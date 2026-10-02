`include "header.v"

module rob #(
        parameter DEPTH              = `ROB_DEPTH,
        parameter ID_WIDTH           = `ROB_ID_WIDTH,
        parameter COUNT_WIDTH        = `ROB_COUNT_WIDTH,
        parameter ARCH_WIDTH         = `ROB_ARCH_WIDTH,
        parameter PHY_WIDTH          = `ROB_PHY_WIDTH,
        parameter PC_WIDTH           = `ROB_PC_WIDTH,
        parameter ISSUE_OP_WIDTH     = `ROB_ISSUE_OP_WIDTH,
        parameter WRITEBACK_OP_WIDTH = `ROB_WRITEBACK_OP_WIDTH

    ) (
        input wire clk,
        input wire resetn,
        input wire flush,

        input  wire                      rob_alloc_valid,
        output wire                      rob_alloc_ready,
        output wire [      ID_WIDTH-1:0] rob_alloc_rob_id,
        input  wire [      PC_WIDTH-1:0] rob_alloc_pc,
        input  wire [              31:0] rob_alloc_instruction,
        input  wire [    ARCH_WIDTH-1:0] rob_alloc_arch_dest,
        input  wire [     PHY_WIDTH-1:0] rob_alloc_new_pdest,
        input  wire [     PHY_WIDTH-1:0] rob_alloc_old_pdest,
        input  wire                      rob_alloc_regfile_we,
        input  wire [               2:0] rob_alloc_inst_type,
        input  wire [ISSUE_OP_WIDTH-1:0] rob_alloc_issue_op,
        input  wire [               4:0] rob_alloc_bid,
        input  wire                      rob_alloc_is_exception,

        input wire                rob_alu_complete_valid,
        input wire [ID_WIDTH-1:0] rob_alu_complete_rob_id,
        input wire [        31:0] rob_alu_complete_value,

        input wire                rob_alu_extra_complete_valid,
        input wire [ID_WIDTH-1:0] rob_alu_extra_complete_rob_id,
        input wire [        31:0] rob_alu_extra_complete_value,


        input wire                          rob_lsu_complete_valid,
        input wire [          ID_WIDTH-1:0] rob_lsu_complete_rob_id,
        input wire [                  31:0] rob_lsu_complete_value,
        input wire [WRITEBACK_OP_WIDTH-1:0] rob_lsu_complete_writeback_op,
        input wire                          rob_lsu_complete_exception,

        input wire                rob_mul_complete_valid,
        input wire [ID_WIDTH-1:0] rob_mul_complete_rob_id,
        input wire [        31:0] rob_mul_complete_value,

        input wire                rob_div_complete_valid,
        input wire [ID_WIDTH-1:0] rob_div_complete_rob_id,
        input wire [        31:0] rob_div_complete_value,

        input wire                rob_fast_complete_valid,
        input wire [ID_WIDTH-1:0] rob_fast_complete_rob_id,
        input wire [        31:0] rob_fast_complete_value,

        input wire                rob_fast_extra_complete_valid,
        input wire [ID_WIDTH-1:0] rob_fast_extra_complete_rob_id,
        input wire [        31:0] rob_fast_extra_complete_value,

        output wire                          rob_commit_valid,
        input  wire                          rob_commit_ready,
        output wire                          rob_commit_fire,
        output wire [          ID_WIDTH-1:0] rob_commit_rob_id,
        output wire [          PC_WIDTH-1:0] rob_commit_pc,
        output wire [                  31:0] rob_commit_instruction,
        output wire [        ARCH_WIDTH-1:0] rob_commit_arch_dest,
        output wire [         PHY_WIDTH-1:0] rob_commit_new_pdest,
        output wire [         PHY_WIDTH-1:0] rob_commit_old_pdest,
        output wire                          rob_commit_regfile_we,
        output wire [                  31:0] rob_commit_value,
        output wire [                   2:0] rob_commit_inst_type,
        output wire [    ISSUE_OP_WIDTH-1:0] rob_commit_issue_op,
        output wire [WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op,
        output wire                          rob_commit_is_exception,

        output wire                   rob_complete_conflict,
        output wire [   ID_WIDTH-1:0] rob_head,
        output wire                   rob_full,
        output wire                   rob_empty,
        output wire [COUNT_WIDTH-1:0] rob_count,


        input wire                predict_flush,
        input wire [ID_WIDTH-1:0] predict_flush_rob_id,
        input wire [         4:0] predict_flush_bid,
        input wire [         4:0] head_bid

    );

    localparam [ID_WIDTH-1:0] LAST = DEPTH - 1;
    localparam [ID_WIDTH-1:0] ID_ONE = {{(ID_WIDTH - 1) {1'b0}}, 1'b1};
    localparam [COUNT_WIDTH-1:0] COUNT_FULL = DEPTH - 1;
    localparam [COUNT_WIDTH-1:0] COUNT_ONE = {{(COUNT_WIDTH - 1) {1'b0}}, 1'b1};
    localparam METADATA_WIDTH = 100;

    reg     [          ID_WIDTH-1:0] head;
    reg     [          ID_WIDTH-1:0] tail;
    reg     [       COUNT_WIDTH-1:0] count;

    reg     [             DEPTH-1:0] valid;
    reg     [             DEPTH-1:0] done;
`ifdef DEBUG_ROB_VALUE

    reg     [                  31:0] value  [DEPTH-1:0];

