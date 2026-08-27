`include "header.v"

module store_buffer (
        input wire clk,
        input wire resetn,

        input  wire        store_valid,
        output wire        store_ready,
        input  wire [ 3:0] store_wstrb,
        input  wire [31:0] store_address,
        input  wire [31:0] store_data,
        input  wire [ 4:0] store_bid,
        input  wire [`ROB_ID_WIDTH-1:0] store_rob_id,
        input  wire [ 1:0] store_mat,
        input  wire [31:0] store_address_pa,

        input  wire [31:0] load_address,
        input  wire [ 1:0] load_mat,
        output wire [ 3:0] load_wstrb,
        output wire [31:0] load_data,
        input  wire [31:0] load_address_pa,

        input  wire [2:0] commit_count,
        output wire [3:0] uncommitted_count,

        output wire        drain_valid,
        input  wire        drain_ready,
        output wire [31:0] drain_address,
        output wire [31:0] drain_data,
        output wire [ 3:0] drain_wstrb,
        output wire [ 1:0] drain_mat,
        output wire [31:0] drain_address_pa,
        output wire [ 4:0] drain_bid,
        output wire [`ROB_ID_WIDTH-1:0] drain_rob_id,

        output reg  [ 3:0] committed_count,


        output wire suc,

        input wire flush,


        input wire       predict_flush,
        input wire [4:0] predict_flush_bid,
        input wire [4:0] head_bid
    );



    wire        store_fire;
    wire        drain_fire;

    reg  [31:0] address_pa              [15:0];
    reg  [31:0] data                    [15:0];
    reg  [ 3:0] byte_wstrb              [15:0];
    reg  [15:0] valid;
    reg  [ 4:0] bid                     [15:0];
    reg  [`ROB_ID_WIDTH-1:0] rob_id      [15:0];
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
    wire [15:0] committed_entry_mask;
    wire [15:0] predict_flush_valid;

    genvar i;
    genvar data_bit;

    assign full              = tail == 4'd15;

    assign store_ready       = !full && !predict_flush;

    assign store_fire        = store_ready && store_valid;
    assign uncommitted_count = tail - committed_count;

    assign drain_valid       = (committed_count != 4'd0)  ;
    assign drain_fire        = drain_valid && drain_ready;


    assign drain_address_pa = address_pa[0];
    assign drain_data       = data[0];
    assign drain_wstrb      = byte_wstrb[0];
    assign drain_mat        = mat[0];
    assign drain_address    = address[0];
    assign drain_bid        = bid[0];
    assign drain_rob_id     = rob_id[0];

    wire [4:0] predict_flush_count;

    assign predict_flush_valid =
           valid & (committed_entry_mask | ~greater_bid);

    always @(posedge clk) begin
        if (!resetn) begin
            tail <= 4'b0;
            committed_count <= 4'd0;
        end
        else if (flush) begin
            // A global redirect discards only the speculative suffix.  Stores
            // already retired from the ROB remain architecturally visible and
            // must still drain to the cache.
            tail <= committed_count;
        end
        else if (predict_flush) begin
            tail <= predict_flush_count[3:0];
        end
        else begin
            case ({
                          store_fire, drain_fire
                      })
                2'b10:
                    tail <= tail + 4'd1;
                2'b01:
                    tail <= tail - 4'd1;
                default:
                    tail <= tail;
            endcase

            committed_count <= committed_count +
                            {1'b0, commit_count} -
                            {{3{1'b0}}, drain_fire};
        end
    end


    popcount16 u_popcount16 (
                   .data (predict_flush_valid),
                   .count(predict_flush_count)
               );



    generate
        for (i = 0; i < 15; i = i + 1) begin : gen_committed_mask
            localparam [3:0] ENTRY_INDEX = i;
            assign committed_entry_mask[i] =
                   committed_count > ENTRY_INDEX;
        end
        assign committed_entry_mask[15] = 1'b0;

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


    wire [3:0] store_write_index =
         tail - {{3{1'b0}}, drain_fire};
    integer entry;

    always @(posedge clk) begin
        if (!resetn) begin
            valid <= 16'd0;
        end
        else if (flush) begin
            for (entry = 0; entry < 16; entry = entry + 1) begin
                if (entry >= committed_count)
                    valid[entry] <= 1'b0;
            end
        end
        else if (predict_flush) begin
            valid <= predict_flush_valid;
        end
        else begin
            if (drain_fire) begin
                for (entry = 0; entry < 15; entry = entry + 1) begin
                    valid[entry]      <= valid[entry+1];
                    address_pa[entry] <= address_pa[entry+1];
                    data[entry]       <= data[entry+1];
                    byte_wstrb[entry] <= byte_wstrb[entry+1];
                    bid[entry]        <= bid[entry+1];
                    rob_id[entry]     <= rob_id[entry+1];
                    mat[entry]        <= mat[entry+1];
                    address[entry]    <= address[entry+1];
                end
                valid[15] <= 1'b0;
            end

            // When enqueue and drain happen together, the shift makes the new
            // tail slot tail-1.  This assignment intentionally has priority
            // over the shift assignment for that slot.
            if (store_fire) begin
                valid[store_write_index]      <= 1'b1;
                address_pa[store_write_index] <= store_address_pa;
                data[store_write_index]       <= store_data;
                byte_wstrb[store_write_index] <= store_wstrb;
                bid[store_write_index]        <= store_bid;
                rob_id[store_write_index]     <= store_rob_id;
                mat[store_write_index]        <= store_mat;
                address[store_write_index]    <= store_address;
            end
        end
    end

endmodule
