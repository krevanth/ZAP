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
 * Use this to built single cycle clearing tag RAMs and TLBs for ZAP. For
 * cache, use mem_ben_block.
 */

module mem_inv_block #(
        parameter DEPTH = 32,
        parameter WIDTH = 32   // Not including valid bit.
)(  
        input wire                           i_clk,
        input wire                           i_reset,
        input wire   [WIDTH-1:0]             i_wdata,
        input wire                           i_wen, 
        input wire                           i_ren,
        input wire                           i_refresh, 
        input wire                           i_inv,
        input wire   [$clog2(DEPTH)-1:0]     i_raddr, 
        input wire   [$clog2(DEPTH)-1:0]     i_waddr,

        output reg [WIDTH-1:0]               o_rdata,
        output reg                           o_rdav
);

reg [WIDTH-1:0] mem_ff [DEPTH-1:0];
reg [DEPTH-1:0] dav_ff;

wire [$clog2(DEPTH)-1:0] addr_r;
wire en_r;

assign addr_r = i_refresh ? i_waddr : i_raddr;
assign en_r   = i_refresh ? 1'd1    : i_ren;

// Initialize block RAM to 0.
initial
begin: bkl1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem_ff[i] = 0;
       
end

always @ (posedge i_clk)
begin: block_ram
        if ( en_r )
                o_rdata <= mem_ff[ addr_r ];

        if ( i_wen )
                mem_ff [ i_waddr ] <= i_wdata;
end

always @ (posedge i_clk)
begin: flip_flops
        if ( i_reset | i_inv )
        begin
               dav_ff <=  {DEPTH{1'd0}};
               o_rdav <= 1'd0;
        end
        else
        begin
                if ( i_wen )
                        dav_ff [ i_waddr ] <= 1'd1;

                if ( en_r )
                        o_rdav <= dav_ff [ addr_r ]; 
        end
end

endmodule
