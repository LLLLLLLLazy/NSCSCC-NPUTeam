`ifndef L2_CACHE_DEFS_VH
`define L2_CACHE_DEFS_VH

`define L2_WAYS        4
`define L2_SETS        512
`define L2_BANKS       8
`define L2_LINE_BYTES  32

`define L2_WORD_WIDTH  32
`define L2_BYTE_WIDTH  8
`define L2_LINE_WIDTH  256
`define L2_WSTRB_WIDTH 4

`define L2_TAG_WIDTH    18
`define L2_INDEX_WIDTH  9
`define L2_OFFSET_WIDTH 5
`define L2_BANK_WIDTH   3
`define L2_BLOCK_ADDR_WIDTH 27
`define L2_LAST_BANK_INDEX 3'd7
`define L2_BYTE_OFFSET_WIDTH 2
`define L2_WAY_WIDTH    2

`define L2_TAG_MSB     31
`define L2_TAG_LSB     14
`define L2_INDEX_MSB   13
`define L2_INDEX_LSB   5
`define L2_BANK_MSB    4
`define L2_BANK_LSB    2
`define L2_BYTE_MSB    1
`define L2_BYTE_LSB    0

`define L2_LINE_WORDS      8
`define L2_CAPACITY_BYTES  (`L2_WAYS * `L2_SETS * `L2_LINE_BYTES)

`define L2_SOURCE_WIDTH 3
`define L2_SRC_ICACHE   3'd0
`define L2_SRC_DCACHE   3'd1
`define L2_SRC_VB       3'd2
`define L2_SRC_MAINT    3'd3
`define L2_SRC_UNCACHED 3'd4
`define L2_SRC_PREFETCH 3'd5

`define L2_OPCODE_WIDTH                 3
`define L2_OP_CACHED_LINE_READ          3'd0
`define L2_OP_CACHED_FULL_LINE_WRITE    3'd1
`define L2_OP_UNCACHED_READ             3'd2
`define L2_OP_UNCACHED_WRITE            3'd3
`define L2_OP_MAINT                     3'd4

`define L2_MAINT_STORE_TAG 2'd0
`define L2_MAINT_INDEX_INV 2'd1
`define L2_MAINT_HIT_INV   2'd2

`define L2_AXI_WORD_SIZE  3'b010
`define L2_AXI_LINE_LEN   8'd7
`define L2_AXI_WORD_LEN   8'd0
`define L2_AXI_BURST_INCR 2'b01
`define L2_AXI_ID         4'd2
`define L2_AXI_RESP_OKAY  2'b00

`endif
