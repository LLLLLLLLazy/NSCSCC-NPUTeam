`include "header.v"
module exe_stage(
    input                                   clk,
    input                                   rst_n,
    input                                   flush,
    input                                   stall_pmem,
    input                                   stall_mem,
    output                                  stall_exe,
    input                                   id_to_exe_valid,
    input [`WIDTH_ID_TO_EXE_BUS-1:0]        id_to_exe_bus,       //id到exe的数据
    output [`WIDTH_EXE_TO_PMEM_BUS-1:0]     exe_to_pmem_bus,      //exe到mem的数据
    output                                  exe_to_pmem_valid,    //exe stage 是否有一条指令可以进入下一级
    output [`WIDTH_BYPASS_FROM_EXE_BUS-1:0] bypass_from_exe_bus,  //旁路单元需要的exe级数据
    output [`WIDTH_BR_BUS-1:0]              br_bus,
    output                                  flush_br,
    output [`WIDTH_AGU_TO_TLB_BUS-1:0]      agu_to_tlb_bus,
    output [31:0]                           data_sram_vaddr_exe 
);
    //流水线控制
    reg exe_valid;           //exe stage 中是否含有效的指令
    reg [`WIDTH_ID_TO_EXE_BUS-1:0] id_to_exe_reg;
    wire stall;
    assign stall = stall_exe || stall_pmem || stall_mem;
    always @(posedge clk)begin
        id_to_exe_reg <= stall ? id_to_exe_reg : id_to_exe_bus;
    end
    always @(posedge clk)begin
        if(!rst_n || flush)
            exe_valid <= 0;
        else if(!stall)
            exe_valid <= id_to_exe_valid;
    end

    assign exe_to_pmem_valid = exe_valid && !stall_exe;
    //控制
    wire [2:0]  c_npcsel_exe;
    wire [4:0]  c_brop_exe;
    wire        c_refetch_exe;
    //数据
    wire [31:0] pc_exe;
    wire [31:0] imm32_exe;                                          //imm32
    wire [31:0] rdata_a_exe;                                        //寄存器读数据a
    wire [31:0] rdata_b_exe;                                        //寄存器读数据b
    wire        c_regwr_exe;                                        //寄存器写使能
    wire [3:0]  c_wbsel_exe;                                        //最终结果选择
    wire [4:0]  rnum_c_exe;                                         //寄存器写目标
    //MDU
    wire [2:0]  c_mduop_exe;
    wire [31:0] mdu_prod;
    wire        is_mdu_instr_exe;
    //ALU
    wire [31:0] alu_a;                                              //alu输入A实际值
    wire [31:0] alu_b;                                              //alu输入B实际值
    wire [`WIDTH_ALUOP - 1 : 0]  c_aluop_exe;                       //alu功能选择
    wire        c_alusrc_a_exe;                                     //alu输入A选择信号
    wire [2:0]  c_alusrc_b_exe;                                     //alu输入b选择信号
    wire [31:0] alu_out_exe;                                        //alu输出
    wire [2:0]  c_memwr_exe;                                        //存储器写方式
    wire [4:0]  c_memrd_exe;                                        //存储器读方式
    //例外
    wire        is_ertn_exe;    //是否为ertn指令
    wire        ex_pre_exe;     //是否有例外(不考虑valid)
    wire [5:0]  ecode_pre_exe;  //例外编码
    wire        ex_exe;         //是否有例外(不考虑valid)
    wire [5:0]  ecode_exe;      //例外编码
    wire [2:0]  c_cntsel_exe;
    //旁路
    wire [4:0]  rnum_as_write_exe;
    wire        data_not_prepared_exe;                               //当前指令在当前流水级不能计算出结果
    //AGU
    wire        is_ld_st_exe;
    wire        is_load_exe;
    wire        is_store_exe;
    wire        is_cacop2_exe;      //2型cache op指令
    //wire [31:0] data_sram_vaddr_exe;//AGU计算出的data sram vaddr
    
    //TLB
    wire        is_tlbrd_exe;     //是否为tlbrd指令
    wire        is_tlbwr_exe;     //是否为tlbwr指令
    wire        is_tlbfill_exe;   //是否为tlbfill指令
    wire        is_tlbsrch_exe;   //是否为tlbsrch指令
    wire        is_invtlb_exe;    //是否为invtlb指令
    //cache
    wire        is_cacop_exe;
    //原子访存
    wire        is_ll_w_exe;
    wire        is_sc_w_exe;
    //例外生成（ALE例外）
    wire [1:0]  addr_1_0 = alu_a[1:0] + imm32_exe[1:0];             //小加法器速算访存地址末两位
    wire        ex_ale = ((c_memwr_exe[0] | c_memrd_exe[0]) & (addr_1_0 != 2'h0)) 
                       | ((c_memwr_exe[1] | c_memrd_exe[1] | c_memrd_exe[3]) & (addr_1_0[0] != 1'h0));
    assign      ex_exe = ex_pre_exe | ex_ale;
    assign      ecode_exe = ex_pre_exe ? ecode_pre_exe : `ECODE_ALE;

    //branch
    wire        cmp_lt;
    wire        cmp_eq;
    wire        cmp_ltu;
    wire        cmp_basic;
    wire        cmp_final;
    wire        br_taken;                           //表示是否要进行分支操作（最终）
    wire [31:0] br_addr;                            //表示分支的目标地址
    //wire        miss_predict;                       //表示是否误预测（只能提供给pif级npc的选择）
    //分支预测
    wire        br_taken_predict_exe;
    wire        btb_hit_exe;
    wire        is_br_exe;
    wire        is_jirl_exe;
    wire        allow_update;                        //指令允许执行（允许更新处理器状态）
    wire        btb_tag_unmatch_exe;                //pif级判断btb命中,但是tag高位比较失败,实际不命中
    //CSR write mask
    wire        csr_wmask_raw_exe;                  //来自id级未处理的csr wmask
    wire [31:0] csr_wmask_exe;
    wire [13:0] csr_addr_exe;
    wire        c_csrwr_exe;

    wire [4:0]  rd_exe;
`ifdef DIFFTEST_EN
    wire [31:0] instr_diff;
`endif
`ifdef PERF_STAT_EN
    wire      pht_taken_perf;
    wire [7:0] icache_stall_count_perf;
    wire      icache_is_uncached_perf;
    wire      br_taken_pred_perf;
    wire      br_correct_perf;
    wire      br_tag_hi_unmatch_perf;
    wire      is_br_perf;
    wire      is_jirl_perf;
    assign    br_taken_pred_perf = br_taken_predict_exe;
    assign    br_correct_perf = !((br_taken_predict_exe ^ br_taken) || (br_taken_predict_exe && btb_tag_unmatch_exe));
    assign    br_tag_hi_unmatch_perf = br_taken_predict_exe && btb_tag_unmatch_exe;
    assign    is_br_perf = is_br_exe;
    assign    is_jirl_perf = is_jirl_exe;
`endif    
    //数据通路
    assign {pc_exe, imm32_exe, rdata_a_exe, rdata_b_exe, rnum_c_exe, csr_wmask_raw_exe, csr_addr_exe,
            is_ertn_exe,ex_pre_exe,ecode_pre_exe, 
            br_taken_predict_exe, btb_hit_exe, is_br_exe, is_jirl_exe, btb_tag_unmatch_exe,
            is_tlbrd_exe,is_tlbwr_exe,is_tlbfill_exe,is_tlbsrch_exe,is_invtlb_exe, 
            is_cacop_exe, is_ll_w_exe, is_sc_w_exe, rd_exe, is_mdu_instr_exe,
            c_npcsel_exe,c_alusrc_a_exe,c_alusrc_b_exe,c_aluop_exe,c_mduop_exe,c_brop_exe,
            c_memwr_exe, c_memrd_exe, c_wbsel_exe, c_regwr_exe, c_csrwr_exe, c_cntsel_exe,
            c_refetch_exe
`ifdef DIFFTEST_EN
            ,instr_diff
`endif 
`ifdef PERF_STAT_EN
            ,
            icache_stall_count_perf,
            icache_is_uncached_perf,
            pht_taken_perf
`endif
        } = id_to_exe_reg;     //从id来

    //csr wmask gen
    assign csr_wmask_exe = {32{csr_wmask_raw_exe}} | rdata_a_exe;
    //旁路
    //assign rnum_as_write_exe = {5{!flush & exe_valid & c_regwr_exe}} & rnum_c_exe;
    assign rnum_as_write_exe = {5{exe_valid & c_regwr_exe}} & rnum_c_exe;//不需要考虑flush，因为exe flush了id必然flush，此时旁路和id级阻塞的结果都没有意义。
    assign data_not_prepared_exe = c_wbsel_exe[3] | c_wbsel_exe[2] | c_wbsel_exe[1];              //当前指令在exe级不能计算出结果
    //分支计算单元 BRU
    assign cmp_lt = $signed(rdata_a_exe) < $signed(rdata_b_exe);
    assign cmp_eq  = rdata_a_exe == rdata_b_exe;
    assign cmp_ltu = $unsigned(rdata_a_exe) < $unsigned(rdata_b_exe);
    assign cmp_basic = (c_brop_exe[0] & cmp_eq)
                      |(c_brop_exe[1] & cmp_lt)
                      |(c_brop_exe[2] & cmp_ltu)
                      | c_brop_exe[4];
    assign cmp_final = c_brop_exe[3] ^ cmp_basic;
    assign br_taken = cmp_final & (~c_npcsel_exe[0]);
    assign br_addr = (({32{c_npcsel_exe[1]}} & pc_exe) | ({32{c_npcsel_exe[2]}} & rdata_a_exe))  + imm32_exe;
    
    //ALU A来源选择
    assign alu_a = c_alusrc_a_exe ? pc_exe : rdata_a_exe;
    assign alu_b =  ({32{c_alusrc_b_exe[2]}} & 32'h4) 
                   |({32{c_alusrc_b_exe[1]}} & imm32_exe)
                   |({32{c_alusrc_b_exe[0]}} & rdata_b_exe);


    assign allow_update = exe_valid && !stall && !ex_exe;
    //乘除法单元 MDU
    mdu MDU(.clk(clk),
            .rst_n(rst_n),
            .flush(flush),
            .exe_valid(exe_valid & ~ex_pre_exe),
            .a(alu_a),
            .b(alu_b),
            .mdu_prod(mdu_prod),
            .is_mdu_instr(is_mdu_instr_exe),
            .mduop(c_mduop_exe),
            .stall(stall_exe));
    //地址计算单元 AGU
    assign is_ld_st_exe =     (|{c_memrd_exe,c_memwr_exe});
    assign is_load_exe  =     (|{c_memrd_exe});
    assign is_store_exe =     (|{c_memwr_exe});
    assign is_cacop2_exe =    is_cacop_exe && rd_exe[4] && !rd_exe[3];
    assign data_sram_vaddr_exe = rdata_a_exe + imm32_exe;
    assign agu_to_tlb_bus =   {data_sram_vaddr_exe, is_ld_st_exe, is_cacop2_exe, is_store_exe,is_tlbsrch_exe};
    //算术逻辑单元 ALU
    alu ALU(.a(alu_a),
            .b(alu_b),
            .c(alu_out_exe),
            .mdu_prod(mdu_prod),
            .aluop(c_aluop_exe));

    assign flush_br = allow_update && ((br_taken_predict_exe ^ br_taken) || (br_taken_predict_exe && btb_tag_unmatch_exe)); //分支预测出错
    
    //通往pmem级
    assign exe_to_pmem_bus = {pc_exe, rdata_b_exe, alu_out_exe, rnum_c_exe, csr_wmask_exe, csr_addr_exe, //147
                              is_ertn_exe, ex_exe, ecode_exe,                                            //8
                              is_tlbrd_exe, is_tlbwr_exe, is_tlbfill_exe, is_tlbsrch_exe, is_invtlb_exe, //5
                              is_cacop_exe, is_ll_w_exe, is_sc_w_exe, rd_exe,                            //8
                              is_ld_st_exe,is_load_exe,is_store_exe,is_cacop2_exe,                       //4
                              c_memwr_exe,c_memrd_exe,c_wbsel_exe,c_regwr_exe, c_csrwr_exe, c_cntsel_exe,
                              c_refetch_exe
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
                            };
    //通往pif级
    assign br_bus = {allow_update, pc_exe, is_br_exe,is_jirl_exe, btb_hit_exe, br_addr, br_taken, br_taken_predict_exe, btb_tag_unmatch_exe};
    
    //通往旁路单元
    assign bypass_from_exe_bus={rnum_as_write_exe, data_not_prepared_exe, alu_out_exe};
endmodule
