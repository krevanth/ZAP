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
        parameter PHY_REGS = 46  // Number of physical registers.
)
(
        // Clock and reset.
        input wire                           i_clk, i_clk_2x,    // ZAP clock and 2x clock.
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
        input wire                           i_clear_from_decode,
        input wire      [31:0]               i_pc_from_decode,

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

        // Coprocessor.
        input wire                              i_copro_reg_en,

        input wire      [$clog2(PHY_REGS)-1:0]  i_copro_reg_wr_index,
        input wire      [$clog2(PHY_REGS)-1:0]  i_copro_reg_rd_index,

        input wire      [31:0]                  i_copro_reg_wr_data,

        output reg      [31:0]                  o_copro_reg_rd_data_ff,

        // Read data from the register file.
        output wire     [31:0]               o_rd_data_0,         
        output wire     [31:0]               o_rd_data_1,         
        output wire     [31:0]               o_rd_data_2,         
        output wire     [31:0]               o_rd_data_3,

        // Program counter (dedicated port).
        output reg      [31:0]               o_pc,

        // CPSR output
        output reg       [31:0]              o_cpsr_nxt,

        // Clear from writeback
        output reg                           o_clear_from_writeback,

        // Acks.
        output reg                           o_fiq_ack,
        output reg                           o_irq_ack
);

// Coprocessor accesses.
always @ (posedge i_clk) 
begin
        o_copro_reg_rd_data_ff = o_rd_data_0;
end

localparam RST_VECTOR   = 32'h00000000;
localparam UND_VECTOR   = 32'h00000004;
localparam SWI_VECTOR   = 32'h00000008;
localparam PABT_VECTOR  = 32'h0000000C;
localparam DABT_VECTOR  = 32'h00000010;
localparam IRQ_VECTOR   = 32'h00000018;
localparam FIQ_VECTOR   = 32'h0000001C;

`include "regs.vh"
`include "modes.vh"
`include "cpsr.vh"

// PC and CPSR are separate registers.
reg     [31:0]  cpsr_ff, cpsr_nxt;
reg     [31:0]  pc_ff, pc_nxt;

// CPSR dedicated output.
always @*
begin
        o_pc            = pc_ff;
        o_cpsr_nxt      = cpsr_nxt;
end

reg [$clog2(PHY_REGS)-1:0]     wa1, wa2;
reg [31:0]                     wdata1, wdata2;
reg                            wen;

`ifdef ASIC
        ram u_ram
        (
                .i_clk          (       i_clk           ),

                .i_reset        (       i_reset         ),       
 
                .i_wr_addr_a    (       wa1             ),
                .i_wr_addr_b    (       wa2             ),
        
                .i_wr_data_a    (       wdata1          ),
                .i_wr_data_b    (       wdata2          ),
        
                .i_wen          (       wen             ),        
        
                .i_rd_addr_a    ( i_copro_reg_en ? i_copro_reg_rd_index : i_rd_index_0 ),
                .i_rd_addr_b    (       i_rd_index_1    ),
                .i_rd_addr_c    (       i_rd_index_2    ),
                .i_rd_addr_d    (       i_rd_index_3    ),
        
                .o_rd_data_a    (       o_rd_data_0     ),
                .o_rd_data_b    (       o_rd_data_1     ),
                .o_rd_data_c    (       o_rd_data_2     ),
                .o_rd_data_d    (       o_rd_data_3     )
        );
`elsif FPGA
        bram_wrapper u_bram_wrapper
        (
                .i_clk          (       i_clk           ),
                .i_clk_2x       (       i_clk_2x        ),

                .i_reset        (       i_reset         ),       
 
                .i_wr_addr_a    (       wa1             ),
                .i_wr_addr_b    (       wa2             ),
        
                .i_wr_data_a    (       wdata1          ),
                .i_wr_data_b    (       wdata2          ),
        
                .i_wen          (       wen             ),        
        
                .i_rd_addr_a    ( i_copro_reg_en ? i_copro_reg_rd_index : i_rd_index_0 ),
                .i_rd_addr_b    (       i_rd_index_1    ),
                .i_rd_addr_c    (       i_rd_index_2    ),
                .i_rd_addr_d    (       i_rd_index_3    ),
        
                .o_rd_data_a    (       o_rd_data_0     ),
                .o_rd_data_b    (       o_rd_data_1     ),
                .o_rd_data_c    (       o_rd_data_2     ),
                .o_rd_data_d    (       o_rd_data_3     )
);
`else
initial
begin
        `ifdef SIM
        $display($time, "Please define either ASIC or FPGA...");
        `endif
        $finish;
