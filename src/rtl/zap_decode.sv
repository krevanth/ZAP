//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//
// This module performs core mode32 instruction decoding by translating mode32
// instructions into an internal long format that can be processed by core
// logic. Note that the predecode stage must change the 32-bit instr. to
// 36-bit before feeding it into this unit.
//

//
// If an immediate value is to be rotated right by an
// immediate value, this mode is used.
//
// If using direct constant without rotation, make it LSL #0.
//

module zap_decode #(
parameter [31:0] ARCH_REGS  = 32,
parameter [31:0] ALU_OPS    = 32,
parameter [31:0] SHIFT_OPS  = 6
)
(
input   logic                             i_irq,
input   logic                             i_fiq,
input   logic                             i_abt,

input    logic   [35:0]                   i_instruction,
input    logic                            i_instruction_valid,

output   logic    [3:0]                   o_condition_code,
output   logic    [$clog2(ARCH_REGS)-1:0] o_destination_index,
output   logic    [32:0]                  o_alu_source,
output   logic    [$clog2(ALU_OPS)-1:0]   o_alu_operation,
output   logic    [32:0]                  o_shift_source,
output   logic    [$clog2(SHIFT_OPS)-1:0] o_shift_operation,
output   logic    [32:0]                  o_shift_length,
output  logic                             o_flag_update,
output  logic   [$clog2(ARCH_REGS)-1:0]   o_mem_srcdest_index,
output  logic                             o_mem_load,
output  logic                             o_mem_store,
output  logic                             o_mem_pre_index,
output  logic                             o_mem_unsigned_byte_enable,
output  logic                             o_mem_signed_byte_enable,
output  logic                             o_mem_signed_halfword_enable,
output  logic                             o_mem_unsigned_halfword_enable,
output  logic                             o_mem_translate,
output  logic                             o_und,
output  logic                             o_switch
);

`include "zap_defines.svh"
`include "zap_localparams.svh"

// Related to memory operations.
localparam [1:0] SIGNED_BYTE            = 2'd2;
localparam [1:0] UNSIGNED_HALF_WORD     = 2'd1;
localparam [1:0] SIGNED_HALF_WORD       = 2'd3;

// Global variables.
logic [35:0] instruction;

