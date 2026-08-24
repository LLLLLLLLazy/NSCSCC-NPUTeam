`include "mycpu.h"

module exe_stage(
    input       wire                     clk           ,
    input       wire                     reset         ,
    //allowin
    output      wire                     es_allowin    ,
    //from alu issue
    input       wire                     issue_valid  ,
    input       wire       [3:0]         issue_rob_id ,
    input       wire [`DE_TO_DS_BUS-1:0] issue_payload,                         
    input       wire       [31:0]        operand1     ,//from regfile
    input       wire       [31:0]        operand2     ,
    input       wire       [5:0]         issue_preg_rd,
    
    output      wire                    es_ready_go,
    output      wire        [3:0]        rob_id     ,
    output      wire                     es_gr_we      ,
    output      wire      [5:0]          es_preg_rd    ,
    output      wire    [31:0]           es_result     ,
    output      wire                     br_mispred       ,
    output      wire    [ 31:0]          br_target      ,
    
    //to issue 发射队列前�?�判�?
//    output      wire                     gr_we_i      ,
//    output      wire      [5:0]          preg_rd_i    ,
    //冲刷信号
    input                          es_reflush,
    //分支更新接口
    output wire exec_update_en,  //分支更新有效
    output wire [31:0] pc_exec, //es_pc
    output wire [31:0] target_exec,//real_target
    output wire [1:0] branch_type_exec ,//br/j/jirl
    output wire es_br,
    output wire br_taken
    
);

