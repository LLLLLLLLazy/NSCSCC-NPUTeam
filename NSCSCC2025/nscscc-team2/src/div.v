module div(
    input               clk,
    input               reset,
    input               start,
    input [31:0]        a,         // dividend (被除数)
    input [31:0]        b,         // divisor  (除数)
    input               is_signed, // signed/unsigned 控制
    input               ex_fire,   

    input               have_any_flush,

    output reg [31:0]   q,         // quotient (商)
    output reg [31:0]   r,         // remainder (余数)
    output reg          busy,      // operation in progress (忙碌标志)
    output reg          done,      // operation done (完成标志)
    output reg [5:0]    cnt        // cycle counter (0 ~ 31)
);

    // --------------------------
    // 1) 内部寄存器声明
    // --------------------------
    reg [31:0] dividend_reg;    // 被除数（绝对值）
    reg [31:0] divisor_reg;     // 除数（绝对值）
    reg [31:0] quotient_reg;    // 中间商
    reg [32:0] remainder_reg;   // 中间余数（多1位，最高位作符号/借位标志）
    reg        sign_q;          // 商的符号
    reg        sign_r;          // 余数的符号

    // 组合逻辑变量：当前周期“先移位后比较/减法”的临时余数
    reg [32:0] trial_rem;       
    reg [31:0] next_dividend;   // 记录移位之后的 dividend_reg
    reg [31:0] next_quotient;   // 记录移位与减法之后的 quotient_reg
    reg [32:0] next_remainder;  // 记录移位或减法之后的 remainder_reg

    // --------------------------
    // 2) 时序逻辑：状态机、初始化、逐周期恢复式除法
    // --------------------------
    always @(posedge clk) begin
        if (reset) begin
            // 同步复位：所有寄存器和输出清零
            q            <= 0;
            r            <= 0;
            busy         <= 0;
            done         <= 0;
            cnt          <= 0;
            dividend_reg <= 0;
            divisor_reg  <= 0;
            quotient_reg <= 0;
            remainder_reg<= 0;
            sign_q       <= 0;
            sign_r       <= 0;
        end
        else if (have_any_flush) begin
            // 分支/异常/刷新复位：清除所有寄存器和输出
            q            <= 0;
            r            <= 0;
            busy         <= 0;
            done         <= 0;
            cnt          <= 0;
            dividend_reg <= 0;
            divisor_reg  <= 0;
            quotient_reg <= 0;
            remainder_reg<= 0;
            sign_q       <= 0;
            sign_r       <= 0;
        end
        else begin
            // 默认每个时钟周期先把 done 拉 0；完成时会在一周期内拉高
            done <= 0;
            if (ex_fire) begin
                cnt <= 0;
            end
            if (start && !busy) begin
                // --------- 2.1 启动除法：start 脉冲到来时，且当前不忙 ---------
                if (b == 0) begin
                    // 2.1.1 除数为 0：特殊处理
                    q    <= 32'hFFFFFFFF;  // 商全 1（按实际设计需求也可以选择其他值）
                    r    <= a;             // 余数直接等于被除数
                    busy <= 0;
                    done <= 1;
                    cnt  <= 0;
                end else begin
                    // 2.1.2 正常开始除法
                    busy <= 1;      // 进入“除法中”状态
                    cnt  <= 0;      // 计数器清零

                    // 有符号 / 无符号：获取绝对值
                    if (is_signed) begin
                        // 商符号 = 被除数符号 ^ 除数符号
                        sign_q <= a[31] ^ b[31];
                        // 余数符号 = 被除数符号
                        sign_r <= a[31];
                        // 取绝对值 (两补码取反 +1)
                        dividend_reg <= a[31] ? (~a + 1) : a;
                        divisor_reg  <= b[31] ? (~b + 1) : b;
                    end else begin
                        sign_q       <= 0;
                        sign_r       <= 0;
                        dividend_reg <= a;
                        divisor_reg  <= b;
                    end

                    // 初始时，商和余数都清 0
                    quotient_reg  <= 0;
                    remainder_reg <= 0;
                end

            end else if (busy) begin
                // --------- 2.2 除法主循环：逐位进行恢复式除法 (一共 32 次) ---------
                // 先根据现有的 remainder_reg 与 dividend_reg 最高位组合出 trial_rem
                // 注意：此时使用的 remainder_reg 和 dividend_reg 都是上一个周期的“旧寄存器值”。
                trial_rem = { remainder_reg[31:0], dividend_reg[31] };  

                // 下面分两种情况：trial_rem >= divisor_reg 或者 < divisor_reg
                if (trial_rem >= {1'b0, divisor_reg}) begin
                    // ① 若 trial_rem ≥ 除数，则执行“减法”并在商的当前位写 1
                    next_remainder = trial_rem - {1'b0, divisor_reg};
                    next_quotient  = (quotient_reg << 1) | 1;
                end else begin
                    // ② 否则“恢复”余数，即余数等于 trial_rem，商当前位写 0
                    next_remainder = trial_rem;
                    next_quotient  = (quotient_reg << 1);
                end

                // 同时，被除数也要左移 1 位，为下一位移位做准备
                next_dividend = dividend_reg << 1;

                // ====== 将“next_xxx” 写回寄存器 ======
                remainder_reg  <= next_remainder;
                quotient_reg   <= next_quotient;
                dividend_reg   <= next_dividend;

                // 周期计数 +1
                if (cnt == 6'd31) begin
                    // 如果已经完成 32 次循环 (0~31)，结束除法
                    busy <= 0;
                    done <= 1;

                    // 恢复符号：若 sign_q 或 sign_r 为 1，则对结果取两补
                    if (sign_q)
                        q <= ~next_quotient + 1;
                    else
                        q <= next_quotient;

                    if (sign_r)
                        r <= ~next_remainder[31:0] + 1;
                    else
                        r <= next_remainder[31:0];

                    // cnt 保持在 31，或者也可以在这里清零，取决于你想怎么调试
                    // cnt <= 0;
                end else begin
                    cnt <= cnt + 1;
                end

            end
            // else: 空闲状态，busy=0 时 done=0，不做额外操作
        end
    end

endmodule
