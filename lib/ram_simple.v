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

/*
 * A simple RAM that maps to FPGA BRAM resources.
 */

module ram_simple #(
        parameter WIDTH = 32,
        parameter DEPTH = 32
)
(
        input wire                          i_clk,

        input wire                          i_wr_en,
        input wire                          i_rd_en,

        input wire [WIDTH-1:0]              i_wr_data,
        input wire[$clog2(DEPTH)-1:0]       i_wr_addr,

        input wire [$clog2(DEPTH)-1:0]      i_rd_addr,
        output reg [WIDTH-1:0]              o_rd_data
);

reg [WIDTH-1:0] mem [DEPTH-1:0];

// Initialize block RAM to ZERO.
initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem[i] = {WIDTH{1'd0}};
end

always @ (posedge i_clk)
begin
        if ( i_rd_en )
                o_rd_data <= mem [ i_rd_addr ];
end

always @ (posedge i_clk)
begin
        if ( i_wr_en )  
                mem [ i_wr_addr ] <= i_wr_data;
end

endmodule
