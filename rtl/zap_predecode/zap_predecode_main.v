`default_nettype none
`include "config.vh"

/*
Filename --
zap_decode_stage.v

Author --
Revanth Kamaraj

Description --
ZAP decode stage. This is the top level decode stage of the ZAP.

Author --
Revanth Kamaraj

License --
Released under the MIT license.
*/

module zap_predecode_main #(
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
        input   wire                            i_clk,
        input   wire                            i_reset,

        // Branch state.
        input   wire     [1:0]                  i_taken,

        // Clear and stall signals. 
        input wire                              i_clear_from_writeback, // | Priority
        input wire                              i_data_stall,           // |
        input wire                              i_clear_from_alu,       // |
        input wire                              i_stall_from_shifter,   // |
        input wire                              i_stall_from_issue,     // V

        // Interrupt events.
        input   wire                            i_irq,
        input   wire                            i_fiq,
        input   wire                            i_abt,

        // Coprocessor module related.
        input   wire                            i_pipeline_dav, // Is 0 if all pipeline is INVALID.
        input   wire                            i_copro_done,

        // PC input.
        input wire  [31:0]                      i_pc_ff,
        input wire  [31:0]                      i_pc_plus_8_ff,

        // CPU mode. Taken from CPSR.
        input   wire    [31:0]                   i_cpu_mode,

        // Instruction input.
        input     wire  [31:0]                  i_instruction,    
        input     wire                          i_instruction_valid,

        // Instruction output      
        output reg [35:0]                       o_instruction_ff,
        output reg                              o_instruction_valid_ff,
     
        // Stall of PC and fetch.
        output  reg                             o_stall_from_decode,

        // PC output.
        output  reg  [31:0]                     o_pc_plus_8_ff,       
        output  reg  [31:0]                     o_pc_ff,

        // Interrupts.
        output  reg                             o_irq_ff,
        output  reg                             o_fiq_ff,
        output  reg                             o_abt_ff,
        output  reg                             o_und_ff,

        // Force 32-bit alignment on memory accesses.
        output reg                              o_force32align_ff,

        // Coprocessor interface.
        output wire                             o_copro_dav_ff,
        output wire  [31:0]                     o_copro_word_ff,

        // Branch.
        output reg   [1:0]                      o_taken_ff,

        // Clear from decode.
        output reg                              o_clear_from_decode,
        output reg [31:0]                       o_pc_from_decode,

        output wire o_unused_ok
);

`include "cc.vh"
`include "regs.vh"
`include "modes.vh"
`include "index_immed.vh"
`include "cpsr.vh"
`include "global_functions.vh"

wire                            o_comp_und_nxt;
wire    [3:0]                   o_condition_code_nxt;
wire                            o_irq_nxt;
wire                            o_fiq_nxt;
wire                            o_abt_nxt;
wire [35:0]                     o_instruction_nxt;
wire                            o_instruction_valid_nxt;

wire                            mem_fetch_stall;

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

reg [1:0] taken_nxt;

wire unused_ok_1, unused_ok_2;

// Unused.
assign o_unused_ok = unused_ok_1 | unused_ok_2;

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
                o_abt_ff                                <= o_abt_nxt;                    
                o_und_ff                                <= o_comp_und_nxt && i_instruction_valid;
                o_pc_plus_8_ff                          <= i_pc_plus_8_ff;
                o_pc_ff                                 <= i_pc_ff;
                o_force32align_ff                       <= o_force32align_nxt;
                o_taken_ff                              <= taken_nxt;
                o_instruction_ff                        <= o_instruction_nxt;
                o_instruction_valid_ff                  <= o_instruction_valid_nxt;
        end
end

task clear;
begin
                o_irq_ff                                <= 0;
                o_fiq_ff                                <= 0;
                o_abt_ff                                <= 0; 
                o_und_ff                                <= 0;
                o_taken_ff                              <= 0;
                o_instruction_valid_ff                  <= 0;
                o_instruction_ff[27]                    <= 0;
end
endtask

always @*
begin
        o_stall_from_decode = mem_fetch_stall || cp_stall;
end

// This unit handles coprocessor stuff.
zap_predecode_coproc 
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
        .o_copro_dav_ff(o_copro_dav_ff),
        .o_copro_word_ff(o_copro_word_ff),

        .o_unused_ok(unused_ok_1)
);

// Implements a custom 16-bit compressed instruction set.
zap_predecode_compress
u_zap_predecode_compress
(
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
        .o_und(o_comp_und_nxt)
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
        taken_nxt               = i_taken;
        addr                    = $signed(arm_instruction[23:0]);
        
        if ( arm_instruction[34] )      // Indicates a shift of 1.
                addr_final = addr << 1;
        else
                addr_final = addr << 2;

        if ( arm_instruction[27:25] == 3'b101 && arm_instruction_valid )
        begin
                if ( i_taken[1] || arm_instruction[31:28] == AL ) // Taken or Strongly Taken or Always taken.
                begin
                        // Take the branch.
                        o_clear_from_decode = 1'd1;

                        // Predict new PC.
                        o_pc_from_decode    = i_pc_plus_8_ff + addr_final;

                       if ( arm_instruction[31:28] == AL ) 
                                taken_nxt = ST;  
                end
                else // Not Taken or Weakly Not Taken.
                begin
                        // Else dont.
                        o_clear_from_decode = 1'd0;
                        o_pc_from_decode    = 32'd0;
                end
        end
end

// This FSM handles LDM/STM/SWAP/SWAPB/BL/LMULT
zap_predecode_mem_fsm u_zap_mem_fsm (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_instruction(arm_instruction),
        .i_instruction_valid(arm_instruction_valid),
        .i_fiq(arm_fiq),
        .i_irq(arm_irq),
        .i_cpsr(i_cpu_mode),

        .i_clear_from_writeback(i_clear_from_writeback),
        .i_data_stall(i_data_stall),          
        .i_clear_from_alu(i_clear_from_alu),      
        .i_issue_stall(i_stall_from_issue), 
        .i_stall_from_shifter(i_stall_from_shifter),

        .o_irq(o_irq_nxt),
        .o_fiq(o_fiq_nxt),
        .o_instruction(o_instruction_nxt),
        .o_instruction_valid(o_instruction_valid_nxt),
        .o_stall_from_decode(mem_fetch_stall),

        .o_unused_ok(unused_ok_2)
);

endmodule
