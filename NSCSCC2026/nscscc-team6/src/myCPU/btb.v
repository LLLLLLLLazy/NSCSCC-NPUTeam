module btb #(
    parameter ADDR_WIDTH = 32,
    parameter INDEX_BITS = 6
) (
    input  wire                  clk,
    input  wire                  reset,

    input  wire [ADDR_WIDTH-1:0] pc_query0,
    input  wire [ADDR_WIDTH-1:0] pc_query1,
    input  wire [ADDR_WIDTH-1:0] pc_query2,
    input  wire [ADDR_WIDTH-1:0] pc_query3,
    output wire [3:0]            btb_hit,
    output wire [ADDR_WIDTH-1:0] btb_target0,
    output wire [ADDR_WIDTH-1:0] btb_target1,
    output wire [ADDR_WIDTH-1:0] btb_target2,
    output wire [ADDR_WIDTH-1:0] btb_target3,
    output wire [3:0]            ras_push,
    output wire [3:0]            ras_pop,

    input  wire                  update_en,
    input  wire [ADDR_WIDTH-1:0] pc_update,
    input  wire [ADDR_WIDTH-1:0] target_update,
    input  wire [1:0]            branch_type_update
);

    localparam TYPE_CALL = 2'b01;
    localparam TYPE_RET  = 2'b10;
    localparam ENTRIES   = (1 << INDEX_BITS); //         
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_BITS - 2;

    // =====================  洢   У ÿһ       ·     =====================
    // way 0  洢
    reg [ADDR_WIDTH-1:0] target_mem0      [0:ENTRIES-1];
    reg [TAG_WIDTH-1:0]  tag_mem0         [0:ENTRIES-1];
    reg                  valid_mem0       [0:ENTRIES-1];
    reg [1:0]            branch_type_mem0  [0:ENTRIES-1];
    // way 1  洢
    reg [ADDR_WIDTH-1:0] target_mem1      [0:ENTRIES-1];
    reg [TAG_WIDTH-1:0]  tag_mem1         [0:ENTRIES-1];
    reg                  valid_mem1       [0:ENTRIES-1];
    reg [1:0]            branch_type_mem1 [0:ENTRIES-1];

    // LRU  Ĵ     ÿ  1bit  0:     滻way0  1:     滻way1
    reg lru_bit [0:ENTRIES-1];

    // ===================== PC     index / tag      =====================
    wire [INDEX_BITS-1:0] query_index0 = pc_query0[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] query_index1 = pc_query1[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] query_index2 = pc_query2[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] query_index3 = pc_query3[INDEX_BITS+1:2];
    wire [TAG_WIDTH-1:0] query_tag0 = pc_query0[ADDR_WIDTH-1:INDEX_BITS+2];
    wire [TAG_WIDTH-1:0] query_tag1 = pc_query1[ADDR_WIDTH-1:INDEX_BITS+2];
    wire [TAG_WIDTH-1:0] query_tag2 = pc_query2[ADDR_WIDTH-1:INDEX_BITS+2];
    wire [TAG_WIDTH-1:0] query_tag3 = pc_query3[ADDR_WIDTH-1:INDEX_BITS+2];

    wire [INDEX_BITS-1:0] update_index = pc_update[INDEX_BITS+1:2];
    wire [TAG_WIDTH-1:0]  update_tag   = pc_update[ADDR_WIDTH-1:INDEX_BITS+2];

    // =====================   ·   в ѯ    ·tag ȶԣ  ж      =====================
    // ÿһ·PC  ѯ  ·BTB  
    // hit_way0 / hit_way1    PC    һ·    
    wire hit0_way0 = valid_mem0[query_index0] && (tag_mem0[query_index0] == query_tag0);
    wire hit0_way1 = valid_mem1[query_index0] && (tag_mem1[query_index0] == query_tag0);
    wire hit1_way0 = valid_mem0[query_index1] && (tag_mem0[query_index1] == query_tag1);
    wire hit1_way1 = valid_mem1[query_index1] && (tag_mem1[query_index1] == query_tag1);
    wire hit2_way0 = valid_mem0[query_index2] && (tag_mem0[query_index2] == query_tag2);
    wire hit2_way1 = valid_mem1[query_index2] && (tag_mem1[query_index2] == query_tag2);
    wire hit3_way0 = valid_mem0[query_index3] && (tag_mem0[query_index3] == query_tag3);
    wire hit3_way1 = valid_mem1[query_index3] && (tag_mem1[query_index3] == query_tag3);

    // BTB hit signal (per slot)
    assign btb_hit[0] = hit0_way0 || hit0_way1;
    assign btb_hit[1] = hit1_way0 || hit1_way1;
    assign btb_hit[2] = hit2_way0 || hit2_way1;
    assign btb_hit[3] = hit3_way0 || hit3_way1;

    // ===================== Target address and branch type selection =====================

    assign btb_target0 = btb_hit[0] ? (hit0_way0 ? target_mem0[query_index0] : target_mem1[query_index0]) : pc_query0 + 4;
    assign btb_target1 = btb_hit[1] ? (hit1_way0 ? target_mem0[query_index1] : target_mem1[query_index1]) : pc_query1 + 4;
    assign btb_target2 = btb_hit[2] ? (hit2_way0 ? target_mem0[query_index2] : target_mem1[query_index2]) : pc_query2 + 4;
    assign btb_target3 = btb_hit[3] ? (hit3_way0 ? target_mem0[query_index3] : target_mem1[query_index3]) : pc_query3 + 4;

    // RAS push/pop  ж   call/ret    ȡ      ͨ·  
    assign ras_push[0] = btb_hit[0] && (hit0_way0 ? (branch_type_mem0[query_index0]==TYPE_CALL) : (branch_type_mem1[query_index0]==TYPE_CALL));
    assign ras_push[1] = btb_hit[1] && (hit1_way0 ? (branch_type_mem0[query_index1]==TYPE_CALL) : (branch_type_mem1[query_index1]==TYPE_CALL));
    assign ras_push[2] = btb_hit[2] && (hit2_way0 ? (branch_type_mem0[query_index2]==TYPE_CALL) : (branch_type_mem1[query_index2]==TYPE_CALL));
    assign ras_push[3] = btb_hit[3] && (hit3_way0 ? (branch_type_mem0[query_index3]==TYPE_CALL) : (branch_type_mem1[query_index3]==TYPE_CALL));

    assign ras_pop[0] = btb_hit[0] && (hit0_way0 ? (branch_type_mem0[query_index0]==TYPE_RET) : (branch_type_mem1[query_index0]==TYPE_RET));
    assign ras_pop[1] = btb_hit[1] && (hit1_way0 ? (branch_type_mem0[query_index1]==TYPE_RET) : (branch_type_mem1[query_index1]==TYPE_RET));
    assign ras_pop[2] = btb_hit[2] && (hit2_way0 ? (branch_type_mem0[query_index2]==TYPE_RET) : (branch_type_mem1[query_index2]==TYPE_RET));
    assign ras_pop[3] = btb_hit[3] && (hit3_way0 ? (branch_type_mem0[query_index3]==TYPE_RET) : (branch_type_mem1[query_index3]==TYPE_RET));

    // Check whether either way already has a matching entry
    wire exist_way0 = valid_mem0[update_index] && (tag_mem0[update_index] == update_tag);
    wire exist_way1 = valid_mem1[update_index] && (tag_mem1[update_index] == update_tag);
    // ===================== ʱ   ߼     λ  ѵ     ¡ BTB  Ŀ    +LRU 滻 =====================
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid_mem0[i] <= 1'b0;
                valid_mem1[i] <= 1'b0;
                lru_bit[i]    <= 1'b0;
            end
        end else begin
            // EXE-stage write BTB: allocate new entry or update existing one via LRU
            if (update_en) begin
                if(exist_way0) begin
                    lru_bit[update_index] <= 1'b1;
                end
                else if(exist_way1) begin
                    lru_bit[update_index] <= 1'b0;
                end
                else begin
                    if(lru_bit[update_index] == 1'b0) begin
                        // Replace way0
                        valid_mem0[update_index]       <= 1'b1;
                        tag_mem0[update_index]         <= update_tag;
                        target_mem0[update_index]      <= target_update;
                        branch_type_mem0[update_index] <= branch_type_update;
                        lru_bit[update_index] <= 1'b1;
                    end
                    else begin
                        // Replace way1
                        valid_mem1[update_index]       <= 1'b1;
                        tag_mem1[update_index]         <= update_tag;
                        target_mem1[update_index]      <= target_update;
                        branch_type_mem1[update_index] <= branch_type_update;
                        lru_bit[update_index] <= 1'b0;
                    end
                end
            end
        end
    end

endmodule