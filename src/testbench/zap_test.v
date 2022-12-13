// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2022 Revanth Kamaraj (krevanth)              --
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

//
// UART0  address space FFFFFFE0 to FFFFFFFF
// Timer0 address space FFFFFFC0 to FFFFFFDF
// VIC0   address space FFFFFFA0 to FFFFFFBF
// UART1  address space FFFFFF80 to FFFFFF9F
// Timer1 address space FFFFFF60 to FFFFFF7F
// RAM    address space 0        to <RAM_SIZE>
// 

module zap_test (
        input  wire            i_clk, 
        input  wire            i_reset,
        output reg             o_sim_ok = 1'd0,
        output reg             o_sim_err = 1'd0,
        
        output reg             o_wb_stb, 
        output reg             o_wb_cyc,
        output reg     [31:0]  o_wb_adr,
        output reg     [3:0]   o_wb_sel,
        output reg             o_wb_we,
        output reg     [31:0]  o_wb_dat,
        output reg      [2:0]  o_wb_cti,
        input  wire            i_wb_ack,
        input  wire    [31:0]  i_wb_dat,

        input  wire    [7:0]   i_mem [65536-1:0],

        output wire            UART_SR_DAV_0, 
        output wire            UART_SR_DAV_1, 
        output wire    [7:0]   UART_SR_0, 
        output wire    [7:0]   UART_SR_1
);

initial
begin
        $dumpfile("zap.vcd");
        $dumpvars;
end

parameter RAM_SIZE                      = 32768;
parameter DATA_SECTION_TLB_ENTRIES      = 4;
parameter DATA_LPAGE_TLB_ENTRIES        = 8;
parameter DATA_SPAGE_TLB_ENTRIES        = 16;
parameter DATA_FPAGE_TLB_ENTRIES        = 32;
parameter DATA_CACHE_SIZE               = 1024;
parameter CODE_SECTION_TLB_ENTRIES      = 4;
parameter CODE_LPAGE_TLB_ENTRIES        = 8;
parameter CODE_SPAGE_TLB_ENTRIES        = 16;
parameter CODE_FPAGE_TLB_ENTRIES        = 32;
parameter CODE_CACHE_SIZE               = 1024;
parameter FIFO_DEPTH                    = 4;
parameter BP_ENTRIES                    = 1024;
parameter STORE_BUFFER_DEPTH            = 32;
parameter ONLY_CORE                     = 0;
parameter BE_32_ENABLE                  = 0;


localparam STRING_LENGTH                = 12;

reg [1:0]                  i_uart = 2'b11;
reg [1:0]                  o_uart;
reg [31:0]                 i;
reg [3:0]                  clk_ctr = 4'd0;
reg [STRING_LENGTH*8-1:0]  uart_string = "DLROW OLLEH ";
reg [6:0]                  uart_ctr    = 6'd10;
reg [31:0]                 btrace      = 32'd0;
reg [31:0]                 mem [65536/4-1:0]; // 16K words.
reg                        uart_done = 1'd0;
reg [8:0]                  uart_init_done = 8'd0;

// Divided clocks.
reg clk_2 = 1'd0, clk_4 = 1'd0, clk_8 = 1'd0, clk_16 = 1'd0;

// Digital clock dividers.
always @ ( posedge i_clk )
        clk_2 = clk_2 + 1;

always @ ( posedge clk_2 )
        clk_4 = clk_4 + 1;

always @ ( posedge clk_4 )
        clk_8 = clk_8 + 1;

always @ ( posedge clk_8 )
        clk_16 = clk_16 + 1;

always @ ( posedge clk_16 )
begin
        if ( !(&uart_init_done) )
                uart_init_done <= uart_init_done + 1;
end

// UART data into the core.
always @ ( posedge clk_16 ) if ( !uart_done && (&uart_init_done) )
begin
        if ( uart_ctr <= 8 )
        begin
                i_uart[0] <= uart_ctr == 0 ? 0 : uart_string[((btrace*8) + uart_ctr - 1)];
                uart_ctr  <= uart_ctr + 1;
        end
        else if ( uart_ctr == 9 )
        begin
                uart_ctr  <= uart_ctr + 1;
                i_uart[0] <= 1'd1;
        end
        else
        begin
                uart_ctr  <= uart_ctr + 1;
                i_uart[0] <= 1'd1;

                if ( &uart_ctr )
                begin
                        btrace <= (btrace == STRING_LENGTH - 1) ? 0 : btrace + 1;

                        if ( btrace == STRING_LENGTH - 1 )
                                uart_done <= 1;
                end
        end
