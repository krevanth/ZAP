`default_nettype none
`include "config.vh"

/*
Filename --
zap_memory_main.v

HDL --
Verilog 2005.

Description --
This stage merely acts as a buffer in between the ALU stage and the register file (i.e., writeback stage). This stage is intended
to allow the memory to use up 1 clock cycle to perform operations without the pipeline losing throughput.
*/

module zap_memory_main
#(
        parameter FLAG_WDT = 32,
        // Number of physical registers.
        parameter PHY_REGS = 46
)
(
        // Clock and reset.
        input wire                          i_clk,
        input wire                          i_reset,

        // Pipeline control signals.
        input wire                          i_clear_from_writeback,
        input wire                          i_data_stall,

        // Memory stuff.
        input   wire                        i_mem_load_ff,
        input   wire [1:0]                  i_mem_address_ff, // Address generated.

        // Data read from memory.
        input   wire [31:0]                 i_mem_rd_data,

        input   wire                        i_mem_fault,        // Fault in.
        output  reg                         o_mem_fault,        // Fault out.

        // Data valid and buffered PC.
        input wire                          i_dav_ff,
        input wire [31:0]                   i_pc_plus_8_ff,

        // ALU value, flags,and where to write the value.
        input wire [31:0]                   i_alu_result_ff,
        input wire  [FLAG_WDT-1:0]          i_flags_ff,
        input wire [$clog2(PHY_REGS)-1:0]   i_destination_index_ff,

        // Interrupts.
        input   wire                        i_irq_ff,
        input   wire                        i_fiq_ff,
        input   wire                        i_instr_abort_ff,
        input   wire                        i_swi_ff,

        // Memory SRCDEST index. For loads, this tells the register file where to
        // put the read data.
        input wire [$clog2(PHY_REGS)-1:0]   i_mem_srcdest_index_ff,     // Set to RAZ if invalid.

        // SRCDEST value too.
        input wire [31:0]                   i_mem_srcdest_value_ff,

        // memory size.
        input wire                          i_sbyte_ff, 
                                            i_ubyte_ff, 
                                            i_shalf_ff, 
                                            i_uhalf_ff,

        // undefined instr.
        input wire                         i_und_ff,
        output reg                         o_und_ff,

        // ALU result and flags.
        output reg  [31:0]                   o_alu_result_ff,
        output reg  [FLAG_WDT-1:0]           o_flags_ff,

        // Where to write ALU and memory read target register.
        output reg [$clog2(PHY_REGS)-1:0]    o_destination_index_ff,
        output reg [$clog2(PHY_REGS)-1:0]    o_mem_srcdest_index_ff, // Set to RAZ if invalid.

        // Outputs valid and PC buffer.
        output reg                           o_dav_ff,
        output reg [31:0]                    o_pc_plus_8_ff,

        // The whole interrupt signaling scheme.
        output reg                           o_irq_ff,
        output reg                           o_fiq_ff,
        output reg                           o_swi_ff,
        output reg                           o_instr_abort_ff,

        // Memory load information is passed down.
        output reg                           o_mem_load_ff,
        output reg  [31:0]                   o_mem_rd_data
);

