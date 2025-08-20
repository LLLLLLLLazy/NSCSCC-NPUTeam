`include "header.v"
module id_stage(
    input                                   clk,
    input                                   rst_n,
    input                                   stall_exe,
    input                                   stall_pmem,
    input                                   stall_mem,
    output                                  stall_id,
    input                                   flush,
    input                                   if_to_id_valid,
    input [`WIDTH_IF_TO_ID_BUS-1:0]         if_to_id_bus,       //if到id的数据
    output [`WIDTH_ID_TO_EXE_BUS-1:0]       id_to_exe_bus,      //id到exe的数据
    output                                  id_to_exe_valid,    //id stage 是否有一条指令可以进入下一级
    input [`WIDTH_WB_TO_RF_BUS-1:0]         wb_to_rf_bus,       //wb到rf的数据
    input [`WIDTH_BYPASS_FROM_EXE_BUS-1:0]  bypass_from_exe_bus,
    input [`WIDTH_BYPASS_FROM_PMEM_BUS-1:0] bypass_from_pmem_bus,
    input [`WIDTH_BYPASS_FROM_MEM_BUS-1:0]  bypass_from_mem_bus,
    input                                   has_intr ,          //中断产生信号
    input [1:0]                             plv                //当前的特权级
    //* difftest
`ifdef DIFFTEST_EN
    ,
    output [31:0]   rf_regs_diff [31:0]
`endif 
);
//数据
    wire [31:0] pc_id;
    wire [31:0] instr_id;
    wire [`WIDTH_PDC_BUS-1:0] predecode_bus_id;
    //wire [`INSTR_COUNT-1:0] instr_vec_id;
    wire [2:0]  c_npcsel_id;                                        //pc地址选择信号
    wire [7:0]  c_immsel;                                           //立即数选择                           
    wire [4:0]  rj;
    wire [4:0]  rk;
    wire [4:0]  rd;

    wire [31:0] imm32_id;                                           //最终立即数
    wire [4:0]  rnum_c_id, rnum_c_wb;                               //寄存器写索引
    wire [31:0] rdata_c_wb;                                         //寄存器写数据
    wire [4:0]  rnum_a;                                             //寄存器读索引a
    wire [4:0]  rnum_b;                                             //寄存器读索引b
    wire [31:0] rdata_a;                                            //寄存器读数据a
    wire [31:0] rdata_b;                                            //寄存器读数据b
    wire        c_regwr_id,c_rf_wen_wb;                             //寄存器写使能(c_regwr是译码出的信号，c_rf_wen是考虑了指令有效性后最终通往rf的信号
    wire        c_rnum_b_sel;                                       //寄存器第二个读目标选择
    wire [2:0]  c_rnum_c_sel;                                       //寄存器写目标选择
    wire [3:0]  c_wbsel_id;                                         //最终写寄存器结果选择
    wire [2:0]  c_memwr_id;
    wire [4:0]  c_memrd_id;
    wire        c_alusrc_a_id;                                      //alu输入A选择信号
    wire [2:0]  c_alusrc_b_id;                                      //alu输入B选择信号
    wire [`WIDTH_ALUOP - 1 : 0]  c_aluop_id;                        //alu功能选择
    wire [2:0]  c_mduop_id;
    wire [2:0]  c_reg_as_read;                                      //a、b路两个寄存器是否要读                                    
    wire        c_csrwr_id;
    
    wire [3:0]  c_fwd_a_sel;                                        //id级 旁路选择信号,从高位到低位分别表示来源为mem,pmem,exe,id
    wire [3:0]  c_fwd_b_sel;                                        //id级 旁路选择信号,从高位到低位分别表示来源为mem,pmem,exe,id
    wire [31:0] rdata_a_fwd;                                        //寄存器读数据a的最新旁路值
    wire [31:0] rdata_b_fwd;                                        //寄存器读数据b的最新旁路值
    wire [31:0] rdata_c_exe;                                        //旁路单元转发来的信号
    wire [31:0] rdata_c_pmem;                                       //旁路单元转发来的信号
    wire [31:0] rdata_c_mem;                                        //旁路单元转发来的信号
    wire        c_refetch_id;                                 
    wire        stall_data_hazard;                                  //数据冒险导致的stall
    wire [4:0]  c_brop_id;                                          //分支方式
    //wire [`WIDTH_BYPASS_FROM_ID_BUS-1:0]    bypass_from_id_bus;
    wire [`WIDTH_BYPASS_TO_ID_BUS-1:0]      bypass_to_id_bus;

    //例外
    wire        csr_wmask_id;
    wire [13:0] csr_addr_id;
    
    wire        is_ertn_id;    //是否为ertn指令
    wire        ex_pre_id;     //上一级传来的指令是否有例外(不考虑valid)
    wire        ex_id;         //经过本级后是否有例外(不考虑valid)
    wire [5:0]  ecode_pre_id;
    wire [5:0]  ecode_id;      //例外编码
    wire        ex_sys;        //是否触发syscall例外(不考虑valid)
    wire        ex_brk;        //是否触发断点例外
    wire        ex_ine;        //是否触发指令不存在例外
    wire        ex_ipe;        //是否触发指令特权级错例外
    wire [5:0]  ecode_gen;     //本级产生的例外编码
    wire [2:0]  c_cntsel_id;   //计数器输出选择
    //TLB
    wire        is_tlbrd_id;     //是否为tlbrd指令
    wire        is_tlbwr_id;     //是否为tlbwr指令
    wire        is_tlbfill_id;   //是否为tlbfill指令
    wire        is_tlbsrch_id;   //是否为tlbsrch指令
    wire        is_invtlb_id;    //是否为invtlb指令
    //杂项
    wire        is_idle_id;
    wire        is_ll_w_id;
    wire        is_sc_w_id;
    wire        is_cacop_id;
    wire        is_mdu_instr_id;
    //分支预测
    wire        br_taken_predict_id;
    wire        btb_hit_id;
    wire        is_br_id;
    wire        is_jirl_id;
    wire        btb_tag_unmatch_id;              //pif级判断btb命中,但是tag高位比较失败,实际不命中
    //流水线控制
    reg id_valid;           //id stage 中是否含有效的指令
    reg [`WIDTH_IF_TO_ID_BUS-1:0] if_to_id_reg;
    wire stall;
    wire stall_from_back;
    
    //idle 指令执行时会设置一个lock,阻止后续进来的指令继续执行
    reg idle_lock;
    always @(posedge clk)begin
        if(!rst_n || flush)
            idle_lock <= 0;
        //idle执行
        else if(id_valid && !ex_id && is_idle_id && !stall_from_back)
            idle_lock <= 1;
        //中断唤醒
        else if(has_intr)
            idle_lock <= 0;
    end
    always @(posedge clk)begin
        if_to_id_reg <= stall ? if_to_id_reg : if_to_id_bus;
    end
    always @(posedge clk)begin
        if(!rst_n || flush)
            id_valid <= 0;
        else if(!stall)
            id_valid <= if_to_id_valid;
    end
    
    assign stall_from_back  = stall_exe || stall_pmem || stall_mem;
    assign stall            = stall_id || stall_exe || stall_pmem || stall_mem;
    assign stall_id         = (id_valid && stall_data_hazard) || idle_lock;
    assign id_to_exe_valid  = id_valid && !stall_id;
