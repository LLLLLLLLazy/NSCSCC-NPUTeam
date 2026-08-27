
module privilege_issue_read_reg (
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire [13:0] in_csr_addr,
    input wire        in_csr_we,
    input wire        in_csr_re,
    input wire        in_sel_csr_wmask,


    input wire [4:0] in_invtlb_op,
    input wire       in_is_inst_tlbsrch,
    input wire       in_is_inst_tlbrd,
    input wire       in_is_inst_tlbwr,
    input wire       in_is_inst_tlbfill,
    input wire       in_is_inst_invtlb,

    output reg [13:0] out_csr_addr,
    output reg        out_csr_we,
    output reg        out_csr_re,
    output reg        out_sel_csr_wmask,


    output reg [4:0] out_invtlb_op,
    output reg       out_is_inst_tlbsrch,
    output reg       out_is_inst_tlbrd,
    output reg       out_is_inst_tlbwr,
    output reg       out_is_inst_tlbfill,
    output reg       out_is_inst_invtlb
);


    always @(posedge clk) begin
        if (!stall) begin
            out_csr_addr        <= in_csr_addr;
            out_csr_we          <= in_csr_we;
            out_csr_re          <= in_csr_re;
            out_sel_csr_wmask   <= in_sel_csr_wmask;

            out_invtlb_op       <= in_invtlb_op;
            out_is_inst_tlbsrch <= in_is_inst_tlbsrch;
            out_is_inst_tlbrd   <= in_is_inst_tlbrd;
            out_is_inst_tlbwr   <= in_is_inst_tlbwr;
            out_is_inst_tlbfill <= in_is_inst_tlbfill;
            out_is_inst_invtlb  <= in_is_inst_invtlb;
        end
    end


endmodule
