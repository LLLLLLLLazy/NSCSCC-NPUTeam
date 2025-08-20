`include "header.v"
module pmem_stage(
    input                                   clk,
    input                                   rst_n,
    input   [7:0]                           hwi,
    input                                   flush,
    input                                   flush_pif,
    input                                   stall_if_to_wb,
    input                                   stall_mem,
    output                                  stall_pmem,
    input                                   exe_to_pmem_valid,
    input [`WIDTH_EXE_TO_PMEM_BUS-1:0]      exe_to_pmem_bus,       //exe到pmem的数据
    input [`WIDTH_AGU_TO_TLB_BUS-1:0]       agu_to_tlb_bus,
    output                                  data_sram_req,
    output                                  data_sram_wr,
    output  [1:0]                           data_sram_mat,
    output  [1:0]                           data_sram_size,
    output  [3:0]                           data_sram_wstrb,
    output  [31:0]                          data_sram_addr,
    output  [31:0]                          data_sram_wdata,
    output  [31:0]                          data_sram_vaddr,
    output                                  flush_ex,               //例外导致的flush              
    output                                  flush_refetch,          //重新取指导致的flush
    output [`WIDTH_REFETCH_BUS-1:0]         refetch_bus,
    output                                  has_intr,
    output [`WIDTH_EX_JUMP_BUS-1:0]         ex_jump_bus,

    output [`WIDTH_PMEM_TO_MEM_BUS-1:0]     pmem_to_mem_bus,        //pmem到mem的数据
    output                                  pmem_to_mem_valid,      //pmem stage 是否有一条指令可以进入下一级
    output [`WIDTH_BYPASS_FROM_PMEM_BUS-1:0] bypass_from_pmem_bus,  //旁路单元需要的pmem级数据
    input  [31:0]                           inst_sram_vaddr,
    output [31:0]                           inst_sram_paddr,
    output  [1:0]                           inst_sram_mat,
    output                                  itlb_stall,
    output                                  ex_pif,
    output [5:0]                            ecode_pif,
    output [1:0]                            plv,                     //特权级
    //zzy
    output                                  dcacop_en,
    output  [4:0]                           cacop_op,
    output                                  pmem_wen  
`ifdef DIFFTEST_EN
    ,
    output [`WIDTH_CSR_DIFF-1:0]            csr_all_diff
`endif
);

    //数据
    //pc
    wire [31:0] pc_pmem;                         //pc
    //寄存器堆
    wire [4:0]  rnum_c_pmem;                     //寄存器写索引
    wire [31:0] rdata_b_pmem;                    //寄存器读数据b
    wire        c_regwr_pmem;                    //寄存器写使能
    wire [3:0]  c_wbsel_pmem;

    //ALU
    wire [31:0] alu_out_pmem;                     //alu输出
    //DMEM
    wire [4:0]  c_memrd_pmem;
    wire [2:0]  c_memwr_pmem;
    wire [3:0]  dm_wen_byte;
    wire [3:0]  dm_wen_half;
    wire [3:0]  dm_wen_word;
    wire [31:0] dm_wdata_byte;
    wire [31:0] dm_wdata_half;
    wire [31:0] dm_wdata_word;
    wire        is_ld_st_pmem;
    wire        is_load_pmem;
    wire        is_store_pmem;
    wire        is_ld_st_except_disabled_sc_pmem;
    //wire        is_store_except_disabled_sc_pmem;

    wire        is_ll_w_pmem;
    wire        is_sc_w_pmem;       //! unused
    wire        llbit_pmem;
    //wire        dm_req_sent_pmem;      //指令在pmem级实际请求了data ram（传给mem级用于接收data_ok)
    //旁路
    wire [4:0]  rnum_as_write_pmem;                   //该指令实际对哪个寄存器进行写操作(指令无效或者不写寄存器则为0)
    wire        data_not_prepared_pmem;                //本周期旁路不能从本级获得结果
    //CSR write mask
    wire [31:0] csr_wmask_pmem;
    wire [13:0] csr_addr_pmem;
    wire        c_csrwr_pmem;
    wire [31:0] csr_rdata_pmem;
    
    //CSR output
    wire [`WIDTH_CSR_TO_TLB_BUS-1:0] csr_to_tlb_bus;
    wire [`WIDTH_TLB_TO_CSR_BUS-1:0] tlb_to_csr_bus;
    
    //例外
    wire        is_ertn_pmem;    //是否为ertn指令
    wire        ex_pre_pmem;     //(来自exe)是否有例外(不考虑valid)
    wire [5:0]  ecode_pre_pmem;  //(来自exe)例外编码
    wire        ex_pmem;         //是否有例外(不考虑valid)
    wire [5:0]  ecode_pmem;      //例外编码
    wire        ex_jump;
    wire [31:0] ex_npc;          
    wire [31:0] badv_pmem;       //出错虚地址
    //wire        esubcode_pmem;   //例外次级编码
    wire        ex_dmemvis_pmem; //触发访问dmem的例外（不考虑valid)
    //计时器
    wire [31:0] counter_rdata_pmem;
    wire [2:0]  c_cntsel_pmem;
    
    //MMU
    wire        is_tlbwr_pmem;
    wire        is_tlbrd_pmem;
    wire        is_tlbsrch_pmem;
    wire        is_tlbfill_pmem;
    wire        is_invtlb_pmem;
    wire        is_cacop_pmem;
    wire [4:0]  rd_pmem;                //for invtlb op
    wire        allow_exec;             //对处理器状态进行修改的指令是否允许执行（valid, 不报例外, 并且本拍能够流走才能执行
    wire        allow_exec_no_pex;      //同上，只是只考虑pmem级前的例外,时序会更好
    wire        is_cacop2_pmem;
    //* DIFFTEST
`ifdef DIFFTEST_EN
    wire [31:0] instr_diff;
    wire [31:0] memvis_data_diff;
    wire        cnt_instr_diff;
    wire [63:0] stable_counter_diff;
    wire        csr_rstat_en_diff;
    wire [`WIDTH_TLB_INDEX - 1:0]  tlbfill_index_diff;
