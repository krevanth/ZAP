`include "config.vh"

// ============================================================================
// Filename:
// zap_d_mmu_cache.v
// ----------------------------------------------------------------------------
// Description:
// The cache/MMU setup for the ZAP processor core. This is the top module. You
// need a CP15 wrapper to properly interface this with the rest of the core.
// You can use this common module for both the I-cache and the D-cache.
// Cache is write-through. Writes update both cache and main memory. Reads
// will short circuit into cache itself. No write buffer is implemented in
// this model. 
// ----------------------------------------------------------------------------
// Author:
// Revanth Kamaraj
// (C) 2016.
// ----------------------------------------------------------------------------
// License: MIT
// ============================================================================

`default_nettype none

module zap_d_mmu_cache #(parameter PHY_REGS = 64) (

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
input wire i_clear_from_writeback               , // High Priority.
// ----------------------------------------------,

// ---------------------------------------------
// Memory access signals.                       |
// ---------------------------------------------
// These are generated at the start of the      |
// memory access stage.                         |
// ---------------------------------------------
input   wire                    i_read_en       , // Read request from CPU.
input   wire                    i_write_en      , // Write request from CPU.
input   wire    [3:0]           i_ben           , // Byte enable from CPU.
input   wire    [31:0]          i_wr_data       , // Data from CPU.
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
output wire                             o_cp_done     ,
output wire                             o_reg_en      ,
output wire [31:0]                      o_reg_wr_data ,
input wire [31:0]                       i_reg_rd_data ,
output wire [$clog2(PHY_REGS)-1:0]      o_reg_wr_index,
                                        o_reg_rd_index,
// ----------------------------------------------------


// ---------------------------------------------
// RAM interface signals.                       |
// ---------------------------------------------
// Technically unregistered.                    |
// ---------------------------------------------|
output  reg     [31:0]          o_ram_wr_data   , // RAM write data.
input   wire    [31:0]          i_ram_rd_data   , // RAM read data.
output  reg     [31:0]          o_ram_address   , // RAM address.
output  reg                     o_ram_rd_en     , // RAM read command.
output  reg                     o_ram_wr_en     , // RAM write command.
output  reg     [3:0]           o_ram_ben       , // RAM byte enable.
input   wire                    i_ram_done        // RAM done indicator.
// ----------------------------------------------

);


// ============================================================================
// INCLUDE FILES, PARAMS.
// ============================================================================


// -----------------------------
// MMU configuration            |
// -----------------------------
// Edit the file to modify the  |
// MMU parameters.              |
// -----------------------------
`include                 "mmu.vh"
`include       "mmu_functions.vh"
`include        "basic_checks.vh"
`include               "modes.vh"
// -----------------------------


