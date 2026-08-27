`include "header.v"

module lsu_issue_queue #(
    parameter DEPTH       = `LSU_ISSUE_QUEUE_DEPTH,
    parameter TAG_WIDTH   = `LSU_ISSUE_QUEUE_TAG_WIDTH,
    parameter OP_WIDTH    = `LSU_ISSUE_QUEUE_OP_WIDTH,
    parameter IMM_WIDTH   = `LSU_ISSUE_QUEUE_IMM_WIDTH,
    parameter COUNT_WIDTH = `LSU_ISSUE_QUEUE_COUNT_WIDTH
) (
    input wire clk,
    input wire resetn,
    input wire flush,

    input  wire                     dispatch_valid,
    output wire                     dispatch_ready,
    input  wire [     OP_WIDTH-1:0] dispatch_opcode,
    input  wire [    TAG_WIDTH-1:0] dispatch_pdest,
    input  wire [    TAG_WIDTH-1:0] dispatch_psrc0,
    input  wire                     dispatch_prdy0,
    input  wire [    TAG_WIDTH-1:0] dispatch_psrc1,
    input  wire                     dispatch_prdy1,
    input  wire [    IMM_WIDTH-1:0] dispatch_imm,
    input  wire [              4:0] dispatch_bid,
    input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id,

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

    output wire                     issue_valid,
    input  wire                     issue_ready,
    output wire [     OP_WIDTH-1:0] issue_opcode,
    output wire [    TAG_WIDTH-1:0] issue_pdest,
    output wire [    TAG_WIDTH-1:0] issue_psrc0,
    output wire [    TAG_WIDTH-1:0] issue_psrc1,
    output wire [    IMM_WIDTH-1:0] issue_imm,
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
    reg                      prdy0         [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] psrc1         [DEPTH-1:0];
    reg                      prdy1         [DEPTH-1:0];
    reg  [    IMM_WIDTH-1:0] imm           [DEPTH-1:0];
    reg  [              4:0] bid           [DEPTH-1:0];
    reg  [`ROB_ID_WIDTH-1:0] rob_id        [DEPTH-1:0];



    wire                     dispatch_fire;
    wire                     issue_fire;

    wire [              4:0] head;
    wire [              4:0] tail;

    reg  [              5:0] queue_head;
    reg  [              5:0] queue_tail;



    wire [             31:0] valid_next;
    wire [             31:0] valid_mask;

    wire [  COUNT_WIDTH-1:0] count_next;

    wire [    DEPTH - 1 : 0] update_prdy0;
    wire [    DEPTH - 1 : 0] update_prdy1;

    wire [        DEPTH-1:0] bid_greater;


    genvar i;

    assign head           = queue_head[4:0];
    assign tail           = queue_tail[4:0];

    assign full           = count == DEPTH;
    assign empty          = (count == {COUNT_WIDTH{1'b0}});
    assign issue_valid    = valid[head] && prdy0[head] && prdy1[head] && !predict_flush;
    assign issue_fire     = issue_valid && issue_ready;

    assign dispatch_ready = !full;
    assign dispatch_fire  = dispatch_valid && dispatch_ready;

    assign issue_opcode   = opcode[head];
    assign issue_pdest    = pdest[head];
    assign issue_psrc0    = psrc0[head];
    assign issue_psrc1    = psrc1[head];
    assign issue_imm      = imm[head];
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

    popcount32 u_popcount32 (
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
        if (!resetn || flush) valid <= 32'd0;
        else if (predict_flush) valid <= valid_mask;
        else valid <= valid_next;
    end


    always @(posedge clk) begin
        if (!resetn || flush) queue_head <= 6'd0;
        else if (issue_fire) queue_head <= queue_head + 6'd1;
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            queue_tail <= 6'd0;
        end else if (predict_flush) queue_tail <= queue_head + count_next;
        else if (dispatch_fire) begin
            queue_tail <= queue_tail + 6'd1;
        end
    end


    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_update_prdy
            assign update_prdy0[i] = prdy0[i] || 
                                (bypass1_valid && (psrc0[i] == bypass1_dst)) || 
                                (bypass2_valid && (psrc0[i] == bypass2_dst)) || 
                                (bypass3_valid && (psrc0[i] == bypass3_dst)) || 
                                (bypass4_valid && (psrc0[i] == bypass4_dst)) || 
                                (bypass5_valid && (psrc0[i] == bypass5_dst)) || 
                                (bypass6_valid && (psrc0[i] == bypass6_dst)) || 
                                (bypass7_valid && (psrc0[i] == bypass7_dst));
            assign update_prdy1[i] = prdy1[i] || 
                                (bypass1_valid && (psrc1[i] == bypass1_dst)) || 
                                (bypass2_valid && (psrc1[i] == bypass2_dst)) || 
                                (bypass3_valid && (psrc1[i] == bypass3_dst)) || 
                                (bypass4_valid && (psrc1[i] == bypass4_dst)) || 
                                (bypass5_valid && (psrc1[i] == bypass5_dst)) || 
                                (bypass6_valid && (psrc1[i] == bypass6_dst)) || 
                                (bypass7_valid && (psrc1[i] == bypass7_dst));
        end
    endgenerate

    always @(posedge clk) begin
        if (dispatch_fire) begin
            opcode[tail] <= dispatch_opcode;
            pdest[tail]  <= dispatch_pdest;
            psrc0[tail]  <= dispatch_psrc0;
            psrc1[tail]  <= dispatch_psrc1;
            imm[tail]    <= dispatch_imm;
            bid[tail]    <= dispatch_bid;
            rob_id[tail] <= dispatch_rob_id;
        end
    end

    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_prdy
            always @(posedge clk) begin
                if (tail == i && dispatch_fire) begin
                    prdy0[i] <= dispatch_prdy0;
                    prdy1[i] <= dispatch_prdy1;
                end else begin
                    prdy0[i] <= update_prdy0[i];
                    prdy1[i] <= update_prdy1[i];
                end
            end
        end
    endgenerate

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

    // wire [COUNT_WIDTH-1:0] count_valid;

    // popcount32 u_count_popcount32 (
    //     .data (valid),
    //     .count(count_valid)
    // );

    // wire count_true;
    // assign count_true = count_valid == count;








endmodule
