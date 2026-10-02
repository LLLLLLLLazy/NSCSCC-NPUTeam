`include "header.v"

module alu (
        // input clk,
        // input resetn,

        // input stall,
        // input clear,
        // input valid,
        // input is_exception,

        input      [31:0] operand1,
        input      [31:0] operand2,
        input      [ 4:0] op,
        // output            multiply_divide_ready,
        output reg [31:0] result
    );

    // wire [63:0] signed_divider_result;
    // wire [63:0] signed_multiplier_result;
    // wire [63:0] unsigned_divider_result;
    // wire [63:0] unsigned_multiplier_result;




    always @(*) begin
        case (op)
            `ALU_SUB:
                result = operand1 - operand2;
            `ALU_LU12I:
                result = operand2;
            `ALU_SLT:
                result = $signed(operand1) < $signed(operand2);
            `ALU_SLTU:
                result = operand1 < operand2;
            `ALU_SLL:
                result = operand1 << operand2[4:0];
            `ALU_SRL:
                result = operand1 >> operand2[4:0];
            `ALU_SRA:
                result = $signed(operand1) >>> operand2[4:0];
            `ALU_AND:
                result = operand1 & operand2;
            `ALU_NOR:
                result = ~(operand1 | operand2);
            `ALU_OR:
                result = operand1 | operand2;
            `ALU_XOR:
                result = operand1 ^ operand2;
            `ALU_CPUCFG: begin
                case (operand1)
                    32'h1:
                        result = {12'd0, `CPUCFG_0x1_19_12, `CPUCFG_0x1_11_4, 1'b0, `CPUCFG_0x1_2, `CPUCFG_0x1_1_0};
                    32'h2:
                        result = `CPUCFG_0x2;
                    32'h10:
                        result = {`CPUCFG_0x10_31_7, `CPUCFG_0x10_6, `CPUCFG_0x10_5, `CPUCFG_0x10_4, `CPUCFG_0x10_3, `CPUCFG_0x10_2, `CPUCFG_0x10_1, `CPUCFG_0x10_0};
                    32'h11:
                        result = {`CPUCFG_0x11_31, `CPUCFG_0x11_30_24, `CPUCFG_0x11_23_16, `CPUCFG_0x11_15_0};
                    32'h12:
                        result = {`CPUCFG_0x12_31, `CPUCFG_0x12_30_24, `CPUCFG_0x12_23_16, `CPUCFG_0x12_15_0};
                    32'h13:
                        result = {`CPUCFG_0x13_31, `CPUCFG_0x13_30_24, `CPUCFG_0x13_23_16, `CPUCFG_0x13_15_0};
                    default:
                        result = 32'd0;

                endcase
            end
            default:
                result = operand1 + operand2;
        endcase
    end


    // wire       signed_divide_valid;
    // wire       unsigned_divide_valid;

    // wire       signed_divide_ready;
    // wire       unsigned_divide_ready;

    // reg  [5:0] signed_divide_counter;
    // reg  [5:0] unsigned_divide_counter;
    // reg  [5:0] signed_multiply_counter;
    // reg  [5:0] unsigned_multiply_counter;

    // wire       is_signed_divide;
    // wire       is_unsigned_divide;
    // wire       is_signed_multiply;
    // wire       is_unsigned_multiply;

    // assign signed_divide_valid   = 1'b1;

    // assign unsigned_divide_valid = 1'b1;

    // always @(posedge clk) begin
    //     if (!resetn) begin
    //         signed_divide_counter <= 6'b0;
    //     end else if (clear || !valid || !stall || is_exception) begin
    //         signed_divide_counter <= 6'b0;
    //     end else if (signed_divide_counter == `SIGNED_DIVIDE_DELAY) begin
    //         signed_divide_counter <= signed_divide_counter;
    //     end else if (is_signed_divide) begin
    //         signed_divide_counter <= signed_divide_counter + 1'b1;
    //     end
    // end

    // always @(posedge clk) begin
    //     if (!resetn) begin
    //         unsigned_divide_counter <= 6'b0;
    //     end else if (clear || !valid || !stall || is_exception) begin
    //         unsigned_divide_counter <= 6'b0;
    //     end else if (unsigned_divide_counter == `UNSIGNED_DIVIDE_DELAY) begin
    //         unsigned_divide_counter <= unsigned_divide_counter;
    //     end else if (is_unsigned_divide) begin
    //         unsigned_divide_counter <= unsigned_divide_counter + 1'b1;
    //     end
    // end





    // always @(posedge clk) begin
    //     if (!resetn) begin
    //         signed_multiply_counter <= 6'b0;
    //     end else if (clear || !valid || !stall || is_exception) begin
    //         signed_multiply_counter <= 6'b0;
    //     end else if (signed_multiply_counter == `SIGNED_MULTIPLY_DELAY) begin
    //         signed_multiply_counter <= signed_multiply_counter;
    //     end else if (is_signed_multiply) begin
    //         signed_multiply_counter <= signed_multiply_counter + 1'b1;
    //     end
    // end


    // always @(posedge clk) begin
    //     if (!resetn) begin
    //         unsigned_multiply_counter <= 6'b0;
    //     end else if (clear || !valid || !stall || is_exception) begin
    //         unsigned_multiply_counter <= 6'b0;
    //     end else if (unsigned_multiply_counter == `UNSIGNED_MULTIPLY_DELAY) begin
    //         unsigned_multiply_counter <= unsigned_multiply_counter;
    //     end else if (is_unsigned_multiply) begin
    //         unsigned_multiply_counter <= unsigned_multiply_counter + 1'b1;
    //     end
    // end


    // assign is_signed_divide = op == `ALU_DIV_W || op == `ALU_MOD_W;
    // assign is_unsigned_divide = op == `ALU_DIV_WU || op == `ALU_MOD_WU;
    // assign is_signed_multiply = op == `ALU_MUL_W || op == `ALU_MULH_W;
    // assign is_unsigned_multiply = op == `ALU_MULH_WU;


    // assign multiply_divide_ready = (!is_signed_divide || signed_divide_counter == `SIGNED_DIVIDE_DELAY) &&
    //                            (!is_unsigned_divide || unsigned_divide_counter == `UNSIGNED_DIVIDE_DELAY) &&
    //                            (!is_signed_multiply || signed_multiply_counter == `SIGNED_MULTIPLY_DELAY) &&
    //                            (!is_unsigned_multiply || unsigned_multiply_counter == `UNSIGNED_MULTIPLY_DELAY);


    // cpu_signed_divider u_cpu_signed_divider (
    //     .aclk                  (clk),                   // input wire aclk
    //     .s_axis_divisor_tvalid (signed_divide_valid),   // input wire s_axis_divisor_tvalid
    //     .s_axis_divisor_tdata  (operand2),              // input wire [31 : 0] s_axis_divisor_tdata
    //     .s_axis_dividend_tvalid(signed_divide_valid),   // input wire s_axis_dividend_tvalid
    //     .s_axis_dividend_tdata (operand1),              // input wire [31 : 0] s_axis_dividend_tdata
    //     .m_axis_dout_tvalid    (signed_divide_ready),   // output wire m_axis_dout_tvalid
    //     .m_axis_dout_tdata     (signed_divider_result)  // output wire [63 : 0] m_axis_dout_tdata
    // );

    // cpu_signed_multiplier u_cpu_signed_multiplier (
    //     .CLK(clk),                      // input wire CLK
    //     .A  (operand1),                 // input wire [31 : 0] A
    //     .B  (operand2),                 // input wire [31 : 0] B
    //     .P  (signed_multiplier_result)  // output wire [63 : 0] P
    // );

    // cpu_unsigned_divider u_cpu_unsigned_divider (
    //     .aclk                  (clk),                     // input wire aclk
    //     .s_axis_divisor_tvalid (unsigned_divide_valid),   // input wire s_axis_divisor_tvalid
    //     .s_axis_divisor_tdata  (operand2),                // input wire [31 : 0] s_axis_divisor_tdata
    //     .s_axis_dividend_tvalid(unsigned_divide_valid),   // input wire s_axis_dividend_tvalid
    //     .s_axis_dividend_tdata (operand1),                // input wire [31 : 0] s_axis_dividend_tdata
    //     .m_axis_dout_tvalid    (unsigned_divide_ready),   // output wire m_axis_dout_tvalid
    //     .m_axis_dout_tdata     (unsigned_divider_result)  // output wire [63 : 0] m_axis_dout_tdata
    // );

    // cpu_unsigned_multiplier u_cpu_unsigned_multiplier (
    //     .CLK(clk),                        // input wire CLK
    //     .A  (operand1),                   // input wire [31 : 0] A
    //     .B  (operand2),                   // input wire [31 : 0] B
    //     .P  (unsigned_multiplier_result)  // output wire [63 : 0] P
    // );

endmodule
