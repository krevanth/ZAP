/*
MIT License

Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

`default_nettype none
`include "config.vh"

/*
Filename --
zap_top.v

HDL --
Verilog-2005

Description --
This is the TOP module of the ZAP core. 

Author --
Revanth Kamaraj.

License --
Released under the MIT license.
*/

module zap_core
(
                // Clock and reset.
                input wire                              i_clk,                  // ZAP clock.        

                input wire                              i_clk_2x,               // 2x ZAP clock for register file.

                input wire                              i_reset,                // Active high synchronous reset.
                                
                // From I-cache.
                input wire [31:0]                       i_instruction,          // A 32-bit ZAP instruction.
                input wire                              i_valid,                // Instruction valid.
                input wire                              i_instr_abort,          // Instruction abort fault.


                // Memory access - ALL ARE REGISTERED..
                output wire                             o_read_en,              // Memory load
                output wire                             o_write_en,             // Memory store.
                output wire[31:0]                       o_address,              // Memory address.

                // User view - REGISTERED.
                output wire                             o_mem_translate,

                // DCache Memory stall.
                input wire                              i_data_stall,
                
                // Memory abort.
                input wire                              i_data_abort,

                // Memory read data.
                input wire  [31:0]                      i_rd_data,

                // Memory write data - REGISTERED. duplicate as needed.
                output wire [31:0]                      o_wr_data,

                // Memory write byte enables. Implement this as 1-hot BYTE 2-hot - HALF 4hot - WORD.
                output wire  [3:0]                      o_ben,                  // Byte enables for memory write.

                // Interrupts.
                input wire                              i_fiq,                  // FIQ signal.
                input wire                              i_irq,                  // IRQ signal.


                // Coprocessor.
                input wire                              i_copro_done,
                output wire                             o_copro_dav,
                output wire  [31:0]                     o_copro_word,
                input wire                              i_copro_reg_en,         // Coprocessor controls register file.
                input wire      [$clog2(PHY_REGS)-1:0]  i_copro_reg_wr_index,   // Register write index.
                input wire      [$clog2(PHY_REGS)-1:0]  i_copro_reg_rd_index,   // Register read index.
                input wire      [31:0]                  i_copro_reg_wr_data,    // Register write data.
                output wire     [31:0]                  o_copro_reg_rd_data,    // Coprocessor read data from register file.


                // Program counter - REGISTERED.
                output wire     [31:0]                  o_pc,                   // Program counter.

                // Determines user or supervisory mode. - REGISTERED.
                output wire      [31:0]                 o_cpsr,                 // CPSR. Cache must use this to determine VM scheme for instruction fetches.

                // Data cache access signals.
                output wire     [31:0]                  o_address_nxt,          // Upcoming address for D-Cache.
 
                // Instruction cache access signals.
                output wire     [31:0]                  o_pc_nxt,               // Upcoming address for I-cache. 

                // Pipeline stall and clear signals.
                output wire                             o_clear_from_alu                     ,    // |
                output wire                             o_stall_from_shifter                 ,    // |
                output wire                             o_stall_from_issue                   ,    // |
                output wire                             o_stall_from_decode                  ,    // V Low Priority.
                output wire                             o_clear_from_decode                  ,    // V
                output wire                             o_clear_from_writeback               
);

localparam ARCH_REGS = 32;
localparam ALU_OPS   = 32;
localparam SHIFT_OPS = 7;
localparam PHY_REGS  = TOTAL_PHY_REGS;
localparam FLAG_WDT  = 32;

`include "regs.vh"
`include "cc.vh"
`include "modes.vh"
`include "cpsr.vh"

// -------------------------------
// Wires.
// -------------------------------

wire reset;

// Clear and stall signals.
wire stall_from_decode;
wire clear_from_alu;
wire stall_from_issue;
wire clear_from_writeback;

// Fetch
wire [31:0] fetch_instruction;  // Instruction from the fetch unit.
wire        fetch_valid;        // Instruction valid from the fetch unit.
wire        fetch_instr_abort;  // abort indicator.
wire [31:0] fetch_pc_plus_8_ff; // PC + 8 generated from the fetch unit.
wire [31:0] fetch_pc_ff;        // PC generated from fetch unit.
wire [1:0]  fetch_bp_state;

