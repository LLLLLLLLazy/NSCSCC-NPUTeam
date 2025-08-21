`include "header.h"
module EX2
#(
    parameter TLBNUM = 16
)
(
    input clk,
    input reset,
    input flush,
    //forward
    output [`WIDTH_EX1_FORWARD_BUS-1:0] EX2_forward_bus,
    //trans
    input  MEM_stall,
    output EX2_stall,
    input  EX1_EX2_valid,
    output EX2_MEM_valid,
    input  [`WIDTH_EX1_EX2_BUS-1 -5+$clog2(TLBNUM): 0] EX1_EX2_bus,
    output [`WIDTH_EX2_MEM_BUS-1 -5+$clog2(TLBNUM): 0] EX2_MEM_bus,
    //cache
    output EX2_data_cancel,
    output EX2_inst_cancel,
    output data_uncache_en,
    input  data_addr_ok,
    input  data_data_ok,
    output [19:0] data_tag,
    input  [31:0] data_rdata


`ifdef DIFFTEST_EN
    ,
    input  [`DIFF_WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_diff_bus,
    output [`DIFF_WIDTH_EX2_MEM_BUS-1 : 0] EX2_MEM_diff_bus
`endif
);

// new
    wire [31:0] data_paddr;
    wire [89+$clog2(TLBNUM):0] tlb_data;
    wire mmu_data_uncache_en;
    wire icacop_op_en;
    wire EX1_icacop_op_en;
    wire EX1_access_dcache;
    wire data_tlb_excp_cancel_req;
    reg first_clk;
// forward
    wire [31:0] EX2_data;
    wire [ 4:0] EX2_dest;
    wire EX2_data_not_prepared;
    wire EX2_data_used;
