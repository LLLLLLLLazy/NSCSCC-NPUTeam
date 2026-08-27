module popcount32 (
    input  [31:0] data,
    output [ 5:0] count
);


    function [2:0] lut6_pop(input [5:0] d);
        lut6_pop = d[0] + d[1] + d[2] + d[3] + d[4] + d[5];
    endfunction

    wire [2:0] c0 = lut6_pop(data[5:0]);
    wire [2:0] c1 = lut6_pop(data[11:6]);
    wire [2:0] c2 = lut6_pop(data[17:12]);
    wire [2:0] c3 = lut6_pop(data[23:18]);
    wire [2:0] c4 = lut6_pop(data[29:24]);
    wire [1:0] c5 = data[31] + data[30];

    assign count = {1'b0, c0} + {1'b0, c1} + {1'b0, c2} + {1'b0, c3} + {1'b0, c4} + {2'b0, c5};



endmodule


module popcount16 (
    input  [15:0] data,
    output [ 4:0] count
);


    function [2:0] lut6_pop(input [5:0] d);
        lut6_pop = d[0] + d[1] + d[2] + d[3] + d[4] + d[5];
    endfunction

    wire [2:0] c0 = lut6_pop(data[5:0]);
    wire [2:0] c1 = lut6_pop(data[11:6]);
    wire [2:0] c2 = data[12] + data[13] + data[14] + data[15];

    assign count = {1'b0, c0} + {1'b0, c1} + {1'b0, c2};



endmodule
