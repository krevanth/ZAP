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
// mem_inv_block.v
//
// Summary --
// Tag RAMs with single cycle clear.
//
// Detail -- 
// Use this to built single cycle clearing tag RAMs and TLBs for ZAP. For
// cache, use mem_ben_block. Single cycle clearing is done by implementing
// the valid bits using flip-flops. The main RAM is implemented using block
// RAM. The designer must ensure sufficient block RAM in the target part.
// 

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module mem_inv_block #(
        parameter DEPTH = 32,
        parameter WIDTH = 32   // Not including valid bit.
)(  

///////////////////////////////////////////////////////////////////////////////

        input wire                           i_clk,
        input wire                           i_reset,

        // Write data.
        input wire   [WIDTH-1:0]             i_wdata,

        // Write and read enable.
        input wire                           i_wen, 
        input wire                           i_ren,

        // Force write.
        input wire                           i_refresh, 

        // Invalidate entries in 1 cycle.
        input wire                           i_inv,

        // Read and write address.
        input wire   [$clog2(DEPTH)-1:0]     i_raddr, 
        input wire   [$clog2(DEPTH)-1:0]     i_waddr,

        // Read data and valid.
        output wire [WIDTH-1:0]              o_rdata,
        output reg                           o_rdav
);

///////////////////////////////////////////////////////////////////////////////

// Flops
reg [DEPTH-1:0] dav_ff;

// Nets
wire [$clog2(DEPTH)-1:0] addr_r;
wire en_r;

///////////////////////////////////////////////////////////////////////////////

assign addr_r = i_refresh ? i_waddr : i_raddr;
assign en_r   = i_refresh ? 1'd1    : i_ren;

///////////////////////////////////////////////////////////////////////////////

// Block RAM.
ram_simple #(.WIDTH(WIDTH), .DEPTH(DEPTH)) u_ram_simple (
        .i_clk     ( i_clk ),

        .i_wr_en   ( i_wen ),
        .i_rd_en   ( en_r ),

        .i_wr_data ( i_wdata ),
        .o_rd_data ( o_rdata ),

        .i_wr_addr ( i_waddr ),
        .i_rd_addr ( addr_r )
);

///////////////////////////////////////////////////////////////////////////////

// DAV flip-flop implementation.
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

///////////////////////////////////////////////////////////////////////////////

endmodule // mem_inv_block.v
