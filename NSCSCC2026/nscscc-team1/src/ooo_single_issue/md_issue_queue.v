`include "header.v"

module md_issue_queue #(
    parameter DEPTH       = `MD_ISSUE_QUEUE_DEPTH,
    parameter TAG_WIDTH   = `MD_ISSUE_QUEUE_TAG_WIDTH,
    parameter OP_WIDTH    = `MD_ISSUE_QUEUE_OP_WIDTH,
    parameter COUNT_WIDTH = `MD_ISSUE_QUEUE_COUNT_WIDTH
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
    input  wire [              4:0] dispatch_bid,
    input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id,
    input  wire [              2:0] dispatch_inst_type, // 3'b100 div 3'b010 mul 3'b001 bru

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


    output wire                     div_issue_valid,
    input  wire                     div_issue_ready,
    output wire [     OP_WIDTH-1:0] div_issue_opcode,
    output wire [    TAG_WIDTH-1:0] div_issue_pdest,
    output wire [    TAG_WIDTH-1:0] div_issue_psrc0,
    output wire [    TAG_WIDTH-1:0] div_issue_psrc1,
    output wire [              4:0] div_issue_bid,
    output wire [`ROB_ID_WIDTH-1:0] div_issue_rob_id,


    output wire                     mul_issue_valid,
    input  wire                     mul_issue_ready,
    output wire [     OP_WIDTH-1:0] mul_issue_opcode,
    output wire [    TAG_WIDTH-1:0] mul_issue_pdest,
    output wire [    TAG_WIDTH-1:0] mul_issue_psrc0,
    output wire [    TAG_WIDTH-1:0] mul_issue_psrc1,
    output wire [              4:0] mul_issue_bid,
    output wire [`ROB_ID_WIDTH-1:0] mul_issue_rob_id,

    output wire                     bru_issue_valid,
    input  wire                     bru_issue_ready,
    output wire [     OP_WIDTH-1:0] bru_issue_opcode,
    output wire [    TAG_WIDTH-1:0] bru_issue_pdest,
    output wire [    TAG_WIDTH-1:0] bru_issue_psrc0,
    output wire [    TAG_WIDTH-1:0] bru_issue_psrc1,
    output wire [              4:0] bru_issue_bid,
    output wire [`ROB_ID_WIDTH-1:0] bru_issue_rob_id,

    output wire                   full,
    output wire                   empty,
    output reg  [COUNT_WIDTH-1:0] count,

    input wire       predict_flush,
    input wire [4:0] predict_flush_bid,
    input wire [4:0] head_bid
);

    localparam INDEX_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam ISSUE_PAYLOAD_WIDTH = OP_WIDTH + 3 * TAG_WIDTH
                                   + 5 + `ROB_ID_WIDTH;

    reg  [        DEPTH-1:0] valid;
    reg  [     OP_WIDTH-1:0] opcode          [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] pdest           [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] psrc0           [DEPTH-1:0];
    reg                      prdy0           [DEPTH-1:0];
    reg  [    TAG_WIDTH-1:0] psrc1           [DEPTH-1:0];
    reg                      prdy1           [DEPTH-1:0];
    reg  [              4:0] bid             [DEPTH-1:0];
    reg  [`ROB_ID_WIDTH-1:0] rob_id          [DEPTH-1:0];
    reg  [              2:0] inst_type       [DEPTH-1:0];

    wire [        DEPTH-1:0] bid_greater;


    wire                     dispatch_fire;


    wire                     div_issue_fire;
    wire                     div_issue_found;

    wire                     mul_issue_fire;
    wire                     mul_issue_found;

    wire                     bru_issue_fire;
    wire                     bru_issue_found;



    assign full            = count == DEPTH;
    assign empty           = (count == {COUNT_WIDTH{1'b0}});

    assign div_issue_valid = div_issue_found && !predict_flush;
    assign div_issue_fire  = div_issue_valid && div_issue_ready;

    assign mul_issue_valid = mul_issue_found && !predict_flush;
    assign mul_issue_fire  = mul_issue_valid && mul_issue_ready;

    assign bru_issue_valid = bru_issue_found && !predict_flush;
    assign bru_issue_fire  = bru_issue_valid && bru_issue_ready;



    assign dispatch_ready  = !full;
    assign dispatch_fire   = dispatch_valid && dispatch_ready;

    wire [     OP_WIDTH-1:0] sel_div_issue_opcode;
    wire [    TAG_WIDTH-1:0] sel_div_issue_pdest;
    wire [    TAG_WIDTH-1:0] sel_div_issue_psrc0;
    wire [    TAG_WIDTH-1:0] sel_div_issue_psrc1;
    wire [              4:0] sel_div_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] sel_div_issue_rob_id;

    wire [     OP_WIDTH-1:0] sel_mul_issue_opcode;
    wire [    TAG_WIDTH-1:0] sel_mul_issue_pdest;
    wire [    TAG_WIDTH-1:0] sel_mul_issue_psrc0;
    wire [    TAG_WIDTH-1:0] sel_mul_issue_psrc1;
    wire [              4:0] sel_mul_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] sel_mul_issue_rob_id;

    wire [     OP_WIDTH-1:0] sel_bru_issue_opcode;
    wire [    TAG_WIDTH-1:0] sel_bru_issue_pdest;
    wire [    TAG_WIDTH-1:0] sel_bru_issue_psrc0;
    wire [    TAG_WIDTH-1:0] sel_bru_issue_psrc1;
    wire [              4:0] sel_bru_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] sel_bru_issue_rob_id;

    wire [ISSUE_PAYLOAD_WIDTH-1:0] issue_payload       [DEPTH-1:0];
    wire [ISSUE_PAYLOAD_WIDTH-1:0] sel_div_payload;
    wire [ISSUE_PAYLOAD_WIDTH-1:0] sel_mul_payload;
    wire [ISSUE_PAYLOAD_WIDTH-1:0] sel_bru_payload;
    wire [             DEPTH-1:0] div_payload_and     [ISSUE_PAYLOAD_WIDTH-1:0];
    wire [             DEPTH-1:0] mul_payload_and     [ISSUE_PAYLOAD_WIDTH-1:0];
    wire [             DEPTH-1:0] bru_payload_and     [ISSUE_PAYLOAD_WIDTH-1:0];





    assign div_issue_opcode = sel_div_issue_opcode;
    assign div_issue_pdest  = sel_div_issue_pdest;
    assign div_issue_psrc0  = sel_div_issue_psrc0;
    assign div_issue_psrc1  = sel_div_issue_psrc1;
    assign div_issue_bid    = sel_div_issue_bid;
    assign div_issue_rob_id = sel_div_issue_rob_id;


    assign mul_issue_opcode = sel_mul_issue_opcode;
    assign mul_issue_pdest  = sel_mul_issue_pdest;
    assign mul_issue_psrc0  = sel_mul_issue_psrc0;
    assign mul_issue_psrc1  = sel_mul_issue_psrc1;
    assign mul_issue_bid    = sel_mul_issue_bid;
    assign mul_issue_rob_id = sel_mul_issue_rob_id;


    assign bru_issue_opcode = sel_bru_issue_opcode;
    assign bru_issue_pdest  = sel_bru_issue_pdest;
    assign bru_issue_psrc0  = sel_bru_issue_psrc0;
    assign bru_issue_psrc1  = sel_bru_issue_psrc1;
    assign bru_issue_bid    = sel_bru_issue_bid;
    assign bru_issue_rob_id = sel_bru_issue_rob_id;


    wire [  DEPTH - 1 : 0] issue_rdy;

    wire [  DEPTH - 1 : 0] div_issue_rdy;
    wire [  DEPTH - 1 : 0] div_issue_notice;
    wire [  DEPTH - 1 : 0] div_issue_onehot;

    wire [  DEPTH - 1 : 0] mul_issue_rdy;
    wire [  DEPTH - 1 : 0] mul_issue_notice;
    wire [  DEPTH - 1 : 0] mul_issue_onehot;

    wire [  DEPTH - 1 : 0] bru_issue_rdy;
    wire [  DEPTH - 1 : 0] bru_issue_notice;
    wire [  DEPTH - 1 : 0] bru_issue_onehot;


    wire [COUNT_WIDTH-1:0] predict_flush_count;

    wire [           31:0] popcount32_data;

    assign popcount32_data = ~bid_greater & valid;

    popcount32 u_popcount32 (
        .data (popcount32_data),
        .count(predict_flush_count)
    );



    genvar i;
    genvar select_bit;
    genvar select_entry;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_greater
            circle_comparator u_circle_comparator (
                .head  (head_bid),
                .a     (bid[i]),
                .b     (predict_flush_bid),
                .a_gt_b(bid_greater[i])
            );
        end
    endgenerate


    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_issue_rdy
            assign issue_rdy[i]     = valid[i] && prdy0[i] && prdy1[i];
            assign div_issue_rdy[i] = issue_rdy[i] && inst_type[i][2];
            assign mul_issue_rdy[i] = issue_rdy[i] && inst_type[i][1];
            assign bru_issue_rdy[i] = issue_rdy[i] && inst_type[i][0];
        end
    endgenerate

    generate
        assign div_issue_notice[0] = div_issue_rdy[0];
        assign div_issue_onehot[0] = div_issue_rdy[0];
        for (i = 1; i < DEPTH; i = i + 1) begin : gen_div_issue_notice_and_onehot
            assign div_issue_notice[i] = div_issue_rdy[i] || div_issue_notice[i-1];
            assign div_issue_onehot[i] = div_issue_notice[i] && !div_issue_notice[i-1];
        end

        assign mul_issue_notice[0] = mul_issue_rdy[0];
        assign mul_issue_onehot[0] = mul_issue_rdy[0];
        for (i = 1; i < DEPTH; i = i + 1) begin : gen_mul_issue_notice_and_onehot
            assign mul_issue_notice[i] = mul_issue_rdy[i] || mul_issue_notice[i-1];
            assign mul_issue_onehot[i] = mul_issue_notice[i] && !mul_issue_notice[i-1];
        end

        assign bru_issue_notice[0] = bru_issue_rdy[0];
        assign bru_issue_onehot[0] = bru_issue_rdy[0];
        for (i = 1; i < DEPTH; i = i + 1) begin : gen_bru_issue_notice_and_onehot
            assign bru_issue_notice[i] = bru_issue_rdy[i] || bru_issue_notice[i-1];
            assign bru_issue_onehot[i] = bru_issue_notice[i] && !bru_issue_notice[i-1];
        end
    endgenerate

    assign div_issue_found = |div_issue_rdy;
    assign mul_issue_found = |mul_issue_rdy;
    assign bru_issue_found = |bru_issue_rdy;


    generate
        for (select_entry = 0; select_entry < DEPTH; select_entry = select_entry + 1) begin : gen_issue_payload
            assign issue_payload[select_entry] = {
                opcode[select_entry],
                pdest[select_entry],
                psrc0[select_entry],
                psrc1[select_entry],
                bid[select_entry],
                rob_id[select_entry]
            };
        end

        for (select_bit = 0; select_bit < ISSUE_PAYLOAD_WIDTH; select_bit = select_bit + 1) begin : gen_issue_payload_or
            for (select_entry = 0; select_entry < DEPTH; select_entry = select_entry + 1) begin : gen_issue_payload_and
                assign div_payload_and[select_bit][select_entry] =
                    div_issue_onehot[select_entry] & issue_payload[select_entry][select_bit];
                assign mul_payload_and[select_bit][select_entry] =
                    mul_issue_onehot[select_entry] & issue_payload[select_entry][select_bit];
                assign bru_payload_and[select_bit][select_entry] =
                    bru_issue_onehot[select_entry] & issue_payload[select_entry][select_bit];
            end

            assign sel_div_payload[select_bit] = |div_payload_and[select_bit];
            assign sel_mul_payload[select_bit] = |mul_payload_and[select_bit];
            assign sel_bru_payload[select_bit] = |bru_payload_and[select_bit];
        end
    endgenerate

    assign {
        sel_div_issue_opcode,
        sel_div_issue_pdest,
        sel_div_issue_psrc0,
        sel_div_issue_psrc1,
        sel_div_issue_bid,
        sel_div_issue_rob_id
    } = sel_div_payload;

    assign {
        sel_mul_issue_opcode,
        sel_mul_issue_pdest,
        sel_mul_issue_psrc0,
        sel_mul_issue_psrc1,
        sel_mul_issue_bid,
        sel_mul_issue_rob_id
    } = sel_mul_payload;

    assign {
        sel_bru_issue_opcode,
        sel_bru_issue_pdest,
        sel_bru_issue_psrc0,
        sel_bru_issue_psrc1,
        sel_bru_issue_bid,
        sel_bru_issue_rob_id
    } = sel_bru_payload;

    wire [DEPTH - 1 : 0] dispatch_notice;
    wire [DEPTH - 1 : 0] dispatch_onehot;

    generate
        assign dispatch_notice[0] = ~valid[0];
        assign dispatch_onehot[0] = ~valid[0];
        for (i = 1; i < DEPTH; i = i + 1) begin : gen_dispatch_notice_and_onehot
            assign dispatch_notice[i] = (~valid[i]) || dispatch_notice[i-1];
            assign dispatch_onehot[i] = dispatch_notice[i] && !dispatch_notice[i-1];
        end
    endgenerate




    wire [DEPTH - 1 : 0] update_prdy0;
    wire [DEPTH - 1 : 0] update_prdy1;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_prdy
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





    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_change
            always @(posedge clk) begin
                if (!resetn || flush) begin
                    valid[i] <= 1'b0;
                end else if (predict_flush) begin
                    valid[i] <= ~bid_greater[i] & valid[i];
                end else if (dispatch_onehot[i] && dispatch_fire) begin
                    valid[i] <= dispatch_valid;
                end else if (div_issue_onehot[i] && div_issue_fire || mul_issue_onehot[i] && mul_issue_fire || bru_issue_onehot[i] && bru_issue_fire) begin
                    valid[i] <= 1'b0;
                end
            end


            always @(posedge clk) begin
                if (dispatch_onehot[i] && dispatch_fire) begin
                    opcode[i]    <= dispatch_opcode;
                    pdest[i]     <= dispatch_pdest;
                    psrc0[i]     <= dispatch_psrc0;
                    prdy0[i]     <= dispatch_prdy0;
                    psrc1[i]     <= dispatch_psrc1;
                    prdy1[i]     <= dispatch_prdy1;
                    bid[i]       <= dispatch_bid;
                    rob_id[i]    <= dispatch_rob_id;
                    inst_type[i] <= dispatch_inst_type;
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
            count <= predict_flush_count;
        end else begin
            count <= count - div_issue_fire - mul_issue_fire - bru_issue_fire + dispatch_fire;
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
