`include "l2_cache_defs.vh"

module l2_replace (
    input wire clk,
    input wire resetn,

    // 与 L2 Tag Array 使用相同的逐组初始化过程。
    input wire init_valid,
    input wire [`L2_INDEX_WIDTH-1:0] init_index,

    input wire valid_way0,
    input wire valid_way1,
    input wire valid_way2,
    input wire valid_way3,

    // Cache Hit：将命中 Line 提升到 RRPV=0。
    input wire hit_valid,
    input wire [`L2_INDEX_WIDTH-1:0] hit_index,
    input wire [`L2_WAY_WIDTH-1:0] hit_way,

    // Cache Fill：执行插入和 Aging。
    input wire fill_valid,
    input wire [`L2_INDEX_WIDTH-1:0] fill_index,
    input wire [`L2_WAY_WIDTH-1:0] fill_way,
    input wire fill_victim_invalid,
    input wire fill_low_priority,

    // 仅 Demand Miss 用于 Set Dueling 训练。
    input wire train_valid,

    // Victim selection
    input wire [`L2_INDEX_WIDTH-1:0] victim_index,

    output wire [`L2_WAY_WIDTH-1:0] victim_way,
    output wire victim_is_invalid
);

localparam [1:0] RRPV_NEAR =
    2'd0;

localparam [1:0] RRPV_SRRIP_INSERT =
    2'd2;

localparam [1:0] RRPV_MAX =
    2'd3;

localparam integer PSEL_WIDTH = 10;

