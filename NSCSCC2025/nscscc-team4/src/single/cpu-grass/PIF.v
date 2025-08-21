`include "header.h"
module PIF(
    input clk,
    input reset,
    input flush,

    input [4:0]   jump_op,
    input [159:0] jump_target,

    output reg [31:0] PIF_pc,
    input             btb_miss,
    input             pred_taken,
    input      [31:0] pred_target,

    input IF_stall,
    input ID_stall,
    input EX_stall,
    input MEM_stall,
    output PIF_IF_valid,
    output [`WIDTH_PIF_IF_BUS-1 : 0] PIF_IF_bus,

    input  [ 9:0] csr_asid_asid,
    input  [ 2:0] IF_tlb_excps,
    output [31:0] inst_vaddr,
    input  [31:0] inst_paddr,
    input         mmu_inst_uncache_en,  
    // to TLB
    input  inst_unhit,
    output s0_valid,
    input  s0_ok,
    input  s0_unbusy,
    output [18:0] s0_vppn,
    output        s0_va_bit12,
    output [ 9:0] s0_asid
);

// control
    wire PIF_valid;
    wire stall_PIF;
    wire stall;
    
// jump
    wire ex;
    wire ertn;
    wire tlbr_ex;
    wire refetch;
    wire taken;

    wire [31:0] ex_entry;
    wire [31:0] pc_era;
    wire [31:0] refetch_pc;
    wire [31:0] tlbr_entry;
    wire [31:0] br_target;

//next_pc
    reg  [31:0] npc;
    reg has_flushed;
    reg [31:0] npc_buf;
    reg [1:0] npc_buf_valid;
//tlb
    reg s0_ok_buf;
    reg s0_valid_reg;
    wire tlb_trans;

    reg inst_unhit_buf;
    reg pif_update;
// bus
    assign {ex, ertn, tlbr_ex, refetch, taken} = jump_op;
    assign {ex_entry, pc_era, refetch_pc, tlbr_entry, br_target} = jump_target;

// control
    assign stall_PIF = ~reset & (tlb_trans & (~(s0_ok | s0_ok_buf) | flush | taken)); //由于buf的性质，在trans模式中，结尾如果刚好是flush或者taken需要多阻塞一个周期完成buf的更新
    assign stall = stall_PIF | IF_stall | ID_stall | EX_stall | MEM_stall;
    assign PIF_IF_valid = PIF_valid & ~stall_PIF;

    assign PIF_valid = tlb_trans & ~npc_buf_valid[1] | ~tlb_trans;

//pc
    always@(*) begin
        if(tlbr_ex) begin
            npc = tlbr_entry;
        end
        else if(ex) begin
            npc = ex_entry;
        end
        else if(ertn) begin
            npc = pc_era;
        end
        else if(refetch) begin
            npc = refetch_pc + 4;
        end
        else if(taken) begin
            npc = br_target;
        end
        else if(pred_taken & ~btb_miss) begin
            npc = pred_target;
        end
        else begin
            npc = PIF_pc + 4;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            PIF_pc <= 32'h1c000000;
        end 
        else if(tlb_trans) begin
            if(~stall) begin
                PIF_pc <= npc_buf_valid[1] ? npc_buf : npc;
            end
        end
        else if((npc_buf_valid != 2'b11) & flush | !npc_buf_valid & taken | ~stall) begin
            PIF_pc <= npc_buf_valid[1] ? npc_buf : npc; 
        end
    end

    assign s0_valid  = ~reset & s0_valid_reg & ~(s0_ok | s0_ok_buf) & tlb_trans;
    assign tlb_trans = pif_update & inst_unhit | ~pif_update & inst_unhit_buf; // 保证一个pc只有一个tlb_trans

    always@(posedge clk) begin
        if(reset) begin
            inst_unhit_buf <= 1'b0;
        end
        else if(pif_update) begin
            inst_unhit_buf <= inst_unhit;
        end

        if(reset) begin
            pif_update <= 1'b0;
        end
        else if(~stall | ~tlb_trans & ((npc_buf_valid != 2'b11) & flush | !npc_buf_valid & taken)) begin
            pif_update <= 1'b1;
        end
        else begin
            pif_update <= 1'b0;
        end
    end
 
    always@(posedge clk) begin
        if(reset) begin
            s0_ok_buf <= 1'b0;
            s0_valid_reg <= 1'b1;
        end
        else if(~stall) begin
            s0_valid_reg <= 1'b1;
            s0_ok_buf <= 1'b0;
        end
        else if(s0_ok) begin
            s0_valid_reg <= 1'b0;
            s0_ok_buf <= 1'b1;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            npc_buf <= 32'b0;
            npc_buf_valid <= 2'b00;
        end
        else if(tlb_trans) begin
            if(flush & ~npc_buf_valid[0]) begin
                npc_buf <= npc;
                npc_buf_valid <= 2'b11;
            end
            else if(taken & !npc_buf_valid) begin
                npc_buf <= npc;
                npc_buf_valid <= 2'b10;
            end
            else if(~stall) begin
                npc_buf_valid <= 2'b00;
            end            
        end
    end

//TLB
    assign inst_vaddr = PIF_pc;
    assign s0_vppn = inst_vaddr[31:13];
    assign s0_asid = csr_asid_asid;
    assign s0_va_bit12 = inst_vaddr[12];
//bus
    assign PIF_IF_bus = {
        IF_tlb_excps & {3{tlb_trans}},        // 3
        inst_paddr,          // 32
        mmu_inst_uncache_en, // 1
        btb_miss,            // 1
        pred_taken,          // 1
        pred_target,         // 32
        PIF_pc               // 32
    };
endmodule