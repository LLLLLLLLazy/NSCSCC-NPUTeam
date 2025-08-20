module br_logic_unit (
    input  wire         clk,
    input  wire         reset,

    input  wire         stall,
    input  wire         refetch_flag,
    input  wire         br_calc_finish,

    input  wire         inst_b,
    input  wire         inst_bl,
    input  wire         inst_jirl,
    input  wire         inst_beq,
    input  wire         inst_bne,
    input  wire         inst_blt,
    input  wire         inst_bltu,
    input  wire         inst_bge,
    input  wire         inst_bgeu,
    input  wire [31:0]  pc,
    input  wire [31:0]  imm,
    input  wire [31:0]  rj_value,
    input  wire [31:0]  rkd_value,

    input  wire [ 4:0]  rj,
    input  wire [ 4:0]  rkd,

    input  wire [ 4:0]  rf_waddr_from_ex,
    input  wire [ 4:0]  rf_waddr_from_mem,
    input  wire [ 4:0]  rf_waddr_from_wb,

    input  wire         rf_we_in_stage_ex,
    input  wire         rf_we_in_stage_mem,
    input  wire         rf_we_in_stage_wb,

    input  wire [31:0]  forwarding_from_ex,
    input  wire [31:0]  forwarding_from_mem,
    input  wire [31:0]  forwarding_from_wb,

    input  wire         bp_ret_en,
    input  wire         bp_taken,
    input  wire [31:0]  bp_ret_pc,

    input  wire         ex_valid,
    input  wire         mem_valid,
    input  wire         wb_valid,
    input  wire         ex_fire,

    output reg  [31:0]  br_target,   
    output reg          br_taken,
    output wire         real_br_taken,
    output wire [31:0]  r_rkd_value,
    output wire [31:0]  r_rj_value,
    output wire         need_ex_forward
);

reg  [ 1:0]  forward1;
reg  [ 1:0]  forward2;
wire         bp_target_error;
reg  [31:0]  br_target0, br_target1, br_target2;

assign need_ex_forward = (forward1 == 2'b11) || (forward2 == 2'b11);

always @(*) begin
    if ((rf_waddr_from_ex == rj) && |(rj ^ 5'b0) && rf_we_in_stage_ex && ex_valid)
        forward1 = 2'b11;
    else if ((rf_waddr_from_mem == rj) && |(rj ^ 5'b0) && rf_we_in_stage_mem && mem_valid)
        forward1 = 2'b10;
    else if ((rf_waddr_from_wb == rj) && |(rj ^ 5'b0) && rf_we_in_stage_wb && wb_valid)
        forward1 = 2'b01;
    else 
        forward1 = 2'b00;
end

always @(*) begin    
    if ((rf_waddr_from_ex == rkd) && |(rkd ^ 5'b0) && rf_we_in_stage_ex && ex_valid)
        forward2 = 2'b11;
    else if ((rf_waddr_from_mem == rkd) && |(rkd ^ 5'b0) && rf_we_in_stage_mem && mem_valid)
        forward2 = 2'b10;
    else if ((rf_waddr_from_wb == rkd) && |(rkd ^ 5'b0) && rf_we_in_stage_wb && wb_valid)
        forward2 = 2'b01;
    else
        forward2 = 2'b00;
end

assign bp_target_error = |(bp_ret_pc ^ br_target);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        br_target0 <= 32'b0;
        br_target1 <= 32'b0;
        br_target2 <= 32'b0;
    end
    else begin
        br_target0 <= pc + 4;
        br_target1 <= r_rj_value + imm;
        br_target2 <= pc + imm;
    end
end

always @(*) begin
    if (!br_taken && bp_ret_en && bp_taken) begin
        br_target = br_target0;
    end
    else if (inst_jirl) begin
        br_target = br_target1;
    end
    else begin
        br_target = br_target2;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset)
        br_taken <= 1'b0;
    else if (inst_b | inst_bl | inst_jirl)
        br_taken <= 1'b1;
    else if (inst_blt)
        br_taken <= ($signed(r_rj_value) < $signed(r_rkd_value));
    else if (inst_bltu)
        br_taken <= (r_rj_value < r_rkd_value);
    else if (inst_bge)
        br_taken <= (($signed(r_rj_value) > $signed(r_rkd_value))  |
                   ($signed(r_rj_value) == $signed(r_rkd_value))) ;
    else if (inst_bgeu)
        br_taken <= ((r_rj_value > r_rkd_value)  |
                   (r_rj_value == r_rkd_value)) ;
    else if (inst_beq)
        br_taken <= (r_rj_value == r_rkd_value);
    else if (inst_bne)
        br_taken <= |(r_rj_value ^ r_rkd_value);
    else
        br_taken <= 1'b0;
end

assign real_br_taken = (!ex_fire || refetch_flag || !br_calc_finish)? 1'b0 :
                       ( br_taken && bp_ret_en && bp_taken && !bp_target_error)? 1'b0 :
                       (!br_taken && bp_ret_en && bp_taken)? 1'b1 : br_taken;

assign r_rj_value = ({32{forward1 == 2'b11}} & forwarding_from_ex  ) |
                    ({32{forward1 == 2'b10}} & forwarding_from_mem ) |
                    ({32{forward1 == 2'b01}} & forwarding_from_wb  ) |
                    ({32{forward1 == 2'b00}} & rj_value            ) ;

assign r_rkd_value = ({32{forward2 == 2'b11}} & forwarding_from_ex  ) |
                     ({32{forward2 == 2'b10}} & forwarding_from_mem ) |
                     ({32{forward2 == 2'b01}} & forwarding_from_wb  ) |
                     ({32{forward2 == 2'b00}} & rkd_value           ) ;

/*
实际跳转，预测正确：
无事发生

实际跳转，预测错误：
br_flush

实际不跳转，预测正确：
无事发生

实际不跳转，预测错误：
br_flush
*/

endmodule
