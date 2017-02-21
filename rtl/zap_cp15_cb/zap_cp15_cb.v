///////////////////////////////////////////////////////////////////////////////

// 
// MIT License
// 
// Copyright (C) 2016,2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
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
// Filename --
// zap_cp15_cb.v 
// 
// Summary --
// CP15 register block.
//
// Detail --
// This RTL describes the CP15 register block. The ports go to the MMU and
// cache unit. This block connects to the CPU core. Coprocessor operations
// supported are read from coprocessor and write to CPU registers or vice
// versa.
//  

///////////////////////////////////////////////////////////////////////////////

`include "config.vh"
`default_nettype none

///////////////////////////////////////////////////////////////////////////////

module zap_cp15_cb #(
        parameter PHY_REGS = 64
)
(
        // Clock and reset.
        input wire                              i_clk,
        input wire                              i_reset,

        //
        // Coprocessor bus.
        //

        // Coprocessor instruction.
        input wire      [31:0]                  i_cp_word,

        // Coprocessor instruction valid.
        input wire                              i_cp_dav,

        // Coprocessor done.
        output reg                              o_cp_done,

        // CPSR from processor.
        input  wire     [31:0]                  i_cpsr,

        // Asserted if we want to control of the register file.
        // Controls a MUX that selects signals.
        output reg                              o_reg_en,

        // Data to write to the register file.
        output reg [31:0]                       o_reg_wr_data,

        // Data read from the register file.
        input wire [31:0]                       i_reg_rd_data,

        // Write and read index for the register file.
        output reg [$clog2(PHY_REGS)-1:0]       o_reg_wr_index,
                                                o_reg_rd_index,

        //
        // From MMU.
        //

        // The FSR stands for "Fault Status Register"
        // The FAR stands for "Fault Address Register"
        input wire      [31:0]                  i_fsr,
        input wire      [31:0]                  i_far,

        //
        // These go to the MMU
        //

        // Domain Access Control Register.
        output reg      [31:0]                  o_dac,

        // Base address of page table.
        output reg      [31:0]                  o_baddr,

        // Cache invalidate signal.
        output reg                              o_cache_inv,

        // TLB invalidate signal.
        output reg                              o_tlb_inv,

        // Data cache enable.
        output reg                              o_dcache_en,

        // Instruction cache enable.
        output reg                              o_icache_en,

        // MMU enable.
        output reg                              o_mmu_en,

        // SR register.
        output reg      [1:0]                   o_sr
);

///////////////////////////////////////////////////////////////////////////////