end

// Create memory for easy analysis.
always @ (*)
begin
        for(int i=0;i<65536;i=i+4) 
                mem[i/4] = {i_mem[i+3], i_mem[i+2], i_mem[i+1], i_mem[i]};
end

// UART TX related. Data out of core.
uart_tx_dumper u_uart_tx_dumper_dev0 (  .i_clk(i_clk), .i_line(o_uart[0]), 
                                        .UART_SR_DAV(UART_SR_DAV_0), .UART_SR(UART_SR_0) );
uart_tx_dumper u_uart_tx_dumper_dev1 (  .i_clk(i_clk), .i_line(o_uart[1]), 
                                        .UART_SR_DAV(UART_SR_DAV_1), .UART_SR(UART_SR_1) );

// DUT
chip_top #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .BP_ENTRIES(BP_ENTRIES),
        .STORE_BUFFER_DEPTH(STORE_BUFFER_DEPTH),
        .DATA_SECTION_TLB_ENTRIES(DATA_SECTION_TLB_ENTRIES),
        .DATA_LPAGE_TLB_ENTRIES(DATA_LPAGE_TLB_ENTRIES),
        .DATA_SPAGE_TLB_ENTRIES(DATA_SPAGE_TLB_ENTRIES),
        .DATA_FPAGE_TLB_ENTRIES(DATA_FPAGE_TLB_ENTRIES),
        .DATA_CACHE_SIZE(DATA_CACHE_SIZE),
        .CODE_SECTION_TLB_ENTRIES(CODE_SECTION_TLB_ENTRIES),
        .CODE_LPAGE_TLB_ENTRIES(CODE_LPAGE_TLB_ENTRIES),
        .CODE_SPAGE_TLB_ENTRIES(CODE_SPAGE_TLB_ENTRIES),
        .CODE_FPAGE_TLB_ENTRIES(CODE_FPAGE_TLB_ENTRIES),
        .CODE_CACHE_SIZE(CODE_CACHE_SIZE),
        .BE_32_ENABLE(BE_32_ENABLE),
        .ONLY_CORE(ONLY_CORE)
) u_chip_top (
        .SYS_CLK  (i_clk),
        .SYS_RST  (i_reset),
        .UART0_RXD(i_uart[0]),
        .UART0_TXD(o_uart[0]),
        .UART1_RXD(i_uart[1]),
        .UART1_TXD(o_uart[1]),
        .I_IRQ    (28'd0),
        .I_FIQ    (1'd0),
        .O_WB_STB (o_wb_stb),
        .O_WB_CYC (o_wb_cyc),
        .O_WB_DAT (o_wb_dat),
        .O_WB_ADR (o_wb_adr),
        .O_WB_SEL (o_wb_sel),
        .O_WB_WE  (o_wb_we),
        .I_WB_ACK (i_wb_ack),
        .I_WB_DAT (i_wb_dat),
        .O_WB_CTI(o_wb_cti)
);

integer sim_ctr = 0;

always @ ( posedge i_clk )
begin
        sim_ctr <= sim_ctr + 1;

        if ( sim_ctr == `MAX_CLOCK_CYCLES )        
        begin
                o_sim_ok <= 1'd1;

                `include "zap_check.vh"
        end
end

// Expose the CPU registers.
wire [31:0] r0   =  `REG_HIER.mem[0]; 
wire [31:0] r1   =  `REG_HIER.mem[1];
wire [31:0] r2   =  `REG_HIER.mem[2];
wire [31:0] r3   =  `REG_HIER.mem[3];
wire [31:0] r4   =  `REG_HIER.mem[4];
wire [31:0] r5   =  `REG_HIER.mem[5];
wire [31:0] r6   =  `REG_HIER.mem[6];
wire [31:0] r7   =  `REG_HIER.mem[7];
wire [31:0] r8   =  `REG_HIER.mem[8];
wire [31:0] r9   =  `REG_HIER.mem[9];
wire [31:0] r10  =  `REG_HIER.mem[10];
wire [31:0] r11  =  `REG_HIER.mem[11];
wire [31:0] r12  =  `REG_HIER.mem[12];
wire [31:0] r13  =  `REG_HIER.mem[13];
wire [31:0] r14  =  `REG_HIER.mem[14];
wire [31:0] r15  =  `REG_HIER.mem[15];
wire [31:0] r16  =  `REG_HIER.mem[16];
wire [31:0] r17  =  `REG_HIER.mem[17];
wire [31:0] r18  =  `REG_HIER.mem[18];
wire [31:0] r19  =  `REG_HIER.mem[19];
wire [31:0] r20  =  `REG_HIER.mem[20];
wire [31:0] r21  =  `REG_HIER.mem[21];
wire [31:0] r22  =  `REG_HIER.mem[22];
wire [31:0] r23  =  `REG_HIER.mem[23];
wire [31:0] r24  =  `REG_HIER.mem[24];
wire [31:0] r25  =  `REG_HIER.mem[25];
wire [31:0] r26  =  `REG_HIER.mem[26];
wire [31:0] r27  =  `REG_HIER.mem[27];
wire [31:0] r28  =  `REG_HIER.mem[28];
wire [31:0] r29  =  `REG_HIER.mem[29];
wire [31:0] r30  =  `REG_HIER.mem[30];
wire [31:0] r31  =  `REG_HIER.mem[31];
wire [31:0] r32  =  `REG_HIER.mem[32];
wire [31:0] r33  =  `REG_HIER.mem[33];
wire [31:0] r34  =  `REG_HIER.mem[34];
wire [31:0] r35  =  `REG_HIER.mem[35];
wire [31:0] r36  =  `REG_HIER.mem[36];
wire [31:0] r37  =  `REG_HIER.mem[37];
wire [31:0] r38  =  `REG_HIER.mem[38];
wire [31:0] r39  =  `REG_HIER.mem[39];

endmodule

module chip_top #(

// CPU config.
parameter DATA_SECTION_TLB_ENTRIES      = 4,
parameter DATA_LPAGE_TLB_ENTRIES        = 8,
parameter DATA_SPAGE_TLB_ENTRIES        = 16,
parameter DATA_FPAGE_TLB_ENTRIES        = 32,
parameter DATA_CACHE_SIZE               = 1024,
parameter CODE_SECTION_TLB_ENTRIES      = 4,
parameter CODE_LPAGE_TLB_ENTRIES        = 8,
parameter CODE_SPAGE_TLB_ENTRIES        = 16,
parameter CODE_FPAGE_TLB_ENTRIES        = 32,
parameter CODE_CACHE_SIZE               = 1024,
parameter FIFO_DEPTH                    = 4,
parameter BP_ENTRIES                    = 1024,
parameter STORE_BUFFER_DEPTH            = 32,
parameter BE_32_ENABLE                  = 0,
parameter ONLY_CORE                     = 0

)(
        // Clk and rst 
        input wire          SYS_CLK, 
        input wire          SYS_RST, 

        // UART 0
        input  wire         UART0_RXD, 
        output wire         UART0_TXD,

        // UART 1
        input  wire         UART1_RXD,
        output wire         UART1_TXD,

        // Remaining IRQs to the interrupt controller.
        input   wire [27:0] I_IRQ,              

        // Single FIQ input directly to ZAP CPU.
        input   wire        I_FIQ,

        // External Wishbone Connection (for RAMs etc).
        output reg          O_WB_STB, 
        output reg          O_WB_CYC,
        output wire [31:0]  O_WB_DAT,
        output wire [31:0]  O_WB_ADR,
        output wire [3:0]   O_WB_SEL,
        output wire         O_WB_WE,
        output wire [2:0]   O_WB_CTI,
        input  wire         I_WB_ACK,
        input  wire [31:0]  I_WB_DAT
);

// Peripheral addresses.
localparam UART0_LO                     = 32'hFFFFFFE0;
localparam UART0_HI                     = 32'hFFFFFFFF;
localparam TIMER0_LO                    = 32'hFFFFFFC0;
localparam TIMER0_HI                    = 32'hFFFFFFDF;
localparam VIC_LO                       = 32'hFFFFFFA0;
localparam VIC_HI                       = 32'hFFFFFFBF;
localparam UART1_LO                     = 32'hFFFFFF80;
localparam UART1_HI                     = 32'hFFFFFF9F;
localparam TIMER1_LO                    = 32'hFFFFFF60;
localparam TIMER1_HI                    = 32'hFFFFFF7F;

// Internal signals.
wire            i_clk    = SYS_CLK;
wire            i_reset  = SYS_RST;

wire [1:0]      uart_in; 
wire [1:0]      uart_out;

assign          {UART1_TXD, UART0_TXD} = uart_out;
assign          uart_in = {UART1_RXD, UART0_RXD};

wire            data_wb_cyc; 
wire            data_wb_stb; 
reg [31:0]      data_wb_din; 
reg             data_wb_ack; 
reg             data_wb_cyc_uart [1:0], data_wb_cyc_timer [1:0], data_wb_cyc_vic;
reg             data_wb_stb_uart [1:0], data_wb_stb_timer [1:0], data_wb_stb_vic;
wire [31:0]     data_wb_din_uart [1:0], data_wb_din_timer [1:0], data_wb_din_vic;
wire            data_wb_ack_uart [1:0], data_wb_ack_timer [1:0], data_wb_ack_vic;
wire [3:0]      data_wb_sel;
wire            data_wb_we;
wire [31:0]     data_wb_dout;
wire [31:0]     data_wb_adr;
wire [2:0]      data_wb_cti; // Cycle Type Indicator.
wire            global_irq;
wire [1:0]      uart_irq;
wire [1:0]      timer_irq;

// Common WB signals to output.
assign        O_WB_ADR        = data_wb_adr;
assign        O_WB_WE         = data_wb_we;
assign        O_WB_DAT        = data_wb_dout;
assign        O_WB_SEL        = data_wb_sel;
assign        O_WB_CTI        = data_wb_cti;

// Wishbone fabric.
always @*
begin:blk1
        integer ii;

        for(ii=0;ii<=1;ii=ii+1)
        begin
                data_wb_cyc_uart [ii]  = 0;
                data_wb_stb_uart [ii]  = 0;
                data_wb_cyc_timer[ii] = 0;
                data_wb_stb_timer[ii] = 0;
        end

        data_wb_cyc_vic   = 0;
        data_wb_stb_vic   = 0;

        O_WB_CYC          = 0;
        O_WB_STB          = 0;

        if ( data_wb_adr >= UART0_LO && data_wb_adr <= UART0_HI )        // UART0 access
        begin
                data_wb_cyc_uart[0] = data_wb_cyc;
                data_wb_stb_uart[0] = data_wb_stb;
                data_wb_ack        = data_wb_ack_uart[0];
                data_wb_din        = data_wb_din_uart[0]; 
        end
        else if ( data_wb_adr >= TIMER0_LO && data_wb_adr <= TIMER0_HI )  // Timer0 access
        begin
                data_wb_cyc_timer[0] = data_wb_cyc;
                data_wb_stb_timer[0] = data_wb_stb;
                data_wb_ack          = data_wb_ack_timer[0];
                data_wb_din          = data_wb_din_timer[0]; 
        end
        else if ( data_wb_adr >= VIC_LO && data_wb_adr <= VIC_HI )        // VIC access.
        begin
                data_wb_cyc_vic   = data_wb_cyc;
                data_wb_stb_vic   = data_wb_stb;
                data_wb_ack       = data_wb_ack_vic;
                data_wb_din       = data_wb_din_vic;                
        end
        else if ( data_wb_adr >= UART1_LO && data_wb_adr <= UART1_HI )    // UART1 access
        begin
                data_wb_cyc_uart[1] = data_wb_cyc;
                data_wb_stb_uart[1] = data_wb_stb;
                data_wb_ack        = data_wb_ack_uart[1];
                data_wb_din        = data_wb_din_uart[1]; 
        end
        else if ( data_wb_adr >= TIMER1_LO && data_wb_adr <= TIMER1_HI )  // Timer1 access
        begin
                data_wb_cyc_timer[1] = data_wb_cyc;
                data_wb_stb_timer[1] = data_wb_stb;
                data_wb_ack          = data_wb_ack_timer[1];
                data_wb_din          = data_wb_din_timer[1]; 
        end       
        else // External WB access.
        begin
                O_WB_CYC         = data_wb_cyc;
                O_WB_STB         = data_wb_stb;
                data_wb_ack      = I_WB_ACK;
                data_wb_din      = I_WB_DAT;
        end
end

// =========================
// Processor core.
// =========================

zap_top #(
        .BE_32_ENABLE(BE_32_ENABLE),
        .ONLY_CORE(ONLY_CORE),
        .FIFO_DEPTH(FIFO_DEPTH),
        .BP_ENTRIES(BP_ENTRIES),
        .STORE_BUFFER_DEPTH(STORE_BUFFER_DEPTH),
        .DATA_SECTION_TLB_ENTRIES(DATA_SECTION_TLB_ENTRIES),
        .DATA_LPAGE_TLB_ENTRIES(DATA_LPAGE_TLB_ENTRIES),
        .DATA_SPAGE_TLB_ENTRIES(DATA_SPAGE_TLB_ENTRIES),
        .DATA_FPAGE_TLB_ENTRIES(DATA_FPAGE_TLB_ENTRIES),
        .DATA_CACHE_SIZE(DATA_CACHE_SIZE),
        .CODE_SECTION_TLB_ENTRIES(CODE_SECTION_TLB_ENTRIES),
        .CODE_LPAGE_TLB_ENTRIES(CODE_LPAGE_TLB_ENTRIES),
        .CODE_SPAGE_TLB_ENTRIES(CODE_SPAGE_TLB_ENTRIES),
        .CODE_FPAGE_TLB_ENTRIES(CODE_FPAGE_TLB_ENTRIES),
        .CODE_CACHE_SIZE(CODE_CACHE_SIZE)
) 
u_zap_top 
(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_irq(global_irq),
        .i_fiq    (I_FIQ),
        .o_wb_cyc (data_wb_cyc),
        .o_wb_stb (data_wb_stb),
        .o_wb_adr (data_wb_adr),
        .o_wb_we  (data_wb_we),
        .o_wb_cti (data_wb_cti),
        .i_wb_dat (data_wb_din),
        .o_wb_dat (data_wb_dout),
        .i_wb_ack (data_wb_ack),
        .o_wb_sel (data_wb_sel),
        .o_wb_bte ()             // Always zero (Linear)

);

// ===============================
// 2 x UART + 2 x Timer
// ===============================

genvar gi;
generate
        for(gi=0;gi<=1;gi=gi+1) 
        begin: uart_gen
                uart_top u_uart_top (
                
                        // WISHBONE interface
                        .wb_clk_i(i_clk),
                        .wb_rst_i(i_reset),
                        .wb_adr_i(data_wb_adr[4:0]),
                        .wb_dat_i(data_wb_dout),
                        .wb_dat_o(data_wb_din_uart[gi]),
                        .wb_we_i (data_wb_we),
                        .wb_stb_i(data_wb_stb_uart[gi]),
                        .wb_cyc_i(data_wb_cyc_uart[gi]),
                        .wb_sel_i(data_wb_sel),
                        .wb_ack_o(data_wb_ack_uart[gi]),
                        .int_o   (uart_irq[gi]), // Interrupt.
                        
                        // UART signals.
                        .srx_pad_i         (uart_in[gi]),
                        .stx_pad_o         (uart_out[gi]),
                
                        // Tied or open.
                        .rts_pad_o(),
                        .cts_pad_i(1'd0),
                        .dtr_pad_o(),
                        .dsr_pad_i(1'd0),
                        .ri_pad_i (1'd0),
                        .dcd_pad_i(1'd0)
                );

                timer u_timer (
                        .i_clk(i_clk),
                        .i_rst(i_reset),
                        .i_wb_adr(data_wb_adr[3:0]),
                        .i_wb_dat(data_wb_dout),
                        .i_wb_stb(data_wb_stb_timer[gi]),
                        .i_wb_cyc(data_wb_cyc_timer[gi]),   // From core
                        .i_wb_wen(data_wb_we),
                        .i_wb_sel(data_wb_sel),
                        .o_wb_dat(data_wb_din_timer[gi]),   // To core.
                        .o_wb_ack(data_wb_ack_timer[gi]),
                        .o_irq(timer_irq[gi])               // Interrupt
                );
        end 
endgenerate

// ===============================
// VIC
// ===============================

vic #(.SOURCES(32)) u_vic (
        .i_clk   (i_clk),
        .i_rst   (i_reset),
        .i_wb_adr(data_wb_adr[3:0]),
        .i_wb_dat(data_wb_dout),
        .i_wb_stb(data_wb_stb_vic),
        .i_wb_cyc(data_wb_cyc_vic), // From core
        .i_wb_wen(data_wb_we),
        .i_wb_sel(data_wb_sel),
        .o_wb_dat(data_wb_din_vic), // To core.
        .o_wb_ack(data_wb_ack_vic),
        .i_irq({I_IRQ, timer_irq[1], uart_irq[1], timer_irq[0], uart_irq[0]}), // Concatenate 32 interrupt sources.
        .o_irq(global_irq)                                                     // Interrupt out
);

endmodule // chip_top

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module timer #(

        // Register addresses.
        parameter       [31:0]  TIMER_ENABLE_REGISTER = 32'h0,
        parameter       [31:0]  TIMER_LIMIT_REGISTER  = 32'h4,
        parameter       [31:0]  TIMER_INTACK_REGISTER = 32'h8,
        parameter       [31:0]  TIMER_START_REGISTER  = 32'hC

) (

// Clock and reset.
input wire                  i_clk,
input wire                  i_rst,

// Wishbone interface.
input wire  [31:0]          i_wb_dat,
input wire   [3:0]          i_wb_adr,
input wire                  i_wb_stb,
input wire                  i_wb_cyc,
input wire                  i_wb_wen,
input wire  [3:0]           i_wb_sel,
output reg [31:0]           o_wb_dat,
output reg                  o_wb_ack,


// Interrupt output. Level interrupt.
output  reg                 o_irq

);

// Timer registers.
reg [31:0] DEVEN;  
reg [31:0] DEVPR;  
reg [31:0] DEVAK;  
reg [31:0] DEVST;  

`define DEVEN TIMER_ENABLE_REGISTER
`define DEVPR TIMER_LIMIT_REGISTER
`define DEVAK TIMER_INTACK_REGISTER
`define DEVST TIMER_START_REGISTER

// Timer core.
reg [31:0] ctr;         // Core counter.
reg        start;       // Pulse to start the timer. Done signal is cleared.
reg        done;        // Asserted when timer is done.
reg        clr;         // Clears the done signal.
reg [31:0] state;       // State
reg        enable;      // 1 to enable the timer.
reg [31:0] finalval;    // Final value to count.
reg [31:0] wbstate;

localparam IDLE         = 0;
localparam COUNTING     = 1;
localparam DONE         = 2;

localparam WBIDLE       = 0;
localparam WBREAD       = 1;
localparam WBWRITE      = 2;
localparam WBACK        = 3;
localparam WBDONE       = 4;

always @ (*)
        o_irq    = done;

always @ (*)
begin
        start    = DEVST[0];
        enable   = DEVEN[0];
        finalval = DEVPR;
        clr      = DEVAK[0];
end

always @ ( posedge i_clk )
begin
        DEVST <= 0;

        if ( i_rst )
        begin
                DEVEN <= 0;
                DEVPR <= 0;
                DEVAK <= 0;
                DEVST <= 0;
                wbstate  <= WBIDLE;
                o_wb_dat <= 0;
                o_wb_ack <= 0;
        end
        else
        begin
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
                                `DEVEN: // DEVEN
                                begin
                                        if ( i_wb_sel[0] ) DEVEN[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVEN[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVEN[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVEN[31:24] <= i_wb_dat >> 24; 
                                end

                                `DEVPR: // DEVPR
                                begin
                                        if ( i_wb_sel[0] ) DEVPR[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVPR[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVPR[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVPR[31:24] <= i_wb_dat >> 24;      
                                        
                                end 

                                `DEVAK: // DEVAK
                                begin
                                        if ( i_wb_sel[0] ) DEVPR[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVPR[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVPR[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVPR[31:24] <= i_wb_dat >> 24;   
                                end

                                `DEVST: // DEVST
                                begin
                                        if ( i_wb_sel[0] ) DEVST[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVST[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVST[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVST[31:24] <= i_wb_dat >> 24;    
                                end

                                default:
                                begin
                                        $display($time, " Error : Illegal register write in %m.");
                                        $finish;
                                end

                                endcase

                                wbstate <= WBACK;
                        end

                        WBREAD:
                        begin
                                case(i_wb_adr)
                                `DEVEN: o_wb_dat <= DEVEN;
                                `DEVPR: o_wb_dat <= DEVPR;
                                `DEVAK: o_wb_dat <= done;
                                `DEVST: o_wb_dat <= 32'd0;
                               default: 
                                        begin
                                                $display($time, " Error : Illegal register read in %m.");
                                                $finish;
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
                                o_wb_ack  <= 1'd0;
                                wbstate   <= IDLE;
                        end
                endcase                
        end
end

always @ (posedge i_clk)
begin
        if ( i_rst || !enable ) 
        begin
                ctr     <= 0;
                done    <= 0;
                state   <= IDLE;
        end     
        else // if enabled
        begin
                case(state)
                IDLE:
                begin
                        if ( start ) 
                        begin
                                state <= COUNTING;
                        end
                end

                COUNTING:
                begin
                        ctr <= ctr + 1;

                        if ( ctr == finalval ) 
                        begin
                                state <= DONE;
                        end                                
                end

                DONE:
                begin
                        done <= 1;

                        if ( start ) 
                        begin
                                done  <= 0;
                                state <= COUNTING;
                                ctr   <= 0;
                        end
                        else if ( clr ) // Acknowledge. 
                        begin
                                done  <= 0;
                                state <= IDLE;
                                ctr   <= 0;
                        end
                end
                endcase
        end
end

endmodule


//                                                                            
// A simple interrupt controller.                                             
//                                                                            
// Registers:                                                                 
// 0x0 - INT_STATUS - Interrupt status as reported by peripherals (sticky).   
// 0x4 - INT_MASK   - Interrupt mask - setting a bit to 1 masks the interrupt 
// 0x8 - INT_CLEAR  - Write 1 to a particular bit to clear the interrupt      
//                    status.                                                 

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
input wire   [SOURCES-1:0]       i_irq,

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
                for(i=0;i<SOURCES;i=i+1)
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
                                        if ( i_wb_sel[0] ) INT_MASK[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) INT_MASK[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) INT_MASK[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) INT_MASK[31:24] <= i_wb_dat >> 24;      
                                        
                                end 

                                `INT_CLEAR: // INT_CLEAR
                                begin: blk22
                                        integer i;

                                        if ( i_wb_sel[0] ) for(i=0; i <=7;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                        if ( i_wb_sel[1] ) for(i=8; i<=15;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                        if ( i_wb_sel[2] ) for(i=16;i<=23;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                        if ( i_wb_sel[3] ) for(i=24;i<=31;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0; 
                                end

                                default: 
                                begin
                                        $display($time, " Error : Attemting to write to illegal register in %m");
                                        $finish;
                                end

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
                                        $display($time, " Error : Attempting to read from illegal register in %m.");
                                        $finish;
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

module uart_tx_dumper ( input wire i_clk, input wire i_line, 
                        output reg UART_SR_DAV = 1'd0, output reg [7:0] UART_SR = 1'd0 ); 

localparam UART_WAIT_FOR_START = 0;
localparam UART_RX             = 1;
localparam UART_STOP_BIT       = 2;

integer                 uart_state   = UART_WAIT_FOR_START;
integer                 uart_ctr     = 0;
integer                 uart_bit_ctr = 0;
reg [7:0]               uart_sr      = 0;
wire                    uart;
integer signed          fh;

assign uart = i_line;

always @ ( posedge i_clk )
begin
        UART_SR_DAV <= 1'd0;

        case ( uart_state ) 
                UART_WAIT_FOR_START:
                begin
                        if ( !uart ) 
                        begin
                                uart_ctr <= uart_ctr + 1;
                        end

                        if ( !uart && (uart_ctr + 1 == 16) ) 
                        begin
                                uart_state   <= UART_RX;
                                uart_ctr     <= 0;
                                uart_bit_ctr <= 0;
                        end                        
                end

                UART_RX:
                begin
                        uart_ctr <= uart_ctr + 1;

                        if ( uart_ctr + 1 == 2 ) 
                                uart_sr <= uart_sr >> 1 | i_line << 7;                                

                        if ( uart_ctr + 1 == 16 ) 
                        begin
                                uart_bit_ctr <= uart_bit_ctr + 1;
                                uart_ctr     <= 0;

                                if ( uart_bit_ctr + 1 == 8 ) 
                                begin
                                        uart_state  <= UART_STOP_BIT;                               
                                        UART_SR     <= uart_sr;
                                        UART_SR_DAV <= 1'd1;
                                        uart_ctr    <= 0;
                                        uart_bit_ctr<= 0;
                                end
                        end                        
                end

                UART_STOP_BIT:
                begin
                        uart_ctr <= uart_ctr + 1;

                        if ( uart && (uart_ctr + 1 == 16) ) // Stop bit.
                        begin
                                uart_state      <= UART_WAIT_FOR_START;                                
                                uart_bit_ctr    <= 0;
                                uart_ctr        <= 0;
                        end
                end
        endcase
end

endmodule // uart_tx_dumper

