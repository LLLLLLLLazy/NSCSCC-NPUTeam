module tlb
#(
    parameter TLBNUM = 8
)
(
    input  wire                      clk,

    // search port 0 (for fetch)
    input  wire [              18:0] s0_vppn,
    input  wire                      s0_va_bit12,
    input  wire [               9:0] s0_asid,
    output wire                      s0_found,
    output wire [$clog2(TLBNUM)-1:0] s0_index,
    output wire [              19:0] s0_ppn,
    output wire [               5:0] s0_ps,
    output wire [               1:0] s0_plv,
    output wire [               1:0] s0_mat,
    output wire                      s0_d,
    output wire                      s0_v,

    // search port 1 (for load/store)
    input  wire [              18:0] s1_vppn,
    input  wire                      s1_va_bit12,
    input  wire [               9:0] s1_asid,
    output wire                      s1_found,
    output wire [$clog2(TLBNUM)-1:0] s1_index,
    output wire [              19:0] s1_ppn,
    output wire [               5:0] s1_ps,
    output wire [               1:0] s1_plv,
    output wire [               1:0] s1_mat,
    output wire                      s1_d,
    output wire                      s1_v,

    // invtlb opcode
    input  wire                      invtlb_valid,
    input  wire [               4:0] invtlb_op,

    // write port
    input  wire                      we,     //w(rite) e(nable)
    input  wire                      tlbfill,
    input  wire [$clog2(TLBNUM)-1:0] rand_index,
    input  wire [$clog2(TLBNUM)-1:0] w_index,
    input  wire                      w_e,
    input  wire [              18:0] w_vppn,
    input  wire [               5:0] w_ps,
    input  wire [               9:0] w_asid,
    input  wire                      w_g,
    input  wire [              19:0] w_ppn0,
    input  wire [               1:0] w_plv0,
    input  wire [               1:0] w_mat0,
    input  wire                      w_d0,
    input  wire                      w_v0,
    input  wire [              19:0] w_ppn1,
    input  wire [               1:0] w_plv1,
    input  wire [               1:0] w_mat1,
    input  wire                      w_d1,
    input  wire                      w_v1,

    // read port
    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output wire                      r_e,
    output wire [              18:0] r_vppn,
    output wire [               5:0] r_ps,
    output wire [               9:0] r_asid,
    output wire                      r_g,
    output wire [              19:0] r_ppn0,
    output wire [               1:0] r_plv0,
    output wire [               1:0] r_mat0,
    output wire                      r_d0,
    output wire                      r_v0,
    output wire [              19:0] r_ppn1,
    output wire [               1:0] r_plv1,
    output wire [               1:0] r_mat1,
    output wire                      r_d1,
    output wire                      r_v1
);

