`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output        debug_ws_valid,
    input         debug_break_point,
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_we ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output [31:0] debug_wb_inst,
    //前递相关
    output [ 4:0] WB_dest,
    output [31:0] ws_result,
    output        ws_gtlb_we,
    output        ws_valid_p,
    //csr相关
    output [13:0] csr_raddr1,
    inout  [31:0] csr_rdata1,
    output        csr_we,
    output [13:0] csr_waddr,
    output [31:0] csr_wdata,
    output [31:0] csr_wmask,
    output [31:0] wb_pc,
    output [31:0] ws_addr,
    output [ 5:0] ws_ecode,
    output [ 8:0] subecode,
    input  [63:0] counter_value,
    output        ws_llbit,
    output        ws_llbit_set,
    output        ws_tlb_search,
    output        ws_tlb_s_found,
    output [ 2:0] ws_tlb_s_index,
    //exception
    output reg    wb_ex,
    output reg    wb_ertn,
    input         ms_ertn,
    input         ms_ex,
    //计数器相关
    input  [31:0] timer_id,
    //tlb相关
    output        tlb_we,
    output        tlb_rd,
    input         ms_tlb_flush,
    output wire   wb_tlb_flush,
    output wire   tlbfill_en,
    //idle相关
    output wire   wb_idle_op,

    // difftest
    output        ws_valid_diff                    ,
    output        ws_cnt_inst_diff                 ,
    output [63:0] ws_timer_64_diff                 ,
    output [ 7:0] ws_inst_ld_en_diff               ,
    output [31:0] ws_ld_paddr_diff                 ,
    output [31:0] ws_ld_vaddr_diff                 ,
    output [ 7:0] ws_inst_st_en_diff               ,
    output [31:0] ws_st_paddr_diff                 ,
    output [31:0] ws_st_vaddr_diff                 ,
    output [31:0] ws_st_data_diff                  ,
    output        ws_csr_rstat_en_diff             ,
    output [31:0] ws_csr_data_diff   
);

//----------信号定义----------
//流水线相关信号
reg         ws_valid;
reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_ready_go;
wire [31:0] ws_pc;
wire [31:0] ws_inst;
wire [7:0]  inst_ld_en;
wire [7:0]  inst_st_en;
wire        inst_csr_rstat_en;
wire ws_inst_ll_w;
wire ws_inst_sc_w;
wire [31:0] ws_st_data;
wire [31:0] ws_ld_paddr;
wire [31:0] ws_ld_vaddr;
//寄存器相关
wire        ws_gr_we;
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
wire [31:0] ws_result_from_ms; //从mem中传入的写回结果

//csr相关
wire        ws_gcsr_we;
wire [13:0] ws_csr_num;
wire        ws_res_from_csr;
wire [31:0] ws_rkd_value;
wire [31:0] ws_rj_value;

//tlb相关
wire        ws_gtlb_rd;
wire        ms_to_ws_tlb_flush;
wire        ms_to_ws_tlb_srch;
wire        ms_to_ws_tlb_found;
wire [ 3:0] ms_to_ws_tlb_index;
wire        ws_tlbfill;
reg         wb_tlb_flush_r;
assign      tlbfill_en = ws_tlbfill & ws_valid;

//idle相关
wire        ws_idle_op;
//exception相关
wire        ws_ertn;
wire        ws_ex;
wire [31:0] ws_ex_addr;
 
//前递相关
wire [ 4:0] ws_dest;

//计数器相关
wire [ 2:0] ws_rd_cnt_op;

//----------信号赋值----------
//接收来自ms的总线信息
assign {ws_idle_op,
        ms_to_ws_tlb_index,
        ms_to_ws_tlb_found,
        ms_to_ws_tlb_srch,
        ws_tlbfill,
        ws_ld_vaddr, 
        ws_ld_paddr,
        ws_st_data,
        ws_inst_ll_w,
        ws_inst_sc_w,
        inst_csr_rstat_en,
        inst_ld_en,
        inst_st_en,
        ws_inst,
        ms_to_ws_tlb_flush,
        ws_gtlb_rd     ,
        ws_gtlb_we     ,
        ws_rd_cnt_op   ,
        ws_ex_addr     ,
        ws_ertn        ,
        ws_ecode       ,
        ws_ex          ,
        ws_rkd_value   ,    
        ws_rj_value    ,
        ws_csr_num     ,
        ws_gcsr_we     ,
        ws_res_from_csr,
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_result_from_ms,//63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

//流水线控制信号赋值
assign ws_ready_go = !debug_break_point;
assign ws_allowin  = !ws_valid || ws_ready_go;
//assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end
assign ws_valid_p = ws_valid;
//写回相关赋值
assign ws_result = ws_res_from_csr ? csr_rdata1 :
                   ws_rd_cnt_op[2] ? timer_id   :
                   ws_rd_cnt_op[1] ? counter_value[63:32]   :
                   ws_rd_cnt_op[0] ? counter_value[31: 0]   :
                              ws_result_from_ms ;
assign rf_we    = ws_gr_we && ws_valid && ~ws_ex;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_result;

assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

// debug info generate
assign debug_ws_valid    = ws_valid;
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;
assign debug_wb_inst     = ws_inst;

assign WB_dest = ws_dest & {5{ws_valid}};

//csr相关赋值
assign csr_raddr1 = ws_csr_num;
assign csr_we     = ws_gcsr_we & ~ws_ex & ~ws_ertn & ws_valid;
assign csr_waddr  = ws_csr_num;
assign csr_wdata  = ws_rkd_value;
assign csr_wmask  = ws_rj_value;
assign wb_pc      = ws_pc;
assign ws_addr    = (ws_ecode == 6'h9 || ws_ecode == 6'h3f || ws_ecode == 6'h01 || ws_ecode == 6'h02 || ws_ecode == 6'h03 || ws_ecode == 6'h04 || ws_ecode == 6'h07) ? ws_ex_addr : ws_pc;
assign subecode   = 9'b0;
//tlb相关赋值
assign tlb_we = ws_gtlb_we & ws_valid & ~ws_ex & ~ws_ertn;
assign tlb_rd = ws_gtlb_rd & ws_valid & ~ws_ex & ~ws_ertn;

always @(posedge clk)begin
    if(reset)begin
        wb_tlb_flush_r <= 1'b0;
    end
    else if(ms_tlb_flush && ms_to_ws_valid && !ms_ex)begin
        wb_tlb_flush_r <= 1'b1;
    end
    else begin
        wb_tlb_flush_r <= 1'b0;
    end
end

assign wb_tlb_flush = wb_tlb_flush_r || csr_we || ((ws_idle_op || ws_inst_ll_w) && ws_valid);
assign ws_tlb_search = ms_to_ws_tlb_srch & ws_valid & ~ws_ex & ~ws_ertn;
assign ws_tlb_s_found = ms_to_ws_tlb_found;
assign ws_tlb_s_index = ms_to_ws_tlb_index;

//exception相关赋值
always @(posedge clk)begin
    if(reset) begin
        wb_ex <= 1'b0;
    end
    else if(ms_ex && ms_to_ws_valid) begin
        wb_ex <= 1'b1;
    end
    else begin
        wb_ex <= 1'b0;
    end
end

always @(posedge clk)begin
    if(reset) begin
        wb_ertn <= 1'b0;
    end
    else if(ms_ertn && ms_to_ws_valid && !ms_ex) begin
        wb_ertn <= 1'b1;
    end
    else begin
        wb_ertn <= 1'b0;
    end
end
//idle相关赋值
assign      wb_idle_op = ws_idle_op && ws_valid;

//llbit
assign ws_llbit_set = (ws_inst_ll_w | ws_inst_sc_w) & ws_valid & !ws_ex; 
assign ws_llbit     = (ws_inst_ll_w & 1'b1) | (ws_inst_sc_w & 1'b0);

assign ws_valid_diff        = ws_valid & ~ws_ex ;
assign ws_timer_64_diff     = counter_value     ;
assign ws_cnt_inst_diff     = (ws_rd_cnt_op!=3'b0);

assign ws_inst_ld_en_diff   = inst_ld_en     ;
assign ws_ld_paddr_diff     = ws_ld_paddr       ;
assign ws_ld_vaddr_diff     = ws_ld_vaddr       ;

assign ws_inst_st_en_diff   = inst_st_en     ;
assign ws_st_paddr_diff     = ws_ld_paddr_diff  ;
assign ws_st_vaddr_diff     = ws_ld_vaddr_diff  ;
assign ws_st_data_diff      = ws_st_data        ;

assign ws_csr_rstat_en_diff = inst_csr_rstat_en ;
assign ws_csr_data_diff     = csr_rdata1        ; 

endmodule
