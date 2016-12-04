`default_nettype none

/*
 * A simple RAM that maps to FPGA BRAM resources.
 */

module ram_simple #(
        parameter WIDTH = 32,
        parameter DEPTH = 32
)
(
        input wire                          i_clk,

        input wire                          i_wr_en,
        input wire                          i_rd_en,

        input wire [WIDTH-1:0]              i_wr_data,
        input wire[$clog2(DEPTH)-1:0]       i_wr_addr,

        input wire [$clog2(DEPTH)-1:0]      i_rd_addr,
        output reg [WIDTH-1:0]              o_rd_data
);

reg [WIDTH-1:0] mem [DEPTH-1:0];

// Initialize block RAM to ZERO.
initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem[i] = {WIDTH{1'd0}};
end

always @ (posedge i_clk)
begin
        if ( i_rd_en )
                o_rd_data <= mem [ i_rd_addr ];
end

always @ (posedge i_clk)
begin
        if ( i_wr_en )  
                mem [ i_wr_addr ] <= i_wr_data;
end

endmodule
