// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_shift_shifter.v
// HDL          : Verilog-2001
// Module       : zap_shift_shifter
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// This module models an ARMv4 compatible shifter unit.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high reset
// Clock        : Core clock
// Depends      : --
// ----------------------------------------------------------------------------

`default_nettype none
module zap_shift_shifter
#(
        parameter SHIFT_OPS = 5
)
(
        // Source value.
        input  wire [31:0]                      i_source,

        // Shift amount.
        input  wire [7:0]                       i_amount, 

        // Carry in.
        input  wire                             i_carry,

        // Shift type.
        input  wire [$clog2(SHIFT_OPS)-1:0]     i_shift_type,

        // Output result and output carry.
        output reg [31:0]                       o_result,
        output reg                              o_carry
);

`include "zap_defines.vh"
`include "zap_localparams.vh"
`include "zap_functions.vh"

///////////////////////////////////////////////////////////////////////////////

always @*
begin
        // Prevent latch inference.
        o_result        = i_source;
        o_carry         = 0;

        case ( i_shift_type )

                // Logical shift left, logical shift right and 
                // arithmetic shift right.
                LSL:    {o_carry, o_result} = {i_carry, i_source} << i_amount;
                LSR:    {o_result, o_carry} = {i_source, i_carry} >> i_amount;
                ASR:    
                begin:blk1111
                        reg signed [32:0] res, res1;
                        res = {i_source, i_carry};
                        res1 = $signed(res) >>> i_amount;
                        {o_result, o_carry} = res1;
                end
//                        ($signed(($signed(i_source) << 1)|i_carry)) >> i_amount;

                ROR: // Rotate right.
                begin
                        o_result = ( i_source >> i_amount[4:0] )  | 
                                   ( i_source << (32 - i_amount[4:0] ) );                               
                        o_carry  = ( i_amount[7:0] == 0) ? 
                                     i_carry  : ( (i_amount[4:0] == 0) ? 
                                     i_source[31] : o_result[31] ); 
                end

                RORI, ROR_1:
                begin
                        // ROR #n (ROR_1)
                        o_result = ( i_source >> i_amount[4:0] )  | 
                                   (i_source << (32 - i_amount[4:0] ) );
                        o_carry  = i_amount ? o_result[31] : i_carry; 
                end

                // ROR #0 becomes this.
                RRC:    {o_result, o_carry}        = {i_carry, i_source}; 
        endcase
end

///////////////////////////////////////////////////////////////////////////////

endmodule // zap_shift_shifter.v
