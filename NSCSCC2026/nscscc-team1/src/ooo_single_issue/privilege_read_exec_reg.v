
module privilege_read_exec_reg (
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire [13:0] in_csr_addr,
    input wire        in_csr_we,
    input wire        in_csr_re,
    input wire        in_sel_csr_wmask,
    input wire [31:0] in_csr_rdata,

    input wire [4:0] in_invtlb_op,
    input wire       in_is_inst_tlbsrch,
    input wire       in_is_inst_tlbrd,
    input wire       in_is_inst_tlbwr,
    input wire       in_is_inst_tlbfill,
    input wire       in_is_inst_invtlb,

    input wire        in_tlbsrch_hit,
    input wire        in_tlbrd_hit,
    input wire [31:0] in_tlb_w_csr_tlbelo0,
    input wire [31:0] in_tlb_w_csr_tlbelo1,
    input wire [31:0] in_tlb_w_csr_tlbidx,
    input wire [31:0] in_tlb_w_csr_tlbehi,
    input wire [31:0] in_tlb_w_csr_asid,

    output reg [13:0] out_csr_addr,
    output reg        out_csr_we,
    output reg        out_csr_re,
    output reg        out_sel_csr_wmask,
    output reg [31:0] out_csr_rdata,


    output reg [4:0] out_invtlb_op,
    output reg       out_is_inst_tlbsrch,
    output reg       out_is_inst_tlbrd,
    output reg       out_is_inst_tlbwr,
    output reg       out_is_inst_tlbfill,
    output reg       out_is_inst_invtlb,


    output reg        out_tlbsrch_hit,
    output reg        out_tlbrd_hit,
    output reg [31:0] out_tlb_w_csr_tlbelo0,
    output reg [31:0] out_tlb_w_csr_tlbelo1,
    output reg [31:0] out_tlb_w_csr_tlbidx,
    output reg [31:0] out_tlb_w_csr_tlbehi,
    output reg [31:0] out_tlb_w_csr_asid
);


    always @(posedge clk) begin
        if (!stall) begin
            out_csr_addr          <= in_csr_addr;
            out_csr_we            <= in_csr_we;
            out_csr_re            <= in_csr_re;
            out_sel_csr_wmask     <= in_sel_csr_wmask;
            out_csr_rdata         <= in_csr_rdata;

            out_invtlb_op         <= in_invtlb_op;
            out_is_inst_tlbsrch   <= in_is_inst_tlbsrch;
            out_is_inst_tlbrd     <= in_is_inst_tlbrd;
            out_is_inst_tlbwr     <= in_is_inst_tlbwr;
            out_is_inst_tlbfill   <= in_is_inst_tlbfill;
            out_is_inst_invtlb    <= in_is_inst_invtlb;


            out_tlbsrch_hit       <= in_tlbsrch_hit;
            out_tlbrd_hit         <= in_tlbrd_hit;
            out_tlb_w_csr_tlbelo0 <= in_tlb_w_csr_tlbelo0;
            out_tlb_w_csr_tlbelo1 <= in_tlb_w_csr_tlbelo1;
            out_tlb_w_csr_tlbidx  <= in_tlb_w_csr_tlbidx;
            out_tlb_w_csr_tlbehi  <= in_tlb_w_csr_tlbehi;
            out_tlb_w_csr_asid    <= in_tlb_w_csr_asid;
        end
    end


endmodule