always_comb
begin

        instruction                     = i_instruction;

        // ==========================================
        // Default value section
        // (Done to avoid combo loops/incomplete assignments)
        // ==========================================

        // If an unrecognized instruction enters this, the output
        // signals an NV state i.e., invalid.
        o_condition_code                = NV;
        o_destination_index             = RAZ_REGISTER;
        o_alu_operation                 = 0;
        o_shift_operation               = 0;
        o_alu_source                    = 0;
        o_shift_source                  = 0;
        o_shift_length                  = 0;
        o_alu_source[32]                = IMMED_EN;
        o_shift_source[32]              = IMMED_EN;
        o_shift_length[32]              = IMMED_EN;
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

        // ========================================================
        // Based on our pattern match, do the required action.
        // ========================================================

        if ( i_fiq || i_irq || i_abt )
        begin
                // Generate LR = PC - 4.
                o_condition_code    = AL;
                o_alu_operation     = {2'd0, SUB};
                o_alu_source        = {29'd0, ARCH_PC};
                o_alu_source[32]    = INDEX_EN;
                o_destination_index = {1'd0, ARCH_LR};
                o_shift_source      = 4;
                o_shift_source[32]  = IMMED_EN;
                o_shift_operation   = {1'd0, LSL};
                o_shift_length      = 0;
                o_shift_length[32]  = IMMED_EN;
        end
        else if ( i_instruction_valid )
        begin
                casez ( instruction[31:0] )

                PLD:
                begin
                        // Generate a NOP i.e., R0 = R0 & R0.
                        o_condition_code    = AL;
                        o_alu_operation     = {2'd0, AND};
                        o_alu_source        = 0;
                        o_alu_source[32]    = INDEX_EN;
                        o_destination_index = 0;
                        o_shift_source      = 0;
                        o_shift_source[32]  = IMMED_EN;
                        o_shift_operation   = {1'd0, LSL};
                        o_shift_length      = 0;
                        o_shift_length[32]  = IMMED_EN;
                end

                SMLAxy, SMLAWy,
                SMLALxy:
                begin: tskLDecodeMultDsp

                        o_condition_code        =       instruction[31:28];
                        o_flag_update           =       1'd1;

                        // mode32 rd.
                        o_destination_index     =       {instruction[ZAP_DP_RD_EXTEND],
                                                         instruction[19:16]};

                        // For MUL, Rd and Rn are interchanged.
                        // For 64bit, this is normally high register.

                        o_alu_source            =       {29'd0, instruction[11:8]}; // mode32 rs
                        o_alu_source[32]        =       INDEX_EN;

                        o_shift_source          =       {28'd0, instruction[ZAP_DP_RB_EXTEND],
                                                         instruction[`ZAP_DP_RB]};
                        o_shift_source[32]      =       INDEX_EN;            // mode32 rm

                        o_shift_length          =       // mode32 rn.
                                                        {28'd0, instruction[ZAP_DP_RA_EXTEND],
                                                         instruction[`ZAP_DP_RD]};

                        o_shift_length[32]      =       INDEX_EN;


                        // We need to generate output code.
                        casez ( instruction[31:0] )

                        SMLAxy:
                        begin
                                o_alu_operation     = instruction[6:5] == 2'b00 ? SMLA00 :
                                                      instruction[6:5] == 2'b01 ? SMLA01 :
                                                      instruction[6:5] == 2'b10 ? SMLA10 :
                                                                                  SMLA11 ;


                                o_mem_srcdest_index = RAZ_REGISTER; // rh.
                        end

                        SMLAWy:
                        begin
                                o_alu_operation     = instruction[6] ? SMLAW1 : SMLAW0;

                                o_mem_srcdest_index = {1'd0, instruction[19:16]}; // rh
                        end

                        SMLALxy:
                        begin
                                o_alu_operation     = instruction[6:5] == 2'b00 ? SMLAL00H :
                                                      instruction[6:5] == 2'b01 ? SMLAL01H :
                                                      instruction[6:5] == 2'b10 ? SMLAL10H :
                                                      instruction[6:5] == 2'b11 ? SMLAL11H : SMLAL11H ;

                                o_mem_srcdest_index = {1'd0, instruction[19:16]}; // rh
                        end

                        default:
                        begin
                                // Synth will OPTIMIZE. OK to do for FPGA synthesis.
                                {o_alu_operation, o_mem_srcdest_index} = 'x;
                        end

                        endcase

                        // Detect a low request.
                        if
                        (
                                instruction[ZAP_OPCODE_EXTEND] == 1'd0 &&
                                instruction[31:0] ==? SMLALxy
                        )
                        begin
                                        o_destination_index = {1'd0, instruction[15:12]}; // Low register.

                                        o_alu_operation =
                                        instruction[6:5] == 2'b00 ? SMLAL00L :
                                        instruction[6:5] == 2'b01 ? SMLAL01L :
                                        instruction[6:5] == 2'b10 ? SMLAL10L :
                                                                    SMLAL11L;

                                        // Ensure low register operation.
                                        assert ( o_alu_operation[0] == 1'd0 ) else
                                        $fatal(2, "ALU low bit not set to zero.");
                        end
                end



                SMULWy, SMULxy:
                begin
                        o_condition_code    = instruction[31:28];
                        o_flag_update       = 1'd1;

                        o_alu_operation = ((instruction[22:21] == 2'b01) && instruction[5] && instruction[15:12] == 0) ?
                                          (instruction[6] ? OP_SMULW0 : OP_SMULW1) :
                                          (instruction[6:5] == 2'b00 ? OP_SMUL00 :
                                           instruction[6:5] == 2'b01 ? OP_SMUL01 :
                                           instruction[6:5] == 2'b10 ? OP_SMUL10 :
                                           instruction[6:5] == 2'b11 ? OP_SMUL11 : OP_SMUL11) ;

                        // mode32 rd
                        o_destination_index = {instruction[ZAP_DP_RD_EXTEND], instruction[19:16]};

                        // mode32 Rs.
                        o_alu_source = {29'd0, instruction[11:8]};
                        o_alu_source[32] = INDEX_EN;

                        // mode32 rm
                        o_shift_source = {28'd0, instruction[ZAP_DP_RB_EXTEND], instruction[`ZAP_DP_RB]};
                        o_shift_source[32] = INDEX_EN;

                        // mode32 rm=0
                        o_shift_length     = 33'd0;
                        o_shift_length[32] = INDEX_EN;

                        // Set rh=0
                        o_mem_srcdest_index = RAZ_REGISTER;
                end


                QADD:
                begin
                        o_condition_code        = instruction[31:28];
                        o_flag_update           = 1'd1;

                        case(instruction[22:21])
                        2'b00: o_alu_operation         = {1'd0, OP_QADD};
                        2'b01: o_alu_operation         = {1'd0, OP_QSUB};
                        2'b10: o_alu_operation         = {1'd0, OP_QDADD};
                        2'b11: o_alu_operation         = {1'd0, OP_QDSUB};
                      default: o_alu_operation         = 'x; // Propagate X;
                        endcase

                        // Processor does Rn - Rm.

                        // Rn
                        o_alu_source            = {29'd0, instruction[3:0]};
                        o_alu_source[32]        = INDEX_EN;

                        // Rm
                        o_shift_source          = {29'd0, instruction[19:16]};
                        o_shift_source[32]      = INDEX_EN;

                        // Rs
                        o_shift_operation       = LSL_SAT;
                        o_shift_length          = 1;
                        o_shift_length[32]      = IMMED_EN;

                        // Destination index.
                        o_destination_index     = {1'd0, instruction[15:12]};
                end


                QSUB:
                begin
                        o_condition_code        = instruction[31:28];
                        o_flag_update           = 1'd1;

                        case(instruction[22:21])
                        2'b00: o_alu_operation         = {1'd0, OP_QADD};
                        2'b01: o_alu_operation         = {1'd0, OP_QSUB};
                        2'b10: o_alu_operation         = {1'd0, OP_QDADD};
                        2'b11: o_alu_operation         = {1'd0, OP_QDSUB};
                      default: o_alu_operation         = 'x; // Propagate X;
                        endcase

                        // Processor does Rn - Rm.

                        // Rn
                        o_alu_source            = {29'd0, instruction[3:0]};
                        o_alu_source[32]        = INDEX_EN;

                        // Rm
                        o_shift_source          = {29'd0, instruction[19:16]};
                        o_shift_source[32]      = INDEX_EN;

                        // Rs
                        o_shift_operation       = LSL_SAT;
                        o_shift_length          = 1;
                        o_shift_length[32]      = IMMED_EN;

                        // Destination index.
                        o_destination_index     = {1'd0, instruction[15:12]};
                end


                QDADD:
                begin
                        o_condition_code        = instruction[31:28];
                        o_flag_update           = 1'd1;

                        case(instruction[22:21])
                        2'b00: o_alu_operation         = {1'd0, OP_QADD};
                        2'b01: o_alu_operation         = {1'd0, OP_QSUB};
                        2'b10: o_alu_operation         = {1'd0, OP_QDADD};
                        2'b11: o_alu_operation         = {1'd0, OP_QDSUB};
                      default: o_alu_operation         = 'x; // Propagate X;
                        endcase

                        // Processor does Rn - Rm.

                        // Rn
                        o_alu_source            = {29'd0, instruction[3:0]};
                        o_alu_source[32]        = INDEX_EN;

                        // Rm
                        o_shift_source          = {29'd0, instruction[19:16]};
                        o_shift_source[32]      = INDEX_EN;

                        // Rs
                        o_shift_operation       = LSL_SAT;
                        o_shift_length          = 1;
                        o_shift_length[32]      = IMMED_EN;

                        // Destination index.
                        o_destination_index     = {1'd0, instruction[15:12]};
                end


                QDSUB:
                begin
                        o_condition_code        = instruction[31:28];
                        o_flag_update           = 1'd1;

                        case(instruction[22:21])
                        2'b00: o_alu_operation         = {1'd0, OP_QADD};
                        2'b01: o_alu_operation         = {1'd0, OP_QSUB};
                        2'b10: o_alu_operation         = {1'd0, OP_QDADD};
                        2'b11: o_alu_operation         = {1'd0, OP_QDSUB};
                      default: o_alu_operation         = 'x; // Propagate X;
                        endcase

                        // Processor does Rn - Rm.

                        // Rn
                        o_alu_source            = {29'd0, instruction[3:0]};
                        o_alu_source[32]        = INDEX_EN;

                        // Rm
                        o_shift_source          = {29'd0, instruction[19:16]};
                        o_shift_source[32]      = INDEX_EN;

                        // Rs
                        o_shift_operation       = LSL_SAT;
                        o_shift_length          = 1;
                        o_shift_length[32]      = IMMED_EN;

                        // Destination index.
                        o_destination_index     = {1'd0, instruction[15:12]};
                end



                CLZ_INSTRUCTION:
                begin: tskDecodeClz
                        o_condition_code        =       instruction[31:28];
                        o_flag_update           =       1'd0; // Instruction does not update any flags.
                        o_alu_operation         =       {1'd0, CLZ};

                        // Rn = 0.
                        o_alu_source            =       33'd0;
                        o_alu_source[32]        =       IMMED_EN;

                        // Rm = register whose CLZ must be found.
                        o_shift_source          =       {28'd0, instruction[ZAP_DP_RB_EXTEND], instruction[`ZAP_DP_RB]}; // Rm
                        o_shift_source[32]      =       INDEX_EN;
                        o_shift_operation       =       {1'd0, LSL};
                        o_shift_length          =       33'd0;
                        o_shift_length[32]      =       IMMED_EN; // Shift length is 0 of course.

                        assert(o_shift_source != 'd15) else
                        $info("Warning: CLZ with source R15 is unpredictable.");

                        // Destination index.
                        o_destination_index     =       {1'd0, instruction[15:12]};

                        assert(o_destination_index != 'd15) else
                        $info("Warning: CLZ to destination R15 is unpredictable.");
                end


                BX_INST:
                begin: tskDecodeBx
                        logic [32:0] temp;

                        temp       = {1'd0, instruction[31:0]};
                        temp[31:4] = 0; // Zero out stuff to avoid conflicts in the function.

                        `zap_process_instruction_specified_shift(temp);

                        // Ensure R is not PC.
                        assert(temp[3:0] != 'd15) else
                        $info(2, "Warning: PC as a source is UNPREDICTABLE for BX.");

                        // The RAW ALU source does not matter.
                        o_condition_code        = instruction[31:28];
                        o_alu_operation         = {2'd0, MOV};
                        o_destination_index     = {1'd0, ARCH_PC};

                        // We will force an immediate in alu source to prevent unwanted locks.
                        o_alu_source            = 0;
                        o_alu_source[32]        = IMMED_EN;

                        // Indicate switch. This is a primary differentiator. The actual
                        // switch happens only if the target LSB = 0 (ALU output).
                        o_switch = 1;
                end


                MRS:
                begin

                        `zap_process_immediate({instruction[11:0]});

                        o_condition_code    = instruction[31:28];
                        o_destination_index = {instruction[ZAP_DP_RD_EXTEND], instruction[`ZAP_DP_RD]};
                        o_alu_source[4:0]   = instruction[22] ? ARCH_CURR_SPSR : ARCH_CPSR;
                        o_alu_source[32]    = INDEX_EN;
                        o_alu_operation     = instruction[22] ? {2'd0, ADD} : FADD;
                end


                MSR,MSR_IMMEDIATE:
                begin

                        if ( instruction[25] ) // Immediate present.
                        begin
                                `zap_process_immediate({instruction[11:0]});
                        end
                        else
                        begin
                                `zap_process_instruction_specified_shift({21'd0, instruction[11:0]});
                        end

                        // Destination.
                        o_destination_index = instruction[22] ? ARCH_CURR_SPSR : ARCH_CPSR;

                        // Set flag update=1 for CPSR updates.
                        o_flag_update = instruction[22] ? 1'd0 : 1'd1;

                        o_condition_code = instruction[31:28];

                        // Make srcdest as SPSR. useful for MMOV.
                        o_mem_srcdest_index = ARCH_CURR_SPSR;

                        // Select SPSR or CPSR.
                        o_alu_operation  = instruction[22] ? {1'd0, MMOV} : {1'd0, FMOV};

                        o_alu_source     = {29'd0, instruction[19:16]};
                        o_alu_source[32] = IMMED_EN;
                end



                DATA_PROCESSING_IMMEDIATE,
                DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT,
                DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT:
                begin
                        o_condition_code        = instruction[31:28];
                        o_alu_operation         = {2'd0, instruction[24:21]};
                        o_flag_update           = instruction[20];
                        o_destination_index     = {instruction[ZAP_DP_RD_EXTEND], instruction[`ZAP_DP_RD]};
                        o_alu_source            = {29'd0, instruction[`ZAP_DP_RA]};
                        o_alu_source[32]        = INDEX_EN;
                        o_mem_srcdest_index     = ARCH_CURR_SPSR;

                        if (    o_alu_operation == {2'd0, CMP} ||
                                o_alu_operation == {2'd0, CMN} ||
                                o_alu_operation == {2'd0, TST} ||
                                o_alu_operation == {2'd0, TEQ} )
                        begin
                                o_destination_index = RAZ_REGISTER;
                        end

                        casez ( {instruction[25],instruction[7],instruction[4]} )
                        3'b1??:
                        begin
                            `zap_process_immediate(instruction[11:0]);
                        end
                        3'b0?0:
                        begin
                            `zap_process_instruction_specified_shift(instruction[32:0]);
                        end
                        3'b001:
                        begin
                            o_shift_length          = {29'd0, instruction[11:8]};
                            o_shift_length[32]      = INDEX_EN;
                            o_shift_source          = {28'd0, instruction[ZAP_DP_RB_EXTEND], instruction[`ZAP_DP_RB]};
                            o_shift_source[32]      = INDEX_EN;
                            o_shift_operation       = {1'd0, instruction[6:5]};

                            assert(o_shift_length != 'd15) else
                            $info("Warning: Using PC here as a source to specify shift length is UNPREDICTABLE.");

                            assert(o_shift_source != 'd15) else
                            $info("Warning: Using PC here as a source to specify shift source is UNPREDICTABLE.");
                        end
                        default:
                        begin
                                // Cannot happen. Synthesis will OPTIMIZE. OK to do for FPGA synth.
                                {o_condition_code,o_alu_operation,o_flag_update,
                                 o_destination_index,o_alu_source, o_mem_srcdest_index} = 'x;
                        end
                        endcase
                end


                BRANCH_INSTRUCTION:
                begin
                        // A branch is decayed into PC = PC + $signed(immed)
                        o_condition_code        = instruction[31:28];
                        o_alu_operation         = {2'd0, ADD};
                        o_destination_index     = {1'd0, ARCH_PC};
                        o_alu_source            = {29'd0, ARCH_PC};
                        o_alu_source[32]        = INDEX_EN;
                        o_shift_source[31:0]    = ($signed({{8{instruction[23]}},instruction[23:0]}));
                        o_shift_source[32]      = IMMED_EN;
                        o_shift_operation       = {1'd0, LSL};
                        o_shift_length          = instruction[34] ? 1 : 2; // mode16 branches sometimes need only a shift of 1.
                        o_shift_length[32]      = IMMED_EN;
                end


                LS_INSTRUCTION_SPECIFIED_SHIFT,
                LS_IMMEDIATE:
                begin: tskDecodeLs


                        o_condition_code = instruction[31:28];

                        if ( !instruction[25] ) // immediate
                        begin
                                o_shift_source          = {21'd0, instruction[11:0]};
                                o_shift_source[32]      = IMMED_EN;
                                o_shift_length          = 0;
                                o_shift_length[32]      = IMMED_EN;
                                o_shift_operation       = {1'd0, LSL};
                        end
                        else
                        begin
                              `zap_process_instruction_specified_shift({21'd0, instruction[11:0]});

                              assert ( instruction [3:0] != 'd15 ) else
                                $info("Warning: Use of PC as Rm in LDR/STR with ISS is UNPREDICTABLE.");
                        end

                        o_alu_operation = instruction[23] ? {2'd0, ADD} : {2'd0, SUB};

                        // Pointer register.
                        o_alu_source    = {28'd0, instruction[ZAP_BASE_EXTEND], instruction[`ZAP_BASE]};
                        o_alu_source[32] = INDEX_EN;
                        o_mem_load          = instruction[20];
                        o_mem_store         = !o_mem_load;
                        o_mem_pre_index     = instruction[24];

                        assert(~(o_mem_store && o_alu_source[31:0] == 'd15 && o_alu_source[32] == INDEX_EN &&
                                 i_instruction_valid)) else
                        $info("Warning: Use of PC as a pointer for STR is IMPLEMENTATION DEFINED (PC + 8). Instruction=%x", instruction);

                        // If post-index is used or pre-index is used with writeback,
                        // take is as a request to update the base register.
                        o_destination_index = (instruction[21] || !o_mem_pre_index) ?
                                                o_alu_source[4:0] :
                                                RAZ_REGISTER; // Pointer register already added.
                        o_mem_unsigned_byte_enable = instruction[22];

                        o_mem_srcdest_index = {instruction[ZAP_SRCDEST_EXTEND], instruction[`ZAP_SRCDEST]};

                        assert ( ~(o_mem_load && o_mem_srcdest_index == 'd15) ) else
                                $info("Warning: Use of PC as a source reg of STORE is UNPREDICTABLE.");

                        if ( !o_mem_pre_index ) // Post-index, writeback has no meaning.
                        begin
                                if ( instruction[21] )
                                begin
                                        // Use it for force usr mode memory mappings.
                                        o_mem_translate = 1'd1;
                                end
                        end
                end


                MULT_INST:
                begin: tskDecodeMult


                        o_condition_code        =       instruction[31:28];
                        o_flag_update           =       instruction[20];
                        o_alu_operation         =       {1'd0, UMLALL};
                        o_destination_index     =       {instruction[ZAP_DP_RD_EXTEND],
                                                         instruction[19:16]};

                        // For MUL, Rd and Rn are interchanged.
                        o_alu_source            =       {29'd0, instruction[11:8]}; // mode32 rs
                        o_alu_source[32]        =       INDEX_EN;

                        o_shift_source          =       {28'd0, instruction[ZAP_DP_RB_EXTEND],
                                                         instruction[`ZAP_DP_RB]};
                        o_shift_source[32]      =       INDEX_EN;            // mode32 rm

                        // mode32 rn - Set for accumulate.
                        o_shift_length          =       instruction[21] ?
                                                        {28'd0, instruction[ZAP_DP_RA_EXTEND],
                                                         instruction[`ZAP_DP_RD]} : 33'd0;

                        o_shift_length[32]      =       instruction[21] ? INDEX_EN : IMMED_EN;

                        // Set rh = 0.
                        o_mem_srcdest_index = RAZ_REGISTER;
                end


                LMULT_INST:
                begin: tskLDecodeMult

                        o_condition_code        =       instruction[31:28];
                        o_flag_update           =       instruction[20];

                        // mode32 rd.
                        o_destination_index     =       {instruction[ZAP_DP_RD_EXTEND],
                                                         instruction[19:16]};

                        // For MUL, Rd and Rn are interchanged.
                        // For 64bit, this is normally high register.

                        o_alu_source            =       {29'd0, instruction[11:8]}; // mode32 rs
                        o_alu_source[32]        =       INDEX_EN;

                        o_shift_source          =       {28'd0, instruction[ZAP_DP_RB_EXTEND],
                                                         instruction[`ZAP_DP_RB]};
                        o_shift_source[32]      =       INDEX_EN;            // mode32 rm

                        // mode32 rn
                        o_shift_length          =       {28'd0, instruction[ZAP_DP_RA_EXTEND],
                                                         instruction[`ZAP_DP_RD]};

                        o_shift_length[32]      =       INDEX_EN;


                        // We need to generate output code.
                        case ( instruction[22:21] )

                        2'b00:
                        begin
                                // Unsigned MULT64
                                o_alu_operation = {1'd0, UMLALH};
                                o_mem_srcdest_index = RAZ_REGISTER; // rh.
                                o_shift_length      = '0;
                                o_shift_length[32]  = IMMED_EN; // rn
                        end

                        2'b01:
                        begin
                                // Unsigned MAC64. Need mem_srcdest as source for RdHi.
                                o_alu_operation = {1'd0, UMLALH};
                                o_mem_srcdest_index = {1'd0, instruction[19:16]};
                        end

                        2'b10:
                        begin
                                // Signed MULT64
                                o_alu_operation = {1'd0, SMLALH};
                                o_mem_srcdest_index = RAZ_REGISTER; // rh
                                o_shift_length = '0;
                                o_shift_length[32] = IMMED_EN; // rn
                        end

                        2'b11:
                        begin
                                // Signed MAC64. Need mem_srcdest as source of RdHi.
                                o_alu_operation = {1'd0, SMLALH};
                                o_mem_srcdest_index = {1'd0, instruction[19:16]};
                        end

                        default: // Propagate X.
                        begin
                                o_alu_operation = 'x;
                                o_mem_srcdest_index = 'x;
                        end

                        endcase

                        if ( instruction[ZAP_OPCODE_EXTEND] == 1'd0 )
                        // Low request - change destination index.
                        begin
                                        o_destination_index = {1'd0, instruction[15:12]}; // Low register.
                                        o_alu_operation[0]  = 1'd0;                       // Request low operation.
                        end
                end


                HALFWORD_LS:
                begin: tskDecodeHalfWordLs
                        logic [11:0] temp, temp1;

                        temp  = instruction[11:0];
                        temp1 = instruction[11:0];

                        o_condition_code = instruction[31:28];

                        temp[7:4]   = temp[11:8];
                        temp[11:8]  = 4'd0;
                        temp1[11:4] = 8'd0;

                        if ( instruction[22] ) // immediate
                        begin
                                `zap_process_immediate({temp});
                        end
                        else
                        begin
                                `zap_process_instruction_specified_shift ( {21'd0, temp1} );
                        end

                        o_alu_operation     = instruction[23] ? {2'd0, ADD} : {2'd0, SUB};
                        o_alu_source        = { 28'd0, instruction[ZAP_BASE_EXTEND],
                                                instruction[`ZAP_BASE]}; // Pointer register.
                        o_alu_source[32]    = INDEX_EN;
                        o_mem_load          = instruction[20];
                        o_mem_store         = !o_mem_load;
                        o_mem_pre_index     = instruction[24];

                        //
                        // If post-index is used or pre-index is used with writeback,
                        // take is as a request to update the base register.
                        //
                        o_destination_index = (instruction[21] || !o_mem_pre_index) ?
                                                o_alu_source[4:0] :
                                                RAZ_REGISTER; // Pointer register already added.

                        o_mem_srcdest_index = {instruction[ZAP_SRCDEST_EXTEND],
                                               instruction[`ZAP_SRCDEST]};

                        // Transfer size.

                        case ( instruction[6:5] )
                        SIGNED_BYTE:            o_mem_signed_byte_enable       = 1'd1;
                        UNSIGNED_HALF_WORD:     o_mem_unsigned_halfword_enable = 1'd1;
                        SIGNED_HALF_WORD:       o_mem_signed_halfword_enable   = 1'd1;
                        default:
                        begin
                                o_mem_signed_byte_enable        = 1'd0;
                                o_mem_unsigned_halfword_enable  = 1'd0;
                                o_mem_signed_halfword_enable    = 1'd0;
                        end
                        endcase

                        assert(~(o_mem_load == 0 && instruction[6] == 1)) else
                               $info("Warning: UNPREDICTABLE behavior of halfword LD/ST instruction=%x",
                                instruction[31:0]);
                end


                SOFTWARE_INTERRUPT:
                begin: tskDecodeSWI

                        // Generate LR = PC - 4
                        o_condition_code    = instruction[31:28];
                        o_alu_operation     = {2'd0, SUB};
                        o_alu_source        = {29'd0, ARCH_PC};
                        o_alu_source[32]    = INDEX_EN;
                        o_destination_index = {1'd0, ARCH_LR};
                        o_shift_source      = 33'd4;
                        o_shift_source[32]  = IMMED_EN;
                        o_shift_operation   = {1'd0, LSL};
                        o_shift_length      = 33'd0;
                        o_shift_length[32]  = IMMED_EN;
                end



               default: // Raise undefined exception.
               begin
                    // Say instruction is undefined.
                    o_und = 1'd1;

                    // Generate LR = PC - 4
                    o_condition_code    = AL;
                    o_alu_operation     = {2'd0, SUB};
                    o_alu_source        = {29'd0, ARCH_PC};
                    o_alu_source[32]    = INDEX_EN;
                    o_destination_index = {1'd0, ARCH_LR};
                    o_shift_source      = 33'd4;
                    o_shift_source[32]  = IMMED_EN;
                    o_shift_operation   = {1'd0, LSL};
                    o_shift_length      = 33'd0;
                    o_shift_length[32]  = IMMED_EN;

            end
            endcase

            // Always ~(ROR #0)
            assert ( !(o_shift_operation      == RORI &&
                       o_shift_length[31:0]   == 0    &&
                       o_shift_length[32]     == IMMED_EN) )
            else
            begin
                    $fatal(2, "Error: RORI #0 propagating out of decode.");
            end
    end
end

endmodule : zap_decode

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
