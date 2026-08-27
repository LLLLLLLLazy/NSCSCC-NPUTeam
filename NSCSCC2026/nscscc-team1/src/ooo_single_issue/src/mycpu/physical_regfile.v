module physical_regfile (
        input clk,
        input resetn,

        input [5:0] raddr1,
        input [5:0] raddr2,
        input [5:0] raddr3,
        input [5:0] raddr4,
        input [5:0] raddr5,
        input [5:0] raddr6,
        input [5:0] raddr7,
        input [5:0] raddr8,
        input [5:0] raddr9,
        input [5:0] raddr10,
        input [5:0] raddr11,
        input [5:0] raddr12,

        input [ 5:0] waddr1,
        input        we1,
        input [31:0] wdata1,

        input [ 5:0] waddr2,
        input        we2,
        input [31:0] wdata2,

        input [ 5:0] waddr3,
        input        we3,
        input [31:0] wdata3,

        input [ 5:0] waddr4,
        input        we4,
        input [31:0] wdata4,

        input [ 5:0] waddr5,
        input        we5,
        input [31:0] wdata5,

        input [ 5:0] waddr6,
        input        we6,
        input [31:0] wdata6,


        input [ 5:0] waddr7,
        input        we7,
        input [31:0] wdata7,


        output [31:0] rdata1,
        output [31:0] rdata2,
        output [31:0] rdata3,
        output [31:0] rdata4,
        output [31:0] rdata5,
        output [31:0] rdata6,
        output [31:0] rdata7,
        output [31:0] rdata8,
        output [31:0] rdata9,
        output [31:0] rdata10,
        output [31:0] rdata11,
        output [31:0] rdata12
`ifdef difftest

        ,  input wire [6:0] rmt [31:0]

`endif

    );


`ifdef difftest


    DifftestGRegState u_difftest_GRegState (
                          .clock (clk),
                          .coreid(8'd0),
                          .gpr_0 ({32'd0, 32'b0}),
                          .gpr_1 ({32'd0, registers[rmt[1]]}),
                          .gpr_2 ({32'd0, registers[rmt[2]]}),
                          .gpr_3 ({32'd0, registers[rmt[3]]}),
                          .gpr_4 ({32'd0, registers[rmt[4]]}),
                          .gpr_5 ({32'd0, registers[rmt[5]]}),
                          .gpr_6 ({32'd0, registers[rmt[6]]}),
                          .gpr_7 ({32'd0, registers[rmt[7]]}),
                          .gpr_8 ({32'd0, registers[rmt[8]]}),
                          .gpr_9 ({32'd0, registers[rmt[9]]}),
                          .gpr_10({32'd0, registers[rmt[10]]}),
                          .gpr_11({32'd0, registers[rmt[11]]}),
                          .gpr_12({32'd0, registers[rmt[12]]}),
                          .gpr_13({32'd0, registers[rmt[13]]}),
                          .gpr_14({32'd0, registers[rmt[14]]}),
                          .gpr_15({32'd0, registers[rmt[15]]}),
                          .gpr_16({32'd0, registers[rmt[16]]}),
                          .gpr_17({32'd0, registers[rmt[17]]}),
                          .gpr_18({32'd0, registers[rmt[18]]}),
                          .gpr_19({32'd0, registers[rmt[19]]}),
                          .gpr_20({32'd0, registers[rmt[20]]}),
                          .gpr_21({32'd0, registers[rmt[21]]}),
                          .gpr_22({32'd0, registers[rmt[22]]}),
                          .gpr_23({32'd0, registers[rmt[23]]}),
                          .gpr_24({32'd0, registers[rmt[24]]}),
                          .gpr_25({32'd0, registers[rmt[25]]}),
                          .gpr_26({32'd0, registers[rmt[26]]}),
                          .gpr_27({32'd0, registers[rmt[27]]}),
                          .gpr_28({32'd0, registers[rmt[28]]}),
                          .gpr_29({32'd0, registers[rmt[29]]}),
                          .gpr_30({32'd0, registers[rmt[30]]}),
                          .gpr_31({32'd0, registers[rmt[31]]})
                      );

`endif



    genvar i;

    // A 12-read/7-write register file cannot be inferred as a normal FPGA
    // block RAM.  Make the intended implementation explicit so that the
    // synthesis tool does not spend effort attempting an unsuitable RAM
    // mapping before falling back to registers.
    (* ram_style = "registers" *) reg [31:0] registers[63:0];

    // always @(posedge clk) begin
    //     if (we1) registers[waddr1] <= wdata1;
    //     if (we2) registers[waddr2] <= wdata2;
    //     if (we3) registers[waddr3] <= wdata3;
    //     if (we4) registers[waddr4] <= wdata4;
    //     if (we5) registers[waddr5] <= wdata5;
    // end



    always @(posedge clk) begin
        if (!resetn)
            registers[0] <= 32'd0;
    end

    // Write addresses are guaranteed to be mutually exclusive.  Decode the
    // seven write ports in parallel and use a balanced OR tree for the data
    // path.  Keeping write_valid separate from the hit vector also avoids a
    // false combinational-loop warning caused by hit[i][0] depending on other
    // bits of hit[i].
    generate
        for (i = 1; i <= 63; i = i + 1) begin : gen_write_entry
            localparam [5:0] REG_INDEX = i;

            wire [6:0] write_hit;
            wire       write_valid;

            wire [31:0] write_data_12;
            wire [31:0] write_data_34;
            wire [31:0] write_data_56;
            wire [31:0] write_data_1234;
            wire [31:0] write_data_567;
            wire [31:0] selected_write_data;

            assign write_hit[0] = we1 && (waddr1 == REG_INDEX);
            assign write_hit[1] = we2 && (waddr2 == REG_INDEX);
            assign write_hit[2] = we3 && (waddr3 == REG_INDEX);
            assign write_hit[3] = we4 && (waddr4 == REG_INDEX);
            assign write_hit[4] = we5 && (waddr5 == REG_INDEX);
            assign write_hit[5] = we6 && (waddr6 == REG_INDEX);
            assign write_hit[6] = we7 && (waddr7 == REG_INDEX);

            assign write_valid = |write_hit;

            assign write_data_12 = ({32{write_hit[0]}} & wdata1) |
                                   ({32{write_hit[1]}} & wdata2);
            assign write_data_34 = ({32{write_hit[2]}} & wdata3) |
                                   ({32{write_hit[3]}} & wdata4);
            assign write_data_56 = ({32{write_hit[4]}} & wdata5) |
                                   ({32{write_hit[5]}} & wdata6);

            assign write_data_1234 = write_data_12 | write_data_34;
            assign write_data_567  = write_data_56 |
                                     ({32{write_hit[6]}} & wdata7);
            assign selected_write_data = write_data_1234 | write_data_567;

            always @(posedge clk) begin
                if (write_valid)
                    registers[i] <= selected_write_data;
            end
        end
    endgenerate

    assign rdata1  = registers[raddr1];
    assign rdata2  = registers[raddr2];
    assign rdata3  = registers[raddr3];
    assign rdata4  = registers[raddr4];
    assign rdata5  = registers[raddr5];
    assign rdata6  = registers[raddr6];
    assign rdata7  = registers[raddr7];
    assign rdata8  = registers[raddr8];
    assign rdata9  = registers[raddr9];
    assign rdata10 = registers[raddr10];
    assign rdata11 = registers[raddr11];
    assign rdata12 = registers[raddr12];


endmodule
