/*
 * ASIC RAM.
 * Do not use for FPGA.
 */

module ram
(
        input wire              i_clk,
        input wire              i_clk_2x,

        input wire              i_reset,

        input wire              i_wen,

        input wire [5:0]        i_wr_addr_a, // 2 write addresses. 
                                i_wr_addr_b, 

        input wire [31:0]       i_wr_data_a, // 2 write data.
                                i_wr_data_b,

        input wire [5:0]        i_rd_addr_a, 
                                i_rd_addr_b, 
                                i_rd_addr_c, 
                                i_rd_addr_d,

        output reg [31:0]       o_rd_data_a, 
                                o_rd_data_b, 
                                o_rd_data_c, 
                                o_rd_data_d
);

reg [31:0] mem [63:0];
integer i;

initial
begin
        for(i=0;i<64;i=i+1)
                mem[i] = 32'd0;
end

// Write on posedge.
always @ (posedge i_clk_2x)
begin
        if ( i_wen )
        begin       
                mem [ i_wr_addr_a ] <= i_wr_data_a;
                mem [ i_wr_addr_b ] <= i_wr_data_b;
        end
end

// Read on negedge.
always @ (posedge i_clk_2x)
begin
        o_rd_data_a <= mem [ i_rd_addr_a ];
        o_rd_data_b <= mem [ i_rd_addr_b ];
        o_rd_data_c <= mem [ i_rd_addr_c ];
        o_rd_data_d <= mem [ i_rd_addr_d ];
end

endmodule
