module regfile(
    input  wire        clk,
    // READ PORT 1
    input  wire [ 4:0] rf_raddr1,
    output wire [31:0] rf_rdata1,
    // READ PORT 2
    input  wire [ 4:0] rf_raddr2,
    output wire [31:0] rf_rdata2,
    // WRITE PORT
    input  wire [ 3:0] rf_we,      
    input  wire [ 4:0] rf_waddr,
    input  wire [31:0] rf_wdata
    `ifdef DIFFTEST_EN
    ,
    output wire [1023:0] regs
    `endif
);

reg [31:0] rf[31:0];

//WRITE
always @(posedge clk) begin
    if (rf_we) rf[rf_waddr] <= rf_wdata;
end

// READ OUT 1
assign rf_rdata1 = (rf_raddr1 == 5'b0) ? 32'b0 : rf[rf_raddr1];

// READ OUT 2
assign rf_rdata2 = (rf_raddr2 == 5'b0) ? 32'b0 : rf[rf_raddr2];

`ifdef DIFFTEST_EN
assign regs = {
    rf[31], rf[30], rf[29], rf[28], rf[27], rf[26], rf[25], rf[24],
    rf[23], rf[22], rf[21], rf[20], rf[19], rf[18], rf[17], rf[16],
    rf[15], rf[14], rf[13], rf[12], rf[11], rf[10], rf[9],  rf[8],
    rf[7],  rf[6],  rf[5],  rf[4],  rf[3],  rf[2],  rf[1],  rf[0]
};
`endif

endmodule
