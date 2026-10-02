`include "cache_defs.vh"

// I-cache miss/refill request adapter.
//
// 请求侧（AR）保持原来的 AXI 形状；返回侧已经不再是 AXI 了 ——
// L1 和 L2 都在同一块芯片里，两边的数据本来都是并行的 256 位整行，
// 中间那层「拆成 8 个 beat 再拼回去」纯属历史包袱（L1 当初是对着
// 外部 AXI 写的）。现在返回通道一拍给整行：
//   - line 读：整行按 bank 自然顺序（bank0 在最低 32 位）
//   - uncached 单字读：目标字在最低 32 位，高位为 0
// 于是 beat 计数、CWF 旋转、ret_last 全部不需要了。
module icache_l2_read (
    input wire clk,
    input wire resetn,

    input wire rd_req,
    input wire [31:0] rd_addr,
    input wire rd_line,
    output wire rd_ready,

    output wire [3:0] arid,
    output reg [31:0] araddr,
    output reg [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    output reg arvalid,
    input wire arready,

    input wire [`CACHE_LINE_WIDTH-1:0] rline,
    input wire rvalid,
    output wire rready,

    output wire ret_valid,
    output wire [`CACHE_LINE_WIDTH-1:0] ret_line
);

// 已发出 AR，并正在等待 R 响应。
reg resp_busy_r;

// AR 通道握手成功。
wire ar_fire_w;
// R 通道握手成功。单拍即整行，握手一次就结束。
wire r_fire_w;

assign ar_fire_w = arvalid && arready;
assign r_fire_w = rvalid && rready;

assign arid = `CACHE_AXI_ID_ICACHE;
assign arsize = `CACHE_AXI_WORD_SIZE;
assign arburst = 2'b01;

assign rd_ready = !arvalid && !resp_busy_r;
assign rready = resp_busy_r;

assign ret_valid = r_fire_w;
assign ret_line = rline;

always @(posedge clk) begin
    if(!resetn) begin
        arvalid <= 1'b0;
        araddr <= 32'b0;
        arlen <= 8'b0;
        resp_busy_r <= 1'b0;
    end else begin
        if(rd_req && rd_ready) begin
            arvalid <= 1'b1;
            // 只清字内字节偏移，保留 bank 位。
            // bank 位对 L2 数组访问已经没用了（返回整行），但 L2 miss 时
            // l2_axi_master 仍靠它做到 DDR 的 critical-word-first，
            // 所以这里照旧传下去。
            araddr <= rd_line ?
                      {rd_addr[31:`CACHE_BANK_LSB],
                       {`CACHE_BANK_LSB{1'b0}}} :
                      rd_addr;
            arlen <= rd_line ? `CACHE_AXI_LINE_LEN : `CACHE_AXI_WORD_LEN;
        end

        if(ar_fire_w) begin
            arvalid <= 1'b0;
            resp_busy_r <= 1'b1;
        end

        if(r_fire_w) begin
            resp_busy_r <= 1'b0;
        end
    end
end

endmodule
