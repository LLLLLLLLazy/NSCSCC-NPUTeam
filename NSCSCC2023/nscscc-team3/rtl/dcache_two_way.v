`define LOOKUP  5'b00001
`define MISS    5'b00010
`define REPLACE 5'b00100
`define REFILL  5'b01000
`define RESPOND 5'b10000 
module dcache_two_way(
    input           clk,
    input           resetn,
    input           pmem_wen, 
    input           stall_mem_to_wb,
    input [2:0]     size,
    input           valid,
    input           op,
    input [7:0]     index,
    input [31:0]    paddr,
    input [3:0]     wstrb,
    input [31:0]    wdata,
    output          stall,
    output [31:0]   rdata,
    input           uncached,
    output          rd_req,
    output [2:0]    rd_type,
    output [31:0]   rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input [1:0]     ret_last,
    input [31:0]    ret_data,
    output          wr_req,
    input           wr_rdy,
    output [2:0]    wr_type,
    output [31:0]   wr_addr,
    output [3:0]    wr_wstrb,
    output [127:0]  wr_data,
    //cacop
    input           is_cacop,
    input  [1:0]    cacop,
    input           cacop01_way
);
    //cache
    //tagv
    wire            way0_tagv_we;
    wire [7:0]      way0_tagv_waddr,way0_tagv_raddr;
    wire [20:0]     way0_tagv_wdata,way0_tagv_rdata;
    wire [7:0]      way0_tagv_real_raddr;
    wire            way1_tagv_we;
    wire [7:0]      way1_tagv_waddr,way1_tagv_raddr;
    wire [20:0]     way1_tagv_wdata,way1_tagv_rdata;
    wire [7:0]      way1_tagv_real_raddr;
    //data
    wire            way0_data_we;
    wire [7:0]      way0_data_waddr,way0_data_raddr;
    wire [127:0]    way0_data_wdata,way0_data_rdata;
    wire [7:0]      way0_data_real_raddr;
    wire            way1_data_we;
    wire [7:0]      way1_data_waddr,way1_data_raddr;
    wire [127:0]        way1_data_wdata,way1_data_rdata;
    wire [7:0]      way1_data_real_raddr;
    //d
    wire            way0_d_we;
    wire [7:0]      way0_d_waddr,way0_d_raddr;
    wire            way0_d_wdata,way0_d_rdata;
    wire [7:0]      way0_d_real_raddr;
    wire            way1_d_we;
    wire [7:0]      way1_d_waddr,way1_d_raddr;
    wire            way1_d_wdata,way1_d_rdata;
    wire [7:0]      way1_d_real_raddr;
    //request buffer
    reg [7:0]       req_buffer_index;
    //mem buffer
    wire mem_buffer_we;
    reg [20:0] mem_buffer_way0_tagv;
    reg [127:0] mem_buffer_way0_data;
    reg mem_buffer_way0_d;
    reg [20:0] mem_buffer_way1_tagv;
    reg [127:0] mem_buffer_way1_data;
    reg mem_buffer_way1_d;
    reg [31:0] mem_buffer_paddr;
    reg mem_buffer_op;
    reg mem_buffer_uncached;
    reg mem_buffer_is_cacop;
    reg [1:0] mem_buffer_cacop;
    reg [3:0] mem_buffer_wstrb;
    reg [31:0] mem_buffer_wdata; 
    reg mem_buffer_valid; 
    reg mem_buffer_uncache_cacop01,mem_buffer_cacop2;
    reg [7:0] mem_buffer_va_index;
    reg [2:0] mem_buffer_size;
    reg mem_buffer_cacop01_way;
    reg mem_buffer_cacop01;
    //state
    reg [4:0] state;
    //tag compare
    wire way0_tagveq,way1_tagveq,tagveq;
    wire cache_hit;
    wire hit_way;
    wire [31:0] load_word;
    //hit write
    wire [127:0] hit_line;
    //replace
    reg used [255:0];
    reg replace_way;
    wire [127:0] replace_data;
    wire [20:0] replace_tagv;
    wire replace_d;
    //receive data
    wire receive_data_rst;
    wire receive_data_we;
    reg [127:0] receive_data;
    wire [127:0] final_receive_line;
    wire [127:0] small_receive_line;
    wire [31:0]receive_word;
    //3t1
    reg [31:0] write_wstrb_hit_data;
    reg [127:0] write_wstrb_hit_line;
    reg [31:0] write_wstrb_miss_data;
    reg [127:0] write_wstrb_miss_line;
    //tagv_write_buffer
    reg  [7:0]     wr_buffer_tagv_waddr;
    reg  [20:0]    wr_buffer_tagv_wdata;
    reg            wr_buffer_tagv_valid;
    reg            wr_buffer_way;
    reg [20:0]      way0_tagv_real_rdata;
    reg [20:0]      way1_tagv_real_rdata;
    //data_d_write_buffer
    wire            write_buffer_we;
    reg             write_buffer_valid;
    reg             write_buffer_way;
    reg [7:0]       write_buffer_index;
    reg [127:0]     write_buffer_data;
    reg             write_buffer_d;
    reg [127:0]     way0_data_real_rdata;
    reg             way0_d_real_rdata;
    reg [127:0]     way1_data_real_rdata;
    reg             way1_d_real_rdata;
    wire            cached;

    wire            wr_no_req;
    wire            rd_no_req;
    
    //storage
    tagv_dual_sram way0_tagv(
        .clka(clk),    
        .wea(way0_tagv_we),      
        .addra(way0_tagv_waddr), 
        .dina(way0_tagv_wdata),    
        .clkb(clk),
        .addrb(way0_tagv_real_raddr),  
        .doutb(way0_tagv_rdata)  
    );
    tagv_dual_sram way1_tagv(
        .clka(clk),    
        .wea(way1_tagv_we),      
        .addra(way1_tagv_waddr), 
        .dina(way1_tagv_wdata),    
        .clkb(clk),
        .addrb(way1_tagv_real_raddr),  
        .doutb(way1_tagv_rdata)  
    );
    data_dual_sram way0_data(
        .clka(clk),    
        .wea(way0_data_we),      
        .addra(way0_data_waddr), 
        .dina(way0_data_wdata),    
        .clkb(clk),
        .addrb(way0_data_real_raddr),  
        .doutb(way0_data_rdata)  
    );  
    data_dual_sram way1_data(
        .clka(clk),    
        .wea(way1_data_we),      
        .addra(way1_data_waddr), 
        .dina(way1_data_wdata),    
        .clkb(clk),
        .addrb(way1_data_real_raddr),  
        .doutb(way1_data_rdata)  
    );  
    reg [255:0] way0_d_reg;
    always @(posedge clk) begin
        if(!resetn) 
            way0_d_reg <= 256'd0;
        else if (way0_d_we) 
            way0_d_reg[way0_d_waddr] <= way0_d_wdata;
    end
    reg [7:0] way0_d_raddr_reg;
    always @(posedge clk) begin
      if(!resetn) way0_d_raddr_reg <= 0;
      else way0_d_raddr_reg <= way0_d_real_raddr;
    end
    assign way0_d_rdata = way0_d_reg[way0_d_raddr_reg];

    reg [255:0] way1_d_reg;
    always @(posedge clk) begin
        if(!resetn) 
            way1_d_reg <= 256'd0;
        else if (way1_d_we) 
            way1_d_reg[way1_d_waddr] <= way1_d_wdata;
    end
    reg [7:0] way1_d_raddr_reg;
    always @(posedge clk) begin
      if(!resetn) way1_d_raddr_reg <= 0;
      else way1_d_raddr_reg <= way1_d_real_raddr;
    end
    assign way1_d_rdata = way1_d_reg[way1_d_raddr_reg];

    //request buffer
    always @(posedge clk) begin
        if(!resetn)begin
            req_buffer_index <= 0;
        end
        else if(pmem_wen)begin
            req_buffer_index <= index;
        end
    end
    assign way0_tagv_real_raddr = pmem_wen ? index : req_buffer_index;
    assign way1_tagv_real_raddr = pmem_wen ? index : req_buffer_index;
    assign way0_data_real_raddr = pmem_wen ? index : req_buffer_index;
    assign way1_data_real_raddr = pmem_wen ? index : req_buffer_index;
    assign way0_d_real_raddr = pmem_wen ? index : req_buffer_index;
    assign way1_d_real_raddr = pmem_wen ? index : req_buffer_index;

    //3t1
    always @(*)begin
        if(mem_buffer_op && mem_buffer_va_index == req_buffer_index && state[0] && cache_hit && mem_buffer_valid && ~hit_way)  
            way0_data_real_rdata = write_wstrb_hit_line;
        else if(write_buffer_valid && write_buffer_index == req_buffer_index && ~write_buffer_way) 
            way0_data_real_rdata = write_buffer_data;
        else  
            way0_data_real_rdata = way0_data_rdata;
    end
    always @(*)begin
        if(mem_buffer_op && mem_buffer_va_index == req_buffer_index && state[0] && cache_hit && mem_buffer_valid && hit_way)  
            way1_data_real_rdata = write_wstrb_hit_line;
        else if(write_buffer_valid && write_buffer_index == req_buffer_index && write_buffer_way) 
            way1_data_real_rdata = write_buffer_data;
        else  
            way1_data_real_rdata = way1_data_rdata;
    end
    always @(*)begin
        if(wr_buffer_tagv_waddr == req_buffer_index && wr_buffer_tagv_valid && ~wr_buffer_way) 
            way0_tagv_real_rdata = wr_buffer_tagv_wdata;
        else  
            way0_tagv_real_rdata = way0_tagv_rdata;
    end
    always @(*)begin
      if(wr_buffer_tagv_waddr == req_buffer_index && wr_buffer_tagv_valid && wr_buffer_way) way1_tagv_real_rdata = wr_buffer_tagv_wdata;
      else  way1_tagv_real_rdata = way1_tagv_rdata;
    end
    always @(*)begin
        if(mem_buffer_op && mem_buffer_va_index == req_buffer_index && state[0] && cache_hit && mem_buffer_valid && ~hit_way)  
            way0_d_real_rdata = 1;
        else if(write_buffer_index == req_buffer_index && write_buffer_valid && ~write_buffer_way) 
            way0_d_real_rdata = write_buffer_d;
        else  way0_d_real_rdata = way0_d_rdata;
    end
    always @(*)begin
        if(mem_buffer_op && mem_buffer_va_index == req_buffer_index && state[0] && cache_hit && mem_buffer_valid && hit_way)  
            way1_d_real_rdata = 1;
        else if(write_buffer_index == req_buffer_index && write_buffer_valid && write_buffer_way) 
            way1_d_real_rdata = write_buffer_d;
        else  way1_d_real_rdata = way1_d_rdata;
    end
    //tag cmp
    reg mem_buffer_way0_tagveq,mem_buffer_way1_tagveq;
    assign way0_tagveq = (way0_tagv_real_rdata[0] && way0_tagv_real_rdata[20:1] == paddr[31:12]);
    assign way1_tagveq = (way1_tagv_real_rdata[0] && way1_tagv_real_rdata[20:1] == paddr[31:12]);
    //mem buffer
    always @(posedge clk) begin
        if(!resetn)begin
            mem_buffer_way0_tagv          <= 0;
            mem_buffer_way0_data          <= 0;
            mem_buffer_way0_d             <= 0;
            mem_buffer_way1_tagv          <= 0;
            mem_buffer_way1_data          <= 0;
            mem_buffer_way1_d             <= 0;
            mem_buffer_paddr              <= 0;
            mem_buffer_op                 <= 0;
            mem_buffer_uncached           <= 0;
            mem_buffer_is_cacop           <= 0;
            mem_buffer_cacop              <= 0;
            mem_buffer_wstrb              <= 0;
            mem_buffer_wdata              <= 0;
            mem_buffer_valid              <= 0;
            mem_buffer_uncache_cacop01    <= 0;
            mem_buffer_cacop2             <= 0;
            mem_buffer_cacop01            <= 0;
            mem_buffer_va_index           <= 0;
            mem_buffer_size               <= 0;
            mem_buffer_cacop01_way        <= 0;
            mem_buffer_way0_tagveq        <= 0;
            mem_buffer_way1_tagveq        <= 0;
        end
        else if(mem_buffer_we)begin
            mem_buffer_way0_tagv       <= way0_tagv_real_rdata ;
            mem_buffer_way0_data       <= way0_data_real_rdata;
            mem_buffer_way0_d          <= way0_d_real_rdata;
            mem_buffer_way1_tagv       <= way1_tagv_real_rdata ;
            mem_buffer_way1_data       <= way1_data_real_rdata;
            mem_buffer_way1_d          <= way1_d_real_rdata;
            mem_buffer_paddr           <= paddr;
            mem_buffer_op              <= op;
            mem_buffer_uncached        <= uncached && !is_cacop;
            mem_buffer_is_cacop        <= is_cacop;
            mem_buffer_cacop           <= cacop;
            mem_buffer_wstrb           <= wstrb;
            mem_buffer_wdata           <= wdata;
            mem_buffer_valid           <= valid;
            mem_buffer_uncache_cacop01 <= (uncached && !is_cacop) || (is_cacop & ~cacop[1]);
            mem_buffer_cacop2          <= is_cacop & cacop[1] & ~cacop[0];
            mem_buffer_cacop01         <= is_cacop & ~cacop[1];
            mem_buffer_va_index        <= req_buffer_index;
            mem_buffer_size            <= size;
            mem_buffer_cacop01_way     <= cacop01_way;
            mem_buffer_way0_tagveq     <= way0_tagveq;
            mem_buffer_way1_tagveq     <= way1_tagveq;
        end else if(state[4])begin
            mem_buffer_valid      <= 0;
        end
    end
    //state case！！
    assign wr_no_req = !((mem_buffer_uncached && mem_buffer_op) || 
                                (!mem_buffer_uncached && (replace_tagv[0] && replace_d) && ((mem_buffer_is_cacop && (mem_buffer_cacop[0] ^ mem_buffer_cacop[1])) || !mem_buffer_is_cacop)));
    assign rd_no_req = (mem_buffer_uncached && mem_buffer_op) || mem_buffer_is_cacop;
    always @(posedge clk) begin
        if(!resetn)
            state <= `LOOKUP;
        else begin
            case(state)
            `LOOKUP:begin
                if(!cache_hit && mem_buffer_valid)
                    state <= `MISS;
                else 
                    state <= `LOOKUP;
            end
            `MISS:begin
                if(wr_no_req || wr_rdy)
                    state <= `REPLACE;
                else
                    state <= `MISS;
                end
            `REPLACE:begin
                if(mem_buffer_uncached && mem_buffer_op)
                    state <= `RESPOND;
                else if(mem_buffer_is_cacop)
                    state <= `REFILL;
                else if(rd_rdy)
                    state <= `REFILL;
                else
                    state <= `REPLACE;
            end
            `REFILL:begin
                if(mem_buffer_is_cacop)
                    state <= `RESPOND;
                else if(ret_last && ret_valid)
                    state <= `RESPOND;
                else
                    state <= `REFILL;
                end
            `RESPOND:begin
                state <= `LOOKUP;
            end
            default: state <= state;
            endcase
        end
    end
    //tag cmp
    // assign way0_tagveq = mem_buffer_way0_tagv[0] && mem_buffer_way0_tagv[20:1] == mem_buffer_paddr[31:12];
    // assign way1_tagveq = mem_buffer_way1_tagv[0] && mem_buffer_way1_tagv[20:1] == mem_buffer_paddr[31:12];
    assign tagveq = mem_buffer_way0_tagveq || mem_buffer_way1_tagveq;
    assign cache_hit = !(mem_buffer_uncache_cacop01) && (tagveq ^ mem_buffer_cacop2);
    // assign load_word = {32{way0_tagveq}} & mem_buffer_way0_data[{mem_buffer_paddr[3:2],5'b0} +: 32] |
    //                     {32{way1_tagveq}} & mem_buffer_way1_data[{mem_buffer_paddr[3:2],5'b0} +: 32];
    assign load_word = hit_line[{mem_buffer_paddr[3:2],5'b0} +: 32];
    assign receive_word = small_receive_line[{mem_buffer_paddr[3:2],5'b0} +: 32];
    assign rdata =  {32{state[0] && cache_hit}} & load_word |
                    {32{state[4]}} & (mem_buffer_uncached ? receive_data[31:0] : receive_word);
    assign hit_way = mem_buffer_way1_tagveq;
    //hit write
    assign hit_line = mem_buffer_way0_tagveq ? mem_buffer_way0_data : mem_buffer_way1_data;
    //replace
    genvar i;
    generate 
        for(i = 0 ;i<256;i=i+1) begin
            always @(posedge clk) begin
                if(!resetn) used[i] <= 0;
                else if (mem_buffer_valid && mem_buffer_way0_tagveq && i == mem_buffer_va_index) used[i] <= 0;
                else if (mem_buffer_valid && mem_buffer_way1_tagveq && i == mem_buffer_va_index) used[i] <= 1;
                else if ((way0_tagv_we || way0_d_we) && i == mem_buffer_va_index) used[i] <= 0;
                else if ((way1_tagv_we || way1_d_we) && i == mem_buffer_va_index) used[i] <= 1; 
                else used[i] <= used[i];
            end
        end
    endgenerate
    always @(posedge clk) begin
        if(!resetn) replace_way <= 0;
        else if(state[0] && !cache_hit && mem_buffer_valid)begin
            if(!mem_buffer_is_cacop) 
                replace_way <= ~used[mem_buffer_va_index];
            else if(mem_buffer_cacop2) 
                replace_way <= mem_buffer_way1_tagveq;
            else if(mem_buffer_cacop01) 
                replace_way <= mem_buffer_cacop01_way;
        end
    end
    assign replace_tagv = replace_way ? mem_buffer_way1_tagv : mem_buffer_way0_tagv;
    assign replace_data = replace_way ? mem_buffer_way1_data : mem_buffer_way0_data;
    assign replace_d    = replace_way ? mem_buffer_way1_d : mem_buffer_way0_d;
    assign wr_req = state[1] && ((mem_buffer_uncached && mem_buffer_op) || 
                                (!mem_buffer_uncached && (replace_tagv[0] && replace_d) && ((mem_buffer_is_cacop && (mem_buffer_cacop[0] ^ mem_buffer_cacop[1])) || !mem_buffer_is_cacop)));
    assign wr_addr = mem_buffer_uncached ? mem_buffer_paddr : {replace_tagv[20:1],mem_buffer_va_index,4'd0};
    assign wr_type = mem_buffer_uncached ? mem_buffer_size : 3'b100;
    assign wr_wstrb = mem_buffer_uncached ? mem_buffer_wstrb : 4'b1111;
    assign wr_data = mem_buffer_uncached ? {96'd0,mem_buffer_wdata} : replace_data;

    //receive
    assign rd_req = state[2] && (!(mem_buffer_uncached && mem_buffer_op) && !mem_buffer_is_cacop); 
    assign rd_type = mem_buffer_uncached ? mem_buffer_size :3'b100;
    assign rd_addr = mem_buffer_uncached ? mem_buffer_paddr :{mem_buffer_paddr[31:4],4'b0000}; 
    always @(posedge clk) begin
        if(!resetn) receive_data <= 0;
        else if(receive_data_rst) receive_data <= 0;
        else if(receive_data_we) receive_data <= receive_data << 32 | {96'd0,ret_data};
    end
    assign final_receive_line = {ret_data,receive_data[31:0],receive_data[63:32],receive_data[95:64]};
    assign small_receive_line = {receive_data[31:0],receive_data[63:32],receive_data[95:64],receive_data[127:96]};
    //write buffer
    always @(*) begin
        if(mem_buffer_paddr[3:2] == 0) begin
            write_wstrb_hit_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : hit_line[31:24],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : hit_line[23:16],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : hit_line[15:8],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : hit_line[7:0]};
            write_wstrb_hit_line = {hit_line[127:32],write_wstrb_hit_data};
        end
        else if(mem_buffer_paddr[3:2] == 1)begin
            write_wstrb_hit_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : hit_line[63:56],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : hit_line[55:48],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : hit_line[47:40],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : hit_line[39:32]};
            write_wstrb_hit_line = {hit_line[127:64],write_wstrb_hit_data,hit_line[31:0]};
        end
        else if(mem_buffer_paddr[3:2] == 2)begin
            write_wstrb_hit_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : hit_line[95:88],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : hit_line[87:80],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : hit_line[79:72],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : hit_line[71:64]};
            write_wstrb_hit_line = {hit_line[127:96],write_wstrb_hit_data,hit_line[63:0]};
        end
        else begin
            write_wstrb_hit_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : hit_line[127:120],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : hit_line[119:112],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : hit_line[111:104],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : hit_line[103:96]};
            write_wstrb_hit_line = {write_wstrb_hit_data,hit_line[95:0]};
        end
    end
    always @(*) begin
        if(mem_buffer_paddr[3:2] == 0) begin
            write_wstrb_miss_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : final_receive_line[31:24],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : final_receive_line[23:16],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : final_receive_line[15:8],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : final_receive_line[7:0]};
            write_wstrb_miss_line = {final_receive_line[127:32],write_wstrb_miss_data};
        end
        else if(mem_buffer_paddr[3:2] == 1)begin
            write_wstrb_miss_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : final_receive_line[63:56],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : final_receive_line[55:48],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : final_receive_line[47:40],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : final_receive_line[39:32]};
            write_wstrb_miss_line = {final_receive_line[127:64],write_wstrb_miss_data,final_receive_line[31:0]};
        end
        else if(mem_buffer_paddr[3:2] == 2)begin
            write_wstrb_miss_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : final_receive_line[95:88],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : final_receive_line[87:80],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : final_receive_line[79:72],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : final_receive_line[71:64]};
            write_wstrb_miss_line = {final_receive_line[127:96],write_wstrb_miss_data,final_receive_line[63:0]};
        end
        else begin
            write_wstrb_miss_data = {mem_buffer_wstrb[3] ? mem_buffer_wdata[31:24] : final_receive_line[127:120],
                        mem_buffer_wstrb[2] ? mem_buffer_wdata[23:16] : final_receive_line[119:112],
                        mem_buffer_wstrb[1] ? mem_buffer_wdata[15:8] : final_receive_line[111:104],
                        mem_buffer_wstrb[0] ? mem_buffer_wdata[7:0] : final_receive_line[103:96]};
            write_wstrb_miss_line = {write_wstrb_miss_data,final_receive_line[95:0]};
        end
    end
    always @(posedge clk) begin
        if(!resetn) begin
            wr_buffer_tagv_waddr <= 0;
            wr_buffer_tagv_wdata <= 0;
            wr_buffer_tagv_valid <= 0;
            wr_buffer_way        <= 0;
        end
        else if(state[3] && !mem_buffer_uncached) begin
            wr_buffer_tagv_waddr <= mem_buffer_va_index;
            wr_buffer_tagv_wdata <= mem_buffer_is_cacop ? 21'd0 : {mem_buffer_paddr[31:12],1'b1};
            wr_buffer_tagv_valid <= 1;
            wr_buffer_way        <= replace_way;
        end
        else if(state[0])begin
            wr_buffer_tagv_valid <= 0;
        end
    end   
    assign cached = !mem_buffer_uncached & !mem_buffer_is_cacop & mem_buffer_valid;
    assign write_buffer_we = cached && (state[3] || mem_buffer_op && state[0] && cache_hit && mem_buffer_valid);
    always @(posedge clk) begin
        if(!resetn)begin
            write_buffer_data <= 0;
            write_buffer_index <= 0;
            write_buffer_d    <= 0;
            write_buffer_way  <= 0;
            write_buffer_valid <= 0;
        end
        else if(write_buffer_we) begin
            write_buffer_data <= state[0] ? write_wstrb_hit_line : (mem_buffer_op ? write_wstrb_miss_line : final_receive_line);
            write_buffer_index <= mem_buffer_va_index;
            write_buffer_d    <= mem_buffer_op;
            write_buffer_way  <= state[0] ? mem_buffer_way1_tagveq : replace_way;
            write_buffer_valid  <= 1;
        end
        else if(state[0])begin
            write_buffer_valid <= 0;
        end
    end
    //control
    assign way0_tagv_we = state[3] && !mem_buffer_uncached && ~replace_way;
    assign way1_tagv_we = state[3] && !mem_buffer_uncached && replace_way;
    assign way0_data_we = cached && ((state[3] && ~replace_way) || (mem_buffer_op && state[0] && mem_buffer_way0_tagveq && mem_buffer_valid));
    assign way1_data_we = cached && ((state[3] && replace_way) || (mem_buffer_op && state[0] && mem_buffer_way1_tagveq && mem_buffer_valid));
    assign way0_d_we = cached &&((state[0] && mem_buffer_valid && mem_buffer_way0_tagveq && mem_buffer_op) || (state[3] && ~replace_way));
    assign way1_d_we = cached &&((state[0] && mem_buffer_valid && mem_buffer_way1_tagveq && mem_buffer_op) || (state[3] && replace_way));
    assign way0_tagv_waddr = mem_buffer_va_index;
    assign way0_tagv_wdata = mem_buffer_is_cacop ? 21'd0 : {mem_buffer_paddr[31:12],1'b1};
    assign way1_tagv_waddr = mem_buffer_va_index;
    assign way1_tagv_wdata = mem_buffer_is_cacop ? 21'd0 : {mem_buffer_paddr[31:12],1'b1};
    assign way0_d_waddr = mem_buffer_va_index;
    assign way0_d_wdata = mem_buffer_op;
    assign way1_d_waddr = mem_buffer_va_index;
    assign way1_d_wdata = mem_buffer_op;
    assign way0_data_waddr = mem_buffer_va_index;
    assign way0_data_wdata = state[0] ? write_wstrb_hit_line : (mem_buffer_op ? write_wstrb_miss_line : final_receive_line);
    assign way1_data_waddr = mem_buffer_va_index;
    assign way1_data_wdata = state[0] ? write_wstrb_hit_line : (mem_buffer_op ? write_wstrb_miss_line : final_receive_line);
    assign mem_buffer_we = !stall_mem_to_wb;
    assign receive_data_rst = state[2] && rd_rdy;
    assign receive_data_we = state[3] && ret_valid;
    assign stall = mem_buffer_valid && !cache_hit && !state[4];
endmodule
