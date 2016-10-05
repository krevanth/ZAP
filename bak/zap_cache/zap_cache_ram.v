`default_nettype none

/*
 * This is the basic data structure used to implement
 * a unified cache for ZAP.
 */

module zap_cache_ram
#(
        parameter DEPTH    = 64,
        parameter WIDTH    = 128
)
(
        input  wire                             i_clk,
        input  wire                             i_reset,

        input  wire [$clog2(DEPTH)-1:0]         i_wr_addr,
        input  wire [WIDTH-1:0]                 i_wr_data,
        input  wire                             i_wr_en,

        input  wire [$clog2(DEPTH)-1:0]         i_rd_addr_1,
        input  wire [$clog2(DEPTH)-1:0]         i_rd_addr_2,

        output reg  [WIDTH-1:0]                 o_rd_data_1,
        output reg  [WIDTH-1:0]                 o_rd_data_2
);

reg [WIDTH-1:0] mem_0 [DEPTH-1:0];      // Primary memory
reg [WIDTH-1:0] mem_1 [DEPTH-1:0];      // Helper memory.

always @ (negedge i_clk)
begin
        if ( i_wr_en )
        begin
                mem_0 [ i_wr_addr ] <= i_wr_data; 
                mem_1 [ i_wr_addr ] <= i_wr_data;
        end 
end

always @ (negedge i_clk)
begin
        o_rd_data_1     <=      mem_0 [ i_rd_addr_1 ];
        o_rd_data_2     <=      mem_1 [ i_rd_addr_2 ];
end

endmodule
