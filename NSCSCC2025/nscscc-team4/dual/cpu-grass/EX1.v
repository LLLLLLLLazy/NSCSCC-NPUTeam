`include "header.h"
module EX1(
    input clk,
    input reset,
    input flush,

    input  EX2_stall,
    input  MEM_stall,
    input  CM_stall,
    output EX1_stall,
    //branch
    output br_taken,
    output [31:0] br_target,
    output [76:0] btb_bus,
    // output operate_en,
    // output add_entry,
    // output pred_error,
    // output target_error,
    // output pred_right,
    // output right_orien,
    // output [31:0] right_target,
    // output [ 4:0] operate_index,
    // output [31:0] operate_pc,
    // output        push_ras,
    // output        pop_ras,

    input     IS_EX1_valid,
    output    EX1_EX2_valid,
    input     IS_EX1_bus2_valid,
    output    EX1_EX2_bus2_valid,
    input  [`WIDTH_IS_EX1_BUS -1:0] IS_EX1_bus1,
    input  [`WIDTH_IS_EX1_BUS -1:0] IS_EX1_bus2,
    output [`WIDTH_EX1_EX2_BUS-1:0] EX1_EX2_bus1,
    output [`WIDTH_EX1_EX2_BUS-1:0] EX1_EX2_bus2,

    // with mmu (a or b pipeline)
    // input  [ 9:0] csr_asid_asid,
    input  [89+`WIDTH_TLB_INDEX:0] tlb_data,
    input  [ 4:0] EX1_tlb_excps,
    input         mmu_data_uncache_en,    
    input         mmu_sc_addr_eq,
    input  [31:0] sc_ll_paddr,
    input  [31:0] EX1_data_paddr,
    output [31:0] EX1_data_vaddr,
    output        EX1_load,
    output        EX1_store,
    output        EX1_cacop,
    output [1:0] EX1_cache_op_mode, //to mmu

    //to cache
    input  icache_unbusy,
    input  dcache_unbusy,    
    input  dcache_hit,
    output data_valid,

    output [ 7:0] data_index,
    output [ 3:0] data_offset,
    output [ 3:0] data_wstrb,
    output [ 2:0] data_size,
    output [31:0] data_wdata,
    output        data_op,

    output [ 1:0] cache_op_mode,
    output        icacop_op_en,
    output        dcacop_op_en,

    output preld_en,

    //to TLB (a or b pipeline)
    input  data_unhit,
    output s1_valid,
    input  s1_ok,
    output [18:0] s1_vppn,
    output        s1_va_bit12,
    output [ 9:0] s1_asid,

    //forward
    output [`WIDTH_EX1_FORWARD_BUS-1:0] EX1_forward_bus1,
    output [`WIDTH_EX1_FORWARD_BUS-1:0] EX1_forward_bus2

    `ifdef DIFFTEST_EN
        ,
        input  [`DIFF_WIDTH_IS_EX1_BUS -1: 0] IS_EX1_diff_bus_1,
        input  [`DIFF_WIDTH_IS_EX1_BUS -1: 0] IS_EX1_diff_bus_2,
        output [`DIFF_WIDTH_EX1_EX2_BUS-1 :0] EX1_EX2_diff_bus_1,
        output [`DIFF_WIDTH_EX1_EX2_BUS-1 :0] EX1_EX2_diff_bus_2
    `endif
);
    wire        operate_en;
    wire        add_entry;
    wire        pred_error;
    wire        target_error;
    wire        pred_right;
    wire        right_orien;
    wire [31:0] right_target;
    wire [ 4:0] operate_index;
    wire [31:0] operate_pc;
    wire        push_ras;
    wire        pop_ras;
    wire        btb_mode; //0:1, 1:2
    assign btb_bus = {
        btb_mode,
        add_entry,
        pred_error,
        target_error,
        pred_right,
        right_orien,
        right_target,
        operate_index,
        operate_pc,
        push_ras,
        pop_ras
    };
// branch predict
    wire taken_update_en_1 ;
    wire taken_update_en_2 ;
    wire target_update_en_1;
    wire target_update_en_2;

//control
    wire stall;
    wire stall_dcache;
    wire stall_nEX2;
    reg  EX1_valid;
    wire IS_mode_buffer;

    wire access_dcache;
    wire access_dcache1;
    wire access_dcache2;

    wire op_icache;
    wire op_icache1;
    wire op_icache2;
    wire icacop_op_en1;
    wire icacop_op_en2;

    wire op_dcache;
    wire op_dcache1;
    wire op_dcache2;
    wire dcacop_op_en1;
    wire dcacop_op_en2;

    wire preld_en1;
    wire preld_en2;
    
    reg s1_ok_buf;
    reg s1_valid_reg;
    wire tlb_trans;
    reg  tlb_trans_reg;

    reg first_clk;
//branch
    wire taken;
    wire [31:0] target;

    wire rj_equal_rd1;
    wire s_rj_smaller_rd1;
    wire us_rj_smaller_rd1;

    wire rj_equal_rd2;
    wire s_rj_smaller_rd2;
    wire us_rj_smaller_rd2;

    wire br_taken1;
    wire taken1;
    wire [31:0] br_target1;
    wire [ 4:0] pred_index1;
    wire add_entry1;
    wire pred_error1;
    wire pred_right1;
    wire target_error1;
    wire btb_error1;

    wire br_taken2;
    wire taken2;
    wire [31:0] br_target2;
    wire [ 4:0] pred_index2;
    wire add_entry2;
    wire pred_error2;
    wire pred_right2;
    wire target_error2;
    wire btb_error2;

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
    wire        br_inst;
    wire        br_inst1;
    wire        br_inst2;

