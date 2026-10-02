module ext (
    input  [31:0] instruction,
    input  [ 1:0] simm,
    output [31:0] extended_imm,
    output [31:0] offset16,
    output [31:0] offset26
);

    wire [31:0] imm[3:0];

    assign imm[0]       = {20'b0, instruction[21:10]};
    assign imm[1]       = {{20{instruction[21]}}, instruction[21:10]};
    assign imm[2]       = {{14{instruction[25]}}, instruction[25:10], 2'b00};
    assign imm[3]       = {{4{instruction[9]}}, instruction[9:0], instruction[25:10], 2'b00};

    assign extended_imm = imm[simm];

    assign offset26     = imm[3];
    assign offset16     = imm[2];



endmodule
