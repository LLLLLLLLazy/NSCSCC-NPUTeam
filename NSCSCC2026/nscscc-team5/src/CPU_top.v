// 多级流水 CPU 核心顶层。
// 本模块负责把 PC/取指、译码、执行、访存、写回、CSR/TLB、异常提交以及
// 调试/差分测试信号串接起来；外部存储访问统一通过类 SRAM 握手接口交给
// mycpu_top 中的 cache/bypass/AXI 桥处理。
//
// 流水主路径：
//   FQ 查询/预测 -> FT 地址翻译 -> FI 请求/IFQ -> ID 译码/读寄存器 -> EX1 旁路与早期
//   分支比较 -> EX2 ALU/乘除/地址 -> MEM 地址翻译与内存队列分配 -> WBQ 精确退休。
// EX1/EX2 的拆分把宽旁路网络与 ALU/目标地址计算隔开；WBQ/LQ/SB 则将无标签
// cache 响应和 store 真正写出从主流水反压中解耦。任何架构副作用只在有序 WBQ
// 队首 ready 时发生，因此异常、ERTN、CSR、TLB、LL/SC 均保持精确顺序。
//
// OP_* 是当前 ID译码结果，对应前缀版本是随流水线携带的指令类别；*_q 是上升沿锁存状态；
// *_fire 表示 valid/ready 条件在本拍同时成立，因而会在时钟沿产生一次状态转移。
// *_pc_word、*_pc_plus_4_word 等 [31:2] 信号是字地址，完整字节地址需补低两位 0。
//
// 类 SRAM 接口没有响应 ID：addr_ok 只表示请求被接收，data_ok 可能若干拍后返回。
// CPU 通过 IF memory FIFO、LQ 和串行事务状态保持响应归属，不允许 cached 与
// uncached 事务以可能重排的方式共享同一无标签返回通道。
// 如果后端长时间不收，rdcntvl/rdcntvh 会在后端放行并真正进入 EX/MEM 的那拍采样
// ，而不是原来结果缓存那拍采样。普通 ALU、地址、分支这类稳定结果不受影响。
// 流水级信号使用id_、ex1_、ex2_、mem_和wb_前缀
// 级间信号使用if2id_、id2ex1_、ex12ex2_、ex2mem_和wbq_head_前缀
module CPU_top(
    input clk,
    input rst,
    input [7:0] hw_int_in,

    // 指令侧类 SRAM 接口：req 发请求，addr_ok 接收地址，data_ok 返回数据。
    // cached 为 1 时走 I-cache，为 0 时走直通访问。
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0]  inst_sram_size,
    output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    output wire        inst_sram_cached,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,

    // 数据侧类 SRAM 接口。load/store 以及非缓存数据访问通过该接口发起。
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1:0]  data_sram_size,
    output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        data_sram_cached,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,

    // CACOP 通过独立请求进入 cache 维护通路。
    output wire        cacop_req,
    output wire [4:0]  cacop_code,
    output wire [31:0] cacop_addr,
    input  wire        cacop_addr_ok,
    input  wire        cacop_data_ok,

    // NSCSCC trace debug 接口：只在真正写回 GPR 时拉高写使能。
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [31:0] debug_wb_inst,

    // 差分测试提交事件。monitor 寄存器只记录可见副作用，不反向影响流水线。
    output wire        diff_commit_valid,
    output wire        diff_cnt_inst,
    output wire [63:0] diff_timer_64,
    output wire [7:0]  diff_inst_ld_en,
    output wire [31:0] diff_ld_paddr,
    output wire [31:0] diff_ld_vaddr,
    output wire [7:0]  diff_inst_st_en,
    output wire [31:0] diff_st_paddr,
    output wire [31:0] diff_st_vaddr,
    output wire [31:0] diff_st_data,
    output wire        diff_csr_rstat_en,
    output wire [31:0] diff_csr_data,
    output wire        diff_excp_valid,
    output wire        diff_ertn,
    output wire [5:0]  diff_csr_ecode,
    output wire        diff_tlbfill_en,
    output wire [4:0]  diff_tlbfill_index,
    output wire [1023:0] diff_gprs,
    output wire [831:0]  diff_csrs
  );

  // FQ 取指前端信号
  wire [31:0] fq_pc;
  wire [31:2] fq_pc_plus_4_word;

  wire [31:0] fq_tlb_vaddr;       //发给同步 TLB s0 端口的查询虚拟地址
  wire [6:0]  fq_bp_index;        //当前 PC 对 BTB/方向表的索引
  wire        fq_btb_hit;         //当前 PC 的 BTB 命中标志
  wire [2:0]  fq_btb_type;        //命中 BTB 项记录的控制流类型
  wire [4:0]  fq_branch_pattern;  //读出的局部历史与两组方向计数器
  wire        fq_pred_history;    //本次预测选择方向计数器的局部历史位
  wire [1:0]  fq_cond_counter;    //本次条件分支预测使用的 2-bit 计数器
  wire        fq_cond_taken;      //条件分支计数器给出的 taken 预测
  wire [3:0]  fq_ras_top_index;   //读取返回地址栈顶使用的索引
  wire [31:0] fq_ras_target;      //预测 return 使用的返回目标

  wire [31:0] fq_pred_target;     //在 BTB 与 RAS 之间选出的预测目标
  wire        fq_pred_taken;      //最终taken预测目标
  wire [31:0] fq_sequential_pc;   //未预测跳转时的顺序PC+4
  wire [31:0] fq_pred_next_pc;    //预测器最终给出的下一 PC

  wire        fq_launch;          // FQ 本拍把 PC 和预测信息送入 FQ->FT 寄存器

  // FQ/FT 级间寄存器
  reg         fq2ft_valid_q;
  reg  [7:0]  fq2ft_epoch_q;
  reg  [31:0] fq2ft_pc_q;           // 本次真实PC
  reg  [31:0] fq2ft_pred_next_pc_q;
  reg         fq2ft_pred_taken_q;
  reg         fq2ft_pred_history_q;
  wire        fq2ft_consume;      //FT 处理的这条信息可以往前挪了
  wire        fq2ft_allow;

  //FT，这一级进行地址翻译，产生 paddr、MAT、异常
  wire [31:0] ft_vaddr;
  wire        ft_ex_adef;
  wire        ft_plv_is_0;
  wire        ft_plv_is_3;
  wire        ft_dmw0_plv_match;     // 当前 PLV 被 DMW0 允许
  wire        ft_dmw1_plv_match;     // 当前 PLV 被 DMW1 允许
  wire [2:0]  ft_vseg;               // FT 虚拟地址用于 DMW 匹配的高三位
  wire        ft_dmw0_vseg_match;
  wire        ft_dmw1_vseg_match;
  wire        ft_dmw0_hit;           //最终命中 DMW0
  wire        ft_dmw1_hit;           //最终命中 DMW1
  wire        ft_dmw_hit;            //命中任一 DMW

  wire [2:0]  ft_dmw0_pseg;          // DMW0 配置的物理地址高三位
  wire [2:0]  ft_dmw1_pseg;          // DMW1 配置的物理地址高三位
  wire [31:0] ft_dmw_paddr;          // 命中 DMW 形成的物理地址
  wire        ft_tlb_req;            // FT 当前地址需要使用 TLB s0 结果
  wire        ft_tlb_large_page;     // TLB s0采用 2 MiB 页
  wire [31:0] ft_tlb_paddr;          // FT 按 TLB 页大小拼接出的物理地址
  wire        ft_tlb_found;          // 命中 TLB
  wire        ft_tlb_entry_valid;    // TLB s0 命中页的有效位
  wire        ft_tlb_privilege_fault;// 权限错误
  wire        ft_ex_tlbr;
  wire        ft_ex_pif;
  wire        ft_ex_ppi;
  wire        ft_ex_tlb;             // FT 任一种取指 TLB 异常
  wire        ft_has_exception;      // FT 当前带有任一取指异常
  wire [31:0] ft_paddr;
  wire [1:0]  ft_mat;

  // FT/FI之间的寄存器，这并不是分成两级，只有在后端反压时才会存到这个寄存器，像一个buffer
  reg         ft2fi_valid_q;
  reg  [7:0]  ft2fi_epoch_q;
  reg  [31:0] ft2fi_pc_q;
  reg  [31:0] ft2fi_pred_next_pc_q;
  reg         ft2fi_pred_taken_q;
  reg         ft2fi_pred_history_q;
  reg  [31:0] ft2fi_paddr_q;
  reg  [1:0]  ft2fi_mat_q;
  reg         ft2fi_ex_adef_q;
  reg         ft2fi_ex_tlbr_q;
  reg         ft2fi_ex_pif_q;
  reg         ft2fi_ex_ppi_q;
  wire        ft2fi_has_exception;
  wire        ft2fi_consume;//表示ft2fi中存放的内容可以移走，要么是已经请求握手了，要么是有异常

  //FI：指令请求发射
  wire fi_req_fire;               // FI 与 inst_sram_addr_ok 本拍完成握手
  wire fi_valid;                  // FI 当前存在可发射请求，来源可为ft2fi或 FT 旁路
  wire fi_has_exception;
  wire fi_mem_order_ready;        // 表示可以按照请求顺序有序返回

  wire ft_bypass_fi_candidate;    // FI 空闲时，FT 结果可直接尝试发射而少停一拍
  wire ft_bypass_ifq_alloc;       // FT 旁路本拍分配 IFQ
  wire ft2fi_ifq_alloc;           // ft2fi 本拍分配 IFQ
  reg  fi_uncached_inflight_q;    // 有已发出但尚未返回的uncached请求

  //IF memory FIFO：8项 已发送请求 队列
  //记录目标IFQ槽 slot 和 epoch；取指异常不进入该 FIFO
  localparam IFQ_DEPTH = 8;
  reg [2:0] if_mem_slot [0:IFQ_DEPTH-1];
  reg [7:0] if_mem_epoch[0:IFQ_DEPTH-1];
  reg [2:0] if_mem_head;          // 最老 在途取指响应
  reg [2:0] if_mem_tail;
  reg [3:0] if_mem_count;
  wire      if_mem_has_space;     // IF memory FIFO 至少还有一个空槽
  wire      if_mem_resp_valid;    //if_mem的请求返回了
  wire      if_mem_resp_current;  //返回的确实属于当前epoch

  //IFQ：按程序顺序等待进入 ID
  reg [31:2] ifq_pc_word       [0:IFQ_DEPTH-1];
  reg [31:0] ifq_pred_next_pc  [0:IFQ_DEPTH-1];
  reg        ifq_pred_taken    [0:IFQ_DEPTH-1];
  reg        ifq_pred_history  [0:IFQ_DEPTH-1];
  reg [31:0] ifq_instr         [0:IFQ_DEPTH-1];
  reg [31:0] ifq_bad_pc        [0:IFQ_DEPTH-1]; // 取指异常对应的完整字节地址
  reg        ifq_ready         [0:IFQ_DEPTH-1]; // 可进入 ID
  reg        ifq_ex_adef       [0:IFQ_DEPTH-1];
  reg        ifq_ex_tlbr       [0:IFQ_DEPTH-1];
  reg        ifq_ex_pif        [0:IFQ_DEPTH-1];
  reg        ifq_ex_ppi        [0:IFQ_DEPTH-1];
  reg [2:0]  ifq_head;
  reg [2:0]  ifq_tail;
  reg [3:0]  ifq_count;
  wire       ifq_has_space;
  wire       ifq_head_valid;    // IFQ 队首存在且已经 ready
  wire       ifq_alloc;         // 本拍在 IFQ 尾部分配一个新项
  wire       ifq_pop;           // 本拍把 ready 的 IFQ 队首交给 ID

  // IFQ -> ID
  wire [31:2] ifq2id_pc_word;
  wire [31:2] ifq2id_pc_plus_4_word;
  wire [31:0] ifq2id_instr;
  wire        ifq2id_valid;       // IF/ID 输入有效位，正常指令和异常项均可置位
  wire        ifq2id_wait;        // IFQ 队首尚无可送入 ID 的指令
  wire        id_wait_ifq;        // ID 级等待 IFQ 队首就绪


  // 注意有_q的才是寄存器，否则可能是always必须的reg
  reg  [31:0] Next_PC;            // 按全局优先级选择出的
  reg  [7:0]  if_epoch_q;         // 全局 epoch


  //-------------------------重定向相关信号---------------------------------
  wire        ID_redirect_valid;        // ID 的 b/bl 目标修正
  wire [31:0] ID_redirect_pc;

  reg         EX1_redirect_valid_q;     // EX1 条件分支方向修正
  reg  [31:0] EX1_redirect_pc_q;
  reg         EX1_redirect_pending_q;   // 后端阻塞时，保存已经确认的 EX1 误预测(因为数据可能源于旁路，不能确定再后端都停止流动，所以需要存储)

  reg         EX2_redirect_valid_q;     // EX2要重定向，不过这个信号与 EX2/MEM 级间寄存器一个位置，不在EX2内部
  reg  [31:0] EX2_redirect_pc_q;

  // MEM 级没有重定向来源

  //串行重取:会改变取指环境的指令(例如:修改 CRMD、ASID、DMW 等影响取指地址转换的 CSR;tlbwr/tlbfill/invtlb 等 TLB 操作;I-cache CACOP;IBAR)精确退休后，丢弃此前预取的年轻指令，并从该指令的 PC+4 重新取指
  reg         WB_redirect_valid_q;      // 异常、ERTN 或 串行重取 统一形成的一拍恢复
  reg  [31:0] WB_redirect_pc_q;         // WB 所有重定向共用的最终目标，包括串行重取的地址


  wire        EX2_back_redirect_valid;//EX2及其后的重定向
  wire [31:0] EX2_back_redirect_pc;
  wire        EX1_back_redirect_valid;
  wire [31:0] EX1_back_redirect_pc;
  wire        ID_back_redirect_valid;   // 全部重定向来源汇总，供取指前端改 PC/epoch
  wire [31:0] ID_back_redirect_pc;

  wire        IF_redirect_dmw0_hit;
  wire        IF_redirect_dmw1_hit;
  wire        IF_redirect_can_inject_FT;// DA/DMW 不需要 TLB，可在时钟沿直接注入fq2ft
  reg         FT_redirect_injected_q;   // 上拍已把 DA/DMW 重定向目标直接注入 fq2ft寄存器

  // 串行屏障
  // 屏障有效期间，较老操作由 MEM 排空，年轻指令最多停在 EX2，不能进入 MEM
  reg         MEM_serial_barrier_q;     // 已有串行指令进入 MEM，尚未在 WB 精确退休
  wire        MEM_serial_accept;        // EX2 串行指令本拍真正进入 MEM
  wire        WB_serial_retire;         // WB 本拍正常退休该串行指令

  // 动态分支预测器
  localparam integer BP_ENTRIES = 128;
  localparam integer BP_RAS_DEPTH = 16;
  localparam [2:0] BP_TYPE_COND   = 3'd0;//条件分支：查询方向计数器
  // 其余的BTB命中就跳转，因为无条件
  localparam [2:0] BP_TYPE_DIRECT = 3'd1;//无条件直接跳转
  localparam [2:0] BP_TYPE_CALL   = 3'd2;
  localparam [2:0] BP_TYPE_RETURN = 3'd3;
  localparam [2:0] BP_TYPE_INDIRECT = 3'd4;//无条件间接跳转（需要计算的跳转）
  reg        btb_valid  [0:BP_ENTRIES-1];
  //(* ram_style = "distributed" *)提示综合器把后面的数组优先实现成分布式 RAM（LUTRAM），而不是 Block RAM
  (* ram_style = "distributed" *) reg [22:0] btb_tag    [0:BP_ENTRIES-1];
  (* ram_style = "distributed" *) reg [31:0] btb_target [0:BP_ENTRIES-1];
  (* ram_style = "distributed" *) reg [2:0]  btb_type   [0:BP_ENTRIES-1];
  (* ram_style = "distributed" *) reg [4:0] branch_pattern[0:BP_ENTRIES-1];
  (* ram_style = "distributed" *) reg [31:0] ras_stack  [0:BP_RAS_DEPTH-1];
  reg [3:0]  ras_sp;
  reg [4:0]  ras_count;

  // EX2 将本次解析结果锁存，下一拍再更新 BTB/RAS
  reg        bp_update_valid_q;       // 更新包有效
  reg        bp_update_control_q;     // 当前指令确为控制流；0 表示普通指令，如果命中则要置BTB项valid为0
  reg        bp_update_call_q;        // call 更新：把顺序执行地址压入 RAS
  reg        bp_update_return_q;      // return 更新：从 RAS 弹出一项
  reg [6:0]  bp_update_index_q;       // 当前指令 PC[8:2]，选择 128 项预测表中的一项
  reg [22:0] bp_update_tag_q;         // 当前指令 PC[31:9]，写入 BTB 用于区分索引冲突
  reg [31:0] bp_update_target_q;      // 已解析出的真实跳转目标，写入 BTB target
  reg [31:0] bp_update_fallthrough_q; // 当前指令 PC+4；call 时作为返回地址压入 RAS
  reg [2:0]  bp_update_type_q;        // 写入 BTB 的分支类型：条件/直接/call/return/间接
  assign fq_bp_index = fq_pc[8:2];
  assign fq_btb_hit = btb_valid[fq_bp_index] &&
         (btb_tag[fq_bp_index] == fq_pc[31:9]);
  assign fq_btb_type = btb_type[fq_bp_index];
  assign fq_branch_pattern = branch_pattern[fq_bp_index];
  assign fq_pred_history = fq_branch_pattern[4];
  assign fq_cond_counter = fq_pred_history ?
         fq_branch_pattern[3:2] : fq_branch_pattern[1:0];
  assign fq_cond_taken = fq_cond_counter[1];
  assign fq_ras_top_index = ras_sp - 4'd1;
  assign fq_ras_target = ras_stack[fq_ras_top_index];
  assign fq_pred_taken = fq_btb_hit &&
         ((fq_btb_type != BP_TYPE_COND) || fq_cond_taken);
  assign fq_pred_target =
         (fq_btb_type == BP_TYPE_RETURN && ras_count != 0) ?
         fq_ras_target : btb_target[fq_bp_index];
  assign fq_sequential_pc = {fq_pc_plus_4_word,2'b00};
  assign fq_pred_next_pc = fq_pred_taken ? fq_pred_target : fq_sequential_pc;


  // IF级流水控制和后端反馈
  reg         fq_pc_en;        // 取指PC写使能
  reg         if2id_en;        // IF到ID级间寄存器写使能
  wire        if2id_flush;     // IF到ID级间寄存器冲刷
  wire        pipeline_wait;   // 后端对IF和ID级的总反压

  PC PC(.clk(clk),.rst(rst),.PC_En(fq_pc_en),.Next_PC(Next_PC),.Current_PC(fq_pc));


  // 重定向目标已经在分级 back 链中按年龄选好；没有重定向时才采用普通预测 PC
  always@*
  begin
    if(ID_back_redirect_valid)
      Next_PC=ID_back_redirect_pc;//选择重定向
    else
      Next_PC=fq_pred_next_pc;
  end

  assign fq_pc_plus_4_word=fq_pc[31:2]+30'd1;


  // -------------------- FT：取指地址翻译 --------------------

  // TLB三个读取通道，以下均为输出。
  // s0/s1：给虚拟地址 → 搜索哪一项匹配 → 返回所选子页的翻译结果
  // r：    给表项编号 → 直接读取这一项 → 返回表项的所有原始字段

  // s0用于取指翻译 s1用于数据访存翻译
  wire        s0_found, s1_found; // 是否命中 TLB 表项
  wire [4:0]  s0_index, s1_index; // 命中表项的索引
  wire [19:0] s0_ppn, s1_ppn;     // 命中子页的物理页号
  wire [5:0]  s0_ps, s1_ps;       // 命中表项的页大小编码
  wire [1:0]  s0_plv, s1_plv;     // 命中子页允许访问的特权级
  wire [1:0]  s0_mat, s1_mat;     // 命中子页的存储访问类型
  wire        s0_d, s1_d;         // 命中子页的脏位（是否允许写）
  wire        s0_v, s1_v;         // 命中子页的有效位

  // TLB读端口信号，供 TLBRD 将指定表项回填至 CSR
  wire        r_e;                              // 表项存在位
  wire [18:0] r_vppn;                           // 虚双页号
  wire [5:0]  r_ps;                             // 页大小编码
  wire [9:0]  r_asid_out;                       // 地址空间标识符
  wire        r_g;                              // 全局映射标志
  wire [19:0] r_ppn0, r_ppn1;                   // 偶数页、奇数页的物理页号
  wire [1:0]  r_plv0, r_mat0, r_plv1, r_mat1;   // 两个子页的特权级和存储访问类型
  wire        r_d0, r_v0, r_d1, r_v1;           // 两个子页的脏位和有效位

  // 地址翻译使用的CSR寄存器
  wire [31:0] csr_tlbidx, csr_tlbehi, csr_tlbelo0, csr_tlbelo1;
  wire [9:0]  csr_asid;
  wire [18:0] csr_tlbehi_vppn;
  wire [4:0]  csr_tlbidx_index;
  wire [5:0]  csr_estat_ecode_out;
  wire [31:0] tc_csr_dmw0, tc_csr_dmw1;
  wire [1:0]  tc_csr_crmd_plv;
  wire        tc_csr_crmd_da, tc_csr_crmd_pg;
  wire [1:0]  tc_csr_crmd_datf, tc_csr_crmd_datm;

  reg  [4:0]  tlbfill_index_q; // TLBFILL自由运行循环替换索引
  wire [4:0]  mem_tlbfill_index;//执行 TLBFILL 指令时，准备填充/替换的 TLB 表项索引
  always @(posedge clk)
  begin
    if (rst)
      tlbfill_index_q <= 5'b0;
    else
      tlbfill_index_q <= tlbfill_index_q + 1'b1;
  end

  // FT 优先选择直接地址模式，其次选择 DMW，最后使用与 fq2ft_* 对齐的 TLB s0 结果。
  assign ft_vaddr = fq2ft_pc_q;
  assign ft_ex_adef = ft_vaddr[1:0] != 2'b00;
  assign ft_plv_is_0 = tc_csr_crmd_plv == 2'b00;
  assign ft_plv_is_3 = tc_csr_crmd_plv == 2'b11;
  assign ft_dmw0_plv_match =
         (ft_plv_is_0 && tc_csr_dmw0[0]) || (ft_plv_is_3 && tc_csr_dmw0[3]);
  assign ft_dmw1_plv_match =
         (ft_plv_is_0 && tc_csr_dmw1[0]) || (ft_plv_is_3 && tc_csr_dmw1[3]);
  assign ft_vseg = ft_vaddr[31:29];
  assign ft_dmw0_vseg_match = ft_vseg == tc_csr_dmw0[31:29];
  assign ft_dmw1_vseg_match = ft_vseg == tc_csr_dmw1[31:29];
  assign ft_dmw0_hit = ft_dmw0_plv_match && ft_dmw0_vseg_match;
  assign ft_dmw1_hit = ft_dmw1_plv_match && ft_dmw1_vseg_match;
  assign ft_dmw_hit = ft_dmw0_hit || ft_dmw1_hit;
  assign ft_dmw0_pseg = tc_csr_dmw0[27:25];
  assign ft_dmw1_pseg = tc_csr_dmw1[27:25];
  assign ft_dmw_paddr = ft_dmw0_hit ?
         {ft_dmw0_pseg,ft_vaddr[28:0]} : {ft_dmw1_pseg,ft_vaddr[28:0]};
  assign ft_tlb_req = tc_csr_crmd_pg && !tc_csr_crmd_da && !ft_dmw_hit;//他标记 FT 阶段当前这条取指地址是否需要采用 TLB 翻译结果
  assign ft_tlb_large_page = s0_ps == 6'd21;
  assign ft_tlb_paddr = ft_tlb_large_page ?
         {s0_ppn[19:9],ft_vaddr[20:0]} : {s0_ppn,ft_vaddr[11:0]};
  assign ft_tlb_found = ft_tlb_req && s0_found;
  assign ft_tlb_entry_valid = s0_v;
  assign ft_tlb_privilege_fault = tc_csr_crmd_plv > s0_plv;
  assign ft_ex_tlbr = ft_tlb_req && !s0_found;
  assign ft_ex_pif = ft_tlb_found && !ft_tlb_entry_valid;
  assign ft_ex_ppi = ft_tlb_found && ft_tlb_entry_valid && ft_tlb_privilege_fault;
  assign ft_ex_tlb = ft_ex_tlbr || ft_ex_pif || ft_ex_ppi;//tlb相关异常
  assign ft_has_exception = ft_ex_adef || ft_ex_tlb;
  assign ft_paddr = tc_csr_crmd_da ? ft_vaddr :
         ft_dmw_hit ? ft_dmw_paddr : s0_found ? ft_tlb_paddr : ft_vaddr;
  assign ft_mat = tc_csr_crmd_da ? tc_csr_crmd_datf :
         ft_dmw0_hit ? tc_csr_dmw0[5:4] :
         ft_dmw1_hit ? tc_csr_dmw1[5:4] :
         s0_found ? s0_mat : 2'b00;

  // -------------------- FI：指令 SRAM 请求 --------------------
  // FI 为空时允许 FT 直接请求；若 addr_ok 拒绝，则时钟沿把相同负载存入 ft2fi_*。
  assign ft_bypass_fi_candidate = fq2ft_valid_q && !ft2fi_valid_q;//候选:FT 当前确实有一条有效取指&& ft2fi级寄存器为空
  assign fi_has_exception = ft_bypass_fi_candidate ?ft_has_exception : ft2fi_has_exception;
  assign fi_valid = ft2fi_valid_q || ft_bypass_fi_candidate;
  assign inst_sram_cached = ft_bypass_fi_candidate ?
         (ft_mat == 2'b01) : (ft2fi_mat_q == 2'b01);
  assign fi_mem_order_ready = inst_sram_cached ?
         !fi_uncached_inflight_q ://如果是cached请求，要求路上没有uncached
         (!fi_uncached_inflight_q && (if_mem_count == 0));//如果是uncached请求，同样要求路上没有uncached且不要有cached
  assign inst_sram_req = fi_valid && !fi_has_exception && ifq_has_space &&
         if_mem_has_space && fi_mem_order_ready && !ID_back_redirect_valid;
  assign inst_sram_wr = 1'b0;
  assign inst_sram_size = 2'b10;//读取多少字节，2'b00：1字节；2'b01：2字节；2'b10：4字节
  assign inst_sram_wstrb = 4'b0000;
  assign inst_sram_addr = ft_bypass_fi_candidate ? ft_paddr : ft2fi_paddr_q;
  assign inst_sram_wdata = 32'b0;
  assign fi_req_fire = inst_sram_req && inst_sram_addr_ok;//请求握手

  // 正常取指在地址握手时分配 IFQ；取指异常不访问存储，但也按程序顺序分配 ready 项。
  assign ft2fi_has_exception = ft2fi_ex_adef_q || ft2fi_ex_tlbr_q ||
         ft2fi_ex_pif_q || ft2fi_ex_ppi_q;
  assign ft2fi_ifq_alloc = ft2fi_valid_q && ifq_has_space &&
         !ID_back_redirect_valid && (ft2fi_has_exception || fi_req_fire);
  assign ft_bypass_ifq_alloc = ft_bypass_fi_candidate && ifq_has_space &&
         !ID_back_redirect_valid && (ft_has_exception || fi_req_fire);
  assign ifq_alloc = ft2fi_ifq_alloc || ft_bypass_ifq_alloc;
  assign ft2fi_consume = ft2fi_ifq_alloc;//consume表示已经被消耗，可清除
  assign fq2ft_consume = fq2ft_valid_q &&
         (ft_bypass_ifq_alloc || !ft2fi_valid_q || ft2fi_consume);

  // FQ 只有在 fq2ft 槽可接收时才同时推进 PC 并启动同步 TLB 查询。
  assign fq2ft_allow = !rst && !ID_back_redirect_valid && !MEM_serial_barrier_q &&
         (!fq2ft_valid_q || fq2ft_consume);
  assign fq_launch = fq2ft_allow && !FT_redirect_injected_q;
  assign fq_tlb_vaddr = fq_pc;

  // DA/DMW 根本不使用 TLB，因此可在重定向沿直接注入 FQ->FT；分页地址仍走
  // 下一拍的普通 fq_launch，并与同步 TLB s0 结果对齐。
  assign IF_redirect_dmw0_hit =
         ((tc_csr_crmd_plv == 2'b00 && tc_csr_dmw0[0]) ||
          (tc_csr_crmd_plv == 2'b11 && tc_csr_dmw0[3])) &&
         (Next_PC[31:29] == tc_csr_dmw0[31:29]);
  assign IF_redirect_dmw1_hit =
         ((tc_csr_crmd_plv == 2'b00 && tc_csr_dmw1[0]) ||
          (tc_csr_crmd_plv == 2'b11 && tc_csr_dmw1[3])) &&
         (Next_PC[31:29] == tc_csr_dmw1[31:29]);
  assign IF_redirect_can_inject_FT = tc_csr_crmd_da ||
         (!tc_csr_crmd_da && (IF_redirect_dmw0_hit || IF_redirect_dmw1_hit));

  // IF memory FIFO 与 IFQ 的容量只依赖寄存计数，不让当拍 pop/response 组合回到请求路径。
  assign if_mem_has_space = if_mem_count < IFQ_DEPTH;
  assign ifq_has_space = ifq_count < IFQ_DEPTH;
  assign if_mem_resp_valid = inst_sram_data_ok && (if_mem_count != 0);
  assign if_mem_resp_current = if_mem_resp_valid && !ID_back_redirect_valid &&
         (if_mem_epoch[if_mem_head] == if_epoch_q);
  assign ifq_head_valid = (ifq_count != 0) && ifq_ready[ifq_head];
  assign ifq_pop = if2id_en && ifq_head_valid && !ID_back_redirect_valid;

  // IFQ 队首统一形成 IF/ID 输入
  assign ifq2id_pc_word = ifq_pc_word[ifq_head];
  assign ifq2id_pc_plus_4_word = ifq_pc_word[ifq_head] + 30'd1;
  assign ifq2id_valid = ifq_head_valid;
  assign ifq2id_instr = ifq_head_valid ? ifq_instr[ifq_head] : 32'b0;

  integer ifq_i;
  always @(posedge clk)
  begin
    if (rst)
    begin
      fq2ft_valid_q <= 1'b0;
      fq2ft_epoch_q <= 8'b0;
      fq2ft_pc_q <= 32'b0;
      fq2ft_pred_next_pc_q <= 32'b0;
      fq2ft_pred_taken_q <= 1'b0;
      fq2ft_pred_history_q <= 1'b0;
      ft2fi_valid_q <= 1'b0;
      ft2fi_epoch_q <= 8'b0;
      ft2fi_pc_q <= 32'b0;
      ft2fi_pred_next_pc_q <= 32'b0;
      ft2fi_pred_taken_q <= 1'b0;
      ft2fi_pred_history_q <= 1'b0;
      ft2fi_paddr_q <= 32'b0;
      ft2fi_mat_q <= 2'b0;
      ft2fi_ex_adef_q <= 1'b0;
      ft2fi_ex_tlbr_q <= 1'b0;
      ft2fi_ex_pif_q <= 1'b0;
      ft2fi_ex_ppi_q <= 1'b0;
      ifq_head         <= 3'b0;
      ifq_tail         <= 3'b0;
      ifq_count        <= 4'b0;
      if_mem_head      <= 3'b0;
      if_mem_tail      <= 3'b0;
      if_mem_count     <= 4'b0;
      if_epoch_q       <= 8'b0;
      FT_redirect_injected_q <= 1'b0;
      fi_uncached_inflight_q <= 1'b0;
      for (ifq_i = 0; ifq_i < IFQ_DEPTH; ifq_i = ifq_i + 1)
      begin
        ifq_pc_word[ifq_i] <= 30'b0;
        ifq_pred_next_pc[ifq_i] <= 32'b0;
        ifq_pred_taken[ifq_i] <= 1'b0;
        ifq_pred_history[ifq_i] <= 1'b0;
        ifq_instr[ifq_i]   <= 32'b0;
        ifq_bad_pc[ifq_i]  <= 32'b0;
        ifq_ready[ifq_i]   <= 1'b0;
        ifq_ex_adef[ifq_i] <= 1'b0;
        ifq_ex_tlbr[ifq_i] <= 1'b0;
        ifq_ex_pif[ifq_i]  <= 1'b0;
        ifq_ex_ppi[ifq_i]  <= 1'b0;
        if_mem_slot[ifq_i] <= 2'b0;
        if_mem_epoch[ifq_i] <= 8'b0;
      end
    end
    else if (ID_back_redirect_valid)
    begin
      // DA/DMW 目标在该沿直接占用 FQ->FT；分页目标不能使用尚未与目标对齐的
      // TLB 结果，只更新 fq_pc，下一拍再由普通 fq_launch 发起同步查询。
      fq2ft_valid_q <= IF_redirect_can_inject_FT;
      fq2ft_epoch_q <= if_epoch_q + 8'd1;
      fq2ft_pc_q <= Next_PC;//如果重定向注入，fq2ft赋值跳转目标的PC
      fq2ft_pred_next_pc_q <= 32'b0;
      fq2ft_pred_taken_q <= 1'b0;
      fq2ft_pred_history_q <= 1'b0;
      ft2fi_valid_q <= 1'b0;
      if_epoch_q       <= if_epoch_q + 8'd1;
      FT_redirect_injected_q <= IF_redirect_can_inject_FT;//如果是DA/DMW，则可直接用fq2ft赋值的跳转目标PC开始下一步；是TLB的话还需等待一拍
      ifq_head         <= 3'b0;
      ifq_tail         <= 3'b0;
      ifq_count        <= 4'b0;
      // redirect 当拍到达的响应也属于被冲刷路径：只回收请求 FIFO，
      // 不写 IFQ。其余旧响应以后按 epoch 不匹配逐个丢弃。
      if (if_mem_resp_valid)//如果当拍到达响应，丢弃它
      begin
        if_mem_head  <= if_mem_head + 3'd1;
        if_mem_count <= if_mem_count - 4'd1;
        if (fi_uncached_inflight_q)//如果到达的响应还是uncached，置"在途"=0
          fi_uncached_inflight_q <= 1'b0;
      end
      for (ifq_i = 0; ifq_i < IFQ_DEPTH; ifq_i = ifq_i + 1)
        ifq_ready[ifq_i] <= 1'b0;
    end
    else//如果没有rst也没有重定位，也就是顺序流动
    begin
      if (FT_redirect_injected_q)//如果上一拍是重定向注入的
        FT_redirect_injected_q <= 1'b0;

      // 更新 fq2ft 寄存器
      if (fq_launch)
      begin
        fq2ft_valid_q <= 1'b1;
        fq2ft_epoch_q <= if_epoch_q;
        fq2ft_pc_q <= fq_pc;
        fq2ft_pred_next_pc_q <= fq_pred_next_pc;
        fq2ft_pred_taken_q <= fq_pred_taken;
        fq2ft_pred_history_q <= fq_pred_history;
      end
      else if (fq2ft_consume)//fq本拍没有发射，且fq2ft消耗了，那么没有有效值
        fq2ft_valid_q <= 1'b0;

      // 更新 ft2fi 寄存器
      if (fq2ft_consume)//顺序流动，如果fq2ft消耗了
      begin
        if (!ft_bypass_ifq_alloc)//fq2ft消耗了，但没有通过旁路，也就是到达了ft2fi寄存器
        begin
          ft2fi_valid_q <= 1'b1;
          ft2fi_epoch_q <= fq2ft_epoch_q;
          ft2fi_pc_q <= fq2ft_pc_q;
          ft2fi_pred_next_pc_q <= FT_redirect_injected_q ?//如果这一拍是重定向，那么预测值还没有被fq2ft保存，只是刚给fq_pc跳转值，所以要用fq的预测值作为跳转值的pred_next
                               fq_pred_next_pc : fq2ft_pred_next_pc_q;
          ft2fi_pred_taken_q <= FT_redirect_injected_q ?
                             fq_pred_taken : fq2ft_pred_taken_q;
          ft2fi_pred_history_q <= FT_redirect_injected_q ?
                               fq_pred_history : fq2ft_pred_history_q;
          ft2fi_paddr_q <= ft_paddr;
          ft2fi_mat_q <= ft_mat;
          ft2fi_ex_adef_q <= ft_ex_adef;
          ft2fi_ex_tlbr_q <= ft_ex_tlbr;
          ft2fi_ex_pif_q <= ft_ex_pif;
          ft2fi_ex_ppi_q <= ft_ex_ppi;
        end
      end
      else if (ft2fi_consume)//顺序流动，fq2ft没有消耗，但ft2fi消耗了
        ft2fi_valid_q <= 1'b0;

      if (fi_req_fire && !inst_sram_cached)
        fi_uncached_inflight_q <= 1'b1;
      if (if_mem_resp_valid && fi_uncached_inflight_q)
        fi_uncached_inflight_q <= 1'b0;

      if (if_mem_resp_current)
      begin
        ifq_instr[if_mem_slot[if_mem_head]] <= inst_sram_rdata;
        ifq_ready[if_mem_slot[if_mem_head]] <= 1'b1;
      end
      if (if_mem_resp_valid)//不管是不是current，都得弹出
      begin
        if_mem_head <= if_mem_head + 3'd1;
      end

      if (fi_req_fire)//有请求握手，则补充if_mem
      begin
        if_mem_slot[if_mem_tail] <= ifq_tail;
        if_mem_epoch[if_mem_tail] <= ft_bypass_ifq_alloc ?
                    fq2ft_epoch_q : ft2fi_epoch_q;
        if_mem_tail <= if_mem_tail + 3'd1;
      end

      case ({fi_req_fire,if_mem_resp_valid})
        2'b10:
          if_mem_count <= if_mem_count + 4'd1;
        2'b01:
          if_mem_count <= if_mem_count - 4'd1;
        default:
          if_mem_count <= if_mem_count;
      endcase

      if (ifq_alloc)//有旁路或ft2fi分配给ifq
      begin
        ifq_pc_word[ifq_tail] <= ft_bypass_ifq_alloc ?
                   fq2ft_pc_q[31:2] : ft2fi_pc_q[31:2];
        ifq_pred_next_pc[ifq_tail] <= ft_bypass_ifq_alloc ?
                        (FT_redirect_injected_q ? fq_pred_next_pc : fq2ft_pred_next_pc_q) :
                        ft2fi_pred_next_pc_q;
        ifq_pred_taken[ifq_tail] <= ft_bypass_ifq_alloc ?
                      (FT_redirect_injected_q ? fq_pred_taken : fq2ft_pred_taken_q) :
                      ft2fi_pred_taken_q;
        ifq_pred_history[ifq_tail] <= ft_bypass_ifq_alloc ?
                        (FT_redirect_injected_q ? fq_pred_history : fq2ft_pred_history_q) :
                        ft2fi_pred_history_q;
        // 普通请求在存储响应返回前 ready=0，旧 instr 不可见，响应到达时会
        // 被完整覆盖；只为立即 ready 的异常项写 0，缩小普通 IFQ 分配驱动
        // 全部 instruction 寄存器同步清零端的控制锥。
        if (ft_bypass_ifq_alloc ? ft_has_exception : ft2fi_has_exception)
          ifq_instr[ifq_tail] <= 32'b0;
        ifq_bad_pc[ifq_tail] <= ft_bypass_ifq_alloc  ? fq2ft_pc_q : ft2fi_pc_q;
        ifq_ready[ifq_tail] <= ft_bypass_ifq_alloc   ? ft_has_exception : ft2fi_has_exception;
        ifq_ex_adef[ifq_tail] <= ft_bypass_ifq_alloc ? ft_ex_adef : ft2fi_ex_adef_q;
        ifq_ex_tlbr[ifq_tail] <= ft_bypass_ifq_alloc ? ft_ex_tlbr : ft2fi_ex_tlbr_q;
        ifq_ex_pif[ifq_tail] <= ft_bypass_ifq_alloc  ? ft_ex_pif : ft2fi_ex_pif_q;
        ifq_ex_ppi[ifq_tail] <= ft_bypass_ifq_alloc  ? ft_ex_ppi : ft2fi_ex_ppi_q;
        ifq_tail <= ifq_tail + 3'd1;
      end

      if (ifq_pop)
      begin
        ifq_ready[ifq_head] <= 1'b0;
        ifq_head <= ifq_head + 3'd1;
      end

      case ({ifq_alloc,ifq_pop})
        2'b10:
          ifq_count <= ifq_count + 4'd1;
        2'b01:
          ifq_count <= ifq_count - 4'd1;
        default:
          ifq_count <= ifq_count;
      endcase

    end
  end

  // ==================== ID 级信号声明 ====================

  wire [31:2] id_branch_target_word;//ID 级计算出的分支目标

  // 各级异常标志按ID到WB的流水顺序排列
  wire        id_has_exception;
  wire        ex2_has_exception_in;
  wire        ex2mem_has_exception;
  wire        mem_has_exception_final;
  wire        wbq_head_has_exception;
  // call: syscall/ break 指令中的 15 位 code 字段
  wire [14:0] id_exc_code;
  wire [14:0] ex12ex2_exc_code;
  wire [14:0] ex2mem_exc_code;
  wire [14:0] wbq_head_exc_code;

  // ecode:异常编码
  wire [5:0]  ex12ex2_exc_ecode;
  wire [5:0]  ex2mem_exc_ecode;
  wire [5:0]  wbq_head_exc_ecode;

  wire [31:0] wb_exception_entry;//异常处理程序的入口地址，由 CSR 模块输出
  wire [31:0] wb_instr_pc;//当前正在 WB 阶段提交的指令的地址
  wire [31:0] wb_ertn_pc;//执行 ertn 指令时的异常返回地址
  //raw：原始信号，尚未经过 ready 等提交条件过滤
  wire        wb_do_ertn_raw;              // WB 队首指令是 ertn,但没有检验是否ready
  wire        wb_do_ertn;                  // ertn 已ready，已可提交
  wire        wb_has_exception_commit_raw; // WB 队首携带异常,但没有检验是否ready
  wire        wb_has_exception_commit;     // 异常已可精确提交
  wire        wb_is_adef_exception;

  // ID级译码的原子、系统、TLB/cache维护及屏障类控制信号
  wire        id_op_load_linked, id_op_store_conditional;//ll.w和sc.w指令
  wire        id_op_tlbsrch, id_op_tlbrd, id_op_tlbwr, id_op_tlbfill;
  wire        id_op_invtlb, id_op_cacop, id_op_idle, id_op_cpucfg;
  wire        id_op_preld, id_op_dbar, id_op_ibar;
  wire [4:0]  id_invtlb_op; //invtlb的操作op，共有5位
  wire [1:0]  id_csr_op;
  // 中断与停顿控制
  wire        csr_has_int;//csr产生的外部中断，被绑定到ID级的指令上，并等待提交
  wire        id_idle_stall;

  // 异常编码常量
  localparam [13:0] CSR_TID   = 14'h0040;
  localparam [5:0] ECODE_INT  = 6'h00;
  localparam [5:0] ECODE_PIL  = 6'h01;
  localparam [5:0] ECODE_PIS  = 6'h02;
  localparam [5:0] ECODE_PIF  = 6'h03;
  localparam [5:0] ECODE_PME  = 6'h04;
  localparam [5:0] ECODE_PPI  = 6'h07;
  localparam [5:0] ECODE_ADE  = 6'h08;
  localparam [5:0] ECODE_ALE  = 6'h09;
  localparam [5:0] ECODE_SYS  = 6'h0b;
  localparam [5:0] ECODE_BRK  = 6'h0c;
  localparam [5:0] ECODE_INE  = 6'h0d;
  localparam [5:0] ECODE_IPE  = 6'h0e;
  localparam [5:0] ECODE_TLBR = 6'h3f;
  localparam [8:0] ESUBCODE_ADEF = 9'h000;

  // GPR的记分板,用于ID级的数据冒险
  localparam integer WBQ_DEPTH = 4;
  reg  [WBQ_DEPTH-1:0] gpr_wbq_slots[0:31];//slot为该gpr则会置1,可有多个1
  reg  [1:0]           gpr_wbq_latest_slot[0:31];//最新的slot编号,可能还没ready
  reg  [31:0]          gpr_wbq_latest_data[0:31];
  reg                  gpr_wbq_latest_ready[0:31];

  wire                 ex2mem_valid;
  wire [4:0]           ex2mem_gpr_waddr; // EX2到MEM级间通用寄存器写地址
  wire                 ex2mem_gpr_write_en;
  wire                 ex2mem_gpr_wdata_from_pc4; // GPR 写数据是 PC+4
  wire [4:0]           wbq_head_gpr_waddr; // WBQ 队首指令的 GPR 写地址
  wire                 wbq_head_gpr_write_en;//队首需要写
  wire                 wbq_head_gpr_wdata_from_pc4; // WBQ 队首写回数据是 PC+4
  reg  [31:0]          wb_gpr_wdata;
  wire                 wb_gpr_we; //当前确实能写



  wire [31:0] id_instr; // ID级指令
  wire [31:2] id_pc_plus_4_word;
  wire [31:2] id_pc_word;
  wire [31:0] id_pred_next_pc;
  wire        id_pred_taken;
  wire        id_pred_history;
  wire id_valid; // ID级有效位

  //由fetch取指产生的异常，传到id级
  wire id_fetch_ex_tlbr;
  wire id_fetch_ex_pif;
  wire id_fetch_ex_ppi;
  wire id_fetch_ex_adef;
  wire [31:0] id_fetch_bad_pc;//发生异常时的错误 PC，也就是取指使用的虚拟地址

  wire [4:0] id_rk_addr;          // 寄存器堆第二读口地址，来自 rk 或 rd 字段
  wire id_rk_addr_from_rd;        // 第二个读寄存器地址是否改为 rd 字段
  wire [31:0] id_rj_data;         // rj 源操作数，已包含 WB 到 ID 的旁路修正
  wire [31:0] id_rk_data;         // rk/rd 源操作数，已包含 WB 到 ID 的旁路修正

  reg id2ex1_en;                  // ID/EX1 流水寄存器写使能
  wire id2ex1_flush;              // 冲刷 ID/EX1 中的当前 ID 指令
  wire [4:0] id_gpr_waddr;        // 当前指令的通用寄存器写回地址
  wire id_high_result;            // 乘法取高半部或除法取余数的结果选择标志


  // 访存宽度编码：0=word，1=half，2=byte；sign 表示 load 到寄存器时，进行符号扩展还是0拓展
  reg  [1:0] id_width;
  wire       id_sign;


  //------------------------------------------------------------------
  //monitor监视信号，用于差分测试：把指令及其访存类型随流水线一路带到 WB 提交级，
  //生成 diff_* 测试输出。不参与 CPU 的实际运算或流水控制。
  reg [31:0] mon_ex1_inst;//当前 EX1 级指令的完整机器码
  reg [63:0] mon_ex1_timer;//指令进入 EX1 时记录的周期计数器值
  reg         mon_ex1_ldb;//当前指令是否为 ld.b
  reg         mon_ex1_ldh;
  reg         mon_ex1_ldbu;
  reg         mon_ex1_ldhu;
  reg         mon_ex1_stb;
  reg         mon_ex1_sth;



  // ==================== ID：信号赋值、译码、寄存器堆与控制 ====================

  IF_ID_reg IF_ID_reg(.clk(clk),.rst(rst),.En(if2id_en),.flush(if2id_flush),
                      .IF_PC_plus_4_word(ifq2id_pc_plus_4_word),.IF_PC_word(ifq2id_pc_word),
                      .IF_pred_next_pc(ifq_pred_next_pc[ifq_head]),
                      .IF_pred_taken(ifq_pred_taken[ifq_head]),
                      .IF_pred_history(ifq_pred_history[ifq_head]),
                      .IF_Instr(ifq2id_instr),.IF_valid(ifq2id_valid),
                      .fs_ex_adef(ifq_ex_adef[ifq_head]&ifq2id_valid),.fs_bad_pc(ifq_bad_pc[ifq_head]),
                      .fs_ex_tlbr(ifq_ex_tlbr[ifq_head]&ifq2id_valid),
                      .fs_ex_pif(ifq_ex_pif[ifq_head]&ifq2id_valid),
                      .fs_ex_ppi(ifq_ex_ppi[ifq_head]&ifq2id_valid),
                      .ID_PC_plus_4_word(id_pc_plus_4_word),.ID_Instr(id_instr),.ID_PC_word(id_pc_word),.ID_pred_next_pc(id_pred_next_pc),
                      .ID_pred_taken(id_pred_taken),.ID_pred_history(id_pred_history),.ID_valid(id_valid),
                      .id_fs_ex_adef(id_fetch_ex_adef),.id_fs_bad_pc(id_fetch_bad_pc),
                      .id_fs_ex_tlbr(id_fetch_ex_tlbr),.id_fs_ex_pif(id_fetch_ex_pif),.id_fs_ex_ppi(id_fetch_ex_ppi));


  // 译码
  wire [31:26] id_opcode_26=id_instr[31:26];
  wire [31:25] id_opcode_25=id_instr[31:25];
  wire [31:24] id_opcode_24=id_instr[31:24];
  wire [31:22] id_opcode_22=id_instr[31:22];
  wire [31:15] id_opcode_15=id_instr[31:15];
  wire [31:10] id_opcode_10=id_instr[31:10];


  wire [14:10] id_rk_field=id_instr[14:10];
  wire [9:5] id_rj_field=id_instr[9:5];
  wire [4:0] id_rd_field=id_instr[4:0];

  wire [21:10] id_imm12_field=id_instr[21:10];
  wire [23:10] id_imm14_field=id_instr[23:10];
  wire [25:10] id_imm16_field=id_instr[25:10];
  wire [25:0] id_imm26_field={id_instr[9:0],id_instr[25:10]};
  wire [14:10] id_shamt_field=id_instr[14:10]; // 移位立即数，slli.w,srli.w,srai.w
  wire [24:5] id_imm20_field=id_instr[24:5];   // lu12i.w/pcaddu12i 的 20 位立即数


  wire [31:0] id_imm12_sext={{20{id_imm12_field[21]}},id_imm12_field};
  wire [31:0] id_imm12_zext={20'b0,id_imm12_field};
  wire [31:0] id_imm14_sext_lsl2={{16{id_imm14_field[23]}},id_imm14_field,2'b00};
  wire [31:0] id_imm16_sext={{16{id_imm16_field[25]}},id_imm16_field};
  wire [31:0] id_imm26_sext={{6{id_imm26_field[25]}},id_imm26_field};
  wire [31:0] id_shamt5_zext={27'b0,id_shamt_field};
  wire [31:0] id_imm20_lsl12={id_imm20_field,12'b0};


  wire id_op_addw=(id_opcode_15==17'h20);
  wire id_op_subw=(id_opcode_15==17'h22);
  wire id_op_addiw=(id_opcode_22==10'hA);
  wire id_op_load_word=(id_opcode_22==10'hA2);
  wire id_op_store_word=(id_opcode_22==10'hA6);
  assign id_op_load_linked=(id_opcode_26==6'h08)&&!id_instr[25]&&!id_instr[24];
  assign id_op_store_conditional=(id_opcode_26==6'h08)&&!id_instr[25]&& id_instr[24];
  wire id_op_beq=(id_opcode_26==6'h16);
  wire id_op_bne=(id_opcode_26==6'h17);
  wire id_op_b=(id_opcode_26==6'h14);
  wire id_op_bl=(id_opcode_26==6'h15);
  wire id_op_jirl=(id_opcode_26==6'h13);
  wire id_op_slt=(id_opcode_15==17'h24);
  wire id_op_sltu=(id_opcode_15==17'h25);
  wire id_op_slliw=(id_opcode_15==17'h81);
  wire id_op_srliw=(id_opcode_15==17'h89);
  wire id_op_sraiw=(id_opcode_15==17'h91);
  wire id_op_lu12iw=(id_opcode_25==7'hA);
  wire id_op_and=(id_opcode_15==17'h29);
  wire id_op_or=(id_opcode_15==17'h2A);
  wire id_op_nor=(id_opcode_15==17'h28);
  wire id_op_xor=(id_opcode_15==17'h2B);
  wire id_op_slti=(id_opcode_22==10'h8);
  wire id_op_sltui=(id_opcode_22==10'h9);
  wire id_op_andi=(id_opcode_22==10'hd);
  wire id_op_ori=(id_opcode_22==10'he);
  wire id_op_xori=(id_opcode_22==10'hf);
  wire id_op_sllw=(id_opcode_15==17'h2E);
  wire id_op_srlw=(id_opcode_15==17'h2F);
  wire id_op_sraw=(id_opcode_15==17'h30);
  wire id_op_pcaddu12i=(id_opcode_25==7'hE);
  wire id_op_mulw=(id_opcode_15==17'h38);
  wire id_op_mulhw=(id_opcode_15==17'h39);
  wire id_op_mulhwu=(id_opcode_15==17'h3A);
  wire id_op_divw=(id_opcode_15==17'h40);
  wire id_op_modw=(id_opcode_15==17'h41);
  wire id_op_divwu=(id_opcode_15==17'h42);
  wire id_op_modwu=(id_opcode_15==17'h43);
  wire id_op_blt=(id_opcode_26==6'h18);
  wire id_op_bge=(id_opcode_26==6'h19);
  wire id_op_bltu=(id_opcode_26==6'h1A);
  wire id_op_bgeu=(id_opcode_26==6'h1B);
  wire id_op_load_byte=(id_opcode_22==10'hA0);
  wire id_op_load_half=(id_opcode_22==10'hA1);
  wire id_op_load_byte_unsigned=(id_opcode_22==10'hA8);
  wire id_op_load_half_unsigned=(id_opcode_22==10'hA9);
  wire id_op_store_byte=(id_opcode_22==10'hA4);
  wire id_op_store_half=(id_opcode_22==10'hA5);

  // CSR、异常、计数器和 cache/TLB 维护类指令
  wire id_op_csrrd=(id_opcode_24==8'h4&&id_rj_field==0);
  wire id_op_csrwr=(id_opcode_24==8'h4&&id_rj_field==1);
  wire id_op_csrxchg=(id_opcode_24==8'h4&&(id_rj_field!=0&&id_rj_field!=1));
  wire id_op_ertn=(id_opcode_10==22'h1920E);
  wire id_op_syscall=(id_opcode_15==17'h56);
  wire id_op_break=(id_opcode_15==17'h54);
  wire id_op_rdcntvl=(id_opcode_10==22'h18&&id_rj_field==0&&id_rd_field!=0);
  wire id_op_rdcntvh=(id_opcode_10==22'h19&&id_rj_field==0);
  wire id_op_rdcntid=(id_opcode_10==22'h18&&id_rd_field==0);
  assign id_op_cacop=(id_opcode_22==10'h18);
  assign id_op_cpucfg=(id_opcode_10==22'h1b);
  assign id_op_tlbsrch = (id_opcode_10 == 22'h1920a);
  assign id_op_tlbrd   = (id_opcode_10 == 22'h1920b);
  assign id_op_tlbwr   = (id_opcode_10 == 22'h1920c);
  assign id_op_tlbfill = (id_opcode_10 == 22'h1920d);
  assign id_op_invtlb  = (id_opcode_15 == 17'h0c93) && (id_instr[4:0] < 5'h07);
  assign id_op_idle    = (id_opcode_15 == 17'h0c91);
  assign id_op_preld   = (id_opcode_22 == 10'h0ab);
  assign id_op_dbar    = (id_opcode_15 == 17'h70e4);
  assign id_op_ibar    = (id_opcode_15 == 17'h70e5);


  assign id_invtlb_op  = id_instr[4:0];

  // 当前指令要访问的CSR 编号/地址
  wire [13:0] id_csr_num=id_op_rdcntid?CSR_TID:id_imm14_field; // rdcntid 读 TID，其余 CSR 类指令使用 id_imm14_field 字段。

  // syscall和break的code字段(不是异常)
  assign id_exc_code=id_instr[14:0];           // syscall/break 的 code 字段随异常提交给 CSR


  // **[改]**
  // 已实现指令集合。id_valid 且不在此集合内时产生 INE；取指异常优先级更高
  // 因为 INE 成立的前提是已经成功取到一条完整指令,如果取指阶段本身失败，就不能再根据 id_instr 判断指令是否合法
  wire id_known_instr=(id_op_addw|id_op_subw|id_op_addiw|id_op_load_word|id_op_store_word|id_op_load_linked|id_op_store_conditional|
                       id_op_beq|id_op_bne|id_op_b|id_op_bl|id_op_jirl|
                       id_op_slt|id_op_sltu|id_op_slliw|id_op_srliw|id_op_sraiw|id_op_lu12iw|
                       id_op_and|id_op_or|id_op_nor|id_op_xor|id_op_slti|id_op_sltui|id_op_andi|id_op_ori|id_op_xori|
                       id_op_sllw|id_op_srlw|id_op_sraw|id_op_pcaddu12i|
                       id_op_mulw|id_op_mulhw|id_op_mulhwu|id_op_divw|id_op_modw|id_op_divwu|id_op_modwu|
                       id_op_blt|id_op_bge|id_op_bltu|id_op_bgeu|
                       id_op_load_byte|id_op_load_half|id_op_load_byte_unsigned|id_op_load_half_unsigned|id_op_store_byte|id_op_store_half|
                       id_op_csrrd|id_op_csrwr|id_op_csrxchg|id_op_ertn|id_op_syscall|id_op_break|
                       id_op_rdcntvl|id_op_rdcntvh|id_op_rdcntid|id_op_cpucfg|
                       id_op_tlbsrch|id_op_tlbrd|id_op_tlbwr|id_op_tlbfill|id_op_invtlb|id_op_cacop|id_op_idle|
                       id_op_preld|id_op_dbar|id_op_ibar);
  wire id_has_if_exception = id_fetch_ex_adef | id_fetch_ex_tlbr | id_fetch_ex_pif | id_fetch_ex_ppi;
  wire id_op_ine=id_valid&&!id_has_if_exception&&!id_known_instr;



  // 特权指令:所有特权指令仅在PLV0特权等级下才能访问。但是可以在PLV3特权等级下执行Hit类CACOP指令。
  // 包括:CSR访问指令(csrrd csrwr csrxchg),Cache 维护指令(cacop),TLB 维护指令(tlbsrch tlbrd tlbwr
  // tlbfil invtlb)，其他指令(ertn idle)
  // 如果非 PLV0 执行特权指令，就产生 IPE（特权指令异常）

  // CACOP 属于特权指令，只允许 PLV0 执行；非 PLV0必须在产生任何 cache 副作用前触发 IPE
  // LA32 精简版允许 PLV3 执行 Hit 类 CACOP(op[4:3] == 2'b10);index/custom 类仍是 PLV0 特权操作。
  wire id_cacop_priv = id_op_cacop && (id_rd_field[4:3] != 2'b10);
  wire id_priv_instr=id_op_csrrd|id_op_csrwr|id_op_csrxchg|id_op_ertn|
       id_op_tlbsrch|id_op_tlbrd|id_op_tlbwr|id_op_tlbfill|id_op_invtlb|id_cacop_priv|id_op_idle;
  wire id_op_ipe=id_valid&&!id_has_if_exception&&(tc_csr_crmd_plv!=2'b00)&&id_priv_instr;//前提都是没有取指异常

  wire id_sync_exception=(id_op_syscall|id_op_break|id_op_ine|id_op_ipe);//id级产生的同步异常
  wire id_has_interrupt=csr_has_int&&id_valid&&!id_sync_exception&&!id_op_ertn;//ertn优先于异步中断，因为从ertn是
  // “异常处理上下文”切换回“被异常打断的上下文”。如果这个过程还没有完成就先接受新中断，
  // 新中断会基于旧的异常处理上下文保存状态，可能覆盖旧有信息.
  assign id_has_exception=id_sync_exception|id_has_interrupt|id_has_if_exception;
  // IDLE 被中断唤醒时应从下一条指令恢复；后端会用 PC_plus_4-4 写入 ERA，
  // 因此仅对真正由中断打断的 IDLE 多传一个字地址。
  wire [31:2] id_exception_pc_plus_4_word =
       (id_has_interrupt && id_op_idle && !id_has_if_exception)
       ? (id_pc_plus_4_word + 30'd1)
       : id_pc_plus_4_word;
  wire [5:0] id_exc_ecode=id_op_syscall?ECODE_SYS:
       (id_op_break?ECODE_BRK:
        (id_fetch_ex_adef?ECODE_ADE:
         (id_fetch_ex_tlbr?ECODE_TLBR:
          (id_fetch_ex_pif ?ECODE_PIF:
           (id_fetch_ex_ppi ?ECODE_PPI:
            (id_op_ine?ECODE_INE:
             (id_op_ipe?ECODE_IPE:
              (id_has_interrupt?ECODE_INT:6'b0))))))));


  // CSR 操作编码：1=读，2=写，3=按 rj 掩码交换；0 表示普通指令
  assign id_csr_op=(id_op_csrrd|id_op_rdcntid)?2'd1:(id_op_csrwr?2'd2:(id_op_csrxchg?2'd3:2'd0));


  // 分支目标使用字地址计算，因此扩展后的 offs16/offs26 可直接作为字偏移相加。
  wire id_branch_uses_imm16=id_op_beq|id_op_bne|id_op_blt|id_op_bge|id_op_bltu|id_op_bgeu;
  wire [29:0] id_branch_word_offset=id_branch_uses_imm16?id_imm16_sext[29:0]:id_imm26_sext[29:0];//分支跳转的偏移值
  assign id_branch_target_word=id_pc_word+id_branch_word_offset;

  // b/bl 的方向和目标在 ID 已完全确定。将更正后的 next-PC 随指令传递，避免它到 EX2 后对同一次 BTB miss 再重定向一次。
  wire id_is_direct_branch = id_valid && !id_has_exception && (id_op_b || id_op_bl);
  wire [31:0] id_direct_target = {id_branch_target_word,2'b00};
  // _eff: effective，ID 修正后随指令传递，并在 EX2 与真实下一 PC 比较。
  // id_pred_next_pc_eff并不直接驱动取指 PC，而是作为“后续判断是否误预测”的标识，随指令向后传递。
  // 现在设置好可避免 b/bl 被认为是误预测而再次跳转。
  wire [31:0] id_pred_next_pc_eff = id_is_direct_branch ?
       id_direct_target : id_pred_next_pc;


  // store、branch、csrwr/csrxchg 需要把 id_rd_field 字段作为第二读寄存器
  assign id_rk_addr=id_rk_addr_from_rd?id_rd_field:id_rk_field;

  //**[改]**
  // imm12或者imm14的立即数选择
  wire id_select_imm12_zext=id_op_andi|id_op_ori|id_op_xori;
  wire [31:0] id_imm_12_14_selected=(id_op_load_linked|id_op_store_conditional)?id_imm14_sext_lsl2:
       (id_select_imm12_zext?id_imm12_zext:id_imm12_sext);


  // 寄存器堆原始读口和 WB 级旁路数据
  wire [31:0] id_rj_data_raw;
  wire [31:0] id_rk_data_raw;
  wire [31:0] wb_bypass_data;

  Register Register(.clk(clk),.rst(rst),.Write_En(wb_gpr_we),.Read_rk_rd(id_rk_addr),
                    .Read_rj(id_rj_field),.Write_addr(wbq_head_gpr_waddr),.Write_data(wb_gpr_wdata),
                    .Read_rk_rd_data(id_rk_data_raw),.Read_rj_data(id_rj_data_raw),
                    .diff_gprs(diff_gprs));

  //load/store的字宽
  always@*
  begin
    if(id_op_load_byte|id_op_load_byte_unsigned|id_op_store_byte)
      id_width=2;
    else if(id_op_load_half|id_op_load_half_unsigned|id_op_store_half)
      id_width=1;
    else
      id_width=0;
  end

  //只有load考虑是否是符号拓展
  assign id_sign=id_op_load_byte|id_op_load_half;


  // 会改变翻译/cache 解释的控制指令携带 serializing 属性进入后端；真正进入
  // MEM 时才建立屏障。会影响取指解释的 CSR/TLB、I-cache CACOP 和 IBAR
  // 在退休后从 PC+4 重取。
  // 串行阻塞
  wire id_serializing = id_valid && !id_has_exception &&
       (id_csr_op[1] || id_op_tlbsrch || id_op_tlbrd || id_op_tlbwr ||
        id_op_tlbfill || id_op_invtlb || id_op_cacop || id_op_dbar || id_op_ibar);
  // 串行重取
  wire id_refetch = id_serializing &&
       (id_csr_op[1] || id_op_tlbrd || id_op_tlbwr ||
        id_op_tlbfill || id_op_invtlb ||
        (id_op_cacop && (id_rd_field[2:0] == 3'd0)) || id_op_ibar);
  wire id_op_store_no_wb=(id_op_store_word|id_op_store_half|id_op_store_byte);//普通存储且不写回通用寄存器的指令
  wire id_op_store_class=(id_op_store_no_wb|id_op_store_conditional);//包括sc.w这个条件存储

  //**[改]**
  assign id_rk_addr_from_rd=id_op_store_class|id_op_bne|id_op_beq|id_op_blt|id_op_bltu|id_op_bge|id_op_bgeu|id_op_csrwr|id_op_csrxchg;


  //**[改]**
  // 不写 GPR 的指令在 ID 级直接关闭写回,有异常这里就确定不写GPR
  wire id_gpr_write_en=~(id_op_store_no_wb|id_op_beq|id_op_bne|id_op_b|id_op_blt|id_op_bltu|id_op_bge|id_op_bgeu|id_op_ertn|id_has_exception|
                         id_op_tlbsrch|id_op_tlbrd|id_op_tlbwr|id_op_tlbfill|id_op_invtlb|id_op_cacop|id_op_idle|
                         id_op_preld|id_op_dbar|id_op_ibar);
  wire id_op_load_class=(id_op_load_word|id_op_load_linked|id_op_load_byte|id_op_load_byte_unsigned|id_op_load_half|id_op_load_half_unsigned);

  // 源寄存器真实使用掩码。LoongArch 的立即数、偏移量、CSR 编号等字段
  // 会与 rj/rk/rd 编码位置复用；若仅比较字段值，会把它们误判成 RAW 相关。
  //**[改]**
  //当前是“两个寄存器参与运算”的指令
  wire id_op_reg_reg_class = id_op_addw|id_op_subw|id_op_slt|id_op_sltu|
       id_op_and|id_op_or|id_op_nor|id_op_xor|id_op_sllw|id_op_srlw|id_op_sraw|
       id_op_mulw|id_op_mulhw|id_op_mulhwu|id_op_divw|id_op_modw|id_op_divwu|id_op_modwu;
  // 当前是“rj 加立即数”的运算指令
  wire id_op_imm_rj_class = id_op_addiw|id_op_slti|id_op_sltui|id_op_andi|id_op_ori|id_op_xori|
       id_op_slliw|id_op_srliw|id_op_sraiw;

  // 当前是条件分支指令
  wire id_op_cond_branch_class = id_op_beq|id_op_bne|id_op_blt|id_op_bge|id_op_bltu|id_op_bgeu;
  // 当前指令真的需要读取 rj
  wire id_uses_rj = id_valid && !id_has_exception &&
       (id_op_reg_reg_class|id_op_imm_rj_class|id_op_load_class|id_op_store_class|id_op_cacop|
        id_op_cond_branch_class|id_op_jirl|id_op_csrxchg|id_op_cpucfg|id_op_invtlb);
  // 当前指令真的需要读取第二个源寄存器(rk/rd)
  wire id_uses_rk = id_valid && !id_has_exception &&
       (id_op_reg_reg_class|id_op_store_class|id_op_cond_branch_class|
        id_op_csrwr|id_op_csrxchg|id_op_invtlb);

  // 对源操作数已在 WBQ 中表示的分支，特意在 ID/EX1 时钟沿之前完成分类。
  // 因此 EX1 短分支路径不会读取 WBQ ready/data 或退休状态。还需纳入将在
  // 同一时钟沿分配 WBQ 项的较早 MEM 生产者；否则其 slot 会晚一拍可见，
  // 无法参与此次分类。
  //ID的条件分支是否依赖 WBQ中未写回数据||或者即将写回数据
  wire id_branch_wbq_dep = id_valid && id_op_cond_branch_class &&
       (
         (
           (id_uses_rj && (id_rj_field != 5'd0)) && //而且 WBQ中有这个寄存器 或者 EX2/MEM 当前正要写回 rj
           ((|gpr_wbq_slots[id_rj_field])||(ex2mem_valid && ex2mem_gpr_write_en && (ex2mem_gpr_waddr == id_rj_field)))
         )||
         (
           (id_uses_rk && (id_rk_addr != 5'd0)) &&
           ((|gpr_wbq_slots[id_rk_addr]) ||(ex2mem_valid && ex2mem_gpr_write_en && (ex2mem_gpr_waddr == id_rk_addr)))
         )
       );

  // ID级的ALU B 操作数选择信号：寄存器、id_imm20_field、id_imm12_field、分支/jirl 偏移或移位立即数。
  reg [2:0] id_alu_b_sel;
  always@*
  begin
    if(id_op_lu12iw|id_op_pcaddu12i)
      id_alu_b_sel=1;
    else if(id_op_addiw|id_op_load_class|id_op_store_class|id_op_cacop|id_op_slti|id_op_sltui|id_op_andi|id_op_ori|id_op_xori)
      id_alu_b_sel=2;
    else if(id_op_beq|id_op_bne|id_op_jirl)
      id_alu_b_sel=3;
    else if(id_op_slliw|id_op_srliw|id_op_sraiw)
      id_alu_b_sel=4;
    else
      id_alu_b_sel=0;
  end
  wire id_store_en=id_op_store_class;


  // ALU 操作编码，乘除/取模作为长操作由 ALU 内部握手 ex2_long_finish。
  localparam [3:0] ALU_ADD = 4'd0;
  localparam [3:0] ALU_SUB = 4'd1;
  localparam [3:0] ALU_SLL = 4'd2;
  localparam [3:0] ALU_SRL = 4'd3;
  localparam [3:0] ALU_SRA = 4'd4;
  localparam [3:0] ALU_AND = 4'd5;
  localparam [3:0] ALU_OR  = 4'd6;
  localparam [3:0] ALU_NOR = 4'd7;
  localparam [3:0] ALU_XOR = 4'd8;
  localparam [3:0] ALU_jirl= 4'd9;
  localparam [3:0] ALU_I   = 4'd10;
  localparam [3:0] ALU_MUL = 4'd11;
  localparam [3:0] ALU_MULU= 4'd12;
  localparam [3:0] ALU_DIV = 4'd13;
  localparam [3:0] ALU_DIVU= 4'd14;

  wire [3:0] id_alu_op;
  assign id_alu_op =(id_op_subw|id_op_slt|id_op_sltu|id_op_slti|id_op_sltui|id_op_blt|id_op_bge|id_op_bltu|id_op_bgeu)?ALU_SUB:
         (id_op_and|id_op_andi)   ? ALU_AND :
         id_op_nor             ? ALU_NOR :
         (id_op_or|id_op_ori)     ? ALU_OR  :
         (id_op_xor|id_op_xori)   ? ALU_XOR :
         (id_op_slliw|id_op_sllw) ? ALU_SLL :
         (id_op_srliw|id_op_srlw) ? ALU_SRL :
         (id_op_sraiw|id_op_sraw) ? ALU_SRA :
         id_op_jirl            ? ALU_jirl:
         id_op_lu12iw          ? ALU_I   :
         (id_op_mulw|id_op_mulhw) ? ALU_MUL :
         id_op_mulhwu          ? ALU_MULU:
         (id_op_divw|id_op_modw)  ? ALU_DIV:
         (id_op_divwu|id_op_modwu)? ALU_DIVU:
         ALU_ADD;

  // GPR 写回来源在 ID 级编码，随流水线传到 EX2/WB。
  wire id_gpr_wdata_from_compare=(id_op_slti|id_op_slt|id_op_sltui|id_op_sltu);//写回比较结果0/1
  wire id_gpr_wdata_from_pc4=(id_op_bl|id_op_jirl);//写回PC+4


  //控制信号汇总
  //id2ex1一直送到ex1\ex2发挥作用的信号
  wire [11:0] id2ex1_ex_ctrl_in={id_op_jirl,id_op_slt,id_op_sltu,id_gpr_wdata_from_compare,
                                 id_gpr_wdata_from_pc4,id_alu_b_sel,id_alu_op};
  //id2ex1一直送到mem发挥作用的信号
  wire id2ex1_mem_ctrl_in=id_store_en;


  assign id_high_result=(id_op_mulhw|id_op_mulhwu|id_op_modw|id_op_modwu);


  assign id_gpr_waddr=(id_op_bl?5'd1:(id_op_rdcntid?id_rj_field:id_rd_field));//gpr写地址

  // -------------------- ID/EX1 流水寄存器 --------------------

  wire        id2ex1_valid; // ID到EX1级间有效位
  wire        id2ex1_serializing;//是串行
  wire        id2ex1_refetch;//需要重取
  wire [31:2] id2ex1_pc_plus_4_word; // ID到EX1级间PC加4字地址
  wire [31:0] id2ex1_pred_next_pc;
  wire        id2ex1_pred_taken;
  wire        id2ex1_pred_history;
  wire [31:0] id2ex1_rj_data;
  wire [31:0] id2ex1_rk_data;
  wire [31:0] id2ex1_imm_12_14_selected;
  wire [31:0] id2ex1_imm20_lsl12;
  wire [31:0] id2ex1_imm16_sext;
  wire [31:0] id2ex1_shamt5_zext;

  wire [4:0]  id2ex1_gpr_waddr;
  wire [4:0]  id2ex1_rj_addr;
  wire [4:0]  id2ex1_rk_addr;
  wire        id2ex1_uses_rj;
  wire        id2ex1_uses_rk;
  wire        id2ex1_branch_wbq_dep;

  wire [1:0]  id2ex1_csr_op;
  wire [13:0] id2ex1_csr_num;
  wire [14:0] id2ex1_exc_code;
  wire [5:0]  id2ex1_exc_ecode;
  wire        id2ex1_fetch_ex_adef;
  wire [31:0] id2ex1_fetch_bad_pc;
  wire [31:2] id2ex1_pc_word;

  wire [31:2] id2ex1_branch_target_word;//分支跳转目标先算出来
  wire [1:0]  id2ex1_width;
  wire        id2ex1_sign;
  wire        id2ex1_high_result;
  wire [11:0] id2ex1_ex_ctrl;
  wire        id2ex1_mem_ctrl;
  wire        id2ex1_gpr_write_en;
  wire        id2ex1_op_load_class;
  wire        id2ex1_op_beq, id2ex1_op_bne, id2ex1_op_bl, id2ex1_op_b;
  wire        id2ex1_op_slti, id2ex1_op_sltui, id2ex1_op_pcaddu12i;
  wire        id2ex1_op_ertn, id2ex1_has_exception;
  wire        id2ex1_op_blt, id2ex1_op_bge, id2ex1_op_bltu, id2ex1_op_bgeu;
  wire        id2ex1_op_rdcntvl, id2ex1_op_rdcntvh;
  wire        id2ex1_op_load_linked, id2ex1_op_store_conditional;
  wire        id2ex1_op_tlbsrch, id2ex1_op_tlbrd, id2ex1_op_tlbwr, id2ex1_op_tlbfill;
  wire        id2ex1_op_invtlb, id2ex1_op_cacop, id2ex1_op_cpucfg;
  wire [4:0]  id2ex1_invtlb_op;
  wire        ex1_op_jirl;
  wire [2:0]  ex1_alu_b_sel;
  wire        ex1_is_call;
  wire        ex1_is_return;
  reg  [31:0] ex1_alu_a;
  reg  [31:0] ex1_rk_value;
  reg  [31:0] ex1_alu_b;

  // 所有旁路:
  // WB → ID解决 WB 写寄存器和 ID 读寄存器同拍的冲突
  // EX2 → EX1   MEM → EX1   WBQ 队首 → EX1   WBQ 中最新 ready 结果 → EX1
  // WBQ 队首 → EX1： 用于csrrd/csrwr/csrxchg/rdcntid 的 CSR 旧值结果
  // WBQ 中最新 ready 结果 → EX1  : 用于 普通 ALU、bl/jirl、cpucfg、rdcntvl/vh、完成的乘除法、普通 load、SC 成功值
  // EX1 可能因多个晚到源操作数连续停留数拍。所以如果某个源先在 WB 退休，必须把该拍的旁路值保存下来。
  // 因为 id2ex1的值不会自动更新
  reg         ex1_saved_rj_valid;
  reg         ex1_saved_rk_valid;
  reg  [31:0] ex1_saved_rj_data;
  reg  [31:0] ex1_saved_rk_data;

  wire        ex12ex2_en;
  wire        ex12ex2_flush;
  // EX1/EX2 总线按 ex12ex2_bus_in 拼接顺序打包 valid、异常/特权控制、操作数、
  // 预测信息和快速访存提示；out 端必须以完全相同顺序解包。位宽改动需同步修改
  // pipeline.v 中实例参数，综合不会为该“总线”生成额外逻辑，只是一组触发器。
  localparam integer EX1_EX2_BUS_W = 316;
  wire [EX1_EX2_BUS_W-1:0] ex12ex2_bus_in;
  wire [EX1_EX2_BUS_W-1:0] ex12ex2_bus_out;
  reg [2:0] ex1_rj_bypass_sel;
  reg [2:0] ex1_rk_bypass_sel;

  ID_EX_reg ID_EX_reg(.clk(clk),.rst(rst),.En(id2ex1_en),.flush(id2ex1_flush),.ID_valid(id_valid),
                      .ID_serializing(id_serializing),.ID_refetch(id_refetch),.ID_PC_plus_4_word(id_exception_pc_plus_4_word),
                      .ID_pred_next_pc(id_pred_next_pc_eff),.ID_pred_taken(id_pred_taken),
                      .ID_pred_history(id_pred_history),.RJ_data(id_rj_data),
                      .RK_RD_data(id_rk_data),.ID_imm_12_14_selected(id_imm_12_14_selected),.ID_imm20_lsl12(id_imm20_lsl12),
                      .ID_imm16_sext(id_imm16_sext),.ID_shamt5_zext(id_shamt5_zext),.RD(id_gpr_waddr),
                      .ID_to_EX_control(id2ex1_ex_ctrl_in),
                      .ID_to_MEM_control(id2ex1_mem_ctrl_in),
                      .ID_gpr_write_en(id_gpr_write_en),
                      .RJ(id_rj_field),.RK_RD(id_rk_addr),.ID_uses_rj(id_uses_rj),.ID_uses_rk(id_uses_rk),
                      .ID_branch_wbq_dep(id_branch_wbq_dep),
                      .ID_CSR_Op(id_csr_op),.ID_csr_num(id_csr_num),
                      .ID_exc_code(id_exc_code),.ID_exc_ecode(id_exc_ecode),
                      .ID_fs_ex_adef(id_fetch_ex_adef),.ID_fs_bad_pc(id_fetch_bad_pc),
                      .OP_ldw(id_op_load_class),
                      .OP_beq(id_op_beq),.OP_bne(id_op_bne),
                      .OP_bl(id_op_bl),.OP_b(id_op_b),
                      .OP_slti(id_op_slti),.OP_sltui(id_op_sltui),
                      .OP_pcaddu12i(id_op_pcaddu12i),.OP_ertn(id_op_ertn),.ID_has_exception(id_has_exception),
                      .OP_blt(id_op_blt),.OP_bge(id_op_bge),.OP_bltu(id_op_bltu),.OP_bgeu(id_op_bgeu),
                      .OP_rdcntvl(id_op_rdcntvl),.OP_rdcntvh(id_op_rdcntvh),
                      .OP_llw(id_op_load_linked),.OP_scw(id_op_store_conditional),
                      .ID_IS_high(id_high_result),
                      .PC_jump_word(id_branch_target_word),
                      .ID_PC_word(id_pc_word),
                      .ID_width(id_width),.ID_sign(id_sign),
                      // TLB/CACOP 控制信号随流水级传递。
                      .OP_tlbsrch(id_op_tlbsrch),.OP_tlbrd(id_op_tlbrd),.OP_tlbwr(id_op_tlbwr),
                      .OP_tlbfill(id_op_tlbfill),.OP_invtlb(id_op_invtlb),.invtlb_op(id_invtlb_op),.OP_cacop(id_op_cacop),
                      .OP_cpucfg(id_op_cpucfg),
                      .EX_valid(id2ex1_valid),.EX_serializing(id2ex1_serializing),.EX_refetch(id2ex1_refetch),
                      .EX_PC_plus_4_word(id2ex1_pc_plus_4_word),.EX_pred_next_pc(id2ex1_pred_next_pc),.EX_pred_taken(id2ex1_pred_taken),
                      .EX_pred_history(id2ex1_pred_history),
                      .RJ_Op(id2ex1_rj_data),.RK_Op(id2ex1_rk_data),
                      .EX_imm_12_14_selected(id2ex1_imm_12_14_selected),.EX_imm20_lsl12(id2ex1_imm20_lsl12),
                      .EX_imm16_sext(id2ex1_imm16_sext),.EX_shamt5_zext(id2ex1_shamt5_zext),.EX_RD(id2ex1_gpr_waddr),
                      .ID_EX_control(id2ex1_ex_ctrl),
                      .ID_EX_to_MEM_control(id2ex1_mem_ctrl),
                      .EX_gpr_write_en(id2ex1_gpr_write_en),
                      .EX_RJ(id2ex1_rj_addr),.EX_RK_RD(id2ex1_rk_addr),.EX_uses_rj(id2ex1_uses_rj),.EX_uses_rk(id2ex1_uses_rk),
                      .EX_branch_wbq_dep(id2ex1_branch_wbq_dep),
                      .EX_CSR_Op(id2ex1_csr_op),.EX_csr_num(id2ex1_csr_num),
                      .EX_exc_code(id2ex1_exc_code),.EX_exc_ecode(id2ex1_exc_ecode),
                      .EX_fs_ex_adef(id2ex1_fetch_ex_adef),.EX_fs_bad_pc(id2ex1_fetch_bad_pc),
                      .EX_OP_ldw(id2ex1_op_load_class),
                      .EX_OP_beq(id2ex1_op_beq),.EX_OP_bne(id2ex1_op_bne),
                      .EX_OP_bl(id2ex1_op_bl),.EX_OP_b(id2ex1_op_b),
                      .EX_OP_slti(id2ex1_op_slti),.EX_OP_sltui(id2ex1_op_sltui),
                      .EX_OP_pcaddu12i(id2ex1_op_pcaddu12i),.EX_OP_ertn(id2ex1_op_ertn),.EX_has_exception(id2ex1_has_exception),
                      .EX_OP_blt(id2ex1_op_blt),.EX_OP_bge(id2ex1_op_bge),.EX_OP_bltu(id2ex1_op_bltu),.EX_OP_bgeu(id2ex1_op_bgeu),
                      .EX_OP_rdcntvl(id2ex1_op_rdcntvl),.EX_OP_rdcntvh(id2ex1_op_rdcntvh),
                      .EX_OP_llw(id2ex1_op_load_linked),.EX_OP_scw(id2ex1_op_store_conditional),
                      .EX_PC_word(id2ex1_pc_word),
                      .EX_IS_high(id2ex1_high_result),
                      .EX_PC_jump_word(id2ex1_branch_target_word),
                      .EX_width(id2ex1_width),.EX_sign(id2ex1_sign),
                      // 输出到 EX1 级的 TLB/CACOP 控制位。
                      .EX_OP_tlbsrch(id2ex1_op_tlbsrch),.EX_OP_tlbrd(id2ex1_op_tlbrd),.EX_OP_tlbwr(id2ex1_op_tlbwr),
                      .EX_OP_tlbfill(id2ex1_op_tlbfill),.EX_OP_invtlb(id2ex1_op_invtlb),.EX_invtlb_op(id2ex1_invtlb_op),.EX_OP_cacop(id2ex1_op_cacop),
                      .EX_OP_cpucfg(id2ex1_op_cpucfg)
                     );

  // EX1级使用的架构稳定计数器
  reg [63:0] stable_counter_q;
  always @(posedge clk)
  begin
    if (rst)
      stable_counter_q <= 64'b0;
    else
      stable_counter_q <= stable_counter_q + 64'd1;
  end

  // ==================== EX1：信号赋值、旁路与操作数选择 ====================

  // -------------------- EX1/EX2 流水寄存器输出（EX2 级）信号声明 --------------------

  // EX1到EX2级间携带的控制和操作类型
  wire [31:2] ex12ex2_branch_target_word;//分支跳转目标，从id传入
  wire        ex12ex2_op_ertn;
  wire        ex12ex2_op_load_class;
  wire        ex12ex2_op_load_linked;
  wire        ex12ex2_op_store_conditional;
  wire        ex12ex2_op_tlbsrch, ex12ex2_op_tlbrd, ex12ex2_op_tlbwr;
  wire        ex12ex2_op_tlbfill, ex12ex2_op_invtlb, ex12ex2_op_cacop;
  wire        ex12ex2_op_cpucfg;
  wire [4:0]  ex12ex2_invtlb_op;
  wire [1:0]  ex12ex2_csr_op;
  wire [13:0] ex12ex2_csr_num;
  wire [1:0]  ex12ex2_width;
  wire        ex12ex2_sign;
  wire [31:2] ex12ex2_pc_plus_4_word; // EX1到EX2级间PC加4字地址
  wire [4:0] ex12ex2_gpr_waddr;
  wire ex12ex2_high_result;

  wire ex2_long_finish; // EX2 长整数运算完成标志：乘法/除法单元已产生最终结果
  wire ex2_div_start_en; // EX2 除法启动使能：允许当前除法指令启动除法器
  wire ex2_long_op;     // EX2 长整数运算类型标志：当前 ALU 操作为乘法或除法
  wire ex2_long_exec;   // EX2 长整数运算执行标志：当前流水指令有效且正在执行长操作
  wire ex2_ale;
  wire ex12ex2_fetch_ex_adef;//经过了fetch和ex送来的adef异常
  wire [31:0] ex12ex2_fetch_bad_pc;

  wire [31:0] ex12ex2_alu_a; // EX1到EX2级间ALU操作数A
  wire [31:0] ex12ex2_alu_b; // EX1到EX2级间ALU操作数B
  wire [31:0] ex12ex2_rk_value; // EX1到EX2级间旁路修正后的rk值
  wire [31:0] ex12ex2_pred_next_pc;
  wire        ex12ex2_pred_history;
  wire        ex12ex2_is_call;//是否为call指令
  wire        ex12ex2_is_return;//是否为return指令
  wire [31:0] ex2_forward_data;//ex2送往ex1的前递数据
  wire [31:0] ex2_current_pc;//ex2本级指令对应pc
  wire        ex12ex2_valid; // EX1到EX2级间有效位
  wire        ex12ex2_serializing;
  wire        ex12ex2_refetch;
  // EX2级写回控制由ID级产生并随流水寄存器向后传递
  wire [3:0] ex2_alu_op;
  wire ex2_op_jirl;
  wire ex2_op_slt;
  wire ex2_op_sltu;
  wire ex2_store_en;
  wire ex2_gpr_wdata_from_compare;
  wire ex2_gpr_wdata_from_pc4;
  wire ex2_gpr_write_en;

  // EX2级分支和比较类指令标志
  wire ex12ex2_op_beq;
  wire ex12ex2_op_bne;
  wire ex12ex2_op_bl;
  wire ex12ex2_op_b;
  wire ex12ex2_op_slti;
  wire ex12ex2_op_sltui;
  wire ex12ex2_op_blt;
  wire ex12ex2_op_bge;
  wire ex12ex2_op_bltu;
  wire ex12ex2_op_bgeu;
  wire ex12ex2_op_rdcntvl;
  wire ex12ex2_op_rdcntvh;

  wire [11:0] ex12ex2_ex_ctrl;
  wire ex12ex2_mem_ctrl;
  wire ex12ex2_gpr_write_en;

  // ==================== 跨级旁路信号声明 ====================

  // EX1级选择源操作数旁路 EX2、MEM和WB级提供反馈
  reg [1:0] ex2_bypass_sel;
  wire [1:0] ex2mem_bypass_sel;//ex2_bypass结果会通过ex2mem传递到mem
  wire [1:0] mem_bypass_sel;
  reg [31:0] mem_bypass_data;
  wire [31:0] wbq_head_bypass_data;

  // ==================== EX1 使用的后级旁路反馈信号声明 ====================

  // EX1旁路和相关判断使用的MEM与WB反馈
  wire [31:2] ex2mem_pc_plus_4_word;
  wire        ex2mem_op_load_class;
  wire        ex2mem_op_store_conditional;
  wire        mem_sc_success;
  wire [31:0] mem_result; // MEM级结果反馈
  wire [31:0] wbq_head_result; // WBQ 队首指令的执行结果
  wire [31:2] wbq_head_pc_plus_4_word; // WBQ 队首指令的 PC+4 字地址
  wire        wbq_head_op_load_class;
  wire        wbq_head_op_store_conditional;
  wire        wbq_head_sc_success;
  wire [31:0] wb_load_data;
  wire        wb_is_csr;
  reg         wb_csr_read_valid_q;
  reg  [31:0] wb_csr_old_data_q;


  wire [WBQ_DEPTH-1:0] ex1_rj_wbq_slots = gpr_wbq_slots[id2ex1_rj_addr];
  wire [WBQ_DEPTH-1:0] ex1_rk_wbq_slots = gpr_wbq_slots[id2ex1_rk_addr];
  wire ex1_rj_wbq_bypass_ready;
  wire ex1_rk_wbq_bypass_ready;
  wire [31:0] ex1_rj_wbq_bypass_data;
  wire [31:0] ex1_rk_wbq_bypass_data;
  reg         mem_issue_checked_q;//表示当前 MEM 指令的地址翻译是否已经完成
  wire        mem_resp_fire;//当前周期收到了一次 CACOP 操作完成的响应
  wire        mem_is_csr;//表示当前 EX2/MEM 指令是否为 CSR 指令
  wire        mem_sc_attempt;//表示当前 SC.W 是否真的具备执行条件，准备尝试条件存储
  //monitor
  reg [31:0] mon_ex2_inst;
  reg [63:0] mon_ex2_timer;
  reg         mon_ex2_ldb;
  reg         mon_ex2_ldh;
  reg         mon_ex2_ldbu;
  reg         mon_ex2_ldhu;
  reg         mon_ex2_stb;
  reg         mon_ex2_sth;
  //信号拆解
  assign ex1_op_jirl = id2ex1_ex_ctrl[11];
  assign ex1_alu_b_sel = id2ex1_ex_ctrl[6:4];
  // 旁路数据选择：bl/jirl 旁路 PC+4，普通 ALU 指令旁路 ALU 结果，sc.w 在 MEM/WB 级旁路成功标志。
  assign mem_bypass_sel = ex2mem_op_store_conditional ? {1'b1, mem_sc_success} : ex2mem_bypass_sel;

  always@*
  begin
    if(ex12ex2_op_bl|ex2_op_jirl)
      ex2_bypass_sel=1;
    else
      ex2_bypass_sel=0;
  end


  always@*
  begin
    case(mem_bypass_sel)
      0:
        mem_bypass_data=mem_result;
      1:
        mem_bypass_data={ex2mem_pc_plus_4_word,2'b00};
      2:
        mem_bypass_data=0;
      3:
        mem_bypass_data=1;
    endcase
  end

  assign wb_bypass_data=wbq_head_op_store_conditional ? {31'b0, wbq_head_sc_success} :
         (wb_is_csr?wb_csr_old_data_q:(wbq_head_op_load_class?wb_load_data:wbq_head_bypass_data));

  // 数据相关处理：
  // - 普通 EX->ID 相关放行，等下一拍变成 EX2→EX1 后由旁路修正；
  // - WB 同拍写回可旁路到 ID，避免寄存器堆读到旧值；
  // - load 和 CSR 结果需要停顿到数据可用；
  // - WB 级 CSR 读旧值在退休队首局部等待，不再冻结前端
  wire mem_bypass_en=(ex2mem_gpr_write_en)&&(ex2mem_gpr_waddr!=0)&&!mem_is_csr&&!ex2mem_op_load_class;
  // 可以旁路:确实写&& 不写0 && 不是csr指令 && 不是load.
  // load 在 MEM 阶段的 mem_result 是地址，不是从 Cache 返回的数据。load 数据要等 LQ/WBQ 准备好后再旁路。
  // CSR 指令的 GPR 写回值是 CSR 旧值，当前 MEM 的 mem_result 不是这个最终值，所以必须等待 WB/WBQ 旁路。
  wire wb_bypass_en=(wbq_head_gpr_write_en)&&(wbq_head_gpr_waddr!=0);//要写且不是写0
  wire ex2_bypass_en=ex12ex2_valid&&ex2_gpr_write_en&&(ex12ex2_gpr_waddr!=0)&&
       !ex12ex2_op_load_class&&(ex12ex2_csr_op==2'b0)&&!ex12ex2_op_store_conditional&&//不是csr指令，也不是sc指令(sc指令只是计算了地址)
       (!ex2_long_op || ex2_long_finish);//操作还没有结束


  always@*
  begin
    if(id2ex1_uses_rj&&(id2ex1_rj_addr==ex12ex2_gpr_waddr)&&ex2_bypass_en)
      ex1_rj_bypass_sel=1;
    else if(id2ex1_uses_rj&&(id2ex1_rj_addr==ex2mem_gpr_waddr)&&mem_bypass_en)
      ex1_rj_bypass_sel=2;
    else if(id2ex1_uses_rj&&(id2ex1_rj_addr!=5'd0)&&ex1_rj_wbq_bypass_ready)//如果wbq中有最新ready的rj
      ex1_rj_bypass_sel=4;
    else if(id2ex1_uses_rj&&(id2ex1_rj_addr==wbq_head_gpr_waddr)&&wb_bypass_en)//如果wbq同拍正好要读出(如果没有ready会阻塞流水级，直到ready再旁路)(似乎没有必要)
      ex1_rj_bypass_sel=3;
    else
      ex1_rj_bypass_sel=0;
  end


  always@*
  begin
    if(id2ex1_uses_rk&&(id2ex1_rk_addr==ex12ex2_gpr_waddr)&&ex2_bypass_en)
      ex1_rk_bypass_sel=1;
    else if(id2ex1_uses_rk&&(id2ex1_rk_addr==ex2mem_gpr_waddr)&&mem_bypass_en)
      ex1_rk_bypass_sel=2;
    else if(id2ex1_uses_rk&&(id2ex1_rk_addr!=5'd0)&&ex1_rk_wbq_bypass_ready)//如果wbq中有最新ready的rk
      ex1_rk_bypass_sel=4;
    else if(id2ex1_uses_rk&&(id2ex1_rk_addr==wbq_head_gpr_waddr)&&wb_bypass_en)//如果wbq同拍正好要读出(如果没有ready会阻塞流水级，直到ready再旁路)(似乎没有必要)
      ex1_rk_bypass_sel=3;
    else
      ex1_rk_bypass_sel=0;
  end

  // 正好同拍读出（如果没有ready，会暂停流水级，所以没有影响）
  wire wb_to_id_bypass_en=wb_gpr_we&&(wbq_head_gpr_waddr!=5'd0);
  assign id_rj_data=(wb_to_id_bypass_en&&id_rj_field==wbq_head_gpr_waddr)?wb_gpr_wdata:id_rj_data_raw;
  assign id_rk_data=(wb_to_id_bypass_en&&id_rk_addr==wbq_head_gpr_waddr)?wb_gpr_wdata:id_rk_data_raw;

  // 在 ID/EX1 保持期间吸收已经退休的源操作数。流水寄存器装入新指令或被冲刷时清除；
  always @(posedge clk)
  begin
    if(rst || (id2ex1_flush && id2ex1_en))//rst/被冲刷
    begin
      ex1_saved_rj_valid <= 1'b0;
      ex1_saved_rk_valid <= 1'b0;
      ex1_saved_rj_data <= 32'b0;
      ex1_saved_rk_data <= 32'b0;
    end
    else if(id2ex1_en)//id2ex1恢复运行
    begin
      ex1_saved_rj_valid <= 1'b0;
      ex1_saved_rk_valid <= 1'b0;
    end
    else if(id2ex1_valid && wb_gpr_we)
      // ex1_saved_rj_data记录的并不一定是最新的ready，而是EX1 停顿期间，最近一次
      // 从 WBQ 队首退休、且目的寄存器等于当前 rk 的写回值。
    begin
      if(id2ex1_uses_rj && (wbq_head_gpr_waddr != 5'd0) && (id2ex1_rj_addr == wbq_head_gpr_waddr))
      begin
        ex1_saved_rj_valid <= 1'b1;
        ex1_saved_rj_data <= wb_gpr_wdata;
      end
      if(id2ex1_uses_rk && (wbq_head_gpr_waddr != 5'd0) && (id2ex1_rk_addr == wbq_head_gpr_waddr))
      begin
        ex1_saved_rk_valid <= 1'b1;
        ex1_saved_rk_data <= wb_gpr_wdata;
      end
    end
  end


  //========================需要等待(阻塞)============================

  //需要等待ex2的数据冒险（EX2 中的指令确实有效、会写通用寄存器，但结果还没有准备好，不能立即前递）
  wire ex2_result_late=ex12ex2_valid&&ex2_gpr_write_en&&
       (ex12ex2_op_load_class||(ex12ex2_csr_op!=2'b0)||ex12ex2_op_store_conditional||
        (ex2_long_exec&&!ex2_long_finish));
  wire ex1_rj_ex_late=id2ex1_uses_rj&&(id2ex1_rj_addr==ex12ex2_gpr_waddr)&&(ex12ex2_gpr_waddr!=0)&&ex2_result_late;
  wire ex1_rk_ex_late=id2ex1_uses_rk&&(id2ex1_rk_addr==ex12ex2_gpr_waddr)&&(ex12ex2_gpr_waddr!=0)&&ex2_result_late;

  //需要等待mem的数据冒险
  wire ex1_rj_mem_load=id2ex1_uses_rj&&(id2ex1_rj_addr==ex2mem_gpr_waddr)&&(ex2mem_gpr_waddr!=0)&&ex2mem_op_load_class;
  wire ex1_rk_mem_load=id2ex1_uses_rk&&(id2ex1_rk_addr==ex2mem_gpr_waddr)&&(ex2mem_gpr_waddr!=0)&&ex2mem_op_load_class;
  wire ex1_rj_mem_csr=id2ex1_uses_rj&&(id2ex1_rj_addr==ex2mem_gpr_waddr)&&(ex2mem_gpr_waddr!=0)&&mem_is_csr;
  wire ex1_rk_mem_csr=id2ex1_uses_rk&&(id2ex1_rk_addr==ex2mem_gpr_waddr)&&(ex2mem_gpr_waddr!=0)&&mem_is_csr;
  // SC 的成功标志要等 MEM 地址检查完成后才有效。普通消费者会被pipeline_wait阻止；
  // 但是条件分支不一样，条件分支可以在 EX1 提前解析，并且设计上允许它在 pipeline_wait 期间进行比较。
  // 那么就必须要先确保sc结束，才能解析，于是设置sc_pending
  wire ex1_rj_mem_sc_pending=id2ex1_uses_rj&&(id2ex1_rj_addr==ex2mem_gpr_waddr)&&(ex2mem_gpr_waddr!=0)&&
       ex2mem_op_store_conditional&&mem_sc_attempt&&!mem_issue_checked_q;
  wire ex1_rk_mem_sc_pending=id2ex1_uses_rk&&(id2ex1_rk_addr==ex2mem_gpr_waddr)&&(ex2mem_gpr_waddr!=0)&&
       ex2mem_op_store_conditional&&mem_sc_attempt&&!mem_issue_checked_q;

  // 直接以源寄存器号读取最年轻 WBQ 生产者。任意 slot 的普通 GPR
  // 结果 ready 后都可旁路；只有最年轻生产者尚未完成时才真正等待。
  wire ex1_rj_wbq_pending = id2ex1_uses_rj && (id2ex1_rj_addr != 5'b0) &&
       (|ex1_rj_wbq_slots) &&
       !ex1_rj_wbq_bypass_ready;
  wire ex1_rk_wbq_pending = id2ex1_uses_rk && (id2ex1_rk_addr != 5'b0) &&
       (|ex1_rk_wbq_slots) &&
       !ex1_rk_wbq_bypass_ready;

  // ex1由于数据冒险导致的等待(这里没有考虑sc造成的等待，因为sc会产生pipeline_wait，这里就不重复考虑阻塞了)
  wire ex1_data_wait=id2ex1_valid&&
       (ex1_rj_ex_late||ex1_rk_ex_late||
        ex1_rj_mem_load||ex1_rk_mem_load||
        ex1_rj_mem_csr||ex1_rk_mem_csr||
        ex1_rj_wbq_pending||ex1_rk_wbq_pending);

  wire ex1_rj_pc_choose=id2ex1_op_pcaddu12i;//当要选择rj或者pc时，选pc
  wire [31:0] ex1_rj_base = ex1_saved_rj_valid ?//rj base，但还需经过旁路选择
       ex1_saved_rj_data : id2ex1_rj_data;
  wire [31:0] ex1_rk_base = ex1_saved_rk_valid ?
       ex1_saved_rk_data : id2ex1_rk_data;

  // EX1 完成旁路和立即数选择，结果随正式 EX1/EX2 流水寄存器前进。
  always@*
  begin
    if(ex1_rj_pc_choose)
      ex1_alu_a={id2ex1_pc_word,2'b0};
    else
    begin
      case(ex1_rj_bypass_sel)
        0:
          ex1_alu_a=ex1_rj_base;
        1:
          ex1_alu_a=ex2_forward_data;
        2:
          ex1_alu_a=mem_bypass_data;
        3:
          ex1_alu_a=wb_bypass_data;//来自 WBQ 队首，也就是当前准备退休/写回的指令
        4:
          ex1_alu_a=ex1_rj_wbq_bypass_data;//写 rk 的最新且已经 ready 的指令
        default:
          ex1_alu_a=ex1_rj_base;
      endcase
    end
  end

  always@*
  begin
    ex1_rk_value=ex1_rk_base;
    case(ex1_rk_bypass_sel)
      0:
        ex1_rk_value=ex1_rk_base;
      1:
        ex1_rk_value=ex2_forward_data;
      2:
        ex1_rk_value=mem_bypass_data;
      3:
        ex1_rk_value=wb_bypass_data;//来自 WBQ 队首，也就是当前准备退休/写回的指令
      4:
        ex1_rk_value=ex1_rk_wbq_bypass_data;//写 rk 的最新且已经 ready 的指令
      default:
        ex1_rk_value=ex1_rk_base;
    endcase
  end

  // 形成真正送入 ALU 的 B 操作数。普通算术取寄存器/立即数，jirl 使用左移后的 id_imm16_field，
  // invtlb 的地址操作数从专门端口进入 TLB，因此这里清零避免误参与 ALU。
  always@*
  begin
    ex1_alu_b=ex1_rk_value;
    case(ex1_alu_b_sel)
      0:
        ex1_alu_b=id2ex1_op_invtlb ? 32'b0 : ex1_rk_value;
      1:
        ex1_alu_b=id2ex1_imm20_lsl12;
      2:
        ex1_alu_b=id2ex1_imm_12_14_selected;
      3:
        ex1_alu_b=ex1_op_jirl ? {id2ex1_imm16_sext[29:0],2'b00} : id2ex1_imm16_sext;
      4:
        ex1_alu_b=id2ex1_shamt5_zext;
      default:
        ex1_alu_b=id2ex1_op_invtlb ? 32'b0 : ex1_rk_value;
    endcase
  end

  // LoongArch 中 r1 为返回地址寄存器。bl 恒为 call；jirl 写 r1 也视为 call；
  // jirl r0,r1,0 视为 return，其余 jirl 为间接跳转。
  assign ex1_is_call = id2ex1_op_bl || (ex1_op_jirl && (id2ex1_gpr_waddr == 5'd1));
  assign ex1_is_return = ex1_op_jirl && (id2ex1_gpr_waddr == 5'd0) &&
         (id2ex1_rj_addr == 5'd1) && (id2ex1_imm16_sext == 32'b0);

  // 汇总信号
  assign ex12ex2_bus_in = {id2ex1_valid,id2ex1_serializing,id2ex1_refetch,id2ex1_pc_plus_4_word,id2ex1_gpr_waddr,
                           id2ex1_ex_ctrl,id2ex1_mem_ctrl,id2ex1_gpr_write_en,
                           id2ex1_csr_op,id2ex1_csr_num,
                           id2ex1_exc_code,id2ex1_exc_ecode,id2ex1_fetch_ex_adef,id2ex1_fetch_bad_pc,id2ex1_op_load_class,id2ex1_op_beq,id2ex1_op_bne,
                           id2ex1_op_bl,id2ex1_op_b,id2ex1_op_slti,id2ex1_op_sltui,id2ex1_op_ertn,id2ex1_has_exception,
                           id2ex1_op_blt,id2ex1_op_bge,id2ex1_op_bltu,id2ex1_op_bgeu,id2ex1_op_rdcntvl,id2ex1_op_rdcntvh,id2ex1_op_load_linked,
                           id2ex1_op_store_conditional,id2ex1_high_result,id2ex1_branch_target_word,id2ex1_width,id2ex1_sign,id2ex1_op_tlbsrch,id2ex1_op_tlbrd,
                           id2ex1_op_tlbwr,id2ex1_op_tlbfill,id2ex1_op_invtlb,id2ex1_invtlb_op,id2ex1_op_cacop,id2ex1_op_cpucfg,
                           ex1_alu_a,ex1_rk_value,ex1_alu_b,
                           id2ex1_pred_next_pc,id2ex1_pred_history,
                           ex1_is_call,ex1_is_return};

  //模块名 #(.参数名(参数值)) 实例名 (.端口名(当前模块中的信号));
  //对应声明:module EX1_EX2_reg #(
  //     parameter BUS_W = 128
  //    )(
  //        ...
  //    );
  EX1_EX2_reg #(.BUS_W(EX1_EX2_BUS_W)) EX1_EX2_reg(
                .clk(clk),.rst(rst),.En(ex12ex2_en),.flush(ex12ex2_flush),
                .bus_in(ex12ex2_bus_in),.bus_out(ex12ex2_bus_out));

  // ==================== EX2：信号赋值、ALU 与分支确认 ====================


  wire [31:0] ex2_store_data;  // 经过旁路修正后的写入内存的数据（修正后的rk的数据）,是从ex1产生的ex12ex2_rk_value
  // EX2级执行结果和提交控制
  wire [31:0] ex2_alu_result;  // 当前指令的普通运算结果，或乘除法结果
  wire [31:0] ex2_addr_result; // 访存与jirl使用的地址加法结果（与ALU相独立的加法器）
  wire        ex2_commit_fire; // EX2指令本拍进入MEM
  wire        mem_backpressure;// MEM级对EX2的反压
  wire        ex2_slt, ex2_sltu;

  // LL和SC共享的保留地址状态
  wire        csr_llbit;//CSR 模块输出的架构级 LLBit，实际来自 LLBCTL.ROLLB
  reg         lladdr_valid_q;//表示 lladdr_q 当前是否有效，与csr_llbit一致，防止使用复位后或保留状态已经失效的旧地址
  reg  [31:4] lladdr_q;//保存上一次成功提交的 LL.W 高位地址。SC.W 必须和它位于同一个 16 字节保留粒度内，否则失败

  // -------------------- EX2/MEM 流水寄存器与快速路径信号声明 --------------------

  // EX2到MEM级间寄存器控制和负载
  wire        ex2mem_en;
  reg         ex2mem_flush;
  wire        ex2mem_serializing;
  wire        ex2mem_refetch;

  wire [31:0] ex2mem_store_data;
  wire [31:0] ex2mem_result;
  wire [31:0] ex2mem_rk_data;
  wire        ex2mem_op_load_linked;
  wire        ex2mem_op_ertn;
  wire        ex2mem_op_tlbsrch, ex2mem_op_tlbrd, ex2mem_op_tlbwr;
  wire        ex2mem_op_tlbfill, ex2mem_op_invtlb, ex2mem_op_cacop;
  wire [4:0]  ex2mem_invtlb_op;
  wire [1:0]  ex2mem_csr_op;
  wire [13:0] ex2mem_csr_num;
  wire [31:0] ex2mem_csr_rj_data;
  wire [1:0]  ex2mem_width;
  wire        ex2mem_sign;
  wire        ex2mem_mem_ctrl;


  // 快速访存资格
  wire        ex2_fast_direct_req_eligible;//EX2 阶段计算出的“该 load 是否可以直接发起缓存请求”
  wire        ex2mem_fast_direct_req_eligible;//ex2_fast_direct_req_eligible传到寄存器
  wire        ex2_fast_direct_valid;//当前 MEM 指令是否具备快速 direct 路径
  wire        ex2mem_fast_direct_valid;//ex2_fast_direct_valid传到寄存器
  wire [31:0] ex2_fast_direct_paddr;//EX2 阶段提前计算出的物理地址，进入 MEM 后直接作为快速路径的物理地址使用
  wire [31:0] ex2mem_fast_direct_paddr;

  // 地址冲突检测
  reg         ex2_fast_store_hash_match;//判断当前 EX2 load 是否可能与较老的 cached store 地址冲突
  wire        ex2mem_fast_store_hash_match;

  //先store后load冲突时，数据的前递，需要区分之前是st.b/st.h之类的
  reg  [31:0] ex2_fast_forward_data;//前递的store数据给load
  reg  [3:0]  ex2_fast_forward_mask;//某一位为 1，表示对应字节可以从旧 store 转发
  reg         mem_fast_forward_valid_q;//表示当前 MEM 中是否保存了一份快速转发快照
  reg  [31:0] mem_fast_forward_data_q;//保存从 EX2 传来的转发数据
  reg  [3:0]  mem_fast_forward_mask_q;//保存从 EX2 传来的字节有效掩码

  integer     ex2_store_hash_slot;//用于遍历 SB 和 WBQ 的循环变量，不是架构状态
  integer     ex2_store_fwd_age;//遍历age，index = head + age
  integer     ex2_store_fwd_lane;//遍历 4 个字节 lane
  integer     ex2_store_fwd_index;//index = head + age


  assign {ex12ex2_valid,ex12ex2_serializing,ex12ex2_refetch,ex12ex2_pc_plus_4_word,ex12ex2_gpr_waddr,
          ex12ex2_ex_ctrl,ex12ex2_mem_ctrl,ex12ex2_gpr_write_en,
          ex12ex2_csr_op,ex12ex2_csr_num,
          ex12ex2_exc_code,ex12ex2_exc_ecode,ex12ex2_fetch_ex_adef,ex12ex2_fetch_bad_pc,ex12ex2_op_load_class,ex12ex2_op_beq,ex12ex2_op_bne,
          ex12ex2_op_bl,ex12ex2_op_b,ex12ex2_op_slti,ex12ex2_op_sltui,ex12ex2_op_ertn,ex2_has_exception_in,
          ex12ex2_op_blt,ex12ex2_op_bge,ex12ex2_op_bltu,ex12ex2_op_bgeu,ex12ex2_op_rdcntvl,ex12ex2_op_rdcntvh,ex12ex2_op_load_linked,
          ex12ex2_op_store_conditional,ex12ex2_high_result,ex12ex2_branch_target_word,ex12ex2_width,ex12ex2_sign,ex12ex2_op_tlbsrch,ex12ex2_op_tlbrd,
          ex12ex2_op_tlbwr,ex12ex2_op_tlbfill,ex12ex2_op_invtlb,ex12ex2_invtlb_op,ex12ex2_op_cacop,ex12ex2_op_cpucfg,
          ex12ex2_alu_a,ex12ex2_rk_value,ex12ex2_alu_b,
          ex12ex2_pred_next_pc,ex12ex2_pred_history,
          ex12ex2_is_call,ex12ex2_is_return} = ex12ex2_bus_out;

  // 地址类指令恒做加法
  assign {ex2_op_jirl,ex2_op_slt,ex2_op_sltu,ex2_gpr_wdata_from_compare,
          ex2_gpr_wdata_from_pc4}=ex12ex2_ex_ctrl[11:7];
  assign ex2_alu_op=ex12ex2_ex_ctrl[3:0];
  assign ex2_store_en=ex12ex2_mem_ctrl;
  assign ex2_gpr_write_en=ex12ex2_gpr_write_en;
  assign ex2_store_data=ex12ex2_rk_value;


  assign ex2_long_op=(ex2_alu_op==ALU_MUL)||(ex2_alu_op==ALU_MULU)||(ex2_alu_op==ALU_DIV)||(ex2_alu_op==ALU_DIVU);
  assign ex2_long_exec=ex12ex2_valid&&ex2_long_op&&!ex2_has_exception_in;//当前 EX2 流水寄存器中的指令属于长运算，并且没有携带异常，表示该指令进入乘除法协议的生命周期
  // 只允许 EX2 同级或更老的恢复杀死当前长运算；ID/EX1 恢复来自更年轻指令。
  wire ex2_long_kill=EX2_back_redirect_valid||wb_has_exception_commit||wb_do_ertn;
  wire ex2_result_take;//这一拍真正接收这个结果: 结果已准备好；没有重定向或当前 WB 异常/ERTN；MEM 没有反压；没有串行屏障。



  cpu_top_alu u_cpu_top_alu(.clk(clk),.rst(rst),.A(ex12ex2_alu_a),.B(ex12ex2_alu_b),.ALUop(ex2_alu_op),.EX_IS_high(ex12ex2_high_result),
                            .ALU_result(ex2_alu_result),.add_result(ex2_addr_result),
                            .slt_En(ex2_slt),.sltu_En(ex2_sltu),
                            .finish(ex2_long_finish),.divider_en(ex2_div_start_en),
                            .long_kill(ex2_long_kill),.result_take(ex2_result_take));

  // cpucfg在EX2级按索引返回固定配置并与cache参数保持一致
  function [31:0] cpucfg_read;
    input [31:0] index;//通过index(rj)输入，输出查询值(cpucfg_read)
    begin
      case(index)
        32'h00000001:
          cpucfg_read = 32'h0001f1f4;
        32'h00000002:
          cpucfg_read = 32'h00000000;

        // L1 I/D 均存在；L2 为每核私有、统一、非 inclusive cache。
        // bit0=L1I，bit2=L1D，bit3=存在 L2IU，bit4=unified，bit5=private。
        32'h00000010:
          cpucfg_read = 32'h0000003d;

        // cache 描述字段：[31:24]=offset 宽度，[23:16]=index 宽度，[15:0]=路数-1。
        32'h00000011:
          cpucfg_read = 32'h040a0001; // I-cache：16B 缓存行，1024 组，2 路。
        32'h00000012:
          cpucfg_read = 32'h040b0001; // D-cache：16B 缓存行，2048 组，2 路（64 KiB）。

        32'h00000013:
          cpucfg_read = 32'h040b0003; // L2：16B 缓存行，2048 组，4 路（128 KiB）。

        default:
          cpucfg_read = 32'h00000000;
      endcase
    end
  endfunction

  // ex2_result 是进入 EX2/MEM 寄存器的主结果：异常坏地址、计数器、
  // cpucfg、比较结果、地址计算和普通 ALU 结果在这里统一选择。
  wire ex2_slt_result=(((ex12ex2_op_slti|ex2_op_slt)&ex2_slt)|((ex2_op_sltu|ex12ex2_op_sltui)&ex2_sltu));
  wire [31:0] ex2_result=(ex12ex2_fetch_ex_adef ? ex12ex2_fetch_bad_pc:
                          (ex12ex2_op_rdcntvl   ? stable_counter_q[31:0]:
                           (ex12ex2_op_rdcntvh  ? stable_counter_q[63:32]:
                            (ex12ex2_op_cpucfg  ? cpucfg_read(ex12ex2_alu_a):
                             (ex2_gpr_wdata_from_compare ? {31'b0,ex2_slt_result}:
                              ex2_alu_result)))));
  assign ex2_forward_data=(ex12ex2_op_bl|ex2_op_jirl)?{ex12ex2_pc_plus_4_word,2'b00}:ex2_result;
  //当前 EX2 指令是 BL 或 JIRL 时，前递 PC+4，因为bl和jirl要求存pc+4；否则前递普通执行结果 ex2_result。

  // 分支在 EX2 级确认。若该条分支依赖尚未可用的 load/CSR 结果，后面的冒险逻辑会先停住，避免用旧操作数生成重定向。
  wire ex2_if_equal=(ex12ex2_alu_a==ex12ex2_rk_value);//比较两个操作数是否相等，用于 BEQ 和 BNE

  //当前指令是否属于直接跳转
  wire ex2_is_direct_branch = ex12ex2_op_b || ex12ex2_op_bl;

  //当前指令是否属于条件分支
  wire ex2_is_cond_branch = ex12ex2_op_beq || ex12ex2_op_bne || ex12ex2_op_blt ||
       ex12ex2_op_bge || ex12ex2_op_bltu || ex12ex2_op_bgeu;

  //当前指令是否可能改变控制流: 条件分支 || 直接跳转 || JIRL
  wire ex2_is_control = ex2_is_cond_branch || ex2_is_direct_branch || ex2_op_jirl;

  //当前指令实际是否跳转
  wire ex2_actual_taken=(ex2_is_direct_branch||(ex12ex2_op_beq&&ex2_if_equal)||(ex12ex2_op_bne&&!ex2_if_equal)||
                         (ex12ex2_op_blt&&ex2_slt)||(ex12ex2_op_bltu&&ex2_sltu)||(ex12ex2_op_bge&&!ex2_slt)||(ex12ex2_op_bgeu&&!ex2_sltu))||ex2_op_jirl;


  // jirl 目标使用 ALU 的独立加法输出，其余从ex1传过来
  wire [31:0] ex2_taken_target = ex2_op_jirl ?ex2_addr_result : {ex12ex2_branch_target_word,2'b00};//跳转目标
  wire [31:0] ex2_fallthrough_pc = {ex12ex2_pc_plus_4_word,2'b00};
  wire [31:0] ex2_actual_next_pc = ex2_actual_taken ? ex2_taken_target : ex2_fallthrough_pc;

  // 预测是否正确
  wire ex2_mispredict = ex12ex2_valid && !ex2_has_exception_in &&
       (ex12ex2_pred_next_pc != ex2_actual_next_pc);


  wire ex2mem_mem_ctrl_in=ex12ex2_mem_ctrl;

  // 地址对齐异常在EX2级检查
  wire ex2_addr_misalign_w=(ex12ex2_width==2'd0)&&(ex2_addr_result[1:0]!=2'b00);
  wire ex2_addr_misalign_h=(ex12ex2_width==2'd1)&&(ex2_addr_result[0]!=1'b0);

  // EX2 当前有效指令需要进行访存地址对齐检查
  wire ex2_mem_access=ex12ex2_valid && (ex12ex2_op_load_class|
                                        (ex2_store_en&&(!ex12ex2_op_store_conditional||csr_llbit)));

  // ID 已经附着的异常（尤其是异步中断）优先于本指令的执行级检查。
  // 异常指令不会使用源操作数旁路；若仍拿无效操作数做对齐判断，可能把原本的 INT 错误覆盖成 ALE。
  assign ex2_ale=ex2_mem_access&&!ex2_has_exception_in&&
         (ex2_addr_misalign_w||ex2_addr_misalign_h);

  wire ex12ex2_has_exception=ex12ex2_valid && (ex2_has_exception_in|ex2_ale);
  wire [5:0] ex2_exc_ecode_to_mem=ex2_ale?ECODE_ALE:(ex12ex2_valid?ex12ex2_exc_ecode:6'b0);

  // 快速direct load通道
  // 在 EX 中提前进行da/dmw的地址翻译
  wire [2:0] ex2_mem_vpn = ex2_addr_result[31:29];
  wire ex2_dmw0_plv_ok = (tc_csr_crmd_plv == 2'b00) ? tc_csr_dmw0[0] :
       ((tc_csr_crmd_plv == 2'b11) ? tc_csr_dmw0[3] : 1'b0);
  wire ex2_dmw1_plv_ok = (tc_csr_crmd_plv == 2'b00) ? tc_csr_dmw1[0] :
       ((tc_csr_crmd_plv == 2'b11) ? tc_csr_dmw1[3] : 1'b0);
  wire ex2_dmw0_hit = ex2_dmw0_plv_ok &&
       (ex2_mem_vpn == tc_csr_dmw0[31:29]);
  wire ex2_dmw1_hit = ex2_dmw1_plv_ok &&
       (ex2_mem_vpn == tc_csr_dmw1[31:29]);
  wire ex2_dmw_hit = ex2_dmw0_hit || ex2_dmw1_hit;
  wire [31:0] ex2_dmw_paddr = ex2_dmw0_hit ?
       {tc_csr_dmw0[27:25],ex2_addr_result[28:0]} :
       {tc_csr_dmw1[27:25],ex2_addr_result[28:0]};
  wire [1:0] ex2_dmw_mat = ex2_dmw0_hit ?
       tc_csr_dmw0[5:4] : tc_csr_dmw1[5:4];
  assign ex2_fast_direct_paddr = tc_csr_crmd_da ?
         ex2_addr_result : ex2_dmw_paddr;
  wire ex2_fast_direct_cached = tc_csr_crmd_da ?
       (tc_csr_crmd_datm == 2'b01) :
       (ex2_dmw_hit && (ex2_dmw_mat == 2'b01));

  // ex2_fast_direct_valid 对普通 load 和 store 都有效。对 store 来说，它主要用于：
  // EX2 预先计算物理地址,进入 MEM 后跳过 TLB，直接使用这个地址,让 store 尽快完成地址翻译并进入 WBQ/SB。
  // 但真正的“直接发起 D-cache 请求”只针对 load
  assign ex2_fast_direct_valid = ex12ex2_valid && !ex12ex2_has_exception &&
         !ex12ex2_serializing && !ex12ex2_op_load_linked && !ex12ex2_op_store_conditional && !ex12ex2_op_cacop &&
         (ex12ex2_op_load_class || ex2_store_en) && ex2_fast_direct_cached;

  // EX2执行结束后写入EX2/MEM级间寄存器
  EX_MEM_reg EX_MEM_reg(.clk(clk),.rst(rst),.En(ex2mem_en),.flush(ex2mem_flush),
                        .EX_valid(ex12ex2_valid),.EX_serializing(ex12ex2_serializing),.EX_refetch(ex12ex2_refetch),
                        .EX_PC_plus_4_word(ex12ex2_pc_plus_4_word),.EX_RD_data(ex2_store_data),
                        .ALU_result(ex2_result),.EX_RD(ex12ex2_gpr_waddr),
                        .EX_to_MEM_control(ex2mem_mem_ctrl_in),
                        .EX_gpr_write_en(ex2_gpr_write_en),
                        .EX_gpr_wdata_from_pc4(ex2_gpr_wdata_from_pc4),
                        .EX_OP_ldw(ex12ex2_op_load_class),.EX_OP_llw(ex12ex2_op_load_linked),.EX_OP_scw(ex12ex2_op_store_conditional),
                        .EX_OP_ertn(ex12ex2_op_ertn),.EX_has_exception(ex12ex2_has_exception),.EX_CSR_Op(ex12ex2_csr_op),.EX_csr_num(ex12ex2_csr_num),.EX_CSR_rj_data(ex12ex2_alu_a),
                        .EX_exc_code(ex12ex2_exc_code),.EX_exc_ecode(ex2_exc_ecode_to_mem),
                        .EX_bypass_Data_Opt(ex2_bypass_sel),
                        .EX_width(ex12ex2_width),.EX_sign(ex12ex2_sign),
                        // TLB/CACOP 控制信号随流水级传递。
                        .EX_OP_tlbsrch(ex12ex2_op_tlbsrch),.EX_OP_tlbrd(ex12ex2_op_tlbrd),.EX_OP_tlbwr(ex12ex2_op_tlbwr),
                        .EX_OP_tlbfill(ex12ex2_op_tlbfill),.EX_OP_invtlb(ex12ex2_op_invtlb),.EX_invtlb_op(ex12ex2_invtlb_op),.EX_OP_cacop(ex12ex2_op_cacop),
                        // RK_Op 供 invtlb 后级使用，必须取 EX2 级已旁路修正后的 B 源操作数。
                        .RK_Op(ex2_store_data),
                        .EX_fast_direct_valid(ex2_fast_direct_valid),
                        .EX_fast_direct_paddr(ex2_fast_direct_paddr),
                        .EX_fast_store_hash_match(ex2_fast_store_hash_match),
                        .EX_fast_direct_req_eligible(ex2_fast_direct_req_eligible),
                        .MEM_valid(ex2mem_valid),.MEM_serializing(ex2mem_serializing),.MEM_refetch(ex2mem_refetch),
                        .MEM_PC_plus_4_word(ex2mem_pc_plus_4_word),.MEM_RD_data(ex2mem_store_data),
                        .DM_addr(ex2mem_result),.MEM_RD(ex2mem_gpr_waddr),.MEM_RK_Op(ex2mem_rk_data),
                        .EX_MEM_control(ex2mem_mem_ctrl),
                        .MEM_gpr_write_en(ex2mem_gpr_write_en),
                        .MEM_gpr_wdata_from_pc4(ex2mem_gpr_wdata_from_pc4),
                        .MEM_OP_ldw(ex2mem_op_load_class),.MEM_OP_llw(ex2mem_op_load_linked),.MEM_OP_scw(ex2mem_op_store_conditional),
                        .MEM_OP_ertn(ex2mem_op_ertn),.MEM_has_exception(ex2mem_has_exception),.MEM_CSR_Op(ex2mem_csr_op),.MEM_csr_num(ex2mem_csr_num),.MEM_CSR_rj_data(ex2mem_csr_rj_data),
                        .MEM_exc_code(ex2mem_exc_code),.MEM_exc_ecode(ex2mem_exc_ecode),
                        .MEM_bypass_Data_Opt(ex2mem_bypass_sel),
                        .MEM_width(ex2mem_width),.MEM_sign(ex2mem_sign),
                        // 输出到 MEM 级的 TLB/CACOP 控制位。
                        .MEM_OP_tlbsrch(ex2mem_op_tlbsrch),.MEM_OP_tlbrd(ex2mem_op_tlbrd),.MEM_OP_tlbwr(ex2mem_op_tlbwr),
                        .MEM_OP_tlbfill(ex2mem_op_tlbfill),.MEM_OP_invtlb(ex2mem_op_invtlb),.MEM_invtlb_op(ex2mem_invtlb_op),.MEM_OP_cacop(ex2mem_op_cacop),
                        .MEM_fast_direct_valid(ex2mem_fast_direct_valid),
                        .MEM_fast_direct_paddr(ex2mem_fast_direct_paddr),
                        .MEM_fast_store_hash_match(ex2mem_fast_store_hash_match),
                        .MEM_fast_direct_req_eligible(ex2mem_fast_direct_req_eligible)
                       );


  // ==================== MEM：地址翻译、请求与完成条件 ====================

  // ==================== MEM 级与访存队列信号声明 ====================

  // MEM级访存类型
  wire        mem_store_en;
  wire        mem_op_load_class;
  wire        mem_op_store_class;


  wire        mem_req_inflight;//是否有 load 请求已经发出但还没返回
  reg         mem_issue_req_q;//MEM 内部是否有一个待发送（发出请求但还没有请求握手）的请求，发起 CACOP 时置 1，请求握手成功后清 0
  reg         mem_issue_is_cacop_q;//当前待发送请求是否是 CACOP 请求
  reg [31:0]  mem_issue_addr_q;// CACOP 要操作的地址
  reg [ 4:0]  mem_issue_cacop_code_q;// CACOP 操作码
  reg [ 3:0]  mem_issue_wstrb_next;//store 写字节使能掩码
  reg [31:0]  mem_issue_wdata_next;//store 写数据

  // CACOP 请求与响应：与 TLB 接口无关
  reg         mem_resp_valid;          // CACOP 请求已收到 data 响应
  reg  [31:2] mem_resp_pc_q;           // 响应所属的 CACOP PC
  wire        mem_req_fire;            // CACOP 请求地址握手成功

  // TLB S1 查询端口输入：以下寄存器直接连接到 u_tlb 的 s1 输入
  reg [18:0] mem_s1_vppn_q;            // 待查询虚拟页号 VPPN
  reg         mem_s1_va_bit12_q;       // 虚拟地址 bit12，用于选择大页低位
  reg [ 9:0] mem_s1_asid_q;            // 待查询地址空间标识 ASID

  // S1 查询控制与访问上下文：由 MEM 内部维护，不是 TLB 模块端口
  reg         mem_s1_valid_q;          // S1 阶段 TLB 查询数据有效
  reg         mem_s1_ready_q;          // S1 查询已准备好，可采样 TLB 返回结果
  reg         mem_s1_tlb_req_q;        // 当前操作是否需要实际 TLB 地址翻译
  reg [ 1:0] mem_s1_cur_plv_q;         // 发起访问时的当前特权级 PLV
  reg [31:0] mem_s1_vaddr_q;           // 待翻译的原始虚拟地址
  reg         mem_s1_is_store_q;       // 当前访存是否为 store

  // TLB S1 查询结果：锁存 u_tlb 的 s1_* 输出，供后续地址翻译和权限检查
  reg         mem_tlb_found_q;         // TLB 是否命中匹配项
  reg [ 4:0] mem_tlb_index_q;          // 命中的 TLB 表项索引
  reg [19:0] mem_tlb_ppn_q;            // 命中表项的物理页号 PPN
  reg [ 5:0] mem_tlb_ps_q;             // 命中表项的页大小编码 PS
  reg [ 1:0] mem_tlb_plv_q;            // 命中表项允许访问的 PLV 上限
  reg [ 1:0] mem_tlb_xlate_mat_q;      // 命中表项的存储器属性 MAT
  reg         mem_tlb_d_q;             // 命中表项 dirty 位
  reg         mem_tlb_v_q;             // 命中表项 valid 位

  // TLB 查询状态与访问上下文：由 MEM 锁存，不是 TLB 模块端口
  reg         mem_tlb_checked_q;       // TLB 查询结果已锁存
  reg         mem_tlb_req_q;           // 已锁存 结果是否来自实际 TLB 翻译
  reg [ 1:0] mem_tlb_cur_plv_q;        // 已锁存 请求的当前特权级 PLV
  reg [31:0] mem_tlb_vaddr_q;           // 已锁存 待翻译虚拟地址
  reg         mem_tlb_is_store_q;      // 已锁存 访存是否为 store

  // 地址翻译结果：由 MEM 根据 TLB 结果和直接地址映射生成
  reg         mem_xlate_exception_tlb_q; // 地址翻译产生 TLB 异常
  reg [ 5:0] mem_xlate_exc_ecode_q;    // 地址翻译异常的 ECode
  reg [31:0] mem_xlate_paddr_q;         // 地址翻译得到的物理地址
  reg         mem_xlate_cached_q;      // 地址翻译结果是否为 cached 属性
  reg [31:0] mem_xlate_vaddr_q;        // 与翻译结果对应的虚拟地址

  // TLBSRCH 结果：锁存查询命中状态和表项索引，提交时写回 CSR
  reg         mem_tlbsrch_found_q;     // TLBSRCH 是否找到匹配表项
  reg [ 4:0] mem_tlbsrch_index_q;      // TLBSRCH 找到的表项索引


  // 两项有序 load queue。count 表示已入队但尚未收到 data_sram 响应的项数；
  // issued_count 表示其中已经完成地址握手、已发出请求但尚未收到响应的项数。
  // 两者之差即已入队但仍待发射的请求数
  localparam integer LQ_DEPTH = 2;       // Load Queue 的容量
  reg [31:0] lq_addr   [0:LQ_DEPTH-1];  // 各项 load 的物理地址
  reg [ 1:0] lq_size   [0:LQ_DEPTH-1];  // 各项 load 的访问宽度编码
  reg        lq_cached [0:LQ_DEPTH-1];  // 各项地址是否可缓存
  reg [ 1:0] lq_wbq_slot[0:LQ_DEPTH-1]; // 各项对应的 WBQ 槽位
  reg        lq_discard[0:LQ_DEPTH-1];  // 冲刷后丢弃该项的响应，不回写 WBQ
  reg        lq_head;                   // 队首索引，响应按此顺序返回
  reg        lq_tail;                   // 队尾索引，新项写入此位置
  reg [1:0]  lq_count;                  // 队列中尚未收到响应的项数
  reg [1:0]  lq_issued_count;           // 已完成地址握手、等待响应的项数
  wire       lq_response_fire;          // data_sram 响应与队首项完成握手
  wire       lq_enqueue;                // load 分配 WBQ 时同时入队 LQ
  wire       lq_issue_fire;             // LQ 项完成发射请求的 data_sram 地址握手
  wire       wbq_store_enq;             // store 项进入 WBQ 的事件
  wire       mem_load_has_older_uncached_store; // SB/WBQ 中仍有更老的未缓存 store
  wire       lq_contains_uncached;      // 队首 LQ 项为未缓存 load


  // -------------------- MEM/WBQ、Load Queue 与 Store Buffer 信号声明 --------------------

  // WBQ 队首送往 WB 级的提交负载
  wire        wbq_head_serializing;
  wire        wbq_head_refetch;
  wire [31:0] wbq_head_csr_wdata;
  wire        wbq_head_op_load_linked;
  wire        wbq_head_op_store_class;
  wire        wbq_head_op_ertn;
  wire        wbq_head_op_tlbrd, wbq_head_op_invtlb, wbq_head_op_cacop;
  wire [4:0]  wbq_head_invtlb_op;
  wire [1:0]  wbq_head_csr_op;
  wire [13:0] wbq_head_csr_num;
  wire [31:0] wbq_head_csr_rj_data;
  wire [31:0] wbq_head_rk_data;


  // 四项按序完成/退休队列。load 地址握手后即可离开 MEM，但其队列项在
  // data_ok 到达前保持 not-ready；年轻无关指令可以进入后续项，WB 始终
  // 只从队首退休，从而保持精确异常、trace 和差分提交顺序。
  // meta 保存退休控制和架构结果；mon 保存指令、计数器及访存 trace。把 monitor
  // 与控制分开可防止宽差分测试字段进入 ready/flush 等时序关键路径。
  localparam integer WBQ_META_W = 251;
  localparam integer WBQ_MON_W = 203;
  reg [WBQ_META_W-1:0] wbq_meta [0:WBQ_DEPTH-1];//metadata，元数据
  // wbq_meta 保存指令在 WB（写回/退休）阶段所需的控制信息和架构结果，例如：
  // 是否写 GPR、写哪个寄存器; ALU/访存结果; load/store 类型; CSR、异常、ERTN、TLB 操作等
  // 它会在下面被解包成 wbq_head_* 信号，供退休逻辑使用

  reg [WBQ_MON_W-1:0]  wbq_mon  [0:WBQ_DEPTH-1];

  reg [31:0] wbq_load_data [0:WBQ_DEPTH-1];         // WBQ 中 load 的最终返回值
  reg [31:0] wbq_load_forward_data[0:WBQ_DEPTH-1];  // 经 store buffer 或其他生产者旁路后的 load 数据
  reg [3:0]  wbq_load_forward_mask[0:WBQ_DEPTH-1];  // load 旁路数据的有效字节掩码
  reg [1:0]  wbq_load_width[0:WBQ_DEPTH-1];         // load 访问宽度：字节、半字或字
  reg        wbq_load_sign [0:WBQ_DEPTH-1];         // load 是否按有符号数进行扩展
  reg [1:0]  wbq_load_addr_low[0:WBQ_DEPTH-1];      // load 地址低两位，用于数据对齐和提取
  reg        wbq_valid [0:WBQ_DEPTH-1];             // WBQ slot 当前是否保存有效的未退休指令
  reg        wbq_ready [0:WBQ_DEPTH-1];             // WBQ slot 的结果是否已经准备好退休

  reg        wbq_gpr_pending [0:WBQ_DEPTH-1];   // 该 WBQ 项是否包含一个尚未退休的 GPR 写回结果
  reg [4:0]  wbq_gpr_rd [0:WBQ_DEPTH-1];        // 该 slot 写回的 GPR 编号
  reg        wbq_gpr_is_latest[0:WBQ_DEPTH-1];    // 该 WBQ 项的GPR写回结果是否为最新的
  reg        wbq_store_pending[0:WBQ_DEPTH-1];    // 该 slot 是否包含尚未提交的store(实际上只要是在wbq中的store就是尚未提交的 store)
  reg [31:0] wbq_store_paddr [0:WBQ_DEPTH-1];     // store 的物理地址
  reg [31:0] wbq_store_wdata [0:WBQ_DEPTH-1];     // store 待写入的数据
  reg [3:0]  wbq_store_wstrb[0:WBQ_DEPTH-1];      // store 的有效字节写使能
  reg [1:0]  wbq_store_size [0:WBQ_DEPTH-1];      // store 访问大小
  reg        wbq_store_cached[0:WBQ_DEPTH-1];     // store 是否命中可缓存区域

  reg [31:0] wbq_mem_paddr[0:WBQ_DEPTH-1];  //wbq中用于load/store的物理地址
  reg [2:0]  wbq_store_count;               // WBQ 中尚未退休的 store 数量
  reg [2:0]  wbq_uncached_store_count;      // WBQ 中尚未退休的 uncached store 数量
  (* max_fanout = 32 *) reg [1:0] wbq_head; // WBQ 当前队首 slot
  // 希望 wbq_head 产生的信号扇出不要超过 32
  reg [1:0] wbq_tail; // WBQ 下一个可写入的 slot
  reg [2:0] wbq_count; // WBQ 当前占用的 slot 数量
  wire      wbq_pop; // 当前周期是否退休 WBQ 队首
  wire      wbq_enq; // 当前周期是否向 WBQ 写入新指令
  wire      wbq_flush; // 是否因异常、分支或其他控制事件清空 WBQ
  wire      wbq_head_valid = (wbq_count != 0) && wbq_valid[wbq_head]; // 队首 slot 有有效指令
  wire      wbq_head_ready = wbq_head_valid && wbq_ready[wbq_head]; // 队首结果已ready，可以执行退休
  wire      wbq_has_space; // WBQ 是否仍有可用 slot

  // 四项已提交 store buffer。只有 WB 队首无异常退休时才能入队，物理 cache
  // 写可在退休后完成。load 不必等待整个 buffer 排空：较老 cached store
  // 通过按字节旁路处理；较老 uncached store 或正在进行的 SB 请求则触发顺序等待
  localparam integer SB_DEPTH = 4;
  reg [31:0] sb_addr [0:SB_DEPTH-1]; // store buffer 每项的物理地址
  reg [31:0] sb_wdata[0:SB_DEPTH-1]; // store buffer 每项的写数据
  reg [3:0]  sb_wstrb[0:SB_DEPTH-1]; // store buffer 每项的有效字节写使能
  reg [1:0]  sb_size [0:SB_DEPTH-1]; // store buffer 每项的访问大小
  reg        sb_cached[0:SB_DEPTH-1]; // store buffer 每项是否位于可缓存区域
  reg        sb_valid [0:SB_DEPTH-1]; // store buffer slot 是否有效
  reg [1:0] sb_head; // store buffer 当前待发送的队首 slot
  reg [1:0] sb_tail; // store buffer 下一个入队位置
  reg [2:0] sb_count; // store buffer 当前占用的 slot 数量
  reg [2:0] sb_uncached_store_count; // store buffer 中尚未完成的 uncached store 数量
  reg       sb_req_inflight; // 队首 store 请求已经发出，等待响应
  wire      sb_full = (sb_count == SB_DEPTH); // store buffer 已满，不能继续入队
  wire      sb_empty = (sb_count == 0); // store buffer 为空，没有待处理 store
  wire      sb_enqueue; // 当前周期是否将已退休的 store 写入 store buffer
  wire      sb_req; // 当前周期是否向存储系统发起 store 请求
  wire      sb_req_fire; // store 请求握手成功
  wire      sb_resp_fire; // store 响应握手成功，队首 slot 可以释放

  reg [31:0] mon_mem_inst;
  reg [63:0] mon_mem_timer;
  reg         mon_mem_ldb;
  reg         mon_mem_ldh;
  reg         mon_mem_ldbu;
  reg         mon_mem_ldhu;
  reg         mon_mem_stb;
  reg         mon_mem_sth;
  wire        mon_wb_valid;
  wire [31:0] mon_wb_inst;
  wire [63:0] mon_wb_timer;
  wire        mon_wb_ldb;
  wire        mon_wb_ldh;
  wire        mon_wb_ldbu;
  wire        mon_wb_ldhu;
  wire        mon_wb_stb;
  wire        mon_wb_sth;
  wire [31:0] mon_wb_mem_paddr;
  wire [31:0] mon_wb_mem_vaddr;
  wire [31:0] mon_wb_store_data;
  wire [ 4:0] mon_wb_tlbfill_index;

  assign mem_result=ex2mem_result;
  assign mem_is_csr=(ex2mem_csr_op!=0);
  assign mem_sc_attempt = ex2mem_op_store_conditional && csr_llbit;// 仅当当前指令为 SC 且 LLBit 有效时，才尝试执行条件存储
  assign mem_store_en=ex2mem_mem_ctrl;// 继承 EX2/MEM 阶段的存储器控制信号
  // 访存类型必须从 EX2/MEM 流水寄存器显式传入 MEM。上一版对应
  // MEM_OP_ld_class/MEM_OP_st_class；重命名时若漏掉这两条连接，所有
  // load/store 都会被当成普通 ALU 指令，MEM 地址翻译和 LQ/SB 永不启动。
  assign mem_op_load_class = ex2mem_op_load_class;
  assign mem_op_store_class = mem_store_en &&
         !(ex2mem_op_store_conditional && !mem_sc_success);

  // -------------------- MEM 级地址翻译 --------------------
  // MEM 翻译与取指 FT 使用相同 CSR/TLB 资源，但属于后端，不混入 FQ/FT/FI 信号组。
  wire [2:0] mem_vpn = mem_result[31:29];
  wire mem_dmw0_vpn_match = mem_vpn == tc_csr_dmw0[31:29];
  wire mem_dmw1_vpn_match = mem_vpn == tc_csr_dmw1[31:29];
  wire mem_dmw0_plv_check = tc_csr_crmd_plv == 2'b00 ? tc_csr_dmw0[0] :
       tc_csr_crmd_plv == 2'b11 ? tc_csr_dmw0[3] : 1'b0;
  wire mem_dmw1_plv_check = tc_csr_crmd_plv == 2'b00 ? tc_csr_dmw1[0] :
       tc_csr_crmd_plv == 2'b11 ? tc_csr_dmw1[3] : 1'b0;
  wire mem_dmw0_hit = mem_dmw0_plv_check && mem_dmw0_vpn_match;
  wire mem_dmw1_hit = mem_dmw1_plv_check && mem_dmw1_vpn_match;
  wire mem_dmw_hit  = mem_dmw0_hit || mem_dmw1_hit;
  wire [31:0] mem_dmw_paddr = mem_dmw0_hit ?
       {tc_csr_dmw0[27:25],mem_result[28:0]} :
       {tc_csr_dmw1[27:25],mem_result[28:0]};
  wire [1:0] mem_dmw_mat = mem_dmw0_hit ? tc_csr_dmw0[5:4] : tc_csr_dmw1[5:4];
  wire mem_op_cacop_hit_va = ex2mem_op_cacop && (ex2mem_gpr_waddr[4:3] == 2'b10);
  // SC 在没有 LLBit 时直接失败；有 reservation 才进行地址翻译。实际
  // store 副作用则还要等物理 reservation 地址和 cache 属性检查通过。

  // 普通 store 或 LLBit 有效的 SC
  wire mem_store_xlate_op = mem_store_en &&
       (!ex2mem_op_store_conditional || mem_sc_attempt);

  // load、可执行的 store 以及命中虚拟地址的 CACOP 需要进行地址访问
  wire mem_xlate_access_op = mem_op_load_class | mem_store_xlate_op |
       mem_op_cacop_hit_va;

  // CRMD.DA 置位时，访存地址直接作为物理地址使用。
  wire mem_da_path = mem_xlate_access_op && !ex2mem_has_exception && tc_csr_crmd_da;

  // 未开启直接地址模式且命中 DMW 窗口时，按 DMW 映射生成物理地址。
  wire mem_dmw_path = mem_xlate_access_op && !ex2mem_has_exception &&
       !tc_csr_crmd_da && mem_dmw_hit;

  // 分页开启、未命中 DMW 且无异常时，通过 TLB 完成虚拟地址翻译。
  wire mem_tlb_path = mem_xlate_access_op && !ex2mem_has_exception &&
       tc_csr_crmd_pg && !tc_csr_crmd_da && !mem_dmw_hit;

  // TLBSRCH 始终发起 TLB 查询，但已有异常时不再查询
  wire mem_tlbsrch_path = ex2mem_op_tlbsrch && !ex2mem_has_exception;

  // 汇总无需 TLB 查询的路径：直接地址、DMW、非虚拟地址 CACOP，
  // 以及未开启分页且未命中 DMW 时的直接映射。
  wire mem_direct_path = mem_da_path || mem_dmw_path ||
       (ex2mem_op_cacop && !mem_op_cacop_hit_va && !ex2mem_has_exception) ||
       (mem_xlate_access_op && !ex2mem_has_exception &&
        !tc_csr_crmd_pg && !tc_csr_crmd_da && !mem_dmw_hit);

  // 按访存宽度和地址低位生成写掩码；byte/half 写只打开目标字节 lane。
  always@*
  begin
    if(!mem_store_en)
      mem_issue_wstrb_next=4'b0000;
    else if(ex2mem_width==2'd0)
      mem_issue_wstrb_next=4'b1111;
    else if(ex2mem_width==2'd1)
      mem_issue_wstrb_next=ex2mem_result[1]?4'b1100:4'b0011;
    else
    begin
      case(ex2mem_result[1:0])
        2'd0:
          mem_issue_wstrb_next=4'b0001;
        2'd1:
          mem_issue_wstrb_next=4'b0010;
        2'd2:
          mem_issue_wstrb_next=4'b0100;
        2'd3:
          mem_issue_wstrb_next=4'b1000;
      endcase
    end
  end

  // 要 store 的数据已在 EX1 完成 EX2/MEM/WBQ 旁路与晚结果等待，随流水寄存器传到 MEM 后直接使用
  wire [31:0] mem_store_data = ex2mem_store_data;

  // store 数据按 lane 复制，真正写哪些字节由 wstrb 控制。
  always@*
  begin
    if(ex2mem_width==2'd0)
      mem_issue_wdata_next=mem_store_data;
    else if(ex2mem_width==2'd1)
      mem_issue_wdata_next={2{mem_store_data[15:0]}};
    else
      mem_issue_wdata_next={4{mem_store_data[7:0]}};
  end



  // MEM 级地址翻译：DA/DMW 等不需要 TLB 的访问直接生成最终翻译结果；所以不考虑在*_xlate_*内。
  // 需要 TLB 的访存以及 tlbsrch 再走 s1 查询、锁存查询结果、生成结果的路径。
  wire mem_xlate_ps_eq_21 = mem_tlb_ps_q == 6'd21;//判断命中的 TLB 项是否为 PS=21 的大页
  wire [31:0] mem_xlate_tlb_paddr = mem_xlate_ps_eq_21 ?//根据 TLB 的 PPN 和页大小，生成物理地址
       {mem_tlb_ppn_q[19:9], mem_tlb_vaddr_q[20:0]} :
       {mem_tlb_ppn_q, mem_tlb_vaddr_q[11:0]};
  wire [31:0] mem_xlate_paddr_next =//最终准备锁存的物理地址。只有“实际 TLB 请求且命中”时使用翻译后的地址，否则暂时使用原虚拟地址
       (mem_tlb_req_q && mem_tlb_found_q) ? mem_xlate_tlb_paddr : mem_tlb_vaddr_q;
  wire [1:0] mem_xlate_mat_next = mem_tlb_xlate_mat_q;
  wire mem_xlate_tlb_found = mem_tlb_req_q && mem_tlb_found_q;
  wire mem_xlate_ex_tlbr = mem_tlb_req_q && !mem_tlb_found_q;
  wire mem_xlate_ex_pi   = mem_xlate_tlb_found && !mem_tlb_v_q;//命中且 V=0：页无效异常
  wire mem_xlate_ex_ppi  = mem_xlate_tlb_found && mem_tlb_v_q && (mem_tlb_cur_plv_q > mem_tlb_plv_q);
  wire mem_xlate_ex_pme  = mem_xlate_tlb_found && mem_tlb_v_q && (mem_tlb_cur_plv_q <= mem_tlb_plv_q) && mem_tlb_is_store_q && !mem_tlb_d_q;
  // tlb相关的异常汇总和异常编码
  wire mem_xlate_exception_tlb_next = mem_xlate_ex_tlbr | mem_xlate_ex_pi | mem_xlate_ex_ppi | mem_xlate_ex_pme;
  wire [5:0] mem_xlate_exc_ecode_next = mem_xlate_ex_tlbr ? ECODE_TLBR :
       (mem_xlate_ex_pi  ? (mem_tlb_is_store_q ? ECODE_PIS : ECODE_PIL) :
        (mem_xlate_ex_ppi ? ECODE_PPI  :
         (mem_xlate_ex_pme ? ECODE_PME  : ECODE_ALE)));

  // 最终异常结果
  wire mem_exception_tlb  = mem_issue_checked_q && mem_xlate_exception_tlb_q;
  assign mem_has_exception_final = ex2mem_has_exception | mem_exception_tlb;
  wire [5:0] mem_exc_ecode_final = mem_exception_tlb ? mem_xlate_exc_ecode_q : ex2mem_exc_ecode;


  // TLB S1 查询输入
  wire [18:0] mem_s1_vppn_next=ex2mem_op_tlbsrch?csr_tlbehi[31:13]:mem_result[31:13];//TLB 查询使用的虚拟页号。普通访存取 mem_result[31:13]；TLBSRCH 取 TLBEHI[31:13]
  wire mem_s1_va_bit12_next=ex2mem_op_tlbsrch?1'b0:mem_result[12];//4 KB 双页中选择偶页还是奇页的地址位。普通访存使用 mem_result[12]；TLBSRCH 固定为 0。
  wire [9:0] mem_s1_asid_next=csr_asid;//当前地址空间标识，来自 CSR.ASID，用于 TLB 的 ASID 匹配

  // 不经过 TLB 时的直接地址路径
  // 直接路径的物理地址和mat
  wire [31:0] mem_direct_paddr_next=tc_csr_crmd_da ? mem_result :
       (mem_dmw_hit ? mem_dmw_paddr : mem_result);
  wire [1:0] mem_direct_mat_next=tc_csr_crmd_da ? tc_csr_crmd_datm :
       (mem_dmw_hit ? mem_dmw_mat : 2'b00);


  // 普通 cached DA/DMW load/store 的地址属性在当前拍已经确定，不必先锁存到 mem_xlate_*_q 再白等一拍。
  // TLB、uncached、LL/SC、CACOP 和串行指令仍走原状态机。

  // mem_fast_direct_xlate 表示当前 MEM 状态下，这条指令“现在可以安全地使用”快速翻译结果
  wire mem_fast_direct_xlate = ex2mem_fast_direct_valid &&//ex2mem_fast_direct_valid：这条指令“具备”
       //快速 direct 地址路径的资格,但没有判断 MEM 内部状态是否空闲.
       //后续的用于防止：当 MEM 仍在处理前一个查询、请求或响应时，mem_xlate_ready 也会被错误地置 1
       !mem_s1_valid_q && !mem_tlb_checked_q && !mem_issue_checked_q &&
       !mem_issue_req_q && !mem_resp_valid &&
       !ex2mem_serializing;
  wire mem_xlate_ready = mem_issue_checked_q || mem_fast_direct_xlate;
  wire [31:0] mem_xlate_paddr_eff = mem_fast_direct_xlate ?
       ex2mem_fast_direct_paddr : mem_xlate_paddr_q;
  wire mem_xlate_cached_eff = mem_fast_direct_xlate ?
       1'b1 : mem_xlate_cached_q;// 这里1'b1是因为mem_fast_direct_xlate 的上游条件已经保证了该访问是 cached
  wire [31:0] mem_xlate_vaddr_eff = mem_fast_direct_xlate ?
       mem_result : mem_xlate_vaddr_q;

  // 对当前已完成翻译的 load，按“已退休 SB -> 未退休 WBQ”的程序年龄
  // 顺序扫描全部老 store。后扫描的年轻 store 逐 byte 覆盖更老数据，
  // 因而每个 byte 最终都来自最近的老 store。第一版只在 load 所需
  // byte 全覆盖时直接转发；部分覆盖保存 mask/data，并在 cache word
  // 返回时逐 byte 合并。
  reg [31:0] mem_load_forward_data;        // 组合扫描得到的老 store 转发数据，按字节 lane 对齐
  reg [3:0]  mem_load_forward_mask;        // 组合扫描得到的有效转发字节掩码，每 bit 对应一个 byte lane
  reg [3:0]  mem_load_need_mask;           // 当前 load 实际需要读取的字节掩码，由访问宽度和地址低位决定
  reg         mem_load_fwd_valid_q;        // 当前 MEM 阶段的 load 是否已经在时钟沿锁存了老 store 的转发结果(不一定full)
  reg [31:0]  mem_load_forward_data_q;     // 锁存
  reg [3:0]   mem_load_forward_mask_q;     // 锁存
  reg         mem_load_forward_full_q;     // 锁存结果已覆盖当前 load 所需的全部字节，可直接完成 load
  reg         mem_load_partial_conflict_q; // 锁存结果仅覆盖部分字节，需要与 cache 返回数据逐字节合并

  integer load_fwd_age;
  integer load_fwd_lane;
  integer load_fwd_index;

  wire lq_has_unissued = (lq_count > lq_issued_count);
  wire lq_issue_index = lq_head + lq_issued_count[0];
  wire lq_has_space = (lq_count < LQ_DEPTH) || lq_response_fire;
  assign mem_req_inflight = (lq_issued_count != 0);


  //=========================================================================
  // 普通load，经过mem流水级寄存器，在该级开始，完成与store冲突的 地址转换，扫描对象是SB、WBQ
  //=========================================================================

  // 普通load: 在mem流水级寄存器，组合路径完成store forwarding扫描，以及地址翻译，完成后的那一拍送入lq和wbq，再一拍可能发起访问（如果不是完全覆盖）
  // 快速load: 再ex2级完成store forwarding扫描，以及地址翻译,一拍发起访问（如果不是完全覆盖），同步送入lq和wbq
  // 两者的store forwarding扫描信息，在后续阻塞时，被存放到寄存器中

  always @*
  begin
    case (ex2mem_width)
      2'd0:
        mem_load_need_mask = 4'b1111;
      2'd1:
        mem_load_need_mask =
        mem_xlate_paddr_eff[1] ? 4'b1100 : 4'b0011;
      default:
      begin
        case (mem_xlate_paddr_eff[1:0])
          2'd0:
            mem_load_need_mask = 4'b0001;
          2'd1:
            mem_load_need_mask = 4'b0010;
          2'd2:
            mem_load_need_mask = 4'b0100;
          default:
            mem_load_need_mask = 4'b1000;
        endcase
      end
    endcase

    mem_load_forward_data = 32'b0;
    mem_load_forward_mask = 4'b0;

    // SB 中的项均比 WBQ 中的 store 更老；环形队列从 head 向 tail扫描，保证同一 byte 的较年轻值覆盖较老值。

    // 遍历 SB 的全部可能槽位；只有 age 小于 sb_count 的项才是有效队列成员。
    for (load_fwd_age = 0; load_fwd_age < SB_DEPTH;load_fwd_age = load_fwd_age + 1)
    begin
      // 根据队头和相对年龄计算环形队列中的实际槽位，SB_DEPTH 为 2 的幂次(这里是8)时按位与可实现等价的取模回绕。
      load_fwd_index = (sb_head + load_fwd_age) & (SB_DEPTH-1);
      // 仅对 cached load、有效 SB 项、cached store，且字地址相同的条目进行旁路。
      // (如果是 uncached 会等其他走完)
      if (mem_xlate_cached_eff && (load_fwd_age < sb_count) &&
          sb_cached[load_fwd_index] &&
          (sb_addr[load_fwd_index][31:2] ==mem_xlate_paddr_eff[31:2]))
      begin
        // 按四个 byte lane 检查 store 写掩码，支持整字和部分字节写入。
        for (load_fwd_lane = 0; load_fwd_lane < 4;load_fwd_lane = load_fwd_lane + 1)
        begin
          // 被 store 实际写入的字节直接转发给 load，并标记该 lane 已覆盖。
          if (sb_wstrb[load_fwd_index][load_fwd_lane])
          begin
            mem_load_forward_data[load_fwd_lane*8 +: 8] =sb_wdata[load_fwd_index][load_fwd_lane*8 +: 8];
            mem_load_forward_mask[load_fwd_lane] = 1'b1;
          end
        end
      end
    end

    // WBQ 中保存的是已进入写回队列、但可能尚未真正退休的 store；
    // 按队头到队尾的程序年龄顺序扫描，较新的条目会覆盖较旧字节。
    for (load_fwd_age = 0; load_fwd_age < WBQ_DEPTH;load_fwd_age = load_fwd_age + 1)
    begin
      // 将相对年龄转换为 WBQ 环形队列中的实际槽位，队尾后自动回绕。
      load_fwd_index = (wbq_head + load_fwd_age) & (WBQ_DEPTH-1);
      // 仅匹配有效的 pending store：必须是 cached store，且与当前 load
      // 位于同一个物理字地址，避免将其他地址的数据错误地旁路进来。
      if (mem_xlate_cached_eff && (load_fwd_age < wbq_count) &&
          wbq_valid[load_fwd_index] &&wbq_store_pending[load_fwd_index] &&
          wbq_store_cached[load_fwd_index] &&
          (wbq_store_paddr[load_fwd_index][31:2] ==mem_xlate_paddr_eff[31:2]))
      begin
        // 逐 byte 检查 store 的写掩码；只转发实际写入的 lane，
        // 未写入的 lane 保留给更老的 store 或 cache 返回数据补齐。
        for (load_fwd_lane = 0; load_fwd_lane < 4;load_fwd_lane = load_fwd_lane + 1)
        begin
          // 将命中的字节复制到转发数据，并置位对应 mask 表示该字节已覆盖。
          if (wbq_store_wstrb[load_fwd_index][load_fwd_lane])
          begin
            mem_load_forward_data[load_fwd_lane*8 +: 8] = wbq_store_wdata[load_fwd_index][load_fwd_lane*8 +: 8];
            mem_load_forward_mask[load_fwd_lane] = 1'b1;
          end
        end
      end
    end
  end


  //=======================================================================================
  // 快速 direct cached load 路径，在ex2级开始，完成与store冲突的 地址转换，扫描对象是：SB、WBQ、以及当前 MEM store,再存到mem级间寄存器
  //=======================================================================================

  // ===简要判断是否冲突,作为预筛选====
  // 用物理地址 [7:2] 做六位 signature 预筛选，降低完整地址 CAM 的时序开销。
  // signature 不同可确定没有同字 store；相同只表示可能地址冲突，仍需后续比较。
  always @*
  begin
    ex2_fast_store_hash_match = 1'b0;// 该信号表示“可能冲突”
    if (ex2_fast_direct_valid && ex12ex2_op_load_class)
    begin

      for (ex2_store_hash_slot = 0; ex2_store_hash_slot < SB_DEPTH;ex2_store_hash_slot = ex2_store_hash_slot + 1)
      begin
        // SB 中按槽位检查有效的 cached store。
        if (sb_valid[ex2_store_hash_slot] && sb_cached[ex2_store_hash_slot] &&
            (sb_addr[ex2_store_hash_slot][7:2] ==ex2_fast_direct_paddr[7:2]))
          ex2_fast_store_hash_match = 1'b1;
      end

      for (ex2_store_hash_slot = 0; ex2_store_hash_slot < WBQ_DEPTH;ex2_store_hash_slot = ex2_store_hash_slot + 1)
      begin
        // WBQ 中只检查仍 pending 且 cached 的 store。
        if (wbq_valid[ex2_store_hash_slot] &&
            wbq_store_pending[ex2_store_hash_slot] &&
            wbq_store_cached[ex2_store_hash_slot] &&
            (wbq_store_paddr[ex2_store_hash_slot][7:2] ==ex2_fast_direct_paddr[7:2]))
          ex2_fast_store_hash_match = 1'b1;
      end

      // 当前 MEM 阶段如果还有store的话(还没有进入 WBQ，所以前面的 SB/WBQ 扫描暂时看不到它)，也可能造成冲突
      if (ex2mem_valid && mem_op_store_class && mem_xlate_ready &&
      // MEM 中确实有有效指令 && 该指令是 store && store 的物理地址已经准备好
          mem_xlate_cached_eff && !mem_has_exception_final &&
      //&& 是 cached store && store 没有异常
          (mem_xlate_paddr_eff[7:2] == ex2_fast_direct_paddr[7:2]))
        // 当前 MEM store 可能在同一拍进入 WBQ，也必须纳入预筛选。
        ex2_fast_store_hash_match = 1'b1;
    end
  end

  // ====direct load发射前提===

  // 判断EX2 的 cached load 能否绕过普通 LQ 路径，直接发起 D-cache 请求
  // wbq_enq/pop(本拍 WBQ 入队/退休)后的预计项数，用于检查直发后是否仍有空槽
  wire [3:0] wbq_count_after_edge = {1'b0,wbq_count} +
       (wbq_enq ? 4'd1 : 4'd0) - (wbq_pop ? 4'd1 : 4'd0);
  // lq_enqueue/response_fire(本拍 LQ 分配/响应回收)后的预计项数。
  wire [2:0] lq_count_after_edge = {1'b0,lq_count} +
       (lq_enqueue ? 3'd1 : 3'd0) -
       (lq_response_fire ? 3'd1 : 3'd0);
  // lq_issue_fire/response_fire操作后的预计已发射项数。
  wire [2:0] lq_issued_after_edge = {1'b0,lq_issued_count} +
       (lq_issue_fire ? 3'd1 : 3'd0) -
       (lq_response_fire ? 3'd1 : 3'd0);

  // 当前 MEM 是否会在本拍新增 uncached store/load；有则不能走 cached 直发路径。
  wire mem_enqueues_uncached_store = wbq_store_enq && !mem_xlate_cached_eff;
  wire mem_enqueues_uncached_load = lq_enqueue && !mem_xlate_cached_eff;

  // lq_issued_after_edge == lq_count_after_edge 表示已有 LQ 项均已发射，新 load 不会越过尚未发出的旧请求。
  // 条件依次保证：快速 load、无可能冲突的 store、无 uncached 顺序屏障、WBQ/LQ 不满，且 LQ 中没有尚未发射的旧请求。
  assign ex2_fast_direct_req_eligible = ex2_fast_direct_valid && ex12ex2_op_load_class &&
         !ex2_fast_store_hash_match &&
         !mem_load_has_older_uncached_store && !lq_contains_uncached &&
         !mem_enqueues_uncached_store && !mem_enqueues_uncached_load &&
         (wbq_count_after_edge < WBQ_DEPTH) &&
         (lq_count_after_edge < LQ_DEPTH) &&
         (lq_issued_after_edge == lq_count_after_edge);

  
  // ===完整的direct load处理===

  // 用完整物理字地址 [31:2] 计算逐字节转发快照，并将 data/mask 锁存到 MEM。
  // 扫描顺序为 SB -> WBQ -> 当前 MEM store；后扫描的年轻 store 覆盖同一 byte 的旧值。
  always @*
  begin
    // 默认没有可转发字节
    ex2_fast_forward_data = 32'b0;
    ex2_fast_forward_mask = 4'b0;
    // 只有快速地址 load 才需要生成转发快照
    if (ex2_fast_direct_valid && ex12ex2_op_load_class)
    begin
      for (ex2_store_fwd_age = 0; ex2_store_fwd_age < SB_DEPTH;ex2_store_fwd_age = ex2_store_fwd_age + 1)
      begin
        // 从 SB head 按程序年龄扫描最老的 store，并处理环形索引回绕。
        ex2_store_fwd_index = (sb_head + ex2_store_fwd_age) & (SB_DEPTH-1);
        // 只匹配有效 cached 项和完整物理字地址。
        // age<count：槽位有效；cached：排除 uncached；[31:2]：精确同字匹配。
        if ((ex2_store_fwd_age < sb_count) &&sb_cached[ex2_store_fwd_index] &&
            (sb_addr[ex2_store_fwd_index][31:2] == ex2_fast_direct_paddr[31:2]))
        begin
          for (ex2_store_fwd_lane = 0; ex2_store_fwd_lane < 4;ex2_store_fwd_lane = ex2_store_fwd_lane + 1)
          begin
            // 只合并该 store 实际写入的 byte，并置位对应转发 mask。
            // wstrb=1 才覆盖该 lane；wstrb=0 时保留更老 store 的结果。
            if (sb_wstrb[ex2_store_fwd_index][ex2_store_fwd_lane])
            begin
              ex2_fast_forward_data[ex2_store_fwd_lane*8 +: 8] = sb_wdata[ex2_store_fwd_index][ex2_store_fwd_lane*8 +: 8];
              ex2_fast_forward_mask[ex2_store_fwd_lane] = 1'b1;
            end
          end
        end
      end

      for (ex2_store_fwd_age = 0; ex2_store_fwd_age < WBQ_DEPTH; ex2_store_fwd_age = ex2_store_fwd_age + 1)
      begin
        // WBQ 中的 store 比 SB 更新，因此其写入字节会覆盖 SB 的旧值。
        ex2_store_fwd_index = (wbq_head + ex2_store_fwd_age) & (WBQ_DEPTH-1);
        // 过滤无效、非 pending、uncached 或地址不匹配的 WBQ 项。
        // age/count、valid、pending、cached 和 [31:2] 地址条件必须同时满足。
        if ((ex2_store_fwd_age < wbq_count) &&wbq_valid[ex2_store_fwd_index] &&
            wbq_store_pending[ex2_store_fwd_index] &&wbq_store_cached[ex2_store_fwd_index] &&
            (wbq_store_paddr[ex2_store_fwd_index][31:2] ==ex2_fast_direct_paddr[31:2]))
        begin
          for (ex2_store_fwd_lane = 0; ex2_store_fwd_lane < 4;ex2_store_fwd_lane = ex2_store_fwd_lane + 1)
          begin
            // 部分 store 只覆盖部分 lane，未写入 lane 保留之前的转发值。wstrb=1 的 lane 才覆盖快照并置位对应 mask。
            if (wbq_store_wstrb[ex2_store_fwd_index][ex2_store_fwd_lane])
            begin
              ex2_fast_forward_data[ex2_store_fwd_lane*8 +: 8] =wbq_store_wdata[ex2_store_fwd_index][ex2_store_fwd_lane*8 +: 8];
              ex2_fast_forward_mask[ex2_store_fwd_lane] = 1'b1;
            end
          end
        end
      end

      if (ex2mem_valid && mem_op_store_class && mem_xlate_ready &&
          mem_xlate_cached_eff && !mem_has_exception_final &&
          (mem_xlate_paddr_eff[31:2] == ex2_fast_direct_paddr[31:2]))
      begin
        // 当前 MEM 级间寄存器的store 是最年轻的较早 store，优先级高于 SB/WBQ。
        // valid/store/ready/cached/no-exception：该 store 确实可影响 load；[31:2]：同字。
        for (ex2_store_fwd_lane = 0; ex2_store_fwd_lane < 4; ex2_store_fwd_lane = ex2_store_fwd_lane + 1)
        begin
          // mem_issue_wstrb_next 决定 st.b/st.h/st.w 实际写入哪些 byte lane。
          // 仅 wstrb=1 的 lane 覆盖前面结果，其余 lane 继续使用 SB/WBQ 数据。
          if (mem_issue_wstrb_next[ex2_store_fwd_lane])
          begin
            ex2_fast_forward_data[ex2_store_fwd_lane*8 +: 8] =mem_issue_wdata_next[ex2_store_fwd_lane*8 +: 8];
            ex2_fast_forward_mask[ex2_store_fwd_lane] = 1'b1;
          end
        end
      end
    end
  end

  // 上述转换在ex2级就能完成，再存储到mem级间寄存器
  // “快速 direct”并不是绕过 MEM，而是：在 EX2 提前计算物理地址和冲突信息；
  // 进入 MEM 后直接发起 D-cache 请求，同步写入lq和wbq，而不是一拍写，一拍访问；仍然由 MEM/LQ 管理请求、响应和退休顺序。
  always @(posedge clk)
  begin
    if (rst)
    begin
      mem_fast_forward_valid_q <= 1'b0;
      mem_fast_forward_data_q <= 32'b0;
      mem_fast_forward_mask_q <= 4'b0;
    end
    else if (ex2mem_en)
    begin
      if (ex2mem_flush)
      begin
        mem_fast_forward_valid_q <= 1'b0;
        mem_fast_forward_data_q <= 32'b0;
        mem_fast_forward_mask_q <= 4'b0;
      end
      else
      begin
        mem_fast_forward_valid_q <= ex2_fast_direct_valid && ex12ex2_op_load_class;
        mem_fast_forward_data_q <= ex2_fast_forward_data;
        mem_fast_forward_mask_q <= ex2_fast_forward_mask;
      end
    end
  end

  wire mem_load_forward_full_comb = // 组合扫描已覆盖当前 load 所需的全部字节
       ex2mem_op_load_class && mem_xlate_ready &&
       mem_xlate_cached_eff &&
       !mem_has_exception_final &&
       ((mem_load_forward_mask & mem_load_need_mask) ==mem_load_need_mask);
  wire mem_load_partial_conflict_comb = // 组合扫描仅覆盖部分字节，需等待 cache 数据合并
       ex2mem_op_load_class && mem_xlate_ready &&
       mem_xlate_cached_eff &&
       !mem_has_exception_final &&
       ((mem_load_forward_mask & mem_load_need_mask) != 4'b0) &&!mem_load_forward_full_comb;
  wire mem_fast_forward_snapshot = // 快速直译路径已锁存到有效的 store 旁路结果，但不一定完整覆盖
       mem_fast_direct_xlate &&
       ex2mem_fast_store_hash_match && mem_fast_forward_valid_q;
  wire mem_fast_forward_full_snapshot = // 快速路径旁路结果完整覆盖当前 load
       mem_fast_forward_snapshot &&
       ((mem_fast_forward_mask_q & mem_load_need_mask) ==
        mem_load_need_mask);
  wire mem_fast_forward_partial_snapshot = // 快速路径旁路结果仅覆盖部分字节
       mem_fast_forward_snapshot &&
       ((mem_fast_forward_mask_q & mem_load_need_mask) != 4'b0) &&
       !mem_fast_forward_full_snapshot;
       
  // 没有任何老 store 时无需启动 4 SB + 4 WBQ 的 M3/SF 比较拍。
  // WBQ store 退休进入 SB 只是在两个计数之间迁移，不会出现空窗。
  wire mem_load_has_older_store = // SB 或 WBQ 中存在当前 load 之前的 store
       !sb_empty || (wbq_store_count != 0);
  wire mem_load_store_hash_match = // 快速路径使用 hash 预筛选，普通路径使用老 store 存在标志
       mem_fast_direct_xlate ?
       ex2mem_fast_store_hash_match : mem_load_has_older_store;
  assign mem_load_has_older_uncached_store = // SB/WBQ 中存在尚未完成的 uncached store
         (sb_uncached_store_count != 0) ||
         (wbq_uncached_store_count != 0);

  // uncached 项进入 LQ 时队列必为空；在它返回前禁止年轻 cached load
  // 入队。这样 CPU 无标签 data_ok 不会把 bypass 响应配给 cache 项。
  assign lq_contains_uncached = // LQ 队头当前是 uncached load/store 事务
       (lq_count != 0) && !lq_cached[lq_head];
  wire mem_load_dispatch_order_ready = // 当前 load 满足 uncached 事务的发射顺序约束
       !mem_load_has_older_uncached_store &&
       (mem_xlate_cached_eff ? !lq_contains_uncached : (lq_count == 0));

  wire mem_load_fwd_start = // 启动普通 cached load 的老 store 旁路扫描
       ex2mem_op_load_class && mem_xlate_ready &&
       !mem_has_exception_final && !mem_load_fwd_valid_q &&
       mem_xlate_cached_eff && !mem_load_has_older_uncached_store &&
       mem_load_store_hash_match && !mem_fast_forward_snapshot;
  wire mem_load_forward_eval_valid = // 存在可评估的旁路结果（普通load或者快速load）
       mem_fast_forward_snapshot ||
       mem_load_fwd_valid_q;
  wire mem_load_forward_full_selected = // 选择快速路径或普通路径的完整旁路标志
       mem_fast_forward_snapshot ?
       mem_fast_forward_full_snapshot : mem_load_forward_full_q;
  wire mem_load_partial_conflict_selected = // 选择快速路径或普通路径的部分冲突标志
       mem_fast_forward_snapshot ?
       mem_fast_forward_partial_snapshot : mem_load_partial_conflict_q;
  wire [31:0] mem_load_forward_data_selected = // 选择快速路径或普通路径的旁路数据
       mem_fast_forward_snapshot ?
       mem_fast_forward_data_q : mem_load_forward_data_q;
  wire [3:0] mem_load_forward_mask_selected = // 选择快速路径或普通路径的旁路字节掩码
       mem_fast_forward_snapshot ?
       mem_fast_forward_mask_q : mem_load_forward_mask_q;
  wire mem_load_forward_full = // 旁路结果完整且满足发射顺序，可直接完成 load
       mem_load_forward_eval_valid &&
       mem_load_forward_full_selected && mem_load_dispatch_order_ready;
  wire mem_load_partial_conflict = // 旁路结果部分覆盖，需要与 cache 返回数据合并
       mem_load_forward_eval_valid &&
       mem_load_partial_conflict_selected;
  wire mem_load_cache_candidate = // 无完整旁路时，当前 load 可进入 cache/LQ 访问
       ex2mem_op_load_class && mem_xlate_ready &&
       !mem_has_exception_final &&
       mem_load_dispatch_order_ready &&
       ((!mem_load_store_hash_match) ||
        (mem_load_forward_eval_valid && !mem_load_forward_full)) &&
       lq_has_space;


  always @(posedge clk)
  begin
    if (rst || wb_has_exception_commit || wb_do_ertn)
    begin
      mem_load_fwd_valid_q <= 1'b0;
      mem_load_forward_data_q <= 32'b0;
      mem_load_forward_mask_q <= 4'b0;
      mem_load_forward_full_q <= 1'b0;
      mem_load_partial_conflict_q <= 1'b0;
    end
    else if (ex2mem_en)//如果流动，则清空（只有后端阻塞了才需要寄存器保存）
    begin
      mem_load_fwd_valid_q <= 1'b0;
      mem_load_forward_mask_q <= 4'b0;
      mem_load_forward_full_q <= 1'b0;
      mem_load_partial_conflict_q <= 1'b0;
    end
    else if (mem_load_fwd_start)//没有流动&&普通load
    begin
      mem_load_fwd_valid_q <= 1'b1;
      mem_load_forward_data_q <= mem_load_forward_data;
      mem_load_forward_mask_q <= mem_load_forward_mask & mem_load_need_mask;
      mem_load_forward_full_q <= mem_load_forward_full_comb;
      mem_load_partial_conflict_q <= mem_load_partial_conflict_comb;
    end
  end

  
  wire mem_uncached_access = // 翻译已完成且地址属性为 uncached 的 load/store
       mem_issue_checked_q &&
       !mem_xlate_cached_q && (ex2mem_op_load_class || mem_store_xlate_op);
  wire mem_serializing_op = // 必须与更老内存操作严格保持顺序的指令
       ex2mem_serializing || mem_uncached_access ||
       ex2mem_op_cacop || ex2mem_op_tlbsrch ||
       ex2mem_op_tlbrd || ex2mem_op_tlbwr || ex2mem_op_tlbfill || ex2mem_op_invtlb ||
       ex2mem_csr_op[1] || ex2mem_op_ertn || ex2mem_op_load_linked || ex2mem_op_store_conditional;
  // 串行指令要等更老的指令全部离开 WBQ、SB 和 LQ；SB 还必须没有正在发出的写请求。
  wire mem_order_ready = // 当前 MEM 操作是否已经满足全局内存顺序要求
       !mem_serializing_op ||
       ((wbq_count == 0) && sb_empty && !sb_req_inflight &&
        (lq_count == 0));
  wire mem_state_idle = // 当前 MEM 指令还没有占用 MEM 内部的地址翻译、CACOP 请求或响应状态机，可以开始一次新的地址翻译
       !mem_s1_valid_q       // 没有正在等待完成的 TLB S1 查询
    && !mem_tlb_checked_q    // 没有已经取回、等待后续处理的 TLB 结果
    && !mem_issue_checked_q  // 没有完成的完成当前地址翻译
    && !mem_issue_req_q      // 没有等待握手的 CACOP 请求
    && !mem_resp_valid;      // 没有等待消费的 CACOP 响应
  wire mem_direct_xlate_start = // 空闲且顺序允许时，启动直接地址翻译
       mem_direct_path&&mem_state_idle&&mem_order_ready;
  wire mem_tlb_query_start = // 空闲且顺序允许时，启动 TLB 查询或 TLBSRCH 查询
       (mem_tlb_path||mem_tlbsrch_path)&&mem_state_idle&&mem_order_ready;
  wire mem_tlb_check = // TLB 查询输入已准备好，且本次查询尚未检查或发请求
       mem_s1_valid_q&&mem_s1_ready_q&&!mem_tlb_checked_q&&!mem_issue_checked_q&&
       !mem_issue_req_q&&!mem_resp_valid;
  wire mem_xlate_check = // TLB 查询结果已锁存经拿到，但最终物理地址、缓存属性和 TLB 异常还没锁存（仅在后端阻塞时锁存）
       mem_tlb_checked_q&&!mem_issue_checked_q&&
       !mem_issue_req_q&&!mem_resp_valid;
  assign mem_sc_success = // SC 只有在地址匹配且本次访问无异常时才成功
         mem_sc_attempt && mem_issue_checked_q &&
         !mem_has_exception_final &&
         lladdr_valid_q && (lladdr_q == mem_xlate_paddr_q[31:4]);
  // 普通 store 在 MEM 只完成翻译并排入退休队列，真正写 cache 由 SB 负责。
  // load完全覆盖直接使用 store 数据；部分/无覆盖：访问 cache，同时保存转发数据和字节掩码，cache 返回后逐字节合并。
  wire cacop_access_req = // CACOP 无异常且未被提交级 flush 时才允许访问 cache
       ex2mem_op_cacop&&
       !(mem_has_exception_final||wb_has_exception_commit||wb_do_ertn);
  wire mem_issue_launch = // CACOP 翻译检查完成、无在途请求且尚未收到响应时发起请求
       ex2mem_op_cacop&&mem_issue_checked_q&&
       !mem_issue_req_q&&!mem_req_inflight&&!mem_resp_valid&&
       cacop_access_req;
  
  wire lq_issue_order_ok = // 没有已发射项，或队头和当前项都是 cached 时允许发射
       (lq_issued_count == 0) ||
       (lq_cached[lq_head] && lq_cached[lq_issue_index]);
  wire lq_bus_req_base = // 普通 LQ 项可发射，且没有 SB/CACOP/响应占用数据端口
       lq_has_unissued && lq_issue_order_ok &&
       !sb_req_inflight && !mem_issue_req_q &&
       !mem_resp_valid;
  // 直接 load 与 SB 同时可发射时，直接 load 优先；本拍只使用原本空闲的端口。
  // 队列满时不强行直发，load 先进入 LQ，稍后由普通 LQ 请求路径发射。
  // flush 时已接收的 LQ 请求仍保留到响应返回，再标记为丢弃项，避免无 tag 响应错配。
  wire lq_direct_bus_req_base = // 当前 EX2 load 满足快速直发条件，直接访问 D-cache
       ex2mem_valid && ex2mem_op_load_class &&
       ex2mem_fast_direct_req_eligible && mem_fast_direct_xlate &&
       !sb_req_inflight;
  wire sb_req_base = // SB请求的前提: SB 非空且端口空闲，同时没有 LQ 项或已有 data_ok
       !sb_empty && !sb_req_inflight &&
       !mem_issue_req_q && (lq_count == 0) && !data_sram_data_ok;

  wire lq_bus_req = lq_bus_req_base; // 普通 LQ 请求候选
  wire lq_direct_bus_req = lq_direct_bus_req_base; // 快速直发的当前 load 请求
  wire data_mem_req_fire = // 普通 LQ 或直发 load 请求被 D-cache 接受
       (lq_bus_req || lq_direct_bus_req) &&
       data_sram_addr_ok;
  wire cacop_req_fire = cacop_req&&cacop_addr_ok; // CACOP 请求被 cache 接受
  wire data_mem_resp_fire = lq_response_fire; // LQ 收到 D-cache 返回数据
  wire cacop_resp_fire = cacop_data_ok; // CACOP 收到 cache 操作完成响应

  assign mem_req_fire    = cacop_req_fire; // MEM/CACOP 请求握手完成
  assign mem_resp_fire   = cacop_resp_fire; // MEM/CACOP 响应握手完成
  assign lq_issue_fire   = data_mem_req_fire; // LQ 项发射握手完成
  assign lq_response_fire = // 只有已有 LQ 在途项且 SB 未占用响应通道时接收 data_ok
         (lq_issued_count != 0) &&
         !sb_req_inflight &&
         data_sram_data_ok;
  // 直接 load 与 SB 同拍竞争时只有一个获得端口所有权；未被选中的请求不能更新在途状态。
  assign sb_req = sb_req_base && !lq_direct_bus_req; // 仅当没有直发 load 时才发 SB 请求
  assign sb_req_fire = sb_req && data_sram_addr_ok; // SB 请求握手完成
  assign sb_resp_fire = sb_req_inflight && data_sram_data_ok; // SB 写请求收到完成响应
  assign data_sram_req   = lq_bus_req || lq_direct_bus_req || sb_req; // D-cache 请求有效
  assign data_sram_wr    = sb_req; // 只有 SB 请求是写操作
  assign data_sram_size  = // 按请求来源选择 SB、直发 load 或普通 LQ 的访问宽度
         sb_req ? sb_size[sb_head] :
         lq_direct_bus_req ?
         ((ex2mem_width == 2'd2) ? 2'd0 :
          ((ex2mem_width == 2'd1) ? 2'd1 : 2'd2)) :
         lq_size[lq_issue_index];
  assign data_sram_wstrb = sb_req ? sb_wstrb[sb_head] : 4'b0; // SB 写字节使能，读请求全为 0
  assign data_sram_addr  = // 按请求来源选择 SB、直发 load 或普通 LQ 的物理地址
         sb_req ? sb_addr[sb_head] :
         lq_direct_bus_req ? mem_xlate_paddr_eff :
         lq_addr[lq_issue_index];
  assign data_sram_wdata = sb_req ? sb_wdata[sb_head] : 32'b0; // SB 写入的数据，读请求填 0
  assign data_sram_cached= // 按请求来源选择缓存属性；直发 load 已确认是 cached
         sb_req ? sb_cached[sb_head] :
         lq_direct_bus_req ? 1'b1 :
         lq_cached[lq_issue_index];
  assign cacop_req       = mem_issue_req_q&&mem_issue_is_cacop_q; // MEM 当前请求是 CACOP
  assign cacop_code      = mem_issue_cacop_code_q; // CACOP 操作码
  assign cacop_addr      = mem_issue_addr_q; // CACOP 使用的物理地址

  // MEM 级内部请求状态机。EX2/MEM 不前进时，它可以独立完成地址翻译、
  // 发出 data/CACOP 请求并缓存返回数据；流水线前进或被异常冲刷时清空状态。
  always @(posedge clk)
  begin
    if(rst||wb_has_exception_commit||wb_do_ertn)
    begin
      mem_issue_req_q<=1'b0;
      mem_issue_checked_q<=1'b0;
      mem_issue_is_cacop_q<=1'b0;
      mem_resp_pc_q<=30'b0;
      mem_s1_valid_q<=1'b0;
      mem_s1_ready_q<=1'b0;
      mem_s1_vppn_q<=19'b0;
      mem_s1_va_bit12_q<=1'b0;
      mem_s1_asid_q<=10'b0;
      mem_s1_tlb_req_q<=1'b0;
      mem_s1_cur_plv_q<=2'b0;
      mem_s1_vaddr_q<=32'b0;
      mem_s1_is_store_q<=1'b0;
      mem_tlb_checked_q<=1'b0;
      mem_tlb_found_q<=1'b0;
      mem_tlb_index_q<=5'b0;
      mem_tlb_ppn_q<=20'b0;
      mem_tlb_ps_q<=6'b0;
      mem_tlb_plv_q<=2'b0;
      mem_tlb_xlate_mat_q<=2'b0;
      mem_tlb_d_q<=1'b0;
      mem_tlb_v_q<=1'b0;
      mem_tlb_req_q<=1'b0;
      mem_tlb_cur_plv_q<=2'b0;
      mem_tlb_vaddr_q<=32'b0;
      mem_tlb_is_store_q<=1'b0;
      mem_xlate_exception_tlb_q<=1'b0;
      mem_xlate_exc_ecode_q<=6'b0;
      mem_xlate_paddr_q<=32'b0;
      mem_xlate_cached_q<=1'b0;
      mem_xlate_vaddr_q<=32'b0;
      mem_tlbsrch_found_q<=1'b0;
      mem_tlbsrch_index_q<=5'b0;
    end
    else if(ex2mem_en)
    begin
      mem_issue_req_q<=1'b0;
      mem_issue_checked_q<=1'b0;
      mem_issue_is_cacop_q<=1'b0;
      mem_resp_pc_q<=30'b0;
      mem_s1_valid_q<=1'b0;
      mem_s1_ready_q<=1'b0;
      mem_s1_vppn_q<=19'b0;
      mem_s1_va_bit12_q<=1'b0;
      mem_s1_asid_q<=10'b0;
      mem_s1_tlb_req_q<=1'b0;
      mem_s1_cur_plv_q<=2'b0;
      mem_s1_vaddr_q<=32'b0;
      mem_s1_is_store_q<=1'b0;
      mem_tlb_checked_q<=1'b0;
      mem_tlb_found_q<=1'b0;
      mem_tlb_req_q<=1'b0;
      mem_tlb_xlate_mat_q<=2'b0;
      mem_tlb_is_store_q<=1'b0;
      mem_xlate_exception_tlb_q<=1'b0;
      mem_xlate_cached_q<=1'b0;
      mem_xlate_vaddr_q<=32'b0;
      mem_tlbsrch_found_q<=1'b0;
      mem_tlbsrch_index_q<=5'b0;
    end
    else
    begin
      if(mem_req_fire) // CACOP 请求与存储器握手成功，清除待发请求及其类型标记
      begin
        mem_issue_req_q<=1'b0;
        mem_issue_is_cacop_q<=1'b0;
      end
      if(mem_direct_xlate_start) // 启动直接地址翻译，锁存物理地址和缓存属性并标记翻译完成
      begin
        mem_issue_checked_q<=1'b1;
        mem_xlate_exception_tlb_q<=1'b0;
        mem_xlate_exc_ecode_q<=6'b0;
        mem_xlate_paddr_q<=mem_direct_paddr_next;
        mem_xlate_cached_q<=mem_direct_mat_next == 2'b01;
        mem_xlate_vaddr_q<=mem_result;
      end
      if(mem_tlb_query_start) // 启动 TLB/TLBSRCH 查询，锁存 S1 端口所需的地址、ASID 和访问属性
      begin
        mem_s1_valid_q<=1'b1;
        mem_s1_ready_q<=1'b0;
        mem_s1_vppn_q<=mem_s1_vppn_next;
        mem_s1_va_bit12_q<=mem_s1_va_bit12_next;
        mem_s1_asid_q<=mem_s1_asid_next;
        mem_s1_tlb_req_q<=mem_tlb_path;
        mem_s1_cur_plv_q<=tc_csr_crmd_plv;
        mem_s1_vaddr_q<=mem_result;
        mem_s1_is_store_q<=mem_store_xlate_op;
      end
      if(mem_s1_valid_q&&!mem_s1_ready_q) // 查询发出后等待一个周期，再允许采样 S1 查询结果
        mem_s1_ready_q<=1'b1;
      if(mem_tlb_check) // S1 查询结果可用时锁存结果，结束本次 S1 查询并标记 TLB 检查完成
      begin
        mem_s1_valid_q<=1'b0;
        mem_s1_ready_q<=1'b0;
        mem_tlb_checked_q<=1'b1;
        mem_tlb_found_q<=s1_found;
        mem_tlb_index_q<=s1_index;
        mem_tlb_ppn_q<=s1_ppn;
        mem_tlb_ps_q<=s1_ps;
        mem_tlb_plv_q<=s1_plv;
        mem_tlb_xlate_mat_q<=mem_s1_tlb_req_q && s1_found ? s1_mat : 2'b00;
        mem_tlb_d_q<=s1_d;
        mem_tlb_v_q<=s1_v;
        mem_tlb_req_q<=mem_s1_tlb_req_q;
        mem_tlb_cur_plv_q<=mem_s1_cur_plv_q;
        mem_tlb_vaddr_q<=mem_s1_vaddr_q;
        mem_tlb_is_store_q<=mem_s1_is_store_q;
      end
      if(mem_xlate_check) // 根据已锁存的 TLB 结果生成最终翻译信息，并记录异常及 TLBSRCH 结果
      begin
        mem_issue_checked_q<=1'b1;
        mem_xlate_exception_tlb_q<=mem_xlate_exception_tlb_next;
        mem_xlate_exc_ecode_q<=mem_xlate_exc_ecode_next;
        mem_xlate_paddr_q<=mem_xlate_paddr_next;
        mem_xlate_cached_q<=mem_xlate_mat_next == 2'b01;
        mem_xlate_vaddr_q<=mem_tlb_vaddr_q;
        mem_tlbsrch_found_q<=mem_tlb_found_q;
        mem_tlbsrch_index_q<=mem_tlb_index_q;
      end
      if(mem_issue_launch) // CACOP 满足发射条件时建立请求，并锁存访问地址、操作码和响应 PC
      begin
        mem_issue_req_q<=1'b1;
        mem_issue_is_cacop_q<=cacop_access_req;
        mem_issue_addr_q<=cacop_access_req && !mem_op_cacop_hit_va ? mem_result : mem_xlate_paddr_q;
        mem_issue_cacop_code_q<=ex2mem_gpr_waddr;
        mem_resp_pc_q<=ex2mem_pc_plus_4_word;
      end
    end
  end

  // MEM 阶段离开条件：普通指令直接完成； 需要地址检查（load、store、CACOP 等）的指令，须等物理地址及最终异常信息锁存后才能离开 MEM 级。
  // store/SC 等待地址转换或sc条件判定；load 全量旁路时以 ready 项入队，否则在满足
  // cache/LQ 发射条件后以 not-ready 项入队并等待返回数据；CACOP 等待响应，TLBSRCH 等待查询完成。
  wire mem_load_complete = ex2mem_op_load_class && // load 已具备离开 MEM 级的条件
       (mem_has_exception_final ? mem_issue_checked_q :
        (mem_load_forward_full ||
         mem_load_cache_candidate));
  wire mem_store_complete = mem_store_en && // store/SC 已完成地址转换或条件判定
       (ex2mem_op_store_conditional ? (!mem_sc_attempt || mem_issue_checked_q) :
        mem_xlate_ready);
  wire mem_cacop_complete = ex2mem_op_cacop && // CACOP 异常已确认或正常响应已返回
       (mem_has_exception_final ? mem_issue_checked_q :
        (mem_resp_valid && (mem_resp_pc_q == ex2mem_pc_plus_4_word)));
  wire mem_tlbsrch_complete = ex2mem_op_tlbsrch && mem_issue_checked_q; // TLBSRCH 已完成发射检查
  wire mem_nonwork_complete = ex2mem_has_exception || // 无需等待访存类工作的指令可直接完成
       !(ex2mem_op_load_class || mem_store_en || ex2mem_op_cacop || ex2mem_op_tlbsrch);
  wire mem_stage_complete = mem_order_ready && // MEM 当前指令满足顺序约束和自身完成条件
       (mem_nonwork_complete || mem_load_complete || mem_store_complete ||
        mem_cacop_complete || mem_tlbsrch_complete);

  // WBQ 入队快照包含该指令从 MEM 离开后提交所需的全部字段
  wire [WBQ_META_W-1:0] wbq_enq_meta = { // WBQ 入队时保存的提交元数据快照
         ex2mem_serializing,ex2mem_refetch,
         ex2mem_pc_plus_4_word,mem_result,ex2mem_store_data,ex2mem_gpr_waddr,
         ex2mem_gpr_write_en,ex2mem_gpr_wdata_from_pc4,
         ex2mem_op_load_class,ex2mem_op_load_linked,ex2mem_op_store_conditional,mem_sc_success,mem_op_store_class,
         ex2mem_op_ertn,mem_has_exception_final,ex2mem_csr_op,ex2mem_csr_num,
         ex2mem_csr_rj_data,ex2mem_exc_code,mem_exc_ecode_final,mem_bypass_data,
         ex2mem_rk_data,ex2mem_op_tlbrd,ex2mem_op_invtlb,ex2mem_op_cacop,
         ex2mem_invtlb_op};
  wire [31:0] mem_mon_store_data = // 按实际写地址对齐后的监控 store 数据
       mon_mem_stb ? ({24'b0,mem_store_data[7:0]} << {ex2mem_result[1:0],3'b0}) :
       (mon_mem_sth ? ({16'b0,mem_store_data[15:0]} << {ex2mem_result[1],4'b0}) :
        mem_store_data);
  wire [WBQ_MON_W-1:0] wbq_enq_mon = { // WBQ 入队时保存的差分监控信息
         mon_mem_inst,mon_mem_timer,mon_mem_ldb,mon_mem_ldh,mon_mem_ldbu,
         mon_mem_ldhu,mon_mem_stb,mon_mem_sth,mem_xlate_paddr_eff,
         mem_xlate_vaddr_eff,mem_mon_store_data,
         (ex2mem_op_tlbfill ? mem_tlbfill_index : 5'b0)};

  // ==================== MEM/WBQ：完成队列、Load Queue 与 Store Buffer ====================

  // 空队列时给解包器全零，保证 WB 级所有副作用控制为 0，而不是读取无效槽内容。
  wire [WBQ_META_W-1:0] wbq_head_meta = // 当前 WBQ 队首的提交元数据，无效时清零
       wbq_head_valid ? wbq_meta[wbq_head] : {WBQ_META_W{1'b0}};
  wire [31:0] wb_mem_paddr = wbq_mem_paddr[wbq_head]; // 当前 WB 指令的访存物理地址
  assign {wbq_head_serializing,wbq_head_refetch,
          wbq_head_pc_plus_4_word,wbq_head_result,wbq_head_csr_wdata,wbq_head_gpr_waddr,
          wbq_head_gpr_write_en,wbq_head_gpr_wdata_from_pc4,
          wbq_head_op_load_class,wbq_head_op_load_linked,wbq_head_op_store_conditional,wbq_head_sc_success,wbq_head_op_store_class,
          wbq_head_op_ertn,wbq_head_has_exception,wbq_head_csr_op,wbq_head_csr_num,wbq_head_csr_rj_data,
          wbq_head_exc_code,wbq_head_exc_ecode,wbq_head_bypass_data,wbq_head_rk_data,
          wbq_head_op_tlbrd,wbq_head_op_invtlb,wbq_head_op_cacop,
          wbq_head_invtlb_op} = wbq_head_meta;


  wire [31:0] wbq_head_raw_load = wbq_load_data[wbq_head]; // 队首 load 返回的原始 32 位数据
  wire [31:0] wbq_head_shifted_byte = // 将目标字节移到最低 8 位
       wbq_head_raw_load >> {wbq_load_addr_low[wbq_head],3'b000};
  wire [15:0] wbq_head_half = wbq_load_addr_low[wbq_head][1] ? // 按地址选择目标半字
       wbq_head_raw_load[31:16] : wbq_head_raw_load[15:0];
  assign wb_load_data = (wbq_load_width[wbq_head] == 2'd0) ? // 按宽度和符号属性扩展最终 load 数据
         wbq_head_raw_load :
         ((wbq_load_width[wbq_head] == 2'd1) ?
          (wbq_load_sign[wbq_head] ?
           {{16{wbq_head_half[15]}},wbq_head_half} : {16'b0,wbq_head_half}) :
          (wbq_load_sign[wbq_head] ?
           {{24{wbq_head_shifted_byte[7]}},wbq_head_shifted_byte[7:0]} :
           {24'b0,wbq_head_shifted_byte[7:0]}));

  wire [WBQ_MON_W-1:0] wbq_head_mon = // 当前 WBQ 队首的差分监控信息，无效时清零
       wbq_head_valid ? wbq_mon[wbq_head] : {WBQ_MON_W{1'b0}};
  assign {mon_wb_inst,mon_wb_timer,mon_wb_ldb,mon_wb_ldh,mon_wb_ldbu,
          mon_wb_ldhu,mon_wb_stb,mon_wb_sth,mon_wb_mem_paddr,
          mon_wb_mem_vaddr,mon_wb_store_data,mon_wb_tlbfill_index} =
         wbq_head_mon;
  assign mon_wb_valid = wbq_head_valid; // WB 级监控信息有效标志

  assign wbq_has_space = (wbq_count < WBQ_DEPTH) || wbq_pop; // WBQ 未满或本拍出队可腾出槽位
  // WB 异常/ERTN 在提交拍先清空 WBQ，前端重定向为降低扇出延后一拍。
  // 该延迟拍仍可看见年轻的 MEM 指令，不能让它重新插入刚清空的 WBQ。
  assign wbq_enq = ex2mem_valid && mem_stage_complete && wbq_has_space && // MEM 指令可进入 WBQ
         !WB_redirect_valid_q;
  assign lq_enqueue = wbq_enq && ex2mem_op_load_class && // 未完全转发的正常 load 进入 LQ
  // 完全覆盖时，load 不进入 LQ，但仍会进入 WBQ
         !mem_has_exception_final &&
         !mem_load_forward_full;
  assign wbq_flush = wb_has_exception_commit || wb_do_ertn; // WB 异常提交或 ERTN 时清空 WBQ
  assign wbq_store_enq = wbq_enq && mem_op_store_class && // 无异常 store 随指令进入 WBQ
         !mem_has_exception_final;
  wire wbq_store_pop = wbq_pop && wbq_store_pending[wbq_head]; // 出队指令带有待提交 store
  wire wbq_uncached_store_enq = wbq_store_enq && !mem_xlate_cached_eff; // 非缓存 store 进入 WBQ
  wire wbq_uncached_store_pop = wbq_store_pop && // 非缓存 store 随队首提交出队
       !wbq_store_cached[wbq_head];

  // 功能：WBQ 队首退休后，重新寻找“最近一条还会写 rd 的指令”。
  // 同一个通用寄存器可能被多条尚未退休的指令连续写入。例如：
  //   slot0: 写 r5（最老，当前 head）
  //   slot1: 写 r3
  //   slot2: 写 r5
  //   slot3: 写 r5（最年轻）
  // slot0 退休后，r5 的最新生产者应改成 slot3，后续依赖 r5 的指令才能
  // 从正确的 slot 取旁路数据。该函数就是完成这个重新选择。
  //
  // old_head 是刚刚被 pop 的旧队首。四项 WBQ 是环形队列，因此从
  // old_head+1 开始向后扫描 3 个位置，超过 slot3 时两位加法会自然回绕。
  // 扫描方向是“较老 -> 较年轻”，每遇到一个写同一 rd 的有效项就覆盖返回值，
  // 所以循环结束时留下的一定是所有匹配项中最年轻的 slot。
  // 如果没有剩余生产者，初始值 old_head 没有实际意义；调用处会同时发现
  // gpr_wbq_slots[rd] 已空并清除相应状态，不会使用这个无意义的 slot。
  function [1:0] wbq_latest_after_pop;
    input [4:0] rd;       // 要重新查找生产者的通用寄存器号（r0~r31）
    input [1:0] old_head; // 本拍刚退休的旧队首 slot 编号
    integer age;          // 相对 old_head 的队列年龄偏移：1、2、3
    reg [1:0] slot;       // 当前正在检查的实际环形队列 slot
    begin
      // 先给返回值一个确定值，避免组合逻辑中出现未赋值分支；
      // 若后面存在匹配项，它会被相应的 slot 编号覆盖。
      wbq_latest_after_pop = old_head;
      for (age = 1; age < WBQ_DEPTH; age = age + 1)
      begin
        // WBQ_DEPTH=4 且 slot 只有两位，所以加法结果会按 4 取模：
        // 例如 old_head=3 时，依次得到 slot 0、1、2。
        slot = old_head + age[1:0];
        // 只有“slot 有效、确实有待退休的 GPR 写回、目的寄存器相同”
        // 才是 rd 的候选生产者。不要在这里提前退出：后面还可能有更年轻
        // 的同 rd 写入者，应让更年轻者继续覆盖当前选择。
        if (wbq_valid[slot] && wbq_gpr_pending[slot] &&
            (wbq_gpr_rd[slot] == rd))
          wbq_latest_after_pop = slot;
      end
    end
  endfunction

  // 功能：把 cache 返回的 32 位数据与老 store 前递的数据按字节合并。
  function [31:0] merge_load_forward_bytes;
    input [31:0] cache_data;   // cache 返回的完整 32 位对齐 word，作为合并底值
    input [31:0] forward_data; // 从老 store 收集到的逐字节前递数据
    input [3:0] forward_mask;  // 每一位指示对应 byte lane 的前递数据是否有效
    integer merge_lane;        // 当前处理的 byte lane 编号（0~3）
    begin
      // 默认四个字节全部取 cache；循环只替换 mask 指定的那些字节。
      merge_load_forward_bytes = cache_data;
      for (merge_lane = 0; merge_lane < 4; merge_lane = merge_lane + 1)
        if (forward_mask[merge_lane])
          // Verilog 的 [base +: width] 表示从 base 位开始向高位取 width 位；
          // 因此这里恰好复制第 merge_lane 个 8-bit 字节。
          merge_load_forward_bytes[merge_lane*8 +: 8] =
                                  forward_data[merge_lane*8 +: 8];
    end
  endfunction

  // 功能：从一个 32 位对齐 word 中取出 load 真正需要的字节/半字/整字，
  // 再按指令类型做符号扩展或零扩展，得到最终写入 GPR 的 32 位结果。
  // raw_word 在进入本函数前已经通过 merge_load_forward_bytes 合并过老 store
  // 的前递字节，所以这里只负责“选择访问宽度 + 对齐位置 + 扩展方式”。
  // 本设计中的 width 编码为：
  //   width=0：load word，直接返回全部 32 位
  //   width=1：load half，取 16 位后扩展到 32 位
  //   其他值：load byte，取 8 位后扩展到 32 位
  // sign_ext=1 表示符号扩展（如 ld.h/ld.b），sign_ext=0 表示零扩展
  // （如 ld.hu/ld.bu）。addr_low 是访存地址的低两位，用来指出目标数据
  // 位于这个 32 位对齐 word 的哪个位置；地址对齐异常已由前级逻辑处理。
  function [31:0] format_load_result;
    input [31:0] raw_word; // cache 数据与 store 前递数据合并后的 32 位对齐 word
    input [1:0] width;     // 访问宽度编码：0=word，1=half，其他=byte
    input sign_ext;        // 1=符号扩展，0=零扩展（word 情况不使用）
    input [1:0] addr_low;  // load 地址低两位，即目标字节在 word 内的偏移 0~3
    reg [31:0] shifted_byte; // 将目标字节右移到最低 8 位后的临时数据
    reg [15:0] selected_half; // 根据地址选择出的低半字或高半字
    begin
      // {addr_low,3'b000} 等于 addr_low*8，即把“字节偏移”换算为“位偏移”。
      // 例如 addr_low=2 时右移 16 位，原来的 raw_word[23:16] 就来到 [7:0]，
      // 随后 byte load 统一读取 shifted_byte[7:0] 即可。
      shifted_byte = raw_word >> {addr_low,3'b000};

      // 对齐的 half load 只可能从 word 的低 16 位（addr_low[1]=0）或
      // 高 16 位（addr_low[1]=1）读取，因此只需检查地址低两位中的 bit1。
      selected_half = addr_low[1] ? raw_word[31:16] : raw_word[15:0];
      case (width)
        2'd0:
          // Word load 已经是 32 位，不需要选择局部字段或扩展。
          format_load_result = raw_word;
        2'd1:
          // Half load：有符号时复制 bit15（符号位）填充高 16 位；
          // 无符号时高 16 位补 0。
          format_load_result = sign_ext ?
          {{16{selected_half[15]}},selected_half} :
            {16'b0,selected_half};
        default:
          // Byte load：目标字节已被移到 [7:0]。有符号时复制 bit7
          // 填充高 24 位，无符号时高 24 位补 0。
          format_load_result = sign_ext ?
          {{24{shifted_byte[7]}},shifted_byte[7:0]} :
            {24'b0,shifted_byte[7:0]};
      endcase
    end
  endfunction

  // cache 响应与依赖它的 EX1 指令可能同拍出现。WBQ scoreboard 在下一时钟沿
  // 更新，因此若只使用其已寄存的 ready/data 位，会留下一个可避免的 load-use
  // bubble。当响应 slot 仍是所请求 GPR 的最年轻写入者时转发该响应；更年轻的 WBQ 生产者必须保持优先级。
  wire [1:0] lq_response_slot /* 当前 load 响应对应的 WBQ 槽位 */ = lq_wbq_slot[lq_head];
  wire [4:0] lq_response_rd /* 当前 load 响应的目的 GPR 编号 */ = wbq_gpr_rd[lq_response_slot];
  wire lq_response_gpr_valid /* 当前 load 响应可直接转发至 GPR 操作数 */ = data_mem_resp_fire &&
       !lq_discard[lq_head] && wbq_gpr_pending[lq_response_slot] &&
       (lq_response_rd != 5'b0) &&
       (gpr_wbq_latest_slot[lq_response_rd] == lq_response_slot);
  wire [31:0] lq_response_raw /* 合并 store 前递字节后的原始 load 数据 */ = merge_load_forward_bytes(
         data_sram_rdata,
         wbq_load_forward_data[lq_response_slot],
         wbq_load_forward_mask[lq_response_slot]);
  wire [31:0] lq_response_value /* 按访存宽度及符号位扩展后的 load 数据 */ = format_load_result(
         lq_response_raw, wbq_load_width[lq_response_slot],
         wbq_load_sign[lq_response_slot],
         wbq_load_addr_low[lq_response_slot]);
  wire ex1_rj_load_response_bypass /* load 响应命中 EX1 的 rj 操作数 */ = lq_response_gpr_valid &&
       id2ex1_uses_rj && (id2ex1_rj_addr == lq_response_rd);
  wire ex1_rk_load_response_bypass /* load 响应命中 EX1 的 rk 操作数 */ = lq_response_gpr_valid &&
       id2ex1_uses_rk && (id2ex1_rk_addr == lq_response_rd);
  assign ex1_rj_wbq_bypass_ready /* EX1 的 rj 可从 WBQ 或同拍 load 响应取数 */ = (|ex1_rj_wbq_slots) &&
         (gpr_wbq_latest_ready[id2ex1_rj_addr] || ex1_rj_load_response_bypass);
  assign ex1_rk_wbq_bypass_ready /* EX1 的 rk 可从 WBQ 或同拍 load 响应取数 */ = (|ex1_rk_wbq_slots) &&
         (gpr_wbq_latest_ready[id2ex1_rk_addr] || ex1_rk_load_response_bypass);
  assign ex1_rj_wbq_bypass_data /* EX1 的 rj 前递数据 */ = ex1_rj_load_response_bypass ?
         lq_response_value : gpr_wbq_latest_data[id2ex1_rj_addr];
  assign ex1_rk_wbq_bypass_data /* EX1 的 rk 前递数据 */ = ex1_rk_load_response_bypass ?
         lq_response_value : gpr_wbq_latest_data[id2ex1_rk_addr];

  integer wbq_i;
  integer gpr_sb_i;
  always @(posedge clk)
  begin
    // 复位或 WBQ 冲刷时，清空队列状态以及全部 GPR scoreboard 信息。
    if (rst || wbq_flush)
    begin
      wbq_head <= 2'b0;
      wbq_tail <= 2'b0;
      wbq_count <= 3'b0;
      wbq_store_count <= 3'b0;
      wbq_uncached_store_count <= 3'b0;
      // 遍历所有 WBQ 槽位，将元数据、访存信息和有效状态复位。
      for (wbq_i = 0; wbq_i < WBQ_DEPTH; wbq_i = wbq_i + 1)
      begin
        wbq_meta[wbq_i] <= {WBQ_META_W{1'b0}};
        wbq_mon[wbq_i] <= {WBQ_MON_W{1'b0}};
        wbq_load_data[wbq_i] <= 32'b0;
        wbq_load_forward_data[wbq_i] <= 32'b0;
        wbq_load_forward_mask[wbq_i] <= 4'b0;
        wbq_load_width[wbq_i] <= 2'b0;
        wbq_load_sign[wbq_i] <= 1'b0;
        wbq_load_addr_low[wbq_i] <= 2'b0;
        wbq_valid[wbq_i] <= 1'b0;
        wbq_ready[wbq_i] <= 1'b0;
        wbq_gpr_pending[wbq_i] <= 1'b0;
        wbq_gpr_rd[wbq_i] <= 5'b0;
        wbq_gpr_is_latest[wbq_i] <= 1'b0;
        wbq_store_pending[wbq_i] <= 1'b0;
        wbq_store_paddr[wbq_i] <= 32'b0;
        wbq_store_wdata[wbq_i] <= 32'b0;
        wbq_store_wstrb[wbq_i] <= 4'b0;
        wbq_store_size[wbq_i] <= 2'b0;
        wbq_store_cached[wbq_i] <= 1'b0;
        wbq_mem_paddr[wbq_i] <= 32'b0;
      end
      // 遍历全部 GPR，清空其 WBQ 生产者集合和最新值缓存。
      for (gpr_sb_i = 0; gpr_sb_i < 32; gpr_sb_i = gpr_sb_i + 1)
      begin
        gpr_wbq_slots[gpr_sb_i] <= {WBQ_DEPTH{1'b0}};
        gpr_wbq_latest_slot[gpr_sb_i] <= 2'b0;
        gpr_wbq_latest_data[gpr_sb_i] <= 32'b0;
        gpr_wbq_latest_ready[gpr_sb_i] <= 1'b0;
      end
    end
    else
    begin
      // D-cache 响应有效且对应 load 未被丢弃时，合并前递数据并将 WBQ 槽位置为就绪。
      if (data_mem_resp_fire && !lq_discard[lq_head])
      begin
        wbq_load_data[lq_wbq_slot[lq_head]] <=
                     merge_load_forward_bytes(
                       data_sram_rdata,
                       wbq_load_forward_data[lq_wbq_slot[lq_head]],
                       wbq_load_forward_mask[lq_wbq_slot[lq_head]]);
        wbq_ready[lq_wbq_slot[lq_head]] <= 1'b1;
        // 响应槽位仍是该 GPR 的最新生产者时，同步更新 scoreboard 的就绪位和数据。
        if (wbq_gpr_pending[lq_wbq_slot[lq_head]] &&
            (gpr_wbq_latest_slot[
               wbq_gpr_rd[lq_wbq_slot[lq_head]]] ==
             lq_wbq_slot[lq_head]))
        begin
          gpr_wbq_latest_ready[
              wbq_gpr_rd[lq_wbq_slot[lq_head]]] <= 1'b1;
          gpr_wbq_latest_data[
              wbq_gpr_rd[lq_wbq_slot[lq_head]]] <=
            format_load_result(
              merge_load_forward_bytes(
                data_sram_rdata,
                wbq_load_forward_data[lq_wbq_slot[lq_head]],
                wbq_load_forward_mask[lq_wbq_slot[lq_head]]),
              wbq_load_width[lq_wbq_slot[lq_head]],
              wbq_load_sign[lq_wbq_slot[lq_head]],
              wbq_load_addr_low[lq_wbq_slot[lq_head]]);
        end
      end

      // WBQ 头项可以退休时，释放其槽位并将队头推进一项。
      if (wbq_pop)
      begin
        // 退休项仍持有 GPR 写依赖时，从该 GPR 的生产者集合中移除它。
        if (wbq_gpr_pending[wbq_head])
        begin
          gpr_wbq_slots[wbq_gpr_rd[wbq_head]][wbq_head] <= 1'b0;
          // 退休项是最新生产者时，重新选择剩余生产者并清除旧的缓存数据。
          if (gpr_wbq_latest_slot[wbq_gpr_rd[wbq_head]] == wbq_head)
          begin
            gpr_wbq_latest_slot[wbq_gpr_rd[wbq_head]] <=
                               wbq_latest_after_pop(wbq_gpr_rd[wbq_head], wbq_head);
            gpr_wbq_latest_ready[wbq_gpr_rd[wbq_head]] <= 1'b0;
            gpr_wbq_latest_data[wbq_gpr_rd[wbq_head]] <= 32'b0;
            // 同拍没有同一目的 GPR 的新生产者入队且仍有其他生产者时，
            // 将剩余生产者中最年轻的 slot 重新标记为 latest。
            if (!(wbq_enq && ex2mem_gpr_write_en &&
                  (ex2mem_gpr_waddr != 5'b0) &&
                  (ex2mem_gpr_waddr == wbq_gpr_rd[wbq_head])) &&
                (|(gpr_wbq_slots[wbq_gpr_rd[wbq_head]] &
                   ~(4'b0001 << wbq_head))))
              wbq_gpr_is_latest[
                  wbq_latest_after_pop(wbq_gpr_rd[wbq_head], wbq_head)] <= 1'b1;
          end
        end
        wbq_valid[wbq_head] <= 1'b0;
        wbq_ready[wbq_head] <= 1'b0;
        wbq_gpr_pending[wbq_head] <= 1'b0;
        wbq_gpr_is_latest[wbq_head] <= 1'b0;
        wbq_store_pending[wbq_head] <= 1'b0;
        wbq_head <= wbq_head + 2'd1;
      end
      // MEM 阶段产生新的 WBQ 项时，写入队尾并将队尾推进一项。
      if (wbq_enq)
      begin
        // 新项确实写非零 GPR 时，将其登记为该寄存器的最新生产者。
        if (ex2mem_gpr_write_en && (ex2mem_gpr_waddr != 5'b0))
        begin
          // 该 GPR 已有在途生产者时，撤销原最新生产者的 latest 标记。
          if (|gpr_wbq_slots[ex2mem_gpr_waddr])
            wbq_gpr_is_latest[gpr_wbq_latest_slot[ex2mem_gpr_waddr]] <= 1'b0;
          wbq_gpr_is_latest[wbq_tail] <= 1'b1;
          gpr_wbq_slots[ex2mem_gpr_waddr][wbq_tail] <= 1'b1;
          gpr_wbq_latest_slot[ex2mem_gpr_waddr] <= wbq_tail;
          gpr_wbq_latest_ready[ex2mem_gpr_waddr] <=
                              (ex2mem_csr_op == 2'b0) &&
                              (!ex2mem_op_load_class || mem_has_exception_final ||
                               mem_load_forward_full);
          gpr_wbq_latest_data[ex2mem_gpr_waddr] <=
                             (ex2mem_op_load_class && mem_load_forward_full) ?
                             format_load_result(mem_load_forward_data_selected,ex2mem_width,
                                                ex2mem_sign,mem_result[1:0]) :
                             mem_bypass_data;
        end
        wbq_meta[wbq_tail] <= wbq_enq_meta;
        wbq_mon[wbq_tail] <= wbq_enq_mon;
        wbq_load_data[wbq_tail] <=
                     (ex2mem_op_load_class && mem_load_forward_full) ?
                     mem_load_forward_data_selected : 32'b0;
        wbq_load_forward_data[wbq_tail] <=
                             (ex2mem_op_load_class && mem_load_partial_conflict) ?
                             mem_load_forward_data_selected : 32'b0;
        wbq_load_forward_mask[wbq_tail] <=
                             (ex2mem_op_load_class && mem_load_partial_conflict) ?
                             mem_load_forward_mask_selected : 4'b0;
        wbq_load_width[wbq_tail] <= ex2mem_width;
        wbq_load_sign[wbq_tail] <= ex2mem_sign;
        wbq_load_addr_low[wbq_tail] <= mem_result[1:0];
        wbq_valid[wbq_tail] <= 1'b1;
        wbq_ready[wbq_tail] <= !ex2mem_op_load_class || mem_has_exception_final ||
                 mem_load_forward_full;
        wbq_gpr_pending[wbq_tail] <= ex2mem_gpr_write_en &&
                       (ex2mem_gpr_waddr != 5'b0);
        wbq_gpr_rd[wbq_tail] <= ex2mem_gpr_waddr;
        // 新项不写有效 GPR 时，确保其不会被误认为最新 GPR 生产者。
        if (!(ex2mem_gpr_write_en && (ex2mem_gpr_waddr != 5'b0)))
        begin
          wbq_gpr_is_latest[wbq_tail] <= 1'b0;
        end
        wbq_store_pending[wbq_tail] <= mem_op_store_class &&
                         !mem_has_exception_final;
        wbq_store_paddr[wbq_tail] <= mem_xlate_paddr_eff;
        wbq_store_wdata[wbq_tail] <= mem_issue_wdata_next;
        wbq_store_wstrb[wbq_tail] <= mem_issue_wstrb_next;
        wbq_store_size[wbq_tail] <=
                      (ex2mem_width == 2'd2) ? 2'd0 :
                      ((ex2mem_width == 2'd1) ? 2'd1 : 2'd2);
        wbq_store_cached[wbq_tail] <= mem_xlate_cached_eff;
        wbq_mem_paddr[wbq_tail] <= mem_xlate_paddr_eff;
        wbq_tail <= wbq_tail + 2'd1;
      end
      case ({wbq_enq,wbq_pop})
        2'b10: // 仅入队：WBQ 占用项数加一。
          wbq_count <= wbq_count + 3'd1;
        2'b01: // 仅出队：WBQ 占用项数减一。
          wbq_count <= wbq_count - 3'd1;
        default: // 同时入队和出队或均未发生：占用项数保持不变。
          wbq_count <= wbq_count;
      endcase
      case ({wbq_store_enq,wbq_store_pop})
        2'b10: // 仅有 store 入队：在途 store 数量加一。
          wbq_store_count <= wbq_store_count + 3'd1;
        2'b01: // 仅有 store 出队：在途 store 数量减一。
          wbq_store_count <= wbq_store_count - 3'd1;
        default: // store 同时入队和出队或均未发生：数量保持不变。
          wbq_store_count <= wbq_store_count;
      endcase
      case ({wbq_uncached_store_enq,wbq_uncached_store_pop})
        2'b10: // 仅有非缓存 store 入队：计数加一。
          wbq_uncached_store_count <= wbq_uncached_store_count + 3'd1;
        2'b01: // 仅有非缓存 store 出队：计数减一。
          wbq_uncached_store_count <= wbq_uncached_store_count - 3'd1;
        default: // 同时入队和出队或均未发生：计数保持不变。
          wbq_uncached_store_count <= wbq_uncached_store_count;
      endcase
    end
  end

  // WB 的异常、ERTN 和串行 refetch 统一锁存成一组 redirect valid/PC。
  // 异常/ERTN 在精确退休拍先提交 CSR，前端大扇出恢复延后一拍。
  always @(posedge clk)
  begin
    if (rst)
    begin
      WB_redirect_valid_q <= 1'b0;
      WB_redirect_pc_q <= 32'b0;
    end
    else
    begin
      WB_redirect_valid_q <= 1'b0;
      if (wb_has_exception_commit)
      begin
        WB_redirect_valid_q <= 1'b1;
        WB_redirect_pc_q <= wb_exception_entry;
      end
      else if (wb_do_ertn)
      begin
        WB_redirect_valid_q <= 1'b1;
        WB_redirect_pc_q <= wb_ertn_pc;
      end
      else if (WB_serial_retire && wbq_head_refetch)
      begin
        WB_redirect_valid_q <= 1'b1;
        WB_redirect_pc_q <= {wbq_head_pc_plus_4_word,2'b00};
      end
    end
  end

  integer sb_i;
  always @(posedge clk)
  begin
    if (rst)
    begin
      sb_head <= 2'b0;
      sb_tail <= 2'b0;
      sb_count <= 3'b0;
      sb_uncached_store_count <= 3'b0;
      sb_req_inflight <= 1'b0;
      for (sb_i = 0; sb_i < SB_DEPTH; sb_i = sb_i + 1)
      begin
        sb_addr[sb_i] <= 32'b0;
        sb_wdata[sb_i] <= 32'b0;
        sb_wstrb[sb_i] <= 4'b0;
        sb_size[sb_i] <= 2'b0;
        sb_cached[sb_i] <= 1'b0;
        sb_valid[sb_i] <= 1'b0;
      end
    end
    else
    begin
      if (sb_resp_fire)
      begin
        sb_valid[sb_head] <= 1'b0;
        sb_head <= sb_head + 2'd1;
        sb_req_inflight <= 1'b0;
      end
      else if (sb_req_fire)
        sb_req_inflight <= 1'b1;

      if (sb_enqueue)
      begin
        sb_addr[sb_tail] <= wbq_store_paddr[wbq_head];
        sb_wdata[sb_tail] <= wbq_store_wdata[wbq_head];
        sb_wstrb[sb_tail] <= wbq_store_wstrb[wbq_head];
        sb_size[sb_tail] <= wbq_store_size[wbq_head];
        sb_cached[sb_tail] <= wbq_store_cached[wbq_head];
        sb_valid[sb_tail] <= 1'b1;
        sb_tail <= sb_tail + 2'd1;
      end
      case ({sb_enqueue,sb_resp_fire})
        2'b10:
          sb_count <= sb_count + 3'd1;
        2'b01:
          sb_count <= sb_count - 3'd1;
        default:
          sb_count <= sb_count;
      endcase
      case ({sb_enqueue && !wbq_store_cached[wbq_head],
               sb_resp_fire && !sb_cached[sb_head]})
        2'b10:
          sb_uncached_store_count <= sb_uncached_store_count + 3'd1;
        2'b01:
          sb_uncached_store_count <= sb_uncached_store_count - 3'd1;
        default:
          sb_uncached_store_count <= sb_uncached_store_count;
      endcase
    end
  end

  // 两项 load queue 将 MEM/WBQ 分配与 data_sram 地址握手解耦。
  // 地址和响应都严格按序，因此无标签 data_ok 始终回填 lq_head 对应
  // 的 WBQ slot。异常/ertn 丢弃尚未发射项，并把已发射项标成 discard；
  // 旧响应仍按序吃掉，但不会写入已经冲刷并可能复用的 WBQ slot。
  integer lq_i;
  always@(posedge clk)
  begin
    if(rst)
    begin
      lq_head <= 1'b0;
      lq_tail <= 1'b0;
      lq_count <= 2'b0;
      lq_issued_count <= 2'b0;
      for (lq_i = 0; lq_i < LQ_DEPTH; lq_i = lq_i + 1)
      begin
        lq_addr[lq_i] <= 32'b0;
        lq_size[lq_i] <= 2'b0;
        lq_cached[lq_i] <= 1'b0;
        lq_wbq_slot[lq_i] <= 2'b0;
        lq_discard[lq_i] <= 1'b0;
      end
    end
    else if (wb_has_exception_commit || wb_do_ertn)
    begin
      // response 和新的地址握手都可能与 flush 同拍。当前响应属于旧
      // epoch；本拍刚握手的年轻请求也必须保留为 discard，等待其无
      // 标签响应返回后再释放，不能让全局异常信号进入 cache 请求路径。
      if (lq_response_fire)
        lq_head <= lq_head + 1'b1;
      lq_tail <= lq_head + lq_issued_count[0] + lq_issue_fire;
      lq_count <= lq_issued_count +
               (lq_issue_fire ? 2'd1 : 2'd0) -
               (lq_response_fire ? 2'd1 : 2'd0);
      lq_issued_count <= lq_issued_count +
                      (lq_issue_fire ? 2'd1 : 2'd0) -
                      (lq_response_fire ? 2'd1 : 2'd0);
      for (lq_i = 0; lq_i < LQ_DEPTH; lq_i = lq_i + 1)
        lq_discard[lq_i] <= 1'b1;
    end
    else
    begin
      if (lq_response_fire)
      begin
        lq_head <= lq_head + 1'b1;
        lq_discard[lq_head] <= 1'b0;
      end
      if (lq_enqueue)
      begin
        lq_addr[lq_tail] <= mem_xlate_paddr_eff;
        lq_size[lq_tail] <=
               (ex2mem_width == 2'd2) ? 2'd0 :
               ((ex2mem_width == 2'd1) ? 2'd1 : 2'd2);
        lq_cached[lq_tail] <= mem_xlate_cached_eff;
        lq_wbq_slot[lq_tail] <= wbq_tail;
        lq_discard[lq_tail] <= 1'b0;
        lq_tail <= lq_tail + 1'b1;
      end

      case ({lq_enqueue,lq_response_fire})
        2'b10:
          lq_count <= lq_count + 2'd1;
        2'b01:
          lq_count <= lq_count - 2'd1;
        default:
          lq_count <= lq_count;
      endcase
      case ({lq_issue_fire,lq_response_fire})
        2'b10:
          lq_issued_count <= lq_issued_count + 2'd1;
        2'b01:
          lq_issued_count <= lq_issued_count - 2'd1;
        default:
          lq_issued_count <= lq_issued_count;
      endcase
    end
  end

  // mem_resp_valid 只服务串行 CACOP。普通 load 的完成直接由 LQ
  // response head 回填 WBQ，不再共享单个 mem_req_inflight 状态。
  always @(posedge clk)
  begin
    if (rst || wb_has_exception_commit || wb_do_ertn)
      mem_resp_valid <= 1'b0;
    else
    begin
      // 响应位只属于当前 MEM 的 CACOP。若该 CACOP 已经被边界替换为
      // 普通指令，即使新指令尚未完成、ex2mem_en=0，也不能让旧响应永久
      // 占住 MEM 状态机；否则后续 TLB store 会永远无法开始翻译。
      if (ex2mem_en || !ex2mem_op_cacop ||
          (mem_resp_valid && (mem_resp_pc_q != ex2mem_pc_plus_4_word)))
        mem_resp_valid <= 1'b0;
      if (mem_resp_fire)
      begin
        mem_resp_valid <= 1'b1;
      end
    end
  end



  // ==================== WB：退休、写回、异常与调试提交 ====================

  // WB级退休和写回控制
  wire [31:0] wb_pc_plus_4;
  wire        wb_csr_read_wait;
  wire        wb_csr_commit_en;
  wire [31:0] wb_csr_rdata;
  wire        wb_retire_fire;


  wire wb_csr_write_en=wbq_head_csr_op[1] && !wbq_head_op_tlbrd;


  assign wb_is_csr=(wbq_head_csr_op!=0);
  assign wb_pc_plus_4={wbq_head_pc_plus_4_word,2'b00};
  wire [31:0] wb_csr_write_mask=(wbq_head_csr_op==2'd2)?32'hffff_ffff:wbq_head_csr_rj_data;

  // 写回数据最终选择。load 类别直接复用 WBQ 已有的 op_load_class 标志；只有
  // BL/JIRL 的 PC+4 来源需要额外携带一位控制。
  always@*
  begin
    if(wbq_head_op_store_conditional)
      wb_gpr_wdata={31'b0, wbq_head_sc_success};
    else if(wb_is_csr)
      wb_gpr_wdata=wb_csr_old_data_q;
    else if(wbq_head_gpr_wdata_from_pc4)
      wb_gpr_wdata=wb_pc_plus_4;
    else if(wbq_head_op_load_class)
      wb_gpr_wdata=wb_load_data;
    else
      wb_gpr_wdata=wbq_head_result;
  end
  wire mon_wb_load_word = wbq_head_op_load_class && !mon_wb_ldb && !mon_wb_ldh && !mon_wb_ldbu && !mon_wb_ldhu;
  wire mon_wb_store_word = wbq_head_op_store_class && !mon_wb_sth && !mon_wb_stb;
  wire mon_wb_load_commit = mon_wb_valid && (wbq_head_op_load_class || mon_wb_ldb || mon_wb_ldh || mon_wb_ldbu || mon_wb_ldhu) && !wb_has_exception_commit_raw;
  wire mon_wb_store_commit = mon_wb_valid && wbq_head_op_store_class && !wb_has_exception_commit_raw;
  wire [7:0] wb_load_diff_en = {2'b0, 1'b0, mon_wb_load_word, mon_wb_ldhu, mon_wb_ldh, mon_wb_ldbu, mon_wb_ldb} & {8{mon_wb_load_commit}};
  wire [7:0] wb_store_diff_en = {4'b0, 1'b0, mon_wb_store_word, mon_wb_sth, mon_wb_stb} & {8{mon_wb_store_commit}};
  wire wb_cnt_inst = (mon_wb_inst[31:10] == 22'h18 && (mon_wb_inst[9:5] == 5'b0 || mon_wb_inst[4:0] == 5'b0)) ||
       (mon_wb_inst[31:10] == 22'h19 && mon_wb_inst[9:5] == 5'b0);
  wire wb_tlbfill_inst = (mon_wb_inst[31:26] == 6'h01) && (mon_wb_inst[25:22] == 4'h9) &&
       (mon_wb_inst[19:15] == 5'h10) && (mon_wb_inst[14:10] == 5'h0d);
  wire wb_csr_rstat_en = wb_is_csr && (wbq_head_csr_num == 14'h0005) && !wb_has_exception_commit_raw;

  // 不允许组合 D-cache 响应在同一拍将已满 store buffer 的 slot 回收到退休路径。
  // 该捷径从 cache tag BRAM 经 data_ok、WB 退休、前端 credit 一直连接到 PC
  // 时钟使能（90 MHz 下共 23 级逻辑）。等待已寄存的 sb_count 更新，只在
  // 四项 SB 完全占满时增加一拍，并能干净地切断全局控制路径。
  wire wb_store_wait = wbq_head_ready && wbq_head_op_store_class &&
       !wb_has_exception_commit_raw && sb_full;
  assign wb_csr_read_wait=wbq_head_ready&&wb_is_csr&&
         !wb_has_exception_commit_raw&&!wb_csr_read_valid_q;
  assign wb_retire_fire = wbq_head_ready && !wb_csr_read_wait &&
         !wb_store_wait;
  assign wbq_pop=wb_retire_fire;
  assign sb_enqueue=wb_retire_fire&&wbq_head_op_store_class&&
         !wb_has_exception_commit_raw;
  assign wb_csr_commit_en=wb_csr_write_en&&wb_retire_fire&&
         !wb_has_exception_commit_raw&&!wb_do_ertn_raw;
  assign wb_gpr_we=wbq_head_gpr_write_en&&wb_retire_fire&&
         !wb_has_exception_commit_raw;
  // WB 级只在退休队首 ready 时产生一次架构可见副作用。
  assign wb_do_ertn_raw=wbq_head_op_ertn;
  assign wb_has_exception_commit_raw=wbq_head_has_exception;
  wire wb_ll_commit = wb_retire_fire && wbq_head_op_load_linked &&
       !wb_has_exception_commit_raw;
  wire wb_sc_commit = wb_retire_fire && wbq_head_op_store_conditional &&
       !wb_has_exception_commit_raw;
  wire wb_llbit_set = wb_ll_commit;
  wire wb_llbit_clear = wb_sc_commit;
  wire wb_tlbrd_commit=wbq_head_op_tlbrd&&!wb_has_exception_commit_raw&&wb_retire_fire;
  wire wb_invtlb_commit=wbq_head_op_invtlb&&!wb_has_exception_commit_raw&&wb_retire_fire;
  // ertn/异常项不依赖 CSR 旧值读取，也不会把 faulting store 放入 SB，
  // 因而可直接由 ready 队首提交。避免让普通退休的 CSR/SB 等待网络
  // 进入全流水 flush/enable 的高扇出路径。
  assign wb_do_ertn=wb_do_ertn_raw&&wbq_head_ready;
  assign wb_has_exception_commit=wb_has_exception_commit_raw&&wbq_head_ready;
  assign wb_is_adef_exception=wbq_head_has_exception&&(wbq_head_exc_ecode==ECODE_ADE);

  // BADV/ERA 相关地址选择：取指异常使用指令 PC，访存/TLB/ALE 使用出错虚地址，
  // 其余异常使用当前指令 PC。
  wire [31:0] wb_exception_pc=wb_is_adef_exception?wbq_head_result:wb_instr_pc;
  wire wb_is_mem_exception = (wbq_head_exc_ecode == ECODE_TLBR || wbq_head_exc_ecode == ECODE_PPI || wbq_head_exc_ecode == ECODE_PIL || wbq_head_exc_ecode == ECODE_PIS || wbq_head_exc_ecode == ECODE_PME) &&
       (wbq_head_op_load_class || wbq_head_op_store_class || wbq_head_op_store_conditional || wbq_head_op_cacop);
  wire wb_is_if_exception = (wbq_head_exc_ecode == ECODE_TLBR || wbq_head_exc_ecode == ECODE_PIF || wbq_head_exc_ecode == ECODE_PPI) && !wb_is_mem_exception;
  wire wb_is_addr_exception = (wbq_head_exc_ecode == ECODE_ALE) || wb_is_mem_exception;
  wire [31:0] wb_exc_vaddr = wb_is_if_exception ? wb_instr_pc :
       (wb_is_addr_exception ? wbq_head_result : wb_pc_plus_4);
  wire [5:0] wb_csr_exc_ecode=wbq_head_exc_ecode;
  wire [8:0] wb_exc_esubcode=wb_is_adef_exception?ESUBCODE_ADEF:9'b0;

  assign wb_instr_pc={wbq_head_pc_plus_4_word,2'b00}-32'd4;
  wire wb_debug_rf_we=wb_gpr_we&&(wbq_head_gpr_waddr!=5'd0);
  wire wb_diff_commit = wb_retire_fire && mon_wb_valid &&
       !wb_has_exception_commit_raw;

  // LoongArch reservation granule 与仓库参考核一致为 16B。LL 无论 cache
  // 属性如何都建立 reservation；SC 无论成功失败都会清除它。
  always @(posedge clk)
  begin
    if (rst)
    begin
      lladdr_valid_q <= 1'b0;
      lladdr_q <= 28'b0;
    end
    else if (wb_sc_commit)
      lladdr_valid_q <= 1'b0;
    else if (wb_ll_commit)
    begin
      lladdr_valid_q <= 1'b1;
      lladdr_q <= wb_mem_paddr[31:4];
    end
    else if (!csr_llbit)
      lladdr_valid_q <= 1'b0;
  end

  // trace debug 输出 WB 指令 PC；写回使能只在实际写 GPR 且尚未发送过 trace 时拉高。
  assign debug_wb_pc       = wb_instr_pc;
  assign debug_wb_rf_we    = {4{wb_debug_rf_we}};
  assign debug_wb_rf_wnum  = wbq_head_gpr_waddr;
  assign debug_wb_rf_wdata = wb_gpr_wdata;
  assign debug_wb_inst     = mon_wb_valid ? mon_wb_inst : 32'b0;

  // 差分测试输出使用 monitor 路径记录的提交信息，避免被流水停顿/旁路信号扰动。
  assign diff_commit_valid = wb_diff_commit;
  assign diff_cnt_inst     = wb_diff_commit && wb_cnt_inst;
  assign diff_timer_64     = mon_wb_timer;
  assign diff_inst_ld_en   = wb_diff_commit ? wb_load_diff_en : 8'b0;
  assign diff_ld_paddr     = mon_wb_mem_paddr;
  assign diff_ld_vaddr     = mon_wb_mem_vaddr;
  assign diff_inst_st_en   = wb_diff_commit ? wb_store_diff_en : 8'b0;
  assign diff_st_paddr     = mon_wb_mem_paddr;
  assign diff_st_vaddr     = mon_wb_mem_vaddr;
  assign diff_st_data      = mon_wb_store_data;
  assign diff_csr_rstat_en = wb_csr_rstat_en;
  assign diff_csr_data     = wb_csr_old_data_q;
  assign diff_excp_valid   = wb_has_exception_commit;
  assign diff_ertn         = wb_do_ertn;
  assign diff_csr_ecode    = wb_csr_exc_ecode;
  assign diff_tlbfill_en   = wb_diff_commit && wb_tlbfill_inst;
  assign diff_tlbfill_index = mon_wb_tlbfill_index;

  // 对可能被仿真 X 污染的 TLB 查询结果做提交前清洗，避免写坏 CSR_TLBIDX。
  wire s1_found_clean;
  assign s1_found_clean = (mem_tlbsrch_found_q === 1'bx) ? 1'b0 : mem_tlbsrch_found_q;
  wire [4:0] s1_index_clean;
  assign s1_index_clean = (^mem_tlbsrch_index_q === 1'bx) ? 5'b0 : mem_tlbsrch_index_q;
  wire [4:0] csr_tlbidx_index_clean;
  assign csr_tlbidx_index_clean = (^csr_tlbidx_index === 1'bx) ? 5'b0 : csr_tlbidx_index;
  wire mem_tlbsrch_commit = ex2mem_op_tlbsrch && wbq_enq &&
       !mem_has_exception_final && !wbq_flush;

  // CSR 模块在 WB 级接受精确异常/ertn/CSR 写入，同时接收 tlbsrch/tlbrd 结果。
  CPU_CSR u_cpu_csr(.clk(clk),.rst(rst),.hw_int_in(hw_int_in),.csr_num(wbq_head_csr_num),.csr_re(wb_is_csr),
                    .csr_wvalue(wbq_head_csr_wdata),.csr_wmask(wb_csr_write_mask),.csr_we(wb_csr_commit_en),
                    .ertn_en(wb_do_ertn),.exc_en(wb_has_exception_commit),.exc_ecode(wb_csr_exc_ecode),.exc_esubcode(wb_exc_esubcode),
                    .exc_pc(wb_exception_pc),.exc_vaddr(wb_exc_vaddr),.exc_code(wbq_head_exc_code),
                    .llbit_set(wb_llbit_set),.llbit_clear(wb_llbit_clear),
                    .has_int(csr_has_int),
                    .csr_rvalue(wb_csr_rdata),.ertn_pc(wb_ertn_pc),.ex_entry(wb_exception_entry),
                    // TLB 指令结果写回 CSR。
                    .tlbsrch_wen(mem_tlbsrch_commit),
                    .tlbsrch_hit(s1_found_clean),
                    .tlbsrch_hit_index(s1_index_clean),
                    .s1_found(mem_tlbsrch_found_q),
                    .tlbrd_we(wb_tlbrd_commit),
                    .tlbrd_e(r_e),
                    .tlbrd_vppn(r_vppn),
                    .tlbrd_ps(r_ps),
                    .tlbrd_asid(r_asid_out),
                    .tlbrd_g(r_g),
                    .tlbrd_ppn0(r_ppn0),
                    .tlbrd_plv0(r_plv0),
                    .tlbrd_mat0(r_mat0),
                    .tlbrd_d0(r_d0),
                    .tlbrd_v0(r_v0),
                    .tlbrd_ppn1(r_ppn1),
                    .tlbrd_plv1(r_plv1),
                    .tlbrd_mat1(r_mat1),
                    .tlbrd_d1(r_d1),
                    .tlbrd_v1(r_v1),
                    // CSR 输出给地址翻译和 TLB 写端口使用。
                    .csr_asid(csr_asid),
                    .csr_tlbehi_vppn(csr_tlbehi_vppn),
                    .csr_tlbidx_index(csr_tlbidx_index),
                    .csr_crmd_da(tc_csr_crmd_da),
                    .csr_crmd_pg(tc_csr_crmd_pg),
                    .csr_crmd_plv(tc_csr_crmd_plv),
                    .csr_crmd_datf(tc_csr_crmd_datf),
                    .csr_crmd_datm(tc_csr_crmd_datm),
                    .csr_dmw0_out(tc_csr_dmw0),
                    .csr_dmw1_out(tc_csr_dmw1),
                    .csr_tlbelo0_out(csr_tlbelo0),
                    .csr_tlbelo1_out(csr_tlbelo1),
                    .csr_tlbidx_out(csr_tlbidx),
                    .csr_tlbehi_out(csr_tlbehi),
                    .csr_tlbrentry_out(),
                    .csr_llbit(csr_llbit),
                    .csr_estat_ecode_out(csr_estat_ecode_out),
                    .diff_csrs(diff_csrs));

  // tlbfill 使用自由运行计数器的低位作为替换索引；tlbwr 使用 CSR_TLBIDX.index。
  // refill 场景需要强制写入有效项，其余情况由 CSR_TLBIDX.NE 控制 entry enable。
  assign mem_tlbfill_index = tlbfill_index_q;
  wire       mem_tlb_write_fire = (ex2mem_op_tlbwr | ex2mem_op_tlbfill) &&
             wbq_enq && !wbq_flush && !mem_has_exception_final;
  wire       mem_tlb_write_e = ex2mem_op_tlbfill && (csr_estat_ecode_out == ECODE_TLBR) ? 1'b1 : !csr_tlbidx[31];

  // TLB：s0 专供取指翻译，s1 供 load/store/CACOP 以及 tlbsrch 共享。
  tlb #(.TLBNUM(32)) u_tlb (
        .clk          (clk),
        .reset        (rst),
        // s0：取指查询端口。
        .s0_en        (fq_launch),
        .s0_vppn      (fq_tlb_vaddr[31:13]),
        .s0_va_bit12  (fq_tlb_vaddr[12]),
        .s0_asid      (csr_asid),
        .s0_found     (s0_found),
        .s0_index     (s0_index),
        .s0_ppn       (s0_ppn),
        .s0_ps        (s0_ps),
        .s0_plv       (s0_plv),
        .s0_mat       (s0_mat),
        .s0_d         (s0_d),
        .s0_v         (s0_v),
        // s1：访存地址翻译和 tlbsrch 共用端口。
        .s1_vppn      (mem_s1_vppn_q),
        .s1_va_bit12  (mem_s1_va_bit12_q),
        .s1_asid      (mem_s1_asid_q),
        .s1_found     (s1_found),
        .s1_index     (s1_index),
        .s1_ppn       (s1_ppn),
        .s1_ps        (s1_ps),
        .s1_plv       (s1_plv),
        .s1_mat       (s1_mat),
        .s1_d         (s1_d),
        .s1_v         (s1_v),
        // invtlb 在 WB 精确提交时生效，参数来自指令源操作数。
        .invtlb_op    (wbq_head_invtlb_op),
        .invtlb_valid (wb_invtlb_commit),
        .invtlb_vppn  (wbq_head_rk_data[31:13]),
        .invtlb_asid  (wbq_head_csr_rj_data[9:0]),
        // tlbwr/tlbfill 写端口，写入字段来自 CSR_TLBEHI/TLBIDX/TLBELO。
        .we           (mem_tlb_write_fire),
        .w_index      (ex2mem_op_tlbfill ? mem_tlbfill_index : csr_tlbidx_index),
        .w_e          (mem_tlb_write_e),
        .w_vppn       (csr_tlbehi[31:13]),
        .w_ps         (csr_tlbidx[29:24]),
        .w_asid       (csr_asid),
        .w_g          (csr_tlbelo0[6] & csr_tlbelo1[6]),
        .w_ppn0       (csr_tlbelo0[27:8]),
        .w_plv0       (csr_tlbelo0[3:2]),
        .w_mat0       (csr_tlbelo0[5:4]),
        .w_d0         (csr_tlbelo0[1]),
        .w_v0         (csr_tlbelo0[0]),
        .w_ppn1       (csr_tlbelo1[27:8]),
        .w_plv1       (csr_tlbelo1[3:2]),
        .w_mat1       (csr_tlbelo1[5:4]),
        .w_d1         (csr_tlbelo1[1]),
        .w_v1         (csr_tlbelo1[0]),
        // tlbrd 读端口，读出的 entry 回写到 CSR。
        .r_index      (csr_tlbidx_index_clean),
        .r_e          (r_e),
        .r_vppn       (r_vppn),
        .r_ps         (r_ps),
        .r_asid       (r_asid_out),
        .r_g          (r_g),
        .r_ppn0       (r_ppn0),
        .r_plv0       (r_plv0),
        .r_mat0       (r_mat0),
        .r_d0         (r_d0),
        .r_v0         (r_v0),
        .r_ppn1       (r_ppn1),
        .r_plv1       (r_plv1),
        .r_mat1       (r_mat1),
        .r_d1         (r_d1),
        .r_v1         (r_v1)
      );


  always@(posedge clk)
  begin
    if(rst||wbq_flush)
    begin
      wb_csr_read_valid_q<=1'b0;
      wb_csr_old_data_q<=32'b0;
    end
    else if(wb_csr_read_wait)
    begin
      wb_csr_read_valid_q<=1'b1;
      wb_csr_old_data_q<=wb_csr_rdata;
    end
    else if(wbq_pop)
      wb_csr_read_valid_q<=1'b0;
  end

  // ==================== 分级重定向与分支预测器更新 ====================

  assign MEM_serial_accept = ex2_commit_fire && ex12ex2_serializing;
  assign WB_serial_retire = wb_retire_fire && wbq_head_serializing &&
         !wb_has_exception_commit_raw;
  // ID 本级的 b/bl 恢复与该指令进入 ID/EX1 同沿发生，因此不能冲刷 ID/EX1；
  // 只有 EX1 及更老级的恢复才会杀死当前 ID 指令。
  assign id2ex1_flush=EX1_back_redirect_valid|id_idle_stall;

  // 串行指令进入 MEM 后保持屏障，直到它精确退休。此时所有年轻指令都被
  // 挡在 EX2/MEM 之前，因此分支恢复不再负责清除屏障。需要重取的操作在
  // 退休沿之后产生一拍 redirect，使新 CSR/TLB/cache 状态先对取指可见。
  always @(posedge clk)
  begin
    if (rst)
      MEM_serial_barrier_q <= 1'b0;
    else
    begin
      if (wb_has_exception_commit || wb_do_ertn)
        MEM_serial_barrier_q <= 1'b0;
      else if (WB_serial_retire)
        MEM_serial_barrier_q <= 1'b0;
      else if (MEM_serial_accept)
        MEM_serial_barrier_q <= 1'b1;
    end
  end
  // -------------------- 分级重定向仲裁 --------------------
  // back 链从最老的 WB 向 ID 逐级合并；同拍多源出现时，越老的来源优先。
  assign EX2_back_redirect_valid = EX2_redirect_valid_q ||
         WB_redirect_valid_q;
  assign EX2_back_redirect_pc = WB_redirect_valid_q ?
         WB_redirect_pc_q : EX2_redirect_pc_q;

  assign EX1_back_redirect_valid = EX1_redirect_valid_q ||
         EX2_back_redirect_valid;
  assign EX1_back_redirect_pc = EX2_back_redirect_valid ?
         EX2_back_redirect_pc : EX1_redirect_pc_q;

  // b/bl 的目标在 ID 已知。只有 ID 能正常进入 EX1 时才重定向；该沿 ID/EX1
  // 保存跳转本身，IF/ID 和取指队列清除其后的年轻路径。
  assign ID_redirect_valid = id_is_direct_branch &&
         (id_pred_next_pc != id_direct_target) &&
         !pipeline_wait && !ex1_data_wait && !id_idle_stall &&
         !EX1_back_redirect_valid &&
         !(wb_has_exception_commit || wb_do_ertn);
  assign ID_redirect_pc = id_direct_target;

  assign ID_back_redirect_valid = ID_redirect_valid ||
         EX1_back_redirect_valid;
  assign ID_back_redirect_pc = EX1_back_redirect_valid ?
         EX1_back_redirect_pc : ID_redirect_pc;

  // 条件分支的两个源数就绪后可在 EX1 提前比较，无需再等到 EX2 的通用
  // ALU/比较器。load-use 等操作数未就绪时不采样；若只是后端反压，则仅
  // 锁存已确认的误预测，等流水线恢复推进后再发出 redirect。
  wire ex1_is_cond_branch = id2ex1_op_beq || id2ex1_op_bne || id2ex1_op_blt ||
       id2ex1_op_bge || id2ex1_op_bltu || id2ex1_op_bgeu;
  // 使用 EX1 已有的寄存旁路结果做条件比较。普通 ALU、MEM 和已经写入
  // WBQ ready/data 寄存器的生产者在这里提前解析；本拍刚返回的 load
  // 仍只进入通用 ex1_alu_a/ex1_rk_value，并随流水寄存器交给 EX2 精确恢复。
  // 专用分支 mux 特意省略通用 WB/CSR 结果 mux。每个尚未 pop 的 WB 生产者也会
  // 由逐 GPR 的 WBQ scoreboard 表示，因此 EX2/MEM/WBQ-ready 能以短得多的
  // 逻辑锥覆盖有用情况。如果该 WBQ 值尚未 ready，
  // ex1_cond_wbq_unregistered_dep 会使分支保持等待。
  wire [31:0] ex1_branch_a_fast =
       (id2ex1_uses_rj && (id2ex1_rj_addr == ex12ex2_gpr_waddr) && ex2_bypass_en) ?
       ex2_forward_data :
       ((id2ex1_uses_rj && (id2ex1_rj_addr == ex2mem_gpr_waddr) && mem_bypass_en) ? mem_bypass_data : ex1_rj_base);
  wire [31:0] ex1_branch_b_fast =
       (id2ex1_uses_rk && (id2ex1_rk_addr == ex12ex2_gpr_waddr) && ex2_bypass_en) ?
       ex2_forward_data :
       ((id2ex1_uses_rk && (id2ex1_rk_addr == ex2mem_gpr_waddr) && mem_bypass_en) ? mem_bypass_data : ex1_rk_base);
  wire ex1_branch_equal = (ex1_branch_a_fast == ex1_branch_b_fast);
  wire ex1_branch_signed_lt =
       ($signed(ex1_branch_a_fast) < $signed(ex1_branch_b_fast));
  wire ex1_branch_unsigned_lt = (ex1_branch_a_fast < ex1_branch_b_fast);
  wire ex1_cond_taken = (id2ex1_op_beq  && ex1_branch_equal) ||
       (id2ex1_op_bne  && !ex1_branch_equal) ||
       (id2ex1_op_blt  && ex1_branch_signed_lt) ||
       (id2ex1_op_bge  && !ex1_branch_signed_lt) ||
       (id2ex1_op_bltu && ex1_branch_unsigned_lt) ||
       (id2ex1_op_bgeu && !ex1_branch_unsigned_lt);
  // EX1 只比较预测方向，避免把“操作数比较”和“32 位 next-PC 比较”
  // 两条 carry chain 串在同一拍。若方向正确但 BTB 目标陈旧，EX2 的
  // 完整 next-PC 比较仍会在下一拍精确恢复。
  wire ex1_cond_direction_mispredict =
       (ex1_cond_taken != id2ex1_pred_taken);
  // 只有方向不匹配时才会使用该地址。此时实际方向必然是预测方向的反相，
  // 因此恢复地址可以直接由预测方向反推，而不再由比较器结果驱动 32 位
  // redirect_pc_q 的 D 输入。地址寄存器在条件分支可解析时捕获候选值，
  // 比较结果只控制标量 redirect valid/pending 状态。
  wire [31:0] ex1_cond_redirect_pc = id2ex1_pred_taken ?
       {id2ex1_pc_plus_4_word,2'b00} : {id2ex1_branch_target_word,2'b00};
  // 实时 load 响应会立即使通用操作数路径 ready，因此分支可在没有 load-use
  // bubble 的情况下推进到 EX2。但早期分支解析会等待所有 WBQ 操作数通过
  // 已寄存 scoreboard 可见，从而使响应数据及 response-valid 控制都不进入
  // EX1 redirect 锥。ID 快照覆盖已在 WBQ 中的生产者和当前 MEM 生产者。
  // 如果分支在 ID 中多停留数拍，仍可能有生产者在快照之后进入 WBQ。
  // 在 EX1 中只重新检查逐 GPR 的 slot valid 位。分支比较器不会选择 WBQ
  // ready/data 或退休结果，因此这只是窄范围正确性保护，而非原先的全局数据锥。
  wire ex1_cond_wbq_unregistered_dep = ex1_is_cond_branch &&
       (id2ex1_branch_wbq_dep ||
        (id2ex1_uses_rj && (id2ex1_rj_addr != 5'd0) && (|ex1_rj_wbq_slots)) ||
        (id2ex1_uses_rk && (id2ex1_rk_addr != 5'd0) && (|ex1_rk_wbq_slots)));
  wire ex1_cond_exmem_wait = ex1_is_cond_branch &&
       (ex1_rj_ex_late || ex1_rk_ex_late ||
        ex1_rj_mem_load || ex1_rk_mem_load ||
        ex1_rj_mem_csr || ex1_rk_mem_csr ||
        ex1_rj_mem_sc_pending || ex1_rk_mem_sc_pending);
  // Resolve 不等待 MEM/WBQ backpressure。预测正确不需要保存任何状态；只有
  // 已确认的误预测在 EX1 被阻塞时锁存，待流水线恢复推进后发出一次 redirect。
  wire ex1_cond_resolve_fire = id2ex1_valid && ex1_is_cond_branch &&
       !id2ex1_has_exception && !ex1_cond_exmem_wait &&
       !ex1_cond_wbq_unregistered_dep &&
       !MEM_serial_barrier_q && !MEM_serial_accept &&
       !EX1_redirect_pending_q;

  always @(posedge clk)
  begin
    if (rst || wb_has_exception_commit || wb_do_ertn)
    begin
      EX1_redirect_valid_q <= 1'b0;
      EX1_redirect_pc_q <= 32'b0;
      EX1_redirect_pending_q <= 1'b0;
    end
    else if (EX1_back_redirect_valid)
    begin
      EX1_redirect_valid_q <= 1'b0;
      EX1_redirect_pending_q <= 1'b0;
    end
    else
    begin
      EX1_redirect_valid_q <= 1'b0;
      if (EX1_redirect_pending_q)
      begin
        // 误预测目标已在后端阻塞期间保存；流水线恢复推进时只发出一次恢复。
        if (id2ex1_en)
        begin
          EX1_redirect_pending_q <= 1'b0;
          // 若本拍恰有更老串行指令进入 MEM，该分支也会进入 EX2 并被屏障
          // 保持；让 EX2 在屏障解除后做精确恢复，避免提前恢复后重复触发。
          if (!MEM_serial_accept)
            EX1_redirect_valid_q <= 1'b1;
        end
      end
      else if (ex1_cond_resolve_fire)
      begin
        // 候选恢复地址与误预测判定分离。即使方向预测正确，也只捕获地址，
        // 不产生 redirect；这样 redirect_pc_q 的 32 位 CE/D 路径不再由比较器
        // 结果控制，误预测结果只进入下面的标量 valid/pending 控制。
        EX1_redirect_pc_q <= ex1_cond_redirect_pc;
        if (ex1_cond_direction_mispredict)
        begin
          // E006d：E006c 已从 D-cache 请求锥中移除全局 WBQ/LQ 资格判断。
          // 流水线可推进时恢复原先无额外周期的分支释放；只有较早 MEM 操作确实
          // 将该分支阻塞在 EX1 时，才保存待处理的 redirect。
          if (pipeline_wait)
            EX1_redirect_pending_q <= 1'b1;
          else
            EX1_redirect_valid_q <= 1'b1;
        end
      end
    end
  end


  // EX2 只在预测错误时产生恢复；正确预测的 taken 分支不再冲刷前端。
  always @(posedge clk)
  begin
    if(rst||wb_has_exception_commit||wb_do_ertn)
    begin
      EX2_redirect_valid_q<=1'b0;
      EX2_redirect_pc_q<=32'b0;
    end
    else if(EX2_back_redirect_valid)
    begin
      EX2_redirect_valid_q<=1'b0;
      if (WB_redirect_valid_q)
        EX2_redirect_pc_q<=32'b0;
    end
    else if(EX1_redirect_valid_q)
    begin
      // EX1 已对当前 EX2 条件分支完成方向恢复，避免 EX2 对同一错误重复恢复。
      EX2_redirect_valid_q<=1'b0;
      EX2_redirect_pc_q<=32'b0;
    end
    else if(ex2mem_en)
    begin
      // 非控制长运算也可能命中陈旧 BTB。必须等该指令真正越过
      // EX2/MEM 才锁存恢复，否则 MUL/DIV 等待期会先 redirect，再把
      // 产生恢复的指令自身 kill 掉。
      EX2_redirect_valid_q<=ex2_mispredict&&ex2_commit_fire;
      EX2_redirect_pc_q<=ex2_actual_next_pc;
    end
  end


  assign if2id_flush=ID_back_redirect_valid;
  // 预测器只在 EX2 指令结果有效且没有被更老异常冲刷时训练。RAS 采用
  // “解析后更新”的保守方案，不需要为推测 push/pop 保存恢复检查点；
  // 极短函数可能少命中一次，但任何错误都由下一 PC 比较精确恢复。
  // 只有 EX2 真正越过 EX2/MEM 边界时才训练一次。若较老 MEM 操作反压，
  // 同一分支会在 EX2 保持多拍；不能每拍重复饱和计数器或 push/pop RAS。
  wire bp_resolve_fire = ex2_commit_fire && !ex2_has_exception_in;
  assign ex2_current_pc = {ex12ex2_pc_plus_4_word - 30'd1,2'b00};
  wire [6:0] ex2_bp_index = ex2_current_pc[8:2];
  wire ex2_btb_entry_match = btb_valid[ex2_bp_index] &&
       (btb_tag[ex2_bp_index] == ex2_current_pc[31:9]);
  wire [2:0] ex2_bp_type = ex2_is_cond_branch ? BP_TYPE_COND :
       ex12ex2_is_call ? BP_TYPE_CALL :
       ex12ex2_is_return ? BP_TYPE_RETURN :
       ex2_is_direct_branch ? BP_TYPE_DIRECT :
       BP_TYPE_INDIRECT;
  wire [31:0] ex2_bp_target = ex2_op_jirl ? ex2_addr_result :
       {ex12ex2_branch_target_word,2'b00};
  wire [4:0] ex2_branch_pattern = branch_pattern[ex2_bp_index];
  wire [1:0] ex2_pattern_counter = ex12ex2_pred_history ?
       ex2_branch_pattern[3:2] :
       ex2_branch_pattern[1:0];
  wire [1:0] ex2_pattern_next =
       (ex2_actual_taken && (ex2_pattern_counter != 2'b11)) ?
       (ex2_pattern_counter + 2'b01) :
       (!ex2_actual_taken && (ex2_pattern_counter != 2'b00)) ?
       (ex2_pattern_counter - 2'b01) : ex2_pattern_counter;
  reg [4:0] ex2_branch_pattern_next;
  always @(*)
  begin
    ex2_branch_pattern_next = ex2_branch_pattern;
    ex2_branch_pattern_next[4] = ex2_actual_taken;
    if (ex12ex2_pred_history)
      ex2_branch_pattern_next[3:2] = ex2_pattern_next;
    else
      ex2_branch_pattern_next[1:0] = ex2_pattern_next;
  end

  integer bp_i;
  always @(posedge clk)
  begin
    if (rst)
    begin
      ras_sp <= 4'b0;
      ras_count <= 5'b0;
      bp_update_valid_q <= 1'b0;
      bp_update_control_q <= 1'b0;
      bp_update_call_q <= 1'b0;
      bp_update_return_q <= 1'b0;
      bp_update_index_q <= 7'b0;
      bp_update_tag_q <= 23'b0;
      bp_update_target_q <= 32'b0;
      bp_update_fallthrough_q <= 32'b0;
      bp_update_type_q <= BP_TYPE_COND;
      for (bp_i = 0; bp_i < BP_ENTRIES; bp_i = bp_i + 1)
      begin
        btb_valid[bp_i] = 1'b0;
        branch_pattern[bp_i] = 5'b00101;
      end
    end
    else
    begin
      bp_update_valid_q <= bp_resolve_fire &&
                        (ex2_is_control ||
                         (ex2_mispredict && !ex2_is_control &&
                          ex2_btb_entry_match));
      if (bp_resolve_fire)
      begin
        bp_update_control_q <= ex2_is_control;
        bp_update_call_q <= ex12ex2_is_call;
        bp_update_return_q <= ex12ex2_is_return;
        bp_update_index_q <= ex2_bp_index;
        bp_update_tag_q <= ex2_current_pc[31:9];
        bp_update_target_q <= ex2_bp_target;
        bp_update_fallthrough_q <= ex2_fallthrough_pc;
        bp_update_type_q <= ex2_bp_type;
      end

      if (bp_resolve_fire && ex2_is_cond_branch)
        branch_pattern[ex2_bp_index] <= ex2_branch_pattern_next;

      // 异常/ertn 会改变控制流上下文，清空 RAS 可避免跨上下文使用旧栈。
      if (wb_has_exception_commit || wb_do_ertn)
      begin
        ras_sp <= 4'b0;
        ras_count <= 5'b0;
      end
      else if (bp_update_valid_q && bp_update_control_q && bp_update_call_q)
      begin
        ras_stack[ras_sp] <= bp_update_fallthrough_q;
        ras_sp <= ras_sp + 4'd1;
        if (ras_count < BP_RAS_DEPTH)
          ras_count <= ras_count + 5'd1;
      end
      else if (bp_update_valid_q && bp_update_control_q &&
               bp_update_return_q && (ras_count != 0))
      begin
        ras_sp <= ras_sp - 4'd1;
        ras_count <= ras_count - 5'd1;
      end

      if (bp_update_valid_q && bp_update_control_q &&
          !(wb_has_exception_commit || wb_do_ertn))
      begin
        btb_valid[bp_update_index_q] <= 1'b1;
        btb_tag[bp_update_index_q] <= bp_update_tag_q;
        btb_target[bp_update_index_q] <= bp_update_target_q;
        btb_type[bp_update_index_q] <= bp_update_type_q;
      end
      else if (bp_update_valid_q && !bp_update_control_q &&
               !(wb_has_exception_commit || wb_do_ertn))
      begin
        // 自修改代码或同一索引被错误类型污染时，普通指令会主动清除陈旧项。
        btb_valid[bp_update_index_q] <= 1'b0;
      end
    end
  end

  // ==================== 全局反压、流水线使能与监控流水 ====================

  assign id_wait_ifq = !ifq_head_valid;
  wire mem_stage_wait = ex2mem_valid &&
       !(mem_stage_complete && wbq_has_space) &&
       !(wb_has_exception_commit||wb_do_ertn);
  assign mem_backpressure=mem_stage_wait;
  assign id_idle_stall=id_valid&&id_op_idle&&!id_has_exception&&!csr_has_int;
  wire ex2_long_wait=ex2_long_exec&&!ex2_long_finish;
  wire ex2_result_ready=ex12ex2_valid&&!(ex2_long_exec&&!ex2_long_finish)&&
       !EX2_back_redirect_valid&&!(wb_has_exception_commit||wb_do_ertn);
  // MEM 串行屏障有效时，EX2 中的年轻指令可以保持和预计算，但不能被视为
  // 真正越过 EX2/MEM；这同时禁止重复训练预测器或消费长运算结果。
  assign ex2_commit_fire=ex2_result_ready&&!mem_backpressure&&
         !MEM_serial_barrier_q;
  assign ex2_result_take=ex2_commit_fire&&ex2_long_exec;
  wire ex2_stage_wait=ex2_long_wait;
  assign pipeline_wait=mem_backpressure||ex2_stage_wait||MEM_serial_barrier_q;

  // 乘除单元只在 EX 操作数已锁存、后端没有额外等待且结果未占用时启动。
  // MEM 串行屏障期间，EX2 中的年轻除法指令只保持，不启动除法器内部状态。
  assign ex2_div_start_en=ex2_long_exec&&!mem_backpressure&&
         !MEM_serial_barrier_q&&!ex2_long_kill;

  // 全局流水线使能/冲刷优先级：
  // 1. WB 异常/ertn 立即改 PC 并冲刷后端；
  // 2. 访存/CSR/长运算等待时整体暂停；
  // 3. 数据相关或乘除启动时插入气泡；
  // 4. 前端无指令时只允许 IF/ID 维持泡泡向后流动。
  always@*
  begin
    // 取指 PC 与后端停顿解耦；只要完成队列有空间就继续预取。
    // 异常/ertn/分支重定向仍具有最高优先级。
    fq_pc_en=ID_back_redirect_valid||FT_redirect_injected_q||fq_launch;
    if(wb_has_exception_commit||wb_do_ertn)
    begin
      if2id_en=1;
      id2ex1_en=1;
      ex2mem_flush=1;
    end
    else if(ID_back_redirect_valid)
    begin
      // 分支恢复不能被一个同时发生的年轻指令数据等待遮蔽；否则该
      // 年轻错误路径指令会留在 ID/EX1，并可能最终进入 WBQ。
      if2id_en=1;
      id2ex1_en=1;
      // EX2/WB 的恢复比当前 EX2 指令更老，需要清 EX2/MEM；ID/EX1 的恢复
      // 通常不能杀死较老 EX2，但 MEM 串行屏障仍必须阻止任何年轻项进入 MEM。
      ex2mem_flush=EX2_back_redirect_valid||
                  (MEM_serial_barrier_q&&!mem_backpressure);
    end
    else if(pipeline_wait)
    begin
      if2id_en=0;
      id2ex1_en=0;
      // 长运算或 MEM 串行屏障只保持 EX1/EX2；若 MEM 本身可接收，则让较老
      // MEM 指令进入完成队列，并向 EX2/MEM 写入气泡，不能让年轻 EX2 顶替。
      ex2mem_flush=(ex2_long_wait||MEM_serial_barrier_q)&&!mem_backpressure;
    end
    else if(ex1_data_wait)
    begin
      if2id_en=0;
      id2ex1_en=0;
      ex2mem_flush=0;
    end
    else if(id_idle_stall)
    begin
      // IDLE 留在 ID 等中断；较老 EX1 只前进一次，ID/EX1 写入气泡。
      if2id_en=0;
      id2ex1_en=1;
      ex2mem_flush=0;
    end
    else if(id_wait_ifq)
    begin
      if2id_en=1;
      id2ex1_en=1;
      ex2mem_flush=0;
    end
    else
    begin
      if2id_en=1;
      id2ex1_en=1;
      ex2mem_flush=0;
    end
  end

  // EX1/EX2 和 EX2/MEM 同步推进。晚结果相关只在 EX1/EX2 注入一个气泡，
  // 让较老的 EX2 指令继续前进；长运算和后端反压才保持两级寄存器。
  // EX1 本级及更老 redirect 只杀更年轻的 EX1/ID。若 EX2 正被 MEM 反压，
  // 不能强制写 EX1/EX2 再把产生 redirect、但尚未提交的分支自身清掉。
  // EX2_redirect_valid_q 已经表示产生恢复的指令进入 MEM；此时 EX2 一定是
  // 年轻错路径，即使它自身是未完成的长运算，也必须使能边界并清成气泡。
  // WB 异常/ertn 属于更老的精确事件，仍可无条件冲刷 EX2。
  // WB 串行重取也必须让 EX1/EX2 边界在 flush=1 时真正写入气泡；否则
  // pipeline_wait 会令 En=0，旧的年轻指令被保留并在重定向后重复提交。
  assign ex12ex2_en=wb_has_exception_commit||wb_do_ertn||EX2_back_redirect_valid||
         !pipeline_wait;
  assign ex12ex2_flush=wb_has_exception_commit||wb_do_ertn||EX1_back_redirect_valid||
         ex1_data_wait;

  // 差分测试 monitor 路径：镜像指令在流水线中的移动，只记录提交所需信息，
  // 不参与控制或数据旁路。
  always@(posedge clk)
  begin
    if(rst)
    begin
      {mon_ex1_inst,mon_ex1_timer,mon_ex1_ldb,mon_ex1_ldh,mon_ex1_ldbu,mon_ex1_ldhu,mon_ex1_stb,mon_ex1_sth}<=0;
    end
    else if(id2ex1_en)
    begin
      if(id2ex1_flush)
        {mon_ex1_inst,mon_ex1_timer,mon_ex1_ldb,mon_ex1_ldh,mon_ex1_ldbu,mon_ex1_ldhu,mon_ex1_stb,mon_ex1_sth}<=0;
      else
      begin
        mon_ex1_inst<=id_instr;
        mon_ex1_timer<=stable_counter_q;
        mon_ex1_ldb<=id_op_load_byte;
        mon_ex1_ldh<=id_op_load_half;
        mon_ex1_ldbu<=id_op_load_byte_unsigned;
        mon_ex1_ldhu<=id_op_load_half_unsigned;
        mon_ex1_stb<=id_op_store_byte;
        mon_ex1_sth<=id_op_store_half;
      end
    end
  end

  always@(posedge clk)
  begin
    if(rst)
    begin
      {mon_ex2_inst,mon_ex2_timer,mon_ex2_ldb,mon_ex2_ldh,mon_ex2_ldbu,mon_ex2_ldhu,mon_ex2_stb,mon_ex2_sth}<=0;
    end
    else if(ex12ex2_en)
    begin
      if(ex12ex2_flush)
        {mon_ex2_inst,mon_ex2_timer,mon_ex2_ldb,mon_ex2_ldh,mon_ex2_ldbu,mon_ex2_ldhu,mon_ex2_stb,mon_ex2_sth}<=0;
      else
      begin
        mon_ex2_inst<=mon_ex1_inst;
        mon_ex2_timer<=mon_ex1_timer;
        mon_ex2_ldb<=mon_ex1_ldb;
        mon_ex2_ldh<=mon_ex1_ldh;
        mon_ex2_ldbu<=mon_ex1_ldbu;
        mon_ex2_ldhu<=mon_ex1_ldhu;
        mon_ex2_stb<=mon_ex1_stb;
        mon_ex2_sth<=mon_ex1_sth;
      end
    end
  end

  always@(posedge clk)
  begin
    if(rst)
    begin
      {mon_mem_inst,mon_mem_timer,mon_mem_ldb,mon_mem_ldh,mon_mem_ldbu,mon_mem_ldhu,mon_mem_stb,mon_mem_sth}<=0;
    end
    else if(ex2mem_en)
    begin
      if(ex2mem_flush)
        {mon_mem_inst,mon_mem_timer,mon_mem_ldb,mon_mem_ldh,mon_mem_ldbu,mon_mem_ldhu,mon_mem_stb,mon_mem_sth}<=0;
      else
      begin
        mon_mem_inst<=mon_ex2_inst;
        mon_mem_timer<=ex2_commit_fire ? stable_counter_q : mon_ex2_timer;
        mon_mem_ldb<=mon_ex2_ldb;
        mon_mem_ldh<=mon_ex2_ldh;
        mon_mem_ldbu<=mon_ex2_ldbu;
        mon_mem_ldhu<=mon_ex2_ldhu;
        mon_mem_stb<=mon_ex2_stb;
        mon_mem_sth<=mon_ex2_sth;
      end
    end
  end


  // MEM 的推进不受 EX2 长运算或串行屏障等待牵连；只有 MEM 自身未完成时
  // 才保持。年轻 EX2 被保持而 MEM 可以离开时，ex2mem_flush 向该边界写气泡。
  // 分支恢复只能杀 EX2 及更年轻级；若 redirecting 指令自身仍在 MEM
  // 翻译/等待，必须尊重 MEM 反压，不能强制覆盖它。
  assign ex2mem_en=wb_has_exception_commit||wb_do_ertn||!mem_backpressure;

`ifdef SIMULATION
  // MEM 串行屏障的核心不变量：屏障建立后，MEM 只能保存该串行指令或气泡；
  // EX2 不能提交，MEM 离开时也必须清成气泡，不能装入年轻指令。
  always @(posedge clk)
  begin
    if (!rst && MEM_serial_barrier_q && ex2_commit_fire)
    begin
      $display("SERIAL_BARRIER_EX2_COMMIT pc=%08x", ex2_current_pc);
      $fatal(1, "SERIAL_BARRIER_EX2_COMMIT");
    end
    if (!rst && MEM_serial_barrier_q && ex2mem_valid && !ex2mem_serializing)
    begin
      $display("SERIAL_BARRIER_YOUNG_MEM pc=%08x", {ex2mem_pc_plus_4_word - 30'd1,2'b00});
      $fatal(1, "SERIAL_BARRIER_YOUNG_MEM");
    end
    if (!rst && MEM_serial_barrier_q && ex2mem_en && !ex2mem_flush &&
        !(wb_has_exception_commit || wb_do_ertn))
    begin
      $display("SERIAL_BARRIER_EXMEM_NOT_BUBBLE");
      $fatal(1, "SERIAL_BARRIER_EXMEM_NOT_BUBBLE");
    end
  end

  // 仿真一致性检查：若完整的 store 扫描发现字节重叠，快速哈希也必须命中。
  always @(posedge clk)
  begin
    if (!rst && ex2mem_valid && ex2mem_op_load_class && mem_xlate_ready &&
        mem_xlate_cached_eff && !mem_has_exception_final &&
        ((mem_load_forward_mask & mem_load_need_mask) != 4'b0) &&
        !mem_load_store_hash_match)
    begin
      $display("STORE_HASH_FALSE_NEGATIVE pc=%08x paddr=%08x hash=%02x sb_count=%0d wbq_count=%0d wbq_store_count=%0d",
               {ex2mem_pc_plus_4_word - 30'd1,2'b00}, mem_xlate_paddr_eff,
               mem_xlate_paddr_eff[7:2], sb_count, wbq_count,
               wbq_store_count);
      $fatal(1, "STORE_HASH_FALSE_NEGATIVE");
    end
  end
`endif

endmodule



// =============================================================================
// 最小 PC 寄存器
// =============================================================================
// 复位入口为 NSCSCC SoC 约定的 0x1c000000。Next_PC 已由 CPU_top 按异常、ERTN、
// 串行重取、分支恢复和预测的优先级选好；本模块只负责在 PC_En 时锁存。
// PC_En=0 表示前端无 credit 或需要保持翻译/请求 payload，Current_PC 必须稳定。
module PC(
    input clk,                  // PC 状态时钟。
    input rst,                  // 高有效同步复位。
    input PC_En,                // PC 写使能；为 0 时保持当前地址。
    input [31:0] Next_PC,       // 顶层完成优先级选择后的下一字节地址。
    output reg [31:0] Current_PC// 当前送往预测器/取指翻译级的字节地址。
  );

  always @(posedge clk)
  begin
    if(rst)
      Current_PC<=32'h1c000000;
    else if(PC_En)
      Current_PC<=Next_PC;
  end

endmodule
