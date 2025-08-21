//????cache????????
`include "cache.h"
module dcache (
    input               clk,
    input               reset,
    input               cancel_req,

    //Cache and CPU
    input               valid,
    input               op,
    input [ 2:0]        size,
    input [ 7:0]        index,
    input [19:0]        tag,
    input [ 3:0]        offset,
    input [ 3:0]        wstrb,
    input [31:0]        wdata,

    output              addr_ok,
    output              data_ok,
    output [31:0]       rdata,

    //CACOP?????????
    input               uncache_en   ,
    input               dcacop_op_en ,
    input  [ 1:0]       cacop_op_mode,

    input               preld_en,

	output              dcache_unbusy,

    //Cache and AXI
    output              rd_req,
    output [ 2:0]       rd_type,
    output [31:0]       rd_addr,

    input               rd_rdy,//????????????????????
    input               ret_valid,
    input               ret_last,
    input [31:0]        ret_data,

    //Cache??AXI§Õ????
    output reg          wr_req,
    output [ 2:0]       wr_type,
    output [31:0]       wr_addr,
    output [ 3:0]       wr_wstrb,
    output [127:0]      wr_data,
    input               wr_rdy,

    output              dcache_miss,
    output              dcache_hit
);

//??¦Ë??
reg  [ 1:0] way_d_reg [255:0];

wire [ 1:0] way_d;
wire  [ 7:0] dirty_index;
//Request Buffer
wire        rq_uncache_en_w;//_w is wire
reg         rq_op_r;
reg         rq_preld_r;
reg [ 2:0]  rq_size_r;
reg [ 7:0]  rq_index_r;
reg [19:0]  rq_tag_r;
reg [ 3:0]  rq_offset_r;
reg [ 3:0]  rq_wstrb_r;
reg [31:0]  rq_wdata_r;
reg         rq_uncache_en_r;
reg         rq_dcacop_r;
reg [ 1:0]  rq_cacop_op_mode_r;

reg         rd_req_buffer;
//MISS Buffer??????
reg  [ 1:0]  miss_buffer_replace_way ;
reg  [ 1:0]  miss_buffer_ret_num     ;
reg          rq_replace_way_r;

//write buffer
reg [ 1:0]  wr_way_r;
reg [ 7:0]  wr_index_r;
reg [ 3:0]  wr_wstrb_r;
reg [31:0]  wr_wdata_r;
reg [ 3:0]  wr_offset_r;

//BANK
wire [ 7:0] bank0_way0_addr;
wire [31:0] bank0_way0_wdata;
wire [31:0] bank0_way0_rdata;
wire        bank0_way0_ena;//?????????????????1'b1 
wire [ 3:0] bank0_way0_wen;//?????? SB??SH????§Õ??????Bank????§Õ?????????????
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
wire wr_match_way_bank[1:0][3:0];
//TAGV
wire [ 7:0] tagv_way0_addr;
wire [20:0] tagv_way0_wdata;
wire [20:0] tagv_way0_rdata;//20:1?tag??0¦Ë?v¦Ë????????tagv
wire        tagv_way0_ena; 
wire        tagv_way0_wen;

wire [ 7:0] tagv_way1_addr;
wire [20:0] tagv_way1_wdata;
wire [20:0] tagv_way1_rdata;
wire        tagv_way1_ena; 
wire        tagv_way1_wen;

//hit???
wire [ 1:0] way_hit     ;
wire        cache_hit   ;

//Data Select???
wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [127:0] way0_data;
wire [127:0] way1_data;
wire [31:0]  load_res;

//REPLACE???
wire [127:0] replace_data    ;
wire         replace_d       ;
wire         replace_v       ;
wire [19:0]  replace_tag     ;


wire [ 1:0]  chosen_way      ;
wire [ 1:0]  replace_way     ;
wire [ 1:0]  invalid_way     ;
wire         has_invalid_way ;
wire [ 1:0]  rand_repl_way   ;
wire [ 1:0]  cacop_chose_way ;

//MAIN FSM
reg [4:0] main_state;
reg [4:0] main_next_state;
wire main_idle = main_state == `MAIN_IDLE;
wire main_lookup = main_state == `MAIN_LOOKUP;
wire main_miss = main_state == `MAIN_MISS;
wire main_replace = main_state == `MAIN_REPLACE;
wire main_refill = main_state == `MAIN_REFILL;

//WRITE BUFFER FSM
reg [1:0] write_buffer_state;
reg [1:0] write_buffer_next_state;

