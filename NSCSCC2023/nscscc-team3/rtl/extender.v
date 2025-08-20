module extender(
    input  [25:0] instr_25_0,
    input  [7:0]  c_immsel,
    output [31:0] imm32
);
    wire [4:0] ui5;
    wire [11:0] imm12;
    wire [13:0] si14;
    wire [15:0] off16;
    wire [19:0] si20;
    wire [20:0] off21;
    wire [25:0] off26;
    assign ui5 = instr_25_0[14:10];
    assign imm12 = instr_25_0[21:10];
    assign si14 = instr_25_0[23:10];
    assign off16 = instr_25_0[25:10];
    assign si20 = instr_25_0[24:5];
    assign off21 = {instr_25_0[4:0],instr_25_0[25:10]};
    assign off26 = {instr_25_0[9:0],instr_25_0[25:10]};
    wire [31:0] ui5_ext;
    wire [31:0] si12_ext;
    wire [31:0] ui12_ext;
    wire [31:0] si14_ext;
    wire [31:0] off16_ext;
    wire [31:0] si20_ext;
    wire [31:0] off21_ext;
    wire [31:0] off26_ext;
    assign ui5_ext =   {27'b0,ui5};
    assign si12_ext =  {{20{imm12[11]}},imm12};
    assign ui12_ext =  {20'b0,imm12};
    assign si14_ext =  {{16{si14[13]}},si14,2'b0};
    assign off16_ext = {{14{off16[15]}},off16,2'b0};
    assign si20_ext =  {si20,12'b0};
    assign off21_ext = {{9{off21[20]}},off21,2'b0};
    assign off26_ext = {{4{off26[25]}},off26,2'b0};
    assign imm32 = ({32{c_immsel[0]}} & ui5_ext)
                  |({32{c_immsel[1]}} & si12_ext)
                  |({32{c_immsel[2]}} & ui12_ext)
                  |({32{c_immsel[3]}} & si14_ext)
                  |({32{c_immsel[4]}} & off16_ext)
                  |({32{c_immsel[5]}} & si20_ext)
                  |({32{c_immsel[6]}} & off21_ext)
                  |({32{c_immsel[7]}} & off26_ext);
endmodule
