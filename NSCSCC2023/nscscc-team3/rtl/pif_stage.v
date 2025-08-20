`include "header.v"
module pif_stage(
    input                               clk,
    input                               rst_n,
    //流水线控制
    input                               flush,               //流水级寄存器清除  
    input                               stall_if,            //其他流水级来的阻塞信号
    input                               stall_id,
    input                               stall_exe,
    input                               stall_pmem,
    input                               stall_mem,
    output [`WIDTH_PIF_TO_IF_BUS-1:0]   pif_to_if_bus,       //pif到if的数据
    output                              pif_to_if_valid,     //pif stage 是否有一条指令可以进入下一级
    output                              pif_wen,             //pif流水级寄存器是否可写
    input                               btb_clean,           //清除btb
    input [`WIDTH_BR_BUS-1:0]           br_bus,
    input [`WIDTH_EX_JUMP_BUS-1:0]      ex_jump_bus,
    input [`WIDTH_REFETCH_BUS-1:0]      refetch_bus,
`ifdef PERF_STAT_EN
    input                               icache_is_uncached,
`endif
    //IMEM interface
    output                              inst_sram_req,
    output                              inst_sram_wr,
    output [1:0]                        inst_sram_size,
    output [3:0]                        inst_sram_wstrb,
    output [31:0]                       inst_sram_addr,
    output [31:0]                       inst_sram_wdata,
    output [31:0]                       inst_sram_vaddr,
    input  [31:0]                       inst_sram_paddr,
    input                               ex_pif,
    input  [5:0]                        ecode_pif,
    input                               itlb_stall,
    //zzy
    output reg [7:0]                    icache_index,       //来自pif的前一级
    output [1:0]                        icacop_code_4_3_pif,
    output                              icache_is_cacop_pif
);  
    wire [31:0] pc_pif;
    reg  [31:0] npc;
    
    wire        ex_jump;
    wire [31:0] ex_npc;
    wire        refetch;
    wire [31:0] refetch_addr;
    //分支预测
    wire [31:0]     pc_exe;
    wire [31:0]     pc_predict;
    wire            br_taken_predict_pif;       //pif级branch taken预测结果
    wire            btb_hit_pif;                //使用pc寻址btb，结果为命中(不考虑是否为分支指令)
    wire            miss_predict;               //先前预测出错
    wire            addr_incorrect_exe;
    wire [31:0]     pc_correct;
    wire [31:0]     br_tar_exe;
    wire            br_taken_exe;
    wire            br_taken_predict_exe;
    wire            is_br_exe;
    wire            is_jirl_exe;
    wire            btb_hit_exe;
    wire            btb_tag_hi_match_pif;              //btb命中时tag的高位
    wire            exe_allow_update;           //exe级指令允许执行(允许更新分支预测器)
`ifdef PERF_STAT_EN
    wire            pht_taken_perf;
`endif
    //流水线控制
    wire        pif_valid;                  //pif stage 中是否含有效的指令(始终有效)
    wire        stall;
    wire        stall_pif;
    wire        icacop_en_pmem;
    wire [31:0] icacop_pc_pmem;
    wire [7:0]  icacop_index_pmem;
    wire [31:0] icacop_paddr_pmem;
    wire [1:0]  icacop_code_4_3_pmem;
    assign {refetch, refetch_addr, icacop_en_pmem ,icacop_code_4_3_pmem,icacop_pc_pmem, icacop_index_pmem, icacop_paddr_pmem} = refetch_bus;
    assign {exe_allow_update, pc_exe, is_br_exe,is_jirl_exe, btb_hit_exe, br_tar_exe, br_taken_exe, br_taken_predict_exe,addr_incorrect_exe} = br_bus;
    assign {ex_jump, ex_npc} = ex_jump_bus;
    always @(*)begin
        if(ex_jump)
            icache_index = ex_npc[11:4];
        else if(icacop_en_pmem)
            icache_index = icacop_index_pmem;
        else if(refetch)
            icache_index = refetch_addr[11:4];
        else if(miss_predict)
            icache_index = pc_correct[11:4];
        else icache_index = pc_predict[11:4];
    end
    always @(*)begin
        //同时存在refetch和exception的时候，exception优先
        if(ex_jump) 
            npc = ex_npc;
        else if(icacop_en_pmem)
            npc = icacop_pc_pmem;
        else if(refetch)
            npc = refetch_addr;
        else if(miss_predict)
            npc = pc_correct;
        else npc = pc_predict;
    end
    bpu U_BPU(
         //预测通道
        .clk(clk),
        .rst_n(rst_n),
        .pc_pif(pc_pif),
        .pc_predict(pc_predict),                    //预测的pc
        .br_taken_predict(br_taken_predict_pif),    //预测为跳转
        .btb_hit(btb_hit_pif),                      //使用pc寻址btb，结果为命中(不考虑是否为分支指令)
        .miss_predict(miss_predict),                //先前分支预测出错
        .pc_correct(pc_correct),                    //分支预测出错时正确的pc
        .pif_allow_update(!stall),
        .btb_tag_hi_match(btb_tag_hi_match_pif),
        //更新预测结果通道
        .exe_allow_update(exe_allow_update),
        .addr_incorrect_exe(addr_incorrect_exe),
        .btb_clean(btb_clean),                      //清除btb(执行IBAR指令时，出现指令自修改)
        .pc_exe(pc_exe),                            //分支指令的pc
        .is_br_exe(is_br_exe),                      //是否为分支指令(不包含jirl)
        .is_jirl_exe(is_jirl_exe),                  //是否为jirl指令
        .btb_hit_exe(btb_hit_exe),                  //先前查询btb时是否命中
        .br_tar_exe(br_tar_exe),                    //跳转目标地址
        .br_taken_exe(br_taken_exe),                //指令实际是否跳转
        .br_taken_predict_exe(br_taken_predict_exe) //指令是否被预测为跳转
`ifdef PERF_STAT_EN
        ,
        .pht_taken_perf(pht_taken_perf)
`endif
    );
    assign stall_pif       = itlb_stall;
    assign stall           = stall_pif || stall_if || stall_id  || stall_exe  || stall_pmem || stall_mem;
    assign pif_wen         = !(stall_pif || stall_if || stall_id  || stall_exe  || stall_pmem || stall_mem) || flush;
    assign pif_valid       = 1'b1;
    assign pif_to_if_valid = pif_valid && !stall_pif;
    //MMU
    assign inst_sram_vaddr = pc_pif;
    wire [`WIDTH_PIF_BUS-1:0] pif_bus;
    reg  [`WIDTH_PIF_BUS-1:0] pif_reg;

    assign pif_bus = {icacop_en_pmem, icacop_paddr_pmem, icacop_code_4_3_pmem};
    always @(posedge clk)begin
        pif_reg <= pif_wen ? pif_bus : pif_reg;
    end
    //PC
    pc PC(.clk(clk),
          .rst_n(rst_n),
          .en(pif_wen),
          .pc(pc_pif),
          .npc(npc));
    wire        icacop_ghost_pif;
    wire [31:0] icacop_paddr_pif;
    assign {icacop_ghost_pif, icacop_paddr_pif,icacop_code_4_3_pif} = pif_reg;
    assign icache_is_cacop_pif = icacop_ghost_pif;
    assign pif_to_if_bus = {pc_pif, ex_pif, ecode_pif, br_taken_predict_pif, btb_hit_pif,btb_tag_hi_match_pif, icacop_ghost_pif
`ifdef PERF_STAT_EN
    ,
    icache_is_uncached,
    pht_taken_perf
`endif
};
    //IMEM
    assign inst_sram_addr  = icacop_ghost_pif ? icacop_paddr_pif : inst_sram_paddr;
    assign inst_sram_size  = 2'h2;
    assign inst_sram_wstrb = 4'h0;
    assign inst_sram_wr    = 1'h0;
    assign inst_sram_wdata = 32'h0;
    assign inst_sram_req   = !flush && !stall && !ex_pif;
endmodule
