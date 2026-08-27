//`define difftest
 `define perftest_or_linux
// `define gettrace

//`define DEBUG_ROB_VALUE

//alu_op
`define ALU_ADD 5'd0
`define ALU_SUB 5'd1
`define ALU_SLT 5'd2
`define ALU_SLTU 5'd3
`define ALU_SLL 5'd4
`define ALU_SRL 5'd5
`define ALU_SRA 5'd6
`define ALU_LU12I 5'd7
`define ALU_AND 5'd8
`define ALU_NOR 5'd9
`define ALU_OR 5'd10
`define ALU_XOR 5'd11
`define ALU_PCADDU12I 5'd12
`define ALU_CPUCFG 5'd13







//decoder
`define inst_31_26_000000 6'b000000
`define inst_31_26_000001 6'b000001
`define inst_31_26_000010 6'b000010
`define inst_31_26_000011 6'b000011
`define inst_31_26_000101 6'b000101
`define inst_31_26_000111 6'b000111
`define inst_31_26_001000 6'b001000
`define inst_31_26_001010 6'b001010
`define inst_31_26_001110 6'b001110
`define inst_31_26_010010 6'b010010
`define inst_31_26_010011 6'b010011
`define inst_31_26_010100 6'b010100
`define inst_31_26_010101 6'b010101
`define inst_31_26_010110 6'b010110
`define inst_31_26_010111 6'b010111
`define inst_31_26_011000 6'b011000
`define inst_31_26_011001 6'b011001
`define inst_31_26_011010 6'b011010
`define inst_31_26_011011 6'b011011

`define inst_25_22_0000 4'b0000
`define inst_25_22_0001 4'b0001
`define inst_25_22_0010 4'b0010
`define inst_25_22_0011 4'b0011
`define inst_25_22_0100 4'b0100
`define inst_25_22_0101 4'b0101
`define inst_25_22_0110 4'b0110
`define inst_25_22_0111 4'b0111
`define inst_25_22_1000 4'b1000
`define inst_25_22_1001 4'b1001
`define inst_25_22_1010 4'b1010
`define inst_25_22_1011 4'b1011
`define inst_25_22_1100 4'b1100
`define inst_25_22_1101 4'b1101
`define inst_25_22_1110 4'b1110
`define inst_25_22_1111 4'b1111

`define inst_21_20_00 2'b00
`define inst_21_20_01 2'b01
`define inst_21_20_10 2'b10
`define inst_21_20_11 2'b11

`define inst_19_15_00000 5'b00000
`define inst_19_15_00001 5'b00001
`define inst_19_15_00010 5'b00010
`define inst_19_15_00011 5'b00011
`define inst_19_15_00100 5'b00100
`define inst_19_15_00101 5'b00101
`define inst_19_15_00110 5'b00110
`define inst_19_15_00111 5'b00111
`define inst_19_15_01000 5'b01000
`define inst_19_15_01001 5'b01001
`define inst_19_15_01010 5'b01010
`define inst_19_15_01011 5'b01011
`define inst_19_15_01100 5'b01100
`define inst_19_15_01101 5'b01101
`define inst_19_15_01110 5'b01110
`define inst_19_15_01111 5'b01111
`define inst_19_15_10000 5'b10000
`define inst_19_15_10001 5'b10001
`define inst_19_15_10010 5'b10010
`define inst_19_15_10011 5'b10011
`define inst_19_15_10100 5'b10100
`define inst_19_15_10101 5'b10101
`define inst_19_15_10110 5'b10110
`define inst_19_15_10111 5'b10111
`define inst_19_15_11000 5'b11000
`define inst_19_15_11001 5'b11001
`define inst_19_15_11010 5'b11010
`define inst_19_15_11011 5'b11011
`define inst_19_15_11100 5'b11100
`define inst_19_15_11101 5'b11101
`define inst_19_15_11110 5'b11110
`define inst_19_15_11111 5'b11111

//comparator_op
`define COMPARATOR_EQ 3'd0
`define COMPARATOR_NE 3'd1
`define COMPARATOR_LT 3'd2
`define COMPARATOR_GE 3'd3
`define COMPARATOR_LTU 3'd4
`define COMPARATOR_GEU 3'd5


//ext_simm
`define EXT_SIMM_UI12 2'b00
`define EXT_SIMM_SI12 2'b01
`define EXT_SIMM_OFFS_15_0 2'b10
`define EXT_SIMM_OFFS_25_0 2'b11



//npc_selector_op
`define SEL_NPC_DEFAULT 2'b00
`define SEL_NPC_BRANCH 2'b01
`define SEL_NPC_B 2'b10
`define SEL_NPC_JIRL 2'b11

//sel_regfile_wdata
`define SEL_REGFILE_WDATA_ALU 2'b00
`define SEL_REGFILE_WDATA_MEM 2'b01
`define SEL_REGFILE_WDATA_PCADD4 2'b10

