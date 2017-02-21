// 
// MIT License
// 
// Copyright (C) 2016, 2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 

///////////////////////////////////////////////////////////////////////////////

//
// Filename --
// zap_predecode_coproc.v
//
// Summary --
// Coprocessor Interface.
//
// Detail --
// Implements a simple coprocessor interface for the ZAP core.
//

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module zap_predecode_coproc #(
        parameter PHY_REGS = 46
)
(
        input wire              i_clk,
        input wire              i_reset,

        // Instruction and valid qualifier.
        input wire [31:0]       i_instruction,
        input wire              i_valid,

        // CPSR Thumb Bit.
        input wire              i_cpsr_ff_t,

        // Interrupts.
        input wire              i_irq,
        input wire              i_fiq,

         // Clear and stall signals.
        input wire              i_clear_from_writeback, // | High Priority
        input wire              i_data_stall,           // |
        input wire              i_clear_from_alu,       // |
        input wire              i_stall_from_shifter,   // |
        input wire              i_stall_from_issue,     // V Low Priority

        // Pipeline Valid. Must become 0 when every stage of the pipeline
        // is invalid.
        input wire              i_pipeline_dav,

        // Coprocessor done signal.
        input wire              i_copro_done,          

        // Interrupts output.
        output reg              o_irq,
        output reg              o_fiq,

        // Instruction and valid qualifier.
        output reg [31:0]       o_instruction,
        output reg              o_valid,

        // We can generate stall if coprocessor is slow. We also have
        // some minimal latency.
        output reg              o_stall_from_decode,      

        // Are we really asking for the coprocessor ?
        output reg                        o_copro_dav_ff,  

        // The entire instruction is passed to the coprocessor.
        output reg  [31:0]                o_copro_word_ff  
);

///////////////////////////////////////////////////////////////////////////////

`include "cpsr.vh"
`include "regs.vh"
`include "modes.vh"
`include "instruction_patterns.vh"
`include "cc.vh"
`include "global_functions.vh"

///////////////////////////////////////////////////////////////////////////////

localparam IDLE = 0;
localparam BUSY = 1;

///////////////////////////////////////////////////////////////////////////////

// State register.
reg state_ff, state_nxt;

// Output registers.
reg        cp_dav_ff, cp_dav_nxt;
reg [31:0] cp_word_ff, cp_word_nxt;

///////////////////////////////////////////////////////////////////////////////

// Connect output registers to output.
always @*
begin
        o_copro_word_ff = cp_word_ff;
        o_copro_dav_ff  = cp_dav_ff;
end

///////////////////////////////////////////////////////////////////////////////

// Next state logic.
always @*
begin
        // Default values.
        cp_dav_nxt              = cp_dav_ff;
        cp_word_nxt             = cp_word_ff;
        o_stall_from_decode     = 1'd0;
        o_instruction           = i_instruction;
        o_valid                 = i_valid;
        state_nxt               = state_ff;
        o_irq                   = i_irq;
        o_fiq                   = i_fiq;

        case ( state_ff )
        IDLE:
                // Activate only if no thumb.
                casez ( (!i_cpsr_ff_t) ? i_instruction : 32'd0 )
                MRC, MCR, LDC, STC, CDP:
                begin
                        // Send ANDNV R0, R0, R0 instruction.
                        o_instruction = {4'b1111, 28'd0}; 
                        o_valid       = 1'd0;
                        o_irq         = 1'd0;
                        o_fiq         = 1'd0;

                        // As long as there is an instruction to process...
                        if ( i_pipeline_dav )
                        begin
                                // Do not impose any output. However, continue
                                // to stall all before this unit in the 
                                // pipeline.
                                o_valid                 = 1'd0;
                                o_stall_from_decode     = 1'd1;
                                cp_dav_nxt              = 1'd0;
                                cp_word_nxt             = 32'd0;
                        end
                        else
                        begin
                                // Prepare to move to BUSY. Continue holding
                                // stall. Send out 0s.
                                o_valid                 = 1'd0;
                                o_stall_from_decode     = 1'd1;
                                cp_word_nxt             = i_instruction;
                                cp_dav_nxt              = 1'd1;
                                state_nxt               = BUSY;
                        end
                end
                default:
                begin
                        // Remain transparent since this is not a coprocessor
                        // instruction.
                        o_valid                 = i_valid;
                        o_instruction           = i_instruction;
                        o_irq                   = i_irq;
                        o_fiq                   = i_fiq;
                        cp_dav_nxt              = 0;
                        o_stall_from_decode     = 0;
                        cp_word_nxt             = {32{1'dx}}; // Don't care.
                end
                endcase

        BUSY:
        begin
                // Provide coprocessor word and valid to the coprocessor.
                cp_word_nxt             = cp_word_ff;
                cp_dav_nxt              = cp_dav_ff;

                // Continue holding stall.
                o_stall_from_decode     = 1'd1;

                // Send out nothing.
                o_valid                 = 1'd0;
                o_instruction           = 32'd0;

                // Block interrupts.
                o_irq = 1'd0;
                o_fiq = 1'd0;

                // If we get a response, we can move back to IDLE. Release
                // the stall so that processor can continue.
                if ( i_copro_done )
                begin
                        cp_dav_nxt              = 1'd0;
                        cp_word_nxt             = 32'd0;
                        state_nxt               = IDLE;
                        o_stall_from_decode     = 1'd0;
                end
        end
        endcase
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                clear;
        end
        else if ( i_clear_from_writeback )
        begin
                clear;
        end
        else if ( i_data_stall )
        begin
                // Preserve values.
        end
        else if ( i_clear_from_alu )
        begin
                clear;
        end
        else if ( i_stall_from_shifter )
        begin
                // Preserve values.
        end
        else if ( i_stall_from_issue )
        begin
                // Preserve values.
        end
        else
        begin
                state_ff   <= state_nxt;
                cp_word_ff <= cp_word_nxt;
                cp_dav_ff  <= cp_dav_nxt;
        end
end

// Clear out the unit.
task clear;
begin
                state_ff            <= IDLE;
                cp_dav_ff           <= 1'd0; 
end
endtask

endmodule
