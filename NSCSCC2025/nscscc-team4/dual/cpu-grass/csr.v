`include "header.h"
`include "csr.h"
//双发CSR，一个写端口，两个读端口
module csr (
    input                   clk,
    input                   reset,

    input                   MEM_ex,
    input   [ 5:0]          MEM_ecode,
    input   [ 8:0]          MEM_esubcode,
    input                   va_error,
    input                   MEM_excp_tlb,
    input   [31:0]          MEM_pc,
    input   [31:0]          MEM_vaddr,

    input   [13:0]          csr_wnum,
    input   [13:0]          csr_rnum1,
    input   [13:0]          csr_rnum2,
    input                   csr_we,
    input   [31:0]          csr_wmask,
    input   [31:0]          csr_wvalue,
    output  [31:0]          csr_rvalue1,
    output  [31:0]          csr_rvalue2,

    input                   ipi_int_in,
    input   [ 7:0]          hw_int_in,
    input                   coreid_in,
    input                   ertn_flush,
    input                   refill_ex,

    input   [98-5+`WIDTH_TLB_INDEX:0]          csr_tlb_in,
    output  [99-10+2*`WIDTH_TLB_INDEX:0]          csr_tlb_out,

    output  [31:0]          ex_entry,       //to pre_IF
    output                  has_int,        //to ID
    output  [63:0]          stable_counter, //to ID
    output  reg   [31:0]    counter_id,

    output  [31:0]          csr_tlbehi_rvalue,
    output  [31:0]          csr_crmd_rvalue,
    output  [31:0]          csr_dmw0_rvalue,
    output  [31:0]          csr_dmw1_rvalue,
    output  [31:0]          csr_tlbrentry_rvalue,
    output  [31:0]          csr_era_rvalue,
    output  [31:0]          csr_asid_rvalue,
    output  [ 1:0]          csr_plv,
    output                  disable_cache_out,

    input                   llbit_in,
    input                   llbit_set_in,
    input   [27:0]          lladdr_in,
    input                   lladdr_set_in,
    output                  llbit_out,
    output  [27:0]          lladdr_out
    `ifdef DIFFTEST_EN
    ,
    output  [ 4:0]          rand_index,
    output  [31:0]          csr_crmd_diff,
    output  [31:0]          csr_prmd_diff,
    output  [31:0]          csr_ecfg_diff,
    output  [31:0]          csr_estat_diff,
    output  [31:0]          csr_era_diff,
    output  [31:0]          csr_badv_diff,
    output  [31:0]          csr_eentry_diff,
    output  [31:0]          csr_tlbidx_diff,
    output  [31:0]          csr_tlbehi_diff,
    output  [31:0]          csr_tlbelo0_diff,
    output  [31:0]          csr_tlbelo1_diff,
    output  [31:0]          csr_asid_diff,
    output  [31:0]          csr_save0_diff,
    output  [31:0]          csr_save1_diff,
    output  [31:0]          csr_save2_diff,
    output  [31:0]          csr_save3_diff,
    output  [31:0]          csr_tid_diff,
    output  [31:0]          csr_tcfg_diff,
    output  [31:0]          csr_tval_diff,
    output  [31:0]          csr_ticlr_diff,
    output  [31:0]          csr_llbctl_diff,
    output  [31:0]          csr_tlbrentry_diff,
    output  [31:0]          csr_dmw0_diff,
    output  [31:0]          csr_dmw1_diff,
    output  [31:0]          csr_pgdl_diff,
    output  [31:0]          csr_pgdh_diff
`endif                      
);
wire                    inst_tlbwr;  //98
wire                    inst_tlbfill;//97  
wire                    inst_tlbsrch;//96
wire                    inst_tlbrd;  //95
wire                    s1_found;    //94
wire [`WIDTH_TLB_INDEX-1:0] s1_index;//93:89
wire                    r_e_input;   //for TLB_NUM change
reg                     r_e;         //88
wire [18:0]             r_vppn;      //87:69
wire [ 5:0]             r_ps;        //68:63
wire [ 9:0]             r_asid;      //62:53
wire                    r_g;         //52
wire [19:0]             r_ppn0;      //51:32
wire [ 1:0]             r_plv0;      //31:30
wire [ 1:0]             r_mat0;      //29:28
wire                    r_d0;        //27
wire                    r_v0;        //26
wire [19:0]             r_ppn1;      //25:6
wire [ 1:0]             r_plv1;      //5:4
wire [ 1:0]             r_mat1;      //3:2
wire                    r_d1;        //1
wire                    r_v1;        //0


assign {
    inst_tlbwr,  //98
    inst_tlbfill,//97
    inst_tlbsrch,//96
    inst_tlbrd,  //95
    s1_found,    //94
    s1_index,    //93:89
    r_e_input,   //88
    r_vppn,      //87:69
    r_ps,        //68:63
    r_asid,      //62:53
    r_g,         //52
    r_ppn0,      //51:32
    r_plv0,      //31:30
    r_mat0,      //29:28
    r_d0,        //27
    r_v0,        //26
    r_ppn1,      //25:6
    r_plv1,      //5:4
    r_mat1,      //3:2
    r_d1,        //1
    r_v1
} = csr_tlb_in;

wire        we;
wire [`WIDTH_TLB_INDEX-1:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [ 5:0] w_ps;
wire [ 9:0] w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;
wire [`WIDTH_TLB_INDEX-1:0] r_index;

//ESTAT寄存器，例外状态寄存器，包括IS，IS，0，IS，IS，0，Ecode，EsubCode，0，共32位
reg [12:0] csr_estat_is;
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;
reg [31:0] timer_cnt;
//提前写了

//CRMD寄存器，存放当前模式信息，包括PLV，IE，DA，PG，DATF，DATM，0这些部分,32位
reg [1:0] csr_crmd_plv;
reg csr_crmd_ie;
reg csr_crmd_da;
reg csr_crmd_pg;
reg [1:0] csr_crmd_datf;
reg [1:0] csr_crmd_datm;
reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;
//PLV区域
always @(posedge clk ) begin
    if (reset)
        csr_crmd_plv<=2'b0;
    else if (MEM_ex)
        csr_crmd_plv<=2'b0;
    else if (ertn_flush)
        csr_crmd_plv<=csr_prmd_pplv;
    else if (csr_we&&csr_wnum==`CSR_CRMD)
        csr_crmd_plv<=csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]|~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
