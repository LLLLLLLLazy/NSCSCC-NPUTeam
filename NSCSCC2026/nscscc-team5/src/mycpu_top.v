// =============================================================================
// SoC 可见封装、CPU/cache 层次与 AXI 主机桥
// =============================================================================
// 本文件包含三个模块：
//   core_top          —— 兼容工程顶层命名/调试端口的薄封装；
//   mycpu_top         —— 实例化 CPU_top、存储层次和可选差分测试监视器；
//   sram_axi_bridge_2x1 —— 在 I/D 类 SRAM 接口、L1/L2 cache 与 AXI4 间转换。
//
// 数据路径层次为 CPU -> 私有 I/D L1 -> 统一 clean L2 -> AXI。CPU 根据地址翻译
// 得到的 MAT 输出 cached 属性；uncached/MMIO 请求绕过 cache 直接进入 AXI。
// =============================================================================

// core_top 仅重命名 trace 信号。break_point/infor_flag/reg_num/ws_valid/rf_rdata
// 属于旧调试接口，本实现不使用，保留端口是为了兼容既有 SoC 工程约束。
module core_top(
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [ 7:0] intrpt,

    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    input  wire        break_point,
    input  wire        infor_flag,
    input  wire [ 4:0] reg_num,
    output wire        ws_valid,
    output wire [31:0] rf_rdata,

    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata,
    output wire [31:0] debug0_wb_inst
  );

  wire [3:0] debug_wb_rf_we;

  // 未实现旧版“任意寄存器观察”窗口；正式 trace 使用 debug0_wb_* 接口。
  assign ws_valid = 1'b0;
  assign rf_rdata = 32'b0;
  assign debug0_wb_rf_wen = debug_wb_rf_we;

  mycpu_top u_mycpu_top(
    .aclk              (aclk),
    .aresetn           (aresetn),
    .intrpt            (intrpt),
    .arid              (arid),
    .araddr            (araddr),
    .arlen             (arlen),
    .arsize            (arsize),
    .arburst           (arburst),
    .arlock            (arlock),
    .arcache           (arcache),
    .arprot            (arprot),
    .arvalid           (arvalid),
    .arready           (arready),
    .rid               (rid),
    .rdata             (rdata),
    .rresp             (rresp),
    .rlast             (rlast),
    .rvalid            (rvalid),
    .rready            (rready),
    .awid              (awid),
    .awaddr            (awaddr),
    .awlen             (awlen),
    .awsize            (awsize),
    .awburst           (awburst),
    .awlock            (awlock),
    .awcache           (awcache),
    .awprot            (awprot),
    .awvalid           (awvalid),
    .awready           (awready),
    .wid               (wid),
    .wdata             (wdata),
    .wstrb             (wstrb),
    .wlast             (wlast),
    .wvalid            (wvalid),
    .wready            (wready),
    .bid               (bid),
    .bresp             (bresp),
    .bvalid            (bvalid),
    .bready            (bready),
    .debug_wb_pc       (debug0_wb_pc),
    .debug_wb_rf_we    (debug_wb_rf_we),
    .debug_wb_rf_wnum  (debug0_wb_rf_wnum),
    .debug_wb_rf_wdata (debug0_wb_rf_wdata),
    .debug_wb_inst     (debug0_wb_inst)
  );

endmodule

