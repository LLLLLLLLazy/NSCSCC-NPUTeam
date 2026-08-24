module PreDecode #(
    parameter integer CORE_INSTR_BITS = 32,
    parameter integer VADDR_BITS      = 32,
    parameter integer CFI_SZ          = 2
) (
    input  wire [CORE_INSTR_BITS-1:0] instr,
    input  wire [VADDR_BITS-1:0]      pc,
    output wire                       isRet,
    output wire                       isCall,
    output wire [VADDR_BITS-1:0]      target,
    output wire [CFI_SZ-1:0]          cfiType
);

    localparam [CFI_SZ-1:0] CFI_X    = 2'd0;
    localparam [CFI_SZ-1:0] CFI_BR   = 2'd1;
    localparam [CFI_SZ-1:0] CFI_J    = 2'd2;
    localparam [CFI_SZ-1:0] CFI_JIRL = 2'd3;

    wire [5:0] op = instr[31:26];

    wire isJirl = (op == 6'b010011);
    wire isB    = (op == 6'b010100);
    wire isBL   = (op == 6'b010101);
    wire isBEQ  = (op == 6'b010110);
    wire isBNE  = (op == 6'b010111);
    wire isBLT  = (op == 6'b011000);
    wire isBGE  = (op == 6'b011001);
    wire isBLTU = (op == 6'b011010);
    wire isBGEU = (op == 6'b011011);

    // - isBr: conditional branches only (BEQ/BNE/BLT/BLTU/BGE/BGEU)
    // - isJ: B or BL
    wire isBr = isBEQ | isBNE | isBLT | isBLTU | isBGE | isBGEU;
    wire isJ = isB | isBL;

    // isRet:
    //  1) JIRL
    //  2) rd=0 (instr[4:0]==0) and rj=1 (instr[9:5]==1)
    //  3) imm[25:10]==0
    assign isRet = isJirl &&
                   (instr[4:0]   == 5'd0) &&
                   (instr[9:5]   == 5'd1) &&
                   (instr[25:10] == 16'd0);

    // isCall: BL, or JIRL with rd=1 (link to ra)
    assign isCall = isBL || (isJirl && (instr[4:0] == 5'd1));

    wire [VADDR_BITS-1:0] br_off = { {14{instr[25]}}, instr[25:10], 2'b00 };
    wire [VADDR_BITS-1:0] J_off  = { { 4{instr[9 ]}}, instr[9:0],  instr[25:10], 2'b00 };
    wire [VADDR_BITS-1:0] off    = isBr ? br_off : J_off;

    assign target = $unsigned($signed(off) + $signed(pc));

    assign cfiType = isBr   ? CFI_BR   :
                     isJ    ? CFI_J    :
                     isJirl ? CFI_JIRL :
                              CFI_X;

endmodule

