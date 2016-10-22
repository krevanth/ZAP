`default_nettype none
`include "config.vh"

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

 For notation, Rs means Rm of ARM. The ARM Rs is just refered to here without
 a name and as a part select.

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

        // Number of shift operations.
        parameter SHIFT_OPS = 6
)
(
                // I/O Ports.
                input   wire                            i_irq, i_fiq, i_abt,
               
 
                // From the FSM.
                input    wire   [35:0]                  i_instruction,          // The upper 2-bit [34:33] are {rd/ptr,rm/srcdest}. The upper most bit is for opcode extend.
                input    wire                           i_instruction_valid,

                // CPSR.
                input   wire    [31:0]                  i_cpsr_ff, 
 
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

reg bx, dp, br, mrs, msr, ls, mult, halfword_ls, swi, dp1, dp2, dp3;

// Main reg is here...

always @*
begin: mainBlk1
        // If an unrecognized instruction enters this, the output
        // signals an NV state i.e., invalid.
        o_condition_code                = NV;
        o_destination_index             = 0;
        o_alu_source                    = 0;
        o_alu_operation                 = 0;
        o_shift_source                  = 0;
        o_shift_operation               = 0;
        o_shift_length                  = 0;
        o_flag_update                   = 0;
        o_mem_srcdest_index             = RAZ_REGISTER;
        o_mem_load                      = 0;
        o_mem_store                     = 0;
        o_mem_translate                 = 0;
        o_mem_pre_index                 = 0;
        o_mem_unsigned_byte_enable      = 0;
        o_mem_signed_byte_enable        = 0;
        o_mem_signed_halfword_enable    = 0;
        o_mem_unsigned_halfword_enable  = 0;
        o_mem_translate                 = 0;
        o_und                           = 0;
        o_switch                        = 0;

        bx  = 0;
        dp  = 0; 
        br  = 0; 
        mrs = 0; 
        msr = 0; 
        ls = 0; 
        mult = 0; 
        halfword_ls = 0; 
        swi = 0; 
        dp1 = 0;
        dp2 = 0;
        dp3 = 0;

                // Based on our pattern match, call the appropriate task
                if ( i_fiq || i_irq || i_abt )
                begin
                        // Generate LR = PC - 4.
                        o_condition_code    = AL;
                        o_alu_operation     = SUB;
                        o_alu_source        = ARCH_PC;
                        o_alu_source[32]    = INDEX_EN; 
                        o_destination_index = ARCH_LR;
                        o_shift_source      = 4;
                        o_shift_source[32]  = IMMED_EN;
                        o_shift_operation   = LSL;
                        o_shift_length      = 0;
                        o_shift_length[32]  = IMMED_EN;
                end
                else if ( i_instruction_valid )
                casez ( i_instruction[31:0] )
                BX_INST:                                        decode_bx ( i_instruction );
                MRS:                                            decode_mrs ( i_instruction );   
                MSR,MSR_IMMEDIATE:                              decode_msr ( i_instruction );
                DATA_PROCESSING_IMMEDIATE, 
                DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT, 
                DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT:    decode_data_processing ( i_instruction );
                BRANCH_INSTRUCTION:                             decode_branch ( i_instruction );   
                LS_INSTRUCTION_SPECIFIED_SHIFT,LS_IMMEDIATE:    decode_ls ( i_instruction );
                MULT_INST:                                      decode_mult ( i_instruction );
                LMULT_INST:                                     decode_lmult( i_instruction );
                HALFWORD_LS:                                    decode_halfword_ls ( i_instruction );
                SOFTWARE_INTERRUPT:                             decode_swi ( i_instruction );
                default:
                begin
                        decode_und ( i_instruction );
                end
                endcase

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                        // Debugging purposes.
                        if ( i_instruction_valid )
                        casez ( i_instruction[31:0] )
                        BX_INST:                                        bx  = 1;

                        MRS:                                            mrs = 1;
                        MSR,MSR_IMMEDIATE:                              msr = 1;

                        DATA_PROCESSING_IMMEDIATE, 
                        DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT, 
                        DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT:    dp  = 1;
                        BRANCH_INSTRUCTION:                             br  = 1;   
 
                        LS_INSTRUCTION_SPECIFIED_SHIFT,LS_IMMEDIATE:    
                        begin
                                if ( i_instruction[20] )
                                        ls  = 1; // Load
                                else
                                        ls  = 2;  // Store
                        end
                        MULT_INST:                                      mult            = 1;
                        HALFWORD_LS:                                    halfword_ls     = 1; 
                        SOFTWARE_INTERRUPT:                             swi             = 1;         
                        endcase

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

end

// Task definitions.

task decode_lmult ( input [35:0] i_instruction ); // Only this uses bit 35. rm.rs + {rh, rn}
begin: tskLDecodeMult

        o_condition_code        =       i_instruction[31:28];
        o_flag_update           =       i_instruction[20];

        // ARM rd.
        o_destination_index     =       {i_instruction[`DP_RD_EXTEND], i_instruction[19:16]};
        // For MUL, Rd and Rn are interchanged. For 64bit, this is normally high register.

        o_alu_source            =       i_instruction[11:8]; // ARM rs
        o_alu_source[32]        =       INDEX_EN;

        o_shift_source          =       {i_instruction[`DP_RS_EXTEND], i_instruction[`DP_RS]};
        o_shift_source[32]      =       INDEX_EN;            // ARM rm 

        // ARM rn
        o_shift_length          =       i_instruction[24] ? 
                                        {i_instruction[`DP_RN_EXTEND], i_instruction[`DP_RD]} : 32'd0;

        o_shift_length[32]      =       i_instruction[24] ? INDEX_EN : IMMED_EN;

        `ifdef SIM
                $display($time, "Long multiplication detected!");
        `endif

        // We need to generate output code.
        case ( i_instruction[22:21] )
        2'b00:
        begin
                // Unsigned MULT64
                o_alu_operation = UMLALH;
                o_mem_srcdest_index = RAZ_REGISTER; // rh.
        end
        2'b01:
        begin
                // Unsigned MAC64. Need mem_srcdest as source for RdHi.
                o_alu_operation = UMLALH;
                o_mem_srcdest_index = i_instruction[19:16];
        end
        2'b10:
        begin
                // Signed MULT64
                o_alu_operation = SMLALH;
                o_mem_srcdest_index = RAZ_REGISTER;
        end
        2'b11:
        begin
                // Signed MAC64. Need mem_srcdest as source of RdHi.
                o_alu_operation = SMLALH;
                o_mem_srcdest_index = i_instruction[19:16];
        end
        endcase

        if ( i_instruction[`OPCODE_EXTEND] == 1'd0 ) // Low request.
        begin
                        o_destination_index = i_instruction[15:12]; // Low register.
                        o_alu_operation[0]  = 1'd0;                 // Request low operation.
        end
end
endtask

task decode_und( input [34:0] i_instruction );
begin
        `ifdef SIM
                $display($time, "Undefined instruction detected! You may continue the simulation...");
                //$stop;
        `endif

        // Say instruction is undefined.
        o_und = 1;

        // Generate LR = PC - 4
        o_condition_code    = AL;
        o_alu_operation     = SUB;
        o_alu_source        = ARCH_PC;
        o_alu_source[32]    = INDEX_EN; 
        o_destination_index = ARCH_LR;
        o_shift_source      = 4;
        o_shift_source[32]  = IMMED_EN;
        o_shift_operation   = LSL;
        o_shift_length      = 0;
        o_shift_length[32]  = IMMED_EN;
end
endtask

task decode_swi( input [34:0] i_instruction );
begin: tskDecodeSWI

        `ifdef SIM
                $display($time, "%m:SWI decode...");
        `endif

        o_condition_code    = AL;
        o_alu_operation     = SUB;
        o_alu_source        = ARCH_PC;
        o_alu_source[32]    = INDEX_EN; 
        o_destination_index = ARCH_LR;
        o_shift_source      = 4;
        o_shift_source[32]  = IMMED_EN;
        o_shift_operation   = LSL;
        o_shift_length      = 0;
        o_shift_length[32]  = IMMED_EN;
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
                $display($time, "%m: MLT 32x32 -> 32 decode...");
        `endif

        o_condition_code        =       i_instruction[31:28];
        o_flag_update           =       i_instruction[20];
        o_alu_operation         =       UMLALL;
        o_destination_index     =       {i_instruction[`DP_RD_EXTEND], i_instruction[19:16]};

        // For MUL, Rd and Rn are interchanged.
        o_alu_source            =       i_instruction[11:8]; // ARM rs
        o_alu_source[32]        =       INDEX_EN;

        o_shift_source          =       {i_instruction[`DP_RS_EXTEND], i_instruction[`DP_RS]};
        o_shift_source[32]      =       INDEX_EN;            // ARM rm 

        // ARM rn - Set for accumulate.
        o_shift_length          =       i_instruction[21] ? 
                                        {i_instruction[`DP_RN_EXTEND], i_instruction[`DP_RD]} : 32'd0;

        o_shift_length[32]      =       i_instruction[21] ? INDEX_EN : IMMED_EN;

        // Set rh = 0.
        o_mem_srcdest_index = RAZ_REGISTER;
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
        o_destination_index = i_instruction[22] ? ARCH_CURR_SPSR : ARCH_CPSR;

        o_condition_code = i_instruction[31:28];
        o_alu_operation  = i_instruction[22] ? MMOV : FMOV;
        o_alu_source     = i_instruction[25] ? (i_instruction[19:16] & 4'b1000) 
                           : (i_instruction[19:16] & 4'b1001);
        o_alu_source[32] = IMMED_EN;

        // Part of the instruction will silently fail when changing mode bits
        // in user mode. This is as per the ARM spec.
        if  ( i_cpsr_ff[5:0] == USR )
        begin
                o_alu_source[2:0] = 3'b0;
        end
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
                $display($time, "%m: Normal DP decode... Received %x %b", i_instruction, i_instruction);
        `endif

        o_condition_code        = i_instruction[31:28];
        o_alu_operation         = i_instruction[24:21];
        o_flag_update           = i_instruction[20];
        o_destination_index     = {i_instruction[`DP_RD_EXTEND], i_instruction[`DP_RD]};
        o_alu_source            = i_instruction[19:16];
        o_alu_source[32]        = INDEX_EN;
        o_mem_srcdest_index     = ARCH_CURR_SPSR;

        if (    o_alu_operation == CMP || 
                o_alu_operation == CMN || 
                o_alu_operation == TST || 
                o_alu_operation == TEQ )
        begin
                o_destination_index = RAZ_REGISTER;
        end

        casez ( {i_instruction[25],i_instruction[7],i_instruction[4]} )
        3'b1zz: process_immediate ( i_instruction );
        3'b0z0: process_instruction_specified_shift ( i_instruction );
        3'b001: process_register_specified_shift ( i_instruction );
        default:
        begin
                $display("This should never happen! Check the RTL..!");
                $stop;
        end
        endcase
end
endtask

///////////////////////////////////////////////////////////////////////////////////////////////////////

// If an immediate value is to be rotated right by an immediate value, this mode is used.
task process_immediate ( input [34:0] instruction );
begin

        `ifdef SIM
        $display("%m Process immediate...");
        `endif

        dp1 = 1;

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

        dp2 = 1;

        // ROR #0 = RRC, ASR #0 = ASR #32, LSL #0 = LSL #0, LSR #0 = LSR #32 ROR #n = ROR_1 #n ( n > 0 )
        o_shift_length          = instruction[11:7];
        o_shift_length[32]      = IMMED_EN;
        o_shift_source          = {i_instruction[`DP_RS_EXTEND],instruction[`DP_RS]};
        o_shift_source[32]      = INDEX_EN;
        o_shift_operation       = instruction[6:5];

        case ( o_shift_operation )
                LSR: if ( !o_shift_length[31:0] ) o_shift_length[31:0] = 32;
                ASR: if ( !o_shift_length[31:0] ) o_shift_length[31:0] = 32;
                ROR: 
                begin
                        if ( !o_shift_length[31:0] ) 
                                o_shift_operation    = RRC;
                        else
                                o_shift_operation    = ROR_1; // Differs in carry generation behavior.
                end
        endcase

        // Reinforce the fact.
        o_shift_length[32] = IMMED_EN;
end
endtask

// The source register and the amount of shift are both in registers.
task process_register_specified_shift ( input [34:0] instruction );
begin
        `ifdef SIM
        $display("%m Process register specified shift...");
        `endif

        dp3 = 1;

        o_shift_length          = instruction[11:8];
        o_shift_length[32]      = INDEX_EN;
        o_shift_source          = {i_instruction[`DP_RS_EXTEND], instruction[`DP_RS]};
        o_shift_source[32]      = INDEX_EN;
        o_shift_operation       = instruction[6:5];
end
endtask

endmodule
