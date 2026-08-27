`include "header.v"

module stall_clear_detector(
    input wire clk,
    input wire resetn,

    input wire pc_reg_out_valid,
    input wire if1_if2_reg_out_valid,
    input wire if2_id_reg_out_valid,
    input wire id_exe_reg_out_valid,
    input wire exe_mem1_reg_out_valid,
    input wire mem1_mem2_reg_out_valid,
    input wire mem2_wb_reg_out_valid,

    input wire [4:0] exe_mem1_reg_out_regfile_waddr,
    input wire [1:0] exe_mem1_reg_out_sel_regfile_wdata,
    input wire exe_mem1_reg_out_regfile_we,

    input wire [4:0] mem1_mem2_reg_out_regfile_waddr,
    input wire [1:0] mem1_mem2_reg_out_sel_regfile_wdata,
    input wire mem1_mem2_reg_out_regfile_we,

    input wire [4:0] id_exe_reg_out_regfile_waddr,
    input wire [1:0] id_exe_reg_out_sel_regfile_wdata,
    input wire id_exe_reg_out_regfile_we,

    input wire [4:0] regfile_raddr1,
    input wire [4:0] regfile_raddr2,

    input wire id_not_branch_taken,
    input wire exe_not_branch_taken,
    input wire mem1_not_branch_taken,

    input wire alu_multiply_divide_ready,



    input wire ctrl_csr_re,
    input wire id_exe_state_out_csr_we,
    input wire exe_mem1_state_out_csr_we,
    input wire mem1_mem2_state_out_csr_we,
    input wire mem2_wb_state_out_csr_we,

    input wire pc_state_out_is_exception,
    input wire if1_if2_state_out_is_exception,
    input wire if2_id_state_out_is_exception,
    input wire id_exe_state_out_is_exception,
    input wire exe_mem1_state_out_is_exception,
    input wire mem1_mem2_state_out_is_exception,
    input wire mem2_wb_state_out_is_exception,

    input wire mem1_mem2_state_out_ertn_flush,
    input wire mem2_wb_state_out_ertn_flush,



    output reg pc_reg_stall,
    output reg pc_reg_clear,
    output reg if1_if2_reg_stall,
    output reg if1_if2_reg_clear,
    output reg if2_id_reg_stall,
    output reg if2_id_reg_clear,
    output reg id_exe_reg_stall,
    output reg id_exe_reg_clear,
    output reg exe_mem1_reg_stall,
    output reg exe_mem1_reg_clear,
    output reg mem1_mem2_reg_stall,
    output reg mem1_mem2_reg_clear,
    output wire mem2_wb_reg_stall,
    output wire mem2_wb_reg_clear,


    input wire [2:0] inst_sram_fsm_state,
    input wire [2:0] data_sram_fsm_state,



    input wire ctrl_tlb_we,
    input wire id_exe_state_out_tlb_we,
    input wire exe_mem1_state_out_tlb_we,
    input wire mem1_mem2_state_out_tlb_we,
    input wire mem2_wb_state_out_tlb_we,

    input wire mem1_tlb_change,
    input wire [13:0] csr_regfile_waddr,

    input wire exe_mem1_reg_out_is_load,
    input wire exe_mem1_reg_out_is_store,
    input wire mem1_mem2_reg_out_is_load,
    input wire mem1_mem2_reg_out_is_store,
    input wire mem2_wb_reg_out_is_load,
    input wire mem2_wb_reg_out_is_store,


    input wire id_exe_reg_out_tlb_change,
    input wire exe_mem1_reg_out_tlb_change,
    input wire mem1_mem2_reg_out_tlb_change,
    input wire mem2_wb_reg_out_tlb_change,

    input wire mem1_mem2_reg_out_is_cacop,
    input wire [1:0] cacop_fsm_state,
 
    output reg cacop_req,

    input wire ctrl_is_inst_idle,
    input wire is_int,

    input wire mem1_mem2_reg_out_is_inst_sc_w,
    input wire csr_regfile_llbit,
    
    input wire wb_refetch,


    input wire cache_subsystem_if1_ready,
    input wire cache_subsystem_if2_refill_valid,
    input wire cache_subsystem_if2_miss,

    input wire cache_subsystem_mem2_ready,
    input wire cache_subsystem_mem2_refill_valid,
    input wire cache_subsystem_mem2_miss,

    input wire cache_subsystem_dcache_busy,
    input wire cache_subsystem_icache_busy

);

// reg delay_data_req;
// reg delay_inst_req;


// always @(posedge clk) begin
//     if(!resetn)
//         delay_data_req <= 1'b0;
//     else if(exe_mem1_reg_stall && data_sram_req)
//         delay_data_req <= 1'b1;
//     else if(!exe_mem1_reg_stall)
//         delay_data_req <= 1'b0;
// end


// always @(posedge clk) begin
//     if(!resetn)
//         delay_inst_req <= 1'b0;
//     else if(pc_reg_stall && inst_sram_req)
//         delay_inst_req <= 1'b1;
//     else if(!pc_reg_stall)
//         delay_inst_req <= 1'b0;
// end




// always @(*) begin
//     pc_reg_clear = 1'b0;
//     if1_if2_reg_clear = 1'b0;
//     if2_id_reg_clear = 1'b0;
//     id_exe_reg_clear = 1'b0;
//     exe_mem1_reg_clear = 1'b0;
//     mem1_mem2_reg_clear = 1'b0;
//     mem2_wb_reg_clear = 1'b0;


//     if(mem2_wb_reg_out_valid &&(mem2_wb_state_out_is_exception || mem2_wb_state_out_ertn_flush))
//     begin
//         pc_reg_clear = 1'b1;
//         if1_if2_reg_clear = 1'b1;
//         if2_id_reg_clear = 1'b1;
//         id_exe_reg_clear = 1'b1;
//         exe_mem1_reg_clear = 1'b1;
//         mem1_mem2_reg_clear = 1'b1;
        
//         // pc_reg_stall = 1'b0;
//         // if1_if2_reg_stall = 1'b0;
//         // if2_id_reg_stall = 1'b0;
//         // id_exe_reg_stall = 1'b0;
//         // exe_mem1_reg_stall = 1'b0;
//         // mem1_mem2_reg_stall = 1'b0;
//         // mem2_wb_reg_stall = 1'b0;
//     end
//     else if(!mem1_mem2_reg_stall && mem1_not_branch_taken)
//     begin
//         pc_reg_clear = 1'b1;
//         if1_if2_reg_clear = 1'b1;
//         if2_id_reg_clear = 1'b1;
//         id_exe_reg_clear = 1'b1;
        
//         // pc_reg_stall = 1'b0;
//         // if1_if2_reg_stall = 1'b0;
//         // if2_id_reg_stall = 1'b0;
//         // id_exe_reg_stall = 1'b0;
//         // exe_mem1_reg_stall = 1'b0;
//         // mem1_mem2_reg_stall = 1'b0;
//         // mem2_wb_reg_stall = 1'b0;

//     end
//     else if(!exe_mem1_reg_stall && exe_not_branch_taken)
//     begin
//         pc_reg_clear = 1'b1;
//         if1_if2_reg_clear = 1'b1;
//         if2_id_reg_clear = 1'b1;

//         // pc_reg_stall = 1'b0;
//         // if1_if2_reg_stall = 1'b0;
//         // if2_id_reg_stall = 1'b0;
//         // id_exe_reg_stall = 1'b0;
//         // exe_mem1_reg_stall = 1'b0;
//         // mem1_mem2_reg_stall = 1'b0;
//         // mem2_wb_reg_stall = 1'b0;
//     end
//     else if(!id_exe_reg_stall && id_not_branch_taken)
//     begin
//         pc_reg_clear = 1'b1;
//         if1_if2_reg_clear = 1'b1;
        
//         // pc_reg_stall = 1'b0;
//         // if1_if2_reg_stall = 1'b0;
//         // if2_id_reg_stall = 1'b0;
//         // id_exe_reg_stall = 1'b0;
//         // exe_mem1_reg_stall = 1'b0;
//         // mem1_mem2_reg_stall = 1'b0;
//         // mem2_wb_reg_stall = 1'b0;
//     end
//     else
//     begin
//         pc_reg_clear = 1'b0;
//         if1_if2_reg_clear = 1'b0;
//         if2_id_reg_clear = 1'b0;
//         id_exe_reg_clear = 1'b0;
//         exe_mem1_reg_clear = 1'b0;
//         mem1_mem2_reg_clear = 1'b0;
//         mem2_wb_reg_clear = 1'b0;
        
//         // pc_reg_stall = 1'b0;
//         // if1_if2_reg_stall = 1'b0;
//         // if2_id_reg_stall = 1'b0;
//         // id_exe_reg_stall = 1'b0;
//         // exe_mem1_reg_stall = 1'b0;
//         // mem1_mem2_reg_stall = 1'b0;
//         // mem2_wb_reg_stall = 1'b0;
//     end
// end

assign mem2_wb_reg_stall = 1'b0;
assign mem2_wb_reg_clear = 1'b0;

// always @(*) begin
//     if(mem2_wb_reg_clear)
//         mem2_wb_reg_stall = 1'b0;
//     else
//         mem2_wb_reg_stall = 1'b0;
// end


always @(*) begin
    cacop_req = 1'b0;
    if(mem2_wb_reg_clear || 
       (!mem2_wb_reg_stall && mem2_wb_reg_out_valid &&
        (mem2_wb_state_out_is_exception || mem2_wb_state_out_ertn_flush) ) || wb_refetch
      )
    begin
        mem1_mem2_reg_clear = 1'b1;
        mem1_mem2_reg_stall = 1'b0;
    end
    // else if(((mem2_wb_state_out_is_exception || mem2_wb_state_out_ertn_flush || mem2_wb_state_out_csr_we) && mem2_wb_reg_out_valid) &&
    //           mem1_mem2_reg_out_is_store && !mem1_mem2_state_out_is_exception && mem1_mem2_reg_out_valid)
    // begin
    //     mem1_mem2_reg_clear = 1'b0;
    //     mem1_mem2_reg_stall = 1'b1;
    // end
    // else if((mem2_wb_reg_out_is_store || mem2_wb_reg_out_is_load) && mem2_wb_reg_out_valid && !mem2_wb_state_out_is_exception &&
    //         mem1_mem2_reg_out_is_inst_sc_w && mem1_mem2_reg_out_valid && !mem1_mem2_state_out_is_exception)
    // begin
    //     mem1_mem2_reg_clear = 1'b0;
    //     mem1_mem2_reg_stall = 1'b1;
    // end
    else if(mem1_mem2_reg_out_valid && 
            !mem1_mem2_state_out_is_exception && 
            (mem1_mem2_reg_out_is_load || (mem1_mem2_reg_out_is_store && !mem1_mem2_reg_out_is_inst_sc_w) || 
            (mem1_mem2_reg_out_is_inst_sc_w && csr_regfile_llbit)) && 
            ((data_sram_fsm_state == `DATA_SRAM_FSM_IDLE && cache_subsystem_mem2_miss) || data_sram_fsm_state==`DATA_SRAM_FSM_SHAKE||(data_sram_fsm_state==`DATA_SRAM_FSM_WAIT && !cache_subsystem_mem2_refill_valid) ))
    begin
        mem1_mem2_reg_clear = 1'b0;
        mem1_mem2_reg_stall = 1'b1;
    end 
    else if(mem1_mem2_reg_out_valid && 
        !mem1_mem2_state_out_is_exception && 
        mem1_mem2_reg_out_is_cacop&&
        cacop_fsm_state != `SRAM_FINISH)
    begin
        cacop_req = cacop_fsm_state == `SRAM_IDLE;
        mem1_mem2_reg_clear = 1'b0;
        mem1_mem2_reg_stall = 1'b1;
    end
    else if(mem1_mem2_reg_out_valid && mem2_wb_reg_stall)
    begin
        mem1_mem2_reg_clear = 1'b0;
        mem1_mem2_reg_stall = 1'b1;
    end
    else
    begin
        mem1_mem2_reg_clear = 1'b0;
        mem1_mem2_reg_stall = 1'b0;
    end
end

always @(*) begin


    if(mem1_mem2_reg_clear)
    begin
        exe_mem1_reg_clear = 1'b1;
        exe_mem1_reg_stall = 1'b0;
    end
    else if(exe_mem1_reg_out_valid && !exe_mem1_state_out_is_exception &&cache_subsystem_dcache_busy && (exe_mem1_reg_out_is_load || exe_mem1_reg_out_is_store))
    begin
        exe_mem1_reg_clear = 1'b0;
        exe_mem1_reg_stall = 1'b1;
    end
    else if(exe_mem1_reg_out_valid && mem1_mem2_reg_stall)
    begin
        exe_mem1_reg_clear = 1'b0;
        exe_mem1_reg_stall = 1'b1;
    end
    else
    begin
        exe_mem1_reg_clear = 1'b0;
        exe_mem1_reg_stall = 1'b0;
    end

end

always @(*) begin
    if(exe_mem1_reg_clear || (!exe_mem1_reg_stall && mem1_not_branch_taken))
    begin
        id_exe_reg_clear = 1'b1;
        id_exe_reg_stall = 1'b0;
    end
    else if(id_exe_reg_out_valid && !alu_multiply_divide_ready && !id_exe_state_out_is_exception)
    begin
        id_exe_reg_clear = 1'b0;
        id_exe_reg_stall = 1'b1;
    end
    else if(id_exe_reg_out_valid && exe_mem1_reg_stall)
    begin
        id_exe_reg_clear = 1'b0;
        id_exe_reg_stall = 1'b1;
    end
    else 
    begin
        id_exe_reg_clear = 1'b0;
        id_exe_reg_stall = 1'b0;
    end
end

always @(*) begin
    //冗余的判断
    if(id_exe_reg_clear || (!id_exe_reg_stall && exe_not_branch_taken))
    begin
        if2_id_reg_clear = 1'b1;
        if2_id_reg_stall = 1'b0;
    end
    else if(if2_id_reg_out_valid == 1'b1 && !if2_id_state_out_is_exception &&
            ctrl_is_inst_idle && !is_int)
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b1;
    end
    else if(exe_mem1_reg_out_valid == 1'b1 && 
            if2_id_reg_out_valid == 1'b1 && 
            !exe_mem1_state_out_is_exception &&
            !if2_id_state_out_is_exception &&
            exe_mem1_reg_out_regfile_waddr != 5'd0 &&
            exe_mem1_reg_out_regfile_we == 1'b1 && 
            exe_mem1_reg_out_sel_regfile_wdata == `SEL_REGFILE_WDATA_MEM &&
            (exe_mem1_reg_out_regfile_waddr == regfile_raddr1 || 
             exe_mem1_reg_out_regfile_waddr == regfile_raddr2))
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b1;
    end
    else if(mem1_mem2_reg_out_valid == 1'b1 && 
        if2_id_reg_out_valid == 1'b1 && 
        !mem1_mem2_state_out_is_exception &&
        !if2_id_state_out_is_exception &&
        mem1_mem2_reg_out_regfile_waddr != 5'd0 &&
        mem1_mem2_reg_out_regfile_we == 1'b1 && 
        mem1_mem2_reg_out_sel_regfile_wdata == `SEL_REGFILE_WDATA_MEM &&
        (mem1_mem2_reg_out_regfile_waddr == regfile_raddr1 || 
            mem1_mem2_reg_out_regfile_waddr == regfile_raddr2))
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b1;
    end
    else if(id_exe_reg_out_valid == 1'b1 && 
            if2_id_reg_out_valid == 1'b1 && 
            id_exe_reg_out_regfile_waddr != 5'd0 &&
            id_exe_reg_out_regfile_we == 1'b1 && 
            !id_exe_state_out_is_exception &&
            !if2_id_state_out_is_exception &&
            (id_exe_reg_out_sel_regfile_wdata == `SEL_REGFILE_WDATA_MEM || 
                id_exe_reg_out_sel_regfile_wdata == `SEL_REGFILE_WDATA_ALU)&&
            (id_exe_reg_out_regfile_waddr == regfile_raddr1 || 
            id_exe_reg_out_regfile_waddr == regfile_raddr2))
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b1;
    end
    else if(ctrl_csr_re && if2_id_reg_out_valid && !if2_id_state_out_is_exception &&
            (((id_exe_state_out_csr_we ) && id_exe_reg_out_valid &&!id_exe_state_out_is_exception) ||
            ((exe_mem1_state_out_csr_we ) && exe_mem1_reg_out_valid &&!exe_mem1_state_out_is_exception) ||
            ((mem1_mem2_state_out_csr_we )&& mem1_mem2_reg_out_valid &&!mem1_mem2_state_out_is_exception) ||
            ((mem2_wb_state_out_csr_we ) && mem2_wb_reg_out_valid &&!mem2_wb_state_out_is_exception)))
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b1;
    end
    //简单判断tlb相关阻塞
    // else if(ctrl_tlb_we && if2_id_reg_out_valid && !if2_id_state_out_is_exception &&
    //     (((id_exe_reg_out_tlb_change) && id_exe_reg_out_valid &&!id_exe_state_out_is_exception) ||
    //     ((exe_mem1_reg_out_tlb_change) && exe_mem1_reg_out_valid &&!exe_mem1_state_out_is_exception) ||
    //     ((mem1_mem2_reg_out_tlb_change)&& mem1_mem2_reg_out_valid &&!mem1_mem2_state_out_is_exception) ||
    //     ((mem2_wb_reg_out_tlb_change) && mem2_wb_reg_out_valid &&!mem2_wb_state_out_is_exception)))
    // begin
    //     if2_id_reg_clear = 1'b0;
    //     if2_id_reg_stall = 1'b1;
    // end
    else if(if2_id_reg_out_valid && id_exe_reg_stall)
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b1;
    end
    else
    begin
        if2_id_reg_clear = 1'b0;
        if2_id_reg_stall = 1'b0;
    end

end

always @(*) begin

    if(if2_id_reg_clear || (!if2_id_reg_stall && id_not_branch_taken))
    begin
        if1_if2_reg_clear = 1'b1;
        if1_if2_reg_stall = 1'b0;
    end
    else if(if1_if2_reg_out_valid && !if1_if2_state_out_is_exception && ((inst_sram_fsm_state==`INST_SRAM_FSM_IDLE && cache_subsystem_if2_miss) || inst_sram_fsm_state==`INST_SRAM_FSM_MISS ||(inst_sram_fsm_state==`INST_SRAM_FSM_WAIT && !cache_subsystem_if2_refill_valid) ))
    begin
        if1_if2_reg_clear = 1'b0;
        if1_if2_reg_stall = 1'b1;
    end
    else if(if1_if2_reg_out_valid && if2_id_reg_stall)    
    begin
        if1_if2_reg_clear = 1'b0;
        if1_if2_reg_stall = 1'b1;
    end
    else
    begin
        if1_if2_reg_clear = 1'b0;
        if1_if2_reg_stall = 1'b0;
    end
end

always @(*) begin


    if(if1_if2_reg_clear)
    begin
        pc_reg_clear = 1'b1;
        pc_reg_stall = 1'b0;
    end
    else if(pc_reg_out_valid && !pc_state_out_is_exception &&cache_subsystem_icache_busy)
    begin
        pc_reg_clear = 1'b0;
        pc_reg_stall = 1'b1;
    end
    else if(pc_reg_out_valid && if1_if2_reg_stall)
    begin
        pc_reg_clear = 1'b0;
        pc_reg_stall = 1'b1;
    end
    else
    begin
        pc_reg_clear = 1'b0;
        pc_reg_stall = 1'b0;
    end
end


endmodule