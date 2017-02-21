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
// instruction_patterns.vh
//
// Summary --
// Instruction decode patterns.
//
// Detail --
// Instruction patterns used in instruction decode. Use casez in RTL when
// using these definitions since ? is used.
//

///////////////////////////////////////////////////////////////////////////////

/* ARM */

localparam      [31:0]  DATA_PROCESSING_IMMEDIATE                       =                                       32'b????_00_1_????_?_????_????_????????????;
localparam      [31:0]  DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT        =                                       32'b????_00_0_????_?_????_????_????0??1????;
localparam      [31:0]  DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT     =                                       32'b????_00_0_????_?_????_????_???????0????;       

// BL never reaches the unit.
localparam      [31:0]  BRANCH_INSTRUCTION                              =                                       32'b????_101?_????_????_????_????_????_????;

localparam      [31:0]  MRS                                             =                                       32'b????_00010_?_001111_????_????_????_????;
localparam      [31:0]  MSR_IMMEDIATE                                   =                                       32'b????_00_1_10?10_????_1111_????_????_????;

localparam      [31:0]  MSR                                             =                                       32'b????_00_0_10?10_????_1111_????_????_????;

localparam      [31:0]  LS_INSTRUCTION_SPECIFIED_SHIFT                  =                                       32'b????_01_1_?????_????_????_????_????_????; 
localparam      [31:0]  LS_IMMEDIATE                                    =                                       32'b????_01_0_?????_????_????_????_????_????;

localparam      [31:0]  BX_INST                                         =                                       32'b????_0001_0010_1111_1111_1111_0001_????;

localparam      [31:0]  MULT_INST                                       =                                       32'b????_0000_00?_?_????_????_????_1001_????;

// M MULT INST - UMULL, UMLAL, SMULL, SMLAL.
localparam      [31:0]  LMULT_INST                                      =                                       32'b????_0000_1??_?_????_????_????_1001_????;

// Halfword memory.
localparam      [31:0]  HALFWORD_LS                                     =                                       32'b????_000_?????_????_????_????_1??1_????;

// Software interrupt.
localparam      [31:0]  SOFTWARE_INTERRUPT                              =                                       32'b????_1111_????_????_????_????_????_????;

// Swap.
localparam      [31:0]  SWAP                                            =                                       32'b????_00010_?_00_????_????_00001001_????;

// Write to coprocessor.
localparam      [31:0]  MCR                                             =                                       32'b????_1110_???_0_????_????_1111_???_1_????;        

// Read from coprocessor.
localparam      [31:0]  MRC                                             =                                       32'b????_1110_???_1_????_????_1111_???_1_????;

// LDC, STC
localparam      [31:0]  LDC                                             =                                       32'b????_110_????1_????_????_????_????????;
localparam      [31:0]  STC                                             =                                       32'b????_110_????0_????_????_????_????????;

// CDP
localparam      [31:0]  CDP                                             =                                       32'b????_1110_????????_????????_????????;

///////////////////////////////////////////////////////////////////////////////

/* COMPRESSED ( Not THUMB! THIS IS NOT COMPATIBLE WITH THE THUMB(R) ISA. ) */

//B
localparam      [15:0]  T_BRANCH_COND                                   =                                       16'b1101_????_????????;
localparam      [15:0]  T_BRANCH_NOCOND                                 =                                       16'b11100_???????????;
localparam      [15:0]  T_BL                                            =                                       16'b1111_?_???????????;
localparam      [15:0]  T_BX                                            =                                       16'b01000111_0_?_???_000;

// SWI
localparam      [15:0]  T_SWI                                           =                                       16'b11011111_????????;

// Shifts.
localparam      [15:0]  T_SHIFT                                         =                                       16'b000_??_?????_???_???;

// Add sub LO.
localparam      [15:0]  T_ADD_SUB_LO                                    =                                       16'b00011_?_?_???_???_???;

// MCAS Imm.
localparam      [15:0]  T_MCAS_IMM                                      =                                       16'b001_??_???_????????;

// ALU Lo.
localparam      [15:0]  T_ALU_LO                                        =                                       16'b010000_????_???_???;

// ALU hi.
localparam      [15:0]  T_ALU_HI                                        =                                       16'b010001_??_?_?_???_???;

// *Get address.
localparam      [15:0]  T_GET_ADDR                                      =                                       16'b1010_?_???_????????;

// *Add offset to SP.
localparam      [15:0]  T_MOD_SP                                        =                                       16'b10110000_?_????_???;

// PC relative load.
localparam      [15:0]  T_PC_REL_LOAD                                   =                                       16'b01001_???_????????;

// LDR_STR_5BIT_OFF
localparam      [15:0] T_LDR_STR_5BIT_OFF                               =                                       16'b011_?_?_?????_???_???;

// LDRH_STRH_5BIT_OFF
localparam      [15:0] T_LDRH_STRH_5BIT_OFF                             =                                       16'b1000_?_?????_???_???;

// Signed LDR/STR
localparam      [15:0]  T_LDRH_STRH_REG                                 =                                       16'b0101_???_???_???_???;

// SP relative LDR/STR
localparam      [15:0]  T_SP_REL_LDR_STR                                =                                       16'b1001_?_???_????????;

// LDMIA/STMIA
localparam      [15:0]  T_LDMIA_STMIA                                   =                                       16'b1100_?_???_????????;

// PUSH POP
localparam      [15:0]  T_POP_PUSH                                      =                                       16'b1011_?_10_?_????????;

///////////////////////////////////////////////////////////////////////////////
