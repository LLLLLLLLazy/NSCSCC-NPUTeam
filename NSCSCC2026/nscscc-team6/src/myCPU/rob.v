module rob (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    // ==========================================
    // 1. Rename 分配接口
    // ==========================================
    input  wire        req_rob_0,
    input  wire        req_rob_1,
    output wire [ 3:0] alloc_rob_id_0,
    output wire [ 3:0] alloc_rob_id_1,
    output wire [ 1:0] rob_free_cnt,

    // --- 指令 0 初始信息 ---
    input  wire [31:0] inst_pc_0,
    input  wire [31:0] inst_0,
    input  wire [ 4:0] areg_rd_0,
    input  wire [ 5:0] new_preg_0,
    input  wire [ 5:0] old_preg_0, 
    input  wire        is_store_0,
    input  wire        is_complex_0,
    input  wire        has_dest_0,

    // --- 指令 1 初始信息 ---
    input  wire [31:0] inst_pc_1,
    input  wire [31:0] inst_1,
    input  wire [ 4:0] areg_rd_1,
    input  wire [ 5:0] new_preg_1,
    input  wire [ 5:0] old_preg_1,
    input  wire        is_store_1,
    input  wire        is_complex_1,
    input  wire        has_dest_1,

    // ==========================================
    // 2. EXE/WB 写回接口
    // ==========================================
    // ALU 0
    input  wire        wb_valid_0,
    input  wire [ 3:0] wb_rob_id_0,
    input  wire        wb_br_miss_0,
    input  wire [31:0] wb_br_target_0,
    input  wire        wb_ex_0,
    input  wire        is_br_0,
    input  wire [1:0]  br_type_0,
    input  wire        wb_br_taken_0,
    // ALU 1
    input  wire        wb_valid_1,
    input  wire [ 3:0] wb_rob_id_1,
    input  wire        wb_br_miss_1,   
    input  wire [31:0] wb_br_target_1,
    input  wire        wb_ex_1,        
    input  wire        is_br_1,        
    input  wire [1:0]  br_type_1,   
    input  wire        wb_br_taken_1,   
    // MEM 写回
    input  wire        wb_valid_2,
    input  wire [ 3:0] wb_rob_id_2,
    input  wire        wb_ex_2,      
    input  wire [128:0]wb_exception_2,
    input  wire         wb_inst_valid_cacop,
    input  wire         wb_inst_tlbsrch,
    input  wire         wb_inst_tlbrd,
    input  wire         wb_inst_tlbwr,
    input  wire         wb_inst_tlbfill,
    input  wire         wb_tlb_hit,
    input  wire [ 4:0]  wb_tlb_index,
    input  wire         wb_inst_sc_w,
    input  wire         wb_inst_ll_w,
    input  wire         wb_mem_we,
    input  wire [31:0]  wb_pa,
    input  wire         wb_uncache_en,
    input  wire         wb_inst_dbar,
    input  wire         wb_inst_ibar,

    // 3. Commit 输出接口
    output wire        commit_done_0,
    output wire [31:0] commit_inst_pc_0,
    output wire [31:0] commit_inst_0,
    output wire        commit_br_miss_0,   
    output wire [31:0] commit_br_target_0,
    output wire        commit_ex_0,        
    output wire [ 4:0] commit_areg_rd_0,
    output wire [ 5:0] commit_new_preg_0,
    output wire [ 5:0] commit_old_preg_0,
    output wire        commit_is_store_0,
    output wire        commit_is_complex_0,
    output wire        commit_has_dest_0,
    output wire        commit_is_br_0,
    output wire [1:0]  commit_br_type_0,
    output wire        commit_br_taken_0,

    output wire        commit_done_1,
    output wire [31:0] commit_inst_pc_1,
    output wire [31:0] commit_inst_1,
    output wire        commit_br_miss_1,   
    output wire [31:0] commit_br_target_1,
    output wire        commit_ex_1,      
    output wire [ 4:0] commit_areg_rd_1,
    output wire [ 5:0] commit_new_preg_1,
    output wire [ 5:0] commit_old_preg_1,
    output wire        commit_is_store_1,
    output wire        commit_is_complex_1,
    output wire        commit_has_dest_1,
    output wire        commit_is_br_1,
    output wire [1:0]  commit_br_type_1,
    output wire        commit_br_taken_1,    
    
    input  wire [ 1:0] commit_pop_cnt,
    output wire [128:0] commit_exception_0,
    output wire [128:0] commit_exception_1,
    output wire        commit_inst_tlbsrch_0,
    output wire        commit_inst_tlbrd_0,
    output wire        commit_inst_tlbwr_0,
    output wire        commit_inst_tlbfill_0,
    output wire        commit_tlb_hit_0,
    output wire [ 4:0] commit_tlb_index_0,
    output wire        commit_inst_tlbsrch_1,
    output wire        commit_inst_tlbrd_1,
    output wire        commit_inst_tlbwr_1,
    output wire        commit_inst_tlbfill_1,
    output wire        commit_tlb_hit_1,
    output wire [ 4:0] commit_tlb_index_1,
    output wire        commit_inst_valid_cacop_0,
    output wire        commit_inst_valid_cacop_1,
    output wire        commit_inst_sc_w_0,
    output wire        commit_inst_ll_w_0,
    output wire [31:0] commit_pa_0,
    output wire        commit_uncache_en_0,
    output wire        commit_inst_dbar_0,
    output wire        commit_inst_ibar_0,
    output wire        commit_inst_sc_w_1,
    output wire        commit_inst_ll_w_1,
    output wire [31:0] commit_pa_1,
    output wire        commit_uncache_en_1,
    output wire        commit_inst_dbar_1,
    output wire        commit_inst_ibar_1,
    output wire [ 3:0] rob_head_id,
    output wire        rob_empty,
    input wire inst_idle_0,
    input wire inst_idle_1,
    output wire commit_idle_0,
    output wire commit_idle_1,
    input  wire        is_load_0,
    input  wire        is_load_1,
    input  wire [31:0] wb_va,
    output wire        commit_is_load_0,
    output wire [31:0] commit_va_0,
    output wire        commit_is_load_1,
    output wire [31:0] commit_va_1,
    input  wire [31:0] ms_store_wdata,
    output wire [31:0] commit_store_wdata_0,
    output wire [31:0] commit_store_wdata_1
);

