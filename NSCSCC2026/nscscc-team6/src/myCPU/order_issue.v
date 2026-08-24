//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/18 16:25:00
// Design Name: 
// Module Name: order_issue
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "mycpu.h"

// ����? 16 �� 1��1�� �ϸ�˳�������?? (FIFO) - ר�� MEM/PRIV ʹ��
module order_queue (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    // 1. ��ӽӿ�?? (Enqueue - 1 ��)
    input  wire        enq_valid,
    input  wire [ 5:0] enq_preg_rs1,
    input  wire [ 5:0] enq_preg_rs2,
    input  wire [ 5:0] enq_preg_rd,
    input  wire [ 3:0] enq_rob_id,
    input  wire [`DE_TO_DS_BUS-1:0] enq_payload,
    input  wire        enq_rs1_ready,
    input  wire        enq_rs2_ready,
    
    output wire        iq_allowin,  // ���� Rename �����һ���û�п�λ

    // 2. CDB ���ѹ㲥����
    input  wire        cdb_we_0,
    input  wire [ 5:0] cdb_preg_0,
    input  wire        cdb_we_1,
    input  wire [ 5:0] cdb_preg_1,
    input  wire        cdb_we_2,
    input  wire [ 5:0] cdb_preg_2,    
    /*
    input      wire                     gr_we_0      ,
    input      wire      [5:0]          preg_rd_0    ,
    input      wire                     gr_we_1      ,
    input      wire      [5:0]          preg_rd_1    ,    */
    // 3. ����/����ӿ�?? (Issue - 1 ��)
    input  wire        ex_allowin,  // ���ִ�е�Ԫ�Ƿ���������??
    output wire        issue_valid, // ������һ��ָ��
    output wire [ 5:0] issue_preg_rs1,
    output wire [ 5:0] issue_preg_rs2,
    output wire [ 5:0] issue_preg_rd,
    output wire [ 3:0] issue_rob_id,
    output wire [`DE_TO_DS_BUS-1:0] issue_payload,
    input  wire        sb_empty,
    input  wire        es_mem_we_stall
);

    parameter DEPTH = 16;
    localparam ADDR_WD = 4;

    // �ڲ����ݽṹ (FIFO)
    reg [5:0]                 iq_rs1     [DEPTH-1:0];
    reg                       iq_rs1_rdy [DEPTH-1:0];
    reg [5:0]                 iq_rs2     [DEPTH-1:0];
    reg                       iq_rs2_rdy [DEPTH-1:0];
    reg [5:0]                 iq_rd      [DEPTH-1:0];
    reg [3:0]                 iq_rob_id  [DEPTH-1:0];
    reg [`DE_TO_DS_BUS-1:0] iq_payload [DEPTH-1:0];

    // FIFO ��дָ�� (��1λ�����жϿ���)
    reg [ADDR_WD:0] head; // ָ����? (׼�������ָ��??)
    reg [ADDR_WD:0] tail; // ָ����? (׼����ӵĿ��?)

    wire is_empty = (head == tail);
    wire is_full  = (head[ADDR_WD-1:0] == tail[ADDR_WD-1:0]) && (head[ADDR_WD] != tail[ADDR_WD]);

    wire [ADDR_WD-1:0] head_idx = head[ADDR_WD-1:0];
    wire [ADDR_WD-1:0] tail_idx = tail[ADDR_WD-1:0];

    // =========================================================
    // A. ����/����߼�?? 
    // =========================================================
    assign iq_allowin = !is_full; 
    wire enq_fire = enq_valid && !is_full;

    // =========================================================
    // B. ����/�����߼� (�ϸ�˳��ֻ�� Head ָ�룡)
    // =========================================================
    // ��ͷָ���Ƿ�׼�����ˣ�
    wire head_is_ready = !is_empty && iq_rs1_rdy[head_idx] && iq_rs2_rdy[head_idx] &&
                         (sb_empty && iq_payload[head_idx][309] && !es_mem_we_stall || !iq_payload[head_idx][309]);
    
    // ������������ͷ׼�����ˣ��Һ�˳Ե���??
  //  wire issue_fire = head_is_ready && ex_allowin;

  //  assign issue_valid    = issue_fire;
  assign issue_valid = head_is_ready;

wire issue_fire =
    issue_valid && ex_allowin;
    assign issue_preg_rs1 = iq_rs1[head_idx];
    assign issue_preg_rs2 = iq_rs2[head_idx];
    assign issue_preg_rd  = iq_rd[head_idx];
    assign issue_rob_id   = iq_rob_id[head_idx];
    assign issue_payload  = iq_payload[head_idx];

    // =========================================================
    // C. ״̬���� (ͬ��ʱ���߼�)
    // =========================================================
    integer i;
    always @(posedge clk) begin
        if (reset || flush) begin
            head <= 0;
            tail <= 0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                iq_rs1_rdy[i] <= 1'b0;
                iq_rs2_rdy[i] <= 1'b0;
            end
        end
        else begin

            // 2. ���� (Wakeup - ȫ�ֹ㲥��������Ч�ı������)
            for (i = 0; i < DEPTH; i = i + 1) begin
                // ���Ŀǰ���? ready�������㲥
                if (!iq_rs1_rdy[i]) begin
                    if (//(gr_we_0 && (preg_rd_0 == iq_rs1[i]))  ||
                       // (gr_we_1 && (preg_rd_1 == iq_rs1[i]))  ||
                        (cdb_we_0 && (cdb_preg_0 == iq_rs1[i])) || 
                        (cdb_we_1 && (cdb_preg_1 == iq_rs1[i])) ||
                        (cdb_we_2 && (cdb_preg_2 == iq_rs1[i]))) begin
                        iq_rs1_rdy[i] <= 1'b1;
                    end
                end
                if (!iq_rs2_rdy[i]) begin
                     if (//(gr_we_0 && (preg_rd_0 == iq_rs2[i]))  ||
                       // (gr_we_1 && (preg_rd_1 == iq_rs2[i]))  ||
                        (cdb_we_0 && (cdb_preg_0 == iq_rs2[i])) || 
                        (cdb_we_1 && (cdb_preg_1 == iq_rs2[i])) ||
                        (cdb_we_2 && (cdb_preg_2 == iq_rs2[i]))) begin
                        iq_rs2_rdy[i] <= 1'b1;
                    end
                end
            end

            // 1. ���?? (д Tail)
            if (enq_fire) begin
                iq_rs1[tail_idx]      <= enq_preg_rs1;
                iq_rs2[tail_idx]      <= enq_preg_rs2;
                iq_rd[tail_idx]       <= enq_preg_rd;
                iq_rob_id[tail_idx]   <= enq_rob_id;
                iq_payload[tail_idx]  <= enq_payload;
                
                // ������·�����ʱ���ø��Ϲ㲥��ֱ��?? Ready
                iq_rs1_rdy[tail_idx] <= enq_rs1_ready | 
                                        (cdb_we_0 && (cdb_preg_0 == enq_preg_rs1)) | 
                                        (cdb_we_1 && (cdb_preg_1 == enq_preg_rs1)) |
                                        (cdb_we_2 && (cdb_preg_2 == enq_preg_rs1)); // �޸�������Ĵ���??
                                         
                iq_rs2_rdy[tail_idx] <= enq_rs2_ready | 
                                        (cdb_we_0 && (cdb_preg_0 == enq_preg_rs2)) | 
                                        (cdb_we_1 && (cdb_preg_1 == enq_preg_rs2)) |
                                        (cdb_we_2 && (cdb_preg_2 == enq_preg_rs2));
            end

            

            // --------------------------------------------------
            // 3. ָ�����?? (��λ)
            // --------------------------------------------------
            if (enq_fire)   tail <= tail + 1'b1;
            if (issue_fire) head <= head + 1'b1;
        end
    end

endmodule