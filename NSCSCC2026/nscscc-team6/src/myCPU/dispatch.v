`include "mycpu.h"

module dispatch (
    input  wire        clk,
    input  wire        reset,
    // 1. 来自 Rename 级的数据

    input  wire        rn_valid_0,
    input  wire        rn_is_mem_priv_0, 
    input  wire [ 5:0] rn_preg_rs1_0,
    input  wire [ 5:0] rn_preg_rs2_0,
    input  wire [ 5:0] rn_preg_rd_0,
    input  wire [ 3:0] rn_rob_id_0,
    input  wire [`DE_TO_DS_BUS-1:0] rn_payload_0,
    input  wire        rn_rs1_ready_0,
    input  wire        rn_rs2_ready_0,

    input  wire        rn_valid_1,
    input  wire        rn_is_mem_priv_1, 
    input  wire [ 5:0] rn_preg_rs1_1,
    input  wire [ 5:0] rn_preg_rs2_1,
    input  wire [ 5:0] rn_preg_rd_1,
    input  wire [ 3:0] rn_rob_id_1,
    input  wire [`DE_TO_DS_BUS-1:0] rn_payload_1,
    input  wire        rn_rs1_ready_1,
    input  wire        rn_rs2_ready_1,

    // 反馈给 Rename/ID 级：本周期实际接收了多少条指令 (0, 1, 或 2)
    output wire [ 1:0] dp_accept_cnt,


    // 2. 发往 ALU_0 队列

    output wire        alu0_enq_valid,
    output wire [ 5:0] alu0_enq_preg_rs1,
    output wire [ 5:0] alu0_enq_preg_rs2,
    output wire [ 5:0] alu0_enq_preg_rd,
    output wire [ 3:0] alu0_enq_rob_id,
    output wire [`DE_TO_DS_BUS-1:0] alu0_enq_payload,
    output wire        alu0_enq_rs1_ready,
    output wire        alu0_enq_rs2_ready,
    input  wire        alu0_iq_allowin,  // ALU0队列有无空位


    // 3. 发往 ALU_1 队列

    output wire        alu1_enq_valid,
    output wire [ 5:0] alu1_enq_preg_rs1,
    output wire [ 5:0] alu1_enq_preg_rs2,
    output wire [ 5:0] alu1_enq_preg_rd,
    output wire [ 3:0] alu1_enq_rob_id,
    output wire [`DE_TO_DS_BUS-1:0] alu1_enq_payload,
    output wire        alu1_enq_rs1_ready,
    output wire        alu1_enq_rs2_ready,
    input  wire        alu1_iq_allowin,  // ALU1队列有无空位


    // 4. 发往 MEM/PRIV 队列

    output wire        mem_enq_valid,
    output wire [ 5:0] mem_enq_preg_rs1,
    output wire [ 5:0] mem_enq_preg_rs2,
    output wire [ 5:0] mem_enq_preg_rd,
    output wire [ 3:0] mem_enq_rob_id,
    output wire [`DE_TO_DS_BUS-1:0] mem_enq_payload,
    output wire        mem_enq_rs1_ready,
    output wire        mem_enq_rs2_ready,
    input  wire        mem_iq_allowin   // MEM队列有无空位
  //  input wire         can_accept_0,
  //  input wire         can_accept_1
    
    //output wire rename_ready_go
);
//assign rename_ready_go = alu0_enq_valid | alu1_enq_valid | mem_enq_valid;


reg alu_pref; // 0: 优先 ALU0, 1: 优先 ALU1

always @(posedge clk) begin
    if (reset) begin
        alu_pref <= 1'b0;
    end else begin
        alu_pref <= ~alu_pref; 
    end
end

wire pref_alu0 = ~alu_pref;
wire pref_alu1 =  alu_pref;

    wire inst0_is_alu = rn_valid_0 & ~rn_is_mem_priv_0;
    wire inst0_is_mem = rn_valid_0 &  rn_is_mem_priv_0;
    
    wire inst1_is_alu = rn_valid_1 & ~rn_is_mem_priv_1;
    wire inst1_is_mem = rn_valid_1 &  rn_is_mem_priv_1;

    // 2. 指令 0 路由 (最高优先级)
    // 策略：如果是 ALU 指令，优先去 ALU0；如果 ALU0 满了，再去尝试 ALU1。