reg  [TLBNUM-1:0] tlb_e;
reg  [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg  [      18:0] tlb_vppn     [TLBNUM-1:0];
reg  [       9:0] tlb_asid     [TLBNUM-1:0];
reg               tlb_g        [TLBNUM-1:0];
reg  [      19:0] tlb_ppn0     [TLBNUM-1:0];
reg  [       1:0] tlb_plv0     [TLBNUM-1:0];
reg  [       1:0] tlb_mat0     [TLBNUM-1:0];
reg               tlb_d0       [TLBNUM-1:0];
reg               tlb_v0       [TLBNUM-1:0];
reg  [      19:0] tlb_ppn1     [TLBNUM-1:0];
reg  [       1:0] tlb_plv1     [TLBNUM-1:0];
reg  [       1:0] tlb_mat1     [TLBNUM-1:0];
reg               tlb_d1       [TLBNUM-1:0];
reg               tlb_v1       [TLBNUM-1:0];

wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;
wire [TLBNUM-1:0] cond1;//G域是否等于0
wire [TLBNUM-1:0] cond2;//G域是否等于1
wire [TLBNUM-1:0] cond3;//s1_asid是否等于ASID域
wire [TLBNUM-1:0] cond4;//s1_vppn是否匹配VPPN和PS域
wire [TLBNUM-1:0] invtlb_cond;

wire [TLBNUM-1:0] real_w_index;

genvar i0;
generate
    for (i0 = 0; i0 < TLBNUM; i0 = i0 + 1) begin : gen_match0
        wire match0_vppn = (s0_vppn[18:9] == tlb_vppn[i0][18:9]);
        wire match0_vppn_ps4MB = (tlb_ps4MB[i0] || s0_vppn[8:0] == tlb_vppn[i0][8:0]);
        wire match0_asid = ((s0_asid == tlb_asid[i0]) || tlb_g[i0]);
        wire match0_enabled = tlb_e[i0];

        assign match0[i0] = match0_vppn && match0_vppn_ps4MB && match0_asid && match0_enabled;
    end
endgenerate

assign s0_found = |match0;
reg [2:0] s0_index_reg;

always @(*) begin
    s0_index_reg = 'h0; // Default value
    casez (match0)
        8'b00000001: s0_index_reg = 3'h0;
        8'b0000001?: s0_index_reg = 3'h1;
        8'b000001??: s0_index_reg = 3'h2;
        8'b00001???: s0_index_reg = 3'h3;
        8'b0001????: s0_index_reg = 3'h4;
        8'b001?????: s0_index_reg = 3'h5;
        8'b01??????: s0_index_reg = 3'h6;
        8'b1???????: s0_index_reg = 3'h7;
        default: s0_index_reg = 3'h0;
    endcase
end

assign s0_index = s0_index_reg;
wire s0_select = s0_va_bit12 && !tlb_ps4MB[s0_index]  || s0_vppn[8] && tlb_ps4MB[s0_index];

assign s0_ppn = s0_select ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_ps  = tlb_ps4MB[s0_index] ? 6'h15 : 6'hc;
assign s0_plv = s0_select ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_mat = s0_select ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d   = s0_select ? tlb_d1[s0_index] : tlb_d0[s0_index];
assign s0_v   = s0_select ? tlb_v1[s0_index] : tlb_v0[s0_index];
                
genvar i1;
generate
    for (i1 = 0; i1 < TLBNUM; i1 = i1 + 1) begin : gen_match1
        wire match1_vppn = (s1_vppn[18:9] == tlb_vppn[i1][18:9]);
        wire match1_vppn_ps4MB = (tlb_ps4MB[i1] || s1_vppn[8:0] == tlb_vppn[i1][8:0]);
        wire match1_asid = ((s1_asid == tlb_asid[i1]) || tlb_g[i1]);
        wire match1_enabled = tlb_e[i1];

        assign match1[i1] = match1_vppn && match1_vppn_ps4MB && match1_asid && match1_enabled;
    end
endgenerate

assign s1_found = |match1;
reg [2:0] s1_index_reg;

always @(*) begin
    s1_index_reg = 3'h0; // Default value
    casez (match1)
        8'b00000001: s1_index_reg = 3'h0;
        8'b0000001?: s1_index_reg = 3'h1;
        8'b000001??: s1_index_reg = 3'h2;
        8'b00001???: s1_index_reg = 3'h3;
        8'b0001????: s1_index_reg = 3'h4;
        8'b001?????: s1_index_reg = 3'h5;
        8'b01??????: s1_index_reg = 3'h6;
        8'b1???????: s1_index_reg = 3'h7;
        default: s1_index_reg = 3'h0;
    endcase
end

assign s1_index = s1_index_reg;
wire s1_select = s1_va_bit12 && !tlb_ps4MB[s1_index]  || s1_vppn[8] && tlb_ps4MB[s1_index];

assign s1_ppn = s1_select ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_ps  = tlb_ps4MB[s1_index] ? 6'h15 : 6'hc;
assign s1_plv = s1_select ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_mat = s1_select ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d   = s1_select ? tlb_d1[s1_index] : tlb_d0[s1_index];
assign s1_v   = s1_select ? tlb_v1[s1_index] : tlb_v0[s1_index];

//write logic

assign real_w_index = tlbfill ? rand_index : w_index;

always @(posedge clk) begin
    if(we) begin
        tlb_e[real_w_index]     <= w_e;
        tlb_ps4MB[real_w_index] <= w_ps == 6'h15 ? 1 : 0;
        tlb_vppn[real_w_index]  <= w_vppn;
        tlb_asid[real_w_index]  <= w_asid;
        tlb_g[real_w_index]     <= w_g;
        tlb_ppn0[real_w_index]  <= w_ppn0;
        tlb_plv0[real_w_index]  <= w_plv0;
        tlb_mat0[real_w_index]  <= w_mat0;
        tlb_d0[real_w_index]    <= w_d0;
        tlb_v0[real_w_index]    <= w_v0;
        tlb_ppn1[real_w_index]  <= w_ppn1;
        tlb_plv1[real_w_index]  <= w_plv1;
        tlb_mat1[real_w_index]  <= w_mat1;
        tlb_d1[real_w_index]    <= w_d1;
        tlb_v1[real_w_index]    <= w_v1;
    end
    else if(invtlb_valid)begin
        if(invtlb_cond[0]) tlb_e[0] <= 0;
        if(invtlb_cond[1]) tlb_e[1] <= 0;
        if(invtlb_cond[2]) tlb_e[2] <= 0;
        if(invtlb_cond[3]) tlb_e[3] <= 0;
        if(invtlb_cond[4]) tlb_e[4] <= 0;
        if(invtlb_cond[5]) tlb_e[5] <= 0;
        if(invtlb_cond[6]) tlb_e[6] <= 0;
        if(invtlb_cond[7]) tlb_e[7] <= 0;
    end
end

//read logic
assign r_e   = tlb_e[r_index];
assign r_vppn= tlb_vppn[r_index];
assign r_ps  = tlb_ps4MB[r_index] ? 6'h15 : 6'hc;
assign r_asid= tlb_asid[r_index];
assign r_g   = tlb_g[r_index];
assign r_ppn0= tlb_ppn0[r_index];
assign r_plv0= tlb_plv0[r_index];
assign r_mat0= tlb_mat0[r_index];
assign r_d0  = tlb_d0[r_index];
assign r_v0  = tlb_v0[r_index];
assign r_ppn1= tlb_ppn1[r_index];
assign r_plv1= tlb_plv1[r_index];
assign r_mat1= tlb_mat1[r_index];
assign r_d1  = tlb_d1[r_index];
assign r_v1  = tlb_v1[r_index];

//invtlb logic
//cond1
assign cond1[0] = ~tlb_g[0];
assign cond1[1] = ~tlb_g[1];
assign cond1[2] = ~tlb_g[2];
assign cond1[3] = ~tlb_g[3];
assign cond1[4] = ~tlb_g[4];
assign cond1[5] = ~tlb_g[5];
assign cond1[6] = ~tlb_g[6];
assign cond1[7] = ~tlb_g[7];

//cond2
assign cond2[0] = tlb_g[0];
assign cond2[1] = tlb_g[1];
assign cond2[2] = tlb_g[2];
assign cond2[3] = tlb_g[3];
assign cond2[4] = tlb_g[4];
assign cond2[5] = tlb_g[5];
assign cond2[6] = tlb_g[6];
assign cond2[7] = tlb_g[7];

//cond3 
assign cond3[0] = s1_asid==tlb_asid[0];
assign cond3[1] = s1_asid==tlb_asid[1];
assign cond3[2] = s1_asid==tlb_asid[2];
assign cond3[3] = s1_asid==tlb_asid[3];
assign cond3[4] = s1_asid==tlb_asid[4];
assign cond3[5] = s1_asid==tlb_asid[5];
assign cond3[6] = s1_asid==tlb_asid[6];
assign cond3[7] = s1_asid==tlb_asid[7];

//cond4
//修改查找逻辑
genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : gen_cond4
        assign cond4[i] = (s1_vppn[18: 9] == tlb_vppn[i][18: 9]) &&
                          (tlb_ps4MB[i] || s1_vppn[8:0] == tlb_vppn[i][8:0]);
    end
endgenerate

//invtlb_cond
assign invtlb_cond = invtlb_op == 5'b0 ? cond1 | cond2 :
                     invtlb_op == 5'b1 ? cond1 | cond2 :
                     invtlb_op == 5'h2 ? cond2         :
                     invtlb_op == 5'h3 ? cond1         :
                     invtlb_op == 5'h4 ? cond1 & cond3 :
                     invtlb_op == 5'h5 ? cond1 & cond3 & cond4:
                     invtlb_op == 5'h6 ? (cond2 | cond3) & cond4 :
                     16'h0;
endmodule
