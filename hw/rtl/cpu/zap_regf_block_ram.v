// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_regf_block_ram.v
// HDL          : Verilog-2001
// Module       : zap_regf_block_ram       
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
//  Description --
//  Synthesizes to a 2 write port + 1 read port block RAM. Note that the 
//  read port is tied to the address of write port A. This is a limitation
//  of Xilinx block RAMs. Thus, a wrapper is needed to emulate 2 write ports
//  and an independent read port by overclocking this RAM.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high reset
// Clock        : 2 x Core clock
// Depends      : --        
// ----------------------------------------------------------------------------

`default_nettype none

module zap_regf_block_ram #(
        parameter       DATA_WDT        =       32,
        parameter       ADDR_WDT        =       6,
        parameter       DEPTH           =       40
)
(
        input wire                      i_clk_multipump,

        input wire      [ADDR_WDT-1:0]  i_addr_a,
        input wire      [ADDR_WDT-1:0]  i_addr_b,

        input wire                      i_wen,

        input wire      [DATA_WDT-1:0]  i_wr_data_a,
        input wire      [DATA_WDT-1:0]  i_wr_data_b,

        output reg      [DATA_WDT-1:0]  o_rd_data_a
);

`include "zap_defines.vh"
`include "zap_localparams.vh"
`include "zap_functions.vh"

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
`endif

initial
begin: blk1
        integer i;

        for(i=0;i<DEPTH;i=i+1)
                mem[i] = 0;
end

always @ (posedge i_clk_multipump)
begin
        if ( i_wen )
        begin
                mem [ i_addr_a ] <= i_wr_data_a;
                mem [ i_addr_b ] <= i_wr_data_b;        
        end
end

always @ (posedge i_clk_multipump)
begin
        o_rd_data_a     <= mem [ i_addr_a ];
end

endmodule // block_ram