`endif

    reg                              writeback_is_exception[DEPTH-1:0];
    reg     [                   4:0] bid                   [DEPTH-1:0];

    wire                             rob_alloc_fire;
    wire                             head_valid;
    wire                             head_done;
    wire    [          ID_WIDTH-1:0] head_next;
    wire    [          ID_WIDTH-1:0] tail_next;
    wire                             rob_active;
    wire    [       COUNT_WIDTH-1:0] count_next;
    wire    [          ID_WIDTH-1:0] bram_read_addr;
    wire    [     METADATA_WIDTH-1:0] metadata_bram_dina;
    wire    [     METADATA_WIDTH-1:0] metadata_bram_doutb;
    wire    [WRITEBACK_OP_WIDTH-1:0] writeback_bram_doutb;
    wire                             metadata_collision;
    wire                             writeback_collision;
    wire    [     METADATA_WIDTH-1:0] metadata_effective_data;
    wire    [WRITEBACK_OP_WIDTH-1:0] writeback_effective_data;
    wire    [          PC_WIDTH-1:0] head_pc;
    wire    [                  31:0] head_instruction;
    wire    [        ARCH_WIDTH-1:0] head_arch_dest;
    wire    [         PHY_WIDTH-1:0] head_new_pdest;
    wire    [         PHY_WIDTH-1:0] head_old_pdest;
    wire                             head_regfile_we;
    wire    [                   2:0] head_inst_type;
    wire    [    ISSUE_OP_WIDTH-1:0] head_issue_op;
    wire                             head_is_exception;
    reg                              metadata_bypass_valid_q;
    reg     [     METADATA_WIDTH-1:0] metadata_bypass_data_q;
    reg                              writeback_bypass_valid_q;
    reg     [WRITEBACK_OP_WIDTH-1:0] writeback_bypass_data_q;
    integer                          seq_i;

    genvar i;

    assign rob_active              = 1'b1;
    assign rob_full                = count == COUNT_FULL;
    assign rob_empty               = (count == {COUNT_WIDTH{1'b0}});
    assign rob_count               = count;
    assign rob_head                = head;
    assign rob_complete_conflict   = rob_alu_complete_valid && rob_lsu_complete_valid && (rob_alu_complete_rob_id == rob_lsu_complete_rob_id);

    assign rob_alloc_ready         = rob_active && !rob_full;
    assign rob_alloc_fire          = rob_alloc_valid && rob_alloc_ready;
    assign rob_alloc_rob_id        = tail;

    assign head_valid              = valid[head];
    assign head_done               = done[head];

    assign metadata_bram_dina = {
               rob_alloc_pc,             // [99:68]
               rob_alloc_instruction,    // [67:36]
               rob_alloc_arch_dest,      // [35:31]
               rob_alloc_new_pdest,      // [30:24]
               rob_alloc_old_pdest,      // [23:17]
               rob_alloc_regfile_we,     // [16]
               rob_alloc_inst_type,      // [15:13]
               rob_alloc_issue_op,       // [12:1]
               rob_alloc_is_exception    // [0]
           };

    assign metadata_collision = rob_alloc_fire &&
           (tail == bram_read_addr);

    assign writeback_collision = rob_lsu_complete_valid &&
           (rob_lsu_complete_rob_id == bram_read_addr);

    assign metadata_effective_data = metadata_bypass_valid_q ?
           metadata_bypass_data_q :
           metadata_bram_doutb;

    assign writeback_effective_data = writeback_bypass_valid_q ?
           writeback_bypass_data_q :
           writeback_bram_doutb;

    assign {
            head_pc,
            head_instruction,
            head_arch_dest,
            head_new_pdest,
            head_old_pdest,
            head_regfile_we,
            head_inst_type,
            head_issue_op,
            head_is_exception
        } = metadata_effective_data;

    assign rob_commit_valid        = rob_active && head_valid && (head_done || head_inst_type == `SEL_ISSUE_QUEUE_NO || rob_commit_is_exception) && head != tail;
    assign rob_commit_fire         = rob_commit_valid && rob_commit_ready;

    assign rob_commit_rob_id       = head;
    assign rob_commit_pc           = head_pc;
    assign rob_commit_instruction  = head_instruction;
    assign rob_commit_arch_dest    = head_arch_dest;
    assign rob_commit_new_pdest    = head_new_pdest;
    assign rob_commit_old_pdest    = head_old_pdest;
    assign rob_commit_regfile_we   = head_regfile_we;
