                         THE ZAP PROCESSOR

(C) 2016-2022 Revanth Kamaraj (krevanth)**

Please reach me at:
GMail   : revanth91kamaraj@gmail.com
LinkedIn: www.linkedin.com/in/revanth-kamaraj-178662113

COPYRIGHT (C) 2016-2022 REVANTH KAMARAJ(KREVANTH) <revanth91kamaraj@gmail.com> 

THIS PROGRAM IS FREE SOFTWARE; YOU CAN REDISTRIBUTE IT AND/OR MODIFY
IT UNDER THE TERMS OF THE GNU GENERAL PUBLIC LICENSE AS PUBLISHED BY
THE FREE SOFTWARE FOUNDATION; EITHER VERSION 2 OF THE LICENSE, OR
(AT YOUR OPTION) ANY LATER VERSION.

THIS PROGRAM IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL,
BUT WITHOUT ANY WARRANTY; WITHOUT EVEN THE IMPLIED WARRANTY OF
MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  SEE THE
GNU GENERAL PUBLIC LICENSE FOR MORE DETAILS.

YOU SHOULD HAVE RECEIVED A COPY OF THE GNU GENERAL PUBLIC LICENSE ALONG
WITH THIS PROGRAM; IF NOT, WRITE TO THE FREE SOFTWARE FOUNDATION, INC.,
51 FRANKLIN STREET, FIFTH FLOOR, BOSTON, MA 02110-1301 USA.
```

===============================================================================
0. Running Simulations
===============================================================================

make [TC=test_name] 

See src/ts for a list of test names. 

===============================================================================
1. Contributors
===============================================================================

Except where otherwise noted, the ZAP processor and its source code is 
Copyright (C) Revanth Kamaraj (krevanth). The proper notices are in the head of 
each file. 

Credit to Bharat Mulagondla (bharathmulagondla) (bharathmulagondla) for finding 
bugs in TLB logic. Credit to Erez Binyamin (ErezBinyamin) for adding Docker 
support for simulation.

===============================================================================
2. Introduction 
===============================================================================

ZAP is a synthesizable SystemVerilog processor core that can execute ARMv5TE 
binaries. Note that ZAP is ***NOT*** an ARM clone. ZAP is a completely 
different implementation and unique superpipelined microarchitecture built from 
scratch with the aim of providing maximum performance for typical FPGA/ASIC 
targets. Cache and MMU should be enabled as soon as possible to enable good 
performance.

ZAP can run binaries compiled for legacy ARM cores (ARMv5TE ISA) and provides 
full software compatibility including architecturally exposed CPU modes, short 
instruction support, FCSE, cache, MMU, TLBs and the CP15 interface layer for 
cache and MMU control. The software compatibility allows ZAP to boot full 
operating systems like Linux. 

===============================================================================
3. ZAP Superpipeline
===============================================================================

┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    DUAL FORWARDING AND SYNCHRONIZATION BUS                                │
└────┬─────────┬──────────┬───────┬────────┬──────────┬───────┬────────┬───────┬───────┬────────┬───────┬───┘
     │         │          │       │        │          │       │        │       │       │        │       │
┌────┴────┬────┴───┬──────┴──┬────┴───┬────┴────┬─────┴──┬────┴───┬────┴───┬───┴───┬───┴────┬───┴───┬───┴───┐
│         │        │         │        │         │        │        │        │       │        │       │       │
│ I-MMU   │        │         │        │         │        │        │ MUL/MAC│       │ MEM    │       │       │
│ FETCH 1 │ FETCH 2│ FIFO    │ DECOMP │ UOP GEN │ DECODE │ ISSUE 1│ ISSUE 2│ ALU   │ DCACHE │ WRBACK│ REGF  │               ┼
│ I-CACHE │        │         │        │         │        │ REG RD │ REG RD │       │ D-MMU  │       │       │
│         │        │         │        │         │        │        │ SHIFTER│       │        │       │       │
└─────┬───┴────────┴─────────┴────────┴─────────┴────────┴────────┴────────┴───────┴────┬───┴───────┴───────┘
      │                                                                                 │
      │                                                                                 │
 ┌────┴─────────────────────────────────────────────────────────────────────────────────┴──────────────────┐
 │                                               WISHBONE ADAPTER                                          │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

===============================================================================
4. Coprocessor 15 CSRs
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
5. Usage
===============================================================================

 * To use the ZAP processor in your project:
   * Add all the files *.sv in src/rtl/ to your project.
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

5.1. CPU Top Level Configuration

| Parameter                | Default| Description                                                                               |
|--------------------------|--------|-------------------------------------------------------------------------------------------|
| BP_ENTRIES               |  1024  | Branch Predictor Settings. Predictor RAM depth. Must be 2^n and > 2                       |
| FIFO_DEPTH               |  4     | Command FIFO depth. Must be 2^n and > 2                                                   |
| STORE_BUFFER_DEPTH       |  16    | Depth of the store buffer. Must be 2^n and > 2                                            |
| DATA_SECTION_TLB_ENTRIES |  4     | Data Cache/MMU Configuration. Section TLB entries. Must be 2^n (n > 0)                    |
| DATA_LPAGE_TLB_ENTRIES   |  8     | Data Cache/MMU Configuration. Large page TLB entries. Must be 2^n (n > 0)                 |
| DATA_SPAGE_TLB_ENTRIES   |  16    | Data Cache/MMU Configuration. Small page TLB entries. Must be 2^n (n > 0)                 |
| DATA_FPAGE_TLB_ENTRIES   |  32    | Data Cache/MMU Configuration. Tiny page TLB entries. Must be 2^n (n > 0)                  |
| DATA_CACHE_SIZE          |  4096  | Data Cache/MMU Configuration. Cache size in bytes. Must be at least 256B and 2^n          |
| CODE_SECTION_TLB_ENTRIES |  4     | Instruction Cache/MMU Configuration. Section TLB entries. Must be 2^n (n > 0)             |
| CODE_LPAGE_TLB_ENTRIES   |  8     | Instruction Cache/MMU Configuration. Large page TLB entries. Must be 2^n (n > 0)          |
| CODE_SPAGE_TLB_ENTRIES   |  16    | Instruction Cache/MMU Configuration. Small page TLB entries. Must be 2^n (n > 0)          |
| CODE_FPAGE_TLB_ENTRIES   |  32    | Instruction Cache/MMU Configuration. Tiny page TLB entries. Must be 2^n (n > 0)           |
| CODE_CACHE_SIZE          |  4096  | Instruction Cache/MMU Configuration. Cache size in bytes. Must be at least 256B and 2^n   |
| DATA_CACHE_LINE          |  64    | Cache Line for Data (Bytes). Keep 2^n and >= 16 Bytes                                     |
| CODE_CACHE_LINE          |  64    | Cache Line for Code (Bytes). Keep 2^n and >= 16 Bytes                                     |

5.2. CPU Top Level IO Interface 
 
| Size  | Port       | Description                                                                                   | Synchronous to       |
|-------|------------|-----------------------------------------------------------------------------------------------|----------------------|
| 1     |  i_clk     |  Clock. All logic is clocked on the rising edge of this signal.                               |  --                  |
| 1     |  i_reset   |  Active high global reset signal. Should be atleast 1 clock cycle wide. Internally synced.    |  --                  |
| 1     |  i_irq     |  Interrupt. Level Sensitive. Signal is internally synced.                                     |  --                  | 
| 1     |  i_fiq     |  Fast Interrupt. Level Sensitive. Signal is internally synced.                                |  --                  |
| 1     |  o_wb_cyc  |  Wishbone CYC signal.                                                                         | Rising edge of i_clk |
| 1     |  o_wb_stb  |  WIshbone STB signal.                                                                         | Rising edge of i_clk |
| [31:0]|  o_wb_adr  |  Wishbone address signal.                                                                     | Rising edge of i_clk |
| 1     |  o_wb_we   |  Wishbone write enable signal.                                                                | Rising edge of i_clk |
| [31:0]|  o_wb_dat  |  Wishbone data output signal.                                                                 | Rising edge of i_clk |
| [3:0] |  o_wb_sel  |  Wishbone byte select signal.                                                                 | Rising edge of i_clk |
| [2:0] |  o_wb_cti  |  Wishbone Cycle Type Indicator (Supported modes: Incrementing Burst, End of Burst)            | Rising edge of i_clk |
| [1:0] |  o_wb_bte  |  Wishbone Burst Type Indicator (Supported modes: Linear)                                      | Rising edge of i_clk |
| 1     |  i_wb_ack  |  Wishbone ack signal. Recommended to use Wishbone registered feedback cycles.                 | Rising edge of i_clk |
| [31:0]|  i_wb_dat  |  Wishbone data input signal.                                                                  | Rising edge of i_clk |

5.4. Running Provded Tests

See Section 0 of this document.

5.5. Test Environment Description

 * See the src/ts directory for some basic tests pre-installed. 
 * Please note that these will be run on the sample TB SOC platform.
   * See src/testbench/testbench.v for more information.
 * Tests will produce wave files in the obj/src/ts/<test_name>/zap.vcd.
 * Each time a test is run, a lint is performed on the SV RTL code using Verilator.
 * Verilator is used to compile the project. 
 * Each TC has a Config.cfg. This is a Perl hash that must be edited to meet 
   requirements.

5.5.1. Config.cfg format

Note that the registers in the REG_CHECK are indexed registers. To find those, 
please do:

cat src/rtl/zap_localparams.svh | grep PHY

For example, if a check requires a certain value of R13 in IRQ mode, the hash 
will mention the register number as r25.

%Config = ( 
        # CPU configuration.
        DATA_CACHE_SIZE             => 4096,    # Data cache size in bytes
        CODE_CACHE_SIZE             => 4096,    # Instruction cache size in bytes
        CODE_SECTION_TLB_ENTRIES    => 8,       # Instruction section TLB entries.
        CODE_SPAGE_TLB_ENTRIES      => 32,      # Instruction small page TLB entries.
        CODE_LPAGE_TLB_ENTRIES      => 16,      # Instruction large page TLB entries.
        DATA_SECTION_TLB_ENTRIES    => 8,       # Data section TLB entries.
        DATA_SPAGE_TLB_ENTRIES      => 32,      # Data small page TLB entries.
        DATA_LPAGE_TLB_ENTRIES      => 16,      # Data large page TLB entries.
        BP_DEPTH                    => 1024,    # Branch predictor depth.
        INSTR_FIFO_DEPTH            => 4,       # Instruction buffer depth.
        STORE_BUFFER_DEPTH          => 8,       # Store buffer depth.
        DEBUG_EN                    => 1,       # Make this to 1 to enable 
                                                # better debug. Keep 0 for 
                                                # synth.

        # Testbench configuration.
        EXT_RAM_SIZE                => 32768,   # External RAM size.
        SEED                        => -1,      # Seed. Use -1 to use random seed.
        MAX_CLOCK_CYCLES            => 100000,  # Clock cycles to run the simulation for.

        REG_CHECK                   => {"r1" => "32'h4", 
                                        "r2" => "32'd3"},      
                                       # Make this an anonymous has with 
                                       # entries like "r10" => "32'h0" etc. 
                                       # These are the internal register indices.

        FINAL_CHECK                 => {"32'h100" => "32'd4", 
                                        "32'h66" => "32'h4"}   
                                       # Make this an anonymous hash with 
                                       # entries like 
                                       # verilog_address => verilog_value.

===============================================================================
7. FPGA Timing and Device Utilization on 7a35t-ftg256-2L 
===============================================================================

Synthesis has been run with Vivado 2021.2 (64-Bit).
Design uses default parameters with -mode out_of_context for synthesis.

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

+-------+-------------+
| Clock |    Fmax     | 
+-------+-------------+
| i_clk |   103MHz    |
+-------+-------------+

===============================================================================
8. References
===============================================================================

* ARM Architecture Specification (ARM DDI 0100E)

