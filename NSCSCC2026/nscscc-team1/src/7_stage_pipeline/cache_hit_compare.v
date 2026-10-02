`include "cache_defs.vh"

module cache_hit_compare (
    input wire req_valid,
    input wire [`CACHE_TAG_WIDTH-1:0] req_tag,

    input wire way0_valid,
    input wire way0_dirty,
    input wire [`CACHE_TAG_WIDTH-1:0] way0_tag,
    input wire [`CACHE_WORD_WIDTH-1:0] way0_rdata,

    input wire way1_valid,
    input wire way1_dirty,
    input wire [`CACHE_TAG_WIDTH-1:0] way1_tag,
    input wire [`CACHE_WORD_WIDTH-1:0] way1_rdata,

    output wire hit,
    output wire hit_way,
    output wire hit_dirty,
    output wire [`CACHE_WORD_WIDTH-1:0] hit_rdata
);

wire way0_hit_w;
wire way1_hit_w;

assign way0_hit_w = req_valid && way0_valid && (way0_tag == req_tag);
assign way1_hit_w = req_valid && way1_valid && (way1_tag == req_tag);

assign hit = way0_hit_w || way1_hit_w;
assign hit_way = way1_hit_w;
assign hit_dirty = way1_hit_w ? way1_dirty : way0_dirty;
assign hit_rdata = way1_hit_w ? way1_rdata : way0_rdata;

endmodule
