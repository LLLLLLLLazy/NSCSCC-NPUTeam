module Counter(
    input           clk,
    input           reset,
    output [63:0]   counter_value,
    output [ 2:0]   rand_index
);

reg [63:0] counter_value_r;

always @(posedge clk ) begin
    if (reset) begin
        counter_value_r <= 64'h0;
    end else  begin
        counter_value_r <= counter_value_r + 64'h1;
    end
end

assign counter_value = counter_value_r;
assign rand_index = counter_value_r[2:0];

endmodule
