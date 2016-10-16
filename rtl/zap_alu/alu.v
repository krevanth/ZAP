`default_nettype none

module alu (
        input wire [31:0] op1, op2, input wire cin, output wire [32:0] sum
);
        assign sum = op1 + op2 + cin;
endmodule
