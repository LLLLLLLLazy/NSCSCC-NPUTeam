`include "header.v"

module alu_issue_queue_lutram_core #(
        parameter DEPTH       = `ISSUE_QUEUE_DEPTH,
        parameter TAG_WIDTH   = `ISSUE_QUEUE_TAG_WIDTH,
        parameter OP_WIDTH    = `ISSUE_QUEUE_OP_WIDTH,
        parameter IMM_WIDTH   = `ISSUE_QUEUE_IMM_WIDTH,
        parameter COUNT_WIDTH = `ISSUE_QUEUE_COUNT_WIDTH
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire [                3:0] dispatch_valid,
        output wire [                3:0] dispatch_ready,
        input  wire [       OP_WIDTH-1:0] dispatch_opcode_0,
        input  wire [       OP_WIDTH-1:0] dispatch_opcode_1,
        input  wire [       OP_WIDTH-1:0] dispatch_opcode_2,
        input  wire [       OP_WIDTH-1:0] dispatch_opcode_3,
        input  wire [      TAG_WIDTH-1:0] dispatch_pdest_0,
        input  wire [      TAG_WIDTH-1:0] dispatch_pdest_1,
        input  wire [      TAG_WIDTH-1:0] dispatch_pdest_2,
        input  wire [      TAG_WIDTH-1:0] dispatch_pdest_3,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc0_0,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc0_1,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc0_2,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc0_3,
        input  wire [                3:0] dispatch_prdy0,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc1_0,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc1_1,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc1_2,
        input  wire [      TAG_WIDTH-1:0] dispatch_psrc1_3,
        input  wire [                3:0] dispatch_prdy1,
        input  wire [      IMM_WIDTH-1:0] dispatch_imm_0,
        input  wire [      IMM_WIDTH-1:0] dispatch_imm_1,
        input  wire [      IMM_WIDTH-1:0] dispatch_imm_2,
        input  wire [      IMM_WIDTH-1:0] dispatch_imm_3,
        input  wire [                4:0] dispatch_bid_0,
        input  wire [                4:0] dispatch_bid_1,
        input  wire [                4:0] dispatch_bid_2,
        input  wire [                4:0] dispatch_bid_3,
        input  wire [`ROB_ID_WIDTH-1 : 0] dispatch_rob_id_0,
        input  wire [`ROB_ID_WIDTH-1 : 0] dispatch_rob_id_1,
        input  wire [`ROB_ID_WIDTH-1 : 0] dispatch_rob_id_2,
        input  wire [`ROB_ID_WIDTH-1 : 0] dispatch_rob_id_3,

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

        output wire                       issue_valid,
        input  wire                       issue_ready,
        output wire [       OP_WIDTH-1:0] issue_opcode,
        output wire [      TAG_WIDTH-1:0] issue_pdest,
        output wire [      TAG_WIDTH-1:0] issue_psrc0,
        output wire [      TAG_WIDTH-1:0] issue_psrc1,
        output wire [      IMM_WIDTH-1:0] issue_imm,
        output wire [                4:0] issue_bid,
        output wire [`ROB_ID_WIDTH-1 : 0] issue_rob_id,

        output wire                       extra_issue_valid,
        input  wire                       extra_issue_ready,
        output wire [       OP_WIDTH-1:0] extra_issue_opcode,
        output wire [      TAG_WIDTH-1:0] extra_issue_pdest,
        output wire [      TAG_WIDTH-1:0] extra_issue_psrc0,
        output wire [      TAG_WIDTH-1:0] extra_issue_psrc1,
        output wire [      IMM_WIDTH-1:0] extra_issue_imm,
        output wire [                4:0] extra_issue_bid,
        output wire [`ROB_ID_WIDTH-1 : 0] extra_issue_rob_id,

        output wire                   full,
        output wire                   empty,
        output reg  [COUNT_WIDTH-1:0] count,

        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid
    );

    localparam INDEX_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam ISSUE_PAYLOAD_WIDTH = OP_WIDTH + 3 * TAG_WIDTH + IMM_WIDTH
               + 5 + `ROB_ID_WIDTH;
    localparam LUTRAM_WIDTH = OP_WIDTH + TAG_WIDTH + IMM_WIDTH
               + `ROB_ID_WIDTH;//（6+32+7+7）52

    reg  [          DEPTH-1:0] valid;
    reg  [      TAG_WIDTH-1:0] psrc0 [DEPTH-1:0];
    reg                        prdy0 [DEPTH-1:0];
    reg  [      TAG_WIDTH-1:0] psrc1 [DEPTH-1:0];
    reg                        prdy1 [DEPTH-1:0];
    reg  [                4:0] bid   [DEPTH-1:0];

    reg [3:0] bank_count0;//四个4位计数器，分别表示各bank中的有效指令数量
    reg [3:0] bank_count1;
    reg [3:0] bank_count2;
    reg [3:0] bank_count3;

    wire [7:0] bank_valid0;//四个8位组合视图，每个bit对应该bank的一个row
    wire [7:0] bank_valid1;
    wire [7:0] bank_valid2;
    wire [7:0] bank_valid3;

    wire [7:0] bank_free0;//表示每个bank中的row是否空闲，即~valid
    wire [7:0] bank_free1;
    wire [7:0] bank_free2;
    wire [7:0] bank_free3;

    wire [7:0] bank_first_free_onehot0;//表示每个bank中第一个空闲的row的onehot编码，空闲即为valid为0
    wire [7:0] bank_first_free_onehot1;
    wire [7:0] bank_first_free_onehot2;
    wire [7:0] bank_first_free_onehot3;

    wire [2:0] dispatch_row0;//四个3位地址，分别指向各bank将写入的row
    wire [2:0] dispatch_row1;
    wire [2:0] dispatch_row2;
    wire [2:0] dispatch_row3;

    wire [DEPTH-1:0] dispatch_onehot;
    wire [       3:0] dispatch_fire;

    wire                  issue_fire;
    wire                  issue_found;
    wire                  extra_issue_fire;
    wire                  extra_issue_found;
    wire [     DEPTH-1:0] issue_rdy;
    wire [     DEPTH-1:0] issue_notice;
    wire [     DEPTH-1:0] issue_onehot;
    wire [     DEPTH-1:0] extra_issue_notice;
    wire [     DEPTH-1:0] extra_issue_onehot;
    wire [           1:0] issue_bank;
    wire [           2:0] issue_row;
    wire [           1:0] extra_issue_bank;
    wire [           2:0] extra_issue_row;

    wire [       OP_WIDTH-1:0] sel_issue_opcode;
    wire [      TAG_WIDTH-1:0] sel_issue_pdest;
    wire [      TAG_WIDTH-1:0] sel_issue_psrc0;
    wire [      TAG_WIDTH-1:0] sel_issue_psrc1;
    wire [      IMM_WIDTH-1:0] sel_issue_imm;
    wire [                4:0] sel_issue_bid;
    wire [`ROB_ID_WIDTH-1 : 0] sel_issue_rob_id;

    wire [       OP_WIDTH-1:0] sel_extra_issue_opcode;
    wire [      TAG_WIDTH-1:0] sel_extra_issue_pdest;
    wire [      TAG_WIDTH-1:0] sel_extra_issue_psrc0;
    wire [      TAG_WIDTH-1:0] sel_extra_issue_psrc1;
    wire [      IMM_WIDTH-1:0] sel_extra_issue_imm;
    wire [                4:0] sel_extra_issue_bid;
    wire [`ROB_ID_WIDTH-1 : 0] sel_extra_issue_rob_id;

    // wire [ISSUE_PAYLOAD_WIDTH-1:0] sel_issue_payload;
    // wire [ISSUE_PAYLOAD_WIDTH-1:0] sel_extra_issue_payload;
    wire [ISSUE_PAYLOAD_WIDTH-1:0] selected_issue_payload;
    wire [ISSUE_PAYLOAD_WIDTH-1:0] selected_extra_issue_payload;

    wire [LUTRAM_WIDTH-1:0] lutram_wdata0;
    wire [LUTRAM_WIDTH-1:0] lutram_wdata1;
    wire [LUTRAM_WIDTH-1:0] lutram_wdata2;
    wire [LUTRAM_WIDTH-1:0] lutram_wdata3;

    wire [LUTRAM_WIDTH-1:0] issue_lutram_data0;
    wire [LUTRAM_WIDTH-1:0] issue_lutram_data1;
    wire [LUTRAM_WIDTH-1:0] issue_lutram_data2;
    wire [LUTRAM_WIDTH-1:0] issue_lutram_data3;
    wire [LUTRAM_WIDTH-1:0] extra_issue_lutram_data0;
    wire [LUTRAM_WIDTH-1:0] extra_issue_lutram_data1;
    wire [LUTRAM_WIDTH-1:0] extra_issue_lutram_data2;
    wire [LUTRAM_WIDTH-1:0] extra_issue_lutram_data3;
    wire [LUTRAM_WIDTH-1:0] selected_issue_lutram_data;//从四个里面去选出来
    wire [LUTRAM_WIDTH-1:0] selected_extra_issue_lutram_data;

    wire [       OP_WIDTH-1:0] selected_issue_opcode;
    wire [      TAG_WIDTH-1:0] selected_issue_pdest;
    wire [      IMM_WIDTH-1:0] selected_issue_imm;
    wire [`ROB_ID_WIDTH-1 : 0] selected_issue_rob_id;
    wire [       OP_WIDTH-1:0] selected_extra_issue_opcode;
    wire [      TAG_WIDTH-1:0] selected_extra_issue_pdest;
    wire [      IMM_WIDTH-1:0] selected_extra_issue_imm;
    wire [`ROB_ID_WIDTH-1 : 0] selected_extra_issue_rob_id;

    wire [DEPTH-1:0] bid_greater;
    wire [DEPTH-1:0] update_prdy0;
    wire [DEPTH-1:0] update_prdy1;

    wire [31:0] popcount32_data;
    wire [COUNT_WIDTH-1:0] predict_flush_count;
    wire [7:0] bank_survivor0;
    wire [7:0] bank_survivor1;
    wire [7:0] bank_survivor2;
    wire [7:0] bank_survivor3;
    wire [3:0] bank_predict_count0;
    wire [3:0] bank_predict_count1;
    wire [3:0] bank_predict_count2;
    wire [3:0] bank_predict_count3;

    //统计一个8位向量中有多少个1
    function automatic [3:0] popcount8;
        input [7:0] data;
        reg [2:0] count_low6;
        reg [1:0] count_high2;
        begin
            count_low6 =
                {2'b0, data[0]}
                + {2'b0, data[1]}
                + {2'b0, data[2]}
                + {2'b0, data[3]}
                + {2'b0, data[4]}
                + {2'b0, data[5]};

            count_high2 =
                {1'b0, data[6]}
                + {1'b0, data[7]};

            popcount8 =
                {1'b0, count_low6}
                + {2'b0, count_high2};
        end
    endfunction

    assign full  = count == DEPTH;
    assign empty = (count == {COUNT_WIDTH{1'b0}});

    assign dispatch_ready[0] = ~bank_count0[3];
    assign dispatch_ready[1] = ~bank_count1[3];
    assign dispatch_ready[2] = ~bank_count2[3];
    assign dispatch_ready[3] = ~bank_count3[3];
    assign dispatch_fire     = dispatch_valid & dispatch_ready;

    assign issue_valid       = issue_found && !predict_flush;
    assign issue_fire        = issue_valid && issue_ready;
    assign extra_issue_valid = extra_issue_found && !predict_flush;
    assign extra_issue_fire  = extra_issue_valid && extra_issue_ready;

    assign issue_opcode = sel_issue_opcode;
    assign issue_pdest  = sel_issue_pdest;
    assign issue_psrc0  = sel_issue_psrc0;
    assign issue_psrc1  = sel_issue_psrc1;
    assign issue_imm    = sel_issue_imm;
    assign issue_bid    = sel_issue_bid;
    assign issue_rob_id = sel_issue_rob_id;

    assign extra_issue_opcode = sel_extra_issue_opcode;
    assign extra_issue_pdest  = sel_extra_issue_pdest;
    assign extra_issue_psrc0  = sel_extra_issue_psrc0;
    assign extra_issue_psrc1  = sel_extra_issue_psrc1;
    assign extra_issue_imm    = sel_extra_issue_imm;
    assign extra_issue_bid    = sel_extra_issue_bid;
    assign extra_issue_rob_id = sel_extra_issue_rob_id;

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

    assign bank_free0 = ~bank_valid0;
    assign bank_free1 = ~bank_valid1;
    assign bank_free2 = ~bank_valid2;
    assign bank_free3 = ~bank_valid3;

    //用的是那种巧妙地方法
    assign bank_first_free_onehot0 =
           bank_free0 & (~bank_free0 + 8'd1);
    assign bank_first_free_onehot1 =
           bank_free1 & (~bank_free1 + 8'd1);
    assign bank_first_free_onehot2 =
           bank_free2 & (~bank_free2 + 8'd1);
    assign bank_first_free_onehot3 =
           bank_free3 & (~bank_free3 + 8'd1);

    //分别找到每一个空闲的最低的row，然后还原回32位
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

    genvar dispatch_row_index;//还原回32位的
    generate
        for (dispatch_row_index = 0;
                dispatch_row_index < 8;
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
               dispatch_opcode_0, dispatch_pdest_0,
               dispatch_imm_0, dispatch_rob_id_0
           };
    assign lutram_wdata1 = {
               dispatch_opcode_1, dispatch_pdest_1,
               dispatch_imm_1, dispatch_rob_id_1
           };
    assign lutram_wdata2 = {
               dispatch_opcode_2, dispatch_pdest_2,
               dispatch_imm_2, dispatch_rob_id_2
           };
    assign lutram_wdata3 = {
               dispatch_opcode_3, dispatch_pdest_3,
               dispatch_imm_3, dispatch_rob_id_3
           };

    alu_iq_lutram_16x52 u_bank0_issue (
                            .a    ({1'b0, dispatch_row0}),
                            .d    (lutram_wdata0),
                            .dpra ({1'b0, issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[0]),
                            .dpo  (issue_lutram_data0)
                        );

    alu_iq_lutram_16x52 u_bank0_extra_issue (
                            .a    ({1'b0, dispatch_row0}),
                            .d    (lutram_wdata0),
                            .dpra ({1'b0, extra_issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[0]),
                            .dpo  (extra_issue_lutram_data0)
                        );

    alu_iq_lutram_16x52 u_bank1_issue (
                            .a    ({1'b0, dispatch_row1}),
                            .d    (lutram_wdata1),
                            .dpra ({1'b0, issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[1]),
                            .dpo  (issue_lutram_data1)
                        );

    alu_iq_lutram_16x52 u_bank1_extra_issue (
                            .a    ({1'b0, dispatch_row1}),
                            .d    (lutram_wdata1),
                            .dpra ({1'b0, extra_issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[1]),
                            .dpo  (extra_issue_lutram_data1)
                        );

    alu_iq_lutram_16x52 u_bank2_issue (
                            .a    ({1'b0, dispatch_row2}),
                            .d    (lutram_wdata2),
                            .dpra ({1'b0, issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[2]),
                            .dpo  (issue_lutram_data2)
                        );

    alu_iq_lutram_16x52 u_bank2_extra_issue (
                            .a    ({1'b0, dispatch_row2}),
                            .d    (lutram_wdata2),
                            .dpra ({1'b0, extra_issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[2]),
                            .dpo  (extra_issue_lutram_data2)
                        );

    alu_iq_lutram_16x52 u_bank3_issue (
                            .a    ({1'b0, dispatch_row3}),
                            .d    (lutram_wdata3),
                            .dpra ({1'b0, issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[3]),
                            .dpo  (issue_lutram_data3)
                        );

    alu_iq_lutram_16x52 u_bank3_extra_issue (
                            .a    ({1'b0, dispatch_row3}),
                            .d    (lutram_wdata3),
                            .dpra ({1'b0, extra_issue_row}),
                            .clk  (clk),
                            .we   (dispatch_fire[3]),
                            .dpo  (extra_issue_lutram_data3)
                        );

    genvar i;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_greater
            circle_comparator u_circle_comparator (
                                  .head   (head_bid),
                                  .a      (bid[i]),
                                  .b      (predict_flush_bid),
                                  .a_gt_b (bid_greater[i])
                              );
        end
    endgenerate

    assign popcount32_data = ~bid_greater & valid;

    popcount32 u_popcount32 (
                   .data  (popcount32_data),
                   .count (predict_flush_count)
               );

    //表示存活指令个数，用于预测是否需要flush
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
        end
    endgenerate

    generate
        assign issue_notice[0] = issue_rdy[0];
        assign issue_onehot[0] = issue_rdy[0];
        for (i = 1; i < DEPTH; i = i + 1) begin : gen_issue_notice_and_onehot
            assign issue_notice[i] = issue_rdy[i] || issue_notice[i-1];
            assign issue_onehot[i] = issue_notice[i] && !issue_notice[i-1];
        end

        assign extra_issue_notice[0] = 1'b0;
        assign extra_issue_onehot[0] = 1'b0;
        for (i = 1; i < DEPTH; i = i + 1) begin : gen_extra_issue_notice_and_onehot
            assign extra_issue_notice[i] =
                   (issue_rdy[i] && issue_notice[i-1]) ||
                   extra_issue_notice[i-1];
            assign extra_issue_onehot[i] =
                   extra_issue_notice[i] && !extra_issue_notice[i-1];
        end
    endgenerate

    assign issue_found       = |issue_rdy;
    assign extra_issue_found = |extra_issue_notice;

    assign issue_bank[0] = |(issue_onehot & 32'hAAAA_AAAA);
    assign issue_bank[1] = |(issue_onehot & 32'hCCCC_CCCC);
    assign issue_row[0]  = |(issue_onehot & 32'hF0F0_F0F0);
    assign issue_row[1]  = |(issue_onehot & 32'hFF00_FF00);
    assign issue_row[2]  = |(issue_onehot & 32'hFFFF_0000);

    assign extra_issue_bank[0] =
           |(extra_issue_onehot & 32'hAAAA_AAAA);
    assign extra_issue_bank[1] =
           |(extra_issue_onehot & 32'hCCCC_CCCC);
    assign extra_issue_row[0] =
           |(extra_issue_onehot & 32'hF0F0_F0F0);
    assign extra_issue_row[1] =
           |(extra_issue_onehot & 32'hFF00_FF00);
    assign extra_issue_row[2] =
           |(extra_issue_onehot & 32'hFFFF_0000);

    assign selected_issue_lutram_data =
           (issue_bank == 2'd0) ? issue_lutram_data0 :
           (issue_bank == 2'd1) ? issue_lutram_data1 :
           (issue_bank == 2'd2) ? issue_lutram_data2 :
           issue_lutram_data3;

    assign selected_extra_issue_lutram_data =
           (extra_issue_bank == 2'd0) ? extra_issue_lutram_data0 :
           (extra_issue_bank == 2'd1) ? extra_issue_lutram_data1 :
           (extra_issue_bank == 2'd2) ? extra_issue_lutram_data2 :
           extra_issue_lutram_data3;

    assign {
            selected_issue_opcode,
            selected_issue_pdest,
            selected_issue_imm,
            selected_issue_rob_id
        } = selected_issue_lutram_data;

    assign {
            selected_extra_issue_opcode,
            selected_extra_issue_pdest,
            selected_extra_issue_imm,
            selected_extra_issue_rob_id
        } = selected_extra_issue_lutram_data;

    assign selected_issue_payload = {
               selected_issue_opcode,
               selected_issue_pdest,
               psrc0[{issue_row, issue_bank}],
               psrc1[{issue_row, issue_bank}],
               selected_issue_imm,
               bid[{issue_row, issue_bank}],
               selected_issue_rob_id
           };

    assign selected_extra_issue_payload = {
               selected_extra_issue_opcode,
               selected_extra_issue_pdest,
               psrc0[{extra_issue_row, extra_issue_bank}],
               psrc1[{extra_issue_row, extra_issue_bank}],
               selected_extra_issue_imm,
               bid[{extra_issue_row, extra_issue_bank}],
               selected_extra_issue_rob_id
           };

    // assign sel_issue_payload =
    //     issue_found ? selected_issue_payload
    //                 : {ISSUE_PAYLOAD_WIDTH{1'b0}};
    // assign sel_extra_issue_payload =
    //     extra_issue_found ? selected_extra_issue_payload
    //                       : {ISSUE_PAYLOAD_WIDTH{1'b0}};

    assign {
            sel_issue_opcode,
            sel_issue_pdest,
            sel_issue_psrc0,
            sel_issue_psrc1,
            sel_issue_imm,
            sel_issue_bid,
            sel_issue_rob_id
        } = selected_issue_payload;

    assign {
            sel_extra_issue_opcode,
            sel_extra_issue_pdest,
            sel_extra_issue_psrc0,
            sel_extra_issue_psrc1,
            sel_extra_issue_imm,
            sel_extra_issue_bid,
            sel_extra_issue_rob_id
        } = selected_extra_issue_payload;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_prdy
            assign update_prdy0[i] = prdy0[i] ||
                   (bypass1_valid && (psrc0[i] == bypass1_dst)) ||
                   (bypass2_valid && (psrc0[i] == bypass2_dst)) ||
                   (bypass3_valid && (psrc0[i] == bypass3_dst)) ||
                   (bypass4_valid && (psrc0[i] == bypass4_dst)) ||
                   (bypass5_valid && (psrc0[i] == bypass5_dst)) ||
                   (bypass6_valid && (psrc0[i] == bypass6_dst)) ||
                   (bypass7_valid && (psrc0[i] == bypass7_dst)) ||
                   (issue_fire && (psrc0[i] == issue_pdest)) ||
                   (extra_issue_fire &&(psrc0[i] == extra_issue_pdest));

            assign update_prdy1[i] = prdy1[i] ||
                   (bypass1_valid && (psrc1[i] == bypass1_dst)) ||
                   (bypass2_valid && (psrc1[i] == bypass2_dst)) ||
                   (bypass3_valid && (psrc1[i] == bypass3_dst)) ||
                   (bypass4_valid && (psrc1[i] == bypass4_dst)) ||
                   (bypass5_valid && (psrc1[i] == bypass5_dst)) ||
                   (bypass6_valid && (psrc1[i] == bypass6_dst)) ||
                   (bypass7_valid && (psrc1[i] == bypass7_dst)) ||
                   (issue_fire && (psrc1[i] == issue_pdest)) ||
                   (extra_issue_fire &&(psrc1[i] == extra_issue_pdest));
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
                    (issue_onehot[i] && issue_fire) ||
                    (extra_issue_onehot[i] && extra_issue_fire)
                ) begin
                    valid[i] <= 1'b0;
                end
            end

            if ((i % 4) == 0) begin : gen_dispatch_metadata_lane0
                always @(posedge clk) begin
                    if (dispatch_onehot[i] && dispatch_fire[0]) begin
                        psrc0[i] <= dispatch_psrc0_0;
                        prdy0[i] <= dispatch_prdy0[0];
                        psrc1[i] <= dispatch_psrc1_0;
                        prdy1[i] <= dispatch_prdy1[0];
                        bid[i]   <= dispatch_bid_0;
                    end
                    else begin
                        prdy0[i] <= update_prdy0[i];
                        prdy1[i] <= update_prdy1[i];
                    end
                end
            end
            else if ((i % 4) == 1) begin : gen_dispatch_metadata_lane1
                always @(posedge clk) begin
                    if (dispatch_onehot[i] && dispatch_fire[1]) begin
                        psrc0[i] <= dispatch_psrc0_1;
                        prdy0[i] <= dispatch_prdy0[1];
                        psrc1[i] <= dispatch_psrc1_1;
                        prdy1[i] <= dispatch_prdy1[1];
                        bid[i]   <= dispatch_bid_1;
                    end
                    else begin
                        prdy0[i] <= update_prdy0[i];
                        prdy1[i] <= update_prdy1[i];
                    end
                end
            end
            else if ((i % 4) == 2) begin : gen_dispatch_metadata_lane2
                always @(posedge clk) begin
                    if (dispatch_onehot[i] && dispatch_fire[2]) begin
                        psrc0[i] <= dispatch_psrc0_2;
                        prdy0[i] <= dispatch_prdy0[2];
                        psrc1[i] <= dispatch_psrc1_2;
                        prdy1[i] <= dispatch_prdy1[2];
                        bid[i]   <= dispatch_bid_2;
                    end
                    else begin
                        prdy0[i] <= update_prdy0[i];
                        prdy1[i] <= update_prdy1[i];
                    end
                end
            end
            else begin : gen_dispatch_metadata_lane3
                always @(posedge clk) begin
                    if (dispatch_onehot[i] && dispatch_fire[3]) begin
                        psrc0[i] <= dispatch_psrc0_3;
                        prdy0[i] <= dispatch_prdy0[3];
                        psrc1[i] <= dispatch_psrc1_3;
                        prdy1[i] <= dispatch_prdy1[3];
                        bid[i]   <= dispatch_bid_3;
                    end
                    else begin
                        prdy0[i] <= update_prdy0[i];
                        prdy1[i] <= update_prdy1[i];
                    end
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn || flush) begin
            bank_count0 <= 4'd0;
        end
        else if (predict_flush) begin
            bank_count0 <= bank_predict_count0;
        end
        else begin
            bank_count0 <= bank_count0
                        + {3'b0, dispatch_fire[0]}
                        - {3'b0, (issue_fire && (issue_bank == 2'd0))}
                        - {3'b0, (extra_issue_fire &&
                                  (extra_issue_bank == 2'd0))};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            bank_count1 <= 4'd0;
        end
        else if (predict_flush) begin
            bank_count1 <= bank_predict_count1;
        end
        else begin
            bank_count1 <= bank_count1
                        + {3'b0, dispatch_fire[1]}
                        - {3'b0, (issue_fire && (issue_bank == 2'd1))}
                        - {3'b0, (extra_issue_fire &&
                                  (extra_issue_bank == 2'd1))};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            bank_count2 <= 4'd0;
        end
        else if (predict_flush) begin
            bank_count2 <= bank_predict_count2;
        end
        else begin
            bank_count2 <= bank_count2
                        + {3'b0, dispatch_fire[2]}
                        - {3'b0, (issue_fire && (issue_bank == 2'd2))}
                        - {3'b0, (extra_issue_fire &&
                                  (extra_issue_bank == 2'd2))};
        end
    end

    always @(posedge clk) begin
        if (!resetn || flush) begin
            bank_count3 <= 4'd0;
        end
        else if (predict_flush) begin
            bank_count3 <= bank_predict_count3;
        end
        else begin
            bank_count3 <= bank_count3
                        + {3'b0, dispatch_fire[3]}
                        - {3'b0, (issue_fire && (issue_bank == 2'd3))}
                        - {3'b0, (extra_issue_fire &&
                                  (extra_issue_bank == 2'd3))};
        end
    end

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
                  - {{(COUNT_WIDTH-1){1'b0}}, issue_fire}
                  - {{(COUNT_WIDTH-1){1'b0}}, extra_issue_fire};
        end
    end

endmodule