//regfile
    wire        gr_we1;
    wire        gr_we2;
    wire [ 4:0] dest1;
    wire [ 4:0] dest2;
//forward data
    wire [31:0] EX1_data1;
    wire [31:0] EX1_data2;    
    wire [ 4:0] EX1_dest1;
    wire [ 4:0] EX1_dest2;   
    wire EX1_data_not_prepared1;
    wire EX1_data_not_prepared2;    
    wire EX1_data_used1;
    wire EX1_data_used2;
//cache
    wire [ 3:0] bpos;
    wire [ 1:0] hpos;
    wire [31:0] bwdata1;
    wire [31:0] bwdata2;
    wire [31:0] hwdata1;
    wire [31:0] hwdata2;
    wire [ 3:0] EX1_data_wstrb;
    wire [31:0] EX1_data_wdata1;
    wire [31:0] EX1_data_wdata2;
    wire [ 2:0] EX1_data_size;
//mmu
    wire [31:0] IS_data_vaddr1;
    wire [31:0] IS_data_vaddr2;
    wire [18:0] IS_s1_vppn1;
    wire [18:0] IS_s1_vppn2;
    wire [31:0] EX1_data_paddr1;
    wire [31:0] EX1_data_paddr2;
    wire [31:0] sc_ll_paddr1;
    wire [31:0] sc_ll_paddr2;
    wire mmu_data_uncache_en1;
    wire mmu_data_uncache_en2;
    wire mmu_sc_addr_eq1;
    wire mmu_sc_addr_eq2;
//tlb
    wire [4:0]  tlb_op1;
    wire [4:0]  tlb_op2;
    wire [89+`WIDTH_TLB_INDEX:0] tlb_data1;
    wire [89+`WIDTH_TLB_INDEX:0] tlb_data2;

    wire [ 9:0] invtlb_asid1;
    wire [ 9:0] invtlb_asid2;
    wire [18:0] invtlb_vppn1;
    wire [18:0] invtlb_vppn2;
    wire        inst_invtlb1;
    wire        inst_invtlb2;
    wire [ 4:0] invtlb_op1;
    wire [ 4:0] invtlb_op2;

    wire [ 9:0] csr_asid_asid1;
    wire [ 9:0] csr_asid_asid2;

// load & store
    wire EX1_load_op1;
    wire EX1_load_op2;
    wire EX1_store_op1;
    wire EX1_store_op2;
    wire [ 2:0] EX1_mem_type1;
    wire [ 2:0] EX1_mem_type2;
// bus
    reg [`WIDTH_IS_EX1_BUS-1:0] IS_EX1_bus_reg1;
    reg [`WIDTH_IS_EX1_BUS-1:0] IS_EX1_bus_reg2;
    wire inst_idle1;
    wire inst_idle2;
    wire inst_ll_w1;
    wire inst_ll_w2;
    wire inst_sc_w1;
    wire inst_sc_w2;
    wire inst_preld1;
    wire inst_preld2;
    wire inst_cacop_valid1;
    wire inst_cacop_valid2;
    wire [ 4:0] cacop_code1;
    wire [ 4:0] cacop_code2;
    wire inst_tlbwr1;
    wire inst_tlbwr2;
    wire inst_tlbfill1;
    wire inst_tlbfill2;
    wire inst_tlbsrch1;
    wire inst_tlbsrch2;
    wire inst_tlbrd1;
    wire inst_tlbrd2;
    wire inst_ertn1;
    wire inst_ertn2;
    wire csr_we1;
    wire csr_we2;
    wire [13:0] csr_num1;
    wire [13:0] csr_num2;
    wire [ 4:0] res_from1;
    wire [ 4:0] res_from2;

    wire [31:0] EX1_pc1;
    wire [31:0] EX1_pc2;
//alu
    wire [ 2:0] sel_alu_src1_1;
    wire [ 2:0] sel_alu_src1_2;
    wire [ 2:0] sel_alu_src2_1;
    wire [ 2:0] sel_alu_src2_2;
    wire [18:0] alu_op1;
    wire [18:0] alu_op2;
    wire [31:0] extend_res1;
    wire [31:0] extend_res2;
    wire [31:0] EX1_rdata_rj1;
    wire [31:0] EX1_rdata_rj2;
    wire [31:0] EX1_rdata_rkd1;
    wire [31:0] EX1_rdata_rkd2;

    wire [31:0] alu_src1_1;
    wire [31:0] alu_src1_2;
    wire [31:0] alu_src2_1;
    wire [31:0] alu_src2_2;
    wire [31:0] alu_result1;
    wire [31:0] alu_result2;
    wire [31:0] real_alu_result1;
    wire [31:0] real_alu_result2;

    wire alu_valid1;
    wire alu_valid2;

// mul and div
    wire div_en1  ;
    wire div_en2  ;
    wire mul_en1  ;
    wire mul_en2  ;
    wire op_mul1  ;
    wire op_mul2  ;
    wire op_mulh1 ;
    wire op_mulh2 ;
    wire op_mulhu1;
    wire op_mulhu2;
    wire op_div1  ;
    wire op_div2  ;
    wire op_divu1 ;
    wire op_divu2 ;
    wire op_mod1  ;
    wire op_mod2  ;
    wire op_modu1 ;
    wire op_modu2 ;

    reg mul_complete1;
    reg mul_complete2;
    wire div_signed1;
    wire div_signed2;
    wire div_complete1;
    wire div_complete2;
    wire [ 2:0] mul_op1;
    wire [ 2:0] mul_op2;
    wire [31:0] res_mul1;
    wire [31:0] res_mul2;
    wire [31:0] result_s1;
    wire [31:0] result_s2;
    wire [31:0] result_r1;
    wire [31:0] result_r2;
        
    wire Is_DM1;
    wire Is_DM2;
    wire [31:0] dm_res1;
    wire [31:0] dm_res2;

