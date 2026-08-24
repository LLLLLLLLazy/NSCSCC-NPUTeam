`include "mycpu.h"

module commit_stage (
    input  wire        clk,
    input  wire        reset,
    // 1. ��̽ ROB ��ͷ (Head) ��״̬ (���� ROB)
    // --- ָ�� 0 (����) ---
    input  wire        rob_head_done_0,    
    input  wire [31:0] rob_head_pc_0,         // NEW
    input  wire        rob_head_br_miss_0,    
    input  wire [31:0] rob_head_br_target_0,  // NEW
    input  wire        rob_head_ex_0,       
    input  wire [ 4:0] rob_head_areg_0,     
    input  wire [ 5:0] rob_head_new_preg_0, 
    input  wire [ 5:0] rob_head_old_preg_0, 
    input  wire        rob_head_is_store_0, 
    input  wire        rob_head_is_complex_0, 
    input  wire        rob_head_has_dest_0,   
    input  wire [128:0]rob_head_exception_0,  // �쳣
    input wire        rob_head_is_br_0,
    input wire [1:0]  rob_head_br_type_0,
    input wire        rob_head_br_taken_0,
    input wire        rob_head_inst_tlbsrch_0,
    input wire        rob_head_inst_tlbrd_0,
    input wire        rob_head_inst_tlbwr_0,
    input wire        rob_head_inst_tlbfill_0,
    input wire        rob_head_tlb_hit_0,
    input wire [ 4:0] rob_head_tlb_index_0,
    input wire        rob_head_inst_valid_cacop_0,
    input wire        rob_head_inst_sc_w_0,
    input wire        rob_head_inst_ll_w_0,
    input wire [31:0] rob_head_pa_0,
    input wire        rob_head_uncache_en_0,
    input wire        rob_head_inst_dbar_0,
    input wire        rob_head_inst_ibar_0,
    // --- ָ�� 1 ---
    input  wire        rob_head_done_1,
    input  wire [31:0] rob_head_pc_1,
    input  wire        rob_head_br_miss_1,
    input  wire [31:0] rob_head_br_target_1,
    input  wire        rob_head_ex_1,
    input  wire [ 4:0] rob_head_areg_1,
    input  wire [ 5:0] rob_head_new_preg_1,
    input  wire [ 5:0] rob_head_old_preg_1,
    input  wire        rob_head_is_store_1,
    input  wire        rob_head_is_complex_1,
    input  wire        rob_head_has_dest_1,
    input  wire [128:0]rob_head_exception_1,
    input wire        rob_head_is_br_1,
    input wire [1:0]  rob_head_br_type_1,
    input wire        rob_head_br_taken_1,
    input wire        rob_head_inst_tlbsrch_1,
    input wire        rob_head_inst_tlbrd_1,
    input wire        rob_head_inst_tlbwr_1,
    input wire        rob_head_inst_tlbfill_1,
    input wire        rob_head_tlb_hit_1,
    input wire [ 4:0] rob_head_tlb_index_1,
    input wire        rob_head_inst_valid_cacop_1,
    input wire        rob_head_inst_sc_w_1,
    input wire        rob_head_inst_ll_w_1,
    input wire [31:0] rob_head_pa_1,
    input wire        rob_head_uncache_en_1,
    input wire        rob_head_inst_dbar_1,
    input wire        rob_head_inst_ibar_1,
    // 2. ���� ROB �Ŀ��� (Ų��ͷָ��)
    output reg  [ 1:0] commit_pop_cnt,      // ���� ROB �����ڳ��Ӽ���


    // 3. ���� aRAT �� Freelist �ĸ����ź�
    output reg         arat_we_0,
    output reg  [ 4:0] arat_waddr_0,
    output reg  [ 5:0] arat_wdata_0,
    output reg         freelist_we_0,
    output reg  [ 5:0] freelist_wdata_0,

    output reg         arat_we_1,
    output reg  [ 4:0] arat_waddr_1,
    output reg  [ 5:0] arat_wdata_1,
    output reg         freelist_we_1,
    output reg  [ 5:0] freelist_wdata_1,

    // 4. ���� Store Buffer
    output reg  [ 1:0] commit_st_cnt,       // �������м��� Store ����


    // 5. �쳣����Ȩ���ˢ�����ӿ�?? (���� CSR ģ���?? Flush Controller)
    output reg         flush_req,           // �����ˢ����??
    output reg  [31:0] flush_target,        // ���� Fetch ��ȥ��������ȡָ

    output wire [`WS_TO_CSR_BUS -1:0] com_to_csr_bus,
    output wire ws_ex,
    output wire ertn_flush,
    output wire [ 5:0] debug_raddr_0,
    output wire [ 5:0] debug_raddr_1,
    input  wire [31:0] debug_rdata_0,
    input  wire [31:0] debug_rdata_1,
    
    // ��ģ��˿���������������?? bp_unit ���ź�
    output reg         bpu_update_en,
    output reg  [31:0] bpu_pc_update,
    output reg  [31:0] bpu_target_update,
    output reg         bpu_actual_taken,
    output reg  [1:0]  bpu_branch_type_update,

    input  wire [ 4:0]                   csr_tlbidx_index,
    // tlbrd
    output wire                         tlbrd_we, // to csr
    output wire[ 4:0]                   r_index,  // to tlb
    // tlbwr and tlbfill
    output wire[ 4:0]                   w_index,  // to tlb
    output   wire                       we,       // to tlb
    // tlbsrch, to csr
    output     wire                     tlbsrch_we,         // to csr
    output     wire                     tlbsrch_hit,        // to csr
    output wire[ 4:0]                   tlbsrch_hit_index,  // to csr
    //llbit
    output wire       ws_llbit_set,
    output wire       ws_llbit,
    output wire       ws_lladdr_set,
    output wire[27:0] ws_lladdr,

    // ���� Trace �ӿ����??
    output wire idle_flush,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    input wire commit_idle_0,
    input wire commit_idle_1,
    input wire [4:0] rand_idx
);


