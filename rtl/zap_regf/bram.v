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

/*
 * Will synthesize to a 2 write port, 1 read port block RAM.
 */

`default_nettype none
`include "config.vh"

module block_ram #(
        parameter       DATA_WDT        =       32,
        parameter       ADDR_WDT        =       6,
        parameter       DEPTH           =       64
)
(
        input wire                      i_clk_2x,

        input wire      [ADDR_WDT-1:0]  i_addr_a,
        input wire      [ADDR_WDT-1:0]  i_addr_b,

        input wire                      i_wen,

        input wire      [DATA_WDT-1:0]  i_wr_data_a,
        input wire      [DATA_WDT-1:0]  i_wr_data_b,

        output reg      [DATA_WDT-1:0]  o_rd_data_a
);

reg [DATA_WDT-1:0] mem [DEPTH-1:0];

`ifdef SIM
        wire [31:0] r0;  assign r0 =  mem[0]; 
        wire [31:0] r1;  assign r1 =  mem[1];
        wire [31:0] r2;  assign r2 =  mem[2];
        wire [31:0] r3;  assign r3 =  mem[3];
        wire [31:0] r4;  assign r4 =  mem[4];
        wire [31:0] r5;  assign r5 =  mem[5];
        wire [31:0] r6;  assign r6 =  mem[6];
        wire [31:0] r7;  assign r7 =  mem[7];
        wire [31:0] r8;  assign r8 =  mem[8];
        wire [31:0] r9;  assign r9 =  mem[9];
        wire [31:0] r10; assign r10 = mem[10];
        wire [31:0] r11; assign r11 = mem[11];
        wire [31:0] r12; assign r12 = mem[12];
        wire [31:0] r13; assign r13 = mem[13];
        wire [31:0] r14; assign r14 = mem[14];
        wire [31:0] r15; assign r15 = mem[15];
        wire [31:0] r16; assign r16 = mem[16];
        wire [31:0] r17; assign r17 = mem[17];
        wire [31:0] r18; assign r18 = mem[18];
        wire [31:0] r19; assign r19 = mem[19];
        wire [31:0] r20; assign r20 = mem[20];
        wire [31:0] r21; assign r21 = mem[21];
        wire [31:0] r22; assign r22 = mem[22];
        wire [31:0] r23; assign r23 = mem[23];
        wire [31:0] r24; assign r24 = mem[24];
        wire [31:0] r25; assign r25 = mem[25];
        wire [31:0] r26; assign r26 = mem[26];
        wire [31:0] r27; assign r27 = mem[27];
        wire [31:0] r28; assign r28 = mem[28];
        wire [31:0] r29; assign r29 = mem[29];
        wire [31:0] r30; assign r30 = mem[30];
        wire [31:0] r31; assign r31 = mem[31];
        wire [31:0] r32; assign r32 = mem[32];
        wire [31:0] r33; assign r33 = mem[33];
        wire [31:0] r34; assign r34 = mem[34];
        wire [31:0] r35; assign r35 = mem[35];
        wire [31:0] r36; assign r36 = mem[36];
        wire [31:0] r37; assign r37 = mem[37];
        wire [31:0] r38; assign r38 = mem[38];
        wire [31:0] r39; assign r39 = mem[39];
        wire [31:0] r40; assign r40 = mem[40];
        wire [31:0] r41; assign r41 = mem[41];
        wire [31:0] r42; assign r42 = mem[42];
        wire [31:0] r43; assign r43 = mem[43];
        wire [31:0] r44; assign r44 = mem[44];
        wire [31:0] r45; assign r45 = mem[45];
`endif

initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem[i] = 0;
end

always @ (posedge i_clk_2x)
begin
        if ( i_wen )
        begin
                mem [ i_addr_a ] <= i_wr_data_a;
                mem [ i_addr_b ] <= i_wr_data_b;        
        end
end

always @ (posedge i_clk_2x)
begin
        o_rd_data_a     <= mem [ i_addr_a ];
end

endmodule
