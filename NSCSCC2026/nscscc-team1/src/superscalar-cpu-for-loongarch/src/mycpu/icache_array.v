`include "cache_defs.vh"

module icache_array (
        input wire clk,
        input wire resetn,

        input wire lookup_valid,
        input wire [`CACHE_INDEX_WIDTH-1:0] lookup_index,

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
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] way0_data7,
        output wire way1_valid,
        output wire [`CACHE_TAG_WIDTH-1:0] way1_tag,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data0,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data1,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data2,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data3,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data4,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data5,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data6,
        output wire [`CACHE_WORD_WIDTH-1:0] way1_data7
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

    reg data_wen [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
    reg [`CACHE_WSTRB_WIDTH-1:0] data_we [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
    reg [`CACHE_INDEX_WIDTH-1:0] data_waddr [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
    reg [`CACHE_WORD_WIDTH-1:0] data_din [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
    reg data_ren [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
    reg [`CACHE_INDEX_WIDTH-1:0] data_raddr [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];
    wire [`CACHE_WORD_WIDTH-1:0] data_dout [0:`CACHE_WAYS-1][0:`CACHE_BANKS-1];


    assign lookup_refill_conflict = refill_valid && lookup_valid &&
           (refill_index == lookup_index);

    assign if2_array_valid = lookup_valid_r;

    assign way0_valid = lookup_valid_r && valid_way0_r[lookup_index_r];
    assign way0_tag = tag_dout[0][`CACHE_TAG_WIDTH-1:0];
    assign way0_data0 = data_dout[0][0];
    assign way0_data1 = data_dout[0][1];
    assign way0_data2 = data_dout[0][2];
    assign way0_data3 = data_dout[0][3];
    assign way0_data4 = data_dout[0][4];
    assign way0_data5 = data_dout[0][5];
    assign way0_data6 = data_dout[0][6];
    assign way0_data7 = data_dout[0][7];

    assign way1_valid = lookup_valid_r && valid_way1_r[lookup_index_r];
    assign way1_tag = tag_dout[1][`CACHE_TAG_WIDTH-1:0];
    assign way1_data0 = data_dout[1][0];
    assign way1_data1 = data_dout[1][1];
    assign way1_data2 = data_dout[1][2];
    assign way1_data3 = data_dout[1][3];
    assign way1_data4 = data_dout[1][4];
    assign way1_data5 = data_dout[1][5];
    assign way1_data6 = data_dout[1][6];
    assign way1_data7 = data_dout[1][7];

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
                    data_wen[dcw][dcb] = refill_valid && (refill_way == dcw);
                    data_we[dcw][dcb] = (refill_valid && (refill_way == dcw)) ?
                           {`CACHE_WSTRB_WIDTH{1'b1}} :
                           {`CACHE_WSTRB_WIDTH{1'b0}};
                    data_waddr[dcw][dcb] = (refill_valid && (refill_way == dcw)) ?
                              refill_index :
                              {`CACHE_INDEX_WIDTH{1'b0}};
                    data_din[dcw][dcb] = (refill_valid && (refill_way == dcw)) ?
                            refill_line[dcb*`CACHE_WORD_WIDTH +:
                                        `CACHE_WORD_WIDTH] :
                            {`CACHE_WORD_WIDTH{1'b0}};

                    data_ren[dcw][dcb] = lookup_valid && !lookup_refill_conflict;
                    data_raddr[dcw][dcb] = (lookup_valid && !lookup_refill_conflict) ?
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
        end
        else begin
            lookup_valid_r <= lookup_valid && !lookup_refill_conflict;
            if(lookup_valid && !lookup_refill_conflict) begin
                lookup_index_r <= lookup_index;
            end

            if(refill_valid) begin
                if(!refill_way) begin
                    valid_way0_r[refill_index] <= 1'b1;
                end
                else begin
                    valid_way1_r[refill_index] <= 1'b1;
                end
            end

            if(maint_clear_valid) begin
                if(!maint_clear_way) begin
                    valid_way0_r[maint_clear_index] <= 1'b0;
                end
                else begin
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
