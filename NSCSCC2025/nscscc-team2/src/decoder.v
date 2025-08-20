module decoder(
    input  wire [31:0]  inst_in,     
    input  wire [31:0]  pc,
    input  wire [ 1:0]  crmd_plv,
   
    output wire [12:0]  alu_op,
    output wire         src1_is_pc,
    output reg  [31:0]  imm,
    output wire         src2_is_imm,
    output wire [ 4:0]  rd,
    output wire [ 4:0]  rj,
    output wire [ 4:0]  rk,
    output wire [ 3:0]  data_sram_we,
    output wire [ 2:0]  rf_wdata_sel,
    output wire         rf_we,
    output wire [ 4:0]  rf_waddr,
    output wire         src_reg_is_rd,
    output wire [ 1:0]  ex_result_sel,
    output wire         mmd_is_signed,    // mul or mod or div is signed
    output wire         mul_need_hi,      // need the high 32 bits result of multiplying 
    output wire         ld_ext_is_signed, // ld use signed extend
    output wire [ 3:0]  ld_width,         // the width of ld or st
    output wire         csr_we,
    output wire         is_csr_op,
    output wire         new_refetch_flag,
    output wire [ 5:0]  dif_ld_info,
    output wire         ipe_ex,
    output wire         inst_branch,
    output wire         need_addr_alu,

    output wire [11:0]  i12,
    output wire [19:0]  i20,
    output wire [15:0]  i16,
    output wire [25:0]  i26,
    output wire [ 4:0]  ui5,
    output wire [13:0]  csr_num,

    output wire         is_ld,
    output wire         is_st,
    output wire         inst_st_b,
    output wire         inst_st_h,
    output wire         is_cntinst,

    output wire         inst_jirl,
    output wire         inst_b,
    output wire         inst_bl,
    output wire         inst_beq,
    output wire         inst_bne,
    output wire         inst_blt,
    output wire         inst_bge,
    output wire         inst_bltu,
    output wire         inst_bgeu,
    output wire         inst_csrxchg,
    output wire         inst_ertn,
    output wire         inst_syscall,
    output wire         inst_break,
    output wire         inst_tlbsrch,
    output wire         inst_invtlb,
    output wire         inst_tlbwr,
    output wire         inst_tlbrd,
    output wire         inst_cacop,
    output wire         inst_cpucfg,
    output wire         inst_ll_w,
    output wire         inst_sc_w,
    output wire         inst_ibar,
    output wire         inst_dbar,
    output wire         inst_tlbfill,
    output wire         inst_idle,

    output wire [ 4:0]  cacop_code,

    output wire         not_inst
);

parameter CRMD      = 14'h00;
parameter ASID      = 14'h18;
parameter TLBEHI    = 14'h11;
parameter TLBELO0   = 14'h12;
parameter TLBELO1   = 14'h13;
parameter TLBIDX    = 14'h10;
parameter ESTAT     = 14'h05;
parameter DMW0      = 14'h180;
parameter DMW1      = 14'h181;
parameter EENTRY    = 14'h0c;
parameter TLBRENTRY = 14'h88;

wire [31:0] inst;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

assign inst = inst_in;

assign rd   = inst[4:0];
assign rj   = inst[9:5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24:5];
assign i16  = inst[25:10];
assign i26  = { inst[9:0], inst[25:10] };
assign ui5  = inst[14:10];

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

wire inst_add_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
wire inst_sub_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
wire inst_slt       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
wire inst_sltu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
wire inst_nor       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
wire inst_and       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
wire inst_or        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
wire inst_xor       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
wire inst_sll_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
wire inst_srl_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
wire inst_sra_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

wire inst_mul_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
wire inst_mulh_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
wire inst_mulh_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
wire inst_div_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
wire inst_mod_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
wire inst_div_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
wire inst_mod_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

