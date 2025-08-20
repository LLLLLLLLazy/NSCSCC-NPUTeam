module mmu(
    input  wire        clk,
    input  wire        reset,
    input  wire        ex_flush,
    input  wire        ertn_flush,
    input  wire        refetch_flush,

    input  wire        crmd_da,
    input  wire        crmd_pg,
    input  wire [ 1:0] crmd_plv, // 当前特权等级
    input  wire [31:0] dmw0,
    input  wire [31:0] dmw1,

    input  wire        s0_found,
    input  wire [19:0] s0_ppn,      
    input  wire [ 5:0] s0_ps,       
    input  wire [ 1:0] s0_plv,
    input  wire [ 1:0] s0_mat,
    input  wire        s0_d,
    input  wire        s0_v,

    input  wire        s1_found,
    input  wire [19:0] s1_ppn,      
    input  wire [ 5:0] s1_ps,       
    input  wire [ 1:0] s1_plv,
    input  wire [ 1:0] s1_mat, //没用
    input  wire        s1_d,
    input  wire        s1_v,

    input  wire        inst_st,
    input  wire        inst_ld, 
    input  wire        id_valid,
    input  wire        ex_fire,

    input  wire [31:0] inst_vaddr,
    input  wire [31:0] data_vaddr,

    output wire [31:0] inst_paddr,
    output wire [31:0] data_paddr,

    output wire        tlbr_ex0, // 取指 TLB 重填例外
    output reg         tlbr_ex1, // 数据 TLB 重填例外
    output wire        pif_ex,   // 取指页无效
    output reg         pil_ex,   // load页无效
    output reg         pis_ex,   // store页无效
    output wire        ppi_ex0,  // 取指页特权异常
    output reg         ppi_ex1,  // 数据页特权异常
    output reg         pme_ex,   // store页修改异常

    output wire [ 1:0] inst_access_type,
    output reg  [ 1:0] data_access_type
);

    // 直接地址翻译模式
    wire [31:0] direct_inst_paddr = inst_vaddr;
    wire [31:0] direct_data_paddr = data_vaddr;

    wire        direct_inst_hit = (crmd_da == 1'b1 && crmd_pg == 1'b0);
    wire        direct_data_hit = (crmd_da == 1'b1 && crmd_pg == 1'b0);


    // 窗口地址翻译模式
    wire        srch_dmw = (crmd_da == 1'b0) && (crmd_pg == 1'b1);

    wire [31:0] dmw0_inst_paddr = {dmw0[27:25], inst_vaddr[28:0]};
    wire [31:0] dmw1_inst_paddr = {dmw1[27:25], inst_vaddr[28:0]};
    wire [31:0] dmw0_data_paddr = {dmw0[27:25], data_vaddr[28:0]};
    wire [31:0] dmw1_data_paddr = {dmw1[27:25], data_vaddr[28:0]};

    wire        dmw0_inst_hit = (inst_vaddr[31:29] == dmw0[31:29]) && (dmw0[crmd_plv] == 1'b1) && srch_dmw;
    wire        dmw0_data_hit = (data_vaddr[31:29] == dmw0[31:29]) && (dmw0[crmd_plv] == 1'b1) && srch_dmw;
    wire        dmw1_inst_hit = (inst_vaddr[31:29] == dmw1[31:29]) && (dmw1[crmd_plv] == 1'b1) && srch_dmw;
    wire        dmw1_data_hit = (data_vaddr[31:29] == dmw1[31:29]) && (dmw1[crmd_plv] == 1'b1) && srch_dmw;


    // 查TLB
    wire        srch_tlb_inst = srch_dmw && !dmw0_inst_hit && !dmw1_inst_hit;
    wire        srch_tlb_data = srch_dmw && !dmw0_data_hit && !dmw1_data_hit;

    wire        tlb_inst_hit = s0_found && srch_tlb_inst;
    wire        tlb_data_hit = s1_found && srch_tlb_data;

    wire [31:0] tlb_inst_paddr = (s0_ps == 6'd12) ? {s0_ppn[19:0],  inst_vaddr[11:0]} :
                                 (s0_ps == 6'd21) ? {s0_ppn[19:10],  inst_vaddr[21:0]} : 32'b0;
                                 
    wire [31:0] tlb_data_paddr = (s1_ps == 6'd12) ? {s1_ppn[19:0],  data_vaddr[11:0]} :
                                 (s1_ps == 6'd21) ? {s1_ppn[19:10],  data_vaddr[21:0]} : 32'b0;


    // paddr  
    assign inst_paddr = direct_inst_hit  ? direct_inst_paddr
                      : dmw0_inst_hit    ? dmw0_inst_paddr
                      : dmw1_inst_hit    ? dmw1_inst_paddr
                      : tlb_inst_hit     ? tlb_inst_paddr
                      : 32'b0;

    assign data_paddr = direct_data_hit  ? direct_data_paddr
                      : dmw0_data_hit    ? dmw0_data_paddr
                      : dmw1_data_hit    ? dmw1_data_paddr
                      : tlb_data_hit     ? tlb_data_paddr
                      : 32'b0;


    // exception
    // 有 exception 的时候记得不要向总线发请求 （控制 req 信号），同时注意阻止请求的同时不要阻塞流水线
    //wire temp_tlbr_ex0 = srch_tlb_inst && !tlb_inst_hit;
    //wire temp_tlbr_ex1 = srch_tlb_data && !tlb_data_hit && (inst_ld || inst_st) && id_valid; 
    wire temp_tlbr_ex0 = srch_tlb_inst && !s0_found;
    wire temp_tlbr_ex1 = srch_tlb_data && !s1_found && (inst_ld || inst_st) && id_valid;

    wire temp_pif_ex   = srch_tlb_inst && !s0_v ;
    wire temp_pil_ex   = srch_tlb_data && !s1_v && inst_ld && id_valid;
    wire temp_pis_ex   = srch_tlb_data && !s1_v && inst_st && id_valid;

    wire temp_ppi_ex0  = srch_tlb_inst && (crmd_plv > s0_plv) && s0_v;
    wire temp_ppi_ex1  = srch_tlb_data && (crmd_plv > s1_plv) && s1_v && (inst_ld || inst_st) && id_valid;
     
    wire temp_pme_ex   = srch_tlb_data && inst_st && s1_v && (crmd_plv <= s1_plv) && !s1_d && id_valid;


    wire [1:0] temp_inst_access_type = direct_inst_hit? 2'b00 :
                                       dmw0_inst_hit?   2'b01 :
                                       dmw1_inst_hit?   2'b10 :
                                       tlb_inst_hit?    2'b11 : 2'b00;

    wire [1:0] temp_data_access_type = direct_data_hit? 2'b00 :
                                       dmw0_data_hit?   2'b01 :
                                       dmw1_data_hit?   2'b10 :
                                       tlb_data_hit?    2'b11 : 2'b00;

    assign tlbr_ex0 = temp_tlbr_ex0;
    assign pif_ex   = temp_pif_ex;
    assign ppi_ex0  = temp_ppi_ex0;
    assign inst_access_type = temp_inst_access_type;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tlbr_ex1 <= 1'b0;
            pil_ex   <= 1'b0;
            pis_ex   <= 1'b0;
            ppi_ex1  <= 1'b0;
            pme_ex   <= 1'b0;

            data_access_type <= 2'b00;
        end
        else if (ertn_flush || ex_flush || refetch_flush) begin
            tlbr_ex1 <= 1'b0;
            pil_ex   <= 1'b0;
            pis_ex   <= 1'b0;
            ppi_ex1  <= 1'b0;
            pme_ex   <= 1'b0;

            data_access_type <= 2'b00;
        end
        else if (ex_fire) begin
            tlbr_ex1 <= temp_tlbr_ex1;
            pil_ex   <= temp_pil_ex;
            pis_ex   <= temp_pis_ex;
            ppi_ex1  <= temp_ppi_ex1;
            pme_ex   <= temp_pme_ex;

            data_access_type <= temp_data_access_type;
        end
    end

endmodule