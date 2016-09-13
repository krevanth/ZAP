`default_nettype none

/* 
 Filename --
 zap_register_file.v

 HDL --
 Verilog-2005

 Description --
 The ZAP register file. The register file is a memory structure
 with 46 x 32-bit registers. Intended to be implemented using flip-flops. 
 The register file provides dedicated ports for accessing the PC and CPSR
 registers. Atomic register updates for interrupt processing is done here.

 Define SIM to turn on debugging messages.

 Copyright --
 (C) 2016 Revanth Kamaraj.
*/

module zap_register_file #(
        parameter FLAG_WDT = 32, // Flags width a.k.a CPSR.
        parameter PHY_REGS  = 46 // Number of physical registers.
)
(
        // Clock and reset.
        input wire                           i_clk,     // ZAP clock.
        input wire                           i_reset,   // ZAP reset.

        // Inputs from memory unit valid signal.
        input wire                           i_valid,

        // The PC can either be frozen in place or changed based on signals
        // from other units. If a unit clears the PC, it must provide the
        // appropriate new value.
        input wire                           i_code_stall,
        input wire                           i_data_stall,
        input wire                           i_clear_from_alu,
        input wire      [31:0]               i_pc_from_alu,
        input wire                           i_stall_from_decode,
        input wire                           i_stall_from_issue,
        input wire                           i_stall_from_shifter,

        // Flag update.
        input wire                           i_flag_update_ff,

        // Configurable intertupt vector positions.
        input wire      [31:0]              i_data_abort_vector,
        input wire      [31:0]              i_fiq_vector,
        input wire      [31:0]              i_irq_vector,
        input wire      [31:0]              i_instruction_abort_vector,
        input wire      [31:0]              i_swi_vector,
        input wire      [31:0]              i_und_vector,

        // 4 read ports for high performance.
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_0, 
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_1, 
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_2, 
        input wire   [$clog2(PHY_REGS)-1:0] i_rd_index_3,

        // Memory load indicator.
        input wire                          i_mem_load_ff,

        // Write index and data and flag updates.
        input   wire [$clog2(PHY_REGS)-1:0] i_wr_index,
        input   wire [31:0]                 i_wr_data,
        input   wire [FLAG_WDT-1:0]         i_flags,
        input   wire [$clog2(PHY_REGS)-1:0] i_wr_index_1,
        input   wire [31:0]                 i_wr_data_1,

        // Interrupt indicators.
        input   wire                         i_irq,
        input   wire                         i_fiq,
        input   wire                         i_instr_abt,
        input   wire                         i_data_abt,
        input   wire                         i_swi,    
        input   wire                         i_und,

        // Program counter, PC + 8. This value is captured in the fetch
        // stage and is buffered all the way through.
        input   wire    [31:0]               i_pc_buf_ff,

        // Read data from the register file.
        output reg      [31:0]               o_rd_data_0,         
        output reg      [31:0]               o_rd_data_1,         
        output reg      [31:0]               o_rd_data_2,         
        output reg      [31:0]               o_rd_data_3,

        // Program counter (dedicated port).
        output reg      [31:0]               o_pc,

        // CPSR output
        output reg       [31:0]              o_cpsr,
        output wire      [31:0]              o_cpsr_nxt,

        // Clear from writeback
        output reg                           o_clear_from_writeback,

        // Acks.
        output reg                           o_fiq_ack,
        output reg                           o_irq_ack,

        // CP15 registers. Connect these to MMU (ARM v4 System Control Coprocessor).
        output reg [31:0]                   o_cp15_r0_id_reg_ro,        // ID register.                 - CP15_R0
        output reg [31:0]                   o_cp15_r1_control_rw,       // Control register.            - CP15_R1
        output reg [31:0]                   o_cp15_r2_ttbase_rw,        // Translation table base.      - CP15_R2
        output reg [31:0]                   o_cp15_r3_dac_rw,           // Domain access control.       - CP15_R3
        output reg [31:0]                   o_cp15_r5_fsr_ro,           // Fault status register.       - CP15_R5
        output reg [31:0]                   o_cp15_r6_far_ro,           // Fault address register.      - CP15_R6
        output reg [31:0]                   o_cp15_r7_cacheops_wo,      // Write 0 to flush I-D cache.  - CP15_R7
        output reg [31:0]                   o_cp15_r8_tlbops_wo,        // Write 0 to flush I-D TLB.    - CP15_R8

        // FSR and FAR may be updated by CP15 coprocessor.
        input wire [31:0]                    i_fsr,
        input wire                           i_fsr_dav,
        input wire [31:0]                    i_far,
        input wire                           i_far_dav   
);

`include "regs.vh"
`include "modes.vh"
`include "cpsr.vh"