end

assign csr_plv = csr_crmd_plv;

//IE区域
always @(posedge clk) begin
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (MEM_ex)
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_wnum==`CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE]| ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
end
//DA、PG、DATF、DATM目前只支持地址翻译模式
always @(posedge clk ) begin
    if(reset)begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
        csr_crmd_datf <= 2'b00;
        csr_crmd_datm <= 2'b00;
    end
    else if (refill_ex) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if (ertn_flush) begin
        if(csr_estat_ecode == `ECODE_TLBR)begin
            csr_crmd_pg <= 1'b1;
            csr_crmd_da <= 1'b0;
        end
    end
    else if(csr_we && csr_wnum == `CSR_CRMD)begin
        csr_crmd_da  <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                     | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        csr_crmd_pg  <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                     | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]
                     | ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
        csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]
                     | ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;                  
    end
end

assign  csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie,csr_crmd_plv};

//PRMD寄存器，存放例外前模式信息，包括PPLV、PIE、0等区域，共32位
always @(posedge clk) begin
    if ((MEM_ex) && csr_crmd_rvalue != 3'b000) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if (csr_we && csr_wnum==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]| ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]| ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
end

wire [31:0] csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};


//ECFG寄存器，例外控制，包括LIE、0，LIE，0等模块，共32位
reg [12:0] csr_ecfg_lie;

always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_wnum==`CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]| ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;
end

wire [31:0] csr_ecfg_rvalue = {19'b0,csr_ecfg_lie};

//ESTAT寄存器，例外状态寄存器，包括IS，IS，0，IS，IS，0，Ecode，EsubCode，0，共32位
//IS区域
always @(posedge clk) begin
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_wnum==`CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]| ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
        
    csr_estat_is[9:2] <= hw_int_in[7:0];
    csr_estat_is[10] <= 1'b0;

    if (timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_wnum==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]&& csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
    
    csr_estat_is[12] <= 1'b0;//ipi_int_in;
end
assign has_int=((csr_estat_is[12:0]&csr_ecfg_lie[12:0]) !=13'b0)&&(csr_crmd_ie== 1'b1);
//Ecode和EsubCode区域
always @(posedge clk) begin
    if (MEM_ex) begin
        csr_estat_ecode <= MEM_ecode;
        csr_estat_esubcode <= MEM_esubcode;
    end
end

wire [31:0] csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};

//ERA寄存器，例外返回，包括PC，共32位
reg [31:0]csr_era_pc;
always @(posedge clk) begin
    if (MEM_ex)
        csr_era_pc <= MEM_pc;
    else if (csr_we && csr_wnum==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]| ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
end
assign csr_era_rvalue = csr_era_pc;

//BADV寄存器，出错虚地址，包括VAddr，共32位
reg [31:0]csr_badv_vaddr;

always @(posedge clk) begin
    if (csr_we && csr_wnum==`CSR_BADV)begin
        csr_badv_vaddr <= csr_wmask & csr_wvalue | ~csr_wmask & csr_badv_vaddr;
    end    
    else if (va_error)begin
        csr_badv_vaddr <= MEM_vaddr;
    end    