`include "global_functions.vh"
`include "cpsr.vh"
`include "regs.vh"
`include "cc.vh"
`include "modes.vh"

///////////////////////////////////////////////////////////////////////////////

reg [31:0] r [6:0]; // Coprocessor registers. R7 is write-only.
reg [2:0]    state; // State variable.

///////////////////////////////////////////////////////////////////////////////

//
// This block ties the registers to the
// output ports.
//
always @*
begin
        o_dcache_en = r[1][2];  // Data cache.
        o_icache_en = r[1][12]; // Instruction cache.
        o_mmu_en   = r[1][0];   // MMU enable.
        o_dac      = r[3];      // DAC register.

        // Base address and SR register.
        o_baddr    = r[2];              
        o_sr       = {r[1][8],r[1][9]}; 

        // Debug only.
        `ifdef SIM
                `ifdef FORCE_DCACHE_EN
                        o_dcache_en = 1'd1;
                `endif

                `ifdef FORCE_ICACHE_EN
                        o_icache_en = 1'd1;
                `endif

                `ifdef FORCE_MMU_EN
                        o_mmu_en = 1'd1;
                `endif
        `endif
end

///////////////////////////////////////////////////////////////////////////////

// States.
localparam IDLE         = 0;
localparam ACTIVE       = 1;
localparam DONE         = 2;
localparam READ         = 3;
localparam READ_DLY     = 4;
localparam TERM         = 5;

///////////////////////////////////////////////////////////////////////////////

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                state          <= IDLE;
                r[0]           <= 32'hFFFFFFFF;
                o_cache_inv    <= 1'd0;
                o_tlb_inv      <= 1'd0;
                o_reg_en       <= 1'd0;
                o_cp_done      <= 1'd0;
                o_reg_wr_data  <= 0;
                o_reg_wr_index <= 0;
                o_reg_rd_index <= 0;
                r[1]           <= 32'd0;
                r[2]           <= 32'd0;
                r[3]           <= 32'd0;
                r[4]           <= 32'd0;
                r[5]           <= 32'd0;
                r[6]           <= 32'd0;
        end
        else
        begin
                r[0]        <= 32'hFFFFFFFF;
                o_tlb_inv   <= 1'd0;
                o_cache_inv <= 1'd0;
                o_reg_en    <= 1'd0;
                o_cp_done   <= 1'd0;
        
                case ( state )
                IDLE: // Idle state.
                begin
                        o_cp_done <= 1'd0;
        
                        // Keep monitoring FSR and FAR from MMU unit. If
                        // produced, clock them in.
                        if ( i_fsr[3:0] != 4'd0 )
                        begin
                                r[5] <= i_fsr;
                                r[6] <= i_far;
                        end
        
                        if ( i_cp_dav && i_cp_word[11:8] == 15 )
                        begin
                                if ( i_cpsr[4:0] != USR )
                                begin
                                        state     <= ACTIVE;
                                        o_cp_done <= 1'd0;
                                end
                                else
                                begin
                                        // No permissions in USR land. 
                                        // Pretend to be done.
                                        o_cp_done <= 1'd1;
                                end
                        end
                end
        
                DONE: // Complete transaction.
                begin
                        // Tell that we are done.
                        o_cp_done    <= 1'd1;
                        state        <= TERM;
                end
        
                TERM: // Wait state before going to IDLE.
                begin
                        state <= IDLE;
                end
        
                READ_DLY: // Register data is clocked out in this stage.
                begin
                        state <= READ;
                end
        
                READ: // Write value read from CPU register to coprocessor.
                begin
                        r [ i_cp_word[19:16] ] <= i_reg_rd_data;
        
                        if (    
                                i_cp_word[19:16] == 4'd5 || 
                                i_cp_word[19:16] == 4'd6 
                        )
                        begin
                                // Invalidate TLB.
                                o_tlb_inv <= 1'd1;
                        end
                        else if ( i_cp_word[19:16] == 4'd7 )
                        begin
                                // Invalidate cache.
                                o_cache_inv <= 1'd1;
                        end
        
                        state <= DONE;
                end
        
                ACTIVE: // Access processor registers.
                begin
                        if ( is_cc_satisfied ( i_cp_word[31:28], i_cpsr[31:28] ) )
                        begin
                                        if ( i_cp_word[20] ) // Load to CPU reg.
                                        begin
                                                // Register write command.                                                                                  
                                                o_reg_en        <= 1'd1;
                                                o_reg_wr_index  <= 
                                                translate( i_cp_word[15:12], i_cpsr[4:0] ); 
                                                o_reg_wr_data   <= r[ i_cp_word[19:16] ];
                                                state           <= DONE;
                                        end
                                        else // Store to CPU register.
                                        begin
                                                // Generate register read command.
                                                o_reg_en        <= 1'd1;
                                                o_reg_rd_index  <=  
                                                translate(i_cp_word[15:12], i_cpsr[4:0]);
                                                o_reg_wr_index  <= 16;
                                                state           <= READ_DLY;                                        
                                        end
                        end
                        else
                        begin
                                state        <= DONE;
                        end
                end
                endcase
        end
end

///////////////////////////////////////////////////////////////////////////////

`ifdef SIM
// Debug only.
wire [31:0] r0 = r[0];
wire [31:0] r1 = r[1];
wire [31:0] r2 = r[2];
wire [31:0] r3 = r[3];
wire [31:0] r4 = r[4];
wire [31:0] r5 = r[5];
wire [31:0] r6 = r[6];
`endif

///////////////////////////////////////////////////////////////////////////////


endmodule
