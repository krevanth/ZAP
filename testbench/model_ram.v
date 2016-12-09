///////////////////////////////////////////////////////////////////////////////

`include "config.vh"

module model_ram #(parameter SIZE_IN_BYTES = 4096)  (

input              i_clk,

input              i_wen_rw,
input              i_ren_rw,
input  [3:0]       i_ben_rw,
input  [31:0]      i_data_rw,
input  [31:0]      i_addr_rw,
output reg[31:0]   o_data_rw,
output reg         o_stall_rw,

input              i_ren_ro,
input  [31:0]      i_addr_ro,
output reg [31:0]  o_data_ro,
output reg         o_stall_ro

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
begin
        o_stall_rw = $random;
        o_stall_ro = $random;
end
`else
        initial o_stall_rw = 0;
        initial o_stall_ro = 0;
`endif

// RW port.
always @ (posedge i_clk)
begin
       if ( i_ren_rw && !o_stall_rw )
                o_data_rw <= ram [ i_addr_rw >> 2 ];  

        if ( i_wen_rw && !o_stall_rw )
        begin
                if ( i_ben_rw[0] ) ram [ i_addr_rw >> 2 ][7:0]   <= i_data_rw[7:0];
                if ( i_ben_rw[1] ) ram [ i_addr_rw >> 2 ][15:8]  <= i_data_rw[15:8];
                if ( i_ben_rw[2] ) ram [ i_addr_rw >> 2 ][23:16] <= i_data_rw[23:16];
                if ( i_ben_rw[3] ) ram [ i_addr_rw >> 2 ][31:24] <= i_data_rw[31:24];
        end
end

// RO port.
always @ (posedge i_clk)
begin
        if ( i_ren_ro && !o_stall_ro )
                o_data_ro <= ram [ i_addr_ro >> 2 ];
end

endmodule

///////////////////////////////////////////////////////////////////////////////


