`include "l2_cache_defs.vh"

module l2_cache_array (
    input wire clk,
    input wire resetn,

    input wire lookup_valid,
    input wire [`L2_INDEX_WIDTH-1:0] lookup_index,
    input wire [`L2_TAG_WIDTH-1:0] lookup_tag,

    output wire lookup_valid_out,
    output wire lookup_hit,
    output wire [3:0] lookup_hit_way,
    output wire [`L2_TAG_WIDTH-1:0] lookup_tag_way0,
    output wire [`L2_TAG_WIDTH-1:0] lookup_tag_way1,
    output wire [`L2_TAG_WIDTH-1:0] lookup_tag_way2,
    output wire [`L2_TAG_WIDTH-1:0] lookup_tag_way3,
    output wire lookup_valid_way0,
    output wire lookup_valid_way1,
    output wire lookup_valid_way2,
    output wire lookup_valid_way3,
    output wire lookup_dirty_way0,
    output wire lookup_dirty_way1,
    output wire lookup_dirty_way2,
    output wire lookup_dirty_way3,

    output wire [`L2_WORD_WIDTH-1:0] read_data0,
    output wire [`L2_WORD_WIDTH-1:0] read_data1,
    output wire [`L2_WORD_WIDTH-1:0] read_data2,
    output wire [`L2_WORD_WIDTH-1:0] read_data3,
    output wire [`L2_WORD_WIDTH-1:0] read_data4,
    output wire [`L2_WORD_WIDTH-1:0] read_data5,
    output wire [`L2_WORD_WIDTH-1:0] read_data6,
    output wire [`L2_WORD_WIDTH-1:0] read_data7,
    output wire read_data_valid,
    output wire [`L2_LINE_WIDTH-1:0] read_way0_line_data,
    output wire [`L2_LINE_WIDTH-1:0] read_way1_line_data,
    output wire [`L2_LINE_WIDTH-1:0] read_way2_line_data,
    output wire [`L2_LINE_WIDTH-1:0] read_way3_line_data,

    input wire tag_write_valid,
    input wire [`L2_WAY_WIDTH-1:0] tag_write_way,
    input wire [`L2_INDEX_WIDTH-1:0] tag_write_index,
    input wire [`L2_TAG_WIDTH-1:0] tag_write_tag,
    input wire tag_write_valid_bit,
    input wire tag_write_dirty_bit,

    input wire clear_set_valid,
    input wire [`L2_INDEX_WIDTH-1:0] clear_set_index,
    input wire clear_valid,
    input wire [`L2_WAY_WIDTH-1:0] clear_way,
    input wire [`L2_INDEX_WIDTH-1:0] clear_index,

    input wire bank_write_valid,
    input wire [`L2_WAY_WIDTH-1:0] bank_write_way,
    input wire [`L2_INDEX_WIDTH-1:0] bank_write_index,
    input wire [`L2_BANK_WIDTH-1:0] bank_write_bank,
    input wire [`L2_WORD_WIDTH-1:0] bank_write_data,

    input wire line_write_valid,
    input wire [`L2_WAY_WIDTH-1:0] line_write_way,
    input wire [`L2_INDEX_WIDTH-1:0] line_write_index,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data0,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data1,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data2,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data3,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data4,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data5,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data6,
    input wire [`L2_WORD_WIDTH-1:0] line_write_data7
);

reg tag_wen [0:`L2_WAYS-1];
reg [`L2_INDEX_WIDTH-1:0] tag_waddr [0:`L2_WAYS-1];
reg [`L2_TAG_WIDTH-1:0] tag_din [0:`L2_WAYS-1];
reg tag_ren [0:`L2_WAYS-1];
reg [`L2_INDEX_WIDTH-1:0] tag_raddr [0:`L2_WAYS-1];
wire [`L2_TAG_WIDTH-1:0] tag_dout [0:`L2_WAYS-1];

reg data_wen [0:`L2_WAYS-1][0:`L2_BANKS-1];
reg [`L2_WSTRB_WIDTH-1:0] data_we [0:`L2_WAYS-1][0:`L2_BANKS-1];
reg [`L2_INDEX_WIDTH-1:0] data_waddr [0:`L2_WAYS-1][0:`L2_BANKS-1];
reg [`L2_WORD_WIDTH-1:0] data_din [0:`L2_WAYS-1][0:`L2_BANKS-1];
reg data_ren [0:`L2_WAYS-1][0:`L2_BANKS-1];
reg [`L2_INDEX_WIDTH-1:0] data_raddr [0:`L2_WAYS-1][0:`L2_BANKS-1];
wire [`L2_WORD_WIDTH-1:0] data_dout [0:`L2_WAYS-1][0:`L2_BANKS-1];

reg [7:0] meta_r [0:`L2_SETS-1];

