`include "cache_defs.vh"
`include "cache_cacop_defs.vh"

module icache_pipeline #(
        parameter [1:0] CACHEABLE_MAT = 2'b01
    ) (
        input wire clk,
        input wire resetn,

        input wire if1_valid,
        input wire [31:0] if1_va,
        output wire if1_ready,

        input wire if2_valid,
        input wire [31:0] if2_va,
        input wire [31:0] if2_pa,
        input wire [1:0] if2_mat,
        input wire if2_miss_req,
        output wire if2_miss_ready,
        output wire if2_array_valid,
        output wire if2_hit,
        output wire if2_miss,
        output wire if2_hit_way,
        output wire if2_refill_valid,


        output wire [`CACHE_WORD_WIDTH-1:0] if2_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data7,

        output wire icache_busy,

        input wire maint_valid,
        input wire [1:0] maint_op,
        input wire maint_way,
        input wire [`CACHE_INDEX_WIDTH-1:0] maint_index,
        input wire [`CACHE_TAG_WIDTH-1:0] maint_tag,
        output wire maint_addr_ok,
        output wire maint_data_ok,

        output wire [3:0] arid,
        output wire [31:0] araddr,
        output wire [7:0] arlen,
        output wire [2:0] arsize,
        output wire [1:0] arburst,
        output wire arvalid,
        input wire arready,
        // 返回通道一拍给整行（bank0 在最低 32 位）。
        input wire [`CACHE_LINE_WIDTH-1:0] rline,
        input wire rvalid,
        output wire rready
    );

    localparam S_IDLE = 3'd0;
    localparam S_REFILL_REQ = 3'd1;
    localparam S_REFILL = 3'd2;
    localparam S_REFILL_RESP = 3'd3;
    localparam S_UNCACHE_REQ = 3'd4;
    localparam S_UNCACHE_WAIT = 3'd5;
    localparam S_UNCACHE_RESP = 3'd6;

    localparam M_IDLE = 3'd0;
    localparam M_LOOKUP = 3'd1;
    localparam M_CHECK = 3'd2;
    localparam M_CLEAR = 3'd3;
    localparam M_RESP = 3'd4;

    localparam R_IDLE = 3'd0;
    localparam R_LOOKUP = 3'd1;
    localparam R_WAIT = 3'd2;
    localparam R_HIT_READY = 3'd3;
    localparam R_MISS_READY = 3'd4;
    localparam R_HIT_RESP = 3'd5;

    reg [2:0] state_r;
    reg [2:0] maint_state_r;
    reg maint_way_r;
    reg [`CACHE_INDEX_WIDTH-1:0] maint_index_r;
    reg [`CACHE_TAG_WIDTH-1:0] maint_tag_r;

    // bank 追踪链（if1_bank → lookup_meta_bank → miss_hold_bank → miss_bank、
    reg [31:0] miss_pa_r;
    reg [`CACHE_INDEX_WIDTH-1:0] miss_index_r;
    reg [`CACHE_TAG_WIDTH-1:0] miss_tag_r;
    reg miss_way_r;
    reg [`CACHE_WORD_WIDTH-1:0] miss_data_r [0:`CACHE_BANKS-1];

    reg miss_hold_valid_r;
    reg miss_hold_cacheable_r;
    reg [31:0] miss_hold_pa_r;
    reg [`CACHE_INDEX_WIDTH-1:0] miss_hold_index_r;
    reg [`CACHE_TAG_WIDTH-1:0] miss_hold_tag_r;
    reg miss_hold_way_r;

    // IF1 的元信息
    reg lookup_meta_if1_valid_r;
    reg [`CACHE_INDEX_WIDTH-1:0] lookup_meta_index_r;
    reg lookup_meta_lru_victim_way_r;

    reg [2:0] replay_state_r;
    reg [31:0] replay_pa_r;
    reg [`CACHE_INDEX_WIDTH-1:0] replay_index_r;
    reg [`CACHE_TAG_WIDTH-1:0] replay_tag_r;

    reg [`CACHE_WORD_WIDTH-1:0] replay_data_r [0:`CACHE_BANKS-1];
    reg replay_lookup_meta_valid_r;
    reg replay_lookup_meta_lru_victim_way_r;
    reg replay_block_valid_r;
    reg [31:0] replay_block_pa_r;

    reg replace_access_valid_r;
    reg [`CACHE_INDEX_WIDTH-1:0] replace_access_index_r;
    reg replace_access_way_r;

    reg [31:0] uncache_pa_r;
    // uncache_rdata_r ，非缓存也用 miss_data_r[]

    wire lookup_valid_w;
    wire [`CACHE_INDEX_WIDTH-1:0] lookup_index_w;
    wire lookup_refill_conflict_w;

    wire [`CACHE_INDEX_WIDTH-1:0] if1_index_w;

    wire [`CACHE_INDEX_WIDTH-1:0] if2_index_w;
    wire [`CACHE_TAG_WIDTH-1:0] if2_tag_w;

    wire way0_valid_w;
    wire [`CACHE_TAG_WIDTH-1:0] way0_tag_w;
    wire [`CACHE_WORD_WIDTH-1:0] way0_data_w [0:`CACHE_BANKS-1];

    wire way1_valid_w;
    wire [`CACHE_TAG_WIDTH-1:0] way1_tag_w;
    wire [`CACHE_WORD_WIDTH-1:0] way1_data_w [0:`CACHE_BANKS-1];


    wire [`CACHE_WORD_WIDTH-1:0] hit_data_w [0:`CACHE_BANKS-1];
    wire [`CACHE_WORD_WIDTH-1:0] replay_sel_w [0:`CACHE_BANKS-1];
    wire [`CACHE_WORD_WIDTH-1:0] refill_data_w [0:`CACHE_BANKS-1];
    wire [`CACHE_WORD_WIDTH-1:0] if2_data_w [0:`CACHE_BANKS-1];

    wire replace_way_raw_unused_w;
    wire lru_victim_way_w;
    wire lookup_lru_victim_way_from_replace_w;
    wire lookup_lru_victim_way_w;
    wire miss_lru_victim_way_w;
    wire replace_way_w;
    wire replace_update_w;
    wire [`CACHE_INDEX_WIDTH-1:0] replace_victim_index_w;
    wire replace_access_valid_w;
    wire [`CACHE_INDEX_WIDTH-1:0] replace_access_index_w;
    wire replace_access_way_w;

    wire compare_hit_w;
    wire compare_hit_way_w;
    wire compare_hit_dirty_unused_w;

    wire if1_lookup_fire_w;
    wire if1_lookup_accept_w;
    wire if2_lookup_match_w;
    wire replay_lookup_req_w;
    wire replay_lookup_accept_w;
    wire replay_active_w;
    wire replay_start_w;
    wire replay_resp_valid_w;
    wire replay_compare_hit_w;
    wire replay_compare_hit_way_w;
    wire replay_compare_hit_dirty_unused_w;
    wire replay_hit_ready_w;
    wire replay_hit_fire_w;
    wire replay_wait_miss_w;

    wire if2_current_miss_w;
    wire if2_raw_refill_valid_w;
    wire [31:0] if2_raw_refill_pa_w;
    wire if2_served_same_w;
    wire if2_wait_data_w;
    wire if2_served_w;
    wire [31:0] if2_served_pa_w;

    wire miss_hold_match_if2_w;
    wire miss_hold_hit_cancel_w;
    wire miss_hold_mismatch_w;
    wire miss_hold_use_w;

    wire miss_req_fire_w;
    wire external_miss_fire_w;
    wire replay_miss_fire_w;

    wire miss_source_cacheable_w;
    wire [31:0] miss_source_pa_w;
    wire [`CACHE_INDEX_WIDTH-1:0] miss_source_index_w;
    wire [`CACHE_TAG_WIDTH-1:0] miss_source_tag_w;
    wire miss_source_way_w;

    wire rd_req_w;
    wire rd_ready_w;

    wire ret_valid_w;
    wire [`CACHE_LINE_WIDTH-1:0] ret_line_w;

    wire refill_valid_w;

    wire maint_busy_w;
    wire maint_accept_w;
    wire maint_hit_lookup_w;
    wire maint_hit_check_w;
    wire maint_hit_w;
    wire maint_hit_way_w;
    wire maint_clear_valid_w;

    wire array_valid_w;

    // 8 个字的复位／装载循环用
    integer i;

    assign if1_index_w = if1_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
    assign if2_index_w = if2_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
    assign if2_tag_w = if2_pa[`CACHE_TAG_MSB:`CACHE_TAG_LSB];

    assign maint_busy_w = maint_state_r != M_IDLE;
    assign replay_active_w = replay_state_r != R_IDLE;
    assign icache_busy = (state_r != S_IDLE) || maint_busy_w || replay_active_w || replay_start_w || if2_wait_data_w;

    assign if1_ready = !icache_busy && !maint_valid && !if2_miss && !if2_miss_req;
    assign if1_lookup_fire_w = if1_valid && if1_ready;
    assign replay_lookup_req_w = replay_state_r == R_LOOKUP;
    assign lookup_valid_w = if1_lookup_fire_w || maint_hit_lookup_w || replay_lookup_req_w;
    assign lookup_index_w = maint_hit_lookup_w ? maint_index_r :
           replay_lookup_req_w ? replay_index_r :
           if1_index_w;

    assign if1_lookup_accept_w = if1_lookup_fire_w && !maint_hit_lookup_w && !replay_lookup_req_w && !lookup_refill_conflict_w;
    assign replay_lookup_accept_w = replay_lookup_req_w && !maint_hit_lookup_w && !lookup_refill_conflict_w;



    assign if2_lookup_match_w = array_valid_w && lookup_meta_if1_valid_r && (lookup_meta_index_r == if2_index_w);
    assign replay_resp_valid_w = (replay_state_r == R_WAIT) && array_valid_w && replay_lookup_meta_valid_r;
    assign replay_hit_ready_w = (replay_state_r == R_HIT_READY);
    assign replay_hit_fire_w = replay_hit_ready_w;
    assign replay_wait_miss_w = replay_resp_valid_w && !replay_compare_hit_w;
    assign replay_start_w = if2_valid && (if2_mat == CACHEABLE_MAT) &&
           !if2_lookup_match_w &&
           !replay_active_w &&
           (!replay_block_valid_r || (if2_pa != replay_block_pa_r)) &&
           (state_r == S_IDLE) &&
           !maint_busy_w &&
           !maint_valid &&
           !miss_hold_match_if2_w;

    assign if2_array_valid = if2_valid && (if2_mat == CACHEABLE_MAT) && if2_lookup_match_w;
    assign if2_hit = if2_array_valid && compare_hit_w;
    assign if2_current_miss_w = if2_valid && (((if2_mat == CACHEABLE_MAT) && if2_lookup_match_w && !compare_hit_w) || (if2_mat != CACHEABLE_MAT));
    assign if2_served_same_w = replay_block_valid_r && if2_valid && (if2_pa == replay_block_pa_r);
    assign if2_wait_data_w = if2_valid && !if2_hit && !if2_refill_valid && !if2_served_same_w;

    assign miss_hold_match_if2_w = miss_hold_valid_r && if2_valid && (miss_hold_pa_r == if2_pa) && (miss_hold_cacheable_r == (if2_mat == CACHEABLE_MAT));
    assign miss_hold_hit_cancel_w = miss_hold_match_if2_w && if2_hit;
    assign miss_hold_mismatch_w = miss_hold_valid_r && if2_valid && !miss_hold_match_if2_w;
    assign miss_hold_use_w = miss_hold_match_if2_w || (replay_state_r == R_MISS_READY);

    assign if2_miss = if2_current_miss_w ||
           (miss_hold_match_if2_w && !if2_hit) ||
           replay_start_w ||
           (replay_active_w && (replay_state_r != R_HIT_RESP)) ||
           if2_wait_data_w;
    assign if2_hit_way = compare_hit_way_w;
    assign if2_miss_ready = (state_r == S_IDLE) && !maint_busy_w &&
           ((!replay_active_w && !replay_start_w) ||
            (replay_state_r == R_MISS_READY) ||
            replay_hit_ready_w);


    assign if2_raw_refill_valid_w = (state_r == S_REFILL_RESP) ||
           (state_r == S_UNCACHE_RESP) ||
           (replay_state_r == R_HIT_RESP);
    assign if2_raw_refill_pa_w = (replay_state_r == R_HIT_RESP) ? replay_pa_r :
           (state_r == S_UNCACHE_RESP) ? uncache_pa_r : miss_pa_r;
    assign if2_refill_valid = if2_raw_refill_valid_w && (if2_raw_refill_pa_w == if2_pa);


    genvar bsel;
    generate
        for (bsel = 0; bsel < `CACHE_BANKS; bsel = bsel + 1) begin : gen_data_sel
            assign hit_data_w[bsel] = compare_hit_way_w ? way1_data_w[bsel] :
                   way0_data_w[bsel];
            assign replay_sel_w[bsel] = replay_compare_hit_way_w ? way1_data_w[bsel] :
                   way0_data_w[bsel];
            // uncache 也读整行8个字，统一用 miss_data_r[]
            assign refill_data_w[bsel] =
                   (replay_state_r == R_HIT_RESP) ? replay_data_r[bsel] :
                   miss_data_r[bsel];
            assign if2_data_w[bsel] = if2_hit ? hit_data_w[bsel] :
                   refill_data_w[bsel];
        end
    endgenerate

    assign if2_data0 = if2_data_w[0];
    assign if2_data1 = if2_data_w[1];
    assign if2_data2 = if2_data_w[2];
    assign if2_data3 = if2_data_w[3];
    assign if2_data4 = if2_data_w[4];
    assign if2_data5 = if2_data_w[5];
    assign if2_data6 = if2_data_w[6];
    assign if2_data7 = if2_data_w[7];
    assign if2_served_w = if2_hit || if2_refill_valid;
    assign if2_served_pa_w = if2_hit ? if2_pa :
           (replay_state_r == R_HIT_RESP) ? replay_pa_r :
           (state_r == S_UNCACHE_RESP) ? uncache_pa_r : miss_pa_r;

    assign external_miss_fire_w = if2_miss_req && if2_miss_ready && if2_miss && !replay_hit_ready_w;
    assign replay_miss_fire_w = (replay_state_r == R_MISS_READY) && miss_hold_valid_r && (state_r == S_IDLE) && !maint_busy_w;
    assign miss_req_fire_w = external_miss_fire_w || replay_miss_fire_w;
    assign miss_source_cacheable_w = miss_hold_use_w ? miss_hold_cacheable_r : (if2_mat == CACHEABLE_MAT);
    assign miss_source_pa_w = miss_hold_use_w ? miss_hold_pa_r : if2_pa;
    assign miss_source_index_w = miss_hold_use_w ? miss_hold_index_r : if2_index_w;
    assign miss_source_tag_w = miss_hold_use_w ? miss_hold_tag_r : if2_tag_w;
    assign miss_source_way_w = miss_hold_use_w ? miss_hold_way_r : replace_way_w;

    assign replace_update_w = miss_req_fire_w && miss_source_cacheable_w;
    assign replace_victim_index_w = replay_wait_miss_w ? replay_index_r : if2_index_w;
    assign replace_access_valid_w = replace_update_w ||
           if2_hit ||
           (replay_resp_valid_w && replay_compare_hit_w);
    assign replace_access_index_w = replace_update_w ? miss_source_index_w :
           (replay_resp_valid_w && replay_compare_hit_w) ? replay_index_r :
           if2_index_w;
    assign replace_access_way_w = replace_update_w ? miss_source_way_w :
           (replay_resp_valid_w && replay_compare_hit_w) ? replay_compare_hit_way_w :
           compare_hit_way_w;

    assign lookup_lru_victim_way_w =
           (replace_access_valid_w && (replace_access_index_w == lookup_index_w)) ?
           ~replace_access_way_w :
           lookup_lru_victim_way_from_replace_w;

    assign miss_lru_victim_way_w = replay_wait_miss_w ? replay_lookup_meta_lru_victim_way_r :
           lookup_meta_lru_victim_way_r;

    assign replace_way_w = !way0_valid_w ? 1'b0 :
           !way1_valid_w ? 1'b1 :
           miss_lru_victim_way_w;

    assign rd_req_w = (state_r == S_REFILL_REQ) || (state_r == S_UNCACHE_REQ);

    // 整行到达即写数组：tag + 8 bank + valid 一拍写完。
    assign refill_valid_w = (state_r == S_REFILL) && ret_valid_w;


    assign maint_accept_w = maint_valid &&
           (state_r == S_IDLE) &&
           !maint_busy_w &&
           !replay_active_w &&
           !replay_start_w &&
           !if2_miss_req;
    assign maint_hit_lookup_w = maint_state_r == M_LOOKUP;
    assign maint_hit_check_w = maint_state_r == M_CHECK;
    assign maint_hit_w = maint_hit_check_w && array_valid_w && ((way0_valid_w && (way0_tag_w == maint_tag_r)) || (way1_valid_w && (way1_tag_w == maint_tag_r)));
    assign maint_hit_way_w = way1_valid_w && (way1_tag_w == maint_tag_r);
    assign maint_clear_valid_w = maint_state_r == M_CLEAR;
    assign maint_addr_ok = maint_accept_w;
    assign maint_data_ok = maint_state_r == M_RESP;

    icache_array u_array (
                     .clk (clk),
                     .resetn (resetn),
                     .lookup_valid (lookup_valid_w),
                     .lookup_index (lookup_index_w),
                     .refill_valid (refill_valid_w),
                     .refill_way (miss_way_r),
                     .refill_index (miss_index_r),
                     .refill_tag (miss_tag_r),
                     .refill_line (ret_line_w),
                     .maint_clear_valid (maint_clear_valid_w),
                     .maint_clear_way (maint_way_r),
                     .maint_clear_index (maint_index_r),
                     .lookup_refill_conflict(lookup_refill_conflict_w),
                     .if2_array_valid (array_valid_w),
                     .way0_valid (way0_valid_w),
                     .way0_tag (way0_tag_w),
                     .way0_data0 (way0_data_w[0]),
                     .way0_data1 (way0_data_w[1]),
                     .way0_data2 (way0_data_w[2]),
                     .way0_data3 (way0_data_w[3]),
                     .way0_data4 (way0_data_w[4]),
                     .way0_data5 (way0_data_w[5]),
                     .way0_data6 (way0_data_w[6]),
                     .way0_data7 (way0_data_w[7]),
                     .way1_valid (way1_valid_w),
                     .way1_tag (way1_tag_w),
                     .way1_data0 (way1_data_w[0]),
                     .way1_data1 (way1_data_w[1]),
                     .way1_data2 (way1_data_w[2]),
                     .way1_data3 (way1_data_w[3]),
                     .way1_data4 (way1_data_w[4]),
                     .way1_data5 (way1_data_w[5]),
                     .way1_data6 (way1_data_w[6]),
                     .way1_data7 (way1_data_w[7])
                 );

    cache_hit_compare u_compare (
                          .req_valid (if2_array_valid),
                          .req_tag (if2_tag_w),
                          .way0_valid(way0_valid_w),
                          .way0_dirty(1'b0),
                          .way0_tag (way0_tag_w),
                          .way0_rdata({`CACHE_WORD_WIDTH{1'b0}}),
                          .way1_valid(way1_valid_w),
                          .way1_dirty(1'b0),
                          .way1_tag (way1_tag_w),
                          .way1_rdata({`CACHE_WORD_WIDTH{1'b0}}),
                          .hit (compare_hit_w),
                          .hit_way (compare_hit_way_w),
                          .hit_dirty (compare_hit_dirty_unused_w),
                          .hit_rdata ()
                      );

    cache_hit_compare u_replay_compare (
                          .req_valid (replay_resp_valid_w),
                          .req_tag (replay_tag_r),
                          .way0_valid(way0_valid_w),
                          .way0_dirty(1'b0),
                          .way0_tag (way0_tag_w),
                          .way0_rdata({`CACHE_WORD_WIDTH{1'b0}}),
                          .way1_valid(way1_valid_w),
                          .way1_dirty(1'b0),
                          .way1_tag (way1_tag_w),
                          .way1_rdata({`CACHE_WORD_WIDTH{1'b0}}),
                          .hit (replay_compare_hit_w),
                          .hit_way (replay_compare_hit_way_w),
                          .hit_dirty (replay_compare_hit_dirty_unused_w),
                          .hit_rdata ()
                      );

    l1_replace u_replace (
                   .clk (clk),
                   .resetn (resetn),
                   .way0_valid (way0_valid_w),
                   .way1_valid (way1_valid_w),
                   .victim_index(replace_victim_index_w),
                   .lookup_index(lookup_index_w),
                   .access_valid(replace_access_valid_r),
                   .access_index(replace_access_index_r),
                   .access_way(replace_access_way_r),
                   .replace_way (replace_way_raw_unused_w),
                   .lru_victim_way(lru_victim_way_w),
                   .lookup_lru_victim_way(lookup_lru_victim_way_from_replace_w)
               );

    icache_l2_read u_l2_read (
                       .clk (clk),
                       .resetn (resetn),
                       .rd_req (rd_req_w),
                       .rd_addr ((state_r == S_UNCACHE_REQ) ?
                                 {uncache_pa_r[31:`CACHE_OFFSET_WIDTH], {`CACHE_OFFSET_WIDTH{1'b0}}} :
                                 {miss_pa_r[31:`CACHE_OFFSET_WIDTH], {`CACHE_OFFSET_WIDTH{1'b0}}}),
                       .rd_line (state_r == S_REFILL_REQ || state_r == S_UNCACHE_REQ),
                       .rd_ready (rd_ready_w),

                       .arid (arid),
                       .araddr (araddr),
                       .arlen (arlen),
                       .arsize (arsize),
                       .arburst (arburst),
                       .arvalid (arvalid),
                       .arready (arready),
                       .rline (rline),
                       .rvalid (rvalid),
                       .rready (rready),

                       .ret_valid(ret_valid_w),
                       .ret_line (ret_line_w)
                   );

    always @(posedge clk) begin
        if (!resetn) begin
            state_r <= S_IDLE;
            maint_state_r <= M_IDLE;
            miss_hold_valid_r <= 1'b0;
            miss_hold_cacheable_r <= 1'b0;
            lookup_meta_if1_valid_r <= 1'b0;
            replay_state_r <= R_IDLE;
            replay_lookup_meta_valid_r <= 1'b0;
            replay_block_valid_r <= 1'b0;
            replace_access_valid_r <= 1'b0;
        end
        else begin

            replace_access_valid_r <= replace_access_valid_w;
            replace_access_index_r <= replace_access_index_w;
            replace_access_way_r <= replace_access_way_w;

            lookup_meta_if1_valid_r <= if1_lookup_accept_w;

            if (if1_lookup_accept_w) begin
                lookup_meta_index_r <= if1_index_w;
                lookup_meta_lru_victim_way_r <= lookup_lru_victim_way_w;
            end

            replay_lookup_meta_valid_r <= replay_lookup_accept_w;
            if (replay_lookup_accept_w) begin
                replay_lookup_meta_lru_victim_way_r <= lookup_lru_victim_way_w;
            end
            if (if2_served_w && (if2_served_pa_w == if2_pa)) begin
                replay_block_valid_r <= 1'b1;
                replay_block_pa_r <= if2_served_pa_w;
            end
            else if (!if2_valid) begin
                replay_block_valid_r <= 1'b0;
            end
            else if (replay_block_valid_r && (if2_pa != replay_block_pa_r)) begin
                replay_block_valid_r <= 1'b0;
            end

            if (replay_start_w) begin
                replay_state_r <= R_LOOKUP;
                replay_pa_r <= if2_pa;
                replay_index_r <= if2_index_w;
                replay_tag_r <= if2_tag_w;
            end
            else begin
                case (replay_state_r)
                    R_IDLE: begin
                        replay_state_r <= R_IDLE;
                    end

                    R_LOOKUP: begin
                        if (replay_lookup_accept_w) begin
                            replay_state_r <= R_WAIT;
                        end
                    end

                    R_WAIT: begin
                        if (replay_resp_valid_w && replay_compare_hit_w) begin
                            for (i = 0; i < `CACHE_BANKS; i = i + 1) begin
                                replay_data_r[i] <= replay_sel_w[i];
                            end
                            replay_state_r <= R_HIT_READY;
                        end
                        else if (replay_wait_miss_w) begin
                            replay_state_r <= R_MISS_READY;
                        end
                    end

                    R_HIT_READY: begin
                        if (replay_hit_fire_w) begin
                            replay_state_r <= R_HIT_RESP;
                        end
                    end

                    R_MISS_READY: begin
                        if (miss_req_fire_w) begin
                            replay_state_r <= R_IDLE;
                        end
                    end

                    R_HIT_RESP: begin
                        replay_state_r <= R_IDLE;
                    end

                    default: begin
                        replay_state_r <= R_IDLE;
                    end
                endcase
            end

            if (miss_req_fire_w) begin
                miss_hold_valid_r <= 1'b0;
            end
            else if (replay_wait_miss_w) begin
                miss_hold_valid_r <= 1'b1;
                miss_hold_cacheable_r <= 1'b1;

                miss_hold_pa_r <= replay_pa_r;
                miss_hold_index_r <= replay_index_r;
                miss_hold_tag_r <= replay_tag_r;
                miss_hold_way_r <= replace_way_w;
            end
            else if (if2_current_miss_w) begin
                miss_hold_valid_r <= 1'b1;
                miss_hold_cacheable_r <= (if2_mat == CACHEABLE_MAT);

                miss_hold_pa_r <= if2_pa;
                miss_hold_index_r <= if2_index_w;
                miss_hold_tag_r <= if2_tag_w;
                miss_hold_way_r <= replace_way_w;
            end
            else if (miss_hold_hit_cancel_w || miss_hold_mismatch_w) begin
                miss_hold_valid_r <= 1'b0;
            end

            if (miss_req_fire_w && miss_source_cacheable_w) begin
                miss_pa_r <= miss_source_pa_w;
                miss_index_r <= miss_source_index_w;
                miss_tag_r <= miss_source_tag_w;
                miss_way_r <= miss_source_way_w;

                for (i = 0; i < `CACHE_BANKS; i = i + 1) begin
                    miss_data_r[i] <= {`CACHE_WORD_WIDTH{1'b0}};
                end

                state_r <= S_REFILL_REQ;
            end
            else if (miss_req_fire_w) begin
                uncache_pa_r <= miss_source_pa_w;

                // 非缓存也用 miss_data_r[] 数组
                for (i = 0; i < `CACHE_BANKS; i = i + 1) begin
                    miss_data_r[i] <= {`CACHE_WORD_WIDTH{1'b0}};
                end

                state_r <= S_UNCACHE_REQ;
            end
            else begin
                case (state_r)

                    S_IDLE: begin
                        state_r <= S_IDLE;
                    end

                    S_REFILL_REQ: begin
                        if (rd_ready_w) begin
                            state_r <= S_REFILL;
                        end
                    end

                    S_REFILL: begin
                        // 整行一拍到齐：同拍写数组、同拍寄下整行 8 个字。
                        if (ret_valid_w) begin
                            for (i = 0; i < `CACHE_BANKS; i = i + 1) begin
                                miss_data_r[i] <= ret_line_w[i*`CACHE_WORD_WIDTH +:
                                                             `CACHE_WORD_WIDTH];
                            end
                            state_r <= S_REFILL_RESP;
                        end
                    end

                    S_REFILL_RESP: begin
                        state_r <= S_IDLE;
                    end

                    S_UNCACHE_REQ: begin
                        if (rd_ready_w) begin
                            state_r <= S_UNCACHE_WAIT;
                        end
                    end

                    S_UNCACHE_WAIT: begin
                        // uncached 也读整行：存8个字到miss_data_r数组。
                        if (ret_valid_w) begin
                            for (i = 0; i < `CACHE_BANKS; i = i + 1) begin
                                miss_data_r[i] <= ret_line_w[i*`CACHE_WORD_WIDTH +: `CACHE_WORD_WIDTH];
                            end
                            state_r <= S_UNCACHE_RESP;
                        end
                    end

                    S_UNCACHE_RESP: begin
                        state_r <= S_IDLE;
                    end

                    default: begin
                        state_r <= S_IDLE;
                    end

                endcase
            end

            if (maint_accept_w) begin
                maint_way_r <= maint_way;
                maint_index_r <= maint_index;
                maint_tag_r <= maint_tag;

                maint_state_r <= (maint_op == `CACHE_CACOP_MAINT_HIT_INV) ? M_LOOKUP : M_CLEAR;
            end
            else begin
                case (maint_state_r)

                    M_IDLE: begin
                        maint_state_r <= M_IDLE;
                    end

                    M_LOOKUP: begin
                        maint_state_r <= M_CHECK;
                    end

                    M_CHECK: begin
                        if (array_valid_w && maint_hit_w) begin
                            maint_way_r <= maint_hit_way_w;
                            maint_state_r <= M_CLEAR;
                        end
                        else begin
                            maint_state_r <= M_RESP;
                        end
                    end

                    M_CLEAR: begin
                        maint_state_r <= M_RESP;
                    end

                    M_RESP: begin
                        maint_state_r <= M_IDLE;
                    end

                    default: begin
                        maint_state_r <= M_IDLE;
                    end

                endcase
            end
        end
    end

    // ICache  Counters
`ifdef PERF_COUNTER
    reg [31:0] perf_icache_total_access;
    reg [31:0] perf_icache_l1_hit;
    reg [31:0] perf_icache_l1_miss;
    reg [31:0] perf_icache_vb_hit;
    reg [31:0] perf_icache_uncached_access;

    always @(posedge clk) begin
        if (!resetn) begin
            perf_icache_total_access <= 32'b0;
            perf_icache_l1_hit <= 32'b0;
            perf_icache_l1_miss <= 32'b0;
            perf_icache_vb_hit <= 32'b0;
            perf_icache_uncached_access <= 32'b0;
        end
        else begin
            if (if2_array_valid && !miss_hold_match_if2_w && !if2_served_same_w) begin
                perf_icache_total_access <= perf_icache_total_access + 1;
            end

            if (if2_hit && !miss_hold_match_if2_w) begin
                perf_icache_l1_hit <= perf_icache_l1_hit + 1;
            end

            if (if2_array_valid && if2_vb_hit_w && !miss_hold_match_if2_w) begin
                perf_icache_vb_hit <= perf_icache_vb_hit + 1;
            end

            if (miss_req_fire_w && miss_source_cacheable_w) begin
                perf_icache_l1_miss <= perf_icache_l1_miss + 1;
            end

            if (miss_req_fire_w && !miss_source_cacheable_w) begin
                perf_icache_uncached_access <= perf_icache_uncached_access + 1;
            end
        end
    end
`endif

endmodule

