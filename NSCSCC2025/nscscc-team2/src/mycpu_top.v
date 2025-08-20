// 80 MHz
module core_top(
    input               aclk,
    input               aresetn,
    input    [ 7:0]     intrpt,

    output   [ 3:0]     arid,
    output   [31:0]     araddr,
    output   [ 7:0]     arlen,
    output   [ 2:0]     arsize,
    output   [ 1:0]     arburst,
    output   [ 1:0]     arlock,
    output   [ 3:0]     arcache,
    output   [ 2:0]     arprot,
    output              arvalid,
    input               arready,

    input    [ 3:0]     rid,
    input    [31:0]     rdata,
    input    [ 1:0]     rresp,
    input               rlast,
    input               rvalid,
    output              rready,

    output   [ 3:0]     awid,
    output   [31:0]     awaddr,
    output   [ 7:0]     awlen,
    output   [ 2:0]     awsize,
    output   [ 1:0]     awburst,
    output   [ 1:0]     awlock,
    output   [ 3:0]     awcache,
    output   [ 2:0]     awprot,
    output              awvalid,
    input               awready,

    output   [ 3:0]     wid,
    output   [31:0]     wdata,
    output   [ 3:0]     wstrb,
    output              wlast,
    output              wvalid,
    input               wready,

    input    [ 3:0]     bid,
    input    [ 1:0]     bresp,
    input               bvalid,
    output              bready,

    input               break_point,
    input               infor_flag,
    input    [ 4:0]     reg_num,
    output              ws_valid,
    output   [31:0]     rf_rdata,

    output   [31:0]     debug0_wb_pc,
    output   [ 3:0]     debug0_wb_rf_wen,
    output   [ 4:0]     debug0_wb_rf_wnum,
    output   [31:0]     debug0_wb_rf_wdata
);

`ifdef DIFFTEST_EN
wire [1023:0] regs;
wire [31:0]   crmd;
wire [31:0]   prmd;
wire [31:0]   ecfg;
wire [31:0]   era;
wire [31:0]   badv;
wire [31:0]   save0;
wire [31:0]   save1;
wire [31:0]   save2;
wire [31:0]   save3;
wire [31:0]   tid;
wire [31:0]   tcfg;
wire [31:0]   tval;
wire [31:0]   ticlr;
wire [31:0]   llbctl;
wire [31:0]   pgd;
wire [31:0]   pgdh;
wire [31:0]   pgdl;
`endif 

wire        inst_sram_req;
wire [31:0] inst_sram_addr;
wire        inst_sram_addr_ok; // in
wire        inst_sram_data_ok; // in
wire [31:0] inst_sram_rdata; // in

wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok; // in
wire        data_sram_data_ok; // in
wire [31:0] data_sram_rdata; // in

reg           reset;
always @(posedge aclk) reset <= ~aresetn;

wire  [31:0]  IF_pc;
wire  [31:0]  ID_pc;
wire  [31:0]  EX_pc;
wire  [31:0]  MEM_pc;
wire  [31:0]  WB_pc;

wire  [31:0]  bp_info_to_pc;

wire  [31:0]  pc;
wire          pc_ready;
wire  [31:0]  inst_paddr;
wire  [31:0]  data_paddr;
wire  [31:0]  pc_from_era;
wire          br_taken;
wire          real_br_taken;
wire  [31:0]  br_target;
wire          need_nop;
wire          have_any_flush;

wire          bp_flush;
wire          bp_ret_en;
wire  [29:0]  bp_ret_pc;
wire          bp_taken;
wire  [ 4:0]  bp_ret_index;

wire          inst_buffer_valid;
wire  [31:0]  pc_plus4_from_id;
wire  [31:0]  inst_from_id;

wire [12:0]  p_alu_op;
wire         p_src1_is_pc;
wire [31:0]  p_imm;
wire         p_src2_is_imm;
wire [ 4:0]  p_rd;
wire [ 4:0]  p_rj;
wire [ 4:0]  p_rk;
wire [ 3:0]  p_data_sram_we;
wire [ 2:0]  p_rf_wdata_sel;
wire         p_rf_we;
wire [ 4:0]  p_rf_waddr;
wire         p_src_reg_is_rd;
wire [ 1:0]  p_ex_result_sel;
wire         p_mmd_is_signed;
wire         p_mul_need_hi;
wire         p_ld_ext_is_signed;
wire [ 3:0]  p_ld_width;
wire         p_csr_we;
wire         p_is_csr_op;
wire         p_new_refetch_flag;
wire [ 5:0]  p_dif_ld_info;
wire         p_ipe_ex;
wire         p_inst_branch;
wire [11:0]  p_i12;
wire [19:0]  p_i20;
wire [15:0]  p_i16;
wire [25:0]  p_i26;
wire [ 4:0]  p_ui5;
wire [13:0]  p_csr_num;
wire         p_is_ld;
wire         p_is_st;
wire         p_inst_st_b;
wire         p_inst_st_h;
wire         p_is_cntinst;
wire         p_inst_jirl;
wire         p_inst_b;
wire         p_inst_bl;
wire         p_inst_beq;
wire         p_inst_bne;
wire         p_inst_blt;
wire         p_inst_bge;
wire         p_inst_bltu;
wire         p_inst_bgeu;
wire         p_inst_csrxchg;
wire         p_inst_ertn;
wire         p_sys_ex;
wire         p_brk_ex;
wire         p_inst_tlbsrch;
wire         p_inst_invtlb;
wire         p_inst_tlbwr;
wire         p_inst_tlbrd;
wire         p_inst_cacop;
wire         p_inst_cpucfg;
wire         p_inst_ll_w;
wire         p_inst_sc_w;
wire         p_inst_ibar;
wire         p_inst_dbar;
wire         p_inst_tlbfill;
wire [ 4:0]  p_cacop_code;
wire         p_inst_idle;
wire         p_ine_ex;
wire         p_need_addr_alu;

wire  [12:0]  alu_op;
wire          src1_is_pc;
wire  [31:0]  imm;
wire          src2_is_imm;
wire  [ 4:0]  rd;
wire  [ 4:0]  rj;
wire  [ 4:0]  rk;
wire  [ 2:0]  rf_wdata_sel;
wire          rf_we;
wire  [ 4:0]  rf_waddr;
wire          src_reg_is_rd;
wire  [ 1:0]  ex_result_sel;
wire          mmd_is_signed;
wire          mul_need_hi;
wire          ld_ext_is_signed;
wire  [ 3:0]  ld_width;
wire          is_csr_op;
wire  [ 5:0]  dif_ld_info;
wire          ipe_ex;
wire          need_addr_alu;

wire  [11:0]  i12;
wire  [19:0]  i20;
wire  [15:0]  i16;
wire  [25:0]  i26;
wire  [ 4:0]  ui5;
wire  [13:0]  csr_num;

wire          csr_we;
wire  [31:0]  csr_rdata;

wire          is_ld;
wire          is_st;
wire          t_is_st;

wire          inst_jirl;
wire          inst_b;
wire          inst_bl;
wire          inst_beq;
wire          inst_bne;
wire          inst_blt;
wire          inst_bltu;
wire          inst_bge;
wire          inst_bgeu;
wire          inst_st_b;
wire          inst_st_h;
wire          inst_csrxchg;
wire          inst_ertn;
wire          inst_tlbsrch;
wire          inst_invtlb;
wire          inst_tlbwr;
wire          inst_tlbrd;
wire          inst_cacop;
wire          inst_cpucfg;
wire          inst_ll_w;
wire          inst_sc_w;
wire          inst_ibar;
wire          inst_dbar;
wire          inst_branch;
wire          inst_tlbfill;
wire          inst_idle;

wire          is_cntinst;

wire  [ 4:0]  cacop_code;

wire  [ 4:0]  rf_raddr2;
wire  [31:0]  rj_value;
wire  [31:0]  rkd_value;

wire  [31:0]  r_rkd_value;
wire  [31:0]  r_rj_value;

wire  [31:0]  pc_from_if;

wire  [ 3:0]  data_sram_we_from_id;
wire          bp_ret_en_from_id;
wire  [29:0]  bp_ret_pc_from_id;
wire          bp_taken_from_id;
wire  [ 4:0]  bp_ret_index_from_id;

wire          execute_finish;

wire  [12:0]  alu_op_from_ex;
wire  [31:0]  pc_plus4_from_ex;
wire  [31:0]  rj_value_from_ex;
wire  [ 4:0]  rd_from_ex;
wire  [31:0]  rkd_value_from_ex;
wire  [ 3:0]  data_sram_we_from_ex;
wire  [ 2:0]  rf_wdata_sel_from_ex;
wire          rf_we_from_ex;
wire  [ 4:0]  rf_waddr_from_ex;
wire  [ 4:0]  rj_from_ex;
wire  [ 4:0]  rkd_from_ex;
wire          is_ld_from_ex;
wire          is_st_from_ex;
wire  [31:0]  data_sram_wdata_from_ex;
wire  [ 1:0]  ex_result_sel_from_ex;
wire          mmd_is_signed_from_ex;
wire          mul_need_hi_from_ex;
wire          ld_ext_is_signed_from_ex;
wire  [ 3:0]  ld_width_from_ex;
wire          is_st_b_from_ex;
wire          is_st_h_from_ex;
wire  [13:0]  csr_num_from_ex;
wire          csr_we_from_ex;
wire  [31:0]  csr_wmask_from_ex;
wire          ertn_flush_from_ex;
wire          is_csr_op_from_ex;
wire          need_nop_from_ex;
wire          inst_tlbsrch_from_ex;
wire          inst_invtlb_from_ex;
wire          inst_tlbwr_from_ex;
wire          inst_tlbrd_from_ex;
wire          is_cacop_from_ex;
wire          is_cpucfg_from_ex;
wire  [31:0]  inst_from_ex;
wire          is_cntinst_from_ex;
wire          is_ll_w_from_ex;
wire          is_sc_w_from_ex;
wire  [ 5:0]  dif_ld_info_from_ex;
wire  [31:0]  alu_result_from_ex;
wire  [31:0]  cacop_va_from_ex;
wire  [31:0]  data_paddr_from_ex;
wire          inst_tlbfill_from_ex;

wire  [31:0]  forwarding_from_ex;
wire  [31:0]  forwarding_from_mem;
wire          need_ex_forward;

wire  [31:0]  alu_src1;
wire  [31:0]  alu_src2;
wire  [31:0]  alu_result;
wire  [31:0]  addr_alu_result;
wire          addr_alu_finish;

wire  [31:0]  mul_result;
wire  [31:0]  div_result;
wire  [31:0]  mod_result;

wire  [31:0]  ex_result;

wire  [31:0]  rkd_value_from_mem;
wire  [ 3:0]  data_sram_we_from_mem;
wire  [ 2:0]  rf_wdata_sel_from_mem;
wire  [31:0]  ex_result_from_mem;
wire          rf_we_from_mem;
wire  [ 4:0]  rf_waddr_from_mem;
wire  [31:0]  pc_plus4_from_mem;
wire  [31:0]  data_sram_wdata_from_mem;
wire          ld_ext_is_signed_from_mem;
wire  [ 3:0]  ld_width_from_mem;
wire          is_st_b_from_mem;
wire          is_st_h_from_mem;
wire  [13:0]  csr_num_from_mem;
wire          csr_we_from_mem;
wire  [31:0]  csr_wmask_from_mem;
wire          ertn_flush_from_mem;
wire          is_csr_op_from_mem;
wire          is_ld_from_mem;
wire          is_st_from_mem;
wire  [31:0]  data_sram_addr_from_mem;
wire          need_nop_from_mem;
wire          inst_tlbsrch_from_mem;
wire  [4:0]   rd_from_mem;
wire          inst_invtlb_from_mem;
wire  [31:0]  rj_value_from_mem;
wire          inst_tlbwr_from_mem;
wire          inst_tlbrd_from_mem;
wire          is_cacop_from_mem;
wire  [31:0]  cacop_va_from_mem;
wire          is_cpucfg_from_mem;
wire  [31:0]  inst_from_mem;
wire          is_cntinst_from_mem;
wire  [31:0]  st_vaddr_from_mem;
wire  [31:0]  st_paddr_from_mem;
wire  [31:0]  st_data_from_mem;
wire  [31:0]  ld_vaddr_from_mem;
wire          is_ll_w_from_mem;
wire          is_sc_w_from_mem;
wire  [ 5:0]  dif_ld_info_from_mem;
wire          ll_w_cached_from_mem;
wire          inst_tlbfill_from_mem;

wire  [ 3:0]  temp_data_sram_wstrb;

