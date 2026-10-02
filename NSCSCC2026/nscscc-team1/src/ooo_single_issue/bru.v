`include "header.v"


module bru (
        input wire [31:0] pc,
        input wire [31:0] predict_target_address,
        input wire [31:0] imm,
        input wire [ 1:0] sel_npc,
        input wire [ 2:0] comparator_op,

        input wire [31:0] operand1,
        input wire [31:0] operand2,

        output wire [31:0] correct_target_address,
        output wire [31:0] writeback_result,
        output wire        is_jump,
        output wire compared_result
    );


    wire [31:0] comparator_operand1;
    wire [31:0] comparator_operand2;

    assign comparator_operand1 = operand1;
    assign comparator_operand2 = operand2;

    wire comparator_compared_result;
    assign compared_result = comparator_compared_result;

    comparator u_comparator (
                   .operand1       (comparator_operand1),
                   .operand2       (comparator_operand2),
                   .op             (comparator_op),
                   .compared_result(comparator_compared_result)
               );

    assign writeback_result = pc + 32'd4;

    assign correct_target_address = sel_npc == `SEL_NPC_JIRL ? operand1 + imm :
           sel_npc == `SEL_NPC_BRANCH && comparator_compared_result ? pc + imm :
           writeback_result;

    assign is_jump = correct_target_address != predict_target_address;



endmodule
