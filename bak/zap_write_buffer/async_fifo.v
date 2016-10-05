`default_nettype none

// ============================================================================
// Filename:
// async_fifo.v
//             
// Brief Description:
// A standard dual clock FIFO.
//                    
// Depends on:
// cdc_dual_flop.v
//
// Description:
// This is a dual clock FIFO that can transfer bursty data efficiently from
// one clock domain to another. FIFO full and empty conditions are efficiently
// implemented using ideas from Clifford Cumming's paper presented as SNUG
// 2002. ALL OUTPUTS EXCEPT O_DATA ARE FULLY REGISTERED. O_DATA IS A FUNCTION
// OF REGISTERED SIGNALS ONLY. That is to reduce the number of flip-flops.
// ============================================================================

module async_fifo
#(
        parameter WIDTH = 105,
        parameter DEPTH = 8
)
(
        // Read clock and reset.
        input wire              i_rclk,
        input wire              i_rrst_n,
        
        // Write clock and reset.
        input wire              i_wclk,
        input wire              i_wrst_n,
        
        // Read and write enables.
        input wire              i_ren,
        input wire              i_wen,
        
        // Write data.
        input  wire [WIDTH-1:0] i_wdata,

        // Read data.
        output wire [WIDTH-1:0] o_rdata,
        
        // FIFO status.
        output wire             o_wfull,
        output wire             o_rempty
);

localparam PTR_WIDTH = $clog2(DEPTH);

reg                  wfull_ff, wfull_nxt;   
reg                  rempty_ff, rempty_nxt;   
reg  [PTR_WIDTH-1:0] rptr_ff, rptr_nxt;
reg  [PTR_WIDTH-1:0] wptr_ff, wptr_nxt;
reg  [PTR_WIDTH-1:0] rgray_ff, rgray_nxt;
reg  [PTR_WIDTH-1:0] wgray_ff, wgray_nxt;
wire [PTR_WIDTH-1:0] rgray_ff_wr_clk_sync;
wire [PTR_WIDTH-1:0] wgray_ff_rd_clk_sync;
reg  [WIDTH-1:0]     mem [DEPTH-1:0];

// ---------------------- WRITE CLOCK DOMAIN-----------------------------------

always @*  wptr_nxt = wptr_ff + ( i_wen && !wfull_ff );
always @* wgray_nxt = wptr_nxt ^ (wptr_nxt >> 1);
always @* wfull_nxt = ((rgray_ff_wr_clk_sync ~^ wgray_nxt) == {(PTR_WIDTH-2){1'd1}});
assign o_wfull = wfull_ff;

always @ (posedge i_wclk or negedge i_wrst_n)
begin
        if ( !i_wrst_n )
                {wptr_ff,wgray_ff,wfull_ff}  <= 0;
        else
                {wptr_ff,wgray_ff,wfull_ff}  <= {wptr_nxt,wgray_nxt,wfull_nxt};
end

cdc_dual_flop #(.WIDTH(PTR_WIDTH)) u_rptr_wr_clk_sync
(
        .i_clk          (i_wclk),
        .i_rst_n        (i_wrst_n),
        .i_sig          (rgray_ff),
        .o_sig          (rgray_ff_wr_clk_sync)        
);

// ----------------------- READ CLOCK DOMAIN ----------------------------------

always @* rptr_nxt = rptr_ff +  ( i_ren && !rempty_ff );
always @* rgray_nxt = rptr_nxt ^ (rptr_nxt >> 1);
always @* rempty_nxt = (wgray_ff_rd_clk_sync == rgray_nxt);
assign o_rempty = rempty_ff;

always @ (posedge i_rclk or negedge i_rrst_n)
        if ( !i_rrst_n )
                {rptr_ff,rgray_ff,rempty_ff}  <= 1;
        else
                {rptr_ff,rgray_ff,rempty_ff}  <= {rptr_nxt, rgray_nxt, rempty_nxt};

cdc_dual_flop #(.WIDTH(PTR_WIDTH)) u_wptr_rd_clk_sync
(
        .i_clk          (i_rclk),
        .i_rst_n        (i_rrst_n),
        .i_sig          (wgray_ff),
        .o_sig          (wgray_ff_rd_clk_sync)        
);

// ---------------------------- MEMORY ----------------------------------------

always @ (posedge i_wclk)
begin
        if ( i_wen && !wfull_ff )
                mem [wptr_ff] <= i_wdata;
end

assign o_rdata = mem[rptr_ff];

endmodule
