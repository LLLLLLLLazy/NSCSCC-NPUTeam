
module csr(
    input                   clk,
    input                   reset,
    //READ PORT 1
    input    [13:0]         csr_raddr1,
    output   [31:0]         csr_rdata1,
    output   [31:0]         csr_eentry_addr,
    output   [31:0]         csr_era_addr,
    output   [31:0]         ex_entry, //例外入口地址
    output                  crmd_da,
    output                  crmd_pg,
    output   [ 1:0]         crmd_datf,
    output   [ 1:0]         crmd_datm,
    output   [ 1:0]         crmd_plv,
    //WRITE PORT 
    input                   csr_we,
    input    [13:0]         csr_waddr,
    input    [31:0]         csr_wdata,
    input    [31:0]         csr_wmask, //写掩码

    input                   wb_ex,    //异常信号
    input    [31:0]         wb_pc,    //异常地址
    input    [31:0]         ws_addr,  //出错虚地址
    input                   ertn_op,  //异常返回信号
    input    [5:0]          ecode, //例外一级编码
    input    [8:0]          subecode,//例外二级编码
    input    [7:0]          hw_int_in,//硬中断信号
    output                  has_int,  //中断信号
    output   [31:0]         timer_id, //定时器编号

    input                   llbit_in     ,
    input                   llbit_set_in ,
    output                  ds_llbit,

    //tlb相关
    //tlbwr
    output   [ 2:0]         tlb_w_index,
    output                  tlb_w_e,
    output   [18:0]         tlb_w_vppn,
    output   [ 5:0]         tlb_w_ps,
    output   [ 9:0]         tlb_w_asid,
    output                  tlb_w_g,
    output   [19:0]         tlb_w_ppn0,
    output   [ 1:0]         tlb_w_plv0,
    output   [ 1:0]         tlb_w_mat0,
    output                  tlb_w_d0,
    output                  tlb_w_v0,
    output   [19:0]         tlb_w_ppn1,
    output   [ 1:0]         tlb_w_plv1,
    output   [ 1:0]         tlb_w_mat1,
    output                  tlb_w_d1,
    output                  tlb_w_v1,

    //tlbrd
    input                   tlb_r_en,   //是否为tlbrd指令
    output   [ 2:0]         tlb_r_index,
    input                   tlb_r_e,
    input    [18:0]         tlb_r_vppn,
    input    [ 5:0]         tlb_r_ps,
    input    [ 9:0]         tlb_r_asid,
    input                   tlb_r_g,
    input    [19:0]         tlb_r_ppn0,
    input    [ 1:0]         tlb_r_plv0,
    input    [ 1:0]         tlb_r_mat0,
    input                   tlb_r_d0,
    input                   tlb_r_v0,
    input    [19:0]         tlb_r_ppn1,
    input    [ 1:0]         tlb_r_plv1,
    input    [ 1:0]         tlb_r_mat1,
    input                   tlb_r_d1,
    input                   tlb_r_v1,

    //tlbsrch
    input                   tlb_search,
    input                   tlb_s_found,
    input    [ 2:0]         tlb_s_index,
    //dmw
    output                  dmw0_plv0,
    output                  dmw0_plv3,
    output   [ 1:0]         dmw0_mat,
    output   [ 2:0]         dmw0_pseg,
    output   [ 2:0]         dmw0_vseg,
    output                  dmw1_plv0,
    output                  dmw1_plv3,
    output   [ 1:0]         dmw1_mat,
    output   [ 2:0]         dmw1_pseg,
    output   [ 2:0]         dmw1_vseg,

    // csr regs for diff
    output [31:0]                   csr_crmd_diff,
    output [31:0]                   csr_prmd_diff,
    output [31:0]                   csr_ectl_diff,
    output [31:0]                   csr_estat_diff,
    output [31:0]                   csr_era_diff,
    output [31:0]                   csr_badv_diff,
    output [31:0]                   csr_eentry_diff,
    output [31:0]                   csr_tlbidx_diff,
    output [31:0]                   csr_tlbehi_diff,
    output [31:0]                   csr_tlbelo0_diff,
    output [31:0]                   csr_tlbelo1_diff,
    output [31:0]                   csr_asid_diff,
    output [31:0]                   csr_save0_diff,
    output [31:0]                   csr_save1_diff,
    output [31:0]                   csr_save2_diff,
    output [31:0]                   csr_save3_diff,
    output [31:0]                   csr_tid_diff,
    output [31:0]                   csr_tcfg_diff,
    output [31:0]                   csr_tval_diff,
    output [31:0]                   csr_ticlr_diff,
    output [31:0]                   csr_llbctl_diff,
    output [31:0]                   csr_tlbrentry_diff,
    output [31:0]                   csr_dmw0_diff,
    output [31:0]                   csr_dmw1_diff,
    output [31:0]                   csr_pgdl_diff,
    output [31:0]                   csr_pgdh_diff
);

//CRMD 0x0 
reg    [1:0] csr_crmd_plv;
reg          csr_crmd_ie;
reg          csr_crmd_da;
reg          csr_crmd_pg;
reg    [1:0] csr_crmd_datf;
reg    [1:0] csr_crmd_datm;
wire  [31:0] csr_crmd_rvalue;

//PRMD 0X1
reg    [1:0] csr_prmd_pplv;
reg          csr_prmd_pie;
wire  [31:0] csr_prmd_rvalue;

//ECFG 0x4
reg    [9:0] csr_ecfg_lie_1;
reg    [1:0] csr_ecfg_lie_2;
wire  [31:0] csr_ecfg_rvalue;

