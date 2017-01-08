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
zap_fetch_stage.v

HDL --
Verilog-2005

Description --
This is the simple I-cache frontend to the processor. This stage simply
serves as a buffer for instructions. This allows maximum cycle time for
the I-cache. Data aborts are handled by pumping an extra signal down the
pipeline. Data aborts piggyback off AND R0, R0, R0. 
*/

module zap_fetch_main #(
        parameter BP_ENTRIES = 1024
)
(
                // Clock and reset.
                input wire i_clk,          // ZAP clock.        
                input wire i_reset,        // Active high synchronous reset.
                
                // From other parts of the pipeline. These
                // signals either tell the unit to invalidate
                // its outputs or freeze in place.
                input wire i_clear_from_writeback, // | High Priority.
                input wire i_data_stall,           // |
                input wire i_clear_from_alu,       // |
                input wire i_stall_from_shifter,   // |
                input wire i_stall_from_issue,     // |
                input wire i_stall_from_decode,    // V Low Priority.
                input wire i_clear_from_decode,    // V

                // Comes from Wb.
                input wire [31:0] i_pc_ff,               // Program counter.

                // Comes from CPSR
                input wire        i_cpsr_ff_t,           // CPSR T bit.

                // From I-cache.
                input wire [31:0] i_instruction,         // A 32-bit ZAP instruction + some bits.
                input wire        i_valid,               // Instruction valid indicator.
                input wire        i_instr_abort,         // Instruction abort fault.
                
                // To decode.
                output reg [31:0]  o_instruction,       // The 32-bit instruction.
                output reg         o_valid,             // Instruction valid.
                output reg         o_instr_abort,       // Indication of an abort.       
                output reg [31:0]  o_pc_plus_8_ff,      // PC +8 ouput.
                output reg [31:0]  o_pc_ff,             // PC output.

                // For BP.
                input wire         i_confirm_from_alu,
                input wire [31:0]  i_pc_from_alu,
                input wire [1:0]   i_taken,
                output wire [1:0]  o_taken_ff
);

wire _unused_ok_;

`include "cpsr.vh"

// If an instruction abort occurs, this unit sleeps until it is woken up.
reg sleep_ff;

// This is the instruction payload on an abort
// because no instruction is actually available on
// an abort.
localparam ABORT_PAYLOAD = 32'd0;

// This stage simply forwards data from the
// I-cache downwards.
always @ (posedge i_clk)
begin
        if (  i_reset )                          
        begin
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                sleep_ff        <= 1'd0;        // Wake unit up.
                o_pc_plus_8_ff  <= 32'd8;
                o_pc_ff         <= 32'd0;
        end
        else if ( i_clear_from_writeback )       
        begin   
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                sleep_ff        <= 1'd0;        // Wake unit up.
        end
        else if ( i_data_stall)                  begin end // Save state.
        else if ( i_clear_from_alu )             
        begin
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                sleep_ff        <= 1'd0;        // Wake unit up.
        end
        else if ( i_stall_from_shifter )         begin end // Save state.
        else if ( i_stall_from_issue )           begin end // Save state.
        else if ( i_stall_from_decode)           begin end // Save state.
        else if ( i_clear_from_decode )
        begin
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                sleep_ff        <= 1'd0;
        end
        else if ( sleep_ff )
        begin
                o_valid         <= 1'd0;
                o_instr_abort   <= 1'd0;
                sleep_ff        <= 1'd1;
        end
        else if ( i_valid )
        begin
                // Instruction aborts occur with i_valid as 1.
                o_valid         <= 1'd1;
                o_instr_abort   <= i_instr_abort;

                // Put unit to sleep on an abort.
                if ( i_instr_abort )
                begin
                        sleep_ff <= 1'd1;
                end

                // Pump PC + 8 or 4 down the pipeline. The number depends on
                // ARM/Compressed mode.
                o_pc_plus_8_ff <= i_cpsr_ff_t ? ( i_pc_ff + 32'd4 ) : ( i_pc_ff + 32'd8 );

                // PC.
                o_pc_ff <= i_pc_ff;
        end
        else
        begin
                o_valid        <= 1'd0;
        end
end


// iCache takes care of stall issues.
always @* 
        o_instruction = i_instruction;

// Branch states.
localparam      SNT     =       0; // Strongly Not Taken.
localparam      WNT     =       1; // Weakly Not Taken.
localparam      WT      =       2; // Weakly Taken.
localparam      ST      =       3; // Strongly Taken.

ram_simple
#(.DEPTH(BP_ENTRIES), .WIDTH(2)) u_br_ram
(
        .i_clk(i_clk),
        .i_wr_en(!i_data_stall && (i_clear_from_alu || i_confirm_from_alu)),
        .i_wr_addr(i_pc_from_alu[$clog2(BP_ENTRIES):1]),
        .i_rd_addr(i_pc_ff[$clog2(BP_ENTRIES):1]),
        .i_wr_data(compute(i_taken, i_clear_from_alu)),
        .i_rd_en(1'd1),
        .o_rd_data(o_taken_ff) 
);

// Memory writes.
function [1:0] compute ( input [1:0] i_taken, input i_clear_from_alu );
begin
                if ( i_clear_from_alu )
                begin
                        case ( i_taken )
                        SNT: compute = WNT;
                        WNT: compute = WT;
                        WT:  compute = WNT;
                        ST:  compute = WT;
                        endcase
                end
                else
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

assign _unused_ok_ =   i_pc_from_alu[0] && 
                       i_pc_from_alu[31:$clog2(BP_ENTRIES) + 1];

endmodule
