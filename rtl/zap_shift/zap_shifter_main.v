`default_nettype none

// Filename --
// zap_shift_stage.v 
//
// Author --
// Revanth Kamaraj
//
// Description --
// This stage contains the barrel shifter and the conflict resolver system.

module zap_shifter_main
#(
        parameter PHY_REGS  = 46,
        parameter ALU_OPS   = 32,
        parameter SHIFT_OPS = 5
)
(
        // =============================
        // Clock and reset.
        // =============================
        input wire                               i_clk,
        input wire                               i_reset,

        // ==============================
        // Stall and clear.
        // ==============================
        input wire i_clear_from_writeback, // | High Priority.
        input wire i_data_stall,           // |
        input wire i_clear_from_alu,       // V Low Priority.

        // ==============================
        // Things from Issue.
        // ==============================

        input wire       [3:0]                   i_condition_code_ff,
        input wire       [$clog2(PHY_REGS )-1:0] i_destination_index_ff,
        input wire       [$clog2(ALU_OPS)-1:0]   i_alu_operation_ff,
        input wire       [$clog2(SHIFT_OPS)-1:0] i_shift_operation_ff,
        input wire                               i_flag_update_ff,
        
        input wire     [$clog2(PHY_REGS )-1:0]   i_mem_srcdest_index_ff,            
        input wire                               i_mem_load_ff,                     
        input wire                               i_mem_store_ff,
        input wire                               i_mem_pre_index_ff,                
        input wire                               i_mem_unsigned_byte_enable_ff,     
        input wire                               i_mem_signed_byte_enable_ff,       
        input wire                               i_mem_signed_halfword_enable_ff,
        input wire                               i_mem_unsigned_halfword_enable_ff,
        input wire                               i_mem_translate_ff,                
        
        input wire                               i_irq_ff,
        input wire                               i_fiq_ff,
        input wire                               i_abt_ff,
        input wire                               i_swi_ff,

        // Indices/immediates enter here.
        input wire      [32:0]                  i_alu_source_ff,
        input wire      [32:0]                  i_shift_source_ff,
        input wire      [32:0]                  i_shift_length_ff,

        // Values are obtained here.
        input wire      [31:0]                  i_alu_source_value_ff,
        input wire      [31:0]                  i_shift_source_value_ff,
        input wire      [31:0]                  i_shift_length_value_ff,
        input wire      [31:0]                  i_mem_srcdest_value_ff, // This too has to be resolved. 
                                                // For stores.

        // The PC value.
        input wire     [31:0]                   i_pc_plus_8_ff,

        // Shifter disable indicator. In the next stage, the output
        // will bypass the shifter. Not actually bypass it but will
        // go to the ALU value corrector unit via a MUX.
        input wire                              i_disable_shifter_ff,

        // ===============================
        // Value from ALU for resolver.
        // ===============================
        input wire   [31:0]                     i_alu_value_nxt,

        // AT indicator.
        input wire      i_switch_ff,
        output reg      o_switch_ff,

        // ===============================
        // Outputs.
        // ===============================

        // Specific to this stage.
        output reg      [31:0]                  o_mem_srcdest_value_ff,
        output reg      [31:0]                  o_alu_source_value_ff,
        output reg      [31:0]                  o_shifted_source_value_ff,
        output reg                              o_shift_carry_ff,
        output reg                              o_rrx_ff,

        // Send all other outputs.

        // PC+8
        output reg      [31:0]                  o_pc_plus_8_ff,

        // Interrupts.
        output reg                              o_irq_ff, 
        output reg                              o_fiq_ff, 
        output reg                              o_abt_ff, 
        output reg                              o_swi_ff,

        // Memory related outputs.
        output reg [$clog2(PHY_REGS )-1:0]      o_mem_srcdest_index_ff,            
        output reg                              o_mem_load_ff,                     
        output reg                              o_mem_store_ff,
        output reg                              o_mem_pre_index_ff,                
        output reg                              o_mem_unsigned_byte_enable_ff,     
        output reg                              o_mem_signed_byte_enable_ff,       
        output reg                              o_mem_signed_halfword_enable_ff,
        output reg                              o_mem_unsigned_halfword_enable_ff,
        output reg                              o_mem_translate_ff,                

        // Other stuff.
        output reg       [3:0]                   o_condition_code_ff,
        output reg       [$clog2(PHY_REGS )-1:0] o_destination_index_ff,
        output reg       [$clog2(ALU_OPS)-1:0]   o_alu_operation_ff,
        output reg       [$clog2(SHIFT_OPS)-1:0] o_shift_operation_ff,
        output reg                               o_flag_update_ff,

        // Stall from shifter.
        output wire                             o_stall_from_shifter
);

`include "opcodes.vh"
`include "index_immed.vh"
`include "cc.vh"