reg         es_valid      ;
reg  [`DE_TO_DS_BUS -1:0] is_to_es_bus_r;

//==================== 修复：删除重复定�? inst_is_mem_priv、inst_tlbsrch ====================
wire         inst_is_mem_priv;  // 1 bit
wire [29:0]  alu_op;            // 28 bits
wire         need_rj;           // 1 bit
wire         need_rk;           // 1 bit
wire         need_rd;           // 1 bit
wire         need_pc;           // 1 bit
wire         need_imm;          // 1 bit
wire [ 4:0]  ldst;              // 5 bits
wire [ 4:0]  lrs1;              // 5 bits
wire [ 4:0]  lrs2;              // 5 bits
wire [ 2:0]  load_op;           // 3 bits
wire [ 1:0]  store_op;          // 2 bits
wire         rf_we;             // 1 bit
wire         mem_we;            // 1 bit
wire [31:0]  imm;               // 32 bits
wire [31:0]  es_pc;             // 32 bits
wire         res_from_mem;      // 1 bit
wire [129:0] ds_exception;      // 130 bits
wire [ 1:0]  time_op;           // 2 bits
wire [ 1:0]  iq_type;           // 2 bits
wire ds0_is_store;
wire                  rename_is_complex_0;
wire es_inst_pcaddu12i;
wire inst_csrxchg;
wire pred_taken;
wire [31:0] pred_target;
wire inst_cpucfg;
wire inst_valid_cacop;
wire [4:0] dest;
wire inst_tlbsrch;
wire inst_tlbrd;
wire inst_tlbwr;
wire inst_tlbfill;
wire inst_invtlb;
wire [4:0] invtlb_op;

assign               {
                        branch_type_exec,        //2
                        inst_cpucfg,     //1
                        inst_valid_cacop, //1
                        dest,          //5
                        inst_tlbsrch,    //1
                        inst_tlbrd,     //1
                        inst_tlbwr,     //1
                        inst_tlbfill,   //1
                        inst_invtlb,    //1
                        invtlb_op,      //5
                      pred_taken,
                       pred_target,
                        inst_csrxchg,//mem相关
                       es_inst_pcaddu12i,
                      ds0_is_store,
                      rename_is_complex_0,
                      inst_is_mem_priv,
                       alu_op       ,   // 28
                       need_rj      ,   //1
                       need_rk      ,//1
                       need_rd      , //1
                       need_pc      , //1
                       need_imm     ,//1
                       ldst         ,//5
                       lrs1         ,//5
                       lrs2         ,//5
                       load_op      ,   // 3
                       store_op     ,  //2
                       rf_we        ,   // 1 
                       mem_we       ,   // 1
                       imm          ,   // 32
                       es_pc           ,    // 32
                       res_from_mem ,//1
                       ds_exception ,//130
                       time_op      ,//2
                       iq_type//2
                    }  = is_to_es_bus_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] alu_res    ;

reg      [ 3:0]        es_rob_id;
reg      [31:0]        es_operand1     ;//from regfile
reg      [31:0]        es_operand2     ;
reg      [5:0]         es_issue_preg_rd;

assign  rob_id = es_rob_id;

assign es_allowin     = !es_valid || es_ready_go;

always @(posedge clk) begin
    if (reset || es_reflush) begin
        es_valid <= 1'b0;
        is_to_es_bus_r <= {`DE_TO_DS_BUS{1'b0}};
        es_rob_id <= 4'd0;
        es_operand1 <= 32'd0;
        es_operand2 <= 32'd0;
        es_issue_preg_rd <= 6'd0;
    end
    else if (es_allowin) begin
        es_valid <= issue_valid;
    end

    if (issue_valid && es_allowin && !es_reflush) begin
        is_to_es_bus_r <= issue_payload;
        es_rob_id <= issue_rob_id;
        es_operand1 <= operand1;
        es_operand2 <= operand2;
        es_issue_preg_rd <= issue_preg_rd;
    end
end

assign alu_src1 = es_operand1;
assign alu_src2 = need_rd & !alu_op[0] ? es_operand2:
                  need_imm ? imm : es_operand2;
                  
wire mul_done;
reg  mul_done_r;
wire mul_start = (alu_op[12] || alu_op[13] || alu_op[14]) && es_valid && !mul_done && !mul_done_r;
wire inst_is_mul = (alu_op[12] || alu_op[13] || alu_op[14]) && es_valid;
wire es_mul_ok      = ((mul_done || mul_done_r) && inst_is_mul);
wire        stall         ;
assign stall = !es_ready_go && es_valid;
always @ (posedge clk) begin
    if(reset) begin
        mul_done_r <= 1'b0;
    end
    else if (!stall) begin
        mul_done_r <= 1'b0;
    end
    else if(mul_done) begin
        mul_done_r <= 1'b1;
    end 
end
alu u_alu(
    .clk(clk),
    .reset(reset),
    .wb_tlb_flush(es_reflush),
    .mul_start  (mul_start),
    .mul_done   (mul_done),
    .inst_pcaddu12i (es_inst_pcaddu12i),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .es_pc      (es_pc),
    .imm        (imm),
    .alu_result (alu_res),
    .es_br      (es_br),
    .br_mispred   (br_mispred),
    .final_target  (br_target),
    .pred_taken (pred_taken),
    .pred_target (pred_target),
    .exec_update_en (exec_update_en),
    .pc_exec        (pc_exec),
    .target_exec    (target_exec),
    .br_taken       (br_taken)
);

wire [31:0] div_result;
wire        inst_is_div;
wire        div_start;
wire        div_signed;
wire        div_complete;
wire [31:0] divisor_tdata;
wire [31:0] dividend_tdata;
wire [31:0] s_result;
wire [31:0] r_result;

assign inst_is_div = (alu_op[15] | alu_op[16] | alu_op[17] | alu_op[18]) & es_valid;
assign divisor_tdata   = alu_src2;
assign dividend_tdata  = alu_src1;

assign div_signed = alu_op[15] | alu_op[16];
assign div_start  = inst_is_div & ~div_complete;
wire div_resetn = reset | es_reflush;

div u_div(
    .div_clk    (clk),
    .reset      (div_resetn),
    .div        (div_start),
    .div_signed (div_signed),
    .x          (dividend_tdata),
    .y          (divisor_tdata),
    .s          (s_result),
    .r          (r_result),
    .complete   (div_complete)
);

assign div_result =  alu_op[15] | alu_op[17] ? s_result : r_result;

assign es_ready_go    = es_reflush?  1'b1:
                        inst_is_div ? div_complete : 
                        inst_is_mul ? es_mul_ok : es_valid;

assign alu_result = inst_is_div ? div_result : alu_res;

assign es_gr_we = rf_we & es_valid & es_ready_go & !es_reflush;
assign es_result = alu_result & {32 {es_valid}};
assign es_preg_rd = es_issue_preg_rd & {6{es_valid}};
/*
wire         inst_is_mem_priv_i;
wire [29:0]  alu_op_i;
wire         need_rj_i;
wire         need_rk_i;
wire         need_rd_i;
wire         need_pc_i;
wire         need_imm_i;
wire [ 4:0]  ldst_i;
wire [ 4:0]  lrs1_i;
wire [ 4:0]  lrs2_i;
wire [ 2:0]  load_op_i;
wire [ 1:0]  store_op_i;
wire         rf_we_i;
wire         mem_we_i;
wire [31:0]  imm_i;
wire [31:0]  es_pc_i;
wire         res_from_mem_i;
wire [129:0] ds_exception_i;
wire [ 1:0]  time_op_i;
wire [ 1:0]  iq_type_i;
wire         ds0_is_store_i;
wire         rename_is_complex_0_i;
wire         es_inst_pcaddu12i_i;
wire         inst_csrxchg_i;

wire  [`DE_TO_DS_BUS -1:0] is_to_es_bus_i;
wire pred_taken_i;
wire [31:0] pred_target_i;
assign is_to_es_bus_i = issue_payload;
assign {pred_taken_i,
        pred_target_i,
        inst_csrxchg_i,
        es_inst_pcaddu12i_i,
        ds0_is_store_i,
        rename_is_complex_0_i,
        inst_is_mem_priv_i,
        alu_op_i,
        need_rj_i,
        need_rk_i,
        need_rd_i,
        need_pc_i,
        need_imm_i,
        ldst_i,
        lrs1_i,
        lrs2_i,
        load_op_i,
        store_op_i,
        rf_we_i,
        mem_we_i,
        imm_i,
        es_pc_i,
        res_from_mem_i,
        ds_exception_i,
        time_op_i,
        iq_type_i
       } = is_to_es_bus_i & {`DE_TO_DS_BUS{issue_valid}};

wire inst_is_div_i = alu_op_i[15] | alu_op_i[16] | alu_op_i[17] | alu_op_i[18];
assign gr_we_i = rf_we_i & !inst_is_div_i;
assign preg_rd_i = issue_preg_rd;
*/
endmodule