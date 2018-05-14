// ---------------------------------------------------------------------------
// --                                                                       --
// --                   (C) 2016-2018 Revanth Kamaraj.                      --
// --                                                                       -- 
// -- ------------------------------------------------------------------------
// --                                                                       --
// -- This program is free software; you can redistribute it and/or         --
// -- modify it under the terms of the GNU General Public License           --
// -- as published by the Free Software Foundation; either version 2        --
// -- of the License, or (at your option) any later version.                --
// --                                                                       --
// -- This program is distributed in the hope that it will be useful,       --
// -- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
// -- GNU General Public License for more details.                          --
// --                                                                       --
// -- You should have received a copy of the GNU General Public License     --
// -- along with this program; if not, write to the Free Software           --
// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA         --
// -- 02110-1301, USA.                                                      --
// --                                                                       --
// ---------------------------------------------------------------------------
// --                                                                       --
// -- This is the main ZAP arithmetic and logic unit. Apart from shfits     --
// -- and multiplies, all other arithmetic and logic is performed here.     --
// -- Also data memory access signals are generated at the end of the clock --
// -- cycle.  Instructions that fail condition checks are invalidated here. --
// --                                                                       --
// ---------------------------------------------------------------------------

`default_nettype none

module zap_alu_main #(

        parameter [31:0] PHY_REGS  = 32'd46, // Number of physical registers.
        parameter [31:0] SHIFT_OPS = 32'd5,  // Number of shift operations.
        parameter [31:0] ALU_OPS   = 32'd32, // Number of arithmetic operations.
        parameter [31:0] FLAG_WDT  = 32'd32  // Width of active CPSR.
)
(
        input wire      [64*8-1:0]         i_decompile,
        output reg      [64*8-1:0]         o_decompile,

        input wire                         i_hijack,                    // Enable hijack.
        input wire      [31:0]             i_hijack_op1,                // Hijack operand 1.
        input wire      [31:0]             i_hijack_op2,                // Hijack operand 2.
        input wire                         i_hijack_cin,                // Hijack carry in.
        output wire     [31:0]             o_hijack_sum,                // Hijack sum out.

        input wire                         i_clk,                       // Clock.
        input wire                         i_reset,                     // sync active high reset.
        input wire  [31:0]                 i_cpsr_nxt,                  // From passive CPSR.
        input wire                         i_clear_from_writeback,      // Clear unit.
        input wire                         i_data_stall,                // DCACHE stall.
        input wire                         i_switch_ff,                 // Switch state.
        input wire   [1:0]                 i_taken_ff,                  // Branch prediction.
        input wire   [31:0]                i_pc_ff,                     // Addr of instr.
        input wire                         i_nozero_ff,                 // Zero flag will not be set.
        input wire  [31:0]                 i_mem_srcdest_value_ff,      // Value to store. 
        input wire  [31:0]                 i_alu_source_value_ff,       // ALU source value.
        input wire  [31:0]                 i_shifted_source_value_ff,   // Shifted source value.
        input wire                         i_shift_carry_ff,            // Carry from shifter.        
        input wire  [31:0]                 i_pc_plus_8_ff,              // PC + 8 value.

        input wire                         i_abt_ff,                    // ABT flagged.
        input wire                         i_irq_ff,                    // IRQ flagged.
        input wire                         i_fiq_ff,                    // FIQ flagged.
        input wire                         i_swi_ff,                    // SWI flagged.

        input wire  [zap_clog2(PHY_REGS)-1:0] i_mem_srcdest_index_ff,           // LD/ST Memory data register index.    
        input wire                            i_mem_load_ff,                    // LD/ST Memory load.
        input wire                            i_mem_store_ff,                   // LD/ST Memory store.                    
        input wire                            i_mem_pre_index_ff,               // LD/ST Pre/Post index.
        input wire                            i_mem_unsigned_byte_enable_ff,    // LD/ST uint8_t  data type.
        input wire                            i_mem_signed_byte_enable_ff,      // LD/ST int8_t   data type.
        input wire                            i_mem_signed_halfword_enable_ff,  // LD/ST int16_t data type.
        input wire                            i_mem_unsigned_halfword_enable_ff,// LD/ST uint16_t  data type.
        input wire                            i_mem_translate_ff,               // LD/ST Force user view of memory.

        input wire  [3:0]                       i_condition_code_ff,            // CC associated with instr.
        input wire  [zap_clog2(PHY_REGS)-1:0]   i_destination_index_ff,         // Target register index.
        input wire  [zap_clog2(ALU_OPS)-1:0]    i_alu_operation_ff,             // Operation to perform.
        input wire                              i_flag_update_ff,               // Update flags if 1.
        input wire                              i_force32align_ff,              // Force address alignment to 32-bit.
        input wire                              i_und_ff,                       // Flagged undefined instructions.
        input wire                              i_data_mem_fault,               // Flagged Data abort.

        output reg [31:0]                   o_alu_result_nxt,           // For feedback. ALU result _nxt version.
        output reg [31:0]                   o_alu_result_ff,            // ALU result flopped version.

        output reg                          o_abt_ff,                   // Instruction abort flagged.
        output reg                          o_irq_ff,                   // IRQ flagged.
        output reg                          o_fiq_ff,                   // FIQ flagged.
        output reg                          o_swi_ff,                   // SWI flagged.
        output reg                          o_und_ff,                   // Flagged undefined instructions

        output reg                          o_dav_ff,                   // Instruction valid.
        output reg                          o_dav_nxt,                  // Instruction valid _nxt version.
        output reg [31:0]                   o_pc_plus_8_ff,             // Instr address + 8.
        output reg                          o_clear_from_alu,           // ALU commands a pipeline clear and a predictor correction.
        output reg [31:0]                   o_pc_from_alu,              // Corresponding address to go to is provided here.
        output reg [zap_clog2(PHY_REGS)-1:0]o_destination_index_ff,     // Destination register index.
        output reg [FLAG_WDT-1:0]           o_flags_ff,                 // Output flags (CPSR).
        output reg [FLAG_WDT-1:0]           o_flags_nxt,                // CPSR next.
        output reg                          o_confirm_from_alu,         // Tell branch predictor it was correct.

        output reg  [zap_clog2(PHY_REGS)-1:0]  o_mem_srcdest_index_ff,  // LD/ST data register.
        output reg                          o_mem_load_ff,              // LD/ST load indicator.
        output reg                          o_mem_store_ff,             // LD/ST store indicator.
        output reg [31:0]                   o_mem_address_ff,           // LD/ST address to access.
        output reg                          o_mem_unsigned_byte_enable_ff,     // uint8_t
        output reg                          o_mem_signed_byte_enable_ff,       // int8_t
        output reg                          o_mem_signed_halfword_enable_ff,   // int16_t
        output reg                          o_mem_unsigned_halfword_enable_ff, // uint16_t
        output reg [31:0]                   o_mem_srcdest_value_ff,     // LD/ST value to store.
        output reg                          o_mem_translate_ff,         // LD/ST force user view of memory.
        output reg [3:0]                    o_ben_ff,                   // LD/ST byte enables (only for STore instructions).
        output reg  [31:0]                  o_address_nxt,              // D pin of address register to drive TAG RAMs.

        // Wishbone signal outputs.
        output reg                              o_data_wb_we_nxt,
        output reg                              o_data_wb_cyc_nxt,
        output reg                              o_data_wb_stb_nxt,
        output reg [31:0]                       o_data_wb_dat_nxt,
        output reg [3:0]                        o_data_wb_sel_nxt,
        output reg                              o_data_wb_we_ff,
        output reg                              o_data_wb_cyc_ff,
        output reg                              o_data_wb_stb_ff,
        output reg [31:0]                       o_data_wb_dat_ff,
        output reg [3:0]                        o_data_wb_sel_ff
);

// ----------------------------------------------------------------------------

`include "zap_defines.vh"
`include "zap_localparams.vh"
`include "zap_functions.vh"

