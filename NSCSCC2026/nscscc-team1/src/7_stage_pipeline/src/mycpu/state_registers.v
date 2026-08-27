module pc_state(
    input wire clk,
    input wire resetn,
    input wire stall,


    input wire in_is_exception,
    input wire in_is_adef,

    output reg out_is_exception,
    output reg out_is_adef
);

always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_adef <= 1'b0;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_adef <= in_is_adef;
    end
end

endmodule


module if1_if2_state(
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire in_is_exception,
    input wire in_is_adef,

    input wire in_is_tlbr,
    input wire in_is_inst_tlbr,
    input wire in_is_inst_pif,
    input wire in_is_inst_ppi,
    
    input wire [1:0] in_mmu_inst_mat,

    output reg out_is_exception,
    output reg out_is_adef,

    output reg out_is_tlbr,
    output reg out_is_inst_tlbr,
    output reg out_is_inst_pif,
    output reg out_is_inst_ppi,
    output reg [1:0] out_mmu_inst_mat
);

always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_adef <= 1'b0;
        out_is_tlbr <= 1'b0;
        out_is_inst_tlbr <= 1'b0;
        out_is_inst_pif <= 1'b0;
        out_is_inst_ppi <= 1'b0;
        out_mmu_inst_mat <= 2'b00;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_adef <= in_is_adef;
        out_is_tlbr <= in_is_tlbr;
        out_is_inst_tlbr <= in_is_inst_tlbr;
        out_is_inst_pif <= in_is_inst_pif;
        out_is_inst_ppi <= in_is_inst_ppi;
        out_mmu_inst_mat <= in_mmu_inst_mat;
    end
end

endmodule

module if2_id_state(
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire in_is_exception,
    input wire in_is_adef,

    input wire in_is_tlbr,
    input wire in_is_inst_tlbr,
    input wire in_is_inst_pif,
    input wire in_is_inst_ppi,

    output reg out_is_exception,
    output reg out_is_adef,

    output reg out_is_tlbr,
    output reg out_is_inst_tlbr,
    output reg out_is_inst_pif,
    output reg out_is_inst_ppi
);

always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_adef <= 1'b0;
        out_is_tlbr <= 1'b0;
        out_is_inst_tlbr <= 1'b0;
        out_is_inst_pif <= 1'b0;
        out_is_inst_ppi <= 1'b0;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_adef <= in_is_adef;
        out_is_tlbr <= in_is_tlbr;
        out_is_inst_tlbr <= in_is_inst_tlbr;
        out_is_inst_pif <= in_is_inst_pif;
        out_is_inst_ppi <= in_is_inst_ppi;
    end
end

endmodule




module id_exe_state(
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire in_is_exception,
    input wire in_is_sys,
    input wire in_is_int,
    input wire in_ertn_flush,
    input wire [13:0] in_csr_addr,
    input wire in_csr_we,
    input wire in_csr_re,

    input wire in_is_adef,
    input wire in_is_ine,
    input wire in_is_brk,

    input wire in_tlb_we,
    input wire [4:0] in_invtlb_op,
    input wire in_is_inst_tlbsrch,
    input wire in_is_inst_tlbrd,
    input wire in_is_inst_tlbwr,
    input wire in_is_inst_tlbfill,
    input wire in_is_inst_invtlb,

    input wire in_is_tlbr,
    input wire in_is_inst_tlbr,
    input wire in_is_inst_pif,
    input wire in_is_inst_ppi,

    output reg out_is_exception,
    output reg out_is_sys,
    output reg out_is_int,
    output reg out_ertn_flush,
    output reg [13:0] out_csr_addr,
    output reg out_csr_we,
    output reg out_csr_re,

    output reg out_is_adef,
    output reg out_is_ine,
    output reg out_is_brk,

    output reg out_tlb_we,
    output reg [4:0] out_invtlb_op,
    output reg out_is_inst_tlbsrch,
    output reg out_is_inst_tlbrd,
    output reg out_is_inst_tlbwr,
    output reg out_is_inst_tlbfill,
    output reg out_is_inst_invtlb,

    output reg out_is_tlbr,
    output reg out_is_inst_tlbr,
    output reg out_is_inst_pif,
    output reg out_is_inst_ppi
);


