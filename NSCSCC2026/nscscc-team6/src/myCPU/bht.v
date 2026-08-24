// ============================================================================
// Branch History Table (BHT) — Local History Predictor
// Stores per-branch local history patterns (shift registers of recent outcomes).
// Indexed by PC (same index bits as BTB), no tags — aliasing is tolerated.
// ============================================================================
module bht #(
    parameter ADDR_WIDTH = 32,
    parameter INDEX_BITS = 6,       // 64 entries
    parameter HIST_BITS  = 8        // 8-bit local history per entry
) (
    input  wire                     clk,
    input  wire                     reset,

    // ---- 4 read ports (combinational) for fetch-group query ----
    input  wire [ADDR_WIDTH-1:0]    pc_query0,
    input  wire [ADDR_WIDTH-1:0]    pc_query1,
    input  wire [ADDR_WIDTH-1:0]    pc_query2,
    input  wire [ADDR_WIDTH-1:0]    pc_query3,
    output wire [HIST_BITS-1:0]     history0,
    output wire [HIST_BITS-1:0]     history1,
    output wire [HIST_BITS-1:0]     history2,
    output wire [HIST_BITS-1:0]     history3,

    // ---- Update read port (combinational) — OLD history for PHT update ----
    output wire [HIST_BITS-1:0]     update_history,

    // ---- 1 write port (sequential, commit-level) ----
    input  wire                     update_en,
    input  wire [ADDR_WIDTH-1:0]    pc_update,
    input  wire                     actual_taken
);

    localparam ENTRIES = (1 << INDEX_BITS);

    // Derive index from PC (same formula as BTB: PC[INDEX_BITS+1 : 2])
    wire [INDEX_BITS-1:0] query_index0 = pc_query0[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] query_index1 = pc_query1[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] query_index2 = pc_query2[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] query_index3 = pc_query3[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] update_index = pc_update[INDEX_BITS+1:2];

    // ---- Storage ----
    reg [HIST_BITS-1:0] bht_mem [0:ENTRIES-1];

    // ---- Combinational reads (4 query ports + 1 update read port) ----
    assign history0 = bht_mem[query_index0];
    assign history1 = bht_mem[query_index1];
    assign history2 = bht_mem[query_index2];
    assign history3 = bht_mem[query_index3];
    assign update_history = bht_mem[update_index];  // OLD value, for PHT update

    // ---- Sequential write (commit-level update) ----
    // Read old history combinationaly, shift in actual_taken at posedge.
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                bht_mem[i] <= {HIST_BITS{1'b0}};
            end
        end else if (update_en) begin
            // Shift left: drop oldest bit, append actual_taken as new LSB
            bht_mem[update_index] <= {bht_mem[update_index][HIST_BITS-2:0], actual_taken};
        end
    end

endmodule
