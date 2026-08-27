module id_allocbid_reg (
        input wire clk,
        input wire resetn,

        input wire stall,
        input wire pre_stall,

        input wire        in_valid,
        input wire [31:0] in_pc,
        input wire [31:0] in_instruction,
        input wire [ 4:0] in_regfile_raddr1,
        input wire [ 4:0] in_regfile_raddr2,
        input wire        in_regfile_we,
        input wire [ 4:0] in_regfile_waddr,
        input wire [ 1:0] in_sel_npc,
        input wire [ 4:0] in_alu_op,
        input wire [ 2:0] in_comparator_op,
        input wire [ 2:0] in_sel_issue_queue,
        input wire        in_sel_imm,
        input wire [31:0] in_extended_imm,
        input wire [31:0] in_target_b,
        input wire [ 6:0] in_md_op,
        input wire [ 2:0] in_sel_load_store_len,
        input wire [31:0] in_predict_target_address,
        input wire in_is_b_jump,

        output reg        out_valid,
        output reg [31:0] out_pc,
        output reg [31:0] out_instruction,
        output reg [ 4:0] out_regfile_raddr1,
        output reg [ 4:0] out_regfile_raddr2,
        output reg        out_regfile_we,
        output reg [ 4:0] out_regfile_waddr,
        output reg [ 1:0] out_sel_npc,
        output reg [ 4:0] out_alu_op,
        output reg [ 2:0] out_comparator_op,
        output reg [ 2:0] out_sel_issue_queue,
        output reg        out_sel_imm,
        output reg [31:0] out_extended_imm,
        output reg [31:0] out_target_b,
        output reg [ 6:0] out_md_op,
        output reg [ 2:0] out_sel_load_store_len,
        output reg [31:0] out_predict_target_address,
        output reg out_is_b_jump

    );
    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 1'b0;
        end
        else if (!stall) begin
            out_valid              <= in_valid & !pre_stall;
            out_pc                 <= in_pc;
            out_instruction        <= in_instruction;
            out_regfile_raddr1     <= in_regfile_raddr1;
            out_regfile_raddr2     <= in_regfile_raddr2;
            out_regfile_we         <= in_regfile_we;
            out_regfile_waddr      <= in_regfile_waddr;
            out_sel_npc            <= in_sel_npc;
            out_alu_op             <= in_alu_op;
            out_comparator_op      <= in_comparator_op;
            out_sel_issue_queue    <= in_sel_issue_queue;
            out_sel_imm            <= in_sel_imm;
            out_extended_imm       <= in_extended_imm;
            out_target_b           <= in_target_b;
            out_md_op              <= in_md_op;
            out_sel_load_store_len <= in_sel_load_store_len;
            out_predict_target_address <= in_predict_target_address;
            out_is_b_jump <= in_is_b_jump;
        end
    end

endmodule
