///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
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
// ones.counter.v
//
// Detail --
// The file name is a little misleading. Not only does it count ones but
// also calculates the address offset since each '1' corresponds to a 4 byte
// memory register, the number of ones is multiplied by 4. This is used by
// the LDM and STM state machine.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none

module ones_counter 
(
        input wire [15:0]    i_word,   // Register list.
        output reg [11:0]    o_offset  // Address Offset.
);

///////////////////////////////////////////////////////////////////////////////

always @*
begin: blk1
        integer i;

        o_offset = 0;

        // Counter number of ones.
        for(i=0;i<16;i=i+1)
                o_offset = o_offset + i_word[i];

        // Since LDM and STM occur only on 4 byte regions, compute the
        // net offset.
        o_offset = (o_offset << 2); // Multiply by 4.
end

///////////////////////////////////////////////////////////////////////////////

endmodule // ones_counter.v
