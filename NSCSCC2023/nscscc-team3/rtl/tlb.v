`include "header.v"
`include "tlb_header.v"
module tlb
(
    input clk,
    input rst_n,
    input                           is_plv3,
    input                           flush_pif,
    input                           stall_if_to_wb,
    input                           stall_mem_to_wb,
    //search port 0 取指
    input                           need_visit_itlb,
    input               [18:0]      s0_vppn,
    input                           s0_va_bit12,
    input               [9:0]       s0_asid,
    output                          s0_found,
    output              [`WIDTH_TLB_INDEX-1:0]       s0_index,
    output              [19:0]      s0_ppn,
    output              [5:0]       s0_ps,
    output                          s0_d,
    output                          s0_v,
    output              [1:0]       s0_mat,
    output              [1:0]       s0_plv,
    output                          s0_ex,                      //! 例外不包含TLBR
    output                          s0_stall,
    //search port 1 load\store\tlbsrch
    input                           s1_is_tlbsrch,
    input                           need_visit_dtlb,
    input                           s1_is_ld_st_cacop2,
    input                           s1_is_store,
    input               [18:0]      s1_vppn,
    input                           s1_va_bit12,
    input               [9:0]       s1_asid,        
    output                          s1_found,
    output              [`WIDTH_TLB_INDEX-1:0]       s1_index,
    output              [19:0]      s1_ppn,
    output              [5:0]       s1_ps,
    output                          s1_d,
    output                          s1_v,
    output              [1:0]       s1_mat,
    output              [1:0]       s1_plv,
    output                          s1_ex,                      //! 例外不包含TLBR
    output                          s1_stall,               
    input                           invtlb_valid,
    input               [4:0]       invtlb_op,
    input               [9:0]       invtlb_asid,
    input               [18:0]      invtlb_vppn,

    //write port
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

    //read port
    input  [`WIDTH_TLB_INDEX-1:0]   r_index,
    output                          r_e,
    output              [18:0]      r_vppn,
    output              [5:0]       r_ps,
    output              [9:0]       r_asid,
    output                          r_g,
    output              [19:0]      r_ppn0,
    output              [1:0]       r_plv0,
    output              [1:0]       r_mat0,
    output                          r_d0,
    output                          r_v0,
    output              [19:0]      r_ppn1,
    output              [1:0]       r_plv1,
    output              [1:0]       r_mat1,
    output                          r_d1,
    output                          r_v1
);
    //ITLB-控制逻辑
    reg  [3:0]                      itlb_state;
    reg  [3:0]                      itlb_state_next;
    wire                            itlb_clean;
    wire                            itlb_refill;

    //ITLB读出数据(组合逻辑出)
    wire [`WIDTH_TLB_INDEX-1:0]     itlb_index;
    wire [19:0]                     itlb_ppn;
    wire [5:0]                      itlb_ps;
    wire                            itlb_d;
    wire                            itlb_v;
    wire [1:0]                      itlb_mat;
    wire [1:0]                      itlb_plv;
    wire                            itlb_found;
    wire                            itlb_ex;

    //L2TLB s0端口 读出数据(寄存器出)
    wire                            l2tlb_s0_found;
    wire [`WIDTH_TLB_INDEX-1:0]     l2tlb_s0_index;
    wire                            l2tlb_s0_e;
    wire                            l2tlb_s0_ps;
    wire                            l2tlb_s0_g;
    wire              [19:0]        l2tlb_s0_ppn0;
    wire              [1:0]         l2tlb_s0_plv0;
    wire              [1:0]         l2tlb_s0_mat0;
    wire                            l2tlb_s0_d0;
    wire                            l2tlb_s0_v0;
    wire              [19:0]        l2tlb_s0_ppn1;
    wire              [1:0]         l2tlb_s0_plv1;
    wire              [1:0]         l2tlb_s0_mat1;
    wire                            l2tlb_s0_d1;
    wire                            l2tlb_s0_v1; 

    //DTLB-控制逻辑
    reg  [4:0]                      dtlb_state;
    reg  [4:0]                      dtlb_state_next;
    wire                            dtlb_clean;
    wire                            dtlb_refill;
    

    //DTLB读出数据(组合逻辑出)
    wire [`WIDTH_TLB_INDEX-1:0]     dtlb_index;
    wire [19:0]                     dtlb_ppn;
    wire [5:0]                      dtlb_ps;
    wire                            dtlb_d;
    wire                            dtlb_v;
    wire [1:0]                      dtlb_mat;
    wire [1:0]                      dtlb_plv;
    wire                            dtlb_found;
    wire                            dtlb_ex;
    //L2TLB s1端口 读出数据(寄存器出)
    wire                            l2tlb_s1_found;
    wire [`WIDTH_TLB_INDEX-1:0]     l2tlb_s1_index;
    wire                            l2tlb_s1_e;
    wire                            l2tlb_s1_ps;
    wire                            l2tlb_s1_g;
    wire              [19:0]        l2tlb_s1_ppn0;
    wire              [1:0]         l2tlb_s1_plv0;
    wire              [1:0]         l2tlb_s1_mat0;
    wire                            l2tlb_s1_d0;
    wire                            l2tlb_s1_v0;
    wire              [19:0]        l2tlb_s1_ppn1;
    wire              [1:0]         l2tlb_s1_plv1;
    wire              [1:0]         l2tlb_s1_mat1;
    wire                            l2tlb_s1_d1;
    wire                            l2tlb_s1_v1; 
    // ITLB相关逻辑
    always @(posedge clk)begin
        if(!rst_n)begin
            itlb_state <= `ITLB_STATE_NORMAL;
        end else if(flush_pif)
            itlb_state <= `ITLB_STATE_NORMAL;
        else 
            itlb_state <= itlb_state_next;
    end
    always @(*)begin
        //! 先空过miss状态，因为L2TLB目前较小，不需要
        if(itlb_state[`ITLB_SIDX_NORMAL])
            itlb_state_next = (need_visit_itlb & !itlb_found)? `ITLB_STATE_REFILL : `ITLB_STATE_NORMAL;
        else if(itlb_state[`ITLB_SIDX_REFILL])
            itlb_state_next = `ITLB_STATE_RETRY;
        else
            itlb_state_next = stall_if_to_wb ? `ITLB_STATE_RETRY : `ITLB_STATE_NORMAL;
    end
    
    assign itlb_refill = itlb_state[`ITLB_SIDX_REFILL] & l2tlb_s0_found;
    assign itlb_clean  = invtlb_valid || we; 
    itlb ITLB (
        .clk                     ( clk              ),
        .rst_n                   ( rst_n            ),
        .is_plv3                 ( is_plv3          ),
        .clean                   ( itlb_clean       ),
        .refill                  ( itlb_refill      ),
        .w_vppn                  ( s0_vppn          ),
        .w_asid                  ( s0_asid          ),
        .w_index                 ( l2tlb_s0_index   ),
        .w_ps                    ( l2tlb_s0_ps      ),
        .w_g                     ( l2tlb_s0_g       ),
        .w_ppn0                  ( l2tlb_s0_ppn0    ),
        .w_plv0                  ( l2tlb_s0_plv0    ),
        .w_mat0                  ( l2tlb_s0_mat0    ),
        .w_d0                    ( l2tlb_s0_d0      ),
        .w_v0                    ( l2tlb_s0_v0      ),
        .w_ppn1                  ( l2tlb_s0_ppn1    ),
        .w_plv1                  ( l2tlb_s0_plv1    ),
        .w_mat1                  ( l2tlb_s0_mat1    ),
        .w_d1                    ( l2tlb_s0_d1      ),
        .w_v1                    ( l2tlb_s0_v1      ),


        .s_valid                 ( need_visit_itlb  ),
        .s_vppn                  ( s0_vppn          ),
        .s_va_bit12              ( s0_va_bit12      ),
        .s_asid                  ( s0_asid          ),

        .s_index                 ( itlb_index      ),
        .s_ppn                   ( itlb_ppn        ),
        .s_ps                    ( itlb_ps         ),
        .s_d                     ( itlb_d          ),
        .s_v                     ( itlb_v          ),
        .s_mat                   ( itlb_mat        ),
        .s_plv                   ( itlb_plv        ),
        .s_found                 ( itlb_found      ),
        .s_ex                    ( itlb_ex         )
    );
    
    //TLB s0端口 读出数据
    assign s0_stall     = itlb_state[`ITLB_SIDX_NORMAL] & need_visit_itlb & ~itlb_found | itlb_state[`ITLB_SIDX_MISS] | itlb_state[`ITLB_SIDX_REFILL];
    assign s0_ppn       = itlb_ppn;
    assign s0_ps        = itlb_ps;
    assign s0_d         = itlb_d;
    assign s0_v         = itlb_v;
    assign s0_mat       = itlb_mat;
    assign s0_plv       = itlb_plv;
    assign s0_found     = itlb_found;
    assign s0_index     = itlb_index;
    assign s0_ex        = itlb_ex;

    //* DTLB相关逻辑    
    always @(posedge clk)begin
        if(!rst_n)begin
            dtlb_state <= `DTLB_STATE_NORMAL;
        end else begin
            dtlb_state <= dtlb_state_next;
        end
    end
    always @(*)begin
        //! 先空过miss状态，因为L2TLB目前较小，不需要
        if(dtlb_state[`DTLB_SIDX_NORMAL])
            dtlb_state_next = (need_visit_dtlb && !dtlb_found)? `DTLB_STATE_REFILL : `DTLB_STATE_NORMAL;
        else if(dtlb_state[`DTLB_SIDX_REFILL])
            dtlb_state_next = `DTLB_STATE_RETRY1;
        else if(dtlb_state[`DTLB_SIDX_RETRY1])
            dtlb_state_next = `DTLB_STATE_RETRY2;
        else dtlb_state_next = stall_mem_to_wb ? `DTLB_STATE_RETRY2 : `DTLB_STATE_NORMAL;
    end
    
    assign dtlb_refill = dtlb_state[`DTLB_SIDX_REFILL] & l2tlb_s1_found;
    assign dtlb_clean  = invtlb_valid || we; 
    
    //L2TLB Data端口寄存器
    reg               [18:0]      s1_vppn_reg;
    reg               [9:0]       s1_asid_reg;
    always @(posedge clk) begin
        if(!s1_stall && !stall_mem_to_wb) begin
            s1_vppn_reg <= s1_vppn;
            s1_asid_reg <= s1_asid;
        end
    end
    
    dtlb DTLB (
        .clk                     ( clk              ),
        
        .rst_n                   ( rst_n            ),
        .is_plv3                 ( is_plv3          ),
        .clean                   ( dtlb_clean       ),
        .refill                  ( dtlb_refill      ),
        .stall_mem_to_wb         ( stall_mem_to_wb  ),
        .w_vppn                  ( s1_vppn_reg      ),
        .w_asid                  ( s1_asid_reg      ),
        .w_index                 ( l2tlb_s1_index   ),
        .w_ps                    ( l2tlb_s1_ps      ),
        .w_g                     ( l2tlb_s1_g       ),
        .w_ppn0                  ( l2tlb_s1_ppn0    ),
        .w_plv0                  ( l2tlb_s1_plv0    ),
        .w_mat0                  ( l2tlb_s1_mat0    ),
        .w_d0                    ( l2tlb_s1_d0      ),
        .w_v0                    ( l2tlb_s1_v0      ),
        .w_ppn1                  ( l2tlb_s1_ppn1    ),
        .w_plv1                  ( l2tlb_s1_plv1    ),
        .w_mat1                  ( l2tlb_s1_mat1    ),
        .w_d1                    ( l2tlb_s1_d1      ),
        .w_v1                    ( l2tlb_s1_v1      ),
        .dtlb_state              ( dtlb_state       ),

        .s_valid                 ( need_visit_dtlb  ),
        .s_is_tlbsrch            ( s1_is_tlbsrch    ),
        .s_is_ld_st_cacop2       ( s1_is_ld_st_cacop2 ),
        .s_is_store              ( s1_is_store),
        .s_vppn                  ( s1_vppn          ),
        .s_va_bit12              ( s1_va_bit12      ),
        .s_asid                  ( s1_asid          ),
        
        .s_index                 ( dtlb_index      ),
        .s_ppn                   ( dtlb_ppn        ),
        .s_ps                    ( dtlb_ps         ),
        .s_d                     ( dtlb_d          ),
        .s_v                     ( dtlb_v          ),
        .s_mat                   ( dtlb_mat        ),
        .s_plv                   ( dtlb_plv        ),
        .s_found                 ( dtlb_found      ),
        .s_ex                    ( dtlb_ex         )
    );
    
    //TLB s1端口 读出数据
    assign s1_stall     = dtlb_state[`DTLB_SIDX_NORMAL] & need_visit_dtlb & ~dtlb_found | dtlb_state[`DTLB_SIDX_REFILL] | dtlb_state[`DTLB_SIDX_RETRY1];
    assign s1_ppn       = dtlb_ppn;
    assign s1_ps        = dtlb_ps;
    assign s1_d         = dtlb_d;
    assign s1_v         = dtlb_v;
    assign s1_mat       = dtlb_mat;
    assign s1_plv       = dtlb_plv;
    assign s1_found     = dtlb_found;
    assign s1_index     = dtlb_index;
    assign s1_ex        = dtlb_ex;
    
    
    l2tlb L2TLB (
        .clk                     ( clk            ),
        .rst_n                   ( rst_n          ),
        .stall_mem_to_wb         ( stall_mem_to_wb ),
        .itlb_state              ( itlb_state     ),
        .dtlb_state              ( dtlb_state     ),
        .s0_vppn                 ( s0_vppn        ),
        .s0_asid                 ( s0_asid        ),
        .s1_vppn                 ( s1_vppn_reg        ),
        .s1_asid                 ( s1_asid_reg        ),
        .invtlb_valid            ( invtlb_valid   ),
        .invtlb_op               ( invtlb_op      ),
        .invtlb_asid             ( invtlb_asid    ),
        .invtlb_vppn             ( invtlb_vppn    ),
        .we                      ( we             ),
        .w_index                 ( w_index        ),
        .w_e                     ( w_e            ),
        .w_vppn                  ( w_vppn         ),
        .w_ps                    ( w_ps           ),
        .w_asid                  ( w_asid         ),
        .w_g                     ( w_g            ),
        .w_ppn0                  ( w_ppn0         ),
        .w_plv0                  ( w_plv0         ),
        .w_mat0                  ( w_mat0         ),
        .w_d0                    ( w_d0           ),
        .w_v0                    ( w_v0           ),
        .w_ppn1                  ( w_ppn1         ),
        .w_plv1                  ( w_plv1         ),
        .w_mat1                  ( w_mat1         ),
        .w_d1                    ( w_d1           ),
        .w_v1                    ( w_v1           ),
        .r_index                 ( r_index        ),

        .s0_found                ( l2tlb_s0_found       ),
        .s0_index                ( l2tlb_s0_index       ),
        .s0_e                    ( l2tlb_s0_e           ),
        .s0_ps                   ( l2tlb_s0_ps          ),
        .s0_g                    ( l2tlb_s0_g           ),
        .s0_ppn0                 ( l2tlb_s0_ppn0        ),
        .s0_plv0                 ( l2tlb_s0_plv0        ),
        .s0_mat0                 ( l2tlb_s0_mat0        ),
        .s0_d0                   ( l2tlb_s0_d0          ),
        .s0_v0                   ( l2tlb_s0_v0          ),
        .s0_ppn1                 ( l2tlb_s0_ppn1        ),
        .s0_plv1                 ( l2tlb_s0_plv1        ),
        .s0_mat1                 ( l2tlb_s0_mat1        ),
        .s0_d1                   ( l2tlb_s0_d1          ),
        .s0_v1                   ( l2tlb_s0_v1          ),
        .s1_found                ( l2tlb_s1_found       ),
        .s1_index                ( l2tlb_s1_index       ),
        .s1_e                    ( l2tlb_s1_e           ),
        .s1_ps                   ( l2tlb_s1_ps          ),
        .s1_g                    ( l2tlb_s1_g           ),
        .s1_ppn0                 ( l2tlb_s1_ppn0        ),
        .s1_plv0                 ( l2tlb_s1_plv0        ),
        .s1_mat0                 ( l2tlb_s1_mat0        ),
        .s1_d0                   ( l2tlb_s1_d0          ),
        .s1_v0                   ( l2tlb_s1_v0          ),
        .s1_ppn1                 ( l2tlb_s1_ppn1        ),
        .s1_plv1                 ( l2tlb_s1_plv1        ),
        .s1_mat1                 ( l2tlb_s1_mat1        ),
        .s1_d1                   ( l2tlb_s1_d1          ),
        .s1_v1                   ( l2tlb_s1_v1          ),
        .r_e                     ( r_e            ),
        .r_vppn                  ( r_vppn         ),
        .r_ps                    ( r_ps           ),
        .r_asid                  ( r_asid         ),
        .r_g                     ( r_g            ),
        .r_ppn0                  ( r_ppn0         ),
        .r_plv0                  ( r_plv0         ),
        .r_mat0                  ( r_mat0         ),
        .r_d0                    ( r_d0           ),
        .r_v0                    ( r_v0           ),
        .r_ppn1                  ( r_ppn1         ),
        .r_plv1                  ( r_plv1         ),
        .r_mat1                  ( r_mat1         ),
        .r_d1                    ( r_d1           ),
        .r_v1                    ( r_v1           )
    );
endmodule
