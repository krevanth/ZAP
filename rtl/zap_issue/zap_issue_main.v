`default_nettype none

/*
 Filename --
 zap_issue_stage.v

 HDL --
 Verilog-2005

 Description --
 This stage converts register indices into actual values. Register indices
 are also pumped forward to allow resolution in the shift stage. PC
 references must be resolved here since the value gives PC + 8. Instructions
 requiring shifts stall if the target registers are in the outputs of this
 stage. We do not issue a multiply if the source is still in the output of this 
 stage just like shifts.

 Copyright --
 (C) 2016 Revanth Kamaraj.
*/

module zap_issue_main
#(
        // Parameters.

        // Number of physical registers.
        parameter PHY_REGS = 46,

        // Although ARM mentions only 16 ALU operations, the processor
        // internally performs many more operations.
        parameter ALU_OPS   = 32,

        // Apart from the 4 specified by ARM, an undocumented RORI is present
        // to help deal with immediate rotates.
        parameter SHIFT_OPS = 5
)
(
        // Clock and reset.
        input  wire                             i_clk,    // ZAP clock.
        input  wire                             i_reset, // Active high sync.

        // Clear and stall signals.
        input wire                              i_clear_from_writeback,
        input wire                              i_data_stall,          
        input wire                              i_clear_from_alu,

        // From decode
        input       [31:0]                      i_pc_plus_8_ff,

        // Inputs from decode.
        // Look at decode_stage.v for the meaning of these ports...
         
        input wire      [3:0]                   i_condition_code_ff,
        
        input wire      [$clog2(PHY_REGS )-1:0] i_destination_index_ff,
        
        input wire      [32:0]                  i_alu_source_ff,
        input wire      [$clog2(ALU_OPS)-1:0]   i_alu_operation_ff,
        
        input wire      [32:0]                  i_shift_source_ff,
        input wire      [$clog2(SHIFT_OPS)-1:0] i_shift_operation_ff,
        input wire      [32:0]                  i_shift_length_ff,
        
        input wire                              i_flag_update_ff,
        
        input wire    [$clog2(PHY_REGS )-1:0]   i_mem_srcdest_index_ff,            
        input wire                              i_mem_load_ff,                     
        input wire                              i_mem_store_ff,                         
        input wire                              i_mem_pre_index_ff,                
        input wire                              i_mem_unsigned_byte_enable_ff,     
        input wire                              i_mem_signed_byte_enable_ff,       
        input wire                              i_mem_signed_halfword_enable_ff,        
        input wire                              i_mem_unsigned_halfword_enable_ff,      
        input wire                              i_mem_translate_ff,                     
                                                                                    
        input wire                              i_irq_ff,                               
        input wire                              i_fiq_ff,                               
        input wire                              i_abt_ff,                               
        input wire                              i_swi_ff,                               

        // From register file. Read ports.
        input wire  [31:0]                      i_rd_data_0,
        input wire  [31:0]                      i_rd_data_1,
        input wire  [31:0]                      i_rd_data_2,
        input wire  [31:0]                      i_rd_data_3,

        // FEEDBACK INPUTS...

        // Destination index feedback. Each stage is represented as
        // combinational logic followed by flops(FFs).
        input wire  [$clog2(PHY_REGS )-1:0]     i_shifter_destination_index_ff,  // The ALU never changes the destination anyway.
        input wire  [$clog2(PHY_REGS )-1:0]     i_alu_destination_index_ff,      // Flopped destination from the ALU.
        input wire  [$clog2(PHY_REGS )-1:0]     i_memory_destination_index_ff,   // Flopped destination in memory stage.

        // Data valid for each stage in the pipeline. Used to validate the
        // pipeline vector when sniffing for register values yet to be written.
        input wire                              i_alu_dav_nxt,                  // Taken from ALU_nxt instead of shifter_ff because ALU can change this.
        input wire                              i_alu_dav_ff,
        input wire                              i_memory_dav_ff,

        // The actual thing we need, the value of stuff we are sniffing for.
        input wire  [31:0]                      i_alu_destination_value_nxt,     // Taken from ALU_nxt since ALU can change this.
        input wire  [31:0]                      i_alu_destination_value_ff,      // ALU flopped result.
        input wire  [31:0]                      i_memory_destination_value_ff,   // Result in the memory area.

        // For load-store locks and memory acceleration, we need srcdest
        // index. Memory loads can be accelerated with a direct load from
        // memory stage instead of register stage(WB).
        input wire  [5:0]                       i_shifter_mem_srcdest_index_ff,
        input wire  [5:0]                       i_alu_mem_srcdest_index_ff,
        input wire  [5:0]                       i_memory_mem_srcdest_index_ff,
        input wire                              i_shifter_mem_load_ff,           // 1 if load.
        input wire                              i_alu_mem_load_ff,
        input wire                              i_memory_mem_load_ff,

        // Memory accelerator values for LOADS.
        input wire  [31:0]                      i_memory_mem_srcdest_value_ff,   // External memory data bus is connected to this.

        // Outputs to register file.
        output reg      [$clog2(PHY_REGS )-1:0] o_rd_index_0,
        output reg      [$clog2(PHY_REGS )-1:0] o_rd_index_1,
        output reg      [$clog2(PHY_REGS )-1:0] o_rd_index_2,
        output reg      [$clog2(PHY_REGS )-1:0] o_rd_index_3,

        // Outputs to SHIFT stage.

        output reg       [3:0]                   o_condition_code_ff,
        output reg       [$clog2(PHY_REGS )-1:0] o_destination_index_ff,
        output reg       [$clog2(ALU_OPS)-1:0]   o_alu_operation_ff,
        output reg       [$clog2(SHIFT_OPS)-1:0] o_shift_operation_ff,
        output reg                               o_flag_update_ff,
        
        output reg     [$clog2(PHY_REGS )-1:0]   o_mem_srcdest_index_ff,            
        output reg                               o_mem_load_ff,                     
        output reg                               o_mem_store_ff,
        output reg                               o_mem_pre_index_ff,                
        output reg                               o_mem_unsigned_byte_enable_ff,     
        output reg                               o_mem_signed_byte_enable_ff,       
        output reg                               o_mem_signed_halfword_enable_ff,
        output reg                               o_mem_unsigned_halfword_enable_ff,
        output reg                               o_mem_translate_ff,                
        
        output reg                               o_irq_ff,
        output reg                               o_fiq_ff,
        output reg                               o_abt_ff,
        output reg                               o_swi_ff,

        // Register values are obtained here.
        output reg      [31:0]                  o_alu_source_value_ff,
        output reg      [31:0]                  o_shift_source_value_ff,
        output reg      [31:0]                  o_shift_length_value_ff,
        output reg      [31:0]                  o_mem_srcdest_value_ff, 
                                                // For stores.

        // Indices/Immeds go here. It might seem odd that we are sending index
        // values and register values (above). The issue stage selects
        // the appropriate value.
        output reg      [32:0]                  o_alu_source_ff,
        output reg      [32:0]                  o_shift_source_ff,
        output reg      [32:0]                  o_shift_length_ff,

        // Stall everything before this.
        output reg                              o_stall_from_issue,

        // The PC value.
        output reg     [31:0]                   o_pc_plus_8_ff,

        // Shifter disable indicator. In the next stage, the output
        // will bypass the shifter. Not actually bypass it but will
        // go to the ALU value corrector unit via a MUX.
        output reg                              o_shifter_disable_ff
);

`include "cc.vh"
`include "index_immed.vh"
`include "regs.vh"
`include "shtype.vh"
`include "opcodes.vh"

