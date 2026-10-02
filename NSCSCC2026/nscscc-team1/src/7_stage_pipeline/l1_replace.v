`include "cache_defs.vh"

module l1_replace (
    input wire clk,
    input wire resetn,

    input wire way0_valid,
    input wire way1_valid,
    input wire [`CACHE_INDEX_WIDTH-1:0] victim_index,
    input wire [`CACHE_INDEX_WIDTH-1:0] lookup_index,

    input wire access_valid,
    input wire [`CACHE_INDEX_WIDTH-1:0] access_index,
    input wire access_way,

    output wire replace_way,
    output wire lru_victim_way,
    output wire lookup_lru_victim_way
);

wire [`CACHE_SETS-1:0] lru_victim_w;

genvar set_id;

generate
    for(set_id = 0;
        set_id < `CACHE_SETS;
        set_id = set_id + 1) begin : GEN_L1_LRU_STATE

        localparam [`CACHE_INDEX_WIDTH-1:0] SET_INDEX = set_id;

        reg lru_victim_r;

        assign lru_victim_w[set_id] = lru_victim_r;

        always @(posedge clk) begin
            if(!resetn) begin
                lru_victim_r <= 1'b0;
            end else if(access_valid &&
                        (access_index == SET_INDEX)) begin
                // 当前访问 Way 成为 MRU，
                // 另一个 Way 成为下一次替换目标。
                lru_victim_r <= ~access_way;
            end
        end
    end
endgenerate

assign lru_victim_way = lru_victim_w[victim_index];
assign lookup_lru_victim_way = lru_victim_w[lookup_index];

assign replace_way =
    !way0_valid ? 1'b0 :
    !way1_valid ? 1'b1 :
                  lru_victim_way;

endmodule
