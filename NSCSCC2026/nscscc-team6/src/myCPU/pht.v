// ============================================================================
// Pattern History Table (PHT) — Local History Predictor
// Stores 2-bit saturating counters indexed by local history patterns.
// Together with BHT, forms a two-level local history (also called Yeh-Patt)
// branch predictor.
// ============================================================================
module pht #(
    parameter HIST_BITS    = 8,     // 256 entries (2^8)
    parameter COUNTER_BITS = 2      // 2-bit saturating counter
) (
    input  wire                     clk,
    input  wire                     reset,

    // ---- 4 read ports (combinational) — one per fetch-group slot ----
    input  wire [HIST_BITS-1:0]     query_pattern0,
    input  wire [HIST_BITS-1:0]     query_pattern1,
    input  wire [HIST_BITS-1:0]     query_pattern2,
    input  wire [HIST_BITS-1:0]     query_pattern3,
    output wire [COUNTER_BITS-1:0]  counter0,
    output wire [COUNTER_BITS-1:0]  counter1,
    output wire [COUNTER_BITS-1:0]  counter2,
    output wire [COUNTER_BITS-1:0]  counter3,

    // ---- 1 write port (sequential, commit-level) ----
    input  wire                     update_en,
    input  wire [HIST_BITS-1:0]     update_pattern,   // OLD history (before BHT shift)
    input  wire                     actual_taken
);

    localparam ENTRIES = (1 << HIST_BITS);

    // ---- Storage ----
    reg [COUNTER_BITS-1:0] pht_mem [0:ENTRIES-1];

    // ---- Combinational reads (4 ports) ----
    assign counter0 = pht_mem[query_pattern0];
    assign counter1 = pht_mem[query_pattern1];
    assign counter2 = pht_mem[query_pattern2];
    assign counter3 = pht_mem[query_pattern3];

    // ---- Sequential write (commit-level update) ----
    // Update the counter indexed by the OLD history pattern.
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                pht_mem[i] <= {COUNTER_BITS{1'b0}};
            end
        end else if (update_en) begin
            if (actual_taken && pht_mem[update_pattern] != {COUNTER_BITS{1'b1}})
                pht_mem[update_pattern] <= pht_mem[update_pattern] + 1'b1;
            else if (!actual_taken && pht_mem[update_pattern] != {COUNTER_BITS{1'b0}})
                pht_mem[update_pattern] <= pht_mem[update_pattern] - 1'b1;
        end
    end

endmodule
