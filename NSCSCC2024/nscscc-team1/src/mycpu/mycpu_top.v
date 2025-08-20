`include "mycpu.h"
module core_top(
    input  wire [ 7:0]  intrpt,
    //时钟与复位 
    input  wire     aclk,
    input  wire     aresetn,
    //AXI接口 主->从
    //读请求通道
    output wire [ 3:0]  arid,
    output wire [31:0]  araddr,
    output wire [ 7:0]  arlen,
    output wire [ 2:0]  arsize,
    output wire [ 1:0]  arburst,
    output wire [ 1:0]  arlock,
    output wire [ 3:0]  arcache,
    output wire [ 2:0]  arprot,
    output wire         arvalid,
    input  wire         arready,
    //读响应通道
    input  wire [ 3:0]  rid,
    input  wire [31:0]  rdata,
    input  wire [ 1:0]  rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,
    //写请求通道
    output wire [ 3:0]  awid,
    output wire [31:0]  awaddr,
    output wire [ 7:0]  awlen,
    output wire [ 2:0]  awsize,
    output wire [ 1:0]  awburst,
    output wire [ 1:0]  awlock,
    output wire [ 3:0]  awcache,
    output wire [ 2:0]  awprot,
    output wire         awvalid,
    input  wire         awready,
    //写数据通道
    output wire [ 3:0]  wid,
    output wire [31:0]  wdata,
    output wire [ 3:0]  wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,
    //写响应通道
    input  wire [ 3:0]  bid,
    input  wire [ 1:0]  bresp,
    input  wire         bvalid,
    output wire         bready,
    //debug相关
    input           break_point,
    input           infor_flag,
    input  [ 4:0]   reg_num,
    output          ws_valid,
    output [31:0]   rf_rdata,

    output wire [31:0]  debug0_wb_pc,
    output wire [ 3:0]  debug0_wb_rf_wen,
    output wire [ 4:0]  debug0_wb_rf_wnum,
    output wire [31:0]  debug0_wb_rf_wdata,
    output wire [31:0]  debug0_wb_inst
);

//----------复位信号定义----------
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

//----------类SRAM相关信号定义----------
//inst sram
wire         inst_sram_req;
wire         inst_sram_wr;
wire  [ 1:0] inst_sram_size;
wire  [31:0] inst_sram_addr;
wire  [ 3:0] inst_sram_wstrb;
wire  [31:0] inst_sram_wdata;
wire         inst_sram_addr_ok;
wire         inst_sram_data_ok;
wire  [31:0] inst_sram_rdata;

//data sram
wire         data_sram_req;
wire         data_sram_wr;
wire  [ 1:0] data_sram_size;
wire  [31:0] data_sram_addr;
wire  [ 3:0] data_sram_wstrb;
wire  [31:0] data_sram_wdata;
wire         data_sram_addr_ok;
wire         data_sram_data_ok;
wire  [31:0] data_sram_rdata;

//----------流水线相关信号定义-----------
wire                         ds_allowin;
wire                         es_allowin;
wire                         pms_allowin;
wire                         ms_allowin;
wire                         ws_allowin;
wire                         fs_to_ds_valid;
wire                         ds_to_es_valid;
wire                         es_to_pms_valid;
wire                         pms_to_ms_valid;
wire                         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`DS_TO_ES_BR_WD  -1:0] ds_to_es_br;
wire [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus;
wire [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire                         es_valid_p;
wire                         pms_valid_p;
wire                         ms_valid_p;
wire                         ws_valid_p;

wire fs_stall;
wire ds_stall;
wire es_stall;
wire pms_stall;
wire ms_stall;

//-----------前递相关信号----------
//用于传递EXE,MEM,WB阶段的目标寄存器
wire [ 4:0] EXE_dest;
wire [ 4:0] PMEM_dest;
wire [ 4:0] MEM_dest;
wire [ 4:0] WB_dest;
wire        es_load_op; //传递EXE阶段是否为load指令(load指令在MEM阶段才能获取正确结果)
wire        pms_load_op;
wire        ms_load_op;
wire        es_csr_op;  //csr相关指令需要到WB阶段才能获取正确结果
wire        ms_csr_op;
wire        pms_csr_op;
wire        br_taken;
wire        es_rdcnt_op;
wire        pms_rdcnt_op;
wire        ms_rdcnt_op;

wire        es_result_stall;
//传递后续阶段计算结果
wire [31:0] es_result;  
wire [31:0] ms_result;
wire [31:0] pms_result;
wire [31:0] ws_result;
wire        es_gtlb_we;
wire        pms_gtlb_we;
wire        ms_gtlb_we;
wire        ws_gtlb_we;

//-----------csr相关信号-----------
wire [13:0] ws_csr_raddr1;
wire [31:0] ws_csr_rdata1;
wire [13:0] ws_csr_waddr;
wire [31:0] ws_csr_wdata;
wire        ws_csr_we;
wire [31:0] ws_csr_wmask;

wire        ws_llbit;
wire        ws_llbit_set;
wire        ds_llbit;

wire [31:0] csr_eentry_addr;
wire [31:0] csr_era_addr;
wire        crmd_da;
wire        crmd_pg;
wire [ 1:0] crmd_plv;
wire [ 1:0] crmd_datf;
wire [ 1:0] crmd_datm;

wire        dmw0_plv0;
wire        dmw0_plv3;
wire [ 1:0] dmw0_mat ;
wire [ 2:0] dmw0_pseg;
wire [ 2:0] dmw0_vseg;
wire        dmw1_plv0;
wire        dmw1_plv3;
wire [ 1:0] dmw1_mat ;
wire [ 2:0] dmw1_pseg;
wire [ 2:0] dmw1_vseg;

//----------例外相关信号-----------
wire        es_ertn;        
wire        ms_ertn;
wire        ws_ertn;
wire        es_ex;          //es阶段是否产生例外
wire        pms_ex;
wire        ms_ex;          //mem阶段是否产生例外
wire        wb_ex;          //wb阶段是否产生例外
wire [31:0] ws_wb_pc;       //wb阶段当前指令pc
wire [31:0] ws_addr;        //出错虚地址
wire        ws_ertn_op;     //wb阶段当前指令是否为ertn指令
wire [ 5:0] ws_ecode;       //wb阶段当前指令例外码
wire [ 8:0] ws_subecode;    //wb阶段当前指令子例外码
wire [31:0] ex_entry;

wire        wb_idle_op;

//----------中断相关信号-----------
wire [ 7:0] ws_hw_int_in;   //wb阶段当前指令硬中断号
wire        has_int;

//----------计时器相关信号-----------
wire        timer_en;
wire [31:0] timer_id;
wire [63:0] counter_value;

//----------TLB相关信号-----------
//write port
wire        tlb_we;
wire [ 2:0] tlb_w_index;
wire [ 2:0] tlb_w_rand_index;
wire        tlb_w_e;
wire [18:0] tlb_w_vppn;
wire [ 5:0] tlb_w_ps;
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
wire        tlbfill_en;
//read port 
wire        tlb_r_en;//当前wb阶段是否为tlb读操作
wire [ 2:0] tlb_r_index;
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

//tlbsearch
wire        tlb_search;
wire        ws_tlb_search; 
wire        ws_tlb_s_found;
wire [ 2:0] ws_tlb_s_index;

//search port 0 (for fetch)
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [ 9:0] s0_asid;
wire        s0_found;
wire [ 2:0] s0_index;
wire [19:0] s0_ppn;
wire [ 5:0] s0_ps;
wire [ 1:0] s0_plv;
wire [ 1:0] s0_mat;
wire        s0_d;
wire        s0_v;

//search port 1 (for load/store)
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [ 9:0] s1_asid;
wire        s1_found;
wire [ 2:0] s1_index;
wire [19:0] s1_ppn;
wire [ 5:0] s1_ps;
wire [ 1:0] s1_plv;
wire [ 1:0] s1_mat;
wire        s1_d;
wire        s1_v;

//invtlb
wire [ 4:0] invtlb_op;
wire        invtlb_valid;
wire        pms_invtlb_valid;
wire [18:0] invtlb_vppn;
wire [ 9:0] invtlb_asid;

// assign  s1_asid = pms_invtlb_valid ? invtlb_asid:
//                   tlb_w_asid;

assign  s0_asid = tlb_w_asid;

//tlb_flush
wire        ms_tlb_flush;
wire        wb_tlb_flush;
wire        ds_tlb_flush;
wire [31:0] ds_tlb_flush_addr;
wire [31:0] mem_pc;
reg  [31:0] tlb_flush_addr;

always @(posedge aclk) begin
    if (reset) begin
        tlb_flush_addr <= 32'h0;
    end
    else if (wb_tlb_flush) begin
        tlb_flush_addr <= ws_wb_pc + 32'h4;
    end
end

//-----------cache相关信号定义----------
//icache
wire         icache_uncache_en;
wire         icache_cacop_en;
wire [ 1: 0] icache_cacop_op;
wire [31: 0] icache_cacop_va;
wire         icache_unbusy;
wire         icache_rd_req;
wire [ 2: 0] icache_rd_type;
wire [31: 0] icache_rd_addr;
wire         icache_rd_rdy;
wire         icache_ret_valid;
wire         icache_ret_last;
wire [31: 0] icache_ret_data;
wire         icache_wr_req;
wire [ 2: 0] icache_wr_type;
wire [31: 0] icache_wr_addr;
wire [ 3: 0] icache_wr_wstrb;
wire [127:0] icache_wr_data;
wire         icache_wr_rdy;     

wire         icache_req;
wire         icache_wr;
wire [ 1:0]  icache_size;
wire [31:0]  icache_addr;
wire         icache_addr_ok;
wire         icache_data_ok;
wire [ 2:0]  icache_type;

assign  icache_req = icache_rd_req | icache_wr_req;
assign  icache_wr  = icache_wr_req;
assign  icache_size= 2'b10;
assign  icache_addr= icache_wr_req ? icache_wr_addr : icache_rd_addr;
assign  icache_type= icache_wr_req ? icache_wr_type : icache_rd_type;

//dcache
wire         dcache_uncache_en;
wire         dcache_cacop_en;
wire [ 1: 0] dcache_cacop_op;
wire [31: 0] dcache_cacop_va;
wire         dcache_unbusy;
wire         dcache_rd_req;
wire [ 2: 0] dcache_rd_type;
wire [31: 0] dcache_rd_addr;
wire         dcache_rd_rdy;
wire         dcache_ret_valid;
wire         dcache_ret_last;
wire [31: 0] dcache_ret_data;
wire         dcache_wr_req;
wire [ 2: 0] dcache_wr_type;
wire [31: 0] dcache_wr_addr;
wire [ 3: 0] dcache_wr_wstrb;
wire [127:0] dcache_wr_data;
wire         dcache_wr_rdy;     

wire         dcache_req;
wire         dcache_wr;
wire [ 1:0]  dcache_size;
wire [31:0]  dcache_addr;
wire         dcache_addr_ok;
wire         dcache_data_ok;
wire [ 2:0]  dcache_type;

assign  dcache_req = dcache_rd_req | dcache_wr_req;
assign  dcache_wr  = dcache_wr_req;
assign  dcache_size= 2'b10;
assign  dcache_addr= dcache_wr_req ? dcache_wr_addr : dcache_rd_addr;
assign  dcache_type= dcache_wr_req ? dcache_wr_type : dcache_rd_type;

//----------流水线模块实例化-----------
// IF stage
if_stage if_stage(
    .clk              (aclk           ),
    .reset            (reset          ),
    //allowin
    .ds_allowin       (ds_allowin     ),
    //stall
    .ms_stall         (ms_stall       ),
    .pms_stall        (pms_stall      ),
    .es_stall         (es_stall       ),
    .ds_stall         (ds_stall       ),
    .fs_stall         (fs_stall       ),
    //brbus
    .br_bus           (br_bus         ),  //branch指令总线
    //outputs
    .fs_to_ds_valid   (fs_to_ds_valid ),
    .fs_to_ds_bus     (fs_to_ds_bus   ),  //fs向ds传递总线
    // inst sram interface
    .inst_sram_en     (inst_sram_req  ),
    .inst_sram_we     (inst_sram_wstrb),
    .inst_sram_addr   (inst_sram_addr ),
    .inst_sram_wdata  (inst_sram_wdata),
    .inst_sram_rdata  (inst_sram_rdata),
    .inst_sram_size   (inst_sram_size ),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    //csr
    .csr_era_addr     (csr_era_addr   ),  //例外返回地址
    .ex_entry         (ex_entry       ),  //例外入口
    .crmd_da          (crmd_da        ),  //直接翻译模式
    .crmd_pg          (crmd_pg        ),  //映射翻译模式
    .crmd_datf        (crmd_datf      ),  
    .crmd_plv         (crmd_plv       ),
    .dmw0_plv0        (dmw0_plv0      ),
    .dmw0_plv3        (dmw0_plv3      ),
    .dmw0_mat         (dmw0_mat       ),
    .dmw0_pseg        (dmw0_pseg      ),
    .dmw0_vseg        (dmw0_vseg      ),
    .dmw1_plv0        (dmw1_plv0      ),
    .dmw1_plv3        (dmw1_plv3      ),
    .dmw1_mat         (dmw1_mat       ),
    .dmw1_pseg        (dmw1_pseg      ),
    .dmw1_vseg        (dmw1_vseg      ),
    //exception
    .wb_ex            (wb_ex          ),
    .wb_ertn          (ws_ertn_op     ),
    .wb_idle_op       (wb_idle_op     ),
    .has_int          (has_int        ),
    //tlb
    .tlb_s0_vppn      (s0_vppn        ),
    .tlb_s0_va_bit12  (s0_va_bit12    ),
    .tlb_s0_found     (s0_found       ),
    .tlb_s0_ppn       (s0_ppn         ),
    .tlb_s0_ps        (s0_ps          ),
    .tlb_s0_plv       (s0_plv         ),
    .tlb_s0_mat       (s0_mat         ),
    .tlb_s0_d         (s0_d           ),
    .tlb_s0_v         (s0_v           ),
    .wb_tlb_flush     (wb_tlb_flush   ),
    .tlb_flush_addr   (tlb_flush_addr ),
    //cache
    .icache_uncache_en(icache_uncache_en)
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //stall
    .ds_stall       (ds_stall       ),
    .es_stall       (es_stall       ),
    .pms_stall      (pms_stall      ),
    .ms_stall       (ms_stall       ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),  //fs向ds传递总线
    //valid from es,ms,ws
    .es_valid_p     (es_valid_p     ),
    .pms_valid_p    (pms_valid_p    ),
    .ms_valid_p     (ms_valid_p     ),
    .ws_valid_p     (ws_valid_p     ),
    //from es
    .br_taken       (br_taken       ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),  //ds向es传递总线
    .ds_to_es_br    (ds_to_es_br    ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),  //ws写回寄存器总线
    //前递相关
    .EXE_dest       (EXE_dest       ),
    .PMEM_dest      (PMEM_dest      ),
    .MEM_dest       (MEM_dest       ),
    .WB_dest        (WB_dest        ),
    .es_load_op     (es_load_op     ),
    .es_result      (es_result      ),
    .pms_load_op    (pms_load_op    ),
    .pms_result     (pms_result     ),
    .ms_load_op     (ms_load_op     ),
    .ms_result      (ms_result      ),
    .ws_result      (ws_result      ),
    .es_csr_op      (es_csr_op      ),
    .pms_csr_op     (pms_csr_op     ),
    .ms_csr_op      (ms_csr_op      ),
    .es_gtlb_we     (es_gtlb_we     ),
    .pms_gtlb_we    (pms_gtlb_we    ),
    .ms_gtlb_we     (ms_gtlb_we     ),
    .ws_gtlb_we     (ws_gtlb_we     ),
    .es_rdcnt_op    (es_rdcnt_op    ),
    .pms_rdcnt_op   (pms_rdcnt_op   ),
    .ms_rdcnt_op    (ms_rdcnt_op    ),
    .es_result_stall(es_result_stall),
    //exception
    .wb_ertn        (ws_ertn_op     ), 
    .wb_ex          (wb_ex          ),
    .ds_llbit       (ds_llbit),
    //中断相关
    .has_int        (has_int        ),
    //tlb相关
    .wb_tlb_flush   (wb_tlb_flush   ),
    .tlb_flush      (ds_tlb_flush   ),
    .tlb_flush_addr (ds_tlb_flush_addr),
    //debug
    .infor_flag           (infor_flag          ),
    .reg_num              (reg_num             ),
    .debug_rf_rdata1      (rf_rdata            )
    `ifdef DIFFTEST_EN
    ,
    .rf_to_diff           (regs                )
    `endif
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .pms_allowin    (pms_allowin    ),
    .es_allowin     (es_allowin     ),
    //stall
    .es_stall       (es_stall       ),
    .pms_stall      (pms_stall      ),
    .ms_stall       (ms_stall       ),
    //to fs
    .br_bus         (br_bus         ),  //branch指令总线
    //to ds
    .br_taken       (br_taken       ),
    .es_valid_p     (es_valid_p     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),  
    .ds_to_es_bus   (ds_to_es_bus   ),  //ds向es传递总线
    .ds_to_es_br    (ds_to_es_br    ),
    //to pms
    .es_to_pms_valid (es_to_pms_valid ),
    .es_to_pms_bus   (es_to_pms_bus   ),  //es向ms传递总线
    
    //前递相关
    .EXE_dest       (EXE_dest       ),
    .es_result      (es_result      ),
    .es_load_op     (es_load_op     ),
    .es_rdcnt_op    (es_rdcnt_op    ),
    .es_csr_op      (es_csr_op      ),
    .es_gtlb_we     (es_gtlb_we     ),
    .es_result_stall(es_result_stall),
    //exception
    .wb_ertn        (ws_ertn_op     ),
    .es_ex          (es_ex          ),
    .wb_ex          (wb_ex          ),
    .wb_tlb_flush   (wb_tlb_flush   ),
    //计时器相关
    .timer_id       (timer_id       ),
    .counter_value  (counter_value  )
               
);
// preMEM stage
premem_stage premem_stage(
    .clk             (aclk            ),
    .reset           (reset           ),
    //allowin
    .ms_allowin      (ms_allowin      ),
    .pms_allowin     (pms_allowin     ),
    //stall
    .pms_stall       (pms_stall       ),
    .ms_stall        (ms_stall        ),
    //from es
    .es_to_pms_valid (es_to_pms_valid ),  
    .es_to_pms_bus   (es_to_pms_bus   ),  //ds向es传递总线
    //to ms
    .pms_to_ms_valid (pms_to_ms_valid ),
    .pms_to_ms_bus   (pms_to_ms_bus   ),  //es向ms传递总线
    // data sram interface
    .data_sram_en   (data_sram_req  ),
    .data_sram_we   (data_sram_wstrb),
    .data_sram_wr   (data_sram_wr   ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_size (data_sram_size),
    //前递相关
    .PMEM_dest      (PMEM_dest       ),
    .pms_resultr    (pms_result      ),
    .pms_load_op    (pms_load_op     ),
    .pms_csr_op     (pms_csr_op      ),
    .pms_rdcnt_op    (pms_rdcnt_op    ),
    .pms_gtlb_we    (pms_gtlb_we     ),
    .pms_valid_p    (pms_valid_p    ),
    //exception
    .ms_ertn        (ms_ertn        ),
    .wb_ertn        (ws_ertn_op     ),
    .pms_ex         (pms_ex          ),
    .ms_ex          (ms_ex          ),
    .wb_ex          (wb_ex          ),
    .wb_ertn_op     (ws_ertn_op     ),
    //tlb相关
    .tlb_search     (tlb_search     ),
    .invtlb_valid   (invtlb_valid   ),
    .pms_invtlb_valid(pms_invtlb_valid),
    .invtlb_op      (invtlb_op      ),
    .invtlb_vppn    (invtlb_vppn    ),
    .invtlb_asid    (invtlb_asid    ),
    .tlb_s1_vppn    (s1_vppn        ), 
    .tlb_s1_va_bit12(s1_va_bit12    ),
    .tlb_s1_asid    (s1_asid        ),  
    .tlb_s1_found   (s1_found       ), 
    .tlb_s1_index   (s1_index       ),
    .tlb_s1_ppn     (s1_ppn         ),  
    .tlb_s1_ps      (s1_ps          ),
    .tlb_s1_plv     (s1_plv         ),  
    .tlb_s1_mat     (s1_mat         ),  
    .tlb_s1_d       (s1_d           ),  
    .tlb_s1_v       (s1_v           ),
    .wb_tlb_flush   (wb_tlb_flush   ),
    .ms_tlb_flush   (ms_tlb_flush   ),
    //csr相关
    .crmd_da        (crmd_da        ),
    .crmd_pg        (crmd_pg        ),
    .crmd_datm      (crmd_datm      ),
    .crmd_plv       (crmd_plv       ),
    .csr_tlbehi_vppn(tlb_w_vppn     ),
    .csr_asid_asid  (tlb_w_asid     ),
    .dmw0_plv0      (dmw0_plv0      ),
    .dmw0_plv3      (dmw0_plv3      ),
    .dmw0_mat       (dmw0_mat       ),
    .dmw0_pseg      (dmw0_pseg      ),
    .dmw0_vseg      (dmw0_vseg      ),
    .dmw1_plv0      (dmw1_plv0      ),
    .dmw1_plv3      (dmw1_plv3      ),
    .dmw1_mat       (dmw1_mat       ),
    .dmw1_pseg      (dmw1_pseg      ),
    .dmw1_vseg      (dmw1_vseg      ),
    //cache
    .dcache_uncache_en(dcache_uncache_en),
    .icache_cacop_en(icache_cacop_en),
    .icache_cacop_op(icache_cacop_op),
    .icache_cacop_va(icache_cacop_va),
    .icache_unbusy  (icache_unbusy  ), 
    .dcache_cacop_en(dcache_cacop_en),
    .dcache_cacop_op(dcache_cacop_op),
    .dcache_cacop_va(dcache_cacop_va),
    .dcache_unbusy  (dcache_unbusy  )

);
// MEM stage
mem_stage mem_stage(
    .clk             (aclk            ),
    .reset           (reset           ),
    //allowin
    .ws_allowin      (ws_allowin      ),
    .ms_allowin      (ms_allowin      ),
    //stall 
    .ms_stall        (ms_stall        ),
    //from pms
    .pms_to_ms_valid (pms_to_ms_valid ),
    .pms_to_ms_bus   (pms_to_ms_bus   ),  //es向ms传递总线
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),  //ms向ws传递总线
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    //from addr trans for difftest
    .data_index_diff      (data_sram_addr[11: 4] ),
    .data_tag_diff        (data_sram_addr[31: 12]),
    .data_offset_diff     (data_sram_addr[ 3: 0] ),
    //前递相关
    .MEM_dest       (MEM_dest       ),
    .ms_result      (ms_result      ),
    .ms_load_op     (ms_load_op     ),
    .ms_csr_op      (ms_csr_op      ),
    .ms_rdcnt_op    (ms_rdcnt_op    ),
    .ms_gtlb_we     (ms_gtlb_we     ),
    .ms_valid_p     (ms_valid_p     ),
    //exception
    .ms_ex          (ms_ex          ),
    .wb_ex          (wb_ex          ),
    .ms_ertn        (ms_ertn        ),
    .wb_ertn_op     (ws_ertn_op     ),
    //tlb
    .ms_tlb_flush   (ms_tlb_flush   ),
    .wb_tlb_flush   (wb_tlb_flush   ),
    .mem_pc         (mem_pc         )

);
// WB stage
wb_stage wb_stage(
    .clk                (aclk              ),
    .reset              (reset            ),
    //allowin
    .ws_allowin         (ws_allowin       ),
    //from ms
    .ms_to_ws_valid     (ms_to_ws_valid   ),
    .ms_to_ws_bus       (ms_to_ws_bus     ),    //ms向ws传递总线
    //to rf: for write back
    .ws_to_rf_bus       (ws_to_rf_bus     ),    //ws写回寄存器总线
    //trace debug interface
    .debug_ws_valid     (ws_valid          ),
    .debug_break_point  (break_point       ),
    .debug_wb_pc        (debug0_wb_pc      ),
    .debug_wb_rf_we     (debug0_wb_rf_wen  ),
    .debug_wb_rf_wnum   (debug0_wb_rf_wnum ),
    .debug_wb_rf_wdata  (debug0_wb_rf_wdata),
    .debug_wb_inst      (debug0_wb_inst    ),
    //前递相关
    .WB_dest            (WB_dest          ),         
    .ws_result          (ws_result        ),
    .ws_gtlb_we         (ws_gtlb_we       ),
    .ws_valid_p         (ws_valid_p       ),
    //csr相关
    .csr_raddr1         (ws_csr_raddr1    ),               
    .csr_rdata1         (ws_csr_rdata1    ),               
    .csr_waddr          (ws_csr_waddr     ),               
    .csr_wdata          (ws_csr_wdata     ),               
    .csr_we             (ws_csr_we        ),               
    .csr_wmask          (ws_csr_wmask     ),
    .ws_ecode           (ws_ecode         ),
    .subecode           (ws_subecode      ),
    .wb_pc              (ws_wb_pc         ),
    .ws_addr            (ws_addr          ),
    .ws_llbit           (ws_llbit         ),
    .ws_llbit_set       (ws_llbit_set     ),
    //exception   
    .ms_ex              (ms_ex            ),           
    .wb_ex              (wb_ex            ),                       
    .wb_ertn            (ws_ertn_op       ),
    .ms_ertn            (ms_ertn          ),
    //计数器相关
    .timer_id           (timer_id         ),
    .counter_value      (counter_value    ),
    //tlb相关
    .tlb_we             (tlb_we           ),
    .tlb_rd             (tlb_r_en         ),             
    .ms_tlb_flush       (ms_tlb_flush     ),
    .wb_tlb_flush       (wb_tlb_flush     ),
    .tlbfill_en         (tlbfill_en       ),
    .ws_tlb_search      (ws_tlb_search    ),
    .ws_tlb_s_found     (ws_tlb_s_found   ),
    .ws_tlb_s_index     (ws_tlb_s_index   ),
    //idle相关
    .wb_idle_op         (wb_idle_op       ),
    //difftest相关
    .ws_valid_diff      (ws_valid_diff     ),
    .ws_cnt_inst_diff   (cnt_inst_diff     ),
    .ws_timer_64_diff   (timer_64_diff     ),
    .ws_inst_ld_en_diff (inst_ld_en_diff   ),
    .ws_ld_paddr_diff   (ld_paddr_diff     ),
    .ws_ld_vaddr_diff   (ld_vaddr_diff     ),
    .ws_inst_st_en_diff (inst_st_en_diff   ),
    .ws_st_paddr_diff   (st_paddr_diff     ),
    .ws_st_vaddr_diff   (st_vaddr_diff     ),
    .ws_st_data_diff    (st_data_diff      ),
    .ws_csr_rstat_en_diff (csr_rstat_en_diff    ),
    .ws_csr_data_diff   (csr_data_diff     )
);

//-----------------csr模块实例化-----------------
csr csr(
    .clk            (aclk           ),
    .reset          (reset          ),
    //读出
    .csr_raddr1     (ws_csr_raddr1  ),               
    .csr_rdata1     (ws_csr_rdata1  ),
    .csr_eentry_addr(csr_eentry_addr),
    .csr_era_addr   (csr_era_addr   ),
    .ex_entry       (ex_entry       ),
    .crmd_da        (crmd_da        ),
    .crmd_pg        (crmd_pg        ),
    .crmd_datf      (crmd_datf      ),
    .crmd_datm      (crmd_datm      ),
    .crmd_plv       (crmd_plv       ),
    //写入              
    .csr_waddr      (ws_csr_waddr   ),
    .csr_wdata      (ws_csr_wdata   ),               
    .csr_we         (ws_csr_we      ),               
    .csr_wmask      (ws_csr_wmask   ),               
    .wb_ex          (wb_ex          ),               
    .wb_pc          (ws_wb_pc       ),
    .ws_addr        (ws_addr        ),               
    .ertn_op        (ws_ertn_op     ),               
    .ecode          (ws_ecode       ),               
    .subecode       (ws_subecode    ),             
    //中断相关            
    .hw_int_in      (ws_hw_int_in   ),
    .has_int        (has_int        ),
    //llbit
    .ds_llbit       (ds_llbit       ),
    .llbit_in       (ws_llbit       ),
    .llbit_set_in   (ws_llbit_set   ),
    //计时器相关
    .timer_id       (timer_id       ),
    //tlb相关
    //tlbwr
    .tlb_w_index    (tlb_w_index    ),
    .tlb_w_e        (tlb_w_e        ),
    .tlb_w_vppn     (tlb_w_vppn     ),
    .tlb_w_ps       (tlb_w_ps       ),
    .tlb_w_asid     (tlb_w_asid     ),
    .tlb_w_g        (tlb_w_g        ),
    .tlb_w_ppn0     (tlb_w_ppn0     ),
    .tlb_w_plv0     (tlb_w_plv0     ),
    .tlb_w_mat0     (tlb_w_mat0     ),
    .tlb_w_d0       (tlb_w_d0       ),
    .tlb_w_v0       (tlb_w_v0       ),
    .tlb_w_ppn1     (tlb_w_ppn1     ),
    .tlb_w_plv1     (tlb_w_plv1     ),
    .tlb_w_mat1     (tlb_w_mat1     ),
    .tlb_w_d1       (tlb_w_d1       ),
    .tlb_w_v1       (tlb_w_v1       ),
    //tlbrd
    .tlb_r_en       (tlb_r_en       ),
    .tlb_r_index    (tlb_r_index    ),
    .tlb_r_e        (tlb_r_e        ),
    .tlb_r_vppn     (tlb_r_vppn     ),
    .tlb_r_ps       (tlb_r_ps       ),
    .tlb_r_asid     (tlb_r_asid     ),
    .tlb_r_g        (tlb_r_g        ),
    .tlb_r_ppn0     (tlb_r_ppn0     ),
    .tlb_r_plv0     (tlb_r_plv0     ),
    .tlb_r_mat0     (tlb_r_mat0     ),
    .tlb_r_d0       (tlb_r_d0       ),
    .tlb_r_v0       (tlb_r_v0       ),
    .tlb_r_ppn1     (tlb_r_ppn1     ),
    .tlb_r_plv1     (tlb_r_plv1     ),
    .tlb_r_mat1     (tlb_r_mat1     ),
    .tlb_r_d1       (tlb_r_d1       ),
    .tlb_r_v1       (tlb_r_v1       ),
    //tlbsrch
    .tlb_search     (ws_tlb_search  ),
    .tlb_s_found    (ws_tlb_s_found ),
    .tlb_s_index    (ws_tlb_s_index ),
    //dmw
    .dmw0_plv0      (dmw0_plv0      ),
    .dmw0_plv3      (dmw0_plv3      ),
    .dmw0_mat       (dmw0_mat       ),
    .dmw0_pseg      (dmw0_pseg      ),
    .dmw0_vseg      (dmw0_vseg      ),
    .dmw1_plv0      (dmw1_plv0      ),
    .dmw1_plv3      (dmw1_plv3      ),
    .dmw1_mat       (dmw1_mat       ),
    .dmw1_pseg      (dmw1_pseg      ),
    .dmw1_vseg      (dmw1_vseg      ),

    //difftest
    .csr_crmd_diff      (csr_crmd_diff_0    ),
    .csr_prmd_diff      (csr_prmd_diff_0    ),
    .csr_ectl_diff      (csr_ectl_diff_0    ),
    .csr_estat_diff     (csr_estat_diff_0   ),
    .csr_era_diff       (csr_era_diff_0     ),
    .csr_badv_diff      (csr_badv_diff_0    ),
    .csr_eentry_diff    (csr_eentry_diff_0  ),
    .csr_tlbidx_diff    (csr_tlbidx_diff_0  ),
    .csr_tlbehi_diff    (csr_tlbehi_diff_0  ),
    .csr_tlbelo0_diff   (csr_tlbelo0_diff_0 ),
    .csr_tlbelo1_diff   (csr_tlbelo1_diff_0 ),
    .csr_asid_diff      (csr_asid_diff_0    ),
    .csr_save0_diff     (csr_save0_diff_0   ),
    .csr_save1_diff     (csr_save1_diff_0   ),
    .csr_save2_diff     (csr_save2_diff_0   ),
    .csr_save3_diff     (csr_save3_diff_0   ),
    .csr_tid_diff       (csr_tid_diff_0     ),
    .csr_tcfg_diff      (csr_tcfg_diff_0    ),
    .csr_tval_diff      (csr_tval_diff_0    ),
    .csr_ticlr_diff     (csr_ticlr_diff_0   ),
    .csr_llbctl_diff    (csr_llbctl_diff_0  ),
    .csr_tlbrentry_diff (csr_tlbrentry_diff_0),
    .csr_dmw0_diff      (csr_dmw0_diff_0    ),
    .csr_dmw1_diff      (csr_dmw1_diff_0    ),
    .csr_pgdl_diff      (csr_pgdl_diff_0    ),
    .csr_pgdh_diff      (csr_pgdh_diff_0    )
);

Counter u_counter(
    .clk            (aclk           ),
    .reset          (reset          ),
    .counter_value  (counter_value  ),
    .rand_index     (tlb_w_rand_index)
);

//----------总线转接桥模块实例化-----------
sram_to_axi_bridge u_sram_to_axi_bridge(
    .clk             (aclk           ),
    .reset           (reset          ),
    //inst sram interface
    .inst_rd_req     (icache_req     ),
    .inst_rd_type    (icache_type    ),
    .inst_rd_addr    (icache_addr    ),
    .inst_rd_rdy     (icache_addr_ok ),
    .inst_ret_valid  (icache_data_ok ),
    .inst_ret_last   (icache_ret_last),
    .inst_ret_data   (icache_ret_data),
    .inst_wr_req     (icache_wr      ),
    .inst_wr_type    (icache_type    ),
    .inst_wr_addr    (icache_addr    ),
    .inst_wr_wstrb   (icache_wr_wstrb),
    .inst_wr_data    (icache_wr_data ),
    .inst_wr_rdy     (               ),
    //data sram interface
    .data_rd_req     (dcache_rd_req  ),
    .data_rd_type    (dcache_rd_type ),
    .data_rd_addr    (dcache_rd_addr ),
    .data_rd_rdy     (dcache_addr_ok ),
    .data_ret_valid  (dcache_data_ok ),
    .data_ret_last   (dcache_ret_last),
    .data_ret_data   (dcache_ret_data),
    .data_wr_req     (dcache_wr_req  ),
    .data_wr_type    (dcache_wr_type ),
    .data_wr_addr    (dcache_wr_addr ),
    .data_wr_wstrb   (dcache_wr_wstrb),
    .data_wr_data    (dcache_wr_data ),
    .data_wr_rdy     (dcache_wr_rdy  ),
    .write_buffer_empty(             ),
    //AXI master interface
    //read channel
    .arid            (arid           ),
    .araddr          (araddr         ),
    .arlen           (arlen          ),
    .arsize          (arsize         ),
    .arburst         (arburst        ),
    .arlock          (arlock         ),
    .arcache         (arcache        ),
    .arprot          (arprot         ),
    .arvalid         (arvalid        ),
    .arready         (arready        ),
    //read data channel
    .rid             (rid            ),
    .rdata           (rdata          ),
    .rresp           (rresp          ),
    .rlast           (rlast          ),
    .rvalid          (rvalid         ),
    .rready          (rready         ),
    //write channel
    .awid            (awid           ),
    .awaddr          (awaddr         ),
    .awlen           (awlen          ),
    .awsize          (awsize         ),
    .awburst         (awburst        ),
    .awlock          (awlock         ),
    .awcache         (awcache        ),
    .awprot          (awprot         ),
    .awvalid         (awvalid        ),
    .awready         (awready        ),
    //write data channel
    .wid             (wid            ),
    .wdata           (wdata          ),
    .wstrb           (wstrb          ),
    .wlast           (wlast          ),
    .wvalid          (wvalid         ),
    .wready          (wready         ),
    //write response channel
    .bid             (bid            ),
    .bresp           (bresp          ),
    .bvalid          (bvalid         ),
    .bready          (bready         )
);

//-----------------TLB模块实例化-----------------
tlb u_tlb(
    .clk            (aclk            ),
    //search port 0
    .s0_vppn        (s0_vppn         ),
    .s0_va_bit12    (s0_va_bit12     ),
    .s0_asid        (s0_asid         ),
    .s0_found       (s0_found        ),
    .s0_index       (s0_index        ), 
    .s0_ppn         (s0_ppn          ),
    .s0_ps          (s0_ps           ),
    .s0_plv         (s0_plv          ),
    .s0_mat         (s0_mat          ),
    .s0_d           (s0_d            ),
    .s0_v           (s0_v            ),

    //search port 1
    .s1_vppn        (s1_vppn         ),
    .s1_va_bit12    (s1_va_bit12     ),
    .s1_asid        (s1_asid         ),
    .s1_found       (s1_found        ),
    .s1_index       (s1_index        ),
    .s1_ppn         (s1_ppn          ),
    .s1_ps          (s1_ps           ),
    .s1_plv         (s1_plv          ),
    .s1_mat         (s1_mat          ),
    .s1_d           (s1_d            ),
    .s1_v           (s1_v            ),

    //invtlb opcode
    .invtlb_valid   (invtlb_valid    ),
    .invtlb_op      (invtlb_op       ),

    //write port
    .we             (tlb_we          ),
    .tlbfill        (tlbfill_en      ),
    .rand_index     (tlb_w_rand_index),
    .w_index        (tlb_w_index     ),
    .w_e            (tlb_w_e         ),
    .w_vppn         (tlb_w_vppn      ),
    .w_ps           (tlb_w_ps        ),
    .w_asid         (tlb_w_asid      ),
    .w_g            (tlb_w_g         ),
    .w_ppn0         (tlb_w_ppn0      ),
    .w_plv0         (tlb_w_plv0      ),
    .w_mat0         (tlb_w_mat0      ),
    .w_d0           (tlb_w_d0        ),
    .w_v0           (tlb_w_v0        ),
    .w_ppn1         (tlb_w_ppn1      ),
    .w_plv1         (tlb_w_plv1      ),
    .w_mat1         (tlb_w_mat1      ),
    .w_d1           (tlb_w_d1        ),
    .w_v1           (tlb_w_v1        ),

    //read port
    .r_index        (tlb_r_index     ),
    .r_e            (tlb_r_e         ),
    .r_vppn         (tlb_r_vppn      ),
    .r_ps           (tlb_r_ps        ),
    .r_asid         (tlb_r_asid      ),
    .r_g            (tlb_r_g         ),
    .r_ppn0         (tlb_r_ppn0      ),
    .r_plv0         (tlb_r_plv0      ),
    .r_mat0         (tlb_r_mat0      ),
    .r_d0           (tlb_r_d0        ),
    .r_v0           (tlb_r_v0        ),
    .r_ppn1         (tlb_r_ppn1      ),
    .r_plv1         (tlb_r_plv1      ),
    .r_mat1         (tlb_r_mat1      ),
    .r_d1           (tlb_r_d1        ),
    .r_v1           (tlb_r_v1        )
);

//----------icache模块实例化----------
icache u_icache(
    .clk            (aclk                 ),
    .resetn         (aresetn              ),
    //cache and pipeline interface
    .valid          (inst_sram_req        ),
    .op             (inst_sram_wr         ),
    .index          (inst_sram_addr[11: 4]),
    .tag            (inst_sram_addr[31:12]),
    .offset         (inst_sram_addr[ 3: 0]),
    .wstrb          (inst_sram_wstrb      ),
    .wdata          (inst_sram_wdata      ),
    .addr_ok        (inst_sram_addr_ok    ),
    .data_ok        (inst_sram_data_ok    ),
    .rdata          (inst_sram_rdata      ),
    .uncache_en     (icache_uncache_en    ),
    .cacop_en       (icache_cacop_en      ),
    .cacop_op       (icache_cacop_op      ),
    .cacop_va       (icache_cacop_va      ),
    .icache_unbusy  (icache_unbusy        ),
    //cache and axi interface
    .rd_req         (icache_rd_req        ),
    .rd_type        (icache_rd_type       ),
    .rd_addr        (icache_rd_addr       ),
    .rd_rdy         (icache_addr_ok       ),
    .ret_valid      (icache_data_ok       ),
    .ret_last       (icache_ret_last      ),
    .ret_data       (icache_ret_data      ),
    .wr_req         (icache_wr_req        ),
    .wr_type        (icache_wr_type       ),
    .wr_addr        (icache_wr_addr       ),
    .wr_wstrb       (icache_wr_wstrb      ),
    .wr_data        (icache_wr_data       ),
    .wr_rdy         (icache_addr_ok       ) 
);

//-----------dcache模块化----------
dcache u_dcache(
    .clk            (aclk                 ),
    .resetn         (aresetn              ),
    //cache and pipeline interface
    .valid          (data_sram_req        ),
    .op             (data_sram_wr         ),
    .size           (data_sram_size       ),
    .index          (data_sram_addr[11: 4]),
    .tag            (data_sram_addr[31:12]),
    .offset         (data_sram_addr[ 3: 0]),
    .wstrb          (data_sram_wstrb      ),
    .wdata          (data_sram_wdata      ),
    .addr_ok        (data_sram_addr_ok    ),
    .data_ok        (data_sram_data_ok    ),
    .rdata          (data_sram_rdata      ),
    .uncache_en     (dcache_uncache_en    ),
    .cacop_en       (dcache_cacop_en      ),
    .cacop_op       (dcache_cacop_op      ),
    .cacop_va       (dcache_cacop_va      ),
    .dcache_unbusy  (dcache_unbusy        ),
    //cache and axi interface
    .rd_req         (dcache_rd_req        ),
    .rd_type        (dcache_rd_type       ),
    .rd_addr        (dcache_rd_addr       ),
    .rd_rdy         (dcache_addr_ok       ),
    .ret_valid      (dcache_data_ok       ),
    .ret_last       (dcache_ret_last      ),
    .ret_data       (dcache_ret_data      ),
    .wr_req         (dcache_wr_req        ),
    .wr_type        (dcache_wr_type       ),
    .wr_addr        (dcache_wr_addr       ),
    .wr_wstrb       (dcache_wr_wstrb      ),
    .wr_data        (dcache_wr_data       ),
    .wr_rdy         (dcache_wr_rdy        )
);

`ifdef DIFFTEST_EN
// difftest
// from wb_stage
wire            ws_valid_diff       ;
wire            cnt_inst_diff       ;
wire    [63:0]  timer_64_diff       ;
wire    [ 7:0]  inst_ld_en_diff     ;
wire    [31:0]  ld_paddr_diff       ;
wire    [31:0]  ld_vaddr_diff       ;
wire    [ 7:0]  inst_st_en_diff     ;
wire    [31:0]  st_paddr_diff       ;
wire    [31:0]  st_vaddr_diff       ;
wire    [31:0]  st_data_diff        ;
wire            csr_rstat_en_diff   ;
wire    [31:0]  csr_data_diff       ;

wire inst_valid_diff = ws_valid_diff;
reg             cmt_valid           ;
reg             cmt_cnt_inst        ;
reg     [63:0]  cmt_timer_64        ;
reg     [ 7:0]  cmt_inst_ld_en      ;
reg     [31:0]  cmt_ld_paddr        ;
reg     [31:0]  cmt_ld_vaddr        ;
reg     [ 7:0]  cmt_inst_st_en      ;
reg     [31:0]  cmt_st_paddr        ;
reg     [31:0]  cmt_st_vaddr        ;
reg     [31:0]  cmt_st_data         ;
reg             cmt_csr_rstat_en    ;
reg     [31:0]  cmt_csr_data        ;

reg             cmt_wen             ;
reg     [ 7:0]  cmt_wdest           ;
reg     [31:0]  cmt_wdata           ;
reg     [31:0]  cmt_pc              ;
reg     [31:0]  cmt_inst            ;

reg             cmt_excp_flush      ;
reg             cmt_ertn            ;
reg     [5:0]   cmt_csr_ecode       ;
reg             cmt_tlbfill_en      ;
reg     [4:0]   cmt_rand_index      ;

// to difftest debug
reg             trap                ;
reg     [ 7:0]  trap_code           ;
reg     [63:0]  cycleCnt            ;
reg     [63:0]  instrCnt            ;

// from regfile
wire    [31:0]  regs[31:0]          ;

// from csr
wire    [31:0]  csr_crmd_diff_0     ;
wire    [31:0]  csr_prmd_diff_0     ;
wire    [31:0]  csr_ectl_diff_0     ;
wire    [31:0]  csr_estat_diff_0    ;
wire    [31:0]  csr_era_diff_0      ;
wire    [31:0]  csr_badv_diff_0     ;
wire	[31:0]  csr_eentry_diff_0   ;
wire 	[31:0]  csr_tlbidx_diff_0   ;
wire 	[31:0]  csr_tlbehi_diff_0   ;
wire 	[31:0]  csr_tlbelo0_diff_0  ;
wire 	[31:0]  csr_tlbelo1_diff_0  ;
wire 	[31:0]  csr_asid_diff_0     ;
wire 	[31:0]  csr_save0_diff_0    ;
wire 	[31:0]  csr_save1_diff_0    ;
wire 	[31:0]  csr_save2_diff_0    ;
wire 	[31:0]  csr_save3_diff_0    ;
wire 	[31:0]  csr_tid_diff_0      ;
wire 	[31:0]  csr_tcfg_diff_0     ;
wire 	[31:0]  csr_tval_diff_0     ;
wire 	[31:0]  csr_ticlr_diff_0    ;
wire 	[31:0]  csr_llbctl_diff_0   ;
wire 	[31:0]  csr_tlbrentry_diff_0;
wire 	[31:0]  csr_dmw0_diff_0     ;
wire 	[31:0]  csr_dmw1_diff_0     ;
wire 	[31:0]  csr_pgdl_diff_0     ;
wire 	[31:0]  csr_pgdh_diff_0     ;

always @(posedge aclk) begin
    if (reset) begin
        {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr, cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data, cmt_csr_rstat_en, cmt_csr_data} <= 0;
        {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
        {trap, trap_code, cycleCnt, instrCnt} <= 0;
    end else if (~trap) begin
        cmt_valid       <= inst_valid_diff          ;
        cmt_cnt_inst    <= cnt_inst_diff            ;
        cmt_timer_64    <= timer_64_diff            ;
        cmt_inst_ld_en  <= inst_ld_en_diff          ;
        cmt_ld_paddr    <= ld_paddr_diff            ;
        cmt_ld_vaddr    <= ld_vaddr_diff            ;
        cmt_inst_st_en  <= inst_st_en_diff          ;
        cmt_st_paddr    <= st_paddr_diff            ;
        cmt_st_vaddr    <= st_vaddr_diff            ;
        cmt_st_data     <= st_data_diff             ;
        cmt_csr_rstat_en<= csr_rstat_en_diff        ;
        cmt_csr_data    <= csr_data_diff            ;

        cmt_wen     <=  debug0_wb_rf_wen             ;
        cmt_wdest   <=  {3'd0, debug0_wb_rf_wnum}   ;
        cmt_wdata   <=  debug0_wb_rf_wdata          ;
        cmt_pc      <=  debug0_wb_pc                ;
        cmt_inst    <=  debug0_wb_inst              ;
        cmt_excp_flush  <= wb_ex                    ;
        cmt_ertn        <= ws_ertn_op               ;
        cmt_csr_ecode   <= ws_ecode                 ;
        cmt_tlbfill_en  <= tlbfill_en               ;
        cmt_rand_index  <= tlb_w_rand_index         ;

        trap            <= 0                        ;
        trap_code       <= regs[10][7:0]            ;
        cycleCnt        <= cycleCnt + 1             ;
        instrCnt        <= instrCnt + inst_valid_diff;
    end
end

DifftestInstrCommit DifftestInstrCommit(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_valid      ),
    .pc                 (cmt_pc         ),
    .instr              (cmt_inst       ),
    .skip               (0              ),
    .is_TLBFILL         (cmt_tlbfill_en ),
    .TLBFILL_index      (cmt_rand_index ),
    .is_CNTinst         (cmt_cnt_inst   ),
    .timer_64_value     (cmt_timer_64   ),
    .wen                (cmt_wen        ),
    .wdest              (cmt_wdest      ),
    .wdata              (cmt_wdata      ),
    .csr_rstat          (cmt_csr_rstat_en),
    .csr_data           (cmt_csr_data   )
);

DifftestExcpEvent DifftestExcpEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .excp_valid         (cmt_excp_flush ),
    .eret               (cmt_ertn       ),
    .intrNo             (csr_estat_diff_0[12:2]),
    .cause              (cmt_csr_ecode  ),
    .exceptionPC        (cmt_pc         ),
    .exceptionInst      (cmt_inst       )
);

DifftestTrapEvent DifftestTrapEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .valid              (trap           ),
    .code               (trap_code      ),
    .pc                 (cmt_pc         ),
    .cycleCnt           (cycleCnt       ),
    .instrCnt           (instrCnt       )
);

DifftestStoreEvent DifftestStoreEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_st_en ),
    .storePAddr         (cmt_st_paddr   ),
    .storeVAddr         (cmt_st_vaddr   ),
    .storeData          (cmt_st_data    )
);

DifftestLoadEvent DifftestLoadEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_ld_en ),
    .paddr              (cmt_ld_paddr   ),
    .vaddr              (cmt_ld_vaddr   )
);

DifftestCSRRegState DifftestCSRRegState(
    .clock              (aclk               ),
    .coreid             (0                  ),
    .crmd               (csr_crmd_diff_0    ),
    .prmd               (csr_prmd_diff_0    ),
    .euen               (0                  ),
    .ecfg               (csr_ectl_diff_0    ),
    .estat              (csr_estat_diff_0   ),
    .era                (csr_era_diff_0     ),
    .badv               (csr_badv_diff_0    ),
    .eentry             (csr_eentry_diff_0  ),
    .tlbidx             (csr_tlbidx_diff_0  ),
    .tlbehi             (csr_tlbehi_diff_0  ),
    .tlbelo0            (csr_tlbelo0_diff_0 ),
    .tlbelo1            (csr_tlbelo1_diff_0 ),
    .asid               (csr_asid_diff_0    ),
    .pgdl               (csr_pgdl_diff_0    ),
    .pgdh               (csr_pgdh_diff_0    ),
    .save0              (csr_save0_diff_0   ),
    .save1              (csr_save1_diff_0   ),
    .save2              (csr_save2_diff_0   ),
    .save3              (csr_save3_diff_0   ),
    .tid                (csr_tid_diff_0     ),
    .tcfg               (csr_tcfg_diff_0    ),
    .tval               (csr_tval_diff_0    ),
    .ticlr              (csr_ticlr_diff_0   ),
    .llbctl             (csr_llbctl_diff_0  ),
    .tlbrentry          (csr_tlbrentry_diff_0),
    .dmw0               (csr_dmw0_diff_0    ),
    .dmw1               (csr_dmw1_diff_0    )
);

DifftestGRegState DifftestGRegState(
    .clock              (aclk       ),
    .coreid             (0          ),
    .gpr_0              (0          ),
    .gpr_1              (regs[1]    ),
    .gpr_2              (regs[2]    ),
    .gpr_3              (regs[3]    ),
    .gpr_4              (regs[4]    ),
    .gpr_5              (regs[5]    ),
    .gpr_6              (regs[6]    ),
    .gpr_7              (regs[7]    ),
    .gpr_8              (regs[8]    ),
    .gpr_9              (regs[9]    ),
    .gpr_10             (regs[10]   ),
    .gpr_11             (regs[11]   ),
    .gpr_12             (regs[12]   ),
    .gpr_13             (regs[13]   ),
    .gpr_14             (regs[14]   ),
    .gpr_15             (regs[15]   ),
    .gpr_16             (regs[16]   ),
    .gpr_17             (regs[17]   ),
    .gpr_18             (regs[18]   ),
    .gpr_19             (regs[19]   ),
    .gpr_20             (regs[20]   ),
    .gpr_21             (regs[21]   ),
    .gpr_22             (regs[22]   ),
    .gpr_23             (regs[23]   ),
    .gpr_24             (regs[24]   ),
    .gpr_25             (regs[25]   ),
    .gpr_26             (regs[26]   ),
    .gpr_27             (regs[27]   ),
    .gpr_28             (regs[28]   ),
    .gpr_29             (regs[29]   ),
    .gpr_30             (regs[30]   ),
    .gpr_31             (regs[31]   )
);
`endif

assign ws_hw_int_in = intrpt;

assign inst_sram_wr = |inst_sram_wstrb;
endmodule
