// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_register_file.v
// HDL          : Verilog-2001
// Module       : zap_register_file
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// The ZAP register file.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high reset
// Clock        : Core clock, 2 x Core clock
// Depends      : zap_regf_bram_wrapper       
// ----------------------------------------------------------------------------

`default_nettype none

module zap_register_file #(
        parameter FLAG_WDT = 32, // Flags width a.k.a CPSR.
        parameter PHY_REGS = 46  // Number of physical registers.
)
(
        // Shelve output.
        output wire                          o_shelve,

        // Clock and reset.
        input wire                           i_clk, 

        input wire                           i_clk_multipump,    // ZAP clock and 2x clock.

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
        output reg      [31:0]               o_pc_nxt,

        // CPSR output
        output reg       [31:0]              o_cpsr_nxt,

        // Clear from writeback
        output reg                           o_clear_from_writeback,

        // Hijack I/F
        output reg    [31:0]                  o_hijack_op1,
        output reg    [31:0]                  o_hijack_op2,
        output reg                            o_hijack_cin,
        output reg                            o_hijack,
        input wire     [31:0]                 i_hijack_sum
);

///////////////////////////////////////////////////////////////////////////////

assign o_shelve = shelve_ff;

`ifdef SIM

reg fiq_ack;
reg irq_ack;
reg und_ack;
reg dabt_ack;
reg iabt_ack;
reg swi_ack;

`endif

// PC and CPSR are separate registers.
reg     [31:0]  cpsr_ff, cpsr_nxt;
reg     [31:0]  pc_ff, pc_nxt;

reg [$clog2(PHY_REGS)-1:0]     wa1, wa2;
reg [31:0]                     wdata1, wdata2;
reg                            wen;

reg [31:0] pc_shelve_ff, pc_shelve_nxt;
reg shelve_ff, shelve_nxt;

`ifdef SIM
integer irq_addr = 0;
`endif

///////////////////////////////////////////////////////////////////////////////

// Coprocessor accesses.
always @ (posedge i_clk) 
begin
        o_copro_reg_rd_data_ff <= i_reset ? 0 : o_rd_data_0;
end

///////////////////////////////////////////////////////////////////////////////

localparam RST_VECTOR   = 32'h00000000;
localparam UND_VECTOR   = 32'h00000004;
localparam SWI_VECTOR   = 32'h00000008;
localparam PABT_VECTOR  = 32'h0000000C;
localparam DABT_VECTOR  = 32'h00000010;
localparam IRQ_VECTOR   = 32'h00000018;
localparam FIQ_VECTOR   = 32'h0000001C;

///////////////////////////////////////////////////////////////////////////////

`include "zap_defines.vh"
`include "zap_functions.vh"
`include "zap_localparams.vh"

///////////////////////////////////////////////////////////////////////////////

// CPSR dedicated output.
always @*
begin
        o_pc            = pc_ff;
        o_pc_nxt        = pc_nxt & 32'hfffffffe;
        o_cpsr_nxt      = cpsr_nxt;
end

///////////////////////////////////////////////////////////////////////////////

