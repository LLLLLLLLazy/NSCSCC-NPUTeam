`include "mycpu.h"

module core_top(

    input         aclk   ,
    input         aresetn,
 
    // ar 
    output [ 3:0] arid   , // master -> slave
    output [31:0] araddr , // master -> slave
    output [ 7:0] arlen  , // master -> slave, 8'b0
    output [ 2:0] arsize , // master -> slave
    output [ 1:0] arburst, // master -> slave, 2'b1
    output [ 1:0] arlock , // master -> slave, 2'b0
    output [ 3:0] arcache, // master -> slave, 4'b0
    output [ 2:0] arprot , // master -> slave, 3'b0
    output        arvalid, // master -> slave
    input         arready, // slave  -> master

    // r
    input  [ 3:0] rid    , // slave  -> master
    input  [31:0] rdata  , // slave  -> master
    input  [ 1:0] rresp  , // slave  -> master, ignore
    input         rlast  , // slave  -> master, ignore
    input         rvalid , // slave  -> master
    output        rready , // master -> slave

    // aw
    output [ 3:0] awid   , // master -> slave, 4'b1
    output [31:0] awaddr , // master -> slave
    output [ 7:0] awlen  , // master -> slave, 8'b0
    output [ 2:0] awsize , // master -> slave
    output [ 1:0] awburst, // master -> slave, 2'b1
    output [ 1:0] awlock , // master -> slave, 2'b0
    output [ 3:0] awcache, // master -> slave, 4'b0
    output [ 2:0] awprot , // master -> slave, 3'b0
    output        awvalid, // master -> slave
    input         awready, // slave  -> master

    // w
    output [ 3:0] wid    , // master -> slave, 4'b1
    output [31:0] wdata  , // master -> slave
    output [ 3:0] wstrb  , // master -> slave
    output        wlast  , // master -> slave, 1'b1
    output        wvalid , // master -> slave
    input         wready , // slave  -> master

    // b
    input  [ 3:0] bid    , // slave  -> master, ignore
    input  [ 1:0] bresp  , // slave  -> master, ignore
    input         bvalid , // slave  -> master
    output        bready , // master -> slave

    //debug
    input  [7:0]    intrpt,
    input           break_point,
    input           infor_flag,
    input  [ 4:0]   reg_num,
    output          ws_valid,
    output [31:0]   rf_rdata,
    
    // trace debug interface
    output [31:0] debug0_wb_pc      ,
    output [ 3:0] debug0_wb_rf_wen  ,
    output [ 4:0] debug0_wb_rf_wnum ,
    output [31:0] debug0_wb_rf_wdata
);

// icache CPU interface
wire        icache_valid    ;
wire        icache_op       ;
wire [ 7:0] icache_index    ;
wire [19:0] icache_tag      ;
wire [ 3:0] icache_offset   ;
wire [ 3:0] icache_wstrb    ;
wire [31:0] icache_wdata    ;
wire        icache_uncache_en;
wire[127:0] icache_rdata    ;
wire        icache_addr_ok  ;
wire        icache_data_ok  ;
wire        icache_tlb_excp_cancel;
wire        icacop_op_en;
wire        icache_miss;
wire        dcache_miss;
// dcache CPU interface
wire        dcache_valid    ;
wire        dcache_op       ;
wire [ 2:0] dcache_size     ;
wire [ 6:0] dcache_index    ;
wire [19:0] dcache_tag      ;
wire [ 4:0] dcache_offset   ;
wire [ 3:0] dcache_wstrb    ;
wire [31:0] dcache_wdata    ;
wire        dcache_uncache_en;
wire [31:0] dcache_rdata    ;
wire        dcache_addr_ok  ;
wire        dcache_data_ok  ;
wire        dcache_tlb_excp_cancel;
wire        dcache_sc_cancel_req;
wire        dcacop_op_en;
wire        preld_en;

wire [1:0]  cacop_op_mode;
wire [7:0]  cacop_op_addr_index;
wire [19:0] cacop_op_addr_tag;
wire [3:0]   cacop_op_addr_offset;

// icache <-> AXI bridge
wire        ic_rd_req;
wire [ 2:0] ic_rd_type;
wire [31:0] ic_rd_addr;
wire        ic_rd_rdy;
wire        ic_ret_valid;
wire        ic_ret_last;
wire [31:0] ic_ret_data;
wire        ic_wr_req;
wire [ 2:0] ic_wr_type;
wire [31:0] ic_wr_addr;
wire [ 3:0] ic_wr_wstrb;
wire [127:0] ic_wr_data;
wire        ic_wr_rdy;
wire        icache_unbusy;

// dcache <-> AXI bridge
wire        dc_rd_req;
wire [ 2:0] dc_rd_type;
wire [31:0] dc_rd_addr;
wire        dc_rd_rdy;
wire        dc_ret_valid;
wire        dc_ret_last;
wire [31:0] dc_ret_data;
wire        dc_wr_req;
wire [ 2:0] dc_wr_type;
wire [31:0] dc_wr_addr;
wire [ 3:0] dc_wr_wstrb;
wire [255:0] dc_wr_data;
wire        dc_wr_rdy;
wire        dcache_empty;
wire        write_buffer_empty;
wire reflush;
mycpu_core u_core(
    .clk               (aclk             ),
    .resetn            (aresetn          ),

    .icache_valid      (icache_valid     ),
    .icache_op         (icache_op        ),
    .icache_index      (icache_index     ),
    .icache_tag        (icache_tag       ),
    .icache_offset     (icache_offset    ),
    .icache_wstrb      (icache_wstrb     ),
    .icache_wdata      (icache_wdata     ),
    .icache_uncache_en (icache_uncache_en),
    .icache_rdata      (icache_rdata     ),
    .icache_addr_ok    (icache_addr_ok   ),
    .icache_data_ok    (icache_data_ok   ),
    .icache_unbusy     (icache_unbusy    ),
    .icache_tlb_excp_cancel(icache_tlb_excp_cancel),
    .icacop_op_en    (icacop_op_en),
    .cacop_op_mode   (cacop_op_mode),
    
    .dcache_valid      (dcache_valid     ),
    .dcache_op         (dcache_op        ),
    .dcache_size       (dcache_size      ),
    .dcache_index      (dcache_index     ),
    .dcache_tag        (dcache_tag       ),
    .dcache_offset     (dcache_offset    ),
    .dcache_wstrb      (dcache_wstrb     ),
    .dcache_wdata      (dcache_wdata     ),
    .dcache_uncache_en (dcache_uncache_en),
    .dcache_rdata      (dcache_rdata     ),
    .dcache_addr_ok    (dcache_addr_ok   ),
    .dcache_data_ok    (dcache_data_ok   ),
    .dcache_tlb_excp_cancel(dcache_tlb_excp_cancel),
    .dcacop_op_en    (dcacop_op_en),
    .preld_en        (preld_en),
    .write_buffer_empty (write_buffer_empty),
    .dcache_empty (dcache_empty),
    .ws_reflush (reflush),
    .debug_wb_pc       (debug0_wb_pc      ),
    .debug_wb_rf_we    (debug0_wb_rf_wen   ),
    .debug_wb_rf_wnum  (debug0_wb_rf_wnum ),
    .debug_wb_rf_wdata (debug0_wb_rf_wdata),
    .intrpt(intrpt)
);

icache u_icache(
    .clk                (aclk                   ),
    .reset              (~aresetn               ),
    .valid              (icache_valid           ),
    .op                 (icache_op              ),
    .index              (icache_index           ),
    .tag                (icache_tag             ),
    .offset             (icache_offset          ),
    .wstrb              (icache_wstrb           ),
    .wdata              (icache_wdata           ),
    .addr_ok            (icache_addr_ok         ),
    .data_ok            (icache_data_ok         ),
    .rdata              (icache_rdata           ),
    .uncache_en         (icache_uncache_en      ),
    .icacop_op_en       (icacop_op_en           ),
    .cacop_op_mode      (cacop_op_mode          ),
    .cacop_op_addr_index({dcache_index, dcache_offset[4]}),
    .cacop_op_addr_tag  (dcache_tag             ),
    .cacop_op_addr_offset(dcache_offset[3:0]    ),
    .icache_unbusy      (icache_unbusy          ),
    .tlb_excp_cancel_req(icache_tlb_excp_cancel ),
    .rd_req             (ic_rd_req              ),
    .rd_type            (ic_rd_type             ),
    .rd_addr            (ic_rd_addr             ),
    .rd_rdy             (ic_rd_rdy              ),
    .ret_valid          (ic_ret_valid           ),
    .ret_last           (ic_ret_last            ),
    .ret_data           (ic_ret_data            ),
    .wr_req             (ic_wr_req              ),
    .wr_type            (ic_wr_type             ),
    .wr_addr            (ic_wr_addr             ),
    .wr_wstrb           (ic_wr_wstrb            ),
    .wr_data            (ic_wr_data             ),
    .wr_rdy             (ic_wr_rdy              ),
     .cache_miss         (icache_miss            )
);

dcache u_dcache(
    .clk                (aclk                   ),
    .reset              (~aresetn               ),
    .valid              (dcache_valid           ),
    .op                 (dcache_op              ),
    .size               (dcache_size            ),
    .index              (dcache_index           ),
    .tag                (dcache_tag             ),
    .offset             (dcache_offset          ),
    .wstrb              (dcache_wstrb           ),
    .wdata              (dcache_wdata           ),
    .addr_ok            (dcache_addr_ok         ),
    .data_ok            (dcache_data_ok         ),
    .rdata              (dcache_rdata           ),
    .uncache_en         (dcache_uncache_en      ),
    .dcacop_op_en       (dcacop_op_en           ),
    .cacop_op_mode      (cacop_op_mode          ),
    .preld_en           (preld_en               ),
    .tlb_excp_cancel_req(dcache_tlb_excp_cancel ),
    .dcache_empty       (dcache_empty           ),
    .rd_req             (dc_rd_req              ),
    .rd_type            (dc_rd_type             ),
    .rd_addr            (dc_rd_addr             ),
    .rd_rdy             (dc_rd_rdy              ),
    .ret_valid          (dc_ret_valid           ),
    .ret_last           (dc_ret_last            ),
    .ret_data           (dc_ret_data            ),
    .wr_req             (dc_wr_req              ),
    .wr_type            (dc_wr_type             ),
    .wr_addr            (dc_wr_addr             ),
    .wr_wstrb           (dc_wr_wstrb            ),
    .wr_data            (dc_wr_data             ),
    .wr_rdy             (dc_wr_rdy              ),
    .cache_miss         (dcache_miss            )
);

axi_bridge u_bridge(
    .clk               (aclk             ),
    .reset             (~aresetn         ),

    .arid              (arid             ),
    .araddr            (araddr           ),
    .arlen             (arlen            ),
    .arsize            (arsize           ),
    .arburst           (arburst          ),
    .arlock            (arlock           ),
    .arcache           (arcache          ),
    .arprot            (arprot           ),
    .arvalid           (arvalid          ),
    .arready           (arready          ),

    .rid               (rid              ),
    .rdata             (rdata            ),
    .rresp             (rresp            ),
    .rlast             (rlast            ),
    .rvalid            (rvalid           ),
    .rready            (rready           ),

    .awid              (awid             ),
    .awaddr            (awaddr           ),
    .awlen             (awlen            ),
    .awsize            (awsize           ),
    .awburst           (awburst          ),
    .awlock            (awlock           ),
    .awcache           (awcache          ),
    .awprot            (awprot           ),
    .awvalid           (awvalid          ),
    .awready           (awready          ),

    .wid               (wid              ),
    .wdata             (wdata            ),
    .wstrb             (wstrb            ),
    .wlast             (wlast            ),
    .wvalid            (wvalid           ),
    .wready            (wready           ),

    .bid               (bid              ),
    .bresp             (bresp            ),
    .bvalid            (bvalid           ),
    .bready            (bready           ),

    .inst_rd_req       (ic_rd_req        ),
    .inst_rd_type      (ic_rd_type       ),
    .inst_rd_addr      (ic_rd_addr       ),
    .inst_rd_rdy       (ic_rd_rdy        ),
    .inst_ret_valid    (ic_ret_valid     ),
    .inst_ret_last     (ic_ret_last      ),
    .inst_ret_data     (ic_ret_data      ),
    .inst_wr_req       (ic_wr_req        ),
    .inst_wr_type      (ic_wr_type       ),
    .inst_wr_addr      (ic_wr_addr       ),
    .inst_wr_wstrb     (ic_wr_wstrb      ),
    .inst_wr_data      (ic_wr_data       ),
    .inst_wr_rdy       (ic_wr_rdy        ),

    .data_rd_req       (dc_rd_req        ),
    .data_rd_type      (dc_rd_type       ),
    .data_rd_addr      (dc_rd_addr       ),
    .data_rd_rdy       (dc_rd_rdy        ),
    .data_ret_valid    (dc_ret_valid     ),
    .data_ret_last     (dc_ret_last      ),
    .data_ret_data     (dc_ret_data      ),
    .data_wr_req       (dc_wr_req        ),
    .data_wr_type      (dc_wr_type       ),
    .data_wr_addr      (dc_wr_addr       ),
    .data_wr_wstrb     (dc_wr_wstrb      ),
    .data_wr_data      (dc_wr_data       ),
    .data_wr_rdy       (dc_wr_rdy        ),
    .write_buffer_empty(write_buffer_empty)
);

endmodule