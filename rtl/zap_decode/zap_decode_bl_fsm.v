`default_nettype none

/*
 Filename --
 zap_bl_fsm.v 

 Author --
 Revanth Kamaraj

 Dependencies --
 None

 Description --
 This is the frontend for the decode of most ZAP instructions. This module
 will translate BL into a MOV PC, LR followed by a branch. Since the PC
 does not change, the LR receives PC + 8. This state machine simplifies the
 complexity of transferring link information across stages. The aim is to
 reduce the number of connections between stages. Note that decode does not
 perform register reads (that is done in the issue stage). Decode simply
 owns the control signals. This state machine connects to the output of the
 memory FSM.

Author --
Revanth Kamaraj.

License --
Released under the MIT license.
*/

module zap_decode_bl_fsm (
                // Clock and reset.
                input wire i_clk,       // ZAP clock.
                input wire i_reset,     // ZAP reset.
                
                // Interrupts
                input wire i_fiq,       // FIQ level signal.
                input wire i_irq,       // IRQ level signal.

                // CPSR from EX.               
                input wire [31:0] i_cpsr_ff, 

                // Clear and stall signals.
                input wire i_clear_from_writeback, // | High Priority
                input wire i_data_stall,           // |
                input wire i_clear_from_alu,       // |
                input wire i_stall_from_shifter,   // |
                input wire i_stall_from_issue,     // V Low Priority
                
                // Inputs from the memory FSM and not fetch. That's because the
                // memory FSM might ask for a save of the base register.
                input   wire   [34:0]           i_instruction,          // Instruction from memory FSM.
                input   wire                    i_instruction_valid,    // Valid from memory FSM.
                
                // Instructions to the decoder.
                output  reg    [34:0]           o_instruction,          // Output instruction.
                output  reg                     o_instruction_valid,    // Output instruction valid.
                
                // When this is asserted, the output of the fetch unit must not change
                // on the upcoming posedge. Incidentally, you MUST tie this
                // to the PC stall signal as well.
                output  reg                     o_stall_from_decode,    // Stall signal output -->
                
                // Interrupts sent out. These are simply copies of the input. The unit may
                // block their propagation temporarily.
                output  reg                     o_fiq,                // FIQ output.
                output  reg                     o_irq                 // IRQ output.
);

// State variables.
reg     state_ff, state_nxt;

localparam      S0 = 0; // Normal state.
localparam      S1 = 1; // Trigerred when a BL is seen.

always @*
begin
       // If we have a BL instruction, we invoke the state
       // machine otherwise we stay in state S0. 

        o_instruction           = i_instruction;
        o_instruction_valid     = i_instruction_valid;
        o_stall_from_decode     = 1'd0;
        state_nxt               = S0;

        // Normally interrupts are simply forwarded.
        o_irq                   = i_irq;
        o_fiq                   = i_fiq;

        if ( i_instruction_valid )
        begin
                case ( state_ff )
                
                S0:
                begin
                        // This is a BL instruction.
                        if (    i_instruction[27:25] == 3'b101 && 
                                i_instruction[24] )
                        begin
                                // Move to new state. In that state, we will 
                                // generate a plain branch.
                                state_nxt = S1;
                                
                                // PC will stall preventing the fetch from 
                                // presenting new data.
                                o_stall_from_decode = 1'd1;

                                if ( i_cpsr_ff[T] == 1'd0 ) // ARM
                                begin
                                        // PC is 8 bytes ahead.
                                        // Craft a SUB LR, PC, 4.
                                        o_instruction = {i_instruction[31:28], 28'h24FE004};
                                end
                                else
                                begin
                                        // PC is 4 bytes ahead...
                                        // Craft a SUB LR, PC, 2 so that return goes to the next Thumb instruction.
                                         o_instruction = {i_instruction[31:28], 28'h24FE002};
                                end

                                // Sell it as a valid instruction
                                o_instruction_valid = 1;

                                // Silence interrupts if a BL instruction is 
                                // seen.
                                o_irq = 0;
                                o_fiq = 0;
                        end
                end

                S1:
                // Since we freeze fetch, valid = 1 in this state anyway.
                begin
                        // Launch out the original instruction clearing the
                        // link bit. This is like MOV PC, <Whatever>
                        o_instruction = i_instruction & ~(1 << 24);

                        // Move to IDLE state.
                        state_nxt       =       S0;

                        // Free the fetch from your clutches.
                        o_stall_from_decode = 1'd0;

                        // Continue to silence interrupts.
                        o_irq           = 0;
                        o_fiq           = 0;
                end

                endcase
        end
end

// Sequential logic. 
always @ (posedge i_clk)
begin
        if      ( i_reset )         
                state_ff <= S0;
        else if ( i_clear_from_writeback )
                state_ff <= S0;
        else if ( i_clear_from_alu )
                state_ff <= S0;
        else if ( i_stall_from_shifter )
                state_ff <= state_ff;
        else if ( i_stall_from_issue )
                state_ff <= state_ff;
        else
                state_ff <= state_nxt;
end

endmodule
