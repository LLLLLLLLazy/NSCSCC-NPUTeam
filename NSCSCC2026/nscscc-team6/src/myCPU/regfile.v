`include "mycpu.h"

// 64项、32位宽、6读3写 物理寄存器堆 (Physical Register File)
module regfile (
    input  wire        clk,
    input  wire        reset,


    // 1. 读端口 (6 个异步读，供 3 个发射队列出队提取数据)

    // 供 ALU_0 提取
    input  wire [ 5:0] raddr1_0,
    input  wire [ 5:0] raddr2_0,
    output wire [31:0] rdata1_0,
    output wire [31:0] rdata2_0,

    // 供 ALU_1 提取
    input  wire [ 5:0] raddr1_1,
    input  wire [ 5:0] raddr2_1,
    output wire [31:0] rdata1_1,
    output wire [31:0] rdata2_1,

    // 供 MEM/PRIV 提取
    input  wire [ 5:0] raddr1_2,
    input  wire [ 5:0] raddr2_2,
    output wire [31:0] rdata1_2,
    output wire [31:0] rdata2_2,
    

    // 2. 写端口 (3 个同步写，监听全场 3 条 CDB 广播)

    input  wire        we_0,       // 连 cdb_we_0
    input  wire [ 5:0] waddr_0,    // 连 cdb_preg_0
    input  wire [31:0] wdata_0,    // 连 cdb_wdata_0

    input  wire        we_1,       // 连 cdb_we_1
    input  wire [ 5:0] waddr_1,    // 连 cdb_preg_1
    input  wire [31:0] wdata_1,    // 连 cdb_wdata_1

    input  wire        we_2,       // 连 cdb_we_2 (新增)
    input  wire [ 5:0] waddr_2,    // 连 cdb_preg_2
    input  wire [31:0] wdata_2    , // 连 cdb_wdata_2,
    input  wire [ 5:0] debug_raddr_0,
    input  wire [ 5:0] debug_raddr_1,
    output wire [31:0] debug_rdata_0,
    output wire [31:0] debug_rdata_1
`ifdef DIFFTEST_EN
    ,
    input  wire [ 5:0] diff_raddr [31:0],
    output wire [31:0] diff_rdata [31:0]
`endif
);

    // 真正的存储阵列：64 个 32-bit 寄存器
    reg [31:0] prf_mem [63:0];
assign debug_rdata_0 = (debug_raddr_0 == 6'd0) ? 32'd0 :prf_mem[debug_raddr_0]; // rf 是你内部的寄存器数组名，请核对
assign debug_rdata_1 = (debug_raddr_1 == 6'd0) ? 32'd0 :prf_mem[debug_raddr_1];    
`ifdef DIFFTEST_EN
genvar diff_i;
generate
    for (diff_i = 0; diff_i < 32; diff_i = diff_i + 1) begin : gen_diff_read
        assign diff_rdata[diff_i] = (diff_raddr[diff_i] == 6'd0) ? 32'd0 : prf_mem[diff_raddr[diff_i]];
    end
endgenerate
`endif

    // A. 读逻辑 (包含 p0 恒为 0，以及 3 路同周期写穿透旁路)
    
    // 读端口 1_0
    assign rdata1_0 = (raddr1_0 == 6'd0) ? 32'd0 :
                      (we_0 && waddr_0 == raddr1_0) ? wdata_0 :
                      (we_1 && waddr_1 == raddr1_0) ? wdata_1 :
                      (we_2 && waddr_2 == raddr1_0) ? wdata_2 :
                      prf_mem[raddr1_0];

    // 读端口 2_0
    assign rdata2_0 = (raddr2_0 == 6'd0) ? 32'd0 :
                      (we_0 && waddr_0 == raddr2_0) ? wdata_0 :
                      (we_1 && waddr_1 == raddr2_0) ? wdata_1 :
                      (we_2 && waddr_2 == raddr2_0) ? wdata_2 :
                      prf_mem[raddr2_0];

    // 读端口 1_1
    assign rdata1_1 = (raddr1_1 == 6'd0) ? 32'd0 :
                      (we_0 && waddr_0 == raddr1_1) ? wdata_0 :
                      (we_1 && waddr_1 == raddr1_1) ? wdata_1 :
                      (we_2 && waddr_2 == raddr1_1) ? wdata_2 :
                      prf_mem[raddr1_1];

    // 读端口 2_1
    assign rdata2_1 = (raddr2_1 == 6'd0) ? 32'd0 :
                      (we_0 && waddr_0 == raddr2_1) ? wdata_0 :
                      (we_1 && waddr_1 == raddr2_1) ? wdata_1 :
                      (we_2 && waddr_2 == raddr2_1) ? wdata_2 :
                      prf_mem[raddr2_1];

    // 读端口 1_2 (MEM)
    assign rdata1_2 = (raddr1_2 == 6'd0) ? 32'd0 :
                      (we_0 && waddr_0 == raddr1_2) ? wdata_0 :
                      (we_1 && waddr_1 == raddr1_2) ? wdata_1 :
                      (we_2 && waddr_2 == raddr1_2) ? wdata_2 :
                      prf_mem[raddr1_2];

    // 读端口 2_2 (MEM)
    assign rdata2_2 = (raddr2_2 == 6'd0) ? 32'd0 :
                      (we_0 && waddr_0 == raddr2_2) ? wdata_0 :
                      (we_1 && waddr_1 == raddr2_2) ? wdata_1 :
                      (we_2 && waddr_2 == raddr2_2) ? wdata_2 :
                      prf_mem[raddr2_2];


    // B. 写逻辑
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // 初始清空防止 X 态
            for (i = 0; i < 64; i = i + 1) begin
                prf_mem[i] <= 32'd0;
            end
        end
        else begin
            // 乱序架构的美妙保证：
            // 因为 Rename 阶段的 Freelist 绝对不可能在同一周期把同一个物理寄存器分配给多条指令，
            // 所以 waddr_0, waddr_1, waddr_2 绝对不可能互相等于！(除非它们都是 0)
            // 毫无冲突之忧，直接并行写入即可。
            if (we_0 && waddr_0 != 6'd0) prf_mem[waddr_0] <= wdata_0;
            if (we_1 && waddr_1 != 6'd0) prf_mem[waddr_1] <= wdata_1;
            if (we_2 && waddr_2 != 6'd0) prf_mem[waddr_2] <= wdata_2;
        end
    end

endmodule