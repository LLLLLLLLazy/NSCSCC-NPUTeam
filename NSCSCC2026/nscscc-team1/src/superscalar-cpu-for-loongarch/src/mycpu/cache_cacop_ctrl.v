`include "cache_defs.vh"
`include "cache_cacop_defs.vh"
`include "l2_cache_defs.vh"

module cache_cacop_ctrl (
    input wire clk,
    input wire resetn,

    input wire cacop_nop,
    input wire [4:0] cacop_code,
    input wire [31:0] cacop_va,
    input wire [31:0] cacop_pa,
    output wire cacop_addr_ok,
    output wire cacop_data_ok,

    output wire i_maint_valid,
    output wire [1:0] i_maint_op,
    output wire i_maint_way,
    output wire [`CACHE_INDEX_WIDTH-1:0] i_maint_index,
    output wire [`CACHE_TAG_WIDTH-1:0] i_maint_tag,
    input wire i_maint_addr_ok,
    input wire i_maint_data_ok,


    output wire d_maint_valid,
    output wire [1:0] d_maint_op,
    output wire d_maint_way,
    output wire [`CACHE_INDEX_WIDTH-1:0] d_maint_index,
    output wire [`CACHE_TAG_WIDTH-1:0] d_maint_tag,
    input wire d_maint_addr_ok,
    input wire d_maint_data_ok,

    output wire l2_maint_valid,
    output wire [1:0] l2_maint_op,
    output wire [31:0] l2_maint_addr,
    input wire l2_maint_addr_ok,
    input wire l2_maint_data_ok
);

reg pending_valid_r;
reg wait_drop_r;
reg pending_icache_r;
reg pending_dcache_r;
reg pending_l2_r;
reg pending_icache_dispatched_r;
reg pending_dcache_dispatched_r;
reg pending_l2_dispatched_r;
reg pending_icache_done_r;
reg pending_dcache_done_r;
reg pending_l2_done_r;
reg pending_l2_all_ways_r;
reg [`L2_WAY_WIDTH-1:0] pending_l2_way_r;
reg [1:0] pending_op_r;
reg pending_way_r;
reg [`CACHE_INDEX_WIDTH-1:0] pending_index_r;
reg [`CACHE_TAG_WIDTH-1:0] pending_tag_r;
reg [31:0] pending_l2_addr_r;


wire code_store_tag_w;
wire code_index_inv_w;
wire code_hit_inv_w;
wire target_icache_w;
wire target_dcache_w;
wire target_l2_w;
wire supported_op_w;
wire real_req_w;
wire direct_l2_maint_w;
wire direct_l2_all_ways_w;
wire fire_w;
wire i_maint_fire_w;
wire d_maint_fire_w;
wire l2_maint_fire_w;
wire target_done_w;
wire noop_done_w;
wire [1:0] decoded_op_w;
wire maint_dispatched_w;

assign code_store_tag_w = (cacop_code[4:3] == `CACHE_CACOP_CODE_STORE_TAG);
assign code_index_inv_w = (cacop_code[4:3] == `CACHE_CACOP_CODE_INDEX_INV);
assign code_hit_inv_w = (cacop_code[4:3] == `CACHE_CACOP_CODE_HIT_INV);
assign target_icache_w = (cacop_code[2:0] == `CACHE_CACOP_TARGET_ICACHE);
assign target_dcache_w = (cacop_code[2:0] == `CACHE_CACOP_TARGET_DCACHE);
assign target_l2_w = (cacop_code[2:0] == `CACHE_CACOP_TARGET_L2);
assign supported_op_w = code_store_tag_w || code_index_inv_w || code_hit_inv_w;
assign real_req_w = supported_op_w &&
                    (target_icache_w || target_dcache_w || target_l2_w);
assign decoded_op_w = code_hit_inv_w ? `CACHE_CACOP_MAINT_HIT_INV :
                      code_index_inv_w ? `CACHE_CACOP_MAINT_INDEX_INV :
                      `CACHE_CACOP_MAINT_STORE_TAG;
assign direct_l2_maint_w = target_l2_w ||
                           (target_icache_w &&
                            (code_store_tag_w ||
                             code_index_inv_w ||
                             code_hit_inv_w)) ||
                           (target_dcache_w && code_store_tag_w);
assign direct_l2_all_ways_w =
    (target_icache_w && (code_store_tag_w || code_index_inv_w)) ||
    (target_dcache_w && code_store_tag_w);

assign cacop_addr_ok = cacop_nop && !pending_valid_r && !wait_drop_r;
assign fire_w = cacop_nop && cacop_addr_ok;

assign i_maint_valid = pending_valid_r && pending_icache_r &&
                       !pending_icache_dispatched_r;
assign d_maint_valid = pending_valid_r && pending_dcache_r &&
                       !pending_dcache_dispatched_r;
assign i_maint_op = pending_op_r;
assign i_maint_way = pending_way_r;
assign i_maint_index = pending_index_r;
assign i_maint_tag = pending_tag_r;
assign d_maint_op = pending_op_r;
assign d_maint_way = pending_way_r;
assign d_maint_index = pending_index_r;
assign d_maint_tag = pending_tag_r;
assign l2_maint_valid = pending_valid_r && pending_l2_r &&
                        !pending_l2_dispatched_r;
assign l2_maint_op = pending_op_r;
assign l2_maint_addr = pending_l2_all_ways_r ?
                       {pending_l2_addr_r[31:`L2_WAY_WIDTH],
                        pending_l2_way_r} :
                       pending_l2_addr_r;

