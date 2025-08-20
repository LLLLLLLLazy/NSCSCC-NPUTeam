`include "csr.h"
`include "header.h" 
module MEM (
    input                                           clk,
    input                                           reset,
    input      [`WIDTH_EX2_MEM_BUS-1:0]             EX2_MEM_bus1,
    input      [`WIDTH_EX2_MEM_BUS-1:0]             EX2_MEM_bus2,
`ifdef DEBUG
    output                                          MEM_CM_valid,
    input                                           CM_stall,
    output     [`WIDTH_MEM_CM_BUS -1:0]             MEM_CM_bus1,
    output     [`WIDTH_MEM_CM_BUS -1:0]             MEM_CM_bus2,
`endif
    output                                          flush,
    input                                           EX2_MEM_valid,
    input                                           EX2_MEM_bus2_valid,
    output                                          MEM_stall,
    output                                          MEM_ex,
    output                                          MEM_ertn,
    output     reg                                  MEM_tlbr_ex,
    output                                          MEM_refetch,
    output     reg                                  va_error,
    output     reg                                  MEM_excp_tlb,

    output     [`WIDTH_MEM_RF_BUS-1:0]              MEM_rf_bus1,
    output     [`WIDTH_MEM_RF_BUS-1:0]              MEM_rf_bus2,
    output     [31:0]                               MEM_pc,
    output     [31:0]                               MEM_pc1,
    output     [31:0]                               MEM_pc2,
    output     [31:0]                               MEM_vaddr,
    output     [`WIDTH_MEM_FORWARD_BUS-1:0]         MEM_forward_bus1,
    output     [`WIDTH_MEM_FORWARD_BUS-1:0]         MEM_forward_bus2,

    output     [13:0]                               csr_wnum,
    output                                          csr_we,
    output     [31:0]                               csr_wmask,
    output     [31:0]                               csr_wvalue,
    output     [31:0]                               MEM_csr_pc,
    output     reg [ 5:0]                           MEM_csr_ecode,
    output     reg [ 8:0]                           MEM_csr_esubcode,

    output                                          MEM_llbit_in,
    output                                          MEM_llbit_set,
    output     [27:0]                               MEM_lladdr_in,
    output                                          MEM_lladdr_set,  

    //TLB
    output     [93+`WIDTH_TLB_INDEX:0]              MEM_TLB_data,
    output                                          invtlb_en,
    output     [ 4:0]                               invtlb_op,
    output     [ 9:0]                               invtlb_asid,
    output     [18:0]                               invtlb_vppn,

    output                                          MEM_mode,
    output     reg                                  MEM_valid,
    output                                          real_br_inst,
    output                                          real_fifo_full,
    output                                          real_fifo_empty,
    output                                          real_dcache_miss

    `ifdef DIFFTEST_EN
        ,
        input  flush_diff,
        input  [`DIFF_WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_diff_bus_1,
        input  [`DIFF_WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_diff_bus_2,
        output [`DIFF_WIDTH_MEM_CM_BUS-1:0] MEM_CM_diff_bus_1,
        output [`DIFF_WIDTH_MEM_CM_BUS-1:0] MEM_CM_diff_bus_2,
        output [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_1,
        output [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_2
    `endif
);
wire [63:0] stable_counter;
wire [31:0] counter_id;
wire        csr_llbit;
wire [63:0] stable_counter1;
wire [31:0] counter_id1;
wire        csr_llbit1;
wire [63:0] stable_counter2;
wire [31:0] counter_id2;
wire        csr_llbit2;
assign stable_counter = stable_counter1;
assign counter_id     = counter_id1;
assign csr_llbit      = csr_llbit1;


wire [31:0] csr_rvalue1;
wire [31:0] csr_rvalue2;
wire [13:0] csr_rnum1;
wire [13:0] csr_rnum2;
wire MEM_flush;

wire          MEM_ex1;
wire          MEM_ex2;

wire          stall;
wire          MEM_ertn1;
wire          MEM_ertn2;
wire          MEM_refetch1;
wire          MEM_refetch2;
wire   [31:0] MEM_vaddr1;
wire   [31:0] MEM_vaddr2;
wire          flush1;
wire          flush2;
wire   [ 4:0] MEM_dest1;
wire   [ 4:0] MEM_dest2;
wire   [31:0] MEM_final_result1;
wire   [31:0] MEM_final_result2;
wire   [31:0] MEM_result1;
wire   [31:0] MEM_result2;
reg    [31:0] WB_result1;
reg    [31:0] WB_result2;
wire   [89+`WIDTH_TLB_INDEX:0] tlb_data1;
wire   [89+`WIDTH_TLB_INDEX:0] tlb_data2;
wire          MEM_csr_we1;
wire          MEM_csr_we2;
wire   [13:0] MEM_csr_num1;
wire   [13:0] MEM_csr_num2;
wire   [ 4:0] res_from1;
wire   [ 4:0] res_from2;
wire          gr_we1;
wire          gr_we2;
wire   [ 2:0] mem_type1;
wire   [ 2:0] mem_type2;
wire   [14:0] MEM_excp_num1;
wire   [14:0] MEM_excp_num2;
wire          MEM_excp1;
wire          MEM_excp2;
wire          inst_ertn1;
wire          inst_ertn2;
wire          MEM_tlb1;
wire          MEM_tlb2;
wire          inst_ll_w1;
wire          inst_ll_w2;
wire          inst_sc_w1;
wire          inst_sc_w2;
wire          MEM_lladdr_set1;
wire          MEM_lladdr_set2;
wire          sc_cancel_req1;
wire          sc_cancel_req2;
wire   [31:0] MEM_csr_rvalue1;
wire   [31:0] MEM_csr_rvalue2;
wire          data_uncache_en1;
wire          data_uncache_en2;
wire   [31:0] sc_ll_paddr1;
wire   [31:0] sc_ll_paddr2;
wire          icacop_op_en1;
wire          icacop_op_en2;
wire   [ 4:0] tlb_op1;
wire   [ 4:0] tlb_op2;
wire   [31:0] csr_wmask_before1;
wire   [31:0] csr_wmask_before2;
wire   [31:0] MEM_alu_result1;
wire   [31:0] MEM_alu_result2;
wire   [31:0] MEM_data_rdata1;
wire   [31:0] MEM_data_rdata2;
reg    [31:0] MEM_csr_wmask;
reg    [`WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_reg1;
reg    [`WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_reg2;
wire          MEM_data_not_prepared1;
wire          MEM_data_not_prepared2;

wire          rf_we1;
wire          rf_we2;
wire   [31:0] rf_wdata1;
wire   [31:0] rf_wdata2;
wire   [ 4:0] rf_waddr1;
wire   [ 4:0] rf_waddr2;

// tlb
wire invtlb_en1;
wire invtlb_en2;
wire [93+`WIDTH_TLB_INDEX:0] MEM_TLB_data1;
wire [93+`WIDTH_TLB_INDEX:0] MEM_TLB_data2;
wire [ 4:0] invtlb_op1;
wire [ 4:0] invtlb_op2;
wire [ 9:0] invtlb_asid1;
wire [ 9:0] invtlb_asid2;
wire [18:0] invtlb_vppn1;
wire [18:0] invtlb_vppn2;

wire EX2_mode_buf;

wire br_inst;
wire FIFO_full;
wire FIFO_empty;
wire dcache_miss;

assign {
        dcache_miss,
        FIFO_full,
        FIFO_empty,
        br_inst,
        EX2_mode_buf,
        MEM_flush,
        inst_ll_w1,
        inst_sc_w1,
        data_uncache_en1,
        sc_cancel_req1,
        sc_ll_paddr1,
        tlb_data1,
        MEM_csr_we1,
        MEM_csr_num1,
        res_from1,
        gr_we1,
        mem_type1,
        MEM_dest1,
        MEM_excp_num1,
        MEM_excp1,
        inst_ertn1,
        icacop_op_en1,
        invtlb_asid1,
        invtlb_vppn1,
        invtlb_op1,
        tlb_op1,
        csr_wmask_before1,
        stable_counter1,
        counter_id1,
        csr_llbit1,
        csr_rvalue1,
        MEM_vaddr1,
        MEM_alu_result1,
        MEM_data_rdata1,
        MEM_pc1
        } = EX2_MEM_reg1;
assign {
        inst_ll_w2,
        inst_sc_w2,
        data_uncache_en2,
        sc_cancel_req2,
        sc_ll_paddr2,
        tlb_data2,
        MEM_csr_we2,
        MEM_csr_num2,
        res_from2,
        gr_we2,
        mem_type2,
        MEM_dest2,
        MEM_excp_num2,
        MEM_excp2,
        inst_ertn2,
        icacop_op_en2,
        invtlb_asid2,
        invtlb_vppn2,
        invtlb_op2,
        tlb_op2,
        csr_wmask_before2,
        stable_counter2,
        counter_id2,
        csr_llbit2,
        csr_rvalue2,
        MEM_vaddr2,
        MEM_alu_result2,
        MEM_data_rdata2,
        MEM_pc2
        } = EX2_MEM_reg2;

// output
assign real_dcache_miss = dcache_miss & MEM_valid;
assign real_br_inst = br_inst & MEM_valid;
assign real_fifo_empty = FIFO_empty & MEM_valid;
assign real_fifo_full = FIFO_full & MEM_valid;
assign MEM_pc = {32{MEM_refetch1}} & MEM_pc1 | {32{~MEM_refetch1}} & MEM_pc2;
assign MEM_mode = EX2_mode_buf & MEM_valid;

`ifdef DEBUG
    assign stall = MEM_stall || CM_stall;
`else
    assign stall = MEM_stall;
`endif

`ifdef DEBUG
    assign MEM_CM_valid = MEM_valid & ~MEM_stall;
`endif
assign MEM_stall = 1'b0;

// assign flush  = flush1 || flush2;
assign flush = MEM_flush & MEM_valid;
assign MEM_ex   = MEM_ex1 || MEM_ex2;
assign MEM_ertn = MEM_ertn1 || MEM_ertn2;
assign MEM_refetch = MEM_refetch1 || MEM_refetch2;

assign invtlb_en = invtlb_en1 | invtlb_en2;
assign invtlb_op = invtlb_en1 ? invtlb_op1 : invtlb_op2;
assign invtlb_asid = invtlb_en1 ? invtlb_asid1 : invtlb_asid2;
assign invtlb_vppn = invtlb_en1 ? invtlb_vppn1 : invtlb_vppn2;
assign MEM_TLB_data = {{94{MEM_tlb1}}, {`WIDTH_TLB_INDEX{MEM_tlb1}}} & MEM_TLB_data1 | 
                      {{94{MEM_tlb2}}, {`WIDTH_TLB_INDEX{MEM_tlb2}}} & MEM_TLB_data2 ;


assign invtlb_en1 = tlb_op1[4] & MEM_valid & ~MEM_ex1;
assign MEM_TLB_data1 = {tlb_op1[3:0]&{4{MEM_valid & ~MEM_ex1}}, tlb_data1};
assign MEM_ex1 = MEM_excp1 & MEM_valid;
assign MEM_ertn1 = inst_ertn1 & MEM_valid;
assign MEM_tlb1 = (|tlb_op1) & MEM_valid;
assign MEM_refetch1 =( MEM_csr_we1 | MEM_tlb1 | icacop_op_en1 | ((inst_sc_w1 || inst_ll_w1 ) && !MEM_ex1)) & MEM_valid;
assign flush1 = MEM_ex1 | MEM_ertn1 | MEM_refetch1 ;

assign invtlb_en2 = tlb_op2[4] & MEM_valid & ~MEM_ex2;
assign MEM_TLB_data2 = {tlb_op2[3:0]&{4{MEM_valid & ~MEM_ex2}}, tlb_data2};
assign MEM_ex2 = MEM_excp2 & MEM_valid;
assign MEM_ertn2 = inst_ertn2 & MEM_valid;
assign MEM_tlb2 = (|tlb_op2) & MEM_valid;
assign MEM_refetch2 =( MEM_csr_we2 | MEM_tlb2 | icacop_op_en2 | ((inst_sc_w2 || inst_ll_w2 ) && !MEM_ex2)) & MEM_valid;
assign flush2 = MEM_ex2 | MEM_ertn2 | MEM_refetch2 ;

always @(posedge clk ) begin
    if(reset) begin
        EX2_MEM_reg1 <= `WIDTH_EX2_MEM_BUS'b0;
    end
    else if (!stall) begin
        EX2_MEM_reg1 <= EX2_MEM_bus1;
    end

    if(reset) begin
        EX2_MEM_reg2 <= `WIDTH_EX2_MEM_BUS'b0;
    end
    else if (!stall) begin
        EX2_MEM_reg2 <= {`WIDTH_EX2_MEM_BUS{EX2_MEM_bus2_valid}} & EX2_MEM_bus2;
    end
end

`ifdef DIFFTEST_EN
always @(posedge clk ) begin
    if (reset || flush_diff) begin
        MEM_valid <= 1'b0;
    end
    else if (!stall) begin
        MEM_valid <= EX2_MEM_valid;
    end
end

`else

always @(posedge clk ) begin
    if (reset || flush) begin
        MEM_valid <= 1'b0;
    end
    else if (!stall) begin
        MEM_valid <= EX2_MEM_valid;
    end
end
`endif
assign MEM_final_result1 = 
    ({32{(res_from1==5'b0)}} & MEM_alu_result1)|  
    ({32{res_from1[0]} }     & MEM_data_rdata1);  
assign MEM_final_result2 = 
    ({32{(res_from2==5'b0)}} & MEM_alu_result2)|  
    ({32{res_from2[0]} }     & MEM_data_rdata2);

//to CSR
always @(*) begin
    {MEM_csr_ecode,
     MEM_csr_esubcode,
     MEM_tlbr_ex,
     va_error,
     MEM_excp_tlb   }  = reset            ? 18'b0             :
                         MEM_excp_num1[ 0] | MEM_excp_num2[ 0] ? {`ECODE_INT ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num1[ 1] | MEM_excp_num2[ 1] ? {`ECODE_ADE ,9'b0, 1'b0     , MEM_valid, 1'b0     }:
                         MEM_excp_num1[ 2] | MEM_excp_num2[ 2] ? {`ECODE_TLBR,9'b0, MEM_valid, MEM_valid, MEM_valid}:
                         MEM_excp_num1[ 3] | MEM_excp_num2[ 3] ? {`ECODE_PIF ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num1[ 4] | MEM_excp_num2[ 4] ? {`ECODE_PPI ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num1[ 5] | MEM_excp_num2[ 5] ? {`ECODE_SYS ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num1[ 6] | MEM_excp_num2[ 6] ? {`ECODE_BRK ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num1[ 7] | MEM_excp_num2[ 7] ? {`ECODE_INE ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num1[ 8] | MEM_excp_num2[ 8] ? {`ECODE_IPE ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num1[ 9] | MEM_excp_num2[ 9] ? {`ECODE_ALE ,9'b0, 1'b0     , MEM_valid, 1'b0     }:
                         MEM_excp_num1[10] | MEM_excp_num2[10] ? {`ECODE_TLBR,9'b0, MEM_valid, MEM_valid, MEM_valid}:
                         MEM_excp_num1[11] | MEM_excp_num2[11] ? {`ECODE_PME ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num1[12] | MEM_excp_num2[12] ? {`ECODE_PPI ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num1[13] | MEM_excp_num2[13] ? {`ECODE_PIS ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num1[14] | MEM_excp_num2[14] ? {`ECODE_PIL ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         {6'b00_0101, 9'b0_0000_0000, 3'b0};
end
assign MEM_vaddr = {32{MEM_ex1}} & MEM_vaddr1 | 
                   {32{~MEM_ex1}} & MEM_vaddr2;
assign MEM_csr_pc = {32{MEM_ex1}} & MEM_pc1 | 
                    {32{~MEM_ex1}} & MEM_pc2;
assign csr_wnum = {14{MEM_csr_we1}} & MEM_csr_num1 | 
                  {14{MEM_csr_we2}} & MEM_csr_num2 ;
assign csr_rnum1 = MEM_csr_num1;
assign csr_rnum2 = MEM_csr_num2;
assign csr_we  = (MEM_csr_we1 | MEM_csr_we2) & MEM_valid;
assign csr_wmask  = {32{MEM_csr_we1}} & csr_wmask_before1 |
                    {32{MEM_csr_we2}} & csr_wmask_before2 ;
assign csr_wvalue = {32{MEM_csr_we1}} & MEM_alu_result1 |
                    {32{MEM_csr_we2}} & MEM_alu_result2 ;
//to RF
always @(*) begin
    if(reset) begin
        WB_result1 = 32'b0;
    end
    else begin
        case(res_from1) 
            5'b00010 : WB_result1 = MEM_csr_rvalue1;
            5'b00100 : WB_result1 = counter_id;
            5'b01000 : WB_result1 = stable_counter[63:32];
            5'b10000 : WB_result1 = stable_counter[31:0];
            default  : WB_result1 = MEM_final_result1;
        endcase
    end
end
always @(*) begin
    if(reset) begin
        WB_result2 = 32'b0;
    end
    else begin
        case(res_from2) 
            5'b00010 : WB_result2 = MEM_csr_rvalue2;
            5'b00100 : WB_result2 = counter_id;
            5'b01000 : WB_result2 = stable_counter[63:32];
            5'b10000 : WB_result2 = stable_counter[31:0];
            default  : WB_result2 = MEM_final_result2;
        endcase
    end
end
assign rf_we1 = gr_we1 && MEM_valid && (~MEM_excp1);
assign rf_waddr1 = MEM_dest1;
assign rf_wdata1 = WB_result1;

assign MEM_rf_bus1 = {
    rf_we1,
    rf_waddr1,
    rf_wdata1
};
assign rf_we2 = gr_we2 && MEM_valid && (~MEM_excp2);
assign rf_waddr2 = MEM_dest2;
assign rf_wdata2 = WB_result2;
assign MEM_rf_bus2 = {
    rf_we2,
    rf_waddr2,
    rf_wdata2
};

//to ID
assign MEM_csr_rvalue1 = inst_sc_w1 ? {31'b0, csr_llbit & ~sc_cancel_req1} : csr_rvalue1;

assign MEM_data_not_prepared1 = ~MEM_valid;
assign MEM_forward_bus1 = {MEM_dest1 & {5{MEM_valid & gr_we1}},MEM_data_not_prepared1,WB_result1};
assign MEM_csr_rvalue2 = inst_sc_w2 ? {31'b0, csr_llbit & ~sc_cancel_req2} : csr_rvalue2;

assign MEM_data_not_prepared2 = ~MEM_valid;
assign MEM_forward_bus2 = {MEM_dest2 & {5{MEM_valid & gr_we2}},MEM_data_not_prepared2,WB_result2};

//ll
assign MEM_llbit_in = (inst_ll_w1 && !data_uncache_en1) | 
                      (inst_ll_w2 && !data_uncache_en2) ;
assign MEM_llbit_set = (inst_ll_w1 | inst_sc_w1) & MEM_valid & ~MEM_ex1 |
                       (inst_ll_w2 | inst_sc_w2) & MEM_valid & ~MEM_ex2 ;
assign MEM_lladdr_in = {32{MEM_lladdr_set1}} & sc_ll_paddr1[31:4] |
                       {32{MEM_lladdr_set2}} & sc_ll_paddr2[31:4] ;
assign MEM_lladdr_set1 = inst_ll_w1 && !data_uncache_en1 && MEM_valid & ~MEM_ex1;
assign MEM_lladdr_set2 = inst_ll_w2 && !data_uncache_en2 && MEM_valid & ~MEM_ex2;
assign MEM_lladdr_set  = MEM_lladdr_set1 | MEM_lladdr_set2;

`ifdef DEBUG
//to cm
    assign MEM_CM_bus1 = {
                            MEM_mode,
                            MEM_dest1,
                            rf_we1,
                            WB_result1,
                            MEM_pc1
                        };
    assign MEM_CM_bus2 = {
                            MEM_dest2,
                            rf_we2,
                            WB_result2,
                            MEM_pc2
                        };
`endif

`ifdef DIFFTEST_EN
    reg [`DIFF_WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_diff_bus_reg_1;
    reg [`DIFF_WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_diff_bus_reg_2;

    wire [63:0] MEM_timer_64_diff_1;
    wire [63:0] MEM_timer_64_diff_2;
    wire [31:0] MEM_csr_data_diff_1;
    wire [31:0] MEM_csr_data_diff_2;

    reg MEM_tlbr_ex_diff_1;
    reg MEM_tlbr_ex_diff_2;
    reg va_error_diff_1;
    reg va_error_diff_2;
    reg MEM_excp_tlb_diff_1;
    reg MEM_excp_tlb_diff_2;
    reg  MEM_valid_diff;
    wire csr_we_diff_1;
    wire csr_we_diff_2;
    wire MEM_llbit_in_diff_1;
    wire MEM_llbit_in_diff_2;
    wire MEM_lladdr_set_diff_1;
    wire MEM_lladdr_set_diff_2;
    wire [93+`WIDTH_TLB_INDEX:0] MEM_TLB_data_diff_1;
    wire [93+`WIDTH_TLB_INDEX:0] MEM_TLB_data_diff_2;

    wire MEM_refetch_diff_1;
    wire MEM_refetch_diff_2;

    assign MEM_refetch_diff_1 =MEM_csr_we1 | (|tlb_op1) | icacop_op_en1 | ((inst_sc_w1 || inst_ll_w1 ) && !MEM_excp1);
    assign MEM_refetch_diff_2 =MEM_csr_we2 | (|tlb_op2) | icacop_op_en2 | ((inst_sc_w2 || inst_ll_w2 ) && !MEM_excp2);

    always @(posedge clk) begin
        if(reset) begin
            EX2_MEM_diff_bus_reg_1 <= 0;
            EX2_MEM_diff_bus_reg_2 <= 0;
            MEM_valid_diff <= 0;
        end
        else if(~stall) begin
            EX2_MEM_diff_bus_reg_1 <= EX2_MEM_diff_bus_1;
            EX2_MEM_diff_bus_reg_2 <= EX2_MEM_diff_bus_2;
            MEM_valid_diff <= EX2_MEM_valid;
        end
    end

    assign MEM_timer_64_diff_1 = stable_counter;
    assign MEM_timer_64_diff_2 = stable_counter;
    assign MEM_csr_data_diff_1 = |res_from1[4:1] ? WB_result1 : 0;
    assign MEM_csr_data_diff_2 = |res_from2[4:1] ? WB_result2 : 0;
    assign csr_we_diff_1 = MEM_csr_we1 & MEM_valid_diff;
    assign csr_we_diff_2 = MEM_csr_we2 & MEM_valid_diff;

    assign MEM_llbit_set_diff_1 = (inst_ll_w1 | inst_sc_w1) & MEM_valid_diff & ~MEM_excp1;
    assign MEM_llbit_set_diff_2 = (inst_ll_w2 | inst_sc_w2) & MEM_valid_diff & ~MEM_excp2 ;
    assign MEM_llbit_in_diff_1 = inst_ll_w1 && !data_uncache_en1;
    assign MEM_llbit_in_diff_2 = inst_ll_w2 && !data_uncache_en2;
    assign MEM_lladdr_set_diff_1 = inst_ll_w1 && !data_uncache_en1 && MEM_valid_diff & ~MEM_excp1;
    assign MEM_lladdr_set_diff_2 = inst_ll_w2 && !data_uncache_en2 && MEM_valid_diff & ~MEM_excp2;


always @(*) begin
    {
     MEM_tlbr_ex_diff_1,
     va_error_diff_1,
     MEM_excp_tlb_diff_1   }  = reset            ? 18'b0             :
                         MEM_excp_num1[ 0] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num1[ 1] ? {1'b0          , MEM_valid_diff, 1'b0          }:
                         MEM_excp_num1[ 2] ? {MEM_valid_diff, MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num1[ 3] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num1[ 4] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num1[ 5] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num1[ 6] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num1[ 7] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num1[ 8] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num1[ 9] ? {1'b0          , MEM_valid_diff, 1'b0          }:
                         MEM_excp_num1[10] ? {MEM_valid_diff, MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num1[11] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num1[12] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num1[13] ? {1'b0          , MEM_valid_diff, MEM_valid}:
                         MEM_excp_num1[14] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         {6'b00_0101, 9'b0_0000_0000, 3'b0};
end
always @(*) begin
    {
     MEM_tlbr_ex_diff_2,
     va_error_diff_2,
     MEM_excp_tlb_diff_2   }  = reset            ? 18'b0             :
                         MEM_excp_num2[ 0] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num2[ 1] ? {1'b0          , MEM_valid_diff, 1'b0          }:
                         MEM_excp_num2[ 2] ? {MEM_valid_diff, MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num2[ 3] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num2[ 4] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num2[ 5] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num2[ 6] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num2[ 7] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num2[ 8] ? {1'b0          , 1'b0          , 1'b0          }:
                         MEM_excp_num2[ 9] ? {1'b0          , MEM_valid_diff, 1'b0          }:
                         MEM_excp_num2[10] ? {MEM_valid_diff, MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num2[11] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num2[12] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         MEM_excp_num2[13] ? {1'b0          , MEM_valid_diff, MEM_valid}:
                         MEM_excp_num2[14] ? {1'b0          , MEM_valid_diff, MEM_valid_diff}:
                         {6'b00_0101, 9'b0_0000_0000, 3'b0};
end
    assign MEM_TLB_data_diff_1 = {tlb_op1[3:0]&{4{MEM_valid_diff & ~MEM_excp1}}, tlb_data1};
    assign MEM_TLB_data_diff_2 = {tlb_op2[3:0]&{4{MEM_valid_diff & ~MEM_excp1}}, tlb_data2};

    assign MEM_CM_diff_bus_1  = {MEM_rf_bus1, MEM_excp1, inst_ertn1, MEM_TLB_data[97-5+`WIDTH_TLB_INDEX], MEM_csr_ecode, MEM_timer_64_diff_1, MEM_csr_data_diff_1, EX2_MEM_diff_bus_reg_1};
    assign MEM_CM_diff_bus_2  = {MEM_rf_bus2, MEM_excp2, inst_ertn2, MEM_TLB_data[97-5+`WIDTH_TLB_INDEX], MEM_csr_ecode, MEM_timer_64_diff_2, MEM_csr_data_diff_2, EX2_MEM_diff_bus_reg_2} & {`DIFF_WIDTH_MEM_CM_BUS{MEM_mode}};

    assign MEM_CM_diff_ctrl_bus_1 = {
        MEM_refetch_diff_1,                // 1
        MEM_excp1,                         // 1
        MEM_csr_ecode & {6{MEM_excp1}},    // 6
        MEM_csr_esubcode & {9{MEM_excp1}}, // 9
        va_error_diff_1,                   // 1
        MEM_tlbr_ex_diff_1,                // 1
        MEM_excp_tlb_diff_1,               // 1
        MEM_pc1,                           // 32
        MEM_vaddr1,                        // 32
        MEM_csr_num1,                      // 14
        csr_we_diff_1,                     // 1
        csr_wmask_before1,                 // 32
        MEM_alu_result1, //wvalue          // 32
        inst_ertn1,                        // 1
        MEM_TLB_data_diff_1,               // 99
        MEM_llbit_in_diff_1,               // 1
        MEM_llbit_set_diff_1,              // 1
        sc_ll_paddr1[31:4],                // 28
        MEM_lladdr_set_diff_1              // 1
    };

    assign MEM_CM_diff_ctrl_bus_2 = {
        MEM_refetch_diff_2,                // 1
        MEM_excp2,                         // 1
        MEM_csr_ecode & {6{MEM_excp2}},    // 6
        MEM_csr_esubcode & {9{MEM_excp2}}, // 9
        va_error_diff_2,                   // 1
        MEM_tlbr_ex_diff_2,                // 1
        MEM_excp_tlb_diff_2,               // 1
        MEM_pc2,                           // 32
        MEM_vaddr2,                        // 32
        MEM_csr_num2,                      // 14
        csr_we_diff_2,                     // 1
        csr_wmask_before2,                 // 32
        MEM_alu_result2, //wvalue          // 32
        inst_ertn2,                        // 1
        MEM_TLB_data_diff_2,               // 99
        MEM_llbit_in_diff_2,               // 1
        MEM_llbit_set_diff_2,              // 1
        sc_ll_paddr2[31:4],                // 28
        MEM_lladdr_set_diff_2              // 1
    } & {`DIFF_WIDTH_MEM_CM_CTRL_BUS{MEM_mode}};
`endif

endmodule