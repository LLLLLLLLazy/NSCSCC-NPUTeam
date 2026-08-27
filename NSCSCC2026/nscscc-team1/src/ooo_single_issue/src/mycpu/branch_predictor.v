module branch_predictor(
    input               clk,
    input               resetn,
    input  [31:0]       pc,
    input               update,
    input  [31:0]       branch_pc,
    input               actual_taken,
    input  [31:0]       actual_target,
    output              is_taken,
    output [31:0]       target_address
);

reg [1:0] PHT [1023:0];
reg [1:0] BTB_valid [63:0];
reg [22:0] BTB_tag [63:0][1:0];
reg [31:0] BTB_target [63:0][1:0];

wire [22:0] read_BTB_tag,write_BTB_tag;
wire [9:0] read_PHT,write_PHT;
wire [5:0] read_BTB,write_BTB;
assign read_PHT = pc[11:2];
assign write_PHT = branch_pc[11:2];
assign read_BTB = pc[7:2];
assign write_BTB = branch_pc[7:2];
assign read_BTB_tag = pc[31:9];
assign write_BTB_tag = branch_pc[31:9];


genvar i;
generate
    for(i = 0; i < 1024; i = i + 1) begin : pht_gen
        always @(posedge clk) begin
            if(!resetn) begin
                PHT[i] <= 2'b00;
            end
            else if(update && (write_PHT == i)) begin
                case(PHT[i])
                    2'b00: PHT[i] <= actual_taken ? 2'b01 : 2'b00;
                    2'b01: PHT[i] <= actual_taken ? 2'b10 : 2'b00;
                    2'b10: PHT[i] <= actual_taken ? 2'b11 : 2'b01;
                    2'b11: PHT[i] <= actual_taken ? 2'b11 : 2'b10;
                endcase
            end
        end
    end
endgenerate

wire BTB_way1_rhit, BTB_way2_rhit;
assign BTB_way1_rhit = (BTB_valid[read_BTB][0] && (BTB_tag[read_BTB][0] == read_BTB_tag)) ? 1 : 0;
assign BTB_way2_rhit = (BTB_valid[read_BTB][1] && (BTB_tag[read_BTB][1] == read_BTB_tag)) ? 1 : 0;
wire BTB_way1_whit, BTB_way2_whit;
assign BTB_way1_whit = (BTB_valid[write_BTB][0] && (BTB_tag[write_BTB][0] == write_BTB_tag)) ? 1 : 0;
assign BTB_way2_whit = (BTB_valid[write_BTB][1] && (BTB_tag[write_BTB][1] == write_BTB_tag)) ? 1 : 0;

wire read_BTB_hit,write_BTB_hit;
assign read_BTB_hit = BTB_way1_rhit || BTB_way2_rhit;
assign write_BTB_hit = BTB_way1_whit || BTB_way2_whit;
wire [31:0] hit_target;

assign hit_target = BTB_way1_rhit ? BTB_target[read_BTB][0] : BTB_target[read_BTB][1];

wire [0:0] whit_index;

assign whit_index = BTB_way2_whit;

//reg is_full;
wire replace_index;
reg plru [63:0];

assign replace_index =
    !BTB_valid[write_BTB][0] ? 1'b0 :
    !BTB_valid[write_BTB][1] ? 1'b1 :
                               plru[write_BTB];

genvar s, w;
generate
    for (s = 0; s < 64; s = s + 1) begin : valid_set
        for (w = 0; w < 2; w = w + 1) begin : valid_way
            always @(posedge clk) begin
                if (!resetn)
                    BTB_valid[s][w] <= 1'b0;
                else if (update && actual_taken &&
                         !write_BTB_hit &&
                         (write_BTB == s) &&
                         (replace_index == w))
                    BTB_valid[s][w] <= 1'b1;
            end
        end
    end
endgenerate
generate
    for (s = 0; s < 64; s = s + 1) begin : tag_set
        for (w = 0; w < 2; w = w + 1) begin : tag_way
            always @(posedge clk) begin
                if (update && actual_taken &&
                    !write_BTB_hit &&
                    (write_BTB == s) &&
                    (replace_index == w))
                    BTB_tag[s][w] <= write_BTB_tag;
            end
        end
    end
endgenerate

wire [63:0] write_sel;
genvar k;
generate
    for(k = 0; k < 64; k = k + 1) begin
        assign write_sel[k] = (write_BTB == k);
    end
endgenerate

generate
    for (s = 0; s < 64; s = s + 1) begin : target_set
        for (w = 0; w < 2; w = w + 1) begin : target_way
            always @(posedge clk) begin
                if (update && actual_taken) begin
                    if (write_BTB_hit) begin
                        if ((write_sel[s]) &&
                            ((BTB_way1_whit && w==0) ||
                             (BTB_way2_whit && w==1)))
                            BTB_target[s][w] <= actual_target;
                    end
                    else begin
                        if ((write_sel[s]) &&
                            (replace_index == w))
                            BTB_target[s][w] <= actual_target;
                    end
                end
            end
        end
    end
endgenerate
generate
    for (s = 0; s < 64; s = s + 1) begin : plru_set
        always @(posedge clk) begin
            if (!resetn)
                plru[s] <= 1'b0;
            else if (update && actual_taken && (write_sel[s])) begin
                case (write_BTB_hit ? whit_index : replace_index)
                   1'd0: plru[s] <= 1'b1;
                   1'd1: plru[s] <= 1'b0;
                endcase
            end
        end
    end
endgenerate

assign is_taken = read_BTB_hit && PHT[read_PHT][1];
assign target_address = is_taken ? hit_target : (pc+4);

endmodule
