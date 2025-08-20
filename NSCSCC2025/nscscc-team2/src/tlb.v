module tlb
#(
    parameter TLBNUM = 32
)
(
    input  wire                        clk,
    input  wire                        reset,

    // search port 0 (for fetch)
    input  wire [18:0]                 s0_vppn,     // 访存虚地址的31..13位
    input  wire                        s0_va_bit12, // 访存虚地址的12位
    input  wire [9:0]                  s0_asid,     // CSR.ASID的ASID域
    output reg  [19:0]                 s0_va_20,    
    output reg                         s0_found,
    output reg  [$clog2(TLBNUM)-1:0]   s0_index,
    output reg  [19:0]                 s0_ppn,      
    output reg  [5:0]                  s0_ps,       
    output reg  [1:0]                  s0_plv,
    output reg  [1:0]                  s0_mat,
    output reg                         s0_d,
    output reg                         s0_v,

    // search port 1 (for load/store)
    input  wire [18:0]                 s1_vppn,
    input  wire                        s1_va_bit12,
    input  wire [9:0]                  s1_asid,
    output wire                        s1_found,
    output wire [$clog2(TLBNUM)-1:0]   s1_index,
    output wire [19:0]                 s1_ppn,
    output wire [5:0]                  s1_ps,
    output wire [1:0]                  s1_plv,
    output wire [1:0]                  s1_mat,
    output wire                        s1_d,
    output wire                        s1_v,

    // search port 2 (for TLBSRCH)
    input  wire [18:0]                 s2_vppn,
    input  wire                        s2_va_bit12,
    input  wire [9:0]                  s2_asid,
    output wire                        s2_found,
    output wire [$clog2(TLBNUM)-1:0]   s2_index,

    // search port 3 (for INVTLB)
    input  wire [18:0]                 s3_vppn,
    input  wire                        s3_va_bit12,
    input  wire [9:0]                  s3_asid,

    // invtlb opcode
    input  wire                        invtlb_valid,
    input  wire [4:0]                  invtlb_op,

    // write port
    input  wire                        we, // write enable
    input  wire [$clog2(TLBNUM)-1:0]   w_index,
    input  wire                        w_e,
    input  wire [18:0]                 w_vppn,
    input  wire [5:0]                  w_ps,
    input  wire [9:0]                  w_asid,
    input  wire                        w_g,
    input  wire [19:0]                 w_ppn0,
    input  wire [1:0]                  w_plv0,
    input  wire [1:0]                  w_mat0,
    input  wire                        w_d0,
    input  wire                        w_v0,
    input  wire [19:0]                 w_ppn1,
    input  wire [1:0]                  w_plv1,
    input  wire [1:0]                  w_mat1,
    input  wire                        w_d1,
    input  wire                        w_v1,

    // read port
    input  wire [$clog2(TLBNUM)-1:0]   r_index,
    output wire                        r_e,
    output wire [18:0]                 r_vppn,
    output wire [5:0]                  r_ps,
    output wire [9:0]                  r_asid,
    output wire                        r_g,
    output wire [19:0]                 r_ppn0,
    output wire [1:0]                  r_plv0,
    output wire [1:0]                  r_mat0,
    output wire                        r_d0,
    output wire                        r_v0,
    output wire [19:0]                 r_ppn1,
    output wire [1:0]                  r_plv1,
    output wire [1:0]                  r_mat1,
    output wire                        r_d1,
    output wire                        r_v1
);

genvar  i;

wire  [19:0]                 temp_s0_va_20;
wire                         temp_s0_found;
wire  [$clog2(TLBNUM)-1:0]   temp_s0_index;
wire  [19:0]                 temp_s0_ppn;
wire  [5:0]                  temp_s0_ps;
wire  [1:0]                  temp_s0_plv;
wire  [1:0]                  temp_s0_mat;
wire                         temp_s0_d;
wire                         temp_s0_v;

// 既参与读写又参与查找比较
reg                     tlb_e     [TLBNUM-1:0];
reg                     tlb_ps4MB [TLBNUM-1:0]; // pagesize 1:4MB, 0:4KB
reg [18:0]              tlb_vppn  [TLBNUM-1:0];
reg [9:0]               tlb_asid  [TLBNUM-1:0];
reg                     tlb_g     [TLBNUM-1:0];

// 仅参与读写 
reg [19:0]              tlb_ppn0  [TLBNUM-1:0];
reg [1:0]               tlb_plv0  [TLBNUM-1:0];
reg [1:0]               tlb_mat0  [TLBNUM-1:0];
reg                     tlb_d0    [TLBNUM-1:0];
reg                     tlb_v0    [TLBNUM-1:0];

