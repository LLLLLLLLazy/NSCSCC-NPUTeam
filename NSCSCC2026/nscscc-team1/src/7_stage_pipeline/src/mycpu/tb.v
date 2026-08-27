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
    wire [31:0] quot, rem;
    assign quot               = $signed(s_axis_dividend_tdata) / $signed(s_axis_divisor_tdata);
    assign rem                = $signed(s_axis_dividend_tdata) % $signed(s_axis_divisor_tdata);
    assign m_axis_dout_tdata  = {quot, rem};
    assign m_axis_dout_tvalid = 1'b1;


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

    wire [31:0] quot, rem;
    assign quot               = $unsigned(s_axis_dividend_tdata) / $unsigned(s_axis_divisor_tdata);
    assign rem                = $unsigned(s_axis_dividend_tdata) % $unsigned(s_axis_divisor_tdata);
    assign m_axis_dout_tdata  = {quot, rem};
    assign m_axis_dout_tvalid = 1'b1;


endmodule


module cpu_signed_multiplier (
    input  wire        CLK,
    input  wire [31:0] A,
    input  wire [31:0] B,
    output wire [63:0] P
);

    assign P = $signed(A) * $signed(B);

endmodule


module cpu_unsigned_multiplier (
    input  wire        CLK,
    input  wire [31:0] A,
    input  wire [31:0] B,
    output wire [63:0] P
);

    assign P = A * B;

endmodule


//-----------------------------------------------------------------------------
// data_bank_ram: 128x32 单端口 RAM，带字节写使能 (8-bank L1: 128 sets)
//-----------------------------------------------------------------------------
// module data_bank_ram (
//     input  wire        clka,
//     input  wire        ena,
//     input  wire [3:0]  wea,
//     input  wire [7:0]  addra,
//     input  wire [31:0] dina,
//     output reg  [31:0] douta
// );

//     // 存储体
//     reg [31:0] mem [0:255];

//     // 读操作：地址锁存（防止地址变化时输出变化）
//     always @(posedge clka) begin
//         if (ena) begin
//             douta <= mem[addra];
//         end
//     end

//     // 写操作：按字节使能写入
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
// data_bank_ram：32 位写优先双端口 RAM (L1: 128 sets, 7-bit addr)
// =====================================================
module data_bank_ram (
    input wire        clka,
    input wire        ena,
    input wire [ 3:0] wea,    // 每 bit 对应一个字节
    input wire [ 6:0] addra,
    input wire [31:0] dina,

    input  wire        clkb,
    input  wire        enb,
    input  wire [ 6:0] addrb,
    output reg  [31:0] doutb
);

    reg [31:0] mem[0:127];

    // A 端口写（按字节掩码）
    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) mem[addra][7:0] <= dina[7:0];
            if (wea[1]) mem[addra][15:8] <= dina[15:8];
            if (wea[2]) mem[addra][23:16] <= dina[23:16];
            if (wea[3]) mem[addra][31:24] <= dina[31:24];
        end
    end

    // B 端口读（写优先：若同时写同一地址，输出写入后的完整数据）
    always @(posedge clkb) begin
        if (enb) begin
            if (ena && (wea != 4'b0) && (addra == addrb)) begin
                // 合并旧存储值与新写数据（写优先）
                doutb <= {wea[3] ? dina[31:24] : mem[addrb][31:24], wea[2] ? dina[23:16] : mem[addrb][23:16], wea[1] ? dina[15:8] : mem[addrb][15:8], wea[0] ? dina[7:0] : mem[addrb][7:0]};
            end else begin
                doutb <= mem[addrb];
            end
        end
    end

endmodule




//-----------------------------------------------------------------------------
// tagv_ram: 128x21 单端口 RAM (8-bank L1: 128 sets)
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
// tagv_ram：21 位写优先双端口 RAM (L1: 128 sets, 7-bit addr)
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

    // A 端口写
    always @(posedge clka) begin
        if (ena && wea[0]) begin
            mem[addra] <= dina;
        end
    end

    // B 端口读（写优先）
    always @(posedge clkb) begin
        if (enb) begin
            if (ena && wea[0] && (addra == addrb)) doutb <= dina;  // 写同一地址，直接输出写数据
            else doutb <= mem[addrb];
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
            if (wea[0]) mem[addra][7:0] <= dina[7:0];
            if (wea[1]) mem[addra][15:8] <= dina[15:8];
            if (wea[2]) mem[addra][23:16] <= dina[23:16];
            if (wea[3]) mem[addra][31:24] <= dina[31:24];
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            if (ena && (wea != 4'b0) && (addra == addrb)) begin
                doutb <= {wea[3] ? dina[31:24] : mem[addrb][31:24],
                          wea[2] ? dina[23:16] : mem[addrb][23:16],
                          wea[1] ? dina[15:8] : mem[addrb][15:8],
                          wea[0] ? dina[7:0] : mem[addrb][7:0]};
            end else begin
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
    input wire [17:0] dina,

    input  wire        clkb,
    input  wire        enb,
    input  wire [ 8:0] addrb,
    output reg  [17:0] doutb
);

    reg [17:0] mem[0:511];

    always @(posedge clka) begin
        if (ena && wea[0]) begin
            mem[addra] <= dina;
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            if (ena && wea[0] && (addra == addrb)) doutb <= dina;
            else doutb <= mem[addrb];
        end
    end

endmodule

`endif

`endif
