module if1_if2_reg (
    input clk,
    input resetn,

    input in_valid,
    input stall,
    input pre_stall,


    input [31:0] in_pc,
    input [31:0] in_pc_offset,
    input [31:0] in_pc_pa,

    output reg out_valid,

    output reg [31:0] out_pc,
    output reg [31:0] out_pc_offset,
    output reg [31:0] out_pc_pa
);


    always @(posedge clk) begin
        if (!resetn) begin
            out_valid     <= 1'b0;
            out_pc        <= 32'b0;
            out_pc_offset <= 32'b0;
            out_pc_pa     <= 32'b0;
        end else if (!stall) begin
            out_valid     <= in_valid && !pre_stall;
            out_pc        <= in_pc;
            out_pc_offset <= in_pc_offset;
            out_pc_pa     <= in_pc_pa;
        end

    end



endmodule


module if2_id_reg (
    input clk,
    input resetn,

    input stall,
    input pre_stall,

    input      in_valid,
    output reg out_valid,

    input [31:0] in_pc,
    input [31:0] in_instruction,
    input [31:0] in_pc_offset,

    output reg [31:0] out_pc,
    output reg [31:0] out_instruction,
    output reg [31:0] out_pc_offset
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid       <= 1'b0;
            out_pc          <= 32'b0;
            out_instruction <= 32'b0;
            out_pc_offset   <= 32'b0;
        end else if (!stall) begin
            out_valid       <= in_valid && !pre_stall;
            out_pc          <= in_pc;
            out_instruction <= in_instruction;
            out_pc_offset   <= in_pc_offset;
        end
    end



endmodule



module id_exe_reg (
    input clk,
    input resetn,

    input stall,
    input pre_stall,


    input      in_valid,
    output reg out_valid,

    input [ 4:0] in_regfile_raddr1,
    input [ 4:0] in_regfile_raddr2,
    input [ 4:0] in_regfile_waddr,
    input        in_regfile_we,
    input [ 4:0] in_alu_op,
    input [ 1:0] in_sel_regfile_wdata,
    input        in_sel_imm,
    input [31:0] in_ext_extended_imm,
    input [31:0] in_regfile_rdata1,
    input [31:0] in_regfile_rdata2,
    input [31:0] in_pc,
    input [31:0] in_result,
    input        in_sel_pc,
    input [ 2:0] in_sel_load_store_len,
    input [ 2:0] in_comparator_op,
    input [ 1:0] in_npc_selector_op,
    input [31:0] in_next_pc,
    input [31:0] in_pc_offset,
    input        in_is_load,
    input        in_is_store,
    input        in_tlb_change,

    input in_comparator_compared_result,

    input        in_is_cacop,
    input [31:0] in_instruction,

    input in_is_inst_ll_w,
    input in_is_inst_sc_w,

    input        in_actual_taken,
    input [31:0] in_actual_target,


    output reg [ 4:0] out_regfile_raddr1,
    output reg [ 4:0] out_regfile_raddr2,
    output reg [ 4:0] out_regfile_waddr,
    output reg        out_regfile_we,
    output reg [ 4:0] out_alu_op,
    output reg [ 1:0] out_sel_regfile_wdata,
    output reg        out_sel_imm,
    output reg [31:0] out_ext_extended_imm,
    output reg [31:0] out_regfile_rdata1,
    output reg [31:0] out_regfile_rdata2,
    output reg [31:0] out_pc,
    output reg [31:0] out_result,
    output reg        out_sel_pc,
    output reg [ 2:0] out_sel_load_store_len,
    output reg [ 2:0] out_comparator_op,
    output reg [ 1:0] out_npc_selector_op,
    output reg [31:0] out_next_pc,
    output reg [31:0] out_pc_offset,
    output reg        out_is_load,
    output reg        out_is_store,
    output reg        out_tlb_change,

    output reg out_comparator_compared_result,

    output reg        out_is_cacop,
    output reg [31:0] out_instruction,

    output reg out_is_inst_ll_w,
    output reg out_is_inst_sc_w,

    output reg        out_actual_taken,
    output reg [31:0] out_actual_target
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid                      <= 1'b0;
            out_regfile_raddr1             <= 5'd0;
            out_regfile_raddr2             <= 5'd0;
            out_regfile_waddr              <= 5'd0;
            out_regfile_we                 <= 1'b0;
            out_alu_op                     <= 5'd0;
            out_sel_regfile_wdata          <= 2'd0;
            out_sel_imm                    <= 1'b0;
            out_ext_extended_imm           <= 32'd0;
            out_regfile_rdata1             <= 32'd0;
            out_regfile_rdata2             <= 32'd0;
            out_pc                         <= 32'd0;
            out_result                     <= 32'd0;
            out_sel_pc                     <= 1'b0;
            out_sel_load_store_len         <= 3'd0;
            out_comparator_op              <= 3'd0;
            out_npc_selector_op            <= 3'd0;
            out_next_pc                    <= 32'b0;
            out_pc_offset                  <= 32'b0;
            out_is_load                    <= 1'b0;
            out_is_store                   <= 1'b0;
            out_tlb_change                 <= 1'b0;
            out_comparator_compared_result <= 1'b0;
            out_is_cacop                   <= 1'b0;
            out_instruction                <= 32'b0;
            out_is_inst_ll_w               <= 1'b0;
            out_is_inst_sc_w               <= 1'b0;
            out_actual_taken               <= 1'b0;
            out_actual_target              <= 32'b0;
        end else if (!stall) begin
            out_valid                      <= in_valid && !pre_stall;
            out_regfile_raddr1             <= in_regfile_raddr1;
            out_regfile_raddr2             <= in_regfile_raddr2;
            out_regfile_waddr              <= in_regfile_waddr;
            out_regfile_we                 <= in_regfile_we;
            out_alu_op                     <= in_alu_op;
            out_sel_regfile_wdata          <= in_sel_regfile_wdata;
            out_sel_imm                    <= in_sel_imm;
            out_ext_extended_imm           <= in_ext_extended_imm;
            out_regfile_rdata1             <= in_regfile_rdata1;
            out_regfile_rdata2             <= in_regfile_rdata2;
            out_pc                         <= in_pc;
            out_result                     <= in_result;
            out_sel_pc                     <= in_sel_pc;
            out_sel_load_store_len         <= in_sel_load_store_len;
            out_comparator_op              <= in_comparator_op;
            out_npc_selector_op            <= in_npc_selector_op;
            out_next_pc                    <= in_next_pc;
            out_pc_offset                  <= in_pc_offset;
            out_is_load                    <= in_is_load;
            out_is_store                   <= in_is_store;
            out_tlb_change                 <= in_tlb_change;
            out_comparator_compared_result <= in_comparator_compared_result;
            out_is_cacop                   <= in_is_cacop;
            out_instruction                <= in_instruction;
            out_is_inst_ll_w               <= in_is_inst_ll_w;
            out_is_inst_sc_w               <= in_is_inst_sc_w;
            out_actual_taken               <= in_actual_taken;
            out_actual_target              <= in_actual_target;
        end
    end


endmodule


module exe_mem1_reg (
    input clk,
    input resetn,

    input stall,
    input pre_stall,

    input      in_valid,
    output reg out_valid,


    input [ 4:0] in_regfile_waddr,
    input        in_regfile_we,
    input [ 1:0] in_sel_regfile_wdata,
    input [31:0] in_result,
    input [31:0] in_pc,
    input [ 2:0] in_sel_load_store_len,
    input [ 4:0] in_regfile_raddr1,
    input [ 4:0] in_regfile_raddr2,
    input [31:0] in_regfile_rdata1,
    input [31:0] in_regfile_rdata2,
    input [31:0] in_vaddr,
    input        in_is_inst_jirl,
    input [31:0] in_pc_offset,
    input [31:0] in_imm,
    input        in_is_load,
    input        in_is_store,
    input        in_tlb_change,
    input        in_is_cacop,
    input [31:0] in_instruction,

    input in_is_inst_ll_w,
    input in_is_inst_sc_w,

    input        in_actual_taken,
    input [31:0] in_actual_target,

    output reg [ 4:0] out_regfile_waddr,
    output reg        out_regfile_we,
    output reg [ 1:0] out_sel_regfile_wdata,
    output reg [31:0] out_result,
    output reg [31:0] out_pc,
    output reg [ 2:0] out_sel_load_store_len,
    output reg [ 4:0] out_regfile_raddr1,
    output reg [ 4:0] out_regfile_raddr2,
    output reg [31:0] out_regfile_rdata1,
    output reg [31:0] out_regfile_rdata2,
    output reg [31:0] out_vaddr,
    output reg        out_is_inst_jirl,
    output reg [31:0] out_pc_offset,
    output reg [31:0] out_imm,
    output reg        out_is_load,
    output reg        out_is_store,
    output reg        out_tlb_change,
    output reg        out_is_cacop,
    output reg [31:0] out_instruction,

    output reg out_is_inst_ll_w,
    output reg out_is_inst_sc_w,

    output reg        out_actual_taken,
    output reg [31:0] out_actual_target
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid              <= 1'b0;
            out_regfile_waddr      <= 5'd0;
            out_regfile_we         <= 1'b0;
            out_sel_regfile_wdata  <= 2'd0;
            out_result             <= 32'd0;
            out_pc                 <= 32'd0;
            out_sel_load_store_len <= 3'd0;
            out_regfile_raddr1     <= 5'd0;
            out_regfile_raddr2     <= 5'd0;
            out_regfile_rdata1     <= 32'd0;
            out_regfile_rdata2     <= 32'd0;
            out_vaddr              <= 32'b0;
            out_is_inst_jirl       <= 1'b0;
            out_pc_offset          <= 32'b0;
            out_imm                <= 32'd0;
            out_is_load            <= 1'b0;
            out_is_store           <= 1'b0;
            out_tlb_change         <= 1'b0;
            out_is_cacop           <= 1'b0;
            out_instruction        <= 32'b0;
            out_is_inst_ll_w       <= 1'b0;
            out_is_inst_sc_w       <= 1'b0;
            out_actual_taken       <= 1'b0;
            out_actual_target      <= 32'b0;
        end else if (!stall) begin
            out_valid              <= in_valid && !pre_stall;
            out_regfile_waddr      <= in_regfile_waddr;
            out_regfile_we         <= in_regfile_we;
            out_sel_regfile_wdata  <= in_sel_regfile_wdata;
            out_result             <= in_result;
            out_pc                 <= in_pc;
            out_sel_load_store_len <= in_sel_load_store_len;
            out_regfile_raddr1     <= in_regfile_raddr1;
            out_regfile_raddr2     <= in_regfile_raddr2;
            out_regfile_rdata1     <= in_regfile_rdata1;
            out_regfile_rdata2     <= in_regfile_rdata2;
            out_vaddr              <= in_vaddr;
            out_is_inst_jirl       <= in_is_inst_jirl;
            out_pc_offset          <= in_pc_offset;
            out_imm                <= in_imm;
            out_is_load            <= in_is_load;
            out_is_store           <= in_is_store;
            out_tlb_change         <= in_tlb_change;
            out_is_cacop           <= in_is_cacop;
            out_instruction        <= in_instruction;
            out_is_inst_ll_w       <= in_is_inst_ll_w;
            out_is_inst_sc_w       <= in_is_inst_sc_w;
            out_actual_taken       <= in_actual_taken;
            out_actual_target      <= in_actual_target;
        end
    end

endmodule


module mem1_mem2_reg (
    input clk,
    input resetn,

    input stall,
    input pre_stall,

    input      in_valid,
    output reg out_valid,


    input [ 4:0] in_regfile_waddr,
    input        in_regfile_we,
    input [ 1:0] in_sel_regfile_wdata,
    input [31:0] in_result,
    input [31:0] in_pc,
    input [ 2:0] in_sel_load_store_len,
    input [ 4:0] in_regfile_raddr1,
    input [ 4:0] in_regfile_raddr2,
    input [31:0] in_regfile_rdata1,
    input [31:0] in_regfile_rdata2,
    input [31:0] in_vaddr,
    input [31:0] in_data_pa,
    input        in_is_load,
    input        in_is_store,
    input        in_tlb_change,
    input        in_is_cacop,
    input [31:0] in_instruction,

    input in_is_inst_ll_w,
    input in_is_inst_sc_w,

    input        in_actual_taken,
    input [31:0] in_actual_target,

    output reg [ 4:0] out_regfile_waddr,
    output reg        out_regfile_we,
    output reg [ 1:0] out_sel_regfile_wdata,
    output reg [31:0] out_result,
    output reg [31:0] out_pc,
    output reg [ 2:0] out_sel_load_store_len,
    output reg [ 4:0] out_regfile_raddr1,
    output reg [ 4:0] out_regfile_raddr2,
    output reg [31:0] out_regfile_rdata1,
    output reg [31:0] out_regfile_rdata2,
    output reg [31:0] out_vaddr,
    output reg [31:0] out_data_pa,
    output reg        out_is_load,
    output reg        out_is_store,
    output reg        out_tlb_change,

    output reg        out_is_cacop,
    output reg [31:0] out_instruction,

    output reg out_is_inst_ll_w,
    output reg out_is_inst_sc_w,

    output reg        out_actual_taken,
    output reg [31:0] out_actual_target
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_valid              <= 1'b0;
            out_regfile_waddr      <= 5'd0;
            out_regfile_we         <= 1'b0;
            out_sel_regfile_wdata  <= 2'd0;
            out_result             <= 32'd0;
            out_pc                 <= 32'd0;
            out_sel_load_store_len <= 3'd0;
            out_regfile_raddr1     <= 5'd0;
            out_regfile_raddr2     <= 5'd0;
            out_regfile_rdata1     <= 32'd0;
            out_regfile_rdata2     <= 32'd0;
            out_vaddr              <= 32'b0;
            out_data_pa            <= 32'b0;
            out_is_load            <= 1'b0;
            out_is_store           <= 1'b0;
            out_tlb_change         <= 1'b0;
            out_is_cacop           <= 1'b0;
            out_instruction        <= 32'b0;
            out_is_inst_ll_w       <= 1'b0;
            out_is_inst_sc_w       <= 1'b0;
            out_actual_taken       <= 1'b0;
            out_actual_target      <= 32'b0;
        end else if (!stall) begin
            out_valid              <= in_valid && !pre_stall;
            out_regfile_waddr      <= in_regfile_waddr;
            out_regfile_we         <= in_regfile_we;
            out_sel_regfile_wdata  <= in_sel_regfile_wdata;
            out_result             <= in_result;
            out_pc                 <= in_pc;
            out_sel_load_store_len <= in_sel_load_store_len;
            out_regfile_raddr1     <= in_regfile_raddr1;
            out_regfile_raddr2     <= in_regfile_raddr2;
            out_regfile_rdata1     <= in_regfile_rdata1;
            out_regfile_rdata2     <= in_regfile_rdata2;
            out_vaddr              <= in_vaddr;
            out_data_pa            <= in_data_pa;
            out_is_load            <= in_is_load;
            out_is_store           <= in_is_store;
            out_tlb_change         <= in_tlb_change;
            out_is_cacop           <= in_is_cacop;
            out_instruction        <= in_instruction;
            out_is_inst_ll_w       <= in_is_inst_ll_w;
            out_is_inst_sc_w       <= in_is_inst_sc_w;
            out_actual_taken       <= in_actual_taken;
            out_actual_target      <= in_actual_target;
        end
    end

endmodule


module mem2_wb_reg (
    input clk,
    input resetn,

    input stall,
    input pre_stall,

    input      in_valid,
    output reg out_valid,

    input [ 4:0] in_regfile_waddr,
    input        in_regfile_we,
    input [31:0] in_result,
    input [31:0] in_pc,
    input [ 4:0] in_regfile_raddr1,
    input [ 4:0] in_regfile_raddr2,
    input [31:0] in_regfile_rdata1,
    input [31:0] in_regfile_rdata2,
    input [31:0] in_vaddr,
    input        in_is_load,
    input        in_is_store,
    input        in_tlb_change,
    input [31:0] in_instruction,

    input in_is_inst_ll_w,
    input in_is_inst_sc_w,

    input in_is_cacop,

    input        in_actual_taken,
    input [31:0] in_actual_target,

    output reg [ 4:0] out_regfile_waddr,
    output reg        out_regfile_we,
    output reg [31:0] out_result,
    output reg [31:0] out_pc,
    output reg [ 4:0] out_regfile_raddr1,
    output reg [ 4:0] out_regfile_raddr2,
    output reg [31:0] out_regfile_rdata1,
    output reg [31:0] out_regfile_rdata2,
    output reg [31:0] out_vaddr,
    output reg        out_is_load,
    output reg        out_is_store,
    output reg        out_tlb_change,
    output reg [31:0] out_instruction,

    output reg out_is_inst_ll_w,
    output reg out_is_inst_sc_w,

    output reg out_is_cacop,

    output reg        out_actual_taken,
    output reg [31:0] out_actual_target
);


    always @(posedge clk) begin
        if (!resetn) begin
            out_valid          <= 1'b0;
            out_regfile_waddr  <= 5'd0;
            out_regfile_we     <= 1'b0;
            out_result         <= 32'd0;
            out_pc             <= 32'd0;
            out_regfile_raddr1 <= 5'd0;
            out_regfile_raddr2 <= 5'd0;
            out_regfile_rdata1 <= 32'd0;
            out_regfile_rdata2 <= 32'd0;
            out_vaddr          <= 32'b0;
            out_is_load        <= 1'b0;
            out_is_store       <= 1'b0;
            out_tlb_change     <= 1'b0;
            out_instruction    <= 32'b0;
            out_is_inst_ll_w   <= 1'b0;
            out_is_inst_sc_w   <= 1'b0;
            out_is_cacop       <= 1'b0;
            out_actual_taken   <= 1'b0;
            out_actual_target  <= 32'b0;
        end else if (!stall) begin
            out_valid          <= in_valid && !pre_stall;
            out_regfile_waddr  <= in_regfile_waddr;
            out_regfile_we     <= in_regfile_we;
            out_result         <= in_result;
            out_pc             <= in_pc;
            out_regfile_raddr1 <= in_regfile_raddr1;
            out_regfile_raddr2 <= in_regfile_raddr2;
            out_regfile_rdata1 <= in_regfile_rdata1;
            out_regfile_rdata2 <= in_regfile_rdata2;
            out_vaddr          <= in_vaddr;
            out_is_load        <= in_is_load;
            out_is_store       <= in_is_store;
            out_tlb_change     <= in_tlb_change;
            out_instruction    <= in_instruction;
            out_is_inst_ll_w   <= in_is_inst_ll_w;
            out_is_inst_sc_w   <= in_is_inst_sc_w;
            out_is_cacop       <= in_is_cacop;
            out_actual_taken   <= in_actual_taken;
            out_actual_target  <= in_actual_target;
        end
    end



endmodule
