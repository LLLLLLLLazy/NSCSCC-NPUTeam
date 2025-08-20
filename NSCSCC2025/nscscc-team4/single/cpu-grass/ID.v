`include "header.h"
module ID (
    input           clk,
    input           reset,
    input           has_int,
    input [31:0]    csr_tlbehi_rvalue,

    //控制信号
    input                                   EX_stall,
    input                                   MEM_stall,
    input                                   flush,
    input                                   taken, //由于idle存在，taken和flush不能合并
    input [`WIDTH_EX1_FORWARD_BUS- 1 : 0]   EX1_forward_bus,
    input [`WIDTH_EX2_FORWARD_BUS- 1 : 0]   EX2_forward_bus,
    input [`WIDTH_MEM_FORWARD_BUS- 1 : 0]   MEM_forward_bus,    
    input [ 1:0]                            csr_plv,
    input                                   IF_ID_valid,
    input [`WIDTH_IF_ID_BUS - 1 : 0]        IF_ID_bus,
    input                                   ID_llbit,

    output                                  ID_EX1_valid,
    output                                  ID_stall,
    output [`WIDTH_ID_EX1_BUS - 1 : 0]      ID_EX1_bus,

    //寄存器堆操作
    output [ 4:0] rf_raddr1,
    output [ 4:0] rf_raddr2,
    input  [31:0] rf_rdata1,
    input  [31:0] rf_rdata2


`ifdef DIFFTEST_EN
    ,
    output [`DIFF_WIDTH_ID_EX1_BUS -1 : 0] ID_EX1_diff_bus