end
`endif

// The register file function.
always @*
begin: blk1

        integer i;

        wen = 1'd0;
        wa1 = PHY_RAZ_REGISTER;
        wa2 = PHY_RAZ_REGISTER;
        wdata1 = 32'd0;
        wdata2 = 32'd0;

        o_clear_from_writeback = 0;
        o_fiq_ack = 0;
        o_irq_ack = 0;

        pc_nxt = pc_ff;
        cpsr_nxt = cpsr_ff;

        `ifdef SIM
                $display($time, "PC_nxt before = %d", pc_nxt);
        `endif

        // PC control sequence.
        if ( i_data_stall )
        begin
                pc_nxt = pc_ff;                        
                $display("Data Stall!");
        end
        else if ( i_clear_from_alu )
        begin
                pc_nxt = i_pc_from_alu;
                $display("Clear from ALU!");
        end
        else if ( i_stall_from_issue )
        begin
                pc_nxt = pc_ff;
                $display("Stall from issue!");
        end
        else if ( i_stall_from_shifter )
        begin
                pc_nxt = pc_ff;
                $display("Stall from shifter!");
        end
        else if ( i_clear_from_decode )
        begin
                pc_nxt = i_pc_from_decode;
                $display("Clear from decode!");
        end
        else if ( i_stall_from_decode )
        begin
                pc_nxt = pc_ff;
                $display("Stall from decode!");
        end
        else if ( i_code_stall )
        begin
                pc_nxt = pc_ff;
                $display("Code Stall!");
        end
        else
        begin
                $display("Normal PC update!");
                // Based on ARM or Thumb, we decide how much to increment.
                pc_nxt = pc_ff + ((cpsr_ff[T]) ? 32'd2 : 32'd4);
        end

        `ifdef SIM
        $display($time, "PC_nxt after = %d", pc_nxt);
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
                cpsr_nxt[I]      = 1'd1; // Mask interrupts.
                cpsr_nxt[T]      = 1'd0; // Go to ARM mode.
                $display("Interrupt detected! Clearing from writeback...");
        end
                

        if ( i_data_abt )
        begin
                // Returns do LR - 8 to get back to the same instruction.
                pc_nxt                   = DABT_VECTOR; 
                wen    = 1;
                wdata1 = (!cpsr_ff[T]) ? i_pc_buf_ff : (i_pc_buf_ff + 32'd4);
                wa1    = PHY_ABT_R14;
                wa2    = PHY_ABT_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = ABT;
        end
        else if ( i_fiq )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                pc_nxt = FIQ_VECTOR; 
                wen    = 1;
                wdata1 = (!cpsr_ff[T]) ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_FIQ_R14;
                wa2    = PHY_FIQ_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = FIQ;
                o_fiq_ack = 1'd1;
                cpsr_nxt[F] = 1'd1;
        end
        else if ( i_irq )
        begin
                pc_nxt = IRQ_VECTOR; 
                wen    = 1;
                wdata1 = (!cpsr_ff[T]) ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_IRQ_R14;
                wa2    = PHY_IRQ_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = IRQ;
                o_irq_ack = 1'd1;
                // Returns do LR - 4 to get back to the same instruction.
        end
        else if ( i_instr_abt )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                pc_nxt = PABT_VECTOR; 
                wen    = 1;
                wdata1 = (!cpsr_ff[T]) ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_ABT_R14;
                wa2    = PHY_ABT_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = ABT;
        end
        else if ( i_swi )
        begin
                // Returns do LR to return to the next instruction.
                pc_nxt = SWI_VECTOR; 
                wen    = 1;
                wdata1 = (!cpsr_ff[T]) ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_SVC_R14;
                wa2    = PHY_SVC_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = SVC;
        end
        else if ( i_und )
        begin
                // Returns do LR to return to the next instruction.
                pc_nxt = UND_VECTOR; 
                wen    = 1;
                wdata1 = (!cpsr_ff[T]) ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_UND_R14;
                wa2    = PHY_UND_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = UND;
        end
        else if ( i_copro_reg_en )
        begin
               // Write to register.
               wen      = 1;
               wa1      = i_copro_reg_wr_index;
               wdata1   = i_copro_reg_wr_data;
        end
        else if ( i_valid )
        begin
                // Only then execute the instruction at hand...
                cpsr_nxt                = (i_wr_index == ARCH_PC) ? i_wr_data_1 : 
                                          ( i_wr_index == PHY_CPSR ? i_wr_data : 
                                            ((i_wr_index_1 == PHY_CPSR && i_mem_load_ff) ? i_wr_data_1 : i_flags)
                                          );                 

                // Dual write port.
                wen    = 1;
                wa1    = i_wr_index;
                wa2    = i_mem_load_ff ? i_wr_index_1 : PHY_RAZ_REGISTER;
                wdata1 = i_wr_data;
                wdata2 = i_mem_load_ff ? i_wr_data_1 : 32'd0;

                // Update PC if needed.
                if ( i_wr_index == ARCH_PC )
                        pc_nxt = i_wr_data;
                else if ( i_mem_load_ff && i_wr_index_1 == ARCH_PC)
                        pc_nxt = i_wr_data_1;

                // A write to PC will trigger a clear from writeback.
                if ( i_wr_index == ARCH_PC || ( i_wr_index_1 == ARCH_PC && i_mem_load_ff) )
                        o_clear_from_writeback  = 1'd1;
        end

        `ifdef SIM
                $display("PC_nxt = %d", pc_nxt);
        `endif
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                // On reset, the CPU starts at 0 in
                // supervisor mode.
                pc_ff                      <= 32'd0;
                cpsr_ff                    <= SVC;
                cpsr_ff[I]                 <= 1'd1; // Mask IRQ.
                cpsr_ff[F]                 <= 1'd1; // Mask FIQ.
                cpsr_ff[T]                 <= 1'd0; // Start CPU in ARM mode.
        end
        else
        begin
                // Hard code lower bit of PC to 0.
                pc_ff   <= pc_nxt & 32'hfffffffe;

                // CPSR.
                cpsr_ff <= cpsr_nxt;
        end
end

endmodule
