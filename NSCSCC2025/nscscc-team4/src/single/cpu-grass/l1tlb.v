module l1tlb
#
(
    parameter TLBNUM = 16
)
(
    input                               clk,
    input                               reset,
    input                               clean,       

    //write(refill) port
    input                               refill,      
    input [$clog2(TLBNUM)-1:0]          w_index,
    input [18:0]                        w_vppn,
    input [ 5:0]                        w_ps,
    input [ 9:0]                        w_asid,
    input                               w_g,
    input [19:0]                        w_ppn0,
    input [ 1:0]                        w_plv0,
    input [ 1:0]                        w_mat0,
    input                               w_d0,
    input                               w_v0,
    input [19:0]                        w_ppn1,
    input [ 1:0]                        w_plv1,
    input [ 1:0]                        w_mat1,
    input                               w_d1,
    input                               w_v1,  
    
    input                               s_valid,            
    input  [18:0]                       s_vppn,
    input                               s_odd_page,
    input  [ 9:0]                       s_asid,
    output [$clog2(TLBNUM)-1:0]         s_index,
    output [19:0]                       s_ppn,
    output [ 5:0]                       s_ps,
    output                              s_d,
    output                              s_v,
    output [ 1:0]                       s_mat,
    output [ 1:0]                       s_plv,
    output                              s_found   
);
    // tlb
    reg [ 5:0]                       tlb_ps    [3:0];
    reg [18:0]                       tlb_vppn  [3:0];
    reg                              tlb_g     [3:0];  
    reg [ 9:0]                       tlb_asid  [3:0];
    reg                              tlb_e     [3:0];
    reg [19:0]                       tlb_ppn0  [3:0];
    reg [ 1:0]                       tlb_plv0  [3:0];
    reg [ 1:0]                       tlb_mat0  [3:0];
    reg                              tlb_d0    [3:0];
    reg                              tlb_v0    [3:0];
    reg [19:0]                       tlb_ppn1  [3:0];
    reg [ 1:0]                       tlb_plv1  [3:0];
    reg [ 1:0]                       tlb_mat1  [3:0];
    reg                              tlb_d1    [3:0];
    reg                              tlb_v1    [3:0];
    reg [$clog2(TLBNUM)-1:0]         tlb_index [3:0];

    // write
    wire [1:0]        w_hash_index;         

    assign w_hash_index[0] = w_vppn[18] ^ w_vppn[16] ^ w_vppn[14] ^ w_vppn[12] ^ w_vppn[10] ^ w_asid[1];
    assign w_hash_index[1] = w_vppn[17] ^ w_vppn[15] ^ w_vppn[13] ^ w_vppn[11] ^ w_vppn[9]  ^ w_asid[0];
    always @(posedge clk)begin
        if(reset || clean)begin
            tlb_e[0] <= 1'b0;
            tlb_e[1] <= 1'b0;
            tlb_e[2] <= 1'b0;
            tlb_e[3] <= 1'b0;
        end 
        else if(refill)begin
            tlb_ps[w_hash_index]      <= w_ps;
            tlb_vppn[w_hash_index]    <= w_vppn;
            tlb_g[w_hash_index]       <= w_g;
            tlb_asid[w_hash_index]    <= w_asid;
            tlb_e[w_hash_index]       <= 1'b1;
            tlb_ppn0[w_hash_index]    <= w_ppn0;
            tlb_plv0[w_hash_index]    <= w_plv0;
            tlb_mat0[w_hash_index]    <= w_mat0;
            tlb_d0[w_hash_index]      <= w_d0;
            tlb_v0[w_hash_index]      <= w_v0;
            tlb_ppn1[w_hash_index]    <= w_ppn1;
            tlb_plv1[w_hash_index]    <= w_plv1;
            tlb_mat1[w_hash_index]    <= w_mat1;
            tlb_d1[w_hash_index]      <= w_d1;
            tlb_v1[w_hash_index]      <= w_v1;
            tlb_index[w_hash_index]   <= w_index;
        end
    end

    // search
    wire [1:0]        s_hash_index;         

    assign s_hash_index[0] = s_vppn[18] ^ s_vppn[16] ^ s_vppn[14] ^ s_vppn[12] ^ s_vppn[10] ^ s_asid[1];
    assign s_hash_index[1] = s_vppn[17] ^ s_vppn[15] ^ s_vppn[13] ^ s_vppn[11] ^ s_vppn[9]  ^ s_asid[0];

    wire  [19:0]  s_ppn_pe          [3:0];
    wire  [1:0]   s_plv_pe          [3:0];
    wire  [1:0]   s_mat_pe          [3:0];
    wire          s_d_pe            [3:0];
    wire          s_v_pe            [3:0];
    wire  [5:0]   s_ps_pe           [3:0];
    wire          tlb_ps4k_pe       [3:0];
    wire          tlb_ps4m_pe       [3:0];
    wire          asid_equal_pe     [3:0];
    wire          s_odd_page_buffer [3:0];

    genvar j;
    generate 
        for (j = 0; j < 4; j = j + 1)
        begin: tlb_match
            assign s_odd_page_buffer[j] = (tlb_ps[j] == 6'd12) ? s_odd_page : s_vppn[8];
            assign s_ppn_pe[j]          = s_odd_page_buffer[j] ? tlb_ppn1[j] : tlb_ppn0[j];
            assign s_plv_pe[j]          = s_odd_page_buffer[j] ? tlb_plv1[j] : tlb_plv0[j];
            assign s_mat_pe[j]          = s_odd_page_buffer[j] ? tlb_mat1[j] : tlb_mat0[j];
            assign s_d_pe[j]            = s_odd_page_buffer[j] ? tlb_d1[j]   : tlb_d0[j];
            assign s_v_pe[j]            = s_odd_page_buffer[j] ? tlb_v1[j]   : tlb_v0[j];
            assign s_ps_pe[j]           = tlb_ps[j];

            assign tlb_ps4k_pe[j]   = (tlb_ps[j] == 6'd12) ? (s_vppn == tlb_vppn[j]) : 1'b0;
            assign tlb_ps4m_pe[j]   = (tlb_ps[j] == 6'd21) ? (s_vppn[18:9] == tlb_vppn[j][18:9]) : 1'b0;
            assign asid_equal_pe[j] = (s_asid == tlb_asid[j]);
        end 
    endgenerate

    wire          tlb_ps4k  ;
    wire          tlb_ps4m  ;
    wire          asid_equal     ;
    wire          tlb_g_final    ;
    wire          tlb_ps_final   ;
    wire          tlb_e_final    ;

    assign  s_index             = tlb_index[s_hash_index];
    assign  s_ps                = s_ps_pe[s_hash_index];
    assign  s_ppn               = s_ppn_pe[s_hash_index];
    assign  s_plv               = s_plv_pe[s_hash_index];
    assign  s_mat               = s_mat_pe[s_hash_index];
    assign  s_d                 = s_d_pe[s_hash_index];
    assign  s_v                 = s_v_pe[s_hash_index];
    assign  tlb_ps4k            = tlb_ps4k_pe[s_hash_index];
    assign  tlb_ps4m            = tlb_ps4m_pe[s_hash_index];
    assign  tlb_g_final         = tlb_g[s_hash_index];
    assign  tlb_ps_final        = (tlb_ps[s_hash_index] == 6'd21);
    assign  tlb_e_final         = tlb_e[s_hash_index];
    assign  asid_equal          = asid_equal_pe[s_hash_index];
    assign  s_found             = (tlb_ps_final ? tlb_ps4m : tlb_ps4k) & (tlb_g_final | asid_equal) & tlb_e_final;

endmodule