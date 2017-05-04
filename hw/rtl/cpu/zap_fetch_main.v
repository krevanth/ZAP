// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_fetch_main.v
// HDL          : Verilog-2001
// Module       : zap_fetch       
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// This is the simple I-cache frontend to the processor. This stage simply
// serves as a buffer for instructions. Data aborts are handled by pumping 
// an extra signal down the pipeline. Data aborts piggyback off AND R0, R0, R0. 
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high reset
// Clock        : Core clock
// Depends      : zap_ram_simple        
// ----------------------------------------------------------------------------

`default_nettype none

module zap_fetch_main #(
        // Branch predictor entries.
        parameter BP_ENTRIES = 1024
)
(
// Clock and reset.
input wire i_clk,          // ZAP clock.        
input wire i_reset,        // Active high synchronous reset.

// 
// From other parts of the pipeline. These
// signals either tell the unit to invalidate
// its outputs or freeze in place.
//
input wire i_code_stall,           // |      
input wire i_clear_from_writeback, // | High Priority.
input wire i_data_stall,           // |
input wire i_clear_from_alu,       // |
input wire i_stall_from_shifter,   // |
input wire i_stall_from_issue,     // |
input wire i_stall_from_decode,    // | Low Priority.
input wire i_clear_from_decode,    // V

// Comes from WB unit.
input wire [31:0] i_pc_ff,         // Program counter.

// Comes from CPSR
input wire        i_cpsr_ff_t,     // CPSR T bit.

// From I-cache.
input wire [31:0] i_instruction_nocache,   // A 32-bit ZAP instruction.
input wire [127:0]i_instruction_cache,     // A 32-bit ZAP instruction. From flop.
input wire        i_instr_src,             // 0 - Uncache 1 - Cache.

input wire        i_valid,         // Instruction valid indicator.
input wire        i_instr_abort,   // Instruction abort fault.

// To I-cache.
output wire       o_cache_rd_en,   // Cache read enable.

// To decode.
output reg [31:0]  o_instruction,  // The 32-bit instruction.
output reg         o_valid,        // Instruction valid.
output reg         o_instr_abort,  // Indication of an abort.       
output reg [31:0]  o_pc_plus_8_ff, // PC +8 ouput.
output reg [31:0]  o_pc_ff,        // PC output.

// For BP.
input wire         i_confirm_from_alu,  // Confirm branch prediction from ALU.
input wire [31:0]  i_pc_from_alu,       // Address of branch. 
input wire [1:0]   i_taken,             // Predicted status.
output wire [1:0]  o_taken_ff           // Prediction.

);

`include "zap_defines.vh"
`include "zap_localparams.vh"
`include "zap_functions.vh"

// Unused signals are assigned to this.
wire _unused_ok_;

// If an instruction abort occurs, this unit sleeps until it is woken up.
reg sleep_ff;

// Instruction buffer.
reg [31:0] instr_ff;
reg src_ff;

// Register read enable.
reg [1:0] rd_en ; // 0 -Uncache 1- Cache.

// Instruction MUX output.
wire [31:0] w_instr;

// ----------------------------------------------------------------------------

//
// This is the instruction payload on an abort
// because no instruction is actually available on
// an abort. This is AND R0, R0, R0 which is a NOP.
//
localparam ABORT_PAYLOAD = 32'd0;

// Branch states.
localparam  [1:0]    SNT     =       2'b00; // Strongly Not Taken.
localparam  [1:0]    WNT     =       2'b01; // Weakly Not Taken.
localparam  [1:0]    WT      =       2'b10; // Weakly Taken.
localparam  [1:0]    ST      =       2'b11; // Strongly Taken.

always @*
begin
        rd_en = 0;

        if      ( i_code_stall )                rd_en = 0;
        else if ( i_clear_from_writeback )      rd_en = 0;
        else if ( i_data_stall )                rd_en = 0;  
        else if ( i_clear_from_alu )            rd_en = 0;
        else if ( i_stall_from_shifter )        rd_en = 0;
        else if ( i_stall_from_issue )          rd_en = 0;
        else if ( i_stall_from_decode )         rd_en = 0;
        else if ( i_clear_from_decode )         rd_en = 0;
        else if ( sleep_ff )                    rd_en = 0;
        else if ( i_valid )
        begin
               // Turn on appropriate read enable.
               rd_en[0] = !i_instr_src;
               rd_en[1] = i_instr_src; 
        end
end

// Cache read enable.
assign o_cache_rd_en = rd_en[1];

always @ (posedge i_clk)
begin
        if ( rd_en[0] )
                instr_ff <= i_instruction_nocache;
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                src_ff <= 0;
        end
        else if ( rd_en[0] | rd_en[1] )
        begin
                src_ff <= i_instr_src;
        end
end

// Instruction wire.
assign w_instr = instr_ff; 
// src_ff ? adapt_cache_data(o_pc_ff[3:2], i_instruction_cache) : instr_ff;

//
// NOTE: If an instruction is invalid, only then can it be tagged with any
// kind of interrupt. Thus, the MMU must make instruction valid as 1 before
// attaching an abort interrupt to it even though the instruction generated
// might be invalid. Such an instruction is not actually executed.
//

