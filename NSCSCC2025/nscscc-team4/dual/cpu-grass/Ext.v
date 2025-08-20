module Ext(
    input      [11:0] sign_imm_12,
    input      [11:0] unsign_imm_12,
    input      [ 4:0] unsign_imm_5,
    input      [19:0] sign_imm_20,
    input      [13:0] sign_imm_14,
    input      [ 4:0] extend_op,
    output reg [31:0] extend_res
);

    wire [31:0] ext_sign_imm_12;
    wire [31:0] ext_unsign_imm_5;
    wire [31:0] ext_sign_imm_20;
    wire [31:0] ext_unsign_imm_12;
    wire [31:0] ext_sign_imm_14;

    assign ext_sign_imm_12   = {{20{sign_imm_12[11]}}, sign_imm_12};
    assign ext_unsign_imm_5  = {{27'b0}, unsign_imm_5};
    assign ext_sign_imm_20   = {sign_imm_20, {12'b0}};
    assign ext_unsign_imm_12 = {{20'b0}, unsign_imm_12};
    assign ext_sign_imm_14   = {{16{sign_imm_14[13]}}, sign_imm_14, 2'b0};

    always@(*) begin
        case(extend_op) 
            5'b00001: extend_res = ext_sign_imm_12;
            5'b00010: extend_res = ext_unsign_imm_5;
            5'b00100: extend_res = ext_sign_imm_20;
            5'b01000: extend_res = ext_unsign_imm_12;
            5'b10000: extend_res = ext_sign_imm_14;
            default: extend_res = 32'b0;
        endcase
    end

endmodule