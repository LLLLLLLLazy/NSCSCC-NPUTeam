module perf_stat(
    input             clk,
    input             rst_n,
    input             valid_instr,
    input             ex,
    input             bubble,
    input   [7:0]     icache_stall_count_perf,
    input             icache_is_uncached_perf,
    input   [7:0]     dcache_stall_count_perf,
    input             dcache_is_uncached_perf,
    input             dcache_req_perf,
    input             br_taken_pred_perf,
    input             br_correct_perf,
    input             br_tag_hi_unmatch_perf,
    input             is_br_perf,
    input             is_jirl_perf,
    input             pht_taken_perf
);
    (*mark_debug = "true"*) reg     [31:0]          cycles;
    (*mark_debug = "true"*) reg     [31:0]          instrs;
    reg     [63:0]          exceptions;
    (*mark_debug = "true"*) reg     [31:0]          icache_uncached_count;
    (*mark_debug = "true"*) reg     [31:0]          icache_uncached_total_cycles;
    (*mark_debug = "true"*) reg     [31:0]          icache_miss_count;
    (*mark_debug = "true"*) reg     [31:0]          icache_miss_total_cycles;
    (*mark_debug = "true"*) reg     [31:0]          dcache_visit_count;
    (*mark_debug = "true"*) reg     [31:0]          dcache_uncached_count;
    (*mark_debug = "true"*) reg     [31:0]          dcache_uncached_total_cycles;
    (*mark_debug = "true"*) reg     [31:0]          dcache_miss_count;
    (*mark_debug = "true"*) reg     [31:0]          dcache_miss_total_cycles;
    (*mark_debug = "true"*) reg     [31:0]          br_count;
    (*mark_debug = "true"*) reg     [31:0]          jirl_count;
    (*mark_debug = "true"*) reg     [31:0]          pht_correct_count;
    (*mark_debug = "true"*) reg     [31:0]          br_correct_count;
    (*mark_debug = "true"*) reg     [31:0]          br_tag_hi_unmatch_count;
    (*mark_debug = "true"*) reg     [31:0]          br_taken_count;
    always @(posedge clk)begin
        if(!rst_n)
            cycles <= 0;
        else cycles <= cycles + 1;
    end
    always @(posedge clk)begin
        if(!rst_n)
            instrs <= 0;
        else if(valid_instr)
            instrs <= instrs + 1;
    end
    always @(posedge clk)begin
        if(!rst_n)
            exceptions <= 0;
        else if(ex)
            exceptions <= exceptions + 1;
    end
    always @(posedge clk)begin
        if(!rst_n)begin
            icache_uncached_count <= 0;
            icache_uncached_total_cycles <= 0;
        end else if(valid_instr && icache_is_uncached_perf)begin
            icache_uncached_count <= icache_uncached_count + 1;
            icache_uncached_total_cycles <= icache_uncached_total_cycles + icache_stall_count_perf;
        end
    end
    always @(posedge clk)begin
        if(!rst_n)begin
            icache_miss_count <= 0;
            icache_miss_total_cycles <= 0;
        end else if(valid_instr && !icache_is_uncached_perf && (|icache_stall_count_perf))begin
            icache_miss_count <= icache_miss_count + 1;
            icache_miss_total_cycles <= icache_miss_total_cycles + icache_stall_count_perf;
        end
    end
    always @(posedge clk)begin
        if(!rst_n)begin
            dcache_visit_count <= 0;
        end else if(valid_instr && dcache_req_perf)begin
            dcache_visit_count <= dcache_visit_count + 1;
        end
    end
    always @(posedge clk)begin
        if(!rst_n)begin
            dcache_uncached_count <= 0;
            dcache_uncached_total_cycles <= 0;
        end else if(valid_instr && dcache_req_perf && dcache_is_uncached_perf)begin
            dcache_uncached_count <= dcache_uncached_count + 1;
            dcache_uncached_total_cycles <= dcache_uncached_total_cycles + dcache_stall_count_perf;
        end
    end
    always @(posedge clk)begin
        if(!rst_n)begin
            dcache_miss_count <= 0;
            dcache_miss_total_cycles <= 0;
        end else if(valid_instr && dcache_req_perf && !dcache_is_uncached_perf && (|dcache_stall_count_perf))begin
            dcache_miss_count <= dcache_miss_count + 1;
            dcache_miss_total_cycles <= dcache_miss_total_cycles + dcache_stall_count_perf;
        end
    end

    
    always @(posedge clk)begin
        if(!rst_n)
            br_count<=0;
        else if(is_br_perf && valid_instr)
            br_count<=br_count+1;
    end
    always @(posedge clk)begin
        if(!rst_n)
            jirl_count<=0;
        else if(is_jirl_perf && valid_instr)
            jirl_count<=jirl_count+1;
    end
    always @(posedge clk)begin
        if(!rst_n)
            br_correct_count <= 0;
        else if(is_br_perf && valid_instr && br_correct_perf)
            br_correct_count <= br_correct_count + 1;
    end
    always @(posedge clk)begin
        if(!rst_n)
            br_tag_hi_unmatch_count <= 0;
        else if(is_br_perf && valid_instr && br_tag_hi_unmatch_perf)
            br_tag_hi_unmatch_count <= br_tag_hi_unmatch_count + 1;
    end
    wire br_taken = br_correct_perf == br_taken_pred_perf;
    always @(posedge clk)begin
        if(!rst_n)
            br_taken_count <= 0;
        else if(is_br_perf && valid_instr && br_correct_perf == br_taken_pred_perf)
            br_taken_count <= br_taken_count + 1;
    end

    always @(posedge clk)begin
        if(!rst_n)
            pht_correct_count <= 0;
        else if(is_br_perf && valid_instr && (br_taken == pht_taken_perf))
            pht_correct_count <= pht_correct_count + 1;
    end
endmodule
