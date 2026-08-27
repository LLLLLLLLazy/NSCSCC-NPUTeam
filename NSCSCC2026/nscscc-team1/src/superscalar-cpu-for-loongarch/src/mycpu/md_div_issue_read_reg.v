`include "header.v"

module md_div_issue_read_reg (
    input wire clk,
    input wire resetn,

    input wire stall,
    input wire pre_stall,

    input wire                       in_valid,
    input wire [                6:0] in_phy_reg_src1,
    input wire [                6:0] in_phy_reg_src2,
    input wire [                6:0] in_phy_reg_dst,
    input wire [                3:0] in_div_op,
    input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
    input wire [                4:0] in_bid,

    output reg                       out_valid,
    output reg [                6:0] out_phy_reg_src1,
    output reg [                6:0] out_phy_reg_src2,
    output reg [                6:0] out_phy_reg_dst,
    output reg [                3:0] out_div_op,
    output reg [`ROB_ID_WIDTH-1 : 0] out_rob_id,
    output reg [                4:0] out_bid
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 1'b0;
        end else if (!stall) begin
            out_valid        <= in_valid && !pre_stall;
            out_phy_reg_src1 <= in_phy_reg_src1;
            out_phy_reg_src2 <= in_phy_reg_src2;
            out_phy_reg_dst  <= in_phy_reg_dst;
            out_div_op       <= in_div_op;
            out_rob_id       <= in_rob_id;
            out_bid          <= in_bid;
        end
    end



endmodule
