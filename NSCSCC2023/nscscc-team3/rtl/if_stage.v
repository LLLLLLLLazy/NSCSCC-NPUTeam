`include "header.v"
module if_stage(
    input                               clk,
    input                               rst_n,
    input                               stall_id,
    input                               stall_exe,
    input                               stall_pmem,
    input                               stall_mem,
    output                              stall_if,
    output                              stall_if_to_wb,
    input [31:0]                        inst_sram_rdata,
    input                               icache_stall,
    input                               flush,
    input [`WIDTH_PIF_TO_IF_BUS-1:0]    pif_to_if_bus,
    input                               pif_to_if_valid,
    output [`WIDTH_IF_TO_ID_BUS-1:0]    if_to_id_bus,       //if到id的数据
    output                              if_to_id_valid      //if stage 是否有一条指令可以进入下一级
);
    //IMEM
    wire [31:0]     instr_if;
    reg  [31:0]     instr_reg;
    reg             valid_reg;
    //pc和例外
    wire [31:0]     pc_if;
    wire            ex_if;
    wire [5:0]      ecode_if;
    wire            ex_pre_if;
    wire [5:0]      ecode_pre_if;
    //分支预测
    wire            br_taken_predict_if;
    wire            btb_hit_if;
    wire            btb_real_hit_if;
    wire            btb_tag_hi_match_if;             //btb命中时tag的高位
    wire            btb_tag_unmatch_if;              //pif级判断btb命中,但是tag高位比较失败,实际不命中
    //if sgate
    //reg wait_flag;
    //reg wait_flag_next;
    reg if_valid;                                   //if stage 中是否含有效的指令
    reg [`WIDTH_PIF_TO_IF_BUS-1:0] pif_to_if_reg;   //流水线寄存器
    wire stall_from_back;                           //相当于下一级的allow in信号取反
    wire stall;
    wire icacop_ghost_if;                           //icacop跳转到自己后，为了重新访问icache而产生的幽灵指令
    assign stall      = stall_if || stall_id || stall_exe || stall_pmem || stall_mem;
    assign stall_from_back = stall_id || stall_exe || stall_pmem || stall_mem;
    assign stall_if_to_wb = stall;
    assign stall_if   = icache_stall;
    assign if_to_id_valid = if_valid && !stall_if && !icacop_ghost_if;
    always @(posedge clk)begin
        pif_to_if_reg <= stall ? pif_to_if_reg : pif_to_if_bus;
    end
    always @(posedge clk)begin
        if(!rst_n || flush)
            if_valid <= 0;
        else if(!stall)
            if_valid <= pif_to_if_valid;
    end
    //性能统计
`ifdef PERF_STAT_EN
    wire            pht_taken_perf;
    reg [7:0] icache_stall_count_perf;
    wire      icache_is_uncached_perf;
    always @(posedge clk)begin
        if(!rst_n || flush)
            icache_stall_count_perf <= 0;
        else if(icache_stall)
            icache_stall_count_perf <= icache_stall_count_perf + 1;
        else icache_stall_count_perf <= 0;
    end
`endif
    assign {pc_if,ex_pre_if,ecode_pre_if,br_taken_predict_if, btb_hit_if, btb_tag_hi_match_if, icacop_ghost_if
`ifdef PERF_STAT_EN
            ,
            icache_is_uncached_perf,
            pht_taken_perf
`endif
    } = pif_to_if_reg;
    assign btb_tag_unmatch_if = ~btb_tag_hi_match_if;
    assign btb_real_hit_if    = btb_hit_if && btb_tag_hi_match_if;
    //IF级例外处理
    assign ex_if = ex_pre_if;
    assign ecode_if = ecode_pre_if;
    assign instr_if = inst_sram_rdata;

    wire [`WIDTH_PDC_BUS-1:0] predecode_bus_if;
    //预解码
    predecoder PDC(instr_if,predecode_bus_if);
    assign if_to_id_bus = {pc_if, instr_if, ex_if, ecode_if,
                           br_taken_predict_if, btb_real_hit_if, btb_tag_unmatch_if,predecode_bus_if
`ifdef PERF_STAT_EN
                            ,
                            icache_stall_count_perf,
                            icache_is_uncached_perf,
                            pht_taken_perf
`endif
                        };
endmodule