parameter DEPTH = 16;
localparam ADDR_WD = 4;

// ===================== 无typedef：定义ROB单条目每�?段位宽偏�? =====================
// 低位�?始排布，按顺序分配bit区间
localparam ROB_INST_PC_W     = 32;
localparam ROB_INST_W        = 32;
localparam ROB_AREG_RD_W     = 5;
localparam ROB_NEW_PREG_W    = 6;
localparam ROB_OLD_PREG_W    = 6;
localparam ROB_IS_STORE_W    = 1;
localparam ROB_IS_COMPLEX_W  = 1;
localparam ROB_HAS_DEST_W    = 1;
localparam ROB_IDLE_W        = 1;
localparam ROB_IS_LOAD_W     = 1;
localparam ROB_VA_W          = 32;
localparam ROB_STORE_WDATA_W = 32;

localparam ROB_DONE_W        = 1;
localparam ROB_BR_MISS_W     = 1;
localparam ROB_BR_TARGET_W   = 32;
localparam ROB_EX_W          = 1;
localparam ROB_IS_BR_W       = 1;
localparam ROB_BR_TYPE_W     = 2;
localparam ROB_BR_TAKEN_W    = 1;

localparam ROB_EXCEPTION_W   = 129;
localparam ROB_VALID_CACOP_W = 1;
localparam ROB_TLBSRCH_W     = 1;
localparam ROB_TLBRD_W       = 1;
localparam ROB_TLBWR_W       = 1;
localparam ROB_TLBFILL_W     = 1;
localparam ROB_TLB_HIT_W     = 1;
localparam ROB_TLB_INDEX_W   = 5;
localparam ROB_SC_W_W        = 1;
localparam ROB_LL_W_W        = 1;
localparam ROB_PA_W          = 32;
localparam ROB_UNCACHE_EN_W  = 1;
localparam ROB_DBAR_W        = 1;
localparam ROB_IBAR_W        = 1;