reg lookup_valid_out_r;
reg [`L2_TAG_WIDTH-1:0] lookup_tag_r;
reg [7:0] lookup_meta_r;

reg read_data_valid_r;

wire tag_write_valid_bit_w;
wire tag_write_dirty_bit_w;

assign tag_write_valid_bit_w = tag_write_valid_bit || tag_write_dirty_bit;
assign tag_write_dirty_bit_w = tag_write_dirty_bit && tag_write_valid_bit_w;

assign lookup_valid_out = lookup_valid_out_r;
assign lookup_tag_way0 = tag_dout[0];
assign lookup_tag_way1 = tag_dout[1];
assign lookup_tag_way2 = tag_dout[2];
assign lookup_tag_way3 = tag_dout[3];
assign lookup_valid_way0 = lookup_meta_r[0];
assign lookup_valid_way1 = lookup_meta_r[1];
assign lookup_valid_way2 = lookup_meta_r[2];
assign lookup_valid_way3 = lookup_meta_r[3];
assign lookup_dirty_way0 = lookup_meta_r[4];
assign lookup_dirty_way1 = lookup_meta_r[5];
assign lookup_dirty_way2 = lookup_meta_r[6];
assign lookup_dirty_way3 = lookup_meta_r[7];

assign lookup_hit_way[0] = lookup_valid_out_r && lookup_meta_r[0] &&
                           (tag_dout[0] == lookup_tag_r);
assign lookup_hit_way[1] = lookup_valid_out_r && lookup_meta_r[1] &&
                           (tag_dout[1] == lookup_tag_r);
assign lookup_hit_way[2] = lookup_valid_out_r && lookup_meta_r[2] &&
                           (tag_dout[2] == lookup_tag_r);
assign lookup_hit_way[3] = lookup_valid_out_r && lookup_meta_r[3] &&
                           (tag_dout[3] == lookup_tag_r);
assign lookup_hit = |lookup_hit_way;

assign read_data_valid = read_data_valid_r;
assign read_data0 = data_dout[0][0];
assign read_data1 = data_dout[0][1];
assign read_data2 = data_dout[0][2];
assign read_data3 = data_dout[0][3];
assign read_data4 = data_dout[0][4];
assign read_data5 = data_dout[0][5];
assign read_data6 = data_dout[0][6];
assign read_data7 = data_dout[0][7];
assign read_way0_line_data = {data_dout[0][7], data_dout[0][6],
                              data_dout[0][5], data_dout[0][4],
                              data_dout[0][3], data_dout[0][2],
                              data_dout[0][1], data_dout[0][0]};
assign read_way1_line_data = {data_dout[1][7], data_dout[1][6],
                              data_dout[1][5], data_dout[1][4],
                              data_dout[1][3], data_dout[1][2],
                              data_dout[1][1], data_dout[1][0]};
assign read_way2_line_data = {data_dout[2][7], data_dout[2][6],
                              data_dout[2][5], data_dout[2][4],
                              data_dout[2][3], data_dout[2][2],
                              data_dout[2][1], data_dout[2][0]};
assign read_way3_line_data = {data_dout[3][7], data_dout[3][6],
                              data_dout[3][5], data_dout[3][4],
                              data_dout[3][3], data_dout[3][2],
                              data_dout[3][1], data_dout[3][0]};

// Synchronous lookup captures the pre-update entry when lookup and write/clear
// target the same index in one cycle. The top-level L2 FSM avoids such
// conflicts in normal operation. Bank order is fixed to addr[4:2]:
// bank0 -> data0, ... , bank7 -> data7.
function [`L2_WORD_WIDTH-1:0] select_line_write_data;
    input [`L2_BANK_WIDTH-1:0] bank;
    begin
        case(bank)
            3'd0: select_line_write_data = line_write_data0;
            3'd1: select_line_write_data = line_write_data1;
            3'd2: select_line_write_data = line_write_data2;
            3'd3: select_line_write_data = line_write_data3;
            3'd4: select_line_write_data = line_write_data4;
            3'd5: select_line_write_data = line_write_data5;
            3'd6: select_line_write_data = line_write_data6;
            default: select_line_write_data = line_write_data7;
        endcase
    end
endfunction

genvar tcw;
generate
    for(tcw = 0; tcw < `L2_WAYS; tcw = tcw + 1) begin : gen_l2_tag_ctrl
        always @(*) begin
            tag_wen[tcw] = tag_write_valid && (tag_write_way == tcw);
            tag_waddr[tcw] = (tag_write_valid &&
                              (tag_write_way == tcw)) ?
                             tag_write_index :
                             {`L2_INDEX_WIDTH{1'b0}};
            tag_din[tcw] = (tag_write_valid &&
                            (tag_write_way == tcw)) ?
                           tag_write_tag :
                           {`L2_TAG_WIDTH{1'b0}};
            tag_ren[tcw] = lookup_valid;
            tag_raddr[tcw] = lookup_valid ?
                             lookup_index :
                             {`L2_INDEX_WIDTH{1'b0}};
        end
    end
endgenerate

genvar dcw;
genvar dcb;
generate
    for(dcw = 0; dcw < `L2_WAYS; dcw = dcw + 1) begin : gen_l2_data_ctrl_way
        for(dcb = 0; dcb < `L2_BANKS; dcb = dcb + 1) begin : gen_l2_data_ctrl_bank
            wire line_write_bank_w;
            wire bank_write_bank_w;

            assign line_write_bank_w =
                line_write_valid && (line_write_way == dcw);
            assign bank_write_bank_w =
                !line_write_valid && bank_write_valid &&
                (bank_write_way == dcw) &&
                (bank_write_bank == dcb);

            always @(*) begin
                data_wen[dcw][dcb] =
                    line_write_bank_w || bank_write_bank_w;
                data_we[dcw][dcb] =
                    (line_write_bank_w || bank_write_bank_w) ?
                    {`L2_WSTRB_WIDTH{1'b1}} :
                    {`L2_WSTRB_WIDTH{1'b0}};
                data_waddr[dcw][dcb] =
                    line_write_bank_w ? line_write_index :
                    bank_write_bank_w ? bank_write_index :
                    {`L2_INDEX_WIDTH{1'b0}};
                data_din[dcw][dcb] =
                    line_write_bank_w ? select_line_write_data(dcb) :
                    bank_write_bank_w ? bank_write_data :
                    {`L2_WORD_WIDTH{1'b0}};
                data_ren[dcw][dcb] = lookup_valid;
                data_raddr[dcw][dcb] = lookup_valid ?
                                       lookup_index :
                                       {`L2_INDEX_WIDTH{1'b0}};
            end
        end
    end
endgenerate

always @(posedge clk) begin
    if(!resetn) begin
        lookup_valid_out_r <= 1'b0;
        lookup_tag_r <= {`L2_TAG_WIDTH{1'b0}};
        lookup_meta_r <= 8'b0;
        read_data_valid_r <= 1'b0;
    end else begin
        lookup_valid_out_r <= lookup_valid;
        read_data_valid_r <= lookup_valid;
        if(lookup_valid) begin
            lookup_tag_r <= lookup_tag;
            lookup_meta_r <= meta_r[lookup_index];
        end

        if(clear_set_valid) begin
            meta_r[clear_set_index] <= 8'b0;
        end else if(clear_valid) begin
            case(clear_way)
                2'd0: begin
                    meta_r[clear_index][0] <= 1'b0;
                    meta_r[clear_index][4] <= 1'b0;
                end
                2'd1: begin
                    meta_r[clear_index][1] <= 1'b0;
                    meta_r[clear_index][5] <= 1'b0;
                end
                2'd2: begin
                    meta_r[clear_index][2] <= 1'b0;
                    meta_r[clear_index][6] <= 1'b0;
                end
                2'd3: begin
                    meta_r[clear_index][3] <= 1'b0;
                    meta_r[clear_index][7] <= 1'b0;
                end
                default: begin
                end
            endcase
        end else if(tag_write_valid) begin
            case(tag_write_way)
                2'd0: begin
                    meta_r[tag_write_index][0] <= tag_write_valid_bit_w;
                    meta_r[tag_write_index][4] <= tag_write_dirty_bit_w;
                end
                2'd1: begin
                    meta_r[tag_write_index][1] <= tag_write_valid_bit_w;
                    meta_r[tag_write_index][5] <= tag_write_dirty_bit_w;
                end
                2'd2: begin
                    meta_r[tag_write_index][2] <= tag_write_valid_bit_w;
                    meta_r[tag_write_index][6] <= tag_write_dirty_bit_w;
                end
                2'd3: begin
                    meta_r[tag_write_index][3] <= tag_write_valid_bit_w;
                    meta_r[tag_write_index][7] <= tag_write_dirty_bit_w;
                end
                default: begin
                end
            endcase
        end
    end
end

genvar gw;
generate
    for(gw = 0; gw < `L2_WAYS; gw = gw + 1) begin : gen_l2_tag_ram
        l2_tagv_ram u_l2_tagv_ram (
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
    for(dw = 0; dw < `L2_WAYS; dw = dw + 1) begin : gen_l2_data_way
        for(db = 0; db < `L2_BANKS; db = db + 1) begin : gen_l2_data_bank
            l2_data_bank_ram u_l2_data_bank_ram (
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
