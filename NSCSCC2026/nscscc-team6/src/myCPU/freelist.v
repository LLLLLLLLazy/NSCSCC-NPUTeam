`include "mycpu.h"

// -----------------------------------------------------------------------------
// 双分配、双回收物理寄存器空闲队列
//
// 核心指针
//   alloc_head    当前推测状态下，下一个可分配 preg 的位置
//   commit_head   已提交状态对应的队首，用于 flush 恢复
//   free_tail     下一个回收 preg 的写入位置
//
// 正常运行
//   Rename 分配 preg，alloc_head 前移
//   Commit 回收 old_preg，free_tail 前移
//   每提交一条带目的寄存器的指令，commit_head 同步前移
//
// Flush
//   不扫描 64 位 bitmap，也不依赖 aRAT 重建
//   直接令 alloc_head 恢复到 commit_head
//   同周期 Commit 产生的回收仍然保留
// -----------------------------------------------------------------------------
module freelist (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    // 为保持原有顶层接口而保留。FIFO 版本不再使用该信号。
    input  wire [63:0] arat_mapped_mask,

    // Rename 分配接口
    input  wire        req_0,
    input  wire        req_1,
    output wire [ 5:0] alloc_preg_0,
    output wire [ 5:0] alloc_preg_1,
    output wire [ 1:0] free_cnt,

    // Commit 回收接口
    input  wire        free_we_0,
    input  wire [ 5:0] free_preg_0,
    input  wire        free_we_1,
    input  wire [ 5:0] free_preg_1
);

    localparam integer PHY_REG_NUM  = 64;
    localparam integer ARCH_REG_NUM = 32;

    // 队列只存 preg 编号。深度使用 64，便于用 6 bit 指针自然回绕。
    reg [5:0] free_queue [0:PHY_REG_NUM-1];

    reg [5:0] alloc_head;
    reg [5:0] commit_head;
    reg [5:0] free_tail;
    reg [6:0] free_count;

    // -------------------------------------------------------------------------
    // 当前周期的分配数量
    // req_0 和 req_1 已经由 rename_top 保证不会超过 free_cnt。
    // -------------------------------------------------------------------------
    wire [1:0] pop_count = {1'b0, req_0} + {1'b0, req_1};

    // 忽略 p0。正常设计中 old_preg 不应为 p0，这里再做一次保护。
    wire push_valid_0 = free_we_0 && (free_preg_0 != 6'd0);
    wire push_valid_1 = free_we_1 && (free_preg_1 != 6'd0);
    wire [1:0] push_count = {1'b0, push_valid_0}
                          + {1'b0, push_valid_1};

    wire [5:0] alloc_head_plus_1 = alloc_head + 6'd1;
    wire [5:0] free_tail_plus_1  = free_tail  + 6'd1;

    // 同周期回收完成后的指针。
    wire [5:0] free_tail_after_push =
        free_tail + {{4{1'b0}}, push_count};

    wire [5:0] commit_head_after_push =
        commit_head + {{4{1'b0}}, push_count};

    // 6 bit 减法自然按模 64 回绕。
    // flush 后，已提交状态的空闲队列范围是
    // [commit_head_after_push, free_tail_after_push)。
    wire [5:0] recover_count_mod64 =
        free_tail_after_push - commit_head_after_push;

    wire [6:0] free_count_after_normal =
        free_count
        + {{5{1'b0}}, push_count}
        - {{5{1'b0}}, pop_count};

    // -------------------------------------------------------------------------
    // 分配候选输出
    //
    // 关键时序优化：候选 preg 只由当前队首指针决定，不再依赖 req_0/req_1。
    // req_0/req_1 只负责在时钟沿真正消费候选（推进 alloc_head）。
    // 候选0/1分别表示当前空闲队列的第1/第2个元素。
    // -------------------------------------------------------------------------
    assign alloc_preg_0 = free_queue[alloc_head];
    assign alloc_preg_1 = free_queue[alloc_head_plus_1];

    // rename_top 只需要知道当前是否至少还有 0、1、2 个空闲 preg。
    assign free_cnt = (free_count >= 7'd2) ? 2'd2 :
                      (free_count == 7'd1) ? 2'd1 : 2'd0;

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // 初始映射是 r0-r31 -> p0-p31。
            // 因此初始空闲物理寄存器是 p32-p63。
            for (i = 0; i < ARCH_REG_NUM; i = i + 1) begin
                free_queue[i] <= i + ARCH_REG_NUM;
            end

            alloc_head  <= 6'd0;
            commit_head <= 6'd0;
            free_tail   <= 6'd32;
            free_count  <= 7'd32;
        end
        else begin
            // -------------------------------------------------------------
            // Commit 回收 old_preg。
            // 两个端口可以出现 01、10、11 三种有效组合，因此要压紧写入。
            // -------------------------------------------------------------
            if (push_valid_0) begin
                free_queue[free_tail] <= free_preg_0;

                if (push_valid_1) begin
                    free_queue[free_tail_plus_1] <= free_preg_1;
                end
            end
            else if (push_valid_1) begin
                free_queue[free_tail] <= free_preg_1;
            end

            if (flush) begin
                // Flush 当周期可能仍有一条提交指令产生回收。
                // 因此恢复时必须采用 after_push 指针，不能丢掉本周期提交。
                alloc_head  <= commit_head_after_push;
                commit_head <= commit_head_after_push;
                free_tail   <= free_tail_after_push;
                free_count  <= {1'b0, recover_count_mod64};
            end
            else begin
                alloc_head  <= alloc_head + {{4{1'b0}}, pop_count};
                commit_head <= commit_head_after_push;
                free_tail   <= free_tail_after_push;
                free_count  <= free_count_after_normal;
            end
        end
    end

    // arat_mapped_mask 在该实现中不使用，保留端口只为避免修改顶层连线。
    wire unused_arat_mask = &{1'b0, arat_mapped_mask};

`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!reset) begin
            if (!flush && ({5'd0, pop_count} > free_count)) begin
                $display("ERROR: freelist underflow, pop=%0d count=%0d",
                         pop_count, free_count);
                $stop;
            end

            if (push_valid_0 && push_valid_1 &&
                (free_preg_0 == free_preg_1)) begin
                $display("ERROR: duplicate preg returned to freelist: p%0d",
                         free_preg_0);
                $stop;
            end

            if (free_count > 7'd32) begin
                $display("ERROR: freelist count exceeds 32: %0d", free_count);
                $stop;
            end

            if (flush && (recover_count_mod64 != 6'd32)) begin
                $display("ERROR: committed freelist size is not 32 on flush: %0d",
                         recover_count_mod64);
                $stop;
            end
        end
    end
`endif

endmodule
