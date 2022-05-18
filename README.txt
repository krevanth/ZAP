                       THE ZAP PROCESSOR
           By Revanth Kamaraj <revanth91kamaraj@gmail.com>

ZAP is a superpipelined ARMv5TE compatible (ARM DDI 0100E, Ref [1]) processor.

Copyright (C) 2016-2022  Revanth Kamaraj (GitHub Username: krevanth) <revanth91kamaraj@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

===============================================================================
Running Simulations
===============================================================================

> make [TC=test_name] 

See src/ts for a list of test names. Not providing a testname will run all
tests.

NOTE: The project environment requires Docker.

===============================================================================
Running Lint
===============================================================================

> make lint

NOTE: The project environment requires Docker.

===============================================================================
Contributors
===============================================================================

Except where otherwise noted, the ZAP processor and its source code is 
Copyright (C) Revanth Kamaraj (GitHub Username: krevanth), that's me. 
The proper notices are in the head of each file. You can contact me at 
<revanth91kamaraj@gmail.com> and my LinkedIn URL is 
<www.linkedin.com/in/revanth-kamaraj-178662113>.

Credit to Bharat Mulagondla (GitHub Username: bharathmulagondla) for finding 
bugs in TLB logic. Credit to Erez Binyamin (GitHub Username: ErezBinyamin) 
for adding Docker support.

===============================================================================
Introduction 
===============================================================================

ZAP is a synthesizable SystemVerilog processor core that can execute ARMv5TE 
binaries. Note that ZAP is ***NOT*** an ARM clone. ZAP is a completely 
different implementation and unique superpipelined microarchitecture built from 
scratch with the aim of providing maximum performance for typical FPGA/ASIC 
targets. Cache and MMU should be enabled as soon as possible to enable good 
performance.

ZAP provides full software compatibility including architecturally exposed CPU 
modes, short instruction support, FCSE, cache, MMU, TLBs and the CP15 interface 
layer for cache and MMU control. The software compatibility allows ZAP to boot 
full operating systems like Linux. 

===============================================================================
ZAP Superpipeline
===============================================================================

┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              DUAL FORWARDING, COMMUNICATION AND SYNCHRONIZATION BUS                       │
└────┬─────────┬──────────┬───────┬────────┬──────────┬───────┬────────┬───────┬───────┬────────┬───────┬───┘
     │         │          │       │        │          │       │        │       │       │        │       │
┌────┴────┬────┴───┬──────┴──┬────┴───┬────┴────┬─────┴──┬────┴───┬────┴───┬───┴───┬───┴────┬───┴───┬───┴───┐
│         │        │         │        │         │        │        │        │       │        │       │       │
│ I-MMU   │        │         │        │         │        │        │ MUL/MAC│       │ MEM    │       │       │
│ FETCH 1 │ FETCH 2│  FIFO   │ DECOMP │ UOP GEN │ DECODE │ ISSUE 1│ ISSUE 2│ ALU   │ DCACHE │ WRBACK│ REGF  │     
│ I-CACHE │        │         │        │         │        │ REG RD │ REG RD │       │ D-MMU  │       │       │
│         │        │         │        │         │        │        │ SHIFTER│       │        │       │       │
└─────┬───┴────────┴─────────┴────────┴─────────┴────────┴────────┴────────┴───────┴────┬───┴───────┴───────┘
      │                                                                                 │
      │                                                                                 │
 ┌────┴─────────────────────────────────────────────────────────────────────────────────┴──────────────────┐
 │                                               WISHBONE ADAPTER                                          │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

===============================================================================
Coprocessor 15 CSRs
===============================================================================

Please refer to the ARM DDI 0100E specification for CP15 CSR requirements. 

 * Register 1: Cache and MMU control.
 * Register 2: Translation Base.
 * Register 3: Domain Access Control.
 * Register 5: FSR.
 * Register 6: FAR.
 * Register 8: TLB functions.
 * Register 7: Cache functions.
   * The arch spec allows for a subset of the functions to be implemented for 
     register 7. 
   * These are supported (Read as {opcode2, crm}) in ZAP for register 7:
     * CASE_FLUSH_ID_CACHE               = 7'b000_0111
     * CASE_FLUSH_I_CACHE                = 7'b000_0101
     * CASE_FLUSH_D_CACHE                = 7'b000_0110
     * CASE_CLEAN_ID_CACHE               = 7'b000_1011
     * CASE_CLEAN_D_CACHE                = 7'b000_1010
     * CASE_CLEAN_AND_FLUSH_ID_CACHE     = 7'b000_1111
     * CASE_CLEAN_AND_FLUSH_D_CACHE      = 7'b000_1110
 * Register 13: FCSE Register.

