///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (C) 2016,2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// Of this software and associated documentation files (the "Software"), to deal
// In the Software without restriction, including without limitation the rights
// To use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// Copies of the Software, and to permit persons to whom the Software is
// Furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// Copies or substantial portions of the Software.
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
// alu.v
//
// Summary --
// A standard 32-bit full adder.
//
// Detail --
// This is a 32-bit full adder with a 33-bit output, the MSB which is carry.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module alu (
        input  wire [31:0] op1, // Input A
        input  wire [31:0] op2, // Input B
        input  wire        cin, // Carry In.
        output wire [32:0] sum  // Sum with MSB bit as carry out.
);

///////////////////////////////////////////////////////////////////////////////

        // Operation.
        assign sum = op1 + op2 + cin;

///////////////////////////////////////////////////////////////////////////////

endmodule // alu.v

