module nop_logic_unit(
    input  wire        clk,
    input  wire        reset,
    input  wire        ertn_flush,
    input  wire        ex_flush,
    input  wire        refetch_flush,

    input  wire [ 4:0] rf_waddr_from_ex,
    input  wire [ 4:0] rf_waddr_from_mem,
    input  wire [ 4:0] rf_waddr_from_wb,
    input  wire        id_stage_is_inst_branch,
    input  wire        ex_stage_is_inst_ld,
    input  wire        mem_stage_is_inst_ld,
    input  wire        wb_stage_is_inst_ld,
    input  wire        ex_stage_is_csr_op,
    input  wire        mem_stage_is_csr_op,
    input  wire        wb_stage_is_csr_op,
    input  wire [31:0] pc_from_ex,
    input  wire [31:0] pc_from_id,
    input  wire        atom_nop,
    input  wire        idle_flag,
    input  wire        need_ex_forward,
    input  wire [ 1:0] ex_result_sel_from_ex,
    
    input  wire [ 4:0] rj,
    input  wire [ 4:0] rkd,

    input  wire        ex_valid,
    input  wire        mem_valid,
    input  wire        wb_valid,

    output wire        need_nop
);

// 需要阻塞的时候，把指令堵在 ID 级

assign need_nop = (  ex_flush || ertn_flush || refetch_flush ) ? 1'b0 :
                     atom_nop || idle_flag ||
                  (  need_ex_forward && |(ex_result_sel_from_ex ^ 2'b00)) ||
                  (  ex_stage_is_inst_ld && ((rf_waddr_from_ex == rj) || (rf_waddr_from_ex == rkd)) && ex_valid)  ||
                  (  mem_stage_is_inst_ld && ((rf_waddr_from_mem == rj) || (rf_waddr_from_mem == rkd)) && mem_valid )  ||            
                  ( (rf_waddr_from_ex  == rj ) && |(rj ^ 5'b0 ) && ex_stage_is_csr_op && ex_valid )  ||
                  ( (rf_waddr_from_ex  == rkd) && |(rkd ^ 5'b0) && ex_stage_is_csr_op && ex_valid )  ||
                  ( (rf_waddr_from_mem == rj ) && |(rj ^ 5'b0 ) && mem_stage_is_csr_op && mem_valid )  || 
                  ( (rf_waddr_from_mem == rkd) && |(rkd ^ 5'b0) && mem_stage_is_csr_op && mem_valid )  ||
                  ( (rf_waddr_from_wb  == rj ) && |(rj ^ 5'b0 ) && wb_stage_is_csr_op && wb_valid )  || 
                  ( (rf_waddr_from_wb  == rkd) && |(rkd ^ 5'b0) && wb_stage_is_csr_op && wb_valid )  ;

endmodule