//exceptions
    wire IS_excp1;
    wire IS_excp2;
    wire [14:0] IS_excp_num1;
    wire [14:0] IS_excp_num2;
    wire EX1_excp1;
    wire EX1_excp2;
    wire [14:0] EX1_excp_num1;
    wire [14:0] EX1_excp_num2;

    wire pc_excp1;
    wire pc_excp2;
    wire [31:0] badvaddr1;
    wire [31:0] badvaddr2;

    wire [4:0] EX1_tlb_excps1;
    wire [4:0] EX1_tlb_excps2;

    wire EX1_mode;
    
    wire FIFO_full;
    wire FIFO_empty;
//-------
    always@(posedge clk) begin
        if(reset) begin
            first_clk <= 1'b0;
        end
        else if(~stall) begin
            first_clk <= 1'b1;
        end
        else if(first_clk) begin
            first_clk <= 1'b0;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            IS_EX1_bus_reg1 <= `WIDTH_IS_EX1_BUS'b0;
        end
        else if(~stall) begin
            IS_EX1_bus_reg1 <= IS_EX1_bus1;
        end

        if(reset) begin
            IS_EX1_bus_reg2 <= `WIDTH_IS_EX1_BUS'b0;
        end
        else if(~stall) begin
            IS_EX1_bus_reg2 <= {`WIDTH_IS_EX1_BUS{IS_EX1_bus2_valid}} & IS_EX1_bus2;
        end
    end

    always@(posedge clk) begin
        if(reset | flush) begin
            EX1_valid <= 1'b0;
        end
        else if(~stall) begin
            if(taken) begin
                EX1_valid <= 1'b0;
            end
            else begin
                EX1_valid <= IS_EX1_valid;
            end
        end
    end

    assign {
        FIFO_full,
        FIFO_empty,
        IS_mode_buffer,
        br_op1,         //9
        offs1_26,       //26
        btb_miss1,      //1
        pred_index1,
        pred_taken1,    //1
        pred_target1,   //32
        EX1_rdata_rj1,
        EX1_rdata_rkd1,
        dest1,
        IS_excp1,
        IS_excp_num1,
        inst_idle1,
        inst_preld1,
        inst_ll_w1,
        inst_sc_w1,
        inst_cacop_valid1,
        cacop_code1,
        inst_invtlb1,
        invtlb_op1,
        inst_tlbwr1,
        inst_tlbfill1,
        inst_tlbsrch1,
        inst_tlbrd1,
        inst_ertn1, 
        csr_we1, 
        csr_num1, 
        res_from1, 
        gr_we1, 
        sel_alu_src1_1, 
        EX1_load_op1, 
        EX1_store_op1, 
        sel_alu_src2_1, 
        EX1_mem_type1, 
        extend_res1, 
        alu_op1, 
        IS_s1_vppn1,
        csr_asid_asid1,
        alu_src1_1,
        alu_src2_1,
        IS_data_vaddr1,
        EX1_pc1
    } = IS_EX1_bus_reg1;

    assign {
        br_op2,         //9
        offs2_26,       //26
        btb_miss2,      //1
        pred_index2,
        pred_taken2,    //1
        pred_target2,   //32
        EX1_rdata_rj2,
        EX1_rdata_rkd2,
        dest2,
        IS_excp2,
        IS_excp_num2,
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
        res_from2, 
        gr_we2, 
        sel_alu_src1_2, 
        EX1_load_op2, 
        EX1_store_op2, 
        sel_alu_src2_2, 
        EX1_mem_type2, 
        extend_res2, 
        alu_op2, 
        IS_s1_vppn2,
        csr_asid_asid2,
        alu_src1_2,
        alu_src2_2,
        IS_data_vaddr2,
        EX1_pc2
    } = IS_EX1_bus_reg2;

    assign EX1_EX2_bus1 = {
        FIFO_full,
        FIFO_empty,
        // all 383
        // 177
        br_inst,
        EX1_mode,            // 1
        (btb_error1 | (br_taken1 & btb_miss1)),              // 1
        inst_ll_w1,          // 1
        inst_sc_w1,          // 1
        icacop_op_en1,       // 1
        dcacop_op_en1,       // 1
        preld_en1,           // 1
        access_dcache1,      // 1
        mmu_data_uncache_en1,// 1
        mmu_sc_addr_eq1,     // 1
        sc_ll_paddr1,        // 32
        invtlb_asid1,        // 10
        invtlb_vppn1,        // 19
        invtlb_op1,          // 5
        tlb_op1,             // 5
        tlb_data1,           // 95
        inst_ertn1,          // 1
        // 45
        csr_we1,           // 1
        csr_num1,          // 14
        res_from1,         // 5
        gr_we1,            // 1
        EX1_mem_type1,     // 3
        dest1,             // 5
        EX1_excp_num1,     // 15
        EX1_excp1,         // 1
        // 160
        badvaddr1,         // 32
        EX1_data_paddr1,   // 32
        real_alu_result1,  // 32
        EX1_rdata_rj1,     // 32
        EX1_pc1            // 32
    };
    assign EX1_EX2_bus2 = {
        // all 382
        // 177
        1'b0,                // 1
        1'b0,                // 1
        inst_ll_w2,          // 1
        inst_sc_w2,          // 1
        icacop_op_en2,       // 1
        dcacop_op_en2,       // 1
        preld_en2,           // 1
        access_dcache2,
        mmu_data_uncache_en2,// 1
        mmu_sc_addr_eq2,     // 1
        sc_ll_paddr2,        // 32
        invtlb_asid2,        // 10
        invtlb_vppn2,        // 19
        invtlb_op2,          // 5
        tlb_op2,             // 5
        tlb_data2,           // 95
        inst_ertn2,          // 1
        // 45
        csr_we2,           // 1
        csr_num2,          // 14
        res_from2,         // 5
        gr_we2,            // 1
        EX1_mem_type2,     // 3
        dest2,             // 5
        EX1_excp_num2,     // 15
        EX1_excp2,         // 1
        // 160
        badvaddr2,         // 32
        EX1_data_paddr2,   // 32
        real_alu_result2,  // 32
        EX1_rdata_rj2,     // 32
        EX1_pc2            // 32
    };

