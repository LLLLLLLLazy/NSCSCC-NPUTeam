`include "header.h" 
`include "csr.h"

module cpu_core (
        input  wire         clk,
        input  wire         reset,
        input  [7:0]        hw_int_in,
        // icache and axi 
        output              inst_rd_req,    
        output [2:0]        inst_rd_type,   
        output [31:0]       inst_rd_addr,   
        input               inst_rd_rdy,  
        input               inst_ret_valid, 
        input               inst_ret_last, 
        input  [31:0]       inst_ret_data,  
        output              inst_wr_req,  
        output [2:0]        inst_wr_type,
        output [31:0]       inst_wr_addr, 
        output [3:0]        inst_wr_wstrb,
        output [127:0]      inst_wr_data, 
        input               inst_wr_rdy,
        // dcache and axi
        output              data_rd_req,  
        output [2:0]        data_rd_type, 
        output [31:0]       data_rd_addr, 
        input               data_rd_rdy,  
        input               data_ret_valid,
        input               data_ret_last,
        input  [31:0]       data_ret_data,
        output              data_wr_req,  
        output [2:0]        data_wr_type, 
        output [31:0]       data_wr_addr, 
        output [3:0]        data_wr_wstrb,
        output [127:0]      data_wr_data,
        input               data_wr_rdy,
        // trace debug interface
        output wire [31:0]  debug_wb_pc,
        output wire [3:0]   debug_wb_rf_we,
        output wire [4:0]   debug_wb_rf_wnum,
        output wire [31:0]  debug_wb_rf_wdata

        `ifdef DIFFTEST_EN
        ,
        output [31:0]       debug0_wb_inst_diff,
        output              mem_valid_diff,
        output              cnt_inst_diff,
        output [63:0]       timer_64_diff,
        output [7:0]        inst_ld_en_diff,
        output [31:0]       ld_paddr_diff,
        output [31:0]       ld_vaddr_diff,
        output [7:0]        inst_st_en_diff,
        output [31:0]       st_paddr_diff,
        output [31:0]       st_vaddr_diff,
        output [31:0]       st_data_diff,
        output              csr_rstat_en_diff,
        output [31:0]       csr_data_diff,

        output [4:0]        rand_index_diff,
        output              MEM_ex_diff,
        output              MEM_ertn_diff,
        output              tlbfill_en_diff,
        output [5:0]        MEM_csr_ecode_diff,

        output [31:0]       rf_to_diff [31:0], //���ֺ����治һ��

        output [31:0]       csr_crmd_diff_0,
        output [31:0]       csr_prmd_diff_0,
        output [31:0]       csr_ectl_diff_0,
        output [31:0]       csr_estat_diff_0,
        output [31:0]       csr_era_diff_0,
        output [31:0]       csr_badv_diff_0,
        output [31:0]       csr_eentry_diff_0,
        output [31:0]       csr_tlbidx_diff_0,
        output [31:0]       csr_tlbehi_diff_0,
        output [31:0]       csr_tlbelo0_diff_0,
        output [31:0]       csr_tlbelo1_diff_0,
        output [31:0]       csr_asid_diff_0,
        output [31:0]       csr_save0_diff_0,
        output [31:0]       csr_save1_diff_0,
        output [31:0]       csr_save2_diff_0,
        output [31:0]       csr_save3_diff_0,
        output [31:0]       csr_tid_diff_0,
        output [31:0]       csr_tcfg_diff_0,
        output [31:0]       csr_tval_diff_0,
        output [31:0]       csr_ticlr_diff_0,
        output [31:0]       csr_llbctl_diff_0,
        output [31:0]       csr_tlbrentry_diff_0,
        output [31:0]       csr_dmw0_diff_0,
        output [31:0]       csr_dmw1_diff_0,
        output [31:0]       csr_pgdl_diff_0,
        output [31:0]       csr_pgdh_diff_0
        `endif
);

`ifdef DIFFTEST_EN
    wire [`DIFF_WIDTH_ID_FIFO_BUS -1 : 0] ID_FIFO_diff_bus_1;
    wire [`DIFF_WIDTH_FIFO_IS_BUS -1 : 0] FIFO_IS_diff_bus_1;
    wire [`DIFF_WIDTH_IS_EX1_BUS  -1 : 0] IS_EX1_diff_bus_1;
    wire [`DIFF_WIDTH_EX1_EX2_BUS -1 : 0] EX1_EX2_diff_bus_1;
    wire [`DIFF_WIDTH_EX2_MEM_BUS -1 : 0] EX2_MEM_diff_bus_1;
    wire [`DIFF_WIDTH_MEM_CM_BUS  -1 : 0] MEM_CM_diff_bus_1;
    wire [`DIFF_WIDTH_ID_FIFO_BUS -1 : 0] ID_FIFO_diff_bus_2;
    wire [`DIFF_WIDTH_FIFO_IS_BUS -1 : 0] FIFO_IS_diff_bus_2;
    wire [`DIFF_WIDTH_IS_EX1_BUS  -1 : 0] IS_EX1_diff_bus_2;
    wire [`DIFF_WIDTH_EX1_EX2_BUS -1 : 0] EX1_EX2_diff_bus_2;
    wire [`DIFF_WIDTH_EX2_MEM_BUS -1 : 0] EX2_MEM_diff_bus_2;
    wire [`DIFF_WIDTH_MEM_CM_BUS  -1 : 0] MEM_CM_diff_bus_2;

    wire [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_1;
    wire [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_2;

    wire [`DIFF_WIDTH_MEM_CM_BUS  -1 : 0] CM_diff_bus;
    wire [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] CM_diff_ctrl_bus;
    //regfile
    wire [`WIDTH_MEM_RF_BUS - 1  : 0  ] MEM_rf_bus_diff;
    wire rf_we_diff;
    wire [4:0] rf_waddr_diff;
    wire [31:0] rf_wdata_diff;
    wire MEM_excp;
    //to PIF
    wire CM_ex_diff;
    wire CM_tlbr_ex_diff;
    wire CM_ertn_diff;
    wire CM_refetch_diff;
    wire [31:0] CM_refetch_pc_diff;
    wire flush_diff;
    wire MEM_flush;
    //csr
    wire        MEM_ex_ctrl_diff          ;
    wire [ 5:0] MEM_csr_ecode_ctrl_diff   ;
    wire [ 8:0] MEM_csr_esubcode_ctrl_diff;
    wire        va_error_ctrl_diff        ;
    wire        MEM_tlbr_ex_ctrl_diff     ;
    wire        MEM_excp_tlb_ctrl_diff    ;
    wire [31:0] MEM_csr_pc_ctrl_diff      ;
    wire [31:0] MEM_vaddr_ctrl_diff       ;
    wire [13:0] csr_wnum_ctrl_diff        ;
    wire        csr_we_ctrl_diff          ;
    wire [31:0] csr_wmask_ctrl_diff       ;
    wire [31:0] csr_wvalue_ctrl_diff      ;
    wire        MEM_ertn_ctrl_diff        ;
    wire [93+`WIDTH_TLB_INDEX:0] MEM_TLB_data_ctrl_diff    ;
    wire        llbit_in_ctrl_diff        ;
    wire        llbit_set_in_ctrl_diff    ;
    wire [27:0] lladdr_in_ctrl_diff       ;
    wire        lladdr_set_in_ctrl_diff   ;
`endif

    // stall
    wire        IF_stall;
    wire        ID_stall;
    wire        FIFO_stall;
    wire        EX_stall;
    wire        EX1_stall;
    wire        EX2_stall;
    wire        MEM_stall;
`ifdef DEBUG
    wire        CM_stall;