// =============================================================================
// CPU 子系统顶层
// =============================================================================
// 所有逻辑使用 aclk。外部 aresetn 为低有效，转换成 CPU_top 所需的高有效同步
// reset；cache/bridge 继续使用 aresetn。AXI 五通道遵循 valid 保持到 ready 的
// 规则，读 burst 的 RLAST 用来释放本地上下文。
module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [ 7:0] intrpt,

    // AXI 读地址通道
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    // AXI 读数据通道
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    // AXI 写地址通道
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    // AXI 写数据通道
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    // AXI 写响应通道
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // trace 调试接口
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [31:0] debug_wb_inst
  );

  // CPU_top 的指令/数据类 SRAM 端口。cached=1 选 cache，0 选 bypass。
  wire        inst_sram_req;
  wire        inst_sram_wr;
  wire [1:0]  inst_sram_size;
  wire [3:0]  inst_sram_wstrb;
  wire [31:0] inst_sram_addr;
  wire [31:0] inst_sram_wdata;
  wire        inst_sram_cached;
  wire        inst_sram_addr_ok;
  wire        inst_sram_data_ok;
  wire [31:0] inst_sram_rdata;

  wire        data_sram_req;
  wire        data_sram_wr;
  wire [1:0]  data_sram_size;
  wire [3:0]  data_sram_wstrb;
  wire [31:0] data_sram_addr;
  wire [31:0] data_sram_wdata;
  wire        data_sram_cached;
  wire        data_sram_addr_ok;
  wire        data_sram_data_ok;
  wire [31:0] data_sram_rdata;
  wire        cacop_req;
  wire [4:0]  cacop_code;
  wire [31:0] cacop_addr;
  wire        cacop_addr_ok;
  wire        cacop_data_ok;

  // 架构提交观察信号，仅在 DIFFTEST_EN 下送入 Difftest DPI 模块。
  wire        diff_commit_valid;
  wire        diff_cnt_inst;
  wire [63:0] diff_timer_64;
  wire [ 7:0] diff_inst_ld_en;
  wire [31:0] diff_ld_paddr;
  wire [31:0] diff_ld_vaddr;
  wire [ 7:0] diff_inst_st_en;
  wire [31:0] diff_st_paddr;
  wire [31:0] diff_st_vaddr;
  wire [31:0] diff_st_data;
  wire        diff_csr_rstat_en;
  wire [31:0] diff_csr_data;
  wire        diff_excp_valid;
  wire        diff_ertn;
  wire [ 5:0] diff_csr_ecode;
  wire        diff_tlbfill_en;
  wire [ 4:0] diff_tlbfill_index;
  wire [1023:0] diff_gprs;
  wire [831:0]  diff_csrs;

  // aresetn 在 aclk 域同步采样为高有效 reset。initial 值保证 FPGA/仿真在第一拍
  // 前也处于复位态，避免 CPU 状态使用未初始化值。
  reg reset;
  initial
  begin
    reset = 1'b1;
  end

  always @(posedge aclk)
  begin
    reset <= ~aresetn;
  end

  // 外部中断可能来自其他时钟域，在 CPU 封装边界做两级同步。
  (* ASYNC_REG = "TRUE" *) reg [7:0] intrpt_sync_ff1;
  (* ASYNC_REG = "TRUE" *) reg [7:0] intrpt_sync_ff2;

  always @(posedge aclk)
  begin
    if (reset)
    begin
      intrpt_sync_ff1 <= 8'b0;
      intrpt_sync_ff2 <= 8'b0;
    end
    else
    begin
      intrpt_sync_ff1 <= intrpt;
      intrpt_sync_ff2 <= intrpt_sync_ff1;
    end
  end

  // 处理器核心只看类 SRAM 握手，不直接依赖 AXI 或 cache 的内部组织。
  CPU_top u_cpu_top(
            .clk              (aclk              ),
            .rst              (reset             ),
            .hw_int_in        (intrpt_sync_ff2   ),
            .inst_sram_req    (inst_sram_req     ),
            .inst_sram_wr     (inst_sram_wr      ),
            .inst_sram_size   (inst_sram_size    ),
            .inst_sram_wstrb  (inst_sram_wstrb   ),
            .inst_sram_addr   (inst_sram_addr    ),
            .inst_sram_wdata  (inst_sram_wdata   ),
            .inst_sram_cached (inst_sram_cached  ),
            .inst_sram_addr_ok(inst_sram_addr_ok ),
            .inst_sram_data_ok(inst_sram_data_ok ),
            .inst_sram_rdata  (inst_sram_rdata   ),
            .data_sram_req    (data_sram_req     ),
            .data_sram_wr     (data_sram_wr      ),
            .data_sram_size   (data_sram_size    ),
            .data_sram_wstrb  (data_sram_wstrb   ),
            .data_sram_addr   (data_sram_addr    ),
            .data_sram_wdata  (data_sram_wdata   ),
            .data_sram_cached (data_sram_cached  ),
            .data_sram_addr_ok(data_sram_addr_ok ),
            .data_sram_data_ok(data_sram_data_ok ),
            .data_sram_rdata  (data_sram_rdata   ),
            .cacop_req        (cacop_req         ),
            .cacop_code       (cacop_code        ),
            .cacop_addr       (cacop_addr        ),
            .cacop_addr_ok    (cacop_addr_ok     ),
            .cacop_data_ok    (cacop_data_ok     ),
            .debug_wb_pc      (debug_wb_pc       ),
            .debug_wb_rf_we   (debug_wb_rf_we    ),
            .debug_wb_rf_wnum (debug_wb_rf_wnum  ),
            .debug_wb_rf_wdata(debug_wb_rf_wdata ),
            .debug_wb_inst    (debug_wb_inst     ),
            .diff_commit_valid(diff_commit_valid ),
            .diff_cnt_inst    (diff_cnt_inst     ),
            .diff_timer_64    (diff_timer_64     ),
            .diff_inst_ld_en  (diff_inst_ld_en   ),
            .diff_ld_paddr    (diff_ld_paddr     ),
            .diff_ld_vaddr    (diff_ld_vaddr     ),
            .diff_inst_st_en  (diff_inst_st_en   ),
            .diff_st_paddr    (diff_st_paddr     ),
            .diff_st_vaddr    (diff_st_vaddr     ),
            .diff_st_data     (diff_st_data      ),
            .diff_csr_rstat_en(diff_csr_rstat_en ),
            .diff_csr_data    (diff_csr_data     ),
            .diff_excp_valid  (diff_excp_valid   ),
            .diff_ertn        (diff_ertn         ),
            .diff_csr_ecode   (diff_csr_ecode    ),
            .diff_tlbfill_en  (diff_tlbfill_en   ),
            .diff_tlbfill_index(diff_tlbfill_index),
            .diff_gprs        (diff_gprs         ),
            .diff_csrs        (diff_csrs         )
          );
  // 存储子系统负责 cached/bypass 选择、L1/L2 和所有 AXI 通道状态。
  sram_axi_bridge_2x1 u_sram_axi_bridge_2x1(
                        .aclk              (aclk              ),
                        .aresetn           (aresetn           ),
                        .inst_sram_req     (inst_sram_req     ),
                        .inst_sram_wr      (inst_sram_wr      ),
                        .inst_sram_size    (inst_sram_size    ),
                        .inst_sram_wstrb   (inst_sram_wstrb   ),
                        .inst_sram_addr    (inst_sram_addr    ),
                        .inst_sram_wdata   (inst_sram_wdata   ),
                        .inst_sram_cached  (inst_sram_cached  ),
                        .inst_sram_addr_ok (inst_sram_addr_ok ),
                        .inst_sram_data_ok (inst_sram_data_ok ),
                        .inst_sram_rdata   (inst_sram_rdata   ),
                        .data_sram_req     (data_sram_req     ),
                        .data_sram_wr      (data_sram_wr      ),
                        .data_sram_size    (data_sram_size    ),
                        .data_sram_wstrb   (data_sram_wstrb   ),
                        .data_sram_addr    (data_sram_addr    ),
                        .data_sram_wdata   (data_sram_wdata   ),
                        .data_sram_cached  (data_sram_cached  ),
                        .data_sram_addr_ok (data_sram_addr_ok ),
                        .data_sram_data_ok (data_sram_data_ok ),
                        .data_sram_rdata   (data_sram_rdata   ),
                        .cacop_req         (cacop_req         ),
                        .cacop_code        (cacop_code        ),
                        .cacop_addr        (cacop_addr        ),
                        .cacop_addr_ok     (cacop_addr_ok     ),
                        .cacop_data_ok     (cacop_data_ok     ),
                        .arid              (arid              ),
                        .araddr            (araddr            ),
                        .arlen             (arlen             ),
                        .arsize            (arsize            ),
                        .arburst           (arburst           ),
                        .arlock            (arlock            ),
                        .arcache           (arcache           ),
                        .arprot            (arprot            ),
                        .arvalid           (arvalid           ),
                        .arready           (arready           ),
                        .rid               (rid               ),
                        .rdata             (rdata             ),
                        .rresp             (rresp             ),
                        .rlast             (rlast             ),
                        .rvalid            (rvalid            ),
                        .rready            (rready            ),
                        .awid              (awid              ),
                        .awaddr            (awaddr            ),
                        .awlen             (awlen             ),
                        .awsize            (awsize            ),
                        .awburst           (awburst           ),
                        .awlock            (awlock            ),
                        .awcache           (awcache           ),
                        .awprot            (awprot            ),
                        .awvalid           (awvalid           ),
                        .awready           (awready           ),
                        .wid               (wid               ),
                        .wdata             (wdata             ),
                        .wstrb             (wstrb             ),
                        .wlast             (wlast             ),
                        .wvalid            (wvalid            ),
                        .wready            (wready            ),
                        .bid               (bid               ),
                        .bresp             (bresp             ),
                        .bvalid            (bvalid            ),
                        .bready            (bready            )
                      );

