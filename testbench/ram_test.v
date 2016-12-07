///////////////////////////////////////////////////////////////////////////////

`include "config.vh"

module model_ram #(parameter SIZE_IN_BYTES = 4096, parameter INIT = 1)  (

input           i_clk,
input           i_wen,
input           i_ren,
input  [3:0]    i_ben,
input  [31:0]   i_data,
input  [31:0]   i_addr,

output reg[31:0]   o_data,
output reg         o_stall

);

reg [31:0] ram [SIZE_IN_BYTES/4 -1:0];

initial
begin:blk1
        integer i;
        integer j;
        reg [7:0] mem [SIZE_IN_BYTES-1:0];

                j = 0;

                for ( i=0;i<SIZE_IN_BYTES;i=i+1)
                        mem[i] = 8'd0;

                `include `MEMORY_IMAGE

                for (i=0;i<SIZE_IN_BYTES/4;i=i+1)
                begin
                        ram[i] = {mem[j+3], mem[j+2], mem[j+1], mem[j]};
                        j = j + 4;
                end
end

integer seed = `SEED;

`ifdef STALL
always @ (negedge i_clk)
        o_stall = $random;
`else
        initial o_stall = 0;
`endif

always @ (posedge i_clk)
begin
       if ( i_ren && !o_stall )
                o_data <= ram [ i_addr >> 2 ];  

        if ( i_wen && !o_stall )
        begin
                if ( i_ben[0] ) ram [ i_addr >> 2 ][7:0]   <= i_data[7:0];
                if ( i_ben[1] ) ram [ i_addr >> 2 ][15:8]  <= i_data[15:8];
                if ( i_ben[2] ) ram [ i_addr >> 2 ][23:16] <= i_data[23:16];
                if ( i_ben[3] ) ram [ i_addr >> 2 ][31:24] <= i_data[31:24];
        end
end

endmodule

///////////////////////////////////////////////////////////////////////////////


