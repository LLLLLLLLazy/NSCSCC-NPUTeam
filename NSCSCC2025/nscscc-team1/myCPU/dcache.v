module dcache (
    input wire clk,
    input wire resetn,
    input wire data_sram_req,     //  ��ǰ�Ƿ��зô������źţ�0��ʾû�У�1��ʾ��

    input wire [31:0] data_sram_addr,        //  ����?
    input wire [31:0] data_addr,             //  ʵ��ַ
    
    output wire  addr_ok,  //  cache ���յ���ַ����
    output wire data_ok,   //  cache ��������ݴ���?
    output wire [31:0] rdata,  //  �� cache ����������

    // belows are related to AXI
    output reg axi_data_sram_req,      //  �����߷����������ź� 
    output wire [31:0] axi_data_sram_addr,    // �����߷����Ķ�����ĵ��?
    input wire ret_valid,           //���߷��ص�������Ч�ź�
    input wire ret_last,
    input wire [31:0] ret_data ,    //���߷��ص�data����
    input wire axi_data_sram_addr_ok ,        //���ߵ�ַ���ֳɹ� 
    input wire data_uncache  ,
    input wire op ,                   // 0��ʾ�Ƕ� , 1��ʾ��д
    input wire [31:0] data_sram_wdata,
    input wire [3:0]data_sram_wstrb,
    input wire axi_data_sram_data_ok,
    output wire axi_data_sram_wr,
    input wire [1:0] data_sram_size,
    output wire [1:0] axi_data_sram_size,
    output wire [31:0] axi_data_sram_wdata,
    output wire [3:0] axi_data_sram_wstrb,

    input wire wb_cacop_en,
    input wire cacop_way0_tag_we,
    input wire cacop_way1_tag_we,
    input wire cacop_way0_v_we,
    input wire cacop_way1_v_we,
    input wire [7:0] data_cacop_waddr,

    output wire [7:0]axi_data_sram_len

);

    wire rst;
    assign rst = ~resetn;

    wire valid;      // cache��Ч�ź�
    assign valid = data_sram_req && rst_busy == 1'b0  ;

    wire [7:0] index;
    wire [19:0] tag;
    wire [3:0]offset;
    assign index = data_sram_addr [11:4] ;
    assign tag = data_addr [31:12] ;
    assign offset = data_sram_addr [3:0] ;

    wire [7:0] arlen ;

    reg req_buffer_op;
    reg [7:0] req_buffer_index;
    reg [19:0] req_buffer_tag;
    reg [3:0] req_buffer_offset;
    reg miss_buffer_op;
    reg [31:0] req_data_addr;
    reg [7:0] miss_buffer_index;
    reg [19:0] miss_buffer_tag;
    reg [3:0] miss_buffer_offset;
    reg [31:0] miss_data_addr;
    reg miss_buffer_uncache ;

    reg [31:0] req_buffer_wdata;
    reg [3:0] req_buffer_wstrb;
    reg [31:0] miss_buffer_wdata;
    reg [3:0] miss_buffer_wstrb;
    reg [1:0] req_buffer_size;
    reg [1:0] miss_buffer_size;
    reg req_buffer_uncache;

   

    reg [255:0] way0_d;
    reg [255:0] way1_d;
    
        reg rand_way;
    always @(posedge clk)
    begin
    if(rst)
    begin
        rand_way <= 1'b0;
    end
    else
    begin
        rand_way <=  ~rand_way;
    end
    end




