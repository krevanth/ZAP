`include "config.vh"

module cache
(
        input wire              i_clk,
        input wire              i_reset,

        input wire      [31:0]  i_address,     // For data.
        input wire      [31:0]  i_address1,    // For instructions.

        output reg      [31:0]  o_data,
        output reg      [31:0]  o_data1,        // Instruction data - 36-bit.

        input wire      [3:0]   i_ben,

        input wire      [31:0]  i_cpsr,         // CPSR.

        input wire      [31:0]  i_data,
        output reg              o_miss,
        output reg              o_hit1,

        output reg              o_abort,        // Data abort.
        output reg              o_abort1,       // Instruction abort.
 
        input wire              i_rd_en,
        input wire              i_wr_en
);

`include "modes.vh"

// Create an 8KB unified cache memory.
reg [7:0] mem  [8192-1:0];

// Create a seed at the start of simulation.
integer seed = `SEED ;

initial
begin:blk1
        integer i;

        o_abort = 0;
        o_abort1 = 0;

        for(i=0;i<8192;i=i+1)
        begin
                mem[i]  = 8'd0;

                `ifdef SIM
                        $display($time, "mem[%d]=%d",i,mem[i]);
                `endif
        end

        // Initialize memory with the program.
        `include `MEMORY_IMAGE
end

// Data write port.
always @ (posedge i_clk)
begin
        // Cache write.
        if ( i_wr_en )
        begin
                if ( i_ben[0] )                        
                        mem[i_address] <= i_data;
                if ( i_ben[1] )
                        mem[i_address+1] <= i_data >> 8;
                if ( i_ben[2] )
                        mem[i_address+2] <= i_data >> 16;
                if ( i_ben[3] )
                        mem[i_address+3] <= i_data >> 24;
        end
end

initial
begin
        o_miss = 1'd1;
        o_hit1 = 1'd0;
end

always @ (negedge i_clk)
begin
        o_miss = $random(seed);               
        o_hit1 = $random(seed);                       
end

// Data read port.
always @*
begin
        // Reads are combinational.
        if ( i_rd_en || i_wr_en )
        begin
                o_data = {mem[i_address+3],mem[i_address+2],mem[i_address+1],mem[i_address]};
        end
        else
        begin
                o_data = 0;
        end
end

// Instruction read port.
always @*
begin
        o_data1  = {mem[i_address1+3],mem[i_address1+2],mem[i_address1+1],mem[i_address1]};
        o_abort1 = 0;
end

endmodule
