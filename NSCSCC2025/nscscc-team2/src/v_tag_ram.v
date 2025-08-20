module v_tag_ram ( 
    input  wire  [ 7:0]     addra   ,
    input  wire             clka    ,
    input  wire  [19:0]     dina    ,
    output wire  [19:0]     douta   ,
    input  wire             wea 
);

    wire ena = 1'b1;

    localparam V_STYLE = "block";
    localparam P_STYLE =    (V_STYLE == "ultra")        ? "uram" :
                            (V_STYLE == "distributed")  ? "select_ram" :
                            "block_ram";

    (*ram_style = V_STYLE*) reg [19:0] mem_reg [255:0]/*synthesis syn_ramstyle=P_STYLE*/;
    reg [19:0] output_buffer;

    always @(posedge clka) begin
        if (ena) begin
            if (wea) begin
                mem_reg[addra] <= dina;
            end
            else begin
                output_buffer <= mem_reg[addra];
            end
        end
    end

    assign douta = output_buffer;

endmodule