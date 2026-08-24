`include "mycpu.h"

module mycpu_core(
    input         clk,
    input         resetn,

    // icache CPU interface
    output        icache_valid,
    output        icache_op,
    output [ 7:0] icache_index,
    output [19:0] icache_tag,
    output [ 3:0] icache_offset,
    output [ 3:0] icache_wstrb,
    output [31:0] icache_wdata,
    output        icache_uncache_en,
    input [127:0] icache_rdata,
    input         icache_addr_ok,
    input         icache_data_ok,
    output        icache_tlb_excp_cancel,
    input         icache_unbusy,
    output        icacop_op_en,
    output [1:0]  cacop_op_mode,

    // dcache CPU interface
    output        dcache_valid,
    output        dcache_op,
    output [ 2:0] dcache_size,
    output [ 6:0] dcache_index,
    output [19:0] dcache_tag,
    output [ 4:0] dcache_offset,
    output [ 3:0] dcache_wstrb,
    output [31:0] dcache_wdata,
    output        dcache_uncache_en,
    input  [31:0] dcache_rdata,
    input         dcache_addr_ok,
    input         dcache_data_ok,
    output        dcache_tlb_excp_cancel,
    output        dcacop_op_en,
    output        preld_en,
    input         write_buffer_empty,
    input         dcache_empty,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_we,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output  ws_reflush,
    input [7:0] intrpt
);
wire [4:0] rand_idx;

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire inst_idle_0;
wire inst_idle_1;
wire commit_idle_0;
wire commit_idle_1;
wire        is_load_0;
wire        is_load_1;
wire [31:0] wb_va;
wire        commit_is_load_0;
wire [31:0] commit_va_0;
wire        commit_is_load_1;
wire [31:0] commit_va_1;
wire [31:0] ms_store_wdata;
wire [31:0] commit_store_wdata_0;
wire [31:0] commit_store_wdata_1;
wire es_mem_we;


wire         ds_allowin;
wire         enq_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
//wire         fs_to_fb_valid;
wire   [1:0] deq_valid;
wire        ds_to_rename_valid_0;
wire        ds_to_rename_valid_1;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
//wire [`FS_TO_DS_BUS_WD -1:0] fs_to_fb_bus;
wire [`FS_TO_DS_BUS_WD -1:0] deq_bus_0;
wire [`FS_TO_DS_BUS_WD -1:0] deq_bus_1;
wire [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_0;
wire [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_1;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [36:0] es_forward_reg;
wire [36:0] ms_forward_reg;
wire [36:0] ws_forward_reg;
wire es_to_ds_load_op;
wire ms_to_ds_load_op;
wire [`WS_TO_CSR_BUS -1:0] ws_to_csr_bus;
wire [191:0] arat_recover_bus;
wire ms_ex;
wire ws_ex;
wire ertn_flush;
wire [31:0] csr_rvalue;
wire [31:0] ex_entry;
wire [31:0] era_entry;
wire es_csr_re;
wire ms_csr_re;
//wire ws_reflush;
wire has_int;
wire es_to_ds_inst_no_dest;
wire ms_to_ds_inst_no_dest;
wire ws_to_ds_inst_no_dest;

wire [1:0] deq_pop_count;
wire [ 1:0] freelist_free_cnt;
wire req_preg_0;
wire req_preg_1;
wire [ 5:0] alloc_preg_0;
wire [ 5:0] alloc_preg_1;
wire [ 1:0] rob_free_cnt;      // ROB ?????  ???????
wire        req_rob_0;         // ???????? 1 ?? ROB ???
wire        req_rob_1;         // ???????? 2 ?? ROB ???
wire [ 3:0] rob_id_0;          // ????? ROB ??? 0
wire [ 3:0] rob_id_1;          // ????? ROB ??? 1
wire [ 4:0] srat_raddr1_0;
wire [ 4:0] srat_raddr2_0;
wire [ 5:0] srat_rdata1_0;
wire [ 5:0] srat_rdata2_0;
wire [ 4:0] srat_raddr1_1;
wire [ 4:0] srat_raddr2_1;
wire [ 5:0] srat_rdata1_1;
wire [ 5:0] srat_rdata2_1;
wire        srat_we_0;
wire [ 4:0] srat_waddr_0;
wire [ 5:0] srat_wdata_0;
wire        srat_we_1;
wire [ 4:0] srat_waddr_1;
wire [ 5:0] srat_wdata_1;
wire      rn_to_issue_valid_0;
wire [ 5:0] preg_rs1_0;
wire [ 5:0] preg_rs2_0;
wire [ 5:0] preg_rd_0;
wire [ 3:0] rn_rob_id_0;
wire        rn_to_issue_valid_1;
wire [ 5:0] preg_rs1_1;
wire [ 5:0] preg_rs2_1;
wire [ 5:0] preg_rd_1;
wire [ 3:0] rn_rob_id_1;
wire        set_preg_busy_0;
wire [ 5:0] busy_preg_id_0;
wire        set_preg_busy_1;
wire [ 5:0] busy_preg_id_1;
wire [ 1:0] dp_accept_cnt;
wire [ 1:0] rn_allowin_cnt;
wire [ 4:0] areg_dest0;
wire [ 4:0] areg_dest1;
wire [ 5:0] srat_dest_rdata0;
wire [ 5:0] srat_dest_rdata1;
wire [63:0] arat_mapped_mask; 
wire        free_we_0;
wire [ 5:0] free_preg_0;
wire        free_we_1;
wire [ 5:0] free_preg_1;
wire [ 5:0] old_preg_0;
wire [ 5:0] old_preg_1;
wire        cdb_we_0;
wire [3:0]  cdb_rob_id_0;
wire        cdb_we_1;
wire [3:0]  cdb_rob_id_1;
wire        cdb_we_2;
wire [3:0]  cdb_rob_id_2;
wire        commit_valid_0;
wire [5:0]  commit_old_preg_0;
wire        commit_valid_1;
wire [5:0]  commit_old_preg_1;
wire [ 4:0] commit_areg_rd_0;
wire [ 5:0] commit_new_preg_0;
wire [ 4:0] commit_areg_rd_1;
wire [ 5:0] commit_new_preg_1;
wire [ 1:0] commit_pop_cnt;
wire rob_head_inst_tlbsrch_0;
wire rob_head_inst_tlbrd_0;
wire rob_head_inst_tlbwr_0;
wire rob_head_inst_tlbfill_0;
wire rob_head_tlb_hit_0;
wire [ 4:0] rob_head_tlb_index_0;
wire rob_head_inst_valid_cacop_0;
wire rob_head_inst_tlbsrch_1;
wire rob_head_inst_tlbrd_1;
wire rob_head_inst_tlbwr_1;
wire rob_head_inst_tlbfill_1;
wire rob_head_tlb_hit_1;
wire [ 4:0] rob_head_tlb_index_1;
wire rob_head_inst_valid_cacop_1;
wire [ 5:0] cdb_preg_0;
wire [ 5:0] cdb_preg_1;
wire [ 5:0] cdb_preg_2;
wire [`DE_TO_DS_BUS-1:0] rn_to_issue_bus_0;
wire [`DE_TO_DS_BUS-1:0] rn_to_issue_bus_1;
wire rn_rs1_ready_0;
wire rn_rs1_ready_1;
wire rn_rs2_ready_0;
wire rn_rs2_ready_1;
wire        alu0_enq_valid;
wire [ 5:0] alu0_enq_preg_rs1;
wire [ 5:0] alu0_enq_preg_rs2;
wire [ 5:0] alu0_enq_preg_rd;
wire [ 3:0] alu0_enq_rob_id;
wire [`DE_TO_DS_BUS-1:0] alu0_enq_payload;
wire        alu0_enq_rs1_ready;
wire        alu0_enq_rs2_ready;
wire        alu0_iq_allowin;  // ALU0?????????  

    // 3. ???? ALU_1 ????

wire        alu1_enq_valid;
wire [ 5:0] alu1_enq_preg_rs1;
wire [ 5:0] alu1_enq_preg_rs2;
wire [ 5:0] alu1_enq_preg_rd;
wire [ 3:0] alu1_enq_rob_id;
wire [`DE_TO_DS_BUS-1:0] alu1_enq_payload;
wire        alu1_enq_rs1_ready;
wire        alu1_enq_rs2_ready;
wire        alu1_iq_allowin;  // ALU1?????????  

    // 4. ???? MEM/PRIV ????

wire        mem_enq_valid;
wire [ 5:0] mem_enq_preg_rs1;
wire [ 5:0] mem_enq_preg_rs2;
wire [ 5:0] mem_enq_preg_rd;
wire [ 3:0] mem_enq_rob_id;
wire [`DE_TO_DS_BUS-1:0] mem_enq_payload;
wire        mem_enq_rs1_ready;
wire        mem_enq_rs2_ready;
wire        mem_iq_allowin;   // MEM?????????  
//alu0
wire        exe0_allowin;  // ?????  ?????????????
wire        alu0_issue_valid; // ????????????
wire [ 5:0] alu0_issue_preg_rs1;
wire [ 5:0] alu0_issue_preg_rs2;
wire [ 5:0] alu0_issue_preg_rd;
wire [ 3:0] alu0_issue_rob_id;
wire [`DE_TO_DS_BUS-1:0] alu0_issue_payload;

//alu1
wire        exe1_allowin;  // ?????  ?????????????
wire        alu1_issue_valid; // ????????????
wire [ 5:0] alu1_issue_preg_rs1;
wire [ 5:0] alu1_issue_preg_rs2;
wire [ 5:0] alu1_issue_preg_rd;
wire [ 3:0] alu1_issue_rob_id;
wire [`DE_TO_DS_BUS-1:0] alu1_issue_payload;

//mem/priv
wire        mem_exe_allowin;  // ?????  ?????????????
wire        mem_issue_valid; // ????????????
wire [ 5:0] mem_issue_preg_rs1;
wire [ 5:0] mem_issue_preg_rs2;
wire [ 5:0] mem_issue_preg_rd;
wire [ 3:0] mem_issue_rob_id;
wire [`DE_TO_DS_BUS-1:0] mem_issue_payload;


wire [31:0] alu0_operand1;
wire [31:0] alu0_operand2;
wire [31:0] alu1_operand1;
wire [31:0] alu1_operand2;
wire [31:0] mem_operand1;
wire [31:0] mem_operand2;
wire [31:0] alu0_result;
wire [31:0] alu1_result;
wire [31:0] mem_result;


wire rename_is_store_0;
wire rename_is_complex_0;
wire rename_has_dest_0;
wire rename_is_store_1;
wire rename_is_complex_1;
wire rename_has_dest_1;
wire [31:0] rename_pc_0;
wire [31:0] rename_pc_1;
wire [31:0] rename_inst_0;
wire [31:0] rename_inst_1;

wire [31:0] es_pa;
wire [31:0] es_va;
wire [1:0] es_mmu_en;
wire [5:0] es_exc_ecode;
wire es_dmw_hit;
wire [1:0] es_plv;
wire es_uncache_en;

    wire        alu0_wb_valid;
    wire        alu1_wb_valid;
    wire        mem_wb_valid;
    wire [ 3:0] mem_wb_rob_id;
    wire        mem_wb_ex;
    wire [128:0]wb_exception_2;
    wire        wb_inst_tlbsrch;
    wire        wb_inst_tlbrd;
    wire        wb_inst_tlbwr;
    wire        wb_inst_tlbfill;
    wire        wb_inst_invtlb;
    wire        wb_tlb_hit;
    wire [ 4:0] wb_tlb_index;
    wire        mem_ready_go;

    // ==========================================
    // ??? 2?????????????????????
    // ==========================================
    wire        alu0_br_miss;
    wire [31:0] alu0_br_target;
    wire        alu1_br_miss;
    wire [31:0] alu1_br_target;

    // ==========================================
    // ??? 3??MEM0 ?? MEM1 ??????????
    // ==========================================
    wire        mem1_allowin;
    wire        mem0_to_mem1_valid;
    wire [`ES_TO_MS_BUS_WD-1:0] mem0_to_mem1_bus;
    wire        issue_mem0_allowin; // mem_priv_issue ?? mem0_stage ??????

    // ==========================================
    // ??? 4??MEM1 ?? CSR ????????? & ????
    // ==========================================
    wire [13:0] mem1_csr_num;
    wire [31:0] mem1_csr_rdata;
    wire [`WS_TO_CSR_BUS-1:0] com_to_csr_bus;
    wire        ws_llbit_set;
    wire        ws_llbit;
    wire        ws_lladdr_set;
    wire [27:0] ws_lladdr;
    wire        csr_llbit;
    wire [27:0] csr_lladdr;

    // ==========================================
    // ??? 5??ROB ?? Commit ??????????? (???0??1)
    // ==========================================
    wire        rob_head_done_0;
    wire [31:0] rob_head_pc_0;
    wire        rob_head_br_miss_0;
    wire [31:0] rob_head_br_target_0;
    wire        rob_head_ex_0;
    wire [ 4:0] rob_head_areg_0;
    wire [ 5:0] rob_head_new_preg_0;
    wire [ 5:0] rob_head_old_preg_0;
    wire        rob_head_is_store_0;
    wire        rob_head_is_complex_0;
    wire        rob_head_has_dest_0;
    wire [128:0]commit_exception_0;

    wire        rob_head_done_1;
    wire [31:0] rob_head_pc_1;
    wire        rob_head_br_miss_1;
    wire [31:0] rob_head_br_target_1;
    wire        rob_head_ex_1;
    wire [ 4:0] rob_head_areg_1;
    wire [ 5:0] rob_head_new_preg_1;
    wire [ 5:0] rob_head_old_preg_1;
    wire        rob_head_is_store_1;
    wire        rob_head_is_complex_1;
    wire        rob_head_has_dest_1;
    wire [128:0]commit_exception_1;

    // ==========================================
    // ??? 6??Commit ??????????aRAT ?? Freelist ????????
    // ==========================================
    wire [31:0] flush_target;
    wire [ 1:0] commit_st_cnt;

    wire        commit_arat_we_0;
    wire [ 4:0] commit_arat_waddr_0;
    wire [ 5:0] commit_arat_wdata_0;
    wire        commit_freelist_we_0;
    wire [ 5:0] commit_freelist_wdata_0;

    wire        commit_arat_we_1;
    wire [ 4:0] commit_arat_waddr_1;
    wire [ 5:0] commit_arat_wdata_1;
    wire        commit_freelist_we_1;
    wire [ 5:0] commit_freelist_wdata_1;
    
wire [ 5:0] commit_debug_raddr_0;
wire [ 5:0] commit_debug_raddr_1;
wire [31:0] commit_debug_rdata_0;
wire [31:0] commit_debug_rdata_1;    

wire rename_ready_go;

wire ms_mem_we;

wire    es_to_ms_sb_valid;
wire    es_ready_go;
wire ms_valid;

wire gr_we_0;
wire  [ 5:0] preg_rd_0_e;
wire gr_we_1;
wire  [ 5:0] preg_rd_1_e;
wire inst0_is_div;
wire inst1_is_div;

wire sb_empty;
wire es_mem_we_stall;
wire ms_inst_valid_cacop;
wire ms_inst_tlbsrch;
wire ms_inst_tlbrd;
wire ms_inst_tlbwr;
wire ms_inst_tlbfill;
wire ms_inst_invtlb;
wire ms_tlb_hit;
wire [ 4:0] ms_tlb_index;
wire ms_inst_sc_w;
wire ms_sc_success;
wire ms_inst_ll_w;
wire [31:0] ms_pa;
wire ms_uncache_en;
wire ms_inst_dbar;
wire ms_inst_ibar;
wire invtlb_valid;
wire [ 4:0] invtlb_op;
wire [19:0] s1_va_highbits;
wire                                pif_to_fs_valid;
wire [`PIF_TO_FS_BUS_WD-1 : 0]      pif_to_fs_bus;


// to FB (Fetch Buffer / Decode)
wire [3:0]                          fs_to_fb_valid;
wire [`FS_TO_FB_BUS_WD-1  : 0]      fs_to_fb_bus;
wire                                fb_allowin;

// icache ???
wire                                inst_uncache_en;
wire                                inst_tlb_excp_cancel_req;
//wire                                inst_valid;
wire                                inst_addr_ok;
wire                                inst_data_ok;

wire [127:0]                        inst_rdata;


wire [31:0]                     pc_query;
wire [3:0]                      pred_taken;
wire [127:0]                    pred_target;

// TLB (Translation Lookaside Buffer) / MMU ???
wire [31:0]                     inst_vaddr;     // ???????????????  ??  ???????? [31:0]
wire                            s0_valid;
wire [18:0]                     s0_vppn;
wire                            s0_va_bit12;
wire [ 9:0]                     s0_asid;
wire                            s0_ok;
wire [ 9:0]                     csr_asid_asid;
wire [ 5:0]                     IF_tlb_excps;
wire [31:0]                     inst_paddr;
wire                            mmu_inst_uncache_en;  
wire                            fs_allowin;

// 1. ROB ????? Commit ?????????
wire        rob_head_is_br_0;
wire [1:0]  rob_head_br_type_0;
wire        rob_head_br_taken_0;

wire        rob_head_is_br_1;
wire [1:0]  rob_head_br_type_1;
wire        rob_head_br_taken_1;
wire        rob_head_inst_sc_w_0;
wire        rob_head_inst_ll_w_0;
wire [31:0] rob_head_pa_0;
wire        rob_head_uncache_en_0;
wire        rob_head_inst_dbar_0;
wire        rob_head_inst_ibar_0;
wire        rob_head_inst_sc_w_1;
wire        rob_head_inst_ll_w_1;
wire [31:0] rob_head_pa_1;
wire        rob_head_uncache_en_1;
wire        rob_head_inst_dbar_1;
wire        rob_head_inst_ibar_1;
wire [31:0] rob_head_inst_0;
wire [31:0] rob_head_inst_1;
wire        current_rob_empty;

`ifdef DIFFTEST_EN
wire [ 5:0] diff_gpr_preg [31:0];
wire [31:0] diff_regs [31:0];
genvar diff_gpr_i;
generate
    for (diff_gpr_i = 0; diff_gpr_i < 32; diff_gpr_i = diff_gpr_i + 1) begin : gen_diff_gpr_addr
        assign diff_gpr_preg[diff_gpr_i] = u_arat.arat_mem[diff_gpr_i];
    end
endgenerate
wire [31:0] csr_crmd_diff;
wire [31:0] csr_prmd_diff;
wire [31:0] csr_ectl_diff;
wire [31:0] csr_estat_diff;
wire [31:0] csr_era_diff;
wire [31:0] csr_badv_diff;
wire [31:0] csr_eentry_diff;
wire [31:0] csr_tlbidx_diff;
wire [31:0] csr_tlbehi_diff;
wire [31:0] csr_tlbelo0_diff;
wire [31:0] csr_tlbelo1_diff;
wire [31:0] csr_asid_diff;
wire [31:0] csr_save0_diff;
wire [31:0] csr_save1_diff;
wire [31:0] csr_save2_diff;
wire [31:0] csr_save3_diff;
wire [31:0] csr_tid_diff;
wire [31:0] csr_tcfg_diff;
wire [31:0] csr_tval_diff;
wire [31:0] csr_ticlr_diff;
wire [31:0] csr_llbctl_diff;
wire [31:0] csr_tlbrentry_diff;
wire [31:0] csr_dmw0_diff;
wire [31:0] csr_dmw1_diff;
wire [31:0] csr_pgdl_diff;
wire [31:0] csr_pgdh_diff;
`endif

// 2. Commit ????? BPU ????????
wire        bpu_update_en;
wire [31:0] bpu_pc_update;
wire [31:0] bpu_target_update;
wire        bpu_actual_taken;
wire [1:0]  bpu_branch_type_update;

// ALU0 ?????????????????
wire        alu0_exec_update_en;
wire [31:0] alu0_pc_exec;
wire [31:0] alu0_target_exec;
wire [1:0]  alu0_branch_type_exec;
wire        alu0_is_br;
wire        alu0_br_taken;


// ALU1 ?????????????????
wire        alu1_exec_update_en;
wire [31:0] alu1_pc_exec;
wire [31:0] alu1_target_exec;
wire [1:0]  alu1_branch_type_exec;
wire        alu1_is_br;
wire        alu1_br_taken;

wire [31:0] csr_crmd_rvalue; // CRMD:  ?????????????????? (DA/PG/PLV ??)
wire [31:0] csr_asid_rvalue; // ASID:  ?????????????
wire [31:0] csr_dmw0_rvalue; // DMW0:  ???????? 0 ????
wire [31:0] csr_dmw1_rvalue; // DMW1:  ???????? 1 ????

wire                    s0_odd_page;
wire                    s0_found;
wire [INDEX_WD-1:0]     s0_index;
wire [ 5:0]             s0_ps;
wire [19:0]             s0_ppn;
wire                    s0_v;
wire                    s0_d;
wire [ 1:0]             s0_mat;
wire [ 1:0]             s0_plv;
wire                    s0_unbusy;
// --- search port 1 ---
wire [18:0]             s1_vppn;
wire                    s1_odd_page;
wire [ 9:0]             s1_asid;
wire                    s1_valid;
wire                    s1_found;
wire                    s1_ok;
wire [INDEX_WD-1:0]     s1_index;
wire [ 5:0]             s1_ps;
wire [19:0]             s1_ppn;
wire                    s1_v;
wire                    s1_d;
wire [ 1:0]             s1_mat;
wire [ 1:0]             s1_plv;
wire                    s1_unbusy;

// --- write port ---
wire                    we;
wire [INDEX_WD-1:0]     w_index;
wire [18:0]             w_vppn;
wire [ 9:0]             w_asid;
wire                    w_g;
wire [ 5:0]             w_ps;
wire                    w_e;
wire                    w_v0;
wire                    w_d0;
wire [ 1:0]             w_mat0;
wire [ 1:0]             w_plv0;
wire [19:0]             w_ppn0;
wire                    w_v1;
wire                    w_d1;
wire [ 1:0]             w_mat1;
wire [ 1:0]             w_plv1;
wire [19:0]             w_ppn1;

// --- read port ---
wire [INDEX_WD-1:0]     r_index;
wire [18:0]             r_vppn;
wire [ 9:0]             r_asid;
wire                    r_g;
wire [ 5:0]             r_ps;
wire                    r_e;
wire                    r_v0;
wire                    r_d0;
wire [ 1:0]             r_mat0;
wire [ 1:0]             r_plv0;
wire [19:0]             r_ppn0;
wire                    r_v1;
wire                    r_d1;
wire [ 1:0]             r_mat1;
wire [ 1:0]             r_plv1;
wire [19:0]             r_ppn1;

// --- invalid port ---
wire                    inv_en;
wire [ 4:0]             inv_op;
wire [ 9:0]             inv_asid;
wire [18:0]             inv_vpn;


wire        tlbrd_we;
wire        tlbsrch_we;
wire        tlbsrch_hit;
wire [ 4:0] tlbsrch_hit_index;

wire [18:0] csr_tlbehi_vppn;
wire [ 4:0] csr_tlbidx_index;

wire                      dmw_hit;
wire [ 1:0]               plv;
wire        disable_cache;
wire [3:0] current_rob_head;
wire br_hit;
wire if_untlb_en;
wire exe_untlb_en;
wire idle_flush;
wire       if_cancel_req;
wire [31:0] if_cancel_target;
wire [31:0] sb_fwd_data;
wire [3:0]  sb_fwd_strb;

PIF u_PIF (
    .clk                    (clk                    ), // input
    .reset                  (reset                  ), // input

    // bpu ???
    .pc_query               (pc_query               ), // output [31:0]
    .pred_taken             (pred_taken             ), // input
    .pred_target            (pred_target            ), // input [31:0]
    .predict_slot           (predict_slot           ),
    // to TLB / MMU
    .inst_vaddr             (inst_vaddr             ), // output [31:0]
    .s0_valid               (s0_valid               ), // output
    .s0_vppn                (s0_vppn                ), // output [18:0]
    .s0_va_bit12            (s0_va_bit12            ), // output
    .s0_asid                (s0_asid                ), // output [9:0]
    .s0_ok                  (s0_ok                  ), // input
    .csr_asid_asid          (csr_asid_asid          ), // input [9:0]
    .IF_tlb_excps           (IF_tlb_excps           ), // input [5:0]
    .inst_paddr             (inst_paddr             ), // input [31:0]
    .mmu_inst_uncache_en    (mmu_inst_uncache_en    ), // input
    .untlb_en               (if_untlb_en            ),

    // to FS
    .pif_to_fs_valid        (pif_to_fs_valid        ), // output
    .pif_to_fs_bus          (pif_to_fs_bus          ), // output [`PIF_TO_FS_BUS_WD-1:0]
    .fs_allowin             (fs_allowin             ), // input

    // ex
    .ex                     (ws_ex                   ), // input
    .ertn                   (ertn_flush              ), // input
    .fs_reflush             (ws_reflush              ), // input
    .ex_entry               (ex_entry                ), // input [31:0]
    .ex_era                 (era_entry               ), // input [31:0]
    .fs_reflush_target      (flush_target            ),  // input [31:0]
    .idle_flush             (idle_flush),
    .has_int                (has_int),
    .if_cancel_req          (if_cancel_req),
    .if_cancel_target       (if_cancel_target)
);
wire        exe_btb_update_en;
wire [31:0] exe_pc;
wire [31:0] exe_br_target;
wire [ 1:0] exe_br_type;
assign exe_btb_update_en = alu0_exec_update_en | alu1_exec_update_en;
assign exe_pc            = alu0_exec_update_en ? alu0_pc_exec          : alu1_pc_exec;
assign exe_br_target     = alu0_exec_update_en ? alu0_target_exec      : alu1_target_exec;
assign exe_br_type       = alu0_exec_update_en ? alu0_branch_type_exec : alu1_branch_type_exec;
bp_unit #(
    .ADDR_WIDTH      (32),
    .INDEX_BITS      (8),
    .HIST_BITS       (8),
    .RAS_DEPTH_BITS  (4)
) u_bp_unit (
    .clk                    (clk),
    .reset                  (reset),
    .flush                  (ws_reflush),

    // ========== 1. ?????? (????? PIF ??) ==========
    .pc_query               (pc_query),                // ?? PIF ???????? PC
    .pred_taken             (pred_taken),              // ????? PIF ?????????
    .pred_target            (pred_target),             // ????? PIF ????????
    .predict_slot           (predict_slot),
    // ========== 2. ????????? (????? Commit ??) ==========
    .update_en              (bpu_update_en),           // ?????? commit_stage
    .pc_update              (bpu_pc_update),
    .actual_taken           (bpu_actual_taken),

    // ========== 3. ????????? BTB (????? EXE ??) ==========
    // ???????????????? ALU/Branch ??????????
    .exec_update_en         (exe_btb_update_en),       // EXE ????????????? BTB ?????
    .pc_exec                (exe_pc),                  // EXE ???????????? PC
    .target_exec            (exe_br_target),           // EXE ?????????????
    .branch_type_exec       (exe_br_type)              // EXE ????????????????
);

