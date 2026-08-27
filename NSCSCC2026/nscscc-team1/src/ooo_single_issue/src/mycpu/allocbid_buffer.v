module allocbid_buffer (
    input wire clk,
    input wire resetn,

    input wire stall,

    input  wire       alloc_valid,
    input  wire [4:0] alloc_bid,
    output reg        alloc_already,
    output reg  [4:0] update_alloc_bid
);

    always @(posedge clk) begin
        if (!resetn || !stall) begin
            alloc_already <= 1'b0;
        end else if (stall && !alloc_already && alloc_valid) begin
            alloc_already    <= 1'b1;
            update_alloc_bid <= alloc_bid;
        end
    end

endmodule
