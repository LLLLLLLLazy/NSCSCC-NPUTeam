// =============================================================================
// 算术逻辑单元与乘除法适配层
// =============================================================================
// cpu_top_alu 同时提供：
//   * 单拍组合运算：加减、移位、按位逻辑、比较辅助结果；
//   * 两拍锁存乘法：先锁存扩展后的操作数，再保存 64 位乘积；
//   * 多周期除法：向 Xilinx Divider Generator 发请求并缓存返回结果。
//
// 长运算采用 issue / finish / result_take / long_kill 协议：divider_en 允许发射，
// finish 表示当前指令的结果已稳定，result_take 表示 EX 已消费该结果，long_kill
// 则在异常或重定向时取消架构提交。该协议保证后端停顿期间结果保持不变。
// =============================================================================

// 仿真环境用可读的行为级除法器替代厂商 IP；综合环境实例化 Xilinx 黑盒。
`ifdef SIMULATION
  `define CPU_ALU_USE_BEHAVIOR_DIV
`elsif SIMU
  `define CPU_ALU_USE_BEHAVIOR_DIV
`endif

module cpu_top_alu(
    input clk,                    // 长运算状态寄存器时钟。
    input rst,                    // 高有效同步复位；不会直接复位无 reset 的厂商 IP。
    input [31:0] A,               // 第一操作数，含被除数/乘数 A。
    input [31:0] B,               // 第二操作数，低 5 位作移位量，除法时作除数。
    input [3:0] ALUop,            // 运算选择编码，见下方组合 case。
    input EX_IS_high,             // 乘法取高 32 位；除法时选择余数而非商。
    input divider_en,             // EX 当前允许启动长运算。
    input long_kill,              // 杀死当前长运算的架构结果，但允许除法 IP 排空。
    input result_take,            // 后端已在本拍消费 finish 对应的缓存结果。
    output reg [31:0] ALU_result, // 当前 ALUop 对应的 32 位最终结果。
    output wire [31:0] add_result,// 独立地址加法输出，避免经过长运算结果多路器。
    output slt_En,                // 有符号 A<B；供 SLT/分支比较逻辑使用。
    output sltu_En,               // 无符号 A<B；由减法借位推导。
    output finish                 // 当前 MUL/DIV 结果有效且未被 kill。
  );

  // ALUop 11~14 为需要内部状态的长运算；0~10 的精确定义见文件后部 case。
  localparam [3:0] ALU_MUL  = 4'd11;
  localparam [3:0] ALU_MULU = 4'd12;
  localparam [3:0] ALU_DIV  = 4'd13;
  localparam [3:0] ALU_DIVU = 4'd14;

  // 用 33 位 A + ~B + 1 同时获得 A-B、无符号进位以及有符号溢出。
  // N^V 是补码有符号小于；减法无进位表示发生借位，因此 ~C 是无符号小于。
  wire [32:0] full_sub = {1'b0, A} + {1'b0, ~B} + 33'b1;
  wire [31:0] sub_result = full_sub[31:0];
  wire N = sub_result[31];
  wire V = (A[31] != B[31]) && (sub_result[31] != A[31]);
  wire C = full_sub[32];

  assign slt_En  = N ^ V;
  assign sltu_En = ~C;
  assign add_result = A + B;


  // ---------------------------------------------------------------------------
  // 乘法数据通路
  // ---------------------------------------------------------------------------
  // 操作数扩展到 33 位后统一使用 signed 乘法：无符号运算补 0，有符号运算复制
  // 符号位。66 位理论乘积的低 64 位就是两种 32x32 运算所需的架构结果。
  wire mul_op = (ALUop == ALU_MUL) || (ALUop == ALU_MULU);
  wire mul_unsigned_op = (ALUop == ALU_MULU);
  wire signed [32:0] mul_a_next = mul_unsigned_op ? {1'b0, A} : {A[31], A};
  wire signed [32:0] mul_b_next = mul_unsigned_op ? {1'b0, B} : {B[31], B};
  reg signed [32:0] mul_a_q;
  reg signed [32:0] mul_b_q;
  reg               mul_pipe_valid;
  wire signed [65:0] mul_prod_66 = mul_a_q * mul_b_q;
  wire [63:0] mul_prod = mul_prod_66[63:0];

  // ---------------------------------------------------------------------------
  // 除法 IP 接口
  // ---------------------------------------------------------------------------
  // 两个 IP 没有 TREADY：两个输入 TVALID 必须同拍出现，固定延迟后由输出 TVALID
  // 标记 64 位结果。数据布局均为 {quotient[31:0],remainder[31:0]}。
  wire div_op = (ALUop == ALU_DIV) || (ALUop == ALU_DIVU);
  wire [63:0] signed_total_data;
  wire signed_tvalid;
  wire signed_result_tvalid;

  signed_div signed_div(
               .aclk                   (clk),
               .s_axis_divisor_tdata   (B),
               .s_axis_divisor_tvalid  (signed_tvalid),
               .s_axis_dividend_tdata  (A),
               .s_axis_dividend_tvalid (signed_tvalid),
               .m_axis_dout_tdata      (signed_total_data),
               .m_axis_dout_tvalid     (signed_result_tvalid)
             );

  wire [63:0] unsigned_total_data;
  wire unsigned_tvalid;
  wire unsigned_result_tvalid;

  unsigned_div unsigned_div(
                 .aclk                   (clk),
                 .s_axis_divisor_tdata   (B),
                 .s_axis_divisor_tvalid  (unsigned_tvalid),
                 .s_axis_dividend_tdata  (A),
                 .s_axis_dividend_tvalid (unsigned_tvalid),
                 .m_axis_dout_tdata      (unsigned_total_data),
                 .m_axis_dout_tvalid     (unsigned_result_tvalid)
               );

  // ---------------------------------------------------------------------------
  // 长运算占用、结果缓存与取消状态
  // ---------------------------------------------------------------------------
  // busy 表示除法请求已进入无 backpressure 的 IP；result_valid 表示返回值已被
  // 本模块锁存，等待 EX 消费。div_drop 仅丢弃被 kill 的迟到响应，不中断 IP。
  reg [63:0] div_result;
  reg        div_result_valid;
  reg        div_busy;
  reg        div_signed_q;
  reg        div_drop;
  reg [63:0] mul_result;
  reg        mul_result_valid;
  // Divider IP 没有 reset 端口。复位释放后的 40 拍只禁止新的 DIV，
  // 用于排空复位前最多 36 拍延迟的旧响应；普通 ALU/MUL 不受影响。
  reg [5:0] div_reset_quarantine;

  // 乘除共享一个架构长运算槽，任何在途或待消费结果都会阻止重复发射。
  wire unit_occupied = mul_pipe_valid || mul_result_valid ||
                       div_busy || div_result_valid;
  wire mul_issue = !rst && divider_en && mul_op && !long_kill && !unit_occupied;
  wire div_issue = !rst && divider_en && div_op && !long_kill && !unit_occupied &&
                   (div_reset_quarantine == 0);
  wire div_rsp = div_busy &&
                 (div_signed_q ? signed_result_tvalid :
                                 unsigned_result_tvalid);

  assign signed_tvalid   = div_issue && (ALUop == ALU_DIV);
  assign unsigned_tvalid = div_issue && (ALUop == ALU_DIVU);
  // raw tvalid 绝不直接完成 EX；只有锁存且类型匹配的当前结果才能 finish。
  assign finish = !long_kill &&
       ((mul_op && mul_result_valid) ||
        (div_result_valid &&
         (((ALUop == ALU_DIV) && div_signed_q) ||
          ((ALUop == ALU_DIVU) && !div_signed_q))));

  // 状态更新顺序经过刻意安排：先处理消费/返回/发射，最后让 long_kill 覆盖所有
  // 可提交有效位。即使 kill 与 IP 返回同拍，也不会留下可被下一条指令误用的结果。
  always @(posedge clk)
  begin
    if (rst)
    begin
      div_result       <= 64'b0;
      div_result_valid <= 1'b0;
      div_busy         <= 1'b0;
      div_signed_q     <= 1'b0;
      div_drop         <= 1'b0;
      div_reset_quarantine <= 6'd40;
      mul_a_q          <= 33'b0;
      mul_b_q          <= 33'b0;
      mul_pipe_valid   <= 1'b0;
      mul_result       <= 64'b0;
      mul_result_valid <= 1'b0;
    end
    else
    begin
      if (div_reset_quarantine != 0)
        div_reset_quarantine <= div_reset_quarantine - 6'd1;

      if (result_take)
      begin
        mul_result_valid <= 1'b0;
        div_result_valid <= 1'b0;
      end

      if (mul_pipe_valid)
      begin
        mul_result       <= mul_prod;
        mul_result_valid <= 1'b1;
        mul_pipe_valid   <= 1'b0;
      end
      if (div_rsp)
      begin
        div_busy <= 1'b0;
        div_drop <= 1'b0;
        if (!(div_drop || long_kill))
        begin
          div_result <= div_signed_q ? signed_total_data :
                                       unsigned_total_data;
          div_result_valid <= 1'b1;
        end
      end

      if (mul_issue)
      begin
        mul_a_q        <= mul_a_next;
        mul_b_q        <= mul_b_next;
        mul_pipe_valid <= 1'b1;
      end
      if (div_issue)
      begin
        div_busy     <= 1'b1;
        div_signed_q <= (ALUop == ALU_DIV);
        div_drop     <= 1'b0;
      end

      // kill 最后覆盖所有可提交状态；尚未返回的 divider 继续占用单元，
      // 其迟到响应仅用于 drain。div_rsp 与 kill 同拍时上面的响应逻辑
      // 已清 busy，故这里不能重新置 drop。
      if (long_kill)
      begin
        mul_pipe_valid   <= 1'b0;
        mul_result_valid <= 1'b0;
        div_result_valid <= 1'b0;
        if (div_busy && !div_rsp)
          div_drop <= 1'b1;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // 最终结果多路选择
  // ---------------------------------------------------------------------------
  // 编码表：0 ADD，1 SUB，2 SLL，3 SRL，4 SRA，5 AND，6 OR，7 NOR，
  // 8 XOR，9 地址/比较复用加法，10 直通 B，11/12 MUL/MULU，13/14 DIV/DIVU。
  // DIV 的 64 位缓存格式为 {商,余数}，因此 EX_IS_high=0 选商、=1 选余数。
  always @*
  begin
    ALU_result = 32'b0;
    case (ALUop)
      4'd0:
        ALU_result = add_result;
      4'd1:
        ALU_result = A - B;
      4'd2:
        ALU_result = A << B[4:0];
      4'd3:
        ALU_result = A >> B[4:0];
      4'd4:
        ALU_result = $signed(A) >>> B[4:0];
      4'd5:
        ALU_result = A & B;
      4'd6:
        ALU_result = A | B;
      4'd7:
        ALU_result = ~(A | B);
      4'd8:
        ALU_result = A ^ B;
      4'd9:
        ALU_result = add_result;
      4'd10:
        ALU_result = B;
      ALU_MUL:
        ALU_result = EX_IS_high ? mul_result[63:32] : mul_result[31:0];
      ALU_MULU:
        ALU_result = EX_IS_high ? mul_result[63:32] : mul_result[31:0];
      ALU_DIV:
        ALU_result = EX_IS_high ? div_result[31:0] : div_result[63:32];
      ALU_DIVU:
        ALU_result = EX_IS_high ? div_result[31:0] : div_result[63:32];
      default:
        ALU_result = 32'b0;
    endcase
  end

endmodule


// =============================================================================
// 有符号除法包装器
// =============================================================================
// 上层永远同时拉高 dividend/divisor valid。SIMULATION/SIMU 下使用单拍行为模型；
// FPGA 综合时则连接固定延迟的 div_signed_ip。包装器保持两种实现的端口一致。
module signed_div(
    input wire aclk,
    input wire [31:0] s_axis_divisor_tdata,
    input wire s_axis_divisor_tvalid,
    input wire [31:0] s_axis_dividend_tdata,
    input wire s_axis_dividend_tvalid,
    output wire [63:0] m_axis_dout_tdata,
    output wire m_axis_dout_tvalid
  );

`ifdef CPU_ALU_USE_BEHAVIOR_DIV
  // 行为模型把输入采样后的结果寄存一拍。除零按 LoongArch 常见硬件语义返回
  // 商 0xffff_ffff、余数等于被除数，避免 Verilog 除零产生 X 污染测试。
  reg [63:0] dout_q;
  reg        valid_q;

  wire input_valid = s_axis_divisor_tvalid && s_axis_dividend_tvalid;
  wire signed [31:0] dividend = $signed(s_axis_dividend_tdata);
  wire signed [31:0] divisor  = $signed(s_axis_divisor_tdata);
  wire signed [31:0] quotient = (divisor == 32'sd0) ? -32'sd1 : ($signed(s_axis_dividend_tdata) / $signed(s_axis_divisor_tdata));
  wire signed [31:0] remainer = (divisor == 32'sd0) ? dividend : ($signed(s_axis_dividend_tdata) % $signed(s_axis_divisor_tdata));

  // 厂商 IP 没有 reset，本模型也用 initial 建立确定的仿真初值。
  initial begin
    dout_q  = 64'b0;
    valid_q = 1'b0;
  end

  always @(posedge aclk) begin
    valid_q <= input_valid;
    if (input_valid)
      dout_q <= {quotient, remainer};
  end

  assign m_axis_dout_tdata  = dout_q;
  assign m_axis_dout_tvalid = valid_q;
`else
  // 综合路径：Xilinx Divider Generator，无 TREADY/复位端口。
  div_signed_ip u_div_signed_ip (
                  .aclk                   (aclk),
                  .s_axis_divisor_tvalid  (s_axis_divisor_tvalid),
                  .s_axis_divisor_tdata   (s_axis_divisor_tdata),
                  .s_axis_dividend_tvalid (s_axis_dividend_tvalid),
                  .s_axis_dividend_tdata  (s_axis_dividend_tdata),
                  .m_axis_dout_tvalid     (m_axis_dout_tvalid),
                  .m_axis_dout_tdata      (m_axis_dout_tdata)
                );
`endif

endmodule


// =============================================================================
// 无符号除法包装器；接口与 signed_div 相同，仅解释方式不同。
// =============================================================================
module unsigned_div(
    input wire aclk,
    input wire [31:0] s_axis_divisor_tdata,
    input wire s_axis_divisor_tvalid,
    input wire [31:0] s_axis_dividend_tdata,
    input wire s_axis_dividend_tvalid,
    output wire [63:0] m_axis_dout_tdata,
    output wire m_axis_dout_tvalid
  );

`ifdef CPU_ALU_USE_BEHAVIOR_DIV
  // 返回布局仍为 {商,余数}；除零时商全 1、余数保持被除数。
  reg [63:0] dout_q;
  reg        valid_q;

  wire input_valid = s_axis_divisor_tvalid && s_axis_dividend_tvalid;
  wire [31:0] quotient = (s_axis_divisor_tdata == 0) ? 32'hffff_ffff : (s_axis_dividend_tdata / s_axis_divisor_tdata);
  wire [31:0] remainer = (s_axis_divisor_tdata == 0) ? s_axis_dividend_tdata : (s_axis_dividend_tdata % s_axis_divisor_tdata);

  initial begin
    dout_q  = 64'b0;
    valid_q = 1'b0;
  end

  always @(posedge aclk) begin
    valid_q <= input_valid;
    if (input_valid)
      dout_q <= {quotient, remainer};
  end

  assign m_axis_dout_tdata  = dout_q;
  assign m_axis_dout_tvalid = valid_q;
`else
  // 综合路径：无符号配置的 Xilinx Divider Generator。
  div_unsigned_ip u_div_unsigned_ip (
                    .aclk                   (aclk),
                    .s_axis_divisor_tvalid  (s_axis_divisor_tvalid),
                    .s_axis_divisor_tdata   (s_axis_divisor_tdata),
                    .s_axis_dividend_tvalid (s_axis_dividend_tvalid),
                    .s_axis_dividend_tdata  (s_axis_dividend_tdata),
                    .m_axis_dout_tvalid     (m_axis_dout_tvalid),
                    .m_axis_dout_tdata      (m_axis_dout_tdata)
                  );
`endif

endmodule

`ifdef CPU_ALU_USE_BEHAVIOR_DIV
  `undef CPU_ALU_USE_BEHAVIOR_DIV
`endif
