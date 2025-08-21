`define CSR_CRMD                14'h0
`define CSR_PRMD                14'h1
`define CSR_ECFG                14'h4
`define CSR_ESTAT               14'h5
`define CSR_ERA                 14'h6
`define CSR_BADV                14'h7
`define CSR_EENTRY              14'hc
`define CSR_TLBIDX              14'h10
`define CSR_TLBEHI              14'h11
`define CSR_TLBELO0             14'h12
`define CSR_TLBELO1             14'h13
`define CSR_ASID                14'h18
`define CSR_PGDL                14'h19
`define CSR_PGDH                14'h1a
`define CSR_PGD                 14'h1b
`define CSR_CPUID               14'h20
`define CSR_SAVE0               14'h30
`define CSR_SAVE1               14'h31
`define CSR_SAVE2               14'h32
`define CSR_SAVE3               14'h33
`define CSR_TID                 14'h40
`define CSR_TCFG                14'h41
`define CSR_TVAL                14'h42
`define CSR_CNTC                14'h43
`define CSR_TICLR               14'h44
`define CSR_LLBCTL              14'h60
`define CSR_TLBRENTRY           14'h88
`define CSR_CPUCFG1             14'hb1 
`define CSR_CPUCFG2             14'hb2 
`define CSR_CPUCFG10            14'hc0
`define CSR_CPUCFG11            14'hc1
`define CSR_CPUCFG12            14'hc2
`define CSR_CPUCFG13            14'hc3
`define CSR_DISABLE_CACHE       14'h101
`define CSR_DMW0                14'h180
`define CSR_DMW1                14'h181


    // CRMD寄存器
`define CSR_CRMD_PLV 1 : 0
`define CSR_CRMD_PIE 2
`define CSR_CRMD_DA 3
`define CSR_CRMD_PG 4
`define CSR_CRMD_DATF 6 : 5
`define CSR_CRMD_DATM 8 : 7

    // PRMD寄存 器
`define CSR_PRMD_PPLV 1 : 0
`define CSR_PRMD_PIE 2

    // ECFG寄存器
`define CSR_ECFG_LIE 12 : 0

    // ESTAT寄存器
`define CSR_ESTAT_IS10 1 : 0

    // ERA寄存器
`define CSR_ERA_PC 31 : 0

    // BADV寄存器
    // 没写好，共八种出错，还没有规定好,目前能用到的好像只有两种
`define ECODE_INT 6'h0
`define ECODE_PIL 6'h1
`define ECODE_PIS 6'h2 
`define ECODE_PIF 6'h3 
`define ECODE_PME 6'h4
`define ECODE_PPI 6'h7
`define ECODE_ADE 6'h8  
`define ECODE_ALE 6'h9
`define ECODE_SYS 6'hb 
`define ECODE_BRK 6'hc 
`define ECODE_INE 6'hd 
`define ECODE_IPE 6'he 
`define ECODE_FPD 6'hf
`define ECODE_FPE 6'h12 
`define ECODE_TLBR 6'h3f 


`define ESUBCODE_ADEF 9'h0 
`define ESUBCODE_ADEM 9'h1
    // EENTRY寄存器
`define CSR_EENTRY_VA 31 : 6

    // TLBIDX寄存器
`define CSR_TLBIDX_INDEX 4 : 0
`define CSR_TLBIDX_PS 29 : 24
`define CSR_TLBIDX_NE 31

    // TLBEHI寄存器
`define CSR_TLBEHI_VPPN 31 : 13

    // TLBELO寄存器
`define CSR_TLBELO_V 0
`define CSR_TLBELO_D 1
`define CSR_TLBELO_PLV 3 : 2
`define CSR_TLBELO_MAT 5 : 4
`define CSR_TLBELO_G 6
`define CSR_TLBELO_PPN 27 : 8

    // ASID寄存器
`define CSR_ASID_ASID 9 : 0

    // PGDL寄存器
`define CSR_PGDL_BASE 31 : 12

    // PGDH寄存器
`define CSR_PGDH_BASE 31 : 12

    // PGD寄存器
`define CSR_PGD_BASE 31 : 12

    // SAVE0~3寄存器
`define CSR_SAVE_DATA 31 : 0

    // TID寄存器
`define CSR_TID_TID 31 : 0

    // TCFG寄存器
    // 这一块的宏定义还有部分问题，暂时还没有搞清楚
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31 : 2
`define CSR_TCFG_INITVAL 31 : 2

    // TICLR寄存器
`define CSR_TICLR_CLR 0

    // TLBERNTRY寄存器
`define CSR_TLBRENTRY_PA 31 : 6

    // DMW0寄存器
`define CSR_DMW0_PLV0 0
`define CSR_DMW0_PLV3 3
`define CSR_DMW0_MAT 5 : 4
`define CSR_DMW0_PSEG 27 : 25
`define CSR_DMW0_VSEG 31 : 29

    // DMW1寄存器
`define CSR_DMW1_PLV0 0
`define CSR_DMW1_PLV3 3
`define CSR_DMW1_MAT 5 : 4
`define CSR_DMW1_PSEG 27 : 25
`define CSR_DMW1_VSEG 31 : 29

    // LLBCTL寄存器
`define CSR_LLBCTL_ROLLB 0
`define CSR_LLBCTL_WCLLB 1
`define CSR_LLBCTL_KLO 2