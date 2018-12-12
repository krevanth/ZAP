// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2018 Revanth Kamaraj.                        --
// --                                                                         -- 
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 2          --
// -- of the License, or (at your option) any later version.                  --
// --                                                                         --
// -- This program is distributed in the hope that it will be useful,         --
// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
// -- GNU General Public License for more details.                            --
// --                                                                         --
// -- You should have received a copy of the GNU General Public License       --
// -- along with this program; if not, write to the Free Software             --
// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
// -- 02110-1301, USA.                                                        --
// --                                                                         --
// -----------------------------------------------------------------------------
//                                                                            --
// A simple interrupt controller.                                             --
//                                                                            --
// Registers:                                                                 --
// 0x0 - INT_STATUS - Interrupt status as reported by peripherals (sticky).   --
// 0x4 - INT_MASK   - Interrupt mask - setting a bit to 1 masks the interrupt --
// 0x8 - INT_CLEAR  - Write 1 to a particular bit to clear the interrupt      --
//                    status.                                                 --
//------------------------------------------------------------------------------

`default_nettype none

module vic #(
        parameter [31:0]        SOURCES                    = 32'd4,
        parameter [31:0]        INTERRUPT_PENDING_REGISTER = 32'h0,
        parameter [31:0]        INTERRUPT_MASK_REGISTER    = 32'h4,
        parameter [31:0]        INTERRUPT_CLEAR_REGISTER   = 32'h8
) (

// Clock and reset.
input  wire                 i_clk,
input  wire                 i_rst,

// Wishbone interface.
input  wire  [31:0]          i_wb_dat,
input  wire   [3:0]          i_wb_adr,
input  wire                  i_wb_stb,
input  wire                  i_wb_cyc,
input  wire                  i_wb_wen,
input  wire  [3:0]           i_wb_sel,
output reg  [31:0]           o_wb_dat,
output reg                   o_wb_ack,

// Interrupt sources in. Concatenate all
// sources together.
input    [SOURCES-1:0]       i_irq,

// Interrupt output. Level interrupt.
output  reg                  o_irq


);

`ifndef ZAP_SOC_VIC
`define ZAP_SOC_VIC
        `define INT_STATUS INTERRUPT_PENDING_REGISTER
        `define INT_MASK   INTERRUPT_MASK_REGISTER
        `define INT_CLEAR  INTERRUPT_CLEAR_REGISTER
`endif

reg [31:0] INT_STATUS;
reg [31:0] INT_MASK;
reg [31:0] wbstate;

// Wishbone states.
localparam WBIDLE       = 0;
localparam WBREAD       = 1;
localparam WBWRITE      = 2;
localparam WBACK        = 3;
localparam WBDONE       = 4;

// Send out a global interrupt signal.
always @ (posedge i_clk)
begin
        o_irq <= | ( INT_STATUS & ~INT_MASK );
end

// Wishbone access FSM
always @ ( posedge i_clk )
begin
        if ( i_rst )
        begin
                wbstate         <= WBIDLE;
                o_wb_dat        <= 0;
                o_wb_ack        <= 0;
                INT_MASK        <= 32'hffffffff;
                INT_STATUS      <= 32'h0;
        end
        else
        begin:blk1
                integer i;

                // Normally record interrupts. These are sticky bits.
                for(i=0;i<SOURCES;i++)
                        INT_STATUS[i] <= INT_STATUS[i] == 0 ? i_irq[i] : 1'd1;

                case(wbstate)
                        WBIDLE:
                        begin
                                o_wb_ack <= 1'd0;

                                if ( i_wb_stb && i_wb_cyc ) 
                                begin
                                        if ( i_wb_wen ) 
                                                wbstate <= WBWRITE;
                                        else
                                                wbstate <= WBREAD;
                                end
                        end

                        WBWRITE:
                        begin
                                case(i_wb_adr)

                                `INT_MASK: // INT_MASK
                                begin
                                        $display($time, " - %m :: Writing to INT_MASK register...");
                                        if ( i_wb_sel[0] ) INT_MASK[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) INT_MASK[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) INT_MASK[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) INT_MASK[31:24] <= i_wb_dat >> 24;      
                                        
                                end 

                                `INT_CLEAR: // INT_CLEAR
                                begin: blk22
                                        integer i;

                                        $display($time, " - %m :: Writing to INT_CLEAR register...");
                                        if ( i_wb_sel[0] ) for(i=0; i <=7;i++) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                        if ( i_wb_sel[1] ) for(i=8; i<=15;i++) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                        if ( i_wb_sel[2] ) for(i=16;i<=23;i++) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                        if ( i_wb_sel[3] ) for(i=24;i<=31;i++) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                end

                                default: $display($time, " - %m :: Warning: Attemting to write to illgal register...");

                                endcase

                                wbstate <= WBACK;
                        end

                        WBREAD:
                        begin
                                case(i_wb_adr)
                                `INT_STATUS:            o_wb_dat <= `INT_STATUS;
                                `INT_MASK:              o_wb_dat <= `INT_MASK;

                                default:                
                                begin
                                        $display($time, " - %m --> Warning: Attempting to read from illegal register. Will return 0...");
                                        o_wb_dat <= 0;
                                end
                                endcase

                                wbstate <= WBACK;
                        end

                        WBACK:
                        begin
                                o_wb_ack   <= 1'd1;
                                wbstate    <= WBDONE;
                        end

                        WBDONE:
                        begin
                                o_wb_ack   <= 1'd0;
                                wbstate    <= WBIDLE;
                        end
                endcase                
        end
end

endmodule // vic

`default_nettype wire