localparam [PSEL_WIDTH-1:0] PSEL_MAX =
    {PSEL_WIDTH{1'b1}};

// 初始略微偏向 SRRIP。
localparam [PSEL_WIDTH-1:0] PSEL_INIT =
    10'd511;


// ============================================================
// Per-line RRPV and per-set rotating tie-break pointer
// ============================================================

reg [1:0] rrpv_way0_r [0:`L2_SETS-1];
reg [1:0] rrpv_way1_r [0:`L2_SETS-1];
reg [1:0] rrpv_way2_r [0:`L2_SETS-1];
reg [1:0] rrpv_way3_r [0:`L2_SETS-1];

// 多个 Way 的 RRPV 相同时，使用旋转指针消除固定 Way 偏置。
reg [`L2_WAY_WIDTH-1:0]
    victim_ptr_r [0:`L2_SETS-1];


// ============================================================
// Set-dueling state
// ============================================================

// SRRIP Leader miss：PSEL 增加，Follower 更倾向 BRRIP。
// BRRIP Leader miss：PSEL 减少，Follower 更倾向 SRRIP。
reg [PSEL_WIDTH-1:0] psel_r;

// BRRIP 1/32 插入概率计数器。
reg [4:0] brrip_counter_r;


// ============================================================
// Victim selection wires
// ============================================================

wire [1:0] victim_rrpv0_w;
wire [1:0] victim_rrpv1_w;
wire [1:0] victim_rrpv2_w;
wire [1:0] victim_rrpv3_w;

wire [1:0] victim_max01_w;
wire [1:0] victim_max23_w;
wire [1:0] victim_max_rrpv_w;

wire [`L2_WAY_WIDTH-1:0] victim_ptr_w;
wire [`L2_WAY_WIDTH-1:0] rrip_victim_way_w;


// ============================================================
// Fill update wires
// ============================================================

// fill 拍先把 RRPV 和上下文捕获到小寄存器，
// 下一拍再做 max/aging/饱和加并写回 RRPV 数组，
// 切断 "动态数组读 -> 比较 -> 饱和加 -> 数组写回" 的长路径。
reg fill_update_valid_r;
reg [`L2_INDEX_WIDTH-1:0] fill_update_index_r;
reg [`L2_WAY_WIDTH-1:0] fill_update_way_r;
reg fill_update_victim_invalid_r;
reg [1:0] fill_rrpv0_r;
reg [1:0] fill_rrpv1_r;
reg [1:0] fill_rrpv2_r;
reg [1:0] fill_rrpv3_r;
reg [1:0] fill_insert_rrpv_r;

wire [1:0] fill_max01_w;
wire [1:0] fill_max23_w;
wire [1:0] fill_max_rrpv_w;

wire [1:0] fill_age_amount_w;

wire [1:0] fill_aged_rrpv0_w;
wire [1:0] fill_aged_rrpv1_w;
wire [1:0] fill_aged_rrpv2_w;
wire [1:0] fill_aged_rrpv3_w;


// ============================================================
// Set-dueling wires
// ============================================================

wire [4:0] fill_set_hash_w;

wire fill_is_srrip_leader_w;
wire fill_is_brrip_leader_w;

wire follower_use_brrip_w;
wire fill_use_brrip_w;

wire [1:0] brrip_insert_rrpv_w;
wire [1:0] fill_insert_rrpv_w;


// ============================================================
// Saturating RRPV addition
// ============================================================

function [1:0] sat_add_rrpv;
    input [1:0] value;
    input [1:0] increment;

    reg [2:0] sum;

    begin
        sum =
            {1'b0, value} +
            {1'b0, increment};

        sat_add_rrpv =
            sum[2] ?
            RRPV_MAX :
            sum[1:0];
    end
endfunction


// ============================================================
// Rotating tie-break selection
// ============================================================

// 从 start_way 开始循环搜索第一个最大 RRPV 候选。
function [`L2_WAY_WIDTH-1:0] choose_rrip_victim;
    input [`L2_WAY_WIDTH-1:0] start_way;

    input [1:0] rrpv0;
    input [1:0] rrpv1;
    input [1:0] rrpv2;
    input [1:0] rrpv3;

    input [1:0] max_rrpv;

    begin
        case(start_way)
            2'd0: begin
                if(rrpv0 == max_rrpv)
                    choose_rrip_victim = 2'd0;
                else if(rrpv1 == max_rrpv)
                    choose_rrip_victim = 2'd1;
                else if(rrpv2 == max_rrpv)
                    choose_rrip_victim = 2'd2;
                else
                    choose_rrip_victim = 2'd3;
            end

            2'd1: begin
                if(rrpv1 == max_rrpv)
                    choose_rrip_victim = 2'd1;
                else if(rrpv2 == max_rrpv)
                    choose_rrip_victim = 2'd2;
                else if(rrpv3 == max_rrpv)
                    choose_rrip_victim = 2'd3;
                else
                    choose_rrip_victim = 2'd0;
            end

            2'd2: begin
                if(rrpv2 == max_rrpv)
                    choose_rrip_victim = 2'd2;
                else if(rrpv3 == max_rrpv)
                    choose_rrip_victim = 2'd3;
                else if(rrpv0 == max_rrpv)
                    choose_rrip_victim = 2'd0;
                else
                    choose_rrip_victim = 2'd1;
            end

            default: begin
                if(rrpv3 == max_rrpv)
                    choose_rrip_victim = 2'd3;
                else if(rrpv0 == max_rrpv)
                    choose_rrip_victim = 2'd0;
                else if(rrpv1 == max_rrpv)
                    choose_rrip_victim = 2'd1;
                else
                    choose_rrip_victim = 2'd2;
            end
        endcase
    end
endfunction


// ============================================================
// Victim selection
// ============================================================

assign victim_is_invalid =
    !valid_way0 ||
    !valid_way1 ||
    !valid_way2 ||
    !valid_way3;

assign victim_rrpv0_w =
    rrpv_way0_r[victim_index];

assign victim_rrpv1_w =
    rrpv_way1_r[victim_index];

assign victim_rrpv2_w =
    rrpv_way2_r[victim_index];

assign victim_rrpv3_w =
    rrpv_way3_r[victim_index];

assign victim_ptr_w =
    victim_ptr_r[victim_index];

assign victim_max01_w =
    (victim_rrpv0_w >= victim_rrpv1_w) ?
    victim_rrpv0_w :
    victim_rrpv1_w;

assign victim_max23_w =
    (victim_rrpv2_w >= victim_rrpv3_w) ?
    victim_rrpv2_w :
    victim_rrpv3_w;

assign victim_max_rrpv_w =
    (victim_max01_w >= victim_max23_w) ?
    victim_max01_w :
    victim_max23_w;

// 如果当前不存在 RRPV=3，选择当前最大 RRPV。
// Fill 阶段会一次性完成等价 Aging。
assign rrip_victim_way_w =
    choose_rrip_victim(
        victim_ptr_w,
        victim_rrpv0_w,
        victim_rrpv1_w,
        victim_rrpv2_w,
        victim_rrpv3_w,
        victim_max_rrpv_w
    );

assign victim_way =
    !valid_way0 ? 2'd0 :
    !valid_way1 ? 2'd1 :
    !valid_way2 ? 2'd2 :
    !valid_way3 ? 2'd3 :
                  rrip_victim_way_w;


// ============================================================
// Fill-time Aging
// ============================================================

// 输入改为上一拍捕获的 RRPV 寄存器，
// 不再在本拍动态读 rrpv_way*_r[fill_index]。
assign fill_max01_w =
    (fill_rrpv0_r >= fill_rrpv1_r) ?
    fill_rrpv0_r :
    fill_rrpv1_r;

assign fill_max23_w =
    (fill_rrpv2_r >= fill_rrpv3_r) ?
    fill_rrpv2_r :
    fill_rrpv3_r;

assign fill_max_rrpv_w =
    (fill_max01_w >= fill_max23_w) ?
    fill_max01_w :
    fill_max23_w;

// 使用 Invalid Way 时不需要 Aging。
// 替换有效 Way 时，将当前最大 RRPV 提升到 3。
assign fill_age_amount_w =
    fill_update_victim_invalid_r ?
    2'd0 :
    (RRPV_MAX - fill_max_rrpv_w);

assign fill_aged_rrpv0_w =
    sat_add_rrpv(
        fill_rrpv0_r,
        fill_age_amount_w
    );

assign fill_aged_rrpv1_w =
    sat_add_rrpv(
        fill_rrpv1_r,
        fill_age_amount_w
    );

assign fill_aged_rrpv2_w =
    sat_add_rrpv(
        fill_rrpv2_r,
        fill_age_amount_w
    );

assign fill_aged_rrpv3_w =
    sat_add_rrpv(
        fill_rrpv3_r,
        fill_age_amount_w
    );


// ============================================================
// Set Dueling
// ============================================================

// index[8:5] XOR index[4:0]。
//
// Hash=0：16 个 SRRIP Leader Sets。
// Hash=31：16 个 BRRIP Leader Sets。
// 其余 480 个 Set 为 Follower Sets。
assign fill_set_hash_w =
    fill_index[4:0] ^
    {1'b0, fill_index[8:5]};

assign fill_is_srrip_leader_w =
    fill_set_hash_w == 5'd0;

assign fill_is_brrip_leader_w =
    fill_set_hash_w == 5'd31;

assign follower_use_brrip_w =
    psel_r[PSEL_WIDTH-1];

assign fill_use_brrip_w =
    fill_is_brrip_leader_w ||
    (
        !fill_is_srrip_leader_w &&
        follower_use_brrip_w
    );

// BRRIP：
// 1/32 插入为 RRPV=2。
// 31/32 插入为 RRPV=3。
assign brrip_insert_rrpv_w =
    (brrip_counter_r == 5'd0) ?
    RRPV_SRRIP_INSERT :
    RRPV_MAX;

assign fill_insert_rrpv_w =
    fill_low_priority ?
    RRPV_MAX :
    fill_use_brrip_w ?
    brrip_insert_rrpv_w :
    RRPV_SRRIP_INSERT;


// ============================================================
// Sequential update
// ============================================================

always @(posedge clk) begin
    if(!resetn) begin
        psel_r <= PSEL_INIT;
        brrip_counter_r <= 5'd0;
        fill_update_valid_r <= 1'b0;
    end else begin

        // L2 原有 Reset Scan 逐组初始化。
        if(init_valid) begin
            rrpv_way0_r[init_index] <= RRPV_MAX;
            rrpv_way1_r[init_index] <= RRPV_MAX;
            rrpv_way2_r[init_index] <= RRPV_MAX;
            rrpv_way3_r[init_index] <= RRPV_MAX;

            victim_ptr_r[init_index] <=
                {`L2_WAY_WIDTH{1'b0}};
        end else if(hit_valid) begin
            case(hit_way)
                2'd0: begin
                    rrpv_way0_r[hit_index] <=
                        RRPV_NEAR;
                end

                2'd1: begin
                    rrpv_way1_r[hit_index] <=
                        RRPV_NEAR;
                end

                2'd2: begin
                    rrpv_way2_r[hit_index] <=
                        RRPV_NEAR;
                end

                default: begin
                    rrpv_way3_r[hit_index] <=
                        RRPV_NEAR;
                end
            endcase
        end else if(fill_update_valid_r) begin
            fill_update_valid_r <= 1'b0;

            // 下一次从本次 Fill Way 的下一个 Way
            // 开始搜索并列 Victim。
            victim_ptr_r[fill_update_index_r] <=
                fill_update_way_r + 2'd1;

            case(fill_update_way_r)
                2'd0: begin
                    rrpv_way0_r[fill_update_index_r] <=
                        fill_insert_rrpv_r;

                    rrpv_way1_r[fill_update_index_r] <=
                        fill_aged_rrpv1_w;

                    rrpv_way2_r[fill_update_index_r] <=
                        fill_aged_rrpv2_w;

                    rrpv_way3_r[fill_update_index_r] <=
                        fill_aged_rrpv3_w;
                end

                2'd1: begin
                    rrpv_way0_r[fill_update_index_r] <=
                        fill_aged_rrpv0_w;

                    rrpv_way1_r[fill_update_index_r] <=
                        fill_insert_rrpv_r;

                    rrpv_way2_r[fill_update_index_r] <=
                        fill_aged_rrpv2_w;

                    rrpv_way3_r[fill_update_index_r] <=
                        fill_aged_rrpv3_w;
                end

                2'd2: begin
                    rrpv_way0_r[fill_update_index_r] <=
                        fill_aged_rrpv0_w;

                    rrpv_way1_r[fill_update_index_r] <=
                        fill_aged_rrpv1_w;

                    rrpv_way2_r[fill_update_index_r] <=
                        fill_insert_rrpv_r;

                    rrpv_way3_r[fill_update_index_r] <=
                        fill_aged_rrpv3_w;
                end

                default: begin
                    rrpv_way0_r[fill_update_index_r] <=
                        fill_aged_rrpv0_w;

                    rrpv_way1_r[fill_update_index_r] <=
                        fill_aged_rrpv1_w;

                    rrpv_way2_r[fill_update_index_r] <=
                        fill_aged_rrpv2_w;

                    rrpv_way3_r[fill_update_index_r] <=
                        fill_insert_rrpv_r;
                end
            endcase
        end

        // fill 拍只做捕获：动态读 RRPV 数组到小寄存器，
        // 实际 aging 计算和写回在下一拍完成。
        if(fill_valid) begin
            fill_update_valid_r <= 1'b1;
            fill_update_index_r <= fill_index;
            fill_update_way_r <= fill_way;
            fill_update_victim_invalid_r <= fill_victim_invalid;
            fill_rrpv0_r <= rrpv_way0_r[fill_index];
            fill_rrpv1_r <= rrpv_way1_r[fill_index];
            fill_rrpv2_r <= rrpv_way2_r[fill_index];
            fill_rrpv3_r <= rrpv_way3_r[fill_index];
            fill_insert_rrpv_r <= fill_insert_rrpv_w;
        end

        // 只使用 I-cache / D-cache Demand Miss 训练 PSEL。
        //
        // SRRIP Leader Miss：
        // SRRIP 表现较差，PSEL 增加。
        if(train_valid &&
           fill_is_srrip_leader_w) begin
            if(psel_r != PSEL_MAX) begin
                psel_r <=
                    psel_r +
                    {{(PSEL_WIDTH-1){1'b0}}, 1'b1};
            end
        end else if(train_valid &&
                    fill_is_brrip_leader_w) begin
            // BRRIP Leader Miss：
            // BRRIP 表现较差，PSEL 减少。
            if(psel_r != {PSEL_WIDTH{1'b0}}) begin
                psel_r <=
                    psel_r -
                    {{(PSEL_WIDTH-1){1'b0}}, 1'b1};
            end
        end

        // BRRIP 的概率只统计实际使用 BRRIP 的 Fill。
        if(fill_valid &&
           !fill_low_priority &&
           fill_use_brrip_w) begin
            brrip_counter_r <=
                brrip_counter_r + 5'd1;
        end
    end
end

endmodule
