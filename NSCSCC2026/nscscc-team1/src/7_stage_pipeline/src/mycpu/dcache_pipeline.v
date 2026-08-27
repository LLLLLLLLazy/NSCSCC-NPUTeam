`include "cache_defs.vh"
`include "cache_cacop_defs.vh"
`include "l2_cache_defs.vh"

module dcache_pipeline #(
    parameter [1:0] CACHEABLE_MAT = 2'b01
) (
    input wire clk,
    input wire resetn,

    input wire mem1_valid,
    input wire [31:0] mem1_va,
    output wire mem1_ready,

    input wire mem2_valid,
    input wire mem2_wr,
    input wire [31:0] mem2_pc,
    input wire mem2_postable_store,
    input wire [1:0] mem2_size,
    input wire [`CACHE_WSTRB_WIDTH-1:0] mem2_wstrb,
    input wire [`CACHE_WORD_WIDTH-1:0] mem2_wdata,
    input wire [31:0] mem2_va,
    input wire [31:0] mem2_pa,
    input wire [1:0] mem2_mat,
    input wire mem2_miss_req,
    output wire mem2_miss_ready,
    output wire mem2_array_valid,
    output wire mem2_hit,
    output wire mem2_miss,
    output wire mem2_hit_way,
    output wire mem2_load_done,
    output wire mem2_store_done,
    output wire [`CACHE_WORD_WIDTH-1:0] mem2_rdata,
    output wire mem2_refill_valid,
    output wire [`CACHE_WORD_WIDTH-1:0] mem2_refill_rdata,
    output wire dcache_busy,

    output wire prefetch_valid,
    output wire [31:0] prefetch_addr,
    output wire prefetch_block,
    input wire prefetch_ready,
    input wire prefetch_complete,

    input wire maint_valid,
    input wire [1:0] maint_op,
    input wire maint_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] maint_index,
    input wire [`CACHE_TAG_WIDTH-1:0] maint_tag,
    output wire maint_addr_ok,
    output wire maint_data_ok,
    output wire maint_l2_valid,
    output wire [1:0] maint_l2_op,
    output wire [31:0] maint_l2_addr,
    input wire maint_l2_ready,
    input wire maint_l2_done,

    output wire [3:0] arid,
    output wire [31:0] araddr,
    output wire [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    output wire arvalid,
    input wire arready,
    // L2 一拍返回整行，不是 AXI beat 流，所以没有 rlast。
    input wire [`CACHE_LINE_WIDTH-1:0] rline,
    input wire rvalid,
    output wire rready,

    output wire [3:0] awid,
    output wire [`L2_SOURCE_WIDTH-1:0] awsource,
    output wire [31:0] awaddr,
    output wire [7:0] awlen,
    output wire [2:0] awsize,
    output wire [1:0] awburst,
    output wire awvalid,
    input wire awready,
    output wire [3:0] wid,
    output wire [`CACHE_LINE_WIDTH-1:0] wline,
    output wire [`CACHE_LINE_WIDTH/8-1:0] wstrb,
    output wire wlast,
    output wire wvalid,
    input wire wready,
    input wire [3:0] bid,
    input wire bvalid,
    output wire bready
);

localparam S_IDLE = 4'd0;
localparam S_VB_READ_L1 = 4'd1;
localparam S_VB_FILL_L1 = 4'd2;
localparam S_VB_RESP = 4'd3;
localparam S_VB_EVICT_REQ = 4'd4;
localparam S_VB_EVICT_WAIT = 4'd5;
localparam S_L1_INSERT = 4'd6;
localparam S_REFILL_REQ = 4'd7;
localparam S_REFILL = 4'd8;
// 整行已寄进 refill_line_r，这一拍一次性写入数组（tag + 8 bank + dirty）。
localparam S_REFILL_WRITE = 4'd9;

localparam U_IDLE = 3'd0;
localparam U_R_REQ = 3'd1;
localparam U_R_WAIT = 3'd2;
localparam U_W_REQ = 3'd3;
localparam U_W_WAIT = 3'd4;

localparam M_IDLE = 4'd0;
localparam M_INDEX_READ = 4'd1;
localparam M_INDEX_CHECK = 4'd2;
localparam M_CLEAR = 4'd3;
localparam M_RESP = 4'd4;
localparam M_WB_REQ = 4'd5;
localparam M_WB_WAIT = 4'd6;
localparam M_HIT_LOOKUP = 4'd7;
localparam M_HIT_CHECK = 4'd8;
localparam M_LINE_READ = 4'd9;
localparam M_VB_SCAN_REQ = 4'd10;
localparam M_VB_SCAN_WB_REQ = 4'd11;
localparam M_VB_SCAN_WB_WAIT = 4'd12;
localparam M_L2_REQ = 4'd13;
localparam M_L2_WAIT = 4'd14;

localparam R_IDLE       = 3'd0;
localparam R_LOOKUP     = 3'd1;
localparam R_WAIT       = 3'd2;
localparam R_HIT_READY  = 3'd3;
localparam R_MISS_READY = 3'd4;
localparam R_HIT_RESP   = 3'd5;

reg miss_valid_r;
reg [3:0] miss_state_r;
reg miss_wr_r;
reg [1:0] miss_size_r;
reg [`CACHE_WSTRB_WIDTH-1:0] miss_wstrb_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_wdata_r;
reg [31:0] miss_pa_r;
reg [`CACHE_INDEX_WIDTH-1:0] miss_index_r;
reg [`CACHE_BANK_WIDTH-1:0] miss_bank_r;
reg [`CACHE_TAG_WIDTH-1:0] miss_tag_r;
reg miss_victim_way_r;
reg miss_victim_valid_r;
reg miss_victim_dirty_r;
reg [`CACHE_TAG_WIDTH-1:0] miss_victim_tag_r;
reg miss_need_cpu_response_r;
reg miss_posted_store_r;
reg miss_post_accept_sent_r;
reg [`CACHE_WORD_WIDTH-1:0] refill_load_data_r;
// L2 返回的整行，已经把 store 数据 merge 进目标字。
// 寄一拍再写数组，把「8 选 1 + byte merge」挡在 BRAM 写口之前，
// 换掉一条会压主频的组合链，代价是多 1 拍（12→6 而不是 12→5）。
reg [`CACHE_LINE_WIDTH-1:0] refill_line_r;
reg [`CACHE_TAG_WIDTH-1:0] wb_line_tag_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data0_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data1_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data2_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data3_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data4_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data5_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data6_r;
reg [`CACHE_WORD_WIDTH-1:0] wb_line_data7_r;
reg vb_hit_path_r;
reg [1:0] vb_hit_index_r;
reg vb_hit_dirty_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data0_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data1_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data2_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data3_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data4_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data5_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data6_r;
reg [`CACHE_WORD_WIDTH-1:0] vb_hit_data7_r;

reg miss_hold_valid_r;
reg miss_hold_cacheable_r;
reg miss_hold_wr_r;
reg miss_hold_postable_store_r;
reg [1:0] miss_hold_size_r;
reg [`CACHE_WSTRB_WIDTH-1:0] miss_hold_wstrb_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_wdata_r;
reg [31:0] miss_hold_pa_r;
reg [`CACHE_INDEX_WIDTH-1:0] miss_hold_index_r;
reg [`CACHE_BANK_WIDTH-1:0] miss_hold_bank_r;
reg [`CACHE_TAG_WIDTH-1:0] miss_hold_tag_r;
reg miss_hold_victim_way_r;
reg miss_hold_victim_valid_r;
reg miss_hold_victim_dirty_r;
reg [`CACHE_TAG_WIDTH-1:0] miss_hold_victim_tag_r;
reg miss_hold_vb_hit_r;
reg [1:0] miss_hold_vb_hit_index_r;
reg miss_hold_vb_hit_dirty_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data0_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data1_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data2_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data3_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data4_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data5_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data6_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_hold_vb_data7_r;

reg normal_lookup_meta_valid_r;
reg [`CACHE_INDEX_WIDTH-1:0] normal_lookup_meta_index_r;
reg [`CACHE_BANK_WIDTH-1:0] normal_lookup_meta_bank_r;
reg normal_lookup_meta_lru_victim_way_r;

reg [2:0] replay_state_r;
reg replay_wr_r;
reg replay_postable_store_r;
reg [1:0] replay_size_r;
reg [`CACHE_WSTRB_WIDTH-1:0] replay_wstrb_r;
reg [`CACHE_WORD_WIDTH-1:0] replay_wdata_r;
reg [31:0] replay_pa_r;
reg [`CACHE_INDEX_WIDTH-1:0] replay_index_r;
reg [`CACHE_BANK_WIDTH-1:0] replay_bank_r;
reg [`CACHE_TAG_WIDTH-1:0] replay_tag_r;
reg replay_hit_way_r;
reg [`CACHE_WORD_WIDTH-1:0] replay_rdata_r;
reg replay_lookup_meta_valid_r;
reg replay_lookup_meta_lru_victim_way_r;

reg miss_launch_valid_r;
reg miss_launch_cacheable_r;
reg miss_launch_wr_r;
reg miss_launch_postable_store_r;
reg [1:0] miss_launch_size_r;
reg [`CACHE_WSTRB_WIDTH-1:0] miss_launch_wstrb_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_wdata_r;
reg [31:0] miss_launch_pa_r;
reg [`CACHE_INDEX_WIDTH-1:0] miss_launch_index_r;
reg [`CACHE_BANK_WIDTH-1:0] miss_launch_bank_r;
reg [`CACHE_TAG_WIDTH-1:0] miss_launch_tag_r;
reg miss_launch_victim_way_r;
reg miss_launch_victim_valid_r;
reg miss_launch_victim_dirty_r;
reg [`CACHE_TAG_WIDTH-1:0] miss_launch_victim_tag_r;
reg miss_launch_vb_hit_r;
reg [1:0] miss_launch_vb_hit_index_r;
reg miss_launch_vb_hit_dirty_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data0_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data1_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data2_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data3_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data4_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data5_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data6_r;
reg [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data7_r;

reg uc_valid_r;
reg [2:0] uc_state_r;
reg uc_wr_r;
reg [1:0] uc_size_r;
reg [`CACHE_WSTRB_WIDTH-1:0] uc_wstrb_r;
reg [31:0] uc_pa_r;
reg [`CACHE_WORD_WIDTH-1:0] uc_wdata_r;

reg maint_busy_r;
reg [3:0] maint_state_r;
reg [1:0] maint_op_r;
reg maint_way_r;
reg [`L2_WAY_WIDTH-1:0] maint_l2_way_r;
reg [`CACHE_INDEX_WIDTH-1:0] maint_index_r;
reg [`CACHE_TAG_WIDTH-1:0] maint_tag_r;
reg maint_line_valid_r;
reg maint_line_dirty_r;
reg [`CACHE_TAG_WIDTH-1:0] maint_line_tag_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data0_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data1_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data2_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data3_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data4_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data5_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data6_r;
reg [`CACHE_WORD_WIDTH-1:0] maint_line_data7_r;

wire [`CACHE_INDEX_WIDTH-1:0] mem1_index_w;
wire [`CACHE_BANK_WIDTH-1:0] mem1_bank_w;
wire [`CACHE_INDEX_WIDTH-1:0] mem2_index_w;
wire [`CACHE_BANK_WIDTH-1:0] mem2_bank_w;
wire [`CACHE_TAG_WIDTH-1:0] mem2_tag_w;
wire mem2_cacheable_w;
wire lookup_valid_w;
wire [`CACHE_INDEX_WIDTH-1:0] lookup_index_w;
wire [`CACHE_BANK_WIDTH-1:0] lookup_bank_w;
wire normal_lookup_req_w;
wire normal_lookup_accept_w;
wire replay_lookup_req_w;
wire replay_lookup_accept_w;
wire replay_active_w;
wire miss_entry_valid_w;
wire miss_entry_posted_store_w;
wire miss_entry_need_cpu_response_w;
wire miss_entry_empty_w;
wire replay_start_w;
wire replay_resp_valid_w;
wire mem2_lookup_match_w;

wire way0_valid_w;
wire way0_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] way0_tag_w;
wire [`CACHE_WORD_WIDTH-1:0] way0_rdata_w;
wire way1_valid_w;
wire way1_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] way1_tag_w;
wire [`CACHE_WORD_WIDTH-1:0] way1_rdata_w;
wire compare_hit_w;
wire compare_hit_way_w;
wire compare_hit_dirty_w;
wire [`CACHE_WORD_WIDTH-1:0] compare_rdata_w;
wire replay_compare_hit_w;
wire replay_compare_hit_way_w;
wire replay_compare_hit_dirty_w;
wire [`CACHE_WORD_WIDTH-1:0] replay_compare_rdata_w;
wire replace_way_w;
wire replace_way_raw_unused_w;
wire lru_victim_way_w;
wire lookup_lru_victim_way_w;
wire miss_lru_victim_way_w;
wire replace_update_w;
wire [`CACHE_INDEX_WIDTH-1:0] replace_victim_index_w;
wire replace_access_valid_w;
wire [`CACHE_INDEX_WIDTH-1:0] replace_access_index_w;
wire replace_access_way_w;

