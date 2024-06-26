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
// This is the barrel shifter in the ZAP processor.
//

module zap_shifter_shift
#(
        // Number of shift operations defined.
        parameter logic [31:0] SHIFT_OPS = 32'd5
)
(
        // Source value.
        input  logic [31:0]                      i_source,

        // Shift amount.
        input  logic [7:0]                       i_amount,

        // Carry in.
        input  logic                             i_carry,

        // Shift type.
        input  logic [$clog2(SHIFT_OPS)-1:0]     i_shift_type,

        // Output result and output carry and saturation indicator.
        output logic [31:0]                       o_result,
        output logic                              o_carry,
        output logic                              o_sat
);

`include "zap_defines.svh"
`include "zap_localparams.svh"

logic signed [32:0] asr_res, asr_res_fin; // For ASR.

assign asr_res     = {i_source, i_carry};
assign asr_res_fin = asr_res >>> i_amount;

assign o_sat = i_shift_type == LSL_SAT ? (i_source[30] != i_source[31]) : 1'd0;

always_comb
begin
        case ( i_shift_type )

                // Logical shift left, logical shift right and
                // arithmetic shift right.
                {1'd0, LSL}:    {o_carry, o_result} = {i_carry, i_source} <<
                                i_amount;

                {1'd0, LSR}:    {o_result, o_carry} = {i_source, i_carry} >>
                                i_amount;

                {1'd0, ASR}:    {o_result, o_carry} = asr_res_fin;

                {1'd0, ROR}: // Rotate right.
                begin
                        o_result = ( i_source >> i_amount[4:0] )  |
                                   ( i_source << (32 - i_amount[4:0] ) );
                        o_carry  = ( i_amount[7:0] == 0) ?
                                     i_carry  : ( (i_amount[4:0] == 0) ?
                                     i_source[31] : o_result[31] );
                end

                RORI, ROR_1:
                begin
                        // ROR #n (ROR_1)
                        o_result = ( i_source >> i_amount[4:0] )  |
                                   (i_source << (32 - i_amount[4:0] ) );
                        o_carry  = (|i_amount) ? o_result[31] : i_carry;
                end

                // ROR #0 becomes this.
                RRC:    {o_result, o_carry}        = {i_carry, i_source};

                //
                // LSL_SAT. Always #1 in length, to deal with * 2. Saturation
                // that occurs is passed on to the ALU.
                //
                LSL_SAT:
                begin
                        o_carry = 1'd0;

                        if ( o_sat )
                        begin
                                if ( i_source[31] == 1'd0 )
                                begin
                                        o_result = {1'd0, {31{1'd1}}}; // Most +ve
                                end
                                else
                                begin
                                        o_result = {1'd1, {31{1'd0}}}; // Most -ve
                                end
                        end
                        else
                        begin
                            o_result = i_source << 1; // Multiply by 2.
                        end
                end

                default:
                begin
                        // Should never happen
                        // Synthesis will OPTIMIZE. OK to do for FPGA synthesis.

                       {o_result,
                        o_carry} = 'x;
                end
        endcase
end

endmodule : zap_shifter_shift

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