// 仅参与读写 
reg [19:0]              tlb_ppn1  [TLBNUM-1:0];
reg [1:0]               tlb_plv1  [TLBNUM-1:0];
reg [1:0]               tlb_mat1  [TLBNUM-1:0];
reg                     tlb_d1    [TLBNUM-1:0];
reg                     tlb_v1    [TLBNUM-1:0];

wire   [TLBNUM-1:0]     match0   ;
wire   [TLBNUM-1:0]     match1   ;
wire   [TLBNUM-1:0]     match2   ;

// search port 0 (for fetch)
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : gen_match0
        assign match0[i] = tlb_e[i]
            && (s0_vppn[18:9] == tlb_vppn[i][18:9])
            && (tlb_ps4MB[i] || (s0_vppn[8:0] == tlb_vppn[i][8:0]))
            && ((s0_asid == tlb_asid[i]) || tlb_g[i]);
    end
endgenerate

assign temp_s0_found = |match0;
encoder_32_5 u_encoder_32_5_0(.in(match0), .out(temp_s0_index)); 

assign temp_s0_ps  = tlb_ps4MB[temp_s0_index]? 6'b010101 : 6'b001100; // 4MB: 010101, 4KB: 001100

assign temp_s0_ppn = tlb_ps4MB[temp_s0_index]? (s0_vppn[8]? tlb_ppn1[temp_s0_index] : tlb_ppn0[temp_s0_index]) : (s0_va_bit12 ? tlb_ppn1[temp_s0_index] : tlb_ppn0[temp_s0_index]) ;

assign temp_s0_plv = tlb_ps4MB[temp_s0_index]? (s0_vppn[8]? tlb_plv1[temp_s0_index] : tlb_plv0[temp_s0_index]) : (s0_va_bit12 ? tlb_plv1[temp_s0_index] : tlb_plv0[temp_s0_index]) ;

assign temp_s0_mat = tlb_ps4MB[temp_s0_index]? (s0_vppn[8]? tlb_mat1[temp_s0_index] : tlb_mat0[temp_s0_index]) : (s0_va_bit12 ? tlb_mat1[temp_s0_index] : tlb_mat0[temp_s0_index]) ;

assign temp_s0_d   = tlb_ps4MB[temp_s0_index]? (s0_vppn[8]? tlb_d1[temp_s0_index]   : tlb_d0[temp_s0_index])   : (s0_va_bit12 ? tlb_d1[temp_s0_index]   : tlb_d0[temp_s0_index])   ;

assign temp_s0_v   = tlb_ps4MB[temp_s0_index]? (s0_vppn[8]? tlb_v1[temp_s0_index]   : tlb_v0[temp_s0_index])   : (s0_va_bit12 ? tlb_v1[temp_s0_index]   : tlb_v0[temp_s0_index])   ;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        s0_va_20 <= 20'b0;
        s0_found <= 1'b0;
        s0_index <= 5'b0;
        s0_ppn   <= 20'b0;
        s0_ps    <= 6'b0;
        s0_plv   <= 2'b0;
        s0_mat   <= 2'b0;
        s0_d     <= 1'b0;
        s0_v     <= 1'b0;
    end
    else begin
        s0_va_20 <= {s0_vppn, s0_va_bit12};
        s0_found <= temp_s0_found ;
        s0_index <= temp_s0_index ;
        s0_ppn   <= temp_s0_ppn   ;
        s0_ps    <= temp_s0_ps    ;
        s0_plv   <= temp_s0_plv   ;
        s0_mat   <= temp_s0_mat   ;
        s0_d     <= temp_s0_d     ;
        s0_v     <= temp_s0_v     ;
    end
end

// search port 1 (for load/store)
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : gen_match1
        assign match1[i] = tlb_e[i]
            && (s1_vppn[18:9] == tlb_vppn[i][18:9])
            && (tlb_ps4MB[i] || (s1_vppn[8:0] == tlb_vppn[i][8:0]))
            && ((s1_asid == tlb_asid[i]) || tlb_g[i]);
    end
endgenerate

assign s1_found = |match1;
encoder_32_5 u_encoder_32_5_1(.in(match1), .out(s1_index));

assign s1_ps  = tlb_ps4MB[s1_index]? 6'b010101 : 6'b001100; // 4MB: 010101, 4KB: 001100

assign s1_ppn = tlb_ps4MB[s1_index]? (s1_vppn[8]? tlb_ppn1[s1_index] : tlb_ppn0[s1_index]) : (s1_va_bit12 ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index]);

