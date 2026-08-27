`include "header.v"

/* verilator lint_off DECLFILENAME */
module id_rename_payload_bank #(
        parameter  WIDTH = `ID_OPCODE_LEN
    ) (
        input  wire         clka,
        input  wire         ena,
        input  wire [0:0]   wea,
        input  wire [0:0]   addra,
        input  wire [WIDTH - 1:0] dina,
        input  wire         clkb,
        input  wire         enb,
        input  wire [0:0]   addrb,
        output wire  [WIDTH - 1 :0] doutb
    );

    reg  [WIDTH - 1 :0] origin_doutb;
    // A bank contains only two payload entries.  Keeping it in local LUT/
    // register storage avoids a fixed RAMB36 placement and preserves the
    // original one-cycle synchronous read latency.
    (* ram_style = "distributed" *) reg [WIDTH - 1:0] mem [0:1];

    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;

        // All current instances tie clka and clkb to the same clock.  Fold
        // the write-first bypass into the synchronous read register so the
        // wide payload no longer needs conflict/p_doutb output muxing.
        if (enb) begin
            if (ena && wea[0] && (addra == addrb))
                origin_doutb <= dina;
            else
                origin_doutb <= mem[addrb];
        end
    end

    assign doutb = origin_doutb;



endmodule

module id_rename_pipeline_queue #(
        parameter integer ENTRY_WIDTH =  `ID_OPCODE_LEN
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire                   in_valid0,
        output wire                   in_ready0,
        input  wire [ENTRY_WIDTH-1:0] in_data0,
        input  wire                   in_is_b_jump0,
        input wire [31:0] in_target_b0,

        input  wire                   in_valid1,
        output wire                   in_ready1,
        input  wire [ENTRY_WIDTH-1:0] in_data1,
        input  wire                   in_is_b_jump1,
        input wire [31:0] in_target_b1,

        input  wire                   in_valid2,
        output wire                   in_ready2,
        input  wire [ENTRY_WIDTH-1:0] in_data2,
        input  wire                   in_is_b_jump2,
        input wire [31:0] in_target_b2,

        input  wire                   in_valid3,
        output wire                   in_ready3,
        input  wire [ENTRY_WIDTH-1:0] in_data3,
        input  wire                   in_is_b_jump3,
        input wire [31:0] in_target_b3,

        output wire                   out_valid0,
        input  wire                   out_ready0,
        output wire [ENTRY_WIDTH-1:0] out_data0,
        output wire [             4:0] out_bid0,

        output wire                   out_valid1,
        input  wire                   out_ready1,
        output wire [ENTRY_WIDTH-1:0] out_data1,
        output wire [             4:0] out_bid1,

        output wire                   out_valid2,
        input  wire                   out_ready2,
        output wire [ENTRY_WIDTH-1:0] out_data2,
        output wire [             4:0] out_bid2,

        output wire                   out_valid3,
        input  wire                   out_ready3,
        output wire [ENTRY_WIDTH-1:0] out_data3,
        output wire [             4:0] out_bid3,



        output wire                   rename_valid0,
        input  wire                   rename_success0,
        output wire [4:0]             rename_regfile_raddr1_0,
        output wire [4:0]             rename_regfile_raddr2_0,
        output wire [4:0]             rename_regfile_waddr_0,
        output wire                   rename_regfile_we_0,
        output wire                   rename_label0,
        output wire [4:0]             rename_bid0,
        input  wire [6:0]             rename_phy_reg_src1_0,
        input  wire [6:0]             rename_phy_reg_src2_0,
        input  wire [6:0]             rename_old_phy_reg_dst_0,
        input  wire [6:0]             rename_new_phy_reg_dst_0,

        output wire                   rename_valid1,
        input  wire                   rename_success1,
        output wire [4:0]             rename_regfile_raddr1_1,
        output wire [4:0]             rename_regfile_raddr2_1,
        output wire [4:0]             rename_regfile_waddr_1,
        output wire                   rename_regfile_we_1,
        output wire                   rename_label1,
        output wire [4:0]             rename_bid1,
        input  wire [6:0]             rename_phy_reg_src1_1,
        input  wire [6:0]             rename_phy_reg_src2_1,
        input  wire [6:0]             rename_old_phy_reg_dst_1,
        input  wire [6:0]             rename_new_phy_reg_dst_1,

        output wire                   rename_valid2,
        input  wire                   rename_success2,
        output wire [4:0]             rename_regfile_raddr1_2,
        output wire [4:0]             rename_regfile_raddr2_2,
        output wire [4:0]             rename_regfile_waddr_2,
        output wire                   rename_regfile_we_2,
        output wire                   rename_label2,
        output wire [4:0]             rename_bid2,
        input  wire [6:0]             rename_phy_reg_src1_2,
        input  wire [6:0]             rename_phy_reg_src2_2,
        input  wire [6:0]             rename_old_phy_reg_dst_2,
        input  wire [6:0]             rename_new_phy_reg_dst_2,

        output wire                   rename_valid3,
        input  wire                   rename_success3,
        output wire [4:0]             rename_regfile_raddr1_3,
        output wire [4:0]             rename_regfile_raddr2_3,
        output wire [4:0]             rename_regfile_waddr_3,
        output wire                   rename_regfile_we_3,
        output wire                   rename_label3,
        output wire [4:0]             rename_bid3,
        input  wire [6:0]             rename_phy_reg_src1_3,
        input  wire [6:0]             rename_phy_reg_src2_3,
        input  wire [6:0]             rename_old_phy_reg_dst_3,
        input  wire [6:0]             rename_new_phy_reg_dst_3,

        output wire [3:0] occupancy,
        output wire       full,
        output wire       empty,

        // Current tail ID and the write-port handshake of branch_id_allocator.
        input  wire                   branch_id_allocator_alloc_bid_ready,
        input  wire [             4:0] branch_id_allocator_alloc_bid,
        output wire                   branch_id_allocator_alloc_bid_valid,
        // Payload of the BRANCH/JIRL at which alloc_bid_valid is asserted.
        output wire [95:0] branch_id_allocator_alloc_data,

        // Decode-stage direct redirect.
        output reg b_flush_r,
        output reg [31:0] target_b_r,

        output wire [3:0] fire_in

    );


    // Bit 3 is the wrap bit; bits [2:0] address the eight physical entries.
    reg [3:0] head;
    reg [3:0] tail;

    wire [2:0] head0 = head[2:0];
    wire [2:0] head1 = head[2:0] + 3'd1;
    wire [2:0] head2 = head[2:0] + 3'd2;
    wire [2:0] head3 = head[2:0] + 3'd3;

    wire [2:0] tail0 = tail[2:0];
    wire [2:0] tail1 = tail[2:0] + 3'd1;
    wire [2:0] tail2 = tail[2:0] + 3'd2;
    wire [2:0] tail3 = tail[2:0] + 3'd3;

    wire [              3:0] in_valid;
    wire [              3:0] in_ready;
    wire [              3:0] in_is_b_jump;

    wire [              3:0] out_valid;
    wire [              3:0] out_ready;
    wire [4*ENTRY_WIDTH-1:0] out_data;
    wire [             19:0] out_bid;
    wire [3:0] rename_valid;
    wire [3:0] rename_success;

    wire [3:0] in_fire;
    wire [3:0] out_fire;
    wire [2:0] push_count;
    wire [2:0] pop_count;
    wire [3:0] free_count;

    assign fire_in = in_fire;

    assign in_valid     = {in_valid3, in_valid2, in_valid1, in_valid0};
    // The four redirect tags were appended to the original interface.  Treat
    // an omitted/unconnected tag as zero so legacy positional instantiations
    // remain deterministic in simulation.
    assign in_is_b_jump = {in_is_b_jump3,
                           in_is_b_jump2,
                           in_is_b_jump1,
                           in_is_b_jump0 };
    assign {in_ready3, in_ready2, in_ready1, in_ready0} = in_ready;
    assign {rename_valid3, rename_valid2, rename_valid1, rename_valid0} = rename_valid;
    assign rename_success = {rename_success3, rename_success2,
                             rename_success1, rename_success0};

    assign {out_valid3, out_valid2, out_valid1, out_valid0} = out_valid;
    assign out_ready = {out_ready3, out_ready2, out_ready1, out_ready0};
    assign {out_data3, out_data2, out_data1, out_data0} = out_data;
    assign {out_bid3, out_bid2, out_bid1, out_bid0} = out_bid;

    function [2:0] prefix_count;
        input [3:0] fire;
        begin
            prefix_count = {2'b0, fire[0]} +  {2'b0, fire[1]} + {2'b0, fire[2]} + {2'b0, fire[3]};
        end
    endfunction

    // Each bank stores entries whose physical slot is
    // {row, bank[1:0]}.  For a four-entry consecutive window starting at
    // base, the row bit for a given bank is the base row XOR the carry from
    // base[1:0] to that bank.  This avoids building four slots, sixteen
    // equality comparators and four masked-OR trees just to obtain one bit
    // of BRAM address.
    function [0:0] bank_row;
        input [2:0] base;
        input [1:0] bank;
        reg carry;
        begin
            case (base[1:0])
                2'd0:
                    carry = 1'b0;
                2'd1:
                    carry = (bank == 2'd0);
                2'd2:
                    carry = (bank <= 2'd1);
                2'd3:
                    carry = (bank <= 2'd2);
                default:
                    carry = 1'b0;
            endcase
            bank_row = base[2] ^ carry;
        end
    endfunction


    assign occupancy = tail - head;
    assign full = (head[2:0] == tail[2:0]) && (head[3] != tail[3]);
    assign empty = (head == tail);
    assign free_count = 4'd8 - occupancy;

    // Do not borrow current-cycle pop credits.  Once a direct redirect is
    // accepted, younger lanes are not accepted, so tail lands at jump+1.
    wire base_ready0 = (free_count >= 4'd1);
    wire base_ready1 = (free_count >= 4'd2);
    wire base_ready2 = (free_count >= 4'd3);
    wire base_ready3 = (free_count >= 4'd4);

    wire fire0 = in_valid[0] && base_ready0;
    wire fire1 = in_valid[1] && base_ready1 && !(in_is_b_jump[0]);
    wire fire2 = in_valid[2] && base_ready2 && !(|in_is_b_jump[1:0]);
    wire fire3 = in_valid[3] && base_ready3 && !(|in_is_b_jump[2:0]);

    assign in_ready[0] = base_ready0;
    assign in_ready[1] = base_ready1;
    assign in_ready[2] = base_ready2;
    assign in_ready[3] = base_ready3;

    wire [3:0] bias_in_fire;

    assign bias_in_fire = in_ready & in_valid;
    assign in_fire = {fire3, fire2, fire1, fire0};
    assign push_count = prefix_count(in_fire);

    wire b_flush;
    wire [31:0] target_b;

    assign b_flush = |(in_fire & in_is_b_jump);
    assign target_b = in_is_b_jump[0] ? in_target_b0 :
           in_is_b_jump[1] ? in_target_b1 :
           in_is_b_jump[2] ? in_target_b2 :
           in_is_b_jump[3] ? in_target_b3 : 32'd0;



    always @(posedge clk) begin
        if(!resetn||flush) begin
            b_flush_r <= 1'b0;
        end
        else begin
            b_flush_r <= b_flush;
        end

        target_b_r <= target_b;

    end

    // The current allocator tail is the BID of every instruction through the
    // first branch in the output window.  Do not expose younger instructions:
    // they must observe the allocator tail after that branch is accepted.
    wire branch_lane0 = (out_data0[90:89] == `SEL_NPC_BRANCH) || (out_data0[90:89] == `SEL_NPC_JIRL);
    wire branch_lane1 = (out_data1[90:89] == `SEL_NPC_BRANCH) || (out_data1[90:89] == `SEL_NPC_JIRL);
    wire branch_lane2 = (out_data2[90:89] == `SEL_NPC_BRANCH) || (out_data2[90:89] == `SEL_NPC_JIRL);
    wire branch_lane3 = (out_data3[90:89] == `SEL_NPC_BRANCH) || (out_data3[90:89] == `SEL_NPC_JIRL);

    assign out_valid = rename_success;


    assign rename_valid[0] = (occupancy >= 4'd1) && out_ready[0] && branch_id_allocator_alloc_bid_ready;
    assign rename_valid[1] = (occupancy >= 4'd2) && out_ready[1] && branch_id_allocator_alloc_bid_ready;
    assign rename_valid[2] = (occupancy >= 4'd3) && out_ready[2] && branch_id_allocator_alloc_bid_ready;
    assign rename_valid[3] = (occupancy >= 4'd4) && out_ready[3] && branch_id_allocator_alloc_bid_ready;


    assign rename_regfile_raddr1_0 = out_data0[106:102];
    assign rename_regfile_raddr2_0 = out_data0[101:97];
    assign rename_regfile_waddr_0 = out_data0[95:91];
    assign rename_regfile_we_0 = out_data0[96];
    assign rename_label0 = (out_data0[90:89] == `SEL_NPC_BRANCH) ||
           (out_data0[90:89] == `SEL_NPC_JIRL);
    assign rename_bid0 = branch_id_allocator_alloc_bid;

    assign rename_regfile_raddr1_1 = out_data1[106:102];
    assign rename_regfile_raddr2_1 = out_data1[101:97];
    assign rename_regfile_waddr_1 = out_data1[95:91];
    assign rename_regfile_we_1 = out_data1[96];
    assign rename_label1 = (out_data1[90:89] == `SEL_NPC_BRANCH) ||
           (out_data1[90:89] == `SEL_NPC_JIRL);
    assign rename_bid1 = branch_id_allocator_alloc_bid;

    assign rename_regfile_raddr1_2 = out_data2[106:102];
    assign rename_regfile_raddr2_2 = out_data2[101:97];
    assign rename_regfile_waddr_2 = out_data2[95:91];
    assign rename_regfile_we_2 = out_data2[96];
    assign rename_label2 = (out_data2[90:89] == `SEL_NPC_BRANCH) ||
           (out_data2[90:89] == `SEL_NPC_JIRL);
    assign rename_bid2 = branch_id_allocator_alloc_bid;

    assign rename_regfile_raddr1_3 = out_data3[106:102];
    assign rename_regfile_raddr2_3 = out_data3[101:97];
    assign rename_regfile_waddr_3 = out_data3[95:91];
    assign rename_regfile_we_3 = out_data3[96];
    assign rename_label3 = (out_data3[90:89] == `SEL_NPC_BRANCH) ||
           (out_data3[90:89] == `SEL_NPC_JIRL);
    assign rename_bid3 = branch_id_allocator_alloc_bid;




    assign out_fire = out_valid & out_ready;
    assign pop_count = prefix_count(out_fire);

    wire [3:0] next_head = head + {1'b0, pop_count};
    wire [2:0] entry_read_base = next_head[2:0];
    reg  [1:0] entry_read_bank_q;

    wire [ENTRY_WIDTH-1:0] entry_out_data[3:0];

    wire [3:0] bank_addrb;
    wire [3:0] bank_addra;
    wire [ENTRY_WIDTH-1:0] bank_doutb[3:0];
    wire [ENTRY_WIDTH-1:0] bank_dina[3:0];
    wire [3:0] bank_wea;


    assign bank_addrb[0] = bank_row(entry_read_base, 2'd0);
    assign bank_addrb[1] = bank_row(entry_read_base, 2'd1);
    assign bank_addrb[2] = bank_row(entry_read_base, 2'd2);
    assign bank_addrb[3] = bank_row(entry_read_base, 2'd3);

    assign bank_addra[0] = bank_row(tail[2:0], 2'd0);
    assign bank_addra[1] = bank_row(tail[2:0], 2'd1);
    assign bank_addra[2] = bank_row(tail[2:0], 2'd2);
    assign bank_addra[3] = bank_row(tail[2:0], 2'd3);


    pipeline_queue_shift #(.ENTRY(1))wea_pipeline_queue_shift(
                             .ptr(tail[1:0]),
                             .in_data0(bias_in_fire[0]),
                             .in_data1(bias_in_fire[1]),
                             .in_data2(bias_in_fire[2]),
                             .in_data3(bias_in_fire[3]),

                             .out_data0(bank_wea[0]),
                             .out_data1(bank_wea[1]),
                             .out_data2(bank_wea[2]),
                             .out_data3(bank_wea[3])
                         );


    pipeline_queue_shift #(.ENTRY(ENTRY_WIDTH))dina_pipeline_queue_shift(
                             .ptr(tail[1:0]),
                             .in_data0(in_data0),
                             .in_data1(in_data1),
                             .in_data2(in_data2),
                             .in_data3(in_data3),

                             .out_data0(bank_dina[0]),
                             .out_data1(bank_dina[1]),
                             .out_data2(bank_dina[2]),
                             .out_data3(bank_dina[3])
                         );



    pipeline_queue_unshift #(.ENTRY(ENTRY_WIDTH))doutb_pipeline_queue_unshift(
                               .ptr(head[1:0]),
                               .in_data0(bank_doutb[0]),
                               .in_data1(bank_doutb[1]),
                               .in_data2(bank_doutb[2]),
                               .in_data3(bank_doutb[3]),

                               .out_data0(entry_out_data[0]),
                               .out_data1(entry_out_data[1]),
                               .out_data2(entry_out_data[2]),
                               .out_data3(entry_out_data[3])
                           );


    genvar i;

    generate
        for(i=0;i<=3;i=i+1) begin : gen_id_rename_payload_bank
            id_rename_payload_bank u_id_rename_payload_bank(
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



    assign out_data = {entry_out_data[3], entry_out_data[2],
                       entry_out_data[1], entry_out_data[0]};
    assign out_bid = {4{branch_id_allocator_alloc_bid}};

    // Allocate only when the branch itself leaves the queue.  This keeps the
    // allocator tail, all visible BIDs and the downstream transfer atomic.
    wire branch_fire0 = branch_lane0 && out_fire[0];
    wire branch_fire1 = branch_lane1 && out_fire[1];
    wire branch_fire2 = branch_lane2 && out_fire[2];
    wire branch_fire3 = branch_lane3 && out_fire[3];
    wire [95:0] branch_entry_data =
         branch_lane0? {entry_out_data[0][170:139], entry_out_data[0][34:3], entry_out_data[0][76:45]}:
         branch_lane1? {entry_out_data[1][170:139], entry_out_data[1][34:3], entry_out_data[1][76:45]}:
         branch_lane2? {entry_out_data[2][170:139], entry_out_data[2][34:3], entry_out_data[2][76:45]}:
         branch_lane3? {entry_out_data[3][170:139], entry_out_data[3][34:3], entry_out_data[3][76:45]}: 96'd0;

    assign branch_id_allocator_alloc_bid_valid = branch_fire0 |
           branch_fire1 | branch_fire2 | branch_fire3;
    assign branch_id_allocator_alloc_data = branch_entry_data;


    always @(posedge clk) begin
        if (!resetn || flush) begin
            head <= 4'd0;
            tail <= 4'd0;
            entry_read_bank_q <= 2'd0;
        end
        else begin
            head <= head + {1'b0, pop_count};
            tail <= tail + {1'b0, push_count};
            entry_read_bank_q <= entry_read_base[1:0];
        end
    end

endmodule
