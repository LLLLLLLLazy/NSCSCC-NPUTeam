module If_to_id_need_cancel (
    input  wire        clk,               // ????
    input  wire        rst,               // ??????
    input  wire        wb_ex,             // ??????
    input  wire        inst_sram_req,     // ??SRAM????
    input  wire        inst_sram_addr_ok, // ??SRAM????OK
    input  wire        inst_sram_data_ok, // ??SRAM????OK
    input wire         if_ready_go,
    input wire         id_allow_in,
    input wire         id_br_taken,
    input wire         pipline_is_not_stalled,
    input wire         pre_if_ready_go,
    input wire         if_allow_in,
    output wire [1:0]        id_need_cancel  ,   // ????ID?????.
    input wire id_ready_go,
    input wire exe_allow_in,
    input wire [31:0] if_pc,
    input wire [31:0] id_pc
);

    // ????
    localparam STATE_NORMAL     = 2'b0;  // ????         
    localparam STATE_NOT_NORMAL_one = 2'b1;  // ?????,????1?
    localparam STATE_NOT_NORMAL_two = 2'b10;
    // ???????
    reg [1:0]state_curr;  // ????
    reg [1:0]state_next;   // ????

    // (1) ?????????
    always @(posedge clk) begin
        if (rst) begin
            state_curr <= STATE_NORMAL;  // ?????????
        end else begin
            state_curr <= state_next;   // ????
        end
    end

    // (2) ????????
    always @(*) begin
        case(state_curr)
            STATE_NORMAL: begin
                if(id_br_taken==1'b1&&pipline_is_not_stalled && (if_ready_go || pre_if_ready_go && if_allow_in || if_pc != id_pc)  && id_ready_go && exe_allow_in)
                begin
                    state_next = STATE_NOT_NORMAL_two;
                end
                else if ((id_br_taken==1'b1&&pipline_is_not_stalled && exe_allow_in && id_ready_go)  ) begin
                    state_next = STATE_NOT_NORMAL_one;
                end
                else if(((inst_sram_req==1'b1&&inst_sram_addr_ok==1'b0))&&wb_ex==1'b1)
                begin
                    state_next = STATE_NOT_NORMAL_one;
                end
                else if(wb_ex==1'b1&&(inst_sram_addr_ok==1'b1 || inst_sram_req==1'b0)&&(if_ready_go && id_allow_in))
                begin
                    state_next = STATE_NOT_NORMAL_one;
                end
                else if(wb_ex==1'b1&&(inst_sram_addr_ok==1'b1 || inst_sram_req==1'b0))
                begin
                    state_next = STATE_NOT_NORMAL_two;
                end
                else
                begin
                    state_next = STATE_NORMAL;
                end
            end
            
            STATE_NOT_NORMAL_one: begin
                // ???OK???????
                if (!(if_ready_go==1'b0)&& id_allow_in&&wb_ex!=1'b1) begin
                    state_next = STATE_NORMAL;
                end
                else if (((if_ready_go && id_allow_in) || (inst_sram_req==1'b1&&inst_sram_addr_ok==1'b0))&&wb_ex==1'b1)
                begin
                    state_next = STATE_NOT_NORMAL_one;
                end
                else if(wb_ex==1'b1&&(inst_sram_addr_ok==1'b1 || inst_sram_req==1'b0))
                begin
                    state_next = STATE_NOT_NORMAL_two;
                end
                else
                begin
                    state_next = STATE_NOT_NORMAL_one;
                end
            end
            STATE_NOT_NORMAL_two:begin
                if (!(if_ready_go==1'b0)&& id_allow_in) begin
                    state_next = STATE_NOT_NORMAL_one;
                end
                else if( ((inst_sram_data_ok== 1'b1 || (inst_sram_req==1'b1&&inst_sram_addr_ok==1'b0)) && id_allow_in&&wb_ex==1'b1))
                begin
                    state_next = STATE_NOT_NORMAL_one;
                end
                else if(wb_ex==1'b1&&(inst_sram_addr_ok==1'b1 || inst_sram_req==1'b0))
                begin
                    state_next = STATE_NOT_NORMAL_two;
                end
                else
                begin
                    state_next = STATE_NOT_NORMAL_two;
                end
            end
        endcase
    end

   
   assign id_need_cancel = state_curr;
endmodule