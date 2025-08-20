`define PHT_LEVEL 8
`define BTB_LEVEL 6
`define PHT_ENTRIES (1<<`PHT_LEVEL)
`define BTB_ENTRIES (1<<`BTB_LEVEL)

`define PHT_SN 2'b00
`define PHT_WN 2'b01
`define PHT_WT 2'b11
`define PHT_ST 2'b10
module bpu(
    //预测通道
    input              clk,
    input              rst_n,
    input  [31:0]      pc_pif,
    input              pif_allow_update,    //pif指令本拍能够离开当前流水级，允许更新分支预测单元
    output [31:0]      pc_predict,          //预测的pc
    output             br_taken_predict,    //预测为跳转
    output             btb_hit,             //使用pc寻址btb，结果为命中(不考虑是否为分支指令)
    output             miss_predict,        //先前分支预测出错
    output [31:0]      pc_correct,          //分支预测出错时正确的pc
    output             btb_tag_hi_match,    //btb tag高位是否相等
    //更新预测结果通道
    input              exe_allow_update,    //exe指令本拍能够离开当前流水级，允许更新分支预测单元
    input              addr_incorrect_exe,  //预测地址不正确(TAG比较的高位不同)
    input              btb_clean,           //清除btb(执行IBAR指令时，出现指令自修改)     *会改变预测器状态，需要考虑valid信号
    input  [31:0]      pc_exe,              //分支指令的pc
    input              is_br_exe,           //是否为分支指令(不包含jirl)
    input              is_jirl_exe,         //是否为jirl指令
    input              btb_hit_exe,         //先前查询btb时是否命中
    input  [31:0]      br_tar_exe,          //跳转目标地址
    input              br_taken_exe,        //指令实际是否跳转
    input              br_taken_predict_exe //指令是否被预测为跳转
`ifdef PERF_STAT_EN
    ,
    output             pht_taken_perf
`endif
);
    //256 entries PHT
    reg  [`PHT_ENTRIES - 1 : 0] pht_0;
    reg  [`PHT_ENTRIES - 1 : 0] pht_1;
    wire [`PHT_LEVEL - 1 : 0] pht_addr_pif = pc_pif[2+`PHT_LEVEL-1 : 2];
    wire [`PHT_LEVEL - 1 : 0] pht_addr_exe = pc_exe[2+`PHT_LEVEL-1 : 2];
    wire pht_pred    = pht_1[pht_addr_pif];  //访问pht预测出的分支是否发生
    wire pht_0_r_exe = pht_0[pht_addr_exe];
    wire pht_1_r_exe = pht_1[pht_addr_exe];
    //PHT更新
    genvar i;
    integer j;
    always @(posedge clk)begin
        if(!rst_n)
            pht_0 <= {`PHT_ENTRIES{1'b1}};
        else if(exe_allow_update && (br_taken_exe == (pht_1_r_exe == pht_0_r_exe))) begin
            pht_0[pht_addr_exe] <= ~pht_0_r_exe;
        end
    end
    always @(posedge clk)begin
        if(!rst_n)
            pht_1 <= {`PHT_ENTRIES{1'b0}};
        else if(exe_allow_update && pht_0_r_exe && (br_taken_exe != pht_1_r_exe)) begin
            pht_1[pht_addr_exe] <= ~pht_1_r_exe;
        end
    end
    
`ifdef PERF_STAT_EN
    assign pht_taken_perf = pht_pred;
`endif
    //* BTB 64项直接映射
    wire            need_visit_btb;                //需要访问btb完成预测    
    wire            btb_wen;                       //btb写使能
    wire [31:2]     btb_pred_pc;                   //btb预测出的目标pc地址
    wire [`BTB_LEVEL - 1:0]      btb_rindex;
    wire [`BTB_LEVEL - 1:0]      btb_windex;
    reg  [`BTB_ENTRIES - 1 : 0]       btb_valid;
    reg  [31:(2+`BTB_LEVEL)] btb_pc       [`BTB_ENTRIES - 1 : 0]; 
    reg  [31:2] btb_tar      [`BTB_ENTRIES - 1 : 0];
    //need visit btb
    assign need_visit_btb = pht_pred;
    assign btb_rindex      = pc_pif[(2+`BTB_LEVEL) - 1:2];
    assign btb_windex      = pc_exe[(2+`BTB_LEVEL) - 1:2];
    //wen
    assign btb_wen = exe_allow_update && is_br_exe && !btb_hit_exe && br_taken_exe && (br_tar_exe[1:0] == 2'b00);
    //btb
    always @(posedge clk)begin
        if(!rst_n || btb_clean)
            btb_valid <= 0;
        else if(btb_wen)
            btb_valid[btb_windex] <= 1'b1;
    end
    always @(posedge clk)begin
        if(btb_wen)
            btb_pc[btb_windex] <= pc_exe[31:2+`BTB_LEVEL];  
    end
    always @(posedge clk)begin
        if(btb_wen)
            btb_tar[btb_windex] <= br_tar_exe[31:2];  
    end
    assign btb_hit          = btb_valid[btb_rindex] && (btb_pc[btb_rindex][11:(2+`BTB_LEVEL)] == pc_pif[11:(2+`BTB_LEVEL)]);//只比较页内偏移量。
    assign btb_tag_hi_match = btb_pc[btb_rindex][31:12] == pc_pif[31:12];
    assign btb_pred_pc      = btb_tar[btb_rindex];
    //预测结果
    assign pc_predict = (need_visit_btb && btb_hit) ? {btb_pred_pc,2'b00} : pc_pif + 4;
    assign br_taken_predict = pht_pred && btb_hit;

    //预测出错处理
    assign miss_predict = exe_allow_update && ((br_taken_predict_exe ^ br_taken_exe) || (br_taken_predict_exe && addr_incorrect_exe));
    assign pc_correct = br_taken_exe ? br_tar_exe : pc_exe + 4;
endmodule
