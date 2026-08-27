`include "header.v"

module md_issue_queue_lutram_core #(
        parameter DEPTH       = `MD_ISSUE_QUEUE_DEPTH,
        parameter TAG_WIDTH   = `MD_ISSUE_QUEUE_TAG_WIDTH,
        parameter OP_WIDTH    = `MD_ISSUE_QUEUE_OP_WIDTH,
        parameter COUNT_WIDTH = `MD_ISSUE_QUEUE_COUNT_WIDTH
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire [              3:0] dispatch_valid,
        output wire [              3:0] dispatch_ready,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_0,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_1,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_2,
        input  wire [     OP_WIDTH-1:0] dispatch_opcode_3,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_0,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_1,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_2,
        input  wire [    TAG_WIDTH-1:0] dispatch_pdest_3,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc0_0,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc0_1,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc0_2,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc0_3,
        input  wire [              3:0] dispatch_prdy0,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc1_0,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc1_1,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc1_2,
        input  wire [    TAG_WIDTH-1:0] dispatch_psrc1_3,
        input  wire [              3:0] dispatch_prdy1,
        input  wire [              4:0] dispatch_bid_0,
        input  wire [              4:0] dispatch_bid_1,
        input  wire [              4:0] dispatch_bid_2,
        input  wire [              4:0] dispatch_bid_3,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_0,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_1,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_2,
        input  wire [`ROB_ID_WIDTH-1:0] dispatch_rob_id_3,
        input  wire [              2:0] dispatch_inst_type_0,
        input  wire [              2:0] dispatch_inst_type_1,
        input  wire [              2:0] dispatch_inst_type_2,
        input  wire [              2:0] dispatch_inst_type_3,

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

    localparam ISSUE_PAYLOAD_WIDTH = OP_WIDTH + 3 * TAG_WIDTH
               + 5 + `ROB_ID_WIDTH;
    localparam LUTRAM_WIDTH = OP_WIDTH + TAG_WIDTH + `ROB_ID_WIDTH;

    reg [    DEPTH-1:0] valid;
    reg [TAG_WIDTH-1:0] psrc0     [DEPTH-1:0];
    reg                 prdy0     [DEPTH-1:0];
    reg [TAG_WIDTH-1:0] psrc1     [DEPTH-1:0];
    reg                 prdy1     [DEPTH-1:0];
    reg [          4:0] bid       [DEPTH-1:0];
    reg [          2:0] inst_type [DEPTH-1:0];

    reg [3:0] res_count0;
    reg [3:0] res_count1;
    reg [3:0] res_count2;
    reg [3:0] res_count3;

    wire [DEPTH-1:0] bid_greater;
    wire [DEPTH-1:0] update_prdy0;
    wire [DEPTH-1:0] update_prdy1;

    wire [3:0] dispatch_fire;

    wire div_issue_fire;
    wire div_issue_found;
    wire mul_issue_fire;
    wire mul_issue_found;
    wire bru_issue_fire;
    wire bru_issue_found;

    wire [DEPTH-1:0] issue_rdy;
    wire [DEPTH-1:0] div_issue_rdy;
    wire [DEPTH-1:0] div_issue_notice;
    wire [DEPTH-1:0] div_issue_onehot;
    wire [DEPTH-1:0] mul_issue_rdy;
    wire [DEPTH-1:0] mul_issue_notice;
    wire [DEPTH-1:0] mul_issue_onehot;
    wire [DEPTH-1:0] bru_issue_rdy;
    wire [DEPTH-1:0] bru_issue_notice;
    wire [DEPTH-1:0] bru_issue_onehot;

    wire [7:0] bank_valid0;
    wire [7:0] bank_valid1;
    wire [7:0] bank_valid2;
    wire [7:0] bank_valid3;
    wire [7:0] bank_first_free_notice0;
    wire [7:0] bank_first_free_notice1;
    wire [7:0] bank_first_free_notice2;
    wire [7:0] bank_first_free_notice3;
    wire [7:0] bank_first_free_onehot0;
    wire [7:0] bank_first_free_onehot1;
    wire [7:0] bank_first_free_onehot2;
    wire [7:0] bank_first_free_onehot3;
    wire [2:0] dispatch_row0;
    wire [2:0] dispatch_row1;
    wire [2:0] dispatch_row2;
    wire [2:0] dispatch_row3;
    wire [DEPTH-1:0] dispatch_onehot;

    wire [1:0] div_issue_bank;
    wire [2:0] div_issue_row;
    wire [1:0] mul_issue_bank;
    wire [2:0] mul_issue_row;
    wire [1:0] bru_issue_bank;
    wire [2:0] bru_issue_row;

    wire [LUTRAM_WIDTH-1:0] lutram_wdata0;
    wire [LUTRAM_WIDTH-1:0] lutram_wdata1;
    wire [LUTRAM_WIDTH-1:0] lutram_wdata2;
    wire [LUTRAM_WIDTH-1:0] lutram_wdata3;

    wire [LUTRAM_WIDTH-1:0] div_issue_lutram_data0;
    wire [LUTRAM_WIDTH-1:0] div_issue_lutram_data1;
    wire [LUTRAM_WIDTH-1:0] div_issue_lutram_data2;
    wire [LUTRAM_WIDTH-1:0] div_issue_lutram_data3;
    wire [LUTRAM_WIDTH-1:0] mul_issue_lutram_data0;
    wire [LUTRAM_WIDTH-1:0] mul_issue_lutram_data1;
    wire [LUTRAM_WIDTH-1:0] mul_issue_lutram_data2;
    wire [LUTRAM_WIDTH-1:0] mul_issue_lutram_data3;
    wire [LUTRAM_WIDTH-1:0] bru_issue_lutram_data0;
    wire [LUTRAM_WIDTH-1:0] bru_issue_lutram_data1;
    wire [LUTRAM_WIDTH-1:0] bru_issue_lutram_data2;
    wire [LUTRAM_WIDTH-1:0] bru_issue_lutram_data3;
    wire [LUTRAM_WIDTH-1:0] selected_div_issue_lutram_data;
    wire [LUTRAM_WIDTH-1:0] selected_mul_issue_lutram_data;
    wire [LUTRAM_WIDTH-1:0] selected_bru_issue_lutram_data;

    wire [OP_WIDTH-1:0] selected_div_issue_opcode;
    wire [TAG_WIDTH-1:0] selected_div_issue_pdest;
    wire [`ROB_ID_WIDTH-1:0] selected_div_issue_rob_id;
    wire [OP_WIDTH-1:0] selected_mul_issue_opcode;
    wire [TAG_WIDTH-1:0] selected_mul_issue_pdest;
    wire [`ROB_ID_WIDTH-1:0] selected_mul_issue_rob_id;
    wire [OP_WIDTH-1:0] selected_bru_issue_opcode;
    wire [TAG_WIDTH-1:0] selected_bru_issue_pdest;
    wire [`ROB_ID_WIDTH-1:0] selected_bru_issue_rob_id;

    wire [ISSUE_PAYLOAD_WIDTH-1:0] selected_div_issue_payload;
    wire [ISSUE_PAYLOAD_WIDTH-1:0] selected_mul_issue_payload;
    wire [ISSUE_PAYLOAD_WIDTH-1:0] selected_bru_issue_payload;

    wire [OP_WIDTH-1:0] sel_div_issue_opcode;
    wire [TAG_WIDTH-1:0] sel_div_issue_pdest;
    wire [TAG_WIDTH-1:0] sel_div_issue_psrc0;
    wire [TAG_WIDTH-1:0] sel_div_issue_psrc1;
    wire [4:0] sel_div_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] sel_div_issue_rob_id;
    wire [OP_WIDTH-1:0] sel_mul_issue_opcode;
    wire [TAG_WIDTH-1:0] sel_mul_issue_pdest;
    wire [TAG_WIDTH-1:0] sel_mul_issue_psrc0;
    wire [TAG_WIDTH-1:0] sel_mul_issue_psrc1;
    wire [4:0] sel_mul_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] sel_mul_issue_rob_id;
    wire [OP_WIDTH-1:0] sel_bru_issue_opcode;
    wire [TAG_WIDTH-1:0] sel_bru_issue_pdest;
    wire [TAG_WIDTH-1:0] sel_bru_issue_psrc0;
    wire [TAG_WIDTH-1:0] sel_bru_issue_psrc1;
    wire [4:0] sel_bru_issue_bid;
    wire [`ROB_ID_WIDTH-1:0] sel_bru_issue_rob_id;

    wire [COUNT_WIDTH-1:0] predict_flush_count;
    wire [31:0] popcount32_data;
    wire [7:0] bank_survivor0;
    wire [7:0] bank_survivor1;
    wire [7:0] bank_survivor2;
    wire [7:0] bank_survivor3;
    wire [3:0] bank_predict_count0;
    wire [3:0] bank_predict_count1;
    wire [3:0] bank_predict_count2;
    wire [3:0] bank_predict_count3;

    function automatic [3:0] popcount8;
        input [7:0] data;
        integer k;
        begin
            popcount8 = 4'd0;
            for (k = 0; k < 8; k = k + 1) begin
                popcount8 = popcount8 + data[k];
            end
        end
    endfunction

    assign full  = count == DEPTH;
    assign empty = count == {COUNT_WIDTH{1'b0}};

    assign dispatch_ready[0] = res_count0 != 4'd0;
    assign dispatch_ready[1] = res_count1 != 4'd0;
    assign dispatch_ready[2] = res_count2 != 4'd0;
    assign dispatch_ready[3] = res_count3 != 4'd0;
    assign dispatch_fire = dispatch_valid & dispatch_ready;

    assign div_issue_valid = div_issue_found && !predict_flush;
    assign div_issue_fire  = div_issue_valid && div_issue_ready;
    assign mul_issue_valid = mul_issue_found && !predict_flush;
    assign mul_issue_fire  = mul_issue_valid && mul_issue_ready;
    assign bru_issue_valid = bru_issue_found && !predict_flush;
    assign bru_issue_fire  = bru_issue_valid && bru_issue_ready;

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

    assign bank_valid0 = {
               valid[28], valid[24], valid[20], valid[16],
               valid[12], valid[ 8], valid[ 4], valid[ 0]
           };
    assign bank_valid1 = {
               valid[29], valid[25], valid[21], valid[17],
               valid[13], valid[ 9], valid[ 5], valid[ 1]
           };
    assign bank_valid2 = {
               valid[30], valid[26], valid[22], valid[18],
               valid[14], valid[10], valid[ 6], valid[ 2]
           };
    assign bank_valid3 = {
               valid[31], valid[27], valid[23], valid[19],
               valid[15], valid[11], valid[ 7], valid[ 3]
           };

    genvar free_row;
    generate
        assign bank_first_free_notice0[0] = ~bank_valid0[0];
        assign bank_first_free_notice1[0] = ~bank_valid1[0];
        assign bank_first_free_notice2[0] = ~bank_valid2[0];
        assign bank_first_free_notice3[0] = ~bank_valid3[0];
        assign bank_first_free_onehot0[0] = ~bank_valid0[0];
        assign bank_first_free_onehot1[0] = ~bank_valid1[0];
        assign bank_first_free_onehot2[0] = ~bank_valid2[0];
        assign bank_first_free_onehot3[0] = ~bank_valid3[0];

        for (free_row = 1; free_row < 8; free_row = free_row + 1) begin : gen_bank_first_free
            assign bank_first_free_notice0[free_row] =
                   (~bank_valid0[free_row]) || bank_first_free_notice0[free_row-1];
            assign bank_first_free_notice1[free_row] =
                   (~bank_valid1[free_row]) || bank_first_free_notice1[free_row-1];
            assign bank_first_free_notice2[free_row] =
                   (~bank_valid2[free_row]) || bank_first_free_notice2[free_row-1];
            assign bank_first_free_notice3[free_row] =
                   (~bank_valid3[free_row]) || bank_first_free_notice3[free_row-1];

            assign bank_first_free_onehot0[free_row] =
                   bank_first_free_notice0[free_row] && !bank_first_free_notice0[free_row-1];
            assign bank_first_free_onehot1[free_row] =
                   bank_first_free_notice1[free_row] && !bank_first_free_notice1[free_row-1];
            assign bank_first_free_onehot2[free_row] =
                   bank_first_free_notice2[free_row] && !bank_first_free_notice2[free_row-1];
            assign bank_first_free_onehot3[free_row] =
                   bank_first_free_notice3[free_row] && !bank_first_free_notice3[free_row-1];
        end
    endgenerate

    assign dispatch_row0 = {
               |(bank_first_free_onehot0 & 8'hF0),
               |(bank_first_free_onehot0 & 8'hCC),
               |(bank_first_free_onehot0 & 8'hAA)
           };
    assign dispatch_row1 = {
               |(bank_first_free_onehot1 & 8'hF0),
               |(bank_first_free_onehot1 & 8'hCC),
               |(bank_first_free_onehot1 & 8'hAA)
           };
    assign dispatch_row2 = {
               |(bank_first_free_onehot2 & 8'hF0),
               |(bank_first_free_onehot2 & 8'hCC),
               |(bank_first_free_onehot2 & 8'hAA)
           };
    assign dispatch_row3 = {
               |(bank_first_free_onehot3 & 8'hF0),
               |(bank_first_free_onehot3 & 8'hCC),
               |(bank_first_free_onehot3 & 8'hAA)
           };

    genvar dispatch_row_index;
    generate
        for (dispatch_row_index = 0; dispatch_row_index < 8;
                dispatch_row_index = dispatch_row_index + 1) begin : gen_dispatch_onehot
            assign dispatch_onehot[dispatch_row_index*4 + 0] =
                   bank_first_free_onehot0[dispatch_row_index];
            assign dispatch_onehot[dispatch_row_index*4 + 1] =
                   bank_first_free_onehot1[dispatch_row_index];
            assign dispatch_onehot[dispatch_row_index*4 + 2] =
                   bank_first_free_onehot2[dispatch_row_index];
            assign dispatch_onehot[dispatch_row_index*4 + 3] =
                   bank_first_free_onehot3[dispatch_row_index];
        end
    endgenerate

    assign lutram_wdata0 = {
               dispatch_opcode_0, dispatch_pdest_0, dispatch_rob_id_0
           };
    assign lutram_wdata1 = {
               dispatch_opcode_1, dispatch_pdest_1, dispatch_rob_id_1
           };
    assign lutram_wdata2 = {
               dispatch_opcode_2, dispatch_pdest_2, dispatch_rob_id_2
           };
    assign lutram_wdata3 = {
               dispatch_opcode_3, dispatch_pdest_3, dispatch_rob_id_3
           };

    md_iq_lutram_16x25 u_bank0_div (
                           .a({1'b0, dispatch_row0}), .d(lutram_wdata0),
                           .dpra({1'b0, div_issue_row}), .clk(clk),
                           .we(dispatch_fire[0]), .dpo(div_issue_lutram_data0)
                       );
    md_iq_lutram_16x25 u_bank0_mul (
                           .a({1'b0, dispatch_row0}), .d(lutram_wdata0),
                           .dpra({1'b0, mul_issue_row}), .clk(clk),
                           .we(dispatch_fire[0]), .dpo(mul_issue_lutram_data0)
                       );
    md_iq_lutram_16x25 u_bank0_bru (
                           .a({1'b0, dispatch_row0}), .d(lutram_wdata0),
                           .dpra({1'b0, bru_issue_row}), .clk(clk),
                           .we(dispatch_fire[0]), .dpo(bru_issue_lutram_data0)
                       );
    md_iq_lutram_16x25 u_bank1_div (
                           .a({1'b0, dispatch_row1}), .d(lutram_wdata1),
                           .dpra({1'b0, div_issue_row}), .clk(clk),
                           .we(dispatch_fire[1]), .dpo(div_issue_lutram_data1)
                       );
    md_iq_lutram_16x25 u_bank1_mul (
                           .a({1'b0, dispatch_row1}), .d(lutram_wdata1),
                           .dpra({1'b0, mul_issue_row}), .clk(clk),
                           .we(dispatch_fire[1]), .dpo(mul_issue_lutram_data1)
                       );
    md_iq_lutram_16x25 u_bank1_bru (
                           .a({1'b0, dispatch_row1}), .d(lutram_wdata1),
                           .dpra({1'b0, bru_issue_row}), .clk(clk),
                           .we(dispatch_fire[1]), .dpo(bru_issue_lutram_data1)
                       );
    md_iq_lutram_16x25 u_bank2_div (
                           .a({1'b0, dispatch_row2}), .d(lutram_wdata2),
                           .dpra({1'b0, div_issue_row}), .clk(clk),
                           .we(dispatch_fire[2]), .dpo(div_issue_lutram_data2)
                       );
    md_iq_lutram_16x25 u_bank2_mul (
                           .a({1'b0, dispatch_row2}), .d(lutram_wdata2),
                           .dpra({1'b0, mul_issue_row}), .clk(clk),
                           .we(dispatch_fire[2]), .dpo(mul_issue_lutram_data2)
                       );
    md_iq_lutram_16x25 u_bank2_bru (
                           .a({1'b0, dispatch_row2}), .d(lutram_wdata2),
                           .dpra({1'b0, bru_issue_row}), .clk(clk),
                           .we(dispatch_fire[2]), .dpo(bru_issue_lutram_data2)
                       );
    md_iq_lutram_16x25 u_bank3_div (
                           .a({1'b0, dispatch_row3}), .d(lutram_wdata3),
                           .dpra({1'b0, div_issue_row}), .clk(clk),
                           .we(dispatch_fire[3]), .dpo(div_issue_lutram_data3)
                       );
    md_iq_lutram_16x25 u_bank3_mul (
                           .a({1'b0, dispatch_row3}), .d(lutram_wdata3),
                           .dpra({1'b0, mul_issue_row}), .clk(clk),
                           .we(dispatch_fire[3]), .dpo(mul_issue_lutram_data3)
                       );
    md_iq_lutram_16x25 u_bank3_bru (
                           .a({1'b0, dispatch_row3}), .d(lutram_wdata3),
                           .dpra({1'b0, bru_issue_row}), .clk(clk),
                           .we(dispatch_fire[3]), .dpo(bru_issue_lutram_data3)
                       );

    genvar i;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_greater
            circle_comparator u_circle_comparator (
                                  .head(head_bid), .a(bid[i]), .b(predict_flush_bid),
                                  .a_gt_b(bid_greater[i])
                              );
        end
    endgenerate

    assign popcount32_data = ~bid_greater & valid;

    popcount32 u_popcount32 (
                   .data(popcount32_data),
                   .count(predict_flush_count)
               );

    assign bank_survivor0 = {
               popcount32_data[28], popcount32_data[24],
               popcount32_data[20], popcount32_data[16],
               popcount32_data[12], popcount32_data[ 8],
               popcount32_data[ 4], popcount32_data[ 0]
           };
    assign bank_survivor1 = {
               popcount32_data[29], popcount32_data[25],
               popcount32_data[21], popcount32_data[17],
               popcount32_data[13], popcount32_data[ 9],
               popcount32_data[ 5], popcount32_data[ 1]
           };
    assign bank_survivor2 = {
               popcount32_data[30], popcount32_data[26],
               popcount32_data[22], popcount32_data[18],
               popcount32_data[14], popcount32_data[10],
               popcount32_data[ 6], popcount32_data[ 2]
           };
    assign bank_survivor3 = {
               popcount32_data[31], popcount32_data[27],
               popcount32_data[23], popcount32_data[19],
               popcount32_data[15], popcount32_data[11],
               popcount32_data[ 7], popcount32_data[ 3]
           };

    assign bank_predict_count0 = popcount8(bank_survivor0);
    assign bank_predict_count1 = popcount8(bank_survivor1);
    assign bank_predict_count2 = popcount8(bank_survivor2);
    assign bank_predict_count3 = popcount8(bank_survivor3);

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_issue_rdy
            assign issue_rdy[i] = valid[i] && prdy0[i] && prdy1[i];
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

    assign div_issue_bank[0] = |(div_issue_onehot & 32'hAAAA_AAAA);
    assign div_issue_bank[1] = |(div_issue_onehot & 32'hCCCC_CCCC);
    assign div_issue_row[0] = |(div_issue_onehot & 32'hF0F0_F0F0);
    assign div_issue_row[1] = |(div_issue_onehot & 32'hFF00_FF00);
    assign div_issue_row[2] = |(div_issue_onehot & 32'hFFFF_0000);
    assign mul_issue_bank[0] = |(mul_issue_onehot & 32'hAAAA_AAAA);
    assign mul_issue_bank[1] = |(mul_issue_onehot & 32'hCCCC_CCCC);
    assign mul_issue_row[0] = |(mul_issue_onehot & 32'hF0F0_F0F0);
    assign mul_issue_row[1] = |(mul_issue_onehot & 32'hFF00_FF00);
    assign mul_issue_row[2] = |(mul_issue_onehot & 32'hFFFF_0000);
    assign bru_issue_bank[0] = |(bru_issue_onehot & 32'hAAAA_AAAA);
    assign bru_issue_bank[1] = |(bru_issue_onehot & 32'hCCCC_CCCC);
    assign bru_issue_row[0] = |(bru_issue_onehot & 32'hF0F0_F0F0);
    assign bru_issue_row[1] = |(bru_issue_onehot & 32'hFF00_FF00);
    assign bru_issue_row[2] = |(bru_issue_onehot & 32'hFFFF_0000);

    assign selected_div_issue_lutram_data =
           (div_issue_bank == 2'd0) ? div_issue_lutram_data0 :
           (div_issue_bank == 2'd1) ? div_issue_lutram_data1 :
           (div_issue_bank == 2'd2) ? div_issue_lutram_data2 :
           div_issue_lutram_data3;
    assign selected_mul_issue_lutram_data =
           (mul_issue_bank == 2'd0) ? mul_issue_lutram_data0 :
           (mul_issue_bank == 2'd1) ? mul_issue_lutram_data1 :
           (mul_issue_bank == 2'd2) ? mul_issue_lutram_data2 :
           mul_issue_lutram_data3;
    assign selected_bru_issue_lutram_data =
           (bru_issue_bank == 2'd0) ? bru_issue_lutram_data0 :
           (bru_issue_bank == 2'd1) ? bru_issue_lutram_data1 :
           (bru_issue_bank == 2'd2) ? bru_issue_lutram_data2 :
           bru_issue_lutram_data3;

    assign {
            selected_div_issue_opcode,
            selected_div_issue_pdest,
            selected_div_issue_rob_id
        } = selected_div_issue_lutram_data;
    assign {
            selected_mul_issue_opcode,
            selected_mul_issue_pdest,
            selected_mul_issue_rob_id
        } = selected_mul_issue_lutram_data;
    assign {
            selected_bru_issue_opcode,
            selected_bru_issue_pdest,
            selected_bru_issue_rob_id
        } = selected_bru_issue_lutram_data;

    assign selected_div_issue_payload = {
               selected_div_issue_opcode,
               selected_div_issue_pdest,
               psrc0[{div_issue_row, div_issue_bank}],
               psrc1[{div_issue_row, div_issue_bank}],
               bid[{div_issue_row, div_issue_bank}],
               selected_div_issue_rob_id
           };
    assign selected_mul_issue_payload = {
               selected_mul_issue_opcode,
               selected_mul_issue_pdest,
               psrc0[{mul_issue_row, mul_issue_bank}],
               psrc1[{mul_issue_row, mul_issue_bank}],
               bid[{mul_issue_row, mul_issue_bank}],
               selected_mul_issue_rob_id
           };
    assign selected_bru_issue_payload = {
               selected_bru_issue_opcode,
               selected_bru_issue_pdest,
               psrc0[{bru_issue_row, bru_issue_bank}],
               psrc1[{bru_issue_row, bru_issue_bank}],
               bid[{bru_issue_row, bru_issue_bank}],
               selected_bru_issue_rob_id
           };

    assign {
            sel_div_issue_opcode,
            sel_div_issue_pdest,
            sel_div_issue_psrc0,
            sel_div_issue_psrc1,
            sel_div_issue_bid,
            sel_div_issue_rob_id
        } = selected_div_issue_payload;
    assign {
            sel_mul_issue_opcode,
            sel_mul_issue_pdest,
            sel_mul_issue_psrc0,
            sel_mul_issue_psrc1,
            sel_mul_issue_bid,
            sel_mul_issue_rob_id
        } = selected_mul_issue_payload;
    assign {
            sel_bru_issue_opcode,
            sel_bru_issue_pdest,
            sel_bru_issue_psrc0,
            sel_bru_issue_psrc1,
            sel_bru_issue_bid,
            sel_bru_issue_rob_id
        } = selected_bru_issue_payload;

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
                   (bypass7_valid && (psrc1[i] == bypass7_dst)) ;
        end
    endgenerate

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_change
            always @(posedge clk) begin
                if (!resetn || flush) begin
                    valid[i] <= 1'b0;
                end
                else if (predict_flush) begin
                    valid[i] <= ~bid_greater[i] & valid[i];
                end
                else if (
                    dispatch_onehot[i] && dispatch_fire[i % 4]
                ) begin
                    valid[i] <= dispatch_valid[i % 4];
                end
                else if (
                    (div_issue_onehot[i] && div_issue_fire) ||
                    (mul_issue_onehot[i] && mul_issue_fire) ||
                    (bru_issue_onehot[i] && bru_issue_fire)
                ) begin
                    valid[i] <= 1'b0;
                end
            end

            always @(posedge clk) begin
                if (dispatch_onehot[i] && dispatch_fire[i % 4]) begin
                    psrc0[i]     <= ((i % 4) == 0) ? dispatch_psrc0_0 :
                         ((i % 4) == 1) ? dispatch_psrc0_1 :
                         ((i % 4) == 2) ? dispatch_psrc0_2 :
                         dispatch_psrc0_3;
                    prdy0[i]     <= dispatch_prdy0[i % 4];
                    psrc1[i]     <= ((i % 4) == 0) ? dispatch_psrc1_0 :
                         ((i % 4) == 1) ? dispatch_psrc1_1 :
                         ((i % 4) == 2) ? dispatch_psrc1_2 :
                         dispatch_psrc1_3;
                    prdy1[i]     <= dispatch_prdy1[i % 4];
                    bid[i]       <= ((i % 4) == 0) ? dispatch_bid_0 :
                       ((i % 4) == 1) ? dispatch_bid_1 :
                       ((i % 4) == 2) ? dispatch_bid_2 :
                       dispatch_bid_3;
                    inst_type[i] <= ((i % 4) == 0) ? dispatch_inst_type_0 :
                             ((i % 4) == 1) ? dispatch_inst_type_1 :
                             ((i % 4) == 2) ? dispatch_inst_type_2 :
                             dispatch_inst_type_3;
                end
                else begin
                    prdy0[i] <= update_prdy0[i];
                    prdy1[i] <= update_prdy1[i];
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn || flush) begin
            count <= {COUNT_WIDTH{1'b0}};
        end
        else if (predict_flush) begin
            count <= predict_flush_count;
        end
        else begin
            count <= count
                  + {{(COUNT_WIDTH-1){1'b0}}, dispatch_fire[0]}
                  + {{(COUNT_WIDTH-1){1'b0}}, dispatch_fire[1]}
                  + {{(COUNT_WIDTH-1){1'b0}}, dispatch_fire[2]}
                  + {{(COUNT_WIDTH-1){1'b0}}, dispatch_fire[3]}
                  - {{(COUNT_WIDTH-1){1'b0}}, div_issue_fire}
                  - {{(COUNT_WIDTH-1){1'b0}}, mul_issue_fire}
                  - {{(COUNT_WIDTH-1){1'b0}}, bru_issue_fire};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            res_count0 <= 4'd8;
        end
        else if (predict_flush) begin
            res_count0 <= 4'd8 - bank_predict_count0;
        end
        else begin
            res_count0 <= res_count0
                       + {3'b0, (div_issue_fire && (div_issue_bank == 2'd0))}
                       + {3'b0, (mul_issue_fire && (mul_issue_bank == 2'd0))}
                       + {3'b0, (bru_issue_fire && (bru_issue_bank == 2'd0))}
                       - {3'b0, dispatch_fire[0]};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            res_count1 <= 4'd8;
        end
        else if (predict_flush) begin
            res_count1 <= 4'd8 - bank_predict_count1;
        end
        else begin
            res_count1 <= res_count1
                       + {3'b0, (div_issue_fire && (div_issue_bank == 2'd1))}
                       + {3'b0, (mul_issue_fire && (mul_issue_bank == 2'd1))}
                       + {3'b0, (bru_issue_fire && (bru_issue_bank == 2'd1))}
                       - {3'b0, dispatch_fire[1]};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            res_count2 <= 4'd8;
        end
        else if (predict_flush) begin
            res_count2 <= 4'd8 - bank_predict_count2;
        end
        else begin
            res_count2 <= res_count2
                       + {3'b0, (div_issue_fire && (div_issue_bank == 2'd2))}
                       + {3'b0, (mul_issue_fire && (mul_issue_bank == 2'd2))}
                       + {3'b0, (bru_issue_fire && (bru_issue_bank == 2'd2))}
                       - {3'b0, dispatch_fire[2]};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            res_count3 <= 4'd8;
        end
        else if (predict_flush) begin
            res_count3 <= 4'd8 - bank_predict_count3;
        end
        else begin
            res_count3 <= res_count3
                       + {3'b0, (div_issue_fire && (div_issue_bank == 2'd3))}
                       + {3'b0, (mul_issue_fire && (mul_issue_bank == 2'd3))}
                       + {3'b0, (bru_issue_fire && (bru_issue_bank == 2'd3))}
                       - {3'b0, dispatch_fire[3]};
        end
    end

    `ifndef SYNTHESIS
            function automatic onehot0_32;
                input [31:0] data;
                begin
                    onehot0_32 = (data == 32'd0) ||
                               ((data & (data - 32'd1)) == 32'd0);
                end
            endfunction

            wire [COUNT_WIDTH-1:0] count_from_valid;
    popcount32 u_count_from_valid (
                   .data(valid),
                   .count(count_from_valid)
               );

    always @(posedge clk) begin
        if (resetn) begin
            if (dispatch_fire[0] &&
                    !((dispatch_inst_type_0 == 3'b100) ||
                      (dispatch_inst_type_0 == 3'b010) ||
                      (dispatch_inst_type_0 == 3'b001))) begin
                $error("accepted dispatch_inst_type must be one-hot");
            end
            if (dispatch_fire[1] &&
                    !((dispatch_inst_type_1 == 3'b100) ||
                      (dispatch_inst_type_1 == 3'b010) ||
                      (dispatch_inst_type_1 == 3'b001))) begin
                $error("accepted dispatch_inst_type must be one-hot");
            end
            if (dispatch_fire[2] &&
                    !((dispatch_inst_type_2 == 3'b100) ||
                      (dispatch_inst_type_2 == 3'b010) ||
                      (dispatch_inst_type_2 == 3'b001))) begin
                $error("accepted dispatch_inst_type must be one-hot");
            end
            if (dispatch_fire[3] &&
                    !((dispatch_inst_type_3 == 3'b100) ||
                      (dispatch_inst_type_3 == 3'b010) ||
                      (dispatch_inst_type_3 == 3'b001))) begin
                $error("accepted dispatch_inst_type must be one-hot");
            end
            if (!onehot0_32(div_issue_onehot) ||
                    !onehot0_32(mul_issue_onehot) ||
                    !onehot0_32(bru_issue_onehot)) begin
                $error("issue selection is not onehot0");
            end
            if (|(div_issue_onehot & mul_issue_onehot) ||
                    |(div_issue_onehot & bru_issue_onehot) ||
                    |(mul_issue_onehot & bru_issue_onehot)) begin
                $error("legal inst_type entries selected by multiple issue types");
            end
            if (count != count_from_valid) begin
                $error("count does not equal popcount(valid)");
            end
            if ((res_count0 != (4'd8 - popcount8(bank_valid0))) ||
                    (res_count1 != (4'd8 - popcount8(bank_valid1))) ||
                    (res_count2 != (4'd8 - popcount8(bank_valid2))) ||
                    (res_count3 != (4'd8 - popcount8(bank_valid3)))) begin
                $error("res_count does not match bank valid state");
            end
        end
    end
`endif

endmodule
