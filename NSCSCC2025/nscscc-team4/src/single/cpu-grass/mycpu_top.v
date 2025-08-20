module core_top(
    input         aclk,
    input         aresetn,
    input  [7:0]  intrpt,
    
    // AXI bridge interface
    // ar 读请求通道
    output     [ 3:0] arid,     //取指0,取数1
    output     [31:0] araddr,   //读请求的地址
    output     [ 7:0] arlen,    //固定为0
    output     [ 2:0] arsize,   //读请求传输长度
    output     [ 1:0] arburst,  //固定为0b01
    output     [ 1:0] arlock,   //固定为0
    output     [ 3:0] arcache,  //固定为0
    output     [ 2:0] arprot,   //固定为0
    output            arvalid,  //握手信号,读请求地址有效
    input             arready,  //握手信号,slave准备好
    // r 读响应通道
    input      [ 3:0] rid,      //0对应取指,1对应数据
    input      [31:0] rdata,    //读请求的读回数据
    input      [ 1:0] rresp,    //可忽略
    input             rlast,    //可忽略
    input             rvalid,   //
    output            rready,   //
    // aw 写请求通道
    output     [ 3:0] awid,     //固定为1
    output     [31:0] awaddr,   //写请求地址
    output     [ 7:0] awlen,    //固定为0
    output     [ 2:0] awsize,   //写请求传输大小
    output     [ 1:0] awburst,  //固定为0b01
    output     [ 1:0] awlock,   //固定为0
    output     [ 3:0] awcache,  //固定为0
    output     [ 2:0] awprot,   //固定为0
    output            awvalid,  //
    input             awready,  //
    // w 写数据通道
    output     [ 3:0] wid,      //固定为1
    output     [31:0] wdata,    //写请求地址
    output     [ 3:0] wstrb,    //选位置
    output            wlast,    //固定为1
    output            wvalid,   //
    input             wready,   //
    // b写响应通道
    input      [ 3:0] bid,      //可忽略
    input      [ 1:0] bresp,    //可忽略
    input             bvalid,   //
    output            bready,   //

    //debug 留接口就好，不需要实现功能
    input           break_point,
    input           infor_flag,
    input  [ 4:0]   reg_num,
    output          ws_valid,
    output [31:0]   rf_rdata,

    // trace debug interface
    output [31:0] debug0_wb_pc,
    output [ 3:0] debug0_wb_rf_wen,
    output [ 4:0] debug0_wb_rf_wnum,
    output [31:0] debug0_wb_rf_wdata
);

