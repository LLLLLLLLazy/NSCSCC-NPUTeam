// =============================================================================
// 通用寄存器堆（GPR, General-Purpose Register File）
// =============================================================================
// 结构：32 个 32 位寄存器、两个异步读端口、一个同步写端口。
//
// LoongArch 将 r0 定义为恒零寄存器，因此这里同时从读、写两侧保证该语义：
//   1. 读地址为 0 时直接返回常数 0，不依赖 Regs[0] 的存储内容；
//   2. 写地址为 0 时忽略写请求，软件不能改变 r0；
//   3. diff_gprs 中 r0 也固定输出 0，便于差分测试按架构状态比较。
//
// 时序约定：读数据为组合逻辑，地址变化后在同一拍传播；写入发生在 clk 上升沿。
// CPU_top 对“同拍写回、同拍读取”的情况另设 WB->ID 旁路，因此本模块不依赖
// FPGA RAM 的 read-during-write 模式，综合到寄存器或分布式 RAM 时语义均明确。
// =============================================================================
module Register(
    input clk,                    // 寄存器堆写时钟，上升沿采样写端口。
    input rst,                    // 高有效同步复位；复位时清零全部物理存储单元。
    input Write_En,               // 写使能；仅与非零 Write_addr 同时有效时真正写入。
    input [4:0] Read_rk_rd,       // 第二读端口地址，译码阶段按指令选择 rk 或 rd。
    input [4:0] Read_rj,          // 第一读端口地址，通常对应指令的 rj 字段。
    input [31:0] Write_data,      // 写回阶段提交的 32 位架构结果。
    input [4:0] Write_addr,       // 写回目的寄存器号 rd。
    output [31:0] Read_rk_rd_data,// 第二读端口组合输出。
    output [31:0] Read_rj_data,   // 第一读端口组合输出。
    output [1023:0] diff_gprs     // 差分测试快照：第 n 个 32 位切片对应 GPR[n]。
  );

  // 物理存储仍保留 Regs[0]，从而使数组索引和寄存器编号一一对应；虽然复位会
  // 清零它，但架构上的“恒零”性质由下面的读旁路和写屏蔽保证，而非依赖其值。
  reg [31:0] Regs[31:0];
  integer i; // 仅用于复位时展开 32 项清零循环，不是架构可见状态。

  // 两个独立组合读端口。显式处理地址 0 也可避免仿真初期未知 Regs[0] 泄漏。
  assign Read_rk_rd_data=(Read_rk_rd==5'd0)?32'b0:Regs[Read_rk_rd];
  assign Read_rj_data=(Read_rj== 5'd0)?32'b0:Regs[Read_rj];

  // ---------------------------------------------------------------------------
  // 差分测试观察总线
  // ---------------------------------------------------------------------------
  // 使用 indexed part-select：diff_gprs[n*32 +: 32] 即第 n 个寄存器。
  // 该总线只用于观察，不参与流水线控制，也不会反向改变寄存器堆内容。
  assign diff_gprs[0*32 +: 32]  = 32'b0;
  assign diff_gprs[1*32 +: 32]  = Regs[1];
  assign diff_gprs[2*32 +: 32]  = Regs[2];
  assign diff_gprs[3*32 +: 32]  = Regs[3];
  assign diff_gprs[4*32 +: 32]  = Regs[4];
  assign diff_gprs[5*32 +: 32]  = Regs[5];
  assign diff_gprs[6*32 +: 32]  = Regs[6];
  assign diff_gprs[7*32 +: 32]  = Regs[7];
  assign diff_gprs[8*32 +: 32]  = Regs[8];
  assign diff_gprs[9*32 +: 32]  = Regs[9];
  assign diff_gprs[10*32 +: 32] = Regs[10];
  assign diff_gprs[11*32 +: 32] = Regs[11];
  assign diff_gprs[12*32 +: 32] = Regs[12];
  assign diff_gprs[13*32 +: 32] = Regs[13];
  assign diff_gprs[14*32 +: 32] = Regs[14];
  assign diff_gprs[15*32 +: 32] = Regs[15];
  assign diff_gprs[16*32 +: 32] = Regs[16];
  assign diff_gprs[17*32 +: 32] = Regs[17];
  assign diff_gprs[18*32 +: 32] = Regs[18];
  assign diff_gprs[19*32 +: 32] = Regs[19];
  assign diff_gprs[20*32 +: 32] = Regs[20];
  assign diff_gprs[21*32 +: 32] = Regs[21];
  assign diff_gprs[22*32 +: 32] = Regs[22];
  assign diff_gprs[23*32 +: 32] = Regs[23];
  assign diff_gprs[24*32 +: 32] = Regs[24];
  assign diff_gprs[25*32 +: 32] = Regs[25];
  assign diff_gprs[26*32 +: 32] = Regs[26];
  assign diff_gprs[27*32 +: 32] = Regs[27];
  assign diff_gprs[28*32 +: 32] = Regs[28];
  assign diff_gprs[29*32 +: 32] = Regs[29];
  assign diff_gprs[30*32 +: 32] = Regs[30];
  assign diff_gprs[31*32 +: 32] = Regs[31];
  // ---------------------------------------------------------------------------
  // 同步写端口与复位优先级
  // ---------------------------------------------------------------------------
  // 优先级为 rst > 正常写入 > 保持。非阻塞赋值保证所有寄存器在同一上升沿更新。
  // Write_En 为 0 或目的地址为 r0 时没有赋值，数组自然保持原值。
  always@(posedge clk)
  begin
    if(rst)
    begin
      for(i=0;i<32;i=i+1)
        Regs[i]<=32'b0;
    end
    else if(Write_En && Write_addr!=0)
    begin
      Regs[Write_addr]<=Write_data;
    end
  end

endmodule