wire store_ready_w;
wire store_can_fire_w;
wire store_fire_w;
wire replay_store_fire_w;
wire array_store_valid_w;
wire array_store_way_w;
wire [`CACHE_INDEX_WIDTH-1:0] array_store_index_w;
wire [`CACHE_BANK_WIDTH-1:0] array_store_bank_w;
wire [`CACHE_WSTRB_WIDTH-1:0] array_store_wstrb_w;
wire [`CACHE_WORD_WIDTH-1:0] array_store_wdata_w;
wire store_lookup_conflict_w;
wire array_write_busy_w;
wire lookup_write_conflict_w;
wire lookup_wb_conflict_w;
wire wb_write_conflict_w;
wire wb_read_valid_w;
wire wb_read_way_w;
wire [`CACHE_INDEX_WIDTH-1:0] wb_read_index_w;
wire wb_line_array_valid_w;
wire wb_line_valid_w;
wire wb_line_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] wb_line_tag_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] wb_line_data7_w;

wire vb_lookup_valid_w;
wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] vb_lookup_block_addr_w;
wire vb_lookup_from_mem2_w;
wire vb_lookup_from_replay_w;
wire vb_lookup_hit_w;
wire [1:0] vb_lookup_hit_index_w;
wire vb_lookup_hit_dirty_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_lookup_data7_w;

wire vb_insert_valid_w;
wire vb_insert_dirty_w;
wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] vb_insert_block_addr_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_insert_data7_w;
wire vb_insert_ready_w;

wire vb_evict_valid_w;
wire vb_evict_dirty_w;
wire [1:0] vb_evict_index_w;
wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] vb_evict_block_addr_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_evict_data7_w;
wire vb_evict_accept_w;

wire vb_swap_valid_w;
wire [1:0] vb_swap_index_w;
wire vb_swap_insert_valid_w;
wire vb_swap_insert_dirty_w;
wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] vb_swap_insert_block_addr_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_swap_insert_data7_w;
wire vb_resp_valid_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_resp_rdata_w;
wire vb_scan_req_w;
wire vb_scan_busy_w;
wire vb_scan_evict_valid_w;
wire vb_scan_evict_dirty_w;
wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] vb_scan_evict_block_addr_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_scan_evict_data7_w;
wire vb_scan_evict_accept_w;
wire vb_scan_done_w;
wire vb_line_fill_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_target_word_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_store_merge_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] vb_line_fill_data7_w;
wire vb_line_fill_dirty_w;
// refill 现在整行一拍写入，复用 array 的 victim_fill 口（tag + 8 bank +
// dirty 一拍写完，且优先级最高）。原来那组按 bank 的 refill_write_* 端口
// 已从 dcache_array 删除。
wire refill_write_line_w;
wire [`CACHE_LINE_WIDTH-1:0] line_fill_line_w;
wire line_fill_valid_w;
wire line_fill_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] line_fill_tag_w;
wire line_fill_way_w;
wire [`CACHE_INDEX_WIDTH-1:0] line_fill_index_w;

wire miss_issue_fire_w;
wire victim_valid_w;
wire victim_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] victim_tag_w;
wire vb_evict_req_w;
wire vb_evict_wait_w;
wire vb_l1_read_w;
wire vb_l1_read_start_w;
wire vb_l1_read_wait_w;
wire vb_l1_read_req_w;
wire refill_req_w;
wire refill_req_fire_w;
wire refill_early_direct_w;
wire refill_early_after_insert_w;
wire refill_early_req_w;
wire refill_early_fire_w;
wire refill_wait_w;
wire refill_arrive_w;
wire refill_done_w;
wire [`CACHE_WORD_WIDTH-1:0] refill_target_word_w;
wire [`CACHE_WORD_WIDTH-1:0] refill_store_merge_w;
wire [`CACHE_LINE_WIDTH-1:0] refill_line_merged_w;

wire uc_r_req_w;
wire uc_r_req_fire_w;
wire uc_r_wait_w;
wire uc_r_done_w;
wire uc_w_req_w;
wire uc_w_req_fire_w;
wire uc_w_wait_w;
wire uc_w_done_w;
wire foreground_response_valid_w;
wire [`CACHE_WORD_WIDTH-1:0] foreground_response_data_w;
wire foreground_load_miss_done_w;
wire foreground_blocking_store_done_w;
wire foreground_vb_done_w;
wire foreground_uncached_done_w;
wire foreground_replay_done_w;
wire posted_store_refill_complete_w;
wire posted_store_vb_complete_w;
wire background_store_complete_w;
wire posted_store_context_captured_w;
wire posted_store_accept_valid_w;
wire posted_store_accept_fire_w;

wire rd_req_w;
wire [31:0] rd_addr_w;
wire rd_line_w;
wire [1:0] rd_size_w;
wire rd_ready_w;
wire ret_valid_w;
// L2 一拍返回整行（bank0 在最低 32 位）。
// uncached 单字读时目标字在最低 32 位。
wire [`CACHE_LINE_WIDTH-1:0] ret_line_w;
wire wr_req_w;
wire [31:0] wr_addr_w;
wire wr_line_w;
wire [`L2_SOURCE_WIDTH-1:0] wr_source_w;
wire [1:0] wr_size_w;
wire [`CACHE_WSTRB_WIDTH-1:0] wr_wstrb_w;
wire [`CACHE_WORD_WIDTH-1:0] wr_data_w;
wire wr_ready_w;
wire wr_done_w;
wire wr_uc_grant_w;
wire wr_vb_scan_grant_w;
wire wr_vb_evict_grant_w;
wire wr_maint_grant_w;
wire wr_vb_evict_fire_w;
wire array_valid_w;

wire maint_idle_w;
wire maint_accept_w;
wire maint_index_op_w;
wire maint_index_read_w;
wire maint_index_check_w;
wire maint_clear_fire_w;
wire maint_clean_or_invalid_w;
wire maint_wb_req_w;
wire maint_wb_req_fire_w;
wire maint_wb_wait_w;
wire maint_vb_scan_wb_req_w;
wire maint_vb_scan_wb_req_fire_w;
wire maint_vb_scan_wb_wait_w;
wire maint_l2_req_w;
wire maint_l2_req_fire_w;
wire maint_need_l2_w;
wire [3:0] maint_accept_start_state_w;
wire maint_hit_lookup_w;
wire maint_hit_check_w;
wire maint_line_read_w;
wire maint_way0_hit_w;
wire maint_way1_hit_w;
wire maint_hit_w;
wire maint_hit_way_w;
wire maint_hit_dirty_w;
wire mem2_current_miss_w;
wire miss_hold_match_mem2_w;
wire miss_hold_use_w;
wire replay_hit_ready_w;
wire replay_hit_fire_w;
wire replay_wait_miss_w;
wire external_miss_fire_w;
wire replay_miss_fire_w;
wire prefetch_train_valid_w;
wire prefetch_demand_miss_valid_w;
wire prefetch_demand_block_w;
wire miss_source_cacheable_w;
wire miss_source_wr_w;
wire miss_source_postable_store_w;
wire [1:0] miss_source_size_w;
wire [`CACHE_WSTRB_WIDTH-1:0] miss_source_wstrb_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_wdata_w;
wire [31:0] miss_source_pa_w;
wire [`CACHE_INDEX_WIDTH-1:0] miss_source_index_w;
wire [`CACHE_BANK_WIDTH-1:0] miss_source_bank_w;
wire [`CACHE_TAG_WIDTH-1:0] miss_source_tag_w;
wire miss_source_victim_way_w;
wire miss_source_victim_valid_w;
wire miss_source_victim_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] miss_source_victim_tag_w;
wire miss_source_vb_hit_w;
wire [1:0] miss_source_vb_hit_index_w;
wire miss_source_vb_hit_dirty_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_source_vb_data7_w;
wire miss_launch_fire_w;
wire miss_launch_cacheable_w;
wire miss_launch_wr_w;
wire miss_launch_store_commit_ok_w;
wire miss_launch_cached_wr_w;
wire miss_launch_postable_store_w;
wire [1:0] miss_launch_size_w;
wire [`CACHE_WSTRB_WIDTH-1:0] miss_launch_wstrb_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_wdata_w;
wire [31:0] miss_launch_pa_w;
wire [`CACHE_INDEX_WIDTH-1:0] miss_launch_index_w;
wire [`CACHE_BANK_WIDTH-1:0] miss_launch_bank_w;
wire [`CACHE_TAG_WIDTH-1:0] miss_launch_tag_w;
wire miss_launch_victim_way_w;
wire miss_launch_victim_valid_w;
wire miss_launch_victim_dirty_w;
wire [`CACHE_TAG_WIDTH-1:0] miss_launch_victim_tag_w;
wire miss_launch_vb_hit_w;
wire [1:0] miss_launch_vb_hit_index_w;
wire miss_launch_vb_hit_dirty_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data0_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data1_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data2_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data3_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data4_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data5_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data6_w;
wire [`CACHE_WORD_WIDTH-1:0] miss_launch_vb_data7_w;

assign mem1_index_w = mem1_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
assign mem1_bank_w = mem1_va[`CACHE_BANK_MSB:`CACHE_BANK_LSB];
assign mem2_index_w = mem2_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
assign mem2_bank_w = mem2_va[`CACHE_BANK_MSB:`CACHE_BANK_LSB];
assign mem2_tag_w = mem2_pa[`CACHE_TAG_MSB:`CACHE_TAG_LSB];
assign mem2_cacheable_w = mem2_mat == CACHEABLE_MAT;

assign vb_lookup_from_replay_w = replay_resp_valid_w;
assign vb_lookup_from_mem2_w = mem2_valid &&
                               mem2_cacheable_w &&
                               mem2_lookup_match_w &&
                               !vb_lookup_from_replay_w;
assign vb_lookup_valid_w = vb_lookup_from_replay_w ||
                           vb_lookup_from_mem2_w;
assign vb_lookup_block_addr_w = vb_lookup_from_replay_w ? replay_pa_r[31:`CACHE_OFFSET_WIDTH] :
                                mem2_pa[31:`CACHE_OFFSET_WIDTH];
assign vb_insert_valid_w = miss_valid_r &&
                           ((miss_state_r == S_L1_INSERT) || vb_evict_req_w) &&
                           miss_victim_valid_r;
assign vb_insert_dirty_w = miss_victim_dirty_r;
assign vb_insert_block_addr_w = {miss_victim_tag_r, miss_index_r};
assign vb_insert_data0_w = wb_line_data0_r;
assign vb_insert_data1_w = wb_line_data1_r;
assign vb_insert_data2_w = wb_line_data2_r;
assign vb_insert_data3_w = wb_line_data3_r;
assign vb_insert_data4_w = wb_line_data4_r;
assign vb_insert_data5_w = wb_line_data5_r;
assign vb_insert_data6_w = wb_line_data6_r;
assign vb_insert_data7_w = wb_line_data7_r;
assign vb_evict_accept_w = vb_evict_wait_w && wr_done_w;
assign vb_swap_valid_w = vb_resp_valid_w && vb_hit_path_r;
assign vb_swap_index_w = vb_hit_index_r;
assign vb_swap_insert_valid_w = miss_victim_valid_r;
assign vb_swap_insert_dirty_w = miss_victim_dirty_r;
assign vb_swap_insert_block_addr_w = {miss_victim_tag_r, miss_index_r};
assign vb_swap_insert_data0_w = wb_line_data0_r;
assign vb_swap_insert_data1_w = wb_line_data1_r;
assign vb_swap_insert_data2_w = wb_line_data2_r;
assign vb_swap_insert_data3_w = wb_line_data3_r;
assign vb_swap_insert_data4_w = wb_line_data4_r;
assign vb_swap_insert_data5_w = wb_line_data5_r;
assign vb_swap_insert_data6_w = wb_line_data6_r;
assign vb_swap_insert_data7_w = wb_line_data7_r;
assign vb_resp_valid_w = miss_valid_r && (miss_state_r == S_VB_RESP);
assign vb_resp_rdata_w = (miss_bank_r == 3'd0) ? vb_hit_data0_r :
                         (miss_bank_r == 3'd1) ? vb_hit_data1_r :
                         (miss_bank_r == 3'd2) ? vb_hit_data2_r :
                         (miss_bank_r == 3'd3) ? vb_hit_data3_r :
                         (miss_bank_r == 3'd4) ? vb_hit_data4_r :
                         (miss_bank_r == 3'd5) ? vb_hit_data5_r :
                         (miss_bank_r == 3'd6) ? vb_hit_data6_r :
                         vb_hit_data7_r;
assign vb_scan_req_w = maint_busy_r && (maint_state_r == M_VB_SCAN_REQ) &&
                       !vb_scan_busy_w && !vb_scan_done_w;
assign vb_scan_evict_accept_w = maint_vb_scan_wb_wait_w && wr_done_w;
assign vb_line_fill_w = miss_valid_r && (miss_state_r == S_VB_FILL_L1);
assign vb_line_fill_dirty_w = miss_wr_r ? 1'b1 : vb_hit_dirty_r;
assign vb_line_fill_target_word_w = (miss_bank_r == 3'd0) ? vb_hit_data0_r :
                                    (miss_bank_r == 3'd1) ? vb_hit_data1_r :
                                    (miss_bank_r == 3'd2) ? vb_hit_data2_r :
                                    (miss_bank_r == 3'd3) ? vb_hit_data3_r :
                                    (miss_bank_r == 3'd4) ? vb_hit_data4_r :
                                    (miss_bank_r == 3'd5) ? vb_hit_data5_r :
                                    (miss_bank_r == 3'd6) ? vb_hit_data6_r :
                                    vb_hit_data7_r;
assign vb_line_fill_store_merge_w = {
    miss_wstrb_r[3] ? miss_wdata_r[31:24] : vb_line_fill_target_word_w[31:24],
    miss_wstrb_r[2] ? miss_wdata_r[23:16] : vb_line_fill_target_word_w[23:16],
    miss_wstrb_r[1] ? miss_wdata_r[15:8]  : vb_line_fill_target_word_w[15:8],
    miss_wstrb_r[0] ? miss_wdata_r[7:0]   : vb_line_fill_target_word_w[7:0]
};
assign vb_line_fill_data0_w = (miss_wr_r && (miss_bank_r == 3'd0)) ?
                              vb_line_fill_store_merge_w : vb_hit_data0_r;
assign vb_line_fill_data1_w = (miss_wr_r && (miss_bank_r == 3'd1)) ?
                              vb_line_fill_store_merge_w : vb_hit_data1_r;
assign vb_line_fill_data2_w = (miss_wr_r && (miss_bank_r == 3'd2)) ?
                              vb_line_fill_store_merge_w : vb_hit_data2_r;
assign vb_line_fill_data3_w = (miss_wr_r && (miss_bank_r == 3'd3)) ?
                              vb_line_fill_store_merge_w : vb_hit_data3_r;
assign vb_line_fill_data4_w = (miss_wr_r && (miss_bank_r == 3'd4)) ?
                              vb_line_fill_store_merge_w : vb_hit_data4_r;
assign vb_line_fill_data5_w = (miss_wr_r && (miss_bank_r == 3'd5)) ?
                              vb_line_fill_store_merge_w : vb_hit_data5_r;
assign vb_line_fill_data6_w = (miss_wr_r && (miss_bank_r == 3'd6)) ?
                              vb_line_fill_store_merge_w : vb_hit_data6_r;
assign vb_line_fill_data7_w = (miss_wr_r && (miss_bank_r == `CACHE_LAST_BANK_INDEX)) ?
                              vb_line_fill_store_merge_w : vb_hit_data7_r;