`endif

);
    wire [31:0] ID_data_vaddr;
    wire [18:0] s1_vppn;
    wire [31:0] alu_src1;
    reg  [31:0] alu_src2;

    //inst
    wire [31:0] ID_pc;
    wire [31:0] inst;
    wire [9:0] offs_25_16;
    wire [5:0] op_31_26;
    wire [3:0] op_25_22;
    wire [1:0] op_21_20;
    wire [4:0] op_19_15;
    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    //rj, rd, rk类型
    wire  inst_add_w;
    wire  inst_sub_w;
    wire  inst_and;
    wire  inst_or;
    wire  inst_xor;
    wire  inst_nor;
    wire  inst_slt;
    wire  inst_sltu;
    wire  inst_sll_w;
    wire  inst_srl_w;
    wire  inst_sra_w;
    wire  inst_mul_w;
    wire  inst_mulh_w;
    wire  inst_mulh_wu;
    wire  inst_div_w;
    wire  inst_div_wu;
    wire  inst_mod_w;
    wire  inst_mod_wu;
    //立即数操作类型
    //si12
    wire  inst_ld_w;
    wire  inst_ld_b;
    wire  inst_ld_h;
    wire  inst_ld_bu;
    wire  inst_ld_hu;
    wire  inst_st_b;
    wire  inst_st_h;
    wire  inst_st_w;
    wire  inst_addi_w;
    wire  inst_slti;
    wire  inst_sltui;
    //ui12
    wire  inst_andi;
    wire  inst_ori;
    wire  inst_xori;
    //ui5
    wire  inst_slli_w;
    wire  inst_srli_w;
    wire  inst_srai_w;
    //si20    
    wire  inst_lu12i_w;
    wire  inst_pcaddu12i;
    //si14
    wire  inst_ll_w;
    wire  inst_sc_w;
    
    //跳转指令类型
    wire  inst_bne;
    wire  inst_b;
    wire  inst_beq;
    wire  inst_bl;
    wire  inst_jirl;
    wire  inst_blt;
    wire  inst_bge;
    wire  inst_bltu;
    wire  inst_bgeu;
    //TLB处理指令
    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire inst_invtlb;
    wire [4:0] invtlb_op;
    //cache维护指令
    wire inst_cacop;
    wire [4:0] cacop_code;
    wire inst_cacop_valid;  //cacop有效信号,该指令是否有效放在ID中判断比较方便
    wire inst_cpucfg;
    wire inst_idle;
    wire inst_preld;
    //dbar,ibar
    wire inst_dbar;
    wire inst_ibar;
    //异常处理
    wire  inst_csrrd;
    wire  inst_csrwr;
    wire  inst_csrxchg;
    wire  inst_ertn;
    wire  inst_rdcntvl_w;
    wire  inst_rdcntvh_w;
    wire  inst_rdcntid;
    wire  inst_syscall;
    wire  inst_break;

    wire inst_nop;

    //中断异常信号
    wire ID_excp;
    wire [14:0] ID_excp_num;       // 位数待定
    wire [14:0] excp_num;
 
    //csr相关信号
    wire  [13:0] csr_num;
    wire  csr_we;   
    wire  csr_w_mask;
    wire  dst_is_rj;
    wire  [2:0] rdcnt_en;
    wire  excp_ine;
    wire  excp_ipe;
    wire  excp_ale;
    wire  kernel_inst;

    //数据
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] sign_imm_12;  //有符号12位立即数
    wire [11:0] unsign_imm_12;//无符号12位立即数
    wire [19:0] sign_imm_20;  //有符号20位立即数
    wire [ 4:0] unsign_imm_5; //无符号5位立即数
    wire [13:0] sign_imm_14;  //有符号14位立即数

    //前递
    wire [4:0]  EX1_dest;
    wire [4:0]  EX2_dest;
    wire [4:0]  MEM_dest;

    wire EX1_data_not_prepared;
    wire MEM_data_not_prepared;


    wire [31:0] EX1_data;
    wire [31:0] MEM_data;

    wire need_rj;
    wire need_rk;
    wire need_rd;
    wire need_rkd;
    wire rj_not_zero;
    wire rkd_not_zero;

    //流水线控制
    reg ID_valid; //id stage 中是否含有效的指令
    reg [`WIDTH_IF_ID_BUS - 1 : 0] IF_ID_reg;
    wire same_reg;
    wire stall;
    wire stall_forward;
    wire stall_data_hazard; //数据冒险导致的stall

    // //分支预测
    wire btb_miss;
    wire pred_taken;
    wire [31:0] pred_target;
    // wire taken; 
    // wire [31:0] target;

    //控制信号
    wire [18:0] ALU_op;       //ALU操作信号12位（独热码）
    wire [ 4:0] extend_op;    //立即数扩展类型选择信号    001为有符号12位扩展，010选择无符号5位扩展，100选择指令lu12i指令的扩展
    wire [31:0] extend_res;   //扩展后立即数
    wire [4:0]  dest;         //写回地址,bl指令时为0000_1 
    wire [2:0]  sel_alu_src2; //寄存器read data2选择器信号   001选择read data2中的数据,010选择立即数，100选择4
    wire        sel_alu_res;  //alu结果选择信号，1选择data ram中读出的数据
    wire [2:0]  sel_alu_src1; //高电平时选择jirl的pc信号， 低电平时选择read data1中的数据
    wire        gr_we;        //寄存器写使能信号
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] rdata_rj;
    wire [31:0] rdata_rkd;
    wire [8:0]  br_op;        //跳转指令类型信号（独热码）
    wire [15:0] offs_15_0;    //跳转信号16位立即数
    wire [25:0] offs_26;      //b和bl信号10位立即数和16位立即数拼接结果
    wire sel_rf_ra2;           //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
    // wire br_taken;             //跳转执行信号，高电平有效
    // wire [31:0] br_target;     //跳转地址目标
    wire [ 4:0] res_from;
    wire [ 2:0] mem_type;
    //跳转指令判断
    wire s_rj_smaller_rd;  
    wire us_rj_smaller_rd;
    wire rj_equal_rd;

    /* ID_EX1_bus总线结构说明（220位宽）
 * 
 * 信号分组说明：
 * [0] cache相关控制信号 (共9位)
 * [1] CSR相关控制信号 (42位)
 * [2] 控制信号 (17位)
 * [3] 寄存器操作信号 (69位)
 * [4] 扩展后立即数 (32位)
 * [5] ALU操作码 (19位)
 * [7] PC值 (32位)
 */
    assign ID_EX1_bus = {
        alu_src1,
        alu_src2,
        s1_vppn,
        ID_data_vaddr,
        // branch 69
        br_op,       //9
        offs_26,     //26
        btb_miss,    //1
        pred_taken,  //1
        pred_target, //32
        //==============================================================
        // 组0: cache相关控制信号 (共9位)   
        //==============================================================
        inst_preld,        // [219]
        inst_ll_w,         // [218]
        inst_sc_w,         // [217]
        inst_cacop_valid,  // [216]     cacop指令有效信号,高电平有效
        cacop_code,        // [215:211] cacop指令的code
        //==============================================================
        // 组1: CSR相关控制信号 (共42位)
        //==============================================================
        inst_invtlb,       // [210]
        invtlb_op,         // [209:205]
        inst_tlbwr,        // [204]
        inst_tlbfill,      // [203]
        inst_tlbsrch,      // [202]
        inst_tlbrd,        // [201]
        ID_excp_num,       // [200:186]
        inst_ertn,         // [185]    ertn信号
        ID_excp,           // [184]    异常信号  
        csr_we,            // [183]    CSR写使能
        csr_num,           // [182:169]CSR地址（14位）
        
        //==============================================================
        // 组2: 控制信号 (共17位)
        //==============================================================
        res_from,          // [168:164] 00000-选ALU结果 00001-选存储器数据 00010-选csr数据 00100~10000等价于之前的rdcnt_en出现该信号时，注意要写入rd或者rj的值为rdcnt_result
        gr_we,             // [163]    寄存器写使能
        sel_alu_src1,      // [162:160]    跳转指令标志 (1-jirl/bl指令)
        load_op,           // [159]    load类指令执行
        store_op,          // [158]    store类指令执行
        sel_alu_src2,      // [157:155]ALU源2选择 (3位)
        mem_type,          // [154:152]访存类型 (3位) 

        //============================================================== 
        // 组3: 寄存器操作信号 (共69位)
        //==============================================================
        dest,              // [151:147]目标寄存器地址 (5位)
        rdata_rkd,         // [146:115]处理后的寄存器读数据2 (32位)
        rdata_rj,          // [114:83]处理后的寄存器读数据1 (32位)

        //==============================================================
        // 组4: 立即数扩展控制 (32位)
        //==============================================================
        extend_res,        // [82:51]   扩展后的立即数

        //==============================================================
        // 组5: ALU操作码 (19位)
        //==============================================================
        ALU_op,            // [50:32]  ALU操作码 (独热码编码)

        //==============================================================
        // 组6: PC值 (32位)
        //==============================================================
        ID_pc              // [31:0]   当前指令PC值
    };

    //译码处理
    assign op_31_26 = inst[31:26];
    assign op_25_22 = inst[25:22];
    assign op_21_20 = inst[21:20];
    assign op_19_15 = inst[19:15];
    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

    //TODO 操作类型信号
    //rj, rd, rk类型
    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    //立即数操作类型
    //si12
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    //ui12
    assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    //ui5
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11]; 
    //si20
    assign inst_lu12i_w= op_31_26_d[6'h05] & (~inst[25]);
    assign inst_pcaddu12i = op_31_26_d[6'h07] & (~inst[25]);
    //si14
    assign inst_ll_w      = op_31_26_d[6'h08] & (inst[25:24] == 2'b00);
    assign inst_sc_w      = op_31_26_d[6'h08] & (inst[25:24] == 2'b01);

    //跳转指令类型
    //br_op的独热码顺序也是按这个顺序
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_blt    = op_31_26_d[6'h18];
    assign inst_bge    = op_31_26_d[6'h19];
    assign inst_bltu   = op_31_26_d[6'h1a];
    assign inst_bgeu   = op_31_26_d[6'h1b];

    //TLB指令处理
    assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (inst[14:10] == 5'b0_1010) & (rj == 5'b0_0000) & (rd == 5'b0_0000);
    assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (inst[14:10] == 5'b0_1011) & (rj == 5'b0_0000) & (rd == 5'b0_0000);
    assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (inst[14:10] == 5'b0_1100) & (rj == 5'b0_0000) & (rd == 5'b0_0000);
    assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (inst[14:10] == 5'b0_1101) & (rj == 5'b0_0000) & (rd == 5'b0_0000);
    assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

    //cache维护指令
    assign inst_cacop   = op_31_26_d[6'h01] & op_25_22_d[4'h8];
    assign cacop_code   = inst[4:0];
    assign inst_cacop_valid = inst_cacop & 
                            (cacop_code[2:0] == 3'b000 | cacop_code[2:0] == 3'b001) &       //暂时不需要实现code[2:0]=2 表示操作二级共享混合 Cache(应该?)
                            (cacop_code[4:3] == 2'b00 | cacop_code[4:3] == 2'b01 | cacop_code[4:3] == 2'b10);   //详细内容见手册P44
    assign inst_nop = inst_cacop & cacop_code[2:0] == 3'b010;
    assign inst_cpucfg     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'b11011);
    assign inst_idle       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_preld      = op_31_26_d[6'h0a] & op_25_22_d[4'hb];
    //dbar,ibar
    assign inst_dbar       = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h04];
    assign inst_ibar       = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h05]; 
    //异常处理指令译码
    assign inst_csrrd  = op_31_26_d[6'h01] & (inst[25] == 0) & (inst[24] == 0) & (rj == 5'b0_0000);
    assign inst_csrwr  = op_31_26_d[6'h01] & (inst[25] == 0) & (inst[24] == 0) & (rj == 5'b0_0001);
    assign inst_csrxchg= op_31_26_d[6'h01] & (inst[25] == 0) & (inst[24] == 0) & (rj != 5'b0_0001 & rj != 5'b0_0000);
    assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (inst[14:10] == 5'b0_1110);
    assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (inst[14:10] == 5'b1_1000) & (inst[9:5] == 5'b0_0000) & (inst[4:0] != 5'b0_0000);
    assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (inst[14:10] == 5'b1_1001) & (inst[9:5] == 5'b0_0000);
    assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (inst[14:10] == 5'b1_1000) & (inst[4:0] == 5'b0_0000);
    
    //部分常用指令
    assign rd          = inst[4:0];
    assign rj          = inst[9:5];
    assign rk          = inst[14:10];
    assign sign_imm_12 = inst[21:10];
    assign unsign_imm_12=inst[21:10];
    assign sign_imm_20 = inst[24:5];
    assign unsign_imm_5= inst[14:10];
    assign sign_imm_14 = inst[23:10];
    assign offs_15_0   = inst[25:10];
    assign offs_25_16  = inst[9:0];
    assign offs_26     = {offs_25_16, offs_15_0};

    //ALU操作译码
    assign ALU_op[0]   = inst_add_w | inst_addi_w |
                        inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h |
                        inst_jirl | inst_bl | inst_pcaddu12i | 
                        inst_csrwr | inst_csrxchg |
                        inst_cacop_valid | inst_ll_w | inst_sc_w | inst_preld;
    assign ALU_op[1]   = inst_sub_w;
    assign ALU_op[2]   = inst_slt | inst_slti;
    assign ALU_op[3]   = inst_sltu | inst_sltui;
    assign ALU_op[4]   = inst_and | inst_andi;
    assign ALU_op[5]   = inst_nor;
    assign ALU_op[6]   = inst_or | inst_ori;
    assign ALU_op[7]   = inst_xor |inst_xori;
    assign ALU_op[8]   = inst_slli_w | inst_sll_w;
    assign ALU_op[9]   = inst_srli_w | inst_srl_w;
    assign ALU_op[10]  = inst_srai_w | inst_sra_w;
    assign ALU_op[11]  = inst_lu12i_w;
    assign ALU_op[12]  = inst_mul_w;
    assign ALU_op[13]  = inst_mulh_w;
    assign ALU_op[14]  = inst_mulh_wu;
    assign ALU_op[15]  = inst_div_w;
    assign ALU_op[16]  = inst_div_wu;
    assign ALU_op[17]  = inst_mod_w;
    assign ALU_op[18]  = inst_mod_wu;

    // alu选择信号
    assign sel_alu_src1   = (inst_csrwr | inst_csrxchg) ? 3'b100 : ((inst_jirl | inst_bl | inst_pcaddu12i) ? 3'b010 : 3'b001);
    assign sel_alu_src2[0]= inst_add_w | inst_sub_w | inst_slt | inst_sltu | 
                            inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu |
                            inst_and | inst_or | inst_xor | inst_nor |
                            inst_sll_w | inst_sra_w | inst_sra_w;  
    assign sel_alu_src2[1]= inst_addi_w | inst_ld_w | inst_ld_h | inst_ld_b | inst_ld_hu | inst_ld_bu | inst_st_w | inst_st_b | inst_st_h | inst_slli_w |
                            inst_srai_w | inst_srli_w | inst_lu12i_w | inst_pcaddu12i | inst_slti | inst_sltui |
                            inst_andi | inst_ori | inst_xori |
                            inst_cacop_valid | inst_ll_w | inst_sc_w | inst_preld;
    assign sel_alu_src2[2]= inst_jirl | inst_bl;

    assign res_from[0] = inst_ld_w | inst_ld_h | inst_ld_b | inst_ld_hu | inst_ld_bu | inst_ll_w;   //选择内存中取出的数
    assign res_from[1] = inst_csrrd | inst_csrwr | inst_csrxchg | inst_cpucfg | inst_sc_w;  //使用csr中的数据
    assign res_from[2] = inst_rdcntid; //出现rdcnt类信号标志，出现该信号时，注意要写入rd或者rj的值为rdcnt_result
    assign res_from[3] = inst_rdcntvh_w;
    assign res_from[4] = inst_rdcntvl_w;

    // 扩展选择信号
    assign extend_op[0] = inst_addi_w | inst_ld_w | inst_ld_h | inst_ld_b | inst_ld_hu | inst_ld_bu | inst_st_w | inst_st_b | inst_st_h | inst_slti | inst_sltui | inst_cacop_valid | inst_preld;  
    assign extend_op[1] = inst_slli_w | inst_srai_w | inst_srli_w; 
    assign extend_op[2] = inst_lu12i_w | inst_pcaddu12i;
    assign extend_op[3] = inst_andi | inst_ori | inst_xori;
    assign extend_op[4] = inst_ll_w | inst_sc_w;

    // 扩展
    Ext extender(.sign_imm_12(sign_imm_12),
                .unsign_imm_12(unsign_imm_12),
                .unsign_imm_5(unsign_imm_5),
                .sign_imm_20(sign_imm_20),
                .sign_imm_14(sign_imm_14),
                .extend_op(extend_op),
                .extend_res(extend_res)
    );

    //寄存器写使能信号
    assign gr_we       = inst_add_w | inst_and | inst_or | inst_xor | inst_nor | inst_sub_w |
                        inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu |
                        inst_slt | inst_sltu | inst_sll_w | inst_srl_w | inst_sra_w |
                        inst_slli_w |inst_srli_w | inst_srai_w | 
                        inst_addi_w | inst_slti | inst_sltui | inst_lu12i_w | inst_pcaddu12i |
                        inst_andi | inst_ori | inst_xori |
                        inst_bl | inst_jirl |
                        inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ll_w | inst_sc_w |
                        inst_csrrd | inst_csrwr | inst_csrxchg | 
                        inst_rdcntid | inst_rdcntvh_w | inst_rdcntvl_w | inst_cpucfg;


    //bl指令地址选择信号
    assign dest = inst_bl ? 5'd1 : (dst_is_rj ? rj : rd);
    //DM_mux选择信号 
    assign sel_rf_res     = inst_ld_w | inst_ld_h | inst_ld_b | inst_ld_hu | inst_ld_bu | inst_ll_w;

    //ld、st等访存信号字节长度
    assign mem_b_size    = inst_ld_b | inst_ld_bu | inst_st_b;  //byte
    assign mem_h_size    = inst_ld_h | inst_ld_hu | inst_st_h;  //halfword
    assign mem_sign_exted= inst_ld_b | inst_ld_h;               //符号扩展
    assign mem_type = {mem_sign_exted, mem_b_size, mem_h_size}; //mem写入或者读取内容类型 
    assign load_op  = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu | inst_ll_w;
    assign store_op = inst_st_w | inst_st_b | inst_st_h | (inst_sc_w & ID_llbit);

    //跳转处理
    assign br_op[0]    = inst_bne;
    assign br_op[1]    = inst_beq;
    assign br_op[2]    = inst_b;
    assign br_op[3]    = inst_bl;
    assign br_op[4]    = inst_jirl;
    assign br_op[5]    = inst_blt;
    assign br_op[6]    = inst_bge;
    assign br_op[7]    = inst_bltu;
    assign br_op[8]    = inst_bgeu;

    //寄存器选择信号
    assign sel_rf_ra2  = inst_st_w | inst_st_b | inst_st_h | inst_bne | inst_beq | inst_bge | inst_bgeu | inst_jirl | inst_csrwr | inst_csrxchg | inst_blt | inst_bltu | inst_sc_w;

    //寄存器操作
    assign rf_raddr1 = rj;
    assign rf_raddr2 = sel_rf_ra2 ? rd : rk;
    assign rj_value  = rf_rdata1;
    assign rkd_value = rf_rdata2;

    //有关csr的信号
    assign csr_we        = inst_csrwr | inst_csrxchg;
    assign csr_num       = inst_cpucfg ? (rj_value[13:0]+14'h00b0) : (inst_ertn ? 14'h6 : inst[23:10]);
    assign csr_w_mask    = inst_csrwr;
    assign dst_is_rj     = inst_rdcntid;
    assign invtlb_op     = rd;
    assign kernel_inst = inst_csrrd     |
                        inst_csrwr      |
                        inst_csrxchg    |
                        inst_tlbsrch    |
                        inst_tlbrd      |
                        inst_tlbwr      |
                        inst_tlbfill    |
                        inst_invtlb     |
                        inst_ertn       |
                        inst_idle       ;

    //异常与中断处理
    //指令特权等级错例外
    assign excp_ipe = kernel_inst && (csr_plv == 2'b11);
    //指令不存在异常
    assign excp_ine = ID_valid & ~(
                        inst_add_w      |
                        inst_sub_w      |
                        inst_slt        |
                        inst_sltu       |
                        inst_nor        |
                        inst_and        |
                        inst_or         |
                        inst_xor        |
                        inst_sll_w      |
                        inst_srl_w      |
                        inst_sra_w      |
                        inst_mul_w      |
                        inst_mulh_w     |
                        inst_mulh_wu    |
                        inst_div_w      |
                        inst_mod_w      |
                        inst_div_wu     |
                        inst_mod_wu     |
                        inst_syscall    |
                        inst_slli_w     |
                        inst_srli_w     |
                        inst_srai_w     |
                        inst_slti       |
                        inst_sltui      |
                        inst_addi_w     |
                        inst_andi       |
                        inst_ori        |
                        inst_xori       |
                        inst_ld_b       |
                        inst_ld_h       |
                        inst_ld_w       |
                        inst_st_b       |
                        inst_st_h       |
                        inst_st_w       |
                        inst_ld_bu      |
                        inst_ld_hu      |
                        inst_jirl       |
                        inst_b          |
                        inst_bl         |
                        inst_beq        |
                        inst_bne        |
                        inst_blt        |
                        inst_bge        |
                        inst_bltu       |
                        inst_bgeu       |
                        inst_lu12i_w    |
                        inst_pcaddu12i  |
                        inst_csrrd      |
                        inst_csrwr      |
                        inst_csrxchg    |
                        inst_rdcntid    |
                        inst_rdcntvh_w  |
                        inst_rdcntvl_w  |
                        inst_ertn       |
                        inst_break      |
                        inst_tlbsrch    |
                        inst_tlbrd      |
                        inst_tlbwr      |
                        inst_tlbfill    |
                        inst_cacop_valid|
                        inst_invtlb     |
                        inst_cpucfg     |                      
                        inst_ll_w       |
                        inst_sc_w       |
                        inst_dbar       |
                        inst_ibar       |  
                        inst_idle       |
                        inst_nop        |
                        inst_preld     )|
    (inst_invtlb & (invtlb_op > 5'h6)  );

    //待定
    assign ID_excp = |ID_excp_num;
    assign ID_excp_num  = {excp_num[14:10], excp_ale, excp_ipe, excp_ine, inst_break, inst_syscall, excp_num[4:1], has_int}; 

    //前递处理
    assign need_rd = ID_valid & (inst_beq | inst_bne | inst_bge | inst_blt | inst_bltu | inst_bgeu |
                        inst_st_w | inst_st_b | inst_st_h |
                        inst_csrrd | inst_csrwr | inst_csrxchg | inst_cpucfg | inst_sc_w);      
    assign need_rj = ID_valid & ~(inst_b | inst_bl | inst_lu12i_w 
                        | inst_pcaddu12i | inst_csrrd | inst_csrwr 
                        | inst_syscall | inst_break | 
                        | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid
                        | inst_tlbrd | inst_tlbsrch | inst_tlbfill | inst_tlbwr
                        | inst_dbar | inst_ibar 
                        | inst_idle);
    assign need_rk = ID_valid & ~(inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w 
                    | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu
                    | inst_st_w | inst_st_h   | inst_st_b 
                    | inst_lu12i_w | inst_jirl 
                    | inst_bl | inst_b | inst_beq | inst_bne 
                    | inst_pcaddu12i | inst_slti | inst_sltui | inst_andi
                    | inst_ori | inst_xori | inst_blt | inst_bltu
                    | inst_bge | inst_bgeu
                    | inst_csrrd | inst_csrwr | inst_csrxchg 
                    | inst_syscall | inst_break
                    | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid
                    | inst_tlbfill | inst_tlbrd | inst_tlbsrch |inst_tlbwr
                    | inst_cacop | inst_sc_w | inst_ll_w
                    | inst_dbar | inst_ibar
                    | inst_idle | inst_preld | inst_cpucfg);
    assign need_rkd = need_rd | need_rk;

    assign {EX1_dest, EX1_data_not_prepared, EX1_data} = EX1_forward_bus;       //前递内容
    assign {EX2_dest                                 } = EX2_forward_bus;
    assign {MEM_dest, MEM_data_not_prepared, MEM_data} = MEM_forward_bus;
    assign rj_not_zero = |rf_raddr1;
    assign rkd_not_zero= |rf_raddr2;

    //旁路控制信号生成
    reg [2:0] rj_sel;
    reg [2:0] rkd_sel;
    always @(*)begin
        //rj
        if(EX1_dest == rf_raddr1 && rj_not_zero && need_rj)
            rj_sel = 3'b010;
        else if(MEM_dest == rf_raddr1 && rj_not_zero && need_rj)
            rj_sel = 3'b100;
        else rj_sel = 3'b001;
    end

    always @(*)begin
        //rkd
        if(EX1_dest == rf_raddr2 && rkd_not_zero && need_rkd)
            rkd_sel = 3'b010;
        else if(MEM_dest == rf_raddr2 && rkd_not_zero && need_rkd)
            rkd_sel = 3'b100;
        else rkd_sel = 3'b001;
    end

    //旁路选择器
    assign rdata_rj = csr_w_mask ? 32'hFFFF_FFFF :  (({32{rj_sel[0]}} & rj_value)
                                                    |({32{rj_sel[1]}} & EX1_data)
                                                    |({32{rj_sel[2]}} & MEM_data));
    assign rdata_rkd = ({32{rkd_sel[0]}} & rkd_value)
                        |({32{rkd_sel[1]}} & EX1_data)
                        |({32{rkd_sel[2]}} & MEM_data);


    wire stall_caused_by_rj  =   ID_valid & (EX1_dest == rj && EX1_data_not_prepared || EX2_dest == rj  || MEM_dest == rj && MEM_data_not_prepared) && |rj;
    wire stall_caused_by_rk  =   ID_valid & (EX1_dest == rk && EX1_data_not_prepared || EX2_dest == rk  || MEM_dest == rk && MEM_data_not_prepared) && |rk;
    wire stall_caused_by_rd  =   ID_valid & (EX1_dest == rd && EX1_data_not_prepared || EX2_dest == rd  || MEM_dest == rd && MEM_data_not_prepared) && |rd;
    assign stall_data_hazard =   stall_caused_by_rj && need_rj || stall_caused_by_rk && need_rk || stall_caused_by_rd && need_rd;

    //流水线控制信号
    reg idle_lock;
    assign stall_forward    = EX_stall || MEM_stall;
    assign stall            = ID_stall || EX_stall || MEM_stall;
    assign ID_stall         = reset ? 1'b0 : ((ID_valid && stall_data_hazard) | idle_lock); //|| idle_lock
    assign ID_EX1_valid     = ID_valid && !ID_stall;

    always @(posedge clk)begin
        if(reset) begin
            IF_ID_reg <= `WIDTH_IF_ID_BUS'b0;     
        end
        else if(~stall) begin
            IF_ID_reg <= IF_ID_bus;
        end
    end

    assign {
            btb_miss,
            pred_taken,
            pred_target,
            excp_num,
            inst,
            ID_pc
            } = IF_ID_reg;

    always @(posedge clk)begin
        if(reset || flush || taken & ~idle_lock) begin
            ID_valid <= 1'b0;
        end
        else if(!stall) begin
            ID_valid <= IF_ID_valid;
        end
    end

    always @(posedge clk)begin
        if(reset || flush)
            idle_lock <= 0;
        //idle执行
        else if(ID_valid && !(|excp_num) && inst_idle && !stall_forward)
            idle_lock <= 1;
        //中断唤醒
        else if(has_int)
            idle_lock <= 0;
    end



`ifdef DIFFTEST_EN
    wire [31:0] ID_inst;
    wire        ID_cnt_inst;
    wire [ 7:0] ID_inst_ld_en;
    wire [ 7:0] ID_inst_st_en;
    wire        ID_csr_rstat_en;
    

    assign ID_inst = inst;
    assign ID_cnt_inst = inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid;
    assign ID_inst_ld_en = {2'b0, inst_ll_w, inst_ld_w, inst_ld_hu, inst_ld_h, inst_ld_bu, inst_ld_b};
    assign ID_inst_st_en = {4'b0, ID_llbit && inst_sc_w, inst_st_w, inst_st_h, inst_st_b};
    assign ID_csr_rstat_en = (inst_csrrd || inst_csrwr || inst_csrxchg) && (csr_num == 14'd5);

    assign ID_EX1_diff_bus = {
        ID_inst,
        ID_cnt_inst,
        ID_inst_ld_en,
        ID_inst_st_en,
        ID_csr_rstat_en
    };
`endif

    assign ID_data_vaddr = rdata_rj + extend_res;
    assign excp_ale = (load_op | store_op) & 
                      ((!mem_type[1:0] & (ID_data_vaddr[0] | ID_data_vaddr[1])) | (mem_type[0] & ID_data_vaddr[0]));
    assign s1_vppn = {19{ inst_tlbsrch}} & csr_tlbehi_rvalue[31:13] |
                     {19{~inst_tlbsrch}} & ID_data_vaddr[31:13];
    assign alu_src1 = {32{sel_alu_src1[0]}} & rdata_rj |
                      {32{sel_alu_src1[1]}} & ID_pc;
    always @(*) begin
        case(sel_alu_src2)
            3'b001:  alu_src2 = rdata_rkd;
            3'b010:  alu_src2 = extend_res;
            3'b100:  alu_src2 = 32'd4;
            default: alu_src2 = rdata_rkd;
        endcase 
    end
endmodule