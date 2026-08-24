module alu(
  input  wire clk,
  input  wire reset,
  input  wb_tlb_flush,
  input  wire mul_start,
  output wire mul_done,
  input  wire        inst_pcaddu12i,
  input  wire [29:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  input  wire [31:0] es_pc,  
  input  wire [31:0] imm,
  output wire [31:0] alu_result,
  output wire        es_br,
//  output wire        br_taken,
 // output wire [31:0] br_target,
  output wire br_mispred,     //����br_taken��λ�ã�Ч��һ�£���֧Ԥ��ʧ�ܴ���rob
  output wire [31:0] final_target,
  input wire pred_taken,
  input wire [31:0] pred_target,
  output wire exec_update_en,  //������ת��Ч
  output wire [31:0] pc_exec, //es_pc
  output wire [31:0] target_exec,//real_target
//  output wire [1:0] branch_type_exec, //br/j/jirl
  output wire br_taken
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_mul;  //multiplication
wire op_mulh; //
wire op_mulhu; //multiplication unsigned
wire op_jirl;
wire op_b;
wire op_bl;
wire op_beq;
wire op_bne;
wire op_blt;
wire op_bge;
wire op_bltu;
wire op_bgeu;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulhu= alu_op[14];

assign op_jirl = alu_op[19];
assign op_b    = alu_op[20];
assign op_bl   = alu_op[21];
assign op_beq  = alu_op[22];
assign op_bne  = alu_op[23];
assign op_blt  = alu_op[24];
assign op_bge  = alu_op[25];
assign op_bltu = alu_op[26];
assign op_bgeu = alu_op[27];
wire alu_orn  = alu_op[28];
wire alu_andn = alu_op[29];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [63:0] unsigned_prod;
wire [63:0] signed_prod;
wire [31:0] mul_result;
wire [31:0] mulu_result;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu |op_blt | op_bge | op_bltu |op_bgeu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu |op_blt | op_bge | op_bltu |op_bgeu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

//mul
//�з��ų˷��õ��Ľ���ǲ������?
assign unsigned_prod = alu_src1 * alu_src2;
assign signed_prod   = $signed(alu_src1) * $signed(alu_src2);
//assign mul_result    = op_mul ? signed_prod[31: 0] : signed_prod[63:32];
//assign mulu_result   = unsigned_prod[63:32];
// final result mux
wire [31:0] link_result = es_pc + 32'd4; // ���㷵�ص�ַ PC + 4

wire [31:0] orn_result  = alu_src1 | ~alu_src2;
wire [31:0] andn_result = alu_src1 & ~alu_src2;
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_mul       }} & mul_result)
                  | ({32{op_mulh|op_mulhu }} & mul_result)
                  | ({32{op_jirl|op_bl}} & link_result)
                  | ({32{inst_pcaddu12i}} & (es_pc+imm))
                  | ({32{alu_orn     }} & orn_result)
                  | ({32{alu_andn      }} & andn_result);
                  


 wire [31:0] jirl_offs;
 wire [31:0] br_offs;
 //��ת�����ж�

wire rj_eq_rd;
wire rj_le_rd_s;
wire rj_le_rd_u;
wire [31:0] br_target;
//��ת����
assign rj_eq_rd = (alu_src1 == alu_src2);
assign  rj_le_rd_s = (alu_src1[31]&~alu_src2[31]) | ((alu_src1[31]~^alu_src2[31])& adder_result[31]); 
assign  rj_le_rd_u = ~adder_cout;
assign es_br  = op_beq | op_bne | op_jirl | op_bl | op_b | op_blt | op_bge | op_bltu | op_bgeu;
 assign br_taken = (  op_beq  &&  rj_eq_rd
                   || op_bne  && !rj_eq_rd
                   || op_jirl
                   || op_bl
                   || op_b
                   || op_blt  && rj_le_rd_s
                   || op_bge  && !rj_le_rd_s
                   || op_bltu && rj_le_rd_u
                   || op_bgeu && !rj_le_rd_u
                ) ;       
assign jirl_offs = imm;    
assign br_offs   = imm;                     
assign br_target = (op_beq || op_bne || op_bl || op_b || op_blt || op_bge || op_bltu || op_bgeu) ? (es_pc + br_offs) :
                                                   /*inst_jirl*/ (alu_src1 + jirl_offs);
                                                  
assign final_target = br_taken ? br_target:es_pc+3'b100;
assign br_mispred = ((br_taken != pred_taken) || (pred_taken &(pred_target != final_target)));
assign exec_update_en = br_taken;
assign pc_exec = es_pc;
assign  target_exec = final_target;

wire [31:0] mul_num1;
wire [31:0] mul_num2;
wire [2:0] mul_op = alu_op[12] ? 3'b000 :
                    alu_op[13] ? 3'b100 :
                    3'b110;
assign mul_num1 = alu_src1;
assign mul_num2 = alu_src2;
mul u_mul(
  .clk(clk),
  .rst_n(reset),
  .flush(wb_tlb_flush),
  .start(mul_start),
  .mul_op(mul_op),
  .a(mul_num1),
  .b(mul_num2),
  .mul_result(mul_result),
  .mul_done(mul_done)
);
endmodule
