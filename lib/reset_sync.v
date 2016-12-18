/*
MIT License

Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

`default_nettype none
`include "config.vh"

module reset_sync
(
        input wire          i_clk,
        input wire          i_reset,

        output wire         o_reset
);

// Reset buffers.
reg flop1, flop2;

always @ (posedge i_clk or posedge i_reset) 
// Model 2 flops with asynchronous active high reset to 1.
begin
        if ( i_reset )
        begin
                // The design sees o_reset = 1.
                flop2 <= 1'd1;
                flop1 <= 1'd1;
        end       
        else
        begin
                // o_reset is turned off eventually.
                flop2 <= flop1;
                flop1 <= 1'd0; // Turn off global reset.
        end 
end

assign o_reset = flop2;

endmodule
