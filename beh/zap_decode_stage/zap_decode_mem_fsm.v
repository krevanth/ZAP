`default_nettype none

// ============================================================================
// Filename --
// zap_mem_fsm.v 
//
// Author --
// Revanth Kamaraj
//
// Description --
// This unit will handle all the LDM/STM complexity. Note that LDR and STR
// instructions natively cannot access the user bank when not in user mode.
// They can enforce a user view of memory in a privileged mode but such an
// option is not available for the LDM/STM type instructions. For that
// purpose, we send a separate signal called force_user_bank.
//
// - The base register is saved onto ARCH_DUMMY_0.
// - The memory transfer is initiated from ARCH_DUMMY_0.
// - PC loads go to ARCH_DUMMY_1.
// - ARCH_DUMMY_1 is written back to the original register is needed.
// - If PC was loaded to ARCH_DUMMY_1, it is moved to PC. The S-bit is
//   provided if required to restore cpsr.
//
// ============================================================================

module zap_decode_mem_fsm (
// ==========================
// Clock and reset.
// ==========================
input   wire            i_clk,
input   wire            i_reset, 

// ===========================
// Clear and stall signals. 
// ===========================      
input wire              i_clear_from_writeback, // | Priority
input wire              i_data_stall,           // |
input wire              i_clear_from_alu,       // |
input wire              i_stall_from_issue,     // V

// ===========================
// IRQ and FIQ requests.
// ===========================
input   wire            i_irq,
input   wire            i_fiq,

// ===========================
// Instruction from fetch. 
// ===========================
        
input   wire    [31:0]  i_instruction,          
input   wire            i_instruction_valid,

// ==================================
// Instruction to memory decoder.
// ==================================

// {Rd/Ptr_Index_Msb, Rm/SourceDest_Index_Msb, Instruction}
// The upper 2-bits are used to extend the register addressing space
// for pointer/src-dest (memory instructions) and dest and shift source
// (Data processing instructions). 

output  reg     [33:0]  o_instruction,
output  reg             o_instruction_valid,
output  reg             o_force_user_bank,
output  reg             o_force_locked_access,

// ===============================================
// Used to stall the fetch stage when in a
// state machine. You must tie this to the PC
// stall signal as well.
// ===============================================
output  reg             o_stall_from_decode,

// =================================
// Interrupt requests transferred.
// =================================
output  reg             o_irq,
output  reg             o_fiq
);

localparam NUMBER_OF_STATES = 4;

// ===============
// States.
// ===============
localparam      IDLE            =       0;
localparam      TRANSFER        =       1;
localparam      PC_CODA         =       2;
localparam      BASE_RESTORE    =       3;

`include "regs.vh"
`include "opcodes.vh"
`include "instruction_patterns.vh"

reg [15:0]                              transfer_list_ff, transfer_list_nxt;    
reg [$clog2(NUMBER_OF_STATES)-1:0]      state_ff, state_nxt;