// 计算每一段偏移地�?
localparam OFF_INST_PC     = 0;
localparam OFF_INST        = OFF_INST_PC     + ROB_INST_PC_W;
localparam OFF_AREG_RD     = OFF_INST        + ROB_INST_W;
localparam OFF_NEW_PREG    = OFF_AREG_RD     + ROB_AREG_RD_W;
localparam OFF_OLD_PREG    = OFF_NEW_PREG    + ROB_NEW_PREG_W;
localparam OFF_IS_STORE    = OFF_OLD_PREG    + ROB_OLD_PREG_W;
localparam OFF_IS_COMPLEX  = OFF_IS_STORE    + ROB_IS_STORE_W;
localparam OFF_HAS_DEST    = OFF_IS_COMPLEX  + ROB_IS_COMPLEX_W;
localparam OFF_IDLE        = OFF_HAS_DEST    + ROB_HAS_DEST_W;
localparam OFF_IS_LOAD     = OFF_IDLE        + ROB_IDLE_W;
localparam OFF_VA          = OFF_IS_LOAD     + ROB_IS_LOAD_W;
localparam OFF_STORE_WDATA = OFF_VA          + ROB_VA_W;

localparam OFF_DONE        = OFF_STORE_WDATA + ROB_STORE_WDATA_W;
localparam OFF_BR_MISS     = OFF_DONE        + ROB_DONE_W;
localparam OFF_BR_TARGET   = OFF_BR_MISS     + ROB_BR_MISS_W;
localparam OFF_EX          = OFF_BR_TARGET   + ROB_BR_TARGET_W;
localparam OFF_IS_BR       = OFF_EX          + ROB_EX_W;
localparam OFF_BR_TYPE     = OFF_IS_BR       + ROB_IS_BR_W;
localparam OFF_BR_TAKEN    = OFF_BR_TYPE     + ROB_BR_TYPE_W;

localparam OFF_EXCEPTION   = OFF_BR_TAKEN    + ROB_BR_TAKEN_W;
localparam OFF_VALID_CACOP = OFF_EXCEPTION   + ROB_EXCEPTION_W;
localparam OFF_TLBSRCH     = OFF_VALID_CACOP + ROB_VALID_CACOP_W;
localparam OFF_TLBRD       = OFF_TLBSRCH     + ROB_TLBSRCH_W;
localparam OFF_TLBWR       = OFF_TLBRD       + ROB_TLBRD_W;
localparam OFF_TLBFILL     = OFF_TLBWR       + ROB_TLBWR_W;
localparam OFF_TLB_HIT     = OFF_TLBFILL     + ROB_TLBFILL_W;
localparam OFF_TLB_INDEX   = OFF_TLB_HIT     + ROB_TLB_HIT_W;
localparam OFF_SC_W        = OFF_TLB_INDEX   + ROB_TLB_INDEX_W;
localparam OFF_LL_W        = OFF_SC_W        + ROB_SC_W_W;
localparam OFF_PA          = OFF_LL_W        + ROB_LL_W_W;
localparam OFF_UNCACHE_EN  = OFF_PA          + ROB_PA_W;
localparam OFF_DBAR        = OFF_UNCACHE_EN  + ROB_UNCACHE_EN_W;
localparam OFF_IBAR        = OFF_DBAR        + ROB_DBAR_W;

// 单条ROB条目总位�?
localparam ROB_ENTRY_W = OFF_IBAR + ROB_IBAR_W;

// ===================== 核心优化1：仅1条大位宽数组，删除全部分散mem_xxx =====================
reg [ROB_ENTRY_W-1:0] mem[DEPTH-1:0];

// ===================== 核心优化2：head加max_fanout自动复制分流 =====================
(* max_fanout = 30 *) reg [ADDR_WD:0] head;
reg [ADDR_WD:0] tail;

wire [ADDR_WD:0] count = tail - head;
wire [ADDR_WD:0] space_left = DEPTH - count;
assign rob_free_cnt = (space_left >= 2) ? 2'd2 : (space_left == 1) ? 2'd1 : 2'd0;
assign rob_empty = (count == 0);

wire [ADDR_WD-1:0] tail_idx_0 = tail[ADDR_WD-1:0];
wire [ADDR_WD-1:0] tail_idx_1 = tail[ADDR_WD-1:0] + 1'b1;
assign alloc_rob_id_0 = tail_idx_0;
assign alloc_rob_id_1 = tail_idx_1;

wire [ADDR_WD-1:0] head_idx_0 = head[ADDR_WD-1:0];
wire [ADDR_WD-1:0] head_idx_1 = head[ADDR_WD-1:0] + 1'b1;
assign rob_head_id = head_idx_0;

