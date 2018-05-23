`default_nettype none

//
// A testbench model of a wishbone timer peripheral.
//
// Local addresses:
// 0x0 (DEVEN) - 0x1 to enable the timer unit. 0x0 to disable the unit.
// 0x4 (DEVPR) - Timer length in number of Wishbone clocks.
// 0x8 (DEVAK) - Write: 0x1 to acknowledge interrupt. Read: 0x1 reveals timer interrupt occured.
// 0xC (DEVST) - 0x1 to start the timer. Write only. Always reads 0x0.
//

module timer (

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
output  reg             o_irq

);

// Timer registers.
reg [31:0] DEVEN;  // 0x0
reg [31:0] DEVPR;  // 0x4
reg [31:0] DEVAK;  // 0x8
reg [31:0] DEVST;  // 0xC

`ifndef TB_TIMER
`define TB_TIMER
        `define DEVEN 32'h0
        `define DEVPR 32'h4
        `define DEVAK 32'h8
        `define DEVST 32'hC
`endif

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

always @*
        o_irq    = done;

always @*
begin
        start    = DEVST[0];
        enable   = DEVEN[0];
        finalval = DEVPR;
        clr      = DEVAK[0];
end

always @ (posedge i_clk)
begin
        DEVST <= 0;

        if ( i_rst )
        begin
                DEVEN <= 0;
                DEVPR <= 0;
                DEVAK <= 0;
                DEVST <= 0;
                wbstate <= WBIDLE;
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
                                        $display($time, " - %m --> Writing register DEVEN...");
                                        if ( i_wb_sel[0] ) DEVEN[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVEN[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVEN[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVEN[31:24] <= i_wb_dat >> 24; 
                                end

                                `DEVPR: // DEVPR
                                begin
                                        $display($time, " - %m --> Writing register DEVPR...");
                                        if ( i_wb_sel[0] ) DEVPR[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVPR[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVPR[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVPR[31:24] <= i_wb_dat >> 24;      
                                        
                                end 

                                `DEVAK: // DEVAK
                                begin
                                        $display($time, " - %m --> Writing register DEVAK...");
                                        if ( i_wb_sel[0] ) DEVPR[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVPR[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVPR[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVPR[31:24] <= i_wb_dat >> 24;   
                                end

                                `DEVST: // DEVST
                                begin
                                        $display($time, " - %m --> Writing register DEVST...");
                                        if ( i_wb_sel[0] ) DEVST[7:0]   <= i_wb_dat >> 0; 
                                        if ( i_wb_sel[1] ) DEVST[15:8]  <= i_wb_dat >> 8; 
                                        if ( i_wb_sel[2] ) DEVST[23:16] <= i_wb_dat >> 16; 
                                        if ( i_wb_sel[3] ) DEVST[31:24] <= i_wb_dat >> 24;    
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
                                endcase

                                wbstate <= WBACK;
                        end

                        WBACK:
                        begin
                                o_wb_ack <= 1'd1;
                                wbstate    <= WBIDLE;
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
                                $display($time,": Timer started counting...");
                                state <= COUNTING;
                        end
                end

                COUNTING:
                begin
                        ctr <= ctr + 1;

                        if ( ctr == finalval ) 
                        begin
                                $display($time, ": Timer done counting...");
                                state <= DONE;
                        end                                
                end

                DONE:
                begin
                        done <= 1;

                        if ( start ) 
                        begin
                                $display($time, ": Timer got START from DONE state...");
                                done  <= 0;
                                state <= COUNTING;
                                ctr   <= 0;
                        end
                        else if ( clr ) // Acknowledge. 
                        begin
                                $display($time, ": Timer got done in ACK state...");
                                done  <= 0;
                                state <= IDLE;
                                ctr   <= 0;
                        end
                end
                endcase
        end
end

endmodule

`default_nettype wire
