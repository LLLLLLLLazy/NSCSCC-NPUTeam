module bypass_update(
        input wire [6:0] phy_src,
        input wire [31:0] phy_data,

        input wire                 bypass1_valid,
        input wire [6:0]           bypass1_dst,
        input wire [31:0]          bypass1_data,
        input wire                 bypass2_valid,
        input wire [6:0]           bypass2_dst,
        input wire [31:0]          bypass2_data,
        input wire                 bypass3_valid,
        input wire [6:0]           bypass3_dst,
        input wire [31:0]          bypass3_data,
        input wire                 bypass4_valid,
        input wire [6:0]           bypass4_dst,
        input wire [31:0]          bypass4_data,
        input wire                 bypass5_valid,
        input wire [6:0]           bypass5_dst,
        input wire [31:0]          bypass5_data,
        input wire                 bypass6_valid,
        input wire [6:0]           bypass6_dst,
        input wire [31:0]          bypass6_data,
        input wire                 bypass7_valid,
        input wire [6:0]           bypass7_dst,
        input wire [31:0]          bypass7_data,

        output wire [31:0] bypass_update_data
    );


    wire [7:1] hit;

    assign hit[1] = bypass1_valid && bypass1_dst == phy_src;
    assign hit[2] = bypass2_valid && bypass2_dst == phy_src;
    assign hit[3] = bypass3_valid && bypass3_dst == phy_src;
    assign hit[4] = bypass4_valid && bypass4_dst == phy_src;
    assign hit[5] = bypass5_valid && bypass5_dst == phy_src;
    assign hit[6] = bypass6_valid && bypass6_dst == phy_src;
    assign hit[7] = bypass7_valid && bypass7_dst == phy_src;

    wire [31:0] hit_data;

    assign hit_data = {32{hit[1]}} & bypass1_data |
           {32{hit[2]}} & bypass2_data |
           {32{hit[3]}} & bypass3_data |
           {32{hit[4]}} & bypass4_data |
           {32{hit[5]}} & bypass5_data |
           {32{hit[6]}} & bypass6_data |
           {32{hit[7]}} & bypass7_data;


    assign bypass_update_data = (|hit) && phy_src != 7'd0 ? hit_data : phy_data;


endmodule
