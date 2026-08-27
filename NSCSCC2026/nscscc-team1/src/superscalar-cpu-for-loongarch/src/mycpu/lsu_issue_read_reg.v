`include "header.v"
module lsu_issue_read_reg (
        input wire clk,
        input wire resetn,

        input wire stall,
        input wire pre_stall,

        input wire                       in_valid,
        input wire [                6:0] in_phy_reg_src1,
        input wire [                6:0] in_phy_reg_src2,
        input wire [                6:0] in_phy_reg_dst,
        input wire [               31:0] in_extended_imm,
        input wire                       in_is_store_or_not_load,
        input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
        input wire [                2:0] in_sel_load_store_len,
        input wire [                4:0] in_bid,

        input wire in_is_cacop,
        input wire in_is_ll_w,
        input wire in_is_sc_w,
        input wire in_is_dbar,

        output reg                       out_valid,
        output reg [                6:0] out_phy_reg_src1,
        output reg [                6:0] out_phy_reg_src2,
        output reg [                6:0] out_phy_reg_dst,
        output reg [               31:0] out_extended_imm,
        output reg                       out_is_store_or_not_load,
        output reg [`ROB_ID_WIDTH-1 : 0] out_rob_id,
        output reg [                2:0] out_sel_load_store_len,
        output reg [                4:0] out_bid,

        output reg out_is_cacop,

        output reg out_is_ll_w,
        output reg out_is_sc_w,
        output reg out_is_dbar
    );

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 1'b0;
        end
        else if (!stall) begin
            out_valid                <= in_valid && !pre_stall;
            out_phy_reg_src1         <= in_phy_reg_src1;
            out_phy_reg_src2         <= in_phy_reg_src2;
            out_phy_reg_dst          <= in_phy_reg_dst;
            out_extended_imm         <= in_extended_imm;
            out_is_store_or_not_load <= in_is_store_or_not_load;
            out_rob_id               <= in_rob_id;
            out_sel_load_store_len   <= in_sel_load_store_len;
            out_bid                  <= in_bid;
            out_is_cacop             <= in_is_cacop;
            out_is_ll_w <= in_is_ll_w;
            out_is_sc_w <= in_is_sc_w;
            out_is_dbar <= in_is_dbar;
        end
    end



endmodule
