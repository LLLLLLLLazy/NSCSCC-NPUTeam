`include "mycpu.h"

// 假设物理寄存器数量为 64，preg 位宽为 6 bit
// 假设 ROB 深度为 16，rob_id 位宽为 4 bit
module rename_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,         // 异常或分支预测错误时的全局冲刷

   
    // 1. 来自 ID 级的逻辑指令 (只提取重命名需要的核心信号)
    input  wire        ds_to_rename_valid_0,
    input  wire [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_0,
    input  wire        ds_to_rename_valid_1,
    input  wire [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_1,

    // 2. 与 Freelist (空闲列表) 交互：分配 preg

    input  wire [ 1:0] freelist_free_cnt, // Freelist 剩余空闲数量
    output wire        req_preg_0,        // 请求分配第 1 个 preg
    output wire        req_preg_1,        // 请求分配第 2 个 preg
    input  wire [ 5:0] alloc_preg_0,      // 分配到的物理寄存器 0
    input  wire [ 5:0] alloc_preg_1,      // 分配到的物理寄存器 1


    // 3. 与 ReOrder Buffer (ROB) 交互：申请 ROB 表项空间
    input  wire [ 1:0] rob_free_cnt,      // ROB 剩余空闲表项数量
    output wire        req_rob_0,         // 请求分配第 1 个 ROB 空间
    output wire        req_rob_1,         // 请求分配第 2 个 ROB 空间
    input  wire [ 3:0] rob_id_0,          // 返回的 ROB 编号 0
    input  wire [ 3:0] rob_id_1,          // 返回的 ROB 编号 1
    output wire rename_is_store_0,
    output wire rename_is_complex_0,
    output wire rename_has_dest_0,
    output wire rename_is_store_1,
    output wire rename_is_complex_1,
    output wire rename_has_dest_1,
    output wire [ 31:0] rename_pc_0,
    output wire [ 31:0] rename_pc_1,
    output wire [ 31:0] rename_inst_0,
    output wire [ 31:0] rename_inst_1,
    // 4. 与 sRAT (推测映射表) 交互：读写映射关系
    // 读端口 (查 areg 对应的 preg)
    output wire [ 4:0] srat_raddr1_0,
    output wire [ 4:0] srat_raddr2_0,
    input  wire [ 5:0] srat_rdata1_0,
    input  wire [ 5:0] srat_rdata2_0,

    output wire [ 4:0] srat_raddr1_1,
    output wire [ 4:0] srat_raddr2_1,
    input  wire [ 5:0] srat_rdata1_1,
    input  wire [ 5:0] srat_rdata2_1,

    // 写端口 (更新 areg 的 preg 映射)
    output wire        srat_we_0,
    output wire [ 4:0] srat_waddr_0,
    output wire [ 5:0] srat_wdata_0,

    output wire        srat_we_1,
    output wire [ 4:0] srat_waddr_1,
    output wire [ 5:0] srat_wdata_1,

    // 5. 向发射级 (Issue Stage) 发送数据与阻塞请求

    output wire        rn_to_issue_valid_0,
    output wire [ 5:0] preg_rs1_0,
    output wire [ 5:0] preg_rs2_0,
    output wire [ 5:0] preg_rd_0,
    output wire [ 3:0] rn_rob_id_0,
    
    output wire         rn_to_issue_valid_1,
    output wire [ 5:0] preg_rs1_1,
    output wire [ 5:0] preg_rs2_1,
    output wire [ 5:0] preg_rd_1,
    output wire [ 3:0] rn_rob_id_1,

    // 发送占用寄存器的请求 (设置物理寄存器为 Busy 状态)
    output wire        set_preg_busy_0,
    output wire [ 5:0] busy_preg_id_0,
    output wire        set_preg_busy_1,
    output wire [ 5:0] busy_preg_id_1,
    
    input wire [ 1:0] dp_accept_cnt,
    // 反馈给 ID 级的允许接收信号 (Allowin)
    output wire [ 1:0] rn_allowin_cnt,
    
    output wire [ 4:0] areg_dest_0,
    output wire [ 4:0] areg_dest_1,
    output wire [`DE_TO_DS_BUS-1:0] rn_to_issue_bus_0,
    output wire [`DE_TO_DS_BUS-1:0] rn_to_issue_bus_1,
    output wire inst_idle_0,
    output wire inst_idle_1,
    output wire rename_is_load_0,
    output wire rename_is_load_1
    
  //  output wire         can_accept_0,
  //  output wire         can_accept_1
    
    //input wire rename_ready_go
   // input  wire [ 5:0] srat_dest_rdata0,
  //  input  wire [ 5:0] srat_dest_rdata1
);

//wire rename_allowin = rename_ready_go | !rn_valid_0 ;

wire rf_we_0;
wire rf_we_1;
wire [4:0] areg_rs1_0;
wire [4:0] areg_rs2_0;
wire [4:0] areg_rs1_1;
wire [4:0] areg_rs2_1;
reg [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_0_r;
reg [`DE_TO_DS_BUS-1:0] ds_to_rename_bus_1_r;
reg rn_valid_0;
reg rn_valid_1;
assign rf_we_0 = ds_to_rename_bus_0_r[200];
assign rf_we_1 = ds_to_rename_bus_1_r[200];
assign areg_rs1_0 = ds_to_rename_bus_0_r[215:211];
assign areg_rs1_1 = ds_to_rename_bus_1_r[215:211];
assign areg_rs2_0 = ds_to_rename_bus_0_r[210:206];
assign areg_rs2_1 = ds_to_rename_bus_1_r[210:206];
assign areg_dest_0 = ds_to_rename_bus_0_r[220:216];
assign areg_dest_1 = ds_to_rename_bus_1_r[220:216];

