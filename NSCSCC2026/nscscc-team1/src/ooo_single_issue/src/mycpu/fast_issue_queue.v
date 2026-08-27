`include "header.v"

module fast_issue_queue #(
        parameter DEPTH       = `FAST_ISSUE_QUEUE_DEPTH,
        parameter TAG_WIDTH   = `FAST_ISSUE_QUEUE_TAG_WIDTH,
        parameter OP_WIDTH    = `FAST_ISSUE_QUEUE_OP_WIDTH,
        parameter IMM_WIDTH   = `FAST_ISSUE_QUEUE_IMM_WIDTH,
        parameter COUNT_WIDTH = `FAST_ISSUE_QUEUE_COUNT_WIDTH
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire                     dispatch_valid,
        output wire                     dispatch_ready,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest,
        input  wire [    IMM_WIDTH-1:0] dispatch_imm,
        input  wire [              4:0] dispatch_bid,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id,

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

        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid
    );

    reg  [        DEPTH-1:0] valid;
    reg  [     OP_WIDTH-1:0] opcode              [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] pdest               [DEPTH-1:0];
    reg  [    IMM_WIDTH-1:0] imm                 [DEPTH-1:0];
    reg  [              4:0] bid                 [DEPTH-1:0];
    reg  [`ROB_ID_WIDTH-1:0] rob_id              [DEPTH-1:0];

    wire extra_issue_fire;
    wire                     dispatch_fire;
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

    genvar i;



    assign head                = queue_head[4:0];
    assign tail                = queue_tail[4:0];


    assign full                = count == DEPTH;
    assign empty               = (count == {COUNT_WIDTH{1'b0}});

    assign dispatch_ready      = !full;
    assign dispatch_fire       = dispatch_valid && dispatch_ready;



    assign first_issue_valid   = valid[head] && !predict_flush;
    assign first_issue_opcode  = opcode[head];
    assign first_issue_pdest   = pdest[head];
    assign first_issue_imm     = imm[head];
    assign first_issue_bid     = bid[head];
    assign first_issue_rob_id  = rob_id[head];

    assign second_issue_valid  = valid[head_next] && !predict_flush;
    assign second_issue_opcode = opcode[head_next];
    assign second_issue_pdest  = pdest[head_next];
    assign second_issue_imm    = imm[head_next];
    assign second_issue_bid    = bid[head_next];
    assign second_issue_rob_id = rob_id[head_next];


    assign issue_valid         = first_issue_valid;
    assign issue_fire          = issue_valid && issue_ready;
    assign issue_opcode        = first_issue_opcode;
    assign issue_pdest         = first_issue_pdest;
    assign issue_imm           = first_issue_imm;
    assign issue_bid           = first_issue_bid;
    assign issue_rob_id        = first_issue_rob_id;


    assign queue_head_next     = queue_head + 6'd1;
    assign head_next           = queue_head_next[4:0];

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
    wire consume_head;
    wire consume_head_next;

    assign consume_head =
           issue_fire ||
           (!issue_ready && extra_issue_fire);

    assign consume_head_next =
           issue_ready && extra_issue_fire;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_valid_next
            assign valid_next[i] =
                   ((head == i) && consume_head) ||
                   ((head_next == i) && consume_head_next) ? 1'b0 :
                   ((tail == i) && dispatch_fire)          ? 1'b1 :
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
        else if (dispatch_fire) begin
            queue_tail <= queue_tail + 6'd1;
        end
    end


    always @(posedge clk) begin
        if (dispatch_fire) begin
            opcode[tail] <= dispatch_opcode;
            pdest[tail]  <= dispatch_pdest;
            imm[tail]    <= dispatch_imm;
            bid[tail]    <= dispatch_bid;
            rob_id[tail] <= dispatch_rob_id;
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
            count <= count - issue_fire - extra_issue_fire + dispatch_fire;
        end
    end


    // wire [COUNT_WIDTH-1:0] count_valid;

    // popcount32 u_count_popcount32 (
    //     .data (valid),
    //     .count(count_valid)
    // );

    // wire count_true;
    // assign count_true = count_valid == count;





endmodule
