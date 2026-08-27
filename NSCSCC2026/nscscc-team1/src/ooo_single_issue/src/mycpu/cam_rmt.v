`include "header.v"

module cam_rmt (
        input wire clk,
        input wire resetn,

        input wire [4:0] arch_reg_src1,
        input wire [4:0] arch_reg_src2,
        input wire [4:0] arch_reg_dst,
        input wire       rename_arch_reg_dst_valid,
        input wire       valid_copy_valid,
        input wire [4:0] valid_copy_bid,

        output wire [6:0] phy_reg_src1,
        output wire       phy_reg_src1_rdy,
        output wire [6:0] phy_reg_src2,
        output wire       phy_reg_src2_rdy,
        output wire [6:0] old_phy_reg_dst,
        output wire [6:0] new_phy_reg_dst,
        output wire       rename_success,

        input wire [6:0] update_writeback1_reg_dst,
        input wire       update_writeback1_valid,

        input wire [6:0] update_writeback2_reg_dst,
        input wire       update_writeback2_valid,

        input wire [6:0] update_writeback3_reg_dst,
        input wire       update_writeback3_valid,

        input wire [6:0] update_writeback4_reg_dst,
        input wire       update_writeback4_valid,

        input wire [6:0] update_writeback5_reg_dst,
        input wire       update_writeback5_valid,

        input wire [6:0] update_writeback6_reg_dst,
        input wire       update_writeback6_valid,

        input wire [6:0] update_writeback7_reg_dst,
        input wire       update_writeback7_valid,

        input wire [6:0] update_commit_new_reg_dst,
        input wire [6:0] update_commit_old_reg_dst,
        input wire       update_commit_valid,

        input wire flush,


        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid

`ifdef difftest

        ,  output wire [6:0] armt [31:0]

