module perf_counter (
    input      clk                ,
    input      reset              ,

    input      dcache_miss        ,
    input      dcache_stall       ,
    input      icache_miss        ,
    input      icache_stall       ,
    input      data_hazard_stall  ,
    input      tlb_stall          ,
    input      commit_inst        ,
    input      br_inst            ,
    input      mem_inst           ,
    input      br_pre             ,
    input      br_pre_error       ,
    input      fifo_full          ,
    input      fifo_empty         ,
    input      double_inst        ,
    input      single_inst         
);

reg[31:0] dcache_miss_counter;
reg[31:0] dcache_stall_counter;
reg[31:0] icache_miss_counter;
reg[31:0] icache_stall_counter;
reg[31:0] tlb_stall_counter;
reg[31:0] data_hazard_stall_counter;
reg[31:0] commit_inst_counter;
reg[31:0] br_inst_counter;
reg[31:0] mem_inst_counter;
reg[31:0] br_pre_counter;
reg[31:0] br_pre_error_counter;
reg[31:0] fifo_full_counter;
reg[31:0] fifo_empty_counter;
reg[31:0] double_inst_counter;
reg[31:0] single_inst_counter;

always @(posedge clk) begin
    if (reset) begin
        dcache_miss_counter       <= 32'b0;
        dcache_stall_counter      <= 32'b0;
        icache_miss_counter       <= 32'b0;
        icache_stall_counter      <= 32'b0;
        data_hazard_stall_counter <= 32'b0;
        tlb_stall_counter         <= 32'b0;
        commit_inst_counter       <= 32'b0;
        br_inst_counter           <= 32'b0;
        mem_inst_counter          <= 32'b0;
        br_pre_counter            <= 32'b0;
        br_pre_error_counter      <= 32'b0;
        fifo_full_counter         <= 32'b0;
        fifo_empty_counter        <= 32'b0;
        double_inst_counter       <= 32'b0;
        single_inst_counter       <= 32'b0;
    end
    else begin
        if (dcache_miss) begin
            dcache_miss_counter <= dcache_miss_counter + 32'b1;
        end
        if (dcache_stall) begin
            dcache_stall_counter <= dcache_stall_counter + 32'b1;
        end
        if (icache_miss) begin
            icache_miss_counter <= icache_miss_counter + 32'b1;
        end
        if (icache_stall) begin
            icache_stall_counter <= icache_stall_counter + 32'b1;
        end
        if (data_hazard_stall) begin
            data_hazard_stall_counter <= data_hazard_stall_counter + 32'b1;
        end
        if (tlb_stall) begin
            tlb_stall_counter <= tlb_stall_counter + 32'b1;
        end
        if (commit_inst) begin
            if(double_inst) begin
                commit_inst_counter <= commit_inst_counter + 32'd2;
                double_inst_counter <= double_inst_counter + 32'b1;
            end
            else begin
                commit_inst_counter <= commit_inst_counter + 32'd1;
                single_inst_counter <= single_inst_counter + 32'b1;
            end
        end
        if (br_inst) begin
            br_inst_counter <= br_inst_counter + 32'b1;
        end
        if (mem_inst) begin
            mem_inst_counter <= mem_inst_counter + 32'b1;
        end
        if (br_pre) begin
            br_pre_counter <= br_pre_counter + 32'b1;
        end
        if (br_pre_error) begin
            br_pre_error_counter <= br_pre_error_counter + 32'b1;
        end
        if (fifo_full) begin
            fifo_full_counter <= fifo_full_counter + 32'b1;
        end
        if (fifo_empty) begin
            fifo_empty_counter <= fifo_empty_counter + 32'b1;
        end
    end
end

endmodule
