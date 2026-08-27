`include "header.v"

module csr_regfile (
    input wire        clk,
    input wire        resetn,
    input wire [ 7:0] intrpt,
    input wire        ipi_int,
    input wire [31:0] pc,
    input wire [31:0] vaddr,


    input  wire [13:0] raddr,
    output reg  [31:0] rdata,

    input wire [13:0] waddr,
    input wire        we,
    input wire [31:0] wdata,
    input wire [31:0] wmask,


    input wire is_exception,
    input wire ertn_flush,

    output wire has_int,

    input wire is_int,
    input wire is_sys,
    input wire is_adef,
    input wire is_ale,
    input wire is_brk,
    input wire is_ine,

    input wire is_tlbr,
    input wire is_inst_tlbr,
    input wire is_inst_pif,
    input wire is_inst_ppi,
    input wire is_data_tlbr,
    input wire is_data_pil,
    input wire is_data_pis,
    input wire is_data_ppi,
    input wire is_data_pme,


    output wire [31:0] exception_enter_addr,
    output wire [31:0] exception_return_addr,
    output wire [31:0] exception_tlb_enter_addr,


    output wire [31:0] out_csr_crmd,
    output wire [31:0] out_csr_dmw0,
    output wire [31:0] out_csr_dmw1,
    output wire [31:0] out_csr_asid,
    output wire [31:0] out_csr_estat,
    output wire [31:0] out_csr_tlbidx,
    output wire [31:0] out_csr_tlbehi,
    output wire [31:0] out_csr_tlbelo0,
    output wire [31:0] out_csr_tlbelo1,

    input wire        is_tlbsrch,
    input wire        tlbsrch_hit,
    input wire        is_tlbrd,
    input wire        tlbrd_hit,
    input wire [31:0] tlb_w_csr_tlbelo0,
    input wire [31:0] tlb_w_csr_tlbelo1,
    input wire [31:0] tlb_w_csr_tlbidx,
    input wire [31:0] tlb_w_csr_tlbehi,
    input wire [31:0] tlb_w_csr_asid,

    input wire is_ll_w,
    input wire is_sc_w,

    output wire llbit

);

    reg  [ 1:0] csr_crmd_plv;
    reg         csr_crmd_ie;
    // *******************************
    reg         csr_crmd_da;
    reg         csr_crmd_pg;
    reg  [ 1:0] csr_crmd_datf;
    reg  [ 1:0] csr_crmd_datm;
    // *******************************
    wire [31:0] csr_crmd;


    reg  [ 1:0] csr_prmd_pplv;
    reg         csr_prmd_pie;
    wire [31:0] csr_prmd;


    reg  [ 9:0] csr_ecfg_lie_9_0;
    reg  [ 1:0] csr_ecfg_lie_12_11;
    wire [31:0] csr_ecfg;


    reg  [ 1:0] csr_estat_is_1_0;
    reg  [ 7:0] csr_estat_is_9_2;
    reg         csr_estat_is_11;
    reg         csr_estat_is_12;
    reg  [ 5:0] csr_estat_ecode;
    reg  [ 8:0] csr_estat_esubcode;
    wire [31:0] csr_estat;


    reg  [31:0] csr_era_pc;
    wire [31:0] csr_era;


    reg  [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv;


    reg  [25:0] csr_eentry_va;
    wire [31:0] csr_eentry;


    reg  [31:0] csr_save0_data;
    wire [31:0] csr_save0;


    reg  [31:0] csr_save1_data;
    wire [31:0] csr_save1;


    reg  [31:0] csr_save2_data;
    wire [31:0] csr_save2;


    reg  [31:0] csr_save3_data;
    wire [31:0] csr_save3;


    reg  [31:0] csr_tid_tid;
    wire [31:0] csr_tid;


    reg         csr_tcfg_en;
    reg         csr_tcfg_periodic;
    reg  [29:0] csr_tcfg_initval;

    wire [31:0] csr_tcfg;
    wire [31:0] csr_tcfg_next;



    reg  [31:0] timer_cnt;

    // reg [31:0] csr_tval_timeval;
    wire [31:0] csr_tval;


    wire        csr_ticlr_clr;


    wire [31:0] csr_ticlr;

    //****************************

    wire [31:0] csr_tlbidx;
    wire [31:0] csr_tlbehi;
    wire [31:0] csr_tlbelo0;
    wire [31:0] csr_tlbelo1;
    wire [31:0] csr_asid;
    wire [31:0] csr_pgdl;
    wire [31:0] csr_pgdh;
    wire [31:0] csr_pgd;
    wire [31:0] csr_tlbrentry;
    wire [31:0] csr_dmw0;
    wire [31:0] csr_dmw1;



    //****************************


    wire [ 5:0] ecode;
    wire [ 8:0] esubcode;


    //****************************

    reg  [ 3:0] csr_tlbidx_index;
    reg  [ 5:0] csr_tlbidx_ps;
    reg         csr_tlbidx_ne;

    reg  [18:0] csr_tlbehi_vppn;

    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg  [ 1:0] csr_tlbelo0_plv;
    reg  [ 1:0] csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg  [23:0] csr_tlbelo0_ppn;

    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg  [ 1:0] csr_tlbelo1_plv;
    reg  [ 1:0] csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg  [23:0] csr_tlbelo1_ppn;

    reg  [ 9:0] csr_asid_asid;
    wire [ 7:0] csr_asid_asidbits;

    //***************************
    reg  [19:0] csr_pgdl_base;

    reg  [19:0] csr_pgdh_base;

    wire [19:0] csr_pgd_base;
    //***************************


    reg  [25:0] csr_tlbrentry_pa;

    reg         csr_dmw0_plv0;
    reg         csr_dmw0_plv3;
    reg  [ 1:0] csr_dmw0_mat;
    reg  [ 2:0] csr_dmw0_pseg;
    reg  [ 2:0] csr_dmw0_vseg;

    reg         csr_dmw1_plv0;
    reg         csr_dmw1_plv3;
    reg  [ 1:0] csr_dmw1_mat;
    reg  [ 2:0] csr_dmw1_pseg;
    reg  [ 2:0] csr_dmw1_vseg;


    //****************************

    reg         csr_llbctl_rollb;
    reg         csr_llbctl_wcllb;
    reg         csr_llbctl_klo;


    wire [31:0] csr_llbctl;

    assign csr_llbctl = {28'b0, csr_llbctl_klo, 1'b0, csr_llbctl_rollb};

    reg [31:0] llbit_addr;

    assign llbit = csr_llbctl_rollb;

    always @(posedge clk) begin
        if (!resetn) llbit_addr <= 32'b0;
        else if (is_ll_w) llbit_addr <= vaddr;
    end

    always @(posedge clk) begin
        if (!resetn) csr_llbctl_rollb <= 1'b0;
        else if (we && waddr == `CSR_ADDR_LLBCTL && (wmask[`CSR_LLBCTL_WCLLB] & wdata[`CSR_LLBCTL_WCLLB])) csr_llbctl_rollb <= 1'b0;
        else if (is_ll_w) csr_llbctl_rollb <= 1'b1;
        else if (ertn_flush && !csr_llbctl_klo) csr_llbctl_rollb <= 1'b0;
        else if (is_sc_w && llbit_addr == vaddr) csr_llbctl_rollb <= 1'b0;
    end



    always @(posedge clk) begin
        if (!resetn) csr_llbctl_klo <= 1'b0;
        else if (we && waddr == `CSR_ADDR_LLBCTL) csr_llbctl_klo <= wmask[`CSR_LLBCTL_KLO] & wdata[`CSR_LLBCTL_KLO] | ~wmask[`CSR_LLBCTL_KLO] & csr_llbctl_klo;
        else if (ertn_flush) csr_llbctl_klo <= 1'b0;
    end

