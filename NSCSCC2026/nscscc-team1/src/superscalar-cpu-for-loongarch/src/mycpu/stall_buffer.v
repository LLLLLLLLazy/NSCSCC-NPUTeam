module stall_buffer(
        input wire clk,
        input wire resetn,

        input wire [31:0] in_rdata,
        input wire data_ok,

        output reg [31:0] out_rdata
    );
    reg state;

    always @(posedge clk) begin
        if(!resetn)
            out_rdata <= 32'b0;
        else if(data_ok)
            out_rdata <= in_rdata;
    end



endmodule


module inst_stall_buffer(
        input wire clk,
        input wire resetn,

        input wire [255:0] in_rdata,
        input wire data_ok,

        output reg [255:0] out_rdata
    );
    reg state;

    always @(posedge clk) begin
        if(!resetn)
            out_rdata <= 256'b0;
        else if(data_ok)
            out_rdata <= in_rdata;
    end



endmodule
