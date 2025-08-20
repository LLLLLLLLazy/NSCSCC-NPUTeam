//Î»Ñ¡ÔñÆ÷
module mux2_bitwise#(parameter width = 32)(
    input [width - 1:0]       d0,
    input [width - 1:0]       d1,
    input [width - 1:0]       sel,
    output [width - 1:0]      out
);
    assign out = (d1 & sel) | (d0 & ~sel);
endmodule

//ÒëÂëÆ÷
module decoder#(parameter width = 2)(
    input  [width - 1:0] in,
    output [(1 << width) - 1:0] out
);
    genvar i;
    generate for (i = 0; i < (1 << width); i = i + 1) begin : gen
        assign out[i] = (in == i);
    end endgenerate
endmodule
