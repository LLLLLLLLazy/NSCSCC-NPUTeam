`include "header.v"


module stall_or_clear_detector (
        input  wire pc_reg_out_valid,
        output reg  pc_reg_stall,
        output reg  if1_clear,
        input  wire pc_state_out_is_exception,

        input  wire if_insfifo_reg_out_valid,
        output reg  if_insfifo_reg_stall,
        output reg  if2_clear,
        input  wire if_insfifo_state_out_is_exception,

        input  wire inst_fifo_out_valid,
        output reg  inst_fifo_stall,
        output reg  id_clear,
        input  wire insfifo_is_exception,

        input  wire id_allocbid_reg_out_valid,
        output reg  id_allocbid_reg_stall,
        output reg  allocbid_clear,
        input  wire id_allocbid_state_out_is_exception,


        input  wire allocbid_rename_reg_out_valid,
        output reg  allocbid_rename_reg_stall,
        output reg  rename_clear,
        input  wire allocbid_rename_state_out_is_exception,

        input  wire rename_dispatch_reg_out_valid,
        output reg  rename_dispatch_reg_stall,
        output reg  dispatch_clear,
        input  wire rename_dispatch_state_out_is_exception,

        input  wire alu_issue_queue_issue_valid,
        output reg  issue_queue_stall,
        output wire issue_queue_extra_stall,
        output reg  issue_clear,

        input  wire       issue_read_reg_out_valid,
        output reg        issue_read_reg_stall,
        output reg        read_clear,
        input  wire [4:0] issue_read_reg_out_bid,

        input  wire       read_exec_reg_out_valid,
        output reg        read_exec_reg_stall,
        output reg        exec_clear,
        input  wire [4:0] read_exec_reg_out_bid,

        input  wire       exec_writeback_reg_out_valid,
        output reg        exec_writeback_reg_stall,
        output reg        writeback_clear,
        input  wire [4:0] exec_writeback_reg_out_bid,


        input  wire       extra_issue_read_reg_out_valid,
        output reg        extra_issue_read_reg_stall,
        output reg        extra_read_clear,
        input  wire [4:0] extra_issue_read_reg_out_bid,

        input  wire       extra_read_exec_reg_out_valid,
        output reg        extra_read_exec_reg_stall,
        output reg        extra_exec_clear,
        input  wire [4:0] extra_read_exec_reg_out_bid,

        input  wire       extra_exec_writeback_reg_out_valid,
        output reg        extra_exec_writeback_reg_stall,
        output reg        extra_writeback_clear,
        input  wire [4:0] extra_exec_writeback_reg_out_bid,


        input  wire lsu_issue_queue_issue_valid,
        output reg  lsu_issue_queue_stall,
        output reg  lsu_issue_clear,

        input  wire       lsu_issue_read_reg_out_valid,
        output reg        lsu_issue_read_reg_stall,
        output reg        lsu_read_clear,
        input  wire [4:0] lsu_issue_read_reg_out_bid,

        input  wire       lsu_read_exec_reg_out_valid,
        output reg        lsu_read_exec_reg_stall,
        output reg        lsu_exec_clear,
        input  wire [4:0] lsu_read_exec_reg_out_bid,

        input  wire       lsu_exec_mem1_reg_out_valid,
        output reg        lsu_exec_mem1_reg_stall,
        output reg        lsu_mem1_clear,
        input  wire [4:0] lsu_exec_mem1_reg_out_bid,
        input  wire       lsu_exec_mem1_reg_out_store_ctrl,
        input  wire       lsu_exec_mem1_state_out_is_exception,

        input  wire       lsu_mem1_mem2_reg_out_valid,
        output reg        lsu_mem1_mem2_reg_stall,
        output reg        lsu_mem2_clear,
        input  wire [4:0] lsu_mem1_mem2_reg_out_bid,
        input  wire       lsu_mem1_mem2_reg_out_store_ctrl,
        input  wire       lsu_mem1_mem2_state_out_is_exception,

        input  wire       lsu_mem2_writeback_reg_out_valid,
        output reg        lsu_mem2_writeback_reg_stall,
        output reg        lsu_writeback_clear,
        input  wire [4:0] lsu_mem2_writeback_reg_out_bid,
        input  wire       lsu_mem2_writeback_state_out_is_exception,

        input  wire md_issue_queue_div_issue_valid,
        input  wire md_issue_queue_mul_issue_valid,
        input  wire md_issue_queue_bru_issue_valid,
        output reg  md_issue_queue_div_stall,
        output reg  md_issue_queue_mul_stall,
        output reg  md_issue_queue_bru_stall,
        output reg  md_issue_clear,

        // input  wire       md_issue_read_reg_out_valid,
        // output reg        md_issue_read_reg_stall,
        // output reg        md_read_clear,
        // input  wire [4:0] md_issue_read_reg_out_bid,

        input  wire       md_div_issue_read_reg_out_valid,
        output reg        md_div_issue_read_reg_stall,
        output reg        md_div_read_clear,
        input  wire [4:0] md_div_issue_read_reg_out_bid,

        input  wire       md_mul_issue_read_reg_out_valid,
        output reg        md_mul_issue_read_reg_stall,
        output reg        md_mul_read_clear,
        input  wire [4:0] md_mul_issue_read_reg_out_bid,

        input  wire       md_bru_issue_read_reg_out_valid,
        output reg        md_bru_issue_read_reg_stall,
        output reg        md_bru_read_clear,
        input  wire [4:0] md_bru_issue_read_reg_out_bid,


        input  wire mul_reg_out_valid,
        input  wire div_reg_out_valid,
        output reg  md_reg_stall,
        output reg  md_clear,

        input  wire       md_read_bru_reg_out_valid,
        output reg        md_read_bru_reg_stall,
        output reg        md_bru_clear,
        input  wire [4:0] md_read_bru_reg_out_bid,

        input  wire       md_bru_writeback_reg_out_valid,
        output reg        md_bru_writeback_reg_stall,
        output reg        md_writeback_clear,
        input  wire [4:0] md_bru_writeback_reg_out_bid,


        input  wire fast_issue_queue_issue_valid,
        output reg  fast_issue_queue_stall,
        output reg  fast_issue_clear,

        input  wire       fast_issue_writeback_reg_out_valid,
        output reg        fast_issue_writeback_reg_stall,
        output reg        fast_writeback_clear,
        input  wire [4:0] fast_issue_writeback_reg_out_bid,

        input  wire fast_issue_queue_extra_issue_valid,
        output reg  fast_issue_queue_extra_stall,

        input  wire       fast_extra_issue_writeback_reg_out_valid,
        output reg        fast_extra_issue_writeback_reg_stall,
        output reg        fast_extra_writeback_clear,
        input  wire [4:0] fast_extra_issue_writeback_reg_out_bid,

        input  wire privilege_issue_queue_issue_valid,
        output reg  privilege_issue_queue_stall,
        output reg  privilege_issue_clear,


        input wire global_flush,



        input wire rename_buffer_result_rename_success,
        input wire cam_rmt_rename_success,
        input wire allocbid_rename_reg_out_regfile_we,

        input wire inst_fifo_wr_ready,

        input wire store_buffer_store_ready,
        input wire lsu_read_exec_reg_out_is_store_or_not_load,
        input wire lsu_exec_mem1_reg_out_is_store_or_not_load,
        input wire lsu_mem1_mem2_reg_out_is_store_or_not_load,
        input wire lsu_mem2_load_miss,

        input wire [2:0] rename_dispatch_reg_out_sel_issue_queue,
        input wire       alu_issue_queue_dispatch_ready,
        input wire       lsu_issue_queue_dispatch_ready,
        input wire       md_issue_queue_dispatch_ready,
        input wire       fast_issue_queue_dispatch_ready,          //
        input wire       privilege_issue_queue_dispatch_ready,
        input wire       rob_alloc_ready,

        input wire [1:0] id_allocbid_reg_out_sel_npc,
        input wire       branch_id_allocator_alloc_bid_ready,
        input wire       branch_id_allocator_alloc_bid_valid,
        input wire       allocbid_buffer_alloc_already,


        output wire b_flush,
        output wire predict_flush,


        input wire       md_bru_writeback_reg_out_is_jump,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] branch_id_allocator_bid_head,
        input wire [1:0] lsu_exec_mem1_state_out_mmu_data_mat,
        input wire       store_buffer_suc,

        input wire sel_store_commit,



        input wire [2:0] inst_sram_fsm_state,
        input wire [2:0] data_sram_fsm_state,

        output reg data_sram_fsm_miss_trans,

        input wire cache_subsystem_mem2_miss,
        input wire cache_subsystem_mem2_refill_valid,
        input wire cache_subsystem_dcache_busy,
        input wire cache_subsystem_if2_miss,
        input wire cache_subsystem_if2_refill_valid,
        input wire cache_subsystem_icache_busy,

        input wire [                  1:0] cacop_fsm_state,
        input wire                         lsu_mem1_mem2_reg_out_is_cacop,
        input wire                         lsu_exec_mem1_reg_out_is_cacop,
        input wire                         lsu_read_exec_reg_out_is_cacop,
        input wire [`ROB_ID_WIDTH - 1 : 0] rob_commit_rob_id,
        input wire [`ROB_ID_WIDTH - 1 : 0] lsu_read_exec_reg_out_rob_id,


        input wire decode_is_idle,
        input wire is_int,

        input wire lsu_mem1_mem2_reg_out_is_dbar,
        input wire lsu_mem1_mem2_reg_out_is_sc_w,
        input wire csr_regfile_llbit,

        input wire lsu_read_exec_reg_out_is_ll_w,
        input wire lsu_read_exec_reg_out_is_sc_w,
        input wire lsu_read_exec_reg_out_is_dbar,

        input wire store_buffer_has_store,

        input wire id_allocbid_reg_out_is_b_jump




    );

    wire extra_writeback_gt;

    circle_comparator u_extra_writeback_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (extra_exec_writeback_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(extra_writeback_gt)
                      );




    always @(*) begin
        if (global_flush || (predict_flush && extra_writeback_gt && extra_exec_writeback_reg_out_valid)) begin
            extra_exec_writeback_reg_stall = 1'b0;
            extra_writeback_clear          = 1'b1;
        end
        else begin
            extra_exec_writeback_reg_stall = 1'b0;
            extra_writeback_clear          = 1'b0;
        end
    end

    wire extra_exec_gt;

    circle_comparator u_extra_exec_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (extra_read_exec_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(extra_exec_gt)
                      );

    always @(*) begin
        if (global_flush || (predict_flush && extra_exec_gt && extra_read_exec_reg_out_valid)) begin
            extra_exec_clear          = 1'b1;
            extra_read_exec_reg_stall = 1'b0;
        end
        else begin
            extra_exec_clear          = 1'b0;
            extra_read_exec_reg_stall = 1'b0;
        end
    end


    wire extra_read_gt;

    circle_comparator u_extra_read_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (extra_issue_read_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(extra_read_gt)
                      );


    always @(*) begin
        if (global_flush || (predict_flush && extra_read_gt && extra_issue_read_reg_out_valid)) begin
            extra_read_clear           = 1'b1;
            extra_issue_read_reg_stall = 1'b0;
        end
        else begin
            extra_read_clear           = 1'b0;
            extra_issue_read_reg_stall = 1'b0;
        end
    end





    wire writeback_gt;

    circle_comparator u_writeback_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (exec_writeback_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(writeback_gt)
                      );




    always @(*) begin
        if (global_flush || (predict_flush && writeback_gt && exec_writeback_reg_out_valid)) begin
            exec_writeback_reg_stall = 1'b0;
            writeback_clear          = 1'b1;
        end
        else begin
            exec_writeback_reg_stall = 1'b0;
            writeback_clear          = 1'b0;
        end
    end

    wire exec_gt;

    circle_comparator u_exec_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (read_exec_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(exec_gt)
                      );

    always @(*) begin
        if (global_flush || (predict_flush && exec_gt && read_exec_reg_out_valid)) begin
            exec_clear          = 1'b1;
            read_exec_reg_stall = 1'b0;
        end
        else begin
            exec_clear          = 1'b0;
            read_exec_reg_stall = 1'b0;
        end
    end


    wire read_gt;

    circle_comparator u_read_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (issue_read_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(read_gt)
                      );


    always @(*) begin
        if (global_flush || (predict_flush && read_gt && issue_read_reg_out_valid)) begin
            read_clear           = 1'b1;
            issue_read_reg_stall = 1'b0;
        end
        else begin
            read_clear           = 1'b0;
            issue_read_reg_stall = 1'b0;
        end
    end

    always @(*) begin
        if (global_flush) begin
            issue_clear       = 1'b1;
            issue_queue_stall = 1'b0;
        end
        else begin
            issue_clear       = 1'b0;
            issue_queue_stall = 1'b0;
        end
    end

    assign issue_queue_extra_stall = 1'b0;


    wire lsu_writeback_gt;

    circle_comparator u_lsu_writeback_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (lsu_mem2_writeback_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(lsu_writeback_gt)
                      );

    always @(*) begin
        if (global_flush || (predict_flush && lsu_writeback_gt && lsu_mem2_writeback_reg_out_valid)) begin
            lsu_writeback_clear          = 1'b1;
            lsu_mem2_writeback_reg_stall = 1'b0;
        end
        else begin
            lsu_writeback_clear          = 1'b0;
            lsu_mem2_writeback_reg_stall = 1'b0;
        end
    end

    wire lsu_mem2_gt;

    circle_comparator u_lsu_mem2_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (lsu_mem1_mem2_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(lsu_mem2_gt)
                      );

    always @(*) begin
        data_sram_fsm_miss_trans = 1'b0;

        if (!(lsu_mem1_mem2_reg_out_valid && lsu_mem1_mem2_reg_out_store_ctrl) && (global_flush || (predict_flush && lsu_mem2_gt && lsu_mem1_mem2_reg_out_valid))) begin
            lsu_mem2_clear          = 1'b1;
            lsu_mem1_mem2_reg_stall = 1'b0;
        end
        else if(lsu_mem1_mem2_reg_out_valid &&
                !lsu_mem1_mem2_state_out_is_exception &&
                (!lsu_mem1_mem2_reg_out_is_store_or_not_load &&!lsu_mem1_mem2_reg_out_is_cacop && !lsu_mem1_mem2_reg_out_is_dbar &&!lsu_mem1_mem2_reg_out_is_sc_w && lsu_mem2_load_miss|| lsu_mem1_mem2_reg_out_is_sc_w && csr_regfile_llbit || lsu_mem1_mem2_reg_out_is_store_or_not_load  && lsu_mem1_mem2_reg_out_store_ctrl) &&
                ((data_sram_fsm_state == `DATA_SRAM_FSM_IDLE && cache_subsystem_mem2_miss) || data_sram_fsm_state==`DATA_SRAM_FSM_MISS ||
                 data_sram_fsm_state==`DATA_SRAM_FSM_SHAKE||(data_sram_fsm_state==`DATA_SRAM_FSM_WAIT && !cache_subsystem_mem2_refill_valid) )) begin
            data_sram_fsm_miss_trans = data_sram_fsm_state == `DATA_SRAM_FSM_MISS;
            lsu_mem2_clear           = 1'b0;
            lsu_mem1_mem2_reg_stall  = 1'b1;
        end
        else if (lsu_mem1_mem2_reg_out_valid && !lsu_mem1_mem2_state_out_is_exception && lsu_mem1_mem2_reg_out_is_cacop && cacop_fsm_state != `SRAM_FINISH) begin
            lsu_mem2_clear          = 1'b0;
            lsu_mem1_mem2_reg_stall = 1'b1;
        end
        else begin
            lsu_mem2_clear          = 1'b0;
            lsu_mem1_mem2_reg_stall = 1'b0;
        end
    end


    wire lsu_mem1_gt;

    circle_comparator u_lsu_mem1_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (lsu_exec_mem1_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(lsu_mem1_gt)
                      );

    always @(*) begin
        if (global_flush || (predict_flush && lsu_mem1_gt && lsu_exec_mem1_reg_out_valid)) begin
            lsu_mem1_clear          = 1'b1;
            lsu_exec_mem1_reg_stall = 1'b0;
        end
        else if (sel_store_commit && lsu_exec_mem1_reg_out_valid) begin
            lsu_mem1_clear          = 1'b0;
            lsu_exec_mem1_reg_stall = 1'b1;
        end
        else if (lsu_exec_mem1_reg_out_valid && !lsu_exec_mem1_state_out_is_exception &&
                 cache_subsystem_dcache_busy && !lsu_exec_mem1_reg_out_is_store_or_not_load &&lsu_exec_mem1_state_out_mmu_data_mat == 2'b01 ) begin
            lsu_mem1_clear          = 1'b0;
            lsu_exec_mem1_reg_stall = 1'b1;
        end
        else if (lsu_exec_mem1_reg_out_valid && !lsu_exec_mem1_state_out_is_exception && lsu_exec_mem1_reg_out_is_store_or_not_load && !(store_buffer_store_ready || store_buffer_has_store)) begin
            lsu_mem1_clear          = 1'b0;
            lsu_exec_mem1_reg_stall = 1'b1;
        end
        else if(lsu_exec_mem1_reg_out_valid &&!lsu_exec_mem1_state_out_is_exception && lsu_exec_mem1_state_out_mmu_data_mat == 2'b00 && store_buffer_suc &&
                !lsu_exec_mem1_reg_out_is_store_or_not_load && !lsu_exec_mem1_reg_out_is_cacop) begin
            lsu_mem1_clear          = 1'b0;
            lsu_exec_mem1_reg_stall = 1'b1;
        end
        else if (lsu_exec_mem1_reg_out_valid && lsu_mem1_mem2_reg_stall) begin
            lsu_mem1_clear          = 1'b0;
            lsu_exec_mem1_reg_stall = 1'b1;
        end
        else begin
            lsu_mem1_clear          = 1'b0;
            lsu_exec_mem1_reg_stall = 1'b0;
        end
    end


    wire lsu_exec_gt;

    circle_comparator u_lsu_exec_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (lsu_read_exec_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(lsu_exec_gt)
                      );

    always @(*) begin
        if (global_flush || (predict_flush && lsu_exec_gt && lsu_read_exec_reg_out_valid)) begin
            lsu_exec_clear          = 1'b1;
            lsu_read_exec_reg_stall = 1'b0;
        end
        else if (lsu_read_exec_reg_out_valid && (lsu_read_exec_reg_out_is_cacop|| lsu_read_exec_reg_out_is_ll_w||lsu_read_exec_reg_out_is_sc_w ||lsu_read_exec_reg_out_is_dbar)&& lsu_read_exec_reg_out_rob_id != rob_commit_rob_id) begin
            lsu_exec_clear          = 1'b0;
            lsu_read_exec_reg_stall = 1'b1;
        end
        else if (lsu_exec_mem1_reg_stall && lsu_read_exec_reg_out_valid) begin
            lsu_exec_clear          = 1'b0;
            lsu_read_exec_reg_stall = 1'b1;
        end
        else begin
            lsu_exec_clear          = 1'b0;
            lsu_read_exec_reg_stall = 1'b0;
        end
    end

    wire lsu_read_gt;

    circle_comparator u_lsu_read_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (lsu_issue_read_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(lsu_read_gt)
                      );

    always @(*) begin
        if (global_flush || (predict_flush && lsu_read_gt && lsu_issue_read_reg_out_valid)) begin
            lsu_read_clear           = 1'b1;
            lsu_issue_read_reg_stall = 1'b0;
        end
        else if (lsu_read_exec_reg_stall && lsu_issue_read_reg_out_valid) begin
            lsu_read_clear           = 1'b0;
            lsu_issue_read_reg_stall = 1'b1;
        end
        else begin
            lsu_read_clear           = 1'b0;
            lsu_issue_read_reg_stall = 1'b0;
        end
    end

    always @(*) begin
        if (global_flush) begin
            lsu_issue_clear       = 1'b1;
            lsu_issue_queue_stall = 1'b0;
        end
        else if (lsu_issue_read_reg_stall && lsu_issue_queue_issue_valid) begin
            lsu_issue_clear       = 1'b0;
            lsu_issue_queue_stall = 1'b1;
        end
        else begin
            lsu_issue_clear       = 1'b0;
            lsu_issue_queue_stall = 1'b0;
        end
    end

    always @(*) begin
        if (global_flush) begin
            md_clear     = 1'b1;
            md_reg_stall = 1'b0;
        end
        else begin
            md_clear     = 1'b0;
            md_reg_stall = 1'b0;
        end
    end

    // wire md_writeback_gt;

    // circle_comparator u_md_writeback_circle_comparator (
    //     .head  (branch_id_allocator_bid_head),
    //     .a     (md_bru_writeback_reg_out_bid),
    //     .b     (predict_flush_bid),
    //     .a_gt_b(md_writeback_gt)
    // );



    always @(*) begin
        if (global_flush  /*|| (predict_flush && md_writeback_gt && md_bru_writeback_reg_out_valid)*/) begin
            md_writeback_clear         = 1'b1;
            md_bru_writeback_reg_stall = 1'b0;
        end
        else begin
            md_writeback_clear         = 1'b0;
            md_bru_writeback_reg_stall = 1'b0;
        end
    end

    wire md_bru_gt;

    circle_comparator u_md_bru_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (md_read_bru_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(md_bru_gt)
                      );



    always @(*) begin
        if (global_flush || (predict_flush && md_bru_gt && md_read_bru_reg_out_valid)) begin
            md_bru_clear          = 1'b1;
            md_read_bru_reg_stall = 1'b0;
        end
        else begin
            md_bru_clear          = 1'b0;
            md_read_bru_reg_stall = 1'b0;
        end
    end


    wire md_div_read_gt;

    circle_comparator u_md_div_read_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (md_div_issue_read_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(md_div_read_gt)
                      );



    always @(*) begin
        if (global_flush || (predict_flush && md_div_read_gt && md_div_issue_read_reg_out_valid)) begin
            md_div_read_clear           = 1'b1;
            md_div_issue_read_reg_stall = 1'b0;
        end
        else begin
            md_div_read_clear           = 1'b0;
            md_div_issue_read_reg_stall = 1'b0;
        end
    end

    wire md_mul_read_gt;

    circle_comparator u_md_mul_read_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (md_mul_issue_read_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(md_mul_read_gt)
                      );



    always @(*) begin
        if (global_flush || (predict_flush && md_mul_read_gt && md_mul_issue_read_reg_out_valid)) begin
            md_mul_read_clear           = 1'b1;
            md_mul_issue_read_reg_stall = 1'b0;
        end
        else begin
            md_mul_read_clear           = 1'b0;
            md_mul_issue_read_reg_stall = 1'b0;
        end
    end


    wire md_bru_read_gt;

    circle_comparator u_md_bru_read_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (md_bru_issue_read_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(md_bru_read_gt)
                      );


    always @(*) begin
        if (global_flush || (predict_flush && md_bru_read_gt && md_bru_issue_read_reg_out_valid)) begin
            md_bru_read_clear           = 1'b1;
            md_bru_issue_read_reg_stall = 1'b0;
        end
        else begin
            md_bru_read_clear           = 1'b0;
            md_bru_issue_read_reg_stall = 1'b0;
        end
    end



    always @(*) begin
        if (global_flush) begin
            md_issue_clear           = 1'b1;
            md_issue_queue_div_stall = 1'b0;
            md_issue_queue_mul_stall = 1'b0;
            md_issue_queue_bru_stall = 1'b0;
        end
        else begin
            md_issue_clear           = 1'b0;
            md_issue_queue_div_stall = 1'b0;
            md_issue_queue_mul_stall = 1'b0;
            md_issue_queue_bru_stall = 1'b0;
        end
    end


    wire fast_writeback_gt;

    circle_comparator u_fast_writeback_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (fast_issue_writeback_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(fast_writeback_gt)
                      );




    always @(*) begin
        if (global_flush || (predict_flush && fast_writeback_gt && fast_issue_writeback_reg_out_valid)) begin
            fast_writeback_clear           = 1'b1;
            fast_issue_writeback_reg_stall = 1'b0;
        end
        else begin
            fast_writeback_clear           = 1'b0;
            fast_issue_writeback_reg_stall = 1'b0;
        end
    end


    always @(*) begin
        if (global_flush) begin
            fast_issue_clear       = 1'b1;
            fast_issue_queue_stall = 1'b0;
        end
        else begin
            fast_issue_clear       = 1'b0;
            fast_issue_queue_stall = 1'b0;
        end
    end

    wire fast_extra_writeback_gt;

    circle_comparator u_fast_extra_writeback_circle_comparator (
                          .head  (branch_id_allocator_bid_head),
                          .a     (fast_extra_issue_writeback_reg_out_bid),
                          .b     (predict_flush_bid),
                          .a_gt_b(fast_extra_writeback_gt)
                      );




    always @(*) begin
        if (global_flush || (predict_flush && fast_extra_writeback_gt && fast_extra_issue_writeback_reg_out_valid)) begin
            fast_extra_writeback_clear           = 1'b1;
            fast_extra_issue_writeback_reg_stall = 1'b0;
        end
        else begin
            fast_extra_writeback_clear           = 1'b0;
            fast_extra_issue_writeback_reg_stall = 1'b0;
        end
    end


    always @(*) begin
        if (global_flush) begin
            fast_issue_queue_extra_stall = 1'b0;
        end
        else begin
            fast_issue_queue_extra_stall = 1'b0;
        end
    end


    always @(*) begin
        if (global_flush) begin
            privilege_issue_clear       = 1'b1;
            privilege_issue_queue_stall = 1'b0;
        end
        else begin
            privilege_issue_clear       = 1'b0;
            privilege_issue_queue_stall = 1'b0;
        end
    end


    assign predict_flush = !global_flush && md_bru_writeback_reg_out_valid && md_bru_writeback_reg_out_is_jump;



    wire alu_dispatch;
    wire lsu_dispatch;
    wire md_dispatch;
    wire fast_dispatch;
    wire no_dispatch;
    wire privilege_dispatch;

    assign alu_dispatch = (!rob_alloc_ready || !alu_issue_queue_dispatch_ready) && rename_dispatch_reg_out_valid &&
           !rename_dispatch_state_out_is_exception && (rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_INTEGER );
    assign lsu_dispatch = (!rob_alloc_ready || !lsu_issue_queue_dispatch_ready) && rename_dispatch_reg_out_valid &&
           !rename_dispatch_state_out_is_exception && (rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_LOAD || rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_STORE);
    assign md_dispatch = (!rob_alloc_ready || !md_issue_queue_dispatch_ready) && rename_dispatch_reg_out_valid &&
           !rename_dispatch_state_out_is_exception &&(rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_MD|| rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_BRQ);
    assign fast_dispatch = (!rob_alloc_ready || !fast_issue_queue_dispatch_ready) && rename_dispatch_reg_out_valid &&
           !rename_dispatch_state_out_is_exception && (rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_FAST);
    assign no_dispatch = !rob_alloc_ready && rename_dispatch_reg_out_valid && ((rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_NO) || rename_dispatch_state_out_is_exception);
    assign privilege_dispatch = (!rob_alloc_ready || !privilege_issue_queue_dispatch_ready) && rename_dispatch_reg_out_valid &&
           !rename_dispatch_state_out_is_exception && (rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_PRIVILIEGE);
    always @(*) begin
        if (global_flush || predict_flush) begin
            dispatch_clear            = 1'b1;
            rename_dispatch_reg_stall = 1'b0;
        end
        else if (alu_dispatch || lsu_dispatch || md_dispatch || fast_dispatch || no_dispatch || privilege_dispatch) begin
            dispatch_clear            = 1'b0;
            rename_dispatch_reg_stall = 1'b1;
        end
        else begin
            dispatch_clear            = 1'b0;
            rename_dispatch_reg_stall = 1'b0;
        end
    end

    always @(*) begin
        if (global_flush || predict_flush) begin
            rename_clear              = 1'b1;
            allocbid_rename_reg_stall = 1'b0;
        end
        else if (allocbid_rename_reg_out_valid && !allocbid_rename_state_out_is_exception && allocbid_rename_reg_out_regfile_we &&
                 !(cam_rmt_rename_success || rename_buffer_result_rename_success)) begin
            rename_clear              = 1'b0;
            allocbid_rename_reg_stall = 1'b1;
        end
        else if (rename_dispatch_reg_stall && allocbid_rename_reg_out_valid) begin
            rename_clear              = 1'b0;
            allocbid_rename_reg_stall = 1'b1;
        end
        else begin
            rename_clear              = 1'b0;
            allocbid_rename_reg_stall = 1'b0;
        end
    end


    always @(*) begin
        if (global_flush || predict_flush) begin
            allocbid_clear        = 1'b1;
            id_allocbid_reg_stall = 1'b0;
        end
        else if(id_allocbid_reg_out_valid&& !id_allocbid_state_out_is_exception &&(id_allocbid_reg_out_sel_npc == `SEL_NPC_BRANCH || id_allocbid_reg_out_sel_npc == `SEL_NPC_JIRL) && !(allocbid_buffer_alloc_already||branch_id_allocator_alloc_bid_ready)) begin
            allocbid_clear        = 1'b0;
            id_allocbid_reg_stall = 1'b1;
        end
        else if (id_allocbid_reg_out_valid && allocbid_rename_reg_stall) begin
            allocbid_clear        = 1'b0;
            id_allocbid_reg_stall = 1'b1;
        end
        else begin
            allocbid_clear        = 1'b0;
            id_allocbid_reg_stall = 1'b0;
        end

    end

    //optimize that first detect and then flush
    assign b_flush = !predict_flush && !global_flush && !id_allocbid_reg_stall && id_allocbid_reg_out_valid && id_allocbid_reg_out_is_b_jump;

    always @(*) begin
        if (global_flush || b_flush || predict_flush) begin
            id_clear        = 1'b1;
            inst_fifo_stall = 1'b0;
        end
        else if(inst_fifo_out_valid == 1'b1 && !insfifo_is_exception &&
                decode_is_idle && !is_int) begin
            id_clear = 1'b0;
            inst_fifo_stall = 1'b1;
        end
        else if (id_allocbid_reg_stall && inst_fifo_out_valid) begin
            id_clear        = 1'b0;
            inst_fifo_stall = 1'b1;
        end
        else begin
            id_clear        = 1'b0;
            inst_fifo_stall = 1'b0;
        end
    end

    always @(*) begin
        if (global_flush || b_flush || predict_flush) begin
            if2_clear            = 1'b1;
            if_insfifo_reg_stall = 1'b0;
        end
        else if(if_insfifo_reg_out_valid && !if_insfifo_state_out_is_exception &&
                (
                    (inst_sram_fsm_state==`INST_SRAM_FSM_IDLE && cache_subsystem_if2_miss) ||
                    inst_sram_fsm_state==`INST_SRAM_FSM_MISS ||
                    (inst_sram_fsm_state==`INST_SRAM_FSM_WAIT && !cache_subsystem_if2_refill_valid)
                )
               ) begin
            if2_clear            = 1'b0;
            if_insfifo_reg_stall = 1'b1;
        end
        else if (!inst_fifo_wr_ready && if_insfifo_reg_out_valid) begin
            if2_clear            = 1'b0;
            if_insfifo_reg_stall = 1'b1;
        end
        else begin
            if2_clear            = 1'b0;
            if_insfifo_reg_stall = 1'b0;
        end
    end

    always @(*) begin
        if (global_flush || b_flush || predict_flush) begin
            if1_clear    = 1'b1;
            pc_reg_stall = 1'b0;
        end
        else if (pc_reg_out_valid && !pc_state_out_is_exception && cache_subsystem_icache_busy) begin
            if1_clear    = 1'b0;
            pc_reg_stall = 1'b1;
        end
        else if (if_insfifo_reg_stall && pc_reg_out_valid) begin
            if1_clear    = 1'b0;
            pc_reg_stall = 1'b1;
        end
        else begin
            if1_clear    = 1'b0;
            pc_reg_stall = 1'b0;
        end
    end


endmodule
