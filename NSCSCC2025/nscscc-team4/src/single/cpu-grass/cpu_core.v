`include "header.h" 
`include "csr.h"

module cpu_core
    #(parameter TLBNUM = 16)
    (
    input  wire        clk,
    input  wire        reset,
    input  [7:0]       hw_int_in,
    // icache and axi 
    output            inst_rd_req,    
    output [2:0 ]     inst_rd_type,   
    output [31:0]     inst_rd_addr,   
    input             inst_rd_rdy,  
    input             inst_ret_valid, 
    input             inst_ret_last, 
    input [31:0]      inst_ret_data,  
    output            inst_wr_req,  
    output [2:0 ]     inst_wr_type,
    output [31:0]     inst_wr_addr, 
    output [3:0 ]     inst_wr_wstrb,
    output [127:0]    inst_wr_data, 
    input             inst_wr_rdy,
    // dcache and axi
    output            data_rd_req,  
    output [2:0 ]     data_rd_type, 
    output [31:0]     data_rd_addr, 
    input             data_rd_rdy,  
    input             data_ret_valid,
    input             data_ret_last,
    input [31:0]      data_ret_data,
    output            data_wr_req,  
    output [2:0 ]     data_wr_type, 
    output [31:0]     data_wr_addr, 
    output [3:0 ]     data_wr_wstrb,
    output [127:0]    data_wr_data,
    input             data_wr_rdy,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata

    `ifdef DIFFTEST_EN
    ,
    output [31:0]  debug0_wb_inst_diff ,
    output         mem_valid_diff      ,
    output         cnt_inst_diff       ,
    output [63:0]  timer_64_diff       ,
    output [ 7:0]  inst_ld_en_diff     ,
    output [31:0]  ld_paddr_diff       ,
    output [31:0]  ld_vaddr_diff       ,
    output [ 7:0]  inst_st_en_diff     ,
    output [31:0]  st_paddr_diff       ,
    output [31:0]  st_vaddr_diff       ,
    output [31:0]  st_data_diff        ,
    output         csr_rstat_en_diff   ,
    output [31:0]  csr_data_diff       ,

    output [ 4:0]  rand_index_diff     ,
    output         MEM_ex_diff         ,
    output         MEM_ertn_diff       ,
    output         tlbfill_en_diff     ,
    output [ 5:0]  MEM_csr_ecode_diff  ,

    output [31:0]  rf_to_diff [31:0], //名字和外面不一样

    output [31:0]  csr_crmd_diff_0     ,
    output [31:0]  csr_prmd_diff_0     ,
    output [31:0]  csr_ectl_diff_0     ,
    output [31:0]  csr_estat_diff_0    ,
    output [31:0]  csr_era_diff_0      ,
    output [31:0]  csr_badv_diff_0     ,
    output [31:0]  csr_eentry_diff_0   ,
    output [31:0]  csr_tlbidx_diff_0   ,
    output [31:0]  csr_tlbehi_diff_0   ,
    output [31:0]  csr_tlbelo0_diff_0  ,
    output [31:0]  csr_tlbelo1_diff_0  ,
    output [31:0]  csr_asid_diff_0     ,
    output [31:0]  csr_save0_diff_0    ,
    output [31:0]  csr_save1_diff_0    ,
    output [31:0]  csr_save2_diff_0    ,
    output [31:0]  csr_save3_diff_0    ,
    output [31:0]  csr_tid_diff_0      ,
    output [31:0]  csr_tcfg_diff_0     ,
    output [31:0]  csr_tval_diff_0     ,
    output [31:0]  csr_ticlr_diff_0    ,
    output [31:0]  csr_llbctl_diff_0   ,
    output [31:0]  csr_tlbrentry_diff_0,
    output [31:0]  csr_dmw0_diff_0     ,
    output [31:0]  csr_dmw1_diff_0     ,
    output [31:0]  csr_pgdl_diff_0     ,
    output [31:0]  csr_pgdh_diff_0     
    `endif
    );

    `ifdef DIFFTEST_EN
    wire [`DIFF_WIDTH_ID_EX1_BUS -1 : 0] ID_EX1_diff_bus;
    wire [`DIFF_WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_diff_bus;
    wire [`DIFF_WIDTH_EX2_MEM_BUS-1 : 0] EX2_MEM_diff_bus;
    `endif

    // unhit
    wire inst_unhit;
    wire data_unhit;
    wire s0_unbusy;
    wire s1_unbusy;

    // stall
    wire IF_stall;
    wire ID_stall;
    wire EX_stall;
    wire EX1_stall;
    wire EX2_stall;
    wire MEM_stall;

    // valid
    wire PIF_IF_valid;
    wire IF_valid;
    wire IF_ID_valid;
    wire ID_EX1_valid;
    wire EX1_valid;
    wire EX1_EX2_valid;
    wire EX2_MEM_valid;

    // bus
    wire [`WIDTH_PIF_IF_BUS - 1  : 0] PIF_IF_bus;
    wire [`WIDTH_IF_ID_BUS - 1   : 0] IF_ID_bus;
    wire [`WIDTH_ID_EX1_BUS - 1  : 0] ID_EX1_bus;
    wire [`WIDTH_BR_BUS - 1      : 0] br_bus;
    wire [`WIDTH_EX1_EX2_BUS - 1 -5+$clog2(TLBNUM): 0] EX1_EX2_bus;
    wire [`WIDTH_EX2_MEM_BUS - 1 -5+$clog2(TLBNUM): 0] EX2_MEM_bus;
    wire [`WIDTH_MEM_RF_BUS - 1  : 0] MEM_rf_bus;

    // forward
    wire [`WIDTH_EX1_FORWARD_BUS - 1 : 0] EX1_forward_bus;
    wire [`WIDTH_EX2_FORWARD_BUS - 1 : 0] EX2_forward_bus;
    wire [`WIDTH_MEM_FORWARD_BUS - 1 : 0] MEM_forward_bus;

    // mmu
    wire [ 31:0] inst_vaddr;
    wire [ 31:0] inst_paddr;
    wire         mmu_inst_uncache_en;
    wire         EX1_load;
    wire         EX1_store;
    wire         EX1_tlbsrch;
    wire         mmu_data_uncache_en;
    wire [ 31:0] EX1_data_paddr;
    wire [ 31:0] EX1_data_vaddr;
    wire         EX1_cacop;
    wire [ 94-5+$clog2(TLBNUM):0] tlb_data;
    wire [188:0] csr_mmu_values;
    wire         mmu_sc_addr_eq;
    wire [ 31:0] sc_ll_paddr;

    //regfile
    wire [ 4:0] rf_raddr1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire        rf_we;
    wire [ 4:0] rf_waddr;
    wire [31:0] rf_wdata;

    // csr
    wire [ 9:0] csr_asid_asid;
    wire [ 1:0] csr_plv;
    wire [31:0] csr_rvalue;
    wire [13:0] csr_num;
    wire        csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [ 5:0] MEM_csr_ecode;
    wire [ 8:0] MEM_csr_esubcode;
    wire [63:0] stable_counter;
    wire [31:0] counter_id;
    wire [98-5+$clog2(TLBNUM):0] MEM_TLB_data;
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

    // excp 
    wire       has_int;
    wire [4:0] EX1_tlb_excps;
    wire [2:0] IF_tlb_excps;
    wire       MEM_ex;
    wire       MEM_ertn;
    wire       MEM_tlbr_ex;
    wire       MEM_refetch;

    wire        va_error         ;
    wire        MEM_excp_tlb     ;

    // flush
    wire        flush;

    // icache
    wire        inst_uncache_en;
    wire        inst_tlb_excp_cancel_req;
    wire        EX2_inst_cancel;
    wire        inst_valid;
    wire        inst_addr_ok;
    wire        inst_data_ok;
    wire [ 7:0] inst_index;
    wire [19:0] inst_tag;
    wire [ 3:0] inst_offset;
    wire [31:0] inst_rdata;
    wire        icacop_op_en;    
    wire        icache_unbusy;

    // dcache
    wire        data_uncache_en;
    wire        EX2_data_cancel;
    wire        data_valid;
    wire        data_op;
    wire        data_addr_ok;
    wire        data_data_ok;
    wire [ 7:0] data_index;
    wire [19:0] data_tag;
    wire [ 3:0] data_offset;
    wire [31:0] data_rdata;
    wire [ 3:0] data_wstrb;
    wire [ 2:0] data_size;
    wire [31:0] data_wdata;
    wire [ 1:0] cache_op_mode;
    wire [ 1:0] EX1_cache_op_mode;
    wire        dcacop_op_en;
    wire        dcache_unbusy;
    wire        preld_en;

    // tlb
    wire [              18:0]    s0_vppn;
    wire                         s0_va_bit12;
    wire [               9:0]    s0_asid;
    wire                         s0_found;
    wire [$clog2(TLBNUM)-1:0]    s0_index;
    wire [              19:0]    s0_ppn;
    wire [               5:0]    s0_ps;
    wire [               1:0]    s0_plv;
    wire [               1:0]    s0_mat;
    wire                         s0_d;
    wire                         s0_v;
    wire                         s0_valid;
    wire                         s0_ok;
    wire  [              18:0]   s1_vppn;
    wire                         s1_va_bit12;
    wire  [               9:0]   s1_asid;
    wire                         s1_found;
    wire [$clog2(TLBNUM)-1:0]    s1_index;
    wire [              19:0]    s1_ppn;
    wire [               5:0]    s1_ps;
    wire [               1:0]    s1_plv;
    wire [               1:0]    s1_mat;
    wire                         s1_d;
    wire                         s1_v;
    wire                         s1_valid;
    wire                         s1_ok;
    wire  [               4:0]   EX1_invtlb_op;
    wire                         EX1_inst_invtlb;
    wire                         tlb_we;
    wire  [$clog2(TLBNUM)-1:0]   w_index;
    wire                         w_e;
    wire  [               5:0]   w_ps;
    wire  [              18:0]   w_vppn;
    wire  [               9:0]   w_asid;
    wire                         w_g;
    wire  [              19:0]   w_ppn0;
    wire  [               1:0]   w_plv0;
    wire  [               1:0]   w_mat0;
    wire                         w_d0;
    wire                         w_v0;
    wire  [              19:0]   w_ppn1;
    wire  [               1:0]   w_plv1;
    wire  [               1:0]   w_mat1;
    wire                         w_d1;
    wire                         w_v1;
    wire  [$clog2(TLBNUM)-1:0]   r_index;
    wire                         r_e;
    wire [              18:0]    r_vppn;
    wire [               5:0]    r_ps;
    wire [               9:0]    r_asid;
    wire                         r_g;
    wire [              19:0]    r_ppn0;
    wire [               1:0]    r_plv0;
    wire [               1:0]    r_mat0;
    wire                         r_d0;
    wire                         r_v0;
    wire [              19:0]    r_ppn1;     
    wire [               1:0]    r_plv1;
    wire [               1:0]    r_mat1;
    wire                         r_d1;
    wire                         r_v1;
    wire [              99-10+2*$clog2(TLBNUM):0]    csr_tlb_out;
    wire        invtlb_en  ;
    wire [ 4:0] invtlb_op  ;
    wire [ 9:0] invtlb_asid;
    wire [18:0] invtlb_vppn;
    // branch
    wire [  4:0] jump_op;
    wire [159:0] jump_target;

    // bp_unit
    wire [31:0] PIF_pc          ;
    wire        btb_miss        ;
    wire        pred_taken      ;
    wire [31:0] pred_target     ;
    wire [31:0] taken_update_en ;
    wire        target_update_en;
    // wire [31:0] ID_pc           ;
    wire [31:0] EX1_pc;
    wire        real_taken      ;
    wire [31:0] real_target     ;

    assign {rf_we, rf_waddr, rf_wdata} = MEM_rf_bus;
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
                            lladdr_out       ,
                            disable_cache    ,
                            csr_tlbehi_rvalue,
                            csr_crmd_rvalue  ,
                            csr_asid_rvalue  ,
                            csr_dmw0_rvalue  ,
                            csr_dmw1_rvalue  
                            };
    assign jump_op = {MEM_ex, MEM_ertn, MEM_tlbr_ex, MEM_refetch, br_bus[32]};
    assign jump_target = {
                         ex_entry            ,
                         csr_era_rvalue      ,
                         MEM_pc              ,
                         csr_tlbrentry_rvalue,
                         br_bus[31:0]
                         };
    assign EX_stall = EX1_stall || EX2_stall;

    PIF u_pif(
        .clk           (clk           ),
        .reset         (reset         ),
        .flush         (flush         ),
        .jump_op       (jump_op       ),
        .jump_target   (jump_target   ),
        .PIF_pc        (PIF_pc        ),
        .btb_miss      (btb_miss      ),
        .pred_taken    (pred_taken    ),
        .pred_target   (pred_target   ),
        .IF_stall      (IF_stall      ),
        .ID_stall      (ID_stall      ),
        .EX_stall      (EX_stall      ),
        .MEM_stall     (MEM_stall     ),
        .PIF_IF_valid  (PIF_IF_valid  ),
        .PIF_IF_bus    (PIF_IF_bus    ),

        .csr_asid_asid (csr_asid_asid),
        .IF_tlb_excps  (IF_tlb_excps ),
        .inst_vaddr    (inst_vaddr   ),
        .inst_paddr    (inst_paddr   ),
        .mmu_inst_uncache_en (mmu_inst_uncache_en),
        .inst_unhit    (inst_unhit   ),
        .s0_valid      (s0_valid     ),
        .s0_ok         (s0_ok        ),
        .s0_unbusy     (s0_unbusy    ),
        .s0_vppn       (s0_vppn      ),
        .s0_va_bit12   (s0_va_bit12  ),
        .s0_asid       (s0_asid      )
    );

    IF u_if(
        .clk                     (clk                     ),
        .reset                   (reset                   ),
        .flush                   (flush | br_bus[32]      ),
        .ID_stall                (ID_stall                ),
        .EX_stall                (EX_stall                ),
        .MEM_stall               (MEM_stall               ),
        .IF_stall                (IF_stall                ),
        .PIF_IF_valid            (PIF_IF_valid            ),
        .IF_valid                (IF_valid                ),
        .IF_ID_valid             (IF_ID_valid             ),
        .PIF_IF_bus              (PIF_IF_bus              ),
        .IF_ID_bus               (IF_ID_bus               ),
        .inst_uncache_en         (inst_uncache_en         ),
        .inst_tlb_excp_cancel_req(inst_tlb_excp_cancel_req),
        .inst_valid              (inst_valid              ),
        .inst_addr_ok            (inst_addr_ok            ),
        .inst_data_ok            (inst_data_ok            ),
        .inst_index              (inst_index              ),
        .inst_tag                (inst_tag                ),
        .inst_offset             (inst_offset             ),
        .inst_rdata              (inst_rdata              )
    );

    ID u_id(
        .clk             (clk             ),
        .reset           (reset           ),
        .has_int         (has_int         ),
        .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
        .EX_stall        (EX_stall        ),
        .MEM_stall       (MEM_stall       ),
        .flush           (flush           ),
        .taken           (br_bus[32]      ),
        .EX1_forward_bus (EX1_forward_bus ),
        .EX2_forward_bus (EX2_forward_bus ),
        .MEM_forward_bus (MEM_forward_bus ),
        .csr_plv         (csr_plv         ),
        .ID_llbit        (llbit_out       ),
        .IF_ID_valid     (IF_ID_valid     ),
        .IF_ID_bus       (IF_ID_bus       ),
        .ID_EX1_valid    (ID_EX1_valid    ),
        .ID_stall        (ID_stall        ),
        .ID_EX1_bus      (ID_EX1_bus      ),
        .rf_raddr1       (rf_raddr1       ),
        .rf_raddr2       (rf_raddr2       ),
        .rf_rdata1       (rf_rdata1       ),
        .rf_rdata2       (rf_rdata2       )

        `ifdef DIFFTEST_EN
        ,
        .ID_EX1_diff_bus(ID_EX1_diff_bus)
        `endif
    );

    EX1 u_ex1(
        .clk             (clk            ),
        .reset           (reset          ),
        .flush           (flush          ),
        .EX1_forward_bus (EX1_forward_bus),
        .EX2_stall       (EX2_stall      ),
        .MEM_stall       (MEM_stall      ),
        .EX1_stall       (EX1_stall      ),
        .ID_EX1_valid    (ID_EX1_valid   ),
        .EX1_valid       (EX1_valid      ),
        .EX1_EX2_valid   (EX1_EX2_valid  ),
        .ID_EX1_bus      (ID_EX1_bus     ),
        .EX1_EX2_bus     (EX1_EX2_bus    ),
        .br_bus          (br_bus          ),

        .csr_tlbehi_rvalue       (csr_tlbehi_rvalue       ),
        .csr_asid_asid           (csr_asid_asid           ),
        .tlb_data                (tlb_data                ),
        .EX1_tlb_excps           (EX1_tlb_excps           ),
        .mmu_data_uncache_en     (mmu_data_uncache_en     ),
        .mmu_sc_addr_eq          (mmu_sc_addr_eq          ),
        .sc_ll_paddr             (sc_ll_paddr             ),
        .EX1_data_paddr          (EX1_data_paddr          ),
        .EX1_data_vaddr          (EX1_data_vaddr          ),
        .EX1_load                (EX1_load                ),
        .EX1_store               (EX1_store               ),
        .EX1_cacop               (EX1_cacop               ),
        .EX1_cache_op_mode       (EX1_cache_op_mode       ),
        .icache_unbusy           (icache_unbusy           ),
        .dcache_unbusy           (dcache_unbusy           ),
        .data_valid              (data_valid              ),
        .data_index              (data_index              ),
        .data_op                 (data_op                 ),
        .data_unhit              (data_unhit              ),
        .data_wstrb              (data_wstrb              ),
        .data_size               (data_size               ),
        .data_wdata              (data_wdata              ),
        .data_offset             (data_offset             ),
        .cache_op_mode           (cache_op_mode           ),
        .icacop_op_en            (icacop_op_en            ),
        .dcacop_op_en            (dcacop_op_en            ),
        .preld_en                (preld_en                ),
        .s1_vppn                 (s1_vppn                 ),
        .s1_va_bit12             (s1_va_bit12             ),
        .s1_asid                 (s1_asid                 ),
        .s1_unbusy               (s1_unbusy               ),
        .s1_valid                (s1_valid                ),
        .s1_ok                   (s1_ok                   ),

        .taken_update_en (taken_update_en ),
        .target_update_en(target_update_en),
        .EX1_pc          (EX1_pc           ),
        .real_taken      (real_taken      ),
        .real_target     (real_target     )
        `ifdef DIFFTEST_EN
        ,
        .ID_EX1_diff_bus(ID_EX1_diff_bus),
        .EX1_EX2_diff_bus(EX1_EX2_diff_bus)
        `endif
    );

    EX2 u_ex2(
        .clk                     (clk                     ),
        .reset                   (reset                   ),
        .flush                   (flush                   ),
        .EX2_forward_bus         (EX2_forward_bus         ),
        .MEM_stall               (MEM_stall               ),
        .EX2_stall               (EX2_stall               ),
        .EX1_EX2_valid           (EX1_EX2_valid           ),
        .EX2_MEM_valid           (EX2_MEM_valid           ),
        .EX1_EX2_bus             (EX1_EX2_bus             ),
        .EX2_MEM_bus             (EX2_MEM_bus             ),
        .EX2_data_cancel         (EX2_data_cancel         ),
        .EX2_inst_cancel         (EX2_inst_cancel         ),
        .data_uncache_en         (data_uncache_en         ),
        .data_addr_ok            (data_addr_ok            ),
        .data_data_ok            (data_data_ok            ),
        .data_tag                (data_tag                ),
        .data_rdata              (data_rdata              )
        `ifdef DIFFTEST_EN
        ,
        .EX1_EX2_diff_bus(EX1_EX2_diff_bus),
        .EX2_MEM_diff_bus(EX2_MEM_diff_bus)
        `endif
    );

    MEM u_mem(
        .clk                (clk                ),
        .reset              (reset              ),
        .EX2_MEM_bus        (EX2_MEM_bus        ),
        .flush              (flush              ),
        .EX2_MEM_valid      (EX2_MEM_valid      ),
        .MEM_forward_bus    (MEM_forward_bus    ),
        .MEM_stall          (MEM_stall          ),
        .MEM_ex             (MEM_ex             ),
        .MEM_ertn           (MEM_ertn           ),
        .MEM_tlbr_ex        (MEM_tlbr_ex        ),
        .MEM_refetch        (MEM_refetch        ),
        .va_error           (va_error           ),
        .MEM_excp_tlb       (MEM_excp_tlb       ),
        .MEM_rf_bus         (MEM_rf_bus         ),
        .MEM_pc             (MEM_pc             ),
        .MEM_vaddr          (MEM_vaddr          ),
        .csr_rvalue         (csr_rvalue         ),
        .csr_num            (csr_num            ),
        .csr_we             (csr_we             ),
        .csr_wmask          (csr_wmask          ),
        .csr_wvalue         (csr_wvalue         ),
        .MEM_csr_ecode      (MEM_csr_ecode      ),
        .MEM_csr_esubcode   (MEM_csr_esubcode   ),
        .stable_counter     (stable_counter     ),
        .counter_id         (counter_id         ),
        .csr_llbit          (llbit_out          ),
        .MEM_llbit_in       (llbit_in           ),
        .MEM_llbit_set      (llbit_set_in       ),
        .MEM_lladdr_in      (lladdr_in          ),
        .MEM_lladdr_set     (lladdr_set_in      ),
        .MEM_TLB_data       (MEM_TLB_data       ),
        .invtlb_en          (invtlb_en          ),
        .invtlb_op          (invtlb_op          ),
        .invtlb_asid        (invtlb_asid        ),
        .invtlb_vppn        (invtlb_vppn        ),
        .debug_wb_pc        (debug_wb_pc        ),
        .debug_wb_rf_we     (debug_wb_rf_we     ),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum   ),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata  )

        `ifdef DIFFTEST_EN
        ,
        .EX2_MEM_diff_bus     (EX2_MEM_diff_bus     ),
        .debug0_wb_inst       (debug0_wb_inst       ),
        .mem_valid_diff       (mem_valid_diff       ),
        .mem_cnt_inst_diff    (cnt_inst_diff        ),
        .mem_timer_64_diff    (timer_64_diff        ),
        .mem_inst_ld_en_diff  (inst_ld_en_diff      ),
        .mem_ld_paddr_diff    (ld_paddr_diff        ),
        .mem_ld_vaddr_diff    (ld_vaddr_diff        ),
        .mem_inst_st_en_diff  (inst_st_en_diff      ),
        .mem_st_paddr_diff    (st_paddr_diff        ),
        .mem_st_vaddr_diff    (st_vaddr_diff        ),
        .mem_st_data_diff     (st_data_diff         ),
        .mem_csr_rstat_en_diff(csr_rstat_en_diff    ),
        .mem_csr_data_diff    (csr_data_diff        )
        `endif
    );

    csr u_csr(
        .clk                  (clk                   ),
        .reset                (reset                 ),
        .MEM_ex               (MEM_ex                ),
        .MEM_ecode            (MEM_csr_ecode         ),
        .MEM_esubcode         (MEM_csr_esubcode      ),
        .va_error             (va_error              ),
        .MEM_excp_tlb         (MEM_excp_tlb          ),
        .MEM_pc               (MEM_pc                ),
        .MEM_vaddr            (MEM_vaddr             ),
        .csr_num              (csr_num               ),
        .csr_we               (csr_we                ),
        .csr_wmask            (csr_wmask             ),
        .csr_wvalue           (csr_wvalue            ),
        .csr_rvalue           (csr_rvalue            ),
        .ipi_int_in           (1'b0                  ),
        .hw_int_in            (hw_int_in             ),
        .coreid_in            (1'b0                  ),
        .ertn_flush           (MEM_ertn              ),
        .refill_ex            (MEM_tlbr_ex           ),
        .csr_tlb_in           (MEM_TLB_data          ),
        .csr_tlb_out          (csr_tlb_out           ),
        .ex_entry             (ex_entry              ),
        .has_int              (has_int               ),
        .stable_counter       (stable_counter        ),
        .counter_id           (counter_id            ),
        .csr_tlbehi_rvalue    (csr_tlbehi_rvalue     ),
        .csr_crmd_rvalue      (csr_crmd_rvalue       ),
        .csr_dmw0_rvalue      (csr_dmw0_rvalue       ),
        .csr_dmw1_rvalue      (csr_dmw1_rvalue       ),
        .csr_tlbrentry_rvalue (csr_tlbrentry_rvalue  ),
        .csr_era_rvalue       (csr_era_rvalue        ),
        .csr_asid_rvalue      (csr_asid_rvalue       ),
        .csr_plv              (csr_plv               ),
        .disable_cache_out    (disable_cache         ),
        .llbit_in             (llbit_in              ),
        .llbit_set_in         (llbit_set_in          ),
        .lladdr_in            (lladdr_in             ),
        .lladdr_set_in        (lladdr_set_in         ),
        .llbit_out            (llbit_out             ),
        .lladdr_out           (lladdr_out            )

        `ifdef DIFFTEST_EN
            ,
        .rand_index_diff    (rand_index_diff     ),
        .csr_crmd_diff      (csr_crmd_diff_0     ),
        .csr_prmd_diff      (csr_prmd_diff_0     ),
        .csr_ecfg_diff      (csr_ectl_diff_0     ),
        .csr_estat_diff     (csr_estat_diff_0    ),
        .csr_era_diff       (csr_era_diff_0      ),
        .csr_badv_diff      (csr_badv_diff_0     ),
        .csr_eentry_diff    (csr_eentry_diff_0   ),
        .csr_tlbidx_diff    (csr_tlbidx_diff_0   ),
        .csr_tlbehi_diff    (csr_tlbehi_diff_0   ),
        .csr_tlbelo0_diff   (csr_tlbelo0_diff_0  ),
        .csr_tlbelo1_diff   (csr_tlbelo1_diff_0  ),
        .csr_asid_diff      (csr_asid_diff_0     ),
        .csr_save0_diff     (csr_save0_diff_0    ),
        .csr_save1_diff     (csr_save1_diff_0    ),
        .csr_save2_diff     (csr_save2_diff_0    ),
        .csr_save3_diff     (csr_save3_diff_0    ),
        .csr_tid_diff       (csr_tid_diff_0      ),
        .csr_tcfg_diff      (csr_tcfg_diff_0     ),
        .csr_tval_diff      (csr_tval_diff_0     ),
        .csr_ticlr_diff     (csr_ticlr_diff_0    ),
        .csr_llbctl_diff    (csr_llbctl_diff_0   ),
        .csr_tlbrentry_diff (csr_tlbrentry_diff_0),
        .csr_dmw0_diff      (csr_dmw0_diff_0     ),
        .csr_dmw1_diff      (csr_dmw1_diff_0     ),
        .csr_pgdl_diff      (csr_pgdl_diff_0     ),
        .csr_pgdh_diff      (csr_pgdh_diff_0     )
        `endif
    );

    tlb u_tlb(
        .clk           (clk            ),
        .reset         (reset          ),
        .flush         (MEM_ex         ),
        // search port 0 (for fetch)
        .s0_vppn       (s0_vppn        ),
        .s0_odd_page   (s0_va_bit12    ),
        .s0_asid       (s0_asid        ),
        .s0_found      (s0_found       ),
        .s0_index      (s0_index       ),
        .s0_ppn        (s0_ppn         ),  
        .s0_ps         (s0_ps          ),
        .s0_plv        (s0_plv         ),
        .s0_mat        (s0_mat         ),
        .s0_d          (s0_d           ),
        .s0_v          (s0_v           ),
        .s0_valid      (s0_valid       ),
        .s0_ok         (s0_ok          ),
        .s0_unbusy     (s0_unbusy      ),
        // search port 1 (for load/store)
        .s1_vppn       (s1_vppn        ),
        .s1_odd_page   (s1_va_bit12    ),
        .s1_asid       (s1_asid        ),
        .s1_found      (s1_found       ),
        .s1_index      (s1_index       ),
        .s1_ppn        (s1_ppn         ),
        .s1_ps         (s1_ps          ),
        .s1_plv        (s1_plv         ),
        .s1_mat        (s1_mat         ),
        .s1_d          (s1_d           ),
        .s1_v          (s1_v           ),
        .s1_valid      (s1_valid       ),
        .s1_ok         (s1_ok          ),
        .s1_unbusy     (s1_unbusy      ),
        // invtlb opcode
        .inv_op        (invtlb_op      ),
        .inv_en        (invtlb_en      ),
        .inv_asid      (invtlb_asid    ),
        .inv_vpn       (invtlb_vppn    ),
        // write port
        .we            (tlb_we         ),
        .w_index       (w_index        ),
        .w_e           (w_e            ),
        .w_ps          (w_ps           ),
        .w_vppn        (w_vppn         ), 
        .w_asid        (w_asid         ),
        .w_g           (w_g            ),
        .w_ppn0        (w_ppn0         ),
        .w_plv0        (w_plv0         ),
        .w_mat0        (w_mat0         ),
        .w_d0          (w_d0           ),
        .w_v0          (w_v0           ),
        .w_ppn1        (w_ppn1         ),
        .w_plv1        (w_plv1         ),
        .w_mat1        (w_mat1         ),
        .w_d1          (w_d1           ),
        .w_v1          (w_v1           ),
        // read port
        .r_index       (r_index        ),
        .r_e           (r_e            ),
        .r_vppn        (r_vppn         ),
        .r_ps          (r_ps           ),
        .r_asid        (r_asid         ),
        .r_g           (r_g            ),
        .r_ppn0        (r_ppn0         ),
        .r_plv0        (r_plv0         ),
        .r_mat0        (r_mat0         ),
        .r_d0          (r_d0           ),
        .r_v0          (r_v0           ),
        .r_ppn1        (r_ppn1         ),
        .r_plv1        (r_plv1         ),
        .r_mat1        (r_mat1         ),
        .r_d1          (r_d1           ),
        .r_v1          (r_v1           )
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
        .clk    (clk       ),
        .raddr1 (rf_raddr1 ),
        .rdata1 (rf_rdata1 ),
        .raddr2 (rf_raddr2 ),
        .rdata2 (rf_rdata2 ),
        .we     (rf_we     ),
        .waddr  (rf_waddr  ),
        .wdata  (rf_wdata  )

        `ifdef DIFFTEST_EN
        ,
        .rf_o(rf_to_diff)   // difftest
        `endif 
    );

    icache u_icache(
        .clk                    (clk                    ),
        .reset                  (reset                  ),
        .valid                  (inst_valid             ),
        .index                  (inst_index             ),
        .tag                    (inst_tag               ),
        .offset                 (inst_offset            ),
        .addr_ok                (inst_addr_ok           ),
        .data_ok                (inst_data_ok           ),
        .rdata                  (inst_rdata             ),
        .uncache_en             (inst_uncache_en        ),
        .icacop_op_en           (icacop_op_en           ),
        .cacop_op_mode          (cache_op_mode          ),
        .cacop_op_addr_index    (data_index             ),
        .cacop_op_addr_tag      (data_tag               ),
        .cacop_op_addr_offset   (data_offset            ),
        .icache_unbusy          (icache_unbusy          ),
        .cancel_req    (inst_tlb_excp_cancel_req | flush | EX2_inst_cancel),
        .rd_req                 (inst_rd_req            ),
        .rd_type                (inst_rd_type           ),
        .rd_addr                (inst_rd_addr           ),
        .rd_rdy                 (inst_rd_rdy            ),
        .ret_valid              (inst_ret_valid         ),
        .ret_last               (inst_ret_last          ),
        .ret_data               (inst_ret_data          ),
        .wr_req                 (inst_wr_req            ),
        .wr_type                (inst_wr_type           ),
        .wr_addr                (inst_wr_addr           ),
        .wr_wstrb               (inst_wr_wstrb          ),
        .wr_data                (inst_wr_data           ),
        .wr_rdy                 (inst_wr_rdy            )
    );

    dcache u_dcache(
        .clk                    (clk                    ),
        .reset                  (reset                  ),
        .cancel_req             (flush | EX2_data_cancel),
        .valid                  (data_valid             ),
        .op                     (data_op                ),
        .size                   (data_size              ),
        .index                  (data_index             ),
        .tag                    (data_tag               ),
        .offset                 (data_offset            ),
        .wstrb                  (data_wstrb             ),
        .wdata                  (data_wdata             ),
        .addr_ok                (data_addr_ok           ),
        .data_ok                (data_data_ok           ),
        .rdata                  (data_rdata             ),
        .uncache_en             (data_uncache_en        ),
        .dcacop_op_en           (dcacop_op_en           ),
        .cacop_op_mode          (cache_op_mode          ),
        .preld_en               (preld_en               ),
        .dcache_unbusy          (dcache_unbusy          ),
        .rd_req                 (data_rd_req            ),
        .rd_type                (data_rd_type           ),
        .rd_addr                (data_rd_addr           ),
        .rd_rdy                 (data_rd_rdy            ),
        .ret_valid              (data_ret_valid         ),
        .ret_last               (data_ret_last          ),
        .ret_data               (data_ret_data          ),
        .wr_req                 (data_wr_req            ),
        .wr_type                (data_wr_type           ),
        .wr_addr                (data_wr_addr           ),
        .wr_wstrb               (data_wr_wstrb          ),
        .wr_data                (data_wr_data           ),
        .wr_rdy                 (data_wr_rdy            )
    );

    bp_unit u_bp_unit(
        .clk              (clk             ),
        .reset            (reset           ),
        .PIF_pc           (PIF_pc          ),
        .btb_miss         (btb_miss        ),
        .pred_taken       (pred_taken      ),
        .pred_target      (pred_target     ),
        .taken_update_en  (taken_update_en ),
        .target_update_en (target_update_en),
        .ID_pc            (EX1_pc           ),
        .real_taken       (real_taken      ),
        .real_target      (real_target     )
    );

`ifdef DIFFTEST_EN
    assign MEM_ex_diff = MEM_ex;
    assign MEM_ertn_diff = MEM_ertn;
    assign tlbfill_en_diff = MEM_TLB_data[97-5+$clog2(TLBNUM)];
    assign MEM_csr_ecode_diff = MEM_csr_ecode;
`endif   

endmodule