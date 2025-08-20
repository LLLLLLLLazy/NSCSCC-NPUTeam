`include "header.h"
//idle lock如果在id的话需要引入taken额外处理
module ID (
    input           clk,
    input           reset,
    input           has_int,

    //控制信号
    input                                   IS_stall, 
    input                                   EX_stall,
    input                                   MEM_stall,
    input                                   flush, // flush|taken
    input [ 1:0]                            csr_plv,
    input                                   IF_ID_valid,
    input [`WIDTH_IF_ID_BUS - 1 : 0]        IF_ID_bus1,
    input [`WIDTH_IF_ID_BUS - 1 : 0]        IF_ID_bus2,
    input                                   FIFO_stall,
    input                                   ID_llbit1,
    input                                   ID_llbit2,

    output                                  inst1_valid,
    output                                  inst2_valid,
    output [`WIDTH_ID_FIFO_BUS-1:0]         ID_FIFO_bus1,
    output [`WIDTH_ID_FIFO_BUS-1:0]         ID_FIFO_bus2,
    output [`WIDTH_ID_DECODE_BUS-1:0]       ID_decode_bus1,
    output [`WIDTH_ID_DECODE_BUS-1:0]       ID_decode_bus2,
    output                                  ID_FIFO_valid,
    output                                  ID_stall,
    output                                  real_icache_miss

    `ifdef DIFFTEST_EN
    ,
    output [`DIFF_WIDTH_ID_FIFO_BUS-1:0] ID_FIFO_diff_bus_1,
    output [`DIFF_WIDTH_ID_FIFO_BUS-1:0] ID_FIFO_diff_bus_2
    `endif
);
    //Decode

    //inst
    wire [31:0] inst1;
    wire [9:0] offs1_25_16;
    wire [5:0] op1_31_26;
    wire [3:0] op1_25_22;
    wire [1:0] op1_21_20;
    wire [4:0] op1_19_15;
    wire [63:0] op1_31_26_d;
    wire [15:0] op1_25_22_d;
    wire [3:0] op1_21_20_d;
    wire [31:0] op1_19_15_d;

    wire [31:0] inst2;
    wire [9:0] offs2_25_16;
    wire [5:0] op2_31_26;
    wire [3:0] op2_25_22;
    wire [1:0] op2_21_20;
    wire [4:0] op2_19_15;
    wire [63:0] op2_31_26_d;
    wire [15:0] op2_25_22_d;
    wire [3:0] op2_21_20_d;
    wire [31:0] op2_19_15_d;

    //rj, rd, rk类型
    wire  inst_add_w1;
    wire  inst_sub_w1;
    wire  inst_and1;
    wire  inst_or1;
    wire  inst_xor1;
    wire  inst_nor1;
    wire  inst_slt1;
    wire  inst_sltu1;
    wire  inst_sll_w1;
    wire  inst_srl_w1;
    wire  inst_sra_w1;
    wire  inst_mul_w1;
    wire  inst_mulh_w1;
    wire  inst_mulh_wu1;
    wire  inst_div_w1;
    wire  inst_div_wu1;
    wire  inst_mod_w1;
    wire  inst_mod_wu1;

    wire  inst_add_w2;
    wire  inst_sub_w2;
    wire  inst_and2;
    wire  inst_or2;
    wire  inst_xor2;
    wire  inst_nor2;
    wire  inst_slt2;
    wire  inst_sltu2;
    wire  inst_sll_w2;
    wire  inst_srl_w2;
    wire  inst_sra_w2;
    wire  inst_mul_w2;
    wire  inst_mulh_w2;
    wire  inst_mulh_wu2;
    wire  inst_div_w2;
    wire  inst_div_wu2;
    wire  inst_mod_w2;
    wire  inst_mod_wu2;
    //立即数操作类型
    //si12
    wire  inst_ld_w1;
    wire  inst_ld_b1;
    wire  inst_ld_h1;
    wire  inst_ld_bu1;
    wire  inst_ld_hu1;
    wire  inst_st_b1;
    wire  inst_st_h1;
    wire  inst_st_w1;
    wire  inst_addi_w1;
    wire  inst_slti1;
    wire  inst_sltui1;

    wire  inst_ld_w2;
    wire  inst_ld_b2;
    wire  inst_ld_h2;
    wire  inst_ld_bu2;
    wire  inst_ld_hu2;
    wire  inst_st_b2;
    wire  inst_st_h2;
    wire  inst_st_w2;
    wire  inst_addi_w2;
    wire  inst_slti2;
    wire  inst_sltui2;
    //ui12
    wire  inst_andi1;
    wire  inst_ori1;
    wire  inst_xori1;

    wire  inst_andi2;
    wire  inst_ori2;
    wire  inst_xori2;
    //ui5
    wire  inst_slli_w1;
    wire  inst_srli_w1;
    wire  inst_srai_w1;

    wire  inst_slli_w2;
    wire  inst_srli_w2;
    wire  inst_srai_w2;
    //si20    
    wire  inst_lu12i_w1;
    wire  inst_pcaddu12i1;

    wire  inst_lu12i_w2;
    wire  inst_pcaddu12i2;
    //si14
    wire  inst_ll_w1;
    wire  inst_sc_w1;

    wire  inst_ll_w2;
    wire  inst_sc_w2;
    
    //跳转指令类型
    wire  inst_bne1;
    wire  inst_b1;
    wire  inst_beq1;
    wire  inst_bl1;
    wire  inst_jirl1;
    wire  inst_blt1;
    wire  inst_bge1;
    wire  inst_bltu1;
    wire  inst_bgeu1;

    wire  inst_bne2;
    wire  inst_b2;
    wire  inst_beq2;
    wire  inst_bl2;
    wire  inst_jirl2;
    wire  inst_blt2;
    wire  inst_bge2;
    wire  inst_bltu2;
    wire  inst_bgeu2;

    //TLB处理指令
    wire inst_tlbsrch1;
    wire inst_tlbrd1;
    wire inst_tlbwr1;
    wire inst_tlbfill1;
    wire inst_invtlb1;
    wire [4:0] invtlb_op1;

    wire inst_tlbsrch2;
    wire inst_tlbrd2;
    wire inst_tlbwr2;
    wire inst_tlbfill2;
    wire inst_invtlb2;
    wire [4:0] invtlb_op2;
    //cache维护指令
    wire inst_cacop1;
    wire [4:0] cacop_code1;
    wire inst_cacop_valid1;  //cacop有效信号,该指令是否有效放在ID中判断比较方便
    wire inst_cpucfg1;
    wire inst_idle1;
    wire inst_preld1;

    wire inst_cacop2;
    wire [4:0] cacop_code2;
    wire inst_cacop_valid2;
    wire inst_cpucfg2;
    wire inst_idle2;
    wire inst_preld2;
    //dbar,ibar
    wire inst_dbar1;
    wire inst_ibar1;

    wire inst_dbar2;
    wire inst_ibar2;
    //异常处理
    wire  inst_csrrd1;
    wire  inst_csrwr1;
    wire  inst_csrxchg1;
    wire  inst_ertn1;
    wire  inst_rdcntvl_w1;
    wire  inst_rdcntvh_w1;
    wire  inst_rdcntid1;
    wire  inst_syscall1;
    wire  inst_break1;
    wire inst_nop1;

    wire  inst_csrrd2;
    wire  inst_csrwr2;
    wire  inst_csrxchg2;
    wire  inst_ertn2;
    wire  inst_rdcntvl_w2;
    wire  inst_rdcntvh_w2;
    wire  inst_rdcntid2;
    wire  inst_syscall2;
    wire  inst_break2;
    wire  inst_nop2;

    //TODO 中断异常信号      异常中断等问题还需要考虑
    wire ID_excp1;
    wire [14:0] ID_excp_num1;       // 位数待定
    wire [14:0] excp_num1;

    wire ID_excp2;
    wire [14:0] ID_excp_num2;       // 位数待定
    wire [14:0] excp_num2;

    //csr相关信号
    wire  [13:0] csr_num1;
    wire  csr_we1;   
    wire  csr_w_mask1;
    wire  dst_is_rj1;
    wire  [2:0] rdcnt_en1;
    wire  excp_ine1;
    wire  excp_ipe1;
    wire  kernel_inst1;

    wire  [13:0] csr_num2;
    wire  csr_we2;   
    wire  csr_w_mask2;
    wire  dst_is_rj2;
    wire  [2:0] rdcnt_en2;
    wire  excp_ine2;
    wire  excp_ipe2;
    wire  kernel_inst2;

    //数据
    wire [ 4:0] rd1;
    wire [ 4:0] rj1;
    wire [ 4:0] rk1;
    wire [11:0] sign_imm1_12;  //有符号12位立即数
    wire [11:0] unsign_imm1_12;//无符号12位立即数
    wire [19:0] sign_imm1_20;  //有符号20位立即数
    wire [ 4:0] unsign_imm1_5; //无符号5位立即数
    wire [13:0] sign_imm1_14;  //有符号14位立即数

    wire [ 4:0] rd2;
    wire [ 4:0] rj2;
    wire [ 4:0] rk2;
    wire [11:0] sign_imm2_12;  //有符号12位立即数
    wire [11:0] unsign_imm2_12;//无符号12位立即数
    wire [19:0] sign_imm2_20;  //有符号20位立即数
    wire [ 4:0] unsign_imm2_5; //无符号5位立即数
    wire [13:0] sign_imm2_14;  //有符号14位立即数

    wire need_rj1;
    wire need_rk1;
    wire need_rd1;
    wire need_rkd1;
    wire rj_not_zero1;
    wire rkd_not_zero1;

    wire need_rj2;
    wire need_rk2;
    wire need_rd2;
    wire need_rkd2;
    wire rj_not_zero2;
    wire rkd_not_zero2;

    wire [4:0] inst_issue_way1; //指令发射方式
    wire [4:0] inst_issue_way2; //指令发射方式

    //分支预测传输信号
    wire btb_miss1;
    wire pred_taken1;
    wire [31:0] pred_target1;
    wire [ 4:0] pred_index1;

    wire btb_miss2;
    wire pred_taken2;
    wire [31:0] pred_target2;
    wire [ 4:0] pred_index2;

    //流水线控制
    reg ID_valid; //id stage 中是否含有效的指令
    reg [`WIDTH_IF_ID_BUS - 1 : 0] IF_ID_reg1;
    reg [`WIDTH_IF_ID_BUS - 1 : 0] IF_ID_reg2;
    wire same_reg;
    wire stall;
    wire stall_forward;
    wire stall_data_hazard; //数据冒险导致的stall

    //控制信号
    wire [31:0] ID_pc1;
    wire [18:0] ALU_op1;       //ALU操作信号12位（独热码）
    wire [ 4:0] extend_op1;    //立即数扩展类型选择信号    001为有符号12位扩展，010选择无符号5位扩展，100选择指令lu12i指令的扩展
    wire [31:0] extend_res1;   //扩展后立即数
    wire [4:0]  dest1;         //写回地址,bl指令时为0000_1 
    wire [2:0]  sel_alu_src2_1; //寄存器read data2选择器信号   001选择read data2中的数据,010选择立即数，100选择4
    wire        sel_alu_res1;  //alu结果选择信号，1选择data ram中读出的数据
    wire [2:0]  sel_alu_src1_1; //高电平时选择jirl的pc信号， 低电平时选择read data1中的数据
    wire        gr_we1;        //寄存器写使能信号
    wire [31:0] rj_value1;
    wire [31:0] rkd_value1;
    wire [31:0] rdata_rj1;
    wire [31:0] rdata_rkd1;
    wire [8:0]  br_op1;        //跳转指令类型信号（独热码）
    wire [15:0] offs1_15_0;    //跳转信号16位立即数
    wire [25:0] offs1_26;      //b和bl信号10位立即数和16位立即数拼接结果
    wire sel_rf_ra2_1;           //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
    wire [31:0] br_target1;     //跳转地址目标
    wire [ 4:0] res_from1;
    wire [ 2:0] mem_type1;

    wire [31:0] ID_pc2;
    wire [18:0] ALU_op2;       //ALU操作信号12位（独热码）
    wire [ 4:0] extend_op2;    //立即数扩展类型选择信号    001为有符号12位扩展，010选择无符号5位扩展，100选择指令lu12i指令的扩展
    wire [31:0] extend_res2;   //扩展后立即数
    wire [4:0]  dest2;         //写回地址,bl指令时为0000_1 
    wire [2:0]  sel_alu_src2_2; //寄存器read data2选择器信号   001选择read data2中的数据,010选择立即数，100选择4
    wire        sel_alu_res2;  //alu结果选择信号，1选择data ram中读出的数据
    wire [2:0]  sel_alu_src1_2; //高电平时选择jirl的pc信号， 低电平时选择read data1中的数据
    wire        gr_we2;        //寄存器写使能信号
    wire [31:0] rj_value2;
    wire [31:0] rkd_value2;
    wire [31:0] rdata_rj2;
    wire [31:0] rdata_rkd2;
    wire [8:0]  br_op2;        //跳转指令类型信号（独热码）
    wire [15:0] offs2_15_0;    //跳转信号16位立即数
    wire [25:0] offs2_26;      //b和bl信号10位立即数和16位立即数拼接结果
    wire sel_rf_ra2_2;           //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
    wire [31:0] br_target2;     //跳转地址目标
    wire [ 4:0] res_from2;
    wire [ 2:0] mem_type2;

    //跳转指令判断
    wire s_rj_smaller_rd1;  
    wire us_rj_smaller_rd1;
    wire rj_equal_rd1;

    wire s_rj_smaller_rd2;  
    wire us_rj_smaller_rd2;
    wire rj_equal_rd2;

    wire icache_miss;

    //ID_BUFFER_Bus
    assign ID_FIFO_bus1 = {
        br_op1,             // 9
        offs1_26,           // 26
        rj1,
        rk1,
        rd1,
        dest1,
        need_rj1,
        need_rk1,
        need_rd1,
        sel_rf_ra2_1,   //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
        inst_issue_way1
    };

    assign ID_FIFO_bus2 = {
        br_op2,             // 9
        offs2_26,           // 26
        rj2,
        rk2,
        rd2,
        dest2,
        need_rj2,
        need_rk2,
        need_rd2,
        sel_rf_ra2_2,
        inst_issue_way2
    };

    //ID_decode_bus  注释暂时不一定准确
    assign ID_decode_bus1 = {
        //==============================================================
        // 组0: cache相关控制信号 (共10位)   
        //==============================================================
        inst_cpucfg1,       // 1
        inst_idle1,         // 1
        inst_preld1,        // 1 
        inst_ll_w1,         // 1 
        inst_sc_w1,         // 1 
        inst_cacop_valid1,  // 1 cacop指令有效信号,高电平有效
        cacop_code1,        // 5 cacop指令的code
        //==============================================================
        // 组1: CSR相关控制信号 (共27位)
        //==============================================================
        inst_invtlb1,       // 1
        invtlb_op1,         // 5
        inst_tlbwr1,        // 1 
        inst_tlbfill1,      // 1 
        inst_tlbsrch1,      // 1 
        inst_tlbrd1,        // 1
        inst_ertn1,         // 1 ertn信号  
        csr_we1,            // 1 CSR写使能
        csr_num1,           // 14 CSR地址（14位）
        csr_w_mask1,        // 1
        
        //==============================================================
        // 组2: 控制信号 (共56位)
        //==============================================================
        res_from1,          // 5 00000-选ALU结果 00001-选存储器数据 00010-选csr数据 00100~10000等价于之前的rdcnt_en出现该信号时，注意要写入rd或者rj的值为rdcnt_result
        gr_we1,             // 1 寄存器写使能
        sel_alu_src1_1,     // 3 跳转指令标志 (1-jirl/bl指令)
        load_op1,           // 1 load类指令执行
        store_op1,          // 1 store类指令执行
        sel_alu_src2_1,     // 3 ALU源2选择 (3位)
        mem_type1,          // 3 访存类型 (3位) 
        btb_miss1,          // 1
        pred_index1,         // 5
        pred_taken1,        // 1
        pred_target1,       // 32
        //============================================================== 
        // 组3: 异常处理  16
        //==============================================================
        ID_excp_num1,       //15 异常号
        ID_excp1,           //1 异常信号
        //==============================================================
        // 组4: 立即数扩展控制 (32位)
        //==============================================================
        extend_res1,        //32 扩展后的立即数

        //==============================================================
        // 组5: ALU操作码 (19位)
        //==============================================================
        ALU_op1,            //19 ALU操作码 (独热码编码)

        //==============================================================
        // 组6: PC值 (32位)
        //==============================================================
        ID_pc1              //32 当前指令PC值
    };

        assign ID_decode_bus2 = {
        //==============================================================
        // 组0: cache相关控制信号  
        //==============================================================
        inst_cpucfg2,
        inst_idle2,
        inst_preld2,        // 
        inst_ll_w2,         // 
        inst_sc_w2,         // 
        inst_cacop_valid2,  // cacop指令有效信号,高电平有效
        cacop_code2,        // cacop指令的code
        //==============================================================
        // 组1: CSR相关控制信号 
        //==============================================================
        inst_invtlb2,       // 
        invtlb_op2,         // 
        inst_tlbwr2,        // 
        inst_tlbfill2,      // 
        inst_tlbsrch2,      // 
        inst_tlbrd2,        // 
        inst_ertn2,         // ertn信号
        csr_we2,            // CSR写使能
        csr_num2,           // CSR地址（14位）
        csr_w_mask2,
        
        //==============================================================
        // 组2: 控制信号 
        //==============================================================
        res_from2,          // 00000-选ALU结果 00001-选存储器数据 00010-选csr数据 00100~10000等价于之前的rdcnt_en出现该信号时，注意要写入rd或者rj的值为rdcnt_result
        gr_we2,             //  寄存器写使能
        sel_alu_src1_2,      // 跳转指令标志 (1-jirl/bl指令)
        load_op2,           // load类指令执行
        store_op2,          // store类指令执行
        sel_alu_src2_2,      // ALU源2选择 (3位)
        mem_type2,          // 访存类型 (3位) 
        btb_miss2,
        pred_index2,
        pred_taken2,
        pred_target2,
        //============================================================== 
        // 组3: 异常处理   
        //==============================================================
        ID_excp_num2,       //
        ID_excp2,           //
        //==============================================================
        // 组4: 立即数扩展控制 
        //==============================================================
        extend_res2,        // 扩展后的立即数

        //==============================================================
        // 组5: ALU操作码 
        //==============================================================
        ALU_op2,            //ALU操作码 (独热码编码)

        //==============================================================
        // 组6: PC值 
        //==============================================================
        ID_pc2              // 当前指令PC值
    };

    //译码处理
    assign op1_31_26 = inst1[31:26];
    assign op1_25_22 = inst1[25:22];
    assign op1_21_20 = inst1[21:20];
    assign op1_19_15 = inst1[19:15];
    assign op2_31_26 = inst2[31:26];
    assign op2_25_22 = inst2[25:22];
    assign op2_21_20 = inst2[21:20];
    assign op2_19_15 = inst2[19:15];
    decoder_6_64 u_dec0(.in(op1_31_26 ), .out(op1_31_26_d ));
    decoder_4_16 u_dec1(.in(op1_25_22 ), .out(op1_25_22_d ));
    decoder_2_4  u_dec2(.in(op1_21_20 ), .out(op1_21_20_d ));
    decoder_5_32 u_dec3(.in(op1_19_15 ), .out(op1_19_15_d ));
    decoder_6_64 u_dec4(.in(op2_31_26 ), .out(op2_31_26_d ));
    decoder_4_16 u_dec5(.in(op2_25_22 ), .out(op2_25_22_d ));
    decoder_2_4  u_dec6(.in(op2_21_20 ), .out(op2_21_20_d ));
    decoder_5_32 u_dec7(.in(op2_19_15 ), .out(op2_19_15_d ));
    
        //TODO 操作类型信号
    //rj, rd, rk类型
    assign inst_add_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h00];
    assign inst_sub_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h02];
    assign inst_slt1    = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h04];
    assign inst_sltu1   = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h05];
    assign inst_and1    = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h09];
    assign inst_or1     = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h0a];
    assign inst_xor1    = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h0b];
    assign inst_nor1    = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h08];
    assign inst_sll_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h0e];
    assign inst_srl_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h0f];
    assign inst_sra_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h10];
    assign inst_mul_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h18];
    assign inst_mulh_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h19];
    assign inst_mulh_wu1= op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h1] & op1_19_15_d[5'h1a];
    assign inst_div_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h2] & op1_19_15_d[5'h00];
    assign inst_mod_w1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h2] & op1_19_15_d[5'h01];
    assign inst_div_wu1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h2] & op1_19_15_d[5'h02];
    assign inst_mod_wu1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h2] & op1_19_15_d[5'h03];

    assign inst_add_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h00];
    assign inst_sub_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h02];
    assign inst_slt2    = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h04];
    assign inst_sltu2   = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h05];
    assign inst_and2    = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h09];
    assign inst_or2     = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h0a];
    assign inst_xor2    = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h0b];
    assign inst_nor2    = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h08];
    assign inst_sll_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h0e];
    assign inst_srl_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h0f];
    assign inst_sra_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h10];
    assign inst_mul_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h18];
    assign inst_mulh_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h19];
    assign inst_mulh_wu2= op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h1] & op2_19_15_d[5'h1a];
    assign inst_div_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h2] & op2_19_15_d[5'h00];
    assign inst_mod_w2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h2] & op2_19_15_d[5'h01];
    assign inst_div_wu2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h2] & op2_19_15_d[5'h02];
    assign inst_mod_wu2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h2] & op2_19_15_d[5'h03];

    //立即数操作类型
    //si12
    assign inst_addi_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'ha];
    assign inst_ld_b1   = op1_31_26_d[6'h0a] & op1_25_22_d[4'h0];
    assign inst_ld_h1   = op1_31_26_d[6'h0a] & op1_25_22_d[4'h1];
    assign inst_ld_w1   = op1_31_26_d[6'h0a] & op1_25_22_d[4'h2];
    assign inst_st_b1   = op1_31_26_d[6'h0a] & op1_25_22_d[4'h4];
    assign inst_st_h1   = op1_31_26_d[6'h0a] & op1_25_22_d[4'h5];
    assign inst_st_w1   = op1_31_26_d[6'h0a] & op1_25_22_d[4'h6];
    assign inst_ld_bu1  = op1_31_26_d[6'h0a] & op1_25_22_d[4'h8];
    assign inst_ld_hu1  = op1_31_26_d[6'h0a] & op1_25_22_d[4'h9];
    assign inst_slti1   = op1_31_26_d[6'h00] & op1_25_22_d[4'h8];
    assign inst_sltui1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h9];

    assign inst_addi_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'ha];
    assign inst_ld_b2   = op2_31_26_d[6'h0a] & op2_25_22_d[4'h0];
    assign inst_ld_h2   = op2_31_26_d[6'h0a] & op2_25_22_d[4'h1];
    assign inst_ld_w2   = op2_31_26_d[6'h0a] & op2_25_22_d[4'h2];
    assign inst_st_b2   = op2_31_26_d[6'h0a] & op2_25_22_d[4'h4];
    assign inst_st_h2   = op2_31_26_d[6'h0a] & op2_25_22_d[4'h5];
    assign inst_st_w2   = op2_31_26_d[6'h0a] & op2_25_22_d[4'h6];
    assign inst_ld_bu2  = op2_31_26_d[6'h0a] & op2_25_22_d[4'h8];
    assign inst_ld_hu2  = op2_31_26_d[6'h0a] & op2_25_22_d[4'h9];
    assign inst_slti2   = op2_31_26_d[6'h00] & op2_25_22_d[4'h8];
    assign inst_sltui2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h9];
    //ui12
    assign inst_andi1   = op1_31_26_d[6'h00] & op1_25_22_d[4'hd];
    assign inst_ori1    = op1_31_26_d[6'h00] & op1_25_22_d[4'he];
    assign inst_xori1   = op1_31_26_d[6'h00] & op1_25_22_d[4'hf];

    assign inst_andi2   = op2_31_26_d[6'h00] & op2_25_22_d[4'hd];
    assign inst_ori2    = op2_31_26_d[6'h00] & op2_25_22_d[4'he];
    assign inst_xori2   = op2_31_26_d[6'h00] & op2_25_22_d[4'hf];
    //ui5
    assign inst_slli_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h1] & op1_21_20_d[2'h0] & op1_19_15_d[5'h01];
    assign inst_srli_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h1] & op1_21_20_d[2'h0] & op1_19_15_d[5'h09];
    assign inst_srai_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h1] & op1_21_20_d[2'h0] & op1_19_15_d[5'h11]; 

    assign inst_slli_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h1] & op2_21_20_d[2'h0] & op2_19_15_d[5'h01];
    assign inst_srli_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h1] & op2_21_20_d[2'h0] & op2_19_15_d[5'h09];
    assign inst_srai_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h1] & op2_21_20_d[2'h0] & op2_19_15_d[5'h11]; 
    //si20
    assign inst_lu12i_w1   = op1_31_26_d[6'h05] & (~inst1[25]);
    assign inst_pcaddu12i1 = op1_31_26_d[6'h07] & (~inst1[25]);

    assign inst_lu12i_w2   = op2_31_26_d[6'h05] & (~inst2[25]);
    assign inst_pcaddu12i2 = op2_31_26_d[6'h07] & (~inst2[25]);
    //si14
    assign inst_ll_w1      = op1_31_26_d[6'h08] & (inst1[25:24] == 2'b00);
    assign inst_sc_w1      = op1_31_26_d[6'h08] & (inst1[25:24] == 2'b01);

    assign inst_ll_w2      = op2_31_26_d[6'h08] & (inst2[25:24] == 2'b00);
    assign inst_sc_w2      = op2_31_26_d[6'h08] & (inst2[25:24] == 2'b01);

    //跳转指令类型
    //br_op的独热码顺序也是按这个顺序
    assign inst_bne1    = op1_31_26_d[6'h17];
    assign inst_beq1    = op1_31_26_d[6'h16];
    assign inst_b1      = op1_31_26_d[6'h14];
    assign inst_bl1     = op1_31_26_d[6'h15];
    assign inst_jirl1   = op1_31_26_d[6'h13];
    assign inst_blt1    = op1_31_26_d[6'h18];
    assign inst_bge1    = op1_31_26_d[6'h19];
    assign inst_bltu1   = op1_31_26_d[6'h1a];
    assign inst_bgeu1   = op1_31_26_d[6'h1b];

    assign inst_bne2    = op2_31_26_d[6'h17];
    assign inst_beq2    = op2_31_26_d[6'h16];
    assign inst_b2      = op2_31_26_d[6'h14];
    assign inst_bl2     = op2_31_26_d[6'h15];
    assign inst_jirl2   = op2_31_26_d[6'h13];
    assign inst_blt2    = op2_31_26_d[6'h18];
    assign inst_bge2    = op2_31_26_d[6'h19];
    assign inst_bltu2   = op2_31_26_d[6'h1a];
    assign inst_bgeu2   = op2_31_26_d[6'h1b];

    //TLB指令处理
    assign inst_tlbsrch1 = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h10] & (inst1[14:10] == 5'b0_1010) & (rj1 == 5'b0_0000) & (rd1 == 5'b0_0000);
    assign inst_tlbrd1   = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h10] & (inst1[14:10] == 5'b0_1011) & (rj1 == 5'b0_0000) & (rd1 == 5'b0_0000);
    assign inst_tlbwr1   = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h10] & (inst1[14:10] == 5'b0_1100) & (rj1 == 5'b0_0000) & (rd1 == 5'b0_0000);
    assign inst_tlbfill1 = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h10] & (inst1[14:10] == 5'b0_1101) & (rj1 == 5'b0_0000) & (rd1 == 5'b0_0000);
    assign inst_invtlb1  = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h13];

    assign inst_tlbsrch2 = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h10] & (inst2[14:10] == 5'b0_1010) & (rj2 == 5'b0_0000) & (rd2 == 5'b0_0000);
    assign inst_tlbrd2   = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h10] & (inst2[14:10] == 5'b0_1011) & (rj2 == 5'b0_0000) & (rd2 == 5'b0_0000);
    assign inst_tlbwr2   = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h10] & (inst2[14:10] == 5'b0_1100) & (rj2 == 5'b0_0000) & (rd2 == 5'b0_0000);
    assign inst_tlbfill2 = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h10] & (inst2[14:10] == 5'b0_1101) & (rj2 == 5'b0_0000) & (rd2 == 5'b0_0000);
    assign inst_invtlb2  = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h13];

    //cache维护指令
    assign inst_cacop1   = op1_31_26_d[6'h01] & op1_25_22_d[4'h8];
    assign cacop_code1   = inst1[4:0];
    assign inst_cacop_valid1 = inst_cacop1 & 
                            (cacop_code1[2:0] == 3'b000 | cacop_code1[2:0] == 3'b001) &       //暂时不需要实现code[2:0]=2 表示操作二级共享混合 Cache(应该?)
                            (cacop_code1[4:3] == 2'b00 | cacop_code1[4:3] == 2'b01 | cacop_code1[4:3] == 2'b10);   //详细内容见手册P44
    assign inst_nop1        = inst_cacop1 & cacop_code1[2:0] == 3'b010;
    assign inst_cpucfg1     = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h0] & op1_19_15_d[5'h00] & (rk1 == 5'b11011);
    assign inst_idle1       = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h11];
    assign inst_preld1      = op1_31_26_d[6'h0a] & op1_25_22_d[4'hb];

    assign inst_cacop2   = op2_31_26_d[6'h01] & op2_25_22_d[4'h8];
    assign cacop_code2   = inst2[4:0];
    assign inst_cacop_valid2 = inst_cacop2 & 
                            (cacop_code2[2:0] == 3'b000 | cacop_code2[2:0] == 3'b001) &       //暂时不需要实现code[2:0]=2 表示操作二级共享混合 Cache(应该?)
                            (cacop_code2[4:3] == 2'b00 | cacop_code2[4:3] == 2'b01 | cacop_code2[4:3] == 2'b10);   //详细内容见手册P44
    assign inst_nop2        = inst_cacop2 & cacop_code2[2:0] == 3'b010;
    assign inst_cpucfg2     = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h0] & op2_19_15_d[5'h00] & (rk2 == 5'b11011);
    assign inst_idle2       = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h11];
    assign inst_preld2      = op2_31_26_d[6'h0a] & op2_25_22_d[4'hb];
    //dbar,ibar
    assign inst_dbar1       = op1_31_26_d[6'h0e] & op1_25_22_d[4'h1] & op1_21_20_d[2'h3] & op1_19_15_d[5'h04];
    assign inst_ibar1       = op1_31_26_d[6'h0e] & op1_25_22_d[4'h1] & op1_21_20_d[2'h3] & op1_19_15_d[5'h05]; 

    assign inst_dbar2       = op2_31_26_d[6'h0e] & op2_25_22_d[4'h1] & op2_21_20_d[2'h3] & op2_19_15_d[5'h04];
    assign inst_ibar2       = op2_31_26_d[6'h0e] & op2_25_22_d[4'h1] & op2_21_20_d[2'h3] & op2_19_15_d[5'h05]; 
    //异常处理指令译码
    assign inst_csrrd1  = op1_31_26_d[6'h01] & (inst1[25] == 0) & (inst1[24] == 0) & (rj1 == 5'b0_0000);
    assign inst_csrwr1  = op1_31_26_d[6'h01] & (inst1[25] == 0) & (inst1[24] == 0) & (rj1 == 5'b0_0001);
    assign inst_csrxchg1= op1_31_26_d[6'h01] & (inst1[25] == 0) & (inst1[24] == 0) & (rj1 != 5'b0_0001 & rj1 != 5'b0_0000);
    assign inst_ertn1   = op1_31_26_d[6'h01] & op1_25_22_d[4'h9] & op1_21_20_d[2'h0] & op1_19_15_d[5'h10] & (inst1[14:10] == 5'b0_1110);
    assign inst_syscall1= op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h2] & op1_19_15_d[5'h16];
    assign inst_break1  = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h2] & op1_19_15_d[5'h14];
    assign inst_rdcntvl_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h0] & op1_19_15_d[5'h00] & (inst1[14:10] == 5'b1_1000) & (inst1[9:5] == 5'b0_0000) & (inst1[4:0] != 5'b0_0000);
    assign inst_rdcntvh_w1 = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h0] & op1_19_15_d[5'h00] & (inst1[14:10] == 5'b1_1001) & (inst1[9:5] == 5'b0_0000);
    assign inst_rdcntid1   = op1_31_26_d[6'h00] & op1_25_22_d[4'h0] & op1_21_20_d[2'h0] & op1_19_15_d[5'h00] & (inst1[14:10] == 5'b1_1000) & (inst1[4:0] == 5'b0_0000);
    
    assign inst_csrrd2  = op2_31_26_d[6'h01] & (inst2[25] == 0) & (inst2[24] == 0) & (rj2 == 5'b0_0000);
    assign inst_csrwr2  = op2_31_26_d[6'h01] & (inst2[25] == 0) & (inst2[24] == 0) & (rj2 == 5'b0_0001);
    assign inst_csrxchg2= op2_31_26_d[6'h01] & (inst2[25] == 0) & (inst2[24] == 0) & (rj2 != 5'b0_0001 & rj2 != 5'b0_0000);
    assign inst_ertn2   = op2_31_26_d[6'h01] & op2_25_22_d[4'h9] & op2_21_20_d[2'h0] & op2_19_15_d[5'h10] & (inst2[14:10] == 5'b0_1110);
    assign inst_syscall2= op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h2] & op2_19_15_d[5'h16];
    assign inst_break2  = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h2] & op2_19_15_d[5'h14];
    assign inst_rdcntvl_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h0] & op2_19_15_d[5'h00] & (inst2[14:10] == 5'b1_1000) & (inst2[9:5] == 5'b0_0000) & (inst2[4:0] != 5'b0_0000);
    assign inst_rdcntvh_w2 = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h0] & op2_19_15_d[5'h00] & (inst2[14:10] == 5'b1_1001) & (inst2[9:5] == 5'b0_0000);
    assign inst_rdcntid2   = op2_31_26_d[6'h00] & op2_25_22_d[4'h0] & op2_21_20_d[2'h0] & op2_19_15_d[5'h00] & (inst2[14:10] == 5'b1_1000) & (inst2[4:0] == 5'b0_0000);
    //部分常用指令
    assign rd1          = inst1[4:0];
    assign rj1          = inst1[9:5];
    assign rk1          = inst1[14:10];
    assign sign_imm1_12 = inst1[21:10];
    assign unsign_imm1_12=inst1[21:10];
    assign sign_imm1_20 = inst1[24:5];
    assign unsign_imm1_5= inst1[14:10];
    assign sign_imm1_14 = inst1[23:10];
    assign offs1_15_0   = inst1[25:10];
    assign offs1_25_16  = inst1[9:0];
    assign offs1_26     = {offs1_25_16, offs1_15_0};

    assign rd2          = inst2[4:0];
    assign rj2          = inst2[9:5];
    assign rk2          = inst2[14:10];
    assign sign_imm2_12 = inst2[21:10];
    assign unsign_imm2_12=inst2[21:10];
    assign sign_imm2_20 = inst2[24:5];
    assign unsign_imm2_5= inst2[14:10];
    assign sign_imm2_14 = inst2[23:10];
    assign offs2_15_0   = inst2[25:10];
    assign offs2_25_16  = inst2[9:0];
    assign offs2_26     = {offs2_25_16, offs2_15_0};

    //ALU操作译码
    assign ALU_op1[0]   = inst_add_w1 | inst_addi_w1 |
                        inst_ld_w1 | inst_ld_b1 | inst_ld_h1 | inst_ld_bu1 | inst_ld_hu1 | inst_st_w1 | inst_st_b1 | inst_st_h1 |
                        inst_jirl1 | inst_bl1 | inst_pcaddu12i1 | 
                        inst_csrwr1 | inst_csrxchg1 |
                        inst_cacop_valid1 | inst_ll_w1 | inst_sc_w1 | inst_preld1;
    assign ALU_op1[1]   = inst_sub_w1;
    assign ALU_op1[2]   = inst_slt1 | inst_slti1;
    assign ALU_op1[3]   = inst_sltu1 | inst_sltui1;
    assign ALU_op1[4]   = inst_and1 | inst_andi1;
    assign ALU_op1[5]   = inst_nor1;
    assign ALU_op1[6]   = inst_or1 | inst_ori1;
    assign ALU_op1[7]   = inst_xor1 |inst_xori1;
    assign ALU_op1[8]   = inst_slli_w1 | inst_sll_w1;
    assign ALU_op1[9]   = inst_srli_w1 | inst_srl_w1;
    assign ALU_op1[10]  = inst_srai_w1 | inst_sra_w1;
    assign ALU_op1[11]  = inst_lu12i_w1;
    assign ALU_op1[12]  = inst_mul_w1;
    assign ALU_op1[13]  = inst_mulh_w1;
    assign ALU_op1[14]  = inst_mulh_wu1;
    assign ALU_op1[15]  = inst_div_w1;
    assign ALU_op1[16]  = inst_div_wu1;
    assign ALU_op1[17]  = inst_mod_w1;
    assign ALU_op1[18]  = inst_mod_wu1;

    assign ALU_op2[0]   = inst_add_w2 | inst_addi_w2 |
                        inst_ld_w2 | inst_ld_b2 | inst_ld_h2 | inst_ld_bu2 | inst_ld_hu2 | inst_st_w2 | inst_st_b2 | inst_st_h2 |
                        inst_jirl2 | inst_bl2 | inst_pcaddu12i2 | 
                        inst_csrwr2 | inst_csrxchg2 |
                        inst_cacop_valid2 | inst_ll_w2 | inst_sc_w2 | inst_preld2;
    assign ALU_op2[1]   = inst_sub_w2;
    assign ALU_op2[2]   = inst_slt2 | inst_slti2;
    assign ALU_op2[3]   = inst_sltu2 | inst_sltui2;
    assign ALU_op2[4]   = inst_and2 | inst_andi2;
    assign ALU_op2[5]   = inst_nor2;
    assign ALU_op2[6]   = inst_or2 | inst_ori2;
    assign ALU_op2[7]   = inst_xor2 |inst_xori2;
    assign ALU_op2[8]   = inst_slli_w2 | inst_sll_w2;
    assign ALU_op2[9]   = inst_srli_w2 | inst_srl_w2;
    assign ALU_op2[10]  = inst_srai_w2 | inst_sra_w2;
    assign ALU_op2[11]  = inst_lu12i_w2;
    assign ALU_op2[12]  = inst_mul_w2;
    assign ALU_op2[13]  = inst_mulh_w2;
    assign ALU_op2[14]  = inst_mulh_wu2;
    assign ALU_op2[15]  = inst_div_w2;
    assign ALU_op2[16]  = inst_div_wu2;
    assign ALU_op2[17]  = inst_mod_w2;
    assign ALU_op2[18]  = inst_mod_wu2;

    // alu选择信号
    assign sel_alu_src1_1   = (inst_csrwr1 | inst_csrxchg1) ? 3'b100 : ((inst_jirl1 | inst_bl1 | inst_pcaddu12i1) ? 3'b010 : 3'b001);
    assign sel_alu_src2_1[0]= inst_add_w1 | inst_sub_w1 | inst_slt1 | inst_sltu1 | 
                            inst_mul_w1 | inst_mulh_w1 | inst_mulh_wu1 | inst_div_w1 | inst_div_wu1 | inst_mod_w1 | inst_mod_wu1 |
                            inst_and1 | inst_or1 | inst_xor1 | inst_nor1 |
                            inst_sll_w1 | inst_sra_w1 | inst_sra_w1;  
    assign sel_alu_src2_1[1]= inst_addi_w1 | inst_ld_w1 | inst_ld_h1 | inst_ld_b1 | inst_ld_hu1 | inst_ld_bu1 | inst_st_w1 | inst_st_b1 | inst_st_h1 | inst_slli_w1 |
                            inst_srai_w1 | inst_srli_w1 | inst_lu12i_w1 | inst_pcaddu12i1 | inst_slti1 | inst_sltui1 |
                            inst_andi1 | inst_ori1 | inst_xori1 |
                            inst_cacop_valid1 | inst_ll_w1 | inst_sc_w1 | inst_preld1;
    assign sel_alu_src2_1[2]= inst_jirl1 | inst_bl1;

    assign res_from1[0] = inst_ld_w1 | inst_ld_h1 | inst_ld_b1 | inst_ld_hu1 | inst_ld_bu1 | inst_ll_w1;   //选择内存中取出的数
    assign res_from1[1] = inst_csrrd1 | inst_csrwr1 | inst_csrxchg1 | inst_cpucfg1 | inst_sc_w1;  //使用csr中的数据
    assign res_from1[2] = inst_rdcntid1; //出现rdcnt类信号标志，出现该信号时，注意要写入rd或者rj的值为rdcnt_result
    assign res_from1[3] = inst_rdcntvh_w1;
    assign res_from1[4] = inst_rdcntvl_w1;

    assign sel_alu_src1_2   = (inst_csrwr2 | inst_csrxchg2) ? 3'b100 : ((inst_jirl2 | inst_bl2 | inst_pcaddu12i2) ? 3'b010 : 3'b001);
    assign sel_alu_src2_2[0]= inst_add_w2 | inst_sub_w2 | inst_slt2 | inst_sltu2 | 
                            inst_mul_w2 | inst_mulh_w2 | inst_mulh_wu2 | inst_div_w2 | inst_div_wu2 | inst_mod_w2 | inst_mod_wu2 |
                            inst_and2 | inst_or2 | inst_xor2 | inst_nor2 |
                            inst_sll_w2 | inst_sra_w2 | inst_sra_w2;  
    assign sel_alu_src2_2[1]= inst_addi_w2 | inst_ld_w2 | inst_ld_h2 | inst_ld_b2 | inst_ld_hu2 | inst_ld_bu2 | inst_st_w2 | inst_st_b2 | inst_st_h2 | inst_slli_w2 |
                            inst_srai_w2 | inst_srli_w2 | inst_lu12i_w2 | inst_pcaddu12i2 | inst_slti2 | inst_sltui2 |
                            inst_andi2 | inst_ori2 | inst_xori2 |
                            inst_cacop_valid2 | inst_ll_w2 | inst_sc_w2 | inst_preld2;
    assign sel_alu_src2_2[2]= inst_jirl2 | inst_bl2;

    assign res_from2[0] = inst_ld_w2 | inst_ld_h2 | inst_ld_b2 | inst_ld_hu2 | inst_ld_bu2 | inst_ll_w2;   //选择内存中取出的数
    assign res_from2[1] = inst_csrrd2 | inst_csrwr2 | inst_csrxchg2 | inst_cpucfg2 | inst_sc_w2;  //使用csr中的数据
    assign res_from2[2] = inst_rdcntid2; //出现rdcnt类信号标志，出现该信号时，注意要写入rd或者rj的值为rdcnt_result
    assign res_from2[3] = inst_rdcntvh_w2;
    assign res_from2[4] = inst_rdcntvl_w2;

    // 扩展选择信号
    assign extend_op1[0] = inst_addi_w1 | inst_ld_w1 | inst_ld_h1 | inst_ld_b1 | inst_ld_hu1 | inst_ld_bu1 | inst_st_w1 | inst_st_b1 | inst_st_h1 | inst_slti1 | inst_sltui1 | inst_cacop_valid1 | inst_preld1;  
    assign extend_op1[1] = inst_slli_w1 | inst_srai_w1 | inst_srli_w1; 
    assign extend_op1[2] = inst_lu12i_w1 | inst_pcaddu12i1;
    assign extend_op1[3] = inst_andi1 | inst_ori1 | inst_xori1;
    assign extend_op1[4] = inst_ll_w1 | inst_sc_w1;

    assign extend_op2[0] = inst_addi_w2 | inst_ld_w2 | inst_ld_h2 | inst_ld_b2 | inst_ld_hu2 | inst_ld_bu2 | inst_st_w2 | inst_st_b2 | inst_st_h2 | inst_slti2 | inst_sltui2 | inst_cacop_valid2 | inst_preld2;  
    assign extend_op2[1] = inst_slli_w2 | inst_srai_w2 | inst_srli_w2; 
    assign extend_op2[2] = inst_lu12i_w2 | inst_pcaddu12i2;
    assign extend_op2[3] = inst_andi2 | inst_ori2 | inst_xori2;
    assign extend_op2[4] = inst_ll_w2 | inst_sc_w2;

    // 扩展
    Ext extender1(.sign_imm_12(sign_imm1_12),
                .unsign_imm_12(unsign_imm1_12),
                .unsign_imm_5(unsign_imm1_5),
                .sign_imm_20(sign_imm1_20),
                .sign_imm_14(sign_imm1_14),
                .extend_op(extend_op1),
                .extend_res(extend_res1)
    );

    Ext extender2(.sign_imm_12(sign_imm2_12),
                .unsign_imm_12(unsign_imm2_12),
                .unsign_imm_5(unsign_imm2_5),
                .sign_imm_20(sign_imm2_20),
                .sign_imm_14(sign_imm2_14),
                .extend_op(extend_op2),
                .extend_res(extend_res2)
    );

    //跳转控制信号
    assign br_op1[0]    = inst_bne1;
    assign br_op1[1]    = inst_beq1;
    assign br_op1[2]    = inst_b1;
    assign br_op1[3]    = inst_bl1;
    assign br_op1[4]    = inst_jirl1;
    assign br_op1[5]    = inst_blt1;
    assign br_op1[6]    = inst_bge1;
    assign br_op1[7]    = inst_bltu1;
    assign br_op1[8]    = inst_bgeu1;

    assign br_op2[0]    = inst_bne2;
    assign br_op2[1]    = inst_beq2;
    assign br_op2[2]    = inst_b2;
    assign br_op2[3]    = inst_bl2;
    assign br_op2[4]    = inst_jirl2;
    assign br_op2[5]    = inst_blt2;
    assign br_op2[6]    = inst_bge2;
    assign br_op2[7]    = inst_bltu2;
    assign br_op2[8]    = inst_bgeu2;

    //寄存器写使能信号
    assign gr_we1       = inst_add_w1 | inst_and1 | inst_or1 | inst_xor1 | inst_nor1 | inst_sub_w1 |
                        inst_mul_w1 | inst_mulh_w1 | inst_mulh_wu1 | inst_div_w1 | inst_div_wu1 | inst_mod_w1 | inst_mod_wu1 |
                        inst_slt1 | inst_sltu1 | inst_sll_w1 | inst_srl_w1 | inst_sra_w1 |
                        inst_slli_w1 |inst_srli_w1 | inst_srai_w1 | 
                        inst_addi_w1 | inst_slti1 | inst_sltui1 | inst_lu12i_w1 | inst_pcaddu12i1 |
                        inst_andi1 | inst_ori1 | inst_xori1 |
                        inst_bl1 | inst_jirl1 |
                        inst_ld_w1 | inst_ld_b1 | inst_ld_h1 | inst_ld_bu1 | inst_ld_hu1 | inst_ll_w1 | inst_sc_w1 |
                        inst_csrrd1 | inst_csrwr1 | inst_csrxchg1 | 
                        inst_rdcntid1 | inst_rdcntvh_w1 | inst_rdcntvl_w1 | inst_cpucfg1;

    assign gr_we2       = inst_add_w2 | inst_and2 | inst_or2 | inst_xor2 | inst_nor2 | inst_sub_w2 |
                        inst_mul_w2 | inst_mulh_w2 | inst_mulh_wu2 | inst_div_w2 | inst_div_wu2 | inst_mod_w2 | inst_mod_wu2 |
                        inst_slt2 | inst_sltu2 | inst_sll_w2 | inst_srl_w2 | inst_sra_w2 |
                        inst_slli_w2 |inst_srli_w2 | inst_srai_w2 | 
                        inst_addi_w2 | inst_slti2 | inst_sltui2 | inst_lu12i_w2 | inst_pcaddu12i2 |
                        inst_andi2 | inst_ori2 | inst_xori2 |
                        inst_bl2 | inst_jirl2 |
                        inst_ld_w2 | inst_ld_b2 | inst_ld_h2 | inst_ld_bu2 | inst_ld_hu2 | inst_ll_w2 | inst_sc_w2 |
                        inst_csrrd2 | inst_csrwr2 | inst_csrxchg2 | 
                        inst_rdcntid2 | inst_rdcntvh_w2 | inst_rdcntvl_w2 | inst_cpucfg2;

    //bl指令地址选择信号
    assign inst_no_dest1 = inst_st_w1   | inst_st_h1 | inst_st_b1 
                        | inst_beq1     | inst_bne1  | inst_b1 
                        | inst_blt1     | inst_bltu1 | inst_bge1 | inst_bgeu1
                        | inst_syscall1 | inst_ertn1 | inst_break1
                        | inst_tlbfill1 | inst_tlbsrch1 | inst_tlbrd1 | inst_tlbwr1 | inst_invtlb1
                        | inst_cacop1   | inst_preld1
                        | inst_dbar1    | inst_ibar1;                      

    assign inst_no_dest2 =  inst_st_w2  | inst_st_h2 | inst_st_b2 
                        | inst_beq2     | inst_bne2  | inst_b2 
                        | inst_blt2     | inst_bltu2 | inst_bge2 | inst_bgeu2
                        | inst_syscall2 | inst_ertn2 | inst_break2
                        | inst_tlbfill2 | inst_tlbsrch2 | inst_tlbrd2 | inst_tlbwr2 | inst_invtlb2
                        | inst_cacop2   | inst_preld2
                        | inst_dbar2    | inst_ibar2;
    assign dest1 = inst_bl1 ? 5'd1 : (inst_no_dest1 ? 5'd0 : (dst_is_rj1 ? rj1 : rd1));
    assign dest2 = inst_bl2 ? 5'd1 : (inst_no_dest2 ? 5'd0 : (dst_is_rj2 ? rj2 : rd2));
        //DM_mux选择信号 
    assign sel_rf_res1     = inst_ld_w1 | inst_ld_h1 | inst_ld_b1 | inst_ld_hu1 | inst_ld_bu1 | inst_ll_w1;
    assign sel_rf_res2     = inst_ld_w2 | inst_ld_h2 | inst_ld_b2 | inst_ld_hu2 | inst_ld_bu2 | inst_ll_w2;

    //ld、st等访存信号字节长度
    assign mem_b_size1    = inst_ld_b1 | inst_ld_bu1 | inst_st_b1;  //byte
    assign mem_h_size1    = inst_ld_h1 | inst_ld_hu1 | inst_st_h1;  //halfword
    assign mem_sign_exted1= inst_ld_b1 | inst_ld_h1;               //符号扩展
    assign mem_type1 = {mem_sign_exted1, mem_b_size1, mem_h_size1}; //mem写入或者读取内容类型 
    assign load_op1  = inst_ld_b1 | inst_ld_h1 | inst_ld_w1 | inst_ld_bu1 | inst_ld_hu1 | inst_ll_w1;
    assign store_op1 = inst_st_w1 | inst_st_b1 | inst_st_h1 | (inst_sc_w1 & ID_llbit1);      //TODO llbit在双发中应该怎么处理？

    assign mem_b_size2    = inst_ld_b2 | inst_ld_bu2 | inst_st_b2;  //byte
    assign mem_h_size2    = inst_ld_h2 | inst_ld_hu2 | inst_st_h2;  //halfword
    assign mem_sign_exted2= inst_ld_b2 | inst_ld_h2;               //符号扩展
    assign mem_type2 = {mem_sign_exted2, mem_b_size2, mem_h_size2}; //mem写入或者读取内容类型 
    assign load_op2  = inst_ld_b2 | inst_ld_h2 | inst_ld_w2 | inst_ld_bu2 | inst_ld_hu2 | inst_ll_w2;
    assign store_op2 = inst_st_w2 | inst_st_b2 | inst_st_h2 | (inst_sc_w2 & ID_llbit2);

    //寄存器选择信号
    assign sel_rf_ra2_1  = inst_st_w1 | inst_st_b1 | inst_st_h1 | inst_bne1 | inst_beq1 | inst_bge1 | inst_bgeu1 | inst_jirl1 | inst_csrwr1 | inst_csrxchg1 | inst_blt1 | inst_bltu1 | inst_sc_w1;
    assign sel_rf_ra2_2  = inst_st_w2 | inst_st_b2 | inst_st_h2 | inst_bne2 | inst_beq2 | inst_bge2 | inst_bgeu2 | inst_jirl2 | inst_csrwr2 | inst_csrxchg2 | inst_blt2 | inst_bltu2 | inst_sc_w2;

    assign real_icache_miss = icache_miss & ID_FIFO_valid;

    //有关csr的信号
    assign csr_we1        = inst_csrwr1 | inst_csrxchg1;
    // assign csr_num1       = inst_cpucfg1 ? (rj_value1[13:0]+14'h00b0) : (inst_ertn1 ? 14'h6 : inst1[23:10]);
    assign csr_num1       = (inst_ertn1 ? 14'h6 : inst1[23:10]);
    assign csr_w_mask1    = inst_csrwr1;
    assign dst_is_rj1     = inst_rdcntid1;
    assign invtlb_op1     = rd1;
    assign kernel_inst1   = inst_csrrd1     |
                            inst_csrwr1      |
                            inst_csrxchg1    |
                            inst_tlbsrch1    |
                            inst_tlbrd1      |
                            inst_tlbwr1      |
                            inst_tlbfill1    |
                            inst_invtlb1     |
                            inst_ertn1       |
                            inst_idle1       ;

    assign csr_we2        = inst_csrwr2 | inst_csrxchg2;
    // assign csr_num2       = inst_cpucfg2 ? (rj_value2[13:0]+14'h00b0) : (inst_ertn2 ? 14'h6 : inst2[23:10]);
    assign csr_num2       = (inst_ertn2 ? 14'h6 : inst2[23:10]);
    assign csr_w_mask2    = inst_csrwr2;
    assign dst_is_rj2     = inst_rdcntid2;
    assign invtlb_op2     = rd2;
    assign kernel_inst2   = inst_csrrd2     |
                            inst_csrwr2      |
                            inst_csrxchg2    |
                            inst_tlbsrch2    |
                            inst_tlbrd2      |
                            inst_tlbwr2      |
                            inst_tlbfill2    |
                            inst_invtlb2     |
                            inst_ertn2       |
                            inst_idle2       ;

    //异常与中断处理
    //指令特权等级错例外
    assign excp_ipe1 = kernel_inst1 && (csr_plv == 2'b11);
    assign excp_ipe2 = kernel_inst2 && (csr_plv == 2'b11);
    //指令不存在异常
    assign excp_ine1 = ID_valid & ~(
                        inst_add_w1      |
                        inst_sub_w1      |
                        inst_slt1        |
                        inst_sltu1       |
                        inst_nor1        |
                        inst_and1        |
                        inst_or1         |
                        inst_xor1        |
                        inst_sll_w1      |
                        inst_srl_w1      |
                        inst_sra_w1      |
                        inst_mul_w1      |
                        inst_mulh_w1     |
                        inst_mulh_wu1    |
                        inst_div_w1      |
                        inst_mod_w1      |
                        inst_div_wu1     |
                        inst_mod_wu1     |
                        inst_syscall1    |
                        inst_slli_w1     |
                        inst_srli_w1     |
                        inst_srai_w1     |
                        inst_slti1       |
                        inst_sltui1      |
                        inst_addi_w1     |
                        inst_andi1       |
                        inst_ori1        |
                        inst_xori1       |
                        inst_ld_b1       |
                        inst_ld_h1       |
                        inst_ld_w1       |
                        inst_st_b1       |
                        inst_st_h1       |
                        inst_st_w1       |
                        inst_ld_bu1      |
                        inst_ld_hu1      |
                        inst_jirl1       |
                        inst_b1          |
                        inst_bl1         |
                        inst_beq1        |
                        inst_bne1        |
                        inst_blt1        |
                        inst_bge1        |
                        inst_bltu1       |
                        inst_bgeu1       |
                        inst_lu12i_w1    |
                        inst_pcaddu12i1  |
                        inst_csrrd1      |
                        inst_csrwr1      |
                        inst_csrxchg1    |
                        inst_rdcntid1    |
                        inst_rdcntvh_w1  |
                        inst_rdcntvl_w1  |
                        inst_ertn1       |
                        inst_break1      |
                        inst_tlbsrch1    |
                        inst_tlbrd1      |
                        inst_tlbwr1      |
                        inst_tlbfill1    |
                        inst_cacop_valid1|
                        inst_invtlb1     |
                        inst_cpucfg1     |                      
                        inst_ll_w1       |
                        inst_sc_w1       |
                        inst_dbar1       |
                        inst_ibar1       |  
                        inst_idle1       |
                        inst_nop1        |
                        inst_preld1     )|
    (inst_invtlb1 & (invtlb_op1 > 5'h6)  );

    assign excp_ine2 = ID_valid & ~(
                        inst_add_w2      |
                        inst_sub_w2      |
                        inst_slt2        |
                        inst_sltu2       |
                        inst_nor2        |
                        inst_and2        |
                        inst_or2         |
                        inst_xor2        |
                        inst_sll_w2      |
                        inst_srl_w2      |
                        inst_sra_w2      |
                        inst_mul_w2      |
                        inst_mulh_w2     |
                        inst_mulh_wu2    |
                        inst_div_w2      |
                        inst_mod_w2      |
                        inst_div_wu2     |
                        inst_mod_wu2     |
                        inst_syscall2    |
                        inst_slli_w2     |
                        inst_srli_w2     |
                        inst_srai_w2     |
                        inst_slti2       |
                        inst_sltui2      |
                        inst_addi_w2     |
                        inst_andi2       |
                        inst_ori2        |
                        inst_xori2       |
                        inst_ld_b2       |
                        inst_ld_h2       |
                        inst_ld_w2       |
                        inst_st_b2       |
                        inst_st_h2       |
                        inst_st_w2       |
                        inst_ld_bu2      |
                        inst_ld_hu2      |
                        inst_jirl2       |
                        inst_b2          |
                        inst_bl2         |
                        inst_beq2        |
                        inst_bne2        |
                        inst_blt2        |
                        inst_bge2        |
                        inst_bltu2       |
                        inst_bgeu2       |
                        inst_lu12i_w2    |
                        inst_pcaddu12i2  |
                        inst_csrrd2      |
                        inst_csrwr2      |
                        inst_csrxchg2    |
                        inst_rdcntid2    |
                        inst_rdcntvh_w2  |
                        inst_rdcntvl_w2  |
                        inst_ertn2       |
                        inst_break2      |
                        inst_tlbsrch2    |
                        inst_tlbrd2      |
                        inst_tlbwr2      |
                        inst_tlbfill2    |
                        inst_cacop_valid2|
                        inst_invtlb2     |
                        inst_cpucfg2     |                      
                        inst_ll_w2       |
                        inst_sc_w2       |
                        inst_dbar2       |
                        inst_ibar2       |  
                        inst_idle2       |
                        inst_nop2        |
                        inst_preld2     )|
    (inst_invtlb2 & (invtlb_op2 > 5'h6)  );

    //TODO 异常待定
    assign ID_excp1 = |ID_excp_num1;
    assign ID_excp_num1  = {excp_num1[14:9], excp_ipe1, excp_ine1, inst_break1, inst_syscall1, excp_num1[4:1], has_int};
    
    assign ID_excp2 = |ID_excp_num2;
    assign ID_excp_num2  = {excp_num2[14:9], excp_ipe2, excp_ine2, inst_break2, inst_syscall2, excp_num2[4:1], has_int}; 

        //前递处理
    assign need_rd1 = inst_beq1 | inst_bne1 | inst_bge1 | inst_blt1 | inst_bltu1 | inst_bgeu1 |
                        inst_st_w1 | inst_st_b1 | inst_st_h1 |
                        inst_csrrd1 | inst_csrwr1 | inst_csrxchg1 | inst_cpucfg1 | inst_sc_w1;      
    assign need_rj1 = ~(inst_b1 | inst_bl1 | inst_lu12i_w1 
                        | inst_pcaddu12i1 | inst_csrrd1 | inst_csrwr1 
                        | inst_syscall1 | inst_break1 | 
                        | inst_rdcntvl_w1 | inst_rdcntvh_w1 | inst_rdcntid1
                        | inst_tlbrd1 | inst_tlbsrch1 | inst_tlbfill1 | inst_tlbwr1
                        | inst_dbar1 | inst_ibar1 
                        | inst_idle1);
    assign need_rk1 = ~(inst_slli_w1 | inst_srli_w1 | inst_srai_w1 | inst_addi_w1 
                    | inst_ld_w1 | inst_ld_b1 | inst_ld_bu1 | inst_ld_h1 | inst_ld_hu1
                    | inst_st_w1 | inst_st_h1   | inst_st_b1 
                    | inst_lu12i_w1 | inst_jirl1 
                    | inst_bl1 | inst_b1 | inst_beq1 | inst_bne1 
                    | inst_pcaddu12i1 | inst_slti1 | inst_sltui1 | inst_andi1
                    | inst_ori1 | inst_xori1 | inst_blt1 | inst_bltu1
                    | inst_bge1 | inst_bgeu1
                    | inst_csrrd1 | inst_csrwr1 | inst_csrxchg1 
                    | inst_syscall1 | inst_break1
                    | inst_rdcntvl_w1 | inst_rdcntvh_w1 | inst_rdcntid1
                    | inst_tlbfill1 | inst_tlbrd1 | inst_tlbsrch1 |inst_tlbwr1
                    | inst_cacop1 | inst_sc_w1 | inst_ll_w1
                    | inst_dbar1 | inst_ibar1
                    | inst_idle1 | inst_preld1 | inst_cpucfg1);
    assign need_rkd1 = need_rd1 | need_rk1;

    assign need_rd2 = inst_beq2 | inst_bne2 | inst_bge2 | inst_blt2 | inst_bltu2 | inst_bgeu2 |
                        inst_st_w2 | inst_st_b2 | inst_st_h2 |
                        inst_csrrd2 | inst_csrwr2 | inst_csrxchg2 | inst_cpucfg2 | inst_sc_w2;      
    assign need_rj2 = ~(inst_b2 | inst_bl2 | inst_lu12i_w2 
                        | inst_pcaddu12i2 | inst_csrrd2 | inst_csrwr2 
                        | inst_syscall2 | inst_break2 | 
                        | inst_rdcntvl_w2 | inst_rdcntvh_w2 | inst_rdcntid2
                        | inst_tlbrd2 | inst_tlbsrch2 | inst_tlbfill2 | inst_tlbwr2
                        | inst_dbar2 | inst_ibar2 
                        | inst_idle2);
    assign need_rk2 = ~(inst_slli_w2 | inst_srli_w2 | inst_srai_w2 | inst_addi_w2 
                    | inst_ld_w2 | inst_ld_b2 | inst_ld_bu2 | inst_ld_h2 | inst_ld_hu2
                    | inst_st_w2 | inst_st_h2   | inst_st_b2 
                    | inst_lu12i_w2 | inst_jirl2
                    | inst_bl2 | inst_b2 | inst_beq2 | inst_bne2 
                    | inst_pcaddu12i2 | inst_slti2 | inst_sltui2 | inst_andi2
                    | inst_ori2 | inst_xori2 | inst_blt2 | inst_bltu2
                    | inst_bge2 | inst_bgeu2
                    | inst_csrrd2 | inst_csrwr2 | inst_csrxchg2 
                    | inst_syscall2 | inst_break2
                    | inst_rdcntvl_w2 | inst_rdcntvh_w2 | inst_rdcntid2
                    | inst_tlbfill2 | inst_tlbrd2 | inst_tlbsrch2 |inst_tlbwr2
                    | inst_cacop2 | inst_sc_w2 | inst_ll_w2
                    | inst_dbar2 | inst_ibar2
                    | inst_idle2 | inst_preld2 | inst_cpucfg2);
    assign need_rkd2 = need_rd2 | need_rk2;

    //指令分类    目前是
    // [0] 算术逻辑指令  0、1都是使用ALU，全部可以并行处理
    // [1] 移位逻辑指令
    // [2] 分支跳转指令
    // [3] 访存指令
    // [4] csr指令和tlb指令
    assign inst_issue_way1[0] = inst_add_w1 | inst_sub_w1 | inst_slt1 | inst_sltu1 |
                                inst_mul_w1 | inst_mulh_w1 | inst_mulh_wu1 | 
                                inst_div_w1 | inst_div_wu1 | inst_mod_w1 | inst_mod_wu1 |
                                inst_slti1 | inst_sltui1 | inst_addi_w1 | inst_pcaddu12i1;
    assign inst_issue_way1[1] = inst_and1 | inst_or1 | inst_xor1 | inst_nor1 |
                                inst_slli_w1 | inst_srli_w1 | inst_srai_w1 |
                                inst_lu12i_w1 | inst_andi1 | inst_ori1 | inst_xori1 |
                                inst_sll_w1 | inst_srl_w1 | inst_sra_w1;
    assign inst_issue_way1[2] = inst_jirl1 | inst_bl1 | inst_b1 | inst_beq1 | inst_bne1 |
                                inst_blt1 | inst_bltu1 | inst_bge1 | inst_bgeu1;
    assign inst_issue_way1[3] = inst_ld_w1 | inst_ld_b1 | inst_ld_h1 | inst_ld_bu1 | inst_ld_hu1 |
                                inst_st_w1 | inst_st_b1 | inst_st_h1;
    assign inst_issue_way1[4] = inst_csrrd1 | inst_csrwr1 | inst_csrxchg1 | inst_rdcntid1 |
                                inst_rdcntvl_w1 | inst_rdcntvh_w1 |
                                inst_idle1 | inst_ertn1 | inst_syscall1 | inst_break1 | inst_cacop1 |
                                inst_tlbrd1 | inst_tlbwr1 | inst_tlbfill1 | inst_tlbsrch1| inst_invtlb1 |
                                inst_ll_w1 | inst_sc_w1 | inst_preld1 | inst_ibar1 | inst_dbar1;

    assign inst_issue_way2[0] = inst_add_w2 | inst_sub_w2 | inst_slt2 | inst_sltu2 |
                                inst_mul_w2 | inst_mulh_w2 | inst_mulh_wu2 | 
                                inst_div_w2 | inst_div_wu2 | inst_mod_w2 | inst_mod_wu2 |
                                inst_slti2 | inst_sltui2 | inst_addi_w2 | inst_pcaddu12i2;
    assign inst_issue_way2[1] = inst_and2 | inst_or2 | inst_xor2 | inst_nor2 |
                                inst_slli_w2 | inst_srli_w2 | inst_srai_w2 |
                                inst_lu12i_w2 | inst_andi2 | inst_ori2 | inst_xori2 |
                                inst_sll_w2 | inst_srl_w2 | inst_sra_w2;
    assign inst_issue_way2[2] = inst_jirl2 | inst_bl2 | inst_b2 | inst_beq2 | inst_bne2 |
                                inst_blt2 | inst_bltu2 | inst_bge2 | inst_bgeu2;
    assign inst_issue_way2[3] = inst_ld_w2 | inst_ld_b2 | inst_ld_h2 | inst_ld_bu2 | inst_ld_hu2 |
                                inst_st_w2 | inst_st_b2 | inst_st_h2;
    assign inst_issue_way2[4] = inst_csrrd2 | inst_csrwr2 | inst_csrxchg2 | inst_rdcntid2 |
                                inst_rdcntvl_w2 | inst_rdcntvh_w2 |
                                inst_idle2 | inst_ertn2 | inst_syscall2 | inst_break2 | inst_cacop2 |
                                inst_tlbrd2 | inst_tlbwr2 | inst_tlbfill2 | inst_tlbsrch2 | inst_invtlb2 |
                                inst_ll_w2 | inst_sc_w2 | inst_preld2 | inst_ibar2 | inst_dbar2;
    //TODO 流水线控制
    assign stall_forward    = FIFO_stall || IS_stall || EX_stall || MEM_stall;
    assign stall            = ID_stall || FIFO_stall; //|| IS_stall || EX_stall || MEM_stall;
    assign ID_stall         = 1'b0;//  idle_lock暂时未考虑;
    assign ID_FIFO_valid     = ID_valid && !FIFO_stall; 

    always @(posedge clk)begin
        if(reset) begin
            IF_ID_reg1 <= `WIDTH_IF_ID_BUS'b0;    
            IF_ID_reg2 <= `WIDTH_IF_ID_BUS'b0;  
        end
        else if(~stall) begin
            IF_ID_reg1 <= IF_ID_bus1;
            IF_ID_reg2 <= IF_ID_bus2;
        end
    end

    assign {
        icache_miss,
        inst1_valid,    //1 该指令是否有效
        btb_miss1,      //1
        pred_index1,    //5
        pred_taken1,    //1
        pred_target1,   //32
        excp_num1,      //15
        inst1,          //5
        ID_pc1          //32
    } = IF_ID_reg1;

    assign {
        inst2_valid,    //该指令是否有效
        btb_miss2,
        pred_index2,
        pred_taken2,
        pred_target2,
        excp_num2,
        inst2,
        ID_pc2
    } = IF_ID_reg2;

    always @(posedge clk)begin
        if(reset || flush) begin
            ID_valid <= 1'b0;
        end
        else if(!stall) begin
            ID_valid <= IF_ID_valid;
        end
    end


`ifdef DIFFTEST_EN
    wire [31:0] ID_inst_1;
    wire [31:0] ID_inst_2;
    wire        ID_cnt_inst_1;
    wire        ID_cnt_inst_2;
    wire [ 7:0] ID_inst_ld_en_1;
    wire [ 7:0] ID_inst_ld_en_2;
    wire [ 7:0] ID_inst_st_en_1;
    wire [ 7:0] ID_inst_st_en_2;
    wire        ID_csr_rstat_en_1;
    wire        ID_csr_rstat_en_2;
    

    assign ID_inst_1 = inst1;
    assign ID_inst_2 = inst2;
    assign ID_cnt_inst_1 = inst_rdcntvl_w1 | inst_rdcntvh_w1 | inst_rdcntid1;
    assign ID_cnt_inst_2 = inst_rdcntvl_w2 | inst_rdcntvh_w2 | inst_rdcntid2;
    assign ID_inst_ld_en_1 = {2'b0, inst_ll_w1, inst_ld_w1, inst_ld_hu1, inst_ld_h1, inst_ld_bu1, inst_ld_b1};
    assign ID_inst_ld_en_2 = {2'b0, inst_ll_w2, inst_ld_w2, inst_ld_hu2, inst_ld_h2, inst_ld_bu2, inst_ld_b2};
    assign ID_inst_st_en_1 = {4'b0, ID_llbit1 && inst_sc_w1, inst_st_w1, inst_st_h1, inst_st_b1};
    assign ID_inst_st_en_2 = {4'b0, ID_llbit2 && inst_sc_w2, inst_st_w2, inst_st_h2, inst_st_b2};
    assign ID_csr_rstat_en_1 = (inst_csrrd1 || inst_csrwr1 || inst_csrxchg1) && (csr_num1 == 14'd5);
    assign ID_csr_rstat_en_2 = (inst_csrrd2 || inst_csrwr2 || inst_csrxchg2) && (csr_num2 == 14'd5);

    assign ID_FIFO_diff_bus_1 = {
        ID_inst_1,         // 32
        ID_cnt_inst_1,     // 1
        ID_inst_ld_en_1,   // 8
        ID_inst_st_en_1,   // 8
        ID_csr_rstat_en_1  // 1
    };
    assign ID_FIFO_diff_bus_2 = {
        ID_inst_2,
        ID_cnt_inst_2,
        ID_inst_ld_en_2,
        ID_inst_st_en_2,
        ID_csr_rstat_en_2
    };
`endif

endmodule