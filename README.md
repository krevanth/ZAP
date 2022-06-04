```text

                           ██████████████████  
                              █████   ███   ██ 
                             ███ ████████████  
                            ███  ██   ███      
                           ████████   ███
                            
              A v5TE ARM PROCESSOR WITH CACHES, MMUs AND TLBs
                  (152 MHz @ XC7A35T256-3 Artix-7 FPGA)

                     https://github.com/krevanth/ZAP
                By Revanth Kamaraj <revanth91kamaraj@gmail.com>
                      
Please reach me at :
EMail Address    : revanth91kamaraj@gmail.com
GitHub Profile   : https://github.com/krevanth 
LinkedIn Profile : https://linkedin.com/in/revanth-kamaraj-178662113

===============================================================================
1. About The ZAP Processor
===============================================================================

The ZAP processor is a scalar 17-stage high performance synthesizable 32-bit 
soft processor core that is fully compatible with the older ARMv5TE ISA 
(reference [1]). The processor also features an architecturally compliant 
(CP15 controllable) cache and MMU.

ZAP provides full software compatibility including architecturally exposed CPU 
modes, short instruction support, FCSE, cache, MMU, TLBs and the CP15 interface 
layer for cache and MMU control. The software compatibility allows ZAP to boot 
full operating systems like Linux. All caches and TL buffers are direct mapped. 

The ZAP implements the ARMv5TE ISA and hence supports the two standard 
instruction sets:
 * The 32-bit ARM instruction set.
 * The 16-bit Thumb instruction set.

-------------------------------------------------------------------------------
1.1. ZAP Superpipelined Microarchitecture (17 Stage)
-------------------------------------------------------------------------------

ZAP uses a 17 stage execution pipeline to increase the speed of the flow of 
instructions to the processor. The 17 stage pipeline consists of Address 
Generator, TLB Check, Cache Access, Memory, Fetch, Instruction Buffer, 
Thumb Decoder, Pre-Decoder, Decoder, Issue, Shift, Execute, TLB Check, 
Cache Access, Memory and Writeback.

> To maintain compatibility with the ARMv5TE standard, reading the program 
counter (PC) will return PC + 8 when read.

During normal operation:

* One instruction is writing out one or two results to the register bank.
  * In case of LDR/STR with writeback, two results are being written to the
    register bank in a single cycle. 
  * All other instructions write out one result to the register bank per cycle.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is performing arithmetic, logic or memory address 
  generation operations. This stage also confirms or rejects the branch 
  predictor's decisions.
* The instruction before that is performing a correction, shift or multiply/MAC 
  operation.
* The instruction before that is performing a register or pipeline read.
* The instruction before that is being decoded.
* The instruction before that is being sequenced to micro-ops (possibly). 
    * Most of the time, 1 ARM instruction = 1 micro-op.
    * The only ARM instructions requiring more than 1 micro-op generation are 
      BLX, LDM, STM, SWAP and LONG MULTIPLY (They generate a 32-bit result per 
      micro-op). 
    * All other ARM instruction decode to just a single micro-op.
    * This stage also causes branches predicted as taken to be actually 
      executed. The latency for a successfully predicted taken branch is 
      6 cycles.
* The instruction before that is being being decompressed. This is only req. 
  in the Thumb state, else the stage simply passes the instructions on. 
* The instruction before that is popped off the instruction buffer.
* The instruction before that is pushed onto the instruction buffer. Branches  
  are predicted using a bimodal predictor (if applicable).
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.

The deep pipeline, although uses more resources, allows the ZAP to run at 
high clock speeds.

-------------------------------------------------------------------------------
1.1.1. Automatic Dual Forwarding Network
-------------------------------------------------------------------------------

The ZAP pipeline has an efficient automatic dual forwarding network with 
interlock detection hardware. This is done automatically and no software 
intervention is required. This complex feedback logic guarantees that almost 
all micro-ops/instructions execute at a rate of 1 every cycle.

The only times a pipeline stalls is when (assume 100% cache hit rate):

* An instruction uses a register that is a data (not pointer) destination for a 
  load instruction within 6 cycles (assuming a load hit).
* The pipeline is executing a multiply/MAC instruction (4 cycles(short)/5 
  cycles(long)). 
  * An instruction that uses a register that is a destination for multiply/MAC 
    adds +1 to the multiply/MAC operation's latency.
* Two back to back instructions require non-zero shift and the second 
  instruction's operand overlaps with the first instruction's destination.

This snippet of ARM code takes 5 cycles to execute:
        ADD R1, R2, R2 LSL #10 (1 cycle)
        ADD R1, R1, R1 LSL #20 (2 cycles)
        ADD R3, R4, R5, LSR #3 (1 cycles)
        ADD R3, R3, R3 (1 cycles)

This snippet of ARM code takes only 4 cycles:
        ADD R1, R2, R2, R2 (1 cycle)
        ADD R1, R1, R1 LSL #2 (1 cycle)
        ADD R3, R4, R5 LSR #3 (1 cycle)
        ADD R3, R3, R3 (1 cycle)

-------------------------------------------------------------------------------
1.1.2. Two Write Port RF
-------------------------------------------------------------------------------

The ZAP can execute LDR/STR with writeback in a single cycle. This is possible
as the ZAP uses a register file with two write ports.

-------------------------------------------------------------------------------
1.1.3. Branch Predictor
-------------------------------------------------------------------------------

To improve performance, the ZAP processor uses a bimodal branch predictor. A
branch memory is maintained which stores the state of each branch. Note that
the predictor can only predict Bcc instructions. 
* Correctly predicted Bccinstructions take 7 cycles (taken)/0 cycles (not taken)
  of latency. 
* Bcc mispredicts/Data processing PC changes/BX/BLX takes 11 cycles. 
* Loading to PC from memory takes 17 cycles.
The bimodal predictor is organized as a direct mapped unit so aliasing is
possible. The predictor cannot be disabled.

-------------------------------------------------------------------------------
1.2. Bus Interface
-------------------------------------------------------------------------------

ZAP uses a Von Neumann memory model and features a common 32-bit Wishbone B3 
bus. The processor can generate byte, halfword or word accesses. The processor 
uses CTI and BTE signals to allow the bus to function more efficiently. 
Registered feedback mode is supported for higher performance. Note that 
multiprocessing is not readily supported and hence, SWAP instructions do not 
actually perform locked transfers.

The bus interface is efficient for burst transfers and hence, cache must be
enabled as soon as possible for good performance.

-------------------------------------------------------------------------------
1.3. Cache, MMU and CP15 Commands
-------------------------------------------------------------------------------

Please refer to ref [1] for CP15 CSR architectural requirements. The ZAP
implements the following software accessinble registers within its CP15
coprocessor.

NOTE: Cleaning and flushing cache and TLB is only supported for the entire
memory. Selective flushing and cleaning of cache/TLB is not available. This
is permitted as per the arch spec.

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

-------------------------------------------------------------------------------
1.4. CPU Top Level Configuration
-------------------------------------------------------------------------------

Note that all parameters should be 2^n. Cache size should be multiple of line
size. Caches/TLBs consume majority of the resources so should be tuned
as required. The default parameters give you quite large caches.

+--------------------------+--------+-----------------------------------------+
| Parameter                | Default| Description                             |
+--------------------------+--------+-----------------------------------------+
| BP_ENTRIES               |  1024  | Predictor RAM depth.                    |
| FIFO_DEPTH               |  4     | Command FIFO depth.                     |
| STORE_BUFFER_DEPTH       |  16    | Depth of the store buffer.              |
| DATA_SECTION_TLB_ENTRIES |  2     | Section TLB entries.                    |
| DATA_LPAGE_TLB_ENTRIES   |  2     | Large page TLB entries.                 |
| DATA_SPAGE_TLB_ENTRIES   |  32    | Small page TLB entries.                 |
| DATA_FPAGE_TLB_ENTRIES   |  2     | Tiny page TLB entries.                  |
| DATA_CACHE_SIZE          |  4096  | Cache size in bytes.                    |
| CODE_SECTION_TLB_ENTRIES |  2     | Section TLB entries.                    |
| CODE_LPAGE_TLB_ENTRIES   |  2     | Large page TLB entries.                 |
| CODE_SPAGE_TLB_ENTRIES   |  32    | Small page TLB entries.                 |
| CODE_FPAGE_TLB_ENTRIES   |  2     | Tiny page TLB entries.                  |
| CODE_CACHE_SIZE          |  4096  | Cache size in bytes.                    |
| DATA_CACHE_LINE          |  64    | Cache Line for Data (Byte). Keep > 8    |
| CODE_CACHE_LINE          |  64    | Cache Line for Code (Byte). Keep > 8    |
+--------------------------+--------+-----------------------------------------+

-------------------------------------------------------------------------------
1.5. CPU Top Level IO Interface 
-------------------------------------------------------------------------------

+----------+------------------------------------------------------------------+ 
| Port     | Description                                                      | 
|----------|------------------------------------------------------------------|
|i_clk     |  Clock. All logic is clocked on the rising edge of this signal.  | 
|i_reset   |  Active high global reset signal. Assert for >= 1 clock cycle.   | 
|i_irq     |  Interrupt. Level Sensitive. Signal is internally synced.        |  
|i_fiq     |  Fast Interrupt. Level Sensitive. Signal is internally synced.   | 
|o_wb_cyc  |  Wishbone CYC signal.                                            | 
|o_wb_stb  |  WIshbone STB signal.                                            | 
|o_wb_adr  |  Wishbone address signal. (32)                                   | 
|o_wb_we   |  Wishbone write enable signal.                                   | 
|o_wb_dat  |  Wishbone data output signal. (32)                               | 
|o_wb_sel  |  Wishbone byte select signal. (4)                                | 
|o_wb_cti  |  Wishbone CTI (Classic, Incrementing Burst, EOB) (3)             | 
|o_wb_bte  |  Wishbone BTE (Linear) (2)                                       | 
|i_wb_ack  |  Wishbone ack signal. Wishbone registered cycles recommended.    | 
|i_wb_dat  |  Wishbone data input signal. (32)                                | 
+----------+------------------------------------------------------------------+

 * To use the ZAP processor in your project:
   * Get the project files:
     > git clone https://github.com/krevanth/ZAP.git
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
                  .o_wb_we                 (),
                  .o_wb_cti                (),
                  .i_wb_dat                (),
                  .o_wb_dat                (),
                  .i_wb_ack                (),
                  .o_wb_sel                (),
                  .o_wb_bte                ()             
        );

    
   * The processor provides a Wishbone B3 bus. It is recommended that you use 
     it in registered feedback cycle mode.
   * Interrupts are level sensitive and are internally synced to clock.

===============================================================================
2. Project Environment
===============================================================================

The project environment requires Docker to be installed at your site. I 
(Revanth Kamaraj) would like to thank Erez Binyamin for adding Docker support
to allow the core to be used more widely.

-------------------------------------------------------------------------------
2.1. Running TCs
-------------------------------------------------------------------------------

To run all/a specific TC, do:

> make [TC=test_name] 

See src/ts for a list of test names. Not providing a testname will run all
tests.

To remove existing object/simulation/synthesis files, do:

> make clean

-------------------------------------------------------------------------------
2.2. Adding TCs
-------------------------------------------------------------------------------

 * Create a folder src/ts/TEST_NAME
 * Please note that these will be run on the sample TB SOC platform.
   * See src/testbench/testbench.v for more information.
 * Tests will produce wave files in the obj/src/ts/<test_name>/zap.vcd.
 * Add a C file (.c), an assembly file (.s) and a linker script (.ld).
 * Create a Config.cfg. This is a Perl hash that must be edited to meet 
   requirements. Note that the registers in the REG_CHECK are indexed 
   registers. To find those, please do:

   > cat src/rtl/zap_localparams.svh | grep PHY

   For example, if a check requires a certain value of R13 in IRQ mode, the
   hash will mention the register number as r25.
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
                                                "32'h104" => "32'h12345678",
                                                "32'h66" =>  "32'h4"}   
                                               # Make this an anonymous hash
                                               # with entries like 
                                               # Base address of 32-bit word => 
                                               # 32-bit verilog_value. The 
                                               # script compares 4 bytes at 
                                               # once.


-------------------------------------------------------------------------------
2.3. Running RTL Lint
-------------------------------------------------------------------------------

To run RTL lint, simply do:
> make lint

-------------------------------------------------------------------------------
2.4. Running Vivado Synthesis
-------------------------------------------------------------------------------

Synthesis scripts can be found here: src/syn/

Assuming you have Vivado installed, please do:
> make syn

Timing report will be available in obj/syn/syn_timing.rpt

If you had used Docker previously to run a test, or had run synth before, do a
> make clean
first.

-------------------------------------------------------------------------------
2.4.1. XDC Setup
-------------------------------------------------------------------------------
* The XDC assumes a 150MHz clock. 
* Input assume they receive data from a flop with Tcq = 50% of clock period.
* Outputs assume they are driving a flop with Tsu = 2ns Th=1ns.

===============================================================================
4. References
===============================================================================

[1] ARM Architecture Specification (ARM DDI 0100E)

===============================================================================
5. Mentions
===============================================================================

The ZAP project was mentioned in this paper : 
researchgate.net/publication/347558929_Free_ARM_Compatible_Softcores_on_FPGA 

Thanks to Erez Binyamin for pointing it out.

===============================================================================
6. License
===============================================================================

Copyright (C) 2016-2022  Revanth Kamaraj

This program is free software; you can redistribute it and/or modify it under 
the terms of the GNU General Public License as published by the Free Software 
Foundation; either version 2 of the License, or (at your option) any later 
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY 
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with 
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin 
Street, Fifth Floor, Boston, MA 02110-1301 USA.
```
