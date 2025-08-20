`include "header.v"
module alu(
    output[31:0] c,
    input [31:0] a,
    input [31:0] b,
    input [31:0] mdu_prod,
    input [`WIDTH_ALUOP - 1:0] aluop
);
    
    wire [31:0] res_add_sub;
    wire [31:0] res_lt;
    wire [31:0] res_ltu;
    wire [31:0] res_nor;
    wire [31:0] res_and;
    wire [31:0] res_or;
    wire [31:0] res_xor;
    wire [31:0] res_sll;
    wire [31:0] res_srl;
    wire [31:0] res_sra;
    wire [31:0] res_direct_b;
    wire [31:0] res_mdm;

    //加法器，计算加减法
    wire [31:0] adder_oprand_b;
    wire adder_oprand_cin;
    assign adder_oprand_b = aluop[0]? b : ~b;
    assign adder_oprand_cin = ~aluop[0];
    assign res_add_sub = a + adder_oprand_b + adder_oprand_cin;

    assign res_lt = $signed(a) < $signed(b) ? 32'h1:32'h0;
    assign res_ltu = $unsigned(a) < $unsigned(b) ? 32'h1:32'h0;
    assign res_nor = ~(a|b);
    assign res_and = a & b;
    assign res_or =  a | b;
    assign res_xor = a ^ b;
    assign res_sll = (a << b[4:0]);
    assign res_srl = (a >> b[4:0]);
    assign res_sra = ($signed(a) >>> b[4:0]);
    assign res_direct_b = b;
    assign res_mdm = mdu_prod;
    assign c = ({32{aluop[0]|aluop[1]}} & res_add_sub)
              |({32{aluop[2]}} & res_lt)
              |({32{aluop[3]}} & res_ltu)
              |({32{aluop[4]}} & res_nor)
              |({32{aluop[5]}} & res_and)
              |({32{aluop[6]}} & res_or)
              |({32{aluop[7]}} & res_xor)
              |({32{aluop[8]}} & res_sll)
              |({32{aluop[9]}} & res_srl)
              |({32{aluop[10]}} & res_sra)
              |({32{aluop[11]}} & res_direct_b)
              |({32{aluop[12]}} & res_mdm);
endmodule