// ===================== 核心优化3：预读出两路完整条目，仅�?次地�?译码 =====================
wire [ROB_ENTRY_W-1:0] rob_entry0, rob_entry1;
assign rob_entry0 = mem[head_idx_0];
assign rob_entry1 = mem[head_idx_1];

// ===================== Commit输出切片提取，无重复数组选择 =====================
// 0号提�?
assign commit_done_0       = (count >= 1) && rob_entry0[OFF_DONE +: ROB_DONE_W];
assign commit_inst_pc_0    = rob_entry0[OFF_INST_PC +: ROB_INST_PC_W];
assign commit_inst_0       = rob_entry0[OFF_INST +: ROB_INST_W];
assign commit_areg_rd_0    = rob_entry0[OFF_AREG_RD +: ROB_AREG_RD_W];
assign commit_new_preg_0   = rob_entry0[OFF_NEW_PREG +: ROB_NEW_PREG_W];
assign commit_old_preg_0   = rob_entry0[OFF_OLD_PREG +: ROB_OLD_PREG_W];
assign commit_is_store_0   = rob_entry0[OFF_IS_STORE +: ROB_IS_STORE_W];
assign commit_is_complex_0 = rob_entry0[OFF_IS_COMPLEX +: ROB_IS_COMPLEX_W];
assign commit_has_dest_0   = rob_entry0[OFF_HAS_DEST +: ROB_HAS_DEST_W];
assign commit_idle_0       = rob_entry0[OFF_IDLE +: ROB_IDLE_W];
assign commit_is_load_0    = rob_entry0[OFF_IS_LOAD +: ROB_IS_LOAD_W];
assign commit_va_0         = rob_entry0[OFF_VA +: ROB_VA_W];
assign commit_store_wdata_0= rob_entry0[OFF_STORE_WDATA +: ROB_STORE_WDATA_W];

assign commit_br_miss_0    = rob_entry0[OFF_BR_MISS +: ROB_BR_MISS_W];
assign commit_br_target_0  = rob_entry0[OFF_BR_TARGET +: ROB_BR_TARGET_W];
assign commit_ex_0         = rob_entry0[OFF_EX +: ROB_EX_W];
assign commit_is_br_0      = rob_entry0[OFF_IS_BR +: ROB_IS_BR_W];
assign commit_br_type_0    = rob_entry0[OFF_BR_TYPE +: ROB_BR_TYPE_W];
assign commit_br_taken_0   = rob_entry0[OFF_BR_TAKEN +: ROB_BR_TAKEN_W];

assign commit_exception_0        = rob_entry0[OFF_EXCEPTION +: ROB_EXCEPTION_W];
assign commit_inst_valid_cacop_0 = rob_entry0[OFF_VALID_CACOP +: ROB_VALID_CACOP_W];
assign commit_inst_tlbsrch_0     = rob_entry0[OFF_TLBSRCH +: ROB_TLBSRCH_W];
assign commit_inst_tlbrd_0       = rob_entry0[OFF_TLBRD +: ROB_TLBRD_W];
assign commit_inst_tlbwr_0       = rob_entry0[OFF_TLBWR +: ROB_TLBWR_W];
assign commit_inst_tlbfill_0     = rob_entry0[OFF_TLBFILL +: ROB_TLBFILL_W];
assign commit_tlb_hit_0          = rob_entry0[OFF_TLB_HIT +: ROB_TLB_HIT_W];
assign commit_tlb_index_0        = rob_entry0[OFF_TLB_INDEX +: ROB_TLB_INDEX_W];
assign commit_inst_sc_w_0        = rob_entry0[OFF_SC_W +: ROB_SC_W_W];
assign commit_inst_ll_w_0        = rob_entry0[OFF_LL_W +: ROB_LL_W_W];
assign commit_pa_0               = rob_entry0[OFF_PA +: ROB_PA_W];
assign commit_uncache_en_0       = rob_entry0[OFF_UNCACHE_EN +: ROB_UNCACHE_EN_W];
assign commit_inst_dbar_0        = rob_entry0[OFF_DBAR +: ROB_DBAR_W];
assign commit_inst_ibar_0        = rob_entry0[OFF_IBAR +: ROB_IBAR_W];

