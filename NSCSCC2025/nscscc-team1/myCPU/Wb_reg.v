module Wb_reg (
    input wire clk,
    input wire rst,
    input wire mem_ready_go,
    input wire wb_ex,
    input wire [31:0] mem_alu_result,
    input wire mem_ref_we,
    input wire [4:0] mem_rd,
    input wire mem_br_taken,
    input wire [31:0] mem_br_target,
    input wire [31:0] mem_dram_rdata,
    input wire mem_res_from_dram,
    input wire [31:0] mem_dram_wdata,
    input wire [31:0] mem_dram_waddr,
    input wire mem_dram_we,
    input wire [31:0] mem_pc,
    input wire [1:0]mem_rdram_num,
    input wire mem_rdram_need_signed_extend,
    input wire mem_rdram_need_zero_extend,
    input wire [31:0] mem_data_addr,
    input wire [13:0] mem_csr_num,
    input wire mem_csr_we,
    input wire mem_is_ertn,
    input wire mem_is_syscall,
    input wire mem_res_from_csr,
    input wire [31:0] mem_csr_wmask,
    input wire [31:0] mem_csr_wdata,
    input wire mem_ex_adef,
    input wire mem_ex_brk,
    input wire mem_ex_ine,
    input wire mem_ex_ale_h,
    input wire mem_ex_ale_w,
    input wire mem_has_int,
    input wire [4:0]mem_rj,
    input wire [31:0]mem_res_of_cnt,
    input wire mem_res_is_rj,
    input wire mem_res_from_cnt,
    input wire mem_ex_ale,
    input wire mem_res_from_tid,
    input wire mem_need_cancel,
    input wire mem_inst_tlbrd,
    input wire mem_inst_tlbsrch,
    input wire mem_tlb_wr_en,
    input wire mem_tlb_we,
    input wire mem_tlb_fill_en,
    input wire [9:0] mem_invtlb_asid,
    input wire [4:0] mem_invtlb_op,
    input wire [18:0] mem_invtlb_va,
    input wire mem_invtlb_valid,
    input wire mem_tlb_or_csr_we,
    input wire [1:0] mem_inst_tlb_ex,
    input wire [2:0] mem_data_tlb_ex,
    input wire mem_icache_v_we,          // ICache valid ˧ ???
    input wire mem_dcache_v_we,          // DCache valid ˧ ???
    input wire mem_dcache_tag_we,        // DCache tag ˧ ???
    input wire mem_icache_tag_we,        // ICache tag ˧ ???
    input wire [31:0] mem_cacop_va,      // Cache??????????
    input wire mem_cacop_need_phy,       // ?????????????
    input wire mem_cacop_en,             // Cache???????
    input wire mem_inst_cacop,           // Cache?????????
    input wire mem_data_cacop,           // Cache??????????    
    input wire [31:0] mem_inst,
    input wire mem_inst_cnt,
    input wire [63:0] mem_timer_64,
    input wire [7:0]mem_inst_ld_en,
    input wire [7:0]mem_inst_st_en,
    input wire mem_csr_rstat_en,
    input wire [31:0] mem_csr_data,
    input wire [31:0] mem_data_phy_addr,
    input wire mem_inst_cpucfg,
    input wire [31:0] mem_cpucfg_result,

    //input wire [31:0]mem_dram_rdata,
    //input wire [31:0] mem_csr_rdata,

    output reg wb_rf_we,
    output reg [31:0] wb_alu_result,
    output reg [4:0] wb_rd,
    output reg wb_br_taken,
    output reg [31:0] wb_br_target,
    output reg [31:0] wb_dram_rdata,
    output reg wb_res_from_dram,
    output reg [31:0] wb_dram_waddr,
    output reg [31:0] wb_dram_wdata,
    output reg wb_dram_we,
    output reg [31:0] wb_pc,
    output reg [1:0]wb_rdram_num,
    output reg wb_rdram_need_signed_extend,
    output reg wb_rdram_need_zero_extend ,
    output reg [31:0] wb_data_addr,
    output reg [13:0] wb_csr_num,
    output reg wb_csr_we,
    output reg wb_is_ertn,
    output reg wb_is_syscall,
    output reg wb_res_from_csr,
    output reg [31:0] wb_csr_wmask,
    output reg [31:0] wb_csr_wdata,
    output reg wb_ex_adef,
    output reg wb_ex_brk,
    output reg wb_ex_ine,
    output reg wb_ex_ale_h,
    output reg wb_ex_ale_w,
    output reg wb_has_int,
    output reg [4:0]wb_rj,
    output reg [31:0]wb_res_of_cnt,
    output reg wb_res_is_rj,
    output reg wb_res_from_cnt,
    output reg wb_ex_ale,
    output reg wb_res_from_tid,
    output reg wb_need_cancel,
    output reg wb_inst_tlbrd,
    output reg wb_inst_tlbsrch,
    output reg wb_tlb_wr_en,
    output reg wb_tlb_we,
    output reg wb_tlb_fill_en,
    output reg [9:0] wb_invtlb_asid,
    output reg [4:0] wb_invtlb_op,
    output reg [18:0] wb_invtlb_va,
    output reg wb_invtlb_valid,
    output reg wb_tlb_or_csr_we,
    output reg [1:0] wb_inst_tlb_ex,
    output reg [2:0] wb_data_tlb_ex,
    output reg wb_icache_v_we,          // ICache valid ˧ ???
    output reg wb_dcache_v_we,          // DCache valid ˧ ???
    output reg wb_dcache_tag_we,        // DCache tag ˧ ???
    output reg wb_icache_tag_we,        // ICache tag ˧ ???
    output reg [31:0] wb_cacop_va,      // Cache??????????
    output reg wb_cacop_need_phy,       // ?????????????
    output reg wb_cacop_en,             // Cache???????
    output reg wb_inst_cacop,           // Cache?????????
    output reg wb_data_cacop ,           // Cache??????????    
    output reg [31:0] wb_inst,
    output reg wb_inst_cnt,
    output reg [63:0] wb_timer_64,
    output reg [7:0]wb_inst_ld_en,
    output reg [7:0]wb_inst_st_en,
    output reg wb_csr_rstat_en,
    output reg [31:0] wb_csr_data,
    output reg [31:0] wb_data_phy_addr,
    output reg wb_inst_cpucfg,
    output reg [31:0] wb_cpucfg_result
);

