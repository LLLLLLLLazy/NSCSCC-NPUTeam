`include "header.v"

/* verilator lint_off DECLFILENAME */
module rename_dispatch_payload_bank #(
        parameter integer WIDTH = `RENAME_OPCODE_LEN + 5 + 4 * 7
    ) (
        input  wire                 clka,
        input  wire                 ena,
        input  wire [0:0]           wea,
        input  wire [0:0]           addra,
        input  wire [WIDTH-1:0]     dina,
        input  wire                 clkb,
        input  wire                 enb,
        input  wire [0:0]           addrb,
        output wire [WIDTH-1:0]     doutb
    );

    wire [WIDTH-1:0] origin_doutb;
    reg  [WIDTH-1:0] p_doutb;
    reg              conflict;

    rename_dispatch_payload_bram u_rename_dispatch_payload_bram (
        .clka(clka),
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(dina),
        .clkb(clkb),
        .enb(enb),
        .addrb(addrb),
        .doutb(origin_doutb)
    );

    always @(posedge clka) begin
        conflict <= ena && wea && enb && (addra == addrb);
        p_doutb <= dina;
    end

    assign doutb = conflict ? p_doutb : origin_doutb;

endmodule
/* verilator lint_on DECLFILENAME */

module rename_dispatch_pipeline_queue #(
        parameter integer ENTRY_WIDTH = `RENAME_OPCODE_LEN
    ) (
        input wire clk,
        input wire resetn,

        input wire flush,

        input  wire                   in_valid0,
        output wire                   in_ready0,
        input  wire [ENTRY_WIDTH-1:0] in_data0,
        input  wire [4:0]             in_bid0,
        input  wire [6:0]             in_phy_reg_src1_0,
        input  wire [6:0]             in_phy_reg_src2_0,
        input  wire [6:0]             in_old_phy_reg_dst_0,
        input  wire [6:0]             in_new_phy_reg_dst_0,

        input  wire                   in_valid1,
        output wire                   in_ready1,
        input  wire [ENTRY_WIDTH-1:0] in_data1,
        input  wire [4:0]             in_bid1,
        input  wire [6:0]             in_phy_reg_src1_1,
        input  wire [6:0]             in_phy_reg_src2_1,
        input  wire [6:0]             in_old_phy_reg_dst_1,
        input  wire [6:0]             in_new_phy_reg_dst_1,

        input  wire                   in_valid2,
        output wire                   in_ready2,
        input  wire [ENTRY_WIDTH-1:0] in_data2,
        input  wire [4:0]             in_bid2,
        input  wire [6:0]             in_phy_reg_src1_2,
        input  wire [6:0]             in_phy_reg_src2_2,
        input  wire [6:0]             in_old_phy_reg_dst_2,
        input  wire [6:0]             in_new_phy_reg_dst_2,

        input  wire                   in_valid3,
        output wire                   in_ready3,
        input  wire [ENTRY_WIDTH-1:0] in_data3,
        input  wire [4:0]             in_bid3,
        input  wire [6:0]             in_phy_reg_src1_3,
        input  wire [6:0]             in_phy_reg_src2_3,
        input  wire [6:0]             in_old_phy_reg_dst_3,
        input  wire [6:0]             in_new_phy_reg_dst_3,

        output wire                   out_valid0,
        input  wire                   out_ready0,
        output wire [ENTRY_WIDTH-1:0] out_data0,
        output wire [4:0]             out_bid0,
        output wire [6:0]             out_phy_reg_src1_0,
        output wire [6:0]             out_phy_reg_src2_0,
        output wire [6:0]             out_old_phy_reg_dst_0,
        output wire [6:0]             out_new_phy_reg_dst_0,

        output wire                   out_valid1,
        input  wire                   out_ready1,
        output wire [ENTRY_WIDTH-1:0] out_data1,
        output wire [4:0]             out_bid1,
        output wire [6:0]             out_phy_reg_src1_1,
        output wire [6:0]             out_phy_reg_src2_1,
        output wire [6:0]             out_old_phy_reg_dst_1,
        output wire [6:0]             out_new_phy_reg_dst_1,

        output wire                   out_valid2,
        input  wire                   out_ready2,
        output wire [ENTRY_WIDTH-1:0] out_data2,
        output wire [4:0]             out_bid2,
        output wire [6:0]             out_phy_reg_src1_2,
        output wire [6:0]             out_phy_reg_src2_2,
        output wire [6:0]             out_old_phy_reg_dst_2,
        output wire [6:0]             out_new_phy_reg_dst_2,

        output wire                   out_valid3,
        input  wire                   out_ready3,
        output wire [ENTRY_WIDTH-1:0] out_data3,
        output wire [4:0]             out_bid3,
        output wire [6:0]             out_phy_reg_src1_3,
        output wire [6:0]             out_phy_reg_src2_3,
        output wire [6:0]             out_old_phy_reg_dst_3,
        output wire [6:0]             out_new_phy_reg_dst_3,

        output wire [3:0]             occupancy,
        output wire                   full,
        output wire                   empty
    );

    localparam integer PAYLOAD_WIDTH = ENTRY_WIDTH + 5 + 4 * 7;

    reg [3:0] head;
    reg [3:0] tail;

    wire [3:0] in_valid;
    wire [3:0] in_ready;
    wire [3:0] in_fire;
    wire [3:0] out_valid;
    wire [3:0] out_ready;
    wire [3:0] out_fire;

    wire [2:0] push_count;
    wire [2:0] pop_count;
    wire [3:0] free_count;

    wire [PAYLOAD_WIDTH-1:0] in_payload [3:0];
    wire [PAYLOAD_WIDTH-1:0] out_payload [3:0];
    wire [PAYLOAD_WIDTH-1:0] bank_dina [3:0];
    wire [PAYLOAD_WIDTH-1:0] bank_doutb [3:0];
    wire [3:0] bank_wea;
    wire [3:0] bank_addra;
    wire [3:0] bank_addrb;

    assign in_valid = {in_valid3, in_valid2, in_valid1, in_valid0};
    assign {in_ready3, in_ready2, in_ready1, in_ready0} = in_ready;
    assign {out_valid3, out_valid2, out_valid1, out_valid0} = out_valid;
    assign out_ready = {out_ready3, out_ready2, out_ready1, out_ready0};

    function [2:0] prefix_count;
        input [3:0] fire;
        begin
            prefix_count = {2'b0, fire[0]} + {2'b0, fire[1]} +
                           {2'b0, fire[2]} + {2'b0, fire[3]};
        end
    endfunction

    function [0:0] bank_row;
        input [2:0] base;
        input [1:0] bank;
        reg carry;
        begin
            case (base[1:0])
                2'd0: carry = 1'b0;
                2'd1: carry = (bank == 2'd0);
                2'd2: carry = (bank <= 2'd1);
                2'd3: carry = (bank <= 2'd2);
                default: carry = 1'b0;
            endcase
            bank_row = base[2] ^ carry;
        end
    endfunction

    assign occupancy = tail - head;
    assign full = (head[2:0] == tail[2:0]) && (head[3] != tail[3]);
    assign empty = (head == tail);
    assign free_count = 4'd8 - occupancy;

    assign in_ready[0] = (free_count >= 4'd1);
    assign in_ready[1] = (free_count >= 4'd2);
    assign in_ready[2] = (free_count >= 4'd3);
    assign in_ready[3] = (free_count >= 4'd4);
    assign in_fire = in_valid & in_ready;
    assign push_count = prefix_count(in_fire);

    assign out_valid[0] = (occupancy >= 4'd1);
    assign out_valid[1] = (occupancy >= 4'd2);
    assign out_valid[2] = (occupancy >= 4'd3);
    assign out_valid[3] = (occupancy >= 4'd4);
    assign out_fire = out_valid & out_ready;
    assign pop_count = prefix_count(out_fire);

    wire [3:0] next_head = head + {1'b0, pop_count};
    wire [2:0] read_base = next_head[2:0];

    assign in_payload[0] = {
               in_data0, in_bid0, in_phy_reg_src1_0, in_phy_reg_src2_0,
               in_old_phy_reg_dst_0, in_new_phy_reg_dst_0
           };
    assign in_payload[1] = {
               in_data1, in_bid1, in_phy_reg_src1_1, in_phy_reg_src2_1,
               in_old_phy_reg_dst_1, in_new_phy_reg_dst_1
           };
    assign in_payload[2] = {
               in_data2, in_bid2, in_phy_reg_src1_2, in_phy_reg_src2_2,
               in_old_phy_reg_dst_2, in_new_phy_reg_dst_2
           };
    assign in_payload[3] = {
               in_data3, in_bid3, in_phy_reg_src1_3, in_phy_reg_src2_3,
               in_old_phy_reg_dst_3, in_new_phy_reg_dst_3
           };

    assign bank_addra[0] = bank_row(tail[2:0], 2'd0);
    assign bank_addra[1] = bank_row(tail[2:0], 2'd1);
    assign bank_addra[2] = bank_row(tail[2:0], 2'd2);
    assign bank_addra[3] = bank_row(tail[2:0], 2'd3);

    assign bank_addrb[0] = bank_row(read_base, 2'd0);
    assign bank_addrb[1] = bank_row(read_base, 2'd1);
    assign bank_addrb[2] = bank_row(read_base, 2'd2);
    assign bank_addrb[3] = bank_row(read_base, 2'd3);

    pipeline_queue_shift #(.ENTRY(1)) u_wea_pipeline_queue_shift (
        .ptr(tail[1:0]),
        .in_data0(in_fire[0]),
        .in_data1(in_fire[1]),
        .in_data2(in_fire[2]),
        .in_data3(in_fire[3]),
        .out_data0(bank_wea[0]),
        .out_data1(bank_wea[1]),
        .out_data2(bank_wea[2]),
        .out_data3(bank_wea[3])
    );

    pipeline_queue_shift #(.ENTRY(PAYLOAD_WIDTH)) u_dina_pipeline_queue_shift (
        .ptr(tail[1:0]),
        .in_data0(in_payload[0]),
        .in_data1(in_payload[1]),
        .in_data2(in_payload[2]),
        .in_data3(in_payload[3]),
        .out_data0(bank_dina[0]),
        .out_data1(bank_dina[1]),
        .out_data2(bank_dina[2]),
        .out_data3(bank_dina[3])
    );

    pipeline_queue_unshift #(.ENTRY(PAYLOAD_WIDTH)) u_doutb_pipeline_queue_unshift (
        .ptr(head[1:0]),
        .in_data0(bank_doutb[0]),
        .in_data1(bank_doutb[1]),
        .in_data2(bank_doutb[2]),
        .in_data3(bank_doutb[3]),
        .out_data0(out_payload[0]),
        .out_data1(out_payload[1]),
        .out_data2(out_payload[2]),
        .out_data3(out_payload[3])
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_rename_dispatch_payload_bank
            rename_dispatch_payload_bank #(.WIDTH(PAYLOAD_WIDTH))
            u_rename_dispatch_payload_bank (
                .clka(clk),
                .ena(1'b1),
                .wea(bank_wea[i]),
                .addra(bank_addra[i]),
                .dina(bank_dina[i]),
                .clkb(clk),
                .enb(1'b1),
                .addrb(bank_addrb[i]),
                .doutb(bank_doutb[i])
            );
        end
    endgenerate

    assign {
               out_data0, out_bid0, out_phy_reg_src1_0, out_phy_reg_src2_0,
               out_old_phy_reg_dst_0, out_new_phy_reg_dst_0
           } = out_payload[0];
    assign {
               out_data1, out_bid1, out_phy_reg_src1_1, out_phy_reg_src2_1,
               out_old_phy_reg_dst_1, out_new_phy_reg_dst_1
           } = out_payload[1];
    assign {
               out_data2, out_bid2, out_phy_reg_src1_2, out_phy_reg_src2_2,
               out_old_phy_reg_dst_2, out_new_phy_reg_dst_2
           } = out_payload[2];
    assign {
               out_data3, out_bid3, out_phy_reg_src1_3, out_phy_reg_src2_3,
               out_old_phy_reg_dst_3, out_new_phy_reg_dst_3
           } = out_payload[3];

    always @(posedge clk) begin
        if (!resetn || flush) begin
            head <= 4'd0;
            tail <= 4'd0;
        end
        else begin
            head <= head + {1'b0, pop_count};
            tail <= tail + {1'b0, push_count};
        end
    end

endmodule