wire  [ 2:0]  rf_wdata_sel_from_wb;
wire          rf_we_from_wb;
wire  [ 4:0]  rf_waddr_from_wb;
wire  [31:0]  pc_plus4_from_wb;
wire  [31:0]  data_sram_addr_from_wb;
wire  [13:0]  csr_num_from_wb;
wire          csr_we_from_wb;
wire  [31:0]  csr_wmask_from_wb;
wire  [31:0]  rkd_value_from_wb;
wire          ertn_flush_from_wb;
wire          inst_tlbsrch_from_wb;
wire  [4:0]   rd_from_wb;
wire          inst_invtlb_from_wb;
wire  [31:0]  rj_value_from_wb;
wire          inst_tlbwr_from_wb;
wire          inst_tlbrd_from_wb;
wire          is_cacop_from_wb;
wire  [31:0]  cacop_va_from_wb;
wire          is_ld_from_wb;
wire  [31:0]  inst_from_wb;
wire          is_cntinst_from_wb;
wire          is_csr_op_from_wb;
wire          is_st_from_wb;
wire          is_st_b_from_wb;
wire          is_st_h_from_wb;
wire  [31:0]  st_vaddr_from_wb;
wire  [31:0]  st_paddr_from_wb;
wire  [31:0]  st_data_from_wb;
wire  [31:0]  ld_vaddr_from_wb;
wire          is_ll_w_from_wb;
wire          is_sc_w_from_wb;
wire  [ 5:0]  dif_ld_info_from_wb;
wire          ll_w_cached_from_wb;
wire          inst_tlbfill_from_wb;

wire  [31:0]  rf_wdata_from_mem;
wire  [31:0]  rf_wdata_from_wb;
wire  [31:0]  rf_wdata;

wire          have_int;

// xx_ex_info : {Ecode , EsubCode , have_ex}, total 16 bits
wire  [15:0]  pre_if_ex_info;
wire  [15:0]  if_ex_info;
wire  [15:0]  id_ex_info;
wire  [15:0]  ex_ex_info;
wire  [15:0]  mem_ex_info;
wire  [15:0]  wb_ex_info;

wire  [15:0]  new_if_ex_info;
wire  [15:0]  new_id_ex_info;
wire  [15:0]  new_ex_ex_info;

// xx_badv_info ：two bits，高位为 1 表示已有记录，低位为 1 表示异常需要记录的是 pc
wire  [ 1:0]  pre_if_badv_info;
wire  [ 1:0]  if_badv_info;
wire  [ 1:0]  id_badv_info;
wire  [ 1:0]  ex_badv_info;
wire  [ 1:0]  mem_badv_info;
wire  [ 1:0]  wb_badv_info;

wire  [ 1:0]  new_if_badv_info;
wire  [ 1:0]  new_id_badv_info;
wire  [ 1:0]  new_ex_badv_info;

wire          adef_ex;
wire          sys_ex;
wire          brk_ex;
wire          ine_ex;
wire          ale_ex;
wire          tlbr_ex0;
wire          tlbr_ex1;
wire          pif_ex;
wire          pil_ex;
wire          pis_ex;
wire          ppi_ex0;
wire          ppi_ex1;
wire          pme_ex;  

// xx reg fire
wire          if_fire;
wire          id_fire;
wire          ex_fire;
wire          mem_fire;
wire          wb_fire;

// xx stage ready_go
wire          pre_if_ready_go;
wire          if_ready_go;
wire          id_ready_go;
wire          ex_ready_go;
wire          mem_ready_go;

// xx stage allowin
wire          if_allowin;
wire          id_allowin;
wire          mem_allowin;

// xx stage valid
wire          if_valid;
wire          id_valid;
wire          ex_valid;
wire          mem_valid;
wire          wb_valid;

reg           data_sram_req_r;

wire          ll_sc_addr_eq;

wire          write_buffer_empty;

wire [31:0]   asid;
wire [31:0]   tlbehi;
wire [31:0]   tlbelo0;
wire [31:0]   tlbelo1;
wire [31:0]   tlbidx;
wire [31:0]   estat;
wire          crmd_da;
wire          crmd_pg;
wire [ 1:0]   crmd_plv;
wire [ 1:0]   crmd_datf;
wire [ 1:0]   crmd_datm;
wire [31:0]   dmw0;
wire [31:0]   dmw1;
wire [31:0]   eentry;
wire [31:0]   tlbrentry;
wire          llbit;
wire [63:0]   stable_cnt;

wire [19:0] s0_va_20;
wire        s0_found;
wire [4:0]  s0_index;
wire [19:0] s0_ppn;
wire [5:0]  s0_ps;
wire [1:0]  s0_plv;
wire [1:0]  s0_mat;
wire        s0_d;
wire        s0_v;

wire        s1_found;
wire [4:0]  s1_index;
wire [19:0] s1_ppn;
wire [5:0]  s1_ps;
wire [1:0]  s1_plv;
wire [1:0]  s1_mat;
wire        s1_d;
wire        s1_v;

wire        s2_found;
wire [4:0]  s2_index;

wire        r_e;
wire [18:0] r_vppn;
wire [5:0]  r_ps;
wire [9:0]  r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [1:0]  r_plv0;
wire [1:0]  r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [1:0]  r_plv1;
wire [1:0]  r_mat1;
wire        r_d1;
wire        r_v1;

wire        new_refetch_flag;
wire        refetch_flush;

// Ecode      
parameter ECODE_INT    = 6'h00;
parameter ESUBCODE_INT = 9'h00;
parameter ECODE_PIL    = 6'h01;
parameter ECODE_PIS    = 6'h02;
parameter ECODE_PIF    = 6'h03;
parameter ECODE_PME    = 6'h04;
parameter ECODE_PPI    = 6'h07;
parameter ECODE_ADE    = 6'h08;   
parameter ECODE_ALE    = 6'h09;   
parameter ECODE_SYS    = 6'h0b;   
parameter ECODE_BRK    = 6'h0c;   
parameter ECODE_INE    = 6'h0d;   
parameter ECODE_IPE    = 6'h0e; 
parameter ECODE_TLBR   = 6'h3f;

wire          data_rd_rdy;
wire          data_wr_rdy;
wire          data_ret_valid;

wire [ 1:0]   inst_access_type;
wire [ 1:0]   data_access_type;

wire        icache_cacop_finish;
wire        icache_addr_ok;
wire        icache_data_ok;
wire [31:0] icache_rdata;

wire        icache_rd_req;
wire [ 2:0] icache_rd_type;
wire [31:0] icache_rd_addr;
wire        icache_rd_rdy;
wire        icache_ret_valid;
wire        icache_ret_last;
wire [31:0] icache_ret_data;

wire         icache_wr_req;
wire [  2:0] icache_wr_type;
wire [ 31:0] icache_wr_addr;
wire [  3:0] icache_wr_wstrb;
wire [127:0] icache_wr_data;
wire         icache_wr_rdy;

wire        dcache_suc_flag;

wire        dcache_cacop_finish;
wire        dcache_addr_ok;
wire        dcache_data_ok;
wire [31:0] dcache_rdata;

wire        dcache_rd_req;
wire [ 2:0] dcache_rd_type;
wire [31:0] dcache_rd_addr;
wire        dcache_rd_rdy;
wire        dcache_ret_valid;
wire        dcache_ret_last;
wire [31:0] dcache_ret_data;

wire         dcache_wr_req;
wire [  2:0] dcache_wr_type;
wire [ 31:0] dcache_wr_addr;
wire [  3:0] dcache_wr_wstrb;
wire [127:0] dcache_wr_data;
wire         dcache_wr_rdy;

reg          bar_flag;
reg          refetch_flag;
reg          idle_flag;
reg          br_calc_finish;

assign have_any_flush = (ertn_flush_from_wb || real_br_taken || wb_ex_info[0] || refetch_flush);

// AXI
axi_bridge u_axi_bridge(
    .clk            (aclk           ),//in
    .reset          (reset          ),//

    .arid           (arid           ),
    .araddr         (araddr         ),
    .arlen          (arlen          ),
    .arsize         (arsize         ),
    .arburst        (arburst        ),
    .arlock         (arlock         ),
    .arcache        (arcache        ),
    .arprot         (arprot         ),
    .arvalid        (arvalid        ),    
    .arready        (arready        ),//
                        
    .rid            (rid            ),//
    .rdata          (rdata          ),//
    .rresp          (rresp          ),//
    .rlast          (rlast          ),//
    .rvalid         (rvalid         ),//
    .rready         (rready         ),
                                
    .awid           (awid           ),
    .awaddr         (awaddr         ),
    .awlen          (awlen          ),
    .awsize         (awsize         ),
    .awburst        (awburst        ),
    .awlock         (awlock         ),
    .awcache        (awcache        ),
    .awprot         (awprot         ), 
    .awvalid        (awvalid        ),
    .awready        (awready        ),//
                                
    .wid            (wid            ),
    .wdata          (wdata          ),
    .wstrb          (wstrb          ),
    .wlast          (wlast          ),
    .wvalid         (wvalid         ),
    .wready         (wready         ),//
                                    
    .bid            (bid            ),//
    .bresp          (bresp          ),//
    .bvalid         (bvalid         ),//
    .bready         (bready         ),
    
    .inst_rd_req    (icache_rd_req    ),//in  
    .inst_rd_type   (icache_rd_type   ),// 
    .inst_rd_addr   (icache_rd_addr   ),//
    .inst_rd_rdy    (icache_rd_rdy    ),
    .inst_ret_valid (icache_ret_valid ),
    .inst_ret_last  (icache_ret_last  ),
    .inst_ret_data  (icache_ret_data  ),
    .inst_wr_req    (icache_wr_req    ),//
    .inst_wr_type   (icache_wr_type   ),//
    .inst_wr_addr   (icache_wr_addr   ),//
    .inst_wr_wstrb  (icache_wr_wstrb  ),//
    .inst_wr_data   (icache_wr_data   ),//
    .inst_wr_rdy    (icache_wr_rdy    ),

    .data_rd_req    (dcache_rd_req    ),//  
    .data_rd_type   (dcache_rd_type   ),// 
    .data_rd_addr   (dcache_rd_addr   ),//
    .data_rd_rdy    (dcache_rd_rdy    ),
    .data_ret_valid (dcache_ret_valid ),
    .data_ret_last  (dcache_ret_last  ),
    .data_ret_data  (dcache_ret_data  ),  
    .data_wr_req    (dcache_wr_req    ),//  
    .data_wr_type   (dcache_wr_type   ),//
    .data_wr_addr   (dcache_wr_addr   ),//
    .data_wr_wstrb  (dcache_wr_wstrb  ),//
    .data_wr_data   (dcache_wr_data   ),//
    .data_wr_rdy    (dcache_wr_rdy    ),

    .write_buffer_empty (write_buffer_empty)
);

wire [31:0] icacop_pa_from_ex;
wire [31:0] dcacop_pa_from_ex;
wire [31:0] icacop_pa_from_mem;
wire [31:0] dcacop_pa_from_mem;
wire [31:0] icacop_pa_from_wb;
wire [31:0] dcacop_pa_from_wb;

wire        disable_cache;
wire        icache_idle;
wire        dcache_idle;

