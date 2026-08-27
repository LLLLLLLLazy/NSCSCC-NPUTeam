
module ins_fifo_mp #(
        parameter DEPTH  = 8,
        parameter DATA_W = 102
    ) (
        input wire clk,
        input wire resetn,

        input wire clear,

        // Write port
        input  wire              in_valid,
        output wire              wr_ready,
        input  wire [DATA_W-1:0] in_data,

        // Read port
        input  wire              stall,
        output wire              out_valid,
        output wire [DATA_W-1:0] out_data,

        // Status
        output wire [7:0] count,
        output wire [7:0] avail
    );

    localparam PTR_W = $clog2(DEPTH);
    localparam [PTR_W:0] DEPTH_VALUE = DEPTH;

    reg  [DATA_W-1:0] mem     [0:DEPTH-1];
    reg  [   PTR_W:0] wptr;
    reg  [   PTR_W:0] rptr;

    wire [   PTR_W:0] used;
    wire              empty;
    wire              full;
    wire              rd_fire;
    wire              wr_fire;

    // wptr/rptr have one extra bit to distinguish empty and full.
    assign used      = wptr - rptr;
    assign empty     = (used == {(PTR_W + 1) {1'b0}});
    assign full      = (used == DEPTH_VALUE);

    // If FIFO is full but one entry is popped this cycle, pushing is allowed.
    assign rd_fire   = out_valid && !stall;
    assign wr_fire   = in_valid && wr_ready;
    assign wr_ready  = (!full || rd_fire);

    assign out_valid = !empty;
    assign out_data  = out_valid ? mem[rptr[PTR_W-1:0]] : {DATA_W{1'b0}};

    assign count     = {{(8 - PTR_W - 1) {1'b0}}, used};
    assign avail     = {{(8 - PTR_W - 1) {1'b0}}, (DEPTH_VALUE - used)};

    always @(posedge clk) begin
        if (!resetn) begin
            wptr <= {(PTR_W + 1) {1'b0}};
            rptr <= {(PTR_W + 1) {1'b0}};
        end
        else if (clear) begin
            wptr <= {(PTR_W + 1) {1'b0}};
            rptr <= {(PTR_W + 1) {1'b0}};
        end
        else begin
            if (wr_fire) begin
                mem[wptr[PTR_W-1:0]] <= in_data;
                wptr                 <= wptr + {{PTR_W{1'b0}}, 1'b1};
            end

            if (rd_fire) begin
                rptr <= rptr + {{PTR_W{1'b0}}, 1'b1};
            end
        end
    end

endmodule
