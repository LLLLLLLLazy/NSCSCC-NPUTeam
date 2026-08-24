module bp_unit #(
    parameter ADDR_WIDTH       = 32,
    parameter INDEX_BITS       = 6,
    parameter HIST_BITS        = 8,
    parameter RAS_DEPTH_BITS   = 4
) (
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     flush,
    input  wire [ADDR_WIDTH-1:0]    pc_query,
    output wire [3:0]               pred_taken,
    output wire [4*ADDR_WIDTH-1:0]  pred_target,
    input  wire [3:0]               predict_slot,
    input  wire                     update_en,
    input  wire [ADDR_WIDTH-1:0]    pc_update,
    input  wire                     actual_taken,
    input  wire                     exec_update_en,
    input  wire [ADDR_WIDTH-1:0]    pc_exec,
    input  wire [ADDR_WIDTH-1:0]    target_exec,
    input  wire [1:0]               branch_type_exec
);

    // ---- Fetch group: 4 consecutive PCs starting at aligned group_pc ----
    wire [ADDR_WIDTH-1:0] group_pc = {pc_query[ADDR_WIDTH-1:4], 4'b0000};
    wire [ADDR_WIDTH-1:0] query0 = group_pc;
    wire [ADDR_WIDTH-1:0] query1 = group_pc + 4;
    wire [ADDR_WIDTH-1:0] query2 = group_pc + 8;
    wire [ADDR_WIDTH-1:0] query3 = group_pc + 12;

    // ---- RAS push addresses (CALL: push PC+4) ----
    wire [ADDR_WIDTH-1:0] push_addr0, push_addr1, push_addr2, push_addr3;
    assign push_addr0 = query0 + 4;
    assign push_addr1 = query1 + 4;
    assign push_addr2 = query2 + 4;
    assign push_addr3 = query3 + 4;

    // =========================================================================
    // BTB: provides target address, branch type, RAS push/pop, and hit signals.
    // Direction prediction is now handled by BHT+PHT (local history predictor).
    // BTB updates (target/type allocation) come from EXE stage via exec_update_en.
    // =========================================================================
    wire [3:0] btb_hit;
    wire [3:0] ras_push;
    wire [3:0] ras_pop;
    wire [ADDR_WIDTH-1:0] target0, target1, target2, target3;

    btb #(.ADDR_WIDTH(ADDR_WIDTH), .INDEX_BITS(INDEX_BITS)) u_btb (
        .clk(clk), .reset(reset),
        .pc_query0(query0), .pc_query1(query1),
        .pc_query2(query2), .pc_query3(query3),
        .btb_hit(btb_hit),
        .btb_target0(target0), .btb_target1(target1),
        .btb_target2(target2), .btb_target3(target3),
        .ras_push(ras_push), .ras_pop(ras_pop),
        .update_en(exec_update_en), .pc_update(pc_exec),
        .target_update(target_exec), .branch_type_update(branch_type_exec)
    );

    // =========================================================================
    // BHT: Branch History Table — per-branch local history shift registers.
    // Indexed by PC (same index bits as BTB), stores patterns of recent outcomes.
    // Updated at commit time (update_en), shifting in actual_taken.
    // =========================================================================
    wire [HIST_BITS-1:0] bht_history0, bht_history1, bht_history2, bht_history3;
    wire [HIST_BITS-1:0] bht_update_history;  // old pattern for PHT update

    bht #(.ADDR_WIDTH(ADDR_WIDTH), .INDEX_BITS(INDEX_BITS), .HIST_BITS(HIST_BITS)) u_bht (
        .clk(clk), .reset(reset),
        .pc_query0(query0), .pc_query1(query1),
        .pc_query2(query2), .pc_query3(query3),
        .history0(bht_history0), .history1(bht_history1),
        .history2(bht_history2), .history3(bht_history3),
        .update_history(bht_update_history),
        .update_en(update_en), .pc_update(pc_update),
        .actual_taken(actual_taken)
    );

    // =========================================================================
    // PHT: Pattern History Table — 2-bit saturating counters indexed by the
    // local history pattern from BHT.
    // Query: use BHT history patterns. Update: use OLD history (before BHT shift).
    // =========================================================================
    wire [1:0] pht_counter0, pht_counter1, pht_counter2, pht_counter3;

    pht #(.HIST_BITS(HIST_BITS)) u_pht (
        .clk(clk), .reset(reset),
        .query_pattern0(bht_history0), .query_pattern1(bht_history1),
        .query_pattern2(bht_history2), .query_pattern3(bht_history3),
        .counter0(pht_counter0), .counter1(pht_counter1),
        .counter2(pht_counter2), .counter3(pht_counter3),
        .update_en(update_en),
        .update_pattern(bht_update_history),
        .actual_taken(actual_taken)
    );

    // =========================================================================
    // Predicted direction from PHT: MSB of 2-bit counter
    // =========================================================================
    wire [3:0] pht_taken;
    assign pht_taken[0] = pht_counter0[1];
    assign pht_taken[1] = pht_counter1[1];
    assign pht_taken[2] = pht_counter2[1];
    assign pht_taken[3] = pht_counter3[1];

    // =========================================================================
    // RAS (Return Address Stack)
    // =========================================================================
    wire [ADDR_WIDTH-1:0] ras_top;
    wire ras_empty;
    wire [3:0] selected_push = (predict_slot & ras_push);
    wire [3:0] selected_pop  = (predict_slot & ras_pop);
    wire push_en = |selected_push;
    wire pop_en = |selected_pop;
    wire [ADDR_WIDTH-1:0] selected_push_addr =
        selected_push[0] ? push_addr0 :
        selected_push[1] ? push_addr1 :
        selected_push[2] ? push_addr2 : push_addr3;

    ras #(.ADDR_WIDTH(ADDR_WIDTH), .DEPTH_BITS(RAS_DEPTH_BITS)) u_ras (
        .clk(clk), .reset(reset), .flush(flush),
        .push_en(push_en),
        .push_addr(selected_push_addr),
        .pop_en(pop_en),
        .ras_top(ras_top), .ras_empty(ras_empty)
    );

    // =========================================================================
    // Final prediction assembly
    //   ras_push:         CALL  — predict taken, target from BTB
    //   return_prediction: RET   — predict taken, target from RAS
    //   btb_hit & pht:    other branches — BTB hit + PHT direction
    // =========================================================================
    wire [3:0] return_prediction = ras_pop & {4{!ras_empty}};

    assign pred_taken = ras_push | return_prediction | (btb_hit & pht_taken);

    assign pred_target[31:0]   = return_prediction[0] ? ras_top : target0;
    assign pred_target[63:32]  = return_prediction[1] ? ras_top : target1;
    assign pred_target[95:64]  = return_prediction[2] ? ras_top : target2;
    assign pred_target[127:96] = return_prediction[3] ? ras_top : target3;

endmodule
