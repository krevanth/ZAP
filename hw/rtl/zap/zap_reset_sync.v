/// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_reset_sync
// HDL          : Verilog-2001
// Module       : zap_reset_sync.v
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// This is dual rank reset synchronizer.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Active high.
// Clock        : i_clk
// Depends      : --        
// ----------------------------------------------------------------------------

`default_nettype none

module zap_reset_sync
(
        input wire          i_clk,  // Clock.
        input wire          i_reset,// Dirty reset - Active High.

        output wire         o_reset // Clean reset - Active High.
);

localparam RESET_ON  = 1'd1; // Active high reset.
localparam RESET_OFF = 1'd0;

// Reset buffers.
reg flop1, flop2;

// Tie second flop to output.
assign o_reset = flop2;

//
// Model a dual flop synchronizer with asynchronous active 
// high reset. The input of the synchronizer is tied to
// RESET_OFF which synchronously travels to the output.
// The async reset pins of both the flops are tied to the
// dirty reset.
//

always @ (posedge i_clk or posedge i_reset) 
begin:rst_sync
        if ( i_reset )
        begin
                // The design sees o_reset = 1.
                flop2 <= RESET_ON;
                flop1 <= RESET_ON;
        end       
        else
        begin
                // o_reset is turned off eventually.
                flop2 <= flop1;
                flop1 <= RESET_OFF; // Turn off global reset.
        end 
end

endmodule // reset_sync.v