always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_sys <= 1'b0;
        out_is_int <= 1'b0;
        out_ertn_flush <= 1'b0;
        out_csr_addr <= 14'd0;
        out_csr_we <= 1'b0;
        out_csr_re <= 1'b0;
        out_is_adef <= 1'b0;
        out_is_ine <= 1'b0;
        out_is_brk <= 1'b0;

        out_tlb_we <= 1'b0;
        out_invtlb_op <= 5'b0;
        out_is_inst_tlbsrch <= 1'b0;
        out_is_inst_tlbrd <= 1'b0;
        out_is_inst_tlbwr <= 1'b0;
        out_is_inst_tlbfill <= 1'b0;
        out_is_inst_invtlb <= 1'b0;

        out_is_tlbr <= 1'b0;
        out_is_inst_tlbr <= 1'b0;
        out_is_inst_pif <= 1'b0;
        out_is_inst_ppi <= 1'b0;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_sys <= in_is_sys;
        out_is_int <= in_is_int;
        out_ertn_flush <= in_ertn_flush;
        out_csr_addr <= in_csr_addr;
        out_csr_we <= in_csr_we;
        out_csr_re <= in_csr_re;
        out_is_adef <= in_is_adef;
        out_is_ine <= in_is_ine;
        out_is_brk <= in_is_brk;

        out_tlb_we <= in_tlb_we;
        out_invtlb_op <= in_invtlb_op;
        out_is_inst_tlbsrch <= in_is_inst_tlbsrch;
        out_is_inst_tlbrd <= in_is_inst_tlbrd;
        out_is_inst_tlbwr <= in_is_inst_tlbwr;
        out_is_inst_tlbfill <= in_is_inst_tlbfill;
        out_is_inst_invtlb <= in_is_inst_invtlb;
        
        out_is_tlbr <= in_is_tlbr;
        out_is_inst_tlbr <= in_is_inst_tlbr;
        out_is_inst_pif <= in_is_inst_pif;
        out_is_inst_ppi <= in_is_inst_ppi;
    end
end


endmodule


module exe_mem1_state(
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire in_is_exception,
    input wire in_is_sys,
    input wire in_is_int,
    input wire in_ertn_flush,
    input wire [13:0] in_csr_addr,
    input wire in_csr_we,
    input wire in_csr_re,

    input wire in_is_adef,
    input wire in_is_ine,
    input wire in_is_brk,
    input wire in_is_ale,

    input wire in_tlb_we,
    input wire [4:0] in_invtlb_op,
    input wire in_is_inst_tlbsrch,
    input wire in_is_inst_tlbrd,
    input wire in_is_inst_tlbwr,
    input wire in_is_inst_tlbfill,
    input wire in_is_inst_invtlb,

    input wire in_is_tlbr,
    input wire in_is_inst_tlbr,
    input wire in_is_inst_pif,
    input wire in_is_inst_ppi,

    output reg out_is_exception,
    output reg out_is_sys,
    output reg out_is_int,
    output reg out_ertn_flush,
    output reg [13:0] out_csr_addr,
    output reg out_csr_we,
    output reg out_csr_re,
    
    output reg out_is_adef,
    output reg out_is_ine,
    output reg out_is_brk,
    output reg out_is_ale,

    output reg out_tlb_we,
    output reg [4:0] out_invtlb_op,
    output reg out_is_inst_tlbsrch,
    output reg out_is_inst_tlbrd,
    output reg out_is_inst_tlbwr,
    output reg out_is_inst_tlbfill,
    output reg out_is_inst_invtlb,

    output reg out_is_tlbr,
    output reg out_is_inst_tlbr,
    output reg out_is_inst_pif,
    output reg out_is_inst_ppi
);

