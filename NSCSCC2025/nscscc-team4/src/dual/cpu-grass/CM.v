`include "header.h"
module CM (
    input                               clk,
    input                               reset,
    input      [`WIDTH_MEM_CM_BUS-1:0]  MEM_CM_bus1,
    input      [`WIDTH_MEM_CM_BUS-1:0]  MEM_CM_bus2,
    input                               MEM_CM_valid, 
    output                              CM_stall,  
    output reg [`WIDTH_MEM_CM_BUS-1:0]  CM_bus,
    output                              CM_debug_valid

    `ifdef DIFFTEST_EN
        ,
        output [9:0] CM_forward_bus,
        input  [`DIFF_WIDTH_MEM_CM_BUS-1:0] MEM_CM_diff_bus_1,
        input  [`DIFF_WIDTH_MEM_CM_BUS-1:0] MEM_CM_diff_bus_2,
        input  [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_1,
        input  [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_2,

        output [`DIFF_WIDTH_MEM_CM_BUS-1:0] CM_diff_bus,
        output [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] CM_diff_ctrl_bus
    `endif
);

localparam COMMIT_FIRST  = 2'b01;
localparam COMMIT_SECOND = 2'b10;

`ifdef DIFFTEST_EN
reg [`DIFF_WIDTH_MEM_CM_BUS-1:0] MEM_CM_diff_bus_reg_1;
reg [`DIFF_WIDTH_MEM_CM_BUS-1:0] MEM_CM_diff_bus_reg_2;
reg [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_reg_1;
reg [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] MEM_CM_diff_ctrl_bus_reg_2;
reg [`DIFF_WIDTH_MEM_CM_BUS-1:0] pending_diff_bus[0:1];
reg [`DIFF_WIDTH_MEM_CM_CTRL_BUS-1:0] pending_diff_ctrl_bus[0:1];
`endif

// bus
reg [`WIDTH_MEM_CM_BUS-1:0] MEM_CM_bus_reg_1;
reg [`WIDTH_MEM_CM_BUS-1:0] MEM_CM_bus_reg_2;

// commit
wire [31:0] CM_pc1;
wire [4:0]  CM_waddr1;
wire [31:0] CM_wdata1;
wire        CM_we1;
wire [31:0] CM_pc2;
wire [4:0]  CM_waddr2;
wire [31:0] CM_wdata2;
wire        CM_we2;
reg         CM_valid;
wire        CM_mode;
reg         CM_ok;

// queue
reg [`WIDTH_MEM_CM_BUS-1:0] pending_bus[0:1];   

// control
wire stall;
// 提交状态机
reg [1:0] main_state;
reg [1:0] next_state;

assign stall = CM_stall;
assign CM_stall = ~reset & (next_state == COMMIT_SECOND) & CM_valid;
assign CM_debug_valid = CM_valid;

// 输入寄存器
always @(posedge clk) begin
    if(reset) begin
        MEM_CM_bus_reg_1 <= `WIDTH_MEM_CM_BUS'b0;
        MEM_CM_bus_reg_2 <= `WIDTH_MEM_CM_BUS'b0;
    end
    else if(~stall) begin
        MEM_CM_bus_reg_1 <= MEM_CM_bus1;
        MEM_CM_bus_reg_2 <= MEM_CM_bus2;
    end
end

always @(posedge clk) begin
    if(reset) begin
        CM_valid <= 1'b0;
    end
    else if(~stall) begin
        CM_valid <= MEM_CM_valid;
    end
end

// 总线解包
assign {
    CM_mode,
    CM_waddr1,
    CM_we1,
    CM_wdata1,
    CM_pc1
} = MEM_CM_bus_reg_1;

assign {
    CM_waddr2,
    CM_we2,
    CM_wdata2,
    CM_pc2
} = MEM_CM_bus_reg_2;

// 状态寄存器更新
always @(posedge clk) begin
    if(reset) begin
        main_state <= COMMIT_FIRST;
    end 
    else begin
        main_state <= next_state;
    end
