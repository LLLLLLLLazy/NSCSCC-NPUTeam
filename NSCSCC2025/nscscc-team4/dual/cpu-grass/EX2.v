`include "header.h"
module EX2(
    input clk,
    input reset,
    input flush,
    //btb
    input [76:0] btb_bus,
    output operate_en,
    output add_entry,
    output pred_error,
    output target_error,
    output pred_right,
    output right_orien,
    output [31:0] right_target,
    output [ 4:0] operate_index,
    output [31:0] operate_pc,
    output        push_ras,
    output        pop_ras,
    //csr
    input      [63:0]                               stable_counter,
    input      [31:0]                               counter_id,
    input                                           csr_llbit,

    input      [31:0]                               csr_rvalue1,
    input      [31:0]                               csr_rvalue2,
    output     [13:0]                               csr_rnum1,
    output     [13:0]                               csr_rnum2,
    //forward
    output [`WIDTH_EX1_FORWARD_BUS-1:0] EX2_forward_bus1,
    output [`WIDTH_EX1_FORWARD_BUS-1:0] EX2_forward_bus2,
    //trans
    input  MEM_stall,
`ifdef DEBUG
    input CM_stall,
`endif
    output EX2_stall,
    input  EX1_EX2_valid,
    output EX2_MEM_valid,
    input  EX1_EX2_bus2_valid,
    output EX2_MEM_bus2_valid,
    input  [`WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_bus1,
    input  [`WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_bus2,
    output [`WIDTH_EX2_MEM_BUS-1 : 0] EX2_MEM_bus1,
    output [`WIDTH_EX2_MEM_BUS-1 : 0] EX2_MEM_bus2,
    //cache
    output EX2_data_cancel,
    output EX2_inst_cancel,
    output data_uncache_en,
    input  data_data_ok,
    output [19:0] data_tag,
    input  [31:0] data_rdata,

    input dcache_miss

    `ifdef DIFFTEST_EN
        ,
        input  [`DIFF_WIDTH_EX1_EX2_BUS-1:0] EX1_EX2_diff_bus_1,
        input  [`DIFF_WIDTH_EX1_EX2_BUS-1:0] EX1_EX2_diff_bus_2,
        output reg [`DIFF_WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_diff_bus_1,
        output reg [`DIFF_WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_diff_bus_2
    `endif
);

// new
    reg [76:0] btb_reg;
    wire EX1_taken1;

    wire inst_ll_w1;
    wire inst_ll_w2;
    wire inst_sc_w1;
    wire inst_sc_w2;

    wire data_uncache_en1;
    wire data_uncache_en2;

    wire mmu_data_uncache_en1;
    wire mmu_data_uncache_en2;
    wire mmu_sc_addr_eq1;
    wire mmu_sc_addr_eq2;

    wire sc_cancel_req1;
    wire sc_cancel_req2;
    wire data_tlb_excp_cancel_req;
    wire inst_taken_cancel_req;
    wire data_taken_cancel_req;

    wire [31:0] sc_ll_paddr1;
    wire [31:0] sc_ll_paddr2;

    wire EX2_icacop_op_en1;
    wire EX2_icacop_op_en2;

    wire csr_we1;
    wire csr_we2;
    wire [13:0] csr_num1;
    wire [13:0] csr_num2;

    wire [ 4:0] res_from1;
    wire [ 4:0] res_from2;

    wire [ 2:0] mem_type1;
    wire [ 2:0] mem_type2;

    wire [31:0] data_paddr1;
    wire [31:0] data_paddr2;

    wire [31:0] data_alu_result;
    wire [ 2:0] data_mem_type;
    wire [31:0] EX2_data_rdata;

    wire [31:0] EX2_rdata_rj1;
    wire [31:0] EX2_rdata_rj2;

    wire [89+`WIDTH_TLB_INDEX:0] tlb_data1;
    wire [89+`WIDTH_TLB_INDEX:0] tlb_data2;
    wire [ 4:0] tlb_op1;
    wire [ 4:0] tlb_op2;
    wire [ 4:0] invtlb_op1;
    wire [ 4:0] invtlb_op2;
    wire [ 9:0] invtlb_asid1;
    wire [ 9:0] invtlb_asid2;
    wire [18:0] invtlb_vppn1;
    wire [18:0] invtlb_vppn2;
//bus
    reg [`WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_reg1;
    reg [`WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_reg2;
    wire inst_ertn1;
    wire inst_ertn2;
    wire gr_we1;
    wire gr_we2;
    wire [ 4:0] dest1;
    wire [ 4:0] dest2;

    wire [ 4:0] EX2_dest1;
    wire [ 4:0] EX2_dest2;
    wire EX2_data_not_prepared1;
    wire EX2_data_not_prepared2;
    wire [31:0] EX2_data1;
    wire [31:0] EX2_data2;
    wire EX2_data_used1;
    wire EX1_data_used2;

    wire [31:0] EX2_alu_result1;
    wire [31:0] EX2_alu_result2;
    wire [31:0] EX2_pc1;
    wire [31:0] EX2_pc2;

    wire EX1_excp1;
    wire EX1_excp2;
    wire EX2_excp1;
    wire EX2_excp2;
    wire [14:0] EX1_excp_num1;
    wire [14:0] EX1_excp_num2;
    wire [14:0] EX2_excp_num1;
    wire [14:0] EX2_excp_num2;
    wire [31:0] badvaddr1;
    wire [31:0] badvaddr2;

//control
    wire stall;
    reg  EX2_valid;

    reg  data_buf_valid;
    reg  [31:0] data_buf;

    reg first_clk;

//cache and cacop
    reg has_cancel;

    wire access_dcache;
    wire EX1_access_dcache1;
    wire EX1_access_dcache2;

    wire EX1_icacop_op_en1;
    wire EX1_icacop_op_en2;
    wire EX1_dcacop_op_en1;
    wire EX1_dcacop_op_en2;
    wire EX1_preld_en1;
    wire EX1_preld_en2;

    wire [31:0] EX2_result;
    wire [ 7:0] EX2_byte;
    wire [15:0] EX2_half;

    wire EX1_mode_buf;
    wire EX2_mode;
    wire EX2_flush;

    wire br_inst;
    wire FIFO_full;
    wire FIFO_empty;

// forward
    assign EX2_forward_bus1 = {EX2_dest1, EX2_data_not_prepared1, EX2_data1};
    assign EX2_forward_bus2 = {EX2_dest2, EX2_data_not_prepared2, EX2_data2};
    assign EX2_dest1  = dest1 & {5{EX2_valid & gr_we1}};
    assign EX2_dest2  = dest2 & {5{EX2_valid & gr_we2}};
    assign EX2_data_not_prepared1 = ~EX2_data_used1;
    assign EX2_data_not_prepared2 = ~EX2_data_used2;
    assign EX2_data_used1 = (!res_from1 || (res_from1[0] & ~EX2_stall)) & EX2_valid & ~flush;
    assign EX2_data_used2 = (!res_from2 || (res_from2[0] & ~EX2_stall)) & EX2_valid & ~flush & EX2_mode;
    assign EX2_data1 = res_from1[0] ? EX2_data_rdata : EX2_alu_result1;
    assign EX2_data2 = res_from2[0] ? EX2_data_rdata : EX2_alu_result2;

//btb
    assign {
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
    } = btb_reg;
    assign operate_en = EX2_valid & first_clk & ~flush & (~btb_mode | btb_mode & EX1_mode_buf);
//bus
assign EX2_MEM_bus1 = {
    dcache_miss,
    FIFO_full,
    FIFO_empty,
    //all 379+32
    // 38
    br_inst,
    EX2_mode,
    EX2_flush,
    inst_ll_w1,            // 1
    inst_sc_w1,            // 1
    data_uncache_en1,       // 1
    sc_cancel_req1,         // 1
    sc_ll_paddr1,          // 32
    // 181
    tlb_data1,             // 95
    csr_we1,               // 1
    csr_num1,              // 14
    res_from1,             // 5
    gr_we1,                // 1
    mem_type1,             // 3
    dest1,                 // 5
    EX2_excp_num1,         // 15
    EX2_excp1,             // 1
    inst_ertn1,            // 1
    EX2_icacop_op_en1,      // 1
    invtlb_asid1,          // 10
    invtlb_vppn1,          // 19
    invtlb_op1,            // 5
    tlb_op1,               // 5
    // 160+32
    EX2_rdata_rj1,         // 32   CSR mask
    stable_counter,
    counter_id,
    csr_llbit,
    csr_rvalue1,
    badvaddr1,             // 32
    EX2_alu_result1,       // 32
    EX2_data_rdata,        // 32
    EX2_pc1                // 32
};
assign EX2_MEM_bus2 = {
    //all 379+32
    // 38
    1'b0,                  // 1
    1'b0,                  // 1
    inst_ll_w2,            // 1
    inst_sc_w2,            // 1
    data_uncache_en2,                  // 1
    sc_cancel_req2,                  // 1
    sc_ll_paddr2,          // 32
    // 181
    tlb_data2,             // 95
    csr_we2,               // 1
    csr_num2,              // 14
    res_from2,             // 5
    gr_we2,                // 1
    mem_type2,             // 3
    dest2,                 // 5
    EX2_excp_num2,         // 15
    EX2_excp2,             // 1
    inst_ertn2,            // 1
    EX2_icacop_op_en2,      // 1
    invtlb_asid2,          // 10
    invtlb_vppn2,          // 19
    invtlb_op2,            // 5
    tlb_op2,               // 5
    // 160+32
    EX2_rdata_rj2,         // 32   CSR mask
    97'b0,
    csr_rvalue2,
    badvaddr2,             // 32
    EX2_alu_result2,       // 32
    EX2_data_rdata,        // 32
    EX2_pc2                // 32
};

    always@(posedge clk) begin
        if(reset) begin
            EX1_EX2_reg1 <= `WIDTH_EX1_EX2_BUS'b0;
            EX1_EX2_reg2 <= `WIDTH_EX1_EX2_BUS'b0;
        end
        else if(~stall) begin
            EX1_EX2_reg1 <= EX1_EX2_bus1;
            EX1_EX2_reg2 <= {`WIDTH_EX1_EX2_BUS{EX1_EX2_bus2_valid}} & EX1_EX2_bus2;
            btb_reg      <= btb_bus;
        end
    end

assign {
    FIFO_full,
    FIFO_empty,
    br_inst,
    EX1_mode_buf,
    EX1_taken1,
    inst_ll_w1,
    inst_sc_w1,
    EX1_icacop_op_en1,
    EX1_dcacop_op_en1,
    EX1_preld_en1,
    EX1_access_dcache1,
    mmu_data_uncache_en1,
    mmu_sc_addr_eq1,
    sc_ll_paddr1,
    invtlb_asid1,
    invtlb_vppn1,
    invtlb_op1,
    tlb_op1,
    tlb_data1,
    inst_ertn1,
    csr_we1,
    csr_num1,
    res_from1,
    gr_we1,
    mem_type1,
    dest1,
    EX1_excp_num1,
    EX1_excp1,
    badvaddr1,
    data_paddr1,
    EX2_alu_result1,
    EX2_rdata_rj1,
    EX2_pc1
} = EX1_EX2_reg1;
assign {
    inst_ll_w2,
    inst_sc_w2,
    EX1_icacop_op_en2,
    EX1_dcacop_op_en2,
    EX1_preld_en2,
    EX1_access_dcache2,
    mmu_data_uncache_en2,
    mmu_sc_addr_eq2,
    sc_ll_paddr2,
    invtlb_asid2,
    invtlb_vppn2,
    invtlb_op2,
    tlb_op2,
    tlb_data2,
    inst_ertn2,
    csr_we2,
    csr_num2,
    res_from2,
    gr_we2,
    mem_type2,
    dest2,
    EX1_excp_num2,
    EX1_excp2,
    badvaddr2,
    data_paddr2,
    EX2_alu_result2,
    EX2_rdata_rj2,
    EX2_pc2
} = EX1_EX2_reg2;

// control
    assign EX2_mode = EX1_mode_buf & EX2_valid & ~EX1_taken1;
`ifdef DEBUG
    assign stall = EX2_stall | MEM_stall || CM_stall;
`else
    assign stall = EX2_stall | MEM_stall;
`endif
    assign access_dcache = (EX1_access_dcache1 | EX1_access_dcache2) & ~(EX2_data_cancel | has_cancel); 
    assign EX2_stall = ~reset & EX2_valid & ((access_dcache & (~data_data_ok & ~data_buf_valid)));
    assign EX2_MEM_valid = ~flush & EX2_valid & ~EX2_stall;
    assign EX2_MEM_bus2_valid = EX2_mode;
    assign EX2_data_rdata = {32{data_buf_valid}}  & data_buf |
                            {32{~data_buf_valid}} & EX2_result;

    assign data_alu_result = {32{EX1_access_dcache1}} & EX2_alu_result1 | 
                             {32{EX1_access_dcache2}} & EX2_alu_result2;
    assign data_mem_type   = { 3{EX1_access_dcache1}} & mem_type1 |
                             { 3{EX1_access_dcache2}} & mem_type2;

    assign EX2_byte   = ({8{data_alu_result[1:0] == 2'b00}} & data_rdata[ 7: 0]) |
                        ({8{data_alu_result[1:0] == 2'b01}} & data_rdata[15: 8]) |
                        ({8{data_alu_result[1:0] == 2'b10}} & data_rdata[23:16]) |
                        ({8{data_alu_result[1:0] == 2'b11}} & data_rdata[31:24]) ; 
                                                                
    assign EX2_half   = ({16{data_alu_result[1:0] == 2'b00}} & data_rdata[15: 0]) |
                        ({16{data_alu_result[1:0] == 2'b10}} & data_rdata[31:16]) ;

    assign EX2_result =  ({32{(data_mem_type == 3'b110)}} & {{24{EX2_byte[ 7]}}, EX2_byte}) | // ld.b
                         ({32{(data_mem_type == 3'b010)}} & { 24'b0            , EX2_byte}) | // ld.bu
                         ({32{(data_mem_type == 3'b101)}} & {{16{EX2_half[15]}}, EX2_half}) | // ld.h
                         ({32{(data_mem_type == 3'b001)}} & { 16'b0            , EX2_half}) | // ld.hu
                         ({32{!data_mem_type}}            & data_rdata                    ) ; // ld.w

    always@(posedge clk) begin
        if(reset | flush) begin
            EX2_valid <= 1'b0;
        end
        else if(~stall) begin
            EX2_valid <= EX1_EX2_valid;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            data_buf <= 32'b0;
            data_buf_valid <= 1'b0;
        end
        else if(~stall) begin
            data_buf_valid <= 1'b0;
        end
        else if(data_data_ok) begin
            data_buf <= EX2_result;
            data_buf_valid <= 1'b1;
        end
    end


//cache
    assign data_tag = data_paddr1[31:12];

    assign data_uncache_en  = data_uncache_en1 | data_uncache_en2;
    assign data_uncache_en1 = mmu_data_uncache_en1 & EX2_valid & ~EX2_excp1;
    assign data_uncache_en2 = mmu_data_uncache_en2 & EX2_valid & ~EX2_excp2 & EX2_mode;

    assign sc_cancel_req1 = (!mmu_sc_addr_eq1 | mmu_data_uncache_en1) & inst_sc_w1 & EX2_valid;
    assign sc_cancel_req2 = (!mmu_sc_addr_eq2 | mmu_data_uncache_en2) & inst_sc_w2 & EX2_valid & EX2_mode;

    assign data_tlb_excp_cancel_req = ((|EX2_excp_num1[14:10]) | (|EX2_excp_num2[14:10]) & EX2_mode) & EX2_valid;
    assign data_taken_cancel_req = EX1_taken1 & (EX1_access_dcache2 | EX1_dcacop_op_en2 | EX1_preld_en2) & EX1_mode_buf & EX2_valid;
    assign inst_taken_cancel_req = EX1_taken1 & EX1_icacop_op_en2 & EX1_mode_buf & EX2_valid; //mode bufӦ�ò���Ҫ

    assign EX2_data_cancel = (data_tlb_excp_cancel_req | data_taken_cancel_req | sc_cancel_req1 | sc_cancel_req2) & first_clk;
    assign EX2_inst_cancel = ((data_tlb_excp_cancel_req & (EX1_icacop_op_en1 | EX1_icacop_op_en2)) | inst_taken_cancel_req) & first_clk;

    always@(posedge clk) begin
        if(reset) begin
            has_cancel <= 1'b0;
        end
        else if(~stall) begin
            has_cancel <= 1'b0;
        end
        else if(EX2_data_cancel) begin
            has_cancel <= 1'b1;
        end
    end

    assign EX2_icacop_op_en1 = EX1_icacop_op_en1 & EX2_valid & ~EX2_excp1 & ~flush;
    assign EX2_icacop_op_en2 = EX1_icacop_op_en2 & EX2_valid & ~EX2_excp2 & ~flush & EX2_mode;

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

//exception
    assign EX2_excp1     = EX1_excp1;
    assign EX2_excp_num1 = EX1_excp_num1;
    assign EX2_excp2     = EX1_excp2;
    assign EX2_excp_num2 = EX1_excp_num2;

// flush
    assign EX2_flush = (EX2_excp1  | EX2_excp2  & EX2_mode) | 
                       (inst_ertn1 | inst_ertn2 & EX2_mode) | 
                       ( csr_we1 | (|tlb_op1) | EX2_icacop_op_en1 | inst_sc_w1 || inst_ll_w1 ) |
                       ( csr_we2 | (|tlb_op2) | EX2_icacop_op_en2 | inst_sc_w2 || inst_ll_w2 ) & EX2_mode;

    assign csr_rnum1 = csr_num1;
    assign csr_rnum2 = csr_num2;
`ifdef DIFFTEST_EN
    always@(posedge clk) begin
        if(reset | flush) begin
            EX2_MEM_diff_bus_1 <= 0;
            EX2_MEM_diff_bus_2 <= 0;
        end
        else if(~stall) begin
            EX2_MEM_diff_bus_1 <= EX1_EX2_diff_bus_1;
            EX2_MEM_diff_bus_2 <= EX1_EX2_diff_bus_2;
        end
    end
`endif
endmodule