// cache
    // inst
    wire            inst_rd_req;    // 相当于把之前的inst_sram_req拆成了读和写请求
    wire [2:0 ]     inst_rd_type;   // 
    wire [31:0]     inst_rd_addr;   // 同理拆成读和写地址
    wire            inst_rd_rdy;  
    wire            inst_ret_valid; // 读响应
    wire [1:0 ]     inst_ret_last;  // ?
    wire [31:0]     inst_ret_data;  // 读数据
    wire            inst_wr_req;  
    wire [2:0 ]     inst_wr_type;
    wire [31:0]     inst_wr_addr; 
    wire [3:0 ]     inst_wr_wstrb;
    wire [127:0]    inst_wr_data; 
    wire            inst_wr_rdy;
    // data
    wire            data_rd_req;  
    wire [2:0 ]     data_rd_type; 
    wire [31:0]     data_rd_addr; 
    wire            data_rd_rdy;  
    wire            data_ret_valid;
    wire [1:0 ]     data_ret_last;
    wire [31:0]     data_ret_data;
    wire            data_wr_req;  
    wire [2:0 ]     data_wr_type; 
    wire [31:0]     data_wr_addr; 
    wire [3:0 ]     data_wr_wstrb;
    wire [127:0]    data_wr_data;
    wire            data_wr_rdy;



    `ifdef DIFFTEST_EN
    // difftest
    // from MEM_stage
    wire    [31:0]  debug0_wb_inst_diff ;
    wire            mem_valid_diff      ;
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


    wire [ 4:0]     rand_index_diff;
    wire            MEM_ex_diff;
    wire            MEM_ertn_diff;
    wire            tlbfill_en_diff;
    wire [ 5:0]     MEM_csr_ecode_diff;


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


    wire           inst_valid_diff = mem_valid_diff;
    `endif
    reg reset;
    always@(posedge aclk) begin
        reset <= ~aresetn;
    end
    // BUFG BUFG_inst (
    //   .O(reset), // 1-bit output: Clock output.
    //   .I(aresetn)  // 1-bit input: Clock input.
    // );

    cpu_core u_cpu_core(
        .clk(aclk),
        .reset(reset),
        .hw_int_in(intrpt),
        // cache and axi
        .inst_rd_req(inst_rd_req),
        .inst_rd_type(inst_rd_type),
        .inst_rd_addr(inst_rd_addr),
        .inst_rd_rdy(inst_rd_rdy),
        .inst_ret_valid(inst_ret_valid),
        .inst_ret_last(inst_ret_last),
        .inst_ret_data(inst_ret_data),
        .inst_wr_req(inst_wr_req),
        .inst_wr_type(inst_wr_type),
        .inst_wr_addr(inst_wr_addr),
        .inst_wr_wstrb(inst_wr_wstrb),
        .inst_wr_data(inst_wr_data),
        .inst_wr_rdy(inst_wr_rdy),
        .data_rd_req(data_rd_req),
        .data_rd_type(data_rd_type),
        .data_rd_addr(data_rd_addr),
        .data_rd_rdy(data_rd_rdy),
        .data_ret_valid(data_ret_valid),
        .data_ret_last(data_ret_last),
        .data_ret_data(data_ret_data),
        .data_wr_req(data_wr_req),
        .data_wr_type(data_wr_type),
        .data_wr_addr(data_wr_addr),
        .data_wr_wstrb(data_wr_wstrb),
        .data_wr_data(data_wr_data),
        .data_wr_rdy(data_wr_rdy),
        // trace debug interface
        .debug_wb_pc(debug0_wb_pc),
        .debug_wb_rf_we(debug0_wb_rf_wen),
        .debug_wb_rf_wnum(debug0_wb_rf_wnum),
        .debug_wb_rf_wdata(debug0_wb_rf_wdata)

        `ifdef DIFFTEST_EN
        ,
        .debug0_wb_inst_diff (debug0_wb_inst_diff ),

        .mem_valid_diff      (mem_valid_diff      ),
        .cnt_inst_diff       (cnt_inst_diff       ),
        .timer_64_diff       (timer_64_diff       ),
        .inst_ld_en_diff     (inst_ld_en_diff     ),
        .ld_paddr_diff       (ld_paddr_diff       ),
        .ld_vaddr_diff       (ld_vaddr_diff       ),
        .inst_st_en_diff     (inst_st_en_diff     ),
        .st_paddr_diff       (st_paddr_diff       ),
        .st_vaddr_diff       (st_vaddr_diff       ),
        .st_data_diff        (st_data_diff        ),
        .csr_rstat_en_diff   (csr_rstat_en_diff   ),
        .csr_data_diff       (csr_data_diff       ),

        .rand_index_diff     (rand_index_diff     ),
        .MEM_ex_diff         (MEM_ex_diff         ),
        .MEM_ertn_diff       (MEM_ertn_diff       ),
        .tlbfill_en_diff     (tlbfill_en_diff     ),
        .MEM_csr_ecode_diff  (MEM_csr_ecode_diff  ),

        .rf_to_diff(regs),

        .csr_crmd_diff_0     (csr_crmd_diff_0     ),
        .csr_prmd_diff_0     (csr_prmd_diff_0     ),
        .csr_ectl_diff_0     (csr_ectl_diff_0     ),
        .csr_estat_diff_0    (csr_estat_diff_0    ),
        .csr_era_diff_0      (csr_era_diff_0      ),
        .csr_badv_diff_0     (csr_badv_diff_0     ),
        .csr_eentry_diff_0   (csr_eentry_diff_0   ),
        .csr_tlbidx_diff_0   (csr_tlbidx_diff_0   ),
        .csr_tlbehi_diff_0   (csr_tlbehi_diff_0   ),
        .csr_tlbelo0_diff_0  (csr_tlbelo0_diff_0  ),
        .csr_tlbelo1_diff_0  (csr_tlbelo1_diff_0  ),
        .csr_asid_diff_0     (csr_asid_diff_0     ),
        .csr_save0_diff_0    (csr_save0_diff_0    ),
        .csr_save1_diff_0    (csr_save1_diff_0    ),
        .csr_save2_diff_0    (csr_save2_diff_0    ),
        .csr_save3_diff_0    (csr_save3_diff_0    ),
        .csr_tid_diff_0      (csr_tid_diff_0      ),
        .csr_tcfg_diff_0     (csr_tcfg_diff_0     ),
        .csr_tval_diff_0     (csr_tval_diff_0     ),
        .csr_ticlr_diff_0    (csr_ticlr_diff_0    ),
        .csr_llbctl_diff_0   (csr_llbctl_diff_0   ),
        .csr_tlbrentry_diff_0(csr_tlbrentry_diff_0),
        .csr_dmw0_diff_0     (csr_dmw0_diff_0     ),
        .csr_dmw1_diff_0     (csr_dmw1_diff_0     ),
        .csr_pgdl_diff_0     (csr_pgdl_diff_0     ),
        .csr_pgdh_diff_0     (csr_pgdh_diff_0     )
        `endif
    );

    axi_bridge u_axi_bridge(
        .aclk(aclk),
        .reset(reset),
        // AXI interface
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
        .inst_rd_req(inst_rd_req),
        .inst_rd_type(inst_rd_type),
        .inst_rd_addr(inst_rd_addr),
        .inst_rd_rdy(inst_rd_rdy),
        .inst_ret_valid(inst_ret_valid),
        .inst_ret_last(inst_ret_last),
        .inst_ret_data(inst_ret_data),
        .inst_wr_req(inst_wr_req),
        .inst_wr_type(inst_wr_type),
        .inst_wr_addr(inst_wr_addr),
        .inst_wr_wstrb(inst_wr_wstrb),
        .inst_wr_data(inst_wr_data),
        .inst_wr_rdy(inst_wr_rdy),
        // data sram interface
        .data_rd_req(data_rd_req),
        .data_rd_type(data_rd_type),
        .data_rd_addr(data_rd_addr),
        .data_rd_rdy(data_rd_rdy),
        .data_ret_valid(data_ret_valid),
        .data_ret_last(data_ret_last),
        .data_ret_data(data_ret_data),
        .data_wr_req(data_wr_req),
        .data_wr_type(data_wr_type),
        .data_wr_addr(data_wr_addr),
        .data_wr_wstrb(data_wr_wstrb),
        .data_wr_data(data_wr_data),
        .data_wr_rdy(data_wr_rdy)
    );
`ifdef DIFFTEST_EN
always @(posedge aclk) begin
    if (~aresetn) begin
        {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr, cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data, cmt_csr_rstat_en, cmt_csr_data} <= 0;
        {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
        {trap, trap_code, cycleCnt, instrCnt} <= 0;
    end
    else if (~trap) begin
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

        cmt_wen   <=  debug0_wb_rf_wen         ;
        cmt_wdest <=  {3'd0, debug0_wb_rf_wnum};
        cmt_wdata <=  debug0_wb_rf_wdata       ;
        cmt_pc    <=  debug0_wb_pc             ;
        cmt_inst  <=  debug0_wb_inst_diff           ;

        cmt_excp_flush  <= MEM_ex_diff              ;
        cmt_ertn        <= MEM_ertn_diff            ;
        cmt_csr_ecode   <= MEM_csr_ecode_diff       ;
        cmt_tlbfill_en  <= tlbfill_en_diff          ;
        cmt_rand_index  <= rand_index_diff          ;

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
endmodule