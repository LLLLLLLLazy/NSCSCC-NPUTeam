`include "mycpu.h"

module MMU(
    input wire  [1:0]                 flag,//10:inst;01:data
    input wire is_store,
    input wire  [31:0]                csr_crmd_rvalue,
    input wire  [31:0]                csr_asid_rvalue,
    input wire  [31:0]                csr_dmw0_rvalue,
    input wire  [31:0]                csr_dmw1_rvalue,

    // from tlb
    input  wire                       s_found,
    input  wire [ 4:0]                s_index,
    input  wire [19:0]                s_ppn,
    input  wire [ 5:0]                s_ps,
    input  wire [ 1:0]                s_plv,
    input  wire [ 1:0]                s_mat,
    input  wire                       s_d,
    input  wire                       s_v,

    //interface
    input  wire [31:0]               va,
    output wire [ 5:0]               exc_ecode,
    output wire                      dmw_hit,
    output wire [ 1:0]               plv,//10:adef,01:adem
    output wire [31:0]               pa,
    output wire                      untlb_en,
    output wire                      uncache_en,
    input wire                       disable_cache

);

wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [1:0]  csr_crmd_plv;
wire [1:0]  csr_crmd_datf;
wire [1:0]  csr_crmd_datm;
wire [9:0]  csr_asid_asid;

assign csr_crmd_da   = csr_crmd_rvalue[`CSR_CRMD_DA  ]; // ֱ�ӵ�ַ����ģʽ��ʹ�ܣ�����Ч
assign csr_crmd_pg   = csr_crmd_rvalue[`CSR_CRMD_PG  ]; // ӳ���ַ����ģʽ��ʹ�ܣ������?
assign csr_crmd_plv  = csr_crmd_rvalue[`CSR_CRMD_PLV ]; //��ǰ��Ȩ�ȼ�����Χλ0-3
assign csr_crmd_datf = csr_crmd_rvalue[`CSR_CRMD_DATF ];
assign csr_crmd_datm = csr_crmd_rvalue[`CSR_CRMD_DATM ];
assign csr_asid_asid = csr_asid_rvalue[`CSR_ASID_ASID]; //��ǰִ�еĳ�������Ӧ�ĵ�ַ�ռ��ʶ��??

wire        direct;
wire        dmw_hit0  ;
wire        dmw_hit1  ;
wire [31:0] dmw_paddr0;
wire [31:0] dmw_paddr1;
wire [31:0] tlb_paddr ;
wire        tlb_trans;
wire        ecode_pil ;
wire        ecode_pis ;
wire        ecode_pif ;
wire        ecode_pme ;
wire        ecode_ppi ;
wire        ecode_tlbr;
wire [1:0]  mat_result;
wire [1:0]  direct_uncache_value;

/**
��DA = 1��PG = 0ʱ������ֱ�ӵ�ַ����ģʽ
������ַĬ��ֱ�ӵ��������ַ��[PALEN-1:0]λ�����㲹0��
*/
assign direct = csr_crmd_da & ~csr_crmd_pg;

/**
ӳ���ַ����ģʽ��Ϊֱ��ӳ���ַ����ģʽ��ҳ��ӳ���ַ����ģ�?

ֱ��ӳ���ַ����ģ�?

���ַ�Ƿ�����ֱ��ӳ�����ô��ڣ�??
���ַ�����λ�����ô��ڼĴ����������λ����ҵ�ǰ��Ȩ�ȼ��ڸ����ô��ڱ�����

���к�������ַ�������ַ�ĺ�??29λƴ���ϸ�ӳ�䴰�������õ�������ַ��λ����PSEG��
*/
assign dmw_hit0 = csr_dmw0_rvalue[csr_crmd_plv] && (csr_dmw0_rvalue[31:29] == va[31:29]);
assign dmw_hit1 = csr_dmw1_rvalue[csr_crmd_plv] && (csr_dmw1_rvalue[31:29] == va[31:29]);
assign dmw_paddr0 = {csr_dmw0_rvalue[`CSR_DMW_PSEG], va[28:0]};
assign dmw_paddr1 = {csr_dmw1_rvalue[`CSR_DMW_PSEG], va[28:0]};
/**
ҳ��ӳ���ַ����ģ�?
�������ֱ�ӵ�ַ����ģʽ��ֱ��ӳ���ַ����ģʽ
*/
assign tlb_trans = ~dmw_hit0 & ~dmw_hit1 & ~direct;
assign tlb_paddr = (s_ps == 6'd12) ? {s_ppn[19:0], va[11:0]} : {s_ppn[19:10], va[21:0]};

/**
TLB�������??
����pme�����ж�v = 1����Ȩ�ȼ��Ƿ�Ϲ棬��Ϊ��Щ���������Ⱥ�˳���
*/

assign ecode_pif  = flag[1] & tlb_trans & s_found & ~s_v;
assign ecode_ppi  = tlb_trans & s_found & s_v & (csr_crmd_plv > s_plv);
assign ecode_tlbr = tlb_trans & ~s_found;
assign ecode_pil  = flag[0] & tlb_trans & s_found & ~s_v;
assign ecode_pis  = flag[0] & tlb_trans & s_found & ~s_v;
assign ecode_pme  = flag[0] & tlb_trans & s_found & s_v &
                    (csr_crmd_plv <= s_plv) & ~s_d;



//TODO:if it is direct ,it should also consider the error inst!
assign exc_ecode = direct ? 6'b0 : {ecode_pil, ecode_pis, ecode_pif, ecode_pme, ecode_ppi, ecode_tlbr};

//paddr
assign pa = ({32{direct}} & va) | 
            ({32{~direct & dmw_hit0}} & dmw_paddr0) | 
            ({32{~direct & ~dmw_hit0 & dmw_hit1}} & dmw_paddr1) | 
            ({32{~direct & ~dmw_hit0 & ~dmw_hit1}} & tlb_paddr);
                  
assign dmw_hit = dmw_hit0 | dmw_hit1;
assign plv     = csr_crmd_plv;
assign direct_uncache_value = flag[1] ? csr_crmd_datf : csr_crmd_datm;
assign mat_result = direct ? direct_uncache_value :(dmw_hit0 ? csr_dmw0_rvalue[`CSR_DMW_MAT] :
                                                    dmw_hit1 ? csr_dmw1_rvalue[`CSR_DMW_MAT] :
                                                    s_mat);
assign uncache_en = (mat_result == 2'b00) | disable_cache;
assign untlb_en = ~tlb_trans;
endmodule
