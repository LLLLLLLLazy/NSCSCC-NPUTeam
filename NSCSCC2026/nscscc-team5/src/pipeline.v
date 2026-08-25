// =============================================================================
// 流水级边界寄存器集合
// =============================================================================
// 本文件只负责“状态随流水级移动”，不执行指令功能。所有边界采用相同优先级：
//   1. rst：无条件清零，流水线进入全气泡状态；
//   2. En=0：保持原值，用于后级反压或数据相关停顿；
//   3. En=1 且 flush=1：写入全零气泡，杀死该边界中的年轻指令；
//   4. En=1 且 flush=0：锁存上一级的全部数据、控制与异常字段。
//
// 各模块用拼接赋值同时搬运整组字段，关键约束是赋值两侧字段的顺序和位宽必须
// 严格一致。新增流水字段时应同时修改复位、冲刷以及正常传递三处拼接列表。
// =============================================================================

// IF -> ID 边界：保存取指结果、预测元数据以及取指阶段产生的异常。
module IF_ID_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input [31:2] IF_PC_plus_4_word,
    input [31:2] IF_PC_word,
    input [31:0] IF_pred_next_pc,
    input IF_pred_taken,
    input IF_pred_history,
    input [31:0] IF_Instr,
    input IF_valid,
    input fs_ex_adef,
    input [31:0] fs_bad_pc,
    input fs_ex_tlbr,
    input fs_ex_pif,
    input fs_ex_ppi,
    output reg [31:2] ID_PC_plus_4_word,
    output reg [31:0] ID_Instr,
    output reg [31:2] ID_PC_word,
    output reg [31:0] ID_pred_next_pc,
    output reg ID_pred_taken,
    output reg ID_pred_history,
    output reg ID_valid,
    output reg id_fs_ex_adef,
    output reg [31:0] id_fs_bad_pc,
    output reg id_fs_ex_tlbr,
    output reg id_fs_ex_pif,
    output reg id_fs_ex_ppi
  );
  always @(posedge clk)
  begin
    if(rst)
      {ID_PC_plus_4_word,ID_Instr,ID_PC_word,ID_pred_next_pc,ID_pred_taken,ID_pred_history,ID_valid,id_fs_ex_adef,id_fs_bad_pc,id_fs_ex_tlbr,id_fs_ex_pif,id_fs_ex_ppi}<=0;
    else if(En)
      if(flush)
        {ID_PC_plus_4_word,ID_Instr,ID_PC_word,ID_pred_next_pc,ID_pred_taken,ID_pred_history,ID_valid,id_fs_ex_adef,id_fs_bad_pc,id_fs_ex_tlbr,id_fs_ex_pif,id_fs_ex_ppi}<=0;
      else
        {ID_PC_plus_4_word,ID_Instr,ID_PC_word,ID_pred_next_pc,ID_pred_taken,ID_pred_history,ID_valid,id_fs_ex_adef,id_fs_bad_pc,id_fs_ex_tlbr,id_fs_ex_pif,id_fs_ex_ppi}<={IF_PC_plus_4_word,IF_Instr,IF_PC_word,IF_pred_next_pc,IF_pred_taken,IF_pred_history,IF_valid,fs_ex_adef,fs_bad_pc,fs_ex_tlbr,fs_ex_pif,fs_ex_ppi};
  end

endmodule


