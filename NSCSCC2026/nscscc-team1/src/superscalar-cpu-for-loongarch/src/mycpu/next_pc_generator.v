module next_pc_generator(
        input wire [31:0] pc,
        input wire [255:0] predict_pc,
        input wire [7:0] predict_taken,

        output wire [3:0] valid_count,
        output wire [31:0] final_predict_pc
    );

    wire [7:0] pc_mask;
    assign pc_mask = 8'b1111_1111 << pc[4:2];

    wire [7:0] taken_mask;

    assign taken_mask = predict_taken & pc_mask;

    wire [7:0] taken_onehot;

    // Select the earliest predicted-taken slot at or after the current PC.
    // When taken_mask is zero this expression remains zero, so the default
    // case below selects the end of the fetch line without underflowing the
    // valid instruction count.
    assign taken_onehot = taken_mask & (~taken_mask + 8'd1);

    reg [31:0] select_target_address;
    reg [3:0] select_count;

    always @(*) begin
        case(taken_onehot)
            8'b0000_0001 : begin
                select_target_address = predict_pc[31:0];
                select_count = 4'd1- pc[4:2];
            end
            8'b0000_0010 : begin
                select_target_address = predict_pc[63:32];
                select_count = 4'd2- pc[4:2];
            end
            8'b0000_0100 : begin
                select_target_address = predict_pc[95:64];
                select_count = 4'd3- pc[4:2];
            end
            8'b0000_1000 : begin
                select_target_address = predict_pc[127:96];
                select_count = 4'd4- pc[4:2];
            end
            8'b0001_0000 : begin
                select_target_address = predict_pc[159:128];
                select_count = 4'd5- pc[4:2];
            end
            8'b0010_0000 : begin
                select_target_address = predict_pc[191:160];
                select_count = 4'd6- pc[4:2];
            end
            8'b0100_0000 : begin
                select_target_address = predict_pc[223:192];
                select_count = 4'd7- pc[4:2];
            end
            8'b1000_0000 : begin
                select_target_address = predict_pc[255:224];
                select_count = 4'd8- pc[4:2];
            end
            default : begin
                select_target_address = predict_pc[255:224];
                select_count = 4'd8- pc[4:2];
            end
        endcase
    end

    assign valid_count = select_count ;
    assign final_predict_pc = select_target_address ;









endmodule