always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_sys <= 1'b0;
        out_is_int <= 1'b0;
        out_ertn_flush <= 1'b0;
        out_csr_addr <= 14'd0;
        out_csr_we <= 1'b0;
        out_csr_re <= 1'b0;
        out_is_adef <= 1'b0;
        out_is_ine <= 1'b0;
        out_is_brk <= 1'b0;
        out_is_ale <= 1'b0;

        out_tlb_we <= 1'b0;
        out_invtlb_op <= 5'b0;
        out_is_inst_tlbsrch <= 1'b0;
        out_is_inst_tlbrd <= 1'b0;
        out_is_inst_tlbwr <= 1'b0;
        out_is_inst_tlbfill <= 1'b0;
        out_is_inst_invtlb <= 1'b0;
        
        out_is_tlbr <= 1'b0;
        out_is_inst_tlbr <= 1'b0;
        out_is_inst_pif <= 1'b0;
        out_is_inst_ppi <= 1'b0;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_sys <= in_is_sys;
        out_is_int <= in_is_int;
        out_ertn_flush <= in_ertn_flush;
        out_csr_addr <= in_csr_addr;
        out_csr_we <= in_csr_we;
        out_csr_re <= in_csr_re;
        out_is_adef <= in_is_adef;
        out_is_ine <= in_is_ine;
        out_is_brk <= in_is_brk;
        out_is_ale <= in_is_ale;

        out_tlb_we <= in_tlb_we;
        out_invtlb_op <= in_invtlb_op;
        out_is_inst_tlbsrch <= in_is_inst_tlbsrch;
        out_is_inst_tlbrd <= in_is_inst_tlbrd;
        out_is_inst_tlbwr <= in_is_inst_tlbwr;
        out_is_inst_tlbfill <= in_is_inst_tlbfill;
        out_is_inst_invtlb <= in_is_inst_invtlb;
        
        out_is_tlbr <= in_is_tlbr;
        out_is_inst_tlbr <= in_is_inst_tlbr;
        out_is_inst_pif <= in_is_inst_pif;
        out_is_inst_ppi <= in_is_inst_ppi;
    end
end

endmodule

module mem1_mem2_state(
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire in_is_exception,
    input wire in_is_sys,
    input wire in_is_int,
    input wire in_ertn_flush,
    input wire [13:0] in_csr_addr,
    input wire in_csr_we,
    input wire in_csr_re,

    input wire in_is_adef,
    input wire in_is_ine,
    input wire in_is_brk,
    input wire in_is_ale,

    input wire in_tlb_we,
    input wire [4:0] in_invtlb_op,
    input wire in_is_inst_tlbsrch,
    input wire in_is_inst_tlbrd,
    input wire in_is_inst_tlbwr,
    input wire in_is_inst_tlbfill,
    input wire in_is_inst_invtlb,

    input wire in_tlbsrch_hit,
    input wire in_tlbrd_hit,
    input wire [31:0] in_tlb_w_csr_tlbelo0,
    input wire [31:0] in_tlb_w_csr_tlbelo1,
    input wire [31:0] in_tlb_w_csr_tlbidx,
    input wire [31:0] in_tlb_w_csr_tlbehi,
    input wire [31:0] in_tlb_w_csr_asid,
    
    input wire in_is_tlbr,
    input wire in_is_inst_tlbr,
    input wire in_is_inst_pif,
    input wire in_is_inst_ppi,
    input wire in_is_data_tlbr,
    input wire in_is_data_pil,
    input wire in_is_data_pis,
    input wire in_is_data_ppi,
    input wire in_is_data_pme,

    input wire [1:0] in_mmu_data_mat,

    output reg out_is_exception,
    output reg out_is_sys,
    output reg out_is_int,
    output reg out_ertn_flush,
    output reg [13:0] out_csr_addr,
    output reg out_csr_we,
    output reg out_csr_re,

    output reg out_is_adef,
    output reg out_is_ine,
    output reg out_is_brk,
    output reg out_is_ale,

    output reg out_tlb_we,
    output reg [4:0] out_invtlb_op,
    output reg out_is_inst_tlbsrch,
    output reg out_is_inst_tlbrd,
    output reg out_is_inst_tlbwr,
    output reg out_is_inst_tlbfill,
    output reg out_is_inst_invtlb,

    output reg out_tlbsrch_hit,
    output reg out_tlbrd_hit,
    output reg [31:0] out_tlb_w_csr_tlbelo0,
    output reg [31:0] out_tlb_w_csr_tlbelo1,
    output reg [31:0] out_tlb_w_csr_tlbidx,
    output reg [31:0] out_tlb_w_csr_tlbehi,
    output reg [31:0] out_tlb_w_csr_asid,

    output reg out_is_tlbr,
    output reg out_is_inst_tlbr,
    output reg out_is_inst_pif,
    output reg out_is_inst_ppi,
    output reg out_is_data_tlbr,
    output reg out_is_data_pil,
    output reg out_is_data_pis,
    output reg out_is_data_ppi,
    output reg out_is_data_pme,

    output reg [1:0] out_mmu_data_mat
);

