`include "header.v"

module commit_ctrl (
        input wire clk,
        input wire resetn,

        input  wire [3:0] rob_commit_valid,
        output reg  [3:0] rob_commit_ready,

        input wire [3:0] rob_commit_is_exception,
        input wire [3:0] rob_commit_is_tlbr,
        input wire [3:0] rob_commit_ertn_flush,
        input wire [3:0] rob_commit_wb_refetch,

        input wire [31:0] csr_regfile_exception_enter_addr,
        input wire [31:0] csr_regfile_exception_return_addr,
        input wire [31:0] csr_regfile_exception_tlb_enter_addr,
        input wire [31:0] rob_commit_pc_0,
        input wire [31:0] rob_commit_pc_1,
        input wire [31:0] rob_commit_pc_2,
        input wire [31:0] rob_commit_pc_3,

        input wire [2:0] rob_commit_inst_type_0,
        input wire [2:0] rob_commit_inst_type_1,
        input wire [2:0] rob_commit_inst_type_2,
        input wire [2:0] rob_commit_inst_type_3,

        input  wire [3:0] store_queue_uncommitted_count,
        input  wire       store_queue_drain_valid,
        input  wire [1:0] store_queue_drain_mat,
        input  wire       cache_subsystem_dcache_busy,
        output wire       sel_store_stall,
        output wire       sel_store_commit,

        output reg [31:0] flush_target_address,
        output reg        global_flush,

        input wire predict_flush
    );

    wire [31:0] rob_commit_pc [3:0];
    wire [2:0] rob_commit_inst_type [3:0];
    wire [3:0] redirect_request;
    wire [3:0] redirect_fire;

    reg       allow_lane;
    reg       lane_resource_ready;
    reg [2:0] stores_accepted;
    integer lane;

    assign rob_commit_pc[0] = rob_commit_pc_0;
    assign rob_commit_pc[1] = rob_commit_pc_1;
    assign rob_commit_pc[2] = rob_commit_pc_2;
    assign rob_commit_pc[3] = rob_commit_pc_3;

    assign rob_commit_inst_type[0] = rob_commit_inst_type_0;
    assign rob_commit_inst_type[1] = rob_commit_inst_type_1;
    assign rob_commit_inst_type[2] = rob_commit_inst_type_2;
    assign rob_commit_inst_type[3] = rob_commit_inst_type_3;

    assign redirect_request = rob_commit_is_exception |
           rob_commit_ertn_flush | rob_commit_wb_refetch;
    assign redirect_fire = rob_commit_valid & rob_commit_ready &
           redirect_request;

    // Build an oldest-first commit prefix.  A redirecting instruction may
    // retire, but terminates the group so no younger instruction can pass it.
    always @(*) begin
        rob_commit_ready = 4'b0000;
        allow_lane = !global_flush && !predict_flush;
        stores_accepted = 3'd0;
        lane_resource_ready = 1'b0;

        for (lane = 0; lane < 4; lane = lane + 1) begin
            lane_resource_ready = 1'b0;

            if (allow_lane && rob_commit_valid[lane]) begin
                if (rob_commit_is_exception[lane]) begin
                    lane_resource_ready = 1'b1;
                end
                else
                case (rob_commit_inst_type[lane])
                    `SEL_ISSUE_QUEUE_INTEGER,
                    `SEL_ISSUE_QUEUE_LOAD,
                    `SEL_ISSUE_QUEUE_BRQ,
                    `SEL_ISSUE_QUEUE_MD,
                    `SEL_ISSUE_QUEUE_FAST,
                    `SEL_ISSUE_QUEUE_NO,
                    `SEL_ISSUE_QUEUE_PRIVILIEGE,
                    `SEL_ISSUE_QUEUE_STORE:
                        lane_resource_ready = 1'b1;
                    default:
                        lane_resource_ready = 1'b0;
                endcase

                if (lane_resource_ready) begin
                    rob_commit_ready[lane] = 1'b1;
                    if (!rob_commit_is_exception[lane] && rob_commit_inst_type[lane] ==`SEL_ISSUE_QUEUE_STORE)
                        stores_accepted = stores_accepted + 3'd1;
                    if (redirect_request[lane])
                        allow_lane = 1'b0;
                end
                else begin
                    allow_lane = 1'b0;
                end
            end
            else begin
                allow_lane = 1'b0;
            end
        end
    end

    assign sel_store_commit = store_queue_drain_valid;
    assign sel_store_stall  = (store_queue_drain_valid && store_queue_drain_mat == 2'b01 && cache_subsystem_dcache_busy) || predict_flush || global_flush;

    always @(posedge clk) begin
        if (!resetn)
            global_flush <= 1'b0;
        else
            global_flush <= |redirect_fire;
    end

    always @(posedge clk) begin
        if (!resetn) begin
            flush_target_address <= 32'd0;
        end
        else if (redirect_fire[0]) begin
            flush_target_address <= rob_commit_is_exception[0] ?
                                 (rob_commit_is_tlbr[0] ?
                                  csr_regfile_exception_tlb_enter_addr :
                                  csr_regfile_exception_enter_addr) :
                                 rob_commit_ertn_flush[0] ?
                                 csr_regfile_exception_return_addr :
                                 rob_commit_pc[0] + 32'd4;
        end
        else if (redirect_fire[1]) begin
            flush_target_address <= rob_commit_is_exception[1] ?
                                 (rob_commit_is_tlbr[1] ?
                                  csr_regfile_exception_tlb_enter_addr :
                                  csr_regfile_exception_enter_addr) :
                                 rob_commit_ertn_flush[1] ?
                                 csr_regfile_exception_return_addr :
                                 rob_commit_pc[1] + 32'd4;
        end
        else if (redirect_fire[2]) begin
            flush_target_address <= rob_commit_is_exception[2] ?
                                 (rob_commit_is_tlbr[2] ?
                                  csr_regfile_exception_tlb_enter_addr :
                                  csr_regfile_exception_enter_addr) :
                                 rob_commit_ertn_flush[2] ?
                                 csr_regfile_exception_return_addr :
                                 rob_commit_pc[2] + 32'd4;
        end
        else if (redirect_fire[3]) begin
            flush_target_address <= rob_commit_is_exception[3] ?
                                 (rob_commit_is_tlbr[3] ?
                                  csr_regfile_exception_tlb_enter_addr :
                                  csr_regfile_exception_enter_addr) :
                                 rob_commit_ertn_flush[3] ?
                                 csr_regfile_exception_return_addr :
                                 rob_commit_pc[3] + 32'd4;
        end
    end

endmodule