// Individual lock signals. These are ORed to get the final lock.
reg shift_lock;
reg load_lock;

                        
reg lock;               // Asserted when an instruction cannot be issued and 
                        // leads to all stages before it stalling.

always @*
        lock = shift_lock | load_lock;

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
        o_shifter_disable_ff              <= 0;
        o_alu_source_ff                   <= 0;
        o_shift_source_ff                 <= 0;
        o_shift_length_ff                 <= 0;
        o_alu_source_value_ff             <= 0;
        o_shift_source_value_ff           <= 0;
        o_shift_length_value_ff           <= 0;
        o_mem_srcdest_value_ff            <= 0;
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
        o_shifter_disable_ff              <= 0;
        o_alu_source_ff                   <= 0;
        o_shift_source_ff                 <= 0;
        o_shift_length_ff                 <= 0;
        o_alu_source_value_ff             <= 0;
        o_shift_source_value_ff           <= 0;
        o_shift_length_value_ff           <= 0;
        o_mem_srcdest_value_ff            <= 0;
end
else if ( lock )
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
        o_shifter_disable_ff              <= 0;
        o_alu_source_ff                   <= 0;
        o_shift_source_ff                 <= 0;
        o_shift_length_ff                 <= 0;
        o_alu_source_value_ff             <= 0;
        o_shift_source_value_ff           <= 0;
        o_shift_length_value_ff           <= 0;
        o_mem_srcdest_value_ff            <= 0;
end
else
begin
        o_condition_code_ff               <= i_condition_code_ff;
        o_destination_index_ff            <= i_destination_index_ff;
        o_alu_operation_ff                <= i_alu_operation_ff;
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
        o_shifter_disable_ff              <= o_shifter_disable_nxt;
        o_alu_source_ff                   <= i_alu_source_ff;
        o_shift_source_ff                 <= i_shift_source_ff;
        o_shift_length_ff                 <= i_shift_length_ff;
        o_alu_source_value_ff             <= o_alu_source_value_nxt;
        o_shift_source_value_ff           <= o_shift_source_value_nxt;
        o_shift_length_value_ff           <= o_shift_length_value_nxt;
        o_mem_srcdest_value_ff            <= o_mem_srcdest_value_nxt;
