///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (c) 2016, 2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 

///////////////////////////////////////////////////////////////////////////////

// 
// Filename --
// zap_alu_main.v
// 
// Summary --
// ZAP 32-bit ALU unit.
//
// Description --
// This unit performs arithmetic operations. It also generates memory signals 
// at the end of the clock cycle. 
// 

///////////////////////////////////////////////////////////////////////////////

`default_nettype none
`include "config.vh"

///////////////////////////////////////////////////////////////////////////////

module zap_alu_main #(
        parameter [31:0] PHY_REGS  = 32'd46,
        parameter [31:0] SHIFT_OPS = 32'd5,
        parameter [31:0] ALU_OPS   = 32'd32,
        parameter [31:0] FLAG_WDT  = 32'd32
)

///////////////////////////////////////////////////////////////////////////////

(
        // ALU Hijack Interface. Used by the writeback stage.
        input wire                         i_hijack,
        input wire      [31:0]             i_hijack_op1,
        input wire      [31:0]             i_hijack_op2,
        input wire                         i_hijack_cin,
        output wire     [31:0]             o_hijack_sum,

        // Clock and reset.
        input wire                         i_clk,   // clock.
        input wire                         i_reset, // sync active high reset.

        // From CPSR. ( I, F, T, Mode ) - From WB unit.
        input wire  [31:0]                 i_cpsr_nxt,

        // Clear and Stall signals. High to low priority.
        input wire                         i_clear_from_writeback, 
        input wire                         i_data_stall,           

        //
        // Inputs from shift stage (previous).
        //

        // State switch ( ARM <-> Compressed mode switch may be done ).
        input wire                         i_switch_ff,

        // Taken branch predicted status.
        input wire   [1:0]                 i_taken_ff,

        // PC
        input wire   [31:0]                i_pc_ff,

        // Do not zero flag for logical instructions.
        input wire                         i_nozero_ff,
         
        // Value to store.
        input wire  [31:0]                 i_mem_srcdest_value_ff, 

        // ALU source operand.
        input wire  [31:0]                 i_alu_source_value_ff,  

        // Shifted source operand.
        input wire  [31:0]                 i_shifted_source_value_ff, 

        // Carry from shifter.
        input wire                         i_shift_carry_ff,          

        // PC plus 8 value.
        input wire  [31:0]                 i_pc_plus_8_ff,

        // Interrupt status.
        input wire                         i_abt_ff, 
                                           i_irq_ff, 
                                           i_fiq_ff, 
                                           i_swi_ff,

        input wire  [$clog2(PHY_REGS)-1:0] i_mem_srcdest_index_ff,     
        input wire                         i_mem_load_ff,                     
        input wire                         i_mem_store_ff,                         
        input wire                         i_mem_pre_index_ff,                
        input wire                         i_mem_unsigned_byte_enable_ff,     
        input wire                         i_mem_signed_byte_enable_ff,       
        input wire                         i_mem_signed_halfword_enable_ff,        
        input wire                         i_mem_unsigned_halfword_enable_ff,      
        input wire                         i_mem_translate_ff,  
        input wire  [3:0]                  i_condition_code_ff,
        input wire  [$clog2(PHY_REGS)-1:0] i_destination_index_ff,
        input wire  [$clog2(ALU_OPS)-1:0]  i_alu_operation_ff,      
        input wire                         i_flag_update_ff,

        // Force 32.
        input wire                         i_force32align_ff,

        // undefined instr.
        input wire                         i_und_ff,
        output reg                         o_und_ff,

        // data abort.
        input wire                         i_data_mem_fault,

        //
        // Outputs
        //

        output reg [31:0]                   o_alu_result_nxt,
        output reg [31:0]                   o_alu_result_ff,

        // Interrupt outputs.
        output reg                          o_abt_ff, 
        output reg                          o_irq_ff, 
        output reg                          o_fiq_ff, 
        output reg                          o_swi_ff,

        // Memory stuff.
        output reg                          o_dav_ff,
        output reg                          o_dav_nxt,
        output reg [31:0]                   o_pc_plus_8_ff,
        output reg [31:0]                   o_mem_address_ff,       
        output reg                          o_clear_from_alu,
        output reg [31:0]                   o_pc_from_alu,
        output reg [$clog2(PHY_REGS)-1:0]   o_destination_index_ff,

        output reg [FLAG_WDT-1:0]           o_flags_ff,  // Output flags (CPSR).
        output reg [FLAG_WDT-1:0]           o_flags_nxt, 

        output reg                          o_confirm_from_alu,

        output reg  [$clog2(PHY_REGS)-1:0]  o_mem_srcdest_index_ff,     
        output reg                          o_mem_load_ff,                     
        output reg                          o_mem_store_ff,                         
        output reg                          o_mem_unsigned_byte_enable_ff,     
        output reg                          o_mem_signed_byte_enable_ff,       
        output reg                          o_mem_signed_halfword_enable_ff,        
        output reg                          o_mem_unsigned_halfword_enable_ff,      
        output reg [31:0]                   o_mem_srcdest_value_ff,
        output reg                          o_mem_translate_ff,

        // Byte enables useful for writes. 
        output reg [3:0]                    o_ben_ff,
        output wire [31:0]                  o_address_nxt
);

