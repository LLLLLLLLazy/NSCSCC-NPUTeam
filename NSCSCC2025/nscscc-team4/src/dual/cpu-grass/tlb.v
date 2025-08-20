`include "header.h"

`define idle    4'b0001
`define look_up 4'b0010
`define miss    4'b0100
`define refill  4'b1000

module tlb (

    input        clk,
    input        reset,
    input        flush,
    // search port 0
    input   [18:0]               s0_vppn     ,
    input                        s0_odd_page ,
    input   [ 9:0]               s0_asid     ,
    input                        s0_valid    ,
    output                       s0_found    ,
    output  reg                  s0_ok       ,
    output [`WIDTH_TLB_INDEX-1:0]s0_index    ,
    output  [ 5:0]               s0_ps       ,
    output  [19:0]               s0_ppn      ,
    output                       s0_v        ,
    output                       s0_d        ,
    output  [ 1:0]               s0_mat      ,
    output  [ 1:0]               s0_plv      ,
    output                       s0_unbusy   ,
    //search port 1
    input   [18:0]               s1_vppn     ,
    input                        s1_odd_page ,
    input   [ 9:0]               s1_asid     ,
    input                        s1_valid    ,
    output                       s1_found    ,
    output  reg                  s1_ok       ,
    output [`WIDTH_TLB_INDEX-1:0]s1_index    ,
    output  [ 5:0]               s1_ps       ,
    output  [19:0]               s1_ppn      ,
    output                       s1_v        ,
    output                       s1_d        ,
    output  [ 1:0]               s1_mat      ,
    output  [ 1:0]               s1_plv      ,
    output                       s1_unbusy   ,
    // write port 
    input                       we          ,
    input [`WIDTH_TLB_INDEX-1:0]w_index     ,
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
    input [`WIDTH_TLB_INDEX-1:0]r_index     ,
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

    //ITLB
    reg  [3:0]                      itlb_state;
    reg  [3:0]                      itlb_next_state;
    wire                            itlb_clean;
    wire                            itlb_refill;
    wire [`WIDTH_TLB_INDEX-1:0]     itlb_index;
    wire [19:0]                     itlb_ppn;
    wire [5:0]                      itlb_ps;
    wire                            itlb_d;
    wire                            itlb_v;
    wire [1:0]                      itlb_mat;
    wire [1:0]                      itlb_plv;

    //DTLB
    reg  [3:0]                      dtlb_state;
    reg  [3:0]                      dtlb_next_state;
    wire                            dtlb_clean;
    wire                            dtlb_refill;
    wire [`WIDTH_TLB_INDEX-1:0]     dtlb_index;
    wire [19:0]                     dtlb_ppn;
    wire [5:0]                      dtlb_ps;
    wire                            dtlb_d;
    wire                            dtlb_v;
    wire [1:0]                      dtlb_mat;
    wire [1:0]                      dtlb_plv;

    //L2TLB 
    wire                            l2tlb_s0_found;
    wire [`WIDTH_TLB_INDEX-1:0]     l2tlb_s0_index;
    wire                            l2tlb_s0_e;
    wire              [ 5:0]        l2tlb_s0_ps;
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
    wire                            l2tlb_s1_found;
    wire [`WIDTH_TLB_INDEX-1:0]     l2tlb_s1_index;
    wire                            l2tlb_s1_e;
    wire              [ 5:0]        l2tlb_s1_ps;
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

// rq_r
    reg [18:0] rq_s0_vppn_r     ;
    reg        rq_s0_odd_page_r ;
    reg [ 9:0] rq_s0_asid_r     ;
    reg [18:0] rq_s1_vppn_r     ;
    reg        rq_s1_odd_page_r ;
    reg [ 9:0] rq_s1_asid_r     ;
    always@(posedge clk) begin
        if(reset) begin
            rq_s0_vppn_r     <= 0;
            rq_s0_odd_page_r <= 0;
            rq_s0_asid_r     <= 0;
            rq_s1_vppn_r     <= 0;
            rq_s1_odd_page_r <= 0;
            rq_s1_asid_r     <= 0;
        end
        else begin
            if(s0_valid & s0_unbusy) begin
                rq_s0_vppn_r     <= s0_vppn;
                rq_s0_odd_page_r <= s0_odd_page;
                rq_s0_asid_r     <= s0_asid;
            end
            if(s1_valid & s1_unbusy) begin
                rq_s1_vppn_r     <= s1_vppn;
                rq_s1_odd_page_r <= s1_odd_page;
                rq_s1_asid_r     <= s1_asid;
            end
        end
    end

    assign s0_unbusy = (itlb_state == `idle);
    assign s1_unbusy = (dtlb_state == `idle);

    always @(posedge clk) begin
        if (reset || flush) begin
            itlb_state <= `idle;
            s0_ok <= 1'b0;
        end else begin
            itlb_state <= itlb_next_state;
            case (itlb_state)
                `idle: begin
                    s0_ok <= 1'b0;
                end
                `look_up: begin
                    if(s0_found) begin
                        s0_ok <= 1'b1;
                    end
                    else begin
                        s0_ok <= 1'b0;
                    end
                end
                `miss: begin
                    s0_ok <= 1'b1;
                end
                `refill: begin
                    s0_ok <= 1'b1;
                end
                default: begin
                    s0_ok <= 1'b0;
                end
            endcase
        end
    end

    always @(*) begin
        if(reset || flush) itlb_next_state = `idle;
        else begin
            case (itlb_state) 
            `idle    : begin
                if(s0_valid) begin
                    itlb_next_state = `look_up;
                end
                else itlb_next_state = `idle;
            end
            `look_up : begin
                if(s0_found) begin 
                    itlb_next_state = `idle;
                end
                else if(l2tlb_s0_found) begin
                    itlb_next_state = `refill;
                end
                else begin
                    itlb_next_state = `miss;
                end
            end
            `miss    : begin
                itlb_next_state = `idle;
            end
            `refill  : begin
                itlb_next_state = `idle;
            end
            default  : itlb_next_state = `idle;
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset || flush) begin
            dtlb_state <= `idle;
            s1_ok <= 1'b0;
        end else begin
            dtlb_state <= dtlb_next_state;
            case (dtlb_state)
                `idle: begin
                    s1_ok <= 1'b0;
                end
                `look_up: begin
                    if(s1_found) begin
                        s1_ok <= 1'b1;
                    end
                    else begin
                        s1_ok <= 1'b0;
                    end
                end
                `miss: begin
                    s1_ok <= 1'b1;
                end
                `refill: begin
                    s1_ok <= 1'b1;
                end
                default: begin
                    s1_ok <= 1'b0;
                end
            endcase
        end
    end

    always @(*) begin
        if(reset || flush) dtlb_next_state = `idle;
        else begin
            case (dtlb_state) 
            `idle    : begin
                if(s1_valid) begin
                    dtlb_next_state = `look_up;
                end
                else dtlb_next_state = `idle;
            end
            `look_up : begin
                if(s1_found) begin 
                    dtlb_next_state = `idle;
                end
                else if(l2tlb_s1_found) begin
                    dtlb_next_state = `refill;
                end
                else dtlb_next_state = `miss;
            end
            `miss    : begin
                dtlb_next_state = `idle;
            end
            `refill  : begin
                dtlb_next_state = `idle;
            end
            default  : dtlb_next_state = `idle;
            endcase
        end
    end

    assign itlb_clean = we || inv_en;
    assign itlb_refill = (itlb_state == `refill);
    assign dtlb_clean = we || inv_en;
    assign dtlb_refill = (dtlb_state == `refill);

    l1tlb u_itlb (
        .clk                     ( clk              ),
        .reset                   ( reset            ),
        .clean                   ( itlb_clean       ),
        .refill                  ( itlb_refill      ),
        .w_vppn                  ( rq_s0_vppn_r          ),
        .w_asid                  ( rq_s0_asid_r          ),
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


        .s_valid                 ( s0_valid         ),
        .s_vppn                  ( rq_s0_vppn_r          ),
        .s_odd_page              ( rq_s0_odd_page_r      ),
        .s_asid                  ( rq_s0_asid_r          ),

        .s_index                 ( s0_index         ),
        .s_ppn                   ( s0_ppn           ),
        .s_ps                    ( s0_ps            ),
        .s_d                     ( s0_d             ),
        .s_v                     ( s0_v             ),
        .s_mat                   ( s0_mat           ),
        .s_plv                   ( s0_plv           ),
        .s_found                 ( s0_found         )
    );

    l1tlb u_dtlb (
        .clk                     ( clk              ),
        .reset                   ( reset            ),
        .clean                   ( dtlb_clean       ),
        .refill                  ( dtlb_refill      ),
        .w_vppn                  ( rq_s1_vppn_r          ),
        .w_asid                  ( rq_s1_asid_r          ),
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


        .s_valid                 ( s1_valid         ),
        .s_vppn                  ( rq_s1_vppn_r          ),
        .s_odd_page              ( rq_s1_odd_page_r      ),
        .s_asid                  ( rq_s1_asid_r          ),

        .s_index                 ( s1_index         ),
        .s_ppn                   ( s1_ppn           ),
        .s_ps                    ( s1_ps            ),
        .s_d                     ( s1_d             ),
        .s_v                     ( s1_v             ),
        .s_mat                   ( s1_mat           ),
        .s_plv                   ( s1_plv           ),
        .s_found                 ( s1_found         )
    );

    l2tlb u_l2tlb (
        .clk                     ( clk            ),
        .reset                   ( reset          ),
        .s0_vppn                 ( rq_s0_vppn_r        ),
        .s0_asid                 ( rq_s0_asid_r        ),
        .s1_vppn                 ( rq_s1_vppn_r        ),
        .s1_asid                 ( rq_s1_asid_r        ),
        .inv_en                  ( inv_en         ),
        .inv_op                  ( inv_op         ),
        .inv_asid                ( inv_asid       ),
        .inv_vpn                 ( inv_vpn        ),
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