//指令cache，只存不取
`include "cache.h"

module icache (
    input               clk,
    input               reset,

    //Cache and CPU
    input               valid,
    input               op,
    input [ 7:0]        index,
    input [19:0]        tag,
    input [ 3:0]        offset,
    input [ 3:0]        wstrb,
    input [31:0]        wdata,

    output              addr_ok,
    output              data_ok,
    output [31:0]       rdata,

    //CACOP指令相关信号
    input               uncache_en,
    input               icacop_op_en,
    input [ 1:0]        cacop_op_mode,//来自code[4:3]
    input [ 7:0]        cacop_op_addr_index,
    input [19:0]        cacop_op_addr_tag,
    input [ 3:0]        cacop_op_addr_offset,

    output              icache_unbusy,

    //可能产生tlb异常
    input               cancel_req,

    //Cache and AXI
    output              rd_req,
    output [ 2:0]       rd_type,
    output [31:0]       rd_addr,

    input               rd_rdy,//读请求能否被接受的握手信号
    input               ret_valid,
    input               ret_last,
    input [31:0]        ret_data,

    //Cache和AXI写请求，事实上在icache中并不使用，但是统一管理
    output              wr_req,
    output [ 2:0]       wr_type,
    output [31:0]       wr_addr,
    output [ 3:0]       wr_wstrb,
    output [127:0]      wr_data,
    input               wr_rdy
);
//端口定义
//主状态机,这儿需要说明：事实上，在icache.v中，状态机的状态并不需要MISS，但是为了保持一致，我没有删除
reg [4:0] main_state;
reg [4:0] main_next_state;
assign main_idle = main_state == `MAIN_IDLE;
wire main_lookup = main_state == `MAIN_LOOKUP;
wire main_miss = main_state == `MAIN_MISS;
wire main_replace = main_state == `MAIN_REPLACE;
wire main_refill = main_state == `MAIN_REFILL;

//Write Buffer状态机在icache中并不使用

//RequestBuffer状态机,采用cache.v中的命名方式
reg         rq_op_r;
reg [ 7:0]  rq_index_r;
reg [19:0]  rq_tag_r;
reg [ 3:0]  rq_offset_r;
reg [ 3:0]  rq_wstrb_r;
reg [31:0]  rq_wdata_r;
reg         rq_uncache_en_r;
reg         rq_icacop_r;
reg [ 1:0]  rq_cacop_op_mode_r;
reg         rd_req_buffer;
//way_bank信号
wire [ 7:0] bank0_way0_addr;
wire [31:0] bank0_way0_wdata;
wire [31:0] bank0_way0_rdata;
wire        bank0_way0_ena;//添加信号，之前是直接赋值1‘b1 
wire [ 3:0] bank0_way0_wen;//为了支持 SB、SH之类的写操作，Bank表的写粒度要精细到字节
wire [ 7:0] bank0_way1_addr;
wire [31:0] bank0_way1_wdata;
wire [31:0] bank0_way1_rdata;
wire        bank0_way1_ena;
wire [ 3:0] bank0_way1_wen;

wire [ 7:0] bank1_way0_addr;
wire [31:0] bank1_way0_wdata;
wire [31:0] bank1_way0_rdata;
wire        bank1_way0_ena;
wire [ 3:0] bank1_way0_wen;
wire [ 7:0] bank1_way1_addr;
wire [31:0] bank1_way1_wdata;
wire [31:0] bank1_way1_rdata;
wire        bank1_way1_ena;
wire [ 3:0] bank1_way1_wen;

wire [ 7:0] bank2_way0_addr;
wire [31:0] bank2_way0_wdata;
wire [31:0] bank2_way0_rdata;
wire        bank2_way0_ena;
wire [ 3:0] bank2_way0_wen;
wire [ 7:0] bank2_way1_addr;
wire [31:0] bank2_way1_wdata;
wire [31:0] bank2_way1_rdata;
wire        bank2_way1_ena;
wire [ 3:0] bank2_way1_wen;

wire [ 7:0] bank3_way0_addr;
wire [31:0] bank3_way0_wdata;
wire [31:0] bank3_way0_rdata;
wire        bank3_way0_ena;
wire [ 3:0] bank3_way0_wen;
wire [ 7:0] bank3_way1_addr;
wire [31:0] bank3_way1_wdata;
wire [31:0] bank3_way1_rdata;
wire        bank3_way1_ena;
wire [ 3:0] bank3_way1_wen;

