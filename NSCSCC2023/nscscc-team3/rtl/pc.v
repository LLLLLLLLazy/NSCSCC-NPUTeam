module pc(
    output reg [31:0] pc,
    input             clk,
    input             rst_n,
    input [31:0]      npc,
    input             en    //Ð´Ê¹ÄÜÐÅºÅ
);
    
    always@(posedge clk)begin
        if(!rst_n)
            pc<=32'h1c000000;
        else if(en)
            pc<=npc;
    end
endmodule
