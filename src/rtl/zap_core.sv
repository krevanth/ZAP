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
// This is the ZAP core which contains the bare processor core without any
// cache or MMU. In other words, this is the bare pipeline.
//

module zap_core #(

        // For CP15 purposes.
        parameter logic [0:0]  CP15_L4_DEFAULT = 0,
        parameter logic [31:0] DATA_CACHE_SIZE = 1024,
        parameter logic [31:0] CODE_CACHE_SIZE = 1024,
        parameter logic [31:0] DATA_CACHE_LINE = 64,
        parameter logic [31:0] CODE_CACHE_LINE = 64,

        // Reset vector. Safe to not override.
        parameter logic [31:0] RESET_VECTOR     = 32'd0,

        // Initial CPSR. Safe to not override.
        parameter logic [31:0] CPSR_INIT        = {24'd0, 1'd1,1'd1,1'd0,5'b10011},

        // For CP15 purposes. Actual conversion is handled at a higher module.
        parameter logic BE_32_ENABLE            = 1'd0,

        // Number of branch predictor entries.
        parameter logic [31:0] BP_ENTRIES       = 32'd1024,

        // Depth of FIFO.
        parameter logic [31:0] FIFO_DEPTH       = 32'd4,

        // RAS depth.
        parameter logic [31:0] RAS_DEPTH        = 32'd4,

        // CPSR mode.
        parameter logic [31:0] CPSR_MODE        = 32'd4
)
(

// ------------------------------------------------
// Trace port
// ------------------------------------------------

output logic [1023:0]                    o_trace,
output logic                             o_trace_valid,
output logic                             o_trace_uop_last,

// ------------------------------------------------
// Clock and reset. Reset is synchronous.
// ------------------------------------------------

input logic                              i_clk,
input logic                              i_reset,

// -------------------------------------------------
// Wishbone memory access for data.
// -------------------------------------------------

output logic                             o_data_wb_we,
output logic                             o_data_wb_cyc,
output logic                             o_data_wb_stb,
output logic[31:0]                       o_data_wb_adr,
input logic                              i_data_wb_ack,
input logic                              i_data_wb_err,
input logic  [31:0]                      i_data_wb_dat,
output logic [31:0]                      o_data_wb_dat,
output logic  [3:0]                      o_data_wb_sel,

// Next state stuff for Wishbone data.
output logic [31:0]                      o_data_wb_adr_nxt,

// Check.
output logic [31:0]                      o_data_wb_adr_check,
output logic                             o_data_wb_we_check,
output logic                             o_data_wb_re_check,

// Force user view.
output logic                             o_mem_translate,

// --------------------------------------------------
// Interrupts. Active high.
// --------------------------------------------------

input logic                              i_fiq,                  // FIQ signal.
input logic                              i_irq,                  // IRQ signal.

// ---------------------------------------------------
// Wishbone instruction access ports.
// ---------------------------------------------------

output logic     [31:0]                  o_instr_wb_adr, // Code address.
output logic                             o_instr_wb_cyc, // Always 1.
output logic                             o_instr_wb_stb, // Always 1.
output logic                             o_instr_wb_we,  // Always 0.
input logic [31:0]                       i_instr_wb_dat, // A 32-bit ZAP instruction.
input logic                              i_instr_wb_ack, // Instruction available.
input logic                              i_instr_wb_err, // Instruction abort fault.
output logic [3:0]                       o_instr_wb_sel, // wishbone byte select.

// Instruction wishbone nxt ports.
output logic     [31:0]                  o_instr_wb_adr_nxt,

// Check address.
output logic    [31:0]                   o_instr_wb_adr_check,

// Determines user or supervisory mode. Cache must use this for VM.
output logic      [CPSR_MODE:0]           o_cpsr,

// -----------------------------------------------------
// For MMU/cache connectivity.
// -----------------------------------------------------

output logic                             o_code_stall,
input logic      [31:0]                  i_fsr,
input logic      [31:0]                  i_far,
output logic      [31:0]                 o_dac,
output logic      [31:0]                 o_baddr,
output logic                             o_mmu_en,
output logic      [1:0]                  o_sr,
output logic      [7:0]                  o_pid,
output logic                             o_dcache_inv,
output logic                             o_icache_inv,
output logic                             o_dcache_clean,
output logic                             o_icache_clean,
output logic                             o_dtlb_inv,
output logic                             o_itlb_inv,
output logic                             o_dcache_en,
output logic                             o_icache_en,
input   logic                            i_dcache_inv_done,
input   logic                            i_icache_inv_done,
input   logic                            i_dcache_clean_done,
input   logic                            i_icache_clean_done,
input   logic                            i_icache_err2,
input   logic                            i_dcache_err2,

// -----------------------------------------------------
// Background load.
// -----------------------------------------------------

input   logic [63:0]                     i_dc_reg_idx, // Register to load to.
input   logic [31:0]                     i_dc_reg_dat, // Register data.
input   logic [63:0]                     i_dc_lock,    // Register that is locked.
output  logic [63:0]                     o_dc_reg_idx, // Register index.
output  logic [5:0]                      o_dc_reg_idx_bin // Binary index.

);

`include "zap_localparams.svh"
`include "zap_defines.svh"

localparam [31:0] ARCH_REGS = 32;
localparam [31:0] ALU_OPS   = 64;
localparam [31:0] SHIFT_OPS = 8;
localparam [31:0] PHY_REGS  = TOTAL_PHY_REGS;
localparam [31:0] FLAG_WDT  = 32;

// Low Bandwidth Coprocessor (COP) I/F to CP15 control block.
logic                             copro_done;        // COP done.
logic                             copro_dav;         // COP command valid.
logic  [31:0]                     copro_word;        // COP command.
logic                             copro_reg_en;      // COP controls registers.
logic      [$clog2(PHY_REGS)-1:0] copro_reg_wr_index;// Reg. file write index.
logic      [$clog2(PHY_REGS)-1:0] copro_reg_rd_index;// Reg. file read index.
logic      [31:0]                 copro_reg_wr_data; // Reg. file write data.
logic     [31:0]                  copro_reg_rd_data; // Reg. file read data.

logic                            reset;               // Tied to i_reset.
logic                            shelve;              // From writeback.
logic                            fiq;                 // Tied to FIQ.
logic                            irq;                 // Tied to IRQ.

logic                            l4_enable;

// Clear and stall signals.
logic                            stall_from_decode;
logic                            clear_from_alu;
logic                            stall_from_issue;
logic                            clear_from_writeback;
logic                            data_stall;
logic                            fifo_full;
logic                            code_stall;
logic                            instr_valid;
logic                            pipeline_is_not_empty;

// Fetch
logic [31:0]                     fetch_instruction;  // Instruction from the fetch unit.
logic                            fetch_valid;        // Instruction valid from the fetch unit.
logic                            fetch_instr_abort;  // abort indicator.
logic [31:0]                     fetch_pc_plus_8_ff; // PC + 8 generated from the fetch unit.
logic [1:0]                      fetch_bp_state;
logic [32:0]                     fetch_pred;

// FIFO.
logic [31:0]                     fifo_pc_plus_8;
logic                            fifo_valid;
logic                            fifo_instr_abort;
logic [31:0]                     fifo_instruction;
logic [1:0]                      fifo_bp_state;
logic [32:0]                     fifo_pred;

// Compressed decoder.
logic                            mode16_irq;
logic                            mode16_fiq;
logic                            mode16_iabort;
logic [34:0]                     mode16_instruction;
logic                            mode16_valid;
logic                            mode16_und;
logic                            mode16_force32;
logic [1:0]                      mode16_bp_state;
logic [31:0]                     mode16_pc_plus_8_ff;
logic [32:0]                     mode16_pred;

// Predecode
logic [31:0]                     predecode_pc_plus_8;
logic [31:0]                     predecode_pc;
logic                            predecode_irq;
logic                            predecode_fiq;
logic                            predecode_abt;
logic [39:0]                     predecode_inst;
logic                            predecode_val;
logic                            predecode_force32;
logic                            predecode_und;
logic [1:0]                      predecode_taken;
logic [31:0]                     predecode_ppc_ff;
logic                            predecode_clear_btb;
logic                            predecode_uop_last;
logic                            predecode_switch;

// Decode
logic [3:0]                      decode_condition_code;
logic [$clog2(PHY_REGS)-1:0]     decode_destination_index;
logic [32:0]                     decode_alu_source_ff;
logic [$clog2(ALU_OPS)-1:0]      decode_alu_operation_ff;
logic [32:0]                     decode_shift_source_ff;
logic [$clog2(SHIFT_OPS)-1:0]    decode_shift_operation_ff;
logic [32:0]                     decode_shift_length_ff;
logic                            decode_flag_update_ff;
logic [$clog2(PHY_REGS)-1:0]     decode_mem_srcdest_index_ff;
logic                            decode_mem_load_ff;
logic                            decode_mem_store_ff;
logic                            decode_mem_pre_index_ff;
logic                            decode_mem_unsigned_byte_enable_ff;
logic                            decode_mem_signed_byte_enable_ff;
logic                            decode_mem_signed_halfword_enable_ff;
logic                            decode_mem_unsigned_halfword_enable_ff;
logic                            decode_mem_translate_ff;
logic                            decode_irq_ff;
logic                            decode_fiq_ff;
logic                            decode_abt_ff;
logic                            decode_swi_ff;
logic [31:0]                     decode_pc_plus_8_ff;
logic [31:0]                     decode_pc_ff;
logic                            decode_switch_ff;
logic                            decode_force32_ff;
logic                            decode_und_ff;
logic                            clear_from_decode;
logic [31:0]                     pc_from_decode;
logic [1:0]                      decode_taken_ff;
logic [31:0]                     decode_ppc_ff;
logic                            decode_uop_last;