//way_tagv信号
wire [ 7:0] tagv_way0_addr;
wire [20:0] tagv_way0_wdata;
wire [20:0] tagv_way0_rdata;//20:1为tag域，0位为v位，因此叫做tagv
wire        tagv_way0_ena; 
wire        tagv_way0_wen;

wire [ 7:0] tagv_way1_addr;
wire [20:0] tagv_way1_wdata;
wire [20:0] tagv_way1_rdata;
wire        tagv_way1_ena; 
wire        tagv_way1_wen;

//MISS Buffer相关信号
reg  [ 1:0]  miss_buffer_replace_way ;
reg  [ 1:0]  miss_buffer_ret_num     ;
reg          rq_replace_way_r;

//hit信号
wire [ 1:0] way_hit     ;
wire        cache_hit   ;

//Data Select信号
wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [127:0] way0_data;
wire [127:0] way1_data;
wire [31:0]  load_res;

//路写使能信号
wire [1:0]   way_wr_en;

//重填数据
wire [31:0]  refill_data;

//CACOP相关信号
wire         cacop_op_mode0;
wire         cacop_op_mode1;
wire         cacop_op_mode2;
wire [1:0]   cacop_chose_way;//两位足够了
wire         cacop_op_mode2_hit_wr;
wire         cacop_op_mode2_no_hit;

wire [1:0]   chosen_way;
wire [1:0]   replace_way;
wire [1:0]   invalid_way;
wire         has_invalid_way;
wire [1:0]   rand_repl_way;

//LFSR
reg  [22:0] pseudo_random_23;

reg  [ 1:0]  lookup_way_hit_buffer;

//new offset,tag,index
wire [ 3:0]  real_offset;
wire [19:0]  real_tag   ;
wire [ 7:0]  real_index ;

wire         req_or_inst_valid ;


//MIAN状态机
assign req_or_inst_valid = valid || icacop_op_en;
always @(posedge clk ) begin
    if(reset)begin
        main_state <= `MAIN_IDLE;
    end
    else begin
        main_state <= main_next_state;
    end
end
always @(*) begin
    case (main_state)
        `MAIN_IDLE:begin
            if(req_or_inst_valid)begin
                main_next_state = `MAIN_LOOKUP;
            end
            else begin
                main_next_state = `MAIN_IDLE;
            end
        end 
        `MAIN_LOOKUP:begin
            if(req_or_inst_valid && cache_hit) begin
                main_next_state = `MAIN_LOOKUP;
            end
            else if(cancel_req) begin
                main_next_state = `MAIN_IDLE;
            end
            else if(!cache_hit) begin
                main_next_state = `MAIN_REPLACE;
            end
            else begin
                main_next_state = `MAIN_IDLE;
            end
        end
        `MAIN_REPLACE:begin
            if(rd_rdy)begin
                main_next_state = `MAIN_REFILL;
            end
            else begin
                main_next_state = `MAIN_REPLACE;
            end
        end
        `MAIN_REFILL:begin
            if((ret_valid && ret_last) || !rd_req_buffer) begin
                main_next_state = `MAIN_IDLE;
            end
            else begin
                main_next_state = `MAIN_REFILL;
            end
        end
        default: main_next_state = `MAIN_IDLE;
    endcase
end


//Request Buffer状态机
//Request Buffer
always @(posedge clk ) begin
    if(reset) begin
        rq_op_r <= 1'b0;
        rq_index_r <= 8'b0;
        rq_tag_r <= 20'b0;
        rq_offset_r <= 4'b0;
        rq_wstrb_r <= 4'b0;
        rq_wdata_r <= 32'b0;

        rq_uncache_en_r <= 1'b0;
        rq_icacop_r <= 1'b0;
        rq_cacop_op_mode_r <= 2'b0;
    end
    else if (main_idle && main_next_state == `MAIN_LOOKUP || main_lookup && main_next_state == `MAIN_LOOKUP)begin
        rq_op_r             <= op;
        rq_index_r          <= real_index;
