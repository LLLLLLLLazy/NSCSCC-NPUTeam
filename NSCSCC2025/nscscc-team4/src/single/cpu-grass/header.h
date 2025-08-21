//总线
`define WIDTH_PIF_IF_BUS        102
`define WIDTH_IF_ID_BUS         113
`define WIDTH_ID_EX1_BUS        404
`define WIDTH_EX1_EX2_BUS       451
`define WIDTH_EX2_MEM_BUS       377
`define WIDTH_BR_BUS            33

//difftest线
`define DIFF_WIDTH_ID_EX1_BUS    50
`define DIFF_WIDTH_EX1_EX2_BUS   50
`define DIFF_WIDTH_EX2_MEM_BUS   146

//ID 目前没有做前递，所以只有5位，即只前递寄存器号来判断是否要在阻塞
`define WIDTH_EX1_FORWARD_BUS   38
`define WIDTH_EX2_FORWARD_BUS   5
`define WIDTH_MEM_FORWARD_BUS   38

//MEM
`define WIDTH_MEM_RF_BUS        38