// ============================================================================
// NETS.
// ============================================================================


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
reg stall = 1'd0                                ; // Do not advance pipeline.
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
reg [31:0] addr_buf                             ;
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
        .i_ren          (!o_stall)                                         ,
        .i_wen          ( i_ram_done ? tag_wen : 1'd0 )                    ,
        .i_raddr        (i_address_nxt[`VA__CACHE_INDEX])                  ,
        .i_waddr        (i_address[`VA__CACHE_INDEX])                      ,
        .i_wdata        (i_address[`VA__CACHE_TAG])                        ,
        .o_rdata        (tag_rdata)                                        ,
        .o_rdav         (tag_rdav)                                         ,
        .i_refresh      (refresh)    
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Section TLB. Read is part of the pipeline. Part of the EX phase.        |
// ------------------------------------------------------------------------
mem_inv_block #(.DEPTH(SECTION_TLB_ENTRIES), .WIDTH(SECTION_TLB_WDT)) sect (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (tlb_inv || !mmu_en)                               ,
        .i_ren          (!o_stall)                                         ,
        .i_wen          ( setlb_wen )                                      ,
        .i_raddr        (i_address_nxt[`VA__SECTION_INDEX])                ,
        .i_waddr        (i_address[`VA__SECTION_INDEX])                    ,
        .i_wdata        (setlb_wdata)                                      ,
        .o_rdata        (setlb_rdata)                                      ,
        .o_rdav         (setlb_rdav)                                       ,
        .i_refresh      (refresh)      
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Large page TLB. Read is part of the pipeline. Part of the EX phase.     |
// ------------------------------------------------------------------------
mem_inv_block #(.DEPTH(LPAGE_TLB_ENTRIES), .WIDTH(LPAGE_TLB_WDT)) u_lptlb  (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (tlb_inv || !mmu_en)                               ,
        .i_ren          (!o_stall)                                         ,
        .i_wen          ( lptlb_wen )                                      ,
        .i_raddr        (i_address_nxt[`VA__LPAGE_INDEX])                  ,
        .i_waddr        (i_address[`VA__LPAGE_INDEX])                      ,   
        .i_wdata        (lptlb_wdata)                                      ,
        .o_rdata        (lptlb_rdata)                                      ,
        .o_rdav         (lptlb_rdav)                                       ,
        .i_refresh      (refresh)         
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Small Page TLB. Read is part of the pipeline. Part of the EX phase.     |
// ------------------------------------------------------------------------
mem_inv_block #(.DEPTH(SPAGE_TLB_ENTRIES), .WIDTH(SPAGE_TLB_WDT)) u_sptlb  (
        .i_clk          (i_clk)                                            ,
        .i_reset        (i_reset)                                          ,
        .i_inv          (tlb_inv || !mmu_en)                               ,
        .i_ren          (!o_stall)                                         ,
        .i_wen          ( sptlb_wen )                                      ,
        .i_raddr        (i_address_nxt[`VA__SPAGE_INDEX])                  ,
        .i_waddr        (i_address[`VA__SPAGE_INDEX])                      ,
        .i_wdata        (sptlb_wdata)                                      ,
        .o_rdata        (sptlb_rdata)                                      ,
        .o_rdav         (sptlb_rdav)                                       ,
        .i_refresh       (refresh)                                          
)                                                                          ;
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// Cache Line Memory. Part of the MEM phase. Read is part of the pipeline. |
// ------------------------------------------------------------------------
mem_ben_block128 #(.DEPTH(CACHE_SIZE/16)) u_cache                          (
        .i_clk          (i_clk)                                            ,
        .i_ben          (i_ram_done ? cache_ben : 16'd0)                   ,
        .i_ren          (!o_stall)                                         ,
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
        .o_cp_done(o_cp_done),
        .i_cpsr(i_cpsr),
        .o_reg_en(o_reg_en),
        .o_reg_wr_data(o_reg_wr_data),
        .i_reg_rd_data(i_reg_rd_data),
        .o_reg_wr_index(o_reg_wr_index),
        .o_reg_rd_index(o_reg_rd_index),
        .i_fsr(fsr),
        .i_far(far),
        .o_dac(dac_reg),
        .o_baddr(baddr),
        .o_cache_inv(cache_inv),
        .o_tlb_inv(tlb_inv),
        .o_dcache_en(cache_en),
        .o_icache_en(),
        .o_mmu_en(mmu_en),
        .o_sr(sr)
);
// -------------------------------------------------------------------------


// ============================================================================
// COMBINATIONAL LOGIC. D CACHE
// ============================================================================

always @*
begin
           // Statii.
           fsr = fsr_ff;
           far = far_ff;

          // Cache read data.
           o_rd_data =  cache_en ? adapt_cache_data ( addr_buf[3:2], cache_rdata ) : i_ram_rd_data;
end

function [31:0] adapt_cache_data ( input [1:0] shift, input [127:0] cd);
begin: blk1
        reg [31:0] shamt;
        shamt = shift << 5;
        adapt_cache_data = cd >> shamt;
end
endfunction

// Sequential logic - BUG FIX.
always @ (posedge i_clk)
begin
        if ( i_reset )
                addr_buf <= 32'd0;
        else if ( !o_stall )
                addr_buf <= i_address;
end

always @*
begin: blk1
        reg cacheable;
        reg goahead;

//        $display($time, "*I: MMU cache trigerred!");

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
                else /* MMU is off */
                begin
                        //
                        // No translation as MMU is OFF. Go ahead with cache access.
                        // Stall witll be computed in cache access.
                        //
                        phy_addr_nxt = i_address;
                        o_fault      = 1'd0;
                        state_nxt    = state_ff;
                        goahead      = 1'd1;
                        fsr_nxt      = 0; // If mmu is off, set statii to 0.
                        far_nxt      = 0;
                        o_stall      = 0; // No stall so far.

                        //
                        // Decide cacheability based on define.
                        //
                        `ifdef FORCE_I_CACHEABLE
                                cacheable = 1'd1;
                        `elsif FORCE_I_RAND_CACHEABLE
                                cacheable = $random; // DO NOT SET THIS FOR SYNTHESIS.
                        `else
                                cacheable = 1'd0; // If mmu is out, cache is also out.
                        `endif
                end

///////////////////////////////////////////////////////////////////////////////

                //
                // Active request to cache pending/maccess pending...
                //
                if ( goahead && (i_read_en || i_write_en) )
                begin
                        if ( cache_en )
                        begin
                                        // Cache is enabled. Check for a tag match.
                                        if ( (i_address[`VA__CACHE_TAG] == tag_rdata) && 
                                             tag_rdav && (cacheable | state_ff == RD_DLY) )
                                        begin
                                                // Tag matches - We are lucky! 
                                                
                                                if ( i_write_en )
                                                begin
                                                        // Stall CPU and go to write state.
                                                        o_stall = 1'd1;
                                                        state_nxt = ( state_ff == IDLE ) ? MEM_WRITE_IDLE : MEM_WRITE_RD_DLY;
                                                end
                                                else // Read 
                                                begin
                                                        // Read. This is where we
                                                        // accelerate performance.
                                                        o_stall = 1'd0;

                                                        // Go to IDLE state.
                                                        state_nxt = IDLE;
                                                end
                                        end
                                        else
                                        begin
                                                // Begin a linefill.
                                                o_stall = 1'd1;
                                                state_nxt = START_CACHE_FILL;
                                        end
                        end
                        else
                        begin
                                // Fall back access.
                                o_ram_wr_data = i_wr_data;
                                o_ram_ben     = i_ben;
                                o_ram_address = phy_addr_nxt;
                                o_ram_wr_en   = i_write_en;
                                o_ram_rd_en   = i_read_en; 
                                o_stall       = !i_ram_done;
                                o_fault       = 1'd0;
                                fsr_nxt       = 32'd0;
                                far_nxt       = 32'd0;
                                state_nxt     = IDLE;
                        end
                end // Else kill_memory_op or TLB transfer.
         end

        MEM_WRITE_IDLE:
        begin
                 // Generate memory write signals to write to physical address.
                 generate_memory_write ( phy_addr_ff );
                 o_stall = 1'd1;

                 if ( i_ram_done && !stall )
                 begin
                         // Go to IDLE.
                         state_nxt = IDLE;

                        // Pull out of stall.
                        o_stall = 1'd0;

                         // Write to line cache with virtual address.
                         cache_wdata = 
                         write_cache_line ( i_wr_data, i_ben, i_address[3:2] );            
                end

        end

        MEM_WRITE_RD_DLY:
        begin
                 // Generate memory write signals to write to physical address.
                 generate_memory_write ( phy_addr_ff );
                 o_stall = 1'd1;

                 if ( i_ram_done && !stall )
                 begin
                         // Go to RD_DLY.
                         state_nxt = RD_DLY;

                        // Pull out of stall.
                        o_stall = 1'd0;

                         // Write to line cache with virtual address.
                         cache_wdata = 
                         write_cache_line ( i_wr_data, i_ben, i_address[3:2] );            
                end

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

                // Get another level of fetch in case PAGE_ID.
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
                        state_nxt = !stall ? IDLE : state_ff;
                        o_stall   = 1'd0;
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
                        fsr_nxt   = FSR_PAGE_TRANSLATION_FAULT;
                        fsr_nxt   = {i_ram_rd_data[`L1_PAGE__DAC_SEL], fsr_nxt[3:0]};
                        far_nxt   = i_address;
                        state_nxt = !stall ? IDLE : state_ff;
                        o_stall   = 1'd0;
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
                state_nxt = state_ff == REFRESH_CYCLE_CACHE ? RD_DLY : IDLE;
                refresh   = 1'd1;
        end
         endcase // : CASE ENDS HERE
end

function [127:0] write_cache_line (input [31:0] wr_data, input [3:0] ben, input [1:0] index  );
begin: bk11
        reg [31:0] shamt1, shamt2;
        reg [127:0] test_wdata;
        reg [15:0] test_ben;        

        shamt1 = index << 5;
        shamt2 = index << 2;

        test_wdata = wr_data << shamt1;
        test_ben   = ben << shamt2;
        cache_ben  = test_ben;

        write_cache_line = test_wdata;
end
endfunction

// ============================================================================
// SEQUENTIAL LOGIC.
// ============================================================================


always @ (posedge i_clk)     if ( i_reset )                state_ff <= IDLE;    
                        else if ( i_clear_from_writeback ) state_ff <= IDLE;
                        else                               state_ff    <= state_nxt;

always @ (posedge i_clk) if ( i_reset ) fsr_ff <= 0;      else fsr_ff      <= fsr_nxt;
always @ (posedge i_clk) if ( i_reset ) far_ff <= 0;      else far_ff      <= far_nxt;
always @ (posedge i_clk) if ( i_reset ) phy_addr_ff <= 0; else phy_addr_ff <= phy_addr_nxt;

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

initial
begin
        `ifndef SIM
                `ifdef FORCE_D_RAND_CACHEABLE
                        $display("*E: Bad config.vh setting for synthesis...");
                        $finish;
                `endif
        `endif
end

endmodule // zap_d_mmu_cache.v
















