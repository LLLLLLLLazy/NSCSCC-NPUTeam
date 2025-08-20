module br_unit(
    input         reset,
    input  [8:0]  jump_op, //  哪个跳转指令
    input         equal, //  是否相等
    input         sign_rj_rd,   //有符号rj小于rd
    input         unsign_rj_rd, //无符号rj小于rd
    //input         same,
    input  [25:0] off_26, //  26位数
    input  [31:0] GR_rj, //  Gr[rj]
    input  [31:0] br_pc,  //  pc
    output [31:0] br_npc,  //  目标地址
    output        RC   //  是否跳转
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
    wire [31:0] RD_b;
    wire [31:0] RD_bl;
    wire [31:0] RD_beq;
    wire [31:0] RD_bne;
    wire [31:0] RD_jirl;
    wire [31:0] RD_blt;
    wire [31:0] RD_bge;
    wire [31:0] RD_bltu;
    wire [31:0] RD_bgeu;

    // 执行的是哪个跳转指令
    assign inst_bne  = jump_op[0];
    assign inst_beq  = jump_op[1];
    assign inst_b    = jump_op[2];
    assign inst_bl   = jump_op[3];    
    assign inst_jirl = jump_op[4];
    assign inst_blt  = jump_op[5];
    assign inst_bge  = jump_op[6];
    assign inst_bltu = jump_op[7];
    assign inst_bgeu = jump_op[8];

    assign RC = ~reset & ((inst_b | inst_bl | (equal & inst_beq) |
                          (!equal & inst_bne) | inst_jirl |
                          (sign_rj_rd & inst_blt) | (!sign_rj_rd & inst_bge) |
                          (unsign_rj_rd & inst_bltu) | (!unsign_rj_rd & inst_bgeu)));

    assign RD_b   = br_pc + {{ 4{off_26[25]}}, off_26, 2'b00};
    assign RD_bl  = br_pc + {{ 4{off_26[25]}}, off_26, 2'b00};
    assign RD_beq = br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};
    assign RD_bne = br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};
    assign RD_jirl= GR_rj + {{14{off_26[15]}}, off_26[15:0], 2'b00}; 
    assign RD_blt = br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};
    assign RD_bge = br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};
    assign RD_bltu= br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};
    assign RD_bgeu= br_pc + {{14{off_26[15]}}, off_26[15:0], 2'b00};
    //assign待添加

    assign br_npc = ({32{inst_b}}   & RD_b)
                  | ({32{inst_bl}}  & RD_bl)
                  | ({32{inst_beq}} & RD_beq)
                  | ({32{inst_bne}} & RD_bne)
                  | ({32{inst_jirl}}& RD_jirl)
                  | ({32{inst_blt}} & RD_blt)
                  | ({32{inst_bge}} & RD_bge)
                  | ({32{inst_bltu}}& RD_bltu)
                  | ({32{inst_bgeu}}& RD_bgeu);

endmodule
