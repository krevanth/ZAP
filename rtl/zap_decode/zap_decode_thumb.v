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
        input wire [31:0]       i_instruction,
        input wire              i_instruction_valid,

        // Ensure Thumb mode is active.
        input wire [31:0]       i_cpsr_ff, // To ensure Thumb mode is active.

        // Output to the ARM decoder.
        output reg [34:0]       o_instruction,
        output reg              o_instruction_valid,
        output reg              o_und
);

reg [11:0] offset_ff, offset_nxt;       // Remember offset.

`include "cc.vh"
`include "cpsr.vh"
`include "instruction_patterns.vh"

always @*
begin
        // If you are not in Thumb mode, just pass stuff on.
        o_instruction_valid     = i_instruction_valid;
        o_und                   = 0;
        o_instruction           = i_instruction;
        state_nxt               = state_ff;
        offset_nxt              = i_instruction[11:0];

        if ( i_cpsr_ff[T] && i_instruction_valid ) // Thumb mode.
        begin
                casez ( i_instruction[15:0] )
                        T_BRANCH_COND   : decode_conditional_branch; 
                        T_BRANCH_NOCOND : decode_unconditional_branch;
                        T_BL            : decode_bl;
                        T_BX            : decode_bx;
                        T_SWI           : decode_swi;
                        default:
                        begin
                                $display($time, "%m: Not implemented!");
                                o_und = 1;
                        end
                endcase 
        end
end

task decode_conditional_branch;
begin
        // An MSB of 1 indicates a left shift of 1.
        o_instruction           = {1'd1, 2'b0, AL, 3'b101, 1'b0, 24'd0}; 
        o_instruction[23:0]     = $signed(i_instruction[7:0]); 
end        
endtask

task decode_unconditional_branch;
begin
        // An MSB of 1 indicates a left shift of 1.
        o_instruction           = {1'd1, 2'b0, AL, 3'b101, 1'b0, 24'd0}; 
        o_instruction[23:0]     = $signed(i_instruction[10:0]);        
end
endtask

task decode_bl;
begin
        case ( i_instruction[11] )
                1'd0:
                begin
                        // Store the offset and send out a dummy instruction.
                        offset_nxt      = i_instruction[11:0];
                        o_instruction   = 32'd0;
                end
                1'd1:
                begin
                        // Generate a full jump.
                        o_instruction = {1'd1, 2'b0, AL, 3'b101, 1'b1, 24'd0};
                        o_instruction[23:0] = ($signed(offset_nxt) << 12) | (offset_ff); 
                end
        endcase
end
endtask

task decode_bx;
begin
        // Generate a BX Rm.
        o_instruction = 32'b0000_0001_0010_1111_1111_1111_0001_0000;
        o_instruction[31:28] = AL;
        o_instruction[3:0]   = i_instruction[6:3];
end
endtask

task decode_swi;
        // Generate a SWI.
        o_instruction = 32'b0000_1111_0000_0000_0000_0000_0000_0000;
        o_instruction[31:28] = AL;
        o_instruction[7:0]   = i_instruction[7:0]; 
endtask

endmodule
