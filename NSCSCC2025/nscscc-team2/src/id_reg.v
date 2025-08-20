module id_reg(
    input  wire         clk,
    input  wire         reset,
    input  wire         br_flush,
    input  wire         ertn_flush,
    input  wire         ex_flush,
    input  wire         refetch_flush,
    input  wire         stall,

    input  wire         if_ready_go,

    input  wire [31:0]  pc_plus4_in,
    input  wire [31:0]  inst_in,
    input  wire [15:0]  ex_info_in,
    input  wire [ 1:0]  badv_info_in,
    input  wire         bp_ret_en_in,
    input  wire [29:0]  bp_ret_pc_in,
    input  wire         bp_taken_in,
    input  wire [ 4:0]  bp_ret_index_in,
    input  wire [12:0]  alu_op_in,
    input  wire         src1_is_pc_in,
    input  wire [31:0]  imm_in,
    input  wire         src2_is_imm_in,
    input  wire [ 4:0]  rd_in,
    input  wire [ 4:0]  rj_in,
    input  wire [ 4:0]  rk_in,
    input  wire [ 3:0]  data_sram_we_in,
    input  wire [ 2:0]  rf_wdata_sel_in,
    input  wire         rf_we_in,
    input  wire [ 4:0]  rf_waddr_in,
    input  wire         src_reg_is_rd_in,
    input  wire [ 1:0]  ex_result_sel_in,
    input  wire         mmd_is_signed_in,
    input  wire         mul_need_hi_in,
    input  wire         ld_ext_is_signed_in,
    input  wire [ 3:0]  ld_width_in,
    input  wire         csr_we_in,
    input  wire         is_csr_op_in,
    input  wire         new_refetch_flag_in,
    input  wire [ 5:0]  dif_ld_info_in,
    input  wire         ipe_ex_in,
    input  wire         inst_branch_in,
    input  wire [11:0]  i12_in,
    input  wire [19:0]  i20_in,
    input  wire [15:0]  i16_in,
    input  wire [25:0]  i26_in,
    input  wire [ 4:0]  ui5_in,
    input  wire [13:0]  csr_num_in,
    input  wire         is_ld_in,
    input  wire         is_st_in,
    input  wire         inst_st_b_in,
    input  wire         inst_st_h_in,
    input  wire         is_cntinst_in,
    input  wire         inst_jirl_in,
    input  wire         inst_b_in,
    input  wire         inst_bl_in,
    input  wire         inst_beq_in,
    input  wire         inst_bne_in,
    input  wire         inst_blt_in,
    input  wire         inst_bge_in,
    input  wire         inst_bltu_in,
    input  wire         inst_bgeu_in,
    input  wire         inst_csrxchg_in,
    input  wire         inst_ertn_in,
    input  wire         inst_syscall_in,
    input  wire         inst_break_in,
    input  wire         inst_tlbsrch_in,
    input  wire         inst_invtlb_in,
    input  wire         inst_tlbwr_in,
    input  wire         inst_tlbrd_in,
    input  wire         inst_cacop_in,
    input  wire         inst_cpucfg_in,
    input  wire         inst_ll_w_in,
    input  wire         inst_sc_w_in,
    input  wire         inst_ibar_in,
    input  wire         inst_tlbfill_in,
    input  wire [ 4:0]  cacop_code_in,
    input  wire         not_inst_in,
    input  wire         inst_idle_in,
    input  wire         need_addr_alu_in,
    input  wire         inst_dbar_in,

    output reg  [31:0]  pc_plus4_out,
    output reg  [31:0]  inst_out,
    output reg  [15:0]  ex_info_out,
    output reg  [ 1:0]  badv_info_out,
    output reg          bp_ret_en_out,
    output reg  [29:0]  bp_ret_pc_out,
    output reg          bp_taken_out,
    output reg  [ 4:0]  bp_ret_index_out,
    output reg  [12:0]  alu_op_out,
    output reg          src1_is_pc_out,
    output reg  [31:0]  imm_out,
    output reg          src2_is_imm_out,
    output reg  [ 4:0]  rd_out,
    output reg  [ 4:0]  rj_out,
    output reg  [ 4:0]  rk_out,
    output reg  [ 3:0]  data_sram_we_out,
    output reg  [ 2:0]  rf_wdata_sel_out,
    output reg          rf_we_out,
    output reg  [ 4:0]  rf_waddr_out,
    output reg          src_reg_is_rd_out,
    output reg  [ 1:0]  ex_result_sel_out,
    output reg          mmd_is_signed_out,
    output reg          mul_need_hi_out,
    output reg          ld_ext_is_signed_out,
    output reg  [ 3:0]  ld_width_out,
    output reg          csr_we_out,
    output reg          is_csr_op_out,
    output reg          new_refetch_flag_out,
    output reg  [ 5:0]  dif_ld_info_out,
    output reg          ipe_ex_out,
    output reg          inst_branch_out,
    output reg  [11:0]  i12_out,
    output reg  [19:0]  i20_out,
    output reg  [15:0]  i16_out,
    output reg  [25:0]  i26_out,
    output reg  [ 4:0]  ui5_out,
    output reg  [13:0]  csr_num_out,
    output reg          is_ld_out,
    output reg          is_st_out,
    output reg          inst_st_b_out,
    output reg          inst_st_h_out,
    output reg          is_cntinst_out,
    output reg          inst_jirl_out,
    output reg          inst_b_out,
    output reg          inst_bl_out,
    output reg          inst_beq_out,
    output reg          inst_bne_out,
    output reg          inst_blt_out,
    output reg          inst_bge_out,
    output reg          inst_bltu_out,
    output reg          inst_bgeu_out,
    output reg          inst_csrxchg_out,
    output reg          inst_ertn_out,
    output reg          inst_syscall_out,
    output reg          inst_break_out,
    output reg          inst_tlbsrch_out,
    output reg          inst_invtlb_out,
    output reg          inst_tlbwr_out,
    output reg          inst_tlbrd_out,
    output reg          inst_cacop_out,
    output reg          inst_cpucfg_out,
    output reg          inst_ll_w_out,
    output reg          inst_sc_w_out,
    output reg          inst_ibar_out,
    output reg          inst_tlbfill_out,
    output reg  [ 4:0]  cacop_code_out,
    output reg          not_inst_out,
    output reg          inst_idle_out,
    output reg          need_addr_alu_out,
    output reg          inst_dbar_out,

    input  wire         ex_fire,
    output wire         id_fire,
    output wire         id_allowin,
    output reg          id_valid
);

