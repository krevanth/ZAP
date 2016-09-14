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
                output  reg                             o_mem_translate,                // Force user's view of memory.
                
                // Unrecognized instruction.
                output  reg                             o_und,

                // ARM <-> Thumb switch indicator. Indicated on a BX.
                output  reg                             o_switch
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

reg clz, bx, dp, br, mrs, msr, ls, mult, halfword_ls, swi, mcr, mrc;

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
        o_und           = 0;
        o_switch        = 0;

        clz = 0; 
        bx = 0;
        dp = 0; br = 0; mrs = 0; msr = 0; ls = 0; mult = 0; 
        halfword_ls = 0; swi = 0; mcr = 0; mrc = 0;


        // Based on our pattern match, call the appropriate task
        if ( i_instruction_valid )
        casez ( i_instruction[31:0] )
        CLZ_INST:                                       decode_clz ( i_instruction );
        BX_INST:                                        decode_bx ( i_instruction );
        DATA_PROCESSING_IMMEDIATE, 
        DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT, 
        DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT:    decode_data_processing ( i_instruction );
        BRANCH_INSTRUCTION:                             decode_branch ( i_instruction );   
        MRS:                                            decode_mrs ( i_instruction );   
        MSR,MSR_IMMEDIATE:                              decode_msr ( i_instruction );
        LS_INSTRUCTION_SPECIFIED_SHIFT,LS_IMMEDIATE:    decode_ls ( i_instruction );
        MULT_INST:                                      decode_mult ( i_instruction );
        HALFWORD_LS:                                    decode_halfword_ls ( i_instruction );
        SOFTWARE_INTERRUPT:                             decode_swi ( i_instruction );
        MCR:                                            decode_mcr ( i_instruction );
        MRC:                                            decode_mrc ( i_instruction );
        default:
        begin
                decode_und ( i_instruction );
        end
        endcase

        `ifdef SIM
        // Debugging purposes.
        if ( i_instruction_valid )
        casez ( i_instruction[31:0] )
        CLZ_INST:                                       clz = 1;
        BX_INST:                                        bx  = 1;
        DATA_PROCESSING_IMMEDIATE, 
        DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT, 
        DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT:    dp  = 1;
        BRANCH_INSTRUCTION:                             br  = 1;   
        MRS:                                            mrs = 1;
        MSR,MSR_IMMEDIATE:                              msr = 1; 
        LS_INSTRUCTION_SPECIFIED_SHIFT,LS_IMMEDIATE:    
        begin
                if ( i_instruction[20] )
                        ls  = 1; // Load
                else
                        ls  = 2;  // Store
        end
        MULT_INST:                                     mult = 1;
        HALFWORD_LS:                                    halfword_ls = 1; 
        SOFTWARE_INTERRUPT:                             swi = 1;         
        MCR:                                            mcr = 1;         
        MRC:                                            mrc = 1;         
        endcase
        `endif
end

// Task definitions.

