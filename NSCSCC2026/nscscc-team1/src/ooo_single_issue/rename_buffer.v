module rename_buffer (
    input wire clk,
    input wire resetn,

    input  wire stall,
    output reg  sel,

    input wire       update_rename_success,
    input wire [6:0] update_old_phy_reg_dst,
    input wire [6:0] update_new_phy_reg_dst,
    input wire [6:0] update_phy_reg_src1,
    input wire       update_phy_reg_src1_rdy,
    input wire [6:0] update_phy_reg_src2,
    input wire       update_phy_reg_src2_rdy,


    output reg        result_rename_success,
    output reg  [6:0] result_old_phy_reg_dst,
    output reg  [6:0] result_new_phy_reg_dst,
    output reg  [6:0] result_phy_reg_src1,
    output wire       result_phy_reg_src1_rdy,
    output reg  [6:0] result_phy_reg_src2,
    output wire       result_phy_reg_src2_rdy,

    input wire       bypass1_valid,
    input wire [6:0] bypass1_dst,
    input wire       bypass2_valid,
    input wire [6:0] bypass2_dst,
    input wire       bypass3_valid,
    input wire [6:0] bypass3_dst,
    input wire       bypass4_valid,
    input wire [6:0] bypass4_dst,
    input wire       bypass5_valid,
    input wire [6:0] bypass5_dst,
    input wire       bypass6_valid,
    input wire [6:0] bypass6_dst,
    input wire       bypass7_valid,
    input wire [6:0] bypass7_dst

);

    reg rdy1, rdy2;

    always @(posedge clk) begin
        if (!resetn) begin
            sel <= 1'b0;

        end else if (stall) begin
            sel <= 1'b1;
            if (sel == 1'b0) begin
                rdy1                <= update_phy_reg_src1_rdy;
                rdy2                <= update_phy_reg_src2_rdy;
                result_phy_reg_src1 <= update_phy_reg_src1;
                result_phy_reg_src2 <= update_phy_reg_src2;
            end else begin
                rdy1 <= result_phy_reg_src1_rdy;
                rdy2 <= result_phy_reg_src2_rdy;
            end
            result_rename_success <= update_rename_success || result_rename_success;
            if (update_rename_success) begin
                result_old_phy_reg_dst <= update_old_phy_reg_dst;
                result_new_phy_reg_dst <= update_new_phy_reg_dst;
            end
        end else begin
            sel                   <= 1'b0;
            result_rename_success <= 1'b0;
        end
    end

    assign result_phy_reg_src1_rdy = rdy1 || 
                                    (bypass1_valid && sel && result_phy_reg_src1 == bypass1_dst) || 
                                    (bypass2_valid && sel && result_phy_reg_src1 == bypass2_dst) ||
                                    (bypass3_valid && sel && result_phy_reg_src1 == bypass3_dst) || 
                                    (bypass4_valid && sel && result_phy_reg_src1 == bypass4_dst) || 
                                    (bypass5_valid && sel && result_phy_reg_src1 == bypass5_dst) || 
                                    (bypass6_valid && sel && result_phy_reg_src1 == bypass6_dst) || 
                                    (bypass7_valid && sel && result_phy_reg_src1 == bypass7_dst)    ;
    assign result_phy_reg_src2_rdy = rdy2 || 
                                    (bypass1_valid && sel && result_phy_reg_src2 == bypass1_dst) || 
                                    (bypass2_valid && sel && result_phy_reg_src2 == bypass2_dst) ||
                                    (bypass3_valid && sel && result_phy_reg_src2 == bypass3_dst) || 
                                    (bypass4_valid && sel && result_phy_reg_src2 == bypass4_dst) || 
                                    (bypass5_valid && sel && result_phy_reg_src2 == bypass5_dst) || 
                                    (bypass6_valid && sel && result_phy_reg_src2 == bypass6_dst) || 
                                    (bypass7_valid && sel && result_phy_reg_src2 == bypass7_dst)  ;

endmodule
