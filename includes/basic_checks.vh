// Returns 1 if permissions check out. Also sets FSR.
function check_section_permissions (
input           user,           // User mode.
input           rd,             // Read request.
input           wr,             // Write request.        
input [1:0]     sr,             // SR bits.
input [31:0]    dac_reg,        // DAC register.
input [SECTION_TLB_WDT-1:0] tlb // TLB entry.
);
reg [3:0] apsr;
reg [1:0] dac;
begin
        fsr_nxt = 0;
        check_section_permissions = 1'd0; // Assume fail.

        apsr = {tlb[`SECTION_TLB__AP], sr};
        dac  = (dac_reg >> ( tlb[`SECTION_TLB__DAC_SEL] << 1 )); 

        case (dac)

        DAC_MANAGER:
        begin
                // Grant permissions - no fuss at all.
                check_section_permissions = 1'd1;

                // Set FSR.
                fsr_nxt = FSR_SECTION_DOMAIN_FAULT; 
        end

        DAC_CLIENT:
        begin
                // Setting this is fine. If we dont fault, we
                // ignore it.
                fsr_nxt = FSR_SECTION_PERMISSION_FAULT;
                check_section_permissions = check_apsr 
                                            (user,rd,wr,apsr);
        end

        default:
        begin
                // BUZZZZZZZZZZZZZ!
                check_section_permissions = 1'd0;
        end

        endcase                               

        fsr_nxt = {tlb[`SECTION_TLB__DAC_SEL], fsr_nxt[3:0]};
 
end
endfunction

// Returns 1 if permissions check out. Also sets FSR.
function check_spage_permissions (
input   [1:0]   ap_sel,         // Select one of 4 APs.
input           user,           // User mode.
input           rd,             // Read request.
input           wr,             // Write request.        
input [1:0]     sr,             // SR bits.
input [31:0]    dac_reg,        // DAC register.
input [SPAGE_TLB_WDT-1:0] tlb // TLB entry.
);
reg [3:0] apsr;
reg [1:0] dac;
begin
        apsr[3:2] = tlb[`SPAGE_TLB__AP] >> (ap_sel << 1);
        apsr[1:0] = sr;
        dac  = dac_reg >> ( tlb[`SPAGE_TLB__DAC_SEL] << 1 ); 

        check_spage_permissions = 1'd0;
        fsr_nxt = 0;

        case (dac)

        DAC_MANAGER:
        begin
                // Grant permissions - no fuss at all.
                check_spage_permissions = 1'd1;

                // Set FSR.
                fsr_nxt = FSR_PAGE_DOMAIN_FAULT; 
        end

        DAC_CLIENT:
        begin
                // Setting this is fine. If we dont fault, we
                // ignore it.
                fsr_nxt = FSR_PAGE_PERMISSION_FAULT;
                check_spage_permissions = check_apsr (user,rd,wr,apsr);
        end

        default:
        begin
                // BUZZZZZZZZZZZZZ!
                check_spage_permissions = 1'd0;
        end

        endcase

         fsr_nxt = {tlb[`SPAGE_TLB__DAC_SEL], fsr_nxt[3:0]};                               
end
endfunction

// Returns 1 if permissions check out. Also sets FSR.
function check_lpage_permissions (
input   [1:0]   ap_sel,         // Select one of 4 APs.
input           user,           // User mode.
input           rd,             // Read request.
input           wr,             // Write request.        
input [1:0]     sr,             // SR bits.
input [31:0]    dac_reg,        // DAC register.
input [LPAGE_TLB_WDT-1:0] tlb // TLB entry.
);
reg [3:0] apsr;
reg [1:0] dac;
begin
        apsr[3:2] = tlb[`LPAGE_TLB__AP] >> (ap_sel << 1);
        apsr[1:0] = sr;
        dac  = dac_reg >> ( tlb[`LPAGE_TLB__DAC_SEL] << 1 ); 

        fsr_nxt = 0;
        check_lpage_permissions = 1'd0;

        case (dac)

        DAC_MANAGER:
        begin
                // Grant permissions - no fuss at all.
                check_lpage_permissions = 1'd1;

                // Set FSR.
                fsr_nxt = FSR_PAGE_DOMAIN_FAULT; 
        end

        DAC_CLIENT:
        begin
                // Setting this is fine. If we dont fault, we
                // ignore it.
                fsr_nxt = FSR_PAGE_PERMISSION_FAULT;
                check_lpage_permissions = check_apsr (user,rd,wr,apsr);
        end

        default:
        begin
                // BUZZZZZZZZZZZZZ!
                check_lpage_permissions = 1'd0;
        end

        endcase                               

        fsr_nxt = {tlb[`LPAGE_TLB__DAC_SEL], fsr_nxt[3:0]};
end
endfunction


// 1 if OK. 0 if fail.
function check_apsr ( input user, input rd, input wr, input [3:0] apsr);
reg x;
begin
        x = 0; // Assume fail.

        casez (apsr)
        APSR_NA_NA: x = 0;
        APSR_RO_RO: x = !wr;
        APSR_RO_NA: x = !user && rd;
        APSR_RW_NA: x = !user;
        APSR_RW_RO: x = !user | (user && rd);
        APSR_RW_RW: x = 1; // Grant.
        default   : x = 0;
        endcase

        check_apsr = x;
end
endfunction

