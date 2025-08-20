module br_unit(
    input         reset,
    input  [8:0]  jump_op,
    input         equal,
    input         sign_rj_rd,
    input         unsign_rj_rd,

    input  [25:0] off_26,
    input  [31:0] GR_rj,
    input  [31:0] br_pc,
    output [31:0] br_npc,
    output        br_taken
);
    wire inst_bne;
    wire inst_beq;
    wire inst_b;
    wire inst_bl;
    wire inst_jirl;
    wire inst_blt;
    wire inst_bge;
    wire inst_bltu;
    wire inst_bgeu;
    wire inst_bgle;
    wire [31:0] RD_b;
    wire [31:0] RD_jirl;
    wire [31:0] RD_bgle;

    assign inst_bne  = jump_op[0];
    assign inst_beq  = jump_op[1];
    assign inst_b    = jump_op[2];
    assign inst_bl   = jump_op[3];
    assign inst_jirl = jump_op[4];
    assign inst_blt  = jump_op[5];
    assign inst_bge  = jump_op[6];
    assign inst_bltu = jump_op[7];
    assign inst_bgeu = jump_op[8];

    assign inst_bgle = jump_op[0] |
                       jump_op[1] |
                       jump_op[5] |
                       jump_op[6] |
                       jump_op[7] |
                       jump_op[8];

    assign br_taken = ~reset & 
                     ((inst_b | inst_bl | inst_jirl | 
                      ( equal & inst_beq) |
                      (!equal & inst_bne) |
                      ( sign_rj_rd & inst_blt) |
                      (!sign_rj_rd & inst_bge) |
                      ( unsign_rj_rd & inst_bltu) |
                      (!unsign_rj_rd & inst_bgeu)));

    assign RD_b    = br_pc + {{ 4{off_26[25]}}, off_26      , 2'b00};
    assign RD_jirl = GR_rj + {{14{off_26[15]}}, off_26[15:0], 2'b00}; 
    assign RD_bgle = br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};

    assign br_npc = ({32{inst_b | inst_bl}}   & RD_b)
                  | ({32{inst_jirl}}& RD_jirl)
                  | ({32{inst_bgle}} & RD_bgle);

endmodule