assign i_maint_fire_w = i_maint_valid && i_maint_addr_ok;
assign d_maint_fire_w = d_maint_valid && d_maint_addr_ok;
assign l2_maint_fire_w = l2_maint_valid && l2_maint_addr_ok;
assign maint_dispatched_w = i_maint_fire_w || d_maint_fire_w ||
                            l2_maint_fire_w;
assign target_done_w = (!pending_icache_r || pending_icache_done_r) &&
                       (!pending_dcache_r || pending_dcache_done_r) &&
                       (!pending_l2_r || pending_l2_done_r);
assign noop_done_w = pending_valid_r && !pending_icache_r &&
                     !pending_dcache_r && !pending_l2_r;
assign cacop_data_ok = pending_valid_r && (target_done_w || noop_done_w);

always @(posedge clk) begin
    if(!resetn) begin
        pending_valid_r <= 1'b0;
        wait_drop_r <= 1'b0;
        pending_icache_r <= 1'b0;
        pending_dcache_r <= 1'b0;
        pending_l2_r <= 1'b0;
        pending_icache_dispatched_r <= 1'b0;
        pending_dcache_dispatched_r <= 1'b0;
        pending_l2_dispatched_r <= 1'b0;
        pending_icache_done_r <= 1'b0;
        pending_dcache_done_r <= 1'b0;
        pending_l2_done_r <= 1'b0;
        pending_l2_all_ways_r <= 1'b0;
        pending_op_r <= `CACHE_CACOP_MAINT_STORE_TAG;
    end else begin
        if(!cacop_nop) begin
            wait_drop_r <= 1'b0;
        end

        if(fire_w) begin
            pending_valid_r <= 1'b1;
            wait_drop_r <= 1'b1;
            pending_icache_r <= real_req_w && target_icache_w;
            pending_dcache_r <= real_req_w && target_dcache_w;
            pending_l2_r <= real_req_w && direct_l2_maint_w;
            pending_icache_dispatched_r <= 1'b0;
            pending_dcache_dispatched_r <= 1'b0;
            pending_l2_dispatched_r <= 1'b0;
            pending_icache_done_r <= 1'b0;
            pending_dcache_done_r <= 1'b0;
            pending_l2_done_r <= 1'b0;
            pending_l2_all_ways_r <= real_req_w && direct_l2_all_ways_w;
            pending_l2_way_r <= {`L2_WAY_WIDTH{1'b0}};
            pending_op_r <= decoded_op_w;
            pending_way_r <= cacop_va[0];
            pending_index_r <= cacop_va[`CACHE_INDEX_MSB:`CACHE_INDEX_LSB];
            pending_tag_r <= cacop_pa[`CACHE_TAG_MSB:`CACHE_TAG_LSB];

            pending_l2_addr_r <= code_hit_inv_w ? cacop_pa : cacop_va;
        end else if(cacop_data_ok) begin
            pending_valid_r <= 1'b0;
            pending_icache_r <= 1'b0;
            pending_dcache_r <= 1'b0;
            pending_l2_r <= 1'b0;
            pending_icache_dispatched_r <= 1'b0;
            pending_dcache_dispatched_r <= 1'b0;
            pending_l2_dispatched_r <= 1'b0;
            pending_icache_done_r <= 1'b0;
            pending_dcache_done_r <= 1'b0;
            pending_l2_done_r <= 1'b0;
            pending_l2_all_ways_r <= 1'b0;
            pending_l2_way_r <= {`L2_WAY_WIDTH{1'b0}};
        end else if(maint_dispatched_w) begin
            if(i_maint_fire_w) begin
                pending_icache_dispatched_r <= 1'b1;
            end
            if(d_maint_fire_w) begin
                pending_dcache_dispatched_r <= 1'b1;
            end
            if(l2_maint_fire_w) begin
                pending_l2_dispatched_r <= 1'b1;
            end
        end

        if(pending_valid_r && pending_icache_r && i_maint_data_ok) begin
            pending_icache_done_r <= 1'b1;
        end
        if(pending_valid_r && pending_dcache_r && d_maint_data_ok) begin
            pending_dcache_done_r <= 1'b1;
        end
        if(pending_valid_r && pending_l2_r && l2_maint_data_ok) begin
            if(pending_l2_all_ways_r &&
               (pending_l2_way_r != (`L2_WAYS - 1))) begin
                pending_l2_way_r <= pending_l2_way_r + 1'b1;
                pending_l2_dispatched_r <= 1'b0;
            end else begin
                pending_l2_done_r <= 1'b1;
            end
        end
    end
end

endmodule
