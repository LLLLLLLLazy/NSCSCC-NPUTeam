`define PHT_LEVEL 8
`define PHT_ENTRIES 256
`define BTB_LEVEL 6
`define BTB_ENTRIES 64

module bp_unit(
    input clk,
    input reset,

    input  [31:0] PIF_pc,
    output        btb_miss,
    output        pred_taken,
    output [31:0] pred_target,

    input taken_update_en,
    input target_update_en,

    input [31:0] ID_pc,
    input        real_taken,
    input [31:0] real_target
);

    integer i;

// PHT

    // PHT index
    wire [`PHT_LEVEL-1 : 0] pht_addr_PIF;
    wire [`PHT_LEVEL-1 : 0] pht_addr_ID;
    // counter  10 11 taken
    reg  [`PHT_ENTRIES - 1 : 0] pht_0;
    reg  [`PHT_ENTRIES - 1 : 0] pht_1;
    wire [1:0] old_pht;
    reg  [1:0] new_pht;

// BTB

    // BTB index
    wire [`BTB_LEVEL-1 : 0] btb_rindex;
    wire [`BTB_LEVEL-1 : 0] btb_windex;
    // counter  10 11 taken
    reg  [31:0] btb [`BTB_ENTRIES - 1 : 0];
    reg   btb_valid [`BTB_ENTRIES - 1 : 0];




// PHT

    assign pht_addr_PIF = PIF_pc[2+`PHT_LEVEL-1 : 2];
    assign pht_addr_ID  = ID_pc [2+`PHT_LEVEL-1 : 2];

    assign pred_taken = pht_1[pht_addr_PIF];

    assign old_pht = {pht_1[pht_addr_ID], pht_0[pht_addr_ID]};
    always@(*) begin
        if(reset) begin
            new_pht = 2'b0;
        end
        else if(taken_update_en) begin
            if(real_taken & old_pht != 2'b11) begin
                new_pht = old_pht + 2'b01;
            end

            if(~real_taken & old_pht != 2'b00) begin
                new_pht = old_pht - 2'b01;
            end
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            pht_0 <= `PHT_ENTRIES'b0;
            pht_1 <= `PHT_ENTRIES'b0;
        end
        else if(taken_update_en) begin
            pht_0[pht_addr_ID] <= new_pht[0];
            pht_1[pht_addr_ID] <= new_pht[1];
        end
    end


//BTB
    assign btb_rindex = PIF_pc[2+`BTB_LEVEL-1:2];
    assign btb_windex = ID_pc [2+`BTB_LEVEL-1:2];

    assign btb_miss = ~btb_valid[btb_rindex];
    assign pred_target = btb[btb_rindex];

    // valid
    always@(posedge clk) begin
        if(reset) begin
            for(i = 0; i < `BTB_ENTRIES; i = i + 1) begin
                btb_valid[i] <= 1'b0;
            end
        end
        else if(target_update_en) begin
            btb_valid[btb_windex] <= 1'b1;
        end
    end

    //btb
    always@(posedge clk) begin
        if(reset) begin
            for(i = 0; i < `BTB_ENTRIES; i = i + 1) begin
                btb[i] <= 32'b0;
            end
        end
        else if(target_update_en) begin
            btb[btb_windex] <= real_target;
        end
    end


endmodule