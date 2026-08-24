`include "mycpu.h"
module IF(
    input clk,
    input reset,
    input flush,

    // from PIF
    input pif_to_fs_valid,
    input [`PIF_TO_FS_BUS_WD-1 : 0] pif_to_fs_bus,
    output fs_allowin,

    // to FB
    output [3:0] fs_to_fb_valid,
    output [`FS_TO_FB_BUS_WD-1 : 0] fs_to_fb_bus,
    input fb_allowin,

    // icache ???
    output inst_uncache_en,   
    output inst_tlb_excp_cancel_req,
    output inst_valid,
    input  inst_addr_ok,
    input  inst_data_ok,
    output [ 7:0] inst_index,
    output [19:0] inst_tag,
    output [ 3:0] inst_offset,
    input  [127:0] inst_rdata,
    output         if_cancel_req,
    output  [31:0] if_cancel_target

);

    reg [`PIF_TO_FS_BUS_WD-1 : 0] pif_to_fs_bus_r;
    wire [31:0] fs_pc;
    wire [31:0] fs_inst_paddr;
    wire [3:0] fs_pred_taken;
    wire [127:0] fs_pred_target;
    wire fs_pif_excp;
    wire [5:0] fs_IF_tlb_excps;
    wire fs_mmu_inst_uncache_en;
    wire [6:0] fs_excps;
    reg finish_req;
    reg fs_valid;
    reg inst_buff_enable;
    wire [3:0] mask_after_first_pred;
    wire [6:0] fs_excps0;
    wire [6:0] fs_excps1;
    wire [6:0] fs_excps2;
    wire [6:0] fs_excps3;

    assign {fs_pc,
            fs_inst_paddr,
            fs_pred_taken,
            fs_pred_target,
            fs_pif_excp,
            fs_IF_tlb_excps,
            fs_mmu_inst_uncache_en} = pif_to_fs_bus_r;

    assign fs_excps = {fs_pif_excp, fs_IF_tlb_excps};
    assign inst_uncache_en = fs_mmu_inst_uncache_en && fs_valid;
    assign inst_tlb_excp_cancel_req = (|fs_excps || flush) && fs_valid;
    assign inst_tag = fs_inst_paddr[31:12];
    assign inst_index = fs_inst_paddr[11:4];
    assign inst_offset = fs_inst_paddr[3:0];
    assign inst_valid = ~finish_req && fs_valid;

    always@(posedge clk) begin
        if(reset || flush) begin
            finish_req <= 1'b0;  
        end
        else if(fs_valid && inst_addr_ok && ~finish_req) begin
            finish_req <= 1'b1; 
        end
         else if(|fs_to_fb_valid && fb_allowin) begin
            finish_req <= 1'b0; 
        end
    end

    always @(posedge clk) begin
        if (reset || flush) begin
            fs_valid <= 0;
        end
        else if (fs_allowin) begin
            fs_valid <= pif_to_fs_valid;
        end
        if (pif_to_fs_valid && fs_allowin) begin
            pif_to_fs_bus_r <= pif_to_fs_bus;
        end
    end

    wire fs_ready_go;
    wire inst_data_ok_real;
    wire [1:0] fs_slot;
    wire [3:0] mask_before_fspc;
    wire [3:0] uncache_mask;
    wire [3:0] fs_slot_mask;
    wire [3:0] fs_to_fb_mask;  
    wire [3:0] fs_to_fb_mask_uncache;

    decoder_2_4 u_decoder_2_4(
        .in(fs_slot),
        .out(fs_slot_mask)
    );
    
    assign fs_slot = fs_pc[3:2];
    assign mask_before_fspc = 4'b1111 << fs_slot;
    assign uncache_mask = {4{inst_uncache_en}} & fs_slot_mask;
    assign fs_to_fb_mask = ((|fs_pred_taken) && ~if_cancel_req) ? mask_before_fspc & mask_after_first_pred : mask_before_fspc;
    assign fs_to_fb_mask_uncache = inst_uncache_en ? uncache_mask : fs_to_fb_mask;

    assign inst_data_ok_real = inst_data_ok && (finish_req || (fs_valid && inst_addr_ok));
    assign fs_ready_go = inst_data_ok_real || inst_buff_enable || (|fs_excps);
    assign fs_allowin = !fs_valid || fs_ready_go && fb_allowin;
    assign fs_to_fb_valid = {4{fs_valid && fs_ready_go && ~flush}} & fs_to_fb_mask_uncache;


    reg  [127:0] inst_rd_buff;
    wire [127:0] fs_inst_data;

    always @(posedge clk) begin
    if (reset || (fs_ready_go && fb_allowin) || flush) begin
        inst_buff_enable  <= 1'b0;
    end
   // else if (fs_valid && inst_data_ok_real && !fb_allowin) begin
   else if (fs_valid && inst_data_ok_real && !fb_allowin) begin
        inst_rd_buff <= inst_rdata;
        inst_buff_enable  <= 1'b1;
    end
