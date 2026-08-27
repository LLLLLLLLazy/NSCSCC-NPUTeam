`include "header.v"


module issue_read_reg (
    input wire clk,
    input wire resetn,

    input wire stall,
    input wire pre_stall,

    input wire                       in_valid,
    input wire [                6:0] in_phy_reg_src1,
    input wire [                6:0] in_phy_reg_src2,
    input wire [                6:0] in_phy_reg_dst,
    input wire                       in_regfile_we,
    input wire [                4:0] in_alu_op,
    input wire                       in_sel_imm,
    input wire [               31:0] in_extended_imm,
    input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
    input wire [                4:0] in_bid,

    output reg                       out_valid,
    output reg [                6:0] out_phy_reg_src1,
    output reg [                6:0] out_phy_reg_src2,
    output reg [                6:0] out_phy_reg_dst,
    output reg                       out_regfile_we,
    output reg [                4:0] out_alu_op,
    output reg                       out_sel_imm,
    output reg [               31:0] out_extended_imm,
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
            out_regfile_we   <= in_regfile_we;
            out_alu_op       <= in_alu_op;
            out_sel_imm      <= in_sel_imm;
            out_extended_imm <= in_extended_imm;
            out_rob_id       <= in_rob_id;
            out_bid          <= in_bid;
        end
    end



endmodule