`ifdef PERF_STAT_EN
    wire            pht_taken_perf;
    wire [7:0] icache_stall_count_perf;
    wire      icache_is_uncached_perf;
`endif        
    //数据通路
    assign {pc_id, instr_id, ex_pre_id, ecode_pre_id, br_taken_predict_id, btb_hit_id, btb_tag_unmatch_id,predecode_bus_id
`ifdef PERF_STAT_EN
            ,
            icache_stall_count_perf,
            icache_is_uncached_perf,
            pht_taken_perf
`endif
} = if_to_id_reg;                         //从if来
    assign {c_rf_wen_wb,rdata_c_wb,rnum_c_wb} = wb_to_rf_bus;       //从wb来

    
    assign rj = instr_id[9:5];
    assign rk = instr_id[14:10];
    assign rd = instr_id[4:0];
    assign rnum_a = rj;
    assign rnum_b = c_rnum_b_sel ? rd : rk;
    assign rnum_c_id = ({5{c_rnum_c_sel[2]}} & rj)|
                       ({5{c_rnum_c_sel[1]}} & 5'h01)|
                       ({5{c_rnum_c_sel[0]}} & rd);

    assign csr_addr_id = is_sc_w_id ? `READ_LLBIT : instr_id[23:10];

    //例外检测逻辑
    assign ex_id = ex_pre_id | ex_ipe | ex_ine | ex_brk | ex_sys | has_intr;
    //! 由于译码时假定了指令符合定义，所以INE例外可能与其他例外同时报出，此时INE优先
    assign ecode_gen = ex_ine ? `ECODE_INE : (({6{ex_brk}} & `ECODE_BRK)|({6{ex_sys}} & `ECODE_SYS)|({6{ex_ipe}} & `ECODE_IPE));
    assign ecode_id  = has_intr ? `ECODE_INT : (ex_pre_id ? ecode_pre_id : ecode_gen);
    //位扩展器
    extender EXTENDER(.instr_25_0(instr_id[25:0]),
                      .imm32(imm32_id),
                      .c_immsel(c_immsel));
    //寄存器堆
    regfile REGFILE(
                    .clk(clk),
                    .wen(c_rf_wen_wb),
                    .num_a(rnum_a),
                    .num_b(rnum_b),
                    .num_c(rnum_c_wb),
                    .data_a(rdata_a),
                    .data_b(rdata_b),
                    .data_c(rdata_c_wb)
`ifdef DIFFTEST_EN
                    ,
                    .rf_regs_diff(rf_regs_diff)
`endif
                    );
    //指令译码器
    ctrl CTRL(
              .instr(instr_id),
              .predecode_bus(predecode_bus_id),
              .rd_id(rd),
              .plv(plv),
              .csr_addr(csr_addr_id),
              .c_refetch(c_refetch_id),
              .c_npcsel(c_npcsel_id),
              .c_immsel(c_immsel),
              .c_alusrc_a(c_alusrc_a_id),
              .c_alusrc_b(c_alusrc_b_id),
              .c_aluop(c_aluop_id),
              .c_mduop(c_mduop_id),
              .c_brop(c_brop_id),
              .c_memwr(c_memwr_id),
              .c_memrd(c_memrd_id),
              .c_wbsel(c_wbsel_id),
              .c_regwr(c_regwr_id),
              .c_reg_as_read(c_reg_as_read),
              .c_rnum_b_sel(c_rnum_b_sel),
              .c_rnum_c_sel(c_rnum_c_sel),
              .c_csrwr(c_csrwr_id),
              .csr_wmask_id(csr_wmask_id),
              .is_ertn(is_ertn_id),
              .ex_sys(ex_sys),
              .ex_ine(ex_ine),
              .ex_brk(ex_brk),
              .ex_ipe(ex_ipe),
              .c_cntsel(c_cntsel_id),
              .is_tlbrd(is_tlbrd_id),       //是否为tlbrd指令
              .is_tlbwr(is_tlbwr_id),       //是否为tlbwr指令
              .is_tlbfill(is_tlbfill_id),   //是否为tlbfill指令
              .is_tlbsrch(is_tlbsrch_id),   //是否为tlbsrch指令
              .is_invtlb(is_invtlb_id),     //是否为invtlb指令
              .is_idle(is_idle_id),
              .is_ll_w(is_ll_w_id),
              .is_sc_w(is_sc_w_id),
              .is_cacop(is_cacop_id),
              .is_br(is_br_id),
              .is_jirl(is_jirl_id),
              .is_mdu_instr(is_mdu_instr_id)
            );
    /***********************************************/
    // 旁路、阻塞控制单元
    assign {c_fwd_a_sel, c_fwd_b_sel, stall_data_hazard, rdata_c_exe, rdata_c_pmem, rdata_c_mem} = bypass_to_id_bus;
    bypass_unit BYPASS_UNIT(
        .rnum_a_id(rnum_a),
        .rnum_b_id(rnum_b),
        .c_reg_as_read(c_reg_as_read),
        .rj(rj),.rk(rk),.rd(rd),
        .bypass_to_id_bus(bypass_to_id_bus),
        .bypass_from_exe_bus(bypass_from_exe_bus),
        .bypass_from_pmem_bus(bypass_from_pmem_bus),
        .bypass_from_mem_bus(bypass_from_mem_bus)
    );
    /***********************************************/
    //旁路选择器
    assign rdata_a_fwd = ({32{c_fwd_a_sel[0]}} & rdata_a)
                        |({32{c_fwd_a_sel[1]}} & rdata_c_exe)
                        |({32{c_fwd_a_sel[2]}} & rdata_c_pmem)
                        |({32{c_fwd_a_sel[3]}} & rdata_c_mem);
    assign rdata_b_fwd = ({32{c_fwd_b_sel[0]}} & rdata_b)
                        |({32{c_fwd_b_sel[1]}} & rdata_c_exe)
                        |({32{c_fwd_b_sel[2]}} & rdata_c_pmem)
                        |({32{c_fwd_b_sel[3]}} & rdata_c_mem);
    //通往exe级
    assign id_to_exe_bus = {pc_id,imm32_id,rdata_a_fwd,rdata_b_fwd,rnum_c_id,csr_wmask_id,csr_addr_id,  //148
                            is_ertn_id,ex_id,ecode_id,                                                  //8
                            br_taken_predict_id, btb_hit_id, is_br_id,is_jirl_id,btb_tag_unmatch_id,    //5
                            is_tlbrd_id,is_tlbwr_id,is_tlbfill_id,is_tlbsrch_id,is_invtlb_id,           //5
                            is_cacop_id, is_ll_w_id, is_sc_w_id, rd,is_mdu_instr_id,                    //9
                            c_npcsel_id,c_alusrc_a_id,c_alusrc_b_id,c_aluop_id,c_mduop_id,c_brop_id,    //15+width_aluop
                            c_memwr_id, c_memrd_id,c_wbsel_id, c_regwr_id, c_csrwr_id, c_cntsel_id,     //17
                            c_refetch_id    //1
`ifdef DIFFTEST_EN
                            ,instr_id
`endif
`ifdef PERF_STAT_EN
                            ,
                            icache_stall_count_perf,
                            icache_is_uncached_perf,
                            pht_taken_perf
`endif
                        };
    
endmodule