//bus
    reg [`WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_reg;
    wire inst_ertn;
    wire csr_we;
    wire [13:0] csr_num;
    wire [ 4:0] res_from;
    wire gr_we;
    wire EX2_load_op;
    wire EX2_store_op;
    wire [ 2:0] mem_type;
    wire [ 4:0] dest;
    wire [31:0] badvaddr;
    wire [31:0] EX2_alu_result;
    wire [ 3:0] EX2_data_wstrb;
    wire [ 2:0] EX2_data_size;
    wire [31:0] EX2_data_rdata;
    wire [31:0] EX2_data_wdata;
    wire [31:0] EX2_rdata_rkd;
    wire [31:0] EX2_rdata_rj;
    wire [31:0] EX2_pc;

    wire [ 4:0] tlb_op;
    wire [ 4:0] invtlb_op;
    wire [ 9:0] invtlb_asid;
    wire [18:0] invtlb_vppn;

    wire [31:0] EX2_result;
    wire [ 7:0] EX2_byte;
    wire [15:0] EX2_half;

    wire inst_ll_w;
    wire inst_sc_w;

//control
    wire stall;
    reg [31:0] data_buf;
    reg data_buf_valid;
    reg EX2_valid;

//cache and cacop
    wire access_dcache;

    wire mmu_sc_addr_eq;
    wire sc_cancel_req;

    wire [31:0] sc_ll_paddr;

//ex and flush
    wire EX2_tlb_excp;
    wire EX2_excp;
    wire [14:0] EX2_excp_num;

// forward
    assign EX2_forward_bus = EX2_dest;
    assign EX2_dest  = dest & {5{EX2_valid & gr_we}};

//bus
assign EX2_MEM_bus = {
    //377
    //36
    inst_ll_w,            // 1
    inst_sc_w,            // 1
    data_uncache_en,      // 1
    sc_cancel_req,        // 1
    sc_ll_paddr,          // 32
    // 181
    tlb_data,             // 95
    csr_we,               // 1
    csr_num,              // 14
    res_from,             // 5
    gr_we,                // 1
    mem_type,             // 3
    dest,                 // 5
    EX2_excp_num,         // 15
    EX2_excp,             // 1
    inst_ertn,            // 1
    icacop_op_en,         // 1
    invtlb_asid,          // 10
    invtlb_vppn,          // 19
    invtlb_op,            // 5
    tlb_op,               // 5
    // 160
    EX2_rdata_rj,         // 32   CSR mask
    badvaddr,             // 32
    EX2_alu_result,       // 32
    EX2_data_rdata,       // 32
    EX2_pc                // 32
};

    always@(posedge clk) begin
        if(reset) begin
            EX1_EX2_reg <= `WIDTH_EX1_EX2_BUS'b0;
        end
        else if(~stall) begin
            EX1_EX2_reg <= EX1_EX2_bus;
        end
    end


assign {
    inst_ll_w,
    inst_sc_w,
    EX1_icacop_op_en,
    EX1_access_dcache,
    mmu_data_uncache_en,
    mmu_sc_addr_eq,
    sc_ll_paddr,
    invtlb_asid,
    invtlb_vppn,
    invtlb_op,
    tlb_op,
    tlb_data,
    inst_ertn,
    csr_we,
    csr_num,
    res_from,
    gr_we,
    EX2_load_op,
    EX2_store_op,
    mem_type,
    dest,
    EX2_excp_num,
    EX2_excp,
    badvaddr,
    data_paddr,
    EX2_alu_result,
    EX2_data_wstrb,
    EX2_data_size,
    EX2_data_wdata,
    EX2_rdata_rkd,
    EX2_rdata_rj,
    EX2_pc
} = EX1_EX2_reg;


// control
    assign stall = EX2_stall | MEM_stall;
    assign access_dcache = EX1_access_dcache; 
    assign EX2_stall = reset ? 1'b0 : EX2_valid & ((access_dcache & (~data_data_ok & ~data_buf_valid)));
    assign EX2_MEM_valid = EX2_valid & ~EX2_stall;
    assign EX2_data_rdata = {32{data_buf_valid}}  & data_buf |
                            {32{~data_buf_valid}} & EX2_result;

    assign EX2_byte   = ({8{EX2_alu_result[1:0] == 2'b00}} & data_rdata[ 7: 0]) |
                        ({8{EX2_alu_result[1:0] == 2'b01}} & data_rdata[15: 8]) |
                        ({8{EX2_alu_result[1:0] == 2'b10}} & data_rdata[23:16]) |
                        ({8{EX2_alu_result[1:0] == 2'b11}} & data_rdata[31:24]) ; 
                                                                
    assign EX2_half   = ({16{EX2_alu_result[1:0] == 2'b00}} & data_rdata[15: 0]) |
                        ({16{EX2_alu_result[1:0] == 2'b10}} & data_rdata[31:16]) ;

    assign EX2_result =  ({32{(mem_type == 3'b110)}} & {{24{EX2_byte[ 7]}}, EX2_byte}) | // ld.b
                         ({32{(mem_type == 3'b010)}} & { 24'b0            , EX2_byte}) | // ld.bu
                         ({32{(mem_type == 3'b101)}} & {{16{EX2_half[15]}}, EX2_half}) | // ld.h
                         ({32{(mem_type == 3'b001)}} & { 16'b0            , EX2_half}) | // ld.hu
                         ({32{!mem_type}}            & data_rdata                    ) ; // ld.w

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
        else if(data_data_ok) begin
            data_buf <= EX2_result;
            data_buf_valid <= 1'b1;
        end
        else if(~stall) begin
            data_buf_valid <= 1'b0;
        end
    end


//cache
    assign data_tag = data_paddr[31:12];

    assign data_uncache_en = mmu_data_uncache_en & EX2_valid;
    assign sc_cancel_req = (!mmu_sc_addr_eq | mmu_data_uncache_en) & inst_sc_w & EX2_valid; 
    assign data_tlb_excp_cancel_req = (|EX2_excp_num[14:10]) & EX2_valid; // flush不用管

    assign EX2_data_cancel = (data_tlb_excp_cancel_req | sc_cancel_req)  & first_clk;
    assign EX2_inst_cancel = data_tlb_excp_cancel_req & EX1_icacop_op_en & first_clk;

    assign icacop_op_en = EX1_icacop_op_en & EX2_valid & ~flush;

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

`ifdef DIFFTEST_EN
    reg  [31:0] EX2_inst;
    reg         EX2_cnt_inst;
    reg  [ 7:0] EX2_inst_ld_en;
    wire [31:0] EX2_ld_paddr;
    wire [31:0] EX2_ld_vaddr;
    reg  [ 7:0] EX2_inst_st_en;
    wire [31:0] EX2_st_data;
    reg         EX2_csr_rstat_en;

    always @(posedge clk) begin
        if(~stall) begin
            {   EX2_inst,
                EX2_cnt_inst,
                EX2_inst_ld_en,
                EX2_inst_st_en,
                EX2_csr_rstat_en
            } <= EX1_EX2_diff_bus;
        end
    end
    assign EX2_MEM_diff_bus = {
        EX2_inst,
        EX2_cnt_inst,
        EX2_inst_ld_en,
        EX2_ld_paddr,
        EX2_ld_vaddr,
        EX2_inst_st_en,
        EX2_st_data,
        EX2_csr_rstat_en
    };
    assign EX2_ld_paddr = data_paddr;
    assign EX2_ld_vaddr = EX2_alu_result;
    assign EX2_st_data  = EX2_data_wdata;
`endif

endmodule