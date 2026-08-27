`include "header.v"

module lsu_issue_queue_lutram_core #(
        parameter DEPTH       = `LSU_ISSUE_QUEUE_DEPTH,
        parameter TAG_WIDTH   = `LSU_ISSUE_QUEUE_TAG_WIDTH,
        parameter OP_WIDTH    = `LSU_ISSUE_QUEUE_OP_WIDTH,
        parameter IMM_WIDTH   = `LSU_ISSUE_QUEUE_IMM_WIDTH,
        parameter COUNT_WIDTH = `LSU_ISSUE_QUEUE_COUNT_WIDTH
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire [                 3:0] bias_valid,
        input  wire [                 3:0] dispatch_valid,
        input  wire [        OP_WIDTH-1:0] dispatch_opcode_0,
        input  wire [        OP_WIDTH-1:0] dispatch_opcode_1,
        input  wire [        OP_WIDTH-1:0] dispatch_opcode_2,
        input  wire [        OP_WIDTH-1:0] dispatch_opcode_3,
        input  wire [       TAG_WIDTH-1:0] dispatch_pdest_0,
        input  wire [       TAG_WIDTH-1:0] dispatch_pdest_1,
        input  wire [       TAG_WIDTH-1:0] dispatch_pdest_2,
        input  wire [       TAG_WIDTH-1:0] dispatch_pdest_3,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc0_0,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc0_1,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc0_2,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc0_3,
        input  wire [                 3:0] dispatch_prdy0,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc1_0,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc1_1,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc1_2,
        input  wire [       TAG_WIDTH-1:0] dispatch_psrc1_3,
        input  wire [                 3:0] dispatch_prdy1,
        input  wire [       IMM_WIDTH-1:0] dispatch_imm_0,
        input  wire [       IMM_WIDTH-1:0] dispatch_imm_1,
        input  wire [       IMM_WIDTH-1:0] dispatch_imm_2,
        input  wire [       IMM_WIDTH-1:0] dispatch_imm_3,
        input  wire [                 4:0] dispatch_bid_0,
        input  wire [                 4:0] dispatch_bid_1,
        input  wire [                 4:0] dispatch_bid_2,
        input  wire [                 4:0] dispatch_bid_3,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_0,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_1,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_2,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_3,

        input wire                 bypass1_valid,
        input wire [TAG_WIDTH-1:0] bypass1_dst,
        input wire                 bypass2_valid,
        input wire [TAG_WIDTH-1:0] bypass2_dst,
        input wire                 bypass3_valid,
        input wire [TAG_WIDTH-1:0] bypass3_dst,
        input wire                 bypass4_valid,
        input wire [TAG_WIDTH-1:0] bypass4_dst,
        input wire                 bypass5_valid,
        input wire [TAG_WIDTH-1:0] bypass5_dst,
        input wire                 bypass6_valid,
        input wire [TAG_WIDTH-1:0] bypass6_dst,
        input wire                 bypass7_valid,
        input wire [TAG_WIDTH-1:0] bypass7_dst,

        output wire [        OP_WIDTH-1:0] issue_opcode,
        output wire [       TAG_WIDTH-1:0] issue_pdest,
        output wire [       TAG_WIDTH-1:0] issue_psrc0,
        output wire [       TAG_WIDTH-1:0] issue_psrc1,
        output wire [       IMM_WIDTH-1:0] issue_imm,
        output wire [                 4:0] issue_bid,
        output wire [`ROB_ID_WIDTH-1:0] issue_rob_id,
        output wire                        issue_valid,
        input  wire                        issue_ready,

        output wire                   full,
        output wire                   empty,
        output reg  [COUNT_WIDTH-1:0] count,

        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid,

        input wire [127:0] phy_ready
    );

    localparam PAYLOAD_WIDTH = OP_WIDTH + (3 * TAG_WIDTH) + IMM_WIDTH + `ROB_ID_WIDTH;

    reg [DEPTH-1:0] valid;
    reg [4:0]             bid [DEPTH-1:0];

    reg [5:0] queue_head;
    reg [5:0] queue_tail;

    wire [4:0] head;
    wire [4:0] tail;
    wire [3:0] dispatch_fire;
    wire       issue_fire;

    wire [2:0] bias_before_0;
    wire [2:0] bias_before_1;
    wire [2:0] bias_before_2;
    wire [2:0] bias_before_3;
    wire [2:0] accept_count;
    wire [5:0] write_ptr_0;
    wire [5:0] write_ptr_1;
    wire [5:0] write_ptr_2;
    wire [5:0] write_ptr_3;
    wire [4:0] write_index_0;
    wire [4:0] write_index_1;
    wire [4:0] write_index_2;
    wire [4:0] write_index_3;
    wire [1:0] write_bank_0;
    wire [1:0] write_bank_1;
    wire [1:0] write_bank_2;
    wire [1:0] write_bank_3;
    wire [2:0] write_row_0;
    wire [2:0] write_row_1;
    wire [2:0] write_row_2;
    wire [2:0] write_row_3;
    wire [DEPTH-1:0] valid_next;
    wire [DEPTH-1:0] valid_mask;
    wire [COUNT_WIDTH-1:0] count_next;
    // Keep the two arithmetic cones independent.  The cache/stall-derived
    // issue_fire signal then selects a completed result instead of entering
    // the count carry chain on the critical path.
    (* keep = "true" *) wire [COUNT_WIDTH-1:0] count_no_issue_w;
    (* keep = "true" *) wire [COUNT_WIDTH-1:0] count_with_issue_w;
    wire [COUNT_WIDTH-1:0] count_normal_next_w;
    wire [DEPTH-1:0] bid_greater;

    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_0;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_1;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_2;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_3;
    wire [3:0]               bank_we;
    wire [2:0]               bank_write_row_0;
    wire [2:0]               bank_write_row_1;
    wire [2:0]               bank_write_row_2;
    wire [2:0]               bank_write_row_3;
    wire [PAYLOAD_WIDTH-1:0] bank_write_data_0;
    wire [PAYLOAD_WIDTH-1:0] bank_write_data_1;
    wire [PAYLOAD_WIDTH-1:0] bank_write_data_2;
    wire [PAYLOAD_WIDTH-1:0] bank_write_data_3;
    wire [4:0]               bank_write_bid_0;
    wire [4:0]               bank_write_bid_1;
    wire [4:0]               bank_write_bid_2;
    wire [4:0]               bank_write_bid_3;
    wire [PAYLOAD_WIDTH-1:0] bank_dpo_0;
    wire [PAYLOAD_WIDTH-1:0] bank_dpo_1;
    wire [PAYLOAD_WIDTH-1:0] bank_dpo_2;
    wire [PAYLOAD_WIDTH-1:0] bank_dpo_3;
    reg  [PAYLOAD_WIDTH-1:0] head_payload;
    wire [DEPTH-1:0] dispatch_onehot;

    genvar i;

    assign head = queue_head[4:0];
    assign tail = queue_tail[4:0];

    assign full       = count == DEPTH;
    assign empty      = count == {COUNT_WIDTH{1'b0}};
    assign dispatch_fire = dispatch_valid;

    assign bias_before_0 = 3'd0;
    assign bias_before_1 = {2'd0, bias_valid[0]};
    assign bias_before_2 = {2'd0, bias_valid[0]} +
           {2'd0, bias_valid[1]};
    assign bias_before_3 = {2'd0, bias_valid[0]} +
           {2'd0, bias_valid[1]} +
           {2'd0, bias_valid[2]};
    assign accept_count = {2'd0, dispatch_fire[0]} +
           {2'd0, dispatch_fire[1]} +
           {2'd0, dispatch_fire[2]} +
           {2'd0, dispatch_fire[3]};

    assign write_ptr_0 = queue_tail + {{3{1'b0}}, bias_before_0};
    assign write_ptr_1 = queue_tail + {{3{1'b0}}, bias_before_1};
    assign write_ptr_2 = queue_tail + {{3{1'b0}}, bias_before_2};
    assign write_ptr_3 = queue_tail + {{3{1'b0}}, bias_before_3};
    assign write_index_0 = write_ptr_0[4:0];
    assign write_index_1 = write_ptr_1[4:0];
    assign write_index_2 = write_ptr_2[4:0];
    assign write_index_3 = write_ptr_3[4:0];
    assign write_bank_0 = write_index_0[1:0];
    assign write_bank_1 = write_index_1[1:0];
    assign write_bank_2 = write_index_2[1:0];
    assign write_bank_3 = write_index_3[1:0];
    assign write_row_0 = write_index_0[4:2];
    assign write_row_1 = write_index_1[4:2];
    assign write_row_2 = write_index_2[4:2];
    assign write_row_3 = write_index_3[4:2];

    assign dispatch_payload_0 = {
               dispatch_opcode_0, dispatch_pdest_0,
               dispatch_psrc0_0, dispatch_psrc1_0,
               dispatch_imm_0, dispatch_rob_id_0
           };
    assign dispatch_payload_1 = {
               dispatch_opcode_1, dispatch_pdest_1,
               dispatch_psrc0_1, dispatch_psrc1_1,
               dispatch_imm_1, dispatch_rob_id_1
           };
    assign dispatch_payload_2 = {
               dispatch_opcode_2, dispatch_pdest_2,
               dispatch_psrc0_2, dispatch_psrc1_2,
               dispatch_imm_2, dispatch_rob_id_2
           };
    assign dispatch_payload_3 = {
               dispatch_opcode_3, dispatch_pdest_3,
               dispatch_psrc0_3, dispatch_psrc1_3,
               dispatch_imm_3, dispatch_rob_id_3
           };

    assign issue_valid = valid[head] && !predict_flush;
    assign issue_fire  = issue_valid && issue_ready;

    assign count_no_issue_w =
           count + {{(COUNT_WIDTH-3){1'b0}}, accept_count};
    assign count_with_issue_w =
           count + {{(COUNT_WIDTH-3){1'b0}}, accept_count} -
           {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
    assign count_normal_next_w =
           issue_fire ? count_with_issue_w : count_no_issue_w;

    assign issue_bid   = bid[head];
    assign {
            issue_opcode, issue_pdest,
            issue_psrc0, issue_psrc1,
            issue_imm, issue_rob_id
        } = head_payload;

    assign bank_we[0] =
           (dispatch_fire[0] && (write_bank_0 == 2'd0)) ||
           (dispatch_fire[1] && (write_bank_1 == 2'd0)) ||
           (dispatch_fire[2] && (write_bank_2 == 2'd0)) ||
           (dispatch_fire[3] && (write_bank_3 == 2'd0));
    assign bank_we[1] =
           (dispatch_fire[0] && (write_bank_0 == 2'd1)) ||
           (dispatch_fire[1] && (write_bank_1 == 2'd1)) ||
           (dispatch_fire[2] && (write_bank_2 == 2'd1)) ||
           (dispatch_fire[3] && (write_bank_3 == 2'd1));
    assign bank_we[2] =
           (dispatch_fire[0] && (write_bank_0 == 2'd2)) ||
           (dispatch_fire[1] && (write_bank_1 == 2'd2)) ||
           (dispatch_fire[2] && (write_bank_2 == 2'd2)) ||
           (dispatch_fire[3] && (write_bank_3 == 2'd2));
    assign bank_we[3] =
           (dispatch_fire[0] && (write_bank_0 == 2'd3)) ||
           (dispatch_fire[1] && (write_bank_1 == 2'd3)) ||
           (dispatch_fire[2] && (write_bank_2 == 2'd3)) ||
           (dispatch_fire[3] && (write_bank_3 == 2'd3));

    assign bank_write_row_0 =
           (bias_valid[0] && (write_bank_0 == 2'd0)) ? write_row_0 :
           (bias_valid[1] && (write_bank_1 == 2'd0)) ? write_row_1 :
           (bias_valid[2] && (write_bank_2 == 2'd0)) ? write_row_2 : write_row_3;
    assign bank_write_row_1 =
           (bias_valid[0] && (write_bank_0 == 2'd1)) ? write_row_0 :
           (bias_valid[1] && (write_bank_1 == 2'd1)) ? write_row_1 :
           (bias_valid[2] && (write_bank_2 == 2'd1)) ? write_row_2 : write_row_3;
    assign bank_write_row_2 =
           (bias_valid[0] && (write_bank_0 == 2'd2)) ? write_row_0 :
           (bias_valid[1] && (write_bank_1 == 2'd2)) ? write_row_1 :
           (bias_valid[2] && (write_bank_2 == 2'd2)) ? write_row_2 : write_row_3;
    assign bank_write_row_3 =
           (bias_valid[0] && (write_bank_0 == 2'd3)) ? write_row_0 :
           (bias_valid[1] && (write_bank_1 == 2'd3)) ? write_row_1 :
           (bias_valid[2] && (write_bank_2 == 2'd3)) ? write_row_2 : write_row_3;

    assign bank_write_data_0 =
           (bias_valid[0] && (write_bank_0 == 2'd0)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd0)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd0)) ? dispatch_payload_2 : dispatch_payload_3;
    assign bank_write_data_1 =
           (bias_valid[0] && (write_bank_0 == 2'd1)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd1)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd1)) ? dispatch_payload_2 : dispatch_payload_3;
    assign bank_write_data_2 =
           (bias_valid[0] && (write_bank_0 == 2'd2)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd2)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd2)) ? dispatch_payload_2 : dispatch_payload_3;
    assign bank_write_data_3 =
           (bias_valid[0] && (write_bank_0 == 2'd3)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd3)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd3)) ? dispatch_payload_2 : dispatch_payload_3;


    lsu_issue_queue_lutram_16x67 u_payload_bank_0 (
                                     .a({1'b0, bank_write_row_0}), .d(bank_write_data_0),
                                     .dpra({1'b0, head[4:2]}), .clk(clk), .we(bank_we[0]), .dpo(bank_dpo_0)
                                 );
    lsu_issue_queue_lutram_16x67 u_payload_bank_1 (
                                     .a({1'b0, bank_write_row_1}), .d(bank_write_data_1),
                                     .dpra({1'b0, head[4:2]}), .clk(clk), .we(bank_we[1]), .dpo(bank_dpo_1)
                                 );
    lsu_issue_queue_lutram_16x67 u_payload_bank_2 (
                                     .a({1'b0, bank_write_row_2}), .d(bank_write_data_2),
                                     .dpra({1'b0, head[4:2]}), .clk(clk), .we(bank_we[2]), .dpo(bank_dpo_2)
                                 );
    lsu_issue_queue_lutram_16x67 u_payload_bank_3 (
                                     .a({1'b0, bank_write_row_3}), .d(bank_write_data_3),
                                     .dpra({1'b0, head[4:2]}), .clk(clk), .we(bank_we[3]), .dpo(bank_dpo_3)
                                 );

    always @(*) begin
        case (head[1:0])
            2'd0:
                head_payload = bank_dpo_0;
            2'd1:
                head_payload = bank_dpo_1;
            2'd2:
                head_payload = bank_dpo_2;
            2'd3:
                head_payload = bank_dpo_3;
        endcase
    end

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_bid_greater
            circle_comparator u_circle_comparator (
                                  .head(head_bid), .a(bid[i]), .b(predict_flush_bid),
                                  .a_gt_b(bid_greater[i])
                              );
        end
    endgenerate


    always @(posedge clk) begin
        if (dispatch_fire[0]) begin
            bid[write_index_0]   <= dispatch_bid_0;
        end
        if (dispatch_fire[1]) begin
            bid[write_index_1]   <= dispatch_bid_1;
        end
        if (dispatch_fire[2]) begin
            bid[write_index_2]   <= dispatch_bid_2;
        end
        if (dispatch_fire[3]) begin
            bid[write_index_3]   <= dispatch_bid_3;
        end
    end


    assign valid_mask = valid & ~bid_greater;

    popcount32 u_popcount32 (
                   .data(valid_mask), .count(count_next)
               );


    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_valid_next
            assign valid_next[i] = head == i && issue_fire ? 1'b0 :
                   ((dispatch_fire[0] && write_index_0 == i) ||
                    (dispatch_fire[1] && write_index_1 == i) ||
                    (dispatch_fire[2] && write_index_2 == i) ||
                    (dispatch_fire[3] && write_index_3 == i)) ? 1'b1 :
                   valid[i];
        end
    endgenerate


    always @(posedge clk) begin
        if (!resetn || flush)
            valid <= {DEPTH{1'b0}};
        else if (predict_flush)
            valid <= valid_mask;
        else
            valid <= valid_next;
    end

    always @(posedge clk) begin
        if (!resetn || flush)
            queue_head <= 6'd0;
        else if (issue_fire)
            queue_head <= queue_head + 6'd1;
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            queue_tail <= 6'd0;
        end
        else if (predict_flush) begin
            queue_tail <= queue_head + count_next;
        end
        else if (accept_count != 3'd0) begin
            queue_tail <= queue_tail + {{3{1'b0}}, accept_count};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush)
            count <= {COUNT_WIDTH{1'b0}};
        else if (predict_flush)
            count <= count_next;
        else
            count <= count_normal_next_w;
    end

endmodule
