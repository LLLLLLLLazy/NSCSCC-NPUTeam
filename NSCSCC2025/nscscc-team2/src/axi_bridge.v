module axi_bridge(
    input  wire          clk,
    input  wire          reset,

    // AXI Read Address Channel
    output reg    [3:0]  arid,
    output reg   [31:0]  araddr,
    output reg    [7:0]  arlen,
    output reg    [2:0]  arsize,
    output wire   [1:0]  arburst,
    output wire   [1:0]  arlock,
    output wire   [3:0]  arcache,
    output wire   [2:0]  arprot,
    output reg           arvalid,
    input  wire          arready,

    // AXI Read Data Channel
    input  wire   [3:0]  rid,
    input  wire  [31:0]  rdata,
    input  wire   [1:0]  rresp,
    input  wire          rlast,
    input  wire          rvalid,
    output reg           rready,
 
    // AXI Write Address Channel
    output wire   [3:0]  awid,
    output reg   [31:0]  awaddr,
    output reg    [7:0]  awlen,
    output reg    [2:0]  awsize,
    output wire   [1:0]  awburst,
    output wire   [1:0]  awlock,
    output wire   [3:0]  awcache,
    output wire   [2:0]  awprot,
    output reg           awvalid,
    input  wire          awready,

    // AXI Write Data Channel
    output wire   [3:0]  wid,
    output reg   [31:0]  wdata,
    output reg    [3:0]  wstrb,
    output reg           wlast,
    output reg           wvalid,
    input  wire          wready,

    // AXI Write Response Channel
    input  wire   [3:0]  bid,
    input  wire   [1:0]  bresp,
    input  wire          bvalid,
    output reg           bready,

    // Cache Interface: Instruction Read
    input  wire          inst_rd_req,
    input  wire   [2:0]  inst_rd_type,
    input  wire  [31:0]  inst_rd_addr,
    output wire          inst_rd_rdy,
    output wire          inst_ret_valid,
    output wire          inst_ret_last,
    output wire  [31:0]  inst_ret_data,

    // Cache Interface: Instruction Write
    input  wire          inst_wr_req,
    input  wire   [2:0]  inst_wr_type,
    input  wire  [31:0]  inst_wr_addr,
    input  wire   [3:0]  inst_wr_wstrb,
    input  wire [127:0]  inst_wr_data,
    output wire          inst_wr_rdy,

    // Cache Interface: Data Read
    input  wire          data_rd_req,
    input  wire   [2:0]  data_rd_type,
    input  wire  [31:0]  data_rd_addr,
    output wire          data_rd_rdy,
    output wire          data_ret_valid,
    output wire          data_ret_last,
    output wire  [31:0]  data_ret_data,
 
    // Cache Interface: Data Write
    input  wire          data_wr_req,
    input  wire   [2:0]  data_wr_type,
    input  wire  [31:0]  data_wr_addr,
    input  wire   [3:0]  data_wr_wstrb,
    input  wire [127:0]  data_wr_data,
    output wire          data_wr_rdy,

    // Write Buffer Status
    output wire          write_buffer_empty
);

// Fixed AXI signals
assign arburst = 2'b01;
assign arlock  = 2'b00;
assign arcache = 4'b0000;
assign arprot  = 3'b000;
assign awid    = 4'b0001;
assign awburst = 2'b01;
assign awlock  = 2'b00;
assign awcache = 4'b0000;
assign awprot  = 3'b000;
assign wid     = 4'b0001;

assign inst_wr_rdy = 1'b1;

// State definitions
localparam RREQ_EMPTY = 1'b0;
localparam RREQ_READY = 1'b1;
localparam RRESP_EMPTY = 1'b0;
localparam RRESP_TRANS = 1'b1;
localparam WREQ_EMPTY = 3'b000;
localparam WD_WAIT   = 3'b101;
localparam WD_TRANS  = 3'b100;
localparam W_WAIT_B  = 3'b110;

// Internal state registers 
reg        rdreq_st;
reg        rrsp_st;
reg [2:0]  wrreq_st;

// Control wires
wire       wr_enable;
wire       rdreq_empty;
wire       rdreq_can;
wire       data_rd_cache, inst_rd_cache;
wire [2:0] data_rd_size, inst_rd_size;
wire [7:0] data_rd_len, inst_rd_len;
wire       data_wr_cache;
wire [2:0] data_wr_size;
wire [7:0] data_wr_len;

reg [127:0] write_buffer_data;
reg [2:0]  write_buffer_num;
wire       write_buffer_last;

