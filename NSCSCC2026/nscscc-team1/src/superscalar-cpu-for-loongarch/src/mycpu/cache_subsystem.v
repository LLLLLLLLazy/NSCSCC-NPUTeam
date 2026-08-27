`include "cache_defs.vh"
`include "cache_cacop_defs.vh"
`include "l2_cache_defs.vh"

module cache_subsystem #(
        parameter [1:0] CACHEABLE_MAT = 2'b01
    ) (
        input wire clk,
        input wire resetn,

        input wire if1_valid, // 表示IF1阶段发起一次有效的PC来查cache
        input wire [31:0] if1_va, // IF1阶段给的虚拟地址来提取index、bank
        output wire if1_ready, // cache表示可以接受，相当于addr_ok

        input wire if2_valid, // IF2阶段有效
        input wire [31:0] if2_va, // IF2请求对应的va (对应IF1的lookup)
        input wire [31:0] if2_pa, // ................pa
        input wire [1:0] if2_mat, // ................mat

        input wire if2_miss_req, // miss=1后发出请求
        output wire if2_miss_ready, // 表示cache空闲，可以接受

        output wire if2_array_valid, // 表示IF2当前拿到的array读出结果有效，可以用于hit/miss 判断
        output wire if2_hit, //IF2 当前取指命中icache
        output wire if2_miss, //IF2当前取指miss，或者该地址是uncache。CPU停IF2，并拉if2_miss_req=1

        output wire if2_hit_way, // 命中的 way
        output wire if2_refill_valid, // 取指miss/uncache完成，cache返回最终取到的数据

        // hit-返回的8 word，miss-返回的refill的8 word，uncache这8 word都是要的那个数据，随便一个就可以
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] if2_data7,

        output wire icache_busy, // cache正在处理 refill、uncache、CACOP 等事

        input wire mem1_valid, // MEM1阶段发起lookup
        input wire [31:0] mem1_va, // MEM1访问的va
        output wire mem1_ready, // 表示cache可以接受

        input wire mem2_valid, // MEM2阶段有效
        input wire mem2_wr, //0-load 1-store
        input wire [31:0] mem2_pc,
        input wire mem2_postable_store, // ordinary store, excluding SC
        input wire [1:0] mem2_size, // uncache访问axi的大小长度
        input wire [`CACHE_WSTRB_WIDTH-1:0] mem2_wstrb, // store写字节使能
        input wire [`CACHE_WORD_WIDTH-1:0] mem2_wdata, // store写数据
        input wire [31:0] mem2_va, // MEM2访问时的va
        input wire [31:0] mem2_pa, // ...........pa
        input wire [1:0] mem2_mat, // ...........mat

        input wire mem2_miss_req, // 发出请求，根据mem2_miss拉高，因为比较器在cache内部
        output wire mem2_miss_ready, // miss FSM 空闲，可以接受req
        output wire mem2_array_valid, // 表示MEM2当前拿到的array 读出结果有效，可以做hit/miss判段，感觉CPU用不上

        output wire mem2_hit, // 当前数据访问命中
        output wire mem2_miss, // 当前数据访问 miss，或者该地址是 uncache
        output wire mem2_hit_way, // 命中的 way 0/1
        output wire mem2_load_done, // load hit 完成。此时 mem2_rdata有效

        // cacheable store hit--写入cache完成；miss/uncache store完成--mem2_refill_valid=1
        output wire mem2_store_done, // cacheable store hit写入cache完成；miss/uncache store完成看mem2_refill_valid
        output wire [`CACHE_WORD_WIDTH-1:0] mem2_rdata, // load hit 时返回的数据

        output wire mem2_refill_valid, // dcache 的miss/refill/uncache 完成
        output wire [`CACHE_WORD_WIDTH-1:0] mem2_refill_rdata, //load miss或uncache load完成后返回的数据,store的话，这个值一般不用

        output wire dcache_busy, // 正在处理 miss、writeback、refill、uncache、CACOP

        input wire cacop_valid,
        output wire cacop_ready,
        output wire cacop_done,
        input wire [4:0] cacop_code,
        input wire [31:0] cacop_va,
        input wire [31:0] cacop_pa,

        output wire [3:0] arid,
        output wire [31:0] araddr,
        output wire [7:0] arlen,
        output wire [2:0] arsize,
        output wire [1:0] arburst,
        output wire [1:0] arlock,
        output wire [3:0] arcache,
        output wire [2:0] arprot,
        output wire arvalid,
        input wire arready,
        input wire [3:0] rid,
        input wire [31:0] rdata,
        input wire [1:0] rresp,
        input wire rlast,
        input wire rvalid,
        output wire rready,

        output wire [3:0] awid,
        output wire [31:0] awaddr,
        output wire [7:0] awlen,
        output wire [2:0] awsize,
        output wire [1:0] awburst,
        output wire [1:0] awlock,
        output wire [3:0] awcache,
        output wire [2:0] awprot,
        output wire awvalid,
        input wire awready,
        output wire [3:0] wid,
        output wire [31:0] wdata,
        output wire [3:0] wstrb,
        output wire wlast,
        output wire wvalid,
        input wire wready,
        input wire [3:0] bid,
        input wire [1:0] bresp,
        input wire bvalid,
        output wire bready
    );

    wire i_maint_valid;
    wire [1:0] i_maint_op;
    wire i_maint_way;
    wire [`CACHE_INDEX_WIDTH-1:0] i_maint_index;
    wire [`CACHE_TAG_WIDTH-1:0] i_maint_tag;
    wire i_maint_addr_ok;
    wire i_maint_data_ok;

    wire d_maint_valid;
    wire [1:0] d_maint_op;
    wire d_maint_way;
    wire [`CACHE_INDEX_WIDTH-1:0] d_maint_index;
    wire [`CACHE_TAG_WIDTH-1:0] d_maint_tag;
    wire d_maint_addr_ok;
    wire d_maint_data_ok;
    wire d_l2_maint_valid;
    wire [1:0] d_l2_maint_op;
    wire [31:0] d_l2_maint_addr;
    wire d_l2_maint_ready;
    wire d_l2_maint_done;
    wire l2_direct_maint_valid;
    wire [1:0] l2_direct_maint_op;
    wire [31:0] l2_direct_maint_addr;
    wire l2_direct_maint_ready;
    wire l2_direct_maint_done;
    wire l2_maint_valid;
    wire [1:0] l2_maint_op;
    wire [31:0] l2_maint_addr;
    wire l2_maint_ready;
    wire l2_maint_done;
    wire l2_maint_error_unused_w;

    wire [3:0] icache_arid;
    wire [31:0] icache_araddr;
    wire [7:0] icache_arlen;
    wire [2:0] icache_arsize;
    wire [1:0] icache_arburst;
    wire icache_arvalid;
    wire icache_arready;
    // L1↔L2 读返回：一拍整行，不再逐 beat。
    wire [`CACHE_LINE_WIDTH-1:0] icache_rline;
    wire icache_rvalid;
    wire icache_rready;

    wire [3:0] dcache_arid;
    wire [31:0] dcache_araddr;
    wire [7:0] dcache_arlen;
    wire [2:0] dcache_arsize;
    wire [1:0] dcache_arburst;
    wire dcache_arvalid;
    wire dcache_arready;
    // dcache 的 L2 返回通道是整行一拍，不是 AXI beat 流，所以没有 rlast。
    wire [`CACHE_LINE_WIDTH-1:0] dcache_rline;
    wire dcache_rvalid;
    wire dcache_rready;

    wire dcache_prefetch_valid;
    wire [31:0] dcache_prefetch_addr;
    wire dcache_prefetch_block;
    wire dcache_prefetch_ready;
    wire dcache_prefetch_complete;

    wire [3:0] dcache_awid;
    wire [`L2_SOURCE_WIDTH-1:0] dcache_awsource;
    wire [31:0] dcache_awaddr;
    wire [7:0] dcache_awlen;
    wire [2:0] dcache_awsize;
    wire [1:0] dcache_awburst;
    wire dcache_awvalid;
    wire dcache_awready;
    wire [3:0] dcache_wid;
    wire [`CACHE_LINE_WIDTH-1:0] dcache_wline;
    wire [`CACHE_LINE_WIDTH/8-1:0] dcache_wstrb;
    wire dcache_wlast;
    wire dcache_wvalid;
    wire dcache_wready;
    wire [3:0] dcache_bid;
    wire dcache_bvalid;
    wire dcache_bready;

    assign l2_maint_valid = d_l2_maint_valid || l2_direct_maint_valid;
    assign l2_maint_op = d_l2_maint_valid ? d_l2_maint_op :
           l2_direct_maint_op;
    assign l2_maint_addr = d_l2_maint_valid ? d_l2_maint_addr :
           l2_direct_maint_addr;
    assign d_l2_maint_ready = d_l2_maint_valid && l2_maint_ready;
    assign l2_direct_maint_ready = !d_l2_maint_valid && l2_maint_ready;
    assign d_l2_maint_done = l2_maint_done;
    assign l2_direct_maint_done = l2_maint_done;

    cache_cacop_ctrl u_cache_cacop_ctrl (
                         .clk (clk),
                         .resetn (resetn),
                         .cacop_nop (cacop_valid),
                         .cacop_code (cacop_code),
                         .cacop_va (cacop_va),
                         .cacop_pa (cacop_pa),
                         .cacop_addr_ok (cacop_ready),
                         .cacop_data_ok (cacop_done),
                         .i_maint_valid (i_maint_valid),
                         .i_maint_op (i_maint_op),
                         .i_maint_way (i_maint_way),
                         .i_maint_index (i_maint_index),
                         .i_maint_tag (i_maint_tag),
                         .i_maint_addr_ok(i_maint_addr_ok),
                         .i_maint_data_ok(i_maint_data_ok),
                         .d_maint_valid (d_maint_valid),
                         .d_maint_op (d_maint_op),
                         .d_maint_way (d_maint_way),
                         .d_maint_index (d_maint_index),
                         .d_maint_tag (d_maint_tag),
                         .d_maint_addr_ok(d_maint_addr_ok),
                         .d_maint_data_ok(d_maint_data_ok),
                         .l2_maint_valid(l2_direct_maint_valid),
                         .l2_maint_op(l2_direct_maint_op),
                         .l2_maint_addr(l2_direct_maint_addr),
                         .l2_maint_addr_ok(l2_direct_maint_ready),
                         .l2_maint_data_ok(l2_direct_maint_done)
                     );

    icache_pipeline #(
                        .CACHEABLE_MAT(CACHEABLE_MAT)
                    ) u_icache (
                        .clk (clk),
                        .resetn (resetn),
                        .if1_valid (if1_valid),
                        .if1_va (if1_va),
                        .if1_ready (if1_ready),
                        .if2_valid (if2_valid),
                        .if2_va (if2_va),
                        .if2_pa (if2_pa),
                        .if2_mat (if2_mat),
                        .if2_miss_req (if2_miss_req),
                        .if2_miss_ready (if2_miss_ready),
                        .if2_array_valid (if2_array_valid),
                        .if2_hit (if2_hit),
                        .if2_miss (if2_miss),
                        .if2_hit_way (if2_hit_way),
                        .if2_refill_valid(if2_refill_valid),
                        .if2_data0 (if2_data0),
                        .if2_data1 (if2_data1),
                        .if2_data2 (if2_data2),
                        .if2_data3 (if2_data3),
                        .if2_data4 (if2_data4),
                        .if2_data5 (if2_data5),
                        .if2_data6 (if2_data6),
                        .if2_data7 (if2_data7),
                        .icache_busy (icache_busy),
                        .maint_valid (i_maint_valid),
                        .maint_op (i_maint_op),
                        .maint_way (i_maint_way),
                        .maint_index (i_maint_index),
                        .maint_tag (i_maint_tag),
                        .maint_addr_ok (i_maint_addr_ok),
                        .maint_data_ok (i_maint_data_ok),
                        .arid (icache_arid),
                        .araddr (icache_araddr),
                        .arlen (icache_arlen),
                        .arsize (icache_arsize),
                        .arburst (icache_arburst),
                        .arvalid (icache_arvalid),
                        .arready (icache_arready),
                        .rline (icache_rline),
                        .rvalid (icache_rvalid),
                        .rready (icache_rready)
                    );

    dcache_pipeline #(
                        .CACHEABLE_MAT(CACHEABLE_MAT)
                    ) u_dcache (
                        .clk (clk),
                        .resetn (resetn),
                        .mem1_valid (mem1_valid),
                        .mem1_va (mem1_va),
                        .mem1_ready (mem1_ready),
                        .mem2_valid (mem2_valid),
                        .mem2_wr (mem2_wr),
                        .mem2_pc (mem2_pc),
                        .mem2_postable_store(mem2_postable_store),
                        .mem2_size (mem2_size),
                        .mem2_wstrb (mem2_wstrb),
                        .mem2_wdata (mem2_wdata),
                        .mem2_va (mem2_va),
                        .mem2_pa (mem2_pa),
                        .mem2_mat (mem2_mat),
                        .mem2_miss_req (mem2_miss_req),
                        .mem2_miss_ready (mem2_miss_ready),
                        .mem2_array_valid (mem2_array_valid),
                        .mem2_hit (mem2_hit),
                        .mem2_miss (mem2_miss),
                        .mem2_hit_way (mem2_hit_way),
                        .mem2_load_done (mem2_load_done),
                        .mem2_store_done (mem2_store_done),
                        .mem2_rdata (mem2_rdata),
                        .mem2_refill_valid(mem2_refill_valid),
                        .mem2_refill_rdata(mem2_refill_rdata),
                        .dcache_busy (dcache_busy),
                        .prefetch_valid(dcache_prefetch_valid),
                        .prefetch_addr(dcache_prefetch_addr),
                        .prefetch_block(dcache_prefetch_block),
                        .prefetch_ready(dcache_prefetch_ready),
                        .prefetch_complete(dcache_prefetch_complete),
                        .maint_valid (d_maint_valid),
                        .maint_op (d_maint_op),
                        .maint_way (d_maint_way),
                        .maint_index (d_maint_index),
                        .maint_tag (d_maint_tag),
                        .maint_addr_ok (d_maint_addr_ok),
                        .maint_data_ok (d_maint_data_ok),
                        .maint_l2_valid (d_l2_maint_valid),
                        .maint_l2_op (d_l2_maint_op),
                        .maint_l2_addr (d_l2_maint_addr),
                        .maint_l2_ready (d_l2_maint_ready),
                        .maint_l2_done (d_l2_maint_done),
                        .arid (dcache_arid),
                        .araddr (dcache_araddr),
                        .arlen (dcache_arlen),
                        .arsize (dcache_arsize),
                        .arburst (dcache_arburst),
                        .arvalid (dcache_arvalid),
                        .arready (dcache_arready),
                        .rline (dcache_rline),
                        .rvalid (dcache_rvalid),
                        .rready (dcache_rready),
                        .awid (dcache_awid),
                        .awsource (dcache_awsource),
                        .awaddr (dcache_awaddr),
                        .awlen (dcache_awlen),
                        .awsize (dcache_awsize),
                        .awburst (dcache_awburst),
                        .awvalid (dcache_awvalid),
                        .awready (dcache_awready),
                        .wid (dcache_wid),
                        .wline (dcache_wline),
                        .wstrb (dcache_wstrb),
                        .wlast (dcache_wlast),
                        .wvalid (dcache_wvalid),
                        .wready (dcache_wready),
                        .bid (dcache_bid),
                        .bvalid (dcache_bvalid),
                        .bready (dcache_bready)
                    );

    l2_cache u_l2_cache (
                 .clk (clk),
                 .resetn (resetn),
                 .icache_arid (icache_arid),
                 .icache_araddr (icache_araddr),
                 .icache_arlen (icache_arlen),
                 .icache_arsize (icache_arsize),
                 .icache_arburst(icache_arburst),
                 .icache_arvalid(icache_arvalid),
                 .icache_arready(icache_arready),
                 .icache_rline (icache_rline),
                 .icache_rvalid (icache_rvalid),
                 .icache_rready (icache_rready),
                 .dcache_arid (dcache_arid),
                 .dcache_araddr (dcache_araddr),
                 .dcache_arlen (dcache_arlen),
                 .dcache_arsize (dcache_arsize),
                 .dcache_arburst(dcache_arburst),
                 .dcache_arvalid(dcache_arvalid),
                 .dcache_arready(dcache_arready),
                 .dcache_rline (dcache_rline),
                 .dcache_rvalid (dcache_rvalid),
                 .dcache_rready (dcache_rready),
                 .prefetch_valid(dcache_prefetch_valid),
                 .prefetch_addr(dcache_prefetch_addr),
                 .prefetch_block(dcache_prefetch_block),
                 .prefetch_ready(dcache_prefetch_ready),
                 .prefetch_complete(dcache_prefetch_complete),
                 .dcache_awid (dcache_awid),
                 .dcache_awsource (dcache_awsource),
                 .dcache_awaddr (dcache_awaddr),
                 .dcache_awlen (dcache_awlen),
                 .dcache_awsize (dcache_awsize),
                 .dcache_awburst(dcache_awburst),
                 .dcache_awvalid(dcache_awvalid),
                 .dcache_awready(dcache_awready),
                 .dcache_wid (dcache_wid),
                 .dcache_wline (dcache_wline),
                 .dcache_wstrb (dcache_wstrb),
                 .dcache_wlast (dcache_wlast),
                 .dcache_wvalid (dcache_wvalid),
                 .dcache_wready (dcache_wready),
                 .dcache_bid (dcache_bid),
                 .dcache_bvalid (dcache_bvalid),
                 .dcache_bready (dcache_bready),
                 .maint_valid (l2_maint_valid),
                 .maint_opcode ({1'b0, l2_maint_op}),
                 .maint_addr (l2_maint_addr),
                 .maint_line_data ({`L2_LINE_WIDTH{1'b0}}),
                 .maint_ready (l2_maint_ready),
                 .maint_done (l2_maint_done),
                 .maint_error (l2_maint_error_unused_w),
                 .arid (arid),
                 .araddr (araddr),
                 .arlen (arlen),
                 .arsize (arsize),
                 .arburst (arburst),
                 .arlock (arlock),
                 .arcache (arcache),
                 .arprot (arprot),
                 .arvalid (arvalid),
                 .arready (arready),
                 .rid (rid),
                 .rdata (rdata),
                 .rresp (rresp),
                 .rvalid (rvalid),
                 .rlast (rlast),
                 .rready (rready),
                 .awid (awid),
                 .awaddr (awaddr),
                 .awlen (awlen),
                 .awsize (awsize),
                 .awburst (awburst),
                 .awlock (awlock),
                 .awcache (awcache),
                 .awprot (awprot),
                 .awvalid (awvalid),
                 .awready (awready),
                 .wid (wid),
                 .wdata (wdata),
                 .wstrb (wstrb),
                 .wlast (wlast),
                 .wvalid (wvalid),
                 .wready (wready),
                 .bid (bid),
                 .bresp (bresp),
                 .bvalid (bvalid),
                 .bready (bready)
             );

endmodule
