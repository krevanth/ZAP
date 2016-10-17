`default_nettype none
`include "config.vh"

// Filename --
// zap_shift_shifter.v 
//
// Author --
// Revanth Kamaraj
//
// Description --
// This module is an ARM compatible barrel shifter.

module zap_shift_shifter
#(
        parameter SHIFT_OPS = 5
)
(
        input  wire [31:0]                      i_source,
        input  wire [7:0]                       i_amount, // Ensures only lower byte is used.
        input  wire                             i_carry,
        input  wire [$clog2(SHIFT_OPS)-1:0]     i_shift_type,

        output reg [31:0]                       o_result,
        output reg                              o_carry
);

`include "shtype.vh"

always @*
begin
        // Prevent latch inference.
        o_result        = i_source;
        o_carry         = 0;

        case ( i_shift_type )
                LSL:    {o_carry, o_result} = {i_carry, i_source} << i_amount;
                LSR:    {o_result, o_carry} = {i_source, i_carry} >> i_amount;
                ASR:    {o_result, o_carry} = ($signed(($signed(i_source) << 1)|i_carry)) >> i_amount;

                ROR:
                begin
                        o_result = ( i_source >> i_amount[4:0] )  | ( i_source << (32 - i_amount[4:0] ) );                               
                        o_carry  = (i_amount[7:0] == 0) ? 
                                   i_carry  : ( (i_amount[4:0] == 0) ? i_source[31] : o_result[31] ); 
                end

                RORI, ROR_1:
                begin
                        // ROR #n (ROR_1)
                        o_result = ( i_source >> i_amount[4:0] )  | (i_source << (32 - i_amount[4:0] ) );
                        o_carry  = i_amount ? o_result[31] : i_carry; 
                end

                // ROR #0 becomes this.
                RRC:    {o_result, o_carry}        = {i_carry, i_source}; 
        endcase
end

endmodule
