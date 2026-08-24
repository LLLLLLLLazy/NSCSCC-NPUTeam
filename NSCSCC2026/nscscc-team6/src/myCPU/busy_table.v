//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/15 18:10:10
// Design Name: 
// Module Name: busy_table
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


module busy_table (
    input  wire        clk,
    input  wire        reset,

    // 1. Rename �׶�����״̬
    input  wire [ 5:0] check_preg_rs1_0,
    input  wire [ 5:0] check_preg_rs2_0,
    output wire        rs1_is_ready_0, //��dispatch
    output wire        rs2_is_ready_0, 
    // ָ�� 1 ��Դ������״̬��ѯ
    input  wire [ 5:0] check_preg_rs1_1,
    input  wire [ 5:0] check_preg_rs2_1,
    output wire        rs1_is_ready_1,
    output wire        rs2_is_ready_1,    
    // 2. Rename �׶��������¼Ĵ�����������Ϊ 0 (Busy/δ���)
    input  wire        allocate_we_0,
    input  wire [ 5:0] allocated_preg_0,
    input  wire        allocate_we_1,
    input  wire [ 5:0] allocated_preg_1,

    // 3. ��� ALU/MEM �������ˣ�ͨ�� CDB �㲥��������Ϊ 1 (Ready/�����)
    input  wire        cdb_we_0,       // ���� ALU_0
    input  wire [ 5:0] cdb_preg_0,
    
    input  wire        cdb_we_1,       // ���� ALU_1
    input  wire [ 5:0] cdb_preg_1,
    
    input  wire        cdb_we_2,       // ���� MEM/LSU
    input  wire [ 5:0] cdb_preg_2,
    
    input wire          reflush
);

    // 64�������Ĵ�����״̬��1 ��ʾ Ready(���Զ�)��0 ��ʾ Busy(������)
    reg [63:0] ready_bits;


assign rs1_is_ready_0 = (check_preg_rs1_0 == 6'd0) ? 1'b1 : 
                        (cdb_we_0 && (cdb_preg_0 == check_preg_rs1_0)) ? 1'b1 :
                        (cdb_we_1 && (cdb_preg_1 == check_preg_rs1_0)) ? 1'b1 :
                        (cdb_we_2 && (cdb_preg_2 == check_preg_rs1_0)) ? 1'b1 :ready_bits[check_preg_rs1_0];
assign rs2_is_ready_0 = (check_preg_rs2_0 == 6'd0) ? 1'b1 : 
                        (cdb_we_0 && (cdb_preg_0 == check_preg_rs2_0)) ? 1'b1 :
                        (cdb_we_1 && (cdb_preg_1 == check_preg_rs2_0)) ? 1'b1 :
                        (cdb_we_2 && (cdb_preg_2 == check_preg_rs2_0)) ? 1'b1 :ready_bits[check_preg_rs2_0];
assign rs1_is_ready_1 = (check_preg_rs1_1 == 6'd0) ? 1'b1 : 
                        ( allocate_we_0  && allocated_preg_0 == check_preg_rs1_1 ) ? 1'b0 :
                        (cdb_we_0 && (cdb_preg_0 == check_preg_rs1_1)) ? 1'b1 :
                        (cdb_we_1 && (cdb_preg_1 == check_preg_rs1_1)) ? 1'b1 :
                        (cdb_we_2 && (cdb_preg_2 == check_preg_rs1_1)) ? 1'b1 :ready_bits[check_preg_rs1_1];
assign rs2_is_ready_1 = (check_preg_rs2_1 == 6'd0) ? 1'b1 : 
                        ( allocate_we_0  && allocated_preg_0 == check_preg_rs2_1 ) ? 1'b0 :
                        (cdb_we_0 && (cdb_preg_0 == check_preg_rs2_1)) ? 1'b1 :
                        (cdb_we_1 && (cdb_preg_1 == check_preg_rs2_1)) ? 1'b1 :
                        (cdb_we_2 && (cdb_preg_2 == check_preg_rs2_1)) ? 1'b1 :ready_bits[check_preg_rs2_1];

    integer i;
    always @(posedge clk) begin
        if (reset || reflush) begin
            // ȫ���� Ready ��
            ready_bits <= 64'hFFFFFFFF_FFFFFFFF;
        end
        else begin
            //��������ˣ�������� 1 (Ready)
            if (cdb_we_0 && cdb_preg_0 != 6'd0) ready_bits[cdb_preg_0] <= 1'b1;
            if (cdb_we_1 && cdb_preg_1 != 6'd0) ready_bits[cdb_preg_1] <= 1'b1;
            if (cdb_we_2 && cdb_preg_2 != 6'd0) ready_bits[cdb_preg_2] <= 1'b1; 
            // Rename �������¼Ĵ������������ 0 (Busy)
            if (allocate_we_0 && allocated_preg_0 != 6'd0) ready_bits[allocated_preg_0] <= 1'b0;
            if (allocate_we_1 && allocated_preg_1 != 6'd0) ready_bits[allocated_preg_1] <= 1'b0;

        end
    end

endmodule