assign s1_plv = tlb_ps4MB[s1_index]? (s1_vppn[8]? tlb_plv1[s1_index] : tlb_plv0[s1_index]) : (s1_va_bit12 ? tlb_plv1[s1_index] : tlb_plv0[s1_index]);

assign s1_mat = tlb_ps4MB[s1_index]? (s1_vppn[8]? tlb_mat1[s1_index] : tlb_mat0[s1_index]) : (s1_va_bit12 ? tlb_mat1[s1_index] : tlb_mat0[s1_index]);

assign s1_d   = tlb_ps4MB[s1_index]? (s1_vppn[8]? tlb_d1[s1_index]   : tlb_d0[s1_index])   : (s1_va_bit12 ? tlb_d1[s1_index]   : tlb_d0[s1_index]);

assign s1_v   = tlb_ps4MB[s1_index]? (s1_vppn[8]? tlb_v1[s1_index]   : tlb_v0[s1_index])   : (s1_va_bit12 ? tlb_v1[s1_index]   : tlb_v0[s1_index]);

// search port 2 (for TLBSRCH)
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : gen_match2
        assign match2[i] = tlb_e[i]
            && (s2_vppn[18:9] == tlb_vppn[i][18:9])
            && (tlb_ps4MB[i] || (s2_vppn[8:0] == tlb_vppn[i][8:0]))
            && ((s2_asid == tlb_asid[i]) || tlb_g[i]);
    end
endgenerate

assign s2_found = |match2;
encoder_32_5 u_encoder_32_5_2(.in(match2), .out(s2_index));

// search port 3 (for INVTLB)
// nothing. In fact it's not a SEARCH port

// read 
assign r_e     = tlb_e[r_index];
assign r_vppn  = tlb_vppn[r_index];
assign r_ps    = tlb_ps4MB[r_index]? 6'b010101 : 6'b001100; // 4MB: 010101, 4KB: 001100
assign r_asid  = tlb_asid[r_index];
assign r_g     = tlb_g[r_index];
assign r_ppn0  = tlb_ppn0[r_index];
assign r_plv0  = tlb_plv0[r_index];
assign r_mat0  = tlb_mat0[r_index];
assign r_d0    = tlb_d0[r_index];
assign r_v0    = tlb_v0[r_index];
assign r_ppn1  = tlb_ppn1[r_index];
assign r_plv1  = tlb_plv1[r_index];
assign r_mat1  = tlb_mat1[r_index];
assign r_d1    = tlb_d1[r_index];
assign r_v1    = tlb_v1[r_index];

// write
always @(posedge clk) begin
    if (we) begin
        tlb_vppn[w_index]  <= w_vppn;
        tlb_ps4MB[w_index] <= w_ps[0];
        tlb_asid[w_index]  <= w_asid;
        tlb_g[w_index]     <= w_g;
        tlb_ppn0[w_index]  <= w_ppn0;
        tlb_plv0[w_index]  <= w_plv0;
        tlb_mat0[w_index]  <= w_mat0;
        tlb_d0[w_index]    <= w_d0;
        tlb_v0[w_index]    <= w_v0;
        tlb_ppn1[w_index]  <= w_ppn1;
        tlb_plv1[w_index]  <= w_plv1;
        tlb_mat1[w_index]  <= w_mat1;
        tlb_d1[w_index]    <= w_d1;
        tlb_v1[w_index]    <= w_v1;
    end
end

// invtlb
generate 
    for (i = 0; i < TLBNUM; i = i + 1) 
        begin: invtlb 
            always @(posedge clk) begin
                if (we && (w_index == i)) begin
                    tlb_e[i] <= w_e;
                end
                else if (invtlb_valid) begin
                    if (invtlb_op == 5'd0 || invtlb_op == 5'd1) begin
                        tlb_e[i] <= 1'b0;
                    end
                    else if (invtlb_op == 5'd2) begin
                        if (tlb_g[i]) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (invtlb_op == 5'd3) begin
                        if (!tlb_g[i]) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (invtlb_op == 5'd4) begin
                        if (!tlb_g[i] && (tlb_asid[i] == s3_asid)) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (invtlb_op == 5'd5) begin
                        if (!tlb_g[i] && (tlb_asid[i] == s3_asid) && 
                           ((!tlb_ps4MB[i]) ? (tlb_vppn[i] == s3_vppn) : (tlb_vppn[i][18:9] == s3_vppn[18:9]))) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (invtlb_op == 5'd6) begin
                        if ((tlb_g[i] || (tlb_asid[i] == s3_asid)) && 
                           ((!tlb_ps4MB[i]) ? (tlb_vppn[i] == s3_vppn) : (tlb_vppn[i][18:9] == s3_vppn[18:9]))) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                end
            end
        end 
endgenerate

endmodule