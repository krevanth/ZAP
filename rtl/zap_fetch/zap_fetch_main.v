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
                input wire i_stall_from_issue,     // |
                input wire i_stall_from_decode,    // V Low Priority.

                // From program counter. This unit will add 8 to it.
                input wire [31:0] i_pc_ff,               
 
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

// Since the I-cache is allowed 1 full cycle for access, the PC needs
// to be buffered properly. This mimics the I-cache providing the address
// back after 1 cycle on every new clock out.
reg [31:0] pc_buff;

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
                pc_buff         <= 32'd0;
                sleep_ff        <= 1'd0;
        end
        else if ( i_clear_from_writeback )       
        begin   
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                o_instruction   <= 32'd0;
                sleep_ff        <= 1'd0;
        end
        else if ( i_data_stall)                  begin end // Save state.
        else if ( i_clear_from_alu || sleep_ff )             
        begin
                // When asleep, do not present anything.
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                o_instruction   <= 32'd0;
        end
        else if ( i_stall_from_issue )           begin end // Save state.
        else if ( i_stall_from_decode)           begin end
        else
        begin
                // Instruction aborts occur only when i_valid
                // is 0 since we are using a VIVT cache that
                // faults only on a miss. However, to maintain
                // pipeline synchronization, we asserted valid
                // for aborted instructions too.
                o_valid         <= i_instr_abort ? 1'd1  : i_valid;
                o_instruction   <= i_instr_abort ? ABORT_PAYLOAD : 
                                                   i_instruction;
                
                // Aborted instructions go with a 0x0000_0000 payload (AND R0,
                // R0, R0) which is harmless.
                
                o_instr_abort   <= i_instr_abort;

                // Buffer PC. Advance only when capturing an instruction.
                pc_buff <= (i_valid || i_instr_abort) ? 
                           i_pc_ff : pc_buff;
        end

        // This is needed to maintain a PC + 8
        // illusion.
        if ( i_reset )
                o_pc_plus_8_ff <= 32'd8;
        else
                o_pc_plus_8_ff <= pc_buff + 32'd8;
end

endmodule
