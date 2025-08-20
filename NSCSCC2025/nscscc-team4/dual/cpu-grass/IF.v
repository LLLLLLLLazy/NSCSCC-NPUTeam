`include "header.h"
module IF(
    input clk,
    input reset,
    input flush,

    input ID_stall,
    input FIFO_stall,
    output IF_stall,
    input  PIF_IF_valid,
    output IF_ID_valid,
    input  [`WIDTH_PIF_IF_BUS-1 : 0] PIF_IF_bus,
    output [`WIDTH_IF_ID_BUS -1 : 0] IF_ID_bus1,
    output [`WIDTH_IF_ID_BUS -1 : 0] IF_ID_bus2,

    // with icache
    output inst_uncache_en,   
    output IF_inst_cancel_req,
    input  inst_data_ok1,
    input  inst_data_ok2,
    output [19:0] inst_tag,
    input  [31:0] inst_rdata1,
    input  [31:0] inst_rdata2,
    input         icache_miss
);
//excps
    //0  INT        ID
    //1  ADEF       IF
    //2  TLBR       IF inst tlb ex
    //3  PIF        IF
    //4  PPI        IF
    //5  syscall    ID
    //6  BRK        ID
    //7  INE        ID
    //8  IPE        ID
    //9  ALE        EX
    //10 TLBR       EX data tlb ex
    //11 PME        EX
    //12 PPI        EX
    //13 PIS        EX
    //14 PIL        EX


// bus
    reg [`WIDTH_PIF_IF_BUS-1 : 0] PIF_IF_reg;
    wire btb_miss1;
    wire btb_miss2;
    wire pred_taken1;
    wire pred_taken2;
    wire [31:0] pred_target1;
    wire [31:0] pred_target2;
    wire [ 4:0] pred_index1;
    wire [ 4:0] pred_index2;

    wire [2:0] IF_tlb_excps;
    wire [31:0] inst_paddr;
    wire mmu_inst_uncache_en;

// control
    reg IF_valid;
    wire stall;
    wire stall_inst1;
    wire stall_inst2;
    
    wire [31:0] IF_pc1;
    wire [31:0] IF_pc2;

    reg finish_hs;
    reg flush_cancel;

    wire PIF_access_icache;
    wire access_icache;

//inst
    wire inst1_valid;
    wire inst2_valid;

    wire [31:0] IF_inst1;
    wire [31:0] IF_inst2;

    reg inst_buf_valid1;
    reg inst_buf_valid2;
    reg  [31:0] inst_buf1;
    reg  [31:0] inst_buf2;

//ex
    wire [14:0] excp_num1;
    wire [14:0] excp_num2;
    wire IF_adef_ex1;
    wire IF_adef_ex2;

//bus
    always@(posedge clk) begin
        if(reset) begin
            PIF_IF_reg <= `WIDTH_PIF_IF_BUS'b0;
        end
        else if(~stall) begin
            PIF_IF_reg <= PIF_IF_bus;
        end
    end

    assign {
            PIF_access_icache,
            IF_tlb_excps,
            inst_paddr,
            mmu_inst_uncache_en,
            btb_miss1,
            btb_miss2,
            pred_index1,
            pred_index2,
            pred_taken1,
            pred_taken2,
            pred_target1,
            pred_target2,
            IF_pc1,
            IF_pc2
            } = PIF_IF_reg;


// control
    assign IF_stall = ~reset & (stall_inst1 || stall_inst2);
    assign access_icache = PIF_access_icache & ~(|IF_tlb_excps);
    assign stall_inst1 = IF_valid & access_icache & ~inst_data_ok1 & ~inst_buf_valid1;
    assign stall_inst2 = IF_valid & access_icache & ~inst_data_ok2 & ~inst_buf_valid2 & inst2_valid;
    assign stall = IF_stall || ID_stall || FIFO_stall;
    assign IF_ID_valid = IF_valid & ~IF_stall;

    always@(posedge clk) begin
        if(reset | flush) begin
            IF_valid <= 1'b0;
        end
        else if(~stall) begin
            IF_valid <= PIF_IF_valid;
        end
    end

    always@(posedge clk) begin
        if(reset | ~stall) begin
            flush_cancel <= 1'b0;
        end
        else if(flush) begin
            flush_cancel <= 1'b1;
        end
    end
//inst
    assign inst1_valid = 1'b1;
    // assign inst2_valid = 1'b0;
    assign inst2_valid = ~(IF_pc1[3:2] == 2'b11 || mmu_inst_uncache_en) & ~pred_taken1;
    assign IF_inst1 = {32{ inst_buf_valid1}}  & inst_buf1 |
                      {32{~inst_buf_valid1}}  & inst_rdata1;
    assign IF_inst2 = {32{ inst_buf_valid2}}  & inst_buf2 |
                      {32{~inst_buf_valid2}}  & inst_rdata2;
    always@(posedge clk) begin
        if(reset) begin
            inst_buf1 <= 32'b0;
            inst_buf_valid1 <= 1'b0;
        end
        else if(inst_data_ok1 & (ID_stall || FIFO_stall || stall_inst2)) begin
            inst_buf1 <= inst_rdata1;
            inst_buf_valid1 <= 1'b1;
        end
        else if(~stall) begin
            inst_buf_valid1 <= 1'b0;
        end
    end
    always@(posedge clk) begin
        if(reset) begin
            inst_buf2 <= 32'b0;
            inst_buf_valid2 <= 1'b0;
        end
        else if(inst_data_ok2 & (ID_stall || FIFO_stall)) begin
            inst_buf2 <= inst_rdata2;
            inst_buf_valid2 <= 1'b1;
        end
        else if(~stall) begin
            inst_buf_valid2 <= 1'b0;
        end
    end

// cache
    assign inst_tag = inst_paddr[31:12];

    assign IF_inst_cancel_req = (|IF_tlb_excps) | flush_cancel;
    assign inst_uncache_en = mmu_inst_uncache_en & IF_valid;

//ex
    assign IF_adef_ex1 = IF_pc1[1:0] != 2'b00;
    assign IF_adef_ex2 = IF_pc2[1:0] != 2'b00;
    assign excp_num1 = {
        10'b0,
        IF_tlb_excps,
        IF_adef_ex1,
        1'b0
    };
    assign excp_num2 = {
        10'b0,
        IF_tlb_excps,
        IF_adef_ex2,
        1'b0
    };
//bus
    assign IF_ID_bus1 = {
        icache_miss,
        inst1_valid,
        btb_miss1,
        pred_index1,
        pred_taken1,
        pred_target1,
        excp_num1,
        IF_inst1,
        IF_pc1
    };
    assign IF_ID_bus2 = {
        inst2_valid,
        btb_miss2,
        pred_index2,
        pred_taken2,
        pred_target2,
        excp_num2,
        IF_inst2,
        IF_pc2
    };
endmodule