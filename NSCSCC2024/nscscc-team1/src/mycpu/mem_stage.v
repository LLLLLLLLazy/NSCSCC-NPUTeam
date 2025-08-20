`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //stall
    output                         ms_stall      ,
    //from pms
    input                           pms_to_ms_valid,
    input  [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    input                          data_sram_data_ok,
    //前递相关
    output [ 4                 :0] MEM_dest       ,
    output [31                 :0] ms_result      ,
    output                         ms_load_op     ,
    output                         ms_rdcnt_op    ,
    output                         ms_csr_op      ,
    output                         ms_gtlb_we     ,
    output                         ms_valid_p     ,
    // from addr trans for difftest
    input  [ 7:0]     data_index_diff   ,
    input  [19:0]     data_tag_diff     ,
    input  [ 3:0]     data_offset_diff  ,
    //csr
    input                          wb_ex          ,
    input                          wb_ertn_op     ,
    output                         ms_ex          ,
    output                         ms_ertn        ,
    //tlb
    output                         ms_tlb_flush   ,
    input                          wb_tlb_flush   ,
    output [31                 :0] mem_pc         
);


//----------信号定义----------
//流水线相关信号
reg         ms_valid;
wire        ms_ready_go;
wire [31:0] ms_to_ws_result;
reg [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus_r;

//操作数相关
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [31:0] ms_inst;
wire [31:0] ms_rj_value;
wire [31:0] ms_rkd_value;

//前递相关
wire [ 4:0] ms_dest;
wire [31:0] mem_result;

//exception相关
wire [ 5:0] ms_ecode;
wire        pms_to_ms_ex;
wire        ms_ertn_op;
wire [31:0] ms_ex_addr;
wire        ms_idle_op;
wire        ms_tlbfill;
wire        pms_to_ms_tlb_srch;
wire        pms_to_ms_tlb_found;
wire [ 3:0] pms_to_ms_tlb_index;
//内存操作相关
wire          ms_res_from_mem;
wire   [ 3:0] ms_mem_bm_load;
wire   [ 3:0] ms_re_1_0_d;
wire   [31:0] mem_result_w;
wire   [15:0] mem_result_h;
wire   [ 7:0] mem_result_b;

wire          ms_store_op;

reg           data_ok_r;

//寄存器相关
wire        pms_to_ms_gr_we;
wire        ms_gr_we;

//csr相关
wire        ms_res_from_csr;
wire        pms_to_ms_gcsr_we;
wire        ms_gcsr_we;
wire [13:0] ms_csr_num;

//tlb相关
wire        pms_to_ms_gtlb_we;
wire        pms_to_ms_gtlb_rd;
wire        ms_gtlb_rd;
wire        pms_to_ms_tlb_flush;

//计数器相关
wire [ 2:0] ms_rd_cnt_op;

//----------信号赋值----------
//流水线控制相关
wire ms_not_mem = !(ms_load_op || ms_store_op);
wire ms_mem_data_ok = ((ms_load_op || ms_store_op) && (data_sram_data_ok || data_ok_r));
assign ms_stall = !ms_ready_go && ms_valid;
assign ms_ready_go    =  ms_not_mem ||
                         ms_mem_data_ok ||
                         ms_ex || wb_ertn_op || wb_ex || wb_tlb_flush;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go && !(wb_tlb_flush || wb_ex || wb_ertn_op);
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (wb_ex || wb_ertn_op || wb_tlb_flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= pms_to_ms_valid;
    end

    if (ms_allowin) begin
        pms_to_ms_bus_r  <= pms_to_ms_bus;
    end
end
assign ms_valid_p = ms_valid;

wire [7:0]  inst_ld_en;
wire [7:0]  inst_st_en;
wire        inst_csr_rstat_en;
wire ms_inst_ll_w;
wire ms_inst_sc_w;
wire [31:0] ms_ld_paddr;
wire [31:0] ms_ld_vaddr;
wire [31:0] ms_st_data;

//接收总线信息
assign {ms_idle_op,
        pms_to_ms_tlb_index,
        pms_to_ms_tlb_found,
        pms_to_ms_tlb_srch,
        ms_tlbfill,
        ms_ld_paddr,
        ms_ld_vaddr,
        ms_st_data,
        ms_inst_ll_w,
        ms_inst_sc_w,
        inst_csr_rstat_en,
        inst_ld_en,
        inst_st_en,
        ms_inst,
        pms_to_ms_tlb_flush,
        pms_to_ms_gtlb_rd,
        pms_to_ms_gtlb_we,
        ms_load_op     ,
        ms_store_op    ,
        ms_rd_cnt_op   ,
        ms_ex_addr     ,
        ms_ertn_op        ,
        ms_ecode       ,
        ms_csr_op      ,
        pms_to_ms_ex    ,
        ms_rj_value    ,
        ms_rkd_value   ,
        ms_csr_num     ,
        pms_to_ms_gcsr_we,
        ms_res_from_csr,
        ms_re_1_0_d    ,
        ms_mem_bm_load ,
        ms_res_from_mem,  //70:70
        pms_to_ms_gr_we ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = pms_to_ms_bus_r;
//前递相关赋值
assign ms_result = ms_alu_result;
assign ms_to_ws_result = ms_res_from_mem ? mem_result : ms_alu_result;
assign MEM_dest = ms_dest & {5{ms_valid}};
assign ms_rdcnt_op = (ms_rd_cnt_op != 3'b0);
assign ms_ertn = ms_ertn_op && ms_valid;
//寄存器相关赋值
assign ms_gr_we = pms_to_ms_gr_we & ~wb_ex & ~wb_ertn_op & ~wb_tlb_flush;

//csr相关赋值
assign ms_gcsr_we = pms_to_ms_gcsr_we & ~wb_ex & ~wb_ertn_op & ~wb_tlb_flush;
assign ms_ertn = ms_ertn_op && ms_valid;

//tlb相关赋值
assign ms_gtlb_we = pms_to_ms_gtlb_we & ~wb_ex & ~wb_ertn_op & ~wb_tlb_flush;
assign ms_gtlb_rd = pms_to_ms_gtlb_rd & ~wb_ex & ~wb_ertn_op & ~wb_tlb_flush;
assign ms_tlb_flush = pms_to_ms_tlb_flush & ~wb_ex & ~wb_ertn_op & ~wb_tlb_flush;
assign mem_pc = ms_pc + 32'h4;

//exception相关赋值
assign ms_ex = pms_to_ms_ex & ~wb_ex & ~wb_ertn_op & ~wb_tlb_flush;

//内存操作相关赋值
assign mem_result_w = data_sram_rdata;
assign mem_result_h = ms_re_1_0_d[0] ? data_sram_rdata[15: 0] : 
                      ms_re_1_0_d[1] ? data_sram_rdata[23: 8] :
                      ms_re_1_0_d[2] ? data_sram_rdata[31:16] : 
                      16'b0;
assign mem_result_b = ms_re_1_0_d[0] ? data_sram_rdata[ 7: 0] : 
                      ms_re_1_0_d[1] ? data_sram_rdata[15: 8] :
                      ms_re_1_0_d[2] ? data_sram_rdata[23:16] :
                      ms_re_1_0_d[3] ? data_sram_rdata[31:24] : 
                      8'b0;

assign mem_result = (ms_mem_bm_load[0] && ms_mem_bm_load[3])  ? {{24{mem_result_b[7]}},mem_result_b} :
                    (ms_mem_bm_load[0] && ~ms_mem_bm_load[3]) ? {{24{1'b0}},mem_result_b}            :
                    (ms_mem_bm_load[1] && ms_mem_bm_load[3])  ? {{16{mem_result_h[15]}},mem_result_h}:
                    (ms_mem_bm_load[1] && ~ms_mem_bm_load[3]) ? {{16{1'b0}},mem_result_h}            :
                    ms_mem_bm_load[2]                         ? mem_result_w                         :
                                        32'b0                                                        ;

always @(posedge clk) begin
    if (reset) begin
        data_ok_r <= 1'b0;
    end
    else if (ms_ready_go && ws_allowin) begin
        data_ok_r <= 1'b0;
    end
    else if (data_sram_data_ok) begin
        data_ok_r <= 1'b1;
    end

end

//MS_TO_WS_BUSF赋值
assign ms_to_ws_bus={   ms_idle_op,
                        pms_to_ms_tlb_index,
                        pms_to_ms_tlb_found,
                        pms_to_ms_tlb_srch,
                        ms_tlbfill,
                        ms_ld_vaddr,
                        ms_ld_paddr,
                        ms_st_data,
                        ms_inst_ll_w,
                        ms_inst_sc_w,
                        inst_csr_rstat_en,
                        inst_ld_en,
                        inst_st_en,
                        ms_inst         ,
                        ms_tlb_flush    ,
                        ms_gtlb_rd      ,
                        ms_gtlb_we      ,
                        ms_rd_cnt_op    ,
                        ms_ex_addr      ,
                        ms_ertn_op         ,
                        ms_ecode        ,
                        ms_ex           ,
                        ms_rkd_value    ,
                        ms_rj_value     ,
                        ms_csr_num      ,
                        ms_gcsr_we      ,
                        ms_res_from_csr ,
                        ms_gr_we        ,  //69:69
                        ms_dest         ,  //68:64
                        ms_to_ws_result ,  //63:32
                        ms_pc              //31:0
                    };
reg  [ 7:0] tmp_data_index  ;
reg  [ 3:0] tmp_data_offset ;
always @(posedge clk) begin
    tmp_data_index  <= data_index_diff;
    tmp_data_offset <= data_offset_diff;
end

endmodule