`include "regs.vh"

reg                             i_mem_load_ff2          ;
reg [31:0]                      i_mem_srcdest_value_ff2 ;
reg [1:0]                       i_mem_address_ff2       ;
reg                             i_sbyte_ff2             ;
reg                             i_ubyte_ff2             ;
reg                             i_shalf_ff2             ;
reg                             i_uhalf_ff2             ;
reg [31:0]                      mem_rd_data_ff          ;

// Absorbed into block RAM.
always @ (posedge i_clk)
        if ( !i_data_stall )
                mem_rd_data_ff <= i_mem_rd_data;

task clear;
begin
        o_dav_ff                  <= 0;
        o_irq_ff                  <= 0;
        o_fiq_ff                  <= 0;
        o_swi_ff                  <= 0;
        o_instr_abort_ff          <= 0;
        o_und_ff                  <= 0;
        o_mem_fault               <= 0;
end
endtask

/*
        On reset or on a clear from WB, we will disable the vectors
        in this unit. Else, we will just flop everything out.
*/
always @ (posedge i_clk)
if ( i_reset )
begin
        clear;
end
else if ( i_clear_from_writeback )
begin
        clear;
end
else if ( i_data_stall )
begin
        // Stall unit. Outputs do not change.
end
else
begin
        // Just flop everything out.
        o_alu_result_ff       <= i_alu_result_ff;
        o_flags_ff            <= i_flags_ff;
        o_mem_srcdest_index_ff<= i_mem_srcdest_index_ff;
        o_dav_ff              <= i_dav_ff;
        o_destination_index_ff<= i_destination_index_ff;
        o_pc_plus_8_ff        <= i_pc_plus_8_ff;
        o_irq_ff              <= i_irq_ff;
        o_fiq_ff              <= i_fiq_ff;
        o_swi_ff              <= i_swi_ff;
        o_instr_abort_ff      <= i_instr_abort_ff;
        o_mem_load_ff         <= i_mem_load_ff; 
        o_und_ff              <= i_und_ff;
        o_mem_fault           <= i_mem_fault;
end

always @ (posedge i_clk)
begin
        if ( !i_data_stall )
        begin
                i_mem_load_ff2          <= i_mem_load_ff;
                i_mem_srcdest_value_ff2 <= i_mem_srcdest_value_ff;
                i_mem_address_ff2       <= i_mem_address_ff;
                i_sbyte_ff2             <= i_sbyte_ff;
                i_ubyte_ff2             <= i_ubyte_ff;
                i_shalf_ff2             <= i_shalf_ff;
                i_uhalf_ff2             <= i_uhalf_ff;
        end
end

always @*
o_mem_rd_data         = transform((i_mem_load_ff2 ? mem_rd_data_ff : 
                        i_mem_srcdest_value_ff2), i_mem_address_ff2, 
                        i_sbyte_ff2, i_ubyte_ff2, i_shalf_ff2, i_uhalf_ff2, 
                        i_mem_load_ff2);

/*
 * Memory always loads 32-bit to processor. We will rotate that here as we wish.
 */
function [31:0] transform ( input [31:0] data, input [1:0] address, input sbyte, input ubyte, input shalf, input uhalf, input mem_load_ff );
begin: trFn
        reg [31:0] d;

        transform = 0;
        d         = data;

        if ( ubyte == 1'd1 )
        begin
                case ( address[1:0] )
                0: transform = (d >> 0)  & 32'h000000ff;
                1: transform = (d >> 8)  & 32'h000000ff;
                2: transform = (d >> 16) & 32'h000000ff;
                3: transform = (d >> 24) & 32'h000000ff;
                endcase
        end
        else if ( sbyte == 1'd1 )
        begin
                case ( address[1:0] )
                0: transform = (d >> 0)  & 32'h000000ff; 
                1: transform = (d >> 8)  & 32'h000000ff;
                2: transform = (d >> 16) & 32'h000000ff;
                3: transform = (d >> 24) & 32'h000000ff;
                endcase

                transform = $signed(transform[7:0]);
        end
        else if ( shalf == 1'd1 )
        begin
                case ( address[1] )
                0: transform = (d >>  0) & 32'h0000ffff;
                1: transform = (d >> 16) & 32'h0000ffff;
                endcase

                transform = $signed(transform[15:0]);
        end
        else if ( uhalf == 1'd1 )
        begin
                case ( address[1] )
                0: transform = (d >>  0) & 32'h0000ffff;
                1: transform = (d >> 16) & 32'h0000ffff;
                endcase
        end
        else
        begin
                transform = data;
        end

        if ( !mem_load_ff ) 
        begin
                transform = data; // No memory load means pass it on.
        end
end
endfunction

endmodule
