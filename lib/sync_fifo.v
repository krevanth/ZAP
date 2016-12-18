/*
MIT License

Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/*
 * A simple synchronous FIFO. Will ignore writes if full. Will ignore reads
 * if empty. Designed for FPGAs. 
 */

`default_nettype none

module sync_fifo #(parameter WIDTH = 32, parameter DEPTH = 32)
(
        input   wire             i_clk,
        input   wire             i_reset,

        input   wire             i_ack,
        input   wire             i_wr_en,

        input   wire [WIDTH-1:0] i_data,
        output  reg [WIDTH-1:0]  o_data,

        output wire              o_empty,
        output wire              o_full
);

// Xilinx does not allow CLOG2 in localparams.
parameter PTR_WDT = $clog2(DEPTH) + 32'd1;
parameter [PTR_WDT-1:0] DEFAULT = {PTR_WDT{1'd0}}; 

// Initialize pointers, empty and full as a part of the FPGA reset.
// All init to *ZERO*.
reg [PTR_WDT-1:0] rptr_ff;
reg [PTR_WDT-1:0] rptr_nxt;
reg [PTR_WDT-1:0] wptr_ff;
reg empty;
reg full;
reg [PTR_WDT-1:0] wptr_nxt;
reg [WIDTH-1:0] mem [DEPTH-1:0];
wire [WIDTH-1:0] dt;
reg [WIDTH-1:0] dt1;

assign o_empty = empty;
assign o_full  = full;

ram_simple #(.WIDTH(WIDTH), .DEPTH(DEPTH)) U_FIFO_RAM (
        .i_clk(i_clk),
        .i_wr_en(i_wr_en && !o_full),
        .i_rd_en(1'd1),
        .i_wr_data(i_data),
        .i_wr_addr(wptr_ff[PTR_WDT-2:0]),
        .i_rd_addr(rptr_nxt[PTR_WDT-2:0]),
        .o_rd_data(dt)
);

always @ (posedge i_clk)
begin
        dt1     <= i_reset ? 0 : i_data;
        rptr_ff <= i_reset ? 0 : rptr_nxt;
        wptr_ff <= i_reset ? 0 : wptr_nxt;
        empty   <= i_reset ? 1 : ( wptr_nxt == rptr_nxt );
        full    <= i_reset ? 0 : 
                     ( ( wptr_nxt[PTR_WDT-2:0] == rptr_nxt[PTR_WDT-2:0] ) && 
                     ( wptr_nxt              != rptr_nxt) ); 
end

always @*
begin
        wptr_nxt = wptr_ff + (i_wr_en && !o_full);
        rptr_nxt = rptr_ff + (i_ack && !o_empty);
        o_data = ( i_wr_en && !o_full && 
                  (wptr_ff[PTR_WDT-2:0] == rptr_nxt[PTR_WDT-2:0]) ) ? dt1 : dt;
end

endmodule
