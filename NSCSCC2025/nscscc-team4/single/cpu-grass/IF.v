`include "header.h"
module IF(
    input clk,
    input reset,
    input flush,

    input ID_stall,
    input EX_stall,
    input MEM_stall,
    output IF_stall,
    input  PIF_IF_valid,
    output reg IF_valid,
    output IF_ID_valid,
    input  [`WIDTH_PIF_IF_BUS-1 : 0] PIF_IF_bus,
    output [`WIDTH_IF_ID_BUS -1 : 0] IF_ID_bus,

    // with icache
    output inst_uncache_en,   
    output inst_tlb_excp_cancel_req,
    output inst_valid,
    input  inst_addr_ok,
    input  inst_data_ok,
    output [ 7:0] inst_index,
    output [19:0] inst_tag,
    output [ 3:0] inst_offset,
    input  [31:0] inst_rdata
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
    wire [2:0] IF_tlb_excps;
    wire [31:0] inst_paddr;
    wire mmu_inst_uncache_en;
    wire [31:0] inst_vaddr;

// bus
    reg [`WIDTH_PIF_IF_BUS-1 : 0] PIF_IF_reg;
    wire btb_miss;
    wire pred_taken;
    wire [31:0] pred_target;

// control
    wire stall;
    
    wire [31:0] IF_pc;

    reg finish_hs;

//inst
    wire [31:0] IF_inst;

    reg inst_buf_valid;
    reg  [31:0] inst_buf;

//ex
    wire [14:0] excp_num;
    wire IF_adef_ex;

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
            IF_tlb_excps,
            inst_paddr,
            mmu_inst_uncache_en,
            btb_miss,
            pred_taken,
            pred_target,
            IF_pc
            } = PIF_IF_reg;



// control
    assign IF_stall = reset ? 1'b0 : (~inst_data_ok & ~inst_buf_valid);
    assign stall = IF_stall || ID_stall || EX_stall || MEM_stall;
    assign IF_ID_valid = IF_valid & ~IF_stall;

    always@(posedge clk) begin
        if(reset | flush) begin
            IF_valid <= 1'b0;
        end
        else if(~stall) begin
            IF_valid <= PIF_IF_valid;
        end
    end


//inst
    assign IF_inst = {32{inst_buf_valid}}  & inst_buf |
                     {32{~inst_buf_valid}} & inst_rdata;
    always@(posedge clk) begin
        if(reset) begin
            inst_buf <= 32'b0;
            inst_buf_valid <= 1'b0;
        end
        else if(inst_data_ok & stall) begin
            inst_buf <= inst_rdata;
            inst_buf_valid <= 1'b1;
        end
        else if(~stall) begin
            inst_buf_valid <= 1'b0;
        end
    end

// cache
    assign inst_tag = inst_paddr[31:12];
    assign inst_offset = inst_vaddr[3:0];
    assign inst_index  = inst_vaddr[11:4];
    assign inst_vaddr = IF_pc;
    assign inst_valid = ~finish_hs;
    assign inst_tlb_excp_cancel_req = |IF_tlb_excps;
    assign inst_uncache_en = mmu_inst_uncache_en & IF_valid;

    always@(posedge clk) begin
        if(reset) begin
            finish_hs <= 1'b0;  
        end
        else if(inst_valid & inst_addr_ok) begin
            finish_hs <= 1'b1; 
        end
        else if(~stall) begin
            finish_hs <= 1'b0; 
        end
    end

//ex
    assign IF_adef_ex = IF_pc[1:0] != 2'b00;
    assign excp_num = {
        10'b0,
        IF_tlb_excps,
        IF_adef_ex,
        1'b0
    };
//bus
    assign IF_ID_bus = {
        btb_miss,
        pred_taken,
        pred_target,
        excp_num,
        IF_inst,
        IF_pc
    };
endmodule