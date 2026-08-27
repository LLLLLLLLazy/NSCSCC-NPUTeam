`ifdef difftest



// Simulation-only metadata queue.  The CPU queue supplies the actual push and
// pop masks, so this queue only has to preserve the same circular ordering.
module difftest_forward_queue #(
        parameter integer ENTRY_WIDTH = 82
    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input wire [3:0] in_fire,
        input wire [ENTRY_WIDTH-1:0] in_data0,
        input wire [ENTRY_WIDTH-1:0] in_data1,
        input wire [ENTRY_WIDTH-1:0] in_data2,
        input wire [ENTRY_WIDTH-1:0] in_data3,

        input wire [3:0] out_fire,
        output wire [ENTRY_WIDTH-1:0] out_data0,
        output wire [ENTRY_WIDTH-1:0] out_data1,
        output wire [ENTRY_WIDTH-1:0] out_data2,
        output wire [ENTRY_WIDTH-1:0] out_data3
    );

    reg [ENTRY_WIDTH-1:0] entries [7:0];
    reg [3:0] head;
    reg [3:0] tail;

    function [2:0] prefix_count;
        input [3:0] valid;
        begin
            case (valid)
                4'b0001: prefix_count = 3'd1;
                4'b0011: prefix_count = 3'd2;
                4'b0111: prefix_count = 3'd3;
                4'b1111: prefix_count = 3'd4;
                default: prefix_count = 3'd0;
            endcase
        end
    endfunction

    wire [2:0] push_count = prefix_count(in_fire);
    wire [2:0] pop_count  = prefix_count(out_fire);

    assign out_data0 = entries[head[2:0]];
    assign out_data1 = entries[head[2:0] + 3'd1];
    assign out_data2 = entries[head[2:0] + 3'd2];
    assign out_data3 = entries[head[2:0] + 3'd3];

    always @(posedge clk) begin
        if (!resetn || flush) begin
            head <= 4'd0;
            tail <= 4'd0;
        end
        else begin
            if (in_fire[0])
                entries[tail[2:0]] <= in_data0;
            if (in_fire[1])
                entries[tail[2:0] + 3'd1] <= in_data1;
            if (in_fire[2])
                entries[tail[2:0] + 3'd2] <= in_data2;
            if (in_fire[3])
                entries[tail[2:0] + 3'd3] <= in_data3;

            head <= head + {1'b0, pop_count};
            tail <= tail + {1'b0, push_count};
        end
    end

endmodule


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
        input wire [3:0] alloc_fire,
        input wire [5:0] alloc_rob_0,
        input wire [5:0] alloc_rob_1,
        input wire [5:0] alloc_rob_2,
        input wire [5:0] alloc_rob_3,
        input wire [81:0] alloc_data_0,
        input wire [81:0] alloc_data_1,
        input wire [81:0] alloc_data_2,
        input wire [81:0] alloc_data_3,
        input wire [3:0] alloc_is_tlbfill,

        input wire tlbfill_fire,
        input wire [5:0] tlbfill_rob,
        input wire [ 3:0] tlbfill_index,

        input wire ls_fire,
        input wire [5:0] ls_rob,
        input wire [31:0] ls_vaddr,
        input wire [31:0] ls_paddr,
        input wire [31:0] ls_store_data,
        input wire ls_llbit,

        input wire [5:0] commit_rob [3:0],
        output wire [3:0] commit_csr_3w,
        output wire [3:0] commit_is_CNTinst,
        output wire [7:0] commit_load_valid [3:0],
        output wire [7:0] commit_store_valid [3:0],
        output wire [63:0] commit_timer_64_value [3:0],
        output wire [3:0] commit_tlbfill_index [3:0],
        output wire [31:0] commit_vaddr [3:0],
        output wire [31:0] commit_paddr [3:0],
        output wire [31:0] commit_store_data [3:0],
        output wire [3:0] commit_is_tlbfill
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

    wire [5:0] alloc_rob [3:0];
    wire [81:0] alloc_data [3:0];

    assign alloc_rob[0] = alloc_rob_0;
    assign alloc_rob[1] = alloc_rob_1;
    assign alloc_rob[2] = alloc_rob_2;
    assign alloc_rob[3] = alloc_rob_3;
    assign alloc_data[0] = alloc_data_0;
    assign alloc_data[1] = alloc_data_1;
    assign alloc_data[2] = alloc_data_2;
    assign alloc_data[3] = alloc_data_3;


    genvar commit_lane;
    generate
        for (commit_lane = 0; commit_lane < 4; commit_lane = commit_lane + 1) begin : gen_commit_read
            assign commit_csr_3w[commit_lane] = csr_3w[commit_rob[commit_lane]];
            assign commit_is_CNTinst[commit_lane] = is_CNTinst[commit_rob[commit_lane]];
            assign commit_load_valid[commit_lane] = load_valid[commit_rob[commit_lane]];
            assign commit_store_valid[commit_lane] = store_valid[commit_rob[commit_lane]];
            assign commit_timer_64_value[commit_lane] = timer_64_value[commit_rob[commit_lane]];
            assign commit_tlbfill_index[commit_lane] = u_tlbfill_index[commit_rob[commit_lane]];
            assign commit_vaddr[commit_lane] = vaddr[commit_rob[commit_lane]];
            assign commit_paddr[commit_lane] = paddr[commit_rob[commit_lane]];
            assign commit_store_data[commit_lane] = store_data[commit_rob[commit_lane]];
            assign commit_is_tlbfill[commit_lane] = tlbfill[commit_rob[commit_lane]];
        end
    endgenerate


    always @(posedge clk) begin
        if(alloc_fire[0]) begin
            {csr_3w[alloc_rob[0]], is_CNTinst[alloc_rob[0]],
             load_valid[alloc_rob[0]], store_valid[alloc_rob[0]],
             timer_64_value[alloc_rob[0]]} <= alloc_data[0];
            tlbfill[alloc_rob[0]] <= alloc_is_tlbfill[0];
        end
        if(alloc_fire[1]) begin
            {csr_3w[alloc_rob[1]], is_CNTinst[alloc_rob[1]],
             load_valid[alloc_rob[1]], store_valid[alloc_rob[1]],
             timer_64_value[alloc_rob[1]]} <= alloc_data[1];
            tlbfill[alloc_rob[1]] <= alloc_is_tlbfill[1];
        end
        if(alloc_fire[2]) begin
            {csr_3w[alloc_rob[2]], is_CNTinst[alloc_rob[2]],
             load_valid[alloc_rob[2]], store_valid[alloc_rob[2]],
             timer_64_value[alloc_rob[2]]} <= alloc_data[2];
            tlbfill[alloc_rob[2]] <= alloc_is_tlbfill[2];
        end
        if(alloc_fire[3]) begin
            {csr_3w[alloc_rob[3]], is_CNTinst[alloc_rob[3]],
             load_valid[alloc_rob[3]], store_valid[alloc_rob[3]],
             timer_64_value[alloc_rob[3]]} <= alloc_data[3];
            tlbfill[alloc_rob[3]] <= alloc_is_tlbfill[3];
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