`ifdef difftest

    DifftestCSRRegState u_difftest_CSRRegState (
        .clock    (clk),
        .coreid   (8'd0),
        .crmd     ({32'd0, csr_crmd}),
        .prmd     ({32'd0, csr_prmd}),       // TODO: connect if CSR has PRMD
        .euen     (64'd0),
        .ecfg     ({32'd0, csr_ecfg}),
        .estat    ({32'd0, csr_estat}),
        .era      ({32'd0, csr_era}),        // TODO: connect if CSR has ERA
        .badv     ({32'd0, csr_badv}),       // TODO: connect if CSR has BADV
        .eentry   ({32'd0, csr_eentry}),     // TODO: connect if CSR has EENTRY
        .tlbidx   ({32'd0, csr_tlbidx}),
        .tlbehi   ({32'd0, csr_tlbehi}),
        .tlbelo0  ({32'd0, csr_tlbelo0}),
        .tlbelo1  ({32'd0, csr_tlbelo1}),
        .asid     ({32'd0, csr_asid}),
        .pgdl     ({32'd0, csr_pgdl}),
        .pgdh     ({32'd0, csr_pgdh}),
        .save0    ({32'd0, csr_save0}),
        .save1    ({32'd0, csr_save1}),
        .save2    ({32'd0, csr_save2}),
        .save3    ({32'd0, csr_save3}),
        .tid      ({32'd0, csr_tid}),
        .tcfg     ({32'd0, csr_tcfg}),
        .tval     ({32'd0, csr_tval}),
        .ticlr    ({32'd0, csr_ticlr}),
        .llbctl   ({32'b0, csr_llbctl}),
        .tlbrentry({32'd0, csr_tlbrentry}),
        .dmw0     ({32'd0, csr_dmw0}),
        .dmw1     ({32'd0, csr_dmw1})
    );

`endif


    assign exception_enter_addr = csr_eentry;
    assign exception_return_addr = csr_era;
    assign exception_tlb_enter_addr = csr_tlbrentry;



    assign ecode = is_adef ? `EXCEPTION_ECODE_ADE :
               is_inst_tlbr ? `EXCEPTION_ECODE_TLBR :
               is_inst_pif ? `EXCEPTION_ECODE_PIF :
               is_inst_ppi ? `EXCEPTION_ECODE_PPI :
               is_int ? `EXCEPTION_ECODE_INT :
               is_ine ? `EXCEPTION_ECODE_INE :
               is_brk ? `EXCEPTION_ECODE_BRK :
               is_sys ? `EXCEPTION_ECODE_SYS : 
               is_ale ? `EXCEPTION_ECODE_ALE :
               is_data_tlbr ? `EXCEPTION_ECODE_TLBR :
               is_data_pil ? `EXCEPTION_ECODE_PIL :
               is_data_pis ? `EXCEPTION_ECODE_PIS :
               is_data_ppi ? `EXCEPTION_ECODE_PPI :
               is_data_pme ? `EXCEPTION_ECODE_PME :
               `EXCEPTION_ECODE_INT;

    assign esubcode = 9'd0;

    assign csr_crmd = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

    assign csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};

    assign csr_ecfg = {19'b0, csr_ecfg_lie_12_11, 1'b0, csr_ecfg_lie_9_0};

    assign csr_estat = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is_12, csr_estat_is_11, 1'b0, csr_estat_is_9_2, csr_estat_is_1_0};

    assign csr_era = csr_era_pc;

    assign csr_badv = csr_badv_vaddr;

    assign csr_eentry = {csr_eentry_va, 6'b0};

    assign csr_save0 = csr_save0_data;

    assign csr_save1 = csr_save1_data;

    assign csr_save2 = csr_save2_data;

    assign csr_save3 = csr_save3_data;

    assign csr_tid = csr_tid_tid;

    assign csr_tcfg = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

    assign csr_tval = timer_cnt;

    assign csr_ticlr_clr = 1'b0;

    assign csr_ticlr = {31'b0, csr_ticlr_clr};


    //*****************************
    assign csr_tlbidx = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};

    assign csr_tlbehi = {csr_tlbehi_vppn, 13'b0};

    assign csr_tlbelo0 = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};

    assign csr_tlbelo1 = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};

    assign csr_asid = {8'b0, csr_asid_asidbits, 6'b0, csr_asid_asid};

    assign csr_pgdl = {csr_pgdl_base, 12'b0};

    assign csr_pgdh = {csr_pgdh_base, 12'b0};

    assign csr_pgd = {csr_pgd_base, 12'b0};

    assign csr_tlbrentry = {csr_tlbrentry_pa, 6'b0};

    assign csr_dmw0 = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};

    assign csr_dmw1 = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};

    //*****************************

    assign out_csr_crmd = csr_crmd;
    assign out_csr_dmw0 = csr_dmw0;
    assign out_csr_dmw1 = csr_dmw1;
    assign out_csr_asid = csr_asid;
    assign out_csr_estat = csr_estat;
    assign out_csr_tlbidx = csr_tlbidx;
    assign out_csr_tlbehi = csr_tlbehi;
    assign out_csr_tlbelo0 = csr_tlbelo0;
    assign out_csr_tlbelo1 = csr_tlbelo1;



    always @(posedge clk) begin
        if (!resetn) csr_crmd_plv <= 2'b0;
        else if (is_exception) csr_crmd_plv <= 2'b0;
        else if (ertn_flush) csr_crmd_plv <= csr_prmd_pplv;
        else if (we && waddr == `CSR_ADDR_CRMD) csr_crmd_plv <= wmask[`CSR_CRMD_PLV] & wdata[`CSR_CRMD_PLV] | ~wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
    end


    always @(posedge clk) begin
        if (!resetn) csr_crmd_ie <= 1'b0;
        else if (is_exception) csr_crmd_ie <= 1'b0;
        else if (ertn_flush) csr_crmd_ie <= csr_prmd_pie;
        else if (we && waddr == `CSR_ADDR_CRMD) csr_crmd_ie <= wmask[`CSR_CRMD_IE] & wdata[`CSR_CRMD_IE] | ~wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end

    // *******************************
    // assign csr_crmd_da = 1'b1;
    // assign csr_crmd_pg = 1'b0;
    // assign csr_crmd_datf = csr_crmd_pg == 1'b1 ? 2'b01 : 2'b00;
    // assign csr_crmd_datm = csr_crmd_pg == 1'b1 ? 2'b01 : 2'b00;
    // *******************************


    always @(posedge clk) begin
        if (!resetn) csr_crmd_da <= 1'b1;
        else if (we && waddr == `CSR_ADDR_CRMD) csr_crmd_da <= wmask[`CSR_CRMD_DA] & wdata[`CSR_CRMD_DA] | ~wmask[`CSR_CRMD_DA] & csr_crmd_da;
        else if (ertn_flush && csr_estat_ecode == `EXCEPTION_ECODE_TLBR) csr_crmd_da <= 1'b0;
        else if (is_exception && is_tlbr) csr_crmd_da <= 1'b1;
    end

    always @(posedge clk) begin
        if (!resetn) csr_crmd_pg <= 1'b0;
        else if (we && waddr == `CSR_ADDR_CRMD) csr_crmd_pg <= wmask[`CSR_CRMD_PG] & wdata[`CSR_CRMD_PG] | ~wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        else if (ertn_flush && csr_estat_ecode == `EXCEPTION_ECODE_TLBR) csr_crmd_pg <= 1'b1;
        else if (is_exception && is_tlbr) csr_crmd_pg <= 1'b0;
    end


    always @(posedge clk) begin
        if (!resetn) csr_crmd_datf <= 2'b00;
        else if (we && waddr == `CSR_ADDR_CRMD) csr_crmd_datf <= wmask[`CSR_CRMD_DATF] & wdata[`CSR_CRMD_DATF] | ~wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
    end

    always @(posedge clk) begin
        if (!resetn) csr_crmd_datm <= 2'b00;
        else if (we && waddr == `CSR_ADDR_CRMD) csr_crmd_datm <= wmask[`CSR_CRMD_DATM] & wdata[`CSR_CRMD_DATM] | ~wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
    end


    always @(posedge clk) begin
        if (is_exception) csr_prmd_pplv <= csr_crmd_plv;
        else if (we && waddr == `CSR_ADDR_PRMD) csr_prmd_pplv <= wmask[`CSR_PRMD_PPLV] & wdata[`CSR_PRMD_PPLV] | ~wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
    end

    always @(posedge clk) begin
        if (is_exception) csr_prmd_pie <= csr_crmd_ie;
        else if (we && waddr == `CSR_ADDR_PRMD) csr_prmd_pie <= wmask[`CSR_PRMD_PIE] & wdata[`CSR_PRMD_PIE] | ~wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end

    always @(posedge clk) begin
        if (!resetn) csr_ecfg_lie_9_0 <= 10'b0;
        else if (we && waddr == `CSR_ADDR_ECFG) csr_ecfg_lie_9_0 <= wmask[`CSR_ECFG_LIE_9_0] & wdata[`CSR_ECFG_LIE_9_0] | ~wmask[`CSR_ECFG_LIE_9_0] & csr_ecfg_lie_9_0;
    end

    always @(posedge clk) begin
        if (!resetn) csr_ecfg_lie_12_11 <= 2'b0;
        else if (we & waddr == `CSR_ADDR_ECFG) csr_ecfg_lie_12_11 <= wmask[`CSR_ECFG_LIE_12_11] & wdata[`CSR_ECFG_LIE_12_11] | ~wmask[`CSR_ECFG_LIE_12_11] & csr_ecfg_lie_12_11;
    end

    always @(posedge clk) begin
        if (!resetn) csr_estat_is_1_0 <= 2'b0;
        else if (we && waddr == `CSR_ADDR_ESTAT) csr_estat_is_1_0 <= wmask[`CSR_ESTAT_IS_1_0] & wdata[`CSR_ESTAT_IS_1_0] | ~wmask[`CSR_ESTAT_IS_1_0] & csr_estat_is_1_0;
    end

    always @(posedge clk) begin
        csr_estat_is_9_2 <= intrpt;
        // csr_estat_is_9_2 <= 8'b0;
    end

    always @(posedge clk) begin
        if (timer_cnt[31:0] == 32'b0) csr_estat_is_11 <= 1'b1;
        else if (we && waddr == `CSR_ADDR_TICLR && wmask[`CSR_TICLR_CLR] && wdata[`CSR_TICLR_CLR]) csr_estat_is_11 <= 1'b0;
    end

    always @(posedge clk) begin
        // csr_estat_is_12 <= ipi_int;
        csr_estat_is_12 <= 1'b0;
    end

    always @(posedge clk) begin
        if (is_exception) csr_estat_ecode <= ecode;
    end

    always @(posedge clk) begin
        if (is_exception) csr_estat_esubcode <= esubcode;
    end

    always @(posedge clk) begin
        if (is_exception) csr_era_pc <= pc;
        else if (we && waddr == `CSR_ADDR_ERA) csr_era_pc <= wmask[`CSR_ERA_PC] & wdata[`CSR_ERA_PC] | ~wmask[`CSR_ERA_PC] & csr_era_pc;
    end

    wire exception_inst_addr_error;
    assign exception_inst_addr_error = is_adef || is_inst_tlbr || is_inst_pif || is_inst_ppi;
    wire exception_data_addr_error;
    assign exception_data_addr_error = !exception_inst_addr_error && !is_int && !is_sys && !is_brk && !is_ine && (is_ale || is_data_tlbr || is_data_pil || is_data_pis || is_data_ppi || is_data_pme);

    wire exception_inst_tlb_error;
    wire exception_data_tlb_error;

    assign exception_inst_tlb_error = !is_adef && (is_inst_tlbr || is_inst_pif || is_inst_ppi);
    assign exception_data_tlb_error = !exception_inst_addr_error && !is_int && !is_sys && !is_brk && !is_ine && !is_ale && (is_data_tlbr || is_data_pil || is_data_pis || is_data_ppi || is_data_pme);


    always @(posedge clk) begin
        if (is_exception && exception_inst_addr_error) csr_badv_vaddr <= pc;
        else if (is_exception && exception_data_addr_error) csr_badv_vaddr <= vaddr;
        else if (we && waddr == `CSR_ADDR_BADV) csr_badv_vaddr <= wmask[`CSR_BADV_VADDR] & wdata[`CSR_BADV_VADDR] | ~wmask[`CSR_BADV_VADDR] & csr_badv_vaddr;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_EENTRY) csr_eentry_va <= wmask[`CSR_EENTRY_VA] & wdata[`CSR_EENTRY_VA] | ~wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_SAVE0) csr_save0_data <= wmask[`CSR_SAVE0_DATA] & wdata[`CSR_SAVE0_DATA] | ~wmask[`CSR_SAVE0_DATA] & csr_save0_data;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_SAVE1) csr_save1_data <= wmask[`CSR_SAVE1_DATA] & wdata[`CSR_SAVE1_DATA] | ~wmask[`CSR_SAVE1_DATA] & csr_save1_data;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_SAVE2) csr_save2_data <= wmask[`CSR_SAVE2_DATA] & wdata[`CSR_SAVE2_DATA] | ~wmask[`CSR_SAVE2_DATA] & csr_save2_data;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_SAVE3) csr_save3_data <= wmask[`CSR_SAVE3_DATA] & wdata[`CSR_SAVE3_DATA] | ~wmask[`CSR_SAVE3_DATA] & csr_save3_data;
    end

    always @(posedge clk) begin
        if (!resetn) csr_tid_tid <= 32'b0;
        else if (we && waddr == `CSR_ADDR_TID) csr_tid_tid <= wmask[`CSR_TID_TID] & wdata[`CSR_TID_TID] | ~wmask[`CSR_TID_TID] & csr_tid_tid;
    end

    always @(posedge clk) begin
        if (!resetn) csr_tcfg_en <= 1'b0;
        else if (we && waddr == `CSR_ADDR_TCFG) csr_tcfg_en <= wmask[`CSR_TCFG_EN] & wdata[`CSR_TCFG_EN] | ~wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TCFG) csr_tcfg_periodic <= wmask[`CSR_TCFG_PERIODIC] & wdata[`CSR_TCFG_PERIODIC] | ~wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TCFG) csr_tcfg_initval <= wmask[`CSR_TCFG_INITVAL] & wdata[`CSR_TCFG_INITVAL] | ~wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
    end

    assign csr_tcfg_next = wmask[31:0] & wdata[31:0] | ~wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

    always @(posedge clk) begin
        if (!resetn) timer_cnt <= 32'hffff_ffff;
        else if (we && waddr == `CSR_ADDR_TCFG && csr_tcfg_next[`CSR_TCFG_EN]) timer_cnt <= {csr_tcfg_next[`CSR_TCFG_INITVAL], 2'b0};
        else if (csr_tcfg_en && timer_cnt != 32'hffff_ffff) begin
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) timer_cnt <= {csr_tcfg_initval, 2'b0};
            else timer_cnt <= timer_cnt - 32'b1;
        end
    end

    assign csr_ticlr_clr = 1'b0;


    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBIDX) csr_tlbidx_index <= wmask[`CSR_TLBIDX_INDEX] & wdata[`CSR_TLBIDX_INDEX] | ~wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
        else if (is_tlbsrch && tlbsrch_hit) csr_tlbidx_index <= tlb_w_csr_tlbidx[`CSR_TLBIDX_INDEX];
    end


    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBIDX) csr_tlbidx_ps <= wmask[`CSR_TLBIDX_PS] & wdata[`CSR_TLBIDX_PS] | ~wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        else if (is_tlbrd) csr_tlbidx_ps <= tlb_w_csr_tlbidx[`CSR_TLBIDX_PS];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBIDX) csr_tlbidx_ne <= wmask[`CSR_TLBIDX_NE] & wdata[`CSR_TLBIDX_NE] | ~wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        else if (is_tlbrd || is_tlbsrch) csr_tlbidx_ne <= tlb_w_csr_tlbidx[`CSR_TLBIDX_NE];
    end


    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBEHI) csr_tlbehi_vppn <= wmask[`CSR_TLBEHI_VPPN] & wdata[`CSR_TLBEHI_VPPN] | ~wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        else if (is_tlbrd) csr_tlbehi_vppn <= tlb_w_csr_tlbehi[`CSR_TLBEHI_VPPN];
        else if (is_exception && exception_data_tlb_error) csr_tlbehi_vppn <= vaddr[`CSR_TLBEHI_VPPN];
        else if (is_exception && exception_inst_tlb_error) csr_tlbehi_vppn <= pc[`CSR_TLBEHI_VPPN];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO0) csr_tlbelo0_v <= wmask[`CSR_TLBELO0_V] & wdata[`CSR_TLBELO0_V] | ~wmask[`CSR_TLBELO0_V] & csr_tlbelo0_v;
        else if (is_tlbrd) csr_tlbelo0_v <= tlb_w_csr_tlbelo0[`CSR_TLBELO0_V];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO0) csr_tlbelo0_d <= wmask[`CSR_TLBELO0_D] & wdata[`CSR_TLBELO0_D] | ~wmask[`CSR_TLBELO0_D] & csr_tlbelo0_d;
        else if (is_tlbrd) csr_tlbelo0_d <= tlb_w_csr_tlbelo0[`CSR_TLBELO0_D];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO0) csr_tlbelo0_plv <= wmask[`CSR_TLBELO0_PLV] & wdata[`CSR_TLBELO0_PLV] | ~wmask[`CSR_TLBELO0_PLV] & csr_tlbelo0_plv;
        else if (is_tlbrd) csr_tlbelo0_plv <= tlb_w_csr_tlbelo0[`CSR_TLBELO0_PLV];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO0) csr_tlbelo0_mat <= wmask[`CSR_TLBELO0_MAT] & wdata[`CSR_TLBELO0_MAT] | ~wmask[`CSR_TLBELO0_MAT] & csr_tlbelo0_mat;
        else if (is_tlbrd) csr_tlbelo0_mat <= tlb_w_csr_tlbelo0[`CSR_TLBELO0_MAT];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO0) csr_tlbelo0_g <= wmask[`CSR_TLBELO0_G] & wdata[`CSR_TLBELO0_G] | ~wmask[`CSR_TLBELO0_G] & csr_tlbelo0_g;
        else if (is_tlbrd) csr_tlbelo0_g <= tlb_w_csr_tlbelo0[`CSR_TLBELO0_G];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO0) csr_tlbelo0_ppn <= wmask[`CSR_TLBELO0_PPN] & wdata[`CSR_TLBELO0_PPN] | ~wmask[`CSR_TLBELO0_PPN] & csr_tlbelo0_ppn;
        else if (is_tlbrd) csr_tlbelo0_ppn <= tlb_w_csr_tlbelo0[`CSR_TLBELO0_PPN];
    end



    // *********************************

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO1) csr_tlbelo1_v <= wmask[`CSR_TLBELO1_V] & wdata[`CSR_TLBELO1_V] | ~wmask[`CSR_TLBELO1_V] & csr_tlbelo1_v;
        else if (is_tlbrd) csr_tlbelo1_v <= tlb_w_csr_tlbelo1[`CSR_TLBELO1_V];
    end


    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO1) csr_tlbelo1_d <= wmask[`CSR_TLBELO1_D] & wdata[`CSR_TLBELO1_D] | ~wmask[`CSR_TLBELO1_D] & csr_tlbelo1_d;
        else if (is_tlbrd) csr_tlbelo1_d <= tlb_w_csr_tlbelo1[`CSR_TLBELO1_D];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO1) csr_tlbelo1_plv <= wmask[`CSR_TLBELO1_PLV] & wdata[`CSR_TLBELO1_PLV] | ~wmask[`CSR_TLBELO1_PLV] & csr_tlbelo1_plv;
        else if (is_tlbrd) csr_tlbelo1_plv <= tlb_w_csr_tlbelo1[`CSR_TLBELO1_PLV];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO1) csr_tlbelo1_mat <= wmask[`CSR_TLBELO1_MAT] & wdata[`CSR_TLBELO1_MAT] | ~wmask[`CSR_TLBELO1_MAT] & csr_tlbelo1_mat;
        else if (is_tlbrd) csr_tlbelo1_mat <= tlb_w_csr_tlbelo1[`CSR_TLBELO1_MAT];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO1) csr_tlbelo1_g <= wmask[`CSR_TLBELO1_G] & wdata[`CSR_TLBELO1_G] | ~wmask[`CSR_TLBELO1_G] & csr_tlbelo1_g;
        else if (is_tlbrd) csr_tlbelo1_g <= tlb_w_csr_tlbelo1[`CSR_TLBELO1_G];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBELO1) csr_tlbelo1_ppn <= wmask[`CSR_TLBELO1_PPN] & wdata[`CSR_TLBELO1_PPN] | ~wmask[`CSR_TLBELO1_PPN] & csr_tlbelo1_ppn;
        else if (is_tlbrd) csr_tlbelo1_ppn <= tlb_w_csr_tlbelo1[`CSR_TLBELO1_PPN];
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_ASID) csr_asid_asid <= wmask[`CSR_ASID_ASID] & wdata[`CSR_ASID_ASID] | ~wmask[`CSR_ASID_ASID] & csr_asid_asid;
        else if (is_tlbrd) csr_asid_asid <= tlb_w_csr_asid[`CSR_ASID_ASID];
    end

    assign csr_asid_asidbits = 8'd10;


    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_PGDL) csr_pgdl_base <= wmask[`CSR_PGDL_BASE] & wdata[`CSR_PGDL_BASE] | ~wmask[`CSR_PGDL_BASE] & csr_pgdl_base;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_PGDH) csr_pgdh_base <= wmask[`CSR_PGDH_BASE] & wdata[`CSR_PGDH_BASE] | ~wmask[`CSR_PGDH_BASE] & csr_pgdh_base;
    end

    assign csr_pgd_base = csr_badv[31] == 1'b0 ? csr_pgdl_base : csr_pgdh_base;

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_TLBRENTRY) csr_tlbrentry_pa <= wmask[`CSR_TLBRENTRY_PA] & wdata[`CSR_TLBRENTRY_PA] | ~wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;

    end

    //******************


    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW0) csr_dmw0_plv0 <= wmask[`CSR_DMW0_PLV0] & wdata[`CSR_DMW0_PLV0] | ~wmask[`CSR_DMW0_PLV0] & csr_dmw0_plv0;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW0) csr_dmw0_plv3 <= wmask[`CSR_DMW0_PLV3] & wdata[`CSR_DMW0_PLV3] | ~wmask[`CSR_DMW0_PLV3] & csr_dmw0_plv3;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW0) csr_dmw0_mat <= wmask[`CSR_DMW0_MAT] & wdata[`CSR_DMW0_MAT] | ~wmask[`CSR_DMW0_MAT] & csr_dmw0_mat;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW0) csr_dmw0_pseg <= wmask[`CSR_DMW0_PSEG] & wdata[`CSR_DMW0_PSEG] | ~wmask[`CSR_DMW0_PSEG] & csr_dmw0_pseg;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW0) csr_dmw0_vseg <= wmask[`CSR_DMW0_VSEG] & wdata[`CSR_DMW0_VSEG] | ~wmask[`CSR_DMW0_VSEG] & csr_dmw0_vseg;
    end

    //**********************

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW1) csr_dmw1_plv0 <= wmask[`CSR_DMW1_PLV0] & wdata[`CSR_DMW1_PLV0] | ~wmask[`CSR_DMW1_PLV0] & csr_dmw1_plv0;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW1) csr_dmw1_plv3 <= wmask[`CSR_DMW1_PLV3] & wdata[`CSR_DMW1_PLV3] | ~wmask[`CSR_DMW1_PLV3] & csr_dmw1_plv3;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW1) csr_dmw1_mat <= wmask[`CSR_DMW1_MAT] & wdata[`CSR_DMW1_MAT] | ~wmask[`CSR_DMW1_MAT] & csr_dmw1_mat;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW1) csr_dmw1_pseg <= wmask[`CSR_DMW1_PSEG] & wdata[`CSR_DMW1_PSEG] | ~wmask[`CSR_DMW1_PSEG] & csr_dmw1_pseg;
    end

    always @(posedge clk) begin
        if (we && waddr == `CSR_ADDR_DMW1) csr_dmw1_vseg <= wmask[`CSR_DMW1_VSEG] & wdata[`CSR_DMW1_VSEG] | ~wmask[`CSR_DMW1_VSEG] & csr_dmw1_vseg;
    end


    always @(*) begin
        case (raddr)
            `CSR_ADDR_CRMD: rdata = csr_crmd;
            `CSR_ADDR_PRMD: rdata = csr_prmd;
            `CSR_ADDR_ECFG: rdata = csr_ecfg;
            `CSR_ADDR_ESTAT: rdata = csr_estat;
            `CSR_ADDR_ERA: rdata = csr_era;
            `CSR_ADDR_BADV: rdata = csr_badv;
            `CSR_ADDR_EENTRY: rdata = csr_eentry;
            `CSR_ADDR_SAVE0: rdata = csr_save0;
            `CSR_ADDR_SAVE1: rdata = csr_save1;
            `CSR_ADDR_SAVE2: rdata = csr_save2;
            `CSR_ADDR_SAVE3: rdata = csr_save3;
            `CSR_ADDR_TID: rdata = csr_tid;
            `CSR_ADDR_TCFG: rdata = csr_tcfg;
            `CSR_ADDR_TVAL: rdata = csr_tval;
            `CSR_ADDR_TICLR: rdata = csr_ticlr;
            `CSR_ADDR_TLBIDX: rdata = csr_tlbidx;
            `CSR_ADDR_TLBEHI: rdata = csr_tlbehi;
            `CSR_ADDR_TLBELO0: rdata = csr_tlbelo0;
            `CSR_ADDR_TLBELO1: rdata = csr_tlbelo1;
            `CSR_ADDR_ASID: rdata = csr_asid;
            `CSR_ADDR_PGDL: rdata = csr_pgdl;
            `CSR_ADDR_PGDH: rdata = csr_pgdh;
            `CSR_ADDR_PGD: rdata = csr_pgd;
            `CSR_ADDR_TLBRENTRY: rdata = csr_tlbrentry;
            `CSR_ADDR_DMW0: rdata = csr_dmw0;
            `CSR_ADDR_DMW1: rdata = csr_dmw1;
            `CSR_ADDR_LLBCTL: rdata = csr_llbctl;
            default: rdata = 32'd0;
        endcase
    end

    assign has_int = (csr_estat[12:0] & csr_ecfg[12:0]) != 13'b0 && csr_crmd_ie == 1'b1;




endmodule
