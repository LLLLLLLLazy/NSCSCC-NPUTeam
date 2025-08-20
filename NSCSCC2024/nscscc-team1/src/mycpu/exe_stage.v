`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          pms_allowin   ,
    output                         es_allowin    ,
    //stall            
    input                          ms_stall      ,
    input                          pms_stall     ,
    output                         es_stall      ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    input  [`DS_TO_ES_BR_WD -1:0 ] ds_to_es_br   ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to ds
    output                         br_taken,
    //to ms
    output                         es_to_pms_valid,
    output [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus  ,
    //前递相关
    output [ 4:0] EXE_dest       ,
    output [31:0] es_result      ,
    output es_load_op            ,
    output es_csr_op             ,
    output es_rdcnt_op           ,
    output es_gtlb_we            ,
    output es_valid_p            ,
    output es_result_stall       ,
    //exception
    input  wb_ex                 ,
    input  wb_ertn               ,
    output es_ex                 ,
    input  wb_tlb_flush          ,
    //计时器相关
    input [63:0] counter_value   ,  
    input [31:0] timer_id        
     
);

//----------信号定义----------
//流水线相关信号
reg         es_valid      ;
wire        es_ready_go   ;
reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
reg  [`DS_TO_ES_BR_WD  -1:0] ds_to_es_br_r;
wire        stall         ;

assign stall = es_stall || ms_stall || pms_stall;

//操作类型相关
wire [14:0] es_alu_op     ;
wire        es_inst_div_w ;
wire        es_inst_div_wu;
wire        es_inst_mod_w ;
wire        es_inst_mod_wu;
wire        es_inst_is_mul = es_alu_op[12] || es_alu_op[13] || es_alu_op[14];
wire [ 2:0] es_rd_cnt_op  ;
wire        es_store_op   ;
wire        es_idle_op    ;

//操作数相关
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_4  ;
wire        ds_to_es_gr_we;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_imm        ;
wire [31:0] es_pc         ;
wire [31:0] es_inst       ;
wire        es_inst_ll_w;
wire        es_inst_sc_w;
wire [31:0] sc_w_value;
wire [ 7:0] inst_ld_en;
wire [ 7:0] inst_st_en;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;

wire [31:0] alu_result    ;

//寄存器相关
wire        es_gr_we      ;
wire [ 4:0] es_dest       ;

//branch
wire [ 8:0] all_br;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire [31:0] br_target;

wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_lt_rd_u;

wire        beq_taken;
wire        bne_taken;
wire        blt_taken;
wire        bltu_taken;
wire        bge_taken;
wire        bgeu_taken;
wire        br_taken_all;

wire        load_csr_stall;
wire        br_stall;
//csr相关
wire [13:0] es_csr_num;
wire        ds_to_es_gcsr_we;
wire        es_res_from_csr;
wire        es_gcsr_we;

//tlb相关
wire [4:0] invtlb_op;
wire        tlb_search;
wire        ds_to_es_gtlb_we;
wire        ds_to_es_gtlb_rd;
wire        es_gtlb_rd;
wire        invtlb_valid;
wire        es_invtlb_valid;
wire        ds_to_es_tlb_flush;
wire        es_tlb_flush;
wire        inst_csr_rstat_en;
wire        es_tlbfill;
//cache相关
wire       cacop_op;
wire [4:0] cacop_code;
wire       preld_op;

//内存操作相关
wire        es_mem_we      ;
wire [ 3:0] es_mem_bm_load ;
wire [ 2:0] es_mem_bm_store;
wire [ 1:0] re_1_0  ;
wire [ 3:0] re_1_0_d;

wire [ 3:0] data_sram_we_bm;
wire [ 3:0] data_we_h;
wire [ 3:0] data_we_b;
wire [31:0] data_wdata_b;
wire [31:0] data_wdata_h;

wire        es_res_from_mem;

//exception相关
wire [ 5:0] ds_to_es_ecode;
wire [ 5:0] es_ecode;
wire        es_ertn_op;
wire        ds_to_es_ex;

//乘法相关
wire mul_done;
reg  mul_done_r;
wire mul_start = (es_alu_op[12] || es_alu_op[13] || es_alu_op[14]) && es_valid && !mul_done && !mul_done_r;

always @ (posedge clk) begin
    if(reset) begin
        mul_done_r <= 1'b0;
    end
    else if (!stall) begin
        mul_done_r <= 1'b0;
    end
    else if(mul_done) begin
        mul_done_r <= 1'b1;
    end 
end

//除法相关
wire div_start = (es_inst_div_w || es_inst_div_wu || es_inst_mod_w || es_inst_mod_wu) && es_valid;
wire [31:0] div_s;
wire [31:0] div_r;

wire        div_complete;

wire [31:0] divider_dividend;
wire [31:0] divider_divisor;


//----------信号赋值----------
wire es_not_mul_div = !(es_inst_is_mul || es_inst_div_w || es_inst_div_wu || es_inst_mod_w || es_inst_mod_wu);
wire es_mul_ok      = ((mul_done || mul_done_r) && es_inst_is_mul);
wire es_div_ok      =((div_complete) && (es_inst_div_w || es_inst_mod_w));
wire es_divu_ok     =((div_complete) && (es_inst_div_wu || es_inst_mod_wu));
assign es_stall     = !es_ready_go && es_valid;
assign es_ready_go    = es_not_mul_div || 
                        es_mul_ok      ||
                        es_div_ok      || 
                        es_divu_ok     ||                                   
                        es_ex || wb_ex || wb_ertn || wb_tlb_flush; //当不是除法指令或者除法指令计算完成时，es_ready_go为1
assign es_allowin     = !es_valid || !stall;
assign es_to_pms_valid =  es_valid && !stall;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
        ds_to_es_br_r <= ds_to_es_br;
    end
end
assign es_valid_p = es_valid;
//接受总线数据
assign {preld_op          ,
        es_idle_op        ,
        es_tlbfill        ,
        es_inst_ll_w      ,
        inst_csr_rstat_en ,
        inst_ld_en        ,
        inst_st_en        ,
        sc_w_value        ,
        es_inst_sc_w      ,
        es_inst         ,
        cacop_op        ,
        cacop_code      ,
        ds_to_es_tlb_flush,
        invtlb_op       ,
        es_invtlb_valid ,
        tlb_search      ,
        ds_to_es_gtlb_rd,
        ds_to_es_gtlb_we,
        es_store_op    ,
        es_rd_cnt_op   ,
        es_ertn_op     ,
        ds_to_es_ecode ,
        es_csr_op      ,  
        ds_to_es_ex    ,
        es_csr_num     ,
        ds_to_es_gcsr_we     ,
        es_res_from_csr,
        es_mem_bm_store,
        es_mem_bm_load ,
        es_inst_mod_wu ,
        es_inst_mod_w  ,
        es_inst_div_wu ,  //152:152
        es_inst_div_w  ,  //151:151
        es_alu_op      ,  //150:139
        es_load_op     ,  //138:138
        es_src1_is_pc  ,  //137:137
        es_src2_is_imm ,  //136:136
        es_src2_is_4   ,  //135:135
        ds_to_es_gr_we ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc          ,  //31 :0
        es_res_from_mem
       } = ds_to_es_bus_r;
assign {all_br,br_offs,br_target,load_csr_stall} = ds_to_es_br_r; 


//操作数相关赋值
assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : es_rj_value; 

assign es_alu_src2 = es_src2_is_imm ? es_imm : es_rkd_value;

assign es_result = es_inst_div_w || es_inst_div_wu ? div_s[31:0]  : 
                   es_inst_mod_w || es_inst_mod_wu ? div_r[31:0]  :
                   alu_result;    

//内存操作相关赋值
assign re_1_0 = alu_result[ 1:0];

assign data_we_b =    re_1_0_d[0] ? 4'b0001 : 
                      re_1_0_d[1] ? 4'b0010 :
                      re_1_0_d[2] ? 4'b0100 :
                      re_1_0_d[3] ? 4'b1000 : 
                      4'b0;

assign data_we_h =    re_1_0_d[0] ? 4'b0011 : 
                      re_1_0_d[1] ? 4'b0110 :
                      re_1_0_d[2] ? 4'b1100 :
                      4'b0;


assign data_sram_we_bm = es_mem_bm_store[2] ? 4'b1111   :
                         es_mem_bm_store[1] ? data_we_h :
                         es_mem_bm_store[0] ? data_we_b :
                                              4'b0      ;

assign data_wdata_b = re_1_0_d[0] ? {{24{1'b0}},es_rkd_value[7:0]}           :
                      re_1_0_d[1] ? {{16{1'b0}},es_rkd_value[7:0],{8{1'b0}}} :
                      re_1_0_d[2] ? {{8{1'b0}},es_rkd_value[7:0],{16{1'b0}}} :
                      re_1_0_d[3] ? {es_rkd_value[7:0],{24{1'b0}}}           :
                                    32'b0;   

assign data_wdata_h = re_1_0_d[0] ? {{16{1'b0}},es_rkd_value[15:0]}          :
                      re_1_0_d[1] ? {{8{1'b0}},es_rkd_value[15:0],{8{1'b0}}} :
                      re_1_0_d[2] ? {es_rkd_value[15:0],{16{1'b0}}}          :
                                    32'b0;

//寄存器相关赋值
assign  es_gr_we = ds_to_es_gr_we & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign  EXE_dest = es_dest & {5{es_valid}};   

//branch
assign rj_eq_rd   = (es_rj_value == es_rkd_value);
assign rj_lt_rd   = ($signed(es_rj_value) < $signed(es_rkd_value));
assign rj_lt_rd_u = (es_rj_value < es_rkd_value);

assign beq_taken = all_br[8] && rj_eq_rd;
assign bne_taken = all_br[7] && !rj_eq_rd;
assign blt_taken = all_br[4] && rj_lt_rd;
assign bltu_taken = all_br[3] && rj_lt_rd_u;
assign bge_taken = all_br[2] && !rj_lt_rd;
assign bgeu_taken = all_br[1] && !rj_lt_rd_u;
assign br_taken_all = beq_taken || bne_taken || blt_taken || bltu_taken || bge_taken || bgeu_taken|| all_br[6] || all_br[5] || all_br[0];

assign br_taken = br_taken_all && es_valid && ~wb_ex && ~wb_ertn && ~wb_tlb_flush;

assign br_stall = load_csr_stall & br_taken;

assign br_bus    = {br_stall,br_taken,br_target};
//前递
assign es_rdcnt_op = (es_rd_cnt_op != 3'b0);
assign es_result_stall = (es_inst_is_mul || es_inst_div_w || es_inst_div_wu || es_inst_mod_w || es_inst_mod_wu || es_inst_sc_w);

//csr相关赋值
assign  es_gcsr_we = ds_to_es_gcsr_we & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;

//tlb相关赋值
assign es_gtlb_we  = ds_to_es_gtlb_we & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign es_gtlb_rd  = ds_to_es_gtlb_rd & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign invtlb_valid = es_invtlb_valid & ~wb_ex & ~wb_ertn & es_valid & ~ds_to_es_ex & ~wb_tlb_flush;
assign invtlb_asid  = es_rj_value[9:0];
assign invtlb_vppn  = es_rkd_value[31:13];
assign es_tlb_flush = ds_to_es_tlb_flush & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;

//exception相关赋值
assign es_ex  = ds_to_es_ex & es_valid & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;

assign es_ecode = ds_to_es_ex ? ds_to_es_ecode  :            
                                6'h00           ;
                                
//除法相关赋值
assign divider_dividend = es_rj_value;
assign divider_divisor = es_rkd_value;

//EX_TO_PMS_BUS赋值
assign es_to_pms_bus = {sc_w_value,
                        es_idle_op,
                        es_tlbfill,
                        es_inst_ll_w,
                        es_inst_sc_w,
                        inst_csr_rstat_en,
                        inst_ld_en,
                        inst_st_en,
                        es_inst,
                        invtlb_valid,
                        tlb_search,
                        es_mem_we,
                        alu_result,
                        es_mem_bm_store,
                        data_sram_we_bm,
                        data_wdata_b,
                        data_wdata_h,
                        cacop_op        ,
                        cacop_code      ,
                        es_tlb_flush   ,
                        invtlb_op      ,
                        es_gtlb_rd     ,
                        es_gtlb_we     ,
                        es_load_op     ,
                        es_store_op    ,
                        es_rd_cnt_op   ,
                        es_ertn_op     ,
                        es_ecode       ,
                        es_csr_op      ,  //160:160
                        es_ex          ,  //159:159
                        es_rj_value    ,  //158:127
                        es_rkd_value   ,  //126:95
                        es_csr_num     ,  //94:81
                        es_gcsr_we     ,  //80:80 
                        es_res_from_csr,  //79:79 
                        re_1_0_d       ,  //78:75
                        es_mem_bm_load ,  //74:71 
                        es_res_from_mem,  //70:70
                        es_gr_we       ,  //69:69
                        es_dest        ,  //68:64
                        es_result      ,  //63:32
                        es_pc             //31:0
                      };

//----------模块实例----------
alu u_alu(
    .clk(clk),
    .reset(reset),
    .wb_tlb_flush(wb_tlb_flush || wb_ex || wb_ertn),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .mul_start  (mul_start),
    .mul_done   (mul_done),
    .alu_result (alu_result)
    );

div mydiv(
    .div_clk                (clk),
    .reset                  (reset),
    .div                    ((es_inst_div_w || es_inst_div_wu || es_inst_mod_w || es_inst_mod_wu) && es_valid),
    .div_signed             (es_inst_div_w || es_inst_mod_w),
    .x                      (divider_dividend),
    .y                      (divider_divisor),
    .s                      (div_s),
    .r                      (div_r),
    .complete               (div_complete)
    );



decoder_2_4  u_dec1(.in(re_1_0), .out(re_1_0_d));

endmodule
