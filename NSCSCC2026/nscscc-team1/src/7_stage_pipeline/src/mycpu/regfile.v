module regfile (
    input clk,
    input resetn,

    input [ 4:0] raddr1,
    input [ 4:0] raddr2,
    input [ 4:0] raddr3,
    input [ 4:0] waddr,
    input        we,
    input [31:0] wdata,

    output [31:0] rdata1,
    output [31:0] rdata2,
    output [31:0] rdata3

    // output [31:0] gpr_dump [31:0]
);

    reg [31:0] registers[31:0];

    always @(posedge clk) begin
        if (we) registers[waddr] <= wdata;
    end

    assign rdata1 = raddr1 == 5'd0 ? 32'b0 : registers[raddr1];
    assign rdata2 = raddr2 == 5'd0 ? 32'b0 : registers[raddr2];
    assign rdata3 = raddr3 == 5'd0 ? 32'b0 : registers[raddr3];

    // genvar i;
    // generate
    //     for (i = 0; i < 32; i = i + 1) begin : gen_gpr_dump
    //         assign gpr_dump[i] = registers[i];
    //     end
    // endgenerate

`ifdef difftest


    DifftestGRegState u_difftest_GRegState (
        .clock (clk),
        .coreid(8'd0),
        .gpr_0 ({32'd0, 32'b0}),
        .gpr_1 ({32'd0, registers[1]}),
        .gpr_2 ({32'd0, registers[2]}),
        .gpr_3 ({32'd0, registers[3]}),
        .gpr_4 ({32'd0, registers[4]}),
        .gpr_5 ({32'd0, registers[5]}),
        .gpr_6 ({32'd0, registers[6]}),
        .gpr_7 ({32'd0, registers[7]}),
        .gpr_8 ({32'd0, registers[8]}),
        .gpr_9 ({32'd0, registers[9]}),
        .gpr_10({32'd0, registers[10]}),
        .gpr_11({32'd0, registers[11]}),
        .gpr_12({32'd0, registers[12]}),
        .gpr_13({32'd0, registers[13]}),
        .gpr_14({32'd0, registers[14]}),
        .gpr_15({32'd0, registers[15]}),
        .gpr_16({32'd0, registers[16]}),
        .gpr_17({32'd0, registers[17]}),
        .gpr_18({32'd0, registers[18]}),
        .gpr_19({32'd0, registers[19]}),
        .gpr_20({32'd0, registers[20]}),
        .gpr_21({32'd0, registers[21]}),
        .gpr_22({32'd0, registers[22]}),
        .gpr_23({32'd0, registers[23]}),
        .gpr_24({32'd0, registers[24]}),
        .gpr_25({32'd0, registers[25]}),
        .gpr_26({32'd0, registers[26]}),
        .gpr_27({32'd0, registers[27]}),
        .gpr_28({32'd0, registers[28]}),
        .gpr_29({32'd0, registers[29]}),
        .gpr_30({32'd0, registers[30]}),
        .gpr_31({32'd0, registers[31]})
    );

`endif


endmodule
