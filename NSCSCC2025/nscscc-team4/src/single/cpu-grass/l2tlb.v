module l2tlb
#(
    parameter TLBNUM = 16
)
(
    input        clk,
    input        reset,
    // search port 0
    input   [18:0]               s0_vppn     ,
    input                        s0_odd_page ,
    input   [ 9:0]               s0_asid     ,
    output                       s0_found    ,
    output  [$clog2(TLBNUM)-1:0] s0_index    ,
    output  [ 5:0]               s0_ps       ,
    output                       s0_g        ,
    output                       s0_e        ,
    output  [19:0]               s0_ppn0     ,
    output                       s0_v0       ,
    output                       s0_d0       ,
    output  [ 1:0]               s0_mat0     ,
    output  [ 1:0]               s0_plv0     ,
    output  [19:0]               s0_ppn1     ,
    output                       s0_v1       ,
    output                       s0_d1       ,
    output  [ 1:0]               s0_mat1     ,
    output  [ 1:0]               s0_plv1     ,
    //search port 1
    input   [18:0]               s1_vppn     ,
    input                        s1_odd_page ,
    input   [ 9:0]               s1_asid     ,
    output                       s1_found    ,
    output  [$clog2(TLBNUM)-1:0] s1_index    ,
    output  [ 5:0]               s1_ps       ,
    output                       s1_g        ,
    output                       s1_e        ,
    output  [19:0]               s1_ppn0     ,
    output                       s1_v0       ,
    output                       s1_d0       ,
    output  [ 1:0]               s1_mat0     ,
    output  [ 1:0]               s1_plv0     ,
    output  [19:0]               s1_ppn1     ,
    output                       s1_v1       ,
    output                       s1_d1       ,
    output  [ 1:0]               s1_mat1     ,
    output  [ 1:0]               s1_plv1     ,
    // write port 
    input                       we          ,
    input  [$clog2(TLBNUM)-1:0] w_index     ,
    input  [18:0]               w_vppn      ,
    input  [ 9:0]               w_asid      ,
    input                       w_g         ,
    input  [ 5:0]               w_ps        ,
    input                       w_e         ,
    input                       w_v0        ,
    input                       w_d0        ,
    input  [ 1:0]               w_mat0      ,
    input  [ 1:0]               w_plv0      ,
    input  [19:0]               w_ppn0      ,
    input                       w_v1        ,
    input                       w_d1        ,
    input  [ 1:0]               w_mat1      ,
    input  [ 1:0]               w_plv1      ,
    input  [19:0]               w_ppn1      ,
    // read port
    input  [$clog2(TLBNUM)-1:0] r_index     ,
    output [18:0]               r_vppn      ,
    output [ 9:0]               r_asid      ,
    output                      r_g         ,
    output [ 5:0]               r_ps        ,
    output                      r_e         ,
    output                      r_v0        ,
    output                      r_d0        ,
    output [ 1:0]               r_mat0      ,
    output [ 1:0]               r_plv0      ,
    output [19:0]               r_ppn0      ,
    output                      r_v1        ,
    output                      r_d1        ,
    output [ 1:0]               r_mat1      ,
    output [ 1:0]               r_plv1      ,
    output [19:0]               r_ppn1      ,
    // invalid port 
    input                       inv_en      ,
    input  [ 4:0]               inv_op      ,
    input  [ 9:0]               inv_asid    ,
    input  [18:0]               inv_vpn
);

reg [18:0] tlb_vppn     [TLBNUM-1:0];
reg        tlb_e        [TLBNUM-1:0];
reg [ 9:0] tlb_asid     [TLBNUM-1:0];
reg        tlb_g        [TLBNUM-1:0];
reg [ 5:0] tlb_ps       [TLBNUM-1:0];
reg [19:0] tlb_ppn0     [TLBNUM-1:0];
reg [ 1:0] tlb_plv0     [TLBNUM-1:0];
reg [ 1:0] tlb_mat0     [TLBNUM-1:0];
reg        tlb_d0       [TLBNUM-1:0];
reg        tlb_v0       [TLBNUM-1:0];
reg [19:0] tlb_ppn1     [TLBNUM-1:0];
reg [ 1:0] tlb_plv1     [TLBNUM-1:0];
reg [ 1:0] tlb_mat1     [TLBNUM-1:0];
reg        tlb_d1       [TLBNUM-1:0];
reg        tlb_v1       [TLBNUM-1:0];

