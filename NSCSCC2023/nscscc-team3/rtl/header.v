`default_nettype wire
//`define PERF_STAT_EN
`ifdef PERF_STAT_EN
    `define PERF_STAT_PIF_TO_IF     2
    `define PERF_STAT_IF_TO_ID      10
    `define PERF_STAT_ID_TO_EXE     10
    `define PERF_STAT_EXE_TO_PMEM   15
    `define PERF_STAT_PMEM_TO_MEM   17
`else
    `define PERF_STAT_PIF_TO_IF     0
    `define PERF_STAT_IF_TO_ID      0
    `define PERF_STAT_ID_TO_EXE     0
    `define PERF_STAT_EXE_TO_PMEM   0
    `define PERF_STAT_PMEM_TO_MEM   0
`endif

`ifdef DIFFTEST_EN
    `define DIFF_ID_TO_EXE     32
    `define DIFF_EXE_TO_PMEM   32
    `define DIFF_PMEM_TO_MEM   208
`else
    `define DIFF_ID_TO_EXE     0
    `define DIFF_EXE_TO_PMEM   0
    `define DIFF_PMEM_TO_MEM   0
`endif
`define INSTR_COUNT                 67
`define WIDTH_PDC_BUS               77
`define WIDTH_ALUOP                 13
`define WIDTH_BR_BUS                69+1+1
`define WIDTH_PIF_TO_IF_BUS         32+1+6+2+1+1 + `PERF_STAT_PIF_TO_IF
`define WIDTH_IF_TO_ID_BUS          64+1+6+2+1+`WIDTH_PDC_BUS + `PERF_STAT_IF_TO_ID
`define WIDTH_WB_TO_RF_BUS          38
`define WIDTH_EX_JUMP_BUS           33
`define WIDTH_REFETCH_BUS           32+1+1+2+32+8+32
`define WIDTH_PIF_BUS               1+32+2
`define WIDTH_AGU_TO_TLB_BUS        32+1+1+1+1

//DIFFTEST
`define WIDTH_CSR_DIFF  32*26

//流水线
`define WIDTH_ID_TO_EXE_BUS         (148+8+5+5+9+15+`WIDTH_ALUOP+17+1) + `DIFF_ID_TO_EXE + `PERF_STAT_ID_TO_EXE
`define WIDTH_EXE_TO_PMEM_BUS       (147+8+5+8+4+17+1) + `DIFF_EXE_TO_PMEM + `PERF_STAT_EXE_TO_PMEM
`define WIDTH_PMEM_TO_MEM_BUS       (32+32+5+32+5+1+1+1) + `DIFF_PMEM_TO_MEM + `PERF_STAT_PMEM_TO_MEM
//旁路
`define WIDTH_BYPASS_FROM_ID_BUS    12
`define WIDTH_BYPASS_FROM_EXE_BUS   38 
`define WIDTH_BYPASS_FROM_PMEM_BUS  38 
`define WIDTH_BYPASS_FROM_MEM_BUS   38
`define WIDTH_BYPASS_FROM_WB_BUS    5
`define WIDTH_BYPASS_TO_ID_BUS      105
//TLB
`define WIDTH_TLB_INDEX             4
`define TLBNUM                      (1<<`WIDTH_TLB_INDEX)
`define WIDTH_CSR_TO_TLB_BUS        `WIDTH_TLB_INDEX*2+124
`define WIDTH_TLB_TO_CSR_BUS        `WIDTH_TLB_INDEX+90
`define WIDTH_EX_VEC                16

//CSR寄存器
`define CSR_CRMD        14'h0
`define CSR_PRMD        14'h1
`define CSR_EUEN        14'h2
`define CSR_ECFG        14'h4
`define CSR_ESTAT       14'h5
`define CSR_ERA         14'h6
`define CSR_BADV        14'h7
`define CSR_EENTRY      14'hc
`define CSR_TLBIDX      14'h10
`define CSR_TLBEHI      14'h11
`define CSR_TLBELO0     14'h12
`define CSR_TLBELO1     14'h13
`define CSR_ASID        14'h18
`define CSR_PGDL        14'h19
`define CSR_PGDH        14'h1A
`define CSR_PGD         14'h1B
`define CSR_CPUID       14'h20
`define CSR_SAVE0       14'h30
`define CSR_SAVE1       14'h31
`define CSR_SAVE2       14'h32
`define CSR_SAVE3       14'h33
`define CSR_TID         14'h40
`define CSR_TCFG        14'h41
`define CSR_TVAL        14'h42
`define CSR_TICLR       14'h44
`define CSR_LLBCTL      14'h60
`define READ_LLBIT      14'h61   //不是一个CSR，只是读出llbit
`define CSR_TLBRENTRY   14'h88
`define CSR_CTAG        14'h98
`define CSR_DMW0        14'h180
`define CSR_DMW1        14'h181

//例外编码
`define ECODE_INT       6'h0
`define ECODE_PIL       6'h1
`define ECODE_PIS       6'h2
`define ECODE_PIF       6'h3
`define ECODE_PME       6'h4
`define ECODE_PPI       6'h7
`define ECODE_ADE       6'h8
`define ECODE_ALE       6'h9
`define ECODE_SYS       6'hb
`define ECODE_BRK       6'hc
`define ECODE_INE       6'hd
`define ECODE_IPE       6'he
`define ECODE_FPD       6'hf 
`define ECODE_FPE       6'h12 
`define ECODE_TLBR      6'h3f 
