// `timescale 1ns/1ps
// `default_nettype none

// 8-lane input / 4-lane output instruction FIFO.
//
// Fixed geometry matches the generated 102-bit x 16 BMG bank IP.  Eight
// interleaved banks provide four conflict-free consecutive read candidates.
// The BMG has one-cycle synchronous read latency; read_bank_r aligns each
// returned bank, while every physical bank corrects its own collision data.
module ins_fifo_8in4out #(
        parameter ENTRY_W = 102
    ) (
        input  wire                   clk,
        input  wire                   resetn,
        input  wire                   flush,

        output wire [7:0]             in_ready,
        input  wire [ENTRY_W-1:0]     in_data_0,
        input  wire [ENTRY_W-1:0]     in_data_1,
        input  wire [ENTRY_W-1:0]     in_data_2,
        input  wire [ENTRY_W-1:0]     in_data_3,
        input  wire [ENTRY_W-1:0]     in_data_4,
        input  wire [ENTRY_W-1:0]     in_data_5,
        input  wire [ENTRY_W-1:0]     in_data_6,
        input  wire [ENTRY_W-1:0]     in_data_7,
        input  wire [7:0]             in_valid_mask,
        input  wire [3:0]             in_valid_count,

        output wire [3:0]             out_valid,
        input  wire [3:0]             out_ready,
        output wire [2:0]             out_valid_count,
        output wire [ENTRY_W-1:0]     out_data_0,
        output wire [ENTRY_W-1:0]     out_data_1,
        output wire [ENTRY_W-1:0]     out_data_2,
        output wire [ENTRY_W-1:0]     out_data_3,

        output wire [7:0]             occupancy,
        output reg  [7:0]             res_count,
        output wire                   full,
        output wire                   empty
    );

    localparam integer FIFO_DEPTH = 128;
    localparam integer BANK_COUNT = 8;
    localparam integer BANK_DEPTH = 16;
    localparam integer BANK_ADDR_W = 4;
    localparam integer PTR_W = 8;
    localparam integer IN_CNT_W = 4;
    localparam integer OUT_NUM = 4;
    localparam integer OUT_CNT_W = 3;

    reg  [PTR_W-1:0]          head;
    reg  [PTR_W-1:0]          tail;
    reg  [2:0]                read_bank_r [3:0];

    wire                      push_req;
    wire                      push_fire;
    wire [IN_CNT_W-1:0]       push_count;

    wire [OUT_NUM-1:0]        out_fire;
    wire [OUT_CNT_W-1:0]      pop_count;
    wire [7:0]                push_count_u8;
    wire [7:0]                pop_count_u8;

    wire [PTR_W-1:0]          head_next;
    wire [PTR_W-1:0]          tail_next;

    wire [BANK_COUNT-1:0]     bank_we;
    wire [BANK_COUNT-1:0]     relative_mask;
    reg  [BANK_COUNT-1:0]     rotated_mask_case;
    wire [BANK_COUNT-1:0]     relative_ready;
    reg  [BANK_COUNT-1:0]     rotated_ready_case;
    reg  [BANK_ADDR_W-1:0]    bank_waddr [7:0];
    reg  [ENTRY_W-1:0]        bank_wdata [7:0];

    wire [PTR_W-1:0]          read_base;
    wire [PTR_W-1:0]          read_ptr [3:0];
    wire [2:0]                read_bank [3:0];
    wire [BANK_ADDR_W-1:0]    read_row [3:0];
    wire [2:0]                base_bank;
    wire [BANK_ADDR_W-1:0]    base_row;
    wire [BANK_ADDR_W-1:0]    bank_raddr [7:0];
    wire [ENTRY_W-1:0]        bank_dout [7:0];

    // The extra pointer bit distinguishes empty from full.  The subtraction
    // is an unsigned 8-bit modular difference and represents 0..128 in every
    // legal FIFO state.
    assign occupancy = tail - head;
    assign empty = (head == tail);
    assign full  = (head[6:0] == tail[6:0]) &&
                   (head[7]   != tail[7]);

    // Input acceptance uses only space available at the beginning of the
    // cycle.  A same-cycle pop cannot make a rejected input batch acceptable.
    // The externally visible per-bank ready mask is generated below without
    // depending on the current input count.
    assign push_req   = (in_valid_count != 4'd0);
    assign push_fire  = push_req && (res_count >= in_valid_count);
    assign push_count = push_fire ? in_valid_count : 4'd0;

    // out_valid_count is the current visible queue prefix, truncated to four.
    assign out_valid_count = (occupancy >= 8'd4)
                           ? 3'd4
                           : occupancy[2:0];

    // Accepted entries occupy one continuous logical interval [head, tail),
    // so the queue count fully determines the valid output prefix.
    assign out_valid[0] = (occupancy >= 8'd1);
    assign out_valid[1] = (occupancy >= 8'd2);
    assign out_valid[2] = (occupancy >= 8'd3);
    assign out_valid[3] = (occupancy >= 8'd4);

    // The per-lane handshake is the single source of truth for dequeue state.
    // Explicit zero extension keeps the four-input popcount three bits wide.
    assign out_fire = out_valid & out_ready;
    assign pop_count = {2'b0, out_fire[0]}
                     + {2'b0, out_fire[1]}
                     + {2'b0, out_fire[2]}
                     + {2'b0, out_fire[3]};

    assign push_count_u8 = {{(8-IN_CNT_W){1'b0}}, push_count};
    assign pop_count_u8  = {{(8-OUT_CNT_W){1'b0}}, pop_count};

    assign head_next = head + pop_count;
    assign tail_next = tail + push_count;

    // Four look-ahead candidates begin at the post-pop head.
    assign read_base   = head_next;
    assign read_ptr[0] = read_base;
    assign read_ptr[1] = read_base + 8'd1;
    assign read_ptr[2] = read_base + 8'd2;
    assign read_ptr[3] = read_base + 8'd3;

    assign read_bank[0] = read_ptr[0][2:0];
    assign read_bank[1] = read_ptr[1][2:0];
    assign read_bank[2] = read_ptr[2][2:0];
    assign read_bank[3] = read_ptr[3][2:0];

    assign read_row[0] = read_ptr[0][6:3];
    assign read_row[1] = read_ptr[1][6:3];
    assign read_row[2] = read_ptr[2][6:3];
    assign read_row[3] = read_ptr[3][6:3];

    assign base_bank = read_base[2:0];
    assign base_row  = read_base[6:3];

    // Every B port stays enabled inside its bank wrapper.  Banks below
    // base_bank have crossed bank7 and therefore read the following row;
    // four-bit arithmetic wraps row15.
    assign bank_raddr[0] = base_row + ((3'd0 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[1] = base_row + ((3'd1 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[2] = base_row + ((3'd2 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[3] = base_row + ((3'd3 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[4] = base_row + ((3'd4 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[5] = base_row + ((3'd5 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[6] = base_row + ((3'd6 < base_bank) ? 4'd1 : 4'd0);
    assign bank_raddr[7] = base_row + ((3'd7 < base_bank) ? 4'd1 : 4'd0);

    // Every bank_dout is already collision-corrected by its physical bank
    // wrapper.  read_bank_r selects the bank response aligned with each lane.
    assign out_data_0 = bank_dout[read_bank_r[0]];
    assign out_data_1 = bank_dout[read_bank_r[1]];
    assign out_data_2 = bank_dout[read_bank_r[2]];
    assign out_data_3 = bank_dout[read_bank_r[3]];

    // head and tail retain the baseline's shared update rule.
    always @(posedge clk) begin
        if (!resetn) begin
            head <= {PTR_W{1'b0}};
            tail <= {PTR_W{1'b0}};
        end
        else if (flush) begin
            head <= {PTR_W{1'b0}};
            tail <= {PTR_W{1'b0}};
        end
        else begin
            head <= head_next;
            tail <= tail_next;
        end
    end

    // Remaining space is independent externally visible state.
    always @(posedge clk) begin
        if (!resetn)
            res_count <= 8'd128;
        else if (flush)
            res_count <= 8'd128;
        else
            res_count <= res_count - push_count_u8 + pop_count_u8;
    end

    // Four bank tags align with the four BMG responses.
    always @(posedge clk) begin
        if (!resetn) begin
            read_bank_r[0] <= 3'd0;
            read_bank_r[1] <= 3'd0;
            read_bank_r[2] <= 3'd0;
            read_bank_r[3] <= 3'd0;
        end
        else if (flush) begin
            read_bank_r[0] <= 3'd0;
            read_bank_r[1] <= 3'd0;
            read_bank_r[2] <= 3'd0;
            read_bank_r[3] <= 3'd0;
        end
        else begin
            read_bank_r[0] <= read_bank[0];
            read_bank_r[1] <= read_bank[1];
            read_bank_r[2] <= read_bank[2];
            read_bank_r[3] <= read_bank[3];
        end
    end

    // The frozen input convention is low-to-high: lane0 is oldest and legal
    // masks are low-bit contiguous.
    assign relative_mask = in_valid_mask;

    // Baseline case implementation of the circular-left write-enable route.
    always @(*) begin
        case (tail[2:0])
            3'd0:
                rotated_mask_case = relative_mask;
            3'd1:
                rotated_mask_case = {relative_mask[6:0], relative_mask[7]};
            3'd2:
                rotated_mask_case = {relative_mask[5:0], relative_mask[7:6]};
            3'd3:
                rotated_mask_case = {relative_mask[4:0], relative_mask[7:5]};
            3'd4:
                rotated_mask_case = {relative_mask[3:0], relative_mask[7:4]};
            3'd5:
                rotated_mask_case = {relative_mask[2:0], relative_mask[7:3]};
            3'd6:
                rotated_mask_case = {relative_mask[1:0], relative_mask[7:2]};
            3'd7:
                rotated_mask_case = {relative_mask[0], relative_mask[7:1]};
            default:
                rotated_mask_case = {BANK_COUNT{1'b0}};
        endcase
    end

    // reset/flush gating is deliberately not added; this preserves the
    // baseline's physical-write/logical-invalidation behavior.
    assign bank_we = rotated_mask_case & {BANK_COUNT{push_fire}};

    // Baseline write address/data routing, preserved verbatim in structure.
    always @(*) begin
        bank_waddr[0] = tail[6:3];
        bank_waddr[1] = tail[6:3];
        bank_waddr[2] = tail[6:3];
        bank_waddr[3] = tail[6:3];
        bank_waddr[4] = tail[6:3];
        bank_waddr[5] = tail[6:3];
        bank_waddr[6] = tail[6:3];
        bank_waddr[7] = tail[6:3];

        bank_wdata[0] = {ENTRY_W{1'b0}};
        bank_wdata[1] = {ENTRY_W{1'b0}};
        bank_wdata[2] = {ENTRY_W{1'b0}};
        bank_wdata[3] = {ENTRY_W{1'b0}};
        bank_wdata[4] = {ENTRY_W{1'b0}};
        bank_wdata[5] = {ENTRY_W{1'b0}};
        bank_wdata[6] = {ENTRY_W{1'b0}};
        bank_wdata[7] = {ENTRY_W{1'b0}};

        case (tail[2:0])
            3'd0: begin
                bank_wdata[7] = in_data_7;
                bank_wdata[6] = in_data_6;
                bank_wdata[5] = in_data_5;
                bank_wdata[4] = in_data_4;
                bank_wdata[3] = in_data_3;
                bank_wdata[2] = in_data_2;
                bank_wdata[1] = in_data_1;
                bank_wdata[0] = in_data_0;
            end
            3'd1: begin
                bank_waddr[0] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_6;
                bank_wdata[6] = in_data_5;
                bank_wdata[5] = in_data_4;
                bank_wdata[4] = in_data_3;
                bank_wdata[3] = in_data_2;
                bank_wdata[2] = in_data_1;
                bank_wdata[1] = in_data_0;
                bank_wdata[0] = in_data_7;
            end
            3'd2: begin
                bank_waddr[0] = tail[6:3] + 4'd1;
                bank_waddr[1] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_5;
                bank_wdata[6] = in_data_4;
                bank_wdata[5] = in_data_3;
                bank_wdata[4] = in_data_2;
                bank_wdata[3] = in_data_1;
                bank_wdata[2] = in_data_0;
                bank_wdata[1] = in_data_7;
                bank_wdata[0] = in_data_6;
            end
            3'd3: begin
                bank_waddr[0] = tail[6:3] + 4'd1;
                bank_waddr[1] = tail[6:3] + 4'd1;
                bank_waddr[2] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_4;
                bank_wdata[6] = in_data_3;
                bank_wdata[5] = in_data_2;
                bank_wdata[4] = in_data_1;
                bank_wdata[3] = in_data_0;
                bank_wdata[2] = in_data_7;
                bank_wdata[1] = in_data_6;
                bank_wdata[0] = in_data_5;
            end
            3'd4: begin
                bank_waddr[0] = tail[6:3] + 4'd1;
                bank_waddr[1] = tail[6:3] + 4'd1;
                bank_waddr[2] = tail[6:3] + 4'd1;
                bank_waddr[3] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_3;
                bank_wdata[6] = in_data_2;
                bank_wdata[5] = in_data_1;
                bank_wdata[4] = in_data_0;
                bank_wdata[3] = in_data_7;
                bank_wdata[2] = in_data_6;
                bank_wdata[1] = in_data_5;
                bank_wdata[0] = in_data_4;
            end
            3'd5: begin
                bank_waddr[0] = tail[6:3] + 4'd1;
                bank_waddr[1] = tail[6:3] + 4'd1;
                bank_waddr[2] = tail[6:3] + 4'd1;
                bank_waddr[3] = tail[6:3] + 4'd1;
                bank_waddr[4] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_2;
                bank_wdata[6] = in_data_1;
                bank_wdata[5] = in_data_0;
                bank_wdata[4] = in_data_7;
                bank_wdata[3] = in_data_6;
                bank_wdata[2] = in_data_5;
                bank_wdata[1] = in_data_4;
                bank_wdata[0] = in_data_3;
            end
            3'd6: begin
                bank_waddr[0] = tail[6:3] + 4'd1;
                bank_waddr[1] = tail[6:3] + 4'd1;
                bank_waddr[2] = tail[6:3] + 4'd1;
                bank_waddr[3] = tail[6:3] + 4'd1;
                bank_waddr[4] = tail[6:3] + 4'd1;
                bank_waddr[5] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_1;
                bank_wdata[6] = in_data_0;
                bank_wdata[5] = in_data_7;
                bank_wdata[4] = in_data_6;
                bank_wdata[3] = in_data_5;
                bank_wdata[2] = in_data_4;
                bank_wdata[1] = in_data_3;
                bank_wdata[0] = in_data_2;
            end
            3'd7: begin
                bank_waddr[0] = tail[6:3] + 4'd1;
                bank_waddr[1] = tail[6:3] + 4'd1;
                bank_waddr[2] = tail[6:3] + 4'd1;
                bank_waddr[3] = tail[6:3] + 4'd1;
                bank_waddr[4] = tail[6:3] + 4'd1;
                bank_waddr[5] = tail[6:3] + 4'd1;
                bank_waddr[6] = tail[6:3] + 4'd1;

                bank_wdata[7] = in_data_0;
                bank_wdata[6] = in_data_7;
                bank_wdata[5] = in_data_6;
                bank_wdata[4] = in_data_5;
                bank_wdata[3] = in_data_4;
                bank_wdata[2] = in_data_3;
                bank_wdata[1] = in_data_2;
                bank_wdata[0] = in_data_1;
            end
            default: begin
                // Defaults above suppress writes through the X-safe mask path.
            end
        endcase
    end

    // res_count describes the continuous free interval beginning at tail.
    // First form readiness for the next eight relative write positions, then
    // rotate it into the frozen physical-bank bit ordering.
    assign relative_ready[0] = (res_count >= 8'd1);
    assign relative_ready[1] = (res_count >= 8'd2);
    assign relative_ready[2] = (res_count >= 8'd3);
    assign relative_ready[3] = (res_count >= 8'd4);
    assign relative_ready[4] = (res_count >= 8'd5);
    assign relative_ready[5] = (res_count >= 8'd6);
    assign relative_ready[6] = (res_count >= 8'd7);
    assign relative_ready[7] = (res_count >= 8'd8);

    always @(*) begin
        case (tail[2:0])
            3'd0:
                rotated_ready_case = relative_ready;
            3'd1:
                rotated_ready_case = {relative_ready[6:0], relative_ready[7]};
            3'd2:
                rotated_ready_case = {relative_ready[5:0], relative_ready[7:6]};
            3'd3:
                rotated_ready_case = {relative_ready[4:0], relative_ready[7:5]};
            3'd4:
                rotated_ready_case = {relative_ready[3:0], relative_ready[7:4]};
            3'd5:
                rotated_ready_case = {relative_ready[2:0], relative_ready[7:3]};
            3'd6:
                rotated_ready_case = {relative_ready[1:0], relative_ready[7:2]};
            3'd7:
                rotated_ready_case = {relative_ready[0], relative_ready[7:1]};
            default:
                rotated_ready_case = {BANK_COUNT{1'b0}};
        endcase
    end

    assign in_ready = rotated_ready_case;

    // One physical bank wrapper is instantiated eight times.  Each wrapper
    // contains the same generated 102x16 BMG and its local collision bypass.
    genvar bank_index;
    generate
        for (bank_index = 0;
             bank_index < BANK_COUNT;
             bank_index = bank_index + 1) begin : gen_bram_bank
            ins_fifo_bank u_bank (
                .clk   (clk),
                .we    (bank_we[bank_index]),
                .waddr (bank_waddr[bank_index]),
                .wdata (bank_wdata[bank_index]),
                .raddr (bank_raddr[bank_index]),
                .rdata (bank_dout[bank_index])
            );
        end
    endgenerate

endmodule

// Physical FIFO bank with deterministic same-address write forwarding.
// The BMG B port is permanently enabled in this FIFO, so the collision tag
// and write data can be sampled every cycle without an additional enable or
// reset/flush state.  FIFO pointer/count state suppresses all invalid output.
module ins_fifo_bank (
        input  wire         clk,
        input  wire         we,
        input  wire [3:0]   waddr,
        input  wire [101:0] wdata,
        input  wire [3:0]   raddr,
        output wire [101:0] rdata
    );

    wire [101:0] bram_rdata;
    wire         collision;
    reg          collision_q;
    reg  [101:0] bypass_data_q;

    assign collision = we && (waddr == raddr);

    ins_fifo_bank_bram u_bram (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (we),
        .addra (waddr),
        .dina  (wdata),
        .clkb  (clk),
        .enb   (1'b1),
        .addrb (raddr),
        .doutb (bram_rdata)
    );

    always @(posedge clk) begin
        collision_q   <= collision;
        bypass_data_q <= wdata;
    end

    assign rdata = collision_q ? bypass_data_q : bram_rdata;

endmodule