///////////////////////////////////////////////////////////////////////////////

`include "cc.vh"
`include "regs.vh"
`include "opcodes.vh"
`include "cpsr.vh"
`include "modes.vh"
`include "global_functions.vh"

///////////////////////////////////////////////////////////////////////////////

// These override global N,Z,C,V definitions which are on CPSR.
localparam [1:0] _N  = 2'd3;
localparam [1:0] _Z  = 2'd2;
localparam [1:0] _C  = 2'd1;
localparam [1:0] _V  = 2'd0;

// Branch status.
localparam [1:0] SNT = 2'd0;
localparam [1:0] WNT = 2'd1;
localparam [1:0] WT  = 2'd2;
localparam [1:0] ST  = 2'd3;

///////////////////////////////////////////////////////////////////////////////

reg                             sleep_ff, sleep_nxt;
reg [31:0]                      flags_ff, flags_nxt;
reg [31:0]                      rm, rn; // RM = shifted source value Rn for
                                        // non shifted source value. These are
                                        // values and not indices.
reg [31:0]                      mem_address_nxt;
reg [$clog2(PHY_REGS)-1:0]      o_destination_index_nxt;
wire [31:0]                     not_rm, not_rn;

// Wires to connect to the adder instance.
reg [31:0]      op1, op2;
reg             cin;
wire [32:0]     sum;

///////////////////////////////////////////////////////////////////////////////

assign o_address_nxt = mem_address_nxt;
assign not_rm = ~rm;
assign not_rn = ~rn;

///////////////////////////////////////////////////////////////////////////////

always @*
begin
        rm          = i_shifted_source_value_ff;
        rn          = i_alu_source_value_ff;
        o_flags_ff  = flags_ff;
        o_flags_nxt = flags_nxt;
end

///////////////////////////////////////////////////////////////////////////////

task clear ( input [31:0] flags );
begin
                o_dav_ff                         <= 0;
                o_destination_index_ff[4]        <= 1;
                flags_ff                         <= flags;
                o_abt_ff                         <= 0;
                o_irq_ff                         <= 0;
                o_fiq_ff                         <= 0;
                o_swi_ff                         <= 0;
                o_und_ff                         <= 0;
                sleep_ff                         <= 0;
                o_mem_load_ff                    <= 0;
                o_mem_store_ff                   <= 0;
end
endtask

