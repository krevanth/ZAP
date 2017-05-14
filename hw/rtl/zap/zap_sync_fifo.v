// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_sync_fifo.v  
// HDL          : Verilog-2001
// Module       : zap_sync_fifo
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// This RTL describes a synchronous FIFO built around synchronous block RAM.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high reset.
// Clock        : Core clock
// Depends      : --
// ----------------------------------------------------------------------------

`default_nettype none

module zap_sync_fifo #(parameter WIDTH = 32, parameter DEPTH = 32, parameter FWFT = 1)
(
        input   wire             i_clk,
        input   wire             i_reset,

        input   wire             i_ack,
        input   wire             i_wr_en,

        input   wire [WIDTH-1:0] i_data,
        output  reg [WIDTH-1:0]  o_data,

        output wire              o_empty,
        output wire              o_full,
        output wire              o_empty_n,
        output wire              o_full_n,
        output wire              o_full_n_nxt
);

// Xilinx ISE does not allow $CLOG2 in localparams.
parameter PTR_WDT = $clog2(DEPTH) + 32'd1;
parameter [PTR_WDT-1:0] DEFAULT = {PTR_WDT{1'd0}}; 

//
// Initialize pointers, empty and full as a part of the FPGA reset.
// All init to *ZERO*.
//
reg [PTR_WDT-1:0] rptr_ff;
reg [PTR_WDT-1:0] rptr_nxt;
reg [PTR_WDT-1:0] wptr_ff;
reg empty, nempty;
reg full, nfull;
reg [PTR_WDT-1:0] wptr_nxt;
reg [WIDTH-1:0] mem [DEPTH-1:0]; // Block RAM.
wire [WIDTH-1:0] dt;
reg [WIDTH-1:0] dt1;

reg sel_ff;
reg [WIDTH-1:0] bram_ff; // Block RAM read register.
reg [WIDTH-1:0] dt_ff;

assign o_empty = empty;
assign o_full  = full;
assign o_empty_n = nempty;
assign o_full_n = nfull;

assign o_full_n_nxt = i_reset ? 1 :
                      !( ( wptr_nxt[PTR_WDT-2:0] == rptr_nxt[PTR_WDT-2:0] ) &&
                       ( wptr_nxt != rptr_nxt ) );


// FIFO write logic.
always @ (posedge i_clk)
        if ( i_wr_en && !o_full )
                mem[wptr_ff[PTR_WDT-2:0]] <= i_data;

generate
begin:gb1
        if ( FWFT == 1 )
        begin:f1
                // Retimed output data compared to normal FIFO.
                always @ (posedge i_clk) 
                begin
                         dt_ff <= i_data;
                        sel_ff <= ( i_wr_en && (wptr_ff == rptr_nxt) );
                       bram_ff <= mem[rptr_nxt[PTR_WDT-2:0]];
                end
        
                // Output signal steering MUX.
                always @*
                begin
                        o_data = sel_ff ? dt_ff : bram_ff;
                end
        end
        else
        begin:f0
                always @ (posedge i_clk)
                begin
                        if ( i_ack && nempty ) // Read request and not empty.
                        begin
                                o_data <= mem [ rptr_ff[PTR_WDT-2:0] ];
                        end
                end
        end
end
endgenerate

// Flip-flop update.
always @ (posedge i_clk)
begin
        dt1     <= i_reset ? 0 : i_data;
        rptr_ff <= i_reset ? 0 : rptr_nxt;
        wptr_ff <= i_reset ? 0 : wptr_nxt;
        empty   <= i_reset ? 1 : ( wptr_nxt == rptr_nxt );
        nempty  <= i_reset ? 0 : ( wptr_nxt != rptr_nxt );
        nfull   <= o_full_n_nxt;
        full    <= !o_full_n_nxt;
end

// Pointer updates.
always @*
begin
        wptr_nxt = wptr_ff + (i_wr_en && !o_full);
        rptr_nxt = rptr_ff + (i_ack && !o_empty);
end

endmodule