// Issue
logic [3:0]                      issue_condition_code_ff;
logic [$clog2(PHY_REGS)-1:0]     issue_destination_index_ff;
logic [$clog2(ALU_OPS)-1:0]      issue_alu_operation_ff;
logic [$clog2(SHIFT_OPS)-1:0]    issue_shift_operation_ff;
logic                            issue_flag_update_ff;
logic [$clog2(PHY_REGS)-1:0]     issue_mem_srcdest_index_ff;
logic                            issue_mem_load_ff;
logic                            issue_mem_store_ff;
logic                            issue_mem_pre_index_ff;
logic                            issue_mem_unsigned_byte_enable_ff;
logic                            issue_mem_signed_byte_enable_ff;
logic                            issue_mem_signed_halfword_enable_ff;
logic                            issue_mem_unsigned_halfword_enable_ff;
logic                            issue_mem_translate_ff;
logic                            issue_irq_ff;
logic                            issue_fiq_ff;
logic                            issue_abt_ff;
logic                            issue_swi_ff;
logic [31:0]                     issue_alu_source_value_ff;
logic [31:0]                     issue_shift_source_value_ff;
logic [31:0]                     issue_shift_length_value_ff;
logic [31:0]                     issue_mem_srcdest_value_ff;
logic [32:0]                     issue_alu_source_ff;
logic [32:0]                     issue_shift_source_ff;
logic [31:0]                     issue_pc_plus_8_ff;
logic [31:0]                     issue_pc_ff;
logic                            issue_shifter_disable_ff;
logic                            issue_switch_ff;
logic                            issue_force32_ff;
logic                            issue_und_ff;
logic  [1:0]                     issue_taken_ff;
logic  [31:0]                    issue_ppc_ff;
logic                            issue_uop_last;

logic [$clog2(PHY_REGS)-1:0]     rd_index_0;
logic [$clog2(PHY_REGS)-1:0]     rd_index_1;
logic [$clog2(PHY_REGS)-1:0]     rd_index_2;
logic [$clog2(PHY_REGS)-1:0]     rd_index_3;

// Shift
logic [$clog2(PHY_REGS)-1:0]     shifter_mem_srcdest_index_ff;
logic                            shifter_mem_load_ff;
logic                            shifter_mem_store_ff;
logic                            shifter_mem_pre_index_ff;
logic                            shifter_mem_unsigned_byte_enable_ff;
logic                            shifter_mem_signed_byte_enable_ff;
logic                            shifter_mem_signed_halfword_enable_ff;
logic                            shifter_mem_unsigned_halfword_enable_ff;
logic                            shifter_mem_translate_ff;
logic [3:0]                      shifter_condition_code_ff;
logic [$clog2(PHY_REGS)-1:0]     shifter_destination_index_ff;
logic [$clog2(ALU_OPS)-1:0]      shifter_alu_operation_ff;
logic                            shifter_nozero_ff;
logic                            shifter_flag_update_ff;
logic [31:0]                     shifter_mem_srcdest_value_ff;
logic [31:0]                     shifter_alu_source_value_ff;
logic [31:0]                     shifter_shifted_source_value_ff;
logic                            shifter_shift_carry_ff;
logic                            shifter_shift_sat_ff;
logic [31:0]                     shifter_pc_plus_8_ff;
logic [31:0]                     shifter_pc_ff;
logic                            shifter_irq_ff;
logic                            shifter_fiq_ff;
logic                            shifter_abt_ff;
logic                            shifter_swi_ff;
logic                            shifter_switch_ff;
logic                            shifter_force32_ff;
logic                            shifter_und_ff;
logic                            stall_from_shifter;
logic [1:0]                      shifter_taken_ff;
logic [31:0]                     shifter_ppc_ff;
logic                            shifter_uop_last;

// ALU
logic [31:0]                     alu_x_result;
logic [1:0]                      alu_x_valid;
logic [31:0]                     alu_alu_result_nxt;
logic [31:0]                     alu_alu_result_ff;
logic                            alu_abt_ff;
logic                            alu_irq_ff;
logic                            alu_fiq_ff;
logic                            alu_swi_ff;
logic                            alu_dav_ff;
logic                            alu_dav_nxt;
logic [31:0]                     alu_pc_plus_8_ff;
logic [31:0]                     pc_from_alu;
logic [$clog2(PHY_REGS)-1:0]     alu_destination_index_ff;
logic [FLAG_WDT-1:0]             alu_flags_ff;
logic [$clog2(PHY_REGS)-1:0]     alu_mem_srcdest_index_ff;
logic [1:0]                      alu_taken_ff;
logic                            alu_mem_load_ff;
logic                            alu_und_ff;
logic [31:0]                     alu_cpsr_nxt;
logic                            confirm_from_alu;
logic                            alu_sbyte_ff;
logic                            alu_ubyte_ff;
logic                            alu_shalf_ff;
logic                            alu_uhalf_ff;
logic [31:0]                     alu_address_ff;
logic                            alu_mem_translate_ff;
logic                            alu_data_wb_we;
logic                            alu_data_wb_cyc;
logic                            alu_data_wb_stb;
logic [31:0]                     alu_data_wb_dat;
logic [3:0]                      alu_data_wb_sel;
logic                            alu_decompile_valid;
logic                            alu_uop_last;
logic                            alu_force32align_ff;

// Post ALU 0
logic [31:0]                     postalu0_alu_result_ff;
logic                            postalu0_abt_ff;
logic                            postalu0_irq_ff;
logic                            postalu0_fiq_ff;
logic                            postalu0_swi_ff;
logic                            postalu0_dav_ff;
logic [31:0]                     postalu0_pc_plus_8_ff;
logic [$clog2(PHY_REGS)-1:0]     postalu0_destination_index_ff;
logic [FLAG_WDT-1:0]             postalu0_flags_ff;
logic [$clog2(PHY_REGS)-1:0]     postalu0_mem_srcdest_index_ff;
logic                            postalu0_mem_load_ff;
logic                            postalu0_und_ff;
logic                            postalu0_sbyte_ff;
logic                            postalu0_ubyte_ff;
logic                            postalu0_shalf_ff;
logic                            postalu0_uhalf_ff;
logic [31:0]                     postalu0_address_ff;
logic                            postalu0_mem_translate_ff;
logic                            postalu0_data_wb_we;
logic                            postalu0_data_wb_cyc;
logic                            postalu0_data_wb_stb;
logic [31:0]                     postalu0_data_wb_dat;
logic [3:0]                      postalu0_data_wb_sel;
logic                            postalu0_decompile_valid;
logic                            postalu0_uop_last;

// Post ALU 1
logic [31:0]                     postalu1_alu_result_ff;
logic                            postalu1_abt_ff;
logic                            postalu1_irq_ff;
logic                            postalu1_fiq_ff;
logic                            postalu1_swi_ff;
logic                            postalu1_dav_ff;
logic [31:0]                     postalu1_pc_plus_8_ff;
logic [$clog2(PHY_REGS)-1:0]     postalu1_destination_index_ff;
logic [FLAG_WDT-1:0]             postalu1_flags_ff;
logic [$clog2(PHY_REGS)-1:0]     postalu1_mem_srcdest_index_ff;
logic                            postalu1_mem_load_ff;
logic                            postalu1_und_ff;
logic                            postalu1_sbyte_ff;
logic                            postalu1_ubyte_ff;
logic                            postalu1_shalf_ff;
logic                            postalu1_uhalf_ff;
logic [31:0]                     postalu1_address_ff;
logic                            postalu1_mem_translate_ff;
logic                            postalu1_data_wb_we;
logic                            postalu1_data_wb_cyc;
logic                            postalu1_data_wb_stb;
logic [31:0]                     postalu1_data_wb_dat;
logic [3:0]                      postalu1_data_wb_sel;
logic                            postalu1_decompile_valid;
logic                            postalu1_uop_last;

// Post ALU
logic [31:0]                     postalu_alu_result_ff;
logic                            postalu_abt_ff;
logic                            postalu_irq_ff;
logic                            postalu_fiq_ff;
logic                            postalu_swi_ff;
logic                            postalu_dav_ff;
logic [31:0]                     postalu_pc_plus_8_ff;
logic [$clog2(PHY_REGS)-1:0]     postalu_destination_index_ff;
logic [FLAG_WDT-1:0]             postalu_flags_ff;
logic [$clog2(PHY_REGS)-1:0]     postalu_mem_srcdest_index_ff;
logic                            postalu_mem_load_ff;
logic                            postalu_und_ff;
logic                            postalu_sbyte_ff;
logic                            postalu_ubyte_ff;
logic                            postalu_shalf_ff;
logic                            postalu_uhalf_ff;
logic [31:0]                     postalu_address_ff;
logic                            postalu_mem_translate_ff;
logic                            postalu_decompile_valid;
logic                            postalu_uop_last;

