module get_wb_data_unit(
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_rdata,
    input  wire [31:0] ex_result,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] rj_value,
    
    input  wire [ 3:0] ld_width,
    input  wire        ld_ext_is_signed,
    input  wire [ 2:0] rf_wdata_sel,

    input  wire        llbit,

    output reg  [31:0] rf_wdata
);

reg  [7:0]  byte_sel;
reg [15:0]  half_sel;
reg [31:0]  r_data_sram_rdata;
reg [31:0]  cpucfg_info;
wire [31:0] sc_w_data = {31'b0, llbit};

always @* begin
    // select byte by addr[1:0]  -> small 4:1 mux
    case (data_sram_addr[1:0])
        2'b00: byte_sel = data_sram_rdata[7:0];
        2'b01: byte_sel = data_sram_rdata[15:8];
        2'b10: byte_sel = data_sram_rdata[23:16];
        2'b11: byte_sel = data_sram_rdata[31:24];
        default: byte_sel = data_sram_rdata[7:0];
    endcase

    // select halfword by addr[1] -> 2:1 mux
    case (data_sram_addr[1])
        1'b0: half_sel = data_sram_rdata[15:0];
        1'b1: half_sel = data_sram_rdata[31:16];
        default: half_sel = data_sram_rdata[15:0];
    endcase

    // expand/extend according to ld_width and ld_ext_is_signed
    case (ld_width)
        4'b1111: r_data_sram_rdata = data_sram_rdata;
        4'b0011: begin
            if (ld_ext_is_signed)
                r_data_sram_rdata = {{16{half_sel[15]}}, half_sel};
            else
                r_data_sram_rdata = {16'b0, half_sel};
        end
        4'b0001: begin
            if (ld_ext_is_signed)
                r_data_sram_rdata = {{24{byte_sel[7]}}, byte_sel};
            else
                r_data_sram_rdata = {24'b0, byte_sel};
        end
        default: r_data_sram_rdata = data_sram_rdata;
    endcase

    // cpucfg_info small mux on rj_value[7:0]
    case (rj_value[7:0])
        8'h01: cpucfg_info = 32'h0001f1f4;
        8'h10: cpucfg_info = 32'h00000005;
        8'h11: cpucfg_info = 32'h04080001;
        8'h12: cpucfg_info = 32'h04080001;
        default: cpucfg_info = 32'h0;
    endcase

    // output selection (small mux)
    case (rf_wdata_sel)
        3'b100: rf_wdata = cpucfg_info;
        3'b101: rf_wdata = sc_w_data;
        3'b001: rf_wdata = r_data_sram_rdata;
        3'b010: rf_wdata = pc_plus4;
        3'b000: rf_wdata = ex_result;
        default: rf_wdata = ex_result;
    endcase
end

endmodule
