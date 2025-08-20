`include "header.v"
module mmu(
    input                               clk,
    input                               rst_n,
    input                               flush_pif,
    input                               stall_if_to_wb,
    input                               stall_mem_to_wb,
    input                               pmem_valid,
    output                              dtlb_stall,
    output                              itlb_stall,
    input                               ex_pif_to_exe,
    input [`WIDTH_AGU_TO_TLB_BUS-1:0]   agu_to_tlb_bus,
    //地址转换
    input               [31:0]          inst_sram_vaddr, //to pif
    output              [31:0]          inst_sram_paddr,
    input               [31:0]          data_sram_vaddr,
    output              [31:0]          data_sram_paddr,
    //存储访问类型
    output              [1:0]           inst_sram_mat,
    output              [1:0]           data_sram_mat,
   
    //控制信号
    //input                             is_tlbrd,
    input                               is_tlbwr,
    input                               is_tlbfill,
    input                               is_invtlb,
    
    input                               is_tlbsrch_pmem,     //PMEM之前报的例外
    input                               is_store_pmem,       //不考虑valid
    input                               is_load_pmem,        //不考虑valid
    input                               is_ld_st_pmem,       //不考虑valid
    input                               is_cacop2_pmem,      //不考虑valid
    //数据
    input               [4:0]           invtlb_op,
    input               [9:0]           invtlb_asid,
    input               [18:0]          invtlb_vppn, 
    input  [`WIDTH_CSR_TO_TLB_BUS-1:0]  csr_to_tlb_bus,
    output [`WIDTH_TLB_TO_CSR_BUS-1:0]  tlb_to_csr_bus,

    //例外(不考虑valid)
    input                               ex_pre_pmem,
    input               [5:0]           ecode_pre_pmem,
    output                              ex_pmem,        
    output reg          [5:0]           ecode_pmem,
    //output                              esubcode_pmem,
    output                              ex_pif,          //to pif
    output reg          [5:0]           ecode_pif,       //to pif
    output                              ex_dmemvis_pmem  //触发了adem以及TLB例外
`ifdef DIFFTEST_EN
    ,
    output              [`WIDTH_TLB_INDEX - 1:0] tlbfill_index_diff