end
wire [31:0] csr_badv_rvalue = csr_badv_vaddr;

//EENTRY寄存器，例外入口地址，包括0，VA，共32位
reg [25:0]csr_eentry_va;
always @(posedge clk) begin
    if(reset) csr_eentry_va <= 26'b0;//{24'h1c00_8, 2'b00};
    else if (csr_we && csr_wnum==`CSR_EENTRY) begin
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA] | 
                        ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end
end

wire [31:0] csr_eentry_rvalue;

assign csr_eentry_rvalue = {csr_eentry_va,6'b0};
assign ex_entry = csr_eentry_rvalue;

//TLBIDX,分为index，ps，ne三部分
reg [4:0] csr_tlbidx_index;
reg [5:0] csr_tlbidx_ps;
reg csr_tlbidx_ne;

// default index <= 5
always@(*) begin
    if(`WIDTH_TLB_INDEX == 5) begin
        r_e = r_e_input;
    end
    else begin
        r_e = r_e_input & ~(|csr_tlbidx_index[4:`WIDTH_TLB_INDEX]); //超过index的部分一旦有1就不found
    end
end

always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_ne    <= 1'b1;
        csr_tlbidx_ps    <= 6'b0;
        csr_tlbidx_index <= 5'b0;
    end
    else if(inst_tlbsrch) begin
        if(s1_found) begin
            csr_tlbidx_ne    <= 1'b0;
            csr_tlbidx_index <= s1_index;
        end
        else 
            csr_tlbidx_ne    <= 1'b1;
    end
    else if(inst_tlbrd) begin
        csr_tlbidx_ne    <= ~r_e;
        csr_tlbidx_ps    <= {6{r_e}} & r_ps;
    end
    else if(csr_we && csr_wnum==`CSR_TLBIDX)begin
        csr_tlbidx_ne    <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                         | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne; 
        csr_tlbidx_ps    <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                         | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                         | ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
    end
end
wire [31:0]csr_tlbidx_rvalue = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,19'b0,csr_tlbidx_index};

//TLBEHI,分为0，vppn两部分，共32位
reg [18:0] csr_tlbehi_vppn;
always @(posedge clk ) begin
    if(reset)begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(inst_tlbrd) begin
        if(r_e) csr_tlbehi_vppn <= r_vppn;
        else csr_tlbehi_vppn <= 19'b0;
    end
    else if (MEM_excp_tlb) begin
        csr_tlbehi_vppn <= MEM_vaddr[31:13];
    end
    else if(csr_we && csr_wnum == `CSR_TLBEHI) begin
        csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                        | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;   
    end 
end

assign csr_tlbehi_rvalue = {csr_tlbehi_vppn,13'b0};


//TLBELO0,分为v，d，plv，mat，g，0，ppn，0等部分
reg csr_tlbelo0_v;
reg csr_tlbelo0_d;
reg [1:0] csr_tlbelo0_plv;
reg [1:0] csr_tlbelo0_mat;
reg csr_tlbelo0_g;
reg [19:0]csr_tlbelo0_ppn;

always @(posedge clk ) begin
    if(reset)
    begin
        csr_tlbelo0_v   <= 1'b0;
        csr_tlbelo0_d   <= 1'b0;
        csr_tlbelo0_plv <= 2'b0;
        csr_tlbelo0_mat <= 2'b0;
        csr_tlbelo0_g   <= 1'b0;
        csr_tlbelo0_ppn <= 20'b0;
    end
    else if(inst_tlbrd)begin
        if(r_e) begin
            csr_tlbelo0_v   <= r_v0;
            csr_tlbelo0_d   <= r_d0;
            csr_tlbelo0_plv <= r_plv0;
            csr_tlbelo0_mat <= r_mat0;
            csr_tlbelo0_g   <= r_g;
            csr_tlbelo0_ppn <= r_ppn0;
        end
        else begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 20'b0;
        end
    end
    else if(csr_we && csr_wnum == `CSR_TLBELO0) begin
        csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo0_v; 
        csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo0_d;
        csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
        csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo0_g;    
    end
end
wire [31:0] csr_tlbelo0_rvalue = {4'b0,csr_tlbelo0_ppn,1'b0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};

//TLBELO1
reg csr_tlbelo1_v;
reg csr_tlbelo1_d;
reg [1:0] csr_tlbelo1_plv;
reg [1:0] csr_tlbelo1_mat;
reg csr_tlbelo1_g;
reg [19:0]csr_tlbelo1_ppn;

always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_v   <= 1'b0;
        csr_tlbelo1_d   <= 1'b0;
        csr_tlbelo1_plv <= 2'b0;
        csr_tlbelo1_mat <= 2'b0;
        csr_tlbelo1_g   <= 1'b0;
        csr_tlbelo1_ppn <= 20'b0;
    end
    else if(inst_tlbrd) begin
        if(r_e) begin
            csr_tlbelo1_v   <= r_v1;
            csr_tlbelo1_d   <= r_d1;
            csr_tlbelo1_plv <= r_plv1;
            csr_tlbelo1_mat <= r_mat1;
            csr_tlbelo1_g   <= r_g;
            csr_tlbelo1_ppn <= r_ppn1;
        end
        else begin
            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 20'b0;
        end
    end
    else if(csr_we && csr_wnum == `CSR_TLBELO1) begin
        csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo1_v; 
        csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo1_d;
        csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
        csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo1_g;    
    end
end

wire [31:0] csr_tlbelo1_rvalue = {4'b0, csr_tlbelo1_ppn,1'b0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};

//ASID,分为asid，0，asidbits,0等部分，共32位
reg [9:0] csr_asid_asid;
wire [7:0] csr_asid_asidbits = 8'd10;
always @(posedge clk ) begin
    if(reset)begin
        csr_asid_asid <= 10'b0;
    end
    else if(inst_tlbrd) begin
        if(r_e) csr_asid_asid <= r_asid;
        else csr_asid_asid <= 10'b0;
    end
//这一部分需要约定，该怎么传递
    else if(csr_we && csr_wnum == `CSR_ASID)begin
        csr_asid_asid  <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                       | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid; 
    end
end

assign csr_asid_rvalue = {8'b0,csr_asid_asidbits,6'b0,csr_asid_asid};
//PGDL，分为0，base两部分，共32位
reg [19:0]csr_pgdl_base;
always @(posedge clk) begin
    if (csr_we & csr_wnum == `CSR_PGDL) begin
        csr_pgdl_base <= csr_wmask[`CSR_PGDL_BASE]&csr_wvalue[`CSR_PGDL_BASE]
                      |~ csr_wmask[`CSR_PGDL_BASE]&csr_pgdl_base;
    end
end
wire [31:0]csr_pgdl_rvalue = {csr_pgdl_base,12'b0};

//PGDH，分为0，base两部分，共32位
reg [19:0]csr_pgdh_base;
always @(posedge clk ) begin
    if(csr_we && csr_wnum==`CSR_PGDH)begin
        csr_pgdh_base <=  csr_wmask[`CSR_PGDH_BASE]&csr_wvalue[`CSR_PGDH_BASE]
                      |~ csr_wmask[`CSR_PGDH_BASE]&csr_pgdl_base;
    end
end
wire [31:0]csr_pgdh_rvalue = {csr_pgdh_base,12'b0};

//PGD,分为0，base两部分，共32位
wire [19:0]csr_pgd_base;
assign csr_pgd_base = csr_badv_rvalue[31] ? csr_pgdh_base : csr_pgdl_base;
wire [31:0]csr_pgd_rvalue = {csr_pgd_base,12'b0};

//CPUID ,目前为单核
reg csr_cpuid_rvalue;
always @(posedge clk) begin
    if (reset) begin
        csr_cpuid_rvalue <= 32'b0;
    end 
end

//SAVE0~3寄存器，数据保存，只有data，共32位
reg [31:0]csr_save0_data;
reg [31:0]csr_save1_data;
reg [31:0]csr_save2_data;
reg [31:0]csr_save3_data;

always @(posedge clk) begin
    if (csr_we && csr_wnum==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]| ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_wnum==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]| ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_wnum==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]| ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_wnum==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]| ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
end
wire [31:0] csr_save0_rvalue = csr_save0_data;
wire [31:0] csr_save1_rvalue = csr_save1_data;
wire [31:0] csr_save2_rvalue = csr_save2_data;
wire [31:0] csr_save3_rvalue = csr_save3_data;
//TID,定时器编号，共32位
reg [31:0]csr_tid_tid;
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= coreid_in;
    else if (csr_we && csr_wnum==`CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]| ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end
wire [31:0]csr_tid_rvalue = csr_tid_tid;


//TCFG,定时器配置，包括En，Periodic，InitVal，0等部分，共32位
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_wnum==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]| ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    if (csr_we && csr_wnum==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]| ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]| ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
    end
end

assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

//TVAL寄存器,定时器数值，包括TimeVal，0等区域，共32位


assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]| ~csr_wmask[31:0]&{csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_wnum==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval_rvalue = timer_cnt[31:0];
//CNTC寄存器，修正值
reg [31:0] csr_cntc;
always @(posedge clk ) begin
    if(reset)begin
        csr_cntc <= 32'b0;
    end
    else if(csr_we && csr_wnum==`CSR_CNTC)
        csr_cntc <= csr_wmask & csr_wvalue | ~csr_wmask & csr_cntc;
end
wire [31:0] csr_cntc_rvalue = csr_cntc;
//TICLR寄存器，定时中断清除，包括CLR，0等部分，共32位
reg csr_ticlr_clr;
always @(posedge clk ) begin
    csr_ticlr_clr <= 1'b0;
end
wire csr_ticlr_rvalue = {31'b0,csr_ticlr_clr};


// 复位时初始化计数器和ID，计满后自动归零
reg [63:0] timer_64;
always @(posedge clk) begin
    if (reset) begin
        timer_64 <= 64'd0;
        counter_id <= 32'b0; // 可根据实际需求设置初始ID值
    end else begin
        // 检查是否达到最大值（2^64-1），若是则归零，否则继续计数
        counter_id <= csr_tid_tid;
        if (timer_64 == 64'hFFFFFFFFFFFFFFFF)
            timer_64 <= 64'd0;
        else
            timer_64 <= timer_64 + 1;
    end
end
assign stable_counter = timer_64 + {{32{csr_cntc[31]}}, csr_cntc};
assign rand_index = {{(5-`WIDTH_TLB_INDEX){1'b0}}, timer_64[`WIDTH_TLB_INDEX-1:0]};

//LLBCTL,
reg csr_llbctl_rollb;
reg csr_llbctl_wcllb;
reg csr_llbctl_klo;
always @(posedge clk) begin
    if (reset) begin
        csr_llbctl_klo     <= 1'b0;
		csr_llbctl_wcllb   <= 1'b0;
        csr_llbctl_rollb    <= 1'b0;
    end 
    else if (ertn_flush) begin
        if (csr_llbctl_klo) begin
            csr_llbctl_klo <= 1'b0;
        end
        else begin
            csr_llbctl_rollb <= 1'b0;
        end
    end
    else if (csr_wnum == `CSR_LLBCTL && csr_we) begin 
        csr_llbctl_klo <= csr_wmask[`CSR_LLBCTL_KLO] & csr_wvalue[`CSR_LLBCTL_KLO]
                       | ~csr_wmask[`CSR_LLBCTL_KLO] & csr_llbctl_klo;
        if (csr_wvalue[`CSR_LLBCTL_WCLLB] == 1'b1) begin
            csr_llbctl_rollb <= 1'b0;
        end
    end
    else if (llbit_set_in) begin
        csr_llbctl_rollb <= llbit_in;
    end
end
assign llbit_out = csr_llbctl_rollb;
wire [31:0] csr_llbctl_rvalue = {29'b0,csr_llbctl_klo,csr_llbctl_wcllb,csr_llbctl_rollb};

reg [27:0] lladdr;
always @(posedge clk) begin
    if (reset) begin
        lladdr <= 28'b0;
    end
    else if (lladdr_set_in) begin
        lladdr <= lladdr_in;
    end
end
assign lladdr_out = lladdr;
//TLBRENTRY,分为0，pa两部分，共32位
reg [25:0] csr_tlbrentry_pa;
always @(posedge clk ) begin
    if(csr_we && csr_wnum == `CSR_TLBRENTRY)
        csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA]&csr_wvalue[`CSR_TLBRENTRY_PA]
                         |~ csr_wmask[`CSR_TLBRENTRY_PA]&csr_tlbrentry_pa;
end
assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa,6'b0};

//CPU指令
reg [31:0] csr_cpucfg1;
reg [31:0] csr_cpucfg2;
reg [31:0] csr_cpucfg10;
reg [31:0] csr_cpucfg11;
reg [31:0] csr_cpucfg12;
reg [31:0] csr_cpucfg13;
//cpucfg1
always @(posedge clk) begin
    if (reset) begin
        csr_cpucfg1 <= 32'h1f1f4;
    end 
end

//cpucfg2
always @(posedge clk) begin
    if (reset) begin
        csr_cpucfg2 <= 32'h0;
    end 
end

//cpucfg10
always @(posedge clk) begin
    if (reset) begin
        csr_cpucfg10 <= 32'h5;
    end 
end

//cpucfg11
always @(posedge clk) begin
    if (reset) begin
        csr_cpucfg11 <= 32'h04080001;
    end 
end

//cpucfg12
always @(posedge clk) begin
    if (reset) begin
        csr_cpucfg12 <= 32'h04080001;
    end 
end

//cpucfg13
always @(posedge clk) begin
    if (reset) begin
        csr_cpucfg13 <= 32'h0;
    end 
end
//disable cache
reg [31:0] csr_disable_cache;
always @(posedge clk ) begin
    if(reset)begin
        csr_disable_cache <= 32'h0;
    end
    else if(csr_we && csr_wnum == `CSR_DISABLE_CACHE) begin
        csr_disable_cache <= csr_wvalue ;
    end
end
assign disable_cache_out = csr_disable_cache[0];

//DMW0,分为PLV0，0，PLV3，MAT，0，PSEG,0,VSEG等部分，共32位
reg csr_dmw0_plv0;
reg csr_dmw0_plv3;
reg [1:0]csr_dmw0_mat;
reg [2:0]csr_dmw0_pseg;
reg [2:0]csr_dmw0_vseg;

always @ (posedge clk) begin
    if (reset) begin
        csr_dmw0_vseg <= 3'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_plv0 <= 1'b0;
    end
    else if (csr_we & csr_wnum == `CSR_DMW0) begin
        csr_dmw0_vseg <= csr_wmask[`CSR_DMW0_VSEG] & csr_wvalue[`CSR_DMW0_VSEG]
                      | ~csr_wmask[`CSR_DMW0_VSEG] & csr_dmw0_vseg;
        csr_dmw0_pseg <= csr_wmask[`CSR_DMW0_PSEG] & csr_wvalue[`CSR_DMW0_PSEG]
                      | ~csr_wmask[`CSR_DMW0_PSEG] & csr_dmw0_pseg;
        csr_dmw0_mat  <= csr_wmask[`CSR_DMW0_MAT]  & csr_wvalue[`CSR_DMW0_MAT]
                      | ~csr_wmask[`CSR_DMW0_MAT]  & csr_dmw0_mat;
        csr_dmw0_plv3 <= csr_wmask[`CSR_DMW0_PLV3] & csr_wvalue[`CSR_DMW0_PLV3]
                      | ~csr_wmask[`CSR_DMW0_PLV3] & csr_dmw0_plv3;
        csr_dmw0_plv0 <= csr_wmask[`CSR_DMW0_PLV0] & csr_wvalue[`CSR_DMW0_PLV0]
                      | ~csr_wmask[`CSR_DMW0_PLV0] & csr_dmw0_plv0;
    end
end

assign csr_dmw0_rvalue = {csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0};

//DMW1
reg csr_dmw1_plv0;
reg csr_dmw1_plv3;
reg [1:0]csr_dmw1_mat;
reg [2:0]csr_dmw1_pseg;
reg [2:0]csr_dmw1_vseg;


always @ (posedge clk) begin
    if (reset) begin
        csr_dmw1_vseg <= 3'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_plv0 <= 1'b0;
    end
    else if (csr_we & csr_wnum == `CSR_DMW1) begin
        csr_dmw1_vseg <= csr_wmask[`CSR_DMW1_VSEG] & csr_wvalue[`CSR_DMW1_VSEG]
                      | ~csr_wmask[`CSR_DMW1_VSEG] & csr_dmw1_vseg;
        csr_dmw1_pseg <= csr_wmask[`CSR_DMW1_PSEG] & csr_wvalue[`CSR_DMW1_PSEG]
                      | ~csr_wmask[`CSR_DMW1_PSEG] & csr_dmw1_pseg;
        csr_dmw1_mat  <= csr_wmask[`CSR_DMW1_MAT]  & csr_wvalue[`CSR_DMW1_MAT]
                      | ~csr_wmask[`CSR_DMW1_MAT]  & csr_dmw1_mat;
        csr_dmw1_plv3 <= csr_wmask[`CSR_DMW1_PLV3] & csr_wvalue[`CSR_DMW1_PLV3]
                      | ~csr_wmask[`CSR_DMW1_PLV3] & csr_dmw1_plv3;
        csr_dmw1_plv0 <= csr_wmask[`CSR_DMW1_PLV0] & csr_wvalue[`CSR_DMW1_PLV0]
                      | ~csr_wmask[`CSR_DMW1_PLV0] & csr_dmw1_plv0;
    end
end

assign csr_dmw1_rvalue = {csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0};
assign we      = inst_tlbwr | inst_tlbfill;
assign w_index = {`WIDTH_TLB_INDEX{inst_tlbfill}} & timer_64[`WIDTH_TLB_INDEX-1:0]      |
                 {`WIDTH_TLB_INDEX{inst_tlbwr  }} & csr_tlbidx_index[`WIDTH_TLB_INDEX-1:0];
assign w_e     = csr_estat_ecode == 6'h3f ? 1'b1         : ~csr_tlbidx_ne;
assign w_vppn  = csr_tlbehi_vppn;
assign w_ps    = csr_tlbidx_ps;
assign w_asid  = csr_asid_asid;
assign w_g     = csr_tlbelo0_g && csr_tlbelo1_g;
assign w_ppn0  = csr_tlbelo0_ppn;
assign w_plv0  = csr_tlbelo0_plv;
assign w_mat0  = csr_tlbelo0_mat;
assign w_d0    = csr_tlbelo0_d;
assign w_v0    = csr_tlbelo0_v;
assign w_ppn1  = csr_tlbelo1_ppn;
assign w_plv1  = csr_tlbelo1_plv;
assign w_mat1  = csr_tlbelo1_mat;
assign w_d1    = csr_tlbelo1_d;
assign w_v1    = csr_tlbelo1_v;
assign r_index = csr_tlbidx_index[`WIDTH_TLB_INDEX-1:0];

assign csr_tlb_out   = {we,     //98
                        w_index,//97:93
                        w_e,    //92
                        w_vppn, //91:73
                        w_ps,   //72:67
                        w_asid, //66:57
                        w_g,    //56
                        w_ppn0, //55:36
                        w_plv0, //35:34
                        w_mat0, //33:32
                        w_d0,   //31
                        w_v0,   //30
                        w_ppn1, //29:10
                        w_plv1, //9:8
                        w_mat1, //7:6
                        w_d1,   //5
                        w_v1,   //4
                        r_index //3:0
                       };

assign csr_rvalue1 = {32{csr_rnum1==`CSR_CRMD}} & csr_crmd_rvalue
                    | {32{csr_rnum1==`CSR_PRMD}} & csr_prmd_rvalue
                    | {32{csr_rnum1==`CSR_ECFG}} & csr_ecfg_rvalue
                    | {32{csr_rnum1==`CSR_ESTAT}} & csr_estat_rvalue
                    | {32{csr_rnum1==`CSR_ERA}} & csr_era_rvalue
                    | {32{csr_rnum1==`CSR_BADV}} & csr_badv_rvalue
                    | {32{csr_rnum1==`CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_rnum1==`CSR_SAVE0}} & csr_save0_rvalue
                    | {32{csr_rnum1==`CSR_SAVE1}} & csr_save1_rvalue
                    | {32{csr_rnum1==`CSR_SAVE2}} & csr_save2_rvalue
                    | {32{csr_rnum1==`CSR_SAVE3}} & csr_save3_rvalue
                    | {32{csr_rnum1==`CSR_TID}} & csr_tid_rvalue
                    | {32{csr_rnum1==`CSR_TCFG}} & csr_tcfg_rvalue
                    | {32{csr_rnum1==`CSR_TVAL}} & csr_tval_rvalue
                    | {32{csr_rnum1==`CSR_CNTC}} & csr_cntc_rvalue
                    | {32{csr_rnum1==`CSR_TICLR}} & csr_ticlr_rvalue
                    | {32{csr_rnum1==`CSR_TLBIDX}} & csr_tlbidx_rvalue
                    | {32{csr_rnum1==`CSR_TLBEHI}} & csr_tlbehi_rvalue
                    | {32{csr_rnum1==`CSR_TLBELO0}} & csr_tlbelo0_rvalue
                    | {32{csr_rnum1==`CSR_TLBELO1}} & csr_tlbelo1_rvalue
                    | {32{csr_rnum1==`CSR_ASID}} & csr_asid_rvalue
                    | {32{csr_rnum1==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                    | {32{csr_rnum1==`CSR_DMW0}} & csr_dmw0_rvalue
                    | {32{csr_rnum1==`CSR_DMW1}} & csr_dmw1_rvalue
                    | {32{csr_rnum1==`CSR_LLBCTL}}& csr_llbctl_rvalue
                    | {32{csr_rnum1==`CSR_PGD}}& csr_pgd_rvalue
                    | {32{csr_rnum1==`CSR_PGDL}}& csr_pgdl_rvalue
                    | {32{csr_rnum1==`CSR_PGDH}}& csr_pgdh_rvalue
                    | {32{csr_rnum1==`CSR_CPUID}}& csr_cpuid_rvalue
                    | {32{csr_rnum1==`CSR_CPUCFG1}}& csr_cpucfg1
                    | {32{csr_rnum1==`CSR_CPUCFG2}}& csr_cpucfg2
                    | {32{csr_rnum1==`CSR_CPUCFG10}}& csr_cpucfg10
                    | {32{csr_rnum1==`CSR_CPUCFG11}}& csr_cpucfg11
                    | {32{csr_rnum1==`CSR_CPUCFG12}}& csr_cpucfg12
                    | {32{csr_rnum1==`CSR_CPUCFG13}}& csr_cpucfg13;

assign csr_rvalue2 = {32{csr_rnum2==`CSR_CRMD}} & csr_crmd_rvalue
                    | {32{csr_rnum2==`CSR_PRMD}} & csr_prmd_rvalue 
                    | {32{csr_rnum2==`CSR_ECFG}} & csr_ecfg_rvalue
                    | {32{csr_rnum2==`CSR_ESTAT}} & csr_estat_rvalue
                    | {32{csr_rnum2==`CSR_ERA}} & csr_era_rvalue
                    | {32{csr_rnum2==`CSR_BADV}} & csr_badv_rvalue
                    | {32{csr_rnum2==`CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_rnum2==`CSR_SAVE0}} & csr_save0_rvalue
                    | {32{csr_rnum2==`CSR_SAVE1}} & csr_save1_rvalue
                    | {32{csr_rnum2==`CSR_SAVE2}} & csr_save2_rvalue
                    | {32{csr_rnum2==`CSR_SAVE3}} & csr_save3_rvalue
                    | {32{csr_rnum2==`CSR_TID}} & csr_tid_rvalue
                    | {32{csr_rnum2==`CSR_TCFG}} & csr_tcfg_rvalue
                    | {32{csr_rnum2==`CSR_TVAL}} & csr_tval_rvalue
                    | {32{csr_rnum2==`CSR_CNTC}} & csr_cntc
                    | {32{csr_rnum2==`CSR_TICLR}} & csr_ticlr_rvalue
                    | {32{csr_rnum2==`CSR_TLBIDX}} & csr_tlbidx_rvalue
                    | {32{csr_rnum2==`CSR_TLBEHI}} & csr_tlbehi_rvalue
                    | {32{csr_rnum2==`CSR_TLBELO0}} & csr_tlbelo0_rvalue
                    | {32{csr_rnum2==`CSR_TLBELO1}} & csr_tlbelo1_rvalue
                    | {32{csr_rnum2==`CSR_ASID}} & csr_asid_rvalue
                    | {32{csr_rnum2==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                    | {32{csr_rnum2==`CSR_DMW0}} & csr_dmw0_rvalue
                    | {32{csr_rnum2==`CSR_DMW1}} & csr_dmw1_rvalue
                    | {32{csr_rnum2==`CSR_LLBCTL}}& csr_llbctl_rvalue
                    | {32{csr_rnum2==`CSR_PGD}}& csr_pgd_rvalue
                    | {32{csr_rnum2==`CSR_PGDL}}& csr_pgdl_rvalue
                    | {32{csr_rnum2==`CSR_PGDH}}& csr_pgdh_rvalue
                    | {32{csr_rnum2==`CSR_CPUID}}& csr_cpuid_rvalue
                    | {32{csr_rnum2==`CSR_CPUCFG1}}& csr_cpucfg1
                    | {32{csr_rnum2==`CSR_CPUCFG2}}& csr_cpucfg2
                    | {32{csr_rnum2==`CSR_CPUCFG10}}& csr_cpucfg10
                    | {32{csr_rnum2==`CSR_CPUCFG11}}& csr_cpucfg11
                    | {32{csr_rnum2==`CSR_CPUCFG12}}& csr_cpucfg12
                    | {32{csr_rnum2==`CSR_CPUCFG13}}& csr_cpucfg13;
                    

`ifdef DIFFTEST_EN
assign csr_crmd_diff        = csr_crmd_rvalue;
assign csr_prmd_diff        = csr_prmd_rvalue;
assign csr_ecfg_diff        = csr_ecfg_rvalue;
assign csr_estat_diff       = csr_estat_rvalue;
assign csr_era_diff         = csr_era_rvalue;
assign csr_badv_diff        = csr_badv_rvalue;
assign csr_eentry_diff      = csr_eentry_rvalue;
assign csr_tlbidx_diff      = csr_tlbidx_rvalue;
assign csr_tlbehi_diff      = csr_tlbehi_rvalue;
assign csr_tlbelo0_diff     = csr_tlbelo0_rvalue;
assign csr_tlbelo1_diff     = csr_tlbelo1_rvalue;
assign csr_asid_diff        = csr_asid_rvalue;
assign csr_save0_diff       = csr_save0_rvalue;
assign csr_save1_diff       = csr_save1_rvalue;
assign csr_save2_diff       = csr_save2_rvalue;
assign csr_save3_diff       = csr_save3_rvalue;
assign csr_tid_diff         = csr_tid_rvalue;
assign csr_tcfg_diff        = csr_tcfg_rvalue;
assign csr_tval_diff        = csr_tval_rvalue;
assign csr_ticlr_diff       = csr_ticlr_rvalue;
assign csr_llbctl_diff      = csr_llbctl_rvalue;
assign csr_tlbrentry_diff   = csr_tlbrentry_rvalue;
assign csr_dmw0_diff        = csr_dmw0_rvalue;
assign csr_dmw1_diff        = csr_dmw1_rvalue;
assign csr_pgdl_diff        = csr_pgdl_rvalue;
assign csr_pgdh_diff        = csr_pgdh_rvalue;
`endif
endmodule