// 1号提�?
assign commit_done_1       = (count >= 2) && rob_entry1[OFF_DONE +: ROB_DONE_W];
assign commit_inst_pc_1    = rob_entry1[OFF_INST_PC +: ROB_INST_PC_W];
assign commit_inst_1       = rob_entry1[OFF_INST +: ROB_INST_W];
assign commit_areg_rd_1    = rob_entry1[OFF_AREG_RD +: ROB_AREG_RD_W];
assign commit_new_preg_1   = rob_entry1[OFF_NEW_PREG +: ROB_NEW_PREG_W];
assign commit_old_preg_1   = rob_entry1[OFF_OLD_PREG +: ROB_OLD_PREG_W];
assign commit_is_store_1   = rob_entry1[OFF_IS_STORE +: ROB_IS_STORE_W];
assign commit_is_complex_1 = rob_entry1[OFF_IS_COMPLEX +: ROB_IS_COMPLEX_W];
assign commit_has_dest_1   = rob_entry1[OFF_HAS_DEST +: ROB_HAS_DEST_W];
assign commit_idle_1       = rob_entry1[OFF_IDLE +: ROB_IDLE_W];
assign commit_is_load_1    = rob_entry1[OFF_IS_LOAD +: ROB_IS_LOAD_W];
assign commit_va_1         = rob_entry1[OFF_VA +: ROB_VA_W];
assign commit_store_wdata_1= rob_entry1[OFF_STORE_WDATA +: ROB_STORE_WDATA_W];

assign commit_br_miss_1    = rob_entry1[OFF_BR_MISS +: ROB_BR_MISS_W];
assign commit_br_target_1  = rob_entry1[OFF_BR_TARGET +: ROB_BR_TARGET_W];
assign commit_ex_1         = rob_entry1[OFF_EX +: ROB_EX_W];
assign commit_is_br_1      = rob_entry1[OFF_IS_BR +: ROB_IS_BR_W];
assign commit_br_type_1    = rob_entry1[OFF_BR_TYPE +: ROB_BR_TYPE_W];
assign commit_br_taken_1   = rob_entry1[OFF_BR_TAKEN +: ROB_BR_TAKEN_W];

assign commit_exception_1        = rob_entry1[OFF_EXCEPTION +: ROB_EXCEPTION_W];
assign commit_inst_valid_cacop_1 = rob_entry1[OFF_VALID_CACOP +: ROB_VALID_CACOP_W];
assign commit_inst_tlbsrch_1     = rob_entry1[OFF_TLBSRCH +: ROB_TLBSRCH_W];
assign commit_inst_tlbrd_1       = rob_entry1[OFF_TLBRD +: ROB_TLBRD_W];
assign commit_inst_tlbwr_1       = rob_entry1[OFF_TLBWR +: ROB_TLBWR_W];
assign commit_inst_tlbfill_1     = rob_entry1[OFF_TLBFILL +: ROB_TLBFILL_W];
assign commit_tlb_hit_1          = rob_entry1[OFF_TLB_HIT +: ROB_TLB_HIT_W];
assign commit_tlb_index_1        = rob_entry1[OFF_TLB_INDEX +: ROB_TLB_INDEX_W];
assign commit_inst_sc_w_1        = rob_entry1[OFF_SC_W +: ROB_SC_W_W];
assign commit_inst_ll_w_1        = rob_entry1[OFF_LL_W +: ROB_LL_W_W];
assign commit_pa_1               = rob_entry1[OFF_PA +: ROB_PA_W];
assign commit_uncache_en_1       = rob_entry1[OFF_UNCACHE_EN +: ROB_UNCACHE_EN_W];
assign commit_inst_dbar_1        = rob_entry1[OFF_DBAR +: ROB_DBAR_W];
assign commit_inst_ibar_1        = rob_entry1[OFF_IBAR +: ROB_IBAR_W];