// VB 命中回填和 L2 refill 回填现在共用 array 的全行写口。
// 两者状态互斥（S_VB_FILL_L1 vs S_REFILL_WRITE），不会同拍。
assign line_fill_valid_w = vb_line_fill_w || refill_write_line_w;
assign line_fill_way_w = miss_victim_way_r;
assign line_fill_index_w = miss_index_r;
assign line_fill_tag_w = miss_tag_r;
// refill 带回来的行：若是 posted/blocking store，miss 那一拍的写数据
// 已经在「到达」时 merge 进 refill_line_r 了，所以这里 dirty 跟着 miss_wr_r。
assign line_fill_dirty_w = refill_write_line_w ? miss_wr_r :
                                                 vb_line_fill_dirty_w;
assign line_fill_line_w = refill_write_line_w ? refill_line_r :
    {vb_line_fill_data7_w, vb_line_fill_data6_w,
     vb_line_fill_data5_w, vb_line_fill_data4_w,
     vb_line_fill_data3_w, vb_line_fill_data2_w,
     vb_line_fill_data1_w, vb_line_fill_data0_w};

// A CACOP maintenance request is issued from the same MEM2 slot as the
// instruction itself.  Do not let the combinational mem2_miss produced by that
// slot block the maintenance handshake; an already issued miss request still
// has priority.
assign maint_idle_w = !maint_busy_r && miss_entry_empty_w && !uc_valid_r &&
                      !miss_launch_valid_r &&
                      (!mem2_miss || maint_valid) && !mem2_miss_req;
