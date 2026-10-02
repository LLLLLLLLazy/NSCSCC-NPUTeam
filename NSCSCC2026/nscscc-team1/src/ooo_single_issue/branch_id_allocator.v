module branch_id_allocator (
    input wire clk,
    input wire resetn,

    input  wire [31:0] alloc_pc,
    input  wire [31:0] alloc_target_address,
    input  wire [31:0] alloc_imm,
    input  wire        alloc_bid_valid,
    output wire        alloc_bid_ready,
    output wire [ 4:0] alloc_bid,

    input wire commit_branch_valid,

    input wire       global_flush,
    input wire       predict_flush,
    input wire [4:0] predict_flush_bid,

    output wire [4:0] bid_head,
    output wire [4:0] bid_tail,

    input  wire [ 4:0] lookup_bid,
    output reg  [31:0] lookup_pc,
    output reg  [31:0] lookup_target_address,
    output reg  [31:0] lookup_imm
);

    wire        full;
    reg  [ 4:0] head;
    reg  [ 4:0] tail;

    (* ram_style = "block" *)
    reg  [31:0] pc            [31:0];
    (* ram_style = "block" *)
    reg  [31:0] target_address[31:0];
    (* ram_style = "block" *)
    reg  [31:0] imm           [31:0];


    always @(posedge clk) begin
        lookup_pc             <= pc[lookup_bid];
        lookup_target_address <= target_address[lookup_bid];
        lookup_imm            <= imm[lookup_bid];
    end

    assign bid_head        = head;
    assign bid_tail        = tail;
    assign full            = tail + 5'd1 == head;
    assign alloc_bid_ready = !full;
    assign alloc_bid       = tail;

    always @(posedge clk) begin
        if (!resetn || global_flush) begin
            head <= 5'd0;
        end else if (commit_branch_valid) begin
            head <= head + 5'd1;
        end
    end

    always @(posedge clk) begin
        if (!resetn || global_flush) begin
            tail <= 5'd0;
        end else if (predict_flush) begin
            tail <= predict_flush_bid + 5'd1;
        end else if (alloc_bid_valid && alloc_bid_ready) begin
            tail <= tail + 5'd1;
        end
    end

    always @(posedge clk) begin
        if (alloc_bid_valid && alloc_bid_ready) begin
            pc[tail]             <= alloc_pc;
            target_address[tail] <= alloc_target_address;
            imm[tail]            <= alloc_imm;
        end
    end



endmodule
