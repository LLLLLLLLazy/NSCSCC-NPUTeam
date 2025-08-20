module alu (
    input  wire [31:0] alu_src1,
    input  wire [31:0] alu_src2,
    input  wire [12:0] alu_op,
    output reg  [31:0] alu_result
);

// Control signals (kept for readability if needed)
wire op_add  = alu_op[0];
wire op_sub  = alu_op[1];
wire op_slt  = alu_op[2];
wire op_sltu = alu_op[3];
wire op_and  = alu_op[4];
wire op_nor  = alu_op[5];
wire op_or   = alu_op[6];
wire op_xor  = alu_op[7];
wire op_sll  = alu_op[8];
wire op_srl  = alu_op[9];
wire op_sra  = alu_op[10];
wire op_lui  = alu_op[11];
wire op_pcaddu12i = alu_op[12];

// Computation results (combinational)
wire [31:0] add_result   = alu_src1 + alu_src2;
wire [31:0] sub_result   = alu_src1 - alu_src2;
wire [31:0] slt_result   = ($signed(alu_src1) < $signed(alu_src2)) ? 32'd1 : 32'd0;
wire [31:0] sltu_result  = (alu_src1 < alu_src2) ? 32'd1 : 32'd0;
wire [31:0] and_result   = alu_src1 & alu_src2;
wire [31:0] nor_result   = ~(alu_src1 | alu_src2);
wire [31:0] or_result    = alu_src1 | alu_src2;
wire [31:0] xor_result   = alu_src1 ^ alu_src2;
wire [31:0] sll_result   = alu_src1 << alu_src2[4:0];
wire [31:0] srl_result   = alu_src1 >> alu_src2[4:0];
wire [31:0] sra_result   = $signed(alu_src1) >>> alu_src2[4:0];
wire [31:0] lui_result   = alu_src2;
wire [31:0] pcaddu12i    = add_result - 32'h00000004;

// One-hot op encodings as localparams (for clarity)
localparam [12:0] OP_ADD       = 13'b0000000000001;
localparam [12:0] OP_SUB       = 13'b0000000000010;
localparam [12:0] OP_SLT       = 13'b0000000000100;
localparam [12:0] OP_SLTU      = 13'b0000000001000;
localparam [12:0] OP_AND       = 13'b0000000010000;
localparam [12:0] OP_NOR       = 13'b0000000100000;
localparam [12:0] OP_OR        = 13'b0000001000000;
localparam [12:0] OP_XOR       = 13'b0000010000000;
localparam [12:0] OP_SLL       = 13'b0000100000000;
localparam [12:0] OP_SRL       = 13'b0001000000000;
localparam [12:0] OP_SRA       = 13'b0010000000000;
localparam [12:0] OP_LUI       = 13'b0100000000000;
localparam [12:0] OP_PCADDU12I = 13'b1000000000000;

always @* begin
    case (alu_op)
        OP_ADD:       alu_result = add_result;
        OP_SUB:       alu_result = sub_result;
        OP_SLT:       alu_result = slt_result;
        OP_SLTU:      alu_result = sltu_result;
        OP_AND:       alu_result = and_result;
        OP_NOR:       alu_result = nor_result;
        OP_OR:        alu_result = or_result;
        OP_XOR:       alu_result = xor_result;
        OP_SLL:       alu_result = sll_result;
        OP_SRL:       alu_result = srl_result;
        OP_SRA:       alu_result = sra_result;
        OP_LUI:       alu_result = lui_result;
        OP_PCADDU12I: alu_result = pcaddu12i;
        default:      alu_result = 32'b0; 
    endcase
end

endmodule



module addr_alu (
    input  wire        clk,
    input  wire        reset,
    input  wire        ex_flush,
    input  wire        ertn_flush,
    input  wire        refetch_flush,
    input  wire        stall,
    input  wire        id_fire,
    input  wire        id_valid,

    input  wire [31:0] alu_src1,
    input  wire [31:0] alu_src2,
    output reg  [31:0] alu_result,
    output reg         alu_finish
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        alu_finish <= 1'b0;
    end
    else if (stall) begin
        alu_finish <= 1'b0;
    end
    else if (id_fire) begin
        alu_finish <= 1'b0;
    end
    else begin
        alu_finish <= id_valid;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        alu_result <= 32'b0;
    end
    else begin
        alu_result <= alu_src1 + alu_src2;
    end
end

endmodule





