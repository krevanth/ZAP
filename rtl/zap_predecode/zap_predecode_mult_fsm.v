/*
 * Synthesizes long multiplies into a low register write and
 * a high register write.
 *
 * Author: Revanth Kamaraj
 */

`default_nettype none

module zap_predecode_mult_fsm
(
        // Clock and reset.
        input wire           i_clk,
        input wire           i_reset,

        // Stalls and clears.
        input wire           i_clear_from_writeback,
        input wire           i_data_stall,
        input wire           i_clear_from_alu,
        input wire           i_stall_from_shifter,
        input wire           i_stall_from_issue,

        // Input from previous stage.
        input wire [34:0]    i_instruction,
        input wire           i_instruction_valid,

        // Interrupts - Unit may block these.
        input wire           i_fiq,
        input wire           i_irq,

        // Outputs. 
        output reg [35:0]    o_instruction,
        output reg           o_instruction_valid,

        // Stall.
        output reg           o_stall_from_decode,

        // Interrupts.
        output reg           o_irq,
        output reg           o_fiq
);

`include "regs.vh"
`include "instruction_patterns.vh"

// States.
localparam IDLE = 0;
localparam BUSY = 1;

// State register.
reg state_ff, state_nxt;

always @*
begin
        // Default values.
        o_irq                   = i_irq;
        o_fiq                   = i_fiq;
        o_instruction           = i_instruction;
        o_instruction_valid     = i_instruction_valid;
        state_nxt               = state_ff;
        o_stall_from_decode     = 1'd0;

        // Next state and output logic.
        case ( state_ff )
                IDLE:
                begin
                        casez ( i_instruction_valid ? i_instruction[31:0] : 32'd0 )
                                LMULT_INST:
                                begin
                                        state_nxt           = BUSY;
                                        o_stall_from_decode = 1'd1; 
                                end
                        endcase
                end
                BUSY:   
                begin
                        o_irq                   = 0;
                        o_fiq                   = 0;
                        o_instruction           = {1'd1, i_instruction}; 
                        o_stall_from_decode     = 1'd0;
                        state_nxt               = IDLE;
                end
        endcase
end

// Sequential logic POSEDGE.
always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                state_ff <= IDLE;
        end
        else if ( i_clear_from_writeback )
        begin
                state_ff <= IDLE;
        end
        else if ( i_data_stall )
        begin
                //Hold.
        end
        else if ( i_clear_from_alu )
        begin
                state_ff <= IDLE;
        end
        else if ( i_stall_from_shifter )
        begin
                //Hold.
        end
        else if ( i_stall_from_issue )
        begin
                //Hold.
        end
        else
        begin
                state_ff <= state_nxt;
        end
end

endmodule
