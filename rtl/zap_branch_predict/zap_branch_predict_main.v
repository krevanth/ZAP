/*
 * A simple branch predictor to make up for the longer 
 * pipeline. Can store 512 branches and uses a 2-state
 * predictor algorithm. 
 *
 * Author:
 * Revanth Kamaraj.
 *
 * License:
 * MIT License.
 */

`default_nettype none

module zap_branch_predict_main
#(
        parameter BP_ENTRIES = 512
)
(
        // Clock and reset.
        input wire              i_clk,
        input wire              i_reset,         

        // Clear from writeback and ALU. Also data stall.
        input wire              i_clear_from_writeback,
        input wire              i_data_stall,
        input wire              i_clear_from_alu,
        input wire   [31:0]     i_pc,                   // PC from fetch. Not added 8!.
        input wire              i_confirm_from_alu,
        input wire   [31:0]     i_pc_from_alu,          // PC sent from ALU on both clear and confirm. For confirm, ALU subtracts 8 internally before giving this.

        input wire              i_stall_from_issue,
        input wire              i_stall_from_shifter,
        input wire              i_stall_from_decode,
        input wire              i_clear_from_decode,

        // From fetch unit along with IABORT.
        input wire   [31:0]     i_inst,
        input wire              i_val,
        input wire              i_abt,
        input wire   [31:0]     i_pc_plus_8,

        // Standard outputs.
        output reg   [31:0]     o_inst_ff,
        output reg              o_val_ff,   
        output reg              o_abt_ff,
        output reg [31:0]       o_pc_plus_8_ff,
        output reg [31:0]       o_pc_ff,

        // Branch state.
        input  wire [1:0]       i_taken,
        output wire [1:0]       o_taken_ff
);

// For Thumb bit position.
`include "cpsr.vh"

// Branch states.
localparam      SNT     =       0; // Strongly Not Taken.
localparam      WNT     =       1; // Weakly Not Taken.
localparam      WT      =       2; // Weakly Taken.
localparam      ST      =       3; // Strongly Taken.

// Mundane outputs.
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
                // Preserve values.
        end
        else if ( i_clear_from_alu )
        begin
                clear;
        end
        else if ( i_stall_from_shifter )
        begin
                // Preser val.
        end
        else if ( i_stall_from_issue )
        begin
                // Preserve values.
        end
        else if ( i_stall_from_decode )
        begin
                // Preserve values.
        end
        else if ( i_clear_from_decode )
        begin
                clear;
        end
        else
        begin
                // Normal update.
                o_inst_ff       <= i_inst;
                o_val_ff        <= i_val;
                o_abt_ff        <= i_abt;
                o_pc_plus_8_ff  <= i_pc_plus_8; 
                o_pc_ff         <= i_pc;
        end
end

task clear;
begin
        // Basically invalidate everything.
        o_inst_ff       <= 32'd0;
        o_val_ff        <= 1'd0;
        o_abt_ff        <= 1'd0;
        o_pc_plus_8_ff  <= 32'd8;
        o_pc_ff         <= 32'd0;
end
endtask

`define x i_pc_from_alu[$clog2(BP_ENTRIES):1]
`define y i_pc[$clog2(BP_ENTRIES):1]

zap_branch_predict_ram
#(.NUMBER_OF_ENTRIES(BP_ENTRIES), .ENTRY_SIZE(2)) u_br_ram
(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_wr_en(!i_data_stall && (i_clear_from_alu || i_confirm_from_alu)),
        .i_wr_addr(`x),
        .i_rd_addr(`y),
        .i_wr_data(compute(i_taken, i_clear_from_alu)),
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

`undef x
`undef y

endmodule