//        rq_tag_r            <= tag;
        rq_offset_r         <= real_offset;
        rq_wstrb_r          <= wstrb;
        rq_wdata_r          <= wdata;

        // rq_uncache_en_r     <= uncache_en;
        rq_cacop_op_mode_r <= cacop_op_mode;
        rq_icacop_r         <= icacop_op_en;
        rq_replace_way_r    <= pseudo_random_23[0];
    end
    else if (main_lookup & !cache_hit) begin
        rq_tag_r <= real_tag;
        rq_uncache_en_r <= (uncache_en && !rq_icacop_r);
    end
end


//MISS Buffer
always @(posedge clk) begin
    if (reset) begin
        miss_buffer_replace_way <= 2'b0;
    end
    else begin
        if (main_lookup && !cache_hit) begin
            miss_buffer_replace_way <= replace_way;
        end
    end
end
always @(posedge clk ) begin
    if(reset)begin
        miss_buffer_ret_num <= 2'b00;
    end
    else if(ret_last && ret_valid)begin
        miss_buffer_ret_num <= 2'b00;
    end
    else if(ret_valid) begin
        miss_buffer_ret_num <= miss_buffer_ret_num + 1'b1;//从bank0-bank3
    end
end

assign real_offset = icacop_op_en ? cacop_op_addr_offset : offset;
assign real_index  = icacop_op_en ? cacop_op_addr_index  : index ;
assign real_tag    = rq_icacop_r ? cacop_op_addr_tag    : tag   ;

//TAG Compare
assign way_hit[0] = (tagv_way0_rdata[20:1] == real_tag) && tagv_way0_rdata[0];
assign way_hit[1] = (tagv_way1_rdata[20:1] == real_tag) && tagv_way1_rdata[0];

assign cache_hit = |way_hit && !(uncache_en || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2); 

//Data select
assign way0_data = {bank3_way0_rdata, bank2_way0_rdata, bank1_way0_rdata, bank0_way0_rdata};
assign way1_data = {bank3_way1_rdata, bank2_way1_rdata, bank1_way1_rdata, bank0_way1_rdata};
assign way0_load_word = way0_data[rq_offset_r[3:2]*32 +: 32];//表示把对应的bank取出来
assign way1_load_word = way1_data[rq_offset_r[3:2]*32 +: 32];

assign load_res = {32{way_hit[0] & main_lookup}} & way0_load_word |
                  {32{way_hit[1] & main_lookup}} & way1_load_word |
                  {32{main_refill}} & ret_data  ;

//LFSR
always @(posedge clk ) begin
    if(reset)begin
        pseudo_random_23 <= {7'b1010101,16'h00FF};//问ai说要为非全0或全1序列，然后这样生成出来的效果比较好 
    end
    else begin
        pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};//对应多项式x^23+x^18+1,这是业内常用多项式
    end
end


assign chosen_way = rq_replace_way_r ? 2'b10 : 2'b01;
//zheassign has_invalid_way = |(~{tagv_way0_rdata[0], tagv_way1_rdata[0]});
//assign invalid_way = {tagv_way1_rdata[0], tagv_way0_rdata[0]};
assign has_invalid_way = ~tagv_way0_rdata[0] | ~tagv_way1_rdata[0];
assign invalid_way = {
    tagv_way0_rdata[0] & ~tagv_way1_rdata[0],  // way1 selected only when way0 is valid and way1 is invalid
    ~tagv_way0_rdata[0]                       // way0 selected if invalid (higher priority)
};
assign rand_repl_way = has_invalid_way ? invalid_way : chosen_way[1:0];
//one_valid_n #(2) sel_one_invalid (.in(~{tagv_way1_rdata[0],tagv_way0_rdata[0]}),.out(invalid_way),.nozero(has_invalid_way));
assign cacop_chose_way = rq_offset_r[0] ? 2'b10 : 2'b01; 
assign replace_way = {2{cacop_op_mode0 || cacop_op_mode1}} & cacop_chose_way[1:0] |
                     {2{cacop_op_mode2}}                   & way_hit              |
                     {2{!rq_icacop_r}}                     & rand_repl_way;

assign rd_req  = main_replace && !(cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2);


