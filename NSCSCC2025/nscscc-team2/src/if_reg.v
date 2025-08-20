module if_reg (
    input  wire         clk,         
    input  wire         reset,     
    input  wire         ertn_flush,
    input  wire         ex_flush,
    input  wire         br_flush,
    input  wire         refetch_flush,
    input  wire         stall,

    input  wire         pre_if_ready_go,

    input  wire  [31:0] pc_in,
    input  wire  [15:0] ex_info_in,
    input  wire  [ 1:0] badv_info_in,

    output reg   [31:0] pc_out,
    output reg   [15:0] ex_info_out,
    output reg   [ 1:0] badv_info_out,

    input  wire         id_fire,
    output wire         if_fire,
    output wire         if_allowin,
    output reg          if_valid
);

assign if_allowin = (!if_valid) || id_fire;

assign if_fire = pre_if_ready_go && if_allowin;

always @(posedge clk or posedge reset) begin
  if (reset) begin
    if_valid <= 1'b0;
  end
  else if ((ertn_flush ) || (ex_flush ) || (br_flush ) || (refetch_flush )) begin
    if_valid <= 1'b0;
  end
  else if (if_fire) begin 
    if_valid <= 1'b1;        
  end
  else if (id_fire) begin 
    if_valid <= 1'b0;       
  end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc_out <= 32'b0;
        ex_info_out <= 16'b0;
        badv_info_out <= 2'b00;
    end
    else if ((ertn_flush ) || (ex_flush ) || (br_flush ) || (refetch_flush )) begin
        pc_out <= 32'b0;
        ex_info_out <= 16'b0;
        badv_info_out <= 2'b00;
    end
    else if (if_fire) begin
        pc_out <= pc_in;
        ex_info_out <= ex_info_in;
        badv_info_out <= badv_info_in;
    end
end

endmodule
