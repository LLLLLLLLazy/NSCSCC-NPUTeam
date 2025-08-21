`include "header.h"
module EX1
#(
    parameter TLBNUM = 16
)
(
    input clk,
    input reset,
    input flush,
    // forward
    output [`WIDTH_EX1_FORWARD_BUS-1:0] EX1_forward_bus,
    //control
    input EX2_stall,
    input MEM_stall,
    output EX1_stall,
    input ID_EX1_valid,
    output reg EX1_valid,
    output EX1_EX2_valid,
    input  [`WIDTH_ID_EX1_BUS -1 : 0] ID_EX1_bus,
    output [`WIDTH_EX1_EX2_BUS-1 -5+$clog2(TLBNUM): 0] EX1_EX2_bus,
    output [`WIDTH_BR_BUS - 1 : 0]    br_bus,
    //分支预测
    output taken_update_en,
    output target_update_en,

    output [31:0] EX1_pc,
    output        real_taken,
    output [31:0] real_target,
    // with mmu 
    input  [31:0] csr_tlbehi_rvalue,
    input  [ 9:0] csr_asid_asid,
    input  [89+$clog2(TLBNUM):0] tlb_data,
    input  [ 4:0] EX1_tlb_excps,
    input         mmu_data_uncache_en,    
    input         mmu_sc_addr_eq,
    input  [31:0] sc_ll_paddr,
    input  [31:0] EX1_data_paddr,
    output [31:0] EX1_data_vaddr,
    output        EX1_load,
    output        EX1_store,
    output        EX1_cacop,
    output [1:0] EX1_cache_op_mode, //to mmu    
    input        data_unhit,

    //to TLB
    output [18:0] s1_vppn,
    output        s1_va_bit12,
    output [ 9:0] s1_asid,
    input         s1_unbusy,
    output        s1_valid,
    input         s1_ok,

    //cache
    output data_valid,
    input  icache_unbusy,
    input  dcache_unbusy,
    output [ 7:0] data_index,
    output [ 3:0] data_offset,
    output [ 3:0] data_wstrb,
    output [ 2:0] data_size,
    output [31:0] data_wdata,
    output        data_op,
    output [1:0] cache_op_mode,
    output       icacop_op_en,
    output       dcacop_op_en,

    output preld_en

`ifdef DIFFTEST_EN
    ,
    input      [`DIFF_WIDTH_ID_EX1_BUS -1 : 0] ID_EX1_diff_bus,
    output reg [`DIFF_WIDTH_EX1_EX2_BUS-1 : 0] EX1_EX2_diff_bus
`endif
);

`ifdef DIFFTEST_EN
    always@(posedge clk) begin
        if(~stall) begin
            EX1_EX2_diff_bus <= ID_EX1_diff_bus;
        end
    end
`endif

//cache
    wire op_icache;
    wire op_dcache;
    wire access_dcache;
//bpu and branch predict
    wire [8:0]  br_op;        //bus
    wire [25:0] offs_26;      //bus
    wire br_taken;             //跳转执行信号，高电平有效
    wire [31:0] br_target;     //跳转地址目标
    //跳转指令判断
    wire s_rj_smaller_rd;  
    wire us_rj_smaller_rd;
    wire rj_equal_rd;

    wire btb_miss;             //bus
    wire pred_taken;           //bus
    wire [31:0] pred_target;   //bus
    wire taken; 
    wire [31:0] target;


// tlb
    wire [19:0] EX1_vpn;
    wire [11:0] blank;

    wire [4:0]  tlb_op;

    wire [ 9:0] invtlb_asid;
    wire [18:0] invtlb_vppn;
    wire        inst_invtlb;
    wire [ 4:0] invtlb_op;

    reg s1_ok_buf;
    reg s1_valid_reg;
    wire tlb_trans;
// forward
    wire [31:0] EX1_data;
    wire [ 4:0] EX1_dest;
    wire EX1_data_not_prepared;
    wire EX1_data_used;

//bus
    reg [`WIDTH_ID_EX1_BUS-1 : 0] ID_EX1_reg;
    wire [ 2:0] sel_alu_src1;
    wire [ 2:0] sel_alu_src2;
    wire [31:0] EX1_rdata_rkd;
    wire [31:0] EX1_rdata_rj;
    wire [18:0] alu_op;
    wire [ 2:0] EX1_mem_type;
    wire [ 4:0] dest;
    wire EX1_load_op;
    wire EX1_store_op;

    wire [14:0] ID_excp_num;
    wire ID_excp;

    wire inst_ll_w;
    wire inst_sc_w;
    wire inst_preld;

    wire inst_cacop_valid;
    wire [ 4:0] cacop_code;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_ertn;
    wire csr_we;
    wire [13:0] csr_num;
    wire [ 4:0] res_from;
    wire gr_we;

