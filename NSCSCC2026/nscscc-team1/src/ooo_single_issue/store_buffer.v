module store_buffer (
    input wire clk,
    input wire resetn,

    input  wire        store_valid,
    output wire        store_ready,
    input  wire [ 3:0] store_wstrb,
    input  wire [31:0] store_address,
    input  wire [31:0] store_data,
    input  wire [ 4:0] store_bid,
    input  wire [ 1:0] store_mat,
    input  wire [31:0] store_address_pa,

    input  wire [31:0] load_address,
    input  wire [ 1:0] load_mat,
    output wire [ 3:0] load_wstrb,
    output wire [31:0] load_data,
    input  wire [31:0] load_address_pa,

    input  wire        commit_valid,
    output wire [31:0] commit_address,
    output wire [31:0] commit_data,
    output wire [ 3:0] commit_wstrb,
    output wire [ 1:0] commit_mat,
    output wire [31:0] commit_address_pa,


    output wire suc,

    input wire flush,


    input wire       predict_flush,
    input wire [4:0] predict_flush_bid,
    input wire [4:0] head_bid
);



    wire        store_fire;

    reg  [31:0] address_pa              [15:0];
    reg  [31:0] data                    [15:0];
    reg  [ 3:0] byte_wstrb              [15:0];
    reg  [15:0] valid;
    reg  [ 4:0] bid                     [15:0];
    reg  [ 3:0] tail;
    reg  [ 1:0] mat                     [15:0];
    reg  [31:0] address                 [15:0];

    wire        full;

    wire [15:0] match_mask;
    wire [15:0] valid_wstrb_match       [ 3:0];
    wire [15:0] valid_wstrb_match_notice[ 3:0];
    wire [15:0] valid_wstrb_match_onehot[ 3:0];

    wire [ 3:0] or_load_wstrb;
    wire [31:0] or_maskdata;
    wire [31:0] maskdata_enable [15:0];
    wire [31:0] masked_data     [15:0];
    wire [15:0] maskdata_and    [31:0];

    wire [15:0] greater_bid;
    wire [15:0] predict_flush_valid;

    genvar i;
    genvar data_bit;

    assign full              = tail == 4'd15;

    assign store_ready       = !full && !predict_flush;

    assign store_fire        = store_ready && store_valid;


    assign commit_address_pa = address_pa[0];
    assign commit_data       = data[0];
    assign commit_wstrb      = byte_wstrb[0];
    assign commit_mat        = mat[0];
    assign commit_address    = address[0];

    wire [3:0] predict_flush_tail;

    assign predict_flush_valid = ~greater_bid & valid;

    always @(posedge clk) begin
        if (!resetn || flush) begin
            tail <= 4'b0;
        end else if (predict_flush) begin
            tail <= predict_flush_tail;
        end else begin
            case ({
                store_fire, commit_valid
            })
                2'b10:   tail <= tail + 4'd1;
                2'b01:   tail <= tail - 4'd1;
                default: tail <= tail;
            endcase
        end
    end


    popcount16 u_popcount16 (
        .data (predict_flush_valid),
        .count(predict_flush_tail)
    );



    generate

        for (i = 15; i >= 0; i = i - 1) begin : gen_match_mask
            assign match_mask[i]           = address_pa[i][31:2] == load_address_pa[31:2];
            assign valid_wstrb_match[0][i] = match_mask[i] && valid[i] && byte_wstrb[i][0];
            assign valid_wstrb_match[1][i] = match_mask[i] && valid[i] && byte_wstrb[i][1];
            assign valid_wstrb_match[2][i] = match_mask[i] && valid[i] && byte_wstrb[i][2];
            assign valid_wstrb_match[3][i] = match_mask[i] && valid[i] && byte_wstrb[i][3];
        end
        assign valid_wstrb_match_notice[0][15] = valid_wstrb_match[0][15];
        assign valid_wstrb_match_notice[1][15] = valid_wstrb_match[1][15];
        assign valid_wstrb_match_notice[2][15] = valid_wstrb_match[2][15];
        assign valid_wstrb_match_notice[3][15] = valid_wstrb_match[3][15];


        assign valid_wstrb_match_onehot[0][15] = valid_wstrb_match[0][15];
        assign valid_wstrb_match_onehot[1][15] = valid_wstrb_match[1][15];
        assign valid_wstrb_match_onehot[2][15] = valid_wstrb_match[2][15];
        assign valid_wstrb_match_onehot[3][15] = valid_wstrb_match[3][15];

        for (i = 14; i >= 0; i = i - 1) begin : gen_valid_wstrb_match_notice_and_onehot
            assign valid_wstrb_match_notice[0][i] = valid_wstrb_match[0][i] || valid_wstrb_match_notice[0][i+1];
            assign valid_wstrb_match_notice[1][i] = valid_wstrb_match[1][i] || valid_wstrb_match_notice[1][i+1];
            assign valid_wstrb_match_notice[2][i] = valid_wstrb_match[2][i] || valid_wstrb_match_notice[2][i+1];
            assign valid_wstrb_match_notice[3][i] = valid_wstrb_match[3][i] || valid_wstrb_match_notice[3][i+1];

            assign valid_wstrb_match_onehot[0][i] = valid_wstrb_match[0][i] && !valid_wstrb_match_notice[0][i+1];
            assign valid_wstrb_match_onehot[1][i] = valid_wstrb_match[1][i] && !valid_wstrb_match_notice[1][i+1];
            assign valid_wstrb_match_onehot[2][i] = valid_wstrb_match[2][i] && !valid_wstrb_match_notice[2][i+1];
            assign valid_wstrb_match_onehot[3][i] = valid_wstrb_match[3][i] && !valid_wstrb_match_notice[3][i+1];
        end
    endgenerate


    generate
        assign or_load_wstrb[3] = |valid_wstrb_match_notice[3];
        assign or_load_wstrb[2] = |valid_wstrb_match_notice[2];
        assign or_load_wstrb[1] = |valid_wstrb_match_notice[1];
        assign or_load_wstrb[0] = |valid_wstrb_match_notice[0];
        for (i = 0; i <= 4'd15; i = i + 1) begin : gen_maskdata_and
            assign maskdata_enable[i] = {
                {8{valid_wstrb_match_onehot[3][i]}},
                {8{valid_wstrb_match_onehot[2][i]}},
                {8{valid_wstrb_match_onehot[1][i]}},
                {8{valid_wstrb_match_onehot[0][i]}}
            };
            assign masked_data[i] = maskdata_enable[i] & data[i];
        end

        for (data_bit = 0; data_bit < 32; data_bit = data_bit + 1) begin : gen_or_maskdata
            for (i = 0; i <= 4'd15; i = i + 1) begin : gen_maskdata_bit
                assign maskdata_and[data_bit][i] = masked_data[i][data_bit];
            end
            assign or_maskdata[data_bit] = |maskdata_and[data_bit];
        end
    endgenerate

    assign load_wstrb = load_mat == 2'b00 ? 4'b0000 : or_load_wstrb;
    assign load_data  = or_maskdata;


    generate
        for (i = 0; i <= 15; i = i + 1) begin : gen_greater_bid
            circle_comparator u_circle_comparator (
                .head  (head_bid),
                .a     (bid[i]),
                .b     (predict_flush_bid),
                .a_gt_b(greater_bid[i])
            );
        end
    endgenerate




    wire        or_suc;
    wire [15:0] suc_and;

    generate
        for (i = 0; i <= 15; i = i + 1) begin : gen_suc
            assign suc_and[i] = valid[i] && (mat[i] == 2'b00);
        end
    endgenerate

    assign or_suc = |suc_and;
    assign suc = or_suc;


    generate
        always @(posedge clk) begin
            if (!resetn || flush) begin
                valid[15] <= 1'b0;
            end
        end

        for (i = 0; i <= 14; i = i + 1) begin : gen_valid
            always @(posedge clk) begin
                if (!resetn || flush) begin
                    valid[i] <= 1'b0;
                end else if (predict_flush) begin
                    valid[i] <= predict_flush_valid[i];
                end else if (store_fire && !commit_valid && i == tail || store_fire && commit_valid && i == tail - 1) begin
                    valid[i]      <= 1'b1;
                    address_pa[i] <= store_address_pa;
                    data[i]       <= store_data;
                    byte_wstrb[i] <= store_wstrb;
                    bid[i]        <= store_bid;
                    mat[i]        <= store_mat;
                    address[i]    <= store_address;
                end else if (commit_valid) begin
                    valid[i]      <= valid[i+1];
                    address_pa[i] <= address_pa[i+1];
                    data[i]       <= data[i+1];
                    byte_wstrb[i] <= byte_wstrb[i+1];
                    bid[i]        <= bid[i+1];
                    mat[i]        <= mat[i+1];
                    address[i]    <= address[i+1];
                end
            end
        end
    endgenerate

endmodule
