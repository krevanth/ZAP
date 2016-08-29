module zap_memory_stage
#(
        parameter PHY_REGS = 32
)
(
        // ===========================================
        // Inputs 
        // ===========================================
        input wire                          i_clk,
        input wire                          i_reset,
        input wire                          i_clear_from_writeback,
        input wire                          i_data_stall,
        input wire [31:0]                   i_alu_result_ff,
        input wire [8:0]                    i_mem_magic_number_ff,      
        input wire                          i_dav_ff,
        input wire [31:0]                   i_pc_plus_8_ff,
        input wire [31:0]                   i_mem_address_ff,           // Memory addresss sent. 
        input wire [$clog2(PHY_REGS)-1:0]   i_destination_index_ff,
        input wire [4:0]                    i_interrupt_vector_ff,      // { DABT IRQ FIQ IABT SWI }
        input wire [$clog2(PHY_REGS)-1:0]   i_mem_srcdest_index_ff,
        input wire [31:0]                   i_mem_srcdest_val_ff,       // Loads use this.
        input wire                          i_data_abort,
        input wire [31:0]                   i_mem_data,

        // ==========================================
        // Outputs.
        // ==========================================
        output reg  [31:0]                   o_alu_result_ff,
        output reg [31:0]                    o_mem_srcdest_val_ff,   // Loaded value.    
        output reg [$clog2(PHY_REGS)-1:0]    o_destination_index_ff,
        output reg [$clog2(PHY_REGS)-1:0]    o_mem_srcdest_index_ff,
        output reg                           o_dav_ff,
        output reg                           o_pc_plus_8_ff,
        output reg                           o_mem_load_ff,          // Also goes to memory unit.
        output reg  [4:0]                    o_interrupt_vector_ff

        // This goes to memory unit.
        output reg                           o_mem_pre_index_ff,
        output reg                           o_mem_unsigned_byte_enable_ff,
        output reg                           o_mem_signed_byte_enable_ff,
        output reg                           o_mem_signed_halfword_enable_ff,
        output reg                           o_mem_unsigned_halfword_enable_ff,
        output reg                           o_mem_translate_ff,
        output reg                           o_mem_store_ff,
        output reg                           o_force_locked_access_ff,
        output reg [31:0]                    o_mem_data,        // For stores.
        output reg                           o_freeze_ff,
        output reg [31:0]                    o_mem_address_ff
);

`include "regs.vh"

// ==================================
// Break the memory magic number
// ==================================
always @ (posedge i_clk)
if ( i_reset )
begin
        o_dav_ff        <= 1'd0;
        o_mem_load_ff   <= 1'd0;
        o_mem_store_ff  <= 1'd0;
end
else if ( i_clear_from_writeback )
begin
        o_dav_ff        <= 1'd0;
        o_mem_load_ff   <= 1'd0;
        o_mem_store_ff  <= 1'd0;
end
else if ( i_data_stall )
begin
        // Stall unit.
end
else
begin
        { o_mem_load_ff,                     
          o_mem_store_ff,
          o_mem_pre_index_ff,                
          o_mem_unsigned_byte_enable_ff,     
          o_mem_signed_byte_enable_ff,       
          o_mem_signed_halfword_enable_ff,
          o_mem_unsigned_halfword_enable_ff,
          o_mem_translate_ff,                
          o_force_locked_access_ff } <= i_mem_magic_number_ff;
        
        o_interrupt_vector_ff <= { i_data_abort, i_interrupt_vector_ff }; 
        o_alu_result_ff       <= i_alu_result_ff;
        o_mem_srcdest_index_ff<= i_mem_srcdest_index_ff;
        o_mem_data            <= i_mem_srcdest_val_ff;
        o_mem_srcdest_val_ff  <= i_mem_data;
        o_dav_ff              <= freeze_nxt ? 1'd0 : i_dav_ff;
        o_destination_index_ff<= i_destination_index_ff;
        o_pc_plus_8_ff        <= i_pc_plus_8_ff;
        o_mem_address_ff      <= i_mem_address_ff;
end

// ===========================================================================
// If freeze_ff = 1 (freeze_nxt too), then o_load_ff and o_store_ff will be
// tied off to zero preventing further memory opertions.
// ============================================================================

reg freeze_nxt;

always @ (posedge i_clk)
begin
       o_freeze_ff <= freeze_nxt; 
end

always @*
begin
        if ( i_reset )
                freeze_nxt = 1'd0;
        else if ( i_clear_from_writeback )
                freeze_nxt = 1'd0;
        else if ( i_data_stall )
        begin
                //Hold values.
                freeze_nxt = o_freeze_ff;
        end
        // -----------------------
        // Compute freeze.
        // -----------------------
        else if ( (  i_destination_index_ff == ARCH_PC   || 
                i_destination_index_ff == ARCH_CPSR || 
                i_interrupt_vector_ff || i_data_abort) && i_dav_ff )
                freeze_nxt = 1;
        else
                freeze_nxt = o_freeze_ff;
end

endmodule
