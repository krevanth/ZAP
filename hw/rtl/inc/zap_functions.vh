// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_functions.vh
// HDL          : Verilog-2001
// Module       : --
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// Contains definitions of a set of useful functions.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : --
// Clock        : --
// Depends      : --        
// ----------------------------------------------------------------------------

//
// Function to model a 16-bit priority encoder.
//

// Priority encoder.
function [3:0] pri_enc ( input [15:0] in );
begin: priEncFn
                casez ( in )
                16'b????_????_????_???1: pri_enc = 4'd0;
                16'b????_????_????_??10: pri_enc = 4'd1;
                16'b????_????_????_?100: pri_enc = 4'd2;
                16'b????_????_????_1000: pri_enc = 4'd3;
                16'b????_????_???1_0000: pri_enc = 4'd4;
                16'b????_????_??10_0000: pri_enc = 4'd5;
                16'b????_????_?100_0000: pri_enc = 4'd6;
                16'b????_????_1000_0000: pri_enc = 4'd7;
                16'b????_???1_0000_0000: pri_enc = 4'd8;
                16'b????_??10_0000_0000: pri_enc = 4'd9;
                16'b????_?100_0000_0000: pri_enc = 4'hA;
                16'b????_1000_0000_0000: pri_enc = 4'hB;
                16'b???1_0000_0000_0000: pri_enc = 4'hC;
                16'b??10_0000_0000_0000: pri_enc = 4'hD;
                16'b?100_0000_0000_0000: pri_enc = 4'hE;
                16'b1000_0000_0000_0000: pri_enc = 4'hF;
                default:                 pri_enc = 4'h0;
                endcase
end
endfunction

// ----------------------------------------------------------------------------

//
// Function to generate clog2. Unused. $clog2 used instead.
//
function [31:0] zap_clog2 ( input [31:0] x );
for(zap_clog2 = 0 ; 2**zap_clog2 < x ; zap_clog2 = zap_clog2 + 1);
endfunction

// ----------------------------------------------------------------------------

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

// ----------------------------------------------------------------------------

// Counts the number of ones and multiplies that by 4 to get final
// address offset.
//
function [11:0] ones_counter (
        input [15:0]    i_word    // Register list.
);
begin: blk1
        integer i;
        reg [11:0] offset;

        offset = 0;

        // Counter number of ones.
        for(i=0;i<16;i=i+1)
                offset = offset + i_word[i];

        // Since LDM and STM occur only on 4 byte regions, compute the
        // net offset.
        offset = (offset << 2); // Multiply by 4.

        ones_counter = offset;
end
endfunction

// ----------------------------------------------------------------------------

// 
// Translate function.
// 
//
// Used to implement ARM modes. The register file is basically a flat array
// of registers. Based on mode, we select some of those to implement banking.
//

function [5:0] translate (
 
        input [5:0] index,      // Requested instruction index.
        input [4:0] cpu_mode    // Current CPU mode.

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

// ----------------------------------------------------------------------------

function [31:0] adapt_cache_data ( input [1:0] shift, input [127:0] cd);
begin: blk1
        reg [31:0] shamt;
        shamt = shift << 5;
        adapt_cache_data = cd >> shamt;
end
endfunction


