`include "header.v"
module control_status_registers(
    input                   clk,
    input                   rst_n,
    input [31:0]            pc,
    input                   ex,                 //有例外 (考虑valid)
    input [5:0]             ecode,              //例外类型 一级编码
    input                   esubcode,           //例外类型 二级编码
    input                   is_ertn,            //是否为eret指令(考虑valid)
    input [13:0]            csr_addr,
    input                   c_csrwr,            //写csr寄存器 (考虑valid)
    input [31:0]            csr_wdata,
    input [31:0]            csr_wmask,          //写掩码
    input [7:0]             hwi,                //硬件中断采样输入
    input                   ipi,                //核间中断
    input [31:0]            badv,               //出错虚地址
    input [2:0]             c_cntsel,           //stable counter读出选择
    output reg [31:0]       csr_rdata,          //csr寄存器读出
    output reg [31:0]       ex_npc,             //产生例外和ertn指令时的目标pc地址
    output                  has_intr,           //有中断到来
    output [31:0]           counter_rdata,      //stable counter读出数据
    //原子访问
    input                   is_ll_w,
    input                   sc_clean_llbit, //zzy
    output                  llbit,
    output [1:0]            plv,                //向id级传的当前特权级信息
    //TLB相关
    input                   is_tlbsrch,         //是否为tlbsrch指令(考虑valid)
    input                   is_tlbrd,           //是否为tlbrd指令(考虑valid)        
    input  [`WIDTH_TLB_TO_CSR_BUS-1:0] tlb_to_csr_bus,
    output [`WIDTH_CSR_TO_TLB_BUS-1:0] csr_to_tlb_bus
`ifdef DIFFTEST_EN
    ,
    output [`WIDTH_CSR_DIFF-1:0] csr_all_diff,
    output [63:0] stable_counter_diff
`endif
);
   
    //前置定义区
    reg [1:0]   csr_prmd_pplv;
    reg         csr_prmd_pie;
    reg [5:0]   csr_estat_ecode;
    wire        csr_ticlr_clr;
    /**/ reg [31:0]  csr_tval_timeval;
    /**/ reg         csr_tcfg_periodic;
    //reg ti;
    //masked write data
    wire [31:0] csr_crmd_wdata_masked;
    wire [31:0] csr_prmd_wdata_masked;
    wire [31:0] csr_ecfg_wdata_masked;
    wire [31:0] csr_estat_wdata_masked;
    wire [31:0] csr_era_wdata_masked;
    wire [31:0] csr_badv_wdata_masked;
    wire [31:0] csr_eentry_wdata_masked;
    wire [31:0] csr_save0_wdata_masked;
    wire [31:0] csr_save1_wdata_masked;
    wire [31:0] csr_save2_wdata_masked;
    wire [31:0] csr_save3_wdata_masked;
    wire [31:0] csr_tlbidx_wdata_masked;
    wire [31:0] csr_tlbehi_wdata_masked;
    wire [31:0] csr_tlbelo0_wdata_masked;
    wire [31:0] csr_tlbelo1_wdata_masked;
    wire [31:0] csr_asid_wdata_masked;
    wire [31:0] csr_pgdl_wdata_masked;
    wire [31:0] csr_pgdh_wdata_masked;
    wire [31:0] csr_pgd_wdata_masked;
    wire [31:0] csr_tid_wdata_masked;
    wire [31:0] csr_tcfg_wdata_masked;
    //tval软件不可写
    wire [31:0] csr_ticlr_wdata_masked;
    wire [31:0] csr_llbctl_wdata_masked;
    wire [31:0] csr_tlbrentry_wdata_masked;
    wire [31:0] csr_dmw0_wdata_masked;
    wire [31:0] csr_dmw1_wdata_masked;

    //TLB相关输入
    wire  [`WIDTH_TLB_INDEX -1 :0] tlbs1_index;
    wire                           tlbs1_found;
    wire  [18:0]                   tlbr_vppn;
    wire  [5:0]                    tlbr_ps;
    wire                           tlbr_e;
    wire  [9:0]                    tlbr_asid;
    wire                           tlbr_g;
    wire  [19:0]                   tlbr_ppn0;
    wire  [1:0]                    tlbr_plv0;
    wire  [1:0]                    tlbr_mat0;
    wire                           tlbr_d0;
    wire                           tlbr_v0;
    wire  [19:0]                   tlbr_ppn1;
    wire  [1:0]                    tlbr_plv1;
    wire  [1:0]                    tlbr_mat1;
    wire                           tlbr_d1;
    wire                           tlbr_v1;
    assign {
        tlbs1_found,tlbs1_index,
        tlbr_e,tlbr_vppn,tlbr_ps,tlbr_asid,tlbr_g,
        tlbr_ppn0,tlbr_plv0,tlbr_mat0,tlbr_d0,tlbr_v0,
        tlbr_ppn1,tlbr_plv1,tlbr_mat1,tlbr_d1,tlbr_v1
    } = tlb_to_csr_bus;
    //0x0 CRMD
    // 31:9    8:7   6:5   4   3   2    1:0
    // 0       DATM  DATF  PG  DA  IE   PLV
    reg [1:0] csr_crmd_plv;
    always @(posedge clk)begin
        if(!rst_n || ex)
            csr_crmd_plv <= 2'h0;
        else if (is_ertn)
            csr_crmd_plv <= csr_prmd_pplv;
        else if(c_csrwr && csr_addr == `CSR_CRMD)
            csr_crmd_plv <= csr_crmd_wdata_masked[1:0];
    end
    reg csr_crmd_ie;
    always @(posedge clk)begin
        if(!rst_n || ex)
            csr_crmd_ie <= 1'h0;
        else if (is_ertn)
            csr_crmd_ie <= csr_prmd_pie;
        else if(c_csrwr && csr_addr == `CSR_CRMD)
            csr_crmd_ie <= csr_crmd_wdata_masked[2];
    end
    reg csr_crmd_da;
    always @(posedge clk)begin
        if(!rst_n)
            csr_crmd_da <= 1'h1;
        else if (ex && ecode == `ECODE_TLBR)
            csr_crmd_da <= 1'h1;
        else if (is_ertn && csr_estat_ecode  == `ECODE_TLBR)
            csr_crmd_da <= 1'h0;
        else if(c_csrwr && csr_addr == `CSR_CRMD)
            csr_crmd_da <= csr_crmd_wdata_masked[3];
    end
    reg csr_crmd_pg;
    always @(posedge clk)begin
        if(!rst_n)
            csr_crmd_pg <= 1'h0;
        else if (ex && ecode == `ECODE_TLBR)
            csr_crmd_pg <= 1'h0;
        else if (is_ertn && csr_estat_ecode  == `ECODE_TLBR)
            csr_crmd_pg <= 1'h1;
        else if(c_csrwr && csr_addr == `CSR_CRMD)
            csr_crmd_pg <= csr_crmd_wdata_masked[4];
    end
    reg [1:0] csr_crmd_datf;
    always @(posedge clk)begin
        if(!rst_n)
            csr_crmd_datf <= 2'h0;
        else if(c_csrwr && csr_addr == `CSR_CRMD)
            csr_crmd_datf <= csr_crmd_wdata_masked[6:5];
    end
    reg [1:0] csr_crmd_datm;
    always @(posedge clk)begin
        if(!rst_n)
            csr_crmd_datm <= 2'h0;
        else if(c_csrwr && csr_addr == `CSR_CRMD)
            csr_crmd_datm <= csr_crmd_wdata_masked[8:7];
    end


    //0x1 PRMD
    // 31:3    2    1:0
    // 0       PIE  PPLV
    
    always @(posedge clk)begin
        if (ex)
            csr_prmd_pplv <= csr_crmd_plv;
        else if(c_csrwr && csr_addr == `CSR_PRMD)
            csr_prmd_pplv <= csr_prmd_wdata_masked[1:0];
    end
    
    always @(posedge clk)begin
        if (ex)
            csr_prmd_pie <= csr_crmd_ie;
        else if(c_csrwr && csr_addr == `CSR_PRMD)
            csr_prmd_pie <= csr_prmd_wdata_masked[2];
    end
    //0x4 ECFG
    // 31:13   12:11     10   9:0
    //   0   LIE[12:11]   0  LIE[9:0]
    reg [12:0] csr_ecfg_lie;
    always @(posedge clk)begin
        if (!rst_n)
            csr_ecfg_lie[12:0] <= 13'h0;
        else if(c_csrwr && csr_addr == `CSR_ECFG)
            csr_ecfg_lie[12:0] <= csr_ecfg_wdata_masked[12:0];
    end
    //0x5 ESTAT
    // 31 30:22     21:16  15:13 12:11     10   9:2     1:0
    // 0  esubcode  ecode    0  IS[12:11]   0  IS[9:2] IS[1:0]
    /**/ reg [12:0] csr_estat_is;
    always @(posedge clk)begin
        if (!rst_n)
            csr_estat_is[1:0] <= 2'h0;
        else if(c_csrwr && csr_addr == `CSR_ESTAT)
            csr_estat_is[1:0] <= csr_estat_wdata_masked[1:0];
    end
    always @(posedge clk)begin
        csr_estat_is[9:2] <= hwi[7:0];
    end
    //定时器中断产生
    reg counting;//是否正在计时
    always @(posedge clk)begin
        if(!rst_n)
            csr_estat_is[11] <= 1'h0;
        else if(csr_ticlr_clr)
            csr_estat_is[11] <= 1'h0;
        else if(counting && csr_tval_timeval == 32'h0)//本周期为0，且仍在计时，触发中断
            csr_estat_is[11] <= 1'h1;
    end
    always @(posedge clk)begin
        csr_estat_is[12] <= ipi;
    end
    
    always @(posedge clk)begin
        if (ex)
            csr_estat_ecode <= ecode;
    end
    reg [8:0] csr_estat_esubcode;
    always @(posedge clk)begin
        if (ex)
            csr_estat_esubcode <= {8'h0,esubcode};
    end

    //0x6 ERA
    // 31:0
    //  PC
    reg [31:0] csr_era_pc;
    always @(posedge clk)begin
        if (ex)
            csr_era_pc <= pc;
        else if(c_csrwr && csr_addr == `CSR_ERA)
            csr_era_pc <= csr_era_wdata_masked;
    end

    //0x7 BADV
    // 31:0
    // vaddr
    wire badv_wcond;
    assign badv_wcond = ecode == `ECODE_TLBR || 
                      ecode == `ECODE_ADE  ||
                      ecode == `ECODE_ALE  ||
                      ecode == `ECODE_PIL  ||
                      ecode == `ECODE_PIS  ||
                      ecode == `ECODE_PIF  ||
                      ecode == `ECODE_PME  ||
                      ecode == `ECODE_PPI  ;
    reg [31:0] csr_badv_vaddr;
    always @(posedge clk)begin
        if(ex & badv_wcond)
            csr_badv_vaddr <= badv;
        else if(c_csrwr && csr_addr == `CSR_BADV)
            csr_badv_vaddr <= csr_badv_wdata_masked;
    end

    //0xc EENTRY
    // 31:6 5:0
    //  va   0
    reg [31:6] csr_eentry_va;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_EENTRY)
            csr_eentry_va <= csr_eentry_wdata_masked[31:6];
    end


    //0x30-0x33 SAVE0-3
    reg [31:0] csr_save0_data;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_SAVE0)
            csr_save0_data <= csr_save0_wdata_masked;
    end

    reg [31:0] csr_save1_data;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_SAVE1)
            csr_save1_data <= csr_save1_wdata_masked;
    end

    reg [31:0] csr_save2_data;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_SAVE2)
            csr_save2_data <= csr_save2_wdata_masked;
    end
 
    reg [31:0] csr_save3_data;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_SAVE3)
            csr_save3_data <= csr_save3_wdata_masked;
    end
    //0x10 TLBIDX
    reg [`WIDTH_TLB_INDEX-1 : 0] csr_tlbidx_index;
    always @(posedge clk)begin
        if(is_tlbsrch && tlbs1_found)
            csr_tlbidx_index <= tlbs1_index;
        else if(c_csrwr && csr_addr == `CSR_TLBIDX)
            csr_tlbidx_index <= csr_tlbidx_wdata_masked[`WIDTH_TLB_INDEX-1 : 0];
    end 
    reg [5:0] csr_tlbidx_ps;
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbidx_ps <= tlbr_e ? tlbr_ps : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBIDX)
            csr_tlbidx_ps <= csr_tlbidx_wdata_masked[29:24];
    end 
    reg      csr_tlbidx_ne;
    always @(posedge clk)begin
        if(is_tlbsrch)
            csr_tlbidx_ne <= ~tlbs1_found;
        else if(is_tlbrd)
            csr_tlbidx_ne <= ~tlbr_e;
        else if(c_csrwr && csr_addr == `CSR_TLBIDX)
            csr_tlbidx_ne <= csr_tlbidx_wdata_masked[31];
    end 
    //0x11 TLBEHI
    reg [18:0] csr_tlbehi_vppn;
    wire tlbehi_wcond;
    assign tlbehi_wcond = ecode == `ECODE_TLBR || 
                          ecode == `ECODE_PIL  ||
                          ecode == `ECODE_PIS  ||
                          ecode == `ECODE_PIF  ||
                          ecode == `ECODE_PME  ||
                          ecode == `ECODE_PPI  ;
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbehi_vppn <= tlbr_e ? tlbr_vppn : 0;
        else if(ex & tlbehi_wcond)
            csr_tlbehi_vppn <= badv[31:13];
        else if(c_csrwr && csr_addr == `CSR_TLBEHI)
            csr_tlbehi_vppn <= csr_tlbehi_wdata_masked[31:13];
    end
    //0x12 TLBELO0
    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg [1:0]   csr_tlbelo0_plv;
    reg [1:0]   csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg [19:0]  csr_tlbelo0_ppn;
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo0_v <= tlbr_e ? tlbr_v0 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO0)
            csr_tlbelo0_v <= csr_tlbelo0_wdata_masked[0];
    end 
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo0_d <= tlbr_e ? tlbr_d0 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO0)
            csr_tlbelo0_d <= csr_tlbelo0_wdata_masked[1];
    end
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo0_plv <= tlbr_e ? tlbr_plv0 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO0)
            csr_tlbelo0_plv <= csr_tlbelo0_wdata_masked[3:2];
    end 
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo0_mat <= tlbr_e ? tlbr_mat0 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO0)
            csr_tlbelo0_mat <= csr_tlbelo0_wdata_masked[5:4];
    end 

    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo0_g <= tlbr_e ? tlbr_g : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO0)
            csr_tlbelo0_g <= csr_tlbelo0_wdata_masked[6];
    end

    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo0_ppn <= tlbr_e ? tlbr_ppn0 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO0)
            csr_tlbelo0_ppn <= csr_tlbelo0_wdata_masked[27:8];
    end 
    //0x13 TLBELO1
    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg [1:0]   csr_tlbelo1_plv;
    reg [1:0]   csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg [19:0]  csr_tlbelo1_ppn;
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo1_v <= tlbr_e ? tlbr_v1 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO1)
            csr_tlbelo1_v <= csr_tlbelo1_wdata_masked[0];
    end 
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo1_d <= tlbr_e ? tlbr_d1 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO1)
            csr_tlbelo1_d <= csr_tlbelo1_wdata_masked[1];
    end
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo1_plv <= tlbr_e ? tlbr_plv1 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO1)
            csr_tlbelo1_plv <= csr_tlbelo1_wdata_masked[3:2];
    end 
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo1_mat <= tlbr_e ? tlbr_mat1 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO1)
            csr_tlbelo1_mat <= csr_tlbelo1_wdata_masked[5:4];
    end 

    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo1_g <= tlbr_e ? tlbr_g : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO1)
            csr_tlbelo1_g <= csr_tlbelo1_wdata_masked[6];
    end

    always @(posedge clk)begin
        if(is_tlbrd)
            csr_tlbelo1_ppn <= tlbr_e ? tlbr_ppn1 : 0;
        else if(c_csrwr && csr_addr == `CSR_TLBELO1)
            csr_tlbelo1_ppn <= csr_tlbelo1_wdata_masked[27:8];
    end 
    //0x18 ASID
    reg [9:0]   csr_asid_asid;
    always @(posedge clk)begin
        if(is_tlbrd)
            csr_asid_asid <= tlbr_e ? tlbr_asid : 0;
        else if(c_csrwr && csr_addr == `CSR_ASID)
            csr_asid_asid <= csr_asid_wdata_masked[9:0];
    end 
    //0x19 PGDL
    reg [19:0]   csr_pgdl_base;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_PGDL)
            csr_pgdl_base <= csr_pgdl_wdata_masked[31:12];
    end 
    //0x1A PGDH
    reg [19:0]   csr_pgdh_base;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_PGDH)
            csr_pgdh_base <= csr_pgdh_wdata_masked[31:12];
    end
    //0x1B PGD
    wire [19:0] csr_pgd_base;
    assign csr_pgd_base = csr_badv_vaddr[31] ? csr_pgdh_base : csr_pgdl_base;

    //0x40 TID
    reg [31:0] csr_tid_tid;
    always @(posedge clk)begin
        if(!rst_n)
            csr_tid_tid <= 32'h0;
        else if(c_csrwr && csr_addr == `CSR_TID)
            csr_tid_tid <= csr_tid_wdata_masked;
    end
    //0x41 TCFG
    /**/reg csr_tcfg_en;
    /**/reg [31:2] csr_tcfg_initval;
    always @(posedge clk)begin
        if(!rst_n)
            csr_tcfg_en <= 0;
        else if(c_csrwr && csr_addr == `CSR_TCFG)
            csr_tcfg_en <= csr_tcfg_wdata_masked[0];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_tcfg_periodic <= 0;
        else if(c_csrwr && csr_addr == `CSR_TCFG)
            csr_tcfg_periodic <= csr_tcfg_wdata_masked[1];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_tcfg_initval <= 30'h0;
        else if(c_csrwr && csr_addr == `CSR_TCFG)
            csr_tcfg_initval <= csr_tcfg_wdata_masked[31:2];
    end

    //0x42 TVAL
    wire [31:0] next_timeval_en;
    always @(posedge clk)begin
        if(!rst_n)
            csr_tval_timeval <= 32'h0;
        else if(c_csrwr && csr_addr == `CSR_TCFG)
            csr_tval_timeval <= {csr_tcfg_wdata_masked[31:2],2'h0};
        else if(counting)
            csr_tval_timeval <= csr_tval_timeval != 32'h0 ? csr_tval_timeval - 1 : ({csr_tcfg_initval[31:2],2'h0});
    end
    always @(posedge clk)begin
        if(!rst_n)
            counting <= 0;
        else if(c_csrwr && csr_addr == `CSR_TCFG)
            counting <= csr_tcfg_wdata_masked[0];
        else if(counting && csr_tval_timeval == 32'h0)
            counting <= csr_tcfg_periodic;
    end
    //0x44 TICLR
    assign csr_ticlr_clr = c_csrwr && csr_addr == `CSR_TICLR && csr_ticlr_wdata_masked[0];
    //0x60 LLBCTL
    reg csr_llbctl_rollb;
    reg csr_llbctl_klo;
    always @(posedge clk)begin
        if(is_ll_w)
            csr_llbctl_rollb <= 1'b1;
        else if(c_csrwr && csr_addr == `CSR_LLBCTL && csr_llbctl_wdata_masked[1] || is_ertn && !csr_llbctl_klo || sc_clean_llbit) //zzy
            csr_llbctl_rollb <= 1'b0;
    end
    always @(posedge clk)begin
        if(!rst_n || is_ertn)
            csr_llbctl_klo <= 0;
        else if(c_csrwr && csr_addr == `CSR_LLBCTL)
            csr_llbctl_klo <= csr_llbctl_wdata_masked[2];
    end
    //0x88 TLBRENTRY
    reg [25:0] csr_tlbrentry_pa;
    always @(posedge clk)begin
        if(c_csrwr && csr_addr == `CSR_TLBRENTRY)
            csr_tlbrentry_pa <= csr_tlbrentry_wdata_masked[31:6];
    end
    //0x180 DMW0
    reg          csr_dmw0_plv0;
    reg          csr_dmw0_plv3;
    reg  [1:0]   csr_dmw0_mat;
    reg  [2:0]   csr_dmw0_pseg;
    reg  [2:0]   csr_dmw0_vseg;
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw0_plv0 <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW0)
            csr_dmw0_plv0 <= csr_dmw0_wdata_masked[0];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw0_plv3 <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW0)
            csr_dmw0_plv3 <= csr_dmw0_wdata_masked[3];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw0_mat <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW0)
            csr_dmw0_mat <= csr_dmw0_wdata_masked[5:4];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw0_pseg <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW0)
            csr_dmw0_pseg <= csr_dmw0_wdata_masked[27:25];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw0_vseg <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW0)
            csr_dmw0_vseg <= csr_dmw0_wdata_masked[31:29];
    end
    //0x181 DMW1
    reg          csr_dmw1_plv0;
    reg          csr_dmw1_plv3;
    reg  [1:0]   csr_dmw1_mat;
    reg  [2:0]   csr_dmw1_pseg;
    reg  [2:0]   csr_dmw1_vseg;
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw1_plv0 <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW1)
            csr_dmw1_plv0 <= csr_dmw1_wdata_masked[0];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw1_plv3 <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW1)
            csr_dmw1_plv3 <= csr_dmw1_wdata_masked[3];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw1_mat <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW1)
            csr_dmw1_mat <= csr_dmw1_wdata_masked[5:4];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw1_pseg <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW1)
            csr_dmw1_pseg <= csr_dmw1_wdata_masked[27:25];
    end
    always @(posedge clk)begin
        if(!rst_n)
            csr_dmw1_vseg <= 0;
        else if(c_csrwr && csr_addr == `CSR_DMW1)
            csr_dmw1_vseg <= csr_dmw1_wdata_masked[31:29];
    end
    //rdata gen
    wire [31:0] csr_crmd_entire   = {23'h0,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
    wire [31:0] csr_prmd_entire   = {29'h0,csr_prmd_pie,csr_prmd_pplv};
    wire [31:0] csr_ecfg_entire   = {19'h0,csr_ecfg_lie[12:11],1'h0,csr_ecfg_lie[9:0]};
    //wire [31:0] csr_ecfg_entire   = {19'h0,csr_ecfg_lie[12:0]};
    wire [31:0] csr_estat_entire  = {1'h0,csr_estat_esubcode,csr_estat_ecode,3'h0,csr_estat_is[12:11],1'h0,csr_estat_is[9:0]};
    wire [31:0] csr_era_entire    = csr_era_pc;
    wire [31:0] csr_badv_entire   = csr_badv_vaddr;
    wire [31:0] csr_eentry_entire = {csr_eentry_va,6'h0};
    wire [31:0] csr_save0_entire  = csr_save0_data;
    wire [31:0] csr_save1_entire  = csr_save1_data;
    wire [31:0] csr_save2_entire  = csr_save2_data;
    wire [31:0] csr_save3_entire  = csr_save3_data;
    wire [31:0] csr_tlbidx_entire = {csr_tlbidx_ne,1'h0,csr_tlbidx_ps,8'h0,{(16-`WIDTH_TLB_INDEX){1'h0}},csr_tlbidx_index};
    wire [31:0] csr_tlbehi_entire = {csr_tlbehi_vppn,13'h0};
    wire [31:0] csr_tlbelo0_entire = {4'h0,csr_tlbelo0_ppn,1'h0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};
    wire [31:0] csr_tlbelo1_entire = {4'h0,csr_tlbelo1_ppn,1'h0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};
    wire [31:0] csr_asid_entire   = {8'h0,8'h0A,6'h0,csr_asid_asid};
    wire [31:0] csr_pgdl_entire   = {csr_pgdl_base,12'h0};
    wire [31:0] csr_pgdh_entire   = {csr_pgdh_base,12'h0};
    wire [31:0] csr_pgd_entire    = {csr_pgd_base,12'h0};
    wire [31:0] csr_tid_entire    = csr_tid_tid;
    wire [31:0] csr_tcfg_entire   = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    wire [31:0] csr_tval_entire   = csr_tval_timeval;
    wire [31:0] csr_ticlr_entire  = 32'h0;
    wire [31:0] csr_llbctl_entire = {29'h0, csr_llbctl_klo, 1'h0, csr_llbctl_rollb};
    wire [31:0] csr_tlbrentry_entire  = {csr_tlbrentry_pa,6'h0};
    wire [31:0] csr_dmw0_entire  = {csr_dmw0_vseg,1'h0,csr_dmw0_pseg,19'h0,csr_dmw0_mat,csr_dmw0_plv3,2'h0,csr_dmw0_plv0};
    wire [31:0] csr_dmw1_entire  = {csr_dmw1_vseg,1'h0,csr_dmw1_pseg,19'h0,csr_dmw1_mat,csr_dmw1_plv3,2'h0,csr_dmw1_plv0};
    wire [31:0] llbit_extend     = {31'h0, csr_llbctl_rollb};//虚拟的CSR寄存器，只用作sc.w指令读出LLBIT
    //mask选择器
    mux2_bitwise#(32) MUX_CRMD      (.d0(csr_crmd_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_crmd_wdata_masked));
    mux2_bitwise#(32) MUX_PRMD      (.d0(csr_prmd_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_prmd_wdata_masked));
    mux2_bitwise#(32) MUX_ECFG      (.d0(csr_ecfg_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_ecfg_wdata_masked));
    mux2_bitwise#(32) MUX_ESTAT     (.d0(csr_estat_entire),     .d1(csr_wdata),.sel(csr_wmask),.out(csr_estat_wdata_masked));
    mux2_bitwise#(32) MUX_ERA       (.d0(csr_era_entire),       .d1(csr_wdata),.sel(csr_wmask),.out(csr_era_wdata_masked));
    mux2_bitwise#(32) MUX_BADV      (.d0(csr_badv_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_badv_wdata_masked));
    mux2_bitwise#(32) MUX_EENTRY    (.d0(csr_eentry_entire),    .d1(csr_wdata),.sel(csr_wmask),.out(csr_eentry_wdata_masked));
    mux2_bitwise#(32) MUX_SAVE0     (.d0(csr_save0_entire),     .d1(csr_wdata),.sel(csr_wmask),.out(csr_save0_wdata_masked));
    mux2_bitwise#(32) MUX_SAVE1     (.d0(csr_save1_entire),     .d1(csr_wdata),.sel(csr_wmask),.out(csr_save1_wdata_masked));
    mux2_bitwise#(32) MUX_SAVE2     (.d0(csr_save2_entire),     .d1(csr_wdata),.sel(csr_wmask),.out(csr_save2_wdata_masked));
    mux2_bitwise#(32) MUX_SAVE3     (.d0(csr_save3_entire),     .d1(csr_wdata),.sel(csr_wmask),.out(csr_save3_wdata_masked));
    mux2_bitwise#(32) MUX_TLBIDX    (.d0(csr_tlbidx_entire),    .d1(csr_wdata),.sel(csr_wmask),.out(csr_tlbidx_wdata_masked));
    mux2_bitwise#(32) MUX_TLBEHI    (.d0(csr_tlbehi_entire),    .d1(csr_wdata),.sel(csr_wmask),.out(csr_tlbehi_wdata_masked));
    mux2_bitwise#(32) MUX_TLBELO0   (.d0(csr_tlbelo0_entire),   .d1(csr_wdata),.sel(csr_wmask),.out(csr_tlbelo0_wdata_masked));
    mux2_bitwise#(32) MUX_TLBELO1   (.d0(csr_tlbelo1_entire),   .d1(csr_wdata),.sel(csr_wmask),.out(csr_tlbelo1_wdata_masked));
    mux2_bitwise#(32) MUX_ASID      (.d0(csr_asid_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_asid_wdata_masked));
    mux2_bitwise#(32) MUX_PGDL      (.d0(csr_pgdl_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_pgdl_wdata_masked));
    mux2_bitwise#(32) MUX_PGDH      (.d0(csr_pgdh_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_pgdh_wdata_masked));
    mux2_bitwise#(32) MUX_PGD       (.d0(csr_pgd_entire),       .d1(csr_wdata),.sel(csr_wmask),.out(csr_pgd_wdata_masked));
    mux2_bitwise#(32) MUX_TID       (.d0(csr_tid_entire),       .d1(csr_wdata),.sel(csr_wmask),.out(csr_tid_wdata_masked));
    mux2_bitwise#(32) MUX_TCFG      (.d0(csr_tcfg_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_tcfg_wdata_masked));
    mux2_bitwise#(32) MUX_TICLR     (.d0(csr_ticlr_entire),     .d1(csr_wdata),.sel(csr_wmask),.out(csr_ticlr_wdata_masked));
    mux2_bitwise#(32) MUX_LLBCTL    (.d0(csr_llbctl_entire),    .d1(csr_wdata),.sel(csr_wmask),.out(csr_llbctl_wdata_masked));
    mux2_bitwise#(32) MUX_TLBRENTRY (.d0(csr_tlbrentry_entire), .d1(csr_wdata),.sel(csr_wmask),.out(csr_tlbrentry_wdata_masked));
    mux2_bitwise#(32) MUX_DMW0      (.d0(csr_dmw0_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_dmw0_wdata_masked));
    mux2_bitwise#(32) MUX_DMW1      (.d0(csr_dmw1_entire),      .d1(csr_wdata),.sel(csr_wmask),.out(csr_dmw1_wdata_masked));
    //读出数据选择
    always @(*)begin
        case(csr_addr)
        `CSR_CRMD:csr_rdata     = csr_crmd_entire;
        `CSR_PRMD:csr_rdata     = csr_prmd_entire;
        `CSR_ECFG:csr_rdata     = csr_ecfg_entire;
        `CSR_ESTAT:csr_rdata    = csr_estat_entire;
        `CSR_ERA:csr_rdata      = csr_era_entire;
        `CSR_BADV:csr_rdata     = csr_badv_entire;
        `CSR_EENTRY:csr_rdata   = csr_eentry_entire;
        `CSR_SAVE0:csr_rdata    = csr_save0_entire;
        `CSR_SAVE1:csr_rdata    = csr_save1_entire;
        `CSR_SAVE2:csr_rdata    = csr_save2_entire;
        `CSR_SAVE3:csr_rdata    = csr_save3_entire;
        `CSR_TLBIDX:csr_rdata   = csr_tlbidx_entire;
        `CSR_TLBEHI:csr_rdata   = csr_tlbehi_entire;
        `CSR_TLBELO0:csr_rdata  = csr_tlbelo0_entire;
        `CSR_TLBELO1:csr_rdata  = csr_tlbelo1_entire;
        `CSR_ASID:csr_rdata     = csr_asid_entire;
        `CSR_PGDL:csr_rdata     = csr_pgdl_entire;
        `CSR_PGDH:csr_rdata     = csr_pgdh_entire;
        `CSR_PGD:csr_rdata      = csr_pgd_entire;
        `CSR_TID:  csr_rdata    = csr_tid_entire;
        `CSR_TCFG: csr_rdata    = csr_tcfg_entire;
        `CSR_TVAL: csr_rdata    = csr_tval_entire;
        `CSR_TICLR:csr_rdata    = csr_ticlr_entire;
        `CSR_LLBCTL:csr_rdata   = csr_llbctl_entire;
        `CSR_TLBRENTRY:csr_rdata= csr_tlbrentry_entire;
        `CSR_DMW0:csr_rdata     = csr_dmw0_entire;
        `CSR_DMW1:csr_rdata     = csr_dmw1_entire;
        `READ_LLBIT: csr_rdata  = llbit_extend;
        default:csr_rdata       = 32'h0;
        endcase
    end
    assign plv = csr_crmd_plv;
    //原子访问
    assign llbit = csr_llbctl_rollb;
    //计数器
    reg [63:0] stable_counter;
    always @(posedge clk)begin
        if(!rst_n)
            stable_counter <= 64'h0;
        else stable_counter <= stable_counter + 64'h1;
    end
    assign counter_rdata = ({32{c_cntsel[2]}} & csr_tid_tid)
                          |({32{c_cntsel[1]}} & stable_counter[63:32])
                          |({32{c_cntsel[0]}} & stable_counter[31:0]);
    
    //中断标记信号
    assign has_intr =  csr_crmd_ie & |{{csr_estat_is[12:11],csr_estat_is[9:0]} & {csr_ecfg_lie[12:11],csr_ecfg_lie[9:0]}};
    //跳转地址
    always @(*)begin    
        if(ex)begin
            if(ecode == `ECODE_TLBR)
                 ex_npc = csr_tlbrentry_entire;
            else ex_npc = csr_eentry_entire;
        end
        else ex_npc = csr_era_entire;
    end

    //TLB相关输出
    assign csr_to_tlb_bus ={
        csr_crmd_plv,csr_crmd_da,csr_crmd_pg,csr_crmd_datf,csr_crmd_datm,
        csr_tlbidx_index,csr_tlbidx_ps,csr_tlbidx_ne,csr_tlbehi_vppn,
        csr_tlbelo0_v,csr_tlbelo0_d,csr_tlbelo0_plv,csr_tlbelo0_mat,csr_tlbelo0_g,csr_tlbelo0_ppn,
        csr_tlbelo1_v,csr_tlbelo1_d,csr_tlbelo1_plv,csr_tlbelo1_mat,csr_tlbelo1_g,csr_tlbelo1_ppn,
        csr_asid_asid,stable_counter[`WIDTH_TLB_INDEX - 1:0],//TODO: 用random可能存在性能问题
        csr_dmw0_plv0,csr_dmw0_plv3,csr_dmw0_mat,csr_dmw0_pseg,csr_dmw0_vseg,
        csr_dmw1_plv0,csr_dmw1_plv3,csr_dmw1_mat,csr_dmw1_pseg,csr_dmw1_vseg,
        csr_estat_ecode
    };
`ifdef DIFFTEST_EN
    assign stable_counter_diff = stable_counter;
    assign csr_all_diff = {
        csr_crmd_entire,
        csr_prmd_entire,
        csr_ecfg_entire,
        csr_estat_entire,
        csr_era_entire,
        csr_badv_entire,
        csr_eentry_entire,
        csr_tlbidx_entire,
        csr_tlbehi_entire,
        csr_tlbelo0_entire,
        csr_tlbelo1_entire,
        csr_asid_entire,
        csr_pgdl_entire,
        csr_pgdh_entire,
        csr_save0_entire,
        csr_save1_entire,
        csr_save2_entire,
        csr_save3_entire,
        csr_tid_entire,
        csr_tcfg_entire,
        csr_tval_entire,
        csr_ticlr_entire,
        csr_llbctl_entire,
        csr_tlbrentry_entire,
        csr_dmw0_entire,
        csr_dmw1_entire
    };
`endif
endmodule
