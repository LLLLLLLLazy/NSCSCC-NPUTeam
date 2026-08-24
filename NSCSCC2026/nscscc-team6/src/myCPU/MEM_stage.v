`include "mycpu.h"

module mem_stage(
    input  wire                        clk            ,
    input  wire                        reset          ,
    input  wire                        ms_reflush     , // ?????

    // ==========================================
    // 1. ???????? (???????? MEM0)
    // ==========================================
    output wire                        ms_allowin     ,
    input  wire                        es_to_ms_valid ,
    input  wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus   ,
    
    // ==========================================
    // 2. Data SRAM ???
    // ==========================================
    output wire                        dcache_uncache_en,
    output wire [19:0]                 ms_dcache_tag,
    input  wire [31:0]                 data_sram_rdata,
    input  wire                        data_sram_data_ok,
    input wire [31:0]                  ms_sb_fwd_data,
    input wire [3:0]                   ms_sb_fwd_strb,
    output wire                        dcache_cancel,

    // ==========================================
    // 3. ????? CSR ???????? (NEW!)
    // ==========================================

    output wire [13:0]                 csr_num,       // ???? CSR ???????
    input  wire [31:0]                 csr_rdata,     // CSR ??�????????????

    // ==========================================
    // 4. ???? CDB ???? ROB д?? (?????????)
    // ==========================================
    output wire                        ms_wb_valid    , // ???????????? ROB ??????????
    output wire [ 3:0]                 ms_rob_id      ,
    output wire                        cdb_we_2       , // ??д???
    output wire [ 5:0]                 ms_preg_rd     , // ???????????
    output wire [31:0]                 ms_final_result, // ?????д???????
    output wire                        ms_ex          ,
    output wire [128:0]                ms_exception   ,  // ???????
    output wire                        ms_inst_valid_cacop,
    output wire                        ms_inst_tlbsrch,
    output wire                        ms_inst_tlbrd,
    output wire                        ms_inst_tlbwr,
    output wire                        ms_inst_tlbfill,
    output  wire                        ms_tlb_hit,
    output wire [ 4:0]                 ms_tlb_index,
    output wire                         ms_inst_sc_w,
    output wire                         ms_sc_success,
    output wire                         ms_inst_ll_w,
    output wire [31:0]                  ms_pa,
    output wire                         ms_uncache_en,
    output wire                         ms_inst_dbar,
    output wire                         ms_inst_ibar,
    output wire                         ms_mem_we,
    input     wire    es_to_ms_sb_valid,
    input     wire    es_ready_go,
    output    wire    ms_to_sb_valid,
    // for tlb
 //   input     wire                     s1_found,   // from tlb
  //  input     wire [ 4:0]              s1_index,   // from tlb
    output wire [31:0] ms_va,
    output wire [31:0] ms_store_wdata
);

    reg         ms_valid;
    reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

    wire ms_ready_go;
    assign ms_allowin = !ms_valid || ms_ready_go;
always @(posedge clk) begin
        if (reset) begin
            ms_valid <= 1'b0;
            es_to_ms_bus_r <= {`ES_TO_MS_BUS_WD{1'b0}};
        end 
        else if (ms_reflush) begin
            // ST ????? mem1 ????? data_ok ?? 
            if (ms_valid && ms_mem_we && !data_sram_data_ok) begin
                ms_valid <= 1'b1; // ??????Ч??????????
            end
            // mem1 ????/??????????? mem0 ???????? ST ????? 
            else if (es_to_ms_sb_valid && es_ready_go) begin
                ms_valid <= 1'b1;
                es_to_ms_bus_r <= es_to_ms_bus;
            end
            // ????????Load/ALU????????? 
            else begin
                ms_valid <= 1'b0;
            end
        end
        else if (ms_allowin) begin
            ms_valid <= es_to_ms_valid;
            if (es_to_ms_valid) begin
                es_to_ms_bus_r <= es_to_ms_bus;
            end
        end
    end
assign ms_to_sb_valid = ms_valid;
    // ==========================================
    // ??????????
    // ==========================================
    wire [ 2:0] ms_load_op;
    wire        ms_res_from_mem;
    wire [31:0] ms_alu_result;
    wire [31:0] ms_pc;
    wire s1_found;
    wire [4:0] s1_index;
    assign ms_tlb_hit = s1_found;
    assign ms_tlb_index = s1_index;
    wire dcahce_cancel;
    assign dcache_cancel = (ms_res_from_mem && ( ms_sb_fwd_strb == 4'b1111)) ||  dcache_tlb_excp_cancel;
    assign ms_uncache_en = dcache_uncache_en;
    assign {
        s1_index,
        s1_found,
        ms_store_wdata,
        ms_inst_dbar,
        ms_inst_ibar,
        dcache_tlb_excp_cancel,
        ms_pa,
        ms_inst_sc_w,
        ms_sc_success,
        ms_inst_ll_w,
        dcache_uncache_en, // 1
        ms_dcache_tag,
        ms_inst_valid_cacop, // 1
        ms_inst_tlbsrch,
        ms_inst_tlbrd,
        ms_inst_tlbwr,
        ms_inst_tlbfill,
        ms_mem_we      ,  // 1
        ms_load_op     ,  // 3
        ms_res_from_mem,  // 1
        ms_gr_we       ,  // 1 (????????????)
        ms_preg_rd     ,  // 6 (???????????????????λ???6)
        ms_alu_result  ,  // 32
        ms_pc          ,  // 32
        ms_rob_id      ,  // 4 (????????????)
        ms_exception      // 129 (????????????)
    } = es_to_ms_bus_r;

wire [31:0] merged_rdata;
    
    // ???????? wstrb ? 1????? SB ?????????????????????????? SRAM ?????????????
    assign merged_rdata[ 7: 0] = ms_sb_fwd_strb[0] ? ms_sb_fwd_data[ 7: 0] : data_sram_rdata[ 7: 0];
    assign merged_rdata[15: 8] = ms_sb_fwd_strb[1] ? ms_sb_fwd_data[15: 8] : data_sram_rdata[15: 8];
    assign merged_rdata[23:16] = ms_sb_fwd_strb[2] ? ms_sb_fwd_data[23:16] : data_sram_rdata[23:16];
    assign merged_rdata[31:24] = ms_sb_fwd_strb[3] ? ms_sb_fwd_data[31:24] : data_sram_rdata[31:24];


    wire [7 :0] ld_b_result;
    wire [15:0] ld_h_result;
    
    assign ld_b_result = (ms_alu_result[1:0] == 2'b00) ? merged_rdata[ 7: 0] :
                         (ms_alu_result[1:0] == 2'b01) ? merged_rdata[15: 8] :
                         (ms_alu_result[1:0] == 2'b10) ? merged_rdata[23:16] : 
                                                         merged_rdata[31:24];
                                                         
    assign ld_h_result = (ms_alu_result[1:0] == 2'b00) ? merged_rdata[15: 0] : 
                                                         merged_rdata[31:16];
                                                         
    wire [31:0] mem_result = 
        (ms_load_op == 3'b001) ? {{24{ld_b_result[7]}}, ld_b_result} : // b
        (ms_load_op == 3'b010) ? {24'b0, ld_b_result}                : // bu
        (ms_load_op == 3'b011) ? {{16{ld_h_result[15]}}, ld_h_result}: // h
        (ms_load_op == 3'b100) ? {16'b0, ld_h_result}                : // hu
                                 merged_rdata;                         // w


    wire csr_re = ms_exception[128]; 
assign csr_num = ms_exception[62:49]; 

    // ??????????????? Load????????????????? CSR??? CSR ????????????? ALU ???
    assign ms_final_result = ms_res_from_mem ? mem_result : 
                             csr_re          ? csr_rdata  :
                             ms_inst_sc_w    ? {31'b0, ms_sc_success} : 
                                               ms_alu_result;


    // ????????Ч???
    wire ms_need_mem   = ms_valid && ((ms_res_from_mem &&( ms_sb_fwd_strb != 4'b1111)) || ms_mem_we);
    
    assign ms_ready_go = (ms_reflush && !ms_mem_we) ? 1'b1 :
                         ms_ex     ? 1'b1 :
                         ms_mem_we ? 1'b1 :
                         ms_need_mem ? data_sram_data_ok : 1'b1;

    // ??????д????Ч??? (?????????)
    assign ms_wb_valid = ms_valid && ms_ready_go && !ms_reflush && (!ms_mem_we || ms_inst_sc_w);

    // ???ж? (??????????????)
    assign ms_ex = ms_valid && (ms_exception[48] | ms_exception[47]); // ????λ????????????? ex ???
assign cdb_we_2 = ms_gr_we & ms_wb_valid;
assign ms_va = ms_alu_result;
endmodule


