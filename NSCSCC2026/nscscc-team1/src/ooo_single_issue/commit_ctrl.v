`include "header.v"

module commit_ctrl (
        input wire clk,
        input wire resetn,

        input  wire rob_commit_valid,
        output reg  rob_commit_ready,

        input wire rob_commit_is_exception,
        input wire rob_commit_is_tlbr,
        input wire rob_commit_ertn_flush,
        input wire rob_commit_wb_refetch,

        input wire [31:0] csr_regfile_exception_enter_addr,
        input wire [31:0] csr_regfile_exception_return_addr,
        input wire [31:0] csr_regfile_exception_tlb_enter_addr,
        input wire [31:0] rob_commit_pc,

        input wire [2:0] rob_commit_inst_type,

        input wire        lsu_mem1_mem2_reg_stall,
        input wire [31:0] rob_commit_target_address,


        input  wire       rob_commit_is_cacop,
        input  wire [1:0] store_buffer_commit_mat,
        input  wire       cache_subsystem_dcache_busy,
        input  wire [1:0] cacop_fsm_state,
        output wire       sel_store_stall,
        output wire       sel_store_commit,

        output reg [31:0] flush_target_address,
        output reg        global_flush,

        input wire predict_flush
    );

    always @(*) begin
        if (rob_commit_valid && !global_flush && !predict_flush) begin
            if (rob_commit_is_exception)
                rob_commit_ready = 1'b1;
            else if (rob_commit_ertn_flush)
                rob_commit_ready = 1'b1;
            else begin
                case (rob_commit_inst_type)
                    `SEL_ISSUE_QUEUE_INTEGER:
                        rob_commit_ready = 1'b1;
                    `SEL_ISSUE_QUEUE_LOAD:
                        rob_commit_ready = 1'b1;
                    `SEL_ISSUE_QUEUE_STORE:
                        rob_commit_ready = commit_store;
                    `SEL_ISSUE_QUEUE_BRQ:
                        rob_commit_ready = 1'b1;
                    `SEL_ISSUE_QUEUE_MD:
                        rob_commit_ready = 1'b1;
                    `SEL_ISSUE_QUEUE_FAST:
                        rob_commit_ready = 1'b1;
                    `SEL_ISSUE_QUEUE_NO:
                        rob_commit_ready = 1'b1;
                    `SEL_ISSUE_QUEUE_PRIVILIEGE:
                        rob_commit_ready = 1'b1;
                    default:
                        rob_commit_ready = 1'b0;
                endcase
            end

        end
        else begin
            rob_commit_ready = 1'b0;
        end
    end
    reg commit_store;

    always @(posedge clk) begin
        if(!resetn)
            commit_store <= 1'b0;
        else if(rob_commit_ready || global_flush)
            commit_store <= 1'b0;
        else if(!sel_store_stall && !lsu_mem1_mem2_reg_stall && sel_store_commit)
            commit_store <= 1'b1;

    end

    assign sel_store_commit = rob_commit_valid && rob_commit_inst_type == `SEL_ISSUE_QUEUE_STORE && !rob_commit_is_exception && !commit_store;
    assign sel_store_stall  = store_buffer_commit_mat == 2'b01 && cache_subsystem_dcache_busy || predict_flush || global_flush;
    always @(posedge clk) begin
        if (!resetn) begin
            global_flush <= 1'b0;
        end
        else begin
            global_flush <= rob_commit_ready && (rob_commit_ertn_flush || rob_commit_is_exception || rob_commit_wb_refetch);
        end
    end

    always @(posedge clk) begin
        flush_target_address <= rob_commit_is_exception ? (rob_commit_is_tlbr ? csr_regfile_exception_tlb_enter_addr: csr_regfile_exception_enter_addr) :
                             rob_commit_ertn_flush ?  csr_regfile_exception_return_addr :
                             rob_commit_pc+32'd4;
    end







endmodule
