`include "header.h"
module PIF(
    input clk,
    input reset,
    input flush,
    input br_taken,

    input [4:0]   jump_op,
    input [159:0] jump_target,

    output            PIF_valid,
    output reg [31:0] PIF_pc1,
    output     [31:0] PIF_pc2,
    input             btb_miss1,
    input             btb_miss2,
    input             pred_taken1,
    input             pred_taken2,
    input      [31:0] pred_target1,
    input      [31:0] pred_target2,
    input      [ 4:0] pred_index1,
    input      [ 4:0] pred_index2,

    input IF_stall,
    input ID_stall,
    input FIFO_stall,

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
    output [18:0] s0_vppn,
    output        s0_va_bit12,
    output [ 9:0] s0_asid,
    // to cache
    input  icache_unbusy,
    input  inst_data_ok1,
    input  inst_data_ok2,
    input  icache_hit,
    output inst_valid,
    output [ 7:0] inst_index,
    output [ 3:0] inst_offset
);

// control
    wire stall_PIF;
    wire stall_nIF;
    wire stall_icache;
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
    reg [31:0] npc_buf;
    reg [ 1:0] npc_buf_valid;
//tlb
    reg s0_ok_buf;
    reg s0_valid_reg;
    wire tlb_trans;

    reg inst_unhit_buf;
    reg pif_update;

    wire issue_mode;

// bus
    assign {ex, ertn, tlbr_ex, refetch, taken} = jump_op;
    assign {ex_entry, pc_era, refetch_pc, tlbr_entry, br_target} = jump_target;

// control
    assign stall_icache = ~(icache_unbusy | icache_hit) & access_icache;
    assign stall_PIF = ~reset & ((tlb_trans & ~(s0_ok | s0_ok_buf)) | flush | br_taken | stall_icache);
    assign stall_nIF = stall_PIF | ID_stall | FIFO_stall;
    assign stall = stall_nIF | IF_stall;
    assign PIF_IF_valid = PIF_valid & ~stall_PIF;

    assign PIF_valid  = ~npc_buf_valid[1];
    assign issue_mode = ~(PIF_pc1[3:2] == 2'b11) & ~pred_taken1 & ~mmu_inst_uncache_en;
    assign inst_valid = ~reset & access_icache & ~stall_nIF & PIF_valid;
    assign access_icache = ~flush & !PIF_pc1[1:0];
    assign {inst_index, inst_offset} = inst_vaddr[11:0];

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
        else if(pred_taken1 & ~btb_miss1) begin
            npc = pred_target1;
        end
        else if(pred_taken2 & ~btb_miss2 & issue_mode) begin
            npc = pred_target2;
        end
        else begin
            if(issue_mode) begin
                npc = PIF_pc1 + 4'b1000;
            end
            else begin
                npc = PIF_pc1 + 3'b100;
            end
            // npc = PIF_pc1 + 3'b100;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            PIF_pc1 <= 32'h1c000000;
        end 
        else if(tlb_trans) begin
            if(~stall) begin
                PIF_pc1<= npc_buf_valid[1] ? npc_buf : npc;
            end
        end
        else if((npc_buf_valid != 2'b11) & flush | !npc_buf_valid & taken | ~stall) begin
            PIF_pc1 <= npc; 
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

    assign PIF_pc2 = PIF_pc1 + 3'b100;

//TLB
    assign inst_vaddr = PIF_pc1;
    assign s0_vppn = inst_vaddr[31:13];
    assign s0_asid = csr_asid_asid;
    assign s0_va_bit12 = inst_vaddr[12];

//bus
    assign PIF_IF_bus = {
        access_icache,
        IF_tlb_excps & {3{tlb_trans}}, // 3
        inst_paddr,          // 32
        mmu_inst_uncache_en, // 1
        btb_miss1,          // 1
        btb_miss2,          // 1
        pred_index1,
        pred_index2,
        pred_taken1,        // 1
        pred_taken2 & issue_mode,        // 1
        pred_target1,       // 32
        pred_target2,       // 32
        PIF_pc1,            // 32
        PIF_pc2             // 32
    };
endmodule