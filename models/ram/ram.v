`default_nettype none
`include "config.vh"

module ram
#(
        parameter SIZE_IN_BYTES = 8192
)
(
        input wire              i_clk,

        input wire      [31:0]  i_daddress,     // For data.
        input wire      [31:0]  i_iaddress,     // For instructions.

        input wire              i_instr_stall,   // From CPU.

        output reg      [31:0]  o_ddata,
        output reg      [31:0]  o_idata,        // Instruction data - 32-bit.

        input wire      [3:0]   i_ben,          // Byte enables.
        input wire      [31:0]  i_ddata,        // Input data.

        input wire      [31:0]  i_cpsr,

        output reg              o_code_hit,
        output reg              o_data_stall,
        output reg              o_code_abort,
        output reg              o_data_abort,

        input wire              i_wr_en         // Write.
);

integer seed = `SEED;

`ifdef SIM
always @ (negedge i_clk)
begin
        o_code_hit = $random(seed);
        o_data_stall = $random(seed);
        o_code_abort = 0;
        o_data_abort = 0;
end
`endif

`ifndef SIM
initial
begin
        o_code_hit   = 1;
        o_data_stall = 0;
        o_code_abort = 0;
        o_data_abort = 0;
end
`endif

reg [31:0] ram  [SIZE_IN_BYTES/4 - 1:0];

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

// Data write port.
always @ (posedge i_clk)
        if ( i_wr_en && i_ben[0] )
                ram[i_daddress  >> 2][7:0] <= i_ddata[7:0];

always @ (posedge i_clk)
        if ( i_wr_en && i_ben[1] )
                ram[i_daddress >> 2][15:8] <= i_ddata[15:8];

always @ (posedge i_clk)
        if ( i_wr_en && i_ben[2] )
                ram[i_daddress >> 2][23:16] <= i_ddata[23:16];

always @ (posedge i_clk)
        if ( i_wr_en && i_ben[3] )
                ram[i_daddress >> 2][31:24] <= i_ddata[31:24];

// Data reads.
always @ (posedge i_clk) 
        if ( !o_data_stall ) 
                o_ddata <= ram[i_daddress >> 2];

// Instruction reads.
always @ (posedge i_clk) 
        if ( o_code_hit && !i_instr_stall )  
                o_idata   <= ram[i_iaddress >> 2];

endmodule
