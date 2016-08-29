`default_nettype none

// ============================================================================
// Filename --
// zap_register_file.v
//
// HDL --
// Verilog-2005
//
// Description --
// The ZAP register file. The register file is a typical RISC like structure
// with 46 x 32-bit registers. Intended to be implemented using flip-flops. 
// The register file provides dedicated ports for accessing the PC and CPSR
// registers. Atomic register updates for interrupt processing is done here.
//
// Copyright --
// (C) 2016 Revanth Kamaraj.
// ============================================================================

module zap_register_file #(
        parameter PHY_REGS  = 46 // Number of physical registers.
)
(
        // =====================================
        // Clock and reset.
        // =====================================
        input wire                           i_clk,     // ZAP clock.
        input wire                           i_reset,   // ZAP reset.

        // ======================================
        // Inputs from memory unit valid signal.
        // ======================================
        input wire                           i_valid,

        // ====================================================================
        // The PC can either be frozen in place or changed based on signals
        // from other units. If a unit clears the PC, it must provide the
        // appropriate new value.
        // ====================================================================
        input wire                           i_data_stall,
        input wire                           i_clear_from_alu,
        input wire      [31:0]               i_pc_from_alu,
        input wire                           i_stall_from_decode,
        input wire                           i_stall_from_issue,

        // =======================================
        // Configurable intertupt vector positions.
        // =======================================
        input wire      [31:0]              i_data_abort_vector,
        input wire      [31:0]              i_fiq_vector,
        input wire      [31:0]              i_irq_vector,
        input wire      [31:0]              i_instruction_abort_vector,
        input wire      [31:0]              i_swi_vector,
        input wire      [31:0]              i_und_vector,

        // =======================================
        // 4 read ports for high performance.
        // =======================================
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_0, 
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_1, 
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_2, 
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_3,

        // ========================================
        // Write index and data and flag updates.
        // ========================================
        input   wire    [$clog2(PHY_REGS)-1:0] i_wr_index,
        input   wire    [31:0]                 i_wr_data,
        input   wire    [3:0]                  i_flags,

        // ========================================
        // Interrupt indicators.
        // ========================================
        input   wire                         i_irq,
        input   wire                         i_fiq,
        input   wire                         i_instr_abt,
        input   wire                         i_data_abt,
        input   wire                         i_swi,    
        input   wire                         i_und,

        // ==============================================================
        // Program counter, PC + 8. The PC read from the issue stage is
        // buffered all the way through until this point to give PC+8.
        // ==============================================================
        input   wire    [31:0]               i_pc_buf_ff,

        // ========================================
        // Read data from the register file.
        // ========================================
        output reg      [31:0]               o_rd_data_0,         
        output reg      [31:0]               o_rd_data_1,         
        output reg      [31:0]               o_rd_data_2,         
        output reg      [31:0]               o_rd_data_3,

        // =========================================
        // Program counter (dedicated port).
        // =========================================
        output reg      [31:0]               o_pc,

        // =========================================
        // CPSR output
        // =========================================
        output reg       [31:0]              o_cpsr,

        // ================================================================
        // Data abort ack. This will reenable data memory after a fault.
        // ================================================================
        output reg                           o_data_abt_ack
);

`include "regs.vh"
`include "modes.vh"

// =========================
// Register file.
// =========================
reg     [31:0]  r_ff       [PHY_REGS-1:0];
reg     [31:0]  r_nxt      [PHY_REGS-1:0];

// ===========================
// CPSR dedicated output.
// ===========================
always @*
begin
        o_cpsr = r_ff[PHY_CPSR];
end

// ===========================
// 4 read decoders.
// ===========================
always @*
begin
        o_rd_data_0 = r_ff [ i_rd_index_0 ];
        o_rd_data_1 = r_ff [ i_rd_index_1 ];
        o_rd_data_2 = r_ff [ i_rd_index_2 ];
        o_rd_data_3 = r_ff [ i_rd_index_3 ];
end

// ===========================
// The register file function.
// ===========================
always @*
begin: blk1

        integer i;

        for ( i=0 ; i<PHY_REGS ; i=i+1 )
                r_nxt[i] = r_ff[i];

        // =====================================
        // PC control sequence.
        // =====================================
        if ( i_data_stall )
                r_nxt[PHY_PC] = r_ff[PHY_PC];                        
        else if ( i_clear_from_alu )
                r_nxt[PHY_PC] = i_pc_from_alu;
        else if ( i_stall_from_decode )
                r_nxt[PHY_PC] = r_ff[PHY_PC];
        else if ( i_stall_from_issue )
                r_nxt[PHY_PC] = r_ff[PHY_PC];

        // ====================================================================
        // The stuff below has more priority than the above. This means even in
        // a global stall, interrupts can overtake execution. Further, writes to 
        // PC that reach writeback can cancel a global stall. On interrupts or 
        // jumps, all units are flushed effectively clearing any global stalls.
        // ====================================================================

        if ( i_data_abt )
        begin
                // ===========================================================
                // Returns do LR - 8 to get back to the same instruction.
                // ===========================================================
                r_nxt[PHY_PC]           = i_data_abort_vector; 
                r_nxt[PHY_ABT_R14]      = i_pc_buf_ff;
                r_nxt[PHY_ABT_SPSR]     = r_ff[PHY_CPSR];
        end
        else if ( i_fiq )
        begin
                // ===========================================================
                // Returns do LR - 4 to get back to the same instruction.
                // ===========================================================
                r_nxt[PHY_PC]           = i_fiq_vector;
                r_nxt[PHY_FIQ_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_FIQ_SPSR]     = r_ff[PHY_CPSR];
        end
        else if ( i_irq )
        begin
                // ==========================================================
                // Returns do LR - 4 to get back to the same instruction.
                // ==========================================================
                r_nxt[PHY_PC]           = i_irq_vector;
                r_nxt[PHY_IRQ_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_IRQ_SPSR]     = r_ff[PHY_CPSR];
        end
        else if ( i_instr_abt )
        begin
                // ==========================================================
                // Returns do LR - 4 to get back to the same instruction.
                // ==========================================================
                r_nxt[PHY_PC]           = i_instruction_abort_vector;
                r_nxt[PHY_ABT_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_ABT_SPSR]     = r_ff[PHY_CPSR];
        end
        else if ( i_swi )
        begin
                // =====================================================
                // Returns do LR to return to the next instruction.
                // =====================================================
                r_nxt[PHY_PC]           = i_swi_vector;
                r_nxt[PHY_SWI_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_SWI_SPSR]     = r_ff[PHY_CPSR];
        end
        else if ( i_und )
        begin
                // ======================================================
                // Returns do LR to get back to the same instruction.
                // ======================================================
                r_nxt[PHY_PC]           = i_und_vector;
                r_nxt[PHY_FIQ_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_FIQ_SPSR]     = r_ff[PHY_CPSR];
        end
        else
        begin
                // ================================================
                // Only then execute the instruction at hand...
                // ================================================
                r_nxt[PHY_CPSR]         = i_flags;                 
                r_nxt[i_wr_index]       = i_wr_data;
        end
end

// ==========================
// Sequential Logic.
// ==========================
always @ (posedge i_clk)
begin
        if ( i_rst )
        begin: rstBlk
                // =================================
                // On reset, the CPU starts at 0 in
                // supervisor mode.
                // =================================
                r_ff[PHY_PC]            <= 32'd0;
                r_ff[PHY_CPSR][4:0]     <= SVC;
        end
        begin: otherBlock
                integer i;

                for(i=0;i<PHY_REGS;i=i+1)
                        r_ff[i] <= r_nxt[i];
        end
end

endmodule
