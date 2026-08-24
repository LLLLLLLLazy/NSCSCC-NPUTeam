`include "mycpu.h"

module decode(
    input  wire [31:0] inst,
    input  wire [31:0] pc,
    input  wire [32:0] adef_data,
    input  wire [5:0] excps,


    output wire [`DE_TO_DS_BUS-1:0] de_to_ds_bus,
    input  wire         ds_has_int,
    input wire pred_taken,
    input wire [31:0] pred_target,
    input wire ds_llbit

);

wire [ 4:0] ldst;
wire [4:0] dest;

    // 1. ָ��ֽ���������� 
    wire [ 5:0] op_31_26  = inst[31:26];
    wire [ 3:0] op_25_22  = inst[25:22];
    wire [ 1:0] op_21_20  = inst[21:20];
    wire [ 4:0] op_19_15  = inst[19:15];

    wire [ 4:0] rd = inst[ 4: 0];
    wire [ 4:0] rj = inst[ 9: 5];
    wire [ 4:0] rk = inst[14:10];

    wire [11:0] i12 = inst[21:10];
    wire [19:0] i20 = inst[24: 5];
    wire [13:0] i14 = inst[23:10];
    wire [15:0] i16 = inst[25:10];
    wire [25:0] i26 = {inst[ 9: 0], inst[25:10]};

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

//exp10
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;


//exp11
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;

//exp12
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;

//exp13
wire        inst_break;
wire        inst_rdcntvl;
wire        inst_rdcntvh;
wire        inst_rdcntid;

// tlb instruction
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

// cacop
wire        inst_cacop;
wire        inst_valid_cacop;
wire        inst_nop;
wire        inst_orn;
wire        inst_andn;
wire        inst_pcaddi;
// cpucfg
wire inst_cpucfg;

wire inst_idle;

wire inst_ll_w;
wire inst_sc_w;

wire inst_dbar;
wire inst_ibar;

wire inst_preld;
wire preld_en;

wire src_no_rj;
wire src_no_rk;
wire src_no_rd;
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

//exp10
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i= op_31_26_d[6'h07] & ~inst[25];
assign inst_mul_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

//exp11
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
//exp12
assign inst_csrrd  = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b00) & (rj == 5'h00);
assign inst_csrwr  = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b00) & (rj == 5'h01);
assign inst_csrxchg= op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b00) & ~inst_csrrd & ~inst_csrwr;
assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0e) & (rj == 5'h00) & (rd == 5'h00);
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

//exp13
assign inst_break    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntvl  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
assign inst_rdcntvh  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);
assign inst_rdcntid  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);

// tlb instruction
assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0a) & (rj == 5'h00) & (rd == 5'h00); 
assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0b) & (rj == 5'h00) & (rd == 5'h00); 
assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0c) & (rj == 5'h00) & (rd == 5'h00); 
assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0d) & (rj == 5'h00) & (rd == 5'h00); 
assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

