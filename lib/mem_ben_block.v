`default_nettype none

module mem_ben_block128 #(
        parameter  DEPTH  = 32
)(
        input   wire                           i_clk,
        input   wire   [15:0]                  i_ben,
        input   wire                           i_ren,
        input   wire   [$clog2(DEPTH)-1:0]     i_addr,
        input   wire   [127:0]                 i_wdata,
        output  reg    [127:0]                 o_rdata 
);

reg [127:0] mem_ff [DEPTH-1:0];

// Initialize block RAM to 0.
initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem_ff[i] = 128'd0;
end

always @ (posedge i_clk)
begin: block_ram
        if ( i_ren )
                o_rdata <= mem_ff [ i_addr ];

        if ( i_ben[0] )    mem_ff[i_addr][7:0]       <=      i_wdata[7:0];
        if ( i_ben[1] )    mem_ff[i_addr][15:8]      <=      i_wdata[15:8];
        if ( i_ben[2] )    mem_ff[i_addr][23:16]     <=      i_wdata[23:16];
        if ( i_ben[3] )    mem_ff[i_addr][31:24]     <=      i_wdata[31:24];
        if ( i_ben[4] )    mem_ff[i_addr][39:32]     <=      i_wdata[39:32];
        if ( i_ben[5] )    mem_ff[i_addr][47:40]     <=      i_wdata[47:40];
        if ( i_ben[6] )    mem_ff[i_addr][55:48]     <=      i_wdata[55:48];
        if ( i_ben[7] )    mem_ff[i_addr][63:56]     <=      i_wdata[63:56];
        if ( i_ben[8] )    mem_ff[i_addr][71:64]     <=      i_wdata[71:64];
        if ( i_ben[9] )    mem_ff[i_addr][79:72]     <=      i_wdata[79:72];
        if ( i_ben[10] )   mem_ff[i_addr][87:80]     <=      i_wdata[87:80];
        if ( i_ben[11] )   mem_ff[i_addr][95:88]     <=      i_wdata[95:88];
        if ( i_ben[12] )   mem_ff[i_addr][103:96]    <=      i_wdata[103:96];
        if ( i_ben[13] )   mem_ff[i_addr][111:104]   <=      i_wdata[111:104];
        if ( i_ben[14] )   mem_ff[i_addr][119:112]   <=      i_wdata[119:112];
        if ( i_ben[15] )   mem_ff[i_addr][127:120]   <=      i_wdata[127:120];

end

endmodule
