`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //stall
    input                          pms_stall      ,
    input                          ms_stall       ,
    input                          es_stall       ,
    input                          ds_stall       ,
    output                         fs_stall       ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output                         inst_sram_en   ,
    output [ 3:0]                  inst_sram_we   ,
    output [31:0]                  inst_sram_addr ,
    output [31:0]                  inst_sram_wdata,
    input  [31:0]                  inst_sram_rdata,
    output [ 1:0]                  inst_sram_size , 
    input                          inst_sram_addr_ok,
    input                          inst_sram_data_ok,
    //csr
    input  [31:0]                  csr_era_addr    ,
    input  [31:0]                  ex_entry        ,
    input                          crmd_da         ,
    input                          crmd_pg         ,
    input  [ 1:0]                  crmd_datf       ,
    input  [ 1:0]                  crmd_plv        ,
    input                          dmw0_plv0       ,
    input                          dmw0_plv3       ,
    input  [ 1:0]                  dmw0_mat        ,
    input  [ 2:0]                  dmw0_pseg       ,
    input  [ 2:0]                  dmw0_vseg       ,
    input                          dmw1_plv0       ,
    input                          dmw1_plv3       ,
    input  [ 1:0]                  dmw1_mat        ,
    input  [ 2:0]                  dmw1_pseg       ,
    input  [ 2:0]                  dmw1_vseg       ,
    //exception
    input         wb_ex          ,//进入例外
    input         wb_ertn        ,//例外返回
    input         wb_idle_op     ,
    input         has_int        ,
    //tlb
    output [18:0] tlb_s0_vppn    ,
    output        tlb_s0_va_bit12,
    input         tlb_s0_found   ,
    input  [19:0] tlb_s0_ppn     ,
    input  [ 5:0] tlb_s0_ps      ,
    input  [ 1:0] tlb_s0_plv     ,
    input  [ 1:0] tlb_s0_mat     ,
    input         tlb_s0_d       ,
    input         tlb_s0_v       ,
    input         wb_tlb_flush   ,
    input  [31:0] tlb_flush_addr ,
    //uncache
    output        icache_uncache_en

);


//----------信号定义----------
//流水线相关信号定义
wire        pre_fs_ready_go;    //pre-IF阶段是否准备好发射
wire        to_fs_valid;        //向IF阶段传递的指令是否有效
reg         fs_valid;           //IF阶段指令是否有效
wire        fs_ready_go;        //IF阶段是否准备好发射
wire        fs_allowin;         //IF阶段是否允许接收新指令

wire        stall;
assign      stall = pms_stall || ms_stall || es_stall || ds_stall || fs_stall;

//PC地址生成相关信号定义
wire [31:0]  seq_pc;    //顺序执行的下一PC，即PC+4
wire [31:0]  nextpc;    //下一PC
wire [31:0]  p_nextpc;  //下一PC的物理地址
reg          ex_en;     //是否进入例外
reg          ertn_en;   //是否例外返回
wire         br_taken;  //是否执行跳转
wire [31:0]  br_target; //跳转目标地址
wire         br_stall;  //跳转阻塞信号(跳转目标地址生成未完成)
reg          idle_lock;

assign {br_stall,br_taken,br_target} = br_bus;

//跳转总线寄存器(防止因branch指令离开id阶段而导致br_bus数据丢失)
reg  [33:0]  br_bus_r;  
reg          br_bus_r_valid;
wire         br_taken_r;
wire [31:0]  br_target_r;
wire         br_stall_r;   

always @(posedge clk) begin
    if (reset) begin
        br_bus_r_valid <=  1'b0;
        br_bus_r       <= 34'b0;
    end
    else if(pre_fs_ready_go && fs_allowin) begin
        br_bus_r_valid <= 1'b0;
    end
    else if (br_taken) begin
        br_bus_r_valid <= 1'b1;
        br_bus_r <= br_bus;
    end
end

assign {br_stall_r,br_taken_r,br_target_r} = br_bus_r;

wire [31:0] fs_inst;    //IF阶段指令
reg  [31:0] fs_inst_r;  //IF阶段指令寄存器
reg         fs_inst_valid;
reg  [31:0] fs_pc;      //IF阶段PC
//例外相关信号定义
wire        ex_aedf;
wire        ex_tlbr;    //tlb重填例外
wire        ex_pif;     //取指页错误例外
wire        fs_ex;
wire  [5:0] ecode;
wire        pre_fs_ex;
wire  [5:0] pre_fs_to_fs_ecode;
wire        pre_fs_to_fs_ex;
wire  [5:0] pre_fs_ecode;
wire  [6:0] pre_fs_to_fs_bus;
reg   [6:0] pre_fs_to_fs_bus_r;
//类sram相关
reg         rdata_cancel;
reg         data_ok_r;

//tlb相关信号
reg         tlb_flush_en;
wire        dmw0_taken;
wire        dmw1_taken;

//----------pre-IF stage-----------
//ex_en信号以及ertn_en信号生成
always @(posedge clk) begin
    if (reset) begin
        ex_en <= 1'b0;
    end
    else if (wb_ex) begin   //由于寄存器的物理特性，需要根据ms_ex信号来判断是否进入例外
        ex_en <= 1'b1;
    end
    else if (pre_fs_ready_go && fs_allowin) begin
        ex_en <= 1'b0;
    end
end  
//ertn_en信号生成
always @(posedge clk) begin
    if (reset) begin
        ertn_en <= 1'b0;
    end
    else if (wb_ertn) begin
        ertn_en <= 1'b1;
    end
    else if (pre_fs_ready_go && fs_allowin) begin
        ertn_en <= 1'b0;
    end
end  

//tlb_flush_en信号生成
always @(posedge clk) begin
    if (reset) begin
        tlb_flush_en <= 1'b0;
    end
    else if (wb_tlb_flush) begin
        tlb_flush_en <= 1'b1;
    end
    else if (pre_fs_ready_go && fs_allowin) begin
        tlb_flush_en <= 1'b0;
    end
end

//idle_lock信号生成
always @(posedge clk) begin
    if (reset) begin
        idle_lock <= 1'b0;
    end
    else if (wb_idle_op && !wb_ex) begin
        idle_lock <= 1'b1;
    end
    else if (has_int) begin
        idle_lock <= 1'b0;
    end
end

//br_bus_r

//生成nextpc
assign to_fs_valid     = ~reset & pre_fs_ready_go & !wb_ex & !wb_ertn & !wb_tlb_flush; 
assign pre_fs_ready_go = ~br_stall && inst_sram_addr_ok && ~(idle_lock || wb_idle_op); //当br_stall为0且inst_sram成功接受请求地址后发射
assign seq_pc          = fs_pc + 3'h4;
assign nextpc          = ex_en                          ? ex_entry        :
                         ertn_en                        ? csr_era_addr    :
                         tlb_flush_en                   ? tlb_flush_addr  :
                         br_taken                       ? br_target       :
                         br_taken_r && br_bus_r_valid   ? br_target_r     : 
                                                          seq_pc          ; 
assign p_nextpc        = crmd_da ? nextpc :
                         dmw0_taken ? {dmw0_pseg,nextpc[28:0]}:
                         dmw1_taken ? {dmw1_pseg,nextpc[28:0]}:
                        (crmd_pg && tlb_s0_ps == 6'h15) ? {tlb_s0_ppn[19:9],nextpc[20:0]}:
                        (crmd_pg && tlb_s0_ps == 6'h0c) ? {tlb_s0_ppn[19:0],nextpc[11:0]}:
                         32'b0;

//----------IF stage----------
assign fs_stall       = !fs_ready_go && fs_valid;
assign fs_ready_go    = (inst_sram_data_ok || data_ok_r) && !rdata_cancel || fs_ex;//成功接受数据后才发射
//br_taken为1时，下一拍才能生成正确的PC地址，此时ds_allowin为1，但fs中的指令无效，允许新指令进入
assign fs_allowin     = !fs_valid || br_taken || !stall;
//当wb_ex为1时，清空当前流水线
assign fs_to_ds_valid = fs_valid && !stall && !wb_ex && !wb_ertn && !wb_tlb_flush && !br_taken;
    
always @(posedge clk) begin
    if (reset) begin
        fs_inst_r <= 32'h0;
        fs_inst_valid <= 1'b0;
    end
    else if (inst_sram_data_ok) begin
        fs_inst_r <= inst_sram_rdata;
        fs_inst_valid <= 1'b1;
    end
    else if (!stall) begin
        fs_inst_valid <= 1'b0;
    end
end    
assign fs_inst        = inst_sram_data_ok ? inst_sram_rdata : 
                        fs_inst_valid     ? fs_inst_r       : 
                        32'b0 ;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end    
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
    else if (wb_ex || wb_ertn || wb_tlb_flush) begin
        fs_valid <= 1'b0;
    end

    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

always @(posedge clk) begin
    if(reset) begin
        rdata_cancel <= 1'b0;
    end
    else if (br_taken && fs_valid && fs_stall) begin
        rdata_cancel <= 1'b1;
    end
    else if ((wb_ertn || wb_ex || wb_tlb_flush) && fs_stall) begin
        rdata_cancel <= 1'b1;
    end
    else if (inst_sram_data_ok || data_ok_r) begin
        rdata_cancel <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        data_ok_r <= 1'b0;
    end
    else if (!stall || br_taken || rdata_cancel && !inst_sram_data_ok) begin
        data_ok_r <= 1'b0;
    end
    else if (inst_sram_data_ok && !rdata_cancel) begin
        data_ok_r <= 1'b1;
    end
    
end

assign fs_to_ds_bus = {fs_ex   ,
                       ecode   ,
                       fs_inst ,
                       fs_pc   };

assign ex_aedf = (fs_pc[1:0] != 2'b0);
assign ex_tlbr = (!tlb_s0_found && crmd_pg) && !(dmw0_taken || dmw1_taken);
assign ex_pif  = tlb_s0_found && crmd_pg && !tlb_s0_v && !(dmw0_taken || dmw1_taken);
assign pre_fs_ex = (ex_tlbr || ex_pif) && to_fs_valid;
assign pre_fs_ecode = ex_tlbr ? 6'h3f :
                      ex_pif  ? 6'h03 :
                      6'h0;
assign pre_fs_to_fs_bus = {pre_fs_ex,pre_fs_ecode};
always @(posedge clk) begin
    if (reset) begin
        pre_fs_to_fs_bus_r <= 7'b0;
    end
    else if (fs_allowin) begin
        pre_fs_to_fs_bus_r <= pre_fs_to_fs_bus;
    end
end                   
assign {pre_fs_to_fs_ex,pre_fs_to_fs_ecode} = pre_fs_to_fs_bus_r;  
assign fs_ex   = (ex_aedf || pre_fs_to_fs_ex) && fs_valid ;
assign ecode   = ex_aedf ? 6'h08: 
                 pre_fs_to_fs_ex ? pre_fs_to_fs_ecode :
                 6'h0;   

assign inst_sram_en    = to_fs_valid && fs_allowin && !br_stall && !pre_fs_ex;
assign inst_sram_we    = 4'h0;
assign inst_sram_addr  = p_nextpc;
assign inst_sram_wdata = 32'b0;
assign inst_sram_size  = 2'b10;

//-----------tlb相关赋值-----------
assign tlb_s0_vppn     = nextpc[31:13];
assign tlb_s0_va_bit12 = nextpc[12];
assign dmw0_taken = crmd_pg && ((crmd_plv == 2'h3 && dmw0_plv3) || (crmd_plv == 2'h0 && dmw0_plv0)) && (nextpc[31:29] == dmw0_vseg);
assign dmw1_taken = crmd_pg && ((crmd_plv == 2'h3 && dmw1_plv3) || (crmd_plv == 2'h0 && dmw1_plv0)) && (nextpc[31:29] == dmw1_vseg);

//-----------cache相关赋值-----------
assign icache_uncache_en = crmd_da ? crmd_datf == 2'b00 :
                           dmw0_taken ? dmw0_mat == 2'b00 :
                           dmw1_taken ? dmw1_mat == 2'b00 :
                           tlb_s0_found ? tlb_s0_mat == 2'b00 :
                           1'b0;


endmodule