always @*
begin

        o_instruction           =       i_instruction;
        o_instruction_valid     =       i_instruction_valid;
        o_stall_from_decode     =       1'd0;
        o_force_user_bank       =       1'd0;
        o_force_locked_access   =       1'd0;
        o_irq                   =       i_irq;
        o_fiq                   =       i_fiq;

        transfer_list_nxt       =       transfer_list_ff;

        if ( i_instruction_valid )
        begin
                if ( i_instruction[27:25] == 3'b100 )
                begin

                        o_irq = 0;
                        o_fiq = 0;

                        process_fsm;
                end
        end
end

// ========================
// Sequential logic.
// ========================
always @ (posedge i_clk)
begin
        if      ( i_reset )
        begin
                state_ff <= IDLE;
                transfer_list_ff <= 0;
        end
        else if ( i_clear_from_writeback )
        begin
                state_ff <= IDLE;
                transfer_list_ff <= 0;
        end
        else if ( i_data_stall )
        begin
                // Preserve state.     
        end
        else if ( i_clear_from_alu )
        begin
                state_ff <= IDLE;
                transfer_list_ff <= 0;
        end
        else if ( i_stall_from_issue )
        begin
                // Preserve state.
        end
        else
        begin
                state_ff <= state_nxt;
                transfer_list_ff <= transfer_list_nxt;
        end
end

task process_fsm;
begin
case ( state_ff )
        IDLE:
        begin
                if ( i_instruction[15:0] == 16'd0 )                                         
                begin
                        // =============================
                        // No register is present in the transfer list. Just
                        // zero out the instruction.
                        // ==============================
                        o_instruction_valid = 1'd0;
                end                
                else // Registers are present in the list.
                begin
                        // Move to transfer state.
                        state_nxt = TRANSFER;

                        // Back up the base register.
                        // Issue a MOV ARCH_DUMMY_REG_0, Rbase 
                        o_instruction = 
                        {1'dx, 1'd0, i_instruction[31:28], 
                        2'b00, 1'b0, 4'b1101, 1'b0, 
                        // Upto flag update.
                         4'b0000,       
                        // Dont care. Direct source is of no importance to MOV. 
                         4'bxxxx,       
                        // ????. MSB is also ? at this point.
                         5'b00000,      
                        // Register specified shift.
                         2'b00,         // LSL
                         1'b0,          // Bit 4
                         i_instruction[19:16]};

                        // Set the destination right.
                        {o_instruction[33], 
                          o_instruction[15:12]} = 
                                       ARCH_DUMMY_REG0;

                        // Instruction is valid.
                        o_instruction_valid = 1'd1;

                        // Stall the fetch.
                        o_stall_from_decode = 1'd1;

                        // Update transfer list.
                        transfer_list_nxt = 
                        i_instruction[15:0];
                end
        end

        TRANSFER:
        begin

                /* ALL MEMORY ACCESSES OCCUR IN THIS STATE ONLY */

                // ============================================================
                // For LDM, if S bit is set and PC is not in transfer list -> User bank.
                // For LDM, if S bit is set and PC is in transfer list -> No User bank.
                // For STM, if S bit is set -> User bank.
                // ============================================================

                if (    i_instruction[20] && 
                        i_instruction[22] && 
                        !i_instruction[15] )
                begin
                        o_force_user_bank = 1'd1;
                end
                else if ( !i_instruction[20] && 
                           i_instruction[22] )
                begin
                        o_force_user_bank = 1'd1;
                end

                o_stall_from_decode = 1'd1;

                // =================================
                // This is PC stuff and must be
                // handled carefully for LDM.
                // =================================
                if ( priority_encoder ( transfer_list_ff ) == (1 << ARCH_PC) && 
                        i_instruction[20] )
                begin
                        if ( !i_instruction[21] ) 
                        // No base update. Simply go to PC_CODA.
                                state_nxt = PC_CODA;    
                        else    // Base update
                                state_nxt = BASE_RESTORE;

                        // ==============================
                        // Generate a load instruction
                        // as usual but to ARCH_DUMMY_REG1. Base
                        // address is ARCH_DUMMY_REG0. 
                        // For post-index, W must be 0. 
                        // PC will be written after the
                        // base update.
                        // ============================
                        
                        o_instruction = {1'bx,1'bx,i_instruction[31:20], 4'b0000,4'b0001, 12'dx};

                        o_instruction_valid     = 1'd1;
                        o_instruction[25]       = 1'd0;
                        o_instruction[22]       = 1'd0;   
                        o_instruction[11:0]     = 12'd4;

                        {o_instruction[33], o_instruction[19:16]} = ARCH_DUMMY_REG0; 
                        // Forms pointer. See MSB.

                        {o_instruction[32], o_instruction[15:12]}= ARCH_DUMMY_REG1; 
                        // Forms srcdest for load.

                        if ( !o_instruction[24] ) // Post-index
                        begin
                                o_instruction[21] = 0; 
                        // No user mode access forcing.
                        end
                end 
                else
                begin
                        // =================================
                        // New transfer list is generated.
                        // =================================
                        transfer_list_nxt = new_transfer_list ( transfer_list_ff, priority_encoder ( transfer_list_ff ) );

                        // ============================
                        // Generate  an instruction based 
                        // on the current transfer list. 
                        // Note that the pointer register 
                        // must be ARCH_DUMMY_REG0.
                        // ============================
                        o_instruction = i_instruction;
                        o_instruction_valid     = 1'd1;
                        o_instruction[25]       = 1'd0;
                        o_instruction[22]       = 1'd0;
                        o_instruction[11:0]     = 12'd4;

                        {o_instruction[33], o_instruction[19:16]} = ARCH_DUMMY_REG0;
                        // =================================
                        // Forms R16 for pointer, see MSB.
                        // =================================

                        if ( !o_instruction[24] ) 
                        // =================
                        // Post-index
                        // =================
                        begin
                                o_instruction[21] = 0; // No user mode access.
                        end

                        if ( transfer_list_nxt == 16'd0 ) 
                        // ======================
                        // We are done.
                        // ======================
                        begin
                                if ( i_instruction[21] ) 
                                        state_nxt = IDLE;
                                else
                                        state_nxt = BASE_RESTORE;
                        end
                end
        end

        BASE_RESTORE:
        begin
                o_stall_from_decode = 1'd1;

                // =============================================
                // Generate a MOV Rbase, R16. Call PC_CODA 
                // if 15 is in transfer list and is a load.
                // =============================================
                if ( priority_encoder ( transfer_list_ff ) == 15 && 
                        i_instruction[20] )
                begin
                        if ( !i_instruction[21] )   // No base update.
                                state_nxt = PC_CODA;// Go to the stage where PC 
                                                    // is written from ARCH_DUMMY_REG1.
                        else                        // Base update
                                state_nxt = IDLE;   // Else we are done.
                end
                else
                        state_nxt = IDLE;                                     

                // ====================================================
                // Generate MOV Rbase, R16 if writeback is specified.
               // =====================================================
               
               if ( i_instruction[21] ) // Writeback is specified.
               begin
                       o_instruction = {1'b1,1'b1,i_instruction[31:20], 4'b0000, 4'b0001, 12'd4};
                       o_instruction_valid     = 1'd1;
                       o_instruction[25]       = 1'd0;
                       o_instruction[22]       = 1'd0;   
                       o_instruction[11:0]     = 12'd4;
                       o_instruction[33]       = 1'd1;
                       o_instruction[19:16]    = 4'b0000; 
                        // Forms R16 for pointer. See MSB.
               end
               else
               begin
                       // MOV R0, R0
                       o_instruction = 32'hE1A00000;
               end

               if ( !o_instruction[24] ) // Post-index
               begin
                       o_instruction[21] = 0; // No user mode access forcing !!!
               end
        end

        PC_CODA:
        begin
                        o_stall_from_decode = 1'd0;

                        // ===================================================
                        // In PC_CODA...
                        // MOVS PC, ARCH_DUMMY_REG1 (if S bit is set or ).
                        // MOV PC, ARCH_DUMMY_REG1.
                        // ===================================================
                        o_instruction = {1'd0, 1'dx, i_instruction[31:28], 
                        2'b00, 1'b0, MOV, i_instruction[22], // Upto flag update.
                        4'b0000,        // Dont care.
                        4'b1111,        // Destination is R15.
                        5'b00000,       // Register specified shift.
                        2'b00,          // LSL.
                        1'b0,           // Bit 4.
                        4'bxxxx};       // Source will be written shortly.                  

                        // Source is written.
                        {o_instruction[32], o_instruction[3:0]} = ARCH_DUMMY_REG1;

                        // Get back to IDLE.
                        state_nxt = IDLE;
        end
endcase

end
endtask

// ======================================
// Priority encoder.
// ======================================
function [4:0] priority_encoder (input [15:0] in);
reg [4:0] penc;
begin
        casez(in)
                16'b0000_0000_0000_0000: penc = 0;
                16'b????_????_????_???1: penc = 1;
                16'b????_????_????_??10: penc = 2;
                16'b????_????_????_?100: penc = 3;
                16'b????_????_????_1000: penc = 4;
                16'b????_????_???1_0000: penc = 5;
                16'b????_????_??10_0000: penc = 6;
                16'b????_????_?100_0000: penc = 7;
                16'b????_????_1000_0000: penc = 8;
                16'b????_???1_0000_0000: penc = 9;
                16'b????_??10_0000_0000: penc = 10;
                16'b????_?100_0000_0000: penc = 11;
                16'b????_1000_0000_0000: penc = 12;
                16'b???1_0000_0000_0000: penc = 13;
                16'b??10_0000_0000_0000: penc = 14;
                16'b?100_0000_0000_0000: penc = 15;
                16'b1000_0000_0000_0000: penc = 16;
        endcase

        priority_encoder = penc;

end
endfunction

// ========================================
// Generate new transfer list.
// ========================================
function [15:0] new_transfer_list ( input [15:0] tlist, input [3:0] penc );
begin
        new_transfer_list = tlist & ~((1'd1 << penc) >> 1'd1); 
end
endfunction

endmodule
