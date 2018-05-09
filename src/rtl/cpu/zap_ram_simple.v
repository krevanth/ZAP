/// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_ram_simple
// HDL          : Verilog-2001
// Module       : zap_ram_simple.v
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// Synthesizes to standard 1R + 1W block RAM. The read and write addresses
// may be specified separately.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : FPGA Init Sequence.
// Clock        : i_clk
// Depends      : --        
// ----------------------------------------------------------------------------

`default_nettype none

module zap_ram_simple #(
        parameter WIDTH = 32,
        parameter DEPTH = 32
)
(
        input wire                          i_clk,

        // Write and read enable.
        input wire                          i_wr_en,
        input wire                          i_rd_en,

        // Write data and address.
        input wire [WIDTH-1:0]              i_wr_data,
        input wire[$clog2(DEPTH)-1:0]       i_wr_addr,

        // Read address and data.
        input wire [$clog2(DEPTH)-1:0]      i_rd_addr,
        output reg [WIDTH-1:0]              o_rd_data
);

// Memory array.
reg [WIDTH-1:0] mem [DEPTH-1:0];

// Initialize block RAM to 0.
initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem[i] = {WIDTH{1'd0}};
end

// Read logic.
always @ (posedge i_clk)
begin
        if ( i_rd_en )
                o_rd_data <= mem [ i_rd_addr ];
end

// Write logic.
always @ (posedge i_clk)
begin
        if ( i_wr_en )  
                mem [ i_wr_addr ] <= i_wr_data;
end

endmodule // ram_simple.v
