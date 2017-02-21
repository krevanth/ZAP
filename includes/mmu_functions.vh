///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (C) 2016, 2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
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
// MMU functions.
//
// Detail --
// This file defines a set of functions used by the memory management unit
// of the ZAP processor. Basically these functions validate memory accesses.
//

///////////////////////////////////////////////////////////////////////////////

//
// Function returns 8-bit non zero section FSR. 
// A return value of 0 means all is well.
//
//
// This function generation a section fault status register entry. An FSR
// of 0 means that access may proceed else the access is prohibited. Note
// that FSR 0 as defined in the ARMv4 spec is unused in this implementation
// and is resued  to mean all OK. Since the FSR is not updated on a good
// access, that's okay to do.
//

function [7:0] section_fsr (

        input           user,           // User mode.
        input           rd,             // Read request.
        input           wr,             // Write request.        
        input [1:0]     sr,             // SR bits.
        input [31:0]    dac_reg,        // DAC register.
        input [SECTION_TLB_WDT-1:0] tlb // TLB entry.

);

reg [3:0] apsr; // Concat of AP and SR.
reg [1:0] dac;  // DAC bits.

begin // Function start

        apsr = {tlb[`SECTION_TLB__AP], sr};

        //
        // Get domain access control settings from the DAC register.
        // The domain access register is indexed into from the TLB entry.
        // With the index, the appropriate DAC bits can be gotten.
        //
        dac  = (dac_reg >> ( tlb[`SECTION_TLB__DAC_SEL] << 1 )); 

        //
        // Based on the DAC bits, we can have either client or manager.
        // Others are reserved in v4.
        //
        case (dac)
                // A manager can never fault.
                DAC_MANAGER: section_fsr = 0;

                // A client requires further checks of the AP and SR fields.
                DAC_CLIENT:  section_fsr = is_apsr_ok(user,rd,wr,apsr) ? 0 : 
                             {tlb[`SECTION_TLB__DAC_SEL], 
                              FSR_SECTION_PERMISSION_FAULT}; 

                // Reserved. No access. Always fail.
                default:     section_fsr = {tlb[`SECTION_TLB__DAC_SEL], 
                             FSR_SECTION_DOMAIN_FAULT};  // No acc, reserved.
        endcase

end

endfunction

///////////////////////////////////////////////////////////////////////////////

//
// Function returns 8-bit non zero small page FSR.
// A return value of 0 means all is well.
//
//
// This function generate a small page FSR entry. A return value of zero
// indicates that the access is permitted and no FSR update is done. The formal
// FSR=0 never occurs in this implementation and is thus reused to mean OKAY. 
//
function [7:0] spage_fsr (

input   [1:0]   ap_sel,         // Select one of 4 APs.
input           user,           // User mode.
input           rd,             // Read request.
input           wr,             // Write request.        
input [1:0]     sr,             // SR bits.
input [31:0]    dac_reg,        // DAC register.
input [SPAGE_TLB_WDT-1:0] tlb   // TLB entry.

);

reg [3:0] apsr; // Cat of AP and SR bits.
reg [1:0] dac;  // Domain access control bits.

begin

        // Build up APSR.
        apsr[3:2] = tlb[`SPAGE_TLB__AP] >> (ap_sel << 1);
        apsr[1:0] = sr;

        //
        // Get DAC bits by indexing into the DAC register by the index from
        // the TLB entry.
        //
        dac  = dac_reg >> ( tlb[`SPAGE_TLB__DAC_SEL] << 1 ); 

        // Based on DAC...
        case (dac)

                // Managers always have authority...
                DAC_MANAGER: spage_fsr = 0; // No fault.

                // Clients have to be checked against APSR.
                DAC_CLIENT:  spage_fsr = is_apsr_ok(user,rd,wr,apsr) ? 0 : 
                                         {tlb[`SPAGE_TLB__DAC_SEL], 
                                          FSR_PAGE_PERMISSION_FAULT}; // Check.

                // Undefined combos will lead to a failed access.
                default:     spage_fsr = {tlb[`SPAGE_TLB__DAC_SEL], 
                                          FSR_PAGE_DOMAIN_FAULT};    
        endcase
end
endfunction

///////////////////////////////////////////////////////////////////////////////

//
// Function returns 8-bit non zero FSR.
// A return of 0 means all is well and access can proceed.
//

function [7:0] lpage_fsr (
input   [1:0]   ap_sel,         // Select one of 4 APs.
input           user,           // User mode.
input           rd,             // Read request.
input           wr,             // Write request.        
input [1:0]     sr,             // SR bits.
input [31:0]    dac_reg,        // DAC register.
input [LPAGE_TLB_WDT-1:0] tlb // TLB entry.
);
reg [3:0] apsr; // Concat of AP and SR.
reg [1:0] dac;  // DAC bits.
begin

        // Build APSR.
        apsr[3:2] = tlb[`LPAGE_TLB__AP] >> (ap_sel << 1);
        apsr[1:0] = sr;

        //
        // Get DAC bits from DAC register by indexing using
        // TLB entry.
        //
        dac  = dac_reg >> ( tlb[`LPAGE_TLB__DAC_SEL] << 1 ); 

        case (dac)

                // Always allow.
                DAC_MANAGER: lpage_fsr = 0; // No fault.

                // Check APSR.
                DAC_CLIENT:  lpage_fsr = is_apsr_ok(user,rd,wr,apsr) ? 
                              0 : {tlb[`LPAGE_TLB__DAC_SEL], 
                              FSR_PAGE_PERMISSION_FAULT}; // Check perms.

                // Always fail.
                default:     lpage_fsr = 
                             {tlb[`LPAGE_TLB__DAC_SEL], FSR_PAGE_DOMAIN_FAULT};    
        endcase
end
endfunction

///////////////////////////////////////////////////////////////////////////////

// 
// Function to check APSR bits.
// 
// Returns 0 for failure, 1 for okay.
// Checks AP and SR bits.
//

localparam APSR_BAD = 1'd0;
localparam APSR_OK  = 1'd1;

function is_apsr_ok ( input user, input rd, input wr, input [3:0] apsr);
reg x;
begin
        x = APSR_BAD; // Assume fail.

        casez (apsr)
                APSR_NA_NA: x = APSR_BAD;       // No access.
                APSR_RO_RO: x = !wr;            // Reads allowed for all.
                APSR_RO_NA: x = !user && rd;    // Only kernel reads.
                APSR_RW_NA: x = !user;          // Only kernel access.
                APSR_RW_RO: x = !user | (user && rd); // User RO, Kernel RW.
                APSR_RW_RW: x = APSR_OK;  // Grant all the time.
                default   : x = APSR_BAD; // Deny all the time.
        endcase

        // Assign to function. Return.
        is_apsr_ok = x;
end
endfunction

///////////////////////////////////////////////////////////////////////////////