wire write_buffer_idle = write_buffer_state == `WRITE_BUFFER_IDLE;
wire write_buffer_write = write_buffer_state == `WRITE_BUFFER_WRITE;

wire         uncache_wr     ;
reg          uncache_wr_buffer;
wire [ 2:0]  uncache_wr_type;

wire [ 1:0]  way_wr_en;

wire [31:0]  refill_data;
wire [31:0]  write_in;

wire         cacop_op_mode0;
wire         cacop_op_mode1;
wire         cacop_op_mode2;

wire         cacop_op_mode2_hit_wr;
reg          cacop_op_mode2_hit_wr_buffer;

wire         req_or_inst_valid;

//LFSR
reg [22:0]   pseudo_random_23;
reg [1:0]    lookup_way_hit_buffer;

//????
//MAIN FSM
assign req_or_inst_valid = valid || dcacop_op_en || preld_en;
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
            if(req_or_inst_valid && !(write_buffer_write && ((wr_offset_r[3:2] == offset[3:2]) || dcacop_op_en)))begin
                main_next_state = `MAIN_LOOKUP;
            end
            else begin
                main_next_state = `MAIN_IDLE;
            end
        end 
        `MAIN_LOOKUP:begin
            if(req_or_inst_valid && !(write_buffer_write && ((wr_offset_r[3:2] == offset[3:2]) || dcacop_op_en)) && 
                            !(rq_op_r  && !op && ((rq_offset_r[3:2] == offset[3:2]) || dcacop_op_en)) &&
                            cache_hit) begin
                main_next_state = `MAIN_LOOKUP;
            end
            else if(cancel_req) begin
                main_next_state = `MAIN_IDLE;
            end
            else if(!cache_hit) begin
                if(uncache_wr || ((replace_d && replace_v) && (!rq_uncache_en_w || cacop_op_mode2_hit_wr) && !cacop_op_mode0))
                begin
                    main_next_state = `MAIN_MISS;
                end
                else begin
                    main_next_state = `MAIN_REPLACE;
                end
            end
            else begin
                main_next_state = `MAIN_IDLE;
            end
        end
        `MAIN_MISS:begin
            if(wr_rdy) begin
                main_next_state = `MAIN_REPLACE;
            end
            else begin
                main_next_state = `MAIN_MISS;
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
assign dcache_unbusy = (main_idle & !(write_buffer_write && ((wr_offset_r[3:2] == offset[3:2]))));

//Request Buffer
always @(posedge clk ) begin
    if(reset) begin
        rq_op_r <= 1'b0;
        rq_size_r <= 3'b0;
        rq_index_r <= 8'b0;
        rq_tag_r <= 20'b0;
        rq_offset_r <= 4'b0;
        rq_wstrb_r <= 4'b0;
        rq_wdata_r <= 32'b0;
        rq_preld_r <= 1'b0;
        rq_uncache_en_r <= 1'b0;
        rq_dcacop_r <= 1'b0;
        rq_cacop_op_mode_r <= 2'b0;
    end
    else if (main_idle && main_next_state == `MAIN_LOOKUP || main_lookup && main_next_state == `MAIN_LOOKUP)begin
        rq_op_r             <= op;
        rq_size_r           <= size;
        rq_index_r          <= index;
        rq_offset_r         <= offset;
        rq_wstrb_r          <= wstrb;
        rq_wdata_r          <= wdata;
        rq_preld_r          <= preld_en;
        rq_dcacop_r         <= dcacop_op_en;
        rq_cacop_op_mode_r  <= cacop_op_mode;
        rq_replace_way_r    <= pseudo_random_23[10];
    end
    else if (main_lookup & !cache_hit) begin
        rq_tag_r <= tag;
        rq_uncache_en_r <= (uncache_en && !rq_dcacop_r);
        uncache_wr_buffer<= uncache_wr;
        cacop_op_mode2_hit_wr_buffer <= cacop_op_mode2_hit_wr;
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
        miss_buffer_ret_num <= miss_buffer_ret_num + 1'b1;//??bank0-bank3
    end
end

//Write Buffer????
wire hit_write = main_lookup && cache_hit && rq_op_r && !cancel_req;
always @(posedge clk ) begin
    if(reset)begin
        write_buffer_state <= `WRITE_BUFFER_IDLE;
    end
    else begin
        write_buffer_state <= write_buffer_next_state;
    end
end