IF u_IF (
    .clk                        (clk                        ), // input
    .reset                      (reset                      ), // input
    .flush                      (ws_reflush                 ), // input???????????csr_we??????ertn????????

    // from PIF
    .pif_to_fs_valid            (pif_to_fs_valid            ), // input
    .pif_to_fs_bus              (pif_to_fs_bus              ), // input
    .fs_allowin                 (fs_allowin                 ), // output

    // to FB
    .fs_to_fb_valid             (fs_to_fb_valid             ), // output
    .fs_to_fb_bus               (fs_to_fb_bus               ), // output
    .fb_allowin                 (fb_allowin                 ), // input

    // icache ???
    .inst_uncache_en            (icache_uncache_en            ), // output
    .inst_tlb_excp_cancel_req   (icache_tlb_excp_cancel       ), // output
    .inst_valid                 (icache_valid                 ), // output
    .inst_addr_ok               (icache_addr_ok               ), // input
    .inst_data_ok               (icache_data_ok               ), // input
    .inst_index                 (icache_index                 ), // output
    .inst_tag                   (icache_tag                   ), // output
    .inst_offset                (icache_offset                ), // output
    .inst_rdata                 (icache_rdata                 ),
    .if_cancel_req              (if_cancel_req),
    .if_cancel_target           (if_cancel_target)
    
);

    assign icache_op    = 1'b0;
    assign icache_wstrb = 4'b0;
    assign icache_wdata = 32'b0;

