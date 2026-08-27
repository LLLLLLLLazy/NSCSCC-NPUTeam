// ================================================================
//  MMU (Memory Management Unit) — 存储管理单元 (黑盒重构版)
//
//  功能: 将虚拟地址翻译为物理地址, 并检测页表相关异常
//        内部直接包裹例化 tlb.v，对外暴露双端口查询和 CSR 管理接口。
//
//  双端口结构:
//    - IF 端口 (inst_*): 用于取指级的地址翻译，没有特权级或写保护违规，只产生 PIF/TLBR
//    - MEM 端口 (data_*): 用于访存级的地址翻译，产生所有类型的异常
//
//  翻译模式 (按优先级):
//    ① 直接地址翻译 (DA)  : CRMD.DA=1, CRMD.PG=0  → PA = VA
//    ② 直接映射窗口 (DMW) : PG 模式下, VA[31:29] 匹配 DMW.VSEG → 直接映射
//    ③ TLB 翻译           : 上述均未命中 → 查 TLB, 可能触发异常
// ================================================================
`include "header.v"

module mmu (
    input  wire        clk,
    input  wire        resetn,

    // ── CSR 状态输入 ──────────────────────────────────────────
    input  wire [ 1:0] csr_crmd_plv,    // CRMD.PLV  当前特权等级
    input  wire        csr_crmd_da,     // CRMD.DA   直接地址翻译使能
    input  wire        csr_crmd_pg,     // CRMD.PG   页表翻译使能
    input  wire [ 1:0] csr_crmd_datf,   // CRMD.DATF 取指直接翻译 MAT
    input  wire [ 1:0] csr_crmd_datm,   // CRMD.DATM 访存直接翻译 MAT
    input  wire [31:0] csr_dmw0,   // DMW0 寄存器全值
    input  wire [31:0] csr_dmw1,   // DMW1 寄存器全值
    input  wire [ 9:0] csr_asid_asid,   // ASID.ASID 当前进程的 ASID
    //新增//TLBWR,TLBFILL
    input wire [21:16] csr_estat_ecode,

    input wire  [ 3:0] csr_tlbidx_index,
    input wire [29:24] csr_tlbidx_ps,
    input wire         csr_tlbidx_ne,
    
    input wire [31:13] csr_tlbehi_vppn,

    input wire         csr_tlbelo0_v,
    input wire         csr_tlbelo0_d,
    input wire  [ 3:2] csr_tlbelo0_plv,
    input wire  [ 5:4] csr_tlbelo0_mat,
    input wire         csr_tlbelo0_g,
    input wire  [27:8] csr_tlbelo0_ppn,

    input wire         csr_tlbelo1_v,
    input wire         csr_tlbelo1_d,
    input wire  [ 3:2] csr_tlbelo1_plv,
    input wire  [ 5:4] csr_tlbelo1_mat,
    input wire         csr_tlbelo1_g,
    input wire  [27:8] csr_tlbelo1_ppn,

    //新增，TLBRD
    output wire         out_csr_tlbelo0_v,
    output wire         out_csr_tlbelo0_d,
    output wire  [ 3:2] out_csr_tlbelo0_plv,
    output wire  [ 5:4] out_csr_tlbelo0_mat,
    output wire         out_csr_tlbelo0_g,
    output wire  [27:8] out_csr_tlbelo0_ppn,

    output wire         out_csr_tlbelo1_v,
    output wire         out_csr_tlbelo1_d,
    output wire  [ 3:2] out_csr_tlbelo1_plv,
    output wire  [ 5:4] out_csr_tlbelo1_mat,
    output wire         out_csr_tlbelo1_g,
    output wire  [27:8] out_csr_tlbelo1_ppn,

    output wire [29:24] out_csr_tlbidx_ps,
    output reg          out_csr_tlbidx_ne,
    output wire [31:13] out_csr_tlbehi_vppn,
    output wire  [9 :0] out_csr_asid_asid,

    output wire         tlbrd_hit,

    // ── 1. 取指 (IF) 翻译通道 ────────
    //取指不需要区分mem_type， 因为端口1只有读指令
    input  wire [31:0] inst_va,         // 取指虚地址
    output wire [31:0] inst_pa,         // 取指物理地址
    output wire [ 1:0] inst_mat,        // 取指 MAT (Cache管理用)
    output wire        inst_ex_tlbr,    // TLB 重填例外
    output wire        inst_ex_pif,     // 取指页无效例外
    output wire        inst_ex_ppi,     // 页特权等级不合规例外 (通常为0，但如果页表将取指设为高特权也可触发)

    // ── 2. 访存 (MEM) 翻译通道 ────────────────────────────────
    input  wire [31:0] data_va,         // 访存虚地址
    input  wire [ 1:0] data_mem_type,   // 2'b01=LOAD, 2'b10=STORE
    output wire [31:0] data_pa,         // 访存物理地址
    output wire [ 1:0] data_mat,        // 访存 MAT
    output wire        data_ex_tlbr,    // TLB 重填例外
    output wire        data_ex_pil,     // load 页无效例外
    output wire        data_ex_pis,     // store 页无效例外
    output wire        data_ex_ppi,     // 页特权等级不合规例外
    output wire        data_ex_pme,     // 页修改例外

    //5条TLB指令
    input wire is_tlbsrch,
    input wire is_tlbrd,
    input wire is_tlbwr,
    input wire is_tlbfill,
    input wire is_invtlb,
    input wire  [ 4:0] invtlb_op,
    input wire  [31:0] rj,
    input wire  [31:0] rk,

    // TLBSRCH 查找结果 (复用数据访存侧的虚地址 data_va 查找)
    output wire        tlbsrch_hit,   
    output wire  [ 3:0] out_csr_tlbidx_index,
    output wire [3:0] tlbfill_index
);

// ================================================================
//  操作类型常量
// ================================================================
localparam MEM_FETCH = 2'b00;
localparam MEM_LOAD  = 2'b01;
localparam MEM_STORE = 2'b10;

//计数器，随机，为了实现TLBFILL指令
reg [ 3:0] rand_index_tlbfill;
assign tlbfill_index= rand_index_tlbfill;

always @(posedge clk)begin
    if(!resetn)begin
        rand_index_tlbfill <= 4'b0;
    end
    else begin
        rand_index_tlbfill <= rand_index_tlbfill + 1'b1;
    end
end
// ================================================================
//  TLB 例化 (黑盒内部)
// ================================================================
// s0：取指
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_ppn;
wire [ 5:0] s0_ps;
wire [ 1:0] s0_plv;
wire [ 1:0] s0_mat;
wire        s0_d;
wire        s0_v;
wire [ 8:0] s0_pa_mid;   // PA[20:12] 已根据 ps4MB 预选 excellent

// s1：load/store（纯净，直连 data_va）
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_ppn;
wire [ 5:0] s1_ps;
wire [ 1:0] s1_plv;
wire [ 1:0] s1_mat;
wire        s1_d;
wire        s1_v;
wire [ 8:0] s1_pa_mid;   // PA[20:12] 已根据 ps4MB 预选， excellent

// s2：TLBSRCH 专用
wire        s2_found;
wire [ 3:0] s2_index;

// s3：INVTLB 专用
//INVTLB
wire invtlb_valid;
wire [ 9:0] invtlb_asid;
wire [18:0] invtlb_vppn;

assign invtlb_valid = is_invtlb;
//invtlb_op已经有了,下面解析两个操作数
assign invtlb_asid = rj[9:0];
assign invtlb_vppn = rk[31:13];//寄存器指定va

//TLBWR
wire [ 3:0] tlb_w_index;
wire        tlb_w_e;
wire [18:0] tlb_w_vppn;
wire [ 5:0] tlb_w_ps;

wire        tlb_we;
wire [ 9:0] tlb_w_asid;
wire        tlb_w_g;
wire [19:0] tlb_w_ppn0;
wire [ 1:0] tlb_w_plv0;
wire [ 1:0] tlb_w_mat0;
wire        tlb_w_d0;
wire        tlb_w_v0;
wire [19:0] tlb_w_ppn1;
wire [ 1:0] tlb_w_plv1;
wire [ 1:0] tlb_w_mat1;
wire        tlb_w_d1;
wire        tlb_w_v1;

assign tlb_w_index= is_tlbwr ? csr_tlbidx_index : rand_index_tlbfill;
assign tlb_w_e    = csr_estat_ecode == 6'h3f ? 1'b1 : ~csr_tlbidx_ne;
assign tlb_w_vppn = csr_tlbehi_vppn;
assign tlb_w_ps   = csr_tlbidx_ps;

assign tlb_we = is_tlbwr | is_tlbfill;//当前没有区分两条指令
assign tlb_w_asid = csr_asid_asid;
assign tlb_w_g    = csr_tlbelo0_g & csr_tlbelo1_g;
assign tlb_w_ppn0 = csr_tlbelo0_ppn;
assign tlb_w_plv0 = csr_tlbelo0_plv;
assign tlb_w_mat0 = csr_tlbelo0_mat;
assign tlb_w_d0   = csr_tlbelo0_d;
assign tlb_w_v0   = csr_tlbelo0_v;

assign tlb_w_ppn1 = csr_tlbelo1_ppn;
assign tlb_w_plv1 = csr_tlbelo1_plv;
assign tlb_w_mat1 = csr_tlbelo1_mat;
assign tlb_w_d1   = csr_tlbelo1_d;
assign tlb_w_v1   = csr_tlbelo1_v;

//TLBRD   需不需要使能位？我们不做，外部处理
wire [ 3:0] tlb_r_index;
wire        tlb_r_e;
wire [18:0] tlb_r_vppn;
wire [ 5:0] tlb_r_ps;
wire [ 9:0] tlb_r_asid;

wire        tlb_r_g;

wire [19:0] tlb_r_ppn0;
wire [ 1:0] tlb_r_plv0;
wire [ 1:0] tlb_r_mat0;
wire        tlb_r_d0;
wire        tlb_r_v0;
wire [19:0] tlb_r_ppn1;
wire [ 1:0] tlb_r_plv1;
wire [ 1:0] tlb_r_mat1;
wire        tlb_r_d1;
wire        tlb_r_v1;

assign tlb_r_index  = csr_tlbidx_index;
// assign out_csr_tlbidx_ne = ~(tlb_r_e | s1_found);

always@(*)begin//融合tlbrd和tlbsrch
    if(is_tlbrd)begin
        out_csr_tlbidx_ne = ~tlb_r_e;
    end
    else if(is_tlbsrch)begin
        out_csr_tlbidx_ne = ~s2_found;// TLBSRCH 已迁到 s2 端口
    end
    else
        out_csr_tlbidx_ne = 1'b0;
end

assign tlbrd_hit = is_tlbrd ? tlb_r_e : 1'b0;
assign out_csr_tlbehi_vppn = tlb_r_e ? tlb_r_vppn : 19'b0;
assign out_csr_tlbidx_ps = tlb_r_e ? tlb_r_ps : 6'b0;
assign out_csr_asid_asid = tlb_r_e ? tlb_r_asid : 10'b0;//有效时候随便写就行

assign out_csr_tlbelo0_v = tlb_r_e ? tlb_r_v0 : 1'b0;
assign out_csr_tlbelo0_d = tlb_r_e ? tlb_r_d0 : 1'b0;
assign out_csr_tlbelo0_plv = tlb_r_e ? tlb_r_plv0 : 2'b0;
assign out_csr_tlbelo0_mat = tlb_r_e ? tlb_r_mat0 : 2'b0;
assign out_csr_tlbelo0_g = tlb_r_e ? tlb_r_g : 1'b0;
assign out_csr_tlbelo0_ppn = tlb_r_e ? tlb_r_ppn0 : 20'b0;

assign out_csr_tlbelo1_v = tlb_r_e ? tlb_r_v1 : 1'b0;
assign out_csr_tlbelo1_d = tlb_r_e ? tlb_r_d1 : 1'b0;
assign out_csr_tlbelo1_plv = tlb_r_e ? tlb_r_plv1 : 2'b0;
assign out_csr_tlbelo1_mat = tlb_r_e ? tlb_r_mat1 : 2'b0;
assign out_csr_tlbelo1_g = tlb_r_e ? tlb_r_g : 1'b0;
assign out_csr_tlbelo1_ppn = tlb_r_e ? tlb_r_ppn1 : 20'b0;

// TLBSRCH 结果（来自 s2，与 load/store 的 s1 完全隔离）
assign tlbsrch_hit          = s2_found;
assign out_csr_tlbidx_index = s2_found ? s2_index : 4'b0;
// assign out_csr_tlbidx_ne  融入到TLBRD的ne输出里了


// ================================================================
//  全局翻译模式判断 & DMW 解析
// ================================================================
wire da_mode, pg_mode, dmw0_plv0, dmw0_plv3, dmw1_plv0, dmw1_plv3, plv0, plv3;
wire [1:0] dmw0_mat, dmw1_mat;
wire [2:0] dmw0_pseg, dmw0_vseg, dmw1_pseg, dmw1_vseg;

assign da_mode  = csr_crmd_da && !csr_crmd_pg;   // DA 直接地址翻译
assign pg_mode  = !csr_crmd_da && csr_crmd_pg;   // PG 页表翻译

assign dmw0_plv0 = csr_dmw0[`CSR_DMW0_PLV0];
assign dmw0_plv3 = csr_dmw0[`CSR_DMW0_PLV3];
assign dmw0_mat  = csr_dmw0[`CSR_DMW0_MAT];
assign dmw0_pseg = csr_dmw0[`CSR_DMW0_PSEG];
assign dmw0_vseg = csr_dmw0[`CSR_DMW0_VSEG];

