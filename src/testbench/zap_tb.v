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


`default_nettype none
`include "zap_defines.vh"

module zap_test; 

// CPU config.
parameter RAM_SIZE                      = 32768;
parameter DATA_SECTION_TLB_ENTRIES      = 4;
parameter DATA_LPAGE_TLB_ENTRIES        = 8;
parameter DATA_SPAGE_TLB_ENTRIES        = 16;
parameter DATA_CACHE_SIZE               = 1024;
parameter CODE_SECTION_TLB_ENTRIES      = 4;
parameter CODE_LPAGE_TLB_ENTRIES        = 8;
parameter CODE_SPAGE_TLB_ENTRIES        = 16;
parameter CODE_CACHE_SIZE               = 1024;
parameter FIFO_DEPTH                    = 4;
parameter BP_ENTRIES                    = 1024;
parameter STORE_BUFFER_DEPTH            = 32;

// TB related.
parameter START                         = 1992;
parameter COUNT                         = 120;

// Variables
reg             i_clk = 1'd0;
reg             i_reset = 1'd0;
wire [1:0]       uart_in;
wire [1:0]      uart_out;
integer         i;
reg [3:0]       clk_ctr = 4'd0;
integer         seed = `SEED;
integer         seed_new = `SEED + 1;

// Clock generator.
always #10      i_clk = !i_clk;

wire    w_wb_stb;
wire    w_wb_cyc;
wire [31:0] w_wb_dat_to_ram;
wire [31:0] w_wb_adr;
wire [3:0] w_wb_sel;
wire    w_wb_we;
wire    w_wb_ack;
wire [31:0] w_wb_dat_from_ram;

// DUT
chip_top #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .BP_ENTRIES(BP_ENTRIES),
        .STORE_BUFFER_DEPTH(STORE_BUFFER_DEPTH),
        .DATA_SECTION_TLB_ENTRIES(DATA_SECTION_TLB_ENTRIES),
        .DATA_LPAGE_TLB_ENTRIES(DATA_LPAGE_TLB_ENTRIES),
        .DATA_SPAGE_TLB_ENTRIES(DATA_SPAGE_TLB_ENTRIES),
        .DATA_CACHE_SIZE(DATA_CACHE_SIZE),
        .CODE_SECTION_TLB_ENTRIES(CODE_SECTION_TLB_ENTRIES),
        .CODE_LPAGE_TLB_ENTRIES(CODE_LPAGE_TLB_ENTRIES),
        .CODE_SPAGE_TLB_ENTRIES(CODE_SPAGE_TLB_ENTRIES),
        .CODE_CACHE_SIZE(CODE_CACHE_SIZE)

) u_chip_top (
        .SYS_CLK  (i_clk),
        .SYS_RST  (i_reset),
        .UART0_RXD(uart_in[0]),
        .UART0_TXD(uart_out[0]),
        .UART1_RXD(uart_in[1]),
        .UART1_TXD(uart_out[1]),
        .I_IRQ    (28'd0),
        .I_FIQ    (1'd0),
        .O_WB_STB (w_wb_stb),
        .O_WB_CYC (w_wb_cyc),
        .O_WB_DAT (w_wb_dat_to_ram),
        .O_WB_ADR (w_wb_adr),
        .O_WB_SEL (w_wb_sel),
        .O_WB_WE  (w_wb_we),
        .I_WB_ACK (w_wb_ack),
        .I_WB_DAT (w_wb_dat_from_ram)
);

// RAM
ram #(.SIZE_IN_BYTES(RAM_SIZE)) u_ram (
        .i_clk(i_clk),
        .i_wb_stb (w_wb_stb),
        .i_wb_cyc (w_wb_cyc),
        .i_wb_dat (w_wb_dat_to_ram),
        .i_wb_adr (w_wb_adr),
        .i_wb_sel (w_wb_sel),
        .i_wb_we  (w_wb_we),
        .o_wb_ack (w_wb_ack),
        .o_wb_dat (w_wb_dat_from_ram)
);

// UART 0 dumper.
uart_tx_dumper #(.P(0)) UARTTX0 (
        .i_clk  (i_clk),
        .i_line (uart_out[0])
);

// UART 1 dumper.
uart_tx_dumper #(.P(1)) UARTTX1 (
        .i_clk  (i_clk),
        .i_line (uart_out[1])
);

// UART 0 logger.
uart_rx_logger #(.P(0)) UARTRX0 (
        .i_clk  (i_clk),
        .o_line (uart_in[0])
);

// UART 1 logger.
uart_rx_logger #(.P(1)) UARTRX1 (
        .i_clk  (i_clk),
        .o_line (uart_in[1])
);

// Run for MAX_CLOCK_CYCLES
initial
begin
        $display("SEED in decimal                         = %d", `SEED                          );
        $display("parameter RAM_SIZE                      = %d", RAM_SIZE                       ); 
        $display("parameter START                         = %d", START                          ); 
        $display("parameter COUNT                         = %d", COUNT                          ); 
        $display("parameter FIFO_DEPTH                    = %d", u_chip_top.FIFO_DEPTH          );
        $display("parameter DATA_SECTION_TLB_ENTRIES      = %d", DATA_SECTION_TLB_ENTRIES       ) ;
        $display("parameter DATA_LPAGE_TLB_ENTRIES        = %d", DATA_LPAGE_TLB_ENTRIES         ) ;
        $display("parameter DATA_SPAGE_TLB_ENTRIES        = %d", DATA_SPAGE_TLB_ENTRIES         ) ;
        $display("parameter DATA_CACHE_SIZE               = %d", DATA_CACHE_SIZE                ) ;
        $display("parameter CODE_SECTION_TLB_ENTRIES      = %d", CODE_SECTION_TLB_ENTRIES       ) ;
        $display("parameter CODE_LPAGE_TLB_ENTRIES        = %d", CODE_LPAGE_TLB_ENTRIES         ) ;
        $display("parameter CODE_SPAGE_TLB_ENTRIES        = %d", CODE_SPAGE_TLB_ENTRIES         ) ;
        $display("parameter CODE_CACHE_SIZE               = %d", CODE_CACHE_SIZE                ) ;
        $display("parameter STORE_BUFFER_DEPTH            = %d", STORE_BUFFER_DEPTH             ) ;

        `ifdef WAVES
                $dumpfile(`VCD_FILE_PATH);
                $dumpvars;
        `endif

        @(posedge i_clk);
        i_reset <= 1;
        @(posedge i_clk);
        i_reset <= 0;

        if (`MAX_CLOCK_CYCLES == 0 ) 
        begin
                forever @(negedge i_clk);
        end
        else
        begin
                repeat(`MAX_CLOCK_CYCLES) 
                        @(negedge i_clk);
        end

       `include "zap_check.vh"                
end

endmodule // zap_tb

`default_nettype wire