end
end

reg o_shifter_disable_nxt;

reg [31:0] o_alu_source_value_nxt, 
           o_shift_source_value_nxt, 
           o_shift_length_value_nxt, 
           o_mem_srcdest_value_nxt;

// Get values from the feedback network.
always @*
begin
o_alu_source_value_nxt  = 
get_register_value ( i_alu_source_ff,       0,i_shifter_destination_index_ff, i_alu_dav_nxt, i_alu_destination_value_nxt, i_alu_destination_value_ff, 
                     i_alu_destination_index_ff, i_alu_dav_ff, i_memory_destination_index_ff, i_memory_dav_ff );

o_shift_source_value_nxt= 
get_register_value ( i_shift_source_ff,     1,i_shifter_destination_index_ff, i_alu_dav_nxt, i_alu_destination_value_nxt, i_alu_destination_value_ff,
                     i_alu_destination_index_ff, i_alu_dav_ff, i_memory_destination_index_ff, i_memory_dav_ff );

o_shift_length_value_nxt= 
get_register_value ( i_shift_length_ff,     2,i_shifter_destination_index_ff, i_alu_dav_nxt, i_alu_destination_value_nxt, i_alu_destination_value_ff,
                     i_alu_destination_index_ff, i_alu_dav_ff, i_memory_destination_index_ff, i_memory_dav_ff );

o_mem_srcdest_value_nxt = 
get_register_value ( i_mem_srcdest_index_ff,3,i_shifter_destination_index_ff, i_alu_dav_nxt, i_alu_destination_value_nxt, i_alu_destination_value_ff,
                     i_alu_destination_index_ff, i_alu_dav_ff, i_memory_destination_index_ff, i_memory_dav_ff ); 
//Naturally an index...
end

// Apply index to register file.
always @*
begin
        o_rd_index_0 = i_alu_source_ff;
        o_rd_index_1 = i_shift_source_ff; 
        o_rd_index_2 = i_shift_length_ff;
        o_rd_index_3 = i_mem_srcdest_index_ff;
end

// Straightforward read feedback function. Looks at all stages of the pipeline
// to sniff out the latest value of the register. Does not sniff the shifter
// stage since no useful information can be obtained from that. There is some 
// complexity here to perform accelerated memory reads. Immediates get read
// here.
function [31:0] get_register_value ( 
        input [32:0]                    index,                                  // Index to search for. This might be a constant too. 
        input [1:0]                     rd_port,                                // Register read port activated. This is like look-ahead.
        input [32:0]                    i_shifter_destination_index_ff,         // Destination on shifter flops.
        input                           i_alu_dav_nxt,                          // ALU output is valid.
        input [31:0]                    i_alu_destination_value_nxt,            // ALU immediate result.
        input [31:0]                    i_alu_destination_value_ff,             // ALU flopped result.
        input [$clog2(PHY_REGS)-1:0]    i_alu_destination_index_ff,             // ALU flopped destination index.
        input                           i_alu_dav_ff,                           // ALU result valid flopped.
        input [$clog2(PHY_REGS)-1:0]    i_memory_destination_index_ff,          // Memory stage destination index.
        input                           i_memory_dav_ff                         // Memory stage valid
);
reg [31:0] get;
begin
             if   ( index[32] )                 // Catch constant here.
                        get = index[31:0]; 
        else if   ( index == ARCH_PC )          // Catch PC here.
                        get = i_pc_plus_8_ff;
        else if   ( index == i_shifter_destination_index_ff && i_alu_dav_nxt  )                 
                        get =  i_alu_destination_value_nxt;         
        else if   ( index == i_alu_destination_index_ff && i_alu_dav_ff       )                 
                        get =  i_alu_destination_value_ff;
        else if   ( index == i_memory_destination_index_ff && i_memory_dav_ff )                 
                        get =  i_memory_destination_value_ff;
        else                          
        begin                                                          
                case ( rd_port )
                        0: get = i_rd_data_0;
                        1: get = i_rd_data_1;
                        2: get = i_rd_data_2;
                        3: get = i_rd_data_3;
                endcase
        end

        // The memory accelerator.
        if ( index == i_mem_srcdest_index_ff && i_memory_mem_load_ff && i_memory_dav_ff )
        begin
                get = i_memory_mem_srcdest_value_ff;
        end

        get_register_value = get;
end
endfunction 