wire [31:0] shout;
wire shcarry;
wire        rrx;
reg [31:0] mem_srcdest_value;
reg [31:0] rm, rn;

wire [31:0] mult_out;

zap_multiply u_zap_multiply
(
        .i_clk(i_clk),
        .i_reset(i_reset),

        .i_clear(i_clear_from_writeback || i_clear_from_alu),
        .i_start( i_alu_operation_ff == MLA ),

        .i_rm(i_alu_source_value_ff),
        .i_rn(i_shift_length_value_ff),
        .i_rs(i_shift_source_value_ff), // rm.rs + rn

        .o_rd(mult_out),
        .o_busy(o_stall_from_shifter)
);

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
           o_condition_code_ff               <= NV;
           o_destination_index_ff            <= 0; 
           o_alu_operation_ff                <= 0; 
           o_shift_operation_ff              <= 0; 
           o_flag_update_ff                  <= 0; 
           o_mem_srcdest_index_ff            <= 0; 
           o_mem_load_ff                     <= 0; 
           o_mem_store_ff                    <= 0; 
           o_mem_pre_index_ff                <= 0; 
           o_mem_unsigned_byte_enable_ff     <= 0; 
           o_mem_signed_byte_enable_ff       <= 0; 
           o_mem_signed_halfword_enable_ff   <= 0; 
           o_mem_unsigned_halfword_enable_ff <= 0; 
           o_mem_translate_ff                <= 0; 
           o_irq_ff                          <= 0; 
           o_fiq_ff                          <= 0; 
           o_abt_ff                          <= 0;                
           o_swi_ff                          <= 0; 
           o_pc_plus_8_ff                    <= 0; 
           o_mem_srcdest_value_ff            <= 0; 
           o_alu_source_value_ff             <= 0; 
           o_shifted_source_value_ff         <= 0; 
           o_shift_carry_ff                  <= 0; 
           o_rrx_ff                          <= 0;
           o_switch_ff                       <= 0; 
        end
        else if ( i_clear_from_writeback )
        begin
           o_condition_code_ff               <= NV;
           o_destination_index_ff            <= 0; 
           o_alu_operation_ff                <= 0; 
           o_shift_operation_ff              <= 0; 
           o_flag_update_ff                  <= 0; 
           o_mem_srcdest_index_ff            <= 0; 
           o_mem_load_ff                     <= 0; 
           o_mem_store_ff                    <= 0; 
           o_mem_pre_index_ff                <= 0; 
           o_mem_unsigned_byte_enable_ff     <= 0; 
           o_mem_signed_byte_enable_ff       <= 0; 
           o_mem_signed_halfword_enable_ff   <= 0; 
           o_mem_unsigned_halfword_enable_ff <= 0; 
           o_mem_translate_ff                <= 0; 
           o_irq_ff                          <= 0; 
           o_fiq_ff                          <= 0; 
           o_abt_ff                          <= 0;                
           o_swi_ff                          <= 0; 
           o_pc_plus_8_ff                    <= 0; 
           o_mem_srcdest_value_ff            <= 0; 
           o_alu_source_value_ff             <= 0; 
           o_shifted_source_value_ff         <= 0; 
           o_shift_carry_ff                  <= 0; 
           o_rrx_ff                          <= 0;
           o_switch_ff                       <= 0;
        end
        else if ( i_data_stall )
        begin
                // Preserve values.
        end
        else if ( i_clear_from_alu )
        begin
           o_condition_code_ff               <= NV;
           o_destination_index_ff            <= 0; 
           o_alu_operation_ff                <= 0; 
           o_shift_operation_ff              <= 0; 
           o_flag_update_ff                  <= 0; 
           o_mem_srcdest_index_ff            <= 0; 
           o_mem_load_ff                     <= 0; 
           o_mem_store_ff                    <= 0; 
           o_mem_pre_index_ff                <= 0; 
           o_mem_unsigned_byte_enable_ff     <= 0; 
           o_mem_signed_byte_enable_ff       <= 0; 
           o_mem_signed_halfword_enable_ff   <= 0; 
           o_mem_unsigned_halfword_enable_ff <= 0; 
           o_mem_translate_ff                <= 0; 
           o_irq_ff                          <= 0; 
           o_fiq_ff                          <= 0; 
           o_abt_ff                          <= 0;                
           o_swi_ff                          <= 0; 
           o_pc_plus_8_ff                    <= 0; 
           o_mem_srcdest_value_ff            <= 0; 
           o_alu_source_value_ff             <= 0; 
           o_shifted_source_value_ff         <= 0; 
           o_shift_carry_ff                  <= 0; 
           o_rrx_ff                          <= 0; 
           o_switch_ff                       <= 0;
        end
        else
        begin
           o_condition_code_ff               <= i_condition_code_ff;                                     
           o_destination_index_ff            <= i_destination_index_ff;
           o_alu_operation_ff                <= (i_alu_operation_ff == MLA) ? MOV : i_alu_operation_ff; // Multiplication needs transformation.
           o_shift_operation_ff              <= i_shift_operation_ff;
           o_flag_update_ff                  <= i_flag_update_ff;
           o_mem_srcdest_index_ff            <= i_mem_srcdest_index_ff;           
           o_mem_load_ff                     <= i_mem_load_ff;                    
           o_mem_store_ff                    <= i_mem_store_ff;                   
           o_mem_pre_index_ff                <= i_mem_pre_index_ff;               
           o_mem_unsigned_byte_enable_ff     <= i_mem_unsigned_byte_enable_ff;    
           o_mem_signed_byte_enable_ff       <= i_mem_signed_byte_enable_ff;      
           o_mem_signed_halfword_enable_ff   <= i_mem_signed_halfword_enable_ff;  
           o_mem_unsigned_halfword_enable_ff <= i_mem_unsigned_halfword_enable_ff;
           o_mem_translate_ff                <= i_mem_translate_ff;               
           o_irq_ff                          <= i_irq_ff;                         
           o_fiq_ff                          <= i_fiq_ff;                         
           o_abt_ff                          <= i_abt_ff;                         
           o_swi_ff                          <= i_swi_ff;   
           o_pc_plus_8_ff                    <= i_pc_plus_8_ff;
           o_mem_srcdest_value_ff            <= mem_srcdest_value;
           o_alu_source_value_ff             <= rn;
           o_shifted_source_value_ff         <= rm;
           o_shift_carry_ff                  <= shcarry;
           o_rrx_ff                          <= rrx; 
           o_switch_ff                       <= i_switch_ff;
   end
