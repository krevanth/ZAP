// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2018 Revanth Kamaraj.                        --
// --                                                                         -- 
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 2          --
// -- of the License, or (at your option) any later version.                  --
// --                                                                         --
// -- This program is distributed in the hope that it will be useful,         --
// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
// -- GNU General Public License for more details.                            --
// --                                                                         --
// -- You should have received a copy of the GNU General Public License       --
// -- along with this program; if not, write to the Free Software             --
// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
// -- 02110-1301, USA.                                                        --
// --                                                                         --
// -----------------------------------------------------------------------------

`default_nettype none

module ram #(parameter SIZE_IN_BYTES = 4096)  (

input wire                   i_clk,
input wire                   i_wb_cyc,
input wire                   i_wb_stb,
input wire [31:0]            i_wb_adr,
input wire [31:0]            i_wb_dat,
input wire  [3:0]            i_wb_sel,
input wire                   i_wb_we,
output reg [31:0]       o_wb_dat = 32'd0,
output reg              o_wb_ack = 1'd0

);

`include "zap_defines.vh"
`include "zap_localparams.vh"
`include "zap_functions.vh"

integer seed = `SEED;
reg [31:0] ram [SIZE_IN_BYTES/4 -1:0];

// Initialize the RAM with the generated image.
initial
begin:blk1
        integer i;
        integer j;

        reg [7:0] mem [SIZE_IN_BYTES-1:0];

        j = 0;

        for ( i=0;i<SIZE_IN_BYTES;i=i+1)
                mem[i] = 8'd0;

        `include `MEMORY_IMAGE

        for (i=0;i<SIZE_IN_BYTES/4;i=i+1)
        begin
                ram[i] = {mem[j+3], mem[j+2], mem[j+1], mem[j]};
                j = j + 4;
        end
end

// Wishbone RAM.

        // Models a variable delay RAM.
        always @ ( negedge i_clk )
        begin:blk
                reg stall;

                stall = $random(seed);
        
                if ( !i_wb_we && i_wb_cyc && i_wb_stb && !stall )
                begin
                        o_wb_ack         <= 1'd1;
                        o_wb_dat         <= ram [ i_wb_adr >> 2 ];
                end
                else if ( i_wb_we && i_wb_cyc && i_wb_stb && !stall )
                begin
                        o_wb_ack         <= 1'd1;
                        o_wb_dat         <= 'dx;
        
                        if ( i_wb_sel[0] ) ram [ i_wb_adr >> 2 ][7:0]   <= i_wb_dat[7:0];
                        if ( i_wb_sel[1] ) ram [ i_wb_adr >> 2 ][15:8]  <= i_wb_dat[15:8];
                        if ( i_wb_sel[2] ) ram [ i_wb_adr >> 2 ][23:16] <= i_wb_dat[23:16];
                        if ( i_wb_sel[3] ) ram [ i_wb_adr >> 2 ][31:24] <= i_wb_dat[31:24];
                end
                else
                begin
                        o_wb_ack    <= 1'd0;
                        o_wb_dat    <= 'dx;
                end
        end

endmodule // ram

`default_nettype wire