// Memory
logic [31:0]                     memory_alu_result_ff;
logic [$clog2(PHY_REGS)-1:0]     memory_destination_index_ff;
logic [$clog2(PHY_REGS)-1:0]     memory_mem_srcdest_index_ff;
logic                            memory_dav_ff;
logic [31:0]                     memory_pc_plus_8_ff;
logic                            memory_irq_ff;
logic                            memory_fiq_ff;
logic                            memory_swi_ff;
logic                            memory_instr_abort_ff;
logic                            memory_mem_load_ff;
logic  [FLAG_WDT-1:0]            memory_flags_ff;
logic  [31:0]                    memory_mem_rd_data;
logic                            memory_und_ff;
logic  [1:0]                     memory_data_abt_ff;
logic                            memory_decompile_valid;
logic                            memory_uop_last;

// Writeback
logic [31:0]                     rd_data_0;
logic [31:0]                     rd_data_1;
logic [31:0]                     rd_data_2;
logic [31:0]                     rd_data_3;
logic [31:0]                     cpsr_nxt;
logic [32:0]                     wb_pred;
logic [1:0]                      wb_taken;

// Decompile chain for debugging.
logic [64*8-1:0]                 decode_decompile;
logic [64*8-1:0]                 issue_decompile;
logic [64*8-1:0]                 shifter_decompile;
logic [64*8-1:0]                 alu_decompile;
logic [64*8-1:0]                 postalu_decompile;
logic [64*8-1:0]                 postalu0_decompile;
logic [64*8-1:0]                 postalu1_decompile;
logic [64*8-1:0]                 memory_decompile;
logic [64*8-1:0]                 rb_decompile;

logic [(8*8)-1:0] CPU_MODE;
logic unused;
assign unused = |{rb_decompile, CPU_MODE, alu_cpsr_nxt[31:30], alu_cpsr_nxt[28:0],
                 predecode_inst[39:36], postalu_mem_translate_ff,
                 i_dc_reg_idx[63:PHY_REGS]};

assign o_cpsr                   = alu_flags_ff[ZAP_CPSR_MODE:0];
assign o_data_wb_adr            = {postalu_address_ff[31:2], 2'd0};
assign o_data_wb_adr_nxt        = {alu_address_ff[31:2], 2'd0};
assign o_instr_wb_we            = 1'd0;
assign o_instr_wb_sel           = 4'b1111;
assign reset                    = i_reset;
assign irq                      = i_irq;
assign fiq                      = i_fiq;

assign data_stall   = o_data_wb_stb & o_data_wb_cyc & ~i_data_wb_ack;
assign instr_valid  = o_instr_wb_stb & o_instr_wb_cyc & i_instr_wb_ack  & ~shelve;

//
// CP registers are changed only when pipe ahead of it is EMPTY. Such
// instructions can be used as fences in ZAP.
//
assign pipeline_is_not_empty    = predecode_val                      ||
                                  (decode_condition_code    != NV)   ||
                                  (issue_condition_code_ff  != NV)   ||
                                  (shifter_condition_code_ff!= NV)   ||
                                  alu_dav_ff                         ||
                                  postalu0_dav_ff                    ||
                                  postalu1_dav_ff                    ||
                                  postalu_dav_ff                     ||
                                  memory_dav_ff                      ||
                                  (|i_dc_lock);

assign o_mem_translate = postalu1_mem_translate_ff;

assign code_stall = fifo_full |
                   (o_instr_wb_stb & o_instr_wb_cyc & ~i_instr_wb_ack);

assign o_data_wb_adr_check =  {postalu1_address_ff[31:2], 2'd0};
assign o_data_wb_we_check  =   postalu1_data_wb_we && postalu1_data_wb_cyc;
assign o_data_wb_re_check  =  !postalu1_data_wb_we && postalu1_data_wb_cyc;
assign o_code_stall        =   code_stall;

always_comb
begin
        o_dc_reg_idx                               = 64'd0;
        o_dc_reg_idx[postalu_mem_srcdest_index_ff] = 1'd1;
end

assign o_dc_reg_idx_bin = postalu_mem_srcdest_index_ff;

localparam [31:0] MIN_SAT = {1'd1, {31{1'd0}}}; // Smallest -ve value.
localparam [31:0] MAX_SAT = {1'd0, {31{1'd1}}}; // Largest +ve value.

logic [31:0] alu_x_ppr; // alu_result_ff passes through this.