always @(*) begin
    case (write_buffer_state)
        `WRITE_BUFFER_IDLE:begin
            if(hit_write)begin
                write_buffer_next_state = `WRITE_BUFFER_WRITE;
            end
            else begin
                write_buffer_next_state = `WRITE_BUFFER_IDLE;
            end
        end 
        `WRITE_BUFFER_WRITE:begin
            if(hit_write)begin
                write_buffer_next_state = `WRITE_BUFFER_WRITE;
            end
            else begin
                write_buffer_next_state = `WRITE_BUFFER_IDLE;
            end
        end
        default: write_buffer_next_state = `WRITE_BUFFER_IDLE;
    endcase
end
//wr_req
always @(posedge clk ) begin
    if(reset)begin
        wr_req <= 1'b0;
    end
    else begin
        case (main_state)
            `MAIN_MISS:begin
                if(wr_rdy)begin
                    wr_req <= 1'b1;
                end
            end 
            `MAIN_REPLACE:begin
                wr_req <= 1'b0;
            end
            default: begin
                wr_req <= 1'b0;
            end
        endcase
    end
end
//Write Buffer
always @(posedge clk ) begin
    if(reset)begin
        wr_way_r   <= 2'b0;
        wr_index_r <= 8'b0;
        wr_wstrb_r <= 4'b0;
        wr_wdata_r <= 32'b0;
        wr_offset_r <= 4'b0;
    end
    else if(hit_write)begin
        wr_way_r   <= way_hit;
        wr_index_r <= rq_index_r;
        wr_wstrb_r <= rq_wstrb_r;
        wr_wdata_r <= rq_wdata_r;
        wr_offset_r <= rq_offset_r;
    end
end

assign dcache_miss = main_refill && ret_last && !(rq_uncache_en_r || rq_dcacop_r);

//TAG Compare
assign way_hit[0] = (tagv_way0_rdata[20:1] == tag) && tagv_way0_rdata[0];
assign way_hit[1] = (tagv_way1_rdata[20:1] == tag) && tagv_way1_rdata[0];

assign cache_hit = |way_hit && !(uncache_en || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2); 
assign dcache_hit = cache_hit & main_lookup 
                              & !(write_buffer_write && ((wr_offset_r[3:2] == offset[3:2])))
                              & !(rq_op_r  && !op && ((rq_offset_r[3:2] == offset[3:2])));

//Data Select
wire [7:0] rd_start  = rq_offset_r[3:2] << 5;
assign way0_data = {bank3_way0_rdata, bank2_way0_rdata, bank1_way0_rdata, bank0_way0_rdata};
assign way1_data = {bank3_way1_rdata, bank2_way1_rdata, bank1_way1_rdata, bank0_way1_rdata};
assign way0_load_word = way0_data[rd_start +: 32];
assign way1_load_word = way1_data[rd_start +: 32];

assign load_res = {32{way_hit[0] & main_lookup}} & way0_load_word |
                  {32{way_hit[1] & main_lookup}} & way1_load_word |
                  {32{main_refill}} & ret_data  ;

assign rq_uncache_en_w = (uncache_en && !rq_dcacop_r);
assign uncache_wr = rq_uncache_en_w && rq_op_r && !cacop_op_mode1 && !cacop_op_mode2_hit_wr;

//LFSR
always @(posedge clk ) begin
    if(reset)begin
        pseudo_random_23 <= {7'b1010101,16'h00FF};
    end
    else begin
        pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};//????????x^23+x^18+1,??????????????
    end
end


assign chosen_way = rq_replace_way_r ? 2'b10 : 2'b01;
//assign has_invalid_way = |(~{tagv_way0_rdata[0], tagv_way1_rdata[0]});
//assign invalid_way = {tagv_way1_rdata[0], tagv_way0_rdata[0]};
assign has_invalid_way = ~tagv_way0_rdata[0] | ~tagv_way1_rdata[0];
assign invalid_way = {
    tagv_way0_rdata[0] & ~tagv_way1_rdata[0],  // way1 selected only when way0 is valid and way1 is invalid
    ~tagv_way0_rdata[0]                       // way0 selected if invalid (higher priority)
};
assign rand_repl_way = has_invalid_way ? invalid_way : chosen_way[1:0];
assign cacop_chose_way = rq_offset_r[0] ? 2'b10 : 2'b01; 
assign replace_way = {2{cacop_op_mode0 || cacop_op_mode1}} & cacop_chose_way[1:0] |
                     {2{cacop_op_mode2}}                   & way_hit              |
                     {2{!rq_dcacop_r}}                     & rand_repl_way;


assign way_d = way_d_reg[rq_index_r] |
               {2{(wr_index_r == rq_index_r)&&write_buffer_write}}&wr_way_r;
//replace???
assign replace_d = |(way_d & replace_way);
assign replace_v = |(replace_way & {tagv_way1_rdata[0], tagv_way0_rdata[0]});
assign replace_tag = {20{miss_buffer_replace_way[0]}} & tagv_way0_rdata[20:1]|
                      {20{miss_buffer_replace_way[1]}} & tagv_way1_rdata[20:1];
assign replace_data = {128{miss_buffer_replace_way[0]}} & way0_data | 
				      {128{miss_buffer_replace_way[1]}} & way1_data ; 


assign wr_type  = uncache_wr_buffer ? uncache_wr_type : 3'b100;     //replace cache line
assign wr_addr  = uncache_wr_buffer ? {rq_tag_r, rq_index_r, rq_offset_r} :
 	                                  {replace_tag, rq_index_r, 4'b0};
assign wr_data  = uncache_wr_buffer ? {96'b0, rq_wdata_r} : replace_data;
assign wr_wstrb = uncache_wr_buffer ? rq_wstrb_r : 4'hf;

assign uncache_wr_type = rq_size_r;

assign rd_req  = main_replace && !(uncache_wr_buffer || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2);

assign rd_type = rq_uncache_en_r ? rq_size_r : 3'b100;
assign rd_addr = rq_uncache_en_r ? {rq_tag_r, rq_index_r, rq_offset_r} : {rq_tag_r, rq_index_r, 4'b0};

assign write_in = {(rq_wstrb_r[3] ? rq_wdata_r[31:24] : ret_data[31:24]), 
                   (rq_wstrb_r[2] ? rq_wdata_r[23:16] : ret_data[23:16]),
                   (rq_wstrb_r[1] ? rq_wdata_r[15: 8] : ret_data[15: 8]),
                   (rq_wstrb_r[0] ? rq_wdata_r[ 7: 0] : ret_data[ 7: 0])};
assign refill_data = (rq_op_r && (rq_offset_r[3:2] == miss_buffer_ret_num)) ? write_in : ret_data; 

assign way_wr_en = miss_buffer_replace_way & {2{ret_valid}}; 

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
//??¦Ë§Õ
always @(posedge clk) begin
    if (main_refill && ((ret_valid && ret_last) || !rd_req_buffer) && (!(rq_uncache_en_r || cacop_op_mode0))) begin
		way_d_reg[rq_index_r][0] <= miss_buffer_replace_way[0] ? rq_op_r : way_d_reg[rq_index_r][0];
		way_d_reg[rq_index_r][1] <= miss_buffer_replace_way[1] ? rq_op_r : way_d_reg[rq_index_r][1];
    end
    else if (write_buffer_write) begin
		way_d_reg[wr_index_r] <= way_d_reg[wr_index_r] | wr_way_r;
    end
end



//CACOP??????
assign cacop_op_mode0 = rq_dcacop_r && (rq_cacop_op_mode_r == 2'b00);
assign cacop_op_mode1 = rq_dcacop_r && ((rq_cacop_op_mode_r == 2'b01) || (rq_cacop_op_mode_r == 2'b11));
assign cacop_op_mode2 = rq_dcacop_r && (rq_cacop_op_mode_r == 2'b10);

assign cacop_op_mode2_hit_wr = cacop_op_mode2 && |way_hit;

//output
assign rdata = {32{main_lookup}} & load_res |
               {32{main_refill}} & ret_data ;

//bank_way???
assign wr_match_way_bank[0][0] = write_buffer_write && (wr_way_r[0] && (wr_offset_r[3:2] == 2'b00));
assign wr_match_way_bank[0][1] = write_buffer_write && (wr_way_r[0] && (wr_offset_r[3:2] == 2'b01));
assign wr_match_way_bank[0][2] = write_buffer_write && (wr_way_r[0] && (wr_offset_r[3:2] == 2'b10));
assign wr_match_way_bank[0][3] = write_buffer_write && (wr_way_r[0] && (wr_offset_r[3:2] == 2'b11));
assign wr_match_way_bank[1][0] = write_buffer_write && (wr_way_r[1] && (wr_offset_r[3:2] == 2'b00));
assign wr_match_way_bank[1][1] = write_buffer_write && (wr_way_r[1] && (wr_offset_r[3:2] == 2'b01));
assign wr_match_way_bank[1][2] = write_buffer_write && (wr_way_r[1] && (wr_offset_r[3:2] == 2'b10));
assign wr_match_way_bank[1][3] = write_buffer_write && (wr_way_r[1] && (wr_offset_r[3:2] == 2'b11));

assign bank0_way0_addr = wr_match_way_bank[0][0] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank1_way0_addr = wr_match_way_bank[0][1] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank2_way0_addr = wr_match_way_bank[0][2] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank3_way0_addr = wr_match_way_bank[0][3] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank0_way1_addr = wr_match_way_bank[1][0] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank1_way1_addr = wr_match_way_bank[1][1] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank2_way1_addr = wr_match_way_bank[1][2] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);
assign bank3_way1_addr = wr_match_way_bank[1][3] ? wr_index_r : ({8{addr_ok}}  & index | {8{!addr_ok}} & rq_index_r);

assign bank0_way0_wen = {4{wr_match_way_bank[0][0]}} & wr_wstrb_r | 
						{4{main_refill && (way_wr_en[0] && (miss_buffer_ret_num == 2'b00))}} & 4'hf;
assign bank1_way0_wen = {4{wr_match_way_bank[0][1]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[0] && (miss_buffer_ret_num == 2'b01))}} & 4'hf;
assign bank2_way0_wen = {4{wr_match_way_bank[0][2]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[0] && (miss_buffer_ret_num == 2'b10))}} & 4'hf;
assign bank3_way0_wen = {4{wr_match_way_bank[0][3]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[0] && (miss_buffer_ret_num == 2'b11))}} & 4'hf;
assign bank0_way1_wen = {4{wr_match_way_bank[1][0]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[1] && (miss_buffer_ret_num == 2'b00))}} & 4'hf;
assign bank1_way1_wen = {4{wr_match_way_bank[1][1]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[1] && (miss_buffer_ret_num == 2'b01))}} & 4'hf;
assign bank2_way1_wen = {4{wr_match_way_bank[1][2]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[1] && (miss_buffer_ret_num == 2'b10))}} & 4'hf;
assign bank3_way1_wen = {4{wr_match_way_bank[1][3]}} & wr_wstrb_r | 
                        {4{main_refill && (way_wr_en[1] && (miss_buffer_ret_num == 2'b11))}} & 4'hf;

assign bank0_way0_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank1_way0_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank2_way0_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank3_way0_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank0_way1_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank1_way1_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank2_way1_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;
assign bank3_way1_wdata = {32{write_buffer_write}}  & wr_wdata_r |
                          {32{main_refill}} & refill_data        ;

assign bank0_way0_ena = (!(rq_uncache_en_r || cacop_op_mode0)) || main_idle || main_lookup;
assign bank1_way0_ena = bank0_way0_ena;
assign bank2_way0_ena = bank0_way0_ena;
assign bank3_way0_ena = bank0_way0_ena;
assign bank0_way1_ena = bank0_way0_ena;
assign bank1_way1_ena = bank0_way0_ena;
assign bank2_way1_ena = bank0_way0_ena;
assign bank3_way1_ena = bank0_way0_ena;

//tagv_way???
assign tagv_way0_addr = {8{addr_ok }} & index      |
                        {8{!addr_ok}} & rq_index_r ; 
assign tagv_way1_addr = tagv_way0_addr;

assign tagv_way0_ena = (!rq_uncache_en_r) || main_idle || main_lookup || reset;
assign tagv_way1_ena = tagv_way0_ena;

assign tagv_way0_wen = reset || (miss_buffer_replace_way[0] && main_refill && 
                       ((ret_valid && ret_last) || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2_hit_wr_buffer));
assign tagv_way1_wen = reset || (miss_buffer_replace_way[1] && main_refill && 
                       ((ret_valid && ret_last) || cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2_hit_wr_buffer));

assign tagv_way0_wdata = (cacop_op_mode0 || cacop_op_mode1 || cacop_op_mode2_hit_wr_buffer || reset) ? 21'b0 : {rq_tag_r, 1'b1};
assign tagv_way1_wdata = tagv_way0_wdata;

assign data_ok = (main_lookup && (cache_hit || rq_op_r)) || 
                 (main_refill && ((ret_valid && ((miss_buffer_ret_num == rq_offset_r[3:2]) || rq_uncache_en_r)))) &&
                 !(rq_dcacop_r || rq_preld_r); 
assign addr_ok = ((main_idle && main_next_state == `MAIN_LOOKUP) || (main_lookup && main_next_state == `MAIN_LOOKUP)) && !dcacop_op_en; 

//????????????????tagv?????bank
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