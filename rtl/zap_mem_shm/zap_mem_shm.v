/*
MIT License

Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

`default_nettype none

module zap_mem_shm(

input   wire            i_clk,
input   wire            i_reset,

// From CPU.
input   wire    [31:0]  i_cpu_address,
input   wire    [31:0]  i_cpu_data,
input   wire            i_cpu_ren,
input   wire            i_cpu_wen,
output  reg     [31:0]  o_cpu_data,
output  reg             o_cpu_stall,                
input   wire            i_cpu_flush,
input   wire    [3:0]   i_cpu_ben,

// To RAM (registered outputs.)
output  reg     [31:0]  o_ram_addr,
output  reg             o_ram_rd_en,
output  reg             o_ram_wr_en,
output  reg     [3:0]   o_ram_ben,
output  reg     [31:0]  o_ram_data,
input   wire    [31:0]  i_ram_data,
input   wire            i_ram_stall

);

localparam IDLE = 1'b0;
localparam BUSY = 1'b1;

reg state;

always @ (posedge i_clk)
begin
        o_ram_addr  <= i_cpu_address;
        o_ram_rd_en <= i_cpu_ren;
        o_ram_wr_en <= i_cpu_wen;
        o_ram_data  <= i_cpu_data;
        o_ram_ben   <= i_cpu_ben;

        if ( i_reset | i_cpu_flush )
        begin
                state           <= IDLE;
                o_ram_rd_en     <= 1'd0;
                o_ram_wr_en     <= 1'd0;
        end
        else
        begin
                case ( state )
                IDLE:   if ( i_cpu_ren | i_cpu_wen )       state <= BUSY;
                BUSY:   if ( !i_ram_stall )                state <= IDLE;
                endcase
        end
end

always @* o_cpu_data = i_ram_data;

always @*
begin
        case ( state )
                IDLE    : o_cpu_stall = i_cpu_ren | i_cpu_wen;
                BUSY    : o_cpu_stall = i_ram_stall;
        endcase
end

endmodule