wire        icache_cacop = wb_valid && is_cacop_from_wb && rd_from_wb[2:0]==3'b000;
wire        icache_valid = inst_sram_req || (icache_cacop && !wb_ex_info[0]);
wire [31:0] icache_vaddr = (icache_cacop && rd_from_wb[4:3]==2'b10)? cacop_va_from_wb : pc;
wire [31:0] icache_paddr = (icache_cacop && rd_from_wb[4:3]==2'b10)? icacop_pa_from_wb : inst_paddr;

wire [ 7:0] icache_index = icache_vaddr[11:4];
wire [19:0] icache_tag = icache_paddr[31:12];
wire [ 3:0] icache_offset = icache_vaddr[3:0];

wire        dcache_cacop = wb_valid && is_cacop_from_wb && rd_from_wb[2:0]==3'b001;
wire        dcache_valid = data_sram_req || (dcache_cacop && !wb_ex_info[0]);
wire [31:0] dcache_vaddr = (dcache_cacop && rd_from_wb[4:3]==2'b10)? cacop_va_from_wb : alu_result_from_ex;
wire [31:0] dcache_paddr = (dcache_cacop && rd_from_wb[4:3]==2'b10)? dcacop_pa_from_wb : data_paddr_from_ex;
wire [ 7:0] dcache_index = dcache_vaddr[11:4];
wire [19:0] dcache_tag = dcache_paddr[31:12];
wire [ 3:0] dcache_offset = dcache_vaddr[3:0];

icache u_icache(
    .clk    (aclk   ), // in
    .resetn (aresetn), //

    // CPU
    .valid  (icache_valid  ), //
    .op     (1'b0          ), // 只读
    .index  (icache_index  ), //
    .tag    (icache_tag    ), //
    .offset (icache_offset ), //
    .wstrb  (4'b0000       ), //
    .wdata  (32'b0         ), //

    .ibar_clear (inst_ibar && id_valid),

    .addr_ok    (inst_sram_addr_ok ),
    .data_ok    (inst_sram_data_ok ),
    .rdata      (inst_sram_rdata   ),

    .cacop_finish(icache_cacop_finish),
    .state_idle (icache_idle       ),

    .access_type(inst_access_type  ),
    .crmd_dat   (crmd_datf         ),
    .dmw0       (dmw0              ),
    .dmw1       (dmw1              ),
    .tlb_mat    (s0_mat            ),
    //.disable_cache (disable_cache  ),
    .disable_cache (1'b0),

    .cacop_flag (wb_valid && is_cacop_from_wb 
                 && !wb_ex_info[0] ),
    .cacop_code (rd_from_wb        ),
    .cacop_va   (cacop_va_from_wb  ),

    // AXI
    .rd_req     (icache_rd_req    ),
    .rd_type    (icache_rd_type   ),
    .rd_addr    (icache_rd_addr   ),
    .rd_rdy     (icache_rd_rdy    ), // in
    .ret_valid  (icache_ret_valid ), //
    .ret_last   (icache_ret_last  ), //
    .ret_data   (icache_ret_data  ), //

    .wr_req     (icache_wr_req    ),
    .wr_type    (icache_wr_type   ),
    .wr_addr    (icache_wr_addr   ),
    .wr_wstrb   (icache_wr_wstrb  ),
    .wr_data    (icache_wr_data   ),
    .wr_rdy     (icache_wr_rdy    )  //
);

reg [1:0] s1_mat_r;
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        s1_mat_r <= 2'b0;
    end
    else if (ertn_flush_from_wb || wb_ex_info[0] || refetch_flush) begin
        s1_mat_r <= 2'b0;
    end
    else if (ex_fire) begin
        s1_mat_r <= s1_mat;
    end
end

wire [2:0] dcache_size = ({3{data_sram_wr && is_st_b_from_ex}}                                                & 3'b000) |
                         ({3{data_sram_wr && is_st_h_from_ex}}                                                & 3'b001) |
                         ({3{data_sram_wr && !(is_st_b_from_ex || is_st_h_from_ex)}}                          & 3'b010) |
                         ({3{~data_sram_wr && (ld_width_from_ex == 4'b0001)}}                                 & 3'b000) |
                         ({3{~data_sram_wr && (ld_width_from_ex == 4'b0011)}}                                 & 3'b001) |
                         ({3{~data_sram_wr && !(ld_width_from_ex == 4'b0001 || ld_width_from_ex == 4'b0011)}} & 3'b010);

dcache u_dcache(
    .clk    (aclk   ), // in
    .resetn (aresetn), //

    // CPU
    .valid  (dcache_valid    ), //
    .op     (data_sram_wr    ), // 
    .size   (dcache_size     ), //
    .index  (dcache_index    ), //
    .tag    (dcache_tag      ), //
    .offset (dcache_offset   ), //
    .wstrb  (data_sram_wstrb ), //
    .wdata  (data_sram_wdata ), //

    .bvalid (bvalid          ),
    .inst_bar (inst_dbar | inst_ibar),

    .suc_flag   (dcache_suc_flag    ),

    .addr_ok    (data_sram_addr_ok  ),
    .data_ok    (data_sram_data_ok  ),
    .rdata      (data_sram_rdata    ),
    
    .cacop_finish(dcache_cacop_finish),
    .state_idle (dcache_idle       ),

    .access_type(data_access_type  ),
    .crmd_dat   (crmd_datm         ),
    .dmw0       (dmw0              ),
    .dmw1       (dmw1              ),
    .tlb_mat    (s1_mat_r          ),
    //.disable_cache (disable_cache  ),
    .disable_cache (1'b0),

    .cacop_flag (wb_valid && is_cacop_from_wb
                 && !wb_ex_info[0] ),
    .cacop_code (rd_from_wb        ),
    .cacop_va   (cacop_va_from_wb  ),

    // AXI
    .rd_req     (dcache_rd_req    ),
    .rd_type    (dcache_rd_type   ),
    .rd_addr    (dcache_rd_addr   ),
    .rd_rdy     (dcache_rd_rdy    ), // in
    .ret_valid  (dcache_ret_valid ), //
    .ret_last   (dcache_ret_last  ), //
    .ret_data   (dcache_ret_data  ), //

    .wr_req     (dcache_wr_req    ),
    .wr_type    (dcache_wr_type   ),
    .wr_addr    (dcache_wr_addr   ),
    .wr_wstrb   (dcache_wr_wstrb  ),
    .wr_data    (dcache_wr_data   ),
    .wr_rdy     (dcache_wr_rdy    )  //
);

// MMU
mmu u_mmu(
    .clk           (aclk               ),
    .reset         (reset              ),
    .ertn_flush    (ertn_flush_from_wb ),
    .ex_flush      (wb_ex_info[0]      ),
    .refetch_flush (refetch_flush      ),

    .crmd_da    (crmd_da    ),
    .crmd_pg    (crmd_pg    ),
    .crmd_plv   (crmd_plv   ),
    .dmw0       (dmw0       ),
    .dmw1       (dmw1       ),

    .s0_found   (s0_found   ),
    .s0_ppn     (s0_ppn     ),
    .s0_ps      (s0_ps      ),
    .s0_plv     (s0_plv     ),
    .s0_mat     (s0_mat     ),
    .s0_d       (s0_d       ),
    .s0_v       (s0_v       ),

    .s1_found   (s1_found   ),
    .s1_ppn     (s1_ppn     ),
    .s1_ps      (s1_ps      ),
    .s1_plv     (s1_plv     ),
    .s1_mat     (s1_mat     ), // 没用
    .s1_d       (s1_d       ),
    .s1_v       (s1_v       ),  

    .inst_st    (is_st      ),
    .inst_ld    (is_ld || (inst_cacop && rd[4:3]==2'b10)),
    .id_valid   (id_valid   ),
    .ex_fire    (ex_fire    ),

    .inst_vaddr (pc              ), 
    .data_vaddr (addr_alu_result ), 

    .inst_paddr (inst_paddr ),
    .data_paddr (data_paddr ),

    .tlbr_ex0   (tlbr_ex0   ),
    .tlbr_ex1   (tlbr_ex1   ),
    .pif_ex     (pif_ex     ),
    .pil_ex     (pil_ex     ),
    .pis_ex     (pis_ex     ),
    .ppi_ex0    (ppi_ex0    ),
    .ppi_ex1    (ppi_ex1    ),
    .pme_ex     (pme_ex     ),
    
    .inst_access_type (inst_access_type),
    .data_access_type (data_access_type)
);

always@(posedge aclk or posedge reset) begin
    if (reset) begin
        data_sram_req_r <= 1'b0;
    end
    else if (mem_fire) begin
        data_sram_req_r <= data_sram_req;
    end
end

// inst_sram_rdata 来的时候如果 ID_reg 不 fire，把它暂存下来
reg        inst_sram_data_ok_r;
reg [31:0] inst_sram_rdata_r;
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        inst_sram_rdata_r <= 32'b0;
    end
    else if (inst_sram_data_ok) begin
        inst_sram_rdata_r <= inst_sram_rdata;
    end
end
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        inst_sram_data_ok_r <= 1'b0;
    end
    else if (have_any_flush) begin
        inst_sram_data_ok_r <= 1'b0; 
    end
    else if (if_fire) begin
        inst_sram_data_ok_r <= 1'b0;
    end
    else if (if_valid && inst_sram_data_ok && !id_fire) begin
        inst_sram_data_ok_r <= 1'b1;
    end
end

assign  inst_sram_req   = if_allowin && pc_ready && (pc[31:12] == s0_va_20) && (!pre_if_ex_info[0]) && (!refetch_flag) && (!new_refetch_flag);  // 注意 llw 和 scw
assign  inst_sram_addr  = inst_paddr;

// XX stage ready go
wire    pre_if_ready_go_normal    = pc_ready && inst_sram_req && inst_sram_addr_ok;      // 正常取指ready
wire    pre_if_ready_go_exception = pc_ready && pre_if_ex_info[0] && (pc[31:12] == s0_va_20) && inst_sram_addr_ok;  // 异常强制ready
assign  pre_if_ready_go           = pre_if_ready_go_normal || pre_if_ready_go_exception;

wire    if_ready_go_normal    = if_valid && (inst_sram_data_ok || inst_sram_data_ok_r);
wire    if_ready_go_exception = if_valid && new_if_ex_info[0];
assign  if_ready_go           = if_ready_go_normal || if_ready_go_exception;  

assign  id_ready_go        = id_valid && (addr_alu_finish || !need_addr_alu) && (br_calc_finish || !inst_branch) && (!refetch_flag);

wire    ex_is_mem_op  = ex_valid && (is_ld_from_ex || is_st_from_ex);
wire    ex_mem_ready  = (data_sram_req && data_sram_addr_ok) || new_ex_ex_info[0] || (is_sc_w_from_ex && !(llbit && ll_sc_addr_eq));
wire    ex_calc_ready = ex_valid && execute_finish;
assign  ex_ready_go   = ex_is_mem_op ? ex_mem_ready : ex_calc_ready;

wire    mem_is_cacop  = mem_valid && is_cacop_from_mem;
wire    can_do_cacop  = icache_idle && dcache_idle;
assign  mem_ready_go  = mem_valid && (!data_sram_req_r || data_sram_data_ok) && (!mem_is_cacop || can_do_cacop) ;

// PC
pc_unit u_pc_unit(
    .clk                  (aclk                 ),
    .reset                (reset                ),
    .if_fire              (if_fire              ),
    .need_nop             (need_nop             ),
    .br_taken             (real_br_taken        ),
    .br_target            (br_target            ),
    .ertn_flush_from_wb   (ertn_flush_from_wb   ),
    .pc_from_era          (pc_from_era          ),
    .wb_ex_info           (wb_ex_info           ),
    .eentry               (eentry               ),
    .tlbrentry            (tlbrentry            ),
    .info_from_bp         (bp_info_to_pc        ),

    .refetch_flush        (refetch_flush        ),
    .pc_from_id           (pc_plus4_from_id - 4 ),
    .pc_from_if           (pc_from_if           ),
    .id_valid             (id_valid             ),
    .if_valid             (if_valid             ),

    .pc                   (pc                   ),
    .pc_ready             (pc_ready             )
);

reg bp_update_en, bp_add_entry, bp_pre_error, bp_pre_right, bp_target_error, bp_pop_ras, bp_push_ras, bp_br_taken;    
reg [4:0] bp_update_index;
reg [29:0] bp_update_pc, bp_br_target;
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        bp_update_en    <= 1'b0;
        bp_add_entry    <= 1'b0;
        bp_pre_error    <= 1'b0;
        bp_pre_right    <= 1'b0;
        bp_target_error <= 1'b0;
        bp_update_index <= 5'b0;
        bp_update_pc    <= 30'b0;
        bp_pop_ras      <= 1'b0;
        bp_push_ras     <= 1'b0;
        bp_br_taken     <= 1'b0;
        bp_br_target    <= 30'b0;
    end
    else begin
        bp_update_en    <= inst_branch &&  ex_fire;
        bp_add_entry    <= inst_branch && !bp_ret_en_from_id &&  br_taken;
        bp_pre_error    <= inst_branch &&  bp_ret_en_from_id && |(br_taken ^ bp_taken_from_id);
        bp_pre_right    <= inst_branch &&  bp_ret_en_from_id && (br_taken == bp_taken_from_id);
        bp_target_error <= inst_branch &&  bp_ret_en_from_id &&  br_taken && bp_taken_from_id && |(bp_ret_pc_from_id ^ br_target[31:2]);
        bp_update_index <= bp_ret_index_from_id;
        bp_update_pc    <= ID_pc[31:2];
        bp_pop_ras      <= inst_jirl;
        bp_push_ras     <= inst_bl;
        bp_br_target    <= br_target[31:2];
        bp_br_taken     <= br_taken;
    end
end

// branch predictor
branchPredictor u_branchPredictor(
    .clk                    (aclk                   ),
    .reset                  (reset                  ),

    .fetch_pc               (pc[31:2]               ),
    .fetch_en               (if_fire                ),

    .update_en              (bp_update_en           ),
    .update_index           (bp_update_index        ),
    .id_pc                  (bp_update_pc           ),
    .id_push_ras            (bp_push_ras            ),
    .id_pop_ras             (bp_pop_ras             ),
    .id_need_add_entry      (bp_add_entry           ),
    .id_need_delete_entry   (1'b0                   ),
    .id_pre_error           (bp_pre_error           ),
    .id_pre_right           (bp_pre_right           ),
    .id_target_error        (bp_target_error        ),
    .id_br_target           (bp_br_target           ),
    .id_br_taken            (bp_br_taken            ),

    .ret_en                 (bp_ret_en              ),
    .ret_pc                 (bp_ret_pc              ),
    .taken                  (bp_taken               ),
    .ret_index              (bp_ret_index           ),
    .info_to_pc             (bp_info_to_pc          )
);

assign adef_ex = |(pc[1:0] ^ 2'b00); 

assign pre_if_badv_info = (adef_ex || tlbr_ex0 || pif_ex || ppi_ex0)? 2'b11 : 2'b00;
assign pre_if_ex_info = (adef_ex )? {ECODE_ADE, 9'b0, 1'b1} :
                        (tlbr_ex0)? {ECODE_TLBR,9'b0, 1'b1} :
                        (pif_ex  )? {ECODE_PIF, 9'b0, 1'b1} :
                        (ppi_ex0 )? {ECODE_PPI, 9'b0, 1'b1} : 16'b0;

// IF reg
if_reg u_if_reg(
    .clk             (aclk               ),
    .reset           (reset             ),
    .ertn_flush      (ertn_flush_from_wb),
    .ex_flush        (wb_ex_info[0]     ),
    .br_flush        (real_br_taken     ),
    .refetch_flush   (refetch_flush     ),
    .stall           (need_nop          ),

    .pre_if_ready_go (pre_if_ready_go   ),

    .pc_in           (pc                ),
    .ex_info_in      (pre_if_ex_info    ),
    .badv_info_in    (pre_if_badv_info  ),

    .pc_out          (pc_from_if        ),
    .ex_info_out     (if_ex_info        ),
    .badv_info_out   (if_badv_info      ),

    .id_fire         (id_fire           ),
    .if_fire         (if_fire           ),
    .if_allowin      (if_allowin        ),
    .if_valid        (if_valid          )
);

assign new_if_badv_info = if_badv_info;
assign new_if_ex_info = if_ex_info;

// decoder
decoder u_decoder(
    .inst_in        (inst_sram_data_ok_r ? 
                     inst_sram_rdata_r   : 
                     inst_sram_rdata       ), 
    .pc             (pc_from_if            ),
    .crmd_plv       (crmd_plv              ),

    .alu_op         (p_alu_op              ),
    .src1_is_pc     (p_src1_is_pc          ),
    .imm            (p_imm                 ),
    .src2_is_imm    (p_src2_is_imm         ),
    .rd             (p_rd                  ),
    .rj             (p_rj                  ),
    .rk             (p_rk                  ),
    .data_sram_we   (p_data_sram_we        ),
    .rf_wdata_sel   (p_rf_wdata_sel        ),
    .rf_we          (p_rf_we               ),
    .rf_waddr       (p_rf_waddr            ),
    .src_reg_is_rd  (p_src_reg_is_rd       ),
    .ex_result_sel  (p_ex_result_sel       ),
    .mmd_is_signed  (p_mmd_is_signed       ),
    .mul_need_hi    (p_mul_need_hi         ), 
    .ld_ext_is_signed(p_ld_ext_is_signed   ),
    .ld_width       (p_ld_width            ),  
    .csr_we         (p_csr_we              ),
    .is_csr_op      (p_is_csr_op           ),
    .new_refetch_flag (p_new_refetch_flag  ),
    .dif_ld_info    (p_dif_ld_info         ),
    .ipe_ex         (p_ipe_ex              ),
    .need_addr_alu  (p_need_addr_alu       ),

    .i12            (p_i12                 ),
    .i20            (p_i20                 ),
    .i16            (p_i16                 ),
    .i26            (p_i26                 ),
    .ui5            (p_ui5                 ),
    .csr_num        (p_csr_num             ),

    .is_ld          (p_is_ld               ),   
    .is_st          (p_is_st               ), 
    .inst_b         (p_inst_b              ),
    .inst_beq       (p_inst_beq            ),
    .inst_bne       (p_inst_bne            ),
    .inst_bl        (p_inst_bl             ),
    .inst_jirl      (p_inst_jirl           ),
    .inst_blt       (p_inst_blt            ),
    .inst_bltu      (p_inst_bltu           ),
    .inst_bge       (p_inst_bge            ),
    .inst_bgeu      (p_inst_bgeu           ),
    .inst_st_b      (p_inst_st_b           ),
    .inst_st_h      (p_inst_st_h           ),
    .inst_csrxchg   (p_inst_csrxchg        ),
    .inst_ertn      (p_inst_ertn           ),
    .inst_syscall   (p_sys_ex              ),
    .inst_break     (p_brk_ex              ),
    .inst_tlbsrch   (p_inst_tlbsrch        ),
    .inst_invtlb    (p_inst_invtlb         ),
    .inst_tlbwr     (p_inst_tlbwr          ),
    .inst_tlbrd     (p_inst_tlbrd          ),
    .inst_cacop     (p_inst_cacop          ),
    .cacop_code     (p_cacop_code          ),
    .inst_cpucfg    (p_inst_cpucfg         ),
    .is_cntinst     (p_is_cntinst          ),
    .inst_ll_w      (p_inst_ll_w           ),
    .inst_sc_w      (p_inst_sc_w           ),
    .inst_ibar      (p_inst_ibar           ),
    .inst_dbar      (p_inst_dbar           ),
    .inst_branch    (p_inst_branch         ),
    .inst_tlbfill   (p_inst_tlbfill        ),
    .inst_idle      (p_inst_idle           ),
    .not_inst       (p_ine_ex              )
);

// ID reg
id_reg u_id_reg (
    .clk          (aclk                     ),
    .reset        (reset                    ),

    .ertn_flush   (ertn_flush_from_wb       ),
    .br_flush     (real_br_taken            ),
    .ex_flush     (wb_ex_info[0]            ),
    .refetch_flush(refetch_flush            ),
    .stall        (need_nop                 ),

    .if_ready_go  (if_ready_go              ),

    .pc_plus4_in        (pc_from_if + 4           ), 
    .inst_in            (inst_sram_data_ok_r ? 
                         inst_sram_rdata_r   : 
                         inst_sram_rdata          ),
    .ex_info_in         (new_if_ex_info           ),
    .badv_info_in       (new_if_badv_info         ),
    .bp_ret_en_in       (bp_ret_en                ),
    .bp_ret_pc_in       (bp_ret_pc                ),
    .bp_taken_in        (bp_taken                 ),
    .bp_ret_index_in    (bp_ret_index           ),
    .alu_op_in          (p_alu_op),
    .src1_is_pc_in      (p_src1_is_pc),
    .imm_in             (p_imm),
    .src2_is_imm_in     (p_src2_is_imm),
    .rd_in              (p_rd),
    .rj_in              (p_rj),
    .rk_in              (p_rk),
    .data_sram_we_in    (p_data_sram_we),
    .rf_wdata_sel_in    (p_rf_wdata_sel),
    .rf_we_in           (p_rf_we),
    .rf_waddr_in        (p_rf_waddr),
    .src_reg_is_rd_in   (p_src_reg_is_rd),
    .ex_result_sel_in   (p_ex_result_sel),
    .mmd_is_signed_in   (p_mmd_is_signed),
    .mul_need_hi_in     (p_mul_need_hi),
    .ld_ext_is_signed_in(p_ld_ext_is_signed),
    .ld_width_in        (p_ld_width),
    .csr_we_in          (p_csr_we),
    .is_csr_op_in       (p_is_csr_op),
    .new_refetch_flag_in(p_new_refetch_flag),
    .dif_ld_info_in     (p_dif_ld_info),
    .ipe_ex_in          (p_ipe_ex),
    .inst_branch_in     (p_inst_branch),
    .i12_in             (p_i12),
    .i20_in             (p_i20),
    .i16_in             (p_i16),
    .i26_in             (p_i26),
    .ui5_in             (p_ui5),
    .csr_num_in         (p_csr_num),
    .is_ld_in           (p_is_ld),
    .is_st_in           (p_is_st),
    .inst_st_b_in       (p_inst_st_b),
    .inst_st_h_in       (p_inst_st_h),
    .is_cntinst_in      (p_is_cntinst),
    .inst_jirl_in       (p_inst_jirl),
    .inst_b_in          (p_inst_b),
    .inst_bl_in         (p_inst_bl),
    .inst_beq_in        (p_inst_beq),
    .inst_bne_in        (p_inst_bne),
    .inst_blt_in        (p_inst_blt),
    .inst_bge_in        (p_inst_bge),
    .inst_bltu_in       (p_inst_bltu),
    .inst_bgeu_in       (p_inst_bgeu),
    .inst_csrxchg_in    (p_inst_csrxchg),
    .inst_ertn_in       (p_inst_ertn),
    .inst_syscall_in    (p_sys_ex),
    .inst_break_in      (p_brk_ex),
    .inst_tlbsrch_in    (p_inst_tlbsrch),
    .inst_invtlb_in     (p_inst_invtlb),
    .inst_tlbwr_in      (p_inst_tlbwr),
    .inst_tlbrd_in      (p_inst_tlbrd),
    .inst_cacop_in      (p_inst_cacop),
    .inst_cpucfg_in     (p_inst_cpucfg),
    .inst_ll_w_in       (p_inst_ll_w),
    .inst_sc_w_in       (p_inst_sc_w),
    .inst_ibar_in       (p_inst_ibar),
    .inst_tlbfill_in    (p_inst_tlbfill),
    .cacop_code_in      (p_cacop_code),
    .not_inst_in        (p_ine_ex),
    .inst_idle_in       (p_inst_idle),
    .need_addr_alu_in   (p_need_addr_alu),
    .inst_dbar_in       (p_inst_dbar),

    .pc_plus4_out       (pc_plus4_from_id         ),
    .inst_out           (inst_from_id             ),
    .ex_info_out        (id_ex_info               ),
    .badv_info_out      (id_badv_info             ),
    .bp_ret_en_out      (bp_ret_en_from_id        ),
    .bp_ret_pc_out      (bp_ret_pc_from_id        ),
    .bp_taken_out       (bp_taken_from_id         ),
    .bp_ret_index_out   (bp_ret_index_from_id  ),
    .alu_op_out         (alu_op),
    .src1_is_pc_out     (src1_is_pc),
    .imm_out            (imm),
    .src2_is_imm_out    (src2_is_imm),
    .rd_out             (rd),
    .rj_out             (rj),
    .rk_out             (rk),
    .data_sram_we_out   (data_sram_we_from_id),
    .rf_wdata_sel_out   (rf_wdata_sel),
    .rf_we_out          (rf_we),
    .rf_waddr_out       (rf_waddr),
    .src_reg_is_rd_out  (src_reg_is_rd),
    .ex_result_sel_out  (ex_result_sel),
    .mmd_is_signed_out  (mmd_is_signed),
    .mul_need_hi_out    (mul_need_hi),
    .ld_ext_is_signed_out(ld_ext_is_signed),
    .ld_width_out       (ld_width),
    .csr_we_out         (csr_we),
    .is_csr_op_out      (is_csr_op),
    .new_refetch_flag_out(new_refetch_flag),
    .dif_ld_info_out    (dif_ld_info),
    .ipe_ex_out         (ipe_ex),
    .inst_branch_out    (inst_branch),
    .i12_out            (i12),
    .i20_out            (i20),
    .i16_out            (i16),
    .i26_out            (i26),
    .ui5_out            (ui5),
    .csr_num_out        (csr_num),
    .is_ld_out          (is_ld),
    .is_st_out          (t_is_st),
    .inst_st_b_out      (inst_st_b),
    .inst_st_h_out      (inst_st_h),
    .is_cntinst_out     (is_cntinst),
    .inst_jirl_out      (inst_jirl),
    .inst_b_out         (inst_b),
    .inst_bl_out        (inst_bl),
    .inst_beq_out       (inst_beq),
    .inst_bne_out       (inst_bne),
    .inst_blt_out       (inst_blt),
    .inst_bge_out       (inst_bge),
    .inst_bltu_out      (inst_bltu),
    .inst_bgeu_out      (inst_bgeu),
    .inst_csrxchg_out   (inst_csrxchg),
    .inst_ertn_out      (inst_ertn),
    .inst_syscall_out   (sys_ex),
    .inst_break_out     (brk_ex),
    .inst_tlbsrch_out   (inst_tlbsrch),
    .inst_invtlb_out    (inst_invtlb),
    .inst_tlbwr_out     (inst_tlbwr),
    .inst_tlbrd_out     (inst_tlbrd),
    .inst_cacop_out     (inst_cacop),
    .inst_cpucfg_out    (inst_cpucfg),
    .inst_ll_w_out      (inst_ll_w),
    .inst_sc_w_out      (inst_sc_w),
    .inst_ibar_out      (inst_ibar),
    .inst_tlbfill_out   (inst_tlbfill),
    .cacop_code_out     (cacop_code),
    .not_inst_out       (ine_ex),
    .inst_idle_out      (inst_idle),
    .need_addr_alu_out  (need_addr_alu),
    .inst_dbar_out      (inst_dbar),

    .ex_fire      (ex_fire                  ),
    .id_fire      (id_fire                  ),
    .id_allowin   (id_allowin               ),
    .id_valid     (id_valid                 )
);

assign is_st = (t_is_st && inst_sc_w)? llbit : t_is_st;

always @(posedge aclk or posedge reset) begin
    if (reset) begin
        refetch_flag <= 1'b0;
    end
    else if (have_any_flush) begin
        refetch_flag <= 1'b0;
    end
    else if (new_refetch_flag && ex_fire) begin
        refetch_flag <= 1'b1;
    end
end 

always @(posedge aclk or posedge reset) begin
    if (reset) begin
        idle_flag <= 1'b0;
    end
    else if (have_any_flush) begin
        idle_flag <= 1'b0;
    end
    else if (new_refetch_flag && ex_fire && inst_idle) begin
        idle_flag <= 1'b1;
    end
end

always @(posedge aclk or posedge reset) begin
    if (reset) begin
        bar_flag <= 1'b0;
    end
    else if (have_any_flush) begin
        bar_flag <= 1'b0;
    end
    else if ((inst_dbar | inst_ibar) && ex_fire) begin
        bar_flag <= 1'b1;
    end
end

assign new_id_badv_info = (have_int)? 2'b00 : id_badv_info;
assign new_id_ex_info = (!id_valid      )? 16'b0                   :    
                        (have_int       )? {ECODE_INT, 9'b0, 1'b1} :     
                        (id_ex_info[0]  )?  id_ex_info             : 
                        (sys_ex         )? {ECODE_SYS, 9'b0, 1'b1} :
                        (brk_ex         )? {ECODE_BRK, 9'b0, 1'b1} :
                        (ine_ex         )? {ECODE_INE, 9'b0, 1'b1} :
                        (ipe_ex         )? {ECODE_IPE, 9'b0, 1'b1} : 16'b0;

assign rf_raddr2 = src_reg_is_rd? rd : rk;

// Registers
regfile u_regfile(
    .clk       (aclk              ),
    .rf_raddr1 (rj                ),
    .rf_rdata1 (rj_value          ),
    .rf_raddr2 (rf_raddr2         ),
    .rf_rdata2 (rkd_value         ),
    .rf_we     (debug0_wb_rf_wen  ),
    .rf_waddr  (rf_waddr_from_wb  ),
    .rf_wdata  (rf_wdata          )
    `ifdef DIFFTEST_EN
    ,
    .regs      (regs              )
    `endif 
);

assign forwarding_from_ex  = (rf_wdata_sel_from_ex[1])?  pc_plus4_from_ex  : alu_result_from_ex;
assign forwarding_from_mem = (rf_wdata_sel_from_mem[1])? pc_plus4_from_mem : ex_result_from_mem;

always @(posedge aclk or posedge reset) begin
    if (reset) begin
        br_calc_finish <= 1'b0;
    end
    else begin
        br_calc_finish <= !id_fire && !need_nop ;
    end
end

// br_logic_unit
br_logic_unit u_br_logic_unit(
    .clk        (aclk                           ),
    .reset      (reset                          ),

    .stall      (need_nop                       ),
    .refetch_flag(refetch_flag                  ),
    .br_calc_finish (br_calc_finish             ),

    .inst_b     (inst_b                         ),
    .inst_bl    (inst_bl                        ),
    .inst_jirl  (inst_jirl                      ),
    .inst_beq   (inst_beq                       ),
    .inst_bne   (inst_bne                       ),
    .inst_blt   (inst_blt                       ),
    .inst_bltu  (inst_bltu                      ),
    .inst_bge   (inst_bge                       ),
    .inst_bgeu  (inst_bgeu                      ),
    .pc         (pc_plus4_from_id - 32'h00000004), 
    .imm        (imm                            ),
    .rj_value   (rj_value                       ),
    .rkd_value  (rkd_value                      ),

    .rj         (rj                             ),
    .rkd        (rf_raddr2                      ),

    .rf_waddr_from_ex(rf_waddr_from_ex          ),
    .rf_waddr_from_mem(rf_waddr_from_mem        ),
    .rf_waddr_from_wb(rf_waddr_from_wb          ),

    .rf_we_in_stage_ex(rf_we_from_ex            ),
    .rf_we_in_stage_mem(rf_we_from_mem          ),
    .rf_we_in_stage_wb(debug0_wb_rf_wen         ),

    .forwarding_from_ex(forwarding_from_ex      ),
    .forwarding_from_mem(forwarding_from_mem    ),
    .forwarding_from_wb(rf_wdata_from_wb        ), // 不含 csr

    .bp_ret_en  ( bp_ret_en_from_id             ),
    .bp_taken   ( bp_taken_from_id              ),
    .bp_ret_pc  ({bp_ret_pc_from_id, 2'b0}      ),

    .ex_valid   (ex_valid                       ),
    .mem_valid  (mem_valid                      ),
    .wb_valid   (wb_valid                       ),
    .ex_fire    (ex_fire                        ),

    .br_taken   (br_taken                       ),
    .real_br_taken (real_br_taken               ),
    .br_target  (br_target                      ),
    .r_rkd_value(r_rkd_value                    ),
    .r_rj_value (r_rj_value                     ),
    .need_ex_forward (need_ex_forward           )
);

alu u_alu(
    .alu_src1   (src1_is_pc? pc_plus4_from_id : r_rj_value),
    .alu_src2   (src2_is_imm? imm : r_rkd_value           ),
    .alu_op     (alu_op                                   ),
    .alu_result (alu_result                               )
);

addr_alu u_addr_alu(
    .clk             (aclk                  ),
    .reset           (reset                 ),
    .ertn_flush      (ertn_flush_from_wb    ),
    .ex_flush        (wb_ex_info[0]         ),
    .refetch_flush   (refetch_flush         ),
    .stall           (need_nop              ),
    .id_fire         (id_fire               ),
    .id_valid        (id_valid              ),

    .alu_src1   (src1_is_pc? pc_plus4_from_id : r_rj_value),
    .alu_src2   (src2_is_imm? imm : r_rkd_value           ),
    .alu_result (addr_alu_result                          ),
    .alu_finish (addr_alu_finish                          )
);

// EX reg
ex_reg u_ex_reg(
    .clk                (aclk                     ),
    .reset              (reset                    ),
    .ertn_flush         (ertn_flush_from_wb       ),
    .ex_flush           (wb_ex_info[0]            ),
    .refetch_flush      (refetch_flush            ),
    .br_taken           (real_br_taken            ),
    .stall              (need_nop                 ),

    .id_ready_go        (id_ready_go              ),

    .pc_plus4_in        (pc_plus4_from_id         ),
    .rj_value_in        (r_rj_value               ),
    .rd_in              (rd                       ),
    .rkd_value_in       (r_rkd_value              ),
    .data_sram_we_in    (data_sram_we_from_id     ),
    .rf_wdata_sel_in    (rf_wdata_sel             ),
    .rf_we_in           (rf_we                    ),
    .rf_waddr_in        (rf_waddr                 ),
    .is_ld_in           (is_ld                    ),
    .is_st_in           (is_st                    ),
    .data_sram_wdata_in (r_rkd_value              ),
    .ex_result_sel_in   (ex_result_sel            ),
    .mmd_is_signed_in   (mmd_is_signed            ),
    .mul_need_hi_in     (mul_need_hi              ),
    .ld_ext_is_signed_in(ld_ext_is_signed         ),
    .ld_width_in        (ld_width                 ),
    .is_st_b_in         (inst_st_b                ),
    .is_st_h_in         (inst_st_h                ),
    .csr_num_in         (csr_num                  ),
    .csr_we_in          (csr_we                   ),
    .csr_wmask_in       (inst_csrxchg ? 
                         r_rj_value   : 
                         32'hffffffff             ),
    .ertn_flush_in      (inst_ertn                ),
    .ex_info_in         (new_id_ex_info           ),
    .is_csr_op_in       (is_csr_op                ),
    .need_nop_in        (need_nop                 ),
    .inst_tlbsrch_in    (inst_tlbsrch             ),
    .inst_invtlb_in     (inst_invtlb              ),
    .inst_tlbwr_in      (inst_tlbwr               ),
    .inst_tlbrd_in      (inst_tlbrd               ),
    .badv_info_in       (new_id_badv_info         ),
    .is_cacop_in        (inst_cacop               ),
    .is_cpucfg_in       (inst_cpucfg              ),
    .inst_in            (inst_from_id             ),
    .is_cntinst_in      (is_cntinst               ),
    .is_ll_w_in         (inst_ll_w                ),
    .is_sc_w_in         (inst_sc_w                ),
    .dif_ld_info_in     (dif_ld_info              ),
    .alu_result_in      (alu_result               ),
    .cacop_va_in        (addr_alu_result          ),
    .icacop_pa_in       (data_paddr               ),
    .dcacop_pa_in       (data_paddr               ),
    .data_paddr_in      (data_paddr               ),
    .inst_tlbfill_in    (inst_tlbfill             ),

    .pc_plus4_out       (pc_plus4_from_ex         ),
    .rj_value_out       (rj_value_from_ex         ),
    .rd_out             (rd_from_ex               ),
    .rkd_value_out      (rkd_value_from_ex        ),
    .data_sram_we_out   (data_sram_we_from_ex     ),
    .rf_wdata_sel_out   (rf_wdata_sel_from_ex     ),
    .rf_we_out          (rf_we_from_ex            ),
    .rf_waddr_out       (rf_waddr_from_ex         ),
    .is_ld_out          (is_ld_from_ex            ),
    .is_st_out          (is_st_from_ex            ),
    .data_sram_wdata_out(data_sram_wdata_from_ex  ),
    .ex_result_sel_out  (ex_result_sel_from_ex    ),
    .mmd_is_signed_out  (mmd_is_signed_from_ex    ),
    .mul_need_hi_out    (mul_need_hi_from_ex      ),
    .ld_ext_is_signed_out(ld_ext_is_signed_from_ex),
    .ld_width_out       (ld_width_from_ex         ),
    .is_st_b_out        (is_st_b_from_ex          ),
    .is_st_h_out        (is_st_h_from_ex          ),
    .csr_num_out        (csr_num_from_ex          ),
    .csr_we_out         (csr_we_from_ex           ),
    .csr_wmask_out      (csr_wmask_from_ex        ),
    .ertn_flush_out     (ertn_flush_from_ex       ),
    .ex_info_out        (ex_ex_info               ),
    .is_csr_op_out      (is_csr_op_from_ex        ),
    .need_nop_out       (need_nop_from_ex         ),
    .inst_tlbsrch_out   (inst_tlbsrch_from_ex     ),
    .inst_invtlb_out    (inst_invtlb_from_ex      ),
    .inst_tlbwr_out     (inst_tlbwr_from_ex       ),
    .inst_tlbrd_out     (inst_tlbrd_from_ex       ),
    .badv_info_out      (ex_badv_info             ),
    .is_cacop_out       (is_cacop_from_ex         ),
    .is_cpucfg_out      (is_cpucfg_from_ex        ),
    .inst_out           (inst_from_ex             ),
    .is_cntinst_out     (is_cntinst_from_ex       ),
    .is_ll_w_out        (is_ll_w_from_ex          ),
    .is_sc_w_out        (is_sc_w_from_ex          ),
    .dif_ld_info_out    (dif_ld_info_from_ex      ),
    .alu_result_out     (alu_result_from_ex       ),
    .cacop_va_out       (cacop_va_from_ex         ),
    .icacop_pa_out      (icacop_pa_from_ex        ),
    .dcacop_pa_out      (dcacop_pa_from_ex        ),
    .data_paddr_out     (data_paddr_from_ex       ),
    .inst_tlbfill_out   (inst_tlbfill_from_ex     ),

    .mem_fire           (mem_fire                 ),
    .ex_fire            (ex_fire                  ),
    .ex_valid           (ex_valid                 )
);

execute_unit u_execute_unit(
    .clk             (aclk                  ),
    .reset           (reset                 ),
    .ex_fire         (ex_fire               ),
    .r_alu_src1      (rj_value_from_ex      ),
    .r_alu_src2      (rkd_value_from_ex     ),
    .ex_result_sel   (ex_result_sel_from_ex ),
    .mmd_is_signed   (mmd_is_signed_from_ex ),
    .mul_need_hi     (mul_need_hi_from_ex   ),

    .have_any_flush  (have_any_flush        ),   

    .alu_result      (alu_result_from_ex    ),
    .ex_result       (ex_result             ),

    .execute_finish  (execute_finish        )
); 

wire ale_ex_load = is_ld_from_ex && !is_cacop_from_ex && (
    (ld_width_from_ex == 4'b1111 && |(alu_result_from_ex[1:0] ^ 2'b00)) || 
    (ld_width_from_ex == 4'b0011 && alu_result_from_ex[0])    
);
wire ale_ex_store = is_st_from_ex && !is_cacop_from_ex && (
    (!is_st_b_from_ex && !is_st_h_from_ex && |(alu_result_from_ex[1:0] ^ 2'b00)) || 
    ( is_st_h_from_ex && alu_result_from_ex[0])                       
);
assign ale_ex = ale_ex_load || ale_ex_store;

assign new_ex_badv_info = (ex_ex_info[0])? ex_badv_info :
                          (ale_ex || tlbr_ex1 || pil_ex || pis_ex || ppi_ex1 || pme_ex )? 2'b10 : 2'b00;
assign new_ex_ex_info = (!ex_valid)? 16'b0 :
                        (ex_ex_info[0])?  ex_ex_info      :
                        (ale_ex  )? {ECODE_ALE, 9'b0, 1'b1} : 
                        (tlbr_ex1)? {ECODE_TLBR,9'b0, 1'b1} :
                        (pil_ex  )? {ECODE_PIL, 9'b0, 1'b1} :
                        (pis_ex  )? {ECODE_PIS, 9'b0 ,1'b1} :
                        (ppi_ex1 )? {ECODE_PPI, 9'b0, 1'b1} :
                        (pme_ex  )? {ECODE_PME, 9'b0 ,1'b1} : 16'b0;

// temp_data_sram_wstrb generator. Name has not been changed yet.
data_sram_we_gen u_data_sram_we_gen (
    .data_sram_we           (data_sram_we_from_ex   ),
    .is_st_b                (is_st_b_from_ex        ),
    .is_st_h                (is_st_h_from_ex        ),
    .ex_result              (alu_result_from_ex     ),
    .temp_data_sram_wstrb   (temp_data_sram_wstrb   )
);

reg [27:0] lladdr;
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        lladdr <= 28'b0;
    end
    else if (wb_valid && is_ll_w_from_wb) begin
        lladdr <= data_sram_addr_from_wb[31:4];
    end
end

assign ll_sc_addr_eq = ex_valid && is_sc_w_from_ex && (lladdr == data_paddr_from_ex[31:4]);

wire [31:0] stb = { {8{temp_data_sram_wstrb[3]}} & data_sram_wdata_from_ex[7:0] ,
                    {8{temp_data_sram_wstrb[2]}} & data_sram_wdata_from_ex[7:0] ,
                    {8{temp_data_sram_wstrb[1]}} & data_sram_wdata_from_ex[7:0] ,
                    {8{temp_data_sram_wstrb[0]}} & data_sram_wdata_from_ex[7:0]};

wire [31:0] sth = { {16{temp_data_sram_wstrb[3]}} & data_sram_wdata_from_ex[15:0] ,
                    {16{temp_data_sram_wstrb[0]}} & data_sram_wdata_from_ex[15:0]};

assign data_sram_req   = ((is_ld_from_ex) || (is_st_from_ex)) & write_buffer_empty &
                          mem_allowin & ex_valid &
                         {~(wb_ex_info[0] | mem_ex_info[0])} & 
                         {~(ertn_flush_from_wb | ertn_flush_from_mem)} & 
                         (!new_ex_ex_info[0]) &
                         ((llbit & ll_sc_addr_eq) | !is_sc_w_from_ex);
assign data_sram_wr    = data_sram_we_from_ex[0];
assign data_sram_addr  = data_paddr_from_ex;
assign data_sram_wstrb = temp_data_sram_wstrb;
assign data_sram_wdata = (is_st_b_from_ex)? stb :
                         (is_st_h_from_ex)? sth :
                                            data_sram_wdata_from_ex ;

// MEM reg
mem_reg u_mem_reg(
    .clk                 (aclk                     ),
    .reset               (reset                    ),
    .ertn_flush          (ertn_flush_from_wb       ),
    .ex_flush            (wb_ex_info[0]            ),
    .refetch_flush       (refetch_flush            ),

    .ex_ready_go         (ex_ready_go              ),

    .rkd_value_in        (rkd_value_from_ex        ),
    .data_sram_we_in     (data_sram_we_from_ex     ),
    .rf_wdata_sel_in     (rf_wdata_sel_from_ex     ),
    .ex_result_in        (ex_result                ),
    .rf_we_in            (rf_we_from_ex            ),
    .rf_waddr_in         (rf_waddr_from_ex         ),
    .pc_plus4_in         (pc_plus4_from_ex         ),
    .data_sram_wdata_in  (data_sram_wdata          ),
    .ld_ext_is_signed_in (ld_ext_is_signed_from_ex ),
    .ld_width_in         (ld_width_from_ex         ),
    .is_st_b_in          (is_st_b_from_ex          ),
    .is_st_h_in          (is_st_h_from_ex          ),
    .csr_num_in          (csr_num_from_ex          ),
    .csr_we_in           (csr_we_from_ex           ),
    .csr_wmask_in        (csr_wmask_from_ex        ),
    .ertn_flush_in       (ertn_flush_from_ex       ), 
    .ex_info_in          (new_ex_ex_info           ),
    .is_csr_op_in        (is_csr_op_from_ex        ),
    .is_ld_in            (is_ld_from_ex            ),
    .is_st_in            (is_st_from_ex            ),
    .data_sram_addr_in   (data_sram_addr           ),
    .need_nop_in         (need_nop_from_ex         ),
    .inst_tlbsrch_in     (inst_tlbsrch_from_ex     ),
    .rd_in               (rd_from_ex               ),
    .inst_invtlb_in      (inst_invtlb_from_ex      ),
    .rj_value_in         (rj_value_from_ex         ),   
    .inst_tlbwr_in       (inst_tlbwr_from_ex       ),
    .inst_tlbrd_in       (inst_tlbrd_from_ex       ),   
    .badv_info_in        (new_ex_badv_info         ),
    .is_cacop_in         (is_cacop_from_ex         ),
    .cacop_va_in         (cacop_va_from_ex         ),
    .icacop_pa_in        (icacop_pa_from_ex        ),
    .dcacop_pa_in        (dcacop_pa_from_ex        ),
    .is_cpucfg_in        (is_cpucfg_from_ex        ),
    .inst_in             (inst_from_ex             ),
    .is_cntinst_in       (is_cntinst_from_ex       ),
    .st_vaddr_in         (alu_result_from_ex       ),
    .st_paddr_in         (data_paddr_from_ex       ),
    .st_data_in          (data_sram_wdata          ),
    .ld_vaddr_in         (alu_result_from_ex       ),
    .is_ll_w_in          (is_ll_w_from_ex          ),
    .is_sc_w_in          (is_sc_w_from_ex          ),
    .dif_ld_info_in      (dif_ld_info_from_ex      ),
    .ll_w_cached_in      (~dcache_suc_flag         ),
    .inst_tlbfill_in     (inst_tlbfill_from_ex     ),

    .rkd_value_out       (rkd_value_from_mem       ),
    .data_sram_we_out    (data_sram_we_from_mem    ),
    .rf_wdata_sel_out    (rf_wdata_sel_from_mem    ),
    .ex_result_out       (ex_result_from_mem       ),
    .rf_we_out           (rf_we_from_mem           ),
    .rf_waddr_out        (rf_waddr_from_mem        ),
    .pc_plus4_out        (pc_plus4_from_mem        ),
    .data_sram_wdata_out (data_sram_wdata_from_mem ),
    .ld_ext_is_signed_out(ld_ext_is_signed_from_mem),
    .ld_width_out        (ld_width_from_mem        ),
    .is_st_b_out         (is_st_b_from_mem         ),
    .is_st_h_out         (is_st_h_from_mem         ),
    .csr_num_out         (csr_num_from_mem         ),
    .csr_we_out          (csr_we_from_mem          ),
    .csr_wmask_out       (csr_wmask_from_mem       ),
    .ertn_flush_out      (ertn_flush_from_mem      ),
    .ex_info_out         (mem_ex_info              ),
    .is_csr_op_out       (is_csr_op_from_mem       ),
    .is_ld_out           (is_ld_from_mem           ),
    .is_st_out           (is_st_from_mem           ),
    .data_sram_addr_out  (data_sram_addr_from_mem  ),
    .need_nop_out        (need_nop_from_mem        ),
    .inst_tlbsrch_out    (inst_tlbsrch_from_mem    ),
    .rd_out              (rd_from_mem              ),
    .inst_invtlb_out     (inst_invtlb_from_mem     ),
    .rj_value_out        (rj_value_from_mem        ),
    .inst_tlbwr_out      (inst_tlbwr_from_mem      ),
    .inst_tlbrd_out      (inst_tlbrd_from_mem      ),
    .badv_info_out       (mem_badv_info            ),
    .is_cacop_out        (is_cacop_from_mem        ),
    .cacop_va_out        (cacop_va_from_mem        ),
    .icacop_pa_out       (icacop_pa_from_mem       ),
    .dcacop_pa_out       (dcacop_pa_from_mem       ),
    .is_cpucfg_out       (is_cpucfg_from_mem       ),
    .inst_out            (inst_from_mem            ),
    .is_cntinst_out      (is_cntinst_from_mem      ),
    .st_vaddr_out        (st_vaddr_from_mem        ),
    .st_paddr_out        (st_paddr_from_mem        ),
    .st_data_out         (st_data_from_mem         ),
    .ld_vaddr_out        (ld_vaddr_from_mem        ),
    .is_ll_w_out         (is_ll_w_from_mem         ),
    .is_sc_w_out         (is_sc_w_from_mem         ),
    .dif_ld_info_out     (dif_ld_info_from_mem     ),
    .ll_w_cached_out     (ll_w_cached_from_mem     ),
    .inst_tlbfill_out    (inst_tlbfill_from_mem    ),

    .wb_fire             (wb_fire                  ),
    .mem_fire            (mem_fire                 ),
    .mem_valid           (mem_valid                ),
    .mem_allowin         (mem_allowin              )
);

// get rf_wdata
get_wb_data_unit u_get_wb_data_unit(
    .data_sram_addr     (data_sram_addr_from_mem    ),
    .data_sram_rdata    (data_sram_rdata    ),
    .ex_result          (ex_result_from_mem         ),
    .pc_plus4           (pc_plus4_from_mem          ),
    .rj_value           (rj_value_from_mem          ),

    .ld_width           (ld_width_from_mem          ),
    .ld_ext_is_signed   (ld_ext_is_signed_from_mem  ),
    .rf_wdata_sel       (rf_wdata_sel_from_mem      ),

    .llbit              (llbit                      ),

    .rf_wdata           (rf_wdata_from_mem          )
);

// WB reg
wb_reg u_wb_reg(
    .clk                    (aclk                     ),
    .reset                  (reset                    ),
    .ertn_flush             (ertn_flush_from_wb       ),
    .ex_flush               (wb_ex_info[0]            ), 
    .refetch_flush          (refetch_flush            ),

    .mem_ready_go           (mem_ready_go             ),

    .rf_wdata_sel_in        (rf_wdata_sel_from_mem    ),
    .rf_we_in               (rf_we_from_mem           ),
    .rf_waddr_in            (rf_waddr_from_mem        ),
    .pc_plus4_in            (pc_plus4_from_mem        ),
    .data_sram_addr_in      (data_sram_addr_from_mem  ),
    .csr_num_in             (csr_num_from_mem         ),
    .csr_we_in              (csr_we_from_mem          ),
    .csr_wmask_in           (csr_wmask_from_mem       ),
    .rkd_value_in           (rkd_value_from_mem       ),
    .ertn_flush_in          (ertn_flush_from_mem      ),
    .ex_info_in             (mem_ex_info              ),
    .inst_tlbsrch_in        (inst_tlbsrch_from_mem    ),
    .rd_in                  (rd_from_mem              ),
    .inst_invtlb_in         (inst_invtlb_from_mem     ),
    .rj_value_in            (rj_value_from_mem        ),
    .inst_tlbwr_in          (inst_tlbwr_from_mem      ),
    .inst_tlbrd_in          (inst_tlbrd_from_mem      ),
    .badv_info_in           (mem_badv_info            ),
    .is_cacop_in            (is_cacop_from_mem        ),
    .cacop_va_in            (cacop_va_from_mem        ),
    .icacop_pa_in           (icacop_pa_from_mem       ),
    .dcacop_pa_in           (dcacop_pa_from_mem       ),
    .is_ld_in               (is_ld_from_mem           ),
    .inst_in                (inst_from_mem            ),
    .is_cntinst_in          (is_cntinst_from_mem      ),
    .is_csr_op_in           (is_csr_op_from_mem       ),   
    .is_st_in               (is_st_from_mem           ),
    .is_st_b_in             (is_st_b_from_mem         ),
    .is_st_h_in             (is_st_h_from_mem         ),
    .st_vaddr_in            (st_vaddr_from_mem        ),
    .st_paddr_in            (st_paddr_from_mem        ),
    .st_data_in             (st_data_from_mem         ),
    .ld_vaddr_in            (ld_vaddr_from_mem        ),
    .is_ll_w_in             (is_ll_w_from_mem         ),
    .is_sc_w_in             (is_sc_w_from_mem         ),
    .dif_ld_info_in         (dif_ld_info_from_mem     ),
    .ll_w_cached_in         (ll_w_cached_from_mem     ),
    .inst_tlbfill_in        (inst_tlbfill_from_mem    ),
    .rf_wdata_in            (rf_wdata_from_mem        ),

    .rf_wdata_sel_out       (rf_wdata_sel_from_wb     ),
    .rf_we_out              (rf_we_from_wb            ), // 
    .rf_waddr_out           (rf_waddr_from_wb         ),
    .pc_plus4_out           (pc_plus4_from_wb         ),
    .data_sram_addr_out     (data_sram_addr_from_wb   ),
    .csr_num_out            (csr_num_from_wb          ),
    .csr_we_out             (csr_we_from_wb           ), //
    .csr_wmask_out          (csr_wmask_from_wb        ),
    .rkd_value_out          (rkd_value_from_wb        ),
    .ertn_flush_out         (ertn_flush_from_wb       ),
    .ex_info_out            (wb_ex_info               ),
    .inst_tlbsrch_out       (inst_tlbsrch_from_wb     ),
    .rd_out                 (rd_from_wb               ),
    .inst_invtlb_out        (inst_invtlb_from_wb      ),
    .rj_value_out           (rj_value_from_wb         ),
    .inst_tlbwr_out         (inst_tlbwr_from_wb       ),
    .inst_tlbrd_out         (inst_tlbrd_from_wb       ),
    .badv_info_out          (wb_badv_info             ),
    .is_cacop_out           (is_cacop_from_wb         ),
    .cacop_va_out           (cacop_va_from_wb         ),
    .icacop_pa_out          (icacop_pa_from_wb        ),
    .dcacop_pa_out          (dcacop_pa_from_wb        ),
    .is_ld_out              (is_ld_from_wb            ),
    .inst_out               (inst_from_wb             ),
    .is_cntinst_out         (is_cntinst_from_wb       ),
    .is_csr_op_out          (is_csr_op_from_wb        ),
    .is_st_out              (is_st_from_wb            ),
    .is_st_b_out            (is_st_b_from_wb          ),
    .is_st_h_out            (is_st_h_from_wb          ),
    .st_vaddr_out           (st_vaddr_from_wb         ),
    .st_paddr_out           (st_paddr_from_wb         ),
    .st_data_out            (st_data_from_wb          ),
    .ld_vaddr_out           (ld_vaddr_from_wb         ),
    .is_ll_w_out            (is_ll_w_from_wb          ),
    .is_sc_w_out            (is_sc_w_from_wb          ),
    .dif_ld_info_out        (dif_ld_info_from_wb      ),
    .ll_w_cached_out        (ll_w_cached_from_wb      ),
    .inst_tlbfill_out       (inst_tlbfill_from_wb     ),
    .rf_wdata_out           (rf_wdata_from_wb         ),
    
    .wb_fire                (wb_fire                  ),
    .wb_valid               (wb_valid                 )
);

wire atom_nop = ((inst_ll_w || inst_sc_w) && (ex_valid || mem_valid || wb_valid)) ||
                ((is_ll_w_from_ex || is_sc_w_from_ex) && ex_valid) ||
                ((is_ll_w_from_mem || is_sc_w_from_mem) && mem_valid) ||
                ((is_ll_w_from_wb || is_sc_w_from_wb) && wb_valid) ;

// NOP unit
nop_logic_unit u_nop_logic_unit(
    .clk                        (aclk                   ),
    .reset                      (reset                  ),
    .ertn_flush                 (ertn_flush_from_wb     ),
    .ex_flush                   (wb_ex_info[0]          ),
    .refetch_flush              (refetch_flush          ),

    .rf_waddr_from_ex           (rf_waddr_from_ex       ),
    .rf_waddr_from_mem          (rf_waddr_from_mem      ),
    .rf_waddr_from_wb           (rf_waddr_from_wb       ),
    .id_stage_is_inst_branch    (inst_branch            ),  
    .ex_stage_is_inst_ld        (is_ld_from_ex          ),
    .mem_stage_is_inst_ld       (is_ld_from_mem         ),
    .wb_stage_is_inst_ld        (is_ld_from_wb          ),
    .ex_stage_is_csr_op         (is_csr_op_from_ex      ),
    .mem_stage_is_csr_op        (is_csr_op_from_mem     ),
    .wb_stage_is_csr_op         (is_csr_op_from_wb      ),
    .pc_from_ex                 (pc_plus4_from_ex       ),
    .pc_from_id                 (pc_plus4_from_id       ),
    .atom_nop                   (atom_nop               ),
    .need_ex_forward            (need_ex_forward        ),
    .ex_result_sel_from_ex      (ex_result_sel_from_ex  ),

    .rj                         (rj                     ),
    .rkd                        (rf_raddr2              ),

    .ex_valid                   (ex_valid               ),
    .mem_valid                  (mem_valid              ),
    .wb_valid                   (wb_valid               ),

    .need_nop                   (need_nop               )
);

// CSR
csr_unit u_csr_unit(
    .clk            (aclk                           ),
    .reset          (reset                          ),

    .icacop_ex_flag (wb_valid && is_cacop_from_wb && rd_from_wb==5'b10000),
    .dcacop_ex_flag (wb_valid && is_cacop_from_wb && rd_from_wb==5'b10001),

    .have_ex        (wb_ex_info[0]                  ),
    .ecode          (wb_ex_info[15:10]              ),
    .esubcode       (wb_ex_info[9:1]                ),
    .pc             (pc_plus4_from_wb - 32'h00000004),
    .mem_vaddr      (ld_vaddr_from_wb               ), // st 的也一样
    .badv_info      (wb_badv_info                   ),

    .ll_w_flag      (wb_valid && is_ll_w_from_wb &&
                     !wb_ex_info[0]         ),
    .sc_w_flag      (wb_valid && is_sc_w_from_wb && 
                     !wb_ex_info[0]         ),

    .tlbsrch        (wb_valid && inst_tlbsrch_from_wb
                        && !wb_ex_info[0]   ),
    .s2_found       (s2_found               ),
    .s2_index       (s2_index               ),
    .tlbrd          (wb_valid && inst_tlbrd_from_wb 
                     && !wb_ex_info[0]      ),
    .tlb_r_e        (r_e                    ),
    .tlb_r_vppn     (r_vppn                 ),
    .tlb_r_ps       (r_ps                   ),
    .tlb_r_asid     (r_asid                 ),
    .tlb_r_g        (r_g                    ),
    .tlb_r_ppn0     (r_ppn0                 ),
    .tlb_r_plv0     (r_plv0                 ),
    .tlb_r_mat0     (r_mat0                 ),
    .tlb_r_d0       (r_d0                   ),
    .tlb_r_v0       (r_v0                   ),
    .tlb_r_ppn1     (r_ppn1                 ),
    .tlb_r_plv1     (r_plv1                 ),
    .tlb_r_mat1     (r_mat1                 ),
    .tlb_r_d1       (r_d1                   ),
    .tlb_r_v1       (r_v1                   ),

    .ertn_flush     (ertn_flush_from_wb     ),
    .hw_interupt    (intrpt                 ),
    .ipi_interupt   ( 0                     ),

    .csr_addr       (csr_num_from_wb        ),
    .csr_we         (wb_valid && csr_we_from_wb & !wb_ex_info[0]), //
    .csr_wmask      (csr_wmask_from_wb      ), 
    .csr_wdata      (rkd_value_from_wb      ),

    .have_int       (have_int               ),
    .pc_from_era    (pc_from_era            ),
    .csr_rdata      (csr_rdata              ),
    .disable_cache_out (disable_cache       ),

    .asid           (asid                   ),
    .tlbehi         (tlbehi                 ),
    .tlbelo0        (tlbelo0                ),
    .tlbelo1        (tlbelo1                ),
    .tlbidx         (tlbidx                 ),
    .estat          (estat                  ),
    .crmd_da        (crmd_da                ),
    .crmd_pg        (crmd_pg                ),
    .crmd_plv       (crmd_plv               ),
    .crmd_datf      (crmd_datf              ),
    .crmd_datm      (crmd_datm              ),
    .llbit          (llbit                  ),
    .dmw0           (dmw0                   ),
    .dmw1           (dmw1                   ),
    .eentry         (eentry                 ),
    .tlbrentry      (tlbrentry              ),
    .stable_cnt     (stable_cnt             )
    `ifdef DIFFTEST_EN
    ,
    .dif_crmd           (crmd                   ),
    .dif_prmd           (prmd                   ),
    .dif_ecfg           (ecfg                   ),
    .dif_era            (era                    ),
    .dif_badv           (badv                   ),
    .dif_save0          (save0                  ),
    .dif_save1          (save1                  ),
    .dif_save2          (save2                  ),
    .dif_save3          (save3                  ),
    .dif_tid            (tid                    ),
    .dif_tcfg           (tcfg                   ),
    .dif_tval           (tval                   ),
    .dif_ticlr          (ticlr                  ),
    .dif_llbctl         (llbctl                 ),
    .dif_pgd            (pgd                    ),
    .dif_pgdl           (pgdl                   ),
    .dif_pgdh           (pgdh                   )
    `endif 
);

wire        tlb_we      = wb_valid && (inst_tlbwr_from_wb || inst_tlbfill_from_wb) && (!wb_ex_info[0]);
wire [ 4:0] tlb_w_index = inst_tlbwr_from_wb? tlbidx[4:0] : stable_cnt[4:0];
wire        tlb_w_e     = (estat[21:16] == 6'h3f)? 1'b1 : (!tlbidx[31]);

// TLB
tlb u_tlb(
    .clk        (aclk        ),
    .reset      (reset       ),

    .s0_vppn    (pc[31:13]   ),
    .s0_va_bit12(pc[12]      ),
    .s0_asid    (asid[9:0]   ),
    .s0_va_20   (s0_va_20    ),
    .s0_found   (s0_found    ),
    .s0_index   (s0_index    ),
    .s0_ppn     (s0_ppn      ),
    .s0_ps      (s0_ps       ),
    .s0_plv     (s0_plv      ),
    .s0_mat     (s0_mat      ),
    .s0_d       (s0_d        ),
    .s0_v       (s0_v        ),

    .s1_vppn    (addr_alu_result[31:13]),
    .s1_va_bit12(addr_alu_result[12]   ),
    .s1_asid    (asid[9:0]   ),
    .s1_found   (s1_found    ),
    .s1_index   (s1_index    ),
    .s1_ppn     (s1_ppn      ),
    .s1_ps      (s1_ps       ),
    .s1_plv     (s1_plv      ),
    .s1_mat     (s1_mat      ),
    .s1_d       (s1_d        ),
    .s1_v       (s1_v        ),

    .s2_vppn    (tlbehi[31:13]  ), 
    .s2_va_bit12(1'b0           ), 
    .s2_asid    (asid[9:0]      ),
    .s2_found   (s2_found       ),
    .s2_index   (s2_index       ),

    .s3_vppn    (rkd_value_from_wb[31:13] ), 
    .s3_va_bit12(rkd_value_from_wb[12]    ), 
    .s3_asid    (rj_value_from_wb[9:0]    ),

    .invtlb_valid(wb_valid && inst_invtlb_from_wb &&
                  !wb_ex_info[0]          ),
    .invtlb_op   (rd_from_wb              ),

    .we         (tlb_we                   ), //
    .w_index    (tlb_w_index              ),
    .w_e        (tlb_w_e                  ),
    .w_vppn     (tlbehi[31:13]            ),
    .w_ps       (tlbidx[29:24]            ),
    .w_asid     (asid[9:0]                ),
    .w_g        (tlbelo0[6] && tlbelo1[6] ),
    .w_ppn0     (tlbelo0[27:8]            ),
    .w_plv0     (tlbelo0[3:2]             ),
    .w_mat0     (tlbelo0[5:4]             ),
    .w_d0       (tlbelo0[1]               ),
    .w_v0       (tlbelo0[0]               ),
    .w_ppn1     (tlbelo1[27:8]            ),
    .w_plv1     (tlbelo1[3:2]             ),
    .w_mat1     (tlbelo1[5:4]             ),
    .w_d1       (tlbelo1[1]               ),
    .w_v1       (tlbelo1[0]               ),

    .r_index    (tlbidx[4:0]    ),
    .r_e        (r_e            ),
    .r_vppn     (r_vppn         ),
    .r_ps       (r_ps           ),
    .r_asid     (r_asid         ),
    .r_g        (r_g            ),
    .r_ppn0     (r_ppn0         ),
    .r_plv0     (r_plv0         ),
    .r_mat0     (r_mat0         ),
    .r_d0       (r_d0           ),
    .r_v0       (r_v0           ),
    .r_ppn1     (r_ppn1         ),
    .r_plv1     (r_plv1         ),
    .r_mat1     (r_mat1         ),
    .r_d1       (r_d1           ),
    .r_v1       (r_v1           )
);

wire cacop_finish = icache_cacop_finish || dcache_cacop_finish || (wb_valid && is_cacop_from_wb && (rd_from_wb==5'b00010));
assign refetch_flush = !ex_valid && !mem_valid && !wb_valid && refetch_flag && (!wb_ex_info[0]) &&
                       (is_cacop_from_wb? cacop_finish : 1'b1) &&
                       (idle_flag? have_int : 1'b1);

assign rf_wdata = (rf_wdata_sel_from_wb==3'b011)? csr_rdata : rf_wdata_from_wb;

assign debug0_wb_rf_wen   = ({4{rf_we_from_wb}} & {4{wb_valid}} & {4{~wb_ex_info[0]}}) | ({4{rf_we_from_wb}} & {4{wb_valid}} & {4{is_sc_w_from_wb & !rf_wdata[0]}});
assign debug0_wb_rf_wnum  = rf_waddr_from_wb;
assign debug0_wb_rf_wdata = rf_wdata;
assign debug0_wb_pc       = pc_plus4_from_wb - 32'h00000004; 

assign IF_pc  = pc_from_if; 
assign ID_pc  = pc_plus4_from_id  - 32'h00000004;
assign EX_pc  = pc_plus4_from_ex  - 32'h00000004;
assign MEM_pc = pc_plus4_from_mem - 32'h00000004;
assign WB_pc  = pc_plus4_from_wb  - 32'h00000004;





`ifdef DIFFTEST_EN

reg             cmt_valid           ;
reg             cmt_cnt_inst        ;
reg     [63:0]  cmt_timer_64        ;
reg     [ 7:0]  cmt_inst_ld_en      ;
reg     [31:0]  cmt_ld_paddr        ;
reg     [31:0]  cmt_ld_vaddr        ;
reg     [ 7:0]  cmt_inst_st_en      ;
reg     [31:0]  cmt_st_paddr        ;
reg     [31:0]  cmt_st_vaddr        ;
reg     [31:0]  cmt_st_data         ;
reg             cmt_csr_rstat_en    ;
reg     [31:0]  cmt_csr_data        ;

reg             cmt_wen             ;
reg     [ 7:0]  cmt_wdest           ;
reg     [31:0]  cmt_wdata           ;
reg     [31:0]  cmt_pc              ;
reg     [31:0]  cmt_inst            ;

reg             cmt_excp_flush      ;
reg             cmt_ertn            ;
reg     [5:0]   cmt_csr_ecode       ;
reg             cmt_tlbfill_en      ;
reg     [4:0]   cmt_rand_index      ;

// to difftest debug
reg             trap                ;
reg     [ 7:0]  trap_code           ;
reg     [63:0]  cycleCnt            ;
reg     [63:0]  instrCnt            ;

wire csr_op_and_estat = wb_valid && is_csr_op_from_wb && (csr_num_from_wb==14'h05);
wire is_st_w_from_wb = wb_valid && is_st_from_wb && (!is_st_b_from_wb) && (!is_st_h_from_wb) && (!is_sc_w_from_wb);
wire [31:0] diff_st_data = (is_st_w_from_wb)? st_data_from_wb:
                           (is_sc_w_from_wb)? st_data_from_wb:
                           (is_st_h_from_wb && !st_vaddr_from_wb[1])? {16'b0, st_data_from_wb[15:0]} :
                           (is_st_h_from_wb &&  st_vaddr_from_wb[1])? {st_data_from_wb[31:16], 16'b0} :
                           (is_st_b_from_wb &&  st_vaddr_from_wb[1:0]==2'b00)? {24'b0, st_data_from_wb[7:0]} : 
                           (is_st_b_from_wb &&  st_vaddr_from_wb[1:0]==2'b01)? {16'b0, st_data_from_wb[15:8], 8'b0} :
                           (is_st_b_from_wb &&  st_vaddr_from_wb[1:0]==2'b10)? {8'b0, st_data_from_wb[23:16], 16'b0} :
                           (is_st_b_from_wb &&  st_vaddr_from_wb[1:0]==2'b11)? {st_data_from_wb[31:24], 24'b0} : 32'b0 ;

always @(posedge aclk) begin
    if (reset) begin
        {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr, cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data, cmt_csr_rstat_en, cmt_csr_data} <= 0;
        {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
        {trap, trap_code, cycleCnt, instrCnt} <= 0;
    end else if (~trap) begin
        cmt_valid       <= wb_valid && !wb_ex_info[0];
        cmt_cnt_inst    <= wb_valid && is_cntinst_from_wb       ;
        cmt_timer_64    <= stable_cnt               ;
        cmt_inst_ld_en  <= {2'b0, dif_ld_info_from_wb};
        cmt_ld_paddr    <= data_sram_addr_from_wb   ;
        cmt_ld_vaddr    <= ld_vaddr_from_wb         ;
        cmt_inst_st_en  <= {4'b0, (llbit && is_sc_w_from_wb), is_st_w_from_wb, is_st_h_from_wb, is_st_b_from_wb } ;
        cmt_st_paddr    <= st_paddr_from_wb         ;
        cmt_st_vaddr    <= st_vaddr_from_wb         ;
        cmt_st_data     <= diff_st_data          ;
        cmt_csr_rstat_en<= csr_op_and_estat         ;
        cmt_csr_data    <= csr_rdata                ;

        cmt_wen     <=  debug0_wb_rf_wen            ;
        cmt_wdest   <=  {3'b0, debug0_wb_rf_wnum}   ;
        cmt_wdata   <=  debug0_wb_rf_wdata          ;
        cmt_pc      <=  debug0_wb_pc                ;
        cmt_inst    <=  inst_from_wb                ;

        cmt_excp_flush  <= wb_ex_info[0]            ;
        cmt_ertn        <= wb_valid && ertn_flush_from_wb       ;
        cmt_csr_ecode   <= wb_ex_info[15:10]        ;
        cmt_tlbfill_en  <= wb_valid && inst_tlbfill_from_wb && !wb_ex_info[0];    
        cmt_rand_index  <= stable_cnt[4:0]            ;      

        trap            <= 0                        ;
        trap_code       <= regs[327:320]            ;
        cycleCnt        <= cycleCnt + 1             ;
        instrCnt        <= instrCnt + (wb_valid && !wb_ex_info[0]);
    end
end

DifftestInstrCommit DifftestInstrCommit(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_valid      ),
    .pc                 (cmt_pc         ),
    .instr              (cmt_inst       ),
    .skip               (0              ), 
    .is_TLBFILL         (cmt_tlbfill_en ),
    .TLBFILL_index      (cmt_rand_index ),
    .is_CNTinst         (cmt_cnt_inst   ),
    .timer_64_value     (cmt_timer_64   ),
    .wen                (cmt_wen        ),
    .wdest              (cmt_wdest      ),
    .wdata              (cmt_wdata      ),
    .csr_rstat          (cmt_csr_rstat_en),
    .csr_data           (cmt_csr_data   )
);

DifftestExcpEvent DifftestExcpEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .excp_valid         (cmt_excp_flush ),
    .eret               (cmt_ertn       ),
    .intrNo             (estat[12:2]    ),
    .cause              (cmt_csr_ecode  ),
    .exceptionPC        (cmt_pc         ),
    .exceptionInst      (cmt_inst       )
);

DifftestTrapEvent DifftestTrapEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .valid              (trap           ),
    .code               (trap_code      ),
    .pc                 (cmt_pc         ),
    .cycleCnt           (cycleCnt       ),
    .instrCnt           (instrCnt       )
);

DifftestStoreEvent DifftestStoreEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_st_en ),
    .storePAddr         (cmt_st_paddr   ),
    .storeVAddr         (cmt_st_vaddr   ),
    .storeData          (cmt_st_data    )
);

DifftestLoadEvent DifftestLoadEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_ld_en ),
    .paddr              (cmt_ld_paddr   ),
    .vaddr              (cmt_ld_vaddr   )
);

DifftestCSRRegState DifftestCSRRegState(
    .clock              (aclk    ),
    .coreid             (0       ),
    .crmd               (crmd    ),
    .prmd               (prmd    ),
    .euen               (0       ),
    .ecfg               (ecfg    ),
    .estat              (estat   ),
    .era                (era     ),
    .badv               (badv    ),
    .eentry             (eentry  ),
    .tlbidx             (tlbidx  ),
    .tlbehi             (tlbehi  ),
    .tlbelo0            (tlbelo0 ),
    .tlbelo1            (tlbelo1 ),
    .asid               (asid    ),
    .pgdl               (pgdl    ),
    .pgdh               (pgdh    ),
    .save0              (save0   ),
    .save1              (save1   ),
    .save2              (save2   ),
    .save3              (save3   ),
    .tid                (tid     ),
    .tcfg               (tcfg    ),
    .tval               (tval    ),
    .ticlr              (ticlr   ),
    .llbctl             (llbctl  ),
    .tlbrentry          (tlbrentry),
    .dmw0               (dmw0    ),
    .dmw1               (dmw1    )
);

DifftestGRegState DifftestGRegState(
    .clock              (aclk       ),
    .coreid             (0          ),
    .gpr_0              (0          ),
    .gpr_1              (regs[63:32]    ),
    .gpr_2              (regs[95:64]    ),
    .gpr_3              (regs[127:96]   ),
    .gpr_4              (regs[159:128]  ),
    .gpr_5              (regs[191:160]  ),
    .gpr_6              (regs[223:192]  ),
    .gpr_7              (regs[255:224]  ),
    .gpr_8              (regs[287:256]  ),
    .gpr_9              (regs[319:288]  ),
    .gpr_10             (regs[351:320]  ),
    .gpr_11             (regs[383:352]  ),
    .gpr_12             (regs[415:384]  ),
    .gpr_13             (regs[447:416]  ),
    .gpr_14             (regs[479:448]  ),
    .gpr_15             (regs[511:480]  ),
    .gpr_16             (regs[543:512]  ),
    .gpr_17             (regs[575:544]  ),
    .gpr_18             (regs[607:576]  ),
    .gpr_19             (regs[639:608]  ),
    .gpr_20             (regs[671:640]  ),
    .gpr_21             (regs[703:672]  ),
    .gpr_22             (regs[735:704]  ),
    .gpr_23             (regs[767:736]  ),
    .gpr_24             (regs[799:768]  ),
    .gpr_25             (regs[831:800]  ),
    .gpr_26             (regs[863:832]  ),
    .gpr_27             (regs[895:864]  ),
    .gpr_28             (regs[927:896]  ),
    .gpr_29             (regs[959:928]  ),
    .gpr_30             (regs[991:960]  ),
    .gpr_31             (regs[1023:992] )
);
`endif

`ifdef DIFFTEST_EN
reg [63:0] bp_pre_right_cnt, bp_pre_error_cnt, bp_target_error_cnt;
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        bp_pre_right_cnt <= 64'b0;
        bp_pre_error_cnt <= 64'b0;
        bp_target_error_cnt <= 64'b0;
    end
    else if (bp_update_en) begin
        bp_pre_right_cnt <= bp_pre_right_cnt + bp_pre_right;
        bp_pre_error_cnt <= bp_pre_error_cnt + bp_pre_error;
        bp_target_error_cnt <= bp_target_error_cnt + bp_target_error;
    end
end
`endif 

endmodule