// Predecode
wire [31:0]     predecode_pc_plus_8;
wire [31:0]     predecode_pc;
wire            predecode_irq;
wire            predecode_fiq;
wire            predecode_abt; 
wire [35:0]     predecode_inst;
wire            predecode_val;
wire            predecode_force32;
wire            predecode_und;
wire [1:0]      predecode_taken;

// Decode
wire [3:0]                      decode_condition_code;
wire [$clog2(PHY_REGS)-1:0]     decode_destination_index;
wire [32:0]                     decode_alu_source_ff;
wire [$clog2(ALU_OPS)-1:0]      decode_alu_operation_ff;             
wire [32:0]                     decode_shift_source_ff;
wire [$clog2(SHIFT_OPS)-1:0]    decode_shift_operation_ff;
wire [32:0]                     decode_shift_length_ff;
wire                            decode_flag_update_ff;
wire [$clog2(PHY_REGS)-1:0]     decode_mem_srcdest_index_ff;
wire                            decode_mem_load_ff;
wire                            decode_mem_store_ff;
wire                            decode_mem_pre_index_ff;
wire                            decode_mem_unsigned_byte_enable_ff;
wire                            decode_mem_signed_byte_enable_ff;
wire                            decode_mem_signed_halfword_enable_ff;
wire                            decode_mem_unsigned_halfword_enable_ff;
wire                            decode_mem_translate_ff;
wire                            decode_irq_ff;
wire                            decode_fiq_ff;
wire                            decode_abt_ff;
wire                            decode_swi_ff;
wire [31:0]                     decode_pc_plus_8_ff;
wire [31:0]                     decode_pc_ff;
wire                            decode_switch_ff;
wire                            decode_force32_ff;
wire                            decode_und_ff;
wire                            clear_from_decode;
wire [31:0]                     pc_from_decode;
wire [1:0]                      decode_taken_ff;

// Issue
wire [$clog2(PHY_REGS)-1:0]     issue_rd_index_0, 
                                issue_rd_index_1, 
                                issue_rd_index_2, 
                                issue_rd_index_3;

wire [3:0]                      issue_condition_code_ff;  
wire [$clog2(PHY_REGS)-1:0]     issue_destination_index_ff;
wire [$clog2(ALU_OPS)-1:0]      issue_alu_operation_ff;
wire [$clog2(SHIFT_OPS)-1:0]    issue_shift_operation_ff;
wire                            issue_flag_update_ff;
wire [$clog2(PHY_REGS)-1:0]     issue_mem_srcdest_index_ff;
wire                            issue_mem_load_ff;
wire                            issue_mem_store_ff;
wire                            issue_mem_pre_index_ff;
wire                            issue_mem_unsigned_byte_enable_ff;
wire                            issue_mem_signed_byte_enable_ff;
wire                            issue_mem_signed_halfword_enable_ff;
wire                            issue_mem_unsigned_halfword_enable_ff;
wire                            issue_mem_translate_ff;
wire                            issue_irq_ff;
wire                            issue_fiq_ff;
wire                            issue_abt_ff;
wire                            issue_swi_ff;
wire [31:0]                     issue_alu_source_value_ff;
wire [31:0]                     issue_shift_source_value_ff;
wire [31:0]                     issue_shift_length_value_ff;
wire [31:0]                     issue_mem_srcdest_value_ff;
wire [32:0]                     issue_alu_source_ff;
wire [32:0]                     issue_shift_source_ff;
wire [31:0]                     issue_pc_plus_8_ff;
wire [31:0]                     issue_pc_ff;
wire                            issue_shifter_disable_ff;
wire                            issue_switch_ff;
wire                            issue_force32_ff;
wire                            issue_und_ff;
wire  [1:0]                     issue_taken_ff;

wire [$clog2(PHY_REGS)-1:0]     rd_index_0;
wire [$clog2(PHY_REGS)-1:0]     rd_index_1;
wire [$clog2(PHY_REGS)-1:0]     rd_index_2;
wire [$clog2(PHY_REGS)-1:0]     rd_index_3;