// control
    wire stall;

    wire EX1_flush;
    wire EX2_flush;

//alu
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] EX1_extend_res;
    wire [31:0] alu_result;
    wire [31:0] real_alu_result;

    wire alu_valid;
    wire div_en;
    wire mul_en;

    wire op_mul  ;
    wire op_mulh ;
    wire op_mulhu;
    wire op_div  ;
    wire op_divu ;
    wire op_mod  ;
    wire op_modu ;

    wire [ 2:0] mul_op;
    wire [31:0] res_mul;
    wire mul_complete;

    wire div_signed;
    wire div_complete;
    wire [31:0] result_s;
    wire [31:0] result_r;
    
    wire Is_DM;   // is div or mod or mul
    wire [31:0] dm_res;

//cache values
    wire [ 3:0] bpos;
    wire [ 1:0] hpos;
    wire [31:0] bwdata;
    wire [31:0] hwdata;
    wire [ 3:0] EX1_data_wstrb;
    wire [31:0] EX1_data_wdata;
    wire [ 2:0] EX1_data_size;

//ex
    wire EX1_excp;
    wire [14:0] EX1_excp_num;
    wire [31:0] badvaddr;

// forward
    assign EX1_forward_bus = {EX1_dest, EX1_data_not_prepared, EX1_data};
    assign EX1_dest  = dest & {5{EX1_valid & gr_we}};
    assign EX1_data_not_prepared = ~EX1_data_used;
    assign EX1_data_used = EX1_valid & !res_from & ~Is_DM;
    assign EX1_data = alu_result;

// bus to EX2
assign EX1_EX2_bus = {
    // ---451---
    // 173
    inst_ll_w,          // 1
    inst_sc_w,          // 1
    icacop_op_en,       // 1
    access_dcache,      // 1
    mmu_data_uncache_en,// 1
    mmu_sc_addr_eq,
    sc_ll_paddr,        // 32
    invtlb_asid,        // 10
    invtlb_vppn,        // 19
    invtlb_op,          // 5
    tlb_op,             // 5
    tlb_data,           // 95
    inst_ertn,          // 1
    // 47
    csr_we,           // 1
    csr_num,          // 14
    res_from,         // 5
    gr_we,            // 1
    EX1_load_op,      // 1
    EX1_store_op,     // 1
    EX1_mem_type,     // 3
    dest,             // 5
    EX1_excp_num,     // 15
    EX1_excp,         // 1
    // 231
    badvaddr,         // 32
    EX1_data_paddr,   // 32
    real_alu_result,  // 32
    EX1_data_wstrb,   // 4
    EX1_data_size,    // 3
    EX1_data_wdata,   // 32
    EX1_rdata_rkd,    // 32
    EX1_rdata_rj,     // 32
    EX1_pc            // 32
};

