`include "header.v"

module decode (
        input wire [31:0] instruction,

        output wire [4:0] regfile_raddr1,
        output wire [4:0] regfile_raddr2,
        output wire       regfile_we,
        output wire [4:0] regfile_waddr,

        output wire [1:0] sel_npc,

        output wire [4:0] alu_op,
        output wire [2:0] comparator_op,

        output wire [2:0] sel_issue_queue,

        output wire sel_imm,

        output wire [1:0] ext_simm,

        output wire sel_lui12,

        output wire [6:0] md_op,

        output [2:0] sel_load_store_len,

        output [2:0] sel_pre_result,

        output [13:0] csr_addr,
        output        csr_we,
        output        csr_re,
        output        sel_csr_wmask,
        output        csr_ertn_flush,

        output is_sys,
        output is_brk,
        output is_ine,




        output [4:0] invtlb_op,


        output is_inst_tlbsrch,
        output is_inst_tlbrd,
        output is_inst_tlbwr,
        output is_inst_tlbfill,
        output is_inst_invtlb,


        output is_cacop,


        output wb_refetch,

        output       csr_3w,
        output       is_CNTinst,
        output [7:0] load_valid,
        output [7:0] store_valid,

        output is_idle,

        output is_ll_w,
        output is_sc_w,
        output is_dbar



    );

    wire is_load;
    wire is_store;

    wire [4:0] rj, rk, rd;

    wire [5:0] inst_31_26;
    wire [3:0] inst_25_22;
    wire [1:0] inst_21_20;
    wire [4:0] inst_19_15;

    wire       inst_add_w;
    wire       inst_sub_w;
    wire       inst_slt;
    wire       inst_sltu;
    wire       inst_addi_w;
    wire       inst_ld_w;
    wire       inst_st_w;
    wire       inst_beq;
    wire       inst_bne;
    wire       inst_bl;
    wire       inst_b;
    wire       inst_jirl;
    wire       inst_slli_w;
    wire       inst_srli_w;
    wire       inst_srai_w;
    wire       inst_lu12i_w;
    wire       inst_and;
    wire       inst_nor;
    wire       inst_or;
    wire       inst_xor;

    wire       inst_slti;
    wire       inst_sltui;
    wire       inst_andi;
    wire       inst_ori;
    wire       inst_xori;
    wire       inst_sll;
    wire       inst_srl;
    wire       inst_sra;
    wire       inst_pcaddu12i;
    wire       inst_mul_w;
    wire       inst_mulh_w;
    wire       inst_mulh_wu;
    wire       inst_div_w;
    wire       inst_mod_w;
    wire       inst_div_wu;
    wire       inst_mod_wu;

    wire       inst_blt;
    wire       inst_bge;
    wire       inst_bltu;
    wire       inst_bgeu;
    wire       inst_ld_b;
    wire       inst_ld_bu;
    wire       inst_ld_h;
    wire       inst_ld_hu;
    wire       inst_st_b;
    wire       inst_st_h;

    wire       inst_csrrd;
    wire       inst_csrwr;
    wire       inst_csrxchg;
    wire       inst_ertn;
    wire       inst_syscall;

    wire       inst_break;

    wire       inst_rdcntid_w;
    wire       inst_rdcntvl_w;
    wire       inst_rdcntvh_w;

    wire       inst_tlbsrch;
    wire       inst_tlbrd;
    wire       inst_tlbwr;
    wire       inst_tlbfill;
    wire       inst_invtlb;

    wire       inst_cacop;

    wire       inst_idle;
    wire       inst_ll_w;
    wire       inst_sc_w;
    wire       inst_dbar;
    wire       inst_ibar;

    wire       inst_preld;
    wire       inst_cpucfg;


    assign inst_31_26 = instruction[31:26];
    assign inst_25_22 = instruction[25:22];
    assign inst_21_20 = instruction[21:20];
    assign inst_19_15 = instruction[19:15];

    assign inst_add_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_00000;

    assign inst_sub_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_00010;

    assign inst_slt = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_00100;

    assign inst_sltu = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_00101;

    assign inst_addi_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_1010;

    assign inst_ld_w = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_0010;

    assign inst_st_w = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_0110;

    assign inst_beq = inst_31_26 == `inst_31_26_010110;

    assign inst_bne = inst_31_26 == `inst_31_26_010111;

    assign inst_bl = inst_31_26 == `inst_31_26_010101;

    assign inst_b = inst_31_26 == `inst_31_26_010100;

    assign inst_jirl = inst_31_26 == `inst_31_26_010011;

    assign inst_slli_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_00001;

    assign inst_srli_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_01001;

    assign inst_srai_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10001;

    assign inst_lu12i_w = inst_31_26 == `inst_31_26_000101;

    assign inst_and = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_01001;

    assign inst_nor = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_01000;

    assign inst_or = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_01010;

    assign inst_xor = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_01011;


    assign inst_slti = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_1000;

    assign inst_sltui = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_1001;

    assign inst_andi = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_1101;

    assign inst_ori = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_1110;

    assign inst_xori = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_1111;

    assign inst_sll = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_01110;

    assign inst_srl = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_01111;

    assign inst_sra = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_10000;

    assign inst_pcaddu12i = inst_31_26 == `inst_31_26_000111;

    assign inst_mul_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_11000;

    assign inst_mulh_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_11001;

    assign inst_mulh_wu = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_01 && inst_19_15 == `inst_19_15_11010;

    assign inst_div_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_10 && inst_19_15 == `inst_19_15_00000;

    assign inst_mod_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_10 && inst_19_15 == `inst_19_15_00001;

    assign inst_div_wu = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_10 && inst_19_15 == `inst_19_15_00010;

    assign inst_mod_wu = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_10 && inst_19_15 == `inst_19_15_00011;

    assign inst_blt = inst_31_26 == `inst_31_26_011000;

    assign inst_bge = inst_31_26 == `inst_31_26_011001;

    assign inst_bltu = inst_31_26 == `inst_31_26_011010;

    assign inst_bgeu = inst_31_26 == `inst_31_26_011011;

    assign inst_ld_b = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_0000;

    assign inst_ld_h = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_0001;

    assign inst_ld_bu = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_1000;

    assign inst_ld_hu = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_1001;


    assign inst_st_b = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_0100;

    assign inst_st_h = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_0101;

    assign inst_csrrd = inst_31_26 == `inst_31_26_000001 && inst_25_22[3:2] == 2'b0 && rj == 5'b0;

    assign inst_csrwr = inst_31_26 == `inst_31_26_000001 && inst_25_22[3:2] == 2'b0 && rj == 5'b1;

    assign inst_csrxchg = inst_31_26 == `inst_31_26_000001 && inst_25_22[3:2] == 2'b0 && rj != 5'b0 && rj != 5'b1;

    assign inst_ertn = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10000 && instruction[14:10] == 5'b01110 && instruction[9:0] == 10'b0;

    assign inst_syscall = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_10 && inst_19_15 == `inst_19_15_10110;

    assign inst_break = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_10 && inst_19_15 == `inst_19_15_10100;

    assign inst_rdcntid_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_00000 && rk == 5'b11000 && rd == 5'b00000;

    assign inst_rdcntvl_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_00000 && rk == 5'b11000 && rj == 5'b00000;

    assign inst_rdcntvh_w = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_00000 && rk == 5'b11001 && rj == 5'b00000;

    assign inst_tlbsrch = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10000 && rk == 5'b01010 && rj == 5'b00000 && rd == 5'b00000;

    assign inst_tlbrd = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10000 && rk == 5'b01011 && rj == 5'b00000 && rd == 5'b00000;

    assign inst_tlbwr = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10000 && rk == 5'b01100 && rj == 5'b00000 && rd == 5'b00000;

    assign inst_tlbfill = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10000 && rk == 5'b01101 && rj == 5'b00000 && rd == 5'b00000;

    assign inst_invtlb = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10011;

    assign inst_cacop = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1000;

    assign inst_idle = inst_31_26 == `inst_31_26_000001 && inst_25_22 == `inst_25_22_1001 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_10001;

    assign inst_ll_w = inst_31_26 == `inst_31_26_001000 && inst_25_22[3:2] == 2'b00;

    assign inst_sc_w = inst_31_26 == `inst_31_26_001000 && inst_25_22[3:2] == 2'b01;

    assign inst_dbar = inst_31_26 == `inst_31_26_001110 && inst_25_22 == `inst_25_22_0001 && inst_21_20 == `inst_21_20_11 && inst_19_15 == `inst_19_15_00100;

    assign inst_ibar = inst_31_26 == `inst_31_26_001110 && inst_25_22 == `inst_25_22_0001 && inst_21_20 == `inst_21_20_11 && inst_19_15 == `inst_19_15_00101;

    assign inst_preld = inst_31_26 == `inst_31_26_001010 && inst_25_22 == `inst_25_22_1011;

    assign inst_cpucfg = inst_31_26 == `inst_31_26_000000 && inst_25_22 == `inst_25_22_0000 && inst_21_20 == `inst_21_20_00 && inst_19_15 == `inst_19_15_00000 && rk == 5'b11011;

    assign alu_op = inst_sub_w ? `ALU_SUB :
           inst_lu12i_w ? `ALU_LU12I :
           inst_slt || inst_slti? `ALU_SLT :
           inst_sltu || inst_sltui? `ALU_SLTU :
           inst_slli_w || inst_sll ? `ALU_SLL :
           inst_srli_w || inst_srl ? `ALU_SRL :
           inst_srai_w || inst_sra ? `ALU_SRA :
           inst_and || inst_andi ? `ALU_AND :
           inst_nor ? `ALU_NOR :
           inst_or || inst_ori ? `ALU_OR :
           inst_xor || inst_xori ? `ALU_XOR :
           inst_pcaddu12i ? `ALU_PCADDU12I :
           inst_cpucfg ? `ALU_CPUCFG :

           // inst_mul_w ?  `ALU_MUL_W :
           // inst_mulh_w ? `ALU_MULH_W :
           // inst_mulh_wu ? `ALU_MULH_WU :
           // inst_div_w ? `ALU_DIV_W :
           // inst_mod_w ? `ALU_MOD_W :
           // inst_div_wu ? `ALU_DIV_WU :
           // inst_mod_wu ? `ALU_MOD_WU :
           `ALU_ADD;


    assign rk = instruction[14:10];
    assign rj = instruction[9:5];
    assign rd = instruction[4:0];

    assign regfile_raddr1 = inst_rdcntid_w || inst_break || inst_csrrd ||
           inst_csrwr || inst_ertn || inst_syscall || inst_dbar|| inst_ibar || inst_preld ||
           inst_bl || inst_b || inst_lu12i_w ||
           inst_pcaddu12i || inst_rdcntvl_w || inst_rdcntvh_w ||
           inst_tlbsrch || inst_tlbrd || inst_tlbwr ||
           inst_tlbfill || inst_idle ? 5'b0 : rj;
    //prefetch

    assign regfile_raddr2 = inst_beq || inst_bne || inst_st_w || inst_sc_w ||
           inst_st_b || inst_st_h || inst_csrwr || inst_csrxchg ||
           inst_blt || inst_bge || inst_bltu || inst_bgeu ? rd :
           inst_addi_w || inst_ld_w || inst_bl || inst_b || inst_cpucfg ||
           inst_jirl || inst_slli_w || inst_srli_w ||
           inst_srai_w || inst_lu12i_w || inst_slti ||
           inst_sltui || inst_andi || inst_ori ||
           inst_xori || inst_pcaddu12i || inst_ld_b || inst_ll_w ||
           inst_ld_bu || inst_ld_h || inst_ld_hu || inst_csrrd ||
           inst_ertn || inst_syscall || inst_break || inst_rdcntid_w ||
           inst_rdcntvl_w || inst_rdcntvh_w || inst_tlbsrch || inst_dbar|| inst_ibar || inst_preld ||
           inst_tlbrd || inst_tlbwr || inst_tlbfill || inst_idle  || inst_cacop ? 5'd0 : rk;


    assign regfile_waddr = inst_bl ? 5'd1 :
           inst_st_w || inst_st_b || inst_st_h || inst_beq || inst_cacop ||
           inst_bne || inst_b || inst_blt || inst_bge || inst_idle || inst_dbar|| inst_ibar || inst_preld ||
           inst_bltu || inst_bgeu || inst_ertn || inst_syscall || inst_tlbsrch || inst_tlbrd ||
           inst_tlbwr || inst_tlbfill || inst_invtlb? 5'd0 :
           inst_rdcntid_w ? rj : rd;

    assign regfile_we = inst_st_w || inst_beq || inst_bne || inst_b ||
           inst_blt || inst_bge || inst_bltu || inst_bgeu ||
           inst_st_b || inst_st_h || inst_ertn || inst_syscall || inst_dbar|| inst_ibar || inst_preld ||
           inst_break || inst_tlbsrch || inst_tlbrd || inst_tlbwr ||
           inst_tlbfill || inst_invtlb || inst_cacop || inst_idle ? 1'b0 : 1'b1;

    assign comparator_op = inst_beq ? `COMPARATOR_EQ : inst_bne ? `COMPARATOR_NE : inst_blt ? `COMPARATOR_LT : inst_bge ? `COMPARATOR_GE : inst_bltu ? `COMPARATOR_LTU : inst_bgeu ? `COMPARATOR_GEU : `COMPARATOR_EQ;

    assign sel_npc = inst_jirl ? `SEL_NPC_JIRL : inst_b || inst_bl ? `SEL_NPC_B : inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu ? `SEL_NPC_BRANCH : `SEL_NPC_DEFAULT;

    assign sel_imm = inst_slti || inst_slli_w || inst_srli_w || inst_srai_w ||
           inst_addi_w || inst_ld_w || inst_st_w || inst_cacop || inst_cpucfg||
           inst_sltui || inst_andi || inst_ori || inst_xori ||
           inst_ld_b || inst_ld_bu || inst_ld_h || inst_ll_w ||
           inst_ld_hu || inst_st_b || inst_st_h || inst_sc_w ||
           inst_jirl || inst_b || inst_bl || inst_beq ||
           inst_bne || inst_blt || inst_bge || inst_bltu ||
           inst_bgeu ;

    assign ext_simm = inst_sltui || inst_slti || inst_addi_w || inst_ld_w ||
           inst_ld_b || inst_ld_bu || inst_ld_h || inst_cacop || inst_cpucfg ||
           inst_ld_hu || inst_st_w || inst_st_b || inst_st_h ? `EXT_SIMM_SI12 :
           inst_jirl || inst_beq || inst_bne || inst_blt || inst_bge ||
           inst_bltu || inst_bgeu ? `EXT_SIMM_OFFS_15_0 :
           inst_b || inst_bl ? `EXT_SIMM_OFFS_25_0 :
           `EXT_SIMM_UI12 ;

    wire sel_brq_queue;
    wire sel_load_queue;
    wire sel_store_queue;
    wire sel_md_queue;
    wire sel_fast_queue;
    wire sel_privilege_queue;
    wire sel_no_queue;

    assign sel_load_queue = is_load || inst_cacop || inst_dbar;
    assign sel_store_queue = is_store;
    assign sel_brq_queue = sel_npc == `SEL_NPC_JIRL || sel_npc == `SEL_NPC_BRANCH;
    assign sel_md_queue = inst_mod_wu || inst_div_wu || inst_mod_w || inst_div_w || inst_mulh_wu || inst_mulh_w || inst_mul_w;
    assign sel_fast_queue = inst_bl || inst_pcaddu12i || inst_lu12i_w || inst_rdcntvh_w || inst_rdcntvl_w;
    assign sel_privilege_queue = inst_rdcntid_w || inst_csrrd || inst_csrwr || inst_csrxchg || inst_tlbsrch || inst_tlbrd || inst_tlbwr || inst_tlbfill || inst_invtlb;
    assign sel_no_queue = inst_b || inst_preld || inst_ibar || inst_idle;


    assign sel_issue_queue = sel_brq_queue ? `SEL_ISSUE_QUEUE_BRQ :
           sel_load_queue ? `SEL_ISSUE_QUEUE_LOAD :
           sel_store_queue ? `SEL_ISSUE_QUEUE_STORE :
           sel_md_queue ? `SEL_ISSUE_QUEUE_MD :
           sel_fast_queue ? `SEL_ISSUE_QUEUE_FAST :
           sel_privilege_queue ? `SEL_ISSUE_QUEUE_PRIVILIEGE:
           sel_no_queue ? `SEL_ISSUE_QUEUE_NO :
           `SEL_ISSUE_QUEUE_INTEGER;


    assign sel_lui12 = inst_lu12i_w || inst_pcaddu12i;


    assign md_op = {inst_mod_wu, inst_div_wu, inst_mod_w, inst_div_w, inst_mulh_wu, inst_mulh_w, inst_mul_w};


    assign is_load = inst_ld_b || inst_ld_bu || inst_ld_h || inst_ld_hu || inst_ld_w || inst_ll_w || inst_sc_w;
    assign is_store = inst_st_b || inst_st_h || inst_st_w ;


    assign sel_load_store_len = inst_ld_b || inst_st_b ? `SEL_LOAD_STORE_B :
           inst_ld_bu ? `SEL_LOAD_STORE_BU :
           inst_ld_h || inst_st_h ? `SEL_LOAD_STORE_H :
           inst_ld_hu ? `SEL_LOAD_STORE_HU :
           inst_ld_w || inst_st_w || inst_ll_w || inst_sc_w? `SEL_LOAD_STORE_W : 3'b111;

    assign sel_pre_result = inst_rdcntvh_w ? `SEL_PRE_RESULT_RDCNTVH :
           inst_rdcntvl_w ? `SEL_PRE_RESULT_RDCNTVL :
           inst_lu12i_w ? `SEL_PRE_RESULT_LU12I :
           inst_pcaddu12i ? `SEL_PRE_RESULT_PCADDU12I :
           inst_bl ? `SEL_PRE_RESULT_PCADD4 :
           inst_ll_w || inst_sc_w ? `SEL_PRE_RESULT_SI14:
           `SEL_PRE_RESULT_IMM;

    assign invtlb_op = rd;
    assign is_inst_tlbsrch = inst_tlbsrch;
    assign is_inst_tlbrd = inst_tlbrd;
    assign is_inst_tlbwr = inst_tlbwr;
    assign is_inst_tlbfill = inst_tlbfill;
    assign is_inst_invtlb = inst_invtlb;


    assign csr_addr = inst_rdcntid_w ? `CSR_ADDR_TID : instruction[23:10];

    assign csr_we = inst_csrwr || inst_csrxchg;

    assign csr_re = inst_csrrd || inst_csrwr || inst_csrxchg || inst_rdcntid_w;

    assign sel_csr_wmask = inst_csrwr;

    assign csr_ertn_flush = inst_ertn;

    assign is_sys = inst_syscall;

    assign is_brk = inst_break;

    assign is_ine = ~(inst_add_w || inst_sub_w || inst_slt || inst_sltu ||
                      inst_addi_w || inst_ld_w || inst_st_w || inst_beq ||
                      inst_bne || inst_bl || inst_b || inst_jirl ||
                      inst_slli_w || inst_srli_w || inst_srai_w ||
                      inst_lu12i_w || inst_and || inst_nor || inst_or ||
                      inst_xor || inst_slti || inst_sltui || inst_andi ||
                      inst_ori || inst_xori || inst_sll || inst_srl ||
                      inst_sra || inst_pcaddu12i || inst_mul_w ||
                      inst_mulh_w || inst_mulh_wu || inst_div_w ||
                      inst_mod_w || inst_div_wu || inst_mod_wu ||
                      inst_blt || inst_bge || inst_bltu || inst_bgeu ||
                      inst_ld_b || inst_ld_bu || inst_ld_h || inst_ld_hu ||
                      inst_st_b || inst_st_h || inst_csrrd || inst_csrwr ||
                      inst_csrxchg || inst_ertn || inst_syscall || inst_break ||
                      inst_rdcntid_w || inst_rdcntvl_w || inst_rdcntvh_w ||
                      inst_tlbsrch || inst_tlbrd || inst_tlbwr || inst_tlbfill || inst_dbar|| inst_ibar || inst_preld ||
                      inst_invtlb || inst_cacop || inst_idle || inst_ll_w || inst_sc_w || inst_cpucfg ) ||
           (inst_invtlb && invtlb_op > 5'h6)
           || ((inst_csrwr || inst_csrxchg || inst_csrrd) && csr_addr == 14'h8a);

    assign wb_refetch = ((csr_we && (csr_addr == `CSR_ADDR_CRMD || csr_addr == `CSR_ADDR_DMW0 || csr_addr == `CSR_ADDR_DMW1 || csr_addr == `CSR_ADDR_ASID || csr_addr == `CSR_ADDR_ESTAT))
                         || (inst_tlbfill || inst_tlbwr || inst_tlbsrch || inst_invtlb || inst_tlbrd /*|| is_cacop*/)) || inst_ibar;

    assign is_cacop = inst_cacop;



    assign csr_3w = (inst_csrwr || inst_csrxchg || inst_csrrd) && csr_addr == `CSR_ADDR_ESTAT;
    assign is_CNTinst = inst_rdcntid_w || inst_rdcntvh_w || inst_rdcntvl_w;
    assign load_valid = {2'b0, inst_ll_w, inst_ld_w, inst_ld_hu, inst_ld_h, inst_ld_bu, inst_ld_b};
    assign store_valid = {4'b0, inst_sc_w, inst_st_w, inst_st_h, inst_st_b};

    assign is_idle = inst_idle;
    assign is_ll_w = inst_ll_w;
    assign is_sc_w = inst_sc_w;
    assign is_dbar = inst_dbar;


endmodule
