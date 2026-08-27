module ins_fifo_shift(
        input wire [31:0] pc,
        input wire [255:0] inst_sram_rdata,
        input wire [255:0] in_predict_target_address,

        output reg [255:0] out_inst_sram_rdata,
        output reg [7:0] out_valid_mask,
        output reg [3:0] out_valid_count,
        output reg [255:0] out_predict_target_address
    );

    always @(*) begin
        case(pc[4:2])
            3'd1 : begin
                out_inst_sram_rdata = {{1{32'd0}},inst_sram_rdata[255:32]};
                out_valid_count = 4'd7;
                out_valid_mask = 8'b0111_1111;
                out_predict_target_address = {{1{32'd0}},in_predict_target_address[255:32]};
            end

            3'd2 : begin
                out_inst_sram_rdata = {{2{32'd0}},inst_sram_rdata[255:64]};
                out_valid_count = 4'd6;
                out_valid_mask = 8'b0011_1111;
                out_predict_target_address = {{2{32'd0}},in_predict_target_address[255:64]};
            end

            3'd3 : begin
                out_inst_sram_rdata = {{3{32'd0}},inst_sram_rdata[255:96]};
                out_valid_count = 4'd5;
                out_valid_mask = 8'b0001_1111;
                out_predict_target_address = {{3{32'd0}},in_predict_target_address[255:96]};
            end

            3'd4 : begin
                out_inst_sram_rdata = {{4{32'd0}},inst_sram_rdata[255:128]};
                out_valid_count = 4'd4;
                out_valid_mask = 8'b0000_1111;
                out_predict_target_address = {{4{32'd0}},in_predict_target_address[255:128]};
            end

            3'd5 : begin
                out_inst_sram_rdata = {{5{32'd0}},inst_sram_rdata[255:160]};
                out_valid_count = 4'd3;
                out_valid_mask = 8'b0000_0111;
                out_predict_target_address = {{5{32'd0}},in_predict_target_address[255:160]};
            end

            3'd6 : begin
                out_inst_sram_rdata = {{6{32'd0}},inst_sram_rdata[255:192]};
                out_valid_count = 4'd2;
                out_valid_mask = 8'b0000_0011;
                out_predict_target_address = {{6{32'd0}},in_predict_target_address[255:192]};
            end

            3'd7 : begin
                out_inst_sram_rdata = {{7{32'd0}},inst_sram_rdata[255:224]};
                out_valid_count = 4'd1;
                out_valid_mask = 8'b0000_0001;
                out_predict_target_address = {{7{32'd0}},in_predict_target_address[255:224]};
            end

            default : begin
                out_inst_sram_rdata = inst_sram_rdata;
                out_valid_count = 4'd8;
                out_valid_mask = 8'b1111_1111;
                out_predict_target_address = in_predict_target_address;

            end


        endcase
    end







endmodule
