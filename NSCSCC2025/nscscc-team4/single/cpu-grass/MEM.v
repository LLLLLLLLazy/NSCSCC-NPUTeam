`include "csr.h"
`include "header.h"
module MEM
#(
    parameter TLBNUM = 16
)
(
    input                                           clk,
    input                                           reset,
    input      [`WIDTH_EX2_MEM_BUS-1 -5+$clog2(TLBNUM):0]             EX2_MEM_bus,
    output                                          flush,
    output     reg                                  MEM_valid,
    input                                           EX2_MEM_valid,
    output                                          MEM_stall,
    output                                          MEM_ex,
    output                                          MEM_ertn,
    output     reg                                  MEM_tlbr_ex,
    output                                          MEM_refetch,
    output     reg                                  va_error,
    output     reg                                  MEM_excp_tlb,

    output     [`WIDTH_MEM_RF_BUS-1:0]              MEM_rf_bus,
    output     [31:0]                               MEM_pc,
    output     [31:0]                               MEM_vaddr,
    output     [`WIDTH_MEM_FORWARD_BUS-1:0]         MEM_forward_bus,     
    // csr
    input      [31:0]                               csr_rvalue,
    output     [13:0]                               csr_num,
    output                                          csr_we,
    output     [31:0]                               csr_wmask,
    output     [31:0]                               csr_wvalue,
    output     reg [ 5:0]                           MEM_csr_ecode,
    output     reg [ 8:0]                           MEM_csr_esubcode,
    input      [63:0]                               stable_counter,
    input      [31:0]                               counter_id,

    //ll
    input                                           csr_llbit,
    output                                          MEM_llbit_in,
    output                                          MEM_llbit_set,
    output     [27:0]                               MEM_lladdr_in,
    output                                          MEM_lladdr_set,

    //TLB
    output     [98-5+$clog2(TLBNUM):0]                               MEM_TLB_data,
    output                                          invtlb_en,
    output     [ 4:0]                               invtlb_op,
    output     [ 9:0]                               invtlb_asid,
    output     [18:0]                               invtlb_vppn,
    // debug
    output     [31:0]                               debug_wb_pc,
    output     [ 3:0]                               debug_wb_rf_we,
    output     [ 4:0]                               debug_wb_rf_wnum,
    output     [31:0]                               debug_wb_rf_wdata


    //difftest
    `ifdef DIFFTEST_EN
    ,
    input [`DIFF_WIDTH_EX2_MEM_BUS-1 : 0] EX2_MEM_diff_bus,
    output reg [31:0] debug0_wb_inst                   ,
    output            mem_valid_diff                    ,
    output reg        mem_cnt_inst_diff                 ,
    output     [63:0] mem_timer_64_diff                 ,
    output reg [ 7:0] mem_inst_ld_en_diff               ,
    output reg [31:0] mem_ld_paddr_diff                 ,
    output reg [31:0] mem_ld_vaddr_diff                 ,
    output reg [ 7:0] mem_inst_st_en_diff               ,
    output     [31:0] mem_st_paddr_diff                 ,
    output     [31:0] mem_st_vaddr_diff                 ,
    output reg [31:0] mem_st_data_diff                  ,
    output reg        mem_csr_rstat_en_diff             ,
    output     [31:0] mem_csr_data_diff         
    `endif

);


`ifdef DIFFTEST_EN
    always @(posedge clk) begin
        if(~MEM_stall) begin
            {debug0_wb_inst,
             mem_cnt_inst_diff,
             mem_inst_ld_en_diff,
             mem_ld_paddr_diff,
             mem_ld_vaddr_diff,
             mem_inst_st_en_diff,
             mem_st_data_diff,
             mem_csr_rstat_en_diff
    } <= EX2_MEM_diff_bus;
        end
    end
    assign mem_st_paddr_diff = mem_ld_paddr_diff;
    assign mem_st_vaddr_diff = mem_ld_vaddr_diff;
`endif


wire   [ 4:0] MEM_dest;
wire   [31:0] MEM_final_result;
wire   [31:0] MEM_result;
reg    [31:0] WB_result;
wire   [94-5+$clog2(TLBNUM):0] tlb_data;
wire          MEM_csr_we;
wire   [13:0] MEM_csr_num;
wire   [ 4:0] res_from;
wire          gr_we;
wire   [ 2:0] mem_type;
wire   [14:0] MEM_excp_num;
wire          MEM_excp;
wire          inst_ertn;
wire          MEM_tlb;
wire          inst_ll_w;
wire          inst_sc_w;
wire          sc_cancel_req;
wire   [31:0] MEM_csr_rvalue;
wire          data_uncache_en;
wire   [31:0] sc_ll_paddr;
wire          icacop_op_en;
wire   [ 4:0] tlb_op;
wire   [31:0] csr_wmask_before;
wire   [31:0] MEM_alu_result;
wire   [31:0] MEM_data_rdata;
reg    [31:0] MEM_csr_wmask;
reg    [`WIDTH_EX2_MEM_BUS-1:0] EX2_MEM_reg;
wire          MEM_data_not_prepared;
reg    [31:0] MEM_data;
wire          rf_we;
wire   [31:0] rf_wdata;
wire   [ 4:0] rf_waddr;

assign {
        inst_ll_w,
        inst_sc_w,
        data_uncache_en,
        sc_cancel_req,
        sc_ll_paddr,
        tlb_data,
        MEM_csr_we,
        MEM_csr_num,
        res_from,
        gr_we,
        mem_type,
        MEM_dest,
        MEM_excp_num,
        MEM_excp,
        inst_ertn,
        icacop_op_en,
        invtlb_asid,
        invtlb_vppn,
        invtlb_op,
        tlb_op,
        csr_wmask_before,
        MEM_vaddr,
        MEM_alu_result,
        MEM_data_rdata,
        MEM_pc} = EX2_MEM_reg;

assign invtlb_en = tlb_op[4] & MEM_valid & ~MEM_ex;
assign MEM_TLB_data = {tlb_op[3:0]&{4{MEM_valid & ~MEM_ex}}, tlb_data};
assign MEM_stall = 1'b0;
assign MEM_ex = MEM_excp & MEM_valid;
assign MEM_ertn = inst_ertn & MEM_valid;
assign MEM_tlb = (|tlb_op) & MEM_valid;
assign MEM_refetch =( csr_we | MEM_tlb | icacop_op_en | ((inst_sc_w || inst_ll_w ) && !MEM_ex)) & MEM_valid;
assign flush = MEM_ex | MEM_ertn | MEM_refetch ;//| MEM_idle;

always @(posedge clk ) begin
    if(reset) begin
        EX2_MEM_reg <= {`WIDTH_EX2_MEM_BUS{1'b0}};
    end
    else if (!MEM_stall) begin
        EX2_MEM_reg <= EX2_MEM_bus;
    end
end

always @(posedge clk ) begin
    if (reset || flush) MEM_valid <= 1'b0;
    else if (!MEM_stall) MEM_valid <= EX2_MEM_valid;
end


assign MEM_final_result = 
    ({32{(res_from==5'b0)}} & MEM_alu_result)|  
    ({32{res_from[0]} }     & MEM_data_rdata);       

//to CSR
always @(*) begin
    {MEM_csr_ecode,
     MEM_csr_esubcode,
     MEM_tlbr_ex,
     va_error,
     MEM_excp_tlb   }  = reset            ? 18'b0             :
                         MEM_excp_num[ 0] ? {`ECODE_INT ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num[ 1] ? {`ECODE_ADE ,9'b0, 1'b0     , MEM_valid, 1'b0     }:
                         MEM_excp_num[ 2] ? {`ECODE_TLBR,9'b0, MEM_valid, MEM_valid, MEM_valid}:
                         MEM_excp_num[ 3] ? {`ECODE_PIF ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num[ 4] ? {`ECODE_PPI ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num[ 5] ? {`ECODE_SYS ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num[ 6] ? {`ECODE_BRK ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num[ 7] ? {`ECODE_INE ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num[ 8] ? {`ECODE_IPE ,9'b0, 1'b0     , 1'b0     , 1'b0     }:
                         MEM_excp_num[ 9] ? {`ECODE_ALE ,9'b0, 1'b0     , MEM_valid, 1'b0     }:
                         MEM_excp_num[10] ? {`ECODE_TLBR,9'b0, MEM_valid, MEM_valid, MEM_valid}:
                         MEM_excp_num[11] ? {`ECODE_PME ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num[12] ? {`ECODE_PPI ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num[13] ? {`ECODE_PIS ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         MEM_excp_num[14] ? {`ECODE_PIL ,9'b0, 1'b0     , MEM_valid, MEM_valid}:
                         {6'b00_0101, 9'b0_0000_0000, 3'b0};
end
assign csr_num = MEM_csr_num;
assign csr_we  = MEM_csr_we & MEM_valid;
always @(*) begin
    if(reset) begin
        MEM_csr_wmask = 32'b0;
    end
    else if (MEM_excp_num[1]|MEM_excp_num[2]|MEM_excp_num[3]|MEM_excp_num[4]|MEM_excp_num[9]|MEM_excp_num[11]|MEM_excp_num[12]|MEM_excp_num[13]|MEM_excp_num[14]) begin
        MEM_csr_wmask = 32'b1;
    end
    else begin
        MEM_csr_wmask = csr_wmask_before;
    end
end
assign csr_wmask  = MEM_csr_wmask;
assign csr_wvalue = MEM_alu_result;

//to RF
always @(*) begin
    if(reset) begin
        WB_result = 32'b0;
    end
    else begin
        case(res_from) 
            5'b00010 : WB_result = MEM_csr_rvalue;
            5'b00100 : WB_result = counter_id;
            5'b01000 : WB_result = stable_counter[63:32];
            5'b10000 : WB_result = stable_counter[31:0];
            default  : WB_result = MEM_final_result;
        endcase
    end
end
assign rf_we = gr_we && MEM_valid && (~MEM_excp);
assign rf_waddr = MEM_dest;
assign rf_wdata = WB_result;

assign MEM_rf_bus = {
    rf_we,
    rf_waddr,
    rf_wdata
};
//to ID
assign MEM_csr_rvalue = inst_sc_w ? {31'b0, csr_llbit & ~sc_cancel_req} : csr_rvalue;
always @(*) begin
    if(reset) begin
        MEM_data = 32'b0;
    end
    else begin
        case(res_from) 
            5'b00000 : MEM_data = MEM_alu_result;
            5'b00001 : MEM_data = MEM_data_rdata;
            5'b00010 : MEM_data = MEM_csr_rvalue;
            5'b00100 : MEM_data = counter_id;
            5'b01000 : MEM_data = stable_counter[63:32];
            5'b10000 : MEM_data = stable_counter[31:0];
            default  : MEM_data = 32'b0;
        endcase
    end
end
assign MEM_data_not_prepared = ~MEM_valid;
assign MEM_forward_bus = {MEM_dest & {5{MEM_valid & gr_we}},MEM_data_not_prepared,MEM_data};

//ll
assign MEM_llbit_in = inst_ll_w && !data_uncache_en;
assign MEM_llbit_set = (inst_ll_w | inst_sc_w) & MEM_valid & ~MEM_ex;
assign MEM_lladdr_in = sc_ll_paddr[31:4];
assign MEM_lladdr_set = inst_ll_w && !data_uncache_en && MEM_valid & ~MEM_ex;

//to debug
assign debug_wb_pc = MEM_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = MEM_dest;
assign debug_wb_rf_wdata = WB_result;

`ifdef DIFFTEST_EN
    assign mem_valid_diff = MEM_valid & ~MEM_ex;
    assign mem_timer_64_diff = stable_counter;
    assign mem_csr_data_diff = |res_from[4:1] ? WB_result : 0; // cunyi
`endif

endmodule