//ESTAT 0X5
reg    [1:0] csr_estat_is_s; //软中断
reg    [7:0] csr_estat_is_h; //硬中断 
reg          csr_estat_is_timer; //定时器中断
reg          csr_estat_is_ipi;   //IPI中断
reg    [5:0] csr_estat_ecode;   //例外一级编码
reg    [8:0] csr_estat_esubcode;//例外二级编码
wire  [31:0] csr_estat_rvalue;

reg          timer_en;

//ERA 0X6
reg   [31:0] csr_era_pc; //例外返回地址
wire  [31:0] csr_era_rvalue;

//BADV 0X7
reg   [31:0] csr_badv_vaddr;
wire  [31:0] csr_badv_rvalue;

//EENTRY 0Xc
reg   [25:0] csr_eentry_va; //例外入口地址
wire  [31:0] csr_eentry_rvalue;

//TLBIDX 0X10
reg   [ 2:0] csr_tlbidx_index;//TLB索引
reg   [ 5:0] csr_tlbidx_ps;   //TLB表项PS值
reg          csr_tlbidx_ne;   //TLB表项有效位
wire  [31:0] csr_tlbidx_rvalue;

//TLBEHI 0X11
reg   [18:0] csr_tlbehi_vppn; //TLB表项vppn值
wire  [31:0] csr_tlbehi_rvalue;

//TLBELO0 0X12 
//偶数页信息
reg          csr_tlbelo0_v;   //TLB表项有效位
reg          csr_tlbelo0_d;   //TLB表项脏位
reg   [ 1:0] csr_tlbelo0_plv; //TLB表项plv值
reg   [ 1:0] csr_tlbelo0_mat; //TLB表项mat值 
reg          csr_tlbelo0_g;   //TLB表项全局位
reg   [19:0] csr_tlbelo0_ppn; //TLB表项ppn值
wire  [31:0] csr_tlbelo0_rvalue;

//TLBELO1 0X13
//奇数页信息
reg          csr_tlbelo1_v;   //TLB表项有效位
reg          csr_tlbelo1_d;   //TLB表项脏位
reg   [ 1:0] csr_tlbelo1_plv; //TLB表项plv值
reg   [ 1:0] csr_tlbelo1_mat; //TLB表项mat值
reg          csr_tlbelo1_g;   //TLB表项全局位
reg   [19:0] csr_tlbelo1_ppn; //TLB表项ppn值
wire  [31:0] csr_tlbelo1_rvalue;

//ASID 0X18
reg   [ 9:0] csr_asid_asid; //地址空间ID
reg   [ 7:0] csr_asid_asidbits; //ASID域的位宽
wire  [31:0] csr_asid_rvalue;

//PGDL 0x19
reg   [31:12] csr_pgdl_base;
wire  [31: 0] csr_pgdl_rvalue;

//PGDH 0x1A
reg   [31:12] csr_pgdh_base;
wire  [31: 0] csr_pgdh_rvalue;

//PGD  0x1B
wire  [31: 0] csr_pgd_rvalue;

//SAVE  0X30~0X33
reg   [31:0] csr_save[3:0]; //保存寄存器
wire  [31:0] csr_save_rvalue[3:0];

//TID 0X40
reg   [31:0] csr_tid; //定时器编号
wire  [31:0] csr_tid_rvalue;

//TCFG 0x41
reg          csr_tcfg_en; //定时器使能位
reg          csr_tcfg_periodic;//定时器循环模式控制位
reg   [29:0] csr_tcfg_initval; //定时器模式
wire  [31:0] csr_tcfg_rvalue;

//TVAL 0x42
reg   [31:0] csr_tval_timeval;
wire  [31:0] csr_tval_rvalue;

//TICLR 0x44
reg          csr_ticlr_clr;
wire  [31:0] csr_ticlr_rvalue;

//LLBit 0x60
reg         llbit;
reg         csr_llbctl_rollb;
reg         csr_llbctl_wcllb;
reg         csr_llbctl_klo;
reg  [31:3] csr_llbctl_r0;
wire [31:0] csr_llbctl_rvalue;

//TLBRENTRY 0x88
reg   [25:0] csr_tlbrentry_pa; //物理地址
wire  [31:0] csr_tlbrentry_rvalue;

//DMW0 0x180
reg          csr_dmw0_plv0;
reg          csr_dmw0_plv3;
reg   [ 1:0] csr_dmw0_mat;
reg   [ 2:0] csr_dmw0_pseg;
reg   [ 2:0] csr_dmw0_vseg;
wire  [31:0] csr_dmw0_rvalue;

//DMW1 0x181
reg          csr_dmw1_plv0;
reg          csr_dmw1_plv3;
reg   [ 1:0] csr_dmw1_mat;
reg   [ 2:0] csr_dmw1_pseg;
reg   [ 2:0] csr_dmw1_vseg;
wire  [31:0] csr_dmw1_rvalue;

