// =============================================================================
// 双查询端口、组相联 LoongArch TLB
// =============================================================================
// 默认容量为 16 项，组织为 4 组 x 4 路。每个 TLB 项描述一对相邻的偶/奇页，
// 共享 E、VPPN、PS、ASID、G，并分别保存 PPN/PLV/MAT/D/V 两套页属性。
// 支持 4 KiB（PS=12）和 4 MiB（PS=21）两种页大小。
//
// s0 供取指、s1 供数据访问/TLBSRCH。比较在组合逻辑中完成，匹配结果和查询
// 地址在时钟沿锁存，因此输出是“一拍查询”结果。s0_en 可在前端反压时保持
// 已有结果；s1 每拍采样。读写端口供 TLBRD/TLBWR/TLBFILL，INVTLB 可按操作码
// 批量清除 E 位。若多个条目异常地同时命中，编码器稳定选择较小组/较小路。
// =============================================================================
module tlb
  #(
     parameter TLBNUM = 16,              // TLB 条目总数，需为 NWAY*NSET。
     parameter NWAY   = 4,               // 每组路数；当前优先编码逻辑按 4 路展开。
     parameter NSET   = TLBNUM / NWAY   // 组数，默认 4。
   )
   (
     input  wire                         clk,
     input  wire                         reset,

     // 查询端口 0（取指）：s0_en=1 时在本拍比较、下个上升沿锁存结果。
     input  wire                         s0_en,
     input  wire [18:0]                  s0_vppn,
     input  wire                         s0_va_bit12,
     input  wire [9:0]                   s0_asid,
     output wire                         s0_found,
     output wire [$clog2(TLBNUM)-1:0]    s0_index,
     output wire [19:0]                  s0_ppn,
     output wire [5:0]                   s0_ps,
     output wire [1:0]                   s0_plv,
     output wire [1:0]                   s0_mat,
     output wire                         s0_d,
     output wire                         s0_v,

     // 查询端口 1（load/store 与 TLBSRCH 复用）：每拍都推进查询结果。
     input  wire [18:0]                  s1_vppn,
     input  wire                         s1_va_bit12,
     input  wire [9:0]                   s1_asid,
     output wire                         s1_found,
     output wire [$clog2(TLBNUM)-1:0]    s1_index,
     output wire [19:0]                  s1_ppn,
     output wire [5:0]                   s1_ps,
     output wire [1:0]                   s1_plv,
     output wire [1:0]                   s1_mat,
     output wire                         s1_d,
     output wire                         s1_v,

     // INVTLB：valid 在一个上升沿清除所有符合 op/asid/vppn 条件的条目。
     input  wire [4:0]                   invtlb_op,
     input  wire                         invtlb_valid,
     input  wire [18:0]                  invtlb_vppn,
     input  wire [9:0]                   invtlb_asid,

     // 单条目写端口：w_index 的高位选路、低位选组，字段来自 TLB 相关 CSR。
     input  wire                         we,
     input  wire [$clog2(TLBNUM)-1:0]    w_index,
     input  wire                         w_e,
     input  wire [18:0]                  w_vppn,
     input  wire [5:0]                   w_ps,
     input  wire [9:0]                   w_asid,
     input  wire                         w_g,
     input  wire [19:0]                  w_ppn0,
     input  wire [1:0]                   w_plv0,
     input  wire [1:0]                   w_mat0,
     input  wire                         w_d0,
     input  wire                         w_v0,
     input  wire [19:0]                  w_ppn1,
     input  wire [1:0]                   w_plv1,
     input  wire [1:0]                   w_mat1,
     input  wire                         w_d1,
     input  wire                         w_v1,

     // 单条目异步读端口：供 TLBRD 将所选条目字段回填 CSR。
     input  wire [$clog2(TLBNUM)-1:0]    r_index,
     output wire                         r_e,
     output wire [18:0]                  r_vppn,
     output wire [5:0]                   r_ps,
     output wire [9:0]                   r_asid,
     output wire                         r_g,
     output wire [19:0]                  r_ppn0,
     output wire [1:0]                   r_plv0,
     output wire [1:0]                   r_mat0,
     output wire                         r_d0,
     output wire                         r_v0,
     output wire [19:0]                  r_ppn1,
     output wire [1:0]                   r_plv1,
     output wire [1:0]                   r_mat1,
     output wire                         r_d1,
     output wire                         r_v1
   );

  // 顶层复位由时钟寄存器产生。若由其直接驱动每个 TLB 状态位，
  // 会形成很长的高扇出同步复位路径。此处的局部流水级用于隔离该路径；
  // 综合工具可在各 TLB 存储体附近复制局部复位树。新增的一拍仅出现在
  // 架构复位期间，因此稳态 IPC 不变。
  (* max_fanout = 32 *) reg reset_tlb = 1'b1;
  always @(posedge clk)
    reset_tlb <= reset;

  // 扁平 index 编码为 {way,set}。默认配置下均为 2 位，组合后得到 4 位索引。
  localparam IDX_W = $clog2(TLBNUM);
  localparam WAY_W = $clog2(NWAY);
  localparam SET_W = $clog2(NSET);

  wire [SET_W-1:0] w_set = w_index[SET_W-1:0];
  wire [WAY_W-1:0] w_way = w_index[IDX_W-1:SET_W];
  wire [SET_W-1:0] r_set = r_index[SET_W-1:0];
  wire [WAY_W-1:0] r_way = r_index[IDX_W-1:SET_W];

  // ============================================================
  // 存储寄存器（组相联：NSET 组 × NWAY 路）
  // ============================================================
  reg  [NWAY-1:0] tlb_e    [NSET-1:0];   // 条目存在位；INVTLB 仅需清除此位。
  reg  [NWAY-1:0] tlb_ps4MB [NSET-1:0];  // 压缩页大小：1=4 MiB，0=4 KiB。

  reg  [18:0] tlb_vppn [NWAY-1:0][NSET-1:0];  // 虚双页号，[路][组]。
  reg  [9:0]  tlb_asid [NWAY-1:0][NSET-1:0];  // 地址空间标识。
  reg         tlb_g    [NWAY-1:0][NSET-1:0];  // 全局项；为 1 时忽略 ASID。
  reg  [19:0] tlb_ppn0 [NWAY-1:0][NSET-1:0];
  reg  [1:0]  tlb_plv0 [NWAY-1:0][NSET-1:0];
  reg  [1:0]  tlb_mat0 [NWAY-1:0][NSET-1:0];
  reg         tlb_d0   [NWAY-1:0][NSET-1:0];
  reg         tlb_v0   [NWAY-1:0][NSET-1:0];
  reg  [19:0] tlb_ppn1 [NWAY-1:0][NSET-1:0];
  reg  [1:0]  tlb_plv1 [NWAY-1:0][NSET-1:0];
  reg  [1:0]  tlb_mat1 [NWAY-1:0][NSET-1:0];
  reg         tlb_d1   [NWAY-1:0][NSET-1:0];
  reg         tlb_v1   [NWAY-1:0][NSET-1:0];

  // ============================================================
  // 匹配比较逻辑（每组每路）
  // ============================================================
  // 4 MiB 页只比较 VPPN[18:9]，低 9 位落在大页页内；4 KiB 页比较完整 VPPN。
  // G=1 表示跨 ASID 共享，否则查询 ASID 必须相等。页的 V/D/PLV 属性不参与
  // “找到条目”的判断，而是在 CPU_top 中用于产生 PIF/PIL/PIS/PPI/PME 异常。
  wire [NWAY-1:0] match0_way [NSET-1:0];
  wire [NWAY-1:0] match1_way [NSET-1:0];

  genvar gi, gj;
  generate
    for (gi = 0; gi < NSET; gi = gi + 1)
    begin : set_loop
      for (gj = 0; gj < NWAY; gj = gj + 1)
      begin : way_loop
        assign match0_way[gi][gj] = tlb_e[gi][gj]
               && (s0_vppn[18:9] == tlb_vppn[gj][gi][18:9])
               && (tlb_ps4MB[gi][gj] || (s0_vppn[8:0] == tlb_vppn[gj][gi][8:0]))
               && ((s0_asid == tlb_asid[gj][gi]) || tlb_g[gj][gi]);

        assign match1_way[gi][gj] = tlb_e[gi][gj]
               && (s1_vppn[18:9] == tlb_vppn[gj][gi][18:9])
               && (tlb_ps4MB[gi][gj] || (s1_vppn[8:0] == tlb_vppn[gj][gi][8:0]))
               && ((s1_asid == tlb_asid[gj][gi]) || tlb_g[gj][gi]);
      end
    end
  endgenerate

  // ============================================================
  // 组内优先级编码（每组找到第一个命中的路）
  // ============================================================
  // 当前实现显式展开 way0..way3，优先级为 0 > 1 > 2 > 3。正常软件应保证
  // 同一 VPPN/ASID 只有一个有效项；确定优先级主要用于防御重复项和稳定仿真。
  reg  [WAY_W-1:0] hit_way_s0 [NSET-1:0];
  reg        set_hit_s0 [NSET-1:0];
  reg  [WAY_W-1:0] hit_way_s1 [NSET-1:0];
  reg        set_hit_s1 [NSET-1:0];

  integer i;
  integer j;
  always @(*)
  begin
    for (i = 0; i < NSET; i = i + 1)
    begin
      hit_way_s0[i] = 2'd0;
      set_hit_s0[i] = 1'b0;
      if (match0_way[i][0])
      begin
        hit_way_s0[i] = 2'd0;
        set_hit_s0[i] = 1'b1;
      end
      else if (match0_way[i][1])
      begin
        hit_way_s0[i] = 2'd1;
        set_hit_s0[i] = 1'b1;
      end
      else if (match0_way[i][2])
      begin
        hit_way_s0[i] = 2'd2;
        set_hit_s0[i] = 1'b1;
      end
      else if (match0_way[i][3])
      begin
        hit_way_s0[i] = 2'd3;
        set_hit_s0[i] = 1'b1;
      end
    end
  end

  always @(*)
  begin
    for (i = 0; i < NSET; i = i + 1)
    begin
      hit_way_s1[i] = 2'd0;
      set_hit_s1[i] = 1'b0;
      if (match1_way[i][0])
      begin
        hit_way_s1[i] = 2'd0;
        set_hit_s1[i] = 1'b1;
      end
      else if (match1_way[i][1])
      begin
        hit_way_s1[i] = 2'd1;
        set_hit_s1[i] = 1'b1;
      end
      else if (match1_way[i][2])
      begin
        hit_way_s1[i] = 2'd2;
        set_hit_s1[i] = 1'b1;
      end
      else if (match1_way[i][3])
      begin
        hit_way_s1[i] = 2'd3;
        set_hit_s1[i] = 1'b1;
      end
    end
  end

  // ============================================================
  // 组间优先级编码（找第一个命中的组，组号小者优先）
  // ============================================================
  // 虽然 set-associative TLB 的所有组都参与 CAM 比较，这里仍把物理存储组织为
  // set/way，以便写索引、读索引和复位布局一致。最终扁平 index={way,set}。
  reg                         s0_found_r;
  reg  [IDX_W-1:0]            s0_index_r;
  reg  [SET_W-1:0]            s0_hit_set_r;
  reg  [WAY_W-1:0]            s0_hit_way_r;

  reg                         s1_found_r;
  reg  [IDX_W-1:0]            s1_index_r;
  reg  [SET_W-1:0]            s1_hit_set_r;
  reg  [WAY_W-1:0]            s1_hit_way_r;

  always @(*)
  begin
    s0_found_r = 1'b0;
    s0_hit_set_r = {SET_W{1'b0}};
    s0_hit_way_r = {WAY_W{1'b0}};
    for (i = 0; i < NSET; i = i + 1)
    begin
      if (!s0_found_r && set_hit_s0[i])
      begin
        s0_found_r = 1'b1;
        s0_hit_set_r = i[SET_W-1:0];
        s0_hit_way_r = hit_way_s0[i];
      end
    end
    s0_index_r = {s0_hit_way_r, s0_hit_set_r};
  end

  always @(*)
  begin
    s1_found_r = 1'b0;
    s1_hit_set_r = {SET_W{1'b0}};
    s1_hit_way_r = {WAY_W{1'b0}};
    for (i = 0; i < NSET; i = i + 1)
    begin
      if (!s1_found_r && set_hit_s1[i])
      begin
        s1_found_r = 1'b1;
        s1_hit_set_r = i[SET_W-1:0];
        s1_hit_way_r = hit_way_s1[i];
      end
    end
    s1_index_r = {s1_hit_way_r, s1_hit_set_r};
  end

  // s0 payload 不再由高扇出的 {way,set} 编码动态索引全部 TLB 存储位。
  // 每个 entry 在本地完成奇偶页选择，命中优先级转换为 one-hot 后分层 OR。
  // 这与原来的 set0/way0 优先规则等价，但避免 index 编码同时驱动所有
  // PPN/属性 mux，降低 PC 到 s0 payload 寄存器的布线扇出。
  wire [NSET-1:0] s0_set_hit_vec;
  wire [NSET-1:0] s0_first_set;
  wire [NWAY-1:0] s0_entry_select [NSET-1:0];
  wire [31:0] s0_entry_payload [NSET-1:0][NWAY-1:0];
  wire [31:0] s0_set_payload [NSET-1:0];

  generate
    for (gi = 0; gi < NSET; gi = gi + 1)
    begin : s0_payload_set
      assign s0_set_hit_vec[gi] = set_hit_s0[gi];
      if (gi == 0)
        assign s0_first_set[gi] = s0_set_hit_vec[gi];
      else
        assign s0_first_set[gi] = s0_set_hit_vec[gi] &&
               !(|s0_set_hit_vec[gi-1:0]);

      assign s0_entry_select[gi][0] = s0_first_set[gi] &&
             match0_way[gi][0];
      assign s0_entry_select[gi][1] = s0_first_set[gi] &&
             !match0_way[gi][0] && match0_way[gi][1];
      assign s0_entry_select[gi][2] = s0_first_set[gi] &&
             !(|match0_way[gi][1:0]) && match0_way[gi][2];
      assign s0_entry_select[gi][3] = s0_first_set[gi] &&
             !(|match0_way[gi][2:0]) && match0_way[gi][3];

      for (gj = 0; gj < NWAY; gj = gj + 1)
      begin : s0_payload_way
        wire s0_entry_odd = tlb_ps4MB[gi][gj] ?
             s0_vppn[8] : s0_va_bit12;
        wire [31:0] s0_entry_payload_raw = {
             s0_entry_odd ? tlb_ppn1[gj][gi] : tlb_ppn0[gj][gi],
             tlb_ps4MB[gi][gj] ? 6'h15 : 6'h0c,
             s0_entry_odd ? tlb_plv1[gj][gi] : tlb_plv0[gj][gi],
             s0_entry_odd ? tlb_mat1[gj][gi] : tlb_mat0[gj][gi],
             s0_entry_odd ? tlb_d1[gj][gi] : tlb_d0[gj][gi],
             s0_entry_odd ? tlb_v1[gj][gi] : tlb_v0[gj][gi]
        };
        assign s0_entry_payload[gi][gj] = s0_entry_payload_raw &
               {32{s0_entry_select[gi][gj]}};
      end
      assign s0_set_payload[gi] = s0_entry_payload[gi][0] |
             s0_entry_payload[gi][1] | s0_entry_payload[gi][2] |
             s0_entry_payload[gi][3];
    end
  endgenerate

  reg [31:0] s0_payload_r;
  always @(*)
  begin
    s0_payload_r = 32'b0;
    for (j = 0; j < NSET; j = j + 1)
      s0_payload_r = s0_payload_r | s0_set_payload[j];
  end

  // 在原有的一拍查询边界直接锁存命中 payload，不增加查询延迟。
  reg                         s0_found_q;
  reg  [IDX_W-1:0]            s0_index_q;
  reg  [19:0]                 s0_ppn_q;
  reg  [5:0]                  s0_ps_q;
  reg  [1:0]                  s0_plv_q;
  reg  [1:0]                  s0_mat_q;
  reg                         s0_d_q;
  reg                         s0_v_q;
  reg                         s1_found_q;
  reg  [IDX_W-1:0]            s1_index_q;
  reg  [SET_W-1:0]            s1_hit_set_q;
  reg  [WAY_W-1:0]            s1_hit_way_q;
  reg  [18:0]                 s1_vppn_q;
  reg                         s1_va_bit12_q;

  always @(posedge clk)
  begin
    if (reset_tlb)
    begin
      s0_found_q    <= 1'b0;
      s0_index_q    <= {IDX_W{1'b0}};
      s0_ppn_q      <= 20'b0;
      s0_ps_q       <= 6'b0;
      s0_plv_q      <= 2'b0;
      s0_mat_q      <= 2'b0;
      s0_d_q        <= 1'b0;
      s0_v_q        <= 1'b0;
      s1_found_q    <= 1'b0;
      s1_index_q    <= {IDX_W{1'b0}};
      s1_hit_set_q  <= {SET_W{1'b0}};
      s1_hit_way_q  <= {WAY_W{1'b0}};
      s1_vppn_q     <= 19'b0;
      s1_va_bit12_q <= 1'b0;
    end
    else
    begin
      // 与前端 xlate 寄存器同步推进。反压时保持查询结果，使查询地址
      // 可以直连 Current_PC，消除经 I-cache addr_ok 返回比较器的回环。
      if (s0_en)
      begin
        s0_found_q    <= s0_found_r;
        s0_index_q    <= s0_index_r;
        if (s0_found_r)
        begin
          {s0_ppn_q,s0_ps_q,s0_plv_q,s0_mat_q,s0_d_q,s0_v_q}
              <= s0_payload_r;
        end
      end
      s1_found_q    <= s1_found_r;
      s1_index_q    <= s1_index_r;
      s1_hit_set_q  <= s1_hit_set_r;
      s1_hit_way_q  <= s1_hit_way_r;
      s1_vppn_q     <= s1_vppn;
      s1_va_bit12_q <= s1_va_bit12;
    end
  end

  // ============================================================
  // 奇偶页选择（与原一致）
  // ============================================================
  // 4 KiB 双页用 VA[12] 选 subpage；4 MiB 双页用 VPPN[8]（即 VA[21]）选择。
  wire s1_odd_page = tlb_ps4MB[s1_hit_set_q][s1_hit_way_q] ? s1_vppn_q[8] : s1_va_bit12_q;

  // ============================================================
  // 输出属性组合逻辑
  // ============================================================
  // s0 属性仅在 found=1 时有效；miss 时保持上次 payload，CPU 侧所有语义使用
  // 都由 s0_found 门控。s1 仍在 miss 时返回 0。命中时根据 odd_page 选择
  // LO0/LO1 属性，并把压缩页大小还原为架构 PS 编码 12 或 21。
  reg  [19:0] s1_ppn_r;
  reg  [5:0]  s1_ps_r;
  reg  [1:0]  s1_plv_r;
  reg  [1:0]  s1_mat_r;
  reg         s1_d_r;
  reg         s1_v_r;

  always @(*)
  begin
    s1_ppn_r = 20'b0;
    s1_ps_r  = 6'b0;
    s1_plv_r = 2'b0;
    s1_mat_r = 2'b0;
    s1_d_r   = 1'b0;
    s1_v_r   = 1'b0;
    if (s1_found_q)
    begin
      s1_ps_r = tlb_ps4MB[s1_hit_set_q][s1_hit_way_q] ? 6'h15 : 6'h0c;
      if (s1_odd_page)
      begin
        s1_ppn_r = tlb_ppn1[s1_hit_way_q][s1_hit_set_q];
        s1_plv_r = tlb_plv1[s1_hit_way_q][s1_hit_set_q];
        s1_mat_r = tlb_mat1[s1_hit_way_q][s1_hit_set_q];
        s1_d_r   = tlb_d1  [s1_hit_way_q][s1_hit_set_q];
        s1_v_r   = tlb_v1  [s1_hit_way_q][s1_hit_set_q];
      end
      else
      begin
        s1_ppn_r = tlb_ppn0[s1_hit_way_q][s1_hit_set_q];
        s1_plv_r = tlb_plv0[s1_hit_way_q][s1_hit_set_q];
        s1_mat_r = tlb_mat0[s1_hit_way_q][s1_hit_set_q];
        s1_d_r   = tlb_d0  [s1_hit_way_q][s1_hit_set_q];
        s1_v_r   = tlb_v0  [s1_hit_way_q][s1_hit_set_q];
      end
    end
  end

  // ============================================================
  // INVTLB 匹配向量计算（遍历所有路和组）
  // ============================================================
  // 操作码语义：
  //   0/1：清除全部有效项；2：清除全局项；3：清除非全局项；
  //   4：清除指定 ASID 的非全局项；
  //   5：清除指定 ASID+VPPN 的非全局项；
  //   6：按 VPPN 清除全局项或指定 ASID 项。
  // VPPN 的比较同查询逻辑一样尊重条目的页大小。
  reg  [NWAY-1:0] inv_match_way [NSET-1:0];

  always @(*)
  begin
    for (i = 0; i < NSET; i = i + 1)
    begin
      for (j = 0; j < NWAY; j = j + 1)
      begin
        inv_match_way[i][j] = 1'b0;
        if (tlb_e[i][j])
        begin
          case (invtlb_op)
            5'd0, 5'd1:
              inv_match_way[i][j] = 1'b1;
            5'd2:
              inv_match_way[i][j] = tlb_g[j][i];
            5'd3:
              inv_match_way[i][j] = ~tlb_g[j][i];
            5'd4:
              inv_match_way[i][j] = (~tlb_g[j][i]) && (invtlb_asid == tlb_asid[j][i]);
            5'd5:
              inv_match_way[i][j] = (~tlb_g[j][i])
              && (invtlb_asid == tlb_asid[j][i])
              && (invtlb_vppn[18:9] == tlb_vppn[j][i][18:9])
              && (tlb_ps4MB[i][j] || (invtlb_vppn[8:0] == tlb_vppn[j][i][8:0]));
            5'd6:
              inv_match_way[i][j] = (tlb_g[j][i] || (invtlb_asid == tlb_asid[j][i]))
              && (invtlb_vppn[18:9] == tlb_vppn[j][i][18:9])
              && (tlb_ps4MB[i][j] || (invtlb_vppn[8:0] == tlb_vppn[j][i][8:0]));
            default:
              inv_match_way[i][j] = 1'b0;
          endcase
        end
      end
    end
  end

  // ============================================================
  // 状态更新（时钟同步）
  // ============================================================
  // reset_tlb 清空 E 位和所有 payload，提供确定仿真状态。稳态时先执行 INVTLB、
  // 再执行单项写；二者同拍命中同一项时，后面的非阻塞写赋值获胜，即新写项有效。
  always @(posedge clk)
  begin
    if (reset_tlb)
    begin
      for (i = 0; i < NSET; i = i + 1)
      begin
        tlb_e[i] <= {NWAY{1'b0}};
        tlb_ps4MB[i] <= {NWAY{1'b0}};
      end
      for (i = 0; i < NWAY; i = i + 1)
      begin
        for (j = 0; j < NSET; j = j + 1)
        begin
          tlb_vppn[i][j] <= 19'b0;
          tlb_asid[i][j] <= 10'b0;
          tlb_g[i][j]    <= 1'b0;
          tlb_ppn0[i][j] <= 20'b0;
          tlb_plv0[i][j] <= 2'b0;
          tlb_mat0[i][j] <= 2'b0;
          tlb_d0[i][j]   <= 1'b0;
          tlb_v0[i][j]   <= 1'b0;
          tlb_ppn1[i][j] <= 20'b0;
          tlb_plv1[i][j] <= 2'b0;
          tlb_mat1[i][j] <= 2'b0;
          tlb_d1[i][j]   <= 1'b0;
          tlb_v1[i][j]   <= 1'b0;
        end
      end
    end
    else
    begin
      // INVTLB 处理
      if (invtlb_valid)
      begin
        for (i = 0; i < NSET; i = i + 1)
        begin
          for (j = 0; j < NWAY; j = j + 1)
          begin
            if (inv_match_way[i][j])
              tlb_e[i][j] <= 1'b0;
          end
        end
      end

      // 写入条目
      if (we)
      begin
        tlb_e[w_set][w_way] <= w_e;
        tlb_ps4MB[w_set][w_way] <= (w_ps == 6'h15);
        tlb_vppn[w_way][w_set] <= w_vppn;
        tlb_asid[w_way][w_set] <= w_asid;
        tlb_g[w_way][w_set]    <= w_g;
        tlb_ppn0[w_way][w_set] <= w_ppn0;
        tlb_plv0[w_way][w_set] <= w_plv0;
        tlb_mat0[w_way][w_set] <= w_mat0;
        tlb_d0[w_way][w_set]   <= w_d0;
        tlb_v0[w_way][w_set]   <= w_v0;
        tlb_ppn1[w_way][w_set] <= w_ppn1;
        tlb_plv1[w_way][w_set] <= w_plv1;
        tlb_mat1[w_way][w_set] <= w_mat1;
        tlb_d1[w_way][w_set]   <= w_d1;
        tlb_v1[w_way][w_set]   <= w_v1;
      end
    end
  end

  // ============================================================
  // 输出驱动
  // ============================================================
  assign s0_found = s0_found_q;
  assign s0_index = s0_index_q;
  assign s0_ppn   = s0_ppn_q;
  assign s0_ps    = s0_ps_q;
  assign s0_plv   = s0_plv_q;
  assign s0_mat   = s0_mat_q;
  assign s0_d     = s0_d_q;
  assign s0_v     = s0_v_q;

  assign s1_found = s1_found_q;
  assign s1_index = s1_index_q;
  assign s1_ppn   = s1_ppn_r;
  assign s1_ps    = s1_ps_r;
  assign s1_plv   = s1_plv_r;
  assign s1_mat   = s1_mat_r;
  assign s1_d     = s1_d_r;
  assign s1_v     = s1_v_r;

  // 读端口为组合读取，r_index 应在 TLBRD 提交周期保持稳定。E=0 时 payload
  // 虽然仍可读出，但 CSR 模块会依据 r_e 清零软件可见字段。
  assign r_e    = tlb_e[r_set][r_way];
  assign r_vppn = tlb_vppn[r_way][r_set];
  assign r_ps   = tlb_ps4MB[r_set][r_way] ? 6'h15 : 6'h0c;
  assign r_asid = tlb_asid[r_way][r_set];
  assign r_g    = tlb_g[r_way][r_set];
  assign r_ppn0 = tlb_ppn0[r_way][r_set];
  assign r_plv0 = tlb_plv0[r_way][r_set];
  assign r_mat0 = tlb_mat0[r_way][r_set];
  assign r_d0   = tlb_d0[r_way][r_set];
  assign r_v0   = tlb_v0[r_way][r_set];
  assign r_ppn1 = tlb_ppn1[r_way][r_set];
  assign r_plv1 = tlb_plv1[r_way][r_set];
  assign r_mat1 = tlb_mat1[r_way][r_set];
  assign r_d1   = tlb_d1[r_way][r_set];
  assign r_v1   = tlb_v1[r_way][r_set];

endmodule
