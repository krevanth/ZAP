///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
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
// opcodes.vh
//
// Summary --
// This file lists the ALU opcodes.
//

///////////////////////////////////////////////////////////////////////////////

//
// Standard opcodes.
// These map to the opcode map in the spec.
//
parameter [3:0] AND   = 0;
parameter [3:0] EOR   = 1;
parameter [3:0] SUB   = 2;
parameter [3:0] RSB   = 3;
parameter [3:0] ADD   = 4;
parameter [3:0] ADC   = 5;
parameter [3:0] SBC   = 6;
parameter [3:0] RSC   = 7;
parameter [3:0] TST   = 8;
parameter [3:0] TEQ   = 9;
parameter [3:0] CMP   = 10;
parameter [3:0] CMN   = 11;
parameter [3:0] ORR   = 12;
parameter [3:0] MOV   = 13;
parameter [3:0] BIC   = 14;
parameter [3:0] MVN   = 15;

//
// Internal opcodes used to 
// implement some instructions.
//
parameter [4:0] MUL   = 16; // Multiply ( 32 x 32 = 32 ) -> Translated to MAC.
parameter [4:0] MLA   = 17; // Multiply-Accumulate ( 32 x 32 + 32 = 32 ). 

//
// Flag MOV. Will write upper 4-bits to flags if mask bit [3] is set to 1. 
// Also writes to target register similarly. 
// Mask bit comes from non-shift operand.
//
parameter [4:0] FMOV  = 18; 

//
// Same as FMOV but does not touch the flags in the ALU. This is MASK MOV. 
// Set to 1 will update, 0 will not 
// (0000 -> No updates, 0001 -> [7:0] update) and so on.
//
parameter [4:0] MMOV  = 19; 

parameter [4:0] UMLALL = 20; // Unsigned multiply accumulate (Write lower reg).
parameter [4:0] UMLALH = 21;

parameter [4:0] SMLALL = 22; // Signed multiply accumulate (Write lower reg).
parameter [4:0] SMLALH = 23;

parameter [4:0] CLZ    = 24; // Count Leading zeros.

///////////////////////////////////////////////////////////////////////////////
