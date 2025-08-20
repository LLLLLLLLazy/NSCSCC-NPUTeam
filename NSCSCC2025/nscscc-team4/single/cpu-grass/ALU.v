`include "tools.v"

    //乘除法使能信号写法
    // assign div_en = (alu_op[15] | alu_op[16] | alu_op[17] | alu_op[18]) & EX1_valid;
    // assign mul_en = (alu_op[12] | alu_op[13] | alu_op[14]) & EX1_valid;
module ALU(
    input clk,
    input reset,
    input wire [18:0]  alu_op,
    input wire [31:0]  alu_src1,
    input wire [31:0]  alu_src2, 
    output wire [31:0] alu_result
);

wire op_add;    //加法操作
wire op_sub;    //减法操作
wire op_slt;    //有符号比较，小于置位
wire op_sltu;   //无符号比较，小于置位
wire op_and;    //按位与
wire op_nor;    //按位或非
wire op_or;     //按位或
wire op_xor;    //按位异或
wire op_sll;    //逻辑左移 
wire op_srl;    //逻辑右移
wire op_sra;    //算术右移
wire op_lui;    //高位加载

assign op_add  =alu_op[0];
assign op_sub  =alu_op[1];
assign op_slt  =alu_op[2];
assign op_sltu =alu_op[3];
assign op_and  =alu_op[4];
assign op_nor  =alu_op[5];
assign op_or   =alu_op[6];
assign op_xor  =alu_op[7];
assign op_sll  =alu_op[8];
assign op_srl  =alu_op[9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];


wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] sll_result;
wire [31:0] srl_result;
wire [31:0] sra_result;
wire [31:0] lui_result;




assign and_result = alu_src1 & alu_src2;
assign nor_result = ~(alu_src1 | alu_src2);
assign or_result = alu_src1 | alu_src2;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

//-----------第二部分----------------------

wire [31:0] adder_a;
wire [31:0] adder_b;
wire adder_cin;
wire [31:0] adder_result;
wire adder_cout;

assign adder_a = alu_src1;
assign adder_b = (op_slt | op_sltu | op_sub) ? ~alu_src2 : alu_src2;
assign adder_cin = (op_slt | op_sltu | op_sub) ? 1'b1 : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

assign add_sub_result = adder_result;


//-------第三部分------------

assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

assign sltu_result[31:1] = 31'b0;
assign sltu_result[0] = ~adder_cout;

assign sll_result = alu_src1 << alu_src2[4:0];
assign srl_result = alu_src1 >> alu_src2[4:0];
assign sra_result = ($signed(alu_src1)) >>> alu_src2[4:0];

// 结果赋值
assign alu_result=({32{op_add|op_sub}} & add_sub_result)
                | ({32{op_slt  }}&slt_result )
                | ({32{op_sltu }}&sltu_result)
                | ({32{op_and  }}&and_result )
                | ({32{op_nor  }}&nor_result )
                | ({32{op_or   }}&or_result  )
                | ({32{op_xor  }}&xor_result )
                | ({32{op_lui  }}&lui_result )
                | ({32{op_sll  }}&sll_result )
                | ({32{op_srl  }}&srl_result )
                | ({32{op_sra  }}&sra_result );


endmodule
