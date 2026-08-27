`ifdef difftest


module cpu_signed_divider (
        input  wire        aclk,
        input  wire        s_axis_divisor_tvalid,
        input  wire [31:0] s_axis_divisor_tdata,
        input  wire        s_axis_dividend_tvalid,
        input  wire [31:0] s_axis_dividend_tdata,
        output wire        m_axis_dout_tvalid,
        output wire [63:0] m_axis_dout_tdata
    );
    localparam DIV_LATENCY = 32;

    wire [31:0] quot, rem;
    reg  [63:0] result_pipe [0:DIV_LATENCY-1];
    reg  [DIV_LATENCY-1:0] valid_pipe = {DIV_LATENCY{1'b0}};
    integer i;

    assign quot = $signed(s_axis_dividend_tdata) / $signed(s_axis_divisor_tdata);
    assign rem  = $signed(s_axis_dividend_tdata) % $signed(s_axis_divisor_tdata);

    always @(posedge aclk) begin
        result_pipe[0] <= {quot, rem};
        valid_pipe[0]  <= s_axis_divisor_tvalid && s_axis_dividend_tvalid;
        for (i = 1; i < DIV_LATENCY; i = i + 1) begin
            result_pipe[i] <= result_pipe[i-1];
            valid_pipe[i]  <= valid_pipe[i-1];
        end
    end

    assign m_axis_dout_tdata  = result_pipe[DIV_LATENCY-1];
    assign m_axis_dout_tvalid = valid_pipe[DIV_LATENCY-1];


endmodule

module cpu_unsigned_divider (
        input  wire        aclk,
        input  wire        s_axis_divisor_tvalid,
        input  wire [31:0] s_axis_divisor_tdata,
        input  wire        s_axis_dividend_tvalid,
        input  wire [31:0] s_axis_dividend_tdata,
        output wire        m_axis_dout_tvalid,
        output wire [63:0] m_axis_dout_tdata
    );

    localparam DIV_LATENCY = 32;

    wire [31:0] quot, rem;
    reg  [63:0] result_pipe [0:DIV_LATENCY-1];
    reg  [DIV_LATENCY-1:0] valid_pipe = {DIV_LATENCY{1'b0}};
    integer i;

    assign quot = $unsigned(s_axis_dividend_tdata) / $unsigned(s_axis_divisor_tdata);
    assign rem  = $unsigned(s_axis_dividend_tdata) % $unsigned(s_axis_divisor_tdata);

    always @(posedge aclk) begin
        result_pipe[0] <= {quot, rem};
        valid_pipe[0]  <= s_axis_divisor_tvalid && s_axis_dividend_tvalid;
        for (i = 1; i < DIV_LATENCY; i = i + 1) begin
            result_pipe[i] <= result_pipe[i-1];
            valid_pipe[i]  <= valid_pipe[i-1];
        end
    end

    assign m_axis_dout_tdata  = result_pipe[DIV_LATENCY-1];
    assign m_axis_dout_tvalid = valid_pipe[DIV_LATENCY-1];


endmodule


module cpu_signed_multiplier (
        input  wire        CLK,
        input  wire [31:0] A,
        input  wire [31:0] B,
        output wire [63:0] P
    );

    localparam MUL_LATENCY = 3;

    reg [63:0] result_pipe [0:MUL_LATENCY-1];
    integer i;

    always @(posedge CLK) begin
        result_pipe[0] <= $signed({{32{A[31]}}, A}) *
                   $signed({{32{B[31]}}, B});
        for (i = 1; i < MUL_LATENCY; i = i + 1)
            result_pipe[i] <= result_pipe[i-1];
    end

    assign P = result_pipe[MUL_LATENCY-1];

endmodule


module cpu_unsigned_multiplier (
        input  wire        CLK,
        input  wire [31:0] A,
        input  wire [31:0] B,
        output wire [63:0] P
    );

    localparam MUL_LATENCY = 3;

    reg [63:0] result_pipe [0:MUL_LATENCY-1];
    integer i;

    always @(posedge CLK) begin
        result_pipe[0] <= {32'b0, A} * {32'b0, B};
        for (i = 1; i < MUL_LATENCY; i = i + 1)
            result_pipe[i] <= result_pipe[i-1];
    end

    assign P = result_pipe[MUL_LATENCY-1];

endmodule

//-----------------------------------------------------------------------------
// data_bank_ram: 128x32 鍗曠鍙� RAM锛屽甫瀛楄妭鍐欎娇鑳� (8-bank L1: 128 sets)
//-----------------------------------------------------------------------------
// module data_bank_ram (
//     input  wire        clka,
//     input  wire        ena,
//     input  wire [3:0]  wea,
//     input  wire [7:0]  addra,
//     input  wire [31:0] dina,
//     output reg  [31:0] douta
// );

//     // 瀛樺偍浣�
//     reg [31:0] mem [0:255];

//     // 璇绘搷浣滐細鍦板潃閿佸瓨锛堥槻姝㈠湴鍧�鍙樺寲鏃惰緭鍑哄彉鍖栵級
//     always @(posedge clka) begin
//         if (ena) begin
//             douta <= mem[addra];
//         end
//     end

//     // 鍐欐搷浣滐細鎸夊瓧鑺備娇鑳藉啓鍏�
//     integer i;
//     always @(posedge clka) begin
//         if (ena) begin
//             if (wea[0]) mem[addra][7:0]   <= dina[7:0];
//             if (wea[1]) mem[addra][15:8]  <= dina[15:8];
//             if (wea[2]) mem[addra][23:16] <= dina[23:16];
//             if (wea[3]) mem[addra][31:24] <= dina[31:24];
//         end
//     end

// endmodule
// =====================================================
// data_bank_ram锛�32 浣嶅啓浼樺厛鍙岀鍙� RAM (L1: 128 sets, 7-bit addr)
// =====================================================
module data_bank_ram (
        input wire        clka,
        input wire        ena,
        input wire [ 3:0] wea,    // 姣� bit 瀵瑰簲涓�涓瓧鑺�
        input wire [ 6:0] addra,
        input wire [31:0] dina,

        input  wire        clkb,
        input  wire        enb,
        input  wire [ 6:0] addrb,
        output reg  [31:0] doutb
    );

    reg [31:0] mem[0:127];

    // A 绔彛鍐欙紙鎸夊瓧鑺傛帺鐮侊級
    always @(posedge clka) begin
        if (ena) begin
            if (wea[0])
                mem[addra][7:0] <= dina[7:0];
            if (wea[1])
                mem[addra][15:8] <= dina[15:8];
            if (wea[2])
                mem[addra][23:16] <= dina[23:16];
            if (wea[3])
                mem[addra][31:24] <= dina[31:24];
        end
    end

    // B 绔彛璇伙紙鍐欎紭鍏堬細鑻ュ悓鏃跺啓鍚屼竴鍦板潃锛岃緭鍑哄啓鍏ュ悗鐨勫畬鏁存暟鎹級
    always @(posedge clkb) begin
        if (enb) begin
            if (ena && (wea != 4'b0) && (addra == addrb)) begin
                // 鍚堝苟鏃у瓨鍌ㄥ�间笌鏂板啓鏁版嵁锛堝啓浼樺厛锛�
                doutb <= {wea[3] ? dina[31:24] : mem[addrb][31:24], wea[2] ? dina[23:16] : mem[addrb][23:16], wea[1] ? dina[15:8] : mem[addrb][15:8], wea[0] ? dina[7:0] : mem[addrb][7:0]};
            end
            else begin
                doutb <= mem[addrb];
            end
        end
    end

endmodule




//-----------------------------------------------------------------------------
// tagv_ram: 128x21 鍗曠鍙� RAM (8-bank L1: 128 sets)
//-----------------------------------------------------------------------------
// module tagv_ram (
//     input  wire        clka,
//     input  wire        ena,
//     input  wire [0:0]  wea,
//     input  wire [7:0]  addra,
//     input  wire [20:0] dina,
//     output reg  [20:0] douta
// );

//     reg [20:0] mem [0:255];

//     always @(posedge clka) begin
//         if (ena) begin
//             douta <= mem[addra];
//             if (wea[0]) begin
//                 mem[addra] <= dina;
//             end
//         end
//     end

// endmodule


// =====================================================
// tagv_ram锛�21 浣嶅啓浼樺厛鍙岀鍙� RAM (L1: 128 sets, 7-bit addr)
// =====================================================
module tagv_ram (
        input wire        clka,
        input wire        ena,
        input wire [ 0:0] wea,
        input wire [ 6:0] addra,
        input wire [20:0] dina,

        input  wire        clkb,
        input  wire        enb,
        input  wire [ 6:0] addrb,
        output reg  [20:0] doutb
    );

    reg [20:0] mem[0:127];

    // A 绔彛鍐�
    always @(posedge clka) begin
        if (ena && wea[0]) begin
            mem[addra] <= dina;
        end
    end

    // B 绔彛璇伙紙鍐欎紭鍏堬級
    always @(posedge clkb) begin
        if (enb) begin
            if (ena && wea[0] && (addra == addrb))
                doutb <= dina;  // 鍐欏悓涓�鍦板潃锛岀洿鎺ヨ緭鍑哄啓鏁版嵁
            else
                doutb <= mem[addrb];
        end
    end

endmodule

`ifndef L2_CACHE_ARRAY_BEHAVIORAL_RAM_V
`define L2_CACHE_ARRAY_BEHAVIORAL_RAM_V

        module l2_data_bank_ram (
                input wire        clka,
                input wire        ena,
                input wire [ 3:0] wea,
                input wire [ 8:0] addra,
                input wire [31:0] dina,

                input  wire        clkb,
                input  wire        enb,
                input  wire [ 8:0] addrb,
                output reg  [31:0] doutb
            );

            reg [31:0] mem[0:511];

            always @(posedge clka) begin
                if (ena) begin
                    if (wea[0])
                        mem[addra][7:0] <= dina[7:0];
                    if (wea[1])
                        mem[addra][15:8] <= dina[15:8];
                    if (wea[2])
                        mem[addra][23:16] <= dina[23:16];
                    if (wea[3])
                        mem[addra][31:24] <= dina[31:24];
                end
            end

            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && (wea != 4'b0) && (addra == addrb)) begin
                        doutb <= {wea[3] ? dina[31:24] : mem[addrb][31:24],
                                  wea[2] ? dina[23:16] : mem[addrb][23:16],
                                  wea[1] ? dina[15:8] : mem[addrb][15:8],
                                  wea[0] ? dina[7:0] : mem[addrb][7:0]};
                    end
                    else begin
                        doutb <= mem[addrb];
                    end
                end
            end

        endmodule

        module l2_tagv_ram (
                input wire        clka,
                input wire        ena,
                input wire [ 0:0] wea,
                input wire [ 8:0] addra,
                input wire [19:0] dina,

                input  wire        clkb,
                input  wire        enb,
                input  wire [ 8:0] addrb,
                output reg  [19:0] doutb
            );

            reg [19:0] mem[0:511];

            always @(posedge clka) begin
                if (ena && wea[0]) begin
                    mem[addra] <= dina;
                end
            end

            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea[0] && (addra == addrb))
                        doutb <= dina;
                    else
                        doutb <= mem[addrb];
                end
            end

        endmodule

`endif
        module rob_metadata_bram (
                input  wire        clka,
                input  wire        ena,
                input  wire        wea,
                input  wire [ 5:0] addra,
                input  wire [99:0] dina,
                input  wire        clkb,
                input  wire        enb,
                input  wire [ 5:0] addrb,
                output reg  [99:0] doutb
            );

            reg [99:0] mem [0:15];

            always @(posedge clka) begin
                if (ena && wea)
                    mem[addra] <= dina;
            end

            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea && (addra == addrb))
                        doutb <= dina;
                    else
                        doutb <= mem[addrb];
                end
            end

        endmodule

        module rob_writeback_bram (
                input  wire        clka,
                input  wire        ena,
                input  wire        wea,
                input  wire [ 5:0] addra,
                input  wire [38:0] dina,
                input  wire        clkb,
                input  wire        enb,
                input  wire [ 5:0] addrb,
                output reg  [38:0] doutb
            );

            reg [38:0] mem [0:15];

            always @(posedge clka) begin
                if (ena && wea)
                    mem[addra] <= dina;
            end

            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea && (addra == addrb))
                        doutb <= dina;
                    else
                        doutb <= mem[addrb];
                end
            end

        endmodule


        module btb_bram (
                input  wire         clka,
                input  wire         ena,
                input  wire [0:0]   wea,
                input  wire [5:0]   addra,
                input  wire [227:0] dina,
                input  wire         clkb,
                input  wire         enb,
                input  wire [5:0]   addrb,
                output reg  [227:0] doutb
            );

            reg [227:0] mem [0:63];    // 64 entries, 228-bit wide

            // Port A: write on rising edge when ena & wea
            always @(posedge clka) begin
                if (ena && wea[0]) begin
                    mem[addra] <= dina;
                end
            end

            // Port B: read with write-first collision handling
            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea[0] && (addra == addrb)) begin
                        doutb <= dina;          // write-first: output new data
                    end
                    else begin
                        doutb <= mem[addrb];
                    end
                end
            end

        endmodule


        module pht_bram (
                input  wire       clka,
                input  wire       ena,
                input  wire [0:0] wea,
                input  wire [7:0] addra,
                input  wire [1:0] dina,
                input  wire       clkb,
                input  wire       enb,
                input  wire [7:0] addrb,
                output reg  [1:0] doutb
            );

            reg [1:0] mem [0:255];    // 256 entries, 2-bit wide

            // Port A: write on rising edge when ena & wea
            always @(posedge clka) begin
                if (ena && wea[0]) begin
                    mem[addra] <= dina;
                end
            end

            // Port B: read with write-first collision handling
            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea[0] && (addra == addrb)) begin
                        doutb <= dina;          // write-first: output new data
                    end
                    else begin
                        doutb <= mem[addrb];
                    end
                end
            end

        endmodule


        module ins_fifo_bank_bram (
                input  wire         clka,
                input  wire         ena,
                input  wire [0:0]   wea,
                input  wire [3:0]   addra,
                input  wire [101:0] dina,

                input  wire         clkb,
                input  wire         enb,
                input  wire [3:0]   addrb,
                output reg  [101:0] doutb
            );

            reg [101:0] mem [0:15];

            // A鍙ｅ悓姝ュ啓
            always @(posedge clka) begin
                if (ena && wea[0])
                    mem[addra] <= dina;
            end

            // B鍙ｅ悓姝ヨ锛屽悓鍧�璇诲啓鏃惰繑鍥炴柊鍐欏叆鐨勬暟鎹�
            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea[0] && (addra == addrb))
                        doutb <= dina;
                    else
                        doutb <= mem[addrb];
                end
            end

        endmodule

        module branch_id_bram (
                input  wire         clka,
                input  wire         ena,
                input  wire [0:0]   wea,
                input  wire [4:0]   addra,
                input  wire [95:0] dina,

                input  wire         clkb,
                input  wire         enb,
                input  wire [4:0]   addrb,
                output reg  [95:0] doutb
            );

            reg [95:0] mem [31:0];

            // A鍙ｅ悓姝ュ啓
            always @(posedge clka) begin
                if (ena && wea[0])
                    mem[addra] <= dina;
            end

            // B鍙ｅ悓姝ヨ锛屽悓鍧�璇诲啓鏃惰繑鍥炴柊鍐欏叆鐨勬暟鎹�
            always @(posedge clkb) begin
                if (enb) begin
                    if (ena && wea[0] && (addra == addrb))
                        doutb <= dina;
                    else
                        doutb <= mem[addrb];
                end
            end

        endmodule

        module cam_rmt_valid_copy_lutram (
                input  wire [ 4:0] a,
                input  wire [127:0] d,
                input  wire [ 4:0] dpra,
                input  wire        clk,
                input  wire        we,
                output wire [127:0] dpo
            );

            reg [127:0] mem[31:0];

            always @(posedge clk) begin
                if (we)
                    mem[a] <= d;
            end

            assign dpo = mem[dpra];

        endmodule


        module id_rename_payload_bram (
                input  wire         clka,
                input  wire         ena,
                input  wire [0:0]   wea,
                input  wire [0:0]   addra,
                input  wire [210:0] dina,
                input  wire         clkb,
                input  wire         enb,
                input  wire [0:0]   addrb,
                output reg  [210:0] doutb
            );

            reg [210:0] mem [0:1];

            always @(posedge clka) begin
                if (ena && wea[0])
                    mem[addra[0]] <= dina;
            end

            always @(posedge clkb) begin
                if (enb) begin
                    doutb <= mem[addrb[0]];
                end
            end

        endmodule

        module allocbid_rename_payload_bram (
                input  wire         clka,
                input  wire         ena,
                input  wire [0:0]   wea,
                input  wire [0:0]   addra,
                input  wire [215:0] dina,
                input  wire         clkb,
                input  wire         enb,
                input  wire [0:0]   addrb,
                output reg  [215:0] doutb
            );

            reg [215:0] mem [0:1];

            always @(posedge clka) begin
                if (ena && wea[0])
                    mem[addra[0]] <= dina;
            end

            always @(posedge clkb) begin
                if (enb) begin
                    doutb <= mem[addrb[0]];
                end
            end

        endmodule

        module rename_dispatch_payload_bram (
                input  wire         clka,
                input  wire         ena,
                input  wire [0:0]   wea,
                input  wire [0:0]   addra,
                input  wire [243:0] dina,
                input  wire         clkb,
                input  wire         enb,
                input  wire [0:0]   addrb,
                output reg  [243:0] doutb
            );

            reg [243:0] mem [0:1];

            always @(posedge clka) begin
                if (ena && wea[0])
                    mem[addra[0]] <= dina;
            end

            always @(posedge clkb) begin
                if (enb)
                    doutb <= mem[addrb[0]];
            end

        endmodule



        module alu_iq_lutram_16x52 (
                input  wire [ 3:0] a,
                input  wire [51:0] d,
                input  wire [ 3:0] dpra,
                input  wire        clk,
                input  wire        we,
                output wire [51:0] dpo
            );

            reg [51:0] mem[0:15];

            always @(posedge clk) begin
                if (we)
                    mem[a] <= d;
            end

            assign dpo = mem[dpra];

        endmodule

        module lsu_issue_queue_lutram_16x67 (
                input  wire [ 3:0] a,
                input  wire [66:0] d,
                input  wire [ 3:0] dpra,
                input  wire        clk,
                input  wire        we,
                output wire [66:0] dpo
            );

            reg [66:0] mem[0:15];

            always @(posedge clk) begin
                if (we)
                    mem[a] <= d;
            end

            assign dpo = mem[dpra];

        endmodule

        module  fast_issue_queue_lutram_46x16 (
                input  wire [ 3:0] a,
                input  wire [45:0] d,
                input  wire [ 3:0] dpra,
                input  wire        clk,
                input  wire        we,
                output wire [45:0] dpo
            );

            reg [45:0] mem[0:15];

            always @(posedge clk) begin
                if (we)
                    mem[a] <= d;
            end

            assign dpo = mem[dpra];

        endmodule

        module  md_iq_lutram_16x25 (
                input  wire [ 3:0] a,
                input  wire [24:0] d,
                input  wire [ 3:0] dpra,
                input  wire        clk,
                input  wire        we,
                output wire [24:0] dpo
            );

            reg [24:0] mem[0:15];

            always @(posedge clk) begin
                if (we)
                    mem[a] <= d;
            end

            assign dpo = mem[dpra];

        endmodule

        module  privilege_issue_queue_lutram_16x55 (
                input  wire [ 3:0] a,
                input  wire [54:0] d,
                input  wire [ 3:0] dpra,
                input  wire        clk,
                input  wire        we,
                output wire [54:0] dpo
            );

            reg [54:0] mem[0:15];

            always @(posedge clk) begin
                if (we)
                    mem[a] <= d;
            end

            assign dpo = mem[dpra];

        endmodule
`endif
