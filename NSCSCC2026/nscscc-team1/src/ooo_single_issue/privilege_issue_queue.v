`include "header.v"

module privilege_issue_queue #(
    parameter DEPTH       = `PRIVILEGE_ISSUE_QUEUE_DEPTH,
    parameter TAG_WIDTH   = `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH,
    parameter OP_WIDTH    = `PRIVILEGE_ISSUE_QUEUE_OP_WIDTH,
    parameter IMM_WIDTH   = `PRIVILEGE_ISSUE_QUEUE_IMM_WIDTH,
    parameter COUNT_WIDTH = `PRIVILEGE_ISSUE_QUEUE_COUNT_WIDTH
) (
    input wire clk,
    input wire resetn,
    input wire flush,

    input  wire                     dispatch_valid,
    output wire                     dispatch_ready,
    input  wire [     OP_WIDTH-1:0] dispatch_opcode,
    input  wire [    TAG_WIDTH-1:0] dispatch_pdest,
    input  wire [    TAG_WIDTH-1:0] dispatch_psrc0,
    input  wire [    TAG_WIDTH-1:0] dispatch_psrc1,
    input  wire [              4:0] dispatch_bid,
    input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id,

    output wire                     issue_valid,
    input  wire                     issue_ready,
    output wire [     OP_WIDTH-1:0] issue_opcode,
    output wire [    TAG_WIDTH-1:0] issue_pdest,
    output wire [    TAG_WIDTH-1:0] issue_psrc0,
    output wire [    TAG_WIDTH-1:0] issue_psrc1,
    output wire [              4:0] issue_bid,
    output wire [`ROB_ID_WIDTH-1:0] issue_rob_id,

    output wire                   full,
    output wire                   empty,
    output reg  [COUNT_WIDTH-1:0] count,

    input wire       predict_flush,
    input wire [4:0] predict_flush_bid,
    input wire [4:0] head_bid
);

    reg  [        DEPTH-1:0] valid;
    reg  [     OP_WIDTH-1:0] opcode        [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] pdest         [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] psrc0         [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] psrc1         [DEPTH-1:0];
    reg  [              4:0] bid           [DEPTH-1:0];
    reg  [`ROB_ID_WIDTH-1:0] rob_id        [DEPTH-1:0];



    wire                     dispatch_fire;
    wire                     issue_fire;

    wire [              3:0] head;
    wire [              3:0] tail;

    reg  [              4:0] queue_head;
    reg  [              4:0] queue_tail;



    wire [        DEPTH-1:0] valid_next;
    wire [        DEPTH-1:0] valid_mask;

    wire [  COUNT_WIDTH-1:0] count_next;


    wire [        DEPTH-1:0] bid_greater;


    genvar i;

    assign head           = queue_head[3:0];
    assign tail           = queue_tail[3:0];

    assign full           = count == DEPTH;
    assign empty          = (count == {COUNT_WIDTH{1'b0}});
    assign issue_valid    = valid[head] && !predict_flush;
    assign issue_fire     = issue_valid && issue_ready;

    assign dispatch_ready = !full;
    assign dispatch_fire  = dispatch_valid && dispatch_ready;

    assign issue_opcode   = opcode[head];
    assign issue_pdest    = pdest[head];
    assign issue_psrc0    = psrc0[head];
    assign issue_psrc1    = psrc1[head];
    assign issue_bid      = bid[head];
    assign issue_rob_id   = rob_id[head];

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

    popcount16 u_popcount16 (
        .data (valid_mask),
        .count(count_next)
    );



    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_valid_next
            assign valid_next[i] = head == i && issue_fire ? 1'b0 :
                                   tail == i && dispatch_fire ? 1'b1 : 
                                   valid[i];
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn || flush) valid <= 16'd0;
        else if (predict_flush) valid <= valid_mask;
        else valid <= valid_next;
    end


    always @(posedge clk) begin
        if (!resetn || flush) queue_head <= 5'd0;
        else if (issue_fire) queue_head <= queue_head + 5'd1;
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            queue_tail <= 5'd0;
        end else if (predict_flush) queue_tail <= queue_head + count_next;
        else if (dispatch_fire) begin
            queue_tail <= queue_tail + 5'd1;
        end
    end

    always @(posedge clk) begin
        if (dispatch_fire) begin
            opcode[tail] <= dispatch_opcode;
            pdest[tail]  <= dispatch_pdest;
            psrc0[tail]  <= dispatch_psrc0;
            psrc1[tail]  <= dispatch_psrc1;
            bid[tail]    <= dispatch_bid;
            rob_id[tail] <= dispatch_rob_id;
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            count <= {COUNT_WIDTH{1'b0}};

        end else if (predict_flush) begin
            count <= count_next;
        end else begin
            case ({
                dispatch_fire, issue_fire
            })
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
            endcase
        end
    end





endmodule
