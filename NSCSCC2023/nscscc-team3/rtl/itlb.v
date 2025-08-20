`include "header.v"
`include "tlb_header.v"
//4项直接映射L1 ITLB
module itlb
(
    input                               clk,
    input                               rst_n,
    input                               is_plv3,
    input                               clean,       //清除L1 TLB里的表项

    //write(refill) port
    input                               refill,      //重填L1 TLB里的表项
    input [`WIDTH_TLB_INDEX-1:0]        w_index,
    input [18:0]                        w_vppn,
    input                               w_ps,
    input [9:0]                         w_asid,
    input                               w_g,
    input [19:0]                        w_ppn0,
    input [1:0]                         w_plv0,
    input [1:0]                         w_mat0,
    input                               w_d0,
    input                               w_v0,
    input [19:0]                        w_ppn1,
    input [1:0]                         w_plv1,
    input [1:0]                         w_mat1,
    input                               w_d1,
    input                               w_v1,  
    
    input                               s_valid,            //valid为0说明不访问tlb，就不会产生例外
    input  [18:0]                       s_vppn,
    input                               s_va_bit12,
    input  [9:0]                        s_asid,
    output [`WIDTH_TLB_INDEX-1:0]       s_index,
    output [19:0]                       s_ppn,
    output [5:0]                        s_ps,
    output                              s_d,
    output                              s_v,
    output [1:0]                        s_mat,
    output [1:0]                        s_plv,
    output                              s_found,
    output                              s_ex
    
);
    reg               tlb_ps    [0:3];
    reg [18:0]        tlb_vppn  [0:3];
    reg               tlb_g     [0:3];  
    reg [9:0]         tlb_asid  [0:3];
    reg               tlb_e     [0:3];
    reg [19:0]        tlb_ppn0  [0:3];
    reg [1:0]         tlb_plv0  [0:3];
    reg [1:0]         tlb_mat0  [0:3];
    reg               tlb_d0    [0:3];
    reg               tlb_v0    [0:3];
    reg [19:0]        tlb_ppn1  [0:3];
    reg [1:0]         tlb_plv1  [0:3];
    reg [1:0]         tlb_mat1  [0:3];
    reg               tlb_d1    [0:3];
    reg               tlb_v1    [0:3];
    reg [`WIDTH_TLB_INDEX-1:0]         tlb_index [0:3];  //在L2TLB中的index
   
    
    
    
    /***********************************************************************/
    // 写端口
    /***********************************************************************/
    wire [1:0]        w_mapping_idx;         //直接映射的index
    //随便hash一下
    assign w_mapping_idx[0] = w_vppn[18] ^ w_vppn[16] ^ w_vppn[14] ^ w_vppn[12] ^ w_vppn[10] ^ w_asid[1];
    assign w_mapping_idx[1] = w_vppn[17] ^ w_vppn[15] ^ w_vppn[13] ^ w_vppn[11] ^ w_vppn[9]  ^ w_asid[0];
    always @(posedge clk)begin
        if(!rst_n)begin
            tlb_e[0] <= 0;
            tlb_e[1] <= 0;
            tlb_e[2] <= 0;
            tlb_e[3] <= 0;
        end else if(clean) begin
            tlb_e[0] <= 0;
            tlb_e[1] <= 0;
            tlb_e[2] <= 0;
            tlb_e[3] <= 0;
        end else if(refill)begin
            tlb_ps[w_mapping_idx]      <= w_ps;
            tlb_vppn[w_mapping_idx]    <= w_vppn;
            tlb_g[w_mapping_idx]       <= w_g;
            tlb_asid[w_mapping_idx]    <= w_asid;
            tlb_e[w_mapping_idx]       <= 1'b1;
            tlb_ppn0[w_mapping_idx]    <= w_ppn0;
            tlb_plv0[w_mapping_idx]    <= w_plv0;
            tlb_mat0[w_mapping_idx]    <= w_mat0;
            tlb_d0[w_mapping_idx]      <= w_d0;
            tlb_v0[w_mapping_idx]      <= w_v0;
            tlb_ppn1[w_mapping_idx]    <= w_ppn1;
            tlb_plv1[w_mapping_idx]    <= w_plv1;
            tlb_mat1[w_mapping_idx]    <= w_mat1;
            tlb_d1[w_mapping_idx]      <= w_d1;
            tlb_v1[w_mapping_idx]      <= w_v1;
            tlb_index[w_mapping_idx]   <= w_index;
        end
    end 
    /***********************************************************************/
    // 查询端口
    /***********************************************************************/
    wire [1:0]        s_mapping_idx;         //直接映射的index
    //随便hash一下
    assign s_mapping_idx[0] = s_vppn[18] ^ s_vppn[16] ^ s_vppn[14] ^ s_vppn[12] ^ s_vppn[10] ^ s_asid[1];
    assign s_mapping_idx[1] = s_vppn[17] ^ s_vppn[15] ^ s_vppn[13] ^ s_vppn[11] ^ s_vppn[9]  ^ s_asid[0];

    //例外通路
    wire    s_ex1_pe    [0:3];
    wire    s_ex0_pe    [0:3];
    wire    s_ex_pe     [0:3];
    genvar j;
    generate for(j = 0;j < 4; j=j+1) begin
        //* LUT6
        assign    s_ex1_pe[j]         = ~tlb_v1[j] | is_plv3 & ~tlb_plv1[j][0];
        assign    s_ex0_pe[j]         = ~tlb_v0[j] | is_plv3 & ~tlb_plv0[j][0];
        //* LUT5
        assign    s_ex_pe[j]          = (tlb_ps[j] ? s_vppn[8] : s_va_bit12) ? s_ex1_pe[j] : s_ex0_pe[j];
    end endgenerate
    

    
    //数据通路
    wire  [19:0]  s_ppn_pe          [0:3];
    wire  [1:0]   s_plv_pe          [0:3];
    wire  [1:0]   s_mat_pe          [0:3];
    wire          s_d_pe            [0:3];
    wire          s_v_pe            [0:3];
    wire  [5:0]   s_ps_pe           [0:3];
    wire          vppn_equal_4k_pe  [0:3];
    wire          vppn_equal_4m_pe  [0:3];
    wire          asid_equal_pe     [0:3];
    generate for(j = 0;j < 4; j=j+1) begin
        assign    s_ppn_pe[j]            = (tlb_ps[j] ? s_vppn[8] : s_va_bit12) ? tlb_ppn1[j] : tlb_ppn0[j];
        assign    s_plv_pe[j]            = (tlb_ps[j] ? s_vppn[8] : s_va_bit12) ? tlb_plv1[j] : tlb_plv0[j];
        assign    s_mat_pe[j]            = (tlb_ps[j] ? s_vppn[8] : s_va_bit12) ? tlb_mat1[j] : tlb_mat0[j];
        assign    s_d_pe[j]              = (tlb_ps[j] ? s_vppn[8] : s_va_bit12) ? tlb_d1[j] : tlb_d0[j];
        assign    s_v_pe[j]              = (tlb_ps[j] ? s_vppn[8] : s_va_bit12) ? tlb_v1[j] : tlb_v0[j];
        assign    s_ps_pe[j]             = tlb_ps[j] ? 6'd21:6'd12;
        assign    vppn_equal_4k_pe[j]    = s_vppn       == tlb_vppn[j];
        assign    vppn_equal_4m_pe[j]    = s_vppn[18:9] == tlb_vppn[j][18:9];
        assign    asid_equal_pe[j]       = s_asid       == tlb_asid[j];
    end endgenerate
    wire          vppn_equal_4k  ;
    wire          vppn_equal_4m  ;
    wire          asid_equal     ;
    wire          tlb_g_final    ;
    wire          tlb_ps_final   ;
    wire          tlb_e_final    ;
    //* 四选一
    assign  s_ex                = s_ex_pe[s_mapping_idx];
    assign  s_index             = tlb_index[s_mapping_idx];
    assign  s_ps                = s_ps_pe[s_mapping_idx];
    assign  s_ppn               = s_ppn_pe[s_mapping_idx];
    assign  s_plv               = s_plv_pe[s_mapping_idx];
    assign  s_mat               = s_mat_pe[s_mapping_idx];
    assign  s_d                 = s_d_pe[s_mapping_idx];
    assign  s_v                 = s_v_pe[s_mapping_idx];
    assign  vppn_equal_4k       = vppn_equal_4k_pe[s_mapping_idx];
    assign  vppn_equal_4m       = vppn_equal_4m_pe[s_mapping_idx];
    assign  tlb_g_final         = tlb_g[s_mapping_idx];
    assign  tlb_ps_final        = tlb_ps[s_mapping_idx];
    assign  tlb_e_final         = tlb_e[s_mapping_idx];
    assign  asid_equal          = asid_equal_pe[s_mapping_idx];
    assign  s_found             = (tlb_ps_final ? vppn_equal_4m : vppn_equal_4k) & (tlb_g_final | asid_equal) & tlb_e_final;
endmodule