reg  [3:0]                          fs_to_fb_valid_r;
reg  [`FS_TO_FB_BUS_WD-1  : 0]      fs_to_fb_bus_r;
assign fb_allowin = !(|fs_to_fb_valid_r) || enq_allowin;

always @(posedge clk) begin
    if (reset || ws_reflush) begin
        fs_to_fb_valid_r <= 4'b0;
    end
    else if (fb_allowin) begin
        fs_to_fb_valid_r <= fs_to_fb_valid;
        if (|fs_to_fb_valid) begin
            fs_to_fb_bus_r <= fs_to_fb_bus;
        end
    end
end

fetch_buffer fetch_buffer(
    .clk            (clk),
    .reset          (reset),
    .flush          (ws_reflush),
    .enq_valid      (fs_to_fb_valid_r),
    .enq_bus        (fs_to_fb_bus_r),
    .enq_allowin    (enq_allowin),
    .deq_valid      (deq_valid),
    .deq_bus_0        (deq_bus_0),
    .deq_bus_1        (deq_bus_1),
    .deq_pop_count     (deq_pop_count)
  //  .es_is_div        (inst0_is_div | inst1_is_div)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),


    .deq_valid     (deq_valid ),
    .deq_bus_0     (deq_bus_0   ), 
    .deq_bus_1     (deq_bus_1),
    .deq_pop_count (deq_pop_count),
    .ds_to_rename_valid_0 (ds_to_rename_valid_0),
    .ds_to_rename_bus_0   (ds_to_rename_bus_0),
    .ds_to_rename_valid_1  (ds_to_rename_valid_1),
    .ds_to_rename_bus_1     (ds_to_rename_bus_1),
    .ds_reflush      (ws_reflush),
    .ds_has_int (has_int),
    .rn_allowin_cnt (rn_allowin_cnt),
    .ds_llbit (csr_llbit),
    .write_buffer_empty (write_buffer_empty),
    .dcache_empty (dcache_empty),
    .rob_empty    (current_rob_empty)
);

rename_top rename_top(
    .clk        (clk),
    .reset      (reset),
    .flush      (ws_reflush),
    .ds_to_rename_valid_0 (ds_to_rename_valid_0),
    .ds_to_rename_bus_0   (ds_to_rename_bus_0),
    .ds_to_rename_valid_1 (ds_to_rename_valid_1),
    .ds_to_rename_bus_1   (ds_to_rename_bus_1),
    .freelist_free_cnt    (freelist_free_cnt),
    .req_preg_0           (req_preg_0),
    .req_preg_1           (req_preg_1),
    .alloc_preg_0         (alloc_preg_0),
    .alloc_preg_1         (alloc_preg_1),
    .rob_free_cnt          (rob_free_cnt),
    .req_rob_0              (req_rob_0),
    .req_rob_1              (req_rob_1),
    .rob_id_0               (rob_id_0),
    .rob_id_1               (rob_id_1),
    .rename_is_store_0     (rename_is_store_0),
    .rename_is_complex_0   (rename_is_complex_0),
    .rename_has_dest_0      (rename_has_dest_0),
    .rename_is_store_1      (rename_is_store_1),
    .rename_is_complex_1    (rename_is_complex_1),
    .rename_has_dest_1      (rename_has_dest_1),
    .rename_pc_0            (rename_pc_0),
    .rename_pc_1            (rename_pc_1),
    .rename_inst_0          (rename_inst_0),
    .rename_inst_1          (rename_inst_1),
    .srat_raddr1_0        (srat_raddr1_0),
    .srat_raddr2_0        (srat_raddr2_0),
    .srat_rdata1_0        (srat_rdata1_0),
    .srat_rdata2_0        (srat_rdata2_0),

    .srat_raddr1_1        (srat_raddr1_1),
    .srat_raddr2_1        (srat_raddr2_1),
    .srat_rdata1_1        (srat_rdata1_1),
    .srat_rdata2_1        (srat_rdata2_1),  
    
    .srat_we_0            (srat_we_0),
    .srat_waddr_0         (srat_waddr_0),
    .srat_wdata_0         (srat_wdata_0),

    .srat_we_1            (srat_we_1),
    .srat_waddr_1         (srat_waddr_1),
    .srat_wdata_1         (srat_wdata_1),  
    
    .rn_to_issue_valid_0           (rn_to_issue_valid_0),
    .preg_rs1_0           (preg_rs1_0),
    .preg_rs2_0           (preg_rs2_0),
    .preg_rd_0            (preg_rd_0),
    .rn_rob_id_0          (rn_rob_id_0),

    .rn_to_issue_valid_1           (rn_to_issue_valid_1),
    .preg_rs1_1           (preg_rs1_1),
    .preg_rs2_1           (preg_rs2_1),
    .preg_rd_1            (preg_rd_1),
    .rn_rob_id_1          (rn_rob_id_1), 
    
     // 7. ????? Busy Table ????  ??????
     .set_preg_busy_0      (set_preg_busy_0),
     .busy_preg_id_0       (busy_preg_id_0),
     .set_preg_busy_1      (set_preg_busy_1),
     .busy_preg_id_1       (busy_preg_id_1),

     // 8. ?????????????????
     .dp_accept_cnt        (dp_accept_cnt),        // Dispatch ???? Rename ???????
     .rn_allowin_cnt       (rn_allowin_cnt),       // Rename ???? DS ?????????

     // 9. ????????????? (??????? ROB ??????)
     .areg_dest_0           (areg_dest0),
     .areg_dest_1           (areg_dest1),
     .rn_to_issue_bus_0  (rn_to_issue_bus_0),
     .rn_to_issue_bus_1  (rn_to_issue_bus_1),
     .inst_idle_0(inst_idle_0),
     .inst_idle_1(inst_idle_1),
     .rename_is_load_0(is_load_0),
     .rename_is_load_1(is_load_1)
    // .rename_ready_go    (rename_ready_go)
    // .srat_dest_rdata0     (srat_dest_rdata0),
    // .srat_dest_rdata1     (srat_dest_rdata1)       
);

dispatch u_dispatch (
        // 1. ???? Rename ???????? (??? 0)
        .clk             (clk),
        .reset           (reset),
        .rn_valid_0         (rn_to_issue_valid_0),
        .rn_is_mem_priv_0   (rn_to_issue_bus_0[256]), 
        .rn_preg_rs1_0      (preg_rs1_0),
        .rn_preg_rs2_0      (preg_rs2_0),
        .rn_preg_rd_0       (preg_rd_0),
        .rn_rob_id_0        (rn_rob_id_0),
        .rn_payload_0       (rn_to_issue_bus_0),          // ????? rename_top ???? payload
        .rn_rs1_ready_0     (rn_rs1_ready_0),        // ???? Busy Table ???????
        .rn_rs2_ready_0     (rn_rs2_ready_0),        // ???? Busy Table ???????


        // 1. ???? Rename ???????? (??? 1)
        .rn_valid_1         (rn_to_issue_valid_1),
        .rn_is_mem_priv_1   (rn_to_issue_bus_1[256]), 
        .rn_preg_rs1_1      (preg_rs1_1),
        .rn_preg_rs2_1      (preg_rs2_1),
        .rn_preg_rd_1       (preg_rd_1),
        .rn_rob_id_1        (rn_rob_id_1),
        .rn_payload_1       (rn_to_issue_bus_1),          // ????? rename_top ???? payload
        .rn_rs1_ready_1     (rn_rs1_ready_1),        // ???? Busy Table ???????
        .rn_rs2_ready_1     (rn_rs2_ready_1),        // ???? Busy Table ???????


        // ?????? Rename/ID ??
        .dp_accept_cnt      (dp_accept_cnt),         // ???? Rename ???????????????????


        // 2. ???? ALU_0 ???? (Issue Queue 0)
        .alu0_enq_valid     (alu0_enq_valid),
        .alu0_enq_preg_rs1  (alu0_enq_preg_rs1),
        .alu0_enq_preg_rs2  (alu0_enq_preg_rs2),
        .alu0_enq_preg_rd   (alu0_enq_preg_rd),
        .alu0_enq_rob_id    (alu0_enq_rob_id),
        .alu0_enq_payload   (alu0_enq_payload),
        .alu0_enq_rs1_ready (alu0_enq_rs1_ready),
        .alu0_enq_rs2_ready (alu0_enq_rs2_ready),
        .alu0_iq_allowin    (alu0_iq_allowin),       // ALU0 ??????  ??????????

        // 3. ???? ALU_1 ???? (Issue Queue 1)
        .alu1_enq_valid     (alu1_enq_valid),
        .alu1_enq_preg_rs1  (alu1_enq_preg_rs1),
        .alu1_enq_preg_rs2  (alu1_enq_preg_rs2),
        .alu1_enq_preg_rd   (alu1_enq_preg_rd),
        .alu1_enq_rob_id    (alu1_enq_rob_id),
        .alu1_enq_payload   (alu1_enq_payload),
        .alu1_enq_rs1_ready (alu1_enq_rs1_ready),
        .alu1_enq_rs2_ready (alu1_enq_rs2_ready),
        .alu1_iq_allowin    (alu1_iq_allowin),       // ALU1 ??????  ??????????

        // 4. ???? MEM/PRIV ???? (Issue Queue 2)
        .mem_enq_valid      (mem_enq_valid),
        .mem_enq_preg_rs1   (mem_enq_preg_rs1),
        .mem_enq_preg_rs2   (mem_enq_preg_rs2),
        .mem_enq_preg_rd    (mem_enq_preg_rd),
        .mem_enq_rob_id     (mem_enq_rob_id),
        .mem_enq_payload    (mem_enq_payload),
        .mem_enq_rs1_ready  (mem_enq_rs1_ready),
        .mem_enq_rs2_ready  (mem_enq_rs2_ready),
        .mem_iq_allowin     (mem_iq_allowin)         // MEM/PRIV ??????  ??????????
        //.rename_ready_go     (rename_ready_go)
);


issue_queue u_issue_queue_alu0 (
        .clk             (clk),
        .reset           (reset),
        .flush           (ws_reflush),          // ???????????

        // 1. ????? (???? Dispatch   ?????? alu0 ???)
        .enq_valid       (alu0_enq_valid),
        .enq_preg_rs1    (alu0_enq_preg_rs1),
        .enq_preg_rs2    (alu0_enq_preg_rs2),
        .enq_preg_rd     (alu0_enq_preg_rd),
        .enq_rob_id      (alu0_enq_rob_id),
        .enq_payload     (alu0_enq_payload),
        .enq_rs1_ready   (alu0_enq_rs1_ready),
        .enq_rs2_ready   (alu0_enq_rs2_ready),
        .iq_allowin      (alu0_iq_allowin),     // ?????? Dispatch??ALU0?????????  

        // 2. CDB ????????? (??????? 3 ????  ??)
        .cdb_we_0        (cdb_we_0),            // ?? ALU_0 ???
        .cdb_preg_0      (cdb_preg_0),
        .cdb_we_1        (cdb_we_1),            // ?? ALU_1 ???
        .cdb_preg_1      (cdb_preg_1),
        .cdb_we_2        (cdb_we_2),            // ?? MEM/LSU ???
        .cdb_preg_2      (cdb_preg_2),    
    /*    .gr_we_0         (gr_we_0),
        .preg_rd_0       (preg_rd_0_e),
        .gr_we_1         (gr_we_1),
        .preg_rd_1       (preg_rd_1_e),*/
        // 3. ????/?????? (??????????????? PRF ?? ALU_0)
        .ex_allowin      (exe0_allowin),        // ALU_0 ????????????????
        .issue_valid     (alu0_issue_valid),    // ?????????????? ALU_0
        .issue_preg_rs1  (alu0_issue_preg_rs1),
        .issue_preg_rs2  (alu0_issue_preg_rs2),
        .issue_preg_rd   (alu0_issue_preg_rd),
        .issue_rob_id    (alu0_issue_rob_id),
        .issue_payload   (alu0_issue_payload)
);


    // 2. ????????? 1 (?? ALU_1 ???)
issue_queue u_issue_queue_alu1 (
        .clk             (clk),
        .reset           (reset),
        .flush           (ws_reflush),          // ???????????

        // 1. ????? (???? Dispatch   ?????? alu1 ???)
        .enq_valid       (alu1_enq_valid),
        .enq_preg_rs1    (alu1_enq_preg_rs1),
        .enq_preg_rs2    (alu1_enq_preg_rs2),
        .enq_preg_rd     (alu1_enq_preg_rd),
        .enq_rob_id      (alu1_enq_rob_id),
        .enq_payload     (alu1_enq_payload),
        .enq_rs1_ready   (alu1_enq_rs1_ready),
        .enq_rs2_ready   (alu1_enq_rs2_ready),
        .iq_allowin      (alu1_iq_allowin),     // ?????? Dispatch??ALU1?????????  

        // 2. CDB ????????? (?????????? 3 ????  ??)
        .cdb_we_0        (cdb_we_0),
        .cdb_preg_0      (cdb_preg_0),
        .cdb_we_1        (cdb_we_1),
        .cdb_preg_1      (cdb_preg_1),
        .cdb_we_2        (cdb_we_2),
        .cdb_preg_2      (cdb_preg_2),    
   /*     .gr_we_0         (gr_we_0),
        .preg_rd_0       (preg_rd_0_e),
        .gr_we_1         (gr_we_1),
        .preg_rd_1       (preg_rd_1_e),*/
        // 3. ????/?????? (??????????????? PRF ?? ALU_1)
        .ex_allowin      (exe1_allowin),        // ALU_1 ????????????????
        .issue_valid     (alu1_issue_valid),    // ?????????????? ALU_1
        .issue_preg_rs1  (alu1_issue_preg_rs1),
        .issue_preg_rs2  (alu1_issue_preg_rs2),
        .issue_preg_rd   (alu1_issue_preg_rd),
        .issue_rob_id    (alu1_issue_rob_id),
        .issue_payload   (alu1_issue_payload)
);


//mem????

order_queue mem_priv_issue (
        .clk             (clk),
        .reset           (reset),
        .flush           (ws_reflush),          // ???????????

        // 1. ????? (?????? Dispatch   ?????? mem ???)
        .enq_valid       (mem_enq_valid),
        .enq_preg_rs1    (mem_enq_preg_rs1),
        .enq_preg_rs2    (mem_enq_preg_rs2),
        .enq_preg_rd     (mem_enq_preg_rd),
        .enq_rob_id      (mem_enq_rob_id),
        .enq_payload     (mem_enq_payload),
        .enq_rs1_ready   (mem_enq_rs1_ready),
        .enq_rs2_ready   (mem_enq_rs2_ready),
        
        .iq_allowin      (mem_iq_allowin),      // ?????? Dispatch???????  ??  ?  
        .sb_empty         (sb_empty),
        .es_mem_we_stall (es_mem_we_stall),
        // 2. CDB ????????? (??????? 3 ????  ??)
        .cdb_we_0        (cdb_we_0),            // ?? ALU_0 ???
        .cdb_preg_0      (cdb_preg_0),
        .cdb_we_1        (cdb_we_1),            // ?? ALU_1 ???
        .cdb_preg_1      (cdb_preg_1),
        .cdb_we_2        (cdb_we_2),            // ?? MEM/LSU ??????
        .cdb_preg_2      (cdb_preg_2),    
     /*   .gr_we_0         (gr_we_0),
        .preg_rd_0       (preg_rd_0_e),
         .gr_we_1         (gr_we_1),
        .preg_rd_1       (preg_rd_1_e),*/
        // 3. ????/?????? (??????????????? PRF ?? MEM/PRIV ??  ??)
        .ex_allowin      (issue_mem0_allowin),     // ???? MEM/PRIV ??  ??????????????????
        .issue_valid     (mem_issue_valid),     // ?????????????????
        .issue_preg_rs1  (mem_issue_preg_rs1),  // ? PRF ????
        .issue_preg_rs2  (mem_issue_preg_rs2),  // ? PRF ????
        .issue_preg_rd   (mem_issue_preg_rd),   // ?????????????? EXE ??
        .issue_rob_id    (mem_issue_rob_id),    // ???? ROB ID ? EXE ??
        .issue_payload   (mem_issue_payload)    // ?????????????? EXE ??
);


regfile phy_regfile(
        .clk            (clk),
        .reset          (reset),
        .raddr1_0       (alu0_issue_preg_rs1),
        .raddr2_0       (alu0_issue_preg_rs2),
        .rdata1_0       (alu0_operand1),
        .rdata2_0       (alu0_operand2),
        
        .raddr1_1       (alu1_issue_preg_rs1),
        .raddr2_1       (alu1_issue_preg_rs2),
        .rdata1_1       (alu1_operand1),
        .rdata2_1       (alu1_operand2),
        
        .raddr1_2       (mem_issue_preg_rs1),
        .raddr2_2       (mem_issue_preg_rs2),
        .rdata1_2       (mem_operand1),
        .rdata2_2       (mem_operand2),
        
        
        .we_0           (cdb_we_0),
        .waddr_0        (cdb_preg_0),
        .wdata_0        (alu0_result),
        
        .we_1           (cdb_we_1),
        .waddr_1        (cdb_preg_1),
        .wdata_1        (alu1_result),
        
        .we_2           (cdb_we_2),
        .waddr_2        (cdb_preg_2),
        .wdata_2        (mem_result),
        .debug_raddr_0  (commit_debug_raddr_0),
        .debug_raddr_1  (commit_debug_raddr_1),
        .debug_rdata_0  (commit_debug_rdata_0),
        .debug_rdata_1  (commit_debug_rdata_1)
`ifdef DIFFTEST_EN
        ,
        .diff_raddr     (diff_gpr_preg),
        .diff_rdata     (diff_regs)
`endif
        
);



// ALU 0 ??  ??

exe_stage u_alu0_exe (
        .clk             (clk),
        .reset           (reset),
        .es_reflush      (ws_reflush),          // ????????

        // 1. ???????????????? (???? u_issue_queue_alu0)
        .es_allowin      (exe0_allowin),        // ??????? ALU0 ???????
        .issue_valid     (alu0_issue_valid),    // ??????????????
        .issue_rob_id    (alu0_issue_rob_id),   // ROB ID
        .issue_payload   (alu0_issue_payload),  // ??????????
        .issue_preg_rd   (alu0_issue_preg_rd),  // ??????????????

        // 2. ????????????? (???? phy_regfile ????? 0)
        .operand1        (alu0_operand1),            // PRF ????????????? 1
        .operand2        (alu0_operand2),            // PRF ????????????? 2
        
        .es_ready_go     (alu0_wb_valid),
        // 3. ???? CDB ???? (  ?? PRF????????  ??? ROB ????)
        .rob_id       (cdb_rob_id_0),        // ???? ROB ?????????????
        .es_gr_we        (cdb_we_0),            // ?????
        .es_preg_rd      (cdb_preg_0),          //   ??????????????
        .es_result       (alu0_result),         // ????????????
        .br_mispred        (alu0_br_miss),
        .br_target       (alu0_br_target),
   //     .gr_we_i         (gr_we_0),
  //      .preg_rd_i       (preg_rd_0_e),
      //????????????? (????? MUX ?? ROB)
        .exec_update_en      (alu0_exec_update_en),  
        .pc_exec             (alu0_pc_exec),
        .target_exec         (alu0_target_exec),
        .branch_type_exec    (alu0_branch_type_exec),
        .es_br               (alu0_is_br),
        .br_taken            (alu0_br_taken)          // ???????????? ROB ?? wb_br_taken_0
);


// ALU 1 ??  ??
exe_stage u_alu1_exe (
        .clk             (clk),
        .reset           (reset),
        .es_reflush      (ws_reflush),          // ????????

        // 1. ???????????????? (???? u_issue_queue_alu1)
        .es_allowin      (exe1_allowin),        // ??????? ALU1 ???????
        .issue_valid     (alu1_issue_valid),    // ??????????????
        .issue_rob_id   (alu1_issue_rob_id),   // ROB ID
        .issue_payload   (alu1_issue_payload),  // ??????????
        .issue_preg_rd   (alu1_issue_preg_rd),  // ??????????????

        // 2. ????????????? (???? phy_regfile ????? 1)
        .operand1        (alu1_operand1),            // PRF ????????????? 1
        .operand2        (alu1_operand2),            // PRF ????????????? 2

        // 3. ???? CDB ???? (  ?? PRF????????  ??? ROB ????)
        .es_ready_go     (alu1_wb_valid),
        .rob_id       (cdb_rob_id_1),        // ???? ROB ?????????????
        .es_gr_we        (cdb_we_1),            // ?????
        .es_preg_rd      (cdb_preg_1),          //   ??????????????
        .es_result       (alu1_result),         // ????????????
        .br_mispred        (alu1_br_miss),
        .br_target       (alu1_br_target),
     //   .gr_we_i         (gr_we_1),
     //   .preg_rd_i       (preg_rd_1_e),
    //????????????? (????? MUX ?? ROB)
        .exec_update_en      (alu1_exec_update_en),   
        .pc_exec             (alu1_pc_exec),
        .target_exec         (alu1_target_exec),
        .branch_type_exec    (alu1_branch_type_exec),
        .es_br               (alu1_is_br),
        .br_taken            (alu1_br_taken)          // ???????????? ROB ?? wb_br_taken_1
);

    // ?????  ?? (MEM0 Stage - ????????Store Buffer????)
mem0_stage u_mem0_stage (
        .clk               (clk),
        .reset             (reset),
        .es_reflush        (ws_reflush),           // ????????

        // 1. ???????????????? (???? mem_issue_queue)
        .issue_es_allowin  (issue_mem0_allowin),          // ??????? MEM0 ???????
        .issue_valid       (mem_issue_valid),      // ?????????????  ???
        .issue_rob_id      (mem_issue_rob_id),     // ROB ID
        .issue_payload     (mem_issue_payload),    // ?????????????
        .issue_preg_rd     (mem_issue_preg_rd),    // ??????????????
        .sb_empty          (sb_empty),
        .es_mem_we_stall    (es_mem_we_stall),

        // 2. ????????????? (???? PRF ??? 3 ?????????)
        .operand1          (mem_operand1),             // PRF ?????????? (rj)
        .operand2          (mem_operand2),             // PRF ?????? Store ???? (rkd)

        // 3. ???????? (????????? MEM1 ??)
        .ms_allowin        (mem1_allowin),         // MEM1 ???? MEM0 ???????
        .es_to_ms_valid    (mem0_to_mem1_valid),   // MEM0 ?????? MEM1
        .es_to_ms_bus      (mem0_to_mem1_bus),     // ???????????????????????

        // 4. Data SRAM ??? (?? Store Buffer ??????)
        .data_sram_en      (dcache_valid),         // ??????????
        .data_sram_wr      (dcache_op),         // ??  ??? (0:??, 1:  )
        .data_sram_we      (dcache_wstrb),         // ???  ???
        .data_sram_size    (dcache_size),       // ????   (b, h, w)
        .data_sram_wdata   (dcache_wdata),      //   ??????
        .data_sram_addr_ok (dcache_addr_ok),    // SRAM ?????????
        .data_sram_data_ok (dcache_data_ok),    // SRAM ????????? (???? MEM0 ???????????????)
        .dcache_index        (dcache_index),
        .dcache_offset       (dcache_offset),
        .preld_en            (preld_en),
        //cache ins
        .icache_unbusy       (icache_unbusy),
        .icacop_op_en        (icacop_op_en),
        .dcacop_op_en        (dcacop_op_en),
        .cacop_op_mode       (cacop_op_mode),
        // 5. Commit ?????? (????????  ???????)
        .commit_st_en      (commit_st_cnt)      ,   // ???? Store Buffer ???????  ??? Store ??????
        .ms_mem_we         (ms_mem_we),
        .es_to_ms_sb_valid (es_to_ms_sb_valid),
        .es_ready_go       (es_ready_go),
        .ms_valid          (ms_valid),
            // to tlb
        .s1_va_highbits           (s1_va_highbits),
        .s1_asid                  (s1_asid),
        .s1_valid                 (s1_valid),
        .s1_ok                    (s1_ok),
        .invtlb_valid             (invtlb_valid),
        .invtlb_op                (invtlb_op),
        // from csr, used for tlbsrch
        .csr_asid_asid            (csr_asid_asid),
        .csr_tlbehi_vppn          (csr_tlbehi_vppn),
        // from mmu
        .es_exc_ecode               (es_exc_ecode),
        .va                         (es_va),
        .mmu_en                     (es_mmu_en),
        .pa                         (es_pa),
        .plv                        (es_plv),
        .dmw_hit                    (es_dmw_hit),
        .es_uncache_en              (es_uncache_en),
        .llbit                      (csr_llbit),
        .lladdr                     (csr_lladdr),
        .rob_head_id    (current_rob_head),
        .untlb_en                   (exe_untlb_en),
        .es_mem_we (es_mem_we),
        .rand_idx(rand_idx),
        .s1_found        (s1_found),
        .s1_index        (s1_index),
        .sb_fwd_data     (sb_fwd_data),
        .sb_fwd_strb     (sb_fwd_strb)
);


// ???  ??? (MEM1 Stage - ????????CSR?????????)
mem_stage u_mem1_stage (
        .clk                 (clk),
        .reset               (reset),
        .ms_reflush          (ws_reflush),           // ????????

        // 1. ???????? (???????? MEM0)
        .ms_allowin          (mem1_allowin),         // ???? MEM0 ???????  ???
        .es_to_ms_valid      (mem0_to_mem1_valid),   // MEM0 ???????????  ???
        .es_to_ms_bus        (mem0_to_mem1_bus),     // MEM0 ????????????? (??????????????)

        // 2. Data SRAM ??????
        .dcache_uncache_en   (dcache_uncache_en),
        .ms_dcache_tag       (dcache_tag),
        .data_sram_rdata     (dcache_rdata),      // ??????????????????
        .data_sram_data_ok   (dcache_data_ok),    // ?????????????  ???
        .ms_sb_fwd_data      (sb_fwd_data),
        .ms_sb_fwd_strb      (sb_fwd_strb),
        .dcache_cancel  (dcache_tlb_excp_cancel),

        // 3. ????? CSR ???????? (??? CSR ???)
        .csr_num             (mem1_csr_num),         // ???? CSR ????????????
        .csr_rdata           (mem1_csr_rdata),       // ???? CSR ?????????????????????

        // 4. ???? CDB ?? (?  ????????? PRF??????????????)
        .cdb_we_2            (cdb_we_2),             // ???? CDB ??  ???
        .ms_preg_rd          (cdb_preg_2),           // ???? CDB ?????????????
        .ms_final_result     (mem_result),          // ???? CDB ??????  ?????? (????/CSR?/ALU?)

        // 5. ROB   ???? (?????????????)
        .ms_wb_valid         (mem_wb_valid),         // ???? ROB ?? wb_valid_2 (??????????????)
        .ms_rob_id           (mem_wb_rob_id),        // ???? ROB ?? wb_rob_id_2
        .ms_ex               (mem_wb_ex),            // ???? ROB ?? wb_ex_2
        .ms_exception        (wb_exception_2),      // ???? ROB ?? wb_exception_2 (129  ?????)
        .ms_mem_we           (ms_mem_we),
        .es_to_ms_sb_valid (es_to_ms_sb_valid),
        .es_ready_go       (es_ready_go),
        .ms_to_sb_valid    (ms_valid),
        .ms_inst_valid_cacop (ms_inst_valid_cacop),
        .ms_inst_tlbsrch   (ms_inst_tlbsrch),
        .ms_inst_tlbrd   (ms_inst_tlbrd),
        .ms_inst_tlbwr   (ms_inst_tlbwr),
        .ms_inst_tlbfill (ms_inst_tlbfill),
        .ms_tlb_hit      (ms_tlb_hit),
        .ms_tlb_index    (ms_tlb_index),
        .ms_inst_sc_w    (ms_inst_sc_w),
        .ms_sc_success   (ms_sc_success),
        .ms_inst_ll_w    (ms_inst_ll_w),
        .ms_pa           (ms_pa),
        .ms_uncache_en   (ms_uncache_en),
        .ms_inst_dbar    (ms_inst_dbar),
        .ms_inst_ibar    (ms_inst_ibar),
        .ms_va            (wb_va),
        .ms_store_wdata(ms_store_wdata)
);

// ???? (Commit Stage 
commit_stage u_commit_stage (
            .clk                (clk),
            .reset              (reset),
        // ---------------------------------------------------------
        // 1. ??? ROB ??? (Head) ???? (????? ROB ?????)
        // ---------------------------------------------------------
        // --- ??? 0 (????) ---
        .rob_head_done_0        (rob_head_done_0),    
        .rob_head_pc_0          (rob_head_pc_0),      
        .rob_head_br_miss_0     (rob_head_br_miss_0), 
        .rob_head_br_target_0   (rob_head_br_target_0),
        .rob_head_ex_0          (rob_head_ex_0),       
        .rob_head_areg_0        (rob_head_areg_0),     
        .rob_head_new_preg_0    (rob_head_new_preg_0), 
        .rob_head_old_preg_0    (rob_head_old_preg_0), 
        .rob_head_is_store_0    (rob_head_is_store_0), 
        .rob_head_is_complex_0  (rob_head_is_complex_0), 
        .rob_head_has_dest_0    (rob_head_has_dest_0),   
        .rob_head_exception_0   (commit_exception_0),  // ???????????? ROB ????????????
        .rob_head_is_br_0       (rob_head_is_br_0),     
        .rob_head_br_type_0     (rob_head_br_type_0),   
        .rob_head_br_taken_0    (rob_head_br_taken_0), 
        .rob_head_inst_tlbsrch_0 (rob_head_inst_tlbsrch_0),
        .rob_head_inst_tlbrd_0   (rob_head_inst_tlbrd_0),
        .rob_head_inst_tlbwr_0   (rob_head_inst_tlbwr_0),
        .rob_head_inst_tlbfill_0 (rob_head_inst_tlbfill_0),
        .rob_head_tlb_hit_0      (rob_head_tlb_hit_0),
        .rob_head_tlb_index_0    (rob_head_tlb_index_0),
        .rob_head_inst_valid_cacop_0 (rob_head_inst_valid_cacop_0),
        .rob_head_inst_sc_w_0     (rob_head_inst_sc_w_0),
        .rob_head_inst_ll_w_0     (rob_head_inst_ll_w_0),
        .rob_head_pa_0            (rob_head_pa_0),
        .rob_head_uncache_en_0    (rob_head_uncache_en_0),
        .rob_head_inst_dbar_0     (rob_head_inst_dbar_0),
        .rob_head_inst_ibar_0     (rob_head_inst_ibar_0),
        // --- ??? 1 ---
        .rob_head_done_1        (rob_head_done_1),
        .rob_head_pc_1          (rob_head_pc_1),
        .rob_head_br_miss_1     (rob_head_br_miss_1),
        .rob_head_br_target_1   (rob_head_br_target_1),
        .rob_head_ex_1          (rob_head_ex_1),
        .rob_head_areg_1        (rob_head_areg_1),
        .rob_head_new_preg_1    (rob_head_new_preg_1),
        .rob_head_old_preg_1    (rob_head_old_preg_1),
        .rob_head_is_store_1    (rob_head_is_store_1),
        .rob_head_is_complex_1  (rob_head_is_complex_1),
        .rob_head_has_dest_1    (rob_head_has_dest_1),
        .rob_head_exception_1   (commit_exception_1),
        .rob_head_is_br_1       (rob_head_is_br_1),     
        .rob_head_br_type_1     (rob_head_br_type_1),   
        .rob_head_br_taken_1    (rob_head_br_taken_1), 
        .rob_head_inst_tlbsrch_1 (rob_head_inst_tlbsrch_1),
        .rob_head_inst_tlbrd_1   (rob_head_inst_tlbrd_1),
        .rob_head_inst_tlbwr_1   (rob_head_inst_tlbwr_1),
        .rob_head_inst_tlbfill_1 (rob_head_inst_tlbfill_1),
        .rob_head_tlb_hit_1      (rob_head_tlb_hit_1),
        .rob_head_tlb_index_1    (rob_head_tlb_index_1),
        .rob_head_inst_valid_cacop_1 (rob_head_inst_valid_cacop_1),
        .rob_head_inst_sc_w_1     (rob_head_inst_sc_w_1),
        .rob_head_inst_ll_w_1     (rob_head_inst_ll_w_1),
        .rob_head_pa_1            (rob_head_pa_1),
        .rob_head_uncache_en_1    (rob_head_uncache_en_1),
        .rob_head_inst_dbar_1     (rob_head_inst_dbar_1),
        .rob_head_inst_ibar_1     (rob_head_inst_ibar_1),

        // ???? ROB ????? (???????)
 
        .commit_pop_cnt         (commit_pop_cnt),      // ???? ROB ????????????


        //  ???? aRAT ?? Freelist ????????
        .arat_we_0              (commit_arat_we_0),
        .arat_waddr_0           (commit_arat_waddr_0),
        .arat_wdata_0           (commit_arat_wdata_0),
        .freelist_we_0          (commit_freelist_we_0),
        .freelist_wdata_0       (commit_freelist_wdata_0),

     
        .arat_we_1              (commit_arat_we_1),
        .arat_waddr_1           (commit_arat_waddr_1),
        .arat_wdata_1           (commit_arat_wdata_1),
        .freelist_we_1          (commit_freelist_we_1),
        .freelist_wdata_1       (commit_freelist_wdata_1),


        // 4. ???? Store Buffer

        .commit_st_cnt          (commit_st_cnt),       // ???? Store Buffer ???????  ?? SRAM ??????


        // 5. ??????????????????
    
        .flush_req              (ws_reflush),    // ???? Flush Controller ????????
        .flush_target           (flush_target), // ???? Flush Controller ?????????
        .com_to_csr_bus         (com_to_csr_bus)    ,   // ??????????????????????? CSR ???
        .ws_ex                  (ws_ex),
        .ertn_flush             (ertn_flush),
        .debug_raddr_0  (commit_debug_raddr_0),
        .debug_raddr_1  (commit_debug_raddr_1),
        .debug_rdata_0  (commit_debug_rdata_0),
        .debug_rdata_1  (commit_debug_rdata_1),

 // ????? BPU ?????/???????
        .bpu_update_en          (bpu_update_en),
        .bpu_pc_update          (bpu_pc_update),
        .bpu_target_update      (bpu_target_update),
        .bpu_actual_taken       (bpu_actual_taken),
        .bpu_branch_type_update (bpu_branch_type_update),
        .csr_tlbidx_index         (csr_tlbidx_index),
        // tlbrd
        .tlbrd_we                 (tlbrd_we), // to csr
        .r_index                  (r_index),  // to tlb
        // tlbwr and tlbfill
        .w_index                  (w_index),  // to tlb
        .we                       (we),       // to tlb
        // tlbsrch, to csr
        .tlbsrch_we                (tlbsrch_we),
        .tlbsrch_hit               (tlbsrch_hit),
        .tlbsrch_hit_index         (tlbsrch_hit_index),
        .ws_llbit_set              (ws_llbit_set),
        .ws_llbit                  (ws_llbit),
        .ws_lladdr_set             (ws_lladdr_set),
        .ws_lladdr                 (ws_lladdr),
        .idle_flush(idle_flush), 
        .debug_wb_pc       (debug_wb_pc),
        .debug_wb_rf_we    (debug_wb_rf_we),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum),
        .debug_wb_rf_wdata (debug_wb_rf_wdata),
        .commit_idle_0 (commit_idle_0),
        .commit_idle_1(commit_idle_1),
        .rand_idx(rand_idx) 
);
busy_table u_busy_table (
        .clk                (clk),
        .reset              (reset),
        .reflush            (ws_reflush),            // ??????????? (?? flush ??)

        // 1. Rename ????????? (????????????????)
        // ??? 0
        .check_preg_rs1_0   (preg_rs1_0),            // Rename ????????????? 1
        .check_preg_rs2_0   (preg_rs2_0),            // Rename ????????????? 2
        .rs1_is_ready_0     (rn_rs1_ready_0),        // ???????????????? Dispatch ??
        .rs2_is_ready_0     (rn_rs2_ready_0),        // ???????????????? Dispatch ??

        // ??? 1
        .check_preg_rs1_1   (preg_rs1_1),            // Rename ????????????? 1
        .check_preg_rs2_1   (preg_rs2_1),            // Rename ????????????? 2
        .rs1_is_ready_1     (rn_rs1_ready_1),        // ???????????????? Dispatch ??
        .rs2_is_ready_1     (rn_rs2_ready_1),        // ???????????????? Dispatch ??


        // 2. Rename ??????????????? (??? 0 / Busy)
        .allocate_we_0      (set_preg_busy_0),       // Rename ?????????? 0 ????????
        .allocated_preg_0   (busy_preg_id_0),        // ??? 0 ????????????????? (alloc_preg_0)
        
        .allocate_we_1      (set_preg_busy_1),       // Rename ?????????? 1 ????????
        .allocated_preg_1   (busy_preg_id_1),        // ??? 1 ????????????????? (alloc_preg_1)


        // 3. ?????  ???????? (??? 1 / Ready)
        // ???? ALU 0 ?? CDB ??
        .cdb_we_0           (cdb_we_0),              // ALU 0 ?????????
        .cdb_preg_0         (cdb_preg_0),            // ALU 0   ???????????????

        // ???? ALU 1 ?? CDB ??
        .cdb_we_1           (cdb_we_1),              // ALU 1 ?????????
        .cdb_preg_1         (cdb_preg_1),            // ALU 1   ???????????????  //????wb??

        // ???? MEM/LSU ?? CDB ??
        .cdb_we_2           (cdb_we_2),              // MEM ???/????????
        .cdb_preg_2         (cdb_preg_2)             // MEM   ???????????????
);

freelist freelist (
        .clk              (clk),
        .reset            (reset),
        .flush            (ws_reflush),           // ??????????/  ???????????

        // ???????? (???? aRAT)
        .arat_mapped_mask (arat_mapped_mask),     // aRAT ?????? 64   ???  ?

        // ?????? (???? Rename ??)
        .req_0            (req_preg_0),           // Rename ?????????????????? 0
        .req_1            (req_preg_1),           // Rename ?????????????????? 1
        .alloc_preg_0     (alloc_preg_0),         // ????? Rename ????????????? 0
        .alloc_preg_1     (alloc_preg_1),         // ????? Rename ????????????? 1
        .free_cnt         (freelist_free_cnt),    // ???? Rename ???????????  

        // ?????? (Commit ??)
        .free_we_0        (commit_freelist_we_0),   // ??? Commit ?????????
        .free_preg_0      (commit_freelist_wdata_0),// ??? Commit ??????????????????
        .free_we_1        (commit_freelist_we_1),   
        .free_preg_1      (commit_freelist_wdata_1)
);



srat u_srat (
        .clk              (clk),
        .reset            (reset),
        .flush            (ws_reflush),                 // ??????????? (?????????????????)


        // ????????

        .arat_recover_bus (arat_recover_bus),      // ???? flush ????? aRAT ?????????? 192-bit ????????


        // ????? (???????????????????????)
        // ??? 0 ?????????
        .raddr1_0         (srat_raddr1_0),         // ?? areg_rs1_0
        .raddr2_0         (srat_raddr2_0),         // ?? areg_rs2_0
        .rdata1_0         (srat_rdata1_0),         // ??? preg_rs1_0 (?????  )
        .rdata2_0         (srat_rdata2_0),         // ??? preg_rs2_0 (?????  )

        // ??? 1 ?????????
        .raddr1_1         (srat_raddr1_1),         // ?? areg_rs1_1
        .raddr2_1         (srat_raddr2_1),         // ?? areg_rs2_1
        .rdata1_1         (srat_rdata1_1),         // ??? preg_rs1_1 (?????  )
        .rdata2_1         (srat_rdata2_1),         // ??? preg_rs2_1 (?????  )


        // ????? (?????????? old_preg ?? ROB)

        .raddr_rd_0       (areg_dest0),       // ?? areg_dest_0
        .raddr_rd_1       (areg_dest1),       // ?? areg_dest_1
        .rdata_rd_0       (old_preg_0),       // ?????????????? (?????????0?? old_preg_0)
        .rdata_rd_1       (old_preg_1),       // ?????????????? (??????1????? WAW ??  )


        //   ??? (Rename ???????????????????????????)
        // ??? 0 ???????
        .we_0             (srat_we_0),
        .waddr_0          (srat_waddr_0),          // ?? areg_dest_0
        .wdata_0          (srat_wdata_0),          // ?? alloc_preg_0

        // ??? 1 ???????
        .we_1             (srat_we_1),
        .waddr_1          (srat_waddr_1),          // ?? areg_dest_1
        .wdata_1          (srat_wdata_1)           // ?? alloc_preg_1
);

arat u_arat (
        .clk              (clk),
        .reset            (reset),


        // 1.   ??? ( Commit ????)

// ??? 0 ????????????????
        .commit_we_0      (commit_arat_we_0),    
        .commit_waddr_0   (commit_arat_waddr_0), 
        .commit_wdata_0   (commit_arat_wdata_0), 

        // ??? 1 ????????????????
        .commit_we_1      (commit_arat_we_1),
        .commit_waddr_1   (commit_arat_waddr_1),
        .commit_wdata_1   (commit_arat_wdata_1),


        // 2. ????????? (???? sRAT ?? Freelist)
        .arat_recover_bus (arat_recover_bus)  ,  // 192-bit ?????????????
        .arat_mapped_mask  (arat_mapped_mask)
    );




    // ROB (???????) ?????
rob u_rob (
        .clk                 (clk),
        .reset               (reset),
        .flush               (ws_reflush),            // ???????????

        // =========================================================
        // 1. Rename ???????? (?? rename_stage ???)
        // =========================================================
        .req_rob_0           (req_rob_0),
        .req_rob_1           (req_rob_1),
        .alloc_rob_id_0      (rob_id_0),              // ???????? 0 ?? ROB ID
        .alloc_rob_id_1      (rob_id_1),              // ???????? 1 ?? ROB ID
        .rob_free_cnt        (rob_free_cnt),          // ????? Rename ????????  ????

        // =========================================================
        // 2. Rename ??????????????????
        // =========================================================
        // --- ??? 0 ---
        .inst_pc_0           (rename_pc_0),           // NEW: ??? 0 ?? PC ?
        .inst_0              (rename_inst_0),
        .areg_rd_0           (areg_dest0),            // ??????????
        .new_preg_0          (preg_rd_0),          // ?  ?????????????
        .old_preg_0          (old_preg_0),            // ??????????????? (aRAT????)
        .is_store_0          (rename_is_store_0),     
        .is_complex_0        (rename_is_complex_0),   // ?????????(???/???/???)
        .has_dest_0          (rename_has_dest_0),     // ??????  ??  ????

        // --- ??? 1 ---
        .inst_pc_1           (rename_pc_1),           // NEW: ??? 1 ?? PC ?
        .inst_1              (rename_inst_1),
        .areg_rd_1           (areg_dest1),
        .new_preg_1          (preg_rd_1),
        .old_preg_1          (old_preg_1),
        .is_store_1          (rename_is_store_1),     
        .is_complex_1        (rename_is_complex_1),   
        .has_dest_1          (rename_has_dest_1),     

        // 3. EXE/WB ??  ???? (?????????????)
        // --- ALU 0   ?? ---
        .wb_valid_0          (alu0_wb_valid),         // ALU0 ?????????
        .wb_rob_id_0         (cdb_rob_id_0),          // ??????????? ROB ID
        .wb_br_miss_0        (alu0_br_miss),          // ALU0 ????????????????
        .wb_br_target_0      (alu0_br_target),        // NEW: ALU0 ??????????????
        .wb_ex_0             (1'b0),               // ALU0 ?????????? (?????)
         .is_br_0             (alu0_is_br),        
        .br_type_0           (alu0_branch_type_exec),
        .wb_br_taken_0       (alu0_br_taken),
        // --- ALU 1   ?? ---
        .wb_valid_1          (alu1_wb_valid),         
        .wb_rob_id_1         (cdb_rob_id_1),          
        .wb_br_miss_1        (alu1_br_miss),          
        .wb_br_target_1      (alu1_br_target),        // NEW: ALU1 ??????????????
        .wb_ex_1             (1'b0),               
        .is_br_1             (alu1_is_br),        // NEW: ???? Rename ???????
        .br_type_1           (alu1_branch_type_exec),
        .wb_br_taken_1       (alu1_br_taken),
        // --- MEM/PRIV   ?? ---
        .wb_valid_2          (mem_wb_valid),          // ??? mem_priv ???? wb_valid
        .wb_rob_id_2         (mem_wb_rob_id),         
        .wb_ex_2             (mem_wb_ex),             // ?????(ALE/TLB) ?? ?????(Syscall)
        .wb_exception_2      (wb_exception_2),
        .wb_inst_valid_cacop (ms_inst_valid_cacop),
        .wb_inst_tlbsrch      (ms_inst_tlbsrch),
        .wb_inst_tlbrd        (ms_inst_tlbrd),
        .wb_inst_tlbwr        (ms_inst_tlbwr),
        .wb_inst_tlbfill      (ms_inst_tlbfill),
        .wb_tlb_hit           (ms_tlb_hit),
        .wb_tlb_index         (ms_tlb_index),
        .wb_inst_sc_w         (ms_inst_sc_w),
        .wb_inst_ll_w         (ms_inst_ll_w),
        .wb_mem_we            (ms_sc_success),
        .wb_pa                (ms_pa),
        .wb_uncache_en        (ms_uncache_en),
        .wb_inst_dbar         (ms_inst_dbar),
        .wb_inst_ibar         (ms_inst_ibar),
        // =========================================================
        // 4. Commit ???????? (???? commit_stage.v ??????)
        // =========================================================
        // --- ?????? 0 ---
        .commit_done_0       (rob_head_done_0),       // ???? Commit ?????????
        .commit_inst_pc_0    (rob_head_pc_0),         // NEW: ?? Debug ??????????
        .commit_inst_0       (rob_head_inst_0),
        .commit_br_miss_0    (rob_head_br_miss_0),    
        .commit_br_target_0  (rob_head_br_target_0),  // NEW: ??????????????????? Fetch
        .commit_ex_0         (rob_head_ex_0),         
        .commit_areg_rd_0    (rob_head_areg_0),       
        .commit_new_preg_0   (rob_head_new_preg_0),   
        .commit_old_preg_0   (rob_head_old_preg_0),   
        .commit_is_store_0   (rob_head_is_store_0),   
        .commit_is_complex_0 (rob_head_is_complex_0), 
        .commit_has_dest_0   (rob_head_has_dest_0),   
        .commit_exception_0  (commit_exception_0),
        .commit_is_br_0      (rob_head_is_br_0),      
        .commit_br_type_0    (rob_head_br_type_0),    
        .commit_br_taken_0   (rob_head_br_taken_0),
        // --- ?????? 1 ---
        .commit_done_1       (rob_head_done_1),
        .commit_inst_pc_1    (rob_head_pc_1),         
        .commit_inst_1       (rob_head_inst_1),
        .commit_br_miss_1    (rob_head_br_miss_1),
        .commit_br_target_1  (rob_head_br_target_1),  
        .commit_ex_1         (rob_head_ex_1),
        .commit_areg_rd_1    (rob_head_areg_1),
        .commit_new_preg_1   (rob_head_new_preg_1),
        .commit_old_preg_1   (rob_head_old_preg_1),
        .commit_is_store_1   (rob_head_is_store_1),
        .commit_is_complex_1 (rob_head_is_complex_1),
        .commit_has_dest_1   (rob_head_has_dest_1),
        .commit_exception_1     (commit_exception_1),
        .commit_is_br_1      (rob_head_is_br_1),     
        .commit_br_type_1    (rob_head_br_type_1),    
        .commit_br_taken_1   (rob_head_br_taken_1),         

        //  ???? Commit ???????????????? (Head)
        .commit_pop_cnt      (commit_pop_cnt),         // ?????????????????? (0, 1, ?? 2)
        .commit_inst_tlbsrch_0 (rob_head_inst_tlbsrch_0),
        .commit_inst_tlbrd_0   (rob_head_inst_tlbrd_0),
        .commit_inst_tlbwr_0   (rob_head_inst_tlbwr_0),
        .commit_inst_tlbfill_0 (rob_head_inst_tlbfill_0),
        .commit_tlb_hit_0      (rob_head_tlb_hit_0),
        .commit_tlb_index_0    (rob_head_tlb_index_0),
        .commit_inst_tlbsrch_1 (rob_head_inst_tlbsrch_1),
        .commit_inst_tlbrd_1   (rob_head_inst_tlbrd_1),
        .commit_inst_tlbwr_1   (rob_head_inst_tlbwr_1),
        .commit_inst_tlbfill_1 (rob_head_inst_tlbfill_1),
        .commit_tlb_hit_1      (rob_head_tlb_hit_1),
        .commit_tlb_index_1    (rob_head_tlb_index_1),
        .commit_inst_valid_cacop_0 (rob_head_inst_valid_cacop_0),
        .commit_inst_valid_cacop_1 (rob_head_inst_valid_cacop_1),
        .commit_inst_sc_w_0        (rob_head_inst_sc_w_0),
        .commit_inst_ll_w_0        (rob_head_inst_ll_w_0),
        .commit_pa_0               (rob_head_pa_0),
        .commit_uncache_en_0       (rob_head_uncache_en_0),
        .commit_inst_dbar_0        (rob_head_inst_dbar_0),
        .commit_inst_ibar_0        (rob_head_inst_ibar_0),
        .commit_inst_sc_w_1        (rob_head_inst_sc_w_1),
        .commit_inst_ll_w_1        (rob_head_inst_ll_w_1),
        .commit_pa_1               (rob_head_pa_1),
        .commit_uncache_en_1       (rob_head_uncache_en_1),
        .commit_inst_dbar_1        (rob_head_inst_dbar_1),
        .commit_inst_ibar_1        (rob_head_inst_ibar_1),
        .rob_head_id    (current_rob_head),
        .rob_empty      (current_rob_empty),
        .inst_idle_0(inst_idle_0),
        .inst_idle_1(inst_idle_1),
        .commit_idle_0 (commit_idle_0),
        .commit_idle_1 (commit_idle_1),
        .is_load_0(is_load_0),
        .is_load_1(is_load_1),
        .wb_va(wb_va),
        .commit_is_load_0(commit_is_load_0),
        .commit_va_0(commit_va_0),
        .commit_is_load_1(commit_is_load_1),
        .commit_va_1(commit_va_1),
        .ms_store_wdata(ms_store_wdata),
        .commit_store_wdata_0(commit_store_wdata_0),
        .commit_store_wdata_1(commit_store_wdata_1)
    );

// ????? MMU (IF_mmu) ?????
MMU u_IF_mmu (
    // 1. ???????????
    .flag            (2'b10           ), // input  [1:0]   
    .is_store        (1'b0),
    .csr_crmd_rvalue (csr_crmd_rvalue ), // input  [31:0]  // ??????????????????
    .csr_asid_rvalue (csr_asid_rvalue ), // input  [31:0]  // ??? ASID
    .csr_dmw0_rvalue (csr_dmw0_rvalue ), // input  [31:0]  // ???????? 0
    .csr_dmw1_rvalue (csr_dmw1_rvalue ), // input  [31:0]  // ???????? 1

    // 2. ???????? TLB Search Port 0 ???????
    .s_found         (s0_found        ), // input 
    .s_index         (s0_index        ), // input  [3:0]
    .s_ppn           (s0_ppn          ), // input  [19:0]
    .s_ps            (s0_ps           ), // input  [5:0]
    .s_plv           (s0_plv          ), // input  [1:0]
    .s_mat           (s0_mat          ), // input  [1:0]
    .s_d             (s0_d            ), // input 
    .s_v             (s0_v            ), // input 

    // 3. ????????????????????????????
    .va              (inst_vaddr      ), // input  [31:0]  // ?????????????? PC (??????)   PIF
    .exc_ecode       (IF_tlb_excps    ), // output [5:0]   // ??????????   PIF
    .dmw_hit         (if_dmw_hit            ), // output         // ???????????? DMW      TO  MEM0
    .plv             (if_plv      ), // output [1:0]   // 10: adef (???????), 01: adem  TO MEM0
    .pa              (inst_paddr           ), // output [31:0]  // ?????????????? (???? I-Cache ?? inst_paddr)  to PIF
    .uncache_en      (mmu_inst_uncache_en   ),  // output         // ???? Uncache ?? (??????? I-Cache) TO PIF
    .untlb_en         (if_untlb_en),
    .disable_cache   (disable_cache)
);

MMU EXE_mmu(
    .flag                   (es_mmu_en),
    .is_store (es_mem_we),
    .csr_crmd_rvalue        (csr_crmd_rvalue),
    .csr_asid_rvalue        (csr_asid_rvalue),
    .csr_dmw0_rvalue        (csr_dmw0_rvalue),
    .csr_dmw1_rvalue        (csr_dmw1_rvalue),
    
    .s_found                (s1_found),
    .s_index                (s1_index),
    .s_ppn                  (s1_ppn),
    .s_ps                   (s1_ps),
    .s_plv                  (s1_plv),
    .s_mat                  (s1_mat),
    .s_d                    (s1_d),
    .s_v                    (s1_v),
    
    .va                     (es_va),
    .exc_ecode              (es_exc_ecode),
    .dmw_hit                (es_dmw_hit),
    .plv                    (es_plv),
    .pa                     (es_pa),
    .uncache_en             (es_uncache_en),
    .untlb_en              (exe_untlb_en),
    .disable_cache          (disable_cache)
);

// TLB ???????????????
localparam TLBNUM   = 32;
localparam INDEX_WD = $clog2(TLBNUM);
tlb #(
    .TLBNUM         (TLBNUM         )
) u_tlb (
    .clk            (clk            ),
    .reset          (reset          ),
    .flush          (ws_reflush      ),

    // search port 0 
    .s0_vppn        (s0_vppn        ), // input  [18:0]  PIF
    .s0_odd_page    (s0_va_bit12    ), // input          PIF
    .s0_asid        (s0_asid        ), // input  [ 9:0]  PIF
    .s0_valid       (s0_valid       ), // input     PIF
    .s0_found       (s0_found       ), // output  to MMU
    .s0_ok          (s0_ok          ), // output reg toPIF
    .s0_index       (s0_index       ), // output [$clog2(TLBNUM)-1:0]   to mmu
    .s0_ps          (s0_ps          ), // output [ 5:0] to if_mmu
    .s0_ppn         (s0_ppn         ), // output [19:0]  to IF_mmu
    .s0_v           (s0_v           ), // output  to if_mmu
    .s0_d           (s0_d           ), // output  to if_mmu
    .s0_mat         (s0_mat         ), // output [ 1:0]  to if_mmu
    .s0_plv         (s0_plv         ), // output [ 1:0]  to if_mmu
    .s0_unbusy      (s0_unbusy      ), // output 

    // search port 1 (????? Load/Store ??????)
    .s1_vppn        (s1_va_highbits[19:1] ), // input  [18:0]
    .s1_odd_page    (s1_va_highbits[0]    ), // input 
    .s1_asid        (s1_asid        ), // input  [ 9:0]
    .s1_valid       (s1_valid       ), // input 
    .s1_found       (s1_found       ), // output 
    .s1_ok          (s1_ok          ), // output reg
    .s1_index       (s1_index       ), // output [$clog2(TLBNUM)-1:0]
    .s1_ps          (s1_ps          ), // output [ 5:0]
    .s1_ppn         (s1_ppn         ), // output [19:0]
    .s1_v           (s1_v           ), // output 
    .s1_d           (s1_d           ), // output 
    .s1_mat         (s1_mat         ), // output [ 1:0]
    .s1_plv         (s1_plv         ), // output [ 1:0]
    .s1_unbusy      (s1_unbusy      ), // output 

    // write port (??????? TLBFILL ?? TLBWR ???)
    .we             (we             ), // input 
    .w_index        (w_index        ), // input  [$clog2(TLBNUM)-1:0]
    .w_vppn         (w_vppn         ), // input  [18:0]
    .w_asid         (w_asid         ), // input  [ 9:0]
    .w_g            (w_g            ), // input 
    .w_ps           (w_ps           ), // input  [ 5:0]
    .w_e            (w_e            ), // input 
    .w_v0           (w_v0           ), // input 
    .w_d0           (w_d0           ), // input 
    .w_mat0         (w_mat0         ), // input  [ 1:0]
    .w_plv0         (w_plv0         ), // input  [ 1:0]
    .w_ppn0         (w_ppn0         ), // input  [19:0]
    .w_v1           (w_v1           ), // input 
    .w_d1           (w_d1           ), // input 
    .w_mat1         (w_mat1         ), // input  [ 1:0]
    .w_plv1         (w_plv1         ), // input  [ 1:0]
    .w_ppn1         (w_ppn1         ), // input  [19:0]

    // read port (??????? TLBRD ???)
    .r_index        (r_index        ), // input  [$clog2(TLBNUM)-1:0]
    .r_vppn         (r_vppn         ), // output [18:0]
    .r_asid         (r_asid         ), // output [ 9:0]
    .r_g            (r_g            ), // output 
    .r_ps           (r_ps           ), // output [ 5:0]
    .r_e            (r_e            ), // output 
    .r_v0           (r_v0           ), // output 
    .r_d0           (r_d0           ), // output 
    .r_mat0         (r_mat0         ), // output [ 1:0]
    .r_plv0         (r_plv0         ), // output [ 1:0]
    .r_ppn0         (r_ppn0         ), // output [19:0]
    .r_v1           (r_v1           ), // output 
    .r_d1           (r_d1           ), // output 
    .r_mat1         (r_mat1         ), // output [ 1:0]
    .r_plv1         (r_plv1         ), // output [ 1:0]
    .r_ppn1         (r_ppn1         ), // output [19:0]

    // invalid port (??????? INVTLB ???)
    .inv_en         (invtlb_valid         ), // input 
    .inv_op         (invtlb_op         ), // input  [ 4:0]
    .inv_asid       (s1_asid       ), // input  [ 9:0]
    .inv_vpn        (s1_va_highbits[19:1] )  // input  [18:0]
);


csr u_csr(
    .clk            (clk),
    .reset          (reset),
    .ws_to_csr_bus  (com_to_csr_bus),
    .ws_ex          (ws_ex),
    .ertn_flush     (ertn_flush),
    .csr_rvalue     (mem1_csr_rdata),
    .ex_entry       (ex_entry),
    .era_entry      (era_entry),
    .has_int        (has_int),

    .csr_asid_asid   (csr_asid_asid),
    .csr_tlbehi_vppn (csr_tlbehi_vppn), //to mem0
    .csr_tlbidx_index(csr_tlbidx_index), // wb(ROB?)
    .disable_cache_out(disable_cache),

    .tlbsrch_we        (tlbsrch_we), //to wb
    .tlbsrch_hit       (tlbsrch_hit),//to wb
    .tlbsrch_hit_index (tlbsrch_hit_index),//to wb
    .tlbrd_we          (tlbrd_we),//to wb

    .r_tlb_e         (r_e),
    .r_tlb_ps        (r_ps),
    .r_tlb_vppn      (r_vppn),
    .r_tlb_asid      (r_asid),
    .r_tlb_g         (r_g),
    .r_tlb_ppn0      (r_ppn0),
    .r_tlb_plv0      (r_plv0),
    .r_tlb_mat0      (r_mat0),
    .r_tlb_d0        (r_d0),
    .r_tlb_v0        (r_v0),
    .r_tlb_ppn1      (r_ppn1),
    .r_tlb_plv1      (r_plv1),
    .r_tlb_mat1      (r_mat1),
    .r_tlb_d1        (r_d1),
    .r_tlb_v1        (r_v1),

    .w_tlb_e         (w_e),
    .w_tlb_ps        (w_ps),
    .w_tlb_vppn      (w_vppn),
    .w_tlb_asid      (w_asid),
    .w_tlb_g         (w_g),
    .w_tlb_ppn0      (w_ppn0),
    .w_tlb_plv0      (w_plv0),
    .w_tlb_mat0      (w_mat0),
    .w_tlb_d0        (w_d0),
    .w_tlb_v0        (w_v0),
    .w_tlb_ppn1      (w_ppn1),
    .w_tlb_plv1      (w_plv1),
    .w_tlb_mat1      (w_mat1),
    .w_tlb_d1        (w_d1),
    .w_tlb_v1        (w_v1),
    .csr_crmd_rvalue (csr_crmd_rvalue),
    .csr_asid_rvalue (csr_asid_rvalue),
    .csr_dmw0_rvalue (csr_dmw0_rvalue),
    .csr_dmw1_rvalue (csr_dmw1_rvalue),
    .csr_num_mem        (mem1_csr_num),
    .llbit_in           (ws_llbit),
    .llbit_set_in       (ws_llbit_set),
    .lladdr_in          (ws_lladdr),
    .lladdr_set_in      (ws_lladdr_set),
    .llbit_out          (csr_llbit),
    .lladdr_out         (csr_lladdr),
    .intrpt(intrpt)
);

`ifdef DIFFTEST_EN

// =========================================================
// Timeout Detection Logic for Difftest Detonation
// =========================================================
reg [15:0] commit_timeout_cnt;
always @(posedge clk) begin
    if (reset) begin
        commit_timeout_cnt <= 16'd0;
    end 
    // ????????????????????
    else if (diff_commit_valid_0 | diff_commit_valid_1) begin
        commit_timeout_cnt <= 16'd0;
    end 
    else begin
        commit_timeout_cnt <= commit_timeout_cnt + 1'b1;
    end
end

wire commit_timeout_trap = (commit_timeout_cnt >= 16'd15000);
/*
reg [8:0] loop_ex;
always @(posedge clk) begin
    if(reset)begin
        loop_ex <= 9'b0;
    end
    else if((rob_head_pc_0==32'h00201080 && diff_commit_valid_0) || (rob_head_pc_1==32'h00201080 && diff_commit_valid_1) ) begin
        loop_ex <= loop_ex + 1'b1;
    end
    
end
wire commit_loop_ex =(loop_ex >= 9'd50);
*/
assign csr_crmd_diff      = u_csr.rval_crmd;
assign csr_prmd_diff      = u_csr.rval_prmd;
assign csr_ectl_diff      = u_csr.rval_ecfg;
assign csr_estat_diff     = u_csr.rval_estat;
assign csr_era_diff       = u_csr.rval_era;
assign csr_badv_diff      = u_csr.rval_badv;
assign csr_eentry_diff    = u_csr.rval_eentry;
assign csr_tlbidx_diff    = u_csr.csr_tlbidx_rvalue;
assign csr_tlbehi_diff    = u_csr.csr_tlbehi_rvalue;
assign csr_tlbelo0_diff   = u_csr.csr_tlbelo0_rvalue;
assign csr_tlbelo1_diff   = u_csr.csr_tlbelo1_rvalue;
assign csr_asid_diff      = u_csr.csr_asid_rvalue;
assign csr_save0_diff     = u_csr.rval_save0;
assign csr_save1_diff     = u_csr.rval_save1;
assign csr_save2_diff     = u_csr.rval_save2;
assign csr_save3_diff     = u_csr.rval_save3;
assign csr_tid_diff       = u_csr.rval_tid;
assign csr_tcfg_diff      = u_csr.rval_tcfg;
assign csr_tval_diff      = u_csr.rval_tval;
assign csr_ticlr_diff     = 32'd0;
assign csr_llbctl_diff    = {u_csr.csr_llbctl[31:1], u_csr.llbit};
assign csr_tlbrentry_diff = u_csr.csr_tlbrentry_rvalue;
assign csr_dmw0_diff      = u_csr.rval_dmw0;
assign csr_dmw1_diff      = u_csr.rval_dmw1;
assign csr_pgdl_diff      = u_csr.rval_pgdl;
assign csr_pgdh_diff      = u_csr.rval_pgdh;

wire diff_commit_valid_0 = (commit_pop_cnt >= 2'd1);
wire diff_commit_valid_1 = (commit_pop_cnt == 2'd2);
wire diff_wen_0 = rob_head_has_dest_0 && (rob_head_areg_0 != 5'd0);
wire diff_wen_1 = rob_head_has_dest_1 && (rob_head_areg_1 != 5'd0);
wire [5:0] diff_excp_ecode = commit_exception_0[14:9];
wire diff_tlbfill_en = rob_head_inst_tlbfill_0 && diff_commit_valid_0;

reg        cmt_valid_0;
reg        cmt_valid_1;
reg [31:0] cmt_pc_0;
reg [31:0] cmt_pc_1;
reg [31:0] cmt_inst_0;
reg [31:0] cmt_inst_1;
reg        cmt_wen_0;
reg        cmt_wen_1;
reg [ 7:0] cmt_wdest_0;
reg [ 7:0] cmt_wdest_1;
reg [31:0] cmt_wdata_0;
reg [31:0] cmt_wdata_1;
reg        cmt_tlbfill_en;
reg [ 4:0] cmt_tlbfill_index;
reg        cmt_excp_flush;
reg        cmt_ertn;
reg [ 5:0] cmt_csr_ecode;
reg [31:0] cmt_excp_pc;
reg [31:0] cmt_excp_inst;
reg cmt_is_st_0;
reg cmt_is_load_0;
reg [31:0] cmt_pa_0;
reg [31:0] cmt_va_0;
reg [31:0] cmt_st_data_0;
reg cmt_is_st_1;
reg cmt_is_load_1;
reg [31:0] cmt_pa_1;
reg [31:0] cmt_va_1;
reg [31:0] cmt_st_data_1;

always @(posedge clk) begin
    if (reset) begin
        cmt_valid_0       <= 1'b0;
        cmt_valid_1       <= 1'b0;
        cmt_pc_0          <= 32'd0;
        cmt_pc_1          <= 32'd0;
        cmt_inst_0        <= 32'd0;
        cmt_inst_1        <= 32'd0;
        cmt_wen_0         <= 1'b0;
        cmt_wen_1         <= 1'b0;
        cmt_wdest_0       <= 8'd0;
        cmt_wdest_1       <= 8'd0;
        cmt_wdata_0       <= 32'd0;
        cmt_wdata_1       <= 32'd0;
        cmt_tlbfill_en    <= 1'b0;
        cmt_tlbfill_index <= 5'd0;
        cmt_excp_flush    <= 1'b0;
        cmt_ertn          <= 1'b0;
        cmt_csr_ecode     <= 6'd0;
        cmt_excp_pc       <= 32'd0;
        cmt_excp_inst     <= 32'd0;
        cmt_is_st_0        <=1'b0;
        cmt_is_load_0     <=1'b0;
        cmt_pa_0           <=32'b0;
        cmt_va_0<=32'b0;
        cmt_st_data_0<=32'b0;
        cmt_is_st_1<=1'b0;
        cmt_is_load_1<=1'b0;
        cmt_pa_1<=32'b0;
        cmt_va_1<=32'b0;
        cmt_st_data_1<=32'b0;
    end else begin
       cmt_valid_0       <= diff_commit_valid_0;
       // cmt_valid_0       <= diff_commit_valid_0| commit_timeout_trap | commit_loop_ex;
     //  cmt_valid_0       <= diff_commit_valid_0| commit_timeout_trap;
        cmt_valid_1       <= diff_commit_valid_1;
        cmt_pc_0          <= rob_head_pc_0;
     //   cmt_pc_0          <= commit_timeout_trap? 32'hDEAD_BEEF : 
      //                        rob_head_pc_0;
        cmt_pc_1          <= rob_head_pc_1;
        cmt_inst_0        <= rob_head_inst_0;
   //     cmt_inst_0        <= commit_timeout_trap ? 32'hBAD_BAD0  : rob_head_inst_0;
        cmt_inst_1        <= rob_head_inst_1;
        cmt_wen_0         <= diff_wen_0;
        cmt_wen_1         <= diff_wen_1;
        cmt_wdest_0       <= {3'd0, rob_head_areg_0};
        cmt_wdest_1       <= {3'd0, rob_head_areg_1};
        cmt_wdata_0       <= commit_debug_rdata_0;
        cmt_wdata_1       <= commit_debug_rdata_1;
        cmt_tlbfill_en    <= diff_tlbfill_en;
        cmt_tlbfill_index <= w_index;
        cmt_excp_flush    <= ws_ex;
        cmt_ertn          <= ertn_flush;
        cmt_csr_ecode     <= diff_excp_ecode;
        cmt_excp_pc       <= rob_head_pc_0;
        cmt_excp_inst     <= rob_head_inst_0;
        cmt_is_st_0        <=rob_head_is_store_0;
        cmt_is_load_0     <=commit_is_load_0;
        cmt_pa_0           <=rob_head_pa_0;
        cmt_va_0           <=commit_va_0;
        cmt_st_data_0         <=commit_store_wdata_0;
        cmt_is_st_1<=rob_head_is_store_1;
        cmt_is_load_1<=commit_is_load_1;
        cmt_pa_1<=rob_head_pa_1;
        cmt_va_1<=commit_va_1;
        cmt_st_data_1<=commit_store_wdata_1;
    end
end

wire cmt_rdcntid_0 = (cmt_inst_0[31:15] == 17'd0) && (cmt_inst_0[14:10] == 5'h18) && (cmt_inst_0[4:0] == 5'd0);
wire cmt_rdcntvl_0 = (cmt_inst_0[31:15] == 17'd0) && (cmt_inst_0[14:10] == 5'h18) && (cmt_inst_0[9:5] == 5'd0) && (cmt_inst_0[4:0] != 5'd0);
wire cmt_rdcntvh_0 = (cmt_inst_0[31:15] == 17'd0) && (cmt_inst_0[14:10] == 5'h19) && (cmt_inst_0[9:5] == 5'd0);
wire cmt_cnt_inst_0 = cmt_rdcntid_0 | cmt_rdcntvl_0 | cmt_rdcntvh_0;
wire [63:0] cmt_timer_64_0 = cmt_rdcntvh_0 ? {cmt_wdata_0, 32'd0} : {32'd0, cmt_wdata_0};

wire cmt_rdcntid_1 = (cmt_inst_1[31:15] == 17'd0) && (cmt_inst_1[14:10] == 5'h18) && (cmt_inst_1[4:0] == 5'd0);
wire cmt_rdcntvl_1 = (cmt_inst_1[31:15] == 17'd0) && (cmt_inst_1[14:10] == 5'h18) && (cmt_inst_1[9:5] == 5'd0) && (cmt_inst_1[4:0] != 5'd0);
wire cmt_rdcntvh_1 = (cmt_inst_1[31:15] == 17'd0) && (cmt_inst_1[14:10] == 5'h19) && (cmt_inst_1[9:5] == 5'd0);
wire cmt_cnt_inst_1 = cmt_rdcntid_1 | cmt_rdcntvl_1 | cmt_rdcntvh_1;
wire [63:0] cmt_timer_64_1 = cmt_rdcntvh_1 ? {cmt_wdata_1, 32'd0} : {32'd0, cmt_wdata_1};

wire cmt_is_csr_estat_0 = (cmt_inst_0[31:24] == 8'h04) && (cmt_inst_0[23:10] == 14'h5);
wire cmt_is_csr_estat_1 = (cmt_inst_1[31:24] == 8'h04) && (cmt_inst_1[23:10] == 14'h5);

DifftestInstrCommit DifftestInstrCommit0(
    .clock              (clk),
    .coreid             (0),
    .index              (0),
    .valid              (cmt_valid_0),
    .pc                 (cmt_pc_0),
    .instr              (cmt_inst_0),
    .skip               (0),
    .is_TLBFILL         (cmt_tlbfill_en),
    .TLBFILL_index      (cmt_tlbfill_index),
    .is_CNTinst         (cmt_cnt_inst_0),
    .timer_64_value     (cmt_timer_64_0),
    .wen                (cmt_wen_0),
    .wdest              (cmt_wdest_0),
    .wdata              (cmt_wdata_0),
    .csr_rstat          (cmt_is_csr_estat_0),
    .csr_data           (cmt_wdata_0)
);

DifftestInstrCommit DifftestInstrCommit1(
    .clock              (clk),
    .coreid             (0),
    .index              (1),
    .valid              (cmt_valid_1),
    .pc                 (cmt_pc_1),
    .instr              (cmt_inst_1),
    .skip               (0),
    .is_TLBFILL         (0),
    .TLBFILL_index      (0),
    .is_CNTinst         (cmt_cnt_inst_1),
    .timer_64_value     (cmt_timer_64_1),
    .wen                (cmt_wen_1),
    .wdest              (cmt_wdest_1),
    .wdata              (cmt_wdata_1),
    .csr_rstat          (cmt_is_csr_estat_1),
    .csr_data           (cmt_wdata_1)
);

DifftestExcpEvent DifftestExcpEvent(
    .clock              (clk),
    .coreid             (0),
    .excp_valid         (cmt_excp_flush),
    .eret               (cmt_ertn),
    .intrNo             (csr_estat_diff[12:2]),
    .cause              (cmt_csr_ecode),
    .exceptionPC        (cmt_excp_pc),
    .exceptionInst      (cmt_excp_inst)
);

DifftestTrapEvent DifftestTrapEvent(
    .clock              (clk),
    .coreid             (0),
    .valid              (0),
    .code               (0),
    .pc                 (cmt_pc_0),
    .cycleCnt           (64'd0),
    .instrCnt           (64'd0)
);

DifftestStoreEvent DifftestStoreEvent0(
        .clock              (clk),
        .coreid             (0),
        .index              (0),
        .valid              (cmt_valid_0 & cmt_is_st_0), 
        .storePAddr         (cmt_pa_0),
        .storeVAddr         (cmt_va_0),
        .storeData          (cmt_st_data_0) 
);

DifftestStoreEvent DifftestStoreEvent1(
        .clock              (clk),
        .coreid             (0),
        .index              (1),
        .valid              (cmt_valid_1 & cmt_is_st_1), 
        .storePAddr         (cmt_pa_1),
        .storeVAddr         (cmt_va_1),
        .storeData          (cmt_st_data_1) 
);

DifftestLoadEvent DifftestLoadEvent0(
    .clock              (clk),
    .coreid             (0),
    .index              (0),
    .valid              (cmt_valid_0 & cmt_is_load_0),
    .paddr              (cmt_pa_0),
    .vaddr              (cmt_va_0)
);
DifftestLoadEvent DifftestLoadEvent1(
    .clock              (clk),
    .coreid             (0),
    .index              (1),
    .valid              (cmt_valid_1 & cmt_is_load_1),
    .paddr              (cmt_pa_1),
    .vaddr              (cmt_va_1)
);

DifftestCSRRegState DifftestCSRRegState(
    .clock              (clk),
    .coreid             (0),
    .crmd               (csr_crmd_diff),
    .prmd               (csr_prmd_diff),
    .euen               (0),
    .ecfg               (csr_ectl_diff),
    .estat              (csr_estat_diff),
    .era                (csr_era_diff),
    .badv               (csr_badv_diff),
    .eentry             (csr_eentry_diff),
    .tlbidx             (csr_tlbidx_diff),
    .tlbehi             (csr_tlbehi_diff),
    .tlbelo0            (csr_tlbelo0_diff),
    .tlbelo1            (csr_tlbelo1_diff),
    .asid               (csr_asid_diff),
    .pgdl               (csr_pgdl_diff),
    .pgdh               (csr_pgdh_diff),
    .save0              (csr_save0_diff),
    .save1              (csr_save1_diff),
    .save2              (csr_save2_diff),
    .save3              (csr_save3_diff),
    .tid                (csr_tid_diff),
    .tcfg               (csr_tcfg_diff),
    .tval               (csr_tval_diff),
    .ticlr              (csr_ticlr_diff),
    .llbctl             (csr_llbctl_diff),
    .tlbrentry          (csr_tlbrentry_diff),
    .dmw0               (csr_dmw0_diff),
    .dmw1               (csr_dmw1_diff)
);

DifftestGRegState DifftestGRegState(
    .clock              (clk),
    .coreid             (0),
    .gpr_0              (0),
    .gpr_1              (diff_regs[1]),
    .gpr_2              (diff_regs[2]),
    .gpr_3              (diff_regs[3]),
    .gpr_4              (diff_regs[4]),
    .gpr_5              (diff_regs[5]),
    .gpr_6              (diff_regs[6]),
    .gpr_7              (diff_regs[7]),
    .gpr_8              (diff_regs[8]),
    .gpr_9              (diff_regs[9]),
    .gpr_10             (diff_regs[10]),
    .gpr_11             (diff_regs[11]),
    .gpr_12             (diff_regs[12]),
    .gpr_13             (diff_regs[13]),
    .gpr_14             (diff_regs[14]),
    .gpr_15             (diff_regs[15]),
    .gpr_16             (diff_regs[16]),
    .gpr_17             (diff_regs[17]),
    .gpr_18             (diff_regs[18]),
    .gpr_19             (diff_regs[19]),
    .gpr_20             (diff_regs[20]),
    .gpr_21             (diff_regs[21]),
    .gpr_22             (diff_regs[22]),
    .gpr_23             (diff_regs[23]),
    .gpr_24             (diff_regs[24]),
    .gpr_25             (diff_regs[25]),
    .gpr_26             (diff_regs[26]),
    .gpr_27             (diff_regs[27]),
    .gpr_28             (diff_regs[28]),
    .gpr_29             (diff_regs[29]),
    .gpr_30             (diff_regs[30]),
    .gpr_31             (diff_regs[31])
);
`endif
endmodule
