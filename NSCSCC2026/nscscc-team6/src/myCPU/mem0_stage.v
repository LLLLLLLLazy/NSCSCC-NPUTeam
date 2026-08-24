`include "mycpu.h"

module mem0_stage(
    input       wire                   clk           ,
    input       wire                   reset         ,
    //allowin
    input      wire                    ms_allowin    ,
    output     wire                    issue_es_allowin    ,
    output     wire                    sb_empty,
    output     wire                    es_mem_we_stall,
    
    //from alu issue
    input       wire                     issue_valid  ,
    input       wire       [3:0]         issue_rob_id ,
    input       wire [`DE_TO_DS_BUS-1:0] issue_payload,
    input       wire       [31:0]        operand1     ,//from regfile
    input       wire       [31:0]        operand2     ,
    input       wire       [5:0]         issue_preg_rd,
    //to ms
    output     wire                    es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    
    output wire                        data_sram_en   ,
    output wire                        data_sram_wr   ,
    output wire [ 3:0]                 data_sram_we   ,
    output wire[ 2:0]                  data_sram_size ,
    output wire[31:0]                  data_sram_wdata,
    input  wire                        data_sram_addr_ok,
    input  wire                        data_sram_data_ok,
    output wire [6:0]                  dcache_index,
    output wire [4:0]                  dcache_offset,
    output wire                        preld_en,
    output wire [31:0]                 sb_fwd_data,
    output wire [3:0]                  sb_fwd_strb,

    //cache ins
    input  wire                           icache_unbusy,
    output wire                           icacop_op_en,
    output wire                           dcacop_op_en,
    output wire [ 1:0]                    cacop_op_mode,


    //input ws_ex,
    input      wire                    es_reflush,
    input      wire     [1:0]            commit_st_en,
    input      wire    ms_mem_we,
    output     wire    es_to_ms_sb_valid,
    output     wire    es_ready_go,
    input      wire    ms_valid,

    // to tlb
    output [19:0]                  s1_va_highbits,
    output [ 9:0]                  s1_asid,
    output                         s1_valid,
    input                          s1_ok,
    output                         invtlb_valid,
    output [ 4:0]                  invtlb_op,
    // from csr, used for tlbsrch
    input  [ 9:0]                  csr_asid_asid,
    input  [18:0]                  csr_tlbehi_vppn,
    // from mmu
    input  [ 5:0]                  es_exc_ecode,
    output [31:0]                  va,
    output [ 1:0]                  mmu_en,
    input  [31:0]                  pa,
    input  [ 1:0]                  plv,
    input                          dmw_hit,
    input                          es_uncache_en,
    input                          llbit,
    input  [27:0]                  lladdr,
    input  [3:0]                   rob_head_id,
    input                          untlb_en,
    output wire                    es_mem_we,
    output wire [4:0]              rand_idx,
    input  wire                    s1_found,
    input  wire [ 4:0]             s1_index
);

