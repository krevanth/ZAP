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
// Filename:
// zap_i_mmu_cache.v
//
// Description:
// The cache/MMU setup for the ZAP processor core. This is the top module. You
// need a CP15 wrapper to properly interface this with the rest of the core.
// You can use this common module for both the I-cache and the D-cache.
// Cache is write-through. Writes update both cache and main memory. Reads
// will short circuit into cache itself. No write buffer is implemented in
// this model. 
//

///////////////////////////////////////////////////////////////////////////////

`include "config.vh"
`default_nettype none

module zap_i_mmu_cache #(

        parameter PHY_REGS            = 64,    // Physical registers.
        parameter SECTION_TLB_ENTRIES =  4,    // Section TLB entries.
        parameter LPAGE_TLB_ENTRIES   =  8,    // Large page TLB entries.
        parameter SPAGE_TLB_ENTRIES   =  16,   // Small page TLB entries.
        parameter CACHE_SIZE          =  1024  // Cache size in bytes.

) (

// ============================================================================
// PORT LIST 
// ============================================================================


// ---------------------------------------------
// Clock and reset                              |
// ---------------------------------------------
// Reset is synchronous and active high.        |
// ---------------------------------------------
input   wire                    i_clk           , // Clock.
input   wire                    i_reset         , // Reset.
// ---------------------------------------------


// ---------------------------------------------
// Auxiliary signals from core.                 |
// ---------------------------------------------
input wire [31:0] i_address_nxt                 , // To be flopped address.
input wire i_dcache_stall                       , // uSed only for icache.
input wire i_clear_from_writeback               ,    // | High Priority.
input wire i_clear_from_alu                     ,    // |
input wire i_stall_from_shifter                 ,    // |
input wire i_stall_from_issue                   ,    // |
input wire i_stall_from_decode                  ,    // V Low Priority.
input wire i_clear_from_decode                  ,    // V
// ----------------------------------------------,

// ---------------------------------------------
// Memory access signals.                       |
// ---------------------------------------------
// These are generated at the start of the      |
// memory access stage.                         |
// ---------------------------------------------
input   wire    [31:0]          i_address       , // Address from CPU.
input   wire    [31:0]          i_cpsr          , // CPSR from CPU.
// ---------------------------------------------


// ---------------------------------------------
// Signals to core.                             |
// ---------------------------------------------
output  reg     [31:0]          o_rd_data       , // Data read. Pipeline register.
output  reg                     o_stall         , // Not registered.
output  reg                     o_fault         , // Not registered.
// ---------------------------------------------


// ---------------------------------------------------
// CP15 Interface.                                    |
// ---------------------------------------------------
input wire      [31:0]                  i_cp_word     ,
input wire                              i_cp_dav      ,
input wire [31:0]                       i_reg_rd_data ,
// ----------------------------------------------------


// ---------------------------------------------
// RAM interface signals.                       |
// ---------------------------------------------
input   wire    [31:0]          i_ram_rd_data   , // RAM read data.
output  reg     [31:0]          o_ram_address   , // RAM address.
output  reg                     o_ram_rd_en     , // RAM read command.
input   wire                    i_ram_done        // RAM done indicator.
// ----------------------------------------------

);

// Unused.
reg [31:0] i_wr_data;
reg i_ben;
reg o_ram_wr_en;
reg o_ram_ben;
reg [31:0] o_ram_wr_data;
wire unused_ok = o_ram_wr_en | o_ram_ben | o_ram_wr_data | i_wr_data | i_ben;

///////////////////////////////////////////////////////////////////////////////

