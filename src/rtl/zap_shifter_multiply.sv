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
// This unit handles 32x32=32/64 multiplication using an FSM using
// a 17x17 signed array multiplier. Takes 5 cycles per 32x32+64 operation.
//

module zap_shifter_multiply
#(
        parameter logic [31:0] PHY_REGS  = 32'd46,
        parameter logic [31:0] ALU_OPS   = 32'd32
)
(
        input logic                              i_clk,
        input logic                              i_reset,

        // Clear and stall signals.
        input logic                              i_clear_from_writeback,
        input logic                              i_data_stall,
        input logic                              i_clear_from_alu,

        // ALU operation to perform. Activate if this is multiplication.
        input logic   [$clog2(ALU_OPS)-1:0]      i_alu_operation_ff,

        // This is not used.
        input logic                              i_cc_satisfied,

        // rm.rs + {rh,rn}. For non accumulate versions, rn = 0x0 and rh = 0x0.
        input logic [31:0]                       i_rm,
        input logic [31:0]                       i_rn,
        input logic [31:0]                       i_rh,
        input logic [31:0]                       i_rs,

        //
        // Outputs.
        //

        output logic  [31:0]                      o_rd,    // Result.
        output logic                              o_sat,
        output logic                              o_busy,  // Unit busy.
        output logic                              o_nozero // Don't set zero flag.
);

`include "zap_defines.svh"
`include "zap_localparams.svh"

///////////////////////////////////////////////////////////////////////////////

// States

localparam [31:0] NUMBER_OF_STATES = 6;

