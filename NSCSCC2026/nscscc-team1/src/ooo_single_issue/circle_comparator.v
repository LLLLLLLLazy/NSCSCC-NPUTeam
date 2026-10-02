module circle_comparator #(
    parameter WIDTH = 5
) (
    input wire [WIDTH - 1:0] head,
    input wire [WIDTH - 1:0] a,
    input wire [WIDTH - 1:0] b,

    output wire a_gt_b
);

    wire a_ge_head;
    wire b_ge_head;

    assign a_ge_head = a >= head;
    assign b_ge_head = b >= head;

    assign a_gt_b = (a_ge_head && b_ge_head && a>b) || (!a_ge_head && b_ge_head) || (!a_ge_head && !b_ge_head && a>b);

    // assign a_gt_b = (a-head) > (b-head); 
endmodule
