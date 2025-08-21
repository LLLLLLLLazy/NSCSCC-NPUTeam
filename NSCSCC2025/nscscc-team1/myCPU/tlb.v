module tlb
#(
    parameter TLBNUM =32
)
 (
    input wire clk,

    //  search ports0(for fetch)
    input wire [18:0]  s0_vppn,            //虚拟访存地址 ???31....13 ???
    input wire s0_va_bit12,                //虚拟访存地址的第12位
    input wire [9:0] s0_asid,              //  CSR的ASID域，用于多线程比较
    output wire   s0_found,                //用于判断重填异常，页无效异常，特权等级不合规异常，页修改异常
    output wire  [$clog2(TLBNUM)-1:0] s0_index,         // 用于TLBSRCH指令，查找在第几项         
    output wire  [19:0] s0_ppn,                //用于产生物理地址
    output wire  [5:0] s0_ps,                  //用于产生物理地址
    output wire  [1:0] s0_plv,                 //用于判断特权等级不合规异常
    output wire  [1:0] s0_mat,                 
    output wire  s0_d,                          //用于判断页修改异常
    output wire s0_v,                           //用于判断页无效异常，页修改异常

    //  search ports1(for load/store)
    input wire [18:0]  s1_vppn,            //虚拟访存地址 ???31....13 ???
    input wire s1_va_bit12,                //虚拟访存地址的第12位
    input wire [9:0] s1_asid,              //  CSR的ASID域，用于多线程比较
    output wire   s1_found,                //用于判断重填异常，页无效异常，特权等级不合规异常，页修改异常
    output wire  [$clog2(TLBNUM)-1:0] s1_index,       // 用于TLBSRCH指令，查找在第几项       
    output wire  [19:0] s1_ppn,                //用于产生物理地址
    output wire  [5:0] s1_ps,                  //用于产生物理地址
    output wire  [1:0] s1_plv,                 //用于判断特权等级不合规异常
    output wire  [1:0] s1_mat,                 
    output wire  s1_d,                          //用于判断页修改异常
    output wire s1_v,                           //用于判断页无效异常，页修改异常

    //    search ports2(for tlbsrch)
    input wire [18:0] s2_vppn,
    input wire [9:0] s2_asid,
    output wire s2_found,
    output wire [$clog2(TLBNUM)-1:0] s2_index,

    // search ports3 (for cacop)
    input wire [18:0] s3_vppn,            // 虚拟访存地址[31:13]
    input wire s3_va_bit12,               // 虚拟访存地址的第12位
    input wire [9:0] s3_asid,             // CSR的ASID域
    output wire s3_found,                 // 命中标志
    output wire [$clog2(TLBNUM)-1:0] s3_index,  // 命中项索引
    output wire [19:0] s3_ppn,            // 物理页号
    output wire [5:0] s3_ps,              // 页大小
    output wire [1:0] s3_plv,             // 特权等级
    output wire [1:0] s3_mat,             // 存储访问类型
    output wire s3_d,                     // 脏位
    output wire s3_v,                     // 有效位

    //write port
    input wire    we,                           //写使能
    input wire   [$clog2(TLBNUM)-1:0] w_index,       //写的地址    
    input wire  w_e,                               //写数据
    input wire  [18:0]w_vppn,                      //要写的虚双页
    input wire  [5:0] w_ps,                       //要写的PS
    input wire  [9:0] w_asid,                     // 要写的ASID
    input wire  w_g,                             //要写的G
    input wire  [19:0] w_ppn0,                  //要写的ppn0
    input wire  [1:0] w_plv0,                     //要写的plv0
    input wire  [1:0] w_mat0,                     //要写的mat0
    input wire  w_d0,                           //要写的d0
    input wire  w_v0,                             //要写的v0
    input wire  [19:0] w_ppn1,                   //要写的ppn1
    input wire [1:0] w_plv1,                     //要写的plv1
    input wire  [1:0] w_mat1,                    //要写的mat1
    input wire  w_d1,                            //要写的d1
    input wire  w_v1,                            //要写的v1

    //read port
    input wire   [$clog2(TLBNUM)-1:0] r_index,       //读的地址    
    output wire  r_e,                               //读数据的e
    output wire  [18:0]r_vppn,                      //要读的虚双页
    output wire  [5:0] r_ps,                       //要读的PS
    output wire  [9:0] r_asid,                     // 要读的ASID
    output wire  r_g,                             //要读的G
    output wire  [19:0] r_ppn0,                  //要读的ppn0
    output wire  [1:0] r_plv0,                     //要读的plv0
    output wire  [1:0] r_mat0,                     //要读的mat0
    output wire  r_d0,                           //要读的d0
    output wire  r_v0,                             //要读的v0
    output wire  [19:0] r_ppn1,                   //要读的ppn1
    output wire [1:0] r_plv1,                     //要读的plv1
    output wire  [1:0] r_mat1,                    //要读的mat1
    output wire  r_d1,                            //要读的d1
    output wire  r_v1,                            //要读的v1

    // invtlb opcode
    input wire invtlb_valid,                     //用于Invtlb指令
    input wire [4:0] invtlb_op                 //Invtlb指令的操作码
);

    reg  [TLBNUM-1:0]tlb_e ;
    reg [TLBNUM-1:0] tlb_ps4MB;       // 1:4MB     0:4KB
    reg [18:0] tlb_vppn [TLBNUM-1:0];
    reg [9:0] tlb_asid [TLBNUM-1:0];
    reg tlb_g [TLBNUM-1:0];
    reg [19:0] tlb_ppn0 [TLBNUM-1:0];
    reg [1:0] tlb_plv0 [TLBNUM-1:0];
    reg [1:0] tlb_mat0 [TLBNUM-1:0];
    reg tlb_d0 [TLBNUM-1:0];
    reg tlb_v0 [TLBNUM-1:0];
    reg [19:0] tlb_ppn1 [TLBNUM-1:0];
    reg [1:0] tlb_plv1 [TLBNUM-1:0];
    reg [1:0] tlb_mat1 [TLBNUM-1:0];
    reg tlb_d1 [TLBNUM-1:0];
    reg tlb_v1 [TLBNUM-1:0];

    //查找操作
    wire [TLBNUM-1:0] match0;
    wire [TLBNUM-1:0] match1;
    wire [TLBNUM-1:0] match2;
    wire [TLBNUM-1:0] match3;

    
  genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : match_gen
        assign match0[i] = 
            (s0_vppn[18:9] == tlb_vppn[i][18:9]) &&
            (tlb_ps4MB[i] || s0_vppn[8:0] == tlb_vppn[i][8:0]) &&
            ((s0_asid == tlb_asid[i]) || tlb_g[i]) &&
            tlb_e[i];
        assign match1[i] = 
            (s1_vppn[18:9] == tlb_vppn[i][18:9]) &&
            (tlb_ps4MB[i] || s1_vppn[8:0] == tlb_vppn[i][8:0]) &&
            ((s1_asid == tlb_asid[i]) || tlb_g[i]) &&
            tlb_e[i];
        assign match2[i] = 
            (s2_vppn[18:9] == tlb_vppn[i][18:9]) &&
            (tlb_ps4MB[i] || s2_vppn[8:0] == tlb_vppn[i][8:0]) &&
            ((s2_asid == tlb_asid[i]) || tlb_g[i]) &&
            tlb_e[i];
        assign match3[i] = 
            (s3_vppn[18:9] == tlb_vppn[i][18:9]) &&
            (tlb_ps4MB[i] || s3_vppn[8:0] == tlb_vppn[i][8:0]) &&
            ((s3_asid == tlb_asid[i]) || tlb_g[i]) &&
            tlb_e[i];
    end