always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_sys <= 1'b0;
        out_is_int <= 1'b0;
        out_ertn_flush <= 1'b0;
        out_csr_addr <= 14'd0;
        out_csr_we <= 1'b0;
        out_csr_re <= 1'b0;
        out_is_adef <= 1'b0;
        out_is_ine <= 1'b0;
        out_is_brk <= 1'b0;
        out_is_ale <= 1'b0;

        out_tlb_we <= 1'b0;
        out_invtlb_op <= 5'b0;
        out_is_inst_tlbsrch <= 1'b0;
        out_is_inst_tlbrd <= 1'b0;
        out_is_inst_tlbwr <= 1'b0;
        out_is_inst_tlbfill <= 1'b0;
        out_is_inst_invtlb <= 1'b0;

        out_tlbsrch_hit <= 1'b0;
        out_tlbrd_hit <= 1'b0;
        out_tlb_w_csr_tlbelo0 <= 32'b0;
        out_tlb_w_csr_tlbelo1 <= 32'b0;
        out_tlb_w_csr_tlbidx <= 32'b0;
        out_tlb_w_csr_tlbehi <= 32'b0;
        out_tlb_w_csr_asid <= 32'b0;

        out_is_tlbr <= 1'b0;
        out_is_inst_tlbr <= 1'b0;
        out_is_inst_pif <= 1'b0;
        out_is_inst_ppi <= 1'b0;
        out_is_data_tlbr <= 1'b0;
        out_is_data_pil <= 1'b0;
        out_is_data_pis <= 1'b0;
        out_is_data_ppi <= 1'b0;
        out_is_data_pme <= 1'b0;

        out_mmu_data_mat <= 2'b00;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_sys <= in_is_sys;
        out_is_int <= in_is_int;
        out_ertn_flush <= in_ertn_flush;
        out_csr_addr <= in_csr_addr;
        out_csr_we <= in_csr_we;
        out_csr_re <= in_csr_re;
        out_is_adef <= in_is_adef;
        out_is_ine <= in_is_ine;
        out_is_brk <= in_is_brk;
        out_is_ale <= in_is_ale;
        
        out_tlb_we <= in_tlb_we;
        out_invtlb_op <= in_invtlb_op;
        out_is_inst_tlbsrch <= in_is_inst_tlbsrch;
        out_is_inst_tlbrd <= in_is_inst_tlbrd;
        out_is_inst_tlbwr <= in_is_inst_tlbwr;
        out_is_inst_tlbfill <= in_is_inst_tlbfill;
        out_is_inst_invtlb <= in_is_inst_invtlb;

        out_tlbsrch_hit <= in_tlbsrch_hit;
        out_tlbrd_hit <= in_tlbrd_hit;
        out_tlb_w_csr_tlbelo0 <= in_tlb_w_csr_tlbelo0;
        out_tlb_w_csr_tlbelo1 <= in_tlb_w_csr_tlbelo1;
        out_tlb_w_csr_tlbidx <= in_tlb_w_csr_tlbidx;
        out_tlb_w_csr_tlbehi <= in_tlb_w_csr_tlbehi;
        out_tlb_w_csr_asid <= in_tlb_w_csr_asid;

        out_is_tlbr <= in_is_tlbr;
        out_is_inst_tlbr <= in_is_inst_tlbr;
        out_is_inst_pif <= in_is_inst_pif;
        out_is_inst_ppi <= in_is_inst_ppi;
        out_is_data_tlbr <= in_is_data_tlbr;
        out_is_data_pil <= in_is_data_pil;
        out_is_data_pis <= in_is_data_pis;
        out_is_data_ppi <= in_is_data_ppi;
        out_is_data_pme <= in_is_data_pme;

        out_mmu_data_mat <= in_mmu_data_mat;
    end
