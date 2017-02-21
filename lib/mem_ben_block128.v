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
// mem_ben_block128.v
//
// Summary --
// Block RAM with byte enables.
//
// Detail --
// A 128-bit wide x N deep block RAM with byte wise enable. Maps efficiently
// to native FPGA block RAM. The designer must ensure that the target part
// contains enough block RAM resources.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module mem_ben_block128 #(
        parameter  DEPTH  = 32
)(
        // RAM Clock.
        input   wire                           i_clk,

        // Byte Write Enable for 16 bytes in 128-bit entry.
        input   wire   [15:0]                  i_ben,

        // Read Enable.
        input   wire                           i_ren,

        // Address
        input   wire   [$clog2(DEPTH)-1:0]     i_addr,

        // Write data.
        input   wire   [127:0]                 i_wdata,

        // Read data.
        output  reg    [127:0]                 o_rdata 
);

///////////////////////////////////////////////////////////////////////////////

// Block RAM
reg [127:0] mem_ff [DEPTH-1:0];

///////////////////////////////////////////////////////////////////////////////

// Initialize block RAM to 0.
initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem_ff[i] = 128'd0;
end

///////////////////////////////////////////////////////////////////////////////

// Block RAM read logic.
always @ (posedge i_clk)
begin: block_ram_read
        if ( i_ren )
                o_rdata <= mem_ff [ i_addr ];
end

///////////////////////////////////////////////////////////////////////////////

// Block RAM write logic (16 byte enables per entry).
always @ (posedge i_clk)
begin: block_ram_write
        if ( i_ben[0]  )   mem_ff[i_addr][7:0]       <=      i_wdata[7:0];
        if ( i_ben[1]  )   mem_ff[i_addr][15:8]      <=      i_wdata[15:8];
        if ( i_ben[2]  )   mem_ff[i_addr][23:16]     <=      i_wdata[23:16];
        if ( i_ben[3]  )   mem_ff[i_addr][31:24]     <=      i_wdata[31:24];
        if ( i_ben[4]  )   mem_ff[i_addr][39:32]     <=      i_wdata[39:32];
        if ( i_ben[5]  )   mem_ff[i_addr][47:40]     <=      i_wdata[47:40];
        if ( i_ben[6]  )   mem_ff[i_addr][55:48]     <=      i_wdata[55:48];
        if ( i_ben[7]  )   mem_ff[i_addr][63:56]     <=      i_wdata[63:56];
        if ( i_ben[8]  )   mem_ff[i_addr][71:64]     <=      i_wdata[71:64];
        if ( i_ben[9]  )   mem_ff[i_addr][79:72]     <=      i_wdata[79:72];
        if ( i_ben[10] )   mem_ff[i_addr][87:80]     <=      i_wdata[87:80];
        if ( i_ben[11] )   mem_ff[i_addr][95:88]     <=      i_wdata[95:88];
        if ( i_ben[12] )   mem_ff[i_addr][103:96]    <=      i_wdata[103:96];
        if ( i_ben[13] )   mem_ff[i_addr][111:104]   <=      i_wdata[111:104];
        if ( i_ben[14] )   mem_ff[i_addr][119:112]   <=      i_wdata[119:112];
        if ( i_ben[15] )   mem_ff[i_addr][127:120]   <=      i_wdata[127:120];
end

///////////////////////////////////////////////////////////////////////////////

endmodule // mem_ben_block128.v
