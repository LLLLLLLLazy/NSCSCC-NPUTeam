`include "header.v"
`include "tlb_header.v"
module l2tlb
(
    input clk,
    input rst_n,
    //L1TLB状态
    input               [3:0]       itlb_state,
    input               [4:0]       dtlb_state,
    input                           stall_mem_to_wb,
    //ITLB通道
    input               [18:0]      s0_vppn,
    input               [9:0]       s0_asid,        
    output                          s0_found,
    output              [`WIDTH_TLB_INDEX-1:0]       s0_index,
    output                          s0_e,
    output                          s0_ps,
    output                          s0_g,
    output              [19:0]      s0_ppn0,
    output              [1:0]       s0_plv0,
    output              [1:0]       s0_mat0,
    output                          s0_d0,
    output                          s0_v0,
    output              [19:0]      s0_ppn1,
    output              [1:0]       s0_plv1,
    output              [1:0]       s0_mat1,
    output                          s0_d1,
    output                          s0_v1, 
  
    //DTLB通道
    input               [18:0]      s1_vppn,
    input               [9:0]       s1_asid,        
    output                          s1_found,
    output              [`WIDTH_TLB_INDEX-1:0]       s1_index,
    output                          s1_e,
    output                          s1_ps,
    output                          s1_g,
    output              [19:0]      s1_ppn0,
    output              [1:0]       s1_plv0,
    output              [1:0]       s1_mat0,
    output                          s1_d0,
    output                          s1_v0,
    output              [19:0]      s1_ppn1,
    output              [1:0]       s1_plv1,
    output              [1:0]       s1_mat1,
    output                          s1_d1,
    output                          s1_v1, 

    //invtlb通道
    input                           invtlb_valid,
    input               [4:0]       invtlb_op,
    input               [9:0]       invtlb_asid,
    input               [18:0]      invtlb_vppn,

    //写通道
    input                           we,
    input               [`WIDTH_TLB_INDEX-1:0]       w_index,
    input                           w_e,
    input               [18:0]      w_vppn,
    input               [5:0]       w_ps,
    input               [9:0]       w_asid,
    input                           w_g,
    input               [19:0]      w_ppn0,
    input               [1:0]       w_plv0,
    input               [1:0]       w_mat0,
    input                           w_d0,
    input                           w_v0,
    input               [19:0]      w_ppn1,
    input               [1:0]       w_plv1,
    input               [1:0]       w_mat1,
    input                           w_d1,
    input                           w_v1,  

    //读通道
    input               [`WIDTH_TLB_INDEX-1:0]       r_index,
    output reg                      r_e,
    output reg          [18:0]      r_vppn,
    output reg          [5:0]       r_ps,
    output reg          [9:0]       r_asid,
    output reg                      r_g,
    output reg          [19:0]      r_ppn0,
    output reg          [1:0]       r_plv0,
    output reg          [1:0]       r_mat0,
    output reg                      r_d0,
    output reg                      r_v0,
    output reg          [19:0]      r_ppn1,
    output reg          [1:0]       r_plv1,
    output reg          [1:0]       r_mat1,
    output reg                      r_d1,
    output reg                      r_v1
);

    reg [18:0] tlb_vppn [`TLBNUM-1:0];
    reg        tlb_ps   [`TLBNUM-1:0];
    reg        tlb_g    [`TLBNUM-1:0];  
    reg [9:0]  tlb_asid [`TLBNUM-1:0];
    reg        tlb_e    [`TLBNUM-1:0];
    reg [19:0] tlb_ppn0 [`TLBNUM-1:0];
    reg [1:0]  tlb_plv0 [`TLBNUM-1:0];
    reg [1:0]  tlb_mat0 [`TLBNUM-1:0];
    reg        tlb_d0   [`TLBNUM-1:0];
    reg        tlb_v0   [`TLBNUM-1:0];
    reg [19:0] tlb_ppn1 [`TLBNUM-1:0];
    reg [1:0]  tlb_plv1 [`TLBNUM-1:0];
    reg [1:0]  tlb_mat1 [`TLBNUM-1:0];
    reg        tlb_d1   [`TLBNUM-1:0];
    reg        tlb_v1   [`TLBNUM-1:0];

    //initialization and write
     
    reg [`TLBNUM-1:0] tlb_zero;
    genvar j;
    generate for(j = 0;j < `TLBNUM; j=j+1)begin
        always @(*) begin
            case(invtlb_op)
            5'h0:tlb_zero[j] = invtlb_valid;
            5'h1:tlb_zero[j] = invtlb_valid;
            5'h2:tlb_zero[j] = tlb_g[j] && invtlb_valid;
            5'h3:tlb_zero[j] = ~tlb_g[j] && invtlb_valid;
            5'h4:tlb_zero[j] = ~tlb_g[j] && tlb_asid[j] == invtlb_asid && invtlb_valid;
            5'h5:tlb_zero[j] = ~tlb_g[j] && tlb_asid[j] == invtlb_asid && tlb_vppn[j] == invtlb_vppn && invtlb_valid;
            5'h6:tlb_zero[j] = (tlb_g[j] || tlb_asid[j] == invtlb_asid) && tlb_vppn[j] == invtlb_vppn && invtlb_valid;
            default: tlb_zero[j] = 0;
            endcase
        end
    end endgenerate
    integer i;
    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_vppn[i] <= 0;
            else if (we && w_index == i)  tlb_vppn[i] <= w_vppn;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_ps[i] <= `PAGE_SIZE_4K;
            else if (we && w_index == i)  tlb_ps[i] <= (w_ps == 6'd21 ? `PAGE_SIZE_4M : `PAGE_SIZE_4K);
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_g[i] <= 0;
            else if (we && w_index == i)  tlb_g[i] <= w_g;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_asid[i] <= 0;
            else if (we && w_index == i)  tlb_asid[i] <= w_asid;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_e[i] <= 0;
            else if (we && w_index == i)  tlb_e[i] <= w_e;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_ppn0[i] <= 0;
            else if (we && w_index == i)  tlb_ppn0[i] <= w_ppn0;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_plv0[i] <= 0;
            else if (we && w_index == i)  tlb_plv0[i] <= w_plv0;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_mat0[i] <= 0;
            else if (we && w_index == i)  tlb_mat0[i] <= w_mat0;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_d0[i] <= 0;
            else if (we && w_index == i)  tlb_d0[i] <= w_d0;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_v0[i] <= 0;
            else if (we && w_index == i)  tlb_v0[i] <= w_v0;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_ppn1[i] <= 0;
            else if (we && w_index == i)  tlb_ppn1[i] <= w_ppn1;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_plv1[i] <= 0;
            else if (we && w_index == i)  tlb_plv1[i] <= w_plv1;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_mat1[i] <= 0;
            else if (we && w_index == i)  tlb_mat1[i] <= w_mat1;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_d1[i] <= 0;
            else if (we && w_index == i)  tlb_d1[i] <= w_d1;
        end
    end

    always @(posedge clk) begin
        for(i = 0;i < `TLBNUM; i=i+1)begin
            if(tlb_zero[i]) tlb_v1[i] <= 0;
            else if (we && w_index == i)  tlb_v1[i] <= w_v1;
        end
    end
    
    /* * search port0 */
    wire [`TLBNUM-1:0] match0;
    generate for(j = 0;j < `TLBNUM; j=j+1)begin
        assign  match0[j] =  (tlb_ps[j] ? (s0_vppn[18:9] == tlb_vppn[j][18:9]) : (s0_vppn == tlb_vppn[j]))   && (tlb_g[j] || s0_asid == tlb_asid[j]) && tlb_e[j];
    end endgenerate
    
    wire [`WIDTH_TLB_INDEX-1:0] s0_index_pre;
    wire s0_found_pre = |match0;
    assign s0_index_pre[0] = match0[1]  | match0[3]  | match0[5]  | match0[7]  | match0[9]  | match0[11] | match0[13] | match0[15];
    assign s0_index_pre[1] = match0[2]  | match0[3]  | match0[6]  | match0[7]  | match0[10] | match0[11] | match0[14] | match0[15];
    assign s0_index_pre[2] = match0[4]  | match0[5]  | match0[6]  | match0[7]  | match0[12] | match0[13] | match0[14] | match0[15];
    assign s0_index_pre[3] = match0[8]  | match0[9]  | match0[10] | match0[11] | match0[12] | match0[13] | match0[14] | match0[15];

    //插入流水线寄存器
    reg                          s0_found_reg;
    reg  [`WIDTH_TLB_INDEX-1:0]  s0_index_reg;
    reg                          s0_e_reg;
    reg                          s0_ps_reg;
    reg                          s0_g_reg;
    reg              [19:0]      s0_ppn0_reg;
    reg              [1:0]       s0_plv0_reg;
    reg              [1:0]       s0_mat0_reg;
    reg                          s0_d0_reg;
    reg                          s0_v0_reg;
    reg              [19:0]      s0_ppn1_reg;
    reg              [1:0]       s0_plv1_reg;
    reg              [1:0]       s0_mat1_reg;
    reg                          s0_d1_reg;
    reg                          s0_v1_reg;
    always @(posedge clk) begin
        if(itlb_state[`ITLB_SIDX_NORMAL]) begin
            s0_found_reg                <= s0_found_pre;
            s0_index_reg                <= s0_index_pre;
            s0_g_reg                    <= tlb_g[s0_index_pre];
            s0_ppn0_reg                 <= tlb_ppn0[s0_index_pre];
            s0_plv0_reg                 <= tlb_plv0[s0_index_pre];
            s0_mat0_reg                 <= tlb_mat0[s0_index_pre];
            s0_d0_reg                   <= tlb_d0[s0_index_pre];
            s0_v0_reg                   <= tlb_v0[s0_index_pre];
            s0_ppn1_reg                 <= tlb_ppn1[s0_index_pre];
            s0_plv1_reg                 <= tlb_plv1[s0_index_pre];
            s0_mat1_reg                 <= tlb_mat1[s0_index_pre];
            s0_d1_reg                   <= tlb_d1[s0_index_pre];
            s0_v1_reg                   <= tlb_v1[s0_index_pre];
            s0_e_reg                    <= tlb_e[s0_index_pre];
            s0_ps_reg                   <= tlb_ps[s0_index_pre];
        end
    end
    assign s0_found = s0_found_reg;
    assign s0_index = s0_index_reg;
    assign s0_g     = s0_g_reg;
    assign s0_ppn0  = s0_ppn0_reg;
    assign s0_plv0  = s0_plv0_reg;
    assign s0_mat0  = s0_mat0_reg;
    assign s0_d0    = s0_d0_reg;
    assign s0_v0    = s0_v0_reg;
    assign s0_ppn1  = s0_ppn1_reg;
    assign s0_plv1  = s0_plv1_reg;
    assign s0_mat1  = s0_mat1_reg;
    assign s0_d1    = s0_d1_reg;
    assign s0_v1    = s0_v1_reg;
    assign s0_e     = s0_e_reg;
    assign s0_ps    = s0_ps_reg;
    
    /* * search port1 */
    wire [`TLBNUM-1:0] match1;
    generate for(j = 0;j < `TLBNUM; j=j+1)begin
        assign  match1[j] =  (tlb_ps[j] ? (s1_vppn[18:9] == tlb_vppn[j][18:9]) : (s1_vppn == tlb_vppn[j]))   && (tlb_g[j] || s1_asid == tlb_asid[j]) && tlb_e[j];
    end endgenerate
    
    wire [`WIDTH_TLB_INDEX-1:0] s1_index_pre;
    wire s1_found_pre = |match1;
    assign s1_index_pre[0] = match1[1]  | match1[3]  | match1[5]  | match1[7]  | match1[9]  | match1[11] | match1[13] | match1[15];
    assign s1_index_pre[1] = match1[2]  | match1[3]  | match1[6]  | match1[7]  | match1[10] | match1[11] | match1[14] | match1[15];
    assign s1_index_pre[2] = match1[4]  | match1[5]  | match1[6]  | match1[7]  | match1[12] | match1[13] | match1[14] | match1[15];
    assign s1_index_pre[3] = match1[8]  | match1[9]  | match1[10] | match1[11] | match1[12] | match1[13] | match1[14] | match1[15];

    //插入流水线寄存器
    reg                          s1_found_reg;
    reg  [`WIDTH_TLB_INDEX-1:0]  s1_index_reg;
    reg                          s1_e_reg;
    reg                          s1_ps_reg;
    reg                          s1_g_reg;
    reg              [19:0]      s1_ppn0_reg;
    reg              [1:0]       s1_plv0_reg;
    reg              [1:0]       s1_mat0_reg;
    reg                          s1_d0_reg;
    reg                          s1_v0_reg;
    reg              [19:0]      s1_ppn1_reg;
    reg              [1:0]       s1_plv1_reg;
    reg              [1:0]       s1_mat1_reg;
    reg                          s1_d1_reg;
    reg                          s1_v1_reg;
    always @(posedge clk) begin
        if(dtlb_state[`DTLB_SIDX_NORMAL]) begin
            s1_found_reg                <= s1_found_pre;
            s1_index_reg                <= s1_index_pre;
            s1_g_reg                    <= tlb_g[s1_index_pre];
            s1_ppn0_reg                 <= tlb_ppn0[s1_index_pre];
            s1_plv0_reg                 <= tlb_plv0[s1_index_pre];
            s1_mat0_reg                 <= tlb_mat0[s1_index_pre];
            s1_d0_reg                   <= tlb_d0[s1_index_pre];
            s1_v0_reg                   <= tlb_v0[s1_index_pre];
            s1_ppn1_reg                 <= tlb_ppn1[s1_index_pre];
            s1_plv1_reg                 <= tlb_plv1[s1_index_pre];
            s1_mat1_reg                 <= tlb_mat1[s1_index_pre];
            s1_d1_reg                   <= tlb_d1[s1_index_pre];
            s1_v1_reg                   <= tlb_v1[s1_index_pre];
            s1_e_reg                    <= tlb_e[s1_index_pre];
            s1_ps_reg                   <= tlb_ps[s1_index_pre];
        end
    end
    assign s1_found = s1_found_reg;
    assign s1_index = s1_index_reg;
    assign s1_g     = s1_g_reg;
    assign s1_ppn0  = s1_ppn0_reg;
    assign s1_plv0  = s1_plv0_reg;
    assign s1_mat0  = s1_mat0_reg;
    assign s1_d0    = s1_d0_reg;
    assign s1_v0    = s1_v0_reg;
    assign s1_ppn1  = s1_ppn1_reg;
    assign s1_plv1  = s1_plv1_reg;
    assign s1_mat1  = s1_mat1_reg;
    assign s1_d1    = s1_d1_reg;
    assign s1_v1    = s1_v1_reg;
    assign s1_e     = s1_e_reg;
    assign s1_ps    = s1_ps_reg;


    // read port
    always @(*) begin
        r_vppn  = tlb_vppn[r_index];
        r_asid  = tlb_asid[r_index];
        r_g     = tlb_g[r_index];
        r_ppn0  = tlb_ppn0[r_index];
        r_plv0  = tlb_plv0[r_index];
        r_mat0  = tlb_mat0[r_index];
        r_d0    = tlb_d0[r_index];
        r_v0    = tlb_v0[r_index];
        r_ppn1  = tlb_ppn1[r_index];
        r_plv1  = tlb_plv1[r_index];
        r_mat1  = tlb_mat1[r_index];
        r_d1    = tlb_d1[r_index];
        r_v1    = tlb_v1[r_index];
        r_e     = tlb_e[r_index];
        r_ps    = tlb_ps[r_index] ? 6'd21 : 6'd12;
    end

endmodule