reg [18:0] s0_vppn_r    ;
reg        s0_odd_page_r;
reg [ 9:0] s0_asid_r    ;
reg [18:0] s1_vppn_r    ;
reg        s1_odd_page_r;
reg [ 9:0] s1_asid_r    ;

wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;

wire [$clog2(TLBNUM)-1:0] match0_en;
wire [$clog2(TLBNUM)-1:0] match1_en;

wire [TLBNUM-1:0] s0_odd_page_buffer;
wire [TLBNUM-1:0] s1_odd_page_buffer;

always @(*) begin
		s0_vppn_r      = s0_vppn;    
        s0_odd_page_r  = s0_odd_page;
        s0_asid_r      = s0_asid;
		s1_vppn_r      = s1_vppn;    
        s1_odd_page_r  = s1_odd_page;
        s1_asid_r      = s1_asid;
end

genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1)
        begin: match
            assign s0_odd_page_buffer[i] = (tlb_ps[i] == 6'd12) ? s0_odd_page_r : s0_vppn_r[8];
            assign match0[i] = tlb_e[i] && ((tlb_ps[i] == 6'd12) ? s0_vppn_r == tlb_vppn[i] : s0_vppn_r[18: 9] == tlb_vppn[i][18: 9]) && ((s0_asid_r == tlb_asid[i]) || tlb_g[i]);
            assign s1_odd_page_buffer[i] = (tlb_ps[i] == 6'd12) ? s1_odd_page_r : s1_vppn_r[8];
            assign match1[i] = tlb_e[i] && ((tlb_ps[i] == 6'd12) ? s1_vppn_r == tlb_vppn[i] : s1_vppn_r[18: 9] == tlb_vppn[i][18: 9]) && ((s1_asid_r == tlb_asid[i]) || tlb_g[i]);
        end
endgenerate

encoder_32_5 en_match0 (.in({{(32-TLBNUM){1'b0}},match0}), .out(match0_en));
encoder_32_5 en_match1 (.in({{(32-TLBNUM){1'b0}},match1}), .out(match1_en));

assign s0_found = |match0;
assign s0_index = match0_en;
assign s0_ps    = tlb_ps[match0_en];
assign s0_g     = tlb_g[match0_en];
assign s0_e     = tlb_e[match0_en];
assign s0_ppn0  = tlb_ppn0[match0_en];
assign s0_mat0  = tlb_mat0[match0_en];
assign s0_plv0  = tlb_plv0[match0_en];
assign s0_d0    = tlb_d0[match0_en];
assign s0_v0    = tlb_v0[match0_en]; 
assign s0_ppn1  = tlb_ppn1[match0_en];
assign s0_mat1  = tlb_mat1[match0_en];
assign s0_plv1  = tlb_plv1[match0_en];
assign s0_d1    = tlb_d1[match0_en];
assign s0_v1    = tlb_v1[match0_en];

assign s1_found = |match1;
assign s1_index = match1_en;
assign s1_ps    = tlb_ps[match1_en];
assign s1_g     = tlb_g[match1_en];
assign s1_e     = tlb_e[match1_en];
assign s1_ppn0  = tlb_ppn0[match1_en];
assign s1_mat0  = tlb_mat0[match1_en];
assign s1_plv0  = tlb_plv0[match1_en];
assign s1_d0    = tlb_d0[match1_en];
assign s1_v0    = tlb_v0[match1_en];
assign s1_ppn1  = tlb_ppn1[match1_en];
assign s1_mat1  = tlb_mat1[match1_en];
assign s1_plv1  = tlb_plv1[match1_en];
assign s1_d1    = tlb_d1[match1_en];
assign s1_v1    = tlb_v1[match1_en];

integer k; 

always @(posedge clk) begin
    if (reset) begin
        for (k = 0; k < TLBNUM; k = k + 1) begin
            tlb_vppn[k] <= 19'b0;
            tlb_asid[k] <= 10'b0;
            tlb_g[k]    <= 1'b0;
            tlb_ps[k]   <= 6'b0;
            tlb_ppn0[k] <= 20'b0;
            tlb_plv0[k] <= 2'b0;
            tlb_mat0[k] <= 2'b0;
            tlb_d0[k]   <= 1'b0;
            tlb_v0[k]   <= 1'b0;
            tlb_ppn1[k] <= 20'b0;
            tlb_plv1[k] <= 2'b0;
            tlb_mat1[k] <= 2'b0;
            tlb_d1[k]   <= 1'b0;
            tlb_v1[k]   <= 1'b0;
        end
    end
    else if (we) begin
        tlb_vppn [w_index] <= w_vppn;
        tlb_asid [w_index] <= w_asid;
        tlb_g    [w_index] <= w_g; 
        tlb_ps   [w_index] <= w_ps;  
        tlb_ppn0 [w_index] <= w_ppn0;
        tlb_plv0 [w_index] <= w_plv0;
        tlb_mat0 [w_index] <= w_mat0;
        tlb_d0   [w_index] <= w_d0;
        tlb_v0   [w_index] <= w_v0; 
        tlb_ppn1 [w_index] <= w_ppn1;
        tlb_plv1 [w_index] <= w_plv1;
        tlb_mat1 [w_index] <= w_mat1;
        tlb_d1   [w_index] <= w_d1;
        tlb_v1   [w_index] <= w_v1; 
    end
end

assign r_vppn  =  tlb_vppn [r_index]; 
assign r_asid  =  tlb_asid [r_index]; 
assign r_g     =  tlb_g    [r_index]; 
assign r_ps    =  tlb_ps   [r_index]; 
assign r_e     =  tlb_e    [r_index]; 
assign r_v0    =  tlb_v0   [r_index]; 
assign r_d0    =  tlb_d0   [r_index]; 
assign r_mat0  =  tlb_mat0 [r_index]; 
assign r_plv0  =  tlb_plv0 [r_index]; 
assign r_ppn0  =  tlb_ppn0 [r_index]; 
assign r_v1    =  tlb_v1   [r_index]; 
assign r_d1    =  tlb_d1   [r_index]; 
assign r_mat1  =  tlb_mat1 [r_index]; 
assign r_plv1  =  tlb_plv1 [r_index]; 
assign r_ppn1  =  tlb_ppn1 [r_index]; 

generate 
    for (i = 0; i < TLBNUM; i = i + 1) 
        begin: invalid_tlb_entry 
            always @(posedge clk) begin
                if(reset) begin
                    tlb_e[i] <= 1'b0;
                end
                else if (we && (w_index == i)) begin
                    tlb_e[i] <= w_e;
                end
                else if (inv_en) begin
                    if (inv_op == 5'd0 || inv_op == 5'd1) begin
                        tlb_e[i] <= 1'b0;
                    end
                    else if (inv_op == 5'd2) begin
                        if (tlb_g[i]) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd3) begin
                        if (!tlb_g[i]) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd4) begin
                        if (!tlb_g[i] && (tlb_asid[i] == inv_asid)) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd5) begin
                        if (!tlb_g[i] && (tlb_asid[i] == inv_asid) && 
                           ((tlb_ps[i] == 6'd12) ? (tlb_vppn[i] == inv_vpn) : (tlb_vppn[i][18:9] == inv_vpn[18:9]))) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd6) begin
                        if ((tlb_g[i] || (tlb_asid[i] == inv_asid)) && 
                           ((tlb_ps[i] == 6'd12) ? (tlb_vppn[i] == inv_vpn) : (tlb_vppn[i][18:9] == inv_vpn[18:9]))) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                end
            end
        end 
endgenerate

endmodule