assign inst_idle_0 = ds_to_rename_bus_0_r[350];
assign inst_idle_1 = ds_to_rename_bus_1_r[350];
assign rename_is_load_0 = ds_to_rename_bus_0_r[134];
assign rename_is_load_1 = ds_to_rename_bus_1_r[134] ;

assign rename_pc_0 = ds_to_rename_bus_0_r[166:135];
assign rename_inst_0 = ds_to_rename_bus_0_r[349 -: 32];
assign rename_is_store_0 = ds_to_rename_bus_0_r[258];
assign rename_is_complex_0 = ds_to_rename_bus_0_r[257];
assign rename_has_dest_0 = rf_we_0;
assign rename_pc_1 = ds_to_rename_bus_1_r[166:135];
assign rename_inst_1 = ds_to_rename_bus_1_r[349 -: 32];
assign rename_is_store_1 = ds_to_rename_bus_1_r[258];
assign rename_is_complex_1 = ds_to_rename_bus_1_r[257];
assign rename_has_dest_1 = rf_we_1;


wire can_accept_0 = (freelist_free_cnt >= {1'b0, need_preg_0}) && (rob_free_cnt >= {1'b0, need_rob_0});
wire can_accept_1 = can_accept_0 && (freelist_free_cnt >= total_preg_need) && (rob_free_cnt >= total_rob_need);
assign rn_to_issue_bus_0 = ds_to_rename_bus_0_r;
assign rn_to_issue_bus_1 = ds_to_rename_bus_1_r;
assign rn_to_issue_valid_0 = rn_valid_0 & can_accept_0;//加上can_accept防止rob或者free list满了但是dispatch仍然继续分发
assign rn_to_issue_valid_1 = rn_valid_1 & can_accept_1;
// A. 资源检查 (Resource Check)
wire need_preg_0 = rn_valid_0 & rf_we_0 & (areg_dest_0 != 5'd0);
wire need_preg_1 = rn_valid_1 & rf_we_1 & (areg_dest_1 != 5'd0); 
wire [1:0] total_preg_need = need_preg_0 + need_preg_1;  
wire need_rob_0 = rn_valid_0; 
wire need_rob_1 = rn_valid_1;
wire [1:0] total_rob_need = need_rob_0 + need_rob_1;




// B. 资源消耗防泄漏 (Gating)

    // 判断当前周期的指令到底有没有成功被分发走？
    // 如果 dp_accept_cnt 是 1，说明只有第 0 条发走了；是 2 说明都发走了。
    wire inst0_dispatched = rn_valid_0 && (dp_accept_cnt >= 2'd1);
    wire inst1_dispatched = rn_valid_1 && (dp_accept_cnt == 2'd2);

    // 只有指令真正发走了，才允许消耗 Freelist 和 ROB！
    assign req_preg_0 = can_accept_0 & need_preg_0 & inst0_dispatched;
    assign req_preg_1 = can_accept_1 & need_preg_1 & inst1_dispatched;

    assign req_rob_0  = can_accept_0 & need_rob_0  & inst0_dispatched;
    assign req_rob_1  = can_accept_1 & need_rob_1  & inst1_dispatched;


// C. 读 sRAT 与 D. 旁路逻辑 (保持不变)

    assign srat_raddr1_0 = areg_rs1_0;
    assign srat_raddr2_0 = areg_rs2_0;
    assign srat_raddr1_1 = areg_rs1_1;
    assign srat_raddr2_1 = areg_rs2_1;

    // Freelist outputs two queue-head candidates independent of req_preg.
    // Compress them onto actual instructions here.  If inst0 does not need a
    // destination preg, inst1 must consume candidate0 rather than candidate1.
    wire [5:0] alloc_for_inst0 = alloc_preg_0;
    wire [5:0] alloc_for_inst1 = need_preg_0 ? alloc_preg_1 : alloc_preg_0;

    // A same-cycle RAW dependency exists only when inst0 really owns a new preg.
    wire inst1_rs1_match_inst0 = need_preg_0 && (areg_rs1_1 == areg_dest_0);
    wire inst1_rs2_match_inst0 = need_preg_0 && (areg_rs2_1 == areg_dest_0);

    assign preg_rs1_0 = srat_rdata1_0;
    assign preg_rs2_0 = srat_rdata2_0;
    
    assign preg_rs1_1 = inst1_rs1_match_inst0 ? alloc_for_inst0 : srat_rdata1_1;
    assign preg_rs2_1 = inst1_rs2_match_inst0 ? alloc_for_inst0 : srat_rdata2_1;

    assign preg_rd_0 = need_preg_0 ? alloc_for_inst0 : 6'd0;
    assign preg_rd_1 = need_preg_1 ? alloc_for_inst1 : 6'd0;


// F. 写 sRAT (更新映射表)

    // 只有真正分发走了，才允许修改 sRAT 映射表！
    assign srat_we_0    = can_accept_0 & rf_we_0 & (areg_dest_0 != 5'd0) & inst0_dispatched;
    assign srat_waddr_0 = areg_dest_0;
    assign srat_wdata_0 = alloc_for_inst0;

    assign srat_we_1    = can_accept_1 & rf_we_1 & (areg_dest_1 != 5'd0) & inst1_dispatched;
    assign srat_waddr_1 = areg_dest_1;
    assign srat_wdata_1 = alloc_for_inst1;

    assign rn_rob_id_0 = rob_id_0;
    assign rn_rob_id_1 = rob_id_1;

    assign set_preg_busy_0 = srat_we_0;
    assign busy_preg_id_0  = alloc_for_inst0;
    assign set_preg_busy_1 = srat_we_1;
    assign busy_preg_id_1  = alloc_for_inst1;


//  G. 极其关键：流水线"滑动移位"与握手逻辑
    // 1. 计算当前 Rename 级里到底滞留(卡住)了多少条指令？
    wire [1:0] valid_cnt = rn_valid_0 + rn_valid_1;
    wire [1:0] keep_cnt  = valid_cnt - dp_accept_cnt;

    // 2. 告诉前级 (ID级) 我们还能接收几条新指令
    assign rn_allowin_cnt = 2'd2 - keep_cnt;

    // 3. 移位寄存器逻辑
    always @(posedge clk) begin
        if (reset || flush) begin
            rn_valid_0 <= 1'b0;
            rn_valid_1 <= 1'b0;
        end 
        else begin
            case (keep_cnt)
                2'd0: begin
                    //if(rename_allowin) begin
                    // 【情况0】：没卡住任何指令。槽位全空，直接把 DS 传来的新指令塞进去。
                        rn_valid_0 <= ds_to_rename_valid_0;
                        rn_valid_1 <= ds_to_rename_valid_1;
                        if (ds_to_rename_valid_0) ds_to_rename_bus_0_r <= ds_to_rename_bus_0;
                        if (ds_to_rename_valid_1) ds_to_rename_bus_1_r <= ds_to_rename_bus_1;
                  //  end
                end
                
                2'd1: begin
                    // 【情况1】：卡住了 1 条指令。
                    // 卡住的绝对是原本的槽 1，所以必须把槽 1 滑动到槽 0 的位置！
                    //也有可能是只有槽0里有有效指令，但正好robid被分配完了，只能等待
                    if (rn_valid_0 && !rn_valid_1) begin
                        rn_valid_0 <= 1'b1;
                    end else begin
                        rn_valid_0 <= 1'b1;
                        ds_to_rename_bus_0_r <= ds_to_rename_bus_1_r;
                    end
                    rn_valid_1 <= ds_to_rename_valid_0;
                    if (ds_to_rename_valid_0) ds_to_rename_bus_1_r <= ds_to_rename_bus_0;
                end

                2'd2: begin
                    // 【情况2】：卡住了 2 条指令 
                    // 保持原样，没有任何数据移动。DS级这周期也不会发新数据过来。
                    rn_valid_0 <= rn_valid_0;
                    rn_valid_1 <= rn_valid_1;
                end
                
                default: begin
                    rn_valid_0 <= 1'b0;
                    rn_valid_1 <= 1'b0;
                end
            endcase
        end
    end

endmodule

