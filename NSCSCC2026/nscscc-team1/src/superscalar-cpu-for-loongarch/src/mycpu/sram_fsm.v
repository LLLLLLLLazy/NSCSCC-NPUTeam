`include "header.v"


module sram_fsm (
    input wire clk,
    input wire resetn,

    input wire addr_ok,
    input wire req,
    input wire data_ok,
    input wire not_ready_go,

    output reg [1:0] state
);

    always @(posedge clk) begin
        if (!resetn) state <= `SRAM_IDLE;
        else if (!not_ready_go) state <= `SRAM_IDLE;
        else if (state == `SRAM_IDLE && addr_ok && req) state <= `SRAM_BUZY;
        else if (state == `SRAM_BUZY && data_ok) state <= `SRAM_FINISH;
    end

endmodule


module inst_sram_fsm (
    input wire clk,
    input wire resetn,

    input  wire hit,
    input  wire miss,
    output wire miss_req,
    input  wire miss_ready,

    input wire refill_valid,
    input wire stall,

    output reg [2:0] state
);

    always @(posedge clk) begin
        if (!resetn) begin
            state <= `INST_SRAM_FSM_IDLE;
        end else if (!stall) begin
            state <= `INST_SRAM_FSM_IDLE;
        end else if (hit && state == `INST_SRAM_FSM_IDLE) begin
            state <= `INST_SRAM_FSM_HIT;
        end else if (miss && state == `INST_SRAM_FSM_IDLE) begin
            state <= `INST_SRAM_FSM_MISS;
        end else if (miss_ready && state == `INST_SRAM_FSM_MISS) begin
            state <= `INST_SRAM_FSM_WAIT;
        end else if (refill_valid && state == `INST_SRAM_FSM_WAIT) begin
            state <= `INST_SRAM_FSM_FINISH;
        end

    end

    assign miss_req = state == `INST_SRAM_FSM_MISS;
endmodule

module data_sram_fsm (
    input wire clk,
    input wire resetn,

    input  wire hit,
    input  wire miss,
    output wire miss_req,
    input  wire miss_ready,

    input wire refill_valid,
    input wire miss_trans,
    input wire stall,

    output reg [2:0] state
);

    always @(posedge clk) begin
        if (!resetn) begin
            state <= `DATA_SRAM_FSM_IDLE;
        end else if (!stall) begin
            state <= `DATA_SRAM_FSM_IDLE;
        end else if (hit && state == `DATA_SRAM_FSM_IDLE) begin
            state <= `DATA_SRAM_FSM_HIT;
        end else if (miss && state == `DATA_SRAM_FSM_IDLE) begin
            state <= `DATA_SRAM_FSM_MISS;
        end else if (miss_trans && state == `DATA_SRAM_FSM_MISS) begin
            state <= `DATA_SRAM_FSM_SHAKE;
        end else if (miss_ready && state == `DATA_SRAM_FSM_SHAKE) begin
            state <= `DATA_SRAM_FSM_WAIT;
        end else if (refill_valid && state == `DATA_SRAM_FSM_WAIT) begin
            state <= `DATA_SRAM_FSM_FINISH;
        end

    end

    assign miss_req = state == `DATA_SRAM_FSM_SHAKE;

endmodule
