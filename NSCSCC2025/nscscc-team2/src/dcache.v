module dcache(
    input           clk,
    input           resetn,

    // CPU
    input           valid,        
    input           op,          
    input   [ 2:0]  size,
    input   [ 7:0]  index,       
    input   [19:0]  tag,          
    input   [ 3:0]  offset,      
    input   [ 3:0]  wstrb,        
    input   [31:0]  wdata,         

    input           bvalid,
    input           inst_bar,

    output          suc_flag,
    output          state_idle,

    output             addr_ok,     
    output  wire       data_ok,     
    output  wire [31:0] rdata,       

    output   reg    cacop_finish,

    input   [ 1:0]  access_type,
    input   [ 1:0]  crmd_dat,
    input   [31:0]  dmw0,
    input   [31:0]  dmw1,
    input   [ 1:0]  tlb_mat,
    input           disable_cache,

    input           cacop_flag,
    input   [ 4:0]  cacop_code,
    input   [31:0]  cacop_va,

    // AXI
    output          rd_req,      
    output  [ 2:0]  rd_type,    
    output  [31:0]  rd_addr,   
    input           rd_rdy,      
    input           ret_valid,    
    input           ret_last,   
    input   [31:0]  ret_data,    

    output  reg     wr_req,       
    output  [ 2:0]  wr_type,     
    output  [31:0]  wr_addr,    
    output  [ 3:0]  wr_wstrb,     
    output  [127:0] wr_data,      
    input           wr_rdy        
);

wire reset = ~resetn;

