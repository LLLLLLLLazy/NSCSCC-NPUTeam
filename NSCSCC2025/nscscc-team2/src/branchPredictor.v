// 输入：
//   clk                  - 时钟信号
//   reset                - 同步复位信号，高电平有效
//   fetch_pc[31:2]       - pre_IF 的 pc
//   fetch_en             - if_fire
//   update_en            - 更新信号，高表示需要更新预测表.注意ex_fire为1时才会更新
//   id_pc[31:2]          - ID 级指令的PC高30位（用于更新）
//   id_push_ras          - ID 级为 bl
//   id_pop_ras           - ID 级为 jirl
//   id_need_add_entry    - ID 级为分支指令且发生了跳转，但是并未进行预测
//   id_need_delete_entry - ID 级不为分支指令但是进行了预测。可忽略
//   id_pre_error         - ID 级为分支指令，进行了预测，但是是否跳转预测错误
//   id_pre_right         - ID 级为分支指令，进行了预测，是否跳转预测正确
//   id_target_error      - ID 级为分支指令，进行了预测，是否跳转预测正确，但是跳转地址不一致
//   id_br_target
//   id_br_taken
// 输出：
//   ret_en          - 预测结果有效信号，高表示预测有效
//   ret_pc[31:2]    - 预测的目标地址高30位
//   taken           - 预测跳转方向，高表示跳转
//   ret_index[4:0]  - 命中的预测表索引（BTB索引或CAM索引）
// -----------------------------------------------------------------------------
module branchPredictor(
    input             clk,
    input             reset,
    input      [29:0] fetch_pc,
    input             fetch_en,
    // 更新接口
    input             update_en,
    input      [ 4:0] update_index,
    input      [29:0] id_pc,
    input             id_push_ras,
    input             id_pop_ras,
    input             id_need_add_entry,
    input             id_need_delete_entry, 
    input             id_pre_error,
    input             id_pre_right,
    input             id_target_error,
    input      [29:0] id_br_target,
    input             id_br_taken,
    // 预测输出
    output reg        ret_en,
    output reg [29:0] ret_pc,
    output reg        taken,
    output reg  [4:0] ret_index,

    output wire [31:0] info_to_pc
);

    // BTB: 32 项
    reg [31:0]  btb_valid ;
    reg [29:0]  btb_tag   [31:0];
    reg [29:0]  btb_target[31:0];
    reg  [1:0]  btb_counter[31:0];

    // CAM: 16 项，用于识别 JIRL PC 
    reg [15:0]  cam_valid;
    reg [29:0]  cam_pc   [15:0];

    // RAS: 8 深度栈
    reg [29:0]  ras_stack[7:0];
    reg  [2:0]  ras_ptr;

    genvar i;

    wire [31:0] btb_match ;
    wire        btb_hit;
    wire [ 4:0] btb_hit_idx;

    wire [15:0] cam_match;
    wire        cam_hit;
    wire [ 3:0] cam_hit_idx;

    wire [ 4:0] btb_add_empty_index;
    wire [ 4:0] btb_add_zero_index;
    wire [31:0] btb_counter_all_zero;

    wire [ 3:0] cam_add_empty_index;

    reg  [ 4:0] lfsr1;
    reg  [ 3:0] lfsr2;

    // 匹配 BTB
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_btb_match
            assign btb_match[i] = btb_valid[i] && (btb_tag[i] == fetch_pc) ;
        end
    endgenerate

    assign btb_hit = |btb_match;
    encoder_32_5 u_encoder_32_5_bp (.in(btb_match), .out(btb_hit_idx));

    // 匹配 CAM
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_cam_match
            assign cam_match[i] = cam_valid[i] && (cam_pc[i] == fetch_pc);
        end
    endgenerate

    assign cam_hit = |cam_match;
    encoder_16_4 u_encoder_16_4_bp (.in(cam_match), .out(cam_hit_idx));

    // 预测结果
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ret_en      <= 1'b0;
            taken       <= 1'b0;
            ret_pc      <= 30'b0;
            ret_index   <= 5'b0;
        end
        else if (fetch_en) begin
            ret_en      <= btb_hit || cam_hit;
            taken       <= (btb_hit && btb_counter[btb_hit_idx][1]) || (cam_hit);
            ret_pc      <= btb_hit? btb_target[btb_hit_idx] :
                           cam_hit? ras_stack[ras_ptr - 3'b1] : 30'b0;
            ret_index   <= btb_hit? btb_hit_idx : 
                           cam_hit? {1'b0, cam_hit_idx} : 5'b0; 
        end
        else begin
            ret_en      <= ret_en;
            taken       <= taken;
            ret_pc      <= ret_pc;
            ret_index   <= ret_index;
        end
    end

    assign info_to_pc = {(btb_hit || cam_hit),
                        ((btb_hit && btb_counter[btb_hit_idx][1]) || (cam_hit)), 
                         (btb_hit? btb_target[btb_hit_idx] :
                          cam_hit? ras_stack[ras_ptr - 3'b1] : 30'b0)} ;

    // 更新逻辑
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_btb_counter_all_zero
            assign  btb_counter_all_zero[i] = ~(|btb_counter[i]);
        end
    endgenerate

    one_valid_32 u_one_valid_32_0 (.in(~btb_valid), .out_en(btb_add_empty_index));
    one_valid_32 u_one_valid_32_1 (.in(btb_counter_all_zero), .out_en(btb_add_zero_index));
 
    wire  [ 4:0] btb_add_index = (~(&btb_valid           ))? btb_add_empty_index :
                                 (&(~btb_counter_all_zero))? lfsr1 :
                                                             btb_add_zero_index;                                        

    one_valid_16 u_one_valid_16(.in (~cam_valid), .out_en(cam_add_empty_index));
    wire  [ 3:0] cam_add_index = (&cam_valid)? lfsr2 : cam_add_empty_index ;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btb_valid <= 32'b0;
            cam_valid <= 16'b0;
        end 
        else if (update_en && !id_pop_ras) begin
            if (id_need_add_entry) begin
                btb_valid[btb_add_index]   <= 1'b1;
                btb_tag[btb_add_index]     <= id_pc;
                btb_target[btb_add_index]  <= id_br_target;
                btb_counter[btb_add_index] <= 2'b10;
            end
            else if (id_target_error) begin
                btb_target[update_index]  <= id_br_target;
                btb_counter[update_index] <= 2'b10;
            end
            else if (id_pre_right || id_pre_error) begin
                if (id_br_taken) begin
                    if (|(btb_counter[update_index] ^ 2'b11)) begin
                        btb_counter[update_index] <= btb_counter[update_index] + 1'b1;
                    end
                end
                else begin
                    if (|(btb_counter[update_index] ^ 2'b00)) begin
                        btb_counter[update_index] <= btb_counter[update_index] - 1'b1;
                    end
                end
            end
        end
        else if (update_en && id_pop_ras) begin
            if (id_need_add_entry) begin
                cam_valid[cam_add_index] <= 1'b1;
                cam_pc[cam_add_index]    <= id_pc;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ras_ptr <= 3'b0;
        end 
        else if (update_en) begin
            if (id_push_ras && !(ras_ptr==3'b111)) begin
                ras_stack[ras_ptr] <= id_pc + 30'b1;
                ras_ptr <= ras_ptr + 3'b1;
            end
            else if (id_pop_ras && !(ras_ptr==3'b000)) begin
                ras_ptr <= ras_ptr - 3'b1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr1 <= 5'b00000; 
        end else begin
            lfsr1 <= lfsr1 + 1'b1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr2 <= 4'b0000; 
        end else begin
            lfsr2 <= lfsr2 + 1'b1;
        end
    end

endmodule
