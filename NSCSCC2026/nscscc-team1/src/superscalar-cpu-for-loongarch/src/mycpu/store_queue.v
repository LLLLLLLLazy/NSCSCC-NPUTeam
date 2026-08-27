// `timescale 1ns / 1ps

module store_queue #(
    parameter TAG_WIDTH      = 7,
    parameter BID_WIDTH      = 5,
    parameter RESERVED_WIDTH = 32
) (
    input wire clk,
    input wire resetn,

    input wire                 global_flush,
    input wire                 predict_flush,
    input wire [BID_WIDTH-1:0] predict_flush_bid,
    input wire [BID_WIDTH-1:0] head_bid,

    input wire [2:0] commit_count,

    input  wire                      sq_in_valid,
    output wire                      sq_in_ready,
    input  wire                      sq_in_mat,
    input  wire [31:0]               sq_in_address,
    input  wire [3:0]                sq_in_wstrb,
    input  wire [BID_WIDTH-1:0]      sq_in_bid,
    input  wire [RESERVED_WIDTH-1:0] sq_in_reserved,
    input  wire                      sq_in_prdy,
    input  wire [TAG_WIDTH-1:0]      sq_in_psrc,
    input  wire [31:0]               sq_in_data,

    input wire                 bypass1_valid,
    input wire [TAG_WIDTH-1:0] bypass1_dst,
    input wire [31:0]          bypass1_data,
    input wire                 bypass2_valid,
    input wire [TAG_WIDTH-1:0] bypass2_dst,
    input wire [31:0]          bypass2_data,
    input wire                 bypass3_valid,
    input wire [TAG_WIDTH-1:0] bypass3_dst,
    input wire [31:0]          bypass3_data,
    input wire                 bypass4_valid,
    input wire [TAG_WIDTH-1:0] bypass4_dst,
    input wire [31:0]          bypass4_data,
    input wire                 bypass5_valid,
    input wire [TAG_WIDTH-1:0] bypass5_dst,
    input wire [31:0]          bypass5_data,
    input wire                 bypass6_valid,
    input wire [TAG_WIDTH-1:0] bypass6_dst,
    input wire [31:0]          bypass6_data,
    input wire                 bypass7_valid,
    input wire [TAG_WIDTH-1:0] bypass7_dst,
    input wire [31:0]          bypass7_data,

    output wire                      sq_out_valid,
    input  wire                      sq_out_ready,
    output wire                      sq_out_mat,
    output wire [31:0]               sq_out_address,
    output wire [31:0]               sq_out_data,
    output wire [3:0]                sq_out_wstrb,
    output wire [BID_WIDTH-1:0]      sq_out_bid,
    output wire [RESERVED_WIDTH-1:0] sq_out_reserved,

    input wire [7:0] matrix3_set_sq_mask,
    input wire [2:0] matrix3_set_lq_index,
    input wire [7:0] matrix3_release_mask,

    output wire [7:0]   sq_entry_valid,
    output wire [7:0]   sq_entry_next_prdy,
    output wire [255:0] sq_entry_address_flat,
    output wire [31:0]  sq_entry_wstrb_flat,
    output wire [255:0] sq_entry_data_flat,
    output wire [255:0] sq_entry_next_data_flat,
    output wire [8*RESERVED_WIDTH-1:0] sq_entry_reserved_flat,
    output wire [2:0]   sq_head_index,

    output wire [3:0] sq_uncommitted_count,

    output wire [3:0] sq_flush_surviving_suc_count
);

    reg [7:0] sq_valid;
    reg [7:0] sq_prdy;
    reg [7:0] sq_mat;
    reg [TAG_WIDTH-1:0]      sq_psrc    [7:0];
    reg [31:0]               sq_address [7:0];
    reg [31:0]               sq_data    [7:0];
    reg [3:0]                sq_wstrb   [7:0];
    reg [BID_WIDTH-1:0]      sq_bid     [7:0];
    reg [RESERVED_WIDTH-1:0] sq_reserved[7:0];

    reg [2:0] sq_head;
    reg [2:0] sq_tail;
    reg [3:0] sq_count;
    reg [3:0] committed_count;

    reg [7:0] matrix3 [7:0];

    wire flush;
    wire sq_in_fire;
    wire sq_out_fire;
    wire sq_tail_allocatable;

    wire [7:0] sq_next_prdy;
    wire [255:0] sq_next_data_flat;
    wire [7:0] sq_committed_mask;
    wire [7:0] sq_live_interval_mask;
    wire [7:0] sq_global_survivor_mask;
    wire [7:0] sq_predict_survivor_mask;
    wire [7:0] sq_selected_survivor_mask;
    wire [3:0] sq_predict_survivor_count;
    wire [3:0] sq_valid_count;

    wire new_store_hit1;
    wire new_store_hit2;
    wire new_store_hit3;
    wire new_store_hit4;
    wire new_store_hit5;
    wire new_store_hit6;
    wire new_store_hit7;
    wire new_store_prdy;
    wire [31:0] new_store_data;

    wire [7:0] matrix3_set_lq_onehot;
    wire [7:0] matrix3_next [7:0];

    function circle_comparator;
        input [BID_WIDTH-1:0] head;
        input [BID_WIDTH-1:0] a;
        input [BID_WIDTH-1:0] b;
        reg a_ge_head;
        reg b_ge_head;
        begin
            a_ge_head = a >= head;
            b_ge_head = b >= head;
            circle_comparator =
                   ( a_ge_head &&  b_ge_head && a > b)
                || (!a_ge_head &&  b_ge_head)
                || (!a_ge_head && !b_ge_head && a > b);
        end
    endfunction

    function [31:0] format_store_data;
        input [31:0] raw_data;
        input [3:0] byte_mask;
        begin
            case (byte_mask)
                4'b0001,
                4'b0010,
                4'b0100,
                4'b1000: format_store_data = {4{raw_data[7:0]}};
                4'b0011,
                4'b1100: format_store_data = {2{raw_data[15:0]}};
                default: format_store_data = raw_data;
            endcase
        end
    endfunction

    assign flush = global_flush || predict_flush;

    assign sq_tail_allocatable = !sq_valid[sq_tail]
                               && (matrix3[sq_tail] == 8'b0);
    assign sq_in_ready = !flush
                       && (sq_count < 4'd8)
                       && sq_tail_allocatable;
    assign sq_in_fire = sq_in_valid && sq_in_ready;

    assign sq_out_valid = !flush
                        && sq_valid[sq_head]
                        && (committed_count != 4'b0)
                        && sq_next_prdy[sq_head];
    assign sq_out_fire = sq_out_valid && sq_out_ready;

    assign sq_out_mat      = sq_mat[sq_head];
    assign sq_out_address  = sq_address[sq_head];
    assign sq_out_data     = sq_next_data_flat[sq_head*32 +: 32];//表示从 start 开始，向高位选择 width 位
    assign sq_out_wstrb    = sq_wstrb[sq_head];
    assign sq_out_bid      = sq_bid[sq_head];
    assign sq_out_reserved = sq_reserved[sq_head];

    assign sq_entry_valid        = sq_valid;
    assign sq_entry_next_prdy    = sq_next_prdy;
    assign sq_entry_next_data_flat = sq_next_data_flat;
    assign sq_head_index         = sq_head;
    assign sq_uncommitted_count  = sq_count - committed_count;

    //新入队的 store 也算一下 bypass hit，若命中则直接使用 bypass 的数据
    assign new_store_hit1 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass1_valid && bypass1_dst == sq_in_psrc;
    assign new_store_hit2 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass2_valid && bypass2_dst == sq_in_psrc;
    assign new_store_hit3 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass3_valid && bypass3_dst == sq_in_psrc;
    assign new_store_hit4 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass4_valid && bypass4_dst == sq_in_psrc;
    assign new_store_hit5 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass5_valid && bypass5_dst == sq_in_psrc;
    assign new_store_hit6 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass6_valid && bypass6_dst == sq_in_psrc;
    assign new_store_hit7 = !sq_in_prdy && (|sq_in_psrc)
                          && bypass7_valid && bypass7_dst == sq_in_psrc;

    assign new_store_prdy = sq_in_prdy
                           || new_store_hit1
                           || new_store_hit2
                           || new_store_hit3
                           || new_store_hit4
                           || new_store_hit5
                           || new_store_hit6
                           || new_store_hit7;

    assign new_store_data = sq_in_prdy      ? sq_in_data
                          : new_store_hit1  ? bypass1_data
                          : new_store_hit2  ? bypass2_data
                          : new_store_hit3  ? bypass3_data
                          : new_store_hit4  ? bypass4_data
                          : new_store_hit5  ? bypass5_data
                          : new_store_hit6  ? bypass6_data
                          : new_store_hit7  ? bypass7_data
                          : sq_in_data;

    assign sq_predict_survivor_count =
          {3'b0, sq_predict_survivor_mask[0]}
        + {3'b0, sq_predict_survivor_mask[1]}
        + {3'b0, sq_predict_survivor_mask[2]}
        + {3'b0, sq_predict_survivor_mask[3]}
        + {3'b0, sq_predict_survivor_mask[4]}
        + {3'b0, sq_predict_survivor_mask[5]}
        + {3'b0, sq_predict_survivor_mask[6]}
        + {3'b0, sq_predict_survivor_mask[7]};

    assign sq_valid_count =
          {3'b0, sq_valid[0]}
        + {3'b0, sq_valid[1]}
        + {3'b0, sq_valid[2]}
        + {3'b0, sq_valid[3]}
        + {3'b0, sq_valid[4]}
        + {3'b0, sq_valid[5]}
        + {3'b0, sq_valid[6]}
        + {3'b0, sq_valid[7]};

    assign sq_global_survivor_mask = sq_committed_mask;
    assign sq_selected_survivor_mask = global_flush
                                     ? sq_global_survivor_mask
                                     : sq_predict_survivor_mask;

    //计算 global flush 和 predict flush 之后，存活的store entry的数量
    assign sq_flush_surviving_suc_count =
          {3'b0, sq_selected_survivor_mask[0] && !sq_mat[0]}
        + {3'b0, sq_selected_survivor_mask[1] && !sq_mat[1]}
        + {3'b0, sq_selected_survivor_mask[2] && !sq_mat[2]}
        + {3'b0, sq_selected_survivor_mask[3] && !sq_mat[3]}
        + {3'b0, sq_selected_survivor_mask[4] && !sq_mat[4]}
        + {3'b0, sq_selected_survivor_mask[5] && !sq_mat[5]}
        + {3'b0, sq_selected_survivor_mask[6] && !sq_mat[6]}
        + {3'b0, sq_selected_survivor_mask[7] && !sq_mat[7]};

    //通过相关 load 的 index 转换成 onehot 方便更新 matrix3
    assign matrix3_set_lq_onehot = (|matrix3_set_sq_mask)
                                 ? (8'b0000_0001 << matrix3_set_lq_index)
                                 : 8'b0;

    genvar store_index;
    generate
        for (store_index = 0; store_index < 8;
             store_index = store_index + 1) begin : gen_store_entry

            localparam [2:0] STORE_INDEX = store_index;

            wire [2:0] store_age;
            wire store_bypass_hit1;
            wire store_bypass_hit2;
            wire store_bypass_hit3;
            wire store_bypass_hit4;
            wire store_bypass_hit5;
            wire store_bypass_hit6;
            wire store_bypass_hit7;
            wire store_bypass_hit;
            wire store_waiting_for_data;
            wire [31:0] store_next_data;
            wire store_is_committed;
            wire store_bid_greater;
            wire allocate_this_store;
            wire global_survivor;
            wire predict_survivor;

            //当前store 是否比predict_flush_bid更大，
            //若是则说明该store在预测flush之后，不会被保留
            assign store_bid_greater = circle_comparator(
                head_bid, sq_bid[store_index], predict_flush_bid);

            //分别算每一个store的年龄
            assign store_age = STORE_INDEX - sq_head;

            //8位的在 sq_count 约束下的掩码，本质是head到tail之间的store entry的掩码
            assign sq_live_interval_mask[store_index]
                = ({1'b0, store_age} < sq_count);
            
            //这个 store entry 是否由于 commit 而无敌
            assign store_is_committed = sq_valid[store_index]
                                      && ({1'b0, store_age}
                                          < committed_count);

            //无敌掩码
            assign sq_committed_mask[store_index] = store_is_committed;

            //predict flush 的时候，存活掩码
            assign sq_predict_survivor_mask[store_index]
                = sq_valid[store_index]
                && (store_is_committed
                    || !store_bid_greater);

            //根据七路旁路更新store entry的rdy和data
            assign store_waiting_for_data = sq_valid[store_index]
                                          && !sq_prdy[store_index]
                                          && (|sq_psrc[store_index]);
            assign store_bypass_hit1 = store_waiting_for_data
                                     && bypass1_valid
                                     && bypass1_dst == sq_psrc[store_index];
            assign store_bypass_hit2 = store_waiting_for_data
                                     && bypass2_valid
                                     && bypass2_dst == sq_psrc[store_index];
            assign store_bypass_hit3 = store_waiting_for_data
                                     && bypass3_valid
                                     && bypass3_dst == sq_psrc[store_index];
            assign store_bypass_hit4 = store_waiting_for_data
                                     && bypass4_valid
                                     && bypass4_dst == sq_psrc[store_index];
            assign store_bypass_hit5 = store_waiting_for_data
                                     && bypass5_valid
                                     && bypass5_dst == sq_psrc[store_index];
            assign store_bypass_hit6 = store_waiting_for_data
                                     && bypass6_valid
                                     && bypass6_dst == sq_psrc[store_index];
            assign store_bypass_hit7 = store_waiting_for_data
                                     && bypass7_valid
                                     && bypass7_dst == sq_psrc[store_index];
            assign store_bypass_hit = store_bypass_hit1
                                    || store_bypass_hit2
                                    || store_bypass_hit3
                                    || store_bypass_hit4
                                    || store_bypass_hit5
                                    || store_bypass_hit6
                                    || store_bypass_hit7;

            assign sq_next_prdy[store_index]
                = sq_prdy[store_index] || store_bypass_hit;

            assign store_next_data = sq_prdy[store_index]
                                   ? sq_data[store_index]
                                   : store_bypass_hit1 ? bypass1_data
                                   : store_bypass_hit2 ? bypass2_data
                                   : store_bypass_hit3 ? bypass3_data
                                   : store_bypass_hit4 ? bypass4_data
                                   : store_bypass_hit5 ? bypass5_data
                                   : store_bypass_hit6 ? bypass6_data
                                   : store_bypass_hit7 ? bypass7_data
                                   : sq_data[store_index];

            //更新store entry 的data
            assign sq_next_data_flat[store_index*32 +: 32]
                = store_next_data;

            // SQ 内保持 raw producer data；只在交给 LQ forwarding 时按
            // byte lane 展开，使 wstrb 选中的 lane 含有真正待写字节。
            assign sq_entry_address_flat[store_index*32 +: 32]
                = sq_address[store_index];

            assign sq_entry_wstrb_flat[store_index*4 +: 4]
                = sq_wstrb[store_index];

            assign sq_entry_data_flat[store_index*32 +: 32]
                = format_store_data(
                    store_next_data, sq_wstrb[store_index]);

            assign sq_entry_reserved_flat[
                store_index*RESERVED_WIDTH +: RESERVED_WIDTH]
                = sq_reserved[store_index];

            //表示找到了一个store entry，准备分配给新的store指令
            assign allocate_this_store = sq_in_fire
                                       && sq_tail == STORE_INDEX;
            assign global_survivor = sq_global_survivor_mask[store_index];
            assign predict_survivor = sq_predict_survivor_mask[store_index];

            //更新 store entry 各个数据项
            always @(posedge clk) begin
                if (!resetn) begin
                    sq_prdy[store_index]    <= 1'b0;
                    sq_psrc[store_index]    <= {TAG_WIDTH{1'b0}};
                    sq_mat[store_index]     <= 1'b0;
                    sq_address[store_index] <= 32'b0;
                    sq_data[store_index]    <= 32'b0;
                    sq_wstrb[store_index]   <= 4'b0;
                    sq_bid[store_index]     <= {BID_WIDTH{1'b0}};
                    sq_reserved[store_index]
                        <= {RESERVED_WIDTH{1'b0}};

                end else if (global_flush) begin
                    if (global_survivor) begin//直接保留该store entry
                        sq_prdy[store_index]
                            <= sq_next_prdy[store_index];
                        sq_data[store_index] <= store_next_data;
                    end else begin
                        sq_prdy[store_index] <= 1'b0;
                    end

                end else if (predict_flush) begin
                    if (predict_survivor) begin
                        sq_prdy[store_index]
                            <= sq_next_prdy[store_index];
                        sq_data[store_index] <= store_next_data;
                    end else begin
                        sq_prdy[store_index] <= 1'b0;
                    end

                end else if (allocate_this_store) begin
                    sq_prdy[store_index]    <= new_store_prdy;
                    sq_psrc[store_index]    <= sq_in_psrc;
                    sq_mat[store_index]     <= sq_in_mat;
                    sq_address[store_index] <= sq_in_address;
                    sq_data[store_index]    <= new_store_data;
                    sq_wstrb[store_index]   <= sq_in_wstrb;
                    sq_bid[store_index]     <= sq_in_bid;
                    sq_reserved[store_index] <= sq_in_reserved;

                end else if (sq_valid[store_index]) begin
                    sq_prdy[store_index] <= sq_next_prdy[store_index];
                    sq_data[store_index] <= store_next_data;
                end
            end
        end
    endgenerate

    //matrix3是一个8x8的矩阵，表示store和load之间的相关性
    //matrix3的每一行表示一个store entry，matrix3的每一列表示一个load entry
    //matrix3的每一行的每一位为1表示该store entry和对应的load entry相关，为0表示不相关
    genvar matrix3_store_index;
    generate
        for (matrix3_store_index = 0; matrix3_store_index < 8;
             matrix3_store_index = matrix3_store_index + 1) begin

            assign matrix3_next[matrix3_store_index]
                = (matrix3[matrix3_store_index] & ~matrix3_release_mask)//load出队或者是被flush了需要清空store矩阵对应的位置
                | ({8{matrix3_set_sq_mask[matrix3_store_index]}}//判断该store是否跟新的load有相关
                   & matrix3_set_lq_onehot);//如果相关根据相关的onehot更新矩阵

            always @(posedge clk) begin
                if (!resetn)
                    matrix3[matrix3_store_index] <= 8'b0;
                else
                    matrix3[matrix3_store_index]
                        <= matrix3_next[matrix3_store_index];
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn) begin
            sq_valid <= 8'b0;
        end else if (global_flush) begin
            sq_valid <= sq_global_survivor_mask;
        end else if (predict_flush) begin
            sq_valid <= sq_predict_survivor_mask;
        end else begin
            if (sq_out_fire)
                sq_valid[sq_head] <= 1'b0;
            if (sq_in_fire)
                sq_valid[sq_tail] <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!resetn)
            sq_head <= 3'b0;
        else if (global_flush)
            sq_head <= sq_head;
        else if (predict_flush)
            sq_head <= sq_head;
        else
            sq_head <= sq_head + {{2{1'b0}}, sq_out_fire};
    end

    always @(posedge clk) begin
        if (!resetn)
            sq_tail <= 3'b0;
        else if (global_flush)
            sq_tail <= sq_head + committed_count[2:0];
        else if (predict_flush)
            sq_tail <= sq_head + sq_predict_survivor_count[2:0];
        else
            sq_tail <= sq_tail + {{2{1'b0}}, sq_in_fire};
    end

    always @(posedge clk) begin
        if (!resetn)
            sq_count <= 4'b0;
        else if (global_flush)
            sq_count <= committed_count;
        else if (predict_flush)
            sq_count <= sq_predict_survivor_count;
        else
            sq_count <= sq_count
                      + {{3{1'b0}}, sq_in_fire}
                      - {{3{1'b0}}, sq_out_fire};
    end

    always @(posedge clk) begin
        if (!resetn)
            committed_count <= 4'b0;
        else if (global_flush)
            committed_count <= committed_count;
        else if (predict_flush)
            committed_count <= committed_count;
        else
            committed_count <= committed_count
                             + {1'b0, commit_count}
                             - {{3{1'b0}}, sq_out_fire};
    end

`ifdef SQ_DEBUG
    always @(posedge clk) begin
        if (resetn
                && (($time >= 1247000 && $time <= 1249000)
                    || (sq_in_valid && sq_in_address == 32'h000d0010)
                    || (sq_out_valid && sq_out_address == 32'h000d0010))
                && (sq_in_valid || sq_out_valid || sq_in_fire || sq_out_fire
                    || commit_count != 3'b0 || global_flush
                    || predict_flush)) begin
            $display("SQ_DEBUG t=%0t in=%b/%b in_addr=%08x out=%b/%b out_addr=%08x out_data=%08x wstrb=%x head=%0d tail=%0d count=%0d committed=%0d commit_add=%0d valid=%02x gflush=%b pflush=%b pfbid=%0d hbid=%0d survivors=%02x",
                     $time, sq_in_valid, sq_in_fire, sq_in_address,
                     sq_out_valid, sq_out_fire, sq_out_address, sq_out_data,
                     sq_out_wstrb, sq_head, sq_tail, sq_count,
                     committed_count, commit_count, sq_valid, global_flush,
                     predict_flush, predict_flush_bid, head_bid,
                     sq_predict_survivor_mask);
        end
    end
`endif

`ifdef LQ_SQ_ASSERTIONS
    always @(posedge clk) begin
        if (resetn) begin
            if (sq_count > 4'd8) begin
                $display("STORE_QUEUE_ASSERT_FAIL count_above_eight");
                $finish;
            end
            if (committed_count > sq_count) begin
                $display("STORE_QUEUE_ASSERT_FAIL committed_above_count");
                $finish;
            end
            if (sq_valid_count != sq_count) begin
                $display("STORE_QUEUE_ASSERT_FAIL valid_count_mismatch");
                $finish;
            end
            if (sq_valid != sq_live_interval_mask) begin
                $display("STORE_QUEUE_ASSERT_FAIL live_interval_not_contiguous");
                $finish;
            end
            if (commit_count > 3'd4) begin
                $display("STORE_QUEUE_ASSERT_FAIL commit_count_above_four");
                $finish;
            end
            if (!flush
                && commit_count > (sq_count - committed_count)) begin
                $display("STORE_QUEUE_ASSERT_FAIL commit_exceeds_uncommitted");
                $finish;
            end
            if (flush && commit_count != 3'b0) begin
                $display("STORE_QUEUE_ASSERT_FAIL flush_commit_nonzero");
                $finish;
            end
            if (sq_in_fire
                && (sq_valid[sq_tail] || matrix3[sq_tail] != 8'b0)) begin
                $display("STORE_QUEUE_ASSERT_FAIL allocated_nonfree_tail");
                $finish;
            end
            if (sq_out_fire && committed_count == 4'b0) begin
                $display("STORE_QUEUE_ASSERT_FAIL uncommitted_store_fired");
                $finish;
            end
        end
    end
`endif

endmodule