`endif
`ifdef PERF_STAT_EN
    wire      pht_taken_perf;
    wire [7:0] icache_stall_count_perf;
    wire      icache_is_uncached_perf;
    wire      dcache_is_uncached_perf;
    wire      dcache_req_perf;
    wire      br_taken_pred_perf;
    wire      br_correct_perf;
    wire      br_tag_hi_unmatch_perf;
    wire      is_br_perf;
    wire      is_jirl_perf;
`endif   
    //流水线控制
    reg pmem_valid;           //pmem stage 中是否含有效的指令
    reg [`WIDTH_EXE_TO_PMEM_BUS-1:0] exe_to_pmem_reg;
    wire stall;

    assign stall = stall_pmem || stall_mem;
    assign pmem_wen = ~stall;
    wire pmem_readygo;        //pmem stage 是否允许离开
    wire c_refetch_pmem;
    always @(posedge clk)begin
        exe_to_pmem_reg <= stall ? exe_to_pmem_reg : exe_to_pmem_bus;
    end
    always @(posedge clk)begin
        if(!rst_n || flush)
            pmem_valid <= 0;
        else if(!stall)
            pmem_valid <= exe_to_pmem_valid;
    end
    //! 好像pmem级自身没有能阻止指令前进的要素
    //zzy:icacop_op_en
    assign cacop_op         = rd_pmem;
    wire icacop_en        = is_cacop_pmem && (cacop_op[2:0] == 3'b0) && allow_exec;
    assign dcacop_en        = is_cacop_pmem && (cacop_op[2:0] == 3'b1);
    wire [1:0] icacop_code_4_3 = cacop_op[4:3];
/*
`ifdef DIFFTEST_EN
    assign pmem_readygo = data_sram_addr_ok || !is_ld_st_pmem || is_sc_w_pmem && !llbit_pmem || ex_pmem;
`else
    assign pmem_readygo = data_sram_addr_ok || !is_ld_st_pmem || is_sc_w_pmem && !llbit_pmem;
`endif*/  
    assign pmem_to_mem_valid = pmem_valid && !stall_pmem;
    //允许执行信号，本级不报例外且下一级允许进入才能执行，防止指令乱序修改处理器状态
    assign allow_exec = pmem_valid && !stall && !ex_pmem;
    //允许执行信号，但是不考虑pmem级才产生的新例外，可以优化时序
    assign allow_exec_no_pex = pmem_valid && !stall && !ex_pre_pmem;
    //数据通路
    assign {pc_pmem, rdata_b_pmem,alu_out_pmem, rnum_c_pmem,csr_wmask_pmem,csr_addr_pmem,
            is_ertn_pmem,ex_pre_pmem,ecode_pre_pmem,
            is_tlbrd_pmem,is_tlbwr_pmem,is_tlbfill_pmem,is_tlbsrch_pmem,is_invtlb_pmem, is_cacop_pmem,
            is_ll_w_pmem, is_sc_w_pmem, rd_pmem,
            is_ld_st_pmem,is_load_pmem,is_store_pmem,is_cacop2_pmem, 
            c_memwr_pmem,c_memrd_pmem,c_wbsel_pmem,c_regwr_pmem, c_csrwr_pmem, c_cntsel_pmem,
            c_refetch_pmem
`ifdef DIFFTEST_EN
            ,instr_diff
`endif
`ifdef PERF_STAT_EN
            ,
            icache_stall_count_perf,
            icache_is_uncached_perf,
            br_taken_pred_perf,
            br_correct_perf,
            br_tag_hi_unmatch_perf,
            is_br_perf,
            is_jirl_perf,
            pht_taken_perf
`endif   
        } = exe_to_pmem_reg; //从exe来

    //memory visit instrucion type

    assign is_ld_st_except_disabled_sc_pmem =     is_ld_st_pmem && !(is_sc_w_pmem && !llbit_pmem);
    //assign is_store_except_disabled_sc_pmem =     is_store_pmem && !(is_sc_w_pmem && !llbit_pmem);
    //bypass
    assign rnum_as_write_pmem = {5{pmem_valid & c_regwr_pmem}} & rnum_c_pmem;
    assign data_not_prepared_pmem = c_wbsel_pmem[3];     //若读memory才能计算出结果，则本级无法获得该结果
    

    // //CACOP
    // assign cacop_code_pmem = rd_pmem;
    // assign cacop_valid_pmem = is_cacop_pmem && allow_exec;
    
    //DMEM wen和wdata生成
    decoder#(2) DCACHE_WEN_BYTE_DECODER (.in(alu_out_pmem[1:0]),.out(dm_wen_byte));
    assign dm_wen_half = alu_out_pmem[1]?4'b1100:4'b0011;
    assign dm_wen_word = 4'b1111;
    assign dm_wdata_byte = {4{rdata_b_pmem[7:0]}};
    assign dm_wdata_half = {2{rdata_b_pmem[15:0]}};
    assign dm_wdata_word = rdata_b_pmem;

    //DMEM
    //非自然对齐导致的adem例外
    assign data_sram_size  = {c_memwr_pmem[0] | c_memrd_pmem[0], c_memrd_pmem[3] | c_memrd_pmem[1] | c_memwr_pmem[1]};
    assign data_sram_wr    = is_store_pmem;
    assign data_sram_wstrb =  ({4{c_memwr_pmem[2]}} & dm_wen_byte) 
                            |({4{c_memwr_pmem[1]}} & dm_wen_half)
                            |({4{c_memwr_pmem[0]}} & dm_wen_word);
    assign data_sram_wdata = ({32{c_memwr_pmem[2]}} & dm_wdata_byte) 
                            |({32{c_memwr_pmem[1]}} & dm_wdata_half)
                            |({32{c_memwr_pmem[0]}} & dm_wdata_word);
    assign data_sram_req =  (is_cacop_pmem || is_ld_st_pmem)  && !(is_sc_w_pmem && !llbit_pmem) && allow_exec;
    //assign dm_req_sent_pmem = is_cacop_pmem || is_ld_st_except_disabled_sc_pmem;
    assign data_sram_vaddr = alu_out_pmem;
`ifdef DIFFTEST_EN
    assign csr_rstat_en_diff = c_wbsel_pmem[1] && csr_addr_pmem == `CSR_ESTAT;
    assign cnt_instr_diff = |c_cntsel_pmem;
    //写存储器访问数据
    assign memvis_data_diff = {{8{data_sram_wstrb[3]}},{8{data_sram_wstrb[2]}},{8{data_sram_wstrb[1]}},{8{data_sram_wstrb[0]}}} & data_sram_wdata;
`endif
`ifdef PERF_STAT_EN
    assign dcache_is_uncached_perf = ~data_sram_mat[0];
    assign dcache_req_perf = (is_cacop_pmem || is_ld_st_pmem)  && !(is_sc_w_pmem && !llbit_pmem);
`endif 
    //控制状态寄存器
    control_status_registers CSR(
        .clk                (clk),
        .rst_n              (rst_n),
        .pc                 (pc_pmem),
        .ex                 (ex_pmem && pmem_valid && !stall),          //例外实际报出
        .ecode              (ecode_pmem),                                    //例外类型 一级编码
        .esubcode           (0),                                             //例外类型 二级编码
        .is_ertn            (is_ertn_pmem && allow_exec_no_pex),             //是否为ertn指令
        .csr_addr           (csr_addr_pmem),
        .badv               (badv_pmem),
        .c_csrwr            (c_csrwr_pmem && allow_exec_no_pex),             //CSR寄存器写使能
        .csr_wdata          (rdata_b_pmem),
        .csr_wmask          (csr_wmask_pmem),                                //写掩码
        .hwi                (hwi),                                           //硬件中断采样输入
        .ipi                (1'h0),                                          //核间中断
        .c_cntsel           (c_cntsel_pmem),
        .csr_rdata          (csr_rdata_pmem),
        .ex_npc             (ex_npc),
        .has_intr           (has_intr),                                      //报出了一个例外
        .counter_rdata      (counter_rdata_pmem),
        .llbit              (llbit_pmem),                                    //llbit当前的值
        .plv                (plv),                                           //当前特权级
        .is_ll_w            (is_ll_w_pmem    && allow_exec),                 //是否为ll_w指令   (控制写llbctl寄存器)(ll_w指令可能报pmem级例外)
        .sc_clean_llbit     (is_sc_w_pmem && allow_exec),                    //是否为sc_w指令   (控制写llbctl寄存器)(sc_w指令可能报pmem级例外) //zzy
        .is_tlbsrch         (is_tlbsrch_pmem && allow_exec_no_pex),          //是否为tlbsrch指令(控制写TLB相关的CSR寄存器)
        .is_tlbrd           (is_tlbrd_pmem   && allow_exec_no_pex),          //是否为tlbrd指令  (控制写TLB相关的CSR寄存器)        
        .tlb_to_csr_bus     (tlb_to_csr_bus),
        .csr_to_tlb_bus     (csr_to_tlb_bus)
`ifdef DIFFTEST_EN
        ,
        .csr_all_diff       (csr_all_diff),
        .stable_counter_diff(stable_counter_diff)
`endif
    );
    //MMU
    mmu MMU(
        .clk(clk),
        .rst_n(rst_n),
        .flush_pif          (flush_pif),
        .stall_if_to_wb     (stall_if_to_wb),
        .stall_mem_to_wb    (stall_mem),
        .pmem_valid         (pmem_valid),
        .dtlb_stall         (stall_pmem),
        .ex_pif_to_exe      (ex_pre_pmem),
        .inst_sram_vaddr    (inst_sram_vaddr),
        .inst_sram_paddr    (inst_sram_paddr),
        .inst_sram_mat      (inst_sram_mat),
        .data_sram_vaddr    (alu_out_pmem),
        .data_sram_paddr    (data_sram_addr),
        .data_sram_mat      (data_sram_mat),
        .is_load_pmem       (is_load_pmem),                                     //当前指令是读dcache的指令(包含ll.w,不包含cacop2)
        .is_store_pmem      (is_store_pmem),                                    //当前指令是写dcache的指令
        .is_ld_st_pmem      (is_ld_st_pmem),
        .is_cacop2_pmem     (is_cacop2_pmem),
        //.is_tlbrd(is_tlbrd_pmem & pmem_valid), 
        .is_tlbwr           (is_tlbwr_pmem    && allow_exec_no_pex),      
        .is_tlbsrch_pmem    (is_tlbsrch_pmem),
        .is_tlbfill         (is_tlbfill_pmem  && allow_exec_no_pex),
        .is_invtlb          (is_invtlb_pmem   && allow_exec_no_pex),
        .invtlb_op          (rd_pmem),
        .invtlb_asid        (alu_out_pmem[9:0]),
        .invtlb_vppn        (rdata_b_pmem[31:13]),
        .csr_to_tlb_bus     (csr_to_tlb_bus),
        .tlb_to_csr_bus     (tlb_to_csr_bus),
        .ex_pre_pmem        (ex_pre_pmem),
        .ecode_pre_pmem     (ecode_pre_pmem),
        .ex_pmem            (ex_pmem),
        .ecode_pmem         (ecode_pmem),
        .itlb_stall         (itlb_stall),
        //.esubcode_pmem      (esubcode_pmem),
        .ex_pif             (ex_pif),
        .ecode_pif          (ecode_pif),
        .ex_dmemvis_pmem    (ex_dmemvis_pmem),
        .agu_to_tlb_bus     (agu_to_tlb_bus)
`ifdef DIFFTEST_EN
        ,
        .tlbfill_index_diff(tlbfill_index_diff)
`endif
    );
    //例外
    assign badv_pmem        = (ex_dmemvis_pmem || ecode_pre_pmem == `ECODE_ALE) ? alu_out_pmem : pc_pmem;
    assign flush_ex         = ex_jump;
    assign flush_refetch    = c_refetch_pmem && pmem_valid && !stall;
    //结果选择
    wire [31:0] rdata_c_pmem = ({32{c_wbsel_pmem[0]}} & alu_out_pmem)
                              |({32{c_wbsel_pmem[1]}} & csr_rdata_pmem)
                              |({32{c_wbsel_pmem[2]}} & counter_rdata_pmem);
   
    //通往pif
    wire [31:0] refetch_addr = pc_pmem + 4;
    wire [31:0] icacop_pc = pc_pmem;
    assign ex_jump     = (ex_pmem || is_ertn_pmem) && pmem_valid && !(stall_pmem || stall_mem);
    assign ex_jump_bus = {ex_jump, ex_npc};
    assign refetch_bus = {flush_refetch, refetch_addr, icacop_en, icacop_code_4_3 , icacop_pc, alu_out_pmem[11:4], data_sram_addr};
    //通往mem级
    assign pmem_to_mem_bus = {pc_pmem,alu_out_pmem, rnum_c_pmem,rdata_c_pmem,
                              c_memrd_pmem, c_wbsel_pmem[3], c_regwr_pmem,
                              ex_pmem
`ifdef DIFFTEST_EN
                              //32+1+1+32+32+32
                              ,instr_diff ,is_load_pmem, (is_store_pmem && !(is_sc_w_pmem && !llbit_pmem)), data_sram_addr, alu_out_pmem, memvis_data_diff
                              //1+64+1
                              ,cnt_instr_diff, stable_counter_diff, csr_rstat_en_diff
                              //1+6
                              ,is_ertn_pmem, ecode_pmem
                              //1+4
                              ,is_tlbfill_pmem, tlbfill_index_diff
`endif
`ifdef PERF_STAT_EN
                              ,
                              icache_stall_count_perf,
                              icache_is_uncached_perf,
                              dcache_is_uncached_perf,
                              dcache_req_perf,
                              br_taken_pred_perf,
                              br_correct_perf,
                              br_tag_hi_unmatch_perf,
                              is_br_perf,
                              is_jirl_perf,
                              pht_taken_perf
`endif 
                            };
    //通往旁路单元
    assign bypass_from_pmem_bus={rnum_as_write_pmem, data_not_prepared_pmem, rdata_c_pmem};
endmodule