`endif

    // valid
    wire        PIF_IF_valid;
    wire        IF_ID_valid;
    wire        ID_FIFO_valid;
    wire        IS_EX1_valid;
    wire        EX1_EX2_valid;
    wire        EX2_MEM_valid;
    //bus2 valid
    wire        IS_EX1_bus2_valid;
    wire        EX1_EX2_bus2_valid;
    wire        EX2_MEM_bus2_valid;
`ifdef DEBUG
    wire        MEM_CM_valid;
    wire        CM_debug_valid;
`endif

    // bus
    wire [`WIDTH_PIF_IF_BUS - 1  : 0  ] PIF_IF_bus;
    wire [`WIDTH_IF_ID_BUS - 1   : 0  ] IF_ID_bus1;
    wire [`WIDTH_IF_ID_BUS - 1   : 0  ] IF_ID_bus2;
    wire [`WIDTH_ID_FIFO_BUS - 1 : 0  ] ID_FIFO_bus1;
    wire [`WIDTH_ID_FIFO_BUS - 1 : 0  ] ID_FIFO_bus2;
    wire [`WIDTH_ID_DECODE_BUS - 1 : 0] ID_decode_bus1;
    wire [`WIDTH_ID_DECODE_BUS - 1 : 0] ID_decode_bus2;
    wire [`WIDTH_FIFO_IS_BUS - 1 : 0  ] FIFO_IS_bus1;
    wire [`WIDTH_FIFO_IS_BUS - 1 : 0  ] FIFO_IS_bus2;
    wire [`WIDTH_IS_EX1_BUS - 1  : 0  ] IS_EX1_bus1;
    wire [`WIDTH_IS_EX1_BUS - 1  : 0  ] IS_EX1_bus2;
    wire [`WIDTH_EX1_EX2_BUS - 1 : 0  ] EX1_EX2_bus1;
    wire [`WIDTH_EX1_EX2_BUS - 1 : 0  ] EX1_EX2_bus2;
    wire [`WIDTH_EX2_MEM_BUS - 1 : 0  ] EX2_MEM_bus1;
    wire [`WIDTH_EX2_MEM_BUS - 1 : 0  ] EX2_MEM_bus2;
    wire [`WIDTH_MEM_RF_BUS - 1  : 0  ] MEM_rf_bus1;
    wire [`WIDTH_MEM_RF_BUS - 1  : 0  ] MEM_rf_bus2;
`ifdef DEBUG
    wire [`WIDTH_MEM_CM_BUS - 1  : 0  ] MEM_CM_bus1;
    wire [`WIDTH_MEM_CM_BUS - 1  : 0  ] MEM_CM_bus2;
    wire [`WIDTH_MEM_CM_BUS - 1  : 0  ] CM_bus;
`endif
    // forward
    wire [`WIDTH_EX1_FORWARD_BUS - 1 : 0] EX1_forward_bus1;
    wire [`WIDTH_EX1_FORWARD_BUS - 1 : 0] EX1_forward_bus2;
    wire [`WIDTH_EX2_FORWARD_BUS - 1 : 0] EX2_forward_bus1;
    wire [`WIDTH_EX2_FORWARD_BUS - 1 : 0] EX2_forward_bus2;
    wire [`WIDTH_MEM_FORWARD_BUS - 1 : 0] MEM_forward_bus1;
    wire [`WIDTH_MEM_FORWARD_BUS - 1 : 0] MEM_forward_bus2;
`ifdef DEBUG
    wire [9:0] CM_forward_bus;
`endif
    // mmu
    wire [31:0] inst_vaddr;
    wire [31:0] inst_paddr;
    wire        mmu_inst_uncache_en;
    wire        EX1_load;
    wire        EX1_store;
    wire        mmu_data_uncache_en;
    wire [31:0] EX1_data_paddr;
    wire [31:0] EX1_data_vaddr;
    wire        EX1_cacop;
    wire [89+`WIDTH_TLB_INDEX:0] tlb_data;
    wire [188:0] csr_mmu_values;
    wire        mmu_sc_addr_eq;
    wire [31:0] sc_ll_paddr;
    wire        inst_unhit;
    wire        data_unhit;

    //regfile
    wire [4:0]  rf_raddr1;
    wire [4:0]  rf_raddr2;
    wire [4:0]  rf_raddr3;
    wire [4:0]  rf_raddr4;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] rf_rdata3;
    wire [31:0] rf_rdata4;
    wire        rf_we1;
    wire [4:0]  rf_waddr1;
    wire [31:0] rf_wdata1;
    wire        rf_we2;
    wire [4:0]  rf_waddr2;
    wire [31:0] rf_wdata2;

    // csr
    wire [9:0]  csr_asid_asid;
    wire [1:0]  csr_plv;
    wire [31:0] MEM_csr_pc;
    wire [31:0] csr_rvalue1;
    wire [31:0] csr_rvalue2;
    wire [13:0] csr_rnum1;
    wire [13:0] csr_rnum2;
    wire [13:0] csr_wnum;
    wire        csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [5:0]  MEM_csr_ecode;
    wire [8:0]  MEM_csr_esubcode;
    wire [63:0] stable_counter;
    wire [31:0] counter_id;
    wire [93+`WIDTH_TLB_INDEX:0] MEM_TLB_data;
    wire [31:0] MEM_pc1;
    wire [31:0] MEM_pc2;
    wire [31:0] MEM_pc;
    wire [31:0] MEM_vaddr;
    wire [31:0] ex_entry;
    wire [31:0] csr_tlbehi_rvalue;
    wire [31:0] csr_crmd_rvalue;
    wire [31:0] csr_dmw0_rvalue;
    wire [31:0] csr_dmw1_rvalue;
    wire [31:0] csr_tlbrentry_rvalue;
    wire [31:0] csr_era_rvalue;
    wire [31:0] csr_asid_rvalue;
    wire        disable_cache;

    wire        llbit_in;
    wire        llbit_set_in;
    wire [27:0] lladdr_in;
    wire        lladdr_set_in;
    wire        llbit_out;
    wire [27:0] lladdr_out;
    wire        ID_llbit1;
    wire        ID_llbit2;

    // excp 
    wire        has_int;
    wire [4:0]  EX1_tlb_excps;
    wire [2:0]  IF_tlb_excps;
    wire        MEM_ex;
    wire        MEM_ertn;
    wire        MEM_tlbr_ex;
    wire        MEM_refetch;

    wire        va_error;
    wire        MEM_excp_tlb;

    // flush
    wire        flush;
    wire        br_taken;
    wire [31:0] br_target;
    wire [76:0] btb_bus;

    // icache
    wire        EX2_inst_cancel;
    wire        inst_uncache_en;
    wire        IF_inst_cancel_req;
    wire        inst_valid;
    wire        inst_addr_ok;
    wire        inst_data_ok1;
    wire        inst_data_ok2;
    wire [7:0]  inst_index;
    wire [19:0] inst_tag;
    wire [3:0]  inst_offset;
    wire [31:0] inst_rdata1;
    wire [31:0] inst_rdata2;
    wire        icacop_op_en;    
    wire        icache_unbusy;
    wire        icache_hit;

    // dcache
    wire        EX2_data_cancel;
    wire        data_uncache_en;
    wire        data_valid;
    wire        data_op;
    wire        data_addr_ok;
    wire        data_data_ok;
    wire [7:0]  data_index;
    wire [19:0] data_tag;
    wire [3:0]  data_offset;
    wire [31:0] data_rdata;
    wire [3:0]  data_wstrb;
    wire [2:0]  data_size;
    wire [31:0] data_wdata;
    wire [1:0]  cache_op_mode;
    wire [1:0]  EX1_cache_op_mode;
    wire        dcacop_op_en;
    wire        dcache_unbusy;
    wire        preld_en;
    wire        dcache_hit;

    // tlb
    wire [18:0] s0_vppn;
    wire        s0_va_bit12;
    wire [9:0]  s0_asid;
    wire        s0_valid;
    wire        s0_found;
    wire        s0_ok;
    wire [`WIDTH_TLB_INDEX-1:0] s0_index;
    wire [19:0] s0_ppn;
    wire [5:0]  s0_ps;
    wire [1:0]  s0_plv;
    wire [1:0]  s0_mat;
    wire        s0_d;
    wire        s0_v;
    wire [18:0] s1_vppn;
    wire        s1_va_bit12;
    wire [9:0]  s1_asid;
    wire        s1_valid;
    wire        s1_found;
    wire        s1_ok;
    wire [`WIDTH_TLB_INDEX-1:0] s1_index;
    wire [19:0] s1_ppn;
    wire [5:0]  s1_ps;
    wire [1:0]  s1_plv;
    wire [1:0]  s1_mat;
    wire        s1_d;
    wire        s1_v;
    wire [4:0]  EX1_invtlb_op;
    wire        EX1_inst_invtlb;
    wire        tlb_we;
    wire [`WIDTH_TLB_INDEX-1:0] w_index;
    wire        w_e;
    wire [5:0]  w_ps;
    wire [18:0] w_vppn;
    wire [9:0]  w_asid;
    wire        w_g;
    wire [19:0] w_ppn0;
    wire [1:0]  w_plv0;
    wire [1:0]  w_mat0;
    wire        w_d0;
    wire        w_v0;
    wire [19:0] w_ppn1;
    wire [1:0]  w_plv1;
    wire [1:0]  w_mat1;
    wire        w_d1;
    wire        w_v1;
    wire [`WIDTH_TLB_INDEX-1:0] r_index;
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
    wire [89+2*`WIDTH_TLB_INDEX:0] csr_tlb_out;
    wire        invtlb_en;
    wire [4:0]  invtlb_op;
    wire [9:0]  invtlb_asid;
    wire [18:0] invtlb_vppn;
    
    // branch
    wire [4:0]  jump_op;
    wire [159:0] jump_target;

    // bp_unit
    wire        PIF_valid;
    wire [31:0] PIF_pc1;
    wire [31:0] PIF_pc2;
    wire [31:0] operate_pc;

    wire        btb_miss1;
    wire        btb_miss2;
    wire        pred_taken1;
    wire        pred_taken2;
    wire [31:0] pred_target1;
    wire [31:0] pred_target2;
    wire [ 4:0] pred_index1;
    wire [ 4:0] pred_index2;
    wire        operate_en;
    wire        add_entry;
    wire        pred_error;
    wire        target_error;
    wire        pred_right;
    wire        right_orien;
    wire [31:0] right_target;
    wire [ 4:0] operate_index;
    wire        push_ras;
    wire        pop_ras;
    // fire
    wire        inst1_valid;
    wire        inst2_valid;

    // perf
    wire MEM_valid;
    wire MEM_mode;
    wire br_inst;
    wire single_inst;
    wire double_inst;
    wire FIFO_full;
    wire FIFO_empty;
    wire dcache_miss;
    wire icache_miss;
    wire real_dcache_miss;
    wire real_icache_miss;

