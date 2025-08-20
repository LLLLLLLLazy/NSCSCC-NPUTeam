module v_bank_ram (
    input   wire  [ 7:0]    addra   ,
    input   wire            clka    ,
    input   wire  [31:0]    dina    ,
    output  wire  [31:0]    douta   ,
    input   wire  [ 3:0]    wea      
);

    wire ena = 1'b1;

    localparam V_STYLE = "block";
    localparam P_STYLE =    (V_STYLE == "ultra")        ? "uram" :
                            (V_STYLE == "distributed")  ? "select_ram" :
                            "block_ram";

    (*ram_style = V_STYLE*) reg [31:0] mem_reg [255:0]/*synthesis syn_ramstyle=P_STYLE*/;
    reg [31:0] output_buffer;

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