// ID -> EX1 边界：携带已译码控制、源操作数、立即数、异常和特权指令类别。
// RJ_data/RK_RD_data 是寄存器堆及 WB->ID 旁路后的初始值；EX1 仍会根据更年轻
// 的流水生产者执行完整旁路，所以这里也同时保留源寄存器编号和 uses 标志。
module ID_EX_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input ID_valid,
    input ID_serializing,
    input ID_refetch,
    input [31:2] ID_PC_plus_4_word,
    input [31:0] ID_pred_next_pc,
    input ID_pred_taken,
    input ID_pred_history,
    input [31:0] RJ_data,
    input [31:0] RK_RD_data,
    input [31:0] ID_imm_12_14_selected,
    input [31:0] ID_imm20_lsl12,
    input [31:0] ID_imm16_sext,
    input [31:0] ID_shamt5_zext,
    input [4:0] RD,
    input [11:0] ID_to_EX_control,
    input ID_to_MEM_control,
    input ID_gpr_write_en,
    input [4:0] RJ,
    input [4:0] RK_RD,
    input ID_uses_rj,
    input ID_uses_rk,
    input ID_branch_wbq_dep,
    input [1:0] ID_CSR_Op,
    input [13:0] ID_csr_num,
    input [14:0] ID_exc_code,
    input [5:0] ID_exc_ecode,
    input ID_fs_ex_adef,
    input [31:0] ID_fs_bad_pc,
    input OP_ldw,
    input OP_beq,
    input OP_bne,
    input OP_bl,
    input OP_b,
    input OP_slti,
    input OP_sltui,
    input OP_pcaddu12i,
    input OP_ertn,
    input ID_has_exception,
    input OP_blt,
    input OP_bge,
    input OP_bltu,
    input OP_bgeu,
    input OP_rdcntvl,
    input OP_rdcntvh,
    input OP_llw,
    input OP_scw,
    input ID_IS_high,
    input [31:2] ID_PC_word,
    input [31:2] PC_jump_word,
    input [1:0] ID_width,
    input ID_sign,
    // TLB/缓存维护/CPUCFG 指令类别与 INVTLB 操作码。
    input OP_tlbsrch,
    input OP_tlbrd,
    input OP_tlbwr,
    input OP_tlbfill,
    input OP_invtlb,
    input [4:0] invtlb_op,
    input OP_cacop,
    input OP_cpucfg,
    output reg EX_valid,
    output reg EX_serializing,
    output reg EX_refetch,
    output reg [31:2] EX_PC_plus_4_word,
    output reg [31:0] EX_pred_next_pc,
    output reg EX_pred_taken,
    output reg EX_pred_history,
    output reg [31:0] RJ_Op,
    output reg [31:0] RK_Op,
    output reg [31:0] EX_imm_12_14_selected,
    output reg [31:0] EX_imm20_lsl12,
    output reg [31:0] EX_imm16_sext,
    output reg [31:0] EX_shamt5_zext,
    output reg [4:0] EX_RD,
    output reg [11:0] ID_EX_control,
    output reg ID_EX_to_MEM_control,
    output reg EX_gpr_write_en,
    output reg [4:0] EX_RJ,
    output reg [4:0] EX_RK_RD,
    output reg EX_uses_rj,
    output reg EX_uses_rk,
    output reg EX_branch_wbq_dep,
    output reg [1:0] EX_CSR_Op,
    output reg [13:0] EX_csr_num,
    output reg [14:0] EX_exc_code,
    output reg [5:0] EX_exc_ecode,
    output reg EX_fs_ex_adef,
    output reg [31:0] EX_fs_bad_pc,
    output reg EX_OP_ldw,
    output reg EX_OP_beq,
    output reg EX_OP_bne,
    output reg EX_OP_bl,
    output reg EX_OP_b,
    output reg EX_OP_slti,
    output reg EX_OP_sltui,
    output reg EX_OP_pcaddu12i,
    output reg EX_OP_ertn,
    output reg EX_has_exception,
    output reg EX_OP_blt,
    output reg EX_OP_bge,
    output reg EX_OP_bltu,
    output reg EX_OP_bgeu,
    output reg EX_OP_rdcntvl,
    output reg EX_OP_rdcntvh,
    output reg EX_OP_llw,
    output reg EX_OP_scw,
    output reg EX_IS_high,
    output reg [31:2] EX_PC_word,
    output reg [31:2] EX_PC_jump_word,
    output reg [1:0] EX_width,
    output reg EX_sign,
    // 对应的 EX1 级特权控制输出。
    output reg EX_OP_tlbsrch,
    output reg EX_OP_tlbrd,
    output reg EX_OP_tlbwr,
    output reg EX_OP_tlbfill,
    output reg EX_OP_invtlb,
    output reg [4:0] EX_invtlb_op,
    output reg EX_OP_cacop,
    output reg EX_OP_cpucfg
  );

  // 用单次拼接更新整个 ID/EX payload。ID_serializing 表示该指令必须等待所有
  // 更老的内存副作用排空；ID_refetch 表示提交后要从顺序 PC 重新取指。
  // flush 写零不仅清 valid，也清所有副作用控制，提供双重安全保护。
  always@(posedge clk)
  begin
    if(rst)
      {EX_valid,EX_serializing,EX_refetch,EX_PC_plus_4_word,EX_pred_next_pc,EX_pred_taken,EX_pred_history,RJ_Op,RK_Op,EX_imm_12_14_selected,EX_imm20_lsl12,EX_imm16_sext,EX_shamt5_zext,EX_RD,ID_EX_control,
       ID_EX_to_MEM_control,EX_gpr_write_en,EX_RJ,EX_RK_RD,EX_uses_rj,EX_uses_rk,EX_branch_wbq_dep,EX_CSR_Op,EX_csr_num,EX_exc_code,EX_exc_ecode,EX_fs_ex_adef,EX_fs_bad_pc,EX_OP_ldw,EX_OP_beq,EX_OP_bne,EX_OP_bl,EX_OP_b,
       EX_OP_slti,EX_OP_sltui,EX_OP_pcaddu12i,EX_OP_ertn,EX_has_exception,EX_OP_blt,EX_OP_bge,EX_OP_bltu,EX_OP_bgeu,EX_OP_rdcntvl,EX_OP_rdcntvh,EX_OP_llw,EX_OP_scw,EX_IS_high,EX_PC_word,EX_PC_jump_word,EX_width,EX_sign,
       EX_OP_tlbsrch,EX_OP_tlbrd,EX_OP_tlbwr,EX_OP_tlbfill,EX_OP_invtlb,EX_invtlb_op,EX_OP_cacop,EX_OP_cpucfg}<=0;
    else if(En)
      if(flush)
        {EX_valid,EX_serializing,EX_refetch,EX_PC_plus_4_word,EX_pred_next_pc,EX_pred_taken,EX_pred_history,RJ_Op,RK_Op,EX_imm_12_14_selected,EX_imm20_lsl12,EX_imm16_sext,EX_shamt5_zext,EX_RD,ID_EX_control,
          ID_EX_to_MEM_control,EX_gpr_write_en,EX_RJ,EX_RK_RD,EX_uses_rj,EX_uses_rk,EX_branch_wbq_dep,EX_CSR_Op,EX_csr_num,EX_exc_code,EX_exc_ecode,EX_fs_ex_adef,EX_fs_bad_pc,EX_OP_ldw,EX_OP_beq,EX_OP_bne,EX_OP_bl,EX_OP_b,
         EX_OP_slti,EX_OP_sltui,EX_OP_pcaddu12i,EX_OP_ertn,EX_has_exception,EX_OP_blt,EX_OP_bge,EX_OP_bltu,EX_OP_bgeu,EX_OP_rdcntvl,EX_OP_rdcntvh,EX_OP_llw,EX_OP_scw,EX_IS_high,EX_PC_word,EX_PC_jump_word,EX_width,EX_sign,
         EX_OP_tlbsrch,EX_OP_tlbrd,EX_OP_tlbwr,EX_OP_tlbfill,EX_OP_invtlb,EX_invtlb_op,EX_OP_cacop,EX_OP_cpucfg}<=0;
      else
        {EX_valid,EX_serializing,EX_refetch,EX_PC_plus_4_word,EX_pred_next_pc,EX_pred_taken,EX_pred_history,RJ_Op,RK_Op,EX_imm_12_14_selected,EX_imm20_lsl12,EX_imm16_sext,EX_shamt5_zext,EX_RD,ID_EX_control,
             ID_EX_to_MEM_control,EX_gpr_write_en,EX_RJ,EX_RK_RD,EX_uses_rj,EX_uses_rk,EX_branch_wbq_dep,EX_CSR_Op,EX_csr_num,EX_exc_code,EX_exc_ecode,EX_fs_ex_adef,EX_fs_bad_pc,EX_OP_ldw,EX_OP_beq,EX_OP_bne,EX_OP_bl,EX_OP_b,
            EX_OP_slti,EX_OP_sltui,EX_OP_pcaddu12i,EX_OP_ertn,EX_has_exception,EX_OP_blt,EX_OP_bge,EX_OP_bltu,EX_OP_bgeu,EX_OP_rdcntvl,EX_OP_rdcntvh,EX_OP_llw,EX_OP_scw,EX_IS_high,EX_PC_word,EX_PC_jump_word,EX_width,EX_sign,
            EX_OP_tlbsrch,EX_OP_tlbrd,EX_OP_tlbwr,EX_OP_tlbfill,EX_OP_invtlb,EX_invtlb_op,EX_OP_cacop,EX_OP_cpucfg}<=
        {ID_valid,ID_serializing,ID_refetch,ID_PC_plus_4_word,ID_pred_next_pc,ID_pred_taken,ID_pred_history,RJ_data,RK_RD_data,ID_imm_12_14_selected,ID_imm20_lsl12,ID_imm16_sext,ID_shamt5_zext,RD,
          ID_to_EX_control,ID_to_MEM_control,ID_gpr_write_en,RJ,RK_RD,ID_uses_rj,ID_uses_rk,ID_branch_wbq_dep,ID_CSR_Op,ID_csr_num,ID_exc_code,ID_exc_ecode,ID_fs_ex_adef,ID_fs_bad_pc,OP_ldw,OP_beq,OP_bne,OP_bl,OP_b,
         OP_slti,OP_sltui,OP_pcaddu12i,OP_ertn,ID_has_exception,OP_blt,OP_bge,OP_bltu,OP_bgeu,OP_rdcntvl,OP_rdcntvh,OP_llw,OP_scw,ID_IS_high,ID_PC_word,PC_jump_word,ID_width,ID_sign,
         OP_tlbsrch,OP_tlbrd,OP_tlbwr,OP_tlbfill,OP_invtlb,invtlb_op,OP_cacop,OP_cpucfg};
  end

