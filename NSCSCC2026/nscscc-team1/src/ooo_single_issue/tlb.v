// ================================================================
//  TLB (Translation Lookaside Buffer) — 地址翻译后备缓冲器
//  
//  功能: 存储虚拟地址→物理地址的翻译条目, 加速地址翻译
//  结构: 16 条目全相联 (Full-Associative)
//        = 查找时, 输入一个虚地址, 同时和 16 个条目并行比较
//  
//  本模块包含 4 个功能:
//    ① 查找 (Search) — 2 个查找端口 (取指 + 数据访存)
//    ② 写入 (Write)  — TLBWR / TLBFILL 指令写入条目
//    ③ 读取 (Read)   — TLBRD 指令读取条目
//    ④ 无效化 (Invalidate) — INVTLB 指令清除条目
// ================================================================

module tlb #(
    parameter TLBNUM = 16  // TLB 条目数量, 可参数化
                           // 龙芯杯比赛一般用 16 条
) (
    input wire clk,
    input wire resetn,

    // ============================================================
    //  查找端口 0 (search port 0) — 用于 取指(IF) 阶段
    //  
    //  输入: 虚拟地址的关键字段 (VPPN, va_bit12, ASID)
    //  输出: 是否命中, 以及命中条目的物理页号和属性
    //
    //  这是纯组合逻辑, 不需要时钟, 输入变化后输出立即变化
    // ============================================================
    input  wire [              18:0] s0_vppn,      // 虚拟双页号 (虚拟地址[31:13])
    input  wire                      s0_va_bit12,  // 虚拟地址的 bit12, 用于选择奇/偶页
    input  wire [               9:0] s0_asid,      // 当前进程的 ASID
    output wire                      s0_found,     // 1=命中 (找到匹配条目)
    output wire [$clog2(TLBNUM)-1:0] s0_index,     // 命中条目的索引号
    output wire [              19:0] s0_ppn,       // 命中条目的物理页号
    output wire [               5:0] s0_ps,        // 命中条目的页大小 (12 或 21)
    output wire [               1:0] s0_plv,       // 命中条目的特权等级
    output wire [               1:0] s0_mat,       // 命中条目的存储访问类型
    output wire                      s0_d,         // 命中条目的脏位
    output wire                      s0_v,         // 命中条目的有效位
    output wire [               8:0] s0_pa_mid,    // PA[20:12]，已根据每个 entry 的 ps4MB 预选好

    // ============================================================
    //  查找端口 1 (s1) — load/store 访存（关键路径）
    // ============================================================
    input  wire [              18:0] s1_vppn,
    input  wire                      s1_va_bit12,
    input  wire [               9:0] s1_asid,
    output wire                      s1_found,
    output wire [$clog2(TLBNUM)-1:0] s1_index,
    output wire [              19:0] s1_ppn,
    output wire [               5:0] s1_ps,
    output wire [               1:0] s1_plv,
    output wire [               1:0] s1_mat,
    output wire                      s1_d,
    output wire                      s1_v,
    output wire [               8:0] s1_pa_mid,    // PA[20:12]，已预选好

    // ============================================================
    //  查找端口 2 (s2) — TLBSRCH 专用
    // ============================================================
    input  wire [              18:0] s2_vppn,
    input  wire [               9:0] s2_asid,
    output wire                      s2_found,
    output wire [$clog2(TLBNUM)-1:0] s2_index,

    // ============================================================
    //  查找端口 3 (s3) — INVTLB 专用
    //  s3_vppn / s3_asid 同时作为 INVTLB 清除条件的输入
    // ============================================================
    input wire [18:0] s3_vppn,
    input wire [ 9:0] s3_asid,

    // ============================================================
    //  INVTLB 端口 — 用于 INVTLB 指令无效化 TLB 条目
    // ============================================================
    input wire       invtlb_valid,  // 1=执行 INVTLB 指令
    input wire [4:0] invtlb_op,     // INVTLB 操作码 (0~6)

    // ============================================================
    //  写端口 — 用于 TLBWR / TLBFILL 指令
    //  
    //  将 CSR 中的内容 (TLBIDX, TLBEHI, TLBELO0/1, ASID) 
    //  写入到 TLB 的第 w_index 条记录中
    // ============================================================
    input wire                      we,       // 写使能 (1=执行写操作)
    input wire [$clog2(TLBNUM)-1:0] w_index,  // 写入哪条记录
    input wire                      w_e,      // 写入的 E 位 (条目是否有效)
    input wire [              18:0] w_vppn,   // 写入的 VPPN
    input wire [               5:0] w_ps,     // 写入的 PS (页大小)
    input wire [               9:0] w_asid,   // 写入的 ASID
    input wire                      w_g,      // 写入的 G 位 (全局位)
    input wire [              19:0] w_ppn0,   // 偶页物理页号
    input wire [               1:0] w_plv0,   // 偶页特权等级
    input wire [               1:0] w_mat0,   // 偶页存储访问类型
    input wire                      w_d0,     // 偶页脏位
    input wire                      w_v0,     // 偶页有效位
    input wire [              19:0] w_ppn1,   // 奇页物理页号
    input wire [               1:0] w_plv1,   // 奇页特权等级
    input wire [               1:0] w_mat1,   // 奇页存储访问类型
    input wire                      w_d1,     // 奇页脏位
    input wire                      w_v1,     // 奇页有效位

    // ============================================================
    //  读端口 — 用于 TLBRD 指令
    //
    //  读取 TLB 的第 r_index 条记录的所有字段
    //  读出的值会写回 CSR (TLBEHI, TLBELO0/1, TLBIDX, ASID)
    // ============================================================
    input  wire [$clog2(TLBNUM)-1:0] r_index,  // 读哪条记录
    output wire                      r_e,      // 读出的 E 位
    output wire [              18:0] r_vppn,   // 读出的 VPPN
    output wire [               5:0] r_ps,     // 读出的 PS
    output wire [               9:0] r_asid,   // 读出的 ASID
    output wire                      r_g,      // 读出的 G 位
    output wire [              19:0] r_ppn0,
    output wire [               1:0] r_plv0,
    output wire [               1:0] r_mat0,
    output wire                      r_d0,
    output wire                      r_v0,
    output wire [              19:0] r_ppn1,
    output wire [               1:0] r_plv1,
    output wire [               1:0] r_mat1,
    output wire                      r_d1,
    output wire                      r_v1
);

    localparam TLB_INDEX_WIDTH = $clog2(TLBNUM);
    localparam SEARCH_PAYLOAD_WIDTH = TLB_INDEX_WIDTH + 20 + 6 + 2 + 2 + 1 + 1;

    // ================================================================
    //  第一部分: TLB 存储体 (Storage Arrays)
    //
    //  把 TLB 的每个字段存成独立的数组。
    //  比如 tlb_vppn[0] ~ tlb_vppn[15] 分别存 16 个条目的 VPPN。
    //
    //  为什么不用一个大的 struct/packed array?
    //  → Verilog-2001 不支持 struct, 逐字段声明是最通用的做法
    //  → 每个字段独立, 读写逻辑更清晰
    // ================================================================

    // --- 公共字段 ---
    reg  [TLBNUM-1:0] tlb_e;  // E (Exist): 条目是否有效
                              //  注意: 这里用 [TLBNUM-1:0] 是一个位向量 (bit vector)
                              //  tlb_e[0] = 条目0的E, tlb_e[1] = 条目1的E, ...
                              //  这样做的好处: 后面 INVTLB 可以用位操作一次清除多个条目

    reg  [TLBNUM-1:0] tlb_ps4MB;  // PS4MB: 页大小标记
                                  //  1 = 4MB 大页 (PS=21)
                                  //  0 = 4KB 普通页 (PS=12)
                                  //  你的设计很聪明: 因为只支持 4KB 和 4MB 两种,
                                  //  用 1 bit 代替 6 bit 的 PS, 节省存储

    reg  [      18:0] tlb_vppn                                                [TLBNUM-1:0];  // VPPN: 虚拟双页号 (各条目独立, 用二维数组)
                                                                                             //  tlb_vppn[0] = 条目0的VPPN (19位)
                                                                                             //  tlb_vppn[1] = 条目1的VPPN (19位) ...

    reg  [       9:0] tlb_asid                                                [TLBNUM-1:0];  // ASID: 地址空间标识符
    reg               tlb_g                                                   [TLBNUM-1:0];  // G: 全局位

    // --- 偶页 (页面0) 字段 ---
    reg  [      19:0] tlb_ppn0                                                [TLBNUM-1:0];  // PPN0: 偶页物理页号
    reg  [       1:0] tlb_plv0                                                [TLBNUM-1:0];  // PLV0: 偶页特权等级
    reg  [       1:0] tlb_mat0                                                [TLBNUM-1:0];  // MAT0: 偶页存储访问类型
    reg               tlb_d0                                                  [TLBNUM-1:0];  // D0: 偶页脏位
    reg               tlb_v0                                                  [TLBNUM-1:0];  // V0: 偶页有效位

    // --- 奇页 (页面1) 字段 ---
    reg  [      19:0] tlb_ppn1                                                [TLBNUM-1:0];
    reg  [       1:0] tlb_plv1                                                [TLBNUM-1:0];
    reg  [       1:0] tlb_mat1                                                [TLBNUM-1:0];
    reg               tlb_d1                                                  [TLBNUM-1:0];
    reg               tlb_v1                                                  [TLBNUM-1:0];


    // ================================================================
    //  第二部分: 查找逻辑 (Search Logic) — 纯组合逻辑
    //
    //  这是 TLB 最核心的功能:
    //    输入一个虚拟地址 → 同时比较 16 个条目 → 输出匹配结果
    //
    //  支持的指令：
    //    TLBSRCH 无操作数。隐式地用 CSR.TLBEHI[VPPN] 和 CSR.ASID[ASID] 作为查找键。
    //            以 CSR.TLBEHI.VPPN 和 CSR.ASID.ASID 为 key，查找 TLB 中的所有条目
    //
    //  分 3 步:
    //    Step 1: 产生 match 向量 (16位, 每bit表示一个条目是否匹配)
    //    Step 2: 从 match 向量中提取命中的条目索引 (优先编码)
    //    Step 3: 根据奇偶页选择, 输出对应页面的物理地址和属性
    // ================================================================

    // --- Step 1: 匹配向量 (Match Vector) ---
    // match0[i] = 1 表示 "第i个条目和查找端口0的输入匹配"
    // match1[i] = 1 表示 "第i个条目和查找端口1的输入匹配"

    wire [TLBNUM-1:0] match0;
    wire [TLBNUM-1:0] match1;
    wire [TLBNUM-1:0] match2;

    wire [SEARCH_PAYLOAD_WIDTH-1:0] s0_entry_payload [TLBNUM-1:0];
    wire [SEARCH_PAYLOAD_WIDTH-1:0] s1_entry_payload [TLBNUM-1:0];
    wire [SEARCH_PAYLOAD_WIDTH-1:0] s0_payload_or;
    wire [SEARCH_PAYLOAD_WIDTH-1:0] s1_payload_or;
    wire [              TLBNUM-1:0] s0_payload_and   [SEARCH_PAYLOAD_WIDTH-1:0];
    wire [              TLBNUM-1:0] s1_payload_and   [SEARCH_PAYLOAD_WIDTH-1:0];
    wire [              TLBNUM-1:0] s2_index_and     [TLB_INDEX_WIDTH-1:0];

    // ================================================================
    //  generate-for 展开后等价于:
    //    assign match0[0]  = (条目0存在) && (ASID匹配或G=1) && (VPPN匹配);
    //    assign match0[1]  = (条目1存在) && (ASID匹配或G=1) && (VPPN匹配);
    //    ...
    //    assign match0[15] = (条目15存在) && (ASID匹配或G=1) && (VPPN匹配);
    //
    //  这 16 个比较是并行执行的 (纯组合逻辑, 同时产生结果)
    //  这就是"全相联"的含义: 所有条目同时比较
    // ================================================================


    // 对每个条目计算: 是否需要被 INVTLB 清除
    wire [TLBNUM-1:0] inv_match;  // inv_match[i]=1 表示第i条要被清除
    genvar i;
    genvar payload_bit;
    genvar payload_entry;
    genvar index_bit;
    genvar index_entry;
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin : match_gen
            // 查找端口 0 的匹配条件:
            // ① tlb_e[i] = 1        → 条目必须有效 (存在)
            // ② ASID 匹配或 G=1     → 属于当前进程, 或是全局映射
            // ③ VPPN 匹配           → 虚拟地址的高位必须相同
            //    - 4MB 大页: 只比较 VPPN[18:9] (高10位)
            //    - 4KB 页:   比较完整 VPPN[18:0] (全部19位)
            wire s0_asid_match = tlb_g[i] || (tlb_asid[i] == s0_asid);
            wire s0_vppn_high_match = (tlb_vppn[i][18:9] == s0_vppn[18:9]);
            wire s0_vppn_low_match = (tlb_vppn[i][8:0] == s0_vppn[8:0]);
            wire s0_vppn_match = s0_vppn_high_match && (tlb_ps4MB[i] || s0_vppn_low_match);

            assign match0[i] = tlb_e[i] && s0_asid_match && s0_vppn_match;

            // 查找端口 1 的匹配条件 (逻辑完全相同, 只是输入信号不同)
            wire s1_asid_match = tlb_g[i] || (tlb_asid[i] == s1_asid);
            wire s1_vppn_high_match = (tlb_vppn[i][18:9] == s1_vppn[18:9]);
            wire s1_vppn_low_match = (tlb_vppn[i][8:0] == s1_vppn[8:0]);
            wire s1_vppn_match = s1_vppn_high_match && (tlb_ps4MB[i] || s1_vppn_low_match);

            assign match1[i] = tlb_e[i] && s1_asid_match && s1_vppn_match;
            assign match2[i] = tlb_e[i] && (tlb_g[i] || (tlb_asid[i] == s2_asid)) && (tlb_ps4MB[i] ? (tlb_vppn[i][18:9] == s2_vppn[18:9]) : (tlb_vppn[i] == s2_vppn));

        end
    endgenerate

    // --- s0_found / s1_found: 是否命中 ---
    // |match0 = 对 match0 的所有 bit 做"或"运算
    // 如果有任何一个 bit 为 1, 结果就是 1 (命中)
    // 如果全是 0, 结果就是 0 (未命中 → 后续会触发 TLB 重填异常)
    assign s0_found = |match0;
    assign s1_found = |match1;
    assign s2_found = |match2;



    // --- Step 2: 优先编码器 — 从 match 向量中提取命中索引 ---
    // ================================================================
    //  match0 是一个 16 位的向量, 比如 16'b0000_0000_0010_0000
    //  我们需要把它转换成索引号 4'd5
    //
    //  方法: 利用 | (按位或) 的特性
    //  因为 TLB 保证同一时刻最多只有一个条目匹配 (操作系统负责保证),
    //  所以 match 向量最多只有一个 bit 为 1。
    //  
    //  我们让每个匹配的条目"贡献"自己的索引号, 然后全部做或运算:
    //    match0[0] ? 4'd0  : 4'd0  → 如果条目0匹配, 贡献0
    //    match0[1] ? 4'd1  : 4'd0  → 如果条目1匹配, 贡献1
    //    match0[5] ? 4'd5  : 4'd0  → 如果条目5匹配, 贡献5
    //    ...
    //  全部或起来, 因为只有一个匹配, 所以结果就是那个匹配的索引号。
    //
    //  举例: 假设 match0 = 16'b0000_0000_0010_0000 (只有bit5=1)
    //    条目5贡献 4'd5 = 4'b0101
    //    其他条目贡献 4'd0 = 4'b0000  
    //    全部 OR: 4'b0101 = 4'd5 ✓
    // ================================================================



    // --- Step 3: 奇偶页选择 & 输出 ---
    // ================================================================
    //  一个 TLB 条目保存一对页面的映射 (偶页 + 奇页):
    //    偶页 = PPN0, PLV0, MAT0, D0, V0
    //    奇页 = PPN1, PLV1, MAT1, D1, V1
    //
    //  如何决定用偶页还是奇页?
    //    4KB 页 (ps4MB=0): 看 va_bit12 (虚拟地址的 bit12)
    //      bit12 = 0 → 偶页 (PPN0)
    //      bit12 = 1 → 奇页 (PPN1)
    //    
    //    4MB 大页 (ps4MB=1): 看 VPPN 的 bit8 (即虚拟地址的 bit21)
    //      因为 4MB 页的页内偏移是 [20:0], 所以区分奇偶的是 bit21
    //      bit21 在 VPPN 中的位置 = VPPN[8] (因为 VPPN = va[31:13])
    //      VPPN[8] = 0 → 偶页
    //      VPPN[8] = 1 → 奇页
    // ================================================================

    // 每个 entry 在本地完成奇偶页选择，随后显式进行匹配位与掩码和归约或。
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin : s0_output_gen
            wire        s0_odd_page;
            wire [19:0] s0_selected_ppn;
            wire [ 1:0] s0_selected_plv;
            wire [ 1:0] s0_selected_mat;
            wire        s0_selected_d;
            wire        s0_selected_v;

            assign s0_odd_page     = tlb_ps4MB[i] ? s0_vppn[8] : s0_va_bit12;
            assign s0_selected_ppn = s0_odd_page ? tlb_ppn1[i] : tlb_ppn0[i];
            assign s0_selected_plv = s0_odd_page ? tlb_plv1[i] : tlb_plv0[i];
            assign s0_selected_mat = s0_odd_page ? tlb_mat1[i] : tlb_mat0[i];
            assign s0_selected_d   = s0_odd_page ? tlb_d1[i] : tlb_d0[i];
            assign s0_selected_v   = s0_odd_page ? tlb_v1[i] : tlb_v0[i];

            assign s0_entry_payload[i] = {
                i[TLB_INDEX_WIDTH-1:0],
                s0_selected_ppn,
                tlb_ps4MB[i] ? 6'd21 : 6'd12,
                s0_selected_plv,
                s0_selected_mat,
                s0_selected_d,
                s0_selected_v
            };
        end
    endgenerate

    // 端口 1 使用与端口 0 对称的 one-hot mask 选择。
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin : s1_output_gen
            wire        s1_odd_page;
            wire [19:0] s1_selected_ppn;
            wire [ 1:0] s1_selected_plv;
            wire [ 1:0] s1_selected_mat;
            wire        s1_selected_d;
            wire        s1_selected_v;

            assign s1_odd_page     = tlb_ps4MB[i] ? s1_vppn[8] : s1_va_bit12;
            assign s1_selected_ppn = s1_odd_page ? tlb_ppn1[i] : tlb_ppn0[i];
            assign s1_selected_plv = s1_odd_page ? tlb_plv1[i] : tlb_plv0[i];
            assign s1_selected_mat = s1_odd_page ? tlb_mat1[i] : tlb_mat0[i];
            assign s1_selected_d   = s1_odd_page ? tlb_d1[i] : tlb_d0[i];
            assign s1_selected_v   = s1_odd_page ? tlb_v1[i] : tlb_v0[i];

            assign s1_entry_payload[i] = {
                i[TLB_INDEX_WIDTH-1:0],
                s1_selected_ppn,
                tlb_ps4MB[i] ? 6'd21 : 6'd12,
                s1_selected_plv,
                s1_selected_mat,
                s1_selected_d,
                s1_selected_v
            };
        end
    endgenerate

    generate
        for (payload_bit = 0; payload_bit < SEARCH_PAYLOAD_WIDTH; payload_bit = payload_bit + 1) begin : search_payload_or_gen
            for (payload_entry = 0; payload_entry < TLBNUM; payload_entry = payload_entry + 1) begin : search_payload_and_gen
                assign s0_payload_and[payload_bit][payload_entry] =
                    match0[payload_entry] & s0_entry_payload[payload_entry][payload_bit];
                assign s1_payload_and[payload_bit][payload_entry] =
                    match1[payload_entry] & s1_entry_payload[payload_entry][payload_bit];
            end

            assign s0_payload_or[payload_bit] = |s0_payload_and[payload_bit];
            assign s1_payload_or[payload_bit] = |s1_payload_and[payload_bit];
        end

        for (index_bit = 0; index_bit < TLB_INDEX_WIDTH; index_bit = index_bit + 1) begin : s2_index_or_gen
            for (index_entry = 0; index_entry < TLBNUM; index_entry = index_entry + 1) begin : s2_index_and_gen
                assign s2_index_and[index_bit][index_entry] =
                    match2[index_entry] & index_entry[index_bit];
            end

            assign s2_index[index_bit] = |s2_index_and[index_bit];
        end
    endgenerate

    assign {
        s0_index,
        s0_ppn,
        s0_ps,
        s0_plv,
        s0_mat,
        s0_d,
        s0_v
    } = s0_payload_or;

    assign {
        s1_index,
        s1_ppn,
        s1_ps,
        s1_plv,
        s1_mat,
        s1_d,
        s1_v
    } = s1_payload_or;

    assign s0_pa_mid = s0_ps[0] ? {s0_vppn[7:0], s0_va_bit12} : s0_ppn[8:0];
    assign s1_pa_mid = s1_ps[0] ? {s1_vppn[7:0], s1_va_bit12} : s1_ppn[8:0];

    // ================================================================
    //  第三部分: 读端口 (Read Port) — 用于 TLBRD 指令
    //
    //  纯组合逻辑: 根据 r_index 直接读出对应条目的所有字段
    //  TLBRD 指令执行时, mycpu_top 会把读出的值写回 CSR
    // ================================================================

    assign r_e       = tlb_e[r_index];
    assign r_vppn    = tlb_vppn[r_index];
    assign r_ps      = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;  // 位标记转回6位PS值
    assign r_asid    = tlb_asid[r_index];
    assign r_g       = tlb_g[r_index];

    assign r_ppn0    = tlb_ppn0[r_index];
    assign r_plv0    = tlb_plv0[r_index];
    assign r_mat0    = tlb_mat0[r_index];
    assign r_d0      = tlb_d0[r_index];
    assign r_v0      = tlb_v0[r_index];

    assign r_ppn1    = tlb_ppn1[r_index];
    assign r_plv1    = tlb_plv1[r_index];
    assign r_mat1    = tlb_mat1[r_index];
    assign r_d1      = tlb_d1[r_index];
    assign r_v1      = tlb_v1[r_index];


    // ================================================================
    //  第四部分: 写端口 (Write Port) — 用于 TLBWR / TLBFILL 指令
    //
    //  在时钟上升沿, 如果 we=1, 把输入数据写入第 w_index 条记录
    //  所有字段一次性写入 (原子操作)
    //
    //  注意: w_ps 是 6 位的(12或21), 需要转换成 1 位的 ps4MB 标记
    // ================================================================

    // --- 写入逻辑 ---
    // 这里使用 generate-for, 因为 tlb_vppn 等是二维数组 [TLBNUM-1:0],
    // 每个元素需要独立控制"是否是当前要写的那条"
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin : write_gen
            always @(posedge clk) begin
                if (we && w_index == i) begin
                    // ↑ 只有写使能=1 且 写索引==当前条目索引i 时才写入

                    // 注意: tlb_e[i] 不在这里赋值!
                    // 因为 INVTLB 也需要写 tlb_e[i] (清除条目)
                    // Verilog 不允许同一个信号在两个 always 块中被赋值
                    // 所以 tlb_e 统一在下面的 e_bit_gen 块中管理

                    tlb_ps4MB[i] <= (w_ps == 6'd21);  // PS==21 → 4MB大页
                    tlb_vppn[i]  <= w_vppn;
                    tlb_asid[i]  <= w_asid;
                    tlb_g[i]     <= w_g;

                    tlb_ppn0[i]  <= w_ppn0;
                    tlb_plv0[i]  <= w_plv0;
                    tlb_mat0[i]  <= w_mat0;
                    tlb_d0[i]    <= w_d0;
                    tlb_v0[i]    <= w_v0;

                    tlb_ppn1[i]  <= w_ppn1;
                    tlb_plv1[i]  <= w_plv1;
                    tlb_mat1[i]  <= w_mat1;
                    tlb_d1[i]    <= w_d1;
                    tlb_v1[i]    <= w_v1;
                end
            end
        end
    endgenerate


    // ================================================================
    //  第五部分: INVTLB (Invalidate TLB) — 无效化 TLB 条目
    //
    //  INVTLB 指令用于清除指定的 TLB 条目 (把 E 位置 0)
    //  不同的操作码 (invtlb_op) 有不同的清除策略
    //
    //  INVTLB 使用查找端口1的输入信号 (s1_vppn, s1_asid) 作为匹配条件:
    //    s1_asid = 通用寄存器 rj 的值 (要匹配的 ASID)
    //    s1_vppn = 通用寄存器 rk 的值的高位 (要匹配的 VPPN)
    //
    //  操作码详解:
    //    op=0: 清除所有条目 (不管条件)
    //    op=1: 清除所有条目 (同op=0)
    //    op=2: 清除所有 G=1 的条目 (全局映射)
    //    op=3: 清除所有 G=0 的条目 (非全局映射, 即进程私有映射)
    //    op=4: 清除 G=0 且 ASID 匹配的条目 (某个进程的所有映射)
    //    op=5: 清除 G=0 且 ASID 匹配 且 VPPN 匹配的条目 (精确清除某一条)
    //    op=6: 清除 (G=1 或 ASID匹配) 且 VPPN 匹配的条目
    //
    //  实现方式: 
    //    对每个条目, 判断它是否满足清除条件
    //    满足的条目, 把 tlb_e[i] 置为 0 (标记为无效)
    //    只需要清 E 位即可, 其他字段不用管 (E=0后查找不会匹配)
    // ================================================================


    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin : inv_gen

            // 各 op 下, 第 i 条是否满足清除条件:
            wire cond_asid_match = (tlb_asid[i] == s3_asid);  // ASID 匹配
            wire cond_vppn_match = tlb_ps4MB[i] ? (tlb_vppn[i][18:9] == s3_vppn[18:9])  // 4MB: 只比高10位
 : (tlb_vppn[i] == s3_vppn);  // 4KB: 比全部19位

            assign inv_match[i] = (invtlb_op == 5'd0 || invtlb_op == 5'd1)  // op 0,1: 清除所有
                || (invtlb_op == 5'd2 && tlb_g[i])  // op 2: G=1
                || (invtlb_op == 5'd3 && !tlb_g[i])  // op 3: G=0
                || (invtlb_op == 5'd4 && !tlb_g[i] && cond_asid_match)  // op 4: G=0 且 ASID匹配
                || (invtlb_op == 5'd5 && !tlb_g[i] && cond_asid_match && cond_vppn_match)  // op 5: G=0 且 ASID+VPPN匹配
                || (invtlb_op == 5'd6 && (tlb_g[i] || cond_asid_match) && cond_vppn_match);  // op 6: (G=1或ASID匹配) 且 VPPN匹配

        end
    endgenerate

    // 执行清除: 在时钟上升沿, 如果 invtlb_valid=1, 把匹配的条目 E 位清零
    // ================================================================
    //  注意: 这里对 tlb_e 的写可能和第四部分的 write_gen 冲突
    //  (都在写 tlb_e[i])
    //  但实际上, INVTLB 和 TLBWR/TLBFILL 不会在同一拍同时执行
    //  (ctrl.v 保证一条指令只会触发一个操作)
    //  所以在实际使用中不会冲突
    //
    //  但为了综合工具不报 warning, 我们把 E 位的写入统一到一个 always 块:
    //  上面 write_gen 中的 tlb_e 赋值需要移除, 改为在这里统一处理
    // ================================================================

    // 重新组织 tlb_e 的写入逻辑 (统一管理, 避免多个 always 驱动同一个信号)
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin : e_bit_gen
            always @(posedge clk) begin
                if (!resetn) begin
                    tlb_e[i] <= 1'b0;  // 复位时所有条目无效
                end else if (invtlb_valid && inv_match[i]) tlb_e[i] <= 1'b0;  // INVTLB 清除
                else if (we && w_index == i) tlb_e[i] <= w_e;  // TLBWR/TLBFILL 写入
            end
        end
    endgenerate

endmodule
