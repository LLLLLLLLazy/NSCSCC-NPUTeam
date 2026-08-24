`include "mycpu.h"

module store_buffer #(parameter DEPTH_WD = 3) (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    // Enqueue from EXE
    input  wire        enq_valid,
    input  wire [31:0] enq_addr,
    input  wire [31:0] enq_wdata,
    input  wire [ 3:0] enq_wstrb,
    input  wire        enq_uncache_en,
    input  wire [ 1:0] enq_size,
    output wire        sb_full,
    output wire        sb_almost_full,
    output wire        sb_empty,
    input  wire        ms_mem_we,

    // Commit ptr advance
    input  wire   [1:0]     commit_st_en,

    // Write to Data SRAM port
    output wire        sram_req,
    output wire [31:0] sram_addr,
    output wire [31:0] sram_wdata,
    output wire [ 3:0] sram_wstrb,
    output wire [ 1:0] sram_size,
    output wire        sram_uncache_en,
    input  wire        sram_addr_ok,
    input  wire        data_sram_en,
    input  wire        es_sb_valid,
    input  wire        sram_data_ok,

    // Store-to-Load Forwarding port
    input  wire        load_req,
    input  wire [31:0] load_addr,
    output wire [31:0] fwd_data,
    output wire [ 3:0] fwd_strb,
    input wire ms_allowin,
    input wire ms_valid
);
    localparam DEPTH = 1 << DEPTH_WD;

    // Store entry array
    (* ram_style = "registers" *) reg [31:0] sb_addr  [DEPTH-1:0];
    (* ram_style = "registers" *) reg [31:0] sb_wdata [DEPTH-1:0];
    (* ram_style = "registers" *) reg [ 3:0] sb_wstrb [DEPTH-1:0];
    (* ram_style = "registers" *) reg [ 1:0] sb_size  [DEPTH-1:0];
    (* ram_style = "registers" *) reg        sb_uncache_en [DEPTH-1:0];

    // Pointers
    reg [DEPTH_WD:0] head;
    reg [DEPTH_WD:0] commit_ptr;
    reg [DEPTH_WD:0] tail;

    // Timing opt: valid entry counter, NO dynamic subtraction on timing path
    reg [DEPTH_WD:0] entry_cnt;
    assign sb_full        = (entry_cnt == DEPTH);
    assign sb_almost_full = (entry_cnt == DEPTH - 1'b1);
    assign sb_empty       = (entry_cnt == 0);

    wire has_committed_store = (head != commit_ptr);

    wire enq_fire   = enq_valid && !sb_full;
    wire drain_fire = ms_mem_we && sram_data_ok;

    // SRAM output assign
    assign sram_req   = has_committed_store  & (!ms_mem_we||!ms_valid);
    assign sram_addr  = sb_addr[head[DEPTH_WD-1:0]];
    assign sram_wdata = sb_wdata[head[DEPTH_WD-1:0]];
    assign sram_wstrb = sb_wstrb[head[DEPTH_WD-1:0]];
    assign sram_size  = sb_size[head[DEPTH_WD-1:0]];
    assign sram_uncache_en = sb_uncache_en[head[DEPTH_WD-1:0]];

    always @(posedge clk) begin
        if (reset) begin
            head       <= 0;
            commit_ptr <= 0;
            tail       <= 0;
            entry_cnt  <= 0;
        end else begin
            if (flush) begin
                tail      <= commit_ptr + commit_st_en;
                entry_cnt <= commit_ptr + commit_st_en - head;
            end 
            else begin
                // Enqueue only
                if (enq_fire && !drain_fire) begin
                    sb_addr[tail[DEPTH_WD-1:0]]  <= enq_addr;
                    sb_wdata[tail[DEPTH_WD-1:0]] <= enq_wdata;
                    sb_wstrb[tail[DEPTH_WD-1:0]] <= enq_wstrb;
                    sb_size[tail[DEPTH_WD-1:0]]  <= enq_size;
                    sb_uncache_en[tail[DEPTH_WD-1:0]] <= enq_uncache_en;
                    tail <= tail + 1'b1;
                    entry_cnt <= entry_cnt + 1'b1;
                end
                // Simultaneous enqueue & dequeue, count unchanged
                else if (enq_fire && drain_fire) begin
                    sb_addr[tail[DEPTH_WD-1:0]]  <= enq_addr;
                    sb_wdata[tail[DEPTH_WD-1:0]] <= enq_wdata;
                    sb_wstrb[tail[DEPTH_WD-1:0]] <= enq_wstrb;
                    sb_size[tail[DEPTH_WD-1:0]]  <= enq_size;
                    sb_uncache_en[tail[DEPTH_WD-1:0]] <= enq_uncache_en;
                    tail <= tail + 1'b1;
                    head <= head + 1'b1;
                end
                // Dequeue only
                else if (!enq_fire && drain_fire) begin
                    head <= head + 1'b1;
                    entry_cnt <= entry_cnt - 1'b1;
                end
            end

            if (commit_st_en != 0) begin
                commit_ptr <= commit_ptr + commit_st_en;
            end
        end
    end

reg [31:0] comb_fwd_data;
reg [ 3:0] comb_fwd_strb;
    
// ??????????????��???????? (?????????????????????????????)
wire [DEPTH_WD:0] valid_count = tail - head; 
    
integer i;
reg [DEPTH_WD-1:0] ptr;
//??? MMIO ?????????(confreg.v??��???)???????????��????????????????????store_buffer???????   
always @(*) begin
        // ???????????????????
        comb_fwd_data = 32'd0;
        comb_fwd_strb = 4'd0;
    if (load_req) begin
            // ?? 0 ???????????????? if (i < valid_count) ???????????��??
            for (i = 0; i < DEPTH; i = i + 1) begin
                if (i < valid_count) begin
                    // ???????????????? (???????????)
                    // ??? DEPTH ?? 2 ????��?????????????? DEPTH_WD ��
                    ptr = head[DEPTH_WD-1:0] + i[DEPTH_WD-1:0]; 
                    
                    // ????????[31:2]??????????"????"
                    if (sb_addr[ptr][31:2] == load_addr[31:2]) begin
                        // ??????????????????��??????????????????????? Store ?????????? Store ��?????????
                        if (sb_wstrb[ptr][0]) begin 
                            comb_fwd_data[ 7: 0] = sb_wdata[ptr][ 7: 0]; 
                            comb_fwd_strb[0] = 1'b1; 
                        end
                        if (sb_wstrb[ptr][1]) begin 
                            comb_fwd_data[15: 8] = sb_wdata[ptr][15: 8]; 
                            comb_fwd_strb[1] = 1'b1; 
                        end
                        if (sb_wstrb[ptr][2]) begin 
                            comb_fwd_data[23:16] = sb_wdata[ptr][23:16]; 
                            comb_fwd_strb[2] = 1'b1; 
                        end
                        if (sb_wstrb[ptr][3]) begin 
                            comb_fwd_data[31:24] = sb_wdata[ptr][31:24]; 
                            comb_fwd_strb[3] = 1'b1; 
                        end
                    end
                end
            end
        end
    end

reg [31:0] fwd_data_r;
reg [ 3:0] fwd_strb_r;
always @(posedge clk) begin
    if(reset) begin
        fwd_data_r <= 32'd0;
        fwd_strb_r <= 4'd0;
    end else if (ms_allowin) begin
        fwd_data_r <= comb_fwd_data;
        fwd_strb_r <= comb_fwd_strb;
    end
end

assign fwd_data = fwd_data_r;
assign fwd_strb = fwd_strb_r;

endmodule