// Stall all previous stages if a lock occurs.
always @*
begin
        o_stall_from_issue = lock;
end

always @*
begin
        // Look for reads from registers to be loaded from memory. Three
        // register sources may cause a load lock.
        load_lock =     determine_load_lock 
                        ( i_alu_source_ff  , o_mem_srcdest_index_ff, o_condition_code_ff, 
                         o_mem_load_ff, i_shifter_mem_srcdest_index_ff, i_alu_dav_nxt, 
                        i_shifter_mem_load_ff, i_alu_mem_srcdest_index_ff, i_alu_dav_ff, 
                        i_alu_mem_load_ff ) 
                        || 
                        determine_load_lock 
                        ( i_shift_source_ff, o_mem_srcdest_index_ff, 
                        o_condition_code_ff, o_mem_load_ff, i_shifter_mem_srcdest_index_ff, 
                        i_alu_dav_nxt, i_shifter_mem_load_ff, i_alu_mem_srcdest_index_ff, 
                        i_alu_dav_ff, i_alu_mem_load_ff ) 
                        ||
                        determine_load_lock 
                        ( i_shift_length_ff, o_mem_srcdest_index_ff, 
                        o_condition_code_ff, o_mem_load_ff, i_shifter_mem_srcdest_index_ff, 
                        i_alu_dav_nxt, i_shifter_mem_load_ff, i_alu_mem_srcdest_index_ff, 
                        i_alu_dav_ff, i_alu_mem_load_ff );

        // A shift lock occurs if the current instruction requires a shift
        // other than LSL #0 or RORI if the operands are right on the output of this
        // stage.
        shift_lock =    !(
                                i_shift_operation_ff    == LSL && 
                                i_shift_length_ff[31:0] == 32'd0 && 
                                i_shift_length_ff[32]   == IMMED_EN
                        )
                        && // If it is not LSL #0 AND...
                        !(
                                i_shift_operation_ff == RORI // The amount to rotate and rotate are self contained.
                        )
                        && // If it is not RORI AND...
                        (
                                shifter_lock_check ( i_shift_source_ff, o_destination_index_ff, o_condition_code_ff ) ||
                                shifter_lock_check ( i_shift_length_ff, o_destination_index_ff, o_condition_code_ff ) ||
                                shifter_lock_check ( i_alu_source_ff  , o_destination_index_ff, o_condition_code_ff )   
                        ); 

        // Shifter disable.
        o_shifter_disable_nxt = (       
                                        i_shift_operation_ff    == LSL && 
                                        i_shift_length_ff[31:0] == 32'd0 && 
                                        i_shift_length_ff[32]   == IMMED_EN
                                ); 
        // If it is LSL #0, we can disable the shifter.
end

// Shifter lock check.
function shifter_lock_check ( 
        input [32:0] index, 
        input [$clog2(PHY_REGS)-1:0] o_destination_index_ff,
        input [3:0] o_condition_code_ff
);
begin
        // Simply check if the operand index is on the output of this unit
        // and that the output is valid.
        if ( o_destination_index_ff == index && o_condition_code_ff != NV )
                shifter_lock_check = 1'd1;
        else
                shifter_lock_check = 1'd0;

        // If immediate, no lock obviously.
        if ( index[32] == IMMED_EN )
                shifter_lock_check = 1'd0;
end        
endfunction

function determine_load_lock ( 
input [32:0]                    index,
input [$clog2(PHY_REGS)-1:0]    o_mem_srcdest_index_ff,
input [3:0]                     o_condition_code_ff,
input                           o_mem_load_ff,
input  [$clog2(PHY_REGS)-1:0]   i_shifter_mem_srcdest_index_ff,
input                           i_alu_dav_nxt,
input                           i_shifter_mem_load_ff,
input  [$clog2(PHY_REGS)-1:0]   i_alu_mem_srcdest_index_ff,
input                           i_alu_dav_ff,
input                           i_alu_mem_load_ff
);
begin
        determine_load_lock = 1'd0;

        // Look for that index <- mem instruction in the required pipeline stages. 
        // If found, we cannot issue the current instruction since old value 
        // will be read.
        if ( 
                ( index == o_mem_srcdest_index_ff          && 
                  o_condition_code_ff != NV                && 
                  o_mem_load_ff )                          ||
                ( index == i_shifter_mem_srcdest_index_ff  && 
                   i_alu_dav_nxt                           &&
                   i_shifter_mem_load_ff )                 ||
                (  index == i_alu_mem_srcdest_index_ff     && 
                   i_alu_dav_ff                            && 
                   i_alu_mem_load_ff )       
        )
                determine_load_lock = 1'd1;

        // Locks occur only for indices...
        if ( index[32] == IMMED_EN )
                determine_load_lock = 1'd0;
end
endfunction

endmodule
