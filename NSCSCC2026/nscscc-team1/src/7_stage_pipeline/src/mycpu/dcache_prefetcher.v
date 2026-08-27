module dcache_prefetcher #(
    parameter ENABLE = 1
) (
    input wire clk,
    input wire resetn,

    input wire train_valid,
    input wire [31:0] train_pc,
    input wire [31:0] train_addr,

    input wire demand_miss_valid,
    input wire [31:0] demand_miss_addr,

    output wire prefetch_valid,
    output wire [31:0] prefetch_addr,
    input wire prefetch_ready,
    input wire prefetch_complete
);

localparam ENTRY_COUNT = 16;
localparam [26:0] LAST_LINE = {27{1'b1}};

reg [ENTRY_COUNT-1:0] entry_valid_r;
reg [25:0] pc_tag_r [0:ENTRY_COUNT-1];
reg [26:0] last_line_r [0:ENTRY_COUNT-1];
reg [ENTRY_COUNT-1:0] direction_r;
reg [ENTRY_COUNT-1:0] direction_valid_r;
reg [1:0] confidence_r [0:ENTRY_COUNT-1];

reg pending_valid_r;
reg [26:0] pending_line_r;
reg inflight_valid_r;
reg [26:0] inflight_line_r;

wire [3:0] train_index_w;
wire [25:0] train_tag_w;
wire [26:0] train_line_w;
wire [26:0] demand_miss_line_w;
wire entry_hit_w;
wire same_line_w;
wire plus_one_w;
wire minus_one_w;
wire adjacent_w;
wire observed_direction_w;
wire same_direction_w;
wire prediction_in_range_w;
wire [26:0] predicted_line_w;
wire [31:0] predicted_addr_w;
wire prediction_same_page_w;
wire candidate_valid_w;
wire candidate_duplicate_pending_w;
wire candidate_duplicate_inflight_w;
wire candidate_slot_available_w;
wire cancel_pending_w;
wire prefetch_fire_w;

integer i;

assign train_index_w = train_pc[5:2];
assign train_tag_w = train_pc[31:6];
assign train_line_w = train_addr[31:5];
assign demand_miss_line_w = demand_miss_addr[31:5];

assign entry_hit_w =
    entry_valid_r[train_index_w] &&
    (pc_tag_r[train_index_w] == train_tag_w);
assign same_line_w =
    entry_hit_w &&
    (last_line_r[train_index_w] == train_line_w);
assign plus_one_w =
    entry_hit_w &&
    (last_line_r[train_index_w] != LAST_LINE) &&
    (train_line_w == (last_line_r[train_index_w] + 1'b1));
assign minus_one_w =
    entry_hit_w &&
    (train_line_w != LAST_LINE) &&
    (last_line_r[train_index_w] == (train_line_w + 1'b1));
assign adjacent_w = plus_one_w || minus_one_w;
assign observed_direction_w = plus_one_w;
assign same_direction_w =
    direction_valid_r[train_index_w] &&
    (direction_r[train_index_w] == observed_direction_w);

assign prediction_in_range_w =
    observed_direction_w ? (train_line_w != LAST_LINE) :
                           (train_line_w != 27'b0);
assign predicted_line_w =
    observed_direction_w ? (train_line_w + 1'b1) :
                           (train_line_w - 1'b1);
assign predicted_addr_w = {predicted_line_w, 5'b0};
assign prediction_same_page_w =
    predicted_addr_w[31:12] == train_addr[31:12];

assign candidate_valid_w =
    train_valid &&
    entry_hit_w &&
    !same_line_w &&
    adjacent_w &&
    same_direction_w &&
    (confidence_r[train_index_w] >= 2'd1) &&
    prediction_in_range_w &&
    prediction_same_page_w;

assign candidate_duplicate_pending_w =
    pending_valid_r &&
    (pending_line_r == predicted_line_w);
assign candidate_duplicate_inflight_w =
    inflight_valid_r &&
    (inflight_line_r == predicted_line_w);
assign candidate_slot_available_w =
    !pending_valid_r ||
    prefetch_fire_w ||
    cancel_pending_w;
assign cancel_pending_w =
    demand_miss_valid &&
    pending_valid_r &&
    (pending_line_r == demand_miss_line_w);

assign prefetch_valid =
    ENABLE &&
    pending_valid_r;
assign prefetch_addr = {pending_line_r, 5'b0};
assign prefetch_fire_w = prefetch_valid && prefetch_ready;

always @(posedge clk) begin
    if(!resetn) begin
        entry_valid_r <= {ENTRY_COUNT{1'b0}};
        direction_r <= {ENTRY_COUNT{1'b0}};
        direction_valid_r <= {ENTRY_COUNT{1'b0}};
        pending_valid_r <= 1'b0;
        pending_line_r <= 27'b0;
        inflight_valid_r <= 1'b0;
        inflight_line_r <= 27'b0;
        for(i = 0; i < ENTRY_COUNT; i = i + 1) begin
            pc_tag_r[i] <= 26'b0;
            last_line_r[i] <= 27'b0;
            confidence_r[i] <= 2'b0;
        end
    end else if(!ENABLE) begin
        pending_valid_r <= 1'b0;
        inflight_valid_r <= 1'b0;
    end else begin
        if(train_valid) begin
            if(!entry_hit_w) begin
                entry_valid_r[train_index_w] <= 1'b1;
                pc_tag_r[train_index_w] <= train_tag_w;
                last_line_r[train_index_w] <= train_line_w;
                direction_r[train_index_w] <= 1'b0;
                direction_valid_r[train_index_w] <= 1'b0;
                confidence_r[train_index_w] <= 2'b0;
            end else if(!same_line_w) begin
                last_line_r[train_index_w] <= train_line_w;
                if(!adjacent_w) begin
                    direction_r[train_index_w] <= 1'b0;
                    direction_valid_r[train_index_w] <= 1'b0;
                    confidence_r[train_index_w] <= 2'b0;
                end else if(!same_direction_w) begin
                    direction_r[train_index_w] <= observed_direction_w;
                    direction_valid_r[train_index_w] <= 1'b1;
                    confidence_r[train_index_w] <= 2'd1;
                end else if(confidence_r[train_index_w] != 2'd3) begin
                    confidence_r[train_index_w] <=
                        confidence_r[train_index_w] + 1'b1;
                end
            end
        end

        if(prefetch_complete) begin
            inflight_valid_r <= 1'b0;
        end

        if(cancel_pending_w) begin
            pending_valid_r <= 1'b0;
        end else if(prefetch_fire_w) begin
            pending_valid_r <= 1'b0;
            inflight_valid_r <= 1'b1;
            inflight_line_r <= pending_line_r;
        end

        if(candidate_valid_w &&
           candidate_slot_available_w &&
           !candidate_duplicate_pending_w &&
           !candidate_duplicate_inflight_w) begin
            pending_valid_r <= 1'b1;
            pending_line_r <= predicted_line_w;
        end
    end
end

endmodule
