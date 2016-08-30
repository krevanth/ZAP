`default_nettype none

/*
 Filename --
 zap_decode.v

 HDL --
 Verilog-2005

 Description --
 This is the ZAP decode unit. You must precede this unit with an FSM to
 manage more complex instructions. This decoder works for all ARM
 instructions except long multiply. The majority of outputs of this unit are
 expected to go to the ISSUE stage. 

 Note --
 You may have noticed that the sources and shift lengths are 33-bit. The
 upper bit is used to indicate the type of value [31:0] has. If [33] is
 IMMED_EN, then [31:0] is a 32-bit immediate value. If [33] is INDEX_EN, then
 [31:0] is a register index (although only the lower 5-bits are actually
 used if the number of arch regs i.e., ARCH_REGS = 32, for example).

 Dependencies --
 None

 Author --
 Revanth Kamaraj.

 License --
 MIT license.
*/

module zap_decode #(

        // Parameters.

        // For several reasons, we need more architectural registers than
        // what ARM specifies. We also need more physical registers.
        parameter ARCH_REGS = 32,

        // Although ARM mentions only 16 ALU operations, the processor
        // internally performs many more operations.
        parameter ALU_OPS   = 32,

        // Apart from the 4 specified by ARM, an undocumented RORI is present
        // to help deal with immediate rotates.
        parameter SHIFT_OPS = 5
)
(
                // I/O Ports.
                
                // From the FSM.
                input    wire   [34:0]                  i_instruction,          // The upper 2-bit are {rd/ptr,rm/srcdest}
                input    wire                           i_instruction_valid,
                
                // This signal is used to check the validity of a pipeline stage.
                output   reg    [3:0]                   o_condition_code,
                
                // Where the primary output of the instruction must go to. Make this RAZ to throw away the primary output to a void.
                output   reg    [$clog2(ARCH_REGS)-1:0] o_destination_index,
                
                // The ALU source is the source that is fed directly to the ALU without the barrel shifter. For multiplication, o_alu_source simply becomes an operand.
                output   reg    [32:0]                  o_alu_source,
                output   reg    [$clog2(ALU_OPS)-1:0]   o_alu_operation,
                
                // Stuff related to the shifter. For multiplication, the source and length simply become two operands.
                output   reg    [32:0]                  o_shift_source,
                output   reg    [$clog2(SHIFT_OPS)-1:0] o_shift_operation,
                output   reg    [32:0]                  o_shift_length,
                
                // Update the flags. Note that writing to CPSR will cause a flag-update (if you asked for) even if this is 0.
                output  reg                             o_flag_update,
                
                // Things related to memory operations.
                output  reg   [$clog2(ARCH_REGS)-1:0]   o_mem_srcdest_index,            // Data register.
                output  reg                             o_mem_load,                     // Type of operation...
                output  reg                             o_mem_store,
                output  reg                             o_mem_pre_index,                // Indicate pre-ALU tap for address.
                output  reg                             o_mem_unsigned_byte_enable,     // Byte enable (unsigned).
                output  reg                             o_mem_signed_byte_enable,       
                output  reg                             o_mem_signed_halfword_enable,
                output  reg                             o_mem_unsigned_halfword_enable,
                output  reg                             o_mem_translate                 // Force user's view of memory.
);

`include "regs.vh"
`include "shtype.vh"
`include "opcodes.vh"
`include "modes.vh"
`include "cc.vh"
`include "instruction_patterns.vh"
`include "sh_params.vh"
`include "cpsr.vh"
`include "index_immed.vh"
`include "fields.vh"

// Main reg is here...

always @*
begin
        // If an unrecognized instruction enters this, the output
        // signals an NV state i.e., invalid.
        o_condition_code        = NV;
        o_destination_index     = 0;
        o_alu_source            = 0;
        o_alu_operation         = 0;
        o_shift_source          = 0;
        o_shift_operation       = 0;
        o_shift_length          = 0;
        o_flag_update           = 0;
        o_mem_srcdest_index     = 0;
        o_mem_load              = 0;
        o_mem_store             = 0;
        o_mem_translate         = 0;
        o_mem_pre_index         = 0;
        o_mem_unsigned_byte_enable = 0;
        o_mem_signed_byte_enable = 0;
        o_mem_signed_halfword_enable = 0;
        o_mem_unsigned_halfword_enable = 0;
        o_mem_translate = 0;

        // Based on our pattern match, call the appropriate task
        if ( i_instruction_valid )
        casez ( i_instruction[31:0] )
        DATA_PROCESSING_IMMEDIATE, 
        DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT, 
        DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT:    decode_data_processing;
        BRANCH_INSTRUCTION:                             decode_branch;   
        MRS:                                            decode_mrs;   
        MSR,MSR_IMMEDIATE:                              decode_msr;
        LS_INSTRUCTION_SPECIFIED_SHIFT,LS_IMMEDIATE:    decode_ls;
        CLZ_INST:                                       decode_clz;
        BX_INST:                                        decode_bx;
        MULT_INST:                                      decode_mult;
        HALFWORD_LS:                                    decode_halfword_ls;
        SOFTWARE_INTERRUPT:                             decode_swi;
        endcase
end

// Task definitions.

task decode_swi;
begin: tskDecodeSWI
        // Generate a MOV RAZ, SWI_number.

        $display($time, "%m:SWI decode...");

        o_condition_code = i_instruction[31:28];
        o_alu_operation  = MOV;
        o_alu_source     = RAZ_REGISTER;
        o_alu_source = 0;
        o_alu_source[32] = IMMED_EN; 
        o_destination_index = RAZ_REGISTER;
        o_shift_source = i_instruction[23:0];
        o_shift_operation = LSL;
        o_shift_length = 0;
        o_shift_length[32] = IMMED_EN;
end
endtask

task decode_halfword_ls;
begin: tskDecodeHalfWordLs
        reg [11:0] temp, temp1;

        $display($time, "%m: Halfword decode...");

        temp = i_instruction;
        temp1 = i_instruction;

        o_condition_code = i_instruction[31:28];

        temp[7:4] = temp[11:8];
        temp[11:8] = 0;
        temp1[11:4] = 0;

        if ( i_instruction[22] ) // immediate
        begin
                process_immediate ( temp );
        end
        else
        begin
                process_instruction_specified_shift ( temp1 );  
        end

        o_alu_operation     = i_instruction[23] ? ADD : SUB;
        o_alu_source        = {i_instruction[`BASE_EXTEND], i_instruction[`BASE]}; // Pointer register.
        o_alu_source[32]    = INDEX_EN;
        o_mem_load          = i_instruction[20];
        o_mem_store         = !o_mem_load;
        o_mem_pre_index     = i_instruction[24];

        // If post-index is used or pre-index is used with writeback,
        // take is as a request to update the base register.
        o_destination_index = (i_instruction[21] || !o_mem_pre_index) ? 
                                o_alu_source : 
                                RAZ_REGISTER; // Pointer register already added.

        o_mem_srcdest_index = {i_instruction[`SRCDEST_EXTEND], i_instruction[`SRCDEST]};

        // Transfer size.
        case ( i_instruction[6:5] )
        SIGNED_BYTE:            o_mem_signed_byte_enable = 1;
        UNSIGNED_HALF_WORD:     o_mem_unsigned_halfword_enable = 1;
        SIGNED_HALF_WORD:       o_mem_signed_halfword_enable = 1;
        endcase
end
endtask

task decode_mult;
begin: tskDecodeMult

        $display($time, "%m: MLT decode...");

        o_condition_code        =       i_instruction[31:28];
        o_alu_operation         =       i_instruction[24] ? MLA : MUL;
        o_destination_index     =       {i_instruction[`DP_RD_EXTEND], i_instruction[19:16]};
        // For MUL, Rd and Rn are interchanged.
        o_alu_source            =       i_instruction[11:8];
        o_alu_source[32]        =       INDEX_EN;
        o_shift_source          =       {i_instruction[`DP_RS_EXTEND], i_instruction[`DP_RS]};
        o_shift_source[32]      =       INDEX_EN;

        // Multiplication does not use the traditional shifter+ALU. The
        // shifter consists of 2 parallel 32x16=32 unsigned multiplier blocks
        // and the ALU adder is used to process the two products. This allows
        // the unit to perform multiplication at the rate of 1 per clock
        // cycle max.

        // To avoid unwanted locks.
        o_shift_length          =       0;
        o_shift_length[32]      =       IMMED_EN;
