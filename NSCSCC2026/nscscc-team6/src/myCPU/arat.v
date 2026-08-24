//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/12 11:08:40
// Design Name: 
// Module Name: arat
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


module arat (
    input  wire        clk,
    input  wire        reset,

    // д�˿� (���� ROB �ύ��)
    input  wire        commit_we_0,
    input  wire [ 4:0] commit_waddr_0,
    input  wire [ 5:0] commit_wdata_0,

    input  wire        commit_we_1,
    input  wire [ 4:0] commit_waddr_1,
    input  wire [ 5:0] commit_wdata_1,

    // ��¶�� sRAT ���ڻָ�������
    output wire [191:0] arat_recover_bus,
   //flushʱ����freelist
    output wire [ 63:0] arat_mapped_mask
);
reg [5:0] next_arat_mem [31:0];
reg [5:0] arat_mem [31:0];
integer n;
    always @(*) begin
        // �Ȱѵ�ǰ�ľ�״̬ԭ�ⲻ���س�����
        for (n = 0; n < 32; n = n + 1) begin
            next_arat_mem[n] = arat_mem[n];
        end
        // ������ύд�룬����������߼��︲���� (ʹ��������ֵ =)
        if (commit_we_0 && commit_waddr_0 != 5'd0) begin
            next_arat_mem[commit_waddr_0] = commit_wdata_0;
        end
        if (commit_we_1 && commit_waddr_1 != 5'd0) begin
            next_arat_mem[commit_waddr_1] = commit_wdata_1;
        end
    end

    integer i;

    // ƴ�ӳɻָ�����
    genvar j;
    generate
        for (j = 0; j < 32; j = j + 1) begin : gen_arat_bus
            assign arat_recover_bus[j*6 +: 6] = next_arat_mem[j];
        end
    endgenerate
reg [63:0] mask_comb;
    integer k;
    always @(*) begin
        mask_comb = 64'd0;
        for (k = 0; k < 32; k = k + 1) begin
            mask_comb[next_arat_mem[k]] = 1'b1; // �����ڱ� aRAT ָ��� preg λ�� 1
        end
    end
    assign arat_mapped_mask = mask_comb;
always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                arat_mem[i] <= i[5:0];
            end
        end
        else begin
            // ֱ�Ӱ���õĴ�̬����Ĵ�������
            for (i = 0; i < 32; i = i + 1) begin
                arat_mem[i] <= next_arat_mem[i];
            end
        end
    end
endmodule

