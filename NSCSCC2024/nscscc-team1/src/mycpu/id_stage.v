`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //stall
    input                          ms_stall      ,
    input                          pms_stall     ,
    input                          es_stall      ,
    output                         ds_stall      ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //valid from es,ms,ws
    input                          es_valid_p    ,
    input                          pms_valid_p   ,
    input                          ms_valid_p    ,
    input                          ws_valid_p    ,
    //from es
    input                          br_taken,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    output [`DS_TO_ES_BR_WD -1:0 ] ds_to_es_br   ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //前递相关
    input  [ 4:0]                  EXE_dest      ,
    input  [ 4:0]                  PMEM_dest     ,
    input  [ 4:0]                  MEM_dest      ,
    input  [ 4:0]                  WB_dest       ,
    input                          es_load_op    ,
    input                          pms_load_op   ,
    input                          ms_load_op    ,
    input [31:0]                   es_result     , 
    input [31:0]                   pms_result    , 
    input [31:0]                   ms_result     ,
    input [31:0]                   ws_result     ,
    input                          es_csr_op     ,
    input                          pms_csr_op    ,
    input                          ms_csr_op     ,
    input                          ms_to_ws_valid,
    input                          es_gtlb_we    ,
    input                          pms_gtlb_we   ,
    input                          ms_gtlb_we    ,
    input                          ws_gtlb_we    ,
    input                          es_rdcnt_op   ,
    input                          pms_rdcnt_op  ,
    input                          ms_rdcnt_op   ,
    input                          es_result_stall,
    //csr
    input                          wb_ex         ,
    input                          wb_ertn       ,
    input                          ds_llbit      ,
    //中断相关
    input                          has_int       ,
    //tlb相关
    input                          wb_tlb_flush  ,
    output                         tlb_flush     ,
    output [31:0]                  tlb_flush_addr,
    //debug
    input                          infor_flag,
    input  [ 4:0]                  reg_num,
    output [31:0]                  debug_rf_rdata1

    // difftest
    `ifdef DIFFTEST_EN
    ,
    output [31:0]                  rf_to_diff [31:0]
    `endif
);


//----------信号定义----------
//流水线控制相关信号
reg         ds_valid   ;
wire        ds_ready_go;
wire        stall;

//fs_to_ds_bus相关信号
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;


//跳转相关信号
wire        load_stall;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

//操作类型信号
wire [14:0] alu_op;
wire        div_w_op;
wire        div_wu_op;
wire        mod_w_op;
wire        mod_wu_op;  
wire        load_op;
wire        store_op;
wire        csr_op;
wire        ertn_op;
wire [ 2:0] rd_cnt_op;
wire        cacop_op;
wire        preld_op;

//操作数相关信号
wire        src1_is_pc;
wire        src2_is_imm;
wire        src_reg_is_rd;  //操作数值来自rd
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;


//结果来源信号
wire        res_from_mem;   //结果来自mem
wire        res_from_csr;   //结果来自csr

//rf相关信号
wire        gr_we;
wire        mem_we;
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

//csr相关信号
wire        gcsr_we;
wire        csr_stall;
//tlb相关信号
wire        gtlb_we;
wire        gtlb_rd;
wire        gtlb_srch;
wire        invtlb_en;
wire [ 4:0] invtlb_op; 

//cache相关信号
wire [ 4:0] cacop_code;

//目标寄存器信号
wire        dst_is_r1; 
wire [ 4:0] dest;
wire        inst_no_dest;

//例外相关信号
wire        ds_ex; //id阶段异常信号
wire        ine_ex;//指令不存在列外
wire [ 5:0] ecode;
wire        fs_to_ds_ex;
wire [ 5:0] fs_to_ds_ecode;

//译码相关信号
//分段截取
wire [ 5:0] op_31_26;
wire [ 1:0] op_25_24;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] op_14_10;
wire [ 4:0] op_9_5;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [13:0] csr_num;
wire [11:0] i12;
wire [13:0] i14;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
//二进制转十进制
wire [63:0] op_31_26_d;
wire [ 3:0] op_25_24_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [31:0] op_14_10_d;
wire [31:0] op_9_5_d;

