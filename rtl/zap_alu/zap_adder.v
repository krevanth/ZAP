/*
 * A simple 32-bit adder.
 */

`default_nettype none

module zap_adder
(
        input   wire [31:0] i_op1,
        input   wire [31:0] i_op2,
        input   wire        i_cin,
        output  wire [32:0] o_sum
);
assign o_sum = i_op1 + i_op2 + i_cin;
endmodule
