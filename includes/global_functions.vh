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
// functions.vh
//
// Summary --
// This file contains 2 functions used by the processor in several modules.
//
// Detail --
// Contains functions:
// translate()
// is_cc_satisfied()
//

///////////////////////////////////////////////////////////////////////////////

// 
// Translate function.
// 
//
// Used to implement ARM modes. The register file is basically a flat array
// of registers. Based on mode, we select some of those to implement banking.
//

function [$clog2(PHY_REGS)-1:0] translate (
 
        input [$clog2(PHY_REGS)-1:0] index, // Requested instruction index.
        input [4:0] cpu_mode                // Current CPU mode.

);
begin
        translate = index; // Avoid latch inference.

        // User/System mode assignments.
        case ( index )
                      0:      translate = PHY_USR_R0; 
                      1:      translate = PHY_USR_R1;                            
                      2:      translate = PHY_USR_R2; 
                      3:      translate = PHY_USR_R3;
                      4:      translate = PHY_USR_R4;
                      5:      translate = PHY_USR_R5;
                      6:      translate = PHY_USR_R6;
                      7:      translate = PHY_USR_R7;
                      8:      translate = PHY_USR_R8;
                      9:      translate = PHY_USR_R9;
                      10:     translate = PHY_USR_R10;
                      11:     translate = PHY_USR_R11;
                      12:     translate = PHY_USR_R12;
                      13:     translate = PHY_USR_R13;
                      14:     translate = PHY_USR_R14;
                      15:     translate = PHY_PC;

            RAZ_REGISTER:     translate = PHY_RAZ_REGISTER;
               ARCH_CPSR:     translate = PHY_CPSR;
          ARCH_CURR_SPSR:     translate = PHY_CPSR;

              // USR2 registers are looped back to USER registers.
              ARCH_USR2_R8:   translate = PHY_USR_R8;
              ARCH_USR2_R9:   translate = PHY_USR_R9;
              ARCH_USR2_R10:  translate = PHY_USR_R10;
              ARCH_USR2_R11:  translate = PHY_USR_R11;
              ARCH_USR2_R12:  translate = PHY_USR_R12;
              ARCH_USR2_R13:  translate = PHY_USR_R13;
              ARCH_USR2_R14:  translate = PHY_USR_R14;

              ARCH_DUMMY_REG0:translate = PHY_DUMMY_REG0;
              ARCH_DUMMY_REG1:translate = PHY_DUMMY_REG1;
        endcase

        // Override per specific mode.
        case ( cpu_mode )
                FIQ:
                begin
                        case ( index )
                                8:      translate = PHY_FIQ_R8;
                                9:      translate = PHY_FIQ_R9;
                                10:     translate = PHY_FIQ_R10;
                                11:     translate = PHY_FIQ_R11;
                                12:     translate = PHY_FIQ_R12;
                                13:     translate = PHY_FIQ_R13;
                                14:     translate = PHY_FIQ_R14;
                    ARCH_CURR_SPSR:     translate = PHY_FIQ_SPSR;
                        endcase
                end

                IRQ:
                begin
                        case ( index )
                                13:     translate = PHY_IRQ_R13;
                                14:     translate = PHY_IRQ_R14;
                    ARCH_CURR_SPSR:     translate = PHY_IRQ_SPSR;
                        endcase
                end

                ABT:
                begin
                        case ( index )
                                13:     translate = PHY_ABT_R13;
                                14:     translate = PHY_ABT_R14;
                    ARCH_CURR_SPSR:     translate = PHY_ABT_SPSR;
                        endcase
                end

                UND:
                begin
                        case ( index )
                                13:     translate = PHY_UND_R13;
                                14:     translate = PHY_UND_R14;
                    ARCH_CURR_SPSR:     translate = PHY_UND_SPSR;
                        endcase
                end

                SVC:
                begin
                        case ( index )
                                13:     translate = PHY_SVC_R13;
                                14:     translate = PHY_SVC_R14;
                    ARCH_CURR_SPSR:     translate = PHY_SVC_SPSR;
                        endcase
                end
        endcase
end
endfunction

///////////////////////////////////////////////////////////////////////////////

//
// Function to check if condition is satisfied for instruction
// execution. Returns 1 if satisfied, 0 if not.
//

function is_cc_satisfied 
( 
        input [3:0] cc,         // 31:28 of the instruction. 
        input [3:0] fl          // CPSR flags.
);
reg ok,n,z,c,v;
begin: blk1
        {n,z,c,v} = fl;

        case(cc)
        EQ:     ok =  z;
        NE:     ok = !z;
        CS:     ok = c;
        CC:     ok = !c;
        MI:     ok = n;
        PL:     ok = !n;
        VS:     ok = v;
        VC:     ok = !v;
        HI:     ok = c && !z;
        LS:     ok = !c || z;
        GE:     ok = (n == v);
        LT:     ok = (n != v);
        GT:     ok = (n == v) && !z;
        LE:     ok = (n != v) || z;
        AL:     ok = 1'd1;
        NV:     ok = 1'd0;                    
        endcase   

        is_cc_satisfied = ok;
end
endfunction

///////////////////////////////////////////////////////////////////////////////
