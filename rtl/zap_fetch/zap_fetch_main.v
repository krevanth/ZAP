`default_nettype none

/*
Filename --
zap_fetch_stage.v

HDL --
Verilog-2005

Description --
This is the simple I-cache frontend to the processor. This stage simply
serves as a buffer for instructions. This allows maximum cycle time for
the I-cache. Data aborts are handled by pumping an extra signal down the
pipeline. Data aborts piggyback off AND R0, R0, R0. 
*/

module zap_fetch_main
(
                // Clock and reset.
                input wire i_clk,          // ZAP clock.        
                input wire i_reset,        // Active high synchronous reset.
                
                // From other parts of the pipeline. These
                // signals either tell the unit to invalidate
                // its outputs or freeze in place.
                input wire i_clear_from_writeback, // | High Priority.
                input wire i_data_stall,           // |
                input wire i_clear_from_alu,       // |
                input wire i_stall_from_shifter,   // |
                input wire i_stall_from_issue,     // |
                input wire i_stall_from_decode,    // V Low Priority.

                // Comes from Wb.
                input wire [31:0] i_pc_ff,               // Program counter.

                // From I-cache.
                input wire [31:0] i_instruction,         // A 32-bit ZAP instruction.
                input wire        i_valid,               // Instruction valid indicator.
                input wire        i_instr_abort,         // Instruction abort fault.
                
                // To decode.
                output reg [31:0]  o_instruction,       // The 32-bit instruction.
                output reg         o_valid,             // Instruction valid.
                output reg         o_instr_abort,       // Indication of an abort.       
                output reg [31:0]  o_pc_plus_8_ff       // PC ouput.
);

// If an instruction abort occurs, this unit sleeps until it is woken up.
reg sleep_ff;

// This is the instruction payload on an abort
// because no instruction is actually available on
// an abort.
localparam ABORT_PAYLOAD = 32'd0;

// This stage simply forwards data from the
// I-cache downwards.
always @ (posedge i_clk)
begin
        if (  i_reset )                          
        begin
                o_valid         <= 1'd0;
                o_instruction   <= 32'd0;
                o_instr_abort   <= 1'd0;
                sleep_ff        <= 1'd0;        // Wake unit up.
                o_pc_plus_8_ff  <= 32'd8;
        end
        else if ( i_clear_from_writeback )       
        begin   
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                o_instruction   <= 32'd0;
                sleep_ff        <= 1'd0;        // Wake unit up.
        end
        else if ( i_data_stall)                  begin end // Save state.
        else if ( i_clear_from_alu )             
        begin
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                o_instruction   <= 32'd0;
                sleep_ff        <= 1'd0;        // Wake unit up.
        end
        else if ( i_stall_from_shifter )         begin end // Save state.
        else if ( i_stall_from_issue )           begin end // Save state.
        else if ( i_stall_from_decode)           begin end
        else if ( sleep_ff )
        begin
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                o_instruction   <= 32'd0;
                sleep_ff        <= 1'd1;
        end
        else
        begin
                // Instruction aborts occur only when i_valid
                // is 0 since we are using a VIVT cache that
                // faults only on a miss. However, to maintain
                // pipeline synchronization, we asserted valid
                // for aborted instructions too.
                o_valid         <= i_valid;
                o_instruction   <= i_instruction;
                o_instr_abort   <= i_instr_abort;

                // Put unit to sleep on an abort.
                if ( i_instr_abort )
                begin
                        sleep_ff <= 1'd1;
                end

                // Pump PC + 8 down the pipeline.
                o_pc_plus_8_ff <= i_pc_ff + 32'd8;
        end
end

endmodule