end



endmodule

module mem2_wb_state(
    input wire clk,
    input wire resetn,
    input wire stall,

    input wire in_is_exception,
    input wire in_is_sys,
    input wire in_is_int,
    input wire in_ertn_flush,
    input wire [13:0] in_csr_addr,
    input wire in_csr_we,
    input wire in_csr_re,

    input wire in_is_adef,
    input wire in_is_ine,
    input wire in_is_brk,
    input wire in_is_ale,

    input wire in_tlb_we,
    input wire [4:0] in_invtlb_op,
    input wire in_is_inst_tlbsrch,
    input wire in_is_inst_tlbrd,
    input wire in_is_inst_tlbwr,
    input wire in_is_inst_tlbfill,
    input wire in_is_inst_invtlb,

    input wire in_tlbsrch_hit,
    input wire in_tlbrd_hit,
    input wire [31:0] in_tlb_w_csr_tlbelo0,
    input wire [31:0] in_tlb_w_csr_tlbelo1,
    input wire [31:0] in_tlb_w_csr_tlbidx,
    input wire [31:0] in_tlb_w_csr_tlbehi,
    input wire [31:0] in_tlb_w_csr_asid,
    
    input wire in_is_tlbr,
    input wire in_is_inst_tlbr,
    input wire in_is_inst_pif,
    input wire in_is_inst_ppi,
    input wire in_is_data_tlbr,
    input wire in_is_data_pil,
    input wire in_is_data_pis,
    input wire in_is_data_ppi,
    input wire in_is_data_pme,

    output reg out_is_exception,
    output reg out_is_sys,
    output reg out_is_int,
    output reg out_ertn_flush,
    output reg [13:0] out_csr_addr,
    output reg out_csr_we,
    output reg out_csr_re,

    output reg out_is_adef,
    output reg out_is_ine,
    output reg out_is_brk,
    output reg out_is_ale,

    output reg out_tlb_we,
    output reg [4:0] out_invtlb_op,
    output reg out_is_inst_tlbsrch,
    output reg out_is_inst_tlbrd,
    output reg out_is_inst_tlbwr,
    output reg out_is_inst_tlbfill,
    output reg out_is_inst_invtlb,

    output reg out_tlbsrch_hit,
    output reg out_tlbrd_hit,
    output reg [31:0] out_tlb_w_csr_tlbelo0,
    output reg [31:0] out_tlb_w_csr_tlbelo1,
    output reg [31:0] out_tlb_w_csr_tlbidx,
    output reg [31:0] out_tlb_w_csr_tlbehi,
    output reg [31:0] out_tlb_w_csr_asid,

    output reg out_is_tlbr,
    output reg out_is_inst_tlbr,
    output reg out_is_inst_pif,
    output reg out_is_inst_ppi,
    output reg out_is_data_tlbr,
    output reg out_is_data_pil,
    output reg out_is_data_pis,
    output reg out_is_data_ppi,
    output reg out_is_data_pme
);

