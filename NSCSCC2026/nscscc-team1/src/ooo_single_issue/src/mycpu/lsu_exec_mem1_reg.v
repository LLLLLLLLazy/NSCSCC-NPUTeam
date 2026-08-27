`include "header.v"

module lsu_exec_mem1_reg (
        input wire clk,
        input wire resetn,

        input wire stall,
        input wire pre_stall,

        input wire                       in_valid,
        input wire [                6:0] in_phy_reg_dst,
        input wire                       in_is_store_or_not_load,
        input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
        input wire [                2:0] in_sel_load_store_len,
        input wire [                3:0] in_wstrb,
        input wire [               31:0] in_address,
        input wire [               31:0] in_store_data,
        input wire [                4:0] in_bid,
        input wire                       in_store_ctrl,
        input wire [               31:0] in_address_pa,
        input wire                       in_is_cacop,
        input wire in_is_ll_w,
        input wire in_is_sc_w,
        input wire in_is_dbar,

        output reg                       out_valid,
        output reg [                6:0] out_phy_reg_dst,
        output reg                       out_is_store_or_not_load,
        output reg [`ROB_ID_WIDTH-1 : 0] out_rob_id,
        output reg [                2:0] out_sel_load_store_len,
        output reg [                3:0] out_wstrb,
        output reg [               31:0] out_address,
        output reg [               31:0] out_store_data,
        output reg [                4:0] out_bid,
        output reg                       out_store_ctrl,
        output reg [               31:0] out_address_pa,

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
            out_phy_reg_dst          <= in_phy_reg_dst;
            out_is_store_or_not_load <= in_is_store_or_not_load;
            out_rob_id               <= in_rob_id;
            out_sel_load_store_len   <= in_sel_load_store_len;
            out_wstrb                <= in_wstrb;
            out_address              <= in_address;
            out_store_data           <= in_store_data;
            out_bid                  <= in_bid;
            out_store_ctrl           <= in_store_ctrl;
            out_address_pa           <= in_address_pa;
            out_is_cacop             <= in_is_cacop;
            out_is_ll_w <= in_is_ll_w;
            out_is_sc_w <= in_is_sc_w;
            out_is_dbar <= in_is_dbar;
        end
    end



endmodule