reg         es_valid      ;
wire        es_need_mem;
reg  [`DE_TO_DS_BUS-1:0] is_to_es_bus_r;


wire [2: 0]  es_load_op;

wire        gr_we;

assign      es_mem_we_stall = es_mem_we;

wire [31:0] imm;
wire [31:0] es_pc;
wire [1:0]  es_store_op;
// Stable Counter
reg  [63:0] counter;

// csr and exception signal
wire         es_inst_cpucfg;
wire         es_inst_valid_cacop;
wire [4:0]   es_cacop_dest;
wire         es_inst_tlbsrch;
wire         es_inst_tlbrd;
wire         es_inst_tlbwr;
wire         es_inst_tlbfill;
wire         es_inst_invtlb;
wire [ 4:0]  es_invtlb_op;
wire [128:0] es_exception;
wire [ 1: 0] time_op;
wire [31: 0] es_final_result;
wire         ld_ale;
wire         st_ale;
wire         csr_re;
wire         csr_we;
wire [ 31:0] csr_wmask;
wire [ 31:0] csr_wvalue;
wire [ 13:0] csr_num;
wire         ds_ex;
wire         es_ertn;
wire         es_adef;
wire [ 31:0] ds_wrong_addr;
wire [  5:0] ds_ecode;
wire [  8:0] ds_esubcode;
wire [  8:0] es_esubcode;
wire         es_ex;
wire [  5:0] es_ecode;
wire [ 31:0] es_wrong_addr;
wire         inst_is_mem_priv;  // 1 bit  (???????????? 254)
wire [29:0]  alu_op;            // 28 bits
wire         need_rj;           // 1 bit
wire         need_rk;           // 1 bit
wire         need_rd;           // 1 bit
wire         need_pc;           // 1 bit
wire         need_imm;          // 1 bit
wire [ 4:0]  ldst;              // 5 bits (??????????????)
wire [ 4:0]  lrs1;              // 5 bits (????????? 1)
wire [ 4:0]  lrs2;              // 5 bits (????????? 2)
wire         rf_we;             // 1 bit  (???????????????)
//wire [31:0]  imm;               // 32 bits(??????)

wire         res_from_mem;      // 1 bit
wire [129:0] ds_exception;      // 130 bits(???? CSR ???????)
//wire [ 1:0]  time_op;           // 2 bits (rdcnt ??????)
wire [ 1:0]  iq_type;           // 2 bits (????????????????)
wire ds0_is_store;
wire                  rename_is_complex_0;
wire es_inst_pcaddu12i;
wire es_inst_csrxchg;
wire pred_taken;
wire [31:0] pred_target;
wire [ 5:0] es_tlb_ecode;
wire [19:0] es_dcache_tag;
wire        dcache_uncache_en;

wire es_inst_sc_w;
wire es_inst_ll_w;
wire es_inst_dbar;
wire es_inst_ibar;
wire [1:0]es_br_type;
wire es_inst_preld;

assign preld_en = es_inst_preld && !es_ex && !es_reflush;

assign                {es_inst_preld,
                       es_inst_dbar,
                       es_inst_ibar,
                       es_inst_sc_w,
                       es_inst_ll_w,
                       es_br_type,
                       es_inst_cpucfg,
                       es_inst_valid_cacop,
                       es_cacop_dest,
                       es_inst_tlbsrch,
                       es_inst_tlbrd,
                       es_inst_tlbwr,
                       es_inst_tlbfill,
                       es_inst_invtlb,
                       es_invtlb_op,
                       pred_taken,
                       pred_target,
                       es_inst_csrxchg,
                       es_inst_pcaddu12i, 
                       ds0_is_store,
                       rename_is_complex_0,
                       inst_is_mem_priv,
                       alu_op       ,   // 28
                       need_rj      ,   //1
                       need_rk      ,//1  30
                       need_rd      , //1
                       need_pc      , //1
                       need_imm     ,//1
                       ldst         ,//5        221
                       lrs1         ,//5        216
                       lrs2         ,//5  48     211
                       es_load_op      ,   // 3     206
                       es_store_op     ,  //2
                       rf_we        ,   // 1 
                       es_mem_we       ,   // 1  55    200
                       imm          ,   // 32  87    199
                       es_pc           ,    // 32  119  167
                       res_from_mem ,//1  120
                       ds_exception ,//130  250  134
                       time_op      ,//2
                       iq_type//2   254  
                    }  = is_to_es_bus_r &{`DE_TO_DS_BUS{es_issue_valid}};

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] alu_res    ;

reg      [ 3:0]        es_rob_id;
reg      [31:0]        es_operand1     ;//from regfile
reg      [31:0]        es_operand2     ;
reg      [5:0]         es_issue_preg_rd;

wire [31:0] es_pa;
assign es_pa = pa;

wire es_to_ms_inst_sc_w;
assign es_to_ms_inst_sc_w = es_inst_sc_w;

wire [31:0] es_store_wdata;
wire dcache_tlb_excp_cancel;
assign es_to_ms_bus = { s1_index,
                        s1_found,
                        es_store_wdata,//341
                        es_inst_dbar, //309
                        es_inst_ibar,
                        dcache_tlb_excp_cancel,
                        es_pa,  //306
                        es_to_ms_inst_sc_w, //274
                        es_sc_success,
                        es_inst_ll_w,
                        dcache_uncache_en,
                        es_dcache_tag,
                        es_inst_valid_cacop,
                        es_inst_tlbsrch,  //249
                        es_inst_tlbrd,
                        es_inst_tlbwr,
                        es_inst_tlbfill, //
                        es_sb_valid,//1   209
                        es_load_op,//3
                       res_from_mem,  //70:70 1
                       rf_we       ,  //69:69 1
                       es_issue_preg_rd        ,  //6  203
                       es_final_result,  //63:32 32  197
                       es_pc       ,    //31:0  32  165
                       es_rob_id,//4     133
                       es_exception//129
                      };

