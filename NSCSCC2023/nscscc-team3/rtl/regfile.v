module regfile(
    input            clk,               //时钟
    input            wen,               //写使能
    input  [4:0]     num_a,             //读寄存器索引a
    input  [4:0]     num_b,             //读寄存器索引b
    input  [4:0]     num_c,             //写寄存器索引
    input  [31:0]    data_c,            //写数据
    output [31:0]    data_a,            //读出数据a
    output [31:0]    data_b             //读出数据b
`ifdef DIFFTEST_EN
    ,
    output [31:0]    rf_regs_diff [31:0] // for difftest
`endif 
);
    reg    [31:0]    gp_registers[31:0]; //寄存器堆
    always @(posedge clk) begin
        if(wen)
            gp_registers[num_c] <= data_c;
    end
    assign data_a = {32{|num_a}} & gp_registers[num_a];
    assign data_b = {32{|num_b}} & gp_registers[num_b];
`ifdef DIFFTEST_EN
    assign rf_regs_diff = gp_registers;
`endif 
endmodule