`endif
);
    //例外
    wire                          exset_adef;
    //wire                          exset_adem;
    wire                          exset_tlbr_i;         //取指TLB重填例外
    wire                          exset_tlbr_d;         //Load/Store TLB重填例外
    wire                          exset_pil;
    wire                          exset_pis;
    wire                          exset_pif;
    wire                          exset_pme;
    wire                          exset_ppi_i;
    wire                          exset_ppi_d;
    //CSR read port
    wire                          csr_crmd_da;
    wire                          csr_crmd_pg;
    wire [1:0]                    csr_crmd_datm;
    wire [1:0]                    csr_crmd_datf;
    wire [1:0]                    csr_crmd_plv;
    wire [`WIDTH_TLB_INDEX -1 :0] csr_tlbidx_index;
    wire [5:0]                    csr_tlbidx_ps;
    wire                          csr_tlbidx_ne;
    wire [18:0]                   csr_tlbehi_vppn;
    wire                          csr_tlbelo0_v;
    wire                          csr_tlbelo0_d;
    wire [1:0]                    csr_tlbelo0_plv;
    wire [1:0]                    csr_tlbelo0_mat;
    wire                          csr_tlbelo0_g;
    wire [19:0]                   csr_tlbelo0_ppn;
    wire                          csr_tlbelo1_v;
    wire                          csr_tlbelo1_d;
    wire [1:0]                    csr_tlbelo1_plv;
    wire [1:0]                    csr_tlbelo1_mat;
    wire                          csr_tlbelo1_g;
    wire [19:0]                   csr_tlbelo1_ppn;
    wire [9:0]                    csr_asid_asid;
    wire [`WIDTH_TLB_INDEX -1 :0] tlb_index_random;
    wire                          csr_dmw0_plv0;
    wire                          csr_dmw0_plv3;
    wire [1:0]                    csr_dmw0_mat;
    wire [2:0]                    csr_dmw0_pseg;
    wire [2:0]                    csr_dmw0_vseg;
    wire                          csr_dmw1_plv0;
    wire                          csr_dmw1_plv3;
    wire [1:0]                    csr_dmw1_mat;
    wire [2:0]                    csr_dmw1_pseg;
    wire [2:0]                    csr_dmw1_vseg;
    wire [5:0]                    csr_estat_ecode;
    /*
    wire                          ex_adef;        
    wire                          ex_adem;
    wire                          ex_pil;
    wire                          ex_pis;
    wire                          ex_pif;
    wire                          ex_pme;
    wire                          ex_pp;
    */
    //TLB
    wire [31:0]      data_sram_vaddr_exe;
    wire             is_ld_st_exe;
    wire             is_cacop2_exe;
    wire             is_store_exe;
    wire             is_tlbsrch_exe;
    assign {data_sram_vaddr_exe, is_ld_st_exe, is_cacop2_exe, is_store_exe, is_tlbsrch_exe} = agu_to_tlb_bus;
    //TLB s0 port
    wire [18:0]      tlbs0_vppn = inst_sram_vaddr[31:13];
    wire             tlbs0_va_bit12 = inst_sram_vaddr[12];
    wire [9:0]       tlbs0_asid = csr_asid_asid;
    wire             tlbs0_found;
    wire [`WIDTH_TLB_INDEX-1:0]       tlbs0_index;
    wire [19:0]      tlbs0_ppn;
    wire [5:0]       tlbs0_ps;
    wire             tlbs0_d;
    wire             tlbs0_v;
    wire [1:0]       tlbs0_mat;
    wire [1:0]       tlbs0_plv;
    wire             tlbs0_ex;    //TLB s0 port 是否产生例外
    //TLB s1 port
    //* TLB s1 port使用两级流水结构实现
    //input are from exe stage
    wire             tlbs1_is_ld_st_cacop2 = is_ld_st_exe || is_cacop2_exe;    //当前指令类型是否要访问TLB
    wire             tlbs1_is_store = is_store_exe;                                 //当前指令类型是否为store
    wire [18:0]      tlbs1_vppn = is_tlbsrch_exe ? csr_tlbehi_vppn : data_sram_vaddr_exe[31:13];
    wire             tlbs1_va_bit12 = data_sram_vaddr_exe[12];
    wire [9:0]       tlbs1_asid = csr_asid_asid;
    wire             tlbs1_found;
    wire [`WIDTH_TLB_INDEX-1:0]       tlbs1_index;
    wire [19:0]      tlbs1_ppn;
    wire [5:0]       tlbs1_ps;
    wire             tlbs1_d;
    wire             tlbs1_v;
    wire [1:0]       tlbs1_mat;
    wire [1:0]       tlbs1_plv;
    wire             tlbs1_ex;    //TLB s1 port 是否产生例外
    //TLB read port
    wire [`WIDTH_TLB_INDEX-1:0]       tlbr_index = csr_tlbidx_index;
    wire             tlbr_e;
    wire [18:0]      tlbr_vppn;
    wire [5:0]       tlbr_ps;
    wire [9:0]       tlbr_asid;
    wire             tlbr_g;
    wire [19:0]      tlbr_ppn0;
    wire [1:0]       tlbr_plv0;
    wire [1:0]       tlbr_mat0;
    wire             tlbr_d0;
    wire             tlbr_v0;
    wire [19:0]      tlbr_ppn1;
    wire [1:0]       tlbr_plv1;
    wire [1:0]       tlbr_mat1;
    wire             tlbr_d1;
    wire             tlbr_v1;
    
    //TLB write port
    wire             tlbwe      = is_tlbwr || is_tlbfill;
    wire [`WIDTH_TLB_INDEX-1:0]       tlbw_index = is_tlbwr ? csr_tlbidx_index : tlb_index_random;
    wire             tlbw_e     = (csr_estat_ecode == `ECODE_TLBR) || !csr_tlbidx_ne;
    wire [18:0]      tlbw_vppn  = csr_tlbehi_vppn;
    wire [5:0]       tlbw_ps    = csr_tlbidx_ps;
    wire [9:0]       tlbw_asid  = csr_asid_asid;
    wire             tlbw_g     = csr_tlbelo0_g & csr_tlbelo1_g;
    wire [19:0]      tlbw_ppn0  = csr_tlbelo0_ppn;
    wire [1:0]       tlbw_plv0  = csr_tlbelo0_plv;
    wire [1:0]       tlbw_mat0  = csr_tlbelo0_mat;
    wire             tlbw_d0    = csr_tlbelo0_d;
    wire             tlbw_v0    = csr_tlbelo0_v;
    wire [19:0]      tlbw_ppn1  = csr_tlbelo1_ppn;
    wire [1:0]       tlbw_plv1  = csr_tlbelo1_plv;
    wire [1:0]       tlbw_mat1  = csr_tlbelo1_mat;
    wire             tlbw_d1    = csr_tlbelo1_d;
    wire             tlbw_v1    = csr_tlbelo1_v;
    