end
endtask

// Converted into a MOV to PC. The task of setting the T-bit in the CPSR is
// the job of the writeback stage.
task decode_bx;
begin: tskDecodeBx
        reg [31:0] temp;
        temp = i_instruction;
        temp[11:4] = 0;

        $display($time, "%m: BX decode...");

        process_instruction_specified_shift(temp[11:0]);

        // The RAW ALU source does not matter.
        o_condition_code        = i_instruction[31:28];
        o_alu_operation         = MOV;
        o_destination_index     = ARCH_PC;

        // We will force an immediate in alu source to prevent unwanted locks.
        o_alu_source            = 0;
        o_alu_source[32]        = IMMED_EN;
end
endtask

// Count leading zeroes... This is a v5T instruction.
task decode_clz;
begin: tskDecodeClz
        // The raw ALU source does not matter.

        reg [31:0] temp;

        $display($time, "%m: CLZ decode...");

        temp = i_instruction;
        temp[4] = 1'd0;

        process_instruction_specified_shift ( temp[11:0] );

        o_destination_index = {i_instruction[`DP_RD_EXTEND], i_instruction[`DP_RD]};
        o_alu_operation = CLZ;
        o_condition_code = i_instruction[31:28];

        // We will force an immediate in alu source to prevent unwanted locks.
        o_alu_source            = 0;
        o_alu_source[32]        = IMMED_EN;
