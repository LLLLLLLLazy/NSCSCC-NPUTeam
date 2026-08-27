`include "header.v"



`ifdef difftest


module core_top(

`elsif  perftest_or_linux


module core_top(


`else

module mycpu_top(


`endif 

    input  wire        aclk,
    input  wire        aresetn,

    input  wire [ 7:0] intrpt,

    output wire [3:0] arid,
    output wire [31:0] araddr,
    output wire [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    output wire [1:0] arlock,
    output wire [3:0] arcache,
    output wire [2:0] arprot,
    output wire arvalid,
    input wire arready,

    input wire [3:0] rid,
    input wire [31:0] rdata,
    input wire [1:0] rresp,
    input wire rlast,
    input wire rvalid,
    output wire rready,

    output wire [3:0] awid,
    output wire [31:0] awaddr,
    output wire [7:0] awlen,
    output wire [2:0] awsize,
    output wire [1:0] awburst,
    output wire [1:0] awlock,
    output wire [3:0] awcache,
    output wire [2:0] awprot,
    output wire awvalid,
    input wire awready, 

    output wire [3:0] wid,
    output wire [31:0] wdata,
    output wire [3:0] wstrb,
    output wire wlast,
    output wire wvalid,
    input wire wready,

    input [3:0] bid,
    input [1:0] bresp,
    input wire bvalid,
    output wire bready,

    `ifdef difftest

    input           break_point,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟缴ｏ拷锟斤拷锟斤拷1'b0
    input           infor_flag,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟缴ｏ拷锟斤拷锟斤拷1'b0
    input  [ 4:0]   reg_num,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟缴ｏ拷锟斤拷锟斤拷5'b0
    output          ws_valid,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟斤拷
    output [31:0]   rf_rdata,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟斤拷

    // trace debug interface
    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata

    `elsif perftest_or_linux

    input           break_point,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟缴ｏ拷锟斤拷锟斤拷1'b0
    input           infor_flag,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟缴ｏ拷锟斤拷锟斤拷1'b0
    input  [ 4:0]   reg_num,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟缴ｏ拷锟斤拷锟斤拷5'b0
    output          ws_valid,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟斤拷
    output [31:0]   rf_rdata,//锟斤拷锟斤拷实锟街癸拷锟杰ｏ拷锟斤拷锟结供锟接口硷拷锟斤拷

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
wire clk = aclk;
wire resetn = aresetn;


reg valid;


wire pc_reg_in_valid;
wire pc_reg_stall; 
wire pc_reg_out_valid;

wire [31:0] pc_reg_npc; 
wire [31:0] pc_reg_pc;




wire if1_if2_reg_in_valid;
wire if1_if2_reg_stall; 
wire [31:0] if1_if2_reg_in_pc;
wire [31:0] if1_if2_reg_in_pc_offset;
wire [31:0] if1_if2_reg_in_pc_pa;

wire if1_if2_reg_out_valid;
wire [31:0] if1_if2_reg_out_pc;
wire [31:0] if1_if2_reg_out_pc_offset;
wire [31:0] if1_if2_reg_out_pc_pa;

wire if2_id_reg_stall; 
wire if2_id_reg_in_valid;
wire if2_id_reg_out_valid;
wire [31:0] if2_id_reg_in_pc;
wire [31:0] if2_id_reg_in_instruction;
wire [31:0] if2_id_reg_in_pc_offset;


wire [31:0] if2_id_reg_out_pc;
wire [31:0] if2_id_reg_out_instruction;
wire [31:0] if2_id_reg_out_pc_offset;

wire [31:0] id_exe_reg_out_instruction;
wire [31:0] exe_mem1_reg_out_instruction;
wire [31:0] mem1_mem2_reg_out_instruction;
wire [31:0] mem2_wb_reg_out_instruction;

// wire [31:0] gpr_dump [31:0];

wire [31:0] instruction;


wire [4:0] regfile_rj;
wire [4:0] regfile_rk;
wire [4:0] regfile_rd;
wire [31:0] regfile_rdata3;

wire [4:0] regfile_raddr1;
wire [4:0] regfile_raddr2;
wire [4:0] regfile_waddr;
wire regfile_we; 
wire [31:0] regfile_wdata; 

wire [31:0] regfile_rdata1;
wire [31:0] regfile_rdata2;

wire ctrl_regfile_we;
wire [4:0] alu_op;

wire sel_imm;
wire sel_pc;
wire [1:0] ext_simm;
wire [2:0] comparator_op;
wire [1:0] npc_selector_op;
wire [1:0] sel_regfile_wdata;
wire [2:0] sel_load_store_len;
wire [1:0] sel_id_exe_in_result;

wire [13:0] ctrl_csr_addr;
wire ctrl_csr_we;
wire ctrl_csr_re;
wire ctrl_sel_csr_wmask;
wire ctrl_csr_ertn_flush;
wire ctrl_is_sys;
wire ctrl_is_brk;
wire ctrl_is_ine;

wire [1:0] ctrl_rdcnt_rd;

wire ctrl_tlb_we;
wire [4:0] ctrl_invtlb_op;
wire ctrl_is_inst_tlbsrch;
wire ctrl_is_inst_tlbrd;
wire ctrl_is_inst_tlbwr;
wire ctrl_is_inst_tlbfill;
wire ctrl_is_inst_invtlb;

wire ctrl_is_load;
wire ctrl_is_store;
wire ctrl_tlb_change;

wire [1:0] ctrl_sel_regfile_rdata1;
wire [1:0] ctrl_sel_regfile_rdata2;

wire ctrl_is_cacop;


wire [31:0] ext_extended_imm;
wire [31:0] ext_offset26;
wire [31:0] ext_offset16;

wire [31:0] u_id_exe_in_result[3:0];


wire id_exe_reg_stall;
wire id_exe_reg_in_valid;
wire id_exe_reg_out_valid;


wire [4:0] id_exe_reg_in_regfile_raddr1;
wire [4:0] id_exe_reg_in_regfile_raddr2;
wire [4:0] id_exe_reg_in_regfile_waddr;
wire id_exe_reg_in_regfile_we;
wire [4:0] id_exe_reg_in_alu_op;
wire [1:0] id_exe_reg_in_sel_regfile_wdata;
wire id_exe_reg_in_sel_imm;
wire [31:0] id_exe_reg_in_ext_extended_imm;
wire [31:0] id_exe_reg_in_regfile_rdata1;
wire [31:0] id_exe_reg_in_regfile_rdata2;
wire [31:0] id_exe_reg_in_pc;
wire [31:0] id_exe_reg_in_result;
wire id_exe_reg_in_sel_pc;
wire [2:0] id_exe_reg_in_sel_load_store_len;
wire [2:0] id_exe_reg_in_comparator_op;
wire [1:0] id_exe_reg_in_npc_selector_op;
wire [31:0] id_exe_reg_in_next_pc;
wire [31:0] id_exe_reg_in_pc_offset;
wire id_exe_reg_in_is_load;
wire id_exe_reg_in_is_store;
wire id_exe_reg_in_tlb_change;
wire id_exe_reg_in_comparator_compared_result;
wire id_exe_reg_in_is_cacop;


wire [4:0] id_exe_reg_out_regfile_raddr1;
wire [4:0] id_exe_reg_out_regfile_raddr2;
wire [4:0] id_exe_reg_out_regfile_waddr;
wire id_exe_reg_out_regfile_we;
wire [4:0] id_exe_reg_out_alu_op;
wire [1:0] id_exe_reg_out_sel_regfile_wdata;
wire id_exe_reg_out_sel_imm;
wire [31:0] id_exe_reg_out_ext_extended_imm;
wire [31:0] id_exe_reg_out_regfile_rdata1;
wire [31:0] id_exe_reg_out_regfile_rdata2;
wire [31:0] id_exe_reg_out_pc;
wire [31:0] id_exe_reg_out_result;
wire id_exe_reg_out_sel_pc;
wire [2:0] id_exe_reg_out_sel_load_store_len;
wire [2:0] id_exe_reg_out_comparator_op;
wire [1:0] id_exe_reg_out_npc_selector_op;
wire [31:0] id_exe_reg_out_next_pc;
wire [31:0] id_exe_reg_out_pc_offset;
wire id_exe_reg_out_is_load;
wire id_exe_reg_out_is_store;
wire id_exe_reg_out_tlb_change;
wire id_exe_reg_out_comparator_compared_result;
wire id_exe_reg_out_is_cacop;

wire [31:0] alu_operand1;
wire [31:0] alu_operand2;

wire [31:0] alu_result;
wire alu_multiply_divide_ready;


wire [31:0] comparator_operand1;
wire [31:0] comparator_operand2;
wire comparator_compared_result;

wire exe_mem1_reg_stall;

wire exe_mem1_reg_in_valid;
wire exe_mem1_reg_out_valid;


wire [4:0] exe_mem1_reg_in_regfile_waddr;
wire exe_mem1_reg_in_regfile_we;
wire [1:0] exe_mem1_reg_in_sel_regfile_wdata;
wire [31:0] exe_mem1_reg_in_result;
wire [31:0] exe_mem1_reg_in_pc;
wire [2:0] exe_mem1_reg_in_sel_load_store_len;
wire [4:0] exe_mem1_reg_in_regfile_raddr1;
wire [4:0] exe_mem1_reg_in_regfile_raddr2;
wire [31:0] exe_mem1_reg_in_regfile_rdata1;
wire [31:0] exe_mem1_reg_in_regfile_rdata2;
wire [31:0] exe_mem1_reg_in_vaddr;
wire exe_mem1_reg_in_is_inst_jirl;
wire [31:0] exe_mem1_reg_in_pc_offset;
wire [31:0] exe_mem1_reg_in_imm;
wire [31:0] mem1_mem2_reg_in_data_pa;
wire exe_mem1_reg_in_is_load;
wire exe_mem1_reg_in_is_store;
wire exe_mem1_reg_in_tlb_change;
wire exe_mem1_reg_in_is_cacop;

wire [4:0] exe_mem1_reg_out_regfile_waddr;
wire exe_mem1_reg_out_regfile_we;
wire [1:0] exe_mem1_reg_out_sel_regfile_wdata;
wire [31:0] exe_mem1_reg_out_result;
wire [31:0] exe_mem1_reg_out_pc;
wire [2:0] exe_mem1_reg_out_sel_load_store_len;
wire [4:0] exe_mem1_reg_out_regfile_raddr1;
wire [4:0] exe_mem1_reg_out_regfile_raddr2;
wire [31:0] exe_mem1_reg_out_regfile_rdata1;
wire [31:0] exe_mem1_reg_out_regfile_rdata2;
wire [31:0] exe_mem1_reg_out_vaddr;
wire exe_mem1_reg_out_is_inst_jirl;
wire [31:0] exe_mem1_reg_out_pc_offset;
wire [31:0] exe_mem1_reg_out_imm;
wire [31:0] mem1_mem2_reg_out_data_pa;
wire exe_mem1_reg_out_is_load;
wire exe_mem1_reg_out_is_store;
wire exe_mem1_reg_out_tlb_change;
wire exe_mem1_reg_out_is_cacop;

wire [1:0] select_store_addr;
wire [31:0] select_store_data;
wire [2:0] select_store_sel_load_store_len;
wire select_store_we;

wire [3:0] select_store_modified_we;
wire [31:0] select_store_result;



wire mem1_mem2_reg_stall;
    
wire mem1_mem2_reg_in_valid;
wire mem1_mem2_reg_out_valid;


wire [4:0] mem1_mem2_reg_in_regfile_waddr;
wire mem1_mem2_reg_in_regfile_we;
wire [1:0] mem1_mem2_reg_in_sel_regfile_wdata;
wire [31:0] mem1_mem2_reg_in_result;
wire [31:0] mem1_mem2_reg_in_pc;
wire [2:0] mem1_mem2_reg_in_sel_load_store_len;
wire [4:0] mem1_mem2_reg_in_regfile_raddr1;
wire [4:0] mem1_mem2_reg_in_regfile_raddr2;
wire [31:0] mem1_mem2_reg_in_regfile_rdata1;
wire [31:0] mem1_mem2_reg_in_regfile_rdata2;
wire [31:0] mem1_mem2_reg_in_vaddr;
wire mem1_mem2_reg_in_is_load;
wire mem1_mem2_reg_in_is_store;
wire mem1_mem2_reg_in_tlb_change;
wire mem1_mem2_reg_in_is_cacop;

wire [4:0] mem1_mem2_reg_out_regfile_waddr;
wire mem1_mem2_reg_out_regfile_we;
wire [1:0] mem1_mem2_reg_out_sel_regfile_wdata;
wire [31:0] mem1_mem2_reg_out_result;
wire [31:0] mem1_mem2_reg_out_pc;
wire [2:0] mem1_mem2_reg_out_sel_load_store_len;
wire [4:0] mem1_mem2_reg_out_regfile_raddr1;
wire [4:0] mem1_mem2_reg_out_regfile_raddr2;
wire [31:0] mem1_mem2_reg_out_regfile_rdata1;
wire [31:0] mem1_mem2_reg_out_regfile_rdata2;
wire [31:0] mem1_mem2_reg_out_vaddr;
wire mem1_mem2_reg_out_is_load;
wire mem1_mem2_reg_out_is_store;
wire mem1_mem2_reg_out_tlb_change;
wire mem1_mem2_reg_out_is_cacop;


wire [1:0] select_load_addr;
wire [31:0] select_load_data;
wire [2:0] select_load_sel_load_store_len;

wire [31:0] select_load_result;


wire mem2_wb_reg_stall;
wire mem2_wb_reg_in_valid;
wire mem2_wb_reg_out_valid;

wire [4:0] mem2_wb_reg_in_regfile_waddr;
wire mem2_wb_reg_in_regfile_we;
wire [31:0] mem2_wb_reg_in_result;
wire [31:0] mem2_wb_reg_in_pc;
wire [4:0] mem2_wb_reg_in_regfile_raddr1;
wire [4:0] mem2_wb_reg_in_regfile_raddr2;
wire [31:0] mem2_wb_reg_in_regfile_rdata1;
wire [31:0] mem2_wb_reg_in_regfile_rdata2;
wire [31:0] mem2_wb_reg_in_vaddr;
wire mem2_wb_reg_in_is_load;
wire mem2_wb_reg_in_is_store;
wire mem2_wb_reg_in_tlb_change;

wire [4:0] mem2_wb_reg_out_regfile_waddr;
wire mem2_wb_reg_out_regfile_we;
wire [31:0] mem2_wb_reg_out_result;
wire [31:0] mem2_wb_reg_out_pc;
wire [4:0] mem2_wb_reg_out_regfile_raddr1;
wire [4:0] mem2_wb_reg_out_regfile_raddr2;
wire [31:0] mem2_wb_reg_out_regfile_rdata1;
wire [31:0] mem2_wb_reg_out_regfile_rdata2;
wire [31:0] mem2_wb_reg_out_vaddr;
wire mem2_wb_reg_out_is_load;
wire mem2_wb_reg_out_is_store;
wire mem2_wb_reg_out_tlb_change;

reg [31:0] id_select_regfile_rdata1;
reg [31:0] id_select_regfile_rdata2;
reg [31:0] id_select_rdata_rj;
reg [31:0] id_select_rdata_rk;
reg [31:0] id_select_rdata_rd;


wire [31:0] exe_select_regfile_rdata1;
wire [31:0] exe_select_regfile_rdata2;


wire if1_valid;
wire if2_valid;
wire id_valid;
wire exe_valid;
wire mem1_valid;
wire mem2_valid;
wire wb_valid;

wire pc_reg_clear;
wire if1_if2_reg_clear;
wire if2_id_reg_clear;
wire id_exe_reg_clear;
wire exe_mem1_reg_clear;
wire mem1_mem2_reg_clear;
wire mem2_wb_reg_clear;


wire [31:0] inst_stall_buffer_in_data;

wire [31:0] inst_stall_buffer_out_data;


wire [31:0] data_stall_buffer_in_data;

wire [31:0] data_stall_buffer_out_data;


wire [31:0] id_next_pc;
wire [31:0] exe_next_pc;
wire [31:0] mem1_next_pc;

wire id_not_branch_taken;
wire exe_not_branch_taken;
wire mem1_not_branch_taken;
wire wb_refetch;
reg [63:0] rdcnt;

wire is_int;
wire is_sys;
wire is_adef;
wire is_ale;
wire is_brk;
wire is_ine;

wire pc_state_in_is_exception;
wire pc_state_in_is_adef;

wire pc_state_out_is_exception;
wire pc_state_out_is_adef;

wire if1_if2_state_in_is_exception;
wire if1_if2_state_in_is_adef;
wire if1_if2_state_in_is_tlbr;
wire if1_if2_state_in_is_inst_tlbr;
wire if1_if2_state_in_is_inst_pif;
wire if1_if2_state_in_is_inst_ppi;

wire [1:0] if1_if2_state_in_mmu_inst_mat;

wire if1_if2_state_out_is_exception;
wire if1_if2_state_out_is_adef;
wire if1_if2_state_out_is_tlbr;
wire if1_if2_state_out_is_inst_tlbr;
wire if1_if2_state_out_is_inst_pif;
wire if1_if2_state_out_is_inst_ppi;

wire [1:0] if1_if2_state_out_mmu_inst_mat;

wire if2_id_state_in_is_exception;
wire if2_id_state_in_is_adef;
wire if2_id_state_in_is_tlbr;
wire if2_id_state_in_is_inst_tlbr;
wire if2_id_state_in_is_inst_pif;
wire if2_id_state_in_is_inst_ppi;

wire if2_id_state_out_is_exception;
wire if2_id_state_out_is_adef;
wire if2_id_state_out_is_tlbr;
wire if2_id_state_out_is_inst_tlbr;
wire if2_id_state_out_is_inst_pif;
wire if2_id_state_out_is_inst_ppi;

wire id_exe_state_in_is_exception;
wire id_exe_state_in_is_sys;
wire id_exe_state_in_is_int;
wire id_exe_state_in_ertn_flush;
wire [13:0] id_exe_state_in_csr_addr;
wire id_exe_state_in_csr_we;
wire id_exe_state_in_csr_re;


wire id_exe_state_in_is_adef;
wire id_exe_state_in_is_ine;
wire id_exe_state_in_is_brk;

wire id_exe_state_in_tlb_we;
wire [4:0] id_exe_state_in_invtlb_op;
wire id_exe_state_in_is_inst_tlbsrch;
wire id_exe_state_in_is_inst_tlbrd;
wire id_exe_state_in_is_inst_tlbwr;
wire id_exe_state_in_is_inst_tlbfill;
wire id_exe_state_in_is_inst_invtlb;

wire id_exe_state_in_is_tlbr;
wire id_exe_state_in_is_inst_tlbr;
wire id_exe_state_in_is_inst_pif;
wire id_exe_state_in_is_inst_ppi;

wire  id_exe_state_out_is_exception;
wire  id_exe_state_out_is_sys;
wire  id_exe_state_out_is_int;
wire  id_exe_state_out_ertn_flush;
wire  [13:0] id_exe_state_out_csr_addr;
wire  id_exe_state_out_csr_we;
wire  id_exe_state_out_csr_re;

wire  id_exe_state_out_is_adef;
wire  id_exe_state_out_is_ine;
wire  id_exe_state_out_is_brk;

wire id_exe_state_out_tlb_we;
wire [4:0] id_exe_state_out_invtlb_op;
wire id_exe_state_out_is_inst_tlbsrch;
wire id_exe_state_out_is_inst_tlbrd;
wire id_exe_state_out_is_inst_tlbwr;
wire id_exe_state_out_is_inst_tlbfill;
wire id_exe_state_out_is_inst_invtlb;

wire id_exe_state_out_is_tlbr;
wire id_exe_state_out_is_inst_tlbr;
wire id_exe_state_out_is_inst_pif;
wire id_exe_state_out_is_inst_ppi;



wire exe_mem1_state_in_is_exception;
wire exe_mem1_state_in_is_sys;
wire exe_mem1_state_in_is_int;
wire exe_mem1_state_in_ertn_flush;
wire [13:0] exe_mem1_state_in_csr_addr;
wire exe_mem1_state_in_csr_we;
wire exe_mem1_state_in_csr_re;

wire exe_mem1_state_in_is_adef;
wire exe_mem1_state_in_is_ine;
wire exe_mem1_state_in_is_brk;
wire exe_mem1_state_in_is_ale;

wire exe_mem1_state_in_tlb_we;
wire [4:0] exe_mem1_state_in_invtlb_op;
wire exe_mem1_state_in_is_inst_tlbsrch;
wire exe_mem1_state_in_is_inst_tlbrd;
wire exe_mem1_state_in_is_inst_tlbwr;
wire exe_mem1_state_in_is_inst_tlbfill;
wire exe_mem1_state_in_is_inst_invtlb;

wire exe_mem1_state_in_is_tlbr;
wire exe_mem1_state_in_is_inst_tlbr;
wire exe_mem1_state_in_is_inst_pif;
wire exe_mem1_state_in_is_inst_ppi;

wire exe_mem1_state_out_is_exception;
wire exe_mem1_state_out_is_sys;
wire exe_mem1_state_out_is_int;
wire exe_mem1_state_out_ertn_flush;
wire [13:0] exe_mem1_state_out_csr_addr;
wire exe_mem1_state_out_csr_we;
wire exe_mem1_state_out_csr_re;

wire exe_mem1_state_out_is_adef;
wire exe_mem1_state_out_is_ine;
wire exe_mem1_state_out_is_brk;
wire exe_mem1_state_out_is_ale;


wire exe_mem1_state_out_tlb_we;
wire [4:0] exe_mem1_state_out_invtlb_op;
wire exe_mem1_state_out_is_inst_tlbsrch;
wire exe_mem1_state_out_is_inst_tlbrd;
wire exe_mem1_state_out_is_inst_tlbwr;
wire exe_mem1_state_out_is_inst_tlbfill;
wire exe_mem1_state_out_is_inst_invtlb;

wire exe_mem1_state_out_is_tlbr;
wire exe_mem1_state_out_is_inst_tlbr;
wire exe_mem1_state_out_is_inst_pif;
wire exe_mem1_state_out_is_inst_ppi;


wire mem1_mem2_state_in_is_exception;
wire mem1_mem2_state_in_is_sys;
wire mem1_mem2_state_in_is_int;
wire mem1_mem2_state_in_ertn_flush;
wire [13:0] mem1_mem2_state_in_csr_addr;
wire mem1_mem2_state_in_csr_we;
wire mem1_mem2_state_in_csr_re;

wire mem1_mem2_state_in_is_adef;
wire mem1_mem2_state_in_is_ine;
wire mem1_mem2_state_in_is_brk;
wire mem1_mem2_state_in_is_ale;

wire mem1_mem2_state_in_tlb_we;
wire [4:0] mem1_mem2_state_in_invtlb_op;
wire mem1_mem2_state_in_is_inst_tlbsrch;
wire mem1_mem2_state_in_is_inst_tlbrd;
wire mem1_mem2_state_in_is_inst_tlbwr;
wire mem1_mem2_state_in_is_inst_tlbfill;
wire mem1_mem2_state_in_is_inst_invtlb;

wire mem1_mem2_state_in_is_tlbr;
wire mem1_mem2_state_in_is_inst_tlbr;
wire mem1_mem2_state_in_is_inst_pif;
wire mem1_mem2_state_in_is_inst_ppi;
wire mem1_mem2_state_in_is_data_tlbr;
wire mem1_mem2_state_in_is_data_pil;
wire mem1_mem2_state_in_is_data_pis;
wire mem1_mem2_state_in_is_data_ppi;
wire mem1_mem2_state_in_is_data_pme;

wire mem1_mem2_state_in_tlbsrch_hit;
wire mem1_mem2_state_in_tlbrd_hit;
wire [31:0] mem1_mem2_state_in_tlb_w_csr_tlbelo0;
wire [31:0] mem1_mem2_state_in_tlb_w_csr_tlbelo1;
wire [31:0] mem1_mem2_state_in_tlb_w_csr_tlbidx;
wire [31:0] mem1_mem2_state_in_tlb_w_csr_tlbehi;
wire [31:0] mem1_mem2_state_in_tlb_w_csr_asid;

wire [1:0] mem1_mem2_state_in_mmu_data_mat;


wire mem1_mem2_state_out_is_exception;
wire mem1_mem2_state_out_is_sys;
wire mem1_mem2_state_out_is_int;
wire mem1_mem2_state_out_ertn_flush;
wire [13:0] mem1_mem2_state_out_csr_addr;
wire mem1_mem2_state_out_csr_we;
wire mem1_mem2_state_out_csr_re;

wire mem1_mem2_state_out_is_adef;
wire mem1_mem2_state_out_is_ine;
wire mem1_mem2_state_out_is_brk;
wire mem1_mem2_state_out_is_ale;



wire mem1_mem2_state_out_tlb_we;
wire [4:0] mem1_mem2_state_out_invtlb_op;
wire mem1_mem2_state_out_is_inst_tlbsrch;
wire mem1_mem2_state_out_is_inst_tlbrd;
wire mem1_mem2_state_out_is_inst_tlbwr;
wire mem1_mem2_state_out_is_inst_tlbfill;
wire mem1_mem2_state_out_is_inst_invtlb;

wire mem1_mem2_state_out_tlbsrch_hit;
wire mem1_mem2_state_out_tlbrd_hit;
wire [31:0] mem1_mem2_state_out_tlb_w_csr_tlbelo0;
wire [31:0] mem1_mem2_state_out_tlb_w_csr_tlbelo1;
wire [31:0] mem1_mem2_state_out_tlb_w_csr_tlbidx;
wire [31:0] mem1_mem2_state_out_tlb_w_csr_tlbehi;
wire [31:0] mem1_mem2_state_out_tlb_w_csr_asid;

wire mem1_mem2_state_out_is_tlbr;
wire mem1_mem2_state_out_is_inst_tlbr;
wire mem1_mem2_state_out_is_inst_pif;
wire mem1_mem2_state_out_is_inst_ppi;
wire mem1_mem2_state_out_is_data_tlbr;
wire mem1_mem2_state_out_is_data_pil;
wire mem1_mem2_state_out_is_data_pis;
wire mem1_mem2_state_out_is_data_ppi;
wire mem1_mem2_state_out_is_data_pme;

wire [1:0] mem1_mem2_state_out_mmu_data_mat;




wire mem2_wb_state_in_is_exception;
wire mem2_wb_state_in_is_sys;
wire mem2_wb_state_in_is_int;
wire mem2_wb_state_in_ertn_flush;
wire [13:0] mem2_wb_state_in_csr_addr;
wire mem2_wb_state_in_csr_we;
wire mem2_wb_state_in_csr_re;

wire mem2_wb_state_in_is_adef;
wire mem2_wb_state_in_is_ine;
wire mem2_wb_state_in_is_brk;
wire mem2_wb_state_in_is_ale;

wire mem2_wb_state_in_tlb_we;
wire [4:0] mem2_wb_state_in_invtlb_op;
wire mem2_wb_state_in_is_inst_tlbsrch;
wire mem2_wb_state_in_is_inst_tlbrd;
wire mem2_wb_state_in_is_inst_tlbwr;
wire mem2_wb_state_in_is_inst_tlbfill;
wire mem2_wb_state_in_is_inst_invtlb;

wire mem2_wb_state_in_tlbsrch_hit;
wire mem2_wb_state_in_tlbrd_hit;
wire [31:0] mem2_wb_state_in_tlb_w_csr_tlbelo0;
wire [31:0] mem2_wb_state_in_tlb_w_csr_tlbelo1;
wire [31:0] mem2_wb_state_in_tlb_w_csr_tlbidx;
wire [31:0] mem2_wb_state_in_tlb_w_csr_tlbehi;
wire [31:0] mem2_wb_state_in_tlb_w_csr_asid;


wire mem2_wb_state_in_is_tlbr;
wire mem2_wb_state_in_is_inst_tlbr;
wire mem2_wb_state_in_is_inst_pif;
wire mem2_wb_state_in_is_inst_ppi;
wire mem2_wb_state_in_is_data_tlbr;
wire mem2_wb_state_in_is_data_pil;
wire mem2_wb_state_in_is_data_pis;
wire mem2_wb_state_in_is_data_ppi;
wire mem2_wb_state_in_is_data_pme;

wire mem2_wb_state_out_is_exception;
wire mem2_wb_state_out_is_sys;
wire mem2_wb_state_out_is_int;
wire mem2_wb_state_out_ertn_flush;
wire [13:0] mem2_wb_state_out_csr_addr;
wire mem2_wb_state_out_csr_we;
wire mem2_wb_state_out_csr_re;

wire mem2_wb_state_out_is_adef;
wire mem2_wb_state_out_is_ine;
wire mem2_wb_state_out_is_brk;
wire mem2_wb_state_out_is_ale;

wire mem2_wb_state_out_tlb_we;
wire [4:0] mem2_wb_state_out_invtlb_op;
wire mem2_wb_state_out_is_inst_tlbsrch;
wire mem2_wb_state_out_is_inst_tlbrd;
wire mem2_wb_state_out_is_inst_tlbwr;
wire mem2_wb_state_out_is_inst_tlbfill;
wire mem2_wb_state_out_is_inst_invtlb;

wire mem2_wb_state_out_tlbsrch_hit;
wire mem2_wb_state_out_tlbrd_hit;
wire [31:0] mem2_wb_state_out_tlb_w_csr_tlbelo0;
wire [31:0] mem2_wb_state_out_tlb_w_csr_tlbelo1;
wire [31:0] mem2_wb_state_out_tlb_w_csr_tlbidx;
wire [31:0] mem2_wb_state_out_tlb_w_csr_tlbehi;
wire [31:0] mem2_wb_state_out_tlb_w_csr_asid;

wire mem2_wb_state_out_is_tlbr;
wire mem2_wb_state_out_is_inst_tlbr;
wire mem2_wb_state_out_is_inst_pif;
wire mem2_wb_state_out_is_inst_ppi;
wire mem2_wb_state_out_is_data_tlbr;
wire mem2_wb_state_out_is_data_pil;
wire mem2_wb_state_out_is_data_pis;
wire mem2_wb_state_out_is_data_ppi;
wire mem2_wb_state_out_is_data_pme;

wire [7:0] csr_regfile_intrpt;
wire csr_regfile_ipi_int;
wire [31:0] csr_regfile_pc;
wire [31:0] csr_regfile_vaddr;
wire [13:0] csr_regfile_raddr;
wire [31:0] csr_regfile_rdata;
wire [13:0] csr_regfile_waddr;
wire csr_regfile_we;
wire [31:0] csr_regfile_wdata;
wire [31:0] csr_regfile_wmask;
wire csr_regfile_is_exception;
wire csr_regfile_ertn_flush;
wire csr_regfile_has_int;
wire csr_regfile_is_int;
wire csr_regfile_is_sys;
wire csr_regfile_is_adef;
wire csr_regfile_is_ale;
wire csr_regfile_is_brk;
wire csr_regfile_is_ine;
wire [31:0] csr_regfile_exception_enter_addr;
wire [31:0] csr_regfile_exception_return_addr;

wire [31:0] csr_regfile_out_csr_crmd;
wire [31:0] csr_regfile_out_csr_dmw0;
wire [31:0] csr_regfile_out_csr_dmw1;
wire [31:0] csr_regfile_out_csr_asid;
wire [31:0] csr_regfile_out_csr_estat;
wire [31:0] csr_regfile_out_csr_tlbidx;
wire [31:0] csr_regfile_out_csr_tlbehi;
wire [31:0] csr_regfile_out_csr_tlbelo0;
wire [31:0] csr_regfile_out_csr_tlbelo1;


wire csr_regfile_is_tlbsrch;
wire csr_regfile_tlbsrch_hit;
wire csr_regfile_is_tlbrd;
wire csr_regfile_tlbrd_hit;
wire [31:0] csr_regfile_tlb_w_csr_tlbelo0;
wire [31:0] csr_regfile_tlb_w_csr_tlbelo1;
wire [31:0] csr_regfile_tlb_w_csr_tlbidx;
wire [31:0] csr_regfile_tlb_w_csr_tlbehi;
wire [31:0] csr_regfile_tlb_w_csr_asid;

wire [31:0] csr_regfile_exception_tlb_enter_addr;

wire csr_regfile_is_tlbr;
wire csr_regfile_is_inst_tlbr;
wire csr_regfile_is_inst_pif;
wire csr_regfile_is_inst_ppi;
wire csr_regfile_is_data_tlbr;
wire csr_regfile_is_data_pil;
wire csr_regfile_is_data_pis;
wire csr_regfile_is_data_ppi;
wire csr_regfile_is_data_pme;

wire csr_regfile_is_ll_w;
wire csr_regfile_is_sc_w;
wire csr_regfile_llbit;



//wire sram_req;
//wire sram_wr;
//wire sram_addr_ok;
//wire sram_data_ok;
//wire [1:0] sram_size;
//wire [3:0] sram_wstrb;
//wire [31:0] sram_addr;
//wire [31:0] sram_wdata;
//wire [31:0] sram_rdata;
//wire sram_read_id;

wire mem1_tlb_change;

wire [ 1:0] mmu_csr_crmd_plv;   
wire        mmu_csr_crmd_da;    
wire        mmu_csr_crmd_pg;     
wire [ 1:0] mmu_csr_crmd_datf;  
wire [ 1:0] mmu_csr_crmd_datm;   
wire [31:0] mmu_csr_dmw0;   
wire [31:0] mmu_csr_dmw1;  
wire [ 9:0] mmu_csr_asid_asid;   
wire [21:16] mmu_csr_estat_ecode;
wire  [ 3:0] mmu_csr_tlbidx_index;
wire [29:24] mmu_csr_tlbidx_ps;
wire         mmu_csr_tlbidx_ne;
wire [31:13] mmu_csr_tlbehi_vppn;
wire         mmu_csr_tlbelo0_v;
wire         mmu_csr_tlbelo0_d;
wire  [ 3:2] mmu_csr_tlbelo0_plv;
wire  [ 5:4] mmu_csr_tlbelo0_mat;
wire         mmu_csr_tlbelo0_g;
wire  [27:8] mmu_csr_tlbelo0_ppn;
wire         mmu_csr_tlbelo1_v;
wire         mmu_csr_tlbelo1_d;
wire  [ 3:2] mmu_csr_tlbelo1_plv;
wire  [ 5:4] mmu_csr_tlbelo1_mat;
wire         mmu_csr_tlbelo1_g;
wire  [27:8] mmu_csr_tlbelo1_ppn;

wire [31:0] mmu_inst_va;  
wire [31:0] mmu_data_va;         
wire [ 1:0] mmu_data_mem_type;   

wire mmu_is_tlbsrch;
wire mmu_is_tlbrd;
wire mmu_is_tlbwr;
wire mmu_is_tlbfill;
wire mmu_is_invtlb;
wire  [ 4:0] mmu_invtlb_op;
wire  [31:0] mmu_rj;
wire  [31:0] mmu_rk;



wire         mmu_out_csr_tlbelo0_v;
wire         mmu_out_csr_tlbelo0_d;
wire  [ 3:2] mmu_out_csr_tlbelo0_plv;
wire  [ 5:4] mmu_out_csr_tlbelo0_mat;
wire         mmu_out_csr_tlbelo0_g;
wire  [27:8] mmu_out_csr_tlbelo0_ppn;

wire         mmu_out_csr_tlbelo1_v;
wire         mmu_out_csr_tlbelo1_d;
wire  [ 3:2] mmu_out_csr_tlbelo1_plv;
wire  [ 5:4] mmu_out_csr_tlbelo1_mat;
wire         mmu_out_csr_tlbelo1_g;
wire  [27:8] mmu_out_csr_tlbelo1_ppn;

wire [29:24] mmu_out_csr_tlbidx_ps;
wire         mmu_out_csr_tlbidx_ne;
wire [31:13] mmu_out_csr_tlbehi_vppn;
wire  [9 :0] mmu_out_csr_asid_asid;
wire  [ 3:0] mmu_out_csr_tlbidx_index;

wire         mmu_tlbrd_hit;
wire         mmu_tlbsrch_hit; 



       
wire [31:0] mmu_inst_pa;         
wire [ 1:0] mmu_inst_mat;        
wire        mmu_inst_ex_tlbr;   
wire        mmu_inst_ex_pif;     
wire        mmu_inst_ex_ppi;    



wire [31:0] mmu_data_pa;         
wire [ 1:0] mmu_data_mat;        
wire        mmu_data_ex_tlbr;    
wire        mmu_data_ex_pil;     
wire        mmu_data_ex_pis;     
wire        mmu_data_ex_ppi;     
wire        mmu_data_ex_pme;    

wire [31:0] tlb_w_csr_tlbelo0;
wire [31:0] tlb_w_csr_tlbelo1;
wire [31:0] tlb_w_csr_tlbidx;
wire [31:0] tlb_w_csr_tlbehi;
wire [31:0] tlb_w_csr_asid;


// wire [31:0] cache_subsystem_mmu_inst_va;
// wire [31:0] cache_subsystem_mmu_inst_pa;
// wire [1:0] cache_subsystem_mmu_inst_mat;

// wire [31:0] cache_subsystem_mmu_data_va;
// wire [31:0] cache_subsystem_mmu_data_pa;
// wire [1:0] cache_subsystem_mmu_data_mat;

// wire cache_subsystem_cacop_nop;
// wire cache_subsystem_cacop_addr_ok;
// wire cache_subsystem_cacop_data_ok;
// wire [4:0] cache_subsystem_cacop_code;
// wire [31:0] cache_subsystem_cacop_va;
// wire [31:0] cache_subsystem_cacop_pa;

wire cacop_req;
wire [1:0] cacop_fsm_state;

// assign cache_subsystem_mmu_inst_va = inst_sram_addr;
// assign cache_subsystem_mmu_inst_pa = inst_sram_addr;
// assign cache_subsystem_mmu_inst_mat = if1_if2_state_out_mmu_inst_mat;

// assign cache_subsystem_mmu_data_va = data_sram_addr;
// assign cache_subsystem_mmu_data_pa = data_sram_addr;
// assign cache_subsystem_mmu_data_mat = mem1_mem2_state_out_mmu_data_mat;

// assign cache_subsystem_cacop_nop = cacop_req;
// assign cache_subsystem_cacop_code = mem1_mem2_state_out_invtlb_op;
// assign cache_subsystem_cacop_va = mem1_mem2_reg_out_vaddr;
// assign cache_subsystem_cacop_pa = mem1_mem2_reg_out_data_pa;


sram_fsm cacop_fsm(
    .clk(clk),
    .resetn(resetn),
    
    .addr_ok(cache_subsystem_cacop_ready),
    .req(cacop_req),
    .data_ok(cache_subsystem_cacop_done),
    .not_ready_go(mem1_mem2_reg_stall),

    .state(cacop_fsm_state)

);

wire cache_subsystem_if1_valid;
wire [31:0] cache_subsystem_if1_va;
wire cache_subsystem_if1_ready;

wire cache_subsystem_if2_valid;
wire [31:0] cache_subsystem_if2_va;
wire [31:0] cache_subsystem_if2_pa;
wire [1:0] cache_subsystem_if2_mat;

wire cache_subsystem_if2_miss_req;
wire cache_subsystem_if2_miss_ready;

wire cache_subsystem_if2_array_valid;
wire cache_subsystem_if2_hit;
wire cache_subsystem_if2_miss;

wire cache_subsystem_if2_hit_way;
wire [31:0] cache_subsystem_if2_rdata;
wire cache_subsystem_if2_refill_valid;
wire [31:0] cache_subsystem_if2_refill_rdata;
wire cache_subsystem_icache_busy;

wire cache_subsystem_mem1_valid;
wire [31:0] cache_subsystem_mem1_va;

wire cache_subsystem_mem2_valid;
wire cache_subsystem_mem2_wr;
wire cache_subsystem_mem2_postable_store;
wire [1:0] cache_subsystem_mem2_size;
wire [3:0] cache_subsystem_mem2_wstrb;
wire [31:0] cache_subsystem_mem2_wdata;
wire [31:0] cache_subsystem_mem2_va;
wire [31:0] cache_subsystem_mem2_pa;
wire [31:0] cache_subsystem_mem2_pc;
wire [1:0] cache_subsystem_mem2_mat;

wire cache_subsystem_mem2_miss_req;
wire cache_subsystem_mem2_miss_ready;
wire cache_subsystem_mem2_array_valid;

wire cache_subsystem_mem2_hit;
wire cache_subsystem_mem2_miss;
wire cache_subsystem_mem2_hit_way;
wire cache_subsystem_mem2_load_done;//
wire cache_subsystem_mem2_store_done; //
wire [31:0] cache_subsystem_mem2_rdata;
wire cache_subsystem_mem2_refill_valid;
wire [31:0] cache_subsystem_mem2_refill_rdata;
wire cache_subsystem_dcache_busy;

wire cache_subsystem_cacop_valid;
wire cache_subsystem_cacop_ready;
wire cache_subsystem_cacop_done;
wire [4:0] cache_subsystem_cacop_code;
wire [31:0] cache_subsystem_cacop_va;
wire [31:0] cache_subsystem_cacop_pa;

assign cache_subsystem_if1_valid = pc_reg_out_valid && !pc_state_out_is_exception;
assign cache_subsystem_if1_va = pc_reg_pc;

assign cache_subsystem_if2_valid = if1_if2_reg_out_valid && !if1_if2_state_out_is_exception;
assign cache_subsystem_if2_va = if1_if2_reg_out_pc;
assign cache_subsystem_if2_pa = if1_if2_reg_out_pc_pa;
assign cache_subsystem_if2_mat = if1_if2_state_out_mmu_inst_mat;


assign cache_subsystem_mem1_valid = exe_mem1_reg_out_valid && !exe_mem1_state_out_is_exception;
assign cache_subsystem_mem1_va = exe_mem1_reg_out_vaddr;

assign cache_subsystem_mem2_valid = mem1_mem2_reg_out_valid && !mem1_mem2_state_out_is_exception && !mem1_mem2_reg_clear && (mem1_mem2_reg_out_is_load || (mem1_mem2_reg_out_is_store && !mem1_mem2_reg_out_is_inst_sc_w) || 
            (mem1_mem2_reg_out_is_inst_sc_w && csr_regfile_llbit)) ;
assign cache_subsystem_mem2_wr = data_sram_wr;

// Posted store: 普通 cacheable store 允许在 refill 完成前就对 CPU 报完成，
// 由 D-cache 在后台把数据合并进 refill。SC 必须同步返回结果，不能 post。
// uncached store 由 cache 内部的 miss_launch_cacheable_w 天然排除。
assign cache_subsystem_mem2_postable_store =
    mem1_mem2_reg_out_is_store && !mem1_mem2_reg_out_is_inst_sc_w;
assign cache_subsystem_mem2_size = data_sram_size;
assign cache_subsystem_mem2_wstrb = data_sram_wstrb;
assign cache_subsystem_mem2_wdata = data_sram_wdata;
assign cache_subsystem_mem2_va = mem1_mem2_reg_out_vaddr;
assign cache_subsystem_mem2_pa = data_sram_addr;
assign cache_subsystem_mem2_pc = mem1_mem2_reg_out_pc;
assign cache_subsystem_mem2_mat = mem1_mem2_state_out_mmu_data_mat;

// assign cache_subsystem_mem2_miss_req = 1'b0;



assign cache_subsystem_cacop_valid = cacop_req;
assign cache_subsystem_cacop_code = mem1_mem2_state_out_invtlb_op;
assign cache_subsystem_cacop_va = mem1_mem2_reg_out_vaddr;
assign cache_subsystem_cacop_pa = mem1_mem2_reg_out_data_pa;




cache_subsystem u_cache_subsystem(
    .clk(clk),
    .resetn(resetn),

    .if1_valid(cache_subsystem_if1_valid),
    .if1_va(cache_subsystem_if1_va),
    .if1_ready(cache_subsystem_if1_ready),

    .if2_valid(cache_subsystem_if2_valid),
    .if2_va(cache_subsystem_if2_va),
    .if2_pa(cache_subsystem_if2_pa),
    .if2_mat(cache_subsystem_if2_mat),

    .if2_miss_req(cache_subsystem_if2_miss_req),
    .if2_miss_ready(cache_subsystem_if2_miss_ready),
    
    .if2_array_valid(cache_subsystem_if2_array_valid),
    .if2_hit(cache_subsystem_if2_hit),
    .if2_miss(cache_subsystem_if2_miss),

    .if2_hit_way(cache_subsystem_if2_hit_way),
    .if2_rdata(cache_subsystem_if2_rdata),
    .if2_refill_valid(cache_subsystem_if2_refill_valid),
    .if2_refill_rdata(cache_subsystem_if2_refill_rdata),
    .icache_busy(cache_subsystem_icache_busy),

    .mem1_valid(cache_subsystem_mem1_valid),
    .mem1_va(cache_subsystem_mem1_va),

    .mem2_valid(cache_subsystem_mem2_valid),
    .mem2_wr(cache_subsystem_mem2_wr),
    .mem2_postable_store(cache_subsystem_mem2_postable_store),
    .mem2_size(cache_subsystem_mem2_size),
    .mem2_wstrb(cache_subsystem_mem2_wstrb),
    .mem2_wdata(cache_subsystem_mem2_wdata),
    .mem2_va(cache_subsystem_mem2_va),
    .mem2_pa(cache_subsystem_mem2_pa),
    .mem2_pc(cache_subsystem_mem2_pc),
    .mem2_mat(cache_subsystem_mem2_mat),

    .mem2_miss_req(cache_subsystem_mem2_miss_req),
    .mem2_miss_ready(cache_subsystem_mem2_miss_ready),
    .mem2_array_valid(cache_subsystem_mem2_array_valid),
    
    .mem2_hit(cache_subsystem_mem2_hit),
    .mem2_miss(cache_subsystem_mem2_miss),
    .mem2_hit_way(cache_subsystem_mem2_hit_way),
    .mem2_load_done(cache_subsystem_mem2_load_done),
    .mem2_store_done(cache_subsystem_mem2_store_done),
    .mem2_rdata(cache_subsystem_mem2_rdata),
    .mem2_refill_valid(cache_subsystem_mem2_refill_valid),
    .mem2_refill_rdata(cache_subsystem_mem2_refill_rdata),
    .dcache_busy(cache_subsystem_dcache_busy),

    .cacop_valid(cache_subsystem_cacop_valid),
    .cacop_ready(cache_subsystem_cacop_ready),
    .cacop_done(cache_subsystem_cacop_done),
    .cacop_code(cache_subsystem_cacop_code),
    .cacop_va(cache_subsystem_cacop_va),
    .cacop_pa(cache_subsystem_cacop_pa),

    
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),
    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)






);

wire inst_sram_req;
wire data_sram_req;

wire [2:0] inst_sram_fsm_state;
wire [2:0] data_sram_fsm_state;


wire inst_sram_req;
wire inst_sram_wr;
wire [1 :0] inst_sram_size;
wire [3 :0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire inst_sram_addr_ok;
wire inst_sram_data_ok;
wire [31:0] inst_sram_rdata;
assign inst_sram_req = cache_subsystem_if2_miss_req;
assign inst_sram_addr_ok = cache_subsystem_if2_miss_ready;
assign inst_sram_data_ok = cache_subsystem_if2_refill_valid;
assign inst_sram_rdata = cache_subsystem_if2_hit ? cache_subsystem_if2_rdata :
                        cache_subsystem_if2_refill_valid ? cache_subsystem_if2_refill_rdata :inst_stall_buffer_out_data;


wire data_sram_req;
wire data_sram_wr;
wire [1 :0] data_sram_size;
wire [3 :0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire data_sram_addr_ok;
wire data_sram_data_ok;
wire [31:0] data_sram_rdata;
assign data_sram_req = cache_subsystem_mem2_miss_req;
assign data_sram_addr_ok = cache_subsystem_mem2_miss_ready;
assign data_sram_data_ok = cache_subsystem_mem2_refill_valid;
assign data_sram_rdata = cache_subsystem_mem2_hit ? cache_subsystem_mem2_rdata :
                        cache_subsystem_mem2_refill_valid ? cache_subsystem_mem2_refill_rdata :data_stall_buffer_out_data;


inst_sram_fsm u_inst_sram_fsm(
    .clk(clk),
    .resetn(resetn),

    .hit(cache_subsystem_if2_hit),
    .miss(cache_subsystem_if2_miss),
    .miss_req(cache_subsystem_if2_miss_req),
    .miss_ready(cache_subsystem_if2_miss_ready),

    .refill_valid(cache_subsystem_if2_refill_valid),
    .stall(if1_if2_reg_stall),

    .state(inst_sram_fsm_state)
);

data_sram_fsm u_data_sram_fsm(
    .clk(clk),
    .resetn(resetn),

    .hit(cache_subsystem_mem2_hit),
    .miss(cache_subsystem_mem2_miss),
    .miss_req(cache_subsystem_mem2_miss_req),
    .miss_ready(cache_subsystem_mem2_miss_ready),

    .refill_valid(cache_subsystem_mem2_refill_valid),
    .stall(mem1_mem2_reg_stall),

    .state(data_sram_fsm_state)
);
 
assign inst_stall_buffer_in_data = inst_sram_rdata;

stall_buffer u_inst_stall_buffer(
    .clk(clk),
    .resetn(resetn),

    .in_rdata(inst_stall_buffer_in_data),
    .data_ok((inst_sram_fsm_state == `INST_SRAM_FSM_WAIT && inst_sram_data_ok )|| (inst_sram_fsm_state == `INST_SRAM_FSM_IDLE && cache_subsystem_if2_hit)),

    .out_rdata(inst_stall_buffer_out_data)
);


assign data_stall_buffer_in_data = data_sram_rdata;


stall_buffer u_data_stall_buffer(
    .clk(clk),
    .resetn(resetn),

    .in_rdata(data_stall_buffer_in_data),
    .data_ok((data_sram_fsm_state == `DATA_SRAM_FSM_WAIT && data_sram_data_ok )|| (data_sram_fsm_state == `DATA_SRAM_FSM_IDLE && cache_subsystem_mem2_hit)),

    .out_rdata(data_stall_buffer_out_data)

);




// cache_subsystem u_cache_subsystem(
//     .clk(clk),
//     .resetn(resetn),

//     .inst_sram_req(inst_sram_req),
//     .inst_sram_wr(inst_sram_wr),
//     .inst_sram_addr_ok(inst_sram_addr_ok),
//     .inst_sram_data_ok(inst_sram_data_ok),
//     .inst_sram_size(inst_sram_size),
//     .inst_sram_wstrb(inst_sram_wstrb),
//     .inst_sram_addr(inst_sram_addr),
//     .inst_sram_wdata(inst_sram_wdata),
//     .inst_sram_rdata(inst_sram_rdata),

//     .data_sram_req(data_sram_req),
//     .data_sram_wr(data_sram_wr),
//     .data_sram_addr_ok(data_sram_addr_ok),
//     .data_sram_data_ok(data_sram_data_ok),
//     .data_sram_size(data_sram_size),
//     .data_sram_wstrb(data_sram_wstrb),
//     .data_sram_addr(data_sram_addr),
//     .data_sram_wdata(data_sram_wdata),
//     .data_sram_rdata(data_sram_rdata),

//     .mmu_inst_va(cache_subsystem_mmu_inst_va),
//     .mmu_inst_pa(cache_subsystem_mmu_inst_pa),
//     .mmu_inst_mat(cache_subsystem_mmu_inst_mat),

//     .mmu_data_va(cache_subsystem_mmu_data_va),
//     .mmu_data_pa(cache_subsystem_mmu_data_pa),
//     .mmu_data_mat(cache_subsystem_mmu_data_mat),
    
//     .cacop_nop(cache_subsystem_cacop_nop),
//     .cacop_addr_ok(cache_subsystem_cacop_addr_ok),
//     .cacop_data_ok(cache_subsystem_cacop_data_ok),
//     .cacop_code(cache_subsystem_cacop_code),
//     .cacop_va(cache_subsystem_cacop_va),
//     .cacop_pa(cache_subsystem_cacop_pa),

//     .arid(arid),
//     .araddr(araddr),
//     .arlen(arlen),
//     .arsize(arsize),
//     .arburst(arburst),
//     .arlock(arlock),
//     .arcache(arcache),
//     .arprot(arprot),
//     .arvalid(arvalid),
//     .arready(arready),
//     .rid(rid),
//     .rdata(rdata),
//     .rresp(rresp),
//     .rlast(rlast),
//     .rvalid(rvalid),
//     .rready(rready),
//     .awid(awid),
//     .awaddr(awaddr),
//     .awlen(awlen),
//     .awsize(awsize),
//     .awburst(awburst),
//     .awlock(awlock),
//     .awcache(awcache),
//     .awprot(awprot),
//     .awvalid(awvalid),
//     .awready(awready),
//     .wid(wid),
//     .wdata(wdata),
//     .wstrb(wstrb),
//     .wlast(wlast),
//     .wvalid(wvalid),
//     .wready(wready),
//     .bid(bid),
//     .bresp(bresp),
//     .bvalid(bvalid),
//     .bready(bready)
// );





assign if1_valid = pc_reg_out_valid && !pc_reg_stall && !pc_reg_clear;
assign if2_valid = if1_if2_reg_out_valid && !if1_if2_reg_stall && !if1_if2_reg_clear;
assign id_valid = if2_id_reg_out_valid && !if2_id_reg_stall && !if2_id_reg_clear;
assign exe_valid = id_exe_reg_out_valid && !id_exe_reg_stall && !id_exe_reg_clear;
assign mem1_valid = exe_mem1_reg_out_valid && !exe_mem1_reg_stall && !exe_mem1_reg_clear;
assign mem2_valid = mem1_mem2_reg_out_valid && !mem1_mem2_reg_stall && !mem1_mem2_reg_clear;
assign wb_valid = mem2_wb_reg_out_valid && !mem2_wb_reg_stall && !mem2_wb_reg_clear;



always @(posedge clk) begin
    if(!resetn)
        valid <= 1'b0;
    else
        valid <= 1'b1;
end


always @(posedge clk) begin
    if(!resetn)
        rdcnt <= 64'd0;
    else 
        rdcnt <= rdcnt + 64'd1;
end



assign pc_reg_in_valid = valid;


pc_reg u_pc_reg(
    .clk(clk),
    .resetn(resetn),
    
    .in_valid(pc_reg_in_valid),
    .stall(pc_reg_stall),
    .out_valid(pc_reg_out_valid),

    .npc(pc_reg_npc),
    .pc(pc_reg_pc)
);

wire [31:0] branch_predictor_pc;
wire branch_predictor_update;
wire [31:0] branch_predictor_branch_pc;
wire branch_predictor_actual_taken;
wire [31:0] branch_predictor_actual_target;
wire branch_predictor_is_taken;

wire [31:0] branch_predictor_target_address;

assign branch_predictor_pc = pc_reg_pc;
assign branch_predictor_update = mem2_wb_reg_out_valid;
assign branch_predictor_branch_pc = mem2_wb_reg_out_pc;
assign branch_predictor_actual_taken = mem2_wb_reg_out_actual_taken;
assign branch_predictor_actual_target = mem2_wb_reg_out_actual_target;
// assign branch_predictor_target_address = pc_reg_pc + 32'd4;
branch_predictor u_branch_predictor(
    .clk(clk),
    .resetn(resetn),

    .pc(branch_predictor_pc),
    .update(branch_predictor_update),
    .branch_pc(branch_predictor_branch_pc),
    .actual_taken(branch_predictor_actual_taken),
    .actual_target(branch_predictor_actual_target),
    .is_taken(branch_predictor_is_taken)
    , .target_address(branch_predictor_target_address)
);






assign if1_if2_reg_in_valid = if1_valid;
assign if1_if2_reg_in_pc = pc_reg_pc;



assign if1_if2_reg_in_pc_pa = mmu_inst_pa;

if1_if2_reg u_if1_if2_reg(
    .clk(clk),
    .resetn(resetn),
    
    .in_valid(if1_if2_reg_in_valid),
    .stall(if1_if2_reg_stall),
    .pre_stall(pc_reg_stall),

    .in_pc(if1_if2_reg_in_pc),
    .in_pc_offset(if1_if2_reg_in_pc_offset),
    .in_pc_pa(if1_if2_reg_in_pc_pa),
    
    .out_valid(if1_if2_reg_out_valid),
    .out_pc(if1_if2_reg_out_pc),
    .out_pc_offset(if1_if2_reg_out_pc_offset),
    .out_pc_pa(if1_if2_reg_out_pc_pa)

);




assign if2_id_reg_in_valid = if2_valid;
assign if2_id_reg_in_pc = if1_if2_reg_out_pc;
assign if2_id_reg_in_instruction = inst_sram_rdata;

if2_id_reg u_if2_id_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(if2_id_reg_stall),
    .pre_stall(if1_if2_reg_stall),

    .in_valid(if2_id_reg_in_valid),
    .out_valid(if2_id_reg_out_valid),

    .in_pc(if2_id_reg_in_pc),
    .in_instruction(if2_id_reg_in_instruction),
    .in_pc_offset(if2_id_reg_in_pc_offset),

    .out_pc(if2_id_reg_out_pc),
    .out_instruction(if2_id_reg_out_instruction),
    .out_pc_offset(if2_id_reg_out_pc_offset)
);

assign instruction = if2_id_reg_out_instruction;



assign regfile_we = mem2_wb_reg_out_regfile_we && wb_valid && !mem2_wb_state_out_is_exception;
assign regfile_wdata = mem2_wb_reg_out_result;
assign regfile_waddr = mem2_wb_reg_out_regfile_waddr;


assign regfile_rj = instruction[9:5];
assign regfile_rk = instruction[14:10];
assign regfile_rd = instruction[4:0];

regfile u_regfile(
    .clk(clk),
    .resetn(resetn),

    .raddr1(regfile_rj),
    .raddr2(regfile_rk),
    .raddr3(regfile_rd),
    .waddr(regfile_waddr),
    .we(regfile_we),
    .wdata(regfile_wdata),

    .rdata1(regfile_rdata1),
    .rdata2(regfile_rdata2),
    .rdata3(regfile_rdata3)
    // .gpr_dump(gpr_dump)
);


wire csr_3w;
wire is_CNTinst;
wire [7:0] store_valid;
wire [7:0] load_valid;

wire ctrl_is_inst_idle;

wire ctrl_is_inst_ll_w;
wire ctrl_is_inst_sc_w;

ctrl u_ctrl(
    .instruction(instruction),
    
    .regfile_raddr1(regfile_raddr1),
    .regfile_raddr2(regfile_raddr2),
    .regfile_we(ctrl_regfile_we),
    .regfile_waddr(id_exe_reg_in_regfile_waddr),
    
    .alu_op(alu_op),
    .sel_imm(sel_imm),
    .sel_pc(sel_pc), //delete
    .ext_simm(ext_simm),

    .comparator_op(comparator_op),
    .npc_selector_op(npc_selector_op),
    .sel_regfile_wdata(sel_regfile_wdata),
    .sel_load_store_len(sel_load_store_len),
    
    .sel_id_exe_in_result(sel_id_exe_in_result),

    .csr_addr(ctrl_csr_addr),
    .csr_we(ctrl_csr_we),
    .csr_re(ctrl_csr_re),
    .sel_csr_wmask(ctrl_sel_csr_wmask),
    .csr_ertn_flush(ctrl_csr_ertn_flush),
    .is_sys(ctrl_is_sys),
    .is_brk(ctrl_is_brk),
    .is_ine(ctrl_is_ine),

    .rdcnt_rd(ctrl_rdcnt_rd),

    .tlb_we(ctrl_tlb_we),
    .invtlb_op(ctrl_invtlb_op),

    .is_inst_tlbsrch(ctrl_is_inst_tlbsrch),
    .is_inst_tlbrd(ctrl_is_inst_tlbrd),
    .is_inst_tlbwr(ctrl_is_inst_tlbwr),
    .is_inst_tlbfill(ctrl_is_inst_tlbfill),
    .is_inst_invtlb(ctrl_is_inst_invtlb),

    .is_load(ctrl_is_load),
    .is_store(ctrl_is_store),

    .tlb_change(ctrl_tlb_change),

    .sel_regfile_rdata1(ctrl_sel_regfile_rdata1),
    .sel_regfile_rdata2(ctrl_sel_regfile_rdata2),

    .is_cacop(ctrl_is_cacop),
    
    .csr_3w(csr_3w),
    .is_CNTinst(is_CNTinst),
    .load_valid(load_valid),
    .store_valid(store_valid),

    .is_inst_idle(ctrl_is_inst_idle),

    .is_inst_ll_w(ctrl_is_inst_ll_w),
    .is_inst_sc_w(ctrl_is_inst_sc_w)
);



ext u_ext(
    .instruction(instruction),
    .simm(ext_simm),
    .extended_imm(ext_extended_imm),
    .offset16(ext_offset16),
    .offset26(ext_offset26)
);

assign u_id_exe_in_result[0] = if2_id_reg_out_pc + 32'd4;
assign u_id_exe_in_result[1] = if2_id_reg_out_pc + {instruction[24:5], 12'b0};
assign u_id_exe_in_result[2] = {instruction[24:5], 12'b0};
assign u_id_exe_in_result[3] = ctrl_rdcnt_rd[1] ? rdcnt[63:32] : rdcnt[31:0];



assign id_exe_reg_in_valid = id_valid;

assign id_exe_reg_in_regfile_raddr1 = regfile_raddr1;
assign id_exe_reg_in_regfile_raddr2 = regfile_raddr2;
// assign id_exe_reg_in_regfile_waddr = regfile_waddr;
assign id_exe_reg_in_regfile_we = ctrl_regfile_we;
assign id_exe_reg_in_alu_op = alu_op;
assign id_exe_reg_in_sel_regfile_wdata = sel_regfile_wdata;
assign id_exe_reg_in_sel_imm = sel_imm;
assign id_exe_reg_in_ext_extended_imm = ctrl_is_inst_ll_w || ctrl_is_inst_sc_w ? {{16{instruction[23]}},instruction[23:10], 2'b00} : ext_extended_imm;
assign id_exe_reg_in_regfile_rdata1 = {32{ctrl_sel_csr_wmask}} | id_select_regfile_rdata1;
assign id_exe_reg_in_regfile_rdata2 = id_select_regfile_rdata2;
assign id_exe_reg_in_pc = if2_id_reg_out_pc;
assign id_exe_reg_in_result = ctrl_csr_re ? csr_regfile_rdata : u_id_exe_in_result[sel_id_exe_in_result];
assign id_exe_reg_in_sel_pc = sel_pc;
assign id_exe_reg_in_sel_load_store_len = sel_load_store_len;
assign id_exe_reg_in_comparator_op = comparator_op;
assign id_exe_reg_in_npc_selector_op = npc_selector_op;



assign id_exe_reg_in_next_pc = if2_id_reg_out_pc + ext_offset16;

assign exe_mem1_reg_in_is_inst_jirl = id_exe_reg_out_npc_selector_op == `NPC_SELECTOR_JIRL;

assign id_next_pc = npc_selector_op == `NPC_SELECTOR_B ? if2_id_reg_out_pc + ext_offset26 : if2_id_reg_out_pc + 32'd4;
assign exe_next_pc = id_exe_reg_out_comparator_compared_result ? id_exe_reg_out_next_pc : id_exe_reg_out_result;
assign mem1_next_pc = exe_mem1_reg_out_vaddr;

assign id_not_branch_taken =  if2_id_reg_out_valid && ((npc_selector_op == `NPC_SELECTOR_B  && if2_id_reg_out_pc_offset != ext_offset26) || (npc_selector_op == `NPC_SELECTOR_DEFAULT && if2_id_reg_out_pc_offset != 32'd4));
assign exe_not_branch_taken =  id_exe_reg_out_valid && id_exe_reg_out_npc_selector_op == `NPC_SELECTOR_BRANCH && 
                             ((id_exe_reg_out_comparator_compared_result && id_exe_reg_out_pc_offset != id_exe_reg_out_ext_extended_imm) 
                               || (!id_exe_reg_out_comparator_compared_result && id_exe_reg_out_pc_offset != 32'd4)); //predict
assign mem1_not_branch_taken =  exe_mem1_reg_out_valid && exe_mem1_reg_out_is_inst_jirl && exe_mem1_reg_out_valid && exe_mem1_reg_out_imm != exe_mem1_reg_out_pc_offset;



assign if1_if2_reg_in_pc_offset = branch_predictor_target_address - pc_reg_pc;//
assign if2_id_reg_in_pc_offset = if1_if2_reg_out_pc_offset;
assign id_exe_reg_in_pc_offset = if2_id_reg_out_pc_offset;
assign exe_mem1_reg_in_pc_offset = id_exe_reg_out_pc_offset;



assign exe_mem1_reg_in_imm = exe_select_regfile_rdata1 + id_exe_reg_out_ext_extended_imm - id_exe_reg_out_pc;

assign id_exe_reg_in_is_load = ctrl_is_load;
assign id_exe_reg_in_is_store = ctrl_is_store;
assign id_exe_reg_in_tlb_change = ctrl_tlb_change;
assign id_exe_reg_in_comparator_compared_result = comparator_compared_result;

assign id_exe_reg_in_is_cacop = ctrl_is_cacop;

wire id_exe_reg_in_is_inst_ll_w;
wire id_exe_reg_in_is_inst_sc_w;
wire id_exe_reg_out_is_inst_ll_w;
wire id_exe_reg_out_is_inst_sc_w;

assign id_exe_reg_in_is_inst_ll_w = ctrl_is_inst_ll_w;
assign id_exe_reg_in_is_inst_sc_w = ctrl_is_inst_sc_w;

wire id_exe_reg_in_actual_taken;
wire [31:0] id_exe_reg_in_actual_target;

wire id_exe_reg_out_actual_taken;
wire [31:0] id_exe_reg_out_actual_target;

assign id_exe_reg_in_actual_taken = npc_selector_op == `NPC_SELECTOR_B;
assign id_exe_reg_in_actual_target = id_next_pc;


id_exe_reg u_id_exe_reg(
    .clk(clk),
    .resetn(resetn),

    .stall(id_exe_reg_stall),
    .pre_stall(if2_id_reg_stall),

    .in_valid(id_exe_reg_in_valid),
    .out_valid(id_exe_reg_out_valid),


    .in_regfile_raddr1(id_exe_reg_in_regfile_raddr1),
    .in_regfile_raddr2(id_exe_reg_in_regfile_raddr2),
    .in_regfile_waddr(id_exe_reg_in_regfile_waddr),
    .in_regfile_we(id_exe_reg_in_regfile_we),
    .in_alu_op(id_exe_reg_in_alu_op),
    .in_sel_regfile_wdata(id_exe_reg_in_sel_regfile_wdata),
    .in_sel_imm(id_exe_reg_in_sel_imm),
    .in_ext_extended_imm(id_exe_reg_in_ext_extended_imm),
    .in_regfile_rdata1(id_exe_reg_in_regfile_rdata1),
    .in_regfile_rdata2(id_exe_reg_in_regfile_rdata2),
    .in_pc(id_exe_reg_in_pc),
    .in_result(id_exe_reg_in_result),
    .in_sel_pc(id_exe_reg_in_sel_pc),
    .in_sel_load_store_len(id_exe_reg_in_sel_load_store_len),
    .in_comparator_op(id_exe_reg_in_comparator_op),
    .in_npc_selector_op(id_exe_reg_in_npc_selector_op),
    .in_next_pc(id_exe_reg_in_next_pc),
    .in_pc_offset(id_exe_reg_in_pc_offset),
    .in_is_load(id_exe_reg_in_is_load),
    .in_is_store(id_exe_reg_in_is_store),
    .in_tlb_change(id_exe_reg_in_tlb_change),
    .in_comparator_compared_result(id_exe_reg_in_comparator_compared_result),
    .in_is_cacop(id_exe_reg_in_is_cacop),
    .in_instruction(if2_id_reg_out_instruction),

    .in_is_inst_ll_w(id_exe_reg_in_is_inst_ll_w),
    .in_is_inst_sc_w(id_exe_reg_in_is_inst_sc_w),

    .in_actual_taken(id_exe_reg_in_actual_taken),
    .in_actual_target(id_exe_reg_in_actual_target),


    .out_regfile_raddr1(id_exe_reg_out_regfile_raddr1),
    .out_regfile_raddr2(id_exe_reg_out_regfile_raddr2),
    .out_regfile_waddr(id_exe_reg_out_regfile_waddr),
    .out_regfile_we(id_exe_reg_out_regfile_we),
    .out_alu_op(id_exe_reg_out_alu_op),
    .out_sel_regfile_wdata(id_exe_reg_out_sel_regfile_wdata),
    .out_sel_imm(id_exe_reg_out_sel_imm),
    .out_ext_extended_imm(id_exe_reg_out_ext_extended_imm),
    .out_regfile_rdata1(id_exe_reg_out_regfile_rdata1),
    .out_regfile_rdata2(id_exe_reg_out_regfile_rdata2),
    .out_pc(id_exe_reg_out_pc),
    .out_result(id_exe_reg_out_result),
    .out_sel_pc(id_exe_reg_out_sel_pc),
    .out_sel_load_store_len(id_exe_reg_out_sel_load_store_len),
    .out_comparator_op(id_exe_reg_out_comparator_op),
    .out_npc_selector_op(id_exe_reg_out_npc_selector_op),
    .out_next_pc(id_exe_reg_out_next_pc),
    .out_pc_offset(id_exe_reg_out_pc_offset),
    .out_is_load(id_exe_reg_out_is_load),
    .out_is_store(id_exe_reg_out_is_store),
    .out_tlb_change(id_exe_reg_out_tlb_change),
    .out_comparator_compared_result(id_exe_reg_out_comparator_compared_result),
    .out_is_cacop(id_exe_reg_out_is_cacop),
    .out_instruction(id_exe_reg_out_instruction),
    
    .out_is_inst_ll_w(id_exe_reg_out_is_inst_ll_w),
    .out_is_inst_sc_w(id_exe_reg_out_is_inst_sc_w),

    .out_actual_taken(id_exe_reg_out_actual_taken),
    .out_actual_target(id_exe_reg_out_actual_target)

);



assign alu_operand1 = id_exe_reg_out_sel_pc ? id_exe_reg_out_pc : exe_select_regfile_rdata1;
assign alu_operand2 = id_exe_reg_out_sel_imm ? id_exe_reg_out_ext_extended_imm : exe_select_regfile_rdata2;
// assign op = id_exe_reg_out_alu_op;


alu u_alu(
    .clk(clk),
    .resetn(resetn),

    .stall(id_exe_reg_stall),
    .clear(id_exe_reg_clear),
    .valid(id_exe_reg_out_valid),
    .is_exception(id_exe_state_out_is_exception),
    
    .operand1(alu_operand1),
    .operand2(alu_operand2),
    .op(id_exe_reg_out_alu_op),

    .multiply_divide_ready(alu_multiply_divide_ready),
    .result(alu_result)
);


assign comparator_operand1 = id_select_rdata_rj;
assign comparator_operand2 = id_select_rdata_rd;


comparator u_comparator(
    .operand1(comparator_operand1),
    .operand2(comparator_operand2),
    .op(comparator_op),
    .compared_result(comparator_compared_result)
);


assign wb_refetch = ((mem2_wb_state_out_csr_we && 
(csr_regfile_waddr == `CSR_ADDR_CRMD || csr_regfile_waddr == `CSR_ADDR_DMW0 ||
 csr_regfile_waddr == `CSR_ADDR_DMW1 || csr_regfile_waddr == `CSR_ADDR_ASID || csr_regfile_waddr == `CSR_ADDR_ESTAT)) || (mem2_wb_state_out_is_inst_tlbfill || mem2_wb_state_out_is_inst_tlbwr || 
mem2_wb_state_out_is_inst_tlbsrch || mem2_wb_state_out_is_inst_invtlb || mem2_wb_state_out_is_inst_tlbrd /*|| mem2_wb_reg_out_is_cacop*/)) &&(mem2_wb_reg_out_valid) &&(!mem2_wb_state_out_is_exception);


assign pc_reg_npc = csr_regfile_is_exception ? (mem2_wb_state_out_is_tlbr ? csr_regfile_exception_tlb_enter_addr : csr_regfile_exception_enter_addr) :
                    csr_regfile_ertn_flush ? csr_regfile_exception_return_addr :
                    wb_refetch ? mem2_wb_reg_out_pc + 32'd4 :
                    mem1_not_branch_taken ? mem1_next_pc :
                    exe_not_branch_taken ? exe_next_pc :
                    id_not_branch_taken ? id_next_pc :
                    branch_predictor_target_address;



assign exe_mem1_reg_in_valid = exe_valid;
assign exe_mem1_reg_in_regfile_waddr = id_exe_reg_out_regfile_waddr;
assign exe_mem1_reg_in_regfile_we = id_exe_reg_out_regfile_we;
assign exe_mem1_reg_in_sel_regfile_wdata = id_exe_reg_out_sel_regfile_wdata;
assign exe_mem1_reg_in_result = id_exe_reg_out_sel_regfile_wdata == `SEL_REGFILE_WDATA_ALU ? alu_result : id_exe_reg_out_result;
assign exe_mem1_reg_in_pc = id_exe_reg_out_pc;
assign exe_mem1_reg_in_sel_load_store_len = id_exe_reg_out_sel_load_store_len;
assign exe_mem1_reg_in_regfile_raddr1 = id_exe_reg_out_regfile_raddr1;
assign exe_mem1_reg_in_regfile_raddr2 = id_exe_reg_out_regfile_raddr2;
assign exe_mem1_reg_in_regfile_rdata1 = exe_select_regfile_rdata1;
assign exe_mem1_reg_in_regfile_rdata2 = exe_select_regfile_rdata2;
// assign exe_mem1_reg_in_vaddr = id_exe_reg_out_sel_load_store_len == `SEL_LOAD_STORE_W ? {alu_result[31:2], 2'b00} :
//                                 (id_exe_reg_out_sel_load_store_len == `SEL_LOAD_STORE_H || id_exe_reg_out_sel_load_store_len == `SEL_LOAD_STORE_HU) ? {alu_result[31:1], 1'b0} :
//                                 alu_result;

assign exe_mem1_reg_in_vaddr = alu_result;





assign exe_mem1_reg_in_is_load = id_exe_reg_out_is_load;
assign exe_mem1_reg_in_is_store = id_exe_reg_out_is_store;



assign exe_mem1_reg_in_tlb_change = id_exe_reg_out_tlb_change;


assign exe_mem1_reg_in_is_cacop = id_exe_reg_out_is_cacop;


wire exe_mem1_reg_in_is_inst_ll_w;
wire exe_mem1_reg_in_is_inst_sc_w;
wire exe_mem1_reg_out_is_inst_ll_w;
wire exe_mem1_reg_out_is_inst_sc_w;

assign exe_mem1_reg_in_is_inst_ll_w = id_exe_reg_out_is_inst_ll_w;
assign exe_mem1_reg_in_is_inst_sc_w = id_exe_reg_out_is_inst_sc_w;

wire exe_mem1_reg_in_actual_taken;
wire [31:0] exe_mem1_reg_in_actual_target;

wire exe_mem1_reg_out_actual_taken;
wire [31:0] exe_mem1_reg_out_actual_target;

assign exe_mem1_reg_in_actual_taken = id_exe_reg_out_npc_selector_op == `NPC_SELECTOR_BRANCH ? id_exe_reg_out_comparator_compared_result : id_exe_reg_out_actual_taken;
assign exe_mem1_reg_in_actual_target = id_exe_reg_out_npc_selector_op == `NPC_SELECTOR_BRANCH ? exe_next_pc : id_exe_reg_out_actual_target;

exe_mem1_reg u_exe_mem1_reg(
    .clk(clk),
    .resetn(resetn),

    .stall(exe_mem1_reg_stall),
    .pre_stall(id_exe_reg_stall),
    
    .in_valid(exe_mem1_reg_in_valid),
    .out_valid(exe_mem1_reg_out_valid),

    .in_regfile_waddr(exe_mem1_reg_in_regfile_waddr),
    .in_regfile_we(exe_mem1_reg_in_regfile_we),
    .in_sel_regfile_wdata(exe_mem1_reg_in_sel_regfile_wdata),
    .in_result(exe_mem1_reg_in_result),
    .in_pc(exe_mem1_reg_in_pc),
    .in_sel_load_store_len(exe_mem1_reg_in_sel_load_store_len),
    .in_regfile_raddr1(exe_mem1_reg_in_regfile_raddr1),
    .in_regfile_raddr2(exe_mem1_reg_in_regfile_raddr2),
    .in_regfile_rdata1(exe_mem1_reg_in_regfile_rdata1),
    .in_regfile_rdata2(exe_mem1_reg_in_regfile_rdata2),
    .in_vaddr(exe_mem1_reg_in_vaddr),
    .in_is_inst_jirl(exe_mem1_reg_in_is_inst_jirl),
    .in_pc_offset(exe_mem1_reg_in_pc_offset),
    .in_imm(exe_mem1_reg_in_imm),
    .in_is_load(exe_mem1_reg_in_is_load),
    .in_is_store(exe_mem1_reg_in_is_store),
    .in_tlb_change(exe_mem1_reg_in_tlb_change),
    .in_is_cacop(exe_mem1_reg_in_is_cacop),
    .in_instruction(id_exe_reg_out_instruction),

    .in_is_inst_ll_w(exe_mem1_reg_in_is_inst_ll_w),
    .in_is_inst_sc_w(exe_mem1_reg_in_is_inst_sc_w),

    
    .in_actual_taken(exe_mem1_reg_in_actual_taken),
    .in_actual_target(exe_mem1_reg_in_actual_target),


    .out_regfile_waddr(exe_mem1_reg_out_regfile_waddr),
    .out_regfile_we(exe_mem1_reg_out_regfile_we),
    .out_sel_regfile_wdata(exe_mem1_reg_out_sel_regfile_wdata),
    .out_result(exe_mem1_reg_out_result),
    .out_pc(exe_mem1_reg_out_pc),
    .out_sel_load_store_len(exe_mem1_reg_out_sel_load_store_len),
    .out_regfile_raddr1(exe_mem1_reg_out_regfile_raddr1),
    .out_regfile_raddr2(exe_mem1_reg_out_regfile_raddr2),
    .out_regfile_rdata1(exe_mem1_reg_out_regfile_rdata1),
    .out_regfile_rdata2(exe_mem1_reg_out_regfile_rdata2),
    .out_vaddr(exe_mem1_reg_out_vaddr),
    .out_is_inst_jirl(exe_mem1_reg_out_is_inst_jirl),
    .out_pc_offset(exe_mem1_reg_out_pc_offset),
    .out_imm(exe_mem1_reg_out_imm),
    .out_is_load(exe_mem1_reg_out_is_load),
    .out_is_store(exe_mem1_reg_out_is_store),
    .out_tlb_change(exe_mem1_reg_out_tlb_change),
    .out_is_cacop(exe_mem1_reg_out_is_cacop),
    .out_instruction(exe_mem1_reg_out_instruction),
    
    .out_is_inst_ll_w(exe_mem1_reg_out_is_inst_ll_w),
    .out_is_inst_sc_w(exe_mem1_reg_out_is_inst_sc_w),

    .out_actual_taken(exe_mem1_reg_out_actual_taken),
    .out_actual_target(exe_mem1_reg_out_actual_target)
);




assign select_store_addr = mem1_mem2_reg_out_data_pa[1:0];
assign select_store_data = mem1_mem2_reg_out_regfile_rdata2;
assign select_store_sel_load_store_len = mem1_mem2_reg_out_sel_load_store_len;
assign select_store_we = mem1_mem2_reg_out_is_store;

select_store u_select_store(
    .addr(select_store_addr),
    .data(select_store_data),
    .sel_load_store_len(select_store_sel_load_store_len),
    .we(select_store_we),

    .modified_we(select_store_modified_we),
    .result(select_store_result)
);


assign mem1_mem2_reg_in_valid = mem1_valid;
assign mem1_mem2_reg_in_regfile_waddr = exe_mem1_reg_out_regfile_waddr;
assign mem1_mem2_reg_in_regfile_we = exe_mem1_reg_out_regfile_we;
assign mem1_mem2_reg_in_sel_regfile_wdata = exe_mem1_reg_out_sel_regfile_wdata;
assign mem1_mem2_reg_in_result = exe_mem1_reg_out_result;
assign mem1_mem2_reg_in_pc = exe_mem1_reg_out_pc;
assign mem1_mem2_reg_in_sel_load_store_len = exe_mem1_reg_out_sel_load_store_len;
assign mem1_mem2_reg_in_regfile_raddr1 = exe_mem1_reg_out_regfile_raddr1;
assign mem1_mem2_reg_in_regfile_raddr2 = exe_mem1_reg_out_regfile_raddr2;
assign mem1_mem2_reg_in_regfile_rdata1 = exe_mem1_reg_out_regfile_rdata1;
assign mem1_mem2_reg_in_regfile_rdata2 = exe_mem1_reg_out_regfile_rdata2;
assign mem1_mem2_reg_in_vaddr = exe_mem1_reg_out_vaddr;

assign mem1_mem2_reg_in_data_pa = mmu_data_pa;

assign mem1_mem2_reg_in_is_load = exe_mem1_reg_out_is_load;
assign mem1_mem2_reg_in_is_store = exe_mem1_reg_out_is_store;



assign mem1_mem2_reg_in_tlb_change = exe_mem1_reg_out_tlb_change;


assign mem1_mem2_reg_in_is_cacop = exe_mem1_reg_out_is_cacop;

wire mem1_mem2_reg_in_is_inst_ll_w;
wire mem1_mem2_reg_in_is_inst_sc_w;
wire mem1_mem2_reg_out_is_inst_ll_w;
wire mem1_mem2_reg_out_is_inst_sc_w;

assign mem1_mem2_reg_in_is_inst_ll_w = exe_mem1_reg_out_is_inst_ll_w;
assign mem1_mem2_reg_in_is_inst_sc_w = exe_mem1_reg_out_is_inst_sc_w;

wire mem1_mem2_reg_in_actual_taken;
wire [31:0] mem1_mem2_reg_in_actual_target;

wire mem1_mem2_reg_out_actual_taken;
wire [31:0] mem1_mem2_reg_out_actual_target;

assign mem1_mem2_reg_in_actual_taken = exe_mem1_reg_out_is_inst_jirl ? 1'b1 : exe_mem1_reg_out_actual_taken;
assign mem1_mem2_reg_in_actual_target = exe_mem1_reg_out_is_inst_jirl ? mem1_next_pc : exe_mem1_reg_out_actual_target;


mem1_mem2_reg u_mem1_mem2_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(mem1_mem2_reg_stall),
    .pre_stall(exe_mem1_reg_stall),

    .in_valid(mem1_mem2_reg_in_valid),
    .out_valid(mem1_mem2_reg_out_valid),
    
    .in_regfile_waddr(mem1_mem2_reg_in_regfile_waddr),
    .in_regfile_we(mem1_mem2_reg_in_regfile_we),
    .in_sel_regfile_wdata(mem1_mem2_reg_in_sel_regfile_wdata),
    .in_result(mem1_mem2_reg_in_result),
    .in_pc(mem1_mem2_reg_in_pc),
    .in_sel_load_store_len(mem1_mem2_reg_in_sel_load_store_len),
    .in_regfile_raddr1(mem1_mem2_reg_in_regfile_raddr1),
    .in_regfile_raddr2(mem1_mem2_reg_in_regfile_raddr2),
    .in_regfile_rdata1(mem1_mem2_reg_in_regfile_rdata1),
    .in_regfile_rdata2(mem1_mem2_reg_in_regfile_rdata2),
    .in_vaddr(mem1_mem2_reg_in_vaddr),
    .in_data_pa(mem1_mem2_reg_in_data_pa),
    .in_is_load(mem1_mem2_reg_in_is_load),
    .in_is_store(mem1_mem2_reg_in_is_store),
    .in_tlb_change(mem1_mem2_reg_in_tlb_change),
    .in_is_cacop(mem1_mem2_reg_in_is_cacop),
    .in_instruction(exe_mem1_reg_out_instruction),

    .in_is_inst_ll_w(mem1_mem2_reg_in_is_inst_ll_w),
    .in_is_inst_sc_w(mem1_mem2_reg_in_is_inst_sc_w),

    .in_actual_taken(mem1_mem2_reg_in_actual_taken),
    .in_actual_target(mem1_mem2_reg_in_actual_target),

    .out_regfile_waddr(mem1_mem2_reg_out_regfile_waddr),
    .out_regfile_we(mem1_mem2_reg_out_regfile_we),
    .out_sel_regfile_wdata(mem1_mem2_reg_out_sel_regfile_wdata),
    .out_result(mem1_mem2_reg_out_result),
    .out_pc(mem1_mem2_reg_out_pc),
    .out_sel_load_store_len(mem1_mem2_reg_out_sel_load_store_len),
    .out_regfile_raddr1(mem1_mem2_reg_out_regfile_raddr1),
    .out_regfile_raddr2(mem1_mem2_reg_out_regfile_raddr2),
    .out_regfile_rdata1(mem1_mem2_reg_out_regfile_rdata1),
    .out_regfile_rdata2(mem1_mem2_reg_out_regfile_rdata2),
    .out_vaddr(mem1_mem2_reg_out_vaddr),
    .out_data_pa(mem1_mem2_reg_out_data_pa),
    .out_is_load(mem1_mem2_reg_out_is_load),
    .out_is_store(mem1_mem2_reg_out_is_store),
    .out_tlb_change(mem1_mem2_reg_out_tlb_change),
    .out_is_cacop(mem1_mem2_reg_out_is_cacop),
    .out_instruction(mem1_mem2_reg_out_instruction),
    
    .out_is_inst_ll_w(mem1_mem2_reg_out_is_inst_ll_w),
    .out_is_inst_sc_w(mem1_mem2_reg_out_is_inst_sc_w),

    .out_actual_taken(mem1_mem2_reg_out_actual_taken),
    .out_actual_target(mem1_mem2_reg_out_actual_target)

);





assign select_load_addr = mem1_mem2_reg_out_vaddr[1:0];
assign select_load_data = data_sram_rdata ;
assign select_load_sel_load_store_len = mem1_mem2_reg_out_sel_load_store_len;



select_load u_select_load(
    .addr(select_load_addr),
    .data(select_load_data),
    .sel_load_store_len(select_load_sel_load_store_len),

    .result(select_load_result)
);


assign mem2_wb_reg_in_valid = mem2_valid;

assign mem2_wb_reg_in_regfile_waddr = mem1_mem2_reg_out_regfile_waddr;
assign mem2_wb_reg_in_regfile_we = mem1_mem2_reg_out_regfile_we;
assign mem2_wb_reg_in_result = mem1_mem2_reg_out_sel_regfile_wdata == `SEL_REGFILE_WDATA_MEM 
                               ? (mem1_mem2_reg_out_is_inst_sc_w ? csr_regfile_llbit : select_load_result) : mem1_mem2_reg_out_result;
assign mem2_wb_reg_in_pc = mem1_mem2_reg_out_pc;
assign mem2_wb_reg_in_regfile_raddr1 = mem1_mem2_reg_out_regfile_raddr1;
assign mem2_wb_reg_in_regfile_raddr2 = mem1_mem2_reg_out_regfile_raddr2;
assign mem2_wb_reg_in_regfile_rdata1 = mem1_mem2_reg_out_regfile_rdata1;
assign mem2_wb_reg_in_regfile_rdata2 = mem1_mem2_reg_out_regfile_rdata2;
assign mem2_wb_reg_in_vaddr = mem1_mem2_reg_out_vaddr;


assign mem2_wb_reg_in_is_load = mem1_mem2_reg_out_is_load;
assign mem2_wb_reg_in_is_store = mem1_mem2_reg_out_is_store;



assign mem2_wb_reg_in_tlb_change = mem1_mem2_reg_out_tlb_change;

wire mem2_wb_reg_in_is_inst_ll_w;
wire mem2_wb_reg_in_is_inst_sc_w;
wire mem2_wb_reg_out_is_inst_ll_w;
wire mem2_wb_reg_out_is_inst_sc_w;

assign mem2_wb_reg_in_is_inst_ll_w = mem1_mem2_reg_out_is_inst_ll_w;
assign mem2_wb_reg_in_is_inst_sc_w = mem1_mem2_reg_out_is_inst_sc_w;


wire mem2_wb_reg_in_is_cacop;
wire mem2_wb_reg_out_is_cacop;

assign mem2_wb_reg_in_is_cacop = mem1_mem2_reg_out_is_cacop;

wire mem2_wb_reg_in_actual_taken;
wire [31:0] mem2_wb_reg_in_actual_target;

wire mem2_wb_reg_out_actual_taken;
wire [31:0] mem2_wb_reg_out_actual_target;

assign mem2_wb_reg_in_actual_taken = mem1_mem2_reg_out_actual_taken;
assign mem2_wb_reg_in_actual_target = mem1_mem2_reg_out_actual_target;



mem2_wb_reg u_mem2_wb_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(mem2_wb_reg_stall),
    .pre_stall(mem1_mem2_reg_stall),
    
    .in_valid(mem2_wb_reg_in_valid),
    .out_valid(mem2_wb_reg_out_valid),

    .in_regfile_waddr(mem2_wb_reg_in_regfile_waddr),
    .in_regfile_we(mem2_wb_reg_in_regfile_we),
    .in_result(mem2_wb_reg_in_result),
    .in_pc(mem2_wb_reg_in_pc),
    .in_regfile_raddr1(mem2_wb_reg_in_regfile_raddr1),
    .in_regfile_raddr2(mem2_wb_reg_in_regfile_raddr2),
    .in_regfile_rdata1(mem2_wb_reg_in_regfile_rdata1),
    .in_regfile_rdata2(mem2_wb_reg_in_regfile_rdata2),
    .in_vaddr(mem2_wb_reg_in_vaddr),
    .in_is_load(mem2_wb_reg_in_is_load),
    .in_is_store(mem2_wb_reg_in_is_store),
    .in_tlb_change(mem2_wb_reg_in_tlb_change),
    .in_instruction(mem1_mem2_reg_out_instruction),

    .in_is_inst_ll_w(mem2_wb_reg_in_is_inst_ll_w),
    .in_is_inst_sc_w(mem2_wb_reg_in_is_inst_sc_w),

    .in_is_cacop(mem2_wb_reg_in_is_cacop),

    .in_actual_taken(mem2_wb_reg_in_actual_taken),
    .in_actual_target(mem2_wb_reg_in_actual_target),

    .out_regfile_waddr(mem2_wb_reg_out_regfile_waddr),
    .out_regfile_we(mem2_wb_reg_out_regfile_we),
    .out_result(mem2_wb_reg_out_result),
    .out_pc(mem2_wb_reg_out_pc),
    .out_regfile_raddr1(mem2_wb_reg_out_regfile_raddr1),
    .out_regfile_raddr2(mem2_wb_reg_out_regfile_raddr2),
    .out_regfile_rdata1(mem2_wb_reg_out_regfile_rdata1),
    .out_regfile_rdata2(mem2_wb_reg_out_regfile_rdata2),
    .out_vaddr(mem2_wb_reg_out_vaddr),
    .out_is_load(mem2_wb_reg_out_is_load),
    .out_is_store(mem2_wb_reg_out_is_store),
    .out_tlb_change(mem2_wb_reg_out_tlb_change),
    .out_instruction(mem2_wb_reg_out_instruction),
    
    .out_is_inst_ll_w(mem2_wb_reg_out_is_inst_ll_w),
    .out_is_inst_sc_w(mem2_wb_reg_out_is_inst_sc_w),
    
    .out_is_cacop(mem2_wb_reg_out_is_cacop),

    .out_actual_taken(mem2_wb_reg_out_actual_taken),
    .out_actual_target(mem2_wb_reg_out_actual_target)
);



always @(*) begin
    if(regfile_rj != 5'd0 && regfile_rj == id_exe_reg_out_regfile_waddr && id_exe_reg_out_valid)
        id_select_rdata_rj = id_exe_reg_out_result;
    else if(regfile_rj != 5'd0 && regfile_rj == exe_mem1_reg_out_regfile_waddr && exe_mem1_reg_out_valid)
        id_select_rdata_rj = exe_mem1_reg_out_result;
    else if(regfile_rj != 5'd0 && regfile_rj == mem1_mem2_reg_out_regfile_waddr && mem1_mem2_reg_out_valid)
        id_select_rdata_rj = mem1_mem2_reg_out_result;
    else if(regfile_rj != 5'd0 && regfile_rj == mem2_wb_reg_out_regfile_waddr && mem2_wb_reg_out_valid)
        id_select_rdata_rj = mem2_wb_reg_out_result;
    else
        id_select_rdata_rj = regfile_rdata1;
end

always @(*) begin
    if(regfile_rk != 5'd0 && regfile_rk == id_exe_reg_out_regfile_waddr && id_exe_reg_out_valid)
        id_select_rdata_rk = id_exe_reg_out_result;
    else if(regfile_rk != 5'd0 && regfile_rk == exe_mem1_reg_out_regfile_waddr && exe_mem1_reg_out_valid)
        id_select_rdata_rk = exe_mem1_reg_out_result;
    else if(regfile_rk != 5'd0 && regfile_rk == mem1_mem2_reg_out_regfile_waddr && mem1_mem2_reg_out_valid)
        id_select_rdata_rk = mem1_mem2_reg_out_result;
    else if(regfile_rk != 5'd0 && regfile_rk == mem2_wb_reg_out_regfile_waddr && mem2_wb_reg_out_valid)
        id_select_rdata_rk = mem2_wb_reg_out_result;
    else
        id_select_rdata_rk = regfile_rdata2;
end

always @(*) begin
    if(regfile_rd != 5'd0 && regfile_rd == id_exe_reg_out_regfile_waddr && id_exe_reg_out_valid)
        id_select_rdata_rd = id_exe_reg_out_result;
    else if(regfile_rd != 5'd0 && regfile_rd == exe_mem1_reg_out_regfile_waddr && exe_mem1_reg_out_valid)
        id_select_rdata_rd = exe_mem1_reg_out_result;
    else if(regfile_rd != 5'd0 && regfile_rd == mem1_mem2_reg_out_regfile_waddr && mem1_mem2_reg_out_valid)
        id_select_rdata_rd = mem1_mem2_reg_out_result;
    else if(regfile_rd != 5'd0 && regfile_rd == mem2_wb_reg_out_regfile_waddr && mem2_wb_reg_out_valid)
        id_select_rdata_rd = mem2_wb_reg_out_result;
    else
        id_select_rdata_rd = regfile_rdata3;
end


always @(*) begin
    case(ctrl_sel_regfile_rdata1)
        `SEL_REGFILE_RDATA_RJ : id_select_regfile_rdata1 = id_select_rdata_rj;
        `SEL_REGFILE_RDATA_RK : id_select_regfile_rdata1 = id_select_rdata_rk;
        `SEL_REGFILE_RDATA_RD : id_select_regfile_rdata1 = id_select_rdata_rd;
        default : id_select_regfile_rdata1 = 5'd0;
    endcase
end

always @(*) begin
    case(ctrl_sel_regfile_rdata2)
        `SEL_REGFILE_RDATA_RJ : id_select_regfile_rdata2 = id_select_rdata_rj;
        `SEL_REGFILE_RDATA_RK : id_select_regfile_rdata2 = id_select_rdata_rk;
        `SEL_REGFILE_RDATA_RD : id_select_regfile_rdata2 = id_select_rdata_rd;
        default : id_select_regfile_rdata2 = 5'd0;
    endcase
end

assign exe_select_regfile_rdata1 = id_exe_reg_out_regfile_rdata1;
assign exe_select_regfile_rdata2 = id_exe_reg_out_regfile_rdata2;



assign mem1_tlb_change = exe_mem1_state_out_is_inst_invtlb || exe_mem1_state_out_is_inst_tlbwr || exe_mem1_state_out_is_inst_tlbfill;





stall_clear_detector u_stall_clear_detector(
    .clk(clk),
    .resetn(resetn),

    .pc_reg_out_valid(pc_reg_out_valid),
    .if1_if2_reg_out_valid(if1_if2_reg_out_valid),
    .if2_id_reg_out_valid(if2_id_reg_out_valid),
    .id_exe_reg_out_valid(id_exe_reg_out_valid),
    .exe_mem1_reg_out_valid(exe_mem1_reg_out_valid),
    .mem1_mem2_reg_out_valid(mem1_mem2_reg_out_valid),
    .mem2_wb_reg_out_valid(mem2_wb_reg_out_valid),

    .exe_mem1_reg_out_regfile_waddr(exe_mem1_reg_out_regfile_waddr),
    .exe_mem1_reg_out_sel_regfile_wdata(exe_mem1_reg_out_sel_regfile_wdata),
    .exe_mem1_reg_out_regfile_we(exe_mem1_reg_out_regfile_we),

    .mem1_mem2_reg_out_regfile_waddr(mem1_mem2_reg_out_regfile_waddr),
    .mem1_mem2_reg_out_sel_regfile_wdata(mem1_mem2_reg_out_sel_regfile_wdata),
    .mem1_mem2_reg_out_regfile_we(mem1_mem2_reg_out_regfile_we),
    
    .id_exe_reg_out_regfile_waddr(id_exe_reg_out_regfile_waddr),
    .id_exe_reg_out_sel_regfile_wdata(id_exe_reg_out_sel_regfile_wdata),
    .id_exe_reg_out_regfile_we(id_exe_reg_out_regfile_we),

    .regfile_raddr1(regfile_raddr1),
    .regfile_raddr2(regfile_raddr2),
    
    .id_not_branch_taken(id_not_branch_taken),
    .exe_not_branch_taken(exe_not_branch_taken),
    .mem1_not_branch_taken(mem1_not_branch_taken),
    
    .alu_multiply_divide_ready(alu_multiply_divide_ready),

    
    .ctrl_csr_re(ctrl_csr_re),
    .id_exe_state_out_csr_we(id_exe_state_out_csr_we),
    .exe_mem1_state_out_csr_we(exe_mem1_state_out_csr_we),
    .mem1_mem2_state_out_csr_we(mem1_mem2_state_out_csr_we),
    .mem2_wb_state_out_csr_we(mem2_wb_state_out_csr_we),
    
    .pc_state_out_is_exception(pc_state_out_is_exception),
    .if1_if2_state_out_is_exception(if1_if2_state_out_is_exception),
    .if2_id_state_out_is_exception(if2_id_state_out_is_exception),
    .id_exe_state_out_is_exception(id_exe_state_out_is_exception),
    .exe_mem1_state_out_is_exception(exe_mem1_state_out_is_exception),
    .mem1_mem2_state_out_is_exception(mem1_mem2_state_out_is_exception),
    .mem2_wb_state_out_is_exception(mem2_wb_state_out_is_exception),

    .mem1_mem2_state_out_ertn_flush(mem1_mem2_state_out_ertn_flush),
    .mem2_wb_state_out_ertn_flush(mem2_wb_state_out_ertn_flush),

    .pc_reg_stall(pc_reg_stall),
    .pc_reg_clear(pc_reg_clear),
    .if1_if2_reg_stall(if1_if2_reg_stall),
    .if1_if2_reg_clear(if1_if2_reg_clear),
    .if2_id_reg_stall(if2_id_reg_stall),
    .if2_id_reg_clear(if2_id_reg_clear),
    .id_exe_reg_stall(id_exe_reg_stall),
    .id_exe_reg_clear(id_exe_reg_clear),
    .exe_mem1_reg_stall(exe_mem1_reg_stall),
    .exe_mem1_reg_clear(exe_mem1_reg_clear),
    .mem1_mem2_reg_stall(mem1_mem2_reg_stall),
    .mem1_mem2_reg_clear(mem1_mem2_reg_clear),
    .mem2_wb_reg_stall(mem2_wb_reg_stall),
    .mem2_wb_reg_clear(mem2_wb_reg_clear),


    .inst_sram_fsm_state(inst_sram_fsm_state),
    .data_sram_fsm_state(data_sram_fsm_state),


    // .inst_sram_req(inst_sram_req),
    // .data_sram_req(data_sram_req),

    .ctrl_tlb_we(ctrl_tlb_we),
    .id_exe_state_out_tlb_we(id_exe_state_out_tlb_we),
    .exe_mem1_state_out_tlb_we(exe_mem1_state_out_tlb_we),
    .mem1_mem2_state_out_tlb_we(mem1_mem2_state_out_tlb_we),
    .mem2_wb_state_out_tlb_we(mem2_wb_state_out_tlb_we),
    
    .mem1_tlb_change(mem1_tlb_change),
    .csr_regfile_waddr(csr_regfile_waddr),


    .exe_mem1_reg_out_is_load(exe_mem1_reg_out_is_load),
    .exe_mem1_reg_out_is_store(exe_mem1_reg_out_is_store),
    .mem1_mem2_reg_out_is_load(mem1_mem2_reg_out_is_load),
    .mem1_mem2_reg_out_is_store(mem1_mem2_reg_out_is_store),
    .mem2_wb_reg_out_is_load(mem2_wb_reg_out_is_load),
    .mem2_wb_reg_out_is_store(mem2_wb_reg_out_is_store),

    .id_exe_reg_out_tlb_change(id_exe_reg_out_tlb_change),
    .exe_mem1_reg_out_tlb_change(exe_mem1_reg_out_tlb_change),
    .mem1_mem2_reg_out_tlb_change(mem1_mem2_reg_out_tlb_change),
    .mem2_wb_reg_out_tlb_change(mem2_wb_reg_out_tlb_change),

    .mem1_mem2_reg_out_is_cacop(mem1_mem2_reg_out_is_cacop),
    .cacop_fsm_state(cacop_fsm_state),
    .cacop_req(cacop_req),

    .ctrl_is_inst_idle(ctrl_is_inst_idle),
    .is_int(is_int),

    .mem1_mem2_reg_out_is_inst_sc_w(mem1_mem2_reg_out_is_inst_sc_w),
    .csr_regfile_llbit(csr_regfile_llbit),

    .wb_refetch(wb_refetch),

    .cache_subsystem_if1_ready(cache_subsystem_if1_ready),
    .cache_subsystem_if2_refill_valid(cache_subsystem_if2_refill_valid),
    .cache_subsystem_if2_miss(cache_subsystem_if2_miss),

    .cache_subsystem_mem2_ready(cache_subsystem_mem2_miss_ready),
    .cache_subsystem_mem2_refill_valid(cache_subsystem_mem2_refill_valid),
    .cache_subsystem_mem2_miss(cache_subsystem_mem2_miss),

    .cache_subsystem_dcache_busy(cache_subsystem_dcache_busy),
    .cache_subsystem_icache_busy(cache_subsystem_icache_busy)

);






assign is_int = csr_regfile_has_int;
assign is_sys = ctrl_is_sys;
assign is_adef = pc_reg_npc[1:0] != 2'b00;
assign is_ale = (id_exe_reg_out_sel_load_store_len == `SEL_LOAD_STORE_W && alu_result[1:0] != 2'b00) ||
                ((id_exe_reg_out_sel_load_store_len == `SEL_LOAD_STORE_H || 
                  id_exe_reg_out_sel_load_store_len == `SEL_LOAD_STORE_HU) && 
                 alu_result[0] != 1'b0);
assign is_brk = ctrl_is_brk;
assign is_ine = ctrl_is_ine;




assign pc_state_in_is_exception = is_adef;
assign pc_state_in_is_adef = is_adef;

pc_state u_pc_state(
    .clk(clk),
    .resetn(resetn),
    .stall(pc_reg_stall),

    .in_is_exception(pc_state_in_is_exception),
    .in_is_adef(pc_state_in_is_adef),
    
    .out_is_exception(pc_state_out_is_exception),
    .out_is_adef(pc_state_out_is_adef)

);


assign if1_if2_state_in_is_exception = pc_state_out_is_exception || mmu_inst_ex_tlbr || 
                                       mmu_inst_ex_ppi || mmu_inst_ex_pif;
assign if1_if2_state_in_is_adef = pc_state_out_is_adef;


assign if1_if2_state_in_is_tlbr = !pc_state_out_is_exception && mmu_inst_ex_tlbr;
assign if1_if2_state_in_is_inst_tlbr = mmu_inst_ex_tlbr;
assign if1_if2_state_in_is_inst_pif = mmu_inst_ex_pif;
assign if1_if2_state_in_is_inst_ppi = mmu_inst_ex_ppi;



assign if1_if2_state_in_mmu_inst_mat = mmu_inst_mat;


if1_if2_state u_if1_if2_state(
    .clk(clk),
    .resetn(resetn),
    .stall(if1_if2_reg_stall),

    .in_is_exception(if1_if2_state_in_is_exception),
    .in_is_adef(if1_if2_state_in_is_adef),
    .in_is_tlbr(if1_if2_state_in_is_tlbr),
    .in_is_inst_tlbr(if1_if2_state_in_is_inst_tlbr),
    .in_is_inst_pif(if1_if2_state_in_is_inst_pif),
    .in_is_inst_ppi(if1_if2_state_in_is_inst_ppi),
    .in_mmu_inst_mat(if1_if2_state_in_mmu_inst_mat),
    
    .out_is_exception(if1_if2_state_out_is_exception),
    .out_is_adef(if1_if2_state_out_is_adef),
    .out_is_tlbr(if1_if2_state_out_is_tlbr),
    .out_is_inst_tlbr(if1_if2_state_out_is_inst_tlbr),
    .out_is_inst_pif(if1_if2_state_out_is_inst_pif),
    .out_is_inst_ppi(if1_if2_state_out_is_inst_ppi),
    .out_mmu_inst_mat(if1_if2_state_out_mmu_inst_mat)
);




assign if2_id_state_in_is_exception = if1_if2_state_out_is_exception;
assign if2_id_state_in_is_adef = if1_if2_state_out_is_adef;



assign if2_id_state_in_is_tlbr = if1_if2_state_out_is_tlbr;
assign if2_id_state_in_is_inst_tlbr = if1_if2_state_out_is_inst_tlbr;
assign if2_id_state_in_is_inst_pif = if1_if2_state_out_is_inst_pif;
assign if2_id_state_in_is_inst_ppi = if1_if2_state_out_is_inst_ppi;


if2_id_state u_if2_id_state(
    .clk(clk),
    .resetn(resetn),
    .stall(if2_id_reg_stall),

    .in_is_exception(if2_id_state_in_is_exception),
    .in_is_adef(if2_id_state_in_is_adef),

    .in_is_tlbr(if2_id_state_in_is_tlbr),
    .in_is_inst_tlbr(if2_id_state_in_is_inst_tlbr),
    .in_is_inst_pif(if2_id_state_in_is_inst_pif),
    .in_is_inst_ppi(if2_id_state_in_is_inst_ppi),
    
    .out_is_exception(if2_id_state_out_is_exception),
    .out_is_adef(if2_id_state_out_is_adef),

    .out_is_tlbr(if2_id_state_out_is_tlbr),
    .out_is_inst_tlbr(if2_id_state_out_is_inst_tlbr),
    .out_is_inst_pif(if2_id_state_out_is_inst_pif),
    .out_is_inst_ppi(if2_id_state_out_is_inst_ppi)
);




assign id_exe_state_in_is_exception = if2_id_state_out_is_exception || is_sys || is_int || is_ine || is_brk;
assign id_exe_state_in_is_sys = is_sys;
assign id_exe_state_in_is_int = is_int;
assign id_exe_state_in_ertn_flush = ctrl_csr_ertn_flush;
assign id_exe_state_in_csr_addr = ctrl_csr_addr;
assign id_exe_state_in_csr_we = ctrl_csr_we;
assign id_exe_state_in_csr_re = ctrl_csr_re;
assign id_exe_state_in_is_adef = if2_id_state_out_is_adef;
assign id_exe_state_in_is_ine = is_ine;
assign id_exe_state_in_is_brk = is_brk;



assign id_exe_state_in_tlb_we = ctrl_tlb_we;
assign id_exe_state_in_invtlb_op = ctrl_invtlb_op;
assign id_exe_state_in_is_inst_tlbsrch = ctrl_is_inst_tlbsrch;
assign id_exe_state_in_is_inst_tlbrd = ctrl_is_inst_tlbrd;
assign id_exe_state_in_is_inst_tlbwr = ctrl_is_inst_tlbwr;
assign id_exe_state_in_is_inst_tlbfill = ctrl_is_inst_tlbfill;
assign id_exe_state_in_is_inst_invtlb = ctrl_is_inst_invtlb;




assign id_exe_state_in_is_tlbr = if2_id_state_out_is_tlbr;
assign id_exe_state_in_is_inst_tlbr = if2_id_state_out_is_inst_tlbr;
assign id_exe_state_in_is_inst_pif = if2_id_state_out_is_inst_pif;
assign id_exe_state_in_is_inst_ppi = if2_id_state_out_is_inst_ppi;




id_exe_state u_id_exe_state(
    .clk(clk),
    .resetn(resetn),
    .stall(id_exe_reg_stall),

    .in_is_exception(id_exe_state_in_is_exception),
    .in_is_sys(id_exe_state_in_is_sys),
    .in_is_int(id_exe_state_in_is_int),
    .in_ertn_flush(id_exe_state_in_ertn_flush),
    .in_csr_addr(id_exe_state_in_csr_addr),
    .in_csr_we(id_exe_state_in_csr_we),
    .in_csr_re(id_exe_state_in_csr_re),

    .in_is_adef(id_exe_state_in_is_adef),
    .in_is_ine(id_exe_state_in_is_ine),
    .in_is_brk(id_exe_state_in_is_brk),

    .in_tlb_we(id_exe_state_in_tlb_we),
    .in_invtlb_op(id_exe_state_in_invtlb_op),
    .in_is_inst_tlbsrch(id_exe_state_in_is_inst_tlbsrch),
    .in_is_inst_tlbrd(id_exe_state_in_is_inst_tlbrd),
    .in_is_inst_tlbwr(id_exe_state_in_is_inst_tlbwr),
    .in_is_inst_tlbfill(id_exe_state_in_is_inst_tlbfill),
    .in_is_inst_invtlb(id_exe_state_in_is_inst_invtlb),

    .in_is_tlbr(id_exe_state_in_is_tlbr),
    .in_is_inst_tlbr(id_exe_state_in_is_inst_tlbr),
    .in_is_inst_pif(id_exe_state_in_is_inst_pif),
    .in_is_inst_ppi(id_exe_state_in_is_inst_ppi),
    
    
    .out_is_exception(id_exe_state_out_is_exception),
    .out_is_sys(id_exe_state_out_is_sys),
    .out_is_int(id_exe_state_out_is_int),
    .out_ertn_flush(id_exe_state_out_ertn_flush),
    .out_csr_addr(id_exe_state_out_csr_addr),
    .out_csr_we(id_exe_state_out_csr_we),
    .out_csr_re(id_exe_state_out_csr_re),

    .out_is_adef(id_exe_state_out_is_adef),
    .out_is_ine(id_exe_state_out_is_ine),
    .out_is_brk(id_exe_state_out_is_brk),

    .out_tlb_we(id_exe_state_out_tlb_we),
    .out_invtlb_op(id_exe_state_out_invtlb_op),
    .out_is_inst_tlbsrch(id_exe_state_out_is_inst_tlbsrch),
    .out_is_inst_tlbrd(id_exe_state_out_is_inst_tlbrd),
    .out_is_inst_tlbwr(id_exe_state_out_is_inst_tlbwr),
    .out_is_inst_tlbfill(id_exe_state_out_is_inst_tlbfill),
    .out_is_inst_invtlb(id_exe_state_out_is_inst_invtlb),

    .out_is_tlbr(id_exe_state_out_is_tlbr),
    .out_is_inst_tlbr(id_exe_state_out_is_inst_tlbr),
    .out_is_inst_pif(id_exe_state_out_is_inst_pif),
    .out_is_inst_ppi(id_exe_state_out_is_inst_ppi)
);





assign exe_mem1_state_in_is_exception = id_exe_state_out_is_exception || is_ale;
assign exe_mem1_state_in_is_sys = id_exe_state_out_is_sys;
assign exe_mem1_state_in_is_int = id_exe_state_out_is_int;
assign exe_mem1_state_in_ertn_flush = id_exe_state_out_ertn_flush;
assign exe_mem1_state_in_csr_addr = id_exe_state_out_csr_addr;
assign exe_mem1_state_in_csr_we = id_exe_state_out_csr_we;
assign exe_mem1_state_in_csr_re = id_exe_state_out_csr_re;
assign exe_mem1_state_in_is_adef = id_exe_state_out_is_adef;
assign exe_mem1_state_in_is_ine = id_exe_state_out_is_ine;
assign exe_mem1_state_in_is_brk = id_exe_state_out_is_brk;
assign exe_mem1_state_in_is_ale = is_ale;



assign exe_mem1_state_in_tlb_we = id_exe_state_out_tlb_we;
assign exe_mem1_state_in_invtlb_op = id_exe_state_out_invtlb_op;
assign exe_mem1_state_in_is_inst_tlbsrch = id_exe_state_out_is_inst_tlbsrch;
assign exe_mem1_state_in_is_inst_tlbrd = id_exe_state_out_is_inst_tlbrd;
assign exe_mem1_state_in_is_inst_tlbwr = id_exe_state_out_is_inst_tlbwr;
assign exe_mem1_state_in_is_inst_tlbfill = id_exe_state_out_is_inst_tlbfill;
assign exe_mem1_state_in_is_inst_invtlb = id_exe_state_out_is_inst_invtlb;




assign exe_mem1_state_in_is_tlbr = id_exe_state_out_is_tlbr;
assign exe_mem1_state_in_is_inst_tlbr = id_exe_state_out_is_inst_tlbr;
assign exe_mem1_state_in_is_inst_pif = id_exe_state_out_is_inst_pif;
assign exe_mem1_state_in_is_inst_ppi = id_exe_state_out_is_inst_ppi;



exe_mem1_state u_exe_mem1_state(
    .clk(clk),
    .resetn(resetn),
    .stall(exe_mem1_reg_stall),

    .in_is_exception(exe_mem1_state_in_is_exception),
    .in_is_sys(exe_mem1_state_in_is_sys),
    .in_is_int(exe_mem1_state_in_is_int),
    .in_ertn_flush(exe_mem1_state_in_ertn_flush),
    .in_csr_addr(exe_mem1_state_in_csr_addr),
    .in_csr_we(exe_mem1_state_in_csr_we),
    .in_csr_re(exe_mem1_state_in_csr_re),

    .in_is_adef(exe_mem1_state_in_is_adef),
    .in_is_ine(exe_mem1_state_in_is_ine),
    .in_is_brk(exe_mem1_state_in_is_brk),
    .in_is_ale(exe_mem1_state_in_is_ale),

    .in_tlb_we(exe_mem1_state_in_tlb_we),
    .in_invtlb_op(exe_mem1_state_in_invtlb_op),
    .in_is_inst_tlbsrch(exe_mem1_state_in_is_inst_tlbsrch),
    .in_is_inst_tlbrd(exe_mem1_state_in_is_inst_tlbrd),
    .in_is_inst_tlbwr(exe_mem1_state_in_is_inst_tlbwr),
    .in_is_inst_tlbfill(exe_mem1_state_in_is_inst_tlbfill),
    .in_is_inst_invtlb(exe_mem1_state_in_is_inst_invtlb),

    .in_is_tlbr(exe_mem1_state_in_is_tlbr),
    .in_is_inst_tlbr(exe_mem1_state_in_is_inst_tlbr),
    .in_is_inst_pif(exe_mem1_state_in_is_inst_pif),
    .in_is_inst_ppi(exe_mem1_state_in_is_inst_ppi),

    
    .out_is_exception(exe_mem1_state_out_is_exception),
    .out_is_sys(exe_mem1_state_out_is_sys),
    .out_is_int(exe_mem1_state_out_is_int),
    .out_ertn_flush(exe_mem1_state_out_ertn_flush),
    .out_csr_addr(exe_mem1_state_out_csr_addr),
    .out_csr_we(exe_mem1_state_out_csr_we),
    .out_csr_re(exe_mem1_state_out_csr_re),

    .out_is_adef(exe_mem1_state_out_is_adef),
    .out_is_ine(exe_mem1_state_out_is_ine),
    .out_is_brk(exe_mem1_state_out_is_brk),
    .out_is_ale(exe_mem1_state_out_is_ale),

    .out_tlb_we(exe_mem1_state_out_tlb_we),
    .out_invtlb_op(exe_mem1_state_out_invtlb_op),
    .out_is_inst_tlbsrch(exe_mem1_state_out_is_inst_tlbsrch),
    .out_is_inst_tlbrd(exe_mem1_state_out_is_inst_tlbrd),
    .out_is_inst_tlbwr(exe_mem1_state_out_is_inst_tlbwr),
    .out_is_inst_tlbfill(exe_mem1_state_out_is_inst_tlbfill),
    .out_is_inst_invtlb(exe_mem1_state_out_is_inst_invtlb),

    .out_is_tlbr(exe_mem1_state_out_is_tlbr),
    .out_is_inst_tlbr(exe_mem1_state_out_is_inst_tlbr),
    .out_is_inst_pif(exe_mem1_state_out_is_inst_pif),
    .out_is_inst_ppi(exe_mem1_state_out_is_inst_ppi)
);



assign mem1_mem2_state_in_is_exception = exe_mem1_state_out_is_exception || mmu_data_ex_tlbr || mmu_data_ex_ppi || 
                                         mmu_data_ex_pme || mmu_data_ex_pis || mmu_data_ex_pil;
assign mem1_mem2_state_in_is_sys = exe_mem1_state_out_is_sys;
assign mem1_mem2_state_in_is_int = exe_mem1_state_out_is_int;
assign mem1_mem2_state_in_ertn_flush = exe_mem1_state_out_ertn_flush;
assign mem1_mem2_state_in_csr_addr = exe_mem1_state_out_csr_addr;
assign mem1_mem2_state_in_csr_we = exe_mem1_state_out_csr_we;
assign mem1_mem2_state_in_csr_re = exe_mem1_state_out_csr_re;
assign mem1_mem2_state_in_is_adef = exe_mem1_state_out_is_adef;
assign mem1_mem2_state_in_is_ine = exe_mem1_state_out_is_ine;
assign mem1_mem2_state_in_is_brk = exe_mem1_state_out_is_brk;
assign mem1_mem2_state_in_is_ale = exe_mem1_state_out_is_ale;



assign mem1_mem2_state_in_tlb_we = exe_mem1_state_out_tlb_we;
assign mem1_mem2_state_in_invtlb_op = exe_mem1_state_out_invtlb_op;
assign mem1_mem2_state_in_is_inst_tlbsrch = exe_mem1_state_out_is_inst_tlbsrch;
assign mem1_mem2_state_in_is_inst_tlbrd = exe_mem1_state_out_is_inst_tlbrd;
assign mem1_mem2_state_in_is_inst_tlbwr = exe_mem1_state_out_is_inst_tlbwr;
assign mem1_mem2_state_in_is_inst_tlbfill = exe_mem1_state_out_is_inst_tlbfill;
assign mem1_mem2_state_in_is_inst_invtlb = exe_mem1_state_out_is_inst_invtlb;



assign mem1_mem2_state_in_tlbsrch_hit = mmu_tlbsrch_hit;
assign mem1_mem2_state_in_tlbrd_hit = mmu_tlbrd_hit;
assign mem1_mem2_state_in_tlb_w_csr_tlbelo0 = tlb_w_csr_tlbelo0;
assign mem1_mem2_state_in_tlb_w_csr_tlbelo1 = tlb_w_csr_tlbelo1;
assign mem1_mem2_state_in_tlb_w_csr_tlbidx = tlb_w_csr_tlbidx;
assign mem1_mem2_state_in_tlb_w_csr_tlbehi = tlb_w_csr_tlbehi;
assign mem1_mem2_state_in_tlb_w_csr_asid = tlb_w_csr_asid;





assign mem1_mem2_state_in_is_tlbr = exe_mem1_state_out_is_tlbr || !exe_mem1_state_out_is_exception && mmu_data_ex_tlbr;
assign mem1_mem2_state_in_is_inst_tlbr = exe_mem1_state_out_is_inst_tlbr;
assign mem1_mem2_state_in_is_inst_pif = exe_mem1_state_out_is_inst_pif;
assign mem1_mem2_state_in_is_inst_ppi = exe_mem1_state_out_is_inst_ppi;
assign mem1_mem2_state_in_is_data_tlbr = mmu_data_ex_tlbr;
assign mem1_mem2_state_in_is_data_pil = mmu_data_ex_pil;
assign mem1_mem2_state_in_is_data_pis = mmu_data_ex_pis;
assign mem1_mem2_state_in_is_data_ppi = mmu_data_ex_ppi;
assign mem1_mem2_state_in_is_data_pme = mmu_data_ex_pme;



assign mem1_mem2_state_in_mmu_data_mat = mmu_data_mat;

mem1_mem2_state u_mem1_mem2_state(
    .clk(clk),
    .resetn(resetn),
    .stall(mem1_mem2_reg_stall),

    .in_is_exception(mem1_mem2_state_in_is_exception),
    .in_is_sys(mem1_mem2_state_in_is_sys),
    .in_is_int(mem1_mem2_state_in_is_int),
    .in_ertn_flush(mem1_mem2_state_in_ertn_flush),
    .in_csr_addr(mem1_mem2_state_in_csr_addr),
    .in_csr_we(mem1_mem2_state_in_csr_we),
    .in_csr_re(mem1_mem2_state_in_csr_re),

    .in_is_adef(mem1_mem2_state_in_is_adef),
    .in_is_ine(mem1_mem2_state_in_is_ine),
    .in_is_brk(mem1_mem2_state_in_is_brk),
    .in_is_ale(mem1_mem2_state_in_is_ale),

    .in_tlb_we(mem1_mem2_state_in_tlb_we),
    .in_invtlb_op(mem1_mem2_state_in_invtlb_op),
    .in_is_inst_tlbsrch(mem1_mem2_state_in_is_inst_tlbsrch),
    .in_is_inst_tlbrd(mem1_mem2_state_in_is_inst_tlbrd),
    .in_is_inst_tlbwr(mem1_mem2_state_in_is_inst_tlbwr),
    .in_is_inst_tlbfill(mem1_mem2_state_in_is_inst_tlbfill),
    .in_is_inst_invtlb(mem1_mem2_state_in_is_inst_invtlb),

    .in_tlbsrch_hit(mem1_mem2_state_in_tlbsrch_hit),
    .in_tlbrd_hit(mem1_mem2_state_in_tlbrd_hit),
    .in_tlb_w_csr_tlbelo0(mem1_mem2_state_in_tlb_w_csr_tlbelo0),
    .in_tlb_w_csr_tlbelo1(mem1_mem2_state_in_tlb_w_csr_tlbelo1),
    .in_tlb_w_csr_tlbidx(mem1_mem2_state_in_tlb_w_csr_tlbidx),
    .in_tlb_w_csr_tlbehi(mem1_mem2_state_in_tlb_w_csr_tlbehi),
    .in_tlb_w_csr_asid(mem1_mem2_state_in_tlb_w_csr_asid),

    .in_is_tlbr(mem1_mem2_state_in_is_tlbr),
    .in_is_inst_tlbr(mem1_mem2_state_in_is_inst_tlbr),
    .in_is_inst_pif(mem1_mem2_state_in_is_inst_pif),
    .in_is_inst_ppi(mem1_mem2_state_in_is_inst_ppi),
    .in_is_data_tlbr(mem1_mem2_state_in_is_data_tlbr),
    .in_is_data_pil(mem1_mem2_state_in_is_data_pil),
    .in_is_data_pis(mem1_mem2_state_in_is_data_pis),
    .in_is_data_ppi(mem1_mem2_state_in_is_data_ppi),
    .in_is_data_pme(mem1_mem2_state_in_is_data_pme),

    .in_mmu_data_mat(mem1_mem2_state_in_mmu_data_mat),

    
    .out_is_exception(mem1_mem2_state_out_is_exception),
    .out_is_sys(mem1_mem2_state_out_is_sys),
    .out_is_int(mem1_mem2_state_out_is_int),
    .out_ertn_flush(mem1_mem2_state_out_ertn_flush),
    .out_csr_addr(mem1_mem2_state_out_csr_addr),
    .out_csr_we(mem1_mem2_state_out_csr_we),
    .out_csr_re(mem1_mem2_state_out_csr_re),

    .out_is_adef(mem1_mem2_state_out_is_adef),
    .out_is_ine(mem1_mem2_state_out_is_ine),
    .out_is_brk(mem1_mem2_state_out_is_brk),
    .out_is_ale(mem1_mem2_state_out_is_ale),

    .out_tlb_we(mem1_mem2_state_out_tlb_we),
    .out_invtlb_op(mem1_mem2_state_out_invtlb_op),
    .out_is_inst_tlbsrch(mem1_mem2_state_out_is_inst_tlbsrch),
    .out_is_inst_tlbrd(mem1_mem2_state_out_is_inst_tlbrd),
    .out_is_inst_tlbwr(mem1_mem2_state_out_is_inst_tlbwr),
    .out_is_inst_tlbfill(mem1_mem2_state_out_is_inst_tlbfill),
    .out_is_inst_invtlb(mem1_mem2_state_out_is_inst_invtlb),

    .out_tlbsrch_hit(mem1_mem2_state_out_tlbsrch_hit),
    .out_tlbrd_hit(mem1_mem2_state_out_tlbrd_hit),
    .out_tlb_w_csr_tlbelo0(mem1_mem2_state_out_tlb_w_csr_tlbelo0),
    .out_tlb_w_csr_tlbelo1(mem1_mem2_state_out_tlb_w_csr_tlbelo1),
    .out_tlb_w_csr_tlbidx(mem1_mem2_state_out_tlb_w_csr_tlbidx),
    .out_tlb_w_csr_tlbehi(mem1_mem2_state_out_tlb_w_csr_tlbehi),
    .out_tlb_w_csr_asid(mem1_mem2_state_out_tlb_w_csr_asid),

    .out_is_tlbr(mem1_mem2_state_out_is_tlbr),
    .out_is_inst_tlbr(mem1_mem2_state_out_is_inst_tlbr),
    .out_is_inst_pif(mem1_mem2_state_out_is_inst_pif),
    .out_is_inst_ppi(mem1_mem2_state_out_is_inst_ppi),
    .out_is_data_tlbr(mem1_mem2_state_out_is_data_tlbr),
    .out_is_data_pil(mem1_mem2_state_out_is_data_pil),
    .out_is_data_pis(mem1_mem2_state_out_is_data_pis),
    .out_is_data_ppi(mem1_mem2_state_out_is_data_ppi),
    .out_is_data_pme(mem1_mem2_state_out_is_data_pme),

    .out_mmu_data_mat(mem1_mem2_state_out_mmu_data_mat)
);




assign mem2_wb_state_in_is_exception = mem1_mem2_state_out_is_exception ;
assign mem2_wb_state_in_is_sys = mem1_mem2_state_out_is_sys;
assign mem2_wb_state_in_is_int = mem1_mem2_state_out_is_int;
assign mem2_wb_state_in_ertn_flush = mem1_mem2_state_out_ertn_flush;
assign mem2_wb_state_in_csr_addr = mem1_mem2_state_out_csr_addr;
assign mem2_wb_state_in_csr_we = mem1_mem2_state_out_csr_we;
assign mem2_wb_state_in_csr_re = mem1_mem2_state_out_csr_re;
assign mem2_wb_state_in_is_adef = mem1_mem2_state_out_is_adef;
assign mem2_wb_state_in_is_ine = mem1_mem2_state_out_is_ine;
assign mem2_wb_state_in_is_brk = mem1_mem2_state_out_is_brk;
assign mem2_wb_state_in_is_ale = mem1_mem2_state_out_is_ale;



assign mem2_wb_state_in_tlb_we = mem1_mem2_state_out_tlb_we;
assign mem2_wb_state_in_invtlb_op = mem1_mem2_state_out_invtlb_op;
assign mem2_wb_state_in_is_inst_tlbsrch = mem1_mem2_state_out_is_inst_tlbsrch;
assign mem2_wb_state_in_is_inst_tlbrd = mem1_mem2_state_out_is_inst_tlbrd;
assign mem2_wb_state_in_is_inst_tlbwr = mem1_mem2_state_out_is_inst_tlbwr;
assign mem2_wb_state_in_is_inst_tlbfill = mem1_mem2_state_out_is_inst_tlbfill;
assign mem2_wb_state_in_is_inst_invtlb = mem1_mem2_state_out_is_inst_invtlb;



assign mem2_wb_state_in_tlbsrch_hit = mem1_mem2_state_out_tlbsrch_hit;
assign mem2_wb_state_in_tlbrd_hit = mem1_mem2_state_out_tlbrd_hit;
assign mem2_wb_state_in_tlb_w_csr_tlbelo0 = mem1_mem2_state_out_tlb_w_csr_tlbelo0;
assign mem2_wb_state_in_tlb_w_csr_tlbelo1 = mem1_mem2_state_out_tlb_w_csr_tlbelo1;
assign mem2_wb_state_in_tlb_w_csr_tlbidx = mem1_mem2_state_out_tlb_w_csr_tlbidx;
assign mem2_wb_state_in_tlb_w_csr_tlbehi = mem1_mem2_state_out_tlb_w_csr_tlbehi;
assign mem2_wb_state_in_tlb_w_csr_asid = mem1_mem2_state_out_tlb_w_csr_asid;



assign mem2_wb_state_in_is_tlbr = mem1_mem2_state_out_is_tlbr;
assign mem2_wb_state_in_is_inst_tlbr = mem1_mem2_state_out_is_inst_tlbr;
assign mem2_wb_state_in_is_inst_pif = mem1_mem2_state_out_is_inst_pif;
assign mem2_wb_state_in_is_inst_ppi = mem1_mem2_state_out_is_inst_ppi;
assign mem2_wb_state_in_is_data_tlbr = mem1_mem2_state_out_is_data_tlbr;
assign mem2_wb_state_in_is_data_pil = mem1_mem2_state_out_is_data_pil;
assign mem2_wb_state_in_is_data_pis = mem1_mem2_state_out_is_data_pis;
assign mem2_wb_state_in_is_data_ppi = mem1_mem2_state_out_is_data_ppi;
assign mem2_wb_state_in_is_data_pme = mem1_mem2_state_out_is_data_pme;

// ********************************************************
// wire m2wsexec,m2wsint;

// assign mem2_wb_state_out_is_exception = m2wsexec | is_int;
// assign mem2_wb_state_out_is_int = m2wsint | is_int;
// ********************************************************

mem2_wb_state u_mem2_wb_state(
    .clk(clk),
    .resetn(resetn),
    .stall(mem2_wb_reg_stall),

    .in_is_exception(mem2_wb_state_in_is_exception),
    .in_is_sys(mem2_wb_state_in_is_sys),
    .in_is_int(mem2_wb_state_in_is_int),
    .in_ertn_flush(mem2_wb_state_in_ertn_flush),
    .in_csr_addr(mem2_wb_state_in_csr_addr),
    .in_csr_we(mem2_wb_state_in_csr_we),
    .in_csr_re(mem2_wb_state_in_csr_re),

    .in_is_adef(mem2_wb_state_in_is_adef),
    .in_is_ine(mem2_wb_state_in_is_ine),
    .in_is_brk(mem2_wb_state_in_is_brk),
    .in_is_ale(mem2_wb_state_in_is_ale),

    .in_tlb_we(mem2_wb_state_in_tlb_we),
    .in_invtlb_op(mem2_wb_state_in_invtlb_op),
    .in_is_inst_tlbsrch(mem2_wb_state_in_is_inst_tlbsrch),
    .in_is_inst_tlbrd(mem2_wb_state_in_is_inst_tlbrd),
    .in_is_inst_tlbwr(mem2_wb_state_in_is_inst_tlbwr),
    .in_is_inst_tlbfill(mem2_wb_state_in_is_inst_tlbfill),
    .in_is_inst_invtlb(mem2_wb_state_in_is_inst_invtlb),

    .in_tlbsrch_hit(mem2_wb_state_in_tlbsrch_hit),
    .in_tlbrd_hit(mem2_wb_state_in_tlbrd_hit),
    .in_tlb_w_csr_tlbelo0(mem2_wb_state_in_tlb_w_csr_tlbelo0),
    .in_tlb_w_csr_tlbelo1(mem2_wb_state_in_tlb_w_csr_tlbelo1),
    .in_tlb_w_csr_tlbidx(mem2_wb_state_in_tlb_w_csr_tlbidx),
    .in_tlb_w_csr_tlbehi(mem2_wb_state_in_tlb_w_csr_tlbehi),
    .in_tlb_w_csr_asid(mem2_wb_state_in_tlb_w_csr_asid),

    .in_is_tlbr(mem2_wb_state_in_is_tlbr),
    .in_is_inst_tlbr(mem2_wb_state_in_is_inst_tlbr),
    .in_is_inst_pif(mem2_wb_state_in_is_inst_pif),
    .in_is_inst_ppi(mem2_wb_state_in_is_inst_ppi),
    .in_is_data_tlbr(mem2_wb_state_in_is_data_tlbr),
    .in_is_data_pil(mem2_wb_state_in_is_data_pil),
    .in_is_data_pis(mem2_wb_state_in_is_data_pis),
    .in_is_data_ppi(mem2_wb_state_in_is_data_ppi),
    .in_is_data_pme(mem2_wb_state_in_is_data_pme),
    
    .out_is_exception(mem2_wb_state_out_is_exception),
    .out_is_sys(mem2_wb_state_out_is_sys),
    .out_is_int(mem2_wb_state_out_is_int),
    .out_ertn_flush(mem2_wb_state_out_ertn_flush),
    .out_csr_addr(mem2_wb_state_out_csr_addr),
    .out_csr_we(mem2_wb_state_out_csr_we),
    .out_csr_re(mem2_wb_state_out_csr_re),

    .out_is_adef(mem2_wb_state_out_is_adef),
    .out_is_ine(mem2_wb_state_out_is_ine),
    .out_is_brk(mem2_wb_state_out_is_brk),
    .out_is_ale(mem2_wb_state_out_is_ale),

    .out_tlb_we(mem2_wb_state_out_tlb_we),
    .out_invtlb_op(mem2_wb_state_out_invtlb_op),
    .out_is_inst_tlbsrch(mem2_wb_state_out_is_inst_tlbsrch),
    .out_is_inst_tlbrd(mem2_wb_state_out_is_inst_tlbrd),
    .out_is_inst_tlbwr(mem2_wb_state_out_is_inst_tlbwr),
    .out_is_inst_tlbfill(mem2_wb_state_out_is_inst_tlbfill),
    .out_is_inst_invtlb(mem2_wb_state_out_is_inst_invtlb),

    .out_tlbsrch_hit(mem2_wb_state_out_tlbsrch_hit),
    .out_tlbrd_hit(mem2_wb_state_out_tlbrd_hit),
    .out_tlb_w_csr_tlbelo0(mem2_wb_state_out_tlb_w_csr_tlbelo0),
    .out_tlb_w_csr_tlbelo1(mem2_wb_state_out_tlb_w_csr_tlbelo1),
    .out_tlb_w_csr_tlbidx(mem2_wb_state_out_tlb_w_csr_tlbidx),
    .out_tlb_w_csr_tlbehi(mem2_wb_state_out_tlb_w_csr_tlbehi),
    .out_tlb_w_csr_asid(mem2_wb_state_out_tlb_w_csr_asid),

    .out_is_tlbr(mem2_wb_state_out_is_tlbr),
    .out_is_inst_tlbr(mem2_wb_state_out_is_inst_tlbr),
    .out_is_inst_pif(mem2_wb_state_out_is_inst_pif),
    .out_is_inst_ppi(mem2_wb_state_out_is_inst_ppi),
    .out_is_data_tlbr(mem2_wb_state_out_is_data_tlbr),
    .out_is_data_pil(mem2_wb_state_out_is_data_pil),
    .out_is_data_pis(mem2_wb_state_out_is_data_pis),
    .out_is_data_ppi(mem2_wb_state_out_is_data_ppi),
    .out_is_data_pme(mem2_wb_state_out_is_data_pme)
);

`ifdef difftest



assign csr_regfile_intrpt = intrpt;

`elsif perftest_or_linux


assign csr_regfile_intrpt = intrpt;

    
`else


assign csr_regfile_intrpt = 8'b0;

`endif


assign csr_regfile_ipi_int = 1'b0; //
assign csr_regfile_pc = mem2_wb_reg_out_pc;
assign csr_regfile_vaddr = mem2_wb_reg_out_vaddr;
assign csr_regfile_raddr = ctrl_csr_addr;
assign csr_regfile_waddr = mem2_wb_state_out_csr_addr;
assign csr_regfile_we = mem2_wb_state_out_csr_we && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception; //
assign csr_regfile_wdata = mem2_wb_reg_out_regfile_rdata2;
assign csr_regfile_wmask = mem2_wb_reg_out_regfile_rdata1;
assign csr_regfile_is_exception = mem2_wb_state_out_is_exception && mem2_wb_reg_out_valid; //
assign csr_regfile_ertn_flush = mem2_wb_state_out_ertn_flush && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception; //

assign csr_regfile_is_int = mem2_wb_state_out_is_int;
assign csr_regfile_is_sys = mem2_wb_state_out_is_sys;
assign csr_regfile_is_adef = mem2_wb_state_out_is_adef;
assign csr_regfile_is_ale = mem2_wb_state_out_is_ale;
assign csr_regfile_is_brk = mem2_wb_state_out_is_brk;
assign csr_regfile_is_ine = mem2_wb_state_out_is_ine;



assign csr_regfile_is_tlbsrch = mem2_wb_state_out_is_inst_tlbsrch && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception;
assign csr_regfile_tlbsrch_hit = mem2_wb_state_out_tlbsrch_hit;
assign csr_regfile_is_tlbrd = mem2_wb_state_out_is_inst_tlbrd && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception;
assign csr_regfile_tlbrd_hit = mem2_wb_state_out_tlbrd_hit;
assign csr_regfile_tlb_w_csr_tlbelo0 = mem2_wb_state_out_tlb_w_csr_tlbelo0;
assign csr_regfile_tlb_w_csr_tlbelo1 = mem2_wb_state_out_tlb_w_csr_tlbelo1;
assign csr_regfile_tlb_w_csr_tlbidx = mem2_wb_state_out_tlb_w_csr_tlbidx;
assign csr_regfile_tlb_w_csr_tlbehi = mem2_wb_state_out_tlb_w_csr_tlbehi;
assign csr_regfile_tlb_w_csr_asid = mem2_wb_state_out_tlb_w_csr_asid;



assign csr_regfile_is_tlbr = mem2_wb_state_out_is_tlbr;
assign csr_regfile_is_inst_tlbr = mem2_wb_state_out_is_inst_tlbr;
assign csr_regfile_is_inst_pif = mem2_wb_state_out_is_inst_pif;
assign csr_regfile_is_inst_ppi = mem2_wb_state_out_is_inst_ppi;
assign csr_regfile_is_data_tlbr = mem2_wb_state_out_is_data_tlbr;
assign csr_regfile_is_data_pil = mem2_wb_state_out_is_data_pil;
assign csr_regfile_is_data_pis = mem2_wb_state_out_is_data_pis;
assign csr_regfile_is_data_ppi = mem2_wb_state_out_is_data_ppi;
assign csr_regfile_is_data_pme = mem2_wb_state_out_is_data_pme;




assign csr_regfile_is_ll_w = mem2_wb_reg_out_is_inst_ll_w && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception;
assign csr_regfile_is_sc_w = mem2_wb_reg_out_is_inst_sc_w && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception;

csr_regfile u_csr_regfile(
    .clk(clk),
    .resetn(resetn),
    .intrpt(csr_regfile_intrpt),
    .ipi_int(csr_regfile_ipi_int),
    .pc(csr_regfile_pc),
    .vaddr(csr_regfile_vaddr),


    .raddr(csr_regfile_raddr),
    .rdata(csr_regfile_rdata),


    .waddr(csr_regfile_waddr),
    .we(csr_regfile_we),
    .wdata(csr_regfile_wdata),
    .wmask(csr_regfile_wmask),


    .is_exception(csr_regfile_is_exception),
    .ertn_flush(csr_regfile_ertn_flush),


    .has_int(csr_regfile_has_int),


    .is_int(csr_regfile_is_int),
    .is_sys(csr_regfile_is_sys),
    .is_adef(csr_regfile_is_adef),
    .is_ale(csr_regfile_is_ale),
    .is_brk(csr_regfile_is_brk),
    .is_ine(csr_regfile_is_ine),

    .is_tlbr(csr_regfile_is_tlbr),
    .is_inst_tlbr(csr_regfile_is_inst_tlbr),
    .is_inst_pif(csr_regfile_is_inst_pif),
    .is_inst_ppi(csr_regfile_is_inst_ppi),
    .is_data_tlbr(csr_regfile_is_data_tlbr),
    .is_data_pil(csr_regfile_is_data_pil),
    .is_data_pis(csr_regfile_is_data_pis),
    .is_data_ppi(csr_regfile_is_data_ppi),
    .is_data_pme(csr_regfile_is_data_pme),


    .exception_enter_addr(csr_regfile_exception_enter_addr),
    .exception_return_addr(csr_regfile_exception_return_addr),
    .exception_tlb_enter_addr(csr_regfile_exception_tlb_enter_addr),

    .out_csr_crmd(csr_regfile_out_csr_crmd),
    .out_csr_dmw0(csr_regfile_out_csr_dmw0),
    .out_csr_dmw1(csr_regfile_out_csr_dmw1),
    .out_csr_asid(csr_regfile_out_csr_asid),
    .out_csr_estat(csr_regfile_out_csr_estat),
    .out_csr_tlbidx(csr_regfile_out_csr_tlbidx),
    .out_csr_tlbehi(csr_regfile_out_csr_tlbehi),
    .out_csr_tlbelo0(csr_regfile_out_csr_tlbelo0),
    .out_csr_tlbelo1(csr_regfile_out_csr_tlbelo1),

    .is_tlbsrch(csr_regfile_is_tlbsrch),
    .tlbsrch_hit(csr_regfile_tlbsrch_hit),
    .is_tlbrd(csr_regfile_is_tlbrd),
    .tlbrd_hit(csr_regfile_tlbrd_hit),
    .tlb_w_csr_tlbelo0(csr_regfile_tlb_w_csr_tlbelo0),
    .tlb_w_csr_tlbelo1(csr_regfile_tlb_w_csr_tlbelo1),
    .tlb_w_csr_tlbidx(csr_regfile_tlb_w_csr_tlbidx),
    .tlb_w_csr_tlbehi(csr_regfile_tlb_w_csr_tlbehi),
    .tlb_w_csr_asid(csr_regfile_tlb_w_csr_asid),

    .is_ll_w(csr_regfile_is_ll_w),
    .is_sc_w(csr_regfile_is_sc_w),

    .llbit(csr_regfile_llbit)


);





  


assign mmu_csr_crmd_plv = csr_regfile_out_csr_crmd[`CSR_CRMD_PLV];
assign mmu_csr_crmd_da = csr_regfile_out_csr_crmd[`CSR_CRMD_DA];
assign mmu_csr_crmd_pg = csr_regfile_out_csr_crmd[`CSR_CRMD_PG];
assign mmu_csr_crmd_datf = csr_regfile_out_csr_crmd[`CSR_CRMD_DATF];
assign mmu_csr_crmd_datm = csr_regfile_out_csr_crmd[`CSR_CRMD_DATM];
assign mmu_csr_dmw0 = csr_regfile_out_csr_dmw0;
assign mmu_csr_dmw1 = csr_regfile_out_csr_dmw1;
assign mmu_csr_asid_asid = csr_regfile_out_csr_asid[`CSR_ASID_ASID];
assign mmu_csr_estat_ecode = csr_regfile_out_csr_estat[`CSR_ESTAT_ECODE];
assign mmu_csr_tlbidx_index = csr_regfile_out_csr_tlbidx[`CSR_TLBIDX_INDEX];
assign mmu_csr_tlbidx_ps = csr_regfile_out_csr_tlbidx[`CSR_TLBIDX_PS];
assign mmu_csr_tlbidx_ne = csr_regfile_out_csr_tlbidx[`CSR_TLBIDX_NE];
assign mmu_csr_tlbehi_vppn = csr_regfile_out_csr_tlbehi[`CSR_TLBEHI_VPPN];
assign mmu_csr_tlbelo0_v = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_V];
assign mmu_csr_tlbelo0_d = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_D];
assign mmu_csr_tlbelo0_plv = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_PLV];
assign mmu_csr_tlbelo0_mat = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_MAT];
assign mmu_csr_tlbelo0_g = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_G];
assign mmu_csr_tlbelo0_ppn = csr_regfile_out_csr_tlbelo0[`CSR_TLBELO0_PPN];
assign mmu_csr_tlbelo1_v = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_V];
assign mmu_csr_tlbelo1_d = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_D];
assign mmu_csr_tlbelo1_plv = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_PLV];
assign mmu_csr_tlbelo1_mat = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_MAT];
assign mmu_csr_tlbelo1_g = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_G];
assign mmu_csr_tlbelo1_ppn = csr_regfile_out_csr_tlbelo1[`CSR_TLBELO1_PPN];

assign mmu_inst_va = {pc_reg_pc[31:2], 2'b00};
assign mmu_data_va = exe_mem1_reg_out_sel_load_store_len == `SEL_LOAD_STORE_W ? {exe_mem1_reg_out_vaddr[31:2], 2'b00} :
                    (exe_mem1_reg_out_sel_load_store_len == `SEL_LOAD_STORE_H || exe_mem1_reg_out_sel_load_store_len == `SEL_LOAD_STORE_HU) ? {exe_mem1_reg_out_vaddr[31:1], 1'b0} :
                    exe_mem1_reg_out_vaddr;

assign mmu_data_mem_type[1] = exe_mem1_reg_out_is_store;
assign mmu_data_mem_type[0] = exe_mem1_reg_out_is_load || (exe_mem1_reg_out_is_cacop && exe_mem1_state_out_invtlb_op[4:3] == 2'b10);

assign mmu_is_tlbsrch = exe_mem1_state_out_is_inst_tlbsrch;
assign mmu_is_tlbrd = exe_mem1_state_out_is_inst_tlbrd;
assign mmu_is_tlbwr = mem2_wb_state_out_is_inst_tlbwr && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception;
assign mmu_is_tlbfill = mem2_wb_state_out_is_inst_tlbfill && mem2_wb_reg_out_valid&& !mem2_wb_state_out_is_exception;
assign mmu_is_invtlb = mem2_wb_state_out_is_inst_invtlb && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception;
assign mmu_invtlb_op = mem2_wb_state_out_invtlb_op;
assign mmu_rj = mem2_wb_reg_out_regfile_rdata1;
assign mmu_rk = mem2_wb_reg_out_regfile_rdata2;



assign tlb_w_csr_tlbelo0 = {mmu_out_csr_tlbelo0_ppn, 1'b0, mmu_out_csr_tlbelo0_g, mmu_out_csr_tlbelo0_mat, 
                            mmu_out_csr_tlbelo0_plv, mmu_out_csr_tlbelo0_d, mmu_out_csr_tlbelo0_v};

assign tlb_w_csr_tlbelo1 = {mmu_out_csr_tlbelo1_ppn, 1'b0, mmu_out_csr_tlbelo1_g, mmu_out_csr_tlbelo1_mat, 
                            mmu_out_csr_tlbelo1_plv, mmu_out_csr_tlbelo1_d, mmu_out_csr_tlbelo1_v};

assign tlb_w_csr_tlbidx = {mmu_out_csr_tlbidx_ne, 1'b0, mmu_out_csr_tlbidx_ps, 20'b0, mmu_out_csr_tlbidx_index};

assign tlb_w_csr_asid = {22'b0, mmu_out_csr_asid_asid};

assign tlb_w_csr_tlbehi = {mmu_out_csr_tlbehi_vppn, 13'b0};

wire [3:0] mmu_tlbfill_index;


mmu u_mmu(
    .clk(clk),
    .resetn(resetn),

    .csr_crmd_plv(mmu_csr_crmd_plv),
    .csr_crmd_da(mmu_csr_crmd_da),
    .csr_crmd_pg(mmu_csr_crmd_pg),
    .csr_crmd_datf(mmu_csr_crmd_datf),
    .csr_crmd_datm(mmu_csr_crmd_datm),
    .csr_dmw0(mmu_csr_dmw0),
    .csr_dmw1(mmu_csr_dmw1),
    .csr_asid_asid(mmu_csr_asid_asid),
    .csr_estat_ecode(mmu_csr_estat_ecode),


    .csr_tlbidx_index(mmu_csr_tlbidx_index),
    .csr_tlbidx_ps(mmu_csr_tlbidx_ps),
    .csr_tlbidx_ne(mmu_csr_tlbidx_ne),

    .csr_tlbehi_vppn(mmu_csr_tlbehi_vppn),

    .csr_tlbelo0_v(mmu_csr_tlbelo0_v),
    .csr_tlbelo0_d(mmu_csr_tlbelo0_d),
    .csr_tlbelo0_plv(mmu_csr_tlbelo0_plv),
    .csr_tlbelo0_mat(mmu_csr_tlbelo0_mat),
    .csr_tlbelo0_g(mmu_csr_tlbelo0_g),
    .csr_tlbelo0_ppn(mmu_csr_tlbelo0_ppn),
    
    .csr_tlbelo1_v(mmu_csr_tlbelo1_v),
    .csr_tlbelo1_d(mmu_csr_tlbelo1_d),
    .csr_tlbelo1_plv(mmu_csr_tlbelo1_plv),
    .csr_tlbelo1_mat(mmu_csr_tlbelo1_mat),
    .csr_tlbelo1_g(mmu_csr_tlbelo1_g),
    .csr_tlbelo1_ppn(mmu_csr_tlbelo1_ppn),

    .out_csr_tlbelo0_v(mmu_out_csr_tlbelo0_v),
    .out_csr_tlbelo0_d(mmu_out_csr_tlbelo0_d),
    .out_csr_tlbelo0_plv(mmu_out_csr_tlbelo0_plv),
    .out_csr_tlbelo0_mat(mmu_out_csr_tlbelo0_mat),
    .out_csr_tlbelo0_g(mmu_out_csr_tlbelo0_g),
    .out_csr_tlbelo0_ppn(mmu_out_csr_tlbelo0_ppn),

    .out_csr_tlbelo1_v(mmu_out_csr_tlbelo1_v),
    .out_csr_tlbelo1_d(mmu_out_csr_tlbelo1_d),
    .out_csr_tlbelo1_plv(mmu_out_csr_tlbelo1_plv),
    .out_csr_tlbelo1_mat(mmu_out_csr_tlbelo1_mat),
    .out_csr_tlbelo1_g(mmu_out_csr_tlbelo1_g),
    .out_csr_tlbelo1_ppn(mmu_out_csr_tlbelo1_ppn),

    .out_csr_tlbidx_ps(mmu_out_csr_tlbidx_ps),
    .out_csr_tlbidx_ne(mmu_out_csr_tlbidx_ne),
    .out_csr_tlbehi_vppn(mmu_out_csr_tlbehi_vppn),
    .out_csr_asid_asid(mmu_out_csr_asid_asid),

    .tlbrd_hit(mmu_tlbrd_hit),

    .inst_va(mmu_inst_va),
    .inst_pa(mmu_inst_pa),
    .inst_mat(mmu_inst_mat),
    .inst_ex_tlbr(mmu_inst_ex_tlbr),
    .inst_ex_pif(mmu_inst_ex_pif),
    .inst_ex_ppi(mmu_inst_ex_ppi),

    .data_va(mmu_data_va),
    .data_mem_type(mmu_data_mem_type),
    .data_pa(mmu_data_pa),
    .data_mat(mmu_data_mat),
    .data_ex_tlbr(mmu_data_ex_tlbr),
    .data_ex_pil(mmu_data_ex_pil),
    .data_ex_pis(mmu_data_ex_pis),
    .data_ex_ppi(mmu_data_ex_ppi),
    .data_ex_pme(mmu_data_ex_pme),

    .is_tlbsrch(mmu_is_tlbsrch),
    .is_tlbrd(mmu_is_tlbrd),
    .is_tlbwr(mmu_is_tlbwr),
    .is_tlbfill(mmu_is_tlbfill),
    .is_invtlb(mmu_is_invtlb),
    .invtlb_op(mmu_invtlb_op),
    .rj(mmu_rj),
    .rk(mmu_rk),
    
    .tlbsrch_hit(mmu_tlbsrch_hit),
    .out_csr_tlbidx_index(mmu_out_csr_tlbidx_index),

    .tlbfill_index(mmu_tlbfill_index)

);























assign data_sram_wr = mem1_mem2_reg_out_is_store;
assign data_sram_size = mem1_mem2_reg_out_sel_load_store_len == `SEL_LOAD_STORE_W ? 2'b10 :
                        (mem1_mem2_reg_out_sel_load_store_len == `SEL_LOAD_STORE_H || mem1_mem2_reg_out_sel_load_store_len == `SEL_LOAD_STORE_HU) ? 2'b01:
                        2'b00;
assign data_sram_wstrb = select_store_modified_we;
assign data_sram_addr = mem1_mem2_reg_out_data_pa;
assign data_sram_wdata = select_store_result;








assign inst_sram_wr = 1'b0;
assign inst_sram_size = 2'b10;
assign inst_sram_wstrb = 4'b0000;
assign inst_sram_addr = if1_if2_reg_out_pc_pa;
assign inst_sram_wdata = 32'd0;






`ifdef difftest

assign debug0_wb_pc = mem2_wb_reg_out_pc;
assign debug0_wb_rf_wen = {4{regfile_we}};
assign debug0_wb_rf_wnum = regfile_waddr;
assign debug0_wb_rf_wdata = regfile_wdata;


`elsif perftest_or_linux

assign debug0_wb_pc = mem2_wb_reg_out_pc;
assign debug0_wb_rf_wen = {4{regfile_we}};
assign debug0_wb_rf_wnum = regfile_waddr;
assign debug0_wb_rf_wdata = regfile_wdata;


`else

assign debug_wb_pc = mem2_wb_reg_out_pc;
assign debug_wb_rf_we = {4{regfile_we}};
assign debug_wb_rf_wnum = regfile_waddr;
assign debug_wb_rf_wdata = regfile_wdata;

`endif


`ifdef difftest

wire difftest_id_exe_reg_in_csr_3w;
wire difftest_id_exe_reg_in_is_CNTinst;
wire [7:0] difftest_id_exe_reg_in_load_valid;
wire [7:0] difftest_id_exe_reg_in_store_valid;
wire [63:0] difftest_id_exe_reg_in_timer_64_value;

wire difftest_id_exe_reg_out_csr_3w;
wire difftest_id_exe_reg_out_is_CNTinst;
wire [7:0] difftest_id_exe_reg_out_load_valid;
wire [7:0] difftest_id_exe_reg_out_store_valid;
wire [63:0] difftest_id_exe_reg_out_timer_64_value;

assign difftest_id_exe_reg_in_csr_3w = csr_3w;
assign difftest_id_exe_reg_in_is_CNTinst = is_CNTinst;
assign difftest_id_exe_reg_in_load_valid = load_valid;
assign difftest_id_exe_reg_in_store_valid = store_valid;
assign difftest_id_exe_reg_in_timer_64_value = rdcnt;



difftest_id_exe_reg u_difftest_id_exe_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(id_exe_reg_stall),

    .in_csr_3w(difftest_id_exe_reg_in_csr_3w),
    .in_is_CNTinst(difftest_id_exe_reg_in_is_CNTinst),
    .in_load_valid(difftest_id_exe_reg_in_load_valid),
    .in_store_valid(difftest_id_exe_reg_in_store_valid),
    .in_timer_64_value(difftest_id_exe_reg_in_timer_64_value),

    .out_csr_3w(difftest_id_exe_reg_out_csr_3w),
    .out_is_CNTinst(difftest_id_exe_reg_out_is_CNTinst),
    .out_load_valid(difftest_id_exe_reg_out_load_valid),
    .out_store_valid(difftest_id_exe_reg_out_store_valid),
    .out_timer_64_value(difftest_id_exe_reg_out_timer_64_value)
);


wire difftest_exe_mem1_reg_in_csr_3w;
wire difftest_exe_mem1_reg_in_is_CNTinst;
wire [7:0] difftest_exe_mem1_reg_in_load_valid;
wire [7:0] difftest_exe_mem1_reg_in_store_valid;
wire [63:0] difftest_exe_mem1_reg_in_timer_64_value;

wire difftest_exe_mem1_reg_out_csr_3w;
wire difftest_exe_mem1_reg_out_is_CNTinst;
wire [7:0] difftest_exe_mem1_reg_out_load_valid;
wire [7:0] difftest_exe_mem1_reg_out_store_valid;
wire [63:0] difftest_exe_mem1_reg_out_timer_64_value;

assign difftest_exe_mem1_reg_in_csr_3w = difftest_id_exe_reg_out_csr_3w;
assign difftest_exe_mem1_reg_in_is_CNTinst = difftest_id_exe_reg_out_is_CNTinst;
assign difftest_exe_mem1_reg_in_load_valid = difftest_id_exe_reg_out_load_valid;
assign difftest_exe_mem1_reg_in_store_valid = difftest_id_exe_reg_out_store_valid;
assign difftest_exe_mem1_reg_in_timer_64_value = difftest_id_exe_reg_out_timer_64_value;



difftest_exe_mem1_reg u_difftest_exe_mem1_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(exe_mem1_reg_stall),

    .in_csr_3w(difftest_exe_mem1_reg_in_csr_3w),
    .in_is_CNTinst(difftest_exe_mem1_reg_in_is_CNTinst),
    .in_load_valid(difftest_exe_mem1_reg_in_load_valid),
    .in_store_valid(difftest_exe_mem1_reg_in_store_valid),
    .in_timer_64_value(difftest_exe_mem1_reg_in_timer_64_value),

    .out_csr_3w(difftest_exe_mem1_reg_out_csr_3w),
    .out_is_CNTinst(difftest_exe_mem1_reg_out_is_CNTinst),
    .out_load_valid(difftest_exe_mem1_reg_out_load_valid),
    .out_store_valid(difftest_exe_mem1_reg_out_store_valid),
    .out_timer_64_value(difftest_exe_mem1_reg_out_timer_64_value)
);


wire difftest_mem1_mem2_reg_in_csr_3w;
wire difftest_mem1_mem2_reg_in_is_CNTinst;
wire [7:0] difftest_mem1_mem2_reg_in_load_valid;
wire [7:0] difftest_mem1_mem2_reg_in_store_valid;
wire [63:0] difftest_mem1_mem2_reg_in_timer_64_value;

wire [31:0] difftest_mem1_mem2_reg_in_vaddr;
wire [31:0] difftest_mem1_mem2_reg_in_paddr;

wire difftest_mem1_mem2_reg_out_csr_3w;
wire difftest_mem1_mem2_reg_out_is_CNTinst;
wire [7:0] difftest_mem1_mem2_reg_out_load_valid;
wire [7:0] difftest_mem1_mem2_reg_out_store_valid;
wire [63:0] difftest_mem1_mem2_reg_out_timer_64_value;

wire [31:0] difftest_mem1_mem2_reg_out_vaddr;
wire [31:0] difftest_mem1_mem2_reg_out_paddr;

assign difftest_mem1_mem2_reg_in_csr_3w = difftest_exe_mem1_reg_out_csr_3w;
assign difftest_mem1_mem2_reg_in_is_CNTinst = difftest_exe_mem1_reg_out_is_CNTinst;
assign difftest_mem1_mem2_reg_in_load_valid = difftest_exe_mem1_reg_out_load_valid;
assign difftest_mem1_mem2_reg_in_store_valid = difftest_exe_mem1_reg_out_store_valid;
assign difftest_mem1_mem2_reg_in_timer_64_value = difftest_exe_mem1_reg_out_timer_64_value;
assign difftest_mem1_mem2_reg_in_vaddr = mmu_data_va;
assign difftest_mem1_mem2_reg_in_paddr = mmu_data_pa;


difftest_mem1_mem2_reg u_difftest_mem1_mem2_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(mem1_mem2_reg_stall),

    .in_csr_3w(difftest_mem1_mem2_reg_in_csr_3w),
    .in_is_CNTinst(difftest_mem1_mem2_reg_in_is_CNTinst),
    .in_load_valid(difftest_mem1_mem2_reg_in_load_valid),
    .in_store_valid(difftest_mem1_mem2_reg_in_store_valid),
    .in_timer_64_value(difftest_mem1_mem2_reg_in_timer_64_value),
    .in_vaddr(difftest_mem1_mem2_reg_in_vaddr),
    .in_paddr(difftest_mem1_mem2_reg_in_paddr),

    .out_csr_3w(difftest_mem1_mem2_reg_out_csr_3w),
    .out_is_CNTinst(difftest_mem1_mem2_reg_out_is_CNTinst),
    .out_load_valid(difftest_mem1_mem2_reg_out_load_valid),
    .out_store_valid(difftest_mem1_mem2_reg_out_store_valid),
    .out_timer_64_value(difftest_mem1_mem2_reg_out_timer_64_value),
    .out_vaddr(difftest_mem1_mem2_reg_out_vaddr),
    .out_paddr(difftest_mem1_mem2_reg_out_paddr)
);



wire difftest_mem2_wb_reg_in_csr_3w;
wire difftest_mem2_wb_reg_in_is_CNTinst;
wire [7:0] difftest_mem2_wb_reg_in_load_valid;
wire [7:0] difftest_mem2_wb_reg_in_store_valid;
wire [63:0] difftest_mem2_wb_reg_in_timer_64_value;

wire [31:0] difftest_mem2_wb_reg_in_vaddr;
wire [31:0] difftest_mem2_wb_reg_in_paddr;

wire [31:0] difftest_mem2_wb_reg_in_storeData;

wire difftest_mem2_wb_reg_out_csr_3w;
wire difftest_mem2_wb_reg_out_is_CNTinst;
wire [7:0] difftest_mem2_wb_reg_out_load_valid;
wire [7:0] difftest_mem2_wb_reg_out_store_valid;
wire [63:0] difftest_mem2_wb_reg_out_timer_64_value;

wire [31:0] difftest_mem2_wb_reg_out_vaddr;
wire [31:0] difftest_mem2_wb_reg_out_paddr;

wire [31:0] difftest_mem2_wb_reg_out_storeData;


assign difftest_mem2_wb_reg_in_csr_3w = difftest_mem1_mem2_reg_out_csr_3w;
assign difftest_mem2_wb_reg_in_is_CNTinst = difftest_mem1_mem2_reg_out_is_CNTinst;
assign difftest_mem2_wb_reg_in_load_valid = difftest_mem1_mem2_reg_out_load_valid;
assign difftest_mem2_wb_reg_in_store_valid = difftest_mem1_mem2_reg_out_store_valid & {4'b1111, csr_regfile_llbit, 3'b111};
assign difftest_mem2_wb_reg_in_timer_64_value = difftest_mem1_mem2_reg_out_timer_64_value;
assign difftest_mem2_wb_reg_in_vaddr = difftest_mem1_mem2_reg_out_vaddr;
assign difftest_mem2_wb_reg_in_paddr = difftest_mem1_mem2_reg_out_paddr;
assign difftest_mem2_wb_reg_in_storeData = select_store_result & {{8{data_sram_wstrb[3]}}, {8{data_sram_wstrb[2]}}, {8{data_sram_wstrb[1]}}, {8{data_sram_wstrb[0]}}};

difftest_mem2_wb_reg u_difftest_mem2_wb_reg(
    .clk(clk),
    .resetn(resetn),
    
    .stall(mem2_wb_reg_stall),

    .in_csr_3w(difftest_mem2_wb_reg_in_csr_3w),
    .in_is_CNTinst(difftest_mem2_wb_reg_in_is_CNTinst),
    .in_load_valid(difftest_mem2_wb_reg_in_load_valid),
    .in_store_valid(difftest_mem2_wb_reg_in_store_valid),
    .in_timer_64_value(difftest_mem2_wb_reg_in_timer_64_value),
    .in_vaddr(difftest_mem2_wb_reg_in_vaddr),
    .in_paddr(difftest_mem2_wb_reg_in_paddr),
    .in_storeData(difftest_mem2_wb_reg_in_storeData),

    .out_csr_3w(difftest_mem2_wb_reg_out_csr_3w),
    .out_is_CNTinst(difftest_mem2_wb_reg_out_is_CNTinst),
    .out_load_valid(difftest_mem2_wb_reg_out_load_valid),
    .out_store_valid(difftest_mem2_wb_reg_out_store_valid),
    .out_timer_64_value(difftest_mem2_wb_reg_out_timer_64_value),
    .out_vaddr(difftest_mem2_wb_reg_out_vaddr),
    .out_paddr(difftest_mem2_wb_reg_out_paddr),
    .out_storeData(difftest_mem2_wb_reg_out_storeData)
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




assign difftest_commit_reg_in_csr_3w = difftest_mem2_wb_reg_out_csr_3w;
assign difftest_commit_reg_in_is_CNTinst = difftest_mem2_wb_reg_out_is_CNTinst;
assign difftest_commit_reg_in_load_valid = difftest_mem2_wb_reg_out_load_valid;
assign difftest_commit_reg_in_store_valid = difftest_mem2_wb_reg_out_store_valid;
assign difftest_commit_reg_in_timer_64_value = difftest_mem2_wb_reg_out_timer_64_value;
assign difftest_commit_reg_in_vaddr = difftest_mem2_wb_reg_out_vaddr;
assign difftest_commit_reg_in_paddr = difftest_mem2_wb_reg_out_paddr;
assign difftest_commit_reg_in_storeData = difftest_mem2_wb_reg_out_storeData;

assign difftest_commit_reg_in_valid = wb_valid && !csr_regfile_is_exception;
assign difftest_commit_reg_in_pc = mem2_wb_reg_out_pc;
assign difftest_commit_reg_in_instruction = mem2_wb_reg_out_instruction;
assign difftest_commit_reg_in_is_tlbfill = mmu_is_tlbfill;
assign difftest_commit_reg_in_tlbfill_index = mmu_tlbfill_index;
assign difftest_commit_reg_in_wen = regfile_we;
assign difftest_commit_reg_in_wdest = regfile_waddr;
assign difftest_commit_reg_in_wdata = regfile_wdata;
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
    .pc             ({32'd0, mem2_wb_reg_out_pc}),
    .cycleCnt       (rdcnt),
    .instrCnt       (64'd0)  // TODO: connect instruction counter
);

// DifftestStoreEvent
DifftestStoreEvent u_difftest_StoreEvent(
    .clock          (clk),
    .coreid         (8'd0),
    .index          (8'd0),
    .valid          (difftest_commit_reg_out_store_valid &
                     {8{difftest_commit_reg_out_valid}}),
    .storePAddr     ({32'd0, difftest_commit_reg_out_paddr}),  // vaddr used as paddr (no MMU address translation in difftest)
    .storeVAddr     ({32'd0, difftest_commit_reg_out_vaddr}),
    .storeData      ({32'd0, difftest_commit_reg_out_storeData})  // TODO: actual store data
);

// DifftestLoadEvent
DifftestLoadEvent u_difftest_LoadEvent(
    .clock          (clk),
    .coreid         (8'd0),
    .index          (8'd0),
    .valid          (difftest_commit_reg_out_load_valid &
                     {8{difftest_commit_reg_out_valid}}),
    .paddr          ({32'd0, difftest_commit_reg_out_paddr}),  // vaddr used as paddr
    .vaddr          ({32'd0, difftest_commit_reg_out_vaddr})
);

// // DifftestCSRRegState
// DifftestCSRRegState u_difftest_CSRRegState(
//     .clock          (clk),
//     .coreid         (8'd0),
//     .crmd           ({32'd0, csr_regfile_out_csr_crmd}),
//     .prmd           (64'd0),  // TODO: connect if CSR has PRMD
//     .euen           (64'd0),
//     .ecfg           (64'd0),
//     .estat          ({32'd0, csr_regfile_out_csr_estat}),
//     .era            (64'd0),  // TODO: connect if CSR has ERA
//     .badv           (64'd0),  // TODO: connect if CSR has BADV
//     .eentry         (64'd0),  // TODO: connect if CSR has EENTRY
//     .tlbidx         ({32'd0, csr_regfile_out_csr_tlbidx}),
//     .tlbehi         ({32'd0, csr_regfile_out_csr_tlbehi}),
//     .tlbelo0        ({32'd0, csr_regfile_out_csr_tlbelo0}),
//     .tlbelo1        ({32'd0, csr_regfile_out_csr_tlbelo1}),
//     .asid           ({32'd0, csr_regfile_out_csr_asid}),
//     .pgdl           (64'd0),
//     .pgdh           (64'd0),
//     .save0          (64'd0),
//     .save1          (64'd0),
//     .save2          (64'd0),
//     .save3          (64'd0),
//     .tid            (64'd0),
//     .tcfg           (64'd0),
//     .tval           (64'd0),
//     .ticlr          (64'd0),
//     .llbctl         (64'd0),
//     .tlbrentry      (64'd0),
//     .dmw0           ({32'd0, csr_regfile_out_csr_dmw0}),
//     .dmw1           ({32'd0, csr_regfile_out_csr_dmw1})
// );

// DifftestGRegState
// genvar gpr_i;
// generate
//     for (gpr_i = 0; gpr_i < 32; gpr_i = gpr_i + 1) begin : gen_gpr_64
//         wire [63:0] gpr_dump_64 = {32'd0, gpr_dump[gpr_i]};
//     end
// endgenerate

// DifftestGRegState u_difftest_GRegState(
//     .clock          (clk),
//     .coreid         (8'd0),
//     .gpr_0          ({32'd0, gpr_dump[0]}),
//     .gpr_1          ({32'd0, gpr_dump[1]}),
//     .gpr_2          ({32'd0, gpr_dump[2]}),
//     .gpr_3          ({32'd0, gpr_dump[3]}),
//     .gpr_4          ({32'd0, gpr_dump[4]}),
//     .gpr_5          ({32'd0, gpr_dump[5]}),
//     .gpr_6          ({32'd0, gpr_dump[6]}),
//     .gpr_7          ({32'd0, gpr_dump[7]}),
//     .gpr_8          ({32'd0, gpr_dump[8]}),
//     .gpr_9          ({32'd0, gpr_dump[9]}),
//     .gpr_10         ({32'd0, gpr_dump[10]}),
//     .gpr_11         ({32'd0, gpr_dump[11]}),
//     .gpr_12         ({32'd0, gpr_dump[12]}),
//     .gpr_13         ({32'd0, gpr_dump[13]}),
//     .gpr_14         ({32'd0, gpr_dump[14]}),
//     .gpr_15         ({32'd0, gpr_dump[15]}),
//     .gpr_16         ({32'd0, gpr_dump[16]}),
//     .gpr_17         ({32'd0, gpr_dump[17]}),
//     .gpr_18         ({32'd0, gpr_dump[18]}),
//     .gpr_19         ({32'd0, gpr_dump[19]}),
//     .gpr_20         ({32'd0, gpr_dump[20]}),
//     .gpr_21         ({32'd0, gpr_dump[21]}),
//     .gpr_22         ({32'd0, gpr_dump[22]}),
//     .gpr_23         ({32'd0, gpr_dump[23]}),
//     .gpr_24         ({32'd0, gpr_dump[24]}),
//     .gpr_25         ({32'd0, gpr_dump[25]}),
//     .gpr_26         ({32'd0, gpr_dump[26]}),
//     .gpr_27         ({32'd0, gpr_dump[27]}),
//     .gpr_28         ({32'd0, gpr_dump[28]}),
//     .gpr_29         ({32'd0, gpr_dump[29]}),
//     .gpr_30         ({32'd0, gpr_dump[30]}),
//     .gpr_31         ({32'd0, gpr_dump[31]})
// );


`endif

endmodule
