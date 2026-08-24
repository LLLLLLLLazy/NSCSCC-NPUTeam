// Return Address Stack (RAS)
module ras #(
    parameter ADDR_WIDTH = 32,
    parameter DEPTH_BITS = 4        // 深度 = 2^DEPTH_BITS，默认 16
) (
    input  wire                      clk,
    input  wire                      reset,
    input  wire                      flush,
    // IF1 阶段：push/pop 由 BTB 命中类型驱动
    input  wire                      push_en,
    input  wire [ADDR_WIDTH-1:0]     push_addr,       // 返回地址 = CALL PC + 4
    input  wire                      pop_en,

    // 组合读出栈顶，IF1 同周期用于预测 next PC
    output wire [ADDR_WIDTH-1:0]     ras_top,
    output wire                      ras_empty
);

    localparam DEPTH = (1 << DEPTH_BITS);

    reg [ADDR_WIDTH-1:0]  stack     [0:DEPTH-1];
    reg [DEPTH_BITS-1:0]  tos;
    reg [DEPTH_BITS:0]    depth_cnt;

    wire [DEPTH_BITS-1:0] tos_push = tos + 1'b1;
    wire [DEPTH_BITS-1:0] tos_pop  = tos - 1'b1;

    // 栈顶组合读出
    assign ras_top   = stack[tos];
    assign ras_empty = (depth_cnt == {(DEPTH_BITS+1){1'b0}});

    integer i;

    always @(posedge clk) begin
        if (reset || flush) begin
            tos       <= {DEPTH_BITS{1'b0}};
            depth_cnt <= {(DEPTH_BITS+1){1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                stack[i] <= {ADDR_WIDTH{1'b0}};

        end else if (push_en && !pop_en) begin
            // CALL：写入新栈顶，tos 递增（环形）
            stack[tos_push] <= push_addr;
            tos             <= tos_push;
            // 满栈时覆盖最旧条目，depth_cnt 上限为 DEPTH
            if (depth_cnt < DEPTH)
                depth_cnt <= depth_cnt + 1'b1;

        end else if (pop_en && !push_en) begin
            // RET：tos 递减（环形），数据原地保留
            // 下溢保护：栈空时 tos 不移动，避免读到脏数据
            if (!ras_empty) begin
                tos       <= tos_pop;
                depth_cnt <= depth_cnt - 1'b1;
            end

        end
    end

endmodule