wire [31:0] mem_srcdest_value_nxt;
wire [3:0] ben_nxt;

// Address about to be output. Used to potentially drive tag RAMs etc.
reg [31:0]                      mem_address_nxt;

assign ben_nxt = i_mem_store_ff ? generate_ben (
                                                 i_mem_unsigned_byte_enable_ff, 
                                                 i_mem_signed_byte_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 mem_address_nxt) : i_mem_load_ff ? 4'b1111 : o_ben_ff;

assign mem_srcdest_value_nxt =  duplicate (
                                                 i_mem_unsigned_byte_enable_ff, 
                                                 i_mem_signed_byte_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 i_mem_unsigned_halfword_enable_ff, 
                                                 i_mem_srcdest_value_ff );  

//
// These override global N,Z,C,V definitions which are on CPSR. These params
// are localized over the 4-bit flag structure.
//
localparam [1:0] _N  = 2'd3;
localparam [1:0] _Z  = 2'd2;
localparam [1:0] _C  = 2'd1;
localparam [1:0] _V  = 2'd0;

// Branch status.
localparam [1:0] SNT = 2'd0;
localparam [1:0] WNT = 2'd1;
localparam [1:0] WT  = 2'd2;
localparam [1:0] ST  = 2'd3;

// Sleep flop.
reg                             sleep_ff, sleep_nxt;