//指令
wire    inst_add_w;
wire    inst_sub_w;
wire    inst_slt;
wire    inst_sltu;
wire    inst_nor;
wire    inst_and;
wire    inst_or;
wire    inst_xor;
wire    inst_slli_w;
wire    inst_srli_w;
wire    inst_srai_w;
wire    inst_addi_w;
wire    inst_ld_b;
wire    inst_ld_bu;
wire    inst_ld_h;
wire    inst_ld_hu;
wire    inst_ld_w;
wire    inst_st_w;
wire    inst_st_h;
wire    inst_st_b;
wire    inst_jirl;
wire    inst_b;
wire    inst_bl;
wire    inst_beq;
wire    inst_bne;
wire    inst_blt;
wire    inst_bge;
wire    inst_bltu;
wire    inst_bgeu;
wire    inst_lu12i_w;
wire    inst_pcaddu12i;
wire    inst_slti;
wire    inst_sltui;
wire    inst_andi;
wire    inst_ori;
wire    inst_xori;
wire    inst_sll;
wire    inst_srl;
wire    inst_sra;
wire    inst_div_w;
wire    inst_div_wu;
wire    inst_mul_w;
wire    inst_mulh_w;
wire    inst_mulh_wu;
wire    inst_mod_w;
wire    inst_mod_wu;
wire    inst_csrrd;
wire    inst_csrwr;
wire    inst_csrxchg;
wire    inst_ertn;
wire    inst_syscall;
wire    inst_break;
wire    inst_rdcntvl_w;
wire    inst_rdcntvh_w;
wire    inst_rdcntid;
wire    inst_tlbrd;
wire    inst_tlbwr;
wire    inst_tlbfill;
wire    inst_tlbsrch;
wire    inst_invtlb;
wire    inst_cacop;
wire    inst_dbar;
wire    inst_ibar;
wire    inst_idle;
wire    inst_preld;
wire    inst_ll_w;
wire    inst_sc_w;
wire    r_type_inst;//运算类指令   

//操作数是否需要立即数
wire        need_ui5;
wire        need_si12;
wire        need_si14_pc;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4; 

//rj与rkd比较大小结果
wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_lt_rd_u;

//load指令相关
wire   [ 3: 0] mem_bm_load;


//st指令相关
wire    [ 2:0] mem_bm_store;

//idle相关信号
wire        idle_op;

//栅障指令相关
wire    pipeline_no_empty;
wire    dbar_stall;
wire    ibar_stall;

//前递相关
//是否需要rj,rk,rd寄存器中的值
wire src_not_rj;
wire src_not_rk;
wire src_not_rd;
//是否需要等待rj,rk,rd的值前递
wire wait_rj;
wire wait_rk;
wire wait_rd;

wire rj_from_es;
wire rj_from_pms;
wire rj_from_ms;
wire rj_from_ws;
wire rkd_from_es;
wire rkd_from_pms;
wire rkd_from_ms;
wire rkd_from_ws;

//tlbsrch 和 tlbwr冲突
wire wait_tlbwr;  //等待tlbwr写入后再进行查找

