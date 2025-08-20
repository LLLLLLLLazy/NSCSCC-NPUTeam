`include "header.v"
module mem_stage(
    input                                   clk,
    input                                   rst_n,
    output                                  stall_mem,
    input                                   dcache_stall,
    input [31:0]                            data_sram_rdata,
    input                                   pmem_to_mem_valid,
    input [`WIDTH_PMEM_TO_MEM_BUS-1:0]      pmem_to_mem_bus,       //pmem到mem的数据
    output [`WIDTH_WB_TO_RF_BUS-1:0]        wb_to_rf_bus,
    output [`WIDTH_BYPASS_FROM_MEM_BUS-1:0] bypass_from_mem_bus,   //旁路单元需要的mem级数据
    output [31:0]                           debug_wb_pc,
    output [3 :0]                           debug_wb_rf_wen,
    output [ 4:0]                           debug_wb_rf_wnum,
    output [31:0]                           debug_wb_rf_wdata
    
`ifdef DIFFTEST_EN
    ,
    output                                  mem_valid_diff,
    output [31:0]                           instr_diff,
    output                                  real_load_diff,
    output                                  real_store_diff,
    output [31:0]                           memvis_paddr_diff,
    output [31:0]                           memvis_vaddr_diff,
    output [31:0]                           memvis_data_diff,
    output                                  cnt_instr_diff,
    output [63:0]                           stable_counter_diff,
    output                                  csr_rstat_en_diff,
    output                                  ex_diff,
    output                                  is_ertn_diff,
    output [5:0]                            ecode_diff,
    output                                  is_tlbfill_diff,
    output [`WIDTH_TLB_INDEX - 1:0]         tlbfill_index_diff
`endif 
);
    
    //例外
    wire        ex_mem;
    //数据
    //pc
    //(*mark_debug = "true"*)
    wire [31:0] pc_mem;                          //pc 
    //寄存器堆
    wire [4:0]  rnum_c_mem;                     //寄存器写索引
    wire [4:0]  c_memrd_mem;
    wire        c_regwr_mem;                    //寄存器写使能
    wire        c_wbsel_mem;                    //寄存器写来源选择
    //ALU
    wire [31:0] alu_out_mem;                     //alu输出
    //DMEM
    wire [31:0] dm_out_mem;                       //存储器输出
    reg  [7:0]  dm_rdata_byte;
    reg  [15:0] dm_rdata_half;
    wire [31:0] rdata_c_mem;
    wire [31:0] rdata_c_pre_mem;
    //写回
    wire        c_rf_wen_mem;                    //寄存器写使能(考虑valid后)
    //旁路
    wire [4:0]  rnum_as_write_mem;              //该指令实际对哪个寄存器进行写操作(指令无效或者不写寄存器则为0)
    //流水线控制
    //(*mark_debug = "true"*) 
    reg mem_valid;           //mem stage 中是否含有效的指令
    reg [`WIDTH_PMEM_TO_MEM_BUS-1:0] pmem_to_mem_reg;
`ifdef PERF_STAT_EN
    wire [7:0] icache_stall_count_perf;
    wire      icache_is_uncached_perf;
    reg  [7:0] dcache_stall_count_perf;
    wire      dcache_is_uncached_perf;
    wire      dcache_req_perf;
    wire      br_taken_pred_perf;
    wire      br_correct_perf;
    wire      br_tag_hi_unmatch_perf;
    wire      is_br_perf;
    wire      is_jirl_perf;
    wire      pht_taken_perf;
    always @(posedge clk)begin
        if(!rst_n )
            dcache_stall_count_perf <= 0;
        else if(dcache_stall)
            dcache_stall_count_perf <= dcache_stall_count_perf + 1;
        else dcache_stall_count_perf <= 0;
    end
`endif     
    //* DIFFTEST