// ===================== 组合逻辑：生成Rename写入的完整条目数�? =====================
reg [ROB_ENTRY_W-1:0] w_data0, w_data1;
always @(*) begin
    w_data0 = 365'b0;
    w_data0[OFF_INST_PC     +: ROB_INST_PC_W]    = inst_pc_0;
    w_data0[OFF_INST        +: ROB_INST_W]       = inst_0;
    w_data0[OFF_AREG_RD     +: ROB_AREG_RD_W]    = areg_rd_0;
    w_data0[OFF_NEW_PREG    +: ROB_NEW_PREG_W]   = new_preg_0;
    w_data0[OFF_OLD_PREG    +: ROB_OLD_PREG_W]   = old_preg_0;
    w_data0[OFF_IS_STORE    +: ROB_IS_STORE_W]   = is_store_0;
    w_data0[OFF_IS_COMPLEX  +: ROB_IS_COMPLEX_W] = is_complex_0;
    w_data0[OFF_HAS_DEST    +: ROB_HAS_DEST_W]   = has_dest_0;
    w_data0[OFF_IDLE        +: ROB_IDLE_W]       = inst_idle_0;
    w_data0[OFF_IS_LOAD     +: ROB_IS_LOAD_W]    = is_load_0;
end

always @(*) begin
    w_data1 = 365'b0;
    w_data1[OFF_INST_PC     +: ROB_INST_PC_W]    = inst_pc_1;
    w_data1[OFF_INST        +: ROB_INST_W]       = inst_1;
    w_data1[OFF_AREG_RD     +: ROB_AREG_RD_W]    = areg_rd_1;
    w_data1[OFF_NEW_PREG    +: ROB_NEW_PREG_W]   = new_preg_1;
    w_data1[OFF_OLD_PREG    +: ROB_OLD_PREG_W]   = old_preg_1;
    w_data1[OFF_IS_STORE    +: ROB_IS_STORE_W]   = is_store_1;
    w_data1[OFF_IS_COMPLEX  +: ROB_IS_COMPLEX_W] = is_complex_1;
    w_data1[OFF_HAS_DEST    +: ROB_HAS_DEST_W]   = has_dest_1;
    w_data1[OFF_IDLE        +: ROB_IDLE_W]       = inst_idle_1;
    w_data1[OFF_IS_LOAD     +: ROB_IS_LOAD_W]    = is_load_1;
end

