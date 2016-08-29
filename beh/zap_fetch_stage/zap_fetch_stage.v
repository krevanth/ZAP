`default_nettype none

// ============================================================================
// Filename --
// zap_fetch_stage.v
//
// HDL --
// Verilog-2005
//
// Author --
// Revanth Kamaraj
//
// Description --
// This is the simple I-cache frontend to the processor. This stage simply
// serves as a buffer for instructions. This allows maximum cycle time for
// the I-cache. 
//
// Copyright --
// (C)2016 Revanth Kamaraj.
// ============================================================================

module zap_fetch_stage
(
                // ==============================
                // Clock and reset.
                // ==============================
                input wire i_clk,          // ZAP clock.        
                input wire i_reset,        // Active high synchronous reset.
                
                // ========================================
                // From other parts of the pipeline. These
                // signals either tell the unit to invalidate
                // its outputs or freeze in place.
                // ========================================
                input wire i_clear_from_writeback, // | High Priority.
                input wire i_data_stall,           // |
                input wire i_clear_from_alu,       // |
                input wire i_stall_from_issue,     // |
                input wire i_stall_from_decode,    // V Low Priority.
                
                // =========================================
                // From I-cache.
                // =========================================
                input wire [31:0] i_instruction,  // A 32-bit ZAP instruction.
                input wire i_valid,               // Instruction valid.
                input wire i_instr_abort,         // Instruction abort fault.
                
                // ==========================================
                // To decode.
                // ==========================================
                output reg [31:0] o_instruction,  // The 32-bit instruction.
                output reg o_valid,               // Instruction valid.
                output reg o_instr_abort          // Indication of an abort.       
);

//================================================
// This is the instruction payload on an abort
// because no instruction is actually available on
// an abort.
// ===============================================

localparam ABORT_PAYLOAD = 32'd0;

// ===========================================
// This stage simply forwards data from the
// I-cache downwards.
// ===========================================
always @ (posedge i_clk)
begin
        if (  i_reset )                          o_valid <= 1'd0;
        else if ( i_clear_from_writeback )       o_valid <= 1'd0;
        else if ( i_data_stall)                  begin end // Save state.
        else if ( i_clear_from_alu )             o_valid <= 1'd0;
        else if ( i_stall_from_issue )           begin end // Save state.
        else if ( i_stall_from_decode)           begin end
        else
        begin
                // =========================================
                // Instruction aborts occur only when i_valid
                // is 0 since we are using a VIVT cache that
                // faults only on a miss. However, to maintain
                // pipeline synchronization, we asserted valid
                // for aborted instructions too.
                // =========================================
                o_valid         <= i_instr_abort ? 1'd1  : i_valid;
                o_instruction   <= i_instr_abort ? ABORT_PAYLOAD : 
                                                   i_instruction;
                
                // ============================================================
                // Aborted instructions go with a 0x0000_0000 payload (AND R0,
                // R0, R0) which is harmless.
                // ============================================================
                
                o_instr_abort   <= i_instr_abort;
        end
end

endmodule
