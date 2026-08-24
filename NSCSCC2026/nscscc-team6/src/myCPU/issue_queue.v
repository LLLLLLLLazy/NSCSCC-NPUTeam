//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/12 15:47:48
// Design Name: 
// Module Name: issue_queue
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

// ����? 16 �� 1��1�� �������? (������ ALU_IQ �� MEM_IQ)
module issue_queue (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,


    // 1. ��ӽӿ�? (Enqueue - 1 ��)

    input  wire        enq_valid,
    input  wire [ 5:0] enq_preg_rs1,
    input  wire [ 5:0] enq_preg_rs2,
    input  wire [ 5:0] enq_preg_rd,
    input  wire [ 3:0] enq_rob_id,
    input  wire [`DE_TO_DS_BUS-1:0] enq_payload,
    input  wire        enq_rs1_ready,
    input  wire        enq_rs2_ready,
    
    output wire        iq_allowin,  // ���� Rename ������û�п�λ


    // 2. CDB ���ѹ㲥���� (Wakeup - ��Ȼ����1������CPU��2��ִ�е�Ԫ������Ҫ��2���㲥)

    input  wire        cdb_we_0,
    input  wire [ 5:0] cdb_preg_0,
    input  wire        cdb_we_1,
    input  wire [ 5:0] cdb_preg_1,
    input  wire        cdb_we_2,
    input  wire [ 5:0] cdb_preg_2,    
  /*  input      wire                     gr_we_0      ,
    input      wire      [5:0]          preg_rd_0    ,
    input      wire                     gr_we_1      ,
    input      wire      [5:0]          preg_rd_1    ,*/
    // 3. ����/����ӿ�? (Issue - 1 ��)
    input  wire        ex_allowin,  // ���ִ�е�Ԫ�Ƿ���������?
    output wire        issue_valid, // ������һ��ָ��
    output wire [ 5:0] issue_preg_rs1,
    output wire [ 5:0] issue_preg_rs2,
    output wire [ 5:0] issue_preg_rd,
    output wire [ 3:0] issue_rob_id,
    output wire [`DE_TO_DS_BUS-1:0] issue_payload
);

    parameter DEPTH = 16;

    // �ڲ����ݽṹ
    reg               iq_valid    [DEPTH-1:0];
    reg [5:0]         iq_rs1      [DEPTH-1:0];
    reg               iq_rs1_rdy  [DEPTH-1:0];
    reg [5:0]         iq_rs2      [DEPTH-1:0];
    reg               iq_rs2_rdy  [DEPTH-1:0];
    reg [5:0]         iq_rd       [DEPTH-1:0];
    reg [3:0]         iq_rob_id   [DEPTH-1:0];
    reg [`DE_TO_DS_BUS-1:0] iq_payload [DEPTH-1:0];
 //   reg [3:0]           iq_age     [DEPTH-1:0];
    integer i;


    // A. �����߼� (Allocation) - �� 1 ����λ
    reg [3:0] alloc_idx;
    reg       has_free;
    always @(*) begin
        alloc_idx = 4'd0;
        has_free  = 1'b0;
        // �򵥵����ȱ��������ҵ���һ�� valid Ϊ 0 �Ĳ�λ
        for (i = 0; i < DEPTH; i = i + 1) begin
            if (!iq_valid[i] && !has_free) begin
                alloc_idx = i[3:0];
                has_free  = 1'b1;
            end
        end
    end

    assign iq_allowin = has_free; // ֻҪ�� 1 ����λ�������� 1 ��ָ���?

// =========================================================
    // B. ��ѡ�߼� (Select Arbiter) - 16ѡ1 ��״�������Ƚ��� (���� Age)
    // =========================================================
    reg [DEPTH-1:0] slot_ready;
    reg [3:0] issue_idx;
    reg has_ready;
    genvar g;

    always @(*) begin
       issue_idx = 4'd0;
        has_ready  = 1'b0;
        // �򵥵����ȱ��������ҵ���һ�� valid Ϊ 0 �Ĳ�λ
        for (i = 0; i < DEPTH; i = i + 1) begin
            if (iq_valid[i] & iq_rs1_rdy[i] & iq_rs2_rdy[i]&!has_ready) begin
                issue_idx = i[3:0];
                has_ready  = 1'b1;
            end
        end
    end
/*
generate
    for (g = 0; g < DEPTH; g = g + 1) begin : gen_ready
        // ����߼�ǰ�ݣ�����Ĵ����Ѿ�ready�����߱�����ǡ�ñ�CDB���ѣ�����ready
        wire rs1_rdy_comb = iq_rs1_rdy[g] | 
                            (gr_we_0 && (preg_rd_0 == iq_rs1[g])) |
                            (gr_we_1 && (preg_rd_1 == iq_rs1[g])) |
                            (cdb_we_0 && (cdb_preg_0 == iq_rs1[g])) |
                            (cdb_we_1 && (cdb_preg_1 == iq_rs1[g])) |
                            (cdb_we_2 && (cdb_preg_2 == iq_rs1[g]));

        wire rs2_rdy_comb = iq_rs2_rdy[g] | 
                            (gr_we_0 && (preg_rd_0 == iq_rs2[g])) |
                            (gr_we_1 && (preg_rd_1 == iq_rs2[g])) |
                            (cdb_we_0 && (cdb_preg_0 == iq_rs2[g])) |
                            (cdb_we_1 && (cdb_preg_1 == iq_rs2[g])) |
                            (cdb_we_2 && (cdb_preg_2 == iq_rs2[g]));

        // ʹ������߼���ǰ�ݽ��������ѡ
        assign slot_ready[g] = iq_valid[g] & rs1_rdy_comb & rs2_rdy_comb;
    end
endgenerate
*/
/*
    // ÿһ��Ľڵ�״̬��[����, Age, �Ƿ�Ready]
    reg [3:0] l1_idx [7:0]; reg [3:0] l1_age [7:0]; reg l1_rdy [7:0]; // 16 �� 8
    reg [3:0] l2_idx [3:0]; reg [3:0] l2_age [3:0]; reg l2_rdy [3:0]; // 8 �� 4
    reg [3:0] l3_idx [1:0]; reg [3:0] l3_age [1:0]; reg l3_rdy [1:0]; // 4 �� 2
    reg [3:0] issue_idx;    reg [3:0] final_age;    reg has_ready;    // 2 �� 1

    integer j;
    always @(*) begin
        // --- �� 1 �㣺16 �� 8  ---
        for (j = 0; j < 8; j = j + 1) begin
            if (slot_ready[2*j] && slot_ready[2*j+1]) begin
                if (iq_age[2*j] >= iq_age[2*j+1]) begin
                    l1_idx[j] = 2*j;     l1_age[j] = iq_age[2*j];
                end else begin
                    l1_idx[j] = 2*j+1;   l1_age[j] = iq_age[2*j+1];
                end
                l1_rdy[j] = 1'b1;
            end else if (slot_ready[2*j]) begin
                l1_idx[j] = 2*j;     l1_age[j] = iq_age[2*j];     l1_rdy[j] = 1'b1;
            end else if (slot_ready[2*j+1]) begin
                l1_idx[j] = 2*j+1;   l1_age[j] = iq_age[2*j+1];   l1_rdy[j] = 1'b1;
            end else begin
                l1_idx[j] = 4'd0;    l1_age[j] = 4'd0;            l1_rdy[j] = 1'b0;
            end
        end

        // --- �� 2 �㣺8 �� 4 ---
        for (j = 0; j < 4; j = j + 1) begin
            if (l1_rdy[2*j] && l1_rdy[2*j+1]) begin
                if (l1_age[2*j] >= l1_age[2*j+1]) begin
                    l2_idx[j] = l1_idx[2*j];   l2_age[j] = l1_age[2*j];
                end else begin
                    l2_idx[j] = l1_idx[2*j+1]; l2_age[j] = l1_age[2*j+1];
                end
                l2_rdy[j] = 1'b1;
            end else if (l1_rdy[2*j]) begin
                l2_idx[j] = l1_idx[2*j];   l2_age[j] = l1_age[2*j];   l2_rdy[j] = 1'b1;
            end else if (l1_rdy[2*j+1]) begin
                l2_idx[j] = l1_idx[2*j+1]; l2_age[j] = l1_age[2*j+1]; l2_rdy[j] = 1'b1;
            end else begin
                l2_idx[j] = 4'd0;          l2_age[j] = 4'd0;          l2_rdy[j] = 1'b0;
            end
        end

        // --- �� 3 �㣺4 �� 2 ---
        for (j = 0; j < 2; j = j + 1) begin
            if (l2_rdy[2*j] && l2_rdy[2*j+1]) begin
                if (l2_age[2*j] >= l2_age[2*j+1]) begin
                    l3_idx[j] = l2_idx[2*j];   l3_age[j] = l2_age[2*j];
                end else begin
                    l3_idx[j] = l2_idx[2*j+1]; l3_age[j] = l2_age[2*j+1];
                end
                l3_rdy[j] = 1'b1;
            end else if (l2_rdy[2*j]) begin
                l3_idx[j] = l2_idx[2*j];   l3_age[j] = l2_age[2*j];   l3_rdy[j] = 1'b1;
            end else if (l2_rdy[2*j+1]) begin
                l3_idx[j] = l2_idx[2*j+1]; l3_age[j] = l2_age[2*j+1]; l3_rdy[j] = 1'b1;
            end else begin
                l3_idx[j] = 4'd0;          l3_age[j] = 4'd0;          l3_rdy[j] = 1'b0;
            end
        end

        // --- �� 4 �㣺2 �� 1 (�����ܹھ�) ---
        if (l3_rdy[0] && l3_rdy[1]) begin
            if (l3_age[0] >= l3_age[1]) begin
                issue_idx = l3_idx[0]; final_age = l3_age[0];
            end else begin
                issue_idx = l3_idx[1]; final_age = l3_age[1];
            end
            has_ready = 1'b1;
        end else if (l3_rdy[0]) begin
            issue_idx = l3_idx[0]; final_age = l3_age[0]; has_ready = 1'b1;
        end else if (l3_rdy[1]) begin
            issue_idx = l3_idx[1]; final_age = l3_age[1]; has_ready = 1'b1;
        end else begin
            issue_idx = 4'd0;      final_age = 4'd0;      has_ready = 1'b0;
        end
    end
*/
    wire issue_fire = has_ready & ex_allowin; // ������ָ�� 

    // ����߼������ EXE ��
    assign issue_valid    = issue_fire;
    assign issue_preg_rs1 = iq_rs1[issue_idx];
    assign issue_preg_rs2 = iq_rs2[issue_idx];
    assign issue_preg_rd  = iq_rd[issue_idx];
    assign issue_rob_id   = iq_rob_id[issue_idx];
    assign issue_payload  = iq_payload[issue_idx];

    // =========================================================
    // C. ״̬���� (Enqueue, Wakeup, Dequeue)
    // =========================================================
    always @(posedge clk) begin
        if (reset || flush) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                iq_valid[i] <= 1'b0;
           //     iq_age[i]   <= 4'd0;
            end
        end
        else begin
        /*
        for (i = 0; i < DEPTH; i = i + 1) begin
                if (iq_valid[i] && enq_valid && has_free) begin
                   iq_age[i] <= iq_age[i] + 4'd1; 
                end
        end*/
            // --------------------------------------------------
            // 1. ���? (Enqueue)
            // --------------------------------------------------
            if (enq_valid && has_free) begin
                iq_valid[alloc_idx]   <= 1'b1;
                iq_rs1[alloc_idx]     <= enq_preg_rs1;
                iq_rs2[alloc_idx]     <= enq_preg_rs2;
                iq_rd[alloc_idx]      <= enq_preg_rd;
                iq_rob_id[alloc_idx]  <= enq_rob_id;
                iq_payload[alloc_idx] <= enq_payload;
                
                // ������·�����ʱ���ø��Ϲ㲥��ֱ��? Ready
                iq_rs1_rdy[alloc_idx] <= enq_rs1_ready | 
                                         (cdb_we_0 && (cdb_preg_0 == enq_preg_rs1)) | 
                                         (cdb_we_1 && (cdb_preg_1 == enq_preg_rs1)) |
                                         (cdb_we_2 && (cdb_preg_2 == enq_preg_rs1));
                                         
                iq_rs2_rdy[alloc_idx] <= enq_rs2_ready | 
                                         (cdb_we_0 && (cdb_preg_0 == enq_preg_rs2)) | 
                                         (cdb_we_1 && (cdb_preg_1 == enq_preg_rs2)) |
                                         (cdb_we_2 && (cdb_preg_2 == enq_preg_rs2));
              //  iq_age[alloc_idx]     <= 4'd0;                         
            end

            // --------------------------------------------------
            // 2. ���� (Wakeup)
            // --------------------------------------------------
            for (i = 0; i < DEPTH; i = i + 1) begin
                if (iq_valid[i]) begin
                    if (!iq_rs1_rdy[i]) begin
                    if (//(gr_we_0 && (preg_rd_0 == iq_rs1[i]))  ||
                        //(gr_we_1 && (preg_rd_1 == iq_rs1[i]))  ||
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
            end

            // --------------------------------------------------
            // 3. ���� (Dequeue)
            // --------------------------------------------------
            if (issue_fire) begin
                iq_valid[issue_idx] <= 1'b0; // �ɹ����䣬��ղ�λ�����¿ն�?
            end
        end
    end

endmodule
