`include "cache_defs.vh"
`include "l2_cache_defs.vh"

// D-cache writeback/uncached write request adapter.
//
// 写方向也已经不是 AXI 了 —— 整行一拍给出，不再拆成 8 个 beat。
// 对 L2 来说，无论是 cached line writeback 还是 uncached 单字写，
// 都通过一个 256 位的 wline + 32 位的 wstrb（每个 bank 4 位）来表达：
//   - line 写：wline 是完整的 8 个字，wstrb 全 1
//   - uncached 单字写：目标字放在对应 bank 的位置，wstrb 只有那个 bank 的 4 位有效
module dcache_l2_write (
    input wire clk,
    input wire resetn,

    input wire wr_req,
    input wire [31:0] wr_addr,
    input wire wr_line,
    input wire [`L2_SOURCE_WIDTH-1:0] wr_source,
    input wire [1:0] wr_size,
    input wire [`CACHE_WSTRB_WIDTH-1:0] wr_wstrb,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_data,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data0,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data1,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data2,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data3,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data4,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data5,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data6,
    input wire [`CACHE_WORD_WIDTH-1:0] wr_line_data7,

    output wire wr_ready,
    output wire wr_done,

    output wire [3:0] awid,
    output wire [`L2_SOURCE_WIDTH-1:0] awsource,
    output reg [31:0] awaddr,
    output reg [7:0] awlen,
    output reg [2:0] awsize,
    output wire [1:0] awburst,
    output reg awvalid,
    input wire awready,

    output wire [3:0] wid,
    output reg [`CACHE_LINE_WIDTH-1:0] wline,
    output reg [`CACHE_LINE_WIDTH/8-1:0] wstrb,
    output reg wlast,
    output reg wvalid,
    input wire wready,

    input wire [3:0] bid,
    input wire bvalid,
    output wire bready
);

localparam S_IDLE = 2'd0;
localparam S_AW = 2'd1;
localparam S_W = 2'd2;
localparam S_B = 2'd3;

reg [1:0] state_r;
reg req_line_r;
reg [`L2_SOURCE_WIDTH-1:0] req_source_r;
reg [2:0] req_bank_r;
reg [`CACHE_WSTRB_WIDTH-1:0] req_wstrb_r;
reg [`CACHE_WORD_WIDTH-1:0] req_data_r;
reg [`CACHE_LINE_WIDTH-1:0] req_line_data_r;

reg wr_done_r;

// AW 通道握手成功。
wire aw_fire_w;
// W 通道握手成功。
wire w_fire_w;
// B 通道握手成功。
wire b_fire_w;

assign aw_fire_w = awvalid && awready;
assign w_fire_w = wvalid && wready;
assign b_fire_w = bvalid && bready;

assign awid = `CACHE_AXI_ID_DCACHE;
assign awsource = req_source_r;
assign wid = `CACHE_AXI_ID_DCACHE;
assign awburst = 2'b01;
assign wr_ready = (state_r == S_IDLE);
assign wr_done = wr_done_r;
assign bready = (state_r == S_B);

always @(posedge clk) begin
    if(!resetn) begin
        state_r <= S_IDLE;
        awvalid <= 1'b0;
        wvalid <= 1'b0;
        wlast <= 1'b0;
    end else begin
        wr_done_r <= 1'b0;

        case(state_r)
            S_IDLE: begin
                awvalid <= 1'b0;
                wvalid <= 1'b0;
                wlast <= 1'b0;

                if(wr_req) begin
                    req_line_r <= wr_line;
                    req_source_r <= wr_source;
                    req_bank_r <= wr_addr[`CACHE_BANK_MSB:`CACHE_BANK_LSB];
                    req_wstrb_r <= wr_wstrb;
                    req_data_r <= wr_data;
                    req_line_data_r <= {wr_line_data7, wr_line_data6,
                                        wr_line_data5, wr_line_data4,
                                        wr_line_data3, wr_line_data2,
                                        wr_line_data1, wr_line_data0};

                    awaddr <= wr_line ?
                              {wr_addr[31:`CACHE_OFFSET_WIDTH],
                               {`CACHE_OFFSET_WIDTH{1'b0}}} :
                              wr_addr;
                    awlen <= wr_line ? `CACHE_AXI_LINE_LEN : `CACHE_AXI_WORD_LEN;
                    awsize <= wr_line ? `CACHE_AXI_WORD_SIZE : {1'b0, wr_size};
                    awvalid <= 1'b1;
                    state_r <= S_AW;
                end
            end

            S_AW: begin
                if(aw_fire_w) begin
                    awvalid <= 1'b0;
                    wvalid <= 1'b1;
                    wlast <= 1'b1;

                    if(req_line_r) begin
                        // 整行写：8 个 bank 全有效，自然顺序（bank0 在最低 32 位）。
                        wline <= req_line_data_r;
                        wstrb <= {`CACHE_LINE_WIDTH/8{1'b1}};
                    end else begin
                        // uncached 单字写：数据放在 wline[31:0]，只用低 4 位 strobe。
                        // L2 core 的 uncached 写只读 ctx_line_data_r[31:0]，
                        // 地址本身决定目标地址，不需要在行里做 bank 偏移。
                        wline <= {{`CACHE_LINE_WIDTH-`CACHE_WORD_WIDTH{1'b0}}, req_data_r};
                        wstrb <= {{`CACHE_LINE_WIDTH/8-`CACHE_WSTRB_WIDTH{1'b0}}, req_wstrb_r};
                    end

                    state_r <= S_W;
                end
            end

            S_W: begin
                if(w_fire_w) begin
                    wvalid <= 1'b0;
                    wlast <= 1'b0;
                    state_r <= S_B;
                end
            end

            S_B: begin
                if(b_fire_w) begin
                    wr_done_r <= 1'b1;
                    state_r <= S_IDLE;
                end
            end

            default: begin
                state_r <= S_IDLE;
            end
        endcase
    end
end

endmodule