`ifdef DEBUG
    assign {debug_wb_rf_wnum, 
            debug_wb_rf_we, 
            debug_wb_rf_wdata, 
            debug_wb_pc} = {CM_bus[69:65], {4{CM_debug_valid & CM_bus[64]}}, CM_bus[63:0]};
`else
    assign debug_wb_pc = MEM_pc1;
`endif
    assign {rf_we1, rf_waddr1, rf_wdata1} = MEM_rf_bus1;
    assign {rf_we2, rf_waddr2, rf_wdata2} = MEM_rf_bus2;
    assign csr_asid_asid = csr_asid_rvalue[`CSR_ASID_ASID];
    assign {
            tlb_we,     //97
            w_index,    //96:93
            w_e,        //92
            w_vppn,     //91:73
            w_ps,       //72:67
            w_asid,     //66:57
            w_g,        //56
            w_ppn0,     //55:36
            w_plv0,     //35:34
            w_mat0,     //33:32
            w_d0,       //31
            w_v0,       //30
            w_ppn1,     //29:10
            w_plv1,     //9:8
            w_mat1,     //7:6
            w_d1,       //5
            w_v1,       //4
            r_index     //3:0
        } = csr_tlb_out;
    assign csr_mmu_values = {
                            lladdr_out,
                            disable_cache,
                            csr_tlbehi_rvalue,
                            csr_crmd_rvalue,
                            csr_asid_rvalue,
                            csr_dmw0_rvalue,
                            csr_dmw1_rvalue  
                            };
`ifdef DIFFTEST_DEBUG
    assign jump_op = {CM_ex_diff, CM_ertn_diff, CM_tlbr_ex_diff, CM_refetch_diff, br_taken};
    assign jump_target = {
                        ex_entry,
                        csr_era_rvalue,
                        CM_refetch_pc_diff,
                        csr_tlbrentry_rvalue,
                        br_target
                        };
`else
    assign jump_op = {MEM_ex, MEM_ertn, MEM_tlbr_ex, MEM_refetch, br_taken};
    assign jump_target = {
                         ex_entry,
                         csr_era_rvalue,
                         MEM_pc,
                         csr_tlbrentry_rvalue,
                         br_target
                         };
