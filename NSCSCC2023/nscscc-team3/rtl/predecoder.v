`include "header.v"
/*
    指令译码第一阶段，位于IF级，改善ID级时序用
*/
module predecoder(
    input   [31:0]                    instr,
    output  [`WIDTH_PDC_BUS-1:0]      predecode_bus
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
    //中间值
    wire          type_b_p1;
    wire          type_b_p2;
    wire          g_ine_p1;
    wire          g_ine_p2;
    wire          g_ine_p3;
    wire          g_ine_p4;
    wire          g_ine_p5;
    wire          b_ine_p3;
    wire          b_ine_p4;
    wire          b_ine_p5;
    wire          b_ine_p6;
    wire          b_ine_p7;
    wire          b_ine_p8;
    wire          b_ine_p9;
    wire          a_ine_p1;
    wire          a_ine_p2;
    wire          a_ine_p3;
    assign        predecode_bus = {
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
    };
    /* * 
        指令译码第一部分
    */
    assign type_a       = instr[31:20] == 12'b0;
    /*
        CARRY4->CARRY4 -> |
        LUT5           -> | LUT2  
    */
    assign type_b_p1    = instr[31:24] == 8'b0;
    assign type_b_p2    = ~instr[23] & ~instr[22] & (instr[21] | instr[20]);
    assign type_b       = type_b_p1 & type_b_p2;
    assign type_c       = (instr[31:23] == 9'b0) & instr[22];
    assign type_d       = (instr[31:26] == 6'b0) & instr[25];
    assign type_e       = (instr[31:27] == 5'b0) & instr[26];
    assign type_f       = (instr[31:29] == 3'b0) & instr[28];
    assign type_g       = (instr[31:30] == 2'b0) & instr[29];
    assign type_h       = ~instr[31] & instr[30];
    assign a_rdcntid    = ~instr[10] & instr[4:0] == 5'b00000;
    assign a_ine_p1     = {instr[14:10],instr[4:0]} == 10'b1100000000;
    assign a_ine_p2     = {instr[14:10],instr[9:5]} == 10'b1100000000;
    assign a_ine_p3     = {instr[14:10],instr[9:5]} == 10'b1100100000;
    assign a_ine        = ~(a_ine_p1 | a_ine_p2 | a_ine_p3);
    assign b_break_or_syscall = instr[21] & instr[19];
    assign b_syscall    = instr[21] & instr[19] & instr[16];
    assign b_break      = instr[21] & instr[19] & ~instr[16];
    assign b_mul        = instr[20] & instr[19] & instr[18];
    assign b_div_mod    = instr[21] & ~instr[19];
    assign b_add_w      = instr[20:16] == 5'b10000;
    assign b_sll_w      = instr[18:15] == 4'b1110;
    assign b_xor        = instr[18:15] == 4'b1011;
    assign b_or         = instr[20:15] == 6'b101010;
    assign b_and        = instr[20:15] == 6'b101001;
    assign b_nor        = instr[19:15] == 5'b01000;
    assign b_sltu       = instr[18:15] == 4'b0101;
    assign b_slt        = instr[19:15] == 5'b00100;
    assign b_mduop2     = (instr[19] & instr[18] & (instr[16] | instr[15])) | (~instr[20] & instr[15]);
    assign b_mduop1     = (instr[20] & instr[19] | instr[21]) & instr[16];
    assign b_ine_p1     = {instr[21:17],instr[15]} == 6'b101010;
    assign b_ine_p2     = instr[21:17] == 6'b10000;
    assign b_ine_p3     = instr[21:19] == 3'b010;
    assign b_ine_p4     = {instr[18:17],instr[15]} == 3'b001;//0110,0111
    assign b_ine_p5     = instr[18:16] == 3'b011;            //1100,1101
    assign b_ine_p6     = instr[18:16] == 3'b110;
    assign b_ine_p7     = instr[21:19] == 3'b011;
    assign b_ine_p8     = instr[18:15] == 4'b0000;
    assign b_ine_p9     = (instr[18:17] == 2'b10) & (instr[16:15]!=2'b11);
    assign b_ine_p10     = (b_ine_p3 & ~(b_ine_p4 | b_ine_p5 | b_ine_p6));
    assign b_ine_p11     = (b_ine_p7 & (b_ine_p8 | b_ine_p9));
    assign c_ine        = ({instr[21:20],instr[17:15]} != 5'b00001) | (instr[19:18] == 2'b11);
    assign d_ori        = instr[24:22] == 3'b110;
    assign d_andi       = instr[24:22] == 3'b101;
    assign d_sltui      = instr[24:22] == 3'b001;
    assign d_slti       = instr[24:22] == 3'b000;
    assign d_addi_w     = instr[24:22] == 3'b010;
    assign d_ine        = (instr[24:22] == 3'b100)  | (instr[24:22] == 3'b011);
    assign e_csrrd      = ~instr[25] & ~instr[9] & ~instr[8] & ~instr[7] & ~instr[6] & ~instr[5];
    assign e_csrwe      = ~instr[25] & (instr[9] | instr[8] | instr[7] | instr[6] | instr[5]);
    assign e_csrwr      = ~instr[25] & ~instr[9] & ~instr[8] & ~instr[7] & ~instr[6] & instr[5];
    assign e_csr        = ~instr[25] & ~instr[24];
    assign e_cacop      = instr[25] & ~instr[22];
    assign e_tlbsrch    = instr[25] & instr[22] & ~instr[15] & (instr[12:10] == 3'b010);
    assign e_tlbrd      = instr[25] & instr[22] & ~instr[15] & (instr[12:10] == 3'b011);
    assign e_tlbwr      = instr[25] & instr[22] & ~instr[15] & (instr[12:10] == 3'b100);
    assign e_tlbfill    = instr[25] & instr[22] & ~instr[15] & (instr[12:10] == 3'b101);
    assign e_ertn       = instr[25] & instr[22] & ~instr[15] & (instr[12:10] == 3'b110);
    assign e_idle       = instr[25] & instr[22] & ~instr[16] & instr[15];
    assign e_invtlb     = instr[25] & instr[22] & instr[16];
    assign e_invtlb_invop = ((&instr[2:0]) | (|instr[4:3]));
    assign e_rj_as_read = (~instr[25] & (instr[9] | instr[8] | instr[7] | instr[6])) | (instr[25] & (~instr[22] | instr[16]));
    assign e_cacop_not_i= instr[25] & ~instr[22] & ~instr[2] & (instr[1] | instr[0]); 
    assign e_ine_p1     = instr[25:24] == 2'b00;
    assign e_ine_p2     = instr[25:22] == 4'b1000;
    assign e_ine_p3     = instr[25:14] == 12'b100100100000;
    assign e_ine_p4     = instr[9:0]   ==  10'b0000000000;
    assign e_ine_p5     = (instr[12] | instr[11]) & ~(instr[12] & instr[11] & instr[10]) & instr[13];
    assign e_ine_p6     = {instr[25:17],instr[15]}  ==  10'b1001001001;
    assign f_ine        = instr[26:25] != 2'b10;
    assign g_st         = instr[24];
    assign g_ll_w       = ~instr[27] & ~instr[24];
    assign g_sc_w       = ~instr[27] & instr[24];
    assign g_st_b       = instr[27:22] == 6'b100100;
    assign g_st_h       = instr[27:22] == 6'b100101;
    assign g_st_w       = instr[27:22] == 6'b100110;
    assign g_ld_b       = instr[27:22] == 6'b100000;
    assign g_ld_h       = ~instr[28] & instr[27] & instr[25:22] == 4'b0001;
    assign g_ld_w       = instr[27:22] == 6'b100010;
    assign g_ld_bu      = instr[27:22] == 6'b101000;
    assign g_ld_hu      = instr[27:22] == 6'b101001;
    assign g_regwne     = instr[27] & (instr[24] | instr[23] & instr[22] | instr[28]);
    /*
        CARRY4            ->|
        LUT6              ->|
        LUT6              ->| 
        CARRY4  -> CARRY4 ->| LUT6
        LUT5              ->|
        REG               ->|      
    */
    assign g_ine_p1     = instr[28:25] == 4'b0000;   //CARRY4
    assign g_ine_p2     = (instr[28:25] == 4'b0100) & ~(instr[23] & instr[22]); //LUT6
    assign g_ine_p3     = (instr[28:25] == 5'b0101) & ~(instr[23] & ~instr[22]);//LUT6 此处还少判一个24，在g_ine中判
    assign g_ine_p4     = instr[28:21] == 8'b11000011; //CARRY4*2 ？
    assign g_ine_p5     = instr[20:16] == 5'b10010;    //LUT5
    assign g_ine        = ~(g_ine_p1 | g_ine_p2 | g_ine_p3 & ~instr[24] | g_ine_p4 & g_ine_p5);//LUT6
    assign h_cond_br    = (instr[28] & instr[27]) | instr[29];
    assign h_jirl       = ~instr[29] & ~instr[28];
    assign h_bl         = ~instr[29] & instr[28] & ~instr[27] & instr[26];
    assign h_rj_as_read =  (~instr[29] & ~instr[28]) | (instr[28] & instr[27] | instr[29]);
    assign h_regwne     = (instr[28] & instr[27] | instr[29]) | ~instr[26];
    assign h_ine        =  ~((instr[29:26] == 4'b0011) | (instr[29] ^ instr[28]));
    
endmodule
