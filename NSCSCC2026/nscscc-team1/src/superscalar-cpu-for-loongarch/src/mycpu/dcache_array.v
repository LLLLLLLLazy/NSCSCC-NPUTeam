`include "cache_defs.vh"

module dcache_array (
    input wire clk,
    input wire resetn,

    input wire lookup_valid,
    input wire [`CACHE_INDEX_WIDTH-1:0] lookup_index,
    input wire [`CACHE_BANK_WIDTH-1:0] lookup_bank,

    input wire maint_write_valid,
    input wire maint_write_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] maint_write_index,
    input wire [`CACHE_BANK_WIDTH-1:0] maint_write_bank,
    input wire maint_write_all_bank,
    input wire maint_clear_valid,
    input wire maint_clear_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] maint_clear_index,

    // 原来这里还有一组按 bank 的 refill_write_* 端口。
    // L1↔L2 改成一拍整行返回后，refill 一律走下面的全行写口
    // （victim_fill_*，一拍写 tag + 8 bank + dirty），
    // 按 bank 的 refill 通路已无调用者，删除。
    // 收益不只是省逻辑：它原本挂在 write_way_w / write_index_w /
    // write_bank_w / write_tag_w / store_ready / lookup_write_conflict
    // 六条 mux 链上，而 BRAM 写地址是关键路径候选。

    input wire victim_fill_valid,
    input wire victim_fill_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] victim_fill_index,
    input wire [`CACHE_TAG_WIDTH-1:0] victim_fill_tag,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data0,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data1,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data2,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data3,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data4,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data5,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data6,
    input wire [`CACHE_WORD_WIDTH-1:0] victim_fill_data7,
    input wire victim_fill_dirty,

    output wire array_write_busy,
    output wire store_ready,

    input wire store_valid,
    input wire store_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] store_index,
    input wire [`CACHE_BANK_WIDTH-1:0] store_bank,
    input wire [`CACHE_WSTRB_WIDTH-1:0] store_wstrb,
    input wire [`CACHE_WORD_WIDTH-1:0] store_wdata,

    input wire wb_read_valid,
    input wire wb_read_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] wb_read_index,

    output wire lookup_write_conflict,
    output wire wb_write_conflict,
    output wire lookup_wb_conflict,

    output wire mem2_array_valid,
    output wire way0_valid,
    output wire way0_dirty,
    output wire [`CACHE_TAG_WIDTH-1:0] way0_tag,
    output wire [`CACHE_WORD_WIDTH-1:0] way0_rdata,
    output wire way1_valid,
    output wire way1_dirty,
    output wire [`CACHE_TAG_WIDTH-1:0] way1_tag,
    output wire [`CACHE_WORD_WIDTH-1:0] way1_rdata,

    output wire wb_line_array_valid,
    output wire wb_line_valid,
    output wire wb_line_dirty,
    output wire [`CACHE_TAG_WIDTH-1:0] wb_line_tag,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data0,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data1,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data2,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data3,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data4,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data5,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data6,
    output wire [`CACHE_WORD_WIDTH-1:0] wb_line_data7
);

reg tag_wen [0:`CACHE_WAYS-1];
reg [`CACHE_INDEX_WIDTH-1:0] tag_waddr [0:`CACHE_WAYS-1];
reg [`CACHE_TAGV_RAM_WIDTH-1:0] tag_din [0:`CACHE_WAYS-1];
reg tag_ren [0:`CACHE_WAYS-1];
reg [`CACHE_INDEX_WIDTH-1:0] tag_raddr [0:`CACHE_WAYS-1];
wire [`CACHE_TAGV_RAM_WIDTH-1:0] tag_dout [0:`CACHE_WAYS-1];

reg [`CACHE_SETS-1:0] valid_way0_r;
reg [`CACHE_SETS-1:0] valid_way1_r;
reg [`CACHE_SETS-1:0] dirty_way0_r;
reg [`CACHE_SETS-1:0] dirty_way1_r;

reg lookup_valid_r;
reg [`CACHE_INDEX_WIDTH-1:0] lookup_index_r;
reg [`CACHE_BANK_WIDTH-1:0] lookup_bank_r;

reg wb_read_valid_r;
reg wb_read_way_r;
reg [`CACHE_INDEX_WIDTH-1:0] wb_read_index_r;

