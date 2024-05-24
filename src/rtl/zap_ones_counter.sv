//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//
// A slightly modified ones counter. It will count the number of ones
// and multiply the result by 4.
//

module zap_ones_counter (
    output logic [11:0] o_ones_counter,
    input  logic [15:0] i_word
);

logic [4:0] offset [15:0];

always_comb
begin
    for(int i=0;i<16;i++)
    begin
        if ( i == 0 )
        begin
            offset[0]  = {4'd0, i_word[0]};
        end
        else
        begin
            offset[i] = offset[i-1] + {4'd0, i_word[i]};
        end
    end
end

// Since LDM and STM occur only on 4 byte regions, compute the
// next offset.
assign o_ones_counter = {5'd0, offset[15], 2'd0};

endmodule : zap_ones_counter

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
