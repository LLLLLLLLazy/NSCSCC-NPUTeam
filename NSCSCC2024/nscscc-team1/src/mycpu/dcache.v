module dcache(
    input           clk,
    input           resetn,
    //cache and pipeline interface
    input           valid,
    input           op,
    input  [  1:0]  size,
    input  [  7:0]  index,
    input  [ 19:0]  tag,
    input  [  3:0]  offset,
    input  [  3:0]  wstrb,
    input  [ 31:0]  wdata,
    output          addr_ok,
    output          data_ok,
    output [ 31:0]  rdata,
    input           uncache_en,
    input           cacop_en,
    input  [  1:0]  cacop_op,
    input  [ 31:0]  cacop_va,
    output          dcache_unbusy,  
    //cache and axi interface
    output          rd_req,
    output [  2:0]  rd_type,
    output [ 31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input  [ 31:0]  ret_data,
    output          wr_req,
    output [  2:0]  wr_type,
    output [ 31:0]  wr_addr,
    output [  3:0]  wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy
);


//-----------状态定义-----------
//定义状态
parameter S_IDLE    = 3'b000;
parameter S_LOOKUP  = 3'b001;
parameter S_MISS    = 3'b010;
parameter S_REPLACE = 3'b011;
parameter S_REFILL  = 3'b100;
parameter S_WRITE   = 3'b101;

//主状态机
reg [ 2:0] main_state;
reg [ 2:0] main_next_state;

//write buffer状态机
reg [ 2:0] wb_state;
reg [ 2:0] wb_next_state;


//-----------data path-----------
//Request Buffer
reg [106:0] req_buf;

//Tag Compare
wire [20:0] way0_tagv_rdata;
wire [20:0] way1_tagv_rdata;
reg  [20:0] way0_tagv_rdata_r;
reg  [20:0] way1_tagv_rdata_r;
wire [19:0] way0_tag;
wire [19:0] way1_tag;

wire [ 1:0] reg_size;
wire [19:0] reg_tag;
wire        reg_op;
wire [ 7:0] reg_index;
wire [ 3:0] reg_offset;
wire [ 3:0] reg_wstrb;
wire [31:0] reg_wdata;
wire        reg_uncache_en;
wire        reg_cacop_en;
wire [ 1:0] reg_cacop_op;
wire [31:0] reg_cacop_va;

wire        way0_v;
wire        way1_v;
wire        way0_hit;
wire        way1_hit;
wire        cache_hit;

always @(*)begin
    way0_tagv_rdata_r = way0_tagv_rdata;
    way1_tagv_rdata_r = way1_tagv_rdata;
end

assign way0_tag  = way0_tagv_rdata_r[19:0];
assign way1_tag  = way1_tagv_rdata_r[19:0];
assign way0_v    = way0_tagv_rdata_r[20];
assign way1_v    = way1_tagv_rdata_r[20];

assign reg_size       = req_buf[106:105];
assign reg_cacop_va   = req_buf[104:73];
assign reg_cacop_op   = req_buf[72:71];
assign reg_cacop_en   = req_buf[70];
assign reg_uncache_en = req_buf[69];
assign reg_op         = req_buf[68];
assign reg_index      = reg_cacop_en ? req_buf[84:77] : req_buf[67:60];
assign reg_tag        = reg_cacop_en ? req_buf[104:85] : req_buf[59:40];
assign reg_offset     = req_buf[39:36];
assign reg_wstrb      = req_buf[35:32];
assign reg_wdata      = req_buf[31:0];


assign way0_hit  = way0_tagv_rdata_r[20] && (way0_tagv_rdata_r[19:0] == reg_tag);
assign way1_hit  = way1_tagv_rdata_r[20] && (way1_tagv_rdata_r[19:0] == reg_tag);
assign cache_hit = (way0_hit || way1_hit) && ~reg_uncache_en;

reg cacop_hit_way_r;

always @(posedge clk)begin
    if(~resetn)begin
        cacop_hit_way_r <= 1'b0;
    end
    else if(main_state == S_LOOKUP && cache_hit == 1'b1 && reg_cacop_en == 1'b1) begin
        cacop_hit_way_r <= way1_hit;
    end
    else begin
        cacop_hit_way_r <= cacop_hit_way_r;
    end
end

//Write buffer
wire        w_way;
wire [ 1:0] w_bank;

wire        wb_way;
wire [ 1:0] wb_bank;
wire [ 7:0] wb_index;
wire [ 3:0] wb_wstrb;
wire [31:0] wb_wdata;

assign w_way = way0_hit ? 1'b0 : 1'b1;
assign w_bank= reg_offset[3:2];

reg [46:0] write_buf;
assign {
    wb_way,
    wb_index,
    wb_bank,
    wb_wstrb,
    wb_wdata
} = write_buf;


//LFSR
reg [ 3:0] lfsr;

always @(posedge clk) begin
    if(~resetn) begin
        lfsr <= 4'b0;
    end
    else begin
        lfsr <= lfsr + 1'b1;
    end
end
//cache ram 读写控制信号
//{Tag,V}
wire [ 7:0] tagv_addr;
reg  [ 7:0] tagv_addr_r;
wire        tagv_way0_wen;
wire        tagv_way1_wen;      
wire [20:0] tagv_wdata;

//Data
wire [ 7:0] bank_waddr;
wire [ 7:0] bank_addr;
reg  [ 7:0] bank_addr_r;
wire [ 3:0] bank_wstrb;
reg  [ 3:0] bank_wstrb_r;
wire [ 3:0] bank0_way0_wen;
wire [ 3:0] bank1_way0_wen;
wire [ 3:0] bank2_way0_wen;
wire [ 3:0] bank3_way0_wen;
wire [ 3:0] bank0_way1_wen;
wire [ 3:0] bank1_way1_wen;
wire [ 3:0] bank2_way1_wen;
wire [ 3:0] bank3_way1_wen;
wire [31:0] bank_wdata;
reg  [31:0] bank_wdata_r;

//D
wire [ 7:0] d_addr;
wire        d_wdata;
wire        d_way0_wen;
wire        d_way1_wen; 
wire        d_way0_rdata;
wire        d_way1_rdata;    

//Data Select
wire [127:0] way0_data;
wire [127:0] way1_data;

wire [ 31:0] way0_bank0_data;
wire [ 31:0] way0_bank1_data;
wire [ 31:0] way0_bank2_data;
wire [ 31:0] way0_bank3_data;
wire [ 31:0] way1_bank0_data;
wire [ 31:0] way1_bank1_data;
wire [ 31:0] way1_bank2_data;
wire [ 31:0] way1_bank3_data;

wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;

wire replace_way_no_cacop;
wire replace_way_cacop;
wire replace_way;

wire [127:0] replace_data;

reg [2:0] miss_buf;//{replace_way,word_num};

wire        miss_way;
wire [ 1:0] rec_num;

assign way0_data = {way0_bank3_data,way0_bank2_data,way0_bank1_data,way0_bank0_data};
assign way1_data = {way1_bank3_data,way1_bank2_data,way1_bank1_data,way1_bank0_data};

assign way0_load_word = way0_data[{reg_offset[3:2],5'b0} +: 32];
assign way1_load_word = way1_data[{reg_offset[3:2],5'b0} +: 32];

assign load_res = {32{way0_hit&main_state == S_LOOKUP}} & way0_load_word
                | {32{way1_hit&main_state == S_LOOKUP}} & way1_load_word
                | {32{main_state == S_REFILL}} & ret_data;

assign replace_way = ~reg_cacop_en && ~way0_v ? 1'b0 : 
                     ~reg_cacop_en && ~way1_v ? 1'b1 :
                     ~reg_cacop_en            ? lfsr[0] :
                     reg_cacop_en && !(reg_cacop_op == 2'h2) ? reg_cacop_va[0] :
                     main_state == S_LOOKUP ? way1_hit : cacop_hit_way_r;
assign replace_data = miss_way ? way1_data : way0_data;

//Miss Buffer

assign miss_way = miss_buf[2];
assign rec_num  = miss_buf[1:0];

//-----------状态机实现-----------
//hit write 冲突
wire hit_write_stall;

//定义状态转移条件

always @(posedge clk) begin
    if(~resetn) begin 
        main_state <= S_IDLE;
    end
    else begin
        main_state <= main_next_state;
    end
end

always @(posedge clk) begin
    if(~resetn) begin 
        wb_state <= S_IDLE;
    end  
    else begin
        wb_state <= wb_next_state;
    end
end

//main_state_machine
always @(*) begin
    case (main_state)
        S_IDLE: begin
            if(!(valid || cacop_en) || hit_write_stall) begin //无新请求
                main_next_state = S_IDLE; 
            end
            else begin
                main_next_state = S_LOOKUP;
            end
        end

        S_LOOKUP: begin
            if(reg_cacop_en && reg_cacop_op == 2'b0)begin
                main_next_state = S_REFILL;
            end
            else if(reg_cacop_en && reg_cacop_op == 2'b1 && ((reg_cacop_va[0] == 1'b0 && way0_v) || (reg_cacop_va[0] == 1'b1 && way1_v)))begin
                main_next_state = S_MISS;
            end
            else if(reg_cacop_en && reg_cacop_op == 2'h2 && cache_hit)begin
                main_next_state = S_MISS;
            end
            else if(reg_cacop_en && (reg_cacop_op == 2'h2 || reg_cacop_op == 2'b1))begin
                main_next_state = S_IDLE;
            end
            else if(cache_hit && !valid || hit_write_stall) begin //命中且无新请求
                main_next_state = S_IDLE;
            end
            else if(cache_hit && valid) begin //命中且有新请求
                main_next_state = S_LOOKUP;
            end
            else if(!cache_hit) begin //未命中
                main_next_state = S_MISS;
            end
            else begin
                main_next_state = S_LOOKUP;
            end
        end

        S_MISS: begin
            if(wr_rdy || !(miss_way && d_way1_rdata || !miss_way && d_way0_rdata) && !(reg_uncache_en && reg_op)) begin //AXI接收写请求
                main_next_state = S_REPLACE;
            end
            else begin
                main_next_state = S_MISS;
            end
        end

        S_REPLACE: begin
            if(rd_rdy || reg_uncache_en && reg_op) begin //AXI接收读请求
                main_next_state = S_REFILL;
            end
            else begin
                main_next_state = S_REPLACE;
            end
        end

        S_REFILL:begin
            if(ret_valid && ret_last || reg_cacop_en || reg_uncache_en && reg_op) begin
                main_next_state = S_IDLE;
            end
            else begin
                main_next_state = S_REFILL;
            end
        end

        default:begin
            main_next_state = S_IDLE ;
        end

    endcase
end

//write buffer状态机
always @(*) begin
    case (wb_state)
        S_IDLE: begin
            if(main_state == S_LOOKUP && cache_hit && reg_op == 1'b1) begin
                wb_next_state = S_WRITE;
            end
            else begin
                wb_next_state = S_IDLE;
            end
        end

        S_WRITE:begin
            if(main_state == S_LOOKUP && cache_hit && reg_op == 1'b1) begin
                wb_next_state = S_WRITE;
            end
            else begin
                wb_next_state = S_IDLE;
            end
        end

        default:begin
            wb_next_state = S_IDLE;
        end
    endcase
end   
//-----------控制逻辑-----------
//tagv_ram
assign  tagv_addr = main_next_state == S_LOOKUP ? index  : reg_index;
assign  tagv_way0_wen = main_next_state == S_REFILL ? miss_way == 0 && ~reg_uncache_en : 1'b0;
assign  tagv_way1_wen = main_next_state == S_REFILL ? miss_way == 1 && ~reg_uncache_en : 1'b0;
assign  tagv_wdata = ~reg_cacop_en ? {1'b1,reg_tag} : 21'b0 ;

//data_bank_ram
always @(posedge clk)begin
    if(~resetn)begin
        bank_wstrb_r <= 4'b0;
    end
    else begin
        bank_wstrb_r <= bank_wstrb;
    end
end
always @(posedge clk) begin
    if(~resetn)begin
        bank_wdata_r <= 32'b0;
    end
    else begin
        bank_wdata_r <= bank_wdata;
    end
end

assign  bank_waddr = wb_state        == S_WRITE  ? wb_index  :
                    reg_index;

assign  bank_addr = main_next_state == S_LOOKUP ? index     : 
                    reg_index;

assign  bank_wstrb = main_state      == S_REFILL ? {4{~reg_uncache_en & ~reg_cacop_en}} :
                     main_next_state == S_REFILL ? {4{~reg_uncache_en & ~reg_cacop_en}} :
                     wb_state        == S_WRITE  ? wb_wstrb:
                     bank_wstrb_r;

wire [31:0] reg_wdata_selected;
reg [31:0] refill_data;
wire is_refill_state;
wire is_write_state;

assign is_refill_state = main_state == S_REFILL;
assign is_write_state  = wb_state == S_WRITE;

always @(*) begin
    refill_data[31:24] = reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24];
    refill_data[23:16] = reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16];
    refill_data[15:8]  = reg_wstrb[1] ? reg_wdata[15:8]  : ret_data[15:8];
    refill_data[7:0]   = reg_wstrb[0] ? reg_wdata[7:0]   : ret_data[7:0];
end

assign reg_wdata_selected = (is_refill_state && rec_num == reg_offset[3:2] && reg_op == 1'b1) ? refill_data : ret_data;

assign bank_wdata = is_write_state ? wb_wdata :
                    (is_refill_state ? reg_wdata_selected : bank_wdata_r);


assign  bank0_way0_wen = main_state == S_REFILL ? {4{(rec_num == 2'h0 && miss_way == 1'b0)}} & bank_wstrb: 
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h0 && wb_way   == 1'b0)}} & bank_wstrb:
                         4'b0;
assign  bank1_way0_wen = main_state == S_REFILL ? {4{(rec_num == 2'h1 && miss_way == 1'b0)}} & bank_wstrb:
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h1 && wb_way   == 1'b0)}} & bank_wstrb:
                         4'b0;
assign  bank2_way0_wen = main_state == S_REFILL ? {4{(rec_num == 2'h2 && miss_way == 1'b0)}} & bank_wstrb: 
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h2 && wb_way   == 1'b0)}} & bank_wstrb:
                         4'b0;
assign  bank3_way0_wen = main_state == S_REFILL ? {4{(rec_num == 2'h3 && miss_way == 1'b0)}} & bank_wstrb: 
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h3 && wb_way   == 1'b0)}} & bank_wstrb:
                         4'b0;  
assign  bank0_way1_wen = main_state == S_REFILL ? {4{(rec_num == 2'h0 && miss_way == 1'b1)}} & bank_wstrb:
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h0 && wb_way   == 1'b1)}} & bank_wstrb:
                         4'b0;
assign  bank1_way1_wen = main_state == S_REFILL ? {4{(rec_num == 2'h1 && miss_way == 1'b1)}} & bank_wstrb:
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h1 && wb_way   == 1'b1)}} & bank_wstrb:
                         4'b0;
assign  bank2_way1_wen = main_state == S_REFILL ? {4{(rec_num == 2'h2 && miss_way == 1'b1)}} & bank_wstrb:
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h2 && wb_way   == 1'b1)}} & bank_wstrb:
                         4'b0;
assign  bank3_way1_wen = main_state == S_REFILL ? {4{(rec_num == 2'h3 && miss_way == 1'b1)}} & bank_wstrb:
                         wb_state   == S_WRITE  ? {4{(wb_bank == 2'h3 && wb_way   == 1'b1)}} & bank_wstrb:
                         4'b0;

//d_regfile
assign  d_addr = main_state == S_REPLACE &&  reg_cacop_en ? reg_cacop_va[11:4] :
                 wb_state   == S_WRITE  ? wb_index  :
                 reg_index;

assign  d_wdata = main_state == S_REFILL ? reg_op   :
                  wb_state        == S_WRITE  ? 1'b1     : 
                  1'b0;

assign  d_way0_wen = main_state == S_REFILL ? (miss_way == 1'b0) && ~reg_uncache_en :
                     wb_state        == S_WRITE  ? wb_way   == 1'b0                     :
                     1'b0;

assign  d_way1_wen = main_state == S_REFILL ? (miss_way == 1'b1) && ~reg_uncache_en :
                     wb_state        == S_WRITE  ? wb_way   == 1'b1                     : 
                     1'b0;

assign hit_write_stall = (main_state == S_LOOKUP && reg_op || wb_state == S_WRITE) && valid == 1'b1 && op == 1'b0 ;

//req_buf
always @(posedge clk) begin
    if(~resetn) begin
        req_buf <= 107'b0;
    end
    else if((main_state == S_IDLE && (valid == 1'b1 || cacop_en == 1'b1)) || (main_state == S_LOOKUP && cache_hit == 1'b1 && valid == 1'b1 && ~reg_cacop_en) ) begin
        req_buf <= {size,cacop_va,cacop_op,cacop_en,uncache_en,op,index,tag,offset,wstrb,wdata};
    end
end

//miss_buf
always @(posedge clk) begin
    if(~resetn) begin
        miss_buf <= 3'b0;
    end
    else if(main_next_state == S_MISS) begin
        miss_buf[2] <= replace_way;
    end
    else if(main_state == S_REPLACE && rd_rdy) begin
        miss_buf[1:0] <= 2'b0;
    end
    else if(main_state == S_REFILL && ret_valid) begin
        miss_buf[1:0] <= miss_buf[1:0] + 1;
    end
end

//write_buf
always @(posedge clk) begin
    if(~resetn) begin
        write_buf <= 47'b0;
    end
    else if(main_state == S_LOOKUP && cache_hit && reg_op == 1'b1) begin
        write_buf <= {w_way,reg_index,w_bank,reg_wstrb,reg_wdata};
    end
end

assign addr_ok = (main_state == S_IDLE || main_state == S_LOOKUP && cache_hit && ~reg_cacop_en) && ~cacop_en && ~hit_write_stall;
assign data_ok = main_state == S_LOOKUP ? cache_hit :
                 main_state == S_REFILL ? (ret_valid && rec_num == reg_offset[3:2] && ~reg_uncache_en) || (reg_uncache_en && (ret_valid || reg_op )) :
                 1'b0;
assign rd_req    = main_state == S_REPLACE && ~(reg_uncache_en && reg_op == 1'b1) && ~reg_cacop_en;
assign rd_type   = reg_uncache_en ? {1'b0,reg_size} : 3'b100;
assign rd_addr   = reg_uncache_en ? {reg_tag,reg_index,reg_offset} : {reg_tag,reg_index,4'b0};
assign wr_req    = (main_state == S_MISS && ((miss_way == 1'b1 && d_way1_rdata && way1_v || miss_way == 1'b0 && d_way0_rdata && way0_v) && ~reg_uncache_en &&  ~reg_cacop_en 
                || (reg_uncache_en && reg_op == 1'b1) 
                || (reg_cacop_en && reg_cacop_op == 2'b1 && (reg_cacop_va[0] == 1'b0 && d_way0_rdata || reg_cacop_va[0] == 1'b1 && d_way1_rdata)) 
                || (reg_cacop_op && reg_cacop_op == 2'h2)));
assign wr_type   = reg_uncache_en && !reg_cacop_en ? 3'b010 : 3'b100;
assign wr_addr   = reg_uncache_en && !reg_cacop_en ? {reg_tag,reg_index,reg_offset} : 
                   miss_way == 1'b1 ? {way1_tag,reg_index,4'b0} :
                   {way0_tag,reg_index,4'b0};
assign wr_data   = reg_uncache_en && !reg_cacop_en ? {96'b0,reg_wdata} : replace_data;
assign wr_wstrb  = reg_uncache_en && !reg_cacop_en ? reg_wstrb : 4'b1111;
assign rdata     = load_res;

//----------实例化----------
//D_REGFILE
d_regfile d_regfile_way0(
    .clk    (         clk),
    .resetn (      resetn),
    .raddr1 (      d_addr),
    .rdata1 (d_way0_rdata),
    .we     (  d_way0_wen),
    .waddr  (      d_addr),
    .wdata  (     d_wdata)
);

d_regfile d_regfile_way1(
    .clk    (         clk),
    .resetn (      resetn),
    .raddr1 (      d_addr),
    .rdata1 (d_way1_rdata),
    .we     (  d_way1_wen),
    .waddr  (      d_addr),
    .wdata  (     d_wdata)
);

//chiplab sram实现
DATA_BANK_RAM data_bank0_ram_way0(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank0_way0_wen),
    .addra  (     bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way0_bank0_data)
);

DATA_BANK_RAM data_bank1_ram_way0(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank1_way0_wen),
    .addra  (     bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way0_bank1_data)
);

DATA_BANK_RAM data_bank2_ram_way0(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank2_way0_wen),
    .addra  (      bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way0_bank2_data)
);

DATA_BANK_RAM data_bank3_ram_way0(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank3_way0_wen),
    .addra  (      bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way0_bank3_data)
);

DATA_BANK_RAM data_bank0_ram_way1(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank0_way1_wen),
    .addra  (      bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way1_bank0_data)
);

DATA_BANK_RAM data_bank1_ram_way1(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank1_way1_wen),
    .addra  (      bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way1_bank1_data)
);

DATA_BANK_RAM data_bank2_ram_way1(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank2_way1_wen),
    .addra  (      bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way1_bank2_data)
);

DATA_BANK_RAM data_bank3_ram_way1(
    .clka   (            clk),
    .ena    (           1'b1),
    .wea    ( bank3_way1_wen),
    .addra  (      bank_waddr),
    .dina   (     bank_wdata),
    .addrb  (      bank_addr),
    .doutb  (way1_bank3_data)
);
//手写tagv_sram实现
TAGV_RAM tagv_ram_way0(
    .clka   (              clk),
    .ena    (             1'b1),
    .rsta   (          ~resetn),
    .wea    (    tagv_way0_wen),
    .addra  (        tagv_addr),
    .dina   (       tagv_wdata),
    .douta  (  way0_tagv_rdata)
);

TAGV_RAM tagv_ram_way1(
    .clka   (              clk),
    .ena    (             1'b1),
    .rsta   (          ~resetn),
    .wea    (    tagv_way1_wen),
    .addra  (        tagv_addr),
    .dina   (       tagv_wdata),
    .douta  (  way1_tagv_rdata)
);


assign dcache_unbusy = (main_state == S_IDLE && !hit_write_stall);

endmodule
