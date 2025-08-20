`include "header.h"

module BUFFER(
    input clk,
    input reset,
    input flush,

    input ID_FIFO_valid,  // ID阶段的ready_go信号,到时候可以考虑在我们的架构下是否需要
    input [`WIDTH_ID_FIFO_BUS-1:0] ID_FIFO_bus1,    
    input [`WIDTH_ID_FIFO_BUS-1:0] ID_FIFO_bus2,
    input [`WIDTH_ID_DECODE_BUS-1:0] ID_decode_bus1,
    input [`WIDTH_ID_DECODE_BUS-1:0] ID_decode_bus2,
    input inst1_valid,
    input inst2_valid,
    input IS_stall, 
    input EX1_stall,
    input EX2_stall,
    input MEM_stall,
`ifdef DEBUG
    input CM_stall,
`endif

    output [`WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_bus1,
    output [`WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_bus2,
    output FIFO_IS_valid,
    output FIFO_stall

    `ifdef DIFFTEST_EN
    ,
    input  [`DIFF_WIDTH_ID_FIFO_BUS-1:0] ID_FIFO_diff_bus_1,
    input  [`DIFF_WIDTH_ID_FIFO_BUS-1:0] ID_FIFO_diff_bus_2,
    output [`DIFF_WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_diff_bus_1,
    output [`DIFF_WIDTH_FIFO_IS_BUS-1:0] FIFO_IS_diff_bus_2
    `endif
);
    //branch
    wire [ 8:0] br_op1;
    wire [ 8:0] br_op2;
    wire [25:0] offs1_26;
    wire [25:0] offs2_26;
    //寄存器堆相关信号
    wire [4:0] rj1;
    wire [4:0] rk1;
    wire [4:0] rd1;
    wire [4:0] dest1;
    wire need_rj1;
    wire need_rk1;
    wire need_rd1;
    wire sel_rf_ra2_1;   //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
    wire [4:0] rj2;
    wire [4:0] rk2;
    wire [4:0] rd2;
    wire [4:0] dest2;
    wire need_rj2;
    wire need_rk2;
    wire need_rd2;
    wire sel_rf_ra2_2;   //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd

    //FIFO队列暂时按照微分的结构，但是个人感觉不需要这么大的队列
    localparam FIFO_DEPTH_BITS = $clog2(`FIFO_DEPTH);
    reg [FIFO_DEPTH_BITS - 1:0] tail;
    reg [FIFO_DEPTH_BITS - 1:0] head;
    wire [FIFO_DEPTH_BITS - 1:0] head_sec;
    reg [`WIDTH_ID_DECODE_BUS   -1:0] FIFO_data      [`FIFO_DEPTH - 1:0];
    reg [`WIDTH_ID_FIFO_BUS     -1:0] FIFO_waydata   [`FIFO_DEPTH - 1:0];
`ifdef DIFFTEST_EN
    reg [`DIFF_WIDTH_FIFO_IS_BUS-1:0] FIFO_data_diff [`FIFO_DEPTH - 1:0];
`endif
    wire [FIFO_DEPTH_BITS - 1:0] sub_1;
    wire [FIFO_DEPTH_BITS - 1:0] sub_2;
    wire [FIFO_DEPTH_BITS:0] FIFO_count;
    wire FIFO_empty;
    wire FIFO_full;
    wire stall;
    reg flush_reg;

    //指令发射相关信号
    wire [4:0] rf_raddr1;
    wire [4:0] rf_raddr2;
    wire [4:0] rf_raddr3;
    wire [4:0] rf_raddr4;
    wire [31:0] rj_value1;
    wire [31:0] rkd_value1;
    wire [31:0] rj_value2;
    wire [31:0] rkd_value2;
    wire [4:0] inst_issue_way1;
    wire [4:0] inst_issue_way2;
    wire inst12_conflict;
    wire issue_mode;

    integer i;
    always@(posedge clk)begin 
    if(reset) begin 
        head <= {FIFO_DEPTH_BITS{1'b0}};
        tail <= {FIFO_DEPTH_BITS{1'b0}};
        for (i = 0; i < `FIFO_DEPTH; i = i + 1) begin
            FIFO_data[i] <= {`WIDTH_ID_DECODE_BUS{1'b0}};    // 清空指令数据
            FIFO_waydata[i] <= {`WIDTH_ID_FIFO_BUS{1'b0}};    // 清空通路数据
        end
    end
    else if(flush) begin
        head <= {FIFO_DEPTH_BITS{1'b0}};
        tail <= {FIFO_DEPTH_BITS{1'b0}};
    end
    else begin
    //出队
    if(issue_mode == 1'b0 && !FIFO_empty && !stall)begin //单指令   
        head <= (head < (`FIFO_DEPTH - 1)) ? head + 1 : {FIFO_DEPTH_BITS{1'b0}};
    end
    else if(issue_mode ==1'b1 && !FIFO_empty && !stall)begin //双指令
        if(head == `FIFO_DEPTH - 2)begin
            head <= {FIFO_DEPTH_BITS{1'b0}};
        end
        else if(head == `FIFO_DEPTH - 1)begin
            head <= {{(FIFO_DEPTH_BITS-1){1'b0}}, 1'b1};
        end
        else begin
            head <= head + 2'b10;
        end
    end
    //入队
    if ( inst1_valid == 1'b1 && inst2_valid == 1'b0 && ID_FIFO_valid) begin //单指令
        FIFO_data[tail] <= ID_decode_bus1;
        FIFO_waydata[tail] <= ID_FIFO_bus1;
        `ifdef DIFFTEST_EN
            FIFO_data_diff[tail] <= ID_FIFO_diff_bus_1;
        `endif
        tail <= (tail < (`FIFO_DEPTH - 1)) ? tail + 1 : {FIFO_DEPTH_BITS{1'b0}};
    end
    else if(inst1_valid == 1'b1 && inst2_valid == 1'b1 && ID_FIFO_valid) begin //双指令
        if(tail == (`FIFO_DEPTH - 2))begin
            FIFO_data[tail]         <= ID_decode_bus1;
            FIFO_waydata[tail]      <= ID_FIFO_bus1;
            FIFO_data[tail+1'd1]    <= ID_decode_bus2;
            FIFO_waydata[tail+1'd1] <= ID_FIFO_bus2;

            `ifdef DIFFTEST_EN
                FIFO_data_diff[tail]      <= ID_FIFO_diff_bus_1;
                FIFO_data_diff[tail+1'd1] <= ID_FIFO_diff_bus_2;
            `endif
            tail <= {FIFO_DEPTH_BITS{1'b0}};
        end
        else if(tail == (`FIFO_DEPTH - 1))begin
            FIFO_data   [tail] <= ID_decode_bus1;
            FIFO_waydata[tail] <= ID_FIFO_bus1;
            FIFO_data   [0] <= ID_decode_bus2;
            FIFO_waydata[0] <= ID_FIFO_bus2;

            `ifdef DIFFTEST_EN
                FIFO_data_diff[tail] <= ID_FIFO_diff_bus_1;
                FIFO_data_diff[0]    <= ID_FIFO_diff_bus_2;
            `endif
            tail <= 1;
        end
        else begin
            FIFO_data[tail] <= ID_decode_bus1;
            FIFO_waydata[tail] <= ID_FIFO_bus1;
            FIFO_data[tail + 1'd1] <= ID_decode_bus2;
            FIFO_waydata[tail + 1'd1] <= ID_FIFO_bus2;

            `ifdef DIFFTEST_EN
                FIFO_data_diff[tail]      <= ID_FIFO_diff_bus_1;
                FIFO_data_diff[tail+1'd1] <= ID_FIFO_diff_bus_2;
            `endif
            tail <= tail + 2'b10;
        end
    end
    end
end

    assign sub_1 = tail - head;
    assign sub_2 = `FIFO_DEPTH + tail - head;
    assign FIFO_count = (tail >= head) ? sub_1 : sub_2;
    assign FIFO_IS_valid = ~FIFO_empty;
    assign head_sec = (head == `FIFO_DEPTH - 1) ? 0 : head + 1;
    assign FIFO_empty = (head == tail);
    assign FIFO_full = (FIFO_count > `FIFO_DEPTH - 3) & ~flush_reg;
    assign FIFO_stall = FIFO_full;
    always@(posedge clk) begin
        if(reset) begin
            flush_reg <= 1'b0;
        end
        else if(flush) begin
            flush_reg <= 1'b1;
        end
        else begin
            flush_reg <= 1'b0;
        end
    end
`ifdef DEBUG
    assign stall = IS_stall | EX1_stall | EX2_stall | MEM_stall | CM_stall;
`else
    assign stall = IS_stall | EX1_stall | EX2_stall | MEM_stall;
`endif

    //寄存器操作
    assign {
        br_op1,
        offs1_26,
        rj1,
        rk1,
        rd1,
        dest1,
        need_rj1,
        need_rk1,
        need_rd1,
        sel_rf_ra2_1,   //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
        inst_issue_way1
    } = FIFO_waydata[head];

    assign {
        br_op2,
        offs2_26,
        rj2,
        rk2,
        rd2,
        dest2,
        need_rj2,
        need_rk2,
        need_rd2,
        sel_rf_ra2_2,   //寄存器堆Read_Address2选择信号, 低电平0选择rk，高电平1选择rd
        inst_issue_way2
    } = FIFO_waydata[head_sec];

    assign rf_raddr1 = rj1;
    assign rf_raddr2 = sel_rf_ra2_1 ? rd1 : rk1;

    assign rf_raddr3 = rj2;
    assign rf_raddr4 = sel_rf_ra2_2 ? rd2 : rk2;

    assign inst12_conflict = ((rf_raddr1 == dest2 || rf_raddr2 == dest2) && |dest2) || ((rf_raddr3 == dest1 || rf_raddr4 == dest1) && |dest1);
    assign issue_mode = ~((FIFO_count < 2) ||         // FIFO队列中指令数小于2时，单指令发射
                         ((inst_issue_way1 == inst_issue_way2) && !(inst_issue_way1[0] || inst_issue_way1[1])) || //两条指令的发射方式相同，且不为可并行处理的指令时，单指令发射
                           inst12_conflict ||                 //两条指令存在寄存器冲突时，单指令发射
                          (inst_issue_way1[3] == 1'b1 || inst_issue_way1[4] == 1'b1));         //csr指令、访存指令或者tlb指令时，单指令发射
    // assign issue_mode = 1'b0;

    assign FIFO_IS_bus1 = {
        FIFO_full,
        FIFO_empty,
        issue_mode,
        br_op1,         //9
        offs1_26,       // 26
        rj1,            //5
        rk1,            //5
        rd1,            //5
        rf_raddr1,      //5
        rf_raddr2,      //5
        need_rj1,       //1
        need_rk1,       //1
        need_rd1,       //1
        dest1,          //5
        FIFO_data[head] //186
    };

    assign FIFO_IS_bus2 = {
        br_op2,         //9
        offs2_26,       // 26
        rj2,
        rk2,
        rd2,
        rf_raddr3,
        rf_raddr4,
        need_rj2,
        need_rk2,
        need_rd2,
        dest2,
        FIFO_data[head_sec]
    } & {`WIDTH_FIFO_IS_BUS{issue_mode}};

    `ifdef DIFFTEST_EN
        assign FIFO_IS_diff_bus_1 = FIFO_data_diff[head];
        assign FIFO_IS_diff_bus_2 = FIFO_data_diff[head_sec];
    `endif
endmodule