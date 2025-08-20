`include "header.v"
/*
    冒险控制单元
    负责处理旁路、阻塞以及流水线刷新
*/
module bypass_unit(
    input [4:0]      rnum_a_id,
    input [4:0]      rnum_b_id,
    input [2:0]      c_reg_as_read,
    input [4:0]      rj,
    input [4:0]      rk,
    input [4:0]      rd,
    input      [`WIDTH_BYPASS_FROM_EXE_BUS-1:0]   bypass_from_exe_bus,
    input      [`WIDTH_BYPASS_FROM_PMEM_BUS-1:0]  bypass_from_pmem_bus,
    input      [`WIDTH_BYPASS_FROM_MEM_BUS-1:0]   bypass_from_mem_bus,
    output     [`WIDTH_BYPASS_TO_ID_BUS-1:0]      bypass_to_id_bus
);
    //MEM
    wire      [31:0]   rdata_c_mem;       //转发数据
    wire      [4:0]    rnum_as_write_mem;  
    wire               data_not_prepared_mem;
    assign {rnum_as_write_mem, data_not_prepared_mem, rdata_c_mem} = bypass_from_mem_bus;

    //PMEM
    wire      [31:0]   rdata_c_pmem;      //转发数据
    wire      [4:0]    rnum_as_write_pmem;  
    wire               data_not_prepared_pmem;
    assign {rnum_as_write_pmem,data_not_prepared_pmem , rdata_c_pmem} = bypass_from_pmem_bus;

    //EXE
    wire      [31:0]   rdata_c_exe;       //转发数据
    wire      [4:0]    rnum_as_write_exe;  
    wire               data_not_prepared_exe;
    assign {rnum_as_write_exe,data_not_prepared_exe , rdata_c_exe} = bypass_from_exe_bus;

    //ID
    reg      [3:0]      c_fwd_a_sel;
    reg      [3:0]      c_fwd_b_sel;
    wire                stall_id;
    wire                rnum_a_not_zero;
    wire                rnum_b_not_zero;
    //wire      [4:0]     rnum_as_write_id; 
    assign bypass_to_id_bus = {c_fwd_a_sel, c_fwd_b_sel, stall_id, rdata_c_exe, rdata_c_pmem, rdata_c_mem};
    assign rnum_a_not_zero = |rnum_a_id;
    assign rnum_b_not_zero = |rnum_b_id;
    //旁路控制信号生成
    always @(*)begin
        //A路
        if(rnum_as_write_exe == rnum_a_id && rnum_a_not_zero)
            c_fwd_a_sel = 4'b0010;
        else if(rnum_as_write_pmem == rnum_a_id && rnum_a_not_zero)
            c_fwd_a_sel = 4'b0100;
        else if(rnum_as_write_mem == rnum_a_id && rnum_a_not_zero)
            c_fwd_a_sel = 4'b1000;
        else c_fwd_a_sel = 4'b0001;
    end
    always @(*)begin
        //B路
        if(rnum_as_write_exe == rnum_b_id && rnum_b_not_zero)
            c_fwd_b_sel = 4'b0010;
        else if(rnum_as_write_pmem == rnum_b_id && rnum_b_not_zero)
            c_fwd_b_sel = 4'b0100;
        else if(rnum_as_write_mem == rnum_b_id && rnum_b_not_zero)
            c_fwd_b_sel = 4'b1000;
        else c_fwd_b_sel = 4'b0001;
    end
    //阻塞信号生成
    wire stall_caused_by_rj  =   (rnum_as_write_pmem == rj && data_not_prepared_pmem || rnum_as_write_exe == rj  && data_not_prepared_exe) && |rj;
    wire stall_caused_by_rk  =   (rnum_as_write_pmem == rk && data_not_prepared_pmem || rnum_as_write_exe == rk  && data_not_prepared_exe) && |rk;
    wire stall_caused_by_rd  =   (rnum_as_write_pmem == rd && data_not_prepared_pmem || rnum_as_write_exe == rd  && data_not_prepared_exe) && |rd;
    //LUT6
    assign stall_id = stall_caused_by_rj && c_reg_as_read[2] || stall_caused_by_rk && c_reg_as_read[1] || stall_caused_by_rd && c_reg_as_read[0]; 
endmodule
