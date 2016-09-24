`default_nettype none

/*
Filename --
zap_top.v

HDL --
Verilog-2005

Dependencies --
zap_fetch_main
zap_decode_main
zap_issue_main
zap_shift_main
zap_alu_main
zap_memory_main
zap_register_file

Description --
This is the TOP module of the ZAP core. It contains only instantiations of
submodules for easy debugging. ZAP is an ARM v4T compatible processor core
intended for open source use.

Author --
Revanth Kamaraj.

License --
Released under the MIT license.
*/

module zap_top #(
        // For several reasons, we need more architectural registers than
        // what ARM specifies. We also need more physical registers. This has
        // *nothing* to do with superscalar terminology. THIS PROCESSOR IS A 
        // SINGLE ISSUE SCALAR PROCESSOR.
        parameter ARCH_REGS = 32,

        // Although ARM mentions only 16 ALU operations, the processor
        // internally performs many more operations.
        parameter ALU_OPS   = 32,

        // Apart from the 4 specified by ARM, an undocumented RORI is present
        // to help deal with immediate rotates.
        parameter SHIFT_OPS = 5,

        // Number of physical registers. Architectural registers map to
        // physical registers in a fixed way.
        parameter PHY_REGS = 64,

        // Width of the flags.
        parameter FLAG_WDT = 32
)
(
                // Clock and reset.
                input wire              i_clk,                  // ZAP clock.        
                input wire              i_reset,                // Active high synchronous reset.
                                
                // From I-cache.
                input wire [31:0]       i_instruction,          // A 32-bit ZAP instruction or a microcode instruction.
                input wire              i_valid,                // Instruction valid.
                input wire              i_instr_abort,          // Instruction abort fault.

                // Coprocessor.
                input wire              i_copro_done,

                // Memory access.
                output wire             o_read_en,              // Memory load
                output wire             o_write_en,             // Memory store.
                output wire[31:0]       o_address,              // Memory address.
                output wire             o_unsigned_byte_en,      // Unsigned byte enable.
                output wire             o_signed_byte_en,       // Signed byte enable.
                output wire             o_unsigned_halfword_en, // Unsiged halfword enable.
                output wire             o_signed_halfword_en,   // Signed halfword enable.

                // User view.
                output wire             o_mem_translate,

                // Memory stall.
                input wire              i_data_stall,
                
                // Memory abort.
                input wire              i_data_abort,

                // Memory read data.
                input wire  [31:0]      i_rd_data,

                // Memory write data.
                output wire [31:0]      o_wr_data,

                // Interrupts.
                input wire              i_fiq,                  // FIQ signal.
                input wire              i_irq,                  // IRQ signal.

                // Coprocessor.
                output wire  [31:0]                     o_copro_mode,   // THE CPSR Exposed to the CoProcessor. Copro must do conditional checks if needed.
                output wire                             o_copro_dav,
                output wire  [31:0]                     o_copro_word,
                output wire  [$clog2(PHY_REGS)-1:0]     o_copro_reg,

                // Coprocessor direct register access.
                input wire                              i_copro_reg_en,         // Coprocessor controls register file.
                input wire      [$clog2(PHY_REGS)-1:0]  i_copro_reg_wr_index,   // Register write index.
                input wire      [$clog2(PHY_REGS)-1:0]  i_copro_reg_rd_index,   // Register read index.
                input wire      [31:0]                  i_copro_reg_wr_data,    // Register write data.

                // Data from register file to coprocessor.
                output wire     [31:0]                  o_copro_reg_rd_data,    // Coprocessor read data from register file.

                // Interrupt acknowledge.
                output wire             o_fiq_ack,              // FIQ acknowledge.
                output wire             o_irq_ack,              // IRQ acknowledge.

                // Program counter.
                output wire[31:0]       o_pc,                   // Program counter.

                // CPSR.
                output wire [31:0]      o_cpsr                  // CPSR. Cache must use this to determine size of code fetches, VM scheme etc for instruction fetches.
);

`include "cc.vh"

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
wire                            decode_taken_ff;

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
wire [32:0]                     issue_shift_length_ff;
wire [31:0]                     issue_pc_plus_8_ff;
wire [31:0]                     issue_pc_ff;
wire                            issue_shifter_disable_ff;
wire                            issue_switch_ff;
wire                            issue_force32_ff;
wire                            issue_und_ff;
wire                            issue_taken_ff;

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
wire [$clog2(SHIFT_OPS)-1:0] shifter_shift_operation_ff;
wire shifter_flag_update_ff;
wire [31:0] shifter_mem_srcdest_value_ff;
wire [31:0] shifter_alu_source_value_ff;
wire [31:0] shifter_shifted_source_value_ff;
wire shifter_shift_carry_ff;
wire shifter_rrx_ff;
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
wire shifter_use_old_carry_ff;
wire shifter_taken_ff;

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
wire                            alu_flag_update_ff;
wire                            alu_und_ff;
wire [31:0]                     alu_cpsr_nxt; //TODO: Eliminate this  and place MAC in ALU itself.
wire                            confirm_from_alu;

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
wire                            memory_flag_update_ff;
wire  [31:0]                    memory_mem_rd_data_ff;
wire                            memory_und_ff;
wire                            memory_data_abt_ff;

