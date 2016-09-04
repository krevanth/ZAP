module cache
(
        input wire              i_clk,
        input wire              i_reset,
        input wire      [31:0]  i_address,
        
        output reg      [31:0]  o_data,
        input wire      [31:0]  i_data,
        output reg              o_hit,
        output reg              o_miss,
        output reg              o_abort,
 
        input wire              i_rd_en,
        input wire              i_wr_en,
        input wire              i_recover
);

// Create a 1024 byte memory.
bit [7:0] mem [1024:0];

initial
begin
        // Initialize memory with the program.
       `include "prog.v"
end

// Construct read and write operations.
always @ (posedge i_clk)
begin
        // Cache write.
        if ( i_wr_en )
        begin
                {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]} <= i_data;
        end
end

always @*
begin
        // Reads are combinational.
        if ( i_rd_en || i_wr_en )
        begin
                o_miss = 0;
                o_hit  = !o_miss;
                o_data = {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]};
        end
end

endmodule
