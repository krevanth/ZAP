`default_nettype none

module mult16x16 (
        input  wire signed [16:0] in1,
        input  wire signed [16:0] in2,
        output wire signed [63:0] out
);

assign out = in1 * in2;

endmodule