task decode_mcr ( input [34:0] i_instruction );
begin: decMcrTsk
        reg [4:0] coproc_reg;
        reg [3:0] src_reg;
        reg [34:0] instruction;

        case ( i_instruction[19:16] )
                0: coproc_reg = CP15_R0;
                1: coproc_reg = CP15_R1;
                2: coproc_reg = CP15_R2;
                3: coproc_reg = CP15_R3;
                4: coproc_reg = CP15_R4;
                5: coproc_reg = CP15_R5;
                6: coproc_reg = CP15_R6;
                7: coproc_reg = CP15_R7;
                8: coproc_reg = CP15_R8;
          default: coproc_reg = PHY_RAZ_REGISTER;
        endcase

        src_reg = i_instruction[15:12];

        // MOV Rx, R
        instruction = {i_instruction[31:28], 2'b00, 1'b0, MOV, 1'd0, 4'd0, 4'd0, 8'd0, src_reg}; 
        {instruction[`DP_RD_EXTEND], instruction[`DP_RD]} = coproc_reg;

        // If we are writing to CP8 with opcode2 = 1, redirect to CP15_R0 since that operation is invalid for CP15_R0.
        // Taken as a local TLB invalidate.
        if ( coproc_reg == CP15_R8 && i_instruction[3:0] == 4'd1 )
                {instruction[`DP_RD_EXTEND],instruction[`DP_RD]} = CP15_R0;

        // Decode that as a DPI.
        decode_data_processing(instruction);
end
endtask

task decode_mrc( input [34:0] i_instruction );
begin: decMrcTsk
        reg [3:0] coproc_reg;
        reg [3:0] dest_reg;
        reg [34:0] instruction;

        case ( i_instruction[19:16] )
                0: coproc_reg = CP15_R0;
                1: coproc_reg = CP15_R1;
                2: coproc_reg = CP15_R2;
                3: coproc_reg = CP15_R3;
                4: coproc_reg = CP15_R4;
                5: coproc_reg = CP15_R5;
                6: coproc_reg = CP15_R6;
                7: coproc_reg = CP15_R7;
                8: coproc_reg = CP15_R8;
          default: coproc_reg = PHY_RAZ_REGISTER;
        endcase

        dest_reg = i_instruction[15:12];

        // MOV R, Rx
        instruction = {i_instruction[31:28], 2'b00, 1'b0, MOV, 1'd0, 4'd0, dest_reg, 8'd0, 4'd0};
        {instruction[`DP_RS_EXTEND],instruction[`DP_RS]} = coproc_reg;

        // Decode that as a DPI.
        decode_data_processing(instruction);
end
endtask

task decode_und( input [34:0] i_instruction );
begin
        // Say instruction is undefined.
        o_und = 1;
end
endtask

task decode_swi( input [34:0] i_instruction );
begin: tskDecodeSWI
        // Generate a MOV RAZ, SWI_number.

        `ifdef SIM
                $display($time, "%m:SWI decode...");
        `endif

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

task decode_halfword_ls( input [34:0] i_instruction );
begin: tskDecodeHalfWordLs
        reg [11:0] temp, temp1;

        `ifdef SIM
                $display($time, "%m: Halfword decode...");
        `endif

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

        o_mem_unsigned_byte_enable      = 0;
        o_mem_unsigned_halfword_enable  = 0;
        o_mem_signed_halfword_enable    = 0;

        case ( i_instruction[6:5] )
        SIGNED_BYTE:            o_mem_signed_byte_enable = 1;
        UNSIGNED_HALF_WORD:     o_mem_unsigned_halfword_enable = 1;
        SIGNED_HALF_WORD:       o_mem_signed_halfword_enable = 1;
        default:
        begin
                o_mem_unsigned_byte_enable      = 0;
                o_mem_unsigned_halfword_enable  = 0;
                o_mem_signed_halfword_enable    = 0;
        end
        endcase
end
endtask

task decode_mult( input [34:0] i_instruction );
begin: tskDecodeMult

        `ifdef SIM
                $display($time, "%m: MLT decode...");
        `endif

        o_condition_code        =       i_instruction[31:28];
        o_alu_operation         =       MLA;
        o_destination_index     =       {i_instruction[`DP_RD_EXTEND], i_instruction[19:16]};
        // For MUL, Rd and Rn are interchanged.
        o_alu_source            =       i_instruction[11:8]; // ARM rs
        o_alu_source[32]        =       INDEX_EN;

        o_shift_source          =       {i_instruction[`DP_RS_EXTEND], i_instruction[`DP_RS]};
        o_shift_source[32]      =       INDEX_EN;            // ARM rm 

        // ARM rn
        o_shift_length          =       i_instruction[24] ? {i_instruction[`DP_RN_EXTEND], i_instruction[`DP_RD]} : 32'd0;
        o_shift_length[32]      =       i_instruction[24] ? INDEX_EN : IMMED_EN;
end
endtask

// Converted into a MOV to PC. The task of setting the T-bit in the CPSR is
// the job of the writeback stage.
task decode_bx( input [34:0] i_instruction );
begin: tskDecodeBx
        reg [31:0] temp;
        temp = i_instruction;
        temp[11:4] = 0;

        `ifdef SIM
                $display($time, "%m: BX decode...");
        `endif

        process_instruction_specified_shift(temp[11:0]);

        // The RAW ALU source does not matter.
        o_condition_code        = i_instruction[31:28];
        o_alu_operation         = MOV;
        o_destination_index     = ARCH_PC;

        // We will force an immediate in alu source to prevent unwanted locks.
        o_alu_source            = 0;
        o_alu_source[32]        = IMMED_EN;

        // Indicate switch.
        o_switch = 1;
end
endtask

// Count leading zeroes... This is a v5T instruction.
task decode_clz( input [34:0] i_instruction );
begin: tskDecodeClz
        // The raw ALU source does not matter.

        reg [31:0] temp;

        `ifdef SIM
                $display($time, "%m: CLZ decode...");
        `endif

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
task decode_ls( input [34:0] i_instruction );
begin: tskDecodeLs

        `ifdef SIM
                $display($time, "%m: LS decode...");
        `endif

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

task decode_mrs( input [34:0] i_instruction );
begin

        `ifdef SIM
                $display($time, "%m: MRS decode...");
        `endif

        process_immediate ( i_instruction[11:0] );
        
        o_condition_code    = i_instruction[31:28];
        o_destination_index = {i_instruction[`DP_RD_EXTEND], i_instruction[`DP_RD]};
        o_alu_source        = i_instruction[22] ? ARCH_CURR_SPSR : ARCH_CPSR;
        o_alu_source[32]    = INDEX_EN;
        o_alu_operation     = ADD;
end
endtask

task decode_msr( input [34:0] i_instruction );
begin
        `ifdef SIM
                $display($time, "%m: MSR decode...");
        `endif

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

task decode_branch( input [34:0] i_instruction );
begin
        `ifdef SIM
                $display($time, "%m: B decode...");
        `endif

        // A branch is decayed into PC = PC + $signed(immed)
        o_condition_code        = i_instruction[31:28];
        o_alu_operation         = ADD;
        o_destination_index     = ARCH_PC;
        o_alu_source            = ARCH_PC;
        o_alu_source[32]        = INDEX_EN;
        o_shift_source          = ($signed(i_instruction[23:0]));
        o_shift_source[32]      = IMMED_EN;
        o_shift_operation       = LSL;
        o_shift_length          = i_instruction[34] ? 1 : 2; // Thumb branches sometimes need only a shift of 1.
        o_shift_length[32]      = IMMED_EN; 
end
endtask

// Common data processing handles the common section of all 3 data processing
// formats.
task decode_data_processing( input [34:0] i_instruction );
begin
        `ifdef SIM
                $display($time, "%m: Normal DP decode...");
        `endif

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
        default:
        begin
                $display("This should never happen! Check the RTL..!");
                $finish;
        end
        endcase
end
endtask

// If an immediate value is to be rotated right by an immediate value, this mode is used.
task process_immediate ( input [11:0] instruction );
begin

        `ifdef SIM
        $display("%m Process immediate...");
        `endif

        o_shift_length          = instruction[11:8] << 1'd1;
        o_shift_length[32]      = IMMED_EN;
        o_shift_source          = instruction[7:0];
        o_shift_source[32]      = IMMED_EN;                        
        o_shift_operation       = RORI;
end
endtask

// The shifter source is a register but the amount to shift is in the instruction itself.
task process_instruction_specified_shift ( input [34:0] instruction );
begin
        `ifdef SIM
        $display("%m Process instruction specified shift...");
        `endif

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
task process_register_specified_shift ( input [34:0] instruction );
begin
        `ifdef SIM
        $display("%m Process register specified shift...");
        `endif

        o_shift_length          = instruction[11:8];
        o_shift_length[32]      = INDEX_EN;
        o_shift_source          = {i_instruction[`DP_RS_EXTEND], instruction[`DP_RS]};
        o_shift_source[32]      = INDEX_EN;
        o_shift_operation       = instruction[6:5];
end
endtask

endmodule
