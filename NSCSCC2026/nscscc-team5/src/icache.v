// icache.v - 两路组相联、非阻塞指令缓存。
//
// 默认组织：1024 set x 2 way x 16 byte = 32 KiB。地址划分为
// {tag, index[INDEX_BITS-1:0], line offset[3:0]}，每行含 4 条 32 位指令。
// 缓存为只读、read-allocate；wr/wstrb/wdata 保留在统一类 SRAM 接口中，正常
// 取指不会使用。有效位与 MRU 位打包进 metadata BRAM，tag/data 不需要复位，
// 上电后逐 set 清 metadata 即可使所有旧内容不可见。
//
// 常驻行命中路径每拍可接收一个请求。两个带 tag 的 MSHR 允许不同缓存行并发
// refill；即使 AXI 乱序返回两个 ID，四项完成队列也能使类 SRAM CPU 响应流
// 严格按照请求顺序返回。当另一个 miss 尚未完成时，命中常驻行或任一 refill
// buffer 中有效字的请求仍可继续执行。
//
// 下级读采用 critical-word-first 的四拍 WRAP burst：mem_addr 指向请求字，随后
// 返回的四个 beat 按模 4 次序填入缓存行。mem_id 标识两个 MSHR，返回时由
// mem_resp_id 选择上下文。mem_req/payload 必须保持到 mem_addr_ok 握手完成。
module icache #(
    parameter integer INDEX_BITS = 10
) (
    input  wire        clk,
    input  wire        resetn,

    // CPU 类 SRAM 请求/响应。addr_ok 接收一个请求；data_ok/rdata 按接收顺序返回。
    input  wire        req,
    input  wire        wr,       // 接口兼容字段；正常取指恒为 0。
    input  wire [31:0] addr,
    input  wire [ 3:0] wstrb,
    input  wire [31:0] wdata,
    // uncached RAM store 完成后的旁路一致性更新。只修改命中的字，不分配新行。
    input  wire        snoop_req,
    input  wire [31:0] snoop_addr,
    input  wire [ 3:0] snoop_wstrb,
    input  wire [31:0] snoop_wdata,
    output wire        snoop_addr_ok,
    output reg         snoop_data_ok,
    // 串行 CACOP 维护接口；等待全部 MSHR/响应排空后才接收。
    input  wire        cacop_req,
    input  wire [ 4:0] cacop_code,
    input  wire [31:0] cacop_addr,
    output wire        cacop_addr_ok,
    output reg         cacop_data_ok,
    output wire        addr_ok,
    output wire        data_ok,
    output wire [31:0] rdata,

    // L2/内存侧类 SRAM 接口；mem_prefetch 标记纯推测的 next-line 请求。
    output reg         mem_req,
    output reg         mem_wr,
    output wire [ 1:0] mem_size,
    output reg  [ 3:0] mem_wstrb,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output wire        mem_id,
    output wire        mem_prefetch,
    input  wire        mem_addr_ok,
    input  wire        mem_data_ok,
    input  wire [31:0] mem_rdata,
    input  wire        mem_resp_id
  );

  // 固定行宽、容量派生量以及并发上下文深度。
  localparam integer LINE_OFFSET_BITS = 4;
  localparam integer TAG_BITS = 32 - INDEX_BITS - LINE_OFFSET_BITS;
  localparam integer LINE_ADDR_BITS = 32 - LINE_OFFSET_BITS;
  localparam integer SET_COUNT = 1 << INDEX_BITS;
  localparam integer MSHR_COUNT = 2;
  localparam integer RESP_DEPTH = 4;

  // 单项同步 lookup 流水寄存器。请求被 addr_ok 接收后，tag/index/offset、类型、
  // 对应响应槽及可能匹配的 MSHR hint 都在这里保持到查询解决。
  reg        lookup_valid;
  reg        lookup_is_cacop;
  reg        lookup_is_snoop;
  reg        lookup_is_pf_probe;
  reg [INDEX_BITS-1:0] lookup_index;
  reg [TAG_BITS-1:0] lookup_tag;
  reg [ 3:0] lookup_offset;
  reg [ 4:0] lookup_cacop_code;
  reg        lookup_cacop_way;
  reg [ 3:0] lookup_snoop_wstrb;
  reg [31:0] lookup_snoop_wdata;
  reg [ 1:0] lookup_resp_slot;
  reg        lookup_mshr_hint_valid;
  reg        lookup_mshr_hint;
  // 同步阵列在 refill 安装与新 lookup 同拍访问同一 set 时呈现旧数据。
  // 记录这一极少见的端口碰撞，下一拍从已经安装完成的阵列重读；正常
  // hit/miss 吞吐和 addr_ok 路径不受影响。
  reg        lookup_array_collision;

  // Tag/data 和紧凑的替换 metadata 均采用同步 RAM。复位后每拍初始化一个 set；
  // 阵列元素均不带异步复位，因此 Vivado 可以使用一个窄位宽 RAMB18，
  // 而不是 2048 个有效位触发器加一个分布式 RAM 写译码器。
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way0 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [TAG_BITS-1:0] tag_way1 [0:SET_COUNT-1];
  // 布局：{valid_way1,valid_way0,mru_way}。
  (* ram_style = "block" *) reg [2:0] metadata_mem [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way0 [0:SET_COUNT-1];
  (* ram_style = "block" *) reg [127:0] data_way1 [0:SET_COUNT-1];
  reg [TAG_BITS-1:0] tag_way0_r;
  reg [TAG_BITS-1:0] tag_way1_r;
  reg [127:0] data_way0_r;
  reg [127:0] data_way1_r;
  reg [2:0] metadata_ram_r;
  reg       metadata_bypass_r;
  reg [2:0] metadata_bypass_data_r;
  wire [2:0] metadata_r = metadata_bypass_r ?
                          metadata_bypass_data_r : metadata_ram_r;
  wire valid_way1_r = metadata_r[2];
  wire valid_way0_r = metadata_r[1];
  wire mru_way_r = metadata_r[0];

  reg init_active;
  reg [INDEX_BITS-1:0] init_index;

  wire way0_valid = valid_way0_r;
  wire way1_valid = valid_way1_r;
  wire way0_hit = way0_valid && (tag_way0_r == lookup_tag);
  wire way1_hit = way1_valid && (tag_way1_r == lookup_tag);
  wire lookup_hit = way0_hit || way1_hit;
  wire [127:0] lookup_hit_line = way1_hit ? data_way1_r : data_way0_r;

  // 每个 MSHR 保存一条在途缓存行。start_word+rd_cnt（模 4）给出当前返回字，
  // word_valid 支持 critical word 尚未装入常驻阵列前直接服务合并 demand。
  reg [1:0] mshr_active;
  reg [1:0] mshr_req_sent;
  reg [TAG_BITS-1:0] mshr_tag[0:MSHR_COUNT-1];
  reg [INDEX_BITS-1:0] mshr_index[0:MSHR_COUNT-1];
  reg        mshr_way[0:MSHR_COUNT-1];
  reg [1:0]  mshr_start_word[0:MSHR_COUNT-1];
  reg [1:0]  mshr_rd_cnt[0:MSHR_COUNT-1];
  reg [3:0]  mshr_word_valid[0:MSHR_COUNT-1];
  reg [127:0] mshr_line[0:MSHR_COUNT-1];
  reg [1:0]  mshr_valid_state[0:MSHR_COUNT-1];
  reg [1:0]  mshr_is_prefetch;
  // 推测请求会保持其下一级 prefetch 属性稳定，但当 CPU demand 与其合并后，
  // 将作为普通常驻行安装。
  reg [1:0]  mshr_demanded;
  reg         mem_req_slot;

  // 单一 next-line stream buffer。只有两个 demand 上下文都空闲时，prefetch
  // 才使用 MSHR1，因此 MSHR0 始终可供后续 demand miss 使用。独立 prefetch
  // 不会创建 CPU 完成队列项或 data_ok 脉冲。demand 使用该 buffer 后，
  // 完整缓存行将提升为 L1 常驻存储。
  reg                      pf_candidate_valid;
  reg [LINE_ADDR_BITS-1:0] pf_candidate_line;
  reg                      pf_buffer_valid;
  reg [LINE_ADDR_BITS-1:0] pf_buffer_line;
  reg [127:0]              pf_buffer_data;

  // 有序完成队列：分配顺序等于 CPU addr_ok 顺序。ready 表示数据已捕获；
  // wait_mshr/mshr_id/word 描述尚在等待哪个 refill 字。只有 head 可产生 data_ok。
  reg [RESP_DEPTH-1:0] resp_valid;
  reg [RESP_DEPTH-1:0] resp_ready;
  reg [31:0] resp_data[0:RESP_DEPTH-1];
  reg [RESP_DEPTH-1:0] resp_wait_mshr;
  reg [RESP_DEPTH-1:0] resp_mshr_id;
  reg [1:0] resp_word[0:RESP_DEPTH-1];
  reg [1:0] resp_head;
  reg [1:0] resp_tail;
  reg [2:0] resp_count;

  // 从 128 位行选择一个 32 位指令字。
  function [31:0] select_word;
    input [127:0] line;
    input [1:0] off;
    begin
      case (off)
        2'd0: select_word = line[31:0];
        2'd1: select_word = line[63:32];
        2'd2: select_word = line[95:64];
        default: select_word = line[127:96];
      endcase
    end
  endfunction

  // 将一个下级返回 beat 写入行缓冲的指定自然 word 位置。
  function [127:0] line_with_ret;
    input [127:0] line;
    input [1:0] word_index;
    input [31:0] word;
    begin
      line_with_ret = line;
      case (word_index)
        2'd0: line_with_ret[31:0] = word;
        2'd1: line_with_ret[63:32] = word;
        2'd2: line_with_ret[95:64] = word;
        default: line_with_ret[127:96] = word;
      endcase
    end
  endfunction

  // snoop 使用的按字节合并函数；取指请求本身从不执行 store。
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

  // 组合准入预检查只比较行地址与 set 冲突，不等待同步 tag RAM。访问已有 MSHR
  // 或 stream buffer 可直接合并；不同 set 的请求即使 MSHR 全忙也可先探测命中。
  wire incoming_match_m0 = mshr_active[0] &&
       ({mshr_tag[0],mshr_index[0]} == addr[31:LINE_OFFSET_BITS]);
  wire incoming_match_m1 = mshr_active[1] &&
       ({mshr_tag[1],mshr_index[1]} == addr[31:LINE_OFFSET_BITS]);
  wire incoming_mshr_match = incoming_match_m0 || incoming_match_m1;
  wire incoming_mshr_id = incoming_match_m1;
  wire incoming_pf_buffer_match = pf_buffer_valid &&
       (pf_buffer_line == addr[31:LINE_OFFSET_BITS]);
  wire incoming_pf_candidate_match = pf_candidate_valid &&
       (pf_candidate_line == addr[31:LINE_OFFSET_BITS]);
  wire incoming_set_conflict =
       (mshr_active[0] &&
        (mshr_index[0] == addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                               LINE_OFFSET_BITS]) &&
        !incoming_match_m0) ||
       (mshr_active[1] &&
        (mshr_index[1] == addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                               LINE_OFFSET_BITS]) &&
        !incoming_match_m1);
  wire mshr_has_free = !mshr_active[0] || !mshr_active[1];
  wire alloc_mshr_id = mshr_active[0];
  // 即使两个 MSHR 都忙，访问无关 set 的请求仍可能命中常驻行。先允许其进入
  // 同步 lookup；只有确认为 miss 时，才保持 lookup_valid 直到 MSHR 空闲。
  wire incoming_can_lookup = incoming_pf_buffer_match ||
       incoming_mshr_match || !incoming_set_conflict;

  wire resident_hit_fire = lookup_valid && !lookup_array_collision &&
                           !lookup_is_cacop &&
                           !lookup_is_pf_probe && lookup_hit;
  // 位于有序响应队首的常驻行命中已经基于同步 BRAM 输出，因此直接返回，
  // 无需先写入完成队列，再延后一拍寄存 data_ok。
  wire resp_resident_hit_pop = resident_hit_fire && (resp_count != 0) &&
       resp_valid[resp_head] && (lookup_resp_slot == resp_head);
  wire resp_ready_pop = (resp_count != 0) && resp_valid[resp_head] &&
                         resp_ready[resp_head];
  // 若当前 refill beat 恰好完成有序队首，直接从 R 通道旁路到 CPU，
  // 避免 completion queue 为 critical-word-first 额外增加一拍。
  wire resp_refill_early_pop = mem_data_ok &&
       mshr_active[mem_resp_id] && (resp_count != 0) &&
       resp_valid[resp_head] && resp_wait_mshr[resp_head] &&
       (resp_mshr_id[resp_head] == mem_resp_id) &&
       (resp_word[resp_head] ==
        (mshr_start_word[mem_resp_id] + mshr_rd_cnt[mem_resp_id]));
  wire resp_pop = resp_ready_pop || resp_refill_early_pop ||
                  resp_resident_hit_pop;
  wire resp_has_space = (resp_count < RESP_DEPTH) || resp_pop;
  // 驱动这些输出的所有队列状态均已寄存。组合 ready/data 握手允许 CPU 在
  // 队列弹出的同一时钟沿捕获响应，从而去掉另一级仅用于响应的寄存器。
  assign data_ok = resp_pop;
  assign rdata = resp_resident_hit_pop ?
                 select_word(lookup_hit_line,lookup_offset[3:2]) :
                 (resp_refill_early_pop ? mem_rdata : resp_data[resp_head]);

  wire lookup_hint_word_valid = lookup_mshr_hint_valid &&
       mshr_word_valid[lookup_mshr_hint][lookup_offset[3:2]];
  wire lookup_pf_buffer_hit = pf_buffer_valid &&
       (pf_buffer_line == {lookup_tag,lookup_index});
  wire lookup_can_allocate = !lookup_mshr_hint_valid && mshr_has_free &&
       !((mshr_active[0] && (mshr_index[0] == lookup_index)) ||
         (mshr_active[1] && (mshr_index[1] == lookup_index)));
  // 常驻行命中可在完成的同一拍接收下一个请求。miss 解决后特意保留一个 bubble，
  // 确保下一个被接收的请求一定有对应的 MSHR 预留项。
  wire lookup_retires_hit = lookup_valid && !lookup_array_collision &&
                            !lookup_is_cacop &&
                            !lookup_is_pf_probe && lookup_hit;
  wire lookup_retires_pf_probe = lookup_valid && lookup_is_pf_probe;
  // prefetch buffer 中的 demand 特意多占用一个 lookup 周期，使其提升写入能在
  // 读取另一个同 set 请求前生效。
  wire lookup_slot_free = !lookup_valid || lookup_retires_hit ||
                          lookup_retires_pf_probe;
  wire accept_req = !init_active && !cacop_req && !snoop_req && req &&
                     resp_has_space && lookup_slot_free && incoming_can_lookup;
  wire cache_quiescent = (mshr_active == 2'b0) && (resp_count == 0) &&
                          !mem_req && !lookup_valid;
  // snoop 持续拉高期间先停止接收新取指，待已有 refill/响应排空后再探测。
  wire accept_snoop = !init_active && snoop_req && cache_quiescent;
  wire accept_cacop = !init_active && cacop_req && !snoop_req &&
                      cache_quiescent;
  // 仅在 lookup 槽原本空闲时，才通过普通同步 tag RAM 探测待处理的 prefetch
  // 候选项。若匹配常驻行，则丢弃候选项且不消耗内存带宽。
  wire pf_probe_accept = !init_active && pf_candidate_valid && !pf_buffer_valid &&
       (mshr_active == 2'b0) && !mem_req && lookup_slot_free &&
       !(lookup_valid && lookup_is_pf_probe) &&
       !accept_req && !accept_cacop && !accept_snoop;
  wire lookup_replaced = accept_req || pf_probe_accept;

  assign addr_ok = accept_req;
  assign cacop_addr_ok = accept_cacop;
  assign snoop_addr_ok = accept_snoop;
  assign mem_size = 2'b10;
  assign mem_id = mem_req_slot;
  assign mem_prefetch = mem_req && mshr_is_prefetch[mem_req_slot];

  // 返回 beat 的定位与整行安装条件。纯 prefetch 若从未被 demand 使用，只进入
  // stream buffer；普通 miss 或已合并 demand 的 prefetch 会安装为常驻 L1 行。
  wire refill_id = mem_resp_id;
  wire [1:0] refill_word_index =
       mshr_start_word[refill_id] + mshr_rd_cnt[refill_id];
  wire [LINE_ADDR_BITS-1:0] refill_line_address =
       {mshr_tag[refill_id],mshr_index[refill_id]};
  wire [127:0] refill_line_next =
       line_with_ret(mshr_line[refill_id],refill_word_index,mem_rdata);
  wire refill_demand_attach = lookup_valid && !lookup_is_cacop &&
       !lookup_is_pf_probe && !lookup_hit && lookup_mshr_hint_valid &&
       (lookup_mshr_hint == refill_id);
  wire refill_to_resident = !mshr_is_prefetch[refill_id] ||
                            mshr_demanded[refill_id] ||
                            refill_demand_attach;
  wire refill_install = mem_data_ok && mshr_active[refill_id] &&
                         refill_to_resident &&
                         (mshr_rd_cnt[refill_id] == 2'd3);
  wire lookup_lru_way = !mru_way_r;
  wire lookup_alloc_way = !way0_valid ? 1'b0 :
                           !way1_valid ? 1'b1 : lookup_lru_way;
  wire lookup_set_mshr_busy =
       (mshr_active[0] && (mshr_index[0] == lookup_index)) ||
       (mshr_active[1] && (mshr_index[1] == lookup_index));
  wire pf_promote_fire = lookup_valid && !lookup_is_cacop &&
                         !lookup_is_pf_probe && !lookup_hit &&
                         lookup_pf_buffer_hit && !refill_install &&
                         !lookup_set_mshr_busy;
  wire pf_promote_way = lookup_alloc_way;
  wire data_read_en = accept_req || accept_cacop || accept_snoop ||
                      pf_probe_accept || lookup_array_collision;
  wire [INDEX_BITS-1:0] data_read_index = accept_snoop ?
       snoop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS] :
       accept_cacop ?
       cacop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS] :
       pf_probe_accept ? pf_candidate_line[INDEX_BITS-1:0] :
       lookup_array_collision ? lookup_index :
       addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS];

  // 每个 tag/data RAM 只呈现一个写端口。refill 安装优先；该拍已抑制
  // pf_promote_fire。将仲裁放在时序 RAM 模板之外对 Vivado 很重要：即使使能
  // 互斥，对同一阵列的两个独立语法写操作仍会被解释为不支持的多写端口。
  wire snoop_update_fire = lookup_valid && lookup_is_snoop && lookup_hit;
  wire [31:0] snoop_old_word =
       select_word(lookup_hit_line,lookup_offset[3:2]);
  wire [31:0] snoop_new_word =
       merge_store_word(snoop_old_word,lookup_snoop_wdata,
                        lookup_snoop_wstrb);
  wire [127:0] snoop_new_line =
       line_with_ret(lookup_hit_line,lookup_offset[3:2],snoop_new_word);
  wire cache_array_we = refill_install || pf_promote_fire ||
                        snoop_update_fire;
  wire cache_array_write_way = refill_install ?
       mshr_way[refill_id] :
       pf_promote_fire ? pf_promote_way : way1_hit;
  wire [INDEX_BITS-1:0] cache_array_write_index = refill_install ?
       mshr_index[refill_id] : lookup_index;
  wire [TAG_BITS-1:0] cache_array_write_tag = refill_install ?
       mshr_tag[refill_id] : lookup_tag;
  wire [127:0] cache_array_write_data = refill_install ?
       refill_line_next :
       pf_promote_fire ? pf_buffer_data : snoop_new_line;
  wire way0_array_we = cache_array_we && !cache_array_write_way;
  wire way1_array_we = cache_array_we && cache_array_write_way;

  // 单一 metadata 写端口。refill 安装使用随 MSHR 保存的 valid 快照，
  // 因为同步 lookup 输出此时可能已保存另一个 set。原设计中 refill/promotion
  // 的替换优先级已经高于同拍的常驻行命中。
  reg metadata_write_en;
  reg [INDEX_BITS-1:0] metadata_write_index;
  reg [2:0] metadata_write_data;
  always @(*) begin
    metadata_write_en = 1'b0;
    metadata_write_index = {INDEX_BITS{1'b0}};
    metadata_write_data = 3'b000;
    if (resetn) begin
      if (init_active) begin
        metadata_write_en = 1'b1;
        metadata_write_index = init_index;
        metadata_write_data = 3'b000;
      end else if (refill_install) begin
        metadata_write_en = 1'b1;
        metadata_write_index = mshr_index[refill_id];
        metadata_write_data =
            {mshr_valid_state[refill_id][1],
             mshr_valid_state[refill_id][0],
             mshr_way[refill_id]};
        if (mshr_way[refill_id])
          metadata_write_data[2] = 1'b1;
        else
          metadata_write_data[1] = 1'b1;
      end else if (pf_promote_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = lookup_index;
        metadata_write_data = {valid_way1_r,valid_way0_r,pf_promote_way};
        if (pf_promote_way)
          metadata_write_data[2] = 1'b1;
        else
          metadata_write_data[1] = 1'b1;
      end else if (lookup_valid && lookup_is_cacop && !lookup_is_snoop) begin
        metadata_write_index = lookup_index;
        metadata_write_data = metadata_r;
        case (lookup_cacop_code[4:3])
          2'b00,
          2'b01: begin
            metadata_write_en = 1'b1;
            if (lookup_cacop_way)
              metadata_write_data[2] = 1'b0;
            else
              metadata_write_data[1] = 1'b0;
          end
          2'b10: begin
            metadata_write_en = way0_hit || way1_hit;
            if (way0_hit)
              metadata_write_data[1] = 1'b0;
            if (way1_hit)
              metadata_write_data[2] = 1'b0;
          end
          default: metadata_write_en = 1'b0;
        endcase
      end else if (resident_hit_fire) begin
        metadata_write_en = 1'b1;
        metadata_write_index = lookup_index;
        metadata_write_data = {valid_way1_r,valid_way0_r,way1_hit};
      end
    end
  end

  // 同步 RAM 读写模板。读写同 set 时显式记录 metadata bypass，data/tag 的极少
  // 数安装碰撞则由 lookup_array_collision 触发下一拍重读，避免依赖器件模式。
  always @(posedge clk)
  begin
    if (data_read_en)
    begin
      data_way0_r <= data_way0[data_read_index];
      data_way1_r <= data_way1[data_read_index];
      tag_way0_r <= tag_way0[data_read_index];
      tag_way1_r <= tag_way1[data_read_index];
      metadata_ram_r <= metadata_mem[data_read_index];
      metadata_bypass_r <= metadata_write_en &&
                           (metadata_write_index == data_read_index);
      metadata_bypass_data_r <= metadata_write_data;
    end
    if (way0_array_we)
    begin
      data_way0[cache_array_write_index] <= cache_array_write_data;
      tag_way0[cache_array_write_index] <= cache_array_write_tag;
    end
    if (way1_array_we)
    begin
      data_way1[cache_array_write_index] <= cache_array_write_data;
      tag_way1[cache_array_write_index] <= cache_array_write_tag;
    end
    if (metadata_write_en)
      metadata_mem[metadata_write_index] <= metadata_write_data;
  end

  integer i;
  integer q;
  // cpu_clk 复位由 SoC 复位桥完成同步。同步缓存控制复位可避免异步控制信号
  // 驱动 BRAM 地址/数据引脚。
  // 主控制时序块同时维护 lookup、MSHR、完成队列、预取器及下级请求寄存器。
  // 非复位周期先把一次性 data_ok 清零，再按“响应弹出/请求接收/lookup 解决/
  // 下级握手/返回 beat”更新；非阻塞赋值和显式门控处理所有同拍事件。
  always @(posedge clk)
  begin
    if (!resetn)
    begin
      lookup_valid <= 1'b0;
      lookup_is_cacop <= 1'b0;
      lookup_is_snoop <= 1'b0;
      lookup_is_pf_probe <= 1'b0;
      lookup_index <= {INDEX_BITS{1'b0}};
      lookup_tag <= {TAG_BITS{1'b0}};
      lookup_offset <= 4'b0;
      lookup_cacop_code <= 5'b0;
      lookup_cacop_way <= 1'b0;
      lookup_snoop_wstrb <= 4'b0;
      lookup_snoop_wdata <= 32'b0;
      lookup_resp_slot <= 2'b0;
      lookup_mshr_hint_valid <= 1'b0;
      lookup_mshr_hint <= 1'b0;
      lookup_array_collision <= 1'b0;
      init_active <= 1'b1;
      init_index <= {INDEX_BITS{1'b0}};

      mshr_active <= 2'b0;
      mshr_req_sent <= 2'b0;
      mshr_is_prefetch <= 2'b0;
      mshr_demanded <= 2'b0;
      mem_req_slot <= 1'b0;
      mem_req <= 1'b0;
      mem_wr <= 1'b0;
      mem_wstrb <= 4'b1111;
      mem_addr <= 32'b0;
      mem_wdata <= 32'b0;
      for (i = 0; i < MSHR_COUNT; i = i + 1)
      begin
        mshr_tag[i] <= {TAG_BITS{1'b0}};
        mshr_index[i] <= {INDEX_BITS{1'b0}};
        mshr_way[i] <= 1'b0;
        mshr_start_word[i] <= 2'b0;
        mshr_rd_cnt[i] <= 2'b0;
        mshr_word_valid[i] <= 4'b0;
        mshr_line[i] <= 128'b0;
        mshr_valid_state[i] <= 2'b0;
      end

      resp_valid <= {RESP_DEPTH{1'b0}};
      resp_ready <= {RESP_DEPTH{1'b0}};
      resp_wait_mshr <= {RESP_DEPTH{1'b0}};
      resp_mshr_id <= {RESP_DEPTH{1'b0}};
      resp_head <= 2'b0;
      resp_tail <= 2'b0;
      resp_count <= 3'b0;
      for (q = 0; q < RESP_DEPTH; q = q + 1)
      begin
        resp_data[q] <= 32'b0;
        resp_word[q] <= 2'b0;
      end

      cacop_data_ok <= 1'b0;
      snoop_data_ok <= 1'b0;
      pf_candidate_valid <= 1'b0;
      pf_candidate_line <= {LINE_ADDR_BITS{1'b0}};
      pf_buffer_valid <= 1'b0;
      pf_buffer_line <= {LINE_ADDR_BITS{1'b0}};
      pf_buffer_data <= 128'b0;
    end
    else
    begin
      cacop_data_ok <= 1'b0;
      snoop_data_ok <= 1'b0;

      if (init_active)
      begin
        if (init_index == SET_COUNT - 1)
          init_active <= 1'b0;
        else
          init_index <= init_index + {{(INDEX_BITS-1){1'b0}},1'b1};
      end

      if (resp_pop)
      begin
        resp_valid[resp_head] <= 1'b0;
        resp_ready[resp_head] <= 1'b0;
        resp_wait_mshr[resp_head] <= 1'b0;
        resp_head <= resp_head + 2'd1;
      end

      if (accept_req)
      begin
        // 新接收的 demand 始终优先于推测发射。如果它恰好是待处理的下一行，
        // 则消费该候选项，避免 demand refill 之后出现重复 prefetch。
        if (incoming_pf_candidate_match)
          pf_candidate_valid <= 1'b0;
        resp_valid[resp_tail] <= 1'b1;
        resp_ready[resp_tail] <= 1'b0;
        resp_wait_mshr[resp_tail] <= 1'b0;
        resp_data[resp_tail] <= 32'b0;
        resp_word[resp_tail] <= addr[3:2];
        lookup_valid <= 1'b1;
        lookup_is_cacop <= 1'b0;
        lookup_is_snoop <= 1'b0;
        lookup_is_pf_probe <= 1'b0;
        lookup_index <= addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                             LINE_OFFSET_BITS];
        lookup_tag <= addr[31:LINE_OFFSET_BITS + INDEX_BITS];
        lookup_offset <= addr[3:0];
        lookup_resp_slot <= resp_tail;
        lookup_mshr_hint_valid <= incoming_mshr_match;
        lookup_mshr_hint <= incoming_mshr_id;
        lookup_array_collision <= cache_array_we &&
            (cache_array_write_index ==
             addr[LINE_OFFSET_BITS + INDEX_BITS - 1:LINE_OFFSET_BITS]);
        resp_tail <= resp_tail + 2'd1;
      end

      if (accept_cacop)
      begin
        // maintenance 操作会使所有推测行失效。已经发出的 prefetch 属于
        // mshr_active，因此在四个返回 beat 全部接收前，cache_quiescent 保持为低。
        pf_candidate_valid <= 1'b0;
        pf_buffer_valid <= 1'b0;
        lookup_valid <= 1'b1;
        lookup_is_cacop <= 1'b1;
        lookup_is_snoop <= 1'b0;
        lookup_is_pf_probe <= 1'b0;
        lookup_index <= cacop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                   LINE_OFFSET_BITS];
        lookup_tag <= cacop_addr[31:LINE_OFFSET_BITS + INDEX_BITS];
        lookup_offset <= cacop_addr[3:0];
        lookup_cacop_code <= cacop_code;
        lookup_cacop_way <= cacop_addr[0];
        lookup_mshr_hint_valid <= 1'b0;
      end

      if (accept_snoop)
      begin
        // 内存写响应已经返回，此处只更新命中的常驻行；未命中无需分配。
        // 同时丢弃预取状态，避免稍后重新安装修改前的旧缓存行。
        pf_candidate_valid <= 1'b0;
        pf_buffer_valid <= 1'b0;
        lookup_valid <= 1'b1;
        lookup_is_cacop <= 1'b1;
        lookup_is_snoop <= 1'b1;
        lookup_is_pf_probe <= 1'b0;
        lookup_index <= snoop_addr[LINE_OFFSET_BITS + INDEX_BITS - 1:
                                   LINE_OFFSET_BITS];
        lookup_tag <= snoop_addr[31:LINE_OFFSET_BITS + INDEX_BITS];
        lookup_offset <= snoop_addr[3:0];
        lookup_snoop_wstrb <= snoop_wstrb;
        lookup_snoop_wdata <= snoop_wdata;
        lookup_mshr_hint_valid <= 1'b0;
      end

      if (pf_probe_accept)
      begin
        lookup_valid <= 1'b1;
        lookup_is_cacop <= 1'b0;
        lookup_is_snoop <= 1'b0;
        lookup_is_pf_probe <= 1'b1;
        lookup_index <= pf_candidate_line[INDEX_BITS-1:0];
        lookup_tag <= pf_candidate_line[LINE_ADDR_BITS-1:INDEX_BITS];
        lookup_offset <= 4'b0;
        lookup_mshr_hint_valid <= 1'b0;
        lookup_mshr_hint <= 1'b0;
      end

      case ({accept_req,resp_pop})
        2'b10: resp_count <= resp_count + 3'd1;
        2'b01: resp_count <= resp_count - 3'd1;
        default: resp_count <= resp_count;
      endcase

      if (lookup_valid)
      begin
        if (lookup_array_collision)
        begin
          // data_read_en 在本拍重读 lookup_index；保持 lookup/payload，
          // 下一拍再按普通 hit/miss 逻辑处理。
          lookup_array_collision <= 1'b0;
        end
        else if (lookup_is_cacop)
        begin
          if (lookup_is_snoop)
            snoop_data_ok <= 1'b1;
          else
            cacop_data_ok <= 1'b1;
          lookup_valid <= 1'b0;
          lookup_is_snoop <= 1'b0;
        end
        else if (lookup_is_pf_probe)
        begin
          // 如果对被探测缓存行的 CPU demand 在解决拍到达，则该 demand 拥有
          // 此缓存行，并正常分配 MSHR0；否则只有真正的常驻行 miss 才转为
          // 推测 MSHR1。
          if (!(accept_req &&
                (addr[31:LINE_OFFSET_BITS] == {lookup_tag,lookup_index})) &&
              !lookup_hit)
          begin
            mshr_active[1] <= 1'b1;
            mshr_req_sent[1] <= 1'b0;
            mshr_is_prefetch[1] <= 1'b1;
            mshr_demanded[1] <= 1'b0;
            mshr_tag[1] <= lookup_tag;
            mshr_index[1] <= lookup_index;
            mshr_way[1] <= lookup_alloc_way;
            mshr_start_word[1] <= 2'b0;
            mshr_rd_cnt[1] <= 2'b0;
            mshr_word_valid[1] <= 4'b0;
            mshr_line[1] <= 128'b0;
            mshr_valid_state[1] <= {valid_way1_r,valid_way0_r};
          end
          pf_candidate_valid <= 1'b0;
          if (!lookup_replaced)
            lookup_valid <= 1'b0;
        end
        else if (lookup_hit)
        begin
          if (!resp_resident_hit_pop)
          begin
            resp_data[lookup_resp_slot] <=
                select_word(lookup_hit_line,lookup_offset[3:2]);
            resp_ready[lookup_resp_slot] <= 1'b1;
          end
          // accept_req 可能在同一时钟沿替换此命中。在该 II=1 情况下，
          // 保留新加载的 lookup metadata。
          if (!lookup_replaced)
            lookup_valid <= 1'b0;
        end
        else if (lookup_pf_buffer_hit)
        begin
          // 常驻 data/tag RAM 只有一个写端口。如果另一个 demand refill 在本拍
          // 安装，则将此 lookup 和 stream buffer 保留一拍，而不分配重复 MSHR。
          if (lookup_set_mshr_busy)
          begin
            // 立即返回有用的缓冲数据。保持 buffer 有效，因为较早的同 set refill
            // 已占用一个 victim way；待该 refill 完成后，后续访问可提升此缓存行。
            resp_data[lookup_resp_slot] <=
                select_word(pf_buffer_data,lookup_offset[3:2]);
            resp_ready[lookup_resp_slot] <= 1'b1;
            lookup_valid <= 1'b0;
          end
          else if (!refill_install)
          begin
            resp_data[lookup_resp_slot] <=
                select_word(pf_buffer_data,lookup_offset[3:2]);
            resp_ready[lookup_resp_slot] <= 1'b1;
            // 有用的 stream-buffer 行转为普通 L1 常驻行；随后仅调度一次其后继行。
            // 不跨越 4 KiB 页边界。
            pf_buffer_valid <= 1'b0;
            if (!pf_candidate_valid &&
                (pf_buffer_line[7:0] != 8'hff))
            begin
              pf_candidate_valid <= 1'b1;
              pf_candidate_line <= pf_buffer_line +
                                   {{(LINE_ADDR_BITS-1){1'b0}},1'b1};
            end
            lookup_valid <= 1'b0;
          end
        end
        else if (lookup_mshr_hint_valid)
        begin
          if (mshr_is_prefetch[lookup_mshr_hint])
            mshr_demanded[lookup_mshr_hint] <= 1'b1;
          if (lookup_hint_word_valid)
          begin
            resp_data[lookup_resp_slot] <=
                select_word(mshr_line[lookup_mshr_hint],lookup_offset[3:2]);
            resp_ready[lookup_resp_slot] <= 1'b1;
          end
          else if (mem_data_ok &&
                   (mem_resp_id == lookup_mshr_hint) &&
                   (refill_word_index == lookup_offset[3:2]))
          begin
            resp_data[lookup_resp_slot] <= mem_rdata;
            resp_ready[lookup_resp_slot] <= 1'b1;
          end
          else
          begin
            resp_wait_mshr[lookup_resp_slot] <= 1'b1;
            resp_mshr_id[lookup_resp_slot] <= lookup_mshr_hint;
          end
          lookup_valid <= 1'b0;
        end
        else if (lookup_can_allocate)
        begin
          mshr_active[alloc_mshr_id] <= 1'b1;
          mshr_req_sent[alloc_mshr_id] <= 1'b0;
          mshr_tag[alloc_mshr_id] <= lookup_tag;
          mshr_index[alloc_mshr_id] <= lookup_index;
          mshr_way[alloc_mshr_id] <= lookup_alloc_way;
          mshr_start_word[alloc_mshr_id] <= lookup_offset[3:2];
          mshr_rd_cnt[alloc_mshr_id] <= 2'b0;
          mshr_word_valid[alloc_mshr_id] <= 4'b0;
          mshr_line[alloc_mshr_id] <= 128'b0;
          mshr_valid_state[alloc_mshr_id] <=
              {valid_way1_r,valid_way0_r};
          mshr_is_prefetch[alloc_mshr_id] <= 1'b0;
          mshr_demanded[alloc_mshr_id] <= 1'b1;
          resp_wait_mshr[lookup_resp_slot] <= 1'b1;
          resp_mshr_id[lookup_resp_slot] <= alloc_mshr_id;
          lookup_valid <= 1'b0;

        end
      end

      // 请求一旦对下一级可见，就保持其身份和 payload 稳定，直到 ready/valid
      // 握手完成。demand 优先级只在下方选择新请求时应用；若更改已经拉高的
      // 推测请求，可能会将延迟的 mem_addr_ok 关联到错误的 MSHR。
      if (mem_req && mem_addr_ok)
      begin
        mem_req <= 1'b0;
        mshr_req_sent[mem_req_slot] <= 1'b1;
      end
      else if (!mem_req)
      begin
        if (mshr_active[0] && !mshr_req_sent[0])
        begin
          mem_req_slot <= 1'b0;
          mem_addr <= {mshr_tag[0],mshr_index[0],
                       mshr_start_word[0],2'b0};
          mem_req <= 1'b1;
        end
        else if (mshr_active[1] && !mshr_req_sent[1])
        begin
          mem_req_slot <= 1'b1;
          mem_addr <= {mshr_tag[1],mshr_index[1],
                       mshr_start_word[1],2'b0};
          mem_req <= 1'b1;
        end
      end

      if (mem_data_ok && mshr_active[refill_id])
      begin
        mshr_line[refill_id] <= refill_line_next;
        mshr_word_valid[refill_id][refill_word_index] <= 1'b1;
        for (q = 0; q < RESP_DEPTH; q = q + 1)
        begin
          if (resp_valid[q] && resp_wait_mshr[q] &&
              (resp_mshr_id[q] == refill_id) &&
              (resp_word[q] == refill_word_index) &&
              !(resp_refill_early_pop && (q[1:0] == resp_head)))
          begin
            resp_data[q] <= mem_rdata;
            resp_ready[q] <= 1'b1;
            resp_wait_mshr[q] <= 1'b0;
          end
        end

        if (mshr_rd_cnt[refill_id] == 2'd3)
        begin
          if (!refill_to_resident)
          begin
            pf_buffer_valid <= 1'b1;
            pf_buffer_line <= refill_line_address;
            pf_buffer_data <= refill_line_next;
          end
          else
          begin
            // 新 demand 流取代旧路径中未使用的 buffer。如果期望的后继行已在
            // buffer 中，则保留它并抑制重复的下一级请求。
            if (refill_line_address[7:0] != 8'hff)
            begin
              if (pf_buffer_valid &&
                  (pf_buffer_line ==
                   (refill_line_address +
                    {{(LINE_ADDR_BITS-1){1'b0}},1'b1})))
                pf_candidate_valid <= 1'b0;
              else
              begin
                pf_buffer_valid <= 1'b0;
                pf_candidate_valid <= 1'b1;
                pf_candidate_line <= refill_line_address +
                                     {{(LINE_ADDR_BITS-1){1'b0}},1'b1};
              end
            end
            else
            begin
              pf_candidate_valid <= 1'b0;
              pf_buffer_valid <= 1'b0;
            end
          end
          mshr_active[refill_id] <= 1'b0;
          mshr_req_sent[refill_id] <= 1'b0;
          mshr_is_prefetch[refill_id] <= 1'b0;
          mshr_demanded[refill_id] <= 1'b0;
        end
        else
          mshr_rd_cnt[refill_id] <= mshr_rd_cnt[refill_id] + 2'd1;
      end
    end
  end

endmodule