//bus
    always@(posedge clk) begin
        if(reset) begin
            ID_EX1_reg <= `WIDTH_ID_EX1_BUS'b0;
        end
        else if(~stall) begin
            ID_EX1_reg <= ID_EX1_bus;
        end
    end

assign {
        alu_src1,
        alu_src2,
        s1_vppn,       //19
        EX1_data_vaddr,//32
        br_op,       //9
        offs_26,     //26
        btb_miss,    //1
        pred_taken,  //1
        pred_target, //32
        inst_preld,
        inst_ll_w,
        inst_sc_w,
        inst_cacop_valid,
        cacop_code,
        inst_invtlb,
        invtlb_op,
        inst_tlbwr,
        inst_tlbfill,
        inst_tlbsrch,
        inst_tlbrd,
        ID_excp_num,
        inst_ertn,
        ID_excp,
        csr_we,
        csr_num,
        res_from,
        gr_we,
        sel_alu_src1,
        EX1_load_op,
        EX1_store_op,
        sel_alu_src2,
        EX1_mem_type,
        dest,
        EX1_rdata_rkd,
        EX1_rdata_rj,
        EX1_extend_res,
        alu_op,
        EX1_pc
} = ID_EX1_reg;

// 前递

//control
    assign stall = EX1_stall | EX2_stall | MEM_stall;
    assign EX1_stall = ~reset & EX1_valid & (~alu_valid | tlb_trans & ~(s1_ok | s1_ok_buf) | ~dcache_unbusy & (access_dcache | op_dcache) | ~icache_unbusy & op_icache); // 如果访问tlb过程中间出现flush，等结果返回之后再流
    assign EX1_EX2_valid = EX1_valid & ~EX1_stall;

    always@(posedge clk) begin
        if(reset | flush) begin
            EX1_valid <= 1'b0;
        end
        else if(~stall) begin
            if(taken) begin
                EX1_valid <= 1'b0;
            end
            else begin
                EX1_valid <= ID_EX1_valid;
            end
        end
    end

//ALU
    ALU alu(
        .clk(clk),
        .reset(reset),
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );

//exception
    assign EX1_excp_num = {EX1_tlb_excps, ID_excp_num[9:0]};
    assign EX1_excp = |EX1_excp_num;
    assign badvaddr = {32{  |ID_excp_num[8:0] }} & EX1_pc | 
                      {32{~(|ID_excp_num[8:0])}} & EX1_data_vaddr;

//cache values
    assign bpos = {EX1_data_vaddr[1:0] == 2'b11,
                   EX1_data_vaddr[1:0] == 2'b10,
                   EX1_data_vaddr[1:0] == 2'b01,
                   EX1_data_vaddr[1:0] == 2'b00};

    assign hpos = {{{EX1_data_vaddr[1] == 1'b1}},
                   {{EX1_data_vaddr[1] == 1'b0}}};

    assign bwdata = {{8{bpos[3]}} & EX1_rdata_rkd[7:0],
                     {8{bpos[2]}} & EX1_rdata_rkd[7:0],
                     {8{bpos[1]}} & EX1_rdata_rkd[7:0],
                     {8{bpos[0]}} & EX1_rdata_rkd[7:0]};

    assign hwdata = {{16{hpos[1]}} & EX1_rdata_rkd[15:0],
                     {16{hpos[0]}} & EX1_rdata_rkd[15:0]};


    assign EX1_data_wstrb = {4{EX1_mem_type[0]}}    & {{2{hpos[1]}}, {2{hpos[0]}}} |
                            {4{EX1_mem_type[1]}}    &  bpos                        |
                            {4{!EX1_mem_type[1:0]}} &  4'b1111;

    assign EX1_data_size = {3{EX1_mem_type[0]}} & 3'b001 |
                           {3{EX1_mem_type[1]}} & 3'b000 |
                           {3{!EX1_mem_type[1:0]}} & 3'b010;

    assign EX1_data_wdata = {32{EX1_mem_type[0]}} & hwdata |
                            {32{EX1_mem_type[1]}} & bwdata |
                            {32{!(|EX1_mem_type[1:0])}} & EX1_rdata_rkd;


//TLB and MMU
    assign EX1_load  = EX1_load_op  & EX1_valid;
    assign EX1_store = EX1_store_op & EX1_valid;
    assign EX1_cacop = inst_cacop_valid & EX1_valid;
    assign EX1_cache_op_mode = cacop_code[4:3];
    // assign EX1_data_vaddr = EX1_rdata_rj + EX1_extend_res;
    assign tlb_op = {inst_invtlb, inst_tlbwr, inst_tlbfill, inst_tlbsrch, inst_tlbrd};
    assign invtlb_asid = EX1_rdata_rj [9:0];
    assign invtlb_vppn = EX1_rdata_rkd[31:13];


    // assign s1_vppn     = {19{ inst_tlbsrch}} & csr_tlbehi_rvalue[31:13] |
    //                      {19{~inst_tlbsrch}} & EX1_data_vaddr[31:13];
    assign s1_va_bit12 = ~inst_tlbsrch & EX1_data_vaddr[12];
    assign s1_asid     = csr_asid_asid;


//div and mul

    assign op_mul  = alu_op[12];
    assign op_mulh = alu_op[13];
    assign op_mulhu= alu_op[14];
    assign op_div  = alu_op[15];
    assign op_divu = alu_op[16];
    assign op_mod  = alu_op[17];
    assign op_modu = alu_op[18];

    assign div_signed = op_div | op_mod; // div mod
    assign mul_op     = {op_mulhu, op_mulh, op_mul};

    assign div_en = EX1_valid & (|alu_op[18:15]);
    assign mul_en = EX1_valid & (|alu_op[14:12]);

    assign Is_DM = div_en | mul_en;
    assign alu_valid = ~reset & (mul_complete | div_complete | ~Is_DM);

    assign real_alu_result = {32{ Is_DM}} & dm_res |
                             {32{~Is_DM}} & alu_result;

    assign dm_res = {32{op_mul | op_mulh | op_mulhu}} & res_mul  | 
                    {32{op_div | op_divu}}            & result_s |
                    {32{op_mod | op_modu}}            & result_r ;


    mul mul_signed(
        .clk(clk),
        .rst_n(reset),
        .a(alu_src1),
        .b(alu_src2),
        .start(mul_en & !mul_complete),
        .mul_op(mul_op),
        .mul_result(res_mul),
        .mul_done(mul_complete)
    );


    div div_new(
            .div_clk(clk),
            .reset(reset),
            .div(div_en),
            .div_signed(div_signed),
            .x(alu_src1),
            .y(alu_src2),
            .s(result_s),
            .r(result_r),
            .complete(div_complete)
        );


//应该是包含了llsc在里面
    assign tlb_trans = ((EX1_load_op | EX1_store_op | inst_cacop_valid  | inst_preld) & data_unhit | (|tlb_op)) & ~(|EX1_excp_num[9:0]);
    assign s1_valid = s1_valid_reg & ~(s1_ok | s1_ok_buf) & tlb_trans & EX1_valid & ~flush; // 一开始发现不对就不发，中间flush不影响
    always@(posedge clk) begin
        if(reset) begin
            s1_ok_buf <= 1'b0;
            s1_valid_reg <= 1'b0;
        end
        else if(~stall) begin
            s1_valid_reg <= 1'b1;
            s1_ok_buf <= 1'b0;
        end
        else if(s1_ok) begin
            s1_valid_reg <= 1'b0;
            s1_ok_buf <= 1'b1;
        end
    end

// bpu
    //分支
    assign rj_equal_rd = (EX1_rdata_rj == EX1_rdata_rkd);
    assign s_rj_smaller_rd = ($signed(EX1_rdata_rj) < $signed(EX1_rdata_rkd));
    assign us_rj_smaller_rd= (EX1_rdata_rj < EX1_rdata_rkd);

    br_unit br( .reset(reset),
                .jump_op(br_op),    
                .equal(rj_equal_rd),
                .sign_rj_rd(s_rj_smaller_rd),
                .unsign_rj_rd(us_rj_smaller_rd),
                .off_26(offs_26),
                .GR_rj(EX1_rdata_rj),
                .br_pc(EX1_pc),
                .br_npc(br_target),
                .RC(br_taken)
    );

    // repair
    assign taken = EX1_valid & !EX1_stall & (taken_update_en | target_update_en);
    assign target = {32{ br_taken}} & br_target |
                    {32{~br_taken}} & EX1_pc + 4;
    assign br_bus = {taken, target};

    assign taken_update_en  = EX1_valid & ~ID_excp & (pred_taken != br_taken);
    assign target_update_en = EX1_valid & ~ID_excp & pred_taken & br_taken & (btb_miss |  pred_target != br_target);
    assign real_taken       = br_taken;
    assign real_target      = br_target;

//cache
    assign data_valid = access_dcache & ~stall & EX1_valid;
    assign access_dcache = (EX1_load_op | EX1_store_op) & ~flush & ~ID_excp;

    assign {data_index, data_offset} = EX1_data_paddr[11:0];
    assign data_wstrb = EX1_data_wstrb;
    assign data_size  = EX1_data_size;
    assign data_wdata = EX1_data_wdata;
    assign data_op    = EX1_store_op;

    assign cache_op_mode = EX1_cache_op_mode; // to cache
    assign icacop_op_en = op_icache & EX1_valid & ~stall & ~ID_excp & ~flush;
    assign dcacop_op_en = op_dcache & EX1_valid & ~stall & ~ID_excp & ~flush;
    assign op_icache = inst_cacop_valid & (cacop_code[2:0] == 3'b000);
    assign op_dcache = inst_cacop_valid & (cacop_code[2:0] == 3'b001);

//preld
    assign preld_en = inst_preld & EX1_valid & ~stall & ~ID_excp & ~flush;
endmodule