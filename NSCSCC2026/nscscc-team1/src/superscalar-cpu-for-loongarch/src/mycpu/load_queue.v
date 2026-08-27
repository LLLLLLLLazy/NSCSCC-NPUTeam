// `timescale 1ns / 1ps

module load_queue #(
    parameter BID_WIDTH       = 5,
    parameter RESERVED_WIDTH  = 32,
    parameter MAT_COUNT_WIDTH = 5
) (
    input wire clk,
    input wire resetn,

    input wire                 global_flush,
    input wire                 predict_flush,
    input wire [BID_WIDTH-1:0] predict_flush_bid,
    input wire [BID_WIDTH-1:0] head_bid,

    input  wire                       lq_in_valid,
    output wire                       lq_in_ready,
    input  wire                       lq_in_mat,
    input  wire [31:0]                lq_in_address,
    input  wire [3:0]                 lq_in_wstrb,
    input  wire [BID_WIDTH-1:0]       lq_in_bid,
    input  wire [RESERVED_WIDTH-1:0]  lq_in_reserved,
    input  wire [MAT_COUNT_WIDTH-1:0] lq_in_older_suc_count,

    input wire suc_out_fire,

    output wire                      lq_out_valid,
    input  wire                      lq_out_ready,
    output wire                      lq_out_mat,
    output wire [31:0]               lq_out_address,
    output wire [31:0]               lq_out_data,
    output wire [3:0]                lq_out_wstrb,
    output wire [3:0]                lq_out_data_bit_mask,
    output wire [BID_WIDTH-1:0]      lq_out_bid,
    output wire [RESERVED_WIDTH-1:0] lq_out_reserved,

    input wire [7:0]   sq_entry_valid,
    input wire [7:0]   sq_entry_next_prdy,
    input wire [255:0] sq_entry_address_flat,
    input wire [31:0]  sq_entry_wstrb_flat,
    input wire [255:0] sq_entry_data_flat,
    input wire [2:0]   sq_head_index,
    input wire         store_out_fire,

    output wire [7:0] matrix3_set_sq_mask,
    output wire [2:0] matrix3_set_lq_index,
    output wire [7:0] matrix3_release_mask,

    output wire [3:0] lq_flush_surviving_suc_count
);

    localparam [3:0] MATRIX2_NONE = 4'b1000;//matrix2中4'b1000表示该字节没有任何store依赖

    reg [7:0] lq_valid;
    reg [7:0] lq_mat;
    reg [31:0]               lq_address [7:0];
    reg [3:0]                lq_wstrb   [7:0];
    reg [BID_WIDTH-1:0]      lq_bid     [7:0];
    reg [RESERVED_WIDTH-1:0] lq_reserved[7:0];
    reg [MAT_COUNT_WIDTH-1:0] lq_mat_count_reg [7:0];
    reg [7:0] matrix1 [7:0];
    reg [3:0] matrix2_byte0 [7:0];
    reg [3:0] matrix2_byte1 [7:0];
    reg [3:0] matrix2_byte2 [7:0];
    reg [3:0] matrix2_byte3 [7:0];
    reg [3:0] lq_count;

    wire flush;
    wire lq_in_fire;
    wire lq_out_fire;
    wire [7:0] lq_free_mask;
    wire [7:0] lq_alloc_onehot;
    wire [2:0] lq_alloc_index;
    wire [7:0] lq_eligible;
    wire [7:0] lq_issue_onehot;
    wire [2:0] lq_issue_index;
    wire [7:0] lq_predict_survivor_mask;
    wire [7:0] lq_predict_remove_mask;
    wire [3:0] lq_predict_survivor_count;
    wire [3:0] lq_valid_count;

    wire [7:0] new_match_phys [3:0];
    wire [7:0] new_match_age [3:0];
    wire [7:0] new_source_onehot [3:0];
    wire [2:0] new_source_age [3:0];
    wire [2:0] new_source_phys [3:0];
    wire [3:0] new_matrix2_flat [3:0];
    wire [3:0] new_source_exists_raw;
    wire [3:0] new_source_exists;
    wire [3:0] new_source_is_draining;
    wire [3:0] new_source_wait;
    wire [7:0] new_matrix1;
    wire [7:0] new_sq_source_mask;

    wire [3:0] winner_source0;
    wire [3:0] winner_source1;
    wire [3:0] winner_source2;
    wire [3:0] winner_source3;

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

    assign flush = global_flush || predict_flush;

    //LQ使用稀疏槽位，优先选择物理编号最小的空闲entry接收新load
    assign lq_free_mask = ~lq_valid;
    assign lq_in_ready = !flush && (lq_count < 4'd8);
    assign lq_in_fire = lq_in_valid && lq_in_ready;

    //8 位的 onehot 转换成 index
    //代码把全 0 默认映射到 7，确实会与 entry7 共用编码；安全性来自 one-hot 的有效/握手信号，而不是 index 自带无效码。
    assign lq_alloc_index = lq_alloc_onehot[0] ? 3'd0
                          : lq_alloc_onehot[1] ? 3'd1
                          : lq_alloc_onehot[2] ? 3'd2
                          : lq_alloc_onehot[3] ? 3'd3
                          : lq_alloc_onehot[4] ? 3'd4
                          : lq_alloc_onehot[5] ? 3'd5
                          : lq_alloc_onehot[6] ? 3'd6
                          : 3'd7;

    assign lq_issue_index = lq_issue_onehot[0] ? 3'd0
                          : lq_issue_onehot[1] ? 3'd1
                          : lq_issue_onehot[2] ? 3'd2
                          : lq_issue_onehot[3] ? 3'd3
                          : lq_issue_onehot[4] ? 3'd4
                          : lq_issue_onehot[5] ? 3'd5
                          : lq_issue_onehot[6] ? 3'd6
                          : 3'd7;

    //从所有满足依赖条件的load中选择物理编号最小的一项发射
    assign lq_out_valid = !flush && (|lq_eligible);
    assign lq_out_fire = lq_out_valid && lq_out_ready;

    assign lq_out_mat      = lq_mat[lq_issue_index];
    assign lq_out_address  = lq_address[lq_issue_index];
    assign lq_out_wstrb    = lq_wstrb[lq_issue_index];
    assign lq_out_bid      = lq_bid[lq_issue_index];
    assign lq_out_reserved = lq_reserved[lq_issue_index];

    assign winner_source0 = matrix2_byte0[lq_issue_index];
    assign winner_source1 = matrix2_byte1[lq_issue_index];
    assign winner_source2 = matrix2_byte2[lq_issue_index];
    assign winner_source3 = matrix2_byte3[lq_issue_index];

    //matrix2按字节保存该load需要转发数据的youngest store物理编号
    //对应store仍有效时，该字节从SQ中取数，并通过bit_mask标记转发有效
    assign lq_out_data_bit_mask[0]
        = (winner_source0 != MATRIX2_NONE)
        && sq_entry_valid[winner_source0[2:0]];

    assign lq_out_data_bit_mask[1]
        = (winner_source1 != MATRIX2_NONE)
        && sq_entry_valid[winner_source1[2:0]];

    assign lq_out_data_bit_mask[2]
        = (winner_source2 != MATRIX2_NONE)
        && sq_entry_valid[winner_source2[2:0]];

    assign lq_out_data_bit_mask[3]
        = (winner_source3 != MATRIX2_NONE)
        && sq_entry_valid[winner_source3[2:0]];

    assign lq_out_data[7:0] = lq_out_data_bit_mask[0]
        ? sq_entry_data_flat[winner_source0[2:0]*32 +: 8] : 8'b0;

    assign lq_out_data[15:8] = lq_out_data_bit_mask[1]
        ? sq_entry_data_flat[winner_source1[2:0]*32 + 8 +: 8] : 8'b0;

    assign lq_out_data[23:16] = lq_out_data_bit_mask[2]
        ? sq_entry_data_flat[winner_source2[2:0]*32 + 16 +: 8] : 8'b0;
        
    assign lq_out_data[31:24] = lq_out_data_bit_mask[3]
        ? sq_entry_data_flat[winner_source3[2:0]*32 + 24 +: 8] : 8'b0;

    //matrix1只记录各字节选中的youngest store中仍未ready者
    assign new_matrix1 =
          (new_source_onehot[0] & {8{new_source_wait[0]}})
        | (new_source_onehot[1] & {8{new_source_wait[1]}})
        | (new_source_onehot[2] & {8{new_source_wait[2]}})
        | (new_source_onehot[3] & {8{new_source_wait[3]}});

    assign new_sq_source_mask = new_source_onehot[0]
                              | new_source_onehot[1]
                              | new_source_onehot[2]
                              | new_source_onehot[3];

    //新load入队时通知SQ建立matrix3反向引用，防止被引用的store槽位过早复用
    assign matrix3_set_sq_mask = lq_in_fire
                               ? new_sq_source_mask : 8'b0;
    assign matrix3_set_lq_index = lq_alloc_index;

    //load发射或被flush删除时，释放matrix3中对应的LQ列
    assign matrix3_release_mask = global_flush
                                ? lq_valid
                                : predict_flush
                                  ? lq_predict_remove_mask
                                  : lq_out_fire
                                    ? lq_issue_onehot : 8'b0;

    assign lq_predict_remove_mask = lq_valid
                                  & ~lq_predict_survivor_mask;

    assign lq_predict_survivor_count =
          {3'b0, lq_predict_survivor_mask[0]}
        + {3'b0, lq_predict_survivor_mask[1]}
        + {3'b0, lq_predict_survivor_mask[2]}
        + {3'b0, lq_predict_survivor_mask[3]}
        + {3'b0, lq_predict_survivor_mask[4]}
        + {3'b0, lq_predict_survivor_mask[5]}
        + {3'b0, lq_predict_survivor_mask[6]}
        + {3'b0, lq_predict_survivor_mask[7]};

    assign lq_valid_count =
          {3'b0, lq_valid[0]}
        + {3'b0, lq_valid[1]}
        + {3'b0, lq_valid[2]}
        + {3'b0, lq_valid[3]}
        + {3'b0, lq_valid[4]}
        + {3'b0, lq_valid[5]}
        + {3'b0, lq_valid[6]}
        + {3'b0, lq_valid[7]};

    //predict flush后重新统计存活load中的SUC数量；global flush不保留load
    assign lq_flush_surviving_suc_count = predict_flush
        ? ({3'b0, lq_predict_survivor_mask[0] && !lq_mat[0]}
         + {3'b0, lq_predict_survivor_mask[1] && !lq_mat[1]}
         + {3'b0, lq_predict_survivor_mask[2] && !lq_mat[2]}
         + {3'b0, lq_predict_survivor_mask[3] && !lq_mat[3]}
         + {3'b0, lq_predict_survivor_mask[4] && !lq_mat[4]}
         + {3'b0, lq_predict_survivor_mask[5] && !lq_mat[5]}
         + {3'b0, lq_predict_survivor_mask[6] && !lq_mat[6]}
         + {3'b0, lq_predict_survivor_mask[7] && !lq_mat[7]})
        : 4'b0;

    genvar load_byte;
    genvar source_store;
    generate
        for (load_byte = 0; load_byte < 4;
             load_byte = load_byte + 1) begin : gen_new_source_byte

            wire [15:0] match_phys_double;
            wire [15:0] match_age_shifted;

            for (source_store = 0; source_store < 8;
                  source_store = source_store + 1) begin : gen_source_store
                //按PA[31:2]和字节写使能寻找与新load当前字节相关的有效store
                assign new_match_phys[load_byte][source_store]
                    = sq_entry_valid[source_store]
                    && (sq_entry_address_flat[source_store*32 + 2 +: 30]
                        == lq_in_address[31:2])
                    && lq_in_wstrb[load_byte]
                    && sq_entry_wstrb_flat[source_store*4 + load_byte];//我感觉这一行加得挺好的：它实现了字节级相关判断，避免同一 32-bit 字内、但访问不同字节的 Load 和 Store 被误判为相关。
            end

            //将 8-bit 物理匹配掩码复制成 16 bit，方便进行环形旋转。因为 SQ 会回绕，物理编号大小不等于年龄大小。
            assign match_phys_double = {new_match_phys[load_byte],
                                        new_match_phys[load_byte]};

            //从SQ head开始旋转匹配掩码，把物理编号转换为0到7的年龄顺序
            assign match_age_shifted
                = match_phys_double >> sq_head_index;
            assign new_match_age[load_byte] = match_age_shifted[7:0];

            //表示新的 load 是否有相关
            assign new_source_exists_raw[load_byte]
                = |new_match_age[load_byte];

            //年龄越大表示越年轻，选择最高置位得到该字节的youngest store
            //优先编码从 age7 向 age0 查找，最终选择到最年轻的 store 的 相对 index
            assign new_source_age[load_byte]
                = new_match_age[load_byte][7] ? 3'd7
                : new_match_age[load_byte][6] ? 3'd6
                : new_match_age[load_byte][5] ? 3'd5
                : new_match_age[load_byte][4] ? 3'd4
                : new_match_age[load_byte][3] ? 3'd3
                : new_match_age[load_byte][2] ? 3'd2
                : new_match_age[load_byte][1] ? 3'd1
                : 3'd0;

            //再转换回物理编号：会回绕，得到真正的 entry index
            assign new_source_phys[load_byte]
                = sq_head_index + new_source_age[load_byte];

            //若唯一选中的source正好是本拍drain的SQ head，则新load不再依赖它
            assign new_source_is_draining[load_byte]
                = new_source_exists_raw[load_byte]
                && store_out_fire //握手出队
                && new_source_phys[load_byte] == sq_head_index;

            assign new_source_exists[load_byte]
                = new_source_exists_raw[load_byte]
                && !new_source_is_draining[load_byte];

            //把物理编号转换成新的 onehot
            assign new_source_onehot[load_byte]
                = new_source_exists[load_byte]
                ? (8'b0000_0001 << new_source_phys[load_byte]) : 8'b0;

            //matrix2保存转发source，matrix1只等待尚未ready的source
            assign new_matrix2_flat[load_byte]
                = new_source_exists[load_byte]
                ? {1'b0, new_source_phys[load_byte]} : MATRIX2_NONE;

            assign new_source_wait[load_byte]
                = new_source_exists[load_byte]
                && !sq_entry_next_prdy[new_source_phys[load_byte]];
        end
    endgenerate

    genvar load_index;
    generate
        for (load_index = 0; load_index < 8;
             load_index = load_index + 1) begin : gen_load_entry

            //屏蔽当前entry之前的物理槽位，用于生成lowest-onehot
            localparam [7:0] LOWER_INDEX_MASK
                = (8'b0000_0001 << load_index) - 1'b1;

            wire allocate_this_load;
            wire issue_this_load;
            wire predict_survivor;
            wire load_is_eligible;
            wire load_bid_greater;

            //load比predict_flush_bid年轻时，在预测恢复后删除
            assign load_bid_greater = circle_comparator(
                head_bid, lq_bid[load_index], predict_flush_bid);

            //选择物理编号最小的空闲entry
            assign lq_alloc_onehot[load_index]
                = lq_free_mask[load_index]
                && !(| (lq_free_mask & LOWER_INDEX_MASK));

            //matrix1清零表示store数据依赖已满足
            //CC可直接发射，SUC还必须等待所有older SUC离队
            assign load_is_eligible = lq_valid[load_index]
                                    && matrix1[load_index] == 8'b0
                                    && (lq_mat[load_index]
                                        || lq_mat_count_reg[load_index] == 0);
            assign lq_eligible[load_index] = load_is_eligible;

            //在所有eligible entry中选择物理编号最小的一项
            assign lq_issue_onehot[load_index]
                = load_is_eligible
                && !(| (lq_eligible & LOWER_INDEX_MASK));

            //预测恢复时，存活load保留在队列中
            assign lq_predict_survivor_mask[load_index]
                = lq_valid[load_index]
                && !load_bid_greater;

            assign allocate_this_load = lq_in_fire
                                      && lq_alloc_onehot[load_index];
            assign issue_this_load = lq_out_fire
                                   && lq_issue_onehot[load_index];
            assign predict_survivor
                = lq_predict_survivor_mask[load_index];

            //更新每个load entry的payload、SUC计数以及matrix1/matrix2依赖信息
            always @(posedge clk) begin
                if (!resetn) begin
                    lq_mat[load_index] <= 1'b0;
                    lq_address[load_index] <= 32'b0;
                    lq_wstrb[load_index] <= 4'b0;
                    lq_bid[load_index] <= {BID_WIDTH{1'b0}};
                    lq_reserved[load_index]
                        <= {RESERVED_WIDTH{1'b0}};
                    lq_mat_count_reg[load_index]
                        <= {MAT_COUNT_WIDTH{1'b0}};

                    matrix1[load_index] <= 8'b0;

                    matrix2_byte0[load_index] <= MATRIX2_NONE;
                    matrix2_byte1[load_index] <= MATRIX2_NONE;
                    matrix2_byte2[load_index] <= MATRIX2_NONE;
                    matrix2_byte3[load_index] <= MATRIX2_NONE;

                end else if (global_flush) begin
                    //global flush删除全部load，并清空其依赖状态
                    lq_mat_count_reg[load_index]
                        <= {MAT_COUNT_WIDTH{1'b0}};

                    matrix1[load_index] <= 8'b0;

                    matrix2_byte0[load_index] <= MATRIX2_NONE;
                    matrix2_byte1[load_index] <= MATRIX2_NONE;
                    matrix2_byte2[load_index] <= MATRIX2_NONE;
                    matrix2_byte3[load_index] <= MATRIX2_NONE;

                end else if (predict_flush) begin
                    if (predict_survivor) begin
                        //存活load继续接收SQ next_prdy，及时解除已经ready的依赖
                        matrix1[load_index]
                            <= matrix1[load_index]
                             & ~sq_entry_next_prdy;

                    end else begin
                        //被预测恢复删除的load清空全部依赖状态
                        lq_mat_count_reg[load_index]
                            <= {MAT_COUNT_WIDTH{1'b0}};

                        matrix1[load_index] <= 8'b0;

                        matrix2_byte0[load_index] <= MATRIX2_NONE;
                        matrix2_byte1[load_index] <= MATRIX2_NONE;
                        matrix2_byte2[load_index] <= MATRIX2_NONE;
                        matrix2_byte3[load_index] <= MATRIX2_NONE;
                    end

                end else if (allocate_this_load) begin
                    //记录新load本身信息以及入队前仍未离队的older SUC数量
                    lq_mat[load_index] <= lq_in_mat;
                    lq_address[load_index] <= lq_in_address;
                    lq_wstrb[load_index] <= lq_in_wstrb;
                    lq_bid[load_index] <= lq_in_bid;
                    lq_reserved[load_index] <= lq_in_reserved;
                    lq_mat_count_reg[load_index]
                        <= lq_in_older_suc_count;
                    
                    //更新矩阵
                    matrix1[load_index] <= new_matrix1;

                    matrix2_byte0[load_index] <= new_matrix2_flat[0];
                    matrix2_byte1[load_index] <= new_matrix2_flat[1];
                    matrix2_byte2[load_index] <= new_matrix2_flat[2];
                    matrix2_byte3[load_index] <= new_matrix2_flat[3];

                end else if (issue_this_load) begin
                    //load发射后清空依赖状态，valid在下方统一清除
                    lq_mat_count_reg[load_index]
                        <= {MAT_COUNT_WIDTH{1'b0}};

                    matrix1[load_index] <= 8'b0;

                    matrix2_byte0[load_index] <= MATRIX2_NONE;
                    matrix2_byte1[load_index] <= MATRIX2_NONE;
                    matrix2_byte2[load_index] <= MATRIX2_NONE;
                    matrix2_byte3[load_index] <= MATRIX2_NONE;

                end else if (lq_valid[load_index]) begin
                    //驻留load持续解除ready store依赖，并跟随SUC离队递减older计数
                    matrix1[load_index]
                        <= matrix1[load_index] & ~sq_entry_next_prdy;
                    if (suc_out_fire
                        && lq_mat_count_reg[load_index] != 0)
                        lq_mat_count_reg[load_index]
                            <= lq_mat_count_reg[load_index] - 1'b1;
                end
            end
        end
    endgenerate

    //统一维护8个LQ槽位的有效位，支持同拍入队和出队
    always @(posedge clk) begin
        if (!resetn)
            lq_valid <= 8'b0;
        else if (global_flush)
            lq_valid <= 8'b0;
        else if (predict_flush)
            lq_valid <= lq_predict_survivor_mask;
        else begin
            if (lq_in_fire && lq_out_fire)
                lq_valid <= (lq_valid & ~lq_issue_onehot)
                          | lq_alloc_onehot;
            else if (lq_out_fire)
                lq_valid <= lq_valid & ~lq_issue_onehot;
            else if (lq_in_fire)
                lq_valid <= lq_valid | lq_alloc_onehot;
        end
    end

    //LQ计数只由实际握手更新，predict flush时用survivor数量重建
    always @(posedge clk) begin
        if (!resetn)
            lq_count <= 4'b0;
        else if (global_flush)
            lq_count <= 4'b0;
        else if (predict_flush)
            lq_count <= lq_predict_survivor_count;
        else
            lq_count <= lq_count
                      + {{3{1'b0}}, lq_in_fire}
                      - {{3{1'b0}}, lq_out_fire};
    end

`ifdef LQ_SQ_ASSERTIONS
    always @(posedge clk) begin
        if (resetn) begin
            if (lq_count > 4'd8) begin
                $display("LOAD_QUEUE_ASSERT_FAIL count_above_eight");
                $finish;
            end
            if (lq_valid_count != lq_count) begin
                $display("LOAD_QUEUE_ASSERT_FAIL valid_count_mismatch");
                $finish;
            end
            if (lq_in_fire && !(|lq_alloc_onehot)) begin
                $display("LOAD_QUEUE_ASSERT_FAIL input_without_free_slot");
                $finish;
            end
            if (lq_out_fire && !(|lq_issue_onehot)) begin
                $display("LOAD_QUEUE_ASSERT_FAIL output_without_winner");
                $finish;
            end
            if (matrix3_set_sq_mask != 0 && !lq_in_fire) begin
                $display("LOAD_QUEUE_ASSERT_FAIL matrix3_set_without_input");
                $finish;
            end
        end
    end
`endif

endmodule