// Write buffer empty when no pending data and not waiting on write
assign write_buffer_empty = (write_buffer_num == 3'b000) && !wr_enable;

// Read request availability
assign rdreq_empty = (rdreq_st == RREQ_EMPTY);
assign rdreq_can = rdreq_empty && !(wr_enable && !(bvalid && bready));

assign data_rd_rdy = rdreq_can;
assign inst_rd_rdy = !data_rd_req && rdreq_can;

// Determine AXI burst size/length for cache-line accesses
assign data_rd_cache = (data_rd_type == 3'b100);
assign data_rd_size  = data_rd_cache ? 3'b010 : data_rd_type;
assign data_rd_len   = data_rd_cache ? 8'b00000011 : 8'b0;

assign inst_rd_cache = (inst_rd_type == 3'b100);
assign inst_rd_size  = inst_rd_cache ? 3'b010 : inst_rd_type;
assign inst_rd_len   = inst_rd_cache ? 8'b00000011 : 8'b0;

assign data_wr_cache = (data_wr_type == 3'b100);
assign data_wr_size  = data_wr_cache ? 3'b010 : data_wr_type;
assign data_wr_len   = data_wr_cache ? 8'b00000011 : 8'b0;

// Read response routing (rid bit 0 selects inst vs data)
assign inst_ret_valid = (!rid[0]) && rvalid;
assign inst_ret_last  = (!rid[0]) && rlast;
assign inst_ret_data  = rdata;
assign data_ret_valid = (rid[0]) && rvalid;
assign data_ret_last  = (rid[0]) && rlast;
assign data_ret_data  = rdata;

// Write request ready signal
assign data_wr_rdy = (wrreq_st == WREQ_EMPTY);

// Last beat of write buffer
assign write_buffer_last = (write_buffer_num == 3'b001);

// Indicates a write operation is in progress (used to pause reads)
assign wr_enable = ~(wrreq_st == WREQ_EMPTY);

// Read request state machine 
always @(posedge clk) begin
    if (reset) begin
        rdreq_st <= RREQ_EMPTY;
        arvalid  <= 1'b0;
    end else if (rdreq_st == RREQ_EMPTY) begin
        // Start a new read request if requested by data or inst
        if (data_rd_req) begin
            if (wr_enable) begin
                if (bvalid && bready) begin
                    rdreq_st <= RREQ_READY;
                    arid     <= 4'b0001;          // ID = data (1)
                    araddr   <= data_rd_addr;
                    arsize   <= data_rd_size;
                    arlen    <= data_rd_len;
                    arvalid  <= 1'b1;
                end
            end else begin
                rdreq_st <= RREQ_READY;
                arid     <= 4'b0001;
                araddr   <= data_rd_addr;
                arsize   <= data_rd_size;
                arlen    <= data_rd_len;
                arvalid  <= 1'b1;
            end
        end else if (inst_rd_req) begin
            if (wr_enable) begin
                if (bvalid && bready) begin
                    rdreq_st <= RREQ_READY;
                    arid     <= 4'b0000;          // ID = inst (0)
                    araddr   <= inst_rd_addr;
                    arsize   <= inst_rd_size;
                    arlen    <= inst_rd_len;
                    arvalid  <= 1'b1;
                end
            end else begin
                rdreq_st <= RREQ_READY;
                arid     <= 4'b0000;
                araddr   <= inst_rd_addr;
                arsize   <= inst_rd_size;
                arlen    <= inst_rd_len;
                arvalid  <= 1'b1;
            end
        end
    end else if (rdreq_st == RREQ_READY) begin
        // Wait for AR ready to complete handshake
        if (arready) begin
            rdreq_st <= RREQ_EMPTY;
            arvalid  <= 1'b0;
        end
    end
end

// Read response state machine 
always @(posedge clk) begin
    if (reset) begin
        rrsp_st <= RRESP_EMPTY;
        rready  <= 1'b1;
    end else if (rrsp_st == RRESP_EMPTY) begin
        if (rvalid && rready) begin
            rrsp_st <= RRESP_TRANS;
        end
    end else if (rrsp_st == RRESP_TRANS) begin
        if (rlast && rvalid) begin
            rrsp_st <= RRESP_EMPTY;
        end
    end
end

// Write request state machine 
always @(posedge clk) begin
    if (reset) begin
        wrreq_st         <= WREQ_EMPTY;
        awvalid          <= 1'b0;
        wvalid           <= 1'b0;
        wlast            <= 1'b0;
        bready           <= 1'b0;
        write_buffer_num <= 3'b000;
        write_buffer_data<= 128'b0;
    end else if (wrreq_st == WREQ_EMPTY) begin
        // New write request from data cache
        if (data_wr_req) begin
            wrreq_st <= WD_WAIT;
            awaddr   <= data_wr_addr;
            awsize   <= data_wr_size;
            awlen    <= data_wr_len;
            awvalid  <= 1'b1;
            wdata    <= data_wr_data[31:0];
            wstrb    <= data_wr_wstrb;
            write_buffer_data <= data_wr_data[127:0] >> 32;  // next 96 bits

            if (data_wr_type == 3'b100) begin
                write_buffer_num <= 3'b011;  // 4 beats total (3 more after first)
            end else begin
                write_buffer_num <= 3'b000;
                wlast <= 1'b1;
            end
        end
    end else if (wrreq_st == WD_WAIT) begin
        if (awready) begin
            wrreq_st <= WD_TRANS;
            awvalid  <= 1'b0;
            wvalid   <= 1'b1;
        end
    end else if (wrreq_st == WD_TRANS) begin
        if (wready) begin
            if (wlast) begin
                wrreq_st <= W_WAIT_B;
                wvalid   <= 1'b0;
                wlast    <= 1'b0;
                bready   <= 1'b1;
            end else begin
                if (write_buffer_last) begin
                    wlast <= 1'b1;
                end
                // Remain in WD_TRANS state
                wdata    <= write_buffer_data[31:0];
                wvalid   <= 1'b1;
                write_buffer_data <= {32'b0, write_buffer_data[127:32]};
                write_buffer_num  <= write_buffer_num - 3'b001;
            end
        end
    end else if (wrreq_st == W_WAIT_B) begin
        if (bvalid && bready) begin
            wrreq_st <= WREQ_EMPTY;
            bready   <= 1'b0;
        end
    end else begin
        // Default fallback state
        wrreq_st <= WREQ_EMPTY;
    end
end

endmodule
