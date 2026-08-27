`include "header.v"

module  fast_issue_queue_lutram_core #(
        parameter DEPTH       = `FAST_ISSUE_QUEUE_DEPTH,
        parameter TAG_WIDTH   = `FAST_ISSUE_QUEUE_TAG_WIDTH,
        parameter OP_WIDTH    = `FAST_ISSUE_QUEUE_OP_WIDTH,
        parameter IMM_WIDTH   = `FAST_ISSUE_QUEUE_IMM_WIDTH,
        parameter COUNT_WIDTH = `FAST_ISSUE_QUEUE_COUNT_WIDTH
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire [              3:0] bias_valid,
        input  wire [              3:0] dispatch_valid,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_0,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_1,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_2,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_3,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_0,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_1,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_2,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_3,
        input  wire [    IMM_WIDTH-1:0] dispatch_imm_0,
        input  wire [    IMM_WIDTH-1:0] dispatch_imm_1,
        input  wire [    IMM_WIDTH-1:0] dispatch_imm_2,
        input  wire [    IMM_WIDTH-1:0] dispatch_imm_3,
        input  wire [              4:0] dispatch_bid_0,
        input  wire [              4:0] dispatch_bid_1,
        input  wire [              4:0] dispatch_bid_2,
        input  wire [              4:0] dispatch_bid_3,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_0,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_1,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_2,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_3,

        output wire                     issue_valid,
        input  wire                     issue_ready,
        output wire [     OP_WIDTH-1:0] issue_opcode,
        output wire [    TAG_WIDTH-1:0] issue_pdest,
        output wire [    IMM_WIDTH-1:0] issue_imm,
        output wire [              4:0] issue_bid,
        output wire [`ROB_ID_WIDTH-1:0] issue_rob_id,

        output wire                     extra_issue_valid,
        input  wire                     extra_issue_ready,
        output wire [     OP_WIDTH-1:0] extra_issue_opcode,
        output wire [    TAG_WIDTH-1:0] extra_issue_pdest,
        output wire [    IMM_WIDTH-1:0] extra_issue_imm,
        output wire [              4:0] extra_issue_bid,
        output wire [`ROB_ID_WIDTH-1:0] extra_issue_rob_id,

        output wire                   full,
        output wire                   empty,
        output reg  [COUNT_WIDTH-1:0] count,
        output wire [COUNT_WIDTH-1:0] res_count,

        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid
    );

    localparam PAYLOAD_WIDTH = OP_WIDTH + TAG_WIDTH + IMM_WIDTH + `ROB_ID_WIDTH;
    localparam [COUNT_WIDTH-1:0] DEPTH_COUNT = DEPTH;

    reg  [        DEPTH-1:0] valid;
    reg  [              4:0] bid                 [DEPTH-1:0];

    wire extra_issue_fire;
    wire [              3:0] dispatch_fire;
    wire                     issue_fire;

    wire [              4:0] head;
    wire [              4:0] tail;

    reg  [              5:0] queue_head;
    reg  [              5:0] queue_tail;

    wire [             31:0] valid_mask;
    wire [             31:0] valid_next;

    wire [  COUNT_WIDTH-1:0] count_next;
    wire [        DEPTH-1:0] bid_greater;

    wire                     first_issue_valid;
    wire [     OP_WIDTH-1:0] first_issue_opcode;
    wire [    TAG_WIDTH-1:0] first_issue_pdest;
    wire [    IMM_WIDTH-1:0] first_issue_imm;
    wire [              4:0] first_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] first_issue_rob_id;

    wire                     second_issue_valid;
    wire [     OP_WIDTH-1:0] second_issue_opcode;
    wire [    TAG_WIDTH-1:0] second_issue_pdest;
    wire [    IMM_WIDTH-1:0] second_issue_imm;
    wire [              4:0] second_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] second_issue_rob_id;

    wire [              5:0] queue_head_next;
    wire [              4:0] head_next;

    wire [              2:0] write_offset_0;
    wire [              2:0] write_offset_1;
    wire [              2:0] write_offset_2;
    wire [              2:0] write_offset_3;
    wire [              2:0] accept_count;

    wire [              5:0] write_ptr_0;
    wire [              5:0] write_ptr_1;
    wire [              5:0] write_ptr_2;
    wire [              5:0] write_ptr_3;

    wire [              4:0] write_index_0;
    wire [              4:0] write_index_1;
    wire [              4:0] write_index_2;
    wire [              4:0] write_index_3;
    wire [              1:0] write_bank_0;
    wire [              1:0] write_bank_1;
    wire [              1:0] write_bank_2;
    wire [              1:0] write_bank_3;
    wire [              2:0] write_row_0;
    wire [              2:0] write_row_1;
    wire [              2:0] write_row_2;
    wire [              2:0] write_row_3;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_0;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_1;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_2;
    wire [PAYLOAD_WIDTH-1:0] dispatch_payload_3;

    wire [              3:0] bank_we;
    wire [              2:0] bank_write_row_0;
    wire [              2:0] bank_write_row_1;
    wire [              2:0] bank_write_row_2;
    wire [              2:0] bank_write_row_3;
    wire [              2:0] bank_read_row_0;
    wire [              2:0] bank_read_row_1;
    wire [              2:0] bank_read_row_2;
    wire [              2:0] bank_read_row_3;
    wire [PAYLOAD_WIDTH-1:0] bank_write_payload_0;
    wire [PAYLOAD_WIDTH-1:0] bank_write_payload_1;
    wire [PAYLOAD_WIDTH-1:0] bank_write_payload_2;
    wire [PAYLOAD_WIDTH-1:0] bank_write_payload_3;
    wire [PAYLOAD_WIDTH-1:0] main_bank_dpo_0;
    wire [PAYLOAD_WIDTH-1:0] main_bank_dpo_1;
    wire [PAYLOAD_WIDTH-1:0] main_bank_dpo_2;
    wire [PAYLOAD_WIDTH-1:0] main_bank_dpo_3;
    wire [PAYLOAD_WIDTH-1:0] main_payload;
    wire [PAYLOAD_WIDTH-1:0] extra_payload;

    wire [        DEPTH-1:0] dispatch_set_mask;
    wire                     consume_head;
    wire                     consume_head_next;

    genvar i;

    assign head                = queue_head[4:0];
    assign tail                = queue_tail[4:0];

    assign full                = count == DEPTH;
    assign empty               = (count == {COUNT_WIDTH{1'b0}});
    assign res_count           = DEPTH_COUNT - count;

    assign dispatch_fire       = dispatch_valid;

    assign write_offset_0      = 3'd0;
    assign write_offset_1      = {2'b00, bias_valid[0]};

    assign write_offset_2      = {2'b00, bias_valid[0]}
           + {2'b00, bias_valid[1]};

    assign write_offset_3      = {2'b00, bias_valid[0]}
           + {2'b00, bias_valid[1]}
           + {2'b00, bias_valid[2]};
    assign accept_count        = {2'b00, dispatch_fire[0]}
           + {2'b00, dispatch_fire[1]}
           + {2'b00, dispatch_fire[2]}
           + {2'b00, dispatch_fire[3]};

    assign write_ptr_0         = queue_tail + {{3{1'b0}}, write_offset_0};
    assign write_ptr_1         = queue_tail + {{3{1'b0}}, write_offset_1};
    assign write_ptr_2         = queue_tail + {{3{1'b0}}, write_offset_2};
    assign write_ptr_3         = queue_tail + {{3{1'b0}}, write_offset_3};

    assign write_index_0       = write_ptr_0[4:0];
    assign write_index_1       = write_ptr_1[4:0];
    assign write_index_2       = write_ptr_2[4:0];
    assign write_index_3       = write_ptr_3[4:0];

    assign write_bank_0        = write_index_0[1:0];
    assign write_bank_1        = write_index_1[1:0];
    assign write_bank_2        = write_index_2[1:0];
    assign write_bank_3        = write_index_3[1:0];
    assign write_row_0         = write_index_0[4:2];
    assign write_row_1         = write_index_1[4:2];
    assign write_row_2         = write_index_2[4:2];
    assign write_row_3         = write_index_3[4:2];

    assign dispatch_payload_0  = {dispatch_opcode_0, dispatch_pdest_0, dispatch_imm_0, dispatch_rob_id_0};
    assign dispatch_payload_1  = {dispatch_opcode_1, dispatch_pdest_1, dispatch_imm_1, dispatch_rob_id_1};
    assign dispatch_payload_2  = {dispatch_opcode_2, dispatch_pdest_2, dispatch_imm_2, dispatch_rob_id_2};
    assign dispatch_payload_3  = {dispatch_opcode_3, dispatch_pdest_3, dispatch_imm_3, dispatch_rob_id_3};

    assign queue_head_next     = queue_head + 6'd1;
    assign head_next           = queue_head_next[4:0];

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

    assign bank_write_payload_0 =
           (bias_valid[0] && (write_bank_0 == 2'd0)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd0)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd0)) ? dispatch_payload_2 : dispatch_payload_3;
    assign bank_write_payload_1 =
           (bias_valid[0] && (write_bank_0 == 2'd1)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd1)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd1)) ? dispatch_payload_2 : dispatch_payload_3;
    assign bank_write_payload_2 =
           (bias_valid[0] && (write_bank_0 == 2'd2)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd2)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd2)) ? dispatch_payload_2 : dispatch_payload_3;
    assign bank_write_payload_3 =
           (bias_valid[0] && (write_bank_0 == 2'd3)) ? dispatch_payload_0 :
           (bias_valid[1] && (write_bank_1 == 2'd3)) ? dispatch_payload_1 :
           (bias_valid[2] && (write_bank_2 == 2'd3)) ? dispatch_payload_2 : dispatch_payload_3;

    assign bank_read_row_0 = (head_next[1:0] == 2'd0) ? head_next[4:2] : head[4:2];
    assign bank_read_row_1 = (head_next[1:0] == 2'd1) ? head_next[4:2] : head[4:2];
    assign bank_read_row_2 = (head_next[1:0] == 2'd2) ? head_next[4:2] : head[4:2];
    assign bank_read_row_3 = (head_next[1:0] == 2'd3) ? head_next[4:2] : head[4:2];

    fast_issue_queue_lutram_46x16 u_main_payload_lutram_0 (
                                      .a({1'b0, bank_write_row_0}), .d(bank_write_payload_0),
                                      .dpra({1'b0, bank_read_row_0}), .clk(clk), .we(bank_we[0]), .dpo(main_bank_dpo_0)
                                  );
    fast_issue_queue_lutram_46x16 u_main_payload_lutram_1 (
                                      .a({1'b0, bank_write_row_1}), .d(bank_write_payload_1),
                                      .dpra({1'b0, bank_read_row_1}), .clk(clk), .we(bank_we[1]), .dpo(main_bank_dpo_1)
                                  );
    fast_issue_queue_lutram_46x16 u_main_payload_lutram_2 (
                                      .a({1'b0, bank_write_row_2}), .d(bank_write_payload_2),
                                      .dpra({1'b0, bank_read_row_2}), .clk(clk), .we(bank_we[2]), .dpo(main_bank_dpo_2)
                                  );
    fast_issue_queue_lutram_46x16 u_main_payload_lutram_3 (
                                      .a({1'b0, bank_write_row_3}), .d(bank_write_payload_3),
                                      .dpra({1'b0, bank_read_row_3}), .clk(clk), .we(bank_we[3]), .dpo(main_bank_dpo_3)
                                  );

    assign main_payload = (head[1:0] == 2'd0) ? main_bank_dpo_0 :
           (head[1:0] == 2'd1) ? main_bank_dpo_1 :
           (head[1:0] == 2'd2) ? main_bank_dpo_2 : main_bank_dpo_3;
    assign extra_payload = (head_next[1:0] == 2'd0) ? main_bank_dpo_0 :
           (head_next[1:0] == 2'd1) ? main_bank_dpo_1 :
           (head_next[1:0] == 2'd2) ? main_bank_dpo_2 : main_bank_dpo_3;

    assign first_issue_valid   = valid[head] && !predict_flush;
    assign {first_issue_opcode,
            first_issue_pdest,
            first_issue_imm,
            first_issue_rob_id} = main_payload;
    assign first_issue_bid     = bid[head];

    assign second_issue_valid  = valid[head_next] && !predict_flush;
    assign {second_issue_opcode,
            second_issue_pdest,
            second_issue_imm,
            second_issue_rob_id} = extra_payload;
    assign second_issue_bid    = bid[head_next];

    assign issue_valid         = first_issue_valid;
    assign issue_fire          = issue_valid && issue_ready;
    assign issue_opcode        = first_issue_opcode;
    assign issue_pdest         = first_issue_pdest;
    assign issue_imm           = first_issue_imm;
    assign issue_bid           = first_issue_bid;
    assign issue_rob_id        = first_issue_rob_id;

    assign extra_issue_valid   = issue_ready ? second_issue_valid : first_issue_valid;
    assign extra_issue_fire    = extra_issue_valid && extra_issue_ready;
    assign extra_issue_opcode  = issue_ready ? second_issue_opcode : first_issue_opcode;
    assign extra_issue_pdest   = issue_ready ? second_issue_pdest : first_issue_pdest;
    assign extra_issue_imm     = issue_ready ? second_issue_imm : first_issue_imm;
    assign extra_issue_bid     = issue_ready ? second_issue_bid : first_issue_bid;
    assign extra_issue_rob_id  = issue_ready ? second_issue_rob_id : first_issue_rob_id;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_bid_greater
            circle_comparator u_circle_comparator (
                                  .head  (head_bid),
                                  .a     (bid[i]),
                                  .b     (predict_flush_bid),
                                  .a_gt_b(bid_greater[i])
                              );
        end
    endgenerate

    assign valid_mask = valid & ~bid_greater;

    popcount32 u_popcount32 (
                   .data (valid_mask),
                   .count(count_next)
               );

    assign consume_head =
           issue_fire ||
           (!issue_ready && extra_issue_fire);

    assign consume_head_next =
           issue_ready && extra_issue_fire;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_dispatch_set_mask
            assign dispatch_set_mask[i] =
                   (dispatch_fire[0] && (write_index_0 == i)) ||
                   (dispatch_fire[1] && (write_index_1 == i)) ||
                   (dispatch_fire[2] && (write_index_2 == i)) ||
                   (dispatch_fire[3] && (write_index_3 == i));
        end
    endgenerate

    always @(posedge clk) begin
        if (dispatch_fire[0])
            bid[write_index_0] <= dispatch_bid_0;
        if (dispatch_fire[1])
            bid[write_index_1] <= dispatch_bid_1;
        if (dispatch_fire[2])
            bid[write_index_2] <= dispatch_bid_2;
        if (dispatch_fire[3])
            bid[write_index_3] <= dispatch_bid_3;
    end

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_valid_next
            assign valid_next[i] =
                   ((head == i) && consume_head) ||
                   ((head_next == i) && consume_head_next) ? 1'b0 :
                   dispatch_set_mask[i]                    ? 1'b1 :
                   valid[i];
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn || flush)
            valid <= 32'd0;
        else if (predict_flush)
            valid <= valid_mask;
        else
            valid <= valid_next;
    end

    always @(posedge clk) begin
        if (!resetn || flush)
            queue_head <= 6'd0;
        else if (issue_fire && extra_issue_fire)
            queue_head <= queue_head + 6'd2;
        else if (issue_fire || extra_issue_fire)
            queue_head <= queue_head + 6'd1;
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            queue_tail <= 6'd0;
        end
        else if (predict_flush)
            queue_tail <= queue_head + count_next;
        else if (accept_count != 3'd0) begin
            queue_tail <= queue_tail + {{3{1'b0}}, accept_count};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            count <= {COUNT_WIDTH{1'b0}};
        end
        else if (predict_flush) begin
            count <= count_next;
        end
        else begin
            count <= count
                  - {{(COUNT_WIDTH-1){1'b0}}, issue_fire}
                  - {{(COUNT_WIDTH-1){1'b0}}, extra_issue_fire}
                  + {{(COUNT_WIDTH-3){1'b0}}, accept_count};
        end
    end

endmodule