//
// ALU outputs CLZ and saturation on parallel ports. The saturation
// must be combined with overflow to get the actual result.
//
// By not doing this in the ALU itself but in the next stage, it
// improves processor timing.
//
always_comb
begin
        case (alu_x_valid)
        2'b00   : alu_x_ppr = alu_alu_result_ff;// Normal
        2'b01   : alu_x_ppr = alu_x_result;     // CLZ

        // Saturation
        2'b10   : alu_x_ppr = alu_flags_ff[27] ? // Overflow set ?
                ( alu_x_result[0] ? MIN_SAT : MAX_SAT ) :
                  alu_alu_result_ff ; // Pass on normal result.
        default : alu_x_ppr = {32{1'dx}};
        endcase
end


/////////////////////////////////
// Instantiations
/////////////////////////////////

//
// Instruction fetch stage.
//
zap_fetch_main u_zap_fetch_main (
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_code_stall                   (code_stall),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_clear_from_decode            (clear_from_decode),
        .i_clear_from_alu               (clear_from_alu),
        .i_taken                        (wb_taken),
        .i_pred                         (wb_pred),
        .i_pc_ff                        (o_instr_wb_adr),
        .i_instruction                  (i_instr_wb_dat),
        .i_valid                        (i_icache_err2  ? 1'd0  : instr_valid),
        .i_instr_abort                  (i_icache_err2  ? 1'd0  : i_instr_wb_err),
        .i_cpsr_ff_t                    (alu_flags_ff[T]),

        // Output.
        .o_instruction                  (fetch_instruction),
        .o_valid                        (fetch_valid),
        .o_instr_abort                  (fetch_instr_abort),
        .o_pc_plus_8_ff                 (fetch_pc_plus_8_ff),
        /* verilator lint_off PINCONNECTEMPTY */
        .o_pc_ff                        (),
        /* verilator lint_on PINCONNECTEMPTY */
        .o_taken                        (fetch_bp_state),
        .o_pred                         (fetch_pred)
);

//
// Pre-fetch buffer.
//
zap_fifo #( .WDT(67 + 33), .DEPTH(FIFO_DEPTH) ) U_ZAP_FIFO (
        // Inputs
        .i_clk                          (i_clk),
        .i_reset                        (i_reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_write_inhibit                (code_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_data_stall                   (data_stall         && mode16_valid && fifo_valid ),
        .i_stall_from_shifter           (stall_from_shifter && mode16_valid && fifo_valid ),
        .i_stall_from_issue             (stall_from_issue   && mode16_valid && fifo_valid ),
        .i_stall_from_decode            (stall_from_decode  && mode16_valid && fifo_valid ),
        .i_clear_from_decode            (clear_from_decode),
        .i_instr                        ({fetch_pc_plus_8_ff, fetch_instr_abort, fetch_instruction, fetch_bp_state, fetch_pred}),
        .i_valid                        (fetch_valid),

        // Outputs
        .o_instr                        ({fifo_pc_plus_8, fifo_instr_abort, fifo_instruction, fifo_bp_state, fifo_pred}),
        .o_valid                        (fifo_valid),
        .o_full                         (fifo_full)
);

//
// Compresssed instruction inflater.
//
zap_mode16_decoder_main u_zap_mode16_decoder (
.i_clk                                  (i_clk),
.i_reset                                (i_reset),
.i_clear_from_writeback                 (clear_from_writeback),
.i_clear_from_alu                       (clear_from_alu),

.i_data_stall                           (data_stall         && mode16_valid  ),
.i_stall_from_shifter                   (stall_from_shifter && mode16_valid  ),
.i_stall_from_issue                     (stall_from_issue   && mode16_valid  ),
.i_stall_from_decode                    (stall_from_decode  && mode16_valid  ),

.i_clear_from_decode                    (clear_from_decode),

.i_taken                                (fifo_bp_state),
.i_instruction                          (fifo_instruction),
.i_instruction_valid                    (fifo_valid),

.i_irq                                  (fifo_valid ? irq && !alu_flags_ff[I] : 1'd0),
// Pass interrupt only if mask = 0 and instruction exists.

.i_fiq                                  (fifo_valid ? fiq && !alu_flags_ff[F] : 1'd0),
// Pass interrupt only if mask = 0 and instruction exists.

.i_iabort                               (fifo_valid ? fifo_instr_abort : 1'd0),
// Pass abort only if instruction valid.

.o_iabort                               (mode16_iabort),
.i_cpsr_ff_t                            (alu_flags_ff[T]),
.i_pc_ff                                (alu_flags_ff[T] ? fifo_pc_plus_8 - 32'd4 : fifo_pc_plus_8 - 32'd8),
.i_pc_plus_8_ff                         (fifo_pc_plus_8),

.o_instruction                          (mode16_instruction),
.o_instruction_valid                    (mode16_valid),
.o_und                                  (mode16_und),
.o_force32_align                        (mode16_force32),

/* verilator lint_off PINCONNECTEMPTY */
.o_pc_ff                                (),
/* verilator lint_on PINCONNECTEMPTY */

.o_pc_plus_8_ff                         (mode16_pc_plus_8_ff),
.o_irq                                  (mode16_irq),
.o_fiq                                  (mode16_fiq),
.o_taken_ff                             (mode16_bp_state),

.i_pred                                 (fifo_pred),
.o_pred                                 (mode16_pred)
);

//
// Pre-decode stage. Handles COP instructions and UOP sequencing.
//
zap_predecode_main #(
        .PHY_REGS(PHY_REGS),
        .RAS_DEPTH(RAS_DEPTH)
)
u_zap_predecode (
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (reset),

        .i_clear_from_writeback         (clear_from_writeback),
        .i_clear_from_alu               (clear_from_alu),

        .i_pred                         (mode16_pred),
        .o_clear_btb                    (predecode_clear_btb),

        .i_l4_enable                    (l4_enable),
        .o_switch_ff                    (predecode_switch),

        .i_data_stall                   (data_stall         ),
        .i_stall_from_shifter           (stall_from_shifter ),
        .i_stall_from_issue             (stall_from_issue   ),

        .i_irq                          (mode16_irq),
        .i_fiq                          (mode16_fiq),

        .i_abt                          (mode16_iabort),
        .i_pc_plus_8_ff                 (mode16_pc_plus_8_ff),
        .i_pc_ff                        (alu_flags_ff[T] ? mode16_pc_plus_8_ff - 32'd4 :
                                         mode16_pc_plus_8_ff - 32'd8),

        .i_cpu_mode_t                   (alu_flags_ff[T]),
        .i_cpu_mode_mode                (alu_flags_ff[ZAP_CPSR_MODE:0]),

        .i_instruction                  (mode16_instruction),
        .i_instruction_valid            (mode16_valid),
        .i_taken                        (mode16_bp_state),

        .i_force32                      (mode16_force32),
        .i_und                          (mode16_und),

        .i_copro_done                   (copro_done),
        .i_pipeline_dav                 (pipeline_is_not_empty),

        // Output.
        .o_stall_from_decode            (stall_from_decode),
        .o_pc_plus_8_ff                 (predecode_pc_plus_8),

        .o_pc_ff                        (predecode_pc),
        .o_irq_ff                       (predecode_irq),
        .o_fiq_ff                       (predecode_fiq),
        .o_abt_ff                       (predecode_abt),
        .o_und_ff                       (predecode_und),

        .o_force32align_ff              (predecode_force32),

        .o_copro_dav_ff                 (copro_dav),
        .o_copro_word_ff                (copro_word),

        .o_clear_from_decode            (clear_from_decode),
        .o_pc_from_decode               (pc_from_decode),

        .o_instruction_ff               (predecode_inst),
        .o_instruction_valid_ff         (predecode_val),

        .o_taken_ff                     (predecode_taken),
        .o_ppc_ff                       (predecode_ppc_ff),

        .o_uop_last                     (predecode_uop_last)
                                        // Asserted to indicate last instruction of sequence.
);

//
// 32-bit instruction decoder.
//
zap_decode_main #(
        .ARCH_REGS(ARCH_REGS),
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS),
        .CPSR_MODE(ZAP_CPSR_MODE)
)
u_zap_decode_main (
        .o_decompile                    (decode_decompile),
        .i_uop_last                     (predecode_uop_last),
        .o_uop_last                     (decode_uop_last),

        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (reset),

        .i_clear_from_writeback         (clear_from_writeback),
        .i_clear_from_alu               (clear_from_alu),

        .i_data_stall                   (data_stall         ),
        .i_stall_from_shifter           (stall_from_shifter ),
        .i_stall_from_issue             (stall_from_issue   ),

        .i_switch                       (predecode_switch),
        .i_mode16_und                   (predecode_und),
        .i_irq                          (predecode_irq),
        .i_fiq                          (predecode_fiq),
        .i_abt                          (predecode_abt),
        .i_pc_plus_8_ff                 (predecode_pc_plus_8),
        .i_pc_ff                        (predecode_pc),

        .i_cpsr_ff_mode                 (alu_flags_ff[ZAP_CPSR_MODE:0]),

        .i_instruction                  (predecode_inst[35:0]),
        .i_instruction_valid            (predecode_val),
        .i_taken                        (predecode_taken),
        .i_ppc_ff                       (predecode_ppc_ff),
        .i_force32align                 (predecode_force32),

        // Output.
        .o_condition_code_ff            (decode_condition_code),
        .o_destination_index_ff         (decode_destination_index),
        .o_alu_source_ff                (decode_alu_source_ff),
        .o_alu_operation_ff             (decode_alu_operation_ff),
        .o_shift_source_ff              (decode_shift_source_ff),
        .o_shift_operation_ff           (decode_shift_operation_ff),
        .o_shift_length_ff              (decode_shift_length_ff),
        .o_flag_update_ff               (decode_flag_update_ff),
        .o_mem_srcdest_index_ff         (decode_mem_srcdest_index_ff),
        .o_mem_load_ff                  (decode_mem_load_ff),
        .o_mem_store_ff                 (decode_mem_store_ff),
        .o_mem_pre_index_ff             (decode_mem_pre_index_ff),
        .o_mem_unsigned_byte_enable_ff  (decode_mem_unsigned_byte_enable_ff),
        .o_mem_signed_byte_enable_ff    (decode_mem_signed_byte_enable_ff),
        .o_mem_signed_halfword_enable_ff(decode_mem_signed_halfword_enable_ff),
        .o_mem_unsigned_halfword_enable_ff (decode_mem_unsigned_halfword_enable_ff),
        .o_mem_translate_ff             (decode_mem_translate_ff),
        .o_pc_plus_8_ff                 (decode_pc_plus_8_ff),
        .o_pc_ff                        (decode_pc_ff),
        .o_switch_ff                    (decode_switch_ff),
        .o_irq_ff                       (decode_irq_ff),
        .o_fiq_ff                       (decode_fiq_ff),
        .o_abt_ff                       (decode_abt_ff),
        .o_swi_ff                       (decode_swi_ff),
        .o_und_ff                       (decode_und_ff),
        .o_force32align_ff              (decode_force32_ff),
        .o_taken_ff                     (decode_taken_ff),
        .o_ppc_ff                       (decode_ppc_ff)
);

//
// Issue stage. Performs register read and dependency checks.
//
zap_issue_main #(
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS)

)
u_zap_issue_main
(
        .i_uop_last(decode_uop_last),
        .o_uop_last(issue_uop_last),

        .i_decompile(decode_decompile),
        .o_decompile(issue_decompile),

        .i_und_ff(decode_und_ff),
        .o_und_ff(issue_und_ff),

        .i_taken_ff(decode_taken_ff),
        .o_taken_ff(issue_taken_ff),

        .i_ppc_ff (decode_ppc_ff),
        .o_ppc_ff (issue_ppc_ff),

        .i_pc_ff(decode_pc_ff),
        .o_pc_ff(issue_pc_ff),

        // Inputs
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_stall_from_shifter           (stall_from_shifter),
        .i_data_stall                   (data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_pc_plus_8_ff                 (decode_pc_plus_8_ff),
        .i_condition_code_ff            (decode_condition_code),
        .i_destination_index_ff         (decode_destination_index),
        .i_alu_source_ff                (decode_alu_source_ff),
        .i_alu_operation_ff             (decode_alu_operation_ff),
        .i_shift_source_ff              (decode_shift_source_ff),
        .i_shift_operation_ff           (decode_shift_operation_ff),
        .i_shift_length_ff              (decode_shift_length_ff),
        .i_flag_update_ff               (decode_flag_update_ff),
        .i_mem_srcdest_index_ff         (decode_mem_srcdest_index_ff),
        .i_mem_load_ff                  (decode_mem_load_ff),
        .i_mem_store_ff                 (decode_mem_store_ff),
        .i_mem_pre_index_ff             (decode_mem_pre_index_ff),
        .i_mem_unsigned_byte_enable_ff  (decode_mem_unsigned_byte_enable_ff),
        .i_mem_signed_byte_enable_ff    (decode_mem_signed_byte_enable_ff),
        .i_mem_signed_halfword_enable_ff(decode_mem_signed_halfword_enable_ff),
        .i_mem_unsigned_halfword_enable_ff(decode_mem_unsigned_halfword_enable_ff),
        .i_mem_translate_ff             (decode_mem_translate_ff),
        .i_irq_ff                       (decode_irq_ff),
        .i_fiq_ff                       (decode_fiq_ff),
        .i_abt_ff                       (decode_abt_ff),
        .i_swi_ff                       (decode_swi_ff),
        .i_cpu_mode                     (alu_flags_ff),
        // Needed to resolve CPSR refs.

        .i_force32align_ff              (decode_force32_ff),
        .o_force32align_ff              (issue_force32_ff),

        // Register file.
        .i_rd_data_0                    (rd_data_0),
        .i_rd_data_1                    (rd_data_1),
        .i_rd_data_2                    (rd_data_2),
        .i_rd_data_3                    (rd_data_3),

        // Feedback.
        .i_dc_lock                      (i_dc_lock),
        .i_shifter_destination_index_ff (shifter_destination_index_ff),
        .i_alu_destination_index_ff     (alu_destination_index_ff),
        .i_memory_destination_index_ff  (memory_destination_index_ff),
        .i_shifter_dav_ff               (shifter_condition_code_ff != NV ? 1'd1 : 1'd0),
        .i_alu_dav_nxt                  (alu_dav_nxt),
        .i_alu_dav_ff                   (alu_dav_ff),
        .i_memory_dav_ff                (memory_dav_ff),
        .i_alu_destination_value_nxt    (alu_alu_result_nxt),
        .i_alu_destination_value_ff     (alu_alu_result_ff),
        .i_memory_destination_value_ff  (memory_alu_result_ff),
        .i_shifter_mem_srcdest_index_ff (shifter_mem_srcdest_index_ff),
        .i_alu_mem_srcdest_index_ff     (alu_mem_srcdest_index_ff),
        .i_memory_mem_srcdest_index_ff  (memory_mem_srcdest_index_ff),
        .i_shifter_mem_load_ff          (shifter_mem_load_ff),
        .i_alu_mem_load_ff              (alu_mem_load_ff),
        .i_memory_mem_load_ff           (memory_mem_load_ff),

        .i_postalu0_destination_index_ff (postalu0_destination_index_ff),
        .i_postalu0_dav_ff               (postalu0_dav_ff),
        .i_postalu0_destination_value_ff (postalu0_alu_result_ff),
        .i_postalu0_mem_srcdest_index_ff (postalu0_mem_srcdest_index_ff),
        .i_postalu0_mem_load_ff          (postalu0_mem_load_ff),

        .i_postalu1_destination_index_ff (postalu1_destination_index_ff),
        .i_postalu1_dav_ff               (postalu1_dav_ff),
        .i_postalu1_destination_value_ff (postalu1_alu_result_ff),
        .i_postalu1_mem_srcdest_index_ff (postalu1_mem_srcdest_index_ff),
        .i_postalu1_mem_load_ff          (postalu1_mem_load_ff),

        .i_postalu_destination_index_ff (postalu_destination_index_ff),
        .i_postalu_dav_ff               (postalu_dav_ff),
        .i_postalu_destination_value_ff (postalu_alu_result_ff),
        .i_postalu_mem_srcdest_index_ff (postalu_mem_srcdest_index_ff),
        .i_postalu_mem_load_ff          (postalu_mem_load_ff),

        // Switch indicator.
        .i_switch_ff                    (decode_switch_ff),
        .o_switch_ff                    (issue_switch_ff),

        // Outputs.
        .o_rd_index_0                   (rd_index_0),
        .o_rd_index_1                   (rd_index_1),
        .o_rd_index_2                   (rd_index_2),
        .o_rd_index_3                   (rd_index_3),
        .o_condition_code_ff            (issue_condition_code_ff),
        .o_destination_index_ff         (issue_destination_index_ff),
        .o_alu_operation_ff             (issue_alu_operation_ff),
        .o_shift_operation_ff           (issue_shift_operation_ff),
        .o_flag_update_ff               (issue_flag_update_ff),
        .o_mem_srcdest_index_ff         (issue_mem_srcdest_index_ff),
        .o_mem_load_ff                  (issue_mem_load_ff),
        .o_mem_store_ff                 (issue_mem_store_ff),
        .o_mem_pre_index_ff             (issue_mem_pre_index_ff),
        .o_mem_unsigned_byte_enable_ff  (issue_mem_unsigned_byte_enable_ff),
        .o_mem_signed_byte_enable_ff    (issue_mem_signed_byte_enable_ff),
        .o_mem_signed_halfword_enable_ff(issue_mem_signed_halfword_enable_ff),
        .o_mem_unsigned_halfword_enable_ff(issue_mem_unsigned_halfword_enable_ff),
        .o_mem_translate_ff             (issue_mem_translate_ff),
        .o_irq_ff                       (issue_irq_ff),
        .o_fiq_ff                       (issue_fiq_ff),
        .o_abt_ff                       (issue_abt_ff),
        .o_swi_ff                       (issue_swi_ff),

        .o_alu_source_value_ff          (issue_alu_source_value_ff),
        .o_shift_source_value_ff        (issue_shift_source_value_ff),
        .o_shift_length_value_ff        (issue_shift_length_value_ff),
        .o_mem_srcdest_value_ff         (issue_mem_srcdest_value_ff),

        .o_alu_source_ff                (issue_alu_source_ff),
        .o_shift_source_ff              (issue_shift_source_ff),
        .o_stall_from_issue             (stall_from_issue),
        .o_pc_plus_8_ff                 (issue_pc_plus_8_ff),
        .o_shifter_disable_ff           (issue_shifter_disable_ff)
);

//
// The barrel shifter, and multiply/MAC unit.
//
zap_shifter_main #(
        .PHY_REGS(PHY_REGS),
        .ALU_OPS(ALU_OPS),
        .SHIFT_OPS(SHIFT_OPS)
)
u_zap_shifter_main
(
        .i_uop_last(issue_uop_last),
        .o_uop_last(shifter_uop_last),

        .i_decompile                    (issue_decompile),
        .o_decompile                    (shifter_decompile),

        .i_pc_ff                        (issue_pc_ff),
        .o_pc_ff                        (shifter_pc_ff),

        .i_ppc_ff                       (issue_ppc_ff),
        .o_ppc_ff                       (shifter_ppc_ff),

        .i_taken_ff                     (issue_taken_ff),
        .o_taken_ff                     (shifter_taken_ff),

        .i_und_ff                       (issue_und_ff),
        .o_und_ff                       (shifter_und_ff),

        .o_nozero_ff                    (shifter_nozero_ff),

        .i_clk                          (i_clk),
        .i_reset                        (reset),

        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_condition_code_ff            (stall_from_issue ? NV : issue_condition_code_ff),
        .i_destination_index_ff         (issue_destination_index_ff),
        .i_alu_operation_ff             (issue_alu_operation_ff),
        .i_shift_operation_ff           (issue_shift_operation_ff),
        .i_flag_update_ff               (issue_flag_update_ff),
        .i_mem_srcdest_index_ff         (issue_mem_srcdest_index_ff),
        .i_mem_load_ff                  (issue_mem_load_ff),
        .i_mem_store_ff                 (issue_mem_store_ff),
        .i_mem_pre_index_ff             (issue_mem_pre_index_ff),
        .i_mem_unsigned_byte_enable_ff  (issue_mem_unsigned_byte_enable_ff),
        .i_mem_signed_byte_enable_ff    (issue_mem_signed_byte_enable_ff),
        .i_mem_signed_halfword_enable_ff(issue_mem_signed_halfword_enable_ff),
        .i_mem_unsigned_halfword_enable_ff(issue_mem_unsigned_halfword_enable_ff),
        .i_mem_translate_ff             (stall_from_issue ? '0 : issue_mem_translate_ff),
        .i_irq_ff                       (stall_from_issue ? '0 : issue_irq_ff),
        .i_fiq_ff                       (stall_from_issue ? '0 : issue_fiq_ff),
        .i_abt_ff                       (stall_from_issue ? '0 : issue_abt_ff),
        .i_swi_ff                       (stall_from_issue ? '0 : issue_swi_ff),
        .i_alu_source_ff                (issue_alu_source_ff),
        .i_shift_source_ff              (issue_shift_source_ff),
        .i_alu_source_value_ff          (issue_alu_source_value_ff),
        .i_shift_source_value_ff        (issue_shift_source_value_ff),
        .i_shift_length_value_ff        (issue_shift_length_value_ff),
        .i_mem_srcdest_value_ff         (issue_mem_srcdest_value_ff),
        .i_pc_plus_8_ff                 (issue_pc_plus_8_ff),
        .i_disable_shifter_ff           (issue_shifter_disable_ff),

        // Next CPSR.
        .i_cpsr_nxt_29                  (alu_cpsr_nxt[29]),
        .i_cpsr_ff_29                   (alu_flags_ff[29]),

        // Feedback
        .i_alu_value_nxt                (alu_alu_result_nxt),
        .i_alu_dav_nxt                  (alu_dav_nxt),

        // Switch indicator.
        .i_switch_ff                    (issue_switch_ff),
        .o_switch_ff                    (shifter_switch_ff),

        // Force32
        .i_force32align_ff              (issue_force32_ff),
        .o_force32align_ff              (shifter_force32_ff),

        // Outputs.

        .o_mem_srcdest_value_ff         (shifter_mem_srcdest_value_ff),
        .o_alu_source_value_ff          (shifter_alu_source_value_ff),
        .o_shifted_source_value_ff      (shifter_shifted_source_value_ff),
        .o_shift_carry_ff               (shifter_shift_carry_ff),
        .o_shift_sat_ff                 (shifter_shift_sat_ff),

        .o_pc_plus_8_ff                 (shifter_pc_plus_8_ff),

        .o_mem_srcdest_index_ff         (shifter_mem_srcdest_index_ff),
        .o_mem_load_ff                  (shifter_mem_load_ff),
        .o_mem_store_ff                 (shifter_mem_store_ff),
        .o_mem_pre_index_ff             (shifter_mem_pre_index_ff),
        .o_mem_unsigned_byte_enable_ff  (shifter_mem_unsigned_byte_enable_ff),
        .o_mem_signed_byte_enable_ff    (shifter_mem_signed_byte_enable_ff),
        .o_mem_signed_halfword_enable_ff(shifter_mem_signed_halfword_enable_ff),
        .o_mem_unsigned_halfword_enable_ff(shifter_mem_unsigned_halfword_enable_ff),
        .o_mem_translate_ff             (shifter_mem_translate_ff),

        .o_condition_code_ff            (shifter_condition_code_ff),
        .o_destination_index_ff         (shifter_destination_index_ff),
        .o_alu_operation_ff             (shifter_alu_operation_ff),
        .o_flag_update_ff               (shifter_flag_update_ff),

        // Interrupts.
        .o_irq_ff                       (shifter_irq_ff),
        .o_fiq_ff                       (shifter_fiq_ff),
        .o_abt_ff                       (shifter_abt_ff),
        .o_swi_ff                       (shifter_swi_ff),

        // Stall
        .o_stall_from_shifter           (stall_from_shifter)
);

//
// ALU Stage.
//
zap_alu_main #(
        .PHY_REGS(PHY_REGS),
        .ALU_OPS(ALU_OPS),
        .CPSR_INIT(CPSR_INIT)
)
u_zap_alu_main
(
         .i_uop_last                     (shifter_uop_last),
         .i_clk                          (i_clk),
         .i_reset                        (reset),
         .i_decompile                    (shifter_decompile),
         .i_taken_ff                     (shifter_taken_ff),
         .i_cpu_pid                      (o_pid[6:0]),
         .i_ppc_ff                       (shifter_ppc_ff),
         .i_pc_ff                        (shifter_pc_ff),
         .i_und_ff                       (shifter_und_ff),
         .i_nozero_ff                    ( shifter_nozero_ff ),
         .i_clear_from_writeback         (clear_from_writeback),
         .i_data_stall                   (data_stall),
         .i_cpsr_nxt                     (cpsr_nxt),
         .i_flag_update_ff               (shifter_flag_update_ff),
         .i_switch_ff                    (shifter_switch_ff),
         .i_force32align_ff              (shifter_force32_ff),
         .i_mem_srcdest_value_ff         (shifter_mem_srcdest_value_ff),
         .i_alu_source_value_ff          (shifter_alu_source_value_ff),
         .i_shifted_source_value_ff      (shifter_shifted_source_value_ff),
         .i_shift_carry_ff               (shifter_shift_carry_ff),
         .i_shift_sat_ff                 (shifter_shift_sat_ff),
         .i_pc_plus_8_ff                 (shifter_pc_plus_8_ff),
         .i_abt_ff                       (shifter_abt_ff),
         .i_irq_ff                       (shifter_irq_ff),
         .i_fiq_ff                       (shifter_fiq_ff),
         .i_swi_ff                       (shifter_swi_ff),
         .i_mem_srcdest_index_ff         (shifter_mem_srcdest_index_ff),
         .i_mem_load_ff                  (shifter_mem_load_ff),
         .i_mem_store_ff                 (shifter_mem_store_ff),
         .i_mem_pre_index_ff             (shifter_mem_pre_index_ff),
         .i_mem_unsigned_byte_enable_ff  (shifter_mem_unsigned_byte_enable_ff),
         .i_mem_signed_byte_enable_ff    (shifter_mem_signed_byte_enable_ff),
         .i_mem_signed_halfword_enable_ff(shifter_mem_signed_halfword_enable_ff),
         .i_mem_unsigned_halfword_enable_ff(shifter_mem_unsigned_halfword_enable_ff),
         .i_mem_translate_ff               (shifter_mem_translate_ff),
         .i_condition_code_ff              (shifter_condition_code_ff),
         .i_destination_index_ff           (shifter_destination_index_ff),
         .i_alu_operation_ff               (shifter_alu_operation_ff),
         .i_data_mem_fault                 (i_data_wb_err | i_dcache_err2),

         .o_force32align_ff                (alu_force32align_ff),
         .o_uop_last                       (alu_uop_last),
         .o_alu_result_nxt                 (alu_alu_result_nxt),
         .o_pc_from_alu                    (pc_from_alu),
         .o_flags_nxt                      (alu_cpsr_nxt),
         .o_clear_from_alu                 (clear_from_alu),
         .o_confirm_from_alu               (confirm_from_alu),
         .o_decompile                      (alu_decompile),
         .o_decompile_valid                (alu_decompile_valid),
         .o_alu_result_ff                  (alu_alu_result_ff),
         .o_und_ff                         (alu_und_ff),
         .o_abt_ff                         (alu_abt_ff),
         .o_irq_ff                         (alu_irq_ff),
         .o_fiq_ff                         (alu_fiq_ff),
         .o_swi_ff                         (alu_swi_ff),
         .o_dav_ff                         (alu_dav_ff),
         .o_dav_nxt                        (alu_dav_nxt),
         .o_pc_plus_8_ff                   (alu_pc_plus_8_ff),
         .o_mem_address_ff                 (alu_address_ff),
         .o_destination_index_ff           (alu_destination_index_ff),
         .o_flags_ff                       (alu_flags_ff),
         .o_taken_ff                       (alu_taken_ff),
         .o_mem_srcdest_index_ff           (alu_mem_srcdest_index_ff),
         .o_mem_load_ff                    (alu_mem_load_ff),
         .o_mem_unsigned_byte_enable_ff    (alu_ubyte_ff),
         .o_mem_signed_byte_enable_ff      (alu_sbyte_ff),
         .o_mem_signed_halfword_enable_ff  (alu_shalf_ff),
         .o_mem_unsigned_halfword_enable_ff(alu_uhalf_ff),
         .o_mem_translate_ff               (alu_mem_translate_ff),
         .o_data_wb_we_ff                  (alu_data_wb_we),
         .o_data_wb_cyc_ff                 (alu_data_wb_cyc),
         .o_data_wb_stb_ff                 (alu_data_wb_stb),
         .o_data_wb_dat_ff                 (alu_data_wb_dat),
         .o_data_wb_sel_ff                 (alu_data_wb_sel),
         .o_alt_result_ff                  (alu_x_result),
         .o_alt_dav_ff                     (alu_x_valid)

);

//
// Post ALU 0 stage. For tag RAM reads etc. The actual tag RAMs are outside
// the core.
//
zap_postalu_main #(
        .PHY_REGS(PHY_REGS),
        .FLAG_WDT(FLAG_WDT)
) u_zap_postalu0_main (
         .i_clk                            (i_clk),
         .i_reset                          (i_reset),
         .i_data_stall                     (data_stall),
         .i_clear_from_writeback           (clear_from_writeback),
         .i_data_mem_fault                 (i_data_wb_err | i_dcache_err2),

          .i_uop_last                      (alu_uop_last),
          .o_uop_last                      (postalu0_uop_last),

         .i_decompile_valid                (alu_decompile_valid),
         .i_decompile                      (alu_decompile),
         .i_alu_result_ff                  (alu_x_ppr),
         .i_und_ff                         (alu_und_ff),
         .i_abt_ff                         (alu_abt_ff),
         .i_irq_ff                         (alu_irq_ff),
         .i_fiq_ff                         (alu_fiq_ff),
         .i_swi_ff                         (alu_swi_ff),
         .i_dav_ff                         (alu_dav_ff),
         .i_pc_plus_8_ff                   (alu_pc_plus_8_ff),
         .i_mem_address_ff                 (alu_force32align_ff ?
                                             (alu_address_ff & 32'hffff_fffc)
                                            : alu_address_ff),
         .i_destination_index_ff           (alu_destination_index_ff),
         .i_flags_ff                       (alu_flags_ff),
         .i_mem_srcdest_index_ff           (alu_mem_srcdest_index_ff),
         .i_mem_load_ff                    (alu_mem_load_ff),
         .i_mem_unsigned_byte_enable_ff    (alu_ubyte_ff),
         .i_mem_signed_byte_enable_ff      (alu_sbyte_ff),
         .i_mem_signed_halfword_enable_ff  (alu_shalf_ff),
         .i_mem_unsigned_halfword_enable_ff(alu_uhalf_ff),
         .i_mem_translate_ff               (alu_mem_translate_ff),

         .i_data_wb_we_ff                  (alu_data_wb_we),
         .i_data_wb_cyc_ff                 (alu_data_wb_cyc),
         .i_data_wb_stb_ff                 (alu_data_wb_stb),
         .i_data_wb_dat_ff                 (alu_data_wb_dat),
         .i_data_wb_sel_ff                 (alu_data_wb_sel),

         .o_decompile                      (postalu0_decompile),
         .o_decompile_valid                (postalu0_decompile_valid),
         .o_alu_result_ff                  (postalu0_alu_result_ff),
         .o_und_ff                         (postalu0_und_ff),
         .o_abt_ff                         (postalu0_abt_ff),
         .o_irq_ff                         (postalu0_irq_ff),
         .o_fiq_ff                         (postalu0_fiq_ff),
         .o_swi_ff                         (postalu0_swi_ff),
         .o_dav_ff                         (postalu0_dav_ff),
         .o_pc_plus_8_ff                   (postalu0_pc_plus_8_ff),
         .o_mem_address_ff                 (postalu0_address_ff),
         .o_destination_index_ff           (postalu0_destination_index_ff),
         .o_flags_ff                       (postalu0_flags_ff),
         .o_mem_srcdest_index_ff           (postalu0_mem_srcdest_index_ff),
         .o_mem_load_ff                    (postalu0_mem_load_ff),
         .o_mem_unsigned_byte_enable_ff    (postalu0_ubyte_ff),
         .o_mem_signed_byte_enable_ff      (postalu0_sbyte_ff),
         .o_mem_signed_halfword_enable_ff  (postalu0_shalf_ff),
         .o_mem_unsigned_halfword_enable_ff(postalu0_uhalf_ff),
         .o_mem_translate_ff               (postalu0_mem_translate_ff),
         .o_data_wb_we_ff                  (postalu0_data_wb_we),
         .o_data_wb_cyc_ff                 (postalu0_data_wb_cyc),
         .o_data_wb_stb_ff                 (postalu0_data_wb_stb),
         .o_data_wb_dat_ff                 (postalu0_data_wb_dat),
         .o_data_wb_sel_ff                 (postalu0_data_wb_sel)
);

//
// Post ALU 1 stage. Similar in purpose to the above. Helps deal with long
// latency RAMs.
//
zap_postalu_main #(
        .PHY_REGS(PHY_REGS),
        .FLAG_WDT(FLAG_WDT)
) u_zap_postalu1_main (
         .i_clk                            (i_clk),
         .i_reset                          (i_reset),
         .i_data_stall                     (data_stall),
         .i_clear_from_writeback           (clear_from_writeback),
         .i_data_mem_fault                 (i_data_wb_err | i_dcache_err2),

         .i_uop_last                       (postalu0_uop_last),
         .o_uop_last                       (postalu1_uop_last),

         .i_decompile                      (postalu0_decompile),
         .i_decompile_valid                (postalu0_decompile_valid),
         .i_alu_result_ff                  (postalu0_alu_result_ff),
         .i_und_ff                         (postalu0_und_ff),
         .i_abt_ff                         (postalu0_abt_ff),
         .i_irq_ff                         (postalu0_irq_ff),
         .i_fiq_ff                         (postalu0_fiq_ff),
         .i_swi_ff                         (postalu0_swi_ff),
         .i_dav_ff                         (postalu0_dav_ff),
         .i_pc_plus_8_ff                   (postalu0_pc_plus_8_ff),
         .i_mem_address_ff                 (postalu0_address_ff),
         .i_destination_index_ff           (postalu0_destination_index_ff),
         .i_flags_ff                       (postalu0_flags_ff),
         .i_mem_srcdest_index_ff           (postalu0_mem_srcdest_index_ff),
         .i_mem_load_ff                    (postalu0_mem_load_ff),
         .i_mem_unsigned_byte_enable_ff    (postalu0_ubyte_ff),
         .i_mem_signed_byte_enable_ff      (postalu0_sbyte_ff),
         .i_mem_signed_halfword_enable_ff  (postalu0_shalf_ff),
         .i_mem_unsigned_halfword_enable_ff(postalu0_uhalf_ff),
         .i_mem_translate_ff               (postalu0_mem_translate_ff),
         .i_data_wb_we_ff                  (postalu0_data_wb_we),
         .i_data_wb_cyc_ff                 (postalu0_data_wb_cyc),
         .i_data_wb_stb_ff                 (postalu0_data_wb_stb),
         .i_data_wb_dat_ff                 (postalu0_data_wb_dat),
         .i_data_wb_sel_ff                 (postalu0_data_wb_sel),

         .o_decompile                      (postalu1_decompile),
         .o_decompile_valid                (postalu1_decompile_valid),
         .o_alu_result_ff                  (postalu1_alu_result_ff),
         .o_und_ff                         (postalu1_und_ff),
         .o_abt_ff                         (postalu1_abt_ff),
         .o_irq_ff                         (postalu1_irq_ff),
         .o_fiq_ff                         (postalu1_fiq_ff),
         .o_swi_ff                         (postalu1_swi_ff),
         .o_dav_ff                         (postalu1_dav_ff),
         .o_pc_plus_8_ff                   (postalu1_pc_plus_8_ff),
         .o_mem_address_ff                 (postalu1_address_ff),
         .o_destination_index_ff           (postalu1_destination_index_ff),
         .o_flags_ff                       (postalu1_flags_ff),
         .o_mem_srcdest_index_ff           (postalu1_mem_srcdest_index_ff),
         .o_mem_load_ff                    (postalu1_mem_load_ff),
         .o_mem_unsigned_byte_enable_ff    (postalu1_ubyte_ff),
         .o_mem_signed_byte_enable_ff      (postalu1_sbyte_ff),
         .o_mem_signed_halfword_enable_ff  (postalu1_shalf_ff),
         .o_mem_unsigned_halfword_enable_ff(postalu1_uhalf_ff),
         .o_mem_translate_ff               (postalu1_mem_translate_ff),

         .o_data_wb_we_ff                  (postalu1_data_wb_we),
         .o_data_wb_cyc_ff                 (postalu1_data_wb_cyc),
         .o_data_wb_stb_ff                 (postalu1_data_wb_stb),
         .o_data_wb_dat_ff                 (postalu1_data_wb_dat),
         .o_data_wb_sel_ff                 (postalu1_data_wb_sel)
);

//
// Post ALU stage. Memory access signals are generated at the end of this
// stage.
//
zap_postalu_main #(
        .PHY_REGS(PHY_REGS),
        .FLAG_WDT(FLAG_WDT)
) u_zap_postalu2_main (
         .i_clk                            (i_clk),
         .i_reset                          (i_reset),
         .i_data_stall                     (data_stall),
         .i_clear_from_writeback           (clear_from_writeback),
         .i_data_mem_fault                 (i_data_wb_err | i_dcache_err2),

         .i_uop_last                        (postalu1_uop_last),
         .o_uop_last                        (postalu_uop_last),

         .i_decompile                      (postalu1_decompile),
         .i_decompile_valid                (postalu1_decompile_valid),
         .i_alu_result_ff                  (postalu1_alu_result_ff),
         .i_und_ff                         (postalu1_und_ff),
         .i_abt_ff                         (postalu1_abt_ff),
         .i_irq_ff                         (postalu1_irq_ff),
         .i_fiq_ff                         (postalu1_fiq_ff),
         .i_swi_ff                         (postalu1_swi_ff),
         .i_dav_ff                         (postalu1_dav_ff),
         .i_pc_plus_8_ff                   (postalu1_pc_plus_8_ff),
         .i_mem_address_ff                 (postalu1_address_ff),
         .i_destination_index_ff           (postalu1_destination_index_ff),
         .i_flags_ff                       (postalu1_flags_ff),
         .i_mem_srcdest_index_ff           (postalu1_mem_srcdest_index_ff),
         .i_mem_load_ff                    (postalu1_mem_load_ff),
         .i_mem_unsigned_byte_enable_ff    (postalu1_ubyte_ff),
         .i_mem_signed_byte_enable_ff      (postalu1_sbyte_ff),
         .i_mem_signed_halfword_enable_ff  (postalu1_shalf_ff),
         .i_mem_unsigned_halfword_enable_ff(postalu1_uhalf_ff),
         .i_mem_translate_ff               (postalu1_mem_translate_ff),
         .i_data_wb_we_ff                  (postalu1_data_wb_we),
         .i_data_wb_cyc_ff                 (postalu1_data_wb_cyc),
         .i_data_wb_stb_ff                 (postalu1_data_wb_stb),
         .i_data_wb_dat_ff                 (postalu1_data_wb_dat),
         .i_data_wb_sel_ff                 (postalu1_data_wb_sel),

         .o_decompile                      (postalu_decompile),
         .o_decompile_valid                (postalu_decompile_valid),
         .o_alu_result_ff                  (postalu_alu_result_ff),
         .o_und_ff                         (postalu_und_ff),
         .o_abt_ff                         (postalu_abt_ff),
         .o_irq_ff                         (postalu_irq_ff),
         .o_fiq_ff                         (postalu_fiq_ff),
         .o_swi_ff                         (postalu_swi_ff),
         .o_dav_ff                         (postalu_dav_ff),
         .o_pc_plus_8_ff                   (postalu_pc_plus_8_ff),
         .o_mem_address_ff                 (postalu_address_ff),
         .o_destination_index_ff           (postalu_destination_index_ff),
         .o_flags_ff                       (postalu_flags_ff),
         .o_mem_srcdest_index_ff           (postalu_mem_srcdest_index_ff),
         .o_mem_load_ff                    (postalu_mem_load_ff),
         .o_mem_unsigned_byte_enable_ff    (postalu_ubyte_ff),
         .o_mem_signed_byte_enable_ff      (postalu_sbyte_ff),
         .o_mem_signed_halfword_enable_ff  (postalu_shalf_ff),
         .o_mem_unsigned_halfword_enable_ff(postalu_uhalf_ff),
         .o_mem_translate_ff               (postalu_mem_translate_ff),

         .o_data_wb_we_ff                  (o_data_wb_we),
         .o_data_wb_cyc_ff                 (o_data_wb_cyc),
         .o_data_wb_stb_ff                 (o_data_wb_stb),
         .o_data_wb_dat_ff                 (o_data_wb_dat),
         .o_data_wb_sel_ff                 (o_data_wb_sel)
);

//
// Memory access stage. This actual loads in the memory value, and
// rotates it as required.
//
zap_memory_main #(
       .PHY_REGS(PHY_REGS)
)
u_zap_memory_main
(
        .i_uop_last                     (postalu_uop_last),
        .o_uop_last                     (memory_uop_last),
        .o_decompile                    (memory_decompile),
        .o_decompile_valid              (memory_decompile_valid),
        .i_decompile                    (postalu_decompile),
        .i_decompile_valid              (postalu_decompile_valid),
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (data_stall),
        .i_alu_result_ff                (postalu_alu_result_ff),
        .i_und_ff                       (postalu_und_ff),
        .i_mem_address_ff               (postalu_address_ff[1:0]),
        .i_sbyte_ff                     (postalu_sbyte_ff),     // Signed byte.
        .i_ubyte_ff                     (postalu_ubyte_ff),     // Unsigned byte.
        .i_shalf_ff                     (postalu_shalf_ff),     // Signed half word.
        .i_uhalf_ff                     (postalu_uhalf_ff),     // Unsigned half word.
        .i_flags_ff                     (postalu_flags_ff),
        .i_mem_load_ff                  (postalu_mem_load_ff),
        .i_dav_ff                       (postalu_dav_ff),
        .i_pc_plus_8_ff                 (postalu_pc_plus_8_ff),
        .i_destination_index_ff         (postalu_destination_index_ff),
        .i_irq_ff                       (postalu_irq_ff),
        .i_fiq_ff                       (postalu_fiq_ff),
        .i_instr_abort_ff               (postalu_abt_ff),
        .i_swi_ff                       (postalu_swi_ff),
        .i_mem_srcdest_index_ff         (postalu_mem_srcdest_index_ff),

        .i_mem_rd_data                  (i_data_wb_dat),// From memory.
        .i_mem_fault                    ({i_dcache_err2, i_data_wb_err}),      // From cache.
        .o_mem_fault                    (memory_data_abt_ff[1:0]),

        // Can come in handy since this is reused for several other things.
        .i_mem_srcdest_value_ff         (o_data_wb_dat),

        .o_alu_result_ff                (memory_alu_result_ff),
        .o_flags_ff                     (memory_flags_ff),

        .o_destination_index_ff         (memory_destination_index_ff),
        .o_mem_srcdest_index_ff         (memory_mem_srcdest_index_ff),

        .o_dav_ff                       (memory_dav_ff),
        .o_pc_plus_8_ff                 (memory_pc_plus_8_ff),

        .o_irq_ff                       (memory_irq_ff),
        .o_fiq_ff                       (memory_fiq_ff),
        .o_swi_ff                       (memory_swi_ff),
        .o_und_ff                       (memory_und_ff),
        .o_instr_abort_ff               (memory_instr_abort_ff),

        .o_mem_load_ff                  (memory_mem_load_ff),
        .o_mem_rd_data                  (memory_mem_rd_data)
);

//
// Writeback stage. Writes to the register file.
//
zap_writeback #(
        .BP_ENTRIES(BP_ENTRIES),
        .PHY_REGS(PHY_REGS),
        .FLAG_WDT(FLAG_WDT),
        .RESET_VECTOR(RESET_VECTOR),
        .CPSR_INIT(CPSR_INIT)
)
u_zap_writeback
(
        .o_trace                (o_trace),
        .o_trace_valid          (o_trace_valid),
        .o_trace_uop_last       (o_trace_uop_last),

        .i_uop_last             (memory_uop_last),
        .i_decompile            (memory_decompile),
        .i_decompile_valid      (memory_decompile_valid),

        .o_decompile            (rb_decompile), // Unused.

        .i_clear_btb            (predecode_clear_btb),

        .i_cpu_pid              (o_pid[6:0]),

        .i_confirm_from_alu     (confirm_from_alu),
        .i_alu_pc_ff            (alu_flags_ff[T] ? alu_pc_plus_8_ff - 32'd4 : alu_pc_plus_8_ff - 32'd8),
        .i_taken                (alu_taken_ff),

        .o_shelve               (shelve),

        .i_clk                  (i_clk),        // ZAP clock.
        .i_reset                (reset),        // ZAP reset.

        .i_l4_enable            (l4_enable),

        .i_valid                (memory_dav_ff),
        .i_clear_from_alu       (clear_from_alu),
        .i_pc_from_alu          (pc_from_alu),
        .i_clear_from_icache    (i_icache_err2),

        .i_mode16               (alu_flags_ff[T]),    // To indicate mode16 state.

        .i_clear_from_decode    (clear_from_decode),
        .i_pc_from_decode       (pc_from_decode),

        .i_code_stall           (code_stall),

        // Used to valid writes on i_wr_index1.
        .i_mem_load_ff          (memory_mem_load_ff),

        .i_rd_index_0           (rd_index_0),
        .i_rd_index_1           (rd_index_1),
        .i_rd_index_2           (rd_index_2),
        .i_rd_index_3           (rd_index_3),

        .i_wr_index             (memory_destination_index_ff),
        .i_wr_data              (memory_alu_result_ff),
        .i_flags                (memory_flags_ff),

        .i_wr_index_1           (memory_mem_srcdest_index_ff),// load index.
        .i_wr_data_1            (memory_mem_rd_data),         // load data.

        .i_wr_index_2           (i_dc_reg_idx[PHY_REGS-1:0]),
        .i_wr_data_2            (i_dc_reg_dat),

        .i_irq                  (memory_irq_ff),
        .i_fiq                  (memory_fiq_ff),
        .i_instr_abt            (memory_instr_abort_ff),
        .i_data_abt             (memory_data_abt_ff[1:0]),
        .i_swi                  (memory_swi_ff),
        .i_und                  (memory_und_ff),

        .i_pc_plus_8_buf_ff     (memory_pc_plus_8_ff),

        .i_copro_reg_en         (copro_reg_en),
        .i_copro_reg_wr_index   (copro_reg_wr_index),
        .i_copro_reg_rd_index   (copro_reg_rd_index),
        .i_copro_reg_wr_data    (copro_reg_wr_data),

        .o_copro_reg_rd_data_ff (copro_reg_rd_data),

        .o_rd_data_0            (rd_data_0),
        .o_rd_data_1            (rd_data_1),
        .o_rd_data_2            (rd_data_2),
        .o_rd_data_3            (rd_data_3),

        .o_taken                (wb_taken),
        .o_pc                   (o_instr_wb_adr),
        .o_pred                 (wb_pred),
        .o_pc_nxt               (o_instr_wb_adr_nxt),
        .o_pc_check             (o_instr_wb_adr_check),
        .o_cpsr_nxt             (cpsr_nxt),
        .o_clear_from_writeback (clear_from_writeback),

        .o_wb_stb               (o_instr_wb_stb),
        .o_wb_cyc               (o_instr_wb_cyc)
);

//
// Coprocessor 15 registers.
//
zap_cp15_cb #(
.BE_32_ENABLE(BE_32_ENABLE),
.PHY_REGS(PHY_REGS),
.CP15_L4_DEFAULT(CP15_L4_DEFAULT),
.DATA_CACHE_SIZE(DATA_CACHE_SIZE),
.CODE_CACHE_SIZE(CODE_CACHE_SIZE),
.DATA_CACHE_LINE(DATA_CACHE_LINE),
.CODE_CACHE_LINE(CODE_CACHE_LINE)
) u_zap_cp15_cb (
        .i_clk                  (i_clk),
        .i_reset                (i_reset),
        .i_cp_word              (copro_word),
        .i_cp_dav               (copro_dav),
        .o_cp_done              (copro_done),
        .i_cpsr                 (alu_flags_ff),
        .o_reg_en               (copro_reg_en),
        .o_reg_wr_data          (copro_reg_wr_data),
        .i_reg_rd_data          (copro_reg_rd_data),
        .o_reg_wr_index         (copro_reg_wr_index),
        .o_reg_rd_index         (copro_reg_rd_index),

        .i_fsr                  (i_fsr),
        .i_far                  (i_far),
        .o_dac                  (o_dac),
        .o_baddr                (o_baddr),
        .o_mmu_en               (o_mmu_en),
        .o_sr                   (o_sr),
        .o_pid                  (o_pid),
        .o_l4_enable            (l4_enable),
        .o_dcache_inv           (o_dcache_inv),
        .o_icache_inv           (o_icache_inv),
        .o_dcache_clean         (o_dcache_clean),
        .o_icache_clean         (o_icache_clean),
        .o_dtlb_inv             (o_dtlb_inv),
        .o_itlb_inv             (o_itlb_inv),
        .o_dcache_en            (o_dcache_en),
        .o_icache_en            (o_icache_en),
        .i_dcache_inv_done      (i_dcache_inv_done),
        .i_icache_inv_done      (i_icache_inv_done),
        .i_dcache_clean_done    (i_dcache_clean_done),
        .i_icache_clean_done    (i_icache_clean_done)
);

// Readout of CPU mode. Useful for debugging.

always_comb
case(o_cpsr[ZAP_CPSR_MODE:0])
FIQ:     CPU_MODE = "FIQ";
IRQ:     CPU_MODE = "IRQ";
USR:     CPU_MODE = "USR";
UND:     CPU_MODE = "UND";
SVC:     CPU_MODE = "SVC";
ABT:     CPU_MODE = "ABT";
SYS:     CPU_MODE = "SYS";
default: CPU_MODE = "???";
endcase

// Assertion to catch if CPU is in a bad mode.
always @ ( posedge i_clk ) // Assertion.
begin
        if ( !i_reset )
        begin
                assert (
                        o_cpsr[ZAP_CPSR_MODE:0] == FIQ ||
                        o_cpsr[ZAP_CPSR_MODE:0] == IRQ ||
                        o_cpsr[ZAP_CPSR_MODE:0] == USR ||
                        o_cpsr[ZAP_CPSR_MODE:0] == UND ||
                        o_cpsr[ZAP_CPSR_MODE:0] == SVC ||
                        o_cpsr[ZAP_CPSR_MODE:0] == ABT ||
                        o_cpsr[ZAP_CPSR_MODE:0] == SYS
                ) else
                        $fatal(2, "Error: CPU in unknown mode.");
        end
end

endmodule : zap_core

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
