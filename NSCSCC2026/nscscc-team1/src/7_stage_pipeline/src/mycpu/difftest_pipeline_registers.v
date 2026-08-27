`ifdef difftest



module difftest_id_exe_reg (
    input clk,
    input resetn,

    input stall,

    input        in_csr_3w,
    input        in_is_CNTinst,
    input [ 7:0] in_load_valid,
    input [ 7:0] in_store_valid,
    input [63:0] in_timer_64_value,

    output reg        out_csr_3w,
    output reg        out_is_CNTinst,
    output reg [ 7:0] out_load_valid,
    output reg [ 7:0] out_store_valid,
    output reg [63:0] out_timer_64_value
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_csr_3w         <= 1'b0;
            out_is_CNTinst     <= 1'b0;
            out_load_valid     <= 8'b0;
            out_store_valid    <= 8'b0;
            out_timer_64_value <= 64'b0;
        end else if (!stall) begin
            out_csr_3w         <= in_csr_3w;
            out_is_CNTinst     <= in_is_CNTinst;
            out_load_valid     <= in_load_valid;
            out_store_valid    <= in_store_valid;
            out_timer_64_value <= in_timer_64_value;
        end
    end

endmodule

module difftest_exe_mem1_reg (
    input clk,
    input resetn,

    input stall,

    input        in_csr_3w,
    input        in_is_CNTinst,
    input [ 7:0] in_load_valid,
    input [ 7:0] in_store_valid,
    input [63:0] in_timer_64_value,

    output reg        out_csr_3w,
    output reg        out_is_CNTinst,
    output reg [ 7:0] out_load_valid,
    output reg [ 7:0] out_store_valid,
    output reg [63:0] out_timer_64_value
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_csr_3w         <= 1'b0;
            out_is_CNTinst     <= 1'b0;
            out_load_valid     <= 8'b0;
            out_store_valid    <= 8'b0;
            out_timer_64_value <= 64'b0;
        end else if (!stall) begin
            out_csr_3w         <= in_csr_3w;
            out_is_CNTinst     <= in_is_CNTinst;
            out_load_valid     <= in_load_valid;
            out_store_valid    <= in_store_valid;
            out_timer_64_value <= in_timer_64_value;
        end
    end

endmodule

module difftest_mem1_mem2_reg (
    input clk,
    input resetn,

    input stall,

    input        in_csr_3w,
    input        in_is_CNTinst,
    input [ 7:0] in_load_valid,
    input [ 7:0] in_store_valid,
    input [63:0] in_timer_64_value,
    input [31:0] in_vaddr,
    input [31:0] in_paddr,

    output reg        out_csr_3w,
    output reg        out_is_CNTinst,
    output reg [ 7:0] out_load_valid,
    output reg [ 7:0] out_store_valid,
    output reg [63:0] out_timer_64_value,
    output reg [31:0] out_vaddr,
    output reg [31:0] out_paddr
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_csr_3w         <= 1'b0;
            out_is_CNTinst     <= 1'b0;
            out_load_valid     <= 8'b0;
            out_store_valid    <= 8'b0;
            out_timer_64_value <= 64'b0;
            out_vaddr          <= 32'b0;
            out_paddr          <= 32'b0;
        end else if (!stall) begin
            out_csr_3w         <= in_csr_3w;
            out_is_CNTinst     <= in_is_CNTinst;
            out_load_valid     <= in_load_valid;
            out_store_valid    <= in_store_valid;
            out_timer_64_value <= in_timer_64_value;
            out_vaddr          <= in_vaddr;
            out_paddr          <= in_paddr;
        end
    end

endmodule

module difftest_mem2_wb_reg (
    input clk,
    input resetn,

    input stall,

    input        in_csr_3w,
    input        in_is_CNTinst,
    input [ 7:0] in_load_valid,
    input [ 7:0] in_store_valid,
    input [63:0] in_timer_64_value,
    input [31:0] in_vaddr,
    input [31:0] in_paddr,
    input [31:0] in_storeData,

    output reg        out_csr_3w,
    output reg        out_is_CNTinst,
    output reg [ 7:0] out_load_valid,
    output reg [ 7:0] out_store_valid,
    output reg [63:0] out_timer_64_value,
    output reg [31:0] out_vaddr,
    output reg [31:0] out_paddr,
    output reg [31:0] out_storeData
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_csr_3w         <= 1'b0;
            out_is_CNTinst     <= 1'b0;
            out_load_valid     <= 8'b0;
            out_store_valid    <= 8'b0;
            out_timer_64_value <= 64'b0;
            out_vaddr          <= 32'b0;
            out_paddr          <= 32'b0;
            out_storeData      <= 32'b0;
        end else if (!stall) begin
            out_csr_3w         <= in_csr_3w;
            out_is_CNTinst     <= in_is_CNTinst;
            out_load_valid     <= in_load_valid;
            out_store_valid    <= in_store_valid;
            out_timer_64_value <= in_timer_64_value;
            out_vaddr          <= in_vaddr;
            out_paddr          <= in_paddr;
            out_storeData      <= in_storeData;
        end
    end

endmodule

module difftest_commit_reg (
    input clk,
    input resetn,

    input stall,

    input        in_csr_3w,
    input        in_is_CNTinst,
    input [ 7:0] in_load_valid,
    input [ 7:0] in_store_valid,
    input [63:0] in_timer_64_value,
    input [31:0] in_vaddr,
    input [31:0] in_paddr,
    input [31:0] in_storeData,

    input        in_valid,
    input [31:0] in_pc,
    input [31:0] in_instruction,
    input        in_is_tlbfill,
    input [ 3:0] in_tlbfill_index,
    input        in_wen,
    input [ 4:0] in_wdest,
    input [31:0] in_wdata,
    input        in_is_exception,
    input        in_is_eret,

    output reg        out_csr_3w,
    output reg        out_is_CNTinst,
    output reg [ 7:0] out_load_valid,
    output reg [ 7:0] out_store_valid,
    output reg [63:0] out_timer_64_value,
    output reg [31:0] out_vaddr,
    output reg [31:0] out_paddr,
    output reg [31:0] out_storeData,

    output reg        out_valid,
    output reg [31:0] out_pc,
    output reg [31:0] out_instruction,
    output reg        out_is_tlbfill,
    output reg [ 3:0] out_tlbfill_index,
    output reg        out_wen,
    output reg [ 4:0] out_wdest,
    output reg [31:0] out_wdata,
    output reg        out_is_exception,
    output reg        out_is_eret
);

    always @(posedge clk) begin
        if (!resetn) begin
            out_csr_3w         <= 1'b0;
            out_is_CNTinst     <= 1'b0;
            out_load_valid     <= 8'b0;
            out_store_valid    <= 8'b0;
            out_timer_64_value <= 64'b0;
            out_vaddr          <= 32'b0;
            out_paddr          <= 32'b0;
            out_storeData      <= 32'b0;

            out_valid          <= 1'b0;
            out_pc             <= 32'b0;
            out_instruction    <= 32'b0;
            out_is_tlbfill     <= 1'b0;
            out_tlbfill_index  <= 4'b0;
            out_wen            <= 1'b0;
            out_wdest          <= 5'b0;
            out_wdata          <= 32'b0;
            out_is_exception   <= 1'b0;
            out_is_eret        <= 1'b0;
        end else if (!stall) begin
            out_csr_3w         <= in_csr_3w;
            out_is_CNTinst     <= in_is_CNTinst;
            out_load_valid     <= in_load_valid;
            out_store_valid    <= in_store_valid;
            out_timer_64_value <= in_timer_64_value;
            out_vaddr          <= in_vaddr;
            out_paddr          <= in_paddr;
            out_storeData      <= in_storeData;

            out_valid          <= in_valid;
            out_pc             <= in_pc;
            out_instruction    <= in_instruction;
            out_is_tlbfill     <= in_is_tlbfill;
            out_tlbfill_index  <= in_tlbfill_index;
            out_wen            <= in_wen;
            out_wdest          <= in_wdest;
            out_wdata          <= in_wdata;
            out_is_exception   <= in_is_exception;
            out_is_eret        <= in_is_eret;
        end
    end


endmodule


`endif
