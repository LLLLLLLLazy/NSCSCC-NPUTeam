module csr_unit (
    input                clk,
    input                reset,

    input                icacop_ex_flag,
    input                dcacop_ex_flag,

    input                have_ex,
    input       [ 5:0]   ecode,
    input       [ 8:0]   esubcode,
    input       [31:0]   pc,
    input       [31:0]   mem_vaddr,
    input       [ 1:0]   badv_info,

    input                tlbsrch,
    input                s2_found,
    input       [4:0]    s2_index,

    input wire           ll_w_flag,
    input wire           sc_w_flag,

    input                tlbrd,
    input wire           tlb_r_e,
    input wire [18:0]    tlb_r_vppn,
    input wire [5:0]     tlb_r_ps,
    input wire [9:0]     tlb_r_asid,
    input wire           tlb_r_g,
    input wire [19:0]    tlb_r_ppn0,
    input wire [1:0]     tlb_r_plv0,
    input wire [1:0]     tlb_r_mat0,
    input wire           tlb_r_d0,
    input wire           tlb_r_v0,
    input wire [19:0]    tlb_r_ppn1,
    input wire [1:0]     tlb_r_plv1,
    input wire [1:0]     tlb_r_mat1,
    input wire           tlb_r_d1,
    input wire           tlb_r_v1,

    input                ertn_flush,
    input       [ 7:0]   hw_interupt,
    input                ipi_interupt,

    input       [13:0]   csr_addr,
    input                csr_we,
    input       [31:0]   csr_wmask,
    input       [31:0]   csr_wdata,

    output wire          have_int,
    output wire [31:0]   pc_from_era,
    output wire [31:0]   csr_rdata,
    output wire          disable_cache_out,

    output wire [31:0]   asid,
    output wire [31:0]   tlbehi,
    output wire [31:0]   tlbelo0,
    output wire [31:0]   tlbelo1,
    output wire [31:0]   tlbidx,
    output wire [31:0]   estat,
    output reg           crmd_da,
    output reg           crmd_pg,
    output reg  [ 1:0]   crmd_plv,
    output reg  [ 1:0]   crmd_datf,
    output reg  [ 1:0]   crmd_datm,
    output reg           llbit,
    output wire [31:0]   dmw0,
    output wire [31:0]   dmw1,
    output wire [31:0]   eentry,
    output wire [31:0]   tlbrentry,
    output reg  [63:0]   stable_cnt

    `ifdef DIFFTEST_EN
    ,
    output wire [31:0]   dif_crmd,
    output wire [31:0]   dif_prmd,
    output wire [31:0]   dif_ecfg,
    output wire [31:0]   dif_era,
    output wire [31:0]   dif_badv,
    output wire [31:0]   dif_save0,
    output wire [31:0]   dif_save1,
    output wire [31:0]   dif_save2,
    output wire [31:0]   dif_save3,
    output wire [31:0]   dif_tid,
    output wire [31:0]   dif_tcfg,
    output wire [31:0]   dif_tval,
    output wire [31:0]   dif_ticlr,
    output wire [31:0]   dif_llbctl,
    output wire [31:0]   dif_pgdl,
    output wire [31:0]   dif_pgdh,
    output wire [31:0]   dif_pgd
    `endif 
);

wire        badv_vaddr_need_update;
wire        tlbehi_vppn_need_update;

wire [31:0] crmd;
//reg  [ 1:0] crmd_plv;
reg         crmd_ie;
//reg         crmd_da;
//reg         crmd_pg;
//reg  [ 1:0] crmd_datf;
//reg  [ 1:0] crmd_datm;

wire [31:0] prmd;
reg  [ 1:0] prmd_pplv;
reg         prmd_pie;

wire [31:0] ecfg;
reg  [12:0] ecfg_lie;

//wire [31:0] estat;
reg  [12:0] estat_is;
reg  [ 5:0] estat_ecode;
reg  [ 8:0] estat_esubcode; 

wire [31:0] era;
reg  [31:0] era_pc;

wire [31:0] badv;
reg  [31:0] badv_vaddr;

//wire [31:0] eentry;
reg  [25:0] eentry_va;

//wire [31:0] tlbidx;
reg  [ 4:0] tlbidx_index;
reg  [ 5:0] tlbidx_ps;
reg         tlbidx_ne;

//wire [31:0] tlbehi;
reg  [18:0] tlbehi_vppn;

//wire [31:0] tlbelo0;
reg         tlbelo0_v;
reg         tlbelo0_d;
reg  [ 1:0] tlbelo0_plv;
reg  [ 1:0] tlbelo0_mat;
reg         tlbelo0_g;
reg  [19:0] tlbelo0_ppn;

//wire [31:0] tlbelo1;
reg         tlbelo1_v;
reg         tlbelo1_d;
reg  [ 1:0] tlbelo1_plv;
reg  [ 1:0] tlbelo1_mat;
reg         tlbelo1_g;
reg  [19:0] tlbelo1_ppn;

