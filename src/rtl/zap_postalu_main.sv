//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
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
// This is the post ALU stage for RAM reads
//

module zap_postalu_main #(
        parameter logic [31:0] PHY_REGS  = 32'd46, // Number of physical registers.
        parameter logic [31:0] FLAG_WDT  = 32'd32  // Width of active CPSR.
)
(
        // ------------------------------------------------------------------
        // Control signals.
        // ------------------------------------------------------------------

        input logic                              i_clk,                       // Clock.
        input logic                              i_reset,                     // sync active high reset.
        input logic                              i_clear_from_writeback,      // Clear unit.
        input logic                              i_data_stall,                // DCACHE stall.
        input logic                              i_data_mem_fault,

        // -----------------------------------------------------------------
        // Inputs
        // -----------------------------------------------------------------

        input logic                              i_uop_last,
        input logic [64*8-1:0]                   i_decompile,
        input logic                              i_decompile_valid,
        input logic [31:0]                       i_alu_result_ff,                       // ALU result flopped version.
        input logic                              i_dav_ff,                              // Instruction valid.
        input logic [FLAG_WDT-1:0]               i_flags_ff,                            // Output flags (CPSR).
        input logic [$clog2   (PHY_REGS)-1:0]    i_destination_index_ff,                // Destination register index.
        input logic                              i_abt_ff,                              // Instruction abort flagged.
        input logic                              i_irq_ff,                              // IRQ flagged.
        input logic                              i_fiq_ff,                              // FIQ flagged.
        input logic                              i_swi_ff,                              // SWI flagged.
        input logic                              i_und_ff,                              // Flagged undefined instructions
        input logic [31:0]                       i_pc_plus_8_ff,                        // Instr address + 8.
        input logic  [$clog2   (PHY_REGS)-1:0]   i_mem_srcdest_index_ff,                // LD/ST data register.
        input logic                              i_mem_load_ff,                         // LD/ST load indicator.
        input logic [31:0]                       i_mem_address_ff,                      // LD/ST address to access.
        input logic                              i_mem_unsigned_byte_enable_ff,         // uint8_t
        input logic                              i_mem_signed_byte_enable_ff,           // int8_t
        input logic                              i_mem_signed_halfword_enable_ff,       // int16_t
        input logic                              i_mem_unsigned_halfword_enable_ff,     // uint16_t
        input logic                              i_mem_translate_ff,                    // LD/ST force user view of memory.
        input logic                              i_data_wb_we_ff,
        input logic                              i_data_wb_cyc_ff,
        input logic                              i_data_wb_stb_ff,
        input logic [31:0]                       i_data_wb_dat_ff,
        input logic [3:0]                        i_data_wb_sel_ff,

        // -----------------------------------------------------------------
        // Outputs
        // -----------------------------------------------------------------

        output logic                              o_uop_last,
        output logic      [64*8-1:0]              o_decompile,                   // Debugging output.
        output logic                              o_decompile_valid,             // Decompile EXCL valid.
        output logic [31:0]                       o_alu_result_ff,               // ALU result flopped version.
        output logic                              o_dav_ff,                      // Instruction valid.
        output logic [FLAG_WDT-1:0]               o_flags_ff,                    // Output flags (CPSR).
        output logic [$clog2   (PHY_REGS)-1:0]    o_destination_index_ff,        // Destination register index.
        output logic                              o_abt_ff,                      // Instruction abort flagged.
        output logic                              o_irq_ff,                      // IRQ flagged.
        output logic                              o_fiq_ff,                      // FIQ flagged.
        output logic                              o_swi_ff,                      // SWI flagged.
        output logic                              o_und_ff,                      // Flagged undefined instructions
        output logic [31:0]                       o_pc_plus_8_ff,                // Instr address + 8.
        output logic  [$clog2   (PHY_REGS)-1:0]   o_mem_srcdest_index_ff,        // LD/ST data register.
        output logic                              o_mem_load_ff,                 // LD/ST load indicator.
        output logic [31:0]                       o_mem_address_ff,              // LD/ST address to access.
        output logic                              o_mem_unsigned_byte_enable_ff, // uint8_t
        output logic                              o_mem_signed_byte_enable_ff,   // int8_t
        output logic                              o_mem_signed_halfword_enable_ff,   // int16_t
        output logic                              o_mem_unsigned_halfword_enable_ff, // uint16_t
        output logic                              o_mem_translate_ff,                // LD/ST force user view of memory.
        output logic                              o_data_wb_we_ff,
        output logic                              o_data_wb_cyc_ff,
        output logic                              o_data_wb_stb_ff,
        output logic [31:0]                       o_data_wb_dat_ff,
        output logic [3:0]                        o_data_wb_sel_ff
);

logic sleep_ff;