reg data_wen [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_WSTRB_WIDTH-1:0] data_we [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_INDEX_WIDTH-1:0] data_waddr [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_WORD_WIDTH-1:0] data_din [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg data_ren [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_INDEX_WIDTH-1:0] data_raddr [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
wire [`CACHE_WORD_WIDTH-1:0] data_dout [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];

wire write_valid_w;
wire write_way_w;
wire [`CACHE_INDEX_WIDTH-1:0] write_index_w;
wire [`CACHE_BANK_WIDTH-1:0] write_bank_w;
wire write_all_bank_w;
wire write_tag_w;

assign store_ready = !maint_write_valid && !maint_clear_valid &&
                     !victim_fill_valid;
assign write_valid_w = maint_write_valid || maint_clear_valid ||
                       victim_fill_valid || store_valid;
assign write_way_w = maint_write_valid ? maint_write_way :
                     maint_clear_valid ? maint_clear_way :
                     victim_fill_valid ? victim_fill_way : store_way;
assign write_index_w = maint_write_valid ? maint_write_index :
                       maint_clear_valid ? maint_clear_index :
                       victim_fill_valid ? victim_fill_index : store_index;
assign write_bank_w = maint_write_valid ? maint_write_bank :
                      maint_clear_valid ? {`CACHE_BANK_WIDTH{1'b0}} :
                      victim_fill_valid ? {`CACHE_BANK_WIDTH{1'b0}} :
                      store_bank;
assign write_all_bank_w = maint_write_valid ? maint_write_all_bank :
                          maint_clear_valid ? 1'b1 :
                          victim_fill_valid ? 1'b1 : 1'b0;
assign write_tag_w = maint_clear_valid || victim_fill_valid;
assign array_write_busy = write_valid_w;

assign lookup_write_conflict = lookup_valid && write_valid_w &&
                               (lookup_index == write_index_w) &&
                               (write_tag_w || write_all_bank_w || (lookup_bank == write_bank_w));
assign wb_write_conflict = wb_read_valid && write_valid_w &&
                           (wb_read_way == write_way_w) &&
                           (wb_read_index == write_index_w);
assign lookup_wb_conflict = lookup_valid && wb_read_valid;

assign mem2_array_valid = lookup_valid_r;
assign way0_valid = lookup_valid_r && valid_way0_r[lookup_index_r];
assign way0_dirty = lookup_valid_r && dirty_way0_r[lookup_index_r];
assign way0_tag = tag_dout[0][`CACHE_TAG_WIDTH-1:0];
assign way0_rdata = data_dout[0][lookup_bank_r];
assign way1_valid = lookup_valid_r && valid_way1_r[lookup_index_r];
assign way1_dirty = lookup_valid_r && dirty_way1_r[lookup_index_r];
assign way1_tag = tag_dout[1][`CACHE_TAG_WIDTH-1:0];
assign way1_rdata = data_dout[1][lookup_bank_r];

assign wb_line_array_valid = wb_read_valid_r;
assign wb_line_valid = wb_read_valid_r && (!wb_read_way_r ? valid_way0_r[wb_read_index_r] : valid_way1_r[wb_read_index_r]);
assign wb_line_dirty = wb_read_valid_r && (!wb_read_way_r ? dirty_way0_r[wb_read_index_r] : dirty_way1_r[wb_read_index_r]);
assign wb_line_tag = !wb_read_way_r ? tag_dout[0][`CACHE_TAG_WIDTH-1:0] : tag_dout[1][`CACHE_TAG_WIDTH-1:0];
assign wb_line_data0 = data_dout[wb_read_way_r][0];
assign wb_line_data1 = data_dout[wb_read_way_r][1];
assign wb_line_data2 = data_dout[wb_read_way_r][2];
assign wb_line_data3 = data_dout[wb_read_way_r][3];
assign wb_line_data4 = data_dout[wb_read_way_r][4];
assign wb_line_data5 = data_dout[wb_read_way_r][5];
assign wb_line_data6 = data_dout[wb_read_way_r][6];
assign wb_line_data7 = data_dout[wb_read_way_r][7];

function [`CACHE_WORD_WIDTH-1:0] select_victim_fill_data;
    input [`CACHE_BANK_WIDTH-1:0] bank;
    begin
        case(bank)
            3'd0: select_victim_fill_data = victim_fill_data0;
            3'd1: select_victim_fill_data = victim_fill_data1;
            3'd2: select_victim_fill_data = victim_fill_data2;
            3'd3: select_victim_fill_data = victim_fill_data3;
            3'd4: select_victim_fill_data = victim_fill_data4;
            3'd5: select_victim_fill_data = victim_fill_data5;
            3'd6: select_victim_fill_data = victim_fill_data6;
            default: select_victim_fill_data = victim_fill_data7;
        endcase
    end
endfunction

genvar tcw;
generate
    for(tcw = 0; tcw < `CACHE_WAYS; tcw = tcw + 1) begin : gen_tag_ctrl
        always @(*) begin
            if(victim_fill_valid && (victim_fill_way == tcw)) begin
                tag_wen[tcw] = 1'b1;
                tag_waddr[tcw] = victim_fill_index;
                tag_din[tcw] =
                    {{(`CACHE_TAGV_RAM_WIDTH-`CACHE_TAG_WIDTH){1'b0}},
                     victim_fill_tag};
            end else begin
                tag_wen[tcw] = 1'b0;
                tag_waddr[tcw] = {`CACHE_INDEX_WIDTH{1'b0}};
                tag_din[tcw] = {`CACHE_TAGV_RAM_WIDTH{1'b0}};
            end

            if(wb_read_valid && !wb_write_conflict &&
               (wb_read_way == tcw)) begin
                tag_ren[tcw] = 1'b1;
                tag_raddr[tcw] = wb_read_index;
            end else if(lookup_valid && !lookup_write_conflict &&
                        !lookup_wb_conflict) begin
                tag_ren[tcw] = 1'b1;
                tag_raddr[tcw] = lookup_index;
            end else begin
                tag_ren[tcw] = 1'b0;
                tag_raddr[tcw] = {`CACHE_INDEX_WIDTH{1'b0}};
            end
        end
    end
endgenerate

genvar dcw;
genvar dcb;
generate
    for(dcw = 0; dcw < `CACHE_WAYS; dcw = dcw + 1) begin : gen_data_ctrl_way
        for(dcb = 0; dcb < `CACHE_BANKS; dcb = dcb + 1) begin : gen_data_ctrl_bank
            wire victim_fill_bank_w;
            wire store_bank_w;
            wire wb_read_bank_w;
            wire lookup_bank_w;
            wire wb_read_addr_sel_w;

            assign victim_fill_bank_w =
                victim_fill_valid && (victim_fill_way == dcw);
            assign store_bank_w =
                !victim_fill_valid && store_valid &&
                (store_way == dcw) &&
                (store_bank == dcb);
            assign wb_read_bank_w =
                wb_read_valid && !wb_write_conflict &&
                (wb_read_way == dcw);
            assign lookup_bank_w =
                lookup_valid && !lookup_write_conflict &&
                !lookup_wb_conflict && (lookup_bank == dcb);
            // BRAM enable already qualifies the read.  Keep conflict and bank
            // select logic off the synchronous BRAM address path.
            assign wb_read_addr_sel_w =
                wb_read_valid && (wb_read_way == dcw);

            always @(*) begin
                data_wen[dcw][dcb] =
                    victim_fill_bank_w || store_bank_w;
                data_we[dcw][dcb] =
                    victim_fill_bank_w ?
                    {`CACHE_WSTRB_WIDTH{1'b1}} :
                    store_bank_w ? store_wstrb :
                    {`CACHE_WSTRB_WIDTH{1'b0}};
                data_waddr[dcw][dcb] =
                    victim_fill_bank_w ? victim_fill_index :
                    store_bank_w ? store_index :
                    {`CACHE_INDEX_WIDTH{1'b0}};
                data_din[dcw][dcb] =
                    victim_fill_bank_w ?
                    select_victim_fill_data(dcb) :
                    store_bank_w ? store_wdata :
                    {`CACHE_WORD_WIDTH{1'b0}};
                data_ren[dcw][dcb] =
                    wb_read_bank_w || lookup_bank_w;
                data_raddr[dcw][dcb] =
                    wb_read_addr_sel_w ? wb_read_index :
                    lookup_index;
            end
        end
    end
endgenerate

always @(posedge clk) begin
    if(!resetn) begin
        valid_way0_r <= {`CACHE_SETS{1'b0}};
        valid_way1_r <= {`CACHE_SETS{1'b0}};
        dirty_way0_r <= {`CACHE_SETS{1'b0}};
        dirty_way1_r <= {`CACHE_SETS{1'b0}};
        lookup_valid_r <= 1'b0;
        lookup_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        lookup_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
        wb_read_valid_r <= 1'b0;
        wb_read_way_r <= 1'b0;
        wb_read_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
    end else begin
        lookup_valid_r <= lookup_valid && !lookup_write_conflict && !lookup_wb_conflict;
        if(lookup_valid && !lookup_write_conflict && !lookup_wb_conflict) begin
            lookup_index_r <= lookup_index;
            lookup_bank_r <= lookup_bank;
        end

        wb_read_valid_r <= wb_read_valid && !wb_write_conflict;
        if(wb_read_valid && !wb_write_conflict) begin
            wb_read_way_r <= wb_read_way;
            wb_read_index_r <= wb_read_index;
        end

        if(maint_clear_valid) begin
            if(!maint_clear_way) begin
                valid_way0_r[maint_clear_index] <= 1'b0;
                dirty_way0_r[maint_clear_index] <= 1'b0;
            end else begin
                valid_way1_r[maint_clear_index] <= 1'b0;
                dirty_way1_r[maint_clear_index] <= 1'b0;
            end
        end else if(maint_write_valid) begin
        end else if(victim_fill_valid) begin
            if(!victim_fill_way) begin
                valid_way0_r[victim_fill_index] <= 1'b1;
                dirty_way0_r[victim_fill_index] <= victim_fill_dirty;
            end else begin
                valid_way1_r[victim_fill_index] <= 1'b1;
                dirty_way1_r[victim_fill_index] <= victim_fill_dirty;
            end
        end else if(store_valid) begin
            if(!store_way) begin
                dirty_way0_r[store_index] <= 1'b1;
            end else begin
                dirty_way1_r[store_index] <= 1'b1;
            end
        end
    end
end

genvar gw;
generate
    for(gw = 0; gw < `CACHE_WAYS; gw = gw + 1) begin : gen_tag_ram
        tagv_ram u_tagv_ram (
            .clka(clk),
            .ena(tag_wen[gw]),
            .wea({tag_wen[gw]}),
            .addra(tag_waddr[gw]),
            .dina(tag_din[gw]),
            
            .clkb(clk),
            .enb(tag_ren[gw]),
            .addrb(tag_raddr[gw]),
            .doutb(tag_dout[gw])
        );
    end
endgenerate

genvar dw;
genvar db;
generate
    for(dw = 0; dw < `CACHE_WAYS; dw = dw + 1) begin : gen_data_way
        for(db = 0; db < `CACHE_BANKS; db = db + 1) begin : gen_data_bank
            data_bank_ram u_data_bank_ram (
                .clka(clk),
                .ena(data_wen[dw][db]),
                .wea(data_we[dw][db]),
                .addra(data_waddr[dw][db]),
                .dina(data_din[dw][db]),

                .clkb(clk),
                .enb(data_ren[dw][db]),
                .addrb(data_raddr[dw][db]),
                .doutb(data_dout[dw][db])
            );
        end
    end
endgenerate

endmodule
