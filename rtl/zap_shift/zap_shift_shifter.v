///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (c) 2016,2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 

///////////////////////////////////////////////////////////////////////////////

//
// Filename --
// zap_shift_shifter.v 
//
// Description --
// This module is an ARM compatible barrel shifter.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

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

`include "shtype.vh"

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
                ASR:    {o_result, o_carry} = 
                        ($signed(($signed(i_source) << 1)|i_carry)) >> i_amount;

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
