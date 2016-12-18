/*
MIT License

Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

// ===============================
// Architectural Registers.
// ===============================
parameter [3:0] ARCH_SP   = 13;
parameter [3:0] ARCH_LR   = 14;
parameter [3:0] ARCH_PC   = 15;
parameter RAZ_REGISTER    = 16; // Serves as $0 does on MIPS.

// These always point to user registers irrespective of mode.
parameter ARCH_USR2_R8    = 18; 
parameter ARCH_USR2_R9    = 19;
parameter ARCH_USR2_R10   = 20;
parameter ARCH_USR2_R11   = 21;
parameter ARCH_USR2_R12   = 22;
parameter ARCH_USR2_R13   = 23;
parameter ARCH_USR2_R14   = 24;

// Dummy architectural registers.
parameter ARCH_DUMMY_REG0 = 25;
parameter ARCH_DUMMY_REG1 = 26;

// CPSR and SPSR.
parameter ARCH_CPSR       = 17;
parameter ARCH_CURR_SPSR  = 27; // Alias to real SPSR.

// Total architectural registers.
parameter TOTAL_ARCH_REGS = 28;

// ===============================
// Physical registers.
// ===============================
parameter  PHY_PC               =       15; // DO NOT CHANGE!
parameter  PHY_RAZ_REGISTER     =       16; // DO NOT CHANGE!
parameter  PHY_CPSR             =       17; // DO NOT CHANGE!

parameter  PHY_USR_R0           =       0;
parameter  PHY_USR_R1           =       1;
parameter  PHY_USR_R2           =       2;
parameter  PHY_USR_R3           =       3;
parameter  PHY_USR_R4           =       4;
parameter  PHY_USR_R5           =       5;
parameter  PHY_USR_R6           =       6;
parameter  PHY_USR_R7           =       7;
parameter  PHY_USR_R8           =       8;
parameter  PHY_USR_R9           =       9;
parameter  PHY_USR_R10          =       10;
parameter  PHY_USR_R11          =       11;
parameter  PHY_USR_R12          =       12;
parameter  PHY_USR_R13          =       13;
parameter  PHY_USR_R14          =       14;

parameter  PHY_FIQ_R8           =       18;
parameter  PHY_FIQ_R9           =       19;
parameter  PHY_FIQ_R10          =       20;
parameter  PHY_FIQ_R11          =       21;
parameter  PHY_FIQ_R12          =       22;
parameter  PHY_FIQ_R13          =       23;
parameter  PHY_FIQ_R14          =       24;

parameter  PHY_IRQ_R13          =       25;
parameter  PHY_IRQ_R14          =       26;

parameter  PHY_SVC_R13          =       27;
parameter  PHY_SVC_R14          =       28;

parameter  PHY_UND_R13          =       29;
parameter  PHY_UND_R14          =       30;

parameter  PHY_ABT_R13          =       31;
parameter  PHY_ABT_R14          =       32;     

// Dummy registers for various purposes.
parameter  PHY_DUMMY_REG0       =       33;
parameter  PHY_DUMMY_REG1       =       34;

// SPSRs.
parameter  PHY_FIQ_SPSR         =       35;
parameter  PHY_IRQ_SPSR         =       36;
parameter  PHY_SVC_SPSR         =       37;
parameter  PHY_UND_SPSR         =       38;
parameter  PHY_ABT_SPSR         =       39;
parameter  PHY_SWI_SPSR         =       40;

// Count of total registers (Can go up to 64 with no problems).
parameter  TOTAL_PHY_REGS       =       41;