assign id_allowin = ((!id_valid) || ex_fire) && !stall;
assign id_fire    = (if_ready_go && id_allowin);

always @(posedge clk or posedge reset) begin
  if (reset) begin
    id_valid <= 1'b0;
  end
  else if (br_flush || ertn_flush || ex_flush || refetch_flush) begin
    id_valid <= 1'b0;
  end
  else if (id_fire) begin 
    id_valid <= 1'b1;        
  end
  else if (ex_fire) begin 
    id_valid <= 1'b0;       
  end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc_plus4_out        <= 32'b0;
        inst_out            <= 32'b0;
        ex_info_out         <= 16'b0;
        badv_info_out       <= 2'b0;
        bp_ret_en_out       <= 1'b0;
        bp_ret_pc_out       <= 30'b0;
        bp_taken_out        <= 1'b0;
        bp_ret_index_out    <= 5'b0;
        alu_op_out          <= 13'b0;
        src1_is_pc_out      <= 1'b0;
        imm_out             <= 32'b0;
        src2_is_imm_out     <= 1'b0;
        rd_out              <= 5'b0;
        rj_out              <= 5'b0;
        rk_out              <= 5'b0;
        data_sram_we_out    <= 4'b0;
        rf_wdata_sel_out    <= 3'b0;
        rf_we_out           <= 1'b0;
        rf_waddr_out        <= 5'b0;
        src_reg_is_rd_out   <= 1'b0;
        ex_result_sel_out   <= 2'b0;
        mmd_is_signed_out   <= 1'b0;
        mul_need_hi_out     <= 1'b0;
        ld_ext_is_signed_out<= 1'b0;
        ld_width_out        <= 4'b0;
        csr_we_out          <= 1'b0;
        is_csr_op_out       <= 1'b0;
        new_refetch_flag_out<= 1'b0;
        dif_ld_info_out     <= 6'b0;
        ipe_ex_out          <= 1'b0;
        inst_branch_out     <= 1'b0;
        i12_out             <= 12'b0;
        i20_out             <= 20'b0;
        i16_out             <= 16'b0;
        i26_out             <= 26'b0;
        ui5_out             <= 5'b0;
        csr_num_out         <= 14'b0;
        is_ld_out           <= 1'b0;
        is_st_out           <= 1'b0;
        inst_st_b_out       <= 1'b0;
        inst_st_h_out       <= 1'b0;
        is_cntinst_out      <= 1'b0;
        inst_jirl_out       <= 1'b0;
        inst_b_out          <= 1'b0;
        inst_bl_out         <= 1'b0;
        inst_beq_out        <= 1'b0;
        inst_bne_out        <= 1'b0;
        inst_blt_out        <= 1'b0;
        inst_bge_out        <= 1'b0;
        inst_bltu_out       <= 1'b0;
        inst_bgeu_out       <= 1'b0;
        inst_csrxchg_out    <= 1'b0;
        inst_ertn_out       <= 1'b0;
        inst_syscall_out    <= 1'b0;
        inst_break_out      <= 1'b0;
        inst_tlbsrch_out    <= 1'b0;
        inst_invtlb_out     <= 1'b0;
        inst_tlbwr_out      <= 1'b0;
        inst_tlbrd_out      <= 1'b0;
        inst_cacop_out      <= 1'b0;
        inst_cpucfg_out     <= 1'b0;
        inst_ll_w_out       <= 1'b0;
        inst_sc_w_out       <= 1'b0;
        inst_ibar_out       <= 1'b0;
        inst_tlbfill_out    <= 1'b0;
        cacop_code_out      <= 5'b0;
        not_inst_out        <= 1'b0;
        inst_idle_out       <= 1'b0;
        need_addr_alu_out   <= 1'b0;
        inst_dbar_out       <= 1'b0;
    end
    else if (br_flush || ertn_flush || ex_flush || refetch_flush) begin
        pc_plus4_out        <= 32'b0;
        inst_out            <= 32'b0;
        ex_info_out         <= 16'b0;
        badv_info_out       <= 2'b0;
        bp_ret_en_out       <= 1'b0;
        bp_ret_pc_out       <= 30'b0;
        bp_taken_out        <= 1'b0;
        bp_ret_index_out    <= 5'b0;
        alu_op_out          <= 13'b0;
        src1_is_pc_out      <= 1'b0;
        imm_out             <= 32'b0;
        src2_is_imm_out     <= 1'b0;
        rd_out              <= 5'b0;
        rj_out              <= 5'b0;
        rk_out              <= 5'b0;
        data_sram_we_out    <= 4'b0;
        rf_wdata_sel_out    <= 3'b0;
        rf_we_out           <= 1'b0;
        rf_waddr_out        <= 5'b0;
        src_reg_is_rd_out   <= 1'b0;
        ex_result_sel_out   <= 2'b0;
        mmd_is_signed_out   <= 1'b0;
        mul_need_hi_out     <= 1'b0;
        ld_ext_is_signed_out<= 1'b0;
        ld_width_out        <= 4'b0;
        csr_we_out          <= 1'b0;
        is_csr_op_out       <= 1'b0;
        new_refetch_flag_out<= 1'b0;
        dif_ld_info_out     <= 6'b0;
        ipe_ex_out          <= 1'b0;
        inst_branch_out     <= 1'b0;
        i12_out             <= 12'b0;
        i20_out             <= 20'b0;
        i16_out             <= 16'b0;
        i26_out             <= 26'b0;
        ui5_out             <= 5'b0;
        csr_num_out         <= 14'b0;
        is_ld_out           <= 1'b0;
        is_st_out           <= 1'b0;
        inst_st_b_out       <= 1'b0;
        inst_st_h_out       <= 1'b0;
        is_cntinst_out      <= 1'b0;
        inst_jirl_out       <= 1'b0;
        inst_b_out          <= 1'b0;
        inst_bl_out         <= 1'b0;
        inst_beq_out        <= 1'b0;
        inst_bne_out        <= 1'b0;
        inst_blt_out        <= 1'b0;
        inst_bge_out        <= 1'b0;
        inst_bltu_out       <= 1'b0;
        inst_bgeu_out       <= 1'b0;
        inst_csrxchg_out    <= 1'b0;
        inst_ertn_out       <= 1'b0;
        inst_syscall_out    <= 1'b0;
        inst_break_out      <= 1'b0;
        inst_tlbsrch_out    <= 1'b0;
        inst_invtlb_out     <= 1'b0;
        inst_tlbwr_out      <= 1'b0;
        inst_tlbrd_out      <= 1'b0;
        inst_cacop_out      <= 1'b0;
        inst_cpucfg_out     <= 1'b0;
        inst_ll_w_out       <= 1'b0;
        inst_sc_w_out       <= 1'b0;
        inst_ibar_out       <= 1'b0;
        inst_tlbfill_out    <= 1'b0;
        cacop_code_out      <= 5'b0;
        not_inst_out        <= 1'b0;
        inst_idle_out       <= 1'b0;
        need_addr_alu_out   <= 1'b0;
        inst_dbar_out       <= 1'b0;
    end
    else if (id_fire) begin
        pc_plus4_out        <= pc_plus4_in;
        inst_out            <= inst_in;
        ex_info_out         <= ex_info_in;
        badv_info_out       <= badv_info_in;
        bp_ret_en_out       <= bp_ret_en_in;
        bp_ret_pc_out       <= bp_ret_pc_in;
        bp_taken_out        <= bp_taken_in;
        bp_ret_index_out    <= bp_ret_index_in;
        alu_op_out          <= alu_op_in;
        src1_is_pc_out      <= src1_is_pc_in;
        imm_out             <= imm_in;
        src2_is_imm_out     <= src2_is_imm_in;
        rd_out              <= rd_in;
        rj_out              <= rj_in;
        rk_out              <= rk_in;
        data_sram_we_out    <= data_sram_we_in;
        rf_wdata_sel_out    <= rf_wdata_sel_in;
        rf_we_out           <= rf_we_in;
        rf_waddr_out        <= rf_waddr_in;
        src_reg_is_rd_out   <= src_reg_is_rd_in;
        ex_result_sel_out   <= ex_result_sel_in;
        mmd_is_signed_out   <= mmd_is_signed_in;
        mul_need_hi_out     <= mul_need_hi_in;
        ld_ext_is_signed_out<= ld_ext_is_signed_in;
        ld_width_out        <= ld_width_in;
        csr_we_out          <= csr_we_in;
        is_csr_op_out       <= is_csr_op_in;
        new_refetch_flag_out<= new_refetch_flag_in;
        dif_ld_info_out     <= dif_ld_info_in;
        ipe_ex_out          <= ipe_ex_in;
        inst_branch_out     <= inst_branch_in;
        i12_out             <= i12_in;
        i20_out             <= i20_in;
        i16_out             <= i16_in;
        i26_out             <= i26_in;
        ui5_out             <= ui5_in;
        csr_num_out         <= csr_num_in;
        is_ld_out           <= is_ld_in;
        is_st_out           <= is_st_in;
        inst_st_b_out       <= inst_st_b_in;
        inst_st_h_out       <= inst_st_h_in;
        is_cntinst_out      <= is_cntinst_in;
        inst_jirl_out       <= inst_jirl_in;
        inst_b_out          <= inst_b_in;
        inst_bl_out         <= inst_bl_in;
        inst_beq_out        <= inst_beq_in;
        inst_bne_out        <= inst_bne_in;
        inst_blt_out        <= inst_blt_in;
        inst_bge_out        <= inst_bge_in;
        inst_bltu_out       <= inst_bltu_in;
        inst_bgeu_out       <= inst_bgeu_in;
        inst_csrxchg_out    <= inst_csrxchg_in;
        inst_ertn_out       <= inst_ertn_in;
        inst_syscall_out    <= inst_syscall_in;
        inst_break_out      <= inst_break_in;
        inst_tlbsrch_out    <= inst_tlbsrch_in;
        inst_invtlb_out     <= inst_invtlb_in;
        inst_tlbwr_out      <= inst_tlbwr_in;
        inst_tlbrd_out      <= inst_tlbrd_in;
        inst_cacop_out      <= inst_cacop_in;
        inst_cpucfg_out     <= inst_cpucfg_in;
        inst_ll_w_out       <= inst_ll_w_in;
        inst_sc_w_out       <= inst_sc_w_in;
        inst_ibar_out       <= inst_ibar_in;
        inst_tlbfill_out    <= inst_tlbfill_in;
        cacop_code_out      <= cacop_code_in;
        not_inst_out        <= not_inst_in;
        inst_idle_out       <= inst_idle_in;
        need_addr_alu_out   <= need_addr_alu_in;
        inst_dbar_out       <= inst_dbar_in;
    end
end

endmodule