wire inst_slli_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
wire inst_srli_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
wire inst_srai_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
wire inst_addi_w    = op_31_26_d[6'h00] & op_25_22_d[4'ha];
wire inst_andi      = op_31_26_d[6'h00] & op_25_22_d[4'hd];
wire inst_ori       = op_31_26_d[6'h00] & op_25_22_d[4'he];
wire inst_xori      = op_31_26_d[6'h00] & op_25_22_d[4'hf];
wire inst_slti      = op_31_26_d[6'h00] & op_25_22_d[4'h8];
wire inst_sltui     = op_31_26_d[6'h00] & op_25_22_d[4'h9];
wire inst_lu12i_w   = op_31_26_d[6'h05] & ~inst[25];
wire inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];

wire inst_preld     = op_31_26_d[6'h0a] & op_25_22_d[4'hb]; // hint = rd

wire inst_ld_w      = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
wire inst_ld_b      = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
wire inst_ld_h      = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
wire inst_ld_bu     = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
wire inst_ld_hu     = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

wire   inst_st_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_st_b    = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h    = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

assign inst_jirl    = op_31_26_d[6'h13];
assign inst_b       = op_31_26_d[6'h14];
assign inst_bl      = op_31_26_d[6'h15];
assign inst_beq     = op_31_26_d[6'h16];
assign inst_bne     = op_31_26_d[6'h17];
assign inst_blt     = op_31_26_d[6'h18];
assign inst_bge     = op_31_26_d[6'h19];
assign inst_bltu    = op_31_26_d[6'h1a];
assign inst_bgeu    = op_31_26_d[6'h1b];

wire   inst_csrrd   = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & (rj == 5'b00000);
wire   inst_csrwr   = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & (rj == 5'b00001);
assign inst_csrxchg = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & ~inst_csrrd & ~inst_csrwr;

assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01110) & (rj==5'b0) & (rd==5'b0);

assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];

wire inst_rdcntid_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk==5'h18) & (rd==5'h00);
wire inst_rdcntvl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk==5'h18) & (rj==5'h00) & (rd!=5'h00);
wire inst_rdcntvh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk==5'h19) & (rj==5'h00);

assign inst_tlbsrch    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'h0a) & (rj==5'h00) & (rd==5'h00);
assign inst_tlbrd      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'h0b) & (rj==5'h00) & (rd==5'h00);
assign inst_tlbfill    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'h0d) & (rj==5'h00) & (rd==5'h00);
assign inst_tlbwr      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'h0c) & (rj==5'h00) & (rd==5'h00);
assign inst_invtlb     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

assign inst_cacop      = op_31_26_d[6'h01] & op_25_22_d[4'h8];

assign inst_cpucfg     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk==5'h1b);

assign inst_idle       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h11];

assign inst_ll_w       = op_31_26_d[6'h08] & ~inst[25] & ~inst[24];
assign inst_sc_w       = op_31_26_d[6'h08] & ~inst[25] &  inst[24];

assign inst_dbar       = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h04];
assign inst_ibar       = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h05];

assign not_inst =
    ~(
       inst_add_w  | inst_sub_w  | inst_slt  | inst_sltu  | inst_nor  | inst_and  | inst_or  | inst_xor |
       inst_sll_w  | inst_srl_w  | inst_sra_w  | inst_mul_w | inst_mulh_w | inst_mulh_wu |
       inst_div_w  | inst_mod_w  | inst_div_wu | inst_mod_wu |
       inst_slli_w | inst_srli_w | inst_srai_w |
       inst_addi_w | inst_andi   | inst_ori   | inst_xori  | inst_slti  | inst_sltui |
       inst_lu12i_w| inst_pcaddu12i|
       inst_ld_w   | inst_ld_b   | inst_ld_h  | inst_ld_bu | inst_ld_hu |
       inst_st_w   | inst_st_b   | inst_st_h  |
       inst_jirl   | inst_b      | inst_bl    | inst_beq   | inst_bne   |
       inst_blt    | inst_bge    | inst_bltu  | inst_bgeu  |
       inst_csrxchg| inst_csrrd  | inst_csrwr |
       inst_ertn   | inst_syscall| inst_break |
       inst_rdcntid_w | inst_rdcntvl_w | inst_rdcntvh_w |
       inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb | inst_cacop | inst_cpucfg | inst_idle |
       inst_ll_w | inst_sc_w | inst_dbar | inst_ibar | inst_preld
    )
    | (inst_invtlb & ~(rd == 5'd0 || rd == 5'd1 || rd == 5'd2 || rd == 5'd3 || rd == 5'd4 || rd == 5'd5 || rd == 5'd6));

assign alu_op[0]  = (inst_add_w  | inst_addi_w | inst_ld_w  | inst_st_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu |
                     inst_st_b   | inst_st_h   | inst_cacop | inst_ll_w | inst_sc_w );
assign alu_op[1]  =  inst_sub_w;
assign alu_op[2]  = (inst_slt    | inst_slti);
assign alu_op[3]  = (inst_sltu   | inst_sltui);
assign alu_op[4]  = (inst_and    | inst_andi);
assign alu_op[5]  =  inst_nor;
assign alu_op[6]  = (inst_or     | inst_ori);
assign alu_op[7]  = (inst_xor    | inst_xori);
assign alu_op[8]  = (inst_slli_w | inst_sll_w);
assign alu_op[9]  = (inst_srli_w | inst_srl_w);
assign alu_op[10] = (inst_srai_w | inst_sra_w);
assign alu_op[11] =  inst_lu12i_w;
assign alu_op[12] =  inst_pcaddu12i;

assign need_addr_alu = (inst_ld_w  | inst_st_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu |
                        inst_st_b   | inst_st_h   | inst_cacop | inst_ll_w | inst_sc_w );

wire   inst_valid_cacop = inst_cacop && (rf_waddr[2:0]==3'b0||rf_waddr[2:0]==3'b1) &&
                         (rf_waddr[4:3]==2'd0||rf_waddr[4:3]==2'd1||rf_waddr[4:3]==2'd2);
 
wire   kernel_inst = inst_csrrd | inst_csrwr | inst_csrxchg | (inst_valid_cacop && |(rd[4:3] ^ 2'b10)) |
                     inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill |  inst_invtlb |
                     inst_ertn | inst_idle ;

assign ipe_ex = kernel_inst && (crmd_plv == 2'b11);

assign inst_branch = inst_b | inst_bl | inst_jirl | inst_beq | inst_bne | inst_blt | inst_bltu |
                     inst_bge | inst_bgeu ;

assign is_cntinst = (inst_rdcntid_w | inst_rdcntvl_w | inst_rdcntvh_w);

assign src1_is_pc = (inst_bl | inst_pcaddu12i);

assign src2_is_imm = (inst_lu12i_w | inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_pcaddu12i | inst_sltui |
                      inst_ld_w    | inst_st_w   | inst_andi   | inst_ori    | inst_xori   | inst_slti      | 
                      inst_ld_b    | inst_ld_bu  | inst_ld_h   | inst_ld_hu  | inst_st_b   | inst_st_h      | inst_cacop |
                      inst_ll_w    | inst_sc_w   );

// 这个信号应该只有一位，只表示写或不写，暂时懒得改了。片选信号在其它地方生成
assign data_sram_we = {4{inst_st_w | inst_st_h | inst_st_b | inst_sc_w}};

assign rf_we =  (~(inst_st_w | inst_b    | inst_beq  | inst_bne  | inst_blt | inst_dbar | inst_ibar | inst_preld
                 | inst_bltu | inst_bge  | inst_bgeu | inst_st_b | inst_st_h | inst_ertn | inst_syscall
                 | inst_break | inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb | inst_cacop | inst_idle));

assign rf_waddr = (inst_bl) ? 5'b00001 :
                  (inst_rdcntid_w)? rj :
                                    rd ;

assign src_reg_is_rd = (inst_beq  | inst_bne  | inst_st_w | inst_blt   | inst_bltu | inst_bge | inst_sc_w |
                        inst_bgeu | inst_st_b | inst_st_h | inst_csrwr | inst_csrxchg);

// default: 3'b000
assign rf_wdata_sel = ({3{inst_cpucfg                                                            }} & 3'b100 ) |
                      ({3{inst_sc_w                                                              }} & 3'b101 ) |
                      ({3{inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_ll_w}} & 3'b001 ) |
                      ({3{inst_bl | inst_jirl                                                    }} & 3'b010 ) |
                      ({3{is_csr_op                                                              }} & 3'b011 ) ;

// default: 2'b00
assign ex_result_sel = ({2{inst_mul_w | inst_mulh_w | inst_mulh_wu}} & 2'b01 ) |
                       ({2{inst_div_w | inst_div_wu               }} & 2'b10 ) |
                       ({2{inst_mod_w | inst_mod_wu               }} & 2'b11 ) ;

assign mmd_is_signed = (inst_mul_w | inst_mulh_w | inst_div_w | inst_mod_w);

assign mul_need_hi = (inst_mulh_w | inst_mulh_wu);

assign is_ld =  (inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_ll_w);
assign is_st =  (inst_st_b | inst_st_h | inst_st_w  | inst_sc_w );

assign ld_ext_is_signed = (inst_ld_b | inst_ld_h | inst_ll_w);

// default: 4'b0
assign ld_width = ({4{inst_ld_w | inst_ll_w  }} & 4'b1111 ) |
                  ({4{inst_ld_h | inst_ld_hu }} & 4'b0011 ) |
                  ({4{inst_ld_b | inst_ld_bu }} & 4'b0001 ) ;

assign csr_we = (inst_csrwr | inst_csrxchg);

assign is_csr_op = (inst_csrwr | inst_csrrd | inst_csrxchg | inst_rdcntid_w | inst_rdcntvl_w | inst_rdcntvh_w);

wire   is_tlb_op = (inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb);

// default: 14'b0
assign csr_num = ({14{inst_csrwr | inst_csrrd | inst_csrxchg}} & inst[23:10] ) |
                 ({14{inst_rdcntvl_w                        }} & 14'h45      ) |
                 ({14{inst_rdcntvh_w                        }} & 14'h46      ) |
                 ({14{inst_rdcntid_w                        }} & 14'h40      ) ;

assign cacop_code = rd;

assign dif_ld_info = {inst_ll_w, inst_ld_w, inst_ld_hu, inst_ld_h, inst_ld_bu, inst_ld_b};

// 如果需要 refetch ，就把之后的指令全部堵在ID级。
// 这样一来，就不会有任何不该有的写操作。
// 当 refetch_flag 为 1 且 EX、MEM、WB 阶段的 valid 都为 0 的时候，说明该进行 refetch 了，此时用 ID 阶段的 pc 去取指。
assign new_refetch_flag = is_tlb_op || inst_cacop || inst_idle || is_csr_op || inst_dbar || inst_ibar || inst_cpucfg;
                           
wire [15:0] a_i16 = {inst[23:10], 2'b0};

always @(*) begin
    if (inst_ll_w || inst_sc_w) begin
        imm = { {16{a_i16[15]}}, a_i16};
    end
    else if (inst_slli_w || inst_srli_w || inst_srai_w) begin
        imm = ui5;
    end
    else if (inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h | inst_cacop) begin
        imm = { {20{i12[11]}}, i12 };
    end
    else if (inst_lu12i_w || inst_pcaddu12i) begin
        imm = { i20, 12'b0 };
    end
    else if (inst_b || inst_bl) begin
        imm = { {4{i26[25]}}, i26, 2'b0 };
    end
    else if (inst_beq || inst_bne || inst_jirl || inst_blt || inst_bltu || inst_bge || inst_bgeu) begin
        imm = { {14{i16[15]}}, i16, 2'b0 };
    end
    else if (inst_andi || inst_ori || inst_xori) begin
        imm = {20'b0, i12};
    end
    else begin
        imm = 32'b0;
    end
end

endmodule
