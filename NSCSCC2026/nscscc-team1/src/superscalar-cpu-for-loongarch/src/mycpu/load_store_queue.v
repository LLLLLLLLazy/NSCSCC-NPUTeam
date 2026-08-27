// `timescale 1ns / 1ps

module load_store_queue #(
    parameter TAG_WIDTH      = 7,
    parameter BID_WIDTH      = 5,
    parameter RESERVED_WIDTH = 32
) (
    input wire clk,
    input wire resetn,

    input wire                 global_flush,//就是flush
    input wire                 predict_flush,
    input wire [BID_WIDTH-1:0] predict_flush_bid,
    input wire [BID_WIDTH-1:0] head_bid,//当前指令的bid

    input wire [2:0] commit_count,//rob给的有几条store要commit

    input  wire                      in_valid,
    output wire                      in_ready,
    input  wire                      in_is_store_or_not_load,
    input  wire                      in_mat,
    input  wire [31:0]               in_address,
    input  wire [3:0]                in_wstrb,
    input  wire [BID_WIDTH-1:0]      in_bid,
    input  wire [RESERVED_WIDTH-1:0] in_reserved,//保留字段，暂时不知道用处

    input wire                 in_prdy,
    input wire [TAG_WIDTH-1:0] in_psrc,
    input wire [31:0]          in_data,

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

    output wire                      out_valid,
    input  wire                      out_ready,
    output wire                      out_is_store_or_not_load,
    output wire                      out_mat,
    output wire [31:0]               out_address,
    output wire [31:0]               out_data,
    output wire [3:0]                out_wstrb,
    output wire [3:0]                load_data_out_bit_mask,
    output wire [BID_WIDTH-1:0]      out_bid,
    output wire [RESERVED_WIDTH-1:0] out_reserved,

    output wire [3:0] sq_uncommitted_count,

    output wire [7:0] sq_entry_valid,
    output wire [7:0] sq_entry_next_prdy,
    output wire [255:0] sq_entry_next_data_flat,
    output wire [8*RESERVED_WIDTH-1:0] sq_entry_reserved_flat
);

    wire flush;
    wire sq_in_valid;
    wire sq_in_ready;
    wire lq_in_valid;
    wire lq_in_ready;
    wire in_fire;

    wire sq_out_valid;
    wire sq_out_ready;
    wire sq_out_mat;
    wire [31:0] sq_out_address;
    wire [31:0] sq_out_data;
    wire [3:0] sq_out_wstrb;
    wire [BID_WIDTH-1:0] sq_out_bid;
    wire [RESERVED_WIDTH-1:0] sq_out_reserved;

    wire lq_out_valid;
    wire lq_out_ready;
    wire lq_out_mat;
    wire [31:0] lq_out_address;
    wire [31:0] lq_out_data;
    wire [3:0] lq_out_wstrb;
    wire [3:0] lq_out_data_bit_mask;
    wire [BID_WIDTH-1:0] lq_out_bid;
    wire [RESERVED_WIDTH-1:0] lq_out_reserved;

    wire store_out_fire;
    wire load_out_fire;
    wire out_fire;
    wire suc_in_fire;
    wire suc_out_fire;

    wire [255:0] sq_entry_address_flat;
    wire [31:0] sq_entry_wstrb_flat;
    wire [255:0] sq_entry_data_flat;
    wire [2:0] sq_head_index;

    wire [7:0] matrix3_set_sq_mask;
    wire [2:0] matrix3_set_lq_index;
    wire [7:0] matrix3_release_mask;

    wire [3:0] sq_flush_surviving_suc_count;
    wire [3:0] lq_flush_surviving_suc_count;

    reg [4:0] global_mat_count;
    wire [4:0] lq_in_older_suc_count;

    assign flush = global_flush || predict_flush;

    //第一次仲裁，进 LQ 还是 SQ
    //1. valid 分配
    assign sq_in_valid = in_valid && in_is_store_or_not_load;
    assign lq_in_valid = in_valid && !in_is_store_or_not_load;

    //2. ready 从两路获取
    assign in_ready = !flush
                    && (in_is_store_or_not_load
                        ? sq_in_ready : lq_in_ready);

    //3. 全局in_fire
    assign in_fire = in_valid && in_ready;

    //下面两行比较关键，决定了 SQ out_valid 的时候， load 让着 store
    //sq_out_valid 信号非常关键
    assign sq_out_ready = !flush && out_ready;
    assign lq_out_ready = !flush && out_ready && !sq_out_valid;

    //全局 out_fire
    assign store_out_fire = sq_out_valid && sq_out_ready;
    assign load_out_fire = lq_out_valid && lq_out_ready;
    assign out_fire = store_out_fire || load_out_fire;

    //整体 wrapper 的输出信号
    assign out_valid = !flush && (sq_out_valid || lq_out_valid);
    assign out_is_store_or_not_load = out_valid && sq_out_valid;
    assign out_mat = sq_out_valid ? sq_out_mat : lq_out_mat;
    assign out_address = sq_out_valid ? sq_out_address : lq_out_address;
    assign out_data = sq_out_valid ? sq_out_data : lq_out_data;
    assign out_wstrb = sq_out_valid ? sq_out_wstrb : lq_out_wstrb;
    assign out_bid = sq_out_valid ? sq_out_bid : lq_out_bid;
    assign out_reserved = sq_out_valid
                        ? sq_out_reserved : lq_out_reserved;

    //load 输出的数据字节掩码
    assign load_data_out_bit_mask
        = (out_valid && !sq_out_valid && lq_out_valid)
        ? lq_out_data_bit_mask : 4'b0;

    //进出是否有 mat = 0 的指令，标志，方便更新全局的 mat_count
    assign suc_in_fire = in_fire && !in_mat;
    assign suc_out_fire = out_fire && !out_mat;

    //传递给 LQ 的 mat_count
    assign lq_in_older_suc_count = global_mat_count
                                 - {{4{1'b0}}, suc_out_fire};

    store_queue #(
        .TAG_WIDTH(TAG_WIDTH),
        .BID_WIDTH(BID_WIDTH),
        .RESERVED_WIDTH(RESERVED_WIDTH)
    ) u_store_queue (
        .clk(clk),
        .resetn(resetn),
        .global_flush(global_flush),
        .predict_flush(predict_flush),
        .predict_flush_bid(predict_flush_bid),
        .head_bid(head_bid),
        .commit_count(commit_count),
        .sq_in_valid(sq_in_valid),
        .sq_in_ready(sq_in_ready),
        .sq_in_mat(in_mat),
        .sq_in_address(in_address),
        .sq_in_wstrb(in_wstrb),
        .sq_in_bid(in_bid),
        .sq_in_reserved(in_reserved),
        .sq_in_prdy(in_prdy),
        .sq_in_psrc(in_psrc),
        .sq_in_data(in_data),
        .bypass1_valid(bypass1_valid),
        .bypass1_dst(bypass1_dst),
        .bypass1_data(bypass1_data),
        .bypass2_valid(bypass2_valid),
        .bypass2_dst(bypass2_dst),
        .bypass2_data(bypass2_data),
        .bypass3_valid(bypass3_valid),
        .bypass3_dst(bypass3_dst),
        .bypass3_data(bypass3_data),
        .bypass4_valid(bypass4_valid),
        .bypass4_dst(bypass4_dst),
        .bypass4_data(bypass4_data),
        .bypass5_valid(bypass5_valid),
        .bypass5_dst(bypass5_dst),
        .bypass5_data(bypass5_data),
        .bypass6_valid(bypass6_valid),
        .bypass6_dst(bypass6_dst),
        .bypass6_data(bypass6_data),
        .bypass7_valid(bypass7_valid),
        .bypass7_dst(bypass7_dst),
        .bypass7_data(bypass7_data),
        .sq_out_valid(sq_out_valid),
        .sq_out_ready(sq_out_ready),
        .sq_out_mat(sq_out_mat),
        .sq_out_address(sq_out_address),
        .sq_out_data(sq_out_data),
        .sq_out_wstrb(sq_out_wstrb),
        .sq_out_bid(sq_out_bid),
        .sq_out_reserved(sq_out_reserved),
        .matrix3_set_sq_mask(matrix3_set_sq_mask),
        .matrix3_set_lq_index(matrix3_set_lq_index),
        .matrix3_release_mask(matrix3_release_mask),
        .sq_entry_valid(sq_entry_valid),
        .sq_entry_next_prdy(sq_entry_next_prdy),
        .sq_entry_address_flat(sq_entry_address_flat),
        .sq_entry_wstrb_flat(sq_entry_wstrb_flat),
        .sq_entry_data_flat(sq_entry_data_flat),
        .sq_entry_next_data_flat(sq_entry_next_data_flat),
        .sq_entry_reserved_flat(sq_entry_reserved_flat),
        .sq_head_index(sq_head_index),
        .sq_uncommitted_count(sq_uncommitted_count),
        .sq_flush_surviving_suc_count(
            sq_flush_surviving_suc_count)
    );

    load_queue #(
        .BID_WIDTH(BID_WIDTH),
        .RESERVED_WIDTH(RESERVED_WIDTH),
        .MAT_COUNT_WIDTH(5)
    ) u_load_queue (
        .clk(clk),
        .resetn(resetn),
        .global_flush(global_flush),
        .predict_flush(predict_flush),
        .predict_flush_bid(predict_flush_bid),
        .head_bid(head_bid),
        .lq_in_valid(lq_in_valid),
        .lq_in_ready(lq_in_ready),
        .lq_in_mat(in_mat),
        .lq_in_address(in_address),
        .lq_in_wstrb(in_wstrb),
        .lq_in_bid(in_bid),
        .lq_in_reserved(in_reserved),
        .lq_in_older_suc_count(lq_in_older_suc_count),
        .suc_out_fire(suc_out_fire),
        .lq_out_valid(lq_out_valid),
        .lq_out_ready(lq_out_ready),
        .lq_out_mat(lq_out_mat),
        .lq_out_address(lq_out_address),
        .lq_out_data(lq_out_data),
        .lq_out_wstrb(lq_out_wstrb),
        .lq_out_data_bit_mask(lq_out_data_bit_mask),
        .lq_out_bid(lq_out_bid),
        .lq_out_reserved(lq_out_reserved),
        .sq_entry_valid(sq_entry_valid),
        .sq_entry_next_prdy(sq_entry_next_prdy),
        .sq_entry_address_flat(sq_entry_address_flat),
        .sq_entry_wstrb_flat(sq_entry_wstrb_flat),
        .sq_entry_data_flat(sq_entry_data_flat),
        .sq_head_index(sq_head_index),
        .store_out_fire(store_out_fire),
        .matrix3_set_sq_mask(matrix3_set_sq_mask),
        .matrix3_set_lq_index(matrix3_set_lq_index),
        .matrix3_release_mask(matrix3_release_mask),
        .lq_flush_surviving_suc_count(
            lq_flush_surviving_suc_count)
    );

    always @(posedge clk) begin
        if (!resetn)
            global_mat_count <= 5'b0;
        else if (flush)
            global_mat_count
                <= {1'b0, sq_flush_surviving_suc_count}
                 + {1'b0, lq_flush_surviving_suc_count};
        else
            global_mat_count
                <= global_mat_count
                 + {{4{1'b0}}, suc_in_fire}
                 - {{4{1'b0}}, suc_out_fire};
    end

`ifdef LQ_SQ_ASSERTIONS
    always @(posedge clk) begin
        if (resetn) begin
            if (global_mat_count > 5'd16) begin
                $display("LOAD_STORE_QUEUE_ASSERT_FAIL mat_count_above_sixteen");
                $finish;
            end
            if (store_out_fire && load_out_fire) begin
                $display("LOAD_STORE_QUEUE_ASSERT_FAIL two_outputs_fired");
                $finish;
            end
            if (flush && (in_ready || out_valid)) begin
                $display("LOAD_STORE_QUEUE_ASSERT_FAIL flush_handshake_visible");
                $finish;
            end
            if (suc_out_fire && global_mat_count == 0) begin
                $display("LOAD_STORE_QUEUE_ASSERT_FAIL suc_output_with_zero_count");
                $finish;
            end
            if (sq_in_valid && lq_in_valid) begin
                $display("LOAD_STORE_QUEUE_ASSERT_FAIL input_routed_twice");
                $finish;
            end
        end
    end
`endif

endmodule