// ===================== 时序逻辑：复�?/写入/更新 =====================
integer i;
always @(posedge clk) begin
    if (reset || flush) begin
        head <= 0;
        tail <= 0;
        for(i=0; i<DEPTH; i=i+1) begin
            mem[i] <= 365'b0; // 整条清零，替代几十行单独赋�??
        end
    end
    else begin
        // 1. Rename分配写入
        if (req_rob_0) begin
            mem[tail_idx_0] <= w_data0;
        end
        if (req_rob_1) begin
            mem[tail_idx_1] <= w_data1;
        end
        tail <= tail + req_rob_0 + req_rob_1;

        // 2. ALU0分支写回更新
        if (wb_valid_0) begin
            mem[wb_rob_id_0][OFF_DONE     +: ROB_DONE_W]      <= 1'b1;
            mem[wb_rob_id_0][OFF_BR_MISS  +: ROB_BR_MISS_W]   <= wb_br_miss_0;
            mem[wb_rob_id_0][OFF_BR_TARGET+: ROB_BR_TARGET_W] <= wb_br_target_0;
            mem[wb_rob_id_0][OFF_EX       +: ROB_EX_W]        <= wb_ex_0;
            mem[wb_rob_id_0][OFF_IS_BR    +: ROB_IS_BR_W]     <= is_br_0;
            mem[wb_rob_id_0][OFF_BR_TYPE  +: ROB_BR_TYPE_W]   <= br_type_0;
            mem[wb_rob_id_0][OFF_BR_TAKEN +: ROB_BR_TAKEN_W]  <= wb_br_taken_0;
        end
        // 3. ALU1分支写回更新
        if (wb_valid_1) begin
            mem[wb_rob_id_1][OFF_DONE     +: ROB_DONE_W]      <= 1'b1;
            mem[wb_rob_id_1][OFF_BR_MISS  +: ROB_BR_MISS_W]   <= wb_br_miss_1;
            mem[wb_rob_id_1][OFF_BR_TARGET+: ROB_BR_TARGET_W] <= wb_br_target_1;
            mem[wb_rob_id_1][OFF_EX       +: ROB_EX_W]        <= wb_ex_1;
            mem[wb_rob_id_1][OFF_IS_BR    +: ROB_IS_BR_W]     <= is_br_1;
            mem[wb_rob_id_1][OFF_BR_TYPE  +: ROB_BR_TYPE_W]   <= br_type_1;
            mem[wb_rob_id_1][OFF_BR_TAKEN +: ROB_BR_TAKEN_W]  <= wb_br_taken_1;
        end
        // 4. MEM写回更新异常/TLB/访存信息
        if (wb_valid_2) begin
            mem[wb_rob_id_2][OFF_DONE             +: ROB_DONE_W]        <= 1'b1;
            mem[wb_rob_id_2][OFF_EX               +: ROB_EX_W]          <= wb_ex_2;
            mem[wb_rob_id_2][OFF_EXCEPTION        +: ROB_EXCEPTION_W]   <= wb_exception_2;
            mem[wb_rob_id_2][OFF_VALID_CACOP      +: ROB_VALID_CACOP_W] <= wb_inst_valid_cacop;
            mem[wb_rob_id_2][OFF_TLBSRCH          +: ROB_TLBSRCH_W]     <= wb_inst_tlbsrch;
            mem[wb_rob_id_2][OFF_TLBRD            +: ROB_TLBRD_W]       <= wb_inst_tlbrd;
            mem[wb_rob_id_2][OFF_TLBWR            +: ROB_TLBWR_W]       <= wb_inst_tlbwr;
            mem[wb_rob_id_2][OFF_TLBFILL          +: ROB_TLBFILL_W]     <= wb_inst_tlbfill;
            mem[wb_rob_id_2][OFF_TLB_HIT          +: ROB_TLB_HIT_W]     <= wb_tlb_hit;
            mem[wb_rob_id_2][OFF_TLB_INDEX        +: ROB_TLB_INDEX_W]   <= wb_tlb_index;
            mem[wb_rob_id_2][OFF_SC_W             +: ROB_SC_W_W]        <= wb_inst_sc_w;
            if (wb_inst_sc_w) begin
                mem[wb_rob_id_2][OFF_IS_STORE     +: ROB_IS_STORE_W]   <= wb_mem_we;
            end
            mem[wb_rob_id_2][OFF_LL_W             +: ROB_LL_W_W]        <= wb_inst_ll_w;
            mem[wb_rob_id_2][OFF_PA               +: ROB_PA_W]          <= wb_pa;
            mem[wb_rob_id_2][OFF_UNCACHE_EN       +: ROB_UNCACHE_EN_W]  <= wb_uncache_en;
            mem[wb_rob_id_2][OFF_DBAR             +: ROB_DBAR_W]        <= wb_inst_dbar;
            mem[wb_rob_id_2][OFF_IBAR             +: ROB_IBAR_W]        <= wb_inst_ibar;
            mem[wb_rob_id_2][OFF_VA               +: ROB_VA_W]          <= wb_va;
            mem[wb_rob_id_2][OFF_STORE_WDATA      +: ROB_STORE_WDATA_W] <= ms_store_wdata;
        end
        // 5. Commit移动头指�?
        head <= head + commit_pop_cnt;
    end
end

// ===================== 性能统计计数器（无改动） =====================
reg [63:0] total_commit_inst_cnt;
always @(posedge clk) begin
    if (reset) begin
        total_commit_inst_cnt <= 64'd0;
    end 
    else begin
        total_commit_inst_cnt <= total_commit_inst_cnt + {62'b0, commit_pop_cnt};
    end
end

reg [63:0] total_br_inst_cnt;
reg [63:0] total_br_miss_cnt;
always @(posedge clk) begin
    if (reset) begin
        total_br_inst_cnt  <= 64'd0;
        total_br_miss_cnt  <= 64'd0;
    end
    else begin
        total_br_inst_cnt <= total_br_inst_cnt 
                             + (((commit_pop_cnt >= 2'd1) && rob_entry0[OFF_IS_BR]) ? 64'd1 : 64'd0)
                             + (((commit_pop_cnt == 2'd2) && rob_entry1[OFF_IS_BR]) ? 64'd1 : 64'd0);

        total_br_miss_cnt <= total_br_miss_cnt 
                             + (((commit_pop_cnt >= 2'd1) && rob_entry0[OFF_IS_BR] && rob_entry0[OFF_BR_MISS]) ? 64'd1 : 64'd0)
                             + (((commit_pop_cnt == 2'd2) && rob_entry1[OFF_IS_BR] && rob_entry1[OFF_BR_MISS]) ? 64'd1 : 64'd0);
    end
end

endmodule