end

// A 32x32+32=32 MAC unit.
zap_shift_shifter U_SHIFT
(
        .i_source       ( i_shift_source_value_ff ),
        .i_amount       ( i_shift_length_value_ff[7:0] ),
        .i_shift_type   ( i_shift_operation_ff ),
        .o_result       ( shout ),
        .o_carry        ( shcarry ),
        .o_rrx          ( rrx )
);

// For ALU source value (rn)
always @*
begin
                rn = resolve_conflict ( i_alu_source_ff, i_alu_source_value_ff, 
                                        o_destination_index_ff, i_alu_value_nxt ); 
end

// For shifter source value.
always @*
begin
        // If we issue an MLA.
        if ( i_alu_operation_ff == MLA )
        begin
                // Get result from multiplier.
                rm = mult_out;
        end        
        else if( !i_disable_shifter_ff )
        begin
                rm = shout;
        end
        else
        begin
                rm = resolve_conflict ( i_shift_source_ff, i_shift_source_value_ff,
                                        o_destination_index_ff, i_alu_value_nxt );
        end
end

// Mem srcdest index. Used for
// stores.
always @*
begin
        mem_srcdest_value = resolve_conflict ( i_mem_srcdest_index_ff, i_mem_srcdest_value_ff,
                                               o_destination_index_ff, i_alu_value_nxt );  
end


// This will resolve conflicts for back to back instruction execution.
// The function entirely depends only on the inputs.
function [31:0] resolve_conflict ( 
        input    [32:0]                  index_from_issue,       // Index from issue stage. Could have immed too.
        input    [31:0]                  value_from_issue,       // Issue speculatively read value.
        input    [$clog2(PHY_REGS)-1:0]  index_from_this_stage,  // From shift (This) stage output flops.
        input    [31:0]                  result_from_alu         // From ALU output directly.
);
begin
        if ( index_from_issue[32] == IMMED_EN )
        begin
                resolve_conflict = index_from_issue[31:0];
        end 
        else if ( index_from_this_stage == index_from_issue[$clog2(PHY_REGS)-1:0] )
        begin
                resolve_conflict = result_from_alu;
        end
        else
        begin
                resolve_conflict = value_from_issue[31:0];
        end
end
endfunction

endmodule
