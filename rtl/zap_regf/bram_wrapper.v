/*
 * Synthesizes to a 4 read port, 2 write port RAM and supports up to 64 entries.
 */

`default_nettype none
`include "config.vh"

module bram_wrapper
(
        input wire              i_clk_2x,

        input wire              i_reset,

        input wire              i_wen,

        input wire  [5:0]       i_wr_addr_a, 
                                i_wr_addr_b,       // 2 write addresses.

        input wire  [31:0]      i_wr_data_a, 
                                i_wr_data_b,       // 2 write data.

        input wire  [5:0]       i_rd_addr_a, 
                                i_rd_addr_b, 
                                i_rd_addr_c, 
                                i_rd_addr_d,

        output reg  [31:0]      o_rd_data_a,
                                o_rd_data_b, 
                                o_rd_data_c, 
                                o_rd_data_d
);

localparam READ_PH  = 1'd0;
localparam WRITE_PH = 1'd1;

reg phase;
reg wen;
reg  [5:0]  addr_a      [3:0];
reg  [5:0]  addr_b      [3:0];
wire [31:0] rd_data     [3:0];

always @*
begin
        o_rd_data_a = rd_data[0];
        o_rd_data_b = rd_data[1];
        o_rd_data_c = rd_data[2];
        o_rd_data_d = rd_data[3];
end

always @*
begin: blk1
        integer i;

        for (i=0;i<4;i=i+1)
                addr_b[i] = 0;

        if ( phase == READ_PH )
        begin
                wen             = 4'd0;    
                addr_a[0]       = i_rd_addr_a;
                addr_a[1]       = i_rd_addr_b;
                addr_a[2]       = i_rd_addr_c;
                addr_a[3]       = i_rd_addr_d;        
        end
        else
        begin
                wen             = i_wen;

                for(i=0;i<4;i=i+1)
                begin
                        addr_a[i]       = i_wr_addr_a;
                        addr_b[i]       = i_wr_addr_b;
                end
        end 
end

genvar gi;
generate
        for(gi=0;gi<4;gi=gi+1) begin: BLK
        block_ram R1 (
                .i_clk_2x(i_clk_2x), 
                .i_addr_a(addr_a[gi]), 
                .i_addr_b(addr_b[gi]), 
                .i_wen(wen), 
                .i_wr_data_a(i_wr_data_a), 
                .i_wr_data_b(i_wr_data_b), 
                .o_rd_data_a(rd_data[gi])
        );
        end
endgenerate

always @ (posedge i_clk_2x)
begin
        if ( i_reset )
                phase <= READ_PH;
        else
                phase <= !phase;
end

endmodule
