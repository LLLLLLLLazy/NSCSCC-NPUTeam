module wb_reg(
    input  wire         clk,         
    input  wire         reset,     

    input  wire         ertn_flush,
    input  wire         ex_flush,
    input  wire         refetch_flush,

    input  wire         mem_ready_go,
      
    input  wire [ 2:0]  rf_wdata_sel_in,
    input  wire         rf_we_in,
    input  wire [ 4:0]  rf_waddr_in,
    input  wire [31:0]  pc_plus4_in,   
    input  wire [31:0]  data_sram_addr_in,
    input  wire [13:0]  csr_num_in,
    input  wire         csr_we_in,
    input  wire [31:0]  csr_wmask_in,
    input  wire [31:0]  rkd_value_in,
    input  wire         ertn_flush_in,
    input  wire [15:0]  ex_info_in,
    input  wire         inst_tlbsrch_in,
    input  wire [ 4:0]  rd_in,
    input  wire         inst_invtlb_in,
    input  wire [31:0]  rj_value_in,
    input  wire         inst_tlbwr_in,
    input  wire         inst_tlbrd_in,
    input  wire [ 1:0]  badv_info_in,
    input  wire         is_cacop_in,
    input  wire [31:0]  cacop_va_in,
    input  wire [31:0]   icacop_pa_in,
    input  wire [31:0]   dcacop_pa_in,
    input  wire          is_ld_in,
    input  wire [31:0]  inst_in,
    input  wire         is_cntinst_in,
    input  wire         is_csr_op_in,
    input  wire         is_st_in,
    input  wire         is_st_b_in,
    input  wire         is_st_h_in,
    input  wire [31:0]  st_vaddr_in,
    input  wire [31:0]  st_paddr_in,
    input  wire [31:0]  st_data_in,
    input  wire [31:0]  ld_vaddr_in,
    input  wire         is_ll_w_in,
    input  wire         is_sc_w_in,
    input  wire [ 5:0]  dif_ld_info_in,
    input  wire         ll_w_cached_in,
    input  wire         inst_tlbfill_in,
    input  wire [31:0]  rf_wdata_in,

    output reg  [ 2:0]  rf_wdata_sel_out,
    output reg          rf_we_out,
    output reg  [ 4:0]  rf_waddr_out,
    output reg  [31:0]  pc_plus4_out,
    output reg  [31:0]  data_sram_addr_out,
    output reg  [13:0]  csr_num_out,
    output reg          csr_we_out,
    output reg  [31:0]  csr_wmask_out,
    output reg  [31:0]  rkd_value_out,
    output reg          ertn_flush_out,
    output reg  [15:0]  ex_info_out,
    output reg          inst_tlbsrch_out,
    output reg  [ 4:0]  rd_out,
    output reg          inst_invtlb_out,
    output reg  [31:0]  rj_value_out,
    output reg          inst_tlbwr_out,
    output reg          inst_tlbrd_out,
    output reg  [ 1:0]  badv_info_out,
    output reg          is_cacop_out,
    output reg  [31:0]  cacop_va_out,
    output reg  [31:0]  icacop_pa_out,
    output reg  [31:0]  dcacop_pa_out,
    output reg          is_ld_out,
    output reg  [31:0]  inst_out,
    output reg          is_cntinst_out,
    output reg          is_csr_op_out,
    output reg          is_st_out,
    output reg          is_st_b_out,
    output reg          is_st_h_out,
    output reg  [31:0]  st_vaddr_out,
    output reg  [31:0]  st_paddr_out,
    output reg  [31:0]  st_data_out,
    output reg  [31:0]  ld_vaddr_out,
    output reg          is_ll_w_out,
    output reg          is_sc_w_out,
    output reg  [ 5:0]  dif_ld_info_out,
    output reg          ll_w_cached_out,
    output reg          inst_tlbfill_out,
    output reg  [31:0]  rf_wdata_out,

    output wire         wb_fire,
    output reg          wb_valid
);

assign wb_fire = mem_ready_go ;

always @(posedge clk or posedge reset) begin
  if (reset) begin
    wb_valid <= 1'b0;
  end
  else if (ertn_flush || ex_flush || refetch_flush) begin
    wb_valid <= 1'b0;
  end
  else if (wb_fire) begin 
    wb_valid <= 1'b1;        
  end
  else begin 
    wb_valid <= 1'b0;       
  end
end