===============================================================================
Usage
===============================================================================

 * To use the ZAP processor in your project:
   * Add all the *.sv files in src/rtl/ to your project.
   * Add src/rtl/ to your tool's search path to allow it to pick up SV headers.
   * Instantiate the ZAP processor in your project using this template:

        zap_top #(.FIFO_DEPTH              (),
                  .BP_ENTRIES              (),
                  .STORE_BUFFER_DEPTH      (),
                  .DATA_SECTION_TLB_ENTRIES(),
                  .DATA_LPAGE_TLB_ENTRIES  (),
                  .DATA_SPAGE_TLB_ENTRIES  (),
                  .DATA_FPAGE_TLB_ENTRIES  (),
                  .DATA_CACHE_SIZE         (),
                  .CODE_SECTION_TLB_ENTRIES(),
                  .CODE_LPAGE_TLB_ENTRIES  (),
                  .CODE_SPAGE_TLB_ENTRIES  (),
                  .CODE_FPAGE_TLB_ENTRIES  (),
                  .CODE_CACHE_SIZE         ()) u_zap_top (
                  .i_clk                   (),
                  .i_reset                 (),
                  .i_irq                   (),
                  .i_fiq                   (), 
                  .o_wb_cyc                (),
                  .o_wb_stb                (),
                  .o_wb_adr                (),
                  .o_wb_we                 (,
                  .o_wb_cti                (),
                  .i_wb_dat                (),
                  .o_wb_dat                (t),
                  .i_wb_ack                (),
                  .o_wb_sel                (),
                  .o_wb_bte                ()             
        );

    
   * The processor provides a Wishbone B3 bus. It is recommended that you use 
     it in registered feedback cycle mode.
   * Interrupts are level sensitive and are internally synced to clock.

CPU Top Level Configuration:

Note that all parameters should be 2^n. Cache size should be multiple of line
size.

+--------------------------+--------+-------------------------------------+
| Parameter                | Default| Description                         |
+--------------------------+--------+-------------------------------------+
| BP_ENTRIES               |  1024  | Predictor RAM depth.                |
| FIFO_DEPTH               |  4     | Command FIFO depth.                 |
| STORE_BUFFER_DEPTH       |  16    | Depth of the store buffer.          |
| DATA_SECTION_TLB_ENTRIES |  4     | Section TLB entries.                |
| DATA_LPAGE_TLB_ENTRIES   |  8     | Large page TLB entries.             |
| DATA_SPAGE_TLB_ENTRIES   |  16    | Small page TLB entries.             |
| DATA_FPAGE_TLB_ENTRIES   |  32    | Tiny page TLB entries.              |
| DATA_CACHE_SIZE          |  4096  | Cache size in bytes.                |
| CODE_SECTION_TLB_ENTRIES |  4     | Section TLB entries.                |
| CODE_LPAGE_TLB_ENTRIES   |  8     | Large page TLB entries.             |
| CODE_SPAGE_TLB_ENTRIES   |  16    | Small page TLB entries.             |
| CODE_FPAGE_TLB_ENTRIES   |  32    | Tiny page TLB entries.              |
| CODE_CACHE_SIZE          |  4096  | Cache size in bytes.                |
| DATA_CACHE_LINE          |  64    | Cache Line for Data (B). Keep > 4   |
| CODE_CACHE_LINE          |  64    | Cache Line for Code (B). Keep > 4   |
+--------------------------+--------+-------------------------------------+

CPU Top Level IO Interface 

+----------+-----------------------------------------------------------------+ 
| Port     | Description                                                     | 
|----------|-----------------------------------------------------------------|
|i_clk     |  Clock. All logic is clocked on the rising edge of this signal. | 
|i_reset   |  Active high global reset signal. Assert for >= 1 clock cycle.  | 
|i_irq     |  Interrupt. Level Sensitive. Signal is internally synced.       |  
|i_fiq     |  Fast Interrupt. Level Sensitive. Signal is internally synced.  | 
|o_wb_cyc  |  Wishbone CYC signal.                                           | 
|o_wb_stb  |  WIshbone STB signal.                                           | 
|o_wb_adr  |  Wishbone address signal. (32)                                  | 
|o_wb_we   |  Wishbone write enable signal.                                  | 
|o_wb_dat  |  Wishbone data output signal. (32)                              | 
|o_wb_sel  |  Wishbone byte select signal. (4)                               | 
|o_wb_cti  |  Wishbone CTI (Classic, Incrementing Burst, EOB) (3)            | 
|o_wb_bte  |  Wishbone BTE (Linear) (2)                                      | 
|i_wb_ack  |  Wishbone ack signal. Wishbone registered cycles recommended.   | 
|i_wb_dat  |  Wishbone data input signal. (32)                               | 
+----------+-----------------------------------------------------------------+

===============================================================================
Running Provded Tests
===============================================================================

See Section 0 of this document.

 * See the src/ts directory for some basic tests pre-installed. 
 * Please note that these will be run on the sample TB SOC platform.
   * See src/testbench/testbench.v for more information.
 * Tests will produce wave files in the obj/src/ts/<test_name>/zap.vcd.
 * Each time a test is run, a lint is performed on the SV RTL code using Verilator.
 * Verilator is used to compile the project. 
 * Each TC has a Config.cfg. This is a Perl hash that must be edited to meet 
   requirements. Note that the registers in the REG_CHECK are indexed 
   registers. To find those, please do:

   > cat src/rtl/zap_localparams.svh | grep PHY

   For example, if a check requires a certain value of R13 in IRQ mode, the hash 
   will mention the register number as r25.
 * Here is a sample Config.cfg:
        %Config = ( 
                # CPU configuration.
                DATA_CACHE_SIZE             => 4096,    
                CODE_CACHE_SIZE             => 4096,    
                CODE_SECTION_TLB_ENTRIES    => 8,       
                CODE_SPAGE_TLB_ENTRIES      => 32,      
                CODE_LPAGE_TLB_ENTRIES      => 16,      
                DATA_SECTION_TLB_ENTRIES    => 8,       
                DATA_SPAGE_TLB_ENTRIES      => 32,      
                DATA_LPAGE_TLB_ENTRIES      => 16,      
                BP_DEPTH                    => 1024,    
                INSTR_FIFO_DEPTH            => 4,       
                STORE_BUFFER_DEPTH          => 8,      

                # Debug helpers. 
                DEBUG_EN                    => 1,       
                                               # Enables debug print messages. 
                                               # Set DEBUG_EN=0 for synthesis.        

                # Testbench configuration.
                MAX_CLOCK_CYCLES            => 100000,  
                                               # Clock cycles to run the 
                                               # simulation for.
        
                REG_CHECK                   => {"r1" => "32'h4", 
                                                "r2" => "32'd3"},      
                                               # Make this an anonymous has with 
                                               # entries like "r10" => "32'h0". 
        
                FINAL_CHECK                 => {"32'h100" => "32'd4", 
                                                "32'h66" => "32'h4"}   
                                               # Make this an anonymous hash with 
                                               # entries like 
                                               # verilog_address => verilog_value.

===============================================================================
Timing and Resource Utilization 
===============================================================================

Synthesis has been run with Vivado 2021.2 (64-Bit).
Design uses default parameters with -mode out_of_context for synthesis.
Resources refer to 7 series FPGA.

+----------+------+---------------------+
| Ref Name | Used | Functional Category |
+----------+------+---------------------+
| LUT6     | 7985 |                 LUT |
| LUT5     | 3858 |                 LUT |
| LUT4     | 1951 |                 LUT |
| LUT3     | 1537 |                 LUT |
| RAMD64E  | 1536 |  Distributed Memory |
| MUXF7    |  904 |               MuxFx |
| LUT2     |  591 |                 LUT |
| RAMD32   |  516 |  Distributed Memory |
| MUXF8    |  264 |               MuxFx |
| RAMS32   |  170 |  Distributed Memory |
| CARRY4   |  158 |          CarryLogic |
| LUT1     |  104 |                 LUT |
| FDRE     | 9223 |       Flop with CLR |
| FDSE     |   26 |       Flop with SET |
| DSP48E1  |    4 |    Block Arithmetic |
| RAMB36E1 |    2 |        Block Memory |
| RAMB18E1 |    1 |        Block Memory |
+----------+------+---------------------+

+-------+-------------+-----------------+
| Clock |    Fmax     |     Part        |
+-------+-------------+-----------------+
| i_clk |   103MHz    | 7a35t-ftg256-2L |
+-------+-------------+-----------------+

===============================================================================
References
===============================================================================

[1] ARM Architecture Specification (ARM DDI 0100E)