`ifdef DEBUG_ROB_VALUE

    assign rob_commit_value        = value[head];

`else
    assign rob_commit_value        = 32'd0;

`endif

    assign rob_commit_inst_type    = head_inst_type;
    assign rob_commit_issue_op     = head_issue_op;
    assign rob_commit_writeback_op = writeback_effective_data & {WRITEBACK_OP_WIDTH{writeback_is_exception[head]}};
    assign rob_commit_is_exception = head_is_exception || writeback_is_exception[head];


    assign count_next              = (predict_flush_rob_id - head + 1) & COUNT_FULL;
    assign head_next               = (head == LAST) ? {ID_WIDTH{1'b0}} : head + ID_ONE;
    assign tail_next               = (tail == LAST) ? {ID_WIDTH{1'b0}} : tail + ID_ONE;
    assign bram_read_addr          = (!resetn || flush) ? {ID_WIDTH{1'b0}} :
           rob_commit_fire    ? head_next :
           head;

    rob_metadata_bram u_rob_metadata_bram (
                          .clka  (clk),
                          .ena   (1'b1),
                          .wea   (rob_alloc_fire),
                          .addra (tail),
                          .dina  (metadata_bram_dina),
                          .clkb  (clk),
                          .enb   (1'b1),
                          .addrb (bram_read_addr),
                          .doutb (metadata_bram_doutb)
                      );

    rob_writeback_bram u_rob_writeback_bram (
                           .clka  (clk),
                           .ena   (1'b1),
                           .wea   (rob_lsu_complete_valid),
                           .addra (rob_lsu_complete_rob_id),
                           .dina  (rob_lsu_complete_writeback_op),
                           .clkb  (clk),
                           .enb   (1'b1),
                           .addrb (bram_read_addr),
                           .doutb (writeback_bram_doutb)
                       );

    always @(posedge clk) begin
        if (!resetn || flush) begin
            metadata_bypass_valid_q  <= 1'b0;
            writeback_bypass_valid_q <= 1'b0;
        end
        else begin
            metadata_bypass_valid_q  <= metadata_collision;
            writeback_bypass_valid_q <= writeback_collision;
        end

        if (metadata_collision)
            metadata_bypass_data_q <= metadata_bram_dina;

        if (writeback_collision)
            writeback_bypass_data_q <= rob_lsu_complete_writeback_op;
    end


    wire [DEPTH-1:0] bid_greater;


    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_greater
            circle_comparator u_circle_comparator (
                                  .head  (head_bid),
                                  .a     (bid[i]),
                                  .b     (predict_flush_bid),
                                  .a_gt_b(bid_greater[i])
                              );
        end
    endgenerate


    always @(posedge clk) begin
        if (!resetn || flush)
            head <= {ID_WIDTH{1'b0}};
        else if (rob_commit_fire)
            head <= head_next;
    end

    always @(posedge clk) begin
        if (!resetn || flush)
            tail <= {ID_WIDTH{1'b0}};
        else if (predict_flush)
            tail <= predict_flush_rob_id + 1;
        else if (rob_alloc_fire)
            tail <= tail_next;
    end

    always @(posedge clk) begin
        if (rob_alloc_fire) begin
            bid[tail]                    <= rob_alloc_bid;
            writeback_is_exception[tail] <= 1'b0;
        end

        if (rob_lsu_complete_valid) begin
            writeback_is_exception[rob_lsu_complete_rob_id] <= rob_lsu_complete_exception;
        end
    end


    always @(posedge clk) begin
        if (!resetn || flush) begin
            count <= {COUNT_WIDTH{1'b0}};
        end
        else if (predict_flush) begin
            count <= count_next;
        end
        else begin
            case ({
                          rob_alloc_fire, rob_commit_fire
                      })
                2'b10:
                    count <= count + COUNT_ONE;
                2'b01:
                    count <= count - COUNT_ONE;
            endcase
        end
    end



    always @(posedge clk) begin
        if (!resetn || flush) begin
            valid <= {DEPTH{1'b0}};
        end
        else if (predict_flush) begin
            valid <= ~bid_greater & valid;
        end
        else begin
            if (rob_alloc_fire)
                valid[tail] <= 1'b1;
            if (rob_commit_fire)
                valid[head] <= 1'b0;
        end
    end


    wire [6:0] complete_rob[DEPTH-1:0];

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_comptete_and_done
            assign complete_rob[i][0] = rob_alu_complete_valid && rob_alu_complete_rob_id == i;
            assign complete_rob[i][1] = rob_lsu_complete_valid && rob_lsu_complete_rob_id == i;
            assign complete_rob[i][2] = rob_mul_complete_valid && rob_mul_complete_rob_id == i;
            assign complete_rob[i][3] = rob_div_complete_valid && rob_div_complete_rob_id == i;
            assign complete_rob[i][4] = rob_fast_complete_valid && rob_fast_complete_rob_id == i;
            assign complete_rob[i][5] = rob_fast_extra_complete_valid && rob_fast_extra_complete_rob_id == i;
            assign complete_rob[i][6] = rob_alu_extra_complete_valid && rob_alu_extra_complete_rob_id == i;

            always @(posedge clk) begin
                if (rob_alloc_fire && i == tail) begin
                    done[i] <= 1'b0;
                end
                else if (|complete_rob[i]) begin
                    done[i] <= 1'b1;
                end
`ifdef DEBUG_ROB_VALUE
                case (complete_rob[i])
                    7'b0000001:
                        value[i] <= rob_alu_complete_value;
                    7'b0000010:
                        value[i] <= rob_lsu_complete_value;
                    7'b0000100:
                        value[i] <= rob_mul_complete_value;
                    7'b0001000:
                        value[i] <= rob_div_complete_value;
                    7'b0010000:
                        value[i] <= rob_fast_complete_value;
                    7'b0100000:
                        value[i] <= rob_fast_extra_complete_value;
                    7'b1000000:
                        value[i] <= rob_alu_extra_complete_value;

                endcase
`endif

            end
        end
    endgenerate



endmodule
