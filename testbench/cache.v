module cache
(
        input wire               i_clk,
        input wire               i_reset,
        input wire      [31:0]   i_address,
        
        output reg [31:0]       o_data,
        input wire [31:0]       i_data,
        output reg              o_hit,
        output reg              o_miss,
        output reg              o_abort,
        
        input wire              i_rd_en,
        input wire              i_wr_en,
        input wire              i_recover
);

// Create a 64KB memory.
bit [7:0] mem [65535:0];

initial
begin
        // Initialize memory with the program.
       `include "prog.v"
end

// Construct read and write operations.
always @ (posedge i_clk)
begin
        if ( i_rd_en )
        begin
                o_data <= {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]};
                o_hit  <= 1'd1;
                o_miss <= 1'd0;
        end

        if ( i_wr_en )
        begin
                {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]} <= i_data;
        end

        // Give a miss on reset.
        if ( i_reset )
        begin
                o_miss <= 1'd1;
                o_hit  <= 1'd0;
        end

        if ( !i_rd_en && !i_wr_en )
        begin
                o_miss <= 1'd0;
                o_hit  <= 1'd1;
        end
end

endmodule