//wire [31:0] asid;
reg  [ 9:0] asid_asid;
wire [ 7:0] asid_asidbits;

wire [31:0] pgdl;
reg [19:0] pgdl_base;

wire [31:0] pgdh;
reg [19:0] pgdh_base;

wire [31:0] pgd;
reg [19:0] pgd_base;

wire [31:0] cpuid;

wire [31:0] save0;
wire [31:0] save1;
wire [31:0] save2;
wire [31:0] save3;
reg  [31:0] save0_data;
reg  [31:0] save1_data;
reg  [31:0] save2_data;
reg  [31:0] save3_data;

wire [31:0] tid;
reg  [31:0] tid_tid;

wire [31:0] tcfg;
reg         tcfg_en;
reg         tcfg_periodic;
reg  [29:0] tcfg_initval;

wire [31:0] tval;
reg  [31:0] tval_timeval;

wire [31:0] ticlr;
wire        ticlr_clr;

//reg  [63:0] stable_cnt;

//reg         llbit;

wire [31:0] llbctl;
wire        llbctl_rollb;
wire        llbctl_wcllb;
reg         llbctl_klo;

//wire [31:0] tlbrentry;
reg  [25:0] tlbrentry_pa;

reg  [31:0] disable_cache;

//wire [31:0] dmw0;
reg         dmw0_plv0;
reg         dmw0_plv3;
reg  [ 1:0] dmw0_mat;
reg  [ 2:0] dmw0_pseg;
reg  [ 2:0] dmw0_vseg;

//wire [31:0] dmw1;
reg         dmw1_plv0;
reg         dmw1_plv3;
reg  [ 1:0] dmw1_mat;
reg  [ 2:0] dmw1_pseg;
reg  [ 2:0] dmw1_vseg;

parameter CRMD      = 14'h00;
`define   CRMD_PLV    1:0
`define   CRMD_IE     2
`define   CRMD_DA     3
`define   CRMD_PG     4
`define   CRMD_DATF   6:5
`define   CRMD_DATM   8:7

parameter PRMD      = 14'h01;
`define   PRMD_PPLV   1:0
`define   PRMD_PIE    2

parameter ECFG      = 14'h04;
`define   ECFG_LIE9_0    9:0
`define   ECFG_LIE12_11  12:11
 
parameter ESTAT     = 14'h05;
`define   ESTAT_IS1_0    1:0
`define   ESTAT_IS9_2    9:2
`define   ESTAT_IS11     11
`define   ESTAT_IS12     12
`define   ESTAT_ECODE    21:16
`define   ESTAT_ESUBCODE 30:22

parameter ERA       = 14'h06;
`define   ERA_PC      31:0

parameter BADV      = 14'h07;
`define   BADV_VADDR  31:0

parameter EENTRY    = 14'h0c;
`define   EENTRY_VA   31:6

parameter TLBIDX    = 14'h10;
`define   TLBIDX_INDEX 4:0
`define   TLBIDX_PS    29:24
`define   TLBIDX_NE    31

parameter TLBEHI    = 14'h11;
`define   TLBEHI_VPPN  31:13

parameter TLBELO0   = 14'h12;
`define   TLBELO0_V    0
`define   TLBELO0_D    1
`define   TLBELO0_PLV  3:2
`define   TLBELO0_MAT  5:4
`define   TLBELO0_G    6
`define   TLBELO0_PPN  27:8

parameter TLBELO1   = 14'h13;
`define   TLBELO1_V    0
`define   TLBELO1_D    1
`define   TLBELO1_PLV  3:2
`define   TLBELO1_MAT  5:4
`define   TLBELO1_G    6
`define   TLBELO1_PPN  27:8

parameter ASID      = 14'h18;
`define   ASID_ASID     9:0
`define   ASID_ASIDBITS 23:16

parameter PGDL      = 14'h19;
`define   PGDL_BASE    31:12

parameter PGDH      = 14'h1a;
`define   PGDH_BASE    31:12

parameter PGD       = 14'h1b;
`define   PGD_BASE     31:12

parameter CPUID     = 14'h20;

parameter SAVE0     = 14'h30;
parameter SAVE1     = 14'h31;
parameter SAVE2     = 14'h32;
parameter SAVE3     = 14'h33;
`define   SAVE_DATA   31:0

parameter TID       = 14'h40;
`define   TID_TID     31:0

parameter TCFG      = 14'h41;
`define   TCFG_EN       0
`define   TCFG_PERIODIC 1
`define   TCFG_INITVAL  31:2

parameter TVAL      = 14'h42;
`define   TVAL_TIMEVAL  31:0

parameter TICLR     = 14'h44;
`define   TICLR_CLR   0

// 把stable counter当成CSR
parameter RDTIMEL = 14'h45;
parameter RDTIMEH = 14'h46;

parameter LLBCTL  = 14'h60;
`define   LLBCTL_ROLLB 0
`define   LLBCTL_WCLLB 1
`define   LLBCTL_KLO   2