end

always @(*) begin
    if(reset) begin
        pending_bus[0] = `WIDTH_MEM_CM_BUS'b0;
        pending_bus[1] = `WIDTH_MEM_CM_BUS'b0;
    end
    else begin
        pending_bus[0] = {
            CM_waddr1,
            CM_we1,
            CM_wdata1,
            CM_pc1  
        };
        pending_bus[1] = {
            CM_waddr2,
            CM_we2,
            CM_wdata2,
            CM_pc2  
        };
    end
end

// 下一状态逻辑
always @(*) begin
    if(reset) begin
        next_state = COMMIT_FIRST;
        CM_bus = `WIDTH_MEM_CM_BUS'b0;
    end
    else begin
        case(main_state)
            COMMIT_FIRST: begin
                // 提交第一条指令
                CM_bus = pending_bus[0];
                `ifdef DIFFTEST_EN
                    CM_diff_bus = pending_diff_bus[0];
                    CM_diff_ctrl_bus = pending_diff_ctrl_bus[0];
                `endif
                if(CM_mode) begin
                    next_state = COMMIT_SECOND;
                end
                else begin
                    next_state = COMMIT_FIRST;
                end
            end
            
            COMMIT_SECOND: begin
                // 提交第二条指令
                CM_bus = pending_bus[1];
                `ifdef DIFFTEST_EN
                    CM_diff_bus = pending_diff_bus[1];
                    CM_diff_ctrl_bus = pending_diff_ctrl_bus[1];
                `endif
                next_state = COMMIT_FIRST;
            end
            
            default: begin
                next_state = COMMIT_FIRST;
            end
        endcase
    end
end

`ifdef DIFFTEST_EN

wire [4:0] CM_dest1;
wire [4:0] CM_dest2;

always @(posedge clk) begin
    if(reset) begin
        MEM_CM_diff_bus_reg_1 <= `DIFF_WIDTH_MEM_CM_BUS'b0;
        MEM_CM_diff_bus_reg_2 <= `DIFF_WIDTH_MEM_CM_BUS'b0;
        MEM_CM_diff_ctrl_bus_reg_1 <= `DIFF_WIDTH_MEM_CM_CTRL_BUS'b0;
        MEM_CM_diff_ctrl_bus_reg_2 <= `DIFF_WIDTH_MEM_CM_CTRL_BUS'b0;
    end
    else if(~stall) begin
        MEM_CM_diff_bus_reg_1 <= MEM_CM_diff_bus_1;
        MEM_CM_diff_bus_reg_2 <= MEM_CM_diff_bus_2;
        MEM_CM_diff_ctrl_bus_reg_1 <= MEM_CM_diff_ctrl_bus_1;
        MEM_CM_diff_ctrl_bus_reg_2 <= MEM_CM_diff_ctrl_bus_2;
    end
end
always @(*) begin
    if(reset) begin
        pending_diff_bus[0] = `DIFF_WIDTH_MEM_CM_BUS'b0;
        pending_diff_bus[1] = `DIFF_WIDTH_MEM_CM_BUS'b0;
        pending_diff_ctrl_bus[0] = `DIFF_WIDTH_MEM_CM_CTRL_BUS'b0;
        pending_diff_ctrl_bus[1] = `DIFF_WIDTH_MEM_CM_CTRL_BUS'b0;
    end
    else begin
        pending_diff_bus[0] = MEM_CM_diff_bus_reg_1;
        pending_diff_bus[1] = MEM_CM_diff_bus_reg_2;
        pending_diff_ctrl_bus[0] = MEM_CM_diff_ctrl_bus_reg_1;
        pending_diff_ctrl_bus[1] = MEM_CM_diff_ctrl_bus_reg_2;
    end
end

assign CM_dest1 = CM_waddr1 & {5{CM_we1}};
assign CM_dest2 = CM_waddr2 & {5{CM_we2}};
assign CM_forward_bus = {CM_dest1, CM_dest2};

`endif

endmodule