//stall_clear_detector_divider_state
`define DIVIDER_STATE_IDLE 1'b0
`define DIVIDER_STATE_BUZY 1'b1

//stall_clear_detector_multiplier_state
`define MULTIPLIER_STATE_IDLE 1'b0
`define MULTIPLIER_STATE_BUZY 1'b1

//stall_clear_detector_sel_load_store_len
`define SEL_LOAD_STORE_W 3'd0
`define SEL_LOAD_STORE_B 3'd1
`define SEL_LOAD_STORE_BU 3'd2
`define SEL_LOAD_STORE_H 3'd3
`define SEL_LOAD_STORE_HU 3'd4


//csr_regfile
`define CSR_ADDR_CRMD 14'h0
`define CSR_ADDR_PRMD 14'h1
`define CSR_ADDR_ECFG 14'h4
`define CSR_ADDR_ESTAT 14'h5
`define CSR_ADDR_ERA 14'h6
`define CSR_ADDR_BADV 14'h7
`define CSR_ADDR_EENTRY 14'hc
`define CSR_ADDR_SAVE0 14'h30
`define CSR_ADDR_SAVE1 14'h31
`define CSR_ADDR_SAVE2 14'h32
`define CSR_ADDR_SAVE3 14'h33
`define CSR_ADDR_TID 14'h40
`define CSR_ADDR_TCFG 14'h41
`define CSR_ADDR_TVAL 14'h42
`define CSR_ADDR_TICLR 14'h44

`define CSR_ADDR_TLBIDX 14'h10
`define CSR_ADDR_TLBEHI 14'h11
`define CSR_ADDR_TLBELO0 14'h12
`define CSR_ADDR_TLBELO1 14'h13
`define CSR_ADDR_ASID 14'h18
`define CSR_ADDR_PGDL 14'h19
`define CSR_ADDR_PGDH 14'h1a
`define CSR_ADDR_PGD 14'h1b
`define CSR_ADDR_CPUID 14'h20 //
`define CSR_ADDR_TLBRENTRY 14'h88
`define CSR_ADDR_DMW0 14'h180
`define CSR_ADDR_DMW1 14'h181

`define CSR_ADDR_LLBCTL 14'h60


`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2
`define CSR_CRMD_DA 3
`define CSR_CRMD_PG 4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2

`define CSR_ECFG_LIE_9_0 9:0
`define CSR_ECFG_LIE_12_11 12:11

`define CSR_ESTAT_IS_1_0 1:0
`define CSR_ESTAT_IS_9_2 9:2
`define CSR_ESTAT_IS_11 11
`define CSR_ESTAT_IS_12 12
`define CSR_ESTAT_ECODE 21:16
`define CSR_ESTAT_ESUBCODE 30:22

`define CSR_ERA_PC 31:0

`define CSR_BADV_VADDR 31:0

`define CSR_EENTRY_VA 31:6

`define CSR_SAVE0_DATA 31:0

`define CSR_SAVE1_DATA 31:0

`define CSR_SAVE2_DATA 31:0

`define CSR_SAVE3_DATA 31:0

`define CSR_TID_TID 31:0

`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIODIC 1
`define CSR_TCFG_INITVAL 31:2

`define CSR_TVAL_TIMEVAL 31:0

`define CSR_TICLR_CLR 0

`define CSR_TLBIDX_INDEX 3:0
`define CSR_TLBIDX_PS 29:24
`define CSR_TLBIDX_NE 31

`define CSR_TLBEHI_VPPN 31:13

`define CSR_TLBELO0_V 0
`define CSR_TLBELO0_D 1
`define CSR_TLBELO0_PLV 3:2
`define CSR_TLBELO0_MAT 5:4
`define CSR_TLBELO0_G 6
`define CSR_TLBELO0_PPN 31:8

