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
    output wire [`CACHE_WORD_WIDTH-1:0] if2_rdata,
    output wire if2_refill_valid,
    output wire [`CACHE_WORD_WIDTH-1:0] if2_refill_rdata,
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

    reg [31:0] miss_pa_r;
    reg [`CACHE_INDEX_WIDTH-1:0] miss_index_r;
    reg [`CACHE_BANK_WIDTH-1:0] miss_bank_r;
    reg [`CACHE_TAG_WIDTH-1:0] miss_tag_r;
    reg miss_way_r;
    reg [`CACHE_WORD_WIDTH-1:0] miss_rdata_r;

    reg miss_hold_valid_r;
    reg miss_hold_cacheable_r;
    reg [31:0] miss_hold_pa_r;
    reg [`CACHE_INDEX_WIDTH-1:0] miss_hold_index_r;
    reg [`CACHE_BANK_WIDTH-1:0] miss_hold_bank_r;
    reg [`CACHE_TAG_WIDTH-1:0] miss_hold_tag_r;
    reg miss_hold_way_r;

    reg lookup_meta_if1_valid_r;
    reg [`CACHE_INDEX_WIDTH-1:0] lookup_meta_index_r;
    reg [`CACHE_BANK_WIDTH-1:0] lookup_meta_bank_r;
    reg lookup_meta_lru_victim_way_r;

    reg [2:0] replay_state_r;
    reg [31:0] replay_pa_r;
    reg [`CACHE_INDEX_WIDTH-1:0] replay_index_r;
    reg [`CACHE_BANK_WIDTH-1:0] replay_bank_r;
    reg [`CACHE_TAG_WIDTH-1:0] replay_tag_r;
    reg [`CACHE_WORD_WIDTH-1:0] replay_rdata_r;
    reg replay_lookup_meta_valid_r;
    reg replay_lookup_meta_lru_victim_way_r;
    reg replay_block_valid_r;
    reg [31:0] replay_block_pa_r;

    reg replace_access_valid_r;
    reg [`CACHE_INDEX_WIDTH-1:0] replace_access_index_r;
    reg replace_access_way_r;

    reg [31:0] uncache_pa_r;
    reg [`CACHE_WORD_WIDTH-1:0] uncache_rdata_r;

    wire lookup_valid_w;
    wire [`CACHE_INDEX_WIDTH-1:0] lookup_index_w;
    wire [`CACHE_BANK_WIDTH-1:0] lookup_bank_w;
    wire lookup_refill_conflict_w;

    wire [`CACHE_INDEX_WIDTH-1:0] if1_index_w;
    wire [`CACHE_BANK_WIDTH-1:0] if1_bank_w;

    wire [`CACHE_INDEX_WIDTH-1:0] if2_index_w;
    wire [`CACHE_BANK_WIDTH-1:0] if2_bank_w;
    wire [`CACHE_TAG_WIDTH-1:0] if2_tag_w;

    wire way0_valid_w;
    wire [`CACHE_TAG_WIDTH-1:0] way0_tag_w;
    wire [`CACHE_WORD_WIDTH-1:0] way0_rdata_w;

    wire way1_valid_w;
    wire [`CACHE_TAG_WIDTH-1:0] way1_tag_w;
    wire [`CACHE_WORD_WIDTH-1:0] way1_rdata_w;

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
    wire [`CACHE_WORD_WIDTH-1:0] compare_rdata_w;

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
    wire [`CACHE_WORD_WIDTH-1:0] replay_compare_rdata_w;
    wire replay_hit_ready_w;
    wire replay_hit_fire_w;
    wire replay_wait_miss_w;

    wire if2_current_miss_w;
    wire if2_raw_refill_valid_w;
    wire [`CACHE_WORD_WIDTH-1:0] if2_raw_refill_rdata_w;
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
    wire [`CACHE_BANK_WIDTH-1:0] miss_source_bank_w;
    wire [`CACHE_TAG_WIDTH-1:0] miss_source_tag_w;
    wire miss_source_way_w;

    wire rd_req_w;
    wire rd_ready_w;

    wire ret_valid_w;
    wire [`CACHE_LINE_WIDTH-1:0] ret_line_w;

    wire refill_valid_w;
    // 整行到达那一拍从行里选出目标字（给 IF2 的取指结果）。
    wire [`CACHE_WORD_WIDTH-1:0] ret_target_word_w;

    wire maint_busy_w;
    wire maint_accept_w;
    wire maint_hit_lookup_w;
    wire maint_hit_check_w;
    wire maint_hit_w;
    wire maint_hit_way_w;
    wire maint_clear_valid_w;

    wire array_valid_w;

    assign if1_index_w = if1_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
    assign if1_bank_w = if1_va[`CACHE_BANK_MSB:`CACHE_BANK_LSB];
    assign if2_index_w = if2_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
    assign if2_bank_w = if2_va[`CACHE_BANK_MSB:`CACHE_BANK_LSB];
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
    assign lookup_bank_w = maint_hit_lookup_w ? {`CACHE_BANK_WIDTH{1'b0}} :
                           replay_lookup_req_w ? replay_bank_r :
                           if1_bank_w;

    assign if1_lookup_accept_w = if1_lookup_fire_w && !maint_hit_lookup_w && !replay_lookup_req_w && !lookup_refill_conflict_w;
    assign replay_lookup_accept_w = replay_lookup_req_w && !maint_hit_lookup_w && !lookup_refill_conflict_w;
    assign if2_lookup_match_w = array_valid_w && lookup_meta_if1_valid_r && (lookup_meta_index_r == if2_index_w) && (lookup_meta_bank_r == if2_bank_w);
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
    assign if2_rdata = compare_rdata_w;
    assign if2_miss_ready = (state_r == S_IDLE) && !maint_busy_w &&
                            ((!replay_active_w && !replay_start_w) ||
                             (replay_state_r == R_MISS_READY) ||
                             replay_hit_ready_w);

    // 整行一拍到齐、一拍写完，S_REFILL_RESP 那拍行已经在数组里可见了，
    // 所以不再需要 early restart（原来那套是为了「8 个 beat 里目标字
    // 先到就放行」，现在没有可提前的对象了）。
    assign if2_raw_refill_valid_w = (state_r == S_REFILL_RESP) ||
                                    (state_r == S_UNCACHE_RESP) ||
                                    (replay_state_r == R_HIT_RESP);
    assign if2_raw_refill_rdata_w = (replay_state_r == R_HIT_RESP) ? replay_rdata_r :
                                    (state_r == S_UNCACHE_RESP) ? uncache_rdata_r :
                                    miss_rdata_r;
    assign if2_raw_refill_pa_w = (replay_state_r == R_HIT_RESP) ? replay_pa_r :
                                 (state_r == S_UNCACHE_RESP) ? uncache_pa_r : miss_pa_r;
    assign if2_refill_valid = if2_raw_refill_valid_w && (if2_raw_refill_pa_w == if2_pa);
    assign if2_refill_rdata = if2_raw_refill_rdata_w;
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
    assign miss_source_bank_w = miss_hold_use_w ? miss_hold_bank_r : if2_bank_w;
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

    // 从整行里取出第 bank 个字（bank0 在最低 32 位）。
    function [`CACHE_WORD_WIDTH-1:0] select_line_word;
        input [`CACHE_LINE_WIDTH-1:0] line_data;
        input [`CACHE_BANK_WIDTH-1:0] bank;
        begin
            case (bank)
                3'd0: select_line_word = line_data[31:0];
                3'd1: select_line_word = line_data[63:32];
                3'd2: select_line_word = line_data[95:64];
                3'd3: select_line_word = line_data[127:96];
                3'd4: select_line_word = line_data[159:128];
                3'd5: select_line_word = line_data[191:160];
                3'd6: select_line_word = line_data[223:192];
                default: select_line_word = line_data[255:224];
            endcase
        end
    endfunction

    // 整行到达即写数组：tag + 8 bank + valid 一拍写完。
    assign refill_valid_w = (state_r == S_REFILL) && ret_valid_w;

    // 目标字从整行里选出来，寄进 miss_rdata_r，下一拍（S_REFILL_RESP）交给 IF2。
    assign ret_target_word_w = select_line_word(ret_line_w, miss_bank_r);

    // Maintenance requests are ordered by the CPU side CACOP stall.  Once the
    // I-cache internal engines are idle, accept the request even if IF2 still
    // holds a stale/waiting miss indication.  Gating this with if2_miss can
    // deadlock: CACOP is already pending, frontend is stalled by CACOP, and the
    // stale IF2 miss can no longer make forward progress to clear itself.
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
        .lookup_bank (lookup_bank_w),
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
        .way0_rdata (way0_rdata_w),
        .way1_valid (way1_valid_w),
        .way1_tag (way1_tag_w),
        .way1_rdata (way1_rdata_w)
    );

    cache_hit_compare u_compare (
        .req_valid (if2_array_valid),
        .req_tag (if2_tag_w),
        .way0_valid(way0_valid_w),
        .way0_dirty(1'b0),
        .way0_tag (way0_tag_w),
        .way0_rdata(way0_rdata_w),
        .way1_valid(way1_valid_w),
        .way1_dirty(1'b0),
        .way1_tag (way1_tag_w),
        .way1_rdata(way1_rdata_w),
        .hit (compare_hit_w),
        .hit_way (compare_hit_way_w),
        .hit_dirty (compare_hit_dirty_unused_w),
        .hit_rdata (compare_rdata_w)
    );

    cache_hit_compare u_replay_compare (
        .req_valid (replay_resp_valid_w),
        .req_tag (replay_tag_r),
        .way0_valid(way0_valid_w),
        .way0_dirty(1'b0),
        .way0_tag (way0_tag_w),
        .way0_rdata(way0_rdata_w),
        .way1_valid(way1_valid_w),
        .way1_dirty(1'b0),
        .way1_tag (way1_tag_w),
        .way1_rdata(way1_rdata_w),
        .hit (replay_compare_hit_w),
        .hit_way (replay_compare_hit_way_w),
        .hit_dirty (replay_compare_hit_dirty_unused_w),
        .hit_rdata (replay_compare_rdata_w)
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
        .rd_addr ((state_r == S_UNCACHE_REQ) ? uncache_pa_r :
                  {miss_pa_r[31:`CACHE_OFFSET_WIDTH],
                   {`CACHE_OFFSET_WIDTH{1'b0}}}),
        .rd_line (state_r == S_REFILL_REQ),
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
            maint_way_r <= 1'b0;
            maint_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
            maint_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};

            miss_pa_r <= 32'b0;
            miss_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
            miss_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
            miss_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
            miss_way_r <= 1'b0;
            miss_rdata_r <= {`CACHE_WORD_WIDTH{1'b0}};

            miss_hold_valid_r <= 1'b0;
            miss_hold_cacheable_r <= 1'b0;
            miss_hold_pa_r <= 32'b0;
            miss_hold_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
            miss_hold_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
            miss_hold_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
            miss_hold_way_r <= 1'b0;

            lookup_meta_if1_valid_r <= 1'b0;
            lookup_meta_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
            lookup_meta_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
            lookup_meta_lru_victim_way_r <= 1'b0;

            replay_state_r <= R_IDLE;
            replay_pa_r <= 32'b0;
            replay_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
            replay_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
            replay_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
            replay_rdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
            replay_lookup_meta_valid_r <= 1'b0;
            replay_lookup_meta_lru_victim_way_r <= 1'b0;
            replay_block_valid_r <= 1'b0;
            replay_block_pa_r <= 32'b0;

            replace_access_valid_r <= 1'b0;
            replace_access_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
            replace_access_way_r <= 1'b0;

            uncache_pa_r <= 32'b0;
            uncache_rdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        end else begin

            replace_access_valid_r <= replace_access_valid_w;
            replace_access_index_r <= replace_access_index_w;
            replace_access_way_r <= replace_access_way_w;

            lookup_meta_if1_valid_r <= if1_lookup_accept_w;

            if (if1_lookup_accept_w) begin
                lookup_meta_index_r <= if1_index_w;
                lookup_meta_bank_r <= if1_bank_w;
                lookup_meta_lru_victim_way_r <= lookup_lru_victim_way_w;
            end

            replay_lookup_meta_valid_r <= replay_lookup_accept_w;
            if (replay_lookup_accept_w) begin
                replay_lookup_meta_lru_victim_way_r <= lookup_lru_victim_way_w;
            end
            if (if2_served_w && (if2_served_pa_w == if2_pa)) begin
                replay_block_valid_r <= 1'b1;
                replay_block_pa_r <= if2_served_pa_w;
            end else if (!if2_valid) begin
                replay_block_valid_r <= 1'b0;
            end else if (replay_block_valid_r && (if2_pa != replay_block_pa_r)) begin
                replay_block_valid_r <= 1'b0;
            end

            if (replay_start_w) begin
                replay_state_r <= R_LOOKUP;
                replay_pa_r <= if2_pa;
                replay_index_r <= if2_index_w;
                replay_bank_r <= if2_bank_w;
                replay_tag_r <= if2_tag_w;
            end else begin
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
                            replay_rdata_r <= replay_compare_rdata_w;
                            replay_state_r <= R_HIT_READY;
                        end else if (replay_wait_miss_w) begin
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
                miss_hold_bank_r <= replay_bank_r;
                miss_hold_tag_r <= replay_tag_r;
                miss_hold_way_r <= replace_way_w;
            end
            else if (if2_current_miss_w) begin
                miss_hold_valid_r <= 1'b1;
                miss_hold_cacheable_r <= (if2_mat == CACHEABLE_MAT);

                miss_hold_pa_r <= if2_pa;
                miss_hold_index_r <= if2_index_w;
                miss_hold_bank_r <= if2_bank_w;
                miss_hold_tag_r <= if2_tag_w;
                miss_hold_way_r <= replace_way_w;
            end
            else if (miss_hold_hit_cancel_w || miss_hold_mismatch_w) begin
                miss_hold_valid_r <= 1'b0;
            end

            if (miss_req_fire_w && miss_source_cacheable_w) begin
                miss_pa_r <= miss_source_pa_w;
                miss_index_r <= miss_source_index_w;
                miss_bank_r <= miss_source_bank_w;
                miss_tag_r <= miss_source_tag_w;
                miss_way_r <= miss_source_way_w;

                miss_rdata_r <= {`CACHE_WORD_WIDTH{1'b0}};

                state_r <= S_REFILL_REQ;
            end
            else if (miss_req_fire_w) begin
                uncache_pa_r <= miss_source_pa_w;
                uncache_rdata_r <= {`CACHE_WORD_WIDTH{1'b0}};

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
                        // 整行一拍到齐：同拍写数组、同拍寄下目标字。
                        if (ret_valid_w) begin
                            miss_rdata_r <= ret_target_word_w;
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
                        // uncached 单字读：目标字在整行最低 32 位。
                        if (ret_valid_w) begin
                            uncache_rdata_r <= ret_line_w[`CACHE_WORD_WIDTH-1:0];
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
                        end else begin
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

endmodule