typedef enum logic [NUMBER_OF_STATES-1:0] {
        IDLE          = 6'b000_001,
        POST_IDLE     = 6'b000_010,
        S1            = 6'b000_100,
        S2            = 6'b001_000,
        S3            = 6'b010_000,
        S4            = 6'b100_000,
        `ZAP_DEFAULT_XX
} t_state;

///////////////////////////////////////////////////////////////////////////////

logic         old_nozero_nxt, old_nozero_ff;
logic         higher;
logic         unused;

assign unused = |{PHY_REGS};

// Set 1 to take upper 32-bit. See this instead of TAKE_UPPER.
assign higher =
                         i_alu_operation_ff[0] ||
                i_alu_operation_ff == SMLAL00H ||
                i_alu_operation_ff == SMLAL01H ||
                i_alu_operation_ff == SMLAL10H ||
                i_alu_operation_ff == SMLAL11H;

// 17-bit partial products.
logic signed [16:0] a;
logic signed [16:0] b;
logic signed [16:0] c;
logic signed [16:0] d;

// Signed products.
logic signed [63:0] x_ff, x_nxt;
logic signed [33:0] xprod_ab, xprod_bc, xprod_ad, xprod_cd;
logic signed [63:0] prod_ab, prod_bc, prod_ad, prod_cd;

//
// Indicates to take upper product. Discard lower 16-bits. NOT what it looks
// like. The one you're looking for is "higher".
//
logic               take_upper; // NOT WHAT IT LOOKS LIKE. NOT TO TAKE UPPER
                                // PRODUCT. THIS IS FOR DSP TO DISCARD LOWER
                                // 16 BIT OF 48-BIT PRODUCT.

// State
t_state state_ff, state_nxt;

///////////////////////////////////////////////////////////////////////////////

// Precompute products using DSP 17x17 signed multipliers. Result is 34-bit.
always_ff @ (posedge i_clk)
begin
        // Multiply 34 = 17 x 17.
        xprod_ab[33:0] <= $signed(a[16:0]) * $signed(b[16:0]);
        xprod_bc[33:0] <= $signed(b[16:0]) * $signed(c[16:0]);
        xprod_ad[33:0] <= $signed(a[16:0]) * $signed(d[16:0]);
        xprod_cd[33:0] <= $signed(c[16:0]) * $signed(d[16:0]);
end

///////////////////////////////////////////////////////////////////////////////

// Sign Extend
assign prod_ab = $signed({{30{xprod_ab[33]}},xprod_ab[33:0]});
assign prod_bc = $signed({{30{xprod_bc[33]}},xprod_bc[33:0]});
assign prod_cd = $signed({{30{xprod_cd[33]}},xprod_cd[33:0]});
assign prod_ad = $signed({{30{xprod_ad[33]}},xprod_ad[33:0]});

always_ff @ (posedge i_clk) // {ac} * {bd} = RM x RS
begin
        if ( i_alu_operation_ff == {1'd0, SMLALL} || i_alu_operation_ff == {1'd0, SMLALH} )
        begin
                // Signed RM x Signed RS

                a <= $signed({i_rm[31], i_rm[31:16]});
                c <= $signed({1'd0, i_rm[15:0]});

                b <= $signed({i_rs[31], i_rs[31:16]});
                d <= $signed({1'd0, i_rs[15:0]});

                take_upper <= 1'd0;
        end
        else if ( i_alu_operation_ff == OP_SMULW0 )
        begin
                // Signed RM x Lower RS

                a <= $signed({i_rm[31], i_rm[31:16]});
                c <= $signed({1'd0, i_rm[15:0]});

                b <= $signed({17{i_rs[15]}});
                d <= $signed({1'd0, i_rs[15:0]});

                take_upper <= 1'd1;
        end
        else if ( i_alu_operation_ff == OP_SMULW1 )
        begin
                // Signed RM x Upper RS

                a <= $signed({i_rm[31], i_rm[31:16]});
                c <= $signed({1'd0, i_rm[15:0]});

                b <= $signed({17{i_rs[31]}});
                d <= $signed({1'd0, i_rs[31:16]});

                take_upper <= 1'd1;
        end
        else if ( i_alu_operation_ff == OP_SMUL00   || i_alu_operation_ff == OP_SMLA00  ||
                  i_alu_operation_ff == OP_SMLAL00L || i_alu_operation_ff == OP_SMLAL00H )
        begin
                // lower RM x lower RS

                a <= $signed({17{i_rm[15]}});
                c <= $signed({1'd0, i_rm[15:0]});

                b <= $signed({17{i_rs[15]}});
                d <= $signed({1'd0, i_rs[15:0]});

                take_upper <= 1'd0;
        end
        else if (  i_alu_operation_ff == OP_SMUL01   || i_alu_operation_ff == OP_SMLA01 ||
                   i_alu_operation_ff == OP_SMLAL01L || i_alu_operation_ff == OP_SMLAL01H )
        begin
                // lower RM x upper RS

                a <= $signed({17{i_rm[15]}});         // x = 0 for Rm
                c <= $signed({1'd0, i_rm[15:0]});

                b <= $signed({17{i_rs[16]}});        // y = 1 for Rs
                d <= $signed({1'd0, i_rs[31:16]});

                if ( i_alu_operation_ff == OP_SMLAL01L || i_alu_operation_ff == OP_SMLAL01H )
                begin
                        take_upper <= 1'd1;
                end
                else
                begin
                        take_upper <= 1'd0;
                end
        end
        else if ( i_alu_operation_ff == OP_SMUL10   || i_alu_operation_ff == OP_SMLA10 ||
                  i_alu_operation_ff == OP_SMLAL10L || i_alu_operation_ff == OP_SMLAL10H )
        begin
                // upper RM x lower RS

                a <= $signed({17{i_rm[31]}});       // x = 1 for Rm
                c <= $signed({1'd0, i_rm[31:16]});

                b <= $signed({17{i_rs[15]}});           // y = 0 for Rs
                d <= $signed({1'd0, i_rs[15:0]});

                if ( i_alu_operation_ff == OP_SMLAL10L || i_alu_operation_ff == OP_SMLAL10H )
                begin
                        take_upper <= 1'd1;
                end
                else
                begin
                        take_upper <= 1'd0;
                end
        end
        else if ( i_alu_operation_ff == OP_SMUL11   || i_alu_operation_ff == OP_SMLA11 ||
                  i_alu_operation_ff == OP_SMLAL11L || i_alu_operation_ff == OP_SMLAL11H)
        begin
                // upper RM x upper RS

                a <= $signed({17{i_rm[31]}});
                c <= $signed({1'd0, i_rm[31:16]});

                b <= $signed({17{i_rs[31]}});
                d <= $signed({1'd0, i_rs[31:16]});

                take_upper <= 1'd0;
        end
        else
        begin
               // unsigned RM x RS

               a <= $signed({1'd0, i_rm[31:16]});
               c <= $signed({1'd0, i_rm[15:0]});

               b <= $signed({1'd0, i_rs[31:16]});
               d <= $signed({1'd0, i_rs[15:0]});

               take_upper <= 1'd0;
        end
end

///////////////////////////////////////////////////////////////////////////////

// STATE MACHINE ( Next State Logic )
always_comb
begin

        // --------------------------------------------------
        // Local Variable Section
        // --------------------------------------------------

        logic tmp_sat;

        // --------------------------------------------------
        // Default Values Section
        // (Done to avoid combo loops/incomplete assignments
        // --------------------------------------------------

        old_nozero_nxt = old_nozero_ff;
        o_nozero       = 1'd0;
        o_busy         = 1'd1;
        o_rd           = 32'd0;
        state_nxt      = state_ff;
        x_nxt          = x_ff;
        o_sat          = 1'd0;
        tmp_sat        = 1'd0;

        // --------------------------------------------------
        // Main FSM code
        // --------------------------------------------------

        case ( state_ff )
                IDLE:
                begin
                        // If we have the go signal.
                        if ( i_cc_satisfied && (i_alu_operation_ff == {1'd0, UMLALL} ||
                                                i_alu_operation_ff == {1'd0, UMLALH} ||
                                                i_alu_operation_ff == {1'd0, SMLALL} ||
                                                i_alu_operation_ff == {1'd0, SMLALH} ||

                                                i_alu_operation_ff == OP_SMULW0 ||
                                                i_alu_operation_ff == OP_SMULW1 ||
                                                i_alu_operation_ff == OP_SMUL00 ||
                                                i_alu_operation_ff == OP_SMUL01 ||
                                                i_alu_operation_ff == OP_SMUL10 ||
                                                i_alu_operation_ff == OP_SMUL11 ||

                                                i_alu_operation_ff == OP_SMLA00     ||
                                                i_alu_operation_ff == OP_SMLA01     ||
                                                i_alu_operation_ff == OP_SMLA10     ||
                                                i_alu_operation_ff == OP_SMLA11     ||
                                                i_alu_operation_ff == OP_SMLAW0     ||
                                                i_alu_operation_ff == OP_SMLAW1     ||
                                                i_alu_operation_ff == OP_SMLAL00L   ||
                                                i_alu_operation_ff == OP_SMLAL01L   ||
                                                i_alu_operation_ff == OP_SMLAL10L   ||
                                                i_alu_operation_ff == OP_SMLAL11L   ||
                                                i_alu_operation_ff == OP_SMLAL00H   ||
                                                i_alu_operation_ff == OP_SMLAL01H   ||
                                                i_alu_operation_ff == OP_SMLAL10H   ||
                                                i_alu_operation_ff == OP_SMLAL11H   )
                        )
                        begin
                                state_nxt = POST_IDLE;
                        end
                        else
                        begin
                                o_busy = 1'd0;
                        end
                end

                POST_IDLE:
                begin
                        state_nxt = !higher ? S1 : S3;
                end

                S1:
                begin
                        // 3 input adder.
                        x_nxt     = (prod_cd <<  0) + (prod_bc << 32'd16) + (prod_ad << 32'd16);
                        state_nxt = S2;
                end

                S2:
                begin
                        // 3 input adder.
                        x_nxt     = (x_ff[63:0]) + (prod_ab << 32'd32) + {i_rh, i_rn};

                        // 64-bit MAC with saturation. For long DSP MAC.
                        if ( i_alu_operation_ff == OP_SMLAL00L   ||
                             i_alu_operation_ff == OP_SMLAL01L   ||
                             i_alu_operation_ff == OP_SMLAL10L   ||
                             i_alu_operation_ff == OP_SMLAL11L   ||
                             i_alu_operation_ff == OP_SMLAL00H   ||
                             i_alu_operation_ff == OP_SMLAL01H   ||
                             i_alu_operation_ff == OP_SMLAL10H   ||
                             i_alu_operation_ff == OP_SMLAL11H  )
                        begin
                                tmp_sat = ( x_nxt[63] != x_ff[63] && x_ff[63] != i_rh[31] ) ? 1'd1 : 1'd0;
                        end
                        else
                        begin
                                // Add sat. Short DSP MAC.
                                tmp_sat = ( x_nxt[31] != x_ff[31] && x_ff[31] == i_rn[31] ) ? 1'd1 : 1'd0;
                        end

                        if ( tmp_sat )
                        begin
                                state_nxt = S4;
                        end
                        else
                        begin
                                state_nxt = S3;
                        end
                end

                S3, S4:
                begin
                        o_sat = state_nxt == S4 ? 1'd1 : 1'd0;

                        state_nxt  = IDLE;

                        // If take_upper=1, discard lower 16-bit.
                        x_nxt = take_upper ? x_ff >>> 32'd16 : x_ff;

                        // Is this the first or second portion of the long multiply.
                        o_rd  = higher ? x_nxt[63:32] : x_nxt[31:0];

                        // Record if older was not zero.
                        if ( !higher )
                        begin
                                old_nozero_nxt = |x_nxt[31:0]; // 0x1 - Older was not zero.
                                                               // 0x0 - Older was zero.
                        end

                        o_busy     = 1'd0;

                        //
                        // During higher operation, override setting of
                        // zero flag IF lower value was non-zero.
                        //
                        if ( higher && old_nozero_ff )
                        begin
                                o_nozero = 1'd1;
                        end
                end

                // ------------------------------------------
                // Default Section - Improves synth results.
                // ------------------------------------------

                default:
                begin
                        old_nozero_nxt = 'x;
                        o_nozero       = 'x;
                        o_busy         = 'x;
                        o_rd           = 'x;
                        state_nxt      = XX;
                        x_nxt          = 'x;
                        o_sat          = 'x;
                        tmp_sat        = 'x;
                end
        endcase
end

///////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                x_ff          <= 64'd0;
                state_ff      <= IDLE;
                old_nozero_ff <= 1'd0;
        end
        else if ( i_clear_from_writeback )
        begin
                state_ff      <= IDLE;
                old_nozero_ff <= 1'd0;
        end
        else if ( i_clear_from_alu && !i_data_stall )
        begin
                state_ff      <= IDLE;
                old_nozero_ff <= 1'd0;
        end
        else if ( !i_data_stall )
        begin
                x_ff          <= x_nxt;
                state_ff      <= state_nxt;
                old_nozero_ff <= old_nozero_nxt;
        end
end

///////////////////////////////////////////////////////////////////////////////

endmodule : zap_shifter_multiply

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
