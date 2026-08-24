//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/12 11:05:18
// Design Name: 
// Module Name: srat
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


module srat (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,         // �쳣�ָ��ź�

    // �� aRAT �ָ��ֳ������� (32���Ĵ�����ÿ��6λ = 192 bits)
    input  wire [191:0] arat_recover_bus, 

    // ���˿� (6�����첽��)
    input  wire [ 4:0] raddr1_0,
    input  wire [ 4:0] raddr2_0,
    input  wire [ 4:0] raddr1_1,
    input  wire [ 4:0] raddr2_1,
    output wire [ 5:0] rdata1_0,
    output wire [ 5:0] rdata2_0,
    output wire [ 5:0] rdata1_1,
    output wire [ 5:0] rdata2_1,
    input  wire [ 4:0] raddr_rd_0,
    input  wire [ 4:0] raddr_rd_1,
    output wire [ 5:0] rdata_rd_0,
    output wire [ 5:0] rdata_rd_1,
    // д�˿� (2����ͬ��д)
    input  wire        we_0,
    input  wire [ 4:0] waddr_0,
    input  wire [ 5:0] wdata_0,

    input  wire        we_1,
    input  wire [ 4:0] waddr_1,
    input  wire [ 5:0] wdata_1
);

    reg [5:0] srat_mem [31:0];
    integer i;

    // �첽��
assign rdata1_0 = (raddr1_0 == 5'd0) ? 6'd0 : srat_mem[raddr1_0];
assign rdata2_0 = (raddr2_0 == 5'd0) ? 6'd0 : srat_mem[raddr2_0];
assign rdata1_1 = (raddr1_1 == 5'd0) ? 6'd0 :
                  (we_0 && (waddr_0 == raddr1_1)) ? wdata_0 : srat_mem[raddr1_1];

assign rdata2_1 = (raddr2_1 == 5'd0) ? 6'd0 :
                  (we_0 && (waddr_0 == raddr2_1)) ? wdata_0 : srat_mem[raddr2_1];
    // �첽�� old_preg
    assign rdata_rd_0 = (raddr_rd_0 == 5'd0) ? 6'd0 : srat_mem[raddr_rd_0];
    assign rdata_rd_1 = (raddr_rd_1 == 5'd0) ? 6'd0 :
                        (we_0 && raddr_rd_0 == raddr_rd_1)? wdata_0 : srat_mem[raddr_rd_1];
    always @(posedge clk) begin
        if (reset) begin
            // ��ʼ״̬���߼��Ĵ��� 0~31 ֱ��ӳ�䵽�����Ĵ��� 0~31
            for (i = 0; i < 32; i = i + 1) begin
                srat_mem[i] <= i[5:0];
            end
        end
        else if (flush) begin
            // �����쳣��˲��� aRAT �ָ����� 32 ���Ĵ�����״̬
            for (i = 0; i < 32; i = i + 1) begin
                srat_mem[i] <= arat_recover_bus[i*6 +: 6]; 
            end
        end
        else begin
            // ͬ��д��ע�⣺��� waddr_0 �� waddr_1 ��ͬ��wdata_1 ���븲�� wdata_0��
            // ���� Verilog ˳��ִ�е����ԣ���д�ĻḲ����д��
            if (we_0 && waddr_0 != 5'd0) srat_mem[waddr_0] <= wdata_0;
            if (we_1 && waddr_1 != 5'd0) srat_mem[waddr_1] <= wdata_1;
        end
    end
endmodule
