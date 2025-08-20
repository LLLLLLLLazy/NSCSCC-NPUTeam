`include "header.v"
`include "tlb_header.v"
//4项直接映射L1 DTLB
module dtlb
(
    input                               clk,
    input                               rst_n,
    input                               is_plv3,
    input                               clean,       //清除L1 TLB里的表项
    input                               stall_mem_to_wb,
    //write(refill) port
    input                               refill,
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
    input [4:0]                         dtlb_state,
    input                               s_is_tlbsrch,
    input                               s_valid,            //valid为0说明不访问tlb，就不会产生例外(来自PMEM级而不是EXE级)
    input                               s_is_ld_st_cacop2,
    input                               s_is_store,
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
    reg [`WIDTH_TLB_INDEX-1:0]          tlb_index [0:3];  //在L2TLB中的index
    reg                                 s_is_ld_st_cacop2_reg;
    reg                                 s_is_store_reg;
    reg    [18:0]                       s_vppn_reg;
    reg                                 s_va_bit12_reg;
    reg     [9:0]                       s_asid_reg;
    
    //在retry和正常路径之间选择
    wire                               s_is_ld_st_cacop2_real;
    wire                               s_is_store_real;
    wire  [18:0]                       s_vppn_real;
    wire                               s_va_bit12_real;
    wire  [9:0]                        s_asid_real;
    assign      s_is_ld_st_cacop2_real  = dtlb_state[`DTLB_SIDX_RETRY1] ? s_is_ld_st_cacop2_reg:s_is_ld_st_cacop2;
    assign      s_is_store_real         = dtlb_state[`DTLB_SIDX_RETRY1] ? s_is_store_reg:s_is_store;
    assign      s_vppn_real             = dtlb_state[`DTLB_SIDX_RETRY1] ? s_vppn_reg:s_vppn;
    assign      s_va_bit12_real         = dtlb_state[`DTLB_SIDX_RETRY1] ? s_va_bit12_reg:s_va_bit12;
    assign      s_asid_real             = dtlb_state[`DTLB_SIDX_RETRY1] ? s_asid_reg:s_asid;
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
    assign s_mapping_idx[0] = s_vppn_real[18] ^ s_vppn_real[16] ^ s_vppn_real[14] ^ s_vppn_real[12] ^ s_vppn_real[10] ^ s_asid_real[1];
    assign s_mapping_idx[1] = s_vppn_real[17] ^ s_vppn_real[15] ^ s_vppn_real[13] ^ s_vppn_real[11] ^ s_vppn_real[9]  ^ s_asid_real[0];

    //例外通路
    wire    s_ex1_pe    [0:3];
    wire    s_ex0_pe    [0:3];
    wire    s_ex_pe     [0:3];
    genvar j;
    generate for(j = 0;j < 4; j=j+1) begin
        //* LUT6
        assign    s_ex1_pe[j]         = (s_is_ld_st_cacop2_real & (~tlb_v1[j] | is_plv3 & ~tlb_plv1[j][0])) | (s_is_store_real & ~tlb_d1[j]);
        assign    s_ex0_pe[j]         = (s_is_ld_st_cacop2_real & (~tlb_v0[j] | is_plv3 & ~tlb_plv0[j][0])) | (s_is_store_real & ~tlb_d0[j]);
        //* LUT5
        assign    s_ex_pe[j]          = (tlb_ps[j] ? s_vppn_real[8] : s_va_bit12_real) ? s_ex1_pe[j] : s_ex0_pe[j];
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
        assign    s_ppn_pe[j]            = (tlb_ps[j] ? s_vppn_real[8] : s_va_bit12_real) ? tlb_ppn1[j] : tlb_ppn0[j];
        assign    s_plv_pe[j]            = (tlb_ps[j] ? s_vppn_real[8] : s_va_bit12_real) ? tlb_plv1[j] : tlb_plv0[j];
        assign    s_mat_pe[j]            = (tlb_ps[j] ? s_vppn_real[8] : s_va_bit12_real) ? tlb_mat1[j] : tlb_mat0[j];
        assign    s_d_pe[j]              = (tlb_ps[j] ? s_vppn_real[8] : s_va_bit12_real) ? tlb_d1[j] : tlb_d0[j];
        assign    s_v_pe[j]              = (tlb_ps[j] ? s_vppn_real[8] : s_va_bit12_real) ? tlb_v1[j] : tlb_v0[j];
        assign    s_ps_pe[j]             = tlb_ps[j] ? 6'd21:6'd12;
        assign    vppn_equal_4k_pe[j]    = s_vppn_real       == tlb_vppn[j];
        assign    vppn_equal_4m_pe[j]    = s_vppn_real[18:9] == tlb_vppn[j][18:9];
        assign    asid_equal_pe[j]       = s_asid_real       == tlb_asid[j];
    end endgenerate

    reg    [`WIDTH_TLB_INDEX-1:0]       s_index_reg;
    reg    [19:0]                       s_ppn_reg;
    reg    [5:0]                        s_ps_reg;
    reg                                 s_d_reg;
    reg                                 s_v_reg;
    reg    [1:0]                        s_mat_reg;
    reg    [1:0]                        s_plv_reg;
    reg                                 s_ex_reg;
    reg                                 vppn_equal_4k_reg;
    reg                                 vppn_equal_4m_reg;
    reg                                 tlb_g_final_reg;
    reg                                 tlb_ps_final_reg;
    reg                                 tlb_e_final_reg;
    reg                                 asid_equal_reg;
    //* 流水级寄存器
    always @(posedge clk) begin
        if((dtlb_state[`DTLB_SIDX_NORMAL] && !(s_valid && !s_found || stall_mem_to_wb )) 
         || dtlb_state[`DTLB_SIDX_RETRY1] 
         || dtlb_state[`DTLB_SIDX_RETRY2] && !stall_mem_to_wb
        ) begin
            s_index_reg                 <= tlb_index[s_mapping_idx];
            s_ppn_reg                   <= s_ppn_pe[s_mapping_idx];
            s_ps_reg                    <= s_ps_pe[s_mapping_idx];
            s_d_reg                     <= s_d_pe[s_mapping_idx];
            s_v_reg                     <= s_v_pe[s_mapping_idx];
            s_mat_reg                   <= s_mat_pe[s_mapping_idx];
            s_plv_reg                   <= s_plv_pe[s_mapping_idx];
            s_ex_reg                    <= s_ex_pe[s_mapping_idx];
            vppn_equal_4k_reg           <= vppn_equal_4k_pe[s_mapping_idx];
            vppn_equal_4m_reg           <= vppn_equal_4m_pe[s_mapping_idx];
            tlb_g_final_reg             <= tlb_g[s_mapping_idx];
            tlb_ps_final_reg            <= tlb_ps[s_mapping_idx];
            tlb_e_final_reg             <= tlb_e[s_mapping_idx];
            asid_equal_reg              <= asid_equal_pe[s_mapping_idx];
            s_is_ld_st_cacop2_reg       <= s_is_ld_st_cacop2_real;
            s_is_store_reg              <= s_is_store_real;
            s_vppn_reg                  <= s_vppn_real;
            s_va_bit12_reg              <= s_va_bit12_real;
            s_asid_reg                  <= s_asid_real;
        end
    end
    //* 四选一
    assign  s_ex                = s_ex_reg;
    assign  s_index             = s_index_reg;
    assign  s_ps                = s_ps_reg;
    assign  s_ppn               = s_ppn_reg;
    assign  s_plv               = s_plv_reg;
    assign  s_mat               = s_mat_reg;
    assign  s_d                 = s_d_reg;
    assign  s_v                 = s_v_reg;
    assign  s_found             = (tlb_ps_final_reg ? vppn_equal_4m_reg : vppn_equal_4k_reg) & (tlb_g_final_reg | asid_equal_reg) & tlb_e_final_reg;
endmodule