`define CSR_TLBELO1_V 0
`define CSR_TLBELO1_D 1
`define CSR_TLBELO1_PLV 3:2
`define CSR_TLBELO1_MAT 5:4
`define CSR_TLBELO1_G 6
`define CSR_TLBELO1_PPN 31:8

`define CSR_ASID_ASID 9:0
`define CSR_ASID_ASIDBITS 23:16

`define CSR_PGDL_BASE 31:12

`define CSR_PGDH_BASE 31:12

`define CSR_PGD_BASE 31:12

`define CSR_TLBRENTRY_PA 31:6

`define CSR_DMW0_PLV0 0
`define CSR_DMW0_PLV3 3
`define CSR_DMW0_MAT 5:4
`define CSR_DMW0_PSEG 27:25
`define CSR_DMW0_VSEG 31:29

`define CSR_DMW1_PLV0 0
`define CSR_DMW1_PLV3 3
`define CSR_DMW1_MAT 5:4
`define CSR_DMW1_PSEG 27:25
`define CSR_DMW1_VSEG 31:29

`define CSR_LLBCTL_ROLLB 0
`define CSR_LLBCTL_WCLLB 1
`define CSR_LLBCTL_KLO 2


`define EXCEPTION_ECODE_INT 6'h0
`define EXCEPTION_ECODE_PIL 6'h1
`define EXCEPTION_ECODE_PIS 6'h2
`define EXCEPTION_ECODE_PIF 6'h3
`define EXCEPTION_ECODE_PME 6'h4
`define EXCEPTION_ECODE_PPI 6'h7
`define EXCEPTION_ECODE_ADE 6'h8
`define EXCEPTION_ECODE_ALE 6'h9
`define EXCEPTION_ECODE_SYS 6'hb
`define EXCEPTION_ECODE_BRK 6'hc
`define EXCEPTION_ECODE_INE 6'hd
`define EXCEPTION_ECODE_IPE 6'he
`define EXCEPTION_ECODE_FPD 6'hf
`define EXCEPTION_ECODE_FPE 6'h12
`define EXCEPTION_ECODE_TLBR 6'h3F




`define SRAM_IDLE 2'b00
`define SRAM_BUZY 2'b01
`define SRAM_FINISH 2'b10
`define SRAM_REQ 2'b11


`define SEL_REGFILE_RDATA_R0 2'b00
`define SEL_REGFILE_RDATA_RJ 2'b01
`define SEL_REGFILE_RDATA_RK 2'b10
`define SEL_REGFILE_RDATA_RD 2'b11


//issue_queue type
`define SEL_ISSUE_QUEUE_INTEGER 3'b000
`define SEL_ISSUE_QUEUE_LOAD 3'b001
`define SEL_ISSUE_QUEUE_STORE 3'b010
`define SEL_ISSUE_QUEUE_BRQ 3'b011
`define SEL_ISSUE_QUEUE_MD 3'b100
`define SEL_ISSUE_QUEUE_FAST 3'b101
`define SEL_ISSUE_QUEUE_NO 3'b110
`define SEL_ISSUE_QUEUE_PRIVILIEGE 3'b111

//rename_state
`define RMT_STATE_EMPTY 2'b00
`define RMT_STATE_MAPPED 2'b01
`define RMT_STATE_WRITEBACK 2'b10
`define RMT_STATE_COMMIT 2'b11

//issue_queue
`define ISSUE_QUEUE_DEPTH 32
`define ISSUE_QUEUE_TAG_WIDTH 7
`define ISSUE_QUEUE_OP_WIDTH 7
`define ISSUE_QUEUE_IMM_WIDTH 32
`define ISSUE_QUEUE_COUNT_WIDTH 6


`define LSU_ISSUE_QUEUE_DEPTH 32
`define LSU_ISSUE_QUEUE_TAG_WIDTH 7
`define LSU_ISSUE_QUEUE_OP_WIDTH 8
`define LSU_ISSUE_QUEUE_IMM_WIDTH 32
`define LSU_ISSUE_QUEUE_COUNT_WIDTH 6

