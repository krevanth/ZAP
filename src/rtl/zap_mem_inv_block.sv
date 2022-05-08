//////////////////////////////////////////////////////////////////////////////////
//                                                                              //                                    
//Copyright (C) 2016-2022 Revanth Kamaraj(krevanth) <revanth91kamaraj@gmail.com)//
//                                                                              // 
// This program is free software; you can redistribute it and/or                //
// modify it under the terms of the GNU General Public License                  //
// as published by the Free Software Foundation; either version 2               //
// of the License, or (at your option) any later version.                       //
//                                                                              //
// This program is distributed in the hope that it will be useful,              //
// but WITHOUT ANY WARRANTY; without even the implied warranty of               //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                //
// GNU General Public License for more details.                                 //
//                                                                              //
// You should have received a copy of the GNU General Public License            //
// along with this program; if not, write to the Free Software                  //
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,   //
// USA.                                                                         //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Tag RAMs with single cycle clear. Finds the greatest use in TLBs.            //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////




module zap_mem_inv_block #(
        parameter DEPTH = 32,
        parameter WIDTH = 32   // Not including valid bit.
)(  


        input logic                           i_clk,
        input logic                           i_reset,

        // Write data.
        input logic   [WIDTH-1:0]             i_wdata,

        // Write and read enable.
        input logic                           i_wen, 
        input logic                           i_ren,

        // Invalidate entries in 1 cycle.
        input logic                           i_inv,

        // Read and write address.
        input logic   [$clog2(DEPTH)-1:0]     i_raddr, 
        input logic   [$clog2(DEPTH)-1:0]     i_waddr,

        // Read data and valid.
        output logic [WIDTH-1:0]              o_rdata,
        output logic                          o_rdav
);


// Flops
logic [DEPTH-1:0] dav_ff;

// Nets
logic [$clog2(DEPTH)-1:0] addr_r;
logic en_r;


assign addr_r = i_raddr;
assign en_r   = i_ren;


// Block RAM.
zap_ram_simple #(.WIDTH(WIDTH), .DEPTH(DEPTH)) u_ram_simple (
        .i_clk     ( i_clk ),

        .i_wr_en   ( i_wen ),
        .i_rd_en   ( en_r ),

        .i_wr_data ( i_wdata ),
        .o_rd_data ( o_rdata ),

        .i_wr_addr ( i_waddr ),
        .i_rd_addr ( addr_r )
);


// DAV flip-flop implementation.
always_ff @ (posedge i_clk)
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


endmodule // mem_inv_block.v

