`default_nettype none

/*
Filename --
zap_decode_stage.v

Author --
Revanth Kamaraj

Description --
ZAP decode stage. This is the top level decode stage of the ZAP.

Dependencies --
zap_decode_mem_fsm
zap_decode_bl_fsm
zap_decode_coproc_fsm
zap_decode_mult_fsm
zap_decode

Author --
Revanth Kamaraj

License --
Released under the MIT license.
*/

module zap_decode_main #(
        // For several reasons, we need more architectural registers than
        // what ARM specifies. We also need more physical registers.
        parameter ARCH_REGS = 32,

        // Although ARM mentions only 16 ALU operations, the processor
        // internally performs many more operations.
        parameter ALU_OPS   = 32,

        // Apart from the 4 specified by ARM, an undocumented RORI is present
        // to help deal with immediate rotates.
        parameter SHIFT_OPS = 5,

        // Number of physical registers.
        parameter PHY_REGS = 46
)
(
        // Clock and reset.
        input   wire                    i_clk,
        input   wire                    i_reset,

        // Branch state.
        input   wire                    i_taken,

        // Clear and stall signals. 
        input wire                      i_clear_from_writeback, // | Priority
        input wire                      i_data_stall,           // |
        input wire                      i_clear_from_alu,       // |
        input wire                      i_stall_from_shifter,   // |
        input wire                      i_stall_from_issue,     // V

        // Interrupt events.
        input   wire                    i_irq,
        input   wire                    i_fiq,
        input   wire                    i_abt,

        // Coprocessor module related.
        input   wire                    i_pipeline_dav, // Is 0 if all pipeline is INVALID.
        input   wire                    i_copro_done,

        // PC input.
        input wire  [31:0]              i_pc_ff,
        input wire  [31:0]              i_pc_plus_8_ff,

        // CPU mode. Taken from CPSR.
        input   wire    [31:0]                   i_cpu_mode,

        // Instruction input.
        input     wire  [31:0]                  i_instruction,    
        // The upper 2-bit are {rd/ptr,rm/srcdest}
        input     wire                          i_instruction_valid,
       
        // This signal is used to check the validity of a pipeline stage.
        output   reg    [3:0]                   o_condition_code_ff,
        
        // Where the primary output of the instruction must go to. Make this RAZ
        // to throw away the primary output to a void.
        output   reg    [$clog2(PHY_REGS)-1:0] o_destination_index_ff,
        
        // The ALU source is the source that is fed directly to the ALU without the
        // barrel shifter. For multiplication, o_alu_source simply becomes an operand.
        output   reg    [32:0]                  o_alu_source_ff,
        output   reg    [$clog2(ALU_OPS)-1:0]   o_alu_operation_ff,
        
        // Stuff related to the shifter. For multiplication, the source and length
        // simply become two operands.
        output   reg    [32:0]                  o_shift_source_ff,
        output   reg    [$clog2(SHIFT_OPS)-1:0] o_shift_operation_ff,
        output   reg    [32:0]                  o_shift_length_ff,
        
        // Update the flags. Note that writing to CPSR will cause a flag-update (if
        // you asked for) even if this is 0.
        output  reg                             o_flag_update_ff,
        
        // Things related to memory operations.
        output  reg   [$clog2(PHY_REGS)-1:0]    o_mem_srcdest_index_ff,            // Data register index.
        output  reg                             o_mem_load_ff,                     // Type of operation...
        output  reg                             o_mem_store_ff,
        output  reg                             o_mem_pre_index_ff,                // Indicate pre-ALU tap for address.
        output  reg                             o_mem_unsigned_byte_enable_ff,     // Byte enable (unsigned).
        output  reg                             o_mem_signed_byte_enable_ff,       
        output  reg                             o_mem_signed_halfword_enable_ff,
        output  reg                             o_mem_unsigned_halfword_enable_ff,
        output  reg                             o_mem_translate_ff,                // Force user's view of memory.
        
        // Stall of PC and fetch.
        output  reg                             o_stall_from_decode,

        // PC output.
        output  reg  [31:0]                     o_pc_plus_8_ff,       
        output  reg  [31:0]                     o_pc_ff,

        // Switch.
        output  reg                             o_switch_ff,
 
        // Interrupts.
        output  reg                             o_irq_ff,
        output  reg                             o_fiq_ff,
        output  reg                             o_abt_ff,
        output  reg                             o_und_ff,
        output  reg                             o_swi_ff,  // EX tests for condition validity.

        // Force 32-bit alignment on memory accesses.
        output reg                              o_force32align_ff,

        // Coprocessor interface.
        output wire  [31:0]                     o_copro_mode_ff,
        output wire                             o_copro_dav_ff,
        output wire  [31:0]                     o_copro_word_ff,
        output wire  [$clog2(PHY_REGS)-1:0]     o_copro_reg_ff,

        // Branch.
        output reg                              o_taken_ff,

        // Clear from decode.
        output reg                              o_clear_from_decode,
        output reg [31:0]                       o_pc_from_decode
);

`include "cc.vh"
`include "regs.vh"
`include "modes.vh"
`include "index_immed.vh"
`include "cpsr.vh"
`include "global_functions.vh"

wire    [3:0]                   o_condition_code_nxt;
wire    [$clog2(PHY_REGS )-1:0] o_destination_index_nxt;
wire    [32:0]                  o_alu_source_nxt;
wire    [$clog2(ALU_OPS)-1:0]   o_alu_operation_nxt;
wire    [32:0]                  o_shift_source_nxt;
wire    [$clog2(SHIFT_OPS)-1:0] o_shift_operation_nxt;
wire    [32:0]                  o_shift_length_nxt;
wire                            o_flag_update_nxt;
wire   [$clog2(PHY_REGS )-1:0]  o_mem_srcdest_index_nxt;            // Data register.
wire                            o_mem_load_nxt;                     // Type of operation...
wire                            o_mem_store_nxt;
wire                            o_mem_pre_index_nxt;                // Indicate pre-ALU tap for address.
wire                            o_mem_unsigned_byte_enable_nxt;     // Byte enable (unsigned).
wire                            o_mem_signed_byte_enable_nxt;       
wire                            o_mem_signed_halfword_enable_nxt;
wire                            o_mem_unsigned_halfword_enable_nxt;
wire                            o_mem_translate_nxt;                // Force user's view of memory.
wire                            o_force_locked_access_nxt;
wire                            o_irq_nxt;
wire                            o_fiq_nxt;
wire                            o_abt_nxt;
reg                             o_swi_nxt;
wire                            o_und_nxt;
wire                            o_switch_nxt;

wire            mem_irq;
wire            mem_fiq;
wire    [34:0]  mem_instruction;
wire            mem_instruction_valid;
wire            mem_fetch_stall;

wire   [34:0]   bl_instruction;
wire            bl_instruction_valid;
wire            bl_fetch_stall;
wire            bl_irq;
wire            bl_fiq;

wire   [35:0]   mult_instruction;
wire            mult_instruction_valid;
wire            mult_stall;

wire o_thumb_und_nxt;
wire arm_irq;
wire arm_fiq;

wire [34:0] arm_instruction;
wire arm_instruction_valid;
wire o_force32align_nxt;

wire cp_stall;
wire [31:0] cp_instruction;
wire cp_instruction_valid;
wire cp_irq;
wire cp_fiq;

reg taken_nxt;

always @*
begin
        // The actual decision whether or not to execute this is taken in EX stage.
        // Passed instructions are pointless anyway since they will not be executed.
        o_swi_nxt = &i_instruction[27:24]; 
end

        // Abort
assign  o_abt_nxt = i_abt;

// Flop the outputs to break the pipeline at this point.
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
                // Preserve state.
        end
        else if ( i_clear_from_alu )
        begin
                clear;
        end
        else if ( i_stall_from_shifter )
        begin
                // Preserve state.
        end
        else if ( i_stall_from_issue )
        begin
                // Preserve state.
        end
        // If no stall, only then update...
        else
        begin
                o_irq_ff                                <= o_irq_nxt & !i_cpu_mode[I]; // If mask is 1, do not pass.
                o_fiq_ff                                <= o_fiq_nxt & !i_cpu_mode[F]; // If mask is 1, do not pass.
                o_swi_ff                                <= o_swi_nxt;
                o_abt_ff                                <= o_abt_nxt;                    
                o_und_ff                                <= (o_und_nxt || o_thumb_und_nxt) && i_instruction_valid;
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
                o_switch_ff                             <= o_switch_nxt;
                o_force32align_ff                       <= o_force32align_nxt;
                o_taken_ff                              <= taken_nxt;
        end
end

task clear;
begin
                o_irq_ff                                <= 0;
                o_fiq_ff                                <= 0;
                o_swi_ff                                <= 0; 
                o_abt_ff                                <= 0; 
                o_condition_code_ff                     <= NV;
                o_destination_index_ff                  <= 0; 
                o_alu_source_ff                         <= 0; 
                o_alu_operation_ff                      <= 0; 
                o_shift_source_ff                       <= 0; 
                o_shift_operation_ff                    <= 0; 
                o_shift_length_ff                       <= 0; 
                o_flag_update_ff                        <= 0; 
                o_mem_srcdest_index_ff                  <= RAZ_REGISTER; 
                o_mem_load_ff                           <= 0; 
                o_mem_store_ff                          <= 0; 
                o_mem_pre_index_ff                      <= 0;             
                o_mem_unsigned_byte_enable_ff           <= 0; 
                o_mem_signed_byte_enable_ff             <= 0; 
                o_mem_signed_halfword_enable_ff         <= 0; 
                o_mem_unsigned_halfword_enable_ff       <= 0; 
                o_mem_translate_ff                      <= 0;
                o_pc_plus_8_ff                          <= 32'd8;
                o_und_ff                                <= 0;
                o_switch_ff                             <= 0; 
                o_force32align_ff                       <= 0;
                o_taken_ff                              <= 0;
                o_pc_ff                                 <= 0;
end
endtask

always @*
begin
        o_stall_from_decode = bl_fetch_stall || mem_fetch_stall || cp_stall || mult_stall;
end

// This unit handles coprocessor stuff.
zap_decode_coproc 
#(
        .PHY_REGS(PHY_REGS)
)
u_zap_decode_coproc
(
        // Inputs from outside world.
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_irq(i_instruction_valid ? i_irq : 1'd0),
        .i_fiq(i_instruction_valid ? i_fiq : 1'd0),
        .i_instruction(i_instruction_valid ? i_instruction : 32'd0),
        .i_valid(i_instruction_valid),
        .i_cpsr_ff(i_cpu_mode),

        // Clear and stall signals.
        .i_clear_from_writeback(i_clear_from_writeback),
        .i_data_stall(i_data_stall),          
        .i_clear_from_alu(i_clear_from_alu),      
        .i_stall_from_issue(i_stall_from_issue), 
        .i_stall_from_shifter(i_stall_from_shifter),

        // Valid signals.
        .i_pipeline_dav (i_pipeline_dav),

        // Coprocessor
        .i_copro_done(i_copro_done),

        // Output to next block.
        .o_instruction(cp_instruction),
        .o_valid(cp_instruction_valid),
        .o_irq(cp_irq),
        .o_fiq(cp_fiq),

        // Stall.
        .o_stall_from_decode(cp_stall),

        // Coprocessor interface.
        .o_copro_mode_ff(o_copro_mode_ff),
        .o_copro_dav_ff(o_copro_dav_ff),
        .o_copro_word_ff(o_copro_word_ff),
        .o_copro_reg_ff(o_copro_reg_ff)
);

// This unit handles decompression.
zap_decode_thumb u_zap_decode_thumb (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_irq(cp_irq),
        .i_fiq(cp_fiq),
        .i_instruction(cp_instruction),
        .i_instruction_valid(cp_instruction_valid),
        .i_cpsr_ff(i_cpu_mode),

        .o_instruction(arm_instruction),
        .o_instruction_valid(arm_instruction_valid),
        .o_irq(arm_irq),
        .o_fiq(arm_fiq),
        .o_force32_align(o_force32align_nxt),
        .o_und(o_thumb_und_nxt)
);

// Branch states.
localparam      SNT     =       0; // Strongly Not Taken.
localparam      WNT     =       1; // Weakly Not Taken.
localparam      WT      =       2; // Weakly Taken.
localparam      ST      =       3; // Strongly Taken.

always @*
begin:bprblk1
        reg [31:0] addr;
        reg [31:0] addr_final;

        o_clear_from_decode     = 1'd0;
        o_pc_from_decode        = 32'd0;
        taken_nxt               = 1'd0;
        addr                    = $signed(arm_instruction[23:0]);
        
        if ( arm_instruction[34] )
                addr_final = addr << 1;
        else
                addr_final = addr << 2;

        if ( arm_instruction[27:25] == 3'b101 && arm_instruction_valid )
        begin
                if ( i_taken || arm_instruction[31:28] == AL ) // Taken or Strongly Taken or Always taken.
                begin
                        // Take the branch.
                        o_clear_from_decode = 1'd1;

                        // Predict new PC.
                        o_pc_from_decode    = i_pc_plus_8_ff + addr_final;

                        // Set as taken.
                        taken_nxt           = 1'd1;
                end
                else // Not Taken or Weakly Not Taken.
                begin
                        // Else dont.
                        o_clear_from_decode = 1'd0;
                        o_pc_from_decode    = 32'd0;
                        taken_nxt           = 1'd0;
                end
        end
end

// This FSM handles LDM/STM/SWAP/SWAPB
zap_decode_mem_fsm u_zap_mem_fsm (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_instruction(arm_instruction),
        .i_instruction_valid(arm_instruction_valid),
        .i_fiq(arm_fiq),
        .i_irq(arm_irq),

        .i_clear_from_writeback(i_clear_from_writeback),
        .i_data_stall(i_data_stall),          
        .i_clear_from_alu(i_clear_from_alu),      
        .i_issue_stall(i_stall_from_issue), 
        .i_stall_from_shifter(i_stall_from_shifter),

        .o_irq(mem_irq),
        .o_fiq(mem_fiq),
        .o_instruction(mem_instruction),
        .o_instruction_valid(mem_instruction_valid),
        .o_stall_from_decode(mem_fetch_stall)
);

// This FSM handles BL.
zap_decode_bl_fsm u_zap_bl_fsm (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_fiq(mem_fiq),
        .i_irq(mem_irq),

        .i_cpsr_ff(i_cpu_mode),
        .i_clear_from_writeback(i_clear_from_writeback),
        .i_data_stall(i_data_stall),          
        .i_clear_from_alu(i_clear_from_alu),      
        .i_stall_from_issue(i_stall_from_issue), 

        .i_stall_from_shifter(i_stall_from_shifter),

        .i_instruction(mem_instruction),
        .i_instruction_valid(mem_instruction_valid), 
        .o_instruction(bl_instruction),
        .o_instruction_valid(bl_instruction_valid),
        .o_stall_from_decode(bl_fetch_stall),
        .o_fiq(bl_fiq),
        .o_irq(bl_irq)
);

// Multiplication FSM - Breaks long multiplies into smaller things..
zap_decode_mult_fsm u_zap_decode_mult_fsm (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_fiq(bl_fiq),
        .i_irq(bl_irq),
        .i_clear_from_writeback(i_clear_from_writeback),
        .i_data_stall(i_data_stall),
        .i_clear_from_alu(i_clear_from_alu),
        .i_stall_from_issue(i_stall_from_issue),
        .i_stall_from_shifter(i_stall_from_shifter),
        .i_instruction(bl_instruction),
        .i_instruction_valid(bl_instruction_valid),

        .o_instruction      (mult_instruction),
        .o_instruction_valid(mult_instruction_valid),
        .o_stall_from_decode(mult_stall), 
        .o_irq              (o_irq_nxt),
        .o_fiq              (o_fiq_nxt)
);

wire [$clog2(ARCH_REGS)-1:0] destination_index_nxt;
wire [32:0] alu_source_nxt;
wire [32:0] shift_source_nxt;
wire [32:0] shift_length_nxt;
wire [$clog2(ARCH_REGS)-1:0] mem_srcdest_index_nxt;

// This section translates the indices from the decode stage converts
// into a physical index. In UCODE mode, no translation is done.
assign  o_destination_index_nxt = 
        translate ( destination_index_nxt, i_cpu_mode[4:0] );
        
assign  o_alu_source_nxt = 
        (alu_source_nxt[32] == IMMED_EN ) ?
        alu_source_nxt :
        translate ( alu_source_nxt, i_cpu_mode[4:0] );

assign  o_shift_source_nxt = 
        (shift_source_nxt[32] == IMMED_EN ) ?
        shift_source_nxt :
        translate ( shift_source_nxt, i_cpu_mode[4:0] );

assign  o_shift_length_nxt =
        (shift_length_nxt[32] == IMMED_EN ) ?
        shift_length_nxt :
        translate ( shift_length_nxt, i_cpu_mode[4:0] );

assign  o_mem_srcdest_index_nxt =       
        translate ( mem_srcdest_index_nxt, i_cpu_mode[4:0] );

// Bulk of the decode logic is here.
zap_decode #(
        .ARCH_REGS      (ARCH_REGS),
        .ALU_OPS        (ALU_OPS),
        .SHIFT_OPS      (SHIFT_OPS)
) 
u_zap_decode (
        .i_instruction(mult_instruction),          
        .i_instruction_valid(mult_instruction_valid),
        .i_cpsr_ff(i_cpu_mode),
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

endmodule