`ifdef DIFFTEST_EN
    assign      mem_valid_diff  = mem_valid && !stall_mem;
    assign      ex_diff         = ex_mem;
`endif 

    always @(posedge clk)begin
        pmem_to_mem_reg <= stall_mem ? pmem_to_mem_reg : pmem_to_mem_bus;
    end
    always @(posedge clk)begin
        if(!rst_n)
            mem_valid <= 0;
        else if(!stall_mem)
            mem_valid <= pmem_to_mem_valid;
    end
    //assign stall_mem = mem_valid && !(data_sram_data_ok || !dm_req_sent_mem || ex_mem);
    assign stall_mem = dcache_stall;
    //数据通路
    assign {pc_mem, alu_out_mem,rnum_c_mem,rdata_c_pre_mem,
            c_memrd_mem, c_wbsel_mem,c_regwr_mem,
            ex_mem
`ifdef DIFFTEST_EN
            ,instr_diff ,real_load_diff, real_store_diff, memvis_paddr_diff, memvis_vaddr_diff, memvis_data_diff
            ,cnt_instr_diff, stable_counter_diff, csr_rstat_en_diff
            ,is_ertn_diff, ecode_diff
            ,is_tlbfill_diff, tlbfill_index_diff
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
        } = pmem_to_mem_reg; //从pmem来
    assign rnum_as_write_mem = {5{mem_valid & c_regwr_mem}} & rnum_c_mem;
    //读出数据生成
    always @(*)begin
        case (alu_out_mem[1:0])
        2'b00:dm_rdata_byte = data_sram_rdata[7:0];
        2'b01:dm_rdata_byte = data_sram_rdata[15:8];
        2'b10:dm_rdata_byte = data_sram_rdata[23:16];
        2'b11:dm_rdata_byte = data_sram_rdata[31:24];
        endcase
    end
    always @(*)begin
        case (alu_out_mem[1])
        1'b0:dm_rdata_half = data_sram_rdata[15:0];
        1'b1:dm_rdata_half = data_sram_rdata[31:16];
        endcase
    end
    //读出数据对齐和扩展
    assign dm_out_mem = ({32{c_memrd_mem[0]}} & data_sram_rdata)
                       |({32{c_memrd_mem[1]}} & {{16{dm_rdata_half[15]}},dm_rdata_half})
                       |({32{c_memrd_mem[2]}} & {{24{dm_rdata_byte[7]}},dm_rdata_byte})
                       |({32{c_memrd_mem[3]}} & {16'b0,dm_rdata_half})
                       |({32{c_memrd_mem[4]}} & {24'b0,dm_rdata_byte});
    //写回
    //最终结果选择
    assign rdata_c_mem = c_wbsel_mem ? dm_out_mem : rdata_c_pre_mem;
    assign c_rf_wen_mem = mem_valid && !stall_mem && !ex_mem && c_regwr_mem;
    //debug
    assign debug_wb_pc = pc_mem;
    assign debug_wb_rf_wen = {4{c_rf_wen_mem}};
    assign debug_wb_rf_wnum = rnum_c_mem;
    assign debug_wb_rf_wdata = rdata_c_mem;
    
    //通往寄存器堆
    assign wb_to_rf_bus = {c_rf_wen_mem,rdata_c_mem,rnum_c_mem};
    //通往旁路单元
    assign bypass_from_mem_bus={rnum_as_write_mem, 1'b0, rdata_c_mem};
    
`ifdef PERF_STAT_EN
    //性能计数器
    perf_stat  u_perf_stat (
        .clk                      ( clk                       ),
        .rst_n                    ( rst_n                     ),
        .valid_instr              ( mem_valid && !stall_mem && !ex_mem      ),
        .ex                       ( mem_valid && !stall_mem && ex_mem       ),
        .bubble                   ( !mem_valid || stall_mem  ),
        .icache_stall_count_perf  ( icache_stall_count_perf   ),
        .icache_is_uncached_perf  ( icache_is_uncached_perf   ),
        .dcache_stall_count_perf  ( dcache_stall_count_perf   ),
        .dcache_is_uncached_perf  ( dcache_is_uncached_perf   ),
        .dcache_req_perf          ( dcache_req_perf           ),
        .br_taken_pred_perf       ( br_taken_pred_perf        ),
        .br_correct_perf          ( br_correct_perf           ),
        .br_tag_hi_unmatch_perf   ( br_tag_hi_unmatch_perf    ),
        .is_br_perf               ( is_br_perf                ),
        .is_jirl_perf             ( is_jirl_perf              ),
        .pht_taken_perf           ( pht_taken_perf            )
    );
`endif
endmodule
