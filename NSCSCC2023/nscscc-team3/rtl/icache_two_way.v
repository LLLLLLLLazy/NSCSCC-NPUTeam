`define LOOKUP  5'b00001
`define MISS    5'b00010
`define REPLACE 5'b00100
`define REFILL  5'b01000
`define RESPOND 5'b10000 
module icache_two_way(
    input           clk,
    input           resetn,
    input           pif_wen,
    input           stall_if_to_wb,
    input           valid,
    input [7:0]     index,
    input [31:0]    paddr,
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
    //cacop
    input           is_cacop,
    input  [1:0]    cacop,
    input           cacop01_way
);
    //cache
    //tagv
    wire way0_tagv_we;
    wire [7:0] way0_tagv_waddr,way0_tagv_raddr;
    wire [20:0] way0_tagv_wdata,way0_tagv_rdata;
    wire way1_tagv_we;
    wire [7:0] way1_tagv_waddr,way1_tagv_raddr;
    wire [20:0] way1_tagv_wdata,way1_tagv_rdata;
    //data
    wire way0_data_we;
    wire [7:0] way0_data_waddr,way0_data_raddr;
    wire [127:0] way0_data_wdata,way0_data_rdata;
    wire way1_data_we;
    wire [7:0] way1_data_waddr,way1_data_raddr;
    wire [127:0] way1_data_wdata,way1_data_rdata;
    //request buffer
    reg [7:0] req_buffer_index;
    //mem buffer
    reg [20:0] mem_buffer_way0_tagv;
    reg [127:0] mem_buffer_way0_data;
    reg [20:0] mem_buffer_way1_tagv;
    reg [127:0] mem_buffer_way1_data;
    reg [31:0] mem_buffer_paddr;
    reg mem_buffer_uncached;
    reg mem_buffer_is_cacop; 
    reg mem_buffer_valid; 
    reg mem_buffer_uncache_cacop01,mem_buffer_cacop2;
    reg [7:0] mem_buffer_index;
    reg mem_buffer_cacop01_way;
    reg mem_buffer_cacop01;
    //state
    reg [4:0] state;
    //tag compare
    wire way0_tagveq,way1_tagveq,tagveq;
    wire cache_hit;
    wire [31:0] load_word;
    //hit write
    wire [127:0] hit_line;
    //replace
    reg replace_way;
    reg used [255:0];
    //receive data
    reg [127:0] receive_data;
    wire [127:0] final_receive_line;
    wire [127:0] small_receive_line;
    wire [31:0]receive_word;
    //tagv_write_buffer
    reg  [7:0]      wr_buffer_tagv_waddr;
    reg  [20:0]     wr_buffer_tagv_wdata;
    reg             wr_buffer_tagv_valid;
    reg             wr_buffer_way;
    wire [20:0]      way0_tagv_real_rdata;
    wire [20:0]      way1_tagv_real_rdata;
    //data_d_write_buffer
    reg             write_buffer_valid;
    reg             write_buffer_way;
    reg [7:0]       write_buffer_index;
    reg [127:0]     write_buffer_data;
    wire [127:0]     way0_data_real_rdata;
    wire [127:0]     way1_data_real_rdata;

    //storage
    tagv_dual_sram way0_tagv(
    .clka(clk),    
    .wea(way0_tagv_we),      
    .addra(way0_tagv_waddr), 
    .dina(way0_tagv_wdata),    
    .clkb(clk),
    .addrb(way0_tagv_raddr),  
    .doutb(way0_tagv_rdata)  
    );
    tagv_dual_sram way1_tagv(
    .clka(clk),    
    .wea(way1_tagv_we),      
    .addra(way1_tagv_waddr), 
    .dina(way1_tagv_wdata),    
    .clkb(clk),
    .addrb(way1_tagv_raddr),  
    .doutb(way1_tagv_rdata)  
    );
    data_dual_sram way0_data(
    .clka(clk),    
    .wea(way0_data_we),      
    .addra(way0_data_waddr), 
    .dina(way0_data_wdata),    
    .clkb(clk),
    .addrb(way0_data_raddr),  
    .doutb(way0_data_rdata)  
    );  
    data_dual_sram way1_data(
    .clka(clk),    
    .wea(way1_data_we),      
    .addra(way1_data_waddr), 
    .dina(way1_data_wdata),    
    .clkb(clk),
    .addrb(way1_data_raddr),  
    .doutb(way1_data_rdata)  
    );  
    //reuest buffer
    always @(posedge clk) begin
        if(!resetn)
            req_buffer_index      <= 0;
        else if(pif_wen)
            req_buffer_index      <= index;
    end
    assign way0_tagv_raddr = index;
    assign way1_tagv_raddr = index;
    assign way0_data_raddr = index;
    assign way1_data_raddr = index;

    //write buffer
    always @(posedge clk) begin
        if(!resetn) begin
            wr_buffer_tagv_waddr <= 0;
            wr_buffer_tagv_wdata <= 0;
            wr_buffer_tagv_valid <= 0;
            wr_buffer_way        <= 0;
        end
        else if(state[3] && !mem_buffer_uncached) begin
            wr_buffer_tagv_waddr <= mem_buffer_index;
            wr_buffer_tagv_wdata <= mem_buffer_is_cacop ? 21'd0 : {mem_buffer_paddr[31:12],1'b1};
            wr_buffer_tagv_valid <= 1;
            wr_buffer_way        <= replace_way;
        end
        else if(state[0]) 
            wr_buffer_tagv_valid <= 0;
    end
    reg             pif_wen_buf;
    reg [20:0]      way0_tagv_rdata_reg;
    wire [20:0]     way0_tagv_addrfix_rdata;
    wire            way0_tagv_conflict;
    always @(posedge clk) begin
        if (!resetn) 
            pif_wen_buf <= 1;
        else 
            pif_wen_buf <= pif_wen;
    end
    always @(posedge clk) begin
        if(way0_tagv_conflict)
            way0_tagv_rdata_reg <= wr_buffer_tagv_wdata;
        else if(pif_wen_buf)
            way0_tagv_rdata_reg <= way0_tagv_rdata;
    end
    assign way0_tagv_addrfix_rdata = pif_wen_buf ? way0_tagv_rdata : way0_tagv_rdata_reg;
    assign way0_tagv_conflict   = wr_buffer_tagv_valid && wr_buffer_tagv_waddr == req_buffer_index && ~wr_buffer_way;
    assign way0_tagv_real_rdata = way0_tagv_conflict ? wr_buffer_tagv_wdata : way0_tagv_addrfix_rdata;
    reg [20:0]      way1_tagv_rdata_reg;
    wire [20:0]     way1_tagv_addrfix_rdata;
    wire            way1_tagv_conflict;
    always @(posedge clk) begin
        if(way1_tagv_conflict)
            way1_tagv_rdata_reg <= wr_buffer_tagv_wdata;
        else if(pif_wen_buf)
            way1_tagv_rdata_reg <= way1_tagv_rdata;
    end
    assign way1_tagv_addrfix_rdata = pif_wen_buf ? way1_tagv_rdata : way1_tagv_rdata_reg;
    assign way1_tagv_conflict   = wr_buffer_tagv_valid && wr_buffer_tagv_waddr == req_buffer_index && wr_buffer_way;
    assign way1_tagv_real_rdata = way1_tagv_conflict ? wr_buffer_tagv_wdata : way1_tagv_addrfix_rdata;

    always @(posedge clk) begin
      if(!resetn)begin
        write_buffer_data <= 0;
        write_buffer_index <= 0;
        write_buffer_way  <= 0;
        write_buffer_valid <= 0;
      end
      else if(state[3] && !mem_buffer_uncached && !mem_buffer_is_cacop) begin
        write_buffer_data <= final_receive_line;
        write_buffer_index <= mem_buffer_index;
        write_buffer_way  <= replace_way;
        write_buffer_valid  <= 1;
      end
      else if(state[0])begin
        write_buffer_valid <= 0;
      end
    end

    reg  [127:0]  way0_data_rdata_reg;   //数据保持寄存�?
    wire [127:0]  way0_data_addrfix_rdata;
    wire          way0_data_conflict;
    always @(posedge clk) begin
        if(way0_data_conflict)
            way0_data_rdata_reg <= write_buffer_data;
        else if(pif_wen_buf)
            way0_data_rdata_reg <= way0_data_rdata;
    end
    assign way0_data_addrfix_rdata = pif_wen_buf ? way0_data_rdata : way0_data_rdata_reg;
    assign way0_data_conflict = write_buffer_valid && write_buffer_index == req_buffer_index && ~write_buffer_way;
    assign way0_data_real_rdata = way0_data_conflict ? write_buffer_data : way0_data_addrfix_rdata;
    reg  [127:0]  way1_data_rdata_reg;   //数据保持寄存�?
    wire [127:0]  way1_data_addrfix_rdata;
    wire          way1_data_conflict;
    always @(posedge clk) begin
        if(way1_data_conflict)
            way1_data_rdata_reg <= write_buffer_data;
        else if(pif_wen_buf)
            way1_data_rdata_reg <= way1_data_rdata;
    end
    assign way1_data_addrfix_rdata = pif_wen_buf ? way1_data_rdata : way1_data_rdata_reg;
    assign way1_data_conflict = write_buffer_valid && write_buffer_index == req_buffer_index && write_buffer_way;
    assign way1_data_real_rdata = way1_data_conflict ? write_buffer_data : way1_data_addrfix_rdata;
    //tag cmp
    wire way0_tageq,way1_tageq;
    assign way0_tageq =  way0_tagv_real_rdata[20:1] == paddr[31:12];
    assign way1_tageq =  way1_tagv_real_rdata[20:1] == paddr[31:12];
    
    reg mem_buffer_way0_tageq,mem_buffer_way1_tageq;
    //reg mem_buffer_cache_hit;
    always @(posedge clk) begin
         if(!resetn)begin
            mem_buffer_way0_tagv        <= 0;
            mem_buffer_way0_data        <= 0;
            mem_buffer_way1_tagv        <= 0;
            mem_buffer_way1_data        <= 0;
            mem_buffer_paddr            <= 0;
            mem_buffer_uncached         <= 0;
            mem_buffer_is_cacop         <= 0;
            mem_buffer_valid            <= 0;
            mem_buffer_uncache_cacop01  <= 0;
            mem_buffer_cacop2           <= 0;
            mem_buffer_index            <= 0;
            mem_buffer_cacop01          <= 0;
            mem_buffer_cacop01_way      <= 0;
            mem_buffer_way0_tageq      <= 0;
            mem_buffer_way1_tageq      <= 0;
            //mem_buffer_cache_hit        <= 0;
        end
        else if(~stall_if_to_wb)begin
            mem_buffer_way0_tagv        <= way0_tagv_real_rdata;
            mem_buffer_way0_data        <= way0_data_real_rdata;
            mem_buffer_way1_tagv        <= way1_tagv_real_rdata;
            mem_buffer_way1_data        <= way1_data_real_rdata;
            mem_buffer_paddr            <= paddr;
            mem_buffer_uncached         <= uncached && !is_cacop;
            mem_buffer_is_cacop         <= is_cacop;
            mem_buffer_valid            <= valid;
            mem_buffer_uncache_cacop01  <= (uncached && !is_cacop) || (is_cacop & ~cacop[1]);
            mem_buffer_cacop2           <= is_cacop & cacop[1] & ~cacop[0];
            mem_buffer_index            <= req_buffer_index;
            mem_buffer_cacop01          <= is_cacop & ~cacop[1];
            mem_buffer_cacop01_way      <= cacop01_way;
            mem_buffer_way0_tageq      <= way0_tageq;
            mem_buffer_way1_tageq      <= way1_tageq;
            //mem_buffer_cache_hit        <= cache_hit;
        end else if(state[4])begin
            mem_buffer_valid            <= 0;
        end
    end
    //state
    always @(posedge clk) begin
        if(!resetn)
            state <= `LOOKUP;
        else begin
            case(state)
                `LOOKUP:begin
                    if (!cache_hit && mem_buffer_valid)
                        state <= `REPLACE;
                    else state <= `LOOKUP;
                end
                `REPLACE:begin
                    if(mem_buffer_is_cacop)
                        state <= `REFILL;
                    else if(rd_rdy)
                        state <= `REFILL; 
                    else 
                        state <= `REPLACE;
                end
                `REFILL:begin
                    if(mem_buffer_is_cacop)
                        state <= `RESPOND;
                    else if(ret_valid && ret_last == 1)
                        state <= `RESPOND;
                    else
                        state <= `REFILL;
                end
                `RESPOND:begin
                    if(stall_if_to_wb)
                        state <= `RESPOND;
                    else
                        state <= `LOOKUP;
                end
                default:begin
                    state <= `LOOKUP;
                end
            endcase
        end
    end
    //tag cmp
    assign way0_tagveq = mem_buffer_way0_tagv[0] && mem_buffer_way0_tageq;
    assign way1_tagveq = mem_buffer_way1_tagv[0] && mem_buffer_way1_tageq;
    // assign tagveq = (mem_buffer_way0_tagv[0] && mem_buffer_way0_tagveq) || (mem_buffer_way1_tagv[0] && mem_buffer_way1_tagveq);
    assign cache_hit = !(mem_buffer_uncache_cacop01) && (((way0_tagveq) || (way1_tagveq)) ^ mem_buffer_cacop2);
    assign load_word = hit_line[{mem_buffer_paddr[3:2],5'b0} +: 32];
    assign receive_word = small_receive_line[{mem_buffer_paddr[3:2],5'b0} +: 32];
    assign rdata =  {32{state[0] && cache_hit}} & load_word |
                    {32{state[4]}} & (mem_buffer_uncached ? receive_data[31:0] : receive_word);
    assign hit_line = way0_tagveq ? mem_buffer_way0_data : mem_buffer_way1_data;
    //replace
    genvar i;
    generate 
      for(i = 0 ;i<256;i=i+1) begin
        always @(posedge clk) begin
            if(!resetn) used[i] <= 0;
            else if (mem_buffer_valid && way0_tagveq && i == mem_buffer_index) used[i] <= 0;
            else if (mem_buffer_valid && way1_tagveq && i == mem_buffer_index) used[i] <= 1;
            else if ((way0_tagv_we) && i == mem_buffer_index) used[i] <= 0;
            else if ((way1_tagv_we) && i == mem_buffer_index) used[i] <= 1; 
            else used[i] <= used[i];
        end
      end
    endgenerate
    always @(posedge clk) begin
        if(!resetn) replace_way <= 0;
        else if(state[0] && !cache_hit && mem_buffer_valid)begin
            if(!mem_buffer_is_cacop) replace_way <= ~used[mem_buffer_index];
            else if(mem_buffer_cacop2) replace_way <= way1_tagveq;
            else if(mem_buffer_cacop01) replace_way <= mem_buffer_cacop01_way;
        end
    end
    //receive
    assign rd_req = state[2] && !mem_buffer_is_cacop;
    assign rd_type = mem_buffer_uncached ? 3'b010 :3'b100;
    assign rd_addr = mem_buffer_uncached ? mem_buffer_paddr :{mem_buffer_paddr[31:4],4'b0000}; 
    always @(posedge clk) begin
        if(!resetn)begin
            receive_data <= 128'd0;  
        end else if (state[3] && ret_valid) begin  
            receive_data <= receive_data << 32 | {96'd0,ret_data};   
        end
    end
    assign final_receive_line = {ret_data,receive_data[31:0],receive_data[63:32],receive_data[95:64]};
    assign small_receive_line = {receive_data[31:0],receive_data[63:32],receive_data[95:64],receive_data[127:96]};
    //control
    assign way0_tagv_we = state[3] && !mem_buffer_uncached && ~replace_way;
    assign way0_tagv_waddr = mem_buffer_index;
    assign way0_tagv_wdata = mem_buffer_is_cacop ? 21'd0 : {mem_buffer_paddr[31:12],1'b1};
    assign way1_tagv_we = state[3] && !mem_buffer_uncached && replace_way;
    assign way1_tagv_waddr = mem_buffer_index;
    assign way1_tagv_wdata = mem_buffer_is_cacop ? 21'd0 : {mem_buffer_paddr[31:12],1'b1};
    //assign way0_data_we = {16{state[3] && !mem_buffer_uncached && !mem_buffer_is_cacop && ~replace_way}};
    assign way0_data_we = state[3] && !mem_buffer_uncached && !mem_buffer_is_cacop && ~replace_way;
    assign way0_data_waddr = mem_buffer_index;
    assign way0_data_wdata = final_receive_line;
    // assign way1_data_we = {16{state[3] && !mem_buffer_uncached && !mem_buffer_is_cacop && replace_way}};
    assign way1_data_we = state[3] && !mem_buffer_uncached && !mem_buffer_is_cacop && replace_way;
    assign way1_data_waddr = mem_buffer_index;
    assign way1_data_wdata = final_receive_line;
    assign stall = mem_buffer_valid && !cache_hit && !state[4];
endmodule