assign ws_llbit_set  = (rob_head_inst_ll_w_0 | rob_head_inst_sc_w_0) & rob_head_done_0 & !ws_ex;
assign ws_llbit      = ((rob_head_inst_ll_w_0 & !rob_head_uncache_en_0) & 1'b1) |
                       (rob_head_inst_sc_w_0 & 1'b0);
assign ws_lladdr_set = (rob_head_inst_ll_w_0 & !rob_head_uncache_en_0) & rob_head_done_0 & !ws_ex;
assign ws_lladdr     = rob_head_pa_0[31:4];


wire        csr_re;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [13:0] csr_num;
wire [ 5:0] wb_ecode;
wire [ 8:0] wb_esubcode;
wire         ipi_int_in = 1'b0;
wire [  7:0] hw_int_in  = 8'b0;
wire [ 31:0] wb_vaddr;
wire [ 31:0] core_id    = 32'b0;
assign {csr_re, csr_we , csr_wmask, csr_wvalue, csr_num, ws_ex, ertn_flush, 
        wb_vaddr, wb_ecode, wb_esubcode} = rob_head_exception_0 & {129{rob_head_done_0}};
assign com_to_csr_bus = {csr_re, csr_we&~ws_ex, csr_wmask, csr_wvalue, csr_num, rob_head_pc_0, wb_ecode, wb_esubcode, ipi_int_in, hw_int_in, core_id, wb_vaddr} & {200{rob_head_done_0}};


wire commit_is_idle = commit_idle_0 && rob_head_done_0 && !ws_ex && !ertn_flush;
assign idle_flush = commit_is_idle;


assign tlbrd_we = rob_head_inst_tlbrd_0 & rob_head_done_0 & ~ws_ex;
assign r_index  = csr_tlbidx_index;
// tlbwr and tlbfill
assign w_index  = rob_head_inst_tlbwr_0 & rob_head_done_0 ? csr_tlbidx_index : rand_idx;
assign we       = (rob_head_inst_tlbwr_0 & rob_head_done_0 | rob_head_inst_tlbfill_0 & rob_head_done_0) & ~ws_ex;
// tlbsrch
assign tlbsrch_we        = (rob_head_inst_tlbsrch_0 & rob_head_done_0) & ~ws_ex;
assign tlbsrch_hit       = rob_head_tlb_hit_0 & rob_head_done_0;
assign tlbsrch_hit_index = rob_head_tlb_index_0 & {5{rob_head_done_0}};

wire tlb_inst_flush = (rob_head_inst_tlbsrch_0  | rob_head_inst_tlbrd_0 | rob_head_inst_tlbwr_0 | rob_head_inst_tlbfill_0) & rob_head_done_0;
wire bar_inst_flush = (rob_head_inst_dbar_0 | rob_head_inst_ibar_0) & rob_head_done_0;

always @(*) begin
        // Ĭ��״̬��ʼ��
        commit_pop_cnt   = 2'd0;
        flush_req        = 1'b0;
        flush_target     = 32'd0;
        commit_st_cnt    = 2'd0;
        
        arat_we_0 = 1'b0;  arat_waddr_0 = 5'd0;  arat_wdata_0 = 6'd0;
        freelist_we_0 = 1'b0; freelist_wdata_0 = 6'd0;
        
        arat_we_1 = 1'b0;  arat_waddr_1 = 5'd0;  arat_wdata_1 = 6'd0;
        freelist_we_1 = 1'b0; freelist_wdata_1 = 6'd0;
        
        bpu_update_en          = 1'b0;
        bpu_pc_update          = 32'd0;
        bpu_target_update      = 32'd0;
        bpu_actual_taken       = 1'b0;
        bpu_branch_type_update = 2'b00;

        // ==========================================
        // ָ�� 0 ���ύ�߼�
        // ==========================================
        if (rob_head_done_0) begin
            if (ws_ex) begin
                flush_req      = 1'b1;
                commit_pop_cnt = 2'd0; // �����쳣������ָ����ۣ�ֱ�����
            end 
            else begin
                // ֻҪ���� exception������ָ���һ���ܳɹ�����
                commit_pop_cnt = 2'd1;

                // �ڶ������������۵�ָ��Ƿ�Ҫ������������
                if (ertn_flush) begin
                    flush_req = 1'b1;
                end 
                else if (commit_is_idle) begin
                    flush_req      = 1'b1;
                    flush_target   = rob_head_pc_0 + 32'd4; 
                end
                // ֻҪ����Ԥ�ⲻ�ԣ������ǲ�����ķ�֧���� Flush
                else if (rob_head_br_miss_0) begin
                    flush_req    = 1'b1;
                    // ����������֧��Ŀ���Ǽ������ target����������е���ָͨ�Ŀ���� PC+4
                    flush_target = rob_head_is_br_0 ? rob_head_br_target_0 : (rob_head_pc_0 + 32'd4);
                end
                // д CSR �� TLB ������ָ��Ҳ��Ҫ Flush ֮���ָ��
                else if ((csr_we | tlb_inst_flush | rob_head_inst_valid_cacop_0 | rob_head_inst_ll_w_0 | rob_head_inst_sc_w_0 | bar_inst_flush)) begin
                    flush_req      = 1'b1;
                    flush_target   = rob_head_pc_0 + 32'd4;
                end

                // ��������������д������ִ�н�������ۺ���ǲ��Ǳ� Flush��
                if (rob_head_is_store_0) commit_st_cnt = 2'd1;

                if (rob_head_has_dest_0 && (rob_head_areg_0 != 5'd0)) begin
                    arat_we_0        = 1'b1;
                    arat_waddr_0     = rob_head_areg_0;
                    arat_wdata_0     = rob_head_new_preg_0;
                    freelist_we_0    = 1'b1;
                    freelist_wdata_0 = rob_head_old_preg_0;
                end

                // ������������ķ�ָ֧����� BPU
                if (rob_head_is_br_0) begin
                    bpu_update_en          = 1'b1;
                    bpu_pc_update          = rob_head_pc_0;
                    bpu_target_update      = rob_head_br_target_0;
                    bpu_actual_taken       = rob_head_br_taken_0;
                    bpu_branch_type_update = rob_head_br_type_0;
                end

                // ----------------------------------------------------
                // ���Ĳ���˫�����߼� (ǰ����ָ�� 0 û����������� Flush)
                // ----------------------------------------------------
                if (!flush_req 
                    && !rob_head_is_complex_0 
                    && rob_head_done_1 
                    && !rob_head_ex_1 
                    && !rob_head_is_br_1 
                    && !rob_head_exception_1[128] 
                    && !rob_head_is_complex_1
                    && !rob_head_inst_ll_w_1
                    && !rob_head_inst_sc_w_1
                    && !commit_idle_0
                    && !commit_idle_1) 
                begin
                    commit_pop_cnt = 2'd2;
                    
                    if (rob_head_is_store_1) commit_st_cnt = commit_st_cnt + 1'b1;
                    
                    if (rob_head_has_dest_1 && (rob_head_areg_1 != 5'd0)) begin
                        // ���ָ�� 0 ��ָ�� 1 ���� WAW ��ͻ������
                        if (arat_we_0 && (arat_waddr_0 == rob_head_areg_1)) arat_we_0 = 1'b0;

                        arat_we_1        = 1'b1;
                        arat_waddr_1     = rob_head_areg_1;
                        arat_wdata_1     = rob_head_new_preg_1;
                        freelist_we_1    = 1'b1;
                        freelist_wdata_1 = rob_head_old_preg_1;
                    end
                end
            end // end of not exception
        end // end of rob_head_done_0
    end
    
    
assign debug_raddr_0 = rob_head_new_preg_0;
assign debug_raddr_1 = rob_head_new_preg_1;

    // FIFO ���� (����: 32(PC) + 4(WE) + 5(WNUM) + 32(WDATA) = 73 bit)
    reg [72:0] trace_fifo [15:0];
    reg [4:0]  trace_head;
    reg [4:0]  trace_tail;

    wire trace_empty = (trace_head == trace_tail);
    wire [4:0] next_tail_1 = trace_tail + 1'b1;
    wire [4:0] next_tail_2 = trace_tail + 2'd2;
wire trace_we_0 = rob_head_has_dest_0 && (rob_head_areg_0 != 5'd0);
wire trace_we_1 = rob_head_has_dest_1 && (rob_head_areg_1 != 5'd0);
    always @(posedge clk) begin
        if (reset) begin
            trace_head <= 0;
            trace_tail <= 0;
        end else begin
            // 1. ����߼�?? (���ݱ����� commit ���������??)
            //  ע�⣺����ȫ�� Flush ʱ�����ǲ������?? trace_fifo����Ϊ�Ѿ��ύ��ָ������ʵ��Ч�ģ�
            if (commit_pop_cnt == 2'd1) begin
                trace_fifo[trace_tail[3:0]] <= {rob_head_pc_0, {4{trace_we_0}}, rob_head_areg_0, debug_rdata_0};
                trace_tail <= next_tail_1;
            end 
            else if (commit_pop_cnt == 2'd2) begin
                trace_fifo[trace_tail[3:0]]  <= {rob_head_pc_0, {4{trace_we_0}}, rob_head_areg_0, debug_rdata_0};
                trace_fifo[next_tail_1[3:0]] <= {rob_head_pc_1, {4{trace_we_1}}, rob_head_areg_1, debug_rdata_1};
                trace_tail <= next_tail_2;
            end

            // 2. �����߼� (ÿ�����ڹ̶��³� 1 �����ⲿ����)
            if (!trace_empty) begin
                trace_head <= trace_head + 1'b1;
            end
        end
    end

    // ����߼����������
    wire [4:0] trace_head_1 = trace_head -1'b1;//ֻ��Ϊ��debug�����ʱ��û��??000000��ȥ������źŵ�����Ϊ�յ�ʱ������trace_out��0Ҳ�ܹ���������̨�����pc��0���������������ɣ�
    wire [72:0] trace_out = trace_empty ? trace_fifo[trace_head_1[3:0]] : trace_fifo[trace_head[3:0]];
    
    // ������п��ˣ�������ɵ���Чλ��ǿ���� we=0
    assign debug_wb_pc       = trace_out[72:41];
    assign debug_wb_rf_we    = trace_empty ? 4'b0000 : trace_out[40:37];
    assign debug_wb_rf_wnum  = trace_out[36:32];
    assign debug_wb_rf_wdata = trace_out[31:0];

endmodule