wire inst0_to_alu0 = inst0_is_alu & alu0_iq_allowin & (pref_alu0 | ~alu1_iq_allowin);
wire inst0_to_alu1 = inst0_is_alu & alu1_iq_allowin & (pref_alu1 | ~alu0_iq_allowin);
    wire inst0_to_mem_q = inst0_is_mem & mem_iq_allowin;
    
    wire inst0_ok = inst0_to_alu0 | inst0_to_alu1 | inst0_to_mem_q;

    // 3. 指令 1 路由 (必须等指令0走掉)
    // 策略：只能去刚才指令 0 没占用的队列。
    wire alu0_still_avail = alu0_iq_allowin & ~inst0_to_alu0;
    wire alu1_still_avail = alu1_iq_allowin & ~inst0_to_alu1;
    wire mem_still_avail  = mem_iq_allowin  & ~inst0_to_mem_q;

    // 苛刻的前提条件：指令 0 必须成功发走，或者指令 0 根本不存在
    wire can_issue_inst1 = (~rn_valid_0 | inst0_ok);

    wire inst1_to_alu0 = inst1_is_alu & alu0_still_avail & can_issue_inst1;
    wire inst1_to_alu1 = inst1_is_alu & ~inst1_to_alu0 & alu1_still_avail & can_issue_inst1; // 优先补位 ALU0
    wire inst1_to_mem_q = inst1_is_mem & mem_still_avail  & can_issue_inst1;
    
    wire inst1_ok = inst1_to_alu0 | inst1_to_alu1 | inst1_to_mem_q;

    // 4. 反馈给前级的接收数量
    assign dp_accept_cnt = (inst0_ok & inst1_ok) ? 2'd2 :
                           (inst0_ok)            ? 2'd1 : 2'd0;

    // ==========================================
    // 数据多路复用器 (MUX) 组装发往队列的包裹
    // ==========================================
    
    // 发往 ALU 0 的数据组合
    assign alu0_enq_valid     = inst0_to_alu0 | inst1_to_alu0;
    assign alu0_enq_preg_rs1  = inst0_to_alu0 ? rn_preg_rs1_0  : rn_preg_rs1_1;
    assign alu0_enq_preg_rs2  = inst0_to_alu0 ? rn_preg_rs2_0  : rn_preg_rs2_1;
    assign alu0_enq_preg_rd   = inst0_to_alu0 ? rn_preg_rd_0   : rn_preg_rd_1;
    assign alu0_enq_rob_id    = inst0_to_alu0 ? rn_rob_id_0    : rn_rob_id_1;
    assign alu0_enq_payload   = inst0_to_alu0 ? rn_payload_0   : rn_payload_1;
    assign alu0_enq_rs1_ready = inst0_to_alu0 ? rn_rs1_ready_0 : rn_rs1_ready_1;
    assign alu0_enq_rs2_ready = inst0_to_alu0 ? rn_rs2_ready_0 : rn_rs2_ready_1;

    // 发往 ALU 1 的数据组合
    assign alu1_enq_valid     = inst0_to_alu1 | inst1_to_alu1;
    assign alu1_enq_preg_rs1  = inst0_to_alu1 ? rn_preg_rs1_0  : rn_preg_rs1_1;
    assign alu1_enq_preg_rs2  = inst0_to_alu1 ? rn_preg_rs2_0  : rn_preg_rs2_1;
    assign alu1_enq_preg_rd   = inst0_to_alu1 ? rn_preg_rd_0   : rn_preg_rd_1;
    assign alu1_enq_rob_id    = inst0_to_alu1 ? rn_rob_id_0    : rn_rob_id_1;
    assign alu1_enq_payload   = inst0_to_alu1 ? rn_payload_0   : rn_payload_1;
    assign alu1_enq_rs1_ready = inst0_to_alu1 ? rn_rs1_ready_0 : rn_rs1_ready_1;
    assign alu1_enq_rs2_ready = inst0_to_alu1 ? rn_rs2_ready_0 : rn_rs2_ready_1;

    // 发往 MEM/PRIV 的数据组合
    assign mem_enq_valid     = inst0_to_mem_q | inst1_to_mem_q;
    assign mem_enq_preg_rs1  = inst0_to_mem_q ? rn_preg_rs1_0  : rn_preg_rs1_1;
    assign mem_enq_preg_rs2  = inst0_to_mem_q ? rn_preg_rs2_0  : rn_preg_rs2_1;
    assign mem_enq_preg_rd   = inst0_to_mem_q ? rn_preg_rd_0   : rn_preg_rd_1;
    assign mem_enq_rob_id    = inst0_to_mem_q ? rn_rob_id_0    : rn_rob_id_1;
    assign mem_enq_payload   = inst0_to_mem_q ? rn_payload_0   : rn_payload_1;
    assign mem_enq_rs1_ready = inst0_to_mem_q ? rn_rs1_ready_0 : rn_rs1_ready_1;
    assign mem_enq_rs2_ready = inst0_to_mem_q ? rn_rs2_ready_0 : rn_rs2_ready_1;

endmodule