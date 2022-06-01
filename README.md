```text
                                     ZAP 
A HIGH PERFORMANCE ARM PROCESSOR (v5TE) WITH CP15 COMPATIBLE CACHE AND MMU (140MHz ON 7-SERIES FPGA)
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
size.

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

If you had used Docker previously to run a test, do a
> make clean
first.

XDC Setup
--------------
* The XDC assumes a 140MHz clock. 
* Input assume they receive data from a flop with Tcq = 3.7ns
* Outputs assume they are driving a flop with Tsu = 2ns Th=1ns.

===============================================================================
3. Timing and Resource Utilization 
   (4KB + 4KB cache , 2,32,2,2 + 2,32,2,2 TLB entries, 1K Predictor Depth)
===============================================================================

-------------------------------------------------------------------------------
3.1. Timing
-------------------------------------------------------------------------------

+-------+-------------+--------+-----------------------------------------------------------------------+
| Clock |    Fmax     | Slack  | Synthesis Command                                                     |
+-------+-------------+--------------------------------------------------------------------------------+
| i_clk |   140 MHz   |  MET   | synth_design -top zap_top -part xc7a35tftg256-3 -mode out_of_context  |
+-------+-------------+--------+----------------+------------------------------------------------------|

-------------------------------------------------------------------------------
3.2. Area
-------------------------------------------------------------------------------

Most of the area is occupied by the caches and TL buffers. For portability
across FPGAs, byte based RAMs are implemented as individual byte wide RAMs.
If your FPGA supports byte enables, you may combine the RAMs highlighted with
a prefix * with byte enables as your FPGA's width. 

The processor core uses 7800 LUTs and 4180 FFs. The rest is occupied by the
caches and TL buffers. 

+---------------------------------------------+--------------------------------------+---------------+---------------+--------------+----------+---------------+----------+----------+------------+
|                   Instance                  |                Module                |   Total LUTs  |   Logic LUTs  |    LUTRAMs   |   SRLs   |      FFs      |  RAMB36  |  RAMB18  | DSP Blocks |
+---------------------------------------------+--------------------------------------+---------------+---------------+--------------+----------+---------------+----------+----------+------------+
| zap_top                                     |                                (top) | 19564(94.06%) | 17744(85.31%) | 1818(18.94%) | 2(0.02%) | 13198(31.73%) | 4(8.00%) | 1(1.00%) |   4(4.44%) |
|   (zap_top)                                 |                                (top) |      0(0.00%) |      0(0.00%) |     0(0.00%) | 0(0.00%) |      0(0.00%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|   u_code_cache                              |                            zap_cache |  4938(23.74%) |  4076(19.60%) |   862(8.98%) | 0(0.00%) |  4235(10.18%) | 2(4.00%) | 0(0.00%) |   0(0.00%) |
|     (u_code_cache)                          |                            zap_cache |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      3(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_cache_fsm                         |                     zap_cache_fsm_66 |  2980(14.33%) |  2980(14.33%) |     0(0.00%) | 0(0.00%) |   1227(2.95%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_cache_tag_ram                     |                 zap_cache_tag_ram_67 |   1282(6.16%) |    514(2.47%) |   768(8.00%) | 0(0.00%) |   2350(5.65%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|       (u_zap_cache_tag_ram)                 |                 zap_cache_tag_ram_67 |     66(0.32%) |     66(0.32%) |     0(0.00%) | 0(0.00%) |    150(0.36%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[0].u_zap_ram_simple_data_ram  |                    zap_ram_simple_79 |     17(0.08%) |      5(0.02%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[10].u_zap_ram_simple_data_ram |                    zap_ram_simple_80 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[11].u_zap_ram_simple_data_ram |                    zap_ram_simple_81 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[12].u_zap_ram_simple_data_ram |                    zap_ram_simple_82 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[13].u_zap_ram_simple_data_ram |                    zap_ram_simple_83 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[14].u_zap_ram_simple_data_ram |                    zap_ram_simple_84 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[15].u_zap_ram_simple_data_ram |                    zap_ram_simple_85 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[16].u_zap_ram_simple_data_ram |                    zap_ram_simple_86 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[17].u_zap_ram_simple_data_ram |                    zap_ram_simple_87 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[18].u_zap_ram_simple_data_ram |                    zap_ram_simple_88 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[19].u_zap_ram_simple_data_ram |                    zap_ram_simple_89 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[1].u_zap_ram_simple_data_ram  |                    zap_ram_simple_90 |     17(0.08%) |      5(0.02%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[20].u_zap_ram_simple_data_ram |                    zap_ram_simple_91 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[21].u_zap_ram_simple_data_ram |                    zap_ram_simple_92 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[22].u_zap_ram_simple_data_ram |                    zap_ram_simple_93 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[23].u_zap_ram_simple_data_ram |                    zap_ram_simple_94 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[24].u_zap_ram_simple_data_ram |                    zap_ram_simple_95 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[25].u_zap_ram_simple_data_ram |                    zap_ram_simple_96 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[26].u_zap_ram_simple_data_ram |                    zap_ram_simple_97 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[27].u_zap_ram_simple_data_ram |                    zap_ram_simple_98 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[28].u_zap_ram_simple_data_ram |                    zap_ram_simple_99 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[29].u_zap_ram_simple_data_ram |                   zap_ram_simple_100 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[2].u_zap_ram_simple_data_ram  |                   zap_ram_simple_101 |     22(0.11%) |     10(0.05%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[30].u_zap_ram_simple_data_ram |                   zap_ram_simple_102 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[31].u_zap_ram_simple_data_ram |                   zap_ram_simple_103 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[32].u_zap_ram_simple_data_ram |                   zap_ram_simple_104 |     22(0.11%) |     10(0.05%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[33].u_zap_ram_simple_data_ram |                   zap_ram_simple_105 |     25(0.12%) |     13(0.06%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[34].u_zap_ram_simple_data_ram |                   zap_ram_simple_106 |     24(0.12%) |     12(0.06%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[35].u_zap_ram_simple_data_ram |                   zap_ram_simple_107 |     23(0.11%) |     11(0.05%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[36].u_zap_ram_simple_data_ram |                   zap_ram_simple_108 |     26(0.13%) |     14(0.07%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[37].u_zap_ram_simple_data_ram |                   zap_ram_simple_109 |     23(0.11%) |     11(0.05%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[38].u_zap_ram_simple_data_ram |                   zap_ram_simple_110 |     24(0.12%) |     12(0.06%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[39].u_zap_ram_simple_data_ram |                   zap_ram_simple_111 |     33(0.16%) |     21(0.10%) |    12(0.13%) | 0(0.00%) |     45(0.11%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[3].u_zap_ram_simple_data_ram  |                   zap_ram_simple_112 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[40].u_zap_ram_simple_data_ram |                   zap_ram_simple_113 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[41].u_zap_ram_simple_data_ram |                   zap_ram_simple_114 |     18(0.09%) |      6(0.03%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[42].u_zap_ram_simple_data_ram |                   zap_ram_simple_115 |     19(0.09%) |      7(0.03%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[43].u_zap_ram_simple_data_ram |                   zap_ram_simple_116 |     19(0.09%) |      7(0.03%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[44].u_zap_ram_simple_data_ram |                   zap_ram_simple_117 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[45].u_zap_ram_simple_data_ram |                   zap_ram_simple_118 |     19(0.09%) |      7(0.03%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[46].u_zap_ram_simple_data_ram |                   zap_ram_simple_119 |     19(0.09%) |      7(0.03%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[47].u_zap_ram_simple_data_ram |                   zap_ram_simple_120 |     19(0.09%) |      7(0.03%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[48].u_zap_ram_simple_data_ram |                   zap_ram_simple_121 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[49].u_zap_ram_simple_data_ram |                   zap_ram_simple_122 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[4].u_zap_ram_simple_data_ram  |                   zap_ram_simple_123 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[50].u_zap_ram_simple_data_ram |                   zap_ram_simple_124 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[51].u_zap_ram_simple_data_ram |                   zap_ram_simple_125 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[52].u_zap_ram_simple_data_ram |                   zap_ram_simple_126 |     29(0.14%) |     17(0.08%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[53].u_zap_ram_simple_data_ram |                   zap_ram_simple_127 |     29(0.14%) |     17(0.08%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[54].u_zap_ram_simple_data_ram |                   zap_ram_simple_128 |     29(0.14%) |     17(0.08%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[55].u_zap_ram_simple_data_ram |                   zap_ram_simple_129 |     32(0.15%) |     20(0.10%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[56].u_zap_ram_simple_data_ram |                   zap_ram_simple_130 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[57].u_zap_ram_simple_data_ram |                   zap_ram_simple_131 |     22(0.11%) |     10(0.05%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[58].u_zap_ram_simple_data_ram |                   zap_ram_simple_132 |     21(0.10%) |      9(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[59].u_zap_ram_simple_data_ram |                   zap_ram_simple_133 |     21(0.10%) |      9(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[5].u_zap_ram_simple_data_ram  |                   zap_ram_simple_134 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[60].u_zap_ram_simple_data_ram |                   zap_ram_simple_135 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[61].u_zap_ram_simple_data_ram |                   zap_ram_simple_136 |     21(0.10%) |      9(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[62].u_zap_ram_simple_data_ram |                   zap_ram_simple_137 |     21(0.10%) |      9(0.04%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[63].u_zap_ram_simple_data_ram |                   zap_ram_simple_138 |     27(0.13%) |     15(0.07%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[6].u_zap_ram_simple_data_ram  |                   zap_ram_simple_139 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[7].u_zap_ram_simple_data_ram  |                   zap_ram_simple_140 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[8].u_zap_ram_simple_data_ram  |                   zap_ram_simple_141 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[9].u_zap_ram_simple_data_ram  |                   zap_ram_simple_142 |     12(0.06%) |      0(0.00%) |    12(0.13%) | 0(0.00%) |     32(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_ram_simple_tag                  |   zap_ram_simple__parameterized0_143 |     87(0.42%) |     87(0.42%) |     0(0.00%) | 0(0.00%) |    139(0.33%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_tlb                               |                           zap_tlb_68 |    674(3.24%) |    580(2.79%) |    94(0.98%) | 0(0.00%) |    655(1.57%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|       u_fpage_tlb                           | zap_mem_inv_block__parameterized2_69 |     97(0.47%) |     61(0.29%) |    36(0.38%) | 0(0.00%) |    151(0.36%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         (u_fpage_tlb)                       | zap_mem_inv_block__parameterized2_69 |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      5(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |    zap_ram_simple__parameterized4_78 |     95(0.46%) |     59(0.28%) |    36(0.38%) | 0(0.00%) |    146(0.35%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_lpage_tlb                           | zap_mem_inv_block__parameterized0_70 |     89(0.43%) |     57(0.27%) |    32(0.33%) | 0(0.00%) |    134(0.32%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         (u_lpage_tlb)                       | zap_mem_inv_block__parameterized0_70 |      3(0.01%) |      3(0.01%) |     0(0.00%) | 0(0.00%) |      4(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |    zap_ram_simple__parameterized2_77 |     86(0.41%) |     54(0.26%) |    32(0.33%) | 0(0.00%) |    130(0.31%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_section_tlb                         |                 zap_mem_inv_block_71 |     79(0.38%) |     53(0.25%) |    26(0.27%) | 0(0.00%) |     94(0.23%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         (u_section_tlb)                     |                 zap_mem_inv_block_71 |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      5(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |    zap_ram_simple__parameterized1_76 |     77(0.37%) |     51(0.25%) |    26(0.27%) | 0(0.00%) |     89(0.21%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_spage_tlb                           | zap_mem_inv_block__parameterized1_72 |     80(0.38%) |     80(0.38%) |     0(0.00%) | 0(0.00%) |    139(0.33%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|         (u_spage_tlb)                       | zap_mem_inv_block__parameterized1_72 |     13(0.06%) |     13(0.06%) |     0(0.00%) | 0(0.00%) |     39(0.09%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |    zap_ram_simple__parameterized3_75 |     67(0.32%) |     67(0.32%) |     0(0.00%) | 0(0.00%) |    100(0.24%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_tlb_check                       |                     zap_tlb_check_73 |     11(0.05%) |     11(0.05%) |     0(0.00%) | 0(0.00%) |     35(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_tlb_fsm                         |                       zap_tlb_fsm_74 |    318(1.53%) |    318(1.53%) |     0(0.00%) | 0(0.00%) |    102(0.25%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|   u_data_cache                              |                          zap_cache_0 |  6537(31.43%) |  5675(27.28%) |   862(8.98%) | 0(0.00%) |  4425(10.64%) | 2(4.00%) | 0(0.00%) |   0(0.00%) |
|     (u_data_cache)                          |                          zap_cache_0 |      1(0.01%) |      1(0.01%) |     0(0.00%) | 0(0.00%) |      3(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_cache_fsm                         |                        zap_cache_fsm |  3598(17.30%) |  3598(17.30%) |     0(0.00%) | 0(0.00%) |   1247(3.00%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_cache_tag_ram                     |                    zap_cache_tag_ram |  2204(10.60%) |   1436(6.90%) |   768(8.00%) | 0(0.00%) |   2480(5.96%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|       (u_zap_cache_tag_ram)                 |                    zap_cache_tag_ram |    179(0.86%) |    179(0.86%) |     0(0.00%) | 0(0.00%) |    217(0.52%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[0].u_zap_ram_simple_data_ram  |                       zap_ram_simple |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[10].u_zap_ram_simple_data_ram |                     zap_ram_simple_3 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[11].u_zap_ram_simple_data_ram |                     zap_ram_simple_4 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[12].u_zap_ram_simple_data_ram |                     zap_ram_simple_5 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[13].u_zap_ram_simple_data_ram |                     zap_ram_simple_6 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[14].u_zap_ram_simple_data_ram |                     zap_ram_simple_7 |     26(0.13%) |     14(0.07%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[15].u_zap_ram_simple_data_ram |                     zap_ram_simple_8 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[16].u_zap_ram_simple_data_ram |                     zap_ram_simple_9 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[17].u_zap_ram_simple_data_ram |                    zap_ram_simple_10 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[18].u_zap_ram_simple_data_ram |                    zap_ram_simple_11 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[19].u_zap_ram_simple_data_ram |                    zap_ram_simple_12 |     26(0.13%) |     14(0.07%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[1].u_zap_ram_simple_data_ram  |                    zap_ram_simple_13 |    175(0.84%) |    163(0.78%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[20].u_zap_ram_simple_data_ram |                    zap_ram_simple_14 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[21].u_zap_ram_simple_data_ram |                    zap_ram_simple_15 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[22].u_zap_ram_simple_data_ram |                    zap_ram_simple_16 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[23].u_zap_ram_simple_data_ram |                    zap_ram_simple_17 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[24].u_zap_ram_simple_data_ram |                    zap_ram_simple_18 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[25].u_zap_ram_simple_data_ram |                    zap_ram_simple_19 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[26].u_zap_ram_simple_data_ram |                    zap_ram_simple_20 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[27].u_zap_ram_simple_data_ram |                    zap_ram_simple_21 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[28].u_zap_ram_simple_data_ram |                    zap_ram_simple_22 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[29].u_zap_ram_simple_data_ram |                    zap_ram_simple_23 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[2].u_zap_ram_simple_data_ram  |                    zap_ram_simple_24 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[30].u_zap_ram_simple_data_ram |                    zap_ram_simple_25 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[31].u_zap_ram_simple_data_ram |                    zap_ram_simple_26 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[32].u_zap_ram_simple_data_ram |                    zap_ram_simple_27 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[33].u_zap_ram_simple_data_ram |                    zap_ram_simple_28 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[34].u_zap_ram_simple_data_ram |                    zap_ram_simple_29 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[35].u_zap_ram_simple_data_ram |                    zap_ram_simple_30 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[36].u_zap_ram_simple_data_ram |                    zap_ram_simple_31 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[37].u_zap_ram_simple_data_ram |                    zap_ram_simple_32 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[38].u_zap_ram_simple_data_ram |                    zap_ram_simple_33 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[39].u_zap_ram_simple_data_ram |                    zap_ram_simple_34 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[3].u_zap_ram_simple_data_ram  |                    zap_ram_simple_35 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[40].u_zap_ram_simple_data_ram |                    zap_ram_simple_36 |     26(0.13%) |     14(0.07%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[41].u_zap_ram_simple_data_ram |                    zap_ram_simple_37 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[42].u_zap_ram_simple_data_ram |                    zap_ram_simple_38 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[43].u_zap_ram_simple_data_ram |                    zap_ram_simple_39 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[44].u_zap_ram_simple_data_ram |                    zap_ram_simple_40 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[45].u_zap_ram_simple_data_ram |                    zap_ram_simple_41 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[46].u_zap_ram_simple_data_ram |                    zap_ram_simple_42 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[47].u_zap_ram_simple_data_ram |                    zap_ram_simple_43 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[48].u_zap_ram_simple_data_ram |                    zap_ram_simple_44 |     52(0.25%) |     40(0.19%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[49].u_zap_ram_simple_data_ram |                    zap_ram_simple_45 |     52(0.25%) |     40(0.19%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[4].u_zap_ram_simple_data_ram  |                    zap_ram_simple_46 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[50].u_zap_ram_simple_data_ram |                    zap_ram_simple_47 |     52(0.25%) |     40(0.19%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[51].u_zap_ram_simple_data_ram |                    zap_ram_simple_48 |     50(0.24%) |     38(0.18%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[52].u_zap_ram_simple_data_ram |                    zap_ram_simple_49 |     44(0.21%) |     32(0.15%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[53].u_zap_ram_simple_data_ram |                    zap_ram_simple_50 |     50(0.24%) |     38(0.18%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[54].u_zap_ram_simple_data_ram |                    zap_ram_simple_51 |     44(0.21%) |     32(0.15%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[55].u_zap_ram_simple_data_ram |                    zap_ram_simple_52 |     59(0.28%) |     47(0.23%) |    12(0.13%) | 0(0.00%) |     45(0.11%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[56].u_zap_ram_simple_data_ram |                    zap_ram_simple_53 |     36(0.17%) |     24(0.12%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[57].u_zap_ram_simple_data_ram |                    zap_ram_simple_54 |     36(0.17%) |     24(0.12%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[58].u_zap_ram_simple_data_ram |                    zap_ram_simple_55 |     36(0.17%) |     24(0.12%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[59].u_zap_ram_simple_data_ram |                    zap_ram_simple_56 |     37(0.18%) |     25(0.12%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[5].u_zap_ram_simple_data_ram  |                    zap_ram_simple_57 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[60].u_zap_ram_simple_data_ram |                    zap_ram_simple_58 |     44(0.21%) |     32(0.15%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[61].u_zap_ram_simple_data_ram |                    zap_ram_simple_59 |     44(0.21%) |     32(0.15%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[62].u_zap_ram_simple_data_ram |                    zap_ram_simple_60 |     44(0.21%) |     32(0.15%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[63].u_zap_ram_simple_data_ram |                    zap_ram_simple_61 |     43(0.21%) |     31(0.15%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[6].u_zap_ram_simple_data_ram  |                    zap_ram_simple_62 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[7].u_zap_ram_simple_data_ram  |                    zap_ram_simple_63 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[8].u_zap_ram_simple_data_ram  |                    zap_ram_simple_64 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|*      genblk1[9].u_zap_ram_simple_data_ram  |                    zap_ram_simple_65 |     20(0.10%) |      8(0.04%) |    12(0.13%) | 0(0.00%) |     33(0.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_ram_simple_tag                  |       zap_ram_simple__parameterized0 |    169(0.81%) |    169(0.81%) |     0(0.00%) | 0(0.00%) |    139(0.33%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_tlb                               |                              zap_tlb |    734(3.53%) |    640(3.08%) |    94(0.98%) | 0(0.00%) |    695(1.67%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|       u_fpage_tlb                           |    zap_mem_inv_block__parameterized2 |     91(0.44%) |     55(0.26%) |    36(0.38%) | 0(0.00%) |    151(0.36%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         (u_fpage_tlb)                       |    zap_mem_inv_block__parameterized2 |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      5(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |       zap_ram_simple__parameterized4 |     89(0.43%) |     53(0.25%) |    36(0.38%) | 0(0.00%) |    146(0.35%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_lpage_tlb                           |    zap_mem_inv_block__parameterized0 |     85(0.41%) |     53(0.25%) |    32(0.33%) | 0(0.00%) |    137(0.33%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         (u_lpage_tlb)                       |    zap_mem_inv_block__parameterized0 |      3(0.01%) |      3(0.01%) |     0(0.00%) | 0(0.00%) |      4(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |       zap_ram_simple__parameterized2 |     82(0.39%) |     50(0.24%) |    32(0.33%) | 0(0.00%) |    133(0.32%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_section_tlb                         |                    zap_mem_inv_block |     80(0.38%) |     54(0.26%) |    26(0.27%) | 0(0.00%) |     97(0.23%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         (u_section_tlb)                     |                    zap_mem_inv_block |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      5(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |       zap_ram_simple__parameterized1 |     78(0.38%) |     52(0.25%) |    26(0.27%) | 0(0.00%) |     92(0.22%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_spage_tlb                           |    zap_mem_inv_block__parameterized1 |     68(0.33%) |     68(0.33%) |     0(0.00%) | 0(0.00%) |    141(0.34%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|         (u_spage_tlb)                       |    zap_mem_inv_block__parameterized1 |     12(0.06%) |     12(0.06%) |     0(0.00%) | 0(0.00%) |     39(0.09%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|         u_ram_simple                        |       zap_ram_simple__parameterized3 |     56(0.27%) |     56(0.27%) |     0(0.00%) | 0(0.00%) |    102(0.25%) | 1(2.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_tlb_check                       |                        zap_tlb_check |     43(0.21%) |     43(0.21%) |     0(0.00%) | 0(0.00%) |     61(0.15%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_tlb_fsm                         |                          zap_tlb_fsm |    367(1.76%) |    367(1.76%) |     0(0.00%) | 0(0.00%) |    108(0.26%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|   u_sync                                    |           zap_dual_rank_synchronizer |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      6(0.01%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|   u_zap_core                                |                             zap_core |  7810(37.55%) |  7762(37.32%) |    46(0.48%) | 2(0.02%) |  4180(10.05%) | 0(0.00%) | 1(1.00%) |   4(4.44%) |
|     (u_zap_core)                            |                             zap_core |     32(0.15%) |     32(0.15%) |     0(0.00%) | 0(0.00%) |      0(0.00%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     U_ZAP_FIFO                              |                             zap_fifo |    296(1.42%) |    250(1.20%) |    46(0.48%) | 0(0.00%) |    212(0.51%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       (U_ZAP_FIFO)                          |                             zap_fifo |    204(0.98%) |    204(0.98%) |     0(0.00%) | 0(0.00%) |     68(0.16%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       USF                                   |                        zap_sync_fifo |     92(0.44%) |     46(0.22%) |    46(0.48%) | 0(0.00%) |    144(0.35%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_alu_main                          |                         zap_alu_main |    143(0.69%) |    143(0.69%) |     0(0.00%) | 0(0.00%) |    191(0.46%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_cp15_cb                           |                          zap_cp15_cb |    279(1.34%) |    279(1.34%) |     0(0.00%) | 0(0.00%) |    511(1.23%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_decode_main                       |                      zap_decode_main |    860(4.13%) |    860(4.13%) |     0(0.00%) | 0(0.00%) |    153(0.37%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_fetch_main                        |                       zap_fetch_main |      4(0.02%) |      4(0.02%) |     0(0.00%) | 0(0.00%) |     69(0.17%) | 0(0.00%) | 1(1.00%) |   0(0.00%) |
|       (u_zap_fetch_main)                    |                       zap_fetch_main |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |     66(0.16%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_br_ram                              |                zap_ram_simple_nopipe |      2(0.01%) |      2(0.01%) |     0(0.00%) | 0(0.00%) |      3(0.01%) | 0(0.00%) | 1(1.00%) |   0(0.00%) |
|     u_zap_issue_main                        |                       zap_issue_main |    793(3.81%) |    793(3.81%) |     0(0.00%) | 0(0.00%) |    266(0.64%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_memory_main                       |                      zap_memory_main |   1733(8.33%) |   1733(8.33%) |     0(0.00%) | 0(0.00%) |    195(0.47%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_postalu0_main                     |                     zap_postalu_main |      3(0.01%) |      3(0.01%) |     0(0.00%) | 0(0.00%) |    188(0.45%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_postalu1_main                     |                   zap_postalu_main_1 |     19(0.09%) |     19(0.09%) |     0(0.00%) | 0(0.00%) |    188(0.45%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_postalu_main                      |                   zap_postalu_main_2 |    154(0.74%) |    152(0.73%) |     0(0.00%) | 2(0.02%) |    187(0.45%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_predecode                         |                   zap_predecode_main |    879(4.23%) |    879(4.23%) |     0(0.00%) | 0(0.00%) |    176(0.42%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       (u_zap_predecode)                     |                   zap_predecode_main |    662(3.18%) |    662(3.18%) |     0(0.00%) | 0(0.00%) |    106(0.25%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_decode_coproc                   |                 zap_predecode_coproc |     42(0.20%) |     42(0.20%) |     0(0.00%) | 0(0.00%) |     31(0.07%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_uop_sequencer                   |          zap_predecode_uop_sequencer |    175(0.84%) |    175(0.84%) |     0(0.00%) | 0(0.00%) |     39(0.09%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_shifter_main                      |                     zap_shifter_main |    840(4.04%) |    840(4.04%) |     0(0.00%) | 0(0.00%) |    268(0.64%) | 0(0.00%) | 0(0.00%) |   4(4.44%) |
|       (u_zap_shifter_main)                  |                     zap_shifter_main |    552(2.65%) |    552(2.65%) |     0(0.00%) | 0(0.00%) |    201(0.48%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_multiply                        |                 zap_shifter_multiply |    288(1.38%) |    288(1.38%) |     0(0.00%) | 0(0.00%) |     67(0.16%) | 0(0.00%) | 0(0.00%) |   4(4.44%) |
|     u_zap_thumb_decoder                     |               zap_thumb_decoder_main |    214(1.03%) |    214(1.03%) |     0(0.00%) | 0(0.00%) |     73(0.18%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     u_zap_writeback                         |                        zap_writeback |   1561(7.50%) |   1561(7.50%) |     0(0.00%) | 0(0.00%) |   1503(3.61%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       (u_zap_writeback)                     |                        zap_writeback |    153(0.74%) |    153(0.74%) |     0(0.00%) | 0(0.00%) |    223(0.54%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|       u_zap_register_file                   |                    zap_register_file |   1408(6.77%) |   1408(6.77%) |     0(0.00%) | 0(0.00%) |   1280(3.08%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|   u_zap_wb_adapter                          |                       zap_wb_adapter |    239(1.15%) |    191(0.92%) |    48(0.50%) | 0(0.00%) |    279(0.67%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     (u_zap_wb_adapter)                      |                       zap_wb_adapter |     67(0.32%) |     67(0.32%) |     0(0.00%) | 0(0.00%) |    130(0.31%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|     U_STORE_FIFO                            |        zap_sync_fifo__parameterized0 |    172(0.83%) |    124(0.60%) |    48(0.50%) | 0(0.00%) |    149(0.36%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
|   u_zap_wb_merger                           |                        zap_wb_merger |     38(0.18%) |     38(0.18%) |     0(0.00%) | 0(0.00%) |     73(0.18%) | 0(0.00%) | 0(0.00%) |   0(0.00%) |
+---------------------------------------------+--------------------------------------+---------------+---------------+--------------+----------+---------------+----------+----------+------------+

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
