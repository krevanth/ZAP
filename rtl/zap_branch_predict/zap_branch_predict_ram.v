`default_nettype none

/*
 * Branch predictor becomes BLOCK RAM.
 */

`include "config.vh"

module zap_branch_predict_ram 
#(
        parameter NUMBER_OF_ENTRIES = 64,
        parameter ENTRY_SIZE = 2
)
(
        input wire                                  i_clk, 
        input wire                                  i_reset, 
        input wire                                  i_wr_en,
        input wire  [$clog2(NUMBER_OF_ENTRIES)-1:0] i_wr_addr, 
        input wire  [$clog2(NUMBER_OF_ENTRIES)-1:0] i_rd_addr,
        input  wire  [ENTRY_SIZE-1:0]               i_wr_data,

        output reg [ENTRY_SIZE-1:0]                 o_rd_data
);

reg [ENTRY_SIZE-1:0] mem [NUMBER_OF_ENTRIES-1:0];

// Read.
always @ (posedge i_clk)
                o_rd_data <= mem [ i_rd_addr ];

// Write (Gated)
always @ (posedge i_clk)
        if ( i_wr_en )
                mem [ i_wr_addr ] <= i_wr_data;

// The initial block initializes the memory.
initial
begin: blk1
                integer i;

                `ifdef SIM
                        $display($time, "(FPGA)Initializing branch RAM to 2'b00...");
                `endif

                // Must initialize to 0.
                for(i=0;i<NUMBER_OF_ENTRIES;i=i+1)
                        mem[i] = 0;
end

endmodule