// Shift
wire [$clog2(PHY_REGS)-1:0] shifter_mem_srcdest_index_ff;
wire shifter_mem_load_ff;
wire shifter_mem_store_ff;
wire shifter_mem_pre_index_ff;
wire shifter_mem_unsigned_byte_enable_ff;
wire shifter_mem_signed_byte_enable_ff;
wire shifter_mem_signed_halfword_enable_ff;
wire shifter_mem_unsigned_halfword_enable_ff;
wire shifter_mem_translate_ff;
wire [3:0] shifter_condition_code_ff;
wire [$clog2(PHY_REGS)-1:0] shifter_destination_index_ff;
wire [$clog2(ALU_OPS)-1:0] shifter_alu_operation_ff;
wire shifter_nozero_ff;
wire shifter_flag_update_ff;
wire [31:0] shifter_mem_srcdest_value_ff;
wire [31:0] shifter_alu_source_value_ff;
wire [31:0] shifter_shifted_source_value_ff;
wire shifter_shift_carry_ff;
wire [31:0] shifter_pc_plus_8_ff;
wire [31:0] shifter_pc_ff;
wire shifter_irq_ff;
wire shifter_fiq_ff;
wire shifter_abt_ff;
wire shifter_swi_ff;
wire shifter_switch_ff;
wire shifter_force32_ff;
wire shifter_und_ff;
wire stall_from_shifter;
wire [1:0] shifter_taken_ff;

// ALU
wire [$clog2(SHIFT_OPS)-1:0]    alu_shift_operation_ff;
wire [31:0]                     alu_alu_result_nxt;
wire [31:0]                     alu_alu_result_ff;
wire                            alu_abt_ff;
wire                            alu_irq_ff;
wire                            alu_fiq_ff;
wire                            alu_swi_ff;
wire                            alu_dav_ff;
wire                            alu_dav_nxt;
wire [31:0]                     alu_pc_plus_8_ff;
wire [31:0]                     pc_from_alu;
wire [$clog2(PHY_REGS)-1:0]     alu_destination_index_ff;
wire [FLAG_WDT-1:0]             alu_flags_ff;
wire [$clog2(PHY_REGS)-1:0]     alu_mem_srcdest_index_ff;
wire                            alu_mem_load_ff;
wire                            alu_und_ff;
wire [31:0]                     alu_cpsr_nxt; //TODO: Eliminate this  and place MAC in ALU itself.
wire                            confirm_from_alu;
wire                            alu_sbyte_ff;
wire                            alu_ubyte_ff;
wire                            alu_shalf_ff;
wire                            alu_uhalf_ff;
wire [31:0]                     alu_address_ff;

// Memory
wire [31:0]                     memory_alu_result_ff;
wire [$clog2(PHY_REGS)-1:0]     memory_destination_index_ff;
wire [$clog2(PHY_REGS)-1:0]     memory_mem_srcdest_index_ff;
wire                            memory_dav_ff;
wire [31:0]                     memory_pc_plus_8_ff;
wire                            memory_irq_ff;
wire                            memory_fiq_ff;
wire                            memory_swi_ff;
wire                            memory_instr_abort_ff;
wire                            memory_mem_load_ff;
wire  [FLAG_WDT-1:0]            memory_flags_ff;
wire  [31:0]                    memory_mem_rd_data;
wire                            memory_und_ff;
wire                            memory_data_abt_ff;

// Writeback
wire [31:0] rd_data_0;
wire [31:0] rd_data_1;
wire [31:0] rd_data_2;
wire [31:0] rd_data_3;
wire [31:0] cpsr_nxt, cpsr;

wire wb_hijack;
wire [31:0] wb_hijack_op1;
wire [31:0] wb_hijack_op2;
wire wb_hijack_cin;
wire [31:0] alu_hijack_sum;

