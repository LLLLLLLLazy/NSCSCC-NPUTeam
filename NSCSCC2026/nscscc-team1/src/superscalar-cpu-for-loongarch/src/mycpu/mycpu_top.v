`include "header.v"

`ifdef difftest


module core_top(

        `elsif  perftest_or_linux


        module core_top(


`else

module mycpu_top(


`endif

                input wire aclk,
                input wire aresetn,

                input wire [7:0] intrpt,

                output wire [ 3:0] arid,
                output wire [31:0] araddr,
                output wire [ 7:0] arlen,
                output wire [ 2:0] arsize,
                output wire [ 1:0] arburst,
                output wire [ 1:0] arlock,
                output wire [ 3:0] arcache,
                output wire [ 2:0] arprot,
                output wire        arvalid,
                input  wire        arready,

                input  wire [ 3:0] rid,
                input  wire [31:0] rdata,
                input  wire [ 1:0] rresp,
                input  wire        rlast,
                input  wire        rvalid,
                output wire        rready,

                output wire [ 3:0] awid,
                output wire [31:0] awaddr,
                output wire [ 7:0] awlen,
                output wire [ 2:0] awsize,
                output wire [ 1:0] awburst,
                output wire [ 1:0] awlock,
                output wire [ 3:0] awcache,
                output wire [ 2:0] awprot,
                output wire        awvalid,
                input  wire        awready,

                output wire [ 3:0] wid,
                output wire [31:0] wdata,
                output wire [ 3:0] wstrb,
                output wire        wlast,
                output wire        wvalid,
                input  wire        wready,

                input       [ 3:0] bid,
                input       [ 1:0] bresp,
                input  wire        bvalid,
                output wire        bready,

`ifdef difftest

                input           break_point,
                input           infor_flag,
                input  [ 4:0]   reg_num,
                output          ws_valid,
                output [31:0]   rf_rdata,
                // trace debug interface
                output wire [31:0] debug0_wb_pc,
                output wire [ 3:0] debug0_wb_rf_wen,
                output wire [ 4:0] debug0_wb_rf_wnum,
                output wire [31:0] debug0_wb_rf_wdata

                `elsif perftest_or_linux

                input           break_point,
                input           infor_flag,
                input  [ 4:0]   reg_num,
                output          ws_valid,
                output [31:0]   rf_rdata,

                // trace debug interface
                output wire [31:0] debug0_wb_pc,
                output wire [ 3:0] debug0_wb_rf_wen,
                output wire [ 4:0] debug0_wb_rf_wnum,
                output wire [31:0] debug0_wb_rf_wdata


`else

                output wire [31:0] debug_wb_pc,
                output wire [ 3:0] debug_wb_rf_we,
                output wire [ 4:0] debug_wb_rf_wnum,
                output wire [31:0] debug_wb_rf_wdata
`endif
            );
            wire         clk = aclk;
            wire         resetn = aresetn;

            wire         inst_sram_req;
            wire         inst_sram_wr;
            wire [1 : 0] inst_sram_size;
            wire [3 : 0] inst_sram_wstrb;
            wire [ 31:0] inst_sram_addr;
            wire [ 31:0] inst_sram_wdata;
            wire         inst_sram_addr_ok;
            wire         inst_sram_data_ok;
            wire [ 255:0] inst_sram_rdata;

            wire         data_sram_req;
            wire         data_sram_wr;
            wire [1 : 0] data_sram_size;
            wire [3 : 0] data_sram_wstrb;
            wire [ 31:0] data_sram_addr;
            wire [ 31:0] data_sram_wdata;
            wire         data_sram_addr_ok;
            wire         data_sram_data_ok;
            wire [ 31:0] data_sram_rdata;

            wire       cacop_req;
            wire [1:0] cacop_fsm_state;
            wire       cacop_fsm_valid;

            wire        cache_subsystem_if1_valid;
            wire [31:0] cache_subsystem_if1_va;
            wire        cache_subsystem_if1_ready;

            wire        cache_subsystem_if2_valid;
            wire [31:0] cache_subsystem_if2_va;
            wire [31:0] cache_subsystem_if2_pa;
            wire [ 1:0] cache_subsystem_if2_mat;

            wire        cache_subsystem_if2_miss_req;
            wire        cache_subsystem_if2_miss_ready;

            wire        cache_subsystem_if2_array_valid;
            wire        cache_subsystem_if2_hit;
            wire        cache_subsystem_if2_miss;

            wire        cache_subsystem_if2_hit_way;
            wire [31:0] cache_subsystem_if2_rdata;
            wire        cache_subsystem_if2_refill_valid;
            wire [31:0] cache_subsystem_if2_refill_rdata;
            wire        cache_subsystem_icache_busy;

            wire        cache_subsystem_mem1_valid;
            wire [31:0] cache_subsystem_mem1_va;
            wire        cache_subsystem_mem1_ready;

            wire        cache_subsystem_mem2_valid;
            wire        cache_subsystem_mem2_wr;
            wire [ 1:0] cache_subsystem_mem2_size;
            wire [ 3:0] cache_subsystem_mem2_wstrb;
            wire [31:0] cache_subsystem_mem2_wdata;
            wire [31:0] cache_subsystem_mem2_va;
            wire [31:0] cache_subsystem_mem2_pa;
            wire [ 1:0] cache_subsystem_mem2_mat;

            wire        cache_subsystem_mem2_miss_req;
            wire        cache_subsystem_mem2_miss_ready;
            wire        cache_subsystem_mem2_array_valid;

            wire        cache_subsystem_mem2_hit;
            wire        cache_subsystem_mem2_miss;
            wire        cache_subsystem_mem2_hit_way;
            wire        cache_subsystem_mem2_load_done;  //
            wire        cache_subsystem_mem2_store_done;  //
            wire [31:0] cache_subsystem_mem2_rdata;
            wire        cache_subsystem_mem2_refill_valid;
            wire [31:0] cache_subsystem_mem2_refill_rdata;
            wire        cache_subsystem_dcache_busy;

            wire        cache_subsystem_cacop_valid;
            wire        cache_subsystem_cacop_ready;
            wire        cache_subsystem_cacop_done;
            wire [ 4:0] cache_subsystem_cacop_code;
            wire [31:0] cache_subsystem_cacop_va;
            wire [31:0] cache_subsystem_cacop_pa;


            wire [2:0] inst_sram_fsm_state;
            wire [255:0] inst_stall_buffer_in_data;
            wire [255:0] inst_stall_buffer_out_data;


            wire [2:0] data_sram_fsm_state;
            wire [31:0] data_stall_buffer_in_data;
            wire [31:0] data_stall_buffer_out_data;
            wire data_sram_fsm_miss_trans;






            reg  global_valid;


            wire pc_state_in_is_exception;
            wire pc_state_in_is_adef;

            wire pc_state_out_is_exception;
            wire pc_state_out_is_adef;

            wire if1_clear;
            wire pc_reg_in_valid, pc_reg_stall, pc_reg_out_valid;

            wire [31:0] pc_reg_npc, pc_reg_pc;


            wire                                          if_insfifo_state_in_is_exception;
            wire                                          if_insfifo_state_in_is_adef;

            wire                                          if_insfifo_state_in_is_tlbr;
            wire                                          if_insfifo_state_in_is_inst_tlbr;
            wire                                          if_insfifo_state_in_is_inst_pif;
            wire                                          if_insfifo_state_in_is_inst_ppi;
            wire [                                   1:0] if_insfifo_state_in_mmu_inst_mat;


            wire                                          if_insfifo_state_out_is_exception;
            wire                                          if_insfifo_state_out_is_adef;

            wire                                          if_insfifo_state_out_is_tlbr;
            wire                                          if_insfifo_state_out_is_inst_tlbr;
            wire                                          if_insfifo_state_out_is_inst_pif;
            wire                                          if_insfifo_state_out_is_inst_ppi;
            wire [                                   1:0] if_insfifo_state_out_mmu_inst_mat;


            wire                                          if2_clear;
            wire                                          if_insfifo_reg_in_valid;
            wire                                          if_insfifo_reg_stall;
            wire                                          if_insfifo_reg_pre_stall;
            wire [                                  31:0] if_insfifo_reg_in_pc;
            wire [31:0] if_insfifo_reg_in_pc_pa;
            wire                                          if_insfifo_reg_out_valid;
            wire [                                  31:0] if_insfifo_reg_out_pc;
            wire [31:0] if_insfifo_reg_out_pc_pa;

            wire [                                  31:0] instruction_buffer_in_instrucion;
            wire                                          instruction_buffer_stall;
            wire [                                  31:0] instruction_buffer_out_instruction;
            wire                                          instruction_buffer_sel;



            wire [                                  31:0] branch_id_allocator_alloc_pc;
            wire [                                  31:0] branch_id_allocator_alloc_target_address;
            wire [                                  31:0] branch_id_allocator_alloc_imm;
            wire                                          branch_id_allocator_alloc_bid_valid;
            wire                                          branch_id_allocator_alloc_bid_ready;
            wire [                                   4:0] branch_id_allocator_alloc_bid;

            wire [2:0]                                    branch_id_allocator_commit_branch_count;

            wire                                          branch_id_allocator_global_flush;
            wire                                          branch_id_allocator_predict_flush;
            wire [                                   4:0] branch_id_allocator_predict_flush_bid;

            wire [                                   4:0] branch_id_allocator_bid_head;
            wire [                                   4:0] branch_id_allocator_bid_tail;

            wire [                                   4:0] branch_id_allocator_lookup_bid;
            wire [                                  31:0] branch_id_allocator_lookup_pc;
            wire [                                  31:0] branch_id_allocator_lookup_target_address;
            wire [                                  31:0] branch_id_allocator_lookup_imm;




            wire                                          rename_clear;





            wire [                                   6:0] cam_rmt_update_writeback1_reg_dst;
            wire                                          cam_rmt_update_writeback1_valid;

            wire [                                   6:0] cam_rmt_update_writeback2_reg_dst;
            wire                                          cam_rmt_update_writeback2_valid;

            wire [                                   6:0] cam_rmt_update_writeback3_reg_dst;
            wire                                          cam_rmt_update_writeback3_valid;

            wire [                                   6:0] cam_rmt_update_writeback4_reg_dst;
            wire                                          cam_rmt_update_writeback4_valid;

            wire [                                   6:0] cam_rmt_update_writeback5_reg_dst;
            wire                                          cam_rmt_update_writeback5_valid;

            wire [                                   6:0] cam_rmt_update_writeback6_reg_dst;
            wire                                          cam_rmt_update_writeback6_valid;

            wire [                                   6:0] cam_rmt_update_writeback7_reg_dst;
            wire                                          cam_rmt_update_writeback7_valid;

            wire [                                   6:0] cam_rmt_update_commit_new_reg_dst[3:0];
            wire [                                   6:0] cam_rmt_update_commit_old_reg_dst[3:0];
            wire [                                   4:0] cam_rmt_update_commit_arch_reg_dst[3:0];
            wire [                                   3:0] cam_rmt_update_commit_valid;

            wire                                          cam_rmt_flush;

            wire                                          cam_rmt_predict_flush;
            wire [                                   4:0] cam_rmt_predict_flush_bid;
            wire [                                   4:0] cam_rmt_head_bid;







            wire                                          issue_clear;
            wire                                          issue_queue_stall;
            wire                                          issue_queue_extra_stall;
            wire                                          alu_issue_queue_flush;

            wire [3:0] alu_issue_queue_dispatch_valid;
            wire [3:0] alu_issue_queue_dispatch_ready;
            wire [             `ISSUE_QUEUE_OP_WIDTH-1:0] alu_issue_queue_dispatch_opcode [3:0];
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_dispatch_pdest [3:0];
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_dispatch_psrc0 [3:0];
            wire [3:0] alu_issue_queue_dispatch_prdy0 ;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_dispatch_psrc1 [3:0];
            wire [3:0] alu_issue_queue_dispatch_prdy1 ;
            wire [            `ISSUE_QUEUE_IMM_WIDTH-1:0] alu_issue_queue_dispatch_imm [3:0];
            wire [                                   4:0] alu_issue_queue_dispatch_bid [3:0];
            wire [                   `ROB_ID_WIDTH-1 : 0] alu_issue_queue_dispatch_rob_id [3:0];

            wire                                          alu_issue_queue_bypass1_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass1_dst;
            wire                                          alu_issue_queue_bypass2_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass2_dst;

            wire                                          alu_issue_queue_bypass3_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass3_dst;
            wire                                          alu_issue_queue_bypass4_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass4_dst;
            wire                                          alu_issue_queue_bypass5_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass5_dst;
            wire                                          alu_issue_queue_bypass6_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass6_dst;
            wire                                          alu_issue_queue_bypass7_valid;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_bypass7_dst;

            wire                                          alu_issue_queue_issue_valid;
            wire                                          alu_issue_queue_issue_ready;
            wire [             `ISSUE_QUEUE_OP_WIDTH-1:0] alu_issue_queue_issue_opcode;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_issue_pdest;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_issue_psrc0;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_issue_psrc1;
            wire [            `ISSUE_QUEUE_IMM_WIDTH-1:0] alu_issue_queue_issue_imm;
            wire [                                   4:0] alu_issue_queue_issue_bid;
            wire [                   `ROB_ID_WIDTH-1 : 0] alu_issue_queue_issue_rob_id;

            wire                                          alu_issue_queue_extra_issue_valid;
            wire                                          alu_issue_queue_extra_issue_ready;
            wire [             `ISSUE_QUEUE_OP_WIDTH-1:0] alu_issue_queue_extra_issue_opcode;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_extra_issue_pdest;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_extra_issue_psrc0;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_extra_issue_psrc1;
            wire [            `ISSUE_QUEUE_IMM_WIDTH-1:0] alu_issue_queue_extra_issue_imm;
            wire [                                   4:0] alu_issue_queue_extra_issue_bid;
            wire [                   `ROB_ID_WIDTH-1 : 0] alu_issue_queue_extra_issue_rob_id;

            wire                                          alu_issue_queue_full;
            wire                                          alu_issue_queue_empty;
            wire [          `ISSUE_QUEUE_COUNT_WIDTH-1:0] alu_issue_queue_count;

            wire                                          alu_issue_queue_predict_flush;
            wire [                                   4:0] alu_issue_queue_predict_flush_bid;
            wire [                                   4:0] alu_issue_queue_head_bid;


            wire                                          read_clear;
            wire                                          issue_read_reg_stall;
            wire                                          issue_read_reg_pre_stall;

            wire                                          issue_read_reg_in_valid;
            wire [                                   6:0] issue_read_reg_in_phy_reg_src1;
            wire [                                   6:0] issue_read_reg_in_phy_reg_src2;
            wire                                          issue_read_reg_in_regfile_we;
            wire [                                   4:0] issue_read_reg_in_alu_op;
            wire                                          issue_read_reg_in_sel_imm;
            wire [                                  31:0] issue_read_reg_in_extended_imm;
            wire [                                   6:0] issue_read_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] issue_read_reg_in_rob_id;
            wire [                                   4:0] issue_read_reg_in_bid;


            wire                                          issue_read_reg_out_valid;
            wire [                                   6:0] issue_read_reg_out_phy_reg_src1;
            wire [                                   6:0] issue_read_reg_out_phy_reg_src2;
            wire                                          issue_read_reg_out_regfile_we;
            wire [                                   4:0] issue_read_reg_out_alu_op;
            wire                                          issue_read_reg_out_sel_imm;
            wire [                                  31:0] issue_read_reg_out_extended_imm;
            wire [                                   6:0] issue_read_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] issue_read_reg_out_rob_id;
            wire [                                   4:0] issue_read_reg_out_bid;




            wire                                          exec_clear;
            wire                                          read_exec_reg_stall;
            wire                                          read_exec_reg_pre_stall;

            wire                                          read_exec_reg_in_valid;
            wire [                                  31:0] read_exec_reg_in_physical_regfile_rdata1;
            wire [                                  31:0] read_exec_reg_in_physical_regfile_rdata2;
            wire                                          read_exec_reg_in_regfile_we;
            wire [                                   4:0] read_exec_reg_in_alu_op;
            wire                                          read_exec_reg_in_sel_imm;
            wire [                                  31:0] read_exec_reg_in_extended_imm;
            wire [                                   6:0] read_exec_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] read_exec_reg_in_rob_id;
            wire [                                   4:0] read_exec_reg_in_bid;


            wire                                          read_exec_reg_out_valid;
            wire [                                  31:0] read_exec_reg_out_physical_regfile_rdata1;
            wire [                                  31:0] read_exec_reg_out_physical_regfile_rdata2;
            wire                                          read_exec_reg_out_regfile_we;
            wire [                                   4:0] read_exec_reg_out_alu_op;
            wire                                          read_exec_reg_out_sel_imm;
            wire [                                  31:0] read_exec_reg_out_extended_imm;
            wire [                                   6:0] read_exec_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] read_exec_reg_out_rob_id;
            wire [                                   4:0] read_exec_reg_out_bid;


            wire [                                  31:0] alu_operand1;
            wire [                                  31:0] alu_operand2;
            wire [                                   4:0] alu_op;
            wire [                                  31:0] alu_result;


            wire                                          writeback_clear;
            wire                                          exec_writeback_reg_stall;
            wire                                          exec_writeback_reg_pre_stall;

            wire                                          exec_writeback_reg_in_valid;
            wire                                          exec_writeback_reg_in_regfile_we;
            wire [                                  31:0] exec_writeback_reg_in_result;
            wire [                                   6:0] exec_writeback_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] exec_writeback_reg_in_rob_id;
            wire [                                   4:0] exec_writeback_reg_in_bid;


            wire                                          exec_writeback_reg_out_valid;
            wire                                          exec_writeback_reg_out_regfile_we;
            wire [                                  31:0] exec_writeback_reg_out_result;
            wire [                                   6:0] exec_writeback_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] exec_writeback_reg_out_rob_id;
            wire [                                   4:0] exec_writeback_reg_out_bid;

            //********************************************
            //extra_issue
            //********************************************

            wire                                          extra_read_clear;
            wire                                          extra_issue_read_reg_stall;
            wire                                          extra_issue_read_reg_pre_stall;

            wire                                          extra_issue_read_reg_in_valid;
            wire [                                   6:0] extra_issue_read_reg_in_phy_reg_src1;
            wire [                                   6:0] extra_issue_read_reg_in_phy_reg_src2;
            wire                                          extra_issue_read_reg_in_regfile_we;
            wire [                                   4:0] extra_issue_read_reg_in_alu_op;
            wire                                          extra_issue_read_reg_in_sel_imm;
            wire [                                  31:0] extra_issue_read_reg_in_extended_imm;
            wire [                                   6:0] extra_issue_read_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] extra_issue_read_reg_in_rob_id;
            wire [                                   4:0] extra_issue_read_reg_in_bid;


            wire                                          extra_issue_read_reg_out_valid;
            wire [                                   6:0] extra_issue_read_reg_out_phy_reg_src1;
            wire [                                   6:0] extra_issue_read_reg_out_phy_reg_src2;
            wire                                          extra_issue_read_reg_out_regfile_we;
            wire [                                   4:0] extra_issue_read_reg_out_alu_op;
            wire                                          extra_issue_read_reg_out_sel_imm;
            wire [                                  31:0] extra_issue_read_reg_out_extended_imm;
            wire [                                   6:0] extra_issue_read_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] extra_issue_read_reg_out_rob_id;
            wire [                                   4:0] extra_issue_read_reg_out_bid;




            wire                                          extra_exec_clear;
            wire                                          extra_read_exec_reg_stall;
            wire                                          extra_read_exec_reg_pre_stall;

            wire                                          extra_read_exec_reg_in_valid;
            wire [                                  31:0] extra_read_exec_reg_in_physical_regfile_rdata1;
            wire [                                  31:0] extra_read_exec_reg_in_physical_regfile_rdata2;
            wire                                          extra_read_exec_reg_in_regfile_we;
            wire [                                   4:0] extra_read_exec_reg_in_alu_op;
            wire                                          extra_read_exec_reg_in_sel_imm;
            wire [                                  31:0] extra_read_exec_reg_in_extended_imm;
            wire [                                   6:0] extra_read_exec_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] extra_read_exec_reg_in_rob_id;
            wire [                                   4:0] extra_read_exec_reg_in_bid;


            wire                                          extra_read_exec_reg_out_valid;
            wire [                                  31:0] extra_read_exec_reg_out_physical_regfile_rdata1;
            wire [                                  31:0] extra_read_exec_reg_out_physical_regfile_rdata2;
            wire                                          extra_read_exec_reg_out_regfile_we;
            wire [                                   4:0] extra_read_exec_reg_out_alu_op;
            wire                                          extra_read_exec_reg_out_sel_imm;
            wire [                                  31:0] extra_read_exec_reg_out_extended_imm;
            wire [                                   6:0] extra_read_exec_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] extra_read_exec_reg_out_rob_id;
            wire [                                   4:0] extra_read_exec_reg_out_bid;


            wire [                                  31:0] extra_alu_operand1;
            wire [                                  31:0] extra_alu_operand2;
            wire [                                   4:0] extra_alu_op;
            wire [                                  31:0] extra_alu_result;


            wire                                          extra_writeback_clear;
            wire                                          extra_exec_writeback_reg_stall;
            wire                                          extra_exec_writeback_reg_pre_stall;

            wire                                          extra_exec_writeback_reg_in_valid;
            wire                                          extra_exec_writeback_reg_in_regfile_we;
            wire [                                  31:0] extra_exec_writeback_reg_in_result;
            wire [                                   6:0] extra_exec_writeback_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] extra_exec_writeback_reg_in_rob_id;
            wire [                                   4:0] extra_exec_writeback_reg_in_bid;


            wire                                          extra_exec_writeback_reg_out_valid;
            wire                                          extra_exec_writeback_reg_out_regfile_we;
            wire [                                  31:0] extra_exec_writeback_reg_out_result;
            wire [                                   6:0] extra_exec_writeback_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] extra_exec_writeback_reg_out_rob_id;
            wire [                                   4:0] extra_exec_writeback_reg_out_bid;


            //********************************************
            //extra_issu_end
            //********************************************


            wire                                          alu_bypass1_valid;
            wire                                          alu_bypass2_valid;
            wire                                          alu_bypass3_valid;
            wire                                          alu_bypass4_valid;

            wire [                                   6:0] alu_bypass1_dst;
            wire [                                   6:0] alu_bypass2_dst;
            wire [                                   6:0] alu_bypass3_dst;
            wire [                                   6:0] alu_bypass4_dst;

            wire [                                  31:0] alu_bypass1_data;
            wire [                                  31:0] alu_bypass2_data;
            wire [                                  31:0] alu_bypass3_data;
            wire [                                  31:0] alu_bypass4_data;


            wire [                                  31:0] alu_bypass_update_rdata1;
            wire [                                  31:0] alu_bypass_update_rdata2;
            wire [                                  31:0] extra_alu_bypass_update_rdata1;
            wire [                                  31:0] extra_alu_bypass_update_rdata2;






            wire                                          lsu_issue_queue_flush;
            wire                                          lsu_issue_queue_stall;
            wire                                          lsu_issue_clear;

            wire [3:0] lsu_issue_queue_dispatch_valid;
            wire [3:0] lsu_issue_queue_dispatch_ready;
            wire [         `LSU_ISSUE_QUEUE_OP_WIDTH-1:0] lsu_issue_queue_dispatch_opcode [3:0];
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_dispatch_pdest [3:0];
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_dispatch_psrc0 [3:0];
            wire [3:0]lsu_issue_queue_dispatch_prdy0 ;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_dispatch_psrc1 [3:0];
            wire [3:0]lsu_issue_queue_dispatch_prdy1 ;
            wire [        `LSU_ISSUE_QUEUE_IMM_WIDTH-1:0] lsu_issue_queue_dispatch_imm [3:0];
            wire [                     `ROB_ID_WIDTH-1:0] lsu_issue_queue_dispatch_rob_id [3:0];

            wire                                          lsu_issue_queue_bypass1_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass1_dst;
            wire                                          lsu_issue_queue_bypass2_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass2_dst;
            wire                                          lsu_issue_queue_bypass3_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass3_dst;
            wire                                          lsu_issue_queue_bypass4_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass4_dst;
            wire                                          lsu_issue_queue_bypass5_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass5_dst;
            wire                                          lsu_issue_queue_bypass6_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass6_dst;
            wire                                          lsu_issue_queue_bypass7_valid;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_bypass7_dst;

            wire                                          lsu_issue_queue_issue_valid;
            wire                                          lsu_issue_queue_issue_ready;
            wire [         `LSU_ISSUE_QUEUE_OP_WIDTH-1:0] lsu_issue_queue_issue_opcode;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_issue_pdest;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_issue_psrc0;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_issue_psrc1;
            wire [        `LSU_ISSUE_QUEUE_IMM_WIDTH-1:0] lsu_issue_queue_issue_imm;
            wire [                     `ROB_ID_WIDTH-1:0] lsu_issue_queue_issue_rob_id;

            wire                                          lsu_issue_queue_full;
            wire                                          lsu_issue_queue_empty;
            wire [      `LSU_ISSUE_QUEUE_COUNT_WIDTH-1:0] lsu_issue_queue_count;


            wire [                                   4:0] lsu_issue_queue_dispatch_bid [3:0];
            wire [                                   4:0] lsu_issue_queue_issue_bid;
            wire                                          lsu_issue_queue_predict_flush;
            wire [                                   4:0] lsu_issue_queue_predict_flush_bid;
            wire [                                   4:0] lsu_issue_queue_head_bid;

            wire                                          lsu_read_clear;
            wire                                          lsu_issue_read_reg_stall;
            wire                                          lsu_issue_read_reg_pre_stall;

            wire                                          lsu_issue_read_reg_in_valid;
            wire [                                   6:0] lsu_issue_read_reg_in_phy_reg_src1;
            wire [                                   6:0] lsu_issue_read_reg_in_phy_reg_src2;
            wire [                                   6:0] lsu_issue_read_reg_in_phy_reg_dst;
            wire [                                  31:0] lsu_issue_read_reg_in_extended_imm;
            wire                                          lsu_issue_read_reg_in_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_issue_read_reg_in_rob_id;
            wire [                                   2:0] lsu_issue_read_reg_in_sel_load_store_len;
            wire [                                   4:0] lsu_issue_read_reg_in_bid;
            wire lsu_issue_read_reg_in_is_cacop;

            wire                                          lsu_issue_read_reg_out_valid;
            wire [                                   6:0] lsu_issue_read_reg_out_phy_reg_src1;
            wire [                                   6:0] lsu_issue_read_reg_out_phy_reg_src2;
            wire [                                   6:0] lsu_issue_read_reg_out_phy_reg_dst;
            wire [                                  31:0] lsu_issue_read_reg_out_extended_imm;
            wire                                          lsu_issue_read_reg_out_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_issue_read_reg_out_rob_id;
            wire [                                   2:0] lsu_issue_read_reg_out_sel_load_store_len;
            wire [                                   4:0] lsu_issue_read_reg_out_bid;
            wire lsu_issue_read_reg_out_is_cacop;

            wire                                          lsu_exec_clear;
            wire                                          lsu_read_exec_reg_stall;
            wire                                          lsu_read_exec_reg_pre_stall;

            wire                                          lsu_read_exec_reg_in_valid;
            wire [                                   6:0] lsu_read_exec_reg_in_phy_reg_src2;
            wire                                          lsu_read_exec_reg_in_phy_reg_src2_rdy;
            wire [                                  31:0] lsu_read_exec_reg_in_phy_reg_rdata1;
            wire [                                  31:0] lsu_read_exec_reg_in_phy_reg_rdata2;
            wire [                                   6:0] lsu_read_exec_reg_in_phy_reg_dst;
            wire [                                  31:0] lsu_read_exec_reg_in_extended_imm;
            wire                                          lsu_read_exec_reg_in_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_read_exec_reg_in_rob_id;
            wire [                                   4:0] lsu_read_exec_reg_in_bid;
            wire [                                   2:0] lsu_read_exec_reg_in_sel_load_store_len;
            wire lsu_read_exec_reg_in_is_cacop;


            wire                                          lsu_read_exec_reg_out_valid;
            wire [                                   6:0] lsu_read_exec_reg_out_phy_reg_src2;
            wire                                          lsu_read_exec_reg_out_phy_reg_src2_rdy;
            wire [                                  31:0] lsu_read_exec_reg_out_phy_reg_rdata1;
            wire [                                  31:0] lsu_read_exec_reg_out_phy_reg_rdata2;
            wire [                                   6:0] lsu_read_exec_reg_out_phy_reg_dst;
            wire [                                  31:0] lsu_read_exec_reg_out_extended_imm;
            wire                                          lsu_read_exec_reg_out_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_read_exec_reg_out_rob_id;
            wire [                                   4:0] lsu_read_exec_reg_out_bid;
            wire [                                   2:0] lsu_read_exec_reg_out_sel_load_store_len;
            wire lsu_read_exec_reg_out_is_cacop;

            wire [                                   7:1] lsu_read_exec_store_data_bypass_hit;
            wire                                          lsu_read_exec_store_data_bypass_valid;
            wire [                                  31:0] lsu_read_exec_store_data_bypass_data;
            wire                                          lsu_read_exec_store_data_prdy_next;
            wire [                                  31:0] lsu_read_exec_store_data_next;


            wire [                                  31:0] lsu_exec_address;


            wire [                                   1:0] select_store_addr;
            wire [                                  31:0] select_store_data;
            wire [                                   2:0] select_store_sel_load_store_len;

            wire [                                   3:0] select_store_wstrb;
            wire [                                  31:0] select_store_result;


            wire                                          lsu_exec_mem1_state_in_is_exception;
            wire                                          lsu_exec_mem1_state_in_is_ale;
            wire                                          lsu_exec_mem1_state_in_is_tlbr;
            wire                                          lsu_exec_mem1_state_in_is_data_tlbr;
            wire                                          lsu_exec_mem1_state_in_is_data_pil;
            wire                                          lsu_exec_mem1_state_in_is_data_pis;
            wire                                          lsu_exec_mem1_state_in_is_data_ppi;
            wire                                          lsu_exec_mem1_state_in_is_data_pme;
            wire [                                   1:0] lsu_exec_mem1_state_in_mmu_data_mat;

            wire                                          lsu_exec_mem1_state_out_is_exception;
            wire                                          lsu_exec_mem1_state_out_is_ale;
            wire                                          lsu_exec_mem1_state_out_is_tlbr;
            wire                                          lsu_exec_mem1_state_out_is_data_tlbr;
            wire                                          lsu_exec_mem1_state_out_is_data_pil;
            wire                                          lsu_exec_mem1_state_out_is_data_pis;
            wire                                          lsu_exec_mem1_state_out_is_data_ppi;
            wire                                          lsu_exec_mem1_state_out_is_data_pme;
            wire [                                   1:0] lsu_exec_mem1_state_out_mmu_data_mat;




            wire                                          lsu_mem1_clear;
            wire                                          lsu_exec_mem1_reg_stall;
            wire                                          lsu_exec_mem1_reg_pre_stall;

            wire                                          lsu_exec_mem1_reg_in_valid;
            wire [                                   6:0] lsu_exec_mem1_reg_in_phy_reg_dst;
            wire                                          lsu_exec_mem1_reg_in_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_exec_mem1_reg_in_rob_id;
            wire [                                   2:0] lsu_exec_mem1_reg_in_sel_load_store_len;
            wire [                                   3:0] lsu_exec_mem1_reg_in_wstrb;
            wire [                                  31:0] lsu_exec_mem1_reg_in_address;
            wire [                                  31:0] lsu_exec_mem1_reg_in_store_data;
            wire [                                   6:0] lsu_exec_mem1_reg_in_store_data_psrc;
            wire                                          lsu_exec_mem1_reg_in_store_data_prdy;
            wire [                                  31:0] lsu_exec_mem1_reg_in_store_data_raw;
            wire [                                   4:0] lsu_exec_mem1_reg_in_bid;
            wire                                          lsu_exec_mem1_reg_in_store_ctrl;
            wire [31:0] lsu_exec_mem1_reg_in_address_pa;
            wire lsu_exec_mem1_reg_in_is_cacop;


            wire                                          lsu_exec_mem1_reg_out_valid;
            wire [                                   6:0] lsu_exec_mem1_reg_out_phy_reg_dst;
            wire                                          lsu_exec_mem1_reg_out_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_exec_mem1_reg_out_rob_id;
            wire [                                   2:0] lsu_exec_mem1_reg_out_sel_load_store_len;
            wire [                                   3:0] lsu_exec_mem1_reg_out_wstrb;
            wire [                                  31:0] lsu_exec_mem1_reg_out_address;
            wire [                                  31:0] lsu_exec_mem1_reg_out_store_data;
            wire [                                   6:0] lsu_exec_mem1_reg_out_store_data_psrc;
            wire                                          lsu_exec_mem1_reg_out_store_data_prdy;
            wire [                                  31:0] lsu_exec_mem1_reg_out_store_data_raw;
            wire [                                   4:0] lsu_exec_mem1_reg_out_bid;
            wire                                          lsu_exec_mem1_reg_out_store_ctrl;
            wire [31:0] lsu_exec_mem1_reg_out_address_pa;
            wire lsu_exec_mem1_reg_out_is_cacop;

            wire [                                   7:1] lsu_exec_mem1_store_data_bypass_hit;
            wire                                          lsu_exec_mem1_store_data_bypass_valid;
            wire [                                  31:0] lsu_exec_mem1_store_data_bypass_data;
            wire                                          lsu_exec_mem1_store_data_prdy_next;
            wire [                                  31:0] lsu_exec_mem1_store_data_next;
            wire [                                   3:0] store_completion_wstrb;
            wire [                                  31:0] store_completion_data;




            localparam integer LQSQ_RESERVED_WIDTH = 48;
            localparam integer LQSQ_VADDR_LSB      = 0;
            localparam integer LQSQ_VADDR_MSB      = 31;
            localparam integer LQSQ_LEN_LSB        = 32;
            localparam integer LQSQ_LEN_MSB        = 34;
            localparam integer LQSQ_ROB_LSB        = 35;
            localparam integer LQSQ_ROB_MSB        = 40;
            localparam integer LQSQ_PDEST_LSB      = 41;
            localparam integer LQSQ_PDEST_MSB      = 47;

            wire                                          lqsq_in_valid;
            wire                                          lqsq_in_ready;
            wire                                          lqsq_in_fire;
            wire                                          lqsq_in_is_store_or_not_load;
            wire                                          lqsq_in_mat;
            wire [                                  31:0] lqsq_in_address;
            wire [                                   3:0] lqsq_in_wstrb;
            wire [                                   4:0] lqsq_in_bid;
            wire [              LQSQ_RESERVED_WIDTH-1:0] lqsq_in_reserved;
            wire                                          lqsq_in_prdy;
            wire [                                   6:0] lqsq_in_psrc;
            wire [                                  31:0] lqsq_in_data;

            wire                                          lqsq_out_valid;
            wire                                          lqsq_out_ready;
            wire                                          lqsq_out_fire;
            wire                                          lqsq_out_is_store_or_not_load;
            wire                                          lqsq_out_mat;
            wire [                                  31:0] lqsq_out_address;
            wire [                                  31:0] lqsq_out_data;
            wire [                                   3:0] lqsq_out_wstrb;
            wire [                                  31:0] lqsq_store_out_data_formatted;
            wire [                                   3:0] lqsq_store_out_wstrb_formatted;
            wire [                                   3:0] lqsq_out_load_data_bit_mask;
            wire [                                   4:0] lqsq_out_bid;
            wire [              LQSQ_RESERVED_WIDTH-1:0] lqsq_out_reserved;
            wire [                                   7:0] lqsq_sq_entry_valid;
            wire [                                   7:0] lqsq_sq_entry_next_prdy;
            wire [                                 255:0] lqsq_sq_entry_next_data_flat;
            wire [    8*LQSQ_RESERVED_WIDTH-1:0] lqsq_sq_entry_reserved_flat;
            wire [                                   3:0] store_queue_uncommitted_count;
            wire [                                   2:0] store_queue_commit_count;
            wire                                          store_queue_drain_valid;
            wire [                                   1:0] store_queue_drain_mat;

            wire                                          lsu_mem1_is_ordinary_memory;
            wire                                          lsu_mem1_is_ordinary_load;
            wire                                          lsu_mem1_is_ordinary_store;
            wire                                          lsu_mem1_direct_valid;
            wire                                          lsu_mem1_direct_cc_busy_block;
            wire                                          lqsq_store_out_selected;
            wire                                          lsu_mem1_direct_selected;
            wire                                          lqsq_load_out_selected;
            wire                                          store_completion_selected;
            wire                                          lqsq_store_out_fire;
            wire                                          lsu_mem1_direct_fire;
            wire                                          lqsq_load_out_fire;
            wire                                          store_completion_fire;
            wire                                          lsu_mem1_current_fire;

            wire sel_store_stall;


            wire                                          lsu_mem1_mem2_state_in_is_exception;
            wire                                          lsu_mem1_mem2_state_in_is_ale;
            wire                                          lsu_mem1_mem2_state_in_is_tlbr;
            wire                                          lsu_mem1_mem2_state_in_is_data_tlbr;
            wire                                          lsu_mem1_mem2_state_in_is_data_pil;
            wire                                          lsu_mem1_mem2_state_in_is_data_pis;
            wire                                          lsu_mem1_mem2_state_in_is_data_ppi;
            wire                                          lsu_mem1_mem2_state_in_is_data_pme;
            wire [                                   1:0] lsu_mem1_mem2_state_in_mmu_data_mat;

            wire                                          lsu_mem1_mem2_state_out_is_exception;
            wire                                          lsu_mem1_mem2_state_out_is_ale;
            wire                                          lsu_mem1_mem2_state_out_is_tlbr;
            wire                                          lsu_mem1_mem2_state_out_is_data_tlbr;
            wire                                          lsu_mem1_mem2_state_out_is_data_pil;
            wire                                          lsu_mem1_mem2_state_out_is_data_pis;
            wire                                          lsu_mem1_mem2_state_out_is_data_ppi;
            wire                                          lsu_mem1_mem2_state_out_is_data_pme;
            wire [                                   1:0] lsu_mem1_mem2_state_out_mmu_data_mat;




            wire                                          lsu_mem2_clear;
            wire                                          lsu_mem1_mem2_reg_stall;
            wire                                          lsu_mem1_mem2_reg_pre_stall;

            wire                                          lsu_mem1_mem2_reg_in_valid;
            wire [                                   6:0] lsu_mem1_mem2_reg_in_phy_reg_dst;
            wire                                          lsu_mem1_mem2_reg_in_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_mem1_mem2_reg_in_rob_id;
            wire [                                   2:0] lsu_mem1_mem2_reg_in_sel_load_store_len;
            wire [                                   3:0] lsu_mem1_mem2_reg_in_wstrb;
            wire [                                  31:0] lsu_mem1_mem2_reg_in_address;
            wire [                                  31:0] lsu_mem1_mem2_reg_in_store_data;
            wire [                                  31:0] lsu_mem1_mem2_reg_in_load_data;
            wire [                                   3:0] lsu_mem1_mem2_reg_in_load_wstrb;
            wire [                                   4:0] lsu_mem1_mem2_reg_in_bid;
            wire                                          lsu_mem1_mem2_reg_in_store_ctrl;
            wire [31:0] lsu_mem1_mem2_reg_in_address_pa;
            wire lsu_mem1_mem2_reg_in_is_cacop;


            wire                                          lsu_mem1_mem2_reg_out_valid;
            wire [                                   6:0] lsu_mem1_mem2_reg_out_phy_reg_dst;
            wire                                          lsu_mem1_mem2_reg_out_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_mem1_mem2_reg_out_rob_id;
            wire [                                   2:0] lsu_mem1_mem2_reg_out_sel_load_store_len;
            wire [                                   3:0] lsu_mem1_mem2_reg_out_wstrb;
            wire [                                  31:0] lsu_mem1_mem2_reg_out_address;
            wire [                                  31:0] lsu_mem1_mem2_reg_out_store_data;
            wire [                                  31:0] lsu_mem1_mem2_reg_out_load_data;
            wire [                                   3:0] lsu_mem1_mem2_reg_out_load_wstrb;
            wire [                                   4:0] lsu_mem1_mem2_reg_out_bid;
            wire                                          lsu_mem1_mem2_reg_out_store_ctrl;
            wire [31:0] lsu_mem1_mem2_reg_out_address_pa;
            wire lsu_mem1_mem2_reg_out_is_cacop;

            wire lsu_mem2_load_miss;


            wire [                                   1:0] select_load_addr;
            wire [                                  31:0] select_load_data;
            wire [                                   2:0] select_load_sel_load_store_len;
            wire [                                  31:0] select_load_result;


            wire                                          lsu_mem2_writeback_state_in_is_exception;
            wire                                          lsu_mem2_writeback_state_in_is_ale;
            wire                                          lsu_mem2_writeback_state_in_is_tlbr;
            wire                                          lsu_mem2_writeback_state_in_is_data_tlbr;
            wire                                          lsu_mem2_writeback_state_in_is_data_pil;
            wire                                          lsu_mem2_writeback_state_in_is_data_pis;
            wire                                          lsu_mem2_writeback_state_in_is_data_ppi;
            wire                                          lsu_mem2_writeback_state_in_is_data_pme;
            wire [                                   1:0] lsu_mem2_writeback_state_in_mmu_data_mat;

            wire                                          lsu_mem2_writeback_state_out_is_exception;
            wire                                          lsu_mem2_writeback_state_out_is_ale;
            wire                                          lsu_mem2_writeback_state_out_is_tlbr;
            wire                                          lsu_mem2_writeback_state_out_is_data_tlbr;
            wire                                          lsu_mem2_writeback_state_out_is_data_pil;
            wire                                          lsu_mem2_writeback_state_out_is_data_pis;
            wire                                          lsu_mem2_writeback_state_out_is_data_ppi;
            wire                                          lsu_mem2_writeback_state_out_is_data_pme;
            wire [                                   1:0] lsu_mem2_writeback_state_out_mmu_data_mat;



            wire                                          lsu_writeback_clear;
            wire                                          lsu_mem2_writeback_reg_stall;
            wire                                          lsu_mem2_writeback_reg_pre_stall;

            wire                                          lsu_mem2_writeback_reg_in_valid;
            wire [                                   6:0] lsu_mem2_writeback_reg_in_phy_reg_dst;
            wire                                          lsu_mem2_writeback_reg_in_is_store_or_not_load;
            wire [                                  31:0] lsu_mem2_writeback_reg_in_result;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_mem2_writeback_reg_in_rob_id;
            wire [                                   4:0] lsu_mem2_writeback_reg_in_bid;
            wire                                          lsu_mem2_writeback_reg_in_store_ctrl;
            wire [                                  31:0] lsu_mem2_writeback_reg_in_vaddr;
            wire [31:0] lsu_mem2_writeback_reg_in_paddr;
            wire lsu_mem2_writeback_reg_in_is_cacop;



            wire                                          lsu_mem2_writeback_reg_out_valid;
            wire [                                   6:0] lsu_mem2_writeback_reg_out_phy_reg_dst;
            wire                                          lsu_mem2_writeback_reg_out_is_store_or_not_load;
            wire [                                  31:0] lsu_mem2_writeback_reg_out_result;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_mem2_writeback_reg_out_rob_id;
            wire [                                   4:0] lsu_mem2_writeback_reg_out_bid;
            wire                                          lsu_mem2_writeback_reg_out_store_ctrl;
            wire [                                  31:0] lsu_mem2_writeback_reg_out_vaddr;
            wire [31:0] lsu_mem2_writeback_reg_out_paddr;
            wire lsu_mem2_writeback_reg_out_is_cacop;



            wire                                          md_issue_queue_flush;

            wire                                          md_issue_queue_div_stall;
            wire                                          md_issue_queue_mul_stall;
            wire                                          md_issue_queue_bru_stall;

            wire                                          md_issue_clear;

            wire [3:0] md_issue_queue_dispatch_valid;
            wire [3:0] md_issue_queue_dispatch_ready;
            wire [          `MD_ISSUE_QUEUE_OP_WIDTH-1:0] md_issue_queue_dispatch_opcode [3:0];
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_dispatch_pdest [3:0];
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_dispatch_psrc0 [3:0];
            wire [3:0]md_issue_queue_dispatch_prdy0;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_dispatch_psrc1 [3:0];
            wire [3:0]md_issue_queue_dispatch_prdy1;
            wire [                                   4:0] md_issue_queue_dispatch_bid [3:0];
            wire [                     `ROB_ID_WIDTH-1:0] md_issue_queue_dispatch_rob_id [3:0];
            wire [                                   2:0] md_issue_queue_dispatch_inst_type [3:0];

            wire                                          md_issue_queue_bypass1_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass1_dst;
            wire                                          md_issue_queue_bypass2_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass2_dst;
            wire                                          md_issue_queue_bypass3_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass3_dst;
            wire                                          md_issue_queue_bypass4_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass4_dst;
            wire                                          md_issue_queue_bypass5_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass5_dst;
            wire                                          md_issue_queue_bypass6_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass6_dst;
            wire                                          md_issue_queue_bypass7_valid;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bypass7_dst;


            wire                                          md_issue_queue_div_issue_valid;
            wire                                          md_issue_queue_div_issue_ready;
            wire [          `MD_ISSUE_QUEUE_OP_WIDTH-1:0] md_issue_queue_div_issue_opcode;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_div_issue_pdest;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_div_issue_psrc0;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_div_issue_psrc1;
            wire [                                   4:0] md_issue_queue_div_issue_bid;
            wire [                     `ROB_ID_WIDTH-1:0] md_issue_queue_div_issue_rob_id;

            wire                                          md_issue_queue_mul_issue_valid;
            wire                                          md_issue_queue_mul_issue_ready;
            wire [          `MD_ISSUE_QUEUE_OP_WIDTH-1:0] md_issue_queue_mul_issue_opcode;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_mul_issue_pdest;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_mul_issue_psrc0;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_mul_issue_psrc1;
            wire [                                   4:0] md_issue_queue_mul_issue_bid;
            wire [                     `ROB_ID_WIDTH-1:0] md_issue_queue_mul_issue_rob_id;

            wire                                          md_issue_queue_bru_issue_valid;
            wire                                          md_issue_queue_bru_issue_ready;
            wire [          `MD_ISSUE_QUEUE_OP_WIDTH-1:0] md_issue_queue_bru_issue_opcode;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bru_issue_pdest;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bru_issue_psrc0;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_bru_issue_psrc1;
            wire [                                   4:0] md_issue_queue_bru_issue_bid;
            wire [                     `ROB_ID_WIDTH-1:0] md_issue_queue_bru_issue_rob_id;

            wire                                          md_issue_queue_full;
            wire                                          md_issue_queue_empty;
            wire [       `MD_ISSUE_QUEUE_COUNT_WIDTH-1:0] md_issue_queue_count;

            wire                                          md_issue_queue_predict_flush;
            wire [                                   4:0] md_issue_queue_predict_flush_bid;
            wire [                                   4:0] md_issue_queue_head_bid;

            wire                                          md_div_read_clear;
            wire                                          md_div_issue_read_reg_stall;  //
            wire                                          md_div_issue_read_reg_pre_stall;

            wire                                          md_div_issue_read_reg_in_valid;
            wire [                                   6:0] md_div_issue_read_reg_in_phy_reg_src1;
            wire [                                   6:0] md_div_issue_read_reg_in_phy_reg_src2;
            wire [                                   6:0] md_div_issue_read_reg_in_phy_reg_dst;
            wire [                                   3:0] md_div_issue_read_reg_in_div_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_div_issue_read_reg_in_rob_id;
            wire [                                   4:0] md_div_issue_read_reg_in_bid;

            wire                                          md_div_issue_read_reg_out_valid;
            wire [                                   6:0] md_div_issue_read_reg_out_phy_reg_src1;
            wire [                                   6:0] md_div_issue_read_reg_out_phy_reg_src2;
            wire [                                   6:0] md_div_issue_read_reg_out_phy_reg_dst;
            wire [                                   3:0] md_div_issue_read_reg_out_div_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_div_issue_read_reg_out_rob_id;
            wire [                                   4:0] md_div_issue_read_reg_out_bid;


            wire                                          div_reg_flush;

            wire                                          div_reg_in_valid;
            wire [                                   6:0] div_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] div_reg_in_rob_id;
            wire [                                   3:0] div_reg_in_div_op;
            wire [                                   4:0] div_reg_in_bid;

            wire [                                  31:0] div_reg_operand1;
            wire [                                  31:0] div_reg_operand2;

            wire                                          div_reg_out_valid;
            wire [                                   6:0] div_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] div_reg_out_rob_id;
            wire [                                   3:0] div_reg_out_div_op;
            wire [                                   4:0] div_reg_out_bid;

            wire [                                  31:0] div_reg_out_result;

            wire                                          div_reg_predict_flush;
            wire [                                   4:0] div_reg_head_bid;
            wire [                                   4:0] div_reg_predict_flush_bid;





            wire                                          md_mul_read_clear;
            wire                                          md_mul_issue_read_reg_stall;  //
            wire                                          md_mul_issue_read_reg_pre_stall;

            wire                                          md_mul_issue_read_reg_in_valid;
            wire [                                   6:0] md_mul_issue_read_reg_in_phy_reg_src1;
            wire [                                   6:0] md_mul_issue_read_reg_in_phy_reg_src2;
            wire [                                   6:0] md_mul_issue_read_reg_in_phy_reg_dst;
            wire [                                   2:0] md_mul_issue_read_reg_in_mul_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_mul_issue_read_reg_in_rob_id;
            wire [                                   4:0] md_mul_issue_read_reg_in_bid;

            wire                                          md_mul_issue_read_reg_out_valid;
            wire [                                   6:0] md_mul_issue_read_reg_out_phy_reg_src1;
            wire [                                   6:0] md_mul_issue_read_reg_out_phy_reg_src2;
            wire [                                   6:0] md_mul_issue_read_reg_out_phy_reg_dst;
            wire [                                   2:0] md_mul_issue_read_reg_out_mul_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_mul_issue_read_reg_out_rob_id;
            wire [                                   4:0] md_mul_issue_read_reg_out_bid;



            wire                                          md_clear;
            wire                                          md_reg_stall;
            wire                                          mul_reg_flush;

            wire                                          mul_reg_in_valid;
            wire [                                   6:0] mul_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] mul_reg_in_rob_id;
            wire [                                   2:0] mul_reg_in_mul_op;
            wire [                                   4:0] mul_reg_in_bid;

            wire [                                  31:0] mul_reg_operand1;
            wire [                                  31:0] mul_reg_operand2;


            wire                                          mul_reg_out_valid;
            wire [                                   6:0] mul_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] mul_reg_out_rob_id;
            wire [                                   2:0] mul_reg_out_mul_op;
            wire [                                   4:0] mul_reg_out_bid;

            wire [                                  31:0] mul_reg_out_result;

            wire                                          mul_reg_predict_flush;
            wire [                                   4:0] mul_reg_head_bid;
            wire [                                   4:0] mul_reg_predict_flush_bid;


            wire                                          md_bru_read_clear;
            wire                                          md_bru_issue_read_reg_stall;
            wire                                          md_bru_issue_read_reg_pre_stall;

            wire                                          md_bru_issue_read_reg_in_valid;
            wire [                                   6:0] md_bru_issue_read_reg_in_phy_reg_src1;
            wire [                                   6:0] md_bru_issue_read_reg_in_phy_reg_src2;
            wire [                                   6:0] md_bru_issue_read_reg_in_phy_reg_dst;
            wire [                                   1:0] md_bru_issue_read_reg_in_sel_npc;
            wire [                                   2:0] md_bru_issue_read_reg_in_comparator_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_bru_issue_read_reg_in_rob_id;
            wire [                                   4:0] md_bru_issue_read_reg_in_bid;

            wire                                          md_bru_issue_read_reg_out_valid;
            wire [                                   6:0] md_bru_issue_read_reg_out_phy_reg_src1;
            wire [                                   6:0] md_bru_issue_read_reg_out_phy_reg_src2;
            wire [                                   6:0] md_bru_issue_read_reg_out_phy_reg_dst;
            wire [                                   1:0] md_bru_issue_read_reg_out_sel_npc;
            wire [                                   2:0] md_bru_issue_read_reg_out_comparator_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_bru_issue_read_reg_out_rob_id;
            wire [                                   4:0] md_bru_issue_read_reg_out_bid;


            wire                                          md_bru_clear;  //

            wire                                          md_read_bru_reg_stall;  //
            wire                                          md_read_bru_reg_pre_stall;

            wire                                          md_read_bru_reg_in_valid;
            wire [                                  31:0] md_read_bru_reg_in_physical_regfile_rdata1;
            wire [                                  31:0] md_read_bru_reg_in_physical_regfile_rdata2;
            wire [                                   6:0] md_read_bru_reg_in_phy_reg_dst;
            wire [                                   1:0] md_read_bru_reg_in_sel_npc;
            wire [                                   2:0] md_read_bru_reg_in_comparator_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_read_bru_reg_in_rob_id;
            wire [                                   4:0] md_read_bru_reg_in_bid;

            wire                                          md_read_bru_reg_out_valid;
            wire [                                  31:0] md_read_bru_reg_out_physical_regfile_rdata1;
            wire [                                  31:0] md_read_bru_reg_out_physical_regfile_rdata2;
            wire [                                   6:0] md_read_bru_reg_out_phy_reg_dst;
            wire [                                   1:0] md_read_bru_reg_out_sel_npc;
            wire [                                   2:0] md_read_bru_reg_out_comparator_op;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_read_bru_reg_out_rob_id;
            wire [                                   4:0] md_read_bru_reg_out_bid;


            wire [                                  31:0] bru_pc;
            wire [                                  31:0] bru_predict_target_address;
            wire [                                  31:0] bru_imm;
            wire [                                   1:0] bru_sel_npc;
            wire [                                   2:0] bru_comparator_op;

            wire [                                  31:0] bru_operand1;
            wire [                                  31:0] bru_operand2;

            wire [                                  31:0] bru_correct_target_address;
            wire [                                  31:0] bru_writeback_result;
            wire                                          bru_is_jump;

            wire                                          md_writeback_clear;

            wire                                          md_bru_writeback_reg_stall;
            wire                                          md_bru_writeback_reg_pre_stall;

            wire                                          md_bru_writeback_reg_in_valid;
            wire                                          md_bru_writeback_reg_in_regfile_we;
            wire [                                  31:0] md_bru_writeback_reg_in_result;
            wire [                                  31:0] md_bru_writeback_reg_in_target_address;
            wire                                          md_bru_writeback_reg_in_is_jump;
            wire [                                   6:0] md_bru_writeback_reg_in_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_bru_writeback_reg_in_rob_id;
            wire [                                   4:0] md_bru_writeback_reg_in_bid;

            wire                                          md_bru_writeback_reg_out_valid;
            wire                                          md_bru_writeback_reg_out_regfile_we;
            wire [                                  31:0] md_bru_writeback_reg_out_result;
            wire [                                  31:0] md_bru_writeback_reg_out_target_address;
            wire                                          md_bru_writeback_reg_out_is_jump;
            wire [                                   6:0] md_bru_writeback_reg_out_phy_reg_dst;
            wire [                   `ROB_ID_WIDTH-1 : 0] md_bru_writeback_reg_out_rob_id;
            wire [                                   4:0] md_bru_writeback_reg_out_bid;


            wire                                          fast_issue_queue_flush;
            wire                                          fast_issue_queue_stall;
            wire                                          fast_issue_clear;


            wire [3:0] fast_issue_queue_dispatch_valid;
            wire [3:0] fast_issue_queue_dispatch_ready;
            wire [        `FAST_ISSUE_QUEUE_OP_WIDTH-1:0] fast_issue_queue_dispatch_opcode [3:0];
            wire [       `FAST_ISSUE_QUEUE_TAG_WIDTH-1:0] fast_issue_queue_dispatch_pdest [3:0];
            wire [       `FAST_ISSUE_QUEUE_IMM_WIDTH-1:0] fast_issue_queue_dispatch_imm [3:0];
            wire [                                   4:0] fast_issue_queue_dispatch_bid [3:0];
            wire [                     `ROB_ID_WIDTH-1:0] fast_issue_queue_dispatch_rob_id [3:0];

            wire                                          fast_issue_queue_issue_valid;
            wire                                          fast_issue_queue_issue_ready;
            wire [        `FAST_ISSUE_QUEUE_OP_WIDTH-1:0] fast_issue_queue_issue_opcode;
            wire [       `FAST_ISSUE_QUEUE_TAG_WIDTH-1:0] fast_issue_queue_issue_pdest;
            wire [       `FAST_ISSUE_QUEUE_IMM_WIDTH-1:0] fast_issue_queue_issue_imm;
            wire [                                   4:0] fast_issue_queue_issue_bid;
            wire [                     `ROB_ID_WIDTH-1:0] fast_issue_queue_issue_rob_id;


            wire                                          fast_issue_queue_extra_stall;
            wire                                          fast_issue_queue_extra_issue_valid;
            wire                                          fast_issue_queue_extra_issue_ready;
            wire [        `FAST_ISSUE_QUEUE_OP_WIDTH-1:0] fast_issue_queue_extra_issue_opcode;
            wire [       `FAST_ISSUE_QUEUE_TAG_WIDTH-1:0] fast_issue_queue_extra_issue_pdest;
            wire [       `FAST_ISSUE_QUEUE_IMM_WIDTH-1:0] fast_issue_queue_extra_issue_imm;
            wire [                                   4:0] fast_issue_queue_extra_issue_bid;
            wire [                     `ROB_ID_WIDTH-1:0] fast_issue_queue_extra_issue_rob_id;


            wire                                          fast_issue_queue_full;
            wire                                          fast_issue_queue_empty;
            wire [     `FAST_ISSUE_QUEUE_COUNT_WIDTH-1:0] fast_issue_queue_count;
            wire [     `FAST_ISSUE_QUEUE_COUNT_WIDTH-1:0] fast_issue_queue_res_count;

            wire                                          fast_issue_queue_predict_flush;
            wire [                                   4:0] fast_issue_queue_predict_flush_bid;
            wire [                                   4:0] fast_issue_queue_head_bid;

            wire                                          fast_writeback_clear;
            wire                                          fast_issue_writeback_reg_stall;
            wire                                          fast_issue_writeback_reg_pre_stall;

            wire                                          fast_issue_writeback_reg_in_valid;
            wire [                                   6:0] fast_issue_writeback_reg_in_phy_reg_dst;
            wire [                                  31:0] fast_issue_writeback_reg_in_result;
            wire [                   `ROB_ID_WIDTH-1 : 0] fast_issue_writeback_reg_in_rob_id;
            wire [                                   4:0] fast_issue_writeback_reg_in_bid;

            wire                                          fast_issue_writeback_reg_out_valid;
            wire [                                   6:0] fast_issue_writeback_reg_out_phy_reg_dst;
            wire [                                  31:0] fast_issue_writeback_reg_out_result;
            wire [                   `ROB_ID_WIDTH-1 : 0] fast_issue_writeback_reg_out_rob_id;
            wire [                                   4:0] fast_issue_writeback_reg_out_bid;


            wire                                          sel_fast_extra_issue_writeback_reg;
            wire                                          fast_extra_writeback_clear;
            wire                                          fast_extra_issue_writeback_reg_stall;
            wire                                          fast_extra_issue_writeback_reg_pre_stall;

            wire                                          fast_extra_issue_writeback_reg_in_valid;
            wire [                                   6:0] fast_extra_issue_writeback_reg_in_phy_reg_dst;
            wire [                                  31:0] fast_extra_issue_writeback_reg_in_result;
            wire [                   `ROB_ID_WIDTH-1 : 0] fast_extra_issue_writeback_reg_in_rob_id;
            wire [                                   4:0] fast_extra_issue_writeback_reg_in_bid;

            wire                                          fast_extra_issue_writeback_reg_out_valid;
            wire [                                   6:0] fast_extra_issue_writeback_reg_out_phy_reg_dst;
            wire [                                  31:0] fast_extra_issue_writeback_reg_out_result;
            wire [                   `ROB_ID_WIDTH-1 : 0] fast_extra_issue_writeback_reg_out_rob_id;
            wire [                                   4:0] fast_extra_issue_writeback_reg_out_bid;

            wire                                          privilege_issue_queue_flush;
            wire                                          privilege_issue_queue_stall;
            wire                                          privilege_issue_clear;

            wire privilege_issue_queue_dispatch_valid;
            wire privilege_issue_queue_dispatch_ready;
            wire [   `PRIVILEGE_ISSUE_QUEUE_OP_WIDTH-1:0] privilege_issue_queue_dispatch_opcode;
            wire [  `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH-1:0] privilege_issue_queue_dispatch_pdest;
            wire [  `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH-1:0] privilege_issue_queue_dispatch_psrc0;
            wire [  `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH-1:0] privilege_issue_queue_dispatch_psrc1;
            wire [                                   4:0] privilege_issue_queue_dispatch_bid;
            wire [                     `ROB_ID_WIDTH-1:0] privilege_issue_queue_dispatch_rob_id;

            wire                                          privilege_issue_queue_issue_valid;
            wire                                          privilege_issue_queue_issue_ready;
            wire [   `PRIVILEGE_ISSUE_QUEUE_OP_WIDTH-1:0] privilege_issue_queue_issue_opcode;
            wire [  `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH-1:0] privilege_issue_queue_issue_pdest;
            wire [  `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH-1:0] privilege_issue_queue_issue_psrc0;
            wire [  `PRIVILEGE_ISSUE_QUEUE_TAG_WIDTH-1:0] privilege_issue_queue_issue_psrc1;
            wire [                                   4:0] privilege_issue_queue_issue_bid;
            wire [                     `ROB_ID_WIDTH-1:0] privilege_issue_queue_issue_rob_id;

            wire                                          privilege_issue_queue_full;
            wire                                          privilege_issue_queue_empty;
            wire [`PRIVILEGE_ISSUE_QUEUE_COUNT_WIDTH-1:0] privilege_issue_queue_count;

            wire                                          privilege_issue_queue_predict_flush;
            wire [                                   4:0] privilege_issue_queue_predict_flush_bid;
            wire [                                   4:0] privilege_issue_queue_head_bid;
            wire                                          sel_privilege_issue;



            wire [                                  13:0] privilege_issue_read_reg_in_csr_addr;
            wire                                          privilege_issue_read_reg_in_csr_we;
            wire                                          privilege_issue_read_reg_in_csr_re;
            wire                                          privilege_issue_read_reg_in_sel_csr_wmask;


            wire [                                   4:0] privilege_issue_read_reg_in_invtlb_op;
            wire                                          privilege_issue_read_reg_in_is_inst_tlbsrch;
            wire                                          privilege_issue_read_reg_in_is_inst_tlbrd;
            wire                                          privilege_issue_read_reg_in_is_inst_tlbwr;
            wire                                          privilege_issue_read_reg_in_is_inst_tlbfill;
            wire                                          privilege_issue_read_reg_in_is_inst_invtlb;




            wire [                                  13:0] privilege_issue_read_reg_out_csr_addr;
            wire                                          privilege_issue_read_reg_out_csr_we;
            wire                                          privilege_issue_read_reg_out_csr_re;
            wire                                          privilege_issue_read_reg_out_sel_csr_wmask;


            wire [                                   4:0] privilege_issue_read_reg_out_invtlb_op;
            wire                                          privilege_issue_read_reg_out_is_inst_tlbsrch;
            wire                                          privilege_issue_read_reg_out_is_inst_tlbrd;
            wire                                          privilege_issue_read_reg_out_is_inst_tlbwr;
            wire                                          privilege_issue_read_reg_out_is_inst_tlbfill;
            wire                                          privilege_issue_read_reg_out_is_inst_invtlb;



            wire [                                  13:0] privilege_read_exec_reg_in_csr_addr;
            wire                                          privilege_read_exec_reg_in_csr_we;
            wire                                          privilege_read_exec_reg_in_csr_re;
            wire                                          privilege_read_exec_reg_in_sel_csr_wmask;
            wire [                                  31:0] privilege_read_exec_reg_in_csr_rdata;


            wire [                                   4:0] privilege_read_exec_reg_in_invtlb_op;
            wire                                          privilege_read_exec_reg_in_is_inst_tlbsrch;
            wire                                          privilege_read_exec_reg_in_is_inst_tlbrd;
            wire                                          privilege_read_exec_reg_in_is_inst_tlbwr;
            wire                                          privilege_read_exec_reg_in_is_inst_tlbfill;
            wire                                          privilege_read_exec_reg_in_is_inst_invtlb;

            wire        privilege_read_exec_reg_in_tlbsrch_hit;
            wire        privilege_read_exec_reg_in_tlbrd_hit;
            wire [31:0] privilege_read_exec_reg_in_tlb_w_csr_tlbelo0;
            wire [31:0] privilege_read_exec_reg_in_tlb_w_csr_tlbelo1;
            wire [31:0] privilege_read_exec_reg_in_tlb_w_csr_tlbidx;
            wire [31:0] privilege_read_exec_reg_in_tlb_w_csr_tlbehi;
            wire [31:0] privilege_read_exec_reg_in_tlb_w_csr_asid;


            wire [                                  13:0] privilege_read_exec_reg_out_csr_addr;
            wire                                          privilege_read_exec_reg_out_csr_we;
            wire                                          privilege_read_exec_reg_out_csr_re;
            wire                                          privilege_read_exec_reg_out_sel_csr_wmask;
            wire [                                  31:0] privilege_read_exec_reg_out_csr_rdata;


            wire [                                   4:0] privilege_read_exec_reg_out_invtlb_op;
            wire                                          privilege_read_exec_reg_out_is_inst_tlbsrch;
            wire                                          privilege_read_exec_reg_out_is_inst_tlbrd;
            wire                                          privilege_read_exec_reg_out_is_inst_tlbwr;
            wire                                          privilege_read_exec_reg_out_is_inst_tlbfill;
            wire                                          privilege_read_exec_reg_out_is_inst_invtlb;

            wire        privilege_read_exec_reg_out_tlbsrch_hit;
            wire        privilege_read_exec_reg_out_tlbrd_hit;
            wire [31:0] privilege_read_exec_reg_out_tlb_w_csr_tlbelo0;
            wire [31:0] privilege_read_exec_reg_out_tlb_w_csr_tlbelo1;
            wire [31:0] privilege_read_exec_reg_out_tlb_w_csr_tlbidx;
            wire [31:0] privilege_read_exec_reg_out_tlb_w_csr_tlbehi;
            wire [31:0] privilege_read_exec_reg_out_tlb_w_csr_asid;



            wire [                                  13:0] privilege_exec_writeback_reg_in_csr_addr;
            wire                                          privilege_exec_writeback_reg_in_csr_we;
            wire                                          privilege_exec_writeback_reg_in_csr_re;
            wire                                          privilege_exec_writeback_reg_in_sel_csr_wmask;
            wire [                                  31:0] privilege_exec_writeback_reg_in_csr_rdata;


            wire [                                   4:0] privilege_exec_writeback_reg_in_invtlb_op;
            wire                                          privilege_exec_writeback_reg_in_is_inst_tlbsrch;
            wire                                          privilege_exec_writeback_reg_in_is_inst_tlbrd;
            wire                                          privilege_exec_writeback_reg_in_is_inst_tlbwr;
            wire                                          privilege_exec_writeback_reg_in_is_inst_tlbfill;
            wire                                          privilege_exec_writeback_reg_in_is_inst_invtlb;


            wire [                                  31:0] privilege_exec_writeback_reg_in_physical_regfile_rdata1;
            wire [                                  31:0] privilege_exec_writeback_reg_in_physical_regfile_rdata2;


            wire        privilege_exec_writeback_reg_in_tlbsrch_hit;
            wire        privilege_exec_writeback_reg_in_tlbrd_hit;
            wire [31:0] privilege_exec_writeback_reg_in_tlb_w_csr_tlbelo0;
            wire [31:0] privilege_exec_writeback_reg_in_tlb_w_csr_tlbelo1;
            wire [31:0] privilege_exec_writeback_reg_in_tlb_w_csr_tlbidx;
            wire [31:0] privilege_exec_writeback_reg_in_tlb_w_csr_tlbehi;
            wire [31:0] privilege_exec_writeback_reg_in_tlb_w_csr_asid;

            wire [                                  13:0] privilege_exec_writeback_reg_out_csr_addr;
            wire                                          privilege_exec_writeback_reg_out_csr_we;
            wire                                          privilege_exec_writeback_reg_out_csr_re;
            wire                                          privilege_exec_writeback_reg_out_sel_csr_wmask;
            wire [                                  31:0] privilege_exec_writeback_reg_out_csr_rdata;


            wire [                                   4:0] privilege_exec_writeback_reg_out_invtlb_op;
            wire                                          privilege_exec_writeback_reg_out_is_inst_tlbsrch;
            wire                                          privilege_exec_writeback_reg_out_is_inst_tlbrd;
            wire                                          privilege_exec_writeback_reg_out_is_inst_tlbwr;
            wire                                          privilege_exec_writeback_reg_out_is_inst_tlbfill;
            wire                                          privilege_exec_writeback_reg_out_is_inst_invtlb;

            wire [                                  31:0] privilege_exec_writeback_reg_out_physical_regfile_rdata1;
            wire [                                  31:0] privilege_exec_writeback_reg_out_physical_regfile_rdata2;


            wire        privilege_exec_writeback_reg_out_tlbsrch_hit;
            wire        privilege_exec_writeback_reg_out_tlbrd_hit;
            wire [31:0] privilege_exec_writeback_reg_out_tlb_w_csr_tlbelo0;
            wire [31:0] privilege_exec_writeback_reg_out_tlb_w_csr_tlbelo1;
            wire [31:0] privilege_exec_writeback_reg_out_tlb_w_csr_tlbidx;
            wire [31:0] privilege_exec_writeback_reg_out_tlb_w_csr_tlbehi;
            wire [31:0] privilege_exec_writeback_reg_out_tlb_w_csr_asid;


            wire                                          bypass1_valid;
            wire [                                   6:0] bypass1_dst;
            wire [                                  31:0] bypass1_data;

            wire                                          bypass2_valid;
            wire [                                   6:0] bypass2_dst;
            wire [                                  31:0] bypass2_data;

            wire                                          bypass3_valid;
            wire [                                   6:0] bypass3_dst;
            wire [                                  31:0] bypass3_data;

            wire                                          bypass4_valid;
            wire [                                   6:0] bypass4_dst;
            wire [                                  31:0] bypass4_data;

            wire                                          bypass5_valid;
            wire [                                   6:0] bypass5_dst;
            wire [                                  31:0] bypass5_data;


            wire                                          bypass6_valid;
            wire [                                   6:0] bypass6_dst;
            wire [                                  31:0] bypass6_data;


            wire                                          bypass7_valid;
            wire [                                   6:0] bypass7_dst;
            wire [                                  31:0] bypass7_data;



            wire [                                   6:0] physical_regfile_raddr1;
            wire [                                   6:0] physical_regfile_raddr2;
            wire [                                   6:0] physical_regfile_raddr3;
            wire [                                   6:0] physical_regfile_raddr4;
            wire [                                   6:0] physical_regfile_raddr5;
            wire [                                   6:0] physical_regfile_raddr6;
            wire [                                   6:0] physical_regfile_raddr7;
            wire [                                   6:0] physical_regfile_raddr8;
            wire [                                   6:0] physical_regfile_raddr9;
            wire [                                   6:0] physical_regfile_raddr10;
            wire [                                   6:0] physical_regfile_raddr11;
            wire [                                   6:0] physical_regfile_raddr12;

            wire [                                   6:0] physical_regfile_waddr1;
            wire                                          physical_regfile_we1;
            wire [                                  31:0] physical_regfile_wdata1;

            wire [                                   6:0] physical_regfile_waddr2;
            wire                                          physical_regfile_we2;
            wire [                                  31:0] physical_regfile_wdata2;

            wire [                                   6:0] physical_regfile_waddr3;
            wire                                          physical_regfile_we3;
            wire [                                  31:0] physical_regfile_wdata3;

            wire [                                   6:0] physical_regfile_waddr4;
            wire                                          physical_regfile_we4;
            wire [                                  31:0] physical_regfile_wdata4;

            wire [                                   6:0] physical_regfile_waddr5;
            wire                                          physical_regfile_we5;
            wire [                                  31:0] physical_regfile_wdata5;

            wire [                                   6:0] physical_regfile_waddr6;
            wire                                         physical_regfile_we6;
            wire [                                  31:0] physical_regfile_wdata6;

            wire [                                   6:0] physical_regfile_waddr7;
            wire                                          physical_regfile_we7;
            wire [                                  31:0] physical_regfile_wdata7;

            wire [                                  31:0] physical_regfile_rdata1;
            wire [                                  31:0] physical_regfile_rdata2;
            wire [                                  31:0] physical_regfile_rdata3;
            wire [                                  31:0] physical_regfile_rdata4;
            wire [                                  31:0] physical_regfile_rdata5;
            wire [                                  31:0] physical_regfile_rdata6;
            wire [                                  31:0] physical_regfile_rdata7;
            wire [                                  31:0] physical_regfile_rdata8;
            wire [                                  31:0] physical_regfile_rdata9;
            wire [                                  31:0] physical_regfile_rdata10;
            wire [                                  31:0] physical_regfile_rdata11;
            wire [                                  31:0] physical_regfile_rdata12;



            wire [                                   7:0] csr_regfile_intrpt;
            wire                                          csr_regfile_ipi_int;
            wire [                                  31:0] csr_regfile_pc;
            wire [                                  31:0] csr_regfile_vaddr;


            wire [                                  13:0] csr_regfile_raddr;
            wire [                                  31:0] csr_regfile_rdata;

            wire [                                  13:0] csr_regfile_waddr;
            wire                                          csr_regfile_we;
            wire [                                  31:0] csr_regfile_wdata;
            wire [                                  31:0] csr_regfile_wmask;


            wire                                          csr_regfile_is_exception;
            wire                                          csr_regfile_ertn_flush;

            wire                                          csr_regfile_has_int;

            wire                                          csr_regfile_is_int;
            wire                                          csr_regfile_is_sys;
            wire                                          csr_regfile_is_adef;
            wire                                          csr_regfile_is_ale;
            wire                                          csr_regfile_is_brk;
            wire                                          csr_regfile_is_ine;

            wire                                          csr_regfile_is_tlbr;
            wire                                          csr_regfile_is_inst_tlbr;
            wire                                          csr_regfile_is_inst_pif;
            wire                                          csr_regfile_is_inst_ppi;
            wire                                          csr_regfile_is_data_tlbr;
            wire                                          csr_regfile_is_data_pil;
            wire                                          csr_regfile_is_data_pis;
            wire                                          csr_regfile_is_data_ppi;
            wire                                          csr_regfile_is_data_pme;


            wire [                                  31:0] csr_regfile_exception_enter_addr;
            wire [                                  31:0] csr_regfile_exception_return_addr;
            wire [                                  31:0] csr_regfile_exception_tlb_enter_addr;


            wire [                                  31:0] csr_regfile_out_csr_crmd;
            wire [                                  31:0] csr_regfile_out_csr_dmw0;
            wire [                                  31:0] csr_regfile_out_csr_dmw1;
            wire [                                  31:0] csr_regfile_out_csr_asid;
            wire [                                  31:0] csr_regfile_out_csr_estat;
            wire [                                  31:0] csr_regfile_out_csr_tlbidx;
            wire [                                  31:0] csr_regfile_out_csr_tlbehi;
            wire [                                  31:0] csr_regfile_out_csr_tlbelo0;
            wire [                                  31:0] csr_regfile_out_csr_tlbelo1;

            wire                                          csr_regfile_is_tlbsrch;
            wire                                          csr_regfile_tlbsrch_hit;
            wire                                          csr_regfile_is_tlbrd;
            wire                                          csr_regfile_tlbrd_hit;
            wire [                                  31:0] csr_regfile_tlb_w_csr_tlbelo0;
            wire [                                  31:0] csr_regfile_tlb_w_csr_tlbelo1;
            wire [                                  31:0] csr_regfile_tlb_w_csr_tlbidx;
            wire [                                  31:0] csr_regfile_tlb_w_csr_tlbehi;
            wire [                                  31:0] csr_regfile_tlb_w_csr_asid;

            wire                                          csr_regfile_is_ll_w;
            wire                                          csr_regfile_is_sc_w;

            wire                                          csr_regfile_llbit;



            wire [  1:0] mmu_csr_crmd_plv;
            wire         mmu_csr_crmd_da;
            wire         mmu_csr_crmd_pg;
            wire [  1:0] mmu_csr_crmd_datf;
            wire [  1:0] mmu_csr_crmd_datm;
            wire [ 31:0] mmu_csr_dmw0;
            wire [ 31:0] mmu_csr_dmw1;
            wire [  9:0] mmu_csr_asid_asid;
            wire [21:16] mmu_csr_estat_ecode;
            wire [  3:0] mmu_csr_tlbidx_index;
            wire [29:24] mmu_csr_tlbidx_ps;
            wire         mmu_csr_tlbidx_ne;
            wire [31:13] mmu_csr_tlbehi_vppn;
            wire         mmu_csr_tlbelo0_v;
            wire         mmu_csr_tlbelo0_d;
            wire [  3:2] mmu_csr_tlbelo0_plv;
            wire [  5:4] mmu_csr_tlbelo0_mat;
            wire         mmu_csr_tlbelo0_g;
            wire [ 27:8] mmu_csr_tlbelo0_ppn;
            wire         mmu_csr_tlbelo1_v;
            wire         mmu_csr_tlbelo1_d;
            wire [  3:2] mmu_csr_tlbelo1_plv;
            wire [  5:4] mmu_csr_tlbelo1_mat;
            wire         mmu_csr_tlbelo1_g;
            wire [ 27:8] mmu_csr_tlbelo1_ppn;

            wire [ 31:0] mmu_inst_va;
            wire [ 31:0] mmu_data_va;
            wire [  1:0] mmu_data_mem_type;

            wire         mmu_is_tlbsrch;
            wire         mmu_is_tlbrd;
            wire         mmu_is_tlbwr;
            wire         mmu_is_tlbfill;
            wire         mmu_is_invtlb;
            wire [  4:0] mmu_invtlb_op;
            wire [ 31:0] mmu_rj;
            wire [ 31:0] mmu_rk;



            wire         mmu_out_csr_tlbelo0_v;
            wire         mmu_out_csr_tlbelo0_d;
            wire [  3:2] mmu_out_csr_tlbelo0_plv;
            wire [  5:4] mmu_out_csr_tlbelo0_mat;
            wire         mmu_out_csr_tlbelo0_g;
            wire [ 27:8] mmu_out_csr_tlbelo0_ppn;

            wire         mmu_out_csr_tlbelo1_v;
            wire         mmu_out_csr_tlbelo1_d;
            wire [  3:2] mmu_out_csr_tlbelo1_plv;
            wire [  5:4] mmu_out_csr_tlbelo1_mat;
            wire         mmu_out_csr_tlbelo1_g;
            wire [ 27:8] mmu_out_csr_tlbelo1_ppn;

            wire [29:24] mmu_out_csr_tlbidx_ps;
            wire         mmu_out_csr_tlbidx_ne;
            wire [31:13] mmu_out_csr_tlbehi_vppn;
            wire [9 : 0] mmu_out_csr_asid_asid;
            wire [  3:0] mmu_out_csr_tlbidx_index;

            wire         mmu_tlbrd_hit;
            wire         mmu_tlbsrch_hit;




            wire [ 31:0] mmu_inst_pa;
            wire [  1:0] mmu_inst_mat;
            wire         mmu_inst_ex_tlbr;
            wire         mmu_inst_ex_pif;
            wire         mmu_inst_ex_ppi;



            wire [ 31:0] mmu_data_pa;
            wire [  1:0] mmu_data_mat;
            wire         mmu_data_ex_tlbr;
            wire         mmu_data_ex_pil;
            wire         mmu_data_ex_pis;
            wire         mmu_data_ex_ppi;
            wire         mmu_data_ex_pme;

            wire [ 31:0] tlb_w_csr_tlbelo0;
            wire [ 31:0] tlb_w_csr_tlbelo1;
            wire [ 31:0] tlb_w_csr_tlbidx;
            wire [ 31:0] tlb_w_csr_tlbehi;
            wire [ 31:0] tlb_w_csr_asid;

            wire [3:0] mmu_tlbfill_index;




            wire [                                   4:0] rob_alloc_bid[3:0];
            wire [                                   4:0] rob_predict_flush_bid;
            wire [                                   4:0] rob_head_bid;

            wire                                          rob_flush;

            wire [3:0] rob_alloc_valid;
            wire [3:0] rob_alloc_ready;
            wire [                     `ROB_ID_WIDTH-1:0] rob_alloc_rob_id[3:0];
            wire [                     `ROB_PC_WIDTH-1:0] rob_alloc_pc[3:0];
            wire [                                  31:0] rob_alloc_instruction[3:0];
            wire [                   `ROB_ARCH_WIDTH-1:0] rob_alloc_arch_dest[3:0];
            wire [                    `ROB_PHY_WIDTH-1:0] rob_alloc_new_pdest[3:0];
            wire [                    `ROB_PHY_WIDTH-1:0] rob_alloc_old_pdest[3:0];
            wire [3:0] rob_alloc_regfile_we;
            wire [                                   2:0] rob_alloc_inst_type[3:0];
            wire [               `ROB_ISSUE_OP_WIDTH-1:0] rob_alloc_issue_op[3:0];
            wire [3:0] rob_alloc_is_exception;

            wire                                          rob_alu_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_alu_complete_rob_id;
            wire [                                  31:0] rob_alu_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_alu_complete_writeback_op;
            wire                                          rob_alu_complete_exception;
            wire [                                   5:0] rob_alu_complete_ecode;

            wire                                          rob_alu_extra_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_alu_extra_complete_rob_id;
            wire [                                  31:0] rob_alu_extra_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_alu_extra_complete_writeback_op;
            wire                                          rob_alu_extra_complete_exception;
            wire [                                   5:0] rob_alu_extra_complete_ecode;

            wire                                          rob_lsu_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_lsu_complete_rob_id;
            wire [                                  31:0] rob_lsu_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_lsu_complete_writeback_op;
            wire                                          rob_lsu_complete_exception;
            wire [                                   5:0] rob_lsu_complete_ecode;

            wire                                          rob_mul_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_mul_complete_rob_id;
            wire [                                  31:0] rob_mul_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_mul_complete_writeback_op;
            wire                                          rob_mul_complete_exception;
            wire [                                   5:0] rob_mul_complete_ecode;

            wire                                          rob_div_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_div_complete_rob_id;
            wire [                                  31:0] rob_div_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_div_complete_writeback_op;
            wire                                          rob_div_complete_exception;
            wire [                                   5:0] rob_div_complete_ecode;

            wire                                          rob_fast_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_fast_complete_rob_id;
            wire [                                  31:0] rob_fast_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_fast_complete_writeback_op;
            wire                                          rob_fast_complete_exception;
            wire [                                   5:0] rob_fast_complete_ecode;

            wire                                          rob_fast_extra_complete_valid;
            wire [                     `ROB_ID_WIDTH-1:0] rob_fast_extra_complete_rob_id;
            wire [                                  31:0] rob_fast_extra_complete_value;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_fast_extra_complete_writeback_op;
            wire                                          rob_fast_extra_complete_exception;
            wire [                                   5:0] rob_fast_extra_complete_ecode;

            wire [3:0]rob_commit_valid;
            wire [3:0]rob_commit_ready;
            wire [3:0]rob_commit_fire;
            wire [                     `ROB_ID_WIDTH-1:0] rob_commit_rob_id[3:0];
            wire [                     `ROB_PC_WIDTH-1:0] rob_commit_pc[3:0];
            wire [                                  31:0] rob_commit_instruction[3:0];
            wire [                   `ROB_ARCH_WIDTH-1:0] rob_commit_arch_dest[3:0];
            wire [                    `ROB_PHY_WIDTH-1:0] rob_commit_new_pdest[3:0];
            wire [                    `ROB_PHY_WIDTH-1:0] rob_commit_old_pdest[3:0];
            wire [3:0] rob_commit_regfile_we;
            wire [                                  31:0] rob_commit_value[3:0];
            wire [                                   2:0] rob_commit_inst_type[3:0];
            wire [               `ROB_ISSUE_OP_WIDTH-1:0] rob_commit_issue_op[3:0];
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op[3:0];
            wire [3:0] rob_commit_is_exception;

            wire [3:0] rob_commit_ertn_flush;
            wire [3:0] rob_commit_is_sys;
            wire [3:0] rob_commit_is_int;
            wire [3:0] rob_commit_is_adef;
            wire [3:0] rob_commit_is_ine;
            wire [3:0] rob_commit_is_brk;
            wire [3:0] rob_commit_is_tlbr;
            wire [3:0] rob_commit_is_inst_tlbr;
            wire [3:0] rob_commit_is_inst_pif;
            wire [3:0] rob_commit_is_inst_ppi;


            wire [3:0] rob_commit_is_ale;
            wire [3:0] rob_commit_is_data_tlbr;
            wire [3:0] rob_commit_is_data_pil;
            wire [3:0] rob_commit_is_data_pis;
            wire [3:0] rob_commit_is_data_ppi;
            wire [3:0] rob_commit_is_data_pme;


            wire [3:0]                                    rob_commit_is_issue_tlbr;
            wire [3:0]                                    rob_commit_is_writeback_tlbr;

            wire [3:0] rob_commit_wb_refetch;
            wire [3:0] rob_commit_is_cacop;
            wire [                                  31:0] rob_commit_vaddr[3:0];
            wire [                                   3:0] rob_commit_redirect_fire;
            wire [                                   3:0] rob_commit_exception_fire;
            wire [                                   1:0] rob_commit_redirect_lane;



            wire                                          rob_complete_conflict;
            wire [                     `ROB_ID_WIDTH-1:0] rob_head;
            wire                                          rob_full;
            wire                                          rob_empty;
            wire [                  `ROB_COUNT_WIDTH-1:0] rob_count;
            wire [                  `ROB_COUNT_WIDTH-1:0] rob_res_count;

            wire                                          global_flush;
            wire                                          sel_store_commit;

            wire [                                  31:0] flush_target_address;



            wire                                          b_flush;


            wire                                          predict_flush;
            wire [                                   4:0] predict_flush_bid;
            wire [                 `ROB_ID_WIDTH - 1 : 0] predict_flush_rob_id;



            wire                                          is_int;
            wire                                          is_sys;
            wire                                          is_adef;
            wire                                          is_ale;
            wire                                          is_brk;
            wire                                          is_ine;



            reg  [                                  63:0] rdcnt;





            assign inst_sram_wr    = 1'b0;
            assign inst_sram_size  = 2'b10;
            assign inst_sram_wstrb = 4'b0000;
            assign inst_sram_addr  = if_insfifo_reg_out_pc_pa;
            assign inst_sram_wdata = 32'd0;


            assign data_sram_wr = lsu_mem1_mem2_reg_out_valid && !lsu_mem1_mem2_state_out_is_exception &&(lsu_mem1_mem2_reg_out_store_ctrl && lsu_mem1_mem2_reg_out_is_store_or_not_load || lsu_mem1_mem2_reg_out_is_sc_w && csr_regfile_llbit);
            assign data_sram_size = lsu_mem1_mem2_reg_out_wstrb == 4'b0001 || lsu_mem1_mem2_reg_out_wstrb == 4'b0010 || lsu_mem1_mem2_reg_out_wstrb == 4'b0100 || lsu_mem1_mem2_reg_out_wstrb == 4'b1000 ? 2'b00 : lsu_mem1_mem2_reg_out_wstrb == 4'b1100 || lsu_mem1_mem2_reg_out_wstrb == 4'b0011 ? 2'b01 : 2'b10;
            assign data_sram_wstrb = lsu_mem1_mem2_reg_out_wstrb;
            assign data_sram_addr = lsu_mem1_mem2_reg_out_address_pa;
            assign data_sram_wdata = lsu_mem1_mem2_reg_out_store_data;


            assign cacop_req = lsu_mem1_mem2_reg_out_valid && !lsu_mem1_mem2_state_out_is_exception && lsu_mem1_mem2_reg_out_is_cacop && cacop_fsm_state == `SRAM_IDLE;

            sram_fsm cacop_fsm (
                         .clk   (clk),
                         .resetn(resetn),

                         .addr_ok     (cache_subsystem_cacop_ready),
                         .req         (cacop_req),
                         .data_ok     (cache_subsystem_cacop_done),
                         .not_ready_go(lsu_mem1_mem2_reg_stall),

                         .state(cacop_fsm_state)
                     );
            wire cache_subsystem_mem2_postable_store;
            wire [255:0]cache_subsystem_if2_data;

            assign cache_subsystem_if1_valid   = pc_reg_out_valid && !pc_state_out_is_exception;
            assign cache_subsystem_if1_va      = pc_reg_pc;

            assign cache_subsystem_if2_valid   = if_insfifo_reg_out_valid && !if_insfifo_state_out_is_exception;
            assign cache_subsystem_if2_va      = if_insfifo_reg_out_pc;
            assign cache_subsystem_if2_pa      = if_insfifo_reg_out_pc_pa;
            assign cache_subsystem_if2_mat     = if_insfifo_state_out_mmu_inst_mat;


            assign cache_subsystem_mem1_valid
                   = !global_flush
                   && !predict_flush
                   && (lqsq_store_out_selected
                       || lqsq_load_out_selected
                       || (lsu_mem1_direct_selected
                           && !lsu_exec_mem1_state_out_is_exception));
            assign cache_subsystem_mem1_va
                   = (lqsq_store_out_selected || lqsq_load_out_selected)
                   ? lqsq_out_reserved[LQSQ_VADDR_MSB:LQSQ_VADDR_LSB]
                   : lsu_exec_mem1_reg_out_address;

            assign cache_subsystem_mem2_valid  = lsu_mem1_mem2_reg_out_valid && !lsu_mem1_mem2_state_out_is_exception &&
                   (lsu_mem1_mem2_reg_out_is_store_or_not_load && lsu_mem1_mem2_reg_out_store_ctrl ||
                    !lsu_mem1_mem2_reg_out_is_store_or_not_load && lsu_mem2_load_miss ||
                    lsu_mem1_mem2_reg_out_is_sc_w && csr_regfile_llbit);
            assign cache_subsystem_mem2_postable_store = lsu_mem1_mem2_reg_out_store_ctrl && lsu_mem1_mem2_reg_out_is_store_or_not_load ;
            assign cache_subsystem_mem2_wr     = data_sram_wr;
            assign cache_subsystem_mem2_size   = data_sram_size;
            assign cache_subsystem_mem2_wstrb  = data_sram_wstrb;
            assign cache_subsystem_mem2_wdata  = data_sram_wdata;
            assign cache_subsystem_mem2_va     = lsu_mem1_mem2_reg_out_address;
            assign cache_subsystem_mem2_pa     = data_sram_addr;
            assign cache_subsystem_mem2_mat    = lsu_mem1_mem2_state_out_mmu_data_mat;

            // assign cache_subsystem_mem2_miss_req = 1'b0;



            assign cache_subsystem_cacop_valid = cacop_req;
            assign cache_subsystem_cacop_code  = rob_commit_arch_dest[0];
            assign cache_subsystem_cacop_va    = lsu_mem1_mem2_reg_out_address;
            assign cache_subsystem_cacop_pa    = lsu_mem1_mem2_reg_out_address_pa;




            cache_subsystem u_cache_subsystem (
                                .clk   (clk),
                                .resetn(resetn),

                                .if1_valid(cache_subsystem_if1_valid),
                                .if1_va   (cache_subsystem_if1_va),
                                .if1_ready(cache_subsystem_if1_ready),

                                .if2_valid(cache_subsystem_if2_valid),
                                .if2_va   (cache_subsystem_if2_va),
                                .if2_pa   (cache_subsystem_if2_pa),
                                .if2_mat  (cache_subsystem_if2_mat),

                                .if2_miss_req  (cache_subsystem_if2_miss_req),
                                .if2_miss_ready(cache_subsystem_if2_miss_ready),

                                .if2_array_valid(cache_subsystem_if2_array_valid),
                                .if2_hit        (cache_subsystem_if2_hit),
                                .if2_miss       (cache_subsystem_if2_miss),

                                .if2_hit_way     (cache_subsystem_if2_hit_way),
                                // .if2_rdata       (cache_subsystem_if2_rdata),
                                .if2_refill_valid(cache_subsystem_if2_refill_valid),
                                // .if2_refill_rdata(cache_subsystem_if2_refill_rdata),
                                .if2_data0(cache_subsystem_if2_data[31:0]),
                                .if2_data1(cache_subsystem_if2_data[63:32]),
                                .if2_data2(cache_subsystem_if2_data[95:64]),
                                .if2_data3(cache_subsystem_if2_data[127:96]),
                                .if2_data4(cache_subsystem_if2_data[159:128]),
                                .if2_data5(cache_subsystem_if2_data[191:160]),
                                .if2_data6(cache_subsystem_if2_data[223:192]),
                                .if2_data7(cache_subsystem_if2_data[255:224]),
                                .icache_busy     (cache_subsystem_icache_busy),

                                .mem1_valid(cache_subsystem_mem1_valid),
                                .mem1_va   (cache_subsystem_mem1_va),
                                .mem1_ready(cache_subsystem_mem1_ready),

                                .mem2_valid(cache_subsystem_mem2_valid),
                                .mem2_postable_store(cache_subsystem_mem2_postable_store),
                                .mem2_pc   (rob_commit_pc[0]),
                                .mem2_wr   (cache_subsystem_mem2_wr),
                                .mem2_size (cache_subsystem_mem2_size),
                                .mem2_wstrb(cache_subsystem_mem2_wstrb),
                                .mem2_wdata(cache_subsystem_mem2_wdata),
                                .mem2_va   (cache_subsystem_mem2_va),
                                .mem2_pa   (cache_subsystem_mem2_pa),
                                .mem2_mat  (cache_subsystem_mem2_mat),

                                .mem2_miss_req   (cache_subsystem_mem2_miss_req),
                                .mem2_miss_ready (cache_subsystem_mem2_miss_ready),
                                .mem2_array_valid(cache_subsystem_mem2_array_valid),

                                .mem2_hit         (cache_subsystem_mem2_hit),
                                .mem2_miss        (cache_subsystem_mem2_miss),
                                .mem2_hit_way     (cache_subsystem_mem2_hit_way),
                                .mem2_load_done   (cache_subsystem_mem2_load_done),
                                .mem2_store_done  (cache_subsystem_mem2_store_done),
                                .mem2_rdata       (cache_subsystem_mem2_rdata),
                                .mem2_refill_valid(cache_subsystem_mem2_refill_valid),
                                .mem2_refill_rdata(cache_subsystem_mem2_refill_rdata),
                                .dcache_busy      (cache_subsystem_dcache_busy),

                                .cacop_valid(cache_subsystem_cacop_valid),
                                .cacop_ready(cache_subsystem_cacop_ready),
                                .cacop_done (cache_subsystem_cacop_done),
                                .cacop_code (cache_subsystem_cacop_code),
                                .cacop_va   (cache_subsystem_cacop_va),
                                .cacop_pa   (cache_subsystem_cacop_pa),


                                .arid   (arid),
                                .araddr (araddr),
                                .arlen  (arlen),
                                .arsize (arsize),
                                .arburst(arburst),
                                .arlock (arlock),
                                .arcache(arcache),
                                .arprot (arprot),
                                .arvalid(arvalid),
                                .arready(arready),
                                .rid    (rid),
                                .rdata  (rdata),
                                .rresp  (rresp),
                                .rlast  (rlast),
                                .rvalid (rvalid),
                                .rready (rready),
                                .awid   (awid),
                                .awaddr (awaddr),
                                .awlen  (awlen),
                                .awsize (awsize),
                                .awburst(awburst),
                                .awlock (awlock),
                                .awcache(awcache),
                                .awprot (awprot),
                                .awvalid(awvalid),
                                .awready(awready),
                                .wid    (wid),
                                .wdata  (wdata),
                                .wstrb  (wstrb),
                                .wlast  (wlast),
                                .wvalid (wvalid),
                                .wready (wready),
                                .bid    (bid),
                                .bresp  (bresp),
                                .bvalid (bvalid),
                                .bready (bready)






                            );




            assign inst_sram_req     = cache_subsystem_if2_miss_req;
            assign inst_sram_addr_ok = cache_subsystem_if2_miss_ready;
            assign inst_sram_data_ok = cache_subsystem_if2_refill_valid;
            assign inst_sram_rdata   = cache_subsystem_if2_hit ? cache_subsystem_if2_data : cache_subsystem_if2_refill_valid ? cache_subsystem_if2_data : inst_stall_buffer_out_data;


            assign data_sram_req     = cache_subsystem_mem2_miss_req;
            assign data_sram_addr_ok = cache_subsystem_mem2_miss_ready;
            assign data_sram_data_ok = cache_subsystem_mem2_refill_valid;
            assign data_sram_rdata   = cache_subsystem_mem2_hit ? cache_subsystem_mem2_rdata : cache_subsystem_mem2_refill_valid ? cache_subsystem_mem2_refill_rdata : data_stall_buffer_out_data;



            inst_sram_fsm u_inst_sram_fsm (
                              .clk   (clk),
                              .resetn(resetn),

                              .hit       (cache_subsystem_if2_hit),
                              .miss      (cache_subsystem_if2_miss),
                              .miss_req  (cache_subsystem_if2_miss_req),
                              .miss_ready(cache_subsystem_if2_miss_ready),

                              .refill_valid(cache_subsystem_if2_refill_valid),
                              .stall       (if_insfifo_reg_stall),

                              .state(inst_sram_fsm_state)
                          );

            data_sram_fsm u_data_sram_fsm (
                              .clk   (clk),
                              .resetn(resetn),

                              .hit       (cache_subsystem_mem2_hit),
                              .miss      (cache_subsystem_mem2_miss),
                              .miss_req  (cache_subsystem_mem2_miss_req),
                              .miss_ready(cache_subsystem_mem2_miss_ready),

                              .refill_valid(cache_subsystem_mem2_refill_valid),
                              .miss_trans  (data_sram_fsm_miss_trans),
                              .stall       (lsu_mem1_mem2_reg_stall),

                              .state(data_sram_fsm_state)
                          );

            assign inst_stall_buffer_in_data = inst_sram_rdata;

            inst_stall_buffer u_inst_stall_buffer (
                                  .clk   (clk),
                                  .resetn(resetn),

                                  .in_rdata(inst_stall_buffer_in_data),
                                  .data_ok ((inst_sram_fsm_state == `INST_SRAM_FSM_WAIT && inst_sram_data_ok) || (inst_sram_fsm_state == `INST_SRAM_FSM_IDLE && cache_subsystem_if2_hit)),

                                  .out_rdata(inst_stall_buffer_out_data)
                              );


            assign data_stall_buffer_in_data = data_sram_rdata;


            stall_buffer u_data_stall_buffer (
                             .clk   (clk),
                             .resetn(resetn),

                             .in_rdata(data_stall_buffer_in_data),
                             .data_ok ((data_sram_fsm_state == `DATA_SRAM_FSM_WAIT && data_sram_data_ok) || (data_sram_fsm_state == `DATA_SRAM_FSM_IDLE && cache_subsystem_mem2_hit)),

                             .out_rdata(data_stall_buffer_out_data)

                         );




            always @(posedge clk) begin
                if (!resetn)
                    rdcnt <= 64'd0;
                else
                    rdcnt <= rdcnt + 64'd1;
            end
            reg sel_predict_pc;
            reg [255:0] predict_pc;
            reg [7:0] predict_taken;


            always @(posedge clk) begin
                if(!resetn) begin
                    sel_predict_pc <= 1'b0;
                end
                else if(!pc_reg_stall) begin
                    sel_predict_pc <= 1'b0;
                end
                else
                    sel_predict_pc <= 1'b1;


                if(!sel_predict_pc) begin
                    predict_taken <= branch_predictor_is_taken;
                    predict_pc <= branch_predictor_target_address;
                end
            end

            wire [31:0] final_predict_pc;
            // assign final_predict_pc = sel_predict_pc ? predict_pc : branch_predictor_target_address; //
            // assign final_predict_pc = mmu_inst_mat == 2'b01 ? {pc_reg_pc[31:5], 5'd0} + 32'b100000 : pc_reg_pc + 32'd4;



            wire  [31:0]      branch_predictor_pc;
            wire              branch_predictor_update;
            wire  [31:0]      branch_predictor_branch_pc;
            wire              branch_predictor_actual_taken;
            wire  [31:0]      branch_predictor_actual_target;
            wire   [7:0]           branch_predictor_is_taken;
            wire [255:0]       branch_predictor_target_address;
            wire branch_predictor_clr;
            assign branch_predictor_pc = pc_reg_in_valid ? pc_reg_npc : 32'h1bfffffc;
            assign branch_predictor_update =  md_bru_writeback_reg_out_valid && md_bru_writeback_reg_out_sel_npc == `SEL_NPC_BRANCH;
            assign branch_predictor_branch_pc = md_bru_writeback_reg_out_pc;
            assign branch_predictor_actual_taken = md_bru_writeback_reg_out_compared_result;
            assign branch_predictor_actual_target = md_bru_writeback_reg_out_target_address;


            branch_predictor u_branch_predictor(
                                 .clk(clk),
                                 .resetn(resetn),

                                 .pc(branch_predictor_pc),
                                 .update(branch_predictor_update),
                                 .branch_pc(branch_predictor_branch_pc),
                                 .actual_taken(branch_predictor_actual_taken),
                                 .actual_target(branch_predictor_actual_target),
                                 .is_taken(branch_predictor_is_taken),
                                 .target_address(branch_predictor_target_address),
                                 .clr(branch_predictor_clr)

                             );

            wire [3:0] next_pc_generator_valid_count;
            wire [255:0] selected_predict_target_address;
            assign selected_predict_target_address =
                   sel_predict_pc ? predict_pc : branch_predictor_target_address;

            next_pc_generator u_next_pc_generator(
                                  .pc(pc_reg_pc),
                                  .predict_pc(selected_predict_target_address),
                                  .predict_taken(sel_predict_pc ? predict_taken : branch_predictor_is_taken),

                                  .valid_count(next_pc_generator_valid_count),
                                  .final_predict_pc(final_predict_pc)

                              );




            always @(posedge clk) begin
                if (!resetn)
                    global_valid <= 1'b0;
                else
                    global_valid <= 1'b1;
            end



            assign is_adef                  = pc_reg_npc[1:0] != 2'b00;
            assign pc_state_in_is_exception = is_adef;
            assign pc_state_in_is_adef      = is_adef;

            pc_state u_pc_state (
                         .clk   (clk),
                         .resetn(resetn),
                         .stall (pc_reg_stall),

                         .in_is_exception(pc_state_in_is_exception),
                         .in_is_adef     (pc_state_in_is_adef),

                         .out_is_exception(pc_state_out_is_exception),
                         .out_is_adef     (pc_state_out_is_adef)

                     );



            assign pc_reg_in_valid = global_valid && !branch_predictor_clr;
            // assign pc_reg_stall    = 1'b0;
            // assign pc_reg_npc      = global_flush ? flush_target_address : predict_flush ? md_bru_writeback_reg_out_target_address : b_flush ? id_rename_pipeline_queue_target_b_r : final_predict_pc;
            assign pc_reg_npc      = global_flush || predict_flush || b_flush  ? {32{global_flush}} & flush_target_address | {32{predict_flush}} & md_bru_writeback_reg_out_target_address | {32{b_flush}} & id_rename_pipeline_queue_target_b_r : final_predict_pc;

            pc_reg u_pc_reg (
                       .clk      (clk),
                       .resetn   (resetn),
                       .in_valid (pc_reg_in_valid),
                       .stall    (pc_reg_stall),
                       .out_valid(pc_reg_out_valid),
                       .npc      (pc_reg_npc),
                       .pc       (pc_reg_pc)
                   );

            // assign inst_sram_we                     = 1'b0;
            // assign inst_sram_addr                   = pc_reg_pc;
            // assign inst_sram_wdata                  = 32'd0;


            assign if_insfifo_state_in_is_exception = pc_state_out_is_exception || mmu_inst_ex_tlbr || mmu_inst_ex_ppi || mmu_inst_ex_pif;
            assign if_insfifo_state_in_is_adef      = pc_state_out_is_adef;

            assign if_insfifo_state_in_is_tlbr      = !pc_state_out_is_exception && mmu_inst_ex_tlbr;
            assign if_insfifo_state_in_is_inst_tlbr = mmu_inst_ex_tlbr;
            assign if_insfifo_state_in_is_inst_pif  = mmu_inst_ex_pif;
            assign if_insfifo_state_in_is_inst_ppi  = mmu_inst_ex_ppi;
            assign if_insfifo_state_in_mmu_inst_mat = mmu_inst_mat;


            if_insfifo_state u_if_insfifo_state (
                                 .clk   (clk),
                                 .resetn(resetn),
                                 .stall (if_insfifo_reg_stall),

                                 .in_is_exception(if_insfifo_state_in_is_exception),
                                 .in_is_adef     (if_insfifo_state_in_is_adef),

                                 .in_is_tlbr     (if_insfifo_state_in_is_tlbr),
                                 .in_is_inst_tlbr(if_insfifo_state_in_is_inst_tlbr),
                                 .in_is_inst_pif (if_insfifo_state_in_is_inst_pif),
                                 .in_is_inst_ppi (if_insfifo_state_in_is_inst_ppi),
                                 .in_mmu_inst_mat(if_insfifo_state_in_mmu_inst_mat),

                                 .out_is_exception(if_insfifo_state_out_is_exception),
                                 .out_is_adef     (if_insfifo_state_out_is_adef),

                                 .out_is_tlbr     (if_insfifo_state_out_is_tlbr),
                                 .out_is_inst_tlbr(if_insfifo_state_out_is_inst_tlbr),
                                 .out_is_inst_pif (if_insfifo_state_out_is_inst_pif),
                                 .out_is_inst_ppi (if_insfifo_state_out_is_inst_ppi),
                                 .out_mmu_inst_mat(if_insfifo_state_out_mmu_inst_mat)
                             );


            wire [255:0] if_insfifo_reg_in_predict_target_address;
            wire [255:0] if_insfifo_reg_out_predict_target_address;
            wire [3:0] if_insfifo_reg_in_valid_count;
            wire [3:0] if_insfifo_reg_out_valid_count;

            assign if_insfifo_reg_in_valid  = pc_reg_out_valid && !if1_clear;
            assign if_insfifo_reg_pre_stall = pc_reg_stall;
            assign if_insfifo_reg_in_pc     = pc_reg_pc;
            // Carry the predicted next PC for every instruction in the fetch
            // group.  final_predict_pc is only the next fetch-group address;
            // using it here makes all eight instructions appear to have made
            // the same prediction and can hide a conditional-branch miss.
            assign if_insfifo_reg_in_predict_target_address = selected_predict_target_address;


            assign if_insfifo_reg_in_pc_pa = mmu_inst_pa;
            assign if_insfifo_reg_in_valid_count = next_pc_generator_valid_count;

            if_insfifo_reg u_if_insfifo_reg (
                               .clk   (clk),
                               .resetn(resetn),

                               .stall    (if_insfifo_reg_stall),
                               .pre_stall(if_insfifo_reg_pre_stall),

                               .in_valid(if_insfifo_reg_in_valid),
                               .in_pc   (if_insfifo_reg_in_pc),
                               .in_pc_pa(if_insfifo_reg_in_pc_pa),
                               .in_predict_target_address(if_insfifo_reg_in_predict_target_address),
                               .in_valid_count(if_insfifo_reg_in_valid_count),

                               .out_valid(if_insfifo_reg_out_valid),
                               .out_pc   (if_insfifo_reg_out_pc),
                               .out_pc_pa(if_insfifo_reg_out_pc_pa),
                               .out_predict_target_address(if_insfifo_reg_out_predict_target_address),
                               .out_valid_count(if_insfifo_reg_out_valid_count)
                           );

            wire [31:0] ins_fifo_shift_pc;
            wire [1:0] ins_fifo_shift_inst_mat;
            wire [255:0] ins_fifo_shift_inst_sram_rdata;
            wire  [255:0] ins_fifo_shift_in_predict_target_address;

            wire [255:0] ins_fifo_shift_out_inst_sram_rdata;
            wire [7:0] ins_fifo_shift_out_valid_mask;
            wire [3:0] ins_fifo_shift_out_valid_count;
            wire [255:0] ins_fifo_shift_out_predict_target_address;

            assign ins_fifo_shift_pc = if_insfifo_reg_out_pc;
            assign ins_fifo_shift_inst_sram_rdata = inst_sram_rdata;
            assign ins_fifo_shift_in_predict_target_address = if_insfifo_reg_out_predict_target_address;


            ins_fifo_shift u_ins_fifo_shift(
                               .pc(ins_fifo_shift_pc),
                               .inst_sram_rdata(ins_fifo_shift_inst_sram_rdata),
                               .in_predict_target_address(ins_fifo_shift_in_predict_target_address),

                               .out_inst_sram_rdata(ins_fifo_shift_out_inst_sram_rdata),
                               .out_valid_mask(ins_fifo_shift_out_valid_mask),
                               .out_valid_count(ins_fifo_shift_out_valid_count),
                               .out_predict_target_address(ins_fifo_shift_out_predict_target_address)
                           );

            wire                   ins_fifo_8in4out_flush;

            wire [7:0]                 ins_fifo_8in4out_in_ready;
            wire [101:0]     ins_fifo_8in4out_in_data [7:0];
            wire [7:0]             ins_fifo_8in4out_in_valid_mask;
            wire [3:0]             ins_fifo_8in4out_in_valid_count;

            wire [3:0]                  ins_fifo_8in4out_out_valid;
            wire [3:0]                  ins_fifo_8in4out_out_ready;
            wire [2:0] ins_fifo_8in4out_out_valid_count;
            wire [101:0]     ins_fifo_8in4out_out_data[3:0];

            wire  [7:0]             ins_fifo_8in4out_occupancy;
            wire  [7:0]             ins_fifo_8in4out_res_count;
            wire                   ins_fifo_8in4out_full;
            wire                   ins_fifo_8in4out_empty;

            wire ins_fifo_8in4out_allow_in;
            assign ins_fifo_8in4out_allow_in =
                   ins_fifo_8in4out_res_count >=
                   {{4{1'b0}}, if_insfifo_reg_out_valid_count};

            assign ins_fifo_8in4out_in_valid_mask = if_insfifo_reg_out_valid && !if_insfifo_reg_stall ? ((8'b1 << (if_insfifo_reg_out_valid_count)) - 8'd1) : 8'b0000_0000;
            assign ins_fifo_8in4out_in_valid_count = if_insfifo_reg_out_valid && !if_insfifo_reg_stall ? if_insfifo_reg_out_valid_count :4'd0;
            assign ins_fifo_8in4out_flush = id_clear;
            assign ins_fifo_8in4out_in_data[0] =
                   {
                       if_insfifo_reg_out_pc,
                       ins_fifo_shift_out_inst_sram_rdata[31:0],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[31:0]
                   };


            assign ins_fifo_8in4out_in_data[1] =
                   {
                       if_insfifo_reg_out_pc+ 32'd4,
                       ins_fifo_shift_out_inst_sram_rdata[63:32],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[63:32]
                   };


            assign ins_fifo_8in4out_in_data[2] =
                   {
                       if_insfifo_reg_out_pc + 32'd8,
                       ins_fifo_shift_out_inst_sram_rdata[95:64],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[95:64]
                   };


            assign ins_fifo_8in4out_in_data[3] =
                   {
                       if_insfifo_reg_out_pc + 32'd12,
                       ins_fifo_shift_out_inst_sram_rdata[127:96],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[127:96]
                   };


            assign ins_fifo_8in4out_in_data[4] =
                   {
                       if_insfifo_reg_out_pc + 32'd16,
                       ins_fifo_shift_out_inst_sram_rdata[159:128],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[159:128]
                   };


            assign ins_fifo_8in4out_in_data[5] =
                   {
                       if_insfifo_reg_out_pc + 32'd20,
                       ins_fifo_shift_out_inst_sram_rdata[191:160],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[191:160]
                   };


            assign ins_fifo_8in4out_in_data[6] =
                   {
                       if_insfifo_reg_out_pc + 32'd24,
                       ins_fifo_shift_out_inst_sram_rdata[223:192],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[223:192]
                   };


            assign ins_fifo_8in4out_in_data[7] =
                   {
                       if_insfifo_reg_out_pc + 32'd28,
                       ins_fifo_shift_out_inst_sram_rdata[255:224],
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       ins_fifo_shift_out_predict_target_address[255:224]
                   };




            ins_fifo_8in4out u_ins_fifo_8in4out(
                                 .clk(clk),
                                 .resetn(resetn),
                                 .flush(ins_fifo_8in4out_flush),

                                 .in_ready(ins_fifo_8in4out_in_ready),

                                 //  .in_data(ins_fifo_8in4out_in_data),
                                 .in_data_0(ins_fifo_8in4out_in_data[0]),
                                 .in_data_1(ins_fifo_8in4out_in_data[1]),
                                 .in_data_2(ins_fifo_8in4out_in_data[2]),
                                 .in_data_3(ins_fifo_8in4out_in_data[3]),
                                 .in_data_4(ins_fifo_8in4out_in_data[4]),
                                 .in_data_5(ins_fifo_8in4out_in_data[5]),
                                 .in_data_6(ins_fifo_8in4out_in_data[6]),
                                 .in_data_7(ins_fifo_8in4out_in_data[7]),
                                 .in_valid_mask(ins_fifo_8in4out_in_valid_mask),
                                 .in_valid_count(ins_fifo_8in4out_in_valid_count),

                                 .out_valid(ins_fifo_8in4out_out_valid),
                                 .out_ready(ins_fifo_8in4out_out_ready),
                                 .out_valid_count(ins_fifo_8in4out_out_valid_count),
                                 //  .out_data(ins_fifo_8in4out_out_data),
                                 .out_data_0(ins_fifo_8in4out_out_data[0]),
                                 .out_data_1(ins_fifo_8in4out_out_data[1]),
                                 .out_data_2(ins_fifo_8in4out_out_data[2]),
                                 .out_data_3(ins_fifo_8in4out_out_data[3]),

                                 .occupancy(ins_fifo_8in4out_occupancy),
                                 .res_count(ins_fifo_8in4out_res_count),
                                 .full(ins_fifo_8in4out_full),
                                 .empty(ins_fifo_8in4out_empty)
                             );


            wire id_clear;


            // IDLE stays at the head of the instruction FIFO until an
            // interrupt arrives.  Keep the handshake prefix-contiguous so
            // older lanes before IDLE may advance, while IDLE and all younger
            // lanes remain buffered.
            wire [3:0] ins_fifo_8in4out_idle_allow;
            assign ins_fifo_8in4out_idle_allow[0] =
                   !(ins_fifo_8in4out_out_valid[0] && compress_decode_is_idle[0] && !is_int);
            assign ins_fifo_8in4out_idle_allow[1] =
                   ins_fifo_8in4out_idle_allow[0] &&
                   !(ins_fifo_8in4out_out_valid[1] && compress_decode_is_idle[1] && !is_int);
            assign ins_fifo_8in4out_idle_allow[2] =
                   ins_fifo_8in4out_idle_allow[1] &&
                   !(ins_fifo_8in4out_out_valid[2] && compress_decode_is_idle[2] && !is_int);
            assign ins_fifo_8in4out_idle_allow[3] =
                   ins_fifo_8in4out_idle_allow[2] &&
                   !(ins_fifo_8in4out_out_valid[3] && compress_decode_is_idle[3] && !is_int);



            assign ins_fifo_8in4out_out_ready =
                   id_rename_pipeline_queue_in_ready &
                   ins_fifo_8in4out_idle_allow;
            wire [31:0] inst_fifo_predict_target_address;

            assign is_int = csr_regfile_has_int;

            // assign inst_fifo_valid = ins_fifo_8in4out_out_valid[0];

            wire compress_decode_csr_3w [3:0];
            wire compress_decode_is_CNTinst [3:0];
            wire [7:0] compress_decode_load_valid [3:0];
            wire [7:0] compress_decode_store_valid [3:0];

            wire compress_decode_is_b_jump [3:0];
            wire [31:0] compress_decode_target_b [3:0];
            wire compress_decode_is_idle [3:0];
            wire compress_decode_label [3:0];
            wire [`ID_OPCODE_LEN - 1 :0] compress_decode_id_opcode [3:0];

            compress_decode u_decode_0(
                                .ins_fifo_data(ins_fifo_8in4out_out_data[0]),
                                .is_int(is_int),
                                .rdcnt(rdcnt),

                                .csr_3w(compress_decode_csr_3w[0]),
                                .is_CNTinst(compress_decode_is_CNTinst[0]),
                                .load_valid(compress_decode_load_valid[0]),
                                .store_valid(compress_decode_store_valid[0]),

                                .is_b_jump(compress_decode_is_b_jump[0]),
                                .target_b(compress_decode_target_b[0]),
                                .is_idle(compress_decode_is_idle[0]),
                                .label(compress_decode_label[0]),
                                .id_opcode(compress_decode_id_opcode[0])
                            );
            compress_decode u_decode_1(
                                .ins_fifo_data(ins_fifo_8in4out_out_data[1]),
                                .is_int(is_int),
                                .rdcnt(rdcnt),

                                .csr_3w(compress_decode_csr_3w[1]),
                                .is_CNTinst(compress_decode_is_CNTinst[1]),
                                .load_valid(compress_decode_load_valid[1]),
                                .store_valid(compress_decode_store_valid[1]),

                                .is_b_jump(compress_decode_is_b_jump[1]),
                                .target_b(compress_decode_target_b[1]),
                                .is_idle(compress_decode_is_idle[1]),
                                .label(compress_decode_label[1]),
                                .id_opcode(compress_decode_id_opcode[1])
                            );
            compress_decode u_decode_2(
                                .ins_fifo_data(ins_fifo_8in4out_out_data[2]),
                                .is_int(is_int),
                                .rdcnt(rdcnt),

                                .csr_3w(compress_decode_csr_3w[2]),
                                .is_CNTinst(compress_decode_is_CNTinst[2]),
                                .load_valid(compress_decode_load_valid[2]),
                                .store_valid(compress_decode_store_valid[2]),

                                .is_b_jump(compress_decode_is_b_jump[2]),
                                .target_b(compress_decode_target_b[2]),
                                .is_idle(compress_decode_is_idle[2]),
                                .label(compress_decode_label[2]),
                                .id_opcode(compress_decode_id_opcode[2])
                            );
            compress_decode u_decode_3(
                                .ins_fifo_data(ins_fifo_8in4out_out_data[3]),
                                .is_int(is_int),
                                .rdcnt(rdcnt),

                                .csr_3w(compress_decode_csr_3w[3]),
                                .is_CNTinst(compress_decode_is_CNTinst[3]),
                                .load_valid(compress_decode_load_valid[3]),
                                .store_valid(compress_decode_store_valid[3]),

                                .is_b_jump(compress_decode_is_b_jump[3]),
                                .target_b(compress_decode_target_b[3]),
                                .is_idle(compress_decode_is_idle[3]),
                                .label(compress_decode_label[3]),
                                .id_opcode(compress_decode_id_opcode[3])
                            );



            wire id_rename_pipeline_queue_flush;

            wire [3:0] id_rename_pipeline_queue_in_valid ;
            wire [3:0] id_rename_pipeline_queue_in_ready;
            wire [`ID_OPCODE_LEN-1:0] id_rename_pipeline_queue_in_data [3:0];
            wire id_rename_pipeline_queue_in_is_b_jump [3:0];
            wire [31:0] id_rename_pipeline_queue_in_target_b [3:0];

            wire [3:0]id_rename_pipeline_queue_out_valid ;
            wire [3:0]id_rename_pipeline_queue_out_ready ;
            wire [`ID_OPCODE_LEN-1:0] id_rename_pipeline_queue_out_data [3:0];
            wire [             4:0] id_rename_pipeline_queue_out_bid [3:0];


            wire [3:0] id_rename_pipeline_queue_occupancy;
            wire       id_rename_pipeline_queue_full;
            wire       id_rename_pipeline_queue_empty;

            wire id_rename_pipeline_queue_branch_id_allocator_alloc_bid_ready;
            wire [4:0] id_rename_pipeline_queue_branch_id_allocator_alloc_bid;
            wire id_rename_pipeline_queue_branch_id_allocator_alloc_bid_valid;
            wire [95:0] id_rename_pipeline_queue_branch_id_allocator_alloc_data;

            wire id_rename_pipeline_queue_b_flush_r;
            wire [31:0] id_rename_pipeline_queue_target_b_r;

            wire [3:0] id_rename_pipeline_queue_in_fire;

            assign id_rename_pipeline_queue_flush = allocbid_clear;

            assign id_rename_pipeline_queue_branch_id_allocator_alloc_bid_ready = branch_id_allocator_alloc_bid_ready;
            assign id_rename_pipeline_queue_branch_id_allocator_alloc_bid = branch_id_allocator_alloc_bid;


            assign id_rename_pipeline_queue_in_valid[0] = ins_fifo_8in4out_out_valid[0] && ins_fifo_8in4out_idle_allow[0] && !b_flush;
            assign id_rename_pipeline_queue_in_data[0] = compress_decode_id_opcode[0];
            assign id_rename_pipeline_queue_in_is_b_jump[0] = compress_decode_is_b_jump[0];
            assign id_rename_pipeline_queue_in_target_b[0] = compress_decode_target_b[0];


            assign id_rename_pipeline_queue_in_valid[1] = ins_fifo_8in4out_out_valid[1] && ins_fifo_8in4out_idle_allow[1] && !b_flush;
            assign id_rename_pipeline_queue_in_data[1] = compress_decode_id_opcode[1];
            assign id_rename_pipeline_queue_in_is_b_jump[1] = compress_decode_is_b_jump[1];
            assign id_rename_pipeline_queue_in_target_b[1] = compress_decode_target_b[1];


            assign id_rename_pipeline_queue_in_valid[2] = ins_fifo_8in4out_out_valid[2] && ins_fifo_8in4out_idle_allow[2] && !b_flush;
            assign id_rename_pipeline_queue_in_data[2] = compress_decode_id_opcode[2];
            assign id_rename_pipeline_queue_in_is_b_jump[2] = compress_decode_is_b_jump[2];
            assign id_rename_pipeline_queue_in_target_b[2] = compress_decode_target_b[2];


            assign id_rename_pipeline_queue_in_valid[3] = ins_fifo_8in4out_out_valid[3] && ins_fifo_8in4out_idle_allow[3] && !b_flush;
            assign id_rename_pipeline_queue_in_data[3] = compress_decode_id_opcode[3];
            assign id_rename_pipeline_queue_in_is_b_jump[3] = compress_decode_is_b_jump[3];
            assign id_rename_pipeline_queue_in_target_b[3] = compress_decode_target_b[3];

            assign id_rename_pipeline_queue_out_ready = rename_dispatch_pipeline_queue_in_ready;


            wire id_rename_pipeline_queue_rename_valid [3:0];
            wire id_rename_pipeline_queue_rename_success [3:0];
            wire [4:0] id_rename_pipeline_queue_rename_regfile_raddr1 [3:0];
            wire [4:0] id_rename_pipeline_queue_rename_regfile_raddr2 [3:0];
            wire [4:0] id_rename_pipeline_queue_rename_regfile_waddr [3:0];
            wire id_rename_pipeline_queue_rename_regfile_we [3:0];
            wire id_rename_pipeline_queue_rename_label [3:0];
            wire [4:0] id_rename_pipeline_queue_rename_bid [3:0];
            wire [6:0] id_rename_pipeline_queue_rename_phy_reg_src1 [3:0];
            wire [6:0] id_rename_pipeline_queue_rename_phy_reg_src2 [3:0];
            wire [6:0] id_rename_pipeline_queue_rename_old_phy_reg_dst [3:0];
            wire [6:0] id_rename_pipeline_queue_rename_new_phy_reg_dst [3:0];

            id_rename_pipeline_queue u_id_rename_pipeline_queue(
                                         .clk(clk),
                                         .resetn(resetn),

                                         .flush(id_rename_pipeline_queue_flush),

                                         .in_valid0(id_rename_pipeline_queue_in_valid[0]),
                                         .in_ready0(id_rename_pipeline_queue_in_ready[0]),
                                         .in_data0(id_rename_pipeline_queue_in_data[0]),
                                         .in_is_b_jump0(id_rename_pipeline_queue_in_is_b_jump[0]),
                                         .in_target_b0(id_rename_pipeline_queue_in_target_b[0]),


                                         .in_valid1(id_rename_pipeline_queue_in_valid[1]),
                                         .in_ready1(id_rename_pipeline_queue_in_ready[1]),
                                         .in_data1(id_rename_pipeline_queue_in_data[1]),
                                         .in_is_b_jump1(id_rename_pipeline_queue_in_is_b_jump[1]),
                                         .in_target_b1(id_rename_pipeline_queue_in_target_b[1]),


                                         .in_valid2(id_rename_pipeline_queue_in_valid[2]),
                                         .in_ready2(id_rename_pipeline_queue_in_ready[2]),
                                         .in_data2(id_rename_pipeline_queue_in_data[2]),
                                         .in_is_b_jump2(id_rename_pipeline_queue_in_is_b_jump[2]),
                                         .in_target_b2(id_rename_pipeline_queue_in_target_b[2]),


                                         .in_valid3(id_rename_pipeline_queue_in_valid[3]),
                                         .in_ready3(id_rename_pipeline_queue_in_ready[3]),
                                         .in_data3(id_rename_pipeline_queue_in_data[3]),
                                         .in_is_b_jump3(id_rename_pipeline_queue_in_is_b_jump[3]),
                                         .in_target_b3(id_rename_pipeline_queue_in_target_b[3]),


                                         .out_valid0(id_rename_pipeline_queue_out_valid[0]),
                                         .out_ready0(id_rename_pipeline_queue_out_ready[0]),
                                         .out_data0(id_rename_pipeline_queue_out_data[0]),
                                         .out_bid0(id_rename_pipeline_queue_out_bid[0]),

                                         .out_valid1(id_rename_pipeline_queue_out_valid[1]),
                                         .out_ready1(id_rename_pipeline_queue_out_ready[1]),
                                         .out_data1(id_rename_pipeline_queue_out_data[1]),
                                         .out_bid1(id_rename_pipeline_queue_out_bid[1]),

                                         .out_valid2(id_rename_pipeline_queue_out_valid[2]),
                                         .out_ready2(id_rename_pipeline_queue_out_ready[2]),
                                         .out_data2(id_rename_pipeline_queue_out_data[2]),
                                         .out_bid2(id_rename_pipeline_queue_out_bid[2]),

                                         .out_valid3(id_rename_pipeline_queue_out_valid[3]),
                                         .out_ready3(id_rename_pipeline_queue_out_ready[3]),
                                         .out_data3(id_rename_pipeline_queue_out_data[3]),
                                         .out_bid3(id_rename_pipeline_queue_out_bid[3]),

                                         .rename_valid0(id_rename_pipeline_queue_rename_valid[0]),
                                         .rename_success0(id_rename_pipeline_queue_rename_success[0]),
                                         .rename_regfile_raddr1_0(id_rename_pipeline_queue_rename_regfile_raddr1[0]),
                                         .rename_regfile_raddr2_0(id_rename_pipeline_queue_rename_regfile_raddr2[0]),
                                         .rename_regfile_waddr_0(id_rename_pipeline_queue_rename_regfile_waddr[0]),
                                         .rename_regfile_we_0(id_rename_pipeline_queue_rename_regfile_we[0]),
                                         .rename_label0(id_rename_pipeline_queue_rename_label[0]),
                                         .rename_bid0(id_rename_pipeline_queue_rename_bid[0]),
                                         .rename_phy_reg_src1_0(id_rename_pipeline_queue_rename_phy_reg_src1[0]),
                                         .rename_phy_reg_src2_0(id_rename_pipeline_queue_rename_phy_reg_src2[0]),
                                         .rename_old_phy_reg_dst_0(id_rename_pipeline_queue_rename_old_phy_reg_dst[0]),
                                         .rename_new_phy_reg_dst_0(id_rename_pipeline_queue_rename_new_phy_reg_dst[0]),



                                         .rename_valid1(id_rename_pipeline_queue_rename_valid[1]),
                                         .rename_success1(id_rename_pipeline_queue_rename_success[1]),
                                         .rename_regfile_raddr1_1(id_rename_pipeline_queue_rename_regfile_raddr1[1]),
                                         .rename_regfile_raddr2_1(id_rename_pipeline_queue_rename_regfile_raddr2[1]),
                                         .rename_regfile_waddr_1(id_rename_pipeline_queue_rename_regfile_waddr[1]),
                                         .rename_regfile_we_1(id_rename_pipeline_queue_rename_regfile_we[1]),
                                         .rename_label1(id_rename_pipeline_queue_rename_label[1]),
                                         .rename_bid1(id_rename_pipeline_queue_rename_bid[1]),
                                         .rename_phy_reg_src1_1(id_rename_pipeline_queue_rename_phy_reg_src1[1]),
                                         .rename_phy_reg_src2_1(id_rename_pipeline_queue_rename_phy_reg_src2[1]),
                                         .rename_old_phy_reg_dst_1(id_rename_pipeline_queue_rename_old_phy_reg_dst[1]),
                                         .rename_new_phy_reg_dst_1(id_rename_pipeline_queue_rename_new_phy_reg_dst[1]),


                                         .rename_valid2(id_rename_pipeline_queue_rename_valid[2]),
                                         .rename_success2(id_rename_pipeline_queue_rename_success[2]),
                                         .rename_regfile_raddr1_2(id_rename_pipeline_queue_rename_regfile_raddr1[2]),
                                         .rename_regfile_raddr2_2(id_rename_pipeline_queue_rename_regfile_raddr2[2]),
                                         .rename_regfile_waddr_2(id_rename_pipeline_queue_rename_regfile_waddr[2]),
                                         .rename_regfile_we_2(id_rename_pipeline_queue_rename_regfile_we[2]),
                                         .rename_label2(id_rename_pipeline_queue_rename_label[2]),
                                         .rename_bid2(id_rename_pipeline_queue_rename_bid[2]),
                                         .rename_phy_reg_src1_2(id_rename_pipeline_queue_rename_phy_reg_src1[2]),
                                         .rename_phy_reg_src2_2(id_rename_pipeline_queue_rename_phy_reg_src2[2]),
                                         .rename_old_phy_reg_dst_2(id_rename_pipeline_queue_rename_old_phy_reg_dst[2]),
                                         .rename_new_phy_reg_dst_2(id_rename_pipeline_queue_rename_new_phy_reg_dst[2]),


                                         .rename_valid3(id_rename_pipeline_queue_rename_valid[3]),
                                         .rename_success3(id_rename_pipeline_queue_rename_success[3]),
                                         .rename_regfile_raddr1_3(id_rename_pipeline_queue_rename_regfile_raddr1[3]),
                                         .rename_regfile_raddr2_3(id_rename_pipeline_queue_rename_regfile_raddr2[3]),
                                         .rename_regfile_waddr_3(id_rename_pipeline_queue_rename_regfile_waddr[3]),
                                         .rename_regfile_we_3(id_rename_pipeline_queue_rename_regfile_we[3]),
                                         .rename_label3(id_rename_pipeline_queue_rename_label[3]),
                                         .rename_bid3(id_rename_pipeline_queue_rename_bid[3]),
                                         .rename_phy_reg_src1_3(id_rename_pipeline_queue_rename_phy_reg_src1[3]),
                                         .rename_phy_reg_src2_3(id_rename_pipeline_queue_rename_phy_reg_src2[3]),
                                         .rename_old_phy_reg_dst_3(id_rename_pipeline_queue_rename_old_phy_reg_dst[3]),
                                         .rename_new_phy_reg_dst_3(id_rename_pipeline_queue_rename_new_phy_reg_dst[3]),

                                         .occupancy(id_rename_pipeline_queue_occupancy),
                                         .full(id_rename_pipeline_queue_full),
                                         .empty(id_rename_pipeline_queue_empty),

                                         .branch_id_allocator_alloc_bid_ready(id_rename_pipeline_queue_branch_id_allocator_alloc_bid_ready),
                                         .branch_id_allocator_alloc_bid(id_rename_pipeline_queue_branch_id_allocator_alloc_bid),
                                         .branch_id_allocator_alloc_bid_valid(id_rename_pipeline_queue_branch_id_allocator_alloc_bid_valid),
                                         .branch_id_allocator_alloc_data(id_rename_pipeline_queue_branch_id_allocator_alloc_data),

                                         .b_flush_r(id_rename_pipeline_queue_b_flush_r),
                                         .target_b_r(id_rename_pipeline_queue_target_b_r),

                                         .fire_in(id_rename_pipeline_queue_in_fire)
                                     );




            wire                                          allocbid_clear;


            assign branch_id_allocator_alloc_pc             = id_rename_pipeline_queue_branch_id_allocator_alloc_data[95:64];
            assign branch_id_allocator_alloc_target_address = id_rename_pipeline_queue_branch_id_allocator_alloc_data[63:32];
            assign branch_id_allocator_alloc_imm            = id_rename_pipeline_queue_branch_id_allocator_alloc_data[31:0];
            assign branch_id_allocator_alloc_bid_valid      = id_rename_pipeline_queue_branch_id_allocator_alloc_bid_valid;

            assign branch_id_allocator_commit_branch_count =
                   {2'b00, rob_commit_fire[0] &&
                    rob_commit_inst_type[0] == `SEL_ISSUE_QUEUE_BRQ} +
                   {2'b00, rob_commit_fire[1] &&
                    rob_commit_inst_type[1] == `SEL_ISSUE_QUEUE_BRQ} +
                   {2'b00, rob_commit_fire[2] &&
                    rob_commit_inst_type[2] == `SEL_ISSUE_QUEUE_BRQ} +
                   {2'b00, rob_commit_fire[3] &&
                    rob_commit_inst_type[3] == `SEL_ISSUE_QUEUE_BRQ};

            assign branch_id_allocator_global_flush         = global_flush;

            assign branch_id_allocator_predict_flush        = predict_flush;
            assign branch_id_allocator_predict_flush_bid    = predict_flush_bid;

            assign branch_id_allocator_lookup_bid           = md_bru_issue_read_reg_out_bid;

            branch_id_allocator u_branch_id_allocator (
                                    .clk   (clk),
                                    .resetn(resetn),

                                    .alloc_pc            (branch_id_allocator_alloc_pc),
                                    .alloc_target_address(branch_id_allocator_alloc_target_address),
                                    .alloc_imm           (branch_id_allocator_alloc_imm),
                                    .alloc_bid_valid     (branch_id_allocator_alloc_bid_valid),
                                    .alloc_bid_ready     (branch_id_allocator_alloc_bid_ready),
                                    .alloc_bid           (branch_id_allocator_alloc_bid),

                                    .commit_branch_count(branch_id_allocator_commit_branch_count),

                                    .global_flush     (branch_id_allocator_global_flush),
                                    .predict_flush    (branch_id_allocator_predict_flush),
                                    .predict_flush_bid(branch_id_allocator_predict_flush_bid),

                                    .bid_head(branch_id_allocator_bid_head),
                                    .bid_tail(branch_id_allocator_bid_tail),

                                    .lookup_bid           (branch_id_allocator_lookup_bid),
                                    .lookup_pc            (branch_id_allocator_lookup_pc),
                                    .lookup_target_address(branch_id_allocator_lookup_target_address),
                                    .lookup_imm           (branch_id_allocator_lookup_imm)
                                );



            assign cam_rmt_update_writeback1_reg_dst = bypass1_dst;
            assign cam_rmt_update_writeback1_valid   = bypass1_valid;
            assign cam_rmt_update_writeback2_reg_dst = bypass2_dst;
            assign cam_rmt_update_writeback2_valid   = bypass2_valid;
            assign cam_rmt_update_writeback3_reg_dst = bypass3_dst;
            assign cam_rmt_update_writeback3_valid   = bypass3_valid;
            assign cam_rmt_update_writeback4_reg_dst = bypass4_dst;
            assign cam_rmt_update_writeback4_valid   = bypass4_valid;
            assign cam_rmt_update_writeback5_reg_dst = bypass5_dst;
            assign cam_rmt_update_writeback5_valid   = bypass5_valid;
            assign cam_rmt_update_writeback6_reg_dst = bypass6_dst;
            assign cam_rmt_update_writeback6_valid   = bypass6_valid;
            assign cam_rmt_update_writeback7_reg_dst = bypass7_dst;
            assign cam_rmt_update_writeback7_valid   = bypass7_valid;

            assign cam_rmt_update_commit_new_reg_dst[0] = rob_commit_new_pdest[0];
            assign cam_rmt_update_commit_new_reg_dst[1] = rob_commit_new_pdest[1];
            assign cam_rmt_update_commit_new_reg_dst[2] = rob_commit_new_pdest[2];
            assign cam_rmt_update_commit_new_reg_dst[3] = rob_commit_new_pdest[3];
            assign cam_rmt_update_commit_old_reg_dst[0] = rob_commit_old_pdest[0];
            assign cam_rmt_update_commit_old_reg_dst[1] = rob_commit_old_pdest[1];
            assign cam_rmt_update_commit_old_reg_dst[2] = rob_commit_old_pdest[2];
            assign cam_rmt_update_commit_old_reg_dst[3] = rob_commit_old_pdest[3];
            assign cam_rmt_update_commit_arch_reg_dst[0] = rob_commit_arch_dest[0];
            assign cam_rmt_update_commit_arch_reg_dst[1] = rob_commit_arch_dest[1];
            assign cam_rmt_update_commit_arch_reg_dst[2] = rob_commit_arch_dest[2];
            assign cam_rmt_update_commit_arch_reg_dst[3] = rob_commit_arch_dest[3];
            assign cam_rmt_update_commit_valid = rob_commit_fire &
                   rob_commit_regfile_we & ~rob_commit_is_exception;

            assign cam_rmt_flush                     = global_flush;

            assign cam_rmt_predict_flush             = predict_flush;
            assign cam_rmt_predict_flush_bid         = predict_flush_bid;
            assign cam_rmt_head_bid                  = branch_id_allocator_bid_head;

`ifdef difftest

            wire [6:0] rmt [31:0];


`endif

            wire [127:0] cam_rmt_phy_ready;

            cam_rmt u_cam_rmt (
                        .clk   (clk),
                        .resetn(resetn),

                        .lane0_arch_reg_src1(id_rename_pipeline_queue_rename_regfile_raddr1[0]),
                        .lane0_arch_reg_src2(id_rename_pipeline_queue_rename_regfile_raddr2[0]),
                        .lane0_arch_reg_dst(id_rename_pipeline_queue_rename_regfile_waddr[0]),
                        .lane0_rename_arch_reg_dst_valid(id_rename_pipeline_queue_rename_valid[0]),
                        .lane0_valid_copy_valid(id_rename_pipeline_queue_rename_label[0]),
                        .lane0_valid_copy_bid(id_rename_pipeline_queue_rename_bid[0]),

                        .lane0_phy_reg_src1(id_rename_pipeline_queue_rename_phy_reg_src1[0]),
                        .lane0_phy_reg_src2(id_rename_pipeline_queue_rename_phy_reg_src2[0]),
                        .lane0_old_phy_reg_dst(id_rename_pipeline_queue_rename_old_phy_reg_dst[0]),
                        .lane0_new_phy_reg_dst(id_rename_pipeline_queue_rename_new_phy_reg_dst[0]),
                        .lane0_rename_success(id_rename_pipeline_queue_rename_success[0]),

                        .lane1_arch_reg_src1(id_rename_pipeline_queue_rename_regfile_raddr1[1]),
                        .lane1_arch_reg_src2(id_rename_pipeline_queue_rename_regfile_raddr2[1]),
                        .lane1_arch_reg_dst(id_rename_pipeline_queue_rename_regfile_waddr[1]),
                        .lane1_rename_arch_reg_dst_valid(id_rename_pipeline_queue_rename_valid[1]),
                        .lane1_valid_copy_valid(id_rename_pipeline_queue_rename_label[1]),
                        .lane1_valid_copy_bid(id_rename_pipeline_queue_rename_bid[1]),

                        .lane1_phy_reg_src1(id_rename_pipeline_queue_rename_phy_reg_src1[1]),
                        .lane1_phy_reg_src2(id_rename_pipeline_queue_rename_phy_reg_src2[1]),
                        .lane1_old_phy_reg_dst(id_rename_pipeline_queue_rename_old_phy_reg_dst[1]),
                        .lane1_new_phy_reg_dst(id_rename_pipeline_queue_rename_new_phy_reg_dst[1]),
                        .lane1_rename_success(id_rename_pipeline_queue_rename_success[1]),


                        .lane2_arch_reg_src1(id_rename_pipeline_queue_rename_regfile_raddr1[2]),
                        .lane2_arch_reg_src2(id_rename_pipeline_queue_rename_regfile_raddr2[2]),
                        .lane2_arch_reg_dst(id_rename_pipeline_queue_rename_regfile_waddr[2]),
                        .lane2_rename_arch_reg_dst_valid(id_rename_pipeline_queue_rename_valid[2]),
                        .lane2_valid_copy_valid(id_rename_pipeline_queue_rename_label[2]),
                        .lane2_valid_copy_bid(id_rename_pipeline_queue_rename_bid[2]),

                        .lane2_phy_reg_src1(id_rename_pipeline_queue_rename_phy_reg_src1[2]),
                        .lane2_phy_reg_src2(id_rename_pipeline_queue_rename_phy_reg_src2[2]),
                        .lane2_old_phy_reg_dst(id_rename_pipeline_queue_rename_old_phy_reg_dst[2]),
                        .lane2_new_phy_reg_dst(id_rename_pipeline_queue_rename_new_phy_reg_dst[2]),
                        .lane2_rename_success(id_rename_pipeline_queue_rename_success[2]),


                        .lane3_arch_reg_src1(id_rename_pipeline_queue_rename_regfile_raddr1[3]),
                        .lane3_arch_reg_src2(id_rename_pipeline_queue_rename_regfile_raddr2[3]),
                        .lane3_arch_reg_dst(id_rename_pipeline_queue_rename_regfile_waddr[3]),
                        .lane3_rename_arch_reg_dst_valid(id_rename_pipeline_queue_rename_valid[3]),
                        .lane3_valid_copy_valid(id_rename_pipeline_queue_rename_label[3]),
                        .lane3_valid_copy_bid(id_rename_pipeline_queue_rename_bid[3]),

                        .lane3_phy_reg_src1(id_rename_pipeline_queue_rename_phy_reg_src1[3]),
                        .lane3_phy_reg_src2(id_rename_pipeline_queue_rename_phy_reg_src2[3]),
                        .lane3_old_phy_reg_dst(id_rename_pipeline_queue_rename_old_phy_reg_dst[3]),
                        .lane3_new_phy_reg_dst(id_rename_pipeline_queue_rename_new_phy_reg_dst[3]),
                        .lane3_rename_success(id_rename_pipeline_queue_rename_success[3]),

                        .update_writeback1_reg_dst(cam_rmt_update_writeback1_reg_dst),
                        .update_writeback1_valid  (cam_rmt_update_writeback1_valid),

                        .update_writeback2_reg_dst(cam_rmt_update_writeback2_reg_dst),
                        .update_writeback2_valid  (cam_rmt_update_writeback2_valid),

                        .update_writeback3_reg_dst(cam_rmt_update_writeback3_reg_dst),
                        .update_writeback3_valid  (cam_rmt_update_writeback3_valid),

                        .update_writeback4_reg_dst(cam_rmt_update_writeback4_reg_dst),
                        .update_writeback4_valid  (cam_rmt_update_writeback4_valid),

                        .update_writeback5_reg_dst(cam_rmt_update_writeback5_reg_dst),
                        .update_writeback5_valid  (cam_rmt_update_writeback5_valid),

                        .update_writeback6_reg_dst(cam_rmt_update_writeback6_reg_dst),
                        .update_writeback6_valid  (cam_rmt_update_writeback6_valid),

                        .update_writeback7_reg_dst(cam_rmt_update_writeback7_reg_dst),
                        .update_writeback7_valid  (cam_rmt_update_writeback7_valid),

                        .update_commit_valid(cam_rmt_update_commit_valid),
                        .update_commit_new_reg_dst_0(cam_rmt_update_commit_new_reg_dst[0]),
                        .update_commit_new_reg_dst_1(cam_rmt_update_commit_new_reg_dst[1]),
                        .update_commit_new_reg_dst_2(cam_rmt_update_commit_new_reg_dst[2]),
                        .update_commit_new_reg_dst_3(cam_rmt_update_commit_new_reg_dst[3]),
                        .update_commit_old_reg_dst_0(cam_rmt_update_commit_old_reg_dst[0]),
                        .update_commit_old_reg_dst_1(cam_rmt_update_commit_old_reg_dst[1]),
                        .update_commit_old_reg_dst_2(cam_rmt_update_commit_old_reg_dst[2]),
                        .update_commit_old_reg_dst_3(cam_rmt_update_commit_old_reg_dst[3]),
                        .update_commit_arch_reg_dst_0(cam_rmt_update_commit_arch_reg_dst[0]),
                        .update_commit_arch_reg_dst_1(cam_rmt_update_commit_arch_reg_dst[1]),
                        .update_commit_arch_reg_dst_2(cam_rmt_update_commit_arch_reg_dst[2]),
                        .update_commit_arch_reg_dst_3(cam_rmt_update_commit_arch_reg_dst[3]),

                        .phy_ready(cam_rmt_phy_ready),

                        .flush(cam_rmt_flush),

                        .predict_flush    (cam_rmt_predict_flush),
                        .predict_flush_bid(cam_rmt_predict_flush_bid),
                        .head_bid         (cam_rmt_head_bid)

`ifdef difftest

                        , .armt(rmt)


`endif
                    );

            wire rename_dispatch_pipeline_queue_flush;

            wire [3:0] rename_dispatch_pipeline_queue_in_valid;
            wire [3:0] rename_dispatch_pipeline_queue_in_ready;
            wire [`RENAME_OPCODE_LEN-1:0] rename_dispatch_pipeline_queue_in_data[3:0];
            wire  [4:0] rename_dispatch_pipeline_queue_in_bid[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_in_phy_reg_src1[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_in_phy_reg_src2[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_in_old_phy_reg_dst[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_in_new_phy_reg_dst[3:0];

            wire [3:0] rename_dispatch_pipeline_queue_out_valid;
            wire [3:0] rename_dispatch_pipeline_queue_out_ready;
            wire [`RENAME_OPCODE_LEN-1:0] rename_dispatch_pipeline_queue_out_data[3:0];
            wire  [4:0] rename_dispatch_pipeline_queue_out_bid[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_out_phy_reg_src1[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_out_phy_reg_src2[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_out_old_phy_reg_dst[3:0];
            wire [6:0] rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3:0];

            wire [3:0] rename_dispatch_pipeline_queue_occupancy;
            wire       rename_dispatch_pipeline_queue_full;
            wire       rename_dispatch_pipeline_queue_empty;

            assign rename_dispatch_pipeline_queue_flush = dispatch_clear;

            assign rename_dispatch_pipeline_queue_in_valid = id_rename_pipeline_queue_out_valid;

            assign rename_dispatch_pipeline_queue_in_data[0] = id_rename_pipeline_queue_out_data[0];
            assign rename_dispatch_pipeline_queue_in_bid[0] = id_rename_pipeline_queue_out_bid[0];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src1[0] = id_rename_pipeline_queue_rename_phy_reg_src1[0];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src2[0] = id_rename_pipeline_queue_rename_phy_reg_src2[0];
            assign rename_dispatch_pipeline_queue_in_old_phy_reg_dst[0] = id_rename_pipeline_queue_rename_old_phy_reg_dst[0];
            assign rename_dispatch_pipeline_queue_in_new_phy_reg_dst[0] = id_rename_pipeline_queue_rename_new_phy_reg_dst[0];


            assign rename_dispatch_pipeline_queue_in_data[1] = id_rename_pipeline_queue_out_data[1];
            assign rename_dispatch_pipeline_queue_in_bid[1] = id_rename_pipeline_queue_out_bid[1];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src1[1] = id_rename_pipeline_queue_rename_phy_reg_src1[1];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src2[1] = id_rename_pipeline_queue_rename_phy_reg_src2[1];
            assign rename_dispatch_pipeline_queue_in_old_phy_reg_dst[1] = id_rename_pipeline_queue_rename_old_phy_reg_dst[1];
            assign rename_dispatch_pipeline_queue_in_new_phy_reg_dst[1] = id_rename_pipeline_queue_rename_new_phy_reg_dst[1];


            assign rename_dispatch_pipeline_queue_in_data[2] = id_rename_pipeline_queue_out_data[2];
            assign rename_dispatch_pipeline_queue_in_bid[2] = id_rename_pipeline_queue_out_bid[2];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src1[2] = id_rename_pipeline_queue_rename_phy_reg_src1[2];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src2[2] = id_rename_pipeline_queue_rename_phy_reg_src2[2];
            assign rename_dispatch_pipeline_queue_in_old_phy_reg_dst[2] = id_rename_pipeline_queue_rename_old_phy_reg_dst[2];
            assign rename_dispatch_pipeline_queue_in_new_phy_reg_dst[2] = id_rename_pipeline_queue_rename_new_phy_reg_dst[2];


            assign rename_dispatch_pipeline_queue_in_data[3] = id_rename_pipeline_queue_out_data[3];
            assign rename_dispatch_pipeline_queue_in_bid[3] = id_rename_pipeline_queue_out_bid[3];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src1[3] = id_rename_pipeline_queue_rename_phy_reg_src1[3];
            assign rename_dispatch_pipeline_queue_in_phy_reg_src2[3] = id_rename_pipeline_queue_rename_phy_reg_src2[3];
            assign rename_dispatch_pipeline_queue_in_old_phy_reg_dst[3] = id_rename_pipeline_queue_rename_old_phy_reg_dst[3];
            assign rename_dispatch_pipeline_queue_in_new_phy_reg_dst[3] = id_rename_pipeline_queue_rename_new_phy_reg_dst[3];


            rename_dispatch_pipeline_queue u_rename_dispatch_pipeline_queue(
                                               .clk(clk),
                                               .resetn(resetn),

                                               .flush(rename_dispatch_pipeline_queue_flush),

                                               .in_valid0(rename_dispatch_pipeline_queue_in_valid[0]),
                                               .in_ready0(rename_dispatch_pipeline_queue_in_ready[0]),
                                               .in_data0(rename_dispatch_pipeline_queue_in_data[0]),
                                               .in_bid0(rename_dispatch_pipeline_queue_in_bid[0]),
                                               .in_phy_reg_src1_0(rename_dispatch_pipeline_queue_in_phy_reg_src1[0]),
                                               .in_phy_reg_src2_0(rename_dispatch_pipeline_queue_in_phy_reg_src2[0]),
                                               .in_old_phy_reg_dst_0(rename_dispatch_pipeline_queue_in_old_phy_reg_dst[0]),
                                               .in_new_phy_reg_dst_0(rename_dispatch_pipeline_queue_in_new_phy_reg_dst[0]),


                                               .in_valid1(rename_dispatch_pipeline_queue_in_valid[1]),
                                               .in_ready1(rename_dispatch_pipeline_queue_in_ready[1]),
                                               .in_data1(rename_dispatch_pipeline_queue_in_data[1]),
                                               .in_bid1(rename_dispatch_pipeline_queue_in_bid[1]),
                                               .in_phy_reg_src1_1(rename_dispatch_pipeline_queue_in_phy_reg_src1[1]),
                                               .in_phy_reg_src2_1(rename_dispatch_pipeline_queue_in_phy_reg_src2[1]),
                                               .in_old_phy_reg_dst_1(rename_dispatch_pipeline_queue_in_old_phy_reg_dst[1]),
                                               .in_new_phy_reg_dst_1(rename_dispatch_pipeline_queue_in_new_phy_reg_dst[1]),


                                               .in_valid2(rename_dispatch_pipeline_queue_in_valid[2]),
                                               .in_ready2(rename_dispatch_pipeline_queue_in_ready[2]),
                                               .in_data2(rename_dispatch_pipeline_queue_in_data[2]),
                                               .in_bid2(rename_dispatch_pipeline_queue_in_bid[2]),
                                               .in_phy_reg_src1_2(rename_dispatch_pipeline_queue_in_phy_reg_src1[2]),
                                               .in_phy_reg_src2_2(rename_dispatch_pipeline_queue_in_phy_reg_src2[2]),
                                               .in_old_phy_reg_dst_2(rename_dispatch_pipeline_queue_in_old_phy_reg_dst[2]),
                                               .in_new_phy_reg_dst_2(rename_dispatch_pipeline_queue_in_new_phy_reg_dst[2]),


                                               .in_valid3(rename_dispatch_pipeline_queue_in_valid[3]),
                                               .in_ready3(rename_dispatch_pipeline_queue_in_ready[3]),
                                               .in_data3(rename_dispatch_pipeline_queue_in_data[3]),
                                               .in_bid3(rename_dispatch_pipeline_queue_in_bid[3]),
                                               .in_phy_reg_src1_3(rename_dispatch_pipeline_queue_in_phy_reg_src1[3]),
                                               .in_phy_reg_src2_3(rename_dispatch_pipeline_queue_in_phy_reg_src2[3]),
                                               .in_old_phy_reg_dst_3(rename_dispatch_pipeline_queue_in_old_phy_reg_dst[3]),
                                               .in_new_phy_reg_dst_3(rename_dispatch_pipeline_queue_in_new_phy_reg_dst[3]),





                                               .out_valid0(rename_dispatch_pipeline_queue_out_valid[0]),
                                               .out_ready0(rename_dispatch_pipeline_queue_out_ready[0]),
                                               .out_data0(rename_dispatch_pipeline_queue_out_data[0]),
                                               .out_bid0(rename_dispatch_pipeline_queue_out_bid[0]),
                                               .out_phy_reg_src1_0(rename_dispatch_pipeline_queue_out_phy_reg_src1[0]),
                                               .out_phy_reg_src2_0(rename_dispatch_pipeline_queue_out_phy_reg_src2[0]),
                                               .out_old_phy_reg_dst_0(rename_dispatch_pipeline_queue_out_old_phy_reg_dst[0]),
                                               .out_new_phy_reg_dst_0(rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0]),


                                               .out_valid1(rename_dispatch_pipeline_queue_out_valid[1]),
                                               .out_ready1(rename_dispatch_pipeline_queue_out_ready[1]),
                                               .out_data1(rename_dispatch_pipeline_queue_out_data[1]),
                                               .out_bid1(rename_dispatch_pipeline_queue_out_bid[1]),
                                               .out_phy_reg_src1_1(rename_dispatch_pipeline_queue_out_phy_reg_src1[1]),
                                               .out_phy_reg_src2_1(rename_dispatch_pipeline_queue_out_phy_reg_src2[1]),
                                               .out_old_phy_reg_dst_1(rename_dispatch_pipeline_queue_out_old_phy_reg_dst[1]),
                                               .out_new_phy_reg_dst_1(rename_dispatch_pipeline_queue_out_new_phy_reg_dst[1]),


                                               .out_valid2(rename_dispatch_pipeline_queue_out_valid[2]),
                                               .out_ready2(rename_dispatch_pipeline_queue_out_ready[2]),
                                               .out_data2(rename_dispatch_pipeline_queue_out_data[2]),
                                               .out_bid2(rename_dispatch_pipeline_queue_out_bid[2]),
                                               .out_phy_reg_src1_2(rename_dispatch_pipeline_queue_out_phy_reg_src1[2]),
                                               .out_phy_reg_src2_2(rename_dispatch_pipeline_queue_out_phy_reg_src2[2]),
                                               .out_old_phy_reg_dst_2(rename_dispatch_pipeline_queue_out_old_phy_reg_dst[2]),
                                               .out_new_phy_reg_dst_2(rename_dispatch_pipeline_queue_out_new_phy_reg_dst[2]),


                                               .out_valid3(rename_dispatch_pipeline_queue_out_valid[3]),
                                               .out_ready3(rename_dispatch_pipeline_queue_out_ready[3]),
                                               .out_data3(rename_dispatch_pipeline_queue_out_data[3]),
                                               .out_bid3(rename_dispatch_pipeline_queue_out_bid[3]),
                                               .out_phy_reg_src1_3(rename_dispatch_pipeline_queue_out_phy_reg_src1[3]),
                                               .out_phy_reg_src2_3(rename_dispatch_pipeline_queue_out_phy_reg_src2[3]),
                                               .out_old_phy_reg_dst_3(rename_dispatch_pipeline_queue_out_old_phy_reg_dst[3]),
                                               .out_new_phy_reg_dst_3(rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3]),

                                               .occupancy(rename_dispatch_pipeline_queue_occupancy),
                                               .full(rename_dispatch_pipeline_queue_full),
                                               .empty(rename_dispatch_pipeline_queue_empty)
                                           );



            wire                                          dispatch_clear;


            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_exception;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_sys;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_int;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_ertn_flush;
            wire [                                  13:0] rename_dispatch_pipeline_queue_out_csr_addr [3:0];
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_csr_we;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_csr_re;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_sel_csr_wmask;

            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_adef;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_ine;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_brk;
            wire [3:0] rename_dispatch_pipeline_queue_out_wb_refetch;
            wire [3:0] rename_dispatch_pipeline_queue_out_is_cacop;

            // wire        rename_dispatch_pipeline_queue_out_tlb_we;
            wire [                                   4:0] rename_dispatch_pipeline_queue_out_invtlb_op [3:0];
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_tlbsrch;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_tlbrd;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_tlbwr;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_tlbfill;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_invtlb;

            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_tlbr;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_tlbr;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_pif;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_is_inst_ppi;


            wire [                                  31:0] rename_dispatch_pipeline_queue_out_pc [3:0];
            wire [                                  31:0] rename_dispatch_pipeline_queue_out_instruction [3:0];
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy;
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy;
            wire [                                   4:0] rename_dispatch_pipeline_queue_out_regfile_waddr [3:0];
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_regfile_we;
            wire [                                   1:0] rename_dispatch_pipeline_queue_out_sel_npc [3:0];
            wire [                                   4:0] rename_dispatch_pipeline_queue_out_alu_op [3:0];
            wire [                                   2:0] rename_dispatch_pipeline_queue_out_comparator_op [3:0];
            wire [                                   2:0] rename_dispatch_pipeline_queue_out_sel_issue_queue [3:0];
            wire [3:0]                                    rename_dispatch_pipeline_queue_out_sel_imm;
            wire [                                  31:0] rename_dispatch_pipeline_queue_out_extended_imm [3:0];
            wire [                                   6:0] rename_dispatch_pipeline_queue_out_md_op [3:0];
            wire [                                   2:0] rename_dispatch_pipeline_queue_out_sel_load_store_len [3:0];



            wire [3:0]                                    rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy;
            wire [3:0]                                    rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy;

            wire [4:0] rename_dispatch_pipeline_queue_out_regfile_raddr1 [3:0];
            wire [4:0] rename_dispatch_pipeline_queue_out_regfile_raddr2 [3:0];
            wire [31:0] rename_dispatch_pipeline_queue_out_predict_target_address [3:0];
            wire [3:0] rename_dispatch_pipeline_queue_out_is_ll_w;
            wire [3:0] rename_dispatch_pipeline_queue_out_is_sc_w;
            wire [3:0] rename_dispatch_pipeline_queue_out_is_dbar;

            wire [3:0] dispatch_fire;

            wire [3:0] dispatch_ctrl_lsu_bias_valid;
            wire [3:0] dispatch_ctrl_fast_bias_valid;

            dispatch_ctrl u_dispatch_ctrl (
                              .clear(dispatch_clear),
                              .in_valid(rename_dispatch_pipeline_queue_out_valid),
                              .in_is_exception(rename_dispatch_pipeline_queue_out_is_exception),
                              .in_sel_issue_queue_0(rename_dispatch_pipeline_queue_out_sel_issue_queue[0]),
                              .in_sel_issue_queue_1(rename_dispatch_pipeline_queue_out_sel_issue_queue[1]),
                              .in_sel_issue_queue_2(rename_dispatch_pipeline_queue_out_sel_issue_queue[2]),
                              .in_sel_issue_queue_3(rename_dispatch_pipeline_queue_out_sel_issue_queue[3]),
                              .alu_dispatch_ready(alu_issue_queue_dispatch_ready),
                              .md_dispatch_ready(md_issue_queue_dispatch_ready),
                              .privilege_dispatch_ready(privilege_issue_queue_dispatch_ready),
                              .rob_alloc_ready(rob_alloc_ready),
                              .lsu_count(lsu_issue_queue_count),
                              .fast_count(fast_issue_queue_count),
                              .out_ready(rename_dispatch_pipeline_queue_out_ready),
                              .dispatch_fire(dispatch_fire),
                              .alu_dispatch_valid(alu_issue_queue_dispatch_valid),
                              .lsu_dispatch_valid(lsu_issue_queue_dispatch_valid),
                              .md_dispatch_valid(md_issue_queue_dispatch_valid),
                              .fast_dispatch_valid(fast_issue_queue_dispatch_valid),
                              .privilege_dispatch_valid(privilege_issue_queue_dispatch_valid),
                              .rob_alloc_valid(rob_alloc_valid),

                              .lsu_bias_valid(dispatch_ctrl_lsu_bias_valid),
                              .fast_bias_valid(dispatch_ctrl_fast_bias_valid)
                          );

            assign
                {
                    rename_dispatch_pipeline_queue_out_is_exception[0],           // [210]
                    rename_dispatch_pipeline_queue_out_is_sys[0],                 // [209]
                    rename_dispatch_pipeline_queue_out_is_int[0],                 // [208]
                    rename_dispatch_pipeline_queue_out_ertn_flush[0],             // [207]
                    rename_dispatch_pipeline_queue_out_csr_addr[0],               // [206:193]
                    rename_dispatch_pipeline_queue_out_csr_we[0],                 // [192]
                    rename_dispatch_pipeline_queue_out_csr_re[0],                 // [191]
                    rename_dispatch_pipeline_queue_out_sel_csr_wmask[0],          // [190]
                    rename_dispatch_pipeline_queue_out_is_adef[0],                // [189]
                    rename_dispatch_pipeline_queue_out_is_ine[0],                 // [188]
                    rename_dispatch_pipeline_queue_out_is_brk[0],                 // [187]
                    rename_dispatch_pipeline_queue_out_invtlb_op[0],              // [186:182]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbsrch[0],        // [181]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbrd[0],          // [180]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbwr[0],          // [179]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbfill[0],        // [178]
                    rename_dispatch_pipeline_queue_out_is_inst_invtlb[0],         // [177]
                    rename_dispatch_pipeline_queue_out_is_tlbr[0],                // [176]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbr[0],           // [175]
                    rename_dispatch_pipeline_queue_out_is_inst_pif[0],            // [174]
                    rename_dispatch_pipeline_queue_out_is_inst_ppi[0],            // [173]
                    rename_dispatch_pipeline_queue_out_wb_refetch[0],             // [172]
                    rename_dispatch_pipeline_queue_out_is_cacop[0],               // [171]
                    rename_dispatch_pipeline_queue_out_pc[0],                       // [170:139]
                    rename_dispatch_pipeline_queue_out_instruction[0],              // [138:107]
                    rename_dispatch_pipeline_queue_out_regfile_raddr1[0],           // [106:102]
                    rename_dispatch_pipeline_queue_out_regfile_raddr2[0],           // [101:97]
                    rename_dispatch_pipeline_queue_out_regfile_we[0],               // [96]
                    rename_dispatch_pipeline_queue_out_regfile_waddr[0],            // [95:91]
                    rename_dispatch_pipeline_queue_out_sel_npc[0],                  // [90:89]
                    rename_dispatch_pipeline_queue_out_alu_op[0],                   // [88:84]
                    rename_dispatch_pipeline_queue_out_comparator_op[0],            // [83:81]
                    rename_dispatch_pipeline_queue_out_sel_issue_queue[0],          // [80:78]
                    rename_dispatch_pipeline_queue_out_sel_imm[0],                  // [77]
                    rename_dispatch_pipeline_queue_out_extended_imm[0],             // [76:45]
                    rename_dispatch_pipeline_queue_out_md_op[0],                    // [44:38]
                    rename_dispatch_pipeline_queue_out_sel_load_store_len[0],       // [37:35]
                    rename_dispatch_pipeline_queue_out_predict_target_address[0],   // [34:3]
                    rename_dispatch_pipeline_queue_out_is_ll_w[0],                // [2]
                    rename_dispatch_pipeline_queue_out_is_sc_w[0],                // [1]
                    rename_dispatch_pipeline_queue_out_is_dbar[0]                 // [0]
                } = rename_dispatch_pipeline_queue_out_data[0];

            assign rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[0] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src1[0]]||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[0] == bypass7_dst));
            assign rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[0] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src2[0]] ||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[0] == bypass7_dst));
            assign rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[0] = rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[0];
            assign rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[0] = rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[0];




            assign
                {
                    rename_dispatch_pipeline_queue_out_is_exception[1],           // [210]
                    rename_dispatch_pipeline_queue_out_is_sys[1],                 // [209]
                    rename_dispatch_pipeline_queue_out_is_int[1],                 // [208]
                    rename_dispatch_pipeline_queue_out_ertn_flush[1],             // [207]
                    rename_dispatch_pipeline_queue_out_csr_addr[1],               // [206:193]
                    rename_dispatch_pipeline_queue_out_csr_we[1],                 // [192]
                    rename_dispatch_pipeline_queue_out_csr_re[1],                 // [191]
                    rename_dispatch_pipeline_queue_out_sel_csr_wmask[1],          // [190]
                    rename_dispatch_pipeline_queue_out_is_adef[1],                // [189]
                    rename_dispatch_pipeline_queue_out_is_ine[1],                 // [188]
                    rename_dispatch_pipeline_queue_out_is_brk[1],                 // [187]
                    rename_dispatch_pipeline_queue_out_invtlb_op[1],              // [186:182]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbsrch[1],        // [181]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbrd[1],          // [180]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbwr[1],          // [179]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbfill[1],        // [178]
                    rename_dispatch_pipeline_queue_out_is_inst_invtlb[1],         // [177]
                    rename_dispatch_pipeline_queue_out_is_tlbr[1],                // [176]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbr[1],           // [175]
                    rename_dispatch_pipeline_queue_out_is_inst_pif[1],            // [174]
                    rename_dispatch_pipeline_queue_out_is_inst_ppi[1],            // [173]
                    rename_dispatch_pipeline_queue_out_wb_refetch[1],             // [172]
                    rename_dispatch_pipeline_queue_out_is_cacop[1],               // [171]
                    rename_dispatch_pipeline_queue_out_pc[1],                       // [170:139]
                    rename_dispatch_pipeline_queue_out_instruction[1],              // [138:107]
                    rename_dispatch_pipeline_queue_out_regfile_raddr1[1],           // [106:102]
                    rename_dispatch_pipeline_queue_out_regfile_raddr2[1],           // [101:97]
                    rename_dispatch_pipeline_queue_out_regfile_we[1],               // [96]
                    rename_dispatch_pipeline_queue_out_regfile_waddr[1],            // [95:91]
                    rename_dispatch_pipeline_queue_out_sel_npc[1],                  // [90:89]
                    rename_dispatch_pipeline_queue_out_alu_op[1],                   // [88:84]
                    rename_dispatch_pipeline_queue_out_comparator_op[1],            // [83:81]
                    rename_dispatch_pipeline_queue_out_sel_issue_queue[1],          // [80:78]
                    rename_dispatch_pipeline_queue_out_sel_imm[1],                  // [77]
                    rename_dispatch_pipeline_queue_out_extended_imm[1],             // [76:45]
                    rename_dispatch_pipeline_queue_out_md_op[1],                    // [44:38]
                    rename_dispatch_pipeline_queue_out_sel_load_store_len[1],       // [37:35]
                    rename_dispatch_pipeline_queue_out_predict_target_address[1],   // [34:3]
                    rename_dispatch_pipeline_queue_out_is_ll_w[1],                // [2]
                    rename_dispatch_pipeline_queue_out_is_sc_w[1],                // [1]
                    rename_dispatch_pipeline_queue_out_is_dbar[1]                 // [1]
                } = rename_dispatch_pipeline_queue_out_data[1];
            assign rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[1] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src1[1]] ||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[1]== bypass7_dst));
            assign rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[1] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src2[1]]||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[1]== bypass7_dst));
            assign rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[1] = rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[1];
            assign rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[1] = rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[1];





            assign
                {
                    rename_dispatch_pipeline_queue_out_is_exception[2],           // [210]
                    rename_dispatch_pipeline_queue_out_is_sys[2],                 // [209]
                    rename_dispatch_pipeline_queue_out_is_int[2],                 // [208]
                    rename_dispatch_pipeline_queue_out_ertn_flush[2],             // [207]
                    rename_dispatch_pipeline_queue_out_csr_addr[2],               // [206:193]
                    rename_dispatch_pipeline_queue_out_csr_we[2],                 // [192]
                    rename_dispatch_pipeline_queue_out_csr_re[2],                 // [191]
                    rename_dispatch_pipeline_queue_out_sel_csr_wmask[2],          // [190]
                    rename_dispatch_pipeline_queue_out_is_adef[2],                // [189]
                    rename_dispatch_pipeline_queue_out_is_ine[2],                 // [188]
                    rename_dispatch_pipeline_queue_out_is_brk[2],                 // [187]
                    rename_dispatch_pipeline_queue_out_invtlb_op[2],              // [186:182]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbsrch[2],        // [181]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbrd[2],          // [180]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbwr[2],          // [179]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbfill[2],        // [178]
                    rename_dispatch_pipeline_queue_out_is_inst_invtlb[2],         // [177]
                    rename_dispatch_pipeline_queue_out_is_tlbr[2],                // [176]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbr[2],           // [175]
                    rename_dispatch_pipeline_queue_out_is_inst_pif[2],            // [174]
                    rename_dispatch_pipeline_queue_out_is_inst_ppi[2],            // [173]
                    rename_dispatch_pipeline_queue_out_wb_refetch[2],             // [172]
                    rename_dispatch_pipeline_queue_out_is_cacop[2],               // [171]
                    rename_dispatch_pipeline_queue_out_pc[2],                       // [170:139]
                    rename_dispatch_pipeline_queue_out_instruction[2],              // [138:107]
                    rename_dispatch_pipeline_queue_out_regfile_raddr1[2],           // [106:102]
                    rename_dispatch_pipeline_queue_out_regfile_raddr2[2],           // [101:97]
                    rename_dispatch_pipeline_queue_out_regfile_we[2],               // [96]
                    rename_dispatch_pipeline_queue_out_regfile_waddr[2],            // [95:91]
                    rename_dispatch_pipeline_queue_out_sel_npc[2],                  // [90:89]
                    rename_dispatch_pipeline_queue_out_alu_op[2],                   // [88:84]
                    rename_dispatch_pipeline_queue_out_comparator_op[2],            // [83:81]
                    rename_dispatch_pipeline_queue_out_sel_issue_queue[2],          // [80:78]
                    rename_dispatch_pipeline_queue_out_sel_imm[2],                  // [77]
                    rename_dispatch_pipeline_queue_out_extended_imm[2],             // [76:45]
                    rename_dispatch_pipeline_queue_out_md_op[2],                    // [44:38]
                    rename_dispatch_pipeline_queue_out_sel_load_store_len[2],       // [37:35]
                    rename_dispatch_pipeline_queue_out_predict_target_address[2],   // [34:3]
                    rename_dispatch_pipeline_queue_out_is_ll_w[2],                // [2]
                    rename_dispatch_pipeline_queue_out_is_sc_w[2],                // [1]
                    rename_dispatch_pipeline_queue_out_is_dbar[2]                 // [2]
                } = rename_dispatch_pipeline_queue_out_data[2];
            assign rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[2] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src1[2]] ||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[2]== bypass7_dst));
            assign rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[2] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src2[2]]||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[2]== bypass7_dst));
            assign rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[2] = rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[2];
            assign rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[2] = rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[2];




            assign
                {
                    rename_dispatch_pipeline_queue_out_is_exception[3],           // [210]
                    rename_dispatch_pipeline_queue_out_is_sys[3],                 // [209]
                    rename_dispatch_pipeline_queue_out_is_int[3],                 // [208]
                    rename_dispatch_pipeline_queue_out_ertn_flush[3],             // [207]
                    rename_dispatch_pipeline_queue_out_csr_addr[3],               // [206:193]
                    rename_dispatch_pipeline_queue_out_csr_we[3],                 // [192]
                    rename_dispatch_pipeline_queue_out_csr_re[3],                 // [191]
                    rename_dispatch_pipeline_queue_out_sel_csr_wmask[3],          // [190]
                    rename_dispatch_pipeline_queue_out_is_adef[3],                // [189]
                    rename_dispatch_pipeline_queue_out_is_ine[3],                 // [188]
                    rename_dispatch_pipeline_queue_out_is_brk[3],                 // [187]
                    rename_dispatch_pipeline_queue_out_invtlb_op[3],              // [186:182]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbsrch[3],        // [181]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbrd[3],          // [180]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbwr[3],          // [179]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbfill[3],        // [178]
                    rename_dispatch_pipeline_queue_out_is_inst_invtlb[3],         // [177]
                    rename_dispatch_pipeline_queue_out_is_tlbr[3],                // [176]
                    rename_dispatch_pipeline_queue_out_is_inst_tlbr[3],           // [175]
                    rename_dispatch_pipeline_queue_out_is_inst_pif[3],            // [174]
                    rename_dispatch_pipeline_queue_out_is_inst_ppi[3],            // [173]
                    rename_dispatch_pipeline_queue_out_wb_refetch[3],             // [172]
                    rename_dispatch_pipeline_queue_out_is_cacop[3],               // [171]
                    rename_dispatch_pipeline_queue_out_pc[3],                       // [170:139]
                    rename_dispatch_pipeline_queue_out_instruction[3],              // [138:107]
                    rename_dispatch_pipeline_queue_out_regfile_raddr1[3],           // [106:102]
                    rename_dispatch_pipeline_queue_out_regfile_raddr2[3],           // [101:97]
                    rename_dispatch_pipeline_queue_out_regfile_we[3],               // [96]
                    rename_dispatch_pipeline_queue_out_regfile_waddr[3],            // [95:91]
                    rename_dispatch_pipeline_queue_out_sel_npc[3],                  // [90:89]
                    rename_dispatch_pipeline_queue_out_alu_op[3],                   // [88:84]
                    rename_dispatch_pipeline_queue_out_comparator_op[3],            // [83:81]
                    rename_dispatch_pipeline_queue_out_sel_issue_queue[3],          // [80:78]
                    rename_dispatch_pipeline_queue_out_sel_imm[3],                  // [77]
                    rename_dispatch_pipeline_queue_out_extended_imm[3],             // [76:45]
                    rename_dispatch_pipeline_queue_out_md_op[3],                    // [44:38]
                    rename_dispatch_pipeline_queue_out_sel_load_store_len[3],       // [37:35]
                    rename_dispatch_pipeline_queue_out_predict_target_address[3],   // [34:3]
                    rename_dispatch_pipeline_queue_out_is_ll_w[3],                // [2]
                    rename_dispatch_pipeline_queue_out_is_sc_w[3],                // [1]
                    rename_dispatch_pipeline_queue_out_is_dbar[3]                 // [3]
                } = rename_dispatch_pipeline_queue_out_data[3];
            assign rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[3] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src1[3]] ||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src1[3]== bypass7_dst));
            assign rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[3] = cam_rmt_phy_ready[rename_dispatch_pipeline_queue_out_phy_reg_src2[3]]||
                   (bypass1_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3] == bypass1_dst)) ||
                   (bypass2_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3] == bypass2_dst)) ||
                   (bypass3_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3] == bypass3_dst)) ||
                   (bypass4_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3] == bypass4_dst)) ||
                   (bypass5_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3] == bypass5_dst)) ||
                   (bypass6_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3] == bypass6_dst)) ||
                   (bypass7_valid && (rename_dispatch_pipeline_queue_out_phy_reg_src2[3]== bypass7_dst));
            assign rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[3] = rename_dispatch_pipeline_queue_out_phy_reg_src1_rdy[3];
            assign rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[3] = rename_dispatch_pipeline_queue_out_phy_reg_src2_rdy[3];




            assign alu_issue_queue_flush             = issue_clear;

            assign alu_issue_queue_dispatch_opcode[0]   = {rename_dispatch_pipeline_queue_out_regfile_we[0], rename_dispatch_pipeline_queue_out_alu_op[0], rename_dispatch_pipeline_queue_out_sel_imm[0]};
            assign alu_issue_queue_dispatch_pdest[0]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0];
            assign alu_issue_queue_dispatch_psrc0[0]    = rename_dispatch_pipeline_queue_out_phy_reg_src1[0];
            assign alu_issue_queue_dispatch_prdy0[0]    = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[0];  //
            assign alu_issue_queue_dispatch_psrc1[0]    = rename_dispatch_pipeline_queue_out_phy_reg_src2[0];
            assign alu_issue_queue_dispatch_prdy1[0]    = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[0];  //
            assign alu_issue_queue_dispatch_imm[0]      = rename_dispatch_pipeline_queue_out_extended_imm[0];
            assign alu_issue_queue_dispatch_rob_id[0]   = rob_alloc_rob_id[0];
            assign alu_issue_queue_dispatch_bid[0]      = rename_dispatch_pipeline_queue_out_bid[0];

            assign alu_issue_queue_dispatch_opcode[1]   = {rename_dispatch_pipeline_queue_out_regfile_we[1], rename_dispatch_pipeline_queue_out_alu_op[1], rename_dispatch_pipeline_queue_out_sel_imm[1]};
            assign alu_issue_queue_dispatch_pdest[1]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[1];
            assign alu_issue_queue_dispatch_psrc0[1]    = rename_dispatch_pipeline_queue_out_phy_reg_src1[1];
            assign alu_issue_queue_dispatch_prdy0[1]    = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[1];  //
            assign alu_issue_queue_dispatch_psrc1[1]    = rename_dispatch_pipeline_queue_out_phy_reg_src2[1];
            assign alu_issue_queue_dispatch_prdy1[1]    = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[1];  //
            assign alu_issue_queue_dispatch_imm[1]      = rename_dispatch_pipeline_queue_out_extended_imm[1];
            assign alu_issue_queue_dispatch_rob_id[1]   = rob_alloc_rob_id[1];
            assign alu_issue_queue_dispatch_bid[1]      = rename_dispatch_pipeline_queue_out_bid[1];


            assign alu_issue_queue_dispatch_opcode[2]   = {rename_dispatch_pipeline_queue_out_regfile_we[2], rename_dispatch_pipeline_queue_out_alu_op[2], rename_dispatch_pipeline_queue_out_sel_imm[2]};
            assign alu_issue_queue_dispatch_pdest[2]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[2];
            assign alu_issue_queue_dispatch_psrc0[2]    = rename_dispatch_pipeline_queue_out_phy_reg_src1[2];
            assign alu_issue_queue_dispatch_prdy0[2]    = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[2];  //
            assign alu_issue_queue_dispatch_psrc1[2]    = rename_dispatch_pipeline_queue_out_phy_reg_src2[2];
            assign alu_issue_queue_dispatch_prdy1[2]    = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[2];  //
            assign alu_issue_queue_dispatch_imm[2]      = rename_dispatch_pipeline_queue_out_extended_imm[2];
            assign alu_issue_queue_dispatch_rob_id[2]   = rob_alloc_rob_id[2];
            assign alu_issue_queue_dispatch_bid[2]      = rename_dispatch_pipeline_queue_out_bid[2];

            assign alu_issue_queue_dispatch_opcode[3]   = {rename_dispatch_pipeline_queue_out_regfile_we[3], rename_dispatch_pipeline_queue_out_alu_op[3], rename_dispatch_pipeline_queue_out_sel_imm[3]};
            assign alu_issue_queue_dispatch_pdest[3]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3];
            assign alu_issue_queue_dispatch_psrc0[3]    = rename_dispatch_pipeline_queue_out_phy_reg_src1[3];
            assign alu_issue_queue_dispatch_prdy0[3]    = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[3];  //
            assign alu_issue_queue_dispatch_psrc1[3]    = rename_dispatch_pipeline_queue_out_phy_reg_src2[3];
            assign alu_issue_queue_dispatch_prdy1[3]    = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[3];  //
            assign alu_issue_queue_dispatch_imm[3]      = rename_dispatch_pipeline_queue_out_extended_imm[3];
            assign alu_issue_queue_dispatch_rob_id[3]   = rob_alloc_rob_id[3];
            assign alu_issue_queue_dispatch_bid[3]      = rename_dispatch_pipeline_queue_out_bid[3];

            assign alu_issue_queue_bypass1_valid     = bypass1_valid;
            assign alu_issue_queue_bypass1_dst       = bypass1_dst;
            assign alu_issue_queue_bypass2_valid     = bypass2_valid;
            assign alu_issue_queue_bypass2_dst       = bypass2_dst;

            assign alu_issue_queue_issue_ready       = !issue_queue_stall;
            assign alu_issue_queue_extra_issue_ready = !issue_queue_extra_stall && !sel_privilege_issue;


            assign alu_issue_queue_bypass3_valid     = bypass3_valid;
            assign alu_issue_queue_bypass3_dst       = bypass3_dst;
            assign alu_issue_queue_bypass4_valid     = bypass4_valid;
            assign alu_issue_queue_bypass4_dst       = bypass4_dst;
            assign alu_issue_queue_bypass5_valid     = bypass5_valid;
            assign alu_issue_queue_bypass5_dst       = bypass5_dst;
            assign alu_issue_queue_bypass6_valid     = bypass6_valid;
            assign alu_issue_queue_bypass6_dst       = bypass6_dst;
            assign alu_issue_queue_bypass7_valid     = bypass7_valid;
            assign alu_issue_queue_bypass7_dst       = bypass7_dst;


            assign alu_issue_queue_predict_flush     = predict_flush;
            assign alu_issue_queue_predict_flush_bid = predict_flush_bid;
            assign alu_issue_queue_head_bid          = branch_id_allocator_bid_head;




            alu_issue_queue_lutram_core u_alu_issue_queue (
                                            .clk   (clk),
                                            .resetn(resetn),

                                            .flush(alu_issue_queue_flush),

                                            .dispatch_valid (alu_issue_queue_dispatch_valid),
                                            .dispatch_ready (alu_issue_queue_dispatch_ready),

                                            .dispatch_prdy0(alu_issue_queue_dispatch_prdy0),
                                            .dispatch_prdy1(alu_issue_queue_dispatch_prdy1),

                                            .dispatch_opcode_0(alu_issue_queue_dispatch_opcode[0]),
                                            .dispatch_pdest_0 (alu_issue_queue_dispatch_pdest[0]),
                                            .dispatch_psrc0_0 (alu_issue_queue_dispatch_psrc0[0]),
                                            .dispatch_psrc1_0 (alu_issue_queue_dispatch_psrc1[0]),
                                            .dispatch_imm_0   (alu_issue_queue_dispatch_imm[0]),
                                            .dispatch_bid_0   (alu_issue_queue_dispatch_bid[0]),
                                            .dispatch_rob_id_0(alu_issue_queue_dispatch_rob_id[0]),



                                            .dispatch_opcode_1(alu_issue_queue_dispatch_opcode[1]),
                                            .dispatch_pdest_1 (alu_issue_queue_dispatch_pdest[1]),
                                            .dispatch_psrc0_1 (alu_issue_queue_dispatch_psrc0[1]),
                                            .dispatch_psrc1_1 (alu_issue_queue_dispatch_psrc1[1]),
                                            .dispatch_imm_1   (alu_issue_queue_dispatch_imm[1]),
                                            .dispatch_bid_1   (alu_issue_queue_dispatch_bid[1]),
                                            .dispatch_rob_id_1(alu_issue_queue_dispatch_rob_id[1]),




                                            .dispatch_opcode_2(alu_issue_queue_dispatch_opcode[2]),
                                            .dispatch_pdest_2 (alu_issue_queue_dispatch_pdest[2]),
                                            .dispatch_psrc0_2 (alu_issue_queue_dispatch_psrc0[2]),
                                            .dispatch_psrc1_2 (alu_issue_queue_dispatch_psrc1[2]),
                                            .dispatch_imm_2   (alu_issue_queue_dispatch_imm[2]),
                                            .dispatch_bid_2   (alu_issue_queue_dispatch_bid[2]),
                                            .dispatch_rob_id_2(alu_issue_queue_dispatch_rob_id[2]),



                                            .dispatch_opcode_3(alu_issue_queue_dispatch_opcode[3]),
                                            .dispatch_pdest_3 (alu_issue_queue_dispatch_pdest[3]),
                                            .dispatch_psrc0_3 (alu_issue_queue_dispatch_psrc0[3]),
                                            .dispatch_psrc1_3 (alu_issue_queue_dispatch_psrc1[3]),
                                            .dispatch_imm_3   (alu_issue_queue_dispatch_imm[3]),
                                            .dispatch_bid_3   (alu_issue_queue_dispatch_bid[3]),
                                            .dispatch_rob_id_3(alu_issue_queue_dispatch_rob_id[3]),


                                            .bypass1_valid(alu_issue_queue_bypass1_valid),
                                            .bypass1_dst  (alu_issue_queue_bypass1_dst),
                                            .bypass2_valid(alu_issue_queue_bypass2_valid),
                                            .bypass2_dst  (alu_issue_queue_bypass2_dst),
                                            .bypass3_valid(alu_issue_queue_bypass3_valid),
                                            .bypass3_dst  (alu_issue_queue_bypass3_dst),
                                            .bypass4_valid(alu_issue_queue_bypass4_valid),
                                            .bypass4_dst  (alu_issue_queue_bypass4_dst),
                                            .bypass5_valid(alu_issue_queue_bypass5_valid),
                                            .bypass5_dst  (alu_issue_queue_bypass5_dst),
                                            .bypass6_valid(alu_issue_queue_bypass6_valid),
                                            .bypass6_dst  (alu_issue_queue_bypass6_dst),
                                            .bypass7_valid(alu_issue_queue_bypass7_valid),
                                            .bypass7_dst  (alu_issue_queue_bypass7_dst),

                                            .issue_valid (alu_issue_queue_issue_valid),
                                            .issue_ready (alu_issue_queue_issue_ready),
                                            .issue_opcode(alu_issue_queue_issue_opcode),
                                            .issue_pdest (alu_issue_queue_issue_pdest),
                                            .issue_psrc0 (alu_issue_queue_issue_psrc0),
                                            .issue_psrc1 (alu_issue_queue_issue_psrc1),
                                            .issue_imm   (alu_issue_queue_issue_imm),
                                            .issue_bid   (alu_issue_queue_issue_bid),
                                            .issue_rob_id(alu_issue_queue_issue_rob_id),

                                            .extra_issue_valid (alu_issue_queue_extra_issue_valid),
                                            .extra_issue_ready (alu_issue_queue_extra_issue_ready),
                                            .extra_issue_opcode(alu_issue_queue_extra_issue_opcode),
                                            .extra_issue_pdest (alu_issue_queue_extra_issue_pdest),
                                            .extra_issue_psrc0 (alu_issue_queue_extra_issue_psrc0),
                                            .extra_issue_psrc1 (alu_issue_queue_extra_issue_psrc1),
                                            .extra_issue_imm   (alu_issue_queue_extra_issue_imm),
                                            .extra_issue_bid   (alu_issue_queue_extra_issue_bid),
                                            .extra_issue_rob_id(alu_issue_queue_extra_issue_rob_id),

                                            .full (alu_issue_queue_full),
                                            .empty(alu_issue_queue_empty),
                                            .count(alu_issue_queue_count),

                                            .predict_flush    (alu_issue_queue_predict_flush),
                                            .predict_flush_bid(alu_issue_queue_predict_flush_bid),
                                            .head_bid         (alu_issue_queue_head_bid)

                                        );


            // assign issue_read_reg_stall = 1'b0;
            assign issue_read_reg_pre_stall                                                            = issue_queue_stall;


            assign issue_read_reg_in_phy_reg_dst                                                       = alu_issue_queue_issue_pdest;

            assign issue_read_reg_in_valid                                                             = alu_issue_queue_issue_valid && !issue_clear;
            assign {issue_read_reg_in_regfile_we, issue_read_reg_in_alu_op, issue_read_reg_in_sel_imm} = alu_issue_queue_issue_opcode;
            assign issue_read_reg_in_phy_reg_src1                                                      = alu_issue_queue_issue_psrc0;
            assign issue_read_reg_in_phy_reg_src2                                                      = alu_issue_queue_issue_psrc1;
            assign issue_read_reg_in_extended_imm                                                      = alu_issue_queue_issue_imm;
            assign issue_read_reg_in_rob_id                                                            = alu_issue_queue_issue_rob_id;

            assign issue_read_reg_in_bid                                                               = alu_issue_queue_issue_bid;

            issue_read_reg u_issue_read_reg (
                               .clk   (clk),
                               .resetn(resetn),

                               .stall    (issue_read_reg_stall),
                               .pre_stall(issue_read_reg_pre_stall),

                               .in_valid       (issue_read_reg_in_valid),
                               .in_phy_reg_src1(issue_read_reg_in_phy_reg_src1),
                               .in_phy_reg_src2(issue_read_reg_in_phy_reg_src2),
                               .in_phy_reg_dst (issue_read_reg_in_phy_reg_dst),
                               .in_regfile_we  (issue_read_reg_in_regfile_we),
                               .in_alu_op      (issue_read_reg_in_alu_op),
                               .in_sel_imm     (issue_read_reg_in_sel_imm),
                               .in_extended_imm(issue_read_reg_in_extended_imm),
                               .in_rob_id      (issue_read_reg_in_rob_id),
                               .in_bid         (issue_read_reg_in_bid),

                               .out_valid       (issue_read_reg_out_valid),
                               .out_phy_reg_src1(issue_read_reg_out_phy_reg_src1),
                               .out_phy_reg_src2(issue_read_reg_out_phy_reg_src2),
                               .out_phy_reg_dst (issue_read_reg_out_phy_reg_dst),
                               .out_regfile_we  (issue_read_reg_out_regfile_we),
                               .out_alu_op      (issue_read_reg_out_alu_op),
                               .out_sel_imm     (issue_read_reg_out_sel_imm),
                               .out_extended_imm(issue_read_reg_out_extended_imm),
                               .out_rob_id      (issue_read_reg_out_rob_id),
                               .out_bid         (issue_read_reg_out_bid)
                           );

            alu_bypass_update u_alu_bypass_update1 (
                                  .raddr(issue_read_reg_out_phy_reg_src1),
                                  .rdata(physical_regfile_rdata1),

                                  .alu_bypass1_valid(alu_bypass1_valid),
                                  .alu_bypass1_dst  (alu_bypass1_dst),
                                  .alu_bypass1_data (alu_bypass1_data),

                                  .alu_bypass2_valid(alu_bypass2_valid),
                                  .alu_bypass2_dst  (alu_bypass2_dst),
                                  .alu_bypass2_data (alu_bypass2_data),

                                  .alu_bypass3_valid(alu_bypass3_valid),
                                  .alu_bypass3_dst  (alu_bypass3_dst),
                                  .alu_bypass3_data (alu_bypass3_data),

                                  .alu_bypass4_valid(alu_bypass4_valid),
                                  .alu_bypass4_dst  (alu_bypass4_dst),
                                  .alu_bypass4_data (alu_bypass4_data),

                                  .update_rdata(alu_bypass_update_rdata1)
                              );

            alu_bypass_update u_alu_bypass_update2 (
                                  .raddr(issue_read_reg_out_phy_reg_src2),
                                  .rdata(physical_regfile_rdata2),

                                  .alu_bypass1_valid(alu_bypass1_valid),
                                  .alu_bypass1_dst  (alu_bypass1_dst),
                                  .alu_bypass1_data (alu_bypass1_data),

                                  .alu_bypass2_valid(alu_bypass2_valid),
                                  .alu_bypass2_dst  (alu_bypass2_dst),
                                  .alu_bypass2_data (alu_bypass2_data),

                                  .alu_bypass3_valid(alu_bypass3_valid),
                                  .alu_bypass3_dst  (alu_bypass3_dst),
                                  .alu_bypass3_data (alu_bypass3_data),

                                  .alu_bypass4_valid(alu_bypass4_valid),
                                  .alu_bypass4_dst  (alu_bypass4_dst),
                                  .alu_bypass4_data (alu_bypass4_data),

                                  .update_rdata(alu_bypass_update_rdata2)
                              );





            assign read_exec_reg_in_rob_id                  = issue_read_reg_out_rob_id;

            // assign read_exec_reg_stall                      = 1'b0;
            assign read_exec_reg_pre_stall                  = issue_read_reg_stall;

            assign read_exec_reg_in_valid                   = issue_read_reg_out_valid && !read_clear;
            assign read_exec_reg_in_physical_regfile_rdata1 = alu_bypass_update_rdata1;
            assign read_exec_reg_in_physical_regfile_rdata2 = alu_bypass_update_rdata2;
            assign read_exec_reg_in_phy_reg_dst             = issue_read_reg_out_phy_reg_dst;
            assign read_exec_reg_in_regfile_we              = issue_read_reg_out_regfile_we;
            assign read_exec_reg_in_alu_op                  = issue_read_reg_out_alu_op;
            assign read_exec_reg_in_sel_imm                 = issue_read_reg_out_sel_imm;
            assign read_exec_reg_in_extended_imm            = issue_read_reg_out_extended_imm;

            assign read_exec_reg_in_bid                     = issue_read_reg_out_bid;

            read_exec_reg u_read_exec_reg (
                              .clk   (clk),
                              .resetn(resetn),

                              .stall    (read_exec_reg_stall),
                              .pre_stall(read_exec_reg_pre_stall),

                              .in_valid                  (read_exec_reg_in_valid),
                              .in_physical_regfile_rdata1(read_exec_reg_in_physical_regfile_rdata1),
                              .in_physical_regfile_rdata2(read_exec_reg_in_physical_regfile_rdata2),
                              .in_phy_reg_dst            (read_exec_reg_in_phy_reg_dst),
                              .in_regfile_we             (read_exec_reg_in_regfile_we),
                              .in_alu_op                 (read_exec_reg_in_alu_op),
                              .in_sel_imm                (read_exec_reg_in_sel_imm),
                              .in_extended_imm           (read_exec_reg_in_extended_imm),
                              .in_rob_id                 (read_exec_reg_in_rob_id),
                              .in_bid                    (read_exec_reg_in_bid),

                              .out_valid                  (read_exec_reg_out_valid),
                              .out_physical_regfile_rdata1(read_exec_reg_out_physical_regfile_rdata1),
                              .out_physical_regfile_rdata2(read_exec_reg_out_physical_regfile_rdata2),
                              .out_phy_reg_dst            (read_exec_reg_out_phy_reg_dst),
                              .out_regfile_we             (read_exec_reg_out_regfile_we),
                              .out_alu_op                 (read_exec_reg_out_alu_op),
                              .out_sel_imm                (read_exec_reg_out_sel_imm),
                              .out_extended_imm           (read_exec_reg_out_extended_imm),
                              .out_rob_id                 (read_exec_reg_out_rob_id),
                              .out_bid                    (read_exec_reg_out_bid)
                          );



            assign alu_operand1 = read_exec_reg_out_physical_regfile_rdata1;
            assign alu_operand2 = read_exec_reg_out_sel_imm ? read_exec_reg_out_extended_imm : read_exec_reg_out_physical_regfile_rdata2;
            assign alu_op       = read_exec_reg_out_alu_op;

            alu u_alu (
                    .operand1(alu_operand1),
                    .operand2(alu_operand2),
                    .op      (alu_op),
                    .result  (alu_result)
                );



            assign exec_writeback_reg_in_rob_id      = read_exec_reg_out_rob_id;

            // assign exec_writeback_reg_stall              = 1'b0;
            assign exec_writeback_reg_pre_stall      = read_exec_reg_stall;

            assign exec_writeback_reg_in_valid       = read_exec_reg_out_valid && !exec_clear;
            assign exec_writeback_reg_in_regfile_we  = read_exec_reg_out_regfile_we;
            assign exec_writeback_reg_in_result      = alu_result;
            assign exec_writeback_reg_in_phy_reg_dst = read_exec_reg_out_phy_reg_dst;
            assign exec_writeback_reg_in_bid         = read_exec_reg_out_bid;


            exec_writeback_reg u_exec_writeback_reg (
                                   .clk   (clk),
                                   .resetn(resetn),

                                   .stall    (exec_writeback_reg_stall),
                                   .pre_stall(exec_writeback_reg_pre_stall),

                                   .in_valid      (exec_writeback_reg_in_valid),
                                   .in_regfile_we (exec_writeback_reg_in_regfile_we),
                                   .in_result     (exec_writeback_reg_in_result),
                                   .in_phy_reg_dst(exec_writeback_reg_in_phy_reg_dst),
                                   .in_rob_id     (exec_writeback_reg_in_rob_id),
                                   .in_bid        (exec_writeback_reg_in_bid),

                                   .out_valid      (exec_writeback_reg_out_valid),
                                   .out_regfile_we (exec_writeback_reg_out_regfile_we),
                                   .out_result     (exec_writeback_reg_out_result),
                                   .out_phy_reg_dst(exec_writeback_reg_out_phy_reg_dst),
                                   .out_rob_id     (exec_writeback_reg_out_rob_id),
                                   .out_bid        (exec_writeback_reg_out_bid)
                               );




            //********************************************
            //extra_issue
            //********************************************


            assign extra_issue_read_reg_pre_stall       = issue_queue_extra_stall;

            assign extra_issue_read_reg_in_phy_reg_dst  = sel_privilege_issue ? privilege_issue_queue_issue_pdest : alu_issue_queue_extra_issue_pdest;

            assign extra_issue_read_reg_in_valid        = sel_privilege_issue ? privilege_issue_queue_issue_valid && !privilege_issue_clear : alu_issue_queue_extra_issue_valid && !issue_clear;
            // assign {
            //     issue_read_reg_in_regfile_we,
            //     issue_read_reg_in_alu_op,
            //     issue_read_reg_in_sel_imm

            //     } = alu_issue_queue_issue_opcode;

            assign extra_issue_read_reg_in_regfile_we   = sel_privilege_issue ? privilege_issue_read_reg_in_csr_re : alu_issue_queue_extra_issue_opcode[6];
            assign extra_issue_read_reg_in_alu_op       = alu_issue_queue_extra_issue_opcode[5:1];
            assign extra_issue_read_reg_in_sel_imm      = alu_issue_queue_extra_issue_opcode[0];

            assign extra_issue_read_reg_in_phy_reg_src1 = sel_privilege_issue ? privilege_issue_queue_issue_psrc0 : alu_issue_queue_extra_issue_psrc0;
            assign extra_issue_read_reg_in_phy_reg_src2 = sel_privilege_issue ? privilege_issue_queue_issue_psrc1 : alu_issue_queue_extra_issue_psrc1;
            assign extra_issue_read_reg_in_extended_imm = alu_issue_queue_extra_issue_imm;
            assign extra_issue_read_reg_in_rob_id       = sel_privilege_issue ? privilege_issue_queue_issue_rob_id : alu_issue_queue_extra_issue_rob_id;

            assign extra_issue_read_reg_in_bid          = sel_privilege_issue ? privilege_issue_queue_issue_bid : alu_issue_queue_extra_issue_bid;





            issue_read_reg u_extra_issue_read_reg (
                               .clk   (clk),
                               .resetn(resetn),

                               .stall    (extra_issue_read_reg_stall),
                               .pre_stall(extra_issue_read_reg_pre_stall),

                               .in_valid       (extra_issue_read_reg_in_valid),
                               .in_phy_reg_src1(extra_issue_read_reg_in_phy_reg_src1),
                               .in_phy_reg_src2(extra_issue_read_reg_in_phy_reg_src2),
                               .in_phy_reg_dst (extra_issue_read_reg_in_phy_reg_dst),
                               .in_regfile_we  (extra_issue_read_reg_in_regfile_we),
                               .in_alu_op      (extra_issue_read_reg_in_alu_op),
                               .in_sel_imm     (extra_issue_read_reg_in_sel_imm),
                               .in_extended_imm(extra_issue_read_reg_in_extended_imm),
                               .in_rob_id      (extra_issue_read_reg_in_rob_id),
                               .in_bid         (extra_issue_read_reg_in_bid),

                               .out_valid       (extra_issue_read_reg_out_valid),
                               .out_phy_reg_src1(extra_issue_read_reg_out_phy_reg_src1),
                               .out_phy_reg_src2(extra_issue_read_reg_out_phy_reg_src2),
                               .out_phy_reg_dst (extra_issue_read_reg_out_phy_reg_dst),
                               .out_regfile_we  (extra_issue_read_reg_out_regfile_we),
                               .out_alu_op      (extra_issue_read_reg_out_alu_op),
                               .out_sel_imm     (extra_issue_read_reg_out_sel_imm),
                               .out_extended_imm(extra_issue_read_reg_out_extended_imm),
                               .out_rob_id      (extra_issue_read_reg_out_rob_id),
                               .out_bid         (extra_issue_read_reg_out_bid)
                           );


            alu_bypass_update u_extra_alu_bypass_update1 (
                                  .raddr(extra_issue_read_reg_out_phy_reg_src1),
                                  .rdata(physical_regfile_rdata7),

                                  .alu_bypass1_valid(alu_bypass1_valid),
                                  .alu_bypass1_dst  (alu_bypass1_dst),
                                  .alu_bypass1_data (alu_bypass1_data),

                                  .alu_bypass2_valid(alu_bypass2_valid),
                                  .alu_bypass2_dst  (alu_bypass2_dst),
                                  .alu_bypass2_data (alu_bypass2_data),

                                  .alu_bypass3_valid(alu_bypass3_valid),
                                  .alu_bypass3_dst  (alu_bypass3_dst),
                                  .alu_bypass3_data (alu_bypass3_data),

                                  .alu_bypass4_valid(alu_bypass4_valid),
                                  .alu_bypass4_dst  (alu_bypass4_dst),
                                  .alu_bypass4_data (alu_bypass4_data),

                                  .update_rdata(extra_alu_bypass_update_rdata1)
                              );

            alu_bypass_update u_extra_alu_bypass_update2 (
                                  .raddr(extra_issue_read_reg_out_phy_reg_src2),
                                  .rdata(physical_regfile_rdata8),

                                  .alu_bypass1_valid(alu_bypass1_valid),
                                  .alu_bypass1_dst  (alu_bypass1_dst),
                                  .alu_bypass1_data (alu_bypass1_data),

                                  .alu_bypass2_valid(alu_bypass2_valid),
                                  .alu_bypass2_dst  (alu_bypass2_dst),
                                  .alu_bypass2_data (alu_bypass2_data),

                                  .alu_bypass3_valid(alu_bypass3_valid),
                                  .alu_bypass3_dst  (alu_bypass3_dst),
                                  .alu_bypass3_data (alu_bypass3_data),

                                  .alu_bypass4_valid(alu_bypass4_valid),
                                  .alu_bypass4_dst  (alu_bypass4_dst),
                                  .alu_bypass4_data (alu_bypass4_data),

                                  .update_rdata(extra_alu_bypass_update_rdata2)
                              );












            assign extra_read_exec_reg_in_rob_id                  = extra_issue_read_reg_out_rob_id;

            assign extra_read_exec_reg_pre_stall                  = extra_issue_read_reg_stall;

            assign extra_read_exec_reg_in_valid                   = extra_issue_read_reg_out_valid && !extra_read_clear;
            assign extra_read_exec_reg_in_physical_regfile_rdata1 = extra_alu_bypass_update_rdata1;  //
            assign extra_read_exec_reg_in_physical_regfile_rdata2 = extra_alu_bypass_update_rdata2;  //
            assign extra_read_exec_reg_in_phy_reg_dst             = extra_issue_read_reg_out_phy_reg_dst;
            assign extra_read_exec_reg_in_regfile_we              = extra_issue_read_reg_out_regfile_we;
            assign extra_read_exec_reg_in_alu_op                  = extra_issue_read_reg_out_alu_op;
            assign extra_read_exec_reg_in_sel_imm                 = extra_issue_read_reg_out_sel_imm;
            assign extra_read_exec_reg_in_extended_imm            = extra_issue_read_reg_out_extended_imm;
            assign extra_read_exec_reg_in_bid                     = extra_issue_read_reg_out_bid;

            read_exec_reg u_extra_read_exec_reg (
                              .clk   (clk),
                              .resetn(resetn),

                              .stall    (extra_read_exec_reg_stall),
                              .pre_stall(extra_read_exec_reg_pre_stall),

                              .in_valid                  (extra_read_exec_reg_in_valid),
                              .in_physical_regfile_rdata1(extra_read_exec_reg_in_physical_regfile_rdata1),
                              .in_physical_regfile_rdata2(extra_read_exec_reg_in_physical_regfile_rdata2),
                              .in_phy_reg_dst            (extra_read_exec_reg_in_phy_reg_dst),
                              .in_regfile_we             (extra_read_exec_reg_in_regfile_we),
                              .in_alu_op                 (extra_read_exec_reg_in_alu_op),
                              .in_sel_imm                (extra_read_exec_reg_in_sel_imm),
                              .in_extended_imm           (extra_read_exec_reg_in_extended_imm),
                              .in_rob_id                 (extra_read_exec_reg_in_rob_id),
                              .in_bid                    (extra_read_exec_reg_in_bid),

                              .out_valid                  (extra_read_exec_reg_out_valid),
                              .out_physical_regfile_rdata1(extra_read_exec_reg_out_physical_regfile_rdata1),
                              .out_physical_regfile_rdata2(extra_read_exec_reg_out_physical_regfile_rdata2),
                              .out_phy_reg_dst            (extra_read_exec_reg_out_phy_reg_dst),
                              .out_regfile_we             (extra_read_exec_reg_out_regfile_we),
                              .out_alu_op                 (extra_read_exec_reg_out_alu_op),
                              .out_sel_imm                (extra_read_exec_reg_out_sel_imm),
                              .out_extended_imm           (extra_read_exec_reg_out_extended_imm),
                              .out_rob_id                 (extra_read_exec_reg_out_rob_id),
                              .out_bid                    (extra_read_exec_reg_out_bid)
                          );



            assign extra_alu_operand1 = extra_read_exec_reg_out_physical_regfile_rdata1;
            assign extra_alu_operand2 = extra_read_exec_reg_out_sel_imm ? extra_read_exec_reg_out_extended_imm : extra_read_exec_reg_out_physical_regfile_rdata2;
            assign extra_alu_op       = extra_read_exec_reg_out_alu_op;

            alu u_extra_alu (
                    .operand1(extra_alu_operand1),
                    .operand2(extra_alu_operand2),
                    .op      (extra_alu_op),
                    .result  (extra_alu_result)
                );



            assign extra_exec_writeback_reg_in_rob_id      = extra_read_exec_reg_out_rob_id;

            // assign exec_writeback_reg_stall              = 1'b0;
            assign extra_exec_writeback_reg_pre_stall      = extra_read_exec_reg_stall;

            assign extra_exec_writeback_reg_in_valid       = extra_read_exec_reg_out_valid && !extra_exec_clear;
            assign extra_exec_writeback_reg_in_regfile_we  = extra_read_exec_reg_out_regfile_we;
            assign extra_exec_writeback_reg_in_result      = privilege_read_exec_reg_out_csr_re ? privilege_read_exec_reg_out_csr_rdata : extra_alu_result;
            assign extra_exec_writeback_reg_in_phy_reg_dst = extra_read_exec_reg_out_phy_reg_dst;
            assign extra_exec_writeback_reg_in_bid         = extra_read_exec_reg_out_bid;


            exec_writeback_reg u_extra_exec_writeback_reg (
                                   .clk   (clk),
                                   .resetn(resetn),

                                   .stall    (extra_exec_writeback_reg_stall),
                                   .pre_stall(extra_exec_writeback_reg_pre_stall),

                                   .in_valid      (extra_exec_writeback_reg_in_valid),
                                   .in_regfile_we (extra_exec_writeback_reg_in_regfile_we),
                                   .in_result     (extra_exec_writeback_reg_in_result),
                                   .in_phy_reg_dst(extra_exec_writeback_reg_in_phy_reg_dst),
                                   .in_rob_id     (extra_exec_writeback_reg_in_rob_id),
                                   .in_bid        (extra_exec_writeback_reg_in_bid),

                                   .out_valid      (extra_exec_writeback_reg_out_valid),
                                   .out_regfile_we (extra_exec_writeback_reg_out_regfile_we),
                                   .out_result     (extra_exec_writeback_reg_out_result),
                                   .out_phy_reg_dst(extra_exec_writeback_reg_out_phy_reg_dst),
                                   .out_rob_id     (extra_exec_writeback_reg_out_rob_id),
                                   .out_bid        (extra_exec_writeback_reg_out_bid)
                               );



            //********************************************
            //extra_issu_end
            //********************************************

            assign alu_bypass1_valid                            = bypass1_valid && bypass1_dst != 7'd0;
            assign alu_bypass2_valid                            = bypass7_valid && bypass7_dst != 7'd0;

            assign alu_bypass1_dst                              = bypass1_dst;
            assign alu_bypass2_dst                              = bypass7_dst;

            assign alu_bypass1_data                             = physical_regfile_wdata1;
            assign alu_bypass2_data                             = physical_regfile_wdata7;

            assign alu_bypass3_valid                            = read_exec_reg_out_valid && read_exec_reg_out_phy_reg_dst != 7'd0;
            assign alu_bypass4_valid                            = extra_read_exec_reg_out_valid && extra_read_exec_reg_out_phy_reg_dst != 7'd0;

            assign alu_bypass3_dst                              = read_exec_reg_out_phy_reg_dst;
            assign alu_bypass4_dst                              = extra_read_exec_reg_out_phy_reg_dst;

            assign alu_bypass3_data                             = exec_writeback_reg_in_result;
            assign alu_bypass4_data                             = extra_exec_writeback_reg_in_result;





            assign lsu_issue_queue_flush                        = lsu_issue_clear;
            wire [3:0] rename_dispatch_pipeline_queue_out_is_store_or_not_load;

            assign rename_dispatch_pipeline_queue_out_is_store_or_not_load[0] = rename_dispatch_pipeline_queue_out_sel_issue_queue[0] == `SEL_ISSUE_QUEUE_STORE;

            assign lsu_issue_queue_dispatch_opcode[0]              = {
                       rename_dispatch_pipeline_queue_out_is_store_or_not_load[0],
                       rename_dispatch_pipeline_queue_out_sel_load_store_len[0],
                       rename_dispatch_pipeline_queue_out_is_cacop[0],
                       rename_dispatch_pipeline_queue_out_is_ll_w[0],
                       rename_dispatch_pipeline_queue_out_is_sc_w[0],
                       rename_dispatch_pipeline_queue_out_is_dbar[0]
                   };
            assign lsu_issue_queue_dispatch_pdest[0]               = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0];
            assign lsu_issue_queue_dispatch_psrc0[0]               = rename_dispatch_pipeline_queue_out_phy_reg_src1[0];
            assign lsu_issue_queue_dispatch_prdy0[0]               = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[0];  //
            assign lsu_issue_queue_dispatch_psrc1[0]               = rename_dispatch_pipeline_queue_out_phy_reg_src2[0];
            assign lsu_issue_queue_dispatch_prdy1[0]               = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[0];  //
            assign lsu_issue_queue_dispatch_imm[0]                 = rename_dispatch_pipeline_queue_out_extended_imm[0];
            assign lsu_issue_queue_dispatch_bid[0]                 = rename_dispatch_pipeline_queue_out_bid[0];
            assign lsu_issue_queue_dispatch_rob_id[0]              = rob_alloc_rob_id[0];



            assign rename_dispatch_pipeline_queue_out_is_store_or_not_load[1] = rename_dispatch_pipeline_queue_out_sel_issue_queue[1] == `SEL_ISSUE_QUEUE_STORE;

            assign lsu_issue_queue_dispatch_opcode[1]              = {
                       rename_dispatch_pipeline_queue_out_is_store_or_not_load[1],
                       rename_dispatch_pipeline_queue_out_sel_load_store_len[1],
                       rename_dispatch_pipeline_queue_out_is_cacop[1],
                       rename_dispatch_pipeline_queue_out_is_ll_w[1],
                       rename_dispatch_pipeline_queue_out_is_sc_w[1],
                       rename_dispatch_pipeline_queue_out_is_dbar[1]
                   };
            assign lsu_issue_queue_dispatch_pdest[1]               = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[1];
            assign lsu_issue_queue_dispatch_psrc0[1]               = rename_dispatch_pipeline_queue_out_phy_reg_src1[1];
            assign lsu_issue_queue_dispatch_prdy0[1]               = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[1];  //
            assign lsu_issue_queue_dispatch_psrc1[1]               = rename_dispatch_pipeline_queue_out_phy_reg_src2[1];
            assign lsu_issue_queue_dispatch_prdy1[1]               = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[1];  //
            assign lsu_issue_queue_dispatch_imm[1]                 = rename_dispatch_pipeline_queue_out_extended_imm[1];
            assign lsu_issue_queue_dispatch_bid[1]                 = rename_dispatch_pipeline_queue_out_bid[1];
            assign lsu_issue_queue_dispatch_rob_id[1]              = rob_alloc_rob_id[1];





            assign rename_dispatch_pipeline_queue_out_is_store_or_not_load[2] = rename_dispatch_pipeline_queue_out_sel_issue_queue[2] == `SEL_ISSUE_QUEUE_STORE;

            assign lsu_issue_queue_dispatch_opcode[2]              = {
                       rename_dispatch_pipeline_queue_out_is_store_or_not_load[2],
                       rename_dispatch_pipeline_queue_out_sel_load_store_len[2],
                       rename_dispatch_pipeline_queue_out_is_cacop[2],
                       rename_dispatch_pipeline_queue_out_is_ll_w[2],
                       rename_dispatch_pipeline_queue_out_is_sc_w[2],
                       rename_dispatch_pipeline_queue_out_is_dbar[2]
                   };
            assign lsu_issue_queue_dispatch_pdest[2]               = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[2];
            assign lsu_issue_queue_dispatch_psrc0[2]               = rename_dispatch_pipeline_queue_out_phy_reg_src1[2];
            assign lsu_issue_queue_dispatch_prdy0[2]               = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[2];  //
            assign lsu_issue_queue_dispatch_psrc1[2]               = rename_dispatch_pipeline_queue_out_phy_reg_src2[2];
            assign lsu_issue_queue_dispatch_prdy1[2]               = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[2];  //
            assign lsu_issue_queue_dispatch_imm[2]                 = rename_dispatch_pipeline_queue_out_extended_imm[2];
            assign lsu_issue_queue_dispatch_bid[2]                 = rename_dispatch_pipeline_queue_out_bid[2];
            assign lsu_issue_queue_dispatch_rob_id[2]              = rob_alloc_rob_id[2];



            assign rename_dispatch_pipeline_queue_out_is_store_or_not_load[3] = rename_dispatch_pipeline_queue_out_sel_issue_queue[3] == `SEL_ISSUE_QUEUE_STORE;

            assign lsu_issue_queue_dispatch_opcode[3]              = {
                       rename_dispatch_pipeline_queue_out_is_store_or_not_load[3],
                       rename_dispatch_pipeline_queue_out_sel_load_store_len[3],
                       rename_dispatch_pipeline_queue_out_is_cacop[3],
                       rename_dispatch_pipeline_queue_out_is_ll_w[3],
                       rename_dispatch_pipeline_queue_out_is_sc_w[3],
                       rename_dispatch_pipeline_queue_out_is_dbar[3]
                   };
            assign lsu_issue_queue_dispatch_pdest[3]               = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3];
            assign lsu_issue_queue_dispatch_psrc0[3]               = rename_dispatch_pipeline_queue_out_phy_reg_src1[3];
            assign lsu_issue_queue_dispatch_prdy0[3]               = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[3];  //
            assign lsu_issue_queue_dispatch_psrc1[3]               = rename_dispatch_pipeline_queue_out_phy_reg_src2[3];
            assign lsu_issue_queue_dispatch_prdy1[3]               = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[3];  //
            assign lsu_issue_queue_dispatch_imm[3]                 = rename_dispatch_pipeline_queue_out_extended_imm[3];
            assign lsu_issue_queue_dispatch_bid[3]                 = rename_dispatch_pipeline_queue_out_bid[3];
            assign lsu_issue_queue_dispatch_rob_id[3]              = rob_alloc_rob_id[3];





            assign lsu_issue_queue_bypass1_valid                = bypass1_valid;
            assign lsu_issue_queue_bypass1_dst                  = bypass1_dst;
            assign lsu_issue_queue_bypass2_valid                = bypass2_valid;
            assign lsu_issue_queue_bypass2_dst                  = bypass2_dst;
            assign lsu_issue_queue_bypass3_valid                = bypass3_valid;
            assign lsu_issue_queue_bypass3_dst                  = bypass3_dst;
            assign lsu_issue_queue_bypass4_valid                = bypass4_valid;
            assign lsu_issue_queue_bypass4_dst                  = bypass4_dst;
            assign lsu_issue_queue_bypass5_valid                = bypass5_valid;
            assign lsu_issue_queue_bypass5_dst                  = bypass5_dst;
            assign lsu_issue_queue_bypass6_valid                = bypass6_valid;
            assign lsu_issue_queue_bypass6_dst                  = bypass6_dst;
            assign lsu_issue_queue_bypass7_valid                = bypass7_valid;
            assign lsu_issue_queue_bypass7_dst                  = bypass7_dst;

            assign lsu_issue_queue_issue_ready                  = !lsu_issue_queue_stall;




            assign lsu_issue_queue_predict_flush                = predict_flush;
            assign lsu_issue_queue_predict_flush_bid            = predict_flush_bid;
            assign lsu_issue_queue_head_bid                     = branch_id_allocator_bid_head;




            lsu_issue_queue_lutram_core u_lsu_issue_queue (
                                            .clk   (clk),
                                            .resetn(resetn),

                                            .flush(lsu_issue_queue_flush),

                                            .bias_valid(dispatch_ctrl_lsu_bias_valid),
                                            .dispatch_valid (lsu_issue_queue_dispatch_valid),
                                            .dispatch_prdy0 (lsu_issue_queue_dispatch_prdy0),
                                            .dispatch_prdy1 (lsu_issue_queue_dispatch_prdy1),



                                            .dispatch_opcode_0(lsu_issue_queue_dispatch_opcode[0]),
                                            .dispatch_pdest_0 (lsu_issue_queue_dispatch_pdest[0]),
                                            .dispatch_psrc0_0 (lsu_issue_queue_dispatch_psrc0[0]),
                                            .dispatch_psrc1_0 (lsu_issue_queue_dispatch_psrc1[0]),
                                            .dispatch_imm_0   (lsu_issue_queue_dispatch_imm[0]),
                                            .dispatch_bid_0   (lsu_issue_queue_dispatch_bid[0]),
                                            .dispatch_rob_id_0(lsu_issue_queue_dispatch_rob_id[0]),




                                            .dispatch_opcode_1(lsu_issue_queue_dispatch_opcode[1]),
                                            .dispatch_pdest_1 (lsu_issue_queue_dispatch_pdest[1]),
                                            .dispatch_psrc0_1 (lsu_issue_queue_dispatch_psrc0[1]),
                                            .dispatch_psrc1_1 (lsu_issue_queue_dispatch_psrc1[1]),
                                            .dispatch_imm_1   (lsu_issue_queue_dispatch_imm[1]),
                                            .dispatch_bid_1   (lsu_issue_queue_dispatch_bid[1]),
                                            .dispatch_rob_id_1(lsu_issue_queue_dispatch_rob_id[1]),





                                            .dispatch_opcode_2(lsu_issue_queue_dispatch_opcode[2]),
                                            .dispatch_pdest_2 (lsu_issue_queue_dispatch_pdest[2]),
                                            .dispatch_psrc0_2 (lsu_issue_queue_dispatch_psrc0[2]),
                                            .dispatch_psrc1_2 (lsu_issue_queue_dispatch_psrc1[2]),
                                            .dispatch_imm_2   (lsu_issue_queue_dispatch_imm[2]),
                                            .dispatch_bid_2   (lsu_issue_queue_dispatch_bid[2]),
                                            .dispatch_rob_id_2(lsu_issue_queue_dispatch_rob_id[2]),



                                            .dispatch_opcode_3(lsu_issue_queue_dispatch_opcode[3]),
                                            .dispatch_pdest_3 (lsu_issue_queue_dispatch_pdest[3]),
                                            .dispatch_psrc0_3 (lsu_issue_queue_dispatch_psrc0[3]),
                                            .dispatch_psrc1_3 (lsu_issue_queue_dispatch_psrc1[3]),
                                            .dispatch_imm_3   (lsu_issue_queue_dispatch_imm[3]),
                                            .dispatch_bid_3   (lsu_issue_queue_dispatch_bid[3]),
                                            .dispatch_rob_id_3(lsu_issue_queue_dispatch_rob_id[3]),


                                            .bypass1_valid(lsu_issue_queue_bypass1_valid),
                                            .bypass1_dst  (lsu_issue_queue_bypass1_dst),
                                            .bypass2_valid(lsu_issue_queue_bypass2_valid),
                                            .bypass2_dst  (lsu_issue_queue_bypass2_dst),
                                            .bypass3_valid(lsu_issue_queue_bypass3_valid),
                                            .bypass3_dst  (lsu_issue_queue_bypass3_dst),
                                            .bypass4_valid(lsu_issue_queue_bypass4_valid),
                                            .bypass4_dst  (lsu_issue_queue_bypass4_dst),
                                            .bypass5_valid(lsu_issue_queue_bypass5_valid),
                                            .bypass5_dst  (lsu_issue_queue_bypass5_dst),
                                            .bypass6_valid(lsu_issue_queue_bypass6_valid),
                                            .bypass6_dst  (lsu_issue_queue_bypass6_dst),
                                            .bypass7_valid(lsu_issue_queue_bypass7_valid),
                                            .bypass7_dst  (lsu_issue_queue_bypass7_dst),

                                            .issue_valid (lsu_issue_queue_issue_valid),
                                            .issue_ready (lsu_issue_queue_issue_ready),
                                            .issue_opcode(lsu_issue_queue_issue_opcode),
                                            .issue_pdest (lsu_issue_queue_issue_pdest),
                                            .issue_psrc0 (lsu_issue_queue_issue_psrc0),
                                            .issue_psrc1 (lsu_issue_queue_issue_psrc1),
                                            .issue_imm   (lsu_issue_queue_issue_imm),
                                            .issue_bid   (lsu_issue_queue_issue_bid),
                                            .issue_rob_id(lsu_issue_queue_issue_rob_id),

                                            .full (lsu_issue_queue_full),
                                            .empty(lsu_issue_queue_empty),
                                            .count(lsu_issue_queue_count),

                                            .predict_flush    (lsu_issue_queue_predict_flush),
                                            .predict_flush_bid(lsu_issue_queue_predict_flush_bid),
                                            .head_bid         (lsu_issue_queue_head_bid),

                                            .phy_ready(cam_rmt_phy_ready)
                                        );





            wire lsu_issue_read_reg_in_is_ll_w;
            wire lsu_issue_read_reg_in_is_sc_w;
            wire lsu_issue_read_reg_in_is_dbar;
            wire lsu_issue_read_reg_out_is_ll_w;
            wire lsu_issue_read_reg_out_is_sc_w;
            wire lsu_issue_read_reg_out_is_dbar;

            assign lsu_issue_read_reg_pre_stall                                                                                           = lsu_issue_queue_stall;
            // assign lsu_issue_read_reg_stall                                                   = 1'b0;

            assign lsu_issue_read_reg_in_valid                                                                                            = lsu_issue_queue_issue_valid && !lsu_issue_clear;
            assign lsu_issue_read_reg_in_phy_reg_src1                                                                                     = lsu_issue_queue_issue_psrc0;
            assign lsu_issue_read_reg_in_phy_reg_src2                                                                                     = lsu_issue_queue_issue_psrc1;
            assign lsu_issue_read_reg_in_phy_reg_dst                                                                                      = lsu_issue_queue_issue_pdest;
            assign lsu_issue_read_reg_in_extended_imm                                                                                     = lsu_issue_queue_issue_imm;
            assign {
                    lsu_issue_read_reg_in_is_store_or_not_load,
                    lsu_issue_read_reg_in_sel_load_store_len,
                    lsu_issue_read_reg_in_is_cacop,
                    lsu_issue_read_reg_in_is_ll_w,
                    lsu_issue_read_reg_in_is_sc_w,
                    lsu_issue_read_reg_in_is_dbar
                } = lsu_issue_queue_issue_opcode;

            assign lsu_issue_read_reg_in_bid                                                                                              = lsu_issue_queue_issue_bid;
            assign lsu_issue_read_reg_in_rob_id                                                                                           = lsu_issue_queue_issue_rob_id;

            lsu_issue_read_reg u_lsu_issue_read_reg (
                                   .clk   (clk),
                                   .resetn(resetn),

                                   .stall    (lsu_issue_read_reg_stall),
                                   .pre_stall(lsu_issue_read_reg_pre_stall),

                                   .in_valid               (lsu_issue_read_reg_in_valid),
                                   .in_phy_reg_src1        (lsu_issue_read_reg_in_phy_reg_src1),
                                   .in_phy_reg_src2        (lsu_issue_read_reg_in_phy_reg_src2),
                                   .in_phy_reg_dst         (lsu_issue_read_reg_in_phy_reg_dst),
                                   .in_extended_imm        (lsu_issue_read_reg_in_extended_imm),
                                   .in_is_store_or_not_load(lsu_issue_read_reg_in_is_store_or_not_load),
                                   .in_rob_id              (lsu_issue_read_reg_in_rob_id),
                                   .in_sel_load_store_len  (lsu_issue_read_reg_in_sel_load_store_len),
                                   .in_bid                 (lsu_issue_read_reg_in_bid),
                                   .in_is_cacop            (lsu_issue_read_reg_in_is_cacop),
                                   .in_is_ll_w(lsu_issue_read_reg_in_is_ll_w),
                                   .in_is_sc_w(lsu_issue_read_reg_in_is_sc_w),
                                   .in_is_dbar(lsu_issue_read_reg_in_is_dbar),

                                   .out_valid               (lsu_issue_read_reg_out_valid),
                                   .out_phy_reg_src1        (lsu_issue_read_reg_out_phy_reg_src1),
                                   .out_phy_reg_src2        (lsu_issue_read_reg_out_phy_reg_src2),
                                   .out_phy_reg_dst         (lsu_issue_read_reg_out_phy_reg_dst),
                                   .out_extended_imm        (lsu_issue_read_reg_out_extended_imm),
                                   .out_is_store_or_not_load(lsu_issue_read_reg_out_is_store_or_not_load),
                                   .out_rob_id              (lsu_issue_read_reg_out_rob_id),
                                   .out_sel_load_store_len  (lsu_issue_read_reg_out_sel_load_store_len),
                                   .out_bid                 (lsu_issue_read_reg_out_bid),
                                   .out_is_cacop            (lsu_issue_read_reg_out_is_cacop),
                                   .out_is_ll_w(lsu_issue_read_reg_out_is_ll_w),
                                   .out_is_sc_w(lsu_issue_read_reg_out_is_sc_w),
                                   .out_is_dbar(lsu_issue_read_reg_out_is_dbar)
                               );


            wire lsu_read_phy_reg_rdy1 = cam_rmt_phy_ready[lsu_issue_read_reg_out_phy_reg_src1]||
                 (bypass1_valid && (lsu_issue_read_reg_out_phy_reg_src1 == bypass1_dst)) ||
                 (bypass2_valid && (lsu_issue_read_reg_out_phy_reg_src1 == bypass2_dst)) ||
                 (bypass3_valid && (lsu_issue_read_reg_out_phy_reg_src1 == bypass3_dst)) ||
                 (bypass4_valid && (lsu_issue_read_reg_out_phy_reg_src1 == bypass4_dst)) ||
                 (bypass5_valid && (lsu_issue_read_reg_out_phy_reg_src1 == bypass5_dst)) ||
                 (bypass6_valid && (lsu_issue_read_reg_out_phy_reg_src1 == bypass6_dst)) ||
                 (bypass7_valid && (lsu_issue_read_reg_out_phy_reg_src1== bypass7_dst));
            wire lsu_read_phy_reg_rdy2 = cam_rmt_phy_ready[lsu_issue_read_reg_out_phy_reg_src2]||
                 (bypass1_valid && (lsu_issue_read_reg_out_phy_reg_src2 == bypass1_dst)) ||
                 (bypass2_valid && (lsu_issue_read_reg_out_phy_reg_src2 == bypass2_dst)) ||
                 (bypass3_valid && (lsu_issue_read_reg_out_phy_reg_src2 == bypass3_dst)) ||
                 (bypass4_valid && (lsu_issue_read_reg_out_phy_reg_src2 == bypass4_dst)) ||
                 (bypass5_valid && (lsu_issue_read_reg_out_phy_reg_src2 == bypass5_dst)) ||
                 (bypass6_valid && (lsu_issue_read_reg_out_phy_reg_src2 == bypass6_dst)) ||
                 (bypass7_valid && (lsu_issue_read_reg_out_phy_reg_src2== bypass7_dst));


            wire [31:0] lsu_read_phy_src1_updata_data;
            wire [31:0] lsu_read_phy_src2_updata_data;

            bypass_update u_bypass_update_lsu_read_phy_src1(
                              .phy_src(lsu_issue_read_reg_out_phy_reg_src1),
                              .phy_data(physical_regfile_rdata3),

                              .bypass1_valid(bypass1_valid),
                              .bypass1_dst(bypass1_dst),
                              .bypass1_data(bypass1_data),
                              .bypass2_valid(bypass2_valid),
                              .bypass2_dst(bypass2_dst),
                              .bypass2_data(bypass2_data),
                              .bypass3_valid(bypass3_valid),
                              .bypass3_dst(bypass3_dst),
                              .bypass3_data(bypass3_data),
                              .bypass4_valid(bypass4_valid),
                              .bypass4_dst(bypass4_dst),
                              .bypass4_data(bypass4_data),
                              .bypass5_valid(bypass5_valid),
                              .bypass5_dst(bypass5_dst),
                              .bypass5_data(bypass5_data),
                              .bypass6_valid(bypass6_valid),
                              .bypass6_dst(bypass6_dst),
                              .bypass6_data(bypass6_data),
                              .bypass7_valid(bypass7_valid),
                              .bypass7_dst(bypass7_dst),
                              .bypass7_data(bypass7_data),

                              .bypass_update_data(lsu_read_phy_src1_updata_data)
                          );

            bypass_update u_bypass_update_lsu_read_phy_src2(
                              .phy_src(lsu_issue_read_reg_out_phy_reg_src2),
                              .phy_data(physical_regfile_rdata4),

                              .bypass1_valid(bypass1_valid),
                              .bypass1_dst(bypass1_dst),
                              .bypass1_data(bypass1_data),
                              .bypass2_valid(bypass2_valid),
                              .bypass2_dst(bypass2_dst),
                              .bypass2_data(bypass2_data),
                              .bypass3_valid(bypass3_valid),
                              .bypass3_dst(bypass3_dst),
                              .bypass3_data(bypass3_data),
                              .bypass4_valid(bypass4_valid),
                              .bypass4_dst(bypass4_dst),
                              .bypass4_data(bypass4_data),
                              .bypass5_valid(bypass5_valid),
                              .bypass5_dst(bypass5_dst),
                              .bypass5_data(bypass5_data),
                              .bypass6_valid(bypass6_valid),
                              .bypass6_dst(bypass6_dst),
                              .bypass6_data(bypass6_data),
                              .bypass7_valid(bypass7_valid),
                              .bypass7_dst(bypass7_dst),
                              .bypass7_data(bypass7_data),

                              .bypass_update_data(lsu_read_phy_src2_updata_data)
                          );

            assign lsu_read_exec_store_data_bypass_hit[1]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass1_valid
                   && bypass1_dst == lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_read_exec_store_data_bypass_hit[2]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass2_valid
                   && bypass2_dst == lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_read_exec_store_data_bypass_hit[3]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass3_valid
                   && bypass3_dst == lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_read_exec_store_data_bypass_hit[4]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass4_valid
                   && bypass4_dst == lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_read_exec_store_data_bypass_hit[5]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass5_valid
                   && bypass5_dst == lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_read_exec_store_data_bypass_hit[6]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass6_valid
                   && bypass6_dst == lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_read_exec_store_data_bypass_hit[7]
                   = lsu_read_exec_reg_out_valid
                   && lsu_read_exec_reg_out_is_store_or_not_load
                   && !lsu_read_exec_reg_out_phy_reg_src2_rdy
                   && lsu_read_exec_reg_out_phy_reg_src2 != 7'd0
                   && bypass7_valid
                   && bypass7_dst == lsu_read_exec_reg_out_phy_reg_src2;

            assign lsu_read_exec_store_data_bypass_valid
                   = |lsu_read_exec_store_data_bypass_hit;
            assign lsu_read_exec_store_data_bypass_data
                   = lsu_read_exec_store_data_bypass_hit[1] ? bypass1_data
                   : lsu_read_exec_store_data_bypass_hit[2] ? bypass2_data
                   : lsu_read_exec_store_data_bypass_hit[3] ? bypass3_data
                   : lsu_read_exec_store_data_bypass_hit[4] ? bypass4_data
                   : lsu_read_exec_store_data_bypass_hit[5] ? bypass5_data
                   : lsu_read_exec_store_data_bypass_hit[6] ? bypass6_data
                   : lsu_read_exec_store_data_bypass_hit[7] ? bypass7_data
                   : lsu_read_exec_reg_out_phy_reg_rdata2;
            assign lsu_read_exec_store_data_prdy_next
                   = lsu_read_exec_reg_out_phy_reg_src2_rdy
                   || lsu_read_exec_store_data_bypass_valid;
            assign lsu_read_exec_store_data_next
                   = lsu_read_exec_reg_out_phy_reg_src2_rdy
                   ? lsu_read_exec_reg_out_phy_reg_rdata2
                   : lsu_read_exec_store_data_bypass_data;


            // assign lsu_read_exec_reg_stall                   = 1'b0;
            assign lsu_read_exec_reg_pre_stall               = lsu_issue_read_reg_stall;

            assign lsu_read_exec_reg_in_valid                = lsu_issue_read_reg_out_valid && !lsu_read_clear;
            assign lsu_read_exec_reg_in_phy_reg_src2         = lsu_issue_read_reg_out_phy_reg_src2;
            assign lsu_read_exec_reg_in_phy_reg_src2_rdy     = lsu_read_phy_reg_rdy2;
            assign lsu_read_exec_reg_in_phy_reg_rdata1       = lsu_read_phy_src1_updata_data;
            assign lsu_read_exec_reg_in_phy_reg_rdata2       = lsu_read_phy_src2_updata_data;
            assign lsu_read_exec_reg_in_phy_reg_dst          = lsu_issue_read_reg_out_phy_reg_dst;
            assign lsu_read_exec_reg_in_extended_imm         = lsu_issue_read_reg_out_extended_imm;
            assign lsu_read_exec_reg_in_is_store_or_not_load = lsu_issue_read_reg_out_is_store_or_not_load;
            assign lsu_read_exec_reg_in_rob_id               = lsu_issue_read_reg_out_rob_id;



            assign lsu_read_exec_reg_in_sel_load_store_len   = lsu_issue_read_reg_out_sel_load_store_len;

            assign lsu_read_exec_reg_in_bid                  = lsu_issue_read_reg_out_bid;



            assign lsu_read_exec_reg_in_is_cacop = lsu_issue_read_reg_out_is_cacop;


            wire lsu_read_exec_reg_in_is_ll_w;
            wire lsu_read_exec_reg_in_is_sc_w;
            wire lsu_read_exec_reg_in_is_dbar;
            wire lsu_read_exec_reg_out_is_ll_w;
            wire lsu_read_exec_reg_out_is_sc_w;
            wire lsu_read_exec_reg_out_is_dbar;

            assign lsu_read_exec_reg_in_is_ll_w = lsu_issue_read_reg_out_is_ll_w;
            assign lsu_read_exec_reg_in_is_sc_w = lsu_issue_read_reg_out_is_sc_w;
            assign lsu_read_exec_reg_in_is_dbar = lsu_issue_read_reg_out_is_dbar;



            lsu_read_exec_reg u_lsu_read_exec_reg (
                                  .clk   (clk),
                                  .resetn(resetn),

                                  .stall    (lsu_read_exec_reg_stall),
                                  .pre_stall(lsu_read_exec_reg_pre_stall),

                                  .in_valid               (lsu_read_exec_reg_in_valid),
                                  .in_phy_reg_src2        (lsu_read_exec_reg_in_phy_reg_src2),
                                  .in_phy_reg_src2_rdy    (lsu_read_exec_reg_in_phy_reg_src2_rdy),
                                  .in_phy_reg_rdata1      (lsu_read_exec_reg_in_phy_reg_rdata1),
                                  .in_phy_reg_rdata2      (lsu_read_exec_reg_in_phy_reg_rdata2),
                                  .in_phy_reg_dst         (lsu_read_exec_reg_in_phy_reg_dst),
                                  .in_extended_imm        (lsu_read_exec_reg_in_extended_imm),
                                  .in_is_store_or_not_load(lsu_read_exec_reg_in_is_store_or_not_load),
                                  .in_rob_id              (lsu_read_exec_reg_in_rob_id),
                                  .in_sel_load_store_len  (lsu_read_exec_reg_in_sel_load_store_len),
                                  .in_bid                 (lsu_read_exec_reg_in_bid),
                                  .in_is_cacop            (lsu_read_exec_reg_in_is_cacop),
                                  .in_is_ll_w(lsu_read_exec_reg_in_is_ll_w),
                                  .in_is_sc_w(lsu_read_exec_reg_in_is_sc_w),
                                  .in_is_dbar(lsu_read_exec_reg_in_is_dbar),
                                  .store_data_bypass_valid(lsu_read_exec_store_data_bypass_valid),
                                  .store_data_bypass_data(lsu_read_exec_store_data_bypass_data),

                                  .out_valid               (lsu_read_exec_reg_out_valid),
                                  .out_phy_reg_src2        (lsu_read_exec_reg_out_phy_reg_src2),
                                  .out_phy_reg_src2_rdy    (lsu_read_exec_reg_out_phy_reg_src2_rdy),
                                  .out_phy_reg_rdata1      (lsu_read_exec_reg_out_phy_reg_rdata1),
                                  .out_phy_reg_rdata2      (lsu_read_exec_reg_out_phy_reg_rdata2),
                                  .out_phy_reg_dst         (lsu_read_exec_reg_out_phy_reg_dst),
                                  .out_extended_imm        (lsu_read_exec_reg_out_extended_imm),
                                  .out_is_store_or_not_load(lsu_read_exec_reg_out_is_store_or_not_load),
                                  .out_rob_id              (lsu_read_exec_reg_out_rob_id),
                                  .out_sel_load_store_len  (lsu_read_exec_reg_out_sel_load_store_len),
                                  .out_bid                 (lsu_read_exec_reg_out_bid),
                                  .out_is_cacop            (lsu_read_exec_reg_out_is_cacop),
                                  .out_is_ll_w(lsu_read_exec_reg_out_is_ll_w),
                                  .out_is_sc_w(lsu_read_exec_reg_out_is_sc_w),
                                  .out_is_dbar(lsu_read_exec_reg_out_is_dbar)
                              );


            assign lsu_exec_address = lsu_read_exec_reg_out_phy_reg_rdata1 + lsu_read_exec_reg_out_extended_imm;

            assign is_ale = (lsu_read_exec_reg_out_sel_load_store_len == `SEL_LOAD_STORE_W && lsu_exec_address[1:0] != 2'b00) || ((lsu_read_exec_reg_out_sel_load_store_len == `SEL_LOAD_STORE_H || lsu_read_exec_reg_out_sel_load_store_len == `SEL_LOAD_STORE_HU) && lsu_exec_address[0] != 1'b0);




            assign select_store_addr = lsu_exec_address;
            assign select_store_data = lsu_read_exec_reg_out_phy_reg_rdata2;
            assign select_store_sel_load_store_len = lsu_read_exec_reg_out_sel_load_store_len;

            select_store u_select_store (
                             .addr              (select_store_addr),
                             .data              (select_store_data),
                             .sel_load_store_len(select_store_sel_load_store_len),

                             .wstrb (select_store_wstrb),
                             .result(select_store_result)
                         );




            assign lsu_exec_mem1_state_in_is_exception = is_ale || mmu_data_ex_tlbr || mmu_data_ex_ppi || mmu_data_ex_pme || mmu_data_ex_pis || mmu_data_ex_pil;
            assign lsu_exec_mem1_state_in_is_ale       = is_ale;
            assign lsu_exec_mem1_state_in_is_tlbr      = !is_ale && mmu_data_ex_tlbr;
            assign lsu_exec_mem1_state_in_is_data_tlbr = mmu_data_ex_tlbr;
            assign lsu_exec_mem1_state_in_is_data_pil  = mmu_data_ex_pil;
            assign lsu_exec_mem1_state_in_is_data_pis  = mmu_data_ex_pis;
            assign lsu_exec_mem1_state_in_is_data_ppi  = mmu_data_ex_ppi;
            assign lsu_exec_mem1_state_in_is_data_pme  = mmu_data_ex_pme;
            assign lsu_exec_mem1_state_in_mmu_data_mat = mmu_data_mat;


            lsu_state u_lsu_exec_mem1_state (
                          .clk   (clk),
                          .resetn(resetn),
                          .stall (lsu_exec_mem1_reg_stall),

                          .in_is_exception(lsu_exec_mem1_state_in_is_exception),
                          .in_is_ale      (lsu_exec_mem1_state_in_is_ale),
                          .in_is_tlbr     (lsu_exec_mem1_state_in_is_tlbr),
                          .in_is_data_tlbr(lsu_exec_mem1_state_in_is_data_tlbr),
                          .in_is_data_pil (lsu_exec_mem1_state_in_is_data_pil),
                          .in_is_data_pis (lsu_exec_mem1_state_in_is_data_pis),
                          .in_is_data_ppi (lsu_exec_mem1_state_in_is_data_ppi),
                          .in_is_data_pme (lsu_exec_mem1_state_in_is_data_pme),
                          .in_mmu_data_mat(lsu_exec_mem1_state_in_mmu_data_mat),

                          .out_is_exception(lsu_exec_mem1_state_out_is_exception),
                          .out_is_ale      (lsu_exec_mem1_state_out_is_ale),
                          .out_is_tlbr     (lsu_exec_mem1_state_out_is_tlbr),
                          .out_is_data_tlbr(lsu_exec_mem1_state_out_is_data_tlbr),
                          .out_is_data_pil (lsu_exec_mem1_state_out_is_data_pil),
                          .out_is_data_pis (lsu_exec_mem1_state_out_is_data_pis),
                          .out_is_data_ppi (lsu_exec_mem1_state_out_is_data_ppi),
                          .out_is_data_pme (lsu_exec_mem1_state_out_is_data_pme),
                          .out_mmu_data_mat(lsu_exec_mem1_state_out_mmu_data_mat)
                      );


            wire lsu_exec_mem1_reg_in_is_ll_w;
            wire lsu_exec_mem1_reg_in_is_sc_w;
            wire lsu_exec_mem1_reg_in_is_dbar;
            wire lsu_exec_mem1_reg_out_is_ll_w;
            wire lsu_exec_mem1_reg_out_is_sc_w;
            wire lsu_exec_mem1_reg_out_is_dbar;

            assign lsu_exec_mem1_reg_in_is_ll_w = lsu_read_exec_reg_out_is_ll_w;
            assign lsu_exec_mem1_reg_in_is_sc_w = lsu_read_exec_reg_out_is_sc_w;
            assign lsu_exec_mem1_reg_in_is_dbar = lsu_read_exec_reg_out_is_dbar;


            assign lsu_exec_mem1_reg_pre_stall               = lsu_read_exec_reg_stall;
            assign lsu_exec_mem1_reg_in_valid                = lsu_read_exec_reg_out_valid && !lsu_exec_clear;
            assign lsu_exec_mem1_reg_in_phy_reg_dst          = lsu_read_exec_reg_out_phy_reg_dst;
            assign lsu_exec_mem1_reg_in_is_store_or_not_load = lsu_read_exec_reg_out_is_store_or_not_load;
            assign lsu_exec_mem1_reg_in_rob_id               = lsu_read_exec_reg_out_rob_id;
            assign lsu_exec_mem1_reg_in_sel_load_store_len   = lsu_read_exec_reg_out_sel_load_store_len;
            assign lsu_exec_mem1_reg_in_wstrb                = select_store_wstrb;
            assign lsu_exec_mem1_reg_in_address              = lsu_exec_address;
            assign lsu_exec_mem1_reg_in_store_data           = select_store_result;
            assign lsu_exec_mem1_reg_in_store_data_psrc      = lsu_read_exec_reg_out_phy_reg_src2;
            assign lsu_exec_mem1_reg_in_store_data_prdy      = lsu_read_exec_store_data_prdy_next;
            assign lsu_exec_mem1_reg_in_store_data_raw       = lsu_read_exec_store_data_next;
            assign lsu_exec_mem1_reg_in_bid                  = lsu_read_exec_reg_out_bid;
            assign lsu_exec_mem1_reg_in_store_ctrl           = 1'b0;


            assign lsu_exec_mem1_reg_in_address_pa = mmu_data_pa;



            assign lsu_exec_mem1_reg_in_is_cacop = lsu_read_exec_reg_out_is_cacop;

            assign lsu_exec_mem1_store_data_bypass_hit[1]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass1_valid
                   && bypass1_dst == lsu_exec_mem1_reg_out_store_data_psrc;
            assign lsu_exec_mem1_store_data_bypass_hit[2]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass2_valid
                   && bypass2_dst == lsu_exec_mem1_reg_out_store_data_psrc;
            assign lsu_exec_mem1_store_data_bypass_hit[3]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass3_valid
                   && bypass3_dst == lsu_exec_mem1_reg_out_store_data_psrc;
            assign lsu_exec_mem1_store_data_bypass_hit[4]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass4_valid
                   && bypass4_dst == lsu_exec_mem1_reg_out_store_data_psrc;
            assign lsu_exec_mem1_store_data_bypass_hit[5]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass5_valid
                   && bypass5_dst == lsu_exec_mem1_reg_out_store_data_psrc;
            assign lsu_exec_mem1_store_data_bypass_hit[6]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass6_valid
                   && bypass6_dst == lsu_exec_mem1_reg_out_store_data_psrc;
            assign lsu_exec_mem1_store_data_bypass_hit[7]
                   = lsu_exec_mem1_reg_out_valid
                   && lsu_exec_mem1_reg_out_is_store_or_not_load
                   && !lsu_exec_mem1_reg_out_store_data_prdy
                   && lsu_exec_mem1_reg_out_store_data_psrc != 7'd0
                   && bypass7_valid
                   && bypass7_dst == lsu_exec_mem1_reg_out_store_data_psrc;

            assign lsu_exec_mem1_store_data_bypass_valid
                   = |lsu_exec_mem1_store_data_bypass_hit;
            assign lsu_exec_mem1_store_data_bypass_data
                   = lsu_exec_mem1_store_data_bypass_hit[1] ? bypass1_data
                   : lsu_exec_mem1_store_data_bypass_hit[2] ? bypass2_data
                   : lsu_exec_mem1_store_data_bypass_hit[3] ? bypass3_data
                   : lsu_exec_mem1_store_data_bypass_hit[4] ? bypass4_data
                   : lsu_exec_mem1_store_data_bypass_hit[5] ? bypass5_data
                   : lsu_exec_mem1_store_data_bypass_hit[6] ? bypass6_data
                   : lsu_exec_mem1_store_data_bypass_hit[7] ? bypass7_data
                   : lsu_exec_mem1_reg_out_store_data_raw;
            assign lsu_exec_mem1_store_data_prdy_next
                   = lsu_exec_mem1_reg_out_store_data_prdy
                   || lsu_exec_mem1_store_data_bypass_valid;
            assign lsu_exec_mem1_store_data_next
                   = lsu_exec_mem1_reg_out_store_data_prdy
                   ? lsu_exec_mem1_reg_out_store_data_raw
                   : lsu_exec_mem1_store_data_bypass_data;

            select_store u_store_completion_select_store (
                             .addr              (lsu_exec_mem1_reg_out_address[1:0]),
                             .data              (lsu_exec_mem1_store_data_next),
                             .sel_load_store_len(lsu_exec_mem1_reg_out_sel_load_store_len),

                             .wstrb (store_completion_wstrb),
                             .result(store_completion_data)
                         );

            // SQ entries keep raw producer data.  The existing Cache interface
            // consumes lane-formatted data together with wstrb, so format only
            // at the committed Store drain boundary.
            select_store u_lqsq_store_out_select_store (
                             .addr(lqsq_out_reserved[
                                       LQSQ_VADDR_LSB+1:LQSQ_VADDR_LSB]),
                             .data(lqsq_out_data),
                             .sel_load_store_len(lqsq_out_reserved[
                                                     LQSQ_LEN_MSB:LQSQ_LEN_LSB]),

                             .wstrb(lqsq_store_out_wstrb_formatted),
                             .result(lqsq_store_out_data_formatted)
                         );




            lsu_exec_mem1_reg u_lsu_exec_mem1_reg (
                                  .clk   (clk),
                                  .resetn(resetn),

                                  .stall    (lsu_exec_mem1_reg_stall),
                                  .pre_stall(lsu_exec_mem1_reg_pre_stall),

                                  .in_valid               (lsu_exec_mem1_reg_in_valid),
                                  .in_phy_reg_dst         (lsu_exec_mem1_reg_in_phy_reg_dst),
                                  .in_is_store_or_not_load(lsu_exec_mem1_reg_in_is_store_or_not_load),
                                  .in_rob_id              (lsu_exec_mem1_reg_in_rob_id),
                                  .in_sel_load_store_len  (lsu_exec_mem1_reg_in_sel_load_store_len),
                                  .in_wstrb               (lsu_exec_mem1_reg_in_wstrb),
                                  .in_address             (lsu_exec_mem1_reg_in_address),
                                  .in_store_data          (lsu_exec_mem1_reg_in_store_data),
                                  .in_store_data_psrc     (lsu_exec_mem1_reg_in_store_data_psrc),
                                  .in_store_data_prdy     (lsu_exec_mem1_reg_in_store_data_prdy),
                                  .in_store_data_raw      (lsu_exec_mem1_reg_in_store_data_raw),
                                  .in_bid                 (lsu_exec_mem1_reg_in_bid),
                                  .in_store_ctrl          (lsu_exec_mem1_reg_in_store_ctrl),
                                  .in_address_pa          (lsu_exec_mem1_reg_in_address_pa),
                                  .in_is_cacop            (lsu_exec_mem1_reg_in_is_cacop),
                                  .in_is_ll_w(lsu_exec_mem1_reg_in_is_ll_w),
                                  .in_is_sc_w(lsu_exec_mem1_reg_in_is_sc_w),
                                  .in_is_dbar(lsu_exec_mem1_reg_in_is_dbar),
                                  .store_data_bypass_valid(lsu_exec_mem1_store_data_bypass_valid),
                                  .store_data_bypass_data(lsu_exec_mem1_store_data_bypass_data),

                                  .out_valid               (lsu_exec_mem1_reg_out_valid),
                                  .out_phy_reg_dst         (lsu_exec_mem1_reg_out_phy_reg_dst),
                                  .out_is_store_or_not_load(lsu_exec_mem1_reg_out_is_store_or_not_load),
                                  .out_rob_id              (lsu_exec_mem1_reg_out_rob_id),
                                  .out_sel_load_store_len  (lsu_exec_mem1_reg_out_sel_load_store_len),
                                  .out_wstrb               (lsu_exec_mem1_reg_out_wstrb),
                                  .out_address             (lsu_exec_mem1_reg_out_address),
                                  .out_store_data          (lsu_exec_mem1_reg_out_store_data),
                                  .out_store_data_psrc     (lsu_exec_mem1_reg_out_store_data_psrc),
                                  .out_store_data_prdy     (lsu_exec_mem1_reg_out_store_data_prdy),
                                  .out_store_data_raw      (lsu_exec_mem1_reg_out_store_data_raw),
                                  .out_bid                 (lsu_exec_mem1_reg_out_bid),
                                  .out_store_ctrl          (lsu_exec_mem1_reg_out_store_ctrl),
                                  .out_address_pa          (lsu_exec_mem1_reg_out_address_pa),
                                  .out_is_cacop            (lsu_exec_mem1_reg_out_is_cacop),
                                  .out_is_ll_w(lsu_exec_mem1_reg_out_is_ll_w),
                                  .out_is_sc_w(lsu_exec_mem1_reg_out_is_sc_w),
                                  .out_is_dbar(lsu_exec_mem1_reg_out_is_dbar)
                              );




            assign lsu_mem1_is_ordinary_memory
                   = lsu_exec_mem1_reg_out_valid
                   && !lsu_exec_mem1_state_out_is_exception
                   && !lsu_exec_mem1_reg_out_is_cacop
                   && !lsu_exec_mem1_reg_out_is_ll_w
                   && !lsu_exec_mem1_reg_out_is_sc_w
                   && !lsu_exec_mem1_reg_out_is_dbar;
            assign lsu_mem1_is_ordinary_load
                   = lsu_mem1_is_ordinary_memory
                   && !lsu_exec_mem1_reg_out_is_store_or_not_load;
            assign lsu_mem1_is_ordinary_store
                   = lsu_mem1_is_ordinary_memory
                   && lsu_exec_mem1_reg_out_is_store_or_not_load;
            assign lsu_mem1_direct_valid
                   = lsu_exec_mem1_reg_out_valid
                   && !lsu_mem1_is_ordinary_memory;
            assign lsu_mem1_direct_cc_busy_block
                   = lsu_mem1_direct_valid
                   && !lsu_exec_mem1_state_out_is_exception
                   && !lsu_exec_mem1_reg_out_is_store_or_not_load
                   && lsu_exec_mem1_state_out_mmu_data_mat == 2'b01
                   && cache_subsystem_dcache_busy;

            assign store_queue_drain_valid
                   = lqsq_out_valid && lqsq_out_is_store_or_not_load;
            assign store_queue_drain_mat = {1'b0, lqsq_out_mat};

            assign lqsq_store_out_selected = sel_store_commit;
            assign lsu_mem1_direct_selected
                   = !lqsq_store_out_selected
                   && lsu_mem1_direct_valid;
            assign lqsq_load_out_selected
                   = !lqsq_store_out_selected
                   && !lsu_mem1_direct_selected
                   && lqsq_out_valid
                   && !lqsq_out_is_store_or_not_load;
            assign store_completion_selected
                   = !lqsq_store_out_selected
                   && !lsu_mem1_direct_selected
                   && !lqsq_load_out_selected
                   && lsu_mem1_is_ordinary_store;

            assign lqsq_out_ready
                   = !global_flush
                   && !predict_flush
                   && !lsu_mem1_mem2_reg_stall
                   && (lqsq_out_is_store_or_not_load
                       ? !sel_store_stall
                       : !lsu_mem1_direct_valid
                       && !(lqsq_out_mat
                            && cache_subsystem_dcache_busy));
            assign lqsq_out_fire = lqsq_out_valid && lqsq_out_ready;
            assign lqsq_store_out_fire
                   = lqsq_out_fire && lqsq_out_is_store_or_not_load;
            assign lqsq_load_out_fire
                   = lqsq_out_fire && !lqsq_out_is_store_or_not_load;

            assign lqsq_in_valid
                   = lsu_mem1_is_ordinary_load
                   || (store_completion_selected
                       && !global_flush
                       && !predict_flush
                       && !lsu_mem1_mem2_reg_stall);
            assign lqsq_in_fire = lqsq_in_valid && lqsq_in_ready;
            assign lqsq_in_is_store_or_not_load
                   = lsu_exec_mem1_reg_out_is_store_or_not_load;
            assign lqsq_in_mat
                   = lsu_exec_mem1_state_out_mmu_data_mat[0];
            assign lqsq_in_address = lsu_exec_mem1_reg_out_address_pa;
            assign lqsq_in_wstrb = lsu_exec_mem1_reg_out_wstrb;
            assign lqsq_in_bid = lsu_exec_mem1_reg_out_bid;
            assign lqsq_in_reserved = {
                       lsu_exec_mem1_reg_out_phy_reg_dst,
                       lsu_exec_mem1_reg_out_rob_id,
                       lsu_exec_mem1_reg_out_sel_load_store_len,
                       lsu_exec_mem1_reg_out_address
                   };
            assign lqsq_in_prdy = lsu_exec_mem1_store_data_prdy_next;
            assign lqsq_in_psrc = lsu_exec_mem1_reg_out_store_data_psrc;
            assign lqsq_in_data = lsu_exec_mem1_store_data_next;

            assign lsu_mem1_direct_fire
                   = lsu_mem1_direct_selected
                   && !global_flush
                   && !predict_flush
                   && !lsu_mem1_direct_cc_busy_block
                   && !lsu_mem1_mem2_reg_stall;
            assign store_completion_fire
                   = store_completion_selected && lqsq_in_fire;
            assign lsu_mem1_current_fire
                   = lsu_mem1_is_ordinary_load ? lqsq_in_fire
                   : lsu_mem1_is_ordinary_store ? store_completion_fire
                   : lsu_mem1_direct_fire;

            assign store_queue_commit_count =
                   {2'b00, rob_commit_fire[0] &&
                    rob_commit_inst_type[0] == `SEL_ISSUE_QUEUE_STORE &&
                    !rob_commit_is_exception[0]} +
                   {2'b00, rob_commit_fire[1] &&
                    rob_commit_inst_type[1] == `SEL_ISSUE_QUEUE_STORE &&
                    !rob_commit_is_exception[1]} +
                   {2'b00, rob_commit_fire[2] &&
                    rob_commit_inst_type[2] == `SEL_ISSUE_QUEUE_STORE &&
                    !rob_commit_is_exception[2]} +
                   {2'b00, rob_commit_fire[3] &&
                    rob_commit_inst_type[3] == `SEL_ISSUE_QUEUE_STORE &&
                    !rob_commit_is_exception[3]};

            load_store_queue #(
                                 .TAG_WIDTH(7),
                                 .BID_WIDTH(5),
                                 .RESERVED_WIDTH(LQSQ_RESERVED_WIDTH)
                             ) u_load_store_queue (
                                 .clk(clk),
                                 .resetn(resetn),
                                 .global_flush(global_flush),
                                 .predict_flush(predict_flush),
                                 .predict_flush_bid(predict_flush_bid),
                                 .head_bid(branch_id_allocator_bid_head),
                                 .commit_count(store_queue_commit_count),
                                 .in_valid(lqsq_in_valid),
                                 .in_ready(lqsq_in_ready),
                                 .in_is_store_or_not_load(
                                     lqsq_in_is_store_or_not_load),
                                 .in_mat(lqsq_in_mat),
                                 .in_address(lqsq_in_address),
                                 .in_wstrb(lqsq_in_wstrb),
                                 .in_bid(lqsq_in_bid),
                                 .in_reserved(lqsq_in_reserved),
                                 .in_prdy(lqsq_in_prdy),
                                 .in_psrc(lqsq_in_psrc),
                                 .in_data(lqsq_in_data),
                                 .bypass1_valid(bypass1_valid),
                                 .bypass1_dst(bypass1_dst),
                                 .bypass1_data(bypass1_data),
                                 .bypass2_valid(bypass2_valid),
                                 .bypass2_dst(bypass2_dst),
                                 .bypass2_data(bypass2_data),
                                 .bypass3_valid(bypass3_valid),
                                 .bypass3_dst(bypass3_dst),
                                 .bypass3_data(bypass3_data),
                                 .bypass4_valid(bypass4_valid),
                                 .bypass4_dst(bypass4_dst),
                                 .bypass4_data(bypass4_data),
                                 .bypass5_valid(bypass5_valid),
                                 .bypass5_dst(bypass5_dst),
                                 .bypass5_data(bypass5_data),
                                 .bypass6_valid(bypass6_valid),
                                 .bypass6_dst(bypass6_dst),
                                 .bypass6_data(bypass6_data),
                                 .bypass7_valid(bypass7_valid),
                                 .bypass7_dst(bypass7_dst),
                                 .bypass7_data(bypass7_data),
                                 .out_valid(lqsq_out_valid),
                                 .out_ready(lqsq_out_ready),
                                 .out_is_store_or_not_load(
                                     lqsq_out_is_store_or_not_load),
                                 .out_mat(lqsq_out_mat),
                                 .out_address(lqsq_out_address),
                                 .out_data(lqsq_out_data),
                                 .out_wstrb(lqsq_out_wstrb),
                                 .load_data_out_bit_mask(
                                     lqsq_out_load_data_bit_mask),
                                 .out_bid(lqsq_out_bid),
                                 .out_reserved(lqsq_out_reserved),
                                 .sq_uncommitted_count(
                                     store_queue_uncommitted_count),
                                 .sq_entry_valid(lqsq_sq_entry_valid),
                                 .sq_entry_next_prdy(lqsq_sq_entry_next_prdy),
                                 .sq_entry_next_data_flat(
                                     lqsq_sq_entry_next_data_flat),
                                 .sq_entry_reserved_flat(
                                     lqsq_sq_entry_reserved_flat)
                             );



            assign lsu_mem1_mem2_state_in_is_exception
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_exception;
            assign lsu_mem1_mem2_state_in_is_ale
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_ale;
            assign lsu_mem1_mem2_state_in_is_tlbr
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_tlbr;
            assign lsu_mem1_mem2_state_in_is_data_tlbr
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_data_tlbr;
            assign lsu_mem1_mem2_state_in_is_data_pil
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_data_pil;
            assign lsu_mem1_mem2_state_in_is_data_pis
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_data_pis;
            assign lsu_mem1_mem2_state_in_is_data_ppi
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_data_ppi;
            assign lsu_mem1_mem2_state_in_is_data_pme
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_state_out_is_data_pme;
            assign lsu_mem1_mem2_state_in_mmu_data_mat
                   = lqsq_out_fire ? {1'b0, lqsq_out_mat}
                   : (lsu_mem1_direct_fire || store_completion_fire)
                   ? lsu_exec_mem1_state_out_mmu_data_mat : 2'b0;


            lsu_state u_lsu_mem1_mem2_state (
                          .clk   (clk),
                          .resetn(resetn),
                          .stall (lsu_mem1_mem2_reg_stall),

                          .in_is_exception(lsu_mem1_mem2_state_in_is_exception),
                          .in_is_ale      (lsu_mem1_mem2_state_in_is_ale),
                          .in_is_tlbr     (lsu_mem1_mem2_state_in_is_tlbr),
                          .in_is_data_tlbr(lsu_mem1_mem2_state_in_is_data_tlbr),
                          .in_is_data_pil (lsu_mem1_mem2_state_in_is_data_pil),
                          .in_is_data_pis (lsu_mem1_mem2_state_in_is_data_pis),
                          .in_is_data_ppi (lsu_mem1_mem2_state_in_is_data_ppi),
                          .in_is_data_pme (lsu_mem1_mem2_state_in_is_data_pme),
                          .in_mmu_data_mat(lsu_mem1_mem2_state_in_mmu_data_mat),

                          .out_is_exception(lsu_mem1_mem2_state_out_is_exception),
                          .out_is_ale      (lsu_mem1_mem2_state_out_is_ale),
                          .out_is_tlbr     (lsu_mem1_mem2_state_out_is_tlbr),
                          .out_is_data_tlbr(lsu_mem1_mem2_state_out_is_data_tlbr),
                          .out_is_data_pil (lsu_mem1_mem2_state_out_is_data_pil),
                          .out_is_data_pis (lsu_mem1_mem2_state_out_is_data_pis),
                          .out_is_data_ppi (lsu_mem1_mem2_state_out_is_data_ppi),
                          .out_is_data_pme (lsu_mem1_mem2_state_out_is_data_pme),
                          .out_mmu_data_mat(lsu_mem1_mem2_state_out_mmu_data_mat)
                      );







            wire lsu_mem1_mem2_reg_in_is_ll_w;
            wire lsu_mem1_mem2_reg_in_is_sc_w;
            wire lsu_mem1_mem2_reg_in_is_dbar;
            wire lsu_mem1_mem2_reg_out_is_ll_w;
            wire lsu_mem1_mem2_reg_out_is_sc_w;
            wire lsu_mem1_mem2_reg_out_is_dbar;

            assign lsu_mem1_mem2_reg_in_is_ll_w
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_reg_out_is_ll_w;
            assign lsu_mem1_mem2_reg_in_is_sc_w
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_reg_out_is_sc_w;
            assign lsu_mem1_mem2_reg_in_is_dbar
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_reg_out_is_dbar;

            assign lsu_mem1_mem2_reg_pre_stall = 1'b0;
            assign lsu_mem1_mem2_reg_in_valid
                   = lqsq_out_fire
                   || lsu_mem1_direct_fire
                   || store_completion_fire;
            assign lsu_mem1_mem2_reg_in_phy_reg_dst
                   = lqsq_out_fire
                   ? lqsq_out_reserved[LQSQ_PDEST_MSB:LQSQ_PDEST_LSB]
                   : lsu_exec_mem1_reg_out_phy_reg_dst;
            assign lsu_mem1_mem2_reg_in_is_store_or_not_load
                   = lqsq_out_fire
                   ? lqsq_out_is_store_or_not_load
                   : lsu_exec_mem1_reg_out_is_store_or_not_load;
            assign lsu_mem1_mem2_reg_in_rob_id
                   = lqsq_out_fire
                   ? lqsq_out_reserved[LQSQ_ROB_MSB:LQSQ_ROB_LSB]
                   : lsu_exec_mem1_reg_out_rob_id;
            assign lsu_mem1_mem2_reg_in_sel_load_store_len
                   = lqsq_out_fire
                   ? lqsq_out_reserved[LQSQ_LEN_MSB:LQSQ_LEN_LSB]
                   : lsu_exec_mem1_reg_out_sel_load_store_len;
            assign lsu_mem1_mem2_reg_in_wstrb
                   = lqsq_store_out_fire
                   ? lqsq_store_out_wstrb_formatted
                   : lqsq_load_out_fire
                   ? lqsq_out_wstrb
                   : store_completion_fire
                   ? store_completion_wstrb
                   : lsu_exec_mem1_reg_out_wstrb;
            assign lsu_mem1_mem2_reg_in_address
                   = lqsq_out_fire
                   ? lqsq_out_reserved[LQSQ_VADDR_MSB:LQSQ_VADDR_LSB]
                   : lsu_exec_mem1_reg_out_address;
            assign lsu_mem1_mem2_reg_in_store_data
                   = lqsq_store_out_fire
                   ? lqsq_store_out_data_formatted
                   : lqsq_load_out_fire
                   ? lqsq_out_data
                   : store_completion_fire
                   ? store_completion_data
                   : lsu_exec_mem1_reg_out_store_data;
            assign lsu_mem1_mem2_reg_in_load_data
                   = lqsq_load_out_fire ? lqsq_out_data : 32'b0;
            assign lsu_mem1_mem2_reg_in_load_wstrb
                   = lqsq_load_out_fire
                   ? lqsq_out_load_data_bit_mask : 4'b0;
            assign lsu_mem1_mem2_reg_in_bid
                   = lqsq_out_fire
                   ? lqsq_out_bid : lsu_exec_mem1_reg_out_bid;
            assign lsu_mem1_mem2_reg_in_store_ctrl
                   = lqsq_store_out_fire;
            assign lsu_mem1_mem2_reg_in_address_pa
                   = lqsq_out_fire
                   ? lqsq_out_address : lsu_exec_mem1_reg_out_address_pa;
            assign lsu_mem1_mem2_reg_in_is_cacop
                   = lsu_mem1_direct_fire
                   && lsu_exec_mem1_reg_out_is_cacop;

            `ifndef SYNTHESIS
                    always @(posedge clk) begin
                        if (resetn) begin
                            if ((lqsq_store_out_fire && lsu_mem1_direct_fire)
                                    || (lqsq_store_out_fire && lqsq_load_out_fire)
                                    || (lqsq_store_out_fire && store_completion_fire)
                                    || (lsu_mem1_direct_fire && lqsq_load_out_fire)
                                    || (lsu_mem1_direct_fire && store_completion_fire)
                                    || (lqsq_load_out_fire && store_completion_fire))
                                $error("multiple LSU MEM1 winners fired");

                            if (store_completion_fire
                                    != (lqsq_in_fire
                                        && lqsq_in_is_store_or_not_load))
                                $error("store SQ input and completion are not atomic");

                            if ((global_flush || predict_flush)
                                    && (lqsq_in_fire || lqsq_out_fire
                                        || lsu_mem1_direct_fire
                                        || store_completion_fire))
                                $error("LSU external fire visible during flush");

                            if (lqsq_in_fire
                                    && lsu_exec_mem1_state_out_mmu_data_mat[1])
                                $error("illegal MAT encoding entered load/store queue");

                            if (lqsq_store_out_fire
                                    && !lsu_mem1_mem2_reg_in_store_ctrl)
                                $error("SQ drain missing store_ctrl");

                            if ((lsu_mem1_direct_fire
                                    || lqsq_load_out_fire
                                    || store_completion_fire)
                                    && lsu_mem1_mem2_reg_in_store_ctrl)
                                $error("non-drain LSU event asserted store_ctrl");

                        end
                    end
`endif


                    lsu_mem1_mem2_reg
                        u_lsu_mem1_mem2_reg (
                            .clk   (clk),
                            .resetn(resetn),

                            .stall    (lsu_mem1_mem2_reg_stall),
                            .pre_stall(lsu_mem1_mem2_reg_pre_stall),

                            .in_valid               (lsu_mem1_mem2_reg_in_valid),
                            .in_phy_reg_dst         (lsu_mem1_mem2_reg_in_phy_reg_dst),
                            .in_is_store_or_not_load(lsu_mem1_mem2_reg_in_is_store_or_not_load),
                            .in_rob_id              (lsu_mem1_mem2_reg_in_rob_id),
                            .in_sel_load_store_len  (lsu_mem1_mem2_reg_in_sel_load_store_len),
                            .in_wstrb               (lsu_mem1_mem2_reg_in_wstrb),
                            .in_address             (lsu_mem1_mem2_reg_in_address),
                            .in_store_data          (lsu_mem1_mem2_reg_in_store_data),
                            .in_load_data           (lsu_mem1_mem2_reg_in_load_data),
                            .in_load_wstrb          (lsu_mem1_mem2_reg_in_load_wstrb),
                            .in_bid                 (lsu_mem1_mem2_reg_in_bid),
                            .in_store_ctrl          (lsu_mem1_mem2_reg_in_store_ctrl),
                            .in_address_pa          (lsu_mem1_mem2_reg_in_address_pa),
                            .in_is_cacop            (lsu_mem1_mem2_reg_in_is_cacop),
                            .in_is_ll_w(lsu_mem1_mem2_reg_in_is_ll_w),
                            .in_is_sc_w(lsu_mem1_mem2_reg_in_is_sc_w),
                            .in_is_dbar(lsu_mem1_mem2_reg_in_is_dbar),

                            .out_valid               (lsu_mem1_mem2_reg_out_valid),
                            .out_phy_reg_dst         (lsu_mem1_mem2_reg_out_phy_reg_dst),
                            .out_is_store_or_not_load(lsu_mem1_mem2_reg_out_is_store_or_not_load),
                            .out_rob_id              (lsu_mem1_mem2_reg_out_rob_id),
                            .out_sel_load_store_len  (lsu_mem1_mem2_reg_out_sel_load_store_len),
                            .out_wstrb               (lsu_mem1_mem2_reg_out_wstrb),
                            .out_address             (lsu_mem1_mem2_reg_out_address),
                            .out_store_data          (lsu_mem1_mem2_reg_out_store_data),
                            .out_load_data           (lsu_mem1_mem2_reg_out_load_data),
                            .out_load_wstrb          (lsu_mem1_mem2_reg_out_load_wstrb),
                            .out_bid                 (lsu_mem1_mem2_reg_out_bid),
                            .out_store_ctrl          (lsu_mem1_mem2_reg_out_store_ctrl),
                            .out_address_pa          (lsu_mem1_mem2_reg_out_address_pa),
                            .out_is_cacop            (lsu_mem1_mem2_reg_out_is_cacop),
                            .out_is_ll_w(lsu_mem1_mem2_reg_out_is_ll_w),
                            .out_is_sc_w(lsu_mem1_mem2_reg_out_is_sc_w),
                            .out_is_dbar(lsu_mem1_mem2_reg_out_is_dbar)
                        );




            assign lsu_mem2_load_miss             = (lsu_mem1_mem2_reg_out_load_wstrb & lsu_mem1_mem2_reg_out_wstrb) != lsu_mem1_mem2_reg_out_wstrb;



            assign select_load_addr               = lsu_mem1_mem2_reg_out_address[1:0];
            assign select_load_data[31:24]        = lsu_mem1_mem2_reg_out_load_wstrb[3] ? lsu_mem1_mem2_reg_out_load_data[31:24] : data_sram_rdata[31:24];  // ******
            assign select_load_data[23:16]        = lsu_mem1_mem2_reg_out_load_wstrb[2] ? lsu_mem1_mem2_reg_out_load_data[23:16] : data_sram_rdata[23:16];
            assign select_load_data[15:8]         = lsu_mem1_mem2_reg_out_load_wstrb[1] ? lsu_mem1_mem2_reg_out_load_data[15:8] : data_sram_rdata[15:8];
            assign select_load_data[7:0]          = lsu_mem1_mem2_reg_out_load_wstrb[0] ? lsu_mem1_mem2_reg_out_load_data[7:0] : data_sram_rdata[7:0];

            assign select_load_sel_load_store_len = lsu_mem1_mem2_reg_out_sel_load_store_len;



            select_load u_select_load (
                            .addr              (select_load_addr),
                            .data              (select_load_data),
                            .sel_load_store_len(select_load_sel_load_store_len),

                            .result(select_load_result)
                        );




            assign lsu_mem2_writeback_state_in_is_exception = lsu_mem1_mem2_state_out_is_exception;
            assign lsu_mem2_writeback_state_in_is_ale       = lsu_mem1_mem2_state_out_is_ale;
            assign lsu_mem2_writeback_state_in_is_tlbr      = lsu_mem1_mem2_state_out_is_tlbr;
            assign lsu_mem2_writeback_state_in_is_data_tlbr = lsu_mem1_mem2_state_out_is_data_tlbr;
            assign lsu_mem2_writeback_state_in_is_data_pil  = lsu_mem1_mem2_state_out_is_data_pil;
            assign lsu_mem2_writeback_state_in_is_data_pis  = lsu_mem1_mem2_state_out_is_data_pis;
            assign lsu_mem2_writeback_state_in_is_data_ppi  = lsu_mem1_mem2_state_out_is_data_ppi;
            assign lsu_mem2_writeback_state_in_is_data_pme  = lsu_mem1_mem2_state_out_is_data_pme;
            assign lsu_mem2_writeback_state_in_mmu_data_mat = lsu_mem1_mem2_state_out_mmu_data_mat;


            lsu_state u_lsu_mem2_writeback_state (
                          .clk   (clk),
                          .resetn(resetn),
                          .stall (lsu_mem2_writeback_reg_stall),

                          .in_is_exception(lsu_mem2_writeback_state_in_is_exception),
                          .in_is_ale      (lsu_mem2_writeback_state_in_is_ale),
                          .in_is_tlbr     (lsu_mem2_writeback_state_in_is_tlbr),
                          .in_is_data_tlbr(lsu_mem2_writeback_state_in_is_data_tlbr),
                          .in_is_data_pil (lsu_mem2_writeback_state_in_is_data_pil),
                          .in_is_data_pis (lsu_mem2_writeback_state_in_is_data_pis),
                          .in_is_data_ppi (lsu_mem2_writeback_state_in_is_data_ppi),
                          .in_is_data_pme (lsu_mem2_writeback_state_in_is_data_pme),
                          .in_mmu_data_mat(lsu_mem2_writeback_state_in_mmu_data_mat),

                          .out_is_exception(lsu_mem2_writeback_state_out_is_exception),
                          .out_is_ale      (lsu_mem2_writeback_state_out_is_ale),
                          .out_is_tlbr     (lsu_mem2_writeback_state_out_is_tlbr),
                          .out_is_data_tlbr(lsu_mem2_writeback_state_out_is_data_tlbr),
                          .out_is_data_pil (lsu_mem2_writeback_state_out_is_data_pil),
                          .out_is_data_pis (lsu_mem2_writeback_state_out_is_data_pis),
                          .out_is_data_ppi (lsu_mem2_writeback_state_out_is_data_ppi),
                          .out_is_data_pme (lsu_mem2_writeback_state_out_is_data_pme),
                          .out_mmu_data_mat(lsu_mem2_writeback_state_out_mmu_data_mat)
                      );



            assign lsu_mem2_writeback_reg_pre_stall               = lsu_mem1_mem2_reg_stall;

            assign lsu_mem2_writeback_reg_in_valid                = lsu_mem1_mem2_reg_out_valid && !lsu_mem2_clear;
            assign lsu_mem2_writeback_reg_in_phy_reg_dst          = lsu_mem1_mem2_reg_out_phy_reg_dst;
            assign lsu_mem2_writeback_reg_in_is_store_or_not_load = lsu_mem1_mem2_reg_out_is_store_or_not_load;
            assign lsu_mem2_writeback_reg_in_result               = lsu_mem1_mem2_reg_out_is_sc_w ? csr_regfile_llbit :select_load_result;
            assign lsu_mem2_writeback_reg_in_rob_id               = lsu_mem1_mem2_reg_out_rob_id;

            assign lsu_mem2_writeback_reg_in_bid                  = lsu_mem1_mem2_reg_out_bid;

            assign lsu_mem2_writeback_reg_in_store_ctrl           = lsu_mem1_mem2_reg_out_store_ctrl;


            assign lsu_mem2_writeback_reg_in_vaddr                = lsu_mem1_mem2_reg_out_address;

            assign lsu_mem2_writeback_reg_in_paddr = lsu_mem1_mem2_reg_out_address_pa;


            assign lsu_mem2_writeback_reg_in_is_cacop = lsu_mem1_mem2_reg_out_is_cacop;


            wire lsu_mem2_writeback_reg_in_is_ll_w;
            wire lsu_mem2_writeback_reg_in_is_sc_w;
            wire lsu_mem2_writeback_reg_in_is_dbar;
            wire lsu_mem2_writeback_reg_out_is_ll_w;
            wire lsu_mem2_writeback_reg_out_is_sc_w;
            wire lsu_mem2_writeback_reg_out_is_dbar;

            assign lsu_mem2_writeback_reg_in_is_ll_w = lsu_mem1_mem2_reg_out_is_ll_w;
            assign lsu_mem2_writeback_reg_in_is_sc_w = lsu_mem1_mem2_reg_out_is_sc_w;
            assign lsu_mem2_writeback_reg_in_is_dbar = lsu_mem1_mem2_reg_out_is_dbar;

            lsu_mem2_writeback_reg u_lsu_mem2_writeback_reg (
                                       .clk   (clk),
                                       .resetn(resetn),

                                       .stall    (lsu_mem2_writeback_reg_stall),
                                       .pre_stall(lsu_mem2_writeback_reg_pre_stall),

                                       .in_valid               (lsu_mem2_writeback_reg_in_valid),
                                       .in_phy_reg_dst         (lsu_mem2_writeback_reg_in_phy_reg_dst),
                                       .in_is_store_or_not_load(lsu_mem2_writeback_reg_in_is_store_or_not_load),
                                       .in_result              (lsu_mem2_writeback_reg_in_result),
                                       .in_rob_id              (lsu_mem2_writeback_reg_in_rob_id),
                                       .in_bid                 (lsu_mem2_writeback_reg_in_bid),
                                       .in_store_ctrl          (lsu_mem2_writeback_reg_in_store_ctrl),
                                       .in_vaddr               (lsu_mem2_writeback_reg_in_vaddr),
                                       .in_paddr               (lsu_mem2_writeback_reg_in_paddr),
                                       .in_is_cacop            (lsu_mem2_writeback_reg_in_is_cacop),
                                       .in_is_ll_w(lsu_mem2_writeback_reg_in_is_ll_w),
                                       .in_is_sc_w(lsu_mem2_writeback_reg_in_is_sc_w),
                                       .in_is_dbar(lsu_mem2_writeback_reg_in_is_dbar),

                                       .out_valid               (lsu_mem2_writeback_reg_out_valid),
                                       .out_phy_reg_dst         (lsu_mem2_writeback_reg_out_phy_reg_dst),
                                       .out_is_store_or_not_load(lsu_mem2_writeback_reg_out_is_store_or_not_load),
                                       .out_result              (lsu_mem2_writeback_reg_out_result),
                                       .out_rob_id              (lsu_mem2_writeback_reg_out_rob_id),
                                       .out_bid                 (lsu_mem2_writeback_reg_out_bid),
                                       .out_store_ctrl          (lsu_mem2_writeback_reg_out_store_ctrl),
                                       .out_vaddr               (lsu_mem2_writeback_reg_out_vaddr),
                                       .out_paddr               (lsu_mem2_writeback_reg_out_paddr),
                                       .out_is_cacop            (lsu_mem2_writeback_reg_out_is_cacop),
                                       .out_is_ll_w(lsu_mem2_writeback_reg_out_is_ll_w),
                                       .out_is_sc_w(lsu_mem2_writeback_reg_out_is_sc_w),
                                       .out_is_dbar(lsu_mem2_writeback_reg_out_is_dbar)
                                   );



            assign md_issue_queue_flush                 = md_issue_clear;  //

            assign md_issue_queue_dispatch_opcode[0]       = {rename_dispatch_pipeline_queue_out_sel_npc[0] , rename_dispatch_pipeline_queue_out_comparator_op[0] , rename_dispatch_pipeline_queue_out_md_op[0] };
            assign md_issue_queue_dispatch_pdest[0]        = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0] ;
            assign md_issue_queue_dispatch_psrc0[0]        = rename_dispatch_pipeline_queue_out_phy_reg_src1[0] ;
            assign md_issue_queue_dispatch_prdy0[0]        = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[0] ;  //
            assign md_issue_queue_dispatch_psrc1[0]        = rename_dispatch_pipeline_queue_out_phy_reg_src2[0] ;
            assign md_issue_queue_dispatch_prdy1[0]        = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[0] ;  //
            assign md_issue_queue_dispatch_bid[0]          = rename_dispatch_pipeline_queue_out_bid[0];
            assign md_issue_queue_dispatch_rob_id[0]       = rob_alloc_rob_id[0];
            assign md_issue_queue_dispatch_inst_type[0][2] = |rename_dispatch_pipeline_queue_out_md_op[0][6:3];
            assign md_issue_queue_dispatch_inst_type[0][1] = |rename_dispatch_pipeline_queue_out_md_op[0][2:0];
            assign md_issue_queue_dispatch_inst_type[0][0] = rename_dispatch_pipeline_queue_out_sel_issue_queue[0] == `SEL_ISSUE_QUEUE_BRQ;


            assign md_issue_queue_dispatch_opcode[1]       = {rename_dispatch_pipeline_queue_out_sel_npc[1] , rename_dispatch_pipeline_queue_out_comparator_op[1] , rename_dispatch_pipeline_queue_out_md_op[1] };
            assign md_issue_queue_dispatch_pdest[1]        = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[1] ;
            assign md_issue_queue_dispatch_psrc0[1]        = rename_dispatch_pipeline_queue_out_phy_reg_src1[1] ;
            assign md_issue_queue_dispatch_prdy0[1]        = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[1] ;  //
            assign md_issue_queue_dispatch_psrc1[1]        = rename_dispatch_pipeline_queue_out_phy_reg_src2[1] ;
            assign md_issue_queue_dispatch_prdy1[1]        = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[1] ;  //
            assign md_issue_queue_dispatch_bid[1]          = rename_dispatch_pipeline_queue_out_bid[1];
            assign md_issue_queue_dispatch_rob_id[1]       = rob_alloc_rob_id[1];
            assign md_issue_queue_dispatch_inst_type[1][2] = |rename_dispatch_pipeline_queue_out_md_op[1][6:3];
            assign md_issue_queue_dispatch_inst_type[1][1] = |rename_dispatch_pipeline_queue_out_md_op[1][2:0];
            assign md_issue_queue_dispatch_inst_type[1][0] = rename_dispatch_pipeline_queue_out_sel_issue_queue[1] == `SEL_ISSUE_QUEUE_BRQ;


            assign md_issue_queue_dispatch_opcode[2]       = {rename_dispatch_pipeline_queue_out_sel_npc[2] , rename_dispatch_pipeline_queue_out_comparator_op[2] , rename_dispatch_pipeline_queue_out_md_op[2] };
            assign md_issue_queue_dispatch_pdest[2]        = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[2] ;
            assign md_issue_queue_dispatch_psrc0[2]        = rename_dispatch_pipeline_queue_out_phy_reg_src1[2] ;
            assign md_issue_queue_dispatch_prdy0[2]        = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[2] ;  //
            assign md_issue_queue_dispatch_psrc1[2]        = rename_dispatch_pipeline_queue_out_phy_reg_src2[2] ;
            assign md_issue_queue_dispatch_prdy1[2]        = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[2] ;  //
            assign md_issue_queue_dispatch_bid[2]          = rename_dispatch_pipeline_queue_out_bid[2];
            assign md_issue_queue_dispatch_rob_id[2]       = rob_alloc_rob_id[2];
            assign md_issue_queue_dispatch_inst_type[2][2] = |rename_dispatch_pipeline_queue_out_md_op[2][6:3];
            assign md_issue_queue_dispatch_inst_type[2][1] = |rename_dispatch_pipeline_queue_out_md_op[2][2:0];
            assign md_issue_queue_dispatch_inst_type[2][0] = rename_dispatch_pipeline_queue_out_sel_issue_queue[2] == `SEL_ISSUE_QUEUE_BRQ;


            assign md_issue_queue_dispatch_opcode[3]       = {rename_dispatch_pipeline_queue_out_sel_npc[3] , rename_dispatch_pipeline_queue_out_comparator_op[3] , rename_dispatch_pipeline_queue_out_md_op[3] };
            assign md_issue_queue_dispatch_pdest[3]        = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3] ;
            assign md_issue_queue_dispatch_psrc0[3]        = rename_dispatch_pipeline_queue_out_phy_reg_src1[3] ;
            assign md_issue_queue_dispatch_prdy0[3]        = rename_dispatch_pipeline_queue_update_phy_reg_src1_rdy[3] ;  //
            assign md_issue_queue_dispatch_psrc1[3]        = rename_dispatch_pipeline_queue_out_phy_reg_src2[3] ;
            assign md_issue_queue_dispatch_prdy1[3]        = rename_dispatch_pipeline_queue_update_phy_reg_src2_rdy[3] ;  //
            assign md_issue_queue_dispatch_bid[3]          = rename_dispatch_pipeline_queue_out_bid[3];
            assign md_issue_queue_dispatch_rob_id[3]       = rob_alloc_rob_id[3];
            assign md_issue_queue_dispatch_inst_type[3][2] = |rename_dispatch_pipeline_queue_out_md_op[3][6:3];
            assign md_issue_queue_dispatch_inst_type[3][1] = |rename_dispatch_pipeline_queue_out_md_op[3][2:0];
            assign md_issue_queue_dispatch_inst_type[3][0] = rename_dispatch_pipeline_queue_out_sel_issue_queue[3] == `SEL_ISSUE_QUEUE_BRQ;



            assign md_issue_queue_bypass1_valid         = bypass1_valid;
            assign md_issue_queue_bypass1_dst           = bypass1_dst;
            assign md_issue_queue_bypass2_valid         = bypass2_valid;
            assign md_issue_queue_bypass2_dst           = bypass2_dst;

            assign md_issue_queue_bypass3_valid         = bypass3_valid;
            assign md_issue_queue_bypass3_dst           = bypass3_dst;
            assign md_issue_queue_bypass4_valid         = bypass4_valid;
            assign md_issue_queue_bypass4_dst           = bypass4_dst;

            assign md_issue_queue_bypass5_valid         = bypass5_valid;
            assign md_issue_queue_bypass5_dst           = bypass5_dst;

            assign md_issue_queue_bypass6_valid         = bypass6_valid;
            assign md_issue_queue_bypass6_dst           = bypass6_dst;

            assign md_issue_queue_bypass7_valid         = bypass7_valid;
            assign md_issue_queue_bypass7_dst           = bypass7_dst;

            assign md_issue_queue_div_issue_ready       = !md_issue_queue_div_stall;
            assign md_issue_queue_mul_issue_ready       = !md_issue_queue_mul_stall;
            assign md_issue_queue_bru_issue_ready       = !md_issue_queue_bru_stall;




            assign md_issue_queue_predict_flush         = predict_flush;
            assign md_issue_queue_predict_flush_bid     = predict_flush_bid;
            assign md_issue_queue_head_bid              = branch_id_allocator_bid_head;







            md_issue_queue_lutram_core u_md_issue_queue (
                                           .clk   (clk),
                                           .resetn(resetn),
                                           .flush (md_issue_queue_flush),

                                           .dispatch_valid    (md_issue_queue_dispatch_valid),
                                           .dispatch_ready    (md_issue_queue_dispatch_ready),
                                           .dispatch_prdy0    (md_issue_queue_dispatch_prdy0),
                                           .dispatch_prdy1    (md_issue_queue_dispatch_prdy1),


                                           .dispatch_opcode_0   (md_issue_queue_dispatch_opcode[0]),
                                           .dispatch_pdest_0    (md_issue_queue_dispatch_pdest[0]),
                                           .dispatch_psrc0_0    (md_issue_queue_dispatch_psrc0[0]),
                                           .dispatch_psrc1_0    (md_issue_queue_dispatch_psrc1[0]),
                                           .dispatch_bid_0      (md_issue_queue_dispatch_bid[0]),
                                           .dispatch_rob_id_0   (md_issue_queue_dispatch_rob_id[0]),
                                           .dispatch_inst_type_0(md_issue_queue_dispatch_inst_type[0]),



                                           .dispatch_opcode_1   (md_issue_queue_dispatch_opcode[1]),
                                           .dispatch_pdest_1    (md_issue_queue_dispatch_pdest[1]),
                                           .dispatch_psrc0_1    (md_issue_queue_dispatch_psrc0[1]),
                                           .dispatch_psrc1_1    (md_issue_queue_dispatch_psrc1[1]),
                                           .dispatch_bid_1      (md_issue_queue_dispatch_bid[1]),
                                           .dispatch_rob_id_1   (md_issue_queue_dispatch_rob_id[1]),
                                           .dispatch_inst_type_1(md_issue_queue_dispatch_inst_type[1]),



                                           .dispatch_opcode_2   (md_issue_queue_dispatch_opcode[2]),
                                           .dispatch_pdest_2    (md_issue_queue_dispatch_pdest[2]),
                                           .dispatch_psrc0_2    (md_issue_queue_dispatch_psrc0[2]),
                                           .dispatch_psrc1_2    (md_issue_queue_dispatch_psrc1[2]),
                                           .dispatch_bid_2      (md_issue_queue_dispatch_bid[2]),
                                           .dispatch_rob_id_2   (md_issue_queue_dispatch_rob_id[2]),
                                           .dispatch_inst_type_2(md_issue_queue_dispatch_inst_type[2]),



                                           .dispatch_opcode_3   (md_issue_queue_dispatch_opcode[3]),
                                           .dispatch_pdest_3    (md_issue_queue_dispatch_pdest[3]),
                                           .dispatch_psrc0_3    (md_issue_queue_dispatch_psrc0[3]),
                                           .dispatch_psrc1_3    (md_issue_queue_dispatch_psrc1[3]),
                                           .dispatch_bid_3      (md_issue_queue_dispatch_bid[3]),
                                           .dispatch_rob_id_3   (md_issue_queue_dispatch_rob_id[3]),
                                           .dispatch_inst_type_3(md_issue_queue_dispatch_inst_type[3]),


                                           .bypass1_valid(md_issue_queue_bypass1_valid),
                                           .bypass1_dst  (md_issue_queue_bypass1_dst),
                                           .bypass2_valid(md_issue_queue_bypass2_valid),
                                           .bypass2_dst  (md_issue_queue_bypass2_dst),
                                           .bypass3_valid(md_issue_queue_bypass3_valid),
                                           .bypass3_dst  (md_issue_queue_bypass3_dst),
                                           .bypass4_valid(md_issue_queue_bypass4_valid),
                                           .bypass4_dst  (md_issue_queue_bypass4_dst),
                                           .bypass5_valid(md_issue_queue_bypass5_valid),
                                           .bypass5_dst  (md_issue_queue_bypass5_dst),
                                           .bypass6_valid(md_issue_queue_bypass6_valid),
                                           .bypass6_dst  (md_issue_queue_bypass6_dst),
                                           .bypass7_valid(md_issue_queue_bypass7_valid),
                                           .bypass7_dst  (md_issue_queue_bypass7_dst),

                                           .div_issue_valid (md_issue_queue_div_issue_valid),
                                           .div_issue_ready (md_issue_queue_div_issue_ready),
                                           .div_issue_opcode(md_issue_queue_div_issue_opcode),
                                           .div_issue_pdest (md_issue_queue_div_issue_pdest),
                                           .div_issue_psrc0 (md_issue_queue_div_issue_psrc0),
                                           .div_issue_psrc1 (md_issue_queue_div_issue_psrc1),
                                           .div_issue_bid   (md_issue_queue_div_issue_bid),
                                           .div_issue_rob_id(md_issue_queue_div_issue_rob_id),


                                           .mul_issue_valid (md_issue_queue_mul_issue_valid),
                                           .mul_issue_ready (md_issue_queue_mul_issue_ready),
                                           .mul_issue_opcode(md_issue_queue_mul_issue_opcode),
                                           .mul_issue_pdest (md_issue_queue_mul_issue_pdest),
                                           .mul_issue_psrc0 (md_issue_queue_mul_issue_psrc0),
                                           .mul_issue_psrc1 (md_issue_queue_mul_issue_psrc1),
                                           .mul_issue_bid   (md_issue_queue_mul_issue_bid),
                                           .mul_issue_rob_id(md_issue_queue_mul_issue_rob_id),


                                           .bru_issue_valid (md_issue_queue_bru_issue_valid),
                                           .bru_issue_ready (md_issue_queue_bru_issue_ready),
                                           .bru_issue_opcode(md_issue_queue_bru_issue_opcode),
                                           .bru_issue_pdest (md_issue_queue_bru_issue_pdest),
                                           .bru_issue_psrc0 (md_issue_queue_bru_issue_psrc0),
                                           .bru_issue_psrc1 (md_issue_queue_bru_issue_psrc1),
                                           .bru_issue_bid   (md_issue_queue_bru_issue_bid),
                                           .bru_issue_rob_id(md_issue_queue_bru_issue_rob_id),

                                           .full (md_issue_queue_full),
                                           .empty(md_issue_queue_empty),
                                           .count(md_issue_queue_count),

                                           .predict_flush    (md_issue_queue_predict_flush),
                                           .predict_flush_bid(md_issue_queue_predict_flush_bid),
                                           .head_bid         (md_issue_queue_head_bid)

                                       );



            assign md_div_issue_read_reg_pre_stall       = md_issue_queue_div_stall;
            assign md_div_issue_read_reg_in_valid        = md_issue_queue_div_issue_valid && !md_issue_clear;
            assign md_div_issue_read_reg_in_phy_reg_src1 = md_issue_queue_div_issue_psrc0;
            assign md_div_issue_read_reg_in_phy_reg_src2 = md_issue_queue_div_issue_psrc1;
            assign md_div_issue_read_reg_in_phy_reg_dst  = md_issue_queue_div_issue_pdest;
            assign md_div_issue_read_reg_in_div_op       = md_issue_queue_div_issue_opcode[6:3];
            assign md_div_issue_read_reg_in_rob_id       = md_issue_queue_div_issue_rob_id;
            assign md_div_issue_read_reg_in_bid          = md_issue_queue_div_issue_bid;

            md_div_issue_read_reg u_md_div_issue_read_reg (
                                      .clk   (clk),
                                      .resetn(resetn),

                                      .stall    (md_div_issue_read_reg_stall),
                                      .pre_stall(md_div_issue_read_reg_pre_stall),

                                      .in_valid       (md_div_issue_read_reg_in_valid),
                                      .in_phy_reg_src1(md_div_issue_read_reg_in_phy_reg_src1),
                                      .in_phy_reg_src2(md_div_issue_read_reg_in_phy_reg_src2),
                                      .in_phy_reg_dst (md_div_issue_read_reg_in_phy_reg_dst),
                                      .in_div_op      (md_div_issue_read_reg_in_div_op),
                                      .in_rob_id      (md_div_issue_read_reg_in_rob_id),
                                      .in_bid         (md_div_issue_read_reg_in_bid),

                                      .out_valid       (md_div_issue_read_reg_out_valid),
                                      .out_phy_reg_src1(md_div_issue_read_reg_out_phy_reg_src1),
                                      .out_phy_reg_src2(md_div_issue_read_reg_out_phy_reg_src2),
                                      .out_phy_reg_dst (md_div_issue_read_reg_out_phy_reg_dst),
                                      .out_div_op      (md_div_issue_read_reg_out_div_op),
                                      .out_rob_id      (md_div_issue_read_reg_out_rob_id),
                                      .out_bid         (md_div_issue_read_reg_out_bid)

                                  );

            assign div_reg_flush             = md_clear;

            assign div_reg_in_valid          = md_div_issue_read_reg_out_valid && !md_div_read_clear;
            assign div_reg_in_phy_reg_dst    = md_div_issue_read_reg_out_phy_reg_dst;
            assign div_reg_in_rob_id         = md_div_issue_read_reg_out_rob_id;
            assign div_reg_in_div_op         = md_div_issue_read_reg_out_div_op;
            assign div_reg_operand1          = physical_regfile_rdata5;
            assign div_reg_operand2          = physical_regfile_rdata6;
            assign div_reg_in_bid            = md_div_issue_read_reg_out_bid;




            assign div_reg_predict_flush     = predict_flush;
            assign div_reg_head_bid          = predict_flush_bid;
            assign div_reg_predict_flush_bid = branch_id_allocator_bid_head;


            div_reg u_div_reg (
                        .clk   (clk),
                        .resetn(resetn),

                        .flush(div_reg_flush),

                        .in_valid      (div_reg_in_valid),
                        .in_phy_reg_dst(div_reg_in_phy_reg_dst),
                        .in_rob_id     (div_reg_in_rob_id),
                        .in_div_op     (div_reg_in_div_op),
                        .in_bid        (div_reg_in_bid),

                        .operand1(div_reg_operand1),
                        .operand2(div_reg_operand2),

                        .out_valid      (div_reg_out_valid),
                        .out_phy_reg_dst(div_reg_out_phy_reg_dst),
                        .out_rob_id     (div_reg_out_rob_id),
                        .out_div_op     (div_reg_out_div_op),
                        .out_bid        (div_reg_out_bid),

                        .out_result(div_reg_out_result),

                        .predict_flush    (div_reg_predict_flush),
                        .predict_flush_bid(div_reg_head_bid),
                        .head_bid         (div_reg_predict_flush_bid)
                    );




            assign md_mul_issue_read_reg_pre_stall       = md_issue_queue_mul_stall;

            assign md_mul_issue_read_reg_in_valid        = md_issue_queue_mul_issue_valid && !md_issue_clear;
            assign md_mul_issue_read_reg_in_phy_reg_src1 = md_issue_queue_mul_issue_psrc0;
            assign md_mul_issue_read_reg_in_phy_reg_src2 = md_issue_queue_mul_issue_psrc1;
            assign md_mul_issue_read_reg_in_phy_reg_dst  = md_issue_queue_mul_issue_pdest;
            assign md_mul_issue_read_reg_in_mul_op       = md_issue_queue_mul_issue_opcode[2:0];
            assign md_mul_issue_read_reg_in_rob_id       = md_issue_queue_mul_issue_rob_id;
            assign md_mul_issue_read_reg_in_bid          = md_issue_queue_mul_issue_bid;

            md_mul_issue_read_reg u_md_mul_issue_read_reg (
                                      .clk   (clk),
                                      .resetn(resetn),

                                      .stall    (md_mul_issue_read_reg_stall),
                                      .pre_stall(md_mul_issue_read_reg_pre_stall),

                                      .in_valid       (md_mul_issue_read_reg_in_valid),
                                      .in_phy_reg_src1(md_mul_issue_read_reg_in_phy_reg_src1),
                                      .in_phy_reg_src2(md_mul_issue_read_reg_in_phy_reg_src2),
                                      .in_phy_reg_dst (md_mul_issue_read_reg_in_phy_reg_dst),
                                      .in_mul_op      (md_mul_issue_read_reg_in_mul_op),
                                      .in_rob_id      (md_mul_issue_read_reg_in_rob_id),
                                      .in_bid         (md_mul_issue_read_reg_in_bid),

                                      .out_valid       (md_mul_issue_read_reg_out_valid),
                                      .out_phy_reg_src1(md_mul_issue_read_reg_out_phy_reg_src1),
                                      .out_phy_reg_src2(md_mul_issue_read_reg_out_phy_reg_src2),
                                      .out_phy_reg_dst (md_mul_issue_read_reg_out_phy_reg_dst),
                                      .out_mul_op      (md_mul_issue_read_reg_out_mul_op),
                                      .out_rob_id      (md_mul_issue_read_reg_out_rob_id),
                                      .out_bid         (md_mul_issue_read_reg_out_bid)
                                  );



            assign mul_reg_flush             = md_clear;

            assign mul_reg_in_valid          = md_mul_issue_read_reg_out_valid && !md_mul_read_clear;
            assign mul_reg_in_phy_reg_dst    = md_mul_issue_read_reg_out_phy_reg_dst;
            assign mul_reg_in_rob_id         = md_mul_issue_read_reg_out_rob_id;
            assign mul_reg_in_mul_op         = md_mul_issue_read_reg_out_mul_op;

            assign mul_reg_operand1          = physical_regfile_rdata9;
            assign mul_reg_operand2          = physical_regfile_rdata10;
            assign mul_reg_in_bid            = md_mul_issue_read_reg_out_bid;

            assign mul_reg_predict_flush     = predict_flush;
            assign mul_reg_head_bid          = predict_flush_bid;
            assign mul_reg_predict_flush_bid = branch_id_allocator_bid_head;

            mul_reg u_mul_reg (
                        .clk   (clk),
                        .resetn(resetn),

                        .flush(mul_reg_flush),

                        .in_valid      (mul_reg_in_valid),
                        .in_phy_reg_dst(mul_reg_in_phy_reg_dst),
                        .in_rob_id     (mul_reg_in_rob_id),
                        .in_mul_op     (mul_reg_in_mul_op),
                        .in_bid        (mul_reg_in_bid),

                        .operand1(mul_reg_operand1),
                        .operand2(mul_reg_operand2),

                        .out_valid      (mul_reg_out_valid),
                        .out_phy_reg_dst(mul_reg_out_phy_reg_dst),
                        .out_rob_id     (mul_reg_out_rob_id),
                        .out_mul_op     (mul_reg_out_mul_op),
                        .out_bid        (mul_reg_out_bid),

                        .out_result(mul_reg_out_result),

                        .predict_flush    (mul_reg_predict_flush),
                        .predict_flush_bid(mul_reg_head_bid),
                        .head_bid         (mul_reg_predict_flush_bid)
                    );





            assign md_bru_issue_read_reg_pre_stall        = md_issue_queue_bru_stall;
            assign md_bru_issue_read_reg_in_valid         = md_issue_queue_bru_issue_valid && !md_issue_clear;
            assign md_bru_issue_read_reg_in_phy_reg_src1  = md_issue_queue_bru_issue_psrc0;
            assign md_bru_issue_read_reg_in_phy_reg_src2  = md_issue_queue_bru_issue_psrc1;
            assign md_bru_issue_read_reg_in_phy_reg_dst   = md_issue_queue_bru_issue_pdest;
            assign md_bru_issue_read_reg_in_sel_npc       = md_issue_queue_bru_issue_opcode[11:10];
            assign md_bru_issue_read_reg_in_comparator_op = md_issue_queue_bru_issue_opcode[9:7];
            assign md_bru_issue_read_reg_in_rob_id        = md_issue_queue_bru_issue_rob_id;
            assign md_bru_issue_read_reg_in_bid           = md_issue_queue_bru_issue_bid;


            md_bru_issue_read_reg u_md_bru_issue_read_reg (
                                      .clk   (clk),
                                      .resetn(resetn),

                                      .stall    (md_bru_issue_read_reg_stall),
                                      .pre_stall(md_bru_issue_read_reg_pre_stall),

                                      .in_valid        (md_bru_issue_read_reg_in_valid),
                                      .in_phy_reg_src1 (md_bru_issue_read_reg_in_phy_reg_src1),
                                      .in_phy_reg_src2 (md_bru_issue_read_reg_in_phy_reg_src2),
                                      .in_phy_reg_dst  (md_bru_issue_read_reg_in_phy_reg_dst),
                                      .in_sel_npc      (md_bru_issue_read_reg_in_sel_npc),
                                      .in_comparator_op(md_bru_issue_read_reg_in_comparator_op),
                                      .in_rob_id       (md_bru_issue_read_reg_in_rob_id),
                                      .in_bid          (md_bru_issue_read_reg_in_bid),

                                      .out_valid        (md_bru_issue_read_reg_out_valid),
                                      .out_phy_reg_src1 (md_bru_issue_read_reg_out_phy_reg_src1),
                                      .out_phy_reg_src2 (md_bru_issue_read_reg_out_phy_reg_src2),
                                      .out_phy_reg_dst  (md_bru_issue_read_reg_out_phy_reg_dst),
                                      .out_sel_npc      (md_bru_issue_read_reg_out_sel_npc),
                                      .out_comparator_op(md_bru_issue_read_reg_out_comparator_op),
                                      .out_rob_id       (md_bru_issue_read_reg_out_rob_id),
                                      .out_bid          (md_bru_issue_read_reg_out_bid)
                                  );




            assign md_read_bru_reg_pre_stall                  = md_bru_issue_read_reg_stall;

            assign md_read_bru_reg_in_valid                   = md_bru_issue_read_reg_out_valid && !md_bru_read_clear;
            assign md_read_bru_reg_in_physical_regfile_rdata1 = physical_regfile_rdata11;
            assign md_read_bru_reg_in_physical_regfile_rdata2 = physical_regfile_rdata12;
            assign md_read_bru_reg_in_phy_reg_dst             = md_bru_issue_read_reg_out_phy_reg_dst;
            assign md_read_bru_reg_in_sel_npc                 = md_bru_issue_read_reg_out_sel_npc;
            assign md_read_bru_reg_in_comparator_op           = md_bru_issue_read_reg_out_comparator_op;
            assign md_read_bru_reg_in_rob_id                  = md_bru_issue_read_reg_out_rob_id;
            assign md_read_bru_reg_in_bid                     = md_bru_issue_read_reg_out_bid;


            md_read_bru_reg u_md_read_bru_reg (
                                .clk   (clk),
                                .resetn(resetn),

                                .stall    (md_read_bru_reg_stall),
                                .pre_stall(md_read_bru_reg_pre_stall),

                                .in_valid                  (md_read_bru_reg_in_valid),
                                .in_physical_regfile_rdata1(md_read_bru_reg_in_physical_regfile_rdata1),
                                .in_physical_regfile_rdata2(md_read_bru_reg_in_physical_regfile_rdata2),
                                .in_phy_reg_dst            (md_read_bru_reg_in_phy_reg_dst),
                                .in_sel_npc                (md_read_bru_reg_in_sel_npc),
                                .in_comparator_op          (md_read_bru_reg_in_comparator_op),
                                .in_rob_id                 (md_read_bru_reg_in_rob_id),
                                .in_bid                    (md_read_bru_reg_in_bid),

                                .out_valid                  (md_read_bru_reg_out_valid),
                                .out_physical_regfile_rdata1(md_read_bru_reg_out_physical_regfile_rdata1),
                                .out_physical_regfile_rdata2(md_read_bru_reg_out_physical_regfile_rdata2),
                                .out_phy_reg_dst            (md_read_bru_reg_out_phy_reg_dst),
                                .out_sel_npc                (md_read_bru_reg_out_sel_npc),
                                .out_comparator_op          (md_read_bru_reg_out_comparator_op),
                                .out_rob_id                 (md_read_bru_reg_out_rob_id),
                                .out_bid                    (md_read_bru_reg_out_bid)

                            );
            wire bru_compared_result;

            assign bru_pc                     = branch_id_allocator_lookup_pc;
            assign bru_predict_target_address = branch_id_allocator_lookup_target_address;
            assign bru_imm                    = branch_id_allocator_lookup_imm;
            assign bru_sel_npc                = md_read_bru_reg_out_sel_npc;
            assign bru_comparator_op          = md_read_bru_reg_out_comparator_op;
            assign bru_operand1               = md_read_bru_reg_out_physical_regfile_rdata1;
            assign bru_operand2               = md_read_bru_reg_out_physical_regfile_rdata2;

            bru u_bru (
                    .pc                    (bru_pc),
                    .predict_target_address(bru_predict_target_address),
                    .imm                   (bru_imm),
                    .sel_npc               (bru_sel_npc),
                    .comparator_op         (bru_comparator_op),

                    .operand1(bru_operand1),
                    .operand2(bru_operand2),

                    .correct_target_address(bru_correct_target_address),
                    .writeback_result      (bru_writeback_result),
                    .is_jump               (bru_is_jump),
                    .compared_result(bru_compared_result)
                );



            wire md_bru_writeback_reg_in_compared_result;
            wire md_bru_writeback_reg_out_compared_result;
            wire [31:0] md_bru_writeback_reg_in_pc;
            wire [                1:0] md_bru_writeback_reg_in_sel_npc;
            wire [31:0] md_bru_writeback_reg_out_pc;
            wire [                1:0] md_bru_writeback_reg_out_sel_npc;

            assign md_bru_writeback_reg_in_pc = branch_id_allocator_lookup_pc;
            assign md_bru_writeback_reg_in_sel_npc = md_read_bru_reg_out_sel_npc;
            assign md_bru_writeback_reg_in_compared_result = bru_compared_result;

            assign md_bru_writeback_reg_pre_stall         = md_read_bru_reg_stall;

            assign md_bru_writeback_reg_in_valid          = md_read_bru_reg_out_valid && !md_bru_clear;
            assign md_bru_writeback_reg_in_regfile_we     = md_read_bru_reg_out_sel_npc == `SEL_NPC_JIRL;
            assign md_bru_writeback_reg_in_result         = bru_writeback_result;
            assign md_bru_writeback_reg_in_target_address = bru_correct_target_address;
            assign md_bru_writeback_reg_in_is_jump        = bru_is_jump;
            assign md_bru_writeback_reg_in_phy_reg_dst    = md_read_bru_reg_out_phy_reg_dst;
            assign md_bru_writeback_reg_in_rob_id         = md_read_bru_reg_out_rob_id;
            assign md_bru_writeback_reg_in_bid            = md_read_bru_reg_out_bid;



            md_bru_writeback_reg u_md_bru_writeback_reg (
                                     .clk   (clk),
                                     .resetn(resetn),

                                     .stall    (md_bru_writeback_reg_stall),
                                     .pre_stall(md_bru_writeback_reg_pre_stall),

                                     .in_valid         (md_bru_writeback_reg_in_valid),
                                     .in_pc(md_bru_writeback_reg_in_pc),
                                     .in_sel_npc(md_bru_writeback_reg_in_sel_npc),
                                     .in_regfile_we    (md_bru_writeback_reg_in_regfile_we),
                                     .in_result        (md_bru_writeback_reg_in_result),
                                     .in_target_address(md_bru_writeback_reg_in_target_address),
                                     .in_is_jump       (md_bru_writeback_reg_in_is_jump),
                                     .in_phy_reg_dst   (md_bru_writeback_reg_in_phy_reg_dst),
                                     .in_rob_id        (md_bru_writeback_reg_in_rob_id),
                                     .in_bid           (md_bru_writeback_reg_in_bid),
                                     .in_compared_result(md_bru_writeback_reg_in_compared_result),

                                     .out_valid         (md_bru_writeback_reg_out_valid),
                                     .out_pc(md_bru_writeback_reg_out_pc),
                                     .out_sel_npc(md_bru_writeback_reg_out_sel_npc),
                                     .out_regfile_we    (md_bru_writeback_reg_out_regfile_we),
                                     .out_result        (md_bru_writeback_reg_out_result),
                                     .out_target_address(md_bru_writeback_reg_out_target_address),
                                     .out_is_jump       (md_bru_writeback_reg_out_is_jump),
                                     .out_phy_reg_dst   (md_bru_writeback_reg_out_phy_reg_dst),
                                     .out_rob_id        (md_bru_writeback_reg_out_rob_id),
                                     .out_bid           (md_bru_writeback_reg_out_bid),
                                     .out_compared_result(md_bru_writeback_reg_out_compared_result)
                                 );




            assign fast_issue_queue_flush             = fast_issue_clear;  //

            assign fast_issue_queue_dispatch_opcode[0]  = 1'b0;
            assign fast_issue_queue_dispatch_pdest[0]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0];
            assign fast_issue_queue_dispatch_imm[0]      = rename_dispatch_pipeline_queue_out_extended_imm[0];
            assign fast_issue_queue_dispatch_bid[0]      = rename_dispatch_pipeline_queue_out_bid[0];
            assign fast_issue_queue_dispatch_rob_id[0]   = rob_alloc_rob_id[0];


            assign fast_issue_queue_dispatch_opcode[1]  = 1'b0;
            assign fast_issue_queue_dispatch_pdest[1]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[1];
            assign fast_issue_queue_dispatch_imm[1]      = rename_dispatch_pipeline_queue_out_extended_imm[1];
            assign fast_issue_queue_dispatch_bid[1]      = rename_dispatch_pipeline_queue_out_bid[1];
            assign fast_issue_queue_dispatch_rob_id[1]   = rob_alloc_rob_id[1];

            assign fast_issue_queue_dispatch_opcode[2]  = 1'b0;
            assign fast_issue_queue_dispatch_pdest[2]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[2];
            assign fast_issue_queue_dispatch_imm[2]      = rename_dispatch_pipeline_queue_out_extended_imm[2];
            assign fast_issue_queue_dispatch_bid[2]      = rename_dispatch_pipeline_queue_out_bid[2];
            assign fast_issue_queue_dispatch_rob_id[2]   = rob_alloc_rob_id[2];

            assign fast_issue_queue_dispatch_opcode[3]  = 1'b0;
            assign fast_issue_queue_dispatch_pdest[3]    = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3];
            assign fast_issue_queue_dispatch_imm[3]      = rename_dispatch_pipeline_queue_out_extended_imm[3];
            assign fast_issue_queue_dispatch_bid[3]      = rename_dispatch_pipeline_queue_out_bid[3];
            assign fast_issue_queue_dispatch_rob_id[3]   = rob_alloc_rob_id[3];



            assign fast_issue_queue_predict_flush     = predict_flush;
            assign fast_issue_queue_predict_flush_bid = predict_flush_bid;
            assign fast_issue_queue_head_bid          = branch_id_allocator_bid_head;

            assign fast_issue_queue_extra_issue_ready = !fast_issue_queue_extra_stall && !sel_fast_extra_issue_writeback_reg;  //



            assign fast_issue_queue_issue_ready       = !fast_issue_queue_stall;

            wire fast_issue_queue_issue_fire;
            wire fast_issue_queue_extra_issue_fire;



            fast_issue_queue_lutram_core u_fast_issue_queue (
                                             .clk   (clk),
                                             .resetn(resetn),

                                             .flush(fast_issue_queue_flush),

                                             .bias_valid(dispatch_ctrl_fast_bias_valid),
                                             .dispatch_valid (fast_issue_queue_dispatch_valid),

                                             .dispatch_opcode_0(fast_issue_queue_dispatch_opcode[0]),
                                             .dispatch_pdest_0 (fast_issue_queue_dispatch_pdest[0]),
                                             .dispatch_imm_0   (fast_issue_queue_dispatch_imm[0]),
                                             .dispatch_bid_0   (fast_issue_queue_dispatch_bid[0]),
                                             .dispatch_rob_id_0(fast_issue_queue_dispatch_rob_id[0]),

                                             .dispatch_opcode_1(fast_issue_queue_dispatch_opcode[1]),
                                             .dispatch_pdest_1 (fast_issue_queue_dispatch_pdest[1]),
                                             .dispatch_imm_1   (fast_issue_queue_dispatch_imm[1]),
                                             .dispatch_bid_1   (fast_issue_queue_dispatch_bid[1]),
                                             .dispatch_rob_id_1(fast_issue_queue_dispatch_rob_id[1]),

                                             .dispatch_opcode_2(fast_issue_queue_dispatch_opcode[2]),
                                             .dispatch_pdest_2 (fast_issue_queue_dispatch_pdest[2]),
                                             .dispatch_imm_2   (fast_issue_queue_dispatch_imm[2]),
                                             .dispatch_bid_2   (fast_issue_queue_dispatch_bid[2]),
                                             .dispatch_rob_id_2(fast_issue_queue_dispatch_rob_id[2]),

                                             .dispatch_opcode_3(fast_issue_queue_dispatch_opcode[3]),
                                             .dispatch_pdest_3 (fast_issue_queue_dispatch_pdest[3]),
                                             .dispatch_imm_3   (fast_issue_queue_dispatch_imm[3]),
                                             .dispatch_bid_3   (fast_issue_queue_dispatch_bid[3]),
                                             .dispatch_rob_id_3(fast_issue_queue_dispatch_rob_id[3]),

                                             .issue_valid (fast_issue_queue_issue_valid),
                                             .issue_ready (fast_issue_queue_issue_ready),
                                             .issue_opcode(fast_issue_queue_issue_opcode),
                                             .issue_pdest (fast_issue_queue_issue_pdest),
                                             .issue_imm   (fast_issue_queue_issue_imm),
                                             .issue_bid   (fast_issue_queue_issue_bid),
                                             .issue_rob_id(fast_issue_queue_issue_rob_id),

                                             .extra_issue_valid (fast_issue_queue_extra_issue_valid),
                                             .extra_issue_ready (fast_issue_queue_extra_issue_ready),
                                             .extra_issue_opcode(fast_issue_queue_extra_issue_opcode),
                                             .extra_issue_pdest (fast_issue_queue_extra_issue_pdest),
                                             .extra_issue_imm   (fast_issue_queue_extra_issue_imm),
                                             .extra_issue_bid   (fast_issue_queue_extra_issue_bid),
                                             .extra_issue_rob_id(fast_issue_queue_extra_issue_rob_id),

                                             .full (fast_issue_queue_full),
                                             .empty(fast_issue_queue_empty),
                                             .count(fast_issue_queue_count),
                                             .res_count(fast_issue_queue_res_count),

                                             .predict_flush    (fast_issue_queue_predict_flush),
                                             .predict_flush_bid(fast_issue_queue_predict_flush_bid),
                                             .head_bid         (fast_issue_queue_head_bid)

                                         );






            assign fast_issue_writeback_reg_pre_stall      = fast_issue_queue_stall;

            assign fast_issue_writeback_reg_in_valid       = fast_issue_queue_issue_valid && !fast_issue_clear;
            assign fast_issue_writeback_reg_in_phy_reg_dst = fast_issue_queue_issue_pdest;
            assign fast_issue_writeback_reg_in_result      = fast_issue_queue_issue_imm;
            assign fast_issue_writeback_reg_in_rob_id      = fast_issue_queue_issue_rob_id;
            assign fast_issue_writeback_reg_in_bid         = fast_issue_queue_issue_bid;

            fast_issue_writeback_reg u_fast_issue_writeback_reg (
                                         .clk   (clk),
                                         .resetn(resetn),

                                         .stall    (fast_issue_writeback_reg_stall),
                                         .pre_stall(fast_issue_writeback_reg_pre_stall),

                                         .in_valid      (fast_issue_writeback_reg_in_valid),
                                         .in_phy_reg_dst(fast_issue_writeback_reg_in_phy_reg_dst),
                                         .in_result     (fast_issue_writeback_reg_in_result),
                                         .in_rob_id     (fast_issue_writeback_reg_in_rob_id),
                                         .in_bid        (fast_issue_writeback_reg_in_bid),

                                         .out_valid      (fast_issue_writeback_reg_out_valid),
                                         .out_phy_reg_dst(fast_issue_writeback_reg_out_phy_reg_dst),
                                         .out_result     (fast_issue_writeback_reg_out_result),
                                         .out_rob_id     (fast_issue_writeback_reg_out_rob_id),
                                         .out_bid        (fast_issue_writeback_reg_out_bid)
                                     );

            assign sel_fast_extra_issue_writeback_reg            = md_read_bru_reg_out_valid;

            assign fast_extra_issue_writeback_reg_pre_stall      = fast_issue_queue_extra_stall;

            assign fast_extra_issue_writeback_reg_in_valid       = sel_fast_extra_issue_writeback_reg ? (md_read_bru_reg_out_valid && !md_bru_clear) : (fast_issue_queue_extra_issue_valid && !fast_issue_clear);
            assign fast_extra_issue_writeback_reg_in_phy_reg_dst = sel_fast_extra_issue_writeback_reg ? md_read_bru_reg_out_phy_reg_dst : fast_issue_queue_extra_issue_pdest;
            assign fast_extra_issue_writeback_reg_in_result      = sel_fast_extra_issue_writeback_reg ? bru_writeback_result : fast_issue_queue_extra_issue_imm;
            assign fast_extra_issue_writeback_reg_in_rob_id      = sel_fast_extra_issue_writeback_reg ? md_read_bru_reg_out_rob_id : fast_issue_queue_extra_issue_rob_id;
            assign fast_extra_issue_writeback_reg_in_bid         = sel_fast_extra_issue_writeback_reg ? md_read_bru_reg_out_bid : fast_issue_queue_extra_issue_bid;


            fast_issue_writeback_reg u_fast_extra_issue_writeback_reg (
                                         .clk   (clk),
                                         .resetn(resetn),

                                         .stall    (fast_extra_issue_writeback_reg_stall),
                                         .pre_stall(fast_extra_issue_writeback_reg_pre_stall),

                                         .in_valid      (fast_extra_issue_writeback_reg_in_valid),
                                         .in_phy_reg_dst(fast_extra_issue_writeback_reg_in_phy_reg_dst),
                                         .in_result     (fast_extra_issue_writeback_reg_in_result),
                                         .in_rob_id     (fast_extra_issue_writeback_reg_in_rob_id),
                                         .in_bid        (fast_extra_issue_writeback_reg_in_bid),

                                         .out_valid      (fast_extra_issue_writeback_reg_out_valid),
                                         .out_phy_reg_dst(fast_extra_issue_writeback_reg_out_phy_reg_dst),
                                         .out_result     (fast_extra_issue_writeback_reg_out_result),
                                         .out_rob_id     (fast_extra_issue_writeback_reg_out_rob_id),
                                         .out_bid        (fast_extra_issue_writeback_reg_out_bid)
                                     );



            assign privilege_issue_queue_flush = privilege_issue_clear;

            assign privilege_issue_queue_dispatch_opcode = {
                       rename_dispatch_pipeline_queue_out_csr_addr[0],
                       rename_dispatch_pipeline_queue_out_csr_we[0],
                       rename_dispatch_pipeline_queue_out_csr_re[0],
                       rename_dispatch_pipeline_queue_out_sel_csr_wmask[0],
                       rename_dispatch_pipeline_queue_out_invtlb_op[0],
                       rename_dispatch_pipeline_queue_out_is_inst_tlbsrch[0],
                       rename_dispatch_pipeline_queue_out_is_inst_tlbrd[0],
                       rename_dispatch_pipeline_queue_out_is_inst_tlbwr[0],
                       rename_dispatch_pipeline_queue_out_is_inst_tlbfill[0],
                       rename_dispatch_pipeline_queue_out_is_inst_invtlb[0]
                   };

            assign privilege_issue_queue_dispatch_pdest = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0];
            assign privilege_issue_queue_dispatch_psrc0 = rename_dispatch_pipeline_queue_out_phy_reg_src1[0];
            assign privilege_issue_queue_dispatch_psrc1 = rename_dispatch_pipeline_queue_out_phy_reg_src2[0];

            assign privilege_issue_queue_dispatch_bid = rename_dispatch_pipeline_queue_out_bid[0];
            assign privilege_issue_queue_dispatch_rob_id = rob_alloc_rob_id[0];


            assign privilege_issue_queue_issue_ready = sel_privilege_issue;

            assign privilege_issue_queue_predict_flush = predict_flush;
            assign privilege_issue_queue_predict_flush_bid = predict_flush_bid;
            assign privilege_issue_queue_head_bid = branch_id_allocator_bid_head;


            assign sel_privilege_issue = privilege_issue_queue_issue_valid && privilege_issue_queue_issue_rob_id == rob_commit_rob_id[0];

            privilege_issue_queue u_privilege_issue_queue (
                                      .clk   (clk),
                                      .resetn(resetn),

                                      .flush(privilege_issue_queue_flush),

                                      .dispatch_valid (privilege_issue_queue_dispatch_valid),
                                      .dispatch_ready (privilege_issue_queue_dispatch_ready),
                                      .dispatch_opcode(privilege_issue_queue_dispatch_opcode),
                                      .dispatch_pdest (privilege_issue_queue_dispatch_pdest),
                                      .dispatch_psrc0 (privilege_issue_queue_dispatch_psrc0),
                                      .dispatch_psrc1 (privilege_issue_queue_dispatch_psrc1),
                                      .dispatch_bid   (privilege_issue_queue_dispatch_bid),
                                      .dispatch_rob_id(privilege_issue_queue_dispatch_rob_id),

                                      .issue_valid (privilege_issue_queue_issue_valid),
                                      .issue_ready (privilege_issue_queue_issue_ready),
                                      .issue_opcode(privilege_issue_queue_issue_opcode),
                                      .issue_pdest (privilege_issue_queue_issue_pdest),
                                      .issue_psrc0 (privilege_issue_queue_issue_psrc0),
                                      .issue_psrc1 (privilege_issue_queue_issue_psrc1),
                                      .issue_bid   (privilege_issue_queue_issue_bid),
                                      .issue_rob_id(privilege_issue_queue_issue_rob_id),

                                      .full (privilege_issue_queue_full),
                                      .empty(privilege_issue_queue_empty),
                                      .count(privilege_issue_queue_count),

                                      .predict_flush    (privilege_issue_queue_predict_flush),
                                      .predict_flush_bid(privilege_issue_queue_predict_flush_bid),
                                      .head_bid         (privilege_issue_queue_head_bid)
                                  );




            assign {
                    privilege_issue_read_reg_in_csr_addr,
                    privilege_issue_read_reg_in_csr_we,
                    privilege_issue_read_reg_in_csr_re,
                    privilege_issue_read_reg_in_sel_csr_wmask,
                    privilege_issue_read_reg_in_invtlb_op,
                    privilege_issue_read_reg_in_is_inst_tlbsrch,
                    privilege_issue_read_reg_in_is_inst_tlbrd,
                    privilege_issue_read_reg_in_is_inst_tlbwr,
                    privilege_issue_read_reg_in_is_inst_tlbfill,
                    privilege_issue_read_reg_in_is_inst_invtlb
                }= privilege_issue_queue_issue_opcode & {`PRIVILEGE_ISSUE_QUEUE_OP_WIDTH{sel_privilege_issue}} ;



            privilege_issue_read_reg u_privilege_issue_read_reg (
                                         .clk   (clk),
                                         .resetn(resetn),
                                         .stall (extra_issue_read_reg_stall),

                                         .in_csr_addr     (privilege_issue_read_reg_in_csr_addr),
                                         .in_csr_we       (privilege_issue_read_reg_in_csr_we),
                                         .in_csr_re       (privilege_issue_read_reg_in_csr_re),
                                         .in_sel_csr_wmask(privilege_issue_read_reg_in_sel_csr_wmask),

                                         .in_invtlb_op      (privilege_issue_read_reg_in_invtlb_op),
                                         .in_is_inst_tlbsrch(privilege_issue_read_reg_in_is_inst_tlbsrch),
                                         .in_is_inst_tlbrd  (privilege_issue_read_reg_in_is_inst_tlbrd),
                                         .in_is_inst_tlbwr  (privilege_issue_read_reg_in_is_inst_tlbwr),
                                         .in_is_inst_tlbfill(privilege_issue_read_reg_in_is_inst_tlbfill),
                                         .in_is_inst_invtlb (privilege_issue_read_reg_in_is_inst_invtlb),

                                         .out_csr_addr     (privilege_issue_read_reg_out_csr_addr),
                                         .out_csr_we       (privilege_issue_read_reg_out_csr_we),
                                         .out_csr_re       (privilege_issue_read_reg_out_csr_re),
                                         .out_sel_csr_wmask(privilege_issue_read_reg_out_sel_csr_wmask),

                                         .out_invtlb_op      (privilege_issue_read_reg_out_invtlb_op),
                                         .out_is_inst_tlbsrch(privilege_issue_read_reg_out_is_inst_tlbsrch),
                                         .out_is_inst_tlbrd  (privilege_issue_read_reg_out_is_inst_tlbrd),
                                         .out_is_inst_tlbwr  (privilege_issue_read_reg_out_is_inst_tlbwr),
                                         .out_is_inst_tlbfill(privilege_issue_read_reg_out_is_inst_tlbfill),
                                         .out_is_inst_invtlb (privilege_issue_read_reg_out_is_inst_invtlb)
                                     );





            assign privilege_read_exec_reg_in_csr_addr        = privilege_issue_read_reg_out_csr_addr;
            assign privilege_read_exec_reg_in_csr_we          = privilege_issue_read_reg_out_csr_we;
            assign privilege_read_exec_reg_in_csr_re          = privilege_issue_read_reg_out_csr_re;
            assign privilege_read_exec_reg_in_sel_csr_wmask   = privilege_issue_read_reg_out_sel_csr_wmask;
            assign privilege_read_exec_reg_in_csr_rdata       = csr_regfile_rdata;

            assign privilege_read_exec_reg_in_invtlb_op       = privilege_issue_read_reg_out_invtlb_op;
            assign privilege_read_exec_reg_in_is_inst_tlbsrch = privilege_issue_read_reg_out_is_inst_tlbsrch;
            assign privilege_read_exec_reg_in_is_inst_tlbrd   = privilege_issue_read_reg_out_is_inst_tlbrd;
            assign privilege_read_exec_reg_in_is_inst_tlbwr   = privilege_issue_read_reg_out_is_inst_tlbwr;
            assign privilege_read_exec_reg_in_is_inst_tlbfill = privilege_issue_read_reg_out_is_inst_tlbfill;
            assign privilege_read_exec_reg_in_is_inst_invtlb  = privilege_issue_read_reg_out_is_inst_invtlb;





            assign privilege_read_exec_reg_in_tlbsrch_hit       = mmu_tlbsrch_hit;
            assign privilege_read_exec_reg_in_tlbrd_hit         = mmu_tlbrd_hit;
            assign privilege_read_exec_reg_in_tlb_w_csr_tlbelo0 = tlb_w_csr_tlbelo0;
            assign privilege_read_exec_reg_in_tlb_w_csr_tlbelo1 = tlb_w_csr_tlbelo1;
            assign privilege_read_exec_reg_in_tlb_w_csr_tlbidx  = tlb_w_csr_tlbidx;
            assign privilege_read_exec_reg_in_tlb_w_csr_tlbehi  = tlb_w_csr_tlbehi;
            assign privilege_read_exec_reg_in_tlb_w_csr_asid    = tlb_w_csr_asid;

            privilege_read_exec_reg u_privilege_read_exec_reg (
                                        .clk   (clk),
                                        .resetn(resetn),
                                        .stall (extra_read_exec_reg_stall),

                                        .in_csr_addr     (privilege_read_exec_reg_in_csr_addr),
                                        .in_csr_we       (privilege_read_exec_reg_in_csr_we),
                                        .in_csr_re       (privilege_read_exec_reg_in_csr_re),
                                        .in_sel_csr_wmask(privilege_read_exec_reg_in_sel_csr_wmask),
                                        .in_csr_rdata    (csr_regfile_rdata),

                                        .in_invtlb_op      (privilege_read_exec_reg_in_invtlb_op),
                                        .in_is_inst_tlbsrch(privilege_read_exec_reg_in_is_inst_tlbsrch),
                                        .in_is_inst_tlbrd  (privilege_read_exec_reg_in_is_inst_tlbrd),
                                        .in_is_inst_tlbwr  (privilege_read_exec_reg_in_is_inst_tlbwr),
                                        .in_is_inst_tlbfill(privilege_read_exec_reg_in_is_inst_tlbfill),
                                        .in_is_inst_invtlb (privilege_read_exec_reg_in_is_inst_invtlb),

                                        .in_tlbsrch_hit      (privilege_read_exec_reg_in_tlbsrch_hit),
                                        .in_tlbrd_hit        (privilege_read_exec_reg_in_tlbrd_hit),
                                        .in_tlb_w_csr_tlbelo0(privilege_read_exec_reg_in_tlb_w_csr_tlbelo0),
                                        .in_tlb_w_csr_tlbelo1(privilege_read_exec_reg_in_tlb_w_csr_tlbelo1),
                                        .in_tlb_w_csr_tlbidx (privilege_read_exec_reg_in_tlb_w_csr_tlbidx),
                                        .in_tlb_w_csr_tlbehi (privilege_read_exec_reg_in_tlb_w_csr_tlbehi),
                                        .in_tlb_w_csr_asid   (privilege_read_exec_reg_in_tlb_w_csr_asid),


                                        .out_csr_addr     (privilege_read_exec_reg_out_csr_addr),
                                        .out_csr_we       (privilege_read_exec_reg_out_csr_we),
                                        .out_csr_re       (privilege_read_exec_reg_out_csr_re),
                                        .out_sel_csr_wmask(privilege_read_exec_reg_out_sel_csr_wmask),
                                        .out_csr_rdata    (privilege_read_exec_reg_out_csr_rdata),

                                        .out_invtlb_op      (privilege_read_exec_reg_out_invtlb_op),
                                        .out_is_inst_tlbsrch(privilege_read_exec_reg_out_is_inst_tlbsrch),
                                        .out_is_inst_tlbrd  (privilege_read_exec_reg_out_is_inst_tlbrd),
                                        .out_is_inst_tlbwr  (privilege_read_exec_reg_out_is_inst_tlbwr),
                                        .out_is_inst_tlbfill(privilege_read_exec_reg_out_is_inst_tlbfill),
                                        .out_is_inst_invtlb (privilege_read_exec_reg_out_is_inst_invtlb),

                                        .out_tlbsrch_hit      (privilege_read_exec_reg_out_tlbsrch_hit),
                                        .out_tlbrd_hit        (privilege_read_exec_reg_out_tlbrd_hit),
                                        .out_tlb_w_csr_tlbelo0(privilege_read_exec_reg_out_tlb_w_csr_tlbelo0),
                                        .out_tlb_w_csr_tlbelo1(privilege_read_exec_reg_out_tlb_w_csr_tlbelo1),
                                        .out_tlb_w_csr_tlbidx (privilege_read_exec_reg_out_tlb_w_csr_tlbidx),
                                        .out_tlb_w_csr_tlbehi (privilege_read_exec_reg_out_tlb_w_csr_tlbehi),
                                        .out_tlb_w_csr_asid   (privilege_read_exec_reg_out_tlb_w_csr_asid)
                                    );


            assign privilege_exec_writeback_reg_in_csr_addr                = privilege_read_exec_reg_out_csr_addr;
            assign privilege_exec_writeback_reg_in_csr_we                  = privilege_read_exec_reg_out_csr_we;
            assign privilege_exec_writeback_reg_in_csr_re                  = privilege_read_exec_reg_out_csr_re;
            assign privilege_exec_writeback_reg_in_sel_csr_wmask           = privilege_read_exec_reg_out_sel_csr_wmask;
            assign privilege_exec_writeback_reg_in_csr_rdata               = privilege_read_exec_reg_out_csr_rdata;

            assign privilege_exec_writeback_reg_in_invtlb_op               = privilege_read_exec_reg_out_invtlb_op;
            assign privilege_exec_writeback_reg_in_is_inst_tlbsrch         = privilege_read_exec_reg_out_is_inst_tlbsrch;
            assign privilege_exec_writeback_reg_in_is_inst_tlbrd           = privilege_read_exec_reg_out_is_inst_tlbrd;
            assign privilege_exec_writeback_reg_in_is_inst_tlbwr           = privilege_read_exec_reg_out_is_inst_tlbwr;
            assign privilege_exec_writeback_reg_in_is_inst_tlbfill         = privilege_read_exec_reg_out_is_inst_tlbfill;
            assign privilege_exec_writeback_reg_in_is_inst_invtlb          = privilege_read_exec_reg_out_is_inst_invtlb;

            assign privilege_exec_writeback_reg_in_physical_regfile_rdata1 = extra_read_exec_reg_out_physical_regfile_rdata1;
            assign privilege_exec_writeback_reg_in_physical_regfile_rdata2 = extra_read_exec_reg_out_physical_regfile_rdata2;





            assign privilege_exec_writeback_reg_in_tlbsrch_hit       = privilege_read_exec_reg_out_tlbsrch_hit;
            assign privilege_exec_writeback_reg_in_tlbrd_hit         = privilege_read_exec_reg_out_tlbrd_hit;
            assign privilege_exec_writeback_reg_in_tlb_w_csr_tlbelo0 = privilege_read_exec_reg_out_tlb_w_csr_tlbelo0;
            assign privilege_exec_writeback_reg_in_tlb_w_csr_tlbelo1 = privilege_read_exec_reg_out_tlb_w_csr_tlbelo1;
            assign privilege_exec_writeback_reg_in_tlb_w_csr_tlbidx  = privilege_read_exec_reg_out_tlb_w_csr_tlbidx;
            assign privilege_exec_writeback_reg_in_tlb_w_csr_tlbehi  = privilege_read_exec_reg_out_tlb_w_csr_tlbehi;
            assign privilege_exec_writeback_reg_in_tlb_w_csr_asid    = privilege_read_exec_reg_out_tlb_w_csr_asid;




            privilege_exec_writeback_reg u_privilege_exec_writeback_reg (
                                             .clk   (clk),
                                             .resetn(resetn),
                                             .stall (extra_exec_writeback_reg_stall),

                                             .in_csr_addr     (privilege_exec_writeback_reg_in_csr_addr),
                                             .in_csr_we       (privilege_exec_writeback_reg_in_csr_we),
                                             .in_csr_re       (privilege_exec_writeback_reg_in_csr_re),
                                             .in_sel_csr_wmask(privilege_exec_writeback_reg_in_sel_csr_wmask),
                                             .in_csr_rdata    (privilege_exec_writeback_reg_in_csr_rdata),

                                             .in_invtlb_op      (privilege_exec_writeback_reg_in_invtlb_op),
                                             .in_is_inst_tlbsrch(privilege_exec_writeback_reg_in_is_inst_tlbsrch),
                                             .in_is_inst_tlbrd  (privilege_exec_writeback_reg_in_is_inst_tlbrd),
                                             .in_is_inst_tlbwr  (privilege_exec_writeback_reg_in_is_inst_tlbwr),
                                             .in_is_inst_tlbfill(privilege_exec_writeback_reg_in_is_inst_tlbfill),
                                             .in_is_inst_invtlb (privilege_exec_writeback_reg_in_is_inst_invtlb),


                                             .in_tlbsrch_hit      (privilege_exec_writeback_reg_in_tlbsrch_hit),
                                             .in_tlbrd_hit        (privilege_exec_writeback_reg_in_tlbrd_hit),
                                             .in_tlb_w_csr_tlbelo0(privilege_exec_writeback_reg_in_tlb_w_csr_tlbelo0),
                                             .in_tlb_w_csr_tlbelo1(privilege_exec_writeback_reg_in_tlb_w_csr_tlbelo1),
                                             .in_tlb_w_csr_tlbidx (privilege_exec_writeback_reg_in_tlb_w_csr_tlbidx),
                                             .in_tlb_w_csr_tlbehi (privilege_exec_writeback_reg_in_tlb_w_csr_tlbehi),
                                             .in_tlb_w_csr_asid   (privilege_exec_writeback_reg_in_tlb_w_csr_asid),


                                             .in_physical_regfile_rdata1(privilege_exec_writeback_reg_in_physical_regfile_rdata1),
                                             .in_physical_regfile_rdata2(privilege_exec_writeback_reg_in_physical_regfile_rdata2),

                                             .out_csr_addr     (privilege_exec_writeback_reg_out_csr_addr),
                                             .out_csr_we       (privilege_exec_writeback_reg_out_csr_we),
                                             .out_csr_re       (privilege_exec_writeback_reg_out_csr_re),
                                             .out_sel_csr_wmask(privilege_exec_writeback_reg_out_sel_csr_wmask),
                                             .out_csr_rdata    (privilege_exec_writeback_reg_out_csr_rdata),

                                             .out_invtlb_op      (privilege_exec_writeback_reg_out_invtlb_op),
                                             .out_is_inst_tlbsrch(privilege_exec_writeback_reg_out_is_inst_tlbsrch),
                                             .out_is_inst_tlbrd  (privilege_exec_writeback_reg_out_is_inst_tlbrd),
                                             .out_is_inst_tlbwr  (privilege_exec_writeback_reg_out_is_inst_tlbwr),
                                             .out_is_inst_tlbfill(privilege_exec_writeback_reg_out_is_inst_tlbfill),
                                             .out_is_inst_invtlb (privilege_exec_writeback_reg_out_is_inst_invtlb),

                                             .out_physical_regfile_rdata1(privilege_exec_writeback_reg_out_physical_regfile_rdata1),
                                             .out_physical_regfile_rdata2(privilege_exec_writeback_reg_out_physical_regfile_rdata2),

                                             .out_tlbsrch_hit      (privilege_exec_writeback_reg_out_tlbsrch_hit),
                                             .out_tlbrd_hit        (privilege_exec_writeback_reg_out_tlbrd_hit),
                                             .out_tlb_w_csr_tlbelo0(privilege_exec_writeback_reg_out_tlb_w_csr_tlbelo0),
                                             .out_tlb_w_csr_tlbelo1(privilege_exec_writeback_reg_out_tlb_w_csr_tlbelo1),
                                             .out_tlb_w_csr_tlbidx (privilege_exec_writeback_reg_out_tlb_w_csr_tlbidx),
                                             .out_tlb_w_csr_tlbehi (privilege_exec_writeback_reg_out_tlb_w_csr_tlbehi),
                                             .out_tlb_w_csr_asid   (privilege_exec_writeback_reg_out_tlb_w_csr_asid)
                                         );






            assign bypass1_valid            = exec_writeback_reg_out_valid && exec_writeback_reg_out_regfile_we;
            assign bypass1_dst              = exec_writeback_reg_out_phy_reg_dst;
            assign bypass1_data = physical_regfile_wdata1;

            assign bypass2_valid            = lsu_mem2_writeback_reg_out_valid && !lsu_mem2_writeback_reg_out_is_store_or_not_load && !lsu_mem2_writeback_reg_out_is_cacop && !lsu_mem2_writeback_reg_out_is_dbar;
            assign bypass2_dst              = lsu_mem2_writeback_reg_out_phy_reg_dst;
            assign bypass2_data = physical_regfile_wdata2;

            assign bypass3_valid            = mul_reg_out_valid;
            assign bypass3_dst              = mul_reg_out_phy_reg_dst;
            assign bypass3_data = physical_regfile_wdata3;

            assign bypass4_valid            = div_reg_out_valid;
            assign bypass4_dst              = div_reg_out_phy_reg_dst;
            assign bypass4_data = physical_regfile_wdata4;

            assign bypass5_valid            = fast_issue_writeback_reg_out_valid;
            assign bypass5_dst              = fast_issue_writeback_reg_out_phy_reg_dst;
            assign bypass5_data = physical_regfile_wdata5;

            assign bypass6_valid            = fast_extra_issue_writeback_reg_out_valid;
            assign bypass6_dst              = fast_extra_issue_writeback_reg_out_phy_reg_dst;
            assign bypass6_data = physical_regfile_wdata6;

            assign bypass7_valid            = extra_exec_writeback_reg_out_valid && extra_exec_writeback_reg_out_regfile_we;
            assign bypass7_dst              = extra_exec_writeback_reg_out_phy_reg_dst;
            assign bypass7_data = physical_regfile_wdata7;





            assign physical_regfile_raddr1  = issue_read_reg_out_phy_reg_src1;
            assign physical_regfile_raddr2  = issue_read_reg_out_phy_reg_src2;

            assign physical_regfile_waddr1  = bypass1_dst;
            assign physical_regfile_we1     = bypass1_valid;
            assign physical_regfile_wdata1  = exec_writeback_reg_out_result;


            assign physical_regfile_raddr3  = lsu_issue_read_reg_out_phy_reg_src1;
            assign physical_regfile_raddr4  = lsu_issue_read_reg_out_phy_reg_src2;

            assign physical_regfile_waddr2  = bypass2_dst;
            assign physical_regfile_we2     = bypass2_valid;
            assign physical_regfile_wdata2  = lsu_mem2_writeback_reg_out_result;

            assign physical_regfile_raddr5  = md_div_issue_read_reg_out_phy_reg_src1;
            assign physical_regfile_raddr6  = md_div_issue_read_reg_out_phy_reg_src2;

            assign physical_regfile_waddr3  = bypass3_dst;
            assign physical_regfile_we3     = bypass3_valid;
            assign physical_regfile_wdata3  = mul_reg_out_result;

            assign physical_regfile_waddr4  = bypass4_dst;
            assign physical_regfile_we4     = bypass4_valid;
            assign physical_regfile_wdata4  = div_reg_out_result;

            assign physical_regfile_waddr5  = bypass5_dst;
            assign physical_regfile_we5     = bypass5_valid;
            assign physical_regfile_wdata5  = fast_issue_writeback_reg_out_result;

            assign physical_regfile_waddr6  = bypass6_dst;
            assign physical_regfile_we6     = bypass6_valid;
            assign physical_regfile_wdata6  = fast_extra_issue_writeback_reg_out_result;

            assign physical_regfile_raddr7  = extra_issue_read_reg_out_phy_reg_src1;
            assign physical_regfile_raddr8  = extra_issue_read_reg_out_phy_reg_src2;

            assign physical_regfile_waddr7  = bypass7_dst;
            assign physical_regfile_we7     = bypass7_valid;
            assign physical_regfile_wdata7  = extra_exec_writeback_reg_out_result;

            assign physical_regfile_raddr9  = md_mul_issue_read_reg_out_phy_reg_src1;
            assign physical_regfile_raddr10 = md_mul_issue_read_reg_out_phy_reg_src2;

            assign physical_regfile_raddr11 = md_bru_issue_read_reg_out_phy_reg_src1;
            assign physical_regfile_raddr12 = md_bru_issue_read_reg_out_phy_reg_src2;


            physical_regfile u_physical_regfile (
                                 .clk   (clk),
                                 .resetn(resetn),

                                 .raddr1(physical_regfile_raddr1),
                                 .raddr2(physical_regfile_raddr2),

                                 .raddr3(physical_regfile_raddr3),
                                 .raddr4(physical_regfile_raddr4),

                                 .raddr5(physical_regfile_raddr5),
                                 .raddr6(physical_regfile_raddr6),

                                 .raddr7(physical_regfile_raddr7),
                                 .raddr8(physical_regfile_raddr8),

                                 .raddr9 (physical_regfile_raddr9),
                                 .raddr10(physical_regfile_raddr10),

                                 .raddr11(physical_regfile_raddr11),
                                 .raddr12(physical_regfile_raddr12),

                                 .waddr1(physical_regfile_waddr1),
                                 .we1   (physical_regfile_we1),
                                 .wdata1(physical_regfile_wdata1),

                                 .waddr2(physical_regfile_waddr2),
                                 .we2   (physical_regfile_we2),
                                 .wdata2(physical_regfile_wdata2),

                                 .waddr3(physical_regfile_waddr3),
                                 .we3   (physical_regfile_we3),
                                 .wdata3(physical_regfile_wdata3),

                                 .waddr4(physical_regfile_waddr4),
                                 .we4   (physical_regfile_we4),
                                 .wdata4(physical_regfile_wdata4),

                                 .waddr5(physical_regfile_waddr5),
                                 .we5   (physical_regfile_we5),
                                 .wdata5(physical_regfile_wdata5),

                                 .waddr6(physical_regfile_waddr6),
                                 .we6   (physical_regfile_we6),
                                 .wdata6(physical_regfile_wdata6),

                                 .waddr7(physical_regfile_waddr7),
                                 .we7   (physical_regfile_we7),
                                 .wdata7(physical_regfile_wdata7),

                                 .rdata1(physical_regfile_rdata1),
                                 .rdata2(physical_regfile_rdata2),

                                 .rdata3(physical_regfile_rdata3),
                                 .rdata4(physical_regfile_rdata4),

                                 .rdata5(physical_regfile_rdata5),
                                 .rdata6(physical_regfile_rdata6),

                                 .rdata7(physical_regfile_rdata7),
                                 .rdata8(physical_regfile_rdata8),

                                 .rdata9 (physical_regfile_rdata9),
                                 .rdata10(physical_regfile_rdata10),

                                 .rdata11(physical_regfile_rdata11),
                                 .rdata12(physical_regfile_rdata12)

`ifdef difftest

                                 , .rmt(rmt)


`endif
                             );

`ifdef difftest



            assign csr_regfile_intrpt = intrpt;

            `elsif perftest_or_linux


                   assign csr_regfile_intrpt = intrpt;


`else


            assign csr_regfile_intrpt = 8'b0;

`endif

            assign csr_regfile_ipi_int           = 1'b0;
            assign csr_regfile_pc                = rob_commit_pc[rob_commit_redirect_lane];
            assign csr_regfile_vaddr             = rob_commit_vaddr[rob_commit_redirect_lane];

            assign csr_regfile_raddr             = privilege_issue_read_reg_out_csr_addr;

            assign csr_regfile_waddr             = privilege_exec_writeback_reg_out_csr_addr;
            assign csr_regfile_we                = privilege_exec_writeback_reg_out_csr_we && extra_exec_writeback_reg_out_valid;
            assign csr_regfile_wdata             = privilege_exec_writeback_reg_out_physical_regfile_rdata2;
            assign csr_regfile_wmask             = privilege_exec_writeback_reg_out_physical_regfile_rdata1 | {32{privilege_exec_writeback_reg_out_sel_csr_wmask}};

            assign csr_regfile_is_exception      = |rob_commit_exception_fire;
            assign csr_regfile_ertn_flush        =
                   |(rob_commit_fire & rob_commit_ertn_flush &
                     ~rob_commit_is_exception);

            assign csr_regfile_is_int            = rob_commit_is_int[rob_commit_redirect_lane];
            assign csr_regfile_is_sys            = rob_commit_is_sys[rob_commit_redirect_lane];
            assign csr_regfile_is_adef           = rob_commit_is_adef[rob_commit_redirect_lane];
            assign csr_regfile_is_ale            = rob_commit_is_ale[rob_commit_redirect_lane];
            assign csr_regfile_is_brk            = rob_commit_is_brk[rob_commit_redirect_lane];
            assign csr_regfile_is_ine            = rob_commit_is_ine[rob_commit_redirect_lane];

            assign csr_regfile_is_tlbr           = rob_commit_is_tlbr[rob_commit_redirect_lane];
            assign csr_regfile_is_inst_tlbr      = rob_commit_is_inst_tlbr[rob_commit_redirect_lane];
            assign csr_regfile_is_inst_pif       = rob_commit_is_inst_pif[rob_commit_redirect_lane];
            assign csr_regfile_is_inst_ppi       = rob_commit_is_inst_ppi[rob_commit_redirect_lane];
            assign csr_regfile_is_data_tlbr      = rob_commit_is_data_tlbr[rob_commit_redirect_lane];
            assign csr_regfile_is_data_pil       = rob_commit_is_data_pil[rob_commit_redirect_lane];
            assign csr_regfile_is_data_pis       = rob_commit_is_data_pis[rob_commit_redirect_lane];
            assign csr_regfile_is_data_ppi       = rob_commit_is_data_ppi[rob_commit_redirect_lane];
            assign csr_regfile_is_data_pme       = rob_commit_is_data_pme[rob_commit_redirect_lane];

            assign csr_regfile_is_tlbsrch        = privilege_exec_writeback_reg_out_is_inst_tlbsrch && extra_exec_writeback_reg_out_valid;
            assign csr_regfile_tlbsrch_hit       = privilege_exec_writeback_reg_out_tlbsrch_hit;
            assign csr_regfile_is_tlbrd          = privilege_exec_writeback_reg_out_is_inst_tlbrd && extra_exec_writeback_reg_out_valid;
            assign csr_regfile_tlbrd_hit         = privilege_exec_writeback_reg_out_tlbrd_hit;
            assign csr_regfile_tlb_w_csr_tlbelo0 = privilege_exec_writeback_reg_out_tlb_w_csr_tlbelo0;
            assign csr_regfile_tlb_w_csr_tlbelo1 = privilege_exec_writeback_reg_out_tlb_w_csr_tlbelo1;
            assign csr_regfile_tlb_w_csr_tlbidx  = privilege_exec_writeback_reg_out_tlb_w_csr_tlbidx;
            assign csr_regfile_tlb_w_csr_tlbehi  = privilege_exec_writeback_reg_out_tlb_w_csr_tlbehi;
            assign csr_regfile_tlb_w_csr_asid    = privilege_exec_writeback_reg_out_tlb_w_csr_asid;

            assign csr_regfile_is_ll_w           = lsu_mem2_writeback_reg_out_valid && !lsu_mem2_writeback_state_out_is_exception && lsu_mem2_writeback_reg_out_is_ll_w;
            assign csr_regfile_is_sc_w           = lsu_mem2_writeback_reg_out_valid && !lsu_mem2_writeback_state_out_is_exception && lsu_mem2_writeback_reg_out_is_sc_w;


            csr_regfile u_csr_regfile (
                            .clk   (clk),
                            .resetn(resetn),

                            .intrpt (csr_regfile_intrpt),
                            .ipi_int(csr_regfile_ipi_int),
                            .pc     (csr_regfile_pc),
                            .vaddr  (csr_regfile_vaddr),

                            .raddr(csr_regfile_raddr),
                            .rdata(csr_regfile_rdata),

                            .waddr(csr_regfile_waddr),
                            .we   (csr_regfile_we),
                            .wdata(csr_regfile_wdata),
                            .wmask(csr_regfile_wmask),

                            .is_exception(csr_regfile_is_exception),
                            .ertn_flush  (csr_regfile_ertn_flush),
                            .has_int     (csr_regfile_has_int),
                            .is_int      (csr_regfile_is_int),
                            .is_sys      (csr_regfile_is_sys),

                            .is_adef(csr_regfile_is_adef),
                            .is_ale (csr_regfile_is_ale),
                            .is_brk (csr_regfile_is_brk),
                            .is_ine (csr_regfile_is_ine),

                            .is_tlbr     (csr_regfile_is_tlbr),
                            .is_inst_tlbr(csr_regfile_is_inst_tlbr),
                            .is_inst_pif (csr_regfile_is_inst_pif),
                            .is_inst_ppi (csr_regfile_is_inst_ppi),
                            .is_data_tlbr(csr_regfile_is_data_tlbr),
                            .is_data_pil (csr_regfile_is_data_pil),
                            .is_data_pis (csr_regfile_is_data_pis),
                            .is_data_ppi (csr_regfile_is_data_ppi),
                            .is_data_pme (csr_regfile_is_data_pme),

                            .exception_enter_addr    (csr_regfile_exception_enter_addr),
                            .exception_return_addr   (csr_regfile_exception_return_addr),
                            .exception_tlb_enter_addr(csr_regfile_exception_tlb_enter_addr),

                            .out_csr_crmd   (csr_regfile_out_csr_crmd),
                            .out_csr_dmw0   (csr_regfile_out_csr_dmw0),
                            .out_csr_dmw1   (csr_regfile_out_csr_dmw1),
                            .out_csr_asid   (csr_regfile_out_csr_asid),
                            .out_csr_estat  (csr_regfile_out_csr_estat),
                            .out_csr_tlbidx (csr_regfile_out_csr_tlbidx),
                            .out_csr_tlbehi (csr_regfile_out_csr_tlbehi),
                            .out_csr_tlbelo0(csr_regfile_out_csr_tlbelo0),
                            .out_csr_tlbelo1(csr_regfile_out_csr_tlbelo1),

                            .is_tlbsrch       (csr_regfile_is_tlbsrch),
                            .tlbsrch_hit      (csr_regfile_tlbsrch_hit),
                            .is_tlbrd         (csr_regfile_is_tlbrd),
                            .tlbrd_hit        (csr_regfile_tlbrd_hit),
                            .tlb_w_csr_tlbelo0(csr_regfile_tlb_w_csr_tlbelo0),
                            .tlb_w_csr_tlbelo1(csr_regfile_tlb_w_csr_tlbelo1),
                            .tlb_w_csr_tlbidx (csr_regfile_tlb_w_csr_tlbidx),
                            .tlb_w_csr_tlbehi (csr_regfile_tlb_w_csr_tlbehi),
                            .tlb_w_csr_asid   (csr_regfile_tlb_w_csr_asid),

                            .is_ll_w(csr_regfile_is_ll_w),
                            .is_sc_w(csr_regfile_is_sc_w),

                            .llbit(csr_regfile_llbit)
                        );







            assign mmu_csr_crmd_plv     = csr_regfile_out_csr_crmd[`CSR_CRMD_PLV];
            assign mmu_csr_crmd_da      = csr_regfile_out_csr_crmd[`CSR_CRMD_DA];
            assign mmu_csr_crmd_pg      = csr_regfile_out_csr_crmd[`CSR_CRMD_PG];
            assign mmu_csr_crmd_datf    = csr_regfile_out_csr_crmd[`CSR_CRMD_DATF];
            assign mmu_csr_crmd_datm    = csr_regfile_out_csr_crmd[`CSR_CRMD_DATM];
            assign mmu_csr_dmw0         = csr_regfile_out_csr_dmw0;
            assign mmu_csr_dmw1         = csr_regfile_out_csr_dmw1;
            assign mmu_csr_asid_asid    = csr_regfile_out_csr_asid[`CSR_ASID_ASID];
            assign mmu_csr_estat_ecode  = csr_regfile_out_csr_estat[`CSR_ESTAT_ECODE];
            assign mmu_csr_tlbidx_index = csr_regfile_out_csr_tlbidx[`CSR_TLBIDX_INDEX];
            assign mmu_csr_tlbidx_ps    = csr_regfile_out_csr_tlbidx[`CSR_TLBIDX_PS];
            assign mmu_csr_tlbidx_ne    = csr_regfile_out_csr_tlbidx[`CSR_TLBIDX_NE];
            assign mmu_csr_tlbehi_vppn  = csr_regfile_out_csr_tlbehi[`CSR_TLBEHI_VPPN];
            assign mmu_csr_tlbelo0_v    = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_V];
            assign mmu_csr_tlbelo0_d    = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_D];
            assign mmu_csr_tlbelo0_plv  = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_PLV];
            assign mmu_csr_tlbelo0_mat  = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_MAT];
            assign mmu_csr_tlbelo0_g    = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_G];
            assign mmu_csr_tlbelo0_ppn  = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_PPN];
            assign mmu_csr_tlbelo1_v    = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_V];
            assign mmu_csr_tlbelo1_d    = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_D];
            assign mmu_csr_tlbelo1_plv  = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_PLV];
            assign mmu_csr_tlbelo1_mat  = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_MAT];
            assign mmu_csr_tlbelo1_g    = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_G];
            assign mmu_csr_tlbelo1_ppn  = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_PPN];

            assign mmu_inst_va          = pc_reg_pc;
            assign mmu_data_va          = lsu_exec_address;

            assign mmu_data_mem_type[1] = lsu_read_exec_reg_out_is_store_or_not_load || lsu_read_exec_reg_out_is_sc_w;
            assign mmu_data_mem_type[0] = !lsu_read_exec_reg_out_is_store_or_not_load && !lsu_read_exec_reg_out_is_cacop && !lsu_read_exec_reg_out_is_dbar && !lsu_read_exec_reg_out_is_sc_w
                   || (lsu_read_exec_reg_out_is_cacop && rob_commit_arch_dest[0][4:3] == 2'b10);

            assign mmu_is_tlbsrch       = privilege_issue_read_reg_out_is_inst_tlbsrch;
            assign mmu_is_tlbrd         = privilege_issue_read_reg_out_is_inst_tlbrd;
            assign mmu_is_tlbwr         = privilege_exec_writeback_reg_out_is_inst_tlbwr && extra_exec_writeback_reg_out_valid;
            assign mmu_is_tlbfill       = privilege_exec_writeback_reg_out_is_inst_tlbfill && extra_exec_writeback_reg_out_valid;
            assign mmu_is_invtlb        = privilege_exec_writeback_reg_out_is_inst_invtlb && extra_exec_writeback_reg_out_valid;
            assign mmu_invtlb_op        = privilege_exec_writeback_reg_out_invtlb_op;
            assign mmu_rj               = privilege_exec_writeback_reg_out_physical_regfile_rdata1;
            assign mmu_rk               = privilege_exec_writeback_reg_out_physical_regfile_rdata2;



            assign tlb_w_csr_tlbelo0    = {mmu_out_csr_tlbelo0_ppn, 1'b0, mmu_out_csr_tlbelo0_g, mmu_out_csr_tlbelo0_mat, mmu_out_csr_tlbelo0_plv, mmu_out_csr_tlbelo0_d, mmu_out_csr_tlbelo0_v};

            assign tlb_w_csr_tlbelo1    = {mmu_out_csr_tlbelo1_ppn, 1'b0, mmu_out_csr_tlbelo1_g, mmu_out_csr_tlbelo1_mat, mmu_out_csr_tlbelo1_plv, mmu_out_csr_tlbelo1_d, mmu_out_csr_tlbelo1_v};

            assign tlb_w_csr_tlbidx     = {mmu_out_csr_tlbidx_ne, 1'b0, mmu_out_csr_tlbidx_ps, 20'b0, mmu_out_csr_tlbidx_index};

            assign tlb_w_csr_asid       = {22'b0, mmu_out_csr_asid_asid};

            assign tlb_w_csr_tlbehi     = {mmu_out_csr_tlbehi_vppn, 13'b0};



            mmu u_mmu (
                    .clk   (clk),
                    .resetn(resetn),

                    .csr_crmd_plv   (mmu_csr_crmd_plv),
                    .csr_crmd_da    (mmu_csr_crmd_da),
                    .csr_crmd_pg    (mmu_csr_crmd_pg),
                    .csr_crmd_datf  (mmu_csr_crmd_datf),
                    .csr_crmd_datm  (mmu_csr_crmd_datm),
                    .csr_dmw0       (mmu_csr_dmw0),
                    .csr_dmw1       (mmu_csr_dmw1),
                    .csr_asid_asid  (mmu_csr_asid_asid),
                    .csr_estat_ecode(mmu_csr_estat_ecode),


                    .csr_tlbidx_index(mmu_csr_tlbidx_index),
                    .csr_tlbidx_ps   (mmu_csr_tlbidx_ps),
                    .csr_tlbidx_ne   (mmu_csr_tlbidx_ne),

                    .csr_tlbehi_vppn(mmu_csr_tlbehi_vppn),

                    .csr_tlbelo0_v  (mmu_csr_tlbelo0_v),
                    .csr_tlbelo0_d  (mmu_csr_tlbelo0_d),
                    .csr_tlbelo0_plv(mmu_csr_tlbelo0_plv),
                    .csr_tlbelo0_mat(mmu_csr_tlbelo0_mat),
                    .csr_tlbelo0_g  (mmu_csr_tlbelo0_g),
                    .csr_tlbelo0_ppn(mmu_csr_tlbelo0_ppn),

                    .csr_tlbelo1_v  (mmu_csr_tlbelo1_v),
                    .csr_tlbelo1_d  (mmu_csr_tlbelo1_d),
                    .csr_tlbelo1_plv(mmu_csr_tlbelo1_plv),
                    .csr_tlbelo1_mat(mmu_csr_tlbelo1_mat),
                    .csr_tlbelo1_g  (mmu_csr_tlbelo1_g),
                    .csr_tlbelo1_ppn(mmu_csr_tlbelo1_ppn),

                    .out_csr_tlbelo0_v  (mmu_out_csr_tlbelo0_v),
                    .out_csr_tlbelo0_d  (mmu_out_csr_tlbelo0_d),
                    .out_csr_tlbelo0_plv(mmu_out_csr_tlbelo0_plv),
                    .out_csr_tlbelo0_mat(mmu_out_csr_tlbelo0_mat),
                    .out_csr_tlbelo0_g  (mmu_out_csr_tlbelo0_g),
                    .out_csr_tlbelo0_ppn(mmu_out_csr_tlbelo0_ppn),

                    .out_csr_tlbelo1_v  (mmu_out_csr_tlbelo1_v),
                    .out_csr_tlbelo1_d  (mmu_out_csr_tlbelo1_d),
                    .out_csr_tlbelo1_plv(mmu_out_csr_tlbelo1_plv),
                    .out_csr_tlbelo1_mat(mmu_out_csr_tlbelo1_mat),
                    .out_csr_tlbelo1_g  (mmu_out_csr_tlbelo1_g),
                    .out_csr_tlbelo1_ppn(mmu_out_csr_tlbelo1_ppn),

                    .out_csr_tlbidx_ps  (mmu_out_csr_tlbidx_ps),
                    .out_csr_tlbidx_ne  (mmu_out_csr_tlbidx_ne),
                    .out_csr_tlbehi_vppn(mmu_out_csr_tlbehi_vppn),
                    .out_csr_asid_asid  (mmu_out_csr_asid_asid),

                    .tlbrd_hit(mmu_tlbrd_hit),

                    .inst_va     (mmu_inst_va),
                    .inst_pa     (mmu_inst_pa),
                    .inst_mat    (mmu_inst_mat
                                 ),
                    .inst_ex_tlbr(mmu_inst_ex_tlbr),
                    .inst_ex_pif (mmu_inst_ex_pif),
                    .inst_ex_ppi (mmu_inst_ex_ppi),

                    .data_va      (mmu_data_va),
                    .data_mem_type(mmu_data_mem_type),
                    .data_pa      (mmu_data_pa),
                    .data_mat     (mmu_data_mat),
                    .data_ex_tlbr (mmu_data_ex_tlbr),
                    .data_ex_pil  (mmu_data_ex_pil),
                    .data_ex_pis  (mmu_data_ex_pis),
                    .data_ex_ppi  (mmu_data_ex_ppi),
                    .data_ex_pme  (mmu_data_ex_pme),

                    .is_tlbsrch(mmu_is_tlbsrch),
                    .is_tlbrd  (mmu_is_tlbrd),
                    .is_tlbwr  (mmu_is_tlbwr),
                    .is_tlbfill(mmu_is_tlbfill),
                    .is_invtlb (mmu_is_invtlb),
                    .invtlb_op (mmu_invtlb_op),
                    .rj        (mmu_rj),
                    .rk        (mmu_rk),

                    .tlbsrch_hit         (mmu_tlbsrch_hit),
                    .out_csr_tlbidx_index(mmu_out_csr_tlbidx_index),

                    .tlbfill_index(mmu_tlbfill_index)

                );


















            assign rob_flush = global_flush;

            assign rob_alloc_pc[0] = rename_dispatch_pipeline_queue_out_pc[0];
            assign rob_alloc_pc[1] = rename_dispatch_pipeline_queue_out_pc[1];
            assign rob_alloc_pc[2] = rename_dispatch_pipeline_queue_out_pc[2];
            assign rob_alloc_pc[3] = rename_dispatch_pipeline_queue_out_pc[3];
            assign rob_alloc_instruction[0] = rename_dispatch_pipeline_queue_out_instruction[0];
            assign rob_alloc_instruction[1] = rename_dispatch_pipeline_queue_out_instruction[1];
            assign rob_alloc_instruction[2] = rename_dispatch_pipeline_queue_out_instruction[2];
            assign rob_alloc_instruction[3] = rename_dispatch_pipeline_queue_out_instruction[3];
            assign rob_alloc_arch_dest[0] = rename_dispatch_pipeline_queue_out_is_cacop[0] ? rename_dispatch_pipeline_queue_out_invtlb_op[0] : rename_dispatch_pipeline_queue_out_regfile_waddr[0];
            assign rob_alloc_arch_dest[1] = rename_dispatch_pipeline_queue_out_is_cacop[1] ? rename_dispatch_pipeline_queue_out_invtlb_op[1] : rename_dispatch_pipeline_queue_out_regfile_waddr[1];
            assign rob_alloc_arch_dest[2] = rename_dispatch_pipeline_queue_out_is_cacop[2] ? rename_dispatch_pipeline_queue_out_invtlb_op[2] : rename_dispatch_pipeline_queue_out_regfile_waddr[2];
            assign rob_alloc_arch_dest[3] = rename_dispatch_pipeline_queue_out_is_cacop[3] ? rename_dispatch_pipeline_queue_out_invtlb_op[3] : rename_dispatch_pipeline_queue_out_regfile_waddr[3];
            assign rob_alloc_new_pdest[0] = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[0];
            assign rob_alloc_new_pdest[1] = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[1];
            assign rob_alloc_new_pdest[2] = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[2];
            assign rob_alloc_new_pdest[3] = rename_dispatch_pipeline_queue_out_new_phy_reg_dst[3];
            assign rob_alloc_old_pdest[0] = rename_dispatch_pipeline_queue_out_old_phy_reg_dst[0];
            assign rob_alloc_old_pdest[1] = rename_dispatch_pipeline_queue_out_old_phy_reg_dst[1];
            assign rob_alloc_old_pdest[2] = rename_dispatch_pipeline_queue_out_old_phy_reg_dst[2];
            assign rob_alloc_old_pdest[3] = rename_dispatch_pipeline_queue_out_old_phy_reg_dst[3];
            assign rob_alloc_regfile_we = rename_dispatch_pipeline_queue_out_regfile_we;
            assign rob_alloc_inst_type[0] = rename_dispatch_pipeline_queue_out_sel_issue_queue[0];
            assign rob_alloc_inst_type[1] = rename_dispatch_pipeline_queue_out_sel_issue_queue[1];
            assign rob_alloc_inst_type[2] = rename_dispatch_pipeline_queue_out_sel_issue_queue[2];
            assign rob_alloc_inst_type[3] = rename_dispatch_pipeline_queue_out_sel_issue_queue[3];
            assign rob_alloc_issue_op[0] = {
                       rename_dispatch_pipeline_queue_out_ertn_flush[0], rename_dispatch_pipeline_queue_out_is_sys[0],
                       rename_dispatch_pipeline_queue_out_is_int[0], rename_dispatch_pipeline_queue_out_is_adef[0],
                       rename_dispatch_pipeline_queue_out_is_ine[0], rename_dispatch_pipeline_queue_out_is_brk[0],
                       rename_dispatch_pipeline_queue_out_is_tlbr[0], rename_dispatch_pipeline_queue_out_is_inst_tlbr[0],
                       rename_dispatch_pipeline_queue_out_is_inst_pif[0], rename_dispatch_pipeline_queue_out_is_inst_ppi[0],
                       rename_dispatch_pipeline_queue_out_wb_refetch[0], rename_dispatch_pipeline_queue_out_is_cacop[0]
                   };
            assign rob_alloc_issue_op[1] = {
                       rename_dispatch_pipeline_queue_out_ertn_flush[1], rename_dispatch_pipeline_queue_out_is_sys[1],
                       rename_dispatch_pipeline_queue_out_is_int[1], rename_dispatch_pipeline_queue_out_is_adef[1],
                       rename_dispatch_pipeline_queue_out_is_ine[1], rename_dispatch_pipeline_queue_out_is_brk[1],
                       rename_dispatch_pipeline_queue_out_is_tlbr[1], rename_dispatch_pipeline_queue_out_is_inst_tlbr[1],
                       rename_dispatch_pipeline_queue_out_is_inst_pif[1], rename_dispatch_pipeline_queue_out_is_inst_ppi[1],
                       rename_dispatch_pipeline_queue_out_wb_refetch[1], rename_dispatch_pipeline_queue_out_is_cacop[1]
                   };
            assign rob_alloc_issue_op[2] = {
                       rename_dispatch_pipeline_queue_out_ertn_flush[2], rename_dispatch_pipeline_queue_out_is_sys[2],
                       rename_dispatch_pipeline_queue_out_is_int[2], rename_dispatch_pipeline_queue_out_is_adef[2],
                       rename_dispatch_pipeline_queue_out_is_ine[2], rename_dispatch_pipeline_queue_out_is_brk[2],
                       rename_dispatch_pipeline_queue_out_is_tlbr[2], rename_dispatch_pipeline_queue_out_is_inst_tlbr[2],
                       rename_dispatch_pipeline_queue_out_is_inst_pif[2], rename_dispatch_pipeline_queue_out_is_inst_ppi[2],
                       rename_dispatch_pipeline_queue_out_wb_refetch[2], rename_dispatch_pipeline_queue_out_is_cacop[2]
                   };
            assign rob_alloc_issue_op[3] = {
                       rename_dispatch_pipeline_queue_out_ertn_flush[3], rename_dispatch_pipeline_queue_out_is_sys[3],
                       rename_dispatch_pipeline_queue_out_is_int[3], rename_dispatch_pipeline_queue_out_is_adef[3],
                       rename_dispatch_pipeline_queue_out_is_ine[3], rename_dispatch_pipeline_queue_out_is_brk[3],
                       rename_dispatch_pipeline_queue_out_is_tlbr[3], rename_dispatch_pipeline_queue_out_is_inst_tlbr[3],
                       rename_dispatch_pipeline_queue_out_is_inst_pif[3], rename_dispatch_pipeline_queue_out_is_inst_ppi[3],
                       rename_dispatch_pipeline_queue_out_wb_refetch[3], rename_dispatch_pipeline_queue_out_is_cacop[3]
                   };
            assign rob_alloc_is_exception = rename_dispatch_pipeline_queue_out_is_exception;

            assign rob_alu_complete_valid = exec_writeback_reg_out_valid && !writeback_clear;
            assign rob_alu_complete_rob_id = exec_writeback_reg_out_rob_id;
            assign rob_alu_complete_value = exec_writeback_reg_out_result;

            assign rob_lsu_complete_valid = lsu_mem2_writeback_reg_out_valid && !lsu_writeback_clear && !lsu_mem2_writeback_reg_out_store_ctrl;
            assign rob_lsu_complete_rob_id = lsu_mem2_writeback_reg_out_rob_id;
            assign rob_lsu_complete_value = lsu_mem2_writeback_reg_out_result;
            assign rob_lsu_complete_writeback_op = {
                       lsu_mem2_writeback_state_out_is_ale,
                       lsu_mem2_writeback_state_out_is_tlbr,
                       lsu_mem2_writeback_state_out_is_data_tlbr,
                       lsu_mem2_writeback_state_out_is_data_pil,
                       lsu_mem2_writeback_state_out_is_data_pis,
                       lsu_mem2_writeback_state_out_is_data_ppi,
                       lsu_mem2_writeback_state_out_is_data_pme,
                       lsu_mem2_writeback_reg_out_vaddr
                   };
            assign rob_lsu_complete_exception = lsu_mem2_writeback_state_out_is_exception;


            assign rob_mul_complete_valid = mul_reg_out_valid && !md_clear;
            assign rob_mul_complete_rob_id = mul_reg_out_rob_id;
            assign rob_mul_complete_value = mul_reg_out_result;

            assign rob_div_complete_valid = div_reg_out_valid && !md_clear;
            assign rob_div_complete_rob_id = div_reg_out_rob_id;
            assign rob_div_complete_value = div_reg_out_result;

            assign rob_fast_complete_valid = fast_issue_writeback_reg_out_valid && !fast_writeback_clear;
            assign rob_fast_complete_rob_id = fast_issue_writeback_reg_out_rob_id;
            assign rob_fast_complete_value = fast_issue_writeback_reg_out_result;

            assign rob_fast_extra_complete_valid = fast_extra_issue_writeback_reg_out_valid && !fast_extra_writeback_clear;
            assign rob_fast_extra_complete_rob_id = fast_extra_issue_writeback_reg_out_rob_id;
            assign rob_fast_extra_complete_value = fast_extra_issue_writeback_reg_out_result;

            assign rob_alu_extra_complete_valid = extra_exec_writeback_reg_out_valid && !extra_writeback_clear;
            assign rob_alu_extra_complete_rob_id = extra_exec_writeback_reg_out_rob_id;
            assign rob_alu_extra_complete_value = extra_exec_writeback_reg_out_result;


            // assign rob_commit_ready                                = 1'b0;


            assign rob_alloc_bid[0] = rename_dispatch_pipeline_queue_out_bid[0];
            assign rob_alloc_bid[1] = rename_dispatch_pipeline_queue_out_bid[1];
            assign rob_alloc_bid[2] = rename_dispatch_pipeline_queue_out_bid[2];
            assign rob_alloc_bid[3] = rename_dispatch_pipeline_queue_out_bid[3];

            assign rob_predict_flush_bid = predict_flush_bid;
            assign rob_head_bid = branch_id_allocator_bid_head;



            assign rob_commit_is_tlbr = rob_commit_is_issue_tlbr |
                   rob_commit_is_writeback_tlbr;

            assign {rob_commit_ertn_flush[0], rob_commit_is_sys[0],
                    rob_commit_is_int[0], rob_commit_is_adef[0],
                    rob_commit_is_ine[0], rob_commit_is_brk[0],
                    rob_commit_is_issue_tlbr[0], rob_commit_is_inst_tlbr[0],
                    rob_commit_is_inst_pif[0], rob_commit_is_inst_ppi[0],
                    rob_commit_wb_refetch[0], rob_commit_is_cacop[0]} =
                   rob_commit_issue_op[0];
            assign {rob_commit_ertn_flush[1], rob_commit_is_sys[1],
                    rob_commit_is_int[1], rob_commit_is_adef[1],
                    rob_commit_is_ine[1], rob_commit_is_brk[1],
                    rob_commit_is_issue_tlbr[1], rob_commit_is_inst_tlbr[1],
                    rob_commit_is_inst_pif[1], rob_commit_is_inst_ppi[1],
                    rob_commit_wb_refetch[1], rob_commit_is_cacop[1]} =
                   rob_commit_issue_op[1];
            assign {rob_commit_ertn_flush[2], rob_commit_is_sys[2],
                    rob_commit_is_int[2], rob_commit_is_adef[2],
                    rob_commit_is_ine[2], rob_commit_is_brk[2],
                    rob_commit_is_issue_tlbr[2], rob_commit_is_inst_tlbr[2],
                    rob_commit_is_inst_pif[2], rob_commit_is_inst_ppi[2],
                    rob_commit_wb_refetch[2], rob_commit_is_cacop[2]} =
                   rob_commit_issue_op[2];
            assign {rob_commit_ertn_flush[3], rob_commit_is_sys[3],
                    rob_commit_is_int[3], rob_commit_is_adef[3],
                    rob_commit_is_ine[3], rob_commit_is_brk[3],
                    rob_commit_is_issue_tlbr[3], rob_commit_is_inst_tlbr[3],
                    rob_commit_is_inst_pif[3], rob_commit_is_inst_ppi[3],
                    rob_commit_wb_refetch[3], rob_commit_is_cacop[3]} =
                   rob_commit_issue_op[3];

            assign {rob_commit_is_ale[0], rob_commit_is_writeback_tlbr[0],
                    rob_commit_is_data_tlbr[0], rob_commit_is_data_pil[0],
                    rob_commit_is_data_pis[0], rob_commit_is_data_ppi[0],
                    rob_commit_is_data_pme[0], rob_commit_vaddr[0]} =
                   rob_commit_writeback_op[0];
            assign {rob_commit_is_ale[1], rob_commit_is_writeback_tlbr[1],
                    rob_commit_is_data_tlbr[1], rob_commit_is_data_pil[1],
                    rob_commit_is_data_pis[1], rob_commit_is_data_ppi[1],
                    rob_commit_is_data_pme[1], rob_commit_vaddr[1]} =
                   rob_commit_writeback_op[1];
            assign {rob_commit_is_ale[2], rob_commit_is_writeback_tlbr[2],
                    rob_commit_is_data_tlbr[2], rob_commit_is_data_pil[2],
                    rob_commit_is_data_pis[2], rob_commit_is_data_ppi[2],
                    rob_commit_is_data_pme[2], rob_commit_vaddr[2]} =
                   rob_commit_writeback_op[2];
            assign {rob_commit_is_ale[3], rob_commit_is_writeback_tlbr[3],
                    rob_commit_is_data_tlbr[3], rob_commit_is_data_pil[3],
                    rob_commit_is_data_pis[3], rob_commit_is_data_ppi[3],
                    rob_commit_is_data_pme[3], rob_commit_vaddr[3]} =
                   rob_commit_writeback_op[3];

            assign rob_commit_redirect_fire = rob_commit_fire &
                   (rob_commit_is_exception | rob_commit_ertn_flush |
                    rob_commit_wb_refetch);
            assign rob_commit_exception_fire = rob_commit_fire &
                   rob_commit_is_exception;
            assign rob_commit_redirect_lane = rob_commit_redirect_fire[0] ? 2'd0 :
                   rob_commit_redirect_fire[1] ? 2'd1 :
                   rob_commit_redirect_fire[2] ? 2'd2 :
                   rob_commit_redirect_fire[3] ? 2'd3 : 2'd0;


            rob_bram_4in4out_core #(
                                      .DEPTH(`ROB_DEPTH),
                                      .ID_WIDTH(`ROB_ID_WIDTH),
                                      .COUNT_WIDTH(`ROB_COUNT_WIDTH),
                                      .ARCH_WIDTH(`ROB_ARCH_WIDTH),
                                      .PHY_WIDTH(`ROB_PHY_WIDTH),
                                      .PC_WIDTH(`ROB_PC_WIDTH),
                                      .ISSUE_OP_WIDTH(`ROB_ISSUE_OP_WIDTH),
                                      .WRITEBACK_OP_WIDTH(`ROB_WRITEBACK_OP_WIDTH)
                                  ) u_rob (
                                      .clk   (clk),
                                      .resetn(resetn),
                                      .flush (rob_flush),

                                      .rob_alloc_valid(rob_alloc_valid),
                                      .rob_alloc_ready(rob_alloc_ready),
                                      .rob_alloc_rob_id_0(rob_alloc_rob_id[0]),
                                      .rob_alloc_rob_id_1(rob_alloc_rob_id[1]),
                                      .rob_alloc_rob_id_2(rob_alloc_rob_id[2]),
                                      .rob_alloc_rob_id_3(rob_alloc_rob_id[3]),
                                      .rob_alloc_pc_0(rob_alloc_pc[0]),
                                      .rob_alloc_pc_1(rob_alloc_pc[1]),
                                      .rob_alloc_pc_2(rob_alloc_pc[2]),
                                      .rob_alloc_pc_3(rob_alloc_pc[3]),
                                      .rob_alloc_instruction_0(rob_alloc_instruction[0]),
                                      .rob_alloc_instruction_1(rob_alloc_instruction[1]),
                                      .rob_alloc_instruction_2(rob_alloc_instruction[2]),
                                      .rob_alloc_instruction_3(rob_alloc_instruction[3]),
                                      .rob_alloc_arch_dest_0(rob_alloc_arch_dest[0]),
                                      .rob_alloc_arch_dest_1(rob_alloc_arch_dest[1]),
                                      .rob_alloc_arch_dest_2(rob_alloc_arch_dest[2]),
                                      .rob_alloc_arch_dest_3(rob_alloc_arch_dest[3]),
                                      .rob_alloc_new_pdest_0(rob_alloc_new_pdest[0]),
                                      .rob_alloc_new_pdest_1(rob_alloc_new_pdest[1]),
                                      .rob_alloc_new_pdest_2(rob_alloc_new_pdest[2]),
                                      .rob_alloc_new_pdest_3(rob_alloc_new_pdest[3]),
                                      .rob_alloc_old_pdest_0(rob_alloc_old_pdest[0]),
                                      .rob_alloc_old_pdest_1(rob_alloc_old_pdest[1]),
                                      .rob_alloc_old_pdest_2(rob_alloc_old_pdest[2]),
                                      .rob_alloc_old_pdest_3(rob_alloc_old_pdest[3]),
                                      .rob_alloc_regfile_we(rob_alloc_regfile_we),
                                      .rob_alloc_inst_type_0(rob_alloc_inst_type[0]),
                                      .rob_alloc_inst_type_1(rob_alloc_inst_type[1]),
                                      .rob_alloc_inst_type_2(rob_alloc_inst_type[2]),
                                      .rob_alloc_inst_type_3(rob_alloc_inst_type[3]),
                                      .rob_alloc_issue_op_0(rob_alloc_issue_op[0]),
                                      .rob_alloc_issue_op_1(rob_alloc_issue_op[1]),
                                      .rob_alloc_issue_op_2(rob_alloc_issue_op[2]),
                                      .rob_alloc_issue_op_3(rob_alloc_issue_op[3]),
                                      .rob_alloc_is_exception(rob_alloc_is_exception),

                                      .rob_alu_complete_valid (rob_alu_complete_valid),
                                      .rob_alu_complete_rob_id(rob_alu_complete_rob_id),
                                      .rob_alu_complete_value (rob_alu_complete_value),

                                      .rob_alu_extra_complete_valid (rob_alu_extra_complete_valid),
                                      .rob_alu_extra_complete_rob_id(rob_alu_extra_complete_rob_id),
                                      .rob_alu_extra_complete_value (rob_alu_extra_complete_value),


                                      .rob_lsu_complete_valid       (rob_lsu_complete_valid),
                                      .rob_lsu_complete_rob_id      (rob_lsu_complete_rob_id),
                                      .rob_lsu_complete_value       (rob_lsu_complete_value),
                                      .rob_lsu_complete_writeback_op(rob_lsu_complete_writeback_op),
                                      .rob_lsu_complete_exception   (rob_lsu_complete_exception),

                                      .rob_mul_complete_valid (rob_mul_complete_valid),
                                      .rob_mul_complete_rob_id(rob_mul_complete_rob_id),
                                      .rob_mul_complete_value (rob_mul_complete_value),

                                      .rob_div_complete_valid (rob_div_complete_valid),
                                      .rob_div_complete_rob_id(rob_div_complete_rob_id),
                                      .rob_div_complete_value (rob_div_complete_value),

                                      .rob_fast_complete_valid (rob_fast_complete_valid),
                                      .rob_fast_complete_rob_id(rob_fast_complete_rob_id),
                                      .rob_fast_complete_value (rob_fast_complete_value),

                                      .rob_fast_extra_complete_valid (rob_fast_extra_complete_valid),
                                      .rob_fast_extra_complete_rob_id(rob_fast_extra_complete_rob_id),
                                      .rob_fast_extra_complete_value (rob_fast_extra_complete_value),


                                      .rob_commit_valid(rob_commit_valid),
                                      .rob_commit_ready(rob_commit_ready),
                                      .rob_commit_fire(rob_commit_fire),
                                      .rob_commit_rob_id_0(rob_commit_rob_id[0]),
                                      .rob_commit_rob_id_1(rob_commit_rob_id[1]),
                                      .rob_commit_rob_id_2(rob_commit_rob_id[2]),
                                      .rob_commit_rob_id_3(rob_commit_rob_id[3]),
                                      .rob_commit_pc_0(rob_commit_pc[0]),
                                      .rob_commit_pc_1(rob_commit_pc[1]),
                                      .rob_commit_pc_2(rob_commit_pc[2]),
                                      .rob_commit_pc_3(rob_commit_pc[3]),
                                      .rob_commit_instruction_0(rob_commit_instruction[0]),
                                      .rob_commit_instruction_1(rob_commit_instruction[1]),
                                      .rob_commit_instruction_2(rob_commit_instruction[2]),
                                      .rob_commit_instruction_3(rob_commit_instruction[3]),
                                      .rob_commit_arch_dest_0(rob_commit_arch_dest[0]),
                                      .rob_commit_arch_dest_1(rob_commit_arch_dest[1]),
                                      .rob_commit_arch_dest_2(rob_commit_arch_dest[2]),
                                      .rob_commit_arch_dest_3(rob_commit_arch_dest[3]),
                                      .rob_commit_new_pdest_0(rob_commit_new_pdest[0]),
                                      .rob_commit_new_pdest_1(rob_commit_new_pdest[1]),
                                      .rob_commit_new_pdest_2(rob_commit_new_pdest[2]),
                                      .rob_commit_new_pdest_3(rob_commit_new_pdest[3]),
                                      .rob_commit_old_pdest_0(rob_commit_old_pdest[0]),
                                      .rob_commit_old_pdest_1(rob_commit_old_pdest[1]),
                                      .rob_commit_old_pdest_2(rob_commit_old_pdest[2]),
                                      .rob_commit_old_pdest_3(rob_commit_old_pdest[3]),
                                      .rob_commit_regfile_we(rob_commit_regfile_we),
                                      .rob_commit_value_0(rob_commit_value[0]),
                                      .rob_commit_value_1(rob_commit_value[1]),
                                      .rob_commit_value_2(rob_commit_value[2]),
                                      .rob_commit_value_3(rob_commit_value[3]),
                                      .rob_commit_inst_type_0(rob_commit_inst_type[0]),
                                      .rob_commit_inst_type_1(rob_commit_inst_type[1]),
                                      .rob_commit_inst_type_2(rob_commit_inst_type[2]),
                                      .rob_commit_inst_type_3(rob_commit_inst_type[3]),
                                      .rob_commit_issue_op_0(rob_commit_issue_op[0]),
                                      .rob_commit_issue_op_1(rob_commit_issue_op[1]),
                                      .rob_commit_issue_op_2(rob_commit_issue_op[2]),
                                      .rob_commit_issue_op_3(rob_commit_issue_op[3]),
                                      .rob_commit_writeback_op_0(rob_commit_writeback_op[0]),
                                      .rob_commit_writeback_op_1(rob_commit_writeback_op[1]),
                                      .rob_commit_writeback_op_2(rob_commit_writeback_op[2]),
                                      .rob_commit_writeback_op_3(rob_commit_writeback_op[3]),
                                      .rob_commit_is_exception(rob_commit_is_exception),

                                      .rob_complete_conflict(rob_complete_conflict),
                                      .rob_head             (rob_head),
                                      .rob_full             (rob_full),
                                      .rob_empty            (rob_empty),
                                      .rob_count            (rob_count),
                                      .rob_res_count        (rob_res_count),

                                      .predict_flush       (predict_flush),
                                      .predict_flush_rob_id(predict_flush_rob_id),
                                      .predict_flush_bid   (rob_predict_flush_bid),
                                      .head_bid            (rob_head_bid)
                                  );




            commit_ctrl u_commit_ctrl (
                            .clk   (clk),
                            .resetn(resetn),

                            .rob_commit_valid(rob_commit_valid),
                            .rob_commit_ready(rob_commit_ready),

                            .rob_commit_is_exception(rob_commit_is_exception),
                            .rob_commit_is_tlbr     (rob_commit_is_tlbr),
                            .rob_commit_ertn_flush  (rob_commit_ertn_flush),
                            .rob_commit_wb_refetch  (rob_commit_wb_refetch),

                            .csr_regfile_exception_enter_addr    (csr_regfile_exception_enter_addr),
                            .csr_regfile_exception_return_addr   (csr_regfile_exception_return_addr),
                            .csr_regfile_exception_tlb_enter_addr(csr_regfile_exception_tlb_enter_addr),
                            .rob_commit_pc_0(rob_commit_pc[0]),
                            .rob_commit_pc_1(rob_commit_pc[1]),
                            .rob_commit_pc_2(rob_commit_pc[2]),
                            .rob_commit_pc_3(rob_commit_pc[3]),

                            .rob_commit_inst_type_0(rob_commit_inst_type[0]),
                            .rob_commit_inst_type_1(rob_commit_inst_type[1]),
                            .rob_commit_inst_type_2(rob_commit_inst_type[2]),
                            .rob_commit_inst_type_3(rob_commit_inst_type[3]),

                            .store_queue_uncommitted_count(store_queue_uncommitted_count),
                            .store_queue_drain_valid   (store_queue_drain_valid),
                            .store_queue_drain_mat     (store_queue_drain_mat),
                            .cache_subsystem_dcache_busy(cache_subsystem_dcache_busy),
                            .sel_store_stall            (sel_store_stall),
                            .sel_store_commit           (sel_store_commit),

                            .flush_target_address(flush_target_address),
                            .global_flush        (global_flush),

                            .predict_flush(predict_flush)
                        );

            `ifndef SYNTHESIS
                    always @(posedge clk) begin
                        if (resetn) begin
                            if ((rob_commit_fire[1] && !rob_commit_fire[0]) ||
                                    (rob_commit_fire[2] && !rob_commit_fire[1]) ||
                                    (rob_commit_fire[3] && !rob_commit_fire[2]))
                                $error("ROB commit fire is not an oldest-first prefix");

                            if ((rob_commit_redirect_fire[0] && |rob_commit_fire[3:1]) ||
                                    (rob_commit_redirect_fire[1] && |rob_commit_fire[3:2]) ||
                                    (rob_commit_redirect_fire[2] && rob_commit_fire[3]))
                                $error("younger instruction committed after a redirect");

                            if ((rob_commit_redirect_fire[0] &&
                                    |rob_commit_redirect_fire[3:1]) ||
                                    (rob_commit_redirect_fire[1] &&
                                     |rob_commit_redirect_fire[3:2]) ||
                                    (rob_commit_redirect_fire[2] &&
                                     rob_commit_redirect_fire[3]))
                                $error("multiple redirects committed in one cycle");

                            if ({1'b0, store_queue_commit_count} >
                                    store_queue_uncommitted_count)
                                $error("store commit count exceeds store queue state");
                        end
                    end
`endif

                    assign predict_flush_rob_id = md_bru_writeback_reg_out_rob_id;

            assign predict_flush_bid    = md_bru_writeback_reg_out_bid;


            stall_or_clear_detector u_stall_or_clear_detector (
                                        .pc_reg_out_valid         (pc_reg_out_valid),
                                        .pc_reg_stall             (pc_reg_stall),
                                        .if1_clear                (if1_clear),
                                        .pc_state_out_is_exception(pc_state_out_is_exception),

                                        .if_insfifo_reg_out_valid         (if_insfifo_reg_out_valid),
                                        .if_insfifo_reg_stall             (if_insfifo_reg_stall),
                                        .if2_clear                        (if2_clear),
                                        .if_insfifo_state_out_is_exception(if_insfifo_state_out_is_exception),

                                        .id_clear      (id_clear),
                                        .allocbid_clear(allocbid_clear),
                                        .rename_clear  (rename_clear),
                                        .dispatch_clear(dispatch_clear),

                                        .alu_issue_queue_issue_valid(alu_issue_queue_issue_valid),
                                        .issue_queue_stall          (issue_queue_stall),
                                        .issue_queue_extra_stall    (issue_queue_extra_stall),
                                        .issue_clear                (issue_clear),

                                        .issue_read_reg_out_valid(issue_read_reg_out_valid),
                                        .issue_read_reg_stall    (issue_read_reg_stall),
                                        .read_clear              (read_clear),
                                        .issue_read_reg_out_bid  (issue_read_reg_out_bid),

                                        .read_exec_reg_out_valid(read_exec_reg_out_valid),
                                        .read_exec_reg_stall    (read_exec_reg_stall),
                                        .exec_clear             (exec_clear),
                                        .read_exec_reg_out_bid  (read_exec_reg_out_bid),

                                        .exec_writeback_reg_out_valid(exec_writeback_reg_out_valid),
                                        .exec_writeback_reg_stall    (exec_writeback_reg_stall),
                                        .writeback_clear             (writeback_clear),
                                        .exec_writeback_reg_out_bid  (exec_writeback_reg_out_bid),

                                        .extra_issue_read_reg_out_valid(extra_issue_read_reg_out_valid),
                                        .extra_issue_read_reg_stall    (extra_issue_read_reg_stall),
                                        .extra_read_clear              (extra_read_clear),
                                        .extra_issue_read_reg_out_bid  (extra_issue_read_reg_out_bid),

                                        .extra_read_exec_reg_out_valid(extra_read_exec_reg_out_valid),
                                        .extra_read_exec_reg_stall    (extra_read_exec_reg_stall),
                                        .extra_exec_clear             (extra_exec_clear),
                                        .extra_read_exec_reg_out_bid  (extra_read_exec_reg_out_bid),

                                        .extra_exec_writeback_reg_out_valid(extra_exec_writeback_reg_out_valid),
                                        .extra_exec_writeback_reg_stall    (extra_exec_writeback_reg_stall),
                                        .extra_writeback_clear             (extra_writeback_clear),
                                        .extra_exec_writeback_reg_out_bid  (extra_exec_writeback_reg_out_bid),


                                        .lsu_issue_queue_issue_valid(lsu_issue_queue_issue_valid),
                                        .lsu_issue_queue_stall      (lsu_issue_queue_stall),
                                        .lsu_issue_clear            (lsu_issue_clear),

                                        .lsu_issue_read_reg_out_valid(lsu_issue_read_reg_out_valid),
                                        .lsu_issue_read_reg_stall    (lsu_issue_read_reg_stall),
                                        .lsu_read_clear              (lsu_read_clear),
                                        .lsu_issue_read_reg_out_bid  (lsu_issue_read_reg_out_bid),

                                        .lsu_read_exec_reg_out_valid(lsu_read_exec_reg_out_valid),
                                        .lsu_read_exec_reg_stall    (lsu_read_exec_reg_stall),
                                        .lsu_exec_clear             (lsu_exec_clear),
                                        .lsu_read_exec_reg_out_bid  (lsu_read_exec_reg_out_bid),

                                        .lsu_exec_mem1_reg_out_valid         (lsu_exec_mem1_reg_out_valid),
                                        .lsu_exec_mem1_reg_out_ready         (lsu_mem1_current_fire),
                                        .lsu_exec_mem1_reg_stall             (lsu_exec_mem1_reg_stall),
                                        .lsu_mem1_clear                      (lsu_mem1_clear),
                                        .lsu_exec_mem1_reg_out_bid           (lsu_exec_mem1_reg_out_bid),
                                        .lsu_exec_mem1_reg_out_store_ctrl    (lsu_exec_mem1_reg_out_store_ctrl),
                                        .lsu_exec_mem1_state_out_is_exception(lsu_exec_mem1_state_out_is_exception),


                                        .lsu_mem1_mem2_reg_out_valid         (lsu_mem1_mem2_reg_out_valid),
                                        .lsu_mem1_mem2_reg_stall             (lsu_mem1_mem2_reg_stall),
                                        .lsu_mem2_clear                      (lsu_mem2_clear),
                                        .lsu_mem1_mem2_reg_out_bid           (lsu_mem1_mem2_reg_out_bid),
                                        .lsu_mem1_mem2_reg_out_store_ctrl    (lsu_mem1_mem2_reg_out_store_ctrl),
                                        .lsu_mem1_mem2_state_out_is_exception(lsu_mem1_mem2_state_out_is_exception),

                                        .lsu_mem2_writeback_reg_out_valid         (lsu_mem2_writeback_reg_out_valid),
                                        .lsu_mem2_writeback_reg_stall             (lsu_mem2_writeback_reg_stall),
                                        .lsu_writeback_clear                      (lsu_writeback_clear),
                                        .lsu_mem2_writeback_reg_out_bid           (lsu_mem2_writeback_reg_out_bid),
                                        .lsu_mem2_writeback_state_out_is_exception(lsu_mem2_writeback_state_out_is_exception),

                                        .md_issue_queue_div_issue_valid(md_issue_queue_div_issue_valid),
                                        .md_issue_queue_mul_issue_valid(md_issue_queue_mul_issue_valid),
                                        .md_issue_queue_bru_issue_valid(md_issue_queue_bru_issue_valid),
                                        .md_issue_queue_div_stall      (md_issue_queue_div_stall),
                                        .md_issue_queue_mul_stall      (md_issue_queue_mul_stall),
                                        .md_issue_queue_bru_stall      (md_issue_queue_bru_stall),
                                        .md_issue_clear                (md_issue_clear),

                                        .md_div_issue_read_reg_out_valid(md_div_issue_read_reg_out_valid),
                                        .md_div_issue_read_reg_stall    (md_div_issue_read_reg_stall),
                                        .md_div_read_clear              (md_div_read_clear),
                                        .md_div_issue_read_reg_out_bid  (md_div_issue_read_reg_out_bid),

                                        .md_mul_issue_read_reg_out_valid(md_mul_issue_read_reg_out_valid),
                                        .md_mul_issue_read_reg_stall    (md_mul_issue_read_reg_stall),
                                        .md_mul_read_clear              (md_mul_read_clear),
                                        .md_mul_issue_read_reg_out_bid  (md_mul_issue_read_reg_out_bid),

                                        .md_bru_issue_read_reg_out_valid(md_bru_issue_read_reg_out_valid),
                                        .md_bru_issue_read_reg_stall    (md_bru_issue_read_reg_stall),
                                        .md_bru_read_clear              (md_bru_read_clear),
                                        .md_bru_issue_read_reg_out_bid  (md_bru_issue_read_reg_out_bid),



                                        .mul_reg_out_valid(mul_reg_out_valid),
                                        .div_reg_out_valid(div_reg_out_valid),
                                        .md_reg_stall     (md_reg_stall),
                                        .md_clear         (md_clear),

                                        .md_read_bru_reg_out_valid(md_read_bru_reg_out_valid),
                                        .md_read_bru_reg_stall    (md_read_bru_reg_stall),
                                        .md_bru_clear             (md_bru_clear),
                                        .md_read_bru_reg_out_bid  (md_read_bru_reg_out_bid),

                                        .md_bru_writeback_reg_out_valid(md_bru_writeback_reg_out_valid),
                                        .md_bru_writeback_reg_stall    (md_bru_writeback_reg_stall),
                                        .md_writeback_clear            (md_writeback_clear),
                                        .md_bru_writeback_reg_out_bid  (md_bru_writeback_reg_out_bid),


                                        .fast_issue_queue_issue_valid(fast_issue_queue_issue_valid),
                                        .fast_issue_queue_stall      (fast_issue_queue_stall),
                                        .fast_issue_clear            (fast_issue_clear),

                                        .fast_issue_writeback_reg_out_valid(fast_issue_writeback_reg_out_valid),
                                        .fast_issue_writeback_reg_stall    (fast_issue_writeback_reg_stall),
                                        .fast_writeback_clear              (fast_writeback_clear),
                                        .fast_issue_writeback_reg_out_bid  (fast_issue_writeback_reg_out_bid),

                                        .fast_issue_queue_extra_issue_valid(fast_issue_queue_extra_issue_valid),
                                        .fast_issue_queue_extra_stall      (fast_issue_queue_extra_stall),

                                        .fast_extra_issue_writeback_reg_out_valid(fast_extra_issue_writeback_reg_out_valid),
                                        .fast_extra_issue_writeback_reg_stall    (fast_extra_issue_writeback_reg_stall),
                                        .fast_extra_writeback_clear              (fast_extra_writeback_clear),
                                        .fast_extra_issue_writeback_reg_out_bid  (fast_extra_issue_writeback_reg_out_bid),

                                        .privilege_issue_queue_issue_valid(privilege_issue_queue_issue_valid),
                                        .privilege_issue_queue_stall      (privilege_issue_queue_stall),
                                        .privilege_issue_clear            (privilege_issue_clear),


                                        .global_flush(global_flush),

                                        .ins_fifo_8in4out_allow_in(ins_fifo_8in4out_allow_in),

                                        .lsu_issue_read_reg_out_is_store_or_not_load(lsu_issue_read_reg_out_is_store_or_not_load),
                                        .lsu_read_exec_reg_out_is_store_or_not_load(lsu_read_exec_reg_out_is_store_or_not_load),
                                        .lsu_exec_mem1_reg_out_is_store_or_not_load(lsu_exec_mem1_reg_out_is_store_or_not_load),
                                        .lsu_mem1_mem2_reg_out_is_store_or_not_load(lsu_mem1_mem2_reg_out_is_store_or_not_load),
                                        .lsu_mem2_load_miss                        (lsu_mem2_load_miss),



                                        .b_flush      (b_flush),
                                        .predict_flush(predict_flush),

                                        .md_bru_writeback_reg_out_is_jump    (md_bru_writeback_reg_out_is_jump),
                                        .predict_flush_bid                   (predict_flush_bid),
                                        .branch_id_allocator_bid_head        (branch_id_allocator_bid_head),

                                        .inst_sram_fsm_state(inst_sram_fsm_state),
                                        .data_sram_fsm_state(data_sram_fsm_state),

                                        .data_sram_fsm_miss_trans(data_sram_fsm_miss_trans),

                                        .cache_subsystem_mem2_miss        (cache_subsystem_mem2_miss),
                                        .cache_subsystem_mem2_refill_valid(cache_subsystem_mem2_refill_valid),
                                        .cache_subsystem_if2_miss         (cache_subsystem_if2_miss),
                                        .cache_subsystem_if2_refill_valid (cache_subsystem_if2_refill_valid),
                                        .cache_subsystem_icache_busy      (cache_subsystem_icache_busy),

                                        .cacop_fsm_state               (cacop_fsm_state),
                                        .lsu_mem1_mem2_reg_out_is_cacop(lsu_mem1_mem2_reg_out_is_cacop),
                                        .lsu_exec_mem1_reg_out_is_cacop(lsu_exec_mem1_reg_out_is_cacop),
                                        .lsu_issue_read_reg_out_is_cacop(lsu_issue_read_reg_out_is_cacop),
                                        .lsu_read_exec_reg_out_is_cacop(lsu_read_exec_reg_out_is_cacop),
                                        .rob_commit_rob_id             (rob_commit_rob_id[0]),
                                        .lsu_read_exec_reg_out_rob_id  (lsu_read_exec_reg_out_rob_id),
                                        .decode_is_idle(compress_decode_is_idle[0]),
                                        .is_int(is_int),

                                        .lsu_mem1_mem2_reg_out_is_dbar(lsu_mem1_mem2_reg_out_is_dbar),
                                        .lsu_mem1_mem2_reg_out_is_sc_w(lsu_mem1_mem2_reg_out_is_sc_w),
                                        .csr_regfile_llbit(csr_regfile_llbit),

                                        .lsu_read_exec_reg_out_is_ll_w(lsu_read_exec_reg_out_is_ll_w),
                                        .lsu_read_exec_reg_out_is_sc_w(lsu_read_exec_reg_out_is_sc_w),
                                        .lsu_read_exec_reg_out_is_dbar(lsu_read_exec_reg_out_is_dbar),
                                        .lsu_issue_read_reg_out_is_ll_w(lsu_issue_read_reg_out_is_ll_w),
                                        .lsu_issue_read_reg_out_is_sc_w(lsu_issue_read_reg_out_is_sc_w),
                                        .lsu_issue_read_reg_out_is_dbar(lsu_issue_read_reg_out_is_dbar),

                                        .id_rename_pipeline_queue_b_flush_r(id_rename_pipeline_queue_b_flush_r),

                                        .lsu_read_phy_reg_rdy1(lsu_read_phy_reg_rdy1),
                                        .lsu_read_phy_reg_rdy2(lsu_read_phy_reg_rdy2)

                                    );


`ifdef difftest

            assign debug0_wb_pc = rob_commit_pc[0];
            assign debug0_wb_rf_wen = {4{rob_commit_fire[0] && rob_commit_regfile_we[0] && !rob_commit_is_exception[0]}};
            assign debug0_wb_rf_wnum = rob_commit_arch_dest[0];
            assign debug0_wb_rf_wdata = rob_commit_value[0];


            `elsif perftest_or_linux

                   assign debug0_wb_pc = rob_commit_pc[0];
            assign debug0_wb_rf_wen = {4{rob_commit_fire[0] && rob_commit_regfile_we[0] && !rob_commit_is_exception[0]}};
            assign debug0_wb_rf_wnum = rob_commit_arch_dest[0];
            assign debug0_wb_rf_wdata = rob_commit_value[0];


`else

            assign debug_wb_pc       = rob_commit_pc[0];
            assign debug_wb_rf_we    = {4{rob_commit_fire[0] && rob_commit_regfile_we[0] && !rob_commit_is_exception[0]}};
            assign debug_wb_rf_wnum  = rob_commit_arch_dest[0];
            assign debug_wb_rf_wdata = rob_commit_value[0];


`endif


`ifdef difftest

            wire [81:0] id_rename_difftest_forward_queue_out_data [3:0];

            difftest_forward_queue u_id_rename_difftest_forward_reg(
                                       .clk(clk),
                                       .resetn(resetn),
                                       .flush(id_rename_pipeline_queue_flush),

                                       .in_fire(id_rename_pipeline_queue_in_fire),
                                       .in_data0({compress_decode_csr_3w[0], compress_decode_is_CNTinst[0], compress_decode_load_valid[0], compress_decode_store_valid[0], rdcnt}),
                                       .in_data1({compress_decode_csr_3w[1], compress_decode_is_CNTinst[1], compress_decode_load_valid[1], compress_decode_store_valid[1], rdcnt}),
                                       .in_data2({compress_decode_csr_3w[2], compress_decode_is_CNTinst[2], compress_decode_load_valid[2], compress_decode_store_valid[2], rdcnt}),
                                       .in_data3({compress_decode_csr_3w[3], compress_decode_is_CNTinst[3], compress_decode_load_valid[3], compress_decode_store_valid[3], rdcnt}),

                                       .out_fire(id_rename_pipeline_queue_out_valid & id_rename_pipeline_queue_out_ready),
                                       .out_data0(id_rename_difftest_forward_queue_out_data[0]),
                                       .out_data1(id_rename_difftest_forward_queue_out_data[1]),
                                       .out_data2(id_rename_difftest_forward_queue_out_data[2]),
                                       .out_data3(id_rename_difftest_forward_queue_out_data[3])
                                   );

            wire        rename_dispatch_difftest_forward_reg_out_csr_3w;
            wire        rename_dispatch_difftest_forward_reg_out_is_CNTinst;
            wire [ 7:0] rename_dispatch_difftest_forward_reg_out_load_valid;
            wire [ 7:0] rename_dispatch_difftest_forward_reg_out_store_valid;
            wire [63:0] rename_dispatch_difftest_forward_reg_out_timer_64_value;

            wire [81:0] rename_dispatch_difftest_forward_queue_out_data [3:0];

            difftest_forward_queue u_rename_dispatch_difftest_forward_reg(
                                       .clk(clk),
                                       .resetn(resetn),
                                       .flush(rename_dispatch_pipeline_queue_flush),

                                       .in_fire(rename_dispatch_pipeline_queue_in_valid & rename_dispatch_pipeline_queue_in_ready),
                                       .in_data0(id_rename_difftest_forward_queue_out_data[0]),
                                       .in_data1(id_rename_difftest_forward_queue_out_data[1]),
                                       .in_data2(id_rename_difftest_forward_queue_out_data[2]),
                                       .in_data3(id_rename_difftest_forward_queue_out_data[3]),

                                       .out_fire(rename_dispatch_pipeline_queue_out_valid & rename_dispatch_pipeline_queue_out_ready),
                                       .out_data0(rename_dispatch_difftest_forward_queue_out_data[0]),
                                       .out_data1(rename_dispatch_difftest_forward_queue_out_data[1]),
                                       .out_data2(rename_dispatch_difftest_forward_queue_out_data[2]),
                                       .out_data3(rename_dispatch_difftest_forward_queue_out_data[3])
                                   );

            assign {
                    rename_dispatch_difftest_forward_reg_out_csr_3w,
                    rename_dispatch_difftest_forward_reg_out_is_CNTinst,
                    rename_dispatch_difftest_forward_reg_out_load_valid,
                    rename_dispatch_difftest_forward_reg_out_store_valid,
                    rename_dispatch_difftest_forward_reg_out_timer_64_value
                } = rename_dispatch_difftest_forward_queue_out_data[0];

            wire [3:0] difftest_rob_commit_csr_3w;
            wire [3:0] difftest_rob_commit_is_CNTinst;
            wire [7:0] difftest_rob_commit_load_valid [3:0];
            wire [7:0] difftest_rob_commit_store_valid [3:0];
            wire [63:0] difftest_rob_commit_timer_64_value [3:0];
            wire [3:0] difftest_rob_commit_tlbfill_index [3:0];
            wire [31:0] difftest_rob_commit_vaddr [3:0];
            wire [31:0] difftest_rob_commit_paddr [3:0];
            wire [31:0] difftest_rob_commit_store_data [3:0];
            wire [3:0] difftest_rob_commit_is_tlbfill;

            difftest_rob u_difftest_rob(
                             .clk(clk),
                             .alloc_fire(rob_alloc_valid & rob_alloc_ready),
                             .alloc_rob_0(rob_alloc_rob_id[0]),
                             .alloc_rob_1(rob_alloc_rob_id[1]),
                             .alloc_rob_2(rob_alloc_rob_id[2]),
                             .alloc_rob_3(rob_alloc_rob_id[3]),
                             .alloc_data_0(rename_dispatch_difftest_forward_queue_out_data[0]),
                             .alloc_data_1(rename_dispatch_difftest_forward_queue_out_data[1]),
                             .alloc_data_2(rename_dispatch_difftest_forward_queue_out_data[2]),
                             .alloc_data_3(rename_dispatch_difftest_forward_queue_out_data[3]),
                             .alloc_is_tlbfill(rename_dispatch_pipeline_queue_out_is_inst_tlbfill),

                             .tlbfill_fire(extra_exec_writeback_reg_out_valid &&
                                           privilege_exec_writeback_reg_out_is_inst_tlbfill),
                             .tlbfill_rob(extra_exec_writeback_reg_out_rob_id),
                             .tlbfill_index(mmu_tlbfill_index),

                             .ls_fire(lsu_mem1_mem2_reg_out_valid &&
                                      !lsu_mem1_mem2_state_out_is_exception &&
                                      !lsu_mem1_mem2_reg_out_store_ctrl),
                             .ls_llbit(csr_regfile_llbit),
                             .ls_rob(lsu_mem1_mem2_reg_out_rob_id),
                             .ls_vaddr(lsu_mem1_mem2_reg_out_address),
                             .ls_paddr(lsu_mem1_mem2_reg_out_address_pa),
                             .ls_store_data(lsu_mem1_mem2_reg_out_store_data &
                                            {{8{lsu_mem1_mem2_reg_out_wstrb[3]}},
                                             {8{lsu_mem1_mem2_reg_out_wstrb[2]}},
                                             {8{lsu_mem1_mem2_reg_out_wstrb[1]}},
                                             {8{lsu_mem1_mem2_reg_out_wstrb[0]}}}),

                             .commit_rob(rob_commit_rob_id),
                             .commit_csr_3w(difftest_rob_commit_csr_3w),
                             .commit_is_CNTinst(difftest_rob_commit_is_CNTinst),
                             .commit_load_valid(difftest_rob_commit_load_valid),
                             .commit_store_valid(difftest_rob_commit_store_valid),
                             .commit_timer_64_value(difftest_rob_commit_timer_64_value),
                             .commit_tlbfill_index(difftest_rob_commit_tlbfill_index),
                             .commit_vaddr(difftest_rob_commit_vaddr),
                             .commit_paddr(difftest_rob_commit_paddr),
                             .commit_store_data(difftest_rob_commit_store_data),
                             .commit_is_tlbfill(difftest_rob_commit_is_tlbfill)
                         );

            wire [3:0] difftest_commit_valid;
            wire [3:0] difftest_commit_csr_3w;
            wire [3:0] difftest_commit_is_CNTinst;
            wire [7:0] difftest_commit_load_valid [3:0];
            wire [7:0] difftest_commit_store_valid [3:0];
            wire [63:0] difftest_commit_timer_64_value [3:0];
            wire [31:0] difftest_commit_vaddr [3:0];
            wire [31:0] difftest_commit_paddr [3:0];
            wire [31:0] difftest_commit_store_data [3:0];
            wire [31:0] difftest_commit_pc [3:0];
            wire [31:0] difftest_commit_instruction [3:0];
            wire [3:0] difftest_commit_is_tlbfill;
            wire [3:0] difftest_commit_tlbfill_index [3:0];
            wire [3:0] difftest_commit_wen;
            wire [4:0] difftest_commit_wdest [3:0];
            wire [31:0] difftest_commit_wdata [3:0];
            wire [3:0] difftest_commit_is_exception;
            wire [3:0] difftest_commit_is_eret;

            genvar difftest_lane;
            generate
                for (difftest_lane = 0; difftest_lane < 4;
                        difftest_lane = difftest_lane + 1) begin : gen_difftest_lane
                    localparam [7:0]
                               DIFFTEST_INDEX = difftest_lane;

                    wire [7:0] difftest_sq_match;
                    wire difftest_sq_match_valid;
                    wire [31:0] difftest_sq_raw_data;
                    wire [LQSQ_RESERVED_WIDTH-1:0]
                         difftest_sq_reserved;
                    wire [3:0] difftest_sq_formatted_wstrb;
                    wire [31:0] difftest_sq_formatted_data;
                    wire [31:0] difftest_sq_store_data;

                    assign difftest_sq_match[0]
                           = lqsq_sq_entry_valid[0]
                           && lqsq_sq_entry_next_prdy[0]
                           && lqsq_sq_entry_reserved_flat[
                               LQSQ_ROB_LSB +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[1]
                           = lqsq_sq_entry_valid[1]
                           && lqsq_sq_entry_next_prdy[1]
                           && lqsq_sq_entry_reserved_flat[
                               LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[2]
                           = lqsq_sq_entry_valid[2]
                           && lqsq_sq_entry_next_prdy[2]
                           && lqsq_sq_entry_reserved_flat[
                               2*LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[3]
                           = lqsq_sq_entry_valid[3]
                           && lqsq_sq_entry_next_prdy[3]
                           && lqsq_sq_entry_reserved_flat[
                               3*LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[4]
                           = lqsq_sq_entry_valid[4]
                           && lqsq_sq_entry_next_prdy[4]
                           && lqsq_sq_entry_reserved_flat[
                               4*LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[5]
                           = lqsq_sq_entry_valid[5]
                           && lqsq_sq_entry_next_prdy[5]
                           && lqsq_sq_entry_reserved_flat[
                               5*LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[6]
                           = lqsq_sq_entry_valid[6]
                           && lqsq_sq_entry_next_prdy[6]
                           && lqsq_sq_entry_reserved_flat[
                               6*LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];
                    assign difftest_sq_match[7]
                           = lqsq_sq_entry_valid[7]
                           && lqsq_sq_entry_next_prdy[7]
                           && lqsq_sq_entry_reserved_flat[
                               7*LQSQ_RESERVED_WIDTH + LQSQ_ROB_LSB
                               +: `ROB_ID_WIDTH]
                           == rob_commit_rob_id[difftest_lane];

                    assign difftest_sq_match_valid = |difftest_sq_match;
                    assign difftest_sq_raw_data
                           = difftest_sq_match[0]
                           ? lqsq_sq_entry_next_data_flat[0*32 +: 32]
                           : difftest_sq_match[1]
                           ? lqsq_sq_entry_next_data_flat[1*32 +: 32]
                           : difftest_sq_match[2]
                           ? lqsq_sq_entry_next_data_flat[2*32 +: 32]
                           : difftest_sq_match[3]
                           ? lqsq_sq_entry_next_data_flat[3*32 +: 32]
                           : difftest_sq_match[4]
                           ? lqsq_sq_entry_next_data_flat[4*32 +: 32]
                           : difftest_sq_match[5]
                           ? lqsq_sq_entry_next_data_flat[5*32 +: 32]
                           : difftest_sq_match[6]
                           ? lqsq_sq_entry_next_data_flat[6*32 +: 32]
                           : lqsq_sq_entry_next_data_flat[7*32 +: 32];
                    assign difftest_sq_reserved
                           = difftest_sq_match[0]
                           ? lqsq_sq_entry_reserved_flat[
                               0*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : difftest_sq_match[1]
                           ? lqsq_sq_entry_reserved_flat[
                               1*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : difftest_sq_match[2]
                           ? lqsq_sq_entry_reserved_flat[
                               2*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : difftest_sq_match[3]
                           ? lqsq_sq_entry_reserved_flat[
                               3*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : difftest_sq_match[4]
                           ? lqsq_sq_entry_reserved_flat[
                               4*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : difftest_sq_match[5]
                           ? lqsq_sq_entry_reserved_flat[
                               5*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : difftest_sq_match[6]
                           ? lqsq_sq_entry_reserved_flat[
                               6*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH]
                           : lqsq_sq_entry_reserved_flat[
                               7*LQSQ_RESERVED_WIDTH
                               +: LQSQ_RESERVED_WIDTH];

                    select_store u_difftest_sq_select_store (
                                     .addr(difftest_sq_reserved[
                                               LQSQ_VADDR_LSB +: 2]),
                                     .data(difftest_sq_raw_data),
                                     .sel_load_store_len(difftest_sq_reserved[
                                                             LQSQ_LEN_LSB +: 3]),
                                     .wstrb(difftest_sq_formatted_wstrb),
                                     .result(difftest_sq_formatted_data)
                                 );

                    assign difftest_sq_store_data
                           = difftest_sq_formatted_data
                           & {{8{difftest_sq_formatted_wstrb[3]}},
                              {8{difftest_sq_formatted_wstrb[2]}},
                              {8{difftest_sq_formatted_wstrb[1]}},
                              {8{difftest_sq_formatted_wstrb[0]}}};

                    difftest_commit_reg u_difftest_commit_reg(
                                            .clk(clk),
                                            .resetn(resetn),
                                            .stall(1'b0),
                                            .in_csr_3w(difftest_rob_commit_csr_3w[difftest_lane]),
                                            .in_is_CNTinst(difftest_rob_commit_is_CNTinst[difftest_lane]),
                                            .in_load_valid(difftest_rob_commit_load_valid[difftest_lane]),
                                            .in_store_valid(difftest_rob_commit_store_valid[difftest_lane]),
                                            .in_timer_64_value(difftest_rob_commit_timer_64_value[difftest_lane]),
                                            .in_vaddr(difftest_rob_commit_vaddr[difftest_lane]),
                                            .in_paddr(difftest_rob_commit_paddr[difftest_lane]),
                                            .in_storeData(difftest_sq_match_valid
                                                          ? difftest_sq_store_data
                                                          : difftest_rob_commit_store_data[difftest_lane]),
                                            .in_valid(rob_commit_fire[difftest_lane] &&
                                                      !rob_commit_is_exception[difftest_lane]),
                                            .in_pc(rob_commit_pc[difftest_lane]),
                                            .in_instruction(rob_commit_instruction[difftest_lane]),
                                            .in_is_tlbfill(difftest_rob_commit_is_tlbfill[difftest_lane]),
                                            .in_tlbfill_index(difftest_rob_commit_tlbfill_index[difftest_lane]),
                                            .in_wen(rob_commit_regfile_we[difftest_lane] &&
                                                    !rob_commit_is_exception[difftest_lane]),
                                            .in_wdest(rob_commit_arch_dest[difftest_lane]),
                                            .in_wdata(rob_commit_value[difftest_lane]),
                                            .in_is_exception(rob_commit_fire[difftest_lane] &&
                                                             rob_commit_is_exception[difftest_lane]),
                                            .in_is_eret(rob_commit_fire[difftest_lane] &&
                                                        rob_commit_ertn_flush[difftest_lane] &&
                                                        !rob_commit_is_exception[difftest_lane]),
                                            .out_csr_3w(difftest_commit_csr_3w[difftest_lane]),
                                            .out_is_CNTinst(difftest_commit_is_CNTinst[difftest_lane]),
                                            .out_load_valid(difftest_commit_load_valid[difftest_lane]),
                                            .out_store_valid(difftest_commit_store_valid[difftest_lane]),
                                            .out_timer_64_value(difftest_commit_timer_64_value[difftest_lane]),
                                            .out_vaddr(difftest_commit_vaddr[difftest_lane]),
                                            .out_paddr(difftest_commit_paddr[difftest_lane]),
                                            .out_storeData(difftest_commit_store_data[difftest_lane]),
                                            .out_valid(difftest_commit_valid[difftest_lane]),
                                            .out_pc(difftest_commit_pc[difftest_lane]),
                                            .out_instruction(difftest_commit_instruction[difftest_lane]),
                                            .out_is_tlbfill(difftest_commit_is_tlbfill[difftest_lane]),
                                            .out_tlbfill_index(difftest_commit_tlbfill_index[difftest_lane]),
                                            .out_wen(difftest_commit_wen[difftest_lane]),
                                            .out_wdest(difftest_commit_wdest[difftest_lane]),
                                            .out_wdata(difftest_commit_wdata[difftest_lane]),
                                            .out_is_exception(difftest_commit_is_exception[difftest_lane]),
                                            .out_is_eret(difftest_commit_is_eret[difftest_lane])
                                        );

                    DifftestInstrCommit u_difftest_InstrCommit(
                                            .clock(clk),
                                            .coreid(8'd0),
                                            .index(DIFFTEST_INDEX),
                                            .valid(difftest_commit_valid[difftest_lane]),
                                            .pc({32'd0, difftest_commit_pc[difftest_lane]}),
                                            .instr(difftest_commit_instruction[difftest_lane]),
                                            .skip(1'b0),
                                            .is_TLBFILL(difftest_commit_is_tlbfill[difftest_lane]),
                                            .TLBFILL_index({1'b0, difftest_commit_tlbfill_index[difftest_lane]}),
                                            .is_CNTinst(difftest_commit_is_CNTinst[difftest_lane]),
                                            .timer_64_value(difftest_commit_timer_64_value[difftest_lane]),
                                            .wen(difftest_commit_wen[difftest_lane]),
                                            .wdest({3'd0, difftest_commit_wdest[difftest_lane]}),
                                            .wdata({32'd0, difftest_commit_wdata[difftest_lane]}),
                                            .csr_rstat(difftest_commit_csr_3w[difftest_lane]),
                                            .csr_data(difftest_commit_wdata[difftest_lane])
                                        );

                    DifftestStoreEvent u_difftest_StoreEvent(
                                           .clock(clk),
                                           .coreid(8'd0),
                                           .index(DIFFTEST_INDEX),
                                           .valid(difftest_commit_store_valid[difftest_lane] &
                                                  {8{difftest_commit_valid[difftest_lane]}}),
                                           .storePAddr({32'd0, difftest_commit_paddr[difftest_lane]}),
                                           .storeVAddr({32'd0, difftest_commit_vaddr[difftest_lane]}),
                                           .storeData({32'd0, difftest_commit_store_data[difftest_lane]})
                                       );

                    DifftestLoadEvent u_difftest_LoadEvent(
                                          .clock(clk),
                                          .coreid(8'd0),
                                          .index(DIFFTEST_INDEX),
                                          .valid(difftest_commit_load_valid[difftest_lane] &
                                                 {8{difftest_commit_valid[difftest_lane]}}),
                                          .paddr({32'd0, difftest_commit_paddr[difftest_lane]}),
                                          .vaddr({32'd0, difftest_commit_vaddr[difftest_lane]})
                                      );
                end
            endgenerate

            wire [3:0] difftest_event_valid;
            wire [1:0] difftest_event_lane;
            assign difftest_event_valid = difftest_commit_is_exception |
                   difftest_commit_is_eret;
            assign difftest_event_lane = difftest_event_valid[0] ? 2'd0 :
                   difftest_event_valid[1] ? 2'd1 :
                   difftest_event_valid[2] ? 2'd2 : 2'd3;

            DifftestExcpEvent u_difftest_ExcpEvent(
                                  .clock(clk),
                                  .coreid(8'd0),
                                  .excp_valid(|difftest_commit_is_exception),
                                  .eret(|difftest_commit_is_eret),
                                  .intrNo({21'b0, csr_regfile_out_csr_estat[12:2]}),
                                  .cause({26'b0, csr_regfile_out_csr_estat[`CSR_ESTAT_ECODE]}),
                                  .exceptionPC({32'd0, difftest_commit_pc[difftest_event_lane]}),
                                  .exceptionInst(difftest_commit_instruction[difftest_event_lane])
                              );

            DifftestTrapEvent u_difftest_TrapEvent(
                                  .clock(clk),
                                  .coreid(8'd0),
                                  .valid(1'b0),
                                  .code(3'd0),
                                  .pc({32'd0, difftest_commit_pc[difftest_event_lane]}),
                                  .cycleCnt(rdcnt),
                                  .instrCnt(64'd0)
                              );






`endif










        endmodule