`ifdef DIFFTEST_EN
  // ---------------------------------------------------------------------------
  // 差分测试监视器
  // ---------------------------------------------------------------------------
  // 先将 CPU 的组合提交输出寄存一拍，再驱动 Difftest 模块；监视路径绝不反馈
  // CPU 控制。cycleCnt 每拍递增，instrCnt 只统计有效架构提交。
  reg        cmt_valid;
  reg        cmt_cnt_inst;
  reg [63:0] cmt_timer_64;
  reg [ 7:0] cmt_inst_ld_en;
  reg [31:0] cmt_ld_paddr;
  reg [31:0] cmt_ld_vaddr;
  reg [ 7:0] cmt_inst_st_en;
  reg [31:0] cmt_st_paddr;
  reg [31:0] cmt_st_vaddr;
  reg [31:0] cmt_st_data;
  reg        cmt_csr_rstat_en;
  reg [31:0] cmt_csr_data;
  reg [ 3:0] cmt_wen;
  reg [ 7:0] cmt_wdest;
  reg [31:0] cmt_wdata;
  reg [31:0] cmt_pc;
  reg [31:0] cmt_inst;
  reg        cmt_excp_valid;
  reg        cmt_ertn;
  reg [ 5:0] cmt_csr_ecode;
  reg        cmt_tlbfill_en;
  reg [ 4:0] cmt_tlbfill_index;
  reg        trap;
  reg [ 7:0] trap_code;
  reg [63:0] cycleCnt;
  reg [63:0] instrCnt;

  always @(posedge aclk) begin
    if (reset) begin
      {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr,
       cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data,
       cmt_csr_rstat_en, cmt_csr_data} <= 0;
      {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
      {cmt_excp_valid, cmt_ertn, cmt_csr_ecode, cmt_tlbfill_en, cmt_tlbfill_index} <= 0;
      {trap, trap_code, cycleCnt, instrCnt} <= 0;
    end else if (!trap) begin
      cmt_valid         <= diff_commit_valid;
      cmt_cnt_inst      <= diff_cnt_inst;
      cmt_timer_64      <= diff_timer_64;
      cmt_inst_ld_en    <= diff_inst_ld_en;
      cmt_ld_paddr      <= diff_ld_paddr;
      cmt_ld_vaddr      <= diff_ld_vaddr;
      cmt_inst_st_en    <= diff_inst_st_en;
      cmt_st_paddr      <= diff_st_paddr;
      cmt_st_vaddr      <= diff_st_vaddr;
      cmt_st_data       <= diff_st_data;
      cmt_csr_rstat_en  <= diff_csr_rstat_en;
      cmt_csr_data      <= diff_csr_data;
      cmt_wen           <= debug_wb_rf_we;
      cmt_wdest         <= {3'b0, debug_wb_rf_wnum};
      cmt_wdata         <= debug_wb_rf_wdata;
      cmt_pc            <= debug_wb_pc;
      cmt_inst          <= debug_wb_inst;
      cmt_excp_valid    <= diff_excp_valid;
      cmt_ertn          <= diff_ertn;
      cmt_csr_ecode     <= diff_csr_ecode;
      cmt_tlbfill_en    <= diff_tlbfill_en;
      cmt_tlbfill_index <= diff_tlbfill_index;
      trap              <= 1'b0;
      trap_code         <= diff_gprs[10*32 +: 8];
      cycleCnt          <= cycleCnt + 1'b1;
      instrCnt          <= instrCnt + diff_commit_valid;
    end
  end

  DifftestInstrCommit DifftestInstrCommit(
    .clock          (aclk),
    .coreid         (8'b0),
    .index          (8'b0),
    .valid          (cmt_valid),
    .pc             (cmt_pc),
    .instr          (cmt_inst),
    .skip           (1'b0),
    .is_TLBFILL     (cmt_tlbfill_en),
    .TLBFILL_index  (cmt_tlbfill_index),
    .is_CNTinst     (cmt_cnt_inst),
    .timer_64_value (cmt_timer_64),
    .wen            (|cmt_wen),
    .wdest          (cmt_wdest),
    .wdata          (cmt_wdata),
    .csr_rstat      (cmt_csr_rstat_en),
    .csr_data       (cmt_csr_data)
  );

  DifftestExcpEvent DifftestExcpEvent(
    .clock          (aclk),
    .coreid         (8'b0),
    .excp_valid     (cmt_excp_valid),
    .eret           (cmt_ertn),
    .intrNo         ({21'b0, diff_csrs[3*32+12 : 3*32+2]}),
    .cause          ({26'b0, cmt_csr_ecode}),
    .exceptionPC    (cmt_pc),
    .exceptionInst  (cmt_inst)
  );

  DifftestTrapEvent DifftestTrapEvent(
    .clock          (aclk),
    .coreid         (8'b0),
    .valid          (trap),
    .code           (trap_code[2:0]),
    .pc             (cmt_pc),
    .cycleCnt       (cycleCnt),
    .instrCnt       (instrCnt)
  );

  DifftestStoreEvent DifftestStoreEvent(
    .clock          (aclk),
    .coreid         (8'b0),
    .index          (8'b0),
    .valid          (cmt_inst_st_en),
    .storePAddr     (cmt_st_paddr),
    .storeVAddr     (cmt_st_vaddr),
    .storeData      (cmt_st_data)
  );

  DifftestLoadEvent DifftestLoadEvent(
    .clock          (aclk),
    .coreid         (8'b0),
    .index          (8'b0),
    .valid          (cmt_inst_ld_en),
    .paddr          (cmt_ld_paddr),
    .vaddr          (cmt_ld_vaddr)
  );

  DifftestCSRRegState DifftestCSRRegState(
    .clock          (aclk),
    .coreid         (8'b0),
    .crmd           (diff_csrs[0*32 +: 32]),
    .prmd           (diff_csrs[1*32 +: 32]),
    .euen           (64'b0),
    .ecfg           (diff_csrs[2*32 +: 32]),
    .estat          (diff_csrs[3*32 +: 32]),
    .era            (diff_csrs[4*32 +: 32]),
    .badv           (diff_csrs[5*32 +: 32]),
    .eentry         (diff_csrs[6*32 +: 32]),
    .tlbidx         (diff_csrs[7*32 +: 32]),
    .tlbehi         (diff_csrs[8*32 +: 32]),
    .tlbelo0        (diff_csrs[9*32 +: 32]),
    .tlbelo1        (diff_csrs[10*32 +: 32]),
    .asid           (diff_csrs[11*32 +: 32]),
    .pgdl           (diff_csrs[12*32 +: 32]),
    .pgdh           (diff_csrs[13*32 +: 32]),
    .save0          (diff_csrs[14*32 +: 32]),
    .save1          (diff_csrs[15*32 +: 32]),
    .save2          (diff_csrs[16*32 +: 32]),
    .save3          (diff_csrs[17*32 +: 32]),
    .tid            (diff_csrs[18*32 +: 32]),
    .tcfg           (diff_csrs[19*32 +: 32]),
    .tval           (diff_csrs[20*32 +: 32]),
    .ticlr          (diff_csrs[21*32 +: 32]),
    .llbctl         (diff_csrs[22*32 +: 32]),
    .tlbrentry      (diff_csrs[23*32 +: 32]),
    .dmw0           (diff_csrs[24*32 +: 32]),
    .dmw1           (diff_csrs[25*32 +: 32])
  );

  DifftestGRegState DifftestGRegState(
    .clock          (aclk),
    .coreid         (8'b0),
    .gpr_0          (diff_gprs[0*32 +: 32]),
    .gpr_1          (diff_gprs[1*32 +: 32]),
    .gpr_2          (diff_gprs[2*32 +: 32]),
    .gpr_3          (diff_gprs[3*32 +: 32]),
    .gpr_4          (diff_gprs[4*32 +: 32]),
    .gpr_5          (diff_gprs[5*32 +: 32]),
    .gpr_6          (diff_gprs[6*32 +: 32]),
    .gpr_7          (diff_gprs[7*32 +: 32]),
    .gpr_8          (diff_gprs[8*32 +: 32]),
    .gpr_9          (diff_gprs[9*32 +: 32]),
    .gpr_10         (diff_gprs[10*32 +: 32]),
    .gpr_11         (diff_gprs[11*32 +: 32]),
    .gpr_12         (diff_gprs[12*32 +: 32]),
    .gpr_13         (diff_gprs[13*32 +: 32]),
    .gpr_14         (diff_gprs[14*32 +: 32]),
    .gpr_15         (diff_gprs[15*32 +: 32]),
    .gpr_16         (diff_gprs[16*32 +: 32]),
    .gpr_17         (diff_gprs[17*32 +: 32]),
    .gpr_18         (diff_gprs[18*32 +: 32]),
    .gpr_19         (diff_gprs[19*32 +: 32]),
    .gpr_20         (diff_gprs[20*32 +: 32]),
    .gpr_21         (diff_gprs[21*32 +: 32]),
    .gpr_22         (diff_gprs[22*32 +: 32]),
    .gpr_23         (diff_gprs[23*32 +: 32]),
    .gpr_24         (diff_gprs[24*32 +: 32]),
    .gpr_25         (diff_gprs[25*32 +: 32]),
    .gpr_26         (diff_gprs[26*32 +: 32]),
    .gpr_27         (diff_gprs[27*32 +: 32]),
    .gpr_28         (diff_gprs[28*32 +: 32]),
    .gpr_29         (diff_gprs[29*32 +: 32]),
    .gpr_30         (diff_gprs[30*32 +: 32]),
    .gpr_31         (diff_gprs[31*32 +: 32])
  );
`endif

