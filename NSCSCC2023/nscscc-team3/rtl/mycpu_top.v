`include "header.v"
/*
����ο�������Ƶ������
    DIFFTEST���Խӿڵ�ʵ�ַ����ο���nscscc-openLA500��
    ��ˮ�����ַ�ѹ����һ��ʼ�ο���CPU���ʵս�����������ȫͬ����ƣ�����ʹ����ʽ�źš�
*/
module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [7:0]  intrpt,
    //AXI�ӿ�
    output wire [3 :0] arid   ,
    output wire [31:0] araddr ,
    output wire [7 :0] arlen  ,
    output wire [2 :0] arsize ,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock ,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot ,
    output wire        arvalid,
    input  wire        arready,
    input  wire [3 :0] rid    ,
    input  wire [31:0] rdata  ,
    input  wire [1 :0] rresp  ,
    input  wire        rlast  ,
    input  wire        rvalid ,
    output wire        rready ,
    output wire [3 :0] awid   ,
    output wire [31:0] awaddr ,
    output wire [7 :0] awlen  ,
    output wire [2 :0] awsize ,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock ,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot ,
    output wire        awvalid,
    input  wire        awready,
    output wire [3 :0] wid    ,
    output wire [31:0] wdata  ,
    output wire [3 :0] wstrb  ,
    output wire        wlast  ,
    output wire        wvalid ,
    input  wire        wready ,
    input  wire [3 :0] bid    ,
    input  wire [1 :0] bresp  ,
    input  wire        bvalid ,
    output wire        bready ,
        //debug 留接口就好，不需要实现功能
    input           break_point,
    input           infor_flag,
    input  [ 4:0]   reg_num,
    output          ws_valid,
    output [31:0]   rf_rdata,
    // trace debug interface
    output wire [31:0] debug0_wb_pc,
    output wire [3 :0] debug0_wb_rf_wen,
    output wire [4 :0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata
);
    //wire [7:0]  intrpt = 0;
    // inst sram interface
    wire        inst_sram_req;
    wire        inst_sram_wr;
    wire [1:0]  inst_sram_size;
    wire [3:0]  inst_sram_wstrb;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    wire        icache_stall;
    wire [31:0] inst_sram_rdata;
    wire [1:0]  inst_sram_mat;

    wire        icache_rd_req;
    wire [2:0]  icache_rd_type;
    wire [31:0] icache_rd_addr;
    wire        icache_rd_rdy;
    wire        icache_ret_valid;
    wire [1:0]  icache_ret_last;
    wire [31:0] icache_ret_data;
    wire        dcache_rd_req;
    wire [2:0]  dcache_rd_type;
    wire [31:0] dcache_rd_addr;
    wire        dcache_rd_rdy;
    wire        dcache_ret_valid;
    wire [1:0]  dcache_ret_last;
    wire [31:0] dcache_ret_data;
    wire        dcache_wr_req;
    wire        dcache_wr_rdy;
    wire [2:0]  dcache_wr_type;
    wire [31:0] dcache_wr_addr;
    wire [3:0]  dcache_wr_wstrb;
    wire [127:0]dcache_wr_data;
    //icache cacop
    wire        icache_is_cacop,dcache_is_cacop;
    wire [1:0]  dcache_cacop_code;
    wire    [1:0]   icacop_code_4_3;
    wire    [7:0]   icache_index;
    // data sram interface
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [1:0]  data_sram_size;
    wire [3:0]  data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire [31:0] data_sram_rdata;
    wire [1:0]  data_sram_mat;
    wire        dcache_stall;
    //������������ͨ·�������źű������塪������
    //data of if and id stage
    wire pif_to_if_valid;
    wire [`WIDTH_EX_JUMP_BUS-1:0]           ex_jump_bus;
    wire [`WIDTH_PIF_TO_IF_BUS-1:0]         pif_to_if_bus;
    wire [`WIDTH_BR_BUS-1:0]                br_bus;
    wire pif_wen;                                           //pif��ˮ���Ĵ����Ƿ��д
    wire stall_if;
    wire stall_if_to_wb;
    wire if_to_id_valid;
    wire [`WIDTH_IF_TO_ID_BUS-1:0]          if_to_id_bus;
    wire id_to_exe_valid;
    wire stall_id;
    wire [`WIDTH_WB_TO_RF_BUS-1:0]          wb_to_rf_bus;
    wire [`WIDTH_ID_TO_EXE_BUS-1:0]         id_to_exe_bus;
    wire exe_to_pmem_valid;
    wire stall_exe;
    wire [`WIDTH_EXE_TO_PMEM_BUS-1:0]       exe_to_pmem_bus;
    wire [`WIDTH_BYPASS_FROM_EXE_BUS-1:0]   bypass_from_exe_bus;
    wire pmem_to_mem_valid;
    wire stall_pmem;
    wire [`WIDTH_PMEM_TO_MEM_BUS-1:0]       pmem_to_mem_bus;
    wire [`WIDTH_BYPASS_FROM_PMEM_BUS-1:0]   bypass_from_pmem_bus;
    wire stall_mem;
    wire [`WIDTH_BYPASS_FROM_MEM_BUS-1:0]   bypass_from_mem_bus;
    //wire [`WIDTH_BYPASS_TO_EXE_BUS-1:0]     bypass_to_mem_bus;

    wire flush_br;//����ð�յ��µ�flush
    wire flush_ex;          //�����ertn���µ�flush
    wire flush_refetch;     //TLB/Cache/IBAR�Ȳ�������ȡָ���µ�flush
    wire [`WIDTH_REFETCH_BUS-1:0]          refetch_bus;
    wire [`WIDTH_AGU_TO_TLB_BUS-1:0]       agu_to_tlb_bus;
    //�������
    wire                                   has_intr;  //�жϲ����ź�
    wire [1:0]                             plv;
    //flush for all stages
    wire flush_pif = flush_br | flush_ex | flush_refetch;
    wire flush_if = flush_br | flush_ex | flush_refetch;
    wire flush_id = flush_br | flush_ex | flush_refetch;
    wire flush_exe = flush_br | flush_ex | flush_refetch;
    wire flush_pmem = flush_ex | flush_refetch;
    //MMU
    wire  [31:0]                           inst_sram_vaddr;
    wire  [31:0]                           inst_sram_paddr;
    wire  [31:0]                           data_sram_vaddr;
    wire                                   ex_pif;
    wire  [5:0]                            ecode_pif;
    wire                                   itlb_stall;
    //* DIFFTEST ������
 `ifdef DIFFTEST_EN
    // difftest
    // from wb_stage
    wire            mem_valid_diff;
    wire    [31:0]  instr_diff;
    wire            cnt_instr_diff;
    wire    [63:0]  stable_counter_diff;
    
    wire            real_load_diff;
    wire            real_store_diff;
    wire    [31:0]  memvis_paddr_diff;
    wire    [31:0]  memvis_vaddr_diff;
    wire    [31:0]  memvis_data_diff;
    wire            csr_rstat_en_diff;
    //wire    [31:0]  csr_data_diff;
    wire    [31:0]  rf_regs_diff [31:0];
    wire    [`WIDTH_CSR_DIFF-1:0] csr_all_diff;
    wire            ex_diff;
    wire            is_ertn_diff;
    wire    [5:0]   ecode_diff; 

    wire            is_tlbfill_diff;
    wire    [`WIDTH_TLB_INDEX-1:0]   tlbfill_index_diff;

   
`endif
    sram_axi_bridge SRAM_AXI_BRIDGE(
        .aclk(aclk),
        .aresetn(aresetn),
        //axi����
        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),
        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),
        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),
        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),
        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),
        // inst sram interface
        .icache_rd_req(icache_rd_req),
        .icache_rd_type(icache_rd_type),
        .icache_rd_addr(icache_rd_addr),
        .icache_rd_rdy(icache_rd_rdy),
        .icache_ret_valid(icache_ret_valid),
        .icache_ret_last(icache_ret_last),
        .icache_ret_data(icache_ret_data),

        .dcache_rd_req(dcache_rd_req),
        .dcache_rd_type(dcache_rd_type),
        .dcache_rd_addr(dcache_rd_addr),
        .dcache_rd_rdy(dcache_rd_rdy),
        .dcache_ret_valid(dcache_ret_valid),
        .dcache_ret_last(dcache_ret_last),
        .dcache_ret_data(dcache_ret_data),
        .dcache_wr_req(dcache_wr_req),
        .dcache_wr_rdy(dcache_wr_rdy),
        .dcache_wr_type(dcache_wr_type),
        .dcache_wr_addr(dcache_wr_addr),
        .dcache_wr_wstrb(dcache_wr_wstrb),
        .dcache_wr_data(dcache_wr_data)
    );

    /***********************************************/
    //��PIF Stage��
    pif_stage PIF_STAGE(
        .clk            (aclk),
        .rst_n          (aresetn),
        .flush          (flush_pif),
        .btb_clean      (flush_refetch),
        .br_bus         (br_bus),
        .refetch_bus    (refetch_bus),
        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .stall_exe      (stall_exe),
        .stall_pmem     (stall_pmem),
        .stall_mem      (stall_mem),
        .pif_wen        (pif_wen),
        .pif_to_if_bus  (pif_to_if_bus),
        .pif_to_if_valid(pif_to_if_valid),
        .ex_jump_bus    (ex_jump_bus),
        .inst_sram_req  (inst_sram_req),
        .inst_sram_wr   (inst_sram_wr),
        .inst_sram_size (inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr (inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_vaddr(inst_sram_vaddr),
        .inst_sram_paddr(inst_sram_paddr),
`ifdef PERF_STAT_EN
        .icache_is_uncached(~inst_sram_mat[0]),
`endif
        .ex_pif         (ex_pif),
        .ecode_pif      (ecode_pif),
        .itlb_stall     (itlb_stall),
        .icache_index   (icache_index),
        .icacop_code_4_3_pif(icacop_code_4_3),
        .icache_is_cacop_pif(icache_is_cacop)
    );
    icache_two_way ICACHE(
        .clk(aclk),
        .resetn(aresetn),
        .pif_wen(pif_wen),
        .stall_if_to_wb(stall_if_to_wb),    //��if��wbֻҪ�������źŲ�����icache��������
        .valid(inst_sram_req),
        .index(icache_index),
        .paddr(inst_sram_addr),
        .stall(icache_stall),
        .rdata(inst_sram_rdata),
        .uncached(~inst_sram_mat[0]),
        .rd_req(icache_rd_req),
        .rd_type(icache_rd_type),
        .rd_addr(icache_rd_addr),
        .rd_rdy(icache_rd_rdy),
        .ret_valid(icache_ret_valid),
        .ret_last(icache_ret_last),
        .ret_data(icache_ret_data),
        .is_cacop(icache_is_cacop),
        .cacop(icacop_code_4_3),
        .cacop01_way(inst_sram_addr[0])
    );
    /***********************************************/
    //��IF Stage��
    if_stage IF_STAGE(
        .clk(aclk),
        .rst_n(aresetn),
        .flush(flush_if),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .stall_exe(stall_exe),
        .stall_pmem(stall_pmem),
        .stall_mem(stall_mem),
        .stall_if_to_wb(stall_if_to_wb),
        .if_to_id_bus(if_to_id_bus),
        .if_to_id_valid(if_to_id_valid),
        .pif_to_if_bus(pif_to_if_bus),
        .pif_to_if_valid(pif_to_if_valid),
        .inst_sram_rdata(inst_sram_rdata),
        .icache_stall(icache_stall)
    );
    /***********************************************/
    //��ID Stage��
    id_stage ID_STAGE(
        .clk(aclk),
        .rst_n(aresetn),
        .stall_exe(stall_exe),
        .stall_pmem(stall_pmem),
        .stall_mem(stall_mem),
        .stall_id(stall_id),
        .flush(flush_id),
        .if_to_id_valid(if_to_id_valid),
        .wb_to_rf_bus(wb_to_rf_bus),            //wb��regfile������
        .if_to_id_bus(if_to_id_bus),            //if��id������
        .id_to_exe_bus(id_to_exe_bus),          //id��exe������
        .id_to_exe_valid(id_to_exe_valid),      //id stage �Ƿ���һ��ָ����Խ�����һ��
        .bypass_from_exe_bus(bypass_from_exe_bus),
        .bypass_from_pmem_bus(bypass_from_pmem_bus),
        .bypass_from_mem_bus(bypass_from_mem_bus),
        .has_intr(has_intr),                  //�жϲ����ź�
        .plv(plv)
        `ifdef DIFFTEST_EN
        ,
        .rf_regs_diff(rf_regs_diff)             // difftest
        `endif
    );
    
    //��EXE Stage��
    wire [31:0] data_sram_vaddr_exe;
    exe_stage EXE_STAGE(
        .clk(aclk),
        .rst_n(aresetn),
        .flush(flush_exe),
        .stall_exe(stall_exe),
        .stall_pmem(stall_pmem),
        .stall_mem(stall_mem),
        .id_to_exe_valid(id_to_exe_valid),
        .id_to_exe_bus(id_to_exe_bus),   
        .exe_to_pmem_bus(exe_to_pmem_bus),   
        .exe_to_pmem_valid(exe_to_pmem_valid),
        .bypass_from_exe_bus(bypass_from_exe_bus),
        .flush_br(flush_br),
        .br_bus(br_bus),
        .agu_to_tlb_bus(agu_to_tlb_bus),
        .data_sram_vaddr_exe(data_sram_vaddr_exe)
    );
    /***********************************************/
    //zzy:dcache
    wire pmem_wen;
    wire [4:0] cacop_code_pmem;
    assign dcache_cacop_code = cacop_code_pmem[4:3];
    //��PMEM Stage��
    pmem_stage PMEM_STAGE(
        .clk(aclk),
        .rst_n(aresetn),
        .flush(flush_pmem),
        .flush_pif(flush_pif),
        .stall_if_to_wb     (stall_if_to_wb),
        .stall_pmem(stall_pmem),
        .stall_mem(stall_mem),
        .flush_ex(flush_ex),                        //�����ertn���µ�flush
        .flush_refetch(flush_refetch),
        .has_intr(has_intr),
        .hwi(intrpt),
        .refetch_bus(refetch_bus),
        .ex_jump_bus(ex_jump_bus),
        .data_sram_req(data_sram_req),
        .data_sram_wr (data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),           
        .data_sram_wdata(data_sram_wdata),
        .data_sram_mat  (data_sram_mat),
        .data_sram_vaddr (data_sram_vaddr),
        .plv(plv),
        //zzy
        .dcacop_en(dcache_is_cacop),
        .cacop_op(cacop_code_pmem),
        .pmem_wen(pmem_wen),
        //.bypass_to_mem_bus(bypass_to_mem_bus), 
        .exe_to_pmem_valid(exe_to_pmem_valid),
        .exe_to_pmem_bus(exe_to_pmem_bus),   
        .pmem_to_mem_bus(pmem_to_mem_bus),   
        .pmem_to_mem_valid(pmem_to_mem_valid),
        .bypass_from_pmem_bus(bypass_from_pmem_bus),
        .inst_sram_vaddr(inst_sram_vaddr),
        .inst_sram_paddr(inst_sram_paddr),
        .inst_sram_mat  (inst_sram_mat),
        .itlb_stall     (itlb_stall),
        .ex_pif(ex_pif),
        .ecode_pif(ecode_pif),
        .agu_to_tlb_bus(agu_to_tlb_bus)
`ifdef DIFFTEST_EN
        ,
        .csr_all_diff(csr_all_diff)
`endif
    );
    dcache_two_way DCACHE(
        .clk(aclk),
        .resetn(aresetn),
        .pmem_wen(pmem_wen),    //!!
        .stall_mem_to_wb(stall_mem), //!!
        .valid(data_sram_req),
        .op(data_sram_wr),
        .size({1'b0,data_sram_size}),   //!!
        .index(data_sram_vaddr_exe[11:4]), //!!
        .paddr(data_sram_addr),
        .wstrb(data_sram_wstrb),
        .wdata(data_sram_wdata),
        .stall(dcache_stall),
        .rdata(data_sram_rdata),
        .uncached(!data_sram_mat[0]),
        .rd_req(dcache_rd_req),
        .rd_type(dcache_rd_type),
        .rd_addr(dcache_rd_addr),
        .rd_rdy(dcache_rd_rdy),
        .ret_valid(dcache_ret_valid),
        .ret_last(dcache_ret_last),
        .ret_data(dcache_ret_data),
        .wr_req(dcache_wr_req),
        .wr_rdy(dcache_wr_rdy),
        .wr_type(dcache_wr_type),
        .wr_addr(dcache_wr_addr),
        .wr_wstrb(dcache_wr_wstrb),
        .wr_data(dcache_wr_data),
        .is_cacop(dcache_is_cacop),
        .cacop(dcache_cacop_code),
        .cacop01_way(data_sram_vaddr[0])
    );
    /***********************************************/
    //��MEM Stage��
    mem_stage MEM_STAGE(
        .clk(aclk),
        .rst_n(aresetn),
        //.flush(flush_mem),
        .stall_mem(stall_mem),
        .pmem_to_mem_valid(pmem_to_mem_valid),
        .pmem_to_mem_bus(pmem_to_mem_bus),   
        .bypass_from_mem_bus(bypass_from_mem_bus),
        .data_sram_rdata(data_sram_rdata),
        .dcache_stall(dcache_stall),
        .wb_to_rf_bus(wb_to_rf_bus),
        .debug_wb_pc(debug0_wb_pc),
        .debug_wb_rf_wen(debug0_wb_rf_wen),
        .debug_wb_rf_wnum(debug0_wb_rf_wnum),
        .debug_wb_rf_wdata(debug0_wb_rf_wdata)
`ifdef DIFFTEST_EN
        ,
        .cnt_instr_diff(cnt_instr_diff),
        .mem_valid_diff(mem_valid_diff),
        .instr_diff(instr_diff),
        .real_load_diff(real_load_diff),
        .real_store_diff(real_store_diff),
        .memvis_paddr_diff(memvis_paddr_diff),
        .memvis_vaddr_diff(memvis_vaddr_diff),
        .memvis_data_diff(memvis_data_diff),
        .stable_counter_diff(stable_counter_diff),
        .csr_rstat_en_diff(csr_rstat_en_diff),
        .ex_diff(ex_diff),
        .is_ertn_diff(is_ertn_diff),
        .ecode_diff(ecode_diff),
        .is_tlbfill_diff(is_tlbfill_diff),
        .tlbfill_index_diff(tlbfill_index_diff)
`endif
    );
    /************************************************/
`ifdef DIFFTEST_EN
    //�ӳ��ύ�Ĵ���
    reg                             cmt_valid;
    reg                             cmt_cnt_instr;
    reg     [63:0]                  cmt_stable_counter;
    reg                             cmt_inst_ld_en;
    reg                             cmt_inst_st_en;
    reg     [31:0]                  cmt_memvis_paddr;
    reg     [31:0]                  cmt_memvis_vaddr;
    reg     [31:0]                  cmt_memvis_data;
    reg                             cmt_csr_rstat_en;
    reg     [`WIDTH_CSR_DIFF-1:0]   cmt_csr_all;
    reg                             cmt_wen;
    reg     [ 7:0]                  cmt_wdest;
    reg     [31:0]                  cmt_wdata;
    reg     [31:0]                  cmt_pc;
    reg     [31:0]                  cmt_inst;

    reg                             cmt_ex;
    reg                             cmt_is_ertn;
    reg     [5:0]                   cmt_ecode;
    reg                             cmt_is_tlbfill;
    reg     [`WIDTH_TLB_INDEX - 1:0] cmt_tlbfill_index;

    // to difftest debug
    reg                             trap;
    reg     [ 7:0]                  trap_code;
    reg     [63:0]                  cycleCnt;
    reg     [63:0]                  instrCnt;

    reg reset_to_1;
    always @(posedge aclk) begin
        reset_to_1 <=0;
    end
    //һЩ�����ӳ�һ�ģ�ȷ������Ӱ��ͬ�����
    always @(posedge aclk) begin
        if (!aresetn) begin
            {cmt_valid, cmt_cnt_instr, cmt_stable_counter, 
            cmt_inst_ld_en, cmt_inst_st_en, cmt_memvis_paddr, cmt_memvis_vaddr, cmt_memvis_data,
            cmt_csr_rstat_en} <= 0;
            {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
            {trap, trap_code, cycleCnt, instrCnt} <= 0;
            cmt_csr_all <=0;
        end else if (~trap) begin
            cmt_valid           <= mem_valid_diff && !ex_diff;
            cmt_cnt_instr       <= cnt_instr_diff;
            cmt_stable_counter  <= stable_counter_diff;
            cmt_inst_ld_en      <= real_load_diff;
            cmt_inst_st_en      <= real_store_diff;
            cmt_memvis_paddr    <= memvis_paddr_diff;
            cmt_memvis_vaddr    <= memvis_vaddr_diff;
            cmt_memvis_data     <= memvis_data_diff;
            cmt_csr_rstat_en    <= csr_rstat_en_diff;
            cmt_wen             <= debug0_wb_rf_wen[0];
            cmt_wdest           <= {3'd0, debug0_wb_rf_wnum};
            cmt_wdata           <=  debug0_wb_rf_wdata;
            cmt_pc              <=  debug0_wb_pc;
            cmt_inst            <=  instr_diff;
            cmt_ex              <= mem_valid_diff && ex_diff;
            cmt_is_ertn         <= is_ertn_diff;
            cmt_ecode           <= ecode_diff;
            cmt_is_tlbfill      <= is_tlbfill_diff;
            cmt_tlbfill_index   <= tlbfill_index_diff;
            cmt_csr_all         <= csr_all_diff;
            trap                <= 0;
            trap_code           <= rf_regs_diff[10][7:0];
            cycleCnt            <= cycleCnt + 1;
            instrCnt            <= instrCnt + mem_valid_diff ;
        end
    end
    DifftestInstrCommit DifftestInstrCommit(
        .clock              (aclk               ),
        .coreid             (0                  ),
        .index              (0                  ),
        .valid              (reset_to_1?0:cmt_valid),
        .pc                 (cmt_pc             ),
        .instr              (cmt_inst           ),
        .skip               (0                  ),
        .is_TLBFILL         (cmt_is_tlbfill     ),
        .TLBFILL_index      (cmt_tlbfill_index  ),
        .is_CNTinst         (cmt_cnt_instr      ),
        .timer_64_value     (cmt_stable_counter ),
        .wen                (cmt_wen            ),
        .wdest              (cmt_wdest          ),
        .wdata              (cmt_wdata          ),
        //// .csr_data      (cmt_csr_data   )
        .csr_rstat          (cmt_csr_rstat_en),
        .csr_data           (cmt_wdata)
    );
    DifftestExcpEvent DifftestExcpEvent(
        .clock              (aclk           ),
        .coreid             (0              ),
        .excp_valid         (cmt_ex),
        .eret               (cmt_is_ertn),
        .intrNo             (cmt_csr_all[32*22+12:32*22+2]),
        .cause              (cmt_ecode),
        .exceptionPC        (cmt_pc),
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
        .storePAddr         (cmt_memvis_paddr   ),
        .storeVAddr         (cmt_memvis_vaddr   ),
        .storeData          (cmt_memvis_data    )
    );

    DifftestLoadEvent DifftestLoadEvent(
        .clock              (aclk           ),
        .coreid             (0              ),
        .index              (0              ),
        .valid              (cmt_inst_ld_en ),
        .paddr              (cmt_memvis_paddr   ),
        .vaddr              (cmt_memvis_vaddr   )
    );

    DifftestCSRRegState DifftestCSRRegState(
        .clock              (aclk               ),
        .coreid             (0                  ),
        .crmd               (cmt_csr_all[32*26-1:32*25]),
        .prmd               (cmt_csr_all[32*25-1:32*24]),
        .euen               (0                  ),
        .ecfg               (cmt_csr_all[32*24-1:32*23]),
        .estat              (cmt_csr_all[32*23-1:32*22]),
        .era                (cmt_csr_all[32*22-1:32*21]),
        .badv               (cmt_csr_all[32*21-1:32*20]),
        .eentry             (cmt_csr_all[32*20-1:32*19]),
        .tlbidx             (cmt_csr_all[32*19-1:32*18]),
        .tlbehi             (cmt_csr_all[32*18-1:32*17]),
        .tlbelo0            (cmt_csr_all[32*17-1:32*16]),
        .tlbelo1            (cmt_csr_all[32*16-1:32*15]),
        .asid               (cmt_csr_all[32*15-1:32*14]),
        .pgdl               (cmt_csr_all[32*14-1:32*13]),
        .pgdh               (cmt_csr_all[32*13-1:32*12]),
        .save0              (cmt_csr_all[32*12-1:32*11]),
        .save1              (cmt_csr_all[32*11-1:32*10]),
        .save2              (cmt_csr_all[32*10-1:32*9]),
        .save3              (cmt_csr_all[32*9-1:32*8]),
        .tid                (cmt_csr_all[32*8-1:32*7]),
        .tcfg               (cmt_csr_all[32*7-1:32*6]),
        .tval               (cmt_csr_all[32*6-1:32*5]),
        .ticlr              (cmt_csr_all[32*5-1:32*4]),
        .llbctl             (cmt_csr_all[32*4-1:32*3]),
        .tlbrentry          (cmt_csr_all[32*3-1:32*2]),
        .dmw0               (cmt_csr_all[32*2-1:32*1]),
        .dmw1               (cmt_csr_all[32*1-1:32*0])
    );
    DifftestGRegState DifftestGRegState(
        .clock              (aclk       ),
        .coreid             (0          ),
        .gpr_0              (0          ),
        .gpr_1              (rf_regs_diff[1]    ),
        .gpr_2              (rf_regs_diff[2]    ),
        .gpr_3              (rf_regs_diff[3]    ),
        .gpr_4              (rf_regs_diff[4]    ),
        .gpr_5              (rf_regs_diff[5]    ),
        .gpr_6              (rf_regs_diff[6]    ),
        .gpr_7              (rf_regs_diff[7]    ),
        .gpr_8              (rf_regs_diff[8]    ),
        .gpr_9              (rf_regs_diff[9]    ),
        .gpr_10             (rf_regs_diff[10]   ),
        .gpr_11             (rf_regs_diff[11]   ),
        .gpr_12             (rf_regs_diff[12]   ),
        .gpr_13             (rf_regs_diff[13]   ),
        .gpr_14             (rf_regs_diff[14]   ),
        .gpr_15             (rf_regs_diff[15]   ),
        .gpr_16             (rf_regs_diff[16]   ),
        .gpr_17             (rf_regs_diff[17]   ),
        .gpr_18             (rf_regs_diff[18]   ),
        .gpr_19             (rf_regs_diff[19]   ),
        .gpr_20             (rf_regs_diff[20]   ),
        .gpr_21             (rf_regs_diff[21]   ),
        .gpr_22             (rf_regs_diff[22]   ),
        .gpr_23             (rf_regs_diff[23]   ),
        .gpr_24             (rf_regs_diff[24]   ),
        .gpr_25             (rf_regs_diff[25]   ),
        .gpr_26             (rf_regs_diff[26]   ),
        .gpr_27             (rf_regs_diff[27]   ),
        .gpr_28             (rf_regs_diff[28]   ),
        .gpr_29             (rf_regs_diff[29]   ),
        .gpr_30             (rf_regs_diff[30]   ),
        .gpr_31             (rf_regs_diff[31]   )
    );
`endif
endmodule
