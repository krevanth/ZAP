///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (C) 2016,2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
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
// fields.vh
//
// Summary --
// Fields for decode of instructions (32-bit).
//
// Detail --
// This file contains defines for instruction fields within a 32-bit word.
// Used in the decode stage to generate control signals.
//

///////////////////////////////////////////////////////////////////////////////

`ifndef __FIELDS_VH__
`define __FIELDS_VH__

`define BASE_EXTEND             33      // Base address register for MEMOPS.
`define BASE                    19:16   // Base address extend.

`define SRCDEST_EXTEND          32      // Data Src/Dest extend register for MEMOPS.
`define SRCDEST                 15:12   // Data src/dest register MEMOPS.

`define DP_RD_EXTEND            33      // Destination source extend.
`define DP_RD                   15:12   // Destination source.

`define DP_RS_EXTEND            32      // Shift source extend.
`define DP_RS                   3:0     // Shift source. ARM refers to this as rm.

`define DP_RN                   19:16   // ALU source.
`define DP_RN_EXTEND            34      // ALU source extend.

`define OPCODE_EXTEND           35      // To differentiate lower and higher -> 
                                        // 1 means higher, 0 lower.
`endif

///////////////////////////////////////////////////////////////////////////////