// ------------------------------
// Assign statements.
// ------------------------------
assign o_cpsr        = alu_flags_ff;
assign o_address     = {alu_address_ff[31:2], 2'd0};

// ---------------------------
// Instances.
// ---------------------------

// RESET SYNCHRONIZER //
reset_sync
U_RST_SYNC
(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .o_reset(reset)
);

// FETCH STAGE //
zap_fetch_main
#(
        .BP_ENTRIES(1024)
) 
u_zap_fetch_main (
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_clear_from_decode            (clear_from_decode),
        .i_data_stall                   (i_data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_stall_from_shifter           (stall_from_shifter),
        .i_stall_from_issue             (stall_from_issue),
        .i_stall_from_decode            (stall_from_decode),
        .i_pc_ff                        (o_pc),
        .i_instruction                  (i_instruction),
        .i_valid                        (i_valid),
        .i_instr_abort                  (i_instr_abort),
        .i_cpsr_ff_t                    (alu_flags_ff[T]),

        // Output.
        .o_instruction                  (fetch_instruction),
        .o_valid                        (fetch_valid),
        .o_instr_abort                  (fetch_instr_abort),
        .o_pc_plus_8_ff                 (fetch_pc_plus_8_ff),
        .o_pc_ff                        (fetch_pc_ff),

        .i_confirm_from_alu             (confirm_from_alu),
        .i_pc_from_alu                  (shifter_pc_ff),
        .i_taken                        (shifter_taken_ff),
        .o_taken_ff                     (fetch_bp_state)
);

// PREDECODE STAGE //
zap_predecode_main #(
        .ARCH_REGS(ARCH_REGS),
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS)
)
u_zap_predecode (
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_stall_from_shifter           (stall_from_shifter),
        .i_stall_from_issue             (stall_from_issue),
        .i_irq                          (i_irq),
        .i_fiq                          (i_fiq),

        .i_abt                          (fetch_instr_abort),
        .i_pc_plus_8_ff                 (fetch_pc_plus_8_ff),
        .i_pc_ff                        (fetch_pc_ff),

//        .i_cpu_mode                     (alu_flags_ff),

        .i_cpu_mode_t                   (alu_flags_ff[T]),
        .i_cpu_mode_f                   (alu_flags_ff[F]),
        .i_cpu_mode_i                   (alu_flags_ff[I]),

        .i_instruction                  (fetch_instruction),
        .i_instruction_valid            (fetch_valid),
        .i_taken                        (fetch_bp_state),

        .i_copro_done                   (i_copro_done),
        .i_pipeline_dav                 (
                                                predecode_val                      ||     
                                                (decode_condition_code    != NV)   ||
                                                (issue_condition_code_ff  != NV)   ||
                                                (shifter_condition_code_ff!= NV)   ||
                                                alu_dav_ff                         ||
                                                memory_dav_ff                      
                                        ),

        // Output.
        .o_stall_from_decode            (stall_from_decode),
        .o_pc_plus_8_ff                 (predecode_pc_plus_8),

        .o_pc_ff                        (predecode_pc),
        .o_irq_ff                       (predecode_irq),
        .o_fiq_ff                       (predecode_fiq),
        .o_abt_ff                       (predecode_abt),
        .o_und_ff                       (predecode_und),

        .o_force32align_ff              (predecode_force32),

        .o_copro_dav_ff                 (o_copro_dav),
        .o_copro_word_ff                (o_copro_word),

        .o_clear_from_decode            (clear_from_decode),
        .o_pc_from_decode               (pc_from_decode),

        .o_instruction_ff               (predecode_inst),
        .o_instruction_valid_ff         (predecode_val),

        .o_taken_ff                     (predecode_taken)
);

// DECODE STAGE //