end
endtask

// Task for decoding load-store instructions.
task decode_ls;
begin: tskDecodeLs

        $display($time, "%m: LS decode...");

        o_condition_code = i_instruction[31:28];

        if ( !i_instruction[25] ) // immediate
        begin
                o_shift_source          = i_instruction[11:0];
                o_shift_source[32]      = IMMED_EN;
                o_shift_length          = 0;
                o_shift_length[32]      = IMMED_EN;
                o_shift_operation       = LSL;                
        end
        else
        begin
              process_instruction_specified_shift ( i_instruction[11:0] );  
        end

        o_alu_operation = i_instruction[23] ? ADD : SUB;
        o_alu_source    = {i_instruction[`BASE_EXTEND], i_instruction[`BASE]}; // Pointer register.
        o_alu_source[32] = INDEX_EN;
        o_mem_load          = i_instruction[20];
        o_mem_store         = !o_mem_load;
        o_mem_pre_index     = i_instruction[24];

        // If post-index is used or pre-index is used with writeback,
        // take is as a request to update the base register.
        o_destination_index = (i_instruction[21] || !o_mem_pre_index) ? 
                                o_alu_source : 
                                RAZ_REGISTER; // Pointer register already added.
        o_mem_unsigned_byte_enable = i_instruction[22];

        // If we do not require a user bank transfer. Note that this stuff
        // cannot come from an LDR/STR itself but comes from an LDM/STM
        // instruction instead.
        o_mem_srcdest_index = {i_instruction[`SRCDEST_EXTEND], i_instruction[`SRCDEST]};

        if ( !o_mem_pre_index ) // Post-index, writeback has no meaning.
        begin
                if ( i_instruction[21] )
                begin
                        // Use it for force usr mode memory mappings.
                        o_mem_translate = 1'd1;
                end
        end
end
endtask

task decode_mrs;
begin

        $display($time, "%m: MRS decode...");

        process_immediate ( i_instruction[11:0] );
        
        o_condition_code    = i_instruction[31:28];
        o_destination_index = {i_instruction[`DP_RD_EXTEND], i_instruction[`DP_RD]};
        o_alu_source        = i_instruction[22] ? ARCH_CURR_SPSR : ARCH_CPSR;
        o_alu_source[32]    = INDEX_EN;
        o_alu_operation     = ADD;
end
endtask

