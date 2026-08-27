`include "header.v"


module compress_decode(
        input wire  [101:0] ins_fifo_data,

        input wire is_int,
        input wire [63:0] rdcnt,



        output wire csr_3w,
        output wire is_CNTinst,
        output wire [7:0] load_valid,
        output wire [7:0] store_valid,

        output wire is_b_jump,
        output wire [31:0] target_b,
        output wire is_idle,
        output wire label,
        output wire [`ID_OPCODE_LEN - 1 :0] id_opcode
    );




    wire                                          insfifo_is_exception;
    wire                                          insfifo_is_adef;
    wire                                          insfifo_is_tlbr;
    wire                                          insfifo_is_inst_tlbr;
    wire                                          insfifo_is_inst_pif;
    wire                                          insfifo_is_inst_ppi;



    wire [                                  31:0] inst_fifo_instruction;
    wire [                                  31:0] inst_fifo_pc;
    wire                                          inst_fifo_valid;

    wire [                                  31:0] decode_instruction;
    wire [                                   4:0] decode_regfile_raddr1;
    wire [                                   4:0] decode_regfile_raddr2;
    wire                                          decode_regfile_we;
    wire [                                   4:0] decode_regfile_waddr;
    wire [                                   1:0] decode_sel_npc;
    wire [                                   4:0] decode_alu_op;
    wire [                                   2:0] decode_comparator_op;
    wire [                                   2:0] decode_sel_issue_queue;
    wire                                          decode_sel_imm;
    wire [                                   1:0] decode_ext_simm;
    wire                                          decode_sel_lui12;
    wire [                                   6:0] decode_md_op;
    wire [                                   2:0] decode_sel_load_store_len;
    wire [                                   2:0] decode_sel_pre_result;


    wire [                                  13:0] decode_csr_addr;
    wire                                          decode_csr_we;
    wire                                          decode_csr_re;
    wire                                          decode_sel_csr_wmask;
    wire                                          decode_csr_ertn_flush;

    wire                                          decode_is_sys;
    wire                                          decode_is_brk;
    wire                                          decode_is_ine;



    wire [                                  31:0] id_pre_result                                            [6:0];

    wire [                                  31:0] ext_instruction;
    wire [                                   1:0] ext_simm;
    wire [                                  31:0] ext_extended_imm;
    wire [                                  31:0] ext_offset16;
    wire [                                  31:0] ext_offset26;

    wire                                          id_rename_state_in_is_exception;
    wire                                          id_rename_state_in_is_sys;
    wire                                          id_rename_state_in_is_int;
    wire                                          id_rename_state_in_ertn_flush;
    wire [                                  13:0] id_rename_state_in_csr_addr;
    wire                                          id_rename_state_in_csr_we;
    wire                                          id_rename_state_in_sel_csr_wmask;
    wire                                          id_rename_state_in_csr_re;

    wire                                          id_rename_state_in_is_adef;
    wire                                          id_rename_state_in_is_ine;
    wire                                          id_rename_state_in_is_brk;

    // wire        id_rename_state_in_tlb_we;
    wire [                                   4:0] id_rename_state_in_invtlb_op;
    wire                                          id_rename_state_in_is_inst_tlbsrch;
    wire                                          id_rename_state_in_is_inst_tlbrd;
    wire                                          id_rename_state_in_is_inst_tlbwr;
    wire                                          id_rename_state_in_is_inst_tlbfill;
    wire                                          id_rename_state_in_is_inst_invtlb;

    wire                                          id_rename_state_in_is_tlbr;
    wire                                          id_rename_state_in_is_inst_tlbr;
    wire                                          id_rename_state_in_is_inst_pif;
    wire                                          id_rename_state_in_is_inst_ppi;
    wire id_rename_state_in_wb_refetch;
    wire id_rename_state_in_is_cacop;


    wire [                                  31:0] id_rename_reg_in_pc;
    wire [                                  31:0] id_rename_reg_in_instruction;
    wire [                                   4:0] id_rename_reg_in_regfile_raddr1;
    wire [                                   4:0] id_rename_reg_in_regfile_raddr2;
    wire                                          id_rename_reg_in_regfile_we;
    wire [                                   4:0] id_rename_reg_in_regfile_waddr;
    wire [                                   1:0] id_rename_reg_in_sel_npc;
    wire [                                   4:0] id_rename_reg_in_alu_op;
    wire [                                   2:0] id_rename_reg_in_comparator_op;
    wire [                                   2:0] id_rename_reg_in_sel_issue_queue;
    wire                                          id_rename_reg_in_sel_imm;
    wire [                                  31:0] id_rename_reg_in_extended_imm;
    wire [                                   6:0] id_rename_reg_in_md_op;
    wire [                                   2:0] id_rename_reg_in_sel_load_store_len;
    wire [31:0] id_rename_reg_in_predict_target_address;

    wire id_rename_reg_in_is_b_jump;
    wire [                                  31:0] id_rename_reg_in_target_b;

    wire id_rename_state_in_is_ll_w;
    wire id_rename_state_in_is_sc_w;
    wire id_rename_state_in_is_dbar;
    wire is_sys,is_brk,is_ine;







    wire [31:0] inst_fifo_predict_target_address;

    wire [4:0] decode_invtlb_op;


    wire       decode_is_inst_tlbsrch;
    wire       decode_is_inst_tlbrd;
    wire       decode_is_inst_tlbwr;
    wire       decode_is_inst_tlbfill;
    wire       decode_is_inst_invtlb;

    wire       decode_wb_refetch;

    wire       decode_is_cacop;

    wire decode_csr_3w;
    wire decode_is_CNTinst;
    wire [7:0] decode_load_valid;
    wire [7:0] decode_store_valid;

    wire decode_is_idle;
    wire decode_is_ll_w;
    wire decode_is_sc_w;
    wire decode_is_dbar;
    assign is_idle = decode_is_idle;

    assign {
            inst_fifo_pc,
            inst_fifo_instruction,
            insfifo_is_exception,
            insfifo_is_adef,
            insfifo_is_tlbr,
            insfifo_is_inst_tlbr,
            insfifo_is_inst_pif,
            insfifo_is_inst_ppi,
            inst_fifo_predict_target_address
        } = ins_fifo_data;


    assign decode_instruction = inst_fifo_instruction;


    assign csr_3w = decode_csr_3w;
    assign is_CNTinst = decode_is_CNTinst;
    assign load_valid = decode_load_valid;
    assign store_valid = decode_store_valid;


    decode u_decode (
               .instruction   (decode_instruction),
               .regfile_raddr1(decode_regfile_raddr1),
               .regfile_raddr2(decode_regfile_raddr2),
               .regfile_we    (decode_regfile_we),
               .regfile_waddr (decode_regfile_waddr),

               .sel_npc           (decode_sel_npc),
               .alu_op            (decode_alu_op),
               .comparator_op     (decode_comparator_op),
               .sel_issue_queue   (decode_sel_issue_queue),
               .sel_imm           (decode_sel_imm),
               .ext_simm          (decode_ext_simm),
               .sel_lui12         (decode_sel_lui12),
               .md_op             (decode_md_op),
               .sel_load_store_len(decode_sel_load_store_len),
               .sel_pre_result    (decode_sel_pre_result),

               .csr_addr      (decode_csr_addr),
               .csr_we        (decode_csr_we),
               .csr_re        (decode_csr_re),
               .sel_csr_wmask (decode_sel_csr_wmask),
               .csr_ertn_flush(decode_csr_ertn_flush),
               .is_sys        (decode_is_sys),
               .is_brk        (decode_is_brk),
               .is_ine        (decode_is_ine),

               .invtlb_op      (decode_invtlb_op),
               .is_inst_tlbsrch(decode_is_inst_tlbsrch),
               .is_inst_tlbrd  (decode_is_inst_tlbrd),
               .is_inst_tlbwr  (decode_is_inst_tlbwr),
               .is_inst_tlbfill(decode_is_inst_tlbfill),
               .is_inst_invtlb (decode_is_inst_invtlb),

               .wb_refetch(decode_wb_refetch),

               .is_cacop(decode_is_cacop),

               .csr_3w(decode_csr_3w),
               .is_CNTinst(decode_is_CNTinst),
               .load_valid(decode_load_valid),
               .store_valid(decode_store_valid),

               .is_idle(decode_is_idle),
               .is_ll_w(decode_is_ll_w),
               .is_sc_w(decode_is_sc_w),
               .is_dbar(decode_is_dbar)
           );

    assign is_sys           = decode_is_sys;
    assign is_brk           = decode_is_brk;
    assign is_ine           = decode_is_ine;
    // assign is_int           = csr_regfile_has_int;




    assign id_pre_result[0] = ext_extended_imm;
    assign id_pre_result[1] = inst_fifo_pc + 32'd4;
    assign id_pre_result[2] = {inst_fifo_instruction[24:5], 12'b0};
    assign id_pre_result[3] = inst_fifo_pc + {inst_fifo_instruction[24:5], 12'b0};
    assign id_pre_result[4] = rdcnt[63:32];
    assign id_pre_result[5] = rdcnt[31:0];
    assign id_pre_result[6] = {{16{inst_fifo_instruction[23]}},inst_fifo_instruction[23:10], 2'b00};



    assign ext_instruction  = inst_fifo_instruction;
    assign ext_simm         = decode_ext_simm;

    ext u_ext (
            .instruction (ext_instruction),
            .simm        (ext_simm),
            .extended_imm(ext_extended_imm),
            .offset16    (ext_offset16),
            .offset26    (ext_offset26)
        );



    assign id_rename_state_in_is_exception    = insfifo_is_exception || is_sys || is_int || is_ine || is_brk;
    assign id_rename_state_in_is_sys          = is_sys;
    assign id_rename_state_in_is_int          = is_int;
    assign id_rename_state_in_ertn_flush      = decode_csr_ertn_flush;
    assign id_rename_state_in_csr_addr        = decode_csr_addr;
    assign id_rename_state_in_csr_we          = decode_csr_we;
    assign id_rename_state_in_sel_csr_wmask   = decode_sel_csr_wmask;
    assign id_rename_state_in_csr_re          = decode_csr_re;

    assign id_rename_state_in_is_adef         = insfifo_is_adef;
    assign id_rename_state_in_is_ine          = is_ine;
    assign id_rename_state_in_is_brk          = is_brk;

    assign id_rename_state_in_invtlb_op       = decode_invtlb_op;
    assign id_rename_state_in_is_inst_tlbsrch = decode_is_inst_tlbsrch;
    assign id_rename_state_in_is_inst_tlbrd   = decode_is_inst_tlbrd;
    assign id_rename_state_in_is_inst_tlbwr   = decode_is_inst_tlbwr;
    assign id_rename_state_in_is_inst_tlbfill = decode_is_inst_tlbfill;
    assign id_rename_state_in_is_inst_invtlb  = decode_is_inst_invtlb;

    assign id_rename_state_in_is_tlbr         = insfifo_is_tlbr;
    assign id_rename_state_in_is_inst_tlbr    = insfifo_is_inst_tlbr;
    assign id_rename_state_in_is_inst_pif     = insfifo_is_inst_pif;
    assign id_rename_state_in_is_inst_ppi     = insfifo_is_inst_ppi;



    assign id_rename_state_in_wb_refetch = decode_wb_refetch;



    assign id_rename_state_in_is_cacop = decode_is_cacop;



    assign id_rename_state_in_is_ll_w = decode_is_ll_w;
    assign id_rename_state_in_is_sc_w = decode_is_sc_w;
    assign id_rename_state_in_is_dbar = decode_is_dbar;



    // assign id_rename_reg_pre_stall             = inst_fifo_stall;

    assign id_rename_reg_in_pc                 = inst_fifo_pc;
    assign id_rename_reg_in_instruction        = inst_fifo_instruction;
    assign id_rename_reg_in_regfile_raddr1     = decode_regfile_raddr1;
    assign id_rename_reg_in_regfile_raddr2     = decode_regfile_raddr2;
    assign id_rename_reg_in_regfile_we         = decode_regfile_we;
    assign id_rename_reg_in_regfile_waddr      = decode_regfile_waddr;
    assign id_rename_reg_in_sel_npc            = decode_sel_npc;
    assign id_rename_reg_in_alu_op             = decode_alu_op;
    assign id_rename_reg_in_comparator_op      = decode_comparator_op;
    assign id_rename_reg_in_sel_issue_queue    = decode_sel_issue_queue;
    assign id_rename_reg_in_sel_imm            = decode_sel_imm;
    assign id_rename_reg_in_extended_imm       = id_pre_result[decode_sel_pre_result];


    assign id_rename_reg_in_target_b           = decode_sel_npc == `SEL_NPC_B ? inst_fifo_pc + ext_offset26 : inst_fifo_pc + 32'd4;


    assign id_rename_reg_in_md_op              = decode_md_op;

    assign id_rename_reg_in_sel_load_store_len = decode_sel_load_store_len;

    assign id_rename_reg_in_predict_target_address = inst_fifo_predict_target_address;

    assign id_rename_reg_in_is_b_jump = (decode_sel_npc == `SEL_NPC_B || decode_sel_npc == `SEL_NPC_DEFAULT) && (id_rename_reg_in_target_b!=inst_fifo_predict_target_address);




    assign is_b_jump = id_rename_reg_in_is_b_jump;
    assign target_b = id_rename_reg_in_target_b;

    assign label = decode_sel_npc == `SEL_NPC_BRANCH || decode_sel_npc == `SEL_NPC_JIRL;

    assign id_opcode =
           {
               id_rename_state_in_is_exception,           // [210]
               id_rename_state_in_is_sys,                 // [209]
               id_rename_state_in_is_int,                 // [208]
               id_rename_state_in_ertn_flush,             // [207]
               id_rename_state_in_csr_addr,               // [206:193]
               id_rename_state_in_csr_we,                 // [192]
               id_rename_state_in_csr_re,                 // [191]
               id_rename_state_in_sel_csr_wmask,          // [190]
               id_rename_state_in_is_adef,                // [189]
               id_rename_state_in_is_ine,                 // [188]
               id_rename_state_in_is_brk,                 // [187]
               id_rename_state_in_invtlb_op,              // [186:182]
               id_rename_state_in_is_inst_tlbsrch,        // [181]
               id_rename_state_in_is_inst_tlbrd,          // [180]
               id_rename_state_in_is_inst_tlbwr,          // [179]
               id_rename_state_in_is_inst_tlbfill,        // [178]
               id_rename_state_in_is_inst_invtlb,         // [177]
               id_rename_state_in_is_tlbr,                // [176]
               id_rename_state_in_is_inst_tlbr,           // [175]
               id_rename_state_in_is_inst_pif,            // [174]
               id_rename_state_in_is_inst_ppi,            // [173]
               id_rename_state_in_wb_refetch,             // [172]
               id_rename_state_in_is_cacop,               // [171]
               id_rename_reg_in_pc,                       // [170:139]
               id_rename_reg_in_instruction,              // [138:107]
               id_rename_reg_in_regfile_raddr1,           // [106:102]
               id_rename_reg_in_regfile_raddr2,           // [101:97]
               id_rename_reg_in_regfile_we,               // [96]
               id_rename_reg_in_regfile_waddr,            // [95:91]
               id_rename_reg_in_sel_npc,                  // [90:89]
               id_rename_reg_in_alu_op,                   // [88:84]
               id_rename_reg_in_comparator_op,            // [83:81]
               id_rename_reg_in_sel_issue_queue,          // [80:78]
               id_rename_reg_in_sel_imm,                  // [77]
               id_rename_reg_in_extended_imm,             // [76:45]
               id_rename_reg_in_md_op,                    // [44:38]
               id_rename_reg_in_sel_load_store_len,       // [37:35]
               id_rename_reg_in_predict_target_address,   // [34:3]
               id_rename_state_in_is_ll_w,                // [2]
               id_rename_state_in_is_sc_w,                // [1]
               id_rename_state_in_is_dbar                 // [0]
           };






endmodule