`include                 "mmu.vh"
`include       "mmu_functions.vh"
`include               "modes.vh"

///////////////////////////////////////////////////////////////////////////////


// ---------------------------------------------
// Tag RAM Comms.                               |
// ---------------------------------------------
// Tag RAM write data is always the tag so no   |
// need to explicitly assign a net for that.    |
// ---------------------------------------------
wire [CACHE_TAG_WDT-1:0]        tag_rdata       ; // Tag read.
wire                            tag_rdav        ; // Tag is valid.
reg                             tag_wen         ; // Write new tag.
// ---------------------------------------------


// ---------------------------------------------
// Section TLB Comms.                           |
// ---------------------------------------------
reg                             setlb_wen       ; // Write enable.
reg  [SECTION_TLB_WDT-1:0]      setlb_wdata     ; // TLB entry + tag (write).
wire [SECTION_TLB_WDT-1:0]      setlb_rdata     ; // TLB entry + tag (read)
wire                            setlb_rdav      ; // Read enable.
// ---------------------------------------------


// ---------------------------------------------
// Small page TLB Comms.                        |
// ---------------------------------------------
reg                             sptlb_wen       ; // Write enable.
reg  [SPAGE_TLB_WDT-1:0]        sptlb_wdata     ; // TLB entry + tag (write).
wire [SPAGE_TLB_WDT-1:0]        sptlb_rdata     ; // TLB entry + tag (Read).
wire                            sptlb_rdav      ; // Read enable.
// ---------------------------------------------


// ---------------------------------------------
// Large page TLB comms.                        |        
// ---------------------------------------------
reg                             lptlb_wen       ;
reg  [LPAGE_TLB_WDT-1:0]        lptlb_wdata     ;
wire [LPAGE_TLB_WDT-1:0]        lptlb_rdata     ;
wire                            lptlb_rdav      ;
// ---------------------------------------------


// ---------------------------------------------
// Cache Comms.                                 |
// ---------------------------------------------
reg [15:0]                      cache_ben       ;
reg [127:0]                     cache_wdata     ;                             
wire[127:0]                     cache_rdata     ;
// ---------------------------------------------


// ---------------------------------------------
// General Variables                            |
// ---------------------------------------------
reg refresh                                     ; // Refresh all EX memories.
reg stall                                       ; // Do not advance pipeline.
reg [31:0] fsr                                  ; // To CP15 CB block.
reg [31:0] far                                  ; // To CP15 CB block.
// ---------------------------------------------


// -----------------------------------
// From CP15 CB block                 |
// -----------------------------------
wire                    cache_inv     ; // Cache invalidate.
wire                    tlb_inv       ; // TLB invalidate.
wire [31:0]             baddr         ; // Table base address.
wire [1:0]              sr            ; // SR bits.
wire [31:0]             dac_reg       ; // Domain access control reg.
wire                    cache_en      ; // Cache enable (needs MMU).
wire                    mmu_en        ; // MMU enable (No need cache).
// -----------------------------------

// ============================================================================
// FLIP-FLOPS.
// ============================================================================


// ---------------------------------------------
// Cache Line Buffers                           |
// ---------------------------------------------
reg [31:0] buf0_ff, buf0_nxt                    ;
reg [31:0] buf1_ff, buf1_nxt                    ;
reg [31:0] buf2_ff, buf2_nxt                    ;
// ---------------------------------------------


// ---------------------------------------------
// Internal registers.                          |
// ---------------------------------------------
reg [$clog2(NUMBER_OF_STATES)-1:0] state_ff     , 
                                   state_nxt    ; // State.
reg [31:0] phy_addr_ff, phy_addr_nxt            ; // Physical address.
reg [31:0] fsr_nxt,     fsr_ff                  ;
reg [31:0] far_nxt,     far_ff                  ;
reg [31:0] pc_buf                               ; // For cache read re-time.
reg        force_rd                             ; // Force read enable on caches.
// ---------------------------------------------

//=============================================================================
// INSTANTIATIONS                                                              
//=============================================================================


// -------------------------------------------------------------------------
// Cache Tag RAM                                                            |    
// -------------------------------------------------------------------------
// The tag RAM is actually a part of the execute phase itself. Thus, the    |
// read registers share the stall signal.                                   |
// -------------------------------------------------------------------------|
mem_inv_block #(.DEPTH(CACHE_SIZE/16), .WIDTH(CACHE_TAG_WDT)) u_cache_tag  (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (cache_inv || !cache_en)                           ,
        .i_ren          (force_rd || (!stall && !o_stall))                 ,
        .i_wen          ( i_ram_done ? tag_wen : 1'd0 )                    ,
        .i_raddr        (i_address_nxt[`VA__CACHE_INDEX])                  ,
        .i_waddr        (i_address[`VA__CACHE_INDEX])                      ,
        .i_wdata        (i_address[`VA__CACHE_TAG])                        ,
        .o_rdata        (tag_rdata)                                        ,
        .o_rdav         (tag_rdav)                                         ,
        .i_refresh      (refresh && !force_rd)    
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Section TLB. Read is part of the pipeline. Part of the EX phase.        |
// ------------------------------------------------------------------------
mem_inv_block #(.DEPTH(SECTION_TLB_ENTRIES), .WIDTH(SECTION_TLB_WDT)) sect (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (tlb_inv || !mmu_en)                               ,
        .i_ren          (force_rd || (!stall && !o_stall))                 ,
        .i_wen          ( setlb_wen )                                      ,
        .i_raddr        (i_address_nxt[`VA__SECTION_INDEX])                ,
        .i_waddr        (i_address[`VA__SECTION_INDEX])                    ,
        .i_wdata        (setlb_wdata)                                      ,
        .o_rdata        (setlb_rdata)                                      ,
        .o_rdav         (setlb_rdav)                                       ,
        .i_refresh      (refresh && !force_rd)      
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Large page TLB. Read is part of the pipeline. Part of the EX phase.     |
// ------------------------------------------------------------------------
mem_inv_block #(.DEPTH(LPAGE_TLB_ENTRIES), .WIDTH(LPAGE_TLB_WDT)) u_lptlb  (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (tlb_inv || !mmu_en)                               ,
        .i_ren          (force_rd||(!stall && !o_stall))                   ,
        .i_wen          ( lptlb_wen )                                      ,
        .i_raddr        (i_address_nxt[`VA__LPAGE_INDEX])                  ,
        .i_waddr        (i_address[`VA__LPAGE_INDEX])                      ,   
        .i_wdata        (lptlb_wdata)                                      ,
        .o_rdata        (lptlb_rdata)                                      ,
        .o_rdav         (lptlb_rdav)                                       ,
        .i_refresh      (refresh && !force_rd)         
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Small Page TLB. Read is part of the pipeline. Part of the EX phase.     |
// ------------------------------------------------------------------------
mem_inv_block #(.DEPTH(SPAGE_TLB_ENTRIES), .WIDTH(SPAGE_TLB_WDT)) u_sptlb  (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (tlb_inv || !mmu_en)                               ,
        .i_ren          (force_rd || (!stall && !o_stall))                 ,
        .i_wen          ( sptlb_wen )                                      ,
        .i_raddr        (i_address_nxt[`VA__SPAGE_INDEX])                  ,
        .i_waddr        (i_address[`VA__SPAGE_INDEX])                      ,
        .i_wdata        (sptlb_wdata)                                      ,
        .o_rdata        (sptlb_rdata)                                      ,
        .o_rdav         (sptlb_rdav)                                       ,
        .i_refresh       (refresh && !force_rd)                                          
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Cache Line Memory. Part of the MEM phase. Read is part of the pipeline. |
// ------------------------------------------------------------------------
mem_ben_block128 #(.DEPTH(CACHE_SIZE/16)) u_cache                          (
        .i_clk          (i_clk)                                            ,
        .i_ben          (i_ram_done ? cache_ben : 1'd0)                    ,
        .i_ren          (!stall && !o_stall)                               ,
        .i_addr         (i_address[`VA__CACHE_INDEX])                      ,
        .i_wdata        (cache_wdata)                                      ,
        .o_rdata        (cache_rdata)
)                                                                          ;
// ------------------------------------------------------------------------


// -------------------------------------------------------------------------
// CP15 Control Block                                                       |
// -------------------------------------------------------------------------
zap_cp15_cb #(.PHY_REGS(PHY_REGS)) u_cb_block (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_cp_word(i_cp_word),
        .i_cp_dav(i_cp_dav),
        .o_cp_done(),
        .i_cpsr(i_cpsr),
        .o_reg_en(),
        .o_reg_wr_data(),
        .i_reg_rd_data(i_reg_rd_data),
        .o_reg_wr_index(),
        .o_reg_rd_index(),
        .i_fsr(fsr),
        .i_far(far),
        .o_dac(dac_reg),
        .o_baddr(baddr),
        .o_cache_inv(cache_inv),
        .o_tlb_inv(tlb_inv),
        .o_icache_en(cache_en),
        .o_dcache_en(),
        .o_mmu_en(mmu_en),
        .o_sr(sr)
);
// -------------------------------------------------------------------------

// ============================================================================
// COMBINATIONAL LOGIC.
// ============================================================================

always @*
begin
        // Pipeline external stall sequence.
        if      ( i_clear_from_writeback )       stall = 1'd0;
        else if ( i_dcache_stall )               stall = 1'd1;
        else if ( i_clear_from_alu )             stall = 1'd0;       
        else if ( i_stall_from_shifter )         stall = 1'd1;
        else if ( i_stall_from_issue )           stall = 1'd1;
        else if ( i_stall_from_decode)           stall = 1'd1;
        else                                     stall = 1'd0;
end

// Sequential logic - BUG FIX.
always @ (posedge i_clk)
begin
        if ( i_reset )
                pc_buf <= 32'd0;
        else if ( !stall && !o_stall )
                pc_buf <= i_address;
end

always @*
begin
           // Statii.
           fsr = fsr_ff;
           far = far_ff;

            // Cache read data.
            o_rd_data = cache_en ? adapt_cache_data ( pc_buf[3:2], cache_rdata ) : 
                        i_ram_rd_data;
end

function [31:0] adapt_cache_data ( input [1:0] shift, input [127:0] cd);
begin: blk1
        reg [31:0] shamt;
        shamt = shift << 5;
        adapt_cache_data = cd >> shamt;
end
endfunction

always @*
begin: blk1
        reg cacheable;
        reg goahead;

        goahead         = 1'd0;
        cacheable       = 1'd0;
        o_stall         = 1'd1;
        fsr_nxt         = fsr_ff;
        far_nxt         = far_ff;
        //fsr             = fsr_ff;
        //far             = far_ff;
        o_fault         = 1'd0;
        phy_addr_nxt    = phy_addr_ff;
        refresh         = 1'd0;
        buf0_nxt        = buf0_ff;
        buf1_nxt        = buf1_ff;
        buf2_nxt        = buf2_ff;
        tag_wen         = 1'd0;
        setlb_wen       = 1'd0;
        setlb_wdata     = 0;
        sptlb_wen       = 0;
        sptlb_wdata     = 0;
        lptlb_wen       = 0;
        lptlb_wdata     = 0;
        cache_ben       = 0;
        cache_wdata     = 0;
        state_nxt       = state_ff;

        kill_memory_op;

         case ( state_ff ) //: CASE STARTS HERE

         IDLE, RD_DLY:
         begin

///////////////////////////////////////////////////////////////////////////////

                if ( mmu_en ) // MMU enabled.
                begin
                        if ( (sptlb_rdata[`SPAGE_TLB__TAG] == 
                               i_address[`VA__SPAGE_TAG]) && sptlb_rdav )
                        begin
                                //
                                // Entry found in small page TLB.
                                //
                                fsr_nxt = spage_fsr
                                (
                                        i_address[`VA__SPAGE_AP_SEL],
                                        i_cpsr[4:0] == USR,
                                        1'd1,
                                        1'd0,
                                        sr,
                                        dac_reg,
                                        sptlb_rdata
                                ) ;

                                phy_addr_nxt = {sptlb_rdata[`SPAGE_TLB__BASE], 
                                                i_address[11:0]};

                                cacheable = sptlb_rdata[`SECTION_TLB__CB] >> 1;

                                if ( fsr_nxt[3:0] != 4'd0 ) // Fault occured.
                                begin
                                        goahead   = 1'd0;       // Block cache access.
                                        o_stall   = 1'd0;       // Don't stall.
                                        o_fault   = 1'd1;       // Set fault.
                                        far_nxt   = i_address;  // Set fault address.
                                end
                                else   // No fault.
                                begin
                                        goahead   = 1'd1;   // No fault.
                                        o_stall   = 1'd0;   // No stall until now. 
                                        far_nxt   = far_ff; // Keep values.
                                        o_fault   = 1'd0;   // No fault.
                                end

                        end
                        else if ( (lptlb_rdata[`LPAGE_TLB__TAG] == 
                               i_address[`VA__LPAGE_TAG]) && lptlb_rdav )
                        begin
                                //
                                // Entry found in large page TLB.
                                //
                                fsr_nxt = lpage_fsr
                                (
                                        i_address[`VA__LPAGE_AP_SEL],
                                        i_cpsr[4:0] == USR,
                                        1'd1,
                                        1'd0,
                                        sr,
                                        dac_reg,
                                        lptlb_rdata
                                ) ;

                                phy_addr_nxt = {lptlb_rdata[`LPAGE_TLB__BASE],
                                                i_address[15:0]};

                                cacheable = lptlb_rdata[`LPAGE_TLB__CB] >> 1;

                                if ( fsr_nxt[3:0] != 4'd0 ) // Fault occured.
                                begin
                                        goahead   = 1'd0;       // Block cache access.
                                        o_stall   = 1'd0;       // Don't stall.
                                        o_fault   = 1'd1;       // Set fault.
                                        far_nxt   = i_address;  // Set fault address.
                                end
                                else   // No fault.
                                begin
                                        goahead   = 1'd1;   // No fault.
                                        o_stall   = 1'd0;   // No stall until now. 
                                        far_nxt   = far_ff; // Keep values.
                                        o_fault   = 1'd0;   // No fault.
                                end

                        end
                        else if ( (setlb_rdata[`SECTION_TLB__TAG] == 
                               i_address[`VA__SECTION_TAG]) && setlb_rdav )
                        begin
                                //
                                // Entry found in section TLB.
                                //
                                fsr_nxt = section_fsr
                                (
                                        i_cpsr[4:0] == USR,
                                        1'd1,
                                        1'd0,
                                        sr,
                                        dac_reg,
                                        setlb_rdata
                                ) ;

                                phy_addr_nxt = {setlb_rdata[`SECTION_TLB__BASE],
                                                i_address[19:0]};

                                cacheable = setlb_rdata[`SECTION_TLB__CB] >> 1;

                                if ( fsr_nxt[3:0] != 4'd0 ) // Fault occured.
                                begin
                                        goahead   = 1'd0;       // Block cache access.
                                        o_stall   = 1'd0;       // Don't stall.
                                        o_fault   = 1'd1;       // Set fault.
                                        far_nxt   = i_address;  // Set fault address.
                                end
                                else   // No fault.
                                begin
                                        goahead   = 1'd1;   // No fault.
                                        o_stall   = 1'd0;   // No stall until now. 
                                        far_nxt   = far_ff; // Keep values.
                                        o_fault   = 1'd0;   // No fault.
                                end

                        end
                        else /* Entry not found. */
                        begin
                                //
                                // Dont go ahead with cache access since we need
                                // to fetch descriptor.
                                //
                                fsr_nxt   = fsr_ff;             // Preserve FSR.
                                far_nxt   = far_ff;             // Preserve FAR.
                                goahead   = 1'd0;               // Don't do cache access.
                                o_fault   = 1'd0;               // No fault.
                                o_stall   = 1'd1;               // Stall CPU.
                                state_nxt = START_DESC_FETCH;   // Initiate DESC_FETCH.
                        end
                end
                else
                begin
                        //
                        // No translation as MMU is OFF. Go ahead with cache access.
                        // Stall witll be computed in cache access.
                        //
                        phy_addr_nxt = i_address;
                        o_fault      = 1'd0;
                        state_nxt    = state_ff;
                        goahead      = 1'd1;
                        fsr_nxt      = 0;
                        far_nxt      = 0;
                        o_stall      = 0; // No stall so far.

                        //
                        // Decide cacheability based on define.
                        //
                        `ifdef SIM
                                // Simulation only.

                                `ifdef FORCE_I_CACHEABLE
                                        cacheable = 1'd1;
                                `elsif FORCE_I_RAND_CACHEABLE
                                        cacheable = $random; // DO NOT SET THIS FOR SYNTHESIS.
                                `else
                                        cacheable = 1'd0; // If mmu is out, cache is also out.
                                `endif
                        `else
                                // Synthesis.
                                cacheable = 1'd0; // If MMU is out, cache too is.
                        `endif
                end

///////////////////////////////////////////////////////////////////////////////

                //
                // Permissions check out, we can access memory.
                //
                if ( goahead )
                begin
                        if ( cache_en )
                        begin
                                        // Cache is enabled. Check for a tag match and CACHEABILITY or in RD_DLY state.
                                        if ( (i_address[`VA__CACHE_TAG] == tag_rdata) && 
                                             tag_rdav && (cacheable | state_ff == RD_DLY) )
                                        begin
                                                        // Read. This is where we
                                                        // accelerate performance.
                                                        o_stall = 1'd0;

                                                        if ( !stall )
                                                        begin 
                                                                state_nxt = IDLE;
                                                        end
                                        end
                                        else
                                        begin
                                                // No match, start cache fill.
                                                o_stall   = 1'd1;
                                                state_nxt = START_CACHE_FILL;
                                        end
                        end
                        else // Fall back access.
                        begin
                                o_ram_address = phy_addr_nxt;
                                o_ram_rd_en   = !stall; 
                                o_stall       = !i_ram_done;
                                o_fault       = 1'd0;
                                fsr_nxt       = 32'd0;
                                far_nxt       = 32'd0;
                        end
                end // Else access is killed or TLB takes over.
         end

         START_CACHE_FILL:
         begin
                 // Stall CPU.
                 o_fault = 1'd0;
                 o_stall = 1'd1;

                 // Place address.
                 generate_memory_read({phy_addr_ff[31:4], 4'd0});

                 // Wait for response.
                 if ( i_ram_done )
                 begin
                         state_nxt = CACHE_FILL_0; 
                 end
                 else
                 begin
                         state_nxt = state_ff;
                 end
         end

         START_DESC_FETCH:
         begin
                 // Stall CPU.
                 o_fault   = 1'd0;
                 o_stall   = 1'd1;

                 // Provide address on the bus.
                 // Generate read.
                 generate_memory_read (   
                 {baddr  [`VA__TRANSLATION_BASE], 
                  i_address[`VA__TABLE_INDEX], 2'd0});

                 // Wait for a response.
                 if ( i_ram_done )
                 begin
                         state_nxt = FETCH_L1_DESC;
                 end
         end

         FETCH_L1_DESC:
         begin
                o_stall = 1'd1;

                // Get another level of fetch - prpr in case.
                generate_memory_read ({i_ram_rd_data[`L1_PAGE__PTBR], 
                                      i_address[`VA__L2_TABLE_INDEX], 2'd0});

                case ( i_ram_rd_data[`ID] )
                SECTION_ID:
                begin
                        // It's a section!!!
                        // No need another fetch.

                        // Update TLB.
                        setlb_wen   = 1'd1;

                        // The section TLB structure mimics the
                        // way ARM likes to do things.
                        setlb_wdata = {i_address[`VA__SECTION_TAG], 
                                       i_ram_rd_data};
                        state_nxt   = REFRESH_CYCLE; 
                end

                PAGE_ID:
                begin
                        if ( i_ram_done )
                                state_nxt = FETCH_L2_DESC;

                        // Store the current one (Only domain sel).
                        phy_addr_nxt[3:0] = i_ram_rd_data[`L1_PAGE__DAC_SEL];

        
                end

                default:
                begin
                        // Generate Section translation fault.
                        fsr_nxt   = FSR_SECTION_TRANSLATION_FAULT;
                        fsr_nxt   = {i_ram_rd_data[`L1_SECTION__DAC_SEL], fsr_nxt[3:0]};
                        far_nxt   = i_address;
                        o_fault   = 1;
                        o_stall   = 1'd0;
                        state_nxt = !stall ? IDLE : state_ff;
                end
                
                endcase 
         end

        FETCH_L2_DESC:
        begin
                o_stall = 1'd1;

                case ( i_ram_rd_data[`ID] )
                SPAGE_ID:
                begin
                        // Update TLB.
                        sptlb_wen   = 1'd1;

                        sptlb_wdata = {i_ram_rd_data[`VA__SPAGE_TAG],
                                       phy_addr_nxt[3:0], // DAC sel. 
                                       i_ram_rd_data};    // This is same.

                        state_nxt   = REFRESH_CYCLE;
                end

                LPAGE_ID:
                begin
                        lptlb_wen   = 1'd1;
                        lptlb_wdata = {i_ram_rd_data[`VA__LPAGE_TAG],
                                       i_ram_rd_data};

                        // DAC is inserted in between to save bits.
                        lptlb_wdata[`LPAGE_TLB__DAC_SEL] = phy_addr_nxt[3:0];

                        state_nxt   = REFRESH_CYCLE;
                end

                default:
                begin
                        o_fault   = 1;
                        o_stall   = 1'd0;
                        fsr_nxt   = FSR_PAGE_TRANSLATION_FAULT;
                        fsr_nxt   = {i_ram_rd_data[`L1_PAGE__DAC_SEL], fsr_nxt[3:0]};
                        far_nxt   = i_address;
                        state_nxt = !stall ? IDLE : state_ff;
                end
                endcase
        end

        CACHE_FILL_0:
        begin
                o_stall = 1'd1;

                generate_memory_read({phy_addr_nxt[31:4], 4'd4});
                buf0_nxt = i_ram_rd_data;

                if ( i_ram_done )
                begin
                        state_nxt = CACHE_FILL_1;
                end
        end

        CACHE_FILL_1:
        begin
                o_stall = 1'd1;

                generate_memory_read ( {phy_addr_ff[31:4], 4'd8} );
                buf1_nxt = i_ram_rd_data;

                if ( i_ram_done )
                begin
                        buf1_nxt = i_ram_rd_data;
                        state_nxt = CACHE_FILL_2;
                end
        end

        CACHE_FILL_2:
        begin
                o_stall = 1'd1;

                generate_memory_read ( {phy_addr_ff[31:4], 4'd12} );
                buf2_nxt = i_ram_rd_data;

                if ( i_ram_done )
                begin
                        state_nxt = CACHE_FILL_3;
                end
        end

        CACHE_FILL_3:
        begin
                o_stall = 1'd1;

                 // Update TAG and Cache.                
                 cache_ben   = 16'b1111_1111_1111_1111;
                 cache_wdata = {i_ram_rd_data, buf2_ff, buf1_ff, buf0_ff};
                 tag_wen     = 1'd1;

                if ( i_ram_done )
                begin
                        state_nxt = REFRESH_CYCLE_CACHE;
                end                        
        end

        REFRESH_CYCLE, REFRESH_CYCLE_CACHE:
        begin
                o_stall   = 1'd1;
                refresh   = 1'd1;
                state_nxt = state_ff == REFRESH_CYCLE_CACHE ? RD_DLY : IDLE;
        end

         endcase // : CASE ENDS HERE
end

always @*
begin
        force_rd = 1'd0;

                if      ( i_clear_from_writeback )   force_rd = 1'd1;
                else if ( i_dcache_stall )           begin end
                else if ( i_clear_from_alu)          force_rd = 1'd1;

                else if ( i_stall_from_shifter || 
                          i_stall_from_issue   || 
                          i_stall_from_decode  ) 
                                                begin end

                else if ( i_clear_from_decode ) force_rd = 1'd1;
                else begin end

end

// ============================================================================
// SEQUENTIAL LOGIC.
// ============================================================================

always @ (posedge i_clk)
begin
        if ( i_reset )  
        begin
                state_ff        <=      IDLE;
        end
        else
        begin
                if      ( i_clear_from_writeback )   state_ff <= IDLE;
                else if ( i_dcache_stall )           state_ff <= state_nxt;
                else if ( i_clear_from_alu)          state_ff <= IDLE;

                else if ( i_stall_from_shifter || 
                          i_stall_from_issue   || 
                          i_stall_from_decode  ) 
                                                state_ff <= state_nxt; // Keep movin'

                else if ( i_clear_from_decode ) state_ff <= IDLE;
                else state_ff <= state_nxt;
        end
end

always @ (posedge i_clk) fsr_ff      <= i_reset ? 0 : fsr_nxt;
always @ (posedge i_clk) far_ff      <= i_reset ? 0 : far_nxt;
always @ (posedge i_clk) phy_addr_ff <= i_reset ? 0 : phy_addr_nxt;

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                buf0_ff <= 32'd0;
                buf1_ff <= 32'd0;
                buf2_ff <= 32'd0;
        end
        else
        begin
                buf0_ff <= buf0_nxt;
                buf1_ff <= buf1_nxt;
                buf2_ff <= buf2_nxt;
        end
end

///////////////////////////////////////////////////////////////////////////////

task kill_memory_op; // Kill memory operation of RW memory.
begin
        o_ram_wr_en   = 1'd0;
        o_ram_rd_en   = 1'd0;
        o_ram_address = 32'd0;
        o_ram_ben     = 4'd0;
        o_ram_wr_data = 32'd0;
end
endtask

// Generate memory write on RW memory.
task generate_memory_write ( input [31:0] address );
begin
           o_ram_wr_data = i_wr_data;
           o_ram_address = address;  
           o_ram_ben     = i_ben;
           o_ram_wr_en   = 1'd1;
           o_ram_rd_en   = 1'd0;
end
endtask

// Generate memory read on RW memory.
task generate_memory_read ( input [31:0] address );
begin
           o_ram_wr_data = 32'd0;
           o_ram_ben     = 4'd0;
           o_ram_address = address;  
           o_ram_wr_en   = 1'd0;
           o_ram_rd_en   = 1'd1;
end
endtask

//////////////////////////////////////////////////////////////////////////////

endmodule // zap_i_mmu_cache.v