reg es_issue_valid;
reg es_sb_valid;
wire es_allowin;
//wire sb_effectively_full = sb_full || (sb_almost_full && es_issue_valid && es_mem_we_real);
wire sb_effectively_full =
    sb_full ||
    (sb_almost_full &&
     es_issue_valid &&
     es_mem_we);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign issue_es_allowin = es_allowin && !sb_sram_req && !sb_effectively_full;
assign es_to_ms_valid =  es_valid && es_ready_go && (~es_reflush);
always @(posedge clk) begin
    if (reset ) begin
        es_valid <= 1'b0;
        es_issue_valid <= 1'b0;
        es_sb_valid <= 1'b0;
        is_to_es_bus_r <= {`DE_TO_DS_BUS{1'b0}};
    end
    else if (es_reflush) begin
        es_valid <= es_sb_valid;
        es_issue_valid <= 1'b0;
        is_to_es_bus_r <= {`DE_TO_DS_BUS{1'b0}};
    end
    else if (issue_es_allowin) begin
        es_issue_valid <= issue_valid;
        es_sb_valid <= 1'b0;
        es_valid <= issue_valid;

    end
    else if (es_allowin) begin
        es_sb_valid <= sb_sram_req;
        es_issue_valid <= 1'b0;
        es_valid <= sb_sram_req;
    end
    if (issue_valid && issue_es_allowin) begin
        is_to_es_bus_r <= issue_payload;
        es_rob_id <= issue_rob_id;
        es_operand1 <= operand1;
        es_operand2 <= operand2;
        es_issue_preg_rd <= issue_preg_rd;
    end
end

assign es_to_ms_sb_valid = es_sb_valid;

assign alu_src1 = es_operand1;
assign alu_src2 = need_rd & !alu_op[0]  ? es_operand2:
                  need_imm ? imm : es_operand2;
                  
assign alu_result =  alu_src1 + alu_src2;

wire [31:0] st_b_result;
wire [31:0] st_h_result;
wire [ 3:0] st_b;
wire [ 3:0] st_h;

assign st_b_result     = {4{es_operand2[ 7:0]}};
assign st_h_result     = {2{es_operand2[15:0]}};
assign st_b            = alu_result[1:0] == 2'b00 ? 4'b0001 :
                         alu_result[1:0] == 2'b01 ? 4'b0010 :
                         alu_result[1:0] == 2'b10 ? 4'b0100 : 4'b1000;
assign st_h            = alu_result[1:0] == 2'b00 ? 4'b0011 : 4'b1100;

wire es_ale;
//wire csr_re;
wire [ 31:0] es_csr_wvalue;
wire [ 31:0] es_csr_wmask;
wire [13:0] es_csr_num;
assign es_csr_wvalue = es_operand2;
assign es_csr_wmask = es_inst_csrxchg ? {32{es_inst_csrxchg}} & es_operand1 : csr_wmask;
assign {csr_re, csr_we, csr_wmask, csr_wvalue, csr_num, ds_ex, es_ertn, 
        es_adef, ds_wrong_addr, ds_ecode, ds_esubcode} = ds_exception;
assign ld_ale  =  (es_load_op == 3'b011) & alu_result[0]   //load_h
                | (es_load_op == 3'b100) & alu_result[0]                  
                | (es_load_op == 3'b101) & (alu_result[1] | alu_result[0]); //load_w       
assign st_ale  =  (es_store_op == 2'b10) & alu_result[0]           //store_h
                | (es_store_op == 2'b11) & (alu_result[1] | alu_result[0]);  //store_w/sc_w
assign es_ale  = ld_ale | st_ale;
assign es_adem = es_need_mem & alu_result[31] & (plv == 2'd3) & ~(dmw_hit) & ~(sb_sram_req & es_sb_valid);
assign es_wrong_addr = (es_adef | (ds_ecode == `ECODE_TLBR) | (ds_ecode == `ECODE_PIF) | (ds_ecode == `ECODE_PPI)) ? ds_wrong_addr : alu_result;
assign es_ecode      = ds_ex    ? ds_ecode
                   //  : es_adem  ? `ECODE_ADE
                     : es_ale   ? `ECODE_ALE
                     : es_tlb_ecode[0] ? `ECODE_TLBR
                     : es_tlb_ecode[1] ? `ECODE_PPI
                     : es_tlb_ecode[5] ? `ECODE_PIL
                     : es_tlb_ecode[4] ? `ECODE_PIS
                     : es_tlb_ecode[2] ? `ECODE_PME
                     : 6'h0;
assign es_esubcode   =  ds_esubcode;
assign es_ex         = (ds_ex | es_ale | es_adem | (|es_tlb_ecode)) & es_valid;
assign es_csr_num    = es_inst_cpucfg ? (es_operand1[13:0]+14'h00b0) : csr_num;
assign es_exception  = {csr_re, csr_we, es_csr_wmask, es_csr_wvalue, es_csr_num, es_ex, es_ertn, 
                        es_wrong_addr, es_ecode, es_esubcode};
always @(posedge clk) begin
    if (reset)
        counter <= 64'b0;
    else 
        counter <= counter + 1'b1;
end
assign rand_idx = counter[4:0];

assign es_final_result  = {32{time_op[0]}}                & counter[31: 0]
                        | {32{time_op[1]}}                & counter[63:32]
                        | {32{~time_op[0] & ~time_op[1]}} & alu_result;


wire [ 3:0] es_store_wstrb;
wire [ 1:0] es_store_size;
wire sb_full;
wire          sb_sram_req;
wire [31:0]   sb_sram_addr;
wire [31:0]   sb_sram_wdata;
wire [ 3:0]    sb_sram_wstrb;
wire [ 1:0]    sb_sram_size;
wire           sb_sram_is_sc;
wire [31:0]    data_sram_addr;
wire           es_sc_success;
wire           es_mem_we_real;
assign es_sc_success  = es_inst_sc_w && llbit && (lladdr == pa[31:4]) && !es_uncache_en && !st_ale;
assign es_mem_we_real = es_inst_sc_w ? es_sc_success : es_mem_we;
assign es_store_wdata = es_store_op == 2'b01 ? st_b_result :
                         es_store_op == 2'b10 ? st_h_result : es_operand2;
assign es_store_wstrb =  es_mem_we_real && (es_issue_valid  & ~es_reflush & ~st_ale) ?
                        (es_inst_sc_w ? 4'hf : (es_store_op == 2'b01 ? st_b : (es_store_op == 2'b10 ? st_h : 4'hf))) : 4'h0;
                        
assign es_store_size =  (es_store_op == 2'b01 | es_load_op == 3'b001 | es_load_op == 3'b010) ? 2'b00   // load b, bu or store b
                       : (es_store_op == 2'b10 | es_load_op == 3'b011 | es_load_op == 3'b100) ? 2'b01   // load h, hu or store h
                       : 2'b10;       
                       
                       
wire sb_almost_full;
store_buffer u_store_buffer (
        .clk          (clk),
        .reset        (reset),
        .flush        (es_reflush),
        
        // ???
        .enq_valid    (es_mem_we_real & es_issue_valid & es_ready_go & ms_allowin),
        .enq_addr     (pa),
        .enq_wdata    (es_store_wdata),
        .enq_wstrb    (es_store_wstrb),
        .enq_size     (es_store_size),
        .enq_uncache_en (es_uncache_en),
        .sb_almost_full (sb_almost_full),
        .sb_full      (sb_full),
        .ms_mem_we    (ms_mem_we),
        .sb_empty     (sb_empty),

        // ???????
        .commit_st_en (commit_st_en), 

        // ??????????? SRAM
        .sram_req     (sb_sram_req),
        .sram_addr    (sb_sram_addr),
        .sram_wdata   (sb_sram_wdata),
        .sram_wstrb   (sb_sram_wstrb),
        .sram_size    (sb_sram_size),
        .sram_uncache_en (sb_uncache_en),
        .sram_addr_ok (data_sram_addr_ok),
        .data_sram_en (data_sram_en),
        .es_sb_valid  (es_sb_valid),
        .sram_data_ok (data_sram_data_ok),
        .load_req  (es_valid && (es_load_op != 3'b000) && (s1_ok || s1_ok_r|| untlb_en)),
        .load_addr (pa),
        .fwd_data  (sb_fwd_data),
        .fwd_strb  (sb_fwd_strb),
        .ms_allowin (ms_allowin),
        .ms_valid   (ms_valid)
    );                        


wire cacop_mode2 = es_inst_valid_cacop && (es_cacop_dest[4:3] == 2'b10) && es_valid;
wire icacop_inst_stall = icacop_op_en && !icache_unbusy && icacop_inst;
wire need_s1_done = (es_inst_tlbsrch || cacop_mode2) && es_valid;

assign es_need_mem = es_valid && ( res_from_mem || (sb_sram_req && es_sb_valid));

assign es_ready_go    = 
                        es_reflush & !(sb_sram_req & es_sb_valid || es_sb_valid & data_sram_addr_ok)?  1:
                        preld_en ? data_sram_addr_ok:
                        uncache_rd_block ? 1'b0 :
                        es_mem_we && es_valid ? (s1_ok || s1_ok_r || untlb_en) || es_ex:
                        es_need_mem ? (data_sram_en && data_sram_addr_ok) || es_ex:
                        need_s1_done ? !icacop_inst_stall && (s1_ok || s1_ok_r || (cacop_mode2 && untlb_en)) || es_ex:
                        (!need_s1_done && !icacop_inst_stall && es_valid);
assign data_sram_en = (sb_sram_req & es_sb_valid & ms_allowin & ~es_ex) | 
                      (res_from_mem && ms_allowin && (s1_ok || s1_ok_r || untlb_en) & ~es_ex & ~es_reflush& ~uncache_rd_block);
assign data_sram_we    = sb_sram_req & es_sb_valid ? sb_sram_wstrb : 4'd0;
assign data_sram_addr  = sb_sram_req & es_sb_valid ? sb_sram_addr  : pa;
assign data_sram_wdata = sb_sram_req & es_sb_valid ? sb_sram_wdata : 32'd0;
assign data_sram_size  = sb_sram_req & es_sb_valid? sb_sram_size  : ( es_load_op == 3'b001 | es_load_op == 3'b010) ? 2'b00   // load b, bu or store b
                       : ( es_load_op == 3'b011 | es_load_op == 3'b100) ? 2'b01   // load h, hu or store h
                       : 2'b10;
assign data_sram_wr    = sb_sram_req & es_sb_valid? 1'b1 : 1'b0;
assign es_dcache_tag   = data_sram_addr[31:12];
assign dcache_index    = data_sram_addr[11:5];   // 7-bit index for 128 sets (32B line)
assign dcache_offset   = data_sram_addr[4:0];    // 5-bit offset for 32B line

assign dcache_uncache_en = sb_sram_req & es_sb_valid ? sb_uncache_en : es_uncache_en;

assign dcache_tlb_excp_cancel = es_ex;

//cache ins
wire [4:0] cacop_op     = es_cacop_dest;
assign icacop_inst      = es_inst_valid_cacop && (cacop_op[2:0] == 3'b0);
assign icacop_op_en     = cacop_mode2 ? (s1_ok || s1_ok_r || untlb_en) : icacop_inst;
assign dcacop_inst      = es_inst_valid_cacop && (cacop_op[2:0] == 3'b1);
assign dcacop_op_en     = cacop_mode2 ? (s1_ok || s1_ok_r || untlb_en) : dcacop_inst;
assign cacop_op_mode    = cacop_op[4:3];

reg s1_ok_r;
always @(posedge clk) begin
    if (reset) begin
        s1_ok_r <= 1'b0;
    end
    else if(es_ready_go && ms_allowin) begin
        s1_ok_r <= 1'b0;
    end
    else if (!s1_ok_r) begin
        s1_ok_r <= s1_ok;
    end
end

assign s1_valid = ((cacop_mode2 || res_from_mem || es_mem_we) && ~untlb_en || es_inst_tlbsrch) && ~(s1_ok_r || s1_ok) && ~(ds_ex || es_ale || es_adem);
assign s1_va_highbits = (res_from_mem || es_mem_we || cacop_mode2)  ? alu_result[31:12] : es_inst_invtlb ? es_operand2[31:12] : {csr_tlbehi_vppn, 1'b0};
assign s1_asid        = (res_from_mem || es_mem_we || cacop_mode2 || ~es_inst_invtlb) ? csr_asid_asid : es_operand1[9:0]; 
assign invtlb_valid   = es_inst_invtlb;
assign invtlb_op      = es_invtlb_op;

assign ecode_pil      = es_exc_ecode[5] & (res_from_mem | cacop_mode2);
assign ecode_pis      = es_exc_ecode[4] & es_mem_we;
assign ecode_pme      = es_exc_ecode[2] & es_mem_we;
assign mmu_en         = {2{(res_from_mem || es_mem_we || cacop_mode2)}} & {1'b0, 1'b1};
assign va             = alu_result;

assign es_tlb_ecode = {ecode_pil , ecode_pis, es_exc_ecode[3] , ecode_pme , es_exc_ecode[1] , es_exc_ecode[0]} 
                    & {6{(res_from_mem || es_mem_we_real || cacop_mode2)}} & {6{(s1_ok || s1_ok_r)}};
                    
wire es_is_oldest = (es_rob_id == rob_head_id);
wire uncache_rd_block = res_from_mem && es_uncache_en && !es_is_oldest;   

endmodule
