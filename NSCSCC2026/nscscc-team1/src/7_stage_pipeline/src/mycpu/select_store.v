`include "header.v"

module select_store(
    input wire [1:0] addr,
    input wire [31:0] data,
    input wire [2:0] sel_load_store_len,
    input wire we,


    output reg [3:0] modified_we,
    output reg [31:0] result
);

always @(*) begin
    case(sel_load_store_len)
        `SEL_LOAD_STORE_B : result = {4{data[7:0]}};
        `SEL_LOAD_STORE_H : result = {2{data[15:0]}};
        default : result = data;
    endcase
end

always @(*) begin
    if(we)
    begin
        case (sel_load_store_len)
            `SEL_LOAD_STORE_B : 
                modified_we = addr == 2'b00 ? 4'b0001 :
                          addr == 2'b01 ? 4'b0010 :
                          addr == 2'b10 ? 4'b0100 :
                          4'b1000;
            `SEL_LOAD_STORE_H :
                modified_we = addr[1] == 1'b0 ? 4'b0011 : 4'b1100;
            default: modified_we = 4'b1111;
        endcase
    end
    else
        modified_we = 4'b0000;
end


endmodule