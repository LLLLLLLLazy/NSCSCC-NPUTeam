`include "l2_cache_defs.vh"

module l2_axi_master (
    input wire clk,
    input wire resetn,

    input wire read_req,
    input wire [31:0] read_addr,
    input wire read_line,
    input wire [1:0] read_size,
    output wire read_ready,

    output wire [3:0] arid,
    output reg [31:0] araddr,
    output reg [7:0] arlen,
    output reg [2:0] arsize,
    output wire [1:0] arburst,
    output wire [1:0] arlock,
    output wire [3:0] arcache,
    output wire [2:0] arprot,
    output reg arvalid,
    input wire arready,

    // Current CPU/SoC assumes AXI responses are always OKAY; ID/RESP inputs
    // are kept only to preserve the existing AXI bus shape.
    input wire [3:0] rid,
    input wire [31:0] rdata,
    input wire [1:0] rresp,
    input wire rlast,
    input wire rvalid,
    output wire rready,

    output wire read_data_valid,
    output wire [`L2_WORD_WIDTH-1:0] read_data,
    output wire [`L2_BANK_WIDTH-1:0] read_beat,
    output wire read_last,
    output wire read_done,

    input wire write_req,
    input wire [31:0] write_addr,
    input wire write_line,
    input wire [1:0] write_size,
    input wire [`L2_WSTRB_WIDTH-1:0] write_wstrb,
    input wire [`L2_WORD_WIDTH-1:0] write_data,
    input wire [`L2_LINE_WIDTH-1:0] write_line_data,
    output wire write_ready,

    output wire [3:0] awid,
    output reg [31:0] awaddr,
    output reg [7:0] awlen,
    output reg [2:0] awsize,
    output wire [1:0] awburst,
    output wire [1:0] awlock,
    output wire [3:0] awcache,
    output wire [2:0] awprot,
    output reg awvalid,
    input wire awready,
    output wire [3:0] wid,
    output wire [`L2_WORD_WIDTH-1:0] wdata,
    output wire [`L2_WSTRB_WIDTH-1:0] wstrb,
    output wire wlast,
    output reg wvalid,
    input wire wready,
    input wire [3:0] bid,
    input wire [1:0] bresp,
    input wire bvalid,
    output wire bready,

    output wire write_done
);

localparam [1:0] R_IDLE = 2'd0;
localparam [1:0] R_AR   = 2'd1;
localparam [1:0] R_DATA = 2'd2;

localparam [1:0] W_IDLE = 2'd0;
localparam [1:0] W_AW   = 2'd1;
localparam [1:0] W_DATA = 2'd2;
localparam [1:0] W_RESP = 2'd3;

