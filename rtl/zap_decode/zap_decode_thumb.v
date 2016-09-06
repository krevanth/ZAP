`default_nettype none

/*
Filename --
zap_decode_thumb.v

HDL --
Verilog-2005

Description --
Performs Thumb to ARM conversion. Placed in series with ARM decode
since ARM decode is relatively simple.

Author --
Revanth Kamaraj.

License --
Released under the MIT License.
*/

module zap_decode_thumb
(
        // Clock and reset.
        input wire              i_clk,
        input wire              i_reset, 

        // Input from I-cache.
        input wire [15:0]       i_instruction,
        input wire              i_instruction_valid,

        // Ensure Thumb mode is active.
        input wire [31:0]       i_cpsr_ff, // To ensure Thumb mode is active.

        // Output to the ARM decoder.
        output reg [34:0]       o_instruction,
        output reg              o_instruction_valid,
        output reg              o_und
);

always @*
begin
        // If you are not in Thumb mode, just pass stuff on.
        o_instruction_valid     = i_instruction_valid;
        o_und                   = 0;
        o_instruction           = i_instruction;

        if ( i_cpsr_ff[T] && i_instruction_valid ) // Thumb mode.
        begin
                casez ( i_instruction[15:0] )
                       T_BRANCH_COND: decode_conditional_branch; 
                endcase 
        end
end

task decode_conditional_branch;
begin
        o_instruction           = 1'd1, 2'b0, AL, 3'b101, 1'b0, 24'd0}; 
        o_instruction[23:1]     = $signed(i_instruction[7:0]); // Left shift by 1 for HWA.
end        
endtask

endmodule
