`default_nettype none

module zap_cache_main
#(
        parameter SIZE_IN_BYTES = 8192
)
(
        input wire              i_clk,

        input wire      [31:0]  i_daddress,     // For data.
        input wire      [31:0]  i_iaddress,     // For instructions.

        output reg      [31:0]  o_ddata,
        output reg      [31:0]  o_idata,        // Instruction data - 36-bit.

        input wire      [3:0]   i_ben,          // Byte enables.
        input wire      [31:0]  i_ddata,        // Input data.

        input wire              i_wr_en         // Write.
);

reg [7:0] mem0  [SIZE_IN_BYTES/4 - 1:0];
reg [7:0] mem1  [SIZE_IN_BYTES/4 - 1:0];
reg [7:0] mem2  [SIZE_IN_BYTES/4 - 1:0];
reg [7:0] mem3  [SIZE_IN_BYTES/4 - 1:0];

initial
begin:blk1
        integer i;
        integer j;
        reg [7:0] mem [SIZE_IN_BYTES-1:0];

        j = 0;

        for(i=0;i<SIZE_IN_BYTES/4;i=i+1)
        begin
                mem0[i]  = 8'd0;
                mem1[i]  = 8'd0;
                mem2[i]  = 8'd0;
                mem3[i]  = 8'd0;
        end

        for ( i=0;i<SIZE_IN_BYTES;i=i+1)
                mem[i] = 8'd0;

        `include "prog.v"

        for (i=0;i<SIZE_IN_BYTES/4;i=i+1)
        begin
                {mem3[i], mem2[i], mem1[i], mem0[i]} = {mem[j+3], mem[j+2], mem[j+1], mem[j]};
                j = j + 4;
        end
end

// Data write port.
always @ (posedge i_clk)
        if ( i_wr_en && i_ben[0] )
                mem0[i_daddress  >> 2] <= i_ddata;

always @ (posedge i_clk)
        if ( i_wr_en && i_ben[1] )
                mem1[i_daddress >> 2] <= i_ddata >> 8;

always @ (posedge i_clk)
        if ( i_wr_en && i_ben[2] )
                mem2[i_daddress >> 2] <= i_ddata >> 16;

always @ (posedge i_clk)
        if ( i_wr_en && i_ben[3] )
                mem3[i_daddress >> 2] <= i_ddata >> 24;

// Data reads.
always @* o_ddata[7:0]   = mem0[i_daddress >> 2];
always @* o_ddata[15:8]  = mem1[i_daddress >> 2];
always @* o_ddata[23:16] = mem2[i_daddress >> 2];
always @* o_ddata[31:24] = mem3[i_daddress >> 2];

// Instruction reads.
always @* o_idata[7:0]   = mem0[i_iaddress >> 2];
always @* o_idata[15:8]  = mem1[i_iaddress >> 2];
always @* o_idata[23:16] = mem2[i_iaddress >> 2];
always @* o_idata[31:24] = mem3[i_iaddress >> 2];

endmodule