// Register file.
reg     [31:0]  r_ff       [PHY_REGS-1:0];
reg     [31:0]  r_nxt      [PHY_REGS-1:0];

// Connect CP15 registers.
always @*
begin
        o_cp15_r0_id_reg_ro   = r_ff[CP15_R0];
        o_cp15_r1_control_rw  = r_ff[CP15_R1];
        o_cp15_r2_ttbase_rw   = r_ff[CP15_R2];
        o_cp15_r3_dac_rw      = r_ff[CP15_R3];
        o_cp15_r5_fsr_ro      = r_ff[CP15_R5];
        o_cp15_r6_far_ro      = r_ff[CP15_R6];
        o_cp15_r7_cacheops_wo = r_ff[CP15_R7];
        o_cp15_r8_tlbops_wo   = r_ff[CP15_R8];
end

assign o_cpsr_nxt = r_nxt[PHY_CPSR];

`ifdef SIM
always @ (posedge i_clk)
begin
        $monitor($time, "PC next = %d PC current = %d", r_nxt[15], r_ff[15]);
end
`endif

// CPSR dedicated output.
always @*
begin
        o_cpsr = r_ff[PHY_CPSR];
        o_pc   = r_ff[PHY_PC];
end

// 4 read decoders.
always @*
begin
        o_rd_data_0 = r_ff [ i_rd_index_0 ];
        o_rd_data_1 = r_ff [ i_rd_index_1 ];
        o_rd_data_2 = r_ff [ i_rd_index_2 ];
        o_rd_data_3 = r_ff [ i_rd_index_3 ];
end

