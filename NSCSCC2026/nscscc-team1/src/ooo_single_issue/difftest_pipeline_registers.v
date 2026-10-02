`ifdef difftest



module difftest_forward_reg (
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
        end
        else if (!stall) begin
            out_csr_3w         <= in_csr_3w;
            out_is_CNTinst     <= in_is_CNTinst;
            out_load_valid     <= in_load_valid;
            out_store_valid    <= in_store_valid;
            out_timer_64_value <= in_timer_64_value;
        end
    end

endmodule

module difftest_rob(
        input wire clk,
        input wire alloc_fire,
        input wire [5:0] alloc_rob,
        input wire       alloc_csr_3w,
        input wire        alloc_is_CNTinst,
        input wire [ 7:0] alloc_load_valid,
        input wire[ 7:0] alloc_store_valid,
        input wire [63:0] alloc_timer_64_value,
        input wire alloc_is_tlbfill,

        input wire tlbfill_fire,
        input wire [5:0] tlbfill_rob,
        input wire [ 3:0] tlbfill_index,

        input wire ls_fire,
        input wire [5:0] ls_rob,
        input wire [31:0] ls_vaddr,
        input wire [31:0] ls_paddr,
        input wire [31:0] ls_store_data,
        input wire ls_llbit,

        input wire [5:0]commit_rob,
        output wire       commit_csr_3w,
        output wire        commit_is_CNTinst,
        output wire [ 7:0] commit_load_valid,
        output wire[ 7:0] commit_store_valid,
        output wire [63:0] commit_timer_64_value,
        output wire  [ 3:0] commit_tlbfill_index,
        output wire [31:0] commit_vaddr,
        output wire [31:0] commit_paddr,
        output wire [31:0] commit_store_data,
        output wire commit_is_tlbfill
    );

    reg csr_3w [63:0];
    reg is_CNTinst [63:0];
    reg [ 7:0] load_valid [63:0];
    reg [ 7:0] store_valid [63:0];
    reg [63:0] timer_64_value [63:0];
    reg  [ 3:0] u_tlbfill_index [63:0];
    reg [31:0]vaddr [63:0];
    reg [31:0] paddr[63:0];
    reg [31:0] store_data[63:0];
    reg tlbfill[63:0];


    assign commit_csr_3w = csr_3w[commit_rob];
    assign commit_is_CNTinst = is_CNTinst[commit_rob];
    assign commit_load_valid = load_valid[commit_rob];
    assign commit_store_valid = store_valid[commit_rob];
    assign commit_timer_64_value = timer_64_value[commit_rob];
    assign commit_tlbfill_index = u_tlbfill_index[commit_rob];
    assign commit_vaddr = vaddr[commit_rob];
    assign commit_paddr = paddr[commit_rob];
    assign commit_store_data = store_data[commit_rob];
    assign commit_is_tlbfill = tlbfill[commit_rob];


    always @(posedge clk) begin
        if(alloc_fire) begin
            csr_3w[alloc_rob] <= alloc_csr_3w;
            is_CNTinst[alloc_rob] <= alloc_is_CNTinst;
            load_valid[alloc_rob] <= alloc_load_valid;
            store_valid[alloc_rob] <= alloc_store_valid;
            timer_64_value[alloc_rob] <= alloc_timer_64_value;
            tlbfill[alloc_rob] <= alloc_is_tlbfill;
        end


        if(tlbfill_fire) begin
            u_tlbfill_index[tlbfill_rob] <= tlbfill_index;
        end

        if(ls_fire) begin
            vaddr[ls_rob] <= ls_vaddr;
            paddr[ls_rob] <= ls_paddr;
            store_data[ls_rob] <= ls_store_data;
            store_valid[ls_rob] <= store_valid[ls_rob] & {4'b1111, ls_llbit, 3'b111};
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
        end
        else if (!stall) begin
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
