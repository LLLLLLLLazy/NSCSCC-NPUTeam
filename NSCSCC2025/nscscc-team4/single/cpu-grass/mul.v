`define MDUOP_MULS      3'b001
`define MDUOP_MULHS     3'b010
`define MDUOP_MULHU     3'b100

module mul(
    input clk,
    input rst_n,
    //input flush,
    input [31:0] a,
    input [31:0] b,
    input start,
    input [2:0] mul_op,
    output reg [31:0] mul_result,
    output reg mul_done        //乘法计算完成标志
);

    reg  [1:0] state_mul;
    reg  [1:0] next_state_mul;

    // 状态转换
    always @(posedge clk) begin
        if(rst_n)
            state_mul <= 2'h0;
        // else if(flush)
        //     state_mul <= 2'h0;
        else 
            state_mul <= next_state_mul;
    end

    // 下一状态生成
    always @(*) begin
        case(state_mul)
        2'h0:    next_state_mul = start ? 2'h1 : 2'h0;
        2'h1:    next_state_mul = 2'h2;
        2'h2:    next_state_mul = 2'h0;
        default: next_state_mul = 2'h0;
        endcase
    end

    // 输出生成
    always @(posedge clk) begin
        // if (rst_n || flush)
        if (rst_n)
            mul_done <= 1'b0;
        else if (state_mul == 2'h2)
            mul_done <= 1'b1;
        else
            mul_done <= 1'b0;
    end

    wire [65:0] mul_prod;
    mul33_3cycle MUL(.clk(clk),.x({(~mul_op[2]&a[31]),a}),.y({(~mul_op[2]&b[31]),b}),.res(mul_prod));

    // MDU计算结果选择
    always @(*) begin
        case(mul_op)
        `MDUOP_MULS:    mul_result = mul_prod[31:0];
        `MDUOP_MULHS:   mul_result = mul_prod[63:32];
        `MDUOP_MULHU:   mul_result = mul_prod[63:32];
        default:        mul_result = 32'h0;
        endcase
    end
endmodule
