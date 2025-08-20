module booth4code(
    input      [33:0] a,
    input      [ 2:0] b,
    output reg [34:0] c
);

wire [33:0] a_rev = ~a + 1;

always @(*) begin
    case(b) 
        3'b000 : c =  0;
        3'b001, 
        3'b010 : c = { a[33], a };
        3'b011 : c = { a, 1'b0 };
        3'b100 : c = ~{ a, 1'b0 } + 1;
        3'b101,
        3'b110 : c = { a_rev[33], a_rev };
        3'b111 : c =  0;
        default: c =  0;
    endcase 
end

endmodule

// a + b + c + d + cin = sum + 2 * (carry + cout)
module compressor42 #(parameter DATA_WIDTH = 70)
(
  input  [DATA_WIDTH - 1 : 0]  a,
  input  [DATA_WIDTH - 1 : 0]  b,
  input  [DATA_WIDTH - 1 : 0]  c,
  input  [DATA_WIDTH - 1 : 0]  d,
  input                        cin,
  output [DATA_WIDTH - 1 : 0]  sum,
  output [DATA_WIDTH - 1 : 0]  carry,
  output                       cout
);
  
  wire [DATA_WIDTH - 1 : 0] s_temp, cin_arry, cout_arry;
  
  assign s_temp    = a ^ b ^ c;
  assign cout_arry = (a ^ b) & c | a & b;
  assign cin_arry  = {cout_arry[DATA_WIDTH - 2 : 0], cin};
  
  assign sum   = s_temp ^ d ^ cin_arry;
  assign carry = (s_temp ^ d) & cin_arry | s_temp & d;
  assign cout  = cout_arry[DATA_WIDTH - 1];  
 
endmodule


module mul(
    input  [31:0] a_in,
    input  [31:0] b_in,
    input         is_signed,
    output [31:0] c_low,
    output [31:0] c_high
);

genvar i;

wire [69:0] c;
wire [33:0] a;
wire [33:0] b;
wire [34:0] booth_o[16:0];
wire [69:0] pp[16:0]; 

// 34 位扩展
assign a = is_signed ? {{2{a_in[31]}}, a_in} : {2'b0, a_in};
assign b = is_signed ? {{2{b_in[31]}}, b_in} : {2'b0, b_in};

// Booth 编码实例化
booth4code u_booth4code_0(a, {b[1:0], 1'b0}, booth_o[0]);
generate
    for (i = 1; i < 16; i = i + 1) begin : booth_inst
        booth4code u_booth4code_i (
            .a(a),
            .b(b[2*i+1 : 2*i-1]),
            .c(booth_o[i])
        );
    end
endgenerate
booth4code u_booth4code_16(a, b[33:31], booth_o[16]);

// 部分积生成
generate
    for (i = 0; i < 17; i = i + 1) begin : pp_assign
        assign pp[i] = { {(69 - 2*i - 34){booth_o[i][34]}}, booth_o[i], {2*i{1'b0}} };
    end
endgenerate

// 压缩树
// 第一层：17 -> 9
wire [69:0] s1_0, c1_0, s1_1, c1_1, s1_2, c1_2, s1_3, c1_3, s1_4, c1_4;
wire        cout1_0, cout1_1, cout1_2, cout1_3, cout1_4;

compressor42 comp1_0(pp[0], pp[1], pp[2], pp[3], 1'b0, s1_0, c1_0, cout1_0);
compressor42 comp1_1(pp[4], pp[5], pp[6], pp[7], 1'b0, s1_1, c1_1, cout1_1);
compressor42 comp1_2(pp[8], pp[9], pp[10], pp[11], 1'b0, s1_2, c1_2, cout1_2);
compressor42 comp1_3(pp[12], pp[13], pp[14], pp[15], 1'b0, s1_3, c1_3, cout1_3);
compressor42 comp1_4(pp[16], 70'd0, 70'd0, 70'd0, 1'b0, s1_4, c1_4, cout1_4);

// 第二层：9 -> 5
wire [69:0] s2_0, c2_0, s2_1, c2_1, s2_2, c2_2;
wire        cout2_0, cout2_1, cout2_2;

compressor42 comp2_0(s1_0, c1_0 << 1, s1_1, c1_1 << 1, 1'b0, s2_0, c2_0, cout2_0);
compressor42 comp2_1(s1_2, c1_2 << 1, s1_3, c1_3 << 1, 1'b0, s2_1, c2_1, cout2_1);
compressor42 comp2_2(s1_4, c1_4 << 1, 70'd0, 70'd0, 1'b0, s2_2, c2_2, cout2_2);

// 第三层：5 -> 3
wire [69:0] s3_0, c3_0, s3_1, c3_1;
wire        cout3_0, cout3_1;

compressor42 comp3_0(s2_0, c2_0 << 1, s2_1, c2_1 << 1, 1'b0, s3_0, c3_0, cout3_0);
compressor42 comp3_1(s2_2, c2_2 << 1, 70'd0, 70'd0, 1'b0, s3_1, c3_1, cout3_1);

// 第四层：3 -> 2
wire [69:0] s4_0, c4_0;
wire        cout4_0;

compressor42 comp4_0(s3_0, c3_0 << 1, s3_1, c3_1 << 1, 1'b0, s4_0, c4_0, cout4_0);

// 最终结果
assign c = s4_0 + (c4_0 << 1);
assign c_low  = c[31:0];
assign c_high = c[63:32]; 

endmodule
