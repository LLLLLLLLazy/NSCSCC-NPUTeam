module data_sram_we_gen (
    input  wire [ 3:0] data_sram_we,
    input  wire        is_st_b,
    input  wire        is_st_h,
    input  wire [31:0] ex_result,
    output reg  [ 3:0] temp_data_sram_wstrb
);

always @(*) begin
    if (data_sram_we == 4'b0) begin
        temp_data_sram_wstrb = 4'b0;
    end
    else if (is_st_b) begin
        case (ex_result[1:0])
            2'b00: temp_data_sram_wstrb = 4'b0001;
            2'b01: temp_data_sram_wstrb = 4'b0010;
            2'b10: temp_data_sram_wstrb = 4'b0100;
            2'b11: temp_data_sram_wstrb = 4'b1000;
            default: temp_data_sram_wstrb = 4'b0;
        endcase
    end
    else if (is_st_h) begin
        case (ex_result[1:0])
            2'b00: temp_data_sram_wstrb = 4'b0011;
            2'b10: temp_data_sram_wstrb = 4'b1100;
            default: temp_data_sram_wstrb = 4'b0;
        endcase
    end
    else begin
        temp_data_sram_wstrb = 4'b1111;
    end
end

endmodule
