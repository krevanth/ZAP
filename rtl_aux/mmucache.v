`default_nettype none

/*
 * This is the cache and MMU system for the ZAP core. Cache is write-through
 * with a write buffer to memory. The write buffer is fully associative.
 */

module mmucache (

        // ZAP clock and reset.
        i_clk,                  // ZAP clock.
        i_reset,                // ZAP reset.

        // Config       
        i_cfg_tlb_clear,        // Clear TLB.
        i_cfg_cache_inv,        // Invalidate cache.

        i_instr_stall,          // Stall output from processor.

        // Pre-address for TAG and TLB lookup.
        i_address_nxt,          // Address for TAG RAM and TLB lookup.
        
        // Standard processor signals.
        i_address,              // Address.
        i_load,                 // Load/Store
        i_store,
        i_wr_data,              // Data to store.
        o_rd_data,              // Loaded data (Clocked).
        o_stall,                // Stall (Unregd.)
        o_fault,                // Fault (Unregd.)

        // Memory interface
        o_ram_req,              // Request access to RAM.
        i_ram_gnt,              // Access granted.
        o_ram_addr,             // RAM address.
        o_ram_data,             // Data to write.
        i_ram_data,             // Data read from RAM.
        i_ram_wait,             // Waiting for RAM access to complete.        

        /* **ERROR REPORTING** */
        // FSR and FAR. These must be logged in by the CP15 register unit.
        o_fsr,                  // FSR   (Must be clocked in externally).
        o_far                   // FAR   (Must be clocked in externally).

);

// NOTE: fsr and far are valid iff o_fault = 1.

// =============================
// Parameters.
// =============================

/* Set the write buffer size */
parameter WRITE_BUFFER_SIZE = 16;       // 16 entry write buffer (Fully assoc).

/* Set the cache size in bytes here */
parameter CACHE_SIZE = 1024;            // Bytes.

/* Set the section TLB depth here. */
parameter SECTION_TLB_ENTRIES = 64;     // Entries 

/* Set the large page TLB depth here */
parameter LPAGE_TLB_ENTRIES = 64;       // Entries.

/* Set the small page TLB depth here */
parameter SPAGE_TLB_ENTRIES = 64;       // Entries.



endmodule
