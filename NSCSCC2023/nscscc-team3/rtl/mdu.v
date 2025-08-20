`include "header.v"
`define DIVSTA_FREE     1'b0
`define DIVSTA_BUSY     1'b1
`define MDUOP_MULS      3'b000
`define MDUOP_MULHS     3'b100
`define MDUOP_MULHU     3'b110
`define MDUOP_DIVS      3'b001
`define MDUOP_DIVU      3'b011
`define MDUOP_MODS      3'b101
`define MDUOP_MODU      3'b111
module mdu(
    input clk,
    input rst_n,
    input flush,
    input [31:0] a,
    input [31:0] b,
    input exe_valid,
    input is_mdu_instr,
    input [2:0] mduop,
    output reg [31:0] mdu_prod,
    output stall        //乘法计算未完成可能导致exe级阻塞
);
    //为了改善时序而延迟flush
    reg flush_reg;
    always @(posedge clk) begin
        flush_reg <= flush;
    end
    wire [63:0] divs_prod;
    wire [63:0] divu_prod;
    reg  [1:0]  state_mul;
    reg  [1:0]  next_state_mul;
    reg  state_div;
    reg  next_state_div;
    wire is_mul;
    wire is_div;                 //当前指令是除法
    wire is_divs;                //当前指令是有符号除法
    wire is_divu;                //当前指令是无符号除法
    wire readygo_div;
    wire readygo_mul;
    wire divs_input_tready;     
    wire divu_input_tready;
    wire divs_input_tvalid;
    wire divs_dout_tvalid;
    wire divu_input_tvalid;
    wire divu_dout_tvalid;
    assign is_mul  = is_mdu_instr & ~mduop[0];
    assign is_div  = is_mdu_instr & mduop[0];
    assign is_divs = is_mdu_instr & mduop[0] & ~mduop[1];
    assign is_divu = is_mdu_instr & mduop[0] & mduop[1];
    //状态转换
    always @(posedge clk) begin
        if(!rst_n)
            state_div <= `DIVSTA_FREE;
        else if(flush_reg)
            state_div <= `DIVSTA_FREE;
        else state_div <= next_state_div;
    end
    always @(posedge clk) begin
        if(!rst_n)
            state_mul <= 2'h0;
        else if(flush_reg)
            state_mul <= 2'h0;
        else state_mul <= next_state_mul;
    end
    //下一状态生成
    always @(*) begin
        case(state_div)
        `DIVSTA_FREE:    next_state_div = exe_valid && is_div ? `DIVSTA_BUSY : `DIVSTA_FREE;
        `DIVSTA_BUSY:    next_state_div = ((is_divs &  divs_dout_tvalid) | (is_divu & divu_dout_tvalid)) ? `DIVSTA_FREE : `DIVSTA_BUSY;
        endcase
    end
    always @(*) begin
        case(state_mul)
        2'h0:    next_state_mul = (exe_valid && is_mul) ? 2'h1 : 2'h0;
        2'h1:    next_state_mul = 2'h2;
        2'h2:    next_state_mul = 2'h0;
        2'h3:    next_state_mul = 2'h0;
        endcase
    end
    assign readygo_div = next_state_div == `DIVSTA_FREE;
    assign readygo_mul = next_state_mul == 2'h0;
    // 输出生成
    assign stall = !readygo_div || !readygo_mul;
    //DIV计算
    assign divs_input_tvalid = (state_div == `DIVSTA_FREE && next_state_div == `DIVSTA_BUSY) && is_divs;
    assign divu_input_tvalid = (state_div == `DIVSTA_FREE && next_state_div == `DIVSTA_BUSY) && is_divu;
    sdiv32b DIVS(
        .clk(clk),
        .rst_n(rst_n && !flush_reg),
        .A(a),
        .B(b),
        .in_valid(divs_input_tvalid),
        .in_ready(divs_input_tready),           //* cpu流水线结构已经保证要计算时ready一定为1
        .Rm(divs_prod[31:0]),
        .Q(divs_prod[63:32]),
        .out_valid(divs_dout_tvalid)
    );

    udiv32b DIVU(
        .clk(clk),
        .rst_n(rst_n && !flush_reg),
        .A(a),
        .B(b),
        .in_valid(divu_input_tvalid),
        .in_ready(divu_input_tready),           //* cpu流水线结构已经保证要计算时ready一定为1
        .Rm(divu_prod[31:0]),
        .Q(divu_prod[63:32]),
        .out_valid(divu_dout_tvalid)
    );
    wire [65:0] mul_prod;
    mul33_3cycle MUL(.clk(clk),.x({(~mduop[1]&a[31]),a}),.y({(~mduop[1]&b[31]),b}),.res(mul_prod));
    //assign muls_prod = $signed(a)*$signed(b);
    //assign mulu_prod = $unsigned(a)*$unsigned(b);
    //MDU计算结果选择
    always @(*) begin
       case(mduop)
       `MDUOP_MULS:    mdu_prod = mul_prod[31:0];
       `MDUOP_MULHS:   mdu_prod = mul_prod[63:32];
       `MDUOP_MULHU:   mdu_prod = mul_prod[63:32];
       `MDUOP_MODS:    mdu_prod = divs_prod[31:0];
       `MDUOP_MODU:    mdu_prod = divu_prod[31:0];
       `MDUOP_DIVS:    mdu_prod = divs_prod[63:32];
       `MDUOP_DIVU:    mdu_prod = divu_prod[63:32];
       default:        mdu_prod = 32'h0;
       endcase
    end
endmodule
