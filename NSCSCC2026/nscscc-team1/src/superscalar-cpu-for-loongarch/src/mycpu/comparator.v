`include "header.v"

module comparator(
    input [31:0] operand1,
    input [31:0] operand2,
    input [2:0] op,
    output reg compared_result
);

always @(*) begin
    case(op)
        `COMPARATOR_EQ : compared_result = operand1 == operand2;
        `COMPARATOR_NE : compared_result = operand1 != operand2;
        `COMPARATOR_LT : compared_result = $signed(operand1) < $signed(operand2);
        `COMPARATOR_GE : compared_result = $signed(operand1) >= $signed(operand2);
        `COMPARATOR_LTU : compared_result = operand1 < operand2;
        `COMPARATOR_GEU : compared_result = operand1 >= operand2;
        default : compared_result = 1'b0;
    endcase
end


endmodule