`ifdef DIFFTEST_EN
    assign           tlbfill_index_diff = tlb_index_random;
`endif
    //CSR TO TLB BUS
    assign {
        csr_crmd_plv,csr_crmd_da,csr_crmd_pg,csr_crmd_datf,csr_crmd_datm,       //8
        csr_tlbidx_index,csr_tlbidx_ps,csr_tlbidx_ne,csr_tlbehi_vppn,           //`WIDTH_TLB_INDEX + 26
        csr_tlbelo0_v,csr_tlbelo0_d,csr_tlbelo0_plv,csr_tlbelo0_mat,csr_tlbelo0_g,csr_tlbelo0_ppn,//27
        csr_tlbelo1_v,csr_tlbelo1_d,csr_tlbelo1_plv,csr_tlbelo1_mat,csr_tlbelo1_g,csr_tlbelo1_ppn,//27
        csr_asid_asid,tlb_index_random,                                         //10 + `WIDTH_TLB_INDEX
        csr_dmw0_plv0,csr_dmw0_plv3,csr_dmw0_mat,csr_dmw0_pseg,csr_dmw0_vseg,   //10
        csr_dmw1_plv0,csr_dmw1_plv3,csr_dmw1_mat,csr_dmw1_pseg,csr_dmw1_vseg,   //10
        csr_estat_ecode                                                         //6
    }=csr_to_tlb_bus;
    
    //TLB TO CSR BUS
    assign tlb_to_csr_bus = {
        tlbs1_found,tlbs1_index,
        tlbr_e,tlbr_vppn,tlbr_ps,tlbr_asid,tlbr_g,
        tlbr_ppn0,tlbr_plv0,tlbr_mat0,tlbr_d0,tlbr_v0,
        tlbr_ppn1,tlbr_plv1,tlbr_mat1,tlbr_d1,tlbr_v1
    };
    wire                        search_tlb_i;
    wire                        search_tlb_d;
    wire                        need_visit_itlb;
    wire                        need_visit_dtlb;
    wire                        tlbs1_is_tlbsrch;
    wire                        is_ld_st_cacop2_pmem = is_ld_st_pmem || is_cacop2_pmem;
    //只包含以查询方式访问TLB的情况，不包含tlbrd,tlbwr等
    assign      need_visit_itlb = search_tlb_i;
    assign      need_visit_dtlb = pmem_valid && !ex_pif_to_exe && ((search_tlb_d && (is_ld_st_pmem || is_cacop2_pmem)) || is_tlbsrch_pmem);
    assign      tlbs1_is_tlbsrch = is_tlbsrch_pmem;
    //TLB
    tlb TLB(
        .clk                (clk),
        .rst_n              (rst_n),
        .is_plv3            (csr_crmd_plv[1]),
        .flush_pif          (flush_pif),
        .stall_if_to_wb     (stall_if_to_wb),
        .stall_mem_to_wb    (stall_mem_to_wb),
        //search port 0 取数
        .need_visit_itlb    (need_visit_itlb),
        .s0_vppn            (tlbs0_vppn),
        .s0_va_bit12        (tlbs0_va_bit12),
        .s0_asid            (tlbs0_asid),
        .s0_found           (tlbs0_found),
        .s0_index           (tlbs0_index),
        .s0_ppn             (tlbs0_ppn),
        .s0_ps              (tlbs0_ps),
        .s0_d               (tlbs0_d),
        .s0_v               (tlbs0_v),
        .s0_mat             (tlbs0_mat),
        .s0_plv             (tlbs0_plv),
        .s0_ex              (tlbs0_ex),              //! 时序原因，例外不包含TLBR
        .s0_stall           (itlb_stall),
        //search port 1 load\store\tlbsrch
        .need_visit_dtlb    (need_visit_dtlb),
        .s1_is_tlbsrch      (tlbs1_is_tlbsrch),
        .s1_vppn            (tlbs1_vppn),
        .s1_va_bit12        (tlbs1_va_bit12),
        .s1_asid            (tlbs1_asid),
        .s1_found           (tlbs1_found),          
        .s1_index           (tlbs1_index),
        .s1_ppn             (tlbs1_ppn),
        .s1_ps              (tlbs1_ps),
        .s1_d               (tlbs1_d),
        .s1_v               (tlbs1_v),
        .s1_mat             (tlbs1_mat),
        .s1_plv             (tlbs1_plv),
        .s1_is_ld_st_cacop2 (tlbs1_is_ld_st_cacop2),
        .s1_is_store        (tlbs1_is_store),
        .s1_ex              (tlbs1_ex),              //! 时序原因，例外不包含TLBR
        .s1_stall           (dtlb_stall),
        //invtlb
        .invtlb_valid       (is_invtlb),
        .invtlb_op          (invtlb_op),
        .invtlb_asid        (invtlb_asid),
        .invtlb_vppn        (invtlb_vppn),
        //tlbsrch

        //write port
        .we                 (tlbwe),
        .w_index            (tlbw_index),
        .w_e                (tlbw_e),
        .w_vppn             (tlbw_vppn),
        .w_ps               (tlbw_ps),
        .w_asid             (tlbw_asid),
        .w_g                (tlbw_g),
        .w_ppn0             (tlbw_ppn0),
        .w_plv0             (tlbw_plv0),
        .w_mat0             (tlbw_mat0),
        .w_d0               (tlbw_d0),
        .w_v0               (tlbw_v0),
        .w_ppn1             (tlbw_ppn1),
        .w_plv1             (tlbw_plv1),
        .w_mat1             (tlbw_mat1),
        .w_d1               (tlbw_d1),
        .w_v1               (tlbw_v1),

        //read port
        .r_index            (tlbr_index),
        .r_e                (tlbr_e),
        .r_vppn             (tlbr_vppn),
        .r_ps               (tlbr_ps),
        .r_asid             (tlbr_asid),
        .r_g                (tlbr_g),
        .r_ppn0             (tlbr_ppn0),
        .r_plv0             (tlbr_plv0),
        .r_mat0             (tlbr_mat0),
        .r_d0               (tlbr_d0),
        .r_v0               (tlbr_v0),
        .r_ppn1             (tlbr_ppn1),
        .r_plv1             (tlbr_plv1),
        .r_mat1             (tlbr_mat1),
        .r_d1               (tlbr_d1),
        .r_v1               (tlbr_v1)
    );
    //虚实地址转换
    //DMW hit
    wire        dmw_hit_0_i = inst_sram_vaddr[31:29] == csr_dmw0_vseg && ((!csr_crmd_plv[0] && csr_dmw0_plv0)  ||  (csr_crmd_plv[0] && csr_dmw0_plv3));
    wire        dmw_hit_1_i = inst_sram_vaddr[31:29] == csr_dmw1_vseg && ((!csr_crmd_plv[0] && csr_dmw1_plv0)  ||  (csr_crmd_plv[0] && csr_dmw1_plv3));
    wire [31:0] dmw_paddr_i = {(dmw_hit_0_i ? csr_dmw0_pseg : csr_dmw1_pseg),inst_sram_vaddr[28:0]};
    wire        dmw_hit_i   = dmw_hit_0_i || dmw_hit_1_i;
    wire [1:0]  dmw_mat_i   = dmw_hit_0_i ? csr_dmw0_mat : csr_dmw1_mat;
    wire [31:0] tlbs0_paddr = tlbs0_ps == 6'd12 ? {tlbs0_ppn,inst_sram_vaddr[11:0]} : {tlbs0_ppn[19:9],inst_sram_vaddr[20:0]};

    //* data端DMW访问并入EXE级，并使用流水级寄存器进程保存
    /*exe级*/
    wire        dmw_hit_0_d = data_sram_vaddr_exe[31:29] == csr_dmw0_vseg && ((!csr_crmd_plv[0] && csr_dmw0_plv0)  ||  (csr_crmd_plv[0] && csr_dmw0_plv3));
    wire        dmw_hit_1_d = data_sram_vaddr_exe[31:29] == csr_dmw1_vseg && ((!csr_crmd_plv[0] && csr_dmw1_plv0)  ||  (csr_crmd_plv[0] && csr_dmw1_plv3));
    wire [31:0] dmw_paddr_d = {(dmw_hit_0_d ? csr_dmw0_pseg : csr_dmw1_pseg),data_sram_vaddr_exe[28:0]};
    wire        dmw_hit_d   = dmw_hit_0_d || dmw_hit_1_d;
    wire [1:0]  dmw_mat_d   = dmw_hit_0_d ? csr_dmw0_mat : csr_dmw1_mat;
    /*流水级寄存器*/
    reg [31:0]  dmw_paddr_d_reg;
    reg         dmw_hit_d_reg;
    reg [1:0]   dmw_mat_d_reg;
    always @(posedge clk) begin
        if(!dtlb_stall && !stall_mem_to_wb) begin
            dmw_paddr_d_reg <= dmw_paddr_d;
            dmw_hit_d_reg   <= dmw_hit_d;
            dmw_mat_d_reg   <= dmw_mat_d;
        end
    end
    /*pmem级*/
    wire [31:0] tlbs1_paddr = tlbs1_ps == 6'd12 ? {tlbs1_ppn,data_sram_vaddr[11:0]} : {tlbs1_ppn[19:9],data_sram_vaddr[20:0]};
    //查询tlb：处于映射地址翻译模式下，并且dmw miss
    //! ISA要求DA和PG中必须有一个为0，一个为1，但PMON试图把它们都设置成0，如果不进行兼容，则LINUX无法正常启动
    assign      search_tlb_i = (!csr_crmd_da && csr_crmd_pg) && !dmw_hit_i;    
    assign      search_tlb_d = (!csr_crmd_da && csr_crmd_pg) && !dmw_hit_d_reg && is_ld_st_cacop2_pmem;
    assign inst_sram_mat   = (csr_crmd_da && !csr_crmd_pg) ? csr_crmd_datf : (dmw_hit_i ? dmw_mat_i : tlbs0_mat);
    assign inst_sram_paddr = (csr_crmd_da && !csr_crmd_pg) ? inst_sram_vaddr : (dmw_hit_i ? dmw_paddr_i : tlbs0_paddr);
    assign data_sram_mat   = (csr_crmd_da && !csr_crmd_pg) ? csr_crmd_datm : (dmw_hit_d_reg ? dmw_mat_d_reg : tlbs1_mat);
    assign data_sram_paddr = (csr_crmd_da && !csr_crmd_pg) ? data_sram_vaddr: (dmw_hit_d_reg ? dmw_paddr_d_reg : tlbs1_paddr);
    //取指ecode计算
    //! 最新版ISA对adef和adem的定义有变化。
    assign exset_adef   = inst_sram_vaddr[1:0] != 2'h0;
    assign exset_tlbr_i = search_tlb_i && !tlbs0_found;
    assign exset_pif    = search_tlb_i && !tlbs0_v;
    assign exset_ppi_i  = search_tlb_i && csr_crmd_plv[0] & ~tlbs0_plv[0];
    //访存ecode计算
    assign exset_tlbr_d =                                      search_tlb_d && !tlbs1_found ;
    assign exset_pil    = (is_load_pmem  || is_cacop2_pmem) && search_tlb_d && !tlbs1_v;
    assign exset_pis    = is_store_pmem                     && search_tlb_d && !tlbs1_v;
    assign exset_ppi_d  =                                      search_tlb_d && csr_crmd_plv[0] & ~tlbs1_plv[0] ;
    assign exset_pme    = is_store_pmem                     && search_tlb_d && !tlbs1_d ;
    //PIF级例外
    assign ex_pif =  exset_adef ||  (search_tlb_i && (tlbs0_ex || !tlbs0_found));
    always @(*)begin
        if(exset_adef)
            ecode_pif = `ECODE_ADE;
        else if(exset_tlbr_i)
            ecode_pif = `ECODE_TLBR;
        else if(exset_pif)
            ecode_pif = `ECODE_PIF;
        else ecode_pif = `ECODE_PPI;
    end
    //PMEM级例外
    
    assign ex_pmem =  ex_pre_pmem || (search_tlb_d && (tlbs1_ex || !tlbs1_found));
    //触发访存例外
    assign ex_dmemvis_pmem = !ex_pre_pmem && (exset_tlbr_d || exset_pil || exset_pis || exset_ppi_d || exset_pme);
    always @(*)begin
        if(ex_pre_pmem)
            ecode_pmem = ecode_pre_pmem;
        /*else if(exset_adem)
            ecode_pmem = `ECODE_ADE;*/
        else if(exset_tlbr_d)
            ecode_pmem = `ECODE_TLBR;
        else if(exset_pil || exset_pis)
            ecode_pmem = exset_pil ? `ECODE_PIL : `ECODE_PIS;
        else if(exset_ppi_d)
            ecode_pmem = `ECODE_PPI;
        else ecode_pmem = `ECODE_PME;
    end
    //assign esubcode_pmem = !ex_pre_pmem && exset_adem;
endmodule
