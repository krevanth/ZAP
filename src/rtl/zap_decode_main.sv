//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//
// This module decodes 32-bit mode32 instructions into an internal wide
// instruction format that is understood by downstream logic.
//

module zap_decode_main #(
        // Number of architectural registers.
        parameter [31:0] ARCH_REGS = 32'd32,

        // Number of arithm. opcodes
        parameter [31:0] ALU_OPS   = 32'd32,

        // Total shift operations supported.
        parameter [31:0] SHIFT_OPS = 32'd6,

        // Number of physical registers.
        parameter [31:0] PHY_REGS = 32'd46,

        // CPSR mode.
        parameter [31:0] CPSR_MODE = 32'd4
)
(
        output logic  [64*8-1:0]                  o_decompile, // For debug purposes.
        input  logic                              i_uop_last,
        output logic                              o_uop_last,

        // -------------------
        // Inputs.
        // -------------------

        // Clock and reset.
        input   logic                            i_clk,
        input   logic                            i_reset,

        // Branch state.
        input   logic     [1:0]                  i_taken,
        input   logic     [31:0]                 i_ppc_ff,

        // Switch
        input   logic                            i_switch,

        // mode16 undefined.
        input   logic                            i_mode16_und,

        // Force 32-bit
        input   logic                            i_force32align,

        // Clear and stall signals. High to low priority.
        input logic                              i_clear_from_writeback, // | Priority
        input logic                              i_data_stall,           // |
        input logic                              i_clear_from_alu,       // |
        input logic                              i_stall_from_shifter,   // |
        input logic                              i_stall_from_issue,     // V

        // Interrupt events.
        input   logic                            i_irq,
        input   logic                            i_fiq,
        input   logic                            i_abt,

        // PC input.
        input logic  [31:0]                      i_pc_ff,
        input logic  [31:0]                      i_pc_plus_8_ff,

        // CPU mode. Taken from CPSR.
        input   logic    [CPSR_MODE:0]            i_cpsr_ff_mode, // Mode.

        // Instruction input.
        input     logic  [35:0]                  i_instruction,
        input     logic                          i_instruction_valid,

        // ------------------------
        // Outputs.
        // ------------------------

        // Predicted program counter.
        output  logic   [31:0]                    o_ppc_ff,

        // This signal is used to check the validity of a pipeline stage.
        output   logic    [3:0]                   o_condition_code_ff,

        //
        // Where the primary output of the instruction must go to. Make this RAZ
        // to throw away the primary output to a void.
        //
        output   logic    [$clog2(PHY_REGS)-1:0] o_destination_index_ff,

        //
        // The ALU source is the source that is fed directly to the ALU without the
        // barrel shifter. For multiplication, o_alu_source simply becomes an operand.
        // For alu_source_ff, if bit 32 is 1, then [31:0] is a constant else
        // [31:0] is a register index (lower 6-bit effectively).
        //
        output   logic    [32:0]                  o_alu_source_ff,
        output   logic    [$clog2(ALU_OPS)-1:0]   o_alu_operation_ff,

        //
        // Stuff related to the shifter. For multiplication, the source and length
        // simply become two operands. For shift_source_ff and shift_length_ff,
        // bit 32 has the same meaning as for o_alu_source_ff.
        //
        output   logic    [32:0]                  o_shift_source_ff,
        output   logic    [$clog2(SHIFT_OPS)-1:0] o_shift_operation_ff,
        output   logic    [32:0]                  o_shift_length_ff,

        //
        // Update the flags. Note that writing to CPSR will cause a flag-update (if
        // you asked for) even if this is 0.
        //
        output  logic                             o_flag_update_ff,

        // Things related to memory operations.

        //
        // Data register index. Register is read
        // for stores and written for loads.
        //
        output  logic   [$clog2(PHY_REGS)-1:0]    o_mem_srcdest_index_ff,

        // Load or store.
        output  logic                             o_mem_load_ff,
        output  logic                             o_mem_store_ff,

        // Indicate pre-ALU tap for address since pre-index.
        output  logic                             o_mem_pre_index_ff,

        // Access size and type.

        // Unsigned byte access.
        output  logic                             o_mem_unsigned_byte_enable_ff,

        // Signed byte access.
        output  logic                             o_mem_signed_byte_enable_ff,

        // Signed halfword access.
        output  logic                             o_mem_signed_halfword_enable_ff,

        // Unsigned halfword access.
        output  logic                             o_mem_unsigned_halfword_enable_ff,

        // Force user view of memory.
        output  logic                             o_mem_translate_ff,

        // PC output. Simply clocked out.
        output  logic  [31:0]                     o_pc_plus_8_ff,
        output  logic  [31:0]                     o_pc_ff,

        // Switch.
        output  logic                             o_switch_ff,

        // Interrupts.
        output  logic                             o_irq_ff, // Goes through mask.
        output  logic                             o_fiq_ff, // Goes through mask.
        output  logic                             o_abt_ff, // Clocked out.
        output  logic                             o_und_ff, // Undefined instr.
        output  logic                             o_swi_ff, // SWI encountered.
        // EXECUTE tests for condition validity and triggers SWI.

        // Force 32-bit alignment on memory accesses. Simply clocked out.
        output logic                              o_force32align_ff,

        // Branch state. Simply clocked out.
        output logic    [1:0]                     o_taken_ff
);

