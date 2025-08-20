module execute_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        ex_fire,
    input  wire [31:0] r_alu_src1,
    input  wire [31:0] r_alu_src2,
    input  wire [1:0]  ex_result_sel,
    input  wire        mmd_is_signed,
    input  wire        mul_need_hi,

    input  wire        have_any_flush,
    
    input  wire [31:0] alu_result,
    output wire [31:0] ex_result,

    output wire        execute_finish
);

    wire [31:0] mul_result_low;
    wire [31:0] mul_result_high;

    wire [31:0] div_result;
    wire [31:0] mod_result;
    wire [ 5:0] div_cnt;
    wire        div_busy;
    reg         div_start;
    wire        div_done;
    reg         div_done_r;
    reg  [31:0] div_result_r;
    reg  [31:0] mod_result_r;

    // MUL
    mul u_mul(
        .a_in (r_alu_src1),
        .b_in (r_alu_src2),
        .is_signed (mmd_is_signed),
        .c_low (mul_result_low),
        .c_high (mul_result_high)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div_start <= 1'b0;
        end
        else if (div_done || div_done_r || div_cnt==6'd31) begin
            div_start <= 1'b0;
        end
        else if (ex_result_sel[1]) begin
            div_start <= 1'b1;
        end
        else begin
            div_start <= 1'b0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div_done_r <= 1'b0;
        end
        else if (ex_fire) begin
            div_done_r <= 1'b0;
        end
        else if (div_done) begin
            div_done_r <= 1'b1;
        end
        else begin
            div_done_r <= div_done_r;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div_result_r <= 32'b0;
            mod_result_r <= 32'b0;
        end
        else if (ex_fire) begin
            div_result_r <= 32'b0;
            mod_result_r <= 32'b0;
        end
        else if (div_done) begin
            div_result_r <= div_result;
            mod_result_r <= mod_result;
        end
        else begin
            div_result_r <= div_result_r;
            mod_result_r <= mod_result_r;
        end
    end

    // DIV & MOD
    div u_div(
        .clk        (clk            ),
        .reset      (reset          ),
        .start      (div_start      ),
        .a          (r_alu_src1    ),
        .b          (r_alu_src2    ),
        .is_signed  (mmd_is_signed ),
        .ex_fire    (ex_fire        ),

        .have_any_flush (have_any_flush),

        .q          (div_result     ),
        .r          (mod_result     ),
        .busy       (div_busy       ),
        .done       (div_done       ),
        .cnt        (div_cnt        )
    );

    assign ex_result = ({32{ex_result_sel==2'b01 &&  mul_need_hi}} & mul_result_high ) |
                       ({32{ex_result_sel==2'b01 && !mul_need_hi}} & mul_result_low  ) |
                       ({32{ex_result_sel==2'b10}} & div_result_r ) |
                       ({32{ex_result_sel==2'b11}} & mod_result_r ) |
                       ({32{ex_result_sel==2'b00}} & alu_result   ) ;

    assign execute_finish = !ex_result_sel[1] || div_done_r ;


endmodule