always @(posedge clk ) begin
    if (rst||wb_ex==1'b1||wb_is_ertn==1'b1) begin
        wb_rf_we <= 1'b0;
        wb_alu_result <= 32'd0;
        wb_rd <= 5'd0;
        wb_br_taken <= 1'b0;
        wb_br_target <= 32'd0;
        wb_dram_rdata <= 32'd0;
        wb_res_from_dram <= 1'b0;
        wb_dram_waddr <= 32'd0;
        wb_dram_wdata <= 32'd0;
        wb_dram_we <= 1'b0;
        wb_pc<=32'b0;
        wb_rdram_num<=2'b0;
        wb_rdram_need_signed_extend<=1'b0;
        wb_rdram_need_zero_extend<=1'b0;
        wb_data_addr<=32'b0;
        wb_csr_num<=14'b0;
        wb_csr_we<=1'b0;
        wb_is_ertn<=1'b0;
        wb_is_syscall<=1'b0;
        wb_res_from_csr<=1'b0;
        wb_csr_wmask<=32'b0;
        wb_csr_wdata<=32'b0;
        wb_ex_adef<=1'b0;
        wb_ex_ale_h<=1'b0;
        wb_ex_ale_w<=1'b0;
        wb_ex_brk<=1'b0;
        wb_ex_ine<=1'b0;
        wb_has_int<=1'b0;
        wb_rj<=5'b0;
        wb_res_of_cnt<=32'b0;
        wb_res_is_rj<=1'b0;
        wb_res_from_cnt<=1'b0;
        wb_ex_ale<=1'b0;
        wb_res_from_tid<=1'b0;
        wb_need_cancel <= 1'b0;
        wb_inst_tlbrd <= 1'b0; 
        wb_inst_tlbsrch <= 1'b0;
        wb_tlb_wr_en <= 1'b0;
        wb_tlb_we <= 1'b0;
        wb_tlb_fill_en <= 1'b0;
        wb_invtlb_asid <= 10'b0;
        wb_invtlb_op <= 5'b0;
        wb_invtlb_va <= 19'b0;
        wb_invtlb_valid <= 1'b0;
        wb_tlb_or_csr_we <= 1'b0;
        wb_inst_tlb_ex <= 2'b0;
        wb_data_tlb_ex <= 3'b0;   
        wb_icache_v_we <= 1'b0;
        wb_dcache_v_we <= 1'b0;
        wb_dcache_tag_we <= 1'b0;
        wb_icache_tag_we <= 1'b0;
        wb_cacop_va <= 32'b0;
        wb_cacop_need_phy <= 1'b0;
        wb_cacop_en <= 1'b0;
        wb_inst_cacop <= 1'b0;
        wb_data_cacop <= 1'b0; 
        wb_inst <= 32'b0;
        wb_inst_cnt <= 1'b0;
        wb_timer_64 <= 64'b0;
        wb_inst_ld_en <= 8'b0;
        wb_inst_st_en <= 8'b0;
        wb_csr_rstat_en <= 1'b0;
        wb_csr_data <= 32'b0;
        wb_data_phy_addr <= 32'b0;
        wb_inst_cpucfg <= 1'b0 ;
        wb_cpucfg_result <= 32'b0 ;
        //wb_csr_rdata<=32'b0;
    end else if(!(mem_ready_go==1'b0))begin
        wb_rf_we <= mem_ref_we;
        wb_alu_result <= mem_alu_result;
        wb_rd <= mem_rd;
        wb_br_taken <= mem_br_taken;
        wb_br_target <= mem_br_target;
        wb_dram_rdata <= mem_dram_rdata;
        wb_res_from_dram <= mem_res_from_dram;
        wb_dram_waddr <= mem_dram_waddr;
        wb_dram_wdata <= mem_dram_wdata;
        wb_dram_we <= mem_dram_we;
        wb_pc<=mem_pc;
        wb_rdram_num<=mem_rdram_num;
        wb_rdram_need_signed_extend<=mem_rdram_need_signed_extend;
        wb_rdram_need_zero_extend<=mem_rdram_need_zero_extend;
        wb_data_addr<=mem_data_addr;
        wb_csr_num<=mem_csr_num;
        wb_csr_we<=mem_csr_we;
        wb_is_ertn<=mem_is_ertn;
        wb_is_syscall<=mem_is_syscall;
        wb_res_from_csr<=mem_res_from_csr;
        wb_csr_wmask<=mem_csr_wmask;
        wb_csr_wdata<=mem_csr_wdata;
        wb_ex_adef<=mem_ex_adef;
        wb_ex_ale_h<=mem_ex_ale_h;
        wb_ex_ale_w<=mem_ex_ale_w;
        wb_ex_brk<=mem_ex_brk;
        wb_ex_ine<=mem_ex_ine;
        wb_has_int<=mem_has_int;
        wb_rj<=mem_rj;
        wb_res_of_cnt<=mem_res_of_cnt;
        wb_res_is_rj<=mem_res_is_rj;
        wb_res_from_cnt<=mem_res_from_cnt;
        wb_ex_ale<=mem_ex_ale;
        wb_res_from_tid<=mem_res_from_tid;
        wb_need_cancel <= mem_need_cancel;
        wb_need_cancel <= mem_need_cancel;
        wb_inst_tlbrd <= mem_inst_tlbrd; 
        wb_inst_tlbsrch <= mem_inst_tlbsrch;
        wb_tlb_wr_en <= mem_tlb_wr_en;
        wb_tlb_we <= mem_tlb_we;
        wb_tlb_fill_en <= mem_tlb_fill_en;
        wb_invtlb_asid <= mem_invtlb_asid;
        wb_invtlb_op <= mem_invtlb_op;
        wb_invtlb_va <= mem_invtlb_va;
        wb_invtlb_valid <= mem_invtlb_valid;
        wb_tlb_or_csr_we <= mem_tlb_or_csr_we;
        wb_inst_tlb_ex <= mem_inst_tlb_ex;
        wb_data_tlb_ex <= mem_data_tlb_ex;
        wb_icache_v_we <= mem_icache_v_we;
        wb_dcache_v_we <= mem_dcache_v_we;
        wb_dcache_tag_we <= mem_dcache_tag_we;
        wb_icache_tag_we <= mem_icache_tag_we;
        wb_cacop_va <= mem_cacop_va;
        wb_cacop_need_phy <= mem_cacop_need_phy;
        wb_cacop_en <= mem_cacop_en;
        wb_inst_cacop <= mem_inst_cacop;
        wb_data_cacop <= mem_data_cacop;        
        wb_inst <= mem_inst;
        wb_inst_cnt <= mem_inst_cnt;
        wb_timer_64 <= mem_timer_64;
        wb_inst_ld_en <= mem_inst_ld_en;
        wb_inst_st_en <= mem_inst_st_en;
        wb_csr_rstat_en <= mem_csr_rstat_en;
        wb_csr_data <= mem_csr_data;
        wb_data_phy_addr <= mem_data_phy_addr;
         wb_inst_cpucfg <= mem_inst_cpucfg ;
        wb_cpucfg_result <= mem_cpucfg_result ;
        //wb_csr_rdata<=mem_csr_rdata;
    end
    else
    begin
         wb_rf_we <= 1'b0;
        wb_alu_result <= 32'd0;
        wb_rd <= 5'd0;
        wb_br_taken <= 1'b0;
        wb_br_target <= 32'd0;
        wb_dram_rdata <= 32'd0;
        wb_res_from_dram <= 1'b0;
        wb_dram_waddr <= 32'd0;
        wb_dram_wdata <= 32'd0;
        wb_dram_we <= 1'b0;
        wb_pc<=32'b0;
        wb_rdram_num<=2'b0;
        wb_rdram_need_signed_extend<=1'b0;
        wb_rdram_need_zero_extend<=1'b0;
        wb_data_addr<=32'b0;
        wb_csr_num<=14'b0;
        wb_csr_we<=1'b0;
        wb_is_ertn<=1'b0;
        wb_is_syscall<=1'b0;
        wb_res_from_csr<=1'b0;
        wb_csr_wmask<=32'b0;
        wb_csr_wdata<=32'b0;
        wb_ex_adef<=1'b0;
        wb_ex_ale_h<=1'b0;
        wb_ex_ale_w<=1'b0;
        wb_ex_brk<=1'b0;
        wb_ex_ine<=1'b0;
        wb_has_int<=1'b0;
        wb_rj<=5'b0;
        wb_res_of_cnt<=32'b0;
        wb_res_is_rj<=1'b0;
        wb_res_from_cnt<=1'b0;
        wb_ex_ale<=1'b0;
        wb_res_from_tid<=1'b0;
        wb_need_cancel <= 1'b0;
        wb_inst_tlbrd <= 1'b0; 
        wb_inst_tlbsrch <= 1'b0;
        wb_tlb_wr_en <= 1'b0;
        wb_tlb_we <= 1'b0;
        wb_tlb_fill_en <= 1'b0;
        wb_invtlb_asid <= 10'b0;
        wb_invtlb_op <= 5'b0;
        wb_invtlb_va <= 19'b0;
        wb_invtlb_valid <= 1'b0;
        wb_tlb_or_csr_we <= 1'b0;
        wb_inst_tlb_ex <= 2'b0;
        wb_data_tlb_ex <= 3'b0;
        wb_icache_v_we <= 1'b0;
        wb_dcache_v_we <= 1'b0;
        wb_dcache_tag_we <= 1'b0;
        wb_icache_tag_we <= 1'b0;
        wb_cacop_va <= 32'b0;
        wb_cacop_need_phy <= 1'b0;
        wb_cacop_en <= 1'b0;
        wb_inst_cacop <= 1'b0;
        wb_data_cacop <= 1'b0;
        wb_inst <= 32'b0 ;
        wb_inst_cnt <= 1'b0;
        wb_timer_64 <= 64'b0;
        wb_inst_ld_en <= 8'b0;
        wb_inst_st_en <= 8'b0;
        wb_csr_rstat_en <= 1'b0;
        wb_csr_data <= 32'b0;
        wb_data_phy_addr <= 32'b0;
         wb_inst_cpucfg <= 1'b0 ;
        wb_cpucfg_result <= 32'b0 ;
        //wb_csr_rdata<=wb_csr_rdata;
    end
end

endmodule