// CACOP
wire do_cacop = cacop_flag && (cacop_code[2:0]==3'b001);

wire cacop_init        = do_cacop && (cacop_code[4:3]==2'b00 ); // 将指定Cache 行的tag 置为全0
wire cacop_index_maint = do_cacop && (cacop_code[4:3]==2'b01 ); // 对指定的Cache 进行无效并写回
wire cacop_probe_maint = do_cacop && (cacop_code[4:3]==2'b10 ); // 对指定的Cache 进行无效并写回

wire        cacop_init_way   = cacop_va[0];
wire [ 7:0] cacop_init_index = cacop_va[11:4];

// 强序非缓存（Strongly-ordered Uncached，简称SUC）
assign suc_flag = (access_type==2'b00 && crmd_dat ==2'b00) ||
                  (access_type==2'b01 && dmw0[5:4]==2'b00) ||
                  (access_type==2'b10 && dmw1[5:4]==2'b00) ||
                  (access_type==2'b11 && tlb_mat  ==2'b00) ||
                   disable_cache;

// 状态机
parameter IDLE        = 5'b00001;   //空闲
parameter LOOKUP      = 5'b00010;   //查找
parameter MISS        = 5'b00100;   //缺失
parameter REPLACE     = 5'b01000;   //替换
parameter REFILL      = 5'b10000;   //填充
/*
• IDLE：Cache 模块当前没有任何操作。
• LOOKUP：Cache 模块当前正在执行一个操作且得到了它的查询结果。
• MISS：Cache 模块当前处理的操作Cache 缺失，且正在等待AXI 总线的wr_rdy 信号。
• REPLACE：待替换的Cache 行已经从Cache 中读出，且正在等待AXI 总线的rd_rdy 信号。
• REFILL：Cache 缺失的访存请求已发出，准备/正在将缺失的Cache 行数据写入Cache 中。
*/

parameter WRBUF_IDLE  = 2'b01;
parameter WRBUF_WRITE = 2'b10;
/*
• IDLE： Write Buffer 当前没有待写的数据。
• WRITE：将待写数据写入到Cache 中。在主状态机处于LOOKUP 状态且发现Store 操作
         命中Cache 时，触发Write Buffer 状态机进入WRITE 状态，同时Write Buffer 会寄存
         Store 要写入的Index、路号、offset、写使能（写32 位数据里的哪些字节）和写数据。
*/

reg  [ 4:0] cs;
reg  [ 4:0] ns;

assign      state_idle    = (cs == IDLE     );
wire        state_lookup  = (cs == LOOKUP   );
wire        state_miss    = (cs == MISS     );
wire        state_replace = (cs == REPLACE  );
wire        state_refill  = (cs == REFILL   );

reg  [ 1:0] w_cs;
reg  [ 1:0] w_ns;

wire        w_state_idle  = (w_cs == WRBUF_IDLE );
wire        w_state_write = (w_cs == WRBUF_WRITE);

// Read cache
reg   [255:0] valid0;
reg   [255:0] valid1;
reg   [255:0] dirty0 ;
reg   [255:0] dirty1 ;

wire  [ 19:0] read_tag0;
wire  [ 19:0] read_tag1;
reg           read_v0;
reg           read_v1;
wire  [ 31:0] read_word0;
wire  [ 31:0] read_word1;
wire  [127:0] read_data0; 
wire  [127:0] read_data1; 

reg           read_d0;
reg           read_d1;

reg   [127:0] read_data0_r; 
reg   [127:0] read_data1_r; 
reg   [ 19:0] read_tag0_r;
reg   [ 19:0] read_tag1_r;
reg           read_v0_r;
reg           read_v1_r;
reg           read_d0_r;
reg           read_d1_r;

// Request Buffer
reg          req_op_r      ;
reg  [ 2:0]  req_size_r    ;
reg  [ 7:0]  req_index_r   ;
reg  [19:0]  req_tag_r     ;
reg  [ 3:0]  req_offset_r  ;
reg  [ 3:0]  req_wstrb_r   ;
reg  [31:0]  req_wdata_r   ;
reg          req_suc_flag_r;

reg          req_do_cacop_r;
reg          req_cacop_init_r;
reg          req_cacop_index_maint_r;
reg          req_cacop_probe_maint_r;

reg          req_cacop_init_way_r;
reg  [ 7:0]  req_cacop_init_index_r; 

// Tag Compare
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;

wire         cache_hit_write;
wire         hit_write_hazard;

// Miss Buffer
/*
Miss Buffer 用于记录缺失Cache 行准备要替换的路信息，以及已经从AXI 总线返回了几个
32 位数据。Miss 处理时需要的地址、是否是Store 指令等信息依然维护在Request Buffer 中。
*/
reg           replace_way; // 0: way0, 1: way1
reg  [127:0]  replace_data;
reg  [ 19:0]  replace_tag;
reg           replace_v;
reg           replace_d;
reg  [ 7:0]   replace_index;
reg  [ 1:0]   cnt;

// Data Select
wire [ 31:0]  way0_load_word;
wire [ 31:0]  way1_load_word;
wire [ 31:0]  load_word;

// Write Buffer
/*
Write Buffer 是在(Store 操作在Look Up 时发现命中Cache）时启动的，它会寄
存Store 要写入的way、bank、index、bank 内字节写使能和写数据，然后使用寄存后的值写入
Cache 中。
*/
reg          w_needed;
reg          w_way;
reg  [ 1:0]  w_bank; 
reg  [ 7:0]  w_index;
reg  [31:0]  w_word;
reg  [ 3:0]  w_wstrb;

reg way0_hit_r;
reg way1_hit_r;

// LFSR
reg          lfsr;

wire wr_necessary;
reg  wr_necessary_r;

reg  bvalid_r;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        bvalid_r <= 1'b0;
    end
    else if (bvalid) begin
        bvalid_r <= 1'b1;
    end
    else if (ns==IDLE) begin
        bvalid_r <= 1'b0;
    end
end

// 状态机
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end

always @(*) begin
    case(cs)
        IDLE:
            if (!valid || hit_write_hazard) begin          
                ns = IDLE; 
            end       
            else if (valid) begin
                ns = LOOKUP;
            end
        LOOKUP:
            if (cache_hit && req_cacop_probe_maint_r) begin
                ns = MISS;
            end
            else if (!cache_hit && req_cacop_probe_maint_r) begin
                ns = IDLE;
            end
            else if (req_suc_flag_r) begin
                ns = MISS;
            end
            else if (cache_hit && (!valid || hit_write_hazard)) begin
                ns = IDLE;
            end
            else if (cache_hit && valid) begin 
                ns = LOOKUP;
            end
            else if (!cache_hit) begin
                ns = MISS;
            end
        MISS:
            if (!wr_rdy) begin
                ns = MISS;
            end
            else if (wr_rdy) begin
                ns = REPLACE;
            end
        REPLACE:
            if (req_do_cacop_r) begin
                ns = REFILL;
            end
            else if (rd_rdy && ((bvalid | bvalid_r | !wr_necessary_r) || !inst_bar)) begin  
                ns = REFILL;
            end
            else begin
                ns = REPLACE;
            end
        REFILL:
            if (req_do_cacop_r) begin
                ns = IDLE;
            end
            else if (ret_valid && ret_last) begin
                ns = IDLE;
            end
            else begin
                ns = REFILL;
            end
        default:
            ns = IDLE;
    endcase
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        w_cs <= WRBUF_IDLE;
    end else begin
        w_cs <= w_ns;
    end
end

always @(*) begin
    case(w_cs)
        WRBUF_IDLE:
            if (!w_needed && !cache_hit_write) begin
                w_ns = WRBUF_IDLE; 
            end 
            else if (!w_needed && cache_hit_write) begin
                w_ns = WRBUF_WRITE;
            end
        WRBUF_WRITE:
            if (w_needed && cache_hit_write) begin
                w_ns = WRBUF_WRITE;
            end
            else if (w_needed && !cache_hit_write) begin
                w_ns = WRBUF_IDLE;
            end
        default:
            w_ns = WRBUF_IDLE;
    endcase
end

// RAM                  
wire refill_write = state_refill && ret_valid && !req_suc_flag_r && !req_do_cacop_r ; 
wire st_flag = !req_suc_flag_r && req_op_r && (cnt == req_offset_r[3:2]);
wire r_needed = (ns == LOOKUP);

wire        invalid_cacop_write = (state_refill && req_do_cacop_r);
wire        invalid_cacop_way   = (req_cacop_index_maint_r || req_cacop_init_r)? req_cacop_init_way_r : way1_hit_r;
wire [ 7:0] invalid_cacop_index = (req_cacop_index_maint_r || req_cacop_init_r)? req_cacop_init_index_r : req_index_r;

v_tag_ram u_tag_ram0(
    .clka   (clk                                        ),

    .wea    ((refill_write && !replace_way) ||
             (invalid_cacop_write && !invalid_cacop_way)),

    .addra  (r_needed? ((cacop_index_maint || cacop_init)? cacop_init_index : index) :
             invalid_cacop_write? invalid_cacop_index :
             req_index_r                                ),

    .dina   (invalid_cacop_write? {20'b0} :
             {req_tag_r}                          ),

    .douta  (read_tag0                                 )
);

v_tag_ram u_tag_ram1(
    .clka   (clk                                        ),

    .wea    ((refill_write && replace_way) ||
             (invalid_cacop_write && invalid_cacop_way)),

    .addra  (r_needed? ((cacop_index_maint || cacop_init)? cacop_init_index : index) :
             invalid_cacop_write? invalid_cacop_index :
             req_index_r                                ),

    .dina   (invalid_cacop_write? {20'b0} :
             {req_tag_r}                          ),
             
    .douta  (read_tag1                                 )
);

wire [31:0] st_mask = { {8{req_wstrb_r[3]}} , 
                        {8{req_wstrb_r[2]}} , 
                        {8{req_wstrb_r[1]}} , 
                        {8{req_wstrb_r[0]}} };
                       
wire [31:0] real_st_word = (st_mask & req_wdata_r) |
                            (~st_mask & ret_data);

v_bank_ram u_bank_ram00(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && !w_way && w_bank==2'b00) || 
             (refill_write && !replace_way && cnt==2'b00)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data0[31:0]                                       )
);

v_bank_ram u_bank_ram01(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && !w_way && w_bank==2'b01) || 
             (refill_write && !replace_way && cnt==2'b01)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data0[63:32]                                      )
);

v_bank_ram u_bank_ram02(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && !w_way && w_bank==2'b10) || 
             (refill_write && !replace_way && cnt==2'b10)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data0[95:64]                                      )
);

v_bank_ram u_bank_ram03(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && !w_way && w_bank==2'b11) || 
             (refill_write && !replace_way && cnt==2'b11)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data0[127:96]                                     )
);

v_bank_ram u_bank_ram10(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && w_way && w_bank==2'b00) || 
             (refill_write && replace_way && cnt==2'b00)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data1[31:0]                                       )
);

v_bank_ram u_bank_ram11(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && w_way && w_bank==2'b01) || 
             (refill_write && replace_way && cnt==2'b01)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data1[63:32]                                      )
);

v_bank_ram u_bank_ram12(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && w_way && w_bank==2'b10) || 
             (refill_write && replace_way && cnt==2'b10)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data1[95:64]                                      )
);

v_bank_ram u_bank_ram13(
    .clka   (clk                                                    ),
    .wea    ({4{(w_needed && w_way && w_bank==2'b11) || 
             (refill_write && replace_way && cnt==2'b11)}} &
             (w_needed? w_wstrb : 4'b1111) ),
    .addra  (r_needed? index : (w_needed? w_index : req_index_r)    ),
    .dina   (w_needed? w_word : (st_flag? real_st_word : ret_data)   ),
    .douta  (read_data1[127:96]                                     )
);

assign read_word0 = ({32{req_offset_r[3:2] == 2'b00}} & read_data0[ 31: 0]) |
                    ({32{req_offset_r[3:2] == 2'b01}} & read_data0[ 63:32]) |
                    ({32{req_offset_r[3:2] == 2'b10}} & read_data0[ 95:64]) |
                    ({32{req_offset_r[3:2] == 2'b11}} & read_data0[127:96]) ;
assign read_word1 = ({32{req_offset_r[3:2] == 2'b00}} & read_data1[ 31: 0]) |
                    ({32{req_offset_r[3:2] == 2'b01}} & read_data1[ 63:32]) |
                    ({32{req_offset_r[3:2] == 2'b10}} & read_data1[ 95:64]) |
                    ({32{req_offset_r[3:2] == 2'b11}} & read_data1[127:96]) ; 

always @(posedge clk or posedge reset) begin
    if (reset) begin
        valid0 <= 256'b0;
        valid1 <= 256'b0;
    end
    else if (refill_write) begin
        if (!replace_way) begin
            valid0[req_index_r] <= 1'b1;
        end
        else if (replace_way) begin
            valid1[req_index_r] <= 1'b1;
        end
    end
    else if (invalid_cacop_write) begin
        if (!invalid_cacop_way) begin
            valid0[invalid_cacop_index] <= 1'b0;
        end
        else if (invalid_cacop_way) begin
            valid1[invalid_cacop_index] <= 1'b0;
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        read_d0     <= 1'b0;
        read_d1     <= 1'b0;
        read_v0     <= 1'b0;
        read_v1     <= 1'b0;
    end 
    else if (r_needed) begin    
        read_d0     <= dirty0[index];
        read_d1     <= dirty1[index];
        read_v0     <= valid0[index];
        read_v1     <= valid1[index];
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        dirty0[255:0] <= 256'b0;
        dirty1[255:0] <= 256'b0;
    end
    else if (w_needed) begin 
        if (w_way) begin
            dirty1[w_index] <= 1'b1;
        end
        else begin
            dirty0[w_index] <= 1'b1;
        end
    end
    else if (refill_write) begin 
        if (replace_way) begin 
            dirty1[req_index_r] <= req_op_r;
        end 
        else begin 
            dirty0[req_index_r] <= req_op_r;
        end
    end
end

// Request Buffer
always @(posedge clk or posedge reset) begin
    if (reset) begin
        req_op_r       <= 1'b0;
        req_size_r     <= 3'b0;
        req_index_r    <= 8'h00;
        req_tag_r      <= 20'h00000;
        req_offset_r   <= 4'h0;
        req_wstrb_r    <= 4'h0;
        req_wdata_r    <= 32'h00000000;
        req_suc_flag_r <= 1'b0;
        req_do_cacop_r  <= 1'b0;

        req_cacop_init_r        <= 1'b0;
        req_cacop_index_maint_r <= 1'b0;
        req_cacop_probe_maint_r <= 1'b0;

        req_cacop_init_way_r    <= 1'b0;
        req_cacop_init_index_r  <= 8'b0;
    end
    else if (r_needed) begin   
        req_op_r       <= op;  
        req_size_r     <= size;
        req_index_r    <= index;
        req_tag_r      <= tag;
        req_offset_r   <= offset;
        req_wstrb_r    <= wstrb;
        req_wdata_r    <= wdata;
        req_suc_flag_r <= suc_flag;
        req_do_cacop_r <= do_cacop;

        req_cacop_init_r        <= cacop_init;
        req_cacop_index_maint_r <= cacop_index_maint;
        req_cacop_probe_maint_r <= cacop_probe_maint;

        req_cacop_init_way_r    <= cacop_init_way;
        req_cacop_init_index_r  <= cacop_init_index;
    end
end

// Tag Compare
assign way0_hit = read_v0 && (read_tag0 == req_tag_r) && state_lookup;
assign way1_hit = read_v1 && (read_tag1 == req_tag_r) && state_lookup;
assign cache_hit = state_lookup && (way0_hit || way1_hit) &&
                  !req_cacop_init_r && !req_cacop_index_maint_r;

assign cache_hit_write = !req_suc_flag_r && req_op_r && cache_hit ;

// 由于RAM不能同时读写，要在写的时候阻塞后面的请求
assign hit_write_hazard = (cs==LOOKUP && cache_hit_write) | // 马上要写
                          (w_cs==WRBUF_WRITE);              // 正在写

// Miss Buffer
always @(posedge clk or posedge reset) begin
    if (reset) begin
        read_data0_r <= 128'b0;
        read_data1_r <= 128'b0;
        read_tag0_r  <= 20'b0;
        read_tag1_r  <= 20'b0;
        read_v0_r    <= 1'b0;
        read_v1_r    <= 1'b0;
        read_d0_r    <= 1'b0;
        read_d1_r    <= 1'b0;

        way0_hit_r   <= 1'b0;
        way1_hit_r   <= 1'b0;
    end
    else if (state_lookup) begin // 保存刚刚读出来的数据
        read_data0_r <= read_data0;
        read_data1_r <= read_data1;
        read_tag0_r  <= read_tag0;
        read_tag1_r  <= read_tag1;
        read_v0_r    <= read_v0;
        read_v1_r    <= read_v1;
        read_d0_r    <= read_d0;
        read_d1_r    <= read_d1;

        way0_hit_r   <= way0_hit;
        way1_hit_r   <= way1_hit;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        replace_way   <= 1'b0;
        replace_data  <= 128'b0;
        replace_tag   <= 20'b0;
        replace_v     <= 1'b0;
        replace_d     <= 1'b0;
        replace_index <= 8'b0;
    end
    else if (cs==MISS && ns==REPLACE && req_cacop_index_maint_r) begin
        replace_way   <= req_cacop_init_way_r ;
        replace_data  <= req_cacop_init_way_r ? read_data1_r : read_data0_r;
        replace_tag   <= req_cacop_init_way_r ? read_tag1_r  : read_tag0_r;
        replace_v     <= req_cacop_init_way_r ? read_v1_r    : read_v0_r;
        replace_d     <= req_cacop_init_way_r ? read_d1_r    : read_d0_r;
        replace_index <= req_cacop_init_index_r;
    end
    else if (cs==MISS && ns==REPLACE && req_cacop_probe_maint_r) begin
        replace_way   <= way1_hit_r ;
        replace_data  <= way1_hit_r ? read_data1_r : read_data0_r;
        replace_tag   <= way1_hit_r ? read_tag1_r  : read_tag0_r;
        replace_v     <= way1_hit_r ? read_v1_r    : read_v0_r;
        replace_d     <= way1_hit_r ? read_d1_r    : read_d0_r;
        replace_index <= req_index_r;
    end
    else if (cs==MISS && ns==REPLACE) begin
        if (!read_v1_r && read_v0_r) begin
            replace_way   <= 1'b1 ;
            replace_data  <= read_data1_r;
            replace_tag   <= read_tag1_r;
            replace_v     <= read_v1_r;
            replace_d     <= read_d1_r;
            replace_index <= req_index_r;
        end
        else if (read_v1_r && !read_v0_r) begin
            replace_way   <= 1'b0 ;
            replace_data  <= read_data0_r;
            replace_tag   <= read_tag0_r;
            replace_v     <= read_v0_r;
            replace_d     <= read_d0_r;
            replace_index <= req_index_r;
        end
        else begin
            replace_way   <= lfsr ;
            replace_data  <= lfsr ? read_data1_r : read_data0_r;
            replace_tag   <= lfsr ? read_tag1_r  : read_tag0_r;
            replace_v     <= lfsr ? read_v1_r    : read_v0_r;
            replace_d     <= lfsr ? read_d1_r    : read_d0_r;
            replace_index <= req_index_r;
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt <= 2'b00;
    end
    else if (cs==REPLACE && ns==REFILL) begin
        cnt <= 2'b00;
    end
    else if (ret_valid) begin
        cnt <= cnt + 1;
    end
end

// Data Select
assign way0_load_word = read_word0;
assign way1_load_word = read_word1;

assign load_word = ({32{way0_hit               }} & way0_load_word) |
                   ({32{way1_hit               }} & way1_load_word) |
                   ({32{state_refill & data_ok }} & ret_data      ) ;      

// Write Buffer
always @(posedge clk or posedge reset) begin
    if (reset) begin
        w_needed <= 1'b0;
    end
    else if (cache_hit_write) begin
        w_needed <= 1'b1;
    end
    else begin
        w_needed <= 1'b0;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        w_way   <= 1'b0;
        w_bank  <= 2'b00;
        w_index <= 8'h00;
        w_word  <= 32'b0;
        w_wstrb <= 4'b0;
    end
    else if (cache_hit_write) begin
        w_way   <= way1_hit;
        w_bank  <= req_offset_r[3:2];           
        w_index <= req_index_r;            
        w_word  <= req_wdata_r;
        w_wstrb <= req_wstrb_r;
    end
end

// LFSR
always @(posedge clk or posedge reset) begin
    if (reset) begin
        lfsr <= 1'b0;
    end else begin
        lfsr <= ~lfsr; 
    end
end

// Output 
assign addr_ok = ((state_idle) || (state_lookup && ns==LOOKUP)) && !hit_write_hazard;

assign data_ok = (!req_suc_flag_r && !req_op_r && state_lookup && cache_hit) ||
                      (!req_suc_flag_r && !req_op_r && state_refill && ret_valid && cnt==req_offset_r[3:2]) ||               
                      ( req_suc_flag_r && !req_op_r && state_refill && ret_valid) ||
                      ( req_op_r && state_lookup );                     

assign rdata = load_word;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cacop_finish <= 1'b0;
    end
    else begin
        cacop_finish <= (req_cacop_init_r && state_refill) ||
                        (req_cacop_index_maint_r && state_refill) ||
                        (req_cacop_probe_maint_r && state_refill) ||
                        (state_lookup && !cache_hit && req_cacop_probe_maint_r) ;
    end
end

assign rd_req = state_replace && !req_do_cacop_r && ((bvalid | bvalid_r | !wr_necessary_r) || !inst_bar);

assign rd_type = (req_suc_flag_r && !req_op_r)?  req_size_r : 3'b100;
assign rd_addr = (req_suc_flag_r && !req_op_r)? {req_tag_r, req_index_r, req_offset_r} :
                                                {req_tag_r, req_index_r, 4'b0000};

assign wr_necessary = (req_cacop_index_maint_r)? (req_cacop_init_way_r? (read_v1_r && read_d1_r) : (read_v0_r && read_d0_r)) :
                      (req_cacop_probe_maint_r)? (way1_hit_r?           (read_v1_r && read_d1_r) : (read_v0_r && read_d0_r)) :
                             (req_cacop_init_r)? 1'b0                                                                        :     
                  (req_suc_flag_r && !req_op_r)? 1'b0                                                                        :  
                  (req_suc_flag_r &&  req_op_r)? 1'b1                                                                        :                                                                                
                      (!read_v1_r && read_v0_r)? (read_v1_r && read_d1_r                                                   ) :
                      (read_v1_r && !read_v0_r)? (read_v0_r && read_d0_r                                                   ) :
                                         (lfsr)? (read_v1_r && read_d1_r) : (read_v0_r && read_d0_r)                         ;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        wr_necessary_r <= 1'b0;
    end
    else if (cs==MISS && ns==REPLACE) begin
        wr_necessary_r <= wr_necessary;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        wr_req <= 1'b0;
    end
    else if (cs==MISS && ns==REPLACE) begin
        wr_req <= wr_necessary ;
    end
    else if (wr_rdy) begin
        wr_req <= 1'b0;
    end
end

assign wr_type  = (req_suc_flag_r && req_op_r)? req_size_r : 3'b100;

assign wr_addr  = (req_suc_flag_r && req_op_r)? {req_tag_r, req_index_r, req_offset_r} :
                                                {replace_tag, replace_index, 4'b0000} ; 

assign wr_wstrb = (req_suc_flag_r && req_op_r)? req_wstrb_r : 4'b1111;

assign wr_data  = (req_suc_flag_r && req_op_r)? {96'b0, req_wdata_r} : replace_data;

endmodule