//
// This stage simply forwards data from the
// I-cache downwards.
//
always @ (posedge i_clk)
begin
        if (  i_reset )                          
        begin
                // Unit has no valid output.
                o_valid         <= 1'd0;

                // Do not signal any abort.
                o_instr_abort   <= 1'd0;

                // Wake unit up.
                sleep_ff        <= 1'd0;
        end
//        else if ( i_code_stall )                 begin end  // Save state.
        else if ( i_clear_from_writeback )       clear_unit;
        else if ( i_data_stall)                  begin end // Save state.
        else if ( i_clear_from_alu )             clear_unit;
        else if ( i_stall_from_shifter )         begin end // Save state.
        else if ( i_stall_from_issue )           begin end // Save state.
        else if ( i_stall_from_decode)           begin end // Save state.
        else if ( i_clear_from_decode )          clear_unit;
        else if ( i_code_stall )                 begin end

        // If unit is sleeping.
        else if ( sleep_ff ) 
        begin
                // Nothing valid to be sent.
                o_valid         <= 1'd0;

                // No aborts.
                o_instr_abort   <= 1'd0;

                // Keep sleeping.
                sleep_ff        <= 1'd1;        
        end

        // Data from memory is valid. This could also be used to signal
        // an instruction access abort.
        else if ( i_valid )
        begin
                // Instruction aborts occur with i_valid as 1. See NOTE.
                o_valid         <= 1'd1;
                o_instr_abort   <= i_instr_abort;

                // Put unit to sleep on an abort.
                sleep_ff        <= i_instr_abort;

                //
                // Pump PC + 8 or 4 down the pipeline. The number depends on
                // ARM/Compressed mode.
                //
                o_pc_plus_8_ff <= i_cpsr_ff_t ? ( i_pc_ff + 32'd4 ) : 
                                                ( i_pc_ff + 32'd8 );

                // PC is pumped down the pipeline.
                o_pc_ff <= i_pc_ff;
        end
        else
        begin
                // Invalidate the output.
                o_valid        <= 1'd0;
        end
end

always @* o_instruction = w_instr;

// ----------------------------------------------------------------------------

//
// Branch State RAM.
// Holds the 2-bit state for a range of branches. Whenever a branch is
// either detected as correctly taken or incorrectly taken, this RAM is
// updated. Each entry in the RAM corresponds to a virtual memory address
// whether or not it be a legit branch or not. 
//
zap_ram_simple
#(.DEPTH(BP_ENTRIES), .WIDTH(2)) u_br_ram
(
        .i_clk(i_clk),

        // The reason that a no-stall condition is included is that
        // if the pipeline stalls, this memory should be trigerred multiply
        // times.
        .i_wr_en(       !i_data_stall             && 
                        !i_stall_from_issue       && 
                        !i_stall_from_decode      && 
                        !i_stall_from_shifter     && 
                        (i_clear_from_alu || i_confirm_from_alu)),

        // Lower bits of the PC index into the branch RAM for read and
        // write addresses.
        .i_wr_addr(i_pc_from_alu[$clog2(BP_ENTRIES):1]),
        .i_rd_addr(i_pc_ff[$clog2(BP_ENTRIES):1]),

        // Write the new state.
        .i_wr_data(compute(i_taken, i_clear_from_alu)),

        // Read when there is no stall.
        .i_rd_en( 
                        !i_code_stall             &&
                        !i_data_stall             && 
                        !i_stall_from_issue       && 
                        !i_stall_from_decode      && 
                        !i_stall_from_shifter      
        ),

        // Send the read data over to o_taken_ff which is a 2-bit value.
        .o_rd_data(o_taken_ff) 
);

// ----------------------------------------------------------------------------

//
// Branch Memory writes.
// Implements a 4-state predictor. 
//
function [1:0] compute ( input [1:0] i_taken, input i_clear_from_alu );
begin
                // Branch was predicted incorrectly. 
                if ( i_clear_from_alu )
                begin
                        case ( i_taken )
                        SNT: compute = WNT;
                        WNT: compute = WT;
                        WT:  compute = WNT;
                        ST:  compute = WT;
                        endcase
                end
                else // Confirm from alu that branch was correctly predicted.
                begin
                        case ( i_taken )
                        SNT: compute = SNT;
                        WNT: compute = SNT;
                        WT:  compute = ST;
                        ST:  compute = ST;
                        endcase
                end
end
endfunction

// ----------------------------------------------------------------------------

//
// This task clears out the unit and refreshes it for a new
// service session. Will wake the unit up and clear the outputs.
//
task clear_unit;
begin
                // No valid output.
                o_valid         <= 1'd0;

                // No aborts since we are clearing out the unit.
                o_instr_abort   <= 1'd0;

                // Wake up the unit.
                sleep_ff        <= 1'd0;
end
endtask

assign _unused_ok_ =   i_pc_from_alu[0] && 
                       i_pc_from_alu[31:$clog2(BP_ENTRIES) + 1];

endmodule // zap_fetch_main.v
