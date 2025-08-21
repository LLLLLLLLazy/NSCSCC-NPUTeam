`include "header.h"
module IS(
    input clk,
    input reset,
    input flush, //flush | taken
    input taken_flush,
    input has_int,

    input  [31:0] csr_tlbehi_rvalue,
    input  [ 9:0] csr_asid_asid,
    input FIFO_IS_valid,
    input EX1_stall,
    input EX2_stall,
    input MEM_stall,
`ifdef DEBUG
    input CM_stall,
`endif
    input [`WIDTH_IS_EX1_FORWARD_BUS- 1 : 0]   EX1_forward_bus,
    input [`WIDTH_IS_EX2_FORWARD_BUS- 1 : 0]   EX2_forward_bus,
    input [`WIDTH_IS_MEM_FORWARD_BUS- 1 : 0]   MEM_forward_bus,
`ifdef DIFFTEST_EN
    `ifdef DEBUG
        input [9:0] CM_forward_bus,
    `endif
`endif
    input [`WIDTH_FIFO_IS_BUS - 1 : 0] FIFO_IS_bus1,
    input [`WIDTH_FIFO_IS_BUS - 1 : 0] FIFO_IS_bus2,

    output [`WIDTH_IS_EX1_BUS - 1 : 0] IS_EX1_bus1,
    output [`WIDTH_IS_EX1_BUS - 1 : 0] IS_EX1_bus2,
    output IS_EX1_bus2_valid,
    output IS_EX1_valid,
    output IS_stall,
    
    //regfiles����
    input [31:0] rf_rdata1,
    input [31:0] rf_rdata2,
    input [31:0] rf_rdata3,
    input [31:0] rf_rdata4,

    output [4:0] rf_raddr1,
    output [4:0] rf_raddr2,
    output [4:0] rf_raddr3,
    output [4:0] rf_raddr4

    `ifdef DIFFTEST_EN
        ,
        input      [`DIFF_WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_diff_bus_1,
        input      [`DIFF_WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_diff_bus_2,
        output reg [`DIFF_WIDTH_IS_EX1_BUS-1:0]  IS_EX1_diff_bus_1,
        output reg [`DIFF_WIDTH_IS_EX1_BUS-1:0]  IS_EX1_diff_bus_2
    `endif
);
    //branch
    wire [8:0]  br_op1;
    wire [8:0]  br_op2;
    wire [25:0] offs1_26;
    wire [25:0] offs2_26;
    wire        btb_miss1;
    wire        btb_miss2;
    wire        pred_taken1;
    wire        pred_taken2;
    wire [31:0] pred_target1;
    wire [31:0] pred_target2;
    wire [ 4:0] pred_index1;
    wire [ 4:0] pred_index2;
    //???????????
    wire [4:0] rj1;
    wire [4:0] rk1;
    wire [4:0] rd1;
    wire [4:0] rj2;
    wire [4:0] rk2;
    wire [4:0] rd2;
    wire [31:0] rj_value1;
    wire [31:0] rkd_value1;
    wire [31:0] rj_value2;
    wire [31:0] rkd_value2;
    wire [31:0] rdata_rj1;
    wire [31:0] rdata_rkd1;
    wire [31:0] rdata_rj2;
    wire [31:0] rdata_rkd2;
    wire [ 4:0] dest1;
    wire [ 4:0] dest2;

    //???????
    wire       inst_cpucfg1;
    wire       inst_idle1;
    wire       inst_preld1;
    wire       inst_ll_w1;
    wire       inst_sc_w1;
    wire       inst_cacop_valid1;
    wire [4:0] cacop_code1;
    wire       inst_invtlb1;
    wire [4:0] invtlb_op1;
    wire       inst_tlbwr1;
    wire       inst_tlbfill1;
    wire       inst_tlbsrch1;
    wire       inst_tlbrd1;
    wire       inst_ertn1;
    wire       csr_we1;
    wire       csr_w_mask1;
    wire [13:0]csr_num1;
    wire [ 4:0]res_from1;
    wire       gr_we1;
    wire [2:0] sel_alu_src1_1;
    wire       load_op1;
    wire       store_op1;
    wire [2:0] sel_alu_src2_1;
    wire [2:0] mem_type1;
    wire [31:0]extend_res1;
    wire [18:0]ALU_op1;
    wire [31:0]IS_pc1;

    wire       inst_cpucfg2;
    wire       inst_idle2;
    wire       inst_preld2;
    wire       inst_ll_w2;
    wire       inst_sc_w2;
    wire       inst_cacop_valid2;
    wire [4:0] cacop_code2;
    wire       inst_invtlb2;
    wire [4:0] invtlb_op2;
    wire       inst_tlbwr2;
    wire       inst_tlbfill2;
    wire       inst_tlbsrch2;
    wire       inst_tlbrd2;
    wire       inst_ertn2;
    wire       csr_we2;
    wire       csr_w_mask2;
    wire [13:0]csr_num2;
    wire [ 4:0]res_from2;
    wire       gr_we2;
    wire [2:0] sel_alu_src1_2;
    wire       load_op2;
    wire       store_op2;
    wire [2:0] sel_alu_src2_2;
    wire [2:0] mem_type2;
    wire [31:0]extend_res2;
    wire [18:0]ALU_op2;
    wire [31:0]IS_pc2;

    wire [13:0] IS_csr_num1;
    wire [13:0] IS_csr_num2;

    //TODO ?????????      ??????????????????
    wire FIFO_excp1;
    wire [14:0] FIFO_excp_num1;

    wire FIFO_excp2;
    wire [14:0] FIFO_excp_num2;

    wire IS_excp1;
    wire [14:0] IS_excp_num1;       // ????????

    wire IS_excp2;
    wire [14:0] IS_excp_num2;       // ????????

    wire inst_tlb1;
    wire inst_tlb2;
    wire [31:0] IS_data_vaddr;
    wire [18:0] IS_s1_vppn;

    wire excp_ale1;
    wire [31:0] IS_data_vaddr1;
    wire [18:0] IS_s1_vppn1;
    wire [31:0] alu_src1_1;
    reg  [31:0] alu_src2_1;
    
    wire excp_ale2;
    wire [31:0] IS_data_vaddr2;
    wire [18:0] IS_s1_vppn2;
    wire [31:0] alu_src1_2;
    reg  [31:0] alu_src2_2;

    //???????????
    wire stall;
    wire stall_forward;
    reg IS_valid; 
    wire issue_mode_buf;
    wire IS_mode;

    reg idle_lock;

    reg [`WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_reg1;
    reg [`WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_reg2;

    wire FIFO_full;
    wire FIFO_empty;

    //????????????
    assign IS_EX1_bus1 = {
        FIFO_full,
        FIFO_empty,
        // total 221+43+1
        IS_mode,
        br_op1,         //9
        offs1_26,       //26
        btb_miss1,      //1
        pred_index1,    //5
        pred_taken1,    //1
        pred_target1,   //32
        // 69
        rdata_rj1,          // 32
        rdata_rkd1,         // 32
        dest1,              // 5
        //?? 16
        IS_excp1,           // 1
        IS_excp_num1,       // 15
        //??????? 135
        inst_idle1,
        inst_preld1,        // 1
        inst_ll_w1,         // 1
        inst_sc_w1,         // 1
        inst_cacop_valid1,  // 1
        cacop_code1,        // 5
        inst_invtlb1,       // 1
        invtlb_op1,         // 5
        inst_tlbwr1,        // 1
        inst_tlbfill1,      // 1
        inst_tlbsrch1,      // 1
        inst_tlbrd1,        // 1
        inst_ertn1,         // 1
        csr_we1,            // 1
        IS_csr_num1,        // 14
        res_from1,          // 5
        gr_we1,             // 1
        sel_alu_src1_1,     // 3
        load_op1,           // 1
        store_op1,          // 1
        sel_alu_src2_1,     // 3
        mem_type1,          // 3
        extend_res1,        // 32
        ALU_op1,            // 19
        IS_s1_vppn,        // 19
        csr_asid_asid,
        alu_src1_1,
        alu_src2_1,
        IS_data_vaddr,      // 32
        IS_pc1              // 32
    };

    assign IS_EX1_bus2 = {
        br_op2,         //9
        offs2_26,       //26
        btb_miss2,      //1
        pred_index2,
        pred_taken2,    //1
        pred_target2,   //32
        rdata_rj2,
        rdata_rkd2,
        dest2,
        //??
        IS_excp2,
        IS_excp_num2,
        //???????
        inst_idle2,
        inst_preld2,
        inst_ll_w2,
        inst_sc_w2,
        inst_cacop_valid2,
        cacop_code2,
        inst_invtlb2,
        invtlb_op2,
        inst_tlbwr2,
        inst_tlbfill2,
        inst_tlbsrch2,
        inst_tlbrd2,
        inst_ertn2, 
        csr_we2, 
        IS_csr_num2, 
        res_from2, 
        gr_we2, 
        sel_alu_src1_2, 
        load_op2, 
        store_op2, 
        sel_alu_src2_2, 
        mem_type2, 
        extend_res2, 
        ALU_op2,
        19'b0,  // vppn
        10'b0,  // asid
        alu_src1_2,
        alu_src2_2,
        32'b0,  // vaddr
        IS_pc2
    };

    //�Ĵ�������
    assign rj_value1 = rf_rdata1;
    assign rkd_value1 = rf_rdata2;
    assign rj_value2 = rf_rdata3;
    assign rkd_value2 = rf_rdata4;
`ifdef DIFFTEST_EN
    assign rdata_rj1 = {32{csr_w_mask1}} | rj_value1;
    assign rdata_rkd1 = rkd_value1;
    assign rdata_rj2 = {32{csr_w_mask2}} | rj_value2;
    assign rdata_rkd2 = rkd_value2;
`endif
    assign IS_mode = issue_mode_buf & ~IS_excp1 & IS_valid; //1 jump or ex =>0
    assign IS_EX1_bus2_valid = IS_mode;
    assign IS_csr_num1 = inst_cpucfg1 ? (rdata_rj1[13:0]+14'h00b0) : csr_num1;
    assign IS_csr_num2 = {14{IS_mode}} & ({inst_cpucfg2} ? (rdata_rj2[13:0]+14'h00b0) : csr_num2);

    //??????
    wire [ 4:0] EX1_dest1;
    wire        EX1_data_not_prepared1;
    wire [31:0] EX1_data1;
    wire [ 4:0] EX1_dest2;
    wire        EX1_data_not_prepared2;
    wire [31:0] EX1_data2;
    wire [ 4:0] EX2_dest1;
    wire        EX2_data_not_prepared1;
    wire [31:0] EX2_data1;
    wire [ 4:0] EX2_dest2;
    wire        EX2_data_not_prepared2;
    wire [31:0] EX2_data2;
    wire [ 4:0] MEM_dest1;
    wire        MEM_data_not_prepared1;
    wire [31:0] MEM_data1;
    wire [ 4:0] MEM_dest2;
    wire        MEM_data_not_prepared2;
    wire [31:0] MEM_data2;
`ifdef DIFFTEST_EN
    `ifdef DEBUG
        wire [ 4:0] CM_dest1;
        wire [ 4:0] CM_dest2;
    `endif
`endif

    wire rj_not_zero1;
    wire rkd_not_zero1;
    wire rj_not_zero2;
    wire rkd_not_zero2;

    assign {EX1_dest1, EX1_data_not_prepared1, EX1_data1, EX1_dest2, EX1_data_not_prepared2, EX1_data2} = EX1_forward_bus;       //???????, ??????????????????????????
    assign {EX2_dest1, EX2_data_not_prepared1, EX2_data1, EX2_dest2, EX2_data_not_prepared2, EX2_data2} = EX2_forward_bus;
    assign {MEM_dest1, MEM_data_not_prepared1, MEM_data1, MEM_dest2, MEM_data_not_prepared2, MEM_data2} = MEM_forward_bus;
`ifdef DIFFTEST_EN
    `ifdef DEBUG
        assign {CM_dest1, CM_dest2} = CM_forward_bus;
    `endif
`endif
    assign rj_not_zero1 = |rf_raddr1;
    assign rkd_not_zero1= |rf_raddr2;
    assign rj_not_zero2 = |rf_raddr3;
    assign rkd_not_zero2= |rf_raddr4;

    
    wire stall_caused_by_rj1;
    wire stall_caused_by_rk1;
    wire stall_caused_by_rd1;
    wire stall_data_hazard1 ;
    wire stall_caused_by_rj2;
    wire stall_caused_by_rk2;
    wire stall_caused_by_rd2;
    wire stall_data_hazard2 ;
//�����������ο�
`ifdef DIFFTEST_EN
    `ifdef DEBUG
        assign stall_caused_by_rj1  =   (EX1_dest1 == rj1 || EX1_dest2 == rj1 || EX2_dest1 == rj1 || EX2_dest2 == rj1 || MEM_dest1 == rj1 || MEM_dest2 == rj1 || CM_dest1 == rj1 || CM_dest2 == rj1) && |rj1;
        assign stall_caused_by_rk1  =   (EX1_dest1 == rk1 || EX1_dest2 == rk1 || EX2_dest1 == rk1 || EX2_dest2 == rk1 || MEM_dest1 == rk1 || MEM_dest2 == rk1 || CM_dest1 == rk1 || CM_dest2 == rk1) && |rk1;
        assign stall_caused_by_rd1  =   (EX1_dest1 == rd1 || EX1_dest2 == rd1 || EX2_dest1 == rd1 || EX2_dest2 == rd1 || MEM_dest1 == rd1 || MEM_dest2 == rd1 || CM_dest1 == rd1 || CM_dest2 == rd1) && |rd1;

        assign stall_data_hazard1   =   stall_caused_by_rj1 && need_rj1 || stall_caused_by_rk1 && need_rk1 || stall_caused_by_rd1 && need_rd1;

        assign stall_caused_by_rj2  =   (EX1_dest1 == rj2 || EX1_dest2 == rj2 || EX2_dest1 == rj2 || EX2_dest2 == rj2 || MEM_dest1 == rj2 || MEM_dest2 == rj2 || CM_dest1 == rj2 || CM_dest2 == rj2) && |rj2;
        assign stall_caused_by_rk2  =   (EX1_dest1 == rk2 || EX1_dest2 == rk2 || EX2_dest1 == rk2 || EX2_dest2 == rk2 || MEM_dest1 == rk2 || MEM_dest2 == rk2 || CM_dest1 == rk2 || CM_dest2 == rk2) && |rk2;
        assign stall_caused_by_rd2  =   (EX1_dest1 == rd2 || EX1_dest2 == rd2 || EX2_dest1 == rd2 || EX2_dest2 == rd2 || MEM_dest1 == rd2 || MEM_dest2 == rd2 || CM_dest1 == rd2 || CM_dest2 == rd2) && |rd2;

        assign stall_data_hazard2   =   stall_caused_by_rj2 && need_rj2 || stall_caused_by_rk2 && need_rk2 || stall_caused_by_rd2 && need_rd2;
    `else
        assign stall_caused_by_rj1  =   (EX1_dest1 == rj1 || EX1_dest2 == rj1 || EX2_dest1 == rj1 || EX2_dest2 == rj1 || MEM_dest1 == rj1 || MEM_dest2 == rj1) && |rj1;
        assign stall_caused_by_rk1  =   (EX1_dest1 == rk1 || EX1_dest2 == rk1 || EX2_dest1 == rk1 || EX2_dest2 == rk1 || MEM_dest1 == rk1 || MEM_dest2 == rk1) && |rk1;
        assign stall_caused_by_rd1  =   (EX1_dest1 == rd1 || EX1_dest2 == rd1 || EX2_dest1 == rd1 || EX2_dest2 == rd1 || MEM_dest1 == rd1 || MEM_dest2 == rd1) && |rd1;

        assign stall_data_hazard1   =   stall_caused_by_rj1 && need_rj1 || stall_caused_by_rk1 && need_rk1 || stall_caused_by_rd1 && need_rd1;

        assign stall_caused_by_rj2  =   (EX1_dest1 == rj2 || EX1_dest2 == rj2 || EX2_dest1 == rj2 || EX2_dest2 == rj2 || MEM_dest1 == rj2 || MEM_dest2 == rj2) && |rj2;
        assign stall_caused_by_rk2  =   (EX1_dest1 == rk2 || EX1_dest2 == rk2 || EX2_dest1 == rk2 || EX2_dest2 == rk2 || MEM_dest1 == rk2 || MEM_dest2 == rk2) && |rk2;
        assign stall_caused_by_rd2  =   (EX1_dest1 == rd2 || EX1_dest2 == rd2 || EX2_dest1 == rd2 || EX2_dest2 == rd2 || MEM_dest1 == rd2 || MEM_dest2 == rd2) && |rd2;

        assign stall_data_hazard2   =   stall_caused_by_rj2 && need_rj2 || stall_caused_by_rk2 && need_rk2 || stall_caused_by_rd2 && need_rd2;
    `endif
`else

    //��·�����ź�����
    wire need_rkd1 = need_rk1 || need_rd1;
    wire need_rkd2 = need_rk2 || need_rd2;
    reg [6:0] rj_sel1;
    reg [6:0] rkd_sel1;
    always @(*)begin
        //rj1
        if     (EX1_dest1 == rf_raddr1 && rj_not_zero1 && need_rj1)
            rj_sel1 = 7'b0000010;
        else if(EX1_dest2 == rf_raddr1 && rj_not_zero1 && need_rj1)
            rj_sel1 = 7'b0000100;

        else if(EX2_dest1 == rf_raddr1 && rj_not_zero1 && need_rj1)
            rj_sel1 = 7'b0001000;
        else if(EX2_dest2 == rf_raddr1 && rj_not_zero1 && need_rj1)
            rj_sel1 = 7'b0010000;

        else if(MEM_dest1 == rf_raddr1 && rj_not_zero1 && need_rj1)
            rj_sel1 = 7'b0100000;
        else if(MEM_dest2 == rf_raddr1 && rj_not_zero1 && need_rj1)
            rj_sel1 = 7'b1000000;

        else rj_sel1 = 7'b0000001;
    end

    always @(*)begin
        //rkd1
        if     (EX1_dest1 == rf_raddr2 && rkd_not_zero1 && need_rkd1)
            rkd_sel1 = 7'b0000010;
        else if(EX1_dest2 == rf_raddr2 && rkd_not_zero1 && need_rkd1)
            rkd_sel1 = 7'b0000100;

        else if(EX2_dest1 == rf_raddr2 && rkd_not_zero1 && need_rkd1)
            rkd_sel1 = 7'b0001000;
        else if(EX2_dest2 == rf_raddr2 && rkd_not_zero1 && need_rkd1)
            rkd_sel1 = 7'b0010000;

        else if(MEM_dest1 == rf_raddr2 && rkd_not_zero1 && need_rkd1)
            rkd_sel1 = 7'b0100000;
        else if(MEM_dest2 == rf_raddr2 && rkd_not_zero1 && need_rkd1)
            rkd_sel1 = 7'b1000000;

        else rkd_sel1 = 7'b0000001;
    end

    reg [6:0] rj_sel2;
    reg [6:0] rkd_sel2;
    always @(*)begin
        //rj2
        if     (EX1_dest1 == rf_raddr3 && rj_not_zero2 && need_rj2)
            rj_sel2 = 7'b0000010;
        else if(EX1_dest2 == rf_raddr3 && rj_not_zero2 && need_rj2)
            rj_sel2 = 7'b0000100;

        else if(EX2_dest1 == rf_raddr3 && rj_not_zero2 && need_rj2)
            rj_sel2 = 7'b0001000;
        else if(EX2_dest2 == rf_raddr3 && rj_not_zero2 && need_rj2)
            rj_sel2 = 7'b0010000;

        else if(MEM_dest1 == rf_raddr3 && rj_not_zero2 && need_rj2)
            rj_sel2 = 7'b0100000;
        else if(MEM_dest2 == rf_raddr3 && rj_not_zero2 && need_rj2)
            rj_sel2 = 7'b1000000;

        else rj_sel2 = 7'b0000001;
    end

    always @(*)begin
        //rkd2
        if     (EX1_dest1 == rf_raddr4 && rkd_not_zero2 && need_rkd2)
            rkd_sel2 = 7'b0000010;
        else if(EX1_dest2 == rf_raddr4 && rkd_not_zero2 && need_rkd2)
            rkd_sel2 = 7'b0000100;

        else if(EX2_dest1 == rf_raddr4 && rkd_not_zero2 && need_rkd2)
            rkd_sel2 = 7'b0001000;
        else if(EX2_dest2 == rf_raddr4 && rkd_not_zero2 && need_rkd2)
            rkd_sel2 = 7'b0010000;

        else if(MEM_dest1 == rf_raddr4 && rkd_not_zero2 && need_rkd2)
            rkd_sel2 = 7'b0100000;
        else if(MEM_dest2 == rf_raddr4 && rkd_not_zero2 && need_rkd2)
            rkd_sel2 = 7'b1000000;

        else rkd_sel2 = 7'b0000001;
    end

    //��·ѡ����
    assign rdata_rj1 = csr_w_mask1 ? 32'hFFFF_FFFF :  (({32{rj_sel1[0]}} & rj_value1)
                                                    |({32{rj_sel1[1]}} & EX1_data1)
                                                    |({32{rj_sel1[2]}} & EX1_data2)
                                                    |({32{rj_sel1[3]}} & EX2_data1)
                                                    |({32{rj_sel1[4]}} & EX2_data2)
                                                    |({32{rj_sel1[5]}} & MEM_data1)
                                                    |({32{rj_sel1[6]}} & MEM_data2));
    assign rdata_rkd1 = (({32{rkd_sel1[0]}} & rkd_value1)
                        |({32{rkd_sel1[1]}} & EX1_data1)
                        |({32{rkd_sel1[2]}} & EX1_data2)
                        |({32{rkd_sel1[3]}} & EX2_data1)
                        |({32{rkd_sel1[4]}} & EX2_data2)
                        |({32{rkd_sel1[5]}} & MEM_data1)
                        |({32{rkd_sel1[6]}} & MEM_data2));
    assign rdata_rj2 = csr_w_mask2 ? 32'hFFFF_FFFF : (({32{rj_sel2[0]}} & rj_value2)
                                                    |({32{rj_sel2[1]}} & EX1_data1)
                                                    |({32{rj_sel2[2]}} & EX1_data2)
                                                    |({32{rj_sel2[3]}} & EX2_data1)
                                                    |({32{rj_sel2[4]}} & EX2_data2)
                                                    |({32{rj_sel2[5]}} & MEM_data1)
                                                    |({32{rj_sel2[6]}} & MEM_data2));
    assign rdata_rkd2 = (({32{rkd_sel2[0]}} & rkd_value2)
                        |({32{rkd_sel2[1]}} & EX1_data1)
                        |({32{rkd_sel2[2]}} & EX1_data2)
                        |({32{rkd_sel2[3]}} & EX2_data1)
                        |({32{rkd_sel2[4]}} & EX2_data2)
                        |({32{rkd_sel2[5]}} & MEM_data1)
                        |({32{rkd_sel2[6]}} & MEM_data2));

    assign stall_caused_by_rj1=(EX1_dest1 == rj1 && EX1_data_not_prepared1 || EX1_dest2 == rj1 && EX1_data_not_prepared2 || 
                                EX2_dest1 == rj1 && EX2_data_not_prepared1 || EX2_dest2 == rj1 && EX2_data_not_prepared2 || 
                                MEM_dest1 == rj1 && MEM_data_not_prepared1 || MEM_dest2 == rj1 && MEM_data_not_prepared2) 
                                && |rj1;
    assign stall_caused_by_rk1=(EX1_dest1 == rk1 && EX1_data_not_prepared1 || EX1_dest2 == rk1 && EX1_data_not_prepared2 || 
                                EX2_dest1 == rk1 && EX2_data_not_prepared1 || EX2_dest2 == rk1 && EX2_data_not_prepared2 ||
                                MEM_dest1 == rk1 && MEM_data_not_prepared1 || MEM_dest2 == rk1 && MEM_data_not_prepared2) 
                                && |rk1;
    assign stall_caused_by_rd1=(EX1_dest1 == rd1 && EX1_data_not_prepared1 || EX1_dest2 == rd1 && EX1_data_not_prepared2 ||
                                EX2_dest1 == rd1 && EX2_data_not_prepared1 || EX2_dest2 == rd1 && EX2_data_not_prepared2 ||
                                MEM_dest1 == rd1 && MEM_data_not_prepared1 || MEM_dest2 == rd1 && MEM_data_not_prepared2) 
                                && |rd1;
    assign stall_data_hazard1 =stall_caused_by_rj1 && need_rj1 || stall_caused_by_rk1 && need_rk1 || stall_caused_by_rd1 && need_rd1;


    assign stall_caused_by_rj2=(EX1_dest1 == rj2 && EX1_data_not_prepared1 || EX1_dest2 == rj2 && EX1_data_not_prepared2 || 
                                EX2_dest1 == rj2 && EX2_data_not_prepared1 || EX2_dest2 == rj2 && EX2_data_not_prepared2 || 
                                MEM_dest1 == rj2 && MEM_data_not_prepared1 || MEM_dest2 == rj2 && MEM_data_not_prepared2) 
                                && |rj2;
    assign stall_caused_by_rk2=(EX1_dest1 == rk2 && EX1_data_not_prepared1 || EX1_dest2 == rk2 && EX1_data_not_prepared2 || 
                                EX2_dest1 == rk2 && EX2_data_not_prepared1 || EX2_dest2 == rk2 && EX2_data_not_prepared2 ||
                                MEM_dest1 == rk2 && MEM_data_not_prepared1 || MEM_dest2 == rk2 && MEM_data_not_prepared2) 
                                && |rk2;
    assign stall_caused_by_rd2=(EX1_dest1 == rd2 && EX1_data_not_prepared1 || EX1_dest2 == rd2 && EX1_data_not_prepared2 ||
                                EX2_dest1 == rd2 && EX2_data_not_prepared1 || EX2_dest2 == rd2 && EX2_data_not_prepared2 ||
                                MEM_dest1 == rd2 && MEM_data_not_prepared1 || MEM_dest2 == rd2 && MEM_data_not_prepared2) 
                                && |rd2;
    assign stall_data_hazard2  =stall_caused_by_rj2 && need_rj2 || stall_caused_by_rk2 && need_rk2 || stall_caused_by_rd2 && need_rd2;

`endif
    //��ˮ�߿���
    assign IS_stall = idle_lock | ~reset & (IS_valid && (stall_data_hazard1 || stall_data_hazard2)); 
    assign stall_forward = EX1_stall || EX2_stall || MEM_stall;
`ifdef DEBUG
    assign stall = IS_stall || EX1_stall || EX2_stall || MEM_stall || CM_stall;
`else
    assign stall = IS_stall || EX1_stall || EX2_stall || MEM_stall;
`endif
    assign IS_EX1_valid = IS_valid && !IS_stall & ~idle_lock;

    always @(posedge clk)begin
        if(reset) begin
            FIFO_IS_reg1 <= `WIDTH_FIFO_IS_BUS'b0;   
            FIFO_IS_reg2 <= `WIDTH_FIFO_IS_BUS'b0;  
        end
        else if(~stall) begin
            FIFO_IS_reg1 <= FIFO_IS_bus1;
            FIFO_IS_reg2 <= FIFO_IS_bus2;
        end
    end

    assign {
        FIFO_full,
        FIFO_empty,
        issue_mode_buf,
        br_op1,         //9
        offs1_26,       //26
        rj1,            //5
        rk1,            //5
        rd1,            //5
        rf_raddr1,      //5
        rf_raddr2,      //5
        need_rj1,       //1
        need_rk1,       //1
        need_rd1,       //1
        dest1,          //5

        inst_cpucfg1,    //1
        inst_idle1,     //1
        inst_preld1,    //1
        inst_ll_w1,     //1
        inst_sc_w1,     //1
        inst_cacop_valid1, //1
        cacop_code1,    //5
        inst_invtlb1,   //1
        invtlb_op1,     //5
        inst_tlbwr1,    //1
        inst_tlbfill1,  //1
        inst_tlbsrch1,  //1
        inst_tlbrd1,    //1
        inst_ertn1,     //1
        csr_we1,        //1
        csr_num1,       //14
        csr_w_mask1,    //1
        res_from1,      //5
        gr_we1,         //1
        sel_alu_src1_1, //3
        load_op1,       //1
        store_op1,      //1
        sel_alu_src2_1, //3
        mem_type1,      //3
        btb_miss1,      //1
        pred_index1,    //5
        pred_taken1,    //1
        pred_target1,   //32
        FIFO_excp_num1,   //15
        FIFO_excp1,       //1
        extend_res1,    //32
        ALU_op1,        //19
        IS_pc1          //32
    } = FIFO_IS_reg1;

    assign {
        br_op2,         //9
        offs2_26,       //26
        rj2,
        rk2,
        rd2,
        rf_raddr3,
        rf_raddr4,
        need_rj2,
        need_rk2,
        need_rd2,
        dest2,

        inst_cpucfg2,
        inst_idle2,
        inst_preld2,
        inst_ll_w2,
        inst_sc_w2,
        inst_cacop_valid2,
        cacop_code2,
        inst_invtlb2,
        invtlb_op2,
        inst_tlbwr2,
        inst_tlbfill2,
        inst_tlbsrch2,
        inst_tlbrd2,
        inst_ertn2, 
        csr_we2, 
        csr_num2, 
        csr_w_mask2,
        res_from2, 
        gr_we2, 
        sel_alu_src1_2, 
        load_op2, 
        store_op2, 
        sel_alu_src2_2, 
        mem_type2, 
        btb_miss2,
        pred_index2,
        pred_taken2,
        pred_target2,
        FIFO_excp_num2,
        FIFO_excp2,
        extend_res2, 
        ALU_op2, 
        IS_pc2
    } = FIFO_IS_reg2;

    //???????????
    always @(posedge clk)begin
        if(reset || flush || taken_flush) begin
            IS_valid <= 1'b0;
        end
        else if(!stall) begin
            IS_valid <= FIFO_IS_valid;
        end
    end
    assign inst_tlb1 = inst_invtlb1 | inst_tlbwr1 | inst_tlbfill1 | inst_tlbsrch1 | inst_tlbrd1;
    assign inst_tlb2 = inst_invtlb2 | inst_tlbwr2 | inst_tlbfill2 | inst_tlbsrch2 | inst_tlbrd2;
    assign IS_s1_vppn     = {19{load_op1 |store_op1 | inst_cacop_valid1 | inst_tlb1}} & IS_s1_vppn1 |
                            {19{load_op2 |store_op2 | inst_cacop_valid2 | inst_tlb2}} & IS_s1_vppn2;
    assign IS_data_vaddr = {32{load_op1 | store_op1 | inst_cacop_valid1 | inst_tlb1}} & IS_data_vaddr1 |
                           {32{load_op2 | store_op2 | inst_cacop_valid2 | inst_tlb2}} & IS_data_vaddr2;

    wire ale_1_0;
    wire ale_1_1;
    wire ale_2_0;
    wire ale_2_1;
    assign {ale_1_1, ale_1_0} = rdata_rj1[1:0] + extend_res1[1:0];
    assign {ale_2_1, ale_2_0} = rdata_rj2[1:0] + extend_res2[1:0];

    assign inst_tlb1 = inst_invtlb1 | inst_tlbwr1 | inst_tlbfill1 | inst_tlbsrch1 | inst_tlbrd1;
    assign inst_tlb2 = inst_invtlb2 | inst_tlbwr2 | inst_tlbfill2 | inst_tlbsrch2 | inst_tlbrd2;
    assign IS_data_vaddr = {32{load_op1 | store_op1 | inst_cacop_valid1 | inst_tlb1}} & IS_data_vaddr1 |
                           {32{load_op2 | store_op2 | inst_cacop_valid2 | inst_tlb2}} & IS_data_vaddr2;

    assign IS_data_vaddr1 = rdata_rj1 + extend_res1;
    assign excp_ale1 = (load_op1 | store_op1) & 
                      ((!mem_type1[1:0] & (ale_1_0 | ale_1_1)) |
                       ( mem_type1[0]   &  ale_1_0));

    assign IS_excp_num1 = {FIFO_excp_num1[14:10], excp_ale1, FIFO_excp_num1[8:1], has_int};
    assign IS_excp1 = |IS_excp_num1;
    assign IS_s1_vppn1 = {19{ inst_tlbsrch1}} & csr_tlbehi_rvalue[31:13] |
                         {19{~inst_tlbsrch1}} & IS_data_vaddr1[31:13];
    assign alu_src1_1 = {32{sel_alu_src1_1[0]}} & rdata_rj1 |
                        {32{sel_alu_src1_1[1]}} & IS_pc1;
    always @(*) begin
        case(sel_alu_src2_1)
            3'b001:  alu_src2_1 = rdata_rkd1;
            3'b010:  alu_src2_1 = extend_res1;
            3'b100:  alu_src2_1 = 32'd4;
            default: alu_src2_1 = rdata_rkd1;
        endcase 
    end

    assign IS_data_vaddr2 = rdata_rj2 + extend_res2;
    assign excp_ale2 = (load_op2 | store_op2) & 
                      ((!mem_type2[1:0] & (ale_2_0 | ale_2_1)) |
                       ( mem_type2[0]   &  ale_2_0));
    assign IS_excp_num2 = {FIFO_excp_num2[14:10], excp_ale2, FIFO_excp_num2[8:0]};
    assign IS_excp2 = FIFO_excp2 | excp_ale2;
    assign IS_s1_vppn2 = {19{ inst_tlbsrch2}} & csr_tlbehi_rvalue[31:13] |
                         {19{~inst_tlbsrch2}} & IS_data_vaddr2[31:13];

    assign alu_src1_2 = {32{sel_alu_src1_2[0]}} & rdata_rj2 |
                        {32{sel_alu_src1_2[1]}} & IS_pc2;
    always @(*) begin
        case(sel_alu_src2_2)
            3'b001:  alu_src2_2 = rdata_rkd2;
            3'b010:  alu_src2_2 = extend_res2;
            3'b100:  alu_src2_2 = 32'd4;
            default: alu_src2_2 = rdata_rkd2;
        endcase 
    end

`ifdef DEBUG
    always @(posedge clk)begin
        if(reset | flush)
            idle_lock <= 0;
        //idleִ��
        else if(IS_valid & ((!(|IS_excp_num1)) & (inst_idle1) | (!(|IS_excp_num2)) & (inst_idle2) & IS_mode) & !(EX1_stall | EX2_stall | MEM_stall | CM_stall))
            idle_lock <= 1;
        //�жϻ���
        else if(has_int)
            idle_lock <= 0;
    end
`else
    always @(posedge clk)begin
        if(reset | flush)
            idle_lock <= 0;
        //idleִ��
        else if(IS_valid & ((!(|IS_excp_num1)) & (inst_idle1) | (!(|IS_excp_num2)) & (inst_idle2) & IS_mode) & !(EX1_stall | EX2_stall | MEM_stall))
            idle_lock <= 1;
        //�жϻ���
        else if(has_int)
            idle_lock <= 0;
    end
`endif

`ifdef DIFFTEST_EN
    always@(posedge clk) begin
        if(reset | flush | taken_flush) begin
            IS_EX1_diff_bus_1 <= 0;
            IS_EX1_diff_bus_2 <= 0;
        end
        else if(~stall) begin
            IS_EX1_diff_bus_1 <= FIFO_IS_diff_bus_1;
            IS_EX1_diff_bus_2 <= FIFO_IS_diff_bus_2;
        end
    end
`endif
endmodule