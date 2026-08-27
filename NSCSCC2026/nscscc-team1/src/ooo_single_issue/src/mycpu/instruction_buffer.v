module instruction_buffer (
    input wire clk,
    input wire resetn,

    input wire [31:0] in_instruction,
    input wire        stall,

    output reg [31:0] out_instruction,
    output reg        sel
);

    always @(posedge clk) begin
        if (!resetn) begin
            sel <= 1'b0;
        end else if (stall) begin
            sel             <= 1'b1;
            out_instruction <= sel ? out_instruction : in_instruction;
        end else begin
            sel <= 1'b0;
        end
    end
endmodule
