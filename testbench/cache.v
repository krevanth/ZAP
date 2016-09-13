`default_nettype none

module cache
(
        input wire              i_clk,
        input wire              i_reset,

        input wire      [31:0]  i_address,     // For data.
        input wire      [31:0]  i_address1,    // For instructions.

        output reg      [31:0]  o_data,
        output reg      [31:0]  o_data1,        // Instruction data.

        input wire      [31:0]  i_data,
        output reg              o_miss,
        output reg              o_hit1,

        output reg              o_abort,        // Data abort.
        output reg              o_abort1,       // Instruction abort.
 
        input wire              i_rd_en,
        input wire              i_wr_en
);

// Create an 8KB memory.
reg [7:0] mem [8191:0];

initial
begin:blk1
        integer i;

        o_abort = 0;
        o_abort1 = 0;

        for(i=0;i<1024;i=i+1)
        begin
                mem[i] = 8'd0;
                $display($time, "mem[%d]=%d",i,mem[i]);
        end

        // Initialize memory with the program.
       `include "prog.v"
end

// Data write port.
always @ (posedge i_clk)
begin
        // Cache write.
        if ( i_wr_en )
        begin
                    // Only data unit can write to cache.
                    {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]} <= i_data;
        end
end

// Data read port.
always @*
begin
        // Reads are combinational.
        if ( i_rd_en || i_wr_en )
        begin
                o_miss = 0;
                o_data = {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]};
        end
        else
        begin
                o_miss = 0;
                o_data = 0;
        end
end

// Instruction read port.
always @*
begin
        o_hit1 = 1;
        o_data1 = {mem[i_address1+3],mem[i_address1+2],mem[i_address1+1],mem[i_address1]};
end

endmodule