//----------信号赋值----------
//流水线相关信号赋值
always @(posedge clk) begin
    if(reset) begin
        ds_valid <= 1'b0;
    end
    else if(wb_ertn || wb_ex || wb_tlb_flush || br_taken) begin
        ds_valid <= 1'b0;
    end
    else if(ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end
wire ds_wait_rj = (~wait_rj || rj_from_es  || rj_from_pms || rj_from_ms  || rj_from_ws ); 
wire ds_wait_rk = (~wait_rk || rkd_from_es || rkd_from_pms || rkd_from_ms || rkd_from_ws);
wire ds_wait_rd = (~wait_rd || rkd_from_es || rkd_from_pms || rkd_from_ms || rkd_from_ws);
wire ds_wait_data = ds_wait_rj & ds_wait_rk & ds_wait_rd;
assign stall = ds_stall || ms_stall || pms_stall || es_stall;
assign ds_stall = !ds_ready_go && ds_valid;
assign ds_ready_go  = ds_wait_data && (~wait_tlbwr) || wb_ex || wb_ertn || wb_tlb_flush; //当例外时，不需要等待前递，因为当前指令已经被无效化处理

assign ds_allowin     = !ds_valid || !stall;
assign ds_to_es_valid = ds_valid && !br_taken && !stall && !wb_ertn && !wb_ex && !wb_tlb_flush;

//fs_to_ds_bus相关信号赋值
assign {fs_to_ds_ex,
        fs_to_ds_ecode,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

//跳转相关信号赋值
//当wb阶段报出例外时，无效化处理，不需要跳转
wire [8:0] all_br= {inst_beq,inst_bne,inst_bl,inst_b,
                    inst_blt,inst_bltu,inst_bge,inst_bgeu,
                    inst_jirl};
wire load_csr_stall = (load_stall | csr_stall) & {ds_valid};
wire [31:0] br_target = all_br[0] ? rj_value + jirl_offs : ds_pc + br_offs;
assign ds_to_es_br = {all_br,br_offs,br_target,load_csr_stall};



//判断是否是load后branch
assign load_stall = (wait_rd & es_load_op) || (wait_rj & es_load_op) || (wait_rk & es_load_op)
                  ||(wait_rd & pms_load_op) || (wait_rj & pms_load_op) || (wait_rk & pms_load_op)
                  ||(wait_rd & ms_load_op) || (wait_rj & ms_load_op) || (wait_rk & ms_load_op);
assign csr_stall  = (wait_rd & es_csr_op)  || (wait_rj & es_csr_op)  || (wait_rk & es_csr_op)
                  ||(wait_rd & pms_csr_op)  || (wait_rj & pms_csr_op)  || (wait_rk & pms_csr_op)
                  ||(wait_rd & ms_csr_op)  || (wait_rj & ms_csr_op)  || (wait_rk & ms_csr_op);

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

//操作类型赋值
assign alu_op[ 0] = inst_add_w | inst_addi_w 
                    | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu
                    | inst_st_w | inst_st_h | inst_st_b
                    | inst_jirl | inst_bl | inst_pcaddu12i
                    | inst_cacop|inst_ll_w | inst_sc_w 
                    | inst_preld ;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll;
assign alu_op[ 9] = inst_srli_w | inst_srl;
assign alu_op[10] = inst_srai_w | inst_sra;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;

assign div_w_op   = inst_div_w;
assign div_wu_op  = inst_div_wu;
assign mod_w_op   = inst_mod_w;
assign mod_wu_op  = inst_mod_wu;

assign load_op    = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ll_w;
assign store_op   = inst_st_w | inst_st_h | inst_st_b | (inst_sc_w & ds_llbit);

assign csr_op     = inst_csrrd | inst_csrwr |inst_csrxchg | inst_rdcntid;
assign ertn_op    = inst_ertn ;

assign rd_cnt_op  = {inst_rdcntid,inst_rdcntvh_w ,inst_rdcntvl_w };
assign cacop_op   = inst_cacop;
assign preld_op   = inst_preld;

//操作数相关信号赋值
assign src1_is_pc   = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w | inst_srli_w |
                       inst_srai_w | inst_addi_w |
                       inst_ld_w   | inst_ld_b   |
                       inst_ld_h   | inst_ld_hu  |
                       inst_ld_bu  | inst_st_w   |
                       inst_st_h   | inst_st_b   |
                       inst_lu12i_w| inst_jirl   |
                       inst_bl     | inst_pcaddu12i|
                       inst_slti   | inst_sltui  |
                       inst_andi   | inst_ori    |
                       inst_xori   | inst_ll_w   |
                       inst_sc_w   | inst_preld  |
                       inst_cacop;

assign src_reg_is_rd = inst_beq | inst_bne  | inst_st_w 
                    | inst_st_b | inst_st_h | inst_blt 
                    | inst_bltu | inst_bge  | inst_bgeu 
                    | inst_csrwr| inst_csrxchg | inst_sc_w;

assign rj_value  = rj_from_es ? es_result :
                   rj_from_pms? pms_result:
                   rj_from_ms ? ms_result :
                   rj_from_ws ? ws_result :
                   inst_csrwr ? {32{1'b1}}: //当为指令csrwr时，设置csr_wmask为全1
                   rf_rdata1;

assign rkd_value = rkd_from_es ? es_result :
                   rkd_from_pms? pms_result:
                   rkd_from_ms ? ms_result :
                   rkd_from_ws ? ws_result :
                   rf_rdata2;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_si14_pc ? {{16{i14[13]}}, i14, 2'b0}:
             need_ui5  ? rk[4:0]                    :
             need_zi12 ? {{20{1'b0}}, i12[11:0]}    :
             /*need_si12*/{{20{i12[11]}}, i12[11:0]}; 

//结果来源信号赋值                   
assign res_from_mem = inst_ld_w | inst_ll_w
                    | inst_ld_b | inst_ld_h 
                    | inst_ld_bu| inst_ld_hu;
assign res_from_csr = inst_csrwr| inst_csrrd | inst_csrxchg;

//sc_w ll_w
wire ds_inst_sc_w;
wire ds_inst_ll_w;
wire [31:0] sc_w_value;
assign ds_inst_sc_w = inst_sc_w;
assign ds_inst_ll_w = inst_ll_w;
assign sc_w_value = {31'b0,ds_llbit};

//rf相关指令赋值
//wb阶段报出例外时，指令无效化处理
assign gr_we    = ~inst_st_w & ~inst_st_b & ~inst_st_h 
                & ~inst_beq  & ~inst_bne  & ~inst_b 
                & ~inst_blt  & ~inst_bltu & ~inst_bge 
                & ~inst_bgeu & ~inst_syscall & ~inst_ertn 
                & ~inst_break
                & ~inst_invtlb & ~inst_tlbfill & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr
                & ~inst_cacop
                & ~inst_dbar & ~inst_ibar
                & ~inst_idle & ~inst_preld
                & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;

assign mem_we   = (inst_st_w | inst_st_b | inst_st_h | inst_sc_w) & ~wb_ex & ~wb_ertn & ~wb_tlb_flush; 

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;

// debug
assign debug_rf_rdata1 = rf_rdata1;

assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;
       
//csr相关信号赋值
assign gcsr_we      = (inst_csrwr | inst_csrxchg) & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;

//tlb相关信号赋值
assign gtlb_we      = (inst_tlbwr || inst_tlbfill) & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign gtlb_rd      = inst_tlbrd   & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign gtlb_srch    = inst_tlbsrch & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign invtlb_en    = inst_invtlb  & ~wb_ex & ~wb_ertn & ~wb_tlb_flush;
assign invtlb_op    = ds_inst[4:0];
assign tlb_flush    = (inst_tlbwr || inst_ibar || inst_csrwr || inst_csrxchg) & ds_valid;
assign tlb_flush_addr = ds_pc + 32'h4;

//cache相关信号赋值
assign cacop_code   = ds_inst[ 4:0] & {5{inst_cacop}};

//目标寄存器信号赋值
assign dst_is_r1    = inst_bl;

assign dest         = dst_is_r1    ? 5'd1 : 
                      inst_no_dest ? 5'd0 : 
                      inst_rdcntid ? rj   :
                                     rd   ;

assign inst_no_dest = inst_st_w | inst_st_h | inst_st_b 
                    | inst_beq  | inst_bne  | inst_b 
                    | inst_blt  | inst_bltu | inst_bge | inst_bgeu
                    | inst_syscall | inst_ertn | inst_break
                    | inst_tlbfill | inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_invtlb
                    | inst_dbar    | inst_ibar
                    | inst_cacop   | inst_preld;                      

//例外相关信号赋值
assign ine_ex = ~r_type_inst
              & ~inst_slli_w & ~inst_srli_w & ~inst_srai_w & ~inst_addi_w
              & ~inst_ld_w & ~inst_ld_b & ~inst_ld_h & ~inst_ld_bu & ~inst_ld_hu
              & ~inst_st_w & ~inst_st_h & ~inst_st_b
              & ~inst_sc_w & ~inst_ll_w
              & ~inst_jirl & ~inst_b & ~inst_bl & ~inst_beq & ~inst_bne
              & ~inst_blt & ~inst_bltu & ~inst_bge & ~inst_bgeu
              & ~inst_lu12i_w & ~inst_pcaddu12i
              & ~inst_slti & ~inst_sltui & ~inst_andi & ~inst_ori & ~inst_xori
              & ~inst_div_w & ~inst_div_wu & ~inst_mul_w & ~inst_mulh_w & ~inst_mulh_wu
              & ~inst_mod_w & ~inst_mod_wu
              & ~inst_csrrd & ~inst_csrwr & ~inst_csrxchg
              & ~inst_ertn & ~inst_syscall & ~inst_break 
              & ~inst_rdcntvl_w & ~inst_rdcntvh_w & ~inst_rdcntid
              & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_tlbsrch & ~(inst_invtlb && invtlb_op < 5'h7) & ~inst_cacop
              & ~inst_dbar & ~inst_ibar 
              & ~inst_idle & ~inst_preld;

assign ds_ex  = (inst_syscall | inst_break | has_int | ine_ex | fs_to_ds_ex) & ds_valid & ~wb_ertn & ~wb_ex & ~wb_tlb_flush;

assign ecode  = fs_to_ds_ex  ? fs_to_ds_ecode :
                inst_syscall ? 6'h0b : 
                inst_break   ? 6'h0c :
                ine_ex       ? 6'h0d :
                               6'h00 ;
//idle相关信号赋值
assign idle_op = inst_idle;
//译码相关信号赋值
assign op_31_26   = ds_inst[31:26];
assign op_25_22   = ds_inst[25:22];
assign op_25_24   = ds_inst[25:24];
assign op_21_20   = ds_inst[21:20];
assign op_19_15   = ds_inst[19:15];
assign op_14_10   = ds_inst[14:10];
assign op_9_5     = ds_inst[ 9: 5];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i14  = ds_inst[23:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

assign csr_num = ds_inst[23:10];
//指令赋值
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_ll_w   = op_31_26_d[6'h08] & ~ds_inst[25] & ~ds_inst[24];
assign inst_sc_w   = op_31_26_d[6'h08] & ~ds_inst[25] &  ds_inst[24];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_csrrd  = op_31_26_d[6'h01] & op_25_24_d[2'h0] & op_9_5_d[5'h00];
assign inst_csrwr  = op_31_26_d[6'h01] & op_25_24_d[2'h0] & op_9_5_d[5'h01];
assign inst_csrxchg= op_31_26_d[6'h01] & op_25_24_d[2'h0] & ~op_9_5_d[5'h00] & ~op_9_5_d[5'h01];
assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0e];
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & (ds_inst[9:5] == 5'h0);
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h19] & (ds_inst[9:5] == 5'h0);
assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & (ds_inst[4:0] == 5'h0);
assign inst_tlbsrch   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0a];
assign inst_tlbrd     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0b];
assign inst_tlbwr     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0c];
assign inst_tlbfill   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0d];
assign inst_invtlb    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];
assign inst_cacop     = op_31_26_d[6'h01] & op_25_22_d[4'h8];
assign inst_dbar      = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h04];
assign inst_ibar      = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h05];
assign inst_idle      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_preld     = op_31_26_d[6'h0a] & op_25_22_d[4'hb];

assign r_type_inst = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and |
                     inst_or | inst_xor | inst_sll | inst_srl | inst_sra;

//立即数类型判断
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_hu | inst_ld_bu 
                     | inst_st_w | inst_st_h | inst_st_b
                     | inst_slti | inst_sltui| inst_cacop | inst_preld;
assign need_si14_pc  =  inst_ll_w | inst_sc_w;                     
assign need_zi12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bltu | inst_bge | inst_bgeu ;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

//rj与rkd比较大小结果
assign rj_eq_rd   = (rj_value == rkd_value);
assign rj_lt_rd   = ($signed(rj_value) < $signed(rkd_value));
assign rj_lt_rd_u = (rj_value < rkd_value);

//load指令相关赋值
assign mem_bm_load[ 2:0] = inst_ld_w | inst_ll_w  ? 3'b100 :
                           inst_ld_b | inst_ld_bu ? 3'b001 :
                           inst_ld_h | inst_ld_hu ? 3'b010 :
                                                    3'b000 ;

assign mem_bm_load[ 3] = ~inst_ld_bu & ~inst_ld_hu;

//st指令相关赋值
assign mem_bm_store = inst_st_w || (inst_sc_w && ds_llbit)? 3'b100 :
                      inst_st_h                           ? 3'b010 :
                      inst_st_b                           ? 3'b001 :
                                  3'b000 ;

//栅障指令相关赋值
assign pipeline_no_empty = (es_valid_p | pms_valid_p |ms_valid_p | ws_valid_p);  
assign dbar_stall        = inst_dbar & pipeline_no_empty;
assign ibar_stall        = inst_ibar & pipeline_no_empty; 

//前递相关赋值
assign src_not_rj = inst_b | inst_bl | inst_lu12i_w 
                  | inst_pcaddu12i | inst_csrwr | inst_csrrd 
                  | inst_syscall   | inst_break 
                  | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid 
                  | inst_tlbrd | inst_tlbsrch | inst_tlbfill | inst_tlbwr
                  | inst_dbar | inst_ibar
                  | inst_idle;

assign src_not_rk = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w 
                    | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu
                    | inst_st_w | inst_st_h   | inst_st_b 
                    | inst_lu12i_w | inst_jirl 
                    | inst_bl | inst_b | inst_beq | inst_bne 
                    | inst_pcaddu12i | inst_slti | inst_sltui | inst_andi
                    | inst_ori | inst_xori | inst_blt | inst_bltu
                    | inst_bge | inst_bgeu
                    | inst_csrrd | inst_csrwr | inst_csrxchg 
                    | inst_syscall | inst_break
                    | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid
                    | inst_tlbfill | inst_tlbrd | inst_tlbsrch |inst_tlbwr
                    | inst_cacop | inst_sc_w | inst_ll_w
                    | inst_dbar | inst_ibar
                    | inst_idle | inst_preld;

assign src_not_rd = ~inst_st_w & ~inst_st_h & ~inst_st_b 
                    & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bltu & ~inst_bge & ~inst_bgeu
                    & ~inst_csrwr & ~inst_csrxchg & ~inst_sc_w; 

assign wait_rj = ~src_not_rj & (rj == EXE_dest | rj == MEM_dest | rj == WB_dest | rj == PMEM_dest) & (rj != 5'd0);
assign wait_rk = ~src_not_rk & (rk == EXE_dest | rk == MEM_dest | rk == WB_dest | rk == PMEM_dest) & (rk != 5'd0);
assign wait_rd = ~src_not_rd & (rd == EXE_dest | rd == MEM_dest | rd == WB_dest | rd == PMEM_dest) & (rd != 5'd0);

assign rj_from_es  = (rf_raddr1 == EXE_dest && !es_load_op && !es_csr_op && !es_rdcnt_op && !es_result_stall) && wait_rj;
assign rj_from_pms = (rf_raddr1 != EXE_dest && rf_raddr1 == PMEM_dest && !pms_csr_op && !pms_load_op && !pms_rdcnt_op) && wait_rj;
assign rj_from_ms  = (rf_raddr1 != EXE_dest && rf_raddr1 != PMEM_dest && rf_raddr1 == MEM_dest && !ms_csr_op && !ms_load_op && !ms_rdcnt_op) && wait_rj;
assign rj_from_ws  = (rf_raddr1 != EXE_dest && rf_raddr1 != PMEM_dest && rf_raddr1 != MEM_dest && rf_raddr1 == WB_dest  ) && wait_rj; 

assign rkd_from_es  = (rf_raddr2 == EXE_dest && !es_load_op && !es_csr_op && !es_rdcnt_op && !es_result_stall) && (wait_rd || wait_rk);
assign rkd_from_pms = (rf_raddr2 != EXE_dest && rf_raddr2 == PMEM_dest && !pms_csr_op && !pms_load_op && !pms_rdcnt_op) && (wait_rd || wait_rk);
assign rkd_from_ms  = (rf_raddr2 != EXE_dest && rf_raddr2 != PMEM_dest && rf_raddr2 == MEM_dest && !ms_csr_op && !ms_load_op && !ms_rdcnt_op) && (wait_rd || wait_rk);
assign rkd_from_ws  = (rf_raddr2 != EXE_dest && rf_raddr2 != PMEM_dest && rf_raddr2 != MEM_dest && rf_raddr2 == WB_dest  ) && (wait_rd || wait_rk);

//TODO:修改invtlb的阻塞逻辑
assign wait_tlbwr = inst_tlbsrch && (es_gtlb_we || pms_gtlb_we || ms_gtlb_we || ws_gtlb_we || es_csr_op || pms_csr_op || ms_csr_op );


// difftest
wire ds_tlbfill;
assign ds_tlbfill = inst_tlbfill;
wire [7:0]  inst_ld_en;
wire [7:0]  inst_st_en;
wire        inst_csr_rstat_en;

// ll ldw ldhu ldh ldbu ldb
assign inst_ld_en = {2'b0, inst_ll_w, inst_ld_w, inst_ld_hu, inst_ld_h, inst_ld_bu, inst_ld_b};
// sc(llbit = 1) stw sth stb
assign inst_st_en = {4'b0, ds_llbit && inst_sc_w, inst_st_w, inst_st_h, inst_st_b};
assign inst_csr_rstat_en = (inst_csrrd || inst_csrwr || inst_csrxchg) && (csr_num == 14'd5);     

//ID~EXE信号总线
assign ds_to_es_bus = {preld_op,
                       idle_op,
                       ds_tlbfill,
                       inst_ll_w,
                       inst_csr_rstat_en,
                       inst_ld_en,
                       inst_st_en,
                       sc_w_value ,
                       ds_inst_sc_w,
                       ds_inst     ,
                       cacop_op    ,  //207:207 
                       cacop_code  ,  //206:202
                       tlb_flush   ,  //201:201
                       invtlb_op   ,  //200:196
                       invtlb_en   ,  //195:195
                       gtlb_srch   ,  //194:194
                       gtlb_rd     ,  //193:193
                       gtlb_we     ,  //192:192
                       store_op    ,  //191:191
                       rd_cnt_op   ,  //190:190
                       ertn_op     ,  //189:189
                       ecode       ,  //188:183
                       csr_op      ,  //182:182
                       ds_ex       ,  //181:181
                       csr_num     ,  //180:167
                       gcsr_we     ,  //166:166
                       res_from_csr,  //165:165
                       mem_bm_store,  //164:162
                       mem_bm_load ,  //161:158
                       mod_wu_op   ,  //157:157
                       mod_w_op    ,  //156:156
                       div_wu_op   ,  //155:155
                       div_w_op    ,  //154:154
                       alu_op      ,  //153:139
                       load_op     ,  //138:138
                       src1_is_pc  ,  //137:137
                       src2_is_imm ,  //136:136
                       src2_is_4   ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       imm         ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc       ,  //31 :0
                       res_from_mem
                      };                

//----------模块实例----------
decoder_6_64 u_dec0(.in(op_31_26  ), .out(op_31_26_d));
decoder_2_4  u_dec1(.in(op_25_24  ), .out(op_25_24_d));
decoder_4_16 u_dec2(.in(op_25_22  ), .out(op_25_22_d));
decoder_2_4  u_dec3(.in(op_21_20  ), .out(op_21_20_d));
decoder_5_32 u_dec4(.in(op_19_15  ), .out(op_19_15_d));
decoder_5_32 u_dec5(.in(op_14_10  ), .out(op_14_10_d));
decoder_5_32 u_dec6(.in(op_9_5    ), .out(op_9_5_d  ));

regfile u_regfile(
    .clk    (clk      ),
    .reset  (reset    ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    `ifdef DIFFTEST_EN
    ,
    .rf_o   (rf_to_diff)
    `endif 
    );

endmodule
