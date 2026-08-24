module PIF(
    input clk,
    input reset,

    // bpu ???
    output     [31:0] pc_query,
    input      [ 3:0] pred_taken,
    input      [127:0] pred_target,
    output     [ 3:0] predict_slot,

    // to TLB
    output   [31:0]       inst_vaddr,
    output          s0_valid,
    output [18:0]   s0_vppn,
    output          s0_va_bit12,
    output [ 9:0]   s0_asid,
    input           s0_ok,

    input  [ 9:0]   csr_asid_asid,
    input  [ 5:0]   IF_tlb_excps,
    input  [31:0]   inst_paddr,
    input           mmu_inst_uncache_en,
    input           untlb_en,
    // to FS
    output pif_to_fs_valid,
    output [`PIF_TO_FS_BUS_WD-1 : 0] pif_to_fs_bus,
    input  fs_allowin,
    // ex
    input  ex,
    input  ertn,
    input  fs_reflush,
    input  [31:0] ex_entry,
    input  [31:0] ex_era,
    input  [31:0] fs_reflush_target,
    input        idle_flush,  // ???? Commit ??
    input        has_int,
    input        if_cancel_req,
    input [31:0] if_cancel_target

);
reg idle_state;
reg [31:0] idle_pc;
always @(posedge clk) begin
      if (reset) begin
           idle_state <= 1'b0;
           idle_pc <= 32'b0;
      end 
      else if (idle_flush) begin
           idle_state <= 1'b1;  // ??? IDLE ?????????????
           idle_pc <= fs_reflush_target;
      end 
      else if (idle_state && has_int) begin
           idle_state <= 1'b0;  // ????��??????
           idle_pc <= 32'b0;
      end
end

reg cancel_pending;
reg [31:0] cancel_target_latched;

    always @(posedge clk) begin
        if (reset || fs_reflush || ex || ertn) begin
            cancel_pending <= 1'b0;
        end else if (if_cancel_req) begin
            cancel_pending <= 1'b1;
            cancel_target_latched <= if_cancel_target;
        end else if (pif_ready_go && fs_allowin) begin
            cancel_pending <= 1'b0;
        end
    end

    wire        pif_ready_go;
    wire[31:0]  nextpc;
    wire        pif_excp;
    reg [31:0]  pif_pc;
    wire [31:0] predicted_nextpc;

    wire [31:0] pred_target0 = pred_target[31:0];
    wire [31:0] pred_target1 = pred_target[63:32];
    wire [31:0] pred_target2 = pred_target[95:64];
    wire [31:0] pred_target3 = pred_target[127:96];

    wire [3:0]  slot_mask = 4'b1111 << pif_pc[3:2];
    assign predict_slot = slot_mask;
    wire [3:0]  eligible_taken = pred_taken & slot_mask;
    wire [3:0]  current_slot = 4'b0001 << pif_pc[3:2];
    wire [3:0]  active_taken = mmu_inst_uncache_en ?
                               (eligible_taken & current_slot) : eligible_taken;
    wire [3:0]  fs_pred_taken = active_taken;
    wire [3:0]  active_first_taken = active_taken[0] ? 4'b0001 :
                                     active_taken[1] ? 4'b0010 :
                                     active_taken[2] ? 4'b0100 :
                                     active_taken[3] ? 4'b1000 : 4'b0000;
    assign predicted_nextpc = active_first_taken[0] ? pred_target0 :
                              active_first_taken[1] ? pred_target1 :
                              active_first_taken[2] ? pred_target2 :
                              active_first_taken[3] ? pred_target3 :
                              mmu_inst_uncache_en   ? pif_pc + 4 :
                                                     {pif_pc[31:4], 4'b0000} + 16;
    assign pif_excp = pif_pc[0] | pif_pc[1];

always @(posedge clk) begin
        if (reset) begin
            pif_pc <= 32'h1c000000;
        end
        else if (if_cancel_req || cancel_pending || fs_reflush || (idle_state && has_int)) begin
            pif_pc <= nextpc;
        end
        else if (pif_ready_go && fs_allowin && ~idle_state) begin
            pif_pc <= nextpc;
        end
    end

    reg s0_valid_req;
    always@(posedge clk) begin
        if(reset) begin
            s0_valid_req <= 1'b0;  
        end
        else if(s0_ok) begin
            s0_valid_req <= 1'b0; 
        end
        else if(fs_allowin) begin
            s0_valid_req <= 1'b1; 
        end
    end

    assign pc_query = pif_pc;
    assign nextpc = ex        ? ex_entry      :
                    ertn      ? ex_era        :
                    idle_state && has_int ? idle_pc        :
                    fs_reflush     ? fs_reflush_target     :
                    if_cancel_req  ? if_cancel_target      : 
                    cancel_pending ? cancel_target_latched :
                    predicted_nextpc;

    assign inst_vaddr   = pif_pc;
    assign s0_valid     = s0_valid_req && ~pif_excp && ~s0_ok && ~untlb_en && ~idle_state;
    assign s0_vppn      = pif_pc[31:13];
    assign s0_va_bit12  = pif_pc[12];
    assign s0_asid      = csr_asid_asid;

    assign pif_ready_go    = s0_ok || pif_excp || untlb_en;
    assign pif_to_fs_valid = ~reset && pif_ready_go && ~fs_reflush && ~idle_state && ~if_cancel_req && ~cancel_pending;

    assign pif_to_fs_bus = {
        pif_pc,          // 32
        inst_paddr,      // 32
        fs_pred_taken,   //  4
        pred_target,     // 128
        pif_excp,        //  1
        IF_tlb_excps,    //  6
        mmu_inst_uncache_en  //  1
    }; 


endmodule