///////////////////////////////////////////////////////////////////////////////

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                // On reset, processor enters supervisory mode with interrupts
                // masked.
                clear ( {1'd1,1'd1,1'd0,SVC} );
        end
        else if ( i_clear_from_writeback ) 
        begin
                // Clear but take CPSR from writeback.
                clear ( i_cpsr_nxt );
        end
        else if ( i_data_stall )
        begin
                // Preserve values.
        end
        else if ( i_data_mem_fault || sleep_ff )
        begin
               clear(flags_ff);
               sleep_ff                         <= 1'd1; 
        end
        else
        begin
                o_alu_result_ff                  <= o_alu_result_nxt;
                o_dav_ff                         <= o_dav_nxt;                
                o_pc_plus_8_ff                   <= i_pc_plus_8_ff;
                o_mem_address_ff                 <= mem_address_nxt;
                o_destination_index_ff           <= o_destination_index_nxt;
                flags_ff                         <= flags_nxt;
                o_abt_ff                         <= i_abt_ff;
                o_irq_ff                         <= i_irq_ff;
                o_fiq_ff                         <= i_fiq_ff;
                o_swi_ff                         <= i_swi_ff;
                o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;
                o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;           
                o_mem_load_ff                    <= o_dav_nxt ? i_mem_load_ff : 1'd0;                    
                o_mem_store_ff                   <= o_dav_nxt ? i_mem_store_ff: 1'd0;                   
                o_mem_unsigned_byte_enable_ff    <= i_mem_unsigned_byte_enable_ff;    
                o_mem_signed_byte_enable_ff      <= i_mem_signed_byte_enable_ff;      
                o_mem_signed_halfword_enable_ff  <= i_mem_signed_halfword_enable_ff;  
                o_mem_unsigned_halfword_enable_ff<= i_mem_unsigned_halfword_enable_ff;
                o_mem_translate_ff               <= i_mem_translate_ff;  

                o_mem_srcdest_value_ff           <= duplicate (
                                                 i_mem_unsigned_byte_enable_ff, 
                                                 i_mem_signed_byte_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 i_mem_srcdest_value_ff ); 

                sleep_ff                         <= sleep_nxt;
                o_und_ff                         <= i_und_ff;

                o_ben_ff                         <= generate_ben (
                                                 i_mem_unsigned_byte_enable_ff, 
                                                 i_mem_signed_byte_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 mem_address_nxt);
        end
end

///////////////////////////////////////////////////////////////////////////////

// The reason we use the duplicate function is to copy value over the memory
// bus for memory stores. If we have a byte write to address 1, then the
// memory controller basically takes address 0 and byte enable 0010 and writes
// to address 1. This enables implementation of a 32-bit memory controller
// with byte enables to control updates as is common.
function [31:0] duplicate (     input ub, // Unsigned byte. 
                                input sb, // Signed byte.
                                input uh, // Unsigned halfword.
                                input sh, // Signed halfword.
                                input [31:0] val        );
reg [31:0] x;
begin
        if ( ub || sb)
        begin
                // Byte.
                x = {val[7:0], val[7:0], val[7:0], val[7:0]};    
        end
        else if (uh || sh)
        begin
                // Halfword.
                x = {val[15:0], val[15:0]};
        end
        else
        begin
                x = val;
        end

        duplicate = x;
end
endfunction

///////////////////////////////////////////////////////////////////////////////

// Generate byte enables.
function [3:0] generate_ben (   input ub, 
                                input sb, 
                                input uh, 
                                input sh, 
                                input [31:0] addr       );
reg [3:0] x;
begin
        if ( ub || sb )
        begin
                case ( addr[1:0] )
                0: x = 1;
                1: x = 1 << 1;
                2: x = 1 << 2;
                3: x = 1 << 3;
                endcase
        end 
        else if ( uh || sh )
        begin
                case ( addr[1] )
                0: x = 4'b0011;
                1: x = 4'b1100;
                endcase
        end
        else
        begin
                x = 4'b1111;
        end

        generate_ben = x;
end
endfunction

///////////////////////////////////////////////////////////////////////////////

always @*
begin
        // Memory address output based on pre or post index.
        if ( i_mem_pre_index_ff == 0 ) // Post-index. Update is done after memory access.
                mem_address_nxt = rn;   
        else                           // Pre-index. Update is done before memory access.
                mem_address_nxt = o_alu_result_nxt;

        // If a force 32 align is set, make the lower 2 bits as zero.
        // Force 32 align is valid for Thumb.
        if ( i_force32align_ff )
                mem_address_nxt[1:0] = 2'b00;

        // Do not change address if not needed.
        if (!( (i_mem_load_ff || i_mem_store_ff) && o_dav_nxt )) 
        // If NOT a load OR a store.
                mem_address_nxt = o_mem_address_ff;
end

///////////////////////////////////////////////////////////////////////////////

always @*
begin: blk1
       reg [31:0] rd; // Temporary result value, not index.
       reg [$clog2(ALU_OPS)-1:0]  opcode;

       o_clear_from_alu         = 1'd0;
       o_pc_from_alu            = 32'd0;
       opcode                   = i_alu_operation_ff;
       sleep_nxt                = sleep_ff;
       flags_nxt                = flags_ff;
       o_destination_index_nxt  = i_destination_index_ff;
       o_confirm_from_alu      = 1'd0;

       o_dav_nxt = is_cc_satisfied ( i_condition_code_ff, flags_ff[31:28] );

        // If it is a logical instruction.
        if (            opcode == AND || 
                        opcode == EOR || 
                        opcode == MOV || 
                        opcode == MVN || 
                        opcode == BIC || 
                        opcode == ORR ||
                        opcode == TST ||
                        opcode == TEQ ||
                        opcode == CLZ 
                )
        begin
                // Call the logical processing function.
                {flags_nxt[31:28], rd} = process_logical_instructions ( 
                        rn, rm, flags_ff[31:28], 
                        opcode, i_flag_update_ff, i_nozero_ff 
                );
        end

        // Flag MOV i.e., MOV to CPSR or MMOV.
        // FMOV moves to CPSR and flushes the pipeline.
        // MMOV moves to SPSR and does not flush the pipeline.
        else if ( opcode == FMOV || opcode == MMOV )
        begin: blk2
                integer i;
                reg [31:0] exp_mask;

                // Read entire CPSR or SPSR.
                rd = opcode == FMOV ? flags_ff : i_mem_srcdest_value_ff;

                // Generate a proper mask.
                exp_mask = {{8{rn[3]}},{8{rn[2]}},{8{rn[1]}},{8{rn[0]}}};

                // Change only specific bits as specified by the mask.
                for ( i=0;i<32;i=i+1 )
                begin
                        if ( exp_mask[i] )
                                rd[i] = rm[i];
                end

                // FMOV moves to the CPSR in ALU and writeback. 
                // No register is changed. The MSR out of this will have
                // a target to CPSR.
                if ( opcode == FMOV )
                begin
                        flags_nxt = rd;
                end
        end
        else
        begin: blk3
                reg [35:0] process_arithmetic_instructions;
                reg [3:0] flags;
                reg [$clog2(ALU_OPS)-1:0] op;
                reg i_flag_upd;
                reg [31:0]      r_d;
                reg             n,z,c,v;

                flags      = flags_ff[31:28];
                op         = opcode;
                i_flag_upd = i_flag_update_ff;

                // Avoid accidental latch inference.
                r_d       = 0;
                n         = 0;
                z         = 0;
                c         = 0;
                v         = 0;

                // Assign output of adder to variables
                {c,r_d} = sum;

                // Compute Z and N (C computed before).
                z = (r_d == 0);
                n = r_d[31];

                // Overflow.
                if ( ( op == ADD || op == ADC || op == CMN ) && (rn[31] == rm[31]) && (r_d[31] != rn[31]) )
                begin
                        v = 1;
                end 
                else if ( (op == RSB || op == RSC) && (rm[31] == !rn[31]) && (r_d[31] != rm[31] ) )
                begin
                        v = 1;
                end
                else if ( (op == SUB || op == SBC || op == CMP) && (rn[31] == !rm[31]) && (r_d[31] != rn[31]) )
                begin
                        v = 1;
                end
                else
                begin
                        v = 0;
                end
       
                // If you choose not to update flags, force n,z,c,v to previous values. 
                // Otherwise, they will contain their newly computed values.
                if ( !i_flag_upd )
                        {n,z,c,v} = flags;

                // Write out the result.
                process_arithmetic_instructions = {n, z, c, v, r_d};


                {flags_nxt[31:28], rd} = process_arithmetic_instructions; 
        end

        //////////////////////////////////////////////////////////////////////

        if ( i_irq_ff || i_fiq_ff || i_abt_ff || i_swi_ff || i_und_ff ) 
        // Any sign of an interrupt is present.
        begin
                $display($time, "ALU :: Interrupt detected! ALU put to sleep...");

                o_dav_nxt = 1'd0;
                sleep_nxt = 1'd1;
        end
        else if ( (opcode == FMOV) && o_dav_nxt ) // Writes to CPSR.
        begin
                $display($time, "ALU :: Major change to CPSR! Restarting from the next instruction...");
                o_clear_from_alu        = 1'd1;
                o_pc_from_alu           = sum;
                flags_nxt[`CPSR_MODE]   = (flags_nxt[`CPSR_MODE] == USR) ? USR : flags_nxt[`CPSR_MODE]; // Security.
        end
        else if ( i_destination_index_ff == ARCH_PC && (i_condition_code_ff != NV))
        begin
                if ( i_flag_update_ff && o_dav_nxt ) 
                // Unit sleeps since this is handled in WB. 
                // PC update flag_update
                // Will restore CPU mode from SPSR.
                begin
                        $display($time, "ALU :: PC write with flag update! Unit put to sleep...");
                        sleep_nxt = 1'd1;

                        // No need to tell the predictor anything. We will
                        // pass on destination as PC along with other information.
                end
                else if ( o_dav_nxt ) // Branch taken and no flag update.
                begin
                        $display($time, "ALU :: A quick branch! Possibly a BX i_switch_ff = %d...", i_switch_ff);

                        if ( i_taken_ff == SNT || i_taken_ff == WNT ) 
                        // Incorrectly predicted.
                        begin
                                // Quick branches - Flush everything before.
                                // Dumping ground since PC change is done.
                                o_destination_index_nxt = PHY_RAZ_REGISTER;
                                o_clear_from_alu        = 1'd1;
                                o_pc_from_alu           = rd;
                                flags_nxt[T]            = i_switch_ff ? 
                                                          rd[0] : flags_ff[T];   
                                                        // Thumb/ARM state if 
                                                        // i_switch_ff = 1.
                        end
                        else    // Correctly predicted.
                        begin
                                // If thumb bit changes, flush everything before
                                if ( i_switch_ff )
                                begin
                                        // Quick branches!
                                        o_destination_index_nxt = PHY_RAZ_REGISTER;                     
                                        // Dumping ground since PC change is done.
                                         
                                        o_clear_from_alu        = 1'd1;
                                        o_pc_from_alu           = rd;
                                        flags_nxt[T]            = i_switch_ff ? 
                                                                   rd[0] : 
                                                                   flags_ff[T];   
                                        // Thumb/ARM state if i_switch_ff = 1.
                                end
                                else
                                begin
                                        // No mode change, do not change 
                                        // anything.
                                        o_destination_index_nxt = PHY_RAZ_REGISTER;
                                        o_clear_from_alu = 1'd0;
                                        flags_nxt[T]     = i_switch_ff ? rd[0]: 
                                                                  flags_ff[T];

                                        // Send confirmation message to branch 
                                        // predictor.
                                        o_pc_from_alu      = 32'd0;
                                        o_confirm_from_alu = 1'd1; 
                                end
                        end
                end
                else    // Branch not taken
                begin
                        if ( i_taken_ff == WT || i_taken_ff == ST ) 
                        // Wrong prediction.
                        begin
                                o_clear_from_alu = 1'd1;
                                o_pc_from_alu    = i_pc_ff; 
                                // Go to the same branch.
                        end
                        else
                        begin
                                // Correct prediction.
                                o_clear_from_alu = 1'd0;
                                o_pc_from_alu    = 32'd0;
                        end
                end
        end
        else if ( i_mem_srcdest_index_ff == ARCH_PC && o_dav_nxt && i_mem_load_ff)
        begin
                // Loads to PC also puts the unit to sleep.
                sleep_nxt = 1'd1;
        end

        // Drive ALU result nxt bus using rd.
        o_alu_result_nxt = rd;

        if ( o_dav_nxt == 1'd0 ) 
        // If the current instruction is invalid, do not update flags.
                flags_nxt = flags_ff;
end

///////////////////////////////////////////////////////////////////////////////

// Process logical instructions.
function [35:0] process_logical_instructions 
( input [31:0] rn, rm, input [3:0] flags, input [$clog2(ALU_OPS)-1:0] op, 
                                input i_flag_upd, input nozero );
begin: blk2
        reg [31:0] rd;
        reg [3:0] flags_out;

        // Avoid accidental latch inference.
        rd        = 0;
        flags_out = 0;

        case(op)
        AND: rd = rn & rm;
        EOR: rd = rn ^ rm;
        BIC: rd = rn & ~(rm);
        MOV: rd = rm;
        MVN: rd = ~rm;
        ORR: rd = rn | rm;
        TST: rd = rn & rm; // Target is not written.
        TEQ: rd = rn ^ rn; // Target is not written.
        default:
        begin
                $display("This should never happen, check the RTL!");
                $finish;
        end
        endcase           

        // Suppose flags are not going to change at ALL.
        flags_out = flags;

        // Assign values to the flags only if an update is requested. Note that V
        // is not touched even if change is requested.
        if ( i_flag_upd )
        begin
                // V is preserved since flags_out = flags assignment.
                flags_out[_C] = i_shift_carry_ff;

                if ( nozero )
                        //
                        // This specifically states that we must NOT set the 
                        // ZERO flag under any circumstance. 
                        //
                        flags_out[_Z] = 1'd0;
                else
                        flags_out[_Z] = (rd == 0);

                flags_out[_N] = rd[31];
        end

        process_logical_instructions = {flags_out, rd};     
end
endfunction

///////////////////////////////////////////////////////////////////////////////

//
// These are ALU connections. Data processing and FMOV use these.
//

always @*
begin: op1op2blk
        reg [$clog2(ALU_OPS)-1:0] op;
        reg [31:0] flags;

        flags = flags_ff[31:28];
        op    = i_alu_operation_ff;

        if ( i_hijack ) 
        begin
                op1 = i_hijack_op1;
                op2 = i_hijack_op2;
                cin = i_hijack_cin;
        end
        else
        case ( op )
       FMOV: begin op1 = i_pc_plus_8_ff ; op2 = ~32'd4 ; cin =   1'd1;      end
        ADD: begin op1 = rn             ; op2 = rm     ; cin =   32'd0;     end
        ADC: begin op1 = rn             ; op2 = rm     ; cin =   flags[_C]; end
        SUB: begin op1 = rn             ; op2 = not_rm ; cin =   32'd1;     end
        RSB: begin op1 = rm             ; op2 = not_rn ; cin =   32'd1;     end
        SBC: begin op1 = rn             ; op2 = not_rm ; cin =   !flags[_C];end
        RSC: begin op1 = rm             ; op2 = not_rn ; cin =   !flags[_C];end

        // Target is not written.
        CMP: begin op1 = rn             ; op2 = not_rm ; cin =   32'd1;     end 
        CMN: begin op1 = rn             ; op2 = rm     ; cin =   32'd0;     end 
        default:
        begin
                op1 = 0;
                op2 = 0;
                cin = 0;
        end
        endcase
end

assign o_hijack_sum = sum;

///////////////////////////////////////////////////////////////////////////////

//
// The 32-bit ALU.
//
alu u_alu ( .op1(op1), .op2(op2), .cin(cin), .sum(sum) );

///////////////////////////////////////////////////////////////////////////////

endmodule // zap_alu_main.v
