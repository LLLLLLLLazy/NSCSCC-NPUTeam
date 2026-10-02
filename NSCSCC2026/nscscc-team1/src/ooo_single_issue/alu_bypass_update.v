module alu_bypass_update (
    input wire [ 6:0] raddr,
    input wire [31:0] rdata,

    input wire        alu_bypass1_valid,
    input wire [ 6:0] alu_bypass1_dst,
    input wire [31:0] alu_bypass1_data,

    input wire        alu_bypass2_valid,
    input wire [ 6:0] alu_bypass2_dst,
    input wire [31:0] alu_bypass2_data,


    input wire        alu_bypass3_valid,
    input wire [ 6:0] alu_bypass3_dst,
    input wire [31:0] alu_bypass3_data,


    input wire        alu_bypass4_valid,
    input wire [ 6:0] alu_bypass4_dst,
    input wire [31:0] alu_bypass4_data,

    output wire [31:0] update_rdata
);


    wire [3:0] hit;

    assign hit[0] = alu_bypass1_valid && alu_bypass1_dst == raddr;
    assign hit[1] = alu_bypass2_valid && alu_bypass2_dst == raddr;
    assign hit[2] = alu_bypass3_valid && alu_bypass3_dst == raddr;
    assign hit[3] = alu_bypass4_valid && alu_bypass4_dst == raddr;


    wire [31:0] bypass_data;

    assign bypass_data = {32{hit[0]}} & alu_bypass1_data |
                     {32{hit[1]}} & alu_bypass2_data |
                     {32{hit[2]}} & alu_bypass3_data |
                     {32{hit[3]}} & alu_bypass4_data ;

    assign update_rdata = (|hit) ? bypass_data : rdata;

endmodule
