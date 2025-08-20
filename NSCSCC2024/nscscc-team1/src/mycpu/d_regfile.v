module  d_regfile(
    input   wire        clk,
    input   wire        resetn,
    //READ PORT 1
    input   wire [ 7:0] raddr1,
    output  wire        rdata1,
/*    //READ PORT 2
    input   wire [ 7:0] raddr2,
    output  wire        rdata2,*/
    //WRITE PORT
    input   wire        we,
    input   wire [ 7:0] waddr,
    input   wire        wdata
);
reg [255:0]  rf;

//WRTIE
always @(posedge clk) begin
    if (!resetn) begin
        rf <= 256'b0;
    end
    else if (we)   rf[waddr] <= wdata;
end

//READ OUT 1
assign rdata1 = rf[raddr1];

//READ OUT 2
//assign rdata2 = rf[raddr2];

endmodule