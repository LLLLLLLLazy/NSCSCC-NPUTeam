`include "mycpu.h"

module id_stage(
    input  wire        clk,
    input  wire        reset,


    // 1. 与前�? Fetch Buffer 的衔�? (接收2�?)
    // 说明：Fetch Buffer目前每周期向ID提供�?�?2条有效指�?
    // ID级根据后端的队列空闲情况，决定消�?(pop) 0�?1 �? 2 条指�?

    input  wire [ 1:0] deq_valid,
    input  wire [`FS_TO_DS_BUS_WD -1:0] deq_bus_0,
    input  wire [`FS_TO_DS_BUS_WD -1:0] deq_bus_1,
    output wire [ 1:0] deq_pop_count,  // 告诉 Buffer 我们实际拿走几条


    // 2. 与后�? 发射队列(Issue Queue) 的握�?
    // 说明：由于分成了两个队列，ID级必须知道每个队列目前还有几个空�?

    // ALU 发射队列的空位计�? (至少�?要能表示 0, 1, 2)
  //  input  wire [ 1:0] alu_iq_free_cnt,
    output wire        ds_to_rename_valid_0,
    output wire [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_0,
    output wire        ds_to_rename_valid_1,
    output wire [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_1,

    // MEM (存取) 发射队列的空位计�?
   /* input  wire [ 1:0] mem_iq_free_cnt,
    output wire        ds_to_mem_valid_0,
    output wire [`DE_TO_DS_BUS-1:0] ds_to_mem_bus_0,
    output wire        ds_to_mem_valid_1,
    output wire [`DE_TO_DS_BUS-1:0] ds_to_mem_bus_1,
*/
    // 全局异常与中�?
    input  wire        ds_has_int,
    input  wire        ds_reflush ,//异常或�?�分支预测失�?
    input  wire   [1:0]   rn_allowin_cnt,
    input  wire       ds_llbit,
    input  wire       write_buffer_empty,
    input  wire       dcache_empty,
    input  wire       rob_empty
);


    // A. 解析 Fetch Buffer 传来的取指包

    wire [32:0] adef_data_0, adef_data_1;
    wire [31:0] inst_0, pc_0;
    wire [31:0] inst_1, pc_1;
reg [`FS_TO_DS_BUS_WD -1:0] deq_bus_0_r;
reg [`FS_TO_DS_BUS_WD -1:0] deq_bus_1_r;
//    assign {adef_data_0, inst_0, pc_0} = deq_bus_0_r;
//    assign {adef_data_1, inst_1, pc_1} = deq_bus_1_r;


wire [6:0]  excps_0, excps_1;
wire        pred_taken_0, pred_taken_1;
wire [31:0] pred_target_0, pred_target_1;

wire [31:0] badvaddr_1;
wire [31:0] badvaddr_0;
// 2. ���½���߼� (�ϸ���� IF ���Ĵ��˳��)
// ����� 0 ��ָ��
    assign {
        pc_0,            // 32-bit (MSB)
        inst_0,          // 32-bit
        excps_0,         // 7-bit  (�������쳣��־λ)
        badvaddr_0,     // 32-bit (�� badvaddr_0)
        pred_taken_0,    // 1-bit  (������Ԥ����ת����)
        pred_target_0    // 32-bit (������Ԥ����תĿ��, LSB)
    } = deq_bus_0_r;

    // ����� 1 ��ָ��
    assign {
        pc_1,            // 32-bit (MSB)
        inst_1,          // 32-bit
        excps_1,         // 7-bit  (�������쳣��־λ)
        badvaddr_1,     // 32-bit (�� badvaddr_1)
        pred_taken_1,    // 1-bit  (������Ԥ����ת����)
        pred_target_1    // 32-bit (������Ԥ����תĿ��, LSB)
    } = deq_bus_1_r;


    // B. 实例化两�? Decode 模块进行双重译码

    wire [`DE_TO_DS_BUS-1:0] dec_bus_0;
    wire [`DE_TO_DS_BUS-1:0] dec_bus_1;
assign adef_data_0 = {excps_0[6],badvaddr_0};
assign adef_data_1 = {excps_1[6],badvaddr_1};
    decode u_dec0(
        .inst        (inst_0),
        .pc          (pc_0),
        .adef_data   (adef_data_0),
        .excps       (excps_0[5:0]),
        .ds_has_int  (ds_has_int),
        .de_to_ds_bus(dec_bus_0),
        .pred_taken (pred_taken_0),    
        .pred_target (pred_target_0),
        .ds_llbit (ds_llbit)
    );

    decode u_dec1(
        .inst        (inst_1),
        .pc          (pc_1),
        .adef_data   (adef_data_1),
        .excps       (excps_1[5:0]),
        .ds_has_int  (1'b0),
        .de_to_ds_bus(dec_bus_1),
        .pred_taken (pred_taken_1),    
        .pred_target (pred_target_1),
        .ds_llbit (ds_llbit)
    );

    
    // C. 动�?�指令路由与资源�?�? (核心乱序分发逻辑)
   
    // 从你拼装�? bus �?低两位提�? iq_type (01: MEM, 00: ALU)
   /* wire [1:0] iq_type_0 = dec_bus_0[1:0]; 
    wire [1:0] iq_type_1 = dec_bus_1[1:0];

    wire inst0_needs_mem = (iq_type_0 == 2'b01);
    wire inst0_needs_alu = (iq_type_0 == 2'b00);
    
    wire inst1_needs_mem = (iq_type_1 == 2'b01);
    wire inst1_needs_alu = (iq_type_1 == 2'b00);
*/

wire inst_bar_stall_0;
wire inst_bar_stall_1;

assign inst_bar_stall_0 = (ds_to_rename_bus_0[315] | ds_to_rename_bus_0[316]) && (!write_buffer_empty || !dcache_empty || !rob_empty);
assign inst_bar_stall_1 = (ds_to_rename_bus_1[315] | ds_to_rename_bus_1[316]) && (!write_buffer_empty || !dcache_empty || !rob_empty);

    // D. 结算出队数量 (返回�? Fetch Buffer)
reg ds_valid0;
reg ds_valid1;
    assign deq_pop_count = inst1_can_go_id ? 2'd2 : 
                           inst0_can_go_id ? 2'd1 : 2'd0;
wire inst0_can_go_id =  ds_valid0 &&!ds_reflush && (
                        rn_allowin_cnt >= 2'b1
                      ) && !inst_bar_stall_0;


wire inst1_can_go_id = ds_valid1 && inst0_can_go_id && !ds_reflush && (
                       rn_allowin_cnt  == 2'b10
                      ) && !inst_bar_stall_1;

    // E. 发往具体队列的�?�线连接
    // ALU 队列数据通口
    assign ds_to_rename_valid_0 = inst0_can_go_id & ds_valid0;
    assign ds_to_rename_bus_0   = dec_bus_0 &{`DE_TO_DS_BUS{ds_valid0}};
    assign ds_to_rename_valid_1 = inst1_can_go_id &ds_valid1;
    assign ds_to_rename_bus_1   = dec_bus_1 &{`DE_TO_DS_BUS{ds_valid1}};


wire ds_allowin;

assign ds_allowin = 1;
always @(posedge clk) begin
    if (reset || ds_reflush) begin
        ds_valid0 <= 1'b0;
        ds_valid1 <= 1'b0;
    end
    else if ((inst0_can_go_id &inst1_can_go_id)||((ds_valid0 == 1'b0) && (ds_valid1 == 1'b0)) || (inst0_can_go_id && (ds_valid1 == 1'b0))) begin
        ds_valid0 <= deq_valid[0];
        deq_bus_0_r <= deq_bus_0;
        ds_valid1 <= deq_valid[1];
         deq_bus_1_r <= deq_bus_1;
    end
    
    else if(inst0_can_go_id & !inst1_can_go_id)begin
        ds_valid0 <= ds_valid1;
        deq_bus_0_r <= deq_bus_1_r;
        ds_valid1 <= deq_valid[1];
         deq_bus_1_r <= deq_bus_1;
    end   
end
endmodule