// The register file function.
always @*
begin: blk1

        integer i;

        o_clear_from_writeback = 0;
        o_fiq_ack = 0;
        o_irq_ack = 0;

        // Avoid latch inference.
        for ( i=0 ; i<PHY_REGS ; i=i+1 )
                r_nxt[i] = r_ff[i];

        // Write all 1s to CP15_R6 and CP15_R7. MMU must trigger only when it all goes to 0 for 1 cycle.
        r_nxt[CP15_R7] = 32'hffff_ffff;
        r_nxt[CP15_R8] = 32'hffff_ffff;

        // CP15 can update FSR and FAR.
        if ( i_far_dav )
        begin
                r_nxt[CP15_R6] = i_far;
        end

        if ( i_fsr_dav )
        begin
                r_nxt[CP15_R5] = i_fsr;
        end

        `ifdef SIM
        $display($time, "PC_nxt before = %d", r_nxt[PHY_PC]);
        `endif

        // PC control sequence.
        if ( i_code_stall )
        begin
                r_nxt[PHY_PC] = r_ff[PHY_PC];
                $display("Code Stall!");
        end
        else if ( i_data_stall )
        begin
                r_nxt[PHY_PC] = r_ff[PHY_PC];                        
                $display("Data Stall!");
        end
        else if ( i_clear_from_alu )
        begin
                r_nxt[PHY_PC] = i_pc_from_alu;
                $display("Clear from ALU!");
        end
        else if ( i_stall_from_decode )
        begin
                r_nxt[PHY_PC] = r_ff[PHY_PC];
                $display("Stall from decode!");
        end
        else if ( i_stall_from_issue )
        begin
                r_nxt[PHY_PC] = r_ff[PHY_PC];
                $display("Stall from issue!");
        end
        else if ( i_stall_from_shifter )
        begin
                r_nxt[PHY_PC] = r_ff[PHY_PC];
                $display("Stall from shifter!");
        end
        else
        begin
                $display("Normal PC update!");
                // Based on ARM or Thumb, we decide how much to increment.
                r_nxt[PHY_PC] = r_ff[PHY_PC] + ((r_ff[PHY_CPSR][T]) ? 32'd2 : 32'd4);
        end

        `ifdef SIM
        $display($time, "PC_nxt after = %d", r_nxt[PHY_PC]);
        `endif

        // The stuff below has more priority than the above. This means even in
        // a global stall, interrupts can overtake execution. Further, writes to 
        // PC that reach writeback can cancel a global stall. On interrupts or 
        // jumps, all units are flushed effectively clearing any global stalls.

        if ( i_data_abt         || 
                i_fiq           || 
                i_irq           || 
                i_instr_abt     || 
                i_swi           ||
                i_und )
        begin
                o_clear_from_writeback  = 1'd1;
                r_nxt[PHY_CPSR][I]      = 1'd1; // Mask interrupts.
                r_nxt[PHY_CPSR][T]      = 1'd0; // Go to ARM mode.
                $display("Interrupt detected! Clearing from writeback...");
        end
                

        if ( i_data_abt )
        begin
                // Returns do LR - 8 to get back to the same instruction.
                r_nxt[PHY_PC]                   = i_data_abort_vector; 

                if ( !r_ff[PHY_CPSR][T] ) // ARM mode.
                        r_nxt[PHY_ABT_R14]              = i_pc_buf_ff;
                else
                        r_nxt[PHY_ABT_R14]              = i_pc_buf_ff + 32'd4;

                r_nxt[PHY_ABT_SPSR]             = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE]     = ABT;
                r_nxt[PHY_CPSR][I]              = 1'd1; 
        end
        else if ( i_fiq )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                r_nxt[PHY_PC]                   = i_fiq_vector;

                if ( !r_ff[PHY_CPSR][T] ) // ARM mode.
                        r_nxt[PHY_FIQ_R14]              = i_pc_buf_ff - 32'd4;
                else
                        r_nxt[PHY_FIQ_R14]              = i_pc_buf_ff;

                r_nxt[PHY_FIQ_SPSR]             = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE]     = FIQ;
                r_nxt[PHY_CPSR][I]              = 1'd1;
                r_nxt[PHY_CPSR][F]              = 1'd1; // Mask FIQ too.
                o_fiq_ack = 1;
        end
        else if ( i_irq )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                r_nxt[PHY_PC]           = i_irq_vector;

                if ( !r_ff[PHY_CPSR][T] ) // ARM mode.
                        r_nxt[PHY_IRQ_R14]      = i_pc_buf_ff - 32'd4;
                else
                        r_nxt[PHY_IRQ_R14]      = i_pc_buf_ff;

                r_nxt[PHY_IRQ_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = IRQ;
                r_nxt[PHY_CPSR][I]      = 1'd1;
                o_irq_ack = 1;
        end
        else if ( i_instr_abt )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                r_nxt[PHY_PC]                   = i_instruction_abort_vector;

                if ( !r_ff[PHY_CPSR][T] ) // ARM mode.
                        r_nxt[PHY_ABT_R14]              = i_pc_buf_ff - 32'd4;
                else
                        r_nxt[PHY_ABT_R14]              = i_pc_buf_ff;

                r_nxt[PHY_ABT_SPSR]             = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE]     = ABT;
                r_nxt[PHY_CPSR][I]              = 1'd1;
        end
        else if ( i_swi )
        begin
                // Returns do LR to return to the next instruction.
                r_nxt[PHY_PC]                   = i_swi_vector;

                if ( !r_ff[PHY_CPSR][T] ) // ARM mode.
                        r_nxt[PHY_SVC_R14]              = i_pc_buf_ff - 32'd4;
                else            
                        r_nxt[PHY_SVC_R14]              = i_pc_buf_ff;

                r_nxt[PHY_SVC_SPSR]             = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE]     = SVC;
                r_nxt[PHY_CPSR][I]              = 1'd1;
        end
        else if ( i_und )
        begin
                // Returns do LR to get back to the same instruction.
                r_nxt[PHY_PC]                   = i_und_vector;

                if ( !r_ff[PHY_CPSR][T] ) // ARM mode.
                        r_nxt[PHY_FIQ_R14]              = i_pc_buf_ff - 32'd4;
                else
                        r_nxt[PHY_FIQ_R14]              = i_pc_buf_ff;

                r_nxt[PHY_FIQ_SPSR]             = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE]     = UND;
                r_nxt[PHY_CPSR][I]              = 1'd1;
        end
        else if ( i_valid )
        begin
                // Only then execute the instruction at hand...
                r_nxt[PHY_CPSR]         = i_flags;                 
                r_nxt[i_wr_index]       = i_wr_data;

                if ( i_mem_load_ff )
                        r_nxt[i_wr_index_1]     = i_wr_data_1;

                // A write to PC will trigger a clear from writeback.
                // PC writes reach this only if flag update bit is set.
                if ( i_wr_index == ARCH_PC )
                begin
                        // If flag update is set, then restore state.
                        if ( i_flag_update_ff )
                        begin

                                `ifdef SIM
                                        $display($time, "Restoring mode...");
                                `endif

                                // Restore mode.
                                case ( r_ff[PHY_CPSR][`CPSR_MODE] )
                                        FIQ: r_nxt[PHY_CPSR] = r_ff[PHY_FIQ_SPSR]; 
                                        IRQ: r_nxt[PHY_CPSR] = r_ff[PHY_IRQ_SPSR]; 
                                        UND: r_nxt[PHY_CPSR] = r_ff[PHY_UND_SPSR];
                                        ABT: r_nxt[PHY_CPSR] = r_ff[PHY_ABT_SPSR];
                                        SVC: r_nxt[PHY_CPSR] = r_ff[PHY_SVC_SPSR];
                                endcase
                        end
                        else /* Architecture should not allow this to happen. No latch inference since regs are looped at the start. */
                        begin
                                `ifdef SIM
                                        $display($time, "Register File :: PC reached without flag update! Check RTL!");
                                        $stop;
                                `endif
                        end

                        o_clear_from_writeback = 1'd1;
                end

                // Independently check PC writes from other source.
                if ( i_wr_index_1 == ARCH_PC && i_mem_load_ff )
                begin
                        o_clear_from_writeback = 1'd1;
                end
        end

        `ifdef SIM
                $display("PC_nxt = %d", r_nxt[15]);
        `endif
end

// Sequential Logic.
always @ (posedge i_clk)
begin
        if ( i_reset )
        begin: rstBlk

                integer i;

                `ifdef SIM
                        $display($time, "Register file in reset...");
                `endif

                for(i=0;i<PHY_REGS;i=i+1)
                        r_ff[i] <= 32'd0;

                // On reset, the CPU starts at 0 in
                // supervisor mode.
                r_ff[PHY_PC]            <= 32'd0;
                r_ff[PHY_CPSR]          <= SVC;
        end
        else 
        begin: otherBlock
                integer i;

                for(i=0;i<PHY_REGS;i=i+1)
                        r_ff[i] <= r_nxt[i];

                // Hard code lower bit of PC to 0.
                r_ff[PHY_PC][0] <= 1'd0;
        end
end

endmodule
