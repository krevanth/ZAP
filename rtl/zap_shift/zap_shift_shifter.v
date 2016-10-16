`default_nettype none
`include "config.vh"

// Filename --
// zap_shift_shifter.v 
//
// Author --
// Revanth Kamaraj
//
// Description --
// This module is an ARM compatible barrel shifter.

module zap_shift_shifter
#(
        parameter SHIFT_OPS = 5
)
(
        input  wire [31:0]                      i_source,
        input  wire [7:0]                       i_amount,
        input  wire                             i_carry,
        input  wire [$clog2(SHIFT_OPS)-1:0]     i_shift_type,

        output reg [31:0]                       o_result,
        output reg                              o_carry,
        output reg                              o_use_old_carry
);

`include "shtype.vh"

always @*
begin
        o_result        = i_source;
        o_carry         = 0;
        o_use_old_carry = 0;

        case ( i_shift_type )
                LSL:    {o_carry, o_result} = i_source << i_amount;
                LSR:    {o_result, o_carry} = {i_source,1'd0} >> i_amount;
                ASR:    {o_result, o_carry} = ($signed(i_source) << 1) >> i_amount;
                ROR:    
                begin
                        o_result = i_source >> i_amount[4:0] |   i_source << (32 - i_amount[4:0] );

                        if ( i_amount == 0 )
                        begin
                                // RRX will be done in the ALU itself.
                                o_result        = {i_carry, i_source[31:1]};
                                o_carry         = i_source[0];
                        end
                end
                RORI:    
                begin
                        o_result = (i_source >> i_amount[4:0]) | ( i_source << (32 - i_amount[4:0] ));
                        o_carry  = o_result[31];
                end
        endcase

        if ( i_amount == 0 && (i_shift_type != ROR) )
        begin
                o_use_old_carry = 1'd1;
        end
end

endmodule
