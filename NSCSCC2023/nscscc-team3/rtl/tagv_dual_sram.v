module tagv_dual_sram
    #(parameter DATA_WIDTH = 21,
    parameter ADDR_WIDTH = 8,
    parameter MEM_DEPTH = 256)
    (
    input   wire                        clka,
    input   wire                        wea,
    input   wire    [ADDR_WIDTH-1:0]    addra,
    input   wire    [DATA_WIDTH-1:0]    dina,
    input   wire                        clkb,
    input   wire    [ADDR_WIDTH-1:0]    addrb,
    output  wire    [DATA_WIDTH-1:0]    doutb
    );
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    reg [DATA_WIDTH-1:0]  data_out;
  
    integer i;
    initial for (i=0; i < MEM_DEPTH; i=i+1) mem[i] = 0;

    always @ (posedge clka)begin
        if (wea) begin
            mem[addra] <= dina; 
        end
    end
    reg [ADDR_WIDTH-1:0] addrb_reg;
    always @(posedge clkb) begin
        addrb_reg <= addrb;
    end
    assign doutb = mem[addrb_reg];
endmodule