`define ROB_DEPTH 64
`define ROB_ID_WIDTH 6
`define ROB_COUNT_WIDTH 7
`define ROB_ARCH_WIDTH 5
`define ROB_PHY_WIDTH 7
`define ROB_PC_WIDTH 32
`define ROB_ISSUE_OP_WIDTH 12
`define ROB_WRITEBACK_OP_WIDTH 39


//md_issue_queue
`define MD_ISSUE_QUEUE_DEPTH 32
`define MD_ISSUE_QUEUE_TAG_WIDTH 7
`define MD_ISSUE_QUEUE_OP_WIDTH 12
`define MD_ISSUE_QUEUE_IMM_WIDTH 32
`define MD_ISSUE_QUEUE_COUNT_WIDTH 6

`define MD_MUL_W 7'b0000001
`define MD_MULH_W 7'b0000010
`define MD_MULH_WU 7'b0000100
`define MD_DIV_W 7'b0001000
`define MD_MOD_W 7'b0010000
`define MD_DIV_WU 7'b0100000
`define MD_MOD_WU 7'b1000000

`define MUL_DELAY 3
`define DIV_DELAY 32


`define SEL_PRE_RESULT_IMM 3'b000
`define SEL_PRE_RESULT_PCADD4 3'b001
`define SEL_PRE_RESULT_LU12I 3'b010
`define SEL_PRE_RESULT_PCADDU12I 3'b011
`define SEL_PRE_RESULT_RDCNTVH 3'b100
`define SEL_PRE_RESULT_RDCNTVL 3'b101
`define SEL_PRE_RESULT_SI14 3'b110



`define FAST_ISSUE_QUEUE_DEPTH 32
`define FAST_ISSUE_QUEUE_TAG_WIDTH 7
`define FAST_ISSUE_QUEUE_OP_WIDTH 1
`define FAST_ISSUE_QUEUE_IMM_WIDTH 32
`define FAST_ISSUE_QUEUE_COUNT_WIDTH 6





`define PRIVILEGE_ISSUE_QUEUE_DEPTH 16
`define PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH 7
`define PRIVILEGE_ISSUE_QUEUE_OP_WIDTH 28
`define PRIVILEGE_ISSUE_QUEUE_IMM_WIDTH 32
`define PRIVILEGE_ISSUE_QUEUE_COUNT_WIDTH 5




`define INST_SRAM_FSM_IDLE 3'b000
`define INST_SRAM_FSM_MISS 3'b001
`define INST_SRAM_FSM_WAIT 3'b010
`define INST_SRAM_FSM_FINISH 3'b011
`define INST_SRAM_FSM_HIT 3'b100

`define DATA_SRAM_FSM_IDLE 3'b000
`define DATA_SRAM_FSM_MISS 3'b001
`define DATA_SRAM_FSM_SHAKE 3'b010
`define DATA_SRAM_FSM_WAIT 3'b011
`define DATA_SRAM_FSM_FINISH 3'b100
`define DATA_SRAM_FSM_HIT 3'b101


`define CPUCFG_0x1_1_0 2'b00
`define CPUCFG_0x1_2 1'b1
`define CPUCFG_0x1_11_4 8'd31
`define CPUCFG_0x1_19_12 8'd31

`define CPUCFG_0x2 32'd0

`define CPUCFG_0x10_0 1'b1
`define CPUCFG_0x10_1 1'b0
`define CPUCFG_0x10_2 1'b1
`define CPUCFG_0x10_3 1'b1
`define CPUCFG_0x10_4 1'b1
`define CPUCFG_0x10_5 1'b0
`define CPUCFG_0x10_6 1'b0
`define CPUCFG_0x10_31_7 25'b0

`define CPUCFG_0x11_15_0 16'b0000_0000_0000_0001
`define CPUCFG_0x11_23_16 8'b0000_0111
`define CPUCFG_0x11_30_24 7'b000_0101
`define CPUCFG_0x11_31 1'b0

`define CPUCFG_0x12_15_0 16'b0000_0000_0000_0001
`define CPUCFG_0x12_23_16 8'b0000_0111
`define CPUCFG_0x12_30_24 7'b000_0101
`define CPUCFG_0x12_31 1'b0

`define CPUCFG_0x13_15_0 16'b0000_0000_0000_0011
`define CPUCFG_0x13_23_16 8'b0000_1001
`define CPUCFG_0x13_30_24 7'b000_0101
`define CPUCFG_0x13_31 1'b0
