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
// ram_simple.v
//
// Summary --
// FPGA block RAM.
//
// Detail --
// RTL code that synthesizes to standard FPGA block RAM given reasonable
// dimensions. The designer must ensure enough block RAM in target.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module ram_simple #(
        parameter WIDTH = 32,
        parameter DEPTH = 32
)
(
        input wire                          i_clk,

        // Write and read enable.
        input wire                          i_wr_en,
        input wire                          i_rd_en,

        // Write data and address.
        input wire [WIDTH-1:0]              i_wr_data,
        input wire[$clog2(DEPTH)-1:0]       i_wr_addr,

        // Read address and data.
        input wire [$clog2(DEPTH)-1:0]      i_rd_addr,
        output reg [WIDTH-1:0]              o_rd_data
);

///////////////////////////////////////////////////////////////////////////////

// Memory array.
reg [WIDTH-1:0] mem [DEPTH-1:0];

///////////////////////////////////////////////////////////////////////////////

// Initialize block RAM to 0.
initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem[i] = {WIDTH{1'd0}};
end

///////////////////////////////////////////////////////////////////////////////

// Read logic.
always @ (posedge i_clk)
begin
        if ( i_rd_en )
                o_rd_data <= mem [ i_rd_addr ];
end

///////////////////////////////////////////////////////////////////////////////

// Write logic.
always @ (posedge i_clk)
begin
        if ( i_wr_en )  
                mem [ i_wr_addr ] <= i_wr_data;
end

///////////////////////////////////////////////////////////////////////////////

endmodule // ram_simple.v
