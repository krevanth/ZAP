/*
 * Will synthesize to a 2 write port, 1 read port block RAM.
 */

module block_ram #(
        parameter       DATA_WDT        =       32,
        parameter       ADDR_WDT        =       6,
        parameter       DEPTH           =       46
)
(
        input wire                      i_clk_2x,

        input wire      [ADDR_WDT-1:0]  i_addr_a,
        input wire      [ADDR_WDT-1:0]  i_addr_b,

        input wire                      i_wen,

        input wire      [DATA_WDT-1:0]  i_wr_data_a,
        input wire      [DATA_WDT-1:0]  i_wr_data_b,

        output reg      [DATA_WDT-1:0]  o_rd_data_a
);

reg [DATA_WDT-1:0] mem [DEPTH-1:0];

always @ (posedge i_clk_2x)
begin
        mem [ i_addr_a ] <= i_wr_data_a;
        mem [ i_addr_b ] <= i_wr_data_b;        
end

always @ (posedge i_clk_2x)
begin
        o_rd_data_a     <= mem[ i_addr_a ];
end

endmodule
