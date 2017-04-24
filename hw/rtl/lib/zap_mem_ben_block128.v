/// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_mem_ben_block128
// HDL          : Verilog-2001
// Module       : zap_mem_ben_block128.v
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// A 128-bit by N block RAM with byte enables. Should synthesize natively on
// most FPGAs. Synthesizes correctly on a Spartan 6 part.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : FPGA Init Sequence.
// Clock        : i_clk
// Depends      : --        
// ----------------------------------------------------------------------------

`default_nettype none

module zap_mem_ben_block128 (

i_clk,  // RAM clock.
i_ben,  // Write enable per byte. 16-bit wide since 16 bytes per memory location.
i_ren,  // Read enable.
i_raddr, // Read Address.
i_waddr, // Write address.
i_wdata,// Write data.
o_rdata // Read data.

);

// Depth of memory.
parameter  DEPTH  = 32;

input   wire                           i_clk;
input   wire   [15:0]                  i_ben;
input   wire                           i_ren;
input   wire   [$clog2(DEPTH)-1:0]     i_raddr, i_waddr;
input   wire   [127:0]                 i_wdata;
output  reg    [127:0]                 o_rdata;

// Block RAM
reg [127:0] mem_ff [DEPTH-1:0];

wire en_r                       = i_ren;
wire [$clog2(DEPTH)-1:0] radr   = i_raddr;

// Initialize block RAM to 0.
initial
begin: blk1
        integer i;

        $display($time,"Setting %m to zero on FPGA power up...");

        for(i=0;i<DEPTH;i=i+1)
                mem_ff[i] = 128'd0;
end

// Block RAM read logic.
always @ (posedge i_clk)
begin: block_ram_read
        if ( en_r )
                o_rdata <= mem_ff [ radr ];
end

// Block RAM write logic (16 byte enables per entry).
always @ (posedge i_clk)
begin: block_ram_write
        if ( i_ben[0]  )   mem_ff[i_waddr][7:0]       <=      i_wdata[7:0];
        if ( i_ben[1]  )   mem_ff[i_waddr][15:8]      <=      i_wdata[15:8];
        if ( i_ben[2]  )   mem_ff[i_waddr][23:16]     <=      i_wdata[23:16];
        if ( i_ben[3]  )   mem_ff[i_waddr][31:24]     <=      i_wdata[31:24];
        if ( i_ben[4]  )   mem_ff[i_waddr][39:32]     <=      i_wdata[39:32];
        if ( i_ben[5]  )   mem_ff[i_waddr][47:40]     <=      i_wdata[47:40];
        if ( i_ben[6]  )   mem_ff[i_waddr][55:48]     <=      i_wdata[55:48];
        if ( i_ben[7]  )   mem_ff[i_waddr][63:56]     <=      i_wdata[63:56];
        if ( i_ben[8]  )   mem_ff[i_waddr][71:64]     <=      i_wdata[71:64];
        if ( i_ben[9]  )   mem_ff[i_waddr][79:72]     <=      i_wdata[79:72];
        if ( i_ben[10] )   mem_ff[i_waddr][87:80]     <=      i_wdata[87:80];
        if ( i_ben[11] )   mem_ff[i_waddr][95:88]     <=      i_wdata[95:88];
        if ( i_ben[12] )   mem_ff[i_waddr][103:96]    <=      i_wdata[103:96];
        if ( i_ben[13] )   mem_ff[i_waddr][111:104]   <=      i_wdata[111:104];
        if ( i_ben[14] )   mem_ff[i_waddr][119:112]   <=      i_wdata[119:112];
        if ( i_ben[15] )   mem_ff[i_waddr][127:120]   <=      i_wdata[127:120];
end

endmodule // mem_ben_block128.v