zap_decode_main #(
        .ARCH_REGS(ARCH_REGS),
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS)
)
u_zap_decode_main (
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_stall_from_shifter           (stall_from_shifter),
        .i_stall_from_issue             (stall_from_issue),
        .i_thumb_und                    (predecode_und),
        .i_irq                          (predecode_irq),
        .i_fiq                          (predecode_fiq),
        .i_abt                          (predecode_abt),
        .i_pc_plus_8_ff                 (predecode_pc_plus_8),
        .i_pc_ff                        (predecode_pc),
       // .i_cpu_mode                     (alu_flags_ff),
       
        .i_cpsr_ff_mode                 (alu_flags_ff[`CPSR_MODE]),
        .i_cpsr_ff_i                    (alu_flags_ff[I]),
        .i_cpsr_ff_f                    (alu_flags_ff[F]),
       
        .i_instruction                  (predecode_inst),
        .i_instruction_valid            (predecode_val),
        .i_taken                        (predecode_taken),
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
        .o_taken_ff                     (decode_taken_ff)
);

// ISSUE //

zap_issue_main #(
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS)
       
)
u_zap_issue_main
(
        .i_und_ff(decode_und_ff),
        .o_und_ff(issue_und_ff),

        .i_taken_ff(decode_taken_ff),
        .o_taken_ff(issue_taken_ff),

        .i_pc_ff(decode_pc_ff),
        .o_pc_ff(issue_pc_ff),

        // Inputs
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_stall_from_shifter           (stall_from_shifter),
        .i_data_stall                   (i_data_stall),
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
        .i_cpu_mode                     (alu_flags_ff), // Needed to resolve CPSR refs.

        .i_force32align_ff              (decode_force32_ff),
        .o_force32align_ff              (issue_force32_ff),

        // Register file.
        .i_rd_data_0                    (rd_data_0),
        .i_rd_data_1                    (rd_data_1),
        .i_rd_data_2                    (rd_data_2),
        .i_rd_data_3                    (rd_data_3),

        // Feedback.
        .i_shifter_destination_index_ff (shifter_destination_index_ff),
        .i_alu_destination_index_ff     (alu_destination_index_ff),
        .i_memory_destination_index_ff  (memory_destination_index_ff),
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
        .i_memory_mem_srcdest_value_ff  (memory_mem_rd_data),

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

// SHIFTER STAGE //

zap_shifter_main #(
        .PHY_REGS(PHY_REGS),
        .ALU_OPS(ALU_OPS),
        .SHIFT_OPS(SHIFT_OPS)
)
u_zap_shifter_main
(
        .i_pc_ff(issue_pc_ff),
        .o_pc_ff(shifter_pc_ff),

        .i_taken_ff(issue_taken_ff),
        .o_taken_ff(shifter_taken_ff),

        .i_und_ff(issue_und_ff),
        .o_und_ff(shifter_und_ff),

        .o_nozero_ff(shifter_nozero_ff),

        // Inputs.
        .i_clk                          (i_clk),
        .i_reset                        (reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_condition_code_ff            (issue_condition_code_ff),
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
        .i_mem_translate_ff             (issue_mem_translate_ff),
        .i_irq_ff                       (issue_irq_ff),
        .i_fiq_ff                       (issue_fiq_ff),
        .i_abt_ff                       (issue_abt_ff),
        .i_swi_ff                       (issue_swi_ff),
        .i_alu_source_ff                (issue_alu_source_ff),
        .i_shift_source_ff              (issue_shift_source_ff),
        .i_alu_source_value_ff          (issue_alu_source_value_ff),
        .i_shift_source_value_ff        (issue_shift_source_value_ff),
        .i_shift_length_value_ff        (issue_shift_length_value_ff),
        .i_mem_srcdest_value_ff         (issue_mem_srcdest_value_ff),
        .i_pc_plus_8_ff                 (issue_pc_plus_8_ff),
        .i_disable_shifter_ff           (issue_shifter_disable_ff),

        // Next CPSR.
        .i_cpsr_nxt                     (alu_cpsr_nxt),

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

// ALU STAGE //

zap_alu_main #(
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS) 
)
u_zap_alu_main
(
        .i_hijack     (wb_hijack      ),
        .i_hijack_op1 ( wb_hijack_op1 ),
        .i_hijack_op2 ( wb_hijack_op2 ),
        .i_hijack_cin ( wb_hijack_cin ),
        .o_hijack_sum ( alu_hijack_sum ),

        .i_taken_ff                      (shifter_taken_ff),
        .o_confirm_from_alu              (confirm_from_alu),

        .i_pc_ff                        (shifter_pc_ff),

        .i_und_ff(shifter_und_ff),
        .o_und_ff(alu_und_ff),

        .i_nozero_ff ( shifter_nozero_ff ),

         .i_clk                          (i_clk),
         .i_reset                        (reset),
         .i_clear_from_writeback         (clear_from_writeback),     // | High Priority
         .i_data_stall                   (i_data_stall),             // V Low Priority

         .i_cpsr_nxt                     (cpsr_nxt), // FROM WB
         .i_flag_update_ff               (shifter_flag_update_ff),
         .i_switch_ff                    (shifter_switch_ff),

         .i_force32align_ff              (shifter_force32_ff),

         .i_mem_srcdest_value_ff        (shifter_mem_srcdest_value_ff),
         .i_alu_source_value_ff         (shifter_alu_source_value_ff), 
         .i_shifted_source_value_ff     (shifter_shifted_source_value_ff),
         .i_shift_carry_ff              (shifter_shift_carry_ff),
         .i_pc_plus_8_ff                (shifter_pc_plus_8_ff),

         .i_abt_ff                      (shifter_abt_ff), 
         .i_irq_ff                      (shifter_irq_ff), 
         .i_fiq_ff                      (shifter_fiq_ff), 
         .i_swi_ff                      (shifter_swi_ff),

         .i_mem_srcdest_index_ff        (shifter_mem_srcdest_index_ff),     
         .i_mem_load_ff                 (shifter_mem_load_ff),                     
         .i_mem_store_ff                (shifter_mem_store_ff),                         
         .i_mem_pre_index_ff            (shifter_mem_pre_index_ff),                
         .i_mem_unsigned_byte_enable_ff (shifter_mem_unsigned_byte_enable_ff),     
         .i_mem_signed_byte_enable_ff   (shifter_mem_signed_byte_enable_ff),       
         .i_mem_signed_halfword_enable_ff(shifter_mem_signed_halfword_enable_ff),        
         .i_mem_unsigned_halfword_enable_ff(shifter_mem_unsigned_halfword_enable_ff),      
         .i_mem_translate_ff            (shifter_mem_translate_ff),  

         .i_condition_code_ff           (shifter_condition_code_ff),
         .i_destination_index_ff        (shifter_destination_index_ff),
         .i_alu_operation_ff            (shifter_alu_operation_ff),  // { OP, S }

         .i_data_mem_fault              (i_data_abort),

         .o_alu_result_nxt              (alu_alu_result_nxt),

         .o_alu_result_ff               (alu_alu_result_ff),

         .o_abt_ff                      (alu_abt_ff),
         .o_irq_ff                      (alu_irq_ff),
         .o_fiq_ff                      (alu_fiq_ff),
         .o_swi_ff                      (alu_swi_ff),

         .o_dav_ff                      (alu_dav_ff),
         .o_dav_nxt                     (alu_dav_nxt),

         .o_pc_plus_8_ff                (alu_pc_plus_8_ff),
         .o_mem_address_ff              (alu_address_ff),                    // Memory addresss sent. Memory system should ignore lower 2 bits.
         .o_clear_from_alu              (clear_from_alu),
         .o_pc_from_alu                 (pc_from_alu),
         .o_destination_index_ff        (alu_destination_index_ff),
         .o_flags_ff                    (alu_flags_ff),                 // Output flags.
         .o_flags_nxt                   (alu_cpsr_nxt),

         .o_mem_srcdest_value_ff           (o_wr_data),        
         .o_mem_srcdest_index_ff           (alu_mem_srcdest_index_ff),     
         .o_mem_load_ff                    (alu_mem_load_ff),                     
         .o_mem_store_ff                   (o_write_en), 

         .o_ben_ff                         (o_ben),         
 
         .o_mem_unsigned_byte_enable_ff    (alu_ubyte_ff),     
         .o_mem_signed_byte_enable_ff      (alu_sbyte_ff),       
         .o_mem_signed_halfword_enable_ff  (alu_shalf_ff),        
         .o_mem_unsigned_halfword_enable_ff(alu_uhalf_ff),      
         .o_mem_translate_ff               (o_mem_translate),
        
        .o_address_nxt ( o_address_nxt )
);

assign o_read_en = alu_mem_load_ff; 

// MEMORY //

zap_memory_main #(
       .PHY_REGS(PHY_REGS) 
)
u_zap_memory_main
(
        .i_und_ff (alu_und_ff),
        .o_und_ff (memory_und_ff),

        .i_mem_address_ff(alu_address_ff[1:0]),

        .i_clk                          (i_clk),
        .i_reset                        (reset),

        .i_sbyte_ff                     (alu_sbyte_ff),     // Signed byte.
        .i_ubyte_ff                     (alu_ubyte_ff),     // Unsigned byte.
        .i_shalf_ff                     (alu_shalf_ff),     // Signed half word.
        .i_uhalf_ff                     (alu_uhalf_ff),     // Unsigned half word.
        
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_alu_result_ff                (alu_alu_result_ff),
        .i_flags_ff                     (alu_flags_ff), 
        
        .i_mem_load_ff                  (alu_mem_load_ff),
        .i_mem_rd_data                  (i_rd_data),            // From memory <----- EXTERNAL.
        .i_mem_fault                    (i_data_abort),         // From memory <----- EXTERNAL.
        .o_mem_fault                    (memory_data_abt_ff),         

        .i_dav_ff                       (alu_dav_ff),
        .i_pc_plus_8_ff                 (alu_pc_plus_8_ff),
         
        .i_destination_index_ff         (alu_destination_index_ff),
         
        .i_irq_ff                       (alu_irq_ff),
        .i_fiq_ff                       (alu_fiq_ff),
        .i_instr_abort_ff               (alu_abt_ff),
        .i_swi_ff                       (alu_swi_ff),
         
        .i_mem_srcdest_index_ff         (alu_mem_srcdest_index_ff), // Used to accelerate loads.
        .i_mem_srcdest_value_ff         (o_wr_data),                // Can come in handy.        
 
        .o_alu_result_ff                (memory_alu_result_ff),
        .o_flags_ff                     (memory_flags_ff),         

        .o_destination_index_ff         (memory_destination_index_ff),
        .o_mem_srcdest_index_ff         (memory_mem_srcdest_index_ff),
 
        .o_dav_ff                       (memory_dav_ff),
        .o_pc_plus_8_ff                 (memory_pc_plus_8_ff),
         
        .o_irq_ff                       (memory_irq_ff),
        .o_fiq_ff                       (memory_fiq_ff),
        .o_swi_ff                       (memory_swi_ff),
        .o_instr_abort_ff               (memory_instr_abort_ff),
         
        .o_mem_load_ff                  (memory_mem_load_ff),


        .o_mem_rd_data                 (memory_mem_rd_data)
);

// WRITEBACK //

zap_register_file #(
        .PHY_REGS(PHY_REGS)
)
u_zap_regf
(
        .i_clk                  (i_clk),     // ZAP clock.

        .i_clk_2x               (i_clk_2x),  // 2xZAP clock.

        .i_reset                (reset),   // ZAP reset.
        .i_valid                (memory_dav_ff),
        .i_data_stall           (i_data_stall),
        .i_clear_from_alu       (clear_from_alu),
        .i_pc_from_alu          (pc_from_alu),
        .i_stall_from_decode    (stall_from_decode),
        .i_stall_from_issue     (stall_from_issue),
        .i_stall_from_shifter   (stall_from_shifter),

        .i_clear_from_decode    (clear_from_decode),
        .i_pc_from_decode       (pc_from_decode),

        .i_code_stall           (!i_valid),

        .i_mem_load_ff          (memory_mem_load_ff), // Used to valid writes on i_wr_index1.

        .i_rd_index_0           (rd_index_0), 
        .i_rd_index_1           (rd_index_1), 
        .i_rd_index_2           (rd_index_2), 
        .i_rd_index_3           (rd_index_3),

        .i_wr_index             (memory_destination_index_ff),
        .i_wr_data              (memory_alu_result_ff),
        .i_flags                (memory_flags_ff),
        .i_wr_index_1           (memory_mem_srcdest_index_ff),  // Memory load index.
        .i_wr_data_1            (memory_mem_rd_data),        // Memory load data.

        .i_irq                  (memory_irq_ff),
        .i_fiq                  (memory_fiq_ff),
        .i_instr_abt            (memory_instr_abort_ff),
        .i_data_abt             (memory_data_abt_ff),
        .i_swi                  (memory_swi_ff),    
        .i_und                  (memory_und_ff),

        .i_pc_buf_ff            (memory_pc_plus_8_ff),

        .i_copro_reg_en         (i_copro_reg_en),
        .i_copro_reg_wr_index   (i_copro_reg_wr_index),
        .i_copro_reg_rd_index   (i_copro_reg_rd_index),
        .i_copro_reg_wr_data    (i_copro_reg_wr_data),

        .o_copro_reg_rd_data_ff (o_copro_reg_rd_data),
        
        .o_rd_data_0            (rd_data_0),         
        .o_rd_data_1            (rd_data_1),         
        .o_rd_data_2            (rd_data_2),         
        .o_rd_data_3            (rd_data_3),

        .o_pc                   (o_pc),
        .o_pc_nxt               (o_pc_nxt),
        .o_cpsr_nxt             (cpsr_nxt),
        .o_clear_from_writeback (clear_from_writeback),

        .o_hijack               (wb_hijack),
        .o_hijack_op1           (wb_hijack_op1),
        .o_hijack_op2           (wb_hijack_op2),
        .o_hijack_cin           (wb_hijack_cin),

        .i_hijack_sum           (alu_hijack_sum)
);

// Pipeline controls exposed.
assign o_clear_from_writeback = clear_from_writeback;
assign o_clear_from_alu     = clear_from_alu;
assign o_stall_from_shifter = stall_from_shifter;
assign o_stall_from_issue   = stall_from_issue;
assign o_stall_from_decode  = stall_from_decode;
assign o_clear_from_decode  = clear_from_decode;

endmodule
