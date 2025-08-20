/*
    无符号32位除法器，输出为32位商和32位余数
    耗时33周期
*/
`define N 32
module udiv32b (
    input clk,
    input rst_n,
    input in_valid,
    output in_ready,
    output out_valid,
    input  [`N-1:0]  A,
    input  [`N-1:0]  B,
    output [`N-1:0] Rm,
    output [`N-1:0] Q
);
    reg        [`N*2-1:0]  rm_q_reg;    //余数-商寄存器
    reg        [`N-1:0]    B_reg;       //除数寄存器
    reg        [5:0]       state;       //状态机，初始化为34,1=输出,0=空闲
    wire       [`N-1:0]    rm_next;     //部分余数
    wire       [`N-1:0]    q_next;      //新的商
    
    
    //计算新的部分余数和商
    wire ge = $unsigned(rm_q_reg[`N*2-2:`N-1]) >= B_reg;
    assign rm_next = ge ? ($unsigned(rm_q_reg[`N*2-2:`N-1]) - B_reg) : rm_q_reg[`N*2-2:`N-1];
    assign q_next = {rm_q_reg[`N-2:0],ge};

    always @(posedge clk)begin
        if(!rst_n)
            B_reg<=0;
        else if(in_valid && in_ready)
            B_reg<=B; //初始化除数
    end
    always @(posedge clk)begin
        if(!rst_n)
            rm_q_reg<=0;
        else if(in_valid && in_ready)
            rm_q_reg<={{`N{1'b0}},A};        //初始化被除数(部分余数)
        else if(|state[5:1])                 //计数器在2-32时说明计算未完成
            rm_q_reg<={rm_next,q_next};      //更新rm_q寄存器
    end

    always @(posedge clk)begin
        if(!rst_n)
            state<=0;
        else if(in_valid && in_ready)
            state<=`N+1;                   //初始化被除数(部分余数)
        else if(|state)
            state<=state-1;                //计数器递减
    end

    assign in_ready = state == 0;
    assign out_valid = state == 1;
    assign {Rm,Q} = rm_q_reg;
endmodule