assign maint_accept_w = maint_valid && maint_idle_w;
assign maint_accept_start_state_w =
    (maint_op == `CACHE_CACOP_MAINT_STORE_TAG) ? M_CLEAR :
    (maint_op == `CACHE_CACOP_MAINT_INDEX_INV) ? M_INDEX_READ :
    (maint_op == `CACHE_CACOP_MAINT_HIT_INV) ? M_HIT_LOOKUP :
    M_RESP;
assign maint_index_op_w = (maint_op_r == `CACHE_CACOP_MAINT_STORE_TAG) ||
                          (maint_op_r == `CACHE_CACOP_MAINT_INDEX_INV);
assign maint_index_read_w = maint_busy_r && (maint_state_r == M_INDEX_READ);
assign maint_index_check_w = maint_busy_r && (maint_state_r == M_INDEX_CHECK);
assign maint_clear_fire_w = maint_busy_r && (maint_state_r == M_CLEAR);
assign maint_clean_or_invalid_w = !maint_line_valid_r || !maint_line_dirty_r;
assign maint_wb_req_w = maint_busy_r && (maint_state_r == M_WB_REQ);
assign maint_wb_req_fire_w = wr_maint_grant_w && wr_ready_w;
assign maint_wb_wait_w = maint_busy_r && (maint_state_r == M_WB_WAIT);
assign maint_vb_scan_wb_req_w = maint_busy_r && (maint_state_r == M_VB_SCAN_WB_REQ);
assign maint_vb_scan_wb_req_fire_w = wr_vb_scan_grant_w && wr_ready_w;
assign maint_vb_scan_wb_wait_w = maint_busy_r && (maint_state_r == M_VB_SCAN_WB_WAIT);
assign maint_l2_req_w = maint_busy_r && (maint_state_r == M_L2_REQ);
assign maint_l2_req_fire_w = maint_l2_req_w && maint_l2_ready;
assign maint_need_l2_w = (maint_op_r == `CACHE_CACOP_MAINT_INDEX_INV) ||
                         (maint_op_r == `CACHE_CACOP_MAINT_HIT_INV);
assign maint_hit_lookup_w = maint_busy_r && (maint_state_r == M_HIT_LOOKUP);
assign maint_hit_check_w = maint_busy_r && (maint_state_r == M_HIT_CHECK);
assign maint_line_read_w = maint_busy_r && (maint_state_r == M_LINE_READ);
assign maint_way0_hit_w = maint_hit_check_w && array_valid_w && way0_valid_w && (way0_tag_w == maint_tag_r);
assign maint_way1_hit_w = maint_hit_check_w && array_valid_w && way1_valid_w && (way1_tag_w == maint_tag_r);
assign maint_hit_w = maint_way0_hit_w || maint_way1_hit_w;
assign maint_hit_way_w = maint_way1_hit_w;
assign maint_hit_dirty_w = maint_hit_way_w ? way1_dirty_w : way0_dirty_w;

assign replay_active_w = replay_state_r != R_IDLE;
assign miss_entry_valid_w = miss_valid_r;
assign miss_entry_posted_store_w = miss_posted_store_r;
assign miss_entry_need_cpu_response_w = miss_need_cpu_response_r;
assign miss_entry_empty_w = !miss_entry_valid_w;

assign dcache_busy = miss_entry_valid_w || uc_valid_r || maint_busy_r ||
                     replay_active_w || miss_launch_valid_r;

assign normal_lookup_req_w = mem1_valid && mem1_ready;
assign replay_lookup_req_w = replay_state_r == R_LOOKUP;

assign mem1_ready = miss_entry_empty_w &&
                    !uc_valid_r && !maint_busy_r &&
                    !maint_valid && !replay_active_w &&
                    !miss_launch_valid_r &&
                    !mem2_miss && !mem2_miss_req &&
                    !store_lookup_conflict_w;


assign lookup_valid_w = maint_hit_lookup_w || replay_lookup_req_w || normal_lookup_req_w;
assign lookup_index_w = maint_hit_lookup_w ? maint_index_r :
                        replay_lookup_req_w ? replay_index_r : mem1_index_w;
assign lookup_bank_w = maint_hit_lookup_w ? {`CACHE_BANK_WIDTH{1'b0}} :
                       replay_lookup_req_w ? replay_bank_r : mem1_bank_w;


assign normal_lookup_accept_w = normal_lookup_req_w &&
                                !maint_hit_lookup_w &&
                                !replay_lookup_req_w &&
                                !lookup_write_conflict_w &&
                                !lookup_wb_conflict_w;
assign replay_lookup_accept_w = replay_lookup_req_w &&
                                !maint_hit_lookup_w &&
                                !lookup_write_conflict_w &&
                                !lookup_wb_conflict_w;


assign mem2_lookup_match_w = array_valid_w &&
                             normal_lookup_meta_valid_r &&
                             (normal_lookup_meta_index_r == mem2_index_w) &&
                             (normal_lookup_meta_bank_r  == mem2_bank_w);

assign mem2_array_valid = mem2_valid && mem2_cacheable_w && mem2_lookup_match_w;
assign mem2_hit = mem2_array_valid && compare_hit_w;
assign mem2_current_miss_w = mem2_valid &&
                             (
                                 (!mem2_cacheable_w) ||
                                 (mem2_cacheable_w && mem2_lookup_match_w && !compare_hit_w)
                             );

assign miss_hold_match_mem2_w = miss_hold_valid_r && mem2_valid &&
                                (miss_hold_pa_r == mem2_pa) &&
                                (miss_hold_wr_r == mem2_wr) &&
                                (miss_hold_size_r == mem2_size);


assign replay_start_w = mem2_valid && mem2_cacheable_w &&
                        !mem2_lookup_match_w &&
                        !replay_active_w &&
                        !miss_launch_valid_r &&
                        miss_entry_empty_w && !uc_valid_r && !maint_busy_r && !maint_valid &&
                        !miss_hold_match_mem2_w;

assign replay_resp_valid_w = (replay_state_r == R_WAIT) &&
                             array_valid_w && replay_lookup_meta_valid_r;
assign replay_wait_miss_w = replay_resp_valid_w && !replay_compare_hit_w;
assign replay_hit_ready_w = (replay_state_r == R_HIT_READY) &&
                            (!replay_wr_r || store_ready_w);

assign mem2_miss = mem2_current_miss_w ||
                   miss_hold_match_mem2_w ||
                   replay_start_w ||
                   (replay_active_w && (replay_state_r != R_HIT_RESP));

assign mem2_miss_ready = miss_entry_empty_w && !uc_valid_r && !maint_busy_r &&
                         !maint_valid && !miss_launch_valid_r &&
                         (
                             (!replay_active_w && !replay_start_w) ||
                             (replay_state_r == R_MISS_READY) ||
                             replay_hit_ready_w
                         );

assign replay_hit_fire_w = replay_hit_ready_w;

assign external_miss_fire_w = mem2_miss_req && mem2_miss_ready &&
                              miss_entry_empty_w && mem2_miss &&
                              !replay_hit_ready_w;

assign prefetch_train_valid_w =
    external_miss_fire_w &&
    mem2_valid &&
    mem2_cacheable_w &&
    (!mem2_wr || mem2_postable_store);
assign prefetch_demand_miss_valid_w =
    external_miss_fire_w &&
    mem2_valid &&
    mem2_cacheable_w;
assign prefetch_demand_block_w =
    mem2_valid &&
    mem2_cacheable_w;
assign prefetch_block =
    dcache_busy ||
    prefetch_demand_block_w;

assign replay_miss_fire_w = (replay_state_r == R_MISS_READY) &&
                            miss_hold_valid_r &&
                            !miss_launch_valid_r &&
                            miss_entry_empty_w &&
                            !uc_valid_r &&
                            !maint_busy_r &&
                            !maint_valid;

assign miss_issue_fire_w = external_miss_fire_w || replay_miss_fire_w;

assign mem2_hit_way = compare_hit_way_w;
assign mem2_load_done = mem2_valid && !mem2_wr && mem2_hit;
assign mem2_store_done = store_fire_w;
assign mem2_rdata = compare_rdata_w;
assign foreground_load_miss_done_w =
    refill_done_w &&
    !miss_wr_r && miss_entry_need_cpu_response_w;
// blocking store（SC 等不可 post 的 store）在写数组那一拍完成。
// 整行一拍写入后，refill_done_w 就是「数据已可见」，不再需要 early restart ——
// 原来那套是为了「8 个 beat 里目标字先到就放行」，现在全行同时到达，
// 提前放行已经没有对象了。
assign foreground_blocking_store_done_w =
    refill_done_w &&
    miss_wr_r && miss_entry_need_cpu_response_w;
assign foreground_vb_done_w =
    vb_resp_valid_w && miss_entry_need_cpu_response_w;
assign foreground_uncached_done_w = uc_r_done_w || uc_w_done_w;
assign foreground_replay_done_w = replay_state_r == R_HIT_RESP;
assign posted_store_refill_complete_w =
    refill_done_w && miss_entry_posted_store_w;
assign posted_store_vb_complete_w =
    vb_resp_valid_w && miss_entry_posted_store_w;
assign background_store_complete_w =
    posted_store_refill_complete_w || posted_store_vb_complete_w;
assign posted_store_context_captured_w =
    miss_launch_fire_w &&
    miss_launch_cacheable_w &&
    miss_launch_cached_wr_w &&
    miss_launch_postable_store_w;
assign posted_store_accept_valid_w =
    posted_store_context_captured_w &&
    !miss_post_accept_sent_r;
assign posted_store_accept_fire_w = posted_store_accept_valid_w;
assign foreground_response_valid_w =
    foreground_load_miss_done_w ||
    foreground_blocking_store_done_w ||
    foreground_vb_done_w ||
    foreground_uncached_done_w ||
    foreground_replay_done_w ||
    posted_store_accept_fire_w;
assign foreground_response_data_w =
    foreground_replay_done_w ? replay_rdata_r :
    foreground_vb_done_w ? (!miss_wr_r ? vb_resp_rdata_w :
                            {`CACHE_WORD_WIDTH{1'b0}}) :
    foreground_load_miss_done_w ? refill_load_data_r :
    uc_r_done_w ? ret_line_w[`CACHE_WORD_WIDTH-1:0] :
    {`CACHE_WORD_WIDTH{1'b0}};
assign mem2_refill_valid = foreground_response_valid_w;
assign mem2_refill_rdata = foreground_response_data_w;

assign store_can_fire_w = mem2_valid && mem2_wr && mem2_cacheable_w &&
                          mem2_lookup_match_w && compare_hit_w &&
                          store_ready_w && miss_entry_empty_w && !uc_valid_r &&
                          !maint_busy_r && !replay_active_w &&
                          !miss_launch_valid_r;
assign store_fire_w = store_can_fire_w;


assign replay_store_fire_w = replay_hit_fire_w && replay_wr_r;
assign array_store_valid_w = store_fire_w || replay_store_fire_w;
assign array_store_way_w = replay_store_fire_w ? replay_hit_way_r : compare_hit_way_w;
assign array_store_index_w = replay_store_fire_w ? replay_index_r : mem2_index_w;
assign array_store_bank_w = replay_store_fire_w ? replay_bank_r : mem2_bank_w;
assign array_store_wstrb_w = replay_store_fire_w ? replay_wstrb_r : mem2_wstrb;
assign array_store_wdata_w = replay_store_fire_w ? replay_wdata_r : mem2_wdata;

assign store_lookup_conflict_w = store_can_fire_w &&
                                 (mem1_index_w == mem2_index_w) &&
                                 (mem1_bank_w == mem2_bank_w);

assign miss_lru_victim_way_w = replay_wait_miss_w ? replay_lookup_meta_lru_victim_way_r :
                                                   normal_lookup_meta_lru_victim_way_r;
assign replace_way_w = !way0_valid_w ? 1'b0 :
                       !way1_valid_w ? 1'b1 :
                                       miss_lru_victim_way_w;
assign victim_valid_w = replace_way_w ? way1_valid_w : way0_valid_w;
assign victim_dirty_w = replace_way_w ? way1_dirty_w : way0_dirty_w;
assign victim_tag_w = replace_way_w ? way1_tag_w : way0_tag_w;

assign miss_hold_use_w = miss_hold_valid_r &&
                         (miss_hold_match_mem2_w || (replay_state_r == R_MISS_READY));
assign miss_source_cacheable_w = miss_hold_use_w ? miss_hold_cacheable_r : mem2_cacheable_w;
assign miss_source_wr_w = miss_hold_use_w ? miss_hold_wr_r : mem2_wr;
assign miss_source_postable_store_w = miss_hold_use_w ? miss_hold_postable_store_r :
                                                        mem2_postable_store;
assign miss_source_size_w = miss_hold_use_w ? miss_hold_size_r : mem2_size;
assign miss_source_wstrb_w = miss_hold_use_w ? miss_hold_wstrb_r : mem2_wstrb;
assign miss_source_wdata_w = miss_hold_use_w ? miss_hold_wdata_r : mem2_wdata;
assign miss_source_pa_w = miss_hold_use_w ? miss_hold_pa_r : mem2_pa;
assign miss_source_index_w = miss_hold_use_w ? miss_hold_index_r : mem2_index_w;
assign miss_source_bank_w = miss_hold_use_w ? miss_hold_bank_r : mem2_bank_w;
assign miss_source_tag_w = miss_hold_use_w ? miss_hold_tag_r : mem2_tag_w;
assign miss_source_victim_way_w = miss_hold_use_w ? miss_hold_victim_way_r : replace_way_w;
assign miss_source_victim_valid_w = miss_hold_use_w ? miss_hold_victim_valid_r : victim_valid_w;
assign miss_source_victim_dirty_w = miss_hold_use_w ? miss_hold_victim_dirty_r : victim_dirty_w;
assign miss_source_victim_tag_w = miss_hold_use_w ? miss_hold_victim_tag_r : victim_tag_w;
assign miss_source_vb_hit_w = miss_source_cacheable_w &&
                              (miss_hold_use_w ? miss_hold_vb_hit_r :
                                                 (vb_lookup_valid_w && vb_lookup_hit_w));
assign miss_source_vb_hit_index_w = miss_hold_use_w ? miss_hold_vb_hit_index_r :
                                                      vb_lookup_hit_index_w;
assign miss_source_vb_hit_dirty_w = miss_hold_use_w ? miss_hold_vb_hit_dirty_r :
                                                      vb_lookup_hit_dirty_w;
assign miss_source_vb_data0_w = miss_hold_use_w ? miss_hold_vb_data0_r : vb_lookup_data0_w;
assign miss_source_vb_data1_w = miss_hold_use_w ? miss_hold_vb_data1_r : vb_lookup_data1_w;
assign miss_source_vb_data2_w = miss_hold_use_w ? miss_hold_vb_data2_r : vb_lookup_data2_w;
assign miss_source_vb_data3_w = miss_hold_use_w ? miss_hold_vb_data3_r : vb_lookup_data3_w;
assign miss_source_vb_data4_w = miss_hold_use_w ? miss_hold_vb_data4_r : vb_lookup_data4_w;
assign miss_source_vb_data5_w = miss_hold_use_w ? miss_hold_vb_data5_r : vb_lookup_data5_w;
assign miss_source_vb_data6_w = miss_hold_use_w ? miss_hold_vb_data6_r : vb_lookup_data6_w;
assign miss_source_vb_data7_w = miss_hold_use_w ? miss_hold_vb_data7_r : vb_lookup_data7_w;
assign miss_launch_fire_w = miss_launch_valid_r &&
                            miss_entry_empty_w &&
                            !uc_valid_r &&
                            !maint_busy_r;
assign miss_launch_cacheable_w = miss_launch_cacheable_r;
assign miss_launch_wr_w = miss_launch_wr_r;
// MEM2 槽位在 miss 处理途中可能被 WB 异常 / ertn / refetch 冲刷
// (mem2_valid 已含 mem1_mem2_reg_clear)。此时这条 store 不应提交数据：
// 把它降级成一次普通的只读 refill，让 miss FSM 自然排空。
// uncached 路径不降级 —— 对设备地址发读会产生副作用，宁可保持原行为。
assign miss_launch_store_commit_ok_w = mem2_valid;
assign miss_launch_cached_wr_w = miss_launch_wr_w && miss_launch_store_commit_ok_w;
assign miss_launch_postable_store_w = miss_launch_postable_store_r;
assign miss_launch_size_w = miss_launch_size_r;
assign miss_launch_wstrb_w = miss_launch_wstrb_r;
assign miss_launch_wdata_w = miss_launch_wdata_r;
assign miss_launch_pa_w = miss_launch_pa_r;
assign miss_launch_index_w = miss_launch_index_r;
assign miss_launch_bank_w = miss_launch_bank_r;
assign miss_launch_tag_w = miss_launch_tag_r;
assign miss_launch_victim_way_w = miss_launch_victim_way_r;
assign miss_launch_victim_valid_w = miss_launch_victim_valid_r;
assign miss_launch_victim_dirty_w = miss_launch_victim_dirty_r;
assign miss_launch_victim_tag_w = miss_launch_victim_tag_r;
assign miss_launch_vb_hit_w = miss_launch_cacheable_r && miss_launch_vb_hit_r;
assign miss_launch_vb_hit_index_w = miss_launch_vb_hit_index_r;
assign miss_launch_vb_hit_dirty_w = miss_launch_vb_hit_dirty_r;
assign miss_launch_vb_data0_w = miss_launch_vb_data0_r;
assign miss_launch_vb_data1_w = miss_launch_vb_data1_r;
assign miss_launch_vb_data2_w = miss_launch_vb_data2_r;
assign miss_launch_vb_data3_w = miss_launch_vb_data3_r;
assign miss_launch_vb_data4_w = miss_launch_vb_data4_r;
assign miss_launch_vb_data5_w = miss_launch_vb_data5_r;
assign miss_launch_vb_data6_w = miss_launch_vb_data6_r;
assign miss_launch_vb_data7_w = miss_launch_vb_data7_r;
assign replace_update_w = miss_launch_fire_w && miss_launch_cacheable_w;
assign replace_victim_index_w = lookup_index_w;
assign replace_access_valid_w = replace_update_w ||
                                mem2_load_done ||
                                store_fire_w ||
                                replay_hit_fire_w;
assign replace_access_index_w = replace_update_w ? miss_launch_index_w :
                                replay_hit_fire_w ? replay_index_r :
                                mem2_index_w;
assign replace_access_way_w = replace_update_w ? miss_launch_victim_way_w :
                              replay_hit_fire_w ? replay_hit_way_r :
                              compare_hit_way_w;
assign lookup_lru_victim_way_w =
    (replace_access_valid_w && (replace_access_index_w == lookup_index_w)) ?
        ~replace_access_way_w :
        lru_victim_way_w;

assign vb_evict_req_w = miss_valid_r && (miss_state_r == S_VB_EVICT_REQ);
assign vb_evict_wait_w = miss_valid_r && (miss_state_r == S_VB_EVICT_WAIT);
assign vb_l1_read_start_w = miss_launch_fire_w &&
                            miss_launch_cacheable_w &&
                            miss_launch_victim_valid_w;
assign vb_l1_read_wait_w = miss_valid_r && (miss_state_r == S_VB_READ_L1);
assign vb_l1_read_req_w = vb_l1_read_start_w ||
                          (vb_l1_read_wait_w && !wb_line_array_valid_w);
assign vb_l1_read_w = vb_l1_read_wait_w;
assign refill_req_w = miss_valid_r && (miss_state_r == S_REFILL_REQ);
assign refill_req_fire_w = refill_req_w && rd_ready_w;
assign refill_early_direct_w = miss_launch_fire_w &&
                               miss_launch_cacheable_w &&
                               !miss_launch_vb_hit_w &&
                               !miss_launch_victim_valid_w;
assign refill_early_after_insert_w = miss_valid_r &&
                                     (miss_state_r == S_L1_INSERT) &&
                                     miss_victim_valid_r &&
                                     vb_insert_ready_w;
assign refill_early_req_w = refill_early_direct_w || refill_early_after_insert_w;
assign refill_early_fire_w = refill_early_req_w && rd_ready_w;
assign refill_wait_w = miss_valid_r && (miss_state_r == S_REFILL);
// L2 现在一拍把整行送到，所以「到达」就等于全部数据到齐，
// 原来那套按 beat 计数 + early restart（目标字先到就放行）已无对象。
// CWF 仍然保留在 L2/DDR 一侧：L2 miss 时它决定 DDR 先给哪个字，
// 从而决定 L2 多快能凑齐这一行。
assign refill_arrive_w = refill_wait_w && ret_valid_w;

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
            `CACHE_LAST_BANK_INDEX: select_line_word = line_data[255:224];
            default: select_line_word = line_data[255:224];
        endcase
    end
endfunction

// 到达那一拍从整行里选出目标字（给 CPU 的 load 结果），寄一拍。
assign refill_target_word_w = select_line_word(ret_line_w, miss_bank_r);

// posted store 的 merge：在「到达」这一拍做，结果寄进 refill_line_r。
// 关键是不要做成「先寄整行，再从寄存器里 8 选 1 + byte merge 进 BRAM 写口」——
// 那条组合链会压在 BRAM 写数据端口前面，是主频风险。
// 这里每个 bank 各自判断「我是不是目标 bank」，只是一个 3 位比较 + 32 位
// 2 选 1，深度浅且 8 个 bank 完全并行；写口侧则是寄存器直连。
assign refill_store_merge_w = {
    miss_wstrb_r[3] ? miss_wdata_r[31:24] : refill_target_word_w[31:24],
    miss_wstrb_r[2] ? miss_wdata_r[23:16] : refill_target_word_w[23:16],
    miss_wstrb_r[1] ? miss_wdata_r[15:8]  : refill_target_word_w[15:8],
    miss_wstrb_r[0] ? miss_wdata_r[7:0]   : refill_target_word_w[7:0]
};

// 每个 bank 独立判断「我是不是 store 的目标 bank」。
// 8 路并行，每路只是 3 位比较 + 32 位 2 选 1。
assign refill_line_merged_w = {
    (miss_wr_r && (miss_bank_r == `CACHE_LAST_BANK_INDEX)) ?
        refill_store_merge_w : ret_line_w[255:224],
    (miss_wr_r && (miss_bank_r == 3'd6)) ?
        refill_store_merge_w : ret_line_w[223:192],
    (miss_wr_r && (miss_bank_r == 3'd5)) ?
        refill_store_merge_w : ret_line_w[191:160],
    (miss_wr_r && (miss_bank_r == 3'd4)) ?
        refill_store_merge_w : ret_line_w[159:128],
    (miss_wr_r && (miss_bank_r == 3'd3)) ?
        refill_store_merge_w : ret_line_w[127:96],
    (miss_wr_r && (miss_bank_r == 3'd2)) ?
        refill_store_merge_w : ret_line_w[95:64],
    (miss_wr_r && (miss_bank_r == 3'd1)) ?
        refill_store_merge_w : ret_line_w[63:32],
    (miss_wr_r && (miss_bank_r == 3'd0)) ?
        refill_store_merge_w : ret_line_w[31:0]
};

// refill 写数组发生在 S_REFILL_WRITE，整行一拍写完（走 victim_fill 口）。
assign refill_write_line_w = miss_valid_r && (miss_state_r == S_REFILL_WRITE);
// 这一拍数组和 tag/dirty 全部更新完毕，miss 即算完成。
assign refill_done_w = refill_write_line_w;

assign uc_r_req_w = uc_valid_r && (uc_state_r == U_R_REQ);
assign uc_r_req_fire_w = uc_r_req_w && rd_ready_w;
assign uc_r_wait_w = uc_valid_r && (uc_state_r == U_R_WAIT);
// uncached 读也是一拍返回，ret_valid 即完成。
assign uc_r_done_w = uc_r_wait_w && ret_valid_w;
assign uc_w_req_w = uc_valid_r && (uc_state_r == U_W_REQ);
assign uc_w_req_fire_w = wr_uc_grant_w && wr_ready_w;
assign uc_w_wait_w = uc_valid_r && (uc_state_r == U_W_WAIT);
assign uc_w_done_w = uc_w_wait_w && wr_done_w;

assign wb_read_valid_w = vb_l1_read_req_w || maint_index_read_w || maint_line_read_w;
assign wb_read_way_w = vb_l1_read_start_w ? miss_launch_victim_way_w :
                       vb_l1_read_wait_w ? miss_victim_way_r :
                       (maint_index_read_w || maint_line_read_w) ? maint_way_r :
                       miss_victim_way_r;
assign wb_read_index_w = vb_l1_read_start_w ? miss_launch_index_w :
                         vb_l1_read_wait_w ? miss_index_r :
                         (maint_index_read_w || maint_line_read_w) ? maint_index_r :
                         miss_index_r;

assign rd_req_w = refill_early_req_w || refill_req_w || uc_r_req_w;
assign rd_addr_w = uc_r_req_w ? uc_pa_r :
                   refill_early_direct_w ? miss_launch_pa_w :
                   miss_pa_r;
assign rd_line_w = !uc_r_req_w && (refill_early_req_w || refill_req_w);
assign rd_size_w = uc_r_req_w ? uc_size_r : 2'b10;

assign wr_uc_grant_w = uc_w_req_w;
assign wr_vb_scan_grant_w = !wr_uc_grant_w && maint_vb_scan_wb_req_w;
assign wr_vb_evict_grant_w = !wr_uc_grant_w && !wr_vb_scan_grant_w &&
                             vb_evict_req_w;
assign wr_maint_grant_w = !wr_uc_grant_w && !wr_vb_scan_grant_w &&
                          !wr_vb_evict_grant_w && maint_wb_req_w;
assign wr_vb_evict_fire_w = wr_vb_evict_grant_w && wr_ready_w;

assign wr_req_w = wr_uc_grant_w || wr_vb_scan_grant_w ||
                  wr_vb_evict_grant_w || wr_maint_grant_w;
assign wr_addr_w = wr_uc_grant_w ? uc_pa_r :
                   wr_vb_scan_grant_w ? {vb_scan_evict_block_addr_w,
                                          {`CACHE_OFFSET_WIDTH{1'b0}}} :
                   wr_vb_evict_grant_w ? {vb_evict_block_addr_w,
                                           {`CACHE_OFFSET_WIDTH{1'b0}}} :
                   wr_maint_grant_w ? {maint_line_tag_r, maint_index_r,
                                        {`CACHE_OFFSET_WIDTH{1'b0}}} :
                   32'b0;
assign wr_line_w = wr_vb_scan_grant_w || wr_vb_evict_grant_w || wr_maint_grant_w;
assign wr_source_w = wr_uc_grant_w ? `L2_SRC_UNCACHED :
                     (wr_vb_scan_grant_w || wr_vb_evict_grant_w) ? `L2_SRC_VB :
                     wr_maint_grant_w ? `L2_SRC_MAINT :
                     `L2_SRC_DCACHE;
assign wr_size_w = wr_uc_grant_w ? uc_size_r : 2'b10;
assign wr_wstrb_w = wr_uc_grant_w ? uc_wstrb_r : {`CACHE_WSTRB_WIDTH{1'b1}};
assign wr_data_w = wr_uc_grant_w ? uc_wdata_r : {`CACHE_WORD_WIDTH{1'b0}};

assign maint_addr_ok = maint_accept_w;
assign maint_data_ok = maint_busy_r && (maint_state_r == M_RESP);
assign maint_l2_valid = maint_l2_req_w;
assign maint_l2_op = maint_op_r;
assign maint_l2_addr =
    (maint_op_r == `CACHE_CACOP_MAINT_INDEX_INV) ?
    {maint_tag_r, maint_index_r,
     {(`CACHE_OFFSET_WIDTH-`L2_WAY_WIDTH){1'b0}},
     maint_l2_way_r} :
    {maint_tag_r, maint_index_r, {`CACHE_OFFSET_WIDTH{1'b0}}};

dcache_array u_array (
    .clk(clk),
    .resetn(resetn),
    .lookup_valid(lookup_valid_w),
    .lookup_index(lookup_index_w),
    .lookup_bank(lookup_bank_w),
    .maint_write_valid(1'b0),
    .maint_write_way(maint_way_r),
    .maint_write_index(maint_index_r),
    .maint_write_bank({`CACHE_BANK_WIDTH{1'b0}}),
    .maint_write_all_bank(1'b1),
    .maint_clear_valid(maint_clear_fire_w),
    .maint_clear_way(maint_way_r),
    .maint_clear_index(maint_index_r),
    // 全行写口：VB 回填和 L2 refill 共用（两者状态互斥）。
    .victim_fill_valid(line_fill_valid_w),
    .victim_fill_way(line_fill_way_w),
    .victim_fill_index(line_fill_index_w),
    .victim_fill_tag(line_fill_tag_w),
    .victim_fill_data0(line_fill_line_w[31:0]),
    .victim_fill_data1(line_fill_line_w[63:32]),
    .victim_fill_data2(line_fill_line_w[95:64]),
    .victim_fill_data3(line_fill_line_w[127:96]),
    .victim_fill_data4(line_fill_line_w[159:128]),
    .victim_fill_data5(line_fill_line_w[191:160]),
    .victim_fill_data6(line_fill_line_w[223:192]),
    .victim_fill_data7(line_fill_line_w[255:224]),
    .victim_fill_dirty(line_fill_dirty_w),
    .array_write_busy(array_write_busy_w),
    .store_ready(store_ready_w),
    .store_valid(array_store_valid_w),
    .store_way(array_store_way_w),
    .store_index(array_store_index_w),
    .store_bank(array_store_bank_w),
    .store_wstrb(array_store_wstrb_w),
    .store_wdata(array_store_wdata_w),
    .wb_read_valid(wb_read_valid_w),
    .wb_read_way(wb_read_way_w),
    .wb_read_index(wb_read_index_w),
    .lookup_write_conflict(lookup_write_conflict_w),
    .wb_write_conflict(wb_write_conflict_w),
    .lookup_wb_conflict(lookup_wb_conflict_w),
    .mem2_array_valid(array_valid_w),
    .way0_valid(way0_valid_w),
    .way0_dirty(way0_dirty_w),
    .way0_tag(way0_tag_w),
    .way0_rdata(way0_rdata_w),
    .way1_valid(way1_valid_w),
    .way1_dirty(way1_dirty_w),
    .way1_tag(way1_tag_w),
    .way1_rdata(way1_rdata_w),
    .wb_line_array_valid(wb_line_array_valid_w),
    .wb_line_valid(wb_line_valid_w),
    .wb_line_dirty(wb_line_dirty_w),
    .wb_line_tag(wb_line_tag_w),
    .wb_line_data0(wb_line_data0_w),
    .wb_line_data1(wb_line_data1_w),
    .wb_line_data2(wb_line_data2_w),
    .wb_line_data3(wb_line_data3_w),
    .wb_line_data4(wb_line_data4_w),
    .wb_line_data5(wb_line_data5_w),
    .wb_line_data6(wb_line_data6_w),
    .wb_line_data7(wb_line_data7_w)
);

cache_hit_compare u_compare (
    .req_valid(mem2_array_valid),
    .req_tag(mem2_tag_w),
    .way0_valid(way0_valid_w),
    .way0_dirty(way0_dirty_w),
    .way0_tag(way0_tag_w),
    .way0_rdata(way0_rdata_w),
    .way1_valid(way1_valid_w),
    .way1_dirty(way1_dirty_w),
    .way1_tag(way1_tag_w),
    .way1_rdata(way1_rdata_w),
    .hit(compare_hit_w),
    .hit_way(compare_hit_way_w),
    .hit_dirty(compare_hit_dirty_w),
    .hit_rdata(compare_rdata_w)
);

cache_hit_compare u_replay_compare (
    .req_valid(replay_resp_valid_w),
    .req_tag(replay_tag_r),
    .way0_valid(way0_valid_w),
    .way0_dirty(way0_dirty_w),
    .way0_tag(way0_tag_w),
    .way0_rdata(way0_rdata_w),
    .way1_valid(way1_valid_w),
    .way1_dirty(way1_dirty_w),
    .way1_tag(way1_tag_w),
    .way1_rdata(way1_rdata_w),
    .hit(replay_compare_hit_w),
    .hit_way(replay_compare_hit_way_w),
    .hit_dirty(replay_compare_hit_dirty_w),
    .hit_rdata(replay_compare_rdata_w)
);

l1_replace u_replace (
    .clk(clk),
    .resetn(resetn),
    .way0_valid(way0_valid_w),
    .way1_valid(way1_valid_w),
    .victim_index(replace_victim_index_w),
    .lookup_index(lookup_index_w),
    .access_valid(replace_access_valid_w),
    .access_index(replace_access_index_w),
    .access_way(replace_access_way_w),
    .replace_way(replace_way_raw_unused_w),
    .lru_victim_way(lru_victim_way_w),
    .lookup_lru_victim_way()
);

dcache_victim_buffer u_victim_buffer (
    .clk(clk),
    .resetn(resetn),
    .lookup_valid(vb_lookup_valid_w),
    .lookup_block_addr(vb_lookup_block_addr_w),
    .lookup_hit(vb_lookup_hit_w),
    .lookup_hit_index(vb_lookup_hit_index_w),
    .lookup_hit_dirty(vb_lookup_hit_dirty_w),
    .lookup_data0(vb_lookup_data0_w),
    .lookup_data1(vb_lookup_data1_w),
    .lookup_data2(vb_lookup_data2_w),
    .lookup_data3(vb_lookup_data3_w),
    .lookup_data4(vb_lookup_data4_w),
    .lookup_data5(vb_lookup_data5_w),
    .lookup_data6(vb_lookup_data6_w),
    .lookup_data7(vb_lookup_data7_w),
    .insert_valid(vb_insert_valid_w),
    .insert_dirty(vb_insert_dirty_w),
    .insert_block_addr(vb_insert_block_addr_w),
    .insert_data0(vb_insert_data0_w),
    .insert_data1(vb_insert_data1_w),
    .insert_data2(vb_insert_data2_w),
    .insert_data3(vb_insert_data3_w),
    .insert_data4(vb_insert_data4_w),
    .insert_data5(vb_insert_data5_w),
    .insert_data6(vb_insert_data6_w),
    .insert_data7(vb_insert_data7_w),
    .insert_ready(vb_insert_ready_w),
    .evict_valid(vb_evict_valid_w),
    .evict_dirty(vb_evict_dirty_w),
    .evict_index(vb_evict_index_w),
    .evict_block_addr(vb_evict_block_addr_w),
    .evict_data0(vb_evict_data0_w),
    .evict_data1(vb_evict_data1_w),
    .evict_data2(vb_evict_data2_w),
    .evict_data3(vb_evict_data3_w),
    .evict_data4(vb_evict_data4_w),
    .evict_data5(vb_evict_data5_w),
    .evict_data6(vb_evict_data6_w),
    .evict_data7(vb_evict_data7_w),
    .evict_accept(vb_evict_accept_w),
    .swap_valid(vb_swap_valid_w),
    .swap_index(vb_swap_index_w),
    .swap_insert_valid(vb_swap_insert_valid_w),
    .swap_insert_dirty(vb_swap_insert_dirty_w),
    .swap_insert_block_addr(vb_swap_insert_block_addr_w),
    .swap_insert_data0(vb_swap_insert_data0_w),
    .swap_insert_data1(vb_swap_insert_data1_w),
    .swap_insert_data2(vb_swap_insert_data2_w),
    .swap_insert_data3(vb_swap_insert_data3_w),
    .swap_insert_data4(vb_swap_insert_data4_w),
    .swap_insert_data5(vb_swap_insert_data5_w),
    .swap_insert_data6(vb_swap_insert_data6_w),
    .swap_insert_data7(vb_swap_insert_data7_w),
    .scan_req(vb_scan_req_w),
    .scan_match_index(maint_op_r == `CACHE_CACOP_MAINT_INDEX_INV),
    .scan_index(maint_index_r),
    .scan_block_addr({maint_tag_r, maint_index_r}),
    .scan_busy(vb_scan_busy_w),
    .scan_evict_valid(vb_scan_evict_valid_w),
    .scan_evict_dirty(vb_scan_evict_dirty_w),
    .scan_evict_block_addr(vb_scan_evict_block_addr_w),
    .scan_evict_data0(vb_scan_evict_data0_w),
    .scan_evict_data1(vb_scan_evict_data1_w),
    .scan_evict_data2(vb_scan_evict_data2_w),
    .scan_evict_data3(vb_scan_evict_data3_w),
    .scan_evict_data4(vb_scan_evict_data4_w),
    .scan_evict_data5(vb_scan_evict_data5_w),
    .scan_evict_data6(vb_scan_evict_data6_w),
    .scan_evict_data7(vb_scan_evict_data7_w),
    .scan_evict_accept(vb_scan_evict_accept_w),
    .scan_done(vb_scan_done_w)
);

dcache_prefetcher #(
    .ENABLE(`DCACHE_PREFETCH_ENABLE)
) u_dcache_prefetcher (
    .clk(clk),
    .resetn(resetn),
    .train_valid(prefetch_train_valid_w),
    .train_pc(mem2_pc),
    .train_addr(mem2_pa),
    .demand_miss_valid(prefetch_demand_miss_valid_w),
    .demand_miss_addr(mem2_pa),
    .prefetch_valid(prefetch_valid),
    .prefetch_addr(prefetch_addr),
    .prefetch_ready(prefetch_ready),
    .prefetch_complete(prefetch_complete)
);

dcache_l2_read u_l2_read (
    .clk(clk),
    .resetn(resetn),
    .rd_req(rd_req_w),
    .rd_addr(rd_addr_w),
    .rd_line(rd_line_w),
    .rd_size(rd_size_w),
    .rd_ready(rd_ready_w),
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arvalid(arvalid),
    .arready(arready),
    .rline(rline),
    .rvalid(rvalid),
    .rready(rready),
    .ret_valid(ret_valid_w),
    .ret_line(ret_line_w)
);

dcache_l2_write u_l2_write (
    .clk(clk),
    .resetn(resetn),
    .wr_req(wr_req_w),
    .wr_addr(wr_addr_w),
    .wr_line(wr_line_w),
    .wr_source(wr_source_w),
    .wr_size(wr_size_w),
    .wr_wstrb(wr_wstrb_w),
    .wr_data(wr_data_w),
    .wr_line_data0(wr_vb_scan_grant_w ? vb_scan_evict_data0_w :
                   wr_vb_evict_grant_w ? vb_evict_data0_w :
                   wr_maint_grant_w ? maint_line_data0_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data1(wr_vb_scan_grant_w ? vb_scan_evict_data1_w :
                   wr_vb_evict_grant_w ? vb_evict_data1_w :
                   wr_maint_grant_w ? maint_line_data1_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data2(wr_vb_scan_grant_w ? vb_scan_evict_data2_w :
                   wr_vb_evict_grant_w ? vb_evict_data2_w :
                   wr_maint_grant_w ? maint_line_data2_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data3(wr_vb_scan_grant_w ? vb_scan_evict_data3_w :
                   wr_vb_evict_grant_w ? vb_evict_data3_w :
                   wr_maint_grant_w ? maint_line_data3_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data4(wr_vb_scan_grant_w ? vb_scan_evict_data4_w :
                   wr_vb_evict_grant_w ? vb_evict_data4_w :
                   wr_maint_grant_w ? maint_line_data4_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data5(wr_vb_scan_grant_w ? vb_scan_evict_data5_w :
                   wr_vb_evict_grant_w ? vb_evict_data5_w :
                   wr_maint_grant_w ? maint_line_data5_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data6(wr_vb_scan_grant_w ? vb_scan_evict_data6_w :
                   wr_vb_evict_grant_w ? vb_evict_data6_w :
                   wr_maint_grant_w ? maint_line_data6_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_line_data7(wr_vb_scan_grant_w ? vb_scan_evict_data7_w :
                   wr_vb_evict_grant_w ? vb_evict_data7_w :
                   wr_maint_grant_w ? maint_line_data7_r :
                   {`CACHE_WORD_WIDTH{1'b0}}),
    .wr_ready(wr_ready_w),
    .wr_done(wr_done_w),
    .awid(awid),
    .awsource(awsource),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awvalid(awvalid),
    .awready(awready),
    .wid(wid),
    .wline(wline),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .bid(bid),
    .bvalid(bvalid),
    .bready(bready)
);

always @(posedge clk) begin
    if(!resetn) begin
        miss_valid_r <= 1'b0;
        miss_state_r <= S_IDLE;
        miss_wr_r <= 1'b0;
        miss_size_r <= 2'b0;
        miss_wstrb_r <= {`CACHE_WSTRB_WIDTH{1'b0}};
        miss_wdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_pa_r <= 32'b0;
        miss_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        miss_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
        miss_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        miss_victim_way_r <= 1'b0;
        miss_victim_valid_r <= 1'b0;
        miss_victim_dirty_r <= 1'b0;
        miss_victim_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        miss_need_cpu_response_r <= 1'b0;
        miss_posted_store_r <= 1'b0;
        miss_post_accept_sent_r <= 1'b0;
        refill_load_data_r <= {`CACHE_WORD_WIDTH{1'b0}};
        refill_line_r <= {`CACHE_LINE_WIDTH{1'b0}};
        wb_line_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        wb_line_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
        wb_line_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_path_r <= 1'b0;
        vb_hit_index_r <= 2'b0;
        vb_hit_dirty_r <= 1'b0;
        vb_hit_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
        vb_hit_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_valid_r <= 1'b0;
        miss_hold_cacheable_r <= 1'b0;
        miss_hold_wr_r <= 1'b0;
        miss_hold_postable_store_r <= 1'b0;
        miss_hold_size_r <= 2'b0;
        miss_hold_wstrb_r <= {`CACHE_WSTRB_WIDTH{1'b0}};
        miss_hold_wdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_pa_r <= 32'b0;
        miss_hold_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        miss_hold_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
        miss_hold_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        miss_hold_victim_way_r <= 1'b0;
        miss_hold_victim_valid_r <= 1'b0;
        miss_hold_victim_dirty_r <= 1'b0;
        miss_hold_victim_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        miss_hold_vb_hit_r <= 1'b0;
        miss_hold_vb_hit_index_r <= 2'b0;
        miss_hold_vb_hit_dirty_r <= 1'b0;
        miss_hold_vb_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_hold_vb_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};

        normal_lookup_meta_valid_r <= 1'b0;
        normal_lookup_meta_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        normal_lookup_meta_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
        normal_lookup_meta_lru_victim_way_r <= 1'b0;

        replay_state_r <= R_IDLE;
        replay_wr_r <= 1'b0;
        replay_postable_store_r <= 1'b0;
        replay_size_r <= 2'b0;
        replay_wstrb_r <= {`CACHE_WSTRB_WIDTH{1'b0}};
        replay_wdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        replay_pa_r <= 32'b0;
        replay_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        replay_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
        replay_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        replay_hit_way_r <= 1'b0;
        replay_rdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        replay_lookup_meta_valid_r <= 1'b0;
        replay_lookup_meta_lru_victim_way_r <= 1'b0;
        miss_launch_valid_r <= 1'b0;
        miss_launch_cacheable_r <= 1'b0;
        miss_launch_wr_r <= 1'b0;
        miss_launch_postable_store_r <= 1'b0;
        miss_launch_size_r <= 2'b0;
        miss_launch_wstrb_r <= {`CACHE_WSTRB_WIDTH{1'b0}};
        miss_launch_wdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_pa_r <= 32'b0;
        miss_launch_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        miss_launch_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
        miss_launch_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        miss_launch_victim_way_r <= 1'b0;
        miss_launch_victim_valid_r <= 1'b0;
        miss_launch_victim_dirty_r <= 1'b0;
        miss_launch_victim_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        miss_launch_vb_hit_r <= 1'b0;
        miss_launch_vb_hit_index_r <= 2'b0;
        miss_launch_vb_hit_dirty_r <= 1'b0;
        miss_launch_vb_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
        miss_launch_vb_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};

        uc_valid_r <= 1'b0;
        uc_state_r <= U_IDLE;
        uc_wr_r <= 1'b0;
        uc_size_r <= 2'b0;
        uc_wstrb_r <= {`CACHE_WSTRB_WIDTH{1'b0}};
        uc_pa_r <= 32'b0;
        uc_wdata_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_busy_r <= 1'b0;
        maint_state_r <= M_IDLE;
        maint_op_r <= 2'b0;
        maint_way_r <= 1'b0;
        maint_l2_way_r <= {`L2_WAY_WIDTH{1'b0}};
        maint_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        maint_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        maint_line_valid_r <= 1'b0;
        maint_line_dirty_r <= 1'b0;
        maint_line_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
        maint_line_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
        maint_line_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};
    end else begin
        normal_lookup_meta_valid_r <= normal_lookup_accept_w;
        if(normal_lookup_accept_w) begin
            normal_lookup_meta_index_r <= mem1_index_w;
            normal_lookup_meta_bank_r <= mem1_bank_w;
            normal_lookup_meta_lru_victim_way_r <= lookup_lru_victim_way_w;
        end

        replay_lookup_meta_valid_r <= replay_lookup_accept_w;
        if(replay_lookup_accept_w) begin
            replay_lookup_meta_lru_victim_way_r <= lookup_lru_victim_way_w;
        end
        if(replay_start_w) begin
            replay_state_r <= R_LOOKUP;
            replay_wr_r <= mem2_wr;
            replay_postable_store_r <= mem2_postable_store;
            replay_size_r <= mem2_size;
            replay_wstrb_r <= mem2_wstrb;
            replay_wdata_r <= mem2_wdata;
            replay_pa_r <= mem2_pa;
            replay_index_r <= mem2_index_w;
            replay_bank_r <= mem2_bank_w;
            replay_tag_r <= mem2_tag_w;
        end else begin
            case(replay_state_r)
                R_IDLE: begin
                    replay_state_r <= R_IDLE;
                end

                R_LOOKUP: begin
                    if(replay_lookup_accept_w) begin
                        replay_state_r <= R_WAIT;
                    end
                end

                R_WAIT: begin
                    if(replay_resp_valid_w && replay_compare_hit_w) begin
                        replay_hit_way_r <= replay_compare_hit_way_w;
                        replay_rdata_r <= replay_compare_rdata_w;
                        replay_state_r <= R_HIT_READY;
                    end else if(replay_wait_miss_w) begin
                        replay_state_r <= R_MISS_READY;
                    end
                end

                R_HIT_READY: begin
                    if(replay_hit_fire_w) begin
                        replay_state_r <= R_HIT_RESP;
                    end
                end

                R_MISS_READY: begin
                    if(miss_issue_fire_w) begin
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


        if(maint_accept_w || miss_issue_fire_w || replay_hit_fire_w) begin
            miss_hold_valid_r <= 1'b0;
        end else if(replay_wait_miss_w) begin
            miss_hold_valid_r <= 1'b1;
            miss_hold_cacheable_r <= 1'b1;
            miss_hold_wr_r <= replay_wr_r;
            miss_hold_postable_store_r <= replay_postable_store_r;
            miss_hold_size_r <= replay_size_r;
            miss_hold_wstrb_r <= replay_wstrb_r;
            miss_hold_wdata_r <= replay_wdata_r;
            miss_hold_pa_r <= replay_pa_r;
            miss_hold_index_r <= replay_index_r;
            miss_hold_bank_r <= replay_bank_r;
            miss_hold_tag_r <= replay_tag_r;
            miss_hold_victim_way_r <= replace_way_w;
            miss_hold_victim_valid_r <= victim_valid_w;
            miss_hold_victim_dirty_r <= victim_dirty_w;
            miss_hold_victim_tag_r <= victim_tag_w;
            miss_hold_vb_hit_r <= vb_lookup_hit_w;
            miss_hold_vb_hit_index_r <= vb_lookup_hit_index_w;
            miss_hold_vb_hit_dirty_r <= vb_lookup_hit_dirty_w;
            miss_hold_vb_data0_r <= vb_lookup_data0_w;
            miss_hold_vb_data1_r <= vb_lookup_data1_w;
            miss_hold_vb_data2_r <= vb_lookup_data2_w;
            miss_hold_vb_data3_r <= vb_lookup_data3_w;
            miss_hold_vb_data4_r <= vb_lookup_data4_w;
            miss_hold_vb_data5_r <= vb_lookup_data5_w;
            miss_hold_vb_data6_r <= vb_lookup_data6_w;
            miss_hold_vb_data7_r <= vb_lookup_data7_w;
        end else if(mem2_current_miss_w && !miss_launch_valid_r) begin
            miss_hold_valid_r <= 1'b1;
            miss_hold_cacheable_r <= mem2_cacheable_w;
            miss_hold_wr_r <= mem2_wr;
            miss_hold_postable_store_r <= mem2_postable_store;
            miss_hold_size_r <= mem2_size;
            miss_hold_wstrb_r <= mem2_wstrb;
            miss_hold_wdata_r <= mem2_wdata;
            miss_hold_pa_r <= mem2_pa;
            miss_hold_index_r <= mem2_index_w;
            miss_hold_bank_r <= mem2_bank_w;
            miss_hold_tag_r <= mem2_tag_w;
            miss_hold_victim_way_r <= replace_way_w;
            miss_hold_victim_valid_r <= victim_valid_w;
            miss_hold_victim_dirty_r <= victim_dirty_w;
            miss_hold_victim_tag_r <= victim_tag_w;
            if(mem2_cacheable_w) begin
                miss_hold_vb_hit_r <= vb_lookup_hit_w;
                miss_hold_vb_hit_index_r <= vb_lookup_hit_index_w;
                miss_hold_vb_hit_dirty_r <= vb_lookup_hit_dirty_w;
                miss_hold_vb_data0_r <= vb_lookup_data0_w;
                miss_hold_vb_data1_r <= vb_lookup_data1_w;
                miss_hold_vb_data2_r <= vb_lookup_data2_w;
                miss_hold_vb_data3_r <= vb_lookup_data3_w;
                miss_hold_vb_data4_r <= vb_lookup_data4_w;
                miss_hold_vb_data5_r <= vb_lookup_data5_w;
                miss_hold_vb_data6_r <= vb_lookup_data6_w;
                miss_hold_vb_data7_r <= vb_lookup_data7_w;
            end else begin
                miss_hold_vb_hit_r <= 1'b0;
                miss_hold_vb_hit_index_r <= 2'b0;
                miss_hold_vb_hit_dirty_r <= 1'b0;
                miss_hold_vb_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
                miss_hold_vb_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};
            end
        end else if(miss_hold_valid_r && mem2_valid && !miss_hold_match_mem2_w &&
                    !miss_launch_valid_r &&
                    (replay_state_r == R_IDLE)) begin
            miss_hold_valid_r <= 1'b0;
        end

        if(miss_issue_fire_w) begin
            miss_launch_valid_r <= 1'b1;
            miss_launch_cacheable_r <= miss_source_cacheable_w;
            miss_launch_wr_r <= miss_source_wr_w;
            miss_launch_postable_store_r <= miss_source_postable_store_w;
            miss_launch_size_r <= miss_source_size_w;
            miss_launch_wstrb_r <= miss_source_wstrb_w;
            miss_launch_wdata_r <= miss_source_wdata_w;
            miss_launch_pa_r <= miss_source_pa_w;
            miss_launch_index_r <= miss_source_index_w;
            miss_launch_bank_r <= miss_source_bank_w;
            miss_launch_tag_r <= miss_source_tag_w;
            miss_launch_victim_way_r <= miss_source_victim_way_w;
            miss_launch_victim_valid_r <= miss_source_victim_valid_w;
            miss_launch_victim_dirty_r <= miss_source_victim_dirty_w;
            miss_launch_victim_tag_r <= miss_source_victim_tag_w;
            miss_launch_vb_hit_r <= miss_source_vb_hit_w;
            miss_launch_vb_hit_index_r <= miss_source_vb_hit_index_w;
            miss_launch_vb_hit_dirty_r <= miss_source_vb_hit_dirty_w;
            miss_launch_vb_data0_r <= miss_source_vb_data0_w;
            miss_launch_vb_data1_r <= miss_source_vb_data1_w;
            miss_launch_vb_data2_r <= miss_source_vb_data2_w;
            miss_launch_vb_data3_r <= miss_source_vb_data3_w;
            miss_launch_vb_data4_r <= miss_source_vb_data4_w;
            miss_launch_vb_data5_r <= miss_source_vb_data5_w;
            miss_launch_vb_data6_r <= miss_source_vb_data6_w;
            miss_launch_vb_data7_r <= miss_source_vb_data7_w;
        end else if(miss_launch_fire_w && miss_launch_cacheable_w) begin
            miss_launch_valid_r <= 1'b0;
            miss_valid_r <= 1'b1;
            miss_wr_r <= miss_launch_cached_wr_w;
            miss_size_r <= miss_launch_size_w;
            miss_wstrb_r <= miss_launch_wstrb_w;
            miss_wdata_r <= miss_launch_wdata_w;
            miss_pa_r <= miss_launch_pa_w;
            miss_index_r <= miss_launch_index_w;
            miss_bank_r <= miss_launch_bank_w;
            miss_tag_r <= miss_launch_tag_w;
            miss_victim_way_r <= miss_launch_victim_way_w;
            miss_victim_valid_r <= miss_launch_victim_valid_w;
            miss_victim_dirty_r <= miss_launch_victim_dirty_w;
            miss_victim_tag_r <= miss_launch_victim_tag_w;
            miss_need_cpu_response_r <= !posted_store_accept_fire_w;
            miss_posted_store_r <= posted_store_accept_fire_w;
            miss_post_accept_sent_r <= posted_store_accept_fire_w;
            vb_hit_path_r <= miss_launch_vb_hit_w;
            vb_hit_index_r <= miss_launch_vb_hit_index_w;
            vb_hit_dirty_r <= miss_launch_vb_hit_dirty_w;
            vb_hit_data0_r <= miss_launch_vb_data0_w;
            vb_hit_data1_r <= miss_launch_vb_data1_w;
            vb_hit_data2_r <= miss_launch_vb_data2_w;
            vb_hit_data3_r <= miss_launch_vb_data3_w;
            vb_hit_data4_r <= miss_launch_vb_data4_w;
            vb_hit_data5_r <= miss_launch_vb_data5_w;
            vb_hit_data6_r <= miss_launch_vb_data6_w;
            vb_hit_data7_r <= miss_launch_vb_data7_w;
            if(miss_launch_vb_hit_w) begin
                miss_state_r <= miss_launch_victim_valid_w ? S_VB_READ_L1 : S_VB_FILL_L1;
            end else if(miss_launch_victim_valid_w) begin
                miss_state_r <= S_VB_READ_L1;
            end else begin
                miss_state_r <= refill_early_fire_w ? S_REFILL : S_REFILL_REQ;
            end
        end else if(miss_launch_fire_w) begin
            miss_launch_valid_r <= 1'b0;
            uc_valid_r <= 1'b1;
            uc_wr_r <= miss_launch_wr_w;
            uc_size_r <= miss_launch_size_w;
            uc_wstrb_r <= miss_launch_wstrb_w;
            uc_pa_r <= miss_launch_pa_w;
            uc_wdata_r <= miss_launch_wdata_w;
            uc_state_r <= miss_launch_wr_w ? U_W_REQ : U_R_REQ;
        end

        if(vb_l1_read_w && wb_line_array_valid_w) begin
            wb_line_tag_r <= wb_line_tag_w;
            wb_line_data0_r <= wb_line_data0_w;
            wb_line_data1_r <= wb_line_data1_w;
            wb_line_data2_r <= wb_line_data2_w;
            wb_line_data3_r <= wb_line_data3_w;
            wb_line_data4_r <= wb_line_data4_w;
            wb_line_data5_r <= wb_line_data5_w;
            wb_line_data6_r <= wb_line_data6_w;
            wb_line_data7_r <= wb_line_data7_w;
            miss_state_r <= vb_hit_path_r ? S_VB_FILL_L1 : S_L1_INSERT;
        end else if(vb_line_fill_w) begin
            miss_state_r <= S_VB_RESP;
        end else if(vb_resp_valid_w) begin
            miss_valid_r <= 1'b0;
            miss_state_r <= S_IDLE;
            miss_need_cpu_response_r <= 1'b0;
            miss_posted_store_r <= 1'b0;
            miss_post_accept_sent_r <= 1'b0;
            vb_hit_path_r <= 1'b0;
        end else if(miss_valid_r && (miss_state_r == S_L1_INSERT) &&
                    !miss_victim_valid_r) begin
            miss_state_r <= S_REFILL_REQ;
        end else if(miss_valid_r && (miss_state_r == S_L1_INSERT) &&
                    vb_insert_ready_w) begin
            miss_state_r <= refill_early_fire_w ? S_REFILL : S_REFILL_REQ;
        end else if(miss_valid_r && (miss_state_r == S_L1_INSERT)) begin
            miss_state_r <= S_VB_EVICT_REQ;
        end else if(wr_vb_evict_fire_w) begin
            miss_state_r <= S_VB_EVICT_WAIT;
        end else if(vb_evict_wait_w && wr_done_w) begin
            miss_state_r <= S_L1_INSERT;
        end else if(refill_req_fire_w) begin
            miss_state_r <= S_REFILL;
        end else if(refill_arrive_w) begin
            // 整行到齐，去写数组。
            miss_state_r <= S_REFILL_WRITE;
        end else if(refill_done_w) begin
            miss_valid_r <= 1'b0;
            miss_state_r <= S_IDLE;
            miss_need_cpu_response_r <= 1'b0;
            miss_posted_store_r <= 1'b0;
            miss_post_accept_sent_r <= 1'b0;
        end

        if(refill_arrive_w) begin
            // 目标字（load 结果）和整行（含 store merge）同拍寄下来。
            refill_load_data_r <= refill_target_word_w;
            refill_line_r <= refill_line_merged_w;
        end

        if(uc_r_req_fire_w) begin
            uc_state_r <= U_R_WAIT;
        end else if(uc_r_done_w) begin
            uc_valid_r <= 1'b0;
            uc_state_r <= U_IDLE;
        end else if(uc_w_req_fire_w) begin
            uc_state_r <= U_W_WAIT;
        end else if(uc_w_done_w) begin
            uc_valid_r <= 1'b0;
            uc_state_r <= U_IDLE;
        end

        if(maint_accept_w) begin
            maint_busy_r <= 1'b1;
            // D-cache maintenance order: L1 D-cache, then victim buffer, then L2.
            maint_state_r <= maint_accept_start_state_w;
            maint_op_r <= maint_op;
            maint_way_r <= maint_way;
            maint_l2_way_r <= {`L2_WAY_WIDTH{1'b0}};
            maint_index_r <= maint_index;
            maint_tag_r <= maint_tag;
            maint_line_valid_r <= 1'b0;
            maint_line_dirty_r <= 1'b0;
            maint_line_tag_r <= {`CACHE_TAG_WIDTH{1'b0}};
            maint_line_data0_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data1_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data2_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data3_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data4_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data5_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data6_r <= {`CACHE_WORD_WIDTH{1'b0}};
            maint_line_data7_r <= {`CACHE_WORD_WIDTH{1'b0}};
        end else if(maint_busy_r && (maint_state_r == M_VB_SCAN_REQ) &&
                    vb_scan_evict_valid_w && vb_scan_evict_dirty_w) begin
            maint_state_r <= M_VB_SCAN_WB_REQ;
        end else if(maint_busy_r && (maint_state_r == M_VB_SCAN_REQ) &&
                    vb_scan_done_w) begin
            maint_state_r <= M_L2_REQ;
        end else if(maint_vb_scan_wb_req_fire_w) begin
            maint_state_r <= M_VB_SCAN_WB_WAIT;
        end else if(maint_vb_scan_wb_wait_w && wr_done_w) begin
            maint_state_r <= M_VB_SCAN_REQ;
        end else if(maint_index_read_w && wb_line_array_valid_w) begin
            maint_state_r <= M_INDEX_CHECK;
            maint_line_valid_r <= wb_line_valid_w;
            maint_line_dirty_r <= wb_line_dirty_w;
            maint_line_tag_r <= wb_line_tag_w;
            maint_line_data0_r <= wb_line_data0_w;
            maint_line_data1_r <= wb_line_data1_w;
            maint_line_data2_r <= wb_line_data2_w;
            maint_line_data3_r <= wb_line_data3_w;
            maint_line_data4_r <= wb_line_data4_w;
            maint_line_data5_r <= wb_line_data5_w;
            maint_line_data6_r <= wb_line_data6_w;
            maint_line_data7_r <= wb_line_data7_w;
        end else if(maint_index_check_w && maint_index_op_w && maint_clean_or_invalid_w) begin
            maint_state_r <= M_CLEAR;
        end else if(maint_index_check_w && maint_index_op_w) begin
            maint_state_r <= M_WB_REQ;
        end else if(maint_hit_lookup_w) begin
            maint_state_r <= M_HIT_CHECK;
        end else if(maint_hit_check_w && array_valid_w && !maint_hit_w) begin
            maint_state_r <= M_VB_SCAN_REQ;
        end else if(maint_hit_check_w && maint_hit_w && !maint_hit_dirty_w) begin
            maint_state_r <= M_CLEAR;
            maint_way_r <= maint_hit_way_w;
            maint_line_valid_r <= 1'b1;
            maint_line_dirty_r <= 1'b0;
            maint_line_tag_r <= maint_hit_way_w ? way1_tag_w : way0_tag_w;
        end else if(maint_hit_check_w && maint_hit_w) begin
            maint_state_r <= M_LINE_READ;
            maint_way_r <= maint_hit_way_w;
            maint_line_valid_r <= 1'b1;
            maint_line_dirty_r <= 1'b1;
            maint_line_tag_r <= maint_hit_way_w ? way1_tag_w : way0_tag_w;
        end else if(maint_line_read_w && wb_line_array_valid_w) begin
            maint_state_r <= M_WB_REQ;
            maint_line_valid_r <= wb_line_valid_w;
            maint_line_dirty_r <= wb_line_dirty_w;
            maint_line_tag_r <= wb_line_tag_w;
            maint_line_data0_r <= wb_line_data0_w;
            maint_line_data1_r <= wb_line_data1_w;
            maint_line_data2_r <= wb_line_data2_w;
            maint_line_data3_r <= wb_line_data3_w;
            maint_line_data4_r <= wb_line_data4_w;
            maint_line_data5_r <= wb_line_data5_w;
            maint_line_data6_r <= wb_line_data6_w;
            maint_line_data7_r <= wb_line_data7_w;
        end else if(maint_wb_req_fire_w) begin
            maint_state_r <= M_WB_WAIT;
        end else if(maint_wb_wait_w && wr_done_w) begin
            maint_state_r <= M_CLEAR;
        end else if(maint_clear_fire_w) begin
            maint_state_r <= maint_need_l2_w ? M_VB_SCAN_REQ : M_RESP;
        end else if(maint_l2_req_fire_w) begin
            maint_state_r <= M_L2_WAIT;
        end else if(maint_busy_r && (maint_state_r == M_L2_WAIT) &&
                    maint_l2_done) begin
            if((maint_op_r == `CACHE_CACOP_MAINT_INDEX_INV) &&
               (maint_l2_way_r != (`L2_WAYS - 1))) begin
                maint_l2_way_r <= maint_l2_way_r + 1'b1;
                maint_state_r <= M_L2_REQ;
            end else begin
                maint_state_r <= M_RESP;
            end
        end else if(maint_busy_r && (maint_state_r == M_RESP)) begin
            maint_busy_r <= 1'b0;
            maint_state_r <= M_IDLE;
        end
    end
end

endmodule