reg [1:0] read_state_r;
reg [1:0] write_state_r;
reg [`L2_BANK_WIDTH-1:0] read_beat_idx_r;
reg [`L2_BANK_WIDTH-1:0] write_beat_idx_r;
reg read_line_r;
reg write_line_r;
reg [`L2_WSTRB_WIDTH-1:0] write_wstrb_r;
reg [`L2_WORD_WIDTH-1:0] write_data_r;
reg [`L2_LINE_WIDTH-1:0] write_line_data_r;

wire read_channel_idle_w;
wire write_channel_idle_w;
wire ar_fire_w;
wire r_fire_w;
wire aw_fire_w;
wire w_fire_w;
wire b_fire_w;
wire read_beat_in_range_w;
wire read_req_fire_w;
wire write_req_fire_w;

// AXI 的 AR/R 与 AW/W/B 是相互独立的通道，规范允许读写同时 outstanding。
// 本模块内读侧与写侧各有独立的状态机、beat 计数和数据锁存，
// rready/bready 也互不相干，寄存器集合完全不相交，
// 因此两侧就绪与否只取决于自己那半边是否空闲。
assign read_channel_idle_w = (read_state_r == R_IDLE);
assign write_channel_idle_w = (write_state_r == W_IDLE);
assign ar_fire_w = arvalid && arready;
assign r_fire_w = rvalid && rready;
assign aw_fire_w = awvalid && awready;
assign w_fire_w = wvalid && wready;
assign b_fire_w = bvalid && bready;
assign read_beat_in_range_w = read_line_r ?
                              (read_beat_idx_r < `L2_LINE_WORDS) :
                              (read_beat_idx_r == {`L2_BANK_WIDTH{1'b0}});
assign read_req_fire_w = read_req && read_ready;
assign write_req_fire_w = write_req && write_ready;

// 原来这两个都接 (read_idle && write_idle)，把独立通道绑成了串行：
// 读要等写排空、写要等读排空，纯属白等。
// 拆开后行为在当前 l2_cache_core 下逐拍不变 —— core 是单 FSM，
// axi_read_req_w / axi_write_req_w 来自互斥状态，本来就不会同时发起。
// 这一步是让「写回与 refill 并行」（dirty miss 省 ~10 拍）成为可能的前提。
assign read_ready = read_channel_idle_w;
assign write_ready = write_channel_idle_w;
assign rready = read_state_r == R_DATA;
assign bready = write_state_r == W_RESP;

assign arid = `L2_AXI_ID;
assign arburst = `L2_AXI_BURST_INCR;
assign arlock = 2'b00;
assign arcache = 4'b0000;
assign arprot = 3'b000;

assign awid = `L2_AXI_ID;
assign awburst = `L2_AXI_BURST_INCR;
assign awlock = 2'b00;
assign awcache = 4'b0000;
assign awprot = 3'b000;
assign wid = `L2_AXI_ID;
assign wstrb = write_line_r ? {`L2_WSTRB_WIDTH{1'b1}} : write_wstrb_r;
assign wlast = (write_state_r == W_DATA) &&
               (write_line_r ? (write_beat_idx_r == `L2_LAST_BANK_INDEX) :
                (write_beat_idx_r == {`L2_BANK_WIDTH{1'b0}}));
assign wdata = !write_line_r ? write_data_r :
               (write_beat_idx_r == 3'd0) ? write_line_data_r[31:0] :
               (write_beat_idx_r == 3'd1) ? write_line_data_r[63:32] :
               (write_beat_idx_r == 3'd2) ? write_line_data_r[95:64] :
               (write_beat_idx_r == 3'd3) ? write_line_data_r[127:96] :
               (write_beat_idx_r == 3'd4) ? write_line_data_r[159:128] :
               (write_beat_idx_r == 3'd5) ? write_line_data_r[191:160] :
               (write_beat_idx_r == 3'd6) ? write_line_data_r[223:192] :
               write_line_data_r[255:224];

assign read_data_valid = r_fire_w && read_beat_in_range_w;
assign read_data = rdata;
assign read_beat = read_beat_idx_r[`L2_BANK_WIDTH-1:0];
assign read_last = r_fire_w && rlast;
assign read_done = read_last;

assign write_done = b_fire_w;

always @(posedge clk) begin
    if(!resetn) begin
        read_state_r <= R_IDLE;
        arvalid <= 1'b0;
    end else begin
        case(read_state_r)
            R_IDLE: begin
                arvalid <= 1'b0;
                if(read_req_fire_w) begin
                    read_state_r <= R_AR;
                    arvalid <= 1'b1;
                    araddr <= read_line ?
                              {read_addr[31:`L2_OFFSET_WIDTH],
                               {`L2_OFFSET_WIDTH{1'b0}}} :
                              read_addr;
                    arlen <= read_line ? `L2_AXI_LINE_LEN :
                             `L2_AXI_WORD_LEN;
                    arsize <= read_line ? `L2_AXI_WORD_SIZE :
                              {1'b0, read_size};
                    read_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                    read_line_r <= read_line;
                end
            end
            R_AR: begin
                if(ar_fire_w) begin
                    read_state_r <= R_DATA;
                    arvalid <= 1'b0;
                    read_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                end
            end
            R_DATA: begin
                if(r_fire_w) begin
                    if(rlast) begin
                        read_state_r <= R_IDLE;
                        read_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                    end else begin
                        read_beat_idx_r <= read_beat_idx_r + 1'b1;
                    end
                end
            end
            default: begin
                read_state_r <= R_IDLE;
                arvalid <= 1'b0;
                read_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                read_line_r <= 1'b0;
            end
        endcase
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        write_state_r <= W_IDLE;
        awvalid <= 1'b0;
        wvalid <= 1'b0;
    end else begin
        case(write_state_r)
            W_IDLE: begin
                awvalid <= 1'b0;
                wvalid <= 1'b0;
                if(write_req_fire_w) begin
                    write_state_r <= W_AW;
                    awvalid <= 1'b1;
                    awaddr <= write_line ?
                              {write_addr[31:`L2_OFFSET_WIDTH],
                               {`L2_OFFSET_WIDTH{1'b0}}} :
                              write_addr;
                    awlen <= write_line ? `L2_AXI_LINE_LEN :
                             `L2_AXI_WORD_LEN;
                    awsize <= write_line ? `L2_AXI_WORD_SIZE :
                              {1'b0, write_size};
                    write_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                    write_line_r <= write_line;
                    write_wstrb_r <= write_wstrb;
                    write_data_r <= write_data;
                    write_line_data_r <= write_line_data;
                end
            end
            W_AW: begin
                if(aw_fire_w) begin
                    write_state_r <= W_DATA;
                    awvalid <= 1'b0;
                    wvalid <= 1'b1;
                    write_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                end
            end
            W_DATA: begin
                if(w_fire_w) begin
                    if(wlast) begin
                        write_state_r <= W_RESP;
                        wvalid <= 1'b0;
                        write_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                    end else begin
                        write_beat_idx_r <= write_beat_idx_r + 1'b1;
                    end
                end
            end
            W_RESP: begin
                if(b_fire_w) begin
                    write_state_r <= W_IDLE;
                end
            end
            default: begin
                write_state_r <= W_IDLE;
                awvalid <= 1'b0;
                wvalid <= 1'b0;
                write_beat_idx_r <= {`L2_BANK_WIDTH{1'b0}};
                write_line_r <= 1'b0;
            end
        endcase
    end
end

endmodule
