`include "header.v"

module md_bru_writeback_reg (
        input wire clk,
        input wire resetn,

        input wire stall,
        input wire pre_stall,

        input wire                       in_valid,
        input wire [31:0] in_pc,
        input wire [                1:0] in_sel_npc,
        input wire                       in_regfile_we,
        input wire [               31:0] in_result,
        input wire [               31:0] in_target_address,
        input wire                       in_is_jump,
        input wire [                6:0] in_phy_reg_dst,
        input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
        input wire [                4:0] in_bid,
        input wire                       in_compared_result,

        output reg                       out_valid,
        output reg [31:0] out_pc,
        output reg [                1:0] out_sel_npc,
        output reg                       out_regfile_we,
        output reg [               31:0] out_result,
        output reg [               31:0] out_target_address,
        output reg                       out_is_jump,
        output reg [                6:0] out_phy_reg_dst,
        output reg [`ROB_ID_WIDTH-1 : 0] out_rob_id,
        output reg [                4:0] out_bid,
        output reg                       out_compared_result
    );

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 1'b0;
        end
        else if (!stall) begin
            out_valid          <= in_valid && !pre_stall;
            out_pc <=in_pc;
            out_sel_npc <= in_sel_npc;
            out_regfile_we     <= in_regfile_we;
            out_result         <= in_result;
            out_target_address <= in_target_address;
            out_is_jump        <= in_is_jump;
            out_phy_reg_dst    <= in_phy_reg_dst;
            out_rob_id         <= in_rob_id;
            out_bid            <= in_bid;
            out_compared_result <= in_compared_result;
        end
    end



endmodule
