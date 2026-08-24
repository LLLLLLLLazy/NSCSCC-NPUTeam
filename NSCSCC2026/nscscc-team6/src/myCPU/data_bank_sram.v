module data_bank_sram
#(
    parameter WIDTH = 32    ,
    parameter DEPTH = 256   ,
    parameter ADDR_WIDTH = 8
)
(
    input  [ADDR_WIDTH-1:0] addra   ,
    input                   clka    ,
    input  [WIDTH-1:0]      dina    ,
    output [WIDTH-1:0]      douta   ,
    input                   ena     ,
    input  [3:0]            wea
);

reg [WIDTH-1:0] mem_reg [DEPTH-1:0];
reg [WIDTH-1:0] output_buffer;

always @(posedge clka) begin
    if (ena) begin
        if (wea) begin
            if (wea[0]) begin
                mem_reg[addra][ 7: 0] <= dina[ 7: 0];
            end

            if (wea[1]) begin
                mem_reg[addra][15: 8] <= dina[15: 8];
            end

            if (wea[2]) begin
                mem_reg[addra][23:16] <= dina[23:16];
            end

            if (wea[3]) begin
                mem_reg[addra][31:24] <= dina[31:24];
            end
        end
        else begin
            output_buffer <= mem_reg[addra];
        end
    end
end

assign douta = output_buffer;

endmodule
