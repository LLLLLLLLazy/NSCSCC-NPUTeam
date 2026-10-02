`include "header.v"

module mul_reg (
    input wire clk,
    input wire resetn,

    input wire flush,

    input wire                       in_valid,
    input wire [                6:0] in_phy_reg_dst,
    input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
    input wire [                2:0] in_mul_op,
    input wire [                4:0] in_bid,

    input wire [31:0] operand1,
    input wire [31:0] operand2,


    output wire                       out_valid,
    output wire [                6:0] out_phy_reg_dst,
    output wire [`ROB_ID_WIDTH-1 : 0] out_rob_id,
    output wire [                2:0] out_mul_op,
    output wire [                4:0] out_bid,

    output reg [31:0] out_result,

    input wire       predict_flush,
    input wire [4:0] predict_flush_bid,
    input wire [4:0] head_bid

);

    reg  [ `MUL_DELAY - 1 : 0] valid;
    reg  [                6:0] pdest       [`MUL_DELAY - 1 : 0];
    reg  [`ROB_ID_WIDTH-1 : 0] rob_id      [`MUL_DELAY - 1 : 0];
    reg  [                2:0] op          [`MUL_DELAY - 1 : 0];
    reg  [                4:0] bid         [`MUL_DELAY - 1 : 0];

    wire [ `MUL_DELAY - 1 : 0] bid_greater;

    genvar i;


    generate
        for (i = 0; i < `MUL_DELAY; i = i + 1) begin : gen_greater
            circle_comparator u_circle_comparator (
                .head  (head_bid),
                .a     (bid[i]),
                .b     (predict_flush_bid),
                .a_gt_b(bid_greater[i])
            );
        end
    endgenerate

    localparam head_length = $clog2(`MUL_DELAY + 1);
    reg [head_length - 1 : 0] head;

    assign out_valid       = valid[head];
    assign out_phy_reg_dst = pdest[head];
    assign out_rob_id      = rob_id[head];
    assign out_mul_op      = op[head];
    assign out_bid         = bid[head];

    always @(posedge clk) begin
        if (!resetn || flush) head <= {head_length{1'b0}};
        else if (head == `MUL_DELAY - 1) head <= {head_length{1'b0}};
        else head <= head + 1;
    end

    generate
        for (i = 0; i < `MUL_DELAY; i = i + 1) begin : gen_valid
            always @(posedge clk) begin
                if (!resetn || flush) valid[i] <= 1'b0;
                else if (i == head) begin
                    valid[i] <= in_valid;
                end else if (predict_flush && bid_greater[i]) begin
                    valid[i] <= 1'b0;
                end
            end
        end
    endgenerate




    always @(posedge clk) begin
        pdest[head]  <= in_phy_reg_dst;
        rob_id[head] <= in_rob_id;
        op[head]     <= in_mul_op;
        bid[head]    <= in_bid;
    end

    wire [63:0] cpu_signed_multiplier_result;
    wire [63:0] cpu_unsigned_multiplier_result;


    cpu_signed_multiplier u_cpu_signed_multiplier (
        .CLK(clk),                          // input wire CLK
        .A  (operand1),                     // input wire [31 : 0] A
        .B  (operand2),                     // input wire [31 : 0] B
        .P  (cpu_signed_multiplier_result)  // output wire [63 : 0] P
    );

    cpu_unsigned_multiplier u_cpu_unsigned_multiplier (
        .CLK(clk),                            // input wire CLK
        .A  (operand1),                       // input wire [31 : 0] A
        .B  (operand2),                       // input wire [31 : 0] B
        .P  (cpu_unsigned_multiplier_result)  // output wire [63 : 0] P
    );

    always @(*) begin
        case (out_mul_op)
            3'b001:  out_result = cpu_signed_multiplier_result[31:0];
            3'b010:  out_result = cpu_signed_multiplier_result[63:32];
            3'b100:  out_result = cpu_unsigned_multiplier_result[63:32];
            default: out_result = 32'd0;
        endcase
    end


endmodule