parameter TLBRENTRY = 14'h88;
`define   TLBRENTRY_PA  31:6

parameter DISABLE_CACHE = 14'h101;

parameter DMW0  = 14'h180;
`define   DMW0_PLV0  0
`define   DMW0_PLV3  3
`define   DMW0_MAT   5:4
`define   DMW0_PSEG  27:25
`define   DMW0_VSEG  31:29

parameter DMW1  = 14'h181;
`define   DMW1_PLV0  0
`define   DMW1_PLV3  3
`define   DMW1_MAT   5:4
`define   DMW1_PSEG  27:25
`define   DMW1_VSEG  31:29

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

// interrupt
assign have_int = |((ecfg[12:0] & estat[12:0]) ^ 13'b0) & crmd[2];

// CRMD
always @(posedge clk or posedge reset) begin
    if (reset) begin
        crmd_plv <= 2'b0;
        crmd_ie  <= 1'b0;
    end
    else if (have_ex) begin
        crmd_plv <= 2'b0;
        crmd_ie  <= 1'b0;
    end
    else if (ertn_flush) begin
        crmd_plv <= prmd_pplv;
        crmd_ie  <= prmd_pie;
    end
    else if (csr_we && csr_addr==CRMD) begin
        crmd_plv <= (csr_wmask[`CRMD_PLV]  & csr_wdata[`CRMD_PLV]) |
                    (~csr_wmask[`CRMD_PLV] & crmd_plv);
        crmd_ie  <= (csr_wmask[`CRMD_IE]  & csr_wdata[`CRMD_IE])  |
                    (~csr_wmask[`CRMD_IE] & crmd_ie);
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        crmd_da <= 1'b1;
    end
    else if (have_ex && ecode==ECODE_TLBR) begin
        crmd_da <= 1'b1;
    end
    else if (ertn_flush && estat_ecode==ECODE_TLBR) begin
        crmd_da <= 1'b0;
    end
    else if (csr_we && csr_addr==CRMD) begin
        crmd_da <= (csr_wmask[`CRMD_DA] & csr_wdata[`CRMD_DA]) |
                  (~csr_wmask[`CRMD_DA] & crmd_da);
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        crmd_pg <= 1'b0;
    end
    else if (have_ex && ecode==ECODE_TLBR) begin
        crmd_pg <= 1'b0;
    end
    else if (ertn_flush && estat_ecode==ECODE_TLBR) begin
        crmd_pg <= 1'b1;
    end
    else if (csr_we && csr_addr==CRMD) begin
        crmd_pg <= (csr_wmask[`CRMD_PG] & csr_wdata[`CRMD_PG]) |
                  (~csr_wmask[`CRMD_PG] & crmd_pg);
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        crmd_datf <= 2'b0;
    end
    else if (csr_we && csr_addr==CRMD) begin
        crmd_datf <= (csr_wmask[`CRMD_DATF] & csr_wdata[`CRMD_DATF]) |
                    (~csr_wmask[`CRMD_DATF] & crmd_datf);
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        crmd_datm <= 2'b0;
    end
    else if (csr_we && csr_addr==CRMD) begin
        crmd_datm <= (csr_wmask[`CRMD_DATM] & csr_wdata[`CRMD_DATM]) |
                    (~csr_wmask[`CRMD_DATM] & crmd_datm);
    end
end

// PRMD
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        prmd_pplv <= 2'b0;
        prmd_pie  <= 1'b0;
    end
    else if (have_ex) begin
        prmd_pplv <= crmd_plv;
        prmd_pie  <= crmd_ie;
    end
    else if (csr_we && csr_addr==PRMD) begin
        prmd_pplv <= (csr_wmask[`PRMD_PPLV] & csr_wdata[`PRMD_PPLV]) |
                    (~csr_wmask[`PRMD_PPLV] & prmd_pplv);
        prmd_pie  <= (csr_wmask[`PRMD_PIE] & csr_wdata[`PRMD_PIE])  |
                    (~csr_wmask[`PRMD_PIE] & prmd_pie);
    end
end

// ECFG
always @(posedge clk or posedge reset) begin
    if (reset) begin
        ecfg_lie <= 13'b0;
    end
    else if (csr_we && csr_addr==ECFG) begin
        ecfg_lie[`ECFG_LIE9_0] <= (csr_wmask[`ECFG_LIE9_0] & csr_wdata[`ECFG_LIE9_0]) |
                                 (~csr_wmask[`ECFG_LIE9_0] & ecfg_lie[`ECFG_LIE9_0]);
        ecfg_lie[`ECFG_LIE12_11] <= (csr_wmask[`ECFG_LIE12_11] & csr_wdata[`ECFG_LIE12_11]) |
                                   (~csr_wmask[`ECFG_LIE12_11] & ecfg_lie[`ECFG_LIE12_11]);
    end
end

// ESTAT
always @(posedge clk or posedge reset) begin
    if (reset) begin
        estat_is[`ESTAT_IS1_0] <= 2'b0;
    end
    else if (csr_we && csr_addr==ESTAT) begin
        estat_is[`ESTAT_IS1_0] <= (csr_wmask[`ESTAT_IS1_0] & csr_wdata[`ESTAT_IS1_0]) |
                                (~csr_wmask[`ESTAT_IS1_0] & estat_is[`ESTAT_IS1_0]);
    end 

    estat_is[`ESTAT_IS9_2] <= hw_interupt;

    estat_is[10] <= 1'b0;

    if (reset) begin // unnecessary reset
        estat_is[`ESTAT_IS11] <= 1'b0;
    end
    else if (tval_timeval==32'b0) begin
        estat_is[`ESTAT_IS11] <= 1'b1;
    end
    else if (csr_we && csr_addr==TICLR && csr_wmask[`TICLR_CLR] && csr_wdata[`TICLR_CLR]) begin
        estat_is[`ESTAT_IS11] <= 1'b0;
    end

    estat_is[`ESTAT_IS12] <= 1'b0;
end

always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        estat_ecode    <= 6'b0;
        estat_esubcode <= 9'b0;
    end
    else if (have_ex) begin
        estat_ecode    <= ecode;
        estat_esubcode <= esubcode;
    end
end

// ERA
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        era_pc <= 32'b0;
    end
    else if (have_ex) begin
        era_pc <= pc;
    end
    else if (csr_we && csr_addr==ERA) begin
        era_pc <= (csr_wmask[`ERA_PC] & csr_wdata[`ERA_PC]) |
                 (~csr_wmask[`ERA_PC] & era_pc);
    end
end

// BADV
assign badv_vaddr_need_update = badv_info[1];
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary resset
        badv_vaddr <= 32'b0;
    end
    else if (badv_vaddr_need_update) begin
        if (badv_info[0]) begin
            badv_vaddr <= pc;
        end
        else begin
            badv_vaddr <= mem_vaddr;
        end
    end
    else if (csr_we && csr_addr==BADV) begin
        badv_vaddr <= (csr_wmask[`BADV_VADDR] & csr_wdata[`BADV_VADDR]) |
                     (~csr_wmask[`BADV_VADDR] & badv_vaddr);
    end
end

// EENTRY
always @(posedge clk or posedge reset) begin
    if (reset) begin //unnecessary reset
        eentry_va <= 26'b0;
    end
    else if (csr_we && csr_addr==EENTRY) begin
        eentry_va <= (csr_wmask[`EENTRY_VA] & csr_wdata[`EENTRY_VA]) |
                    (~csr_wmask[`EENTRY_VA] & eentry_va);
    end
end

// TLBIDX
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbidx_ps    <= 6'b0;
    end
    else if (tlbrd && tlb_r_e) begin
        tlbidx_ps    <= tlb_r_ps;
    end
    else if (tlbrd && !tlb_r_e) begin
        tlbidx_ps    <= 6'b0;
    end
    else if (csr_we && csr_addr==TLBIDX) begin
        tlbidx_ps    <= (csr_wmask[`TLBIDX_PS] & csr_wdata[`TLBIDX_PS]) |
                      (~csr_wmask[`TLBIDX_PS] & tlbidx_ps);
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbidx_ne    <= 1'b0;
    end
    else if (tlbsrch) begin
        tlbidx_ne    <= (!s2_found);
    end
    else if (tlbrd) begin
        tlbidx_ne    <= (!tlb_r_e);
    end
    else if (csr_we && csr_addr==TLBIDX) begin
        tlbidx_ne    <= (csr_wmask[`TLBIDX_NE] & csr_wdata[`TLBIDX_NE]) |
                      (~csr_wmask[`TLBIDX_NE] & tlbidx_ne);
    end    
end

always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbidx_index <= 5'b0;
    end
    else if (tlbsrch && s2_found) begin
        tlbidx_index <= s2_index ;
    end
    else if (csr_we && csr_addr==TLBIDX) begin
        tlbidx_index <= (csr_wmask[`TLBIDX_INDEX] & csr_wdata[`TLBIDX_INDEX]) |
                      (~csr_wmask[`TLBIDX_INDEX] & tlbidx_index);
    end    
end

// TLBEHI
/* 当触发TLB 重填例外、load 操作页无效例外、store 操作页无效例外、取指操作页无
效例外、页写允许例外和页特权等级不合规例外时，触发例外的虚地址的[31:13]位被
记录到tlbehi_vppn。*/
assign tlbehi_vppn_need_update = badv_vaddr_need_update && (ecode==ECODE_TLBR || ecode==ECODE_PIL || ecode==ECODE_PIS ||
                                                            ecode==ECODE_PIF  || ecode==ECODE_PME || ecode==ECODE_PPI );
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbehi_vppn <= 19'b0;
    end
    else if (tlbrd && tlb_r_e) begin
        tlbehi_vppn <= tlb_r_vppn;
    end
    else if (tlbrd && !tlb_r_e) begin
        tlbehi_vppn <= 19'b0;
    end
    else if (tlbehi_vppn_need_update) begin
        if (badv_info[0]) begin
            tlbehi_vppn <= pc[31:13];
        end
        else begin
            tlbehi_vppn <= mem_vaddr[31:13];
        end
    end
    else if (csr_we && csr_addr==TLBEHI) begin
        tlbehi_vppn <= (csr_wmask[`TLBEHI_VPPN] & csr_wdata[`TLBEHI_VPPN]) |
                     (~csr_wmask[`TLBEHI_VPPN] & tlbehi_vppn);
    end
end

// TLBELO0
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbelo0_v <= 1'b0;
        tlbelo0_d <= 1'b0;
        tlbelo0_plv <= 2'b0;
        tlbelo0_mat <= 2'b0;
        tlbelo0_g <= 1'b0;
        tlbelo0_ppn <= 20'b0;
    end
    else if (tlbrd) begin
        tlbelo0_v <= (tlb_r_v0 & tlb_r_e);
        tlbelo0_d <= (tlb_r_d0 & tlb_r_e);
        tlbelo0_plv <= (tlb_r_plv0 & {2{tlb_r_e}});
        tlbelo0_mat <= (tlb_r_mat0 & {2{tlb_r_e}});
        tlbelo0_g <= (tlb_r_g & tlb_r_e);
        tlbelo0_ppn <= (tlb_r_ppn0 & {20{tlb_r_e}});
    end
    else if (csr_we && csr_addr==TLBELO0) begin
        tlbelo0_v <= (csr_wmask[`TLBELO0_V] & csr_wdata[`TLBELO0_V]) |
                    (~csr_wmask[`TLBELO0_V] & tlbelo0_v);
        tlbelo0_d <= (csr_wmask[`TLBELO0_D] & csr_wdata[`TLBELO0_D]) |
                    (~csr_wmask[`TLBELO0_D] & tlbelo0_d);
        tlbelo0_plv <= (csr_wmask[`TLBELO0_PLV] & csr_wdata[`TLBELO0_PLV]) |
                      (~csr_wmask[`TLBELO0_PLV] & tlbelo0_plv);
        tlbelo0_mat <= (csr_wmask[`TLBELO0_MAT] & csr_wdata[`TLBELO0_MAT]) |
                      (~csr_wmask[`TLBELO0_MAT] & tlbelo0_mat);
        tlbelo0_g <= (csr_wmask[`TLBELO0_G] & csr_wdata[`TLBELO0_G]) |
                    (~csr_wmask[`TLBELO0_G] & tlbelo0_g);
        tlbelo0_ppn <= (csr_wmask[`TLBELO0_PPN] & csr_wdata[`TLBELO0_PPN]) |
                      (~csr_wmask[`TLBELO0_PPN] & tlbelo0_ppn);
    end
end

// TLBELO1
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbelo1_v <= 1'b0;
        tlbelo1_d <= 1'b0;
        tlbelo1_plv <= 2'b0;
        tlbelo1_mat <= 2'b0;
        tlbelo1_g <= 1'b0;
        tlbelo1_ppn <= 20'b0;
    end
    else if (tlbrd) begin
        tlbelo1_v <= (tlb_r_v1 & tlb_r_e);
        tlbelo1_d <= (tlb_r_d1 & tlb_r_e);
        tlbelo1_plv <= (tlb_r_plv1 & {2{tlb_r_e}});
        tlbelo1_mat <= (tlb_r_mat1 & {2{tlb_r_e}});
        tlbelo1_g <= (tlb_r_g & tlb_r_e);
        tlbelo1_ppn <= (tlb_r_ppn1 & {20{tlb_r_e}});
    end
    else if (csr_we && csr_addr==TLBELO1) begin
        tlbelo1_v <= (csr_wmask[`TLBELO1_V] & csr_wdata[`TLBELO1_V]) |
                    (~csr_wmask[`TLBELO1_V] & tlbelo1_v);
        tlbelo1_d <= (csr_wmask[`TLBELO1_D] & csr_wdata[`TLBELO1_D]) |
                    (~csr_wmask[`TLBELO1_D] & tlbelo1_d);
        tlbelo1_plv <= (csr_wmask[`TLBELO1_PLV] & csr_wdata[`TLBELO1_PLV]) |
                      (~csr_wmask[`TLBELO1_PLV] & tlbelo1_plv);
        tlbelo1_mat <= (csr_wmask[`TLBELO1_MAT] & csr_wdata[`TLBELO1_MAT]) |
                      (~csr_wmask[`TLBELO1_MAT] & tlbelo1_mat);
        tlbelo1_g <= (csr_wmask[`TLBELO1_G] & csr_wdata[`TLBELO1_G]) |
                    (~csr_wmask[`TLBELO1_G] & tlbelo1_g);
        tlbelo1_ppn <= (csr_wmask[`TLBELO1_PPN] & csr_wdata[`TLBELO1_PPN]) |
                      (~csr_wmask[`TLBELO1_PPN] & tlbelo1_ppn);
    end
end

// ASID
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        asid_asid <= 10'b0;
    end
    else if (tlbrd && tlb_r_e) begin
        asid_asid <= tlb_r_asid;
    end
    else if (tlbrd && !tlb_r_e) begin
        asid_asid <= 10'b0;
    end
    else if (csr_we && csr_addr==ASID) begin
        asid_asid <= (csr_wmask[`ASID_ASID] & csr_wdata[`ASID_ASID]) |
                    (~csr_wmask[`ASID_ASID] & asid_asid);
    end
end

assign asid_asidbits = 8'd10;

// PGD
assign pgd = badv[31]? pgdh : pgdl;

// PGDL
always @(posedge clk or posedge reset) begin
    if (reset) begin
        pgdl_base <= 20'b0;
    end
    else if (csr_we && csr_addr==PGDL) begin
        pgdl_base <= (csr_wmask[`PGDL_BASE] & csr_wdata[`PGDL_BASE]) |
                    (~csr_wmask[`PGDL_BASE] & pgdl_base);
    end
end

// PGDH
always @(posedge clk or posedge reset) begin
    if (reset) begin
        pgdh_base <= 20'b0;
    end
    else if (csr_we && csr_addr==PGDH) begin
        pgdh_base <= (csr_wmask[`PGDH_BASE] & csr_wdata[`PGDH_BASE]) |
                    (~csr_wmask[`PGDH_BASE] & pgdh_base);
    end
end

// SAVE
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        save0_data <= 32'b0;
        save1_data <= 32'b0;
        save2_data <= 32'b0;
        save3_data <= 32'b0;
    end
    else if (csr_we && csr_addr==SAVE0) begin
        save0_data <= (csr_wmask[`SAVE_DATA] & csr_wdata[`SAVE_DATA]) |
                     (~csr_wmask[`SAVE_DATA] & save0_data);
    end
    else if (csr_we && csr_addr==SAVE1) begin
        save1_data <= (csr_wmask[`SAVE_DATA] & csr_wdata[`SAVE_DATA]) |
                     (~csr_wmask[`SAVE_DATA] & save1_data);
    end
    else if (csr_we && csr_addr==SAVE2) begin
        save2_data <= (csr_wmask[`SAVE_DATA] & csr_wdata[`SAVE_DATA]) |
                     (~csr_wmask[`SAVE_DATA] & save2_data);
    end
    else if (csr_we && csr_addr==SAVE3) begin
        save3_data <= (csr_wmask[`SAVE_DATA] & csr_wdata[`SAVE_DATA]) |
                     (~csr_wmask[`SAVE_DATA] & save3_data);
    end
end

// TID
always @(posedge clk or posedge reset) begin
    if (reset) begin
        tid_tid <= 32'b0; // ?
    end
    else if (csr_we && csr_addr == TID) begin
        tid_tid <= (csr_wmask[`TID_TID] & csr_wdata[`TID_TID]) |
                  (~csr_wmask[`TID_TID] & tid_tid);
    end
end

// TCFG
always @(posedge clk or posedge reset) begin
    if (reset) begin
        tcfg_en <= 1'b0;
    end
    else if (csr_we && csr_addr == TCFG) begin
        tcfg_en <= (csr_wmask[`TCFG_EN] & csr_wdata[`TCFG_EN]) |
                  (~csr_wmask[`TCFG_EN] & tcfg_en);
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tcfg_periodic <= 1'b0;
        tcfg_initval  <= 30'h0; 
    end
    else if (csr_we && csr_addr == TCFG) begin
        tcfg_periodic <= (csr_wmask[`TCFG_PERIODIC] & csr_wdata[`TCFG_PERIODIC]) |
                        (~csr_wmask[`TCFG_PERIODIC] & tcfg_periodic);
        tcfg_initval <= (csr_wmask[`TCFG_INITVAL] & csr_wdata[`TCFG_INITVAL]) |
                       (~csr_wmask[`TCFG_INITVAL] & tcfg_initval);
    end
end

// TVAL
wire [31:0] new_tcfg = (csr_wmask[31:0] & csr_wdata[31:0]) |
                      (~csr_wmask[31:0] & tcfg);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        tval_timeval <= 32'hffffffff;
    end
    else if (csr_we && csr_addr==TCFG && new_tcfg[`TCFG_EN]) begin
        tval_timeval <= {new_tcfg[`TCFG_INITVAL], 2'b0};
    end
    else if (tcfg_en && |(tval_timeval ^ 32'hffffffff)) begin
        if (tval_timeval==32'b0 && tcfg_periodic) begin
            tval_timeval <= {tcfg_initval, 2'b0};
        end
        else begin
            tval_timeval <= tval_timeval - 1'b1;
        end
    end
    else begin
        tval_timeval <= 32'hffffffff;
    end
end

// TICLR
assign ticlr_clr = 1'b0;

// stable counter
always @(posedge clk or posedge reset) begin
  if (reset) begin
    stable_cnt <= 64'd0;
  end
  else begin
    stable_cnt <= stable_cnt + 1;
  end
end

// LLBCTL
always @(posedge clk or posedge reset) begin
    if (reset) begin
        llbit <= 1'b0;
    end
    else if (ll_w_flag) begin
        llbit <= 1'b1;
    end
    else if (
            sc_w_flag
        || (ertn_flush && (!llbctl_klo))
        || (csr_we && csr_addr==LLBCTL && csr_wmask[`LLBCTL_WCLLB] && csr_wdata[`LLBCTL_WCLLB])
    ) begin
        llbit <= 1'b0;
    end
end

assign llbctl_rollb = llbit;
assign llbctl_wcllb = 1'b0;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        llbctl_klo <= 1'b0;
    end
    else if (ertn_flush) begin
        llbctl_klo <= 1'b0;
    end
    else if (csr_we && csr_addr == LLBCTL) begin
        llbctl_klo <= (csr_wmask[`LLBCTL_KLO] & csr_wdata[`LLBCTL_KLO]) |
                     (~csr_wmask[`LLBCTL_KLO] & llbctl_klo);
    end
end

// TLBRENTRY
always @(posedge clk or posedge reset) begin
    if (reset) begin // unnecessary reset
        tlbrentry_pa <= 26'b0;
    end
    else if (csr_we && csr_addr == TLBRENTRY) begin
        tlbrentry_pa <= (csr_wmask[`TLBRENTRY_PA] & csr_wdata[`TLBRENTRY_PA]) |
                       (~csr_wmask[`TLBRENTRY_PA] & tlbrentry_pa);
    end
end

// DISABLE_CACHE
always @(posedge clk or posedge reset) begin
    if (reset) begin 
        disable_cache <= 32'b0;
    end
    else if (csr_we && csr_addr == DISABLE_CACHE) begin
        disable_cache <= (csr_wmask & csr_wdata) |
                       (~csr_wmask & disable_cache);
    end
end
assign disable_cache_out = disable_cache[0] ;

// DMW0
always @(posedge clk or posedge reset) begin
    if (reset) begin
        dmw0_plv0  <= 1'b0;
        dmw0_plv3  <= 1'b0;
        dmw0_mat   <= 2'b0;
        dmw0_pseg  <= 3'b0;
        dmw0_vseg  <= 3'b0;
    end
    else if (csr_we && csr_addr == DMW0) begin
        dmw0_plv0  <= (csr_wmask[`DMW0_PLV0] & csr_wdata[`DMW0_PLV0]) |
                     (~csr_wmask[`DMW0_PLV0] & dmw0_plv0);
        dmw0_plv3  <= (csr_wmask[`DMW0_PLV3] & csr_wdata[`DMW0_PLV3]) |
                     (~csr_wmask[`DMW0_PLV3] & dmw0_plv3);
        dmw0_mat   <= (csr_wmask[`DMW0_MAT] & csr_wdata[`DMW0_MAT]) |
                     (~csr_wmask[`DMW0_MAT] & dmw0_mat);
        dmw0_pseg  <= (csr_wmask[`DMW0_PSEG] & csr_wdata[`DMW0_PSEG]) |
                     (~csr_wmask[`DMW0_PSEG] & dmw0_pseg);
        dmw0_vseg  <= (csr_wmask[`DMW0_VSEG] & csr_wdata[`DMW0_VSEG]) |
                     (~csr_wmask[`DMW0_VSEG] & dmw0_vseg);
    end
end

// DMW1
always @(posedge clk or posedge reset) begin
    if (reset) begin
        dmw1_plv0  <= 1'b0;
        dmw1_plv3  <= 1'b0;
        dmw1_mat   <= 2'b0;
        dmw1_pseg  <= 3'b0;
        dmw1_vseg  <= 3'b0;
    end
    else if (csr_we && csr_addr == DMW1) begin
        dmw1_plv0  <= (csr_wmask[`DMW1_PLV0] & csr_wdata[`DMW1_PLV0]) |
                     (~csr_wmask[`DMW1_PLV0] & dmw1_plv0);
        dmw1_plv3  <= (csr_wmask[`DMW1_PLV3] & csr_wdata[`DMW1_PLV3]) |
                     (~csr_wmask[`DMW1_PLV3] & dmw1_plv3);
        dmw1_mat   <= (csr_wmask[`DMW1_MAT] & csr_wdata[`DMW1_MAT]) |
                     (~csr_wmask[`DMW1_MAT] & dmw1_mat);
        dmw1_pseg  <= (csr_wmask[`DMW1_PSEG] & csr_wdata[`DMW1_PSEG]) |
                     (~csr_wmask[`DMW1_PSEG] & dmw1_pseg);
        dmw1_vseg  <= (csr_wmask[`DMW1_VSEG] & csr_wdata[`DMW1_VSEG]) |
                     (~csr_wmask[`DMW1_VSEG] & dmw1_vseg);
    end
end

assign crmd   = {23'b0, crmd_datm, crmd_datf, crmd_pg, crmd_da, crmd_ie, crmd_plv};
assign prmd   = {29'b0, prmd_pie, prmd_pplv};
assign ecfg   = {19'b0, ecfg_lie};
assign estat  = { 1'b0, estat_esubcode, estat_ecode, 3'b0, estat_is};
assign era    = era_pc;
assign badv   = badv_vaddr;
assign eentry = {eentry_va, 6'b0};
assign tlbidx = {tlbidx_ne, 1'b0, tlbidx_ps, 19'b0, tlbidx_index};
assign tlbehi = {tlbehi_vppn, 13'b0};
assign tlbelo0= {4'b0, tlbelo0_ppn, 1'b0, tlbelo0_g, tlbelo0_mat, tlbelo0_plv, tlbelo0_d, tlbelo0_v}; 
assign tlbelo1= {4'b0, tlbelo1_ppn, 1'b0, tlbelo1_g, tlbelo1_mat, tlbelo1_plv, tlbelo1_d, tlbelo1_v};
assign asid   = {8'b0, asid_asidbits, 6'b0, asid_asid};
assign pgdl   = {pgdl_base, 12'b0};
assign pgdh   = {pgdh_base, 12'b0};
assign cpuid  = 32'b0;
assign save0  = save0_data;
assign save1  = save1_data;
assign save2  = save2_data;
assign save3  = save3_data;
assign tid    = tid_tid;
assign tcfg   = {tcfg_initval, tcfg_periodic, tcfg_en};
assign tval   = tval_timeval;
assign ticlr  = {31'b0, ticlr_clr};
assign llbctl = {29'b0, llbctl_klo, llbctl_wcllb, llbctl_rollb};
assign tlbrentry = {tlbrentry_pa, 6'b0};
assign dmw0   = {dmw0_vseg, 1'b0, dmw0_pseg, 19'b0, dmw0_mat, dmw0_plv3, 2'b0, dmw0_plv0};
assign dmw1   = {dmw1_vseg, 1'b0, dmw1_pseg, 19'b0, dmw1_mat, dmw1_plv3, 2'b0, dmw1_plv0};
 
assign pc_from_era = era_pc;

// Output multiplexer
assign csr_rdata  = ({32{csr_addr == CRMD     }} & crmd)
                  | ({32{csr_addr == PRMD     }} & prmd)
                  | ({32{csr_addr == ECFG     }} & ecfg)
                  | ({32{csr_addr == ESTAT    }} & estat)
                  | ({32{csr_addr == ERA      }} & era)
                  | ({32{csr_addr == BADV     }} & badv)
                  | ({32{csr_addr == EENTRY   }} & eentry)
                  | ({32{csr_addr == TLBIDX   }} & tlbidx)
                  | ({32{csr_addr == TLBEHI   }} & tlbehi)
                  | ({32{csr_addr == TLBELO0  }} & tlbelo0)
                  | ({32{csr_addr == TLBELO1  }} & tlbelo1)
                  | ({32{csr_addr == ASID     }} & asid)
                  | ({32{csr_addr == PGD      }} & pgd)
                  | ({32{csr_addr == PGDH     }} & pgdh)
                  | ({32{csr_addr == PGDL     }} & pgdl)
                  | ({32{csr_addr == CPUID    }} & cpuid)
                  | ({32{csr_addr == SAVE0    }} & save0)
                  | ({32{csr_addr == SAVE1    }} & save1)
                  | ({32{csr_addr == SAVE2    }} & save2)
                  | ({32{csr_addr == SAVE3    }} & save3)
                  | ({32{csr_addr == TID      }} & tid)
                  | ({32{csr_addr == TCFG     }} & tcfg)
                  | ({32{csr_addr == TVAL     }} & tval)
                  | ({32{csr_addr == TICLR    }} & ticlr)
                  | ({32{csr_addr == RDTIMEL  }} & stable_cnt[31:0]) 
                  | ({32{csr_addr == RDTIMEH  }} & stable_cnt[63:32])
                  | ({32{csr_addr == LLBCTL   }} & llbctl)
                  | ({32{csr_addr == TLBRENTRY}} & tlbrentry)
                  | ({32{csr_addr == DMW0     }} & dmw0)
                  | ({32{csr_addr == DMW1     }} & dmw1);

`ifdef DIFFTEST_EN
assign dif_crmd = crmd;
assign dif_prmd = prmd;
assign dif_ecfg = ecfg;
assign dif_era  = era;
assign dif_badv = badv;
assign dif_save0 = save0;
assign dif_save1 = save1;
assign dif_save2 = save2;
assign dif_save3 = save3;
assign dif_tid = tid;
assign dif_tcfg = tcfg;
assign dif_tval = tval;
assign dif_ticlr = ticlr;
assign dif_llbctl = llbctl;
assign dif_pgd = pgd;
assign dif_pgdl = pgdl;
assign dif_pgdh = pgdh;
`endif

endmodule //csr_unit