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
            wire [ 31:0] inst_sram_rdata;

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
            wire [31:0] inst_stall_buffer_in_data;
            wire [31:0] inst_stall_buffer_out_data;


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

            wire                                          inst_fifo_clear;
            wire                                          inst_fifo_in_valid;
            wire                                          inst_fifo_wr_ready;
            wire [                                  101:0] inst_fifo_in_data;
            wire                                          inst_fifo_stall;
            wire                                          inst_fifo_out_valid;
            wire [                                  101:0] inst_fifo_out_data;

            wire [                                   7:0] inst_fifo_count;
            wire [                                   7:0] inst_fifo_avail;



            wire                                          insfifo_is_exception;
            wire                                          insfifo_is_adef;
            wire                                          insfifo_is_tlbr;
            wire                                          insfifo_is_inst_tlbr;
            wire                                          insfifo_is_inst_pif;
            wire                                          insfifo_is_inst_ppi;



            wire [                                  31:0] inst_fifo_instruction;
            wire [                                  31:0] inst_fifo_pc;
            wire                                          inst_fifo_valid;
            wire                                          id_clear;

            wire [                                  31:0] decode_instruction;
            wire [                                   4:0] decode_regfile_raddr1;
            wire [                                   4:0] decode_regfile_raddr2;
            wire                                          decode_regfile_we;
            wire [                                   4:0] decode_regfile_waddr;
            wire [                                   1:0] decode_sel_npc;
            wire [                                   4:0] decode_alu_op;
            wire [                                   2:0] decode_comparator_op;
            wire [                                   2:0] decode_sel_issue_queue;
            wire                                          decode_sel_imm;
            wire [                                   1:0] decode_ext_simm;
            wire                                          decode_sel_lui12;
            wire [                                   6:0] decode_md_op;
            wire [                                   2:0] decode_sel_load_store_len;
            wire [                                   2:0] decode_sel_pre_result;


            wire [                                  13:0] decode_csr_addr;
            wire                                          decode_csr_we;
            wire                                          decode_csr_re;
            wire                                          decode_sel_csr_wmask;
            wire                                          decode_csr_ertn_flush;

            wire                                          decode_is_sys;
            wire                                          decode_is_brk;
            wire                                          decode_is_ine;



            wire [                                  31:0] id_pre_result                                            [6:0];

            wire [                                  31:0] ext_instruction;
            wire [                                   1:0] ext_simm;
            wire [                                  31:0] ext_extended_imm;
            wire [                                  31:0] ext_offset16;
            wire [                                  31:0] ext_offset26;



            wire                                          id_allocbid_state_in_is_exception;
            wire                                          id_allocbid_state_in_is_sys;
            wire                                          id_allocbid_state_in_is_int;
            wire                                          id_allocbid_state_in_ertn_flush;
            wire [                                  13:0] id_allocbid_state_in_csr_addr;
            wire                                          id_allocbid_state_in_csr_we;
            wire                                          id_allocbid_state_in_sel_csr_wmask;
            wire                                          id_allocbid_state_in_csr_re;

            wire                                          id_allocbid_state_in_is_adef;
            wire                                          id_allocbid_state_in_is_ine;
            wire                                          id_allocbid_state_in_is_brk;

            // wire        id_allocbid_state_in_tlb_we;
            wire [                                   4:0] id_allocbid_state_in_invtlb_op;
            wire                                          id_allocbid_state_in_is_inst_tlbsrch;
            wire                                          id_allocbid_state_in_is_inst_tlbrd;
            wire                                          id_allocbid_state_in_is_inst_tlbwr;
            wire                                          id_allocbid_state_in_is_inst_tlbfill;
            wire                                          id_allocbid_state_in_is_inst_invtlb;

            wire                                          id_allocbid_state_in_is_tlbr;
            wire                                          id_allocbid_state_in_is_inst_tlbr;
            wire                                          id_allocbid_state_in_is_inst_pif;
            wire                                          id_allocbid_state_in_is_inst_ppi;
            wire id_allocbid_state_in_wb_refetch;
            wire id_allocbid_state_in_is_cacop;

            wire                                          id_allocbid_state_out_is_exception;
            wire                                          id_allocbid_state_out_is_sys;
            wire                                          id_allocbid_state_out_is_int;
            wire                                          id_allocbid_state_out_ertn_flush;
            wire [                                  13:0] id_allocbid_state_out_csr_addr;
            wire                                          id_allocbid_state_out_csr_we;
            wire                                          id_allocbid_state_out_sel_csr_wmask;
            wire                                          id_allocbid_state_out_csr_re;

            wire                                          id_allocbid_state_out_is_adef;
            wire                                          id_allocbid_state_out_is_ine;
            wire                                          id_allocbid_state_out_is_brk;

            // wire        id_allocbid_state_out_tlb_we;
            wire [                                   4:0] id_allocbid_state_out_invtlb_op;
            wire                                          id_allocbid_state_out_is_inst_tlbsrch;
            wire                                          id_allocbid_state_out_is_inst_tlbrd;
            wire                                          id_allocbid_state_out_is_inst_tlbwr;
            wire                                          id_allocbid_state_out_is_inst_tlbfill;
            wire                                          id_allocbid_state_out_is_inst_invtlb;

            wire                                          id_allocbid_state_out_is_tlbr;
            wire                                          id_allocbid_state_out_is_inst_tlbr;
            wire                                          id_allocbid_state_out_is_inst_pif;
            wire                                          id_allocbid_state_out_is_inst_ppi;
            wire id_allocbid_state_out_wb_refetch;
            wire id_allocbid_state_out_is_cacop;






            wire                                          allocbid_clear;
            wire                                          id_allocbid_reg_stall;
            wire                                          id_allocbid_reg_pre_stall;

            wire                                          id_allocbid_reg_in_valid;
            wire [                                  31:0] id_allocbid_reg_in_pc;
            wire [                                  31:0] id_allocbid_reg_in_instruction;
            wire [                                   4:0] id_allocbid_reg_in_regfile_raddr1;
            wire [                                   4:0] id_allocbid_reg_in_regfile_raddr2;
            wire                                          id_allocbid_reg_in_regfile_we;
            wire [                                   4:0] id_allocbid_reg_in_regfile_waddr;
            wire [                                   1:0] id_allocbid_reg_in_sel_npc;
            wire [                                   4:0] id_allocbid_reg_in_alu_op;
            wire [                                   2:0] id_allocbid_reg_in_comparator_op;
            wire [                                   2:0] id_allocbid_reg_in_sel_issue_queue;
            wire                                          id_allocbid_reg_in_sel_imm;
            wire [                                  31:0] id_allocbid_reg_in_extended_imm;
            wire [                                  31:0] id_allocbid_reg_in_target_b;
            wire [                                   6:0] id_allocbid_reg_in_md_op;
            wire [                                   2:0] id_allocbid_reg_in_sel_load_store_len;

            wire                                          id_allocbid_reg_out_valid;
            wire [                                  31:0] id_allocbid_reg_out_pc;
            wire [                                  31:0] id_allocbid_reg_out_instruction;
            wire [                                   4:0] id_allocbid_reg_out_regfile_raddr1;
            wire [                                   4:0] id_allocbid_reg_out_regfile_raddr2;
            wire                                          id_allocbid_reg_out_regfile_we;
            wire [                                   4:0] id_allocbid_reg_out_regfile_waddr;
            wire [                                   1:0] id_allocbid_reg_out_sel_npc;
            wire [                                   4:0] id_allocbid_reg_out_alu_op;
            wire [                                   2:0] id_allocbid_reg_out_comparator_op;
            wire [                                   2:0] id_allocbid_reg_out_sel_issue_queue;
            wire                                          id_allocbid_reg_out_sel_imm;
            wire [                                  31:0] id_allocbid_reg_out_extended_imm;
            wire [                                  31:0] id_allocbid_reg_out_target_b;
            wire [                                   6:0] id_allocbid_reg_out_md_op;
            wire [                                   2:0] id_allocbid_reg_out_sel_load_store_len;



            wire [                                  31:0] branch_id_allocator_alloc_pc;
            wire [                                  31:0] branch_id_allocator_alloc_target_address;
            wire [                                  31:0] branch_id_allocator_alloc_imm;
            wire                                          branch_id_allocator_alloc_bid_valid;
            wire                                          branch_id_allocator_alloc_bid_ready;
            wire [                                   4:0] branch_id_allocator_alloc_bid;

            wire                                          branch_id_allocator_commit_branch_valid;

            wire                                          branch_id_allocator_global_flush;
            wire                                          branch_id_allocator_predict_flush;
            wire [                                   4:0] branch_id_allocator_predict_flush_bid;

            wire [                                   4:0] branch_id_allocator_bid_head;
            wire [                                   4:0] branch_id_allocator_bid_tail;

            wire [                                   4:0] branch_id_allocator_lookup_bid;
            wire [                                  31:0] branch_id_allocator_lookup_pc;
            wire [                                  31:0] branch_id_allocator_lookup_target_address;
            wire [                                  31:0] branch_id_allocator_lookup_imm;


            wire                                          allocbid_buffer_alloc_valid;
            wire [                                   4:0] allocbid_buffer_alloc_bid;
            wire                                          allocbid_buffer_alloc_already;
            wire [                                   4:0] allocbid_buffer_update_alloc_bid;




            wire                                          allocbid_rename_state_in_is_exception;
            wire                                          allocbid_rename_state_in_is_sys;
            wire                                          allocbid_rename_state_in_is_int;
            wire                                          allocbid_rename_state_in_ertn_flush;
            wire [                                  13:0] allocbid_rename_state_in_csr_addr;
            wire                                          allocbid_rename_state_in_csr_we;
            wire                                          allocbid_rename_state_in_csr_re;
            wire                                          allocbid_rename_state_in_sel_csr_wmask;

            wire                                          allocbid_rename_state_in_is_adef;
            wire                                          allocbid_rename_state_in_is_ine;
            wire                                          allocbid_rename_state_in_is_brk;

            // wire        allocbid_rename_state_in_tlb_we;
            wire [                                   4:0] allocbid_rename_state_in_invtlb_op;
            wire                                          allocbid_rename_state_in_is_inst_tlbsrch;
            wire                                          allocbid_rename_state_in_is_inst_tlbrd;
            wire                                          allocbid_rename_state_in_is_inst_tlbwr;
            wire                                          allocbid_rename_state_in_is_inst_tlbfill;
            wire                                          allocbid_rename_state_in_is_inst_invtlb;

            wire                                          allocbid_rename_state_in_is_tlbr;
            wire                                          allocbid_rename_state_in_is_inst_tlbr;
            wire                                          allocbid_rename_state_in_is_inst_pif;
            wire                                          allocbid_rename_state_in_is_inst_ppi;
            wire allocbid_rename_state_in_wb_refetch;
            wire allocbid_rename_state_in_is_cacop;

            wire                                          allocbid_rename_state_out_is_exception;
            wire                                          allocbid_rename_state_out_is_sys;
            wire                                          allocbid_rename_state_out_is_int;
            wire                                          allocbid_rename_state_out_ertn_flush;
            wire [                                  13:0] allocbid_rename_state_out_csr_addr;
            wire                                          allocbid_rename_state_out_csr_we;
            wire                                          allocbid_rename_state_out_csr_re;
            wire                                          allocbid_rename_state_out_sel_csr_wmask;

            wire                                          allocbid_rename_state_out_is_adef;
            wire                                          allocbid_rename_state_out_is_ine;
            wire                                          allocbid_rename_state_out_is_brk;
            wire allocbid_rename_state_out_wb_refetch;
            wire allocbid_rename_state_out_is_cacop;

            // wire        allocbid_rename_state_out_tlb_we;
            wire [                                   4:0] allocbid_rename_state_out_invtlb_op;
            wire                                          allocbid_rename_state_out_is_inst_tlbsrch;
            wire                                          allocbid_rename_state_out_is_inst_tlbrd;
            wire                                          allocbid_rename_state_out_is_inst_tlbwr;
            wire                                          allocbid_rename_state_out_is_inst_tlbfill;
            wire                                          allocbid_rename_state_out_is_inst_invtlb;

            wire                                          allocbid_rename_state_out_is_tlbr;
            wire                                          allocbid_rename_state_out_is_inst_tlbr;
            wire                                          allocbid_rename_state_out_is_inst_pif;
            wire                                          allocbid_rename_state_out_is_inst_ppi;



            wire                                          rename_clear;
            wire                                          allocbid_rename_reg_stall;
            wire                                          allocbid_rename_reg_pre_stall;

            wire                                          allocbid_rename_reg_in_valid;
            wire [                                  31:0] allocbid_rename_reg_in_pc;
            wire [                                  31:0] allocbid_rename_reg_in_instruction;
            wire [                                   4:0] allocbid_rename_reg_in_regfile_raddr1;
            wire [                                   4:0] allocbid_rename_reg_in_regfile_raddr2;
            wire                                          allocbid_rename_reg_in_regfile_we;
            wire [                                   4:0] allocbid_rename_reg_in_regfile_waddr;
            wire [                                   1:0] allocbid_rename_reg_in_sel_npc;
            wire [                                   4:0] allocbid_rename_reg_in_alu_op;
            wire [                                   2:0] allocbid_rename_reg_in_comparator_op;
            wire [                                   2:0] allocbid_rename_reg_in_sel_issue_queue;
            wire                                          allocbid_rename_reg_in_sel_imm;
            wire [                                  31:0] allocbid_rename_reg_in_extended_imm;
            wire [                                   6:0] allocbid_rename_reg_in_md_op;
            wire [                                   2:0] allocbid_rename_reg_in_sel_load_store_len;
            wire [                                   4:0] allocbid_rename_reg_in_bid;

            wire                                          allocbid_rename_reg_out_valid;
            wire [                                  31:0] allocbid_rename_reg_out_pc;
            wire [                                  31:0] allocbid_rename_reg_out_instruction;
            wire [                                   4:0] allocbid_rename_reg_out_regfile_raddr1;
            wire [                                   4:0] allocbid_rename_reg_out_regfile_raddr2;
            wire                                          allocbid_rename_reg_out_regfile_we;
            wire [                                   4:0] allocbid_rename_reg_out_regfile_waddr;
            wire [                                   1:0] allocbid_rename_reg_out_sel_npc;
            wire [                                   4:0] allocbid_rename_reg_out_alu_op;
            wire [                                   2:0] allocbid_rename_reg_out_comparator_op;
            wire [                                   2:0] allocbid_rename_reg_out_sel_issue_queue;
            wire                                          allocbid_rename_reg_out_sel_imm;
            wire [                                  31:0] allocbid_rename_reg_out_extended_imm;
            wire [                                   6:0] allocbid_rename_reg_out_md_op;
            wire [                                   2:0] allocbid_rename_reg_out_sel_load_store_len;
            wire [                                   4:0] allocbid_rename_reg_out_bid;





            wire [                                   4:0] cam_rmt_arch_reg_src1;
            wire [                                   4:0] cam_rmt_arch_reg_src2;
            wire [                                   4:0] cam_rmt_arch_reg_dst;
            wire                                          cam_rmt_rename_arch_reg_dst_valid;
            wire                                          cam_rmt_valid_copy_valid;
            wire [                                   4:0] cam_rmt_valid_copy_bid;

            wire [                                   6:0] cam_rmt_phy_reg_src1;
            wire                                          cam_rmt_phy_reg_src1_rdy;
            wire [                                   6:0] cam_rmt_phy_reg_src2;
            wire                                          cam_rmt_phy_reg_src2_rdy;


            wire [                                   6:0] cam_rmt_old_phy_reg_dst;
            wire [                                   6:0] cam_rmt_new_phy_reg_dst;
            wire                                          cam_rmt_rename_success;

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

            wire [                                   6:0] cam_rmt_update_commit_new_reg_dst;
            wire [                                   6:0] cam_rmt_update_commit_old_reg_dst;
            wire                                          cam_rmt_update_commit_valid;

            wire                                          cam_rmt_flush;

            wire                                          cam_rmt_predict_flush;
            wire [                                   4:0] cam_rmt_predict_flush_bid;
            wire [                                   4:0] cam_rmt_head_bid;

            wire                                          rename_buffer_stall;
            wire                                          rename_buffer_sel;

            wire                                          rename_buffer_update_rename_success;
            wire [                                   6:0] rename_buffer_update_old_phy_reg_dst;
            wire [                                   6:0] rename_buffer_update_new_phy_reg_dst;
            wire [                                   6:0] rename_buffer_update_phy_reg_src1;
            wire                                          rename_buffer_update_phy_reg_src1_rdy;
            wire [                                   6:0] rename_buffer_update_phy_reg_src2;
            wire                                          rename_buffer_update_phy_reg_src2_rdy;


            wire                                          rename_buffer_result_rename_success;
            wire [                                   6:0] rename_buffer_result_old_phy_reg_dst;
            wire [                                   6:0] rename_buffer_result_new_phy_reg_dst;
            wire [                                   6:0] rename_buffer_result_phy_reg_src1;
            wire                                          rename_buffer_result_phy_reg_src1_rdy;
            wire [                                   6:0] rename_buffer_result_phy_reg_src2;
            wire                                          rename_buffer_result_phy_reg_src2_rdy;

            wire                                          rename_buffer_bypass1_valid;
            wire [                                   6:0] rename_buffer_bypass1_dst;
            wire                                          rename_buffer_bypass2_valid;
            wire [                                   6:0] rename_buffer_bypass2_dst;
            wire                                          rename_buffer_bypass3_valid;
            wire [                                   6:0] rename_buffer_bypass3_dst;
            wire                                          rename_buffer_bypass4_valid;
            wire [                                   6:0] rename_buffer_bypass4_dst;
            wire                                          rename_buffer_bypass5_valid;
            wire [                                   6:0] rename_buffer_bypass5_dst;
            wire                                          rename_buffer_bypass6_valid;
            wire [                                   6:0] rename_buffer_bypass6_dst;
            wire                                          rename_buffer_bypass7_valid;
            wire [                                   6:0] rename_buffer_bypass7_dst;




            wire                                          rename_dispatch_state_in_is_exception;
            wire                                          rename_dispatch_state_in_is_sys;
            wire                                          rename_dispatch_state_in_is_int;
            wire                                          rename_dispatch_state_in_ertn_flush;
            wire [                                  13:0] rename_dispatch_state_in_csr_addr;
            wire                                          rename_dispatch_state_in_csr_we;
            wire                                          rename_dispatch_state_in_csr_re;
            wire                                          rename_dispatch_state_in_sel_csr_wmask;

            wire                                          rename_dispatch_state_in_is_adef;
            wire                                          rename_dispatch_state_in_is_ine;
            wire                                          rename_dispatch_state_in_is_brk;

            // wire        rename_dispatch_state_in_tlb_we;
            wire [                                   4:0] rename_dispatch_state_in_invtlb_op;
            wire                                          rename_dispatch_state_in_is_inst_tlbsrch;
            wire                                          rename_dispatch_state_in_is_inst_tlbrd;
            wire                                          rename_dispatch_state_in_is_inst_tlbwr;
            wire                                          rename_dispatch_state_in_is_inst_tlbfill;
            wire                                          rename_dispatch_state_in_is_inst_invtlb;

            wire                                          rename_dispatch_state_in_is_tlbr;
            wire                                          rename_dispatch_state_in_is_inst_tlbr;
            wire                                          rename_dispatch_state_in_is_inst_pif;
            wire                                          rename_dispatch_state_in_is_inst_ppi;
            wire rename_dispatch_state_in_wb_refetch;
            wire rename_dispatch_state_in_is_cacop;

            wire                                          rename_dispatch_state_out_is_exception;
            wire                                          rename_dispatch_state_out_is_sys;
            wire                                          rename_dispatch_state_out_is_int;
            wire                                          rename_dispatch_state_out_ertn_flush;
            wire [                                  13:0] rename_dispatch_state_out_csr_addr;
            wire                                          rename_dispatch_state_out_csr_we;
            wire                                          rename_dispatch_state_out_csr_re;
            wire                                          rename_dispatch_state_out_sel_csr_wmask;

            wire                                          rename_dispatch_state_out_is_adef;
            wire                                          rename_dispatch_state_out_is_ine;
            wire                                          rename_dispatch_state_out_is_brk;
            wire rename_dispatch_state_out_wb_refetch;
            wire rename_dispatch_state_out_is_cacop;

            // wire        rename_dispatch_state_out_tlb_we;
            wire [                                   4:0] rename_dispatch_state_out_invtlb_op;
            wire                                          rename_dispatch_state_out_is_inst_tlbsrch;
            wire                                          rename_dispatch_state_out_is_inst_tlbrd;
            wire                                          rename_dispatch_state_out_is_inst_tlbwr;
            wire                                          rename_dispatch_state_out_is_inst_tlbfill;
            wire                                          rename_dispatch_state_out_is_inst_invtlb;

            wire                                          rename_dispatch_state_out_is_tlbr;
            wire                                          rename_dispatch_state_out_is_inst_tlbr;
            wire                                          rename_dispatch_state_out_is_inst_pif;
            wire                                          rename_dispatch_state_out_is_inst_ppi;


            wire                                          dispatch_clear;
            wire                                          rename_dispatch_reg_stall;
            wire                                          rename_dispatch_reg_pre_stall;

            wire                                          rename_dispatch_reg_in_valid;
            wire [                                  31:0] rename_dispatch_reg_in_pc;
            wire [                                  31:0] rename_dispatch_reg_in_instruction;
            wire [                                   6:0] rename_dispatch_reg_in_phy_reg_src1;
            wire [                                   6:0] rename_dispatch_reg_in_phy_reg_src2;
            wire                                          rename_dispatch_reg_in_phy_reg_src1_rdy;
            wire                                          rename_dispatch_reg_in_phy_reg_src2_rdy;
            wire [                                   4:0] rename_dispatch_reg_in_regfile_waddr;
            wire [                                   6:0] rename_dispatch_reg_in_old_phy_reg_dst;
            wire [                                   6:0] rename_dispatch_reg_in_new_phy_reg_dst;
            wire                                          rename_dispatch_reg_in_regfile_we;
            wire [                                   1:0] rename_dispatch_reg_in_sel_npc;
            wire [                                   4:0] rename_dispatch_reg_in_alu_op;
            wire [                                   2:0] rename_dispatch_reg_in_comparator_op;
            wire [                                   2:0] rename_dispatch_reg_in_sel_issue_queue;
            wire                                          rename_dispatch_reg_in_sel_imm;
            wire [                                  31:0] rename_dispatch_reg_in_extended_imm;
            wire [                                   4:0] rename_dispatch_reg_in_bid;
            wire [                                   6:0] rename_dispatch_reg_in_md_op;
            wire [                                   2:0] rename_dispatch_reg_in_sel_load_store_len;

            wire                                          rename_dispatch_reg_out_valid;
            wire [                                  31:0] rename_dispatch_reg_out_pc;
            wire [                                  31:0] rename_dispatch_reg_out_instruction;
            wire [                                   6:0] rename_dispatch_reg_out_phy_reg_src1;
            wire [                                   6:0] rename_dispatch_reg_out_phy_reg_src2;
            wire                                          rename_dispatch_reg_out_phy_reg_src1_rdy;
            wire                                          rename_dispatch_reg_out_phy_reg_src2_rdy;
            wire [                                   4:0] rename_dispatch_reg_out_regfile_waddr;
            wire [                                   6:0] rename_dispatch_reg_out_old_phy_reg_dst;
            wire [                                   6:0] rename_dispatch_reg_out_new_phy_reg_dst;
            wire                                          rename_dispatch_reg_out_regfile_we;
            wire [                                   1:0] rename_dispatch_reg_out_sel_npc;
            wire [                                   4:0] rename_dispatch_reg_out_alu_op;
            wire [                                   2:0] rename_dispatch_reg_out_comparator_op;
            wire [                                   2:0] rename_dispatch_reg_out_sel_issue_queue;
            wire                                          rename_dispatch_reg_out_sel_imm;
            wire [                                  31:0] rename_dispatch_reg_out_extended_imm;
            wire [                                   4:0] rename_dispatch_reg_out_bid;
            wire [                                   6:0] rename_dispatch_reg_out_md_op;
            wire [                                   2:0] rename_dispatch_reg_out_sel_load_store_len;



            wire                                          rename_dispatch_reg_update_phy_reg_src1_rdy;
            wire                                          rename_dispatch_reg_update_phy_reg_src2_rdy;



            wire                                          issue_clear;
            wire                                          issue_queue_stall;
            wire                                          issue_queue_extra_stall;
            wire                                          alu_issue_queue_flush;

            wire                                          alu_issue_queue_dispatch_valid;
            wire                                          alu_issue_queue_dispatch_ready;
            wire [             `ISSUE_QUEUE_OP_WIDTH-1:0] alu_issue_queue_dispatch_opcode;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_dispatch_pdest;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_dispatch_psrc0;
            wire                                          alu_issue_queue_dispatch_prdy0;
            wire [            `ISSUE_QUEUE_TAG_WIDTH-1:0] alu_issue_queue_dispatch_psrc1;
            wire                                          alu_issue_queue_dispatch_prdy1;
            wire [            `ISSUE_QUEUE_IMM_WIDTH-1:0] alu_issue_queue_dispatch_imm;
            wire [                                   4:0] alu_issue_queue_dispatch_bid;
            wire [                   `ROB_ID_WIDTH-1 : 0] alu_issue_queue_dispatch_rob_id;

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
            wire                                          lsu_issue_queue_dispatch_valid;
            wire                                          lsu_issue_queue_dispatch_ready;
            wire [         `LSU_ISSUE_QUEUE_OP_WIDTH-1:0] lsu_issue_queue_dispatch_opcode;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_dispatch_pdest;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_dispatch_psrc0;
            wire                                          lsu_issue_queue_dispatch_prdy0;
            wire [        `LSU_ISSUE_QUEUE_TAG_WIDTH-1:0] lsu_issue_queue_dispatch_psrc1;
            wire                                          lsu_issue_queue_dispatch_prdy1;
            wire [        `LSU_ISSUE_QUEUE_IMM_WIDTH-1:0] lsu_issue_queue_dispatch_imm;
            wire [                     `ROB_ID_WIDTH-1:0] lsu_issue_queue_dispatch_rob_id;

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

            wire                                          rename_dispatch_reg_out_is_store_or_not_load;

            wire [                                   4:0] lsu_issue_queue_dispatch_bid;
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
            wire [                                  31:0] lsu_read_exec_reg_out_phy_reg_rdata1;
            wire [                                  31:0] lsu_read_exec_reg_out_phy_reg_rdata2;
            wire [                                   6:0] lsu_read_exec_reg_out_phy_reg_dst;
            wire [                                  31:0] lsu_read_exec_reg_out_extended_imm;
            wire                                          lsu_read_exec_reg_out_is_store_or_not_load;
            wire [                   `ROB_ID_WIDTH-1 : 0] lsu_read_exec_reg_out_rob_id;
            wire [                                   4:0] lsu_read_exec_reg_out_bid;
            wire [                                   2:0] lsu_read_exec_reg_out_sel_load_store_len;
            wire lsu_read_exec_reg_out_is_cacop;


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
            wire [                                   4:0] lsu_exec_mem1_reg_out_bid;
            wire                                          lsu_exec_mem1_reg_out_store_ctrl;
            wire [31:0] lsu_exec_mem1_reg_out_address_pa;
            wire lsu_exec_mem1_reg_out_is_cacop;




            wire [                                   4:0] store_buffer_store_bid;
            wire                                          store_buffer_predict_flush;
            wire [                                   4:0] store_buffer_predict_flush_bid;
            wire [                                   4:0] store_buffer_head_bid;

            wire                                          store_buffer_store_valid;
            wire                                          store_buffer_store_ready;
            wire [                                   3:0] store_buffer_store_wstrb;
            wire [                                  31:0] store_buffer_store_address;
            wire [                                  31:0] store_buffer_store_data;
            wire [                                   1:0] store_buffer_store_mat;
            wire [31:0] store_buffer_store_address_pa;

            wire [                                  31:0] store_buffer_load_address;
            wire [                                   3:0] store_buffer_load_wstrb;
            wire [                                  31:0] store_buffer_load_data;
            wire [                                   1:0] store_buffer_load_mat;
            wire [31:0] store_buffer_load_address_pa;

            wire                                          store_buffer_commit_valid;
            wire [                                  31:0] store_buffer_commit_address;
            wire [                                  31:0] store_buffer_commit_data;
            wire [                                   3:0] store_buffer_commit_wstrb;
            wire [                                   1:0] store_buffer_commit_mat;
            wire [31:0] store_buffer_commit_address_pa;
            wire                                          store_buffer_flush;
            wire                                          store_buffer_suc;

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

            wire                                          md_issue_queue_dispatch_valid;
            wire                                          md_issue_queue_dispatch_ready;
            wire [          `MD_ISSUE_QUEUE_OP_WIDTH-1:0] md_issue_queue_dispatch_opcode;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_dispatch_pdest;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_dispatch_psrc0;
            wire                                          md_issue_queue_dispatch_prdy0;
            wire [         `MD_ISSUE_QUEUE_TAG_WIDTH-1:0] md_issue_queue_dispatch_psrc1;
            wire                                          md_issue_queue_dispatch_prdy1;
            wire [                                   4:0] md_issue_queue_dispatch_bid;
            wire [                     `ROB_ID_WIDTH-1:0] md_issue_queue_dispatch_rob_id;
            wire [                                   2:0] md_issue_queue_dispatch_inst_type;

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
            wire                                          fast_issue_queue_dispatch_valid;
            wire                                          fast_issue_queue_dispatch_ready;
            wire [        `FAST_ISSUE_QUEUE_OP_WIDTH-1:0] fast_issue_queue_dispatch_opcode;
            wire [       `FAST_ISSUE_QUEUE_TAG_WIDTH-1:0] fast_issue_queue_dispatch_pdest;
            wire [       `FAST_ISSUE_QUEUE_IMM_WIDTH-1:0] fast_issue_queue_dispatch_imm;
            wire [                                   4:0] fast_issue_queue_dispatch_bid;
            wire [                     `ROB_ID_WIDTH-1:0] fast_issue_queue_dispatch_rob_id;

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
            wire                                          privilege_issue_queue_dispatch_valid;
            wire                                          privilege_issue_queue_dispatch_ready;
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

            wire                                          bypass2_valid;
            wire [                                   6:0] bypass2_dst;

            wire                                          bypass3_valid;
            wire [                                   6:0] bypass3_dst;

            wire                                          bypass4_valid;
            wire [                                   6:0] bypass4_dst;

            wire                                          bypass5_valid;
            wire [                                   6:0] bypass5_dst;


            wire                                          bypass6_valid;
            wire [                                   6:0] bypass6_dst;


            wire                                          bypass7_valid;
            wire [                                   6:0] bypass7_dst;



            wire [                                   5:0] physical_regfile_raddr1;
            wire [                                   5:0] physical_regfile_raddr2;
            wire [                                   5:0] physical_regfile_raddr3;
            wire [                                   5:0] physical_regfile_raddr4;
            wire [                                   5:0] physical_regfile_raddr5;
            wire [                                   5:0] physical_regfile_raddr6;
            wire [                                   5:0] physical_regfile_raddr7;
            wire [                                   5:0] physical_regfile_raddr8;
            wire [                                   5:0] physical_regfile_raddr9;
            wire [                                   5:0] physical_regfile_raddr10;
            wire [                                   5:0] physical_regfile_raddr11;
            wire [                                   5:0] physical_regfile_raddr12;

            wire [                                   5:0] physical_regfile_waddr1;
            wire                                          physical_regfile_we1;
            wire [                                  31:0] physical_regfile_wdata1;

            wire [                                   5:0] physical_regfile_waddr2;
            wire                                          physical_regfile_we2;
            wire [                                  31:0] physical_regfile_wdata2;

            wire [                                   5:0] physical_regfile_waddr3;
            wire                                          physical_regfile_we3;
            wire [                                  31:0] physical_regfile_wdata3;

            wire [                                   5:0] physical_regfile_waddr4;
            wire                                          physical_regfile_we4;
            wire [                                  31:0] physical_regfile_wdata4;

            wire [                                   5:0] physical_regfile_waddr5;
            wire                                          physical_regfile_we5;
            wire [                                  31:0] physical_regfile_wdata5;

            wire [                                   5:0] physical_regfile_waddr6;
            wire                                          physical_regfile_we6;
            wire [                                  31:0] physical_regfile_wdata6;

            wire [                                   5:0] physical_regfile_waddr7;
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




            wire [                                   4:0] rob_alloc_bid;
            wire [                                   4:0] rob_predict_flush_bid;
            wire [                                   4:0] rob_head_bid;

            wire                                          rob_flush;

            wire                                          rob_alloc_valid;
            wire                                          rob_alloc_ready;
            wire [                     `ROB_ID_WIDTH-1:0] rob_alloc_rob_id;
            wire [                     `ROB_PC_WIDTH-1:0] rob_alloc_pc;
            wire [                                  31:0] rob_alloc_instruction;
            wire [                   `ROB_ARCH_WIDTH-1:0] rob_alloc_arch_dest;
            wire [                    `ROB_PHY_WIDTH-1:0] rob_alloc_new_pdest;
            wire [                    `ROB_PHY_WIDTH-1:0] rob_alloc_old_pdest;
            wire                                          rob_alloc_regfile_we;
            wire [                                   2:0] rob_alloc_inst_type;
            wire [               `ROB_ISSUE_OP_WIDTH-1:0] rob_alloc_issue_op;
            wire                                          rob_alloc_is_exception;

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

            wire                                          rob_commit_valid;
            wire                                          rob_commit_ready;
            wire                                          rob_commit_fire;
            wire [                     `ROB_ID_WIDTH-1:0] rob_commit_rob_id;
            wire [                     `ROB_PC_WIDTH-1:0] rob_commit_pc;
            wire [                                  31:0] rob_commit_instruction;
            wire [                   `ROB_ARCH_WIDTH-1:0] rob_commit_arch_dest;
            wire [                    `ROB_PHY_WIDTH-1:0] rob_commit_new_pdest;
            wire [                    `ROB_PHY_WIDTH-1:0] rob_commit_old_pdest;
            wire                                          rob_commit_regfile_we;
            wire [                                  31:0] rob_commit_value;
            wire [                                   2:0] rob_commit_inst_type;
            wire [               `ROB_ISSUE_OP_WIDTH-1:0] rob_commit_issue_op;
            wire [           `ROB_WRITEBACK_OP_WIDTH-1:0] rob_commit_writeback_op;
            wire                                          rob_commit_is_exception;

            wire                                          rob_commit_ertn_flush;
            wire                                          rob_commit_is_sys;
            wire                                          rob_commit_is_int;
            wire                                          rob_commit_is_adef;
            wire                                          rob_commit_is_ine;
            wire                                          rob_commit_is_brk;
            wire                                          rob_commit_is_tlbr;
            wire                                          rob_commit_is_inst_tlbr;
            wire                                          rob_commit_is_inst_pif;
            wire                                          rob_commit_is_inst_ppi;


            wire                                          rob_commit_is_ale;
            wire                                          rob_commit_is_data_tlbr;
            wire                                          rob_commit_is_data_pil;
            wire                                          rob_commit_is_data_pis;
            wire                                          rob_commit_is_data_ppi;
            wire                                          rob_commit_is_data_pme;


            wire                                          rob_commit_is_issue_tlbr;
            wire                                          rob_commit_is_writeback_tlbr;

            wire rob_commit_wb_refetch;
            wire rob_commit_is_cacop;
            wire [                                  31:0] rob_commit_vaddr;



            wire                                          rob_complete_conflict;
            wire [                     `ROB_ID_WIDTH-1:0] rob_head;
            wire                                          rob_full;
            wire                                          rob_empty;
            wire [                  `ROB_COUNT_WIDTH-1:0] rob_count;

            wire [                                  31:0] rob_commit_target_address;
            wire                                          rob_commit_is_jump;


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

            assign cache_subsystem_if1_valid   = pc_reg_out_valid && !pc_state_out_is_exception;
            assign cache_subsystem_if1_va      = pc_reg_pc;

            assign cache_subsystem_if2_valid   = if_insfifo_reg_out_valid && !if_insfifo_state_out_is_exception;
            assign cache_subsystem_if2_va      = if_insfifo_reg_out_pc;
            assign cache_subsystem_if2_pa      = if_insfifo_reg_out_pc_pa;
            assign cache_subsystem_if2_mat     = if_insfifo_state_out_mmu_inst_mat;


            assign cache_subsystem_mem1_valid  = sel_store_commit ? 1'b1 : lsu_exec_mem1_reg_out_valid && !lsu_exec_mem1_state_out_is_exception;
            assign cache_subsystem_mem1_va     = sel_store_commit ? store_buffer_commit_address : lsu_exec_mem1_reg_out_address;

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
            assign cache_subsystem_cacop_code  = rob_commit_arch_dest;
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
                                .if2_rdata       (cache_subsystem_if2_rdata),
                                .if2_refill_valid(cache_subsystem_if2_refill_valid),
                                .if2_refill_rdata(cache_subsystem_if2_refill_rdata),
                                .icache_busy     (cache_subsystem_icache_busy),

                                .mem1_valid(cache_subsystem_mem1_valid),
                                .mem1_va   (cache_subsystem_mem1_va),
                                .mem1_ready(cache_subsystem_mem1_ready),

                                .mem2_valid(cache_subsystem_mem2_valid),
                                .mem2_postable_store(cache_subsystem_mem2_postable_store),
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
            assign inst_sram_rdata   = cache_subsystem_if2_hit ? cache_subsystem_if2_rdata : cache_subsystem_if2_refill_valid ? cache_subsystem_if2_refill_rdata : inst_stall_buffer_out_data;


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

            stall_buffer u_inst_stall_buffer (
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


            wire  [31:0]      branch_predictor_pc;
            wire              branch_predictor_update;
            wire  [31:0]      branch_predictor_branch_pc;
            wire              branch_predictor_actual_taken;
            wire  [31:0]      branch_predictor_actual_target;
            wire              branch_predictor_is_taken;
            wire [31:0]       branch_predictor_target_address;
            assign branch_predictor_pc = pc_reg_pc;
            assign branch_predictor_update =  md_bru_writeback_reg_out_valid&&md_bru_writeback_reg_out_sel_npc == `SEL_NPC_BRANCH;
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
                                 .target_address(branch_predictor_target_address)
                             );




            assign inst_sram_en = 1'b1;
            assign data_sram_en = 1'b1;

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



            assign pc_reg_in_valid = global_valid;
            // assign pc_reg_stall    = 1'b0;
            assign pc_reg_npc      = global_flush ? flush_target_address : predict_flush ? md_bru_writeback_reg_out_target_address : b_flush ? id_allocbid_reg_out_target_b : branch_predictor_target_address;

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


            wire [31:0] if_insfifo_reg_in_predict_target_address;

            wire [31:0] if_insfifo_reg_out_predict_target_address;

            assign if_insfifo_reg_in_valid  = pc_reg_out_valid && !if1_clear;
            assign if_insfifo_reg_pre_stall = pc_reg_stall;
            assign if_insfifo_reg_in_pc     = pc_reg_pc;
            assign if_insfifo_reg_in_predict_target_address = branch_predictor_target_address;


            assign if_insfifo_reg_in_pc_pa = mmu_inst_pa;

            if_insfifo_reg u_if_insfifo_reg (
                               .clk   (clk),
                               .resetn(resetn),

                               .stall    (if_insfifo_reg_stall),
                               .pre_stall(if_insfifo_reg_pre_stall),

                               .in_valid(if_insfifo_reg_in_valid),
                               .in_pc   (if_insfifo_reg_in_pc),
                               .in_pc_pa(if_insfifo_reg_in_pc_pa),
                               .in_predict_target_address(if_insfifo_reg_in_predict_target_address),

                               .out_valid(if_insfifo_reg_out_valid),
                               .out_pc   (if_insfifo_reg_out_pc),
                               .out_pc_pa(if_insfifo_reg_out_pc_pa),
                               .out_predict_target_address(if_insfifo_reg_out_predict_target_address)
                           );



            // assign instruction_buffer_in_instrucion = inst_stall_buffer_out_data;  //*****
            // assign instruction_buffer_stall         = if_insfifo_reg_stall;

            // instruction_buffer u_instruction_buffer (
            //     .clk   (clk),
            //     .resetn(resetn),

            //     .in_instruction(instruction_buffer_in_instrucion),
            //     .stall         (instruction_buffer_stall),

            //     .out_instruction(instruction_buffer_out_instruction),
            //     .sel            (instruction_buffer_sel)

            // );





            assign inst_fifo_clear    = id_clear;
            assign inst_fifo_in_valid = if_insfifo_reg_out_valid && !if2_clear && !if_insfifo_reg_stall;
            assign inst_fifo_in_data  = {
                       if_insfifo_reg_out_pc,
                       inst_sram_rdata,
                       if_insfifo_state_out_is_exception,
                       if_insfifo_state_out_is_adef,
                       if_insfifo_state_out_is_tlbr,
                       if_insfifo_state_out_is_inst_tlbr,
                       if_insfifo_state_out_is_inst_pif,
                       if_insfifo_state_out_is_inst_ppi,
                       if_insfifo_reg_out_predict_target_address
                   };

            ins_fifo_mp u_inst_fifo (
                            .clk   (clk),
                            .resetn(resetn),

                            .clear   (inst_fifo_clear),
                            .in_valid(inst_fifo_in_valid),
                            .wr_ready(inst_fifo_wr_ready),
                            .in_data (inst_fifo_in_data),

                            .stall    (inst_fifo_stall),
                            .out_valid(inst_fifo_out_valid),
                            .out_data (inst_fifo_out_data),

                            .count(inst_fifo_count),
                            .avail(inst_fifo_avail)
                        );

            wire [31:0] inst_fifo_predict_target_address;

            assign {
                    inst_fifo_pc,
                    inst_fifo_instruction,
                    insfifo_is_exception,
                    insfifo_is_adef,
                    insfifo_is_tlbr,
                    insfifo_is_inst_tlbr,
                    insfifo_is_inst_pif,
                    insfifo_is_inst_ppi,
                    inst_fifo_predict_target_address
                } = inst_fifo_out_data;

            assign inst_fifo_valid                                                                                                                                               = inst_fifo_out_valid;


            assign decode_instruction                                                                                                                                            = inst_fifo_instruction;

            wire [4:0] decode_invtlb_op;


            wire       decode_is_inst_tlbsrch;
            wire       decode_is_inst_tlbrd;
            wire       decode_is_inst_tlbwr;
            wire       decode_is_inst_tlbfill;
            wire       decode_is_inst_invtlb;

            wire       decode_wb_refetch;

            wire       decode_is_cacop;

            wire decode_csr_3w;
            wire decode_is_CNTinst;
            wire [7:0] decode_load_valid;
            wire [7:0] decode_store_valid;

            wire decode_is_idle;
            wire decode_is_ll_w;
            wire decode_is_sc_w;
            wire decode_is_dbar;

            decode u_decode (
                       .instruction   (decode_instruction),
                       .regfile_raddr1(decode_regfile_raddr1),
                       .regfile_raddr2(decode_regfile_raddr2),
                       .regfile_we    (decode_regfile_we),
                       .regfile_waddr (decode_regfile_waddr),

                       .sel_npc           (decode_sel_npc),
                       .alu_op            (decode_alu_op),
                       .comparator_op     (decode_comparator_op),
                       .sel_issue_queue   (decode_sel_issue_queue),
                       .sel_imm           (decode_sel_imm),
                       .ext_simm          (decode_ext_simm),
                       .sel_lui12         (decode_sel_lui12),
                       .md_op             (decode_md_op),
                       .sel_load_store_len(decode_sel_load_store_len),
                       .sel_pre_result    (decode_sel_pre_result),

                       .csr_addr      (decode_csr_addr),
                       .csr_we        (decode_csr_we),
                       .csr_re        (decode_csr_re),
                       .sel_csr_wmask (decode_sel_csr_wmask),
                       .csr_ertn_flush(decode_csr_ertn_flush),
                       .is_sys        (decode_is_sys),
                       .is_brk        (decode_is_brk),
                       .is_ine        (decode_is_ine),

                       .invtlb_op      (decode_invtlb_op),
                       .is_inst_tlbsrch(decode_is_inst_tlbsrch),
                       .is_inst_tlbrd  (decode_is_inst_tlbrd),
                       .is_inst_tlbwr  (decode_is_inst_tlbwr),
                       .is_inst_tlbfill(decode_is_inst_tlbfill),
                       .is_inst_invtlb (decode_is_inst_invtlb),

                       .wb_refetch(decode_wb_refetch),

                       .is_cacop(decode_is_cacop),

                       .csr_3w(decode_csr_3w),
                       .is_CNTinst(decode_is_CNTinst),
                       .load_valid(decode_load_valid),
                       .store_valid(decode_store_valid),

                       .is_idle(decode_is_idle),
                       .is_ll_w(decode_is_ll_w),
                       .is_sc_w(decode_is_sc_w),
                       .is_dbar(decode_is_dbar)
                   );

            assign is_sys           = decode_is_sys;
            assign is_brk           = decode_is_brk;
            assign is_ine           = decode_is_ine;
            assign is_int           = csr_regfile_has_int;




            assign id_pre_result[0] = ext_extended_imm;
            assign id_pre_result[1] = inst_fifo_pc + 32'd4;
            assign id_pre_result[2] = {inst_fifo_instruction[24:5], 12'b0};
            assign id_pre_result[3] = inst_fifo_pc + {inst_fifo_instruction[24:5], 12'b0};
            assign id_pre_result[4] = rdcnt[63:32];
            assign id_pre_result[5] = rdcnt[31:0];
            assign id_pre_result[6] = {{16{inst_fifo_instruction[23]}},inst_fifo_instruction[23:10], 2'b00};



            assign ext_instruction  = inst_fifo_instruction;
            assign ext_simm         = decode_ext_simm;

            ext u_ext (
                    .instruction (ext_instruction),
                    .simm        (ext_simm),
                    .extended_imm(ext_extended_imm),
                    .offset16    (ext_offset16),
                    .offset26    (ext_offset26)
                );



            assign id_allocbid_state_in_is_exception    = insfifo_is_exception || is_sys || is_int || is_ine || is_brk;
            assign id_allocbid_state_in_is_sys          = is_sys;
            assign id_allocbid_state_in_is_int          = is_int;
            assign id_allocbid_state_in_ertn_flush      = decode_csr_ertn_flush;
            assign id_allocbid_state_in_csr_addr        = decode_csr_addr;
            assign id_allocbid_state_in_csr_we          = decode_csr_we;
            assign id_allocbid_state_in_sel_csr_wmask   = decode_sel_csr_wmask;
            assign id_allocbid_state_in_csr_re          = decode_csr_re;

            assign id_allocbid_state_in_is_adef         = insfifo_is_adef;
            assign id_allocbid_state_in_is_ine          = is_ine;
            assign id_allocbid_state_in_is_brk          = is_brk;

            assign id_allocbid_state_in_invtlb_op       = decode_invtlb_op;
            assign id_allocbid_state_in_is_inst_tlbsrch = decode_is_inst_tlbsrch;
            assign id_allocbid_state_in_is_inst_tlbrd   = decode_is_inst_tlbrd;
            assign id_allocbid_state_in_is_inst_tlbwr   = decode_is_inst_tlbwr;
            assign id_allocbid_state_in_is_inst_tlbfill = decode_is_inst_tlbfill;
            assign id_allocbid_state_in_is_inst_invtlb  = decode_is_inst_invtlb;

            assign id_allocbid_state_in_is_tlbr         = insfifo_is_tlbr;
            assign id_allocbid_state_in_is_inst_tlbr    = insfifo_is_inst_tlbr;
            assign id_allocbid_state_in_is_inst_pif     = insfifo_is_inst_pif;
            assign id_allocbid_state_in_is_inst_ppi     = insfifo_is_inst_ppi;



            assign id_allocbid_state_in_wb_refetch = decode_wb_refetch;



            assign id_allocbid_state_in_is_cacop = decode_is_cacop;

            wire id_allocbid_state_in_is_ll_w;
            wire id_allocbid_state_in_is_sc_w;
            wire id_allocbid_state_in_is_dbar;

            wire id_allocbid_state_out_is_ll_w;
            wire id_allocbid_state_out_is_sc_w;
            wire id_allocbid_state_out_is_dbar;


            assign id_allocbid_state_in_is_ll_w = decode_is_ll_w;
            assign id_allocbid_state_in_is_sc_w = decode_is_sc_w;
            assign id_allocbid_state_in_is_dbar = decode_is_dbar;


            id_allocbid_state u_id_allocbid_state (
                                  .clk   (clk),
                                  .resetn(resetn),
                                  .stall (id_allocbid_reg_stall),

                                  .in_is_exception (id_allocbid_state_in_is_exception),
                                  .in_is_sys       (id_allocbid_state_in_is_sys),
                                  .in_is_int       (id_allocbid_state_in_is_int),
                                  .in_ertn_flush   (id_allocbid_state_in_ertn_flush),
                                  .in_csr_addr     (id_allocbid_state_in_csr_addr),
                                  .in_csr_we       (id_allocbid_state_in_csr_we),
                                  .in_csr_re       (id_allocbid_state_in_csr_re),
                                  .in_sel_csr_wmask(id_allocbid_state_in_sel_csr_wmask),

                                  .in_is_adef(id_allocbid_state_in_is_adef),
                                  .in_is_ine (id_allocbid_state_in_is_ine),
                                  .in_is_brk (id_allocbid_state_in_is_brk),

                                  // .in_tlb_we         (),
                                  .in_invtlb_op      (id_allocbid_state_in_invtlb_op),
                                  .in_is_inst_tlbsrch(id_allocbid_state_in_is_inst_tlbsrch),
                                  .in_is_inst_tlbrd  (id_allocbid_state_in_is_inst_tlbrd),
                                  .in_is_inst_tlbwr  (id_allocbid_state_in_is_inst_tlbwr),
                                  .in_is_inst_tlbfill(id_allocbid_state_in_is_inst_tlbfill),
                                  .in_is_inst_invtlb (id_allocbid_state_in_is_inst_invtlb),

                                  .in_is_tlbr     (id_allocbid_state_in_is_tlbr),
                                  .in_is_inst_tlbr(id_allocbid_state_in_is_inst_tlbr),
                                  .in_is_inst_pif (id_allocbid_state_in_is_inst_pif),
                                  .in_is_inst_ppi (id_allocbid_state_in_is_inst_ppi),

                                  .in_wb_refetch(id_allocbid_state_in_wb_refetch),

                                  .in_is_cacop(id_allocbid_state_in_is_cacop),

                                  .in_is_ll_w(id_allocbid_state_in_is_ll_w),
                                  .in_is_sc_w(id_allocbid_state_in_is_sc_w),
                                  .in_is_dbar(id_allocbid_state_in_is_dbar),

                                  .out_is_exception (id_allocbid_state_out_is_exception),
                                  .out_is_sys       (id_allocbid_state_out_is_sys),
                                  .out_is_int       (id_allocbid_state_out_is_int),
                                  .out_ertn_flush   (id_allocbid_state_out_ertn_flush),
                                  .out_csr_addr     (id_allocbid_state_out_csr_addr),
                                  .out_csr_we       (id_allocbid_state_out_csr_we),
                                  .out_csr_re       (id_allocbid_state_out_csr_re),
                                  .out_sel_csr_wmask(id_allocbid_state_out_sel_csr_wmask),

                                  .out_is_adef(id_allocbid_state_out_is_adef),
                                  .out_is_ine (id_allocbid_state_out_is_ine),
                                  .out_is_brk (id_allocbid_state_out_is_brk),

                                  // .out_tlb_we         (),
                                  .out_invtlb_op      (id_allocbid_state_out_invtlb_op),
                                  .out_is_inst_tlbsrch(id_allocbid_state_out_is_inst_tlbsrch),
                                  .out_is_inst_tlbrd  (id_allocbid_state_out_is_inst_tlbrd),
                                  .out_is_inst_tlbwr  (id_allocbid_state_out_is_inst_tlbwr),
                                  .out_is_inst_tlbfill(id_allocbid_state_out_is_inst_tlbfill),
                                  .out_is_inst_invtlb (id_allocbid_state_out_is_inst_invtlb),

                                  .out_is_tlbr     (id_allocbid_state_out_is_tlbr),
                                  .out_is_inst_tlbr(id_allocbid_state_out_is_inst_tlbr),
                                  .out_is_inst_pif (id_allocbid_state_out_is_inst_pif),
                                  .out_is_inst_ppi (id_allocbid_state_out_is_inst_ppi),

                                  .out_wb_refetch(id_allocbid_state_out_wb_refetch),

                                  .out_is_cacop(id_allocbid_state_out_is_cacop),

                                  .out_is_ll_w(id_allocbid_state_out_is_ll_w),
                                  .out_is_sc_w(id_allocbid_state_out_is_sc_w),
                                  .out_is_dbar(id_allocbid_state_out_is_dbar)
                              );


            wire [31:0] id_allocbid_reg_in_predict_target_address;
            wire id_allocbid_reg_in_is_b_jump;

            wire [31:0] id_allocbid_reg_out_predict_target_address;
            wire id_allocbid_reg_out_is_b_jump;

            assign id_allocbid_reg_pre_stall             = inst_fifo_stall;

            assign id_allocbid_reg_in_valid              = inst_fifo_valid && !id_clear;
            assign id_allocbid_reg_in_pc                 = inst_fifo_pc;
            assign id_allocbid_reg_in_instruction        = inst_fifo_instruction;
            assign id_allocbid_reg_in_regfile_raddr1     = decode_regfile_raddr1;
            assign id_allocbid_reg_in_regfile_raddr2     = decode_regfile_raddr2;
            assign id_allocbid_reg_in_regfile_we         = decode_regfile_we;
            assign id_allocbid_reg_in_regfile_waddr      = decode_regfile_waddr;
            assign id_allocbid_reg_in_sel_npc            = decode_sel_npc;
            assign id_allocbid_reg_in_alu_op             = decode_alu_op;
            assign id_allocbid_reg_in_comparator_op      = decode_comparator_op;
            assign id_allocbid_reg_in_sel_issue_queue    = decode_sel_issue_queue;
            assign id_allocbid_reg_in_sel_imm            = decode_sel_imm;
            assign id_allocbid_reg_in_extended_imm       = id_pre_result[decode_sel_pre_result];


            assign id_allocbid_reg_in_target_b           = decode_sel_npc == `SEL_NPC_B ? inst_fifo_pc + ext_offset26 : inst_fifo_pc + 32'd4;


            assign id_allocbid_reg_in_md_op              = decode_md_op;

            assign id_allocbid_reg_in_sel_load_store_len = decode_sel_load_store_len;

            assign id_allocbid_reg_in_predict_target_address = inst_fifo_predict_target_address;

            assign id_allocbid_reg_in_is_b_jump = (decode_sel_npc == `SEL_NPC_B || decode_sel_npc == `SEL_NPC_DEFAULT) && (id_allocbid_reg_in_target_b!=inst_fifo_predict_target_address);


            id_allocbid_reg u_id_allocbid_reg (
                                .clk   (clk),
                                .resetn(resetn),

                                .stall    (id_allocbid_reg_stall),
                                .pre_stall(id_allocbid_reg_pre_stall),

                                .in_valid             (id_allocbid_reg_in_valid),
                                .in_pc                (id_allocbid_reg_in_pc),
                                .in_instruction       (id_allocbid_reg_in_instruction),
                                .in_regfile_raddr1    (id_allocbid_reg_in_regfile_raddr1),
                                .in_regfile_raddr2    (id_allocbid_reg_in_regfile_raddr2),
                                .in_regfile_we        (id_allocbid_reg_in_regfile_we),
                                .in_regfile_waddr     (id_allocbid_reg_in_regfile_waddr),
                                .in_sel_npc           (id_allocbid_reg_in_sel_npc),
                                .in_alu_op            (id_allocbid_reg_in_alu_op),
                                .in_comparator_op     (id_allocbid_reg_in_comparator_op),
                                .in_sel_issue_queue   (id_allocbid_reg_in_sel_issue_queue),
                                .in_sel_imm           (id_allocbid_reg_in_sel_imm),
                                .in_extended_imm      (id_allocbid_reg_in_extended_imm),
                                .in_target_b          (id_allocbid_reg_in_target_b),
                                .in_md_op             (id_allocbid_reg_in_md_op),
                                .in_sel_load_store_len(id_allocbid_reg_in_sel_load_store_len),
                                .in_predict_target_address(id_allocbid_reg_in_predict_target_address),
                                .in_is_b_jump(id_allocbid_reg_in_is_b_jump),

                                .out_valid             (id_allocbid_reg_out_valid),
                                .out_pc                (id_allocbid_reg_out_pc),
                                .out_instruction       (id_allocbid_reg_out_instruction),
                                .out_regfile_raddr1    (id_allocbid_reg_out_regfile_raddr1),
                                .out_regfile_raddr2    (id_allocbid_reg_out_regfile_raddr2),
                                .out_regfile_we        (id_allocbid_reg_out_regfile_we),
                                .out_regfile_waddr     (id_allocbid_reg_out_regfile_waddr),
                                .out_sel_npc           (id_allocbid_reg_out_sel_npc),
                                .out_alu_op            (id_allocbid_reg_out_alu_op),
                                .out_comparator_op     (id_allocbid_reg_out_comparator_op),
                                .out_sel_issue_queue   (id_allocbid_reg_out_sel_issue_queue),
                                .out_sel_imm           (id_allocbid_reg_out_sel_imm),
                                .out_extended_imm      (id_allocbid_reg_out_extended_imm),
                                .out_target_b          (id_allocbid_reg_out_target_b),
                                .out_md_op             (id_allocbid_reg_out_md_op),
                                .out_sel_load_store_len(id_allocbid_reg_out_sel_load_store_len),
                                .out_predict_target_address(id_allocbid_reg_out_predict_target_address),
                                .out_is_b_jump(id_allocbid_reg_out_is_b_jump)
                            );





            assign branch_id_allocator_alloc_pc             = id_allocbid_reg_out_pc;
            assign branch_id_allocator_alloc_target_address = id_allocbid_reg_out_predict_target_address;
            assign branch_id_allocator_alloc_imm            = id_allocbid_reg_out_extended_imm;
            assign branch_id_allocator_alloc_bid_valid      = id_allocbid_reg_out_valid && (id_allocbid_reg_out_sel_npc == `SEL_NPC_BRANCH || id_allocbid_reg_out_sel_npc == `SEL_NPC_JIRL) && !allocbid_buffer_alloc_already;

            assign branch_id_allocator_commit_branch_valid  = rob_commit_valid && rob_commit_ready && rob_commit_inst_type == `SEL_ISSUE_QUEUE_BRQ;

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

                                    .commit_branch_valid(branch_id_allocator_commit_branch_valid),

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





            assign allocbid_buffer_alloc_valid = branch_id_allocator_alloc_bid_valid && branch_id_allocator_alloc_bid_ready;
            assign allocbid_buffer_alloc_bid   = branch_id_allocator_alloc_bid;


            allocbid_buffer u_allocbid_buffer (
                                .clk   (clk),
                                .resetn(resetn),

                                .stall(id_allocbid_reg_stall),

                                .alloc_valid     (allocbid_buffer_alloc_valid),
                                .alloc_bid       (allocbid_buffer_alloc_bid),
                                .alloc_already   (allocbid_buffer_alloc_already),
                                .update_alloc_bid(allocbid_buffer_update_alloc_bid)
                            );










            assign allocbid_rename_state_in_is_exception    = id_allocbid_state_out_is_exception;
            assign allocbid_rename_state_in_is_sys          = id_allocbid_state_out_is_sys;
            assign allocbid_rename_state_in_is_int          = id_allocbid_state_out_is_int;
            assign allocbid_rename_state_in_ertn_flush      = id_allocbid_state_out_ertn_flush;
            assign allocbid_rename_state_in_csr_addr        = id_allocbid_state_out_csr_addr;
            assign allocbid_rename_state_in_csr_we          = id_allocbid_state_out_csr_we;
            assign allocbid_rename_state_in_csr_re          = id_allocbid_state_out_csr_re;
            assign allocbid_rename_state_in_sel_csr_wmask   = id_allocbid_state_out_sel_csr_wmask;



            assign allocbid_rename_state_in_is_adef         = id_allocbid_state_out_is_adef;
            assign allocbid_rename_state_in_is_ine          = id_allocbid_state_out_is_ine;
            assign allocbid_rename_state_in_is_brk          = id_allocbid_state_out_is_brk;

            assign allocbid_rename_state_in_invtlb_op       = id_allocbid_state_out_invtlb_op;
            assign allocbid_rename_state_in_is_inst_tlbsrch = id_allocbid_state_out_is_inst_tlbsrch;
            assign allocbid_rename_state_in_is_inst_tlbrd   = id_allocbid_state_out_is_inst_tlbrd;
            assign allocbid_rename_state_in_is_inst_tlbwr   = id_allocbid_state_out_is_inst_tlbwr;
            assign allocbid_rename_state_in_is_inst_tlbfill = id_allocbid_state_out_is_inst_tlbfill;
            assign allocbid_rename_state_in_is_inst_invtlb  = id_allocbid_state_out_is_inst_invtlb;

            assign allocbid_rename_state_in_is_tlbr         = id_allocbid_state_out_is_tlbr;
            assign allocbid_rename_state_in_is_inst_tlbr    = id_allocbid_state_out_is_inst_tlbr;
            assign allocbid_rename_state_in_is_inst_pif     = id_allocbid_state_out_is_inst_pif;
            assign allocbid_rename_state_in_is_inst_ppi     = id_allocbid_state_out_is_inst_ppi;



            assign allocbid_rename_state_in_wb_refetch = id_allocbid_state_out_wb_refetch;



            assign allocbid_rename_state_in_is_cacop = id_allocbid_state_out_is_cacop;


            wire allocbid_rename_state_in_is_ll_w;
            wire allocbid_rename_state_in_is_sc_w;
            wire allocbid_rename_state_in_is_dbar;

            wire allocbid_rename_state_out_is_ll_w;
            wire allocbid_rename_state_out_is_sc_w;
            wire allocbid_rename_state_out_is_dbar;


            assign allocbid_rename_state_in_is_ll_w = id_allocbid_state_out_is_ll_w;
            assign allocbid_rename_state_in_is_sc_w = id_allocbid_state_out_is_sc_w;
            assign allocbid_rename_state_in_is_dbar = id_allocbid_state_out_is_dbar;



            allocbid_rename_state u_allocbid_rename_state (
                                      .clk   (clk),
                                      .resetn(resetn),
                                      .stall (allocbid_rename_reg_stall),

                                      .in_is_exception (allocbid_rename_state_in_is_exception),
                                      .in_is_sys       (allocbid_rename_state_in_is_sys),
                                      .in_is_int       (allocbid_rename_state_in_is_int),
                                      .in_ertn_flush   (allocbid_rename_state_in_ertn_flush),
                                      .in_csr_addr     (allocbid_rename_state_in_csr_addr),
                                      .in_csr_we       (allocbid_rename_state_in_csr_we),
                                      .in_csr_re       (allocbid_rename_state_in_csr_re),
                                      .in_sel_csr_wmask(allocbid_rename_state_in_sel_csr_wmask),

                                      .in_is_adef(allocbid_rename_state_in_is_adef),
                                      .in_is_ine (allocbid_rename_state_in_is_ine),
                                      .in_is_brk (allocbid_rename_state_in_is_brk),

                                      // .in_tlb_we         (),
                                      .in_invtlb_op      (allocbid_rename_state_in_invtlb_op),
                                      .in_is_inst_tlbsrch(allocbid_rename_state_in_is_inst_tlbsrch),
                                      .in_is_inst_tlbrd  (allocbid_rename_state_in_is_inst_tlbrd),
                                      .in_is_inst_tlbwr  (allocbid_rename_state_in_is_inst_tlbwr),
                                      .in_is_inst_tlbfill(allocbid_rename_state_in_is_inst_tlbfill),
                                      .in_is_inst_invtlb (allocbid_rename_state_in_is_inst_invtlb),

                                      .in_is_tlbr     (allocbid_rename_state_in_is_tlbr),
                                      .in_is_inst_tlbr(allocbid_rename_state_in_is_inst_tlbr),
                                      .in_is_inst_pif (allocbid_rename_state_in_is_inst_pif),
                                      .in_is_inst_ppi (allocbid_rename_state_in_is_inst_ppi),

                                      .in_wb_refetch(allocbid_rename_state_in_wb_refetch),

                                      .in_is_cacop(allocbid_rename_state_in_is_cacop),

                                      .in_is_ll_w(allocbid_rename_state_in_is_ll_w),
                                      .in_is_sc_w(allocbid_rename_state_in_is_sc_w),
                                      .in_is_dbar(allocbid_rename_state_in_is_dbar),

                                      .out_is_exception (allocbid_rename_state_out_is_exception),
                                      .out_is_sys       (allocbid_rename_state_out_is_sys),
                                      .out_is_int       (allocbid_rename_state_out_is_int),
                                      .out_ertn_flush   (allocbid_rename_state_out_ertn_flush),
                                      .out_csr_addr     (allocbid_rename_state_out_csr_addr),
                                      .out_csr_we       (allocbid_rename_state_out_csr_we),
                                      .out_csr_re       (allocbid_rename_state_out_csr_re),
                                      .out_sel_csr_wmask(allocbid_rename_state_out_sel_csr_wmask),

                                      .out_is_adef(allocbid_rename_state_out_is_adef),
                                      .out_is_ine (allocbid_rename_state_out_is_ine),
                                      .out_is_brk (allocbid_rename_state_out_is_brk),

                                      // .out_tlb_we         (),
                                      .out_invtlb_op      (allocbid_rename_state_out_invtlb_op),
                                      .out_is_inst_tlbsrch(allocbid_rename_state_out_is_inst_tlbsrch),
                                      .out_is_inst_tlbrd  (allocbid_rename_state_out_is_inst_tlbrd),
                                      .out_is_inst_tlbwr  (allocbid_rename_state_out_is_inst_tlbwr),
                                      .out_is_inst_tlbfill(allocbid_rename_state_out_is_inst_tlbfill),
                                      .out_is_inst_invtlb (allocbid_rename_state_out_is_inst_invtlb),

                                      .out_is_tlbr     (allocbid_rename_state_out_is_tlbr),
                                      .out_is_inst_tlbr(allocbid_rename_state_out_is_inst_tlbr),
                                      .out_is_inst_pif (allocbid_rename_state_out_is_inst_pif),
                                      .out_is_inst_ppi (allocbid_rename_state_out_is_inst_ppi),

                                      .out_wb_refetch(allocbid_rename_state_out_wb_refetch),

                                      .out_is_cacop(allocbid_rename_state_out_is_cacop),

                                      .out_is_ll_w(allocbid_rename_state_out_is_ll_w),
                                      .out_is_sc_w(allocbid_rename_state_out_is_sc_w),
                                      .out_is_dbar(allocbid_rename_state_out_is_dbar)
                                  );




















            assign allocbid_rename_reg_pre_stall             = id_allocbid_reg_stall;

            assign allocbid_rename_reg_in_valid              = id_allocbid_reg_out_valid && !allocbid_clear;

            assign allocbid_rename_reg_in_pc                 = id_allocbid_reg_out_pc;
            assign allocbid_rename_reg_in_instruction        = id_allocbid_reg_out_instruction;
            assign allocbid_rename_reg_in_regfile_raddr1     = id_allocbid_reg_out_regfile_raddr1;
            assign allocbid_rename_reg_in_regfile_raddr2     = id_allocbid_reg_out_regfile_raddr2;
            assign allocbid_rename_reg_in_regfile_we         = id_allocbid_reg_out_regfile_we;
            assign allocbid_rename_reg_in_regfile_waddr      = id_allocbid_reg_out_regfile_waddr;
            assign allocbid_rename_reg_in_sel_npc            = id_allocbid_reg_out_sel_npc;
            assign allocbid_rename_reg_in_alu_op             = id_allocbid_reg_out_alu_op;
            assign allocbid_rename_reg_in_comparator_op      = id_allocbid_reg_out_comparator_op;
            assign allocbid_rename_reg_in_sel_issue_queue    = id_allocbid_reg_out_sel_issue_queue;
            assign allocbid_rename_reg_in_sel_imm            = id_allocbid_reg_out_sel_imm;
            assign allocbid_rename_reg_in_extended_imm       = id_allocbid_reg_out_extended_imm;
            assign allocbid_rename_reg_in_md_op              = id_allocbid_reg_out_md_op;
            assign allocbid_rename_reg_in_sel_load_store_len = id_allocbid_reg_out_sel_load_store_len;
            assign allocbid_rename_reg_in_bid                = allocbid_buffer_alloc_already ? allocbid_buffer_update_alloc_bid : branch_id_allocator_alloc_bid;



            allocbid_rename_reg u_allocbid_rename_reg (
                                    .clk   (clk),
                                    .resetn(resetn),

                                    .stall    (allocbid_rename_reg_stall),
                                    .pre_stall(allocbid_rename_reg_pre_stall),

                                    .in_valid             (allocbid_rename_reg_in_valid),
                                    .in_pc                (allocbid_rename_reg_in_pc),
                                    .in_instruction       (allocbid_rename_reg_in_instruction),
                                    .in_regfile_raddr1    (allocbid_rename_reg_in_regfile_raddr1),
                                    .in_regfile_raddr2    (allocbid_rename_reg_in_regfile_raddr2),
                                    .in_regfile_we        (allocbid_rename_reg_in_regfile_we),
                                    .in_regfile_waddr     (allocbid_rename_reg_in_regfile_waddr),
                                    .in_sel_npc           (allocbid_rename_reg_in_sel_npc),
                                    .in_alu_op            (allocbid_rename_reg_in_alu_op),
                                    .in_comparator_op     (allocbid_rename_reg_in_comparator_op),
                                    .in_sel_issue_queue   (allocbid_rename_reg_in_sel_issue_queue),
                                    .in_sel_imm           (allocbid_rename_reg_in_sel_imm),
                                    .in_extended_imm      (allocbid_rename_reg_in_extended_imm),
                                    .in_md_op             (allocbid_rename_reg_in_md_op),
                                    .in_sel_load_store_len(allocbid_rename_reg_in_sel_load_store_len),
                                    .in_bid               (allocbid_rename_reg_in_bid),


                                    .out_valid             (allocbid_rename_reg_out_valid),
                                    .out_pc                (allocbid_rename_reg_out_pc),
                                    .out_instruction       (allocbid_rename_reg_out_instruction),
                                    .out_regfile_raddr1    (allocbid_rename_reg_out_regfile_raddr1),
                                    .out_regfile_raddr2    (allocbid_rename_reg_out_regfile_raddr2),
                                    .out_regfile_we        (allocbid_rename_reg_out_regfile_we),
                                    .out_regfile_waddr     (allocbid_rename_reg_out_regfile_waddr),
                                    .out_sel_npc           (allocbid_rename_reg_out_sel_npc),
                                    .out_alu_op            (allocbid_rename_reg_out_alu_op),
                                    .out_comparator_op     (allocbid_rename_reg_out_comparator_op),
                                    .out_sel_issue_queue   (allocbid_rename_reg_out_sel_issue_queue),
                                    .out_sel_imm           (allocbid_rename_reg_out_sel_imm),
                                    .out_extended_imm      (allocbid_rename_reg_out_extended_imm),
                                    .out_md_op             (allocbid_rename_reg_out_md_op),
                                    .out_sel_load_store_len(allocbid_rename_reg_out_sel_load_store_len),
                                    .out_bid               (allocbid_rename_reg_out_bid)
                                );








            assign cam_rmt_arch_reg_src1             = allocbid_rename_reg_out_regfile_raddr1;
            assign cam_rmt_arch_reg_src2             = allocbid_rename_reg_out_regfile_raddr2;
            assign cam_rmt_arch_reg_dst              = allocbid_rename_reg_out_regfile_waddr;
            assign cam_rmt_rename_arch_reg_dst_valid = allocbid_rename_reg_out_regfile_we && allocbid_rename_reg_out_valid && !rename_buffer_result_rename_success;


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

            assign cam_rmt_update_commit_new_reg_dst = rob_commit_new_pdest;
            assign cam_rmt_update_commit_old_reg_dst = rob_commit_old_pdest;
            assign cam_rmt_update_commit_valid       = rob_commit_ready && !rob_commit_is_exception && rob_commit_regfile_we;  //

            assign cam_rmt_flush                     = global_flush;






            assign cam_rmt_valid_copy_valid          = allocbid_rename_reg_out_valid && (allocbid_rename_reg_out_sel_npc == `SEL_NPC_BRANCH || allocbid_rename_reg_out_sel_npc == `SEL_NPC_JIRL) && !allocbid_rename_reg_stall;
            assign cam_rmt_valid_copy_bid            = allocbid_rename_reg_out_bid;


            assign cam_rmt_predict_flush             = predict_flush;
            assign cam_rmt_predict_flush_bid         = predict_flush_bid;
            assign cam_rmt_head_bid                  = branch_id_allocator_bid_head;

`ifdef difftest

            wire [6:0] rmt [31:0];


`endif



            cam_rmt u_cam_rmt (
                        .clk   (clk),
                        .resetn(resetn),

                        .arch_reg_src1            (cam_rmt_arch_reg_src1),
                        .arch_reg_src2            (cam_rmt_arch_reg_src2),
                        .arch_reg_dst             (cam_rmt_arch_reg_dst),
                        .rename_arch_reg_dst_valid(cam_rmt_rename_arch_reg_dst_valid),
                        .valid_copy_valid         (cam_rmt_valid_copy_valid),
                        .valid_copy_bid           (cam_rmt_valid_copy_bid),

                        .phy_reg_src1    (cam_rmt_phy_reg_src1),
                        .phy_reg_src1_rdy(cam_rmt_phy_reg_src1_rdy),
                        .phy_reg_src2    (cam_rmt_phy_reg_src2),
                        .phy_reg_src2_rdy(cam_rmt_phy_reg_src2_rdy),
                        .old_phy_reg_dst (cam_rmt_old_phy_reg_dst),
                        .new_phy_reg_dst (cam_rmt_new_phy_reg_dst),
                        .rename_success  (cam_rmt_rename_success),

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

                        .update_commit_new_reg_dst(cam_rmt_update_commit_new_reg_dst),
                        .update_commit_old_reg_dst(cam_rmt_update_commit_old_reg_dst),
                        .update_commit_valid      (cam_rmt_update_commit_valid),

                        .flush(cam_rmt_flush),

                        .predict_flush    (cam_rmt_predict_flush),
                        .predict_flush_bid(cam_rmt_predict_flush_bid),
                        .head_bid         (cam_rmt_head_bid)

`ifdef difftest

                        , .armt(rmt)


`endif


                    );


            assign rename_buffer_stall = allocbid_rename_reg_stall;
            assign rename_buffer_update_rename_success = cam_rmt_rename_success;
            assign rename_buffer_update_old_phy_reg_dst = cam_rmt_old_phy_reg_dst;
            assign rename_buffer_update_new_phy_reg_dst = cam_rmt_new_phy_reg_dst;
            assign rename_buffer_update_phy_reg_src1 = cam_rmt_phy_reg_src1;
            assign rename_buffer_update_phy_reg_src1_rdy = cam_rmt_phy_reg_src1_rdy ||
                   (bypass1_valid && bypass1_dst == cam_rmt_phy_reg_src1) ||
                   (bypass2_valid && bypass2_dst == cam_rmt_phy_reg_src1) ||
                   (bypass3_valid && bypass3_dst == cam_rmt_phy_reg_src1) ||
                   (bypass4_valid && bypass4_dst == cam_rmt_phy_reg_src1) ||
                   (bypass5_valid && bypass5_dst == cam_rmt_phy_reg_src1) ||
                   (bypass6_valid && bypass6_dst == cam_rmt_phy_reg_src1) ||
                   (bypass7_valid && bypass7_dst == cam_rmt_phy_reg_src1);  //;
            assign rename_buffer_update_phy_reg_src2 = cam_rmt_phy_reg_src2;
            assign rename_buffer_update_phy_reg_src2_rdy = cam_rmt_phy_reg_src2_rdy ||
                   (bypass1_valid && bypass1_dst == cam_rmt_phy_reg_src2) ||
                   (bypass2_valid && bypass2_dst == cam_rmt_phy_reg_src2) ||
                   (bypass3_valid && bypass3_dst == cam_rmt_phy_reg_src2) ||
                   (bypass4_valid && bypass4_dst == cam_rmt_phy_reg_src2) ||
                   (bypass5_valid && bypass5_dst == cam_rmt_phy_reg_src2) ||
                   (bypass6_valid && bypass6_dst == cam_rmt_phy_reg_src2) ||
                   (bypass7_valid && bypass7_dst == cam_rmt_phy_reg_src2);  //;
            assign rename_buffer_bypass1_valid = bypass1_valid;
            assign rename_buffer_bypass1_dst = bypass1_dst;
            assign rename_buffer_bypass2_valid = bypass2_valid;
            assign rename_buffer_bypass2_dst = bypass2_dst;


            assign rename_buffer_bypass3_valid = bypass3_valid;
            assign rename_buffer_bypass3_dst = bypass3_dst;
            assign rename_buffer_bypass4_valid = bypass4_valid;
            assign rename_buffer_bypass4_dst = bypass4_dst;
            assign rename_buffer_bypass5_valid = bypass5_valid;
            assign rename_buffer_bypass5_dst = bypass5_dst;
            assign rename_buffer_bypass6_valid = bypass6_valid;
            assign rename_buffer_bypass6_dst = bypass6_dst;
            assign rename_buffer_bypass7_valid = bypass7_valid;
            assign rename_buffer_bypass7_dst = bypass7_dst;


            rename_buffer u_rename_buffer (
                              .clk   (clk),
                              .resetn(resetn),

                              .stall(rename_buffer_stall),
                              .sel  (rename_buffer_sel),

                              .update_rename_success  (rename_buffer_update_rename_success),
                              .update_old_phy_reg_dst (rename_buffer_update_old_phy_reg_dst),
                              .update_new_phy_reg_dst (rename_buffer_update_new_phy_reg_dst),
                              .update_phy_reg_src1    (rename_buffer_update_phy_reg_src1),
                              .update_phy_reg_src1_rdy(rename_buffer_update_phy_reg_src1_rdy),
                              .update_phy_reg_src2    (rename_buffer_update_phy_reg_src2),
                              .update_phy_reg_src2_rdy(rename_buffer_update_phy_reg_src2_rdy),

                              .result_rename_success  (rename_buffer_result_rename_success),
                              .result_old_phy_reg_dst (rename_buffer_result_old_phy_reg_dst),
                              .result_new_phy_reg_dst (rename_buffer_result_new_phy_reg_dst),
                              .result_phy_reg_src1    (rename_buffer_result_phy_reg_src1),
                              .result_phy_reg_src1_rdy(rename_buffer_result_phy_reg_src1_rdy),
                              .result_phy_reg_src2    (rename_buffer_result_phy_reg_src2),
                              .result_phy_reg_src2_rdy(rename_buffer_result_phy_reg_src2_rdy),

                              .bypass1_valid(rename_buffer_bypass1_valid),
                              .bypass1_dst  (rename_buffer_bypass1_dst),
                              .bypass2_valid(rename_buffer_bypass2_valid),
                              .bypass2_dst  (rename_buffer_bypass2_dst),
                              .bypass3_valid(rename_buffer_bypass3_valid),
                              .bypass3_dst  (rename_buffer_bypass3_dst),
                              .bypass4_valid(rename_buffer_bypass4_valid),
                              .bypass4_dst  (rename_buffer_bypass4_dst),
                              .bypass5_valid(rename_buffer_bypass5_valid),
                              .bypass5_dst  (rename_buffer_bypass5_dst),
                              .bypass6_valid(rename_buffer_bypass6_valid),
                              .bypass6_dst  (rename_buffer_bypass6_dst),
                              .bypass7_valid(rename_buffer_bypass7_valid),
                              .bypass7_dst  (rename_buffer_bypass7_dst)


                          );








            assign rename_dispatch_state_in_is_exception    = allocbid_rename_state_out_is_exception;
            assign rename_dispatch_state_in_is_sys          = allocbid_rename_state_out_is_sys;
            assign rename_dispatch_state_in_is_int          = allocbid_rename_state_out_is_int;
            assign rename_dispatch_state_in_ertn_flush      = allocbid_rename_state_out_ertn_flush;
            assign rename_dispatch_state_in_csr_addr        = allocbid_rename_state_out_csr_addr;
            assign rename_dispatch_state_in_csr_we          = allocbid_rename_state_out_csr_we;
            assign rename_dispatch_state_in_csr_re          = allocbid_rename_state_out_csr_re;
            assign rename_dispatch_state_in_sel_csr_wmask   = allocbid_rename_state_out_sel_csr_wmask;

            assign rename_dispatch_state_in_is_adef         = allocbid_rename_state_out_is_adef;
            assign rename_dispatch_state_in_is_ine          = allocbid_rename_state_out_is_ine;
            assign rename_dispatch_state_in_is_brk          = allocbid_rename_state_out_is_brk;

            assign rename_dispatch_state_in_invtlb_op       = allocbid_rename_state_out_invtlb_op;
            assign rename_dispatch_state_in_is_inst_tlbsrch = allocbid_rename_state_out_is_inst_tlbsrch;
            assign rename_dispatch_state_in_is_inst_tlbrd   = allocbid_rename_state_out_is_inst_tlbrd;
            assign rename_dispatch_state_in_is_inst_tlbwr   = allocbid_rename_state_out_is_inst_tlbwr;
            assign rename_dispatch_state_in_is_inst_tlbfill = allocbid_rename_state_out_is_inst_tlbfill;
            assign rename_dispatch_state_in_is_inst_invtlb  = allocbid_rename_state_out_is_inst_invtlb;

            assign rename_dispatch_state_in_is_tlbr         = allocbid_rename_state_out_is_tlbr;
            assign rename_dispatch_state_in_is_inst_tlbr    = allocbid_rename_state_out_is_inst_tlbr;
            assign rename_dispatch_state_in_is_inst_pif     = allocbid_rename_state_out_is_inst_pif;
            assign rename_dispatch_state_in_is_inst_ppi     = allocbid_rename_state_out_is_inst_ppi;


            assign rename_dispatch_state_in_wb_refetch = allocbid_rename_state_out_wb_refetch;




            assign rename_dispatch_state_in_is_cacop = allocbid_rename_state_out_is_cacop;



            wire rename_dispatch_state_in_is_ll_w;
            wire rename_dispatch_state_in_is_sc_w;
            wire rename_dispatch_state_in_is_dbar;

            wire rename_dispatch_state_out_is_ll_w;
            wire rename_dispatch_state_out_is_sc_w;
            wire rename_dispatch_state_out_is_dbar;


            assign rename_dispatch_state_in_is_ll_w = allocbid_rename_state_out_is_ll_w;
            assign rename_dispatch_state_in_is_sc_w = allocbid_rename_state_out_is_sc_w;
            assign rename_dispatch_state_in_is_dbar = allocbid_rename_state_out_is_dbar;


            rename_dispatch_state u_rename_dispatch_state (
                                      .clk   (clk),
                                      .resetn(resetn),
                                      .stall (rename_dispatch_reg_stall),

                                      .in_is_exception (rename_dispatch_state_in_is_exception),
                                      .in_is_sys       (rename_dispatch_state_in_is_sys),
                                      .in_is_int       (rename_dispatch_state_in_is_int),
                                      .in_ertn_flush   (rename_dispatch_state_in_ertn_flush),
                                      .in_csr_addr     (rename_dispatch_state_in_csr_addr),
                                      .in_csr_we       (rename_dispatch_state_in_csr_we),
                                      .in_csr_re       (rename_dispatch_state_in_csr_re),
                                      .in_sel_csr_wmask(rename_dispatch_state_in_sel_csr_wmask),

                                      .in_is_adef(rename_dispatch_state_in_is_adef),
                                      .in_is_ine (rename_dispatch_state_in_is_ine),
                                      .in_is_brk (rename_dispatch_state_in_is_brk),

                                      // .in_tlb_we         (),
                                      .in_invtlb_op      (rename_dispatch_state_in_invtlb_op),
                                      .in_is_inst_tlbsrch(rename_dispatch_state_in_is_inst_tlbsrch),
                                      .in_is_inst_tlbrd  (rename_dispatch_state_in_is_inst_tlbrd),
                                      .in_is_inst_tlbwr  (rename_dispatch_state_in_is_inst_tlbwr),
                                      .in_is_inst_tlbfill(rename_dispatch_state_in_is_inst_tlbfill),
                                      .in_is_inst_invtlb (rename_dispatch_state_in_is_inst_invtlb),

                                      .in_is_tlbr     (rename_dispatch_state_in_is_tlbr),
                                      .in_is_inst_tlbr(rename_dispatch_state_in_is_inst_tlbr),
                                      .in_is_inst_pif (rename_dispatch_state_in_is_inst_pif),
                                      .in_is_inst_ppi (rename_dispatch_state_in_is_inst_ppi),

                                      .in_wb_refetch(rename_dispatch_state_in_wb_refetch),

                                      .in_is_cacop(rename_dispatch_state_in_is_cacop),

                                      .in_is_ll_w(rename_dispatch_state_in_is_ll_w),
                                      .in_is_sc_w(rename_dispatch_state_in_is_sc_w),
                                      .in_is_dbar(rename_dispatch_state_in_is_dbar),

                                      .out_is_exception (rename_dispatch_state_out_is_exception),
                                      .out_is_sys       (rename_dispatch_state_out_is_sys),
                                      .out_is_int       (rename_dispatch_state_out_is_int),
                                      .out_ertn_flush   (rename_dispatch_state_out_ertn_flush),
                                      .out_csr_addr     (rename_dispatch_state_out_csr_addr),
                                      .out_csr_we       (rename_dispatch_state_out_csr_we),
                                      .out_csr_re       (rename_dispatch_state_out_csr_re),
                                      .out_sel_csr_wmask(rename_dispatch_state_out_sel_csr_wmask),

                                      .out_is_adef(rename_dispatch_state_out_is_adef),
                                      .out_is_ine (rename_dispatch_state_out_is_ine),
                                      .out_is_brk (rename_dispatch_state_out_is_brk),

                                      // .out_tlb_we         (),
                                      .out_invtlb_op      (rename_dispatch_state_out_invtlb_op),
                                      .out_is_inst_tlbsrch(rename_dispatch_state_out_is_inst_tlbsrch),
                                      .out_is_inst_tlbrd  (rename_dispatch_state_out_is_inst_tlbrd),
                                      .out_is_inst_tlbwr  (rename_dispatch_state_out_is_inst_tlbwr),
                                      .out_is_inst_tlbfill(rename_dispatch_state_out_is_inst_tlbfill),
                                      .out_is_inst_invtlb (rename_dispatch_state_out_is_inst_invtlb),

                                      .out_is_tlbr     (rename_dispatch_state_out_is_tlbr),
                                      .out_is_inst_tlbr(rename_dispatch_state_out_is_inst_tlbr),
                                      .out_is_inst_pif (rename_dispatch_state_out_is_inst_pif),
                                      .out_is_inst_ppi (rename_dispatch_state_out_is_inst_ppi),

                                      .out_wb_refetch(rename_dispatch_state_out_wb_refetch),

                                      .out_is_cacop(rename_dispatch_state_out_is_cacop),

                                      .out_is_ll_w(rename_dispatch_state_out_is_ll_w),
                                      .out_is_sc_w(rename_dispatch_state_out_is_sc_w),
                                      .out_is_dbar(rename_dispatch_state_out_is_dbar)
                                  );


            // assign rename_dispatch_reg_stall               = 1'b0;
            assign rename_dispatch_reg_pre_stall = allocbid_rename_reg_stall;

            assign rename_dispatch_reg_in_valid = allocbid_rename_reg_out_valid && !rename_clear;
            assign rename_dispatch_reg_in_pc = allocbid_rename_reg_out_pc;
            assign rename_dispatch_reg_in_instruction = allocbid_rename_reg_out_instruction;
            assign rename_dispatch_reg_in_phy_reg_src1 = rename_buffer_sel ? rename_buffer_result_phy_reg_src1 : cam_rmt_phy_reg_src1;
            assign rename_dispatch_reg_in_phy_reg_src2 = rename_buffer_sel ? rename_buffer_result_phy_reg_src2 : cam_rmt_phy_reg_src2;
            assign rename_dispatch_reg_in_phy_reg_src1_rdy = rename_buffer_sel ? rename_buffer_result_phy_reg_src1_rdy : rename_buffer_update_phy_reg_src1_rdy;
            assign rename_dispatch_reg_in_phy_reg_src2_rdy = rename_buffer_sel ? rename_buffer_result_phy_reg_src2_rdy : rename_buffer_update_phy_reg_src2_rdy;
            assign rename_dispatch_reg_in_regfile_waddr = allocbid_rename_reg_out_regfile_waddr;
            assign rename_dispatch_reg_in_old_phy_reg_dst = rename_buffer_sel && rename_buffer_result_rename_success ? rename_buffer_result_old_phy_reg_dst : cam_rmt_old_phy_reg_dst;
            assign rename_dispatch_reg_in_new_phy_reg_dst = rename_buffer_sel && rename_buffer_result_rename_success ? rename_buffer_result_new_phy_reg_dst : cam_rmt_new_phy_reg_dst;
            assign rename_dispatch_reg_in_regfile_we = allocbid_rename_reg_out_regfile_we;
            assign rename_dispatch_reg_in_sel_npc = allocbid_rename_reg_out_sel_npc;
            assign rename_dispatch_reg_in_alu_op = allocbid_rename_reg_out_alu_op;
            assign rename_dispatch_reg_in_comparator_op = allocbid_rename_reg_out_comparator_op;
            assign rename_dispatch_reg_in_sel_issue_queue = allocbid_rename_reg_out_sel_issue_queue;
            assign rename_dispatch_reg_in_sel_imm = allocbid_rename_reg_out_sel_imm;
            assign rename_dispatch_reg_in_extended_imm = allocbid_rename_reg_out_extended_imm;
            assign rename_dispatch_reg_in_bid = allocbid_rename_reg_out_bid;


            assign rename_dispatch_reg_in_md_op = allocbid_rename_reg_out_md_op;


            assign rename_dispatch_reg_update_phy_reg_src1_rdy = rename_dispatch_reg_out_phy_reg_src1_rdy||
                   (bypass1_valid && bypass1_dst == rename_dispatch_reg_out_phy_reg_src1) ||
                   (bypass2_valid && bypass2_dst == rename_dispatch_reg_out_phy_reg_src1) ||
                   (bypass3_valid && bypass3_dst == rename_dispatch_reg_out_phy_reg_src1) ||
                   (bypass4_valid && bypass4_dst == rename_dispatch_reg_out_phy_reg_src1) ||
                   (bypass5_valid && bypass5_dst == rename_dispatch_reg_out_phy_reg_src1) ||
                   (bypass6_valid && bypass6_dst == rename_dispatch_reg_out_phy_reg_src1) ||
                   (bypass7_valid && bypass7_dst == rename_dispatch_reg_out_phy_reg_src1);  //


            assign rename_dispatch_reg_update_phy_reg_src2_rdy = rename_dispatch_reg_out_phy_reg_src2_rdy||
                   (bypass1_valid && bypass1_dst == rename_dispatch_reg_out_phy_reg_src2) ||
                   (bypass2_valid && bypass2_dst == rename_dispatch_reg_out_phy_reg_src2) ||
                   (bypass3_valid && bypass3_dst == rename_dispatch_reg_out_phy_reg_src2) ||
                   (bypass4_valid && bypass4_dst == rename_dispatch_reg_out_phy_reg_src2) ||
                   (bypass5_valid && bypass5_dst == rename_dispatch_reg_out_phy_reg_src2) ||
                   (bypass6_valid && bypass6_dst == rename_dispatch_reg_out_phy_reg_src2) ||
                   (bypass7_valid && bypass7_dst == rename_dispatch_reg_out_phy_reg_src2);  //



            assign rename_dispatch_reg_in_sel_load_store_len = allocbid_rename_reg_out_sel_load_store_len;

            //bypass when stall
            rename_dispatch_reg u_rename_dispatch_reg (
                                    .clk   (clk),
                                    .resetn(resetn),

                                    .stall    (rename_dispatch_reg_stall),
                                    .pre_stall(rename_dispatch_reg_pre_stall),

                                    .in_valid             (rename_dispatch_reg_in_valid),
                                    .in_pc                (rename_dispatch_reg_in_pc),
                                    .in_instruction       (rename_dispatch_reg_in_instruction),
                                    .in_phy_reg_src1      (rename_dispatch_reg_in_phy_reg_src1),
                                    .in_phy_reg_src2      (rename_dispatch_reg_in_phy_reg_src2),
                                    .in_phy_reg_src1_rdy  (rename_dispatch_reg_in_phy_reg_src1_rdy),
                                    .in_phy_reg_src2_rdy  (rename_dispatch_reg_in_phy_reg_src2_rdy),
                                    .in_regfile_waddr     (rename_dispatch_reg_in_regfile_waddr),
                                    .in_old_phy_reg_dst   (rename_dispatch_reg_in_old_phy_reg_dst),
                                    .in_new_phy_reg_dst   (rename_dispatch_reg_in_new_phy_reg_dst),
                                    .in_regfile_we        (rename_dispatch_reg_in_regfile_we),
                                    .in_sel_npc           (rename_dispatch_reg_in_sel_npc),
                                    .in_alu_op            (rename_dispatch_reg_in_alu_op),
                                    .in_comparator_op     (rename_dispatch_reg_in_comparator_op),
                                    .in_sel_issue_queue   (rename_dispatch_reg_in_sel_issue_queue),
                                    .in_sel_imm           (rename_dispatch_reg_in_sel_imm),
                                    .in_extended_imm      (rename_dispatch_reg_in_extended_imm),
                                    .in_md_op             (rename_dispatch_reg_in_md_op),
                                    .in_sel_load_store_len(rename_dispatch_reg_in_sel_load_store_len),
                                    .in_bid               (rename_dispatch_reg_in_bid),

                                    .out_valid             (rename_dispatch_reg_out_valid),
                                    .out_pc                (rename_dispatch_reg_out_pc),
                                    .out_instruction       (rename_dispatch_reg_out_instruction),
                                    .out_phy_reg_src1      (rename_dispatch_reg_out_phy_reg_src1),
                                    .out_phy_reg_src2      (rename_dispatch_reg_out_phy_reg_src2),
                                    .out_phy_reg_src1_rdy  (rename_dispatch_reg_out_phy_reg_src1_rdy),
                                    .out_phy_reg_src2_rdy  (rename_dispatch_reg_out_phy_reg_src2_rdy),
                                    .out_regfile_waddr     (rename_dispatch_reg_out_regfile_waddr),
                                    .out_old_phy_reg_dst   (rename_dispatch_reg_out_old_phy_reg_dst),
                                    .out_new_phy_reg_dst   (rename_dispatch_reg_out_new_phy_reg_dst),
                                    .out_regfile_we        (rename_dispatch_reg_out_regfile_we),
                                    .out_sel_npc           (rename_dispatch_reg_out_sel_npc),
                                    .out_alu_op            (rename_dispatch_reg_out_alu_op),
                                    .out_comparator_op     (rename_dispatch_reg_out_comparator_op),
                                    .out_sel_issue_queue   (rename_dispatch_reg_out_sel_issue_queue),
                                    .out_sel_imm           (rename_dispatch_reg_out_sel_imm),
                                    .out_extended_imm      (rename_dispatch_reg_out_extended_imm),
                                    .out_md_op             (rename_dispatch_reg_out_md_op),
                                    .out_sel_load_store_len(rename_dispatch_reg_out_sel_load_store_len),
                                    .out_bid               (rename_dispatch_reg_out_bid),

                                    .update_phy_reg_src1_rdy(rename_dispatch_reg_update_phy_reg_src1_rdy),
                                    .update_phy_reg_src2_rdy(rename_dispatch_reg_update_phy_reg_src2_rdy)
                                );


            assign alu_issue_queue_flush             = issue_clear;

            assign alu_issue_queue_dispatch_valid    = rename_dispatch_reg_out_valid && !rename_dispatch_reg_stall && !rename_dispatch_state_out_is_exception && rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_INTEGER;
            assign alu_issue_queue_dispatch_opcode   = {rename_dispatch_reg_out_regfile_we, rename_dispatch_reg_out_alu_op, rename_dispatch_reg_out_sel_imm};

            assign alu_issue_queue_dispatch_pdest    = rename_dispatch_reg_out_new_phy_reg_dst;
            assign alu_issue_queue_dispatch_psrc0    = rename_dispatch_reg_out_phy_reg_src1;
            assign alu_issue_queue_dispatch_prdy0    = rename_dispatch_reg_update_phy_reg_src1_rdy;  //
            assign alu_issue_queue_dispatch_psrc1    = rename_dispatch_reg_out_phy_reg_src2;
            assign alu_issue_queue_dispatch_prdy1    = rename_dispatch_reg_update_phy_reg_src2_rdy;  //
            assign alu_issue_queue_dispatch_imm      = rename_dispatch_reg_out_extended_imm;

            assign alu_issue_queue_bypass1_valid     = bypass1_valid;
            assign alu_issue_queue_bypass1_dst       = bypass1_dst;
            assign alu_issue_queue_bypass2_valid     = bypass2_valid;
            assign alu_issue_queue_bypass2_dst       = bypass2_dst;

            assign alu_issue_queue_issue_ready       = !issue_queue_stall;
            // The privilege issue queue shares the extra ALU pipeline.  When a
            // privilege instruction at the ROB head wins the mux, do not let
            // the ALU issue queue consume (and consequently drop) its own
            // second instruction in the same cycle.
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

            assign alu_issue_queue_dispatch_bid      = rename_dispatch_reg_out_bid;

            assign alu_issue_queue_predict_flush     = predict_flush;
            assign alu_issue_queue_predict_flush_bid = predict_flush_bid;
            assign alu_issue_queue_head_bid          = branch_id_allocator_bid_head;


            assign alu_issue_queue_dispatch_rob_id   = rob_alloc_rob_id;


            alu_issue_queue u_alu_issue_queue (
                                .clk   (clk),
                                .resetn(resetn),

                                .flush(alu_issue_queue_flush),

                                .dispatch_valid (alu_issue_queue_dispatch_valid),
                                .dispatch_ready (alu_issue_queue_dispatch_ready),
                                .dispatch_opcode(alu_issue_queue_dispatch_opcode),
                                .dispatch_pdest (alu_issue_queue_dispatch_pdest),
                                .dispatch_psrc0 (alu_issue_queue_dispatch_psrc0),
                                .dispatch_prdy0 (alu_issue_queue_dispatch_prdy0),
                                .dispatch_psrc1 (alu_issue_queue_dispatch_psrc1),
                                .dispatch_prdy1 (alu_issue_queue_dispatch_prdy1),
                                .dispatch_imm   (alu_issue_queue_dispatch_imm),
                                .dispatch_bid   (alu_issue_queue_dispatch_bid),
                                .dispatch_rob_id(alu_issue_queue_dispatch_rob_id),


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


            assign rename_dispatch_reg_out_is_store_or_not_load = rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_STORE;
            assign lsu_issue_queue_dispatch_valid               = rename_dispatch_reg_out_valid && !rename_dispatch_reg_stall && !rename_dispatch_state_out_is_exception && (rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_STORE || rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_LOAD);
            assign lsu_issue_queue_dispatch_opcode              = {
                       rename_dispatch_reg_out_is_store_or_not_load,
                       rename_dispatch_reg_out_sel_load_store_len,
                       rename_dispatch_state_out_is_cacop,
                       rename_dispatch_state_out_is_ll_w,
                       rename_dispatch_state_out_is_sc_w,
                       rename_dispatch_state_out_is_dbar
                   };

            assign lsu_issue_queue_dispatch_pdest               = rename_dispatch_reg_out_new_phy_reg_dst;
            assign lsu_issue_queue_dispatch_psrc0               = rename_dispatch_reg_out_phy_reg_src1;
            assign lsu_issue_queue_dispatch_prdy0               = rename_dispatch_reg_update_phy_reg_src1_rdy;  //
            assign lsu_issue_queue_dispatch_psrc1               = rename_dispatch_reg_out_phy_reg_src2;
            assign lsu_issue_queue_dispatch_prdy1               = rename_dispatch_reg_update_phy_reg_src2_rdy;  //
            assign lsu_issue_queue_dispatch_imm                 = rename_dispatch_reg_out_extended_imm;

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


            assign lsu_issue_queue_dispatch_bid                 = rename_dispatch_reg_out_bid;


            assign lsu_issue_queue_predict_flush                = predict_flush;
            assign lsu_issue_queue_predict_flush_bid            = predict_flush_bid;
            assign lsu_issue_queue_head_bid                     = branch_id_allocator_bid_head;



            assign lsu_issue_queue_dispatch_rob_id              = rob_alloc_rob_id;

            lsu_issue_queue u_lsu_issue_queue (
                                .clk   (clk),
                                .resetn(resetn),

                                .flush(lsu_issue_queue_flush),

                                .dispatch_valid (lsu_issue_queue_dispatch_valid),
                                .dispatch_ready (lsu_issue_queue_dispatch_ready),
                                .dispatch_opcode(lsu_issue_queue_dispatch_opcode),
                                .dispatch_pdest (lsu_issue_queue_dispatch_pdest),
                                .dispatch_psrc0 (lsu_issue_queue_dispatch_psrc0),
                                .dispatch_prdy0 (lsu_issue_queue_dispatch_prdy0),
                                .dispatch_psrc1 (lsu_issue_queue_dispatch_psrc1),
                                .dispatch_prdy1 (lsu_issue_queue_dispatch_prdy1),
                                .dispatch_imm   (lsu_issue_queue_dispatch_imm),
                                .dispatch_bid   (lsu_issue_queue_dispatch_bid),
                                .dispatch_rob_id(lsu_issue_queue_dispatch_rob_id),

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
                                .head_bid         (lsu_issue_queue_head_bid)
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



            // assign lsu_read_exec_reg_stall                   = 1'b0;
            assign lsu_read_exec_reg_pre_stall               = lsu_issue_read_reg_stall;

            assign lsu_read_exec_reg_in_valid                = lsu_issue_read_reg_out_valid && !lsu_read_clear;
            assign lsu_read_exec_reg_in_phy_reg_rdata1       = physical_regfile_rdata3;
            assign lsu_read_exec_reg_in_phy_reg_rdata2       = physical_regfile_rdata4;
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

                                  .out_valid               (lsu_read_exec_reg_out_valid),
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
            assign lsu_exec_mem1_reg_in_bid                  = lsu_read_exec_reg_out_bid;
            assign lsu_exec_mem1_reg_in_store_ctrl           = 1'b0;


            assign lsu_exec_mem1_reg_in_address_pa = mmu_data_pa;



            assign lsu_exec_mem1_reg_in_is_cacop = lsu_read_exec_reg_out_is_cacop;




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
                                  .in_bid                 (lsu_exec_mem1_reg_in_bid),
                                  .in_store_ctrl          (lsu_exec_mem1_reg_in_store_ctrl),
                                  .in_address_pa          (lsu_exec_mem1_reg_in_address_pa),
                                  .in_is_cacop            (lsu_exec_mem1_reg_in_is_cacop),
                                  .in_is_ll_w(lsu_exec_mem1_reg_in_is_ll_w),
                                  .in_is_sc_w(lsu_exec_mem1_reg_in_is_sc_w),
                                  .in_is_dbar(lsu_exec_mem1_reg_in_is_dbar),

                                  .out_valid               (lsu_exec_mem1_reg_out_valid),
                                  .out_phy_reg_dst         (lsu_exec_mem1_reg_out_phy_reg_dst),
                                  .out_is_store_or_not_load(lsu_exec_mem1_reg_out_is_store_or_not_load),
                                  .out_rob_id              (lsu_exec_mem1_reg_out_rob_id),
                                  .out_sel_load_store_len  (lsu_exec_mem1_reg_out_sel_load_store_len),
                                  .out_wstrb               (lsu_exec_mem1_reg_out_wstrb),
                                  .out_address             (lsu_exec_mem1_reg_out_address),
                                  .out_store_data          (lsu_exec_mem1_reg_out_store_data),
                                  .out_bid                 (lsu_exec_mem1_reg_out_bid),
                                  .out_store_ctrl          (lsu_exec_mem1_reg_out_store_ctrl),
                                  .out_address_pa          (lsu_exec_mem1_reg_out_address_pa),
                                  .out_is_cacop            (lsu_exec_mem1_reg_out_is_cacop),
                                  .out_is_ll_w(lsu_exec_mem1_reg_out_is_ll_w),
                                  .out_is_sc_w(lsu_exec_mem1_reg_out_is_sc_w),
                                  .out_is_dbar(lsu_exec_mem1_reg_out_is_dbar)
                              );




            reg store_buffer_has_store;

            always @(posedge clk) begin
                if(!resetn)
                    store_buffer_has_store <= 1'b0;
                else if(!lsu_exec_mem1_reg_stall)
                    store_buffer_has_store <= 1'b0;
                else if(store_buffer_store_valid && store_buffer_store_ready)
                    store_buffer_has_store <= 1'b1;
            end


            assign store_buffer_store_bid         = lsu_exec_mem1_reg_out_bid;
            assign store_buffer_predict_flush     = predict_flush;
            assign store_buffer_predict_flush_bid = predict_flush_bid;
            assign store_buffer_head_bid          = branch_id_allocator_bid_head;


            assign store_buffer_store_valid       = lsu_exec_mem1_reg_out_valid && lsu_exec_mem1_reg_out_is_store_or_not_load && !lsu_exec_mem1_reg_out_store_ctrl && !store_buffer_has_store;
            assign store_buffer_store_address     = lsu_exec_mem1_reg_out_address;
            assign store_buffer_store_wstrb       = lsu_exec_mem1_reg_out_wstrb;
            assign store_buffer_store_data        = lsu_exec_mem1_reg_out_store_data;

            assign store_buffer_load_address      = lsu_exec_mem1_reg_out_address;

            assign store_buffer_commit_valid      = rob_commit_inst_type == `SEL_ISSUE_QUEUE_STORE && rob_commit_ready;  //

            assign store_buffer_flush             = global_flush;



            assign store_buffer_store_mat         = lsu_exec_mem1_state_out_mmu_data_mat;
            assign store_buffer_load_mat          = lsu_exec_mem1_state_out_mmu_data_mat;



            assign store_buffer_store_address_pa = lsu_exec_mem1_reg_out_address_pa;
            assign store_buffer_load_address_pa  = lsu_exec_mem1_reg_out_address_pa;


            store_buffer u_store_buffer (
                             .clk   (clk),
                             .resetn(resetn),

                             .store_valid     (store_buffer_store_valid),
                             .store_ready     (store_buffer_store_ready),
                             .store_wstrb     (store_buffer_store_wstrb),
                             .store_address   (store_buffer_store_address),
                             .store_data      (store_buffer_store_data),
                             .store_bid       (store_buffer_store_bid),
                             .store_mat       (store_buffer_store_mat),
                             .store_address_pa(store_buffer_store_address_pa),

                             .load_address   (store_buffer_load_address),
                             .load_mat       (store_buffer_load_mat),
                             .load_wstrb     (store_buffer_load_wstrb),
                             .load_data      (store_buffer_load_data),
                             .load_address_pa(store_buffer_load_address_pa),

                             .commit_valid     (store_buffer_commit_valid),
                             .commit_address   (store_buffer_commit_address),
                             .commit_data      (store_buffer_commit_data),
                             .commit_wstrb     (store_buffer_commit_wstrb),
                             .commit_mat       (store_buffer_commit_mat),
                             .commit_address_pa(store_buffer_commit_address_pa),

                             .suc(store_buffer_suc),

                             .flush(store_buffer_flush),

                             .predict_flush    (store_buffer_predict_flush),
                             .predict_flush_bid(store_buffer_predict_flush_bid),
                             .head_bid         (store_buffer_head_bid)

                         );



            // assign data_sram_we                        = {4{store_buffer_commit_valid}} & store_buffer_commit_wstrb;
            // assign data_sram_addr                      = sel_store_commit ? store_buffer_commit_address : lsu_exec_mem1_reg_out_address;
            // assign data_sram_wdata                     = store_buffer_commit_data;





            assign lsu_mem1_mem2_state_in_is_exception = sel_store_commit ? 1'b0 : lsu_exec_mem1_state_out_is_exception;
            assign lsu_mem1_mem2_state_in_is_ale       = lsu_exec_mem1_state_out_is_ale;
            assign lsu_mem1_mem2_state_in_is_tlbr      = lsu_exec_mem1_state_out_is_tlbr;
            assign lsu_mem1_mem2_state_in_is_data_tlbr = lsu_exec_mem1_state_out_is_data_tlbr;
            assign lsu_mem1_mem2_state_in_is_data_pil  = lsu_exec_mem1_state_out_is_data_pil;
            assign lsu_mem1_mem2_state_in_is_data_pis  = lsu_exec_mem1_state_out_is_data_pis;
            assign lsu_mem1_mem2_state_in_is_data_ppi  = lsu_exec_mem1_state_out_is_data_ppi;
            assign lsu_mem1_mem2_state_in_is_data_pme  = lsu_exec_mem1_state_out_is_data_pme;
            assign lsu_mem1_mem2_state_in_mmu_data_mat = sel_store_commit ? store_buffer_commit_mat : lsu_exec_mem1_state_out_mmu_data_mat;


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

            assign lsu_mem1_mem2_reg_in_is_ll_w = sel_store_commit ? 1'b0 : lsu_exec_mem1_reg_out_is_ll_w;
            assign lsu_mem1_mem2_reg_in_is_sc_w =sel_store_commit ? 1'b0 :  lsu_exec_mem1_reg_out_is_sc_w;
            assign lsu_mem1_mem2_reg_in_is_dbar = sel_store_commit ? 1'b0 : lsu_exec_mem1_reg_out_is_dbar;


            assign lsu_mem1_mem2_reg_pre_stall               = sel_store_commit ? sel_store_stall : lsu_exec_mem1_reg_stall;
            assign lsu_mem1_mem2_reg_in_valid                = sel_store_commit ? 1'b1 : lsu_exec_mem1_reg_out_valid && !lsu_mem1_clear;
            assign lsu_mem1_mem2_reg_in_phy_reg_dst          = sel_store_commit ? rob_commit_new_pdest : lsu_exec_mem1_reg_out_phy_reg_dst;
            assign lsu_mem1_mem2_reg_in_is_store_or_not_load = sel_store_commit ? 1'b1 : lsu_exec_mem1_reg_out_is_store_or_not_load;
            assign lsu_mem1_mem2_reg_in_rob_id               = sel_store_commit ? rob_commit_rob_id : lsu_exec_mem1_reg_out_rob_id;
            assign lsu_mem1_mem2_reg_in_sel_load_store_len   = lsu_exec_mem1_reg_out_sel_load_store_len;
            assign lsu_mem1_mem2_reg_in_wstrb                = sel_store_commit ? store_buffer_commit_wstrb : lsu_exec_mem1_reg_out_wstrb;
            assign lsu_mem1_mem2_reg_in_address              = sel_store_commit ? store_buffer_commit_address : lsu_exec_mem1_reg_out_address;
            assign lsu_mem1_mem2_reg_in_store_data           = sel_store_commit ? store_buffer_commit_data : lsu_exec_mem1_reg_out_store_data;
            assign lsu_mem1_mem2_reg_in_load_data            = store_buffer_load_data;
            assign lsu_mem1_mem2_reg_in_load_wstrb           = store_buffer_load_wstrb;
            assign lsu_mem1_mem2_reg_in_bid                  = sel_store_commit ? branch_id_allocator_bid_head : lsu_exec_mem1_reg_out_bid;
            assign lsu_mem1_mem2_reg_in_store_ctrl           = sel_store_commit;

            assign lsu_mem1_mem2_reg_in_address_pa = sel_store_commit ? store_buffer_commit_address_pa : lsu_exec_mem1_reg_out_address_pa;



            assign lsu_mem1_mem2_reg_in_is_cacop = sel_store_commit ? 1'b0 : lsu_exec_mem1_reg_out_is_cacop;


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

            assign md_issue_queue_dispatch_valid        = rename_dispatch_reg_out_valid && !rename_dispatch_reg_stall && !rename_dispatch_state_out_is_exception && (rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_MD || rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_BRQ);
            assign md_issue_queue_dispatch_opcode       = {rename_dispatch_reg_out_sel_npc, rename_dispatch_reg_out_comparator_op, rename_dispatch_reg_out_md_op};

            assign md_issue_queue_dispatch_pdest        = rename_dispatch_reg_out_new_phy_reg_dst;
            assign md_issue_queue_dispatch_psrc0        = rename_dispatch_reg_out_phy_reg_src1;
            assign md_issue_queue_dispatch_prdy0        = rename_dispatch_reg_update_phy_reg_src1_rdy;  //
            assign md_issue_queue_dispatch_psrc1        = rename_dispatch_reg_out_phy_reg_src2;
            assign md_issue_queue_dispatch_prdy1        = rename_dispatch_reg_update_phy_reg_src2_rdy;  //

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


            assign md_issue_queue_dispatch_bid          = rename_dispatch_reg_out_bid;


            assign md_issue_queue_predict_flush         = predict_flush;
            assign md_issue_queue_predict_flush_bid     = predict_flush_bid;
            assign md_issue_queue_head_bid              = branch_id_allocator_bid_head;

            assign md_issue_queue_dispatch_inst_type[2] = |rename_dispatch_reg_out_md_op[6:3];
            assign md_issue_queue_dispatch_inst_type[1] = |rename_dispatch_reg_out_md_op[2:0];
            assign md_issue_queue_dispatch_inst_type[0] = rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_BRQ;



            assign md_issue_queue_dispatch_rob_id       = rob_alloc_rob_id;



            md_issue_queue u_md_issue_queue (
                               .clk   (clk),
                               .resetn(resetn),
                               .flush (md_issue_queue_flush),

                               .dispatch_valid    (md_issue_queue_dispatch_valid),
                               .dispatch_ready    (md_issue_queue_dispatch_ready),
                               .dispatch_opcode   (md_issue_queue_dispatch_opcode),
                               .dispatch_pdest    (md_issue_queue_dispatch_pdest),
                               .dispatch_psrc0    (md_issue_queue_dispatch_psrc0),
                               .dispatch_prdy0    (md_issue_queue_dispatch_prdy0),
                               .dispatch_psrc1    (md_issue_queue_dispatch_psrc1),
                               .dispatch_prdy1    (md_issue_queue_dispatch_prdy1),
                               .dispatch_bid      (md_issue_queue_dispatch_bid),
                               .dispatch_rob_id   (md_issue_queue_dispatch_rob_id),
                               .dispatch_inst_type(md_issue_queue_dispatch_inst_type),

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

            assign fast_issue_queue_dispatch_valid    = rename_dispatch_reg_out_valid && !rename_dispatch_reg_stall && !rename_dispatch_state_out_is_exception && rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_FAST;
            assign fast_issue_queue_dispatch_opcode   = 1'b0;
            assign fast_issue_queue_dispatch_pdest    = rename_dispatch_reg_out_new_phy_reg_dst;
            assign fast_issue_queue_dispatch_imm      = rename_dispatch_reg_out_extended_imm;

            assign fast_issue_queue_issue_ready       = !fast_issue_queue_stall;

            assign fast_issue_queue_dispatch_bid      = rename_dispatch_reg_out_bid;

            assign fast_issue_queue_predict_flush     = predict_flush;
            assign fast_issue_queue_predict_flush_bid = predict_flush_bid;
            assign fast_issue_queue_head_bid          = branch_id_allocator_bid_head;

            assign fast_issue_queue_extra_issue_ready = !fast_issue_queue_extra_stall && !sel_fast_extra_issue_writeback_reg;  //



            assign fast_issue_queue_dispatch_rob_id   = rob_alloc_rob_id;




            fast_issue_queue u_fast_issue_queue (
                                 .clk   (clk),
                                 .resetn(resetn),

                                 .flush(fast_issue_queue_flush),

                                 .dispatch_valid (fast_issue_queue_dispatch_valid),
                                 .dispatch_ready (fast_issue_queue_dispatch_ready),
                                 .dispatch_opcode(fast_issue_queue_dispatch_opcode),
                                 .dispatch_pdest (fast_issue_queue_dispatch_pdest),
                                 .dispatch_imm   (fast_issue_queue_dispatch_imm),
                                 .dispatch_bid   (fast_issue_queue_dispatch_bid),
                                 .dispatch_rob_id(fast_issue_queue_dispatch_rob_id),

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

            assign privilege_issue_queue_dispatch_valid = rename_dispatch_reg_out_valid && !rename_dispatch_reg_stall && !rename_dispatch_state_out_is_exception && rename_dispatch_reg_out_sel_issue_queue == `SEL_ISSUE_QUEUE_PRIVILIEGE;
            assign privilege_issue_queue_dispatch_opcode = {
                       rename_dispatch_state_out_csr_addr,
                       rename_dispatch_state_out_csr_we,
                       rename_dispatch_state_out_csr_re,
                       rename_dispatch_state_out_sel_csr_wmask,
                       rename_dispatch_state_out_invtlb_op,
                       rename_dispatch_state_out_is_inst_tlbsrch,
                       rename_dispatch_state_out_is_inst_tlbrd,
                       rename_dispatch_state_out_is_inst_tlbwr,
                       rename_dispatch_state_out_is_inst_tlbfill,
                       rename_dispatch_state_out_is_inst_invtlb
                   };

            assign privilege_issue_queue_dispatch_pdest = rename_dispatch_reg_out_new_phy_reg_dst;
            assign privilege_issue_queue_dispatch_psrc0 = rename_dispatch_reg_out_phy_reg_src1;
            assign privilege_issue_queue_dispatch_psrc1 = rename_dispatch_reg_out_phy_reg_src2;

            assign privilege_issue_queue_dispatch_bid = rename_dispatch_reg_out_bid;
            assign privilege_issue_queue_dispatch_rob_id = rob_alloc_rob_id;


            assign privilege_issue_queue_issue_ready = sel_privilege_issue;

            assign privilege_issue_queue_predict_flush = predict_flush;
            assign privilege_issue_queue_predict_flush_bid = predict_flush_bid;
            assign privilege_issue_queue_head_bid = branch_id_allocator_bid_head;


            assign sel_privilege_issue = privilege_issue_queue_issue_valid && privilege_issue_queue_issue_rob_id == rob_commit_rob_id;

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

            assign bypass2_valid            = lsu_mem2_writeback_reg_out_valid && !lsu_mem2_writeback_reg_out_is_store_or_not_load && !lsu_mem2_writeback_reg_out_is_cacop && !lsu_mem2_writeback_reg_out_is_dbar;
            assign bypass2_dst              = lsu_mem2_writeback_reg_out_phy_reg_dst;

            assign bypass3_valid            = mul_reg_out_valid;
            assign bypass3_dst              = mul_reg_out_phy_reg_dst;

            assign bypass4_valid            = div_reg_out_valid;
            assign bypass4_dst              = div_reg_out_phy_reg_dst;

            assign bypass5_valid            = fast_issue_writeback_reg_out_valid;
            assign bypass5_dst              = fast_issue_writeback_reg_out_phy_reg_dst;

            assign bypass6_valid            = fast_extra_issue_writeback_reg_out_valid;
            assign bypass6_dst              = fast_extra_issue_writeback_reg_out_phy_reg_dst;

            assign bypass7_valid            = extra_exec_writeback_reg_out_valid && extra_exec_writeback_reg_out_regfile_we;
            assign bypass7_dst              = extra_exec_writeback_reg_out_phy_reg_dst;





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
            assign csr_regfile_pc                = rob_commit_pc;
            assign csr_regfile_vaddr             = rob_commit_vaddr;

            assign csr_regfile_raddr             = privilege_issue_read_reg_out_csr_addr;

            assign csr_regfile_waddr             = privilege_exec_writeback_reg_out_csr_addr;
            assign csr_regfile_we                = privilege_exec_writeback_reg_out_csr_we && extra_exec_writeback_reg_out_valid;
            assign csr_regfile_wdata             = privilege_exec_writeback_reg_out_physical_regfile_rdata2;
            assign csr_regfile_wmask             = privilege_exec_writeback_reg_out_physical_regfile_rdata1 | {32{privilege_exec_writeback_reg_out_sel_csr_wmask}};

            assign csr_regfile_is_exception      = rob_commit_is_exception && rob_commit_fire;
            assign csr_regfile_ertn_flush        = !rob_commit_is_exception && rob_commit_ertn_flush && rob_commit_fire;

            assign csr_regfile_is_int            = rob_commit_is_int;
            assign csr_regfile_is_sys            = rob_commit_is_sys;
            assign csr_regfile_is_adef           = rob_commit_is_adef;
            assign csr_regfile_is_ale            = rob_commit_is_ale;
            assign csr_regfile_is_brk            = rob_commit_is_brk;
            assign csr_regfile_is_ine            = rob_commit_is_ine;

            assign csr_regfile_is_tlbr           = rob_commit_is_tlbr;
            assign csr_regfile_is_inst_tlbr      = rob_commit_is_inst_tlbr;
            assign csr_regfile_is_inst_pif       = rob_commit_is_inst_pif;
            assign csr_regfile_is_inst_ppi       = rob_commit_is_inst_ppi;
            assign csr_regfile_is_data_tlbr      = rob_commit_is_data_tlbr;
            assign csr_regfile_is_data_pil       = rob_commit_is_data_pil;
            assign csr_regfile_is_data_pis       = rob_commit_is_data_pis;
            assign csr_regfile_is_data_ppi       = rob_commit_is_data_ppi;
            assign csr_regfile_is_data_pme       = rob_commit_is_data_pme;

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
                   || (lsu_read_exec_reg_out_is_cacop && rob_commit_arch_dest[4:3] == 2'b10);

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
                    .inst_mat    (mmu_inst_mat),
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

            assign rob_alloc_valid = rename_dispatch_reg_out_valid && !rename_dispatch_reg_stall && !dispatch_clear;
            assign rob_alloc_pc = rename_dispatch_reg_out_pc;
            assign rob_alloc_instruction = rename_dispatch_reg_out_instruction;
            assign rob_alloc_arch_dest = rename_dispatch_state_out_is_cacop ? rename_dispatch_state_out_invtlb_op : rename_dispatch_reg_out_regfile_waddr;
            assign rob_alloc_new_pdest = rename_dispatch_reg_out_new_phy_reg_dst;
            assign rob_alloc_old_pdest = rename_dispatch_reg_out_old_phy_reg_dst;
            assign rob_alloc_regfile_we = rename_dispatch_reg_out_regfile_we;
            assign rob_alloc_inst_type = rename_dispatch_reg_out_sel_issue_queue;
            assign rob_alloc_issue_op = {
                       rename_dispatch_state_out_ertn_flush,
                       rename_dispatch_state_out_is_sys,
                       rename_dispatch_state_out_is_int,
                       rename_dispatch_state_out_is_adef,
                       rename_dispatch_state_out_is_ine,
                       rename_dispatch_state_out_is_brk,
                       rename_dispatch_state_out_is_tlbr,
                       rename_dispatch_state_out_is_inst_tlbr,
                       rename_dispatch_state_out_is_inst_pif,
                       rename_dispatch_state_out_is_inst_ppi,
                       rename_dispatch_state_out_wb_refetch,
                       rename_dispatch_state_out_is_cacop
                   };
            assign rob_alloc_is_exception = rename_dispatch_state_out_is_exception;

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


            assign rob_alloc_bid = rename_dispatch_reg_out_bid;

            assign rob_predict_flush_bid = predict_flush_bid;
            assign rob_head_bid = branch_id_allocator_bid_head;



            assign rob_commit_is_tlbr = rob_commit_is_issue_tlbr || rob_commit_is_writeback_tlbr;

            assign {rob_commit_ertn_flush, rob_commit_is_sys, rob_commit_is_int, rob_commit_is_adef, rob_commit_is_ine, rob_commit_is_brk, rob_commit_is_issue_tlbr, rob_commit_is_inst_tlbr, rob_commit_is_inst_pif, rob_commit_is_inst_ppi, rob_commit_wb_refetch, rob_commit_is_cacop} = rob_commit_issue_op;


            assign {rob_commit_is_ale, rob_commit_is_writeback_tlbr, rob_commit_is_data_tlbr, rob_commit_is_data_pil, rob_commit_is_data_pis, rob_commit_is_data_ppi, rob_commit_is_data_pme, rob_commit_vaddr}                                                                           = rob_commit_writeback_op;


            rob u_rob (
                    .clk   (clk),
                    .resetn(resetn),
                    .flush (rob_flush),

                    .rob_alloc_valid       (rob_alloc_valid),
                    .rob_alloc_ready       (rob_alloc_ready),
                    .rob_alloc_rob_id      (rob_alloc_rob_id),
                    .rob_alloc_pc          (rob_alloc_pc),
                    .rob_alloc_instruction (rob_alloc_instruction),
                    .rob_alloc_arch_dest   (rob_alloc_arch_dest),
                    .rob_alloc_new_pdest   (rob_alloc_new_pdest),
                    .rob_alloc_old_pdest   (rob_alloc_old_pdest),
                    .rob_alloc_regfile_we  (rob_alloc_regfile_we),
                    .rob_alloc_inst_type   (rob_alloc_inst_type),
                    .rob_alloc_issue_op    (rob_alloc_issue_op),
                    .rob_alloc_bid         (rob_alloc_bid),
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


                    .rob_commit_valid       (rob_commit_valid),
                    .rob_commit_ready       (rob_commit_ready),
                    .rob_commit_fire        (rob_commit_fire),
                    .rob_commit_rob_id      (rob_commit_rob_id),
                    .rob_commit_pc          (rob_commit_pc),
                    .rob_commit_instruction (rob_commit_instruction),
                    .rob_commit_arch_dest   (rob_commit_arch_dest),
                    .rob_commit_new_pdest   (rob_commit_new_pdest),
                    .rob_commit_old_pdest   (rob_commit_old_pdest),
                    .rob_commit_regfile_we  (rob_commit_regfile_we),
                    .rob_commit_value       (rob_commit_value),
                    .rob_commit_inst_type   (rob_commit_inst_type),
                    .rob_commit_issue_op    (rob_commit_issue_op),
                    .rob_commit_writeback_op(rob_commit_writeback_op),
                    .rob_commit_is_exception(rob_commit_is_exception),

                    .rob_complete_conflict(rob_complete_conflict),
                    .rob_head             (rob_head),
                    .rob_full             (rob_full),
                    .rob_empty            (rob_empty),
                    .rob_count            (rob_count),

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
                            .rob_commit_pc                       (rob_commit_pc),

                            .rob_commit_inst_type(rob_commit_inst_type),

                            .lsu_mem1_mem2_reg_stall  (lsu_mem1_mem2_reg_stall),
                            .rob_commit_target_address(rob_commit_target_address),

                            .rob_commit_is_cacop        (rob_commit_is_cacop),
                            .store_buffer_commit_mat    (store_buffer_commit_mat),
                            .cache_subsystem_dcache_busy(cache_subsystem_dcache_busy),
                            .cacop_fsm_state            (cacop_fsm_state),
                            .sel_store_stall            (sel_store_stall),
                            .sel_store_commit           (sel_store_commit),

                            .flush_target_address(flush_target_address),
                            .global_flush        (global_flush),

                            .predict_flush(predict_flush)
                        );



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

                                        .inst_fifo_out_valid (inst_fifo_out_valid),
                                        .inst_fifo_stall     (inst_fifo_stall),
                                        .id_clear            (id_clear),
                                        .insfifo_is_exception(insfifo_is_exception),

                                        .id_allocbid_reg_out_valid         (id_allocbid_reg_out_valid),
                                        .id_allocbid_reg_stall             (id_allocbid_reg_stall),
                                        .allocbid_clear                    (allocbid_clear),
                                        .id_allocbid_state_out_is_exception(id_allocbid_state_out_is_exception),

                                        .allocbid_rename_reg_out_valid         (allocbid_rename_reg_out_valid),
                                        .allocbid_rename_reg_stall             (allocbid_rename_reg_stall),
                                        .rename_clear                          (rename_clear),
                                        .allocbid_rename_state_out_is_exception(allocbid_rename_state_out_is_exception),

                                        .rename_dispatch_reg_out_valid         (rename_dispatch_reg_out_valid),
                                        .rename_dispatch_reg_stall             (rename_dispatch_reg_stall),
                                        .dispatch_clear                        (dispatch_clear),
                                        .rename_dispatch_state_out_is_exception(rename_dispatch_state_out_is_exception),

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

                                        .rename_buffer_result_rename_success(rename_buffer_result_rename_success),
                                        .cam_rmt_rename_success             (cam_rmt_rename_success),
                                        .allocbid_rename_reg_out_regfile_we (allocbid_rename_reg_out_regfile_we),

                                        .inst_fifo_wr_ready(inst_fifo_wr_ready),

                                        .store_buffer_store_ready                  (store_buffer_store_ready),
                                        .lsu_read_exec_reg_out_is_store_or_not_load(lsu_read_exec_reg_out_is_store_or_not_load),
                                        .lsu_exec_mem1_reg_out_is_store_or_not_load(lsu_exec_mem1_reg_out_is_store_or_not_load),
                                        .lsu_mem1_mem2_reg_out_is_store_or_not_load(lsu_mem1_mem2_reg_out_is_store_or_not_load),
                                        .lsu_mem2_load_miss                        (lsu_mem2_load_miss),



                                        .rename_dispatch_reg_out_sel_issue_queue(rename_dispatch_reg_out_sel_issue_queue),
                                        .alu_issue_queue_dispatch_ready         (alu_issue_queue_dispatch_ready),
                                        .lsu_issue_queue_dispatch_ready         (lsu_issue_queue_dispatch_ready),
                                        .md_issue_queue_dispatch_ready          (md_issue_queue_dispatch_ready),
                                        .fast_issue_queue_dispatch_ready        (fast_issue_queue_dispatch_ready),
                                        .privilege_issue_queue_dispatch_ready   (privilege_issue_queue_dispatch_ready),
                                        .rob_alloc_ready                        (rob_alloc_ready),

                                        .id_allocbid_reg_out_sel_npc        (id_allocbid_reg_out_sel_npc),
                                        .branch_id_allocator_alloc_bid_ready(branch_id_allocator_alloc_bid_ready),
                                        .branch_id_allocator_alloc_bid_valid(branch_id_allocator_alloc_bid_valid),
                                        .allocbid_buffer_alloc_already      (allocbid_buffer_alloc_already),

                                        .b_flush      (b_flush),
                                        .predict_flush(predict_flush),

                                        .md_bru_writeback_reg_out_is_jump    (md_bru_writeback_reg_out_is_jump),
                                        .predict_flush_bid                   (predict_flush_bid),
                                        .branch_id_allocator_bid_head        (branch_id_allocator_bid_head),
                                        .lsu_exec_mem1_state_out_mmu_data_mat(lsu_exec_mem1_state_out_mmu_data_mat),
                                        .store_buffer_suc                    (store_buffer_suc),

                                        .sel_store_commit(sel_store_commit),

                                        .inst_sram_fsm_state(inst_sram_fsm_state),
                                        .data_sram_fsm_state(data_sram_fsm_state),

                                        .data_sram_fsm_miss_trans(data_sram_fsm_miss_trans),

                                        .cache_subsystem_mem2_miss        (cache_subsystem_mem2_miss),
                                        .cache_subsystem_mem2_refill_valid(cache_subsystem_mem2_refill_valid),
                                        .cache_subsystem_dcache_busy      (cache_subsystem_dcache_busy),
                                        .cache_subsystem_if2_miss         (cache_subsystem_if2_miss),
                                        .cache_subsystem_if2_refill_valid (cache_subsystem_if2_refill_valid),
                                        .cache_subsystem_icache_busy      (cache_subsystem_icache_busy),

                                        .cacop_fsm_state               (cacop_fsm_state),
                                        .lsu_mem1_mem2_reg_out_is_cacop(lsu_mem1_mem2_reg_out_is_cacop),
                                        .lsu_exec_mem1_reg_out_is_cacop(lsu_exec_mem1_reg_out_is_cacop),
                                        .lsu_read_exec_reg_out_is_cacop(lsu_read_exec_reg_out_is_cacop),
                                        .rob_commit_rob_id             (rob_commit_rob_id),
                                        .lsu_read_exec_reg_out_rob_id  (lsu_read_exec_reg_out_rob_id),
                                        .decode_is_idle(decode_is_idle),
                                        .is_int(is_int),

                                        .lsu_mem1_mem2_reg_out_is_dbar(lsu_mem1_mem2_reg_out_is_dbar),
                                        .lsu_mem1_mem2_reg_out_is_sc_w(lsu_mem1_mem2_reg_out_is_sc_w),
                                        .csr_regfile_llbit(csr_regfile_llbit),

                                        .lsu_read_exec_reg_out_is_ll_w(lsu_read_exec_reg_out_is_ll_w),
                                        .lsu_read_exec_reg_out_is_sc_w(lsu_read_exec_reg_out_is_sc_w),
                                        .lsu_read_exec_reg_out_is_dbar(lsu_read_exec_reg_out_is_dbar),

                                        .store_buffer_has_store(store_buffer_has_store),

                                        .id_allocbid_reg_out_is_b_jump(id_allocbid_reg_out_is_b_jump)

                                    );


`ifdef difftest

            assign debug0_wb_pc = rob_commit_pc;
            assign debug0_wb_rf_wen = {4{rob_commit_ready & rob_commit_regfile_we & ~rob_commit_is_exception}};
            assign debug0_wb_rf_wnum = rob_commit_arch_dest;
            assign debug0_wb_rf_wdata = rob_commit_value;


            `elsif perftest_or_linux

                   assign debug0_wb_pc = rob_commit_pc;
            assign debug0_wb_rf_wen = {4{rob_commit_ready & rob_commit_regfile_we & ~rob_commit_is_exception}};
            assign debug0_wb_rf_wnum = rob_commit_arch_dest;
            assign debug0_wb_rf_wdata = rob_commit_value;


`else

            assign debug_wb_pc       = rob_commit_pc;
            assign debug_wb_rf_we    = {4{rob_commit_ready & rob_commit_regfile_we & ~rob_commit_is_exception}};
            assign debug_wb_rf_wnum  = rob_commit_arch_dest;
            assign debug_wb_rf_wdata = rob_commit_value;


`endif


`ifdef difftest

            wire         id_allocbid_difftest_forward_reg_in_csr_3w;
            wire         id_allocbid_difftest_forward_reg_in_is_CNTinst;
            wire  [ 7:0] id_allocbid_difftest_forward_reg_in_load_valid;
            wire  [ 7:0] id_allocbid_difftest_forward_reg_in_store_valid;
            wire [63:0] id_allocbid_difftest_forward_reg_in_timer_64_value;

            wire        id_allocbid_difftest_forward_reg_out_csr_3w;
            wire        id_allocbid_difftest_forward_reg_out_is_CNTinst;
            wire [ 7:0] id_allocbid_difftest_forward_reg_out_load_valid;
            wire [ 7:0] id_allocbid_difftest_forward_reg_out_store_valid;
            wire [63:0] id_allocbid_difftest_forward_reg_out_timer_64_value;

            assign id_allocbid_difftest_forward_reg_in_csr_3w = decode_csr_3w;
            assign id_allocbid_difftest_forward_reg_in_is_CNTinst = decode_is_CNTinst;
            assign id_allocbid_difftest_forward_reg_in_load_valid = decode_load_valid;
            assign id_allocbid_difftest_forward_reg_in_store_valid = decode_store_valid;
            assign id_allocbid_difftest_forward_reg_in_timer_64_value = rdcnt;



            difftest_forward_reg u_id_allocbid_difftest_forward_reg(
                                     .clk(clk),
                                     .resetn(resetn),

                                     .stall(id_allocbid_reg_stall),

                                     .in_csr_3w(id_allocbid_difftest_forward_reg_in_csr_3w),
                                     .in_is_CNTinst(id_allocbid_difftest_forward_reg_in_is_CNTinst),
                                     .in_load_valid(id_allocbid_difftest_forward_reg_in_load_valid),
                                     .in_store_valid(id_allocbid_difftest_forward_reg_in_store_valid),
                                     .in_timer_64_value(id_allocbid_difftest_forward_reg_in_timer_64_value),

                                     .out_csr_3w(id_allocbid_difftest_forward_reg_out_csr_3w),
                                     .out_is_CNTinst(id_allocbid_difftest_forward_reg_out_is_CNTinst),
                                     .out_load_valid(id_allocbid_difftest_forward_reg_out_load_valid),
                                     .out_store_valid(id_allocbid_difftest_forward_reg_out_store_valid),
                                     .out_timer_64_value(id_allocbid_difftest_forward_reg_out_timer_64_value)
                                 );


            wire         allocbid_rename_difftest_forward_reg_in_csr_3w;
            wire         allocbid_rename_difftest_forward_reg_in_is_CNTinst;
            wire  [ 7:0] allocbid_rename_difftest_forward_reg_in_load_valid;
            wire  [ 7:0] allocbid_rename_difftest_forward_reg_in_store_valid;
            wire [63:0] allocbid_rename_difftest_forward_reg_in_timer_64_value;

            wire        allocbid_rename_difftest_forward_reg_out_csr_3w;
            wire        allocbid_rename_difftest_forward_reg_out_is_CNTinst;
            wire [ 7:0] allocbid_rename_difftest_forward_reg_out_load_valid;
            wire [ 7:0] allocbid_rename_difftest_forward_reg_out_store_valid;
            wire [63:0] allocbid_rename_difftest_forward_reg_out_timer_64_value;

            assign allocbid_rename_difftest_forward_reg_in_csr_3w = id_allocbid_difftest_forward_reg_out_csr_3w;
            assign allocbid_rename_difftest_forward_reg_in_is_CNTinst = id_allocbid_difftest_forward_reg_out_is_CNTinst;
            assign allocbid_rename_difftest_forward_reg_in_load_valid = id_allocbid_difftest_forward_reg_out_load_valid;
            assign allocbid_rename_difftest_forward_reg_in_store_valid = id_allocbid_difftest_forward_reg_out_store_valid;
            assign allocbid_rename_difftest_forward_reg_in_timer_64_value = id_allocbid_difftest_forward_reg_out_timer_64_value;



            difftest_forward_reg u_allocbid_rename_difftest_forward_reg(
                                     .clk(clk),
                                     .resetn(resetn),

                                     .stall(allocbid_rename_reg_stall),

                                     .in_csr_3w(allocbid_rename_difftest_forward_reg_in_csr_3w),
                                     .in_is_CNTinst(allocbid_rename_difftest_forward_reg_in_is_CNTinst),
                                     .in_load_valid(allocbid_rename_difftest_forward_reg_in_load_valid),
                                     .in_store_valid(allocbid_rename_difftest_forward_reg_in_store_valid),
                                     .in_timer_64_value(allocbid_rename_difftest_forward_reg_in_timer_64_value),

                                     .out_csr_3w(allocbid_rename_difftest_forward_reg_out_csr_3w),
                                     .out_is_CNTinst(allocbid_rename_difftest_forward_reg_out_is_CNTinst),
                                     .out_load_valid(allocbid_rename_difftest_forward_reg_out_load_valid),
                                     .out_store_valid(allocbid_rename_difftest_forward_reg_out_store_valid),
                                     .out_timer_64_value(allocbid_rename_difftest_forward_reg_out_timer_64_value)
                                 );


            wire         rename_dispatch_difftest_forward_reg_in_csr_3w;
            wire         rename_dispatch_difftest_forward_reg_in_is_CNTinst;
            wire  [ 7:0] rename_dispatch_difftest_forward_reg_in_load_valid;
            wire  [ 7:0] rename_dispatch_difftest_forward_reg_in_store_valid;
            wire [63:0] rename_dispatch_difftest_forward_reg_in_timer_64_value;

            wire        rename_dispatch_difftest_forward_reg_out_csr_3w;
            wire        rename_dispatch_difftest_forward_reg_out_is_CNTinst;
            wire [ 7:0] rename_dispatch_difftest_forward_reg_out_load_valid;
            wire [ 7:0] rename_dispatch_difftest_forward_reg_out_store_valid;
            wire [63:0] rename_dispatch_difftest_forward_reg_out_timer_64_value;

            assign rename_dispatch_difftest_forward_reg_in_csr_3w = allocbid_rename_difftest_forward_reg_out_csr_3w;
            assign rename_dispatch_difftest_forward_reg_in_is_CNTinst = allocbid_rename_difftest_forward_reg_out_is_CNTinst;
            assign rename_dispatch_difftest_forward_reg_in_load_valid = allocbid_rename_difftest_forward_reg_out_load_valid;
            assign rename_dispatch_difftest_forward_reg_in_store_valid = allocbid_rename_difftest_forward_reg_out_store_valid;
            assign rename_dispatch_difftest_forward_reg_in_timer_64_value = allocbid_rename_difftest_forward_reg_out_timer_64_value;



            difftest_forward_reg u_rename_dispatch_difftest_forward_reg(
                                     .clk(clk),
                                     .resetn(resetn),

                                     .stall(rename_dispatch_reg_stall),

                                     .in_csr_3w(rename_dispatch_difftest_forward_reg_in_csr_3w),
                                     .in_is_CNTinst(rename_dispatch_difftest_forward_reg_in_is_CNTinst),
                                     .in_load_valid(rename_dispatch_difftest_forward_reg_in_load_valid),
                                     .in_store_valid(rename_dispatch_difftest_forward_reg_in_store_valid),
                                     .in_timer_64_value(rename_dispatch_difftest_forward_reg_in_timer_64_value),

                                     .out_csr_3w(rename_dispatch_difftest_forward_reg_out_csr_3w),
                                     .out_is_CNTinst(rename_dispatch_difftest_forward_reg_out_is_CNTinst),
                                     .out_load_valid(rename_dispatch_difftest_forward_reg_out_load_valid),
                                     .out_store_valid(rename_dispatch_difftest_forward_reg_out_store_valid),
                                     .out_timer_64_value(rename_dispatch_difftest_forward_reg_out_timer_64_value)
                                 );

            wire difftest_commit_reg_in_csr_3w;
            wire difftest_commit_reg_in_is_CNTinst;
            wire [7:0] difftest_commit_reg_in_load_valid;
            wire [7:0] difftest_commit_reg_in_store_valid;
            wire [63:0] difftest_commit_reg_in_timer_64_value;

            wire [31:0] difftest_commit_reg_in_vaddr;
            wire [31:0] difftest_commit_reg_in_paddr;

            wire [31:0] difftest_commit_reg_in_storeData;

            wire difftest_commit_reg_in_valid;
            wire [31:0] difftest_commit_reg_in_pc;
            wire [31:0] difftest_commit_reg_in_instruction;
            wire difftest_commit_reg_in_is_tlbfill;
            wire [3:0] difftest_commit_reg_in_tlbfill_index;
            wire difftest_commit_reg_in_wen;
            wire [4:0] difftest_commit_reg_in_wdest;
            wire [31:0] difftest_commit_reg_in_wdata;
            wire difftest_commit_reg_in_is_exception;
            wire difftest_commit_reg_in_is_eret;



            wire difftest_commit_reg_out_csr_3w;
            wire difftest_commit_reg_out_is_CNTinst;
            wire [7:0] difftest_commit_reg_out_load_valid;
            wire [7:0] difftest_commit_reg_out_store_valid;
            wire [63:0] difftest_commit_reg_out_timer_64_value;

            wire [31:0] difftest_commit_reg_out_vaddr;
            wire [31:0] difftest_commit_reg_out_paddr;

            wire [31:0] difftest_commit_reg_out_storeData;

            wire difftest_commit_reg_out_valid;
            wire [31:0] difftest_commit_reg_out_pc;
            wire [31:0] difftest_commit_reg_out_instruction;
            wire difftest_commit_reg_out_is_tlbfill;
            wire [3:0] difftest_commit_reg_out_tlbfill_index;
            wire difftest_commit_reg_out_wen;
            wire [4:0] difftest_commit_reg_out_wdest;
            wire [31:0] difftest_commit_reg_out_wdata;
            wire difftest_commit_reg_out_is_exception;
            wire difftest_commit_reg_out_is_eret;


            wire       difftest_rob_commit_csr_3w;
            wire        difftest_rob_commit_is_CNTinst;
            wire [ 7:0] difftest_rob_commit_load_valid;
            wire[ 7:0] difftest_rob_commit_store_valid;
            wire [63:0] difftest_rob_commit_timer_64_value;
            wire  [ 3:0] difftest_rob_commit_tlbfill_index;
            wire [31:0] difftest_rob_commit_vaddr;
            wire [31:0] difftest_rob_commit_paddr;
            wire [31:0] difftest_rob_commit_store_data;
            wire difftest_rob_commit_commit_is_tlbfill;


            difftest_rob u_difftest_rob(
                             .clk(clk),
                             .alloc_fire(rob_alloc_ready && rob_alloc_valid),
                             .alloc_rob(rob_alloc_rob_id),
                             .alloc_csr_3w(rename_dispatch_difftest_forward_reg_out_csr_3w),
                             .alloc_is_CNTinst(rename_dispatch_difftest_forward_reg_out_is_CNTinst),
                             .alloc_load_valid(rename_dispatch_difftest_forward_reg_out_load_valid),
                             .alloc_store_valid(rename_dispatch_difftest_forward_reg_out_store_valid),
                             .alloc_timer_64_value(rename_dispatch_difftest_forward_reg_out_timer_64_value),
                             .alloc_is_tlbfill(rename_dispatch_state_out_is_inst_tlbfill),

                             .tlbfill_fire(extra_exec_writeback_reg_out_valid && privilege_exec_writeback_reg_out_is_inst_tlbfill),
                             .tlbfill_rob(extra_exec_writeback_reg_out_rob_id),
                             .tlbfill_index(mmu_tlbfill_index),

                             .ls_fire(lsu_mem1_mem2_reg_out_valid && !lsu_mem1_mem2_state_out_is_exception &&
                                      !lsu_mem1_mem2_reg_out_store_ctrl),
                             .ls_llbit(csr_regfile_llbit),
                             .ls_rob(lsu_mem1_mem2_reg_out_rob_id),
                             .ls_vaddr(lsu_mem1_mem2_reg_out_address),
                             .ls_paddr(lsu_mem1_mem2_reg_out_address_pa),
                             .ls_store_data(lsu_mem1_mem2_reg_out_store_data &{{8{lsu_mem1_mem2_reg_out_wstrb[3]}}, {8{lsu_mem1_mem2_reg_out_wstrb[2]}}, {8{lsu_mem1_mem2_reg_out_wstrb[1]}}, {8{lsu_mem1_mem2_reg_out_wstrb[0]}}}),

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
                             .commit_is_tlbfill(difftest_rob_commit_commit_is_tlbfill)
                         );


            assign difftest_commit_reg_in_csr_3w = difftest_rob_commit_csr_3w;
            assign difftest_commit_reg_in_is_CNTinst = difftest_rob_commit_is_CNTinst;
            assign difftest_commit_reg_in_load_valid = difftest_rob_commit_load_valid;
            assign difftest_commit_reg_in_store_valid = difftest_rob_commit_store_valid;
            assign difftest_commit_reg_in_timer_64_value = difftest_rob_commit_timer_64_value;
            assign difftest_commit_reg_in_vaddr = difftest_rob_commit_vaddr;
            assign difftest_commit_reg_in_paddr = difftest_rob_commit_paddr;
            assign difftest_commit_reg_in_storeData = difftest_rob_commit_store_data;

            assign difftest_commit_reg_in_valid = rob_commit_valid &&rob_commit_ready && !csr_regfile_is_exception;
            assign difftest_commit_reg_in_pc = rob_commit_pc;
            assign difftest_commit_reg_in_instruction = rob_commit_instruction;
            assign difftest_commit_reg_in_is_tlbfill = difftest_rob_commit_commit_is_tlbfill;
            assign difftest_commit_reg_in_tlbfill_index = difftest_rob_commit_tlbfill_index;
            assign difftest_commit_reg_in_wen = rob_commit_regfile_we;
            assign difftest_commit_reg_in_wdest = rob_commit_arch_dest;
            assign difftest_commit_reg_in_wdata = rob_commit_value;
            assign difftest_commit_reg_in_is_exception = csr_regfile_is_exception;
            assign difftest_commit_reg_in_is_eret = csr_regfile_ertn_flush;


            difftest_commit_reg u_difftest_commit_reg(
                                    .clk(clk),
                                    .resetn(resetn),

                                    .stall(1'b0),

                                    .in_csr_3w(difftest_commit_reg_in_csr_3w),
                                    .in_is_CNTinst(difftest_commit_reg_in_is_CNTinst),
                                    .in_load_valid(difftest_commit_reg_in_load_valid),
                                    .in_store_valid(difftest_commit_reg_in_store_valid),
                                    .in_timer_64_value(difftest_commit_reg_in_timer_64_value),
                                    .in_vaddr(difftest_commit_reg_in_vaddr),
                                    .in_paddr(difftest_commit_reg_in_paddr),
                                    .in_storeData(difftest_commit_reg_in_storeData),

                                    .in_valid(difftest_commit_reg_in_valid),
                                    .in_pc(difftest_commit_reg_in_pc),
                                    .in_instruction(difftest_commit_reg_in_instruction),
                                    .in_is_tlbfill(difftest_commit_reg_in_is_tlbfill),
                                    .in_tlbfill_index(difftest_commit_reg_in_tlbfill_index),
                                    .in_wen(difftest_commit_reg_in_wen),
                                    .in_wdest(difftest_commit_reg_in_wdest),
                                    .in_wdata(difftest_commit_reg_in_wdata),
                                    .in_is_exception(difftest_commit_reg_in_is_exception),
                                    .in_is_eret(difftest_commit_reg_in_is_eret),

                                    .out_csr_3w(difftest_commit_reg_out_csr_3w),
                                    .out_is_CNTinst(difftest_commit_reg_out_is_CNTinst),
                                    .out_load_valid(difftest_commit_reg_out_load_valid),
                                    .out_store_valid(difftest_commit_reg_out_store_valid),
                                    .out_timer_64_value(difftest_commit_reg_out_timer_64_value),
                                    .out_vaddr(difftest_commit_reg_out_vaddr),
                                    .out_paddr(difftest_commit_reg_out_paddr),
                                    .out_storeData(difftest_commit_reg_out_storeData),

                                    .out_valid(difftest_commit_reg_out_valid),
                                    .out_pc(difftest_commit_reg_out_pc),
                                    .out_instruction(difftest_commit_reg_out_instruction),
                                    .out_is_tlbfill(difftest_commit_reg_out_is_tlbfill),
                                    .out_tlbfill_index(difftest_commit_reg_out_tlbfill_index),
                                    .out_wen(difftest_commit_reg_out_wen),
                                    .out_wdest(difftest_commit_reg_out_wdest),
                                    .out_wdata(difftest_commit_reg_out_wdata),
                                    .out_is_exception(difftest_commit_reg_out_is_exception),
                                    .out_is_eret(difftest_commit_reg_out_is_eret)
                                );





            DifftestInstrCommit u_difftest_InstrCommit(
                                    .clock          (clk),
                                    .coreid         (8'd0),
                                    .index          (8'd0),
                                    .valid          (difftest_commit_reg_out_valid),
                                    .pc             ({32'd0, difftest_commit_reg_out_pc}),
                                    .instr          (difftest_commit_reg_out_instruction),
                                    .skip           (1'b0),
                                    .is_TLBFILL     (difftest_commit_reg_out_is_tlbfill),
                                    .TLBFILL_index  (difftest_commit_reg_out_tlbfill_index),
                                    .is_CNTinst     (difftest_commit_reg_out_is_CNTinst),
                                    .timer_64_value (difftest_commit_reg_out_timer_64_value),
                                    .wen            (difftest_commit_reg_out_wen),
                                    .wdest          ({3'd0, difftest_commit_reg_out_wdest}),
                                    .wdata          ({32'd0, difftest_commit_reg_out_wdata}),
                                    .csr_rstat      (difftest_commit_reg_out_csr_3w),
                                    .csr_data       (difftest_commit_reg_out_wdata)
                                );

            // DifftestExcpEvent
            DifftestExcpEvent u_difftest_ExcpEvent(
                                  .clock          (clk),
                                  .coreid         (8'd0),
                                  .excp_valid     (difftest_commit_reg_out_is_exception),
                                  .eret           (difftest_commit_reg_out_is_eret),
                                  .intrNo         ({21'b0, csr_regfile_out_csr_estat[12:2]}),  // TODO: connect actual interrupt number
                                  .cause          ({26'b0, csr_regfile_out_csr_estat[`CSR_ESTAT_ECODE]}),
                                  .exceptionPC    ({32'd0, difftest_commit_reg_out_pc}),
                                  .exceptionInst  (difftest_commit_reg_out_instruction)
                              );

            // DifftesTrapEvent
            DifftestTrapEvent u_difftest_TrapEvent(
                                  .clock          (clk),
                                  .coreid         (8'd0),
                                  .valid          (1'b0),  // TODO: connect trap signal
                                  .code           (3'd0),
                                  .pc             ({32'd0, difftest_commit_reg_out_pc}),
                                  .cycleCnt       (rdcnt),
                                  .instrCnt       (64'd0)  // TODO: connect instruction counter
                              );

            // DifftestStoreEvent
            DifftestStoreEvent u_difftest_StoreEvent(
                                   .clock          (clk),
                                   .coreid         (8'd0),
                                   .index          (8'd0),
                                   .valid          (difftest_commit_reg_out_store_valid & {8{difftest_commit_reg_out_valid}}),
                                   .storePAddr     ({32'd0, difftest_commit_reg_out_paddr}),  // vaddr used as paddr (no MMU address translation in difftest)
                                   .storeVAddr     ({32'd0, difftest_commit_reg_out_vaddr}),
                                   .storeData      ({32'd0, difftest_commit_reg_out_storeData})  // TODO: actual store data
                               );

            // DifftestLoadEvent
            DifftestLoadEvent u_difftest_LoadEvent(
                                  .clock          (clk),
                                  .coreid         (8'd0),
                                  .index          (8'd0),
                                  .valid          (difftest_commit_reg_out_load_valid & {8{difftest_commit_reg_out_valid}}),
                                  .paddr          ({32'd0, difftest_commit_reg_out_paddr}),  // vaddr used as paddr
                                  .vaddr          ({32'd0, difftest_commit_reg_out_vaddr})
                              );






`endif










        endmodule

