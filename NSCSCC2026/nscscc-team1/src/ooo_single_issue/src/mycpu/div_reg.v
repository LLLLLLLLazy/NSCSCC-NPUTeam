`include "header.v"

module div_reg (
    input wire clk,
    input wire resetn,

    input wire flush,

    input wire                       in_valid,
    input wire [                6:0] in_phy_reg_dst,
    input wire [`ROB_ID_WIDTH-1 : 0] in_rob_id,
    input wire [                3:0] in_div_op,
    input wire [                4:0] in_bid,

    input wire [31:0] operand1,
    input wire [31:0] operand2,

    output wire                       out_valid,
    output wire [                6:0] out_phy_reg_dst,
    output wire [`ROB_ID_WIDTH-1 : 0] out_rob_id,
    output wire [                3:0] out_div_op,
    output wire [                4:0] out_bid,

    output reg [31:0] out_result,


    input wire       predict_flush,
    input wire [4:0] predict_flush_bid,
    input wire [4:0] head_bid

);

    reg  [ `DIV_DELAY - 1 : 0] valid;
    reg  [                6:0] pdest       [`DIV_DELAY - 1 : 0];
    reg  [`ROB_ID_WIDTH-1 : 0] rob_id      [`DIV_DELAY - 1 : 0];
    reg  [                3:0] op          [`DIV_DELAY - 1 : 0];
    reg  [                4:0] bid         [`DIV_DELAY - 1 : 0];


    wire [ `DIV_DELAY - 1 : 0] bid_greater;

    genvar i;


    generate
        for (i = 0; i < `DIV_DELAY; i = i + 1) begin : gen_greater
            circle_comparator u_circle_comparator (
                .head  (head_bid),
                .a     (bid[i]),
                .b     (predict_flush_bid),
                .a_gt_b(bid_greater[i])
            );
        end
    endgenerate

    localparam head_length = $clog2(`DIV_DELAY + 1);
    reg [head_length - 1 : 0] head;

    assign out_valid       = valid[head];
    assign out_phy_reg_dst = pdest[head];
    assign out_rob_id      = rob_id[head];
    assign out_div_op      = op[head];
    assign out_bid         = bid[head];

    always @(posedge clk) begin
        if (!resetn || flush) head <= {head_length{1'b0}};
        else if (head == `DIV_DELAY - 1) head <= {head_length{1'b0}};
        else head <= head + 1;
    end

    generate
        for (i = 0; i < `DIV_DELAY; i = i + 1) begin : gen_valid
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
        op[head]     <= in_div_op;
        bid[head]    <= in_bid;
    end

    wire [63:0] cpu_signed_divider_result;
    wire        cpu_signed_divider_result_valid;
    wire [63:0] cpu_unsigned_divider_result;
    wire        cpu_unsigned_divider_result_valid;

    cpu_signed_divider u_cpu_signed_divider (
        .aclk(clk),  // input wire aclk
        .s_axis_divisor_tvalid(1'b1),  // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(operand2),  // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(operand1),  // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(cpu_signed_divider_result_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(cpu_signed_divider_result)  // output wire [63 : 0] m_axis_dout_tdata
    );

    cpu_unsigned_divider u_cpu_unsigned_divider (
        .aclk(clk),  // input wire aclk
        .s_axis_divisor_tvalid(1'b1),  // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(operand2),  // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(operand1),  // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(cpu_unsigned_divider_result_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(cpu_unsigned_divider_result)  // output wire [63 : 0] m_axis_dout_tdata
    );


    always @(*) begin
        case (out_div_op)
            4'b0001: out_result = cpu_signed_divider_result[63:32];
            4'b0010: out_result = cpu_signed_divider_result[31:0];
            4'b0100: out_result = cpu_unsigned_divider_result[63:32];
            4'b1000: out_result = cpu_unsigned_divider_result[31:0];
            default: out_result = 32'd0;
        endcase
    end


endmodule