// CPSR (Active CPSR).
reg [31:0]                      flags_ff, flags_nxt;

reg [31:0]                      rm, rn; // RM = shifted source value Rn for
                                        // non shifted source value. These are
                                        // values and not indices.



// Destination index about to be output.
reg [zap_clog2(PHY_REGS)-1:0]      o_destination_index_nxt;

// Negation of Rm and Rn.
wire [31:0]                     not_rm = ~rm;
wire [31:0]                     not_rn = ~rn;

// Wires to emulate an adder.
reg [31:0]      op1, op2;
reg             cin;
wire [32:0]     sum = {1'd0, op1} + {1'd0, op2} + {32'd0, cin};

reg [31:0] tmp_flags, tmp_sum;

// Opcode.
wire [zap_clog2(ALU_OPS)-1:0] opcode = i_alu_operation_ff;

// Hijack interface.
assign o_hijack_sum = sum;

// ----------------------------------------------------------------------------

always @*
begin
        rm          = i_shifted_source_value_ff;
        rn          = i_alu_source_value_ff;
        o_flags_ff  = flags_ff;
        o_flags_nxt = flags_nxt;
end

// Sequential logic.
always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                //
                // On reset, processor enters supervisory mode with interrupts
                // masked.
                //
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
                // Clear and preserve flags. Keep sleeping.
                clear(flags_ff);
                sleep_ff                         <= 1'd1; 
        end
        else
        begin
                // Clock out all flops normally.

                o_alu_result_ff                  <= o_alu_result_nxt;
                o_dav_ff                         <= o_dav_nxt;                
                o_pc_plus_8_ff                   <= i_pc_plus_8_ff;
                o_destination_index_ff           <= o_destination_index_nxt;
                flags_ff                         <= flags_nxt;
                o_abt_ff                         <= i_abt_ff;
                o_irq_ff                         <= i_irq_ff;
                o_fiq_ff                         <= i_fiq_ff;
                o_swi_ff                         <= i_swi_ff;
                o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;
                o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;           

                // Load or store must come up only if an actual LDR/STR is
                // detected.
                o_mem_load_ff                    <= o_dav_nxt ? i_mem_load_ff : 1'd0;                    
                o_mem_store_ff                   <= o_dav_nxt ? i_mem_store_ff: 1'd0;                   

                o_mem_unsigned_byte_enable_ff    <= i_mem_unsigned_byte_enable_ff;    
                o_mem_signed_byte_enable_ff      <= i_mem_signed_byte_enable_ff;      
                o_mem_signed_halfword_enable_ff  <= i_mem_signed_halfword_enable_ff;  
                o_mem_unsigned_halfword_enable_ff<= i_mem_unsigned_halfword_enable_ff;
                o_mem_translate_ff               <= i_mem_translate_ff;  

                //
                // The value to store will have to be duplicated for easier
                // memory controller design. See the duplicate() function.
                //
                o_mem_srcdest_value_ff           <= mem_srcdest_value_nxt; 

                sleep_ff                         <= sleep_nxt;
                o_und_ff                         <= i_und_ff;

                // Generating byte enables based on the data type and address.
                o_ben_ff                         <= ben_nxt;

                // For debug
                o_decompile                     <= i_decompile;
        end
end

// ----------------------------------------------------------------------------

always @ (posedge i_clk) // Wishbone flops.
begin
                // Wishbone updates.    
                o_data_wb_cyc_ff                <= o_data_wb_cyc_nxt;
                o_data_wb_stb_ff                <= o_data_wb_stb_nxt;
                o_data_wb_we_ff                 <= o_data_wb_we_nxt;
                o_data_wb_dat_ff                <= o_data_wb_dat_nxt;
                o_data_wb_sel_ff                <= o_data_wb_sel_nxt;
                o_mem_address_ff                <= o_address_nxt; 
end

always @* // Wishbone next state logic.
begin
        // Preserve values.
        o_data_wb_cyc_nxt = o_data_wb_cyc_ff;
        o_data_wb_stb_nxt = o_data_wb_stb_ff;
        o_data_wb_we_nxt  = o_data_wb_we_ff;
        o_data_wb_dat_nxt = o_data_wb_dat_ff;
        o_data_wb_sel_nxt = o_data_wb_sel_ff;
        o_address_nxt     = o_mem_address_ff;

        if ( i_reset )  
        begin 
                o_data_wb_cyc_nxt = 1'd0;
                o_data_wb_stb_nxt = 1'd0;
        end 
        else if ( i_clear_from_writeback ) 
        begin 
                o_data_wb_cyc_nxt = 0;
                o_data_wb_stb_nxt = 0;
        end
        else if ( i_data_stall ) begin end
        else if ( i_data_mem_fault || sleep_ff ) 
        begin 
                o_data_wb_cyc_nxt = 0;
                o_data_wb_stb_nxt = 0;
        end
        else
        begin
                o_data_wb_cyc_nxt = o_dav_nxt ? i_mem_load_ff | i_mem_store_ff : 1'd0;
                o_data_wb_stb_nxt = o_dav_nxt ? i_mem_load_ff | i_mem_store_ff : 1'd0;
                o_data_wb_we_nxt  = o_dav_nxt ? i_mem_store_ff                 : 1'd0;
                o_data_wb_dat_nxt = mem_srcdest_value_nxt; 
                o_data_wb_sel_nxt = ben_nxt;
                o_address_nxt     = mem_address_nxt;
        end
end

// ----------------------------------------------------------------------------

always @*
begin:pre_post_index
        // Memory address output based on pre or post index.
        if ( i_mem_pre_index_ff == 0 ) // Post-index. Update is done after memory access.
                mem_address_nxt = rn;   
        else                           // Pre-index. Update is done before memory access.
                mem_address_nxt = o_alu_result_nxt;

        //
        // If a force 32 align is set, make the lower 2 bits as zero.
        // Force 32 align is valid for Thumb.
        //
        if ( i_force32align_ff )
                mem_address_nxt[1:0] = 2'b00;

        //
        // Do not change address if not needed.
        // If not a load OR a store. Preserve this value. Power saving.
        //
        if (!( (i_mem_load_ff || i_mem_store_ff) && o_dav_nxt )) 
                mem_address_nxt = o_mem_address_ff;
end

// ----------------------------------------------------------------------------

`ifndef SYNTHESIS

reg [64*8-1:0] OPCODE;

always @*
case(opcode)
AND:begin       OPCODE = "AND";    end              
EOR:begin       OPCODE = "EOR";    end    
MOV:begin       OPCODE = "MOV";    end
MVN:begin       OPCODE = "MVN";    end
BIC:begin       OPCODE = "BIC";    end
ORR:begin       OPCODE = "ORR";    end
TST:begin       OPCODE = "TST";    end
TEQ:begin       OPCODE = "TEQ";    end
CLZ:begin       OPCODE = "CLZ";    end
FMOV:begin      OPCODE = "FMOV";   end
ADD:begin       OPCODE = "ADD";    end   
ADC:begin       OPCODE = "ADC";    end 
SUB:begin       OPCODE = "SUB";    end 
RSB:begin       OPCODE = "RSB";    end 
SBC:begin       OPCODE = "SBC";    end 
RSC:begin       OPCODE = "RSC";    end 
CMP:begin       OPCODE = "CMP";    end
CMN:begin       OPCODE = "CMN";    end
endcase

`endif

always @*
begin: alu_result

        // Default value.
        tmp_flags = flags_ff;        

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
                {tmp_flags[31:28], tmp_sum} = process_logical_instructions ( 
                        rn, rm, flags_ff[31:28], 
                        opcode, i_flag_update_ff, i_nozero_ff 
                );
        end

        //
        // Flag MOV i.e., MOV to CPSR or MMOV.
        // FMOV moves to CPSR and flushes the pipeline.
        // MMOV moves to SPSR and does not flush the pipeline.
        //
        else if ( opcode == FMOV || opcode == MMOV )
        begin: fmov_mmov
                integer i;
                reg [31:0] exp_mask;

                // Read entire CPSR or SPSR.
                tmp_sum = opcode == FMOV ? flags_ff : i_mem_srcdest_value_ff;

                // Generate a proper mask.
                exp_mask = {{8{rn[3]}},{8{rn[2]}},{8{rn[1]}},{8{rn[0]}}};

                // Change only specific bits as specified by the mask.
                for ( i=0;i<32;i=i+1 )
                begin
                        if ( exp_mask[i] )
                                tmp_sum[i] = rm[i];
                end

                //
                // FMOV moves to the CPSR in ALU and writeback. 
                // No register is changed. The MSR out of this will have
                // a target to CPSR.
                //
                if ( opcode == FMOV )
                begin
                        tmp_flags = tmp_sum;
                end
        end
        else
        begin: blk3
                reg [3:0] flags;
                reg [zap_clog2(ALU_OPS)-1:0] op;
                reg n,z,c,v;

                op         = opcode;

                // Assign output of adder to flags.
                c = sum[32];
                z = (sum[31:0] == 0);
                n = sum[31];

                // Overflow.
                if ( ( op == ADD || op == ADC || op == CMN ) && (rn[31] == rm[31]) && (sum[31] != rn[31]) )
                begin
                        v = 1;
                end 
                else if ( (op == RSB || op == RSC) && (rm[31] == !rn[31]) && (sum[31] != rm[31] ) )
                begin
                        v = 1;
                end
                else if ( (op == SUB || op == SBC || op == CMP) && (rn[31] == !rm[31]) && (sum[31] != rn[31]) )
                begin
                        v = 1;
                end
                else
                begin
                        v = 0;
                end

                //       
                // If you choose not to update flags, do not change the flags.
                // Otherwise, they will contain their newly computed values.
                //
                if ( i_flag_update_ff )
                        tmp_flags[31:28] = {n,z,c,v};

                // Write out the result.
                tmp_sum = sum; 
        end

        // Drive nxt pin of result register.
        o_alu_result_nxt = tmp_sum;
end

// ----------------------------------------------------------------------------

always @*
begin: flags_bp_feedback

       o_clear_from_alu         = 1'd0;
       o_pc_from_alu            = 32'd0;
       sleep_nxt                = sleep_ff;
       flags_nxt                = tmp_flags;
       o_destination_index_nxt  = i_destination_index_ff;
       o_confirm_from_alu       = 1'd0;

        // Check if condition is satisfied.
       o_dav_nxt = is_cc_satisfied ( i_condition_code_ff, flags_ff[31:28] );

        if ( i_irq_ff || i_fiq_ff || i_abt_ff || i_swi_ff || i_und_ff ) 
        begin
                //
                // Any sign of an interrupt is present, put unit to sleep.
                // The current instruction will not be executed ultimately.
                //
                o_dav_nxt = 1'd0;
                sleep_nxt = 1'd1;
        end
        else if ( (opcode == FMOV) && o_dav_nxt ) // Writes to CPSR...
        begin
                o_clear_from_alu        = 1'd1; // Need to flush everything because we might end up fetching stuff in KERNEL instead of USER mode.
                o_pc_from_alu           = sum;  // NOT tmp_sum, that would be loaded into CPSR. 

                // USR cannot change mode. Will silently fail.
                flags_nxt[`CPSR_MODE]   = (flags_nxt[`CPSR_MODE] == USR) ? USR : flags_nxt[`CPSR_MODE]; // Security.
        end
        else if ( i_destination_index_ff == ARCH_PC && (i_condition_code_ff != NV))
        begin
                if ( i_flag_update_ff && o_dav_nxt ) 
                // PC update with S bit.
                // Will restore CPU mode from SPSR. USR no change.
                begin
                        o_destination_index_nxt = PHY_RAZ_REGISTER;
                        o_clear_from_alu        = 1'd1;
                        o_pc_from_alu           = tmp_sum;
                        flags_nxt               = i_mem_srcdest_value_ff;                                       // Restore CPSR from SPSR.
                        flags_nxt[`CPSR_MODE]   = (flags_nxt[`CPSR_MODE] == USR) ? USR : flags_nxt[`CPSR_MODE]; // Security.
                end
                else if ( o_dav_nxt ) // Branch taken and no flag update.
                begin
                        if ( i_taken_ff == SNT || i_taken_ff == WNT ) 
                        // Incorrectly predicted as not-taken.
                        begin
                                // Quick branches - Flush everything before.

                                // Dumping ground since PC change is done.
                                o_destination_index_nxt = PHY_RAZ_REGISTER;
                                o_clear_from_alu        = 1'd1;
                                o_pc_from_alu           = tmp_sum;
                                flags_nxt[T]            = i_switch_ff ? tmp_sum[0] : flags_ff[T]; // Thumb/ARM state if i_switch_ff = 1.
                        end
                        else    // Correctly predicted.
                        begin
                                // If thumb bit changes, flush everything before
                                if ( i_switch_ff )
                                begin
                                        //
                                        // Quick branches! PC goes to RAZ register since
                                        // change is done.
                                        //
                                        o_destination_index_nxt = PHY_RAZ_REGISTER;                     
                                         
                                        o_clear_from_alu        = 1'd1;
                                        o_pc_from_alu           = tmp_sum;
                                        flags_nxt[T]            = i_switch_ff ? tmp_sum[0] : flags_ff[T];   
                                        // Thumb/ARM state if i_switch_ff = 1.
                                end
                                else
                                begin
                                        //
                                        // No mode change, do not change 
                                        // anything.
                                        //
                                        o_destination_index_nxt = PHY_RAZ_REGISTER;
                                        o_clear_from_alu = 1'd0;
                                        flags_nxt[T]     = i_switch_ff ? tmp_sum[0]: flags_ff[T];

                                        //
                                        // Send confirmation message to branch 
                                        // predictor.
                                        //
                                        o_pc_from_alu      = 32'd0;
                                        o_confirm_from_alu = 1'd1; 
                                end
                        end
                end
                else    // Branch not taken
                begin
                        if ( i_taken_ff == WT || i_taken_ff == ST ) 
                        // Wrong prediction as taken...
                        begin
                                // Go to the same branch.
                                o_clear_from_alu = 1'd1;
                                o_pc_from_alu    = i_pc_ff; 
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

        // If the current instruction is invalid, do not update flags.
        if ( o_dav_nxt == 1'd0 ) 
                flags_nxt = flags_ff;
end

// ----------------------------------------------------------------------------

// These are adder connections. Data processing and FMOV use these.
always @*
begin: adder_ip_mux
        reg [zap_clog2(ALU_OPS)-1:0] op;
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

// ----------------------------------------------------------------------------

// Process logical instructions.
function [35:0] process_logical_instructions 
( input [31:0] rn, rm, input [3:0] flags, input [zap_clog2(ALU_OPS)-1:0] op, 
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
                rd = 0;
                $display("*W: WARNING: Logic unit got non logic opcode...");
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

// ----------------------------------------------------------------------------

task clear ( input [31:0] flags );
begin
                o_dav_ff                         <= 0;
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

// ----------------------------------------------------------------------------

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

// ----------------------------------------------------------------------------

// Generate byte enables.
function [3:0] generate_ben (   input ub, // Unsigned byte. 
                                input sb, // Signed byte.
                                input uh, // Unsigned halfword.
                                input sh, // Signed halfword.
                                input [31:0] addr       );
reg [3:0] x;
begin
        if ( ub || sb ) // Byte oriented.
        begin
                case ( addr[1:0] ) // Based on address lower 2-bits.
                0: x = 1;
                1: x = 1 << 1;
                2: x = 1 << 2;
                3: x = 1 << 3;
                endcase
        end 
        else if ( uh || sh ) // Halfword. A word = 2 half words.
        begin
                case ( addr[1] )
                0: x = 4'b0011;
                1: x = 4'b1100;
                endcase
        end
        else
        begin
                x = 4'b1111; // Word oriented.
        end

        generate_ben = x;
end
endfunction

`ifndef SYNTHESIS

always @*
if ( flags_nxt[`CPSR_MODE] != USR && flags_ff[`CPSR_MODE] == USR )
begin
        $display($time, "FUNC_ERROR :: %m CPU is changing out of USR mode without an exception...");
        $stop;
end

`endif

endmodule // zap_alu_main.v
`default_nettype wire
