module if_insfifo_reg (
        input wire clk,
        input wire resetn,

        input wire in_valid,
        input wire stall,
        input wire pre_stall,


        input wire [31:0] in_pc,
        input wire [31:0] in_pc_pa,
        input wire [31:0] in_predict_target_address,

        output reg out_valid,

        output reg [31:0] out_pc,
        output reg [31:0] out_pc_pa,
        output reg [31:0] out_predict_target_address
    );


    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 1'b0;
        end
        else if (!stall) begin
            out_valid <= in_valid && !pre_stall;
            out_pc    <= in_pc;
            out_pc_pa <= in_pc_pa;
            out_predict_target_address <= in_predict_target_address;
        end

    end

endmodule
