module tagv_sram
#( 
    parameter WIDTH = 21    ,
    parameter DEPTH = 256
)
( 
    input wire [ 7:0]          addra   ,
    input wire                 clka    ,
    input wire [20:0]          dina    ,
    output wire [20:0]          douta   ,
    input  wire                 ena     ,
    input  wire                 wea 
);

reg [20:0] mem_reg [255:0];
reg [20:0] output_buffer;

// Initialize memory and output buffer to zero
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1) begin
        mem_reg[i] = 21'b0;
    end
    output_buffer = 21'b0;
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