task decode_msr;
begin

        $display($time, "%m: MSR decode...");

        if ( i_instruction[25] ) // Immediate present.
        begin
                process_immediate ( i_instruction[11:0] );
        end
        else
        begin
                process_instruction_specified_shift ( i_instruction[11:0] );
        end

        // Destination.
        o_destination_index = i_instruction[22] ? ARCH_CPSR : ARCH_CURR_SPSR;

        o_condition_code = i_instruction[31:28];
        o_alu_operation  = i_instruction[22] ? FMOV : MMOV;
        o_alu_source     = i_instruction[25] ? (i_instruction[19:16] & 4'b1000) 
                                : i_instruction[19:16];
        o_alu_source[32] = IMMED_EN; 
end
endtask

task decode_branch;
begin

        $display($time, "%m: B decode...");

        // A branch is decayed into PC = PC + $signed(immed)
        o_condition_code        = i_instruction[31:28];
        o_alu_operation         = ADD;
        o_destination_index     = ARCH_PC;
        o_alu_source            = ARCH_PC;
        o_alu_source[32]        = INDEX_EN;
        o_shift_source          = ($signed(i_instruction[23:0]));
        o_shift_source[32]      = IMMED_EN;
        o_shift_operation       = LSL;
        o_shift_length          = 2;
        o_shift_length[32]      = IMMED_EN; 
end
endtask

// Common data processing handles the common section of all 3 data processing
// formats.
task decode_data_processing;
begin

        $display($time, "%m: Normal DP decode...");

        o_condition_code        = i_instruction[31:28];
        o_alu_operation         = i_instruction[24:21];
        o_flag_update           = i_instruction[20];
        o_destination_index     = {i_instruction[`DP_RD_EXTEND], i_instruction[`DP_RD]};
        o_alu_source            = i_instruction[19:16];
        o_alu_source[32]        = INDEX_EN;

        if (    o_alu_operation == CMP || 
                o_alu_operation == CMN || 
                o_alu_operation == TST || 
                o_alu_operation == TEQ )
        begin
                o_destination_index = RAZ_REGISTER;
        end

        casez ( {i_instruction[25],i_instruction[7],i_instruction[4]} )
        3'b1zz: process_immediate ( i_instruction[11:0] );
        3'b0z0: process_instruction_specified_shift ( i_instruction[11:0] );
        3'b001: process_register_specified_shift ( i_instruction[11:0] );
        endcase
end
endtask

// If an immediate value is to be rotated right by an immediate value, this mode is used.
task process_immediate ( input [11:0] instruction );
begin

        $display("%m Process immediate...");

        o_shift_length          = instruction[11:8] << 1'd1;
        o_shift_length[32]      = IMMED_EN;
        o_shift_source          = instruction[7:0];
        o_shift_source[32]      = IMMED_EN;                        
        o_shift_operation       = RORI;
end
endtask

// The shifter source is a register but the amount to shift is in the instruction itself.
task process_instruction_specified_shift ( input [33:0] instruction );
begin

        $display("%m Process instruction specified shift...");

        // ROR #0 = ROR #32, ASR #0 = ASR #23, LSL #0 = LSL #0.
        o_shift_length          = instruction[11:7];
        o_shift_length[32]      = IMMED_EN;
        o_shift_source          = {i_instruction[`DP_RS_EXTEND],instruction[`DP_RS]};
        o_shift_source[32]      = INDEX_EN;
        o_shift_operation       = instruction[6:5];

        case ( o_shift_operation )
        LSR: if ( !o_shift_length) o_shift_length = 32;
        ASR: if ( !o_shift_length) o_shift_length = 32;
        endcase

end
endtask

// The source register and the amount of shift are both in registers.
task process_register_specified_shift ( input [33:0] instruction );
begin

        $display("%m Process register specified shift...");

        o_shift_length          = instruction[11:8];
        o_shift_length[32]      = INDEX_EN;
        o_shift_source          = {i_instruction[`DP_RS_EXTEND], instruction[`DP_RS]};
        o_shift_source[32]      = INDEX_EN;
        o_shift_operation       = instruction[6:5];
end
endtask

endmodule