assign rd_type = rq_uncache_en_r ? 3'b010 : 3'b100;
assign rd_addr = rq_uncache_en_r ? {rq_tag_r, rq_index_r, rq_offset_r} : {rq_tag_r, rq_index_r, 4'b0};

assign refill_data = ret_data;

assign way_wr_en = miss_buffer_replace_way & {2{ret_valid}}; //when rd_req is not set, ret_valid and ret_last will not be set. block will not be wr also.

//CACOP信号
assign cacop_op_mode0 = rq_icacop_r && (rq_cacop_op_mode_r == 2'b00);
assign cacop_op_mode1 = rq_icacop_r && ((rq_cacop_op_mode_r == 2'b01) || (rq_cacop_op_mode_r == 2'b11));
assign cacop_op_mode2 = rq_icacop_r && (rq_cacop_op_mode_r == 2'b10);

assign cacop_op_mode2_hit_wr = cacop_op_mode2 && |lookup_way_hit_buffer;
assign cacop_op_mode2_no_hit = cacop_op_mode2 && ~|lookup_way_hit_buffer;

always @(posedge clk) begin
    if (reset) begin
        lookup_way_hit_buffer <= 2'b00;
    end
    else if (cacop_op_mode2 && main_lookup) begin
        lookup_way_hit_buffer <= way_hit;
    end
end

always @(posedge clk) begin
    if (reset) begin
        rd_req_buffer <= 1'b0;
    end
    else if (rd_req) begin
        rd_req_buffer <= 1'b1;
    end
    else if (main_refill && (ret_valid && ret_last)) begin
        rd_req_buffer <= 1'b0;
    end
end
//output
assign rdata = {32{main_lookup}} & load_res |
               {32{main_refill}} & ret_data ;

//bank_way信号
assign bank0_way0_addr = {8{addr_ok}}  & real_index | {8{!addr_ok}} & rq_index_r ;
assign bank1_way0_addr = bank0_way0_addr;
assign bank2_way0_addr = bank0_way0_addr;
assign bank3_way0_addr = bank0_way0_addr;
assign bank0_way1_addr = bank0_way0_addr;
assign bank1_way1_addr = bank0_way0_addr;
assign bank2_way1_addr = bank0_way0_addr;
assign bank3_way1_addr = bank0_way0_addr;

assign bank0_way0_wen = (main_refill && way_wr_en[0] && (miss_buffer_ret_num == 2'b00)) ? 4'b1111 : 4'b0000;
assign bank1_way0_wen = (main_refill && way_wr_en[0] && (miss_buffer_ret_num == 2'b01)) ? 4'b1111 : 4'b0000;
assign bank2_way0_wen = (main_refill && way_wr_en[0] && (miss_buffer_ret_num == 2'b10)) ? 4'b1111 : 4'b0000;
assign bank3_way0_wen = (main_refill && way_wr_en[0] && (miss_buffer_ret_num == 2'b11)) ? 4'b1111 : 4'b0000;
assign bank0_way1_wen = (main_refill && way_wr_en[1] && (miss_buffer_ret_num == 2'b00)) ? 4'b1111 : 4'b0000;
assign bank1_way1_wen = (main_refill && way_wr_en[1] && (miss_buffer_ret_num == 2'b01)) ? 4'b1111 : 4'b0000;
assign bank2_way1_wen = (main_refill && way_wr_en[1] && (miss_buffer_ret_num == 2'b10)) ? 4'b1111 : 4'b0000;
assign bank3_way1_wen = (main_refill && way_wr_en[1] && (miss_buffer_ret_num == 2'b11)) ? 4'b1111 : 4'b0000;

assign bank0_way0_wdata = main_refill ? refill_data : 32'b0;
assign bank1_way0_wdata = bank0_way0_wdata;
assign bank2_way0_wdata = bank0_way0_wdata;
assign bank3_way0_wdata = bank0_way0_wdata;
assign bank0_way1_wdata = bank0_way0_wdata;
assign bank1_way1_wdata = bank0_way0_wdata;
assign bank2_way1_wdata = bank0_way0_wdata;
assign bank3_way1_wdata = bank0_way0_wdata;

assign bank0_way0_ena = (!(rq_uncache_en_r || cacop_op_mode0)) || main_idle || main_lookup;
assign bank1_way0_ena = bank0_way0_ena;
assign bank2_way0_ena = bank0_way0_ena;
assign bank3_way0_ena = bank0_way0_ena;
assign bank0_way1_ena = bank0_way0_ena;
assign bank1_way1_ena = bank0_way0_ena;
assign bank2_way1_ena = bank0_way0_ena;
assign bank3_way1_ena = bank0_way0_ena;

wire [19:0] tagv_way0_tag;
wire [19:0] tagv_way1_tag;

assign tagv_way0_tag = tagv_way0_wdata[20:1];
assign tagv_way1_tag = tagv_way1_wdata[20:1];
//tagv_way信号

assign tagv_way0_addr = {8{addr_ok || (icacop_op_en && 
                        (main_idle || main_lookup))}} & real_index | 
                        {8{main_replace || main_refill}} & rq_index_r;
assign tagv_way1_addr = tagv_way0_addr;

assign tagv_way0_ena = (!rq_uncache_en_r) || main_idle || main_lookup;
assign tagv_way1_ena = tagv_way0_ena;

assign tagv_way0_wen = miss_buffer_replace_way[0] && main_refill && 
                       ((ret_valid && ret_last) || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2_hit_wr);
assign tagv_way1_wen = miss_buffer_replace_way[1] && main_refill && 
                       ((ret_valid && ret_last) || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2_hit_wr);


assign tagv_way0_wdata = (cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2_hit_wr) ? 21'b0 : {rq_tag_r,1'b1};
assign tagv_way1_wdata = tagv_way0_wdata;
assign icache_unbusy = main_idle;
assign data_ok = (main_lookup && (cache_hit || cancel_req)) || 
                 (main_refill && ((ret_valid && ((miss_buffer_ret_num == rq_offset_r[3:2]) || rq_uncache_en_r)))) &&
                 !rq_icacop_r; 
assign addr_ok = ((main_idle && main_next_state == `MAIN_LOOKUP) || (main_lookup && main_next_state == `MAIN_LOOKUP)) && !icacop_op_en; 
//书上建议实例化两块tagv，八块bank
TAGV_RAM tagv_way0(
    .addra(tagv_way0_addr),
    .ena(tagv_way0_ena),
    .clka(clk),
    .dina(tagv_way0_wdata),
    .douta(tagv_way0_rdata),
    .wea(tagv_way0_wen)
    );
TAGV_RAM tagv_way1(
    .addra(tagv_way1_addr),
    .ena(tagv_way1_ena),
    .clka(clk),
    .dina(tagv_way1_wdata),
    .douta(tagv_way1_rdata),
    .wea(tagv_way1_wen)
    );
BANK_RAM bank0_way0(
    .addra(bank0_way0_addr),
    .ena(bank0_way0_ena),
    .clka(clk),
    .dina(bank0_way0_wdata),
    .douta(bank0_way0_rdata),
    .wea(bank0_way0_wen)
    );
BANK_RAM bank1_way0(
    .addra(bank1_way0_addr),
    .ena(bank1_way0_ena),
    .clka(clk),
    .dina(bank1_way0_wdata),
    .douta(bank1_way0_rdata),
    .wea(bank1_way0_wen)
    );
BANK_RAM bank2_way0(
    .addra(bank2_way0_addr),
    .ena(bank2_way0_ena),
    .clka(clk),
    .dina(bank2_way0_wdata),
    .douta(bank2_way0_rdata),
    .wea(bank2_way0_wen)
    );
BANK_RAM bank3_way0(
    .addra(bank3_way0_addr),
    .ena(bank3_way0_ena),
    .clka(clk),
    .dina(bank3_way0_wdata),
    .douta(bank3_way0_rdata),
    .wea(bank3_way0_wen)
    );
BANK_RAM bank0_way1(
    .addra(bank0_way1_addr),
    .ena(bank0_way1_ena),
    .clka(clk),
    .dina(bank0_way1_wdata),
    .douta(bank0_way1_rdata),
    .wea(bank0_way1_wen)
    );
BANK_RAM bank1_way1(
    .addra(bank1_way1_addr),
    .ena(bank1_way1_ena),
    .clka(clk),
    .dina(bank1_way1_wdata),
    .douta(bank1_way1_rdata),
    .wea(bank1_way1_wen)
    );
BANK_RAM bank2_way1(
    .addra(bank2_way1_addr),
    .ena(bank2_way1_ena),
    .clka(clk),
    .dina(bank2_way1_wdata),
    .douta(bank2_way1_rdata),
    .wea(bank2_way1_wen)
    );
BANK_RAM bank3_way1(
    .addra(bank3_way1_addr),
    .ena(bank3_way1_ena),
    .clka(clk),
    .dina(bank3_way1_wdata),
    .douta(bank3_way1_rdata),
    .wea(bank3_way1_wen)
    );
endmodule
