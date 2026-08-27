`include "header.v"

module rob_bram_4in4out_core #(
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

        input  wire [3:0]                 rob_alloc_valid,
        output wire [3:0]                 rob_alloc_ready,
        output wire [ID_WIDTH-1:0]        rob_alloc_rob_id_0,
        output wire [ID_WIDTH-1:0]        rob_alloc_rob_id_1,
        output wire [ID_WIDTH-1:0]        rob_alloc_rob_id_2,
        output wire [ID_WIDTH-1:0]        rob_alloc_rob_id_3,
        input  wire [PC_WIDTH-1:0]        rob_alloc_pc_0,
        input  wire [PC_WIDTH-1:0]        rob_alloc_pc_1,
        input  wire [PC_WIDTH-1:0]        rob_alloc_pc_2,
        input  wire [PC_WIDTH-1:0]        rob_alloc_pc_3,
        input  wire [31:0]                rob_alloc_instruction_0,
        input  wire [31:0]                rob_alloc_instruction_1,
        input  wire [31:0]                rob_alloc_instruction_2,
        input  wire [31:0]                rob_alloc_instruction_3,
        input  wire [ARCH_WIDTH-1:0]      rob_alloc_arch_dest_0,
        input  wire [ARCH_WIDTH-1:0]      rob_alloc_arch_dest_1,
        input  wire [ARCH_WIDTH-1:0]      rob_alloc_arch_dest_2,
        input  wire [ARCH_WIDTH-1:0]      rob_alloc_arch_dest_3,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_new_pdest_0,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_new_pdest_1,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_new_pdest_2,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_new_pdest_3,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_old_pdest_0,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_old_pdest_1,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_old_pdest_2,
        input  wire [PHY_WIDTH-1:0]       rob_alloc_old_pdest_3,
        input  wire [3:0]                 rob_alloc_regfile_we,
        input  wire [2:0]                 rob_alloc_inst_type_0,
        input  wire [2:0]                 rob_alloc_inst_type_1,
        input  wire [2:0]                 rob_alloc_inst_type_2,
        input  wire [2:0]                 rob_alloc_inst_type_3,
        input  wire [ISSUE_OP_WIDTH-1:0]  rob_alloc_issue_op_0,
        input  wire [ISSUE_OP_WIDTH-1:0]  rob_alloc_issue_op_1,
        input  wire [ISSUE_OP_WIDTH-1:0]  rob_alloc_issue_op_2,
        input  wire [ISSUE_OP_WIDTH-1:0]  rob_alloc_issue_op_3,
        input  wire [3:0]                 rob_alloc_is_exception,

        input wire                rob_alu_complete_valid,
        input wire [ID_WIDTH-1:0] rob_alu_complete_rob_id,
        input wire [31:0]         rob_alu_complete_value,

        input wire                rob_alu_extra_complete_valid,
        input wire [ID_WIDTH-1:0] rob_alu_extra_complete_rob_id,
        input wire [31:0]         rob_alu_extra_complete_value,

        input wire                          rob_lsu_complete_valid,
        input wire [ID_WIDTH-1:0]           rob_lsu_complete_rob_id,
        input wire [31:0]                   rob_lsu_complete_value,
        input wire [WRITEBACK_OP_WIDTH-1:0] rob_lsu_complete_writeback_op,
        input wire                          rob_lsu_complete_exception,

        input wire                rob_mul_complete_valid,
        input wire [ID_WIDTH-1:0] rob_mul_complete_rob_id,
        input wire [31:0]         rob_mul_complete_value,

        input wire                rob_div_complete_valid,
        input wire [ID_WIDTH-1:0] rob_div_complete_rob_id,
        input wire [31:0]         rob_div_complete_value,

        input wire                rob_fast_complete_valid,
        input wire [ID_WIDTH-1:0] rob_fast_complete_rob_id,
        input wire [31:0]         rob_fast_complete_value,

        input wire                rob_fast_extra_complete_valid,
        input wire [ID_WIDTH-1:0] rob_fast_extra_complete_rob_id,
        input wire [31:0]         rob_fast_extra_complete_value,

        output wire [3:0]                    rob_commit_valid,
        input  wire [3:0]                    rob_commit_ready,
        output wire [3:0]                    rob_commit_fire,
        output wire [ID_WIDTH-1:0]           rob_commit_rob_id_0,
        output wire [ID_WIDTH-1:0]           rob_commit_rob_id_1,
        output wire [ID_WIDTH-1:0]           rob_commit_rob_id_2,
        output wire [ID_WIDTH-1:0]           rob_commit_rob_id_3,
        output wire [PC_WIDTH-1:0]           rob_commit_pc_0,
        output wire [PC_WIDTH-1:0]           rob_commit_pc_1,
        output wire [PC_WIDTH-1:0]           rob_commit_pc_2,
        output wire [PC_WIDTH-1:0]           rob_commit_pc_3,
        output wire [31:0]                   rob_commit_instruction_0,
        output wire [31:0]                   rob_commit_instruction_1,
        output wire [31:0]                   rob_commit_instruction_2,
        output wire [31:0]                   rob_commit_instruction_3,
        output wire [ARCH_WIDTH-1:0]         rob_commit_arch_dest_0,
        output wire [ARCH_WIDTH-1:0]         rob_commit_arch_dest_1,
        output wire [ARCH_WIDTH-1:0]         rob_commit_arch_dest_2,
        output wire [ARCH_WIDTH-1:0]         rob_commit_arch_dest_3,
        output wire [PHY_WIDTH-1:0]          rob_commit_new_pdest_0,
        output wire [PHY_WIDTH-1:0]          rob_commit_new_pdest_1,
        output wire [PHY_WIDTH-1:0]          rob_commit_new_pdest_2,
        output wire [PHY_WIDTH-1:0]          rob_commit_new_pdest_3,
        output wire [PHY_WIDTH-1:0]          rob_commit_old_pdest_0,
        output wire [PHY_WIDTH-1:0]          rob_commit_old_pdest_1,
        output wire [PHY_WIDTH-1:0]          rob_commit_old_pdest_2,
        output wire [PHY_WIDTH-1:0]          rob_commit_old_pdest_3,
        output wire [3:0]                    rob_commit_regfile_we,
        output wire [31:0]                   rob_commit_value_0,
        output wire [31:0]                   rob_commit_value_1,
        output wire [31:0]                   rob_commit_value_2,
        output wire [31:0]                   rob_commit_value_3,
        output wire [2:0]                    rob_commit_inst_type_0,
        output wire [2:0]                    rob_commit_inst_type_1,
        output wire [2:0]                    rob_commit_inst_type_2,
        output wire [2:0]                    rob_commit_inst_type_3,
        output wire [ISSUE_OP_WIDTH-1:0]     rob_commit_issue_op_0,
        output wire [ISSUE_OP_WIDTH-1:0]     rob_commit_issue_op_1,
        output wire [ISSUE_OP_WIDTH-1:0]     rob_commit_issue_op_2,
        output wire [ISSUE_OP_WIDTH-1:0]     rob_commit_issue_op_3,
        output wire [WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op_0,
        output wire [WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op_1,
        output wire [WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op_2,
        output wire [WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op_3,
        output wire [3:0]                    rob_commit_is_exception,

        output wire                   rob_complete_conflict,
        output wire [ID_WIDTH-1:0]    rob_head,
        output wire                   rob_full,
        output wire                   rob_empty,
        output wire [COUNT_WIDTH-1:0] rob_count,
        output wire [COUNT_WIDTH-1:0] rob_res_count,

        input wire                predict_flush,
        input wire [ID_WIDTH-1:0] predict_flush_rob_id,
        input wire [4:0]          predict_flush_bid,
        input wire [4:0]          head_bid
    );

    localparam [COUNT_WIDTH-1:0] COUNT_CAPACITY = DEPTH;
    localparam integer METADATA_WIDTH = 100;
    localparam [ID_WIDTH-1:0] ROB_ID_ONE =
               {{(ID_WIDTH-1){1'b0}}, 1'b1};

    wire [ID_WIDTH-1:0]           rob_alloc_rob_id [3:0];
    wire [PC_WIDTH-1:0]           rob_alloc_pc [3:0];
    wire [31:0]                   rob_alloc_instruction [3:0];
    wire [ARCH_WIDTH-1:0]         rob_alloc_arch_dest [3:0];
    wire [PHY_WIDTH-1:0]          rob_alloc_new_pdest [3:0];
    wire [PHY_WIDTH-1:0]          rob_alloc_old_pdest [3:0];
    wire [2:0]                    rob_alloc_inst_type [3:0];
    wire [ISSUE_OP_WIDTH-1:0]     rob_alloc_issue_op [3:0];
    wire [ID_WIDTH-1:0]           rob_commit_rob_id [3:0];
    wire [PC_WIDTH-1:0]           rob_commit_pc [3:0];
    wire [31:0]                   rob_commit_instruction [3:0];
    wire [ARCH_WIDTH-1:0]         rob_commit_arch_dest [3:0];
    wire [PHY_WIDTH-1:0]          rob_commit_new_pdest [3:0];
    wire [PHY_WIDTH-1:0]          rob_commit_old_pdest [3:0];
    wire [31:0]                   rob_commit_value [3:0];
    wire [2:0]                    rob_commit_inst_type [3:0];
    wire [ISSUE_OP_WIDTH-1:0]     rob_commit_issue_op [3:0];
    wire [WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op [3:0];

    assign rob_alloc_pc[0] = rob_alloc_pc_0;
    assign rob_alloc_pc[1] = rob_alloc_pc_1;
    assign rob_alloc_pc[2] = rob_alloc_pc_2;
    assign rob_alloc_pc[3] = rob_alloc_pc_3;
    assign rob_alloc_instruction[0] = rob_alloc_instruction_0;
    assign rob_alloc_instruction[1] = rob_alloc_instruction_1;
    assign rob_alloc_instruction[2] = rob_alloc_instruction_2;
    assign rob_alloc_instruction[3] = rob_alloc_instruction_3;
    assign rob_alloc_arch_dest[0] = rob_alloc_arch_dest_0;
    assign rob_alloc_arch_dest[1] = rob_alloc_arch_dest_1;
    assign rob_alloc_arch_dest[2] = rob_alloc_arch_dest_2;
    assign rob_alloc_arch_dest[3] = rob_alloc_arch_dest_3;
    assign rob_alloc_new_pdest[0] = rob_alloc_new_pdest_0;
    assign rob_alloc_new_pdest[1] = rob_alloc_new_pdest_1;
    assign rob_alloc_new_pdest[2] = rob_alloc_new_pdest_2;
    assign rob_alloc_new_pdest[3] = rob_alloc_new_pdest_3;
    assign rob_alloc_old_pdest[0] = rob_alloc_old_pdest_0;
    assign rob_alloc_old_pdest[1] = rob_alloc_old_pdest_1;
    assign rob_alloc_old_pdest[2] = rob_alloc_old_pdest_2;
    assign rob_alloc_old_pdest[3] = rob_alloc_old_pdest_3;
    assign rob_alloc_inst_type[0] = rob_alloc_inst_type_0;
    assign rob_alloc_inst_type[1] = rob_alloc_inst_type_1;
    assign rob_alloc_inst_type[2] = rob_alloc_inst_type_2;
    assign rob_alloc_inst_type[3] = rob_alloc_inst_type_3;
    assign rob_alloc_issue_op[0] = rob_alloc_issue_op_0;
    assign rob_alloc_issue_op[1] = rob_alloc_issue_op_1;
    assign rob_alloc_issue_op[2] = rob_alloc_issue_op_2;
    assign rob_alloc_issue_op[3] = rob_alloc_issue_op_3;
    assign rob_alloc_rob_id_0 = rob_alloc_rob_id[0];
    assign rob_alloc_rob_id_1 = rob_alloc_rob_id[1];
    assign rob_alloc_rob_id_2 = rob_alloc_rob_id[2];
    assign rob_alloc_rob_id_3 = rob_alloc_rob_id[3];
    assign rob_commit_rob_id_0 = rob_commit_rob_id[0];
    assign rob_commit_rob_id_1 = rob_commit_rob_id[1];
    assign rob_commit_rob_id_2 = rob_commit_rob_id[2];
    assign rob_commit_rob_id_3 = rob_commit_rob_id[3];
    assign rob_commit_pc_0 = rob_commit_pc[0];
    assign rob_commit_pc_1 = rob_commit_pc[1];
    assign rob_commit_pc_2 = rob_commit_pc[2];
    assign rob_commit_pc_3 = rob_commit_pc[3];
    assign rob_commit_instruction_0 = rob_commit_instruction[0];
    assign rob_commit_instruction_1 = rob_commit_instruction[1];
    assign rob_commit_instruction_2 = rob_commit_instruction[2];
    assign rob_commit_instruction_3 = rob_commit_instruction[3];
    assign rob_commit_arch_dest_0 = rob_commit_arch_dest[0];
    assign rob_commit_arch_dest_1 = rob_commit_arch_dest[1];
    assign rob_commit_arch_dest_2 = rob_commit_arch_dest[2];
    assign rob_commit_arch_dest_3 = rob_commit_arch_dest[3];
    assign rob_commit_new_pdest_0 = rob_commit_new_pdest[0];
    assign rob_commit_new_pdest_1 = rob_commit_new_pdest[1];
    assign rob_commit_new_pdest_2 = rob_commit_new_pdest[2];
    assign rob_commit_new_pdest_3 = rob_commit_new_pdest[3];
    assign rob_commit_old_pdest_0 = rob_commit_old_pdest[0];
    assign rob_commit_old_pdest_1 = rob_commit_old_pdest[1];
    assign rob_commit_old_pdest_2 = rob_commit_old_pdest[2];
    assign rob_commit_old_pdest_3 = rob_commit_old_pdest[3];
    assign rob_commit_value_0 = rob_commit_value[0];
    assign rob_commit_value_1 = rob_commit_value[1];
    assign rob_commit_value_2 = rob_commit_value[2];
    assign rob_commit_value_3 = rob_commit_value[3];
    assign rob_commit_inst_type_0 = rob_commit_inst_type[0];
    assign rob_commit_inst_type_1 = rob_commit_inst_type[1];
    assign rob_commit_inst_type_2 = rob_commit_inst_type[2];
    assign rob_commit_inst_type_3 = rob_commit_inst_type[3];
    assign rob_commit_issue_op_0 = rob_commit_issue_op[0];
    assign rob_commit_issue_op_1 = rob_commit_issue_op[1];
    assign rob_commit_issue_op_2 = rob_commit_issue_op[2];
    assign rob_commit_issue_op_3 = rob_commit_issue_op[3];
    assign rob_commit_writeback_op_0 = rob_commit_writeback_op[0];
    assign rob_commit_writeback_op_1 = rob_commit_writeback_op[1];
    assign rob_commit_writeback_op_2 = rob_commit_writeback_op[2];
    assign rob_commit_writeback_op_3 = rob_commit_writeback_op[3];

    reg [ID_WIDTH-1:0]    head;
    reg [ID_WIDTH-1:0]    tail;
    reg [COUNT_WIDTH-1:0] count;

    reg [DEPTH-1:0] done;
`ifdef DEBUG_ROB_VALUE

    reg [31:0] value [DEPTH-1:0];