// Writeback
wire [31:0] rd_data_0;
wire [31:0] rd_data_1;
wire [31:0] rd_data_2;
wire [31:0] rd_data_3;
wire [31:0] cpsr_nxt, cpsr;

// Predictor.
wire [31:0]     bp_inst;
wire            bp_val;
wire            bp_abt;
wire [31:0]     bp_pc_plus_8;
wire            bp_state;
wire [31:0]     bp_pc;

assign o_cpsr           = alu_flags_ff;

// FETCH STAGE //
zap_fetch_main 
u_zap_fetch_main (
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (i_reset),
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
        .i_cpsr_ff                      (o_cpsr),

        // Output.
        .o_instruction                  (fetch_instruction),
        .o_valid                        (fetch_valid),
        .o_instr_abort                  (fetch_instr_abort),
        .o_pc_plus_8_ff                 (fetch_pc_plus_8_ff),
        .o_pc_ff                        (fetch_pc_ff)
);

// PREDICTOR STAGE //
zap_branch_predict
u_zap_branch_predict
(
        // Input.
        .i_clk                          (i_clk),
        .i_reset                        (i_reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_confirm_from_alu             (confirm_from_alu),
        .i_pc_from_alu                  (shifter_pc_ff),     
        .i_inst                         (fetch_instruction),
        .i_val                          (fetch_valid),
        .i_abt                          (fetch_instr_abort),
        .i_pc_plus_8                    (fetch_pc_plus_8_ff),
        .i_pc                           (fetch_pc_ff),

        .i_stall_from_shifter           (stall_from_shifter),
        .i_stall_from_issue             (stall_from_issue),
        .i_stall_from_decode            (stall_from_decode),
        .i_clear_from_decode            (clear_from_decode),

        // Output.
        .o_inst_ff                      (bp_inst),
        .o_val_ff                       (bp_val),
        .o_abt_ff                       (bp_abt),
        .o_pc_plus_8_ff                 (bp_pc_plus_8),
        .o_pc_ff                        (bp_pc),
        .o_taken_ff                     (bp_state)
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
        .i_reset                        (i_reset),
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_clear_from_alu               (clear_from_alu),
        .i_stall_from_shifter           (stall_from_shifter),
        .i_stall_from_issue             (stall_from_issue),
        .i_irq                          (i_irq),
        .i_fiq                          (i_fiq),

        .i_abt                          (bp_abt),
        .i_pc_plus_8_ff                 (bp_pc_plus_8),
        .i_pc_ff                        (bp_pc),
        .i_cpu_mode                     (o_cpsr),
        .i_instruction                  (bp_inst),
        .i_instruction_valid            (bp_val),
        .i_taken                        (bp_state),

        .i_copro_done                   (i_copro_done),
        .i_pipeline_dav                 (
                                                (decode_condition_code    != NV)   ||
                                                (issue_condition_code_ff  != NV)   ||
                                                (shifter_condition_code_ff!= NV)   ||
                                                alu_dav_ff                         ||
                                                memory_dav_ff                      
                                        ),

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
        .o_stall_from_decode            (stall_from_decode),
        .o_pc_plus_8_ff                 (decode_pc_plus_8_ff),
        .o_pc_ff                        (decode_pc_ff),
        .o_switch_ff                    (decode_switch_ff), 
        .o_irq_ff                       (decode_irq_ff),
        .o_fiq_ff                       (decode_fiq_ff),
        .o_abt_ff                       (decode_abt_ff),
        .o_swi_ff                       (decode_swi_ff),
        .o_und_ff                       (decode_und_ff),
        .o_force32align_ff              (decode_force32_ff),

        .o_copro_mode_ff                (o_copro_mode),
        .o_copro_dav_ff                 (o_copro_dav),
        .o_copro_word_ff                (o_copro_word),
        .o_copro_reg_ff                 (o_copro_reg),

        .o_clear_from_decode            (clear_from_decode),
        .o_pc_from_decode               (pc_from_decode),

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
        .i_reset                        (i_reset),
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
        .i_memory_mem_srcdest_value_ff  (memory_mem_rd_data_ff),

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
        .o_shift_length_ff              (issue_shift_length_ff),
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

        // Inputs.
        .i_clk                          (i_clk),
        .i_reset                        (i_reset),
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
        .i_shift_length_ff              (issue_shift_length_ff),
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
        .o_rrx_ff                       (shifter_rrx_ff),

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
        .o_shift_operation_ff           (shifter_shift_operation_ff),
        .o_flag_update_ff               (shifter_flag_update_ff),

        // Interrupts.
        .o_irq_ff                       (shifter_irq_ff), 
        .o_fiq_ff                       (shifter_fiq_ff), 
        .o_abt_ff                       (shifter_abt_ff), 
        .o_swi_ff                       (shifter_swi_ff),

        // Stall
        .o_stall_from_shifter           (stall_from_shifter),

        .o_use_old_carry_ff             (shifter_use_old_carry_ff)
);

// ALU STAGE //

zap_alu_main #(
        .PHY_REGS(PHY_REGS),
        .SHIFT_OPS(SHIFT_OPS),
        .ALU_OPS(ALU_OPS) 
)
u_zap_alu_main
(
        .i_taken_ff                      (shifter_taken_ff),
        .o_confirm_from_alu              (confirm_from_alu),

        .i_und_ff(shifter_und_ff),
        .o_und_ff(alu_und_ff),

         .i_clk                          (i_clk),
         .i_reset                        (i_reset),
         .i_clear_from_writeback         (clear_from_writeback),     // | High Priority
         .i_data_stall                   (i_data_stall),             // V Low Priority

         .i_use_old_carry_ff             (shifter_use_old_carry_ff),

         .i_cpsr_ff                      (cpsr),
         .i_cpsr_nxt                     (cpsr_nxt),
         .i_flag_update_ff               (shifter_flag_update_ff),
         .i_switch_ff                    (shifter_switch_ff),

         .i_force32align_ff              (shifter_force32_ff),

         .i_mem_srcdest_value_ff        (shifter_mem_srcdest_value_ff),
         .i_alu_source_value_ff         (shifter_alu_source_value_ff), 
         .i_shifted_source_value_ff     (shifter_shifted_source_value_ff),
         .i_shift_carry_ff              (shifter_shift_carry_ff),
         .i_rrx_ff                      (shifter_rrx_ff),
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
         .o_mem_address_ff              (o_address),          // Memory addresss sent. 
         .o_clear_from_alu              (clear_from_alu),
         .o_pc_from_alu                 (pc_from_alu),
         .o_destination_index_ff        (alu_destination_index_ff),
         .o_flags_ff                    (alu_flags_ff),           // Output flags.
         .o_flags_nxt                   (alu_cpsr_nxt),

         .o_mem_srcdest_value_ff           (o_wr_data),
         .o_mem_srcdest_index_ff           (alu_mem_srcdest_index_ff),     
         .o_mem_load_ff                    (alu_mem_load_ff),                     
         .o_mem_store_ff                   (o_write_en),                         
         .o_mem_unsigned_byte_enable_ff    (o_unsigned_byte_en),     
         .o_mem_signed_byte_enable_ff      (o_signed_byte_en),       
         .o_mem_signed_halfword_enable_ff  (o_signed_halfword_en),        
         .o_mem_unsigned_halfword_enable_ff(o_unsigned_halfword_en),      
         .o_mem_translate_ff               (o_mem_translate),

        .o_flag_update_ff                  (alu_flag_update_ff) 
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

        .i_clk                          (i_clk),
        .i_reset                        (i_reset),
         
        .i_clear_from_writeback         (clear_from_writeback),
        .i_data_stall                   (i_data_stall),
        .i_alu_result_ff                (alu_alu_result_ff),
        .i_flags_ff                     (alu_flags_ff), 
        
        .i_mem_load_ff                  (alu_mem_load_ff),
        .i_mem_rd_data                  (i_rd_data), // From memory.
        .i_mem_fault                    (i_data_abort),// From memory.
        .o_mem_fault                    (memory_data_abt_ff),         

        .i_dav_ff                       (alu_dav_ff),
        .i_pc_plus_8_ff                 (alu_pc_plus_8_ff),
         
        .i_destination_index_ff         (alu_destination_index_ff),
         
        .i_irq_ff                       (alu_irq_ff),
        .i_fiq_ff                       (alu_fiq_ff),
        .i_instr_abort_ff               (alu_abt_ff),
        .i_swi_ff                       (alu_swi_ff),
         
        .i_mem_srcdest_index_ff         (alu_mem_srcdest_index_ff), // Used to accelerate loads.
         
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

        .i_flag_update_ff               (alu_flag_update_ff),
        .o_flag_update_ff               (memory_flag_update_ff),

        .o_mem_rd_data_ff               (memory_mem_rd_data_ff)
);

// WRITEBACK //

zap_register_file #(
        .PHY_REGS(PHY_REGS)
)
u_zap_regf
(
        .i_clk                  (i_clk),   // ZAP clock.
        .i_reset                (i_reset),   // ZAP reset.
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

        .i_flag_update_ff       (memory_flag_update_ff),

        .i_mem_load_ff          (memory_mem_load_ff), // Used to valid writes on i_wr_index1.

        .i_rd_index_0           (rd_index_0), 
        .i_rd_index_1           (rd_index_1), 
        .i_rd_index_2           (rd_index_2), 
        .i_rd_index_3           (rd_index_3),

        .i_wr_index             (memory_destination_index_ff),
        .i_wr_data              (memory_alu_result_ff),
        .i_flags                (memory_flags_ff),
        .i_wr_index_1           (memory_mem_srcdest_index_ff),  // Memory load index.
        .i_wr_data_1            (memory_mem_rd_data_ff),        // Memory load data.

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
        .o_cpsr                 (cpsr),
        .o_cpsr_nxt             (cpsr_nxt),
        .o_clear_from_writeback (clear_from_writeback),

        .o_fiq_ack              (o_fiq_ack),
        .o_irq_ack              (o_irq_ack)
);

endmodule