assign dest         = dst_is_r1 ? 5'd1 : (dst_is_rj ? rj : rd);
assign inst_cacop   = op_31_26_d[6'h01] & op_25_22_d[4'h8];
assign inst_valid_cacop = inst_cacop&&(dest[2:0]==3'b0||dest[2:0]==3'b1)&&(dest[4:3]==2'd0||dest[4:3]==2'd1||dest[4:3]==2'd2);
assign inst_nop = inst_cacop&&((dest[2:0]!=3'b0&&dest[2:0]!=3'b1)||(dest[4:3]==2'd3));

assign inst_cpucfg     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h1b);

assign inst_idle  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_orn   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0c];
assign inst_andn  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0d];
assign inst_pcaddi     = op_31_26_d[6'h06] & ~inst[25];

assign inst_ll_w = op_31_26_d[6'h08] & ~inst[25] & ~inst[24];
assign inst_sc_w = op_31_26_d[6'h08] & ~inst[25] &  inst[24];

assign inst_dbar = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h04];
assign inst_ibar = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h05];

assign inst_preld = op_31_26_d[6'h0a] & op_25_22_d[4'hb];

// 3. �������·��??? (Issue Queue Type)
wire        mem_we;
wire        res_from_mem;
assign  res_from_mem = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ll_w;
assign mem_we     = inst_st_w | inst_st_b | inst_st_h | inst_sc_w;
wire [1:0]  iq_type;
// 0: ALU Queue (����/��֧��), 1: MEM Queue (�ô�)
assign iq_type = (res_from_mem | mem_we) ? 1'b1 : 1'b0;


wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
wire        need_ui12;
wire        need_si22; // ר�Ÿ� pcaddi ��
wire        need_si14;

assign need_si14  =  inst_ll_w | inst_sc_w;
assign need_si22  =  inst_pcaddi;
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui | inst_ld_b 
                     | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h | inst_valid_cacop | inst_preld;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;

wire [31:0] imm;
assign imm = 
             need_si20 ? {i20[19:0], 12'b0}         :
             need_si22 ? {{10{i20[19]}}, i20[19:0], 2'b00} :
             need_si14 ? {{16{i14[13]}}, i14, 2'b0} :
             need_ui5  ?  rk                         :
             need_ui12 ? {20'b0,i12[11:0]}        :
             need_si12 ? {{20{i12[11]}}, i12[11:0]} :
             need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                          {{14{i16[15]}}, i16[15:0], 2'b0} ;  
             
wire        src2_is_imm;            
assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_st_b   |
                       inst_st_h   |
                       inst_b
                       | inst_beq | inst_bne | inst_blt | inst_bge 
                       | inst_bltu | inst_bgeu
                       | inst_valid_cacop
                       |inst_ll_w | inst_sc_w | inst_preld;
                       
wire [29:0] alu_op;
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_ld_b
                    | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h
                    | inst_valid_cacop 
                    | inst_ll_w | inst_sc_w | inst_preld;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w; //37
assign alu_op[16] = inst_mod_w;
assign alu_op[17] = inst_div_wu;
assign alu_op[18] = inst_mod_wu;
assign alu_op[19] = inst_jirl;
assign alu_op[20] = inst_b;
assign alu_op[21] = inst_bl;
assign alu_op[22] = inst_beq;
assign alu_op[23] = inst_bne;
assign alu_op[24] = inst_blt;
assign alu_op[25] = inst_bge;
assign alu_op[26] = inst_bltu;
assign alu_op[27] = inst_bgeu;
assign alu_op[28] = inst_orn;
assign alu_op[29] = inst_andn;

wire [2:0] load_op;
assign load_op = inst_ld_b ? 3'b001 : inst_ld_bu ? 3'b010 : 
                 inst_ld_h ? 3'b011 : inst_ld_hu ? 3'b100 : 
                 inst_ld_w | inst_ll_w ? 3'b101 : 3'b000;
wire   [1:0]   store_op;  
assign store_op = inst_st_b ? 2'b01 : (inst_st_h ? 2'b10 : (inst_st_w | inst_sc_w ? 2'b11 : 2'b00));

wire [4:0] invtlb_op;
assign invtlb_op  = rd;

wire [129:0] ds_exception;
//csr��ʹ�ܣ�дʹ�ܣ�д���룬д���ݣ�д��ַ
wire        csr_re;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [13:0] csr_num;
//exp13
wire [  5:0] ds_ecode;
wire [  8:0] ds_esubcode;

wire         ds_adef;
wire [ 31:0] ds_wrong_addr;
wire         ds_ine;
wire         ds_ertn;
wire         ds_ex;
wire [  1:0] time_op;

assign {ds_adef, ds_wrong_addr} = adef_data;
assign csr_re     = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid | inst_cpucfg;
assign csr_we     = inst_csrwr | inst_csrxchg;
assign csr_wmask  = {32{inst_csrwr}};
assign csr_wvalue = 32'b0;
assign csr_num = inst_idle ? 14'h3FFF : ({14{inst_rdcntid}} & `CSR_TID | {14{~inst_rdcntid}} & inst[23:10]);
assign ds_ine      = ~(inst_add_w     | inst_sub_w   | inst_slt     | inst_sltu      |
                       inst_nor       | inst_and     | inst_or      | inst_xor       |   
                       inst_slli_w    | inst_srli_w  | inst_srai_w  | inst_addi_w    | 
                       inst_ld_w      | inst_st_w    | inst_jirl    | inst_b         |
                       inst_bl        | inst_beq     | inst_bne     | inst_lu12i_w   |
                       inst_slti      | inst_sltui   | inst_andi    | inst_ori       | 
                       inst_xori      | inst_sll_w   | inst_srl_w   | inst_sra_w     |
                       inst_mul_w     | inst_mulh_w  | inst_mulh_wu | inst_div_w     | 
                       inst_mod_w     | inst_div_wu  | inst_mod_wu  | inst_pcaddu12i |
                       inst_blt       | inst_bge     | inst_bltu    | inst_bgeu      | 
                       inst_ld_b      | inst_ld_h    | inst_ld_bu   | inst_ld_hu     |
                       inst_st_b      | inst_st_h    | inst_csrrd   | inst_csrwr     |
                       inst_csrxchg   | inst_ertn    | inst_syscall | inst_break     |
                       inst_rdcntvl   | inst_rdcntvh | inst_rdcntid | inst_tlbsrch   |
                       inst_tlbrd     | inst_tlbwr   | inst_tlbfill | inst_invtlb    |
                       inst_valid_cacop | inst_cpucfg | inst_idle |inst_orn          |
                       inst_andn | inst_pcaddi | inst_ll_w | inst_sc_w | inst_preld  |
                       inst_dbar | inst_ibar | inst_nop)                             |
                       inst_invtlb & (invtlb_op > 5'd6);

assign ds_ex       =  (inst_syscall | inst_break | ds_ine | ds_has_int | ds_adef | |excps);
assign ds_ecode    = ds_has_int   ? `ECODE_INT
                   : ds_adef      ? `ECODE_ADE
                   : excps[0]     ? `ECODE_TLBR
                   : excps[3]     ? `ECODE_PIF
                   : excps[1]     ? `ECODE_PPI
                   : ds_ine       ? `ECODE_INE
                   : inst_break   ? `ECODE_BRK
                   : inst_syscall ? `ECODE_SYS : 6'b0;
assign ds_esubcode = ds_adef ? `ESUBCODE_ADEF : 9'b0;
assign time_op     = {inst_rdcntvh, inst_rdcntvl}; 

assign ds_exception = {csr_re, csr_we, csr_wmask, csr_wvalue, csr_num, ds_ex, inst_ertn, 
                       ds_adef, ds_wrong_addr, ds_ecode, ds_esubcode};
wire need_rj;
wire need_rk;
wire need_rd;
wire need_imm;
wire need_pc;
assign need_rj = ~(inst_b | inst_bl | inst_lu12i_w | inst_pcaddu12i | inst_csrrd | inst_csrwr|inst_pcaddi | inst_dbar | inst_ibar | inst_nop);
assign need_rk = ~(inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | 
                 inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w |inst_slti | inst_sltui | inst_andi | 
                 inst_ori | inst_xori | inst_pcaddu12i | inst_blt |inst_bge | inst_bltu | inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu|
                 inst_ld_hu | inst_st_b | inst_st_h|inst_csrrd|inst_csrwr|inst_csrxchg | inst_valid_cacop | inst_cpucfg | inst_pcaddi |
                 inst_dbar | inst_ibar | inst_preld | inst_ll_w  | inst_sc_w | inst_nop);
assign need_rd = inst_beq | inst_bne | inst_st_w | inst_blt | inst_bge
                 | inst_bltu | inst_bgeu | inst_st_b | inst_st_h| inst_csrwr | inst_csrxchg | inst_sc_w;
assign need_pc = inst_jirl |inst_b |inst_bl |inst_beq |inst_bne | inst_pcaddu12i |inst_blt |inst_bge |inst_bltu|
                 inst_bgeu| inst_pcaddi;
assign need_imm = inst_slli_w |inst_srli_w |inst_srai_w |inst_addi_w |inst_ld_w   |inst_st_w   |
                  inst_lu12i_w|inst_jirl   |inst_bl     |inst_slti   |inst_sltui  |
                  inst_andi   | inst_ori    |inst_xori   |inst_pcaddu12i |inst_ld_b   |
                  inst_ld_h   | inst_ld_bu  | inst_ld_hu  |inst_st_b   | inst_st_h   |
                  inst_b | inst_beq | inst_bne | inst_blt | inst_bge| inst_bltu | inst_bgeu| inst_pcaddi |
                  inst_ll_w  | inst_sc_w | inst_preld | inst_valid_cacop;
wire   dst_is_r1;
wire   dst_is_rj;
assign dst_is_r1 = inst_bl;
assign dst_is_rj = inst_rdcntid;
wire    rf_we;
assign ldst    = rf_we ? (dst_is_r1 ? 5'd1 : (dst_is_rj ? rj : rd)) : 5'd0;
assign rf_we   = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_st_b & ~inst_st_h & ~inst_syscall & ~inst_ertn &
                 ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb & ~inst_valid_cacop & ~inst_dbar & ~inst_ibar & ~inst_preld & ~inst_nop;
wire [4:0] lrs1;
wire [4:0] lrs2;
assign  lrs1 = need_rj ? rj : 5'b0;
assign  lrs2 = need_rk ? rk :
               need_rd ? rd : 5'b0;
               
wire   inst_is_mem_priv;
assign inst_is_mem_priv = inst_ld_w | inst_st_w | inst_ld_b | inst_ld_h |inst_ld_bu | inst_ld_hu |
                          inst_st_h | inst_st_b | inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn |
                          inst_syscall | inst_break | inst_rdcntvl | inst_rdcntid |
                          ds_ine | ds_has_int | ds_adef | inst_tlbsrch | inst_tlbrd |
                          inst_tlbwr | inst_tlbfill | inst_invtlb | |excps | inst_valid_cacop | inst_cpucfg | inst_idle |
                          inst_ll_w | inst_sc_w | inst_dbar | inst_ibar | inst_preld;
wire ds0_is_branch = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                         inst_b | inst_bl | inst_jirl;

    // 2. �ô��� (Load/Store)
    // �������еĶ�д�ڴ����???
wire ds0_is_load   = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ll_w;
wire ds0_is_store  = inst_st_w | inst_st_b | inst_st_h | inst_sc_w;
wire ds0_is_mem    = ds0_is_load | ds0_is_store;

    // 3. ��Ȩ���쳣�� (Privilege / System)
    // ������д CSR��ϵͳ���á��ϵ㡢���쳣���ء�TLB�������Լ���ʱ����ȡ
wire ds0_is_priv   = inst_csrrd | inst_csrwr | inst_csrxchg | 
                         inst_syscall | inst_break | inst_ertn |
                         inst_rdcntvl | inst_rdcntvh | inst_rdcntid |
                         inst_tlbsrch | inst_tlbrd | inst_tlbwr |
                         inst_tlbfill | inst_invtlb | inst_valid_cacop |
                         inst_cpucfg | inst_idle | inst_ll_w | inst_sc_w |
                         inst_dbar | inst_ibar;

wire rename_is_complex_0 = ds0_is_priv;
wire [1:0] br_type;
wire isRet;
wire isCall;

assign isRet = inst_jirl &&
               (inst[4:0]   == 5'd0) &&
               (inst[9:5]   == 5'd1) &&
               (inst[25:10] == 16'd0);

assign isCall = inst_bl || (inst_jirl && (inst[4:0] == 5'd1));
    assign br_type = isCall ? 2'b01 :
                     isRet ? 2'b10 :
                 inst_b | inst_bl | inst_jirl ? 2'b00 :
                 2'b11;
wire inst_pc_add = inst_pcaddu12i | inst_pcaddi;

assign preld_en = inst_preld && ((dest == 5'd0) || (dest == 5'd8));
assign de_to_ds_bus = { inst_idle,
                        inst,
                        preld_en,
                        inst_dbar,
                        inst_ibar,
                        inst_sc_w,
                        inst_ll_w,
                        br_type,        //2
                        inst_cpucfg,     //1
                        inst_valid_cacop, //1
                        dest,          //5
                        inst_tlbsrch,    //1
                        inst_tlbrd,     //1
                        inst_tlbwr,     //1
                        inst_tlbfill,   //1
                        inst_invtlb,    //1
                        invtlb_op,      //5
                       pred_taken,   //294
                       pred_target,   //293
                       inst_csrxchg,  //261
                      // inst_pcaddu12i,
                       inst_pc_add,
                       ds0_is_store,
                       rename_is_complex_0,
                       inst_is_mem_priv,
                       alu_op       ,   // 30 256
                       need_rj      ,   //1
                       need_rk      ,//1  30  225
                       need_rd      , //1
                       need_pc      , //1
                       need_imm     ,//1
                       ldst         ,//5       221
                       lrs1         ,//5        
                       lrs2         ,//5    
                       load_op      ,   // 3    206
                       store_op     ,  //2
                       rf_we        ,   // 1 
                       mem_we       ,   // 1  
                       imm          ,   // 32  199
                       pc           ,    // 32  
                       res_from_mem ,//1  
                       ds_exception ,//130  
                       time_op      ,//2
                       iq_type//2     
                    };

endmodule
