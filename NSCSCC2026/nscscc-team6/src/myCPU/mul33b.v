module csa(
    input x,
    input y,
    input z,
    output s,
    output c
);
    assign {c,s} = x+y+z;
endmodule

module wallace_17to2(
    input [16:0] a,
    input [13:0] cin,
    output [13:0] cout,
    output res_s,
    output res_c
);
    wire l1to2[8:4];
    wire l2to3[5:2];
    wire l3to4[5:4];
    wire l4to5[2:1];
    wire l5to6;
    csa l1_1(a[16],a[15],a[14],l1to2[8],cout[0]);
    csa l1_2(a[13],a[12],a[11],l1to2[7],cout[1]);
    csa l1_3(a[10],a[9], a[8], l1to2[6],cout[2]);
    csa l1_4(a[7], a[6], a[5], l1to2[5],cout[3]);
    csa l1_5(a[4], a[3], a[2], l1to2[4],cout[4]);
    csa l2_1(l1to2[8],l1to2[7],l1to2[6],l2to3[5],cout[5]);
    csa l2_2(l1to2[5],l1to2[4],a[1]    ,l2to3[4],cout[6]);
    csa l2_3(a[0],    cin[0],  cin[1]  ,l2to3[3],cout[7]);
    csa l2_4(cin[2],  cin[3],  cin[4]  ,l2to3[2],cout[8]);
    csa l3_1(l2to3[5],l2to3[4],l2to3[3],l3to4[5],cout[9]);
    csa l3_2(l2to3[2],cin[5],  cin[6]  ,l3to4[4],cout[10]);
    csa l4_1(l3to4[5],l3to4[4],cin[7]  ,l4to5[2],cout[11]);
    csa l4_2(cin[8],  cin[9],  cin[10] ,l4to5[1],cout[12]);
    csa l5_1(l4to5[2],l4to5[1],cin[11] ,l5to6,   cout[13]);
    csa l6_1(l5to6,   cin[12], cin[13] ,res_s,   res_c);
endmodule

/* 部分积生成器 */
module ppgen_booth2_33(
    input [2:0] y,
    input [65:0] x,
    output reg [65:0] pp,
    output rev  //对x取负，但只取了反并未+1
);
    wire [65:0] _2x;
    wire [65:0] x_rev;
    wire [65:0] _2x_rev;
    assign _2x = {x[64:0],1'b0};
    assign x_rev = ~x;
    assign _2x_rev = ~_2x;
    assign rev = y[2];
    always @(*)begin
        case(y)
        3'b000:pp=66'h0;
        3'b001:pp=x;
        3'b010:pp=x;
        3'b011:pp=_2x;
        3'b100:pp=_2x_rev;
        3'b101:pp=x_rev;
        3'b110:pp=x_rev;
        3'b111:pp=66'h3_ffff_ffff_ffff_ffff;
        endcase
    end
endmodule

/*3级流水33位有符号华莱士树乘法器*/
module mul33_3cycle(
    input clk,
    input signed [32:0] x,
    input signed [32:0] y,
    output signed [65:0] res
);
    wire signed [65:0] pp [16:0];
    wire [16:1] c;
    //生成部分积
    genvar i;
    generate for (i=1; i<=16; i=i+1) begin : ppgen_booth2_32
        ppgen_booth2_33 PPGEN(.y(y[(2*i):(2*i)-2]),.x({{(34-2*i){x[32]}},x,{(2*i-1){1'b0}}}),.pp(pp[i]),.rev(c[i]));
    end endgenerate
    assign pp[0] = y[0]? (-{{33{x[32]}},x}):(66'h0);
    //矩阵转置
    wire [16:0] pp_t [65:0];
    generate for (i=0; i<=65; i=i+1) begin : gen
        assign pp_t[i] = {pp[16][i],pp[15][i],pp[14][i],pp[13][i],
                          pp[12][i],pp[11][i],pp[10][i],pp[9][i],
                          pp[8][i] ,pp[7][i],pp[6][i],pp[5][i],
                          pp[4][i] ,pp[3][i],pp[2][i],pp[1][i],pp[0][i]};
    end endgenerate
    //加入一级流水
    reg [16:0] pp_t_reg [65:0];
    reg [16:1] c_reg;
    generate for (i=0; i<=65; i=i+1) begin : gen_pipe1
        always @(posedge clk)begin
            pp_t_reg[i] <= pp_t[i];
        end
    end endgenerate
    always @(posedge clk)begin
        c_reg <= c;
    end
    
    //华莱士树
    wire [66:0] carry;//最高位丢弃
    wire [65:0] sum;
    wire [13:0] ci [66:0];  //内部进位
    assign ci[0] = c_reg[14:1];
    generate for (i=0; i<=65; i=i+1) begin : wallace_17to2
        wallace_17to2 WALLACE(.a(pp_t_reg[i][16:0]),.cin(ci[i]),.cout(ci[i+1]),.res_c(carry[i+1]),.res_s(sum[i]));
    end endgenerate
    assign carry[0] = c_reg[15];
    wire final_cin = c_reg[16];


    //加入第二级流水
    reg [65:0]  carry_reg;
    reg [65:0]  sum_reg;
    reg         final_cin_reg;
    always @(posedge clk)begin
        carry_reg <= carry[65:0];
    end
    always @(posedge clk)begin
        sum_reg <= sum;
    end
    always @(posedge clk)begin
        final_cin_reg <= final_cin;
    end
    
    wire [65:0] final_result;
    wire        final_cout;
    assign {final_cout,final_result} = sum_reg + carry_reg + final_cin_reg;

    //加入第三级流水
    //? 如果非关键路径可不可以去掉
    /*
    reg [65:0] res_reg;
    always @(posedge clk)begin
        res_reg <= final_result;
    end*/
    assign res = final_result;
endmodule
