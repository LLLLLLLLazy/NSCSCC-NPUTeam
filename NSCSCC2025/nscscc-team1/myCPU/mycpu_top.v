module core_top
#(
    parameter TLBNUM =32
)
(
    input  wire        aclk,
    input  wire        aresetn,  // low active

    // AXI Read Address Channel
    output wire [3:0]  arid,
    output wire [31:0] araddr,
    output wire [7:0]  arlen,
    output wire [2:0]  arsize,
    output wire [1:0]  arburst,
    output wire [1:0]  arlock,
    output wire [3:0]  arcache,
    output wire [2:0]  arprot,
    output wire        arvalid,
    input  wire        arready,

    input wire [7:0] intrpt,

    // AXI Read Data Channel
    input  wire [3:0]  rid,
    input  wire [31:0] rdata,
    input  wire [1:0]  rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    // AXI Write Address Channel
    output wire [3:0]  awid,
    output wire [31:0] awaddr,
    output wire [7:0]  awlen,
    output wire [2:0]  awsize,
    output wire [1:0]  awburst,
    output wire [1:0]  awlock,
    output wire [3:0]  awcache,
    output wire [2:0]  awprot,
    output wire        awvalid,
    input  wire        awready,

    // AXI Write Data Channel
    output wire [3:0]  wid,
    output wire [31:0] wdata,
    output wire [3:0]  wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    // AXI Write Response Channel
    input  wire [3:0]  bid,
    input  wire [1:0]  bresp,
    input  wire        bvalid,
    output wire        bready,

    // trace debug interface
    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata,
    output wire [31:0] debug0_wb_inst,

    input   wire        break_point,
    input   wire       infor_flag,
    input   wire [ 4:0]   reg_num,
    output  wire       ws_valid,
    output wire [31:0]   rf_rdata

);

    wire        inst_sram_req;
    wire        inst_sram_wr;
    wire [1:0]  inst_sram_size;
    wire [3:0]  inst_sram_wstrb;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    wire        inst_sram_data_ok;
    wire        inst_sram_addr_ok;
    wire [31:0] inst_sram_rdata;
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [1:0]  data_sram_size;
    wire [3:0]  data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_data_ok;
    wire        data_sram_addr_ok;
    wire [31:0] data_sram_rdata;
   // wire clk;

   // assign clk = aclk;


    assign inst_sram_wr=1'b0;
    assign inst_sram_size=2'd2;
    assign inst_sram_wdata=32'b0;
    assign inst_sram_wstrb=4'b0;
    assign inst_sram_req= if_allow_in & inst_req_valid & pc_inst_en & (~pipline_is_not_stalled==1'b0) & (!(inst_tlb_or_csr_we == 1'b1)) & (!(inst_cacop == 1'b1)) ;
  
    wire if_allow_in;
    wire id_allow_in;
    wire exe_allow_in;
    wire mem_allow_in;
    wire wb_allow_in;
    wire [31:0]csr_era_pc;
    wire rst;
    wire [31:0] pc_br_target;
    wire pc_br_taken;
    wire pc_inst_en;
    wire [31:0] if_pc;
    assign rst = ~aresetn;
    wire inst_req_valid;//1表示还没给inst_dram�? ? 请求�?1表示已经给inst_dram�? ? 请求，但还没有返�?
    wire wb_ready_go;
    wire if_ready_go;
    wire id_ready_go;
    wire exe_ready_go;
    wire mem_ready_go; 
    wire pre_if_ready_go;
    wire [1:0]id_need_cancel;          //下一条流入id_stage的指令需要取 ????
    //wire if_allow_in;
    wire pipline_is_not_stalled;
    wire id_inst_cancel;
    wire exe_addr_shake_ok;
    wire mem_data_shake_ok;
    wire IF_ready_go;
    wire ID_ready_go;
    wire EXE_ready_go;
    wire mem_need_and_data_ok;
    wire [4:0] rf_raddr1;
    wire [4:0] rf_raddr2;
    wire [31:0] rf_wdata;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] inst_addr;   // 经过TLB转换后的地址
    wire inst_dmw0_en;
    wire inst_dmw1_en;
    wire [1:0]inst_tlb_ex;
    wire if_tlb_or_csr_we;
    wire inst_tlb_or_csr_we;
    wire [1:0] if_inst_tlb_ex;
    wire if_inst_cacop;
    wire if_data_cacop;
    wire inst_cacop;
    wire wb_ex;//是否是异 ?????
    wire [31:0] csr_rvalue;
    wire wb_is_ertn;


    wire inst_uncache ;             //   ?1表示inst是不可缓存的，不�? ? 过cache访问 
    
    assign inst_tlb_ex = ((csr_crmd_da && csr_crmd_pg==1'b0)|| inst_dmw0_en || inst_dmw1_en) ? 2'h0 :
                         (tlb_s0_found == 1'b0)                                              ? 2'h1 :
                         (tlb_s0_v == 1'b0)                                                  ? 2'h2 :
                         (tlb_s0_plv < csr_crmd_plv)                                         ? 2'h3 : 2'h0;

     
                         
    assign inst_dmw0_en = csr_crmd_da == 1'b0 && csr_crmd_pg && ((csr_crmd_plv == 2'h3 && csr_dmw0_plv3)||(csr_crmd_plv == 2'h0 && csr_dmw0_plv0)) && inst_sram_addr[31:29] == csr_dmw0_vseg;
    assign inst_dmw1_en = csr_crmd_da == 1'b0 && csr_crmd_pg && ((csr_crmd_plv == 2'h3 && csr_dmw1_plv3)||(csr_crmd_plv == 2'h0 && csr_dmw1_plv0)) && inst_sram_addr[31:29] == csr_dmw1_vseg;
    assign inst_addr = (csr_crmd_da && csr_crmd_pg==1'b0) ?  inst_sram_addr :
                        inst_dmw0_en                       ?  {csr_dmw0_pseg,inst_sram_addr[28:0]} :
                        inst_dmw1_en                       ?  {csr_dmw1_pseg,inst_sram_addr[28:0]} :  {tlb_s0_ppn[19:0],inst_sram_addr[11:0]};

    assign inst_uncache = ( csr_crmd_da && csr_crmd_pg==1'b0 && csr_crmd_datf == 2'b0) ||  
                         ( inst_dmw0_en && csr_dmw0_mat == 2'b0 )  ||
                         ( inst_dmw1_en && csr_dmw1_mat == 2'b0)  ||
                         ( csr_crmd_da == 1'b0 && csr_crmd_pg && inst_dmw0_en == 1'b0 && inst_dmw1_en == 1'b0 && tlb_r_mat0 == 2'b0);                 


                        
    
    PC_Reg pc_reg(
        .clk(aclk),
        .rst(rst),
        .if_allow_in(if_allow_in),
        .wb_ready_go(wb_ready_go),
        .pre_if_ready_go(pre_if_ready_go),
        .pipline_is_not_stalled(pipline_is_not_stalled),
        .if_pc(if_pc),
        .wb_ex(wb_ex),
        .inst_en(pc_inst_en),
        .pc_br_taken(pc_br_taken),
        .pc_br_target(pc_br_target),
        .inst_addr(inst_sram_addr),
        .inst_tlb_ex(inst_tlb_ex),
        .if_inst_tlb_ex(if_inst_tlb_ex),
        .id_ready_go(id_ready_go),
        .exe_allow_in(exe_allow_in)
    );

  
    assign if_tlb_or_csr_we =  (if_inst[31:24] == 8'h4  &&  if_inst[9:5] != 5'b0 ) ||
                            (if_inst[31:13] == 29'b0000011001001000001 || if_inst[31:15]==17'b00000110010010011);

    

    assign inst_tlb_or_csr_we = (if_tlb_or_csr_we && id_need_cancel != 2'b0) | id_tlb_or_csr_we | exe_tlb_or_csr_we | mem_tlb_or_csr_we | wb_tlb_or_csr_we ;
    assign inst_cacop = (if_inst_cacop && id_need_cancel != 2'b0) | (id_inst_cacop && ID_need_cancel == 1'b0) | (exe_inst_cacop && exe_need_cancel == 1'b0)
    | (mem_inst_cacop && mem_need_cancel == 1'b0) | (wb_inst_cacop && wb_need_cancel == 1'b0) ;
    assign if_inst_cacop = if_inst[31:22] == 10'b0000011000 && (if_inst[2:0] == 3'b0 || if_inst[2:0] == 3'h2); 
    assign if_data_cacop = if_inst[31:22] == 10'b0000011000 && (if_inst[2:0] == 3'b1 || if_inst[2:0] == 3'h2); 


    wire [31:0] id_inst;
    wire [31:0] id_pc;
    wire [31:0] if_inst;
    wire ID_need_cancel;
    wire [1:0] id_inst_tlb_ex;
    wire id_inst_cacop;
    wire id_data_cacop;
    ID_Reg id_reg(
        .clk(aclk),
        .rst(rst),
        .wb_is_ertn(wb_is_ertn),
        .if_ready_go(if_ready_go),
        .exe_allow_in(exe_allow_in),
        .exe_addr_shake_ok(exe_addr_shake_ok),
        .exe_data_ram_req(data_sram_req),
        .exe_data_ram_addr_ok(data_sram_addr_ok),
        .id_inst_cancel(id_inst_cancel),
        .pipline_is_not_stalled(pipline_is_not_stalled),
        .id_allow_in(id_allow_in),
        .id_need_cancel(id_need_cancel),
        .if_pc(if_pc),
        .if_inst(if_inst),
        .id_inst(id_inst),
        .id_pc(id_pc),
        .wb_ex(wb_ex),
        .ID_need_cancel(ID_need_cancel),
        .if_inst_tlb_ex(if_inst_tlb_ex),
        .id_inst_tlb_ex(id_inst_tlb_ex),
        .if_inst_cacop(if_inst_cacop),
        .if_data_cacop(if_data_cacop),
        .id_inst_cacop(id_inst_cacop),
        .id_data_cacop(id_data_cacop)
    );
    reg [31:0] inst_sram_rdata_reg;
    assign if_inst = inst_sram_rdata_reg;

    always @(*) begin
         inst_sram_rdata_reg = inst_sram_rdata;
    end

    wire [31:0]id_src1;
    wire [31:0]id_src2;
    wire id_ref_we;
    wire [4:0]id_alu_op;
    wire id_dram_we;
    wire id_dram_re;
    wire [4:0]id_rd;
    wire [4:0]id_rj;
    wire [4:0]id_rk;
    wire id_src2_is_imm12;
    wire [11:0]id_imm12;
    wire [4:0]id_imm5;
    wire id_src2_is_imm5;
    wire id_src2_is_rd;
    wire [15:0] id_imm16;
    wire [25:0] id_imm26;
    wire id_src2_is_imm26;
    wire id_src2_is_imm16;
    wire id_res_from_dram;
    wire [31:0] id_dram_wdata;
    wire [19:0] id_imm20;
    wire id_src2_is_imm20;
   // wire id_cancel;   //跳转的话，需要置 ????????1
    wire id_br_taken;
    wire [31:0]id_br_target;
    wire id_src1_from_ref;
    wire id_src2_from_ref;
    wire id_zero_extend; //如果第二个操作数是立即数�? ? �? ?????要零扩展，是的话 ?????1，否则的话为0
    wire id_rdram_need_zero_extend;
    wire id_rdram_need_signed_extend;
    wire [1:0]id_rdram_num; //如果是ld类指令，ld.w ?????0，ld.b,ld.bu ?????1，ld.h,ld.hu ?????2
    wire [1:0]id_wdram_num; //如果是st类指令，st.w ?????0，ld.b,ld.bu ?????1，ld.h,ld.hu ?????2

    wire [13:0] id_csr_num;
    wire id_csr_we;
    wire id_is_ertn;
    wire id_is_syscall;
    wire id_res_from_csr;
    wire [31:0]id_csr_wdata;
    wire [31:0]id_csr_wmask;
    wire id_csr_mask_all_one;
    wire id_ex_adef;
    wire id_ex_brk;
    wire id_ex_ine;
    wire id_ex_ale_h;
    wire id_ex_ale_w;
    wire id_has_int;
    wire [31:0] csr_tid_tid;
    wire [63:0] csr_timer_64;
    wire [31:0] id_res_of_cnt;
    wire id_res_from_cnt;
    //wire [31:0]id_csr_rdata;
    wire id_res_from_tid;
    wire id_need_data_sram;
    wire id_inst_tlbrd;
    wire id_tlb_we;
    wire id_inst_tlbsrch;
    wire id_tlb_wr_en;
    wire id_tlb_fill_en;
    wire id_invtlb_valid;
    wire [4:0]id_invtlb_op;
    wire [9:0]id_invtlb_asid;
    wire [18:0]id_invtlb_va;
    wire id_is_st;
    wire id_is_ld;
    wire id_tlb_or_csr_we;
    wire id_res_is_rj;

    wire id_icache_v_we;
    wire id_dcache_v_we;
    wire id_icache_tag_we;
    wire id_dcache_tag_we;
    wire [31:0] id_cacop_va;
    wire id_cacop_need_phy ;
    wire id_cacop_en;


    wire id_inst_cnt;
    wire [63:0]id_timer_64;
    wire [7:0]id_inst_ld_en;
    wire [7:0]id_inst_st_en;
    wire id_csr_rstat_en;
    wire [31:0]id_csr_data;

    wire id_inst_cpucfg;
    wire [31:0]id_cpucfg_result;

    wire [12:0] csr_estat_is;
    wire [12:0] csr_ecfg_lie;
    wire csr_crmd_ie;
    

    ID_stage id_stage (
        .id_inst(id_inst),    //Input:输入的指 ?????
        .id_pc(id_pc),        //Input:当前指令的pc
        .csr_estat_is(csr_estat_is),       //新增
        .csr_ecfg_lie(csr_ecfg_lie),       //新增
        .csr_crmd_ie(csr_crmd_ie),         //新增
        .csr_timer_64(csr_timer_64),       //新增 ?????64位计数器的数 ?????
        .csr_tid_tid(csr_tid_tid),         //新增 ?????64位计数器的编 ?????
        .id_rj(id_rj),        //output：寄存器rj的地 ?????
        .id_rk(id_rk),        //output：rk的地 ?????
        .id_rd(id_rd),        //output：rd的地 ?????，记得指令为bl时将id_rd设置 ?????1(已实 ?????)
        .id_rf_rdata1(rf_rdata1),     //Input：从寄存器读到的源操作数1 ?????
        .id_rf_rdata2(rf_rdata2),     //Input:从寄存器读到的源操作 ?????2,
        .id_ref_we(id_ref_we),        //Output:是否 ?????要写寄存 ?????
        .id_alu_op(id_alu_op),        //Output:alu的op信号，对照表在word ?????
        .id_dram_we(id_dram_we),      //Output(下边的都是output):是否 ?????要写dram
        .id_dram_re(id_dram_re),      //是否 ?????要读dram
        .id_src2_is_imm12(id_src2_is_imm12),         //以下为立即数的控制信 ?????
        .id_imm12(id_imm12),
        .id_imm5(id_imm5),
        .id_src2_is_imm5(id_src2_is_imm5),
        .id_src2_is_rd(id_src2_is_rd),
        .id_imm16(id_imm16),
        .id_imm26(id_imm26),
        .id_src2_is_imm26(id_src2_is_imm26),
        .id_src2_is_imm16(id_src2_is_imm16),
        .id_res_from_dram(id_res_from_dram),
        .id_src2_is_imm20(id_src2_is_imm20),
        .id_imm20(id_imm20),      
        .id_br_taken(id_br_taken),                //是否 ?????要跳 ?????
        .id_br_target(id_br_target),              //跳转的地 ?????，（由于流水线要处理冒险，故我把跳转模块从exe_stage挪到了id_stage ?????)
        .id_src1_from_ref(id_src1_from_ref),      // ?????1个源操作数是否来自寄存器堆，
        .id_src2_from_ref(id_src2_from_ref),      // ?????2个源操作数是否来自寄存器堆，这个和id_src1_from_ref的生成方法要看下"exp8-9"word,
        .id_zero_extend(id_zero_extend),          //src2是立即数的话，是 ?????要符号扩展还是零扩展，零扩展的话 ?????1
        .id_rdram_need_zero_extend(id_rdram_need_zero_extend),
        .id_rdram_need_signed_extend(id_rdram_need_signed_extend),  // ?????3个信号是ld类指令， ?????要将dada_ram数据写入寄存器堆时，对data_ram中读到的数据的处理信 ?????
        .id_rdram_num(id_rdram_num),             //如果是ld类指令，ld.w ?????0，ld.b,ld.bu ?????1，ld.h,ld.hu ?????2
        .id_wdram_num(id_wdram_num),              //如果是st类指令，st.w ?????0，ld.b,ld.bu ?????1，ld.h,ld.hu ?????2
        .id_csr_rdata(csr_rvalue),
        .id_csr_num(id_csr_num),                   //csr读地 ?????�? ? 写地�?
        .id_csr_we(id_csr_we),                     //csr写使 ?????
        .id_is_ertn(id_is_ertn) ,                 //是否是ertn
        .id_is_syscall(id_is_syscall) ,           //是否是系统调用异 ?????
        .id_res_from_csr(id_res_from_csr),     //与id_res_from_dram类似，这里最后要写回通用寄存器的数据可能来自csr寄存器，是的话置1
        .id_csr_mask_all_one(id_csr_mask_all_one),       //csrxchg指令 ?????0，其余是1
        .id_ex_adef(id_ex_adef),                         // ?????测取指令的地 ?????错了没？即最低两位不 ?????00的话�? ? �?1
        .id_ex_brk(id_ex_brk),                          //与syscall指令类似，只要译码出来是break指令，就 ?????1
        .id_ex_ine(id_ex_ine),                           //指令地址虽然正确，但取出来的指令不存 ?????,不是任何 ?????条指 ?????
        .id_ex_ale_h(id_ex_ale_h),                       //ld.h,ld.hu,st.h时置1
        .id_ex_ale_w(id_ex_ale_w),                      // ld.w,st.w时置1，这两条信号是为了方便之后exe级检测地 ?????不对齐异 ?????
        .id_has_int(id_has_int),                       // ?????测中断，在书 ?????7.2.1节有示例，注意前边多 ?????3个来自csr的输入信号需要补 ?????
        .id_res_is_rj(id_res_is_rj),                   //只对应rdcntid指令，写寄存器的地址是rj
        .id_res_of_cnt(id_res_of_cnt),                  //对应三个将counter64相关数据写入寄存器的指令，如果是那三个指令，就输出要写入寄存器堆的数 ?????
        .id_res_from_cnt(id_res_from_cnt),              //对应上边三个指令时为1
        .id_res_from_tid(id_res_from_tid),
        .id_need_data_sram(id_need_data_sram) ,         //对应load,store类指 ????
        .id_inst_tlbrd(id_inst_tlbrd),                    //表示是tlbrd指令
        .id_tlb_we(id_tlb_we),                            //tlb的写使能
        .id_invtlb_op(id_invtlb_op),            //invtlb指令的op ???
        .id_invtlb_valid(id_invtlb_valid),              //invtlb指令有效
        .id_inst_tlbsrch(id_inst_tlbsrch),                //表示是inst_tlbsrch指令
        .id_tlb_wr_en(id_tlb_wr_en),
        .id_tlb_fill_en(id_tlb_fill_en),
        .id_is_st(id_is_st),
        .id_is_ld(id_is_ld),
        .id_tlb_or_csr_we(id_tlb_or_csr_we),
        .id_icache_v_we(id_icache_v_we),
        .id_dcache_v_we(id_dcache_v_we),
        .id_dcache_tag_we(id_dcache_tag_we),
        .id_icache_tag_we(id_icache_tag_we),
        .id_cacop_va(id_cacop_va),
        .id_cacop_need_phy(id_cacop_need_phy),
        .id_cacop_en(id_cacop_en),
        .id_inst_cnt(id_inst_cnt),
        .id_timer_64(id_timer_64),
        .id_inst_ld_en(id_inst_ld_en),
        .id_inst_st_en(id_inst_st_en),
        .id_csr_rstat_en(id_csr_rstat_en),
        .id_csr_data(id_csr_data)  ,
        .id_inst_cpucfg(id_inst_cpucfg),
        .id_cpucfg_result(id_cpucfg_result)  
    );

    assign id_dram_wdata =id_src2;
    assign pc_br_taken= id_br_taken |(wb_ex==1'b1)|(wb_is_ertn==1'b1);
    //assign pc_br_target=id_br_target|({32{wb_ex==1'b1}}&csr_rvalue)|({32{wb_is_ertn==1'b1}}&csr_era_pc);
    assign pc_br_target =    wb_is_ertn==1'b1  ?   csr_era_pc  :  
                            (csr_data_tlb_refill || csr_inst_tlb_refill || csr_cacop_tlb_refill) ? {csr_tlbrentry, 6'b0}  :
                            wb_ex==1'b1      ?   csr_rvalue  :  id_br_target;
    assign id_csr_wdata=id_src2;
    assign id_csr_wmask = id_csr_mask_all_one? 32'hffffffff : id_src1;
    assign id_invtlb_asid = rf_rdata1[9:0];
    assign id_invtlb_va = rf_rdata2[31:13];
    //assign id_csr_rdata=csr_rvalue;

    wire [31:0]exe_src1;
    wire [4:0]exe_rd;
    wire [31:0]exe_src2;
    wire exe_ref_we;
    wire [4:0]exe_alu_op;
    wire exe_dram_we;
    wire exe_dram_re;
    wire [11:0] exe_imm12;
    wire exe_src2_is_imm12;
    wire [4:0] exe_imm5;
    wire exe_src2_is_imm5;
    wire [31:0] exe_pc;
    wire [15:0] exe_imm16;
    wire exe_src2_is_imm26;
    wire [25:0]exe_imm26;
    wire exe_src2_is_imm16;
    wire exe_res_from_dram;
    wire [31:0] exe_dram_wdata;
    wire [19:0] exe_imm20;
    wire exe_src2_is_imm20;
    wire [31:0] exe_dram_waddr;
    wire [31:0] exe_rf_src1;
    wire [31:0] exe_rf_src2;
    wire exe_zero_extend;
    wire exe_rdram_need_zero_extend;
    wire exe_rdram_need_signed_extend;
    wire [1:0]exe_rdram_num;
    wire [1:0]exe_wdram_num;

    wire [13:0] exe_csr_num;
    wire exe_csr_we;
    wire exe_is_ertn;
    wire exe_res_from_csr;
    wire [31:0] exe_csr_wmask;
    wire [31:0] exe_csr_wdata;
    wire exe_ex_ale_h;
    wire exe_ex_ale_w;
    wire exe_ex_ale;
    wire exe_ex_adef;
    wire exe_ex_brk;
    wire exe_ex_ine;
    wire exe_has_int;
    wire [4:0]exe_rj;
    wire [31:0]exe_res_of_cnt;
    wire exe_res_is_rj;
    wire exe_res_from_cnt;
    wire exe_res_from_tid;
    wire exe_need_data_sram;
    wire exe_need_cancel;
    wire exe_inst_tlbrd;
    wire exe_inst_tlbsrch;
    wire exe_tlb_wr_en;
    wire exe_tlb_fill_en;
    wire exe_tlb_we;
    wire exe_invtlb_valid;
    wire [4:0]exe_invtlb_op;
    wire [9:0]exe_invtlb_asid;
    wire [18:0]exe_invtlb_va;
    wire exe_div_is_doing;
    wire exe_is_st;
    wire exe_is_ld;
    wire exe_tlb_or_csr_we;
    wire [1:0]exe_inst_tlb_ex;
    wire exe_is_sycall;

    wire exe_icache_v_we;
    wire exe_dcache_v_we;
    wire exe_icache_tag_we;
    wire exe_dcache_tag_we;
    wire [31:0] exe_cacop_va;
    wire exe_cacop_need_phy;
    wire exe_inst_cacop;
    wire exe_data_cacop;
    wire exe_cacop_en;
    wire [31:0] exe_inst;

    wire exe_inst_cnt;
    wire [63:0]exe_timer_64;
    wire [7:0]exe_inst_ld_en;
    wire [7:0]exe_inst_st_en;
    wire exe_csr_rstat_en;
    wire [31:0]exe_csr_data;

    wire exe_inst_cpucfg;
    wire [31:0]exe_cpucfg_result;
    


    
    //wire [31:0]exe_csr_rdata;
    ExE_reg exe_reg(
        .clk(aclk),
        .rst(rst),
        .wb_ex(wb_ex),
        .wb_is_ertn(wb_is_ertn),
        .exe_div_is_doing(exe_div_is_doing),
        .id_ready_go(id_ready_go),
        .exe_ready_go(exe_ready_go),
        .mem_allow_in(mem_allow_in),
        .exe_allow_in(exe_allow_in),
        .exe_addr_shake_ok(exe_addr_shake_ok),
        .mem_data_shake_ok(mem_data_shake_ok),
        .mem_need_and_data_ok(mem_need_and_data_ok),
        .id_rd(id_rd),
        .id_src1(id_src1),
        .id_src2(id_src2),
        .id_ref_we(id_ref_we),
        .id_alu_op(id_alu_op),
        .id_dram_re(id_dram_re),
        .id_dram_we(id_dram_we),
        .id_imm12(id_imm12),
        .id_src2_is_imm12(id_src2_is_imm12),
        .id_src2_is_imm5(id_src2_is_imm5),
        .id_imm5(id_imm5),
        .id_pc(id_pc),
        .id_imm16(id_imm16),
        .id_imm26(id_imm26),
        .id_src2_is_imm26(id_src2_is_imm26),
        .id_src2_is_imm16(id_src2_is_imm16),
        .id_res_from_dram(id_res_from_dram),
        .id_dram_wdata(id_dram_wdata),
        .id_imm20(id_imm20),
        .id_src2_is_imm20(id_src2_is_imm20),
        .id_zero_extend(id_zero_extend),
        .id_rdram_need_zero_extend(id_rdram_need_zero_extend),
        .id_rdram_need_signed_extend(id_rdram_need_signed_extend),
        .id_rdram_num(id_rdram_num),
        .id_wdram_num(id_wdram_num),
        .id_csr_num(id_csr_num),
        .id_csr_we(id_csr_we),
        .id_is_ertn(id_is_ertn),
        .id_is_syscall(id_is_syscall),
        .id_res_from_csr(id_res_from_csr),
        .id_csr_wmask(id_csr_wmask),
        .id_csr_wdata(id_csr_wdata),
        .id_ex_adef(id_ex_adef),                        
        .id_ex_brk(id_ex_brk),                         
        .id_ex_ine(id_ex_ine),                           
        .id_ex_ale_h(id_ex_ale_h),                       
        .id_ex_ale_w(id_ex_ale_w),
        .id_has_int(id_has_int),
        .id_rj(id_rj),
        .id_res_of_cnt(id_res_of_cnt),
        .id_res_is_rj(id_res_is_rj),
        .id_res_from_cnt(id_res_from_cnt),
        .id_res_from_tid(id_res_from_tid),
        .id_need_data_sram(id_need_data_sram),
        .id_need_cancel(ID_need_cancel),
        .id_inst_tlbrd(id_inst_tlbrd),
        .id_inst_tlbsrch(id_inst_tlbsrch),
        .id_tlb_wr_en(id_tlb_wr_en),
        .id_tlb_we(id_tlb_we),
        .id_tlb_fill_en(id_tlb_fill_en),
        .id_invtlb_asid(id_invtlb_asid),
        .id_invtlb_op(id_invtlb_op),
        .id_invtlb_va(id_invtlb_va),
        .id_invtlb_valid(id_invtlb_valid),
        .id_is_st(id_is_st),
        .id_is_ld(id_is_ld),
        .id_tlb_or_csr_we(id_tlb_or_csr_we),
        .id_inst_tlb_ex(id_inst_tlb_ex),
        .id_icache_v_we(id_icache_v_we),
        .id_dcache_v_we(id_dcache_v_we),
        .id_dcache_tag_we(id_dcache_tag_we),
        .id_icache_tag_we(id_icache_tag_we),
        .id_cacop_va(id_cacop_va),
        .id_cacop_need_phy(id_cacop_need_phy),
        .id_inst_cacop(id_inst_cacop),
        .id_data_cacop(id_data_cacop),
        .id_cacop_en(id_cacop_en),
        .id_inst(id_inst),
        .id_inst_cnt(id_inst_cnt),
        .id_timer_64(id_timer_64),
        .id_inst_ld_en(id_inst_ld_en),
        .id_inst_st_en(id_inst_st_en),
        .id_csr_rstat_en(id_csr_rstat_en),
        .id_csr_data(id_csr_data),
        .id_inst_cpucfg(id_inst_cpucfg),
        .id_cpucfg_result(id_cpucfg_result),
        //.id_csr_rdata(id_csr_rdata),
        .exe_rd(exe_rd),
        .exe_src1(exe_src1),
        .exe_src2(exe_src2),
        .exe_ref_we(exe_ref_we),
        .exe_alu_op(exe_alu_op),
        .exe_dram_re(exe_dram_re),
        .exe_dram_we(exe_dram_we),
        .exe_imm12(exe_imm12),
        .exe_src2_is_imm12(exe_src2_is_imm12),
        .exe_pc(exe_pc),
        .exe_imm16(exe_imm16),
        .exe_imm5(exe_imm5),
        .exe_src2_is_imm5(exe_src2_is_imm5),
        .exe_src2_is_imm26(exe_src2_is_imm26),
        .exe_imm26(exe_imm26),
        .exe_src2_is_imm16(exe_src2_is_imm16),
        .exe_res_from_dram(exe_res_from_dram),
        .exe_dram_wdata(exe_dram_wdata),
        .exe_imm20(exe_imm20),
        .exe_src2_is_imm20(exe_src2_is_imm20),
        .exe_rf_src1(exe_rf_src1),
        .exe_rf_src2(exe_rf_src2),
        .exe_zero_extend(exe_zero_extend),   
        .exe_rdram_need_zero_extend(exe_rdram_need_zero_extend),
        .exe_rdram_need_signed_extend(exe_rdram_need_signed_extend),
        .exe_rdram_num(exe_rdram_num),
        .exe_wdram_num(exe_wdram_num) ,
        .exe_csr_num(exe_csr_num),
        .exe_csr_we(exe_csr_we),
        .exe_is_ertn(exe_is_ertn),
        .exe_is_syscall(exe_is_sycall),
        .exe_res_from_csr(exe_res_from_csr),
        .exe_csr_wmask(exe_csr_wmask),
        .exe_csr_wdata(exe_csr_wdata),
        .exe_ex_adef(exe_ex_adef),                        
        .exe_ex_brk(exe_ex_brk),                         
        .exe_ex_ine(exe_ex_ine),                           
        .exe_ex_ale_h(exe_ex_ale_h),                       
        .exe_ex_ale_w(exe_ex_ale_w),
        .exe_has_int(exe_has_int),
        .exe_rj(exe_rj),
        .exe_res_of_cnt(exe_res_of_cnt),
        .exe_res_is_rj(exe_res_is_rj),
        .exe_res_from_cnt(exe_res_from_cnt),
        .exe_res_from_tid(exe_res_from_tid),
        .exe_need_data_sram(exe_need_data_sram),
        .exe_need_cancel(exe_need_cancel),
        .exe_inst_tlbrd(exe_inst_tlbrd),
        .exe_inst_tlbsrch(exe_inst_tlbsrch),
        .exe_tlb_we(exe_tlb_we),
        .exe_tlb_wr_en(exe_tlb_wr_en),
        .exe_tlb_fill_en(exe_tlb_fill_en),
        .exe_invtlb_asid(exe_invtlb_asid),
        .exe_invtlb_op(exe_invtlb_op),
        .exe_invtlb_va(exe_invtlb_va),
        .exe_invtlb_valid(exe_invtlb_valid),
        .exe_is_st(exe_is_st),
        .exe_is_ld(exe_is_ld),
        .exe_tlb_or_csr_we(exe_tlb_or_csr_we),
        .exe_inst_tlb_ex(exe_inst_tlb_ex),
        .exe_icache_v_we(exe_icache_v_we),
        .exe_dcache_v_we(exe_dcache_v_we),
        .exe_dcache_tag_we(exe_dcache_tag_we),
        .exe_icache_tag_we(exe_icache_tag_we),
        .exe_cacop_va(exe_cacop_va),
        .exe_cacop_need_phy(exe_cacop_need_phy),
        .exe_data_cacop(exe_data_cacop),
        .exe_inst_cacop(exe_inst_cacop),
        .exe_cacop_en(exe_cacop_en),
        .exe_inst(exe_inst),
        .exe_inst_cnt(exe_inst_cnt),
        .exe_timer_64(exe_timer_64),
        .exe_inst_ld_en(exe_inst_ld_en),
        .exe_inst_st_en(exe_inst_st_en),
        .exe_csr_rstat_en(exe_csr_rstat_en),
        .exe_csr_data(exe_csr_data),
        .exe_inst_cpucfg(exe_inst_cpucfg),
        .exe_cpucfg_result(exe_cpucfg_result)
        

        
    );

    wire [31:0] exe_alu_result;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0]exe_br_target;
    wire exe_br_taken;
    wire [17:0]exe_imm16_extend;
    wire [27:0]exe_imm26_extend;
    assign exe_imm16_extend={exe_imm16,2'b00};
    assign exe_imm26_extend={exe_imm26,2'b00};
    wire div_divsigned;
    wire div_completed;
    wire div_en;
    wire [31:0] div_result;
    wire [31:0] div_rest;
    wire [31:0] exe_alu_ret;

    
    assign alu_src1=exe_src1;
    assign alu_src2 = exe_src2_is_imm12  ?  exe_zero_extend?     {20'b0,exe_imm12} :{{20{exe_imm12[11]}}, exe_imm12} :
                  exe_src2_is_imm5   ? {{27{exe_imm5[4]}}, exe_imm5} :
                  exe_src2_is_imm26  ?  {{4{exe_imm26_extend[27]}}, exe_imm26_extend}:
                  exe_src2_is_imm16  ?  {{14{exe_imm16_extend[17]}}, exe_imm16_extend} :
                  exe_src2_is_imm20  ? exe_imm20 :
                                       exe_src2;
    assign div_divsigned = exe_alu_op == 5'd22 || exe_alu_op == 5'd20;
    assign div_en = exe_alu_op == 5'd20 || exe_alu_op == 5'd21 || exe_alu_op == 5'd22 || exe_alu_op == 5'd23 ;
    assign exe_div_is_doing = div_en && div_completed==1'b0;

    wire [31:0] exe_data_phy_addr ;

    assign exe_data_phy_addr = data_addr ;


    ALU alu(
        .src1(alu_src1),
        .src2(alu_src2),
        .alu_op(exe_alu_op),
        .exe_alu_result(exe_alu_ret),
        .exe_pc(exe_pc),
        .exe_br_taken(exe_br_taken),
        .exe_br_target(exe_br_target),
        .alu_rf_src1(exe_rf_src1),
        .alu_rf_src2(exe_rf_src2),
        .exe_ex_ale_h(exe_ex_ale_h),
        .exe_ex_ale_w(exe_ex_ale_w),
        .exe_ex_ale(exe_ex_ale)       //exe_ex_ale_h ?????1时， ?????测运算结果最低位是否 ?????0，不是的话置1；exe_ex_ale_w ?????0时， ?????测运算结果低两位是否 ?????0，不是就 ?????1
    );//


    Div div(
        .div_clk(aclk),
        .reset(rst),
        .div_signed(div_divsigned),
        .div(div_en),
        .x(alu_src1),
        .y(alu_src2),
        .s(div_result),
        .r(div_rest),
        .complete(div_completed)
    );
    assign exe_alu_result = (exe_alu_op==5'd20 || exe_alu_op == 5'd21) ?   div_result :
                            (exe_alu_op==5'd22 || exe_alu_op == 5'd23) ?   div_rest : exe_alu_ret;
    assign exe_dram_waddr = exe_alu_result;

    wire [2:0]data_tlb_ex;
    wire [31:0] mem_alu_result;
    wire  mem_ref_we;
    wire [4:0] mem_rd;
    wire mem_dram_re;
    wire mem_dram_we;
    //wire mem_br_taken;
    //wire [31:0] mem_br_target;
    wire mem_res_from_dram;
    wire [31:0] mem_dram_wdata;
    wire [31:0] mem_dram_waddr;
    wire [31:0] mem_pc;
    wire mem_rdram_need_zero_extend;
    wire mem_rdram_need_signed_extend;
    wire [1:0]mem_rdram_num;
    wire [1:0] mem_wdram_num;
    wire [31:0] mem_dram_rdata;
    wire [13:0] mem_csr_num;
    wire mem_csr_we;
    wire mem_is_ertn;
    wire mem_is_syscall;
    wire mem_res_from_csr;
    wire [31:0] mem_csr_wmask;
    wire [31:0] mem_csr_wdata;
    wire mem_ex_adef;
    wire mem_ex_ale;
    wire mem_ex_brk;
    wire mem_ex_ine;
    wire mem_has_int;
    wire [4:0]mem_rj;
    wire [31:0]mem_res_of_cnt;
    wire mem_res_is_rj;
    wire mem_res_from_cnt;
    wire mem_res_from_tid;
    wire data_req_valid;
    wire mem_need_data_sram;//
    wire mem_ex_ale_h;
    wire mem_ex_ale_w;
    wire [31:0] exe_data_addr;
    wire [31:0] mem_data_addr;
    wire mem_need_cancel;
    wire mem_inst_tlbrd;
    assign exe_data_addr = data_sram_addr ;
    wire mem_inst_tlbsrch;
    wire mem_tlb_we;
    wire mem_tlb_fill_en;
    wire mem_tlb_wr_en;
    wire mem_invtlb_valid;
    wire [4:0]mem_invtlb_op;
    wire [9:0]mem_invtlb_asid;
    wire [18:0]mem_invtlb_va;
    wire [4:0] mem_alu_op;
    wire mem_tlb_or_csr_we;
    wire [1:0] mem_inst_tlb_ex;
    wire [2:0] mem_data_tlb_ex;

    wire mem_icache_v_we;
    wire mem_dcache_v_we;
    wire mem_icache_tag_we;
    wire mem_dcache_tag_we;
    wire [31:0] mem_cacop_va;
    wire mem_cacop_need_phy;
    wire mem_cacop_en;
    wire mem_inst_cacop;
    wire mem_data_cacop;
    wire [31:0] mem_inst;
    wire [31:0] mem_data_phy_addr ;


    wire mem_inst_cnt;
    wire [63:0]mem_timer_64;
    wire [7:0]mem_inst_ld_en;
    wire [7:0]mem_inst_st_en;
    wire mem_csr_rstat_en;
    wire [31:0]mem_csr_data;

    wire mem_inst_cpucfg ;
    wire [31:0] mem_cpucfg_result ;
    

   // wire [31:0] mem_csr_rdata;
    Mem_reg mem_reg(
        .clk(aclk),
        .rst(rst),
        .wb_ex(wb_ex),
        .wb_is_ertn(wb_is_ertn),
        .exe_ready_go(exe_ready_go),
        .mem_allow_in(mem_allow_in),
        .mem_ready_go(mem_ready_go),
        
        .mem_data_shake_ok(mem_data_shake_ok),
        .exe_alu_result(exe_alu_result),
        .exe_ref_we(exe_ref_we),
        .exe_dram_re(exe_dram_re),
        .exe_dram_we(exe_dram_we),
        .exe_data_addr(exe_data_addr),
        .exe_rd(exe_rd),
        //.exe_br_taken(exe_br_taken),
        //.exe_br_target(exe_br_target),
        .exe_res_from_dram(exe_res_from_dram),
        .exe_dram_waddr(exe_dram_waddr),
        .exe_dram_wdata(data_sram_wdata),
        .exe_pc(exe_pc),
        .exe_rdram_need_zero_extend(exe_rdram_need_zero_extend),
        .exe_rdram_need_signed_extend(exe_rdram_need_signed_extend),
        .exe_rdram_num(exe_rdram_num),
        .exe_wdram_num(exe_wdram_num),
        .exe_csr_num(exe_csr_num),
        .exe_csr_we(exe_csr_we),
        .exe_is_ertn(exe_is_ertn),
        .exe_is_syscall(exe_is_sycall),
        .exe_res_from_csr(exe_res_from_csr),
        .exe_csr_wmask(exe_csr_wmask),
        .exe_csr_wdata(exe_csr_wdata),
        .exe_ex_adef(exe_ex_adef),                        
        .exe_ex_brk(exe_ex_brk),                         
        .exe_ex_ine(exe_ex_ine),                           
        .exe_ex_ale(exe_ex_ale),   
        .exe_has_int(exe_has_int), 
        .exe_rj(exe_rj),
        .exe_res_of_cnt(exe_res_of_cnt),
        .exe_res_is_rj(exe_res_is_rj),
        .exe_res_from_cnt(exe_res_from_cnt),  
        .exe_res_from_tid(exe_res_from_tid),
        .exe_need_data_sram(exe_need_data_sram),
        .exe_ex_ale_h(exe_ex_ale_h),
        .exe_ex_ale_w(exe_ex_ale_w),
        .exe_need_cancel(exe_need_cancel),
        .exe_inst_tlbrd(exe_inst_tlbrd),
        .exe_inst_tlbsrch(exe_inst_tlbsrch),
        .exe_tlb_wr_en(exe_tlb_wr_en),
        .exe_tlb_fill_en(exe_tlb_fill_en),
        .exe_tlb_we(exe_tlb_we),
        .exe_invtlb_asid(exe_invtlb_asid),
        .exe_invtlb_op(exe_invtlb_op),
        .exe_invtlb_va(exe_invtlb_va),
        .exe_invtlb_valid(exe_invtlb_valid),
        .exe_alu_op(exe_alu_op),
        .exe_tlb_or_csr_we(exe_tlb_or_csr_we),
        .exe_inst_tlb_ex(exe_inst_tlb_ex),
        .exe_data_tlb_ex(data_tlb_ex),
        .exe_icache_v_we(exe_icache_v_we),
        .exe_dcache_v_we(exe_dcache_v_we),
        .exe_dcache_tag_we(exe_dcache_tag_we),
        .exe_icache_tag_we(exe_icache_tag_we),
        .exe_cacop_va(exe_cacop_va),
        .exe_cacop_need_phy(exe_cacop_need_phy),
        .exe_data_cacop(exe_data_cacop),
        .exe_inst_cacop(exe_inst_cacop),
        .exe_cacop_en(exe_cacop_en),
        .exe_inst(exe_inst),
        .exe_data_phy_addr(exe_data_phy_addr),
        .exe_inst_cnt(exe_inst_cnt),
        .exe_timer_64(exe_timer_64),
        .exe_inst_ld_en(exe_inst_ld_en),
        .exe_inst_st_en(exe_inst_st_en),
        .exe_csr_rstat_en(exe_csr_rstat_en),
        .exe_csr_data(exe_csr_data),
        .exe_inst_cpucfg(exe_inst_cpucfg),
        .exe_cpucfg_result(exe_cpucfg_result),
        //.exe_csr_rdata(exe_csr_rdata),                 
        .mem_ref_we(mem_ref_we),
        .mem_alu_result(mem_alu_result),
        .mem_dram_re(mem_dram_re),
        .mem_dram_we(mem_dram_we),
        .mem_rd(mem_rd),
        //.mem_br_taken(mem_br_taken),
        //.mem_br_target(mem_br_target),
        .mem_res_from_dram(mem_res_from_dram),
        .mem_dram_wdata(mem_dram_wdata),
        .mem_dram_waddr(mem_dram_waddr),
        .mem_pc(mem_pc),
        .mem_rdram_need_zero_extend(mem_rdram_need_zero_extend),
        .mem_rdram_need_signed_extend(mem_rdram_need_signed_extend),
        .mem_rdram_num(mem_rdram_num),
        .mem_wdram_num(mem_wdram_num),
        .mem_csr_num(mem_csr_num),
        .mem_csr_we(mem_csr_we),
        .mem_is_ertn(mem_is_ertn),
        .mem_is_syscall(mem_is_syscall),
        .mem_res_from_csr(mem_res_from_csr),
        .mem_csr_wmask(mem_csr_wmask),
        .mem_csr_wdata(mem_csr_wdata),
        .mem_ex_adef(mem_ex_adef),                        
        .mem_ex_brk(mem_ex_brk),                         
        .mem_ex_ine(mem_ex_ine),                           
        .mem_ex_ale(mem_ex_ale),
        .mem_has_int(mem_has_int),
        .mem_rj(mem_rj),
        .mem_res_of_cnt(mem_res_of_cnt),
        .mem_res_is_rj(mem_res_is_rj),
        .mem_res_from_cnt(mem_res_from_cnt),
        .mem_res_from_tid(mem_res_from_tid),
        .mem_need_data_sram(mem_need_data_sram),
        .mem_ex_ale_h(mem_ex_ale_h),
        .mem_ex_ale_w(mem_ex_ale_w),
        .mem_data_addr(mem_data_addr),
        .mem_need_cancel(mem_need_cancel),
        .mem_inst_tlbrd(mem_inst_tlbrd),
        .mem_inst_tlbsrch(mem_inst_tlbsrch),
        .mem_tlb_we(mem_tlb_we),
        .mem_tlb_fill_en(mem_tlb_fill_en),
        .mem_tlb_wr_en(mem_tlb_wr_en),
        .mem_invtlb_asid(mem_invtlb_asid),
        .mem_invtlb_op(mem_invtlb_op),
        .mem_invtlb_va(mem_invtlb_va),
        .mem_invtlb_valid(mem_invtlb_valid),
        .mem_alu_op(mem_alu_op),
        .mem_tlb_or_csr_we(mem_tlb_or_csr_we),
        .mem_inst_tlb_ex(mem_inst_tlb_ex),
        .mem_data_tlb_ex(mem_data_tlb_ex),
        .mem_icache_v_we(mem_icache_v_we),
        .mem_dcache_v_we(mem_dcache_v_we),
        .mem_dcache_tag_we(mem_dcache_tag_we),
        .mem_icache_tag_we(mem_icache_tag_we),
        .mem_cacop_va(mem_cacop_va),
        .mem_cacop_need_phy(mem_cacop_need_phy),
        .mem_inst_cacop(mem_inst_cacop),
        .mem_data_cacop(mem_data_cacop),
        .mem_cacop_en(mem_cacop_en),
        .mem_inst(mem_inst),
        .mem_data_phy_addr(mem_data_phy_addr),
        .mem_inst_cnt(mem_inst_cnt),
        .mem_timer_64(mem_timer_64),
        .mem_inst_ld_en(mem_inst_ld_en),
        .mem_inst_st_en(mem_inst_st_en),
        .mem_csr_rstat_en(mem_csr_rstat_en),
        .mem_csr_data(mem_csr_data),
        .mem_inst_cpucfg(mem_inst_cpucfg),
        .mem_cpucfg_result(mem_cpucfg_result)
        

    );
    //assign data_sram_addr=mem_alu_result;

    wire [31:0] mem_alu_ret = (mem_alu_op==5'd22 || mem_alu_op == 5'd23) ?   div_rest : mem_alu_result; 
    wire data_tlb_or_csr_we;
    wire [31:0]data_we;

    assign mem_dram_rdata=data_sram_rdata;
    assign data_sram_wstrb=(wb_ex==1'b1||exe_ex_ale==1'b1||wb_is_ertn==1'b1 || data_tlb_ex != 3'b0)?    4'b0000:
                        (exe_dram_we&&exe_wdram_num==0)? 4'b1111:
                        (exe_dram_we&&exe_wdram_num==1&&data_sram_addr[1:0]==2'b00)?  4'b0001:
                        (exe_dram_we&&exe_wdram_num==1&&data_sram_addr[1:0]==2'b01)?4'b0010:
                        (exe_dram_we&&exe_wdram_num==1&&data_sram_addr[1:0]==2'b10)? 4'b0100:
                        (exe_dram_we&&exe_wdram_num==1&&data_sram_addr[1:0]==2'b11)? 4'b1000:
                        (exe_dram_we&&exe_wdram_num==2&&data_sram_addr[1:0]==2'b00)?4'b0011:
                        (exe_dram_we&&exe_wdram_num==2&&data_sram_addr[1:0]==2'b01)?4'b0110:
                        (exe_dram_we&&exe_wdram_num==2&&data_sram_addr[1:0]==2'b10)?4'b1100:   4'b0000;

    assign data_we = { {8{data_sram_wstrb[3]}}, 
                   {8{data_sram_wstrb[2]}}, 
                   {8{data_sram_wstrb[1]}}, 
                   {8{data_sram_wstrb[0]}} };

    assign data_sram_req=  data_req_valid & exe_need_data_sram & mem_allow_in &&(wb_ex!=1'b1) & (!(data_tlb_or_csr_we == 1'b1)) &(data_tlb_ex == 3'b0) &(!(data_cacop == 1'b1));
    assign data_sram_size = exe_ex_ale_h ? 2'b1 :
                            exe_ex_ale_w ? 2'b10 :  2'b0;
    assign exe_addr_shake_ok = exe_need_data_sram ?  data_sram_req&&(data_sram_addr_ok==1'b1) :  1'b1;
    assign mem_data_shake_ok = mem_need_data_sram ?  (data_sram_data_ok==1'b1) : 1'b1;
    assign data_sram_wr = exe_dram_we;
    assign mem_need_and_data_ok = mem_need_data_sram && (data_sram_data_ok==1'b1);
   // assign data_sram_en=1'b1;
    //assign data_sram_wdata=mem_dram_wdata;
    assign data_sram_wdata =  exe_wdram_num==0?  exe_dram_wdata:
                             exe_wdram_num==1?   {4{exe_dram_wdata[7:0]}} & data_we :{2{exe_dram_wdata[15:0]}} & data_we;
    assign data_sram_addr=exe_dram_we? exe_dram_waddr: exe_alu_result;

    wire [31:0] data_addr;   // 经过TLB转换后的地址
    wire data_dmw0_en;
    wire data_dmw1_en;

    wire data_cacop;
    
    assign data_tlb_ex = ((csr_crmd_da && csr_crmd_pg==1'b0)|| data_dmw0_en || data_dmw1_en || exe_need_data_sram==1'b0) ? 3'h0 :
                         (tlb_s1_found == 1'b0)                                              ? 3'h1 :
                         (tlb_s1_v == 1'b0 && exe_is_ld)                                     ? 3'h2 :
                         (tlb_s1_v == 1'b0 && exe_is_st)                                     ? 3'h3 :
                         (tlb_s1_plv < csr_crmd_plv)                                         ? 3'h4 : 
                         (tlb_s1_d == 1'b0 && exe_is_st)                                     ? 3'h5 : 3'h0; 
                         
    assign data_dmw0_en = csr_crmd_da == 1'b0 && csr_crmd_pg && ((csr_crmd_plv == 2'h3 && csr_dmw0_plv3)||(csr_crmd_plv == 2'h0 && csr_dmw0_plv0)) && data_sram_addr[31:29] == csr_dmw0_vseg;
    assign data_dmw1_en = csr_crmd_da == 1'b0 && csr_crmd_pg && ((csr_crmd_plv == 2'h3 && csr_dmw1_plv3)||(csr_crmd_plv == 2'h0 && csr_dmw1_plv0)) && data_sram_addr[31:29] == csr_dmw1_vseg;
    assign data_addr = (csr_crmd_da && csr_crmd_pg==1'b0) ?  data_sram_addr :
                        data_dmw0_en                       ?  {csr_dmw0_pseg,data_sram_addr[28:0]} :
                        data_dmw1_en                       ?  {csr_dmw1_pseg,data_sram_addr[28:0]} :  {tlb_s1_ppn[19:0],data_sram_addr[11:0]};

    assign data_tlb_or_csr_we = mem_tlb_or_csr_we | wb_tlb_or_csr_we;
    assign data_cacop = (mem_data_cacop && mem_need_cancel == 1'b0 ) && (wb_data_cacop && wb_need_cancel == 1'b0 ); 


    wire  wb_rf_we;
    wire [31:0] wb_alu_result;
    wire [4:0] wb_rd;
    //wire [31:0] wb_br_target;
    //wire wb_br_taken;
    wire [31:0]wb_dram_rdata;
    wire wb_res_from_dram;
    wire [31:0] wb_dram_wdata;
    wire [31:0] wb_dram_waddr;
    wire wb_dram_we;
    wire [31:0] wb_pc;
    wire [1:0]wb_rdram_num;
    wire wb_rdram_need_zero_extend;
    wire wb_rdram_need_signed_extend;
    wire [31:0] wb_data_addr;
    wire [13:0] wb_csr_num;
    wire wb_csr_we;
    wire wb_is_syscall;
    wire wb_res_from_csr;
    wire [31:0] wb_csr_wmask;
    wire [31:0] wb_csr_wdata;
    wire wb_ex_adef;
    wire wb_ex_ale;
    wire wb_ex_brk;
    wire wb_ex_ine;
    wire wb_has_int;
    wire wb_res_from_tid;
    wire wb_need_cancel;
    wire wb_inst_tlbrd;
    wire [4:0] wb_rj;
    wire [31:0] wb_res_of_cnt;
    wire wb_inst_tlbsrch;
    wire wb_tlb_we;
    wire wb_tlb_fill_en;
    wire wb_tlb_wr_en;
    wire wb_invtlb_valid;
    wire [4:0]wb_invtlb_op;
    wire [9:0]wb_invtlb_asid;
    wire [18:0]wb_invtlb_va;
    wire wb_tlb_or_csr_we;
    wire [1:0] wb_inst_tlb_ex;
    wire [2:0] wb_data_tlb_ex;
    wire wb_res_from_cnt;
    wire wb_res_is_rj;

    wire wb_icache_v_we;
    wire wb_dcache_v_we;
    wire wb_icache_tag_we;
    wire wb_dcache_tag_we;
    wire [31:0] wb_cacop_va;
    wire wb_cacop_need_phy;
    wire wb_cacop_en;
    wire wb_inst_cacop;
    wire wb_data_cacop;
    wire [31:0] wb_inst;
    wire [31:0] wb_data_phy_addr;


    wire wb_inst_cnt;
    wire [63:0]wb_timer_64;
    wire [7:0]wb_inst_ld_en;
    wire [7:0]wb_inst_st_en;
    wire wb_csr_rstat_en;
    wire [31:0]wb_csr_data;

    wire wb_inst_cpucfg ;
    wire [31:0] wb_cpucfg_result ;

    

    
    
    
   // wire [31:0] wb_csr_rdata;

    Wb_reg wb_reg(
        .clk(aclk),
        .rst(rst),
        .wb_ex(wb_ex),
        .mem_ready_go(mem_ready_go),
        .mem_alu_result(mem_alu_ret),
        .mem_ref_we(mem_ref_we),
        .mem_rd(mem_rd),
       // .mem_br_taken(mem_br_taken),
        //.mem_br_target(mem_br_target),
        .mem_dram_rdata(mem_dram_rdata),
        .mem_res_from_dram(mem_res_from_dram),
        .mem_dram_wdata(mem_dram_wdata),
        .mem_dram_waddr(mem_dram_waddr),
        .mem_dram_we(mem_dram_we),
        .mem_pc(mem_pc),
        .mem_rdram_num(mem_rdram_num),
        .mem_rdram_need_zero_extend(mem_rdram_need_zero_extend),
        .mem_rdram_need_signed_extend(mem_rdram_need_signed_extend),
        .mem_data_addr(mem_data_addr),
        .mem_csr_num(mem_csr_num),
        .mem_csr_we(mem_csr_we),
        .mem_is_ertn(mem_is_ertn),
        .mem_is_syscall(mem_is_syscall),
        .mem_res_from_csr(mem_res_from_csr),
        .mem_csr_wmask(mem_csr_wmask),
        .mem_csr_wdata(mem_csr_wdata),
        .mem_ex_adef(mem_ex_adef),                        
        .mem_ex_brk(mem_ex_brk),                         
        .mem_ex_ine(mem_ex_ine),                           
        .mem_ex_ale(mem_ex_ale),
        .mem_has_int(mem_has_int),
        .mem_rj(mem_rj),
        .mem_res_of_cnt(mem_res_of_cnt),
        .mem_res_is_rj(mem_res_is_rj),
        .mem_res_from_cnt(mem_res_from_cnt),
        .mem_res_from_tid(mem_res_from_tid),
        .mem_need_cancel(mem_need_cancel),
        .mem_inst_tlbrd(mem_inst_tlbrd),
        .mem_inst_tlbsrch(mem_inst_tlbsrch),
        .mem_tlb_we(mem_tlb_we),
        .mem_tlb_wr_en(mem_tlb_wr_en),
        .mem_tlb_fill_en(mem_tlb_fill_en),
        .mem_invtlb_asid(mem_invtlb_asid),
        .mem_invtlb_op(mem_invtlb_op),
        .mem_invtlb_va(mem_invtlb_va),
        .mem_invtlb_valid(mem_invtlb_valid),
        .mem_tlb_or_csr_we(mem_tlb_or_csr_we),
        .mem_inst_tlb_ex(mem_inst_tlb_ex),
        .mem_data_tlb_ex(mem_data_tlb_ex),
         .mem_icache_v_we(mem_icache_v_we),
        .mem_dcache_v_we(mem_dcache_v_we),
        .mem_dcache_tag_we(mem_dcache_tag_we),
        .mem_icache_tag_we(mem_icache_tag_we),
        .mem_cacop_va(mem_cacop_va),
        .mem_cacop_need_phy(mem_cacop_need_phy),
        .mem_data_cacop(mem_data_cacop),
        .mem_inst_cacop(mem_inst_cacop),
        .mem_cacop_en(mem_cacop_en),
        .mem_inst(mem_inst),
        .mem_data_phy_addr(mem_data_phy_addr),
        .mem_inst_cnt(mem_inst_cnt),
        .mem_timer_64(mem_timer_64),
        .mem_inst_ld_en(mem_inst_ld_en),
        .mem_inst_st_en(mem_inst_st_en),
        .mem_csr_rstat_en(mem_csr_rstat_en),
        .mem_csr_data(mem_csr_data),
        .mem_inst_cpucfg(mem_inst_cpucfg),
        .mem_cpucfg_result(mem_cpucfg_result),
        
        //.mem_csr_rdata(mem_csr_rdata),
        .wb_rf_we(wb_rf_we),
        .wb_alu_result(wb_alu_result),
        .wb_rd(wb_rd),
        //.wb_br_taken(wb_br_taken),
        //.wb_br_target(wb_br_target),
        .wb_dram_rdata(wb_dram_rdata),
        .wb_res_from_dram(wb_res_from_dram),
        .wb_dram_waddr(wb_dram_waddr),
        .wb_dram_wdata(wb_dram_wdata),
        .wb_dram_we(wb_dram_we),
        .wb_pc(wb_pc),
        .wb_rdram_num(wb_rdram_num),
        .wb_rdram_need_signed_extend(wb_rdram_need_signed_extend),
        .wb_rdram_need_zero_extend(wb_rdram_need_zero_extend),
        .wb_data_addr(wb_data_addr),
        .wb_csr_num(wb_csr_num),
        .wb_csr_we(wb_csr_we),
        .wb_is_ertn(wb_is_ertn),
        .wb_is_syscall(wb_is_syscall),
        .wb_res_from_csr(wb_res_from_csr),
        .wb_csr_wmask(wb_csr_wmask),
        .wb_csr_wdata(wb_csr_wdata),
        .wb_ex_adef(wb_ex_adef),                        
        .wb_ex_brk(wb_ex_brk),                         
        .wb_ex_ine(wb_ex_ine),                           
        .wb_ex_ale(wb_ex_ale),
        .wb_has_int(wb_has_int),
        .wb_rj(wb_rj),
        .wb_res_of_cnt(wb_res_of_cnt),
        .wb_res_is_rj(wb_res_is_rj),
        .wb_res_from_cnt(wb_res_from_cnt),
        .wb_res_from_tid(wb_res_from_tid),
        .wb_need_cancel(wb_need_cancel),
        .wb_inst_tlbrd(wb_inst_tlbrd),
        .wb_inst_tlbsrch(wb_inst_tlbsrch),
        .wb_tlb_we(wb_tlb_we),
        .wb_tlb_wr_en(wb_tlb_wr_en),
        .wb_tlb_fill_en(wb_tlb_fill_en),
        .wb_invtlb_asid(wb_invtlb_asid),
        .wb_invtlb_op(wb_invtlb_op),
        .wb_invtlb_va(wb_invtlb_va),
        .wb_invtlb_valid(wb_invtlb_valid),
        .wb_tlb_or_csr_we(wb_tlb_or_csr_we),
        .wb_inst_tlb_ex(wb_inst_tlb_ex),
        .wb_data_tlb_ex(wb_data_tlb_ex),
        .wb_icache_v_we(wb_icache_v_we),
        .wb_dcache_v_we(wb_dcache_v_we),
        .wb_dcache_tag_we(wb_dcache_tag_we),
        .wb_icache_tag_we(wb_icache_tag_we),
        .wb_cacop_va(wb_cacop_va),
        .wb_cacop_need_phy(wb_cacop_need_phy),
        .wb_inst_cacop(wb_inst_cacop),
        .wb_data_cacop(wb_data_cacop),
        .wb_cacop_en(wb_cacop_en),
        .wb_inst(wb_inst),
        .wb_data_phy_addr(wb_data_phy_addr),
        .wb_inst_cnt(wb_inst_cnt),
        .wb_timer_64(wb_timer_64),
        .wb_inst_ld_en(wb_inst_ld_en),
        .wb_inst_st_en(wb_inst_st_en),
        .wb_csr_rstat_en(wb_csr_rstat_en),
        .wb_csr_data(wb_csr_data),
        .wb_inst_cpucfg(wb_inst_cpucfg),
        .wb_cpucfg_result(wb_cpucfg_result)
       

        
    );
    


    wire [31:0] mem_to_rf_data;
    wire rf_we;
    assign rf_we = (wb_ex_ale==1'b1) ? 1'b0  :  wb_rf_we & !(wb_ex==1'b1);
    assign mem_to_rf_data = wb_rdram_num==0 ?   wb_dram_rdata :
                            (wb_rdram_num==1&&wb_data_addr[1:0]==2'b00&&wb_rdram_need_signed_extend) ?  {{16{wb_dram_rdata[15]}},wb_dram_rdata[15:0]}   :
                            (wb_rdram_num==1&&wb_data_addr[1:0]==2'b00&&wb_rdram_need_zero_extend) ?  {{16{1'b0}},wb_dram_rdata[15:0]}   :
                            (wb_rdram_num==1&&wb_data_addr[1:0]==2'b01&&wb_rdram_need_signed_extend) ?  {{16{wb_dram_rdata[23]}},wb_dram_rdata[23:8]}   :
                            (wb_rdram_num==1&&wb_data_addr[1:0]==2'b01&&wb_rdram_need_zero_extend) ?  {{16{1'b0}},wb_dram_rdata[23:8]}   :
                            (wb_rdram_num==1&&wb_data_addr[1:0]==2'b10&&wb_rdram_need_signed_extend) ?  {{16{wb_dram_rdata[31]}},wb_dram_rdata[31:16]}   :
                            (wb_rdram_num==1&&wb_data_addr[1:0]==2'b10&&wb_rdram_need_zero_extend) ?  {{16{1'b0}},wb_dram_rdata[31:16]}   :                   
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b00&&wb_rdram_need_signed_extend) ?  {{24{wb_dram_rdata[7]}},wb_dram_rdata[7:0]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b00&&wb_rdram_need_zero_extend) ?  {{24{1'b0}},wb_dram_rdata[7:0]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b01&&wb_rdram_need_signed_extend) ?  {{24{wb_dram_rdata[15]}},wb_dram_rdata[15:8]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b01&&wb_rdram_need_zero_extend) ?  {{24{1'b0}},wb_dram_rdata[15:8]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b10&&wb_rdram_need_signed_extend) ?  {{24{wb_dram_rdata[23]}},wb_dram_rdata[23:16]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b10&&wb_rdram_need_zero_extend) ?  {{24{1'b0}},wb_dram_rdata[23:16]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b11&&wb_rdram_need_signed_extend) ?  {{24{wb_dram_rdata[31]}},wb_dram_rdata[31:24]}   :
                            (wb_rdram_num==2&&wb_data_addr[1:0]==2'b11&&wb_rdram_need_zero_extend) ?  {{24{1'b0}},wb_dram_rdata[31:24]}   : 32'b0;

    //assign rf_raddr1 =  infor_flag ? reg_num : id_rj;
    assign rf_raddr1 = id_rj ;
    assign rf_raddr2 = id_src2_is_rd? id_rd: id_rk;
    assign rf_wdata =  wb_inst_cpucfg ?  wb_cpucfg_result :
                        wb_res_from_dram? mem_to_rf_data: 
                      (wb_res_from_csr|wb_res_from_tid)? csr_rvalue :
                      wb_res_from_cnt?  wb_res_of_cnt:wb_alu_result;  
    
    wire [4:0]rf_waddr;
    assign rf_waddr = wb_res_is_rj? wb_rj : wb_rd;

    wire [31:0] rf_to_diff[31:0];

    regfile rf(
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2),
        .clk(aclk),
        .waddr(rf_waddr),
        .wdata(rf_wdata),
        .we(rf_we),
        .rst(rst)
        `ifdef DIFFTEST_EN
    ,
    .rf_o   (rf_to_diff)
    `endif

    );

    assign id_src1=rf_rdata1;
    assign id_src2=rf_rdata2;
    assign debug0_wb_pc = wb_pc;
    assign debug0_wb_rf_wen ={4{rf_we}};
    assign debug0_wb_rf_wnum=wb_rd;
    assign debug0_wb_rf_wdata=rf_wdata;
    assign rf_rdata = rf_rdata1;
    assign debug0_wb_inst = wb_inst ;

    reg WS_valid;

    always @(posedge aclk)
    begin
        if(rst)
        begin
            WS_valid <= 1'b0 ;
        end
        else if(mem_ready_go && wb_allow_in)
        begin
            WS_valid <= 1'b1 ;
        end
        else 
        begin
            WS_valid <= 1'b0 ;
        end
    end

    assign ws_valid = WS_valid && wb_pc != 32'b0 &&  wb_need_cancel == 1'b0 && wb_pc != 32'h1bfffffc ;



    

    //assign if_allow_in = inst_sram_data_ok==1'b0;
    assign exe_ready_go=    (if_pc!=32'h1bfffffc && exe_pc==32'b0) ?                  1'b0:
                            (wb_ex==1'b1)?                                            1'b0:
                            (exe_alu_op == 5'd20 || exe_alu_op == 5'd21 || exe_alu_op == 5'd22 || exe_alu_op == 5'd23)?   div_completed :
                            (EXE_ready_go == 1'b1) ?                                  1'b1 :
                            exe_need_data_sram ? (data_sram_addr_ok==1'b1 && data_sram_req)||(data_tlb_ex!=3'b0) : 1'b1;
    assign mem_ready_go=     (if_pc != 32'h1c000000&& if_pc!= 32'h1c000004 &&if_pc!=32'h1bfffffc && mem_pc==32'b0) ?       1'b0: 
                            (wb_ex==1'b1)?                                                 1'b0:
                            mem_need_data_sram ?  (data_sram_data_ok==1'b1||mem_data_tlb_ex != 3'b0) : 1'b1;
    //assign pre_if_ready_go =(inst_sram_addr_ok && inst_sram_req)||(inst_tlb_ex != 2'b0);
    assign pre_if_ready_go =(inst_sram_addr_ok && inst_sram_req);
    //assign if_ready_go =1'b1;
    //assign id_ready_go =1'b1;
    //assign wb_ready_go=1'b 1;
    assign if_ready_go = rst? 1'b1:
                         (IF_ready_go == 1'b1) ?     1'b1:
                         //(if_inst_tlb_ex != 2'b0 && id_need_cancel != 2'b0) ?  1'b1 :
                        (if_pc!=32'h1bfffffc&&inst_sram_data_ok==1'b0)? 1'b0 :
                        (exe_ref_we&&exe_rd!=0&&((id_src1_from_ref&&(rf_raddr1==exe_rd))||(id_src2_from_ref&&(rf_raddr2==exe_rd))))? 1'b0 :
                        (mem_ref_we&&mem_rd!=0&&((id_src1_from_ref&&(rf_raddr1==mem_rd))||(id_src2_from_ref&&(rf_raddr2==mem_rd))))?  1'b0:
                        (wb_rf_we&&wb_rd!=0&&((id_src1_from_ref&&(rf_raddr1==wb_rd))||(id_src2_from_ref&&(rf_raddr2==wb_rd))))?  1'b0  : 1'b1;
                        // (exe_csr_we&&(exe_csr_num==14'h4||exe_csr_num==14'd5||exe_csr_num==14'b0)) ?       1'b0:
                        // (mem_csr_we&&(mem_csr_num==14'h4||mem_csr_num==14'd5||mem_csr_num==14'b0)) ?       1'b0:
                        // (wb_csr_we&&(wb_csr_num==14'h4||wb_csr_num==14'd5||wb_csr_num==14'b0)) ?       1'b0:   1'b1;
    assign id_ready_go = rst? 1'b1:
                        (ID_ready_go == 1'b1) ?      1'b1 :
                        (wb_ex==1'b1)? 1'b0:
                        //(wb_is_ertn==1'b1) ? 1'b1:
                        (id_pc==32'b0) ? 1'b0 :
                        (exe_ref_we&&exe_rd!=0&&((id_src1_from_ref&&(rf_raddr1==exe_rd))||(id_src2_from_ref&&(rf_raddr2==exe_rd))))? 1'b0 :
                        (mem_ref_we&&mem_rd!=0&&((id_src1_from_ref&&(rf_raddr1==mem_rd))||(id_src2_from_ref&&(rf_raddr2==mem_rd))))?  1'b0:
                        (wb_rf_we&&wb_rd!=0&&((id_src1_from_ref&&(rf_raddr1==wb_rd))||(id_src2_from_ref&&(rf_raddr2==wb_rd))))?  1'b0  : 1'b1;
                        // (exe_csr_we&&(exe_csr_num==14'h4||exe_csr_num==14'd5||exe_csr_num==14'b0)) ?       1'b0:
                        // (mem_csr_we&&(mem_csr_num==14'h4||mem_csr_num==14'd5||mem_csr_num==14'b0)) ?       1'b0:
                        // (wb_csr_we&&(wb_csr_num==14'h4||wb_csr_num==14'd5||wb_csr_num==14'b0)) ?       1'b0:   1'b1;
    assign wb_ready_go =rst? 1'b1:
                        (wb_ex==1'b1)? 1'b0:
                        //(wb_is_ertn==1'b1) ? 1'b1:
                        (inst_sram_data_ok==1'b0)? 1'b0 :
                        (exe_ref_we&&exe_rd!=0&&((id_src1_from_ref&&(rf_raddr1==exe_rd))||(id_src2_from_ref&&(rf_raddr2==exe_rd))))? 1'b0 :
                        (mem_ref_we&&mem_rd!=0&&((id_src1_from_ref&&(rf_raddr1==mem_rd))||(id_src2_from_ref&&(rf_raddr2==mem_rd))))?  1'b0:
                        (wb_rf_we&&wb_rd!=0&&((id_src1_from_ref&&(rf_raddr1==wb_rd))||(id_src2_from_ref&&(rf_raddr2==wb_rd))))?  1'b0  : 1'b1;
                        // (exe_csr_we&&(exe_csr_num==14'h4||exe_csr_num==14'd5||exe_csr_num==14'b0)) ?       1'b0:
                        // (mem_csr_we&&(mem_csr_num==14'h4||mem_csr_num==14'd5||mem_csr_num==14'b0)) ?       1'b0:
                        // (wb_csr_we&&(wb_csr_num==14'h4||wb_csr_num==14'd5||wb_csr_num==14'b0)) ?       1'b0:   1'b1;
    assign pipline_is_not_stalled =rst? 1'b1:
                       // (wb_ex==1'b1)? 1'b1:
                        (exe_ref_we&&exe_rd!=0&&((id_src1_from_ref&&(rf_raddr1==exe_rd))||(id_src2_from_ref&&(rf_raddr2==exe_rd))))? 1'b0 :
                        (mem_ref_we&&mem_rd!=0&&((id_src1_from_ref&&(rf_raddr1==mem_rd))||(id_src2_from_ref&&(rf_raddr2==mem_rd))))?  1'b0:
                        (wb_rf_we&&wb_rd!=0&&((id_src1_from_ref&&(rf_raddr1==wb_rd))||(id_src2_from_ref&&(rf_raddr2==wb_rd))))?  1'b0  : 1'b1;
                        // (exe_csr_we&&(exe_csr_num==14'h4||exe_csr_num==14'd5||exe_csr_num==14'b0)) ?       1'b0:
                        // (mem_csr_we&&(mem_csr_num==14'h4||mem_csr_num==14'd5||mem_csr_num==14'b0)) ?       1'b0:
                        // (wb_csr_we&&(wb_csr_num==14'h4||wb_csr_num==14'd5||wb_csr_num==14'b0)) ?       1'b0:   1'b1;
    assign wb_allow_in = 1'b1;
    // assign mem_allow_in = wb_allow_in && (~(mem_ready_go==1'b0));
    // assign exe_allow_in = mem_allow_in && (~(exe_ready_go==1'b0));
    // assign id_allow_in = exe_allow_in && (~(id_ready_go==1'b0));
    // assign if_allow_in = id_allow_in && (~(if_ready_go==1'b0));
    if_allow_in_state If_allow_in(
        .clk(aclk),
        .rst(rst),
        .pre_if_ready_go(pre_if_ready_go),
        .if_ready_go(if_ready_go),
        .id_allow_in(id_allow_in),
        .if_allow_in(if_allow_in)
    );
    id_allow_in_state Id_allow_in(
        .clk(aclk),
        .rst(rst),
        .if_ready_go(if_ready_go),
        .id_ready_go(id_ready_go),
        .exe_allow_in(exe_allow_in),
        .if_pc(if_pc),
        .id_allow_in(id_allow_in)
    );
    exe_allow_in_state Exe_allow_in(
        .clk(aclk),
        .rst(rst),
        .id_ready_go(id_ready_go),
        .exe_ready_go(exe_ready_go),
        .wb_ex(wb_ex),
        .mem_allow_in(mem_allow_in),
        .exe_allow_in(exe_allow_in)
    );
    mem_allow_in_state Mem_allow_in(
        .clk(aclk),
        .rst(rst),
        .exe_ready_go(exe_ready_go),
        .mem_ready_go(mem_ready_go),
        .wb_allow_in(wb_allow_in),
        .mem_allow_in(mem_allow_in)
    );
                        
    
    wire [5:0]wb_ecode;
    wire [7:0]wb_esubcode;//异常类型的编 ?????
    wire [2:0]cacop_tlb_ex;
    wire [7:0] axi_data_sram_len ;


    Wb_stage wb_stage(
        .wb_is_syscall(wb_is_syscall), //  Input，是否是调用异常 ?????1 ?????
        .wb_ecode(wb_ecode),          //   Output，异常编码，同下
        .wb_esubcode(wb_esubcode),    //   OutPut,异常编码，按照指令手册表7-7中，8 ?????
        .wb_ex(wb_ex),                // Output,是否触发异常,1 ?????
        .wb_is_ertn(wb_is_ertn),       //Input，是否是ertn指令 ?????1 ?????
        .wb_ex_adef(wb_ex_adef),       //Input，是否是取指令的地址错误 ?????1 ?????
        .wb_ex_ale(wb_ex_ale),         //Input，地 ?????非对齐错误，1 ?????
        .wb_ex_brk(wb_ex_brk),         //Input，是否是断点错误 ?????1 ?????
        .wb_ex_ine(wb_ex_ine),          //Input，指令不存在错误 ?????1 ?????
        .wb_need_cancel(wb_need_cancel),
        .wb_has_int(wb_has_int) ,         //Input,发生了中 ?????
        .wb_inst_tlb_ex(wb_inst_tlb_ex),
        .wb_data_tlb_ex(wb_data_tlb_ex),
        .cacop_tlb_ex(cacop_tlb_ex)
    );

    wire [13:0]csr_num;

    wire [7:0]hw_int_in;

    assign hw_int_in = intrpt ;
    //assign hw_int_in = 8'b0 ;

    wire [31:0] coueid_in=32'b0;
    wire ipi_int_in=1'b0;
    wire [31:0] wb_ex_ale_addr;
    wire csr_ex;
    wire [$clog2(TLBNUM)-1:0] csr_tlbidx_index;
    wire csr_tlbidx_index_we;
    wire [$clog2(TLBNUM)-1:0]csr_tlbidx_index_wvalue;
    wire csr_tlbehi_we;
    wire [18:0]csr_tlbehi_wvalue;

    wire csr_tlbelo0_v_we;
    wire csr_tlbelo0_v_wvalue;
    wire csr_tlbelo0_d_we;
    wire csr_tlbelo0_d_wvalue;
    wire csr_tlbelo0_plv_we;
    wire [1:0]csr_tlbelo0_plv_wvalue;
    wire csr_tlbelo0_mat_we;
    wire [1:0]csr_tlbelo0_mat_wvalue;
    wire csr_tlbelo0_g_we;
    wire csr_tlbelo0_g_wvalue;
    wire csr_tlbelo0_ppn_we;
    wire [19:0]csr_tlbelo0_ppn_wvalue;

    wire csr_tlbelo1_v_we;
    wire csr_tlbelo1_v_wvalue;
    wire csr_tlbelo1_d_we;
    wire csr_tlbelo1_d_wvalue;
    wire csr_tlbelo1_plv_we;
    wire [1:0]csr_tlbelo1_plv_wvalue;
    wire csr_tlbelo1_mat_we;
    wire [1:0]csr_tlbelo1_mat_wvalue;
    wire csr_tlbelo1_g_we;
    wire csr_tlbelo1_g_wvalue;
    wire csr_tlbelo1_ppn_we;
    wire [19:0]csr_tlbelo1_ppn_wvalue;

    wire csr_tlbidx_ne_we;
    wire csr_tlbidx_ne_wvalue;
    wire csr_tlbidx_ps_we;
    wire [5:0]csr_tlbidx_ps_wvalue;

    wire csr_asid_asid_we;
    wire [9:0]csr_asid_asid_wvalue;
    
    wire [9:0] csr_asid_asid;
    wire [5:0] csr_estat_ecode;
    wire csr_tlbidx_ne;
    wire [5:0] csr_tlbidx_ps;
    wire csr_tlbelo0_d;
    wire csr_tlbelo0_g;
    wire csr_tlbelo0_v;
    wire [1:0]csr_tlbelo0_mat;
    wire [19:0] csr_tlbelo0_ppn;
    wire [1:0] csr_tlbelo0_plv;
    wire csr_tlbelo1_d;
    wire csr_tlbelo1_g;
    wire csr_tlbelo1_v;
    wire [1:0] csr_tlbelo1_mat;
    wire [19:0] csr_tlbelo1_ppn;
    wire [1:0] csr_tlbelo1_plv;
    wire [18:0] csr_tlbehi;
    wire csr_dmw0_plv0;
    wire csr_dmw0_plv3;
    wire [1:0]csr_dmw0_mat;
    wire [2:0]csr_dmw0_pseg;
    wire [2:0] csr_dmw0_vseg;
    wire csr_dmw1_plv0;
    wire csr_dmw1_plv3;
    wire [1:0]csr_dmw1_mat;
    wire [2:0]csr_dmw1_pseg;
    wire [2:0] csr_dmw1_vseg;
    wire csr_crmd_da;
    wire csr_crmd_pg;
    wire [31:0] csr_dmw0;
    wire [31:0] csr_dmw1;
    wire [1:0] csr_crmd_plv;
    wire csr_inst_tlb_refill;
    wire csr_data_tlb_refill;
    wire csr_cacop_tlb_refill;

    assign csr_inst_tlb_refill = wb_inst_tlb_ex == 2'b1;
    assign csr_data_tlb_refill = wb_data_tlb_ex == 3'b1;
    assign csr_cacop_tlb_refill = cacop_tlb_ex == 3'b1 ;

    assign csr_dmw0 ={csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0} ;
    assign csr_dmw1 ={csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0} ;

    assign csr_ex = (wb_ex==1'b1) && wb_is_ertn==1'b0 ;
    
    assign wb_ex_ale_addr=wb_data_addr;
    assign csr_num = (wb_ex == 1'b1 &&wb_is_ertn==1'b0) ?           14'hc :
                    wb_res_from_tid?   14'h40:  wb_csr_num;  //中断的话，要去读中断程序入口地址，csr_rvalue即为入口地址

    wire [25:0] csr_tlbrentry;

    wire [1:0] csr_crmd_datf ;
    wire [1:0] csr_crmd_datm ;
    wire [31:0] coreid_in ;

    assign coreid_in = 32'b0;

    wire [31:0] csr_crmd_rvalue;
    wire [31:0] csr_prmd_rvalue;
    wire [31:0] csr_ecfg_rvalue;
    wire [31:0] csr_estat_rvalue;
    wire [31:0] csr_era_rvalue;
    wire [31:0] csr_badv_rvalue;
    wire [31:0] csr_eentry_rvalue;
    wire [31:0] csr_tlbidx_rvalue;
    wire [31:0] csr_tlbehi_rvalue;
    wire [31:0] csr_tlbelo0_rvalue;
    wire [31:0] csr_tlbelo1_rvalue;
    wire [31:0] csr_asid_rvalue;
    wire [31:0] csr_save0_rvalue;
    wire [31:0] csr_save1_rvalue;
    wire [31:0] csr_save2_rvalue;
    wire [31:0] csr_save3_rvalue;
    wire [31:0] csr_tid_rvalue;
    wire [31:0] csr_tcfg_rvalue;
    wire [31:0] csr_tval_rvalue;
    wire [31:0] csr_ticlr_rvalue;
    wire [31:0] csr_llbctl_rvalue;
    wire [31:0] csr_tlbrentry_rvalue;
    wire [31:0] csr_dmw0_rvalue;
    wire [31:0] csr_dmw1_rvalue;
    wire [31:0] csr_pgdl_rvalue;
    wire [31:0] csr_pgdh_rvalue;


    CSR csr(
        .clk(aclk),//
        .rst(rst),//
        .csr_num(csr_num),//
        .csr_we(wb_csr_we),//
        .csr_wmask(wb_csr_wmask),//
        .wb_ertn_flush(wb_is_ertn),//
        .wb_ex(csr_ex),//
        .wb_ecode(wb_ecode),//
        .wb_esubcode(wb_esubcode),//
        .hw_int_in(hw_int_in),
        .coreid_in(coreid_in),
        .ipi_int_in(ipi_int_in),
        .csr_rvalue(csr_rvalue),//
        .csr_wvalue(wb_csr_wdata),//
        .wb_pc(wb_pc),//
        .csr_era_pc(csr_era_pc),
        .wb_ex_ale(wb_ex_ale),
        .wb_ex_ale_addr(wb_ex_ale_addr),
        .csr_estat_is(csr_estat_is),
        .csr_ecfg_lie(csr_ecfg_lie),
        .csr_crmd_ie(csr_crmd_ie),
        .csr_timer_64(csr_timer_64),
        .csr_tid_tid(csr_tid_tid),
        .csr_estat_ecode(csr_estat_ecode),
        .csr_tlbidx_ne(csr_tlbidx_ne),
        .csr_tlbidx_ps(csr_tlbidx_ps),
        .wb_inst_tlb_ex(wb_inst_tlb_ex),
        .wb_data_tlb_ex(wb_data_tlb_ex),
        .cacop_tlb_ex(cacop_tlb_ex),

        .wb_data_addr(wb_data_addr),

        .csr_tlbelo0_d(csr_tlbelo0_d),
        .csr_tlbelo0_g(csr_tlbelo0_g),
        .csr_tlbelo0_mat(csr_tlbelo0_mat),
        .csr_tlbelo0_plv(csr_tlbelo0_plv),
        .csr_tlbelo0_ppn(csr_tlbelo0_ppn),
        .csr_tlbelo0_v(csr_tlbelo0_v),
        .csr_tlbelo1_d(csr_tlbelo1_d),
        .csr_tlbelo1_g(csr_tlbelo1_g),
        .csr_tlbelo1_mat(csr_tlbelo1_mat),
        .csr_tlbelo1_plv(csr_tlbelo1_plv),
        .csr_tlbelo1_ppn(csr_tlbelo1_ppn),
        .csr_tlbelo1_v(csr_tlbelo1_v),


        .csr_tlbidx_index(csr_tlbidx_index),                           //   output
        .csr_tlbidx_index_we(csr_tlbidx_index_we),                     //   input
        .csr_tlbidx_index_wvalue(csr_tlbidx_index_wvalue),             //   input

        .csr_tlbehi_we(csr_tlbehi_we),                                 //   input
        .csr_tlbehi_wvalue(csr_tlbehi_wvalue),                         //   input
        .csr_tlbidx_ps_we(csr_tlbidx_ps_we),                 
        .csr_tlbidx_ps_wvalue(csr_tlbidx_ps_wvalue),

        .csr_tlbelo0_d_we(csr_tlbelo0_d_we),                            
        .csr_tlbelo0_d_wvalue(csr_tlbelo0_d_wvalue),

        .csr_tlbelo0_g_we(csr_tlbelo0_g_we),
        .csr_tlbelo0_g_wvalue(csr_tlbelo0_g_wvalue),

        .csr_tlbelo0_v_we(csr_tlbelo0_v_we),
        .csr_tlbelo0_v_wvalue(csr_tlbelo0_v_wvalue),

        .csr_tlbelo0_plv_we(csr_tlbelo0_plv_we),
        .csr_tlbelo0_plv_wvalue(csr_tlbelo0_plv_wvalue),

        .csr_tlbelo0_mat_we(csr_tlbelo0_mat_we),
        .csr_tlbelo0_mat_wvalue(csr_tlbelo0_mat_wvalue),

        .csr_tlbelo0_ppn_we(csr_tlbelo0_ppn_we),
        .csr_tlbelo0_ppn_wvalue(csr_tlbelo0_ppn_wvalue),

        
        .csr_tlbelo1_d_we(csr_tlbelo1_d_we),                            
        .csr_tlbelo1_d_wvalue(csr_tlbelo1_d_wvalue),

        .csr_tlbelo1_g_we(csr_tlbelo1_g_we),
        .csr_tlbelo1_g_wvalue(csr_tlbelo1_g_wvalue),

        .csr_tlbelo1_v_we(csr_tlbelo1_v_we),
        .csr_tlbelo1_v_wvalue(csr_tlbelo1_v_wvalue),

        .csr_tlbelo1_plv_we(csr_tlbelo1_plv_we),
        .csr_tlbelo1_plv_wvalue(csr_tlbelo1_plv_wvalue),

        .csr_tlbelo1_mat_we(csr_tlbelo1_mat_we),
        .csr_tlbelo1_mat_wvalue(csr_tlbelo1_mat_wvalue),

        .csr_tlbelo1_ppn_we(csr_tlbelo1_ppn_we),
        .csr_tlbelo1_ppn_wvalue(csr_tlbelo1_ppn_wvalue),

        .csr_tlbidx_ne_we(csr_tlbidx_ne_we),
        .csr_tlbidx_ne_wvalue(csr_tlbidx_ne_wvalue),

        .csr_asid_asid_we(csr_asid_asid_we),
        .csr_asid_asid_wvalue(csr_asid_asid_wvalue),

        .csr_asid_asid(csr_asid_asid),
        .csr_tlbehi(csr_tlbehi),

        .csr_dmw0_plv0(csr_dmw0_plv0),
        .csr_dmw0_plv3(csr_dmw0_plv3),
        .csr_dmw0_mat(csr_dmw0_mat),
        .csr_dmw0_pseg(csr_dmw0_pseg),
        .csr_dmw0_vseg(csr_dmw0_vseg),
        .csr_dmw1_plv0(csr_dmw1_plv0),
        .csr_dmw1_plv3(csr_dmw1_plv3),
        .csr_dmw1_mat(csr_dmw1_mat),
        .csr_dmw1_pseg(csr_dmw1_pseg),
        .csr_dmw1_vseg(csr_dmw1_vseg),
        .csr_crmd_da(csr_crmd_da),
        .csr_crmd_pg(csr_crmd_pg),
        .csr_crmd_plv(csr_crmd_plv),
        .csr_inst_tlb_refill(csr_inst_tlb_refill),
        .csr_data_tlb_refill(csr_data_tlb_refill),
        .csr_cacop_tlb_refill(csr_cacop_tlb_refill),
        .csr_tlbrentry(csr_tlbrentry),

        .csr_crmd_datm(csr_crmd_datm),
        .csr_crmd_datf(csr_crmd_datf),


        .csr_crmd_rvalue(csr_crmd_rvalue),
        .csr_prmd_rvalue(csr_prmd_rvalue), 
        .csr_ecfg_rvalue(csr_ecfg_rvalue),
        .csr_estat_rvalue(csr_estat_rvalue),
        .csr_era_rvalue(csr_era_rvalue),
        .csr_badv_rvalue(csr_badv_rvalue),
        .csr_eentry_rvalue(csr_eentry_rvalue),
        .csr_tlbidx_rvalue(csr_tlbidx_rvalue),
        .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
        .csr_tlbelo0_rvalue(csr_tlbelo0_rvalue),
        .csr_tlbelo1_rvalue(csr_tlbelo1_rvalue),
        .csr_asid_rvalue(csr_asid_rvalue),
        .csr_save0_rvalue(csr_save0_rvalue),
        .csr_save1_rvalue(csr_save1_rvalue),
        .csr_save2_rvalue(csr_save2_rvalue),
        .csr_save3_rvalue(csr_save3_rvalue),
        .csr_tid_rvalue(csr_tid_rvalue),
        .csr_tcfg_rvalue(csr_tcfg_rvalue),
        .csr_tval_rvalue(csr_tval_rvalue),
        .csr_ticlr_rvalue(csr_ticlr_rvalue),
        .csr_llbctl_rvalue(csr_llbctl_rvalue),
        .csr_tlbrentry_rvalue(csr_tlbrentry_rvalue),
        .csr_dmw0_rvalue(csr_dmw0_rvalue),
        .csr_dmw1_rvalue(csr_dmw1_rvalue),
        .csr_pgdl_rvalue(csr_pgdl_rvalue),
        .csr_pgdh_rvalue(csr_pgdh_rvalue)

    );

    Inst_ram_state inst_ram_state(
        .clk(aclk),
        .rst(rst),
        .req(inst_sram_req),
        .data_ok(inst_sram_data_ok),
        .addr_ok(inst_sram_addr_ok),
        .inst_req_valid(inst_req_valid)          //output,等于0表示 ????1个请求已经发出，不能再发请求
    );

    wire Inst_sram_req;
    assign Inst_sram_req =if_allow_in & inst_req_valid & pc_inst_en & (~pipline_is_not_stalled==1'b0);
    wire axi_inst_sram_addr_ok;
    wire axi_inst_sram_req;
    wire [31:0] axi_inst_sram_addr;
    wire axi_ret_valid ;
    wire [31:0] axi_ret_data ;

    wire axi_data_sram_req;
    wire [31:0] axi_data_sram_addr ;
    wire axi_data_sram_addr_ok ;
    wire axi_data_sram_data_ok ;
    wire [1:0]axi_data_sram_size;
    wire [31:0]axi_data_sram_wdata;
    wire axi_data_sram_wr;
    wire [3:0] axi_data_sram_wstrb ;
    wire data_ret_valid;
    wire axi_ret_last;
    wire data_uncache ;
    assign data_uncache = ( csr_crmd_da && csr_crmd_pg==1'b0 && csr_crmd_datm == 2'b0) ||  
                         ( data_dmw0_en && csr_dmw0_mat == 2'b0 )  ||
                         ( data_dmw1_en && csr_dmw1_mat == 2'b0)  ||
                         ( csr_crmd_da == 1'b0 && csr_crmd_pg && data_dmw0_en == 1'b0 && data_dmw1_en == 1'b0 && tlb_r_mat1 == 2'b0);

    If_to_id_need_cancel if_to_id_need_cancel(
        .clk(aclk),
        .rst(rst),
        .wb_ex(wb_ex),
        .pipline_is_not_stalled(pipline_is_not_stalled),
        .inst_sram_req(Inst_sram_req),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .if_ready_go(if_ready_go),
        .id_allow_in(id_allow_in),
        .id_br_taken(id_br_taken),
        .pre_if_ready_go(pre_if_ready_go),
        .if_allow_in(if_allow_in),
        .id_need_cancel(id_need_cancel),          //output;等于1表示if-id级的指令 ????要取 ????
         .id_ready_go(id_ready_go),
        .exe_allow_in(exe_allow_in),
        .if_pc(if_pc),
        .id_pc(id_pc)
    );

    Data_ram_state data_ram_state(
        .clk(aclk),
        .rst(rst),
        .req(data_sram_req),
        .data_ok(data_sram_data_ok),
        .addr_ok(data_sram_addr_ok),
        .data_req_valid(data_req_valid)          //表示 ????1个请求已经发出，不能再发请求
    );

    id_next_inst_cancel id_next_inst_cancel(
        .clk(aclk),
        .rst(rst),
        .id_br_taken(id_br_taken),
        .if_ready_go(if_ready_go),
        .id_allow_in(id_allow_in),
        .pre_if_ready_go(pre_if_ready_go),
        .if_allow_in(if_allow_in),
        .id_next_inst_cancel(id_inst_cancel)
    );

    IF_readygo_state If_readygo_state(
        .rst(rst),
        .clk(aclk),
        .id_allow_in(id_allow_in),
        .if_ready_go(if_ready_go),
        .IF_ready_go(IF_ready_go)
    );

    EXE_readygo_state Exe_readygo_state(
        .rst(rst),
        .clk(aclk),
        .mem_allow_in(mem_allow_in),
        .exe_ready_go(exe_ready_go),
        .EXE_ready_go(EXE_ready_go)
    );

    ID_readygo_state Id_readygo_state(
        .rst(rst),
        .clk(aclk),
        .id_ready_go(id_ready_go),
        .exe_allow_in(exe_allow_in),
        .ID_ready_go(ID_ready_go)
    );

    wire [31:0]axi_data_ret_data;

    axi_bridge u_axi_bridge (
    .aclk(aclk),
    .aresetn(aresetn),

    .inst_sram_req(axi_inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(axi_inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_data_ok(axi_ret_valid),
    .inst_sram_addr_ok(axi_inst_sram_addr_ok),
    .inst_sram_rdata(axi_ret_data),

    .data_sram_req(axi_data_sram_req),
    .data_sram_wr(axi_data_sram_wr),
    .data_sram_size(axi_data_sram_size),
    .data_sram_wstrb(axi_data_sram_wstrb),
    .data_sram_addr(axi_data_sram_addr),
    .data_sram_wdata(axi_data_sram_wdata),
    .data_sram_data_ok(axi_data_sram_data_ok),
    .data_sram_addr_ok(axi_data_sram_addr_ok),
    .data_sram_len(axi_data_sram_len),

    .data_sram_rdata(axi_data_ret_data),

    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rvalid(rvalid),
    .rready(rready),
    .rlast(rlast),
    .axi_ret_last(axi_ret_last),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bvalid(bvalid),
    .bready(bready),
    .data_ret_valid(data_ret_valid)
);
    
    wire tlb_r_e;
    wire [18:0] tlb_r_vppn;
    wire [5:0] tlb_r_ps;
    wire [9:0] tlb_r_asid;
    wire tlb_r_g;
    wire [19:0] tlb_r_ppn0;
    wire [1:0] tlb_r_plv0;
    wire [1:0] tlb_r_mat0;
    wire tlb_r_d0;
    wire tlb_r_v0;
    wire [19:0] tlb_r_ppn1;
    wire [1:0] tlb_r_plv1;
    wire [1:0] tlb_r_mat1;
    wire tlb_r_d1;
    wire tlb_r_v1;
    wire [18:0]tlb_s2_vppn;
    wire [9:0] tlb_s2_asid;
    wire tlb_s2_found;
    wire [$clog2(TLBNUM)-1:0]tlb_s2_index;
    wire [$clog2(TLBNUM)-1:0]tlb_w_index;

    wire tlb_w_e;
    wire [18:0]tlb_w_vppn;
    wire [5:0] tlb_w_ps;
    wire [9:0] tlb_w_asid;
    wire tlb_w_g;
    wire [19:0] tlb_w_ppn0;
    wire [1:0] tlb_w_plv0;
    wire [1:0] tlb_w_mat0;
    wire tlb_w_d0;
    wire tlb_w_v0;
    wire [19:0] tlb_w_ppn1;
    wire [1:0] tlb_w_plv1;
    wire [1:0] tlb_w_mat1;
    wire tlb_w_d1;
    wire tlb_w_v1;


    wire [18:0] tlb_s0_vppn;
    wire tlb_s0_va_bit12;
    wire [9:0] tlb_s0_asid;
    wire tlb_s0_found;
    wire [$clog2(TLBNUM)-1:0] tlb_s0_index;
    wire [19:0] tlb_s0_ppn;
    wire [5:0] tlb_s0_ps;
    wire [1:0] tlb_s0_plv;
    wire [1:0] tlb_s0_mat;
    wire tlb_s0_d;
    wire tlb_s0_v;

    wire [18:0] tlb_s1_vppn;
    wire tlb_s1_va_bit12;
    wire [9:0] tlb_s1_asid;
    wire tlb_s1_found;
    wire [$clog2(TLBNUM)-1:0] tlb_s1_index;
    wire [19:0] tlb_s1_ppn;
    wire [5:0] tlb_s1_ps;
    wire [1:0] tlb_s1_plv;
    wire [1:0] tlb_s1_mat;
    wire tlb_s1_d;
    wire tlb_s1_v;

    wire [18:0] tlb_s3_vppn;
    wire tlb_s3_va_bit12;
    wire [9:0] tlb_s3_asid;
    wire tlb_s3_found;
    wire [$clog2(TLBNUM)-1:0] tlb_s3_index;
    wire [19:0] tlb_s3_ppn;
    wire [5:0] tlb_s3_ps;
    wire [1:0] tlb_s3_plv;
    wire [1:0] tlb_s3_mat;
    wire tlb_s3_d;
    wire tlb_s3_v;




    assign tlb_w_index = wb_tlb_fill_en ?  csr_timer_64[3:0] : csr_tlbidx_index ;
    assign tlb_w_e  = (csr_estat_ecode == 6'h3f) ?  1'b1 : (~csr_tlbidx_ne) ;
    assign tlb_w_vppn =  csr_tlbehi;
    assign tlb_w_ps = csr_tlbidx_ps;
    assign tlb_w_asid = csr_asid_asid;
    assign tlb_w_g = csr_tlbelo0_g & csr_tlbelo1_g;
    assign tlb_w_ppn0 = csr_tlbelo0_ppn;
    assign tlb_w_plv0 = csr_tlbelo0_plv;
    assign tlb_w_mat0 = csr_tlbelo0_mat;
    assign tlb_w_d0 = csr_tlbelo0_d;
    assign tlb_w_v0 = csr_tlbelo0_v;
    assign tlb_w_ppn1 = csr_tlbelo1_ppn;
    assign tlb_w_plv1 = csr_tlbelo1_plv;
    assign tlb_w_mat1 = csr_tlbelo1_mat;
    assign tlb_w_d1 = csr_tlbelo1_d;
    assign tlb_w_v1 = csr_tlbelo1_v;

    assign tlb_s2_asid = wb_inst_tlbsrch ? csr_asid_asid : wb_invtlb_asid;
    assign tlb_s2_vppn = wb_inst_tlbsrch ? csr_tlbehi  :  wb_invtlb_va  ;


    //  search ports for fetch and load/store
    assign tlb_s0_vppn = inst_sram_addr [31:13];
    assign tlb_s0_va_bit12  = inst_sram_addr [12];
    assign tlb_s0_asid = csr_asid_asid;
    
    assign tlb_s1_vppn = data_sram_addr [31:13];
    assign tlb_s1_va_bit12 = data_sram_addr [12];
    assign tlb_s1_asid = csr_asid_asid;

    assign tlb_s3_vppn = wb_cacop_va[31:13] ;
    assign tlb_s3_va_bit12 = wb_cacop_va[12] ;
    assign tlb_s3_asid = csr_asid_asid ;
 
    tlb u_tlb (
    .clk(aclk),

    //  search ports0(for fetch)
    .s0_vppn(tlb_s0_vppn),            //虚拟访存地址 ??????31....13 ??????
    .s0_va_bit12(tlb_s0_va_bit12),                //虚拟访存地址的第12 ???
    .s0_asid(tlb_s0_asid),              //  CSR的ASID域，用于多线程比 ???
    .s0_found(tlb_s0_found),                //用于判断重填异常，页无效异常，特权等级不合规异常，页修改异常
    .s0_index(tlb_s0_index),         // 用于TLBSRCH指令，查找在第几 ???         
    .s0_ppn(tlb_s0_ppn),                //用于产生物理地址
    .s0_ps(tlb_s0_ps),                  //用于产生物理地址
    .s0_plv(tlb_s0_plv),                 //用于判断特权等级不合规异 ???
    .s0_mat(tlb_s0_mat),                 
    .s0_d(tlb_s0_d),                          //用于判断页修改异 ???
    .s0_v(tlb_s0_v),                           //用于判断页无效异常，页修改异 ???

    //  search ports1(for load/store)
    .s1_vppn(tlb_s1_vppn),            //虚拟访存地址 ??????31....13 ??????
    .s1_va_bit12(tlb_s1_va_bit12),                //虚拟访存地址的第12 ???
    .s1_asid(tlb_s1_asid),              //  CSR的ASID域，用于多线程比 ???
    .s1_found(tlb_s1_found),                //用于判断重填异常，页无效异常，特权等级不合规异常，页修改异常
    .s1_index(tlb_s1_index),       // 用于TLBSRCH指令，查找在第几 ???       
    .s1_ppn(tlb_s1_ppn),                //用于产生物理地址
    .s1_ps(tlb_s1_ps),                  //用于产生物理地址
    .s1_plv(tlb_s1_plv),                 //用于判断特权等级不合规异 ???
    .s1_mat(tlb_s1_mat),                 
    .s1_d(tlb_s1_d),                          //用于判断页修改异 ???
    .s1_v(tlb_s1_v),                           //用于判断页无效异常，页修改异 ???

    // search ports three
    .s2_vppn(tlb_s2_vppn),
    .s2_asid(tlb_s2_asid),
    .s2_found(tlb_s2_found),
    .s2_index(tlb_s2_index),

    //search ports4(for cacop)
    .s3_vppn(tlb_s3_vppn),            //虚拟访存地址 ??????31....13 ??????
    .s3_va_bit12(tlb_s3_va_bit12),                //虚拟访存地址的第12 ???
    .s3_asid(tlb_s3_asid),              //  CSR的ASID域，用于多线程比 ???
    .s3_found(tlb_s3_found),                //用于判断重填异常，页无效异常，特权等级不合规异常，页修改异常
    .s3_index(tlb_s3_index),       // 用于TLBSRCH指令，查找在第几 ???       
    .s3_ppn(tlb_s3_ppn),                //用于产生物理地址
    .s3_ps(tlb_s3_ps),                  //用于产生物理地址
    .s3_plv(tlb_s3_plv),                 //用于判断特权等级不合规异 ???
    .s3_mat(tlb_s3_mat),                 
    .s3_d(tlb_s3_d),                          //用于判断页修改异 ???
    .s3_v(tlb_s3_v),                           //用于判断页无效异常，页修改异 ???

    //write port
    .we(wb_tlb_we),                           //写使 ???
    .w_index(tlb_w_index),       //写的地址    
    .w_e(tlb_w_e),                               //写数 ???
    .w_vppn(tlb_w_vppn),                      //要写的虚双页
    .w_ps(tlb_w_ps),                       //要写的PS
    .w_asid(tlb_w_asid),                     // 要写的ASID
    .w_g(tlb_w_g),                             //要写的G
    .w_ppn0(tlb_w_ppn0),                  //要写的ppn0
    .w_plv0(tlb_w_plv0),                     //要写的plv0
    .w_mat0(tlb_w_mat0),                     //要写的mat0
    .w_d0(tlb_w_d0),                           //要写的d0
    .w_v0(tlb_w_v0),                             //要写的v0
    .w_ppn1(tlb_w_ppn1),                   //要写的ppn1
    .w_plv1(tlb_w_plv1),                     //要写的plv1
    .w_mat1(tlb_w_mat1),                    //要写的mat1
    .w_d1(tlb_w_d1),                            //要写的d1
    .w_v1(tlb_w_v1),                            //要写的v1

    //read port
    .r_index(csr_tlbidx_index),                  //读的地址    
    .r_e(tlb_r_e),                               //读数据的e
    .r_vppn(tlb_r_vppn),                      //要读的虚双页
    .r_ps(tlb_r_ps),                       //要读的PS
    .r_asid(tlb_r_asid),                     // 要读的ASID
    .r_g(tlb_r_g),                             //要读的G
    .r_ppn0(tlb_r_ppn0),                  //要读的ppn0
    .r_plv0(tlb_r_plv0),                     //要读的plv0
    .r_mat0(tlb_r_mat0),                     //要读的mat0
    .r_d0(tlb_r_d0),                           //要读的d0
    .r_v0(tlb_r_v0),                             //要读的v0
    .r_ppn1(tlb_r_ppn1),                   //要读的ppn1
    .r_plv1(tlb_r_plv1),                     //要读的plv1
    .r_mat1(tlb_r_mat1),                    //要读的mat1
    .r_d1(tlb_r_d1),                            //要读的d1
    .r_v1(tlb_r_v1),                            //要读的v1

    //invtlb opcode
    .invtlb_valid(wb_invtlb_valid),                     //用于Invtlb指令
    .invtlb_op(wb_invtlb_op)                 //Invtlb指令的操作码
);

    assign csr_tlbehi_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbehi_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_vppn : 19'b0;

    assign csr_tlbelo0_g_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo0_g_wvalue   =  (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_g : 1'b0;
                                     

    assign csr_tlbelo0_d_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo0_d_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_d0 : 1'b0;
                                

    assign csr_tlbelo0_v_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo0_v_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_v0 : 1'b0;
                                    

    assign csr_tlbelo0_plv_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo0_plv_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_plv0 : 2'b0;
                                    

    assign csr_tlbelo0_mat_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo0_mat_wvalue =  (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_mat0 : 2'b0;
                                    

    assign csr_tlbelo0_ppn_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo0_ppn_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_ppn0 : 20'b0;
                                    

    assign csr_tlbelo1_g_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo1_g_wvalue   =  (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_g : 1'b0;
                                    

    assign csr_tlbelo1_d_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo1_d_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_d1 : 1'b0;
                                

    assign csr_tlbelo1_v_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo1_v_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_v1 : 1'b0;
                               

    assign csr_tlbelo1_plv_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo1_plv_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_plv1 : 2'b0;
                                    

    assign csr_tlbelo1_mat_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo1_mat_wvalue =  (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_mat1: 2'b0;
                                   

    assign csr_tlbelo1_ppn_we = wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbelo1_ppn_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_ppn1 : 20'b0;
                                   

    assign csr_tlbidx_ps_we =  wb_inst_tlbrd ? 1'b1 : 1'b0;
    assign csr_tlbidx_ps_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  tlb_r_ps : 6'b0;
                                   

    assign csr_tlbidx_ne_we =  (wb_inst_tlbrd || wb_inst_tlbsrch) ? 1'b1 : 1'b0;
    assign csr_tlbidx_ne_wvalue = (wb_inst_tlbrd && tlb_r_e ) ?  1'b0 :
                                  (wb_inst_tlbrd && tlb_r_e!=1'b1 )?   1'b1 :
                                  (wb_inst_tlbsrch && tlb_s2_found) ?  1'b0: 1'b1;
                                  

    assign csr_asid_asid_we =  wb_inst_tlbrd  ? 1'b1 : 1'b0;
    assign csr_asid_asid_wvalue =  (wb_inst_tlbrd && tlb_r_e ) ?   tlb_r_asid : 10'b0  ;

    assign csr_tlbidx_index_we = (wb_inst_tlbsrch && tlb_s2_found);
    assign csr_tlbidx_index_wvalue  = tlb_s2_index;

    wire inst_way0_tag_we;
    wire inst_way1_tag_we;
    wire inst_way0_v_we;
    wire inst_way1_v_we;
    wire [7:0]inst_cacop_waddr;
    wire data_way0_tag_we;
    wire data_way1_tag_we;
    wire data_way0_v_we;
    wire data_way1_v_we;
    wire [7:0] data_cacop_waddr;

    wire [31:0] cacop_addr;   // 经过TLB转换后的地址
    wire cacop_dmw0_en;
    wire cacop_dmw1_en;

    
    assign cacop_tlb_ex = ((csr_crmd_da && csr_crmd_pg==1'b0)|| cacop_dmw0_en || cacop_dmw1_en || wb_cacop_need_phy==1'b0 || wb_cacop_en == 1'b0) ? 3'h0 :
                         (tlb_s3_found == 1'b0)                                              ? 3'h1 :
                         (tlb_s3_v == 1'b0 )                                                ? 3'h2 :
                         (tlb_s3_plv < csr_crmd_plv)                                         ? 3'h4 : 3'h0 ;
                         
    assign cacop_dmw0_en = csr_crmd_da == 1'b0 && csr_crmd_pg && ((csr_crmd_plv == 2'h3 && csr_dmw0_plv3)||(csr_crmd_plv == 2'h0 && csr_dmw0_plv0)) && wb_cacop_va[31:29] == csr_dmw0_vseg;
    assign cacop_dmw1_en = csr_crmd_da == 1'b0 && csr_crmd_pg && ((csr_crmd_plv == 2'h3 && csr_dmw1_plv3)||(csr_crmd_plv == 2'h0 && csr_dmw1_plv0)) && wb_cacop_va[31:29] == csr_dmw1_vseg;
    assign cacop_addr = (csr_crmd_da && csr_crmd_pg==1'b0 && wb_cacop_need_phy == 1'b0) ?  wb_cacop_va :
                        cacop_dmw0_en                       ?  {csr_dmw0_pseg,wb_cacop_va[28:0]} :
                        cacop_dmw1_en                       ?  {csr_dmw1_pseg,wb_cacop_va[28:0]} :  {tlb_s3_ppn[19:0],wb_cacop_va[11:0]};

    assign inst_way0_tag_we = wb_icache_tag_we && cacop_addr[0] == 1'b0 ;
    assign inst_way1_tag_we = wb_icache_tag_we && cacop_addr[0] == 1'b1 ;
    assign inst_way0_v_we = wb_icache_v_we && (cacop_addr[0] == 1'b0 || wb_cacop_need_phy);
    assign inst_way1_v_we = wb_icache_v_we && (cacop_addr[0] == 1'b1 || wb_cacop_need_phy);
    assign inst_cacop_waddr = cacop_addr[11:4];

    assign data_way0_tag_we = wb_dcache_tag_we && cacop_addr[0] == 1'b0 ;
    assign data_way1_tag_we = wb_dcache_tag_we && cacop_addr[0] == 1'b1 ;
    assign data_way0_v_we = wb_dcache_v_we && (cacop_addr[0] == 1'b0 || wb_cacop_need_phy);
    assign data_way1_v_we = wb_dcache_v_we && (cacop_addr[0] == 1'b1 || wb_cacop_need_phy);
    assign data_cacop_waddr = cacop_addr[11:4];


    icache u_icache (
    .clk(aclk),
    .resetn(aresetn) ,
    .inst_sram_req(inst_sram_req),     //  当前是否有访存请求信号，0表示没有 ?1表示 ?

    .inst_uncache(inst_uncache),
    
    .inst_sram_addr(inst_sram_addr),
    .inst_addr(inst_addr),
    
    .addr_ok(inst_sram_addr_ok),  //  cache 接收到地 ?请求
    .data_ok(inst_sram_data_ok),   //  cache 完成了数据传 ?
    .rdata(inst_sram_rdata),  //   ? cache 读出的数 ?

    // belows are related to AXI
    .axi_inst_sram_req(axi_inst_sram_req),      //  �? ? 线发出读请求�? ? 
    .axi_inst_sram_addr(axi_inst_sram_addr),    // �? ? 线发出的读请求的�? ?
    .ret_valid(axi_ret_valid),           //总线返回的数据有效信 ?
    .ret_last(axi_ret_last),
    .ret_data(axi_ret_data),     //总线返回的data数据
    .axi_inst_sram_addr_ok(axi_inst_sram_addr_ok),

    //below are related to cacop
    .cacop_way0_tag_we(inst_way0_tag_we),
    .cacop_way1_tag_we(inst_way1_tag_we),
    .cacop_way0_v_we(inst_way0_v_we),
    .cacop_way1_v_we(inst_way1_v_we),
    .inst_cacop_waddr(inst_cacop_waddr),
    .wb_cacop_en(wb_cacop_en),

    .id_need_cancel(id_need_cancel)
);

    dcache u_dcache(
        .clk(aclk),
        .resetn(aresetn),
        .data_sram_req(data_sram_req),

        .data_uncache(data_uncache),

        .data_sram_addr(data_sram_addr),
        .data_addr(data_addr),

        .addr_ok(data_sram_addr_ok),
        .data_ok(data_sram_data_ok),
        .rdata(data_sram_rdata),

        .axi_data_sram_req(axi_data_sram_req),
        .axi_data_sram_addr_ok(axi_data_sram_addr_ok),
        .axi_data_sram_addr(axi_data_sram_addr),
        .ret_valid(data_ret_valid),
        .ret_last(axi_ret_last),
        .ret_data(axi_data_ret_data),
        .op(data_sram_wr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_wstrb(data_sram_wstrb),
        .axi_data_sram_data_ok(axi_data_sram_data_ok),
        .axi_data_sram_wr(axi_data_sram_wr),
        
        .data_sram_size(data_sram_size),

        .axi_data_sram_size(axi_data_sram_size),
        .axi_data_sram_wdata(axi_data_sram_wdata),
        .axi_data_sram_wstrb(axi_data_sram_wstrb),
        .axi_data_sram_len(axi_data_sram_len),

        .cacop_way0_tag_we(data_way0_tag_we),
        .cacop_way1_tag_we(data_way1_tag_we),
        .cacop_way0_v_we(data_way0_v_we),
        .cacop_way1_v_we(data_way1_v_we),
        .data_cacop_waddr(data_cacop_waddr),
        .wb_cacop_en(wb_cacop_en)
        
    );

    wire excp_flush ;
    assign excp_flush = (csr_ex == 1'b1) && ws_valid ;
    wire ertn_flush ;
    assign ertn_flush = (wb_is_ertn == 1'b1) && ws_valid ;








// below are related to diffset

`ifdef DIFFTEST_EN
// difftest
// from wb_stage
wire            ws_valid_diff       ;
wire            cnt_inst_diff       ;
wire    [63:0]  timer_64_diff       ;
wire    [ 7:0]  inst_ld_en_diff     ;
wire    [31:0]  ld_paddr_diff       ;
wire    [31:0]  ld_vaddr_diff       ;
wire    [ 7:0]  inst_st_en_diff     ;
wire    [31:0]  st_paddr_diff       ;
wire    [31:0]  st_vaddr_diff       ;
wire    [31:0]  st_data_diff        ;
wire            csr_rstat_en_diff   ;
wire    [31:0]  csr_data_diff       ;

wire inst_valid_diff = ws_valid_diff;
reg             cmt_valid           ;
reg             cmt_cnt_inst        ;
reg     [63:0]  cmt_timer_64        ;
reg     [ 7:0]  cmt_inst_ld_en      ;
reg     [31:0]  cmt_ld_paddr        ;
reg     [31:0]  cmt_ld_vaddr        ;
reg     [ 7:0]  cmt_inst_st_en      ;
reg     [31:0]  cmt_st_paddr        ;
reg     [31:0]  cmt_st_vaddr        ;
reg     [31:0]  cmt_st_data         ;
reg             cmt_csr_rstat_en    ;
reg     [31:0]  cmt_csr_data        ;

reg             cmt_wen             ;
reg     [ 7:0]  cmt_wdest           ;
reg     [31:0]  cmt_wdata           ;
reg     [31:0]  cmt_pc              ;
reg     [31:0]  cmt_inst            ;

reg             cmt_excp_flush      ;
reg             cmt_ertn            ;
reg     [5:0]   cmt_csr_ecode       ;
reg             cmt_tlbfill_en      ;
reg     [4:0]   cmt_rand_index      ;

// to difftest debug
reg             trap                ;
reg     [ 7:0]  trap_code           ;
reg     [63:0]  cycleCnt            ;
reg     [63:0]  instrCnt            ;

// from regfile
wire    [31:0]  regs[31:0]          ;

// from csr
wire    [31:0]  csr_crmd_diff_0     ;
wire    [31:0]  csr_prmd_diff_0     ;
wire    [31:0]  csr_ecfg_diff_0     ;
wire    [31:0]  csr_estat_diff_0    ;
wire    [31:0]  csr_era_diff_0      ;
wire    [31:0]  csr_badv_diff_0     ;
wire	[31:0]  csr_eentry_diff_0   ;
wire 	[31:0]  csr_tlbidx_diff_0   ;
wire 	[31:0]  csr_tlbehi_diff_0   ;
wire 	[31:0]  csr_tlbelo0_diff_0  ;
wire 	[31:0]  csr_tlbelo1_diff_0  ;
wire 	[31:0]  csr_asid_diff_0     ;
wire 	[31:0]  csr_save0_diff_0    ;
wire 	[31:0]  csr_save1_diff_0    ;
wire 	[31:0]  csr_save2_diff_0    ;
wire 	[31:0]  csr_save3_diff_0    ;
wire 	[31:0]  csr_tid_diff_0      ;
wire 	[31:0]  csr_tcfg_diff_0     ;
wire 	[31:0]  csr_tval_diff_0     ;
wire 	[31:0]  csr_ticlr_diff_0    ;
wire 	[31:0]  csr_llbctl_diff_0   ;
wire 	[31:0]  csr_tlbrentry_diff_0;
wire 	[31:0]  csr_dmw0_diff_0     ;
wire 	[31:0]  csr_dmw1_diff_0     ;
wire 	[31:0]  csr_pgdl_diff_0     ;
wire 	[31:0]  csr_pgdh_diff_0     ;



// difftest from wb_stage
assign ws_valid_diff = ws_valid &&  !(csr_ex == 1'b1) ;
assign cnt_inst_diff = wb_inst_cnt;     //  要补id 
assign timer_64_diff = wb_timer_64;     //  要补id 
assign inst_ld_en_diff =  wb_inst_ld_en ;    //  要补id 
assign ld_paddr_diff  =  wb_data_phy_addr ;     // 要补 mem 
assign ld_vaddr_diff  =  wb_data_addr ;     

assign inst_st_en_diff = wb_inst_st_en ;  //  要补id 
assign st_paddr_diff  = ld_paddr_diff ;
assign st_vaddr_diff  = wb_data_addr  ;

assign st_data_diff = wb_dram_wdata ;
assign csr_rstat_en_diff = wb_csr_rstat_en ;  //要补id

assign csr_data_diff = csr_rvalue ;         // 要补id

always @(posedge aclk) begin
    if (rst) begin
        {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr, cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data, cmt_csr_rstat_en, cmt_csr_data} <= 0;
        {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
        {trap, trap_code, cycleCnt, instrCnt} <= 0;
    end else if (~trap) begin
        cmt_valid       <= inst_valid_diff          ;
        cmt_cnt_inst    <= cnt_inst_diff            ;
        cmt_timer_64    <= timer_64_diff            ;
        cmt_inst_ld_en  <= inst_ld_en_diff          ;
        cmt_ld_paddr    <= ld_paddr_diff            ;
        cmt_ld_vaddr    <= ld_vaddr_diff            ;
        cmt_inst_st_en  <= inst_st_en_diff          ;
        cmt_st_paddr    <= st_paddr_diff            ;
        cmt_st_vaddr    <= st_vaddr_diff            ;
        cmt_st_data     <= st_data_diff             ;
        cmt_csr_rstat_en<= csr_rstat_en_diff        ;
        cmt_csr_data    <= csr_data_diff            ;

        cmt_wen     <=  debug0_wb_rf_wen            ;
        cmt_wdest   <=  {3'd0, debug0_wb_rf_wnum}   ;
        cmt_wdata   <=  debug0_wb_rf_wdata          ;
        cmt_pc      <=  debug0_wb_pc                ;
        cmt_inst    <=  debug0_wb_inst              ;

        cmt_excp_flush  <= excp_flush               ;               
        cmt_ertn        <= ertn_flush               ;               
        cmt_csr_ecode   <= wb_ecode                 ;
        cmt_tlbfill_en  <= wb_tlb_fill_en            ;               //  要补id
        cmt_rand_index  <= tlb_w_index               ;

        trap            <= 0                        ;
        trap_code       <= regs[10][7:0]            ;
        cycleCnt        <= cycleCnt + 1             ;
        instrCnt        <= instrCnt + inst_valid_diff;
    end
end

    assign regs = rf_to_diff ;                                     


    //以下这些要补csr

assign csr_crmd_diff_0       = csr_crmd_rvalue;
assign csr_prmd_diff_0       = csr_prmd_rvalue;
assign csr_ecfg_diff_0       = csr_ecfg_rvalue;
assign csr_estat_diff_0      = csr_estat_rvalue;
assign csr_era_diff_0        = csr_era_rvalue;
assign csr_badv_diff_0       = csr_badv_rvalue;
assign csr_eentry_diff_0     = csr_eentry_rvalue;
assign csr_tlbidx_diff_0     = csr_tlbidx_rvalue;
assign csr_tlbehi_diff_0     = csr_tlbehi_rvalue;
assign csr_tlbelo0_diff_0    = csr_tlbelo0_rvalue;
assign csr_tlbelo1_diff_0    = csr_tlbelo1_rvalue;
assign csr_asid_diff_0       = csr_asid_rvalue;
assign csr_save0_diff_0      = csr_save0_rvalue;
assign csr_save1_diff_0      = csr_save1_rvalue;
assign csr_save2_diff_0      = csr_save2_rvalue;
assign csr_save3_diff_0      = csr_save3_rvalue;
assign csr_tid_diff_0        = csr_tid_rvalue;
assign csr_tcfg_diff_0       = csr_tcfg_rvalue;
assign csr_tval_diff_0       = csr_tval_rvalue;
assign csr_ticlr_diff_0      = csr_ticlr_rvalue;
assign csr_llbctl_diff_0     = csr_llbctl_rvalue;
assign csr_tlbrentry_diff_0  = csr_tlbrentry_rvalue;
assign csr_dmw0_diff_0       = csr_dmw0_rvalue;
assign csr_dmw1_diff_0       = csr_dmw1_rvalue;
assign csr_pgdl_diff_0       = csr_pgdl_rvalue;
assign csr_pgdh_diff_0       = csr_pgdh_rvalue;

DifftestInstrCommit DifftestInstrCommit(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_valid      ),
    .pc                 (cmt_pc         ),
    .instr              (cmt_inst       ),
    .skip               (0              ),
    .is_TLBFILL         (cmt_tlbfill_en ),
    .TLBFILL_index      (cmt_rand_index ),
    .is_CNTinst         (cmt_cnt_inst   ),
    .timer_64_value     (cmt_timer_64   ),
    .wen                (cmt_wen        ),
    .wdest              (cmt_wdest      ),
    .wdata              (cmt_wdata      ),
    .csr_rstat          (cmt_csr_rstat_en),
    .csr_data           (cmt_csr_data   )
);

DifftestExcpEvent DifftestExcpEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .excp_valid         (cmt_excp_flush ),
    .eret               (cmt_ertn       ),
    .intrNo             (csr_estat_diff_0[12:2]),
    .cause              (cmt_csr_ecode  ),
    .exceptionPC        (cmt_pc         ),
    .exceptionInst      (cmt_inst       )
);

DifftestTrapEvent DifftestTrapEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .valid              (trap           ),
    .code               (trap_code      ),
    .pc                 (cmt_pc         ),
    .cycleCnt           (cycleCnt       ),
    .instrCnt           (instrCnt       )
);

DifftestStoreEvent DifftestStoreEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_st_en ),
    .storePAddr         (cmt_st_paddr   ),
    .storeVAddr         (cmt_st_vaddr   ),
    .storeData          (cmt_st_data    )
);

DifftestLoadEvent DifftestLoadEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_ld_en ),
    .paddr              (cmt_ld_paddr   ),
    .vaddr              (cmt_ld_vaddr   )
);

DifftestCSRRegState DifftestCSRRegState(
    .clock              (aclk               ),
    .coreid             (0                  ),
    .crmd               (csr_crmd_diff_0    ),
    .prmd               (csr_prmd_diff_0    ),
    .euen               (0                  ),
    .ecfg               (csr_ecfg_diff_0    ),
    .estat              (csr_estat_diff_0   ),
    .era                (csr_era_diff_0     ),
    .badv               (csr_badv_diff_0    ),
    .eentry             (csr_eentry_diff_0  ),
    .tlbidx             (csr_tlbidx_diff_0  ),
    .tlbehi             (csr_tlbehi_diff_0  ),
    .tlbelo0            (csr_tlbelo0_diff_0 ),
    .tlbelo1            (csr_tlbelo1_diff_0 ),
    .asid               (csr_asid_diff_0    ),
    .pgdl               (csr_pgdl_diff_0    ),
    .pgdh               (csr_pgdh_diff_0    ),
    .save0              (csr_save0_diff_0   ),
    .save1              (csr_save1_diff_0   ),
    .save2              (csr_save2_diff_0   ),
    .save3              (csr_save3_diff_0   ),
    .tid                (csr_tid_diff_0     ),
    .tcfg               (csr_tcfg_diff_0    ),
    .tval               (csr_tval_diff_0    ),
    .ticlr              (csr_ticlr_diff_0   ),
    .llbctl             (csr_llbctl_diff_0  ),
    .tlbrentry          (csr_tlbrentry_diff_0),
    .dmw0               (csr_dmw0_diff_0    ),
    .dmw1               (csr_dmw1_diff_0    )
);

DifftestGRegState DifftestGRegState(
    .clock              (aclk       ),
    .coreid             (0          ),
    .gpr_0              (0          ),
    .gpr_1              (regs[1]    ),
    .gpr_2              (regs[2]    ),
    .gpr_3              (regs[3]    ),
    .gpr_4              (regs[4]    ),
    .gpr_5              (regs[5]    ),
    .gpr_6              (regs[6]    ),
    .gpr_7              (regs[7]    ),
    .gpr_8              (regs[8]    ),
    .gpr_9              (regs[9]    ),
    .gpr_10             (regs[10]   ),
    .gpr_11             (regs[11]   ),
    .gpr_12             (regs[12]   ),
    .gpr_13             (regs[13]   ),
    .gpr_14             (regs[14]   ),
    .gpr_15             (regs[15]   ),
    .gpr_16             (regs[16]   ),
    .gpr_17             (regs[17]   ),
    .gpr_18             (regs[18]   ),
    .gpr_19             (regs[19]   ),
    .gpr_20             (regs[20]   ),
    .gpr_21             (regs[21]   ),
    .gpr_22             (regs[22]   ),
    .gpr_23             (regs[23]   ),
    .gpr_24             (regs[24]   ),
    .gpr_25             (regs[25]   ),
    .gpr_26             (regs[26]   ),
    .gpr_27             (regs[27]   ),
    .gpr_28             (regs[28]   ),
    .gpr_29             (regs[29]   ),
    .gpr_30             (regs[30]   ),
    .gpr_31             (regs[31]   )
);


`endif
 


endmodule