//��״̬���Ŀ���
    localparam IDLE = 2'h0;
    localparam LOOKUP = 2'h1;
    localparam MISS = 2'h2;
    localparam REFILL = 2'h3;
   
    reg [1:0] main_state_cur;

    reg replace_way;

    always @(posedge clk)
    begin
        if(rst)
        begin
            main_state_cur <= IDLE ;
            req_buffer_op     <= 1'b0;
            req_buffer_index  <= 8'b0;
            req_buffer_tag    <= 20'b0;
            req_buffer_offset <= 4'b0;
            replace_way    <= 1'b0 ;
            req_data_addr <= 32'b0;
            req_buffer_size <= 2'b0;
            axi_data_sram_req <= 1'b0 ;
            req_buffer_uncache <= 1'b0 ;
            
        end
        else
        begin
            case (main_state_cur)
                IDLE:
                begin
                    if( valid )    //��cache���Ͷ�����
                    begin
                        main_state_cur <= LOOKUP ;
                        req_buffer_op <= op;
                        req_buffer_index <= index;
                        req_buffer_offset <= offset;
                        req_buffer_tag <= tag;
                        req_data_addr <= data_addr ;
                        req_buffer_size <= data_sram_size ;
                        req_buffer_wdata <= data_sram_wdata;
                        req_buffer_wstrb <= data_sram_wstrb ;
                        req_buffer_uncache <= data_uncache ;
                    end
                end 
                LOOKUP:
                begin
                    if(cache_hit && valid && req_buffer_op == 1'b0 )
                    begin
                        main_state_cur <= LOOKUP ;
                        req_buffer_op <= op;
                        req_buffer_index <= index;
                        req_buffer_offset <= offset;
                        req_buffer_tag <= tag;
                        req_data_addr <= data_addr ;
                        req_buffer_size <= data_sram_size ;
                        req_buffer_wdata <= data_sram_wdata;
                        req_buffer_wstrb <= data_sram_wstrb ;
                        req_buffer_uncache <= data_uncache ;
                    end
                    else if(~cache_hit || req_buffer_op)
                    begin
                        main_state_cur <= MISS ;
                        replace_way <= rand_way; 
                        miss_buffer_op <= req_buffer_op;
                        miss_buffer_index <= req_buffer_index;
                        miss_buffer_offset <= req_buffer_offset;
                        miss_buffer_tag <= req_buffer_tag;
                        axi_data_sram_req  <= 1'b1;
                        miss_data_addr <= req_data_addr ;
                        miss_buffer_size <= req_buffer_size ;
                        miss_buffer_wdata <= req_buffer_wdata ;
                        miss_buffer_wstrb <= req_buffer_wstrb ;
                        miss_buffer_uncache <= req_buffer_uncache ;
                    end
                    else 
                    begin
                        main_state_cur <= IDLE ;
                    end
                end
                MISS:
                begin
                    if(axi_data_sram_addr_ok==1'b1)
                    begin
                        main_state_cur <= REFILL ;
                        axi_data_sram_req <= 1'b0 ;
                    end
                    else          
                    begin
                        main_state_cur <= MISS ;
                    end
                end
                REFILL:
                begin
                    if((ret_valid == 1'b1 && ret_last == 1'b1 && miss_buffer_op == 1'b0) || (miss_buffer_op && axi_data_sram_data_ok))
                    begin
                        main_state_cur <= IDLE ;
                    end
                    else 
                    begin
                        main_state_cur <= REFILL ;
                    end
                end
            endcase
        end
    end

    reg [2:0] write_counter;
    always @(posedge clk)
    begin
        if(rst | (ret_last && ret_valid))
        begin
            write_counter <= 3'b0;
        end
        else if(ret_valid && main_state_cur == REFILL)
        begin
            write_counter  <= write_counter + 1'b1 ;
        end
    end



    wire way0_hit;    //  ��0·����
    wire way1_hit;    //  ��1·����
    wire cache_hit;   //   cache ����������

    assign way0_hit = way0_r_v && (way0_r_tag == req_buffer_tag);
    assign way1_hit = way1_r_v && (way1_r_tag == req_buffer_tag);
    assign cache_hit =  (way0_hit || way1_hit) && req_buffer_uncache == 1'b0 ;



//  �洢���ݵ�cache����,��Ҫ����ip
    wire  way0_r_v;
    wire  way1_r_v;
    wire [19:0]way0_r_tag;
    wire [19:0]way1_r_tag;
    wire way0_r_d;
    wire way1_r_d;
    wire [31:0] way0_r_bank0;
    wire [31:0] way0_r_bank1;
    wire [31:0] way0_r_bank2;
    wire [31:0] way0_r_bank3;
    wire [31:0] way1_r_bank0;
    wire [31:0] way1_r_bank1;
    wire [31:0] way1_r_bank2;
    wire [31:0] way1_r_bank3;
    wire [3:0]way0_bank0_we;
    wire [3:0]way0_bank1_we;
    wire [3:0]way0_bank2_we;
    wire [3:0]way0_bank3_we;
    wire [3:0]way1_bank0_we;
    wire [3:0]way1_bank1_we;
    wire [3:0]way1_bank2_we;
    wire [3:0]way1_bank3_we;
    wire way0_tag_we;
    wire way1_tag_we;
    wire way0_v_we;
    wire way1_v_we;
    wire [7:0] way0_bank0_addr;
    wire [7:0] way0_bank1_addr;
    wire [7:0] way0_bank2_addr;
    wire [7:0] way0_bank3_addr;
    wire [7:0] way1_bank0_addr;
    wire [7:0] way1_bank1_addr;
    wire [7:0] way1_bank2_addr;
    wire [7:0] way1_bank3_addr;
    wire [7:0] way0_tag_addr;
    wire [7:0] way1_tag_addr;
    wire [7:0] way0_v_addr;
    wire [7:0] way1_v_addr;
    wire [31:0] way0_bank0_wdata;
    wire [31:0] way0_bank1_wdata;
    wire [31:0] way0_bank2_wdata;
    wire [31:0] way0_bank3_wdata;
    wire [31:0] way1_bank0_wdata;
    wire [31:0] way1_bank1_wdata;
    wire [31:0] way1_bank2_wdata;
    wire [31:0] way1_bank3_wdata;
    wire [19:0] way0_tag_wdata;
    wire [19:0] way1_tag_wdata;
    wire  way0_v_wdata;
    wire  way1_v_wdata;
    wire way0_d_we;
    wire way1_d_we;
    wire way0_d_wdata;
    wire way1_d_wdata;

    wire way0_bank0_rsta_busy ;
    wire way0_bank1_rsta_busy ;
    wire way0_bank2_rsta_busy ;
    wire way0_bank3_rsta_busy ;
    wire way1_bank0_rsta_busy ;
    wire way1_bank1_rsta_busy ;
    wire way1_bank2_rsta_busy ;
    wire way1_bank3_rsta_busy ;
    wire way0_tag_rsta_busy;
    wire way1_tag_rsta_busy;
    wire way0_v_rsta_busy;
    wire way1_v_rsta_busy;

    wire rst_busy;

    assign rst_busy = way0_bank0_rsta_busy |
                  way0_bank1_rsta_busy |
                  way0_bank2_rsta_busy |
                  way0_bank3_rsta_busy |
                  way1_bank0_rsta_busy |
                  way1_bank1_rsta_busy |
                  way1_bank2_rsta_busy |
                  way1_bank3_rsta_busy |
                  way0_tag_rsta_busy   |
                  way1_tag_rsta_busy   |
                  way0_v_rsta_busy     |
                  way1_v_rsta_busy;


    assign way0_bank0_we =  ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b0 && write_counter == 3'h0 && miss_buffer_op == 1'b0 )     ?  4'b1111 :                      //������δ����                                                                                                                                                                        //д����������
                            (!req_buffer_uncache && main_state_cur == LOOKUP && way0_hit && req_buffer_offset[3:2] == 2'b00 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way0_bank1_we =  ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b0 && write_counter == 3'h1 && miss_buffer_op == 1'b0)     ?  4'b1111 :                   //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way0_hit && req_buffer_offset[3:2] == 2'b01 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way0_bank2_we =  (!miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b0 && write_counter == 3'h2 && miss_buffer_op == 1'b0)     ?  4'b1111 :                    //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way0_hit && req_buffer_offset[3:2] == 2'b10 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way0_bank3_we = ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b0 && write_counter == 3'h3 && miss_buffer_op == 1'b0)     ?  4'b1111 :                //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way0_hit && req_buffer_offset[3:2] == 2'b11 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way1_bank0_we = ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b1 && write_counter == 3'h0 && miss_buffer_op == 1'b0)     ?  4'b1111 :                   //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way1_hit && req_buffer_offset[3:2] == 2'b00 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way1_bank1_we = ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b1 && write_counter == 3'h1 && miss_buffer_op == 1'b0)     ?  4'b1111 :                  //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way1_hit && req_buffer_offset[3:2] == 2'b01 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way1_bank2_we = ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b1 && write_counter == 3'h2 && miss_buffer_op == 1'b0)     ?  4'b1111 :                     //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way1_hit && req_buffer_offset[3:2] == 2'b10 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;

    assign way1_bank3_we = ( !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b1 && write_counter == 3'h3 && miss_buffer_op == 1'b0)     ?  4'b1111 :                   //������δ����
                             (!req_buffer_uncache && main_state_cur == LOOKUP && way1_hit && req_buffer_offset[3:2] == 2'b11 && req_buffer_op)                              ?  req_buffer_wstrb : 4'b0 ;


    assign way0_d_we = 1'b0 ;
    assign way1_d_we = 1'b0 ;

    assign way0_tag_we =  wb_cacop_en ? cacop_way0_tag_we :  !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b0 && miss_buffer_op == 1'b0 ;
    assign way1_tag_we =  wb_cacop_en ? cacop_way1_tag_we : !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b1 && miss_buffer_op == 1'b0;
    assign way0_v_we =  wb_cacop_en ? cacop_way0_v_we :     !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b0 && miss_buffer_op == 1'b0 ;
    assign way1_v_we =  wb_cacop_en ? cacop_way1_v_we :     !miss_buffer_uncache && ret_valid && main_state_cur == REFILL && replace_way == 1'b1 && miss_buffer_op == 1'b0;



    assign way0_bank0_addr =    (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way0_bank0_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way0_bank1_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way0_bank1_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way0_bank2_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way0_bank2_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way0_bank3_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way0_bank3_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way1_bank0_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way1_bank0_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way1_bank1_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way1_bank1_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way1_bank2_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way1_bank2_we != 4'b0 ? miss_buffer_index  :  index ;
    assign way1_bank3_addr = (main_state_cur == LOOKUP && req_buffer_op)  ?   req_buffer_index :
                                                    way1_bank3_we != 4'b0 ? miss_buffer_index  :  index ;

    assign way0_tag_addr =  wb_cacop_en ?   data_cacop_waddr :
                            ( main_state_cur == REFILL && replace_way == 1'b0)          ?  miss_buffer_index : index ;                      //������δ����
    assign way1_tag_addr =  wb_cacop_en ?   data_cacop_waddr :
                            ( main_state_cur == REFILL && replace_way == 1'b1)          ?  miss_buffer_index : index ;                      //������δ����
    assign way0_v_addr =  wb_cacop_en ?   data_cacop_waddr :
                            ( main_state_cur == REFILL && replace_way == 1'b0)          ?  miss_buffer_index : index ;                      //������δ����
    assign way1_v_addr =  wb_cacop_en ?   data_cacop_waddr :
                            ( main_state_cur == REFILL && replace_way == 1'b1)          ?  miss_buffer_index : index ;                      //������δ����    


    assign way0_bank0_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way0_bank1_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way0_bank2_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way0_bank3_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way1_bank0_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way1_bank1_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way1_bank2_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way1_bank3_wdata = main_state_cur == LOOKUP ?  req_buffer_wdata : ret_data;
    assign way0_d_wdata    = 1'b1;
    assign way1_d_wdata    = 1'b1;
    assign way0_tag_wdata = wb_cacop_en ? 20'b0 : miss_buffer_tag  ;                    //������δ����
    assign way1_tag_wdata = wb_cacop_en ? 20'b0 : miss_buffer_tag  ;                    //������δ����
    assign way0_v_wdata = !wb_cacop_en ;                  
    assign way1_v_wdata = !wb_cacop_en ;     



        // WAY0
    BANK_WAY bank0_way0 (
        .clka(clk),    
        .wea(way0_bank0_we),      
        .addra(way0_bank0_addr),  
        .dina(way0_bank0_wdata),    
        .douta(way0_r_bank0),
        .rsta(rst),
        .rsta_busy(way0_bank0_rsta_busy)
    );

    BANK_WAY bank1_way0 (
        .clka(clk),    
        .wea(way0_bank1_we),      
        .addra(way0_bank1_addr),  
        .dina(way0_bank1_wdata),    
        .douta(way0_r_bank1) ,
        .rsta(rst),
        .rsta_busy(way0_bank1_rsta_busy) 
    );

    BANK_WAY bank2_way0 (
        .clka(clk),    
        .wea(way0_bank2_we),      
        .addra(way0_bank2_addr),  
        .dina(way0_bank2_wdata),    
        .douta(way0_r_bank2)  ,
        .rsta(rst),
        .rsta_busy(way0_bank2_rsta_busy)
    );

    BANK_WAY bank3_way0 (
        .clka(clk),    
        .wea(way0_bank3_we),      
        .addra(way0_bank3_addr),  
        .dina(way0_bank3_wdata),    
        .douta(way0_r_bank3)  ,
        .rsta(rst),
        .rsta_busy(way0_bank3_rsta_busy)
    );

    // WAY1
    BANK_WAY bank0_way1 (
        .clka(clk),    
        .wea(way1_bank0_we),      
        .addra(way1_bank0_addr),  
        .dina(way1_bank0_wdata),    
        .douta(way1_r_bank0)  ,
        .rsta(rst),
        .rsta_busy(way1_bank0_rsta_busy)
    );

    BANK_WAY bank1_way1 (
        .clka(clk),    
        .wea(way1_bank1_we),      
        .addra(way1_bank1_addr),  
        .dina(way1_bank1_wdata),    
        .douta(way1_r_bank1)  ,
        .rsta(rst),
        .rsta_busy(way1_bank1_rsta_busy)
    );

    BANK_WAY bank2_way1 (
        .clka(clk),    
        .wea(way1_bank2_we),      
        .addra(way1_bank2_addr),  
        .dina(way1_bank2_wdata),    
        .douta(way1_r_bank2) ,
        .rsta(rst),
        .rsta_busy(way1_bank2_rsta_busy) 
    );

    BANK_WAY bank3_way1 (
        .clka(clk),    
        .wea(way1_bank3_we),      
        .addra(way1_bank3_addr),  
        .dina(way1_bank3_wdata),    
        .douta(way1_r_bank3)  ,
        .rsta(rst),
        .rsta_busy(way1_bank3_rsta_busy)
    );

    TAG tag_ram_way0 (
        .clka(clk),   
        .wea(way0_tag_we),      
        .addra(way0_tag_addr),  
        .dina(way0_tag_wdata),    
        .douta(way0_r_tag)  ,
        .rsta(rst),
        .rsta_busy(way0_tag_rsta_busy)
    );
    TAG tag_ram_way1 (
        .clka(clk),   
        .wea(way1_tag_we),      
        .addra(way1_tag_addr),  
        .dina(way1_tag_wdata),    
        .douta(way1_r_tag) ,
        .rsta(rst),
        .rsta_busy(way1_tag_rsta_busy) 
    );

    V_RAM v_ram_way0 (
        .clka(clk),
        .wea(way0_v_we),
        .addra(way0_v_addr),
        .dina(way0_v_wdata),
        .douta(way0_r_v),
        .rsta(rst),
        .rsta_busy(way0_v_rsta_busy)
    );

    V_RAM v_ram_way1 (
        .clka(clk),
        .wea(way1_v_we),
        .addra(way1_v_addr),
        .dina(way1_v_wdata),
        .douta(way1_r_v),
        .rsta(rst),
        .rsta_busy(way1_v_rsta_busy)
    ) ;



    wire [127:0] way0_r_data;
    wire [127:0] way1_r_data;
    assign way0_r_data ={way0_r_bank3,way0_r_bank2,way0_r_bank1,way0_r_bank0};
    assign way1_r_data ={way1_r_bank3,way1_r_bank2,way1_r_bank1,way1_r_bank0};
    assign way0_r_d = way0_d[index];
    assign way1_r_d = way1_d[index];


    wire [31:0] way0_data;
    wire [31:0] way1_data;
    assign way0_data = way0_r_data[req_buffer_offset[3:2] * 32 +:32];
    assign way1_data = way1_r_data[req_buffer_offset[3:2] * 32 +:32];


// ��CPU�������źš������߽������ź�
    assign addr_ok = (valid  && main_state_cur == IDLE)
                    || (cache_hit && valid && main_state_cur == LOOKUP) 
                    || (miss_buffer_op && axi_data_sram_addr_ok) ;
                    
    assign data_ok = (main_state_cur == LOOKUP && req_buffer_op == 1'b0 && cache_hit)    //��cache����,���� 
                    || (main_state_cur== REFILL && ret_valid && (miss_buffer_offset[3:2] == write_counter[1:0] || ret_last))  //��/дcache������û������
                    || (miss_buffer_op && axi_data_sram_data_ok) 
                    || (miss_buffer_uncache && axi_data_sram_data_ok);            
                   
    assign rdata =  data_ok == 1'b0         ? 32'b0    :
                    main_state_cur == REFILL ? ret_data :
                   way0_hit                 ? way0_data : way1_data ; 

    assign axi_data_sram_wr = miss_buffer_op ;
     
    assign axi_data_sram_addr = (miss_buffer_op || miss_buffer_uncache) ? miss_data_addr : {miss_data_addr[31:4],4'b0};

    assign axi_data_sram_wdata = miss_buffer_wdata ;
    assign axi_data_sram_size = miss_buffer_size ;
    assign axi_data_sram_wstrb = miss_buffer_wstrb ;
    assign axi_data_sram_len = miss_buffer_uncache ? 8'h0 : 8'h3;




    
endmodule