endgenerate

    
    assign s0_found = (match0 !=  0);
    assign s1_found = (match1 !=  0);
    assign s2_found = (match2 !=  0);
    assign s3_found = (match3 !=  0);


    encoder_32_5 en_match0 (.in({{(32-TLBNUM){1'b0}},match0}), .out(s0_index));
    encoder_32_5 en_match1 (.in({{(32-TLBNUM){1'b0}},match1}), .out(s1_index));
    encoder_32_5 en_match2 (.in({{(32-TLBNUM){1'b0}},match2}), .out(s2_index));
    encoder_32_5 en_match3 (.in({{(32-TLBNUM){1'b0}},match3}), .out(s3_index));

    assign s0_ppn = s0_va_bit12 ? tlb_ppn1[s0_index] :  tlb_ppn0[s0_index];
    assign s1_ppn = s1_va_bit12 ? tlb_ppn1[s1_index] :  tlb_ppn0[s1_index];
    assign s3_ppn = s3_va_bit12 ? tlb_ppn1[s3_index] :  tlb_ppn0[s3_index];
    assign s0_ps  = tlb_ps4MB[s0_index] ?  6'd21 : 6'd12;
    assign s1_ps  = tlb_ps4MB[s1_index] ?  6'd21:  6'd12;
    assign s3_ps  = tlb_ps4MB[s3_index] ?  6'd21:  6'd12;
    assign s0_plv = s0_va_bit12 ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s1_plv = s1_va_bit12 ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s3_plv = s3_va_bit12 ? tlb_plv1[s3_index] : tlb_plv0[s3_index];
    assign s0_mat = s0_va_bit12 ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s1_mat = s1_va_bit12 ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s3_mat = s3_va_bit12 ? tlb_mat1[s3_index] : tlb_mat0[s3_index];
    assign s0_d   = s0_va_bit12 ? tlb_d1[s0_index]   : tlb_d0[s0_index];
    assign s1_d   = s1_va_bit12 ? tlb_d1[s1_index]   : tlb_d0[s1_index];
    assign s3_d   = s3_va_bit12 ? tlb_d1[s3_index]   : tlb_d0[s3_index];
    assign s0_v   = s0_va_bit12 ? tlb_v1[s0_index]   : tlb_v0[s0_index];
    assign s1_v   = s1_va_bit12 ? tlb_v1[s1_index]   : tlb_v0[s1_index];
    assign s3_v   = s3_va_bit12 ? tlb_v1[s3_index]   : tlb_v0[s3_index];

     //写操作
     always @(posedge clk)
     begin
        if(we)
        begin
        tlb_vppn [w_index] <= w_vppn;
        tlb_asid [w_index] <= w_asid;
        tlb_g    [w_index] <= w_g; 
        tlb_ps4MB   [w_index] <= w_ps[0];  
        tlb_ppn0 [w_index] <= w_ppn0;
        tlb_plv0 [w_index] <= w_plv0;
        tlb_mat0 [w_index] <= w_mat0;
        tlb_d0   [w_index] <= w_d0;
        tlb_v0   [w_index] <= w_v0; 
        tlb_ppn1 [w_index] <= w_ppn1;
        tlb_plv1 [w_index] <= w_plv1;
        tlb_mat1 [w_index] <= w_mat1;
        tlb_d1   [w_index] <= w_d1;
        tlb_v1   [w_index] <= w_v1; 
        end
     end

     //读操作
    assign r_vppn  =  tlb_vppn [r_index]; 
    assign r_asid  =  tlb_asid [r_index]; 
    assign r_g     =  tlb_g    [r_index]; 
    assign r_ps    =  tlb_ps4MB[r_index] ? 6'd21 : 6'd12; 
    assign r_e     =  tlb_e    [r_index]; 
    assign r_v0    =  tlb_v0   [r_index]; 
    assign r_d0    =  tlb_d0   [r_index]; 
    assign r_mat0  =  tlb_mat0 [r_index]; 
    assign r_plv0  =  tlb_plv0 [r_index]; 
    assign r_ppn0  =  tlb_ppn0 [r_index]; 
    assign r_v1    =  tlb_v1   [r_index]; 
    assign r_d1    =  tlb_d1   [r_index]; 
    assign r_mat1  =  tlb_mat1 [r_index]; 
    assign r_plv1  =  tlb_plv1 [r_index]; 
    assign r_ppn1  =  tlb_ppn1 [r_index]; 

    // INVTLB 指令相关的操作
    always @(posedge clk)
    begin
        if(we)
        begin
            tlb_e[w_index]  <=w_e;
        end
        else if(invtlb_valid)
        begin
            case (invtlb_op)
                5'd0   :    begin
                    tlb_e <= 16'b0;
                end
                5'd1   :begin
                    tlb_e <= 16'b0;
                end
                5'd2   :begin
                    tlb_e[0]  <= tlb_g[0]  ? 1'b0 : tlb_e[0];
                    tlb_e[1]  <= tlb_g[1]  ? 1'b0 : tlb_e[1];
                    tlb_e[2]  <= tlb_g[2]  ? 1'b0 : tlb_e[2];
                    tlb_e[3]  <= tlb_g[3]  ? 1'b0 : tlb_e[3];
                    tlb_e[4]  <= tlb_g[4]  ? 1'b0 : tlb_e[4];
                    tlb_e[5]  <= tlb_g[5]  ? 1'b0 : tlb_e[5];
                    tlb_e[6]  <= tlb_g[6]  ? 1'b0 : tlb_e[6];
                    tlb_e[7]  <= tlb_g[7]  ? 1'b0 : tlb_e[7];
                    tlb_e[8]  <= tlb_g[8]  ? 1'b0 : tlb_e[8];
                    tlb_e[9]  <= tlb_g[9]  ? 1'b0 : tlb_e[9];
                    tlb_e[10] <= tlb_g[10] ? 1'b0 : tlb_e[10];
                    tlb_e[11] <= tlb_g[11] ? 1'b0 : tlb_e[11];
                    tlb_e[12] <= tlb_g[12] ? 1'b0 : tlb_e[12];
                    tlb_e[13] <= tlb_g[13] ? 1'b0 : tlb_e[13];
                    tlb_e[14] <= tlb_g[14] ? 1'b0 : tlb_e[14];
                    tlb_e[15] <= tlb_g[15] ? 1'b0 : tlb_e[15];
                end
                5'd3   :begin
                    tlb_e[0] <= (tlb_e[0] & tlb_g[0]);
                    tlb_e[1] <= (tlb_e[1] & tlb_g[1]);
                    tlb_e[2] <= (tlb_e[2] & tlb_g[2]);
                    tlb_e[3] <= (tlb_e[3] & tlb_g[3]);
                    tlb_e[4] <= (tlb_e[4] & tlb_g[4]);
                    tlb_e[5] <= (tlb_e[5] & tlb_g[5]);
                    tlb_e[6] <= (tlb_e[6] & tlb_g[6]);
                    tlb_e[7] <= (tlb_e[7] & tlb_g[7]);
                    tlb_e[8] <= (tlb_e[8] & tlb_g[8]);
                    tlb_e[9] <= (tlb_e[9] & tlb_g[9]);
                    tlb_e[10] <= (tlb_e[10] & tlb_g[10]);
                    tlb_e[11] <= (tlb_e[11] & tlb_g[11]);
                    tlb_e[12] <= (tlb_e[12] & tlb_g[12]);
                    tlb_e[13] <= (tlb_e[13] & tlb_g[13]);
                    tlb_e[14] <= (tlb_e[14] & tlb_g[14]);
                    tlb_e[15] <= (tlb_e[15] & tlb_g[15]);
                end
                5'd4   :begin
                    tlb_e[0]  <= (tlb_g[0]  == 0 && s2_asid == tlb_asid[0])  ? 1'b0 : tlb_e[0];
                    tlb_e[1]  <= (tlb_g[1]  == 0 && s2_asid == tlb_asid[1])  ? 1'b0 : tlb_e[1];
                    tlb_e[2]  <= (tlb_g[2]  == 0 && s2_asid == tlb_asid[2])  ? 1'b0 : tlb_e[2];
                    tlb_e[3]  <= (tlb_g[3]  == 0 && s2_asid == tlb_asid[3])  ? 1'b0 : tlb_e[3];
                    tlb_e[4]  <= (tlb_g[4]  == 0 && s2_asid == tlb_asid[4])  ? 1'b0 : tlb_e[4];
                    tlb_e[5]  <= (tlb_g[5]  == 0 && s2_asid == tlb_asid[5])  ? 1'b0 : tlb_e[5];
                    tlb_e[6]  <= (tlb_g[6]  == 0 && s2_asid == tlb_asid[6])  ? 1'b0 : tlb_e[6];
                    tlb_e[7]  <= (tlb_g[7]  == 0 && s2_asid == tlb_asid[7])  ? 1'b0 : tlb_e[7];
                    tlb_e[8]  <= (tlb_g[8]  == 0 && s2_asid == tlb_asid[8])  ? 1'b0 : tlb_e[8];
                    tlb_e[9]  <= (tlb_g[9]  == 0 && s2_asid == tlb_asid[9])  ? 1'b0 : tlb_e[9];
                    tlb_e[10] <= (tlb_g[10] == 0 && s2_asid == tlb_asid[10]) ? 1'b0 : tlb_e[10];
                    tlb_e[11] <= (tlb_g[11] == 0 && s2_asid == tlb_asid[11]) ? 1'b0 : tlb_e[11];
                    tlb_e[12] <= (tlb_g[12] == 0 && s2_asid == tlb_asid[12]) ? 1'b0 : tlb_e[12];
                    tlb_e[13] <= (tlb_g[13] == 0 && s2_asid == tlb_asid[13]) ? 1'b0 : tlb_e[13];
                    tlb_e[14] <= (tlb_g[14] == 0 && s2_asid == tlb_asid[14]) ? 1'b0 : tlb_e[14];
                    tlb_e[15] <= (tlb_g[15] == 0 && s2_asid == tlb_asid[15]) ? 1'b0 : tlb_e[15];
                end
                5'd5   :begin
                    tlb_e[0]  <= (tlb_g[0]  == 0 && s2_asid == tlb_asid[0]  && s2_vppn == tlb_vppn[0])  ? 1'b0 : tlb_e[0];
                    tlb_e[1]  <= (tlb_g[1]  == 0 && s2_asid == tlb_asid[1]  && s2_vppn == tlb_vppn[1])  ? 1'b0 : tlb_e[1];
                    tlb_e[2]  <= (tlb_g[2]  == 0 && s2_asid == tlb_asid[2]  && s2_vppn == tlb_vppn[2])  ? 1'b0 : tlb_e[2];
                    tlb_e[3]  <= (tlb_g[3]  == 0 && s2_asid == tlb_asid[3]  && s2_vppn == tlb_vppn[3])  ? 1'b0 : tlb_e[3];
                    tlb_e[4]  <= (tlb_g[4]  == 0 && s2_asid == tlb_asid[4]  && s2_vppn == tlb_vppn[4])  ? 1'b0 : tlb_e[4];
                    tlb_e[5]  <= (tlb_g[5]  == 0 && s2_asid == tlb_asid[5]  && s2_vppn == tlb_vppn[5])  ? 1'b0 : tlb_e[5];
                    tlb_e[6]  <= (tlb_g[6]  == 0 && s2_asid == tlb_asid[6]  && s2_vppn == tlb_vppn[6])  ? 1'b0 : tlb_e[6];
                    tlb_e[7]  <= (tlb_g[7]  == 0 && s2_asid == tlb_asid[7]  && s2_vppn == tlb_vppn[7])  ? 1'b0 : tlb_e[7];
                    tlb_e[8]  <= (tlb_g[8]  == 0 && s2_asid == tlb_asid[8]  && s2_vppn == tlb_vppn[8])  ? 1'b0 : tlb_e[8];
                    tlb_e[9]  <= (tlb_g[9]  == 0 && s2_asid == tlb_asid[9]  && s2_vppn == tlb_vppn[9])  ? 1'b0 : tlb_e[9];
                    tlb_e[10] <= (tlb_g[10] == 0 && s2_asid == tlb_asid[10] && s2_vppn == tlb_vppn[10]) ? 1'b0 : tlb_e[10];
                    tlb_e[11] <= (tlb_g[11] == 0 && s2_asid == tlb_asid[11] && s2_vppn == tlb_vppn[11]) ? 1'b0 : tlb_e[11];
                    tlb_e[12] <= (tlb_g[12] == 0 && s2_asid == tlb_asid[12] && s2_vppn == tlb_vppn[12]) ? 1'b0 : tlb_e[12];
                    tlb_e[13] <= (tlb_g[13] == 0 && s2_asid == tlb_asid[13] && s2_vppn == tlb_vppn[13]) ? 1'b0 : tlb_e[13];
                    tlb_e[14] <= (tlb_g[14] == 0 && s2_asid == tlb_asid[14] && s2_vppn == tlb_vppn[14]) ? 1'b0 : tlb_e[14];
                    tlb_e[15] <= (tlb_g[15] == 0 && s2_asid == tlb_asid[15] && s2_vppn == tlb_vppn[15]) ? 1'b0 : tlb_e[15];
                end
                5'd6   :begin
                    tlb_e[0]  <= ((tlb_g[0]  == 1 || s2_asid == tlb_asid[0])  && s2_vppn == tlb_vppn[0])  ? 1'b0 : tlb_e[0];
                    tlb_e[1]  <= ((tlb_g[1]  == 1 || s2_asid == tlb_asid[1])  && s2_vppn == tlb_vppn[1])  ? 1'b0 : tlb_e[1];
                    tlb_e[2]  <= ((tlb_g[2]  == 1 || s2_asid == tlb_asid[2])  && s2_vppn == tlb_vppn[2])  ? 1'b0 : tlb_e[2];
                    tlb_e[3]  <= ((tlb_g[3]  == 1 || s2_asid == tlb_asid[3])  && s2_vppn == tlb_vppn[3])  ? 1'b0 : tlb_e[3];
                    tlb_e[4]  <= ((tlb_g[4]  == 1 || s2_asid == tlb_asid[4])  && s2_vppn == tlb_vppn[4])  ? 1'b0 : tlb_e[4];
                    tlb_e[5]  <= ((tlb_g[5]  == 1 || s2_asid == tlb_asid[5])  && s2_vppn == tlb_vppn[5])  ? 1'b0 : tlb_e[5];
                    tlb_e[6]  <= ((tlb_g[6]  == 1 || s2_asid == tlb_asid[6])  && s2_vppn == tlb_vppn[6])  ? 1'b0 : tlb_e[6];
                    tlb_e[7]  <= ((tlb_g[7]  == 1 || s2_asid == tlb_asid[7])  && s2_vppn == tlb_vppn[7])  ? 1'b0 : tlb_e[7];
                    tlb_e[8]  <= ((tlb_g[8]  == 1 || s2_asid == tlb_asid[8])  && s2_vppn == tlb_vppn[8])  ? 1'b0 : tlb_e[8];
                    tlb_e[9]  <= ((tlb_g[9]  == 1 || s2_asid == tlb_asid[9])  && s2_vppn == tlb_vppn[9])  ? 1'b0 : tlb_e[9];
                    tlb_e[10] <= ((tlb_g[10] == 1 || s2_asid == tlb_asid[10]) && s2_vppn == tlb_vppn[10]) ? 1'b0 : tlb_e[10];
                    tlb_e[11] <= ((tlb_g[11] == 1 || s2_asid == tlb_asid[11]) && s2_vppn == tlb_vppn[11]) ? 1'b0 : tlb_e[11];
                    tlb_e[12] <= ((tlb_g[12] == 1 || s2_asid == tlb_asid[12]) && s2_vppn == tlb_vppn[12]) ? 1'b0 : tlb_e[12];
                    tlb_e[13] <= ((tlb_g[13] == 1 || s2_asid == tlb_asid[13]) && s2_vppn == tlb_vppn[13]) ? 1'b0 : tlb_e[13];
                    tlb_e[14] <= ((tlb_g[14] == 1 || s2_asid == tlb_asid[14]) && s2_vppn == tlb_vppn[14]) ? 1'b0 : tlb_e[14];
                    tlb_e[15] <= ((tlb_g[15] == 1 || s2_asid == tlb_asid[15]) && s2_vppn == tlb_vppn[15]) ? 1'b0 : tlb_e[15];

                end
                default: 
                    tlb_e <= tlb_e;
            endcase

        end        
    end









endmodule