assign dmw1_plv0 = csr_dmw1[`CSR_DMW1_PLV0];
assign dmw1_plv3 = csr_dmw1[`CSR_DMW1_PLV3];
assign dmw1_mat  = csr_dmw1[`CSR_DMW1_MAT];
assign dmw1_pseg = csr_dmw1[`CSR_DMW1_PSEG];
assign dmw1_vseg = csr_dmw1[`CSR_DMW1_VSEG];

// plv0 = (csr_crmd_plv == 2'b00);
// plv3 = (csr_crmd_plv == 2'b11);
assign plv0 = ~csr_crmd_plv[0] & ~csr_crmd_plv[1];
assign plv3 = csr_crmd_plv[0] & csr_crmd_plv[1];



tlb #(
    .TLBNUM(16)
) u_tlb (
    .clk          (clk),
    .resetn       (resetn),
    
    // s0 端口供 IF (取指) 使用
    .s0_vppn      (inst_va[31:13]),
    .s0_va_bit12  (inst_va[12]),
    .s0_asid      (csr_asid_asid),
    .s0_found     (s0_found),
    .s0_index     (s0_index),
    .s0_ppn       (s0_ppn),
    .s0_ps        (s0_ps),
    .s0_plv       (s0_plv),
    .s0_mat       (s0_mat),
    .s0_d         (s0_d),
    .s0_v         (s0_v),
    .s0_pa_mid    (s0_pa_mid), //excellent

    // s1 端口 — load/store 访存（完全纯净，无 mux）
    .s1_vppn      (data_va[31:13]),
    .s1_va_bit12  (data_va[12]),
    .s1_asid      (csr_asid_asid),
    .s1_found     (s1_found),
    .s1_index     (s1_index),
    .s1_ppn       (s1_ppn),
    .s1_ps        (s1_ps),
    .s1_plv       (s1_plv),
    .s1_mat       (s1_mat),
    .s1_d         (s1_d),
    .s1_v         (s1_v),
    .s1_pa_mid    (s1_pa_mid),

    // s2 端口 — TLBSRCH 专用
    .s2_vppn      (csr_tlbehi_vppn),
    .s2_asid      (csr_asid_asid),
    .s2_found     (s2_found),
    .s2_index     (s2_index),

    // s3 端口 — INVTLB 专用
    .s3_vppn      (invtlb_vppn),
    .s3_asid      (invtlb_asid),
    // INVTLB 接口
    .invtlb_valid (invtlb_valid),
    .invtlb_op    (invtlb_op),

    // TLB 写入接口
    .we           (tlb_we),
    .w_index      (tlb_w_index),
    .w_e          (tlb_w_e),
    .w_vppn       (tlb_w_vppn),
    .w_ps         (tlb_w_ps),
    .w_asid       (tlb_w_asid),
    .w_g          (tlb_w_g),
    .w_ppn0       (tlb_w_ppn0),
    .w_plv0       (tlb_w_plv0),
    .w_mat0       (tlb_w_mat0),
    .w_d0         (tlb_w_d0),
    .w_v0         (tlb_w_v0),
    .w_ppn1       (tlb_w_ppn1),
    .w_plv1       (tlb_w_plv1),
    .w_mat1       (tlb_w_mat1),
    .w_d1         (tlb_w_d1),
    .w_v1         (tlb_w_v1),

    // TLB 读取接口
    .r_index      (tlb_r_index),
    .r_e          (tlb_r_e),
    .r_vppn       (tlb_r_vppn),
    .r_ps         (tlb_r_ps),
    .r_asid       (tlb_r_asid),
    .r_g          (tlb_r_g),
    .r_ppn0       (tlb_r_ppn0),
    .r_plv0       (tlb_r_plv0),
    .r_mat0       (tlb_r_mat0),
    .r_d0         (tlb_r_d0),
    .r_v0         (tlb_r_v0),
    .r_ppn1       (tlb_r_ppn1),
    .r_plv1       (tlb_r_plv1),
    .r_mat1       (tlb_r_mat1),
    .r_d1         (tlb_r_d1),
    .r_v1         (tlb_r_v1)
);

// ================================================================
//  IF (取指) 通道逻辑计算
// ================================================================
wire inst_dmw0_hit, inst_dmw1_hit, inst_use_tlb;
wire [31:0] inst_tlb_pa;

assign inst_dmw0_hit = pg_mode && (inst_va[31:29] == dmw0_vseg) && ((dmw0_plv0 && plv0) || (dmw0_plv3 && plv3));
assign inst_dmw1_hit = pg_mode && (inst_va[31:29] == dmw1_vseg) && ((dmw1_plv0 && plv0) || (dmw1_plv3 && plv3));
//  PA 拼接规则: 根据页大小决定 PPN 和 VA 的切割点
//    4KB (PS=12): PA = {PPN[19:0],  VA[11:0]}
//    4MB (PS=21): PA = {PPN[19:9],  VA[20:0]}
// assign inst_tlb_pa = (s0_ps == 6'd21) ? {s0_ppn[19:9], inst_va[20:0]} : {s0_ppn[19:0], inst_va[11:0]};
// assign inst_tlb_pa = {
//     s0_ppn[19:9],       // [31:21] 两种模式完全相同
//     // PS=12=6'b001100(bit0=0), PS=21=6'b010101(bit0=1), 直接取一位省掉比较器
//     (s0_ps[0] ? inst_va[20:12] : s0_ppn[8:0]),  // [20:12] 仅此 9 位需要 mux
//     inst_va[11:0]       // [11:0]  两种模式完全相同
// };
assign inst_tlb_pa = { s0_ppn[19:9], s0_pa_mid, inst_va[11:0] };

assign inst_pa = da_mode       ? inst_va :
                 inst_dmw0_hit ? {dmw0_pseg, inst_va[28:0]} :
                 inst_dmw1_hit ? {dmw1_pseg, inst_va[28:0]} :
                                 inst_tlb_pa;

assign inst_mat= da_mode       ? csr_crmd_datf :
                 inst_dmw0_hit ? dmw0_mat :
                 inst_dmw1_hit ? dmw1_mat :
                                 s0_mat;

assign inst_use_tlb = pg_mode && !inst_dmw0_hit && !inst_dmw1_hit;

assign inst_ex_tlbr = inst_use_tlb && !s0_found;
assign inst_ex_pif  = inst_use_tlb && s0_found && !s0_v;
// inst_ex_pif 要求 !s0_v，inst_ex_ppi 要求 s0_v，天然互斥，!inst_ex_pif 冗余
assign inst_ex_ppi  = inst_use_tlb && s0_found && s0_v && (csr_crmd_plv > s0_plv);

// ================================================================
//  MEM (访存) 通道逻辑计算
// ================================================================
wire data_dmw0_hit, data_dmw1_hit, data_use_tlb;
wire [31:0] data_tlb_pa;

assign data_dmw0_hit = pg_mode && (data_va[31:29] == dmw0_vseg) && ((dmw0_plv0 && plv0) || (dmw0_plv3 && plv3));
assign data_dmw1_hit = pg_mode && (data_va[31:29] == dmw1_vseg) && ((dmw1_plv0 && plv0) || (dmw1_plv3 && plv3));

// PA[20:12] 由 TLB 内部 per-entry 预选 (s1_pa_mid)，外部直接拼接
assign data_tlb_pa = { s1_ppn[19:9], s1_pa_mid, data_va[11:0] };

assign data_pa = da_mode       ? data_va :
                 data_dmw0_hit ? {dmw0_pseg, data_va[28:0]} :
                 data_dmw1_hit ? {dmw1_pseg, data_va[28:0]} :
                                 data_tlb_pa;

assign data_mat= da_mode       ? csr_crmd_datm :
                 data_dmw0_hit ? dmw0_mat :
                 data_dmw1_hit ? dmw1_mat :
                                 s1_mat;

//wire is_real_mem_access = (data_mem_type == MEM_LOAD) || (data_mem_type == MEM_STORE);
wire is_real_access_mem = (data_mem_type[0]) || (data_mem_type[1]);
assign data_use_tlb = pg_mode && !data_dmw0_hit && !data_dmw1_hit && is_real_access_mem;//访存才需要TLB，纯地址计算不需要

assign data_ex_tlbr = data_use_tlb && !s1_found;
assign data_ex_pil  = data_use_tlb && s1_found && !s1_v && (data_mem_type == MEM_LOAD);
assign data_ex_pis  = data_use_tlb && s1_found && !s1_v && (data_mem_type == MEM_STORE);
// pil/pis 要求 !s1_v，ppi 要求 s1_v，天然互斥，!(pil||pis) 冗余
assign data_ex_ppi  = data_use_tlb && s1_found && s1_v && (csr_crmd_plv > s1_plv);
// pme 直接用互补条件替代 !data_ex_ppi，消除级联 LUT 依赖
assign data_ex_pme  = data_use_tlb && s1_found && s1_v && !(csr_crmd_plv > s1_plv) && (data_mem_type == MEM_STORE) && !s1_d;


endmodule