endmodule

// =============================================================================
// 双端口类 SRAM -> cache/L2 -> AXI4 桥
// =============================================================================
// 功能分层：
//   1. 按 inst/data_sram_cached 将 CPU 请求路由到 L1 cache 或 uncached bypass；
//   2. 实例化两路 L1 和统一 L2，并路由 CACOP 到 code[2:0] 指定的层级；
//   3. 为 I、D 各维护两个带 tag 的读 context，把缓存四拍 refill 映射成 AXI
//      INCR/WRAP burst，把 bypass 映射成单拍事务；
//   4. 使用一个独立写 context 处理 D-cache writeback 与 bypass store；
//   5. uncached 普通 RAM store 完成后 snoop I-cache/L2，支持自修改代码一致性。
//
// 板级 AXI mux 实际只保留 ID[0]：RID=0 表示 I，RID=1 表示 D。同一 ID 的 AXI
// 响应保证有序，所以每侧用 return_order FIFO 恢复两个本地 slot。cache 内部 ID
// 不直接编码到 ARID，避免位宽截断导致响应错配。
// =============================================================================
module sram_axi_bridge_2x1(
    input  wire        aclk,
    input  wire        aresetn,

    // CPU 指令类 SRAM 接口；cached=0 的取指绕过 I/L2 cache。
    input  wire        inst_sram_req,
    input  wire        inst_sram_wr,
    input  wire [ 1:0] inst_sram_size,
    input  wire [ 3:0] inst_sram_wstrb,
    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_cached,
    output wire        inst_sram_addr_ok,
    output wire        inst_sram_data_ok,
    output wire [31:0] inst_sram_rdata,

    // CPU 数据类 SRAM 接口；cached=0 用于 MMIO/强序或不可缓存内存。
    input  wire        data_sram_req,
    input  wire        data_sram_wr,
    input  wire [ 1:0] data_sram_size,
    input  wire [ 3:0] data_sram_wstrb,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_wdata,
    input  wire        data_sram_cached,
    output wire        data_sram_addr_ok,
    output wire        data_sram_data_ok,
    output wire [31:0] data_sram_rdata,

    // CPU 的 CACOP 独立维护接口；低 3 位选择 I-cache、D-cache 或 L2。
    input  wire        cacop_req,
    input  wire [ 4:0] cacop_code,
    input  wire [31:0] cacop_addr,
    output wire        cacop_addr_ok,
    output wire        cacop_data_ok,

    // AXI 读地址通道。cache refill 为 len=3、32-bit beat；bypass 为 len=0。
    output wire [ 3:0] arid,
    output reg  [31:0] araddr,
    output wire [ 7:0] arlen,
    output reg  [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output reg         arvalid,
    input  wire        arready,

    // AXI 读数据通道。rready 只对能够匹配当前有效 context 的 RID 拉高。
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    // AXI 写地址通道；本实现所有写均为单 beat（awlen=0）。
    output wire [ 3:0] awid,
    output reg  [31:0] awaddr,
    output wire [ 7:0] awlen,
    output reg  [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output reg         awvalid,
    input  wire        awready,

    // AXI 写数据通道；AW/W 可独立握手，wlast 恒 1。
    output wire [ 3:0] wid,
    output reg  [31:0] wdata,
    output reg  [ 3:0] wstrb,
    output wire        wlast,
    output reg         wvalid,
    input  wire        wready,

    // AXI 写响应通道；AW 与 W 都被接收后才拉高 bready。
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready
  );

  // 写/请求来源编码。当前写通路只产生 DBYPASS 或 DCACHE，完整枚举便于调试。
  localparam SRC_IBYPASS = 2'd0;
  localparam SRC_DBYPASS = 2'd1;
  localparam SRC_ICACHE  = 2'd2;
  localparam SRC_DCACHE  = 2'd3;

  // I-read、D-read 和 write 各有独立 context。AR 只仲裁地址发送，
  // 已发送的 I/D read 可同时等待返回，RID 负责选择对应 context。
  reg [1:0] iread_valid;
  reg [1:0] iread_ar_sent;
  reg [1:0] iread_is_cache;
  reg [31:0] iread_addr[0:1];
  reg [1:0]  iread_size[0:1];
  // 板级 AXI mux 的 slave 侧只提供一位 ID。保留两个本地 context，
  // 但不再通过 AXI ID[1] 输出槽号，而是按照发出顺序在内部恢复槽号。
  // AXI 保证相同 ID 的事务响应保持顺序。
  reg [1:0] iread_return_order;
  reg       iread_return_head;
  reg       iread_return_tail;
  reg [1:0] iread_return_count;
  reg [1:0] dread_valid;
  reg [1:0] dread_ar_sent;
  reg [1:0] dread_is_cache;
  reg [31:0] dread_addr[0:1];
  reg [1:0]  dread_size[0:1];
  reg [1:0] dread_return_order;
  reg       dread_return_head;
  reg       dread_return_tail;
  reg [1:0] dread_return_count;
  reg       ar_select_d;
  reg       ar_select_slot;
  reg       ar_is_cache;

  // 单项写 context 将 AW/W 的独立握手与上游请求解耦。write_src 决定 B 响应
  // 应回给 D-cache 还是 bypass；write_valid 直到匹配 B 响应完成才清除。
  reg       write_valid;
  reg [1:0] write_src;
  reg [7:0] arlen_r;

  // cached 属性必须与请求同拍稳定；四个互斥条件把上游分成 cache/bypass 流量。
  wire inst_cache_req  = inst_sram_req && inst_sram_cached;
  wire inst_bypass_req = inst_sram_req && !inst_sram_cached;
  wire data_cache_req  = data_sram_req && data_sram_cached;
  wire data_bypass_req = data_sram_req && !data_sram_cached;

  wire        icache_addr_ok;
  wire        icache_data_ok;
  wire [31:0] icache_rdata;
  wire        icache_l1_mem_req;
  wire        icache_l1_mem_wr;
  wire [ 1:0] icache_l1_mem_size;
  wire [ 3:0] icache_l1_mem_wstrb;
  wire [31:0] icache_l1_mem_addr;
  wire [31:0] icache_l1_mem_wdata;
  wire        icache_l1_mem_id;
  wire        icache_l1_mem_prefetch;
  wire        icache_l1_mem_addr_ok;
  wire        icache_l1_mem_data_ok;
  wire [31:0] icache_l1_mem_rdata;
  wire        icache_l1_mem_resp_id;
  wire        icache_mem_req;
  wire        icache_mem_wr;
  wire [ 1:0] icache_mem_size;
  wire [ 3:0] icache_mem_wstrb;
  wire [31:0] icache_mem_addr;
  wire [31:0] icache_mem_wdata;
  wire        icache_mem_id;
  wire        icache_mem_addr_ok;
  wire        icache_mem_data_ok;
  wire [31:0] icache_mem_rdata;
  wire        icache_mem_resp_id;

  wire        dcache_addr_ok;
  wire        dcache_data_ok;
  wire [31:0] dcache_rdata;
  wire        dcache_l1_mem_req;
  wire        dcache_l1_mem_wr;
  wire [ 1:0] dcache_l1_mem_size;
  wire [ 3:0] dcache_l1_mem_wstrb;
  wire [31:0] dcache_l1_mem_addr;
  wire [31:0] dcache_l1_mem_wdata;
  wire        dcache_l1_mem_id;
  wire        dcache_l1_mem_addr_ok;
  wire        dcache_l1_mem_data_ok;
  wire [31:0] dcache_l1_mem_rdata;
  wire        dcache_l1_mem_resp_id;
  wire        dcache_mem_req;
  wire        dcache_mem_wr;
  wire [ 1:0] dcache_mem_size;
  wire [ 3:0] dcache_mem_wstrb;
  wire [31:0] dcache_mem_addr;
  wire [31:0] dcache_mem_wdata;
  wire        dcache_mem_id;
  wire        dcache_mem_addr_ok;
  wire        dcache_mem_data_ok;
  wire [31:0] dcache_mem_rdata;
  wire        dcache_mem_resp_id;

  // CACOP 目标编码：0=L1I，1=L1D，2=L2；其他编码作为无副作用操作立即完成。
  wire cacop_icache_req = cacop_req && (cacop_code[2:0] == 3'd0);
  wire cacop_dcache_req = cacop_req && (cacop_code[2:0] == 3'd1);
  wire cacop_l2_req     = cacop_req && (cacop_code[2:0] == 3'd2);
  wire cacop_noop       = cacop_req && !cacop_icache_req &&
                          !cacop_dcache_req && !cacop_l2_req;
  wire icache_cacop_addr_ok;
  wire icache_cacop_data_ok;
  wire dcache_cacop_addr_ok;
  wire dcache_cacop_data_ok;
  wire l2_cacop_addr_ok;
  wire l2_cacop_data_ok;

  // uncached 普通 RAM store 在 AXI B 返回后同步更新 I-cache 与 clean L2。
  // 独立握手允许两个 cache 先后排空，不把 maintenance 状态接入 cached 命中路径。
  reg         uncached_snoop_pending_q;
  reg         icache_snoop_req_q;
  reg         l2_snoop_req_q;
  reg         icache_snoop_done_q;
  reg         l2_snoop_done_q;
  reg  [31:0] uncached_snoop_addr_q;
  reg  [ 3:0] uncached_snoop_wstrb_q;
  reg  [31:0] uncached_snoop_wdata_q;
  wire        icache_snoop_addr_ok;
  wire        icache_snoop_data_ok;
  wire        l2_snoop_addr_ok;
  wire        l2_snoop_data_ok;

  icache u_icache(
           .clk          (aclk                 ),
           .resetn       (aresetn              ),
           .req          (inst_cache_req        ),
           .wr           (1'b0                 ),
           .addr         (inst_sram_addr        ),
           .wstrb        (4'b0000              ),
           .wdata        (32'b0                ),
           .snoop_req    (icache_snoop_req_q   ),
           .snoop_addr   (uncached_snoop_addr_q),
           .snoop_wstrb  (uncached_snoop_wstrb_q),
           .snoop_wdata  (uncached_snoop_wdata_q),
           .snoop_addr_ok(icache_snoop_addr_ok ),
           .snoop_data_ok(icache_snoop_data_ok ),
           .cacop_req    (cacop_icache_req     ),
           .cacop_code   (cacop_code           ),
           .cacop_addr   (cacop_addr           ),
           .cacop_addr_ok(icache_cacop_addr_ok ),
           .cacop_data_ok(icache_cacop_data_ok ),
           .addr_ok      (icache_addr_ok       ),
           .data_ok      (icache_data_ok       ),
           .rdata        (icache_rdata         ),
           .mem_req      (icache_l1_mem_req       ),
           .mem_wr       (icache_l1_mem_wr        ),
           .mem_size     (icache_l1_mem_size      ),
           .mem_wstrb    (icache_l1_mem_wstrb     ),
           .mem_addr     (icache_l1_mem_addr      ),
            .mem_wdata    (icache_l1_mem_wdata     ),
            .mem_id       (icache_l1_mem_id        ),
            .mem_prefetch (icache_l1_mem_prefetch  ),
           .mem_addr_ok  (icache_l1_mem_addr_ok   ),
           .mem_data_ok  (icache_l1_mem_data_ok   ),
           .mem_rdata    (icache_l1_mem_rdata     ),
           .mem_resp_id  (icache_l1_mem_resp_id   )
         );

  dcache u_dcache(
           .clk          (aclk                 ),
           .resetn       (aresetn              ),
           .req          (data_cache_req        ),
           .wr           (data_sram_wr         ),
           .addr         (data_sram_addr       ),
           .wstrb        (data_sram_wstrb      ),
           .wdata        (data_sram_wdata      ),
           .cacop_req    (cacop_dcache_req     ),
           .cacop_code   (cacop_code           ),
           .cacop_addr   (cacop_addr           ),
           .cacop_addr_ok(dcache_cacop_addr_ok ),
           .cacop_data_ok(dcache_cacop_data_ok ),
           .addr_ok      (dcache_addr_ok       ),
           .data_ok      (dcache_data_ok       ),
           .rdata        (dcache_rdata         ),
           .mem_req      (dcache_l1_mem_req       ),
           .mem_wr       (dcache_l1_mem_wr        ),
           .mem_size     (dcache_l1_mem_size      ),
           .mem_wstrb    (dcache_l1_mem_wstrb     ),
           .mem_addr     (dcache_l1_mem_addr      ),
           .mem_wdata    (dcache_l1_mem_wdata     ),
           .mem_id       (dcache_l1_mem_id        ),
           .mem_addr_ok  (dcache_l1_mem_addr_ok   ),
           .mem_data_ok  (dcache_l1_mem_data_ok   ),
           .mem_rdata    (dcache_l1_mem_rdata     ),
           .mem_resp_id  (dcache_l1_mem_resp_id   )
         );

  // 128 KiB 统一式 clean L2。只有缓存访问的 L1 refill/writeback 流量进入
  // 此模块；下方现有的 uncached/MMIO 路径仍然将其旁路。
  l2_cache u_l2_cache(
           .clk          (aclk                    ),
           .resetn       (aresetn                 ),
           .cacop_req    (cacop_l2_req            ),
           .cacop_code   (cacop_code              ),
           .cacop_addr   (cacop_addr              ),
           .cacop_addr_ok(l2_cacop_addr_ok        ),
           .cacop_data_ok(l2_cacop_data_ok        ),
           .snoop_req    (l2_snoop_req_q          ),
           .snoop_addr   (uncached_snoop_addr_q   ),
           .snoop_wstrb  (uncached_snoop_wstrb_q  ),
           .snoop_wdata  (uncached_snoop_wdata_q  ),
           .snoop_addr_ok(l2_snoop_addr_ok        ),
           .snoop_data_ok(l2_snoop_data_ok        ),
           .i_req        (icache_l1_mem_req       ),
           .i_wr         (icache_l1_mem_wr        ),
           .i_size       (icache_l1_mem_size      ),
           .i_wstrb      (icache_l1_mem_wstrb     ),
           .i_addr       (icache_l1_mem_addr      ),
            .i_wdata      (icache_l1_mem_wdata     ),
            .i_id         (icache_l1_mem_id        ),
            .i_prefetch   (icache_l1_mem_prefetch  ),
           .i_addr_ok    (icache_l1_mem_addr_ok   ),
           .i_data_ok    (icache_l1_mem_data_ok   ),
           .i_rdata      (icache_l1_mem_rdata     ),
           .i_resp_id    (icache_l1_mem_resp_id   ),
           .d_req        (dcache_l1_mem_req       ),
           .d_wr         (dcache_l1_mem_wr        ),
           .d_size       (dcache_l1_mem_size      ),
           .d_wstrb      (dcache_l1_mem_wstrb     ),
           .d_addr       (dcache_l1_mem_addr      ),
           .d_wdata      (dcache_l1_mem_wdata     ),
           .d_id         (dcache_l1_mem_id        ),
           .d_addr_ok    (dcache_l1_mem_addr_ok   ),
           .d_data_ok    (dcache_l1_mem_data_ok   ),
           .d_rdata      (dcache_l1_mem_rdata     ),
           .d_resp_id    (dcache_l1_mem_resp_id   ),
           .i_mem_req    (icache_mem_req          ),
           .i_mem_wr     (icache_mem_wr           ),
           .i_mem_size   (icache_mem_size         ),
           .i_mem_wstrb  (icache_mem_wstrb        ),
           .i_mem_addr   (icache_mem_addr         ),
           .i_mem_wdata  (icache_mem_wdata        ),
           .i_mem_id     (icache_mem_id           ),
           .i_mem_addr_ok(icache_mem_addr_ok      ),
           .i_mem_data_ok(icache_mem_data_ok      ),
           .i_mem_rdata  (icache_mem_rdata        ),
           .i_mem_resp_id(icache_mem_resp_id      ),
           .d_mem_req    (dcache_mem_req          ),
           .d_mem_wr     (dcache_mem_wr           ),
           .d_mem_size   (dcache_mem_size         ),
           .d_mem_wstrb  (dcache_mem_wstrb        ),
           .d_mem_addr   (dcache_mem_addr         ),
           .d_mem_wdata  (dcache_mem_wdata        ),
           .d_mem_id     (dcache_mem_id           ),
           .d_mem_addr_ok(dcache_mem_addr_ok      ),
           .d_mem_data_ok(dcache_mem_data_ok      ),
           .d_mem_rdata  (dcache_mem_rdata        ),
           .d_mem_resp_id(dcache_mem_resp_id      )
         );

  assign cacop_addr_ok = cacop_icache_req ? icache_cacop_addr_ok :
         cacop_dcache_req ? dcache_cacop_addr_ok :
         cacop_l2_req ? l2_cacop_addr_ok :
         cacop_noop;
  assign cacop_data_ok = icache_cacop_data_ok ||
         dcache_cacop_data_ok ||
         l2_cacop_data_ok ||
         cacop_noop;

  // 每个 cache 侧提供两个 tagged read context。bypass 没有返回 tag，
  // 因此只在同侧两个 context 都空闲时使用 slot 0。
  wire grant_dcache_read = !write_valid && dcache_mem_req &&
                           !dcache_mem_wr && !dread_valid[dcache_mem_id];
  wire grant_dbypass_read = !(|dread_valid) && !write_valid && !dcache_mem_req &&
                            data_bypass_req && !data_sram_wr;
  wire grant_icache_read = icache_mem_req && !icache_mem_wr &&
                           !iread_valid[icache_mem_id];
  wire grant_ibypass_read = !(|iread_valid) && !icache_mem_req &&
                            inst_bypass_req && !inst_sram_wr;

  wire grant_dcache_write = !write_valid && !(|dread_valid) && dcache_mem_req &&
                            dcache_mem_wr;
  wire grant_dbypass_write = !write_valid && !uncached_snoop_pending_q &&
                             !(|dread_valid) && !dcache_mem_req &&
                             data_bypass_req && data_sram_wr;

  assign icache_mem_addr_ok = grant_icache_read;
  assign dcache_mem_addr_ok = grant_dcache_read || grant_dcache_write;
  wire inst_bypass_addr_ok = grant_ibypass_read;
  wire data_bypass_addr_ok = grant_dbypass_read || grant_dbypass_write;

  wire iread_return_slot = iread_return_order[iread_return_head];
  wire dread_return_slot = dread_return_order[dread_return_head];
  wire read_resp_slot = rid[0] ? dread_return_slot : iread_return_slot;
  wire rid_is_iread = (rid == 4'd0);
  wire rid_is_dread = (rid == 4'd1);
  wire iread_resp_fire = rvalid && rready && rid_is_iread;
  wire dread_resp_fire = rvalid && rready && rid_is_dread;
  wire axi_write_ok = bvalid && bready && (bid == 4'd1);
  // 低 128 MiB 和 0x1c000000 主存窗口都由仿真 RAM 承载。后者是 func
  // 自修改代码实际使用的取指地址，不能按 MMIO 跳过 cache snoop；其余
  // 地址（例如 0xd0100000、UART、SPI）仍直接完成，避免污染 cache。
  wire write_targets_snoop_ram = (awaddr[31:27] == 5'b00000) ||
       (awaddr[31:24] == 8'h1c);
  wire uncached_ram_write_ok = axi_write_ok &&
       (write_src == SRC_DBYPASS) && write_targets_snoop_ram;
  wire uncached_mmio_write_ok = axi_write_ok &&
       (write_src == SRC_DBYPASS) && !write_targets_snoop_ram;
  wire uncached_snoop_finish = uncached_snoop_pending_q &&
       (icache_snoop_done_q || icache_snoop_data_ok) &&
       (l2_snoop_done_q || l2_snoop_data_ok);

  assign icache_mem_data_ok = iread_resp_fire &&
                              iread_is_cache[read_resp_slot];
  assign icache_mem_resp_id = read_resp_slot;
  assign dcache_mem_data_ok =
         (dread_resp_fire && dread_is_cache[read_resp_slot]) ||
         (axi_write_ok && (write_src == SRC_DCACHE));
  assign dcache_mem_resp_id = read_resp_slot;
  assign icache_mem_rdata = rdata;
  assign dcache_mem_rdata = rdata;

  wire inst_bypass_data_ok = iread_resp_fire &&
                             !iread_is_cache[read_resp_slot];
  wire data_bypass_data_ok =
       (dread_resp_fire && !dread_is_cache[read_resp_slot]) ||
       uncached_mmio_write_ok || uncached_snoop_finish;
  // AXI 旁路响应先经过寄存器再到达 CPU。若让 rvalid/rready 与
  // data_sram_data_ok 保持组合连接，会形成很长的
  // uncached-response -> LQ/WBQ -> frontend-control 路径。性能测试流量
  // 使用缓存，因此新增的一拍只影响 uncached/MMIO 访问。
  reg inst_bypass_data_ok_q;
  reg data_bypass_data_ok_q;
  reg [31:0] inst_bypass_rdata_q;
  reg [31:0] data_bypass_rdata_q;

  assign inst_sram_addr_ok = inst_sram_cached ? icache_addr_ok :
                             inst_bypass_addr_ok;
  assign inst_sram_data_ok = icache_data_ok || inst_bypass_data_ok_q;
  assign inst_sram_rdata   = icache_data_ok ? icache_rdata :
                             inst_bypass_rdata_q;

  assign data_sram_addr_ok = data_sram_cached ? dcache_addr_ok :
                             data_bypass_addr_ok;
  assign data_sram_data_ok = dcache_data_ok || data_bypass_data_ok_q;
  assign data_sram_rdata   = dcache_data_ok ? dcache_rdata :
                             data_bypass_rdata_q;

  // axi_2x1_mux 的 S00 ID 端口只有一位：0 表示取指读，1 表示数据读。
  // 下方每个来源各自维护返回队列，不再依赖会被截断的 ID 位保存本地槽号。
  assign arid    = {3'b000,ar_select_d};
  assign arlen   = arlen_r;
  assign arburst = ar_is_cache ? 2'b10 : 2'b01;
  assign arlock  = 2'b00;
  assign arcache = 4'b0000;
  assign arprot  = 3'b000;
  // 只接收能由当前有效且已经发出 AR 的 context 消费的 RID。
  assign rready = (rid_is_iread && (iread_return_count != 2'd0) &&
                   iread_valid[read_resp_slot] &&
                   iread_ar_sent[read_resp_slot]) ||
                  (rid_is_dread && (dread_return_count != 2'd0) &&
                   dread_valid[read_resp_slot] &&
                   dread_ar_sent[read_resp_slot]);

  wire iread_return_push = arvalid && arready && !ar_select_d;
  wire dread_return_push = arvalid && arready && ar_select_d;
  wire iread_return_pop = iread_resp_fire && rlast;
  wire dread_return_pop = dread_resp_fire && rlast;

  assign awid    = 4'd1;
  assign awlen   = 8'd0;
  assign awburst = 2'b01;
  assign awlock  = 2'b00;
  assign awcache = 4'b0000;
  assign awprot  = 3'b000;
  assign wid     = 4'd1;
  assign wlast   = 1'b1;
  // AW/W 都握手后才允许消费 B，read context 与此完全独立。
  assign bready  = write_valid && !awvalid && !wvalid;

  always @(posedge aclk)
  begin
    if (!aresetn)
    begin
      iread_valid <= 2'b0;
      iread_ar_sent <= 2'b0;
      iread_is_cache <= 2'b0;
      iread_addr[0] <= 32'b0;
      iread_addr[1] <= 32'b0;
      iread_size[0] <= 2'b0;
      iread_size[1] <= 2'b0;
      iread_return_order <= 2'b0;
      iread_return_head <= 1'b0;
      iread_return_tail <= 1'b0;
      iread_return_count <= 2'b0;
      dread_valid <= 2'b0;
      dread_ar_sent <= 2'b0;
      dread_is_cache <= 2'b0;
      dread_addr[0] <= 32'b0;
      dread_addr[1] <= 32'b0;
      dread_size[0] <= 2'b0;
      dread_size[1] <= 2'b0;
      dread_return_order <= 2'b0;
      dread_return_head <= 1'b0;
      dread_return_tail <= 1'b0;
      dread_return_count <= 2'b0;
      ar_select_d <= 1'b0;
      ar_select_slot <= 1'b0;
      ar_is_cache <= 1'b0;
      arlen_r <= 8'b0;
      araddr <= 32'b0;
      arsize <= 3'b0;
      arvalid <= 1'b0;

      write_valid <= 1'b0;
      write_src <= SRC_DBYPASS;
      awaddr <= 32'b0;
      awsize <= 3'b0;
      awvalid <= 1'b0;
      wdata <= 32'b0;
      wstrb <= 4'b0;
      wvalid <= 1'b0;
      uncached_snoop_pending_q <= 1'b0;
      icache_snoop_req_q <= 1'b0;
      l2_snoop_req_q <= 1'b0;
      icache_snoop_done_q <= 1'b0;
      l2_snoop_done_q <= 1'b0;
      uncached_snoop_addr_q <= 32'b0;
      uncached_snoop_wstrb_q <= 4'b0;
      uncached_snoop_wdata_q <= 32'b0;
      inst_bypass_data_ok_q <= 1'b0;
      data_bypass_data_ok_q <= 1'b0;
      inst_bypass_rdata_q <= 32'b0;
      data_bypass_rdata_q <= 32'b0;
    end
    else
    begin
      inst_bypass_data_ok_q <= inst_bypass_data_ok;
      data_bypass_data_ok_q <= data_bypass_data_ok;
      if (inst_bypass_data_ok)
        inst_bypass_rdata_q <= rdata;
      if (dread_resp_fire && !dread_is_cache[read_resp_slot])
        data_bypass_rdata_q <= rdata;

      // 普通 RAM 的 B 响应先启动两个 cache 的精确行更新，两个更新都完成后
      // 才向 CPU 返回 store data_ok。MMIO 不进入此状态机。
      if (uncached_ram_write_ok)
      begin
        uncached_snoop_pending_q <= 1'b1;
        icache_snoop_req_q <= 1'b1;
        l2_snoop_req_q <= 1'b1;
        icache_snoop_done_q <= 1'b0;
        l2_snoop_done_q <= 1'b0;
        uncached_snoop_addr_q <= awaddr;
        uncached_snoop_wstrb_q <= wstrb;
        uncached_snoop_wdata_q <= wdata;
      end
      if (icache_snoop_req_q && icache_snoop_addr_ok)
        icache_snoop_req_q <= 1'b0;
      if (l2_snoop_req_q && l2_snoop_addr_ok)
        l2_snoop_req_q <= 1'b0;
      if (icache_snoop_data_ok)
        icache_snoop_done_q <= 1'b1;
      if (l2_snoop_data_ok)
        l2_snoop_done_q <= 1'b1;
      if (uncached_snoop_finish)
      begin
        uncached_snoop_pending_q <= 1'b0;
        icache_snoop_req_q <= 1'b0;
        l2_snoop_req_q <= 1'b0;
        icache_snoop_done_q <= 1'b0;
        l2_snoop_done_q <= 1'b0;
      end

      // 返回末 beat 释放各自 context；I/D 可在同一段时间交错返回。
      if (iread_resp_fire && rlast)
      begin
        iread_valid[read_resp_slot] <= 1'b0;
        iread_ar_sent[read_resp_slot] <= 1'b0;
      end
      if (dread_resp_fire && rlast)
      begin
        dread_valid[read_resp_slot] <= 1'b0;
        dread_ar_sent[read_resp_slot] <= 1'b0;
      end

      // AR 被接收时记录本地槽号，并在整个 burst 返回期间保持队首不变。
      // 最后一个 R beat 与新 AR 同拍时，计数保持不变，两个指针同时前进。
      if (iread_return_push)
      begin
        iread_return_order[iread_return_tail] <= ar_select_slot;
        iread_return_tail <= iread_return_tail + 1'b1;
      end
      if (iread_return_pop)
        iread_return_head <= iread_return_head + 1'b1;
      case ({iread_return_push,iread_return_pop})
        2'b10: iread_return_count <= iread_return_count + 1'b1;
        2'b01: iread_return_count <= iread_return_count - 1'b1;
        default: iread_return_count <= iread_return_count;
      endcase

      if (dread_return_push)
      begin
        dread_return_order[dread_return_tail] <= ar_select_slot;
        dread_return_tail <= dread_return_tail + 1'b1;
      end
      if (dread_return_pop)
        dread_return_head <= dread_return_head + 1'b1;
      case ({dread_return_push,dread_return_pop})
        2'b10: dread_return_count <= dread_return_count + 1'b1;
        2'b01: dread_return_count <= dread_return_count - 1'b1;
        default: dread_return_count <= dread_return_count;
      endcase

      if (grant_icache_read || grant_ibypass_read)
      begin
        iread_valid[grant_icache_read ? icache_mem_id : 1'b0] <= 1'b1;
        iread_ar_sent[grant_icache_read ? icache_mem_id : 1'b0] <= 1'b0;
        iread_is_cache[grant_icache_read ? icache_mem_id : 1'b0] <=
            grant_icache_read;
        iread_addr[grant_icache_read ? icache_mem_id : 1'b0] <=
            grant_icache_read ? icache_mem_addr : inst_sram_addr;
        iread_size[grant_icache_read ? icache_mem_id : 1'b0] <=
            grant_icache_read ? icache_mem_size : inst_sram_size;
      end
      if (grant_dcache_read || grant_dbypass_read)
      begin
        dread_valid[grant_dcache_read ? dcache_mem_id : 1'b0] <= 1'b1;
        dread_ar_sent[grant_dcache_read ? dcache_mem_id : 1'b0] <= 1'b0;
        dread_is_cache[grant_dcache_read ? dcache_mem_id : 1'b0] <=
            grant_dcache_read;
        dread_addr[grant_dcache_read ? dcache_mem_id : 1'b0] <=
            grant_dcache_read ? dcache_mem_addr : data_sram_addr;
        dread_size[grant_dcache_read ? dcache_mem_id : 1'b0] <=
            grant_dcache_read ? dcache_mem_size : data_sram_size;
      end

      // 单 AR 输出寄存器在两个 pending context 间仲裁。D 具有固定优先级，
      // 但每侧只有一个 context，所以 D 发出后 I 下一拍即可获得通道。
      if (arvalid && arready)
      begin
        arvalid <= 1'b0;
        if (ar_select_d)
          dread_ar_sent[ar_select_slot] <= 1'b1;
        else
          iread_ar_sent[ar_select_slot] <= 1'b1;
      end
      else if (!arvalid)
      begin
        if (dread_valid[0] && !dread_ar_sent[0])
        begin
          ar_select_d <= 1'b1;
          ar_select_slot <= 1'b0;
          ar_is_cache <= dread_is_cache[0];
          arlen_r <= dread_is_cache[0] ? 8'd3 : 8'd0;
          araddr <= dread_addr[0];
          arsize <= {1'b0,dread_size[0]};
          arvalid <= 1'b1;
        end
        else if (iread_valid[0] && !iread_ar_sent[0])
        begin
          ar_select_d <= 1'b0;
          ar_select_slot <= 1'b0;
          ar_is_cache <= iread_is_cache[0];
          arlen_r <= iread_is_cache[0] ? 8'd3 : 8'd0;
          araddr <= iread_addr[0];
          arsize <= {1'b0,iread_size[0]};
          arvalid <= 1'b1;
        end
        else if (dread_valid[1] && !dread_ar_sent[1])
        begin
          ar_select_d <= 1'b1;
          ar_select_slot <= 1'b1;
          ar_is_cache <= dread_is_cache[1];
          arlen_r <= dread_is_cache[1] ? 8'd3 : 8'd0;
          araddr <= dread_addr[1];
          arsize <= {1'b0,dread_size[1]};
          arvalid <= 1'b1;
        end
        else if (iread_valid[1] && !iread_ar_sent[1])
        begin
          ar_select_d <= 1'b0;
          ar_select_slot <= 1'b1;
          ar_is_cache <= iread_is_cache[1];
          arlen_r <= iread_is_cache[1] ? 8'd3 : 8'd0;
          araddr <= iread_addr[1];
          arsize <= {1'b0,iread_size[1]};
          arvalid <= 1'b1;
        end
      end

      // 写地址和数据独立握手；写响应只释放 write context，不阻塞 read。
      if (grant_dcache_write || grant_dbypass_write)
      begin
        write_valid <= 1'b1;
        write_src <= grant_dcache_write ? SRC_DCACHE : SRC_DBYPASS;
        awaddr <= grant_dcache_write ? dcache_mem_addr : data_sram_addr;
        awsize <= {1'b0,(grant_dcache_write ? dcache_mem_size :
                        data_sram_size)};
        awvalid <= 1'b1;
        wdata <= grant_dcache_write ? dcache_mem_wdata : data_sram_wdata;
        wstrb <= grant_dcache_write ? dcache_mem_wstrb : data_sram_wstrb;
        wvalid <= 1'b1;
      end
      if (awvalid && awready)
        awvalid <= 1'b0;
      if (wvalid && wready)
        wvalid <= 1'b0;
      if (axi_write_ok)
        write_valid <= 1'b0;
    end
  end

endmodule
