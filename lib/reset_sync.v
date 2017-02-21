///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (C) 2016,2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
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
// reset_sync.v
//
// Summary --
// Reset synchronizer.
//
// Detail --
// A dual flip-flop reset synchronizer. Treats all resets as active high.
// The output reset is guaranteed to turn off on a rising edge of the clock.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module reset_sync
(
        input wire          i_clk,  // Clock.
        input wire          i_reset,// Dirty reset.

        output wire         o_reset // Clean reset.
);

///////////////////////////////////////////////////////////////////////////////

localparam RESET_ON  = 1'd1;
localparam RESET_OFF = 1'd0;

///////////////////////////////////////////////////////////////////////////////

// Reset buffers.
reg flop1, flop2;

///////////////////////////////////////////////////////////////////////////////

// Tie second flop to output.
assign o_reset = flop2;

///////////////////////////////////////////////////////////////////////////////

//
// Model a dual flop synchronizer with asynchronous active 
// high reset. The input of the synchronizer is tied to
// RESET_OFF which synchronously travels to the output.
// The async reset pins of both the flops are tied to the
// dirty reset.
//

always @ (posedge i_clk or posedge i_reset) 
begin:rst_sync
        if ( i_reset )
        begin
                // The design sees o_reset = 1.
                flop2 <= RESET_ON;
                flop1 <= RESET_ON;
        end       
        else
        begin
                // o_reset is turned off eventually.
                flop2 <= flop1;
                flop1 <= RESET_OFF; // Turn off global reset.
        end 
end

///////////////////////////////////////////////////////////////////////////////

endmodule // reset_sync.v