//----------------------------REG_WRITE---------------------------
//CRMD REG WRITE LOGIC
//csr_crmd_plv write logic
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_plv <= 2'b0;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin //触发例外
        csr_crmd_plv <= 2'b0;
    end
    else if(ertn_op) begin //例外返回
        csr_crmd_plv <= csr_prmd_pplv;
    end
    else if(csr_we && csr_waddr==14'b0) begin  //写入CRMD
        csr_crmd_plv <= csr_wdata[1:0] & csr_wmask[1:0] | csr_crmd_plv & ~csr_wmask[1:0];
    end
end

//csr_crmd_ie write logic
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_ie <= 1'b0;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin //触发例外
        csr_crmd_ie <= 1'b0;
    end
    else if(ertn_op) begin //例外返回
        csr_crmd_ie <= csr_prmd_pie;
    end
    else if(csr_we && csr_waddr==14'b0) begin  //写入CRMD
        csr_crmd_ie <= csr_wdata[2] & csr_wmask[2] | csr_crmd_ie & ~csr_wmask[2];
    end   
end

//csr_crmd_da and csr_crmd_pg write logic
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if(wb_ex && ecode == 6'h3f) begin //触发例外
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if(ertn_op && csr_estat_ecode == 6'h3f) begin //例外返回
        csr_crmd_da <= 1'b0;
        csr_crmd_pg <= 1'b1;
    end
    else if(csr_we && csr_waddr==14'b0) begin  //写入CRMD
        csr_crmd_da <= csr_wdata[3] & csr_wmask[3] | csr_crmd_da & ~csr_wmask[3];
        csr_crmd_pg <= csr_wdata[4] & csr_wmask[4] | csr_crmd_pg & ~csr_wmask[4];
    end   
end

//csr_crmd_datf and csr_crmd_datm write logic
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_datf <= 2'b00;
        csr_crmd_datm <= 2'b00;
    end
    // else if(csr_crmd_pg == 1'b1)begin
    //     csr_crmd_datf <= 2'b01;
    //     csr_crmd_datm <= 2'b01;
    // end
    else if(csr_we && csr_waddr==14'b0) begin  //写入CRMD
        csr_crmd_datf <= csr_wdata[6:5] & csr_wmask[6:5] | csr_crmd_datf & ~csr_wmask[6:5];
        csr_crmd_datm <= csr_wdata[8:7] & csr_wmask[8:7] | csr_crmd_datm & ~csr_wmask[8:7];
    end   
end

//csr_crmd_rvalue 
assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

//PRMD REG WRTIE LOGIC
//csr_prmd_pplv write logic
always @(posedge clk) begin
    if(reset)begin
        csr_prmd_pplv <= 2'b00;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin //触发例外
        csr_prmd_pplv <= csr_crmd_plv;
    end
    else if(csr_we && csr_waddr==14'b1) begin  //写入PRMD
        csr_prmd_pplv <= csr_wdata[1:0] & csr_wmask[1:0] | csr_prmd_pplv & ~csr_wmask[1:0];
    end    
end 

//csr_prmd_pie write logic
always @(posedge clk) begin
    if(reset)begin
        csr_prmd_pie <= 1'b0;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin //触发例外
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if(csr_we && csr_waddr==14'b1) begin  //写入PRMD
        csr_prmd_pie <= csr_wdata[2] & csr_wmask[2] | csr_prmd_pie & ~csr_wmask[2];
    end    
end

//csr_prmd_rvalue write logic
assign csr_prmd_rvalue = {30'b0, csr_prmd_pie, csr_prmd_pplv};

//ECFG REG WRITE LOGIC
//csr_ecfg_lie_1 write logic
always @(posedge clk) begin
    if(reset)begin
        csr_ecfg_lie_1 <= 10'b0;
    end
    else if(csr_we && csr_waddr==14'h4) begin  //写入ECFG
        csr_ecfg_lie_1 <= csr_wdata[9:0] & csr_wmask[9:0] | csr_ecfg_lie_1 & ~csr_wmask[9:0];
    end
end

//csr_ecfg_lie_2 write logic
always @(posedge clk) begin
    if(reset)begin
        csr_ecfg_lie_2 <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h4) begin  //写入ECFG
        csr_ecfg_lie_2 <= csr_wdata[12:11] & csr_wmask[12:11] | csr_ecfg_lie_2 & ~csr_wmask[12:11];
    end
end

//csr_ecfg_rvalue write logic
assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie_2,1'b0,csr_ecfg_lie_1};

//ESTAT REG WRITE LOGIC
//csr_estat_is_s write logic
always @(posedge clk) begin
    if(reset)begin
        csr_estat_is_s <= 2'b00;
    end
    else if(csr_we && csr_waddr==14'h5) begin  //写入ESTAT
        csr_estat_is_s <= csr_wdata[1:0] & csr_wmask[1:0] | csr_estat_is_s & ~csr_wmask[1:0];
    end
end    

//csr_estat_is_h write logic
always @(posedge clk) begin
    if(reset)begin
        csr_estat_is_h <= 8'b0;
    end
    else begin
        csr_estat_is_h <= hw_int_in;
    end
end

//csr_estat_is_timer write logic
always @(posedge clk) begin
    if(reset)begin
        csr_estat_is_timer <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h44 && csr_wdata[0] && csr_wmask[0])begin
        csr_estat_is_timer <= 1'b0;
    end
    else if((csr_tval_timeval ==32'b0 || csr_tval_timeval == 32'b1) && timer_en) begin
        csr_estat_is_timer <= 1'b1;
    end
end

//csr_estat_is_ipi write logic
always @(posedge clk) begin
    if(reset)begin
        csr_estat_is_ipi <= 1'b0;
    end
end

//csr_estat_ecode write logic
always @(posedge clk) begin
    if(reset)begin
        csr_estat_ecode <= 6'b0;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin
        csr_estat_ecode <= ecode;
    end   
end

//csr_estat_esubcode write logic
always @(posedge clk) begin
    if(reset)begin
        csr_estat_esubcode <= 9'b0;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin
        csr_estat_esubcode <= subecode;
    end   
end

//timer_en write logic
always @(posedge clk) begin
    if(reset)begin
        timer_en <= 1'b0;
    end
    else if((csr_tval_timeval ==32'b0 || csr_tval_timeval == 32'b1) && timer_en)begin
        timer_en <= csr_tcfg_periodic;
    end
    else if(csr_we && csr_waddr==14'h41) begin  //写入ESTAT
        timer_en <= csr_wdata[0] & csr_wmask[0] | timer_en & ~csr_wmask[0];
    end
end

//csr_estat_rvalue write logic
assign csr_estat_rvalue = {1'b0,csr_estat_esubcode, csr_estat_ecode,3'b0,csr_estat_is_ipi, csr_estat_is_timer,1'b0,csr_estat_is_h, csr_estat_is_s};

//ERA REG WRITE LOGIC
//csr_era_pc write logic
always @(posedge clk) begin
    if(reset)begin
        csr_era_pc <= 32'b0;
    end
    else if(wb_ex && (csr_crmd_ie || ecode != 6'b0)) begin
        csr_era_pc <= wb_pc;
    end
    else if(csr_we && csr_waddr==14'h6) begin  //写入ERA
        csr_era_pc <= csr_wdata;
    end
end

//csr_era_rvalue write logic
assign csr_era_rvalue = csr_era_pc;

//BADV REG WRITE LOGIC
//csr_badv_vaddr write logic
always @(posedge clk) begin
    if(reset)begin
        csr_badv_vaddr <= 32'b0;
    end
    else if(wb_ex && (ecode == 6'h8 || ecode == 6'h9 || ecode == 6'h3f || ecode == 6'h01 || ecode == 6'h02 || ecode == 6'h03 || ecode == 6'h04 || ecode == 6'h07)) begin
        csr_badv_vaddr <= ws_addr;
    end
    else if(csr_we && csr_waddr==14'h7) begin  //写入BADV
        csr_badv_vaddr <= csr_wdata[31:0] & csr_wmask[31:0] | csr_eentry_va & ~csr_wmask[31:0];
    end
end

//csr_badv_rvalue write logic
assign csr_badv_rvalue = csr_badv_vaddr;

//EENTRY REG WRITE LOGIC
//csr_eentry_va write logic
always @(posedge clk) begin
    if(reset)begin
        csr_eentry_va <= 26'b0;
    end
    else if(csr_we && csr_waddr==14'hc) begin  //写入EENTRY
        csr_eentry_va <= csr_wdata[31:6] & csr_wmask[31:6] | csr_eentry_va & ~csr_wmask[31:6];
    end
end
//csr_eentry_rvalue write logic
assign csr_eentry_rvalue = {csr_eentry_va,6'b0};

//--------------------------TLB REG WRITE LOGIC--------------------------
//TLBIDX REG WRITE LOGIC
//csr_tlbidx_index write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbidx_index <= 3'b0;
    end
    else if(tlb_search && tlb_s_found) begin
        csr_tlbidx_index <= tlb_s_index;
    end
    else if(csr_we && csr_waddr==14'h10) begin  //写入TLBIDX
        csr_tlbidx_index <= csr_wdata[2:0] & csr_wmask[2:0] | csr_tlbidx_index & ~csr_wmask[2:0];
    end
end

//csr_tlbidx_ps write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbidx_ps <= 6'b0;
    end
    else if(csr_we && csr_waddr==14'h10) begin  //写入TLBIDX
        csr_tlbidx_ps <= csr_wdata[29:24] & csr_wmask[29:24] | csr_tlbidx_ps & ~csr_wmask[29:24];
    end
    else if(tlb_r_en)begin
        csr_tlbidx_ps <= tlb_r_ps & {6{tlb_r_e}};
    end
end

//csr_tlbidx_ne write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbidx_ne <= 1'b0;
    end
    else if(tlb_search) begin
        csr_tlbidx_ne <= ~tlb_s_found;
    end
    else if(csr_we && csr_waddr==14'h10) begin  //写入TLBIDX
        csr_tlbidx_ne <= csr_wdata[31] & csr_wmask[31] | csr_tlbidx_ne & ~csr_wmask[31];
    end
    else if(tlb_r_en)begin
        csr_tlbidx_ne <= ~tlb_r_e;
    end

end

//csr_tlbidx_rvalue write logic
assign csr_tlbidx_rvalue = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,8'b0,13'b0,csr_tlbidx_index};

//TLBEHI REG WRITE LOGIC
//csr_tlbehi_vppn write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(csr_we && csr_waddr==14'h11) begin  //写入TLBEHI
        csr_tlbehi_vppn <= csr_wdata[31:13] & csr_wmask[31:13] | csr_tlbehi_vppn & ~csr_wmask[31:13];
    end
    else if(wb_ex && (ecode == 6'h3f || ecode == 6'h01 || ecode == 6'h02 || ecode == 6'h03 || ecode == 6'h04 || ecode == 6'h07)) begin
        csr_tlbehi_vppn <= ws_addr[31:13];
    end
    else if(tlb_r_en)begin
        csr_tlbehi_vppn <= tlb_r_vppn & {19{tlb_r_e}};
    end
end

//csr_tlbehi_rvalue write logic
assign csr_tlbehi_rvalue = {csr_tlbehi_vppn,13'b0};

//TLBELO0 REG WRITE LOGIC
//csr_tlbelo0_v write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo0_v <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h12) begin  //写入TLBELO0
        csr_tlbelo0_v <= csr_wdata[0] & csr_wmask[0] | csr_tlbelo0_v & ~csr_wmask[0];
    end
    else if(tlb_r_en)begin
        csr_tlbelo0_v <= tlb_r_v0 & tlb_r_e;
    end
end

//csr_tlbelo0_d write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo0_d <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h12) begin  //写入TLBELO0
        csr_tlbelo0_d <= csr_wdata[1] & csr_wmask[1] | csr_tlbelo0_d & ~csr_wmask[1];
    end
    else if(tlb_r_en)begin
        csr_tlbelo0_d <= tlb_r_d0 & tlb_r_e;
    end
end

//csr_tlbelo0_plv write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo0_plv <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h12) begin  //写入TLBELO0
        csr_tlbelo0_plv <= csr_wdata[3:2] & csr_wmask[3:2] | csr_tlbelo0_plv & ~csr_wmask[3:2];
    end
    else if(tlb_r_en)begin
        csr_tlbelo0_plv <= tlb_r_plv0 & {2{tlb_r_e}};
    end
end

//csr_tlbelo0_mat write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo0_mat <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h12) begin  //写入TLBELO0
        csr_tlbelo0_mat <= csr_wdata[5:4] & csr_wmask[5:4] | csr_tlbelo0_mat & ~csr_wmask[5:4];
    end
    else if(tlb_r_en)begin
        csr_tlbelo0_mat <= tlb_r_mat0 & {2{tlb_r_e}};
    end
end

//csr_tlbelo0_g write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo0_g <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h12) begin  //写入TLBELO0
        csr_tlbelo0_g <= csr_wdata[6] & csr_wmask[6] | csr_tlbelo0_g & ~csr_wmask[6];
    end
    else if(tlb_r_en)begin
        csr_tlbelo0_g <= tlb_r_g & tlb_r_e;
    end
end

//csr_tlbelo0_ppn write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo0_ppn <= 20'b0;
    end
    else if(csr_we && csr_waddr==14'h12) begin  //写入TLBELO0
        csr_tlbelo0_ppn <= csr_wdata[27:8] & csr_wmask[27:8] | csr_tlbelo0_ppn & ~csr_wmask[27:8];
    end
    else if(tlb_r_en)begin
        csr_tlbelo0_ppn <= tlb_r_ppn0 & {20{tlb_r_e}};
    end
end

//csr_tlbelo0_rvalue write logic
assign csr_tlbelo0_rvalue = {4'b0,csr_tlbelo0_ppn,1'b0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};

//TLBELO1 REG WRITE LOGIC
//csr_tlbelo1_v write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo1_v <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h13) begin  //写入TLBELO1
        csr_tlbelo1_v <= csr_wdata[0] & csr_wmask[0] | csr_tlbelo1_v & ~csr_wmask[0];
    end
    else if(tlb_r_en)begin
        csr_tlbelo1_v <= tlb_r_v1 & tlb_r_e;
    end
end

//csr_tlbelo1_d write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo1_d <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h13) begin  //写入TLBELO1
        csr_tlbelo1_d <= csr_wdata[1] & csr_wmask[1] | csr_tlbelo1_d & ~csr_wmask[1];
    end
    else if(tlb_r_en)begin
        csr_tlbelo1_d <= tlb_r_d1 & tlb_r_e;
    end
end

//csr_tlbelo1_plv write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo1_plv <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h13) begin  //写入TLBELO1
        csr_tlbelo1_plv <= csr_wdata[3:2] & csr_wmask[3:2] | csr_tlbelo1_plv & ~csr_wmask[3:2];
    end
    else if(tlb_r_en)begin
        csr_tlbelo1_plv <= tlb_r_plv1 & {2{tlb_r_e}};
    end
end

//csr_tlbelo1_mat write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo1_mat <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h13) begin  //写入TLBELO1
        csr_tlbelo1_mat <= csr_wdata[5:4] & csr_wmask[5:4] | csr_tlbelo1_mat & ~csr_wmask[5:4];
    end
    else if(tlb_r_en)begin
        csr_tlbelo1_mat <= tlb_r_mat1 & {2{tlb_r_e}};
    end
end

//csr_tlbelo1_g write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo1_g <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h13) begin  //写入TLBELO1
        csr_tlbelo1_g <= csr_wdata[6] & csr_wmask[6] | csr_tlbelo1_g & ~csr_wmask[6];
    end
    else if(tlb_r_en)begin
        csr_tlbelo1_g <= tlb_r_g & tlb_r_e;
    end
end

//csr_tlbelo1_ppn write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbelo1_ppn <= 20'b0;
    end
    else if(csr_we && csr_waddr==14'h13) begin  //写入TLBELO1
        csr_tlbelo1_ppn <= csr_wdata[27:8] & csr_wmask[27:8] | csr_tlbelo1_ppn & ~csr_wmask[27:8];
    end
    else if(tlb_r_en)begin
        csr_tlbelo1_ppn <= tlb_r_ppn1 & {20{tlb_r_e}};
    end
end

//csr_tlbelo1_rvalue write logic
assign csr_tlbelo1_rvalue = {4'b0,csr_tlbelo1_ppn,1'b0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};

//ASID REG WRITE LOGIC
//csr_asid_asid write logic
always @(posedge clk) begin
    if(reset)begin
        csr_asid_asid <= 10'b0;
    end
    else if(csr_we && csr_waddr==14'h18) begin  //写入ASID
        csr_asid_asid <= csr_wdata[9:0] & csr_wmask[9:0] | csr_asid_asid & ~csr_wmask[9:0];
    end
    else if(tlb_r_en)begin
        csr_asid_asid <= tlb_r_asid & {10{tlb_r_e}};
    end
end

//csr_asid_asidbits write logic
always @(posedge clk) begin
    if(reset)begin
        csr_asid_asidbits <= 8'ha;
    end
end

//csr_asid_rvalue write logic
assign csr_asid_rvalue = {8'b0,csr_asid_asidbits,6'b0,csr_asid_asid};

//PGDL REG WRITE LOGIC
always @(posedge clk) begin
    if (csr_we && csr_waddr==14'h19) begin
        csr_pgdl_base <= csr_wdata[31:12];
    end
end

assign csr_pgdl_rvalue = {csr_pgdl_base,12'b0};

//PGDH REG WRITE LOGIC
always @(posedge clk) begin
    if (csr_we && csr_waddr==14'h1a) begin
        csr_pgdh_base <= csr_wdata[31:12];
    end
end

assign csr_pgdh_rvalue = {csr_pgdh_base,12'b0};

//PGD WRITE LOGIC
assign csr_pgd_rvalue = csr_badv_rvalue[31] ? csr_pgdh_rvalue : csr_pgdl_rvalue;

//TLBRENTRY REG WRITE LOGIC
//csr_tlbrentry_pa write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tlbrentry_pa <= 26'b0;
    end
    else if(csr_we && csr_waddr==14'h88) begin  //写入TLBRENTRY
        csr_tlbrentry_pa <= csr_wdata[31:6] & csr_wmask[31:6] | csr_tlbrentry_pa & ~csr_wmask[31:6];
    end
end

//csr_tlbrentry_rvalue write logic
assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa,6'b0};

//SAVE REG WRITE LOGIC
//csr_save write logic
always @(posedge clk) begin
    if(reset)begin
        csr_save[0] <= 32'b0;
        csr_save[1] <= 32'b0;
        csr_save[2] <= 32'b0;
        csr_save[3] <= 32'b0;
    end
    else if(csr_we && csr_waddr>=14'h30 && csr_waddr<=14'h33) begin  //写入SAVE
        case(csr_waddr)
            14'h30: csr_save[0] <= csr_wdata & csr_wmask | csr_save[0] & ~csr_wmask;
            14'h31: csr_save[1] <= csr_wdata & csr_wmask | csr_save[1] & ~csr_wmask;
            14'h32: csr_save[2] <= csr_wdata & csr_wmask | csr_save[2] & ~csr_wmask;
            14'h33: csr_save[3] <= csr_wdata & csr_wmask | csr_save[3] & ~csr_wmask;
        endcase
    end
end

//csr_save_rvalue write logic
assign csr_save_rvalue[0] = csr_save[0];
assign csr_save_rvalue[1] = csr_save[1];
assign csr_save_rvalue[2] = csr_save[2];
assign csr_save_rvalue[3] = csr_save[3];

//TID REG WRITE LOGIC
//csr_tid write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tid <= 32'b0;
    end
    else if(csr_we && csr_waddr==14'h40) begin  //写入TID
        csr_tid <= csr_wdata & csr_wmask | csr_tid & ~csr_wmask;
    end
end

//csr_tid_rvalue write logic
assign csr_tid_rvalue = csr_tid;

//TCFG REG WRITE LOGIC
//csr_tcfg_en write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tcfg_en <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h41) begin  
        csr_tcfg_en <= csr_wdata[0] & csr_wmask[0] | csr_tcfg_en & ~csr_wmask[0];
    end
end

//csr_tcfg_periodic write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tcfg_periodic <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h41) begin  
        csr_tcfg_periodic <= csr_wdata[1] & csr_wmask[1] | csr_tcfg_periodic & ~csr_wmask[1];
    end
end

//csr_tcfg_initval write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tcfg_initval <= 30'b0;
    end
    else if(csr_we && csr_waddr==14'h41) begin  
        csr_tcfg_initval <= csr_wdata[31:2] & csr_wmask[31:2] | csr_tcfg_initval & ~csr_wmask[31:2];
    end
end

//csr_tcfg_rvalue write logic
assign csr_tcfg_rvalue = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};

//TVAL REG WITRE LOGIC
//csr_tval_timeval write logic
always @(posedge clk) begin
    if(reset)begin
        csr_tval_timeval <= 32'b0;
    end
    else if(csr_we && csr_waddr==14'h41) begin  
        csr_tval_timeval <= {{csr_wdata[31:2] & csr_wmask[31:2] | csr_tval_timeval & ~csr_wmask[31:2]},{2{1'b0}}};
    end
    else if(csr_tcfg_en == 1'b1 || (csr_we && csr_waddr==14'h41 && csr_wdata[0] == 1'b1)) begin //开始倒计时
        if(csr_tval_timeval != 32'b0) begin //还未减到0
            csr_tval_timeval <= csr_tval_timeval - 1'b1;
        end
        else begin
            if(csr_tcfg_periodic == 1'b1) begin
                csr_tval_timeval <= {csr_tcfg_initval,{2{1'b0}}};
            end
        end

    end
end

assign csr_tval_rvalue = {csr_tval_timeval};

//TICLR REG WRITE LOGIC
//csr_ticlr_clr write logic
always @(posedge clk) begin
    if(reset)begin
        csr_ticlr_clr <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h44) begin  
        csr_ticlr_clr <= csr_wdata[0] & csr_wmask[0] | csr_ticlr_clr & ~csr_wmask[0];
    end
    else if(csr_tval_timeval != 32'h0) begin
        csr_ticlr_clr <= 1'b0;
    end
end

assign csr_ticlr_rvalue = 32'b0;

//LLBCTl
always @(posedge clk) begin
    if(reset) begin
        csr_llbctl_klo <= 1'b0;
        csr_llbctl_r0 <= 29'b0;
        csr_llbctl_wcllb <= 1'b0;
        llbit <= 1'b0;
    end
    else if(ertn_op) begin
        if(csr_llbctl_klo) csr_llbctl_klo <= 1'b0;
        else begin
        llbit <= 1'b0;
        end
    end
    else if (csr_we && csr_waddr==14'h60) begin 
        csr_llbctl_klo <= csr_wdata[2];
        if (csr_wdata[1] == 1'b1) begin
            llbit <= 1'b0;
        end
    end
    else if (llbit_set_in) begin
        llbit <= llbit_in;
    end
end

assign ds_llbit = llbit;
assign csr_llbctl_rvalue = {csr_llbctl_r0,csr_llbctl_klo,csr_llbctl_wcllb,csr_llbctl_rollb};

//DMW0 REG WRITE LOGIC
//csr_dmw0_plv0 write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw0_plv0 <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h180) begin  
        csr_dmw0_plv0 <= csr_wdata[0] & csr_wmask[0] | csr_dmw0_plv0 & ~csr_wmask[0];
    end
end

//csr_dmw0_plv3 write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw0_plv3 <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h180) begin  
        csr_dmw0_plv3 <= csr_wdata[3] & csr_wmask[3] | csr_dmw0_plv3 & ~csr_wmask[3];
    end
end

//csr_dmw0_mat write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw0_mat <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h180) begin  
        csr_dmw0_mat <= csr_wdata[5:4] & csr_wmask[5:4] | csr_dmw0_mat & ~csr_wmask[5:4];
    end
end

//csr_dmw0_pseg write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw0_pseg <= 3'b0;
    end
    else if(csr_we && csr_waddr==14'h180) begin  
        csr_dmw0_pseg <= csr_wdata[27:25] & csr_wmask[27:25] | csr_dmw0_pseg & ~csr_wmask[27:25];
    end
end

//csr_dmw0_vseg write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw0_vseg <= 3'b0;
    end
    else if(csr_we && csr_waddr==14'h180) begin  
        csr_dmw0_vseg <= csr_wdata[31:29] & csr_wmask[31:29] | csr_dmw0_vseg & ~csr_wmask[31:29];
    end
end

//csr_dmw0_rvalue write logic
assign csr_dmw0_rvalue = {csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0};

//DMW1 REG WRITE LOGIC
//csr_dmw1_plv0 write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw1_plv0 <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h181) begin  
        csr_dmw1_plv0 <= csr_wdata[0] & csr_wmask[0] | csr_dmw1_plv0 & ~csr_wmask[0];
    end
end

//csr_dmw1_plv3 write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw1_plv3 <= 1'b0;
    end
    else if(csr_we && csr_waddr==14'h181) begin  
        csr_dmw1_plv3 <= csr_wdata[3] & csr_wmask[3] | csr_dmw1_plv3 & ~csr_wmask[3];
    end
end

//csr_dmw1_mat write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw1_mat <= 2'b0;
    end
    else if(csr_we && csr_waddr==14'h181) begin  
        csr_dmw1_mat <= csr_wdata[5:4] & csr_wmask[5:4] | csr_dmw1_mat & ~csr_wmask[5:4];
    end
end

//csr_dmw1_pseg write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw1_pseg <= 3'b0;
    end
    else if(csr_we && csr_waddr==14'h181) begin  
        csr_dmw1_pseg <= csr_wdata[27:25] & csr_wmask[27:25] | csr_dmw1_pseg & ~csr_wmask[27:25];
    end
end

//csr_dmw1_vseg write logic
always @(posedge clk) begin
    if(reset)begin
        csr_dmw1_vseg <= 3'b0;
    end
    else if(csr_we && csr_waddr==14'h181) begin  
        csr_dmw1_vseg <= csr_wdata[31:29] & csr_wmask[31:29] | csr_dmw1_vseg & ~csr_wmask[31:29];
    end
end

//csr_dmw1_rvalue write logic
assign csr_dmw1_rvalue = {csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0};


//----------------------------REG_READ----------------------------
assign csr_rdata1 = (csr_raddr1==14'b0) ? csr_crmd_rvalue :
                    (csr_raddr1==14'b1) ? csr_prmd_rvalue :
                    (csr_raddr1==14'h4) ? csr_ecfg_rvalue :
                    (csr_raddr1==14'h5) ? csr_estat_rvalue:
                    (csr_raddr1==14'h6) ? csr_era_rvalue  :
                    (csr_raddr1==14'h7) ? csr_badv_rvalue :
                    (csr_raddr1==14'hc) ? csr_eentry_rvalue :
                    (csr_raddr1==14'h10)? csr_tlbidx_rvalue:
                    (csr_raddr1==14'h11)? csr_tlbehi_rvalue:
                    (csr_raddr1==14'h12)? csr_tlbelo0_rvalue:
                    (csr_raddr1==14'h13)? csr_tlbelo1_rvalue:
                    (csr_raddr1==14'h18)? csr_asid_rvalue :
                    (csr_raddr1==14'h19)? csr_pgdl_rvalue :
                    (csr_raddr1==14'h1a)? csr_pgdh_rvalue :
                    (csr_raddr1==14'h1b)? csr_pgd_rvalue :
                    (csr_raddr1>=14'h30 && csr_raddr1<=14'h33) ? csr_save_rvalue[csr_raddr1[1:0]] :
                    (csr_raddr1==14'h40)? csr_tid_rvalue  :
                    (csr_raddr1==14'h41)? csr_tcfg_rvalue :
                    (csr_raddr1==14'h42)? csr_tval_rvalue :
                    (csr_raddr1==14'h44)? csr_ticlr_rvalue:
                    (csr_raddr1==14'h60)? {csr_llbctl_rvalue[31:1],llbit}:
                    (csr_raddr1==14'h88)? csr_tlbrentry_rvalue:
                    (csr_raddr1==14'h180)? csr_dmw0_rvalue:
                    (csr_raddr1==14'h181)? csr_dmw1_rvalue:
                    32'b0;    

assign crmd_da  = csr_crmd_da;
assign crmd_pg  = csr_crmd_pg;
assign crmd_plv = csr_crmd_plv;
assign crmd_datf= csr_crmd_datf;
assign crmd_datm= csr_crmd_datm;

//----------------------------TLB LOGIC----------------------------
//tlbwr
assign tlb_w_index = csr_tlbidx_index;
assign tlb_w_ps    = csr_tlbidx_ps   ; 
assign tlb_w_e     = csr_estat_ecode == 6'h3f ? 1'b1 : ~csr_tlbidx_ne  ;
assign tlb_w_vppn  = csr_tlbehi_vppn ;
assign tlb_w_g     = csr_tlbelo0_g & csr_tlbelo1_g;
assign tlb_w_v0    = csr_tlbelo0_v   ;
assign tlb_w_d0    = csr_tlbelo0_d   ;
assign tlb_w_plv0  = csr_tlbelo0_plv ;
assign tlb_w_mat0  = csr_tlbelo0_mat ;
assign tlb_w_ppn0  = csr_tlbelo0_ppn ;
assign tlb_w_v1    = csr_tlbelo1_v   ;
assign tlb_w_d1    = csr_tlbelo1_d   ;
assign tlb_w_plv1  = csr_tlbelo1_plv ;
assign tlb_w_mat1  = csr_tlbelo1_mat ;
assign tlb_w_ppn1  = csr_tlbelo1_ppn ;
assign tlb_w_asid  = csr_asid_asid   ;

//tlbrd
assign tlb_r_index = csr_tlbidx_index;


assign csr_eentry_addr = csr_eentry_rvalue;
assign csr_era_addr    = csr_era_rvalue   ;
assign ex_entry        = ((ecode == 6'h3f && wb_ex) || (csr_estat_ecode == 6'h3f && !wb_ex)) ? csr_tlbrentry_rvalue : csr_eentry_rvalue;

assign has_int = (({csr_ecfg_lie_2,csr_ecfg_lie_1}  & {csr_estat_is_ipi,csr_estat_is_timer,csr_estat_is_h,csr_estat_is_s}) != 12'b0) && csr_crmd_ie;
assign timer_id = csr_tid_rvalue;

//dmw_rd
assign dmw0_plv0 = csr_dmw0_plv0;
assign dmw0_plv3 = csr_dmw0_plv3;
assign dmw0_mat  = csr_dmw0_mat ;
assign dmw0_pseg = csr_dmw0_pseg;
assign dmw0_vseg = csr_dmw0_vseg;
assign dmw1_plv0 = csr_dmw1_plv0;
assign dmw1_plv3 = csr_dmw1_plv3;
assign dmw1_mat  = csr_dmw1_mat ;
assign dmw1_pseg = csr_dmw1_pseg;
assign dmw1_vseg = csr_dmw1_vseg;

// difftest
assign csr_crmd_diff        = csr_crmd_rvalue;
assign csr_prmd_diff        = csr_prmd_rvalue;
assign csr_ectl_diff        = csr_ecfg_rvalue;
assign csr_estat_diff       = csr_estat_rvalue;
assign csr_era_diff         = csr_era_rvalue;
assign csr_badv_diff        = csr_badv_rvalue;
assign csr_eentry_diff      = csr_eentry_rvalue;
assign csr_tlbidx_diff      = csr_tlbidx_rvalue;
assign csr_tlbehi_diff      = csr_tlbehi_rvalue;
assign csr_tlbelo0_diff     = csr_tlbelo0_rvalue;
assign csr_tlbelo1_diff     = csr_tlbelo1_rvalue;
assign csr_asid_diff        = csr_asid_rvalue;
assign csr_save0_diff       = csr_save_rvalue[0];
assign csr_save1_diff       = csr_save_rvalue[1];
assign csr_save2_diff       = csr_save_rvalue[2];
assign csr_save3_diff       = csr_save_rvalue[3];
assign csr_tid_diff         = csr_tid_rvalue;
assign csr_tcfg_diff        = csr_tcfg_rvalue;
assign csr_tval_diff        = csr_tval_rvalue;
assign csr_ticlr_diff       = csr_ticlr_rvalue;
assign csr_llbctl_diff      = {csr_llbctl_rvalue[31:1], llbit};
assign csr_tlbrentry_diff   = csr_tlbrentry_rvalue;
assign csr_dmw0_diff        = csr_dmw0_rvalue;
assign csr_dmw1_diff        = csr_dmw1_rvalue;
assign csr_pgdl_diff        = csr_pgdl_rvalue;
assign csr_pgdh_diff        = csr_pgdh_rvalue;

endmodule
