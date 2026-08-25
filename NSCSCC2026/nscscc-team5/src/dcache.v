// =============================================================================
// dcache.v - 两路组相联、写回写分配（write-back/write-allocate）数据缓存
// =============================================================================
// 默认组织：2048 set x 2 way x 16 byte = 64 KiB。地址拆分为
// {tag, set index, line offset[3:0]}，每行含 4 个 32 位字。
//
// CPU 侧采用无 transaction ID 的类 SRAM 两阶段握手：addr_ok 表示请求字段已
// 被缓存接收，data_ok 表示对应请求完成。请求/响应严格保序。主 FSM 处理命中、
// dirty victim 四字回写、critical-word-first WRAP refill 和 CACOP；额外的第二
// MSHR 可在主 refill 期间处理不同 set 的 clean-victim miss。四项 hot-line
// 寄存器缓存最近访问行，用于缩短反复读命中的时延，但不改变 BRAM 中的权威状态。
//
// 下级接口一次只传一个 32 位 beat。读 miss 用同一 mem_id 连续返回四拍；写回
// 则逐字发起四个写事务。mem_req 拉高后地址/数据/id 必须保持，直到 mem_addr_ok；
// mem_data_ok 表示读 beat 或写响应完成。ID0 属于主 FSM，ID1 属于次级 MSHR。
// =============================================================================
module dcache #(
    parameter integer INDEX_BITS = 11 // set 索引位数；容量随 2^INDEX_BITS 线性变化。
) (
    input  wire        clk,
    input  wire        resetn,

    // CPU 类 SRAM 接口。wr=0 为读，wr=1 为写；wstrb 每位控制一个字节 lane。
    input  wire        req,
    input  wire        wr,
    input  wire [31:0] addr,
    input  wire [ 3:0] wstrb,
    input  wire [31:0] wdata,
    // CACOP 是串行化维护请求；code[4:3] 决定按索引/按命中方式失效或写回失效。
    input  wire        cacop_req,
    input  wire [ 4:0] cacop_code,
    input  wire [31:0] cacop_addr,
    output reg         cacop_addr_ok,
    output reg         cacop_data_ok,
    output wire        addr_ok,
    output wire        data_ok,
    output wire [31:0] rdata,

    // 内存接口（单次地址握手；缓存行 refill 为 4 beat，writeback 为四个单拍写）。
    output reg         mem_req,
    output reg         mem_wr,
    output wire [ 1:0] mem_size,
    output reg  [ 3:0] mem_wstrb,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output wire        mem_id,
    input  wire        mem_addr_ok,
    input  wire        mem_data_ok,
    input  wire [31:0] mem_rdata,
    input  wire        mem_resp_id
  );

  // 固定 16 B 行使 offset 为 4 位；TAG_BITS 由总地址位数扣除 index/offset 得到。
  localparam integer LINE_OFFSET_BITS = 4;
  localparam integer TAG_BITS = 32 - INDEX_BITS - LINE_OFFSET_BITS;
  localparam integer SET_COUNT = 1 << INDEX_BITS;

  // 主状态机：
  //   INIT -> IDLE -> LOOKUP；命中后回 IDLE。
  //   dirty miss: WB_REQ <-> WB_WAIT 共四字，再进入 RD_REQ/RD_WAIT。
  //   clean miss: 直接 RD_REQ/RD_WAIT，收完后 PREP/WRITE 安装整行。
  //   CACOP dirty 目标走专用 WB 状态，最终完成失效；其余直接 CACOP_INV。
  localparam S_IDLE          = 4'd0;
  localparam S_LOOKUP        = 4'd1;
  localparam S_WB_REQ        = 4'd4;
  localparam S_WB_WAIT       = 4'd5;
  localparam S_RD_REQ        = 4'd6;
  localparam S_RD_WAIT       = 4'd7;
  localparam S_REFILL_PREP   = 4'd8;
  localparam S_REFILL_WRITE  = 4'd9;
  localparam S_CACOP_WB_REQ  = 4'd10;
  localparam S_CACOP_WB_WAIT = 4'd11;
  localparam S_CACOP_INV     = 4'd13;
  localparam S_INIT          = 4'd14;

  reg [3:0] state; // 当前主事务的唯一状态；未列出的编码由 default 恢复到 IDLE。

  // CPU/CACOP 请求在 addr_ok 所在时钟沿锁存；之后上游可改变输入而不影响事务。
  reg        req_is_cacop;
  reg        req_op;
  reg [INDEX_BITS-1:0] req_index;
  reg [TAG_BITS-1:0] req_tag;
  reg [ 3:0] req_offset;
  reg [ 3:0] req_wstrb;
  reg [31:0] req_wdata;
  reg [ 4:0] req_cacop_code;
  reg        req_cacop_way;

  // 当组数为 2048 时，每路的 17 位 tag 恰好可放入一个 RAMB36。将两路的
  // valid/dirty 状态和替换位打包进一个窄位宽的简单双端口 metadata BRAM。
  // 布局为 {way1_valid,way1_dirty,way0_valid,way0_dirty,mru_way}。
  // 复位后每拍清除一组，从而避免宽复位网络和分布式 RAM 译码器。
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way0 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way1 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [4:0] metadata_mem [0:SET_COUNT-1];

  (* ram_style = "block" *) reg [127:0] data_way0 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way1 [0:SET_COUNT-1];

  reg [TAG_BITS-1:0] tag_way0_r;
  reg [TAG_BITS-1:0] tag_way1_r;
  reg [4:0] metadata_ram_r;
  reg       metadata_bypass_r;
  reg [4:0] metadata_bypass_data_r;
  wire [4:0] metadata_r = metadata_bypass_r ?
                          metadata_bypass_data_r : metadata_ram_r;
  wire [1:0] state_way1_r = metadata_r[4:3];
  wire [1:0] state_way0_r = metadata_r[2:1];
  wire       valid_way0_r = state_way0_r[1];
  wire       valid_way1_r = state_way1_r[1];
  wire       dirty_way0_r = state_way0_r[0];
  wire       dirty_way1_r = state_way1_r[0];
  wire       mru_way_r = metadata_r[0];
  reg [127:0] data_way0_ram_r;
  reg [127:0] data_way1_ram_r;
  reg         data_way0_bypass_r;
  reg         data_way1_bypass_r;
  reg [127:0] data_bypass_line_r;
  wire [127:0] data_way0_r = data_way0_bypass_r ?
                              data_bypass_line_r : data_way0_ram_r;
  wire [127:0] data_way1_r = data_way1_bypass_r ?
                              data_bypass_line_r : data_way1_ram_r;

  // 主 miss/refill 上下文。start_word 记录 WRAP burst 的 critical word，rd_cnt
  // 是返回 beat 序号；word_valid 允许完整行安装前命中已经返回的字。
  reg        replace_way;
  reg [ 1:0] rd_cnt;
  reg [127:0] refill_line;
  reg [127:0] final_line;
  reg [ 1:0] refill_start_word;
  reg [ 3:0] refill_word_valid;
  reg         miss_response_sent;
  reg         refill_dirty;
  reg [4:0]   refill_metadata_snapshot;
  // CPU 数据侧请求跟踪器只在观察到 addr_ok 后才将请求标记为在途。
  // 将 refill buffer 命中的 data_ok 延迟一拍，避免 addr_ok/data_ok 同拍时
  // 被误认为旧响应。
  reg         refill_cpu_resp_pending;
  reg [31:0]  refill_cpu_resp_data;
  // 所有 CPU 响应都跨越寄存器边界。常驻行命中的 tag 比较结果不能以组合逻辑
  // 直接驱动 data_ok：data_ok 会控制 LQ、WBQ、流水线使能和前端 credit，
  // 否则将形成远超 90 MHz 时序预算的 cache-BRAM-to-IFQ 路径。
  // lookup 流水线仍可每拍接收一次命中，因此独立命中的吞吐率仍为 1。
  reg         data_ok_q;
  reg [31:0]  rdata_q;

  // 用寄存器保存最近访问的完整缓存行。当缓存空闲时到达的读请求，可在接收请求的
  // 时钟沿直接由这些触发器响应，比 BRAM tag/data lookup 提前一拍，
  // 同时无需将 BRAM 输出重新以组合逻辑连接到 CPU 控制路径。
  reg         hot_line_valid;
  reg [27:0]  hot_line_addr;
  reg [127:0] hot_line_data;
  reg         hot_line1_valid;
  reg [27:0]  hot_line1_addr;
  reg [127:0] hot_line1_data;
  reg         hot_line2_valid;
  reg [27:0]  hot_line2_addr;
  reg [127:0] hot_line2_data;
  reg         hot_line3_valid;
  reg [27:0]  hot_line3_addr;
  reg [127:0] hot_line3_data;

  // 第二个 MSHR 先覆盖最常见的 clean read miss。主 miss critical word
  // 已返回后，可对不同 set 发起一次后台 lookup：resident hit 直接完成，
  // clean-victim miss 使用 AXI read ID 1 与主 refill(ID 0)并行。
  reg         under_lookup_valid;
  reg [INDEX_BITS-1:0] under_index;
  reg [TAG_BITS-1:0] under_tag;
  reg [3:0]   under_offset;
  reg         under_op;
  reg [3:0]   under_wstrb;
  reg [31:0]  under_wdata;
  reg         mshr1_active;
  reg [INDEX_BITS-1:0] mshr1_index;
  reg [TAG_BITS-1:0] mshr1_tag;
  reg         mshr1_way;
  reg [1:0]   mshr1_start_word;
  reg [1:0]   mshr1_rd_cnt;
  reg [127:0] mshr1_line;
  reg         mshr1_op;
  reg [3:0]   mshr1_wstrb;
  reg [31:0]  mshr1_wdata;
  reg         mshr1_response_sent;
  reg         mshr1_refill_complete;
  reg [4:0]   mshr1_metadata_snapshot;
  reg         mem_id_q;

  // 写回上下文锁存 victim 的完整行和基地址，避免后续 BRAM 读口变化影响事务。
  // wb_cnt 选择当前 32 位字；主 miss 与 CACOP 共用这组寄存器。
  reg        wb_way;
  reg [ 1:0] wb_cnt;
  reg [31:0] wb_base_addr;
  reg [127:0] wb_line;
  reg        cacop_inv_valid;
  reg        cacop_inv_way;
  reg [INDEX_BITS-1:0] init_index;
  reg        under_replay_pending;

  // 当前上游地址与 CACOP 地址的 tag/index/offset 分解。
  wire [INDEX_BITS-1:0] index =
       addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS];
  wire [TAG_BITS-1:0] tag = addr[31:LINE_OFFSET_BITS + INDEX_BITS];
  wire [ 3:0] offset      = addr[3:0];
  wire [INDEX_BITS-1:0] cacop_index =
       cacop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS];
  wire [TAG_BITS-1:0] cacop_tag =
       cacop_addr[31:LINE_OFFSET_BITS + INDEX_BITS];
  wire        cacop_way   = cacop_addr[0];

  wire        way0_valid = valid_way0_r;
  wire        way1_valid = valid_way1_r;
  wire [TAG_BITS-1:0] way0_tag = tag_way0_r;
  wire [TAG_BITS-1:0] way1_tag = tag_way1_r;
  wire        way0_hit   = way0_valid && (way0_tag == req_tag);
  wire        way1_hit   = way1_valid && (way1_tag == req_tag);
  wire        hit        = way0_hit || way1_hit;
  wire        hit_way    = way1_hit;
  wire [127:0] hit_line  = hit_way ? data_way1_r : data_way0_r;

  // 请求准入分三类：IDLE 新请求、命中完成同拍的流水请求、以及主 refill 期间
  // 可由 refill buffer/次级 lookup 服务的请求。所有 addr_ok 条件均保证响应保序。
  wire lookup_cpu_hit = (state == S_LOOKUP) && !req_is_cacop && hit;
  wire accept_replay_lookup = (state == S_IDLE) &&
                              !mshr1_active && under_replay_pending;
  wire accept_cacop_lookup = (state == S_IDLE) &&
                             !mshr1_active && !under_replay_pending &&
                             cacop_req;
  wire accept_idle_cpu = (state == S_IDLE) &&
                          !mshr1_active && !under_replay_pending &&
                          !cacop_req && req;
  wire idle_hot0_read_hit = accept_idle_cpu && !wr &&
                            hot_line_valid &&
                            (hot_line_addr == addr[31:4]);
  wire idle_hot1_read_hit = accept_idle_cpu && !wr &&
                            hot_line1_valid &&
                            (hot_line1_addr == addr[31:4]);
  wire idle_hot2_read_hit = accept_idle_cpu && !wr &&
                            hot_line2_valid &&
                            (hot_line2_addr == addr[31:4]);
  wire idle_hot3_read_hit = accept_idle_cpu && !wr &&
                            hot_line3_valid &&
                            (hot_line3_addr == addr[31:4]);
  wire idle_hot_read_hit = idle_hot0_read_hit || idle_hot1_read_hit ||
                           idle_hot2_read_hit || idle_hot3_read_hit;
  // 常驻行命中完成的同时，下一个请求开始同步 tag/data 读取。发生 miss 时
  // addr_ok 保持为低，因此后续请求无法越过尚未解决的 miss，响应严格保序。
  wire accept_hit_pipeline = lookup_cpu_hit && !mshr1_active &&
                             !under_replay_pending &&
                             !cacop_req && req;
  wire accept_cpu_lookup = accept_idle_cpu || accept_hit_pipeline;
  wire refill_line_match =
       (addr[31:LINE_OFFSET_BITS] == {req_tag,req_index});
  wire accept_refill_cpu   = (state == S_RD_WAIT) &&
                             miss_response_sent &&
                             !refill_cpu_resp_pending &&
                             !under_lookup_valid && !under_replay_pending &&
                             !mshr1_active &&
                             !cacop_req && req &&
                             refill_line_match &&
                             refill_word_valid[addr[3:2]];
  wire accept_under_cpu = (state == S_RD_WAIT) &&
                          miss_response_sent &&
                          !refill_cpu_resp_pending &&
                          !under_lookup_valid && !under_replay_pending &&
                          !mshr1_active &&
                          !cacop_req && req &&
                          !refill_line_match && (index != req_index);
  assign addr_ok = accept_cpu_lookup || accept_refill_cpu ||
                   accept_under_cpu;
  wire [INDEX_BITS-1:0] read_index =
       accept_replay_lookup ? under_index :
       accept_cacop_lookup ? cacop_index :
       (accept_cpu_lookup || accept_under_cpu) ? index : req_index;
  wire metadata_read_en = accept_replay_lookup || accept_cacop_lookup ||
                          accept_cpu_lookup || accept_under_cpu;

  // 两路近似 LRU：metadata 保存最近使用路 mru_way，替换另一条路；无效路优先。
  wire lru_way = !mru_way_r;
  wire alloc_way = !way0_valid ? 1'b0 :
                   !way1_valid ? 1'b1 :
                                 lru_way;
  wire alloc_valid = alloc_way ? way1_valid : way0_valid;
  wire alloc_dirty = alloc_way ? dirty_way1_r : dirty_way0_r;
  wire [TAG_BITS-1:0] alloc_tag = alloc_way ? way1_tag : way0_tag;
  wire [127:0] alloc_line = alloc_way ? data_way1_r : data_way0_r;

  wire under_way0_hit = valid_way0_r && (tag_way0_r == under_tag);
  wire under_way1_hit = valid_way1_r && (tag_way1_r == under_tag);
  wire under_hit = under_way0_hit || under_way1_hit;
  wire under_hit_way = under_way1_hit;
  wire [127:0] under_hit_line = under_way1_hit ? data_way1_r : data_way0_r;
  // 次级 MSHR 无法接纳 dirty victim。仅一路为 clean 时优先选择该路；
  // 两路 dirty 状态相同时选择真正的 LRU 路，而不是把每个 clean/dirty
  // 组合都偏向 way0。
  wire under_alloc_way = !valid_way0_r ? 1'b0 :
                         !valid_way1_r ? 1'b1 :
                         ( dirty_way0_r && !dirty_way1_r) ? 1'b1 :
                         (!dirty_way0_r &&  dirty_way1_r) ? 1'b0 :
                                                           lru_way;
  wire under_alloc_dirty = under_alloc_way ? dirty_way1_r : dirty_way0_r;

  wire cacop_hit_mode = req_cacop_code[4:3] == 2'b10;
  wire cacop_target_hit = cacop_hit_mode ? hit : 1'b1;
  wire cacop_target_way = cacop_hit_mode ? hit_way : req_cacop_way;
  wire cacop_target_valid = cacop_target_way ? way1_valid : way0_valid;
  wire cacop_target_dirty = cacop_target_way ? dirty_way1_r : dirty_way0_r;
  wire [TAG_BITS-1:0] cacop_target_tag =
       cacop_target_way ? way1_tag : way0_tag;
  wire [127:0] cacop_target_line = cacop_target_way ? data_way1_r : data_way0_r;

  // BRAM 写端口仲裁后的统一控制。data/tag/metadata 的各更新来源在后面的组合块
  // 中按确定优先级合并，避免同一 always 块里出现不可综合的多个写端口模板。
  reg        data_we;
  reg        data_we_way;
  reg [INDEX_BITS-1:0] data_we_index;
  reg [127:0] data_we_line;
  reg        tag_we_way0;
  reg        tag_we_way1;
  reg [INDEX_BITS-1:0] tag_we_index_way0;
  reg [INDEX_BITS-1:0] tag_we_index_way1;
  reg [TAG_BITS-1:0] tag_we_data_way0;
  reg [TAG_BITS-1:0] tag_we_data_way1;

  // 从 128 位缓存行选择 offset 指定的 32 位自然对齐字。
  function [31:0] select_word;
    input [127:0] line;
    input [1:0]   off;
    begin
      case (off)
        2'd0:
          select_word = line[31:0];
        2'd1:
          select_word = line[63:32];
        2'd2:
          select_word = line[95:64];
        default:
          select_word = line[127:96];
      endcase
    end
  endfunction

  // 返回替换指定 32 位字后的整条缓存行，其他 96 位保持不变。
  function [127:0] set_word;
    input [127:0] line;
    input [1:0]   off;
    input [31:0]  word;
    begin
      set_word = line;
      case (off)
        2'd0:
          set_word[31:0] = word;
        2'd1:
          set_word[63:32] = word;
        2'd2:
          set_word[95:64] = word;
        default:
          set_word[127:96] = word;
      endcase
    end
  endfunction

  // 按 4 位 byte-enable 合并 store 数据；mask[n] 对应字节 [8*n +: 8]。
  function [31:0] merge_word;
    input [31:0] old_word;
    input [31:0] new_word;
    input [3:0]  mask;
    begin
      merge_word[7:0]   = mask[0] ? new_word[7:0]   : old_word[7:0];
      merge_word[15:8]  = mask[1] ? new_word[15:8]  : old_word[15:8];
      merge_word[23:16] = mask[2] ? new_word[23:16] : old_word[23:16];
      merge_word[31:24] = mask[3] ? new_word[31:24] : old_word[31:24];
    end
  endfunction

  // 先选中目标字、做字节合并，再写回 128 位行；用于 store hit 与 store miss。
  function [127:0] merge_store;
    input [127:0] line;
    input [1:0]   off;
    input [3:0]   mask;
    input [31:0]  word;
    reg [31:0] old_word;
    reg [31:0] new_word;
    begin
      old_word = select_word(line, off);
      new_word = merge_word(old_word, word, mask);
      merge_store = set_word(line, off, new_word);
    end
  endfunction

  // 把一个下级返回 beat 放入 refill 行的自然 word 位置。
  function [127:0] line_with_ret;
    input [127:0] line;
    input [1:0]   cnt;
    input [31:0]  word;
    begin
      line_with_ret = line;
      case (cnt)
        2'd0:
          line_with_ret[31:0] = word;
        2'd1:
          line_with_ret[63:32] = word;
        2'd2:
          line_with_ret[95:64] = word;
        default:
          line_with_ret[127:96] = word;
      endcase
    end
  endfunction

  // 从 victim 行选择当前要写回的字，wb_cnt=0..3 对应低字到高字。
  function [31:0] wb_word;
    input [127:0] line;
    input [1:0]   cnt;
    begin
      case (cnt)
        2'd0:
          wb_word = line[31:0];
        2'd1:
          wb_word = line[63:32];
        2'd2:
          wb_word = line[95:64];
        default:
          wb_word = line[127:96];
      endcase
    end
  endfunction

  assign data_ok = data_ok_q;
  assign rdata = rdata_q;

  // Cache refill 是从请求字开始的 AXI 四 beat WRAP burst。
  // 将每个返回 beat 映射回其在缓存行中的自然位置。
  wire primary_mem_data_ok = mem_data_ok && !mem_resp_id;
  wire [1:0] refill_word_index = refill_start_word + rd_cnt;
  wire [127:0] refill_after_mem =
       primary_mem_data_ok ? line_with_ret(refill_line,refill_word_index,mem_rdata) :
                     refill_line;
  wire [127:0] refill_after_primary_store =
       (primary_mem_data_ok && !miss_response_sent && req_op) ?
       merge_store(refill_after_mem,req_offset[3:2],req_wstrb,req_wdata) :
       refill_after_mem;
  wire [127:0] refill_cycle_next =
       (accept_refill_cpu && wr) ?
       merge_store(refill_after_primary_store,addr[3:2],wstrb,wdata) :
       refill_after_primary_store;
  wire [31:0] critical_store_word =
       merge_word(mem_rdata,req_wdata,req_wstrb);

  wire mshr1_mem_data_ok = mem_data_ok && mem_resp_id && mshr1_active;
  wire [1:0] mshr1_refill_word_index =
       mshr1_start_word + mshr1_rd_cnt;
  wire [127:0] mshr1_line_after_mem =
       line_with_ret(mshr1_line,mshr1_refill_word_index,mem_rdata);
  wire [127:0] mshr1_line_next =
       (mshr1_mem_data_ok && !mshr1_response_sent && mshr1_op) ?
       merge_store(mshr1_line_after_mem,mshr1_start_word,
                   mshr1_wstrb,mshr1_wdata) : mshr1_line_after_mem;
  wire mshr1_install = mshr1_mem_data_ok && (mshr1_rd_cnt == 2'd3);
  wire store_hit_fire = (state == S_LOOKUP) && !req_is_cacop &&
                        hit && req_op;
  wire under_store_hit_fire = under_lookup_valid && under_hit && under_op;
  wire primary_install_fire = (state == S_REFILL_WRITE);
  wire normal_wb_last_fire = (state == S_WB_WAIT) && mem_data_ok &&
                             (wb_cnt == 2'd3);
  wire cacop_inv_fire = (state == S_CACOP_INV) && cacop_inv_valid;
  wire cacop_wb_last_fire = (state == S_CACOP_WB_WAIT) && mem_data_ok &&
                            (wb_cnt == 2'd3);
  // 已完成的次级 refill 会继续缓冲，直到所有 data/tag/state 写端口可用。
  // 单拍 FSM 副作用具有更高优先级。
  wire mshr1_commit_fire = mshr1_refill_complete &&
                           (state != S_INIT) &&
                           !store_hit_fire && !under_store_hit_fire &&
                            !primary_install_fire && !normal_wb_last_fire &&
                           !cacop_inv_fire && !cacop_wb_last_fire;

  // Data RAM 单写端口优先级：主/次级 store hit > 主 refill 安装 > 次级安装。
  // 上层保证冲突来源不会同时需要架构完成；确定优先级仍使综合和仿真行为明确。
  always @(*)
  begin
    data_we       = 1'b0;
    data_we_way   = 1'b0;
    data_we_index = req_index;
    data_we_line  = 128'b0;
    if (store_hit_fire)
    begin
      data_we       = 1'b1;
      data_we_way   = hit_way;
      data_we_index = req_index;
      data_we_line  = merge_store(hit_line, req_offset[3:2], req_wstrb, req_wdata);
    end
    else if (under_store_hit_fire)
    begin
      data_we       = 1'b1;
      data_we_way   = under_hit_way;
      data_we_index = under_index;
      data_we_line  = merge_store(under_hit_line,under_offset[3:2],
                                  under_wstrb,under_wdata);
    end
    else if (primary_install_fire)
    begin
      data_we       = 1'b1;
      data_we_way   = replace_way;
      data_we_index = req_index;
      data_we_line  = final_line;
    end
    else if (mshr1_commit_fire)
    begin
      data_we       = 1'b1;
      data_we_way   = mshr1_way;
      data_we_index = mshr1_index;
      data_we_line  = mshr1_line;
    end
  end

  // 将所有安装来源合并到每个 tag 路的单一物理写端口。
  // 保持唯一的写使能/地址/数据元组，使 Vivado 能将较深的 tag 阵列推断为
  // block RAM，而不是将其复制为 LUTRAM。
  always @(*)
  begin
    tag_we_way0 = 1'b0;
    tag_we_way1 = 1'b0;
    tag_we_index_way0 = req_index;
    tag_we_index_way1 = req_index;
    tag_we_data_way0 = req_tag;
    tag_we_data_way1 = req_tag;
    if (primary_install_fire)
    begin
      if (replace_way)
        tag_we_way1 = 1'b1;
      else
        tag_we_way0 = 1'b1;
    end
    else if (mshr1_commit_fire)
    begin
      if (mshr1_way)
      begin
        tag_we_way1 = 1'b1;
        tag_we_index_way1 = mshr1_index;
        tag_we_data_way1 = mshr1_tag;
      end
      else
      begin
        tag_we_way0 = 1'b1;
        tag_we_index_way0 = mshr1_index;
        tag_we_data_way0 = mshr1_tag;
      end
    end
  end

  // 使用单一 metadata 写端口替代原先三个 LUTRAM 写网络。Fill 提交使用
  // miss 分配时捕获的快照，因为届时实时同步读输出可能已属于其他 set。
  // 次级 fill 提交的优先级高于同拍的 load 命中 MRU 更新；丢失这种少见的
  // 替换提示没有影响，但缓存行有效性不能丢失。
  // metadata 更新同时承担 valid、dirty 和 MRU 维护。优先级从高到低为初始化、
  // store hit、主安装、回写清 dirty、CACOP 失效、次级安装、普通读命中 MRU。
  reg metadata_write_en;
  reg [INDEX_BITS-1:0] metadata_write_index;
  reg [4:0] metadata_write_data;
  always @(*) begin
    metadata_write_en = 1'b0;
    metadata_write_index = {INDEX_BITS{1'b0}};
    metadata_write_data = 5'b0;
    if (resetn) begin
      if (state == S_INIT) begin
        metadata_write_en = 1'b1;
        metadata_write_index = init_index;
        metadata_write_data = 5'b0;
      end else if (store_hit_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = req_index;
        metadata_write_data = metadata_r;
        metadata_write_data[0] = hit_way;
        if (hit_way)
          metadata_write_data[4:3] = 2'b11;
        else
          metadata_write_data[2:1] = 2'b11;
      end else if (under_store_hit_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = under_index;
        metadata_write_data = metadata_r;
        metadata_write_data[0] = under_hit_way;
        if (under_hit_way)
          metadata_write_data[4:3] = 2'b11;
        else
          metadata_write_data[2:1] = 2'b11;
      end else if (primary_install_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = req_index;
        metadata_write_data = refill_metadata_snapshot;
        metadata_write_data[0] = replace_way;
        if (replace_way)
          metadata_write_data[4:3] = {1'b1,refill_dirty};
        else
          metadata_write_data[2:1] = {1'b1,refill_dirty};
      end else if (normal_wb_last_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = req_index;
        metadata_write_data = metadata_r;
        if (wb_way)
          metadata_write_data[3] = 1'b0;
        else
          metadata_write_data[1] = 1'b0;
      end else if (cacop_inv_fire || cacop_wb_last_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = req_index;
        metadata_write_data = metadata_r;
        if (cacop_inv_fire ? cacop_inv_way : wb_way)
          metadata_write_data[4:3] = 2'b00;
        else
          metadata_write_data[2:1] = 2'b00;
      end else if (mshr1_commit_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = mshr1_index;
        metadata_write_data = mshr1_metadata_snapshot;
        metadata_write_data[0] = mshr1_way;
        if (mshr1_way)
          metadata_write_data[4:3] = {1'b1,mshr1_op};
        else
          metadata_write_data[2:1] = {1'b1,mshr1_op};
      end else if (lookup_cpu_hit) begin
        metadata_write_en = 1'b1;
        metadata_write_index = req_index;
        metadata_write_data = metadata_r;
        metadata_write_data[0] = hit_way;
      end else if (under_lookup_valid && under_hit) begin
        metadata_write_en = 1'b1;
        metadata_write_index = under_index;
        metadata_write_data = metadata_r;
        metadata_write_data[0] = under_hit_way;
      end
    end
  end

  always @(posedge clk)
  begin
    // 将阵列端口保持为标准的简单双端口 BRAM 形式。下方的寄存器旁路提供
    // 确定性的 write-first 行为，无需在 RAM 读取赋值中嵌入 mux。
    data_way0_ram_r <= data_way0[read_index];
    data_way1_ram_r <= data_way1[read_index];
    data_way0_bypass_r <= data_we && !data_we_way &&
                          (data_we_index == read_index);
    data_way1_bypass_r <= data_we && data_we_way &&
                          (data_we_index == read_index);
    data_bypass_line_r <= data_we_line;

    if (metadata_read_en)
    begin
      tag_way0_r <= tag_way0[read_index];
      tag_way1_r <= tag_way1[read_index];
      metadata_ram_r <= metadata_mem[read_index];
      metadata_bypass_r <= metadata_write_en &&
                           (metadata_write_index == read_index);
      metadata_bypass_data_r <= metadata_write_data;
    end

    if (data_we && !data_we_way)
      data_way0[data_we_index] <= data_we_line;
    if (data_we && data_we_way)
      data_way1[data_we_index] <= data_we_line;

    if (tag_we_way0)
      tag_way0[tag_we_index_way0] <= tag_we_data_way0;
    if (tag_we_way1)
      tag_way1[tag_we_index_way1] <= tag_we_data_way1;

    if (metadata_write_en)
      metadata_mem[metadata_write_index] <= metadata_write_data;
  end

  // 在 hot-line MRU 栈之前合并四个完整缓存行更新来源。优先级与原顺序赋值
  // 一致：次级 MSHR 提交高于主安装、miss 下命中和普通 lookup。
  // 保持原优先级 mshr1 > primary > under > lookup，但在每个来源本地完成
  // 地址比较，避免先经过宽地址 mux 再驱动 hot-line 更新使能。
  wire hot_update_from_mshr1 = mshr1_commit_fire;
  wire hot_update_from_primary = !mshr1_commit_fire && primary_install_fire;
  wire hot_update_from_under = !mshr1_commit_fire && !primary_install_fire &&
       under_lookup_valid && under_hit;
  wire hot_update_from_lookup = !mshr1_commit_fire && !primary_install_fire &&
       !(under_lookup_valid && under_hit) && lookup_cpu_hit;
  wire hot_update_valid = hot_update_from_mshr1 || hot_update_from_primary ||
       hot_update_from_under || hot_update_from_lookup;

  wire [27:0] hot_lookup_addr = {req_tag,req_index};
  wire [27:0] hot_under_addr = {under_tag,under_index};
  wire [27:0] hot_primary_addr = {req_tag,req_index};
  wire [27:0] hot_mshr1_addr = {mshr1_tag,mshr1_index};
  wire [127:0] hot_lookup_data = req_op ?
       merge_store(hit_line,req_offset[3:2],req_wstrb,req_wdata) : hit_line;
  wire [127:0] hot_under_data = under_op ?
       merge_store(under_hit_line,under_offset[3:2],under_wstrb,under_wdata) :
       under_hit_line;
  wire [27:0] hot_update_addr = hot_update_from_mshr1 ? hot_mshr1_addr :
       hot_update_from_primary ? hot_primary_addr :
       hot_update_from_under ? hot_under_addr : hot_lookup_addr;
  wire [127:0] hot_update_data = hot_update_from_mshr1 ? mshr1_line :
       hot_update_from_primary ? final_line :
       hot_update_from_under ? hot_under_data : hot_lookup_data;

  // keep 阻止综合器重新合并成“地址 mux 后统一比较”的原始长路径。
  (* keep = "true" *) wire hot_update_match0 = hot_line_valid &&
       ((hot_update_from_mshr1 && (hot_line_addr == hot_mshr1_addr)) ||
        (hot_update_from_primary && (hot_line_addr == hot_primary_addr)) ||
        (hot_update_from_under && (hot_line_addr == hot_under_addr)) ||
        (hot_update_from_lookup && (hot_line_addr == hot_lookup_addr)));
  (* keep = "true" *) wire hot_update_match1 = hot_line1_valid &&
       ((hot_update_from_mshr1 && (hot_line1_addr == hot_mshr1_addr)) ||
        (hot_update_from_primary && (hot_line1_addr == hot_primary_addr)) ||
        (hot_update_from_under && (hot_line1_addr == hot_under_addr)) ||
        (hot_update_from_lookup && (hot_line1_addr == hot_lookup_addr)));
  (* keep = "true" *) wire hot_update_match2 = hot_line2_valid &&
       ((hot_update_from_mshr1 && (hot_line2_addr == hot_mshr1_addr)) ||
        (hot_update_from_primary && (hot_line2_addr == hot_primary_addr)) ||
        (hot_update_from_under && (hot_line2_addr == hot_under_addr)) ||
        (hot_update_from_lookup && (hot_line2_addr == hot_lookup_addr)));

  // CPU 复位已由 SoC 复位桥同步到 cpu_clk。保持缓存控制复位为同步形式，
  // 使 BRAM 地址/写控制不由 FDCE 异步控制寄存器驱动（REQP-1839/1840）。
  always @(posedge clk)
  begin
    if (!resetn)
    begin
      state          <= S_INIT;
      req_is_cacop   <= 1'b0;
      req_op         <= 1'b0;
      req_index      <= {INDEX_BITS{1'b0}};
      req_tag        <= {TAG_BITS{1'b0}};
      req_offset     <= 4'b0;
      req_wstrb      <= 4'b0;
      req_wdata      <= 32'b0;
      req_cacop_code <= 5'b0;
      req_cacop_way  <= 1'b0;
      data_ok_q      <= 1'b0;
      cacop_addr_ok  <= 1'b0;
      cacop_data_ok  <= 1'b0;
      rdata_q        <= 32'b0;
      hot_line_valid <= 1'b0;
      hot_line_addr  <= 28'b0;
      hot_line_data  <= 128'b0;
      hot_line1_valid <= 1'b0;
      hot_line1_addr  <= 28'b0;
      hot_line1_data  <= 128'b0;
      hot_line2_valid <= 1'b0;
      hot_line2_addr  <= 28'b0;
      hot_line2_data  <= 128'b0;
      hot_line3_valid <= 1'b0;
      hot_line3_addr  <= 28'b0;
      hot_line3_data  <= 128'b0;
      mem_req        <= 1'b0;
      mem_wr         <= 1'b0;
      mem_wstrb      <= 4'b0;
      mem_addr       <= 32'b0;
      mem_wdata      <= 32'b0;
      replace_way    <= 1'b0;
      rd_cnt         <= 2'b0;
      refill_line    <= 128'b0;
      final_line     <= 128'b0;
      refill_start_word <= 2'b0;
      refill_word_valid <= 4'b0;
      miss_response_sent <= 1'b0;
      refill_dirty   <= 1'b0;
      refill_metadata_snapshot <= 5'b0;
      refill_cpu_resp_pending <= 1'b0;
      refill_cpu_resp_data <= 32'b0;
      under_lookup_valid <= 1'b0;
      under_index <= {INDEX_BITS{1'b0}};
      under_tag <= {TAG_BITS{1'b0}};
      under_offset <= 4'b0;
      under_op <= 1'b0;
      under_wstrb <= 4'b0;
      under_wdata <= 32'b0;
      mshr1_active <= 1'b0;
      mshr1_index <= {INDEX_BITS{1'b0}};
      mshr1_tag <= {TAG_BITS{1'b0}};
      mshr1_way <= 1'b0;
      mshr1_start_word <= 2'b0;
      mshr1_rd_cnt <= 2'b0;
      mshr1_line <= 128'b0;
      mshr1_op <= 1'b0;
      mshr1_wstrb <= 4'b0;
      mshr1_wdata <= 32'b0;
      mshr1_response_sent <= 1'b0;
      mshr1_refill_complete <= 1'b0;
      mshr1_metadata_snapshot <= 5'b0;
      mem_id_q <= 1'b0;
      wb_way         <= 1'b0;
      wb_cnt         <= 2'b0;
      wb_base_addr   <= 32'b0;
      wb_line        <= 128'b0;
      cacop_inv_valid <= 1'b0;
      cacop_inv_way   <= 1'b0;
      init_index <= {INDEX_BITS{1'b0}};
      under_replay_pending <= 1'b0;
    end
    else
    begin
      data_ok_q     <= refill_cpu_resp_pending;
      cacop_addr_ok <= 1'b0;
      cacop_data_ok <= 1'b0;
      if (refill_cpu_resp_pending)
        rdata_q <= refill_cpu_resp_data;
      refill_cpu_resp_pending <= 1'b0;

      // Cache maintenance 是串行化操作，因此在 CACOP 被接收后立即使所有
      // 寄存器副本失效是一种保守处理。
      if (accept_cacop_lookup)
      begin
        hot_line_valid <= 1'b0;
        hot_line1_valid <= 1'b0;
        hot_line2_valid <= 1'b0;
        hot_line3_valid <= 1'b0;
      end
      else if (hot_update_valid)
      begin
        hot_line_valid <= 1'b1;
        hot_line_addr <= hot_update_addr;
        hot_line_data <= hot_update_data;
        if (!hot_update_match0)
        begin
          hot_line1_valid <= hot_line_valid;
          hot_line1_addr <= hot_line_addr;
          hot_line1_data <= hot_line_data;
          if (!hot_update_match1)
          begin
            hot_line2_valid <= hot_line1_valid;
            hot_line2_addr <= hot_line1_addr;
            hot_line2_data <= hot_line1_data;
            if (!hot_update_match2)
            begin
              hot_line3_valid <= hot_line2_valid;
              hot_line3_addr <= hot_line2_addr;
              hot_line3_data <= hot_line2_data;
            end
          end
        end
      end
      else if (idle_hot1_read_hit)
      begin
        hot_line_valid <= hot_line1_valid;
        hot_line_addr <= hot_line1_addr;
        hot_line_data <= hot_line1_data;
        hot_line1_valid <= hot_line_valid;
        hot_line1_addr <= hot_line_addr;
        hot_line1_data <= hot_line_data;
      end
      else if (idle_hot2_read_hit)
      begin
        hot_line_valid <= hot_line2_valid;
        hot_line_addr <= hot_line2_addr;
        hot_line_data <= hot_line2_data;
        hot_line1_valid <= hot_line_valid;
        hot_line1_addr <= hot_line_addr;
        hot_line1_data <= hot_line_data;
        hot_line2_valid <= hot_line1_valid;
        hot_line2_addr <= hot_line1_addr;
        hot_line2_data <= hot_line1_data;
      end
      else if (idle_hot3_read_hit)
      begin
        hot_line_valid <= hot_line3_valid;
        hot_line_addr <= hot_line3_addr;
        hot_line_data <= hot_line3_data;
        hot_line1_valid <= hot_line_valid;
        hot_line1_addr <= hot_line_addr;
        hot_line1_data <= hot_line_data;
        hot_line2_valid <= hot_line1_valid;
        hot_line2_addr <= hot_line1_addr;
        hot_line2_data <= hot_line1_data;
        hot_line3_valid <= hot_line2_valid;
        hot_line3_addr <= hot_line2_addr;
        hot_line3_data <= hot_line2_data;
      end

      if (accept_under_cpu)
      begin
        under_lookup_valid <= 1'b1;
        under_index <= index;
        under_tag <= tag;
        under_offset <= offset;
        under_op <= wr;
        under_wstrb <= wstrb;
        under_wdata <= wdata;
      end

      if (under_lookup_valid)
      begin
        if (under_hit)
        begin
          refill_cpu_resp_pending <= 1'b1;
          refill_cpu_resp_data <= under_op ? 32'b0 :
              select_word(under_hit_line,under_offset[3:2]);
        end
        else if (!under_alloc_dirty)
        begin
          mshr1_active <= 1'b1;
          mshr1_index <= under_index;
          mshr1_tag <= under_tag;
          mshr1_way <= under_alloc_way;
          mshr1_start_word <= under_offset[3:2];
          mshr1_rd_cnt <= 2'b0;
          mshr1_line <= 128'b0;
          mshr1_op <= under_op;
          mshr1_wstrb <= under_wstrb;
          mshr1_wdata <= under_wdata;
          mshr1_response_sent <= 1'b0;
          mshr1_refill_complete <= 1'b0;
          mshr1_metadata_snapshot <= metadata_r;
          mem_req <= 1'b1;
          mem_wr <= 1'b0;
          mem_wstrb <= 4'b1111;
          mem_addr <= {under_tag,under_index,under_offset[3:2],2'b0};
          mem_wdata <= 32'b0;
          mem_id_q <= 1'b1;
        end
        else
          under_replay_pending <= 1'b1;
        under_lookup_valid <= 1'b0;
      end

      if (mshr1_mem_data_ok)
      begin
        mshr1_line <= mshr1_line_next;
        if (!mshr1_response_sent)
        begin
          refill_cpu_resp_pending <= 1'b1;
          refill_cpu_resp_data <= mshr1_op ? 32'b0 : mem_rdata;
          mshr1_response_sent <= 1'b1;
        end
        if (mshr1_rd_cnt == 2'd3)
          mshr1_refill_complete <= 1'b1;
        else
          mshr1_rd_cnt <= mshr1_rd_cnt + 2'd1;
      end

      if (mshr1_commit_fire)
      begin
        mshr1_active <= 1'b0;
        mshr1_refill_complete <= 1'b0;
      end

      if (mem_req && mem_addr_ok)
        mem_req <= 1'b0;

      // 主 FSM 每个状态只拥有一类外部副作用。mem_req 在地址握手前保持；收到
      // mem_data_ok 后才推进 beat 计数或转移到下一阶段。
      case (state)
        S_INIT:
        begin
          // 数据/tag 内容无需清零；逐组把 metadata 的 valid/dirty 清 0 即可。
          if (init_index == SET_COUNT-1)
          begin
            init_index <= {INDEX_BITS{1'b0}};
            state <= S_IDLE;
          end
          else
            init_index <= init_index + {{(INDEX_BITS-1){1'b0}},1'b1};
        end

        S_IDLE:
        begin
          // 准入优先级：因 dirty victim 退回的 replay > CACOP > 新 CPU 请求。
          // hot-line 读命中在此直接寄存响应，否则启动同步 BRAM lookup。
          if (accept_replay_lookup)
          begin
            req_is_cacop <= 1'b0;
            req_op       <= under_op;
            req_index    <= under_index;
            req_tag      <= under_tag;
            req_offset   <= under_offset;
            req_wstrb    <= under_wstrb;
            req_wdata    <= under_wdata;
            under_replay_pending <= 1'b0;
            state        <= S_LOOKUP;
          end
          else if (accept_cacop_lookup)
          begin
            req_is_cacop   <= 1'b1;
            req_op         <= 1'b0;
            req_index      <= cacop_index;
            req_tag        <= cacop_tag;
            req_offset     <= cacop_addr[3:0];
            req_wstrb      <= 4'b0;
            req_wdata      <= 32'b0;
            req_cacop_code <= cacop_code;
            req_cacop_way  <= cacop_way;
            cacop_addr_ok  <= 1'b1;
            state          <= S_LOOKUP;
          end
          else if (accept_idle_cpu)
          begin
            if (idle_hot_read_hit)
            begin
              data_ok_q <= 1'b1;
              rdata_q <= select_word(idle_hot3_read_hit ? hot_line3_data :
                                     (idle_hot2_read_hit ? hot_line2_data :
                                      (idle_hot1_read_hit ? hot_line1_data :
                                                           hot_line_data)),
                                     offset[3:2]);
              state <= S_IDLE;
            end
            else
            begin
              req_is_cacop <= 1'b0;
              req_op       <= wr;
              req_index    <= index;
              req_tag      <= tag;
              req_offset   <= offset;
              req_wstrb    <= wstrb;
              req_wdata    <= wdata;
              state        <= S_LOOKUP;
            end
          end
        end

        S_LOOKUP:
        begin
          // 同步 tag/data 输出在此消费。CACOP 与普通 CPU 访问分流；普通命中
          // 可同拍接收下一请求，miss 则先选择 victim，必要时写回再 refill。
          if (req_is_cacop)
          begin
            case (req_cacop_code[4:3])
              2'b00:
              begin
                cacop_inv_valid <= 1'b1;
                cacop_inv_way <= req_cacop_way;
                state <= S_CACOP_INV;
              end

              2'b01,
              2'b10:
              begin
                if (cacop_target_hit && cacop_target_valid && cacop_target_dirty)
                begin
                  wb_way       <= cacop_target_way;
                  wb_cnt       <= 2'b0;
                  wb_base_addr <= {cacop_target_tag, req_index, 4'b0};
                  wb_line      <= cacop_target_line;
                  mem_req      <= 1'b1;
                  mem_id_q     <= 1'b0;
                  mem_wr       <= 1'b1;
                  mem_wstrb    <= 4'b1111;
                  mem_addr     <= {cacop_target_tag, req_index, 4'b0};
                  mem_wdata    <= wb_word(cacop_target_line, 2'b0);
                  state        <= S_CACOP_WB_REQ;
                end
                else
                begin
                  cacop_inv_valid <= cacop_target_hit && cacop_target_valid;
                  cacop_inv_way <= cacop_target_way;
                  state <= S_CACOP_INV;
                end
              end

              default:
              begin
                cacop_data_ok <= 1'b1;
                state <= S_IDLE;
              end
            endcase
          end
            else if (hit)
            begin
              data_ok_q <= 1'b1;
              if (!req_op)
                rdata_q <= select_word(hit_line, req_offset[3:2]);

              if (accept_hit_pipeline)
            begin
              req_is_cacop <= 1'b0;
              req_op       <= wr;
              req_index    <= index;
              req_tag      <= tag;
              req_offset   <= offset;
              req_wstrb    <= wstrb;
              req_wdata    <= wdata;
              state        <= S_LOOKUP;
            end
            else
              state <= S_IDLE;
          end
          else
          begin
            replace_way <= alloc_way;
            refill_metadata_snapshot <= metadata_r;
            refill_start_word <= req_offset[3:2];
            refill_word_valid <= 4'b0;
            miss_response_sent <= 1'b0;
            refill_dirty <= req_op;
            if (alloc_valid && alloc_dirty)
            begin
              wb_way       <= alloc_way;
              wb_cnt       <= 2'b0;
              wb_base_addr <= {alloc_tag, req_index, 4'b0};
              wb_line      <= alloc_line;
              mem_req      <= 1'b1;
              mem_id_q     <= 1'b0;
              mem_wr       <= 1'b1;
              mem_wstrb    <= 4'b1111;
              mem_addr     <= {alloc_tag, req_index, 4'b0};
              mem_wdata    <= wb_word(alloc_line, 2'b0);
              state        <= S_WB_REQ;
            end
            else
            begin
              rd_cnt <= 2'b0;
              refill_line <= 128'b0;
              mem_req <= 1'b1;
              mem_id_q <= 1'b0;
              mem_wr <= 1'b0;
              mem_wstrb <= 4'b1111;
              mem_addr <= {req_tag,req_index,req_offset[3:2],2'b0};
              mem_wdata <= 32'b0;
              state <= S_RD_REQ;
            end
          end
        end

        S_CACOP_INV:
        begin
          // metadata 组合写口已在本拍清除目标 valid/dirty；随后向上游确认完成。
          cacop_inv_valid <= 1'b0;
          cacop_data_ok <= 1'b1;
          state <= S_IDLE;
        end

        S_WB_REQ:
        begin
          // 等待当前 victim 字的写地址/数据被下级接收。
          if (mem_addr_ok)
          begin
            mem_req <= 1'b0;
            state <= S_WB_WAIT;
          end
        end

        S_WB_WAIT:
        begin
          // 等待当前字写响应；前三字继续发下一写请求，第四字后开始读 refill。
          if (mem_data_ok)
          begin
            if (wb_cnt == 2'd3)
            begin
              rd_cnt <= 2'b0;
              refill_line <= 128'b0;
              refill_word_valid <= 4'b0;
              mem_req <= 1'b1;
              mem_id_q <= 1'b0;
              mem_wr <= 1'b0;
              mem_wstrb <= 4'b1111;
              mem_addr <= {req_tag,req_index,req_offset[3:2],2'b0};
              mem_wdata <= 32'b0;
              state <= S_RD_REQ;
            end
            else
            begin
              wb_cnt <= wb_cnt + 2'd1;
              mem_req <= 1'b1;
              mem_id_q <= 1'b0;
              mem_wr <= 1'b1;
              mem_wstrb <= 4'b1111;
              mem_addr <= wb_base_addr + {28'b0, wb_cnt + 2'd1, 2'b0};
              mem_wdata <= wb_word(wb_line, wb_cnt + 2'd1);
              state <= S_WB_REQ;
            end
          end
        end

        S_RD_REQ:
        begin
          // miss 读请求只做一次地址握手；下级随后返回固定四个 WRAP beat。
          if (mem_addr_ok)
          begin
            mem_req <= 1'b0;
            state <= S_RD_WAIT;
          end
        end

        S_RD_WAIT:
        begin
          // critical word 首拍即可 data_ok；余下 beat 继续填充 refill_line。
          // 同缓存行且所需字已返回的年轻请求也可从 buffer 获得延迟响应。
          if (accept_refill_cpu)
          begin
            refill_cpu_resp_pending <= 1'b1;
            refill_cpu_resp_data <= wr ? 32'b0 :
                                    select_word(refill_line,addr[3:2]);
            if (wr)
              refill_dirty <= 1'b1;
          end

          if (primary_mem_data_ok)
          begin
            refill_word_valid[refill_word_index] <= 1'b1;
            // 第一个 WRAP beat 是原始 load/store 字。立即合并 store 并确认
            // 已提交的 store buffer；load 同样可以在无需等待完整缓存行时重启。
            if (!miss_response_sent)
            begin
              if (!req_op)
                rdata_q <= mem_rdata;
              else
                rdata_q <= critical_store_word;
              data_ok_q <= 1'b1;
              miss_response_sent <= 1'b1;
            end
            if (rd_cnt == 2'd3)
              state <= S_REFILL_PREP;
            else
              rd_cnt <= rd_cnt + 2'd1;
          end

          if (primary_mem_data_ok || (accept_refill_cpu && wr))
            refill_line <= refill_cycle_next;
        end

        S_REFILL_PREP:
        begin
          // 单独一拍冻结最终行，切断 AXI 返回组合逻辑到 BRAM 写数据路径。
          final_line <= refill_line;
          state <= S_REFILL_WRITE;
        end

        S_REFILL_WRITE:
        begin
          // 统一写端口把 final_line/tag/metadata 安装到 victim way，然后释放 FSM。
          // 正常 WRAP 操作已在 beat 0 响应。为独立或不符合规范的内存模型
          // 保留 fallback，但绝不能重复响应。
          if (!miss_response_sent)
          begin
            if (!req_op)
              rdata_q <= select_word(final_line,req_offset[3:2]);
            data_ok_q <= 1'b1;
          end
          state <= S_IDLE;
        end

        S_CACOP_WB_REQ:
        begin
          // CACOP dirty 行写回的地址握手阶段，与普通 miss 写回分开便于完成语义。
          if (mem_addr_ok)
          begin
            mem_req <= 1'b0;
            state <= S_CACOP_WB_WAIT;
          end
        end

        S_CACOP_WB_WAIT:
        begin
          // 第四个写响应到达时，metadata 写口同步使目标行无效并产生 data_ok。
          if (mem_data_ok)
          begin
            if (wb_cnt == 2'd3)
            begin
              cacop_data_ok <= 1'b1;
              state <= S_IDLE;
            end
            else
            begin
              wb_cnt <= wb_cnt + 2'd1;
              mem_req <= 1'b1;
              mem_id_q <= 1'b0;
              mem_wr <= 1'b1;
              mem_wstrb <= 4'b1111;
              mem_addr <= wb_base_addr + {28'b0, wb_cnt + 2'd1, 2'b0};
              mem_wdata <= wb_word(wb_line, wb_cnt + 2'd1);
              state <= S_CACOP_WB_REQ;
            end
          end
        end

        default:
          state <= S_IDLE;
      endcase
    end
  end

  assign mem_size = 2'b10;
  assign mem_id = mem_id_q;

endmodule
