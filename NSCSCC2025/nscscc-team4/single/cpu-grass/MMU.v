`include "csr.h"
module mmu
#(
    parameter TLBNUM = 16
)
(
    input          clk,
    input          reset,

    input          s0_found,
    input  [$clog2(TLBNUM)-1:0]  s0_index,
    input  [ 5:0]  s0_ps,
    input  [19:0]  s0_ppn,
    input  [ 1:0]  s0_plv,
    input  [ 1:0]  s0_mat,
    input          s0_d,
    input          s0_v,
    input          s1_found,
    input  [$clog2(TLBNUM)-1:0]  s1_index,
    input  [ 5:0]  s1_ps,
    input  [19:0]  s1_ppn,
    input  [ 1:0]  s1_plv,
    input  [ 1:0]  s1_mat,
    input          s1_d,
    input          s1_v,
    input          r_e,
    input  [18:0]  r_vppn,
    input  [ 5:0]  r_ps,
    input  [ 9:0]  r_asid,
    input          r_g,
    input  [19:0]  r_ppn0,
    input  [ 1:0]  r_plv0,
    input  [ 1:0]  r_mat0,
    input          r_d0,
    input          r_v0,
    input  [19:0]  r_ppn1,
    input  [ 1:0]  r_plv1,
    input  [ 1:0]  r_mat1,
    input          r_d1,
    input          r_v1,

    output inst_unhit,
    output data_unhit,

    output [89+$clog2(TLBNUM):0] tlb_data,
    input  [188:0] csr_mmu_values,

    input  [ 31:0] inst_vaddr,
    input  [ 31:0] data_vaddr,
    output [ 31:0] inst_paddr,
    output [ 31:0] data_paddr,

    output [ 31:0] sc_ll_paddr,

    output [  2:0] IF_tlb_excps,
    output [  4:0] EX1_tlb_excps,
    output         mmu_inst_uncache_en,
    output         mmu_data_uncache_en,
    output         mmu_sc_addr_eq,

    input          EX1_load,
    input          EX1_store,
    input          EX1_cacop,
    input          EX1_tlbsrch,
    input [1:0]    cache_op_mode     
);
    // CSR
    wire [31:0] csr_dmw0_rvalue;
    wire [31:0] csr_dmw1_rvalue;
    wire [31:0] csr_crmd_rvalue;
    wire [31:0] csr_asid_rvalue;
    wire [31:0] csr_tlbehi_rvalue;
    wire [ 9:0] csr_asid_asid;        // to EX1 and IF
    wire        disable_cache;
    wire [27:0] lladdr;

    wire [ 1:0] csr_crmd_plv;
    wire [ 1:0] csr_crmd_datf;
    wire [ 1:0] csr_crmd_datm;

    wire csr_crmd_da;
    wire csr_crmd_pg;


    wire       csr_dmw0_plv0;
    wire       csr_dmw0_plv3;
    wire [2:0] csr_dmw0_pseg;
    wire [2:0] csr_dmw0_vseg;
    wire [1:0] csr_dmw0_mat;

    wire       csr_dmw1_plv0;
    wire       csr_dmw1_plv3;
    wire [2:0] csr_dmw1_pseg;
    wire [2:0] csr_dmw1_vseg;
    wire [1:0] csr_dmw1_mat;
    
//
    wire inst_dmw0_hit;
    wire inst_dmw1_hit;
    wire inst_dmw_hit;
    
    wire data_dmw0_hit;
    wire data_dmw1_hit;
    wire data_dmw_hit;

    wire da_hit;
    wire inst_cmp_plv;
    wire data_cmp_plv;
    wire [31:0] inst_tlb_addr;
    wire [31:0] data_tlb_addr;

//exception
    wire IF_excp_tlbr;
    wire IF_excp_pif;
    wire IF_excp_ppi;

    wire EX1_excp_tlb;
    wire EX1_excp_pil;
    wire EX1_excp_pis;
    wire EX1_excp_ppi;
    wire EX1_excp_pme;

//bus

    assign tlb_data = {
        s1_found,
        s1_index,
        r_e,
        r_vppn,
        r_ps,
        r_asid,
        r_g,
        r_ppn0,
        r_plv0,
        r_mat0,
        r_d0,
        r_v0,
        r_ppn1,
        r_plv1,
        r_mat1,
        r_d1,
        r_v1
    };

    assign {
        lladdr,
        disable_cache,
        csr_tlbehi_rvalue,
        csr_crmd_rvalue,
        csr_asid_rvalue,
        csr_dmw0_rvalue,
        csr_dmw1_rvalue
    } = csr_mmu_values;

    // 读CSR
    assign csr_crmd_da   = csr_crmd_rvalue[`CSR_CRMD_DA];
    assign csr_crmd_pg   = csr_crmd_rvalue[`CSR_CRMD_PG];
    assign csr_crmd_plv  = csr_crmd_rvalue[`CSR_CRMD_PLV];
    assign csr_crmd_datf = csr_crmd_rvalue[`CSR_CRMD_DATF];
    assign csr_crmd_datm = csr_crmd_rvalue[`CSR_CRMD_DATM]; 

    assign csr_asid_asid = csr_asid_rvalue[`CSR_ASID_ASID];

    assign csr_dmw0_plv0 = csr_dmw0_rvalue[`CSR_DMW0_PLV0];
    assign csr_dmw0_plv3 = csr_dmw0_rvalue[`CSR_DMW0_PLV3];
    assign csr_dmw0_pseg = csr_dmw0_rvalue[`CSR_DMW0_PSEG];
    assign csr_dmw0_vseg = csr_dmw0_rvalue[`CSR_DMW0_VSEG];
    assign csr_dmw0_mat  = csr_dmw0_rvalue[`CSR_DMW0_MAT];

    assign csr_dmw1_plv0 = csr_dmw1_rvalue[`CSR_DMW1_PLV0];
    assign csr_dmw1_plv3 = csr_dmw1_rvalue[`CSR_DMW1_PLV3];
    assign csr_dmw1_pseg = csr_dmw1_rvalue[`CSR_DMW1_PSEG];
    assign csr_dmw1_vseg = csr_dmw1_rvalue[`CSR_DMW1_VSEG];
    assign csr_dmw1_mat  = csr_dmw1_rvalue[`CSR_DMW1_MAT];


    assign da_hit = csr_crmd_da & ~csr_crmd_pg;

    assign inst_dmw0_hit = csr_crmd_pg && (csr_crmd_plv == 2'b11 & csr_dmw0_plv3 | csr_crmd_plv == 2'b00 & csr_dmw0_plv0) & (inst_vaddr[31:29] == csr_dmw0_vseg);
    assign inst_dmw1_hit = csr_crmd_pg && (csr_crmd_plv == 2'b11 & csr_dmw1_plv3 | csr_crmd_plv == 2'b00 & csr_dmw1_plv0) & (inst_vaddr[31:29] == csr_dmw1_vseg);
    assign inst_dmw_hit  = inst_dmw0_hit | inst_dmw1_hit;

    assign data_dmw0_hit = csr_crmd_pg && (csr_crmd_plv == 2'b11 & csr_dmw0_plv3 | csr_crmd_plv == 2'b00 & csr_dmw0_plv0) & (data_vaddr[31:29] == csr_dmw0_vseg);
    assign data_dmw1_hit = csr_crmd_pg && (csr_crmd_plv == 2'b11 & csr_dmw1_plv3 | csr_crmd_plv == 2'b00 & csr_dmw1_plv0) & (data_vaddr[31:29] == csr_dmw1_vseg);
    assign data_dmw_hit  = data_dmw0_hit | data_dmw1_hit;

    assign inst_paddr = {32{da_hit}}        & inst_vaddr |
                        {32{inst_dmw0_hit}} & {csr_dmw0_pseg, inst_vaddr[28:0]} |
                        {32{inst_dmw1_hit}} & {csr_dmw1_pseg, inst_vaddr[28:0]} | 
                        {32{~da_hit & ~inst_dmw0_hit & ~inst_dmw1_hit}} & inst_tlb_addr;

    assign inst_tlb_addr = {32{s0_ps == 6'd12}} & {s0_ppn[19: 0], inst_vaddr[11:0]} |
                           {32{s0_ps != 6'd12}} & {s0_ppn[19:10], inst_vaddr[21:0]};

    assign data_paddr = {32{da_hit}}        & data_vaddr |
                        {32{data_dmw0_hit}} & {csr_dmw0_pseg, data_vaddr[28:0]} |
                        {32{data_dmw1_hit}} & {csr_dmw1_pseg, data_vaddr[28:0]} | 
                        {32{~da_hit & ~data_dmw0_hit & ~data_dmw1_hit}} & data_tlb_addr;

    assign data_tlb_addr = {32{s1_ps == 6'd12}} & {s1_ppn[19: 0], data_vaddr[11:0]} |
                           {32{s1_ps != 6'd12}} & {s1_ppn[19:10], data_vaddr[21:0]};



    assign inst_cmp_plv = ~(csr_crmd_plv == 2'b11 & s0_plv == 2'b00);
    assign data_cmp_plv = ~(csr_crmd_plv == 2'b11 & s1_plv == 2'b00);

    assign IF_excp_tlbr = ~da_hit & ~inst_dmw_hit & ~s0_found;
    assign IF_excp_pif  = ~da_hit & ~inst_dmw_hit &  s0_found & ~s0_v; 
    assign IF_excp_ppi  = ~da_hit & ~inst_dmw_hit &  s0_found &  s0_v & ~inst_cmp_plv; 

    assign EX1_excp_tlbr = ~da_hit & ~data_dmw_hit & ~s1_found & (EX1_load | EX1_store | EX1_cacop);
    assign EX1_excp_pil  = ~da_hit & ~data_dmw_hit &  s1_found & ~s1_v & (EX1_load | EX1_cacop) ;
    assign EX1_excp_pis  = ~da_hit & ~data_dmw_hit &  s1_found & ~s1_v & EX1_store;
    assign EX1_excp_ppi  = ~da_hit & ~data_dmw_hit &  s1_found &  s1_v & ~data_cmp_plv & (EX1_load | EX1_store | EX1_cacop); 
    assign EX1_excp_pme  = ~da_hit & ~data_dmw_hit &  s1_found &  s1_v &  data_cmp_plv & ~s1_d & EX1_store;

    assign IF_tlb_excps = {
        IF_excp_ppi,
        IF_excp_pif,
        IF_excp_tlbr
    };

    assign EX1_tlb_excps = {
        EX1_excp_pil,
        EX1_excp_pis,
        EX1_excp_ppi,
        EX1_excp_pme,
        EX1_excp_tlbr
    };


    assign mmu_inst_uncache_en = da_hit   & (csr_crmd_datf == 2'b00) | 
                             inst_dmw0_hit & (csr_dmw0_mat == 2'b00)  |
                             inst_dmw1_hit & (csr_dmw1_mat == 2'b00)  |
                             (~da_hit & ~inst_dmw0_hit & ~inst_dmw1_hit) & (s0_mat == 2'b0)  |
                             disable_cache;

    assign mmu_data_uncache_en = da_hit   & (csr_crmd_datm == 2'b00) |
                             data_dmw0_hit & (csr_dmw0_mat == 2'b00)  |
                             data_dmw1_hit & (csr_dmw1_mat == 2'b00)  |
                             (~da_hit & ~data_dmw0_hit & ~data_dmw1_hit) & ~(EX1_cacop & cache_op_mode != 2'b10) & (s1_mat == 2'b0)  |
                             disable_cache;
                             
    assign sc_ll_paddr = {s1_ppn, data_vaddr[11:0]};
    assign mmu_sc_addr_eq = (lladdr == sc_ll_paddr[31:4]);

    assign inst_unhit = ~da_hit & ~inst_dmw0_hit & ~inst_dmw1_hit;
    assign data_unhit = ~da_hit & ~data_dmw0_hit & ~data_dmw1_hit;

endmodule