always @(posedge clk) begin
    if(!resetn)
    begin
        out_is_exception <= 1'b0;
        out_is_sys <= 1'b0;
        out_is_int <= 1'b0;
        out_ertn_flush <= 1'b0;
        out_csr_addr <= 14'd0;
        out_csr_we <= 1'b0;
        out_csr_re <= 1'b0;
        out_is_adef <= 1'b0;
        out_is_ine <= 1'b0;
        out_is_brk <= 1'b0;
        out_is_ale <= 1'b0;

        out_tlb_we <= 1'b0;
        out_invtlb_op <= 5'b0;
        out_is_inst_tlbsrch <= 1'b0;
        out_is_inst_tlbrd <= 1'b0;
        out_is_inst_tlbwr <= 1'b0;
        out_is_inst_tlbfill <= 1'b0;
        out_is_inst_invtlb <= 1'b0;

        out_tlbsrch_hit <= 1'b0;
        out_tlbrd_hit <= 1'b0;
        out_tlb_w_csr_tlbelo0 <= 32'b0;
        out_tlb_w_csr_tlbelo1 <= 32'b0;
        out_tlb_w_csr_tlbidx <= 32'b0;
        out_tlb_w_csr_tlbehi <= 32'b0;
        out_tlb_w_csr_asid <= 32'b0;
        
        out_is_tlbr <= 1'b0;
        out_is_inst_tlbr <= 1'b0;
        out_is_inst_pif <= 1'b0;
        out_is_inst_ppi <= 1'b0;
        out_is_data_tlbr <= 1'b0;
        out_is_data_pil <= 1'b0;
        out_is_data_pis <= 1'b0;
        out_is_data_ppi <= 1'b0;
        out_is_data_pme <= 1'b0;
    end
    else if(!stall)
    begin
        out_is_exception <= in_is_exception;
        out_is_sys <= in_is_sys;
        out_is_int <= in_is_int;
        out_ertn_flush <= in_ertn_flush;
        out_csr_addr <= in_csr_addr;
        out_csr_we <= in_csr_we;
        out_csr_re <= in_csr_re;
        out_is_adef <= in_is_adef;
        out_is_ine <= in_is_ine;
        out_is_brk <= in_is_brk;
        out_is_ale <= in_is_ale;

        out_tlb_we <= in_tlb_we;
        out_invtlb_op <= in_invtlb_op;
        out_is_inst_tlbsrch <= in_is_inst_tlbsrch;
        out_is_inst_tlbrd <= in_is_inst_tlbrd;
        out_is_inst_tlbwr <= in_is_inst_tlbwr;
        out_is_inst_tlbfill <= in_is_inst_tlbfill;
        out_is_inst_invtlb <= in_is_inst_invtlb;

        out_tlbsrch_hit <= in_tlbsrch_hit;
        out_tlbrd_hit <= in_tlbrd_hit;
        out_tlb_w_csr_tlbelo0 <= in_tlb_w_csr_tlbelo0;
        out_tlb_w_csr_tlbelo1 <= in_tlb_w_csr_tlbelo1;
        out_tlb_w_csr_tlbidx <= in_tlb_w_csr_tlbidx;
        out_tlb_w_csr_tlbehi <= in_tlb_w_csr_tlbehi;
        out_tlb_w_csr_asid <= in_tlb_w_csr_asid;
        
        out_is_tlbr <= in_is_tlbr;
        out_is_inst_tlbr <= in_is_inst_tlbr;
        out_is_inst_pif <= in_is_inst_pif;
        out_is_inst_ppi <= in_is_inst_ppi;
        out_is_data_tlbr <= in_is_data_tlbr;
        out_is_data_pil <= in_is_data_pil;
        out_is_data_pis <= in_is_data_pis;
        out_is_data_ppi <= in_is_data_ppi;
        out_is_data_pme <= in_is_data_pme;
    end
end



endmodule