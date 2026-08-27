`include "cache_defs.vh"

module dcache_victim_buffer (
        input wire clk,
        input wire resetn,

        // Lookup
        input wire lookup_valid,
        input wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] lookup_block_addr,

        output wire lookup_hit,
        output wire [1:0] lookup_hit_index,
        output wire lookup_hit_dirty,

        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] lookup_data7,

        // Insert
        input wire insert_valid,
        input wire insert_dirty,
        input wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] insert_block_addr,

        input wire [`CACHE_WORD_WIDTH-1:0] insert_data0,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data1,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data2,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data3,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data4,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data5,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data6,
        input wire [`CACHE_WORD_WIDTH-1:0] insert_data7,

        output wire insert_ready,

        // Evict
        output wire evict_valid,
        output wire evict_dirty,
        output wire [1:0] evict_index,
        output wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] evict_block_addr,

        output wire [`CACHE_WORD_WIDTH-1:0] evict_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] evict_data7,

        input wire evict_accept,

        // Swap
        input wire swap_valid,
        input wire [1:0] swap_index,
        input wire swap_insert_valid,
        input wire swap_insert_dirty,
        input wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] swap_insert_block_addr,

        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data0,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data1,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data2,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data3,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data4,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data5,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data6,
        input wire [`CACHE_WORD_WIDTH-1:0] swap_insert_data7,

        // CACOP scan
        input wire scan_req,
        input wire scan_match_index,
        input wire [`CACHE_INDEX_WIDTH-1:0] scan_index,
        input wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] scan_block_addr,

        output wire scan_busy,

        output wire scan_evict_valid,
        output wire scan_evict_dirty,
        output wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] scan_evict_block_addr,

        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] scan_evict_data7,

        input wire scan_evict_accept,
        output wire scan_done
    );

    reg [3:0] valid_r;
    reg [3:0] dirty_r;

    reg [`CACHE_BLOCK_ADDR_WIDTH-1:0] block_addr_r [3:0];


    (* ram_style = "distributed" *)
    reg [`CACHE_LINE_WIDTH-1:0] line_data_r [3:0];

    // lru_xy_r = 1：Entry x 比 Entry y 更新。
    reg lru_01_r;
    reg lru_02_r;
    reg lru_03_r;
    reg lru_12_r;
    reg lru_13_r;
    reg lru_23_r;

    // 锁存正在写回的 Dirty Victim。
    reg evict_pending_r;
    reg [1:0] evict_pending_index_r;

    reg scan_busy_r;
    reg [1:0] scan_idx_r;
    reg scan_done_r;

    wire lookup_hit0_w;
    wire lookup_hit1_w;
    wire lookup_hit2_w;
    wire lookup_hit3_w;
    wire [`CACHE_LINE_WIDTH-1:0] lookup_line_data_w;

    wire all_valid_w;

    wire lru_way0_w;
    wire lru_way1_w;
    wire lru_way2_w;
    wire lru_way3_w;

    wire [1:0] lru_victim_w;
    wire [1:0] active_evict_index_w;
    wire evict_pending_start_w;

    wire [1:0] insert_target_w;
    wire insert_fire_w;
    wire line_write_valid_w;
    wire [1:0] line_write_index_w;
    wire [`CACHE_LINE_WIDTH-1:0] line_write_data_w;

    wire evict_dirty_sel_w;
    wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] evict_block_addr_sel_w;

    wire [`CACHE_LINE_WIDTH-1:0] evict_line_data_sel_w;

    wire lru_touch_valid_w;
    wire [1:0] lru_touch_index_w;

    wire scan_entry_valid_w;
    wire scan_entry_dirty_w;
    wire scan_entry_match_w;
    wire scan_entry_dirty_match_w;
    wire [`CACHE_BLOCK_ADDR_WIDTH-1:0] scan_entry_block_addr_w;

    wire [`CACHE_LINE_WIDTH-1:0] scan_entry_line_data_w;

    wire scan_idx_last_w;


    // ============================================================
    // Lookup
    // ============================================================

    assign lookup_hit0_w =
           lookup_valid &&
           valid_r[0] &&
           (block_addr_r[0] == lookup_block_addr);

    assign lookup_hit1_w =
           lookup_valid &&
           valid_r[1] &&
           (block_addr_r[1] == lookup_block_addr);

    assign lookup_hit2_w =
           lookup_valid &&
           valid_r[2] &&
           (block_addr_r[2] == lookup_block_addr);

    assign lookup_hit3_w =
           lookup_valid &&
           valid_r[3] &&
           (block_addr_r[3] == lookup_block_addr);

    assign lookup_hit =
           lookup_hit0_w ||
           lookup_hit1_w ||
           lookup_hit2_w ||
           lookup_hit3_w;

    assign lookup_hit_index =
           lookup_hit0_w ? 2'd0 :
           lookup_hit1_w ? 2'd1 :
           lookup_hit2_w ? 2'd2 :
           lookup_hit3_w ? 2'd3 :
           2'd0;

    assign lookup_hit_dirty =
           lookup_hit0_w ? dirty_r[0] :
           lookup_hit1_w ? dirty_r[1] :
           lookup_hit2_w ? dirty_r[2] :
           lookup_hit3_w ? dirty_r[3] :
           1'b0;

    assign lookup_line_data_w =
           lookup_hit ?
           line_data_r[lookup_hit_index] :
           {`CACHE_LINE_WIDTH{1'b0}};

    assign {lookup_data7, lookup_data6, lookup_data5, lookup_data4,
            lookup_data3, lookup_data2, lookup_data1, lookup_data0} =
           lookup_line_data_w;


    // ============================================================
    // Exact 4-entry LRU victim selection
    // ============================================================

    assign all_valid_w = &valid_r;

    // Entry 0 比 1、2、3 都旧。
    assign lru_way0_w =
           !lru_01_r &&
           !lru_02_r &&
           !lru_03_r;

    // Entry 1 比 0、2、3 都旧。
    assign lru_way1_w =
           lru_01_r &&
           !lru_12_r &&
           !lru_13_r;

    // Entry 2 比 0、1、3 都旧。
    assign lru_way2_w =
           lru_02_r &&
           lru_12_r &&
           !lru_23_r;

    // Entry 3 比 0、1、2 都旧。
    assign lru_way3_w =
           lru_03_r &&
           lru_13_r &&
           lru_23_r;

    assign lru_victim_w =
           lru_way0_w ? 2'd0 :
           lru_way1_w ? 2'd1 :
           lru_way2_w ? 2'd2 :
           lru_way3_w ? 2'd3 :
           2'd0;


    // ============================================================
    // Insert / eviction selection
    // ============================================================

    assign insert_target_w =
           !valid_r[0] ? 2'd0 :
           !valid_r[1] ? 2'd1 :
           !valid_r[2] ? 2'd2 :
           !valid_r[3] ? 2'd3 :
           lru_victim_w;

    assign insert_fire_w =
           insert_valid &&
           insert_ready;

    assign line_write_valid_w =
           !scan_busy_r &&
           !scan_req &&
           !evict_pending_r &&
           (
               (swap_valid && swap_insert_valid) ||
               (!swap_valid && insert_fire_w)
           );

    assign line_write_index_w =
           swap_valid ?
           swap_index :
           insert_target_w;

    assign line_write_data_w =
           swap_valid ?
           {swap_insert_data7, swap_insert_data6,
            swap_insert_data5, swap_insert_data4,
            swap_insert_data3, swap_insert_data2,
            swap_insert_data1, swap_insert_data0} :
           {insert_data7, insert_data6,
            insert_data5, insert_data4,
            insert_data3, insert_data2,
            insert_data1, insert_data0};

    // 写回期间始终使用锁存的 Entry。
    // 非写回期间使用当前 LRU Entry。
    assign active_evict_index_w =
           evict_pending_r ?
           evict_pending_index_r :
           lru_victim_w;

    assign evict_dirty_sel_w =
           (active_evict_index_w == 2'd0) ? dirty_r[0] :
           (active_evict_index_w == 2'd1) ? dirty_r[1] :
           (active_evict_index_w == 2'd2) ? dirty_r[2] :
           dirty_r[3];

    assign evict_block_addr_sel_w =
           (active_evict_index_w == 2'd0) ? block_addr_r[0] :
           (active_evict_index_w == 2'd1) ? block_addr_r[1] :
           (active_evict_index_w == 2'd2) ? block_addr_r[2] :
           block_addr_r[3];

    assign evict_line_data_sel_w =
           line_data_r[active_evict_index_w];

    // 有无效项或 LRU 项为 Clean 时，可以直接插入。
    // Dirty LRU 项需要先完成写回。
    assign insert_ready =
           !scan_busy_r &&
           !scan_req &&
           !evict_pending_r &&
           (!all_valid_w || !evict_dirty_sel_w);

    // Dirty Victim 在请求发起后，一直保持有效到 evict_accept。
    assign evict_valid =
           !scan_busy_r &&
           !scan_req &&
           (
               evict_pending_r ||
               (
                   insert_valid &&
                   all_valid_w &&
                   evict_dirty_sel_w
               )
           );

    assign evict_dirty =
           evict_valid &&
           evict_dirty_sel_w;

    assign evict_index =
           evict_valid ?
           active_evict_index_w :
           2'd0;

    // 第一次发现需要 Dirty Eviction 时锁存 Victim。
    assign evict_pending_start_w =
           !scan_busy_r &&
           !scan_req &&
           !evict_pending_r &&
           insert_valid &&
           all_valid_w &&
           evict_dirty_sel_w;

    assign evict_block_addr =
           evict_valid ?
           evict_block_addr_sel_w :
           {`CACHE_BLOCK_ADDR_WIDTH{1'b0}};

    assign {evict_data7, evict_data6, evict_data5, evict_data4,
            evict_data3, evict_data2, evict_data1, evict_data0} =
           evict_valid ?
           evict_line_data_sel_w :
           {`CACHE_LINE_WIDTH{1'b0}};


    // ============================================================
    // LRU touch event
    // ============================================================

    // 数据状态更新优先级：
    // scan > evict_accept > swap > insert。
    assign lru_touch_valid_w =
           !scan_busy_r &&
           !scan_req &&
           !evict_pending_r &&
           !evict_accept &&
           (
               (swap_valid && swap_insert_valid) ||
               (!swap_valid && insert_fire_w)
           );

    assign lru_touch_index_w =
           swap_valid ?
           swap_index :
           insert_target_w;


    // ============================================================
    // CACOP scan
    // ============================================================

    assign scan_entry_valid_w =
           valid_r[scan_idx_r];

    assign scan_entry_dirty_w =
           dirty_r[scan_idx_r];

    assign scan_entry_block_addr_w =
           (scan_idx_r == 2'd0) ? block_addr_r[0] :
           (scan_idx_r == 2'd1) ? block_addr_r[1] :
           (scan_idx_r == 2'd2) ? block_addr_r[2] :
           block_addr_r[3];

    assign scan_entry_match_w =
           scan_entry_valid_w &&
           (
               scan_match_index ?
               (scan_entry_block_addr_w[`CACHE_INDEX_WIDTH-1:0] == scan_index) :
               (scan_entry_block_addr_w == scan_block_addr)
           );

    assign scan_entry_dirty_match_w =
           scan_entry_match_w &&
           scan_entry_dirty_w;

    assign scan_entry_line_data_w =
           line_data_r[scan_idx_r];

    assign scan_idx_last_w =
           scan_idx_r == 2'd3;

    assign scan_busy =
           scan_busy_r;

    assign scan_evict_valid =
           scan_busy_r &&
           scan_entry_dirty_match_w;

    assign scan_evict_dirty =
           scan_evict_valid;

    assign scan_evict_block_addr =
           scan_evict_valid ?
           scan_entry_block_addr_w :
           {`CACHE_BLOCK_ADDR_WIDTH{1'b0}};

    assign {scan_evict_data7, scan_evict_data6,
            scan_evict_data5, scan_evict_data4,
            scan_evict_data3, scan_evict_data2,
            scan_evict_data1, scan_evict_data0} =
           scan_evict_valid ?
           scan_entry_line_data_w :
           {`CACHE_LINE_WIDTH{1'b0}};

    assign scan_done =
           scan_done_r;


    // ============================================================
    // Dirty  pending state
    // ============================================================

    always @(posedge clk) begin
        if(!resetn) begin
            evict_pending_r <= 1'b0;
        end
        else if(evict_accept &&
                evict_pending_r) begin
            evict_pending_r <= 1'b0;
        end
        else if(evict_pending_start_w) begin
            evict_pending_r <= 1'b1;
            evict_pending_index_r <= lru_victim_w;
        end
    end


    // ============================================================
    // Exact LRU state
    // ============================================================

    always @(posedge clk) begin
        if(!resetn) begin
            lru_01_r <= 1'b0;
            lru_02_r <= 1'b0;
            lru_03_r <= 1'b0;
            lru_12_r <= 1'b0;
            lru_13_r <= 1'b0;
            lru_23_r <= 1'b0;
        end
        else if(lru_touch_valid_w) begin
            case(lru_touch_index_w)
                2'd0: begin
                    // Entry 0 成为 MRU。
                    lru_01_r <= 1'b1;
                    lru_02_r <= 1'b1;
                    lru_03_r <= 1'b1;
                end

                2'd1: begin
                    // Entry 1 成为 MRU。
                    lru_01_r <= 1'b0;
                    lru_12_r <= 1'b1;
                    lru_13_r <= 1'b1;
                end

                2'd2: begin
                    // Entry 2 成为 MRU。
                    lru_02_r <= 1'b0;
                    lru_12_r <= 1'b0;
                    lru_23_r <= 1'b1;
                end

                default: begin
                    // Entry 3 成为 MRU。
                    lru_03_r <= 1'b0;
                    lru_13_r <= 1'b0;
                    lru_23_r <= 1'b0;
                end
            endcase
        end
    end


    // ============================================================
    // Victim Buffer data
    // ============================================================

    always @(posedge clk) begin
        if(line_write_valid_w) begin
            line_data_r[line_write_index_w] <= line_write_data_w;
        end
    end

    always @(posedge clk) begin
        if(!resetn) begin
            valid_r <= 4'b0000;
            dirty_r <= 4'b0000;
            scan_busy_r <= 1'b0;
        end
        else begin
            scan_done_r <= 1'b0;

            if(scan_busy_r) begin
                if(scan_entry_dirty_match_w) begin
                    if(scan_evict_accept) begin
                        valid_r[scan_idx_r] <= 1'b0;
                        dirty_r[scan_idx_r] <= 1'b0;

                        if(scan_idx_last_w) begin
                            scan_busy_r <= 1'b0;
                            scan_done_r <= 1'b1;
                        end
                        else begin
                            scan_idx_r <= scan_idx_r + 2'd1;
                        end
                    end
                end
                else begin
                    if(scan_entry_match_w) begin
                        valid_r[scan_idx_r] <= 1'b0;
                        dirty_r[scan_idx_r] <= 1'b0;
                    end

                    if(scan_idx_last_w) begin
                        scan_busy_r <= 1'b0;
                        scan_done_r <= 1'b1;
                    end
                    else begin
                        scan_idx_r <= scan_idx_r + 2'd1;
                    end
                end
            end
            else if(scan_req &&
                    !evict_pending_r) begin
                scan_busy_r <= 1'b1;
                scan_idx_r <= 2'd0;
            end
            else if(evict_accept &&
                    evict_pending_r) begin
                valid_r[evict_pending_index_r] <= 1'b0;
                dirty_r[evict_pending_index_r] <= 1'b0;
            end
            else if(!evict_pending_r &&
                    swap_valid) begin
                valid_r[swap_index] <= swap_insert_valid;

                dirty_r[swap_index] <=
                       swap_insert_valid &&
                       swap_insert_dirty;

                if(swap_insert_valid) begin
                    block_addr_r[swap_index] <=
                                swap_insert_block_addr;
                end
            end
            else if(!evict_pending_r &&
                    insert_fire_w) begin
                valid_r[insert_target_w] <= 1'b1;
                dirty_r[insert_target_w] <= insert_dirty;

                block_addr_r[insert_target_w] <=
                            insert_block_addr;
            end
        end
    end

// DCache Victim Buffer Perf
`ifdef PERF_COUNTER
    reg [31:0] perf_dcache_vb_insert;
    reg [31:0] perf_dcache_vb_hit;
    reg [31:0] perf_dcache_vb_evict;
    reg [31:0] perf_dcache_vb_writeback;

    always @(posedge clk) begin
        if (!resetn) begin
            perf_dcache_vb_insert <= 32'b0;
            perf_dcache_vb_hit <= 32'b0;
            perf_dcache_vb_evict <= 32'b0;
            perf_dcache_vb_writeback <= 32'b0;
        end else begin
            if (insert_fire_w) begin
                perf_dcache_vb_insert <= perf_dcache_vb_insert + 1;
            end

            if (lookup_valid && lookup_hit) begin
                perf_dcache_vb_hit <= perf_dcache_vb_hit + 1;
            end

            if (evict_valid && evict_accept) begin
                perf_dcache_vb_evict <= perf_dcache_vb_evict + 1;
            end


            if (evict_valid && evict_dirty && evict_accept) begin
                perf_dcache_vb_writeback <= perf_dcache_vb_writeback + 1;
            end
        end
    end
`endif

endmodule
