`include "mycpu.h"

module premem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         pms_allowin   ,
    //stall
    input                          ms_stall      ,
    output                         pms_stall     ,
    //from ds
    input                           es_to_pms_valid,
    input  [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus  ,
    //to ms
    output                          pms_to_ms_valid,
    output [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus  ,
    // data sram interface
    output        data_sram_en     ,
    output [ 3:0] data_sram_we     ,
    output        data_sram_wr     ,
    output [31:0] data_sram_addr   ,
    output [31:0] data_sram_wdata  ,
    input         data_sram_addr_ok,
    output [1:0]  data_sram_size   ,
    //前递相关
    output [ 4:0] PMEM_dest      ,
    output [31:0] pms_resultr    ,
    output pms_rdcnt_op          ,
    output pms_load_op           ,
    output pms_csr_op            ,
    output pms_gtlb_we           ,
    output pms_valid_p           ,
    //exception
    input  wb_ex                 ,
    input  ms_ex                 ,
    input  wb_ertn               ,
    input  ms_ertn               ,
    input  wb_ertn_op            ,
    output pms_ex                ,

    //tlb相关
    output        tlb_search      ,
    output        invtlb_valid    ,
    output        pms_invtlb_valid,
    output [ 4:0] invtlb_op       ,
    output [18:0] invtlb_vppn     ,
    output [ 9:0] invtlb_asid     ,
    output [18:0] tlb_s1_vppn     ,
    output        tlb_s1_va_bit12 ,
    output [ 9:0] tlb_s1_asid     ,
    input         tlb_s1_found    ,
    input  [ 2:0] tlb_s1_index    ,
    input  [19:0] tlb_s1_ppn      ,
    input  [ 5:0] tlb_s1_ps       ,
    input  [ 1:0] tlb_s1_plv      ,
    input  [ 1:0] tlb_s1_mat      ,
    input         tlb_s1_d        ,
    input         tlb_s1_v        ,
    input         wb_tlb_flush    ,
    input         ms_tlb_flush    ,
    //csr相关
    input         crmd_da         ,
    input         crmd_pg         ,
    input  [ 1:0] crmd_datm       ,
    input  [ 1:0] crmd_plv        ,
    input  [18:0] csr_tlbehi_vppn ,
    input  [ 9:0] csr_asid_asid   ,
    input         dmw0_plv0       ,
    input         dmw0_plv3       ,
    input  [ 1:0] dmw0_mat        ,
    input  [ 2:0] dmw0_pseg       ,
    input  [ 2:0] dmw0_vseg       ,
    input         dmw1_plv0       ,
    input         dmw1_plv3       ,
    input  [ 1:0] dmw1_mat        ,
    input  [ 2:0] dmw1_pseg       ,
    input  [ 2:0] dmw1_vseg       ,
    //cache相关
    output        dcache_uncache_en,
    output        icache_cacop_en  ,
    output [ 1:0] icache_cacop_op  ,
    output [31:0] icache_cacop_va  , 
    input         icache_unbusy    ,
    output        dcache_cacop_en  ,
    output [ 1:0] dcache_cacop_op  ,
    output [31:0] dcache_cacop_va  ,
    input         dcache_unbusy         
);

//----------信号定义----------
//流水线相关信号
reg         pms_valid      ;
wire        pms_ready_go   ;
reg  [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus_r;
wire [31:0] pms_pc         ;
wire [31:0] pms_inst;
wire [31:0] pms_rj_value;
wire [31:0] pms_rkd_value;
wire [31:0] pms_alu_result;
wire [31:0] pms_result;
wire stall;

assign stall = ms_stall || pms_stall;

//寄存器相关
wire        pms_gr_we      ;
wire        es_to_pms_gr_we;
wire [ 4:0] pms_dest       ;
wire        pms_store_op;

//csr相关
wire [13:0] pms_csr_num;
wire        es_to_pms_gcsr_we;
wire        pms_res_from_csr;
wire        pms_gcsr_we;
wire        pms_ertn_op;
wire [ 2:0] pms_rd_cnt_op;
//tlb相关
wire        es_to_pms_gtlb_we;
wire        es_to_pms_gtlb_rd;
wire        pms_gtlb_rd;
wire        pms_tlb_flush;
wire        es_to_pms_tlb_flush;
wire        tlb_use;

//cache相关
wire       cacop_op;
wire [4:0] cacop_code;
wire pms_idle_op;
wire pms_tlbfill;
wire pms_inst_ll_w;
wire pms_inst_sc_w;
wire inst_csr_rstat_en;
wire [7:0] inst_ld_en;
wire [7:0] inst_st_en;
//内存操作相关
wire        pms_mem_we      ;
wire        pms_res_from_mem;
wire [ 3:0] pms_mem_bm_load ;
wire [ 2:0] pms_mem_bm_store;
wire [ 3:0] re_1_0_d;

wire [31:0] sc_w_value;

wire [ 3:0] data_sram_we_bm;
wire [31:0] data_wdata_b;
wire [31:0] data_wdata_h;

wire [31:0] p_data_sram_addr;

wire        dmw0_taken;
wire        dmw1_taken;

//exception相关
wire [ 5:0] es_to_pms_ecode;
wire [ 5:0] pms_ecode;
wire        es_to_pms_ex;
wire        ale_ex;
wire        tlbr_ex;   //tlb重填例外
wire        til_ex;    //load操作页无效
wire        tis_ex;    //store操作页无效
wire        pme_ex;
wire        ppi_ex;
wire [31:0] pms_ex_addr;//例外虚地址

wire ws_flush; //wb阶段的异常或重取
assign ws_flush = wb_ex || wb_ertn || wb_tlb_flush;

//----------信号赋值----------
wire pms_not_mem     = !((|pms_mem_bm_load[2:0]) || (|pms_mem_bm_store[2:0]) || icache_cacop_en || dcache_cacop_en);
wire pms_mem_addr_ok = ((pms_load_op || pms_store_op) && data_sram_addr_ok);
wire pms_cache_cacop = ((icache_cacop_en && icache_unbusy)) || ((dcache_cacop_en && dcache_unbusy));
assign pms_stall     = !pms_ready_go && pms_valid;
assign pms_ready_go    = pms_not_mem ||                                  
                         pms_mem_addr_ok ||
                         pms_cache_cacop ||
                         pms_ex || ws_flush; //当不是除法指令或者除法指令计算完成时，es_ready_go为1
assign pms_allowin     = !pms_valid || !stall;
assign pms_to_ms_valid =  pms_valid && !stall;
always @(posedge clk) begin
    if (reset) begin
        pms_valid <= 1'b0;
    end
    else if (ws_flush) begin
        pms_valid <= 1'b0;
    end
    else if (pms_allowin) begin
        pms_valid <= es_to_pms_valid;
    end

    if (pms_allowin) begin
        es_to_pms_bus_r <= es_to_pms_bus;
    end
end
assign pms_valid_p = pms_valid;
//接受总线数据
assign {sc_w_value,
        pms_idle_op,
        pms_tlbfill,
        pms_inst_ll_w,
        pms_inst_sc_w,
        inst_csr_rstat_en,
        inst_ld_en,
        inst_st_en,
        pms_inst,
        pms_invtlb_valid,
        tlb_search,
        pms_mem_we,
        pms_alu_result,
        pms_mem_bm_store,
        data_sram_we_bm,
        data_wdata_b,
        data_wdata_h,
        cacop_op        ,
        cacop_code      ,
        es_to_pms_tlb_flush,
        invtlb_op,
        es_to_pms_gtlb_rd,
        es_to_pms_gtlb_we,
        pms_load_op     ,
        pms_store_op    ,
        pms_rd_cnt_op   ,
        pms_ertn_op     ,
        es_to_pms_ecode,
        pms_csr_op      ,  
        es_to_pms_ex    ,  
        pms_rj_value    ,  
        pms_rkd_value   ,  
        pms_csr_num     ,  
        es_to_pms_gcsr_we,  
        pms_res_from_csr, 
        re_1_0_d       ,  
        pms_mem_bm_load ,  
        pms_res_from_mem,  
        es_to_pms_gr_we ,  
        pms_dest        ,  
        pms_result      ,  
        pms_pc             
       } = es_to_pms_bus_r;


//内存操作相关赋值
assign dmw0_taken = crmd_pg && ((crmd_plv == 2'h3 && dmw0_plv3) || (crmd_plv == 2'h0 && dmw0_plv0)) && (pms_result[31:29] == dmw0_vseg);
assign dmw1_taken = crmd_pg && ((crmd_plv == 2'h3 && dmw1_plv3) || (crmd_plv == 2'h0 && dmw1_plv0)) && (pms_result[31:29] == dmw1_vseg);

assign p_data_sram_addr = crmd_da                         ? pms_result :
                          dmw0_taken                      ? {{dmw0_pseg},{pms_result[28:0]}}    :
                          dmw1_taken                      ? {{dmw1_pseg},{pms_result[28:0]}}    :
                          (crmd_pg && tlb_s1_ps == 6'h15) ? {tlb_s1_ppn[19:9],pms_result[20:0]} :
                          (crmd_pg && tlb_s1_ps == 6'h0c) ? {tlb_s1_ppn[19:0],pms_result[11:0]} :
                          32'b0;

assign data_sram_en    = (pms_load_op || pms_store_op) && !ms_stall && pms_valid && !ms_ex && !ms_ertn && !pms_ex && !ws_flush;
assign data_sram_we    = pms_mem_we && pms_valid && !ms_ex && !ms_ertn && !pms_ex && !ws_flush ? data_sram_we_bm : 4'h0;
assign data_sram_wr    = |data_sram_we;
assign data_sram_addr  = p_data_sram_addr;
assign data_sram_wdata = pms_mem_bm_store[2] ? pms_rkd_value :
                         pms_mem_bm_store[1] ? data_wdata_h :
                         pms_mem_bm_store[0] ? data_wdata_b :
                                              32'b0;      
assign data_sram_size  = pms_mem_bm_store[2] || pms_mem_bm_load[2] ? 2'b10 :
                         pms_mem_bm_store[1] || pms_mem_bm_load[1] ? 2'b01 :
                                                                   2'b00 ;                                                                          

//寄存器相关赋值
assign  pms_gr_we = es_to_pms_gr_we && !ws_flush;
assign  PMEM_dest = pms_dest & {5{pms_valid}};   

//csr相关赋值
assign  pms_gcsr_we = es_to_pms_gcsr_we && !ws_flush;

//tlb相关赋值
assign pms_gtlb_we  = es_to_pms_gtlb_we && !ws_flush;
assign pms_gtlb_rd  = es_to_pms_gtlb_rd && !ws_flush;
assign invtlb_valid = pms_invtlb_valid && !ws_flush;
assign invtlb_asid  = pms_rj_value[9:0];
assign invtlb_vppn  = pms_rkd_value[31:13];
assign pms_tlb_flush = es_to_pms_tlb_flush && !ws_flush;

//exception相关赋值
assign tlb_use = crmd_pg && !(dmw0_taken || dmw1_taken);
assign pms_ex  = (es_to_pms_ex || ale_ex || tlbr_ex || til_ex || tis_ex || pme_ex || ppi_ex) && pms_valid && !ws_flush ;
assign ale_ex = (pms_mem_bm_load[2] && pms_result[1:0] != 2'b0) || 
                (pms_mem_bm_load[1] && pms_result[0]   != 1'b0) ||
                (pms_mem_bm_store[1] && pms_result[0]  != 1'b0) ||
                (pms_mem_bm_store[2] && pms_result[1:0]!= 2'b0) ;            
assign tlbr_ex = (pms_load_op || pms_store_op || (cacop_op && cacop_code[4:3] == 2'h2)) && !tlb_s1_found && tlb_use;
assign til_ex  = (pms_load_op || (cacop_op && cacop_code[4:3] == 2'h2)) && tlb_s1_found && !tlb_s1_v && tlb_use;
assign tis_ex  = pms_store_op && tlb_s1_found && !tlb_s1_v && tlb_use;
assign pme_ex  = pms_store_op && tlb_s1_found && !tlb_s1_d && tlb_use; 
assign ppi_ex  = (pms_load_op || pms_store_op || (cacop_op && cacop_code[4:3] == 2'h2)) && tlb_s1_found && (tlb_s1_plv < crmd_plv) && tlb_use;

assign pms_ecode = es_to_pms_ex ? es_to_pms_ecode  : 
                  ale_ex      ? 6'h09           :
                  tlbr_ex     ? 6'h3f           :
                  til_ex      ? 6'h01           :
                  tis_ex      ? 6'h02           :
                  ppi_ex      ? 6'h07           :
                  pme_ex      ? 6'h04           :             
                                6'h00           ;

assign pms_ex_addr = pms_ex && !es_to_pms_ex ? pms_result : pms_pc;                        
                                
assign pms_rdcnt_op = pms_rd_cnt_op != 3'b0;
//PMS_TO_MS_BUS赋值
assign pms_resultr = pms_inst_sc_w ? sc_w_value : pms_result;

assign pms_to_ms_bus = {pms_idle_op,
                        tlb_s1_index,
                        tlb_s1_found,
                        tlb_search,
                        pms_tlbfill,
                        data_sram_addr,
                        pms_result,
                        data_sram_wdata,
                        pms_inst_ll_w,
                        pms_inst_sc_w,
                        inst_csr_rstat_en,
                        inst_ld_en,
                        inst_st_en,
                        pms_inst,
                        pms_tlb_flush,
                        pms_gtlb_rd,
                        pms_gtlb_we,
                        pms_load_op     ,
                        pms_store_op    ,
                        pms_rd_cnt_op   ,
                        pms_ex_addr     ,
                        pms_ertn_op     ,
                        pms_ecode       ,
                        pms_csr_op      ,
                        pms_ex    ,
                        pms_rj_value    ,
                        pms_rkd_value   ,
                        pms_csr_num     ,
                        pms_gcsr_we ,
                        pms_res_from_csr,
                        re_1_0_d    ,
                        pms_mem_bm_load ,
                        pms_res_from_mem, 
                        pms_gr_we       ,  
                        pms_dest        ,  
                        pms_resultr    ,  
                        pms_pc 
                      };


//tlb相关信号生成
assign tlb_s1_vppn  = tlb_search   ? csr_tlbehi_vppn :
                      pms_invtlb_valid ? invtlb_vppn :
                      pms_result[31:13];

assign tlb_s1_va_bit12 = pms_result[12];
                         

assign tlb_s1_asid = pms_invtlb_valid ? invtlb_asid :
                     csr_asid_asid;

//-----------cache相关赋值-----------
assign dcache_uncache_en = crmd_da ? crmd_datm == 2'b00 :
                           dmw0_taken ? dmw0_mat == 2'b00 :
                           dmw1_taken ? dmw1_mat == 2'b00 :
                           tlb_s1_found ? tlb_s1_mat == 2'b00 :
                           1'b0;

assign icache_cacop_en = (cacop_code[2:0] == 3'b0) && pms_valid && cacop_op && !pms_ex && !ms_ex && !ms_ertn && !ms_tlb_flush && !ws_flush;
assign icache_cacop_op = cacop_code[4:3];
assign icache_cacop_va = icache_cacop_op == 2'h2 ? p_data_sram_addr : pms_alu_result;
assign dcache_cacop_en = (cacop_code[2:0] == 3'b1) && pms_valid && cacop_op && !pms_ex && !ms_ex && !ms_ertn && !ms_tlb_flush && !ws_flush;
assign dcache_cacop_op = cacop_code[4:3];
assign dcache_cacop_va = dcache_cacop_op == 2'h2 ? p_data_sram_addr : pms_alu_result;


endmodule
