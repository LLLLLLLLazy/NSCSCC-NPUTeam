module branch_predictor(
        input               clk,
        input               resetn,
        input  [31:0]       pc,
        input               update,
        input  [31:0]       branch_pc,
        input               actual_taken,
        input  [31:0]       actual_target,
        output [7:0]        is_taken,
        output [255:0]      target_address,
        output wire         clr
    );

    //鎷兼帴pc
    wire [31:0] pc_slot [0:7];
    assign pc_slot[0] = {pc[31:5], 3'd0, 2'b00};
    assign pc_slot[1] = {pc[31:5], 3'd1, 2'b00};
    assign pc_slot[2] = {pc[31:5], 3'd2, 2'b00};
    assign pc_slot[3] = {pc[31:5], 3'd3, 2'b00};
    assign pc_slot[4] = {pc[31:5], 3'd4, 2'b00};
    assign pc_slot[5] = {pc[31:5], 3'd5, 2'b00};
    assign pc_slot[6] = {pc[31:5], 3'd6, 2'b00};
    assign pc_slot[7] = {pc[31:5], 3'd7, 2'b00};


    wire [7:0] pht_read_addr [0:7];
    wire [7:0] pht_update_addr = branch_pc[12:5];
    wire [2:0] pht_update_bank = branch_pc[4:2];

    assign pht_read_addr[0] = pc_slot[0][12:5];
    assign pht_read_addr[1] = pc_slot[1][12:5];
    assign pht_read_addr[2] = pc_slot[2][12:5];
    assign pht_read_addr[3] = pc_slot[3][12:5];
    assign pht_read_addr[4] = pc_slot[4][12:5];
    assign pht_read_addr[5] = pc_slot[5][12:5];
    assign pht_read_addr[6] = pc_slot[6][12:5];
    assign pht_read_addr[7] = pc_slot[7][12:5];

    wire [1:0] pht_pred_dout [0:7];
    wire [1:0] pht_upd_dout [0:7];
    wire [7:0] pht_we;

    reg pht_upd_valid;
    reg [2:0] pht_upd_bank;
    reg [7:0] pht_upd_addr;
    reg pht_upd_taken;

    always @(posedge clk) begin
        if (!resetn) begin
            pht_upd_valid <= 1'b0;
            pht_upd_bank <= 3'd0;
            pht_upd_addr <= 8'd0;
            pht_upd_taken <= 1'b0;
        end
        else begin
            pht_upd_valid <= update;
            pht_upd_bank <= pht_update_bank;
            pht_upd_addr <= pht_update_addr;
            pht_upd_taken <= actual_taken;
        end
    end

    wire [1:0] pht_upd_dout_sel = pht_upd_dout[pht_upd_bank];
    wire [1:0] pht_upd_next = pht_upd_taken ?
         (pht_upd_dout_sel == 2'b11 ? 2'b11 : pht_upd_dout_sel + 2'd1) :
         (pht_upd_dout_sel == 2'b00 ? 2'b00 : pht_upd_dout_sel - 2'd1);

    genvar pb;
    generate
        for (pb = 0; pb < 8; pb = pb + 1) begin : pht_bram_gen
            assign pht_we[pb] = pht_upd_valid && (pht_upd_bank == pb);

            pht_bram u_pht_pred (
                         .clka  (clk),
                         .ena   (1'b1),
                         .wea   (pht_we[pb]),
                         .addra (pht_upd_addr),
                         .dina  (pht_upd_next),
                         .clkb  (clk),
                         .enb   (1'b1),
                         .addrb (pht_read_addr[pb]),
                         .doutb (pht_pred_dout[pb])
                     );

            pht_bram u_pht_upd (
                         .clka  (clk),
                         .ena   (1'b1),
                         .wea   (pht_we[pb]),
                         .addra (pht_upd_addr),
                         .dina  (pht_upd_next),
                         .clkb  (clk),
                         .enb   (1'b1),
                         .addrb (pht_update_addr),
                         .doutb (pht_upd_dout[pb])
                     );
        end
    endgenerate


    localparam BTB_WAY_WIDTH = 57;//1way鐨勯暱搴�
    localparam BTB_ROW_WIDTH = 228;//4way
    localparam BTB_CLR_IDLE = 1'b0;
    localparam BTB_CLR_WORK = 1'b1;

    wire [5:0] btb_read_addr [0:7];
    wire [5:0] btb_update_addr = branch_pc[10:5];
    wire [2:0] btb_update_bank = branch_pc[4:2];
    wire [20:0] btb_update_tag = branch_pc[31:11];

    assign btb_read_addr[0] = pc_slot[0][10:5];
    assign btb_read_addr[1] = pc_slot[1][10:5];
    assign btb_read_addr[2] = pc_slot[2][10:5];
    assign btb_read_addr[3] = pc_slot[3][10:5];
    assign btb_read_addr[4] = pc_slot[4][10:5];
    assign btb_read_addr[5] = pc_slot[5][10:5];
    assign btb_read_addr[6] = pc_slot[6][10:5];
    assign btb_read_addr[7] = pc_slot[7][10:5];

    wire [BTB_ROW_WIDTH-1:0] btb_pred_dout [0:7];
    wire [BTB_ROW_WIDTH-1:0] btb_upd_dout [0:7];

    reg btb_upd_valid;
    reg [2:0] btb_upd_bank;
    reg [5:0] btb_upd_addr;
    reg [20:0] btb_upd_tag;
    reg [31:0] btb_upd_target;


    reg btb_clr_state = BTB_CLR_IDLE;
    reg [5:0] btb_clr_addr = 6'd0;

    wire btb_clr_en = (btb_clr_state == BTB_CLR_WORK);
    wire btb_clr_busy = btb_clr_en;

    always @(posedge clk) begin
        if (!resetn) begin
            btb_clr_state <= BTB_CLR_WORK;
            btb_clr_addr <= 6'd0;
        end
        else if (btb_clr_en) begin
            if (btb_clr_addr == 6'd63)
                btb_clr_state <= BTB_CLR_IDLE;
            else
                btb_clr_addr <= btb_clr_addr + 1'b1;
        end
    end

    assign clr = btb_clr_en;

    wire [5:0] btb_a_addr = btb_clr_en ? btb_clr_addr : btb_upd_addr;

    always @(posedge clk) begin
        if (!resetn) begin
            btb_upd_valid <= 1'b0;
            btb_upd_bank <= 3'd0;
            btb_upd_addr <= 6'd0;
            btb_upd_tag <= 21'd0;
            btb_upd_target <= 32'd0;
        end
        else begin
            btb_upd_valid <= !btb_clr_busy && update && actual_taken;
            btb_upd_bank <= btb_update_bank;
            btb_upd_addr <= btb_update_addr;
            btb_upd_tag <= btb_update_tag;
            btb_upd_target <= actual_target;
        end
    end

    wire [7:0] btb_we;
    wire [BTB_ROW_WIDTH-1:0] btb_wdata [0:7];

    genvar bu;
    generate
        for (bu = 0; bu < 8; bu = bu + 1) begin : btb_update_logic
            wire [56:0] btb_old0 = btb_upd_dout[bu][56:0];
            wire [56:0] btb_old1 = btb_upd_dout[bu][113:57];
            wire [56:0] btb_old2 = btb_upd_dout[bu][170:114];
            wire [56:0] btb_old3 = btb_upd_dout[bu][227:171];

            wire [2:0] btb_old_plru =
                 btb_old0[56] ? btb_old0[55:53] :
                 btb_old1[56] ? btb_old1[55:53] :
                 btb_old2[56] ? btb_old2[55:53] :
                 btb_old3[56] ? btb_old3[55:53] :
                 3'b000;

            wire btb_way0_whit = btb_old0[56] &&
                 (btb_old0[52:32] == btb_upd_tag);
            wire btb_way1_whit = btb_old1[56] &&
                 (btb_old1[52:32] == btb_upd_tag);
            wire btb_way2_whit = btb_old2[56] &&
                 (btb_old2[52:32] == btb_upd_tag);
            wire btb_way3_whit = btb_old3[56] &&
                 (btb_old3[52:32] == btb_upd_tag);

            wire btb_write_hit =
                 btb_way0_whit || btb_way1_whit || btb_way2_whit || btb_way3_whit;

            wire [1:0] btb_whit_index =
                 btb_way0_whit ? 2'd0 :
                 btb_way1_whit ? 2'd1 :
                 btb_way2_whit ? 2'd2 :
                 2'd3;

            reg [1:0] btb_replace_index;
            always @(*) begin
                if (!btb_old0[56])
                    btb_replace_index = 2'd0;
                else if (!btb_old1[56])
                    btb_replace_index = 2'd1;
                else if (!btb_old2[56])
                    btb_replace_index = 2'd2;
                else if (!btb_old3[56])
                    btb_replace_index = 2'd3;
                else
                    btb_replace_index = !btb_old_plru[0] ?
                                      (btb_old_plru[2] ? 2'd2 : 2'd3) :
                                      (btb_old_plru[1] ? 2'd0 : 2'd1);
            end

            wire [1:0] btb_used_way =
                 btb_write_hit ? btb_whit_index : btb_replace_index;

            reg [2:0] btb_plru_next;
            always @(*) begin
                case (btb_used_way)
                    2'd0:
                        btb_plru_next = {btb_old_plru[2], 2'b00};
                    2'd1:
                        btb_plru_next = {btb_old_plru[2], 2'b10};
                    2'd2:
                        btb_plru_next = {1'b0, btb_old_plru[1], 1'b1};
                    2'd3:
                        btb_plru_next = {1'b1, btb_old_plru[1], 1'b1};
                    default:
                        btb_plru_next = btb_old_plru;
                endcase
            end

            wire [BTB_WAY_WIDTH-1:0] btb_way0_new =
                 (btb_used_way == 2'd0) ?
                 {1'b1, btb_plru_next, btb_upd_tag, btb_upd_target} :
                 {btb_old0[56], btb_plru_next,
                  btb_old0[52:32], btb_old0[31:0]};
            wire [BTB_WAY_WIDTH-1:0] btb_way1_new =
                 (btb_used_way == 2'd1) ?
                 {1'b1, btb_plru_next, btb_upd_tag, btb_upd_target} :
                 {btb_old1[56], btb_plru_next,
                  btb_old1[52:32], btb_old1[31:0]};
            wire [BTB_WAY_WIDTH-1:0] btb_way2_new =
                 (btb_used_way == 2'd2) ?
                 {1'b1, btb_plru_next, btb_upd_tag, btb_upd_target} :
                 {btb_old2[56], btb_plru_next,
                  btb_old2[52:32], btb_old2[31:0]};
            wire [BTB_WAY_WIDTH-1:0] btb_way3_new =
                 (btb_used_way == 2'd3) ?
                 {1'b1, btb_plru_next, btb_upd_tag, btb_upd_target} :
                 {btb_old3[56], btb_plru_next,
                  btb_old3[52:32], btb_old3[31:0]};

            assign btb_wdata[bu] = {
                       btb_way3_new,
                       btb_way2_new,
                       btb_way1_new,
                       btb_way0_new
                   };
            assign btb_we[bu] = btb_upd_valid && (btb_upd_bank == bu);
        end
    endgenerate

    genvar bi;
    generate
        for (bi = 0; bi < 8; bi = bi + 1) begin : btb_bram_bank
            btb_bram u_btb_pred (
                         .clka  (clk),
                         .ena   (1'b1),
                         .wea   (btb_clr_en ? 1'b1 : btb_we[bi]),
                         .addra (btb_a_addr),
                         .dina  (btb_clr_en ? {BTB_ROW_WIDTH{1'b0}} : btb_wdata[bi]),
                         .clkb  (clk),
                         .enb   (1'b1),
                         .addrb (btb_read_addr[bi]),
                         .doutb (btb_pred_dout[bi])
                     );

            btb_bram u_btb_upd (
                         .clka  (clk),
                         .ena   (1'b1),
                         .wea   (btb_clr_en ? 1'b1 : btb_we[bi]),
                         .addra (btb_a_addr),
                         .dina  (btb_clr_en ? {BTB_ROW_WIDTH{1'b0}} : btb_wdata[bi]),
                         .clkb  (clk),
                         .enb   (1'b1),
                         .addrb (btb_update_addr),
                         .doutb (btb_upd_dout[bi])
                     );
        end
    endgenerate


    reg [20:0] btb_tag_r [0:7];
    reg [31:0] pc_plus4_r [0:7];

    genvar sl;
    generate
        for (sl = 0; sl < 8; sl = sl + 1) begin : pred_pipe_gen
            always @(posedge clk) begin
                if (!resetn) begin
                    btb_tag_r[sl]  <= 21'd0;
                    pc_plus4_r[sl] <= 32'd0;
                end
                else begin
                    btb_tag_r[sl]  <= pc_slot[sl][31:11];
                    pc_plus4_r[sl] <= pc_slot[sl] + 32'd4;
                end
            end
        end
    endgenerate

    wire [7:0] stage_taken_bus;
    wire [255:0] stage_target_bus;
    wire [31:0] slot_target_w [0:7];

    genvar rs;
    generate
        for (rs = 0; rs < 8; rs = rs + 1) begin : result_gen
            wire [56:0] btb_way0 = btb_pred_dout[rs][56:0];
            wire [56:0] btb_way1 = btb_pred_dout[rs][113:57];
            wire [56:0] btb_way2 = btb_pred_dout[rs][170:114];
            wire [56:0] btb_way3 = btb_pred_dout[rs][227:171];

            wire btb_way0_rhit = btb_way0[56] &&
                 (btb_way0[52:32] == btb_tag_r[rs]);
            wire btb_way1_rhit = btb_way1[56] &&
                 (btb_way1[52:32] == btb_tag_r[rs]);
            wire btb_way2_rhit = btb_way2[56] &&
                 (btb_way2[52:32] == btb_tag_r[rs]);
            wire btb_way3_rhit = btb_way3[56] &&
                 (btb_way3[52:32] == btb_tag_r[rs]);

            wire btb_rhit =
                 btb_way0_rhit || btb_way1_rhit ||
                 btb_way2_rhit || btb_way3_rhit;

            wire [31:0] hit_target =
                 btb_way0_rhit ? btb_way0[31:0] :
                 btb_way1_rhit ? btb_way1[31:0] :
                 btb_way2_rhit ? btb_way2[31:0] :
                 btb_way3[31:0];

            wire slot_taken = !btb_clr_busy && btb_rhit &&
                 pht_pred_dout[rs][1];
            wire [31:0] slot_target =
                 slot_taken ? hit_target : pc_plus4_r[rs];

            assign stage_taken_bus[rs] = slot_taken;
            assign slot_target_w[rs] = slot_target;
        end
    endgenerate

    assign stage_target_bus = {
               slot_target_w[7],
               slot_target_w[6],
               slot_target_w[5],
               slot_target_w[4],
               slot_target_w[3],
               slot_target_w[2],
               slot_target_w[1],
               slot_target_w[0]
           };

    assign is_taken = stage_taken_bus;
    assign target_address = stage_target_bus;

endmodule
