module regfile(
    input  wire        clk,
    input wire         rst,
    // READ PORT 1
    input  wire [ 4:0] raddr1,
    output wire [31:0] rdata1,
    // READ PORT 2
    input  wire [ 4:0] raddr2,
    output wire [31:0] rdata2,
    // WRITE PORT
    input  wire        we,       //write enable, HIGH valid
    input  wire [ 4:0] waddr,
    input  wire [31:0] wdata
    `ifdef DIFFTEST_EN
    ,
    output [31:0] rf_o [31:0]   // difftest
    `endif 
);
reg [31:0] rf[31:0];

    integer i;

//WRITE
always @(posedge clk) begin
    if(rst)
    begin
        for (i = 0; i < 32; i = i + 1) begin
            rf[i] = 32'b0;
        end
    end
    else if (we) 
    begin
    rf[waddr] <= wdata;
    end
end

//READ OUT 1
assign rdata1 = (raddr1==5'b0) ? 32'b0 : rf[raddr1];

//READ OUT 2
assign rdata2 = (raddr2==5'b0) ? 32'b0 : rf[raddr2];

// difftest
`ifdef DIFFTEST_EN
assign rf_o = rf;
`endif

endmodule