`endif

    reg       writeback_is_exception [DEPTH-1:0];

    wire       rob_active;
    wire [3:0] rob_alloc_fire;
    wire [2:0] actual_alloc_count;
    wire [2:0] commit_count;

    wire [COUNT_WIDTH-1:0] count_next;
    wire [ID_WIDTH-1:0] read_base;
    wire [ID_WIDTH-1:0] read_rob_id [3:0];
    reg  [1:0] read_base_bank_q;

    wire [METADATA_WIDTH-1:0] metadata_bram_dina [3:0];
    reg                         metadata_bank_wea   [3:0];
    reg  [3:0]                  metadata_bank_addra [3:0];
    reg  [METADATA_WIDTH-1:0]   metadata_bank_dina  [3:0];
    reg  [3:0]                  metadata_bank_addrb [3:0];
    wire [METADATA_WIDTH-1:0]   metadata_bank_doutb [3:0];

    reg                         writeback_bank_wea   [3:0];
    reg  [3:0]                  writeback_bank_addra [3:0];
    reg  [3:0]                  writeback_bank_addrb [3:0];
    wire [WRITEBACK_OP_WIDTH-1:0] writeback_bank_doutb [3:0];

    reg  [METADATA_WIDTH-1:0]     metadata_bram_lane_data  [3:0];
    reg  [WRITEBACK_OP_WIDTH-1:0] writeback_bram_lane_data [3:0];
    wire                            commit_static_is_exception [3:0];

    wire hit0;
    wire hit1;
    wire hit2;
    wire hit3;

    wire [DEPTH-1:0] alloc_hit;
    wire [6:0] complete_rob [DEPTH-1:0];

    integer bank_i;
    genvar i;

    assign rob_active = 1'b1;

    assign rob_full      = count == COUNT_CAPACITY;
    assign rob_empty     = count == {COUNT_WIDTH{1'b0}};
    assign rob_count     = count;
    assign rob_res_count = COUNT_CAPACITY - count;
    assign rob_head      = head;

    assign rob_alloc_ready[0] = rob_active && (rob_res_count >= 1);
    assign rob_alloc_ready[1] = rob_active && (rob_res_count >= 2);
    assign rob_alloc_ready[2] = rob_active && (rob_res_count >= 3);
    assign rob_alloc_ready[3] = rob_active && (rob_res_count >= 4);

    assign rob_alloc_fire = rob_alloc_valid & rob_alloc_ready;
    assign actual_alloc_count =
           {2'b00, rob_alloc_fire[0]} +
           {2'b00, rob_alloc_fire[1]} +
           {2'b00, rob_alloc_fire[2]} +
           {2'b00, rob_alloc_fire[3]};

    assign rob_complete_conflict =
           rob_alu_complete_valid && rob_lsu_complete_valid &&
           (rob_alu_complete_rob_id == rob_lsu_complete_rob_id);

    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_lane_io
            localparam [ID_WIDTH-1:0] LANE_OFFSET = i;

            // Both operands are explicitly ID_WIDTH wide.  The addition is
            // therefore modulo 2**ID_WIDTH, including the 63 -> 0 wrap.
            assign rob_alloc_rob_id[i] = tail + LANE_OFFSET;
            assign rob_commit_rob_id[i] = head + LANE_OFFSET;
            assign read_rob_id[i] = read_base + LANE_OFFSET;

            assign metadata_bram_dina[i] = {
                       rob_alloc_pc[i],
                       rob_alloc_instruction[i],
                       rob_alloc_arch_dest[i],
                       rob_alloc_new_pdest[i],
                       rob_alloc_old_pdest[i],
                       rob_alloc_regfile_we[i],
                       rob_alloc_inst_type[i],
                       rob_alloc_issue_op[i],
                       rob_alloc_is_exception[i]
                   };

            assign {
                    rob_commit_pc[i],
                    rob_commit_instruction[i],
                    rob_commit_arch_dest[i],
                    rob_commit_new_pdest[i],
                    rob_commit_old_pdest[i],
                    rob_commit_regfile_we[i],
                    rob_commit_inst_type[i],
                    rob_commit_issue_op[i],
                    commit_static_is_exception[i]
                } = metadata_bram_lane_data[i];

            assign rob_commit_writeback_op[i] =
                   writeback_bram_lane_data[i] &
                   {WRITEBACK_OP_WIDTH{
                        writeback_is_exception[rob_commit_rob_id[i]]
                    }};

            assign rob_commit_is_exception[i] =
                   commit_static_is_exception[i] ||
                   writeback_is_exception[rob_commit_rob_id[i]];

`ifdef DEBUG_ROB_VALUE

            assign rob_commit_value[i] = value[rob_commit_rob_id[i]];