`endif
    assign EX_stall = EX1_stall || EX2_stall;

    PIF u_pif(
        .clk                (clk                ),
        .reset              (reset              ),
        .flush              (flush              ),
        .br_taken           (br_taken           ),
        .jump_op            (jump_op            ),
        .jump_target        (jump_target        ),
        .PIF_valid          (PIF_valid          ),
        .PIF_pc1            (PIF_pc1            ),
        .PIF_pc2            (PIF_pc2            ),
        .btb_miss1          (btb_miss1          ),
        .btb_miss2          (btb_miss2          ),
        .pred_taken1        (pred_taken1        ),
        .pred_target1       (pred_target1       ),
        .pred_taken2        (pred_taken2        ),
        .pred_target2       (pred_target2       ),
        .pred_index1        (pred_index1        ),
        .pred_index2        (pred_index2        ),
        .IF_stall           (IF_stall           ),
        .ID_stall           (ID_stall           ),
        .FIFO_stall         (FIFO_stall         ),
        .PIF_IF_valid       (PIF_IF_valid       ),
        .PIF_IF_bus         (PIF_IF_bus         ),
        .csr_asid_asid      (csr_asid_asid      ),
        .IF_tlb_excps       (IF_tlb_excps       ),
        .inst_vaddr         (inst_vaddr         ),
        .inst_paddr         (inst_paddr         ),
        .mmu_inst_uncache_en(mmu_inst_uncache_en),
        .inst_unhit         (inst_unhit         ),
        .s0_valid           (s0_valid           ),
        .s0_ok              (s0_ok              ),
        .s0_vppn            (s0_vppn            ),
        .s0_va_bit12        (s0_va_bit12        ),
        .s0_asid            (s0_asid            ),
        .icache_unbusy      (icache_unbusy      ),
        .inst_data_ok1      (inst_data_ok1      ),
        .inst_data_ok2      (inst_data_ok2      ),
        .icache_hit         (icache_hit         ),
        .inst_valid         (inst_valid         ),
        .inst_index         (inst_index         ),
        .inst_offset        (inst_offset        )
    );

    IF u_if(
        .clk                     (clk                     ),
        .reset                   (reset                   ),
        .flush                   (flush | br_taken        ),
        .ID_stall                (ID_stall                ),
        .FIFO_stall              (FIFO_stall              ),
        .IF_stall                (IF_stall                ),
        .PIF_IF_valid            (PIF_IF_valid            ),
        .IF_ID_valid             (IF_ID_valid             ),
        .PIF_IF_bus              (PIF_IF_bus              ),
        .IF_ID_bus1              (IF_ID_bus1              ),
        .IF_ID_bus2              (IF_ID_bus2              ),
        .inst_uncache_en         (inst_uncache_en         ),
        .IF_inst_cancel_req      (IF_inst_cancel_req      ),
        .inst_data_ok1           (inst_data_ok1           ),
        .inst_data_ok2           (inst_data_ok2           ),
        .inst_tag                (inst_tag                ),
        .inst_rdata1             (inst_rdata1             ),
        .inst_rdata2             (inst_rdata2             ),
        .icache_miss             (icache_miss             )
    );

    ID u_id(
        .clk             (clk             ),
        .reset           (reset           ),
        .has_int         (has_int         ),
        .EX_stall        (EX_stall        ),
        .MEM_stall       (MEM_stall       ),
        .flush           (flush|br_taken  ),
        .csr_plv         (csr_plv         ),
        .IF_ID_valid     (IF_ID_valid     ),
        .IF_ID_bus1      (IF_ID_bus1      ),
        .IF_ID_bus2      (IF_ID_bus2      ),
        .FIFO_stall      (FIFO_stall      ),
        .ID_llbit1       (llbit_out       ),
        .ID_llbit2       (llbit_out       ),
        .inst1_valid     (inst1_valid     ),
        .inst2_valid     (inst2_valid     ),
        .ID_FIFO_bus1    (ID_FIFO_bus1    ),
        .ID_FIFO_bus2    (ID_FIFO_bus2    ),
        .ID_decode_bus1  (ID_decode_bus1  ),
        .ID_decode_bus2  (ID_decode_bus2  ),
        .ID_FIFO_valid   (ID_FIFO_valid   ),
        .ID_stall        (ID_stall        ),
        .real_icache_miss(real_icache_miss)

    `ifdef DIFFTEST_EN
        ,
        .ID_FIFO_diff_bus_1 (ID_FIFO_diff_bus_1 ),
        .ID_FIFO_diff_bus_2 (ID_FIFO_diff_bus_2 )
    `endif
    );

    BUFFER u_buf(
        .clk            (clk            ),
        .reset          (reset          ),
        .flush          (flush|br_taken ),
        .ID_FIFO_valid  (ID_FIFO_valid  ),
        .ID_FIFO_bus1   (ID_FIFO_bus1   ),
        .ID_FIFO_bus2   (ID_FIFO_bus2   ),
        .ID_decode_bus1 (ID_decode_bus1 ),
        .ID_decode_bus2 (ID_decode_bus2 ),
        .inst1_valid    (inst1_valid    ),
        .inst2_valid    (inst2_valid    ),
        .IS_stall       (IS_stall       ),
        .EX1_stall      (EX1_stall      ),
        .EX2_stall      (EX2_stall      ),
        .MEM_stall      (MEM_stall      ),
    `ifdef DEBUG
        .CM_stall       (CM_stall       ),
    `endif
        .FIFO_IS_bus1   (FIFO_IS_bus1   ),
        .FIFO_IS_bus2   (FIFO_IS_bus2   ),
        .FIFO_IS_valid  (FIFO_IS_valid  ),
        .FIFO_stall     (FIFO_stall     )

    `ifdef DIFFTEST_EN
        ,
        .ID_FIFO_diff_bus_1      (ID_FIFO_diff_bus_1      ),
        .ID_FIFO_diff_bus_2      (ID_FIFO_diff_bus_2      ),
        .FIFO_IS_diff_bus_1      (FIFO_IS_diff_bus_1      ),
        .FIFO_IS_diff_bus_2      (FIFO_IS_diff_bus_2      )
    `endif
    );


    IS u_is(
        .clk                  (clk                  ),
        .reset                (reset                ),
        // .flush                (flush|br_taken       ),
        .flush                (flush                ),
        .taken_flush          (br_taken             ),
        .has_int              (has_int              ),
        .csr_tlbehi_rvalue    (csr_tlbehi_rvalue    ),
        .csr_asid_asid        (csr_asid_asid        ),
        .FIFO_IS_valid        (FIFO_IS_valid        ),
        .EX1_stall            (EX1_stall            ),
        .EX2_stall            (EX2_stall            ),
        .MEM_stall            (MEM_stall            ),
    `ifdef DEBUG
        .CM_stall             (CM_stall             ),
    `endif
        .FIFO_IS_bus1         (FIFO_IS_bus1         ),
        .FIFO_IS_bus2         (FIFO_IS_bus2         ),
        .IS_EX1_bus1          (IS_EX1_bus1          ),
        .IS_EX1_bus2          (IS_EX1_bus2          ),
        .IS_EX1_bus2_valid    (IS_EX1_bus2_valid    ),
        .EX1_forward_bus      ({EX1_forward_bus1, EX1_forward_bus2}),
        .EX2_forward_bus      ({EX2_forward_bus1, EX2_forward_bus2}),
        .MEM_forward_bus      ({MEM_forward_bus1, MEM_forward_bus2}),
    `ifdef DIFFTEST_DEBUG
        .CM_forward_bus(CM_forward_bus),
    `endif
        .IS_EX1_valid         (IS_EX1_valid         ),
        .IS_stall             (IS_stall             ),
        .rf_rdata1            (rf_rdata1            ),
        .rf_rdata2            (rf_rdata2            ),
        .rf_rdata3            (rf_rdata3            ),
        .rf_rdata4            (rf_rdata4            ),
        .rf_raddr1            (rf_raddr1            ),
        .rf_raddr2            (rf_raddr2            ),
        .rf_raddr3            (rf_raddr3            ),
        .rf_raddr4            (rf_raddr4            )

        `ifdef DIFFTEST_EN
        ,
        .FIFO_IS_diff_bus_1      (FIFO_IS_diff_bus_1      ),
        .FIFO_IS_diff_bus_2      (FIFO_IS_diff_bus_2      ),
        .IS_EX1_diff_bus_1      (IS_EX1_diff_bus_1      ),
        .IS_EX1_diff_bus_2      (IS_EX1_diff_bus_2      )
        `endif
    );

    EX1 u_ex1(
        .clk                  (clk                  ),
        .reset                (reset                ),
        .flush                (flush                ),
        .EX2_stall            (EX2_stall            ),
        .MEM_stall            (MEM_stall            ),
    `ifdef DEBUG
        .CM_stall             (CM_stall             ),
    `endif
        .EX1_stall            (EX1_stall            ),
        .br_taken             (br_taken             ),
        .br_target            (br_target            ),
        .btb_bus              (btb_bus              ),
        .IS_EX1_valid         (IS_EX1_valid         ),
        .EX1_EX2_valid        (EX1_EX2_valid        ),
        .IS_EX1_bus2_valid    (IS_EX1_bus2_valid    ),
        .EX1_EX2_bus2_valid   (EX1_EX2_bus2_valid   ),
        .IS_EX1_bus1          (IS_EX1_bus1          ),
        .IS_EX1_bus2          (IS_EX1_bus2          ),
        .EX1_EX2_bus1         (EX1_EX2_bus1         ),
        .EX1_EX2_bus2         (EX1_EX2_bus2         ),
        .tlb_data             (tlb_data             ),
        .EX1_tlb_excps        (EX1_tlb_excps        ),
        .mmu_data_uncache_en  (mmu_data_uncache_en  ),
        .mmu_sc_addr_eq       (mmu_sc_addr_eq       ),
        .sc_ll_paddr          (sc_ll_paddr          ),
        .EX1_data_paddr       (EX1_data_paddr       ),
        .EX1_data_vaddr       (EX1_data_vaddr       ),
        .EX1_load             (EX1_load             ),
        .EX1_store            (EX1_store            ),
        .EX1_cacop            (EX1_cacop            ),
        .EX1_cache_op_mode    (EX1_cache_op_mode    ),
        //cache
        .icache_unbusy        (icache_unbusy           ),
        .dcache_unbusy        (dcache_unbusy           ),
        .dcache_hit           (dcache_hit              ),
        .data_valid           (data_valid              ),
        .data_index           (data_index              ),
        .data_op              (data_op                 ),
        .data_wstrb           (data_wstrb              ),
        .data_size            (data_size               ),
        .data_wdata           (data_wdata              ),
        .data_offset          (data_offset             ),
        .cache_op_mode        (cache_op_mode           ),
        .icacop_op_en         (icacop_op_en            ),
        .dcacop_op_en         (dcacop_op_en            ),
        .preld_en             (preld_en                ),
        //tlb
        .data_unhit           (data_unhit           ),
        .s1_valid             (s1_valid             ),
        .s1_ok                (s1_ok                ),
        .s1_vppn              (s1_vppn              ),
        .s1_va_bit12          (s1_va_bit12          ),
        .s1_asid              (s1_asid              ),
        .EX1_forward_bus1     (EX1_forward_bus1     ),
        .EX1_forward_bus2     (EX1_forward_bus2     )
    `ifdef DIFFTEST_EN
        ,
        .IS_EX1_diff_bus_1      (IS_EX1_diff_bus_1      ),
        .IS_EX1_diff_bus_2      (IS_EX1_diff_bus_2      ),
        .EX1_EX2_diff_bus_1     (EX1_EX2_diff_bus_1     ),
        .EX1_EX2_diff_bus_2     (EX1_EX2_diff_bus_2     )
    `endif
    );

    EX2 u_ex2(
        .clk                  (clk                  ),
        .reset                (reset                ),
    `ifdef DIFFTEST_DEBUG
        .flush                (MEM_flush | flush    ),
    `else
        .flush                (flush                ),
    `endif
        .btb_bus              (btb_bus              ),
        .operate_en           (operate_en           ),
        .add_entry            (add_entry            ),
        .pred_error           (pred_error           ),
        .target_error         (target_error         ),
        .pred_right           (pred_right           ),
        .right_orien          (right_orien          ),
        .right_target         (right_target         ),
        .operate_index        (operate_index        ),
        .operate_pc           (operate_pc           ),
        .push_ras             (push_ras             ),
        .pop_ras              (pop_ras              ),
        .stable_counter     (stable_counter     ),
        .counter_id         (counter_id         ),
        .csr_llbit          (llbit_out          ),
        .csr_rvalue1        (csr_rvalue1        ),
        .csr_rvalue2        (csr_rvalue2        ),
        .csr_rnum1          (csr_rnum1          ),
        .csr_rnum2          (csr_rnum2          ),
        .EX2_forward_bus1     (EX2_forward_bus1     ),
        .EX2_forward_bus2     (EX2_forward_bus2     ),
        .MEM_stall            (MEM_stall            ),
    `ifdef DEBUG
        .CM_stall             (CM_stall             ),
    `endif
        .EX2_stall            (EX2_stall            ),
        .EX1_EX2_valid        (EX1_EX2_valid        ),
        .EX2_MEM_valid        (EX2_MEM_valid        ),
        .EX1_EX2_bus2_valid   (EX1_EX2_bus2_valid   ),
        .EX2_MEM_bus2_valid   (EX2_MEM_bus2_valid   ),
        .EX1_EX2_bus1         (EX1_EX2_bus1         ),
        .EX1_EX2_bus2         (EX1_EX2_bus2         ),
        .EX2_MEM_bus1         (EX2_MEM_bus1         ),
        .EX2_MEM_bus2         (EX2_MEM_bus2         ),
        .EX2_data_cancel      (EX2_data_cancel      ),
        .EX2_inst_cancel      (EX2_inst_cancel      ),
        .data_uncache_en      (data_uncache_en      ),
        .data_data_ok         (data_data_ok         ),
        .data_tag             (data_tag             ),
        .data_rdata           (data_rdata           ),
        .dcache_miss          (dcache_miss          )

        `ifdef DIFFTEST_EN
        ,
        .EX1_EX2_diff_bus_1     (EX1_EX2_diff_bus_1     ),
        .EX1_EX2_diff_bus_2     (EX1_EX2_diff_bus_2     ),
        .EX2_MEM_diff_bus_1     (EX2_MEM_diff_bus_1     ),
        .EX2_MEM_diff_bus_2     (EX2_MEM_diff_bus_2     )
        `endif
    );

    MEM u_mem(
        .clk                (clk                ),
        .reset              (reset              ),
        .EX2_MEM_bus1       (EX2_MEM_bus1       ),
        .EX2_MEM_bus2       (EX2_MEM_bus2       ),
    `ifdef DEBUG
        .MEM_CM_valid       (MEM_CM_valid       ),
        .CM_stall           (CM_stall           ),
        .MEM_CM_bus1        (MEM_CM_bus1        ),
        .MEM_CM_bus2        (MEM_CM_bus2        ),
    `endif
    `ifdef DIFFTEST_DEBUG
        .flush_diff         (flush_diff         ),
        .flush              (MEM_flush          ),
    `else
        .flush              (flush              ),
    `endif
        .EX2_MEM_valid      (EX2_MEM_valid      ),
        .EX2_MEM_bus2_valid (EX2_MEM_bus2_valid ),
        .MEM_stall          (MEM_stall          ),
        .MEM_ex             (MEM_ex             ),
        .MEM_ertn           (MEM_ertn           ),
        .MEM_tlbr_ex        (MEM_tlbr_ex        ),
        .MEM_refetch        (MEM_refetch        ),
        .va_error           (va_error           ),
        .MEM_excp_tlb       (MEM_excp_tlb       ),
        .MEM_rf_bus1        (MEM_rf_bus1        ),
        .MEM_rf_bus2        (MEM_rf_bus2        ),
        .MEM_pc             (MEM_pc             ),
        .MEM_pc1            (MEM_pc1            ),
        .MEM_pc2            (MEM_pc2            ),
        .MEM_vaddr          (MEM_vaddr          ),
        .MEM_forward_bus1   (MEM_forward_bus1   ),
        .MEM_forward_bus2   (MEM_forward_bus2   ),
        .csr_wnum           (csr_wnum           ),
        .csr_we             (csr_we             ),
        .csr_wmask          (csr_wmask          ),
        .csr_wvalue         (csr_wvalue         ),
        .MEM_csr_pc         (MEM_csr_pc         ),
        .MEM_csr_ecode      (MEM_csr_ecode      ),
        .MEM_csr_esubcode   (MEM_csr_esubcode   ),
        .MEM_llbit_in       (llbit_in           ),
        .MEM_llbit_set      (llbit_set_in       ),
        .MEM_lladdr_in      (lladdr_in          ),
        .MEM_lladdr_set     (lladdr_set_in      ),
        .MEM_TLB_data       (MEM_TLB_data       ),
        .invtlb_en          (invtlb_en          ),
        .invtlb_op          (invtlb_op          ),
        .invtlb_asid        (invtlb_asid        ),
        .invtlb_vppn        (invtlb_vppn        ),
        .MEM_valid          (MEM_valid          ),
        .MEM_mode           (MEM_mode           ),
        .real_br_inst       (br_inst            ),
        .real_fifo_empty    (FIFO_empty         ),
        .real_fifo_full     (FIFO_full          ),
        .real_dcache_miss   (real_dcache_miss   )
    `ifdef DIFFTEST_EN
        ,
        .EX2_MEM_diff_bus_1 (EX2_MEM_diff_bus_1 ),
        .EX2_MEM_diff_bus_2 (EX2_MEM_diff_bus_2 )
    `ifdef DEBUG
        ,
        .MEM_CM_diff_bus_1  (MEM_CM_diff_bus_1  ),
        .MEM_CM_diff_bus_2  (MEM_CM_diff_bus_2  ),
        .MEM_CM_diff_ctrl_bus_1(MEM_CM_diff_ctrl_bus_1),
        .MEM_CM_diff_ctrl_bus_2(MEM_CM_diff_ctrl_bus_2)
    `endif
    `endif
    );

`ifdef DEBUG
    CM u_cm(
        .clk            (clk          ),
        .reset          (reset        ),
        .MEM_CM_bus1    (MEM_CM_bus1  ),
        .MEM_CM_bus2    (MEM_CM_bus2  ),
        .MEM_CM_valid   (MEM_CM_valid ),
        .CM_stall       (CM_stall     ),
        .CM_bus         (CM_bus       ),
        .CM_debug_valid (CM_debug_valid)

    `ifdef DIFFTEST_EN
        ,
        .CM_forward_bus(CM_forward_bus),
        .MEM_CM_diff_bus_1(MEM_CM_diff_bus_1),
        .MEM_CM_diff_bus_2(MEM_CM_diff_bus_2),
        .MEM_CM_diff_ctrl_bus_1(MEM_CM_diff_ctrl_bus_1),
        .MEM_CM_diff_ctrl_bus_2(MEM_CM_diff_ctrl_bus_2),
        .CM_diff_bus     (CM_diff_bus    ),
        .CM_diff_ctrl_bus(CM_diff_ctrl_bus)
    `endif
    );
`endif
    csr u_csr(
        .clk                  (clk                  ),
        .reset                (reset                ),
    `ifdef DIFFTEST_DEBUG
        .MEM_ex               (MEM_ex_ctrl_diff               ),
        .MEM_ecode            (MEM_csr_ecode_ctrl_diff        ),
        .MEM_esubcode         (MEM_csr_esubcode_ctrl_diff     ),
        .va_error             (va_error_ctrl_diff             ),
        .refill_ex            (MEM_tlbr_ex_ctrl_diff          ),
        .MEM_excp_tlb         (MEM_excp_tlb_ctrl_diff         ),
        .MEM_pc               (MEM_csr_pc_ctrl_diff           ),
        .MEM_vaddr            (MEM_vaddr_ctrl_diff            ),
        .csr_wnum             (csr_wnum_ctrl_diff             ),
        .csr_we               (csr_we_ctrl_diff               ),
        .csr_wmask            (csr_wmask_ctrl_diff            ),
        .csr_wvalue           (csr_wvalue_ctrl_diff           ),
        .ertn_flush           (MEM_ertn_ctrl_diff             ),
        .csr_tlb_in           (MEM_TLB_data_ctrl_diff         ),
        .llbit_in             (llbit_in_ctrl_diff             ),
        .llbit_set_in         (llbit_set_in_ctrl_diff         ),
        .lladdr_in            (lladdr_in_ctrl_diff            ),
        .lladdr_set_in        (lladdr_set_in_ctrl_diff        ),
    `else
        .MEM_ex               (MEM_ex               ),
        .MEM_ecode            (MEM_csr_ecode        ),
        .MEM_esubcode         (MEM_csr_esubcode     ),
        .va_error             (va_error             ),
        .refill_ex            (MEM_tlbr_ex          ),
        .MEM_excp_tlb         (MEM_excp_tlb         ),
        .MEM_pc               (MEM_csr_pc           ),
        .MEM_vaddr            (MEM_vaddr            ),
        .csr_wnum             (csr_wnum             ),
        .csr_we               (csr_we               ),
        .csr_wmask            (csr_wmask            ),
        .csr_wvalue           (csr_wvalue           ),
        .ertn_flush           (MEM_ertn             ),
        .csr_tlb_in           (MEM_TLB_data         ),
        .llbit_in             (llbit_in             ),
        .llbit_set_in         (llbit_set_in         ),
        .lladdr_in            (lladdr_in            ),
        .lladdr_set_in        (lladdr_set_in        ),
    `endif
        .csr_rnum1            (csr_rnum1            ),
        .csr_rnum2            (csr_rnum2            ),
        .csr_rvalue1          (csr_rvalue1          ),
        .csr_rvalue2          (csr_rvalue2          ),
        .ipi_int_in           (1'b0                 ),
        .hw_int_in            (hw_int_in            ),
        .coreid_in            (1'b0                 ),
        .csr_tlb_out          (csr_tlb_out          ),
        .ex_entry             (ex_entry             ),
        .has_int              (has_int              ),
        .stable_counter       (stable_counter       ),
        .counter_id           (counter_id           ),
        .csr_tlbehi_rvalue    (csr_tlbehi_rvalue    ),
        .csr_crmd_rvalue      (csr_crmd_rvalue      ),
        .csr_dmw0_rvalue      (csr_dmw0_rvalue      ),
        .csr_dmw1_rvalue      (csr_dmw1_rvalue      ),
        .csr_tlbrentry_rvalue (csr_tlbrentry_rvalue ),
        .csr_era_rvalue       (csr_era_rvalue       ),
        .csr_asid_rvalue      (csr_asid_rvalue      ),
        .csr_plv              (csr_plv              ),
        .disable_cache_out    (disable_cache        ),
        .llbit_out            (llbit_out            ),
        .lladdr_out           (lladdr_out           )
        `ifdef DIFFTEST_EN
        ,
        .rand_index           (rand_index_diff      ),
        .csr_crmd_diff        (csr_crmd_diff_0      ),
        .csr_prmd_diff        (csr_prmd_diff_0      ),
        .csr_ecfg_diff        (csr_ectl_diff_0      ),
        .csr_estat_diff       (csr_estat_diff_0     ),
        .csr_era_diff         (csr_era_diff_0       ),
        .csr_badv_diff        (csr_badv_diff_0      ),
        .csr_eentry_diff      (csr_eentry_diff_0    ),
        .csr_tlbidx_diff      (csr_tlbidx_diff_0    ),
        .csr_tlbehi_diff      (csr_tlbehi_diff_0    ),
        .csr_tlbelo0_diff     (csr_tlbelo0_diff_0   ),
        .csr_tlbelo1_diff     (csr_tlbelo1_diff_0   ),
        .csr_asid_diff        (csr_asid_diff_0      ),
        .csr_save0_diff       (csr_save0_diff_0     ),
        .csr_save1_diff       (csr_save1_diff_0     ),
        .csr_save2_diff       (csr_save2_diff_0     ),
        .csr_save3_diff       (csr_save3_diff_0     ),
        .csr_tid_diff         (csr_tid_diff_0       ),
        .csr_tcfg_diff        (csr_tcfg_diff_0      ),
        .csr_tval_diff        (csr_tval_diff_0      ),
        .csr_ticlr_diff       (csr_ticlr_diff_0     ),
        .csr_llbctl_diff      (csr_llbctl_diff_0    ),
        .csr_tlbrentry_diff   (csr_tlbrentry_diff_0 ),
        .csr_dmw0_diff        (csr_dmw0_diff_0      ),
        .csr_dmw1_diff        (csr_dmw1_diff_0      ),
        .csr_pgdl_diff        (csr_pgdl_diff_0      ),
        .csr_pgdh_diff        (csr_pgdh_diff_0      )
        `endif
    );

    tlb u_tlb(
        .clk         (clk         ),
        .reset       (reset       ),
        .flush       (flush       ),
        .s0_vppn     (s0_vppn     ),
        .s0_odd_page (s0_va_bit12 ),
        .s0_asid     (s0_asid     ),
        .s0_valid    (s0_valid    ),
        .s0_ok       (s0_ok       ),
        .s0_found    (s0_found    ),
        .s0_index    (s0_index    ),
        .s0_ppn      (s0_ppn      ),
        .s0_ps       (s0_ps       ),
        .s0_plv      (s0_plv      ),
        .s0_mat      (s0_mat      ),
        .s0_d        (s0_d        ),
        .s0_v        (s0_v        ),
        .s1_vppn     (s1_vppn     ),
        .s1_odd_page (s1_va_bit12 ),
        .s1_asid     (s1_asid     ),
        .s1_valid    (s1_valid    ),
        .s1_ok       (s1_ok       ),
        .s1_found    (s1_found    ),
        .s1_index    (s1_index    ),
        .s1_ppn      (s1_ppn      ),
        .s1_ps       (s1_ps       ),
        .s1_plv      (s1_plv      ),
        .s1_mat      (s1_mat      ),
        .s1_d        (s1_d        ),
        .s1_v        (s1_v        ),
        .inv_op      (invtlb_op   ),
        .inv_en      (invtlb_en   ),
        .inv_asid    (invtlb_asid ),
        .inv_vpn     (invtlb_vppn ),
        .we          (tlb_we      ),
        .w_index     (w_index     ),
        .w_e         (w_e         ),
        .w_ps        (w_ps        ),
        .w_vppn      (w_vppn      ),
        .w_asid      (w_asid      ),
        .w_g         (w_g         ),
        .w_ppn0      (w_ppn0      ),
        .w_plv0      (w_plv0      ),
        .w_mat0      (w_mat0      ),
        .w_d0        (w_d0        ),
        .w_v0        (w_v0        ),
        .w_ppn1      (w_ppn1      ),
        .w_plv1      (w_plv1      ),
        .w_mat1      (w_mat1      ),
        .w_d1        (w_d1        ),
        .w_v1        (w_v1        ),
        .r_index     (r_index     ),
        .r_e         (r_e         ),
        .r_vppn      (r_vppn      ),
        .r_ps        (r_ps        ),
        .r_asid      (r_asid      ),
        .r_g         (r_g         ),
        .r_ppn0      (r_ppn0      ),
        .r_plv0      (r_plv0      ),
        .r_mat0      (r_mat0      ),
        .r_d0        (r_d0        ),
        .r_v0        (r_v0        ),
        .r_ppn1      (r_ppn1      ),
        .r_plv1      (r_plv1      ),
        .r_mat1      (r_mat1      ),
        .r_d1        (r_d1        ),
        .r_v1        (r_v1        )
    );

    mmu u_mmu(
        .clk                (clk                ),
        .reset              (reset              ),
        .s0_found           (s0_found           ),
        .s0_index           (s0_index           ),
        .s0_ppn             (s0_ppn             ),
        .s0_ps              (s0_ps              ),
        .s0_plv             (s0_plv             ),
        .s0_mat             (s0_mat             ),
        .s0_d               (s0_d               ),
        .s0_v               (s0_v               ),
        .s1_found           (s1_found           ),
        .s1_index           (s1_index           ),
        .s1_ppn             (s1_ppn             ),
        .s1_ps              (s1_ps              ),
        .s1_plv             (s1_plv             ),
        .s1_mat             (s1_mat             ),
        .s1_d               (s1_d               ),
        .s1_v               (s1_v               ),
        .r_e                (r_e                ),
        .r_vppn             (r_vppn             ),
        .r_ps               (r_ps               ),
        .r_asid             (r_asid             ),
        .r_g                (r_g                ),
        .r_ppn0             (r_ppn0             ),
        .r_plv0             (r_plv0             ),
        .r_mat0             (r_mat0             ),
        .r_d0               (r_d0               ),
        .r_v0               (r_v0               ),
        .r_ppn1             (r_ppn1             ),
        .r_plv1             (r_plv1             ),
        .r_mat1             (r_mat1             ),
        .r_d1               (r_d1               ),
        .r_v1               (r_v1               ),
        .inst_unhit         (inst_unhit         ),
        .data_unhit         (data_unhit         ),
        .tlb_data           (tlb_data           ),
        .csr_mmu_values     (csr_mmu_values     ),
        .inst_vaddr         (inst_vaddr         ),
        .data_vaddr         (EX1_data_vaddr     ),
        .inst_paddr         (inst_paddr         ),
        .data_paddr         (EX1_data_paddr     ),
        .sc_ll_paddr        (sc_ll_paddr        ),
        .IF_tlb_excps       (IF_tlb_excps       ),
        .EX1_tlb_excps      (EX1_tlb_excps      ),
        .mmu_inst_uncache_en(mmu_inst_uncache_en),
        .mmu_data_uncache_en(mmu_data_uncache_en),
        .mmu_sc_addr_eq     (mmu_sc_addr_eq     ),
        .EX1_load           (EX1_load           ),
        .EX1_store          (EX1_store          ),
        .EX1_cacop          (EX1_cacop          ),
        .cache_op_mode      (EX1_cache_op_mode  )
    );

    regfile u_regfile(
        .clk   (clk      ),
        .reset (reset    ),
        .raddr1(rf_raddr1),
        .rdata1(rf_rdata1),
        .raddr2(rf_raddr2),
        .rdata2(rf_rdata2),
        .raddr3(rf_raddr3),
        .rdata3(rf_rdata3),
        .raddr4(rf_raddr4),
        .rdata4(rf_rdata4)

    `ifdef DIFFTEST_DEBUG
        ,
        .rf_o  (rf_to_diff    ),
        .we1   (rf_we_diff    ),
        .waddr1(rf_waddr_diff ),
        .wdata1(rf_wdata_diff ),
        .we2   (0             ),
        .waddr2(0             ),
        .wdata2(0             )
    `else
        ,
        .we1   (rf_we1   ),
        .waddr1(rf_waddr1),
        .wdata1(rf_wdata1),
        .we2   (rf_we2   ),
        .waddr2(rf_waddr2),
        .wdata2(rf_wdata2)
    `endif
    );

    icache u_icache(
        .clk                 (clk                 ),
        .reset               (reset               ),
        .valid               (inst_valid          ),
        .index               (inst_index          ),
        .tag                 (inst_tag            ),
        .offset              (inst_offset         ),
        .addr_ok             (inst_addr_ok        ),
        .data_ok1            (inst_data_ok1       ),
        .data_ok2            (inst_data_ok2       ),
        .rdata1              (inst_rdata1         ),
        .rdata2              (inst_rdata2         ),
        .uncache_en          (inst_uncache_en     ),
        .icacop_op_en        (icacop_op_en        ),
        .cacop_op_mode       (cache_op_mode       ),
        .cacop_op_addr_index (data_index          ),
        .cacop_op_addr_tag   (data_tag            ),
        .cacop_op_addr_offset(data_offset         ),
        .icache_unbusy       (icache_unbusy       ),
    `ifdef DIFFTEST_DEBUG
        .cancel_req    (IF_inst_cancel_req | flush | MEM_flush | EX2_inst_cancel),
    `else
        .cancel_req    (IF_inst_cancel_req | flush | EX2_inst_cancel),
    `endif
        .rd_req              (inst_rd_req         ),
        .rd_type             (inst_rd_type        ),
        .rd_addr             (inst_rd_addr        ),
        .rd_rdy              (inst_rd_rdy         ),
        .ret_valid           (inst_ret_valid      ),
        .ret_last            (inst_ret_last       ),
        .ret_data            (inst_ret_data       ),
        .wr_req              (inst_wr_req         ),
        .wr_type             (inst_wr_type        ),
        .wr_addr             (inst_wr_addr        ),
        .wr_wstrb            (inst_wr_wstrb       ),
        .wr_data             (inst_wr_data        ),
        .wr_rdy              (inst_wr_rdy         ),
        .icache_miss         (icache_miss         ),
        .icache_hit          (icache_hit          )
    );

    dcache u_dcache(
        .clk                 (clk                 ),
        .reset               (reset               ),
    `ifdef DIFFTEST_DEBUG
        .cancel_req          (flush | MEM_flush | EX2_data_cancel),
    `else
        .cancel_req          (flush | EX2_data_cancel),
    `endif
        .valid               (data_valid          ),
        .op                  (data_op             ),
        .size                (data_size           ),
        .index               (data_index          ),
        .tag                 (data_tag            ),
        .offset              (data_offset         ),
        .wstrb               (data_wstrb          ),
        .wdata               (data_wdata          ),
        .addr_ok             (data_addr_ok        ),
        .data_ok             (data_data_ok        ),
        .rdata               (data_rdata          ),
        .uncache_en          (data_uncache_en     ),
        .dcacop_op_en        (dcacop_op_en        ),
        .cacop_op_mode       (cache_op_mode       ),
        .preld_en            (preld_en            ),
        .dcache_unbusy       (dcache_unbusy       ),
        .rd_req              (data_rd_req         ),
        .rd_type             (data_rd_type        ),
        .rd_addr             (data_rd_addr        ),
        .rd_rdy              (data_rd_rdy         ),
        .ret_valid           (data_ret_valid      ),
        .ret_last            (data_ret_last       ),
        .ret_data            (data_ret_data       ),
        .wr_req              (data_wr_req         ),
        .wr_type             (data_wr_type        ),
        .wr_addr             (data_wr_addr        ),
        .wr_wstrb            (data_wr_wstrb       ),
        .wr_data             (data_wr_data        ),
        .wr_rdy              (data_wr_rdy         ),
        .dcache_miss         (dcache_miss         ),
        .dcache_hit          (dcache_hit          )
    );

    wire btb_hit1;
    wire btb_hit2;

    assign btb_miss1 = ~btb_hit1;
    assign btb_miss2 = ~btb_hit2;

    btb u_btb( 
        .clk            (clk              ),
        .reset          (reset            ),
        .fetch_en       (PIF_valid        ),
        .fetch_pc1      (PIF_pc1          ),
        .ret_pc1        (pred_target1     ), 
        .taken1         (pred_taken1      ),
        .ret_en1        (btb_hit1         ),
        .ret_index1     (pred_index1      ),
        .fetch_pc2      (PIF_pc2          ),
        .ret_pc2        (pred_target2     ), 
        .taken2         (pred_taken2      ),
        .ret_en2        (btb_hit2         ),
        .ret_index2     (pred_index2      ),
        .operate_en     (operate_en       ),
        .operate_pc     (operate_pc       ),    
        .operate_index  (operate_index    ),
        .pop_ras        (pop_ras          ),
        .push_ras       (push_ras         ),
        .add_entry      (add_entry        ),    
        .pre_error      (pred_error       ),
        .pre_right      (pred_right       ),
        .target_error   (target_error     ),
        .right_orien    (right_orien      ),
        .right_target   (right_target     )
    );

    assign double_inst = MEM_mode;
    assign single_inst = ~MEM_mode;

    perf_counter u_perf_cnt(
        .clk               (clk               ),
        .reset             (reset             ),
        .dcache_miss       (real_dcache_miss  ),
        // .dcache_stall      (dcache_stall      ),
        .icache_miss       (real_icache_miss  ),
        // .icache_stall      (icache_stall      ),
        // .data_hazard_stall (stall_data_hazard ),
        // .tlb_stall         (tlb_stall         ),
        .br_inst           (br_inst           ),
        // .mem_inst          (mem_inst          ),
        .commit_inst       (MEM_valid         ),
        .br_pre_error      (br_taken          ),
        .single_inst       (single_inst       ),
        .double_inst       (double_inst       ),
        .fifo_full         (FIFO_full         ),
        .fifo_empty        (FIFO_empty        )
    );

`ifdef DIFFTEST_DEBUG
reg first_clk;
always@(posedge clk) begin
    if(reset) begin
        first_clk <= 1'b1;
    end
    else if(~CM_stall)begin
        first_clk <= 1'b1;
    end
    else if(first_clk) begin
        first_clk <= 1'b0;
    end
end
assign {rf_we_diff, rf_waddr_diff,rf_wdata_diff} = MEM_rf_bus_diff;
assign {MEM_rf_bus_diff,
        MEM_excp,
        MEM_ertn_diff,
        tlbfill_en_diff,
        MEM_csr_ecode_diff,
        timer_64_diff,
        csr_data_diff,
        debug0_wb_inst_diff,
        cnt_inst_diff,
        inst_ld_en_diff,
        ld_paddr_diff,
        ld_vaddr_diff,
        st_paddr_diff,
        st_vaddr_diff,
        inst_st_en_diff,
        st_data_diff,
        csr_rstat_en_diff
} = CM_diff_bus;
reg CM_real_valid;
always@(posedge clk) begin
    if(reset || MEM_ex_diff) begin
        CM_real_valid <= 1'b0;
    end
    else if(~CM_stall) begin
        CM_real_valid <= MEM_CM_valid;
    end
end
assign MEM_ex_diff = MEM_excp & CM_real_valid;
assign mem_valid_diff = CM_real_valid & ~MEM_ex_diff;

//to PIF
assign CM_ex_diff = MEM_ex_ctrl_diff;
assign CM_tlbr_ex_diff = MEM_tlbr_ex_ctrl_diff;
assign CM_ertn_diff = MEM_ertn_ctrl_diff;
// assign CM_refetch_diff = ;
assign CM_refetch_pc_diff = MEM_csr_pc_ctrl_diff;
assign flush_diff = CM_ex_diff | CM_ertn_diff | CM_refetch_diff;
assign flush = flush_diff;
//ctrl
assign {
    CM_refetch_diff           ,
    MEM_ex_ctrl_diff          ,
    MEM_csr_ecode_ctrl_diff   ,
    MEM_csr_esubcode_ctrl_diff,
    va_error_ctrl_diff        ,
    MEM_tlbr_ex_ctrl_diff     ,
    MEM_excp_tlb_ctrl_diff    ,
    MEM_csr_pc_ctrl_diff      ,
    MEM_vaddr_ctrl_diff       ,
    csr_wnum_ctrl_diff        ,
    csr_we_ctrl_diff          ,
    csr_wmask_ctrl_diff       ,
    csr_wvalue_ctrl_diff      ,
    MEM_ertn_ctrl_diff        ,
    MEM_TLB_data_ctrl_diff    ,
    llbit_in_ctrl_diff        ,
    llbit_set_in_ctrl_diff    ,
    lladdr_in_ctrl_diff       ,
    lladdr_set_in_ctrl_diff   
} = CM_diff_ctrl_bus & {`DIFF_WIDTH_MEM_CM_CTRL_BUS{CM_real_valid & CM_debug_valid}};
`endif

endmodule