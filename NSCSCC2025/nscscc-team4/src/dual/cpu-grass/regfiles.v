module regfile(
    input  wire        clk,
    input  wire        reset,
    // READ PORT 1
    input  wire [ 4:0] raddr1,
    output wire [31:0] rdata1,
    // READ PORT 2
    input  wire [ 4:0] raddr2,
    output wire [31:0] rdata2,
    // READ PORT 3
    input  wire [ 4:0] raddr3,
    output wire [31:0] rdata3,
    // READ PORT 4
    input  wire [ 4:0] raddr4,
    output wire [31:0] rdata4,
    // WRITE PORT 1
    input  wire        we1,       //write enable, HIGH valid
    input  wire [ 4:0] waddr1,
    input  wire [31:0] wdata1,
    // WRITE PORT 2
    input wire         we2,
    input wire  [ 4:0] waddr2,
    input wire  [31:0] wdata2

    `ifdef DIFFTEST_EN
    ,
    output [31:0] rf_o [31:0]   // difftest
    `endif 
);
reg [31:0] rf[31:0];

integer i;

// WRITE
always @(posedge clk) begin
    if (reset) begin  // 复位时清零所有寄存器
        for (i = 0; i < 32; i = i + 1) begin
            rf[i] <= 32'b0;      // 寄存器清零
        end
    end
    else begin        // 正常写操作
        case({we1, we2})
            2'b11: begin          // 双写端口同时写入
                rf[waddr1] <= wdata1;
                rf[waddr2] <= wdata2;
            end
            2'b10: begin          // 仅写端口1有效
                rf[waddr1] <= wdata1;
            end
            2'b01: begin          // 仅写端口2有效
                rf[waddr2] <= wdata2;
            end
            // 2'b00: 无操作
        endcase
    end
end

// READ OUT 1
assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : rf[raddr1];

// READ OUT 2
assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : rf[raddr2];

// READ OUT 3
assign rdata3 = (raddr3 == 5'b0) ? 32'b0 : rf[raddr3];

// READ OUT 4
assign rdata4 = (raddr4 == 5'b0) ? 32'b0 : rf[raddr4];

// difftest
`ifdef DIFFTEST_EN
    assign rf_o = rf;
`endif

endmodule