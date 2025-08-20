module DATA_BANK_RAM
#(
    parameter WIDTH = 32    ,
    parameter DEPTH = 256
)
(
    input  [ 7:0]          addra   ,
    input                  clka    ,
    input  [31:0]          dina    ,
    input  [ 7:0]          addrb   ,
    output [31:0]          doutb   ,
    input                  ena     ,
    input  [ 3:0]          wea      
);

reg [31:0] mem_reg [255:0];
reg [31:0] output_buffer;

wire rd_eq_wr = addra == addrb;

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
        output_buffer[7:0] <= (wea[0] && rd_eq_wr) ? dina[7:0] : mem_reg[addrb][7:0];
        output_buffer[15:8] <= (wea[1] && rd_eq_wr) ? dina[15:8] : mem_reg[addrb][15:8];
        output_buffer[23:16] <= (wea[2] && rd_eq_wr) ? dina[23:16] : mem_reg[addrb][23:16];
        output_buffer[31:24] <= (wea[3] && rd_eq_wr) ? dina[31:24] : mem_reg[addrb][31:24];
    end
end

assign doutb = output_buffer;

endmodule