endmodule

// EX1/EX2 正式流水边界。EX1 完成寄存器旁路和操作数选择，EX2 完成
// ALU、地址、比较和分支计算。使用统一数据总线可确保所有控制/异常字段
// 与操作数在暂停和冲刷时严格同拍移动。
//
// BUS_W 由 CPU_top 中 ex1_ex2_bus_in/out 的打包格式决定。这里故意不理解各位
// 的含义，使后续扩展字段时只需同步修改顶层打包和 BUS_W，而无需复制长端口表。
module EX1_EX2_reg #(
    parameter BUS_W = 316
  )(
    input                   clk,
    input                   rst,
    input                   En,
    input                   flush,
    input      [BUS_W-1:0]  bus_in,
    output reg [BUS_W-1:0]  bus_out
  );

  // PC 在大部分内部接口中使用 [31:2] 字地址；pred_next_pc、bad_pc 保留完整
  // 字节地址。取指异常同样以一条 valid 指令进入 ID，便于后端精确提交。
  // En=0 时没有 else 分支，bus_out 保持；这正是长除法或 MEM 反压时的停顿语义。
  always @(posedge clk)
  begin
    if(rst)
      bus_out <= {BUS_W{1'b0}};
    else if(En)
    begin
      if(flush)
        bus_out <= {BUS_W{1'b0}};
      else
        bus_out <= bus_in;
    end
  end

endmodule

// EX2 -> MEM 边界：保存执行结果、访存属性、异常以及 TLB/CACOP 副作用控制。
// ALU_result 在 MEM 中作为数据地址 DM_addr；EX_RD_data 是普通运算/写回候选值。
module EX_MEM_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input EX_valid,
    input EX_serializing,
    input EX_refetch,
    input [31:2] EX_PC_plus_4_word,
    input [31:0] EX_RD_data,
    input [31:0] ALU_result,
    input [4:0] EX_RD,
    input EX_to_MEM_control,
    input EX_gpr_write_en,
    input EX_gpr_wdata_from_pc4,
    input EX_OP_ldw,
    input EX_OP_llw,
    input EX_OP_scw,
    input EX_OP_ertn,
    input EX_has_exception,
    input [1:0] EX_CSR_Op,
    input [13:0] EX_csr_num,
    input [31:0] EX_CSR_rj_data,
    input [14:0] EX_exc_code,
    input [5:0] EX_exc_ecode,
    input [1:0] EX_bypass_Data_Opt,
    input [1:0] EX_width,
    input EX_sign,
    // TLB 指令
    // TLB 指令及缓存维护控制；RK_Op 为 INVTLB 提供已旁路修正的源操作数。
    input EX_OP_tlbsrch,
    input EX_OP_tlbrd,
    input EX_OP_tlbwr,
    input EX_OP_tlbfill,
    input EX_OP_invtlb,
    input [4:0] EX_invtlb_op,
    input EX_OP_cacop,
    input [31:0] RK_Op,
    // 缓存访问的 DA/DMW 地址转换在 EX 级完成，并跨越此流水级边界传递。
    // 将 CSR/DMW 译码保留在 EX 侧，可避免其以组合逻辑方式进入
    // MEM-ready/全局前端控制路径。
    input EX_fast_direct_valid,
    input [31:0] EX_fast_direct_paddr,
    input EX_fast_store_hash_match,
    input EX_fast_direct_req_eligible,
    output reg MEM_valid,
    output reg MEM_serializing,
    output reg MEM_refetch,
    output reg [31:2] MEM_PC_plus_4_word,
    output reg [31:0] MEM_RD_data,
    output reg [31:0] DM_addr,
    output reg [4:0] MEM_RD,
    output reg EX_MEM_control,
    output reg MEM_gpr_write_en,
    output reg MEM_gpr_wdata_from_pc4,
    output reg MEM_OP_ldw,
    output reg MEM_OP_llw,
    output reg MEM_OP_scw,
    output reg MEM_OP_ertn,
    output reg MEM_has_exception,
    output reg [1:0] MEM_CSR_Op,
    output reg [13:0] MEM_csr_num,
    output reg [31:0] MEM_CSR_rj_data,
    output reg [14:0] MEM_exc_code,
    output reg [5:0] MEM_exc_ecode,
    output reg [1:0] MEM_bypass_Data_Opt,
    output reg [1:0] MEM_width,
    output reg MEM_sign,
    // TLB 指令
    // 与输入逐项对应的 MEM 级特权控制输出。
    output reg MEM_OP_tlbsrch,
    output reg MEM_OP_tlbrd,
    output reg MEM_OP_tlbwr,
    output reg MEM_OP_tlbfill,
    output reg MEM_OP_invtlb,
    output reg [4:0] MEM_invtlb_op,
    output reg MEM_OP_cacop,
    output reg [31:0] MEM_RK_Op,
    output reg MEM_fast_direct_valid,
    output reg [31:0] MEM_fast_direct_paddr,
    output reg MEM_fast_store_hash_match,
    output reg MEM_fast_direct_req_eligible
  );
  // fast_direct_* 是 EX 提前计算并经过寄存器切断的快速访存资格信息：它们只
  // 优化常见 DA/DMW cached load 路径，不改变慢速 TLB/异常状态机的语义。
  always@(posedge clk)
  begin
    if(rst)
      {MEM_valid,MEM_serializing,MEM_refetch,MEM_PC_plus_4_word,MEM_RD_data,DM_addr,MEM_RD,EX_MEM_control,MEM_gpr_write_en,MEM_gpr_wdata_from_pc4,MEM_OP_ldw,MEM_OP_llw,MEM_OP_scw,MEM_OP_ertn,
       MEM_has_exception,MEM_CSR_Op,MEM_csr_num,MEM_CSR_rj_data,MEM_exc_code,MEM_exc_ecode,MEM_bypass_Data_Opt,MEM_width,MEM_sign,
       MEM_OP_tlbsrch,MEM_OP_tlbrd,MEM_OP_tlbwr,MEM_OP_tlbfill,MEM_OP_invtlb,MEM_invtlb_op,MEM_OP_cacop,MEM_RK_Op,
       MEM_fast_direct_valid,MEM_fast_direct_paddr,
       MEM_fast_store_hash_match,MEM_fast_direct_req_eligible}<=0;
    else if(En)
      if(flush)
        {MEM_valid,MEM_serializing,MEM_refetch,MEM_PC_plus_4_word,MEM_RD_data,DM_addr,MEM_RD,EX_MEM_control,MEM_gpr_write_en,MEM_gpr_wdata_from_pc4,MEM_OP_ldw,MEM_OP_llw,MEM_OP_scw,MEM_OP_ertn,
         MEM_has_exception,MEM_CSR_Op,MEM_csr_num,MEM_CSR_rj_data,MEM_exc_code,MEM_exc_ecode,MEM_bypass_Data_Opt,MEM_width,MEM_sign,
         MEM_OP_tlbsrch,MEM_OP_tlbrd,MEM_OP_tlbwr,MEM_OP_tlbfill,MEM_OP_invtlb,MEM_invtlb_op,MEM_OP_cacop,MEM_RK_Op,
         MEM_fast_direct_valid,MEM_fast_direct_paddr,
         MEM_fast_store_hash_match,MEM_fast_direct_req_eligible}<=0;
      else
      begin
        {MEM_valid,MEM_serializing,MEM_refetch,MEM_PC_plus_4_word,MEM_RD_data,DM_addr,MEM_RD,EX_MEM_control,MEM_gpr_write_en,MEM_gpr_wdata_from_pc4,MEM_OP_ldw,MEM_OP_llw,MEM_OP_scw,MEM_OP_ertn,
         MEM_has_exception,MEM_CSR_Op,MEM_csr_num,MEM_CSR_rj_data,MEM_exc_code,MEM_exc_ecode,MEM_bypass_Data_Opt,MEM_width,MEM_sign,
         MEM_OP_tlbsrch,MEM_OP_tlbrd,MEM_OP_tlbwr,MEM_OP_tlbfill,MEM_OP_invtlb,MEM_invtlb_op,MEM_OP_cacop,MEM_RK_Op,
         MEM_fast_direct_valid,MEM_fast_direct_paddr,
         MEM_fast_store_hash_match,MEM_fast_direct_req_eligible}
        <={EX_valid,EX_serializing,EX_refetch,EX_PC_plus_4_word,EX_RD_data,ALU_result,EX_RD,EX_to_MEM_control,EX_gpr_write_en,EX_gpr_wdata_from_pc4,EX_OP_ldw,
           EX_OP_llw,EX_OP_scw,EX_OP_ertn,EX_has_exception,EX_CSR_Op,EX_csr_num,EX_CSR_rj_data,EX_exc_code,EX_exc_ecode,EX_bypass_Data_Opt,EX_width,EX_sign,
           EX_OP_tlbsrch,EX_OP_tlbrd,EX_OP_tlbwr,EX_OP_tlbfill,EX_OP_invtlb,EX_invtlb_op,EX_OP_cacop,RK_Op,
           EX_fast_direct_valid,EX_fast_direct_paddr,
           EX_fast_store_hash_match,EX_fast_direct_req_eligible};

      end
  end

endmodule
