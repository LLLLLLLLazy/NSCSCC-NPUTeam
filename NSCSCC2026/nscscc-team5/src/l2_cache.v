// 面向私有 I/D L1 cache 的统一式 clean/read-allocate L2 cache。
//
// 默认组织结构：2048 set x 4 way x 16 byte = 128 KiB。
// 两个带 tag 的读 MSHR 独立接收下一级 beat，四项响应表将无 ready 的 L1 响应
// 端口与 AXI 返回时序解耦。因此，当较早的 refill 尚未完成时，不同 set 的
// 常驻行命中、第二个 miss 和同缓存行消费者仍可继续执行。独立的单项 D-write
// 上下文保留现有 write-around/精确失效策略。
//
// 行大小固定 16 B。L1 I/D 各自拥有类 SRAM 请求/响应端口和一个下级内存端口，
// L2 在内部共享 tag/data 阵列，但保持 I、D 的返回 ID 独立。读 miss 为四拍
// critical-word-first WRAP refill；D 写采用 write-around：先写下级，再精确失效
// 命中的 clean L2 行，避免维护 dirty 状态和重复写回。L2 因而只保存 clean 数据。
//
// 四路替换使用 3 位 tree-PLRU：root 决定左右子树，left/right 决定各子树中的
// victim。纯 prefetch 以“插入为 LRU”方式减少污染，被 demand 合并后按普通
// MRU 安装。所有 metadata 更新仲裁到单一 BRAM 写端口。
module l2_cache #(
    parameter integer INDEX_BITS = 11
  )(
    input  wire        clk,
    input  wire        resetn,

    // 串行 cache maintenance；只有缓存、MSHR、响应和写上下文全部静止才接收。
    input  wire        cacop_req,
    input  wire [ 4:0] cacop_code,
    input  wire [31:0] cacop_addr,
    output wire        cacop_addr_ok,
    output wire        cacop_data_ok,

    // uncached RAM store 完成后的旁路一致性更新。
    input  wire        snoop_req,
    input  wire [31:0] snoop_addr,
    input  wire [ 3:0] snoop_wstrb,
    input  wire [31:0] snoop_wdata,
    output wire        snoop_addr_ok,
    output wire        snoop_data_ok,

    // 上游 I-cache refill 端口。i_id 是 L1 的 MSHR ID，随每个返回 beat原样送回。
    input  wire        i_req,
    input  wire        i_wr,
    input  wire [ 1:0] i_size,
    input  wire [ 3:0] i_wstrb,
    input  wire [31:0] i_addr,
    input  wire [31:0] i_wdata,
    input  wire        i_id,
    // 只有明确为 1 时才视为推测请求。因此在仿真中，省略的旧版连接按 demand
    // 流量处理。
    input  wire        i_prefetch,
    output wire        i_addr_ok,
    output wire        i_data_ok,
    output wire [31:0] i_rdata,
    output wire        i_resp_id,

    // 上游 D-cache 端口：读可分配到 L2，写走 write-around 并探测失效命中行。
    input  wire        d_req,
    input  wire        d_wr,
    input  wire [ 1:0] d_size,
    input  wire [ 3:0] d_wstrb,
    input  wire [31:0] d_addr,
    input  wire [31:0] d_wdata,
    input  wire        d_id,
    output wire        d_addr_ok,
    output wire        d_data_ok,
    output wire [31:0] d_rdata,
    output wire        d_resp_id,

    // 下级 I 读端口。每个稳定的 mem_req 保持到 addr_ok，返回用 resp_id 匹配 MSHR。
    output wire        i_mem_req,
    output wire        i_mem_wr,
    output wire [ 1:0] i_mem_size,
    output wire [ 3:0] i_mem_wstrb,
    output wire [31:0] i_mem_addr,
    output wire [31:0] i_mem_wdata,
    output wire        i_mem_id,
    input  wire        i_mem_addr_ok,
    input  wire        i_mem_data_ok,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_resp_id,

    // 下级 D 端口承载 D refill 与 write-around 写；写响应也由 d_mem_data_ok 表示。
    output wire        d_mem_req,
    output wire        d_mem_wr,
    output wire [ 1:0] d_mem_size,
    output wire [ 3:0] d_mem_wstrb,
    output wire [31:0] d_mem_addr,
    output wire [31:0] d_mem_wdata,
    output wire        d_mem_id,
    input  wire        d_mem_addr_ok,
    input  wire        d_mem_data_ok,
    input  wire [31:0] d_mem_rdata,
    input  wire        d_mem_resp_id
  );

  // 几何参数与固定并发深度。RESP_DEPTH=4 允许多个合并消费者等待不同 critical 字。
  localparam integer LINE_OFFSET_BITS = 4;
  localparam integer LINE_ADDR_BITS = 32 - LINE_OFFSET_BITS;
  localparam integer TAG_BITS = 32 - INDEX_BITS - LINE_OFFSET_BITS;
  localparam integer SET_COUNT = 1 << INDEX_BITS;
  localparam integer MSHR_COUNT = 2;
  localparam integer RESP_DEPTH = 4;

  // 四路 tag/data 均按单读单写 BRAM 模板实现。valid 不与 tag 混合，复位只需
  // 逐 set 清 metadata，避免清除大容量 payload 阵列。
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way0 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way1 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way2 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way3 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way0 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way1 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way2 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way3 [0:SET_COUNT-1];
  // 将 valid 和 PLRU 打包成一个 7 位 metadata 字。所有更新来源在下方仲裁到
  // 一个写端口，而 lookup 使用独立的同步读端口。这是原生简单双端口 BRAM
  // 模式，可避免在时序关键请求路径上出现 2048 项分布式 RAM 写译码器。
  // 布局：{valid[3:0],plru[root,left,right]}。
  (* ram_style = "block" *) reg [6:0] metadata_mem [0:SET_COUNT-1];

  reg [TAG_BITS-1:0] tag_way0_r;
  reg [TAG_BITS-1:0] tag_way1_r;
  reg [TAG_BITS-1:0] tag_way2_r;
  reg [TAG_BITS-1:0] tag_way3_r;
  reg [127:0] data_way0_r;
  reg [127:0] data_way1_r;
  reg [127:0] data_way2_r;
  reg [127:0] data_way3_r;
  reg [3:0] valid_r;
  reg [2:0] plru_r;

  // 每个 L1 来源配置一个单项 skid buffer。地址接收只在此捕获请求；所有缓存行
  // 比较、合并检查和 metadata lookup 控制均在下一拍使用这些已寄存字段。
  // pop 与新 push 可同时发生，因此持续请求吞吐率仍为每拍一个。
  reg        i_req_q;
  reg        i_wr_q;
  reg [31:0] i_addr_q;
  reg        i_id_q;
  reg        i_prefetch_q;
  reg        d_req_q;
  reg        d_wr_q;
  reg [1:0]  d_size_q;
  reg [3:0]  d_wstrb_q;
  reg [31:0] d_addr_q;
  reg [31:0] d_wdata_q;
  reg        d_id_q;

  // 两个 MSHR 均满时，可暂存一个同步 tag/data lookup。同缓存行合并使用
  // MSHR line RAM，因此旁路此寄存器。
  reg       lookup_valid;
  reg       lookup_is_cacop;
  reg       lookup_is_snoop;
  reg       lookup_is_d;
  reg       lookup_is_prefetch;
  reg       lookup_needs_replay;
  reg       lookup_up_id;
  reg [4:0] lookup_cacop_code;
  reg [1:0] lookup_cacop_way;
  reg [3:0] lookup_snoop_wstrb;
  reg [31:0] lookup_snoop_wdata;
  reg [TAG_BITS-1:0] lookup_tag;
  reg [INDEX_BITS-1:0] lookup_index;
  reg [1:0] lookup_start_word;
  reg [1:0] lookup_resp_slot;

  // 两个下级读取上下文。lower_id 保留原始 L1 MSHR ID，使现有 bridge 能将
  // {source,ID} 直接编码进 AXI ARID。
  reg [1:0] mshr_active;
  reg [1:0] mshr_req_sent;
  reg [1:0] mshr_is_d;
  reg [1:0] mshr_lower_id;
  reg [1:0] mshr_is_prefetch;
  reg [1:0] mshr_fill_complete;
  reg [TAG_BITS-1:0] mshr_tag [0:MSHR_COUNT-1];
  reg [INDEX_BITS-1:0] mshr_index [0:MSHR_COUNT-1];
  reg [1:0] mshr_start_word [0:MSHR_COUNT-1];
  reg [1:0] mshr_beat_count [0:MSHR_COUNT-1];
  reg [3:0] mshr_word_valid [0:MSHR_COUNT-1];
  reg [127:0] mshr_line [0:MSHR_COUNT-1];
  reg [1:0] mshr_victim_way [0:MSHR_COUNT-1];
  reg [3:0] mshr_valid_state [0:MSHR_COUNT-1];
  reg [2:0] mshr_plru_state [0:MSHR_COUNT-1];

  // 每个来源使用稳定的发射选择器。mem_req 一旦可见，选中的 slot 和所有
  // payload 字段在 mem_addr_ok 到来前保持不变。
  reg i_issue_valid;
  reg i_issue_slot;
  reg d_issue_valid;
  reg d_issue_slot;

  // 每个被接收的上级读请求都会预留一个响应项。下级 refill 字会复制到所有
  // 关联消费者，使 critical word 不同的 I 请求和 D 请求能够共享一次下级事务。
  reg [RESP_DEPTH-1:0] resp_valid;
  reg [RESP_DEPTH-1:0] resp_is_d;
  reg [RESP_DEPTH-1:0] resp_up_id;
  reg [RESP_DEPTH-1:0] resp_has_mshr;
  reg [RESP_DEPTH-1:0] resp_mshr_id;
  reg [LINE_ADDR_BITS-1:0] resp_line_addr [0:RESP_DEPTH-1];
  reg [1:0] resp_start_word [0:RESP_DEPTH-1];
  reg [1:0] resp_send_count [0:RESP_DEPTH-1];
  reg [3:0] resp_word_valid [0:RESP_DEPTH-1];
  reg [127:0] resp_line [0:RESP_DEPTH-1];
  reg [1:0] i_resp_rr;
  reg [1:0] d_resp_rr;

  // I/D lookup 仲裁的轮转偏好位，防止两个上游持续请求时某一侧饥饿。
  reg prefer_d;

  // D writeback 转发与 I 读取保持独立。写探测可能在 L2 fill 安装之后等待，
  // 以保证 metadata_mem 只有一个写入方。
  reg       write_pending_q;
  reg       write_busy_q;
  reg       write_id_q;
  reg [1:0] write_size_q;
  reg [3:0] write_wstrb_q;
  reg [31:0] write_addr_q;
  reg [31:0] write_wdata_q;
  reg       write_probe_pending;
  reg [INDEX_BITS-1:0] write_index_q;
  reg [TAG_BITS-1:0] write_tag_q;

  reg init_active;
  reg [INDEX_BITS-1:0] init_index;

  // 从一条 128 位行选择指定 32 位 word。
  function [31:0] select_word;
    input [127:0] line;
    input [1:0] word_index;
    begin
      case (word_index)
        2'd0: select_word = line[31:0];
        2'd1: select_word = line[63:32];
        2'd2: select_word = line[95:64];
        default: select_word = line[127:96];
      endcase
    end
  endfunction

  // 把返回 beat 放入 refill/响应行副本的指定 word 位置。
  function [127:0] put_word;
    input [127:0] line;
    input [1:0] word_index;
    input [31:0] word_data;
    begin
      put_word = line;
      case (word_index)
        2'd0: put_word[31:0] = word_data;
        2'd1: put_word[63:32] = word_data;
        2'd2: put_word[95:64] = word_data;
        default: put_word[127:96] = word_data;
      endcase
    end
  endfunction

  // snoop/write probe 命中时按 byte-enable 合并下级已经提交的新数据。
  function [31:0] merge_store_word;
    input [31:0] old_word;
    input [31:0] new_word;
    input [ 3:0] byte_en;
    begin
      merge_store_word = old_word;
      if (byte_en[0]) merge_store_word[ 7: 0] = new_word[ 7: 0];
      if (byte_en[1]) merge_store_word[15: 8] = new_word[15: 8];
      if (byte_en[2]) merge_store_word[23:16] = new_word[23:16];
      if (byte_en[3]) merge_store_word[31:24] = new_word[31:24];
    end
  endfunction

  // Tree-PLRU 编码更新：访问一路后，把沿途方向位指向相反子树（下一 victim）。
  function [2:0] plru_mark_mru;
    input [2:0] old_state;
    input [1:0] accessed_way;
    begin
      plru_mark_mru = old_state;
      case (accessed_way)
        2'd0: begin
          plru_mark_mru[2] = 1'b1;
          plru_mark_mru[1] = 1'b1;
        end
        2'd1: begin
          plru_mark_mru[2] = 1'b1;
          plru_mark_mru[1] = 1'b0;
        end
        2'd2: begin
          plru_mark_mru[2] = 1'b0;
          plru_mark_mru[0] = 1'b1;
        end
        default: begin
          plru_mark_mru[2] = 1'b0;
          plru_mark_mru[0] = 1'b0;
        end
      endcase
    end
  endfunction

  // 纯推测 fill 按下一个 victim 安装。如果安装前有 demand 与其合并，
  // 则改用普通 MRU 插入方式。
  // 预取插入时把该路标成优先 victim，而非普通访问后的 MRU，降低预取污染。
  function [2:0] plru_mark_lru;
    input [2:0] old_state;
    input [1:0] inserted_way;
    begin
      plru_mark_lru = old_state;
      case (inserted_way)
        2'd0: begin
          plru_mark_lru[2] = 1'b0;
          plru_mark_lru[1] = 1'b0;
        end
        2'd1: begin
          plru_mark_lru[2] = 1'b0;
          plru_mark_lru[1] = 1'b1;
        end
        2'd2: begin
          plru_mark_lru[2] = 1'b1;
          plru_mark_lru[0] = 1'b0;
        end
        default: begin
          plru_mark_lru[2] = 1'b1;
          plru_mark_lru[0] = 1'b1;
        end
      endcase
    end
  endfunction

  // ------------------------------------------------------------------------
  // 下级响应匹配及各 MSHR 的 refill 状态
  // ------------------------------------------------------------------------
  wire mshr0_i_return = i_mem_data_ok && mshr_active[0] &&
       mshr_req_sent[0] && !mshr_is_d[0] &&
       (i_mem_resp_id == mshr_lower_id[0]);
  wire mshr0_d_return = d_mem_data_ok && mshr_active[0] &&
       mshr_req_sent[0] && mshr_is_d[0] &&
       (d_mem_resp_id == mshr_lower_id[0]);
  wire mshr1_i_return = i_mem_data_ok && mshr_active[1] &&
       mshr_req_sent[1] && !mshr_is_d[1] &&
       (i_mem_resp_id == mshr_lower_id[1]);
  wire mshr1_d_return = d_mem_data_ok && mshr_active[1] &&
       mshr_req_sent[1] && mshr_is_d[1] &&
       (d_mem_resp_id == mshr_lower_id[1]);
  wire mshr0_refill_fire = mshr0_i_return || mshr0_d_return;
  wire mshr1_refill_fire = mshr1_i_return || mshr1_d_return;
  wire [31:0] mshr0_refill_data = mshr_is_d[0] ?
       d_mem_rdata : i_mem_rdata;
  wire [31:0] mshr1_refill_data = mshr_is_d[1] ?
       d_mem_rdata : i_mem_rdata;
  wire [1:0] mshr0_refill_word = mshr_start_word[0] +
                                 mshr_beat_count[0];
  wire [1:0] mshr1_refill_word = mshr_start_word[1] +
                                 mshr_beat_count[1];
  wire [127:0] mshr0_line_next = mshr0_refill_fire ?
       put_word(mshr_line[0],mshr0_refill_word,mshr0_refill_data) :
       mshr_line[0];
  wire [127:0] mshr1_line_next = mshr1_refill_fire ?
       put_word(mshr_line[1],mshr1_refill_word,mshr1_refill_data) :
       mshr_line[1];
  wire [3:0] mshr0_word_valid_next = mshr_word_valid[0] |
       (mshr0_refill_fire ? (4'b0001 << mshr0_refill_word) : 4'b0000);
  wire [3:0] mshr1_word_valid_next = mshr_word_valid[1] |
       (mshr1_refill_fire ? (4'b0001 << mshr1_refill_word) : 4'b0000);
  wire mshr0_refill_last = mshr0_refill_fire &&
                           (mshr_beat_count[0] == 2'd3);
  wire mshr1_refill_last = mshr1_refill_fire &&
                           (mshr_beat_count[1] == 2'd3);

  // ------------------------------------------------------------------------
  // 响应项分配及 I/D beat 调度器
  // ------------------------------------------------------------------------
  reg resp_free_valid;
  reg [1:0] resp_free_slot;
  always @(*) begin
    resp_free_valid = 1'b1;
    if (!resp_valid[0])
      resp_free_slot = 2'd0;
    else if (!resp_valid[1])
      resp_free_slot = 2'd1;
    else if (!resp_valid[2])
      resp_free_slot = 2'd2;
    else if (!resp_valid[3])
      resp_free_slot = 2'd3;
    else begin
      resp_free_valid = 1'b0;
      resp_free_slot = 2'd0;
    end
  end

  wire [1:0] resp_word_index0 = resp_start_word[0] + resp_send_count[0];
  wire [1:0] resp_word_index1 = resp_start_word[1] + resp_send_count[1];
  wire [1:0] resp_word_index2 = resp_start_word[2] + resp_send_count[2];
  wire [1:0] resp_word_index3 = resp_start_word[3] + resp_send_count[3];
  wire i_ready0 = resp_valid[0] && !resp_is_d[0] &&
                  resp_word_valid[0][resp_word_index0];
  wire i_ready1 = resp_valid[1] && !resp_is_d[1] &&
                  resp_word_valid[1][resp_word_index1];
  wire i_ready2 = resp_valid[2] && !resp_is_d[2] &&
                  resp_word_valid[2][resp_word_index2];
  wire i_ready3 = resp_valid[3] && !resp_is_d[3] &&
                  resp_word_valid[3][resp_word_index3];
  wire d_ready0 = resp_valid[0] && resp_is_d[0] &&
                  resp_word_valid[0][resp_word_index0];
  wire d_ready1 = resp_valid[1] && resp_is_d[1] &&
                  resp_word_valid[1][resp_word_index1];
  wire d_ready2 = resp_valid[2] && resp_is_d[2] &&
                  resp_word_valid[2][resp_word_index2];
  wire d_ready3 = resp_valid[3] && resp_is_d[3] &&
                  resp_word_valid[3][resp_word_index3];

  reg i_emit_valid;
  reg [1:0] i_emit_slot;
  always @(*) begin
    i_emit_valid = 1'b1;
    i_emit_slot = i_resp_rr;
    case (i_resp_rr)
      2'd0: begin
        if (i_ready0) i_emit_slot = 2'd0;
        else if (i_ready1) i_emit_slot = 2'd1;
        else if (i_ready2) i_emit_slot = 2'd2;
        else if (i_ready3) i_emit_slot = 2'd3;
        else i_emit_valid = 1'b0;
      end
      2'd1: begin
        if (i_ready1) i_emit_slot = 2'd1;
        else if (i_ready2) i_emit_slot = 2'd2;
        else if (i_ready3) i_emit_slot = 2'd3;
        else if (i_ready0) i_emit_slot = 2'd0;
        else i_emit_valid = 1'b0;
      end
      2'd2: begin
        if (i_ready2) i_emit_slot = 2'd2;
        else if (i_ready3) i_emit_slot = 2'd3;
        else if (i_ready0) i_emit_slot = 2'd0;
        else if (i_ready1) i_emit_slot = 2'd1;
        else i_emit_valid = 1'b0;
      end
      default: begin
        if (i_ready3) i_emit_slot = 2'd3;
        else if (i_ready0) i_emit_slot = 2'd0;
        else if (i_ready1) i_emit_slot = 2'd1;
        else if (i_ready2) i_emit_slot = 2'd2;
        else i_emit_valid = 1'b0;
      end
    endcase
  end

  reg d_pick_valid;
  reg [1:0] d_emit_slot;
  always @(*) begin
    d_pick_valid = 1'b1;
    d_emit_slot = d_resp_rr;
    case (d_resp_rr)
      2'd0: begin
        if (d_ready0) d_emit_slot = 2'd0;
        else if (d_ready1) d_emit_slot = 2'd1;
        else if (d_ready2) d_emit_slot = 2'd2;
        else if (d_ready3) d_emit_slot = 2'd3;
        else d_pick_valid = 1'b0;
      end
      2'd1: begin
        if (d_ready1) d_emit_slot = 2'd1;
        else if (d_ready2) d_emit_slot = 2'd2;
        else if (d_ready3) d_emit_slot = 2'd3;
        else if (d_ready0) d_emit_slot = 2'd0;
        else d_pick_valid = 1'b0;
      end
      2'd2: begin
        if (d_ready2) d_emit_slot = 2'd2;
        else if (d_ready3) d_emit_slot = 2'd3;
        else if (d_ready0) d_emit_slot = 2'd0;
        else if (d_ready1) d_emit_slot = 2'd1;
        else d_pick_valid = 1'b0;
      end
      default: begin
        if (d_ready3) d_emit_slot = 2'd3;
        else if (d_ready0) d_emit_slot = 2'd0;
        else if (d_ready1) d_emit_slot = 2'd1;
        else if (d_ready2) d_emit_slot = 2'd2;
        else d_pick_valid = 1'b0;
      end
    endcase
  end

  // ------------------------------------------------------------------------
  // 读仲裁、同缓存行合并准入及 lookup 准入
  // ------------------------------------------------------------------------
  wire i_prefetch_active = (i_prefetch_q === 1'b1);
  wire write_context_valid = write_pending_q || write_busy_q;
  wire write_order_valid = write_context_valid || write_probe_pending;
  wire i_write_line_conflict = write_order_valid &&
       (i_addr_q[31:LINE_OFFSET_BITS] == {write_tag_q,write_index_q});
  wire d_write_waiting = d_req_q && d_wr_q;
  wire d_read_pending = d_req_q && !d_wr_q && !write_order_valid;
  wire i_demand_pending = i_req_q && !i_wr_q && !i_prefetch_active &&
                          !i_write_line_conflict;
  wire i_prefetch_pending = i_req_q && !i_wr_q && i_prefetch_active &&
                            !i_write_line_conflict;
  wire select_d_read = d_read_pending &&
                       (!i_demand_pending || prefer_d);
  wire select_i_demand = i_demand_pending &&
                         (!d_read_pending || !prefer_d);
  wire select_i_read = select_i_demand ||
       (!d_read_pending && !i_demand_pending && i_prefetch_pending);
  wire selected_valid = select_d_read || select_i_read;
  wire selected_is_d = select_d_read;
  wire selected_is_prefetch = select_i_read && i_prefetch_active;
  wire selected_up_id = selected_is_d ? d_id_q : i_id_q;
  wire [31:0] selected_addr = selected_is_d ? d_addr_q : i_addr_q;
  wire [LINE_ADDR_BITS-1:0] selected_line_addr =
       selected_addr[31:LINE_OFFSET_BITS];
  wire [INDEX_BITS-1:0] selected_index =
       selected_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS];
  wire [TAG_BITS-1:0] selected_tag =
       selected_addr[31:LINE_OFFSET_BITS + INDEX_BITS];

  wire selected_match_m0 = mshr_active[0] &&
       ({mshr_tag[0],mshr_index[0]} == selected_line_addr);
  wire selected_match_m1 = mshr_active[1] &&
       ({mshr_tag[1],mshr_index[1]} == selected_line_addr);
  wire selected_mshr_match = selected_match_m0 || selected_match_m1;
  wire selected_mshr_slot = selected_match_m1;
  wire selected_set_conflict =
       (mshr_active[0] && (mshr_index[0] == selected_index) &&
        !selected_match_m0) ||
       (mshr_active[1] && (mshr_index[1] == selected_index) &&
        !selected_match_m1);
  wire selected_set_installing =
       (mshr_fill_complete[0] && (mshr_index[0] == selected_index) &&
        !selected_match_m0) ||
       (mshr_fill_complete[1] && (mshr_index[1] == selected_index) &&
        !selected_match_m1);
  wire selected_lower_id_conflict =
       (mshr_active[0] && (mshr_is_d[0] == selected_is_d) &&
        (mshr_lower_id[0] == selected_up_id)) ||
       (mshr_active[1] && (mshr_is_d[1] == selected_is_d) &&
        (mshr_lower_id[1] == selected_up_id));

  wire mshr0_has_i_consumer = |(resp_valid & resp_has_mshr &
       ~resp_mshr_id & ~resp_is_d);
  wire mshr0_has_d_consumer = |(resp_valid & resp_has_mshr &
       ~resp_mshr_id & resp_is_d);
  wire mshr1_has_i_consumer = |(resp_valid & resp_has_mshr &
       resp_mshr_id & ~resp_is_d);
  wire mshr1_has_d_consumer = |(resp_valid & resp_has_mshr &
       resp_mshr_id & resp_is_d);
  wire selected_consumer_conflict = selected_mshr_slot ?
       (selected_is_d ? mshr1_has_d_consumer : mshr1_has_i_consumer) :
       (selected_is_d ? mshr0_has_d_consumer : mshr0_has_i_consumer);

  // 新拉高的 CACOP 会阻止后续外部 buffer push，但不能阻止已经收到 addr_ok、
  // 当前位于 skid buffer 中的请求。这些较早请求排空后，cache_quiescent
  // 才允许 CACOP 进入。
  wire read_accept_base = !init_active &&
       !d_write_waiting && !write_probe_pending && selected_valid &&
       resp_free_valid;
  wire prefetch_lookup_allowed = !selected_is_prefetch ||
       selected_mshr_match || (mshr_active == 2'b00);
  wire accept_merge = read_accept_base && selected_mshr_match &&
                      !selected_consumer_conflict;
  wire accept_normal_read = read_accept_base && !selected_mshr_match &&
       !selected_set_installing && !selected_lower_id_conflict &&
       !lookup_valid && prefetch_lookup_allowed;
  wire accept_read = accept_merge || accept_normal_read;

  wire i_buffer_pop = accept_read && !selected_is_d;

  // D 写请求早于同拍暂存的 I 请求。当它等待安全的 metadata 探测时，
  // 不再绕过它继续接收更晚的读请求。
  wire any_d_response = |(resp_valid & resp_is_d);
  wire any_d_lower_mshr = (mshr_active[0] && mshr_is_d[0]) ||
                          (mshr_active[1] && mshr_is_d[1]);
  wire d_read_outstanding = any_d_response || any_d_lower_mshr ||
                            d_issue_valid;
  wire write_mshr_set_conflict =
       (mshr_active[0] &&
        (mshr_index[0] == d_addr_q[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                  LINE_OFFSET_BITS])) ||
       (mshr_active[1] &&
        (mshr_index[1] == d_addr_q[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                  LINE_OFFSET_BITS]));
  wire write_response_line_conflict =
       (resp_valid[0] &&
        (resp_line_addr[0] == d_addr_q[31:LINE_OFFSET_BITS])) ||
       (resp_valid[1] &&
        (resp_line_addr[1] == d_addr_q[31:LINE_OFFSET_BITS])) ||
       (resp_valid[2] &&
        (resp_line_addr[2] == d_addr_q[31:LINE_OFFSET_BITS])) ||
       (resp_valid[3] &&
        (resp_line_addr[3] == d_addr_q[31:LINE_OFFSET_BITS]));
  wire accept_d_write = !init_active && d_write_waiting &&
       !write_order_valid && !lookup_valid && !d_read_outstanding &&
       !write_mshr_set_conflict && !write_response_line_conflict;
  wire d_buffer_pop = (accept_read && selected_is_d) || accept_d_write;

  // 上游握手终止于 skid 寄存器，而不是 lookup 或响应表写逻辑。同拍 pop 时
  // 进行替换，可在不重建外部地址组合路径的情况下保持 II=1。
  wire i_buffer_ready = !init_active && !cacop_req && !snoop_req &&
                         (!i_req_q || i_buffer_pop);
  wire d_buffer_ready = !init_active && !cacop_req && !snoop_req &&
                         (!d_req_q || d_buffer_pop);
  wire i_buffer_push = i_req && i_buffer_ready;
  wire d_buffer_push = d_req && d_buffer_ready;
  assign i_addr_ok = i_buffer_push;
  assign d_addr_ok = d_buffer_push;

  always @(posedge clk) begin
    if (!resetn) begin
      i_req_q <= 1'b0;
      i_wr_q <= 1'b0;
      i_addr_q <= 32'b0;
      i_id_q <= 1'b0;
      i_prefetch_q <= 1'b0;
      d_req_q <= 1'b0;
      d_wr_q <= 1'b0;
      d_size_q <= 2'b0;
      d_wstrb_q <= 4'b0;
      d_addr_q <= 32'b0;
      d_wdata_q <= 32'b0;
      d_id_q <= 1'b0;
    end else begin
      case ({i_buffer_push,i_buffer_pop})
        2'b10: i_req_q <= 1'b1;
        2'b01: i_req_q <= 1'b0;
        2'b11: i_req_q <= 1'b1;
        default: i_req_q <= i_req_q;
      endcase
      if (i_buffer_push) begin
        i_wr_q <= i_wr;
        i_addr_q <= i_addr;
        i_id_q <= i_id;
        i_prefetch_q <= (i_prefetch === 1'b1);
      end

      case ({d_buffer_push,d_buffer_pop})
        2'b10: d_req_q <= 1'b1;
        2'b01: d_req_q <= 1'b0;
        2'b11: d_req_q <= 1'b1;
        default: d_req_q <= d_req_q;
      endcase
      if (d_buffer_push) begin
        d_wr_q <= d_wr;
        d_size_q <= d_size;
        d_wstrb_q <= d_wstrb;
        d_addr_q <= d_addr;
        d_wdata_q <= d_wdata;
        d_id_q <= d_id;
      end
    end
  end

  wire cache_quiescent = !i_req_q && !d_req_q && !lookup_valid &&
       (mshr_active == 2'b00) &&
       (resp_valid == 4'b0000) && !i_issue_valid && !d_issue_valid &&
       !write_order_valid;
  // snoop 优先于新的 CACOP，并在已有 I/D 上级请求排空后进行同步 tag 探测。
  wire accept_snoop = !init_active && snoop_req && cache_quiescent;
  wire accept_cacop = !init_active && cacop_req && !snoop_req &&
                      cache_quiescent;
  assign cacop_addr_ok = accept_cacop;
  assign snoop_addr_ok = accept_snoop;

  wire lookup_current_set_conflict =
       (mshr_active[0] && (mshr_index[0] == lookup_index) &&
        ({mshr_tag[0],mshr_index[0]} != {lookup_tag,lookup_index})) ||
       (mshr_active[1] && (mshr_index[1] == lookup_index) &&
        ({mshr_tag[1],mshr_index[1]} != {lookup_tag,lookup_index}));
  wire lookup_replay_fire = lookup_valid && !lookup_is_cacop &&
       lookup_needs_replay && !lookup_current_set_conflict &&
       !write_probe_pending;
  wire metadata_read_en = accept_normal_read || accept_d_write ||
                           accept_cacop || accept_snoop || lookup_replay_fire;
  wire [INDEX_BITS-1:0] metadata_read_index = accept_d_write ?
       d_addr_q[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS] :
       accept_snoop ?
       snoop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS] :
       accept_cacop ?
       cacop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS] :
       lookup_replay_fire ? lookup_index : selected_index;

  // ------------------------------------------------------------------------
  // Lookup 结果、替换、安装及 maintenance 仲裁
  // ------------------------------------------------------------------------
  wire hit0 = valid_r[0] && (tag_way0_r == lookup_tag);
  wire hit1 = valid_r[1] && (tag_way1_r == lookup_tag);
  wire hit2 = valid_r[2] && (tag_way2_r == lookup_tag);
  wire hit3 = valid_r[3] && (tag_way3_r == lookup_tag);
  wire lookup_hit = hit0 || hit1 || hit2 || hit3;
  wire [127:0] lookup_hit_line = hit0 ? data_way0_r :
                                      hit1 ? data_way1_r :
                                      hit2 ? data_way2_r : data_way3_r;
  wire [1:0] lookup_hit_way = hit0 ? 2'd0 :
                               hit1 ? 2'd1 :
                               hit2 ? 2'd2 : 2'd3;
  wire [3:0] lookup_hit_mask = {hit3,hit2,hit1,hit0};
  wire [1:0] plru_victim = !plru_r[2] ?
                           (!plru_r[1] ? 2'd0 : 2'd1) :
                           (!plru_r[0] ? 2'd2 : 2'd3);
  wire [1:0] lookup_victim = !valid_r[0] ? 2'd0 :
                             !valid_r[1] ? 2'd1 :
                             !valid_r[2] ? 2'd2 :
                             !valid_r[3] ? 2'd3 : plru_victim;
  wire mshr_has_free = !mshr_active[0] || !mshr_active[1];
  wire lookup_alloc_slot = mshr_active[0];
  wire lookup_hit_fire = lookup_valid && !lookup_is_cacop && lookup_hit;
  wire lookup_hit_plru_update = lookup_hit_fire && !lookup_is_prefetch;
  wire cacop_lookup_done = lookup_valid && lookup_is_cacop &&
                           !lookup_is_snoop;
  wire snoop_lookup_done = lookup_valid && lookup_is_snoop;
  assign cacop_data_ok = cacop_lookup_done;
  assign snoop_data_ok = snoop_lookup_done;
  wire snoop_update_fire = snoop_lookup_done && lookup_hit;
  wire [31:0] snoop_old_word =
       select_word(lookup_hit_line,lookup_start_word);
  wire [31:0] snoop_new_word =
       merge_store_word(snoop_old_word,lookup_snoop_wdata,
                        lookup_snoop_wstrb);
  wire [127:0] snoop_new_line =
       put_word(lookup_hit_line,lookup_start_word,snoop_new_word);

  wire install_valid = mshr_fill_complete[0] || mshr_fill_complete[1];
  // 安装仲裁只能依赖已寄存的 refill 状态。两个 fill 同时完成时，slot 0 具有
  // 确定的优先级。同拍的上级请求仍可与任一已完成缓存行合并，但不能通过
  // 很长的比较链控制 metadata 写地址。
  wire install_slot = !mshr_fill_complete[0];
  wire install_is_prefetch = install_slot ?
       mshr_is_prefetch[1] : mshr_is_prefetch[0];
  wire [INDEX_BITS-1:0] install_index = install_slot ?
       mshr_index[1] : mshr_index[0];
  wire [1:0] install_victim_way = install_slot ?
       mshr_victim_way[1] : mshr_victim_way[0];
  wire [3:0] install_valid_snapshot = install_slot ?
       mshr_valid_state[1] : mshr_valid_state[0];
  wire [2:0] install_plru_snapshot = install_slot ?
       mshr_plru_state[1] : mshr_plru_state[0];
  wire [3:0] install_valid_next = install_valid_snapshot |
       (4'b0001 << install_victim_way);
  wire [2:0] install_plru_next = install_is_prefetch ?
       plru_mark_lru(install_plru_snapshot,install_victim_way) :
       plru_mark_mru(install_plru_snapshot,install_victim_way);

  wire write_hit0 = valid_r[0] && (tag_way0_r == write_tag_q);
  wire write_hit1 = valid_r[1] && (tag_way1_r == write_tag_q);
  wire write_hit2 = valid_r[2] && (tag_way2_r == write_tag_q);
  wire write_hit3 = valid_r[3] && (tag_way3_r == write_tag_q);
  wire [3:0] write_hit_mask = {write_hit3,write_hit2,
                               write_hit1,write_hit0};
  // 安装操作独占单一 valid/PLRU 写端口。待处理的写探测会保留 valid_r/tag_r，
  // 直到后续周期可以执行失效操作。
  wire write_invalidate_fire = write_probe_pending && !install_valid;
  wire [3:0] cacop_index_mask = 4'b0001 << lookup_cacop_way;
  wire [3:0] cacop_invalidate_mask =
       ((lookup_cacop_code[4:3] == 2'b00) ||
        (lookup_cacop_code[4:3] == 2'b01)) ? cacop_index_mask :
       (lookup_cacop_code[4:3] == 2'b10) ? lookup_hit_mask : 4'b0000;

  // 单一显式 metadata 写端口。除了保证 BRAM 推断的确定性外，该优先级还与
  // 原始顺序更新次序完全一致：初始化、fill 安装、D-write 失效、CACOP，
  // 最后是替换状态维护。
  reg metadata_write_en;
  reg [INDEX_BITS-1:0] metadata_write_index;
  reg [6:0] metadata_write_data;
  always @(*) begin
    metadata_write_en = 1'b0;
    metadata_write_index = {INDEX_BITS{1'b0}};
    metadata_write_data = 7'b0;
    if (resetn) begin
      if (init_active) begin
        metadata_write_en = 1'b1;
        metadata_write_index = init_index;
        metadata_write_data = 7'b0;
      end else if (install_valid) begin
        metadata_write_en = 1'b1;
        metadata_write_index = install_index;
        metadata_write_data = {install_valid_next,install_plru_next};
      end else if (write_invalidate_fire && (|write_hit_mask)) begin
        metadata_write_en = 1'b1;
        metadata_write_index = write_index_q;
        metadata_write_data = {valid_r & ~write_hit_mask,plru_r};
      end else if (cacop_lookup_done && (|cacop_invalidate_mask)) begin
        metadata_write_en = 1'b1;
        metadata_write_index = lookup_index;
        metadata_write_data = {valid_r & ~cacop_invalidate_mask,plru_r};
      end else if (lookup_hit_plru_update) begin
        metadata_write_en = 1'b1;
        metadata_write_index = lookup_index;
        metadata_write_data =
            {valid_r,plru_mark_mru(plru_r,lookup_hit_way)};
      end
    end
  end

  // ------------------------------------------------------------------------
  // 稳定的下级请求输出和上级响应输出
  // ------------------------------------------------------------------------
  assign i_mem_req = i_issue_valid;
  assign i_mem_wr = 1'b0;
  assign i_mem_size = 2'b10;
  assign i_mem_wstrb = 4'b0000;
  assign i_mem_addr = i_issue_slot ?
       {mshr_tag[1],mshr_index[1],mshr_start_word[1],2'b00} :
       {mshr_tag[0],mshr_index[0],mshr_start_word[0],2'b00};
  assign i_mem_wdata = 32'b0;
  assign i_mem_id = i_issue_slot ? mshr_lower_id[1] : mshr_lower_id[0];
  wire i_issue_fire = i_issue_valid && i_mem_addr_ok;

  assign d_mem_req = write_pending_q || d_issue_valid;
  assign d_mem_wr = write_pending_q;
  assign d_mem_size = write_pending_q ? write_size_q : 2'b10;
  assign d_mem_wstrb = write_pending_q ? write_wstrb_q : 4'b0000;
  assign d_mem_addr = write_pending_q ? write_addr_q :
       d_issue_slot ?
       {mshr_tag[1],mshr_index[1],mshr_start_word[1],2'b00} :
       {mshr_tag[0],mshr_index[0],mshr_start_word[0],2'b00};
  assign d_mem_wdata = write_pending_q ? write_wdata_q : 32'b0;
  assign d_mem_id = write_pending_q ? write_id_q :
       d_issue_slot ? mshr_lower_id[1] : mshr_lower_id[0];
  wire write_issue_fire = write_pending_q && d_mem_addr_ok;
  wire d_issue_fire = !write_pending_q && d_issue_valid && d_mem_addr_ok;
  wire write_resp_fire = write_busy_q && d_mem_data_ok;

  // 写 B 响应在共享的 D 上级完成端口上具有优先级。准入规则使这种重叠在
  // 正常运行时不会发生；为读调度器增加门控可防御性地保证行为无损。
  wire d_emit_valid = d_pick_valid && !write_resp_fire;
  reg i_data_ok_q;
  reg [31:0] i_rdata_q;
  reg i_resp_id_q;
  reg d_data_ok_q;
  reg [31:0] d_rdata_q;
  reg d_resp_id_q;
  assign i_data_ok = i_data_ok_q;
  assign i_rdata = i_rdata_q;
  assign i_resp_id = i_resp_id_q;
  assign d_data_ok = d_data_ok_q;
  assign d_rdata = d_rdata_q;
  assign d_resp_id = d_resp_id_q;

  // 对两个上级响应端口都进行寄存。响应调度器仍能让每个来源每拍完成一个 beat；
  // 此边界只增加一拍 L2 命中延迟，并阻止其 select/round-robin 逻辑在同一
  // 时钟周期内穿过 L1 refill 数据通路进入 CPU 前端。
  always @(posedge clk) begin
    if (!resetn) begin
      i_data_ok_q <= 1'b0;
      i_rdata_q <= 32'b0;
      i_resp_id_q <= 1'b0;
      d_data_ok_q <= 1'b0;
      d_rdata_q <= 32'b0;
      d_resp_id_q <= 1'b0;
    end else begin
      i_data_ok_q <= i_emit_valid;
      if (i_emit_valid) begin
        i_rdata_q <= select_word(resp_line[i_emit_slot],
                                 resp_start_word[i_emit_slot] +
                                 resp_send_count[i_emit_slot]);
        i_resp_id_q <= resp_up_id[i_emit_slot];
      end
      d_data_ok_q <= write_resp_fire || d_emit_valid;
      if (write_resp_fire) begin
        d_rdata_q <= 32'b0;
        d_resp_id_q <= write_id_q;
      end else if (d_emit_valid) begin
        d_rdata_q <= select_word(resp_line[d_emit_slot],
                                 resp_start_word[d_emit_slot] +
                                 resp_send_count[d_emit_slot]);
        d_resp_id_q <= resp_up_id[d_emit_slot];
      end
    end
  end

  // 同缓存行消费者使用的快照。将与 addr_ok 同一时钟沿到达的下级 beat 纳入，
  // 确保较晚加入的消费者不会错过其 critical word。
  wire [127:0] selected_merge_line = selected_mshr_slot ?
       mshr1_line_next : mshr0_line_next;
  wire [3:0] selected_merge_word_valid = selected_mshr_slot ?
       mshr1_word_valid_next : mshr0_word_valid_next;
  wire selected_merge_complete = selected_mshr_slot ?
       (mshr_fill_complete[1] || mshr1_refill_last) :
       (mshr_fill_complete[0] || mshr0_refill_last);

  // Payload RAM 具有一个同步读端口和一个 fill 写端口。阻止同 set 不同缓存行
  // 的准入，以避免 read-during-write 歧义。
  always @(posedge clk) begin
    if (metadata_read_en) begin
      tag_way0_r <= tag_way0[metadata_read_index];
      tag_way1_r <= tag_way1[metadata_read_index];
      tag_way2_r <= tag_way2[metadata_read_index];
      tag_way3_r <= tag_way3[metadata_read_index];
      data_way0_r <= data_way0[metadata_read_index];
      data_way1_r <= data_way1[metadata_read_index];
      data_way2_r <= data_way2[metadata_read_index];
      data_way3_r <= data_way3[metadata_read_index];
    end

    if (install_valid) begin
      case (install_victim_way)
        2'd0: begin
          tag_way0[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_tag[1] : mshr_tag[0];
          data_way0[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_line[1] : mshr_line[0];
        end
        2'd1: begin
          tag_way1[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_tag[1] : mshr_tag[0];
          data_way1[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_line[1] : mshr_line[0];
        end
        2'd2: begin
          tag_way2[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_tag[1] : mshr_tag[0];
          data_way2[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_line[1] : mshr_line[0];
        end
        default: begin
          tag_way3[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_tag[1] : mshr_tag[0];
          data_way3[install_slot ? mshr_index[1] : mshr_index[0]] <=
              install_slot ? mshr_line[1] : mshr_line[0];
        end
      endcase
    end else if (snoop_update_fire) begin
      // snoop 只在 L2 完全静止时进入，因此不会与 refill 安装争用写端口。
      case (lookup_hit_way)
        2'd0: data_way0[lookup_index] <= snoop_new_line;
        2'd1: data_way1[lookup_index] <= snoop_new_line;
        2'd2: data_way2[lookup_index] <= snoop_new_line;
        default: data_way3[lookup_index] <= snoop_new_line;
      endcase
    end
  end

  // 简单双端口 metadata RAM：一拍内可同时进行一次同步 lookup 读取和一次
  // 独立寻址写入。准入规则可防止对正在安装的 set 发生读写冲突。
  always @(posedge clk) begin
    if (metadata_read_en)
      {valid_r,plru_r} <= metadata_mem[metadata_read_index];
    if (metadata_write_en)
      metadata_mem[metadata_write_index] <= metadata_write_data;
  end

  // 每拍初始化一个 metadata set，无需复位 BRAM 阵列。
  always @(posedge clk) begin
    if (!resetn) begin
      init_active <= 1'b1;
      init_index <= {INDEX_BITS{1'b0}};
    end else if (init_active) begin
      if (init_index == SET_COUNT - 1)
        init_active <= 1'b0;
      else
        init_index <= init_index + {{(INDEX_BITS-1){1'b0}},1'b1};
    end
  end

  integer q;
  integer m;
  always @(posedge clk) begin
    if (!resetn) begin
      lookup_valid <= 1'b0;
      lookup_is_cacop <= 1'b0;
      lookup_is_snoop <= 1'b0;
      lookup_is_d <= 1'b0;
      lookup_is_prefetch <= 1'b0;
      lookup_needs_replay <= 1'b0;
      lookup_up_id <= 1'b0;
      lookup_cacop_code <= 5'b0;
      lookup_cacop_way <= 2'b0;
      lookup_snoop_wstrb <= 4'b0;
      lookup_snoop_wdata <= 32'b0;
      lookup_tag <= {TAG_BITS{1'b0}};
      lookup_index <= {INDEX_BITS{1'b0}};
      lookup_start_word <= 2'b0;
      lookup_resp_slot <= 2'b0;

      mshr_active <= 2'b00;
      mshr_req_sent <= 2'b00;
      mshr_is_d <= 2'b00;
      mshr_lower_id <= 2'b00;
      mshr_is_prefetch <= 2'b00;
      mshr_fill_complete <= 2'b00;
      for (m = 0; m < MSHR_COUNT; m = m + 1) begin
        mshr_tag[m] <= {TAG_BITS{1'b0}};
        mshr_index[m] <= {INDEX_BITS{1'b0}};
        mshr_start_word[m] <= 2'b0;
        mshr_beat_count[m] <= 2'b0;
        mshr_word_valid[m] <= 4'b0000;
        mshr_line[m] <= 128'b0;
        mshr_victim_way[m] <= 2'b0;
        mshr_valid_state[m] <= 4'b0;
        mshr_plru_state[m] <= 3'b0;
      end

      i_issue_valid <= 1'b0;
      i_issue_slot <= 1'b0;
      d_issue_valid <= 1'b0;
      d_issue_slot <= 1'b0;

      resp_valid <= 4'b0000;
      resp_is_d <= 4'b0000;
      resp_up_id <= 4'b0000;
      resp_has_mshr <= 4'b0000;
      resp_mshr_id <= 4'b0000;
      i_resp_rr <= 2'b0;
      d_resp_rr <= 2'b0;
      for (q = 0; q < RESP_DEPTH; q = q + 1) begin
        resp_line_addr[q] <= {LINE_ADDR_BITS{1'b0}};
        resp_start_word[q] <= 2'b0;
        resp_send_count[q] <= 2'b0;
        resp_word_valid[q] <= 4'b0000;
        resp_line[q] <= 128'b0;
      end

      prefer_d <= 1'b1;
      write_pending_q <= 1'b0;
      write_busy_q <= 1'b0;
      write_id_q <= 1'b0;
      write_size_q <= 2'b0;
      write_wstrb_q <= 4'b0;
      write_addr_q <= 32'b0;
      write_wdata_q <= 32'b0;
      write_probe_pending <= 1'b0;
      write_index_q <= {INDEX_BITS{1'b0}};
      write_tag_q <= {TAG_BITS{1'b0}};
    end else begin
      // 每拍独立发出至多一个 I 响应 beat 和一个 D 响应 beat。
      if (i_emit_valid) begin
        resp_word_valid[i_emit_slot]
                       [resp_start_word[i_emit_slot] +
                        resp_send_count[i_emit_slot]] <= 1'b0;
        i_resp_rr <= i_emit_slot + 2'd1;
        if (resp_send_count[i_emit_slot] == 2'd3) begin
          resp_valid[i_emit_slot] <= 1'b0;
          resp_has_mshr[i_emit_slot] <= 1'b0;
          resp_send_count[i_emit_slot] <= 2'b0;
        end else
          resp_send_count[i_emit_slot] <=
              resp_send_count[i_emit_slot] + 2'd1;
      end
      if (d_emit_valid) begin
        resp_word_valid[d_emit_slot]
                       [resp_start_word[d_emit_slot] +
                        resp_send_count[d_emit_slot]] <= 1'b0;
        d_resp_rr <= d_emit_slot + 2'd1;
        if (resp_send_count[d_emit_slot] == 2'd3) begin
          resp_valid[d_emit_slot] <= 1'b0;
          resp_has_mshr[d_emit_slot] <= 1'b0;
          resp_send_count[d_emit_slot] <= 2'b0;
        end else
          resp_send_count[d_emit_slot] <=
              resp_send_count[d_emit_slot] + 2'd1;
      end

      // 无论上级响应如何调度，都捕获每个下级 beat。
      if (mshr0_refill_fire) begin
        mshr_line[0] <= mshr0_line_next;
        mshr_word_valid[0] <= mshr0_word_valid_next;
        if (mshr0_refill_last)
          mshr_fill_complete[0] <= 1'b1;
        else
          mshr_beat_count[0] <= mshr_beat_count[0] + 2'd1;
        for (q = 0; q < RESP_DEPTH; q = q + 1) begin
          if (resp_valid[q] && resp_has_mshr[q] &&
              !resp_mshr_id[q]) begin
            resp_line[q] <= put_word(resp_line[q],mshr0_refill_word,
                                     mshr0_refill_data);
            resp_word_valid[q][mshr0_refill_word] <= 1'b1;
          end
        end
      end
      if (mshr1_refill_fire) begin
        mshr_line[1] <= mshr1_line_next;
        mshr_word_valid[1] <= mshr1_word_valid_next;
        if (mshr1_refill_last)
          mshr_fill_complete[1] <= 1'b1;
        else
          mshr_beat_count[1] <= mshr_beat_count[1] + 2'd1;
        for (q = 0; q < RESP_DEPTH; q = q + 1) begin
          if (resp_valid[q] && resp_has_mshr[q] &&
              resp_mshr_id[q]) begin
            resp_line[q] <= put_word(resp_line[q],mshr1_refill_word,
                                     mshr1_refill_data);
            resp_word_valid[q][mshr1_refill_word] <= 1'b1;
          end
        end
      end

      // 对 miss 活跃期间仍允许发生的常驻行命中，保持替换快照一致。如果命中与
      // 安装发生在同一时钟沿，安装操作获得单一 metadata 写端口；最坏情况下
      // 只会丢失一个近似 PLRU 提示。安装地址和有效性仍只依赖随 MSHR 保存的状态。
      if (lookup_hit_plru_update) begin
        if (mshr_active[0] && (mshr_index[0] == lookup_index))
          mshr_plru_state[0] <=
              plru_mark_mru(mshr_plru_state[0],lookup_hit_way);
        if (mshr_active[1] && (mshr_index[1] == lookup_index))
          mshr_plru_state[1] <=
              plru_mark_mru(mshr_plru_state[1],lookup_hit_way);
      end

      // 安装发生在最后一个下级 beat 之后一拍，因此缓存行 payload 已包含全部
      // 四个字。响应项持有自己的副本，此后不再需要 MSHR。
      if (install_valid) begin
        mshr_active[install_slot] <= 1'b0;
        mshr_req_sent[install_slot] <= 1'b0;
        mshr_is_prefetch[install_slot] <= 1'b0;
        mshr_fill_complete[install_slot] <= 1'b0;
        mshr_word_valid[install_slot] <= 4'b0000;
        mshr_beat_count[install_slot] <= 2'b0;
        for (q = 0; q < RESP_DEPTH; q = q + 1) begin
          if (resp_valid[q] && resp_has_mshr[q] &&
            (resp_mshr_id[q] == install_slot)) begin
            resp_has_mshr[q] <= 1'b0;
          end
        end
      end

      // 稳定的下级读发射寄存器；当 demand MSHR 和纯 prefetch 同时等待同一
      // 来源端口时，优先选择 demand MSHR。
      if (i_issue_fire) begin
        mshr_req_sent[i_issue_slot] <= 1'b1;
        i_issue_valid <= 1'b0;
      end else if (!i_issue_valid) begin
        if (mshr_active[0] && !mshr_req_sent[0] && !mshr_is_d[0] &&
            !mshr_is_prefetch[0]) begin
          i_issue_valid <= 1'b1;
          i_issue_slot <= 1'b0;
        end else if (mshr_active[1] && !mshr_req_sent[1] &&
                     !mshr_is_d[1] && !mshr_is_prefetch[1]) begin
          i_issue_valid <= 1'b1;
          i_issue_slot <= 1'b1;
        end else if (mshr_active[0] && !mshr_req_sent[0] &&
                     !mshr_is_d[0]) begin
          i_issue_valid <= 1'b1;
          i_issue_slot <= 1'b0;
        end else if (mshr_active[1] && !mshr_req_sent[1] &&
                     !mshr_is_d[1]) begin
          i_issue_valid <= 1'b1;
          i_issue_slot <= 1'b1;
        end
      end
      if (d_issue_fire) begin
        mshr_req_sent[d_issue_slot] <= 1'b1;
        d_issue_valid <= 1'b0;
      end else if (!d_issue_valid && !write_order_valid) begin
        if (mshr_active[0] && !mshr_req_sent[0] && mshr_is_d[0]) begin
          d_issue_valid <= 1'b1;
          d_issue_slot <= 1'b0;
        end else if (mshr_active[1] && !mshr_req_sent[1] && mshr_is_d[1]) begin
          d_issue_valid <= 1'b1;
          d_issue_slot <= 1'b1;
        end
      end

      // 独立的 D 写上下文及其延迟执行的精确 tag 失效。
      if (accept_d_write) begin
        write_pending_q <= 1'b1;
        write_id_q <= d_id_q;
        write_size_q <= d_size_q;
        write_wstrb_q <= d_wstrb_q;
        write_addr_q <= d_addr_q;
        write_wdata_q <= d_wdata_q;
        write_index_q <= d_addr_q[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                      LINE_OFFSET_BITS];
        write_tag_q <= d_addr_q[31:LINE_OFFSET_BITS + INDEX_BITS];
        write_probe_pending <= 1'b1;
        prefer_d <= 1'b0;
      end
      if (write_issue_fire) begin
        write_pending_q <= 1'b0;
        write_busy_q <= 1'b1;
      end
      if (write_resp_fire)
        write_busy_q <= 1'b0;
      if (write_invalidate_fire)
        write_probe_pending <= 1'b0;

      // 处理 tag lookup。常驻行命中可立即参与调度；只有两个 MSHR 都被占用时，
      // miss 才原地等待。
      if (lookup_replay_fire)
        lookup_needs_replay <= 1'b0;
      if (lookup_valid) begin
        if (lookup_is_cacop) begin
          lookup_valid <= 1'b0;
          lookup_is_snoop <= 1'b0;
          lookup_needs_replay <= 1'b0;
        end else if (lookup_hit) begin
          resp_line[lookup_resp_slot] <= lookup_hit_line;
          resp_word_valid[lookup_resp_slot] <= 4'b1111;
          resp_has_mshr[lookup_resp_slot] <= 1'b0;
          lookup_valid <= 1'b0;
          lookup_needs_replay <= 1'b0;
        end else if (!lookup_needs_replay && mshr_has_free) begin
          mshr_active[lookup_alloc_slot] <= 1'b1;
          mshr_req_sent[lookup_alloc_slot] <= 1'b0;
          mshr_is_d[lookup_alloc_slot] <= lookup_is_d;
          mshr_lower_id[lookup_alloc_slot] <= lookup_up_id;
          mshr_is_prefetch[lookup_alloc_slot] <= lookup_is_prefetch;
          mshr_fill_complete[lookup_alloc_slot] <= 1'b0;
          mshr_tag[lookup_alloc_slot] <= lookup_tag;
          mshr_index[lookup_alloc_slot] <= lookup_index;
          mshr_start_word[lookup_alloc_slot] <= lookup_start_word;
          mshr_beat_count[lookup_alloc_slot] <= 2'b0;
          mshr_word_valid[lookup_alloc_slot] <= 4'b0000;
          mshr_line[lookup_alloc_slot] <= 128'b0;
          mshr_victim_way[lookup_alloc_slot] <= lookup_victim;
          mshr_valid_state[lookup_alloc_slot] <= valid_r;
          mshr_plru_state[lookup_alloc_slot] <= plru_r;
          resp_has_mshr[lookup_resp_slot] <= 1'b1;
          resp_mshr_id[lookup_resp_slot] <= lookup_alloc_slot;
          lookup_valid <= 1'b0;
          lookup_needs_replay <= 1'b0;
        end
      end

      // 仅当所有读/写/响应上下文均为空时才接收 CACOP。
      if (accept_cacop) begin
        lookup_valid <= 1'b1;
        lookup_is_cacop <= 1'b1;
        lookup_is_snoop <= 1'b0;
        lookup_is_d <= 1'b0;
        lookup_is_prefetch <= 1'b0;
        lookup_needs_replay <= 1'b0;
        lookup_cacop_code <= cacop_code;
        lookup_cacop_way <= cacop_addr[1:0];
        lookup_tag <= cacop_addr[31:LINE_OFFSET_BITS + INDEX_BITS];
        lookup_index <= cacop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                        LINE_OFFSET_BITS];
      end

      if (accept_snoop) begin
        // 内存中的新值已经生效，只更新命中的 clean L2 行；未命中无需分配。
        lookup_valid <= 1'b1;
        lookup_is_cacop <= 1'b1;
        lookup_is_snoop <= 1'b1;
        lookup_is_d <= 1'b0;
        lookup_is_prefetch <= 1'b0;
        lookup_needs_replay <= 1'b0;
        lookup_tag <= snoop_addr[31:LINE_OFFSET_BITS + INDEX_BITS];
        lookup_index <= snoop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                        LINE_OFFSET_BITS];
        lookup_start_word <= snoop_addr[3:2];
        lookup_snoop_wstrb <= snoop_wstrb;
        lookup_snoop_wdata <= snoop_wdata;
      end

      if (accept_read) begin
        resp_valid[resp_free_slot] <= 1'b1;
        resp_is_d[resp_free_slot] <= selected_is_d;
        resp_up_id[resp_free_slot] <= selected_up_id;
        resp_line_addr[resp_free_slot] <= selected_line_addr;
        resp_start_word[resp_free_slot] <= selected_addr[3:2];
        resp_send_count[resp_free_slot] <= 2'b0;
        prefer_d <= !selected_is_d;
        if (accept_merge) begin
          resp_line[resp_free_slot] <= selected_merge_line;
          resp_word_valid[resp_free_slot] <= selected_merge_word_valid;
          resp_has_mshr[resp_free_slot] <= !selected_merge_complete;
          resp_mshr_id[resp_free_slot] <= selected_mshr_slot;
          if (!selected_is_prefetch)
            mshr_is_prefetch[selected_mshr_slot] <= 1'b0;
        end else begin
          resp_line[resp_free_slot] <= 128'b0;
          resp_word_valid[resp_free_slot] <= 4'b0000;
          resp_has_mshr[resp_free_slot] <= 1'b0;
          resp_mshr_id[resp_free_slot] <= 1'b0;
          lookup_valid <= 1'b1;
          lookup_is_cacop <= 1'b0;
          lookup_is_snoop <= 1'b0;
          lookup_is_d <= selected_is_d;
          lookup_is_prefetch <= selected_is_prefetch;
          lookup_needs_replay <= selected_set_conflict;
          lookup_up_id <= selected_up_id;
          lookup_tag <= selected_tag;
          lookup_index <= selected_index;
          lookup_start_word <= selected_addr[3:2];
          lookup_resp_slot <= resp_free_slot;
        end
      end
    end
  end

`ifdef SIMULATION
  // 外部类 SRAM 接口的响应 beat 不带 ready，也没有 RLAST/RRESP sideband。
  // 在仿真中显式检查其固定四 beat、带 tag 的契约，使后续 bridge 修改在本地
  // 直接报错，而不是静默破坏缓存行。
  always @(posedge clk) begin
    if (resetn && !init_active) begin
      if ((mshr0_i_return && mshr1_i_return) ||
          (mshr0_d_return && mshr1_d_return))
        $fatal(1,"L2 protocol error: duplicate live lower source/ID");
      if (i_mem_data_ok && !(mshr0_i_return || mshr1_i_return))
        $fatal(1,"L2 protocol error: unmatched I lower response");
      if (d_mem_data_ok && !(mshr0_d_return || mshr1_d_return ||
                             write_resp_fire))
        $fatal(1,"L2 protocol error: unmatched D lower response");
      if (i_emit_valid &&
          !resp_word_valid[i_emit_slot]
                          [resp_start_word[i_emit_slot] +
                           resp_send_count[i_emit_slot]])
        $fatal(1,"L2 protocol error: emitted unavailable I word");
      if (d_emit_valid &&
          !resp_word_valid[d_emit_slot]
                          [resp_start_word[d_emit_slot] +
                           resp_send_count[d_emit_slot]])
        $fatal(1,"L2 protocol error: emitted unavailable D word");
      if (install_valid &&
          ((install_slot ? mshr_word_valid[1] : mshr_word_valid[0]) !=
           4'b1111))
        $fatal(1,"L2 protocol error: installed incomplete refill line");
      if (write_busy_q &&
          (any_d_response || any_d_lower_mshr || d_issue_valid))
        $fatal(1,"L2 protocol error: D read overlaps write response");
      if (i_buffer_pop && !i_req_q)
        $fatal(1,"L2 protocol error: popped an empty I skid buffer");
      if (d_buffer_pop && !d_req_q)
        $fatal(1,"L2 protocol error: popped an empty D skid buffer");
      if (accept_cacop && (i_req_q || d_req_q))
        $fatal(1,"L2 protocol error: CACOP bypassed an accepted request");
    end
  end
`endif

endmodule
