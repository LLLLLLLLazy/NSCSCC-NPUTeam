`include "cache_defs.vh"
`include "l2_cache_defs.vh"

module l2_cache_core (
    input wire clk,
    input wire resetn,

    input wire req_valid,
    output wire req_ready,
    input wire [`L2_SOURCE_WIDTH-1:0] req_source,
    input wire [`L2_OPCODE_WIDTH-1:0] req_opcode,
    input wire req_uncached,
    input wire [31:0] req_addr,
    input wire [1:0] req_size,
    input wire [`L2_WSTRB_WIDTH-1:0] req_wstrb,
    input wire [`L2_LINE_WIDTH-1:0] req_line_data,

    output wire resp_valid,
    input wire resp_ready,
    output wire [`L2_SOURCE_WIDTH-1:0] resp_source,
    output wire [`L2_LINE_WIDTH-1:0] resp_line_data,
    output wire resp_error,

    output wire [3:0] arid,
    output wire [31:0] araddr,
    output wire [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    output wire [1:0] arlock,
    output wire [3:0] arcache,
    output wire [2:0] arprot,
    output wire arvalid,
    input wire arready,
    input wire [3:0] rid,
    input wire [31:0] rdata,
    input wire [1:0] rresp,
    input wire rlast,
    input wire rvalid,
    output wire rready,

    output wire [3:0] awid,
    output wire [31:0] awaddr,
    output wire [7:0] awlen,
    output wire [2:0] awsize,
    output wire [1:0] awburst,
    output wire [1:0] awlock,
    output wire [3:0] awcache,
    output wire [2:0] awprot,
    output wire awvalid,
    input wire awready,
    output wire [3:0] wid,
    output wire [`L2_WORD_WIDTH-1:0] wdata,
    output wire [`L2_WSTRB_WIDTH-1:0] wstrb,
    output wire wlast,
    output wire wvalid,
    input wire wready,
    input wire [3:0] bid,
    input wire [1:0] bresp,
    input wire bvalid,
    output wire bready
);

localparam [4:0] S_RESET_SCAN    = 5'd0;
localparam [4:0] S_IDLE          = 5'd1;
localparam [4:0] S_LOOKUP_WAIT   = 5'd2;
localparam [4:0] S_SELECT_VICTIM = 5'd3;
localparam [4:0] S_MEM_READ_REQ  = 5'd4;
localparam [4:0] S_MEM_READ_DATA = 5'd5;
localparam [4:0] S_REFILL_UPDATE = 5'd6;
localparam [4:0] S_RESP          = 5'd7;
localparam [4:0] S_FULL_LINE_ALLOCATE = 5'd8;
localparam [4:0] S_BLOCKING_WB_REQ = 5'd9;
// 原 S_BLOCKING_WB_WAIT(5'd10) 已删除：脏行写回不再阻塞 refill。
// AW 握手成功后直接去发 AR，写回在后台排空，由 wb_inflight_r 跟踪。
// 编码 5'd10 空出不再使用（CACOP 的 S_MAINT_WB_WAIT 仍保持阻塞语义）。
localparam [4:0] S_UNCACHED_READ_REQ = 5'd11;
localparam [4:0] S_UNCACHED_READ_WAIT = 5'd12;
localparam [4:0] S_UNCACHED_WRITE_REQ = 5'd13;
localparam [4:0] S_UNCACHED_WRITE_WAIT = 5'd14;
localparam [4:0] S_MAINT_LOOKUP_WAIT = 5'd15;
localparam [4:0] S_MAINT_CHECK = 5'd16;
localparam [4:0] S_MAINT_WB_REQ = 5'd17;
localparam [4:0] S_MAINT_WB_WAIT = 5'd18;
localparam [4:0] S_MAINT_CLEAR = 5'd19;
localparam [4:0] S_MAINT_NEXT = 5'd20;
localparam [4:0] S_CAPTURE_VICTIM = 5'd21;
localparam [`L2_INDEX_WIDTH-1:0] RESET_SCAN_LAST = `L2_SETS - 1;

reg [4:0] state_r;
reg init_done_r;
// 脏行写回已发出 AW、但还没收到 B 响应。
// 置起期间主状态机可以继续往前跑（发 AR、收 refill、写数组、回响应），
// 只有「接受下一个新请求」被挡住 —— 见 req_ready。
reg wb_inflight_r;
reg [`L2_INDEX_WIDTH-1:0] reset_scan_index_r;

reg [`L2_SOURCE_WIDTH-1:0] ctx_source_r;
reg [`L2_OPCODE_WIDTH-1:0] ctx_opcode_r;
reg ctx_uncached_r;
reg [31:0] ctx_addr_r;
reg [`L2_TAG_WIDTH-1:0] ctx_tag_r;
reg [`L2_INDEX_WIDTH-1:0] ctx_index_r;
reg [`L2_BANK_WIDTH-1:0] ctx_bank_r;
reg [1:0] ctx_size_r;
reg [`L2_WSTRB_WIDTH-1:0] ctx_wstrb_r;
reg [`L2_LINE_WIDTH-1:0] ctx_line_data_r;
reg [1:0] maint_op_r;
reg [`L2_WAY_WIDTH-1:0] maint_way_r;
reg [`L2_WAY_WIDTH-1:0] victim_way_r;
reg victim_is_invalid_r;
reg [`L2_TAG_WIDTH-1:0] victim_tag_r;
reg [`L2_LINE_WIDTH-1:0] victim_line_data_r;
reg [`L2_LINE_WIDTH-1:0] refill_line_data_r;
reg [`L2_LINE_WIDTH-1:0] resp_line_data_r;
reg resp_error_r;
reg [31:0] l2_i_access_count;
reg [31:0] l2_d_access_count;
reg [31:0] l2_hit_count;
reg [31:0] l2_miss_count;
reg [31:0] l2_dirty_evict_count;
reg [31:0] l2_clean_evict_count;
reg [31:0] l2_refill_cycles;
reg [31:0] l2_writeback_cycles;
reg [31:0] victim_to_l2_write_count;
reg [31:0] uncached_read_count;
reg [31:0] uncached_write_count;

wire req_fire_w;
wire cached_lookup_req_w;
wire resp_fire_w;
wire cached_line_read_w;
wire cached_full_line_write_w;
wire req_uncached_read_w;
wire req_uncached_write_w;
wire req_maint_w;
wire full_line_write_mask_ok_w;
wire lookup_result_valid_w;
wire read_hit_w;
wire read_miss_w;
wire write_hit_w;
wire write_miss_w;
wire hit_success_w;
wire refill_update_w;
wire full_line_allocate_w;
wire tag_write_valid_w;
wire tag_write_dirty_w;
wire [`L2_WAY_WIDTH-1:0] tag_write_way_w;
wire replace_hit_valid_w;
wire replace_fill_valid_w;
wire replace_fill_low_priority_w;
wire replace_train_valid_w;
wire [`L2_WAY_WIDTH-1:0] hit_way_w;
wire [`L2_LINE_WIDTH-1:0] read_hit_line_data_w;
wire [`L2_TAG_WIDTH-1:0] victim_tag_w;
wire [`L2_LINE_WIDTH-1:0] victim_line_data_w;
wire victim_dirty_w;
wire victim_clean_or_invalid_w;
wire axi_read_req_w;
wire axi_read_line_w;
wire axi_read_ready_w;
wire axi_read_data_valid_w;
wire [`L2_WORD_WIDTH-1:0] axi_read_data_w;
wire [`L2_BANK_WIDTH-1:0] axi_read_beat_w;
wire axi_read_last_unused_w;
wire axi_read_done_w;
wire axi_write_req_w;
wire axi_write_line_w;
wire axi_write_ready_w;
wire axi_write_done_w;
wire [31:0] victim_addr_w;
wire victim_clean_valid_w;
wire [`L2_LINE_WIDTH-1:0] refill_line_next_w;
wire maint_lookup_req_w;
wire maint_index_mode_w;
wire maint_hit_mode_w;
wire maint_single_way_op_w;
wire [`L2_WAY_WIDTH-1:0] maint_req_way_w;
wire maint_current_valid_w;
wire maint_current_dirty_w;
wire maint_current_hit_w;
wire [`L2_TAG_WIDTH-1:0] maint_current_tag_w;
wire [`L2_LINE_WIDTH-1:0] maint_current_line_w;
wire maint_clear_valid_w;
wire l2_clear_valid_w;
wire [`L2_WAY_WIDTH-1:0] l2_clear_way_w;

wire tag_lookup_valid_out_w;
wire tag_lookup_hit_w;
wire [3:0] tag_lookup_hit_way_w;
wire [`L2_TAG_WIDTH-1:0] tag_lookup_tag_way0_w;
wire [`L2_TAG_WIDTH-1:0] tag_lookup_tag_way1_w;
wire [`L2_TAG_WIDTH-1:0] tag_lookup_tag_way2_w;
wire [`L2_TAG_WIDTH-1:0] tag_lookup_tag_way3_w;
wire tag_lookup_valid_way0_w;
wire tag_lookup_valid_way1_w;
wire tag_lookup_valid_way2_w;
wire tag_lookup_valid_way3_w;
wire tag_lookup_dirty_way0_w;
wire tag_lookup_dirty_way1_w;
wire tag_lookup_dirty_way2_w;
wire tag_lookup_dirty_way3_w;

wire [`L2_WORD_WIDTH-1:0] data_read_data0_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data1_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data2_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data3_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data4_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data5_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data6_w;
wire [`L2_WORD_WIDTH-1:0] data_read_data7_w;
wire data_read_valid_w;
wire [`L2_LINE_WIDTH-1:0] data_read_way0_line_w;
wire [`L2_LINE_WIDTH-1:0] data_read_way1_line_w;
wire [`L2_LINE_WIDTH-1:0] data_read_way2_line_w;
wire [`L2_LINE_WIDTH-1:0] data_read_way3_line_w;

wire [`L2_WAY_WIDTH-1:0] victim_way_w;
wire victim_is_invalid_w;

// !wb_inflight_r 是本次改造的正确性关键：
// 允许 refill 与写回并行，但不允许「下一个请求」在写回落地前开始。
// 否则若新请求恰好去读刚被逐出的那一行，读可能超过尚未完成的写，
// 从 DDR 拿到旧数据。等 B 响应（AXI 语义下写已被目标接受）再放行，
// 该 hazard 被完全排除，而 refill 提前发起的收益不受影响。
assign req_ready = init_done_r && (state_r == S_IDLE) && !wb_inflight_r;
assign req_fire_w = req_valid && req_ready;
assign cached_lookup_req_w = req_fire_w && !req_uncached &&
                             ((req_opcode == `L2_OP_CACHED_LINE_READ) ||
                              (req_opcode == `L2_OP_CACHED_FULL_LINE_WRITE));
assign resp_valid = state_r == S_RESP;
assign resp_fire_w = resp_valid && resp_ready;

assign resp_source = ctx_source_r;
assign resp_line_data = resp_line_data_r;
assign resp_error = resp_valid && resp_error_r;

assign cached_line_read_w = !ctx_uncached_r &&
                            (ctx_opcode_r == `L2_OP_CACHED_LINE_READ);
assign cached_full_line_write_w = !ctx_uncached_r &&
                                  (ctx_opcode_r == `L2_OP_CACHED_FULL_LINE_WRITE);
assign req_uncached_read_w = req_uncached &&
                             (req_opcode == `L2_OP_UNCACHED_READ);
assign req_uncached_write_w = req_uncached &&
                              (req_opcode == `L2_OP_UNCACHED_WRITE);
assign req_maint_w = !req_uncached &&
                     (req_opcode == `L2_OP_MAINT);
assign full_line_write_mask_ok_w = ctx_wstrb_r == {`L2_WSTRB_WIDTH{1'b1}};
assign lookup_result_valid_w = tag_lookup_valid_out_w && data_read_valid_w;
assign read_hit_w = (state_r == S_LOOKUP_WAIT) &&
                    cached_line_read_w && lookup_result_valid_w &&
                    tag_lookup_hit_w;
assign read_miss_w = (state_r == S_LOOKUP_WAIT) &&
                     cached_line_read_w && lookup_result_valid_w &&
                     !tag_lookup_hit_w;
assign write_hit_w = (state_r == S_LOOKUP_WAIT) &&
                     cached_full_line_write_w && full_line_write_mask_ok_w &&
                     lookup_result_valid_w && tag_lookup_hit_w;
assign write_miss_w = (state_r == S_LOOKUP_WAIT) &&
                      cached_full_line_write_w && full_line_write_mask_ok_w &&
                      lookup_result_valid_w && !tag_lookup_hit_w;
assign hit_success_w = read_hit_w || write_hit_w;
assign refill_update_w = state_r == S_REFILL_UPDATE;
assign full_line_allocate_w = state_r == S_FULL_LINE_ALLOCATE;
assign tag_write_valid_w = write_hit_w || full_line_allocate_w ||
                           refill_update_w;
assign tag_write_dirty_w = write_hit_w || full_line_allocate_w;
assign tag_write_way_w = (full_line_allocate_w || refill_update_w) ?
                         victim_way_r : hit_way_w;
// Hit 负责 Promotion。
assign replace_hit_valid_w =
    (read_hit_w && (ctx_source_r != `L2_SRC_PREFETCH)) ||
    write_hit_w;

// 所有 Cache Fill 都需要执行 DRRIP Insertion 和 Aging。
assign replace_fill_valid_w =
    full_line_allocate_w ||
    refill_update_w;

assign replace_fill_low_priority_w =
    refill_update_w &&
    (ctx_source_r == `L2_SRC_PREFETCH);

// 只有 I-cache / D-cache 的 Demand Refill 用于训练 PSEL。
//
// Victim Buffer 写回到 L2：
// 仍使用当前 DRRIP 策略进行插入，
// 但不更新 PSEL，避免写回流量污染策略选择。
assign replace_train_valid_w =
    refill_update_w &&
    (
        (ctx_source_r == `L2_SRC_ICACHE) ||
        (ctx_source_r == `L2_SRC_DCACHE)
    );


assign hit_way_w = tag_lookup_hit_way_w[0] ? 2'd0 :
                   tag_lookup_hit_way_w[1] ? 2'd1 :
                   tag_lookup_hit_way_w[2] ? 2'd2 : 2'd3;
assign read_hit_line_data_w = tag_lookup_hit_way_w[0] ? data_read_way0_line_w :
                              tag_lookup_hit_way_w[1] ? data_read_way1_line_w :
                              tag_lookup_hit_way_w[2] ? data_read_way2_line_w :
                              data_read_way3_line_w;
assign victim_tag_w = (victim_way_r == 2'd0) ? tag_lookup_tag_way0_w :
                      (victim_way_r == 2'd1) ? tag_lookup_tag_way1_w :
                      (victim_way_r == 2'd2) ? tag_lookup_tag_way2_w :
                      tag_lookup_tag_way3_w;
assign victim_line_data_w = (victim_way_r == 2'd0) ? data_read_way0_line_w :
                            (victim_way_r == 2'd1) ? data_read_way1_line_w :
                            (victim_way_r == 2'd2) ? data_read_way2_line_w :
                            data_read_way3_line_w;
assign victim_dirty_w = (victim_way_r == 2'd0) ? tag_lookup_dirty_way0_w :
                        (victim_way_r == 2'd1) ? tag_lookup_dirty_way1_w :
                        (victim_way_r == 2'd2) ? tag_lookup_dirty_way2_w :
                        tag_lookup_dirty_way3_w;
assign victim_clean_or_invalid_w = victim_is_invalid_r || !victim_dirty_w;
assign victim_clean_valid_w = !victim_is_invalid_r && !victim_dirty_w;
assign axi_read_line_w = state_r == S_MEM_READ_REQ;
assign axi_read_req_w = ((state_r == S_MEM_READ_REQ) ||
                         (state_r == S_UNCACHED_READ_REQ)) &&
                        axi_read_ready_w;
assign victim_addr_w = {victim_tag_r, ctx_index_r, {`L2_OFFSET_WIDTH{1'b0}}};
assign axi_write_line_w = (state_r == S_BLOCKING_WB_REQ) ||
                          (state_r == S_MAINT_WB_REQ);
assign axi_write_req_w = ((state_r == S_BLOCKING_WB_REQ) ||
                          (state_r == S_MAINT_WB_REQ) ||
                          (state_r == S_UNCACHED_WRITE_REQ)) &&
                         axi_write_ready_w;
assign refill_line_next_w =
    !axi_read_data_valid_w ? refill_line_data_r :
    (axi_read_beat_w == 3'd0) ? {refill_line_data_r[255:32], axi_read_data_w} :
    (axi_read_beat_w == 3'd1) ? {refill_line_data_r[255:64],
                                 axi_read_data_w,
                                 refill_line_data_r[31:0]} :
    (axi_read_beat_w == 3'd2) ? {refill_line_data_r[255:96],
                                 axi_read_data_w,
                                 refill_line_data_r[63:0]} :
    (axi_read_beat_w == 3'd3) ? {refill_line_data_r[255:128],
                                 axi_read_data_w,
                                 refill_line_data_r[95:0]} :
    (axi_read_beat_w == 3'd4) ? {refill_line_data_r[255:160],
                                 axi_read_data_w,
                                 refill_line_data_r[127:0]} :
    (axi_read_beat_w == 3'd5) ? {refill_line_data_r[255:192],
                                 axi_read_data_w,
                                 refill_line_data_r[159:0]} :
    (axi_read_beat_w == 3'd6) ? {refill_line_data_r[255:224],
                                 axi_read_data_w,
                                 refill_line_data_r[191:0]} :
    {axi_read_data_w, refill_line_data_r[223:0]};
assign maint_lookup_req_w = req_fire_w && req_maint_w &&
                            (req_size != `L2_MAINT_STORE_TAG);
assign maint_index_mode_w = maint_op_r == `L2_MAINT_INDEX_INV;
assign maint_hit_mode_w = maint_op_r == `L2_MAINT_HIT_INV;
assign maint_single_way_op_w = (maint_op_r == `L2_MAINT_STORE_TAG) ||
                               maint_index_mode_w;
assign maint_req_way_w =
    ((req_size == `L2_MAINT_STORE_TAG) ||
     (req_size == `L2_MAINT_INDEX_INV)) ?
    req_addr[`L2_WAY_WIDTH-1:0] :
    {`L2_WAY_WIDTH{1'b0}};
assign maint_current_valid_w =
    (maint_way_r == 2'd0) ? tag_lookup_valid_way0_w :
    (maint_way_r == 2'd1) ? tag_lookup_valid_way1_w :
    (maint_way_r == 2'd2) ? tag_lookup_valid_way2_w :
                            tag_lookup_valid_way3_w;
assign maint_current_dirty_w =
    (maint_way_r == 2'd0) ? tag_lookup_dirty_way0_w :
    (maint_way_r == 2'd1) ? tag_lookup_dirty_way1_w :
    (maint_way_r == 2'd2) ? tag_lookup_dirty_way2_w :
                            tag_lookup_dirty_way3_w;
assign maint_current_tag_w =
    (maint_way_r == 2'd0) ? tag_lookup_tag_way0_w :
    (maint_way_r == 2'd1) ? tag_lookup_tag_way1_w :
    (maint_way_r == 2'd2) ? tag_lookup_tag_way2_w :
                            tag_lookup_tag_way3_w;
assign maint_current_line_w =
    (maint_way_r == 2'd0) ? data_read_way0_line_w :
    (maint_way_r == 2'd1) ? data_read_way1_line_w :
    (maint_way_r == 2'd2) ? data_read_way2_line_w :
                            data_read_way3_line_w;
assign maint_current_hit_w = maint_current_valid_w &&
                             (maint_index_mode_w ||
                              (maint_hit_mode_w &&
                               (maint_current_tag_w == ctx_tag_r)));
assign maint_clear_valid_w = state_r == S_MAINT_CLEAR;
assign l2_clear_valid_w = maint_clear_valid_w;
assign l2_clear_way_w = maint_way_r;

l2_cache_array u_l2_cache_array (
    .clk(clk),
    .resetn(resetn),
    .lookup_valid(cached_lookup_req_w || maint_lookup_req_w),
    .lookup_index(req_addr[`L2_INDEX_MSB:`L2_INDEX_LSB]),
    .lookup_tag(req_addr[`L2_TAG_MSB:`L2_TAG_LSB]),
    .lookup_valid_out(tag_lookup_valid_out_w),
    .lookup_hit(tag_lookup_hit_w),
    .lookup_hit_way(tag_lookup_hit_way_w),
    .lookup_tag_way0(tag_lookup_tag_way0_w),
    .lookup_tag_way1(tag_lookup_tag_way1_w),
    .lookup_tag_way2(tag_lookup_tag_way2_w),
    .lookup_tag_way3(tag_lookup_tag_way3_w),
    .lookup_valid_way0(tag_lookup_valid_way0_w),
    .lookup_valid_way1(tag_lookup_valid_way1_w),
    .lookup_valid_way2(tag_lookup_valid_way2_w),
    .lookup_valid_way3(tag_lookup_valid_way3_w),
    .lookup_dirty_way0(tag_lookup_dirty_way0_w),
    .lookup_dirty_way1(tag_lookup_dirty_way1_w),
    .lookup_dirty_way2(tag_lookup_dirty_way2_w),
    .lookup_dirty_way3(tag_lookup_dirty_way3_w),
    .read_data0(data_read_data0_w),
    .read_data1(data_read_data1_w),
    .read_data2(data_read_data2_w),
    .read_data3(data_read_data3_w),
    .read_data4(data_read_data4_w),
    .read_data5(data_read_data5_w),
    .read_data6(data_read_data6_w),
    .read_data7(data_read_data7_w),
    .read_data_valid(data_read_valid_w),
    .read_way0_line_data(data_read_way0_line_w),
    .read_way1_line_data(data_read_way1_line_w),
    .read_way2_line_data(data_read_way2_line_w),
    .read_way3_line_data(data_read_way3_line_w),
    .tag_write_valid(tag_write_valid_w),
    .tag_write_way(tag_write_way_w),
    .tag_write_index(ctx_index_r),
    .tag_write_tag(ctx_tag_r),
    .tag_write_valid_bit(1'b1),
    .tag_write_dirty_bit(tag_write_dirty_w),
    .clear_set_valid(state_r == S_RESET_SCAN),
    .clear_set_index(reset_scan_index_r),
    .clear_valid(l2_clear_valid_w),
    .clear_way(l2_clear_way_w),
    .clear_index(ctx_index_r),
    .bank_write_valid(1'b0),
    .bank_write_way(victim_way_r),
    .bank_write_index(ctx_index_r),
    .bank_write_bank(axi_read_beat_w),
    .bank_write_data(axi_read_data_w),
    .line_write_valid(write_hit_w || full_line_allocate_w || refill_update_w),
    .line_write_way((full_line_allocate_w || refill_update_w) ?
                    victim_way_r : hit_way_w),
    .line_write_index(ctx_index_r),
    .line_write_data0(refill_update_w ? refill_line_data_r[31:0] :
                      ctx_line_data_r[31:0]),
    .line_write_data1(refill_update_w ? refill_line_data_r[63:32] :
                      ctx_line_data_r[63:32]),
    .line_write_data2(refill_update_w ? refill_line_data_r[95:64] :
                      ctx_line_data_r[95:64]),
    .line_write_data3(refill_update_w ? refill_line_data_r[127:96] :
                      ctx_line_data_r[127:96]),
    .line_write_data4(refill_update_w ? refill_line_data_r[159:128] :
                      ctx_line_data_r[159:128]),
    .line_write_data5(refill_update_w ? refill_line_data_r[191:160] :
                      ctx_line_data_r[191:160]),
    .line_write_data6(refill_update_w ? refill_line_data_r[223:192] :
                      ctx_line_data_r[223:192]),
    .line_write_data7(refill_update_w ? refill_line_data_r[255:224] :
                      ctx_line_data_r[255:224])
);

l2_replace u_l2_replace (
    .clk(clk),
    .resetn(resetn),

    // 复用 L2 原有的逐 Set Reset Scan。
    .init_valid(state_r == S_RESET_SCAN),
    .init_index(reset_scan_index_r),

    .valid_way0(tag_lookup_valid_way0_w),
    .valid_way1(tag_lookup_valid_way1_w),
    .valid_way2(tag_lookup_valid_way2_w),
    .valid_way3(tag_lookup_valid_way3_w),

    // Hit Promotion
    .hit_valid(replace_hit_valid_w),
    .hit_index(ctx_index_r),
    .hit_way(hit_way_w),

    // Fill Insertion / Aging
    .fill_valid(replace_fill_valid_w),
    .fill_index(ctx_index_r),
    .fill_way(victim_way_r),
    .fill_victim_invalid(victim_is_invalid_r),
    .fill_low_priority(replace_fill_low_priority_w),

    // 仅 Demand Miss 训练 Set Dueling。
    .train_valid(replace_train_valid_w),

    // Victim Selection
    .victim_index(ctx_index_r),
    .victim_way(victim_way_w),
    .victim_is_invalid(victim_is_invalid_w)
);



l2_axi_master u_l2_axi_master (
    .clk(clk),
    .resetn(resetn),
    .read_req(axi_read_req_w),
    .read_addr(ctx_addr_r),
    .read_line(axi_read_line_w),
    .read_size(ctx_size_r),
    .read_ready(axi_read_ready_w),
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    .read_data_valid(axi_read_data_valid_w),
    .read_data(axi_read_data_w),
    .read_beat(axi_read_beat_w),
    .read_last(axi_read_last_unused_w),
    .read_done(axi_read_done_w),
    .write_req(axi_write_req_w),
    .write_addr(axi_write_line_w ? victim_addr_w : ctx_addr_r),
    .write_line(axi_write_line_w),
    .write_size(ctx_size_r),
    .write_wstrb(ctx_wstrb_r),
    .write_data(ctx_line_data_r[31:0]),
    .write_line_data(victim_line_data_r),
    .write_ready(axi_write_ready_w),
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),
    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),
    .write_done(axi_write_done_w)
);

always @(posedge clk) begin
    if(!resetn) begin
        state_r <= S_RESET_SCAN;
        init_done_r <= 1'b0;
        wb_inflight_r <= 1'b0;
        reset_scan_index_r <= {`L2_INDEX_WIDTH{1'b0}};
        ctx_source_r <= {`L2_SOURCE_WIDTH{1'b0}};
        ctx_opcode_r <= {`L2_OPCODE_WIDTH{1'b0}};
        ctx_uncached_r <= 1'b0;
        ctx_addr_r <= 32'b0;
        ctx_tag_r <= {`L2_TAG_WIDTH{1'b0}};
        ctx_index_r <= {`L2_INDEX_WIDTH{1'b0}};
        ctx_bank_r <= {`L2_BANK_WIDTH{1'b0}};
        ctx_size_r <= 2'b0;
        ctx_wstrb_r <= {`L2_WSTRB_WIDTH{1'b0}};
        ctx_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
        maint_op_r <= `L2_MAINT_STORE_TAG;
        maint_way_r <= {`L2_WAY_WIDTH{1'b0}};
        victim_way_r <= {`L2_WAY_WIDTH{1'b0}};
        victim_is_invalid_r <= 1'b0;
        victim_tag_r <= {`L2_TAG_WIDTH{1'b0}};
        victim_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
        refill_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
        resp_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
        resp_error_r <= 1'b1;
        l2_i_access_count <= 32'b0;
        l2_d_access_count <= 32'b0;
        l2_hit_count <= 32'b0;
        l2_miss_count <= 32'b0;
        l2_dirty_evict_count <= 32'b0;
        l2_clean_evict_count <= 32'b0;
        l2_refill_cycles <= 32'b0;
        l2_writeback_cycles <= 32'b0;
        victim_to_l2_write_count <= 32'b0;
        uncached_read_count <= 32'b0;
        uncached_write_count <= 32'b0;
    end else begin
        // 后台写回跟踪，与下面的主状态机并行推进。
        // 放在 case 之前：写回的完成时刻已不再绑定到某个特定状态，
        // B 响应可能在 S_MEM_READ_DATA / S_REFILL_UPDATE / S_RESP 任意一拍到达。
        // 与 case 内的赋值不会同拍冲突：
        //   - S_BLOCKING_WB_REQ 置起 wb_inflight_r 时它的旧值还是 0，本块不动；
        //   - 新请求被 req_ready 挡住，所以 wb_inflight_r 期间进不了
        //     S_BLOCKING_WB_REQ / S_MAINT_WB_* ，计数器不会被重复累加。
        if(wb_inflight_r) begin
            l2_writeback_cycles <= l2_writeback_cycles + 32'd1;
            if(axi_write_done_w) begin
                wb_inflight_r <= 1'b0;
                l2_dirty_evict_count <= l2_dirty_evict_count + 32'd1;
            end
        end

        case(state_r)
            S_RESET_SCAN: begin
                if(reset_scan_index_r == RESET_SCAN_LAST) begin
                    init_done_r <= 1'b1;
                    state_r <= S_IDLE;
                end else begin
                    reset_scan_index_r <= reset_scan_index_r + {{(`L2_INDEX_WIDTH-1){1'b0}}, 1'b1};
                end
            end
            S_IDLE: begin
                if(req_fire_w) begin
                    if(req_source == `L2_SRC_ICACHE) begin
                        l2_i_access_count <= l2_i_access_count + 32'd1;
                    end
                    if(req_source == `L2_SRC_DCACHE) begin
                        l2_d_access_count <= l2_d_access_count + 32'd1;
                    end
                    if(req_uncached_read_w) begin
                        uncached_read_count <= uncached_read_count + 32'd1;
                    end
                    if(req_uncached_write_w) begin
                        uncached_write_count <= uncached_write_count + 32'd1;
                    end
                    if(!req_uncached &&
                       (req_opcode == `L2_OP_CACHED_FULL_LINE_WRITE) &&
                       (req_source == `L2_SRC_VB)) begin
                        victim_to_l2_write_count <=
                            victim_to_l2_write_count + 32'd1;
                    end
                    ctx_source_r <= req_source;
                    ctx_opcode_r <= req_opcode;
                    ctx_uncached_r <= req_uncached;
                    ctx_addr_r <= req_addr;
                    ctx_tag_r <= req_addr[`L2_TAG_MSB:`L2_TAG_LSB];
                    ctx_index_r <= req_addr[`L2_INDEX_MSB:`L2_INDEX_LSB];
                    ctx_bank_r <= req_addr[`L2_BANK_MSB:`L2_BANK_LSB];
                    ctx_size_r <= req_size;
                    ctx_wstrb_r <= req_wstrb;
                    ctx_line_data_r <= req_line_data;
                    maint_op_r <= req_size;
                    maint_way_r <= maint_req_way_w;
                    refill_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
                    if(req_uncached_read_w) begin
                        state_r <= S_UNCACHED_READ_REQ;
                    end else if(req_uncached_write_w) begin
                        state_r <= S_UNCACHED_WRITE_REQ;
                    end else if(req_maint_w) begin
                        resp_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
                        resp_error_r <= 1'b0;
                        state_r <= (req_size == `L2_MAINT_STORE_TAG) ?
                                   S_MAINT_CLEAR : S_MAINT_LOOKUP_WAIT;
                    end else begin
                        state_r <= S_LOOKUP_WAIT;
                    end
                end
            end
            S_UNCACHED_READ_REQ: begin
                if(axi_read_req_w) begin
                    state_r <= S_UNCACHED_READ_WAIT;
                end
            end
            S_UNCACHED_READ_WAIT: begin
                if(axi_read_done_w) begin
                    resp_line_data_r <=
                        {{(`L2_LINE_WIDTH-`L2_WORD_WIDTH){1'b0}},
                         axi_read_data_w};
                    resp_error_r <= 1'b0;
                    state_r <= S_RESP;
                end
            end
            S_UNCACHED_WRITE_REQ: begin
                if(axi_write_req_w) begin
                    state_r <= S_UNCACHED_WRITE_WAIT;
                end
            end
            S_UNCACHED_WRITE_WAIT: begin
                if(axi_write_done_w) begin
                    resp_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
                    resp_error_r <= 1'b0;
                    state_r <= S_RESP;
                end
            end
            S_LOOKUP_WAIT: begin
                if(read_hit_w || write_hit_w) begin
                    l2_hit_count <= l2_hit_count + 32'd1;
                    resp_line_data_r <= read_hit_w ? read_hit_line_data_w :
                                        {`L2_LINE_WIDTH{1'b0}};
                    resp_error_r <= 1'b0;
                    state_r <= S_RESP;
                end else if(read_miss_w) begin
                    l2_miss_count <= l2_miss_count + 32'd1;
                    state_r <= S_SELECT_VICTIM;
                end else if(write_miss_w) begin
                    l2_miss_count <= l2_miss_count + 32'd1;
                    state_r <= S_SELECT_VICTIM;
                end else begin
                    resp_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
                    resp_error_r <= 1'b1;
                    state_r <= S_RESP;
                end
            end
            S_SELECT_VICTIM: begin
                // 只寄存 l2_replace 的动态选择结果，
                // 切断 victim 选择到 4-way tag/data mux 的组合链。
                victim_way_r <= victim_way_w;
                victim_is_invalid_r <= victim_is_invalid_w;
                state_r <= S_CAPTURE_VICTIM;
            end
            S_CAPTURE_VICTIM: begin
                // 用寄存后的 victim_way_r 选择 tag/data/dirty 并分支。
                victim_tag_r <= victim_tag_w;
                victim_line_data_r <= victim_line_data_w;
                if(victim_clean_or_invalid_w) begin
                    if(victim_clean_valid_w) begin
                        l2_clean_evict_count <= l2_clean_evict_count + 32'd1;
                    end
                    state_r <= cached_line_read_w ? S_MEM_READ_REQ :
                               S_FULL_LINE_ALLOCATE;
                end else begin
                    state_r <= S_BLOCKING_WB_REQ;
                end
            end
            S_BLOCKING_WB_REQ: begin
                l2_writeback_cycles <= l2_writeback_cycles + 32'd1;
                if(axi_write_req_w) begin
                    // AW 已握手，W beats 交给 AXI master 在后台排空，
                    // 不等 B 响应就直接去发 AR —— 每次脏行逐出省下
                    // 「8 拍 W + B 响应」这段串行等待。
                    //
                    // 地址无重叠：写的是 {victim_tag_r, ctx_index_r}，
                    // 读的是 ctx_addr_r（tag 为 ctx_tag_r）。既然走到这里是
                    // miss，victim way 有效却未命中，故 victim_tag_r != ctx_tag_r，
                    // 同 index 不同 tag，两笔 AXI 事务地址必然不同。
                    //
                    // 数据无依赖：AXI master 在 W_IDLE→W_AW 已把
                    // victim_line_data_r 锁存进自己的 write_line_data_r，
                    // 而数组回填走 refill_line_data_r / ctx_line_data_r，
                    // 两条通路互不相干（等于双缓冲）。
                    wb_inflight_r <= 1'b1;
                    state_r <= cached_line_read_w ? S_MEM_READ_REQ :
                               S_FULL_LINE_ALLOCATE;
                end
            end
            S_MEM_READ_REQ: begin
                l2_refill_cycles <= l2_refill_cycles + 32'd1;
                if(axi_read_req_w) begin
                    state_r <= S_MEM_READ_DATA;
                end
            end
            S_MEM_READ_DATA: begin
                l2_refill_cycles <= l2_refill_cycles + 32'd1;
                refill_line_data_r <= refill_line_next_w;
                if(axi_read_done_w) begin
                    resp_line_data_r <= refill_line_next_w;
                    resp_error_r <= 1'b0;
                    state_r <= S_REFILL_UPDATE;
                end
            end
            S_REFILL_UPDATE: begin
                state_r <= S_RESP;
            end
            S_FULL_LINE_ALLOCATE: begin
                resp_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
                resp_error_r <= 1'b0;
                state_r <= S_RESP;
            end
            S_MAINT_LOOKUP_WAIT: begin
                if(lookup_result_valid_w) begin
                    if(maint_hit_mode_w) begin
                        maint_way_r <= {`L2_WAY_WIDTH{1'b0}};
                    end
                    state_r <= S_MAINT_CHECK;
                end
            end
            S_MAINT_CHECK: begin
                if(maint_current_hit_w && maint_current_dirty_w) begin
                    victim_way_r <= maint_way_r;
                    victim_tag_r <= maint_current_tag_w;
                    victim_line_data_r <= maint_current_line_w;
                    state_r <= S_MAINT_WB_REQ;
                end else if(maint_current_hit_w) begin
                    state_r <= S_MAINT_CLEAR;
                end else begin
                    state_r <= maint_single_way_op_w ? S_RESP :
                               S_MAINT_NEXT;
                end
            end
            S_MAINT_WB_REQ: begin
                l2_writeback_cycles <= l2_writeback_cycles + 32'd1;
                if(axi_write_req_w) begin
                    state_r <= S_MAINT_WB_WAIT;
                end
            end
            S_MAINT_WB_WAIT: begin
                l2_writeback_cycles <= l2_writeback_cycles + 32'd1;
                if(axi_write_done_w) begin
                    l2_dirty_evict_count <= l2_dirty_evict_count + 32'd1;
                    state_r <= S_MAINT_CLEAR;
                end
            end
            S_MAINT_CLEAR: begin
                state_r <= maint_single_way_op_w ? S_RESP :
                           S_MAINT_NEXT;
            end
            S_MAINT_NEXT: begin
                if(maint_way_r == (`L2_WAYS - 1)) begin
                    resp_line_data_r <= {`L2_LINE_WIDTH{1'b0}};
                    resp_error_r <= 1'b0;
                    state_r <= S_RESP;
                end else begin
                    maint_way_r <= maint_way_r + 1'b1;
                    state_r <= S_MAINT_CHECK;
                end
            end
            S_RESP: begin
                if(resp_fire_w) begin
                    state_r <= S_IDLE;
                end
            end
            default: begin
                state_r <= S_RESET_SCAN;
                init_done_r <= 1'b0;
                reset_scan_index_r <= {`L2_INDEX_WIDTH{1'b0}};
            end
        endcase
    end
end

`ifndef SYNTHESIS
always @(posedge clk) begin
    if(resetn && req_fire_w &&
       !req_uncached &&
       (req_opcode == `L2_OP_CACHED_FULL_LINE_WRITE) &&
       (req_wstrb != {`L2_WSTRB_WIDTH{1'b1}})) begin
        $fatal(1, "L2 full-line cached write requires all byte lanes enabled");
    end
end
`endif

endmodule

module l2_cache (
    input wire clk,
    input wire resetn,

    input wire [3:0] icache_arid,
    input wire [31:0] icache_araddr,
    input wire [7:0] icache_arlen,
    input wire [2:0] icache_arsize,
    input wire [1:0] icache_arburst,
    input wire icache_arvalid,
    output wire icache_arready,
    // 返回整行（bank0 在最低 32 位）。uncached 单字读时目标字在最低 32 位。
    // 不再按 beat 挤出去，所以没有 rlast。
    output wire [`L2_LINE_WIDTH-1:0] icache_rline,
    output wire icache_rvalid,
    input wire icache_rready,

    input wire [3:0] dcache_arid,
    input wire [31:0] dcache_araddr,
    input wire [7:0] dcache_arlen,
    input wire [2:0] dcache_arsize,
    input wire [1:0] dcache_arburst,
    input wire dcache_arvalid,
    output wire dcache_arready,
    // 返回整行（bank0 在最低 32 位）。uncached 单字读时目标字在最低 32 位。
    // 不再按 beat 挤出去，所以没有 rlast。
    output wire [`L2_LINE_WIDTH-1:0] dcache_rline,
    output wire dcache_rvalid,
    input wire dcache_rready,

    input wire prefetch_valid,
    input wire [31:0] prefetch_addr,
    input wire prefetch_block,
    output wire prefetch_ready,
    output wire prefetch_complete,

    input wire [3:0] dcache_awid,
    input wire [`L2_SOURCE_WIDTH-1:0] dcache_awsource,
    input wire [31:0] dcache_awaddr,
    input wire [7:0] dcache_awlen,
    input wire [2:0] dcache_awsize,
    input wire [1:0] dcache_awburst,
    input wire dcache_awvalid,
    output wire dcache_awready,
    input wire [3:0] dcache_wid,
    input wire [`L2_LINE_WIDTH-1:0] dcache_wline,
    input wire [`L2_LINE_WIDTH/8-1:0] dcache_wstrb,
    input wire dcache_wlast,
    input wire dcache_wvalid,
    output wire dcache_wready,
    output wire [3:0] dcache_bid,
    output wire dcache_bvalid,
    input wire dcache_bready,

    input wire maint_valid,
    input wire [`L2_OPCODE_WIDTH-1:0] maint_opcode,
    input wire [31:0] maint_addr,
    input wire [`L2_LINE_WIDTH-1:0] maint_line_data,
    output wire maint_ready,
    output wire maint_done,
    output wire maint_error,

    output wire [3:0] arid,
    output wire [31:0] araddr,
    output wire [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    output wire [1:0] arlock,
    output wire [3:0] arcache,
    output wire [2:0] arprot,
    output wire arvalid,
    input wire arready,
    input wire [3:0] rid,
    input wire [31:0] rdata,
    input wire [1:0] rresp,
    input wire rlast,
    input wire rvalid,
    output wire rready,

    output wire [3:0] awid,
    output wire [31:0] awaddr,
    output wire [7:0] awlen,
    output wire [2:0] awsize,
    output wire [1:0] awburst,
    output wire [1:0] awlock,
    output wire [3:0] awcache,
    output wire [2:0] awprot,
    output wire awvalid,
    input wire awready,
    output wire [3:0] wid,
    output wire [`L2_WORD_WIDTH-1:0] wdata,
    output wire [`L2_WSTRB_WIDTH-1:0] wstrb,
    output wire wlast,
    output wire wvalid,
    input wire wready,
    input wire [3:0] bid,
    input wire [1:0] bresp,
    input wire bvalid,
    output wire bready
);

localparam [3:0] S_IDLE            = 4'd0;
localparam [3:0] S_READ_WAIT_L2    = 4'd1;
localparam [3:0] S_ICACHE_RET      = 4'd2;
localparam [3:0] S_DCACHE_RET      = 4'd3;
localparam [3:0] S_DWRITE_W        = 4'd4;
localparam [3:0] S_DWRITE_L2_REQ   = 4'd5;
localparam [3:0] S_DWRITE_WAIT_L2  = 4'd6;
localparam [3:0] S_DWRITE_B        = 4'd7;
localparam [3:0] S_MAINT_WAIT_L2   = 4'd8;
localparam [3:0] S_PREFETCH_WAIT_L2 = 4'd9;
localparam [1:0] D_DEMAND_STARVE_LIMIT = 2'd3;

reg [3:0] state_r;
reg [`L2_LINE_WIDTH-1:0] resp_line_r;
// 原来这里还有 req_line_r / ret_cnt_r / req_start_bank_r 三个寄存器，
// 用来把 resp_line_r 按 critical-word-first 顺序逐 beat 挤到 L1。
// icache 和 dcache 的返回通道都改成一拍整行之后，L1 自己按 bank 位挑字，
// 这套 beat 串行化机构就没有使用者了，连同 ret_bank_w / ret_last_cnt_w /
// grant_start_bank_w / select_line_word 一起删除。
reg [1:0] dcache_demand_grant_count_r;
reg [3:0] dcache_write_id_r;
reg [`L2_SOURCE_WIDTH-1:0] dcache_write_source_r;
reg dcache_write_line_mode_r;
reg [31:0] dcache_write_addr_r;
reg [1:0] dcache_write_size_r;
reg [`L2_WSTRB_WIDTH-1:0] dcache_write_wstrb_r;
reg [`L2_LINE_WIDTH-1:0] dcache_write_line_r;
// 原来这里还有 dcache_write_beat_cnt_r，用来逐拍接收 8 个 beat。
// 写方向拓宽之后，整行一拍到齐，不再需要计数器。

wire core_req_valid;
wire core_req_ready;
wire [`L2_SOURCE_WIDTH-1:0] core_req_source;
wire [`L2_OPCODE_WIDTH-1:0] core_req_opcode;
wire core_req_uncached;
wire [31:0] core_req_addr;
wire [1:0] core_req_size;
wire [`L2_WSTRB_WIDTH-1:0] core_req_wstrb;
wire [`L2_LINE_WIDTH-1:0] core_req_line_data;
wire core_resp_valid;
wire core_resp_ready;
wire [`L2_SOURCE_WIDTH-1:0] core_resp_source;
wire [`L2_LINE_WIDTH-1:0] core_resp_line_data;
wire core_resp_error;

wire icache_grant_w;
wire dcache_read_grant_w;
wire dcache_write_aw_grant_w;
wire maint_grant_w;
wire prefetch_grant_w;
wire dcache_write_pending_w;
wire dcache_full_line_write_w;
wire dcache_uncached_write_w;
wire icache_line_req_w;
wire icache_uncached_req_w;
wire dcache_line_req_w;
wire dcache_uncached_req_w;
wire icache_demand_pending_w;
wire dcache_demand_pending_w;
wire icache_uncached_pending_w;
wire dcache_uncached_pending_w;
wire force_icache_demand_w;
wire selected_line_req_w;
wire core_req_fire_w;
wire core_icache_resp_ready_w;
wire core_dcache_resp_ready_w;
wire core_dcache_write_resp_ready_w;
wire core_maint_resp_ready_w;
wire core_prefetch_resp_ready_w;
wire core_icache_resp_fire_w;
wire core_dcache_resp_fire_w;
wire core_dcache_write_resp_fire_w;
wire core_maint_resp_fire_w;
wire core_prefetch_resp_fire_w;
wire read_ret_fire_w;
wire dcache_ret_fire_w;
wire dcache_w_fire_w;
wire dcache_w_last_fire_w;
wire dcache_b_fire_w;
wire unused_inputs_w;

assign icache_line_req_w = (icache_arlen == `L2_AXI_LINE_LEN);
assign icache_uncached_req_w = !icache_line_req_w;
assign dcache_line_req_w = (dcache_arlen == `L2_AXI_LINE_LEN);
assign dcache_uncached_req_w = !dcache_line_req_w;
assign dcache_full_line_write_w =
    (dcache_awlen == `L2_AXI_LINE_LEN) &&
    (dcache_awsize == `L2_AXI_WORD_SIZE);
assign dcache_uncached_write_w =
    (dcache_awlen == `L2_AXI_WORD_LEN);

assign dcache_write_pending_w =
    dcache_awvalid ||
    dcache_wvalid ||
    dcache_bready;

assign icache_demand_pending_w =
    icache_arvalid &&
    icache_line_req_w;

assign dcache_demand_pending_w =
    dcache_arvalid &&
    dcache_line_req_w;

assign icache_uncached_pending_w =
    icache_arvalid &&
    icache_uncached_req_w;

assign dcache_uncached_pending_w =
    dcache_arvalid &&
    dcache_uncached_req_w;

assign force_icache_demand_w =
    icache_demand_pending_w &&
    dcache_demand_pending_w &&
    (dcache_demand_grant_count_r >= D_DEMAND_STARVE_LIMIT);

assign icache_grant_w =
    (state_r == S_IDLE) &&
    !dcache_write_pending_w &&
    !maint_valid &&
    icache_arvalid &&
    ((icache_uncached_req_w && !dcache_uncached_pending_w) ||
     (icache_line_req_w &&
      !dcache_uncached_pending_w &&
      (!dcache_demand_pending_w || force_icache_demand_w)));

assign dcache_read_grant_w =
    (state_r == S_IDLE) &&
    !dcache_write_pending_w &&
    !maint_valid &&
    dcache_arvalid &&
    (dcache_uncached_req_w ||
     (dcache_line_req_w &&
      !icache_uncached_pending_w &&
      !force_icache_demand_w));

assign dcache_write_aw_grant_w =
    (state_r == S_IDLE) &&
    dcache_awvalid &&
    (dcache_full_line_write_w || dcache_uncached_write_w);

assign maint_grant_w =
    (state_r == S_IDLE) &&
    !dcache_write_pending_w &&
    !dcache_awvalid &&
    maint_valid;

assign prefetch_grant_w =
    (state_r == S_IDLE) &&
    !dcache_write_pending_w &&
    !maint_valid &&
    !icache_arvalid &&
    !dcache_arvalid &&
    !prefetch_block &&
    prefetch_valid;

assign selected_line_req_w =
    dcache_read_grant_w ? dcache_line_req_w :
                          icache_line_req_w;

assign core_req_fire_w =
    core_req_valid &&
    core_req_ready;

assign core_icache_resp_ready_w =
    (state_r == S_READ_WAIT_L2) &&
    (core_resp_source == `L2_SRC_ICACHE);

assign core_dcache_resp_ready_w =
    (state_r == S_READ_WAIT_L2) &&
    (core_resp_source == `L2_SRC_DCACHE);

assign core_dcache_write_resp_ready_w =
    (state_r == S_DWRITE_WAIT_L2) &&
    (core_resp_source == dcache_write_source_r);

assign core_maint_resp_ready_w =
    (state_r == S_MAINT_WAIT_L2) &&
    (core_resp_source == `L2_SRC_MAINT);

assign core_prefetch_resp_ready_w =
    (state_r == S_PREFETCH_WAIT_L2) &&
    (core_resp_source == `L2_SRC_PREFETCH);

assign core_icache_resp_fire_w =
    core_resp_valid &&
    core_icache_resp_ready_w;

assign core_dcache_resp_fire_w =
    core_resp_valid &&
    core_dcache_resp_ready_w;

assign core_dcache_write_resp_fire_w =
    core_resp_valid &&
    core_dcache_write_resp_ready_w;

assign core_maint_resp_fire_w =
    core_resp_valid &&
    core_maint_resp_ready_w;

assign core_prefetch_resp_fire_w =
    core_resp_valid &&
    core_prefetch_resp_ready_w;

// 两侧都是一拍整行，握手一次即结束。
assign read_ret_fire_w =
    (state_r == S_ICACHE_RET) && icache_rready;

assign dcache_ret_fire_w =
    (state_r == S_DCACHE_RET) && dcache_rready;

assign dcache_w_fire_w =
    dcache_wvalid &&
    dcache_wready;

// 整行一拍到齐，w_fire 即 w_last_fire。
assign dcache_w_last_fire_w = dcache_w_fire_w;

assign dcache_b_fire_w =
    dcache_bvalid &&
    dcache_bready;

assign unused_inputs_w = |{
    icache_arid,
    icache_arburst,
    dcache_arid,
    dcache_arburst,
    dcache_awburst,
    dcache_wid,
    dcache_wlast,
    maint_line_data
};

always @(posedge clk) begin
    if(!resetn) begin
        state_r <= S_IDLE;
        resp_line_r <= {`L2_LINE_WIDTH{1'b0}};
        dcache_write_id_r <= 4'b0;
        dcache_write_source_r <= {`L2_SOURCE_WIDTH{1'b0}};
        dcache_write_line_mode_r <= 1'b0;
        dcache_write_addr_r <= 32'b0;
        dcache_write_size_r <= 2'b0;
        dcache_write_wstrb_r <= {`L2_WSTRB_WIDTH{1'b0}};
        dcache_write_line_r <= {`L2_LINE_WIDTH{1'b0}};
    end else begin
        case(state_r)
            S_IDLE: begin
                if(dcache_write_aw_grant_w) begin
                    dcache_write_id_r <= dcache_awid;
                    dcache_write_source_r <= dcache_awsource;
                    dcache_write_line_mode_r <= dcache_full_line_write_w;
                    dcache_write_addr_r <= dcache_awaddr;
                    dcache_write_size_r <= dcache_awsize[1:0];
                    dcache_write_wstrb_r <= {`L2_WSTRB_WIDTH{1'b0}};
                    dcache_write_line_r <= {`L2_LINE_WIDTH{1'b0}};
                    state_r <= S_DWRITE_W;
                end else if(maint_grant_w && core_req_fire_w) begin
                    state_r <= S_MAINT_WAIT_L2;
                end else if(prefetch_grant_w && core_req_fire_w) begin
                    state_r <= S_PREFETCH_WAIT_L2;
                end else if(core_req_fire_w) begin
                    state_r <= S_READ_WAIT_L2;
                end
            end

            S_READ_WAIT_L2: begin
                if(core_icache_resp_fire_w) begin
                    resp_line_r <= core_resp_error ?
                                   {`L2_LINE_WIDTH{1'b0}} :
                                   core_resp_line_data;
                    state_r <= S_ICACHE_RET;
                end else if(core_dcache_resp_fire_w) begin
                    resp_line_r <= core_resp_error ?
                                   {`L2_LINE_WIDTH{1'b0}} :
                                   core_resp_line_data;
                    state_r <= S_DCACHE_RET;
                end
            end

            S_DWRITE_W: begin
                // 整行一拍到齐：直接锁存整行和 strobe，不再逐 beat 拼装。
                // uncached 单字写：dcache_l2_write 把数据放在 wline[31:0]，
                //   wstrb[3:0] 是字节使能；L2 core 靠 ctx_line_data_r[31:0] 取数。
                // line 写：wline 是完整 8 字，wstrb 全 1。
                if(dcache_w_fire_w) begin
                    dcache_write_line_r  <= dcache_wline;
                    dcache_write_wstrb_r <= dcache_wstrb[`L2_WSTRB_WIDTH-1:0];
                    state_r <= S_DWRITE_L2_REQ;
                end
            end

            S_DWRITE_L2_REQ: begin
                if(core_req_fire_w) begin
                    state_r <= S_DWRITE_WAIT_L2;
                end
            end

            S_DWRITE_WAIT_L2: begin
                if(core_dcache_write_resp_fire_w) begin
                    state_r <= S_DWRITE_B;
                end
            end

            S_DWRITE_B: begin
                if(dcache_b_fire_w) begin
                    state_r <= S_IDLE;
                end
            end

            S_MAINT_WAIT_L2: begin
                if(core_maint_resp_fire_w) begin
                    state_r <= S_IDLE;
                end
            end

            S_PREFETCH_WAIT_L2: begin
                if(core_prefetch_resp_fire_w) begin
                    state_r <= S_IDLE;
                end
            end

            S_ICACHE_RET: begin
                // 整行一拍交付，不再逐 beat 挤 —— 每次 icache miss 省下 7 拍。
                if(read_ret_fire_w) begin
                    state_r <= S_IDLE;
                end
            end

            S_DCACHE_RET: begin
                // 整行一拍交付，不再逐 beat 挤 —— 每次 dcache miss 省下 7 拍。
                if(dcache_ret_fire_w) begin
                    state_r <= S_IDLE;
                end
            end

            default: begin
                state_r <= S_IDLE;
            end
        endcase
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        dcache_demand_grant_count_r <= 2'b0;
    end else if(core_req_fire_w) begin
        if(dcache_read_grant_w && dcache_line_req_w) begin
            if(dcache_demand_grant_count_r != D_DEMAND_STARVE_LIMIT) begin
                dcache_demand_grant_count_r <=
                    dcache_demand_grant_count_r + 1'b1;
            end
        end else begin
            dcache_demand_grant_count_r <= 2'b0;
        end
    end
end

assign icache_arready = icache_grant_w && core_req_ready;
assign icache_rline = resp_line_r;
assign icache_rvalid = (state_r == S_ICACHE_RET);

assign dcache_arready = dcache_read_grant_w && core_req_ready;
// 直连寄存器输出，连 8 选 1 的 mux 都不用了 —— 比改之前的组合路径更浅。
// core 给的 resp_line_r 已经是 bank 自然顺序；uncached 单字在最低 32 位，
// 正好对上 dcache 侧对 ret_line[31:0] 的取法。
assign dcache_rline = resp_line_r;
assign dcache_rvalid = (state_r == S_DCACHE_RET);

assign dcache_awready = dcache_write_aw_grant_w;
assign dcache_wready = (state_r == S_DWRITE_W);
assign dcache_bid = dcache_write_id_r;
assign dcache_bvalid = (state_r == S_DWRITE_B);

assign maint_ready = maint_grant_w && core_req_ready;
assign maint_done = core_maint_resp_fire_w && !core_resp_error;
assign maint_error = (core_maint_resp_fire_w && core_resp_error) ||
                     (1'b0 && unused_inputs_w);

assign prefetch_ready = prefetch_grant_w && core_req_ready;
assign prefetch_complete = core_prefetch_resp_fire_w;

assign core_req_valid =
    (state_r == S_DWRITE_L2_REQ) ||
    maint_grant_w ||
    dcache_read_grant_w ||
    icache_grant_w ||
    prefetch_grant_w;
assign core_req_source =
    (state_r == S_DWRITE_L2_REQ) ? dcache_write_source_r :
    maint_grant_w ? `L2_SRC_MAINT :
    dcache_read_grant_w ? `L2_SRC_DCACHE :
    prefetch_grant_w ? `L2_SRC_PREFETCH :
    `L2_SRC_ICACHE;
assign core_req_opcode =
    (state_r == S_DWRITE_L2_REQ) ?
    (dcache_write_line_mode_r ? `L2_OP_CACHED_FULL_LINE_WRITE :
                                `L2_OP_UNCACHED_WRITE) :
    maint_grant_w ? `L2_OP_MAINT :
    prefetch_grant_w ? `L2_OP_CACHED_LINE_READ :
    selected_line_req_w ? `L2_OP_CACHED_LINE_READ :
                          `L2_OP_UNCACHED_READ;
assign core_req_uncached =
    (state_r == S_DWRITE_L2_REQ) ? !dcache_write_line_mode_r :
    maint_grant_w ? 1'b0 :
    prefetch_grant_w ? 1'b0 :
    dcache_read_grant_w ? dcache_uncached_req_w :
                          icache_uncached_req_w;
assign core_req_addr =
    (state_r == S_DWRITE_L2_REQ) ? dcache_write_addr_r :
    maint_grant_w ? maint_addr :
    dcache_read_grant_w ? dcache_araddr :
    prefetch_grant_w ? prefetch_addr :
                          icache_araddr;
assign core_req_size =
    (state_r == S_DWRITE_L2_REQ) ? dcache_write_size_r :
    maint_grant_w ? maint_opcode[1:0] :
    dcache_read_grant_w ? dcache_arsize[1:0] :
    prefetch_grant_w ? 2'b10 :
                          icache_arsize[1:0];
assign core_req_wstrb =
    (state_r == S_DWRITE_L2_REQ) ?
    (dcache_write_line_mode_r ? {`L2_WSTRB_WIDTH{1'b1}} :
                                dcache_write_wstrb_r) :
                               {`L2_WSTRB_WIDTH{1'b0}};
assign core_req_line_data =
    (state_r == S_DWRITE_L2_REQ) ? dcache_write_line_r :
                                   {`L2_LINE_WIDTH{1'b0}};

assign core_resp_ready = core_icache_resp_ready_w ||
                         core_dcache_resp_ready_w ||
                         core_dcache_write_resp_ready_w ||
                         core_maint_resp_ready_w ||
                         core_prefetch_resp_ready_w;

l2_cache_core u_l2_cache_core (
    .clk(clk),
    .resetn(resetn),
    .req_valid(core_req_valid),
    .req_ready(core_req_ready),
    .req_source(core_req_source),
    .req_opcode(core_req_opcode),
    .req_uncached(core_req_uncached),
    .req_addr(core_req_addr),
    .req_size(core_req_size),
    .req_wstrb(core_req_wstrb),
    .req_line_data(core_req_line_data),
    .resp_valid(core_resp_valid),
    .resp_ready(core_resp_ready),
    .resp_source(core_resp_source),
    .resp_line_data(core_resp_line_data),
    .resp_error(core_resp_error),
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),
    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

endmodule