always @(posedge clk or posedge reset) begin
  if (reset) begin
    ertn_flush_out <= 1'b0;
    ex_info_out    <= 16'b0;
    badv_info_out  <= 2'b0;
  end
  else if (ertn_flush || ex_flush || refetch_flush) begin
    ertn_flush_out <= 1'b0;
    ex_info_out    <= 16'b0;
    badv_info_out  <= 2'b0;
  end
  else if (wb_fire) begin 
    ertn_flush_out <= ertn_flush_in;      
    ex_info_out    <= ex_info_in;  
    badv_info_out  <= badv_info_in;
  end
  else begin
    ertn_flush_out <= 1'b0;
    ex_info_out    <= 16'b0;
    badv_info_out  <= 2'b0;
  end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        rf_wdata_sel_out <= 3'b0;
        rf_we_out        <= 1'b0;
        rf_waddr_out     <= 5'b0;
        pc_plus4_out     <= 32'b0;
        data_sram_addr_out<= 32'b0;
        csr_num_out      <= 14'b0;
        csr_we_out       <= 1'b0;
        csr_wmask_out    <= 32'b0;
        rkd_value_out    <= 32'b0;
        inst_tlbsrch_out <= 1'b0;
        rd_out           <= 5'b0;
        inst_invtlb_out  <= 1'b0;
        rj_value_out     <= 32'b0;
        inst_tlbwr_out   <= 1'b0;
        inst_tlbrd_out   <= 1'b0;
        is_cacop_out     <= 1'b0;
        cacop_va_out     <= 32'b0;
        icacop_pa_out    <= 32'b0;
        dcacop_pa_out    <= 32'b0;
        is_ld_out        <= 1'b0;
        inst_out         <= 32'b0; 
        is_cntinst_out   <= 1'b0;
        is_csr_op_out    <= 1'b0;
        is_st_out        <= 1'b0;
        is_st_b_out      <= 1'b0;
        is_st_h_out      <= 1'b0;
        st_vaddr_out     <= 32'b0;
        st_paddr_out     <= 32'b0;
        st_data_out      <= 32'b0;
        ld_vaddr_out     <= 32'b0;
        is_ll_w_out      <= 1'b0;
        is_sc_w_out      <= 1'b0;
        dif_ld_info_out  <= 6'b0;
        ll_w_cached_out  <= 1'b0;
        inst_tlbfill_out <= 1'b0;
        rf_wdata_out     <= 32'b0;
    end
    else if (wb_fire) begin
        rf_wdata_sel_out <= rf_wdata_sel_in;
        rf_we_out        <= rf_we_in;
        rf_waddr_out     <= rf_waddr_in;
        pc_plus4_out     <= pc_plus4_in;
        data_sram_addr_out <= data_sram_addr_in;
        csr_num_out      <= csr_num_in;
        csr_we_out       <= csr_we_in;
        csr_wmask_out    <= csr_wmask_in;
        rkd_value_out    <= rkd_value_in;
        inst_tlbsrch_out <= inst_tlbsrch_in;
        rd_out           <= rd_in;
        inst_invtlb_out  <= inst_invtlb_in;
        rj_value_out     <= rj_value_in;
        inst_tlbwr_out   <= inst_tlbwr_in;
        inst_tlbrd_out   <= inst_tlbrd_in;
        is_cacop_out     <= is_cacop_in;
        cacop_va_out     <= cacop_va_in;
        icacop_pa_out    <= icacop_pa_in;
        dcacop_pa_out    <= dcacop_pa_in;
        is_ld_out        <= is_ld_in;
        inst_out         <= inst_in; 
        is_cntinst_out   <= is_cntinst_in;
        is_csr_op_out    <= is_csr_op_in;
        is_st_out        <= is_st_in;
        is_st_b_out      <= is_st_b_in;
        is_st_h_out      <= is_st_h_in;
        st_vaddr_out     <= st_vaddr_in;
        st_paddr_out     <= st_paddr_in;
        st_data_out      <= st_data_in;
        ld_vaddr_out     <= ld_vaddr_in;
        is_ll_w_out      <= is_ll_w_in;
        is_sc_w_out      <= is_sc_w_in;
        dif_ld_info_out  <= dif_ld_info_in;
        ll_w_cached_out  <= ll_w_cached_in;
        inst_tlbfill_out <= inst_tlbfill_in;
        rf_wdata_out     <= rf_wdata_in;
    end
end

endmodule