end

    assign fs_inst_data = inst_buff_enable ? inst_rd_buff : inst_rdata;
    
    wire [31:0] fs_inst0;
    wire [31:0] fs_inst1;
    wire [31:0] fs_inst2;
    wire [31:0] fs_inst3;
    wire [31:0] fs_pc0;
    wire [31:0] fs_pc1;
    wire [31:0] fs_pc2;
    wire [31:0] fs_pc3;
    wire [31:0] fs_pc_aligned;

    assign fs_inst0 = fs_inst_data[31:0];
    assign fs_inst1 = fs_inst_data[63:32];
    assign fs_inst2 = fs_inst_data[95:64];
    assign fs_inst3 = fs_inst_data[127:96];
    assign fs_pc_aligned = {fs_pc[31:4], 4'b0000};
    assign fs_pc0 = fs_excps0[6]? fs_pc:fs_pc_aligned;
    assign fs_pc1 = fs_excps1[6]? fs_pc:fs_pc_aligned + 32'd4;
    assign fs_pc2 = fs_excps2[6]? fs_pc:fs_pc_aligned + 32'd8;
    assign fs_pc3 = fs_excps3[6]? fs_pc:fs_pc_aligned + 32'd12;

    wire first_pred0 = fs_pred_taken[0] && mask_before_fspc[0];
    wire first_pred1 = !first_pred0 && fs_pred_taken[1] && mask_before_fspc[1];
    wire first_pred2 = !first_pred0 && !first_pred1 && fs_pred_taken[2] && mask_before_fspc[2];
    wire first_pred3 = !first_pred0 && !first_pred1 && !first_pred2 && fs_pred_taken[3] && mask_before_fspc[3];

    assign mask_after_first_pred = first_pred0 ? 4'b0001 :
                                   first_pred1 ? 4'b0011 :
                                   first_pred2 ? 4'b0111 :
                                   first_pred3 ? 4'b1111 : 4'b1111;

    // 1.(Exception & BadVAddr)
    assign fs_excps0 = (fs_slot == 2'b00) ? fs_excps : 7'b0;
    assign fs_excps1 = (fs_slot == 2'b01) ? fs_excps : 7'b0;
    assign fs_excps2 = (fs_slot == 2'b10) ? fs_excps : 7'b0;
    assign fs_excps3 = (fs_slot == 2'b11) ? fs_excps : 7'b0;

    wire [31:0] fs_badvaddr0 = (fs_slot == 2'b00) ? fs_pc : 32'b0;
    wire [31:0] fs_badvaddr1 = (fs_slot == 2'b01) ? fs_pc : 32'b0;
    wire [31:0] fs_badvaddr2 = (fs_slot == 2'b10) ? fs_pc : 32'b0;
    wire [31:0] fs_badvaddr3 = (fs_slot == 2'b11) ? fs_pc : 32'b0;


    // 2.(Branch Prediction)
    wire        fs_pred_taken0  = fs_pred_taken[0];
    wire        fs_pred_taken1  = fs_pred_taken[1];
    wire        fs_pred_taken2  = fs_pred_taken[2];
    wire        fs_pred_taken3  = fs_pred_taken[3];

    wire [31:0] fs_pred_target0 = first_pred0 ? fs_pred_target[31:0]   : 32'b0;
    wire [31:0] fs_pred_target1 = first_pred1 ? fs_pred_target[63:32]  : 32'b0;
    wire [31:0] fs_pred_target2 = first_pred2 ? fs_pred_target[95:64]  : 32'b0;
    wire [31:0] fs_pred_target3 = first_pred3 ? fs_pred_target[127:96] : 32'b0;

    wire  pd0_is_ret;
    wire  pd0_is_call;
    wire [31:0] pd0_target;
    wire [ 1:0] pd0_cfi_type;

    wire  pd1_is_ret;
    wire  pd1_is_call;
    wire [31:0] pd1_target;
    wire [ 1:0] pd1_cfi_type;

    wire  pd2_is_ret;
    wire  pd2_is_call;
    wire [31:0] pd2_target;
    wire [ 1:0] pd2_cfi_type;

    wire  pd3_is_ret;
    wire  pd3_is_call;
    wire [31:0] pd3_target;
    wire [ 1:0] pd3_cfi_type;
    PreDecode u_predecode0 (
        .instr   (fs_inst0),
        .pc      (fs_pc0),
        .isRet   (pd0_is_ret),
        .isCall  (pd0_is_call),
        .target  (pd0_target),
        .cfiType (pd0_cfi_type)
    );

    PreDecode u_predecode1 (
        .instr   (fs_inst1),
        .pc      (fs_pc1),
        .isRet   (pd1_is_ret),
        .isCall  (pd1_is_call),
        .target  (pd1_target),
        .cfiType (pd1_cfi_type)
    );

    PreDecode u_predecode2 (
        .instr   (fs_inst2),
        .pc      (fs_pc2),
        .isRet   (pd2_is_ret),
        .isCall  (pd2_is_call),
        .target  (pd2_target),
        .cfiType (pd2_cfi_type)
    );

    PreDecode u_predecode3 (
        .instr   (fs_inst3),
        .pc      (fs_pc3),
        .isRet   (pd3_is_ret),
        .isCall  (pd3_is_call),
        .target  (pd3_target),
        .cfiType (pd3_cfi_type)
    );
    
    wire cfi0_valid = (pd0_cfi_type != 2'b00);
    wire cfi1_valid = (pd1_cfi_type != 2'b00);
    wire cfi2_valid = (pd2_cfi_type != 2'b00);
    wire cfi3_valid = (pd3_cfi_type != 2'b00);

    wire [3:0] pred_valid = {(~cfi3_valid && fs_pred_taken3),(~cfi2_valid && fs_pred_taken2),(~cfi1_valid && fs_pred_taken1),(~cfi0_valid && fs_pred_taken0)};
    wire [3:0] pred_cancel = pred_valid & mask_before_fspc & mask_after_first_pred;
    assign if_cancel_req    = fs_valid && (|fs_pred_taken) && (|pred_cancel) && inst_data_ok_real;
    assign if_cancel_target = fs_mmu_inst_uncache_en ? (fs_pc + 32'd4) : (fs_pc_aligned + 32'd16);
    assign fs_to_fb_bus = {//544
        // ?? 3 ????? (MSB)
        fs_pc3,                 // 32
        fs_inst3,               // 32
        fs_excps3,              // 7  (???  ?????)
        fs_badvaddr3,           // 32 (???  ????????)
        fs_pred_taken3,         // 1  (???  ????????)
        fs_pred_target3,        // 32 (???  ?????????)
                
        // ?? 2 ?????
        fs_pc2,                 // 32
        fs_inst2,               // 32
        fs_excps2,              // 7
        fs_badvaddr2,           // 32
        fs_pred_taken2,         // 1
        fs_pred_target2,        // 32
        
        // ?? 1 ?????
        fs_pc1,                 // 32
        fs_inst1,               // 32
        fs_excps1,              // 7
        fs_badvaddr1,           // 32
        fs_pred_taken1,         // 1
        fs_pred_target1,        // 32

        // ?? 0 ????? (LSB)
        fs_pc0,                 // 32
        fs_inst0,               // 32
        fs_excps0,              // 7
        fs_badvaddr0,           // 32
        fs_pred_taken0,         // 1
        fs_pred_target0         // 32
    };
endmodule
