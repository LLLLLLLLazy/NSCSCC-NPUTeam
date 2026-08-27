`include "header.v"

module dispatch_ctrl (
        input  wire       clear,
        input  wire [3:0] in_valid,
        input  wire [3:0] in_is_exception,
        input  wire [2:0] in_sel_issue_queue_0,
        input  wire [2:0] in_sel_issue_queue_1,
        input  wire [2:0] in_sel_issue_queue_2,
        input  wire [2:0] in_sel_issue_queue_3,

        input  wire [3:0] alu_dispatch_ready,
        input  wire [3:0] md_dispatch_ready,
        input  wire       privilege_dispatch_ready,
        input  wire [3:0] rob_alloc_ready,
        input  wire [`LSU_ISSUE_QUEUE_COUNT_WIDTH-1:0] lsu_count,
        input  wire [`FAST_ISSUE_QUEUE_COUNT_WIDTH-1:0] fast_count,

        output wire [3:0] out_ready,
        output wire [3:0] dispatch_fire,
        output wire [3:0] alu_dispatch_valid,
        output wire [3:0] lsu_dispatch_valid,
        output wire [3:0] md_dispatch_valid,
        output wire [3:0] fast_dispatch_valid,
        output wire       privilege_dispatch_valid,
        output wire [3:0] rob_alloc_valid,

        output wire [3:0] lsu_bias_valid,
        output wire [3:0] fast_bias_valid
    );

    wire [2:0] sel_issue_queue [3:0];
    wire [3:0] is_alu;
    wire [3:0] is_lsu;
    wire [3:0] is_md;
    wire [3:0] is_fast;
    wire [3:0] is_no_queue;
    wire [`LSU_ISSUE_QUEUE_COUNT_WIDTH:0] lsu_res_count;
    wire [`FAST_ISSUE_QUEUE_COUNT_WIDTH:0] fast_res_count;
    wire [`LSU_ISSUE_QUEUE_COUNT_WIDTH:0] lsu_need_0;
    wire [`LSU_ISSUE_QUEUE_COUNT_WIDTH:0] lsu_need_1;
    wire [`LSU_ISSUE_QUEUE_COUNT_WIDTH:0] lsu_need_2;
    wire [`LSU_ISSUE_QUEUE_COUNT_WIDTH:0] lsu_need_3;
    wire [`FAST_ISSUE_QUEUE_COUNT_WIDTH:0] fast_need_0;
    wire [`FAST_ISSUE_QUEUE_COUNT_WIDTH:0] fast_need_1;
    wire [`FAST_ISSUE_QUEUE_COUNT_WIDTH:0] fast_need_2;
    wire [`FAST_ISSUE_QUEUE_COUNT_WIDTH:0] fast_need_3;
    wire [3:0] slot_resource_ready;
    wire [3:0] lane_allow;

    assign sel_issue_queue[0] = in_sel_issue_queue_0;
    assign sel_issue_queue[1] = in_sel_issue_queue_1;
    assign sel_issue_queue[2] = in_sel_issue_queue_2;
    assign sel_issue_queue[3] = in_sel_issue_queue_3;

    genvar lane;
    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : gen_route
            assign is_alu[lane] =
                   sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_INTEGER;
            assign is_lsu[lane] =
                   (sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_LOAD) ||
                   (sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_STORE);
            assign is_md[lane] =
                   (sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_MD) ||
                   (sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_BRQ);
            assign is_fast[lane] =
                   sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_FAST;
            assign is_no_queue[lane] =
                   sel_issue_queue[lane] == `SEL_ISSUE_QUEUE_NO;
        end
    endgenerate

    // LSU and Fast queues compact sparse routed lanes.  Their capacity check
    // uses the number of same-queue requests up to the current lane.
    assign lsu_need_0 = {{`LSU_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
                         is_lsu[0]};
    assign lsu_need_1 = lsu_need_0 +
           {{`LSU_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
            is_lsu[1]};
    assign lsu_need_2 = lsu_need_1 +
           {{`LSU_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
            is_lsu[2]};
    assign lsu_need_3 = lsu_need_2 +
           {{`LSU_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
            is_lsu[3]};
    assign fast_need_0 = {{`FAST_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
                          is_fast[0]};
    assign fast_need_1 = fast_need_0 +
           {{`FAST_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
            is_fast[1]};
    assign fast_need_2 = fast_need_1 +
           {{`FAST_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
            is_fast[2]};
    assign fast_need_3 = fast_need_2 +
           {{`FAST_ISSUE_QUEUE_COUNT_WIDTH{1'b0}},
            is_fast[3]};

    assign lsu_res_count = `LSU_ISSUE_QUEUE_DEPTH - lsu_count;
    assign fast_res_count = `FAST_ISSUE_QUEUE_DEPTH - fast_count;

    assign slot_resource_ready[0] = rob_alloc_ready[0] &&
           (in_is_exception[0] || is_no_queue[0] ||
            (is_alu[0] && alu_dispatch_ready[0]) ||
            (is_lsu[0] && lsu_res_count >= lsu_need_0) ||
            (is_md[0] && md_dispatch_ready[0]) ||
            (is_fast[0] && fast_res_count >= fast_need_0) ||
            ((sel_issue_queue[0] == `SEL_ISSUE_QUEUE_PRIVILIEGE) &&
             privilege_dispatch_ready));
    assign slot_resource_ready[1] = rob_alloc_ready[1] &&
           (in_is_exception[1] || is_no_queue[1] ||
            (is_alu[1] && alu_dispatch_ready[1]) ||
            (is_lsu[1] && lsu_res_count >= lsu_need_1) ||
            (is_md[1] && md_dispatch_ready[1]) ||
            (is_fast[1] && fast_res_count >= fast_need_1));
    assign slot_resource_ready[2] = rob_alloc_ready[2] &&
           (in_is_exception[2] || is_no_queue[2] ||
            (is_alu[2] && alu_dispatch_ready[2]) ||
            (is_lsu[2] && lsu_res_count >= lsu_need_2) ||
            (is_md[2] && md_dispatch_ready[2]) ||
            (is_fast[2] && fast_res_count >= fast_need_2));
    assign slot_resource_ready[3] = rob_alloc_ready[3] &&
           (in_is_exception[3] || is_no_queue[3] ||
            (is_alu[3] && alu_dispatch_ready[3]) ||
            (is_lsu[3] && lsu_res_count >= lsu_need_3) ||
            (is_md[3] && md_dispatch_ready[3]) ||
            (is_fast[3] && fast_res_count >= fast_need_3));

    assign lane_allow[0] = slot_resource_ready[0];
    assign lane_allow[1] = slot_resource_ready[1];
    assign lane_allow[2] = slot_resource_ready[2];
    assign lane_allow[3] = slot_resource_ready[3];

    // Acceptance is always a low-lane prefix, preserving program order and
    // making ROB/issue-queue allocation an atomic event for every lane.
    assign out_ready[0] = lane_allow[0];
    assign out_ready[1] = lane_allow[0] && lane_allow[1];
    assign out_ready[2] = lane_allow[0] && lane_allow[1] &&
           lane_allow[2];
    assign out_ready[3] = lane_allow[0] && lane_allow[1] &&
           lane_allow[2] && lane_allow[3];

    assign dispatch_fire = in_valid & out_ready;
    assign alu_dispatch_valid = dispatch_fire & is_alu & ~in_is_exception;
    assign lsu_dispatch_valid = dispatch_fire & is_lsu & ~in_is_exception;
    assign md_dispatch_valid = dispatch_fire & is_md & ~in_is_exception;
    assign fast_dispatch_valid = dispatch_fire & is_fast & ~in_is_exception;

    assign lsu_bias_valid =  is_lsu & ~in_is_exception;
    assign fast_bias_valid =  is_fast & ~in_is_exception;

    // The privilege queue has one dispatch port.  A privilege instruction in
    // a younger lane is held until it reaches lane zero.
    assign privilege_dispatch_valid = dispatch_fire[0] &&
           (sel_issue_queue[0] ==
            `SEL_ISSUE_QUEUE_PRIVILIEGE) &&
           !in_is_exception[0];
    assign rob_alloc_valid = dispatch_fire;

endmodule
