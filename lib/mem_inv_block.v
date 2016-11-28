`default_nettype none

/*
 * Use this to built single cycle clearing tag RAMs and TLBs for ZAP. For
 * cache, use mem_ben_block.
 */

module mem_inv_block #(
        parameter DEPTH = 32,
        parameter WIDTH = 32   // Not including valid bit.
)(  
        input wire                           i_clk,
        input wire                           i_reset,
        input wire   [WIDTH-1:0]             i_wdata,
        input wire                           i_wen, 
        input wire                           i_ren,
        input wire                           i_refresh, 
        input wire                           i_inv,
        input wire   [$clog2(DEPTH)-1:0]     i_raddr, 
        input wire   [$clog2(DEPTH)-1:0]     i_waddr,

        output reg [WIDTH-1:0]               o_rdata,
        output reg                           o_rdav
);

reg [WIDTH-1:0] mem_ff [DEPTH-1:0];
reg [DEPTH-1:0] dav_ff;

wire [$clog2(DEPTH)-1:0] addr_r;
wire en_r;

assign addr_r = i_refresh ? i_waddr : i_raddr;
assign en_r   = i_refresh ? 1'd1    : i_ren;

always @ (posedge i_clk)
begin: block_ram
        if ( en_r )
                o_rdata <= mem_ff[ addr_r ];

        if ( i_wen )
                mem_ff [ i_waddr ] <= i_wdata;
end

always @ (posedge i_clk)
begin: flip_flops
        if ( i_reset | i_inv )
               dav_ff <=  {DEPTH{1'd0}};
        else
        begin
                if ( i_wen )
                        dav_ff [ i_waddr ] <= 1'd1;

                o_rdav <= dav_ff [ i_raddr ];
        end
end

endmodule