//control
`ifdef DEBUG
    assign stall = EX1_stall | EX2_stall | MEM_stall | CM_stall;
    assign stall_nEX2 = EX1_stall | MEM_stall | CM_stall;
`else
    assign stall = EX1_stall | EX2_stall | MEM_stall;
    assign stall_nEX2 = EX1_stall | MEM_stall;
`endif
    assign stall_dcache = ~dcache_unbusy & op_dcache | ~(dcache_unbusy | dcache_hit) & access_dcache;
    assign EX1_stall = ~reset & EX1_valid & ((~(alu_valid1 & alu_valid2)) | (tlb_trans & first_clk | tlb_trans_reg & ~(s1_ok | s1_ok_buf)) | stall_dcache | ~icache_unbusy & op_icache); // �������tlb�����м����flush���Ƚ�������?������
    assign EX1_EX2_valid = EX1_valid & ~EX1_stall;

    assign EX1_mode = IS_mode_buffer & ~EX1_excp1 & EX1_valid;
    assign EX1_EX2_bus2_valid = IS_mode_buffer & ~EX1_excp1 & EX1_valid; //taken1����գ����2�Ƿ���cache����taken_cancel

//branch
    assign rj_equal_rd1 = (EX1_rdata_rj1 == EX1_rdata_rkd1);
    assign s_rj_smaller_rd1 = ($signed(EX1_rdata_rj1) < $signed(EX1_rdata_rkd1));
    assign us_rj_smaller_rd1= (EX1_rdata_rj1 < EX1_rdata_rkd1);

    assign rj_equal_rd2 = (EX1_rdata_rj2 == EX1_rdata_rkd2);
    assign s_rj_smaller_rd2 = ($signed(EX1_rdata_rj2) < $signed(EX1_rdata_rkd2));
    assign us_rj_smaller_rd2= (EX1_rdata_rj2 < EX1_rdata_rkd2);

    br_unit br1( .reset(reset),
                .jump_op(br_op1),    
                .equal(rj_equal_rd1),
                .sign_rj_rd(s_rj_smaller_rd1),
                .unsign_rj_rd(us_rj_smaller_rd1),
                .off_26(offs1_26),
                .GR_rj(EX1_rdata_rj1),
                .br_pc(EX1_pc1),
                .br_npc(br_target1),
                .br_taken(br_taken1)
    );

    br_unit br2( .reset(reset),
                .jump_op(br_op2),    
                .equal(rj_equal_rd2),
                .sign_rj_rd(s_rj_smaller_rd2),
                .unsign_rj_rd(us_rj_smaller_rd2),
                .off_26(offs2_26),
                .GR_rj(EX1_rdata_rj2),
                .br_pc(EX1_pc2),
                .br_npc(br_target2),
                .br_taken(br_taken2)
    );

    //branch
    assign br_taken  = taken;
    assign br_target = target;

    assign br_inst1 =  |br_op1;
    assign br_inst2 = (|br_op2) & EX1_mode;
    assign br_inst  = br_inst1 | br_inst2;

    assign operate_en    = EX1_valid & ~EX1_stall;

    assign add_entry1    = br_inst1 & btb_miss1 & br_taken1;
    assign add_entry2    = br_inst2 & btb_miss2 & br_taken2;
    assign add_entry     = add_entry1 | add_entry2;

    assign pred_error1   = ( !btb_miss1 & (pred_taken1 ^ br_taken1));
    assign pred_error2   = ((!btb_miss2 & (pred_taken2 ^ br_taken2)) & EX1_mode);
    assign pred_error    = pred_error1 | pred_error2;

    assign target_error1 = (br_inst1 & !btb_miss1 & (pred_taken1 & br_taken1) & (pred_target1 != br_target1)) ;
    assign target_error2 = (br_inst2 & !btb_miss2 & (pred_taken2 & br_taken2) & (pred_target2 != br_target2)) ;
    assign target_error  = target_error1 | target_error2;

    assign btb_error1    = pred_error1 | target_error1;
    assign btb_error2    = pred_error2 | target_error2;

    assign pred_right1   = ( !btb_miss1 & !(pred_taken1 ^ br_taken1)) ;
    assign pred_right2   = ((!btb_miss2 & !(pred_taken2 ^ br_taken2)) & EX1_mode);
    assign pred_right    = pred_right1 | pred_right2;

    assign right_orien   = br_taken1 | br_taken2 & EX1_mode;

    assign right_target  = {32{br_taken1}} & br_target1 | {32{!br_taken1}} & br_target2;

    assign operate_index = {5{br_inst1}} & pred_index1 | {5{!br_inst1}} & pred_index2;

    assign taken  = (taken1 | taken2) & EX1_valid & !EX1_stall;
    assign taken1 = add_entry1 | pred_error1 | target_error1;
    assign taken2 = add_entry2 | pred_error2 | target_error2;

    assign target = {32{ br_taken1 &  taken1}} &  br_target1   |
                    {32{ br_taken2 & ~taken1}} &  br_target2   |
                    {32{~br_taken1 &  taken1}} & (EX1_pc1 + 4) |
                    {32{~br_taken2 & ~taken1}} & (EX1_pc2 + 4) ;

    assign operate_pc = {32{br_inst1}} & EX1_pc1 | {32{~br_inst1}} & EX1_pc2;
    assign btb_mode   = ~br_inst1;

    assign push_ras = br_op1[3] | br_op2[3] & EX1_mode;
    assign pop_ras  = br_op1[4] | br_op2[4] & EX1_mode;

// forward
    assign EX1_forward_bus1 = {EX1_dest1, EX1_data_not_prepared1, EX1_data1};
    assign EX1_dest1  = dest1 & {5{gr_we1 & EX1_valid & ~flush}};
    assign EX1_data_not_prepared1 = ~EX1_data_used1;
    assign EX1_data_used1 = !res_from1 & ~Is_DM1 & EX1_valid & ~flush;
    assign EX1_data1 = alu_result1;

    assign EX1_forward_bus2 = {EX1_dest2, EX1_data_not_prepared2, EX1_data2};
    assign EX1_dest2  = dest2 & {5{gr_we2 & EX1_valid & ~flush}};
    assign EX1_data_not_prepared2 = ~EX1_data_used2;
    assign EX1_data_used2 = !res_from2 & ~Is_DM2 & EX1_valid & ~flush;
    assign EX1_data2 = alu_result2;
//alu res
    assign alu_valid1 = ~reset & ((mul_complete1 & (|mul_op1)) | div_complete1 | ~Is_DM1);
    assign alu_valid2 = ~reset & ((mul_complete2 & (|mul_op2)) | div_complete2 | ~Is_DM2);
    assign real_alu_result1 = {32{ Is_DM1}} & dm_res1    |
                               {32{~Is_DM1}} & alu_result1;
    assign real_alu_result2 = {32{ Is_DM2}} & dm_res2    |
                               {32{~Is_DM2}} & alu_result2;

// alu

    ALU u_alu_1(
        .clk       (clk         ),
        .reset     (reset       ),
        .alu_op    (alu_op1     ),
        .alu_src1  (alu_src1_1  ),
        .alu_src2  (alu_src2_1  ),
        .alu_result(alu_result1)
    );
    ALU u_alu_2(
        .clk       (clk         ),
        .reset     (reset       ),
        .alu_op    (alu_op2     ),
        .alu_src1  (alu_src1_2  ),
        .alu_src2  (alu_src2_2  ),
        .alu_result(alu_result2)
    );

//div and mul

    assign op_mul1  = alu_op1[12];
    assign op_mulh1 = alu_op1[13];
    assign op_mulhu1= alu_op1[14];
    assign op_div1  = alu_op1[15];
    assign op_divu1 = alu_op1[16];
    assign op_mod1  = alu_op1[17];
    assign op_modu1 = alu_op1[18];

    assign op_mul2  = alu_op2[12];
    assign op_mulh2 = alu_op2[13];
    assign op_mulhu2= alu_op2[14];
    assign op_div2  = alu_op2[15];
    assign op_divu2 = alu_op2[16];
    assign op_mod2  = alu_op2[17];
    assign op_modu2 = alu_op2[18];


    assign div_signed1 = op_div1 | op_mod1;
    assign mul_op1     = {op_mulhu1, op_mulh1, op_mul1};
    assign div_signed2 = op_div2 | op_mod2;
    assign mul_op2     = {op_mulhu2, op_mulh2, op_mul2};

    assign div_en1 = EX1_valid & ~flush & (|alu_op1[18:15]);
    assign mul_en1 = EX1_valid & ~flush & (|alu_op1[14:12]);
    assign div_en2 = EX1_valid & ~flush & (|alu_op2[18:15]);
    assign mul_en2 = EX1_valid & ~flush & (|alu_op2[14:12]);

    assign Is_DM1 = div_en1 | mul_en1;
    assign Is_DM2 = div_en2 | mul_en2;

    assign dm_res1 = {32{op_mul1 | op_mulh1 | op_mulhu1}} & res_mul1  | 
                      {32{op_div1 | op_divu1}}              & result_s1 |
                      {32{op_mod1 | op_modu1}}              & result_r1 ;
    assign dm_res2 = {32{op_mul2 | op_mulh2 | op_mulhu2}} & res_mul2  | 
                      {32{op_div2 | op_divu2}}              & result_s2 |
                      {32{op_mod2 | op_modu2}}              & result_r2 ;

    // mul mul_signed_1(
    //     .clk(clk),
    //     .rst_n(reset),
    //     .a(alu_src1_1),
    //     .b(alu_src2_1),
    //     .start(mul_en1 & !mul_complete1),
    //     .mul_op(mul_op1),
    //     .mul_result(res_mul1),
    //     .mul_done(mul_complete1)
    // );

    // mul mul_signed_2(
    //     .clk(clk),
    //     .rst_n(reset),
    //     .a(alu_src1_2),
    //     .b(alu_src2_2),
    //     .start(mul_en2 & !mul_complete2),
    //     .mul_op(mul_op2),
    //     .mul_result(res_mul2),
    //     .mul_done(mul_complete2)
    // );
    always @(posedge clk ) begin
        if(reset) begin
            mul_complete1 <= 1'b0;
            mul_complete2 <= 1'b0;
        end
        else if(!stall) begin
            mul_complete1 <= 1'b0;
            mul_complete2 <= 1'b0;
        end
        else if(EX1_valid) begin
            mul_complete1 <= 1'b1;
            mul_complete2 <= 1'b1;
        end     
    end

    mul_new u_mul1(
        .mul_clk         (clk            ),
        .reset           (reset          ),
        .mul_signed      (|mul_op1[1:0]  ),
        .mul_op          (mul_op1[1:0]   ),
        .x               (alu_src1_1     ),
        .y               (alu_src2_1     ),
        .mul_result      (res_mul1       )
    );

    mul_new u_mul2(
        .mul_clk         (clk            ),
        .reset           (reset          ),
        .mul_signed      (|mul_op2[1:0]  ),
        .mul_op          (mul_op2[1:0]   ),
        .x               (alu_src1_2     ),
        .y               (alu_src2_2     ),
        .mul_result      (res_mul2       )
    );

    div div_new_1(
            .div_clk(clk),
            .reset(reset),
            .div(div_en1),
            .div_signed(div_signed1),
            .x(alu_src1_1),
            .y(alu_src2_1),
            .s(result_s1),
            .r(result_r1),
            .complete(div_complete1)
        );

    div div_new_2(
            .div_clk(clk),
            .reset(reset),
            .div(div_en2),
            .div_signed(div_signed2),
            .x(alu_src1_2),
            .y(alu_src2_2),
            .s(result_s2),
            .r(result_r2),
            .complete(div_complete2)
        );

//exception
    assign EX1_tlb_excps1 = {5{EX1_load_op1 |EX1_store_op1 | inst_cacop_valid1}} & EX1_tlb_excps;
    assign EX1_excp_num1 = {EX1_tlb_excps1, IS_excp_num1[9:0]};
    assign EX1_excp1 = |EX1_excp_num1;

    assign pc_excp1 = |IS_excp_num1[8:0];
    assign badvaddr1 = {32{ pc_excp1}} & EX1_pc1 | 
                       {32{~pc_excp1}} & alu_result1;

    assign EX1_tlb_excps2 = {5{EX1_load_op2 |EX1_store_op2 | inst_cacop_valid2}} & EX1_tlb_excps;
    assign EX1_excp_num2 = {EX1_tlb_excps2, IS_excp_num2[9:0]};
    assign EX1_excp2 = |EX1_excp_num2;

    assign pc_excp2 = |IS_excp_num2[8:0];
    assign badvaddr2 = {32{ pc_excp2}} & EX1_pc2 | 
                       {32{~pc_excp2}} & alu_result2;

//cache values
    wire [2:0] data_mem_type;
    assign data_mem_type   = { 3{EX1_load_op1 | EX1_store_op1 | inst_cacop_valid1}} & EX1_mem_type1 |
                             { 3{EX1_load_op2 | EX1_store_op2 | inst_cacop_valid2}} & EX1_mem_type2;

    assign bpos  = {EX1_data_vaddr[1:0] == 2'b11,
                    EX1_data_vaddr[1:0] == 2'b10,
                    EX1_data_vaddr[1:0] == 2'b01,
                    EX1_data_vaddr[1:0] == 2'b00};

    assign hpos   = {{{EX1_data_vaddr[1] == 1'b1}},
                     {{EX1_data_vaddr[1] == 1'b0}}};

    assign bwdata1  = {{8{bpos[3]}} & EX1_rdata_rkd1[7:0],
                       {8{bpos[2]}} & EX1_rdata_rkd1[7:0],
                       {8{bpos[1]}} & EX1_rdata_rkd1[7:0],
                       {8{bpos[0]}} & EX1_rdata_rkd1[7:0]};
    assign bwdata2  = {{8{bpos[3]}} & EX1_rdata_rkd2[7:0],
                       {8{bpos[2]}} & EX1_rdata_rkd2[7:0],
                       {8{bpos[1]}} & EX1_rdata_rkd2[7:0],
                       {8{bpos[0]}} & EX1_rdata_rkd2[7:0]};

    assign hwdata1  = {{16{hpos[1]}} & EX1_rdata_rkd1[15:0],
                       {16{hpos[0]}} & EX1_rdata_rkd1[15:0]};
    assign hwdata2  = {{16{hpos[1]}} & EX1_rdata_rkd2[15:0],
                       {16{hpos[0]}} & EX1_rdata_rkd2[15:0]};

    assign EX1_data_wdata1  = {32{EX1_mem_type1[0]}} & hwdata1 |
                              {32{EX1_mem_type1[1]}} & bwdata1 |
                              {32{!(|EX1_mem_type1[1:0])}} & EX1_rdata_rkd1;
    assign EX1_data_wdata2  = {32{EX1_mem_type2[0]}} & hwdata2 |
                              {32{EX1_mem_type2[1]}} & bwdata2 |
                              {32{!(|EX1_mem_type2[1:0])}} & EX1_rdata_rkd2;

    assign EX1_data_wstrb   = {4{ data_mem_type[0]}}   & {{2{hpos[1]}}, {2{hpos[0]}}} |
                              {4{ data_mem_type[1]}}   &  bpos                          |
                              {4{!data_mem_type[1:0]}} &  4'b1111;

    assign EX1_data_size   = {3{ data_mem_type[0]}} & 3'b001 |
                             {3{ data_mem_type[1]}} & 3'b000 |
                             {3{!data_mem_type[1:0]}} & 3'b010;
//TLB and MMU
    assign EX1_load  = (EX1_load_op1  | EX1_load_op2 )         & EX1_valid & ~flush;
    assign EX1_store = (EX1_store_op1 | EX1_store_op2)         & EX1_valid & ~flush;
    assign EX1_cacop = (inst_cacop_valid1 | inst_cacop_valid2) & EX1_valid & ~flush;

    assign EX1_cache_op_mode = {2{ inst_cacop_valid1}} & cacop_code1[4:3] | 
                               {2{~inst_cacop_valid1}} & cacop_code2[4:3];
    assign EX1_data_vaddr = IS_data_vaddr1;

    assign EX1_data_paddr1 = EX1_data_paddr;
    assign EX1_data_paddr2 = EX1_data_paddr;

    assign sc_ll_paddr1 = sc_ll_paddr;
    assign sc_ll_paddr2 = sc_ll_paddr;

    assign mmu_data_uncache_en1 = (EX1_load_op1 | EX1_store_op1 | inst_cacop_valid1) & mmu_data_uncache_en;
    assign mmu_data_uncache_en2 = (EX1_load_op2 | EX1_store_op2 | inst_cacop_valid2) & mmu_data_uncache_en;
    assign mmu_sc_addr_eq1 = (EX1_load_op1 | EX1_store_op1 | inst_cacop_valid1 | inst_sc_w1) & mmu_sc_addr_eq;
    assign mmu_sc_addr_eq2 = (EX1_load_op2 | EX1_store_op2 | inst_cacop_valid2 | inst_sc_w2) & mmu_sc_addr_eq;

    assign tlb_data1 = tlb_data;
    assign tlb_data2 = tlb_data;
    assign tlb_op1 = {inst_invtlb1, inst_tlbwr1, inst_tlbfill1, inst_tlbsrch1, inst_tlbrd1};
    assign tlb_op2 = {inst_invtlb2, inst_tlbwr2, inst_tlbfill2, inst_tlbsrch2, inst_tlbrd2};
    assign invtlb_asid1 = EX1_rdata_rj1 [ 9: 0];
    assign invtlb_asid2 = EX1_rdata_rj2 [ 9: 0];
    assign invtlb_vppn1 = EX1_rdata_rkd1[31:13];
    assign invtlb_vppn2 = EX1_rdata_rkd2[31:13];
    // tlb
    assign s1_vppn     = IS_s1_vppn1;
    assign s1_asid     = csr_asid_asid1;
    assign s1_va_bit12 = (inst_tlbsrch1 | inst_tlbsrch2) ? 1'b0 : EX1_data_vaddr[12];
    
    assign tlb_trans = (((EX1_load_op1 | EX1_store_op1 | inst_cacop_valid1 | inst_preld1) & data_unhit | (|tlb_op1)) & ~(|EX1_excp_num1[9:0]) |
                        ((EX1_load_op2 | EX1_store_op2 | inst_cacop_valid2 | inst_preld2) & data_unhit | (|tlb_op2)) & ~(|EX1_excp_num2[9:0]) & IS_mode_buffer);
    assign s1_valid = s1_valid_reg & ~(s1_ok | s1_ok_buf) & tlb_trans & EX1_valid & ~flush;

    always@(posedge clk) begin
        if(reset | ~stall) begin
            tlb_trans_reg <= 1'b0;
        end
        else if(first_clk & tlb_trans) begin
            tlb_trans_reg <= 1'b1;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            s1_ok_buf <= 1'b0;
            s1_valid_reg <= 1'b0;
        end
        else if(~stall) begin
            s1_valid_reg <= 1'b1;
            s1_ok_buf <= 1'b0;
        end
        else if(s1_ok) begin
            s1_valid_reg <= 1'b0;
            s1_ok_buf <= 1'b1;
        end
    end

//cache
    assign data_valid = access_dcache & ~stall_nEX2 & EX1_valid;
    assign access_dcache = access_dcache1 | access_dcache2;
    assign access_dcache1 = (EX1_load_op1 | EX1_store_op1) & ~flush & ~IS_excp1;
    assign access_dcache2 = (EX1_load_op2 | EX1_store_op2) & ~flush & ~IS_excp2 & IS_mode_buffer; // if taken1 cancel in EX2

    assign {data_index, data_offset} = EX1_data_vaddr[11:0];
    assign data_wstrb = EX1_data_wstrb;
    assign data_size  = EX1_data_size;
    assign data_wdata = {32{EX1_load_op1 | EX1_store_op1 | inst_cacop_valid1}} & EX1_data_wdata1 |
                        {32{EX1_load_op2 | EX1_store_op2 | inst_cacop_valid2}} & EX1_data_wdata2;
    assign data_op    = {{EX1_load_op1 | EX1_store_op1 | inst_cacop_valid1}} & EX1_store_op1 |
                        {{EX1_load_op2 | EX1_store_op2 | inst_cacop_valid2}} & EX1_store_op2;

    assign cache_op_mode = EX1_cache_op_mode; // to cache
    assign icacop_op_en = icacop_op_en1 | icacop_op_en2;
    assign dcacop_op_en = dcacop_op_en1 | dcacop_op_en2;

    assign icacop_op_en1 = op_icache1 & EX1_valid & ~stall & ~flush;
    assign icacop_op_en2 = op_icache2 & EX1_valid & ~stall & ~flush;

    assign dcacop_op_en1 = op_dcache1 & EX1_valid & ~stall_nEX2 & ~flush;
    assign dcacop_op_en2 = op_dcache2 & EX1_valid & ~stall_nEX2 & ~flush;

    assign op_icache = op_icache1 | op_icache2;
    assign op_icache1 = inst_cacop_valid1 & (cacop_code1[2:0] == 3'b000) & ~IS_excp1;
    assign op_icache2 = inst_cacop_valid2 & (cacop_code2[2:0] == 3'b000) & ~IS_excp2 & IS_mode_buffer;

    assign op_dcache = op_dcache1 | op_dcache2;
    assign op_dcache1 = inst_cacop_valid1 & (cacop_code1[2:0] == 3'b001) & ~IS_excp1;
    assign op_dcache2 = inst_cacop_valid2 & (cacop_code1[2:0] == 3'b001) & ~IS_excp2 & IS_mode_buffer;

//preld
    assign preld_en  = preld_en1 | preld_en2;
    assign preld_en1 = inst_preld1 & EX1_valid & ~stall_nEX2 & ~IS_excp1 & ~flush;
    assign preld_en2 = inst_preld2 & EX1_valid & ~stall_nEX2 & ~IS_excp2 & ~flush & IS_mode_buffer;

`ifdef DIFFTEST_EN
    reg [`DIFF_WIDTH_IS_EX1_BUS-1 :0] IS_EX1_diff_bus_reg_1;
    reg [`DIFF_WIDTH_IS_EX1_BUS-1 :0] IS_EX1_diff_bus_reg_2;
    always@(posedge clk) begin
        if(reset | flush) begin
            IS_EX1_diff_bus_reg_1 <= 0;
            IS_EX1_diff_bus_reg_2 <= 0;
        end
        else if(~stall) begin
            IS_EX1_diff_bus_reg_1 <= IS_EX1_diff_bus_1;
            IS_EX1_diff_bus_reg_2 <= IS_EX1_diff_bus_2;
        end
    end
    wire [31:0] EX1_inst_1;
    wire [31:0] EX1_inst_2;
    wire        EX1_cnt_inst_1;
    wire        EX1_cnt_inst_2;
    wire [ 7:0] EX1_inst_ld_en_1;
    wire [ 7:0] EX1_inst_ld_en_2;
    wire [ 7:0] EX1_inst_st_en_1;
    wire [ 7:0] EX1_inst_st_en_2;
    wire        EX1_csr_rstat_en_1;
    wire        EX1_csr_rstat_en_2;

    wire [31:0] EX1_ld_paddr_1;
    wire [31:0] EX1_ld_paddr_2;
    wire [31:0] EX1_ld_vaddr_1;
    wire [31:0] EX1_ld_vaddr_2;
    wire [31:0] EX1_st_paddr_1;
    wire [31:0] EX1_st_paddr_2;
    wire [31:0] EX1_st_vaddr_1;
    wire [31:0] EX1_st_vaddr_2;

    wire [31:0] EX1_st_data_1;
    wire [31:0] EX1_st_data_2;
    
    assign {
        EX1_inst_1,
        EX1_cnt_inst_1,
        EX1_inst_ld_en_1,
        EX1_inst_st_en_1,
        EX1_csr_rstat_en_1
    } = IS_EX1_diff_bus_reg_1;
    assign {
        EX1_inst_2,
        EX1_cnt_inst_2,
        EX1_inst_ld_en_2,
        EX1_inst_st_en_2,
        EX1_csr_rstat_en_2
    } = IS_EX1_diff_bus_reg_2;

    assign EX1_ld_paddr_1 = EX1_data_paddr;
    assign EX1_ld_paddr_2 = EX1_data_paddr;
    assign EX1_ld_vaddr_1 = EX1_data_vaddr;
    assign EX1_ld_vaddr_2 = EX1_data_vaddr;
    assign EX1_st_paddr_1 = EX1_data_paddr;
    assign EX1_st_paddr_2 = EX1_data_paddr;
    assign EX1_st_vaddr_1 = EX1_data_vaddr;
    assign EX1_st_vaddr_2 = EX1_data_vaddr;

    assign EX1_st_data_1  = EX1_data_wdata1;
    assign EX1_st_data_2  = EX1_data_wdata2;

    assign EX1_EX2_diff_bus_1 = {
        EX1_inst_1,          // 32
        EX1_cnt_inst_1,      // 1
        EX1_inst_ld_en_1,    // 8
        EX1_ld_paddr_1,      // 32
        EX1_ld_vaddr_1,      // 32
        EX1_st_paddr_1,      // 32
        EX1_st_vaddr_1,      // 32
        EX1_inst_st_en_1,    // 8
        EX1_st_data_1,       // 32
        EX1_csr_rstat_en_1   // 1
    };
    assign EX1_EX2_diff_bus_2 = {
        EX1_inst_2,
        EX1_cnt_inst_2,
        EX1_inst_ld_en_2,
        EX1_ld_paddr_2,
        EX1_ld_vaddr_2,
        EX1_st_paddr_2,
        EX1_st_vaddr_2,
        EX1_inst_st_en_2,
        EX1_st_data_2,
        EX1_csr_rstat_en_2
    };
`endif
endmodule