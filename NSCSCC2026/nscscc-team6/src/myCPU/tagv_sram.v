module tagv_sram
#(
    parameter WIDTH = 21      ,
    parameter DEPTH = 256     ,
    parameter ADDR_WIDTH = 8
)
(
    input  wire [ADDR_WIDTH-1:0] addra   ,
    input  wire                  clka    ,
    input  wire [WIDTH-1:0]      dina    ,
    output wire [WIDTH-1:0]      douta   ,
    input  wire                  ena     ,
    input  wire                  wea
);

reg [WIDTH-1:0] mem_reg [DEPTH-1:0];
reg [WIDTH-1:0] output_buffer;

integer i;
initial begin
    for (i = 0; i < DEPTH; i = i + 1) begin
        mem_reg[i] = {WIDTH{1'b0}};
    end
    output_buffer = {WIDTH{1'b0}};
end

always @(posedge clka) begin
    if (ena) begin
        if (wea) begin
            mem_reg[addra] <= dina;
        end
        else begin
            output_buffer <= mem_reg[addra];
        end
    end
end

assign douta = output_buffer;

endmodule
