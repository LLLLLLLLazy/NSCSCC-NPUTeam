module pc_reg(
    input clk ,
    input resetn ,

    input in_valid,
    input stall,
    output reg out_valid,

    input [31:0] npc,
    output reg [31:0] pc
);

always @(posedge clk) begin
    if(!resetn)
    begin
        pc <= 32'h1bfffffc;
        out_valid <= 1'b0;
    end
    else if(!stall && in_valid)
    begin
        out_valid <= in_valid;
        pc <= npc;
    end
end

endmodule