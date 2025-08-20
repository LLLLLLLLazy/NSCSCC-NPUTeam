module pc_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        if_fire,
    input  wire        need_nop,
    input  wire        br_taken,
    input  wire [31:0] br_target,
    input  wire        ertn_flush_from_wb,
    input  wire [31:0] pc_from_era,
    input  wire [15:0] wb_ex_info,
    input  wire [31:0] eentry,
    input  wire [31:0] tlbrentry,
    input  wire [31:0] info_from_bp,

    input  wire        refetch_flush,
    input  wire [31:0] pc_from_id,
    input  wire [31:0] pc_from_if,
    input  wire        id_valid,
    input  wire        if_valid,

    output reg  [31:0] pc,
    output wire        pc_ready
);

    parameter ECODE_TLBR   = 6'h3f;

    // 优先级？
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'h1c000000; 
        end
        else if (refetch_flush && id_valid) begin
            pc <= pc_from_id; 
        end
        else if (refetch_flush && if_valid) begin
            pc <= pc_from_if;
        end
        else if (refetch_flush) begin
            pc <= pc;
        end
        else if (wb_ex_info[15:10]==ECODE_TLBR) begin
            pc <= tlbrentry ;
        end
        else if (wb_ex_info[0]) begin
            pc <= eentry;
        end
        else if (ertn_flush_from_wb) begin
            pc <= pc_from_era;
        end
        else if (br_taken) begin
            pc <= br_target ;
        end
        else if (if_fire && info_from_bp[31] && info_from_bp[30]) begin
            pc <= {info_from_bp[29:0], 2'b0};
        end
        else if (if_fire) begin
            pc <= pc + 32'h00000004;
        end
        else begin
            pc <= pc;
        end
    end

    assign pc_ready =  !(reset ||
                        (refetch_flush) ||
                        (wb_ex_info[15:10]==ECODE_TLBR) ||
                        (wb_ex_info[0]) ||
                        (ertn_flush_from_wb) ||
                        (br_taken) );

endmodule