`include "header.v"

/* verilator lint_off DECLFILENAME */
module cam_rmt_checkpoint_bram (
        input wire         clk,
        input wire         write_enable,
        input wire [  4:0] write_addr,
        input wire [223:0] write_data,
        input wire         read_enable,
        input wire [  4:0] read_addr,
        output reg [223:0] read_data
    );

    // A checkpoint is 32 architectural mappings of seven bits each.  The
    // synchronous read is intentional: ram_style="block" must not silently
    // fall back to distributed RAM because of an asynchronous output.
    (* ram_style = "block" *) reg [223:0] mem [31:0];

    always @(posedge clk) begin
        if (write_enable)
            mem[write_addr] <= write_data;
        if (read_enable)
            read_data <= mem[read_addr];
    end

endmodule
/* verilator lint_on DECLFILENAME */

module cam_rmt (
        input wire clk,
        input wire resetn,

        input wire [4:0] lane0_arch_reg_src1,
        input wire [4:0] lane0_arch_reg_src2,
        input wire [4:0] lane0_arch_reg_dst,
        input wire       lane0_rename_arch_reg_dst_valid,
        input wire       lane0_valid_copy_valid,
        input wire [4:0] lane0_valid_copy_bid,

        input wire [4:0] lane1_arch_reg_src1,
        input wire [4:0] lane1_arch_reg_src2,
        input wire [4:0] lane1_arch_reg_dst,
        input wire       lane1_rename_arch_reg_dst_valid,
        input wire       lane1_valid_copy_valid,
        input wire [4:0] lane1_valid_copy_bid,

        input wire [4:0] lane2_arch_reg_src1,
        input wire [4:0] lane2_arch_reg_src2,
        input wire [4:0] lane2_arch_reg_dst,
        input wire       lane2_rename_arch_reg_dst_valid,
        input wire       lane2_valid_copy_valid,
        input wire [4:0] lane2_valid_copy_bid,

        input wire [4:0] lane3_arch_reg_src1,
        input wire [4:0] lane3_arch_reg_src2,
        input wire [4:0] lane3_arch_reg_dst,
        input wire       lane3_rename_arch_reg_dst_valid,
        input wire       lane3_valid_copy_valid,
        input wire [4:0] lane3_valid_copy_bid,

        output wire [6:0] lane0_phy_reg_src1,
        output wire [6:0] lane0_phy_reg_src2,
        output wire [6:0] lane0_old_phy_reg_dst,
        output wire [6:0] lane0_new_phy_reg_dst,
        output wire       lane0_rename_success,

        output wire [6:0] lane1_phy_reg_src1,
        output wire [6:0] lane1_phy_reg_src2,
        output wire [6:0] lane1_old_phy_reg_dst,
        output wire [6:0] lane1_new_phy_reg_dst,
        output wire       lane1_rename_success,

        output wire [6:0] lane2_phy_reg_src1,
        output wire [6:0] lane2_phy_reg_src2,
        output wire [6:0] lane2_old_phy_reg_dst,
        output wire [6:0] lane2_new_phy_reg_dst,
        output wire       lane2_rename_success,

        output wire [6:0] lane3_phy_reg_src1,
        output wire [6:0] lane3_phy_reg_src2,
        output wire [6:0] lane3_old_phy_reg_dst,
        output wire [6:0] lane3_new_phy_reg_dst,
        output wire       lane3_rename_success,

        input wire [6:0] update_writeback1_reg_dst,
        input wire       update_writeback1_valid,
        input wire [6:0] update_writeback2_reg_dst,
        input wire       update_writeback2_valid,
        input wire [6:0] update_writeback3_reg_dst,
        input wire       update_writeback3_valid,
        input wire [6:0] update_writeback4_reg_dst,
        input wire       update_writeback4_valid,
        input wire [6:0] update_writeback5_reg_dst,
        input wire       update_writeback5_valid,
        input wire [6:0] update_writeback6_reg_dst,
        input wire       update_writeback6_valid,
        input wire [6:0] update_writeback7_reg_dst,
        input wire       update_writeback7_valid,

        input wire [3:0] update_commit_valid,
        input wire [4:0] update_commit_arch_reg_dst_0,
        input wire [4:0] update_commit_arch_reg_dst_1,
        input wire [4:0] update_commit_arch_reg_dst_2,
        input wire [4:0] update_commit_arch_reg_dst_3,
        input wire [6:0] update_commit_new_reg_dst_0,
        input wire [6:0] update_commit_new_reg_dst_1,
        input wire [6:0] update_commit_new_reg_dst_2,
        input wire [6:0] update_commit_new_reg_dst_3,
        input wire [6:0] update_commit_old_reg_dst_0,
        input wire [6:0] update_commit_old_reg_dst_1,
        input wire [6:0] update_commit_old_reg_dst_2,
        input wire [6:0] update_commit_old_reg_dst_3,

        output wire [127:0] phy_ready,

        input wire       flush,
        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid

`ifdef difftest
        , output wire [6:0] armt [31:0]
