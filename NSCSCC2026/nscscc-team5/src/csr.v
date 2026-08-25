// =============================================================================
// LoongArch 控制状态寄存器（CSR）文件
// =============================================================================
// 本模块集中维护处理器的特权架构状态，包括：当前/异常前模式、中断控制、
// 异常入口与返回地址、定时器、LL/SC 保留位、TLB 软件可见寄存器和 DMW 窗口。
//
// 写口支持掩码语义：new = (old & ~wmask) | (wvalue & wmask)，可同时实现 CSRWR
// 与 CSRXCHG。不同 CSR 只截取架构允许写入的位，保留位始终读 0 或保持规定值。
// 异常和 ERTN 对特权状态的更新优先于同拍软件写入，从而保证精确异常语义。
//
// 时序边界：所有架构状态仅在 clk 上升沿更新；csr_rvalue、has_int、异常入口及
// TLB 配置输出均为当前状态的组合视图。diff_csrs 只用于观察，不参与控制。
// =============================================================================
module CPU_CSR(
    input clk,                    // CSR 状态时钟。
    input rst,                    // 高有效同步复位。
    input [7:0] hw_int_in,        // ESTAT.IS[9:2] 的八路外部硬件中断电平。

    // 流水线提交级 CSR 读写端口。
    input [13:0] csr_num,         // LoongArch 14 位 CSR 地址。
    input [31:0] csr_wvalue,      // 待写数据；仅 wmask=1 的位生效。
    input [31:0] csr_wmask,       // 按位写掩码，CSRWR 通常为全 1。
    input csr_we,                 // 本拍提交 CSR 写操作。
    input csr_re,                 // 读使能；为 0 时 csr_rvalue 强制为 0。

    // 精确异常/返回接口，均只在对应指令到达 WB 提交点时拉高。
    input ertn_en,                // 执行 ERTN：恢复 PRMD 中的 PLV/IE。
    input exc_en,                 // 提交异常：保存 ERA/ESTAT/BADV 并进入 PLV0。
    input [5:0] exc_ecode,        // ESTAT.Ecode 以及异常入口选择依据。
    input [8:0] exc_esubcode,     // ESTAT.EsubCode；ADEF/ADEM 等由此进一步区分。
    input [31:0] exc_pc,          // 触发异常的指令 PC，写入 ERA。
    input [31:0] exc_vaddr,       // 地址类异常的坏虚地址，必要时写入 BADV/TLBEHI。
    input [14:0] exc_code,        // 流水线内部 one-hot 异常向量；当前实现保留作接口。
    input llbit_set,              // LL 指令提交后建立 LLBit。
    input llbit_clear,            // SC 或显式事件清除 LLBit。

    // TLB 查询/读指令回写接口：TLBSRCH 更新 TLBIDX，TLBRD 更新整组 TLB CSR。
    input        tlbsrch_wen,
    input        tlbsrch_hit,
    input [4:0]  tlbsrch_hit_index,
    input        s1_found,
    input        tlbrd_we,
    input        tlbrd_e,
    input [18:0] tlbrd_vppn,
    input [5:0]  tlbrd_ps,
    input [9:0]  tlbrd_asid,
    input        tlbrd_g,
    input [19:0] tlbrd_ppn0,
    input [1:0]  tlbrd_plv0,
    input [1:0]  tlbrd_mat0,
    input        tlbrd_d0,
    input        tlbrd_v0,
    input [19:0] tlbrd_ppn1,
    input [1:0]  tlbrd_plv1,
    input [1:0]  tlbrd_mat1,
    input        tlbrd_d1,
    input        tlbrd_v1,

    // 输出到地址翻译/TLB 写端口；均为软件可见 CSR 的字段化视图。
    output [9:0]  csr_asid,
    output [18:0] csr_tlbehi_vppn,
    output [4:0]  csr_tlbidx_index,
    output        csr_crmd_da,
    output        csr_crmd_pg,
    output [1:0]  csr_crmd_plv,
    output [1:0]  csr_crmd_datf,
    output [1:0]  csr_crmd_datm,
    output [31:0] csr_dmw0_out,
    output [31:0] csr_dmw1_out,
    output [31:0] csr_tlbelo0_out,
    output [31:0] csr_tlbelo1_out,
    output [31:0] csr_tlbidx_out,
    output [31:0] csr_tlbehi_out,
    output [31:0] csr_tlbrentry_out,
    output csr_llbit,
    output [5:0] csr_estat_ecode_out,

    output has_int,               // CRMD.IE=1 且任一使能中断 pending 时为 1。
    output [31:0] csr_rvalue,     // csr_num 选中的 CSR 当前读值。
    output [31:0] ertn_pc,        // 异常返回地址，即 ERA。
    output [31:0] ex_entry,       // 普通异常取 EENTRY，TLB refill 取 TLBRENTRY。
    output [831:0] diff_csrs      // 26 个 32 位 CSR 的差分测试快照。
  );

  // ---------------------------------------------------------------------------
  // CSR 地址与本模块直接使用的异常编码
  // ---------------------------------------------------------------------------
  // 地址值遵循 LoongArch32 CSR 编码。EUEN/CPUID/CTAG 目前没有可变状态，读
  // 多路器对未实现地址返回 0；保留 localparam 便于与架构手册及后续扩展对照。
  localparam [13:0] CSR_CRMD      = 14'h0000;
  localparam [13:0] CSR_PRMD      = 14'h0001;
  localparam [13:0] CSR_EUEN      = 14'h0002;
  localparam [13:0] CSR_ECFG      = 14'h0004;
  localparam [13:0] CSR_ESTAT     = 14'h0005;
  localparam [13:0] CSR_ERA       = 14'h0006;
  localparam [13:0] CSR_BADV      = 14'h0007;
  localparam [13:0] CSR_EENTRY    = 14'h000c;
  localparam [13:0] CSR_TLBIDX    = 14'h0010;
  localparam [13:0] CSR_TLBEHI    = 14'h0011;
  localparam [13:0] CSR_TLBLO0    = 14'h0012;
  localparam [13:0] CSR_TLBLO1    = 14'h0013;
  localparam [13:0] CSR_ASID      = 14'h0018;
  localparam [13:0] CSR_PGDL      = 14'h0019;
  localparam [13:0] CSR_PGDH      = 14'h001A;
  localparam [13:0] CSR_PGD       = 14'h001B;
  localparam [13:0] CSR_CPUID     = 14'h0020;
  localparam [13:0] CSR_SAVE0     = 14'h0030;
  localparam [13:0] CSR_SAVE1     = 14'h0031;
  localparam [13:0] CSR_SAVE2     = 14'h0032;
  localparam [13:0] CSR_SAVE3     = 14'h0033;
  localparam [13:0] CSR_TID       = 14'h0040;
  localparam [13:0] CSR_TCFG      = 14'h0041;
  localparam [13:0] CSR_TVAL      = 14'h0042;
  localparam [13:0] CSR_TICLR     = 14'h0044;
  localparam [13:0] CSR_LLBCTL    = 14'h0060;
  localparam [13:0] CSR_TLBRENTRY = 14'h0088;
  localparam [13:0] CSR_CTAG      = 14'h0098;
  localparam [13:0] CSR_DMW0      = 14'h0180;
  localparam [13:0] CSR_DMW1      = 14'h0181;
  localparam [5:0]  ECODE_PME     = 6'h04;
  localparam [5:0]  ECODE_ADE     = 6'h08;
  localparam [5:0]  ECODE_ALE     = 6'h09;
  localparam [8:0]  ESUBCODE_ADEF = 9'h000;

  // 通用掩码写函数。调用处还会用常数掩码过滤各 CSR 的只读/保留位。
  function [31:0] merge_mask;
    input [31:0] old_value;
    input [31:0] wmask;
    input [31:0] wvalue;
    begin
      merge_mask = (old_value & ~wmask) | (wvalue & wmask);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // 架构状态寄存器的内部字段
  // ---------------------------------------------------------------------------
  // CRMD：PLV[1:0] 当前特权级，IE[2] 全局中断使能，DA/PG[3:4] 选择直接地址
  // 或分页模式，DATF/DATM[6:5]/[8:7] 给出直接地址模式下的取指/数据存储属性。
  reg [1:0]  csr_crmd_plv_reg;
  reg        csr_crmd_ie;
  reg        csr_crmd_da_reg;
  reg        csr_crmd_pg_reg;
  reg [1:0]  csr_crmd_datf_reg;
  reg [1:0]  csr_crmd_datm_reg;

  // PRMD 保存异常发生前的 PLV 和 IE，ERTN 用它恢复执行上下文。
  reg [1:0]  csr_prmd_pplv;
  reg        csr_prmd_pie;

  // ECFG.LIE 是 13 位局部中断使能；ESTAT 中软件、硬件和定时器 pending
  // 位与其逐位相与后再受 CRMD.IE 总开关控制。
  reg [12:0] csr_ecfg_lie;

  reg [1:0]  csr_estat_sw_int;
  reg        csr_estat_timer_int;

  // ESTAT.Ecode/EsubCode 只在异常提交时覆盖，普通 CSR 写仅能修改软件中断位。
  reg [5:0]  csr_estat_ecode;
  reg [8:0]  csr_estat_esubcode;

  // 异常地址、异常入口、页表基址、软件保存区和线程 ID。
  reg [31:0] csr_era_pc;
  reg [31:0] csr_badv_vaddr;
  reg [25:0] csr_eentry_va;
  reg [31:0] csr_pgdl;
  reg [31:0] csr_pgdh;
  reg [31:0] csr_save0_data;
  reg [31:0] csr_save1_data;
  reg [31:0] csr_save2_data;
  reg [31:0] csr_save3_data;
  reg [31:0] csr_tid_tid;

  // 定时器：TCFG.InitVal 以 4 个时钟为单位，装载时在低位补 00；TVAL 是实际
  // 递减值。关闭时以 0xffff_ffff 作为哨兵，防止误产生 timer interrupt。
  reg        csr_tcfg_en;
  reg        csr_tcfg_periodic;
  reg [29:0] csr_tcfg_initval;
  reg [31:0] timer_cnt;

  // LLBCTL.ROLLB 在本核中作为架构 LLBit；KLO 控制 ERTN 是否保留该位。
  reg        csr_llbctl_rollb;
  reg        csr_llbctl_klo;

  // TLB 相关寄存器。TLBELO0/1 保存偶/奇页 PPN、G、MAT、PLV、D、V 属性；
  // TLBIDX 保存 NE[31]、PS[29:24]、Index[4:0]；TLBEHI 保存 VPPN[31:13]。
  reg [31:0] csr_tlbidx;
  reg [31:0] csr_tlbehi;
  reg [31:0] csr_tlbelo0;
  reg [31:0] csr_tlbelo1;
  reg [31:0] csr_asid_reg;
  reg [31:0] csr_dmw0;
  reg [31:0] csr_dmw1;
  reg [31:0] csr_tlbrentry;

  // 仿真健壮性：顶层未连接或测试平台初始化前的 X 不应凭空触发中断，也不应
  // 通过 TLBSRCH/TLBRD 把未知值永久写进 CSR 状态。综合后正常 0/1 输入不变。
  wire [7:0] hw_int_level = (^hw_int_in===1'bx) ? 8'b0 : hw_int_in;

  // intrpt[3] 是持续时间有限的 NAND 中断，对应 Linux 分发使用的 ESTAT.IS[5]。
  // 保存其上升沿直到中断提交；service 快照让处理程序仍能识别中断源。
  localparam [7:0] HW_INT_EDGE_MASK = 8'b0000_1000;
  reg  [7:0] hw_int_level_q;
  reg  [7:0] hw_int_pending_q;
  reg  [7:0] hw_int_service_q;
  wire [7:0] hw_int_rise = hw_int_level & ~hw_int_level_q &
                            HW_INT_EDGE_MASK;
  wire       exc_is_interrupt = exc_en && (exc_ecode == 6'h00);
  wire [7:0] csr_estat_hw_int = hw_int_level |
                                hw_int_pending_q |
                                hw_int_service_q;

  always @(posedge clk)
  begin
    if (rst)
    begin
      hw_int_level_q   <= 8'b0;
      hw_int_pending_q <= 8'b0;
      hw_int_service_q <= 8'b0;
    end
    else
    begin
      hw_int_level_q <= hw_int_level;

      if (exc_is_interrupt)
      begin
        hw_int_service_q <= (hw_int_service_q |
                             hw_int_pending_q |
                             hw_int_level) & HW_INT_EDGE_MASK;
        hw_int_pending_q <= 8'b0;
      end
      else
      begin
        hw_int_pending_q <= hw_int_pending_q | hw_int_rise;
        if (ertn_en)
          hw_int_service_q <= 8'b0;
      end
    end
  end

  wire        tlbsrch_hit_clean;
  wire [4:0]  tlbsrch_hit_index_clean;
  assign tlbsrch_hit_clean = (tlbsrch_hit === 1'bx) ? 1'b0 : tlbsrch_hit;
  assign tlbsrch_hit_index_clean = (^tlbsrch_hit_index === 1'bx) ? 5'b0 : tlbsrch_hit_index;

  wire        tlbrd_e_clean;
  wire [18:0] tlbrd_vppn_clean;
  wire [5:0]  tlbrd_ps_clean;
  wire [9:0]  tlbrd_asid_clean;
  wire        tlbrd_g_clean;
  wire [19:0] tlbrd_ppn0_clean, tlbrd_ppn1_clean;
  wire [1:0]  tlbrd_plv0_clean, tlbrd_mat0_clean, tlbrd_plv1_clean, tlbrd_mat1_clean;
  wire        tlbrd_d0_clean, tlbrd_v0_clean, tlbrd_d1_clean, tlbrd_v1_clean;
  assign tlbrd_e_clean     = (tlbrd_e === 1'bx) ? 1'b0 : tlbrd_e;
  assign tlbrd_vppn_clean  = (^tlbrd_vppn === 1'bx) ? 19'b0 : tlbrd_vppn;
  assign tlbrd_ps_clean    = (^tlbrd_ps === 1'bx) ? 6'b0 : tlbrd_ps;
  assign tlbrd_asid_clean  = (^tlbrd_asid === 1'bx) ? 10'b0 : tlbrd_asid;
  assign tlbrd_g_clean     = (tlbrd_g === 1'bx) ? 1'b0 : tlbrd_g;
  assign tlbrd_ppn0_clean  = (^tlbrd_ppn0 === 1'bx) ? 20'b0 : tlbrd_ppn0;
  assign tlbrd_ppn1_clean  = (^tlbrd_ppn1 === 1'bx) ? 20'b0 : tlbrd_ppn1;
  assign tlbrd_plv0_clean  = (^tlbrd_plv0 === 1'bx) ? 2'b0 : tlbrd_plv0;
  assign tlbrd_mat0_clean  = (^tlbrd_mat0 === 1'bx) ? 2'b0 : tlbrd_mat0;
  assign tlbrd_plv1_clean  = (^tlbrd_plv1 === 1'bx) ? 2'b0 : tlbrd_plv1;
  assign tlbrd_mat1_clean  = (^tlbrd_mat1 === 1'bx) ? 2'b0 : tlbrd_mat1;
  assign tlbrd_d0_clean    = (tlbrd_d0 === 1'bx) ? 1'b0 : tlbrd_d0;
  assign tlbrd_v0_clean    = (tlbrd_v0 === 1'bx) ? 1'b0 : tlbrd_v0;
  assign tlbrd_d1_clean    = (tlbrd_d1 === 1'bx) ? 1'b0 : tlbrd_d1;
  assign tlbrd_v1_clean    = (tlbrd_v1 === 1'bx) ? 1'b0 : tlbrd_v1;

  // ESTAT.IS[12:0] 布局：{保留,TI,IPI保留,HWI[7:0],SWI[1:0]}。
  wire [12:0] csr_estat_is = {1'b0, csr_estat_timer_int, 1'b0, csr_estat_hw_int, csr_estat_sw_int};

  // ---------------------------------------------------------------------------
  // 各 CSR 的规范化 32 位读值
  // ---------------------------------------------------------------------------
  // 分散保存字段便于逐项更新；这里按架构位域重新拼接，并将未实现/保留位补 0。
  wire [31:0] csr_crmd_rvalue   = {23'b0, csr_crmd_datm_reg, csr_crmd_datf_reg, csr_crmd_pg_reg, csr_crmd_da_reg, csr_crmd_ie, csr_crmd_plv_reg};
  wire [31:0] csr_prmd_rvalue   = {29'b0, csr_prmd_pie, csr_prmd_pplv};
  wire [31:0] csr_ecfg_rvalue   = {19'b0, csr_ecfg_lie};
  wire [31:0] csr_estat_rvalue  = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
  wire [31:0] csr_era_rvalue    = csr_era_pc;
  wire [31:0] csr_badv_rvalue   = csr_badv_vaddr;
  wire [31:0] csr_eentry_rvalue = {csr_eentry_va, 6'b0};
  wire [31:0] csr_tcfg_rvalue   = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
  wire [31:0] csr_tval_rvalue   = timer_cnt;
  wire [31:0] csr_ticlr_rvalue  = 32'b0;
  wire [31:0] csr_llbctl_rvalue = {29'b0, csr_llbctl_klo, 1'b0, csr_llbctl_rollb};
  wire [31:0] csr_tlbidx_rvalue = csr_tlbidx;
  wire [31:0] csr_tlbehi_rvalue = {csr_tlbehi[31:13], 13'b0};
  wire [31:0] csr_tlbelo0_rvalue = csr_tlbelo0;
  wire [31:0] csr_tlbelo1_rvalue = csr_tlbelo1;
  wire [31:0] csr_asid_rvalue   = csr_asid_reg;
  wire [31:0] csr_pgdl_rvalue   = csr_pgdl;
  wire [31:0] csr_pgdh_rvalue   = csr_pgdh;
  wire [31:0] csr_pgd_rvalue    = csr_badv_vaddr[31] ? csr_pgdh_rvalue : csr_pgdl_rvalue;
  wire [31:0] csr_dmw0_rvalue   = csr_dmw0;
  wire [31:0] csr_dmw1_rvalue   = csr_dmw1;
  wire [31:0] csr_tlbrentry_rvalue = csr_tlbrentry;

  // ---------------------------------------------------------------------------
  // 软件写入后的候选值
  // ---------------------------------------------------------------------------
  // next 线只做“旧值+掩码”计算，真正是否写入、以及异常/硬件事件的优先级由
  // 后面的各时序块决定。附加常数掩码明确禁止写入架构保留位。
  wire [31:0] csr_crmd_next    = merge_mask(csr_crmd_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_prmd_next    = merge_mask(csr_prmd_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_ecfg_next    = merge_mask(csr_ecfg_rvalue, csr_wmask & 32'h0000_1bff, csr_wvalue & 32'h0000_1bff);
  wire [31:0] csr_estat_next   = merge_mask(csr_estat_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_era_next     = merge_mask(csr_era_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_badv_next    = merge_mask(csr_badv_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_eentry_next  = merge_mask(csr_eentry_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_save0_next   = merge_mask(csr_save0_data, csr_wmask, csr_wvalue);
  wire [31:0] csr_save1_next   = merge_mask(csr_save1_data, csr_wmask, csr_wvalue);
  wire [31:0] csr_save2_next   = merge_mask(csr_save2_data, csr_wmask, csr_wvalue);
  wire [31:0] csr_save3_next   = merge_mask(csr_save3_data, csr_wmask, csr_wvalue);
  wire [31:0] csr_tid_next     = merge_mask(csr_tid_tid, csr_wmask, csr_wvalue);
  wire [31:0] csr_tcfg_next    = merge_mask(csr_tcfg_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_llbctl_next  = merge_mask(csr_llbctl_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_tlbidx_next  = merge_mask(csr_tlbidx_rvalue, csr_wmask & 32'hbf00_001f, csr_wvalue & 32'hbf00_001f);
  wire [31:0] csr_tlbehi_next  = merge_mask(csr_tlbehi_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_tlbelo0_next = merge_mask(csr_tlbelo0_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_tlbelo1_next = merge_mask(csr_tlbelo1_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_asid_next    = merge_mask(csr_asid_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_pgdl_next    = merge_mask(csr_pgdl_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_pgdh_next    = merge_mask(csr_pgdh_rvalue, csr_wmask, csr_wvalue);
  wire [31:0] csr_dmw0_next    = merge_mask(csr_dmw0_rvalue, csr_wmask & 32'hee00_0039, csr_wvalue & 32'hee00_0039);
  wire [31:0] csr_dmw1_next    = merge_mask(csr_dmw1_rvalue, csr_wmask & 32'hee00_0039, csr_wvalue & 32'hee00_0039);
  wire [31:0] csr_tlbrentry_next = merge_mask(csr_tlbrentry_rvalue, csr_wmask & 32'hffff_ffc0, csr_wvalue & 32'hffff_ffc0);
  // TLB refill、页无效、权限、修改例外等地址翻译异常会把坏地址的 VPPN 写入
  // TLBEHI，供异常处理程序直接构造或查询页表项。
  wire        exc_tlbehi_fill  = exc_en && (
                (exc_ecode == 6'h3f) ||
                (exc_ecode == 6'h01) ||
                (exc_ecode == 6'h02) ||
                (exc_ecode == 6'h03) ||
                (exc_ecode == 6'h04) ||
                (exc_ecode == 6'h07)
              );
  // 只有携带有意义坏地址的异常才更新 BADV，避免普通系统调用等覆盖旧诊断信息。
  wire        exc_addr_err     = (exc_ecode==ECODE_ADE) || (exc_ecode==ECODE_ALE)
              || (exc_ecode==ECODE_PME)
              || (exc_ecode==6'h3f) || (exc_ecode==6'h01)
              || (exc_ecode==6'h02) || (exc_ecode==6'h03)
              || (exc_ecode==6'h07);

  reg [31:0] csr_rvalue_r;

  // 异常入口选择使用“本拍正在提交的异常编码”：TLBR(0x3f) 进入专用 refill
  // 入口，其余异常进入通用 EENTRY。has_int 只报告可屏蔽中断，不直接提交异常。
  assign ertn_pc = csr_era_pc;
  assign ex_entry = (exc_ecode == 6'h3f) ? csr_tlbrentry : csr_eentry_rvalue;
  assign has_int = ((csr_estat_is & csr_ecfg_lie)!=13'b0) && csr_crmd_ie;

  // TLB 输出
  assign csr_asid          = csr_asid_reg[9:0];
  assign csr_tlbehi_vppn   = csr_tlbehi[31:13];
  assign csr_tlbidx_index  = csr_tlbidx[4:0];
  assign csr_crmd_da       = csr_crmd_da_reg;
  assign csr_crmd_pg       = csr_crmd_pg_reg;
  assign csr_crmd_plv      = csr_crmd_plv_reg;
  assign csr_crmd_datf     = csr_crmd_datf_reg;
  assign csr_crmd_datm     = csr_crmd_datm_reg;
  assign csr_dmw0_out      = csr_dmw0;
  assign csr_dmw1_out      = csr_dmw1;
  assign csr_tlbelo0_out   = csr_tlbelo0;
  assign csr_tlbelo1_out   = csr_tlbelo1;
  assign csr_tlbidx_out    = csr_tlbidx;
  assign csr_tlbehi_out    = csr_tlbehi;
  assign csr_tlbrentry_out = csr_tlbrentry;
  assign csr_llbit         = csr_llbctl_rollb;
  assign csr_estat_ecode_out = csr_estat_ecode;

  // 差分测试总线的切片顺序是项目约定，不是 CSR 地址顺序。每项均使用规范化
  // read-value，确保保留位为 0；PGD 是 BADV 选择出的别名，因此不单独导出。
  assign diff_csrs[0*32 +: 32]  = csr_crmd_rvalue;
  assign diff_csrs[1*32 +: 32]  = csr_prmd_rvalue;
  assign diff_csrs[2*32 +: 32]  = csr_ecfg_rvalue;
  assign diff_csrs[3*32 +: 32]  = csr_estat_rvalue;
  assign diff_csrs[4*32 +: 32]  = csr_era_rvalue;
  assign diff_csrs[5*32 +: 32]  = csr_badv_rvalue;
  assign diff_csrs[6*32 +: 32]  = csr_eentry_rvalue;
  assign diff_csrs[7*32 +: 32]  = csr_tlbidx_rvalue;
  assign diff_csrs[8*32 +: 32]  = csr_tlbehi_rvalue;
  assign diff_csrs[9*32 +: 32]  = csr_tlbelo0_rvalue;
  assign diff_csrs[10*32 +: 32] = csr_tlbelo1_rvalue;
  assign diff_csrs[11*32 +: 32] = csr_asid_rvalue;
  assign diff_csrs[12*32 +: 32] = csr_pgdl_rvalue;
  assign diff_csrs[13*32 +: 32] = csr_pgdh_rvalue;
  assign diff_csrs[14*32 +: 32] = csr_save0_data;
  assign diff_csrs[15*32 +: 32] = csr_save1_data;
  assign diff_csrs[16*32 +: 32] = csr_save2_data;
  assign diff_csrs[17*32 +: 32] = csr_save3_data;
  assign diff_csrs[18*32 +: 32] = csr_tid_tid;
  assign diff_csrs[19*32 +: 32] = csr_tcfg_rvalue;
  assign diff_csrs[20*32 +: 32] = csr_tval_rvalue;
  assign diff_csrs[21*32 +: 32] = csr_ticlr_rvalue;
  assign diff_csrs[22*32 +: 32] = csr_llbctl_rvalue;
  assign diff_csrs[23*32 +: 32] = csr_tlbrentry_rvalue;
  assign diff_csrs[24*32 +: 32] = csr_dmw0_rvalue;
  assign diff_csrs[25*32 +: 32] = csr_dmw1_rvalue;

  // CRMD 寄存器更新。
  // 异常强制进入 PLV0 并关中断；TLB refill 还临时切到 DA=1/PG=0，使 refill
  // 处理程序无需可用 TLB 即可执行。若从 TLBR 返回，则恢复 DA=0/PG=1。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_crmd_plv_reg  <= 2'b0;
      csr_crmd_ie       <= 1'b0;
      csr_crmd_da_reg   <= 1'b1;
      csr_crmd_pg_reg   <= 1'b0;
      csr_crmd_datf_reg <= 2'b0;
      csr_crmd_datm_reg <= 2'b0;
    end
    else if(exc_en)
    begin
      csr_crmd_plv_reg <= 2'b0;
      csr_crmd_ie      <= 1'b0;
      if(exc_ecode == 6'h3f)
      begin
        csr_crmd_da_reg <= 1'b1;
        csr_crmd_pg_reg <= 1'b0;
      end
    end
    else if(ertn_en)
    begin
      csr_crmd_plv_reg <= csr_prmd_pplv;
      csr_crmd_ie      <= csr_prmd_pie;
      if(csr_estat_ecode == 6'h3f)
      begin
        csr_crmd_da_reg <= 1'b0;
        csr_crmd_pg_reg <= 1'b1;
      end
    end
    else if(csr_we && csr_num==CSR_CRMD)
    begin
      csr_crmd_plv_reg  <= csr_crmd_next[1:0];
      csr_crmd_ie       <= csr_crmd_next[2];
      csr_crmd_da_reg   <= csr_crmd_next[3];
      csr_crmd_pg_reg   <= csr_crmd_next[4];
      csr_crmd_datf_reg <= csr_crmd_next[6:5];
      csr_crmd_datm_reg <= csr_crmd_next[8:7];
    end
  end

  // PRMD 寄存器更新：异常入口先保存 CRMD.PLV/IE，之后才由 CRMD 时序块降权。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_prmd_pplv <= 2'b0;
      csr_prmd_pie  <= 1'b0;
    end
    else if(exc_en)
    begin
      csr_prmd_pplv <= csr_crmd_plv_reg;
      csr_prmd_pie  <= csr_crmd_ie;
    end
    else if(csr_we && csr_num==CSR_PRMD)
    begin
      csr_prmd_pplv <= csr_prmd_next[1:0];
      csr_prmd_pie  <= csr_prmd_next[2];
    end
  end

  // ECFG 寄存器更新：只实现架构定义的 LIE 位，保留的 bit10 固定清零。
  always @(posedge clk)
  begin
    if(rst)
      csr_ecfg_lie <= 13'b0;
    else if(csr_we && csr_num==CSR_ECFG)
      csr_ecfg_lie <= {csr_ecfg_next[12:11], 1'b0, csr_ecfg_next[9:0]};
  end

  // ESTAT 寄存器更新：异常编码、软件中断和定时器中断具有独立写入来源。
  // timer_cnt 到 0 置位 TI；向 TICLR.CLR 写 1 清除，写 0 不产生副作用。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_estat_sw_int    <= 2'b0;
      csr_estat_timer_int <= 1'b0;
      csr_estat_ecode     <= 6'b0;
      csr_estat_esubcode  <= 9'b0;
    end
    else
    begin
      if(exc_en)
      begin
        csr_estat_ecode    <= exc_ecode;
        csr_estat_esubcode <= exc_esubcode;
      end

      if(csr_we && csr_num==CSR_ESTAT)
        csr_estat_sw_int <= csr_estat_next[1:0];

      if(timer_cnt==32'b0)
        csr_estat_timer_int <= 1'b1;
      else if(csr_we && csr_num==CSR_TICLR && csr_wmask[0] && csr_wvalue[0])
        csr_estat_timer_int <= 1'b0;
    end
  end

  // ERA 寄存器更新：异常提交优先于软件写，保证保存真正的 faulting PC。
  always @(posedge clk)
  begin
    if(rst)
      csr_era_pc <= 32'b0;
    else if(exc_en)
      csr_era_pc <= exc_pc;
    else if(csr_we && csr_num==CSR_ERA)
      csr_era_pc <= csr_era_next;
  end

  // BADV 寄存器更新：ADEF 的坏地址是 exc_pc，其他地址类异常使用 exc_vaddr。
  always @(posedge clk)
  begin
    if(rst)
      csr_badv_vaddr <= 32'b0;
    else if(exc_en && exc_addr_err)
      csr_badv_vaddr <= (exc_ecode==ECODE_ADE && exc_esubcode==ESUBCODE_ADEF) ? exc_pc : exc_vaddr;
    else if(csr_we && csr_num==CSR_BADV)
      csr_badv_vaddr <= csr_badv_next;
  end

  // EENTRY 寄存器更新：入口要求 64 字节对齐，因此仅保存 [31:6]。
  always @(posedge clk)
  begin
    if(rst)
      csr_eentry_va <= 26'b0;
    else if(csr_we && csr_num==CSR_EENTRY)
      csr_eentry_va <= csr_eentry_next[31:6];
  end

  // SAVE0~SAVE3 是完全由软件管理的 32 位暂存寄存器，通常供异常处理程序使用。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_save0_data <= 32'b0;
      csr_save1_data <= 32'b0;
      csr_save2_data <= 32'b0;
      csr_save3_data <= 32'b0;
    end
    else
    begin
      if(csr_we && csr_num==CSR_SAVE0)
        csr_save0_data <= csr_save0_next;
      if(csr_we && csr_num==CSR_SAVE1)
        csr_save1_data <= csr_save1_next;
      if(csr_we && csr_num==CSR_SAVE2)
        csr_save2_data <= csr_save2_next;
      if(csr_we && csr_num==CSR_SAVE3)
        csr_save3_data <= csr_save3_next;
    end
  end

  // TID 为软件可写定时器/线程标识，本实现复位为 0。
  always @(posedge clk)
  begin
    if(rst)
      csr_tid_tid <= 32'b0;
    else if(csr_we && csr_num==CSR_TID)
      csr_tid_tid <= csr_tid_next;
  end

  // TCFG 记录 enable、periodic 和 30 位 InitVal；实际计数器在下一时序块装载。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_tcfg_en       <= 1'b0;
      csr_tcfg_periodic <= 1'b0;
      csr_tcfg_initval  <= 30'b0;
    end
    else if(csr_we && csr_num==CSR_TCFG)
    begin
      csr_tcfg_en       <= csr_tcfg_next[0];
      csr_tcfg_periodic <= csr_tcfg_next[1];
      csr_tcfg_initval  <= csr_tcfg_next[31:2];
    end
  end

  // TVAL/Timer 计数器更新。写 TCFG 时立即重装；周期模式到 0 后重装，
  // 单次模式则从 0 下溢到全 1 并停在哨兵值，不会反复触发。
  always @(posedge clk)
  begin
    if(rst)
      timer_cnt <= 32'hffff_ffff;
    else if(csr_we && csr_num==CSR_TCFG)
      timer_cnt <= csr_tcfg_next[0] ? {csr_tcfg_next[31:2], 2'b0} : 32'hffff_ffff;
    else if(csr_tcfg_en && timer_cnt!=32'hffff_ffff)
    begin
      if(timer_cnt==32'b0 && csr_tcfg_periodic)
        timer_cnt <= {csr_tcfg_initval, 2'b0};
      else
        timer_cnt <= timer_cnt - 1'b1;
    end
  end

  // LLBCTL/LLBit 更新优先级：ERTN 处理 > LL 建立 > SC/事件清除 > 软件写。
  // 软件只能通过 WCLLB 清零 ROLLB，不能伪造一个有效 reservation。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_llbctl_rollb <= 1'b0;
      csr_llbctl_klo   <= 1'b0;
    end
    else if(ertn_en)
    begin
      if(!csr_llbctl_klo)
        csr_llbctl_rollb <= 1'b0;
      else
        csr_llbctl_klo <= 1'b0;
    end
    else if(llbit_set)
      csr_llbctl_rollb <= 1'b1;
    else if(llbit_clear)
      csr_llbctl_rollb <= 1'b0;
    else if(csr_we && csr_num==CSR_LLBCTL)
    begin
      if(csr_llbctl_next[1])
        csr_llbctl_rollb <= 1'b0;
      // ROLLB/LLBit 不能由软件直接置 1；WCLLB 只允许清除。
      csr_llbctl_klo <= csr_llbctl_next[2];
    end
  end

  // TLB 相关寄存器更新。优先级为异常自动填 TLBEHI（可与后续字段更新并存）、
  // TLBSRCH 硬件结果、TLBRD 硬件结果、最后才是普通 CSR 软件写。
  always @(posedge clk)
  begin
    if(rst)
    begin
      csr_tlbidx    <= 32'h0;
      csr_tlbehi    <= 32'h0;
      csr_tlbelo0   <= 32'h0;
      csr_tlbelo1   <= 32'h0;
      csr_asid_reg  <= 32'h000a0000;
      csr_pgdl      <= 32'h0;
      csr_pgdh      <= 32'h0;
      csr_dmw0      <= 32'h0;
      csr_dmw1      <= 32'h0;
      csr_tlbrentry <= 32'h0;
    end
    else
    begin
      if (exc_tlbehi_fill)
        csr_tlbehi[31:13] <= exc_vaddr[31:13];

      // TLBSRCH：命中时 NE=0 并记录 index；未命中时只置 NE=1，旧 index 无意义。
      if (tlbsrch_wen)
      begin
        csr_tlbidx[31] <= ~tlbsrch_hit_clean;
        if (tlbsrch_hit_clean)
          csr_tlbidx[4:0] <= tlbsrch_hit_index_clean;
      end
      // TLBRD：有效条目完整回填 TLBEHI/TLBIDX/ASID/TLBELO0/1；无效条目除 NE
      // 外清零相关字段，避免软件把上一次读取残留误认为当前条目。
      else if (tlbrd_we)
      begin
        csr_tlbidx[31] <= ~tlbrd_e_clean;
        if (tlbrd_e_clean)
        begin
          csr_tlbehi[31:13] <= tlbrd_vppn_clean;
          csr_tlbidx[29:24] <= tlbrd_ps_clean;
          csr_asid_reg[9:0] <= tlbrd_asid_clean;
          csr_tlbelo0 <= {tlbrd_ppn0_clean, 1'b0, tlbrd_g_clean, tlbrd_mat0_clean, tlbrd_plv0_clean, tlbrd_d0_clean, tlbrd_v0_clean};
          csr_tlbelo1 <= {tlbrd_ppn1_clean, 1'b0, tlbrd_g_clean, tlbrd_mat1_clean, tlbrd_plv1_clean, tlbrd_d1_clean, tlbrd_v1_clean};
        end
        else
        begin
          csr_tlbehi[31:13] <= 19'b0;
          csr_tlbidx[29:24] <= 6'b0;
          csr_asid_reg[9:0] <= 10'b0;
          csr_tlbelo0 <= 32'b0;
          csr_tlbelo1 <= 32'b0;
        end
      end
      // 软件 CSR 写：逐字段截取可写位，PGDL/PGDH 保持 4 KiB 对齐。
      else if (csr_we && !tlbrd_we)
      begin
        case (csr_num)
          CSR_TLBIDX:
          begin
            csr_tlbidx[31] <= csr_tlbidx_next[31];
            csr_tlbidx[29:24] <= csr_tlbidx_next[29:24];
            csr_tlbidx[4:0] <= csr_tlbidx_next[4:0];
          end
          CSR_TLBEHI:
            csr_tlbehi[31:13] <= csr_tlbehi_next[31:13];
          CSR_TLBLO0:
          begin
            csr_tlbelo0[27:8] <= csr_tlbelo0_next[27:8];
            csr_tlbelo0[6:0] <= csr_tlbelo0_next[6:0];
          end
          CSR_TLBLO1:
          begin
            csr_tlbelo1[27:8] <= csr_tlbelo1_next[27:8];
            csr_tlbelo1[6:0] <= csr_tlbelo1_next[6:0];
          end
          CSR_ASID:
            csr_asid_reg[9:0] <= csr_asid_next[9:0];
          CSR_PGDL:
            csr_pgdl <= {csr_pgdl_next[31:12], 12'b0};
          CSR_PGDH:
            csr_pgdh <= {csr_pgdh_next[31:12], 12'b0};
          CSR_DMW0:
            csr_dmw0 <= csr_dmw0_next;
          CSR_DMW1:
            csr_dmw1 <= csr_dmw1_next;
          CSR_TLBRENTRY:
            csr_tlbrentry <= csr_tlbrentry_next;
        endcase
      end
    end
  end

  // CSR 读取多路选择。组合块为每个地址完整赋值，default=0，因而不会推断锁存器。
  always @*
  begin
    case(csr_num)
      CSR_CRMD:
        csr_rvalue_r = csr_crmd_rvalue;
      CSR_PRMD:
        csr_rvalue_r = csr_prmd_rvalue;
      CSR_ECFG:
        csr_rvalue_r = csr_ecfg_rvalue;
      CSR_ESTAT:
        csr_rvalue_r = csr_estat_rvalue;
      CSR_ERA:
        csr_rvalue_r = csr_era_rvalue;
      CSR_BADV:
        csr_rvalue_r = csr_badv_rvalue;
      CSR_EENTRY:
        csr_rvalue_r = csr_eentry_rvalue;
      CSR_SAVE0:
        csr_rvalue_r = csr_save0_data;
      CSR_SAVE1:
        csr_rvalue_r = csr_save1_data;
      CSR_SAVE2:
        csr_rvalue_r = csr_save2_data;
      CSR_SAVE3:
        csr_rvalue_r = csr_save3_data;
      CSR_TID:
        csr_rvalue_r = csr_tid_tid;
      CSR_TCFG:
        csr_rvalue_r = csr_tcfg_rvalue;
      CSR_TVAL:
        csr_rvalue_r = csr_tval_rvalue;
      CSR_TICLR:
        csr_rvalue_r = csr_ticlr_rvalue;
      CSR_LLBCTL:
        csr_rvalue_r = csr_llbctl_rvalue;
      CSR_TLBIDX:
        csr_rvalue_r = csr_tlbidx_rvalue;
      CSR_TLBEHI:
        csr_rvalue_r = csr_tlbehi_rvalue;
      CSR_TLBLO0:
        csr_rvalue_r = csr_tlbelo0_rvalue;
      CSR_TLBLO1:
        csr_rvalue_r = csr_tlbelo1_rvalue;
      CSR_ASID:
        csr_rvalue_r = csr_asid_rvalue;
      CSR_PGDL:
        csr_rvalue_r = csr_pgdl_rvalue;
      CSR_PGDH:
        csr_rvalue_r = csr_pgdh_rvalue;
      CSR_PGD:
        csr_rvalue_r = csr_pgd_rvalue;
      CSR_DMW0:
        csr_rvalue_r = csr_dmw0_rvalue;
      CSR_DMW1:
        csr_rvalue_r = csr_dmw1_rvalue;
      CSR_TLBRENTRY:
        csr_rvalue_r = csr_tlbrentry_rvalue;
      default:
        csr_rvalue_r = 32'b0;
    endcase
  end

  // 读使能关闭时主动输出 0，减少无关 CSR 数据在旁路网络中的翻转与 X 传播。
  assign csr_rvalue = csr_re ? csr_rvalue_r : 32'b0;

endmodule