always_ff @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                sleep_ff                         <= 1'd0;
                o_dav_ff                         <= '0;
                o_decompile_valid                <= '0;
                o_uop_last                       <= '0;
                o_abt_ff                         <= '0;
                o_irq_ff                         <= '0;
                o_fiq_ff                         <= '0;
                o_swi_ff                         <= '0;
                o_und_ff                         <= '0;
                o_data_wb_cyc_ff                 <= '0;
                o_data_wb_stb_ff                 <= '0;

                o_alu_result_ff                  <= 'x;
                o_mem_srcdest_index_ff           <= 'x;
                o_mem_srcdest_index_ff           <= 'x;
                o_mem_load_ff                    <= 'x;
                o_mem_unsigned_byte_enable_ff    <= 'x;
                o_mem_signed_byte_enable_ff      <= 'x;
                o_mem_signed_halfword_enable_ff  <= 'x;
                o_mem_unsigned_halfword_enable_ff<= 'x;
                o_mem_translate_ff               <= 'x;
                o_decompile                      <= 'x;
                o_data_wb_sel_ff                 <= 'x;
                o_data_wb_dat_ff                 <= 'x;
                o_data_wb_we_ff                  <= 'x;
                o_flags_ff                       <= 'x;
                o_pc_plus_8_ff                   <= 'x;
                o_destination_index_ff           <= 'x;
        end
        else if ( i_clear_from_writeback )
        begin
                o_dav_ff                         <= '0;
                o_decompile_valid                <= '0;
                o_uop_last                       <= '0;
                o_mem_load_ff                    <= '0;
                o_dav_ff                         <= '0;
                o_abt_ff                         <= '0;
                o_irq_ff                         <= '0;
                o_fiq_ff                         <= '0;
                o_swi_ff                         <= '0;
                o_und_ff                         <= '0;
                sleep_ff                         <= '0;
                o_data_wb_cyc_ff                 <= '0;
                o_data_wb_stb_ff                 <= '0;

                o_alu_result_ff                  <= 'x;
                o_mem_srcdest_index_ff           <= 'x;
                o_mem_srcdest_index_ff           <= 'x;
                o_mem_load_ff                    <= 'x;
                o_mem_unsigned_byte_enable_ff    <= 'x;
                o_mem_signed_byte_enable_ff      <= 'x;
                o_mem_signed_halfword_enable_ff  <= 'x;
                o_mem_unsigned_halfword_enable_ff<= 'x;
                o_mem_translate_ff               <= 'x;
                o_decompile                      <= 'x;
                o_data_wb_sel_ff                 <= 'x;
                o_data_wb_dat_ff                 <= 'x;
                o_data_wb_we_ff                  <= 'x;
                o_flags_ff                       <= 'x;
                o_pc_plus_8_ff                   <= 'x;
                o_destination_index_ff           <= 'x;
        end
        else if ( !i_data_stall )
        begin
                if ( i_data_mem_fault || sleep_ff )
                begin
                        sleep_ff                         <= 1'd1;
                        o_dav_ff                         <= '0;
                        o_mem_load_ff                    <= '0;
                        o_dav_ff                         <= '0;
                        o_decompile_valid                <= '0;
                        o_uop_last                       <= '0;
                        o_abt_ff                         <= '0;
                        o_irq_ff                         <= '0;
                        o_fiq_ff                         <= '0;
                        o_swi_ff                         <= '0;
                        o_und_ff                         <= '0;
                        o_mem_load_ff                    <= '0;
                        o_data_wb_cyc_ff                 <= '0;
                        o_data_wb_stb_ff                 <= '0;

                        o_alu_result_ff                  <= 'x;
                        o_mem_srcdest_index_ff           <= 'x;
                        o_mem_srcdest_index_ff           <= 'x;
                        o_mem_load_ff                    <= 'x;
                        o_mem_unsigned_byte_enable_ff    <= 'x;
                        o_mem_signed_byte_enable_ff      <= 'x;
                        o_mem_signed_halfword_enable_ff  <= 'x;
                        o_mem_unsigned_halfword_enable_ff<= 'x;
                        o_mem_translate_ff               <= 'x;
                        o_decompile                      <= 'x;
                        o_data_wb_sel_ff                 <= 'x;
                        o_data_wb_dat_ff                 <= 'x;
                        o_data_wb_we_ff                  <= 'x;
                        o_flags_ff                       <= 'x;
                        o_pc_plus_8_ff                   <= 'x;
                        o_destination_index_ff           <= 'x;
                end
                else
                begin
                        o_decompile                      <= i_decompile;
                        o_decompile_valid                <= i_decompile_valid;
                        o_uop_last                       <= i_uop_last;
                        o_alu_result_ff                  <= i_alu_result_ff;
                        o_dav_ff                         <= i_dav_ff;
                        o_flags_ff                       <= i_flags_ff;
                        o_destination_index_ff           <= i_destination_index_ff;
                        o_abt_ff                         <= i_abt_ff;
                        o_irq_ff                         <= i_irq_ff;
                        o_fiq_ff                         <= i_fiq_ff;
                        o_swi_ff                         <= i_swi_ff;
                        o_und_ff                         <= i_und_ff;
                        o_pc_plus_8_ff                   <= i_pc_plus_8_ff;
                        o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;
                        o_mem_load_ff                    <= i_mem_load_ff;
                        o_mem_address_ff                 <= i_mem_address_ff;
                        o_mem_unsigned_byte_enable_ff    <= i_mem_unsigned_byte_enable_ff;
                        o_mem_signed_byte_enable_ff      <= i_mem_signed_byte_enable_ff;
                        o_mem_signed_halfword_enable_ff  <= i_mem_signed_halfword_enable_ff;
                        o_mem_unsigned_halfword_enable_ff<= i_mem_unsigned_halfword_enable_ff;
                        o_mem_translate_ff               <= i_mem_translate_ff;
                        o_data_wb_cyc_ff                 <= i_data_wb_cyc_ff;
                        o_data_wb_stb_ff                 <= i_data_wb_stb_ff;
                        o_data_wb_we_ff                  <= i_data_wb_we_ff;
                        o_data_wb_dat_ff                 <= i_data_wb_dat_ff;
                        o_data_wb_sel_ff                 <= i_data_wb_sel_ff;
                end
        end
end

endmodule : zap_postalu_main

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