`endif
    );

    // The old implementation kept an architectural tag in every physical
    // entry and performed twelve 128-entry CAM searches per cycle.  A forward
    // map has the same rename semantics with only twelve 32-entry reads.
    (* ram_style = "registers" *) reg [6:0] speculative_rmt [31:0];
    (* ram_style = "registers" *) reg [6:0] committed_rmt   [31:0];

    reg [1:0] state [127:0];
    reg [4:0] bid   [127:0];

    wire [127:0] allocated;
    wire [127:0] zero_hot;
    wire [127:0] phy_reg_rdy;
    wire [127:0] phy_reg_rdy_now;
    wire [3:0] lane_has_free_phy;
    wire [6:0] lane_free_phy [3:0];

    wire lane0_reached;
    wire lane1_reached;
    wire lane2_reached;
    wire lane3_reached;
    wire do_rename0;
    wire do_rename1;
    wire do_rename2;
    wire do_rename3;

    wire [3:0] checkpoint_fire;
    wire checkpoint_write_valid;
    wire [4:0] checkpoint_write_bid;
    reg        checkpoint_write_valid_q;
    reg  [4:0] checkpoint_write_bid_q;

    wire [223:0] speculative_map_flat;
    wire [223:0] checkpoint_map_flat;
    reg          checkpoint_restore_pending;

    wire [4:0] update_commit_arch_reg_dst [3:0];
    wire [6:0] update_commit_new_reg_dst [3:0];
    wire [6:0] update_commit_old_reg_dst [3:0];
    // Keep the shared high-bit decode so synthesis does not rebuild 127
    // independent 7-bit comparisons driven by each commit lane.
    (* keep = "true" *) wire [7:0] commit_new_group_hit [3:0];
    (* keep = "true" *) wire [7:0] commit_old_group_hit [3:0];
    wire [127:1] writeback_event;
    wire [127:1] alloc_event;
    wire [127:1] commit_touch;
    wire [1:0] commit_final_state [127:1];
    wire [127:1] greater_bid;

    genvar i;
    genvar arch;
    genvar index_bit;
    genvar index_entry;
    genvar commit_lane;
    genvar commit_group;

    assign update_commit_arch_reg_dst[0] = update_commit_arch_reg_dst_0;
    assign update_commit_arch_reg_dst[1] = update_commit_arch_reg_dst_1;
    assign update_commit_arch_reg_dst[2] = update_commit_arch_reg_dst_2;
    assign update_commit_arch_reg_dst[3] = update_commit_arch_reg_dst_3;
    assign update_commit_new_reg_dst[0] = update_commit_new_reg_dst_0;
    assign update_commit_new_reg_dst[1] = update_commit_new_reg_dst_1;
    assign update_commit_new_reg_dst[2] = update_commit_new_reg_dst_2;
    assign update_commit_new_reg_dst[3] = update_commit_new_reg_dst_3;
    assign update_commit_old_reg_dst[0] = update_commit_old_reg_dst_0;
    assign update_commit_old_reg_dst[1] = update_commit_old_reg_dst_1;
    assign update_commit_old_reg_dst[2] = update_commit_old_reg_dst_2;
    assign update_commit_old_reg_dst[3] = update_commit_old_reg_dst_3;

    // Decode the physical-register group once per commit lane.  Each shared
    // group hit drives only the sixteen state entries in that group; the low
    // four bits are compared locally beside the state registers.
    generate
        for (commit_lane = 0; commit_lane < 4;
                commit_lane = commit_lane + 1) begin : gen_commit_lane_predecode
            for (commit_group = 0; commit_group < 8;
                    commit_group = commit_group + 1) begin : gen_commit_group_predecode
                localparam [2:0] COMMIT_GROUP_ID = commit_group;

                assign commit_new_group_hit[commit_lane][commit_group] =
                       update_commit_valid[commit_lane] &&
                       (update_commit_new_reg_dst[commit_lane][6:4] ==
                        COMMIT_GROUP_ID);
                assign commit_old_group_hit[commit_lane][commit_group] =
                       update_commit_valid[commit_lane] &&
                       (update_commit_old_reg_dst[commit_lane][6:4] ==
                        COMMIT_GROUP_ID);
            end
        end
    endgenerate

    assign allocated[0] = 1'b1;
    assign phy_reg_rdy[0] = 1'b1;
    assign phy_reg_rdy_now[0] = 1'b1;

    generate
        for (i = 1; i < 128; i = i + 1) begin : gen_phy_status
            assign allocated[i] = (state[i] != `RMT_STATE_EMPTY);
            assign phy_reg_rdy[i] =
                   (state[i] == `RMT_STATE_WRITEBACK) ||
                   (state[i] == `RMT_STATE_COMMIT);
            assign phy_reg_rdy_now[i] = phy_reg_rdy[i];
        end
    endgenerate

    assign phy_ready = phy_reg_rdy_now;

    // Each rename lane owns a disjoint physical-register partition.  This
    // guarantees four independent allocations without a cross-lane arbiter.
    assign zero_hot[0]       = 1'b0;
    assign zero_hot[63:1]    = (~allocated[63:1]) &
           (allocated[63:1] + 63'd1);
    assign zero_hot[95:64]   = (~allocated[95:64]) &
           (allocated[95:64] + 32'd1);
    assign zero_hot[111:96]  = (~allocated[111:96]) &
           (allocated[111:96] + 16'd1);
    assign zero_hot[127:112] = (~allocated[127:112]) &
           (allocated[127:112] + 16'd1);

    assign lane_has_free_phy[0] = |zero_hot[63:1];
    assign lane_has_free_phy[1] = |zero_hot[95:64];
    assign lane_has_free_phy[2] = |zero_hot[111:96];
    assign lane_has_free_phy[3] = |zero_hot[127:112];

    wire [63:1] lane0_idx_and [6:0];
    wire [31:0] lane1_idx_and [6:0];
    wire [15:0] lane2_idx_and [6:0];
    wire [15:0] lane3_idx_and [6:0];

    generate
        for (index_bit = 0; index_bit < 7;
                index_bit = index_bit + 1) begin : gen_lane0_index_bit
            for (index_entry = 1; index_entry < 64;
                    index_entry = index_entry + 1) begin : gen_lane0_index_entry
                localparam [6:0] PHY_INDEX = index_entry;
                assign lane0_idx_and[index_bit][index_entry] =
                       zero_hot[index_entry] && PHY_INDEX[index_bit];
            end
            assign lane_free_phy[0][index_bit] =
                   |lane0_idx_and[index_bit];
        end
        for (index_bit = 0; index_bit < 7;
                index_bit = index_bit + 1) begin : gen_lane1_index_bit
            for (index_entry = 0; index_entry < 32;
                    index_entry = index_entry + 1) begin : gen_lane1_index_entry
                localparam [6:0] PHY_INDEX = index_entry + 7'd64;
                assign lane1_idx_and[index_bit][index_entry] =
                       zero_hot[index_entry + 64] && PHY_INDEX[index_bit];
            end
            assign lane_free_phy[1][index_bit] =
                   |lane1_idx_and[index_bit];
        end
        for (index_bit = 0; index_bit < 7;
                index_bit = index_bit + 1) begin : gen_lane2_index_bit
            for (index_entry = 0; index_entry < 16;
                    index_entry = index_entry + 1) begin : gen_lane2_index_entry
                localparam [6:0] PHY_INDEX = index_entry + 7'd96;
                assign lane2_idx_and[index_bit][index_entry] =
                       zero_hot[index_entry + 96] && PHY_INDEX[index_bit];
            end
            assign lane_free_phy[2][index_bit] =
                   |lane2_idx_and[index_bit];
        end
        for (index_bit = 0; index_bit < 7;
                index_bit = index_bit + 1) begin : gen_lane3_index_bit
            for (index_entry = 0; index_entry < 16;
                    index_entry = index_entry + 1) begin : gen_lane3_index_entry
                localparam [6:0] PHY_INDEX = index_entry + 7'd112;
                assign lane3_idx_and[index_bit][index_entry] =
                       zero_hot[index_entry + 112] && PHY_INDEX[index_bit];
            end
            assign lane_free_phy[3][index_bit] =
                   |lane3_idx_and[index_bit];
        end
    endgenerate

    // Success is an oldest-first prefix.  A branch checkpoint terminates the
    // group, but the branch itself (including a JIRL destination) is renamed.
    assign lane0_reached = !checkpoint_restore_pending;
    assign lane0_rename_success = lane0_reached &&
           (lane0_arch_reg_dst == 5'd0 || lane_has_free_phy[0]) &&
           lane0_rename_arch_reg_dst_valid;

    assign lane1_reached = lane0_rename_success && !lane0_valid_copy_valid;
    assign lane1_rename_success = lane1_reached &&
           (lane1_arch_reg_dst == 5'd0 || lane_has_free_phy[1]) &&
           lane1_rename_arch_reg_dst_valid;

    assign lane2_reached = lane1_rename_success &&
           !lane1_valid_copy_valid;
    assign lane2_rename_success = lane2_reached &&
           (lane2_arch_reg_dst == 5'd0 || lane_has_free_phy[2]) &&
           lane2_rename_arch_reg_dst_valid;

    assign lane3_reached = lane2_rename_success &&
           !lane2_valid_copy_valid;
    assign lane3_rename_success = lane3_reached &&
           (lane3_arch_reg_dst == 5'd0 || lane_has_free_phy[3]) &&
           lane3_rename_arch_reg_dst_valid;

    assign do_rename0 = lane0_rename_success &&
           (lane0_arch_reg_dst != 5'd0);
    assign do_rename1 = lane1_rename_success &&
           (lane1_arch_reg_dst != 5'd0);
    assign do_rename2 = lane2_rename_success &&
           (lane2_arch_reg_dst != 5'd0);
    assign do_rename3 = lane3_rename_success &&
           (lane3_arch_reg_dst != 5'd0);

    assign lane0_new_phy_reg_dst = do_rename0 ? lane_free_phy[0] : 7'd0;
    assign lane1_new_phy_reg_dst = do_rename1 ? lane_free_phy[1] : 7'd0;
    assign lane2_new_phy_reg_dst = do_rename2 ? lane_free_phy[2] : 7'd0;
    assign lane3_new_phy_reg_dst = do_rename3 ? lane_free_phy[3] : 7'd0;

    // Forward-map reads replace twelve full CAM compare/encode trees.  The
    // bypass chain preserves same-cycle RAW and WAW ordering across four lanes.
    assign lane0_phy_reg_src1 = speculative_rmt[lane0_arch_reg_src1];
    assign lane0_phy_reg_src2 = speculative_rmt[lane0_arch_reg_src2];
    assign lane0_old_phy_reg_dst = speculative_rmt[lane0_arch_reg_dst];

    assign lane1_phy_reg_src1 =
           (lane0_arch_reg_dst == lane1_arch_reg_src1) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane1_arch_reg_src1];
    assign lane1_phy_reg_src2 =
           (lane0_arch_reg_dst == lane1_arch_reg_src2) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane1_arch_reg_src2];
    assign lane1_old_phy_reg_dst =
           (lane0_arch_reg_dst == lane1_arch_reg_dst) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane1_arch_reg_dst];

    assign lane2_phy_reg_src1 =
           (lane1_arch_reg_dst == lane2_arch_reg_src1) ?
           lane1_new_phy_reg_dst :
           (lane0_arch_reg_dst == lane2_arch_reg_src1) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane2_arch_reg_src1];
    assign lane2_phy_reg_src2 =
           (lane1_arch_reg_dst == lane2_arch_reg_src2) ?
           lane1_new_phy_reg_dst :
           (lane0_arch_reg_dst == lane2_arch_reg_src2) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane2_arch_reg_src2];
    assign lane2_old_phy_reg_dst =
           (lane1_arch_reg_dst == lane2_arch_reg_dst) ?
           lane1_new_phy_reg_dst :
           (lane0_arch_reg_dst == lane2_arch_reg_dst) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane2_arch_reg_dst];

    assign lane3_phy_reg_src1 =
           (lane2_arch_reg_dst == lane3_arch_reg_src1) ?
           lane2_new_phy_reg_dst :
           (lane1_arch_reg_dst == lane3_arch_reg_src1) ?
           lane1_new_phy_reg_dst :
           (lane0_arch_reg_dst == lane3_arch_reg_src1) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane3_arch_reg_src1];
    assign lane3_phy_reg_src2 =
           (lane2_arch_reg_dst == lane3_arch_reg_src2) ?
           lane2_new_phy_reg_dst :
           (lane1_arch_reg_dst == lane3_arch_reg_src2) ?
           lane1_new_phy_reg_dst :
           (lane0_arch_reg_dst == lane3_arch_reg_src2) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane3_arch_reg_src2];
    assign lane3_old_phy_reg_dst =
           (lane2_arch_reg_dst == lane3_arch_reg_dst) ?
           lane2_new_phy_reg_dst :
           (lane1_arch_reg_dst == lane3_arch_reg_dst) ?
           lane1_new_phy_reg_dst :
           (lane0_arch_reg_dst == lane3_arch_reg_dst) ?
           lane0_new_phy_reg_dst : speculative_rmt[lane3_arch_reg_dst];

    // Flatten the speculative map into one BRAM checkpoint word.  The delayed
    // write samples the map after the branch lane's rename and before any
    // following cycle's nonblocking map updates take effect.
    generate
        for (arch = 0; arch < 32; arch = arch + 1) begin : gen_map_flatten
            assign speculative_map_flat[arch * 7 +: 7] =
                   speculative_rmt[arch];
        end
    endgenerate

    cam_rmt_checkpoint_bram u_cam_rmt_checkpoint_bram (
                                .clk         (clk),
                                .write_enable(checkpoint_write_valid_q && !predict_flush),
                                .write_addr  (checkpoint_write_bid_q),
                                .write_data  (speculative_map_flat),
                                .read_enable (predict_flush),
                                .read_addr   (predict_flush_bid),
                                .read_data   (checkpoint_map_flat)
                            );

    assign checkpoint_fire[0] = lane0_rename_success &&
           lane0_valid_copy_valid;
    assign checkpoint_fire[1] = lane1_rename_success &&
           lane1_valid_copy_valid;
    assign checkpoint_fire[2] = lane2_rename_success &&
           lane2_valid_copy_valid;
    assign checkpoint_fire[3] = lane3_rename_success &&
           lane3_valid_copy_valid;
    assign checkpoint_write_valid = |checkpoint_fire;
    assign checkpoint_write_bid = checkpoint_fire[0] ?
           lane0_valid_copy_bid : checkpoint_fire[1] ?
           lane1_valid_copy_bid : checkpoint_fire[2] ?
           lane2_valid_copy_bid : lane3_valid_copy_bid;

    always @(posedge clk) begin
        if (!resetn || flush) begin
            checkpoint_write_valid_q <= 1'b0;
            checkpoint_write_bid_q   <= 5'd0;
        end
        else begin
            checkpoint_write_valid_q <= checkpoint_write_valid;
            checkpoint_write_bid_q   <= checkpoint_write_bid;
        end
    end

    // Block rename for the BRAM read latency.  The request is sampled on the
    // predict-flush edge; the map is installed on the following edge.
    always @(posedge clk) begin
        if (!resetn || flush)
            checkpoint_restore_pending <= 1'b0;
        else if (predict_flush)
            checkpoint_restore_pending <= 1'b1;
        else if (checkpoint_restore_pending)
            checkpoint_restore_pending <= 1'b0;
    end

    // One register per architectural mapping avoids a wide variable write
    // decoder.  Later lanes have priority for same-cycle WAW dependencies.
    generate
        for (arch = 0; arch < 32; arch = arch + 1) begin : gen_forward_map
            localparam [4:0] ARCH_INDEX = arch;

            always @(posedge clk) begin
                if (!resetn)
                    speculative_rmt[arch] <= 7'd0;
                else if (flush)
                    speculative_rmt[arch] <= committed_rmt[arch];
                else if (checkpoint_restore_pending)
                    speculative_rmt[arch] <=
                                   checkpoint_map_flat[arch * 7 +: 7];
                else begin
                    if (do_rename0 && lane0_arch_reg_dst == ARCH_INDEX)
                        speculative_rmt[arch] <= lane0_new_phy_reg_dst;
                    if (do_rename1 && lane1_arch_reg_dst == ARCH_INDEX)
                        speculative_rmt[arch] <= lane1_new_phy_reg_dst;
                    if (do_rename2 && lane2_arch_reg_dst == ARCH_INDEX)
                        speculative_rmt[arch] <= lane2_new_phy_reg_dst;
                    if (do_rename3 && lane3_arch_reg_dst == ARCH_INDEX)
                        speculative_rmt[arch] <= lane3_new_phy_reg_dst;
                end
            end

            always @(posedge clk) begin
                if (!resetn)
                    committed_rmt[arch] <= 7'd0;
                else begin
                    if (update_commit_valid[0] &&
                            update_commit_arch_reg_dst[0] == ARCH_INDEX)
                        committed_rmt[arch] <= update_commit_new_reg_dst[0];
                    if (update_commit_valid[1] &&
                            update_commit_arch_reg_dst[1] == ARCH_INDEX)
                        committed_rmt[arch] <= update_commit_new_reg_dst[1];
                    if (update_commit_valid[2] &&
                            update_commit_arch_reg_dst[2] == ARCH_INDEX)
                        committed_rmt[arch] <= update_commit_new_reg_dst[2];
                    if (update_commit_valid[3] &&
                            update_commit_arch_reg_dst[3] == ARCH_INDEX)
                        committed_rmt[arch] <= update_commit_new_reg_dst[3];
                end
            end
        end
    endgenerate

    // Physical-register lifecycle is independent of the forward map.  It
    // supplies allocation availability and source-ready wakeup state.
    always @(posedge clk) begin
        state[0] <= `RMT_STATE_COMMIT;
        bid[0]   <= 5'd0;
    end

    generate
        for (i = 1; i < 64; i = i + 1) begin : gen_bid_write_lane0
            always @(posedge clk) begin
                if (do_rename0 && lane0_new_phy_reg_dst == i)
                    bid[i] <= lane0_valid_copy_bid;
            end
        end
        for (i = 64; i < 96; i = i + 1) begin : gen_bid_write_lane1
            always @(posedge clk) begin
                if (do_rename1 && lane1_new_phy_reg_dst == i)
                    bid[i] <= lane1_valid_copy_bid;
            end
        end
        for (i = 96; i < 112; i = i + 1) begin : gen_bid_write_lane2
            always @(posedge clk) begin
                if (do_rename2 && lane2_new_phy_reg_dst == i)
                    bid[i] <= lane2_valid_copy_bid;
            end
        end
        for (i = 112; i < 128; i = i + 1) begin : gen_bid_write_lane3
            always @(posedge clk) begin
                if (do_rename3 && lane3_new_phy_reg_dst == i)
                    bid[i] <= lane3_valid_copy_bid;
            end
        end
    endgenerate

    generate
        for (i = 1; i < 128; i = i + 1) begin : gen_state_events
            localparam [6:0] PHY_INDEX = i;
            localparam [2:0] PHY_GROUP = PHY_INDEX[6:4];
            localparam [3:0] PHY_OFFSET = PHY_INDEX[3:0];
            wire [3:0] commit_new_hit;
            wire [3:0] commit_old_hit;
            wire [3:0] commit_lane_touch;

            assign commit_new_hit[0] =
                   commit_new_group_hit[0][PHY_GROUP] &&
                   (update_commit_new_reg_dst[0][3:0] == PHY_OFFSET);
            assign commit_new_hit[1] =
                   commit_new_group_hit[1][PHY_GROUP] &&
                   (update_commit_new_reg_dst[1][3:0] == PHY_OFFSET);
            assign commit_new_hit[2] =
                   commit_new_group_hit[2][PHY_GROUP] &&
                   (update_commit_new_reg_dst[2][3:0] == PHY_OFFSET);
            assign commit_new_hit[3] =
                   commit_new_group_hit[3][PHY_GROUP] &&
                   (update_commit_new_reg_dst[3][3:0] == PHY_OFFSET);

            assign commit_old_hit[0] =
                   commit_old_group_hit[0][PHY_GROUP] &&
                   (update_commit_old_reg_dst[0][3:0] == PHY_OFFSET);
            assign commit_old_hit[1] =
                   commit_old_group_hit[1][PHY_GROUP] &&
                   (update_commit_old_reg_dst[1][3:0] == PHY_OFFSET);
            assign commit_old_hit[2] =
                   commit_old_group_hit[2][PHY_GROUP] &&
                   (update_commit_old_reg_dst[2][3:0] == PHY_OFFSET);
            assign commit_old_hit[3] =
                   commit_old_group_hit[3][PHY_GROUP] &&
                   (update_commit_old_reg_dst[3][3:0] == PHY_OFFSET);

            assign commit_lane_touch = commit_new_hit | commit_old_hit;
            assign commit_touch[i] = |commit_lane_touch;
            assign commit_final_state[i] = commit_lane_touch[3] ?
                   (commit_new_hit[3] ? `RMT_STATE_COMMIT : `RMT_STATE_EMPTY) :
                   commit_lane_touch[2] ?
                   (commit_new_hit[2] ? `RMT_STATE_COMMIT : `RMT_STATE_EMPTY) :
                   commit_lane_touch[1] ?
                   (commit_new_hit[1] ? `RMT_STATE_COMMIT : `RMT_STATE_EMPTY) :
                   (commit_new_hit[0] ? `RMT_STATE_COMMIT : `RMT_STATE_EMPTY);

            assign writeback_event[i] =
                   (update_writeback1_valid &&
                    update_writeback1_reg_dst == PHY_INDEX) ||
                   (update_writeback2_valid &&
                    update_writeback2_reg_dst == PHY_INDEX) ||
                   (update_writeback3_valid &&
                    update_writeback3_reg_dst == PHY_INDEX) ||
                   (update_writeback4_valid &&
                    update_writeback4_reg_dst == PHY_INDEX) ||
                   (update_writeback5_valid &&
                    update_writeback5_reg_dst == PHY_INDEX) ||
                   (update_writeback6_valid &&
                    update_writeback6_reg_dst == PHY_INDEX) ||
                   (update_writeback7_valid &&
                    update_writeback7_reg_dst == PHY_INDEX);

            circle_comparator u_circle_comparator (
                                  .head  (head_bid),
                                  .a     (bid[i]),
                                  .b     (predict_flush_bid),
                                  .a_gt_b(greater_bid[i])
                              );
        end

        for (i = 1; i < 64; i = i + 1) begin : gen_alloc_event_lane0
            assign alloc_event[i] = !predict_flush && do_rename0 &&
                   (lane0_new_phy_reg_dst == i);
        end
        for (i = 64; i < 96; i = i + 1) begin : gen_alloc_event_lane1
            assign alloc_event[i] = !predict_flush && do_rename1 &&
                   (lane1_new_phy_reg_dst == i);
        end
        for (i = 96; i < 112; i = i + 1) begin : gen_alloc_event_lane2
            assign alloc_event[i] = !predict_flush && do_rename2 &&
                   (lane2_new_phy_reg_dst == i);
        end
        for (i = 112; i < 128; i = i + 1) begin : gen_alloc_event_lane3
            assign alloc_event[i] = !predict_flush && do_rename3 &&
                   (lane3_new_phy_reg_dst == i);
        end

        for (i = 1; i < 128; i = i + 1) begin : gen_state_register
            always @(posedge clk) begin
                if (!resetn)
                    state[i] <= `RMT_STATE_EMPTY;
                else if (flush)
                    state[i] <= (state[i] == `RMT_STATE_COMMIT) ? `RMT_STATE_COMMIT : `RMT_STATE_EMPTY;
                else if (predict_flush && state[i] != `RMT_STATE_COMMIT && greater_bid[i])
                    state[i] <= `RMT_STATE_EMPTY;
                else if (commit_touch[i])
                    state[i] <= commit_final_state[i];
                else if (writeback_event[i])
                    state[i] <= `RMT_STATE_WRITEBACK;
                else if (alloc_event[i])
                    state[i] <= `RMT_STATE_MAPPED;
            end
        end
    endgenerate

`ifdef difftest

    assign armt = committed_rmt;
`endif

endmodule
