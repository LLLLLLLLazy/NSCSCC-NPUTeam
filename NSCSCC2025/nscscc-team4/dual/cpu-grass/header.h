// `include "../../chip/soc_demo/nscscc-team/soc_config.vh"

// (chiplab)
// `ifdef RUN_FUNC_TEST
//     `define DEBUG
// `endif

// (DIFFTEST)
//`define DEBUG
// `undef DIFFTEST_EN

`ifdef DIFFTEST_EN
    `ifdef DEBUG
        `define DIFFTEST_DEBUG
    `endif
`endif

//??
`define WIDTH_PIF_IF_BUS        179
`define WIDTH_IF_ID_BUS         120
`define WIDTH_ID_FIFO_BUS       64
`define WIDTH_ID_DECODE_BUS     193
`define WIDTH_FIFO_IS_BUS       264
`define WIDTH_IS_EX1_BUS        423


`define WIDTH_EX1_EX2_BUS       382-5+`WIDTH_TLB_INDEX + 3
`define WIDTH_EX2_MEM_BUS       379+32+97-5+`WIDTH_TLB_INDEX + 4
`define WIDTH_MEM_CM_BUS        71
`define WIDTH_BR_BUS            33


//difftest?
`define DIFF_WIDTH_ID_FIFO_BUS   50
`define DIFF_WIDTH_FIFO_IS_BUS   50
`define DIFF_WIDTH_IS_EX1_BUS    50
`define DIFF_WIDTH_EX1_EX2_BUS   210
`define DIFF_WIDTH_EX2_MEM_BUS   210
`define DIFF_WIDTH_MEM_CM_BUS    354
`define DIFF_WIDTH_MEM_CM_CTRL_BUS 294-5+`WIDTH_TLB_INDEX

//ID 
`define WIDTH_EX1_FORWARD_BUS      38
`define WIDTH_EX2_FORWARD_BUS      38
`define WIDTH_MEM_FORWARD_BUS      38
`define WIDTH_IS_EX1_FORWARD_BUS   76
`define WIDTH_IS_EX2_FORWARD_BUS   76
`define WIDTH_IS_MEM_FORWARD_BUS   76

//FIFO
`define FIFO_DEPTH              8

//IS
`define WIDTH_BR_BUS            33

//MEM
`define WIDTH_MEM_RF_BUS        38

//TLB
`define TLB_NUM 16
`define WIDTH_TLB_INDEX 4