//?????
`define  busrt_idle             3'b000
`define  busrt_transform_addr   3'b001
`define  busrt_transform_data0  3'b010
`define  busrt_transform_data1  3'b011 
`define  busrt_transform_data2  3'b100
`define  busrt_transform_data3  3'b101 
`define  busrt_wait_b           3'b110
module sram_axi_bridge(
    input  wire        aclk,
    input  wire        aresetn,
    output wire [3 :0] arid   ,
    output wire [31:0] araddr ,
    output wire [7 :0] arlen  ,
    output wire [2 :0] arsize ,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock ,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot ,
    output wire        arvalid,
    input  wire        arready,
    input  wire [3 :0] rid    ,
    input  wire [31:0] rdata  ,
    input  wire [1 :0] rresp  ,
    input  wire        rlast  ,
    input  wire        rvalid ,
    output wire        rready ,
    output reg [3 :0] awid   ,
    output reg [31:0] awaddr ,
    output reg [7 :0] awlen  ,
    output reg [2 :0] awsize ,
    output reg [1 :0] awburst,
    output reg [1 :0] awlock ,
    output reg [3 :0] awcache,
    output reg [2 :0] awprot ,
    output reg        awvalid,
    input  wire        awready,
    output reg [3 :0] wid    ,
    output reg [31:0] wdata  ,
    output reg [3 :0] wstrb  ,
    output reg        wlast  ,
    output reg        wvalid ,
    input  wire        wready ,
    input  wire [3 :0] bid    ,
    input  wire [1 :0] bresp  ,
    input  wire        bvalid ,
    output reg        bready,

    //ins_cache axi interface
    input  wire        icache_rd_req,
    input  wire [2 :0] icache_rd_type,
    input  wire [31:0] icache_rd_addr,
    output wire        icache_rd_rdy,
    output wire        icache_ret_valid,
    output wire [1 :0] icache_ret_last,
    output wire [31:0] icache_ret_data,

    //ins_cache axi interface
    input  wire        dcache_rd_req,
    input  wire [2 :0] dcache_rd_type,
    input  wire [31:0] dcache_rd_addr,
    output wire        dcache_rd_rdy,
    output wire        dcache_ret_valid,
    output wire [1 :0] dcache_ret_last,
    output wire [31:0] dcache_ret_data,
    input  wire        dcache_wr_req,
    output wire        dcache_wr_rdy,
    input  wire [2 :0] dcache_wr_type,
    input  wire [31:0] dcache_wr_addr,
    input  wire [3 :0] dcache_wr_wstrb,
    input  wire [127:0]dcache_wr_data
);
    assign arburst = 2'b01;
    assign arlock  = 2'b00;
    assign arprot  = 3'b000;
    assign rready  = 1'h1;
    
    

    wire [7:0]                  ins_arlen;
    wire [2:0]                  ins_arsize;
    wire [3:0]                  ins_arcache;
    wire [4+32+8+3+4-1:0]       ins_req_buf_to_ar_bus; //output   arid araddr arlen arsize arcache


    wire [7:0]                  data_arlen;
    wire [2:0]                  data_arsize;
    wire [3:0]                  data_arcache;
    wire [7:0]                  data_awlen;
    wire [2:0]                  data_awsize;
    wire [3:0]                  data_awcache;
    //wire                        data_rreq_buf_allowin;
    //reg                         data_rreq_buf_valid;
    wire [4+32+8+3+4-1:0]       data_req_buf_to_ar_bus;  //output-awid araddr arlen arsize arcache

    wire                        select_ins_rreq;
    wire                        select_data_rreq; 
    wire                        final_req_to_ar_valid;
    wire [4+32+8+3+4-1:0]       final_req_to_ar_bus;


    wire                        ar_buf_allowin;  
    reg                         ar_buf_valid;
    reg [4+32+8+3+4-1:0]        ar_buf;

    reg [3:0]                   r_buf_rid;
    reg                         r_buf_rvalid;
    reg [31:0]                  r_buf_rdata;
    reg                         r_buf_last;

    
    reg [2:0]                   state;
    //同一地址读写冲突处理
    wire                        icache_conflict_with_write;
    wire                        dcache_conflict_with_write;
    wire                        conflict_with_read;
    always @(posedge aclk ) begin
        if(!aresetn)begin
            state <= `busrt_idle;
        end
        else if(state == `busrt_idle && dcache_wr_req && !conflict_with_read)begin
            state <= `busrt_transform_addr;
        end
        else if(state == `busrt_transform_addr && awready)begin
            state <= `busrt_transform_data0;
        end
        else if(state == `busrt_transform_data0 && wready && ~wlast)begin
            state <= `busrt_transform_data1;
        end
        else if(state == `busrt_transform_data0 && wready && wlast)begin
            state <= `busrt_wait_b;
        end
        else if(state == `busrt_transform_data1 && wready)begin
            state <= `busrt_transform_data2;
        end
        else if(state == `busrt_transform_data2 && wready)begin
            state <= `busrt_transform_data3;
        end
        else if(state == `busrt_transform_data3 && wready)begin
            state <= `busrt_wait_b;
        end
        else if(state == `busrt_wait_b && bvalid && bready)begin
            state <= `busrt_idle;
        end
    end
    
    assign icache_conflict_with_write = (dcache_wr_req && dcache_wr_addr[31:4] == icache_rd_addr[31:4] && state == `busrt_idle) || (state != `busrt_idle && icache_rd_addr[31:4] == awaddr[31:4]);
    assign ins_arlen = icache_rd_type == 3'b100 ? 8'b11 : 8'b0;
    assign ins_arsize = icache_rd_type == 3'b100 ? 3'b010 : icache_rd_type;
    assign ins_arcache = {4{1'b0}};
    assign ins_req_buf_to_ar_bus = {4'h0,icache_rd_addr,ins_arlen,ins_arsize,ins_arcache};
    assign icache_rd_rdy = select_ins_rreq && !icache_conflict_with_write;

    assign dcache_conflict_with_write = (state != `busrt_idle && dcache_rd_addr[31:4] == awaddr[31:4]);
    assign data_arlen = dcache_rd_type == 3'b100 ? 8'b11 : 8'b0;
    assign data_arsize = dcache_rd_type == 3'b100 ? 3'b010 : dcache_rd_type;
    assign data_arcache = {4{1'b0}};
    assign data_awlen = dcache_wr_type == 3'b100 ? 8'b11 : 8'b0;
    assign data_awsize = dcache_wr_type == 3'b100 ? 3'b10 : dcache_wr_type;
    assign data_awcache = {4{1'b0}};
    assign conflict_with_read = (ar_buf_valid && dcache_wr_addr[31:4] == araddr[31:4]);
    assign data_req_buf_to_ar_bus = {4'h1,dcache_rd_addr,data_arlen,data_arsize,data_arcache};
    assign dcache_rd_rdy = select_data_rreq  && !dcache_conflict_with_write;
    assign dcache_wr_rdy = state == `busrt_idle && !conflict_with_read;

    
    assign  select_ins_rreq  = ar_buf_allowin && !dcache_rd_req && icache_rd_req && !icache_conflict_with_write;
    assign  select_data_rreq = ar_buf_allowin &&  dcache_rd_req && !dcache_conflict_with_write;
    assign  final_req_to_ar_valid = (icache_rd_req && !icache_conflict_with_write) || (dcache_rd_req && !dcache_conflict_with_write);
    assign  final_req_to_ar_bus = dcache_rd_req ? data_req_buf_to_ar_bus : ins_req_buf_to_ar_bus;


    always @(posedge aclk) begin
        if(!aresetn)
            ar_buf_valid <= 0;
        else if(ar_buf_allowin)
            ar_buf_valid <= final_req_to_ar_valid;
    end
    always @(posedge aclk) begin
        if(!aresetn)
            ar_buf <= 0;
        else if(ar_buf_allowin)
            ar_buf <= final_req_to_ar_bus;
    end
    assign ar_buf_allowin = !ar_buf_valid || arready;

    assign {arid,araddr,arlen,arsize,arcache} = ar_buf_valid ? ar_buf : 0;
    assign arvalid = ar_buf_valid;

    reg [127:0] wdata_buffer;
    always @(posedge aclk) begin
        if (!aresetn) begin
            awid <= 0;
            awaddr <= 0;
            awlen <= 0;
            awsize <= 0;
            awburst <= 0;
            awlock <= 0;
            awcache <= 0;
            awprot <= 0;
            awvalid <= 0;
        end
        else if(state == `busrt_idle && dcache_wr_req) begin
            awvalid <= 1;
            awaddr <= dcache_wr_addr;
            awsize  <= data_awsize;
            awlen <= data_awlen;
            awburst <= 2'b01;
            awlock <= 2'b00;
            awprot <= 3'b000;
            awid <= 1;
            awcache <= 0;
        end
        else if(state == `busrt_transform_addr && awready) awvalid <= 0;
    end

    always @(posedge aclk) begin
        if(!aresetn)begin
          wid <= 0;
          wdata <= 0;
          wstrb <= 0;
          wlast <= 0;
          wvalid <= 0;
          wdata_buffer <= 0;
        end
        else if (state == `busrt_idle && dcache_wr_req)begin
            wdata <= dcache_wr_data[31:0];
            wstrb <= dcache_wr_wstrb;
            wdata_buffer <= {32'b0,dcache_wr_data[127:32]};
            wid<= 1;
        end
        else if(state == `busrt_transform_addr && awready)begin
            wvalid <= 1;
            wlast <= awlen == 0;
        end
        else if(state == `busrt_transform_data0 && wready && wlast)begin
            wvalid <= 0;
            wlast <= 0;
        end
        else if((state == `busrt_transform_data0 && !wlast) || state == `busrt_transform_data1 || state == `busrt_transform_data2)begin
            if(wready)begin
                wdata <= wdata_buffer[31:0];
                wvalid <= 1;
                wdata_buffer <= {32'b0,wdata_buffer[127:32]};
                wlast <= state == `busrt_transform_data2;
            end
        end
        else if(state == `busrt_transform_data3)begin
            if(wready && wlast)begin
                wvalid <= 0;
                wlast <= 0;
            end
        end
    end
    
    always @(posedge aclk) begin
        if(!aresetn) bready<=0;
        else if((state == `busrt_transform_data3 || state == `busrt_transform_data0) && wready && wlast) bready <= 1;
        else if(state == `busrt_wait_b && bvalid && bready) bready <= 0;
    end

    //响应通道
    always @(posedge aclk) begin
        if(!aresetn)
            r_buf_rid <= 0;
        else
            r_buf_rid <= rid;
    end
    always @(posedge aclk) begin
        if(!aresetn)
            r_buf_rvalid <= 0;
        else
            r_buf_rvalid <= rvalid;
    end
    always @(posedge aclk) begin
        if(!aresetn)
            r_buf_rdata <= 0;
        else
            r_buf_rdata <= rdata;
    end
    always @(posedge aclk) begin
        if(!aresetn)
            r_buf_last <= 0;
        else
            r_buf_last <= rlast;
    end
    assign icache_ret_valid = r_buf_rid == 4'h0 && r_buf_rvalid;
    assign dcache_ret_valid = r_buf_rid == 4'h1 && r_buf_rvalid; 
    assign icache_ret_data = r_buf_rdata;
    assign dcache_ret_data = r_buf_rdata;
    assign icache_ret_last = {1'b0,{r_buf_last}};
    assign dcache_ret_last = {1'b0,{r_buf_last}};
endmodule
