`include "header.v"
/*
    模块不检查输入指令的有效性
*/
module ctrl(
    input  [31:0]   instr,
    input  [`WIDTH_PDC_BUS - 1:0] predecode_bus,
    input  [4:0]    rd_id,
    input  [1:0]    plv,
    input  [13:0]   csr_addr,
    output          c_refetch,
    output [2:0]    c_npcsel,
    output [7:0]    c_immsel,
    output [2:0]    c_reg_as_read,
    output          c_alusrc_a,
    output [2:0]    c_alusrc_b,
    output [`WIDTH_ALUOP - 1:0]   c_aluop,
    output [2:0]    c_mduop,
    output [4:0]    c_brop,
    output [2:0]    c_memwr,
    output [4:0]    c_memrd,
    output [3:0]    c_wbsel,
    output          c_regwr,
    output          c_rnum_b_sel,
    output [2:0]    c_rnum_c_sel,
    output          c_csrwr,
    output [2:0]    c_cntsel,   //计数器输出选择
    output          csr_wmask_id,
    output          is_ertn,      //是否为ertn指令
    output          ex_sys,       //是否报出sys例外
    output          ex_brk,       //是否报出brk例外
    output          ex_ine,       //是否报出ine例外
    output          ex_ipe,
    output          is_tlbrd,     //是否为tlbrd指令
    output          is_tlbwr,     //是否为tlbwr指令
    output          is_tlbfill,   //是否为tlbfill指令
    output          is_tlbsrch,   //是否为tlbsrch指令
    output          is_invtlb,    //是否为invtlb指令
    output          is_idle,
    output          is_ll_w,
    output          is_sc_w,
    output          is_cacop,
    output          is_br,
    output          is_jirl,
    output          is_mdu_instr
    /*
    output          is_preld,
    output          is_ibar*/
);

wire          type_a;
wire          type_b;
wire          type_c;
wire          type_d;
wire          type_e;
wire          type_f;
wire          type_g;
wire          type_h;
//假定已属于某大类,并且指令一定有效的条件下，具体的小类
wire          a_rdcntid;
wire          a_ine;
wire          b_break_or_syscall;
wire          b_add_w;
wire          b_div_mod;
wire          b_mul;
wire          b_or;
wire          b_syscall;
wire          b_break;
wire          b_sll_w;
wire          b_xor;
wire          b_and;
wire          b_nor;
wire          b_sltu;
wire          b_slt;
wire          b_mduop2;
wire          b_mduop1;
wire          b_ine_p1;
wire          b_ine_p2;
wire          b_ine_p10;
wire          b_ine_p11;
wire          c_ine;
wire          d_ori;
wire          d_andi;
wire          d_sltui;
wire          d_slti;
wire          d_addi_w;
wire          d_ine;
wire          e_csr;        //三条csr指令
wire          e_csrrd;
wire          e_csrwr;
wire          e_csrwe;      //指令对CSR进行写操作(csrwr和csrxchg指令)
wire          e_cacop; 
wire          e_tlbsrch;
wire          e_tlbrd;
wire          e_tlbwr; 
wire          e_tlbfill; 
wire          e_ertn;
wire          e_idle;
wire          e_invtlb;
wire          e_rj_as_read;
wire          e_cacop_not_i;
wire          e_ine_p1;
wire          e_ine_p2;
wire          e_ine_p3;
wire          e_ine_p4;
wire          e_ine_p5;
wire          e_ine_p6;
wire          e_invtlb_invop;
wire          f_ine;
wire          g_ll_w;
wire          g_sc_w;
wire          g_st;         //包含SC.W
wire          g_st_b;
wire          g_st_w;
wire          g_st_h;
wire          g_ld_b;
wire          g_ld_bu;
wire          g_ld_h;
wire          g_ld_hu;
wire          g_ld_w;
wire          g_regwne;     //不写寄存器
wire          g_ine;
wire          h_cond_br;    //指令是条件跳转指令
wire          h_jirl;       //指令是JIRL指令
wire          h_bl;         //指令是BL指令
wire          h_rj_as_read; //指令将rj寄存器作为源寄存器之一
wire          h_ine;        //未定义的H型指令
wire          h_regwne;     //不写寄存器
assign         {
    type_a,type_b,type_c,type_d,type_e,type_f,type_g,type_h,    //8
    a_rdcntid,a_ine,    //2
    b_break_or_syscall,b_add_w,b_div_mod,b_mul,b_or,b_syscall,b_break,b_sll_w,b_xor,b_and,b_nor,b_sltu,b_slt,b_mduop2,b_mduop1,
    b_ine_p1,b_ine_p2,b_ine_p10,b_ine_p11,
    c_ine,
    d_addi_w,d_ori,d_andi,d_sltui,d_slti,d_ine,
    e_csr,e_csrrd,e_csrwr,e_csrwe,e_cacop,e_tlbsrch,e_tlbrd,e_tlbwr,e_tlbfill,e_ertn,e_idle,e_invtlb,e_rj_as_read,e_cacop_not_i,
    e_ine_p1,e_ine_p2,e_ine_p3,e_ine_p4,e_ine_p5,e_ine_p6,e_invtlb_invop,
    f_ine,
    g_ll_w,g_sc_w,g_st,g_st_b,g_st_w,g_st_h,g_ld_b,g_ld_bu,g_ld_h,g_ld_hu,g_ld_w,g_regwne,g_ine,
    h_cond_br,h_jirl,h_bl,h_rj_as_read,h_ine,h_regwne
} = predecode_bus;
    /* * 
        指令译码第二部分
    */
    wire  e_ine;
    wire  b_ine;
    wire  ine_extend;

    //* 写CSR寄存器的指令只有在PMEM级之前被使用才会产生数据冒险

    assign b_ine        = ~(b_ine_p1 | b_ine_p2 | b_ine_p10 | b_ine_p11);
    assign e_ine        = ~(e_ine_p1 | e_ine_p2 | e_ine_p3 & e_ine_p4 & e_ine_p5 | e_ine_p6);
    assign ine_extend   = type_e & e_invtlb & e_invtlb_invop | instr[31];
    assign ex_ine       = type_a & a_ine | type_b & b_ine | type_c & c_ine | type_d & d_ine | type_e & e_ine 
                        | type_f & f_ine | type_g & g_ine | type_h & h_ine | ine_extend;
    assign is_br        = type_h & ~h_jirl;
    assign is_jirl      = type_h & h_jirl;
    assign is_ertn      = type_e & e_ertn;
    assign ex_sys       = type_b & b_syscall;
    assign ex_brk       = type_b & b_break;
    assign ex_ipe       = plv[0] & type_e & ~(e_cacop & instr[4] & ~instr[3]);
    assign is_tlbrd     = type_e & e_tlbrd;
    assign is_tlbwr     = type_e & e_tlbwr;
    assign is_tlbfill   = type_e & e_tlbfill;
    assign is_tlbsrch   = type_e & e_tlbsrch;
    assign is_invtlb    = type_e & e_invtlb;
    assign is_idle      = type_e & e_idle;
    assign is_cacop     = type_e & e_cacop;
    assign is_ll_w      = type_g & g_ll_w;
    assign is_sc_w      = type_g & g_sc_w;
    assign is_mdu_instr = type_b & (b_mul | b_div_mod);
    //c_immsel
    assign c_immsel[7] = type_h & ~(h_jirl | h_cond_br);
    assign c_immsel[6] = 1'b0;
    assign c_immsel[5] = type_f;
    assign c_immsel[4] = type_h & (h_jirl | h_cond_br);
    assign c_immsel[3] = type_g & ~instr[27];
    assign c_immsel[2] = type_d & instr[24];
    assign c_immsel[1] = (type_d & ~instr[24]) | type_e | (type_g & instr[27]);
    assign c_immsel[0] = type_c;
    //c_alusrc_a
    assign c_alusrc_a  = (type_f & instr[27]) | (type_h & (h_jirl | h_bl));
    //c_alusrc_b
    assign c_alusrc_b[2] = type_h & (h_jirl | h_bl);
    assign c_alusrc_b[1] = type_c | type_d | (type_e & e_cacop)| type_f | type_g;
    assign c_alusrc_b[0] = type_b | (type_e & e_invtlb);
    //c_aluop
    assign c_aluop[12] = type_b & (b_div_mod | b_mul);
    assign c_aluop[11] = type_f & ~instr[27];
    assign c_aluop[10] = (type_c & instr[19]) | (type_b & instr[20] & instr[19] & ~instr[18]) ;
    assign c_aluop[9] =  (type_c & instr[18]) | (type_b & instr[17] & instr[16] & instr[15]) ;
    assign c_aluop[8] = (type_c & ~instr[19] & ~instr[18]) | (type_b & b_sll_w);
    assign c_aluop[7] = (type_b & b_xor) | (type_d & instr[23] & instr[22]);
    assign c_aluop[6] = type_b & b_or | type_d & d_ori | type_e & e_invtlb;
    assign c_aluop[5] = type_b & b_and | type_d & d_andi;
    assign c_aluop[4] = type_b & b_nor;
    assign c_aluop[3] = type_b & b_sltu | type_d & d_sltui;
    assign c_aluop[2] = type_b & b_slt | type_d & d_slti;
    assign c_aluop[1] = type_b & (instr[20:16] == 5'b10001);
    assign c_aluop[0] = type_b & b_add_w | type_d & d_addi_w | type_e & e_cacop | type_f & instr[27] | type_g | type_h;
    //c_mduop
    assign c_mduop[2] = type_b & b_mduop2;
    assign c_mduop[1] = type_b & b_mduop1;
    assign c_mduop[0] = type_b & b_div_mod;
    //c_brop
    assign c_brop[4] = type_h & ~h_cond_br;
    assign c_brop[3] = type_h & instr[26] & ~h_jirl & ~h_bl;
    assign c_brop[2] = type_h & instr[29:27] == 3'b101;
    assign c_brop[1] = type_h & instr[29:27] == 3'b100;
    assign c_brop[0] = type_h & instr[29:27] == 3'b011;

    //c_memwr
    assign c_memwr[2] = type_g & g_st_b;
    assign c_memwr[1] = type_g & g_st_h;
    assign c_memwr[0] = type_g & (g_st_w | g_sc_w);
    //c_memrd
    assign c_memrd[4] = type_g & g_ld_bu;
    assign c_memrd[3] = type_g & g_ld_hu;
    assign c_memrd[2] = type_g & g_ld_b;
    assign c_memrd[1] = type_g & g_ld_h;
    assign c_memrd[0] = type_g & (g_ld_w | g_ll_w);
    //c_wbsel
    assign c_wbsel[3] = type_g & ~instr[24];
    assign c_wbsel[2] = type_a;
    assign c_wbsel[1] = type_e & e_csr | type_g & g_sc_w;
    assign c_wbsel[0] = type_b | type_c | type_d | type_e & ~e_csr | type_f | type_g & ~g_sc_w | type_h;

    //cntsel
    assign c_cntsel[2] = type_a & ~instr[10] & (instr[4:0] == 5'b0);
    assign c_cntsel[1] = type_a &  instr[10];
    assign c_cntsel[0] = type_a & ~instr[10] & (instr[9:5] == 5'b0);

    //c_regwr
    assign c_regwr = ~(type_b & b_break_or_syscall | type_e & ~e_csr | type_g & g_regwne | type_h & h_regwne);

    //c_npcsel
    assign c_npcsel[2] = type_h & h_jirl;
    assign c_npcsel[1] = type_h & ~h_jirl;
    assign c_npcsel[0] = ~type_h;

    //c_rnum_b_sel
    assign c_rnum_b_sel = type_e & e_csrwe | type_g & g_st | type_h & h_cond_br;

    //c_rnum_c_sel
    assign c_rnum_c_sel[2] = type_a & a_rdcntid;
    assign c_rnum_c_sel[1] = type_h & h_bl;
    assign c_rnum_c_sel[0] = ~(type_a & a_rdcntid | type_h & h_bl);
    //c_reg_as_read
    assign c_reg_as_read[2] = type_b | type_c | type_d | (type_e & e_rj_as_read) | type_g | (type_h & h_rj_as_read);
    assign c_reg_as_read[1] = type_b | (type_e & e_invtlb);
    assign c_reg_as_read[0] = (type_e & e_csrwe) | (type_g & g_st) | (type_h & h_cond_br);

    //CSR WRITE MASK
    assign csr_wmask_id = type_e & e_csrwr;

    //c_csrwr
    assign c_csrwr = type_e & e_csrwe;
    
    //refetch，在PMEM级提交后，会刷新流水线，并从下一条指令开始重新取指，避免数据冒险
    assign c_refetch = type_e & ~(e_csrrd | e_tlbsrch | e_ertn | e_idle | e_cacop_not_i);
endmodule
