module pipeline_queue_shift #(
        parameter integer ENTRY = 211
    )(
        input wire [1:0] ptr,
        input wire [ENTRY-1 : 0] in_data0,
        input wire [ENTRY-1 : 0] in_data1,
        input wire [ENTRY-1 : 0] in_data2,
        input wire [ENTRY-1 : 0] in_data3,

        output wire [ENTRY-1 : 0] out_data0,
        output wire [ENTRY-1 : 0] out_data1,
        output wire [ENTRY-1 : 0] out_data2,
        output wire [ENTRY-1 : 0] out_data3
    );

    wire [ENTRY-1 : 0] in_data [3:0];
    reg [ENTRY-1 : 0] out_data [3:0];
    assign in_data[0] = in_data0;
    assign in_data[1] = in_data1;
    assign in_data[2] = in_data2;
    assign in_data[3] = in_data3;

    assign out_data0 = out_data[0];
    assign out_data1 = out_data[1];
    assign out_data2 = out_data[2];
    assign out_data3 = out_data[3];

    always @(*) begin
        case(ptr[1:0])
            2'b00 : begin
                out_data[0] = in_data[0];
                out_data[1] = in_data[1];
                out_data[2] = in_data[2];
                out_data[3] = in_data[3];
            end
            2'b01 : begin
                out_data[0] = in_data[3];
                out_data[1] = in_data[0];
                out_data[2] = in_data[1];
                out_data[3] = in_data[2];
            end
            2'b10 : begin
                out_data[0] = in_data[2];
                out_data[1] = in_data[3];
                out_data[2] = in_data[0];
                out_data[3] = in_data[1];
            end
            2'b11 : begin
                out_data[0] = in_data[1];
                out_data[1] = in_data[2];
                out_data[2] = in_data[3];
                out_data[3] = in_data[0];
            end
        endcase
    end
endmodule


module pipeline_queue_unshift #(
        parameter integer ENTRY = 211
    )(
        input wire [1:0] ptr,
        input wire [ENTRY-1 : 0] in_data0,
        input wire [ENTRY-1 : 0] in_data1,
        input wire [ENTRY-1 : 0] in_data2,
        input wire [ENTRY-1 : 0] in_data3,

        output wire [ENTRY-1 : 0] out_data0,
        output wire [ENTRY-1 : 0] out_data1,
        output wire [ENTRY-1 : 0] out_data2,
        output wire [ENTRY-1 : 0] out_data3
    );

    wire [ENTRY-1 : 0] in_data [3:0];
    reg [ENTRY-1 : 0] out_data [3:0];
    assign in_data[0] = in_data0;
    assign in_data[1] = in_data1;
    assign in_data[2] = in_data2;
    assign in_data[3] = in_data3;

    assign out_data0 = out_data[0];
    assign out_data1 = out_data[1];
    assign out_data2 = out_data[2];
    assign out_data3 = out_data[3];

    always @(*) begin
        case(ptr[1:0])
            2'b00 : begin
                out_data[0] = in_data[0];
                out_data[1] = in_data[1];
                out_data[2] = in_data[2];
                out_data[3] = in_data[3];
            end
            2'b01 : begin
                out_data[0] = in_data[1];
                out_data[1] = in_data[2];
                out_data[2] = in_data[3];
                out_data[3] = in_data[0];
            end
            2'b10 : begin
                out_data[0] = in_data[2];
                out_data[1] = in_data[3];
                out_data[2] = in_data[0];
                out_data[3] = in_data[1];
            end
            2'b11 : begin
                out_data[0] = in_data[3];
                out_data[1] = in_data[0];
                out_data[2] = in_data[1];
                out_data[3] = in_data[2];
            end
        endcase
    end
endmodule