// ----------------------------------------------------------------------------

`include "zap_defines.svh"
`include "zap_localparams.svh"
`include "zap_functions.svh"

logic    [3:0]                   o_condition_code_nxt;
logic    [$clog2(PHY_REGS )-1:0] o_destination_index_nxt;
logic    [32:0]                  o_alu_source_nxt;
logic    [$clog2(ALU_OPS)-1:0]   o_alu_operation_nxt;
logic    [32:0]                  o_shift_source_nxt;
logic    [$clog2(SHIFT_OPS)-1:0] o_shift_operation_nxt;
logic    [32:0]                  o_shift_length_nxt;
logic                            o_flag_update_nxt;
logic   [$clog2(PHY_REGS )-1:0]  o_mem_srcdest_index_nxt; // Data register.
logic                            o_mem_load_nxt;          // Type of operation...
logic                            o_mem_store_nxt;
logic                            o_mem_pre_index_nxt;     // Indicate pre-ALU tap for address.
logic                            o_mem_unsigned_byte_enable_nxt;// Byte enable (unsigned).
logic                            o_mem_signed_byte_enable_nxt;
logic                            o_mem_signed_halfword_enable_nxt;
logic                            o_mem_unsigned_halfword_enable_nxt;
logic                            o_mem_translate_nxt;    // Force user's view of memory.
logic                            o_irq_nxt;
logic                            o_fiq_nxt;
logic                            o_abt_nxt;
logic                            o_swi_nxt;
logic                            o_und_nxt;
logic                            o_switch_nxt;
logic [$clog2(ARCH_REGS)-1:0]    destination_index_nxt;
logic [32:0]                     alu_source_nxt;
logic [32:0]                     shift_source_nxt;
logic [32:0]                     shift_length_nxt;
logic [$clog2(ARCH_REGS)-1:0]    mem_srcdest_index_nxt;

// ----------------------------------------------------------------------------

// Abort
assign       o_abt_nxt = i_abt && i_instruction_valid;

// Pass IRQ only when no FIQ and no abort.
assign       o_irq_nxt = !i_fiq && i_irq && !o_abt_nxt;

// Pass FIQ only when no abort.
assign       o_fiq_nxt = i_fiq && !o_abt_nxt;

//
// This section translates the indices from the decode stage converts
// into a physical index. This is needed because the decode.v module extracts
// architectural register numbers.
//
assign       o_destination_index_nxt = // Always a register so no need for IMMED_EN.
        translate ( destination_index_nxt, i_cpsr_ff_mode );

assign       o_alu_source_nxt =
        (alu_source_nxt[32] == IMMED_EN ) ? // Constant...?
        alu_source_nxt : // Pass constant on.
        {27'd0, translate ( alu_source_nxt[4:0], i_cpsr_ff_mode )}; // Translate index.

assign       o_shift_source_nxt =
        (shift_source_nxt[32] == IMMED_EN ) ? // Constant...?
        shift_source_nxt : // Pass constant on.
        {27'd0, translate ( shift_source_nxt[4:0], i_cpsr_ff_mode )}; // Translate index.

assign       o_shift_length_nxt =
        (shift_length_nxt[32] == IMMED_EN ) ? // Constant...?
        shift_length_nxt : // Pass constant on.
        {27'd0, translate ( shift_length_nxt[4:0], i_cpsr_ff_mode )}; // Translate index.

assign       o_mem_srcdest_index_nxt = // Always a register so no need for IMMED_EN.
        translate ( mem_srcdest_index_nxt, i_cpsr_ff_mode );


// ----------------------------------------------------------------------------

//
// The actual decision whether or not to execute this is taken in EX stage.
// At this point, we don't do anything with the SWI except take note.
//
assign  o_swi_nxt = (&i_instruction[27:24]) && !(i_irq || i_fiq || i_abt);

// ----------------------------------------------------------------------------

logic [64*8-1:0] decompile_tmp;

// Flop the outputs to break the pipeline at this point.
always_ff @ ( posedge i_clk )
begin
        if ( i_reset )
        begin
                // Assigns to X on reset means that these registers should NOT
                // be reset.
                o_destination_index_ff                  <= 'x;
                o_alu_source_ff                         <= 'x;
                o_alu_operation_ff                      <= 'x;
                o_shift_source_ff                       <= 'x;
                o_shift_operation_ff                    <= 'x;
                o_shift_length_ff                       <= 'x;
                o_flag_update_ff                        <= 'x;
                o_mem_srcdest_index_ff                  <= 'x;
                o_mem_load_ff                           <= 'x;
                o_mem_store_ff                          <= 'x;
                o_mem_pre_index_ff                      <= 'x;
                o_mem_unsigned_byte_enable_ff           <= 'x;
                o_mem_signed_byte_enable_ff             <= 'x;
                o_mem_signed_halfword_enable_ff         <= 'x;
                o_mem_unsigned_halfword_enable_ff       <= 'x;
                o_mem_translate_ff                      <= 'x;
                o_pc_plus_8_ff                          <= 'x;
                o_pc_ff                                 <= 'x;
                o_switch_ff                             <= 'x;
                o_force32align_ff                       <= 'x;
                o_decompile                             <= 'x;
                o_ppc_ff                                <= 'x;
                o_irq_ff                                <= 0;
                o_fiq_ff                                <= 0;
                o_swi_ff                                <= 0;
                o_abt_ff                                <= 0;
                o_condition_code_ff                     <= NV;
                o_und_ff                                <= 0;
                o_taken_ff                              <= 0;
                o_uop_last                              <= 0;
        end
        else if ( i_clear_from_writeback || (i_clear_from_alu && !i_data_stall ) )
        begin
                o_irq_ff                                <= 0;
                o_fiq_ff                                <= 0;
                o_swi_ff                                <= 0;
                o_abt_ff                                <= 0;
                o_condition_code_ff                     <= NV;
                o_und_ff                                <= 0;
                o_taken_ff                              <= 0;
                o_uop_last                              <= 0;
                o_destination_index_ff                  <= 'x;
                o_alu_source_ff                         <= 'x;
                o_alu_operation_ff                      <= 'x;
                o_shift_source_ff                       <= 'x;
                o_shift_operation_ff                    <= 'x;
                o_shift_length_ff                       <= 'x;
                o_flag_update_ff                        <= 'x;
                o_mem_srcdest_index_ff                  <= 'x;
                o_mem_load_ff                           <= 'x;
                o_mem_store_ff                          <= 'x;
                o_mem_pre_index_ff                      <= 'x;
                o_mem_unsigned_byte_enable_ff           <= 'x;
                o_mem_signed_byte_enable_ff             <= 'x;
                o_mem_signed_halfword_enable_ff         <= 'x;
                o_mem_unsigned_halfword_enable_ff       <= 'x;
                o_mem_translate_ff                      <= 'x;
                o_pc_plus_8_ff                          <= 'x;
                o_pc_ff                                 <= 'x;
                o_switch_ff                             <= 'x;
                o_force32align_ff                       <= 'x;
                o_decompile                             <= 'x;
                o_ppc_ff                                <= 'x;

        end
        // If no stall, only then update...
        else if ( !i_data_stall && !i_stall_from_issue && !i_stall_from_shifter )
        begin
                o_irq_ff                                <= o_irq_nxt;
                o_fiq_ff                                <= o_fiq_nxt;
                o_swi_ff                                <= o_swi_nxt;
                o_abt_ff                                <= o_abt_nxt;
                o_und_ff                                <= o_und_nxt | i_mode16_und;
                o_condition_code_ff                     <= o_condition_code_nxt;
                o_destination_index_ff                  <= o_destination_index_nxt;
                o_alu_source_ff                         <= o_alu_source_nxt;
                o_alu_operation_ff                      <= o_alu_operation_nxt;
                o_shift_source_ff                       <= o_shift_source_nxt;
                o_shift_operation_ff                    <= o_shift_operation_nxt;
                o_shift_length_ff                       <= o_shift_length_nxt;
                o_flag_update_ff                        <= o_flag_update_nxt;
                o_mem_srcdest_index_ff                  <= o_mem_srcdest_index_nxt;
                o_mem_load_ff                           <= o_mem_load_nxt;
                o_mem_store_ff                          <= o_mem_store_nxt;
                o_mem_pre_index_ff                      <= o_mem_pre_index_nxt;
                o_mem_unsigned_byte_enable_ff           <= o_mem_unsigned_byte_enable_nxt;
                o_mem_signed_byte_enable_ff             <= o_mem_signed_byte_enable_nxt;
                o_mem_signed_halfword_enable_ff         <= o_mem_signed_halfword_enable_nxt;
                o_mem_unsigned_halfword_enable_ff       <= o_mem_unsigned_halfword_enable_nxt;
                o_mem_translate_ff                      <= o_mem_translate_nxt;
                o_pc_plus_8_ff                          <= i_pc_plus_8_ff;
                o_pc_ff                                 <= i_pc_ff;
                o_switch_ff                             <= o_switch_nxt | i_switch;
                o_force32align_ff                       <= i_force32align;
                o_taken_ff                              <= i_taken;
                o_ppc_ff                                <= i_ppc_ff;
                o_decompile                             <= decompile_tmp;
                o_uop_last                              <= i_uop_last;
        end
end

// ----------------------------------------------------------------------------

// Bulk of the decode logic is here.
zap_decode #(
        .ARCH_REGS      (ARCH_REGS),
        .ALU_OPS        (ALU_OPS),
        .SHIFT_OPS      (SHIFT_OPS)
)
u_zap_decode (
        .i_irq(i_irq),
        .i_fiq(i_fiq),
        .i_abt(i_abt),
        .i_instruction(i_instruction[35:0]),
        .i_instruction_valid(i_instruction_valid),
        .o_condition_code(o_condition_code_nxt),
        .o_destination_index(destination_index_nxt),
        .o_alu_source(alu_source_nxt),
        .o_alu_operation(o_alu_operation_nxt),
        .o_shift_source(shift_source_nxt),
        .o_shift_operation(o_shift_operation_nxt),
        .o_shift_length(shift_length_nxt),
        .o_flag_update(o_flag_update_nxt),
        .o_mem_srcdest_index(mem_srcdest_index_nxt),
        .o_mem_load(o_mem_load_nxt),
        .o_mem_store(o_mem_store_nxt),
        .o_mem_pre_index(o_mem_pre_index_nxt),
        .o_mem_unsigned_byte_enable(o_mem_unsigned_byte_enable_nxt),
        .o_mem_signed_byte_enable(o_mem_signed_byte_enable_nxt),
        .o_mem_signed_halfword_enable(o_mem_signed_halfword_enable_nxt),
        .o_mem_unsigned_halfword_enable(o_mem_unsigned_halfword_enable_nxt),
        .o_mem_translate(o_mem_translate_nxt),
        .o_und(o_und_nxt),
        .o_switch(o_switch_nxt)
);

// ----------------------------------------------------------------------------

// Decompile


zap_decompile u_zap_decompile (
        .i_instruction  (i_instruction[35:0]),
        .i_dav          (i_instruction_valid),
        .o_decompile    (decompile_tmp)
);


endmodule : zap_decode_main

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