`endif
    );

    genvar i;

    reg  [ 4:0] rmt              [63:0];
    reg  [ 1:0] state            [63:0];
    reg  [63:0] valid;

    reg  [ 4:0] bid              [63:0];


    reg  [63:0] valid_copy       [31:0];
    reg         valid_copy_p;
    reg  [ 4:0] valid_copy_bid_p;

    wire        do_rename;

    wire [63:0] greater_bid;

    generate
        for (i = 1; i < 64; i = i + 1) begin : gen_greater_bid
            circle_comparator u_circle_comparator (
                                  .head  (head_bid),
                                  .a     (bid[i]),
                                  .b     (predict_flush_bid),
                                  .a_gt_b(greater_bid[i])
                              );
        end
    endgenerate


    assign do_rename = rename_success && (arch_reg_dst != 5'd0);


    always @(posedge clk) begin
        if (!resetn || flush)
            valid_copy_p <= 1'b0;
        else
            valid_copy_p <= valid_copy_valid;
    end

    always @(posedge clk) begin
        valid_copy_bid_p <= valid_copy_bid;
    end

    always @(posedge clk) begin
        if (valid_copy_p)
            valid_copy[valid_copy_bid_p] <= valid;
    end

    always @(posedge clk) begin
        if (do_rename)
            bid[new_phy_reg_dst] <= valid_copy_bid;
    end



    always @(posedge clk) begin
        if (!resetn) begin
            state[0] <= `RMT_STATE_COMMIT;
            valid[0] <= 1'b1;
        end
    end

    wire [3:0] next_state[63:1];


    generate
        for (i = 1; i < 64; i = i + 1) begin : gen_next_state
            assign next_state[i][3] = update_commit_new_reg_dst == i && update_commit_valid;
            assign next_state[i][2] = update_writeback1_reg_dst == i && update_writeback1_valid ||
                   update_writeback2_reg_dst == i && update_writeback2_valid ||
                   update_writeback3_reg_dst == i && update_writeback3_valid ||
                   update_writeback4_reg_dst == i && update_writeback4_valid ||
                   update_writeback5_reg_dst == i && update_writeback5_valid ||
                   update_writeback6_reg_dst == i && update_writeback6_valid ||
                   update_writeback7_reg_dst == i && update_writeback7_valid ;
            assign next_state[i][1] = new_phy_reg_dst == i && do_rename;
            assign next_state[i][0] = update_commit_old_reg_dst == i && update_commit_valid;
        end
    endgenerate


    generate
        for (i = 1; i < 64; i = i + 1) begin : gen_valid
            always @(posedge clk) begin
                if (!resetn)
                    valid[i] <= 1'b0;
                else if (flush)
                    valid[i] <= state[i] == `RMT_STATE_COMMIT;
                else if (predict_flush)
                    valid[i] <= valid_copy[predict_flush_bid][i];
                else if (do_rename && new_phy_reg_dst == i)
                    valid[i] <= 1'b1;
                else if (do_rename && old_phy_reg_dst == i)
                    valid[i] <= 1'b0;
            end
        end
    endgenerate





    generate
        for (i = 1; i < 64; i = i + 1) begin : gen_state
            always @(posedge clk) begin
                if (!resetn)
                    state[i] <= `RMT_STATE_EMPTY;
                else if (flush)
                    state[i] <= (state[i] == `RMT_STATE_COMMIT) ? `RMT_STATE_COMMIT : `RMT_STATE_EMPTY;
                else if (predict_flush && !(state[i] == `RMT_STATE_COMMIT) && greater_bid[i]) begin
                    state[i] <= `RMT_STATE_EMPTY;
                end
                else if (next_state[i]) begin
                    state[i] <= {2{next_state[i][3]}} & `RMT_STATE_COMMIT |
                         {2{next_state[i][2]}} & `RMT_STATE_WRITEBACK |
                         {2{next_state[i][1]}} & `RMT_STATE_MAPPED |
                         {2{next_state[i][0]}} & `RMT_STATE_EMPTY ;

                end
            end
        end
    endgenerate





    wire [63:0] match_arch_reg_src1;
    wire [63:0] match_arch_reg_src2;
    wire [63:0] match_arch_reg_dst;
    wire [63:0] phy_reg_rdy;
    wire [63:0] free_phy;
    wire [63:0] free_phy_masked;
    wire [63:0] free_phy_onehot;


    wire [ 6:0] match_src1_idx_or;
    wire [ 6:0] match_src2_idx_or;
    wire [ 6:0] match_dst_idx_or;
    wire [ 6:0] free_idx_or;

    wire [63:0] match_src1_idx_and [6:0];
    wire [63:0] match_src2_idx_and [6:0];
    wire [63:0] match_dst_idx_and  [6:0];
    wire [63:0] free_idx_and       [6:0];

    wire        matched_arch_reg_src1;
    wire        matched_arch_reg_src2;
    wire        matched_arch_reg_dst;
    wire        has_free_phy;

    wire        m_phy_reg_src1_rdy;
    wire        m_phy_reg_src2_rdy;

    genvar phy;
    genvar bit_idx;
    generate
        for (phy = 0; phy < 64; phy = phy + 1) begin : gen_cam_entry
            assign match_arch_reg_src1[phy] = (rmt[phy] == arch_reg_src1) && valid[phy];
            assign match_arch_reg_src2[phy] = (rmt[phy] == arch_reg_src2) && valid[phy];
            assign match_arch_reg_dst[phy] = (rmt[phy] == arch_reg_dst) && valid[phy];
            assign phy_reg_rdy[phy]         = (state[phy] == `RMT_STATE_WRITEBACK) || (state[phy] == `RMT_STATE_COMMIT);

            if (phy == 0) begin : gen_first_free_mask
                assign free_phy[phy]        = arch_reg_dst == 5'd0;
                assign free_phy_masked[phy] = arch_reg_dst == 5'd0;
                assign free_phy_onehot[phy] = arch_reg_dst == 5'd0;
            end
            else begin : gen_other_free_mask
                assign free_phy[phy]        = (state[phy] == `RMT_STATE_EMPTY);
                assign free_phy_masked[phy] = |free_phy[phy-1:0];
                assign free_phy_onehot[phy] = free_phy[phy] && !free_phy_masked[phy];
            end
        end

        for (bit_idx = 0; bit_idx < 7; bit_idx = bit_idx + 1) begin : gen_idx_or_bit
            for (phy = 0; phy < 64; phy = phy + 1) begin : gen_idx_and_phy
                assign match_src1_idx_and[bit_idx][phy] = match_arch_reg_src1[phy] & phy[bit_idx];
                assign match_src2_idx_and[bit_idx][phy] = match_arch_reg_src2[phy] & phy[bit_idx];
                assign match_dst_idx_and[bit_idx][phy]  = match_arch_reg_dst[phy] & phy[bit_idx];
                assign free_idx_and[bit_idx][phy]       = free_phy_onehot[phy] & phy[bit_idx];
            end

            assign match_src1_idx_or[bit_idx] = |match_src1_idx_and[bit_idx];
            assign match_src2_idx_or[bit_idx] = |match_src2_idx_and[bit_idx];
            assign match_dst_idx_or[bit_idx]  = |match_dst_idx_and[bit_idx];
            assign free_idx_or[bit_idx]       = |free_idx_and[bit_idx];
        end

    endgenerate

    always @(posedge clk) begin
        if (!resetn)
            rmt[0] <= 5'd0;
    end

    generate
        for (i = 1; i < 64; i = i + 1) begin
            always @(posedge clk) begin
                if (do_rename && free_phy_onehot[i])
                    rmt[i] <= arch_reg_dst;
            end
        end
    endgenerate


    assign matched_arch_reg_src1 = |match_arch_reg_src1;
    assign matched_arch_reg_src2 = |match_arch_reg_src2;
    assign matched_arch_reg_dst = |match_arch_reg_dst;
    assign has_free_phy = |free_phy;

    assign phy_reg_src1 = match_src1_idx_or;
    assign phy_reg_src2 = match_src2_idx_or;
    assign old_phy_reg_dst = match_dst_idx_or;
    assign new_phy_reg_dst = free_idx_or;

    assign m_phy_reg_src1_rdy = |(match_arch_reg_src1 & phy_reg_rdy);
    assign m_phy_reg_src2_rdy = |(match_arch_reg_src2 & phy_reg_rdy);
    assign phy_reg_src1_rdy = matched_arch_reg_src1 ? m_phy_reg_src1_rdy : 1'b1;
    assign phy_reg_src2_rdy = matched_arch_reg_src2 ? m_phy_reg_src2_rdy : 1'b1;
    assign rename_success = rename_arch_reg_dst_valid && ((arch_reg_dst == 5'd0) || has_free_phy);

`ifdef difftest


    reg [6:0] commit_rmt [31:0];

    integer k;

    always @(*) begin
        // 默认映射
        for (k = 0; k < 32; k = k + 1)
            commit_rmt[k] =0;



        // 查找所有 COMMIT 状态的物理寄存器
        for (k = 1; k < 64; k = k + 1) begin
            if (state[k] == `RMT_STATE_COMMIT)
                commit_rmt[rmt[k]] = k;
        end
    end

    assign armt =  commit_rmt;
`endif



endmodule