zap_regf_bram_wrapper u_bram_wrapper
(
 .i_clk_multipump(       i_clk_multipump ),

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

///////////////////////////////////////////////////////////////////////////////

`define ARM_MODE (cpsr_ff[T] == 1'd0)

`ifdef SIM
reg temp_set;
reg error;
initial error = 0;
initial temp_set = 0;
`endif

// The register file function.
always @*
begin: blk1

        integer i;

        shelve_nxt = shelve_ff;
        pc_shelve_nxt = pc_shelve_ff;



        `ifdef SIM
                fiq_ack = 0;
                irq_ack = 0;
                und_ack = 0;
                dabt_ack = 0;
                iabt_ack = 0;
                swi_ack = 0;
        `endif

        o_hijack    =  0;
        o_hijack_op1 = 0;
        o_hijack_op2 = 0;
        o_hijack_cin = 0;

        wen = 1'd0;
        wa1 = PHY_RAZ_REGISTER;
        wa2 = PHY_RAZ_REGISTER;
        wdata1 = 32'd0;
        wdata2 = 32'd0;

        o_clear_from_writeback = 0;

        pc_nxt = pc_ff;
        cpsr_nxt = cpsr_ff;

        `ifdef RF_DEBUG
                $display($time, "PC_nxt before = %d", pc_nxt);
        `endif

        // PC control sequence.
        //if ( i_data_stall )
        //begin
        //        pc_nxt = pc_ff;                        
        //end

        if ( i_clear_from_alu )
        begin
                pc_shelve(i_pc_from_alu);
        end
        //else if ( i_stall_from_issue )
        //begin
        //        pc_nxt = pc_ff;
        //end
        //else if ( i_stall_from_shifter )
        //begin
        //        pc_nxt = pc_ff;
        //end
        else if ( i_clear_from_decode )
        begin
                pc_shelve(i_pc_from_decode);
        end
        //else if ( i_stall_from_decode )
        //begin
        //        pc_nxt = pc_ff;
        //end
        else if ( i_code_stall )
        begin
                pc_nxt = pc_ff;
        end
        else if ( shelve_ff )
        begin
                `ifdef SIM
                        if ( temp_set == 1 )
                        begin
                                `ifdef RF_DEBUG
                                $display($time, "PAIR -> SHELVE_RET :: Returning to %d", pc_shelve_ff);
                                `endif

                                if ( pc_shelve_ff != 24 )
                                begin
                                        error = 1;
                                end

                                temp_set = 0;
                        end
                `endif

                pc_nxt     = pc_shelve_ff;
                shelve_nxt = 1'd0;
        end
        else
        begin
                pc_nxt = pc_ff + ((cpsr_ff[T]) ? 32'd2 : 32'd4);
        end

        `ifdef RF_DEBUG
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
        end
                

        if ( i_data_abt )
        begin
                o_hijack    =  1'd1;
                o_hijack_op1 = i_pc_buf_ff;
                o_hijack_op2 = 32'd4;
                o_hijack_cin = 1'd0;

                // Returns do LR - 8 to get back to the same instruction.
                pc_shelve( DABT_VECTOR ); 
                wen    = 1;
                wdata1 = `ARM_MODE ? i_pc_buf_ff : i_hijack_sum[31:0];
                wa1    = PHY_ABT_R14;
                wa2    = PHY_ABT_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = ABT;

                `ifdef SIM
                        dabt_ack = 1'd1;
                `endif

        end
        else if ( i_fiq )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                pc_shelve ( FIQ_VECTOR ); 
                wen    = 1;
                wdata1 = `ARM_MODE ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_FIQ_R14;
                wa2    = PHY_FIQ_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = FIQ;
                cpsr_nxt[F] = 1'd1;

                `ifdef SIM
                        fiq_ack = 1'd1;
                `endif
        end
        else if ( i_irq )
        begin
                pc_shelve (IRQ_VECTOR); 

                wen    = 1;
                wdata1 = `ARM_MODE ? i_wr_data : i_pc_buf_ff ;

                `ifdef SIM
                irq_addr = wdata1;
                `endif

                wa1    = PHY_IRQ_R14;
                wa2    = PHY_IRQ_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = IRQ;
                // Returns do LR - 4 to get back to the same instruction.

                `ifdef SIM
                irq_ack = 1'd1;
                if ( i_code_stall )
                begin
                        `ifdef RF_DEBUG
                        $display($time, "PAIR -> IRQ :: Entered IRQ with link register = %d", wdata1);
                        `endif
                        temp_set = 1;
                end
                else temp_set = 0;
                `endif
        end
        else if ( i_instr_abt )
        begin
                // Returns do LR - 4 to get back to the same instruction.
                pc_shelve (PABT_VECTOR); 
                wen    = 1;
                wdata1 = `ARM_MODE ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_ABT_R14;
                wa2    = PHY_ABT_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = ABT;

                `ifdef SIM
                        iabt_ack = 1'd1;
                `endif
        end
        else if ( i_swi )
        begin
                // Returns do LR to return to the next instruction.
                pc_shelve(SWI_VECTOR); 
                wen    = 1;
                wdata1 = `ARM_MODE ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_SVC_R14;
                wa2    = PHY_SVC_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = SVC;

                `ifdef SIM
                        swi_ack = 1'd1;
                `endif
        end
        else if ( i_und )
        begin
                // Returns do LR to return to the next instruction.
                pc_shelve(UND_VECTOR); 
                wen    = 1;
                wdata1 = `ARM_MODE ? i_wr_data : i_pc_buf_ff ;
                wa1    = PHY_UND_R14;
                wa2    = PHY_UND_SPSR;
                wdata2 = cpsr_ff;
                cpsr_nxt[`CPSR_MODE]  = UND;

                `ifdef SIM
                        und_ack = 1'd1;
                `endif
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
                        pc_shelve (i_wr_data);
                else if ( i_mem_load_ff && i_wr_index_1 == ARCH_PC)
                        pc_shelve (i_wr_data_1);

                // A write to PC will trigger a clear from writeback.
                if ( i_wr_index == ARCH_PC || ( i_wr_index_1 == ARCH_PC && i_mem_load_ff) )
                        o_clear_from_writeback  = 1'd1;
        end

        pc_nxt = pc_nxt & 32'h_ffff_fffe;

        if ( i_reset )
                pc_nxt = 32'd0;
end

///////////////////////////////////////////////////////////////////////////////

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                // On reset, the CPU starts at 0 in
                // supervisor mode.
                shelve_ff                  <= 1'd0;
                pc_ff                      <= 32'd0;
                cpsr_ff                    <= SVC;
                cpsr_ff[I]                 <= 1'd1; // Mask IRQ.
                cpsr_ff[F]                 <= 1'd1; // Mask FIQ.
                cpsr_ff[T]                 <= 1'd0; // Start CPU in ARM mode.
        end
        else
        begin
                shelve_ff    <= shelve_nxt;
                pc_shelve_ff <= pc_shelve_nxt;
                pc_ff        <= pc_nxt;
                cpsr_ff      <= cpsr_nxt;
        end
end

///////////////////////////////////////////////////////////////////////////////

task pc_shelve (input [31:0] new_pc);
begin
        if (!i_code_stall )
        begin
                pc_nxt = new_pc;
                shelve_nxt = 1'd0; // BUG FIX.
        end
        else
        begin 
                shelve_nxt = 1'd1;
                pc_shelve_nxt = new_pc;
                pc_nxt = pc_ff;
        end
end
endtask

endmodule // zap_register_file.v
