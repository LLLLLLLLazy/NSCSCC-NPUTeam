`include "mycpu.h"

module fetch_buffer (
    input  wire        clk,
    input  wire        reset,
    
    // ���Ժ��(ROB/WB)��ˢ���źţ��쳣���߷�֧Ԥ��ʧ��
    input  wire        flush,


    // Enqueue (�� IF ���Խӣ�ά�ֵ����� 1��)
 
    input  wire   [3:0]     enq_valid,
    input  wire [`FS_TO_FB_BUS_WD -1:0] enq_bus,
    output wire        enq_allowin,


    // Dequeue (�� ID/Rename ���Խӣ���Ϊ˫���� 2��)

    output wire [1:0]  deq_valid,     // [0]��ʾbus_0��Ч��[1]��ʾbus_1��Ч
    output wire [`FS_TO_DS_BUS_WD -1:0] deq_bus_0, // ��1��ָ����ϵ�ָ�
    output wire [`FS_TO_DS_BUS_WD -1:0] deq_bus_1, // ��2��ָ����µ�ָ�
    
    // �ؼ��ı䣺��Ϊ�󼶿���ֻ��1����Ҳ������2���������� pop_count ��� ready
    // 2'b00: û��;  2'b01: ����1��;  2'b10: ����2��
    input  wire [1:0]  deq_pop_count
  //  input wire es_is_div
    
    // ��֧��ת��Ϣ
  //  input  wire [`BR_BUS_WD       -1:0] br_bus 
);


//    assign {br_stall, br_taken, br_target} = br_bus;

    // �������壺��ȿ���Ϊ 8 �� 16 (������ 2 ����)
    parameter BUFFER_DEPTH = 16;
    localparam ADDR_WD = $clog2(BUFFER_DEPTH);

    // �洢����
    reg [`FS_TO_DS_BUS_WD -1:0] buffer_mem [BUFFER_DEPTH-1:0];
    
    // ָ����� (��1λ�����жϿ���)
    reg [ADDR_WD:0] head_ptr; // ��ָ��
    reg [ADDR_WD:0] tail_ptr; // дָ��

    // ״̬����
    wire [ADDR_WD:0] count = tail_ptr - head_ptr;
//    wire is_full  = (count == BUFFER_DEPTH);

    // ��ǰ���������ź� (ֻҪ��������û�з����ӳٲ� stall���Ϳ��Խ�)
 //   assign enq_allowin = !is_full ;
// ���ĸı䣺ֻҪ��λС�� 4 �� (������ָ���� > 12)������������ allowin
assign enq_allowin = (count <= (BUFFER_DEPTH - 4));   
 
localparam INST_WD = `FS_TO_DS_BUS_WD;
wire [INST_WD-1:0] in_inst_0 = enq_bus[1*INST_WD-1 : 0*INST_WD];
wire [INST_WD-1:0] in_inst_1 = enq_bus[2*INST_WD-1 : 1*INST_WD];
wire [INST_WD-1:0] in_inst_2 = enq_bus[3*INST_WD-1 : 2*INST_WD];
wire [INST_WD-1:0] in_inst_3 = enq_bus[4*INST_WD-1 : 3*INST_WD];
// 2) ����ÿ����Чָ��Ӧ��д���ƫ���� 
    wire [2:0] offset_0 = 3'd0;
    wire [2:0] offset_1 = offset_0 + enq_valid[0];
    wire [2:0] offset_2 = offset_1 + enq_valid[1];
    wire [2:0] offset_3 = offset_2 + enq_valid[2];
// ������ʵ��д�������Чָ����
wire [2:0] enq_count = offset_3 + enq_valid[3];    
// 3) ����ʵ������ RAM �ĵ�ַ  
wire [ADDR_WD-1:0] wr_idx_0 = tail_ptr[ADDR_WD-1:0] + offset_0;
wire [ADDR_WD-1:0] wr_idx_1 = tail_ptr[ADDR_WD-1:0] + offset_1;
wire [ADDR_WD-1:0] wr_idx_2 = tail_ptr[ADDR_WD-1:0] + offset_2;
wire [ADDR_WD-1:0] wr_idx_3 = tail_ptr[ADDR_WD-1:0] + offset_3; 
    always @(posedge clk) begin
        if (reset || flush ) begin
            tail_ptr <= 0;
        end
        else if ((|enq_valid) && enq_allowin) begin
            // ֻ�ж�Ӧ valid Ϊ 1 ��ָ��Żᱻд��
            if (enq_valid[0]) buffer_mem[wr_idx_0] <= in_inst_0;
            if (enq_valid[1]) buffer_mem[wr_idx_1] <= in_inst_1;
            if (enq_valid[2]) buffer_mem[wr_idx_2] <= in_inst_2;
            if (enq_valid[3]) buffer_mem[wr_idx_3] <= in_inst_3;
            
            // ָ�벽��ʵ��д�������
            tail_ptr <= tail_ptr + { {(ADDR_WD-2){1'b0}}, enq_count };
        end
    end

    // �����߼� (Dequeue - ���ĸĶ��㣬ÿ�α�¶2��)

    
    // 1. �жϳ������м�����Чָ��
   // assign deq_valid[0] = (count >= 1) && !es_is_div; // ������1��
  //  assign deq_valid[1] = (count >= 2) && !es_is_div; // ������2��
 assign deq_valid[0] = (count >= 1+deq_pop_count); // ������1��
  assign deq_valid[1] = (count >= 2 + deq_pop_count);
    // 2. ׼���������˿ڵĵ�ַ
    wire [ADDR_WD-1:0] head_idx_0 = head_ptr[ADDR_WD-1:0]+ deq_pop_count;
    // ����λ���ض����ԣ���� head ���� 15��+1 ���Զ����ص� 0
    wire [ADDR_WD-1:0] head_idx_1 = head_ptr[ADDR_WD-1:0] + deq_pop_count+1'b1;

    // 3. ������¶��ͷ�����ϵ�����ָ��
    assign deq_bus_0 = buffer_mem[head_idx_0];
    assign deq_bus_1 = buffer_mem[head_idx_1];

    // 4. ���ݺ�ʵ�����ߵ�������pop_count����������ָ��
    always @(posedge clk) begin
        if (reset || flush ) begin
            head_ptr <= 0;
        end

        else if(count != 5'b0)begin
            
            head_ptr <= head_ptr + deq_pop_count;
        end
     
        /*
        else if(es_is_div) begin
            head_ptr <= head_ptr + 1'b0;
        end
        else begin
            head_ptr <= head_ptr + deq_pop_count;
        end
        */
    end

endmodule