`else
            assign rob_commit_value[i] = 32'd0;
`endif

        end
    endgenerate

    // Allocation and recovery keep the active ROB entries as one continuous
    // interval [head, tail), so count determines whether each commit lane
    // exists.  done/exception state still determines whether it may commit.
    assign hit0 = rob_active && (count >= 1) &&
           (done[rob_commit_rob_id[0]] ||
            rob_commit_inst_type[0] == `SEL_ISSUE_QUEUE_NO ||
            rob_commit_is_exception[0]);

    assign hit1 = (count >= 2) &&
           (done[rob_commit_rob_id[1]] ||
            rob_commit_inst_type[1] == `SEL_ISSUE_QUEUE_NO ||
            rob_commit_is_exception[1]);

    assign hit2 = (count >= 3) &&
           (done[rob_commit_rob_id[2]] ||
            rob_commit_inst_type[2] == `SEL_ISSUE_QUEUE_NO ||
            rob_commit_is_exception[2]);

    assign hit3 = (count >= 4) &&
           (done[rob_commit_rob_id[3]] ||
            rob_commit_inst_type[3] == `SEL_ISSUE_QUEUE_NO ||
            rob_commit_is_exception[3]);

    assign rob_commit_valid[0] = hit0;
    assign rob_commit_valid[1] = hit1;
    assign rob_commit_valid[2] = hit2;
    assign rob_commit_valid[3] = hit3;

    assign rob_commit_fire[0] =
           rob_commit_valid[0] && rob_commit_ready[0];

    assign rob_commit_fire[1] =
           rob_commit_valid[1] && rob_commit_ready[0] &&
           rob_commit_ready[1];

    assign rob_commit_fire[2] =
           rob_commit_valid[2] && rob_commit_ready[0] &&
           rob_commit_ready[1] && rob_commit_ready[2];

    assign rob_commit_fire[3] =
           rob_commit_valid[3] && rob_commit_ready[0] &&
           rob_commit_ready[1] && rob_commit_ready[2] &&
           rob_commit_ready[3];

    assign commit_count =
           {2'b00, rob_commit_fire[0]} +
           {2'b00, rob_commit_fire[1]} +
           {2'b00, rob_commit_fire[2]} +
           {2'b00, rob_commit_fire[3]};

    assign read_base = head +
           {{(ID_WIDTH-3){1'b0}}, commit_count};

    always @* begin
        for (bank_i = 0; bank_i < 4; bank_i = bank_i + 1) begin
            metadata_bank_wea[bank_i] = 1'b0;
            metadata_bank_addra[bank_i] = 4'd0;
            metadata_bank_dina[bank_i] = {METADATA_WIDTH{1'b0}};
            metadata_bank_addrb[bank_i] = 4'd0;

            writeback_bank_wea[bank_i] = 1'b0;
            writeback_bank_addra[bank_i] = 4'd0;
            writeback_bank_addrb[bank_i] = 4'd0;
        end

        // Four consecutive allocation IDs visit each bank exactly once.
        // Express the rotation directly so synthesis does not build a
        // four-lane priority chain for every wide metadata input.
        case (tail[1:0])
            2'd0: begin
                metadata_bank_wea[0] = rob_alloc_fire[0];
                metadata_bank_wea[1] = rob_alloc_fire[1];
                metadata_bank_wea[2] = rob_alloc_fire[2];
                metadata_bank_wea[3] = rob_alloc_fire[3];

                metadata_bank_addra[0] = rob_alloc_rob_id[0][5:2];
                metadata_bank_addra[1] = rob_alloc_rob_id[1][5:2];
                metadata_bank_addra[2] = rob_alloc_rob_id[2][5:2];
                metadata_bank_addra[3] = rob_alloc_rob_id[3][5:2];

                metadata_bank_dina[0] = metadata_bram_dina[0];
                metadata_bank_dina[1] = metadata_bram_dina[1];
                metadata_bank_dina[2] = metadata_bram_dina[2];
                metadata_bank_dina[3] = metadata_bram_dina[3];
            end
            2'd1: begin
                metadata_bank_wea[0] = rob_alloc_fire[3];
                metadata_bank_wea[1] = rob_alloc_fire[0];
                metadata_bank_wea[2] = rob_alloc_fire[1];
                metadata_bank_wea[3] = rob_alloc_fire[2];

                metadata_bank_addra[0] = rob_alloc_rob_id[3][5:2];
                metadata_bank_addra[1] = rob_alloc_rob_id[0][5:2];
                metadata_bank_addra[2] = rob_alloc_rob_id[1][5:2];
                metadata_bank_addra[3] = rob_alloc_rob_id[2][5:2];

                metadata_bank_dina[0] = metadata_bram_dina[3];
                metadata_bank_dina[1] = metadata_bram_dina[0];
                metadata_bank_dina[2] = metadata_bram_dina[1];
                metadata_bank_dina[3] = metadata_bram_dina[2];
            end
            2'd2: begin
                metadata_bank_wea[0] = rob_alloc_fire[2];
                metadata_bank_wea[1] = rob_alloc_fire[3];
                metadata_bank_wea[2] = rob_alloc_fire[0];
                metadata_bank_wea[3] = rob_alloc_fire[1];

                metadata_bank_addra[0] = rob_alloc_rob_id[2][5:2];
                metadata_bank_addra[1] = rob_alloc_rob_id[3][5:2];
                metadata_bank_addra[2] = rob_alloc_rob_id[0][5:2];
                metadata_bank_addra[3] = rob_alloc_rob_id[1][5:2];

                metadata_bank_dina[0] = metadata_bram_dina[2];
                metadata_bank_dina[1] = metadata_bram_dina[3];
                metadata_bank_dina[2] = metadata_bram_dina[0];
                metadata_bank_dina[3] = metadata_bram_dina[1];
            end
            2'd3: begin
                metadata_bank_wea[0] = rob_alloc_fire[1];
                metadata_bank_wea[1] = rob_alloc_fire[2];
                metadata_bank_wea[2] = rob_alloc_fire[3];
                metadata_bank_wea[3] = rob_alloc_fire[0];

                metadata_bank_addra[0] = rob_alloc_rob_id[1][5:2];
                metadata_bank_addra[1] = rob_alloc_rob_id[2][5:2];
                metadata_bank_addra[2] = rob_alloc_rob_id[3][5:2];
                metadata_bank_addra[3] = rob_alloc_rob_id[0][5:2];

                metadata_bank_dina[0] = metadata_bram_dina[1];
                metadata_bank_dina[1] = metadata_bram_dina[2];
                metadata_bank_dina[2] = metadata_bram_dina[3];
                metadata_bank_dina[3] = metadata_bram_dina[0];
            end
        endcase

        // The LSU has one write candidate, so select its physical bank
        // directly and use only the four-bit row within that bank.
        case (rob_lsu_complete_rob_id[1:0])
            2'd0: begin
                writeback_bank_wea[0] = rob_lsu_complete_valid;
                writeback_bank_addra[0] = rob_lsu_complete_rob_id[5:2];
            end
            2'd1: begin
                writeback_bank_wea[1] = rob_lsu_complete_valid;
                writeback_bank_addra[1] = rob_lsu_complete_rob_id[5:2];
            end
            2'd2: begin
                writeback_bank_wea[2] = rob_lsu_complete_valid;
                writeback_bank_addra[2] = rob_lsu_complete_rob_id[5:2];
            end
            2'd3: begin
                writeback_bank_wea[3] = rob_lsu_complete_valid;
                writeback_bank_addra[3] = rob_lsu_complete_rob_id[5:2];
            end
        endcase

        // The four look-ahead read IDs also visit every bank exactly once.
        case (read_base[1:0])
            2'd0: begin
                metadata_bank_addrb[0] = read_rob_id[0][5:2];
                metadata_bank_addrb[1] = read_rob_id[1][5:2];
                metadata_bank_addrb[2] = read_rob_id[2][5:2];
                metadata_bank_addrb[3] = read_rob_id[3][5:2];

                writeback_bank_addrb[0] = read_rob_id[0][5:2];
                writeback_bank_addrb[1] = read_rob_id[1][5:2];
                writeback_bank_addrb[2] = read_rob_id[2][5:2];
                writeback_bank_addrb[3] = read_rob_id[3][5:2];
            end
            2'd1: begin
                metadata_bank_addrb[0] = read_rob_id[3][5:2];
                metadata_bank_addrb[1] = read_rob_id[0][5:2];
                metadata_bank_addrb[2] = read_rob_id[1][5:2];
                metadata_bank_addrb[3] = read_rob_id[2][5:2];

                writeback_bank_addrb[0] = read_rob_id[3][5:2];
                writeback_bank_addrb[1] = read_rob_id[0][5:2];
                writeback_bank_addrb[2] = read_rob_id[1][5:2];
                writeback_bank_addrb[3] = read_rob_id[2][5:2];
            end
            2'd2: begin
                metadata_bank_addrb[0] = read_rob_id[2][5:2];
                metadata_bank_addrb[1] = read_rob_id[3][5:2];
                metadata_bank_addrb[2] = read_rob_id[0][5:2];
                metadata_bank_addrb[3] = read_rob_id[1][5:2];

                writeback_bank_addrb[0] = read_rob_id[2][5:2];
                writeback_bank_addrb[1] = read_rob_id[3][5:2];
                writeback_bank_addrb[2] = read_rob_id[0][5:2];
                writeback_bank_addrb[3] = read_rob_id[1][5:2];
            end
            2'd3: begin
                metadata_bank_addrb[0] = read_rob_id[1][5:2];
                metadata_bank_addrb[1] = read_rob_id[2][5:2];
                metadata_bank_addrb[2] = read_rob_id[3][5:2];
                metadata_bank_addrb[3] = read_rob_id[0][5:2];

                writeback_bank_addrb[0] = read_rob_id[1][5:2];
                writeback_bank_addrb[1] = read_rob_id[2][5:2];
                writeback_bank_addrb[2] = read_rob_id[3][5:2];
                writeback_bank_addrb[3] = read_rob_id[0][5:2];
            end
        endcase
    end

    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_bram_bank
            rob_metadata_bank u_rob_metadata_bank (
                                  .clk    (clk),
                                  .resetn (resetn),
                                  .flush  (flush),
                                  .we     (metadata_bank_wea[i]),
                                  .waddr  (metadata_bank_addra[i]),
                                  .wdata  (metadata_bank_dina[i]),
                                  .re     (1'b1),
                                  .raddr  (metadata_bank_addrb[i]),
                                  .rdata  (metadata_bank_doutb[i])
                              );

            rob_writeback_bank u_rob_writeback_bank (
                                   .clk    (clk),
                                   .resetn (resetn),
                                   .flush  (flush),
                                   .we     (writeback_bank_wea[i]),
                                   .waddr  (writeback_bank_addra[i]),
                                   .wdata  (rob_lsu_complete_writeback_op),
                                   .re     (1'b1),
                                   .raddr  (writeback_bank_addrb[i]),
                                   .rdata  (writeback_bank_doutb[i])
                               );
        end
    endgenerate

    always @(posedge clk) begin
        read_base_bank_q <= read_base[1:0];
    end

    always @* begin
        case (read_base_bank_q)
            2'd0: begin
                metadata_bram_lane_data[0] = metadata_bank_doutb[0];
                metadata_bram_lane_data[1] = metadata_bank_doutb[1];
                metadata_bram_lane_data[2] = metadata_bank_doutb[2];
                metadata_bram_lane_data[3] = metadata_bank_doutb[3];
                writeback_bram_lane_data[0] = writeback_bank_doutb[0];
                writeback_bram_lane_data[1] = writeback_bank_doutb[1];
                writeback_bram_lane_data[2] = writeback_bank_doutb[2];
                writeback_bram_lane_data[3] = writeback_bank_doutb[3];
            end
            2'd1: begin
                metadata_bram_lane_data[0] = metadata_bank_doutb[1];
                metadata_bram_lane_data[1] = metadata_bank_doutb[2];
                metadata_bram_lane_data[2] = metadata_bank_doutb[3];
                metadata_bram_lane_data[3] = metadata_bank_doutb[0];
                writeback_bram_lane_data[0] = writeback_bank_doutb[1];
                writeback_bram_lane_data[1] = writeback_bank_doutb[2];
                writeback_bram_lane_data[2] = writeback_bank_doutb[3];
                writeback_bram_lane_data[3] = writeback_bank_doutb[0];
            end
            2'd2: begin
                metadata_bram_lane_data[0] = metadata_bank_doutb[2];
                metadata_bram_lane_data[1] = metadata_bank_doutb[3];
                metadata_bram_lane_data[2] = metadata_bank_doutb[0];
                metadata_bram_lane_data[3] = metadata_bank_doutb[1];
                writeback_bram_lane_data[0] = writeback_bank_doutb[2];
                writeback_bram_lane_data[1] = writeback_bank_doutb[3];
                writeback_bram_lane_data[2] = writeback_bank_doutb[0];
                writeback_bram_lane_data[3] = writeback_bank_doutb[1];
            end
            2'd3: begin
                metadata_bram_lane_data[0] = metadata_bank_doutb[3];
                metadata_bram_lane_data[1] = metadata_bank_doutb[0];
                metadata_bram_lane_data[2] = metadata_bank_doutb[1];
                metadata_bram_lane_data[3] = metadata_bank_doutb[2];
                writeback_bram_lane_data[0] = writeback_bank_doutb[3];
                writeback_bram_lane_data[1] = writeback_bank_doutb[0];
                writeback_bram_lane_data[2] = writeback_bank_doutb[1];
                writeback_bram_lane_data[3] = writeback_bank_doutb[2];
            end
            default: begin
                metadata_bram_lane_data[0] = {METADATA_WIDTH{1'b0}};
                metadata_bram_lane_data[1] = {METADATA_WIDTH{1'b0}};
                metadata_bram_lane_data[2] = {METADATA_WIDTH{1'b0}};
                metadata_bram_lane_data[3] = {METADATA_WIDTH{1'b0}};
                writeback_bram_lane_data[0] = {WRITEBACK_OP_WIDTH{1'b0}};
                writeback_bram_lane_data[1] = {WRITEBACK_OP_WIDTH{1'b0}};
                writeback_bram_lane_data[2] = {WRITEBACK_OP_WIDTH{1'b0}};
                writeback_bram_lane_data[3] = {WRITEBACK_OP_WIDTH{1'b0}};
            end
        endcase
    end

    assign count_next =
           (predict_flush_rob_id >= head) ?
           // 没有经过 63→0
           ({{(COUNT_WIDTH-ID_WIDTH){1'b0}}, predict_flush_rob_id} -
            {{(COUNT_WIDTH-ID_WIDTH){1'b0}}, head} + 1'b1) :
           // 经过了 63→0
           (COUNT_CAPACITY -
            {{(COUNT_WIDTH-ID_WIDTH){1'b0}}, head} +
            {{(COUNT_WIDTH-ID_WIDTH){1'b0}}, predict_flush_rob_id} + 1'b1);

    always @(posedge clk) begin
        if (!resetn || flush)
            head <= {ID_WIDTH{1'b0}};
        else if (commit_count != 0)
            head <= head + {{(ID_WIDTH-3){1'b0}}, commit_count};
    end

    always @(posedge clk) begin
        if (!resetn || flush)
            tail <= {ID_WIDTH{1'b0}};
        else if (predict_flush)
            tail <= predict_flush_rob_id + ROB_ID_ONE;
        else if (|rob_alloc_fire)
            tail <= tail +
                 {{(ID_WIDTH-3){1'b0}}, actual_alloc_count};
    end

    always @(posedge clk) begin
        if (!resetn || flush)
            count <= {COUNT_WIDTH{1'b0}};
        else if (predict_flush)
            count <= count_next;
        else
            count <= count +
                  {{(COUNT_WIDTH-3){1'b0}}, actual_alloc_count} -
                  {{(COUNT_WIDTH-3){1'b0}}, commit_count};
    end

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_entry_state
            assign alloc_hit[i] =
                   (rob_alloc_fire[0] && rob_alloc_rob_id[0] == i) ||
                   (rob_alloc_fire[1] && rob_alloc_rob_id[1] == i) ||
                   (rob_alloc_fire[2] && rob_alloc_rob_id[2] == i) ||
                   (rob_alloc_fire[3] && rob_alloc_rob_id[3] == i);

            assign complete_rob[i][0] =
                   rob_alu_complete_valid && rob_alu_complete_rob_id == i;
            assign complete_rob[i][1] =
                   rob_lsu_complete_valid && rob_lsu_complete_rob_id == i;
            assign complete_rob[i][2] =
                   rob_mul_complete_valid && rob_mul_complete_rob_id == i;
            assign complete_rob[i][3] =
                   rob_div_complete_valid && rob_div_complete_rob_id == i;
            assign complete_rob[i][4] =
                   rob_fast_complete_valid && rob_fast_complete_rob_id == i;
            assign complete_rob[i][5] =
                   rob_fast_extra_complete_valid &&
                   rob_fast_extra_complete_rob_id == i;
            assign complete_rob[i][6] =
                   rob_alu_extra_complete_valid &&
                   rob_alu_extra_complete_rob_id == i;

            always @(posedge clk) begin
                if (alloc_hit[i])
                    writeback_is_exception[i] <= 1'b0;
                if (rob_lsu_complete_valid &&
                        rob_lsu_complete_rob_id == i)
                    writeback_is_exception[i] <=
                                          rob_lsu_complete_exception;
            end

            always @(posedge clk) begin
                if (alloc_hit[i])
                    done[i] <= 1'b0;
                else if (|complete_rob[i])
                    done[i] <= 1'b1;

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

// One metadata bank with deterministic same-address write forwarding.  The
// collision tag and write data are registered in parallel with the BMG's
// one-cycle synchronous read response, so no extra response cycle is added.
module rob_metadata_bank (
        input  wire        clk,
        input  wire        resetn,
        input  wire        flush,
        input  wire        we,
        input  wire [3:0]  waddr,
        input  wire [99:0] wdata,
        input  wire        re,
        input  wire [3:0]  raddr,
        output wire [99:0] rdata
    );

    wire [99:0] bram_rdata;
    wire        collision;
    reg          collision_q;
    reg  [99:0] bypass_data_q;

    assign collision = we && re && (waddr == raddr);

    rob_metadata_bram u_bram (
                          .clka  (clk),
                          .ena   (1'b1),
                          .wea   (we),
                          .addra (waddr),
                          .dina  (wdata),
                          .clkb  (clk),
                          .enb   (re),
                          .addrb (raddr),
                          .doutb (bram_rdata)
                      );

    always @(posedge clk) begin
        collision_q   <= collision;
        bypass_data_q <= wdata;
    end

    assign rdata = collision_q ? bypass_data_q : bram_rdata;

endmodule

// Writeback data uses the same bank-local forwarding rule as metadata.
module rob_writeback_bank (
        input  wire        clk,
        input  wire        resetn,
        input  wire        flush,
        input  wire        we,
        input  wire [3:0]  waddr,
        input  wire [38:0] wdata,
        input  wire        re,
        input  wire [3:0]  raddr,
        output wire [38:0] rdata
    );

    wire [38:0] bram_rdata;
    wire        collision;
    reg          collision_q;
    reg  [38:0] bypass_data_q;

    assign collision = we && re && (waddr == raddr);

    rob_writeback_bram u_bram (
                           .clka  (clk),
                           .ena   (1'b1),
                           .wea   (we),
                           .addra (waddr),
                           .dina  (wdata),
                           .clkb  (clk),
                           .enb   (re),
                           .addrb (raddr),
                           .doutb (bram_rdata)
                       );

    always @(posedge clk) begin
        collision_q   <= collision;
        bypass_data_q <= wdata;
    end

    assign rdata = collision_q ? bypass_data_q : bram_rdata;

endmodule
