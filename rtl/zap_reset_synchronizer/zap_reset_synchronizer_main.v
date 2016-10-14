`default_nettype none
`include "config.vh"

module zap_reset_synchronizer_main
(
        input wire          i_clk,
        input wire          i_reset,

        output wire         o_reset
);

// Reset buffers.
reg flop1, flop2;

always @ (posedge i_clk or posedge i_reset) 
// Model 2 flops with asynchronous active high reset to 1.
begin
        if ( i_reset )
        begin
                // The design sees o_reset = 1.
                flop2 <= 1'd1;
                flop1 <= 1'd1;
        end       
        else
        begin
                // o_reset is turned off eventually.
                flop2 <= flop1;
                flop1 <= 1'd0; // Turn off global reset.
        end 
end

assign o_reset = flop2;

endmodule
