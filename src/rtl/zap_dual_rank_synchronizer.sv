// -----------------------------------------------------------------------------
// --                                                                         --
// --    (C) 2016-2022 Revanth Kamaraj (krevanth)                             --
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

module zap_dual_rank_synchronizer
#(
        parameter bit [31:0] WIDTH = 32'd1
)
(
        input  logic             i_clk,
        input  logic             i_reset,
        input  logic [WIDTH-1:0] i_async,
        output logic [WIDTH-1:0] o_sync
);

logic [WIDTH-1:0] meta;

always_ff @ ( posedge i_clk )
begin
        if ( i_reset )
                meta <= '0;
        else
                meta <= i_async;
end

always_ff @ ( posedge i_clk )
begin
        if ( i_reset )
                o_sync <= '0;
        else
                o_sync <= meta;
end

endmodule: zap_dual_rank_synchronizer

// ----------------------------------------------------------------------------
// EOF
// ----------------------------------------------------------------------------
