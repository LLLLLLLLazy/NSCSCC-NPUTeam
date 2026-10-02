`include "header.v"

module select_load(
    input wire [1:0] addr,
    input wire [31:0] data,
    input wire [2:0] sel_load_store_len,

    output reg [31:0] result
);

wire [7:0] data_31_24;
wire [7:0] data_23_16;
wire [7:0] data_15_8;
wire [7:0] data_7_0;


assign data_31_24 = data[31:24];
assign data_23_16 = data[23:16];
assign data_15_8 = data[15:8];
assign data_7_0 = data[7:0];

always @(*) begin
    case (sel_load_store_len)
        `SEL_LOAD_STORE_B : 
            result = addr == 2'b00 ? {{24{data_7_0[7]}},data_7_0} :
                     addr == 2'b01 ? {{24{data_15_8[7]}},data_15_8} :
                     addr == 2'b10 ? {{24{data_23_16[7]}},data_23_16} :
                     {{24{data_31_24[7]}},data_31_24};
        `SEL_LOAD_STORE_BU :
            result = addr == 2'b00 ? {24'b0,data_7_0} :
                     addr == 2'b01 ? {24'b0,data_15_8} :
                     addr == 2'b10 ? {24'b0,data_23_16} :
                     {24'b0,data_31_24};
        `SEL_LOAD_STORE_H :
            result = addr[1] == 1'b0 ? {{16{data_15_8[7]}}, data_15_8, data_7_0} : 
                                       {{16{data_31_24[7]}}, data_31_24, data_23_16}; 
        `SEL_LOAD_STORE_HU :
            result = addr[1] == 1'b0 ? {16'b0, data_15_8, data_7_0} : 
                                       {16'b0, data_31_24, data_23_16}; 
        default:  result = data;
    endcase
end




endmodule