`include "cache_defs.vh"

module icache_array (
    input wire clk,
    input wire resetn,

    input wire lookup_valid,
    input wire [`CACHE_INDEX_WIDTH-1:0] lookup_index,
    input wire [`CACHE_BANK_WIDTH-1:0] lookup_bank,

    // 整行写口：一拍写完 tag + 8 个 bank + valid。
    // 原来是按 bank 的 refill_valid/refill_bank/refill_last 通路，
    // 需要 8 拍，且要靠「bank0 那拍清 valid、refill_last 那拍置 valid」
    // 来保证半填充的行不被命中。整行原子写之后这套时序完全不需要了。
    input wire refill_valid,
    input wire refill_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] refill_index,
    input wire [`CACHE_TAG_WIDTH-1:0] refill_tag,
    input wire [`CACHE_LINE_WIDTH-1:0] refill_line,

    input wire maint_clear_valid,
    input wire maint_clear_way,
    input wire [`CACHE_INDEX_WIDTH-1:0] maint_clear_index,

    output wire lookup_refill_conflict,
    output wire if2_array_valid,

    output wire way0_valid,
    output wire [`CACHE_TAG_WIDTH-1:0] way0_tag,
    output wire [`CACHE_WORD_WIDTH-1:0] way0_rdata,
    output wire way1_valid,
    output wire [`CACHE_TAG_WIDTH-1:0] way1_tag,
    output wire [`CACHE_WORD_WIDTH-1:0] way1_rdata
);

reg tag_wen [0:`CACHE_WAYS-1];
reg [`CACHE_INDEX_WIDTH-1:0] tag_waddr [0:`CACHE_WAYS-1];
reg [`CACHE_TAGV_RAM_WIDTH-1:0] tag_din [0:`CACHE_WAYS-1];
reg tag_ren [0:`CACHE_WAYS-1];
reg [`CACHE_INDEX_WIDTH-1:0] tag_raddr [0:`CACHE_WAYS-1];
wire [`CACHE_TAGV_RAM_WIDTH-1:0] tag_dout [0:`CACHE_WAYS-1];

reg [`CACHE_SETS-1:0] valid_way0_r;
reg [`CACHE_SETS-1:0] valid_way1_r;

reg lookup_valid_r;
reg [`CACHE_INDEX_WIDTH-1:0] lookup_index_r;
reg [`CACHE_BANK_WIDTH-1:0] lookup_bank_r;

reg data_wen [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_WSTRB_WIDTH-1:0] data_we [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_INDEX_WIDTH-1:0] data_waddr [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_WORD_WIDTH-1:0] data_din [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg data_ren [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
reg [`CACHE_INDEX_WIDTH-1:0] data_raddr [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
wire [`CACHE_WORD_WIDTH-1:0] data_dout [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];

// 整行写会占掉这个 index 上的 tag 和全部 8 个 bank，
// 所以同 index 的 lookup 一律让路（不再需要比 bank）。
assign lookup_refill_conflict = refill_valid && lookup_valid &&
                                (refill_index == lookup_index);

// 从整行里取出第 bank 个字（bank0 在最低 32 位）。
function [`CACHE_WORD_WIDTH-1:0] select_refill_word;
    input [`CACHE_LINE_WIDTH-1:0] line_data;
    input [`CACHE_BANK_WIDTH-1:0] bank;
    begin
        case (bank)
            3'd0: select_refill_word = line_data[31:0];
            3'd1: select_refill_word = line_data[63:32];
            3'd2: select_refill_word = line_data[95:64];
            3'd3: select_refill_word = line_data[127:96];
            3'd4: select_refill_word = line_data[159:128];
            3'd5: select_refill_word = line_data[191:160];
            3'd6: select_refill_word = line_data[223:192];
            default: select_refill_word = line_data[255:224];
        endcase
    end
endfunction

assign if2_array_valid = lookup_valid_r;
assign way0_valid = lookup_valid_r && valid_way0_r[lookup_index_r];
assign way0_tag = tag_dout[0][`CACHE_TAG_WIDTH-1:0];
assign way0_rdata = data_dout[0][lookup_bank_r];
assign way1_valid = lookup_valid_r && valid_way1_r[lookup_index_r];
assign way1_tag = tag_dout[1][`CACHE_TAG_WIDTH-1:0];
assign way1_rdata = data_dout[1][lookup_bank_r];

genvar tcw;
generate
    for(tcw = 0; tcw < `CACHE_WAYS; tcw = tcw + 1) begin : gen_tag_ctrl
        always @(*) begin
            tag_wen[tcw] = refill_valid && (refill_way == tcw);
            tag_waddr[tcw] = (refill_valid && (refill_way == tcw)) ?
                             refill_index :
                             {`CACHE_INDEX_WIDTH{1'b0}};
            tag_din[tcw] = (refill_valid && (refill_way == tcw)) ?
                           {{(`CACHE_TAGV_RAM_WIDTH-`CACHE_TAG_WIDTH){1'b0}},
                            refill_tag} :
                           {`CACHE_TAGV_RAM_WIDTH{1'b0}};
            tag_ren[tcw] = lookup_valid && !lookup_refill_conflict;
            tag_raddr[tcw] = (lookup_valid && !lookup_refill_conflict) ?
                             lookup_index :
                             {`CACHE_INDEX_WIDTH{1'b0}};
        end
    end
endgenerate

genvar dcw;
genvar dcb;
generate
    for(dcw = 0; dcw < `CACHE_WAYS; dcw = dcw + 1) begin : gen_data_ctrl_way
        for(dcb = 0; dcb < `CACHE_BANKS; dcb = dcb + 1) begin : gen_data_ctrl_bank
            always @(*) begin
                // 整行写：本 way 的 8 个 bank 同拍全写，不再比 bank 号。
                // dcb 是 genvar，select_refill_word 退化成常量切片，
                // 写数据端口上没有 mux。
                data_wen[dcw][dcb] = refill_valid && (refill_way == dcw);
                data_we[dcw][dcb] = (refill_valid && (refill_way == dcw)) ?
                                     {`CACHE_WSTRB_WIDTH{1'b1}} :
                                     {`CACHE_WSTRB_WIDTH{1'b0}};
                data_waddr[dcw][dcb] = (refill_valid && (refill_way == dcw)) ?
                                        refill_index :
                                        {`CACHE_INDEX_WIDTH{1'b0}};
                data_din[dcw][dcb] = (refill_valid && (refill_way == dcw)) ?
                                      select_refill_word(refill_line, dcb) :
                                      {`CACHE_WORD_WIDTH{1'b0}};
                data_ren[dcw][dcb] = lookup_valid &&
                                      !lookup_refill_conflict &&
                                      (lookup_bank == dcb);
                data_raddr[dcw][dcb] = (lookup_valid &&
                                         !lookup_refill_conflict &&
                                         (lookup_bank == dcb)) ?
                                        lookup_index :
                                        {`CACHE_INDEX_WIDTH{1'b0}};
            end
        end
    end
endgenerate

always @(posedge clk) begin
    if(!resetn) begin
        valid_way0_r <= {`CACHE_SETS{1'b0}};
        valid_way1_r <= {`CACHE_SETS{1'b0}};
        lookup_valid_r <= 1'b0;
        lookup_index_r <= {`CACHE_INDEX_WIDTH{1'b0}};
        lookup_bank_r <= {`CACHE_BANK_WIDTH{1'b0}};
    end else begin
        lookup_valid_r <= lookup_valid && !lookup_refill_conflict;
        if(lookup_valid && !lookup_refill_conflict) begin
            lookup_index_r <= lookup_index;
            lookup_bank_r <= lookup_bank;
        end

        // 整行一拍写完，不存在「半填充的行」这个中间态，
        // 所以 valid 直接 0→1，不用先清再置。
        if(refill_valid) begin
            if(!refill_way) begin
                valid_way0_r[refill_index] <= 1'b1;
            end else begin
                valid_way1_r[refill_index] <= 1'b1;
            end
        end

        if(maint_clear_valid) begin
            if(!maint_clear_way) begin
                valid_way0_r[maint_clear_index] <= 1'b0;
            end else begin
                valid_way1_r[maint_clear_index] <= 1'b0;
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
