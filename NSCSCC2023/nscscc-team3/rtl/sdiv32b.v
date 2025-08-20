/*
    有符号32位除法器，输出为32位商和32位余数
    耗时33周期
*/
`define N 32
module sdiv32b (
    input clk,
    input rst_n,
    input in_valid,
    output in_ready,
    output out_valid,
    input  signed [`N-1:0]  A,
    input  signed [`N-1:0]  B,
    output reg [`N-1:0] Rm,
    output reg [`N-1:0] Q
);
    reg signed [`N*2-1:0]  rm_q_reg;    //余数-商寄存器(R)
    reg signed [`N-1:0]    B_reg;       //除数寄存器(R)
    reg signed [`N-1:0]    minus_B_reg; //负除数寄存器(R)
    reg                    Q_sign_reg;  //商符号寄存器(R)
    reg        [5:0]       state;       //状态机，初始化为34,1=输出,0=空闲
    wire signed [`N-1:0]    rm_next;     //部分余数
    wire signed [`N-1:0]    q_next;      //新的商
    wire signed [`N-1:0]    rm_reg;      //rm_q_reg的高N位
    wire signed [`N-1:0]    q_reg;       //rm_q_reg的低N位
    
    
    //计算新的部分余数和商
    assign rm_next = $signed(rm_q_reg[`N*2-2:`N-1]) + ((B_reg[`N-1]==rm_q_reg[`N*2-1]) ? minus_B_reg : B_reg);
    assign q_next = {rm_q_reg[`N-2:0],~rm_next[`N-1]^B_reg[`N-1]};

    always @(posedge clk)begin
        if(!rst_n)
            Q_sign_reg<=0;
        else if(in_valid && in_ready)
            Q_sign_reg<=A[`N-1]^B[`N-1];//保存商的符号，供最后修正使用
    end

    always @(posedge clk)begin
        if(!rst_n)
            B_reg<=0;
        else if(in_valid && in_ready)
            B_reg<=B; //初始化除数
    end
    always @(posedge clk)begin
        if(!rst_n)
            minus_B_reg<=0;
        else if(in_valid && in_ready)
            minus_B_reg<=-$signed(B);      //初始化除数
    end
    always @(posedge clk)begin
        if(!rst_n)
            rm_q_reg<=0;
        else if(in_valid && in_ready)
            rm_q_reg<=$signed(A);          //初始化被除数(部分余数)
        else if(|state[5:1])               //计数器在2-34时说明计算未完成
            rm_q_reg<={rm_next,q_next};  //更新rm_q寄存器
    end

    always @(posedge clk)begin
        if(!rst_n)
            state<=0;
        else if(in_valid && in_ready)
            state<=`N+2;                   //初始化被除数(部分余数)
        else if(|state)
            state<=state-1;                //计数器递减
    end

    assign in_ready = state == 0;
    assign out_valid = state == 1;
    assign {rm_reg,q_reg} = rm_q_reg;
    //修正最终结果 商
    always @(posedge clk)begin
        //Q_sign_reg 等价于第一次迭代前被除数和除数符号是否不相同，相同则为0，不相同则为1
        //q_reg[0]   等价于最后一次迭代后部分余数和除数的符号是否相同，相同则为1，不相同则为0
        case({Q_sign_reg,q_reg[0]})
        2'b00: Q <= q_reg+((rm_reg==0) ? 32'h1 : 32'h0);
        2'b01: Q <= q_reg+((rm_reg==B_reg) ? 32'h1 : 32'h0);
        2'b10: Q <= q_reg+((rm_reg==minus_B_reg) ? 32'h0 : 32'h1);
        2'b11: Q <= q_reg+((rm_reg==0) ? 32'h0 : 32'h1);
        endcase
    end
    //修正最终结果 余数
    always @(posedge clk)begin
        case({Q_sign_reg,q_reg[0]})
        2'b00: Rm <= (rm_reg == 0) ? 0 : $signed(rm_reg)+$signed(B_reg);
        2'b01: Rm <= (rm_reg == B_reg) ? 0 : rm_reg;
        2'b10: Rm <= (rm_reg == minus_B_reg) ? 0 : rm_reg;
        2'b11: Rm <= (rm_reg == 0) ? 0 : $signed(rm_reg)+$signed(minus_B_reg);
        endcase
    end
endmodule
