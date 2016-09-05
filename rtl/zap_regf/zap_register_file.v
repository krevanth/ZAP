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

 Define REG_DEBUG to turn on debugging messages.

 Copyright --
 (C) 2016 Revanth Kamaraj.
*/

module zap_register_file #(
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
        input   wire [3:0]                  i_flags,
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

        // Clear from writeback
        output reg                           o_clear_from_writeback,

        // Acks.
        output reg                           o_fiq_ack,
        output reg                           o_irq_ack
);

`include "regs.vh"
`include "modes.vh"
`include "cpsr.vh"

// Register file.
reg     [31:0]  r_ff       [PHY_REGS-1:0];
reg     [31:0]  r_nxt      [PHY_REGS-1:0];

`ifdef REG_DEBUG
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

        for ( i=0 ; i<PHY_REGS ; i=i+1 )
                r_nxt[i] = r_ff[i];

        `ifdef REG_DEBUG
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

        `ifdef REG_DEBUG
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
                o_clear_from_writeback = 1'd1;
                $display("Interrupt detected! Clearing from writeback...");
        end
                

        if ( i_data_abt )
        begin
                // Returns do LR - 8 to get back to the same instruction.
                r_nxt[PHY_PC]           = i_data_abort_vector; 
                r_nxt[PHY_ABT_R14]      = i_pc_buf_ff;
                r_nxt[PHY_ABT_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = ABT;
        end
        else if ( i_fiq )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                r_nxt[PHY_PC]           = i_fiq_vector;
                r_nxt[PHY_FIQ_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_FIQ_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = FIQ;
                o_fiq_ack = 1;
        end
        else if ( i_irq )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                r_nxt[PHY_PC]           = i_irq_vector;
                r_nxt[PHY_IRQ_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_IRQ_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = IRQ;
                o_irq_ack = 1;
        end
        else if ( i_instr_abt )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                r_nxt[PHY_PC]           = i_instruction_abort_vector;
                r_nxt[PHY_ABT_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_ABT_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = ABT;
        end
        else if ( i_swi )
        begin
                // Returns do LR to return to the next instruction.
                r_nxt[PHY_PC]           = i_swi_vector;
                r_nxt[PHY_SVC_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_SVC_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = SVC;
        end
        else if ( i_und )
        begin
                // Returns do LR to get back to the same instruction.
                r_nxt[PHY_PC]           = i_und_vector;
                r_nxt[PHY_FIQ_R14]      = i_pc_buf_ff - 32'd4;
                r_nxt[PHY_FIQ_SPSR]     = r_ff[PHY_CPSR];
                r_nxt[PHY_CPSR][`CPSR_MODE] = UND;
        end
        else if ( i_valid )
        begin
                // Only then execute the instruction at hand...
                r_nxt[PHY_CPSR][31:28]  = i_flags;                 
                r_nxt[i_wr_index]       = i_wr_data;

                if ( i_mem_load_ff )
                        r_nxt[i_wr_index_1]     = i_wr_data_1;

                // Note that if we are writing to CPSR and if CPSR[4:0] == USR,
                // we maintain it the same way. Thus, user cannot change interrupt
                // controls or change processor mode...
                if ( r_ff[PHY_CPSR][`CPSR_MODE] == USR )
                begin
                        r_nxt[PHY_CPSR][7:0] = r_ff[PHY_CPSR][7:0]; // Don't change LOWER byte.
                end
                else if (       i_wr_index == PHY_CPSR && 
                                r_ff[PHY_CPSR][7:0] != i_wr_data[7:0] ) // Mode, interrupt change.
                begin
                        // Flush instructions currently in the pipeline.
                        o_clear_from_writeback = 1'd1;

                        // Provide a new PC.
                        r_nxt[PHY_PC] = i_pc_buf_ff - 32'd4; // Goes to the next instruction.
                end

                // Also if writes to PC change LSB, we change to Thumb mode.
                if ( r_nxt[PHY_PC][0] )
                begin
                        r_nxt[PHY_CPSR][T] = 1'd1; // Set T bit.
                        $display("Executing in Thumb mode...!");
                end
                else
                begin
                        r_nxt[PHY_CPSR][T] = 1'd0; // Clear T bit.
                        $display("Executing in ARM mode...!");
                end

                // A write to PC will trigger a clear from writeback.
                // PC writes reach this only if flag update bit is set.
                if ( i_wr_index == ARCH_PC )
                begin
                        // If flag update is set, then restore state.
                        if ( i_flag_update_ff )
                        begin

                                `ifdef REG_DEBUG
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
                        else
                        begin
                                $display("Register File :: PC reached without flag update! Check RTL!");
                                $finish;
                        end

                        o_clear_from_writeback = 1'd1;
                end

                // Independently check PC writes from other source.
                if ( i_wr_index_1 == ARCH_PC && i_mem_load_ff )
                begin
                        o_clear_from_writeback = 1'd1;
                end
        end

        `ifdef REG_DEBUG
                $display("PC_nxt = %d", r_nxt[15]);
        `endif

end

// Sequential Logic.
always @ (posedge i_clk)
begin
        if ( i_reset )
        begin: rstBlk

                integer i;

                $display("Register file in reset...");

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

        end
end

endmodule
