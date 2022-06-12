# The ZAP Processor (ARMV5TE)

**ZAP : An Open Source High Performance ARMV5TE Processor for FPGA**

**By Revanth Kamaraj <**[**revanth91kamaraj@gmail.com**](mailto:revanth91kamaraj@gmail.com)**>**



| <p><a href="https://github.com/krevanth"><img src="https://avatars.githubusercontent.com/u/16576547?v=4?s=100" alt="" data-size="original"><br><strong>Revanth Kamaraj</strong></a><br><br><strong>Lead, Processor Microarchitect, Design, Coding</strong></p> | <p><a href="https://github.com/ErezBinyamin"><img src="https://avatars.githubusercontent.com/u/22354670?v=4?s=100" alt="" data-size="line"><br><strong>Erez</strong></a><strong></strong><br><strong></strong><br><strong></strong>Contributor <br></p> | <p><a href="https://github.com/bharathmulagondla"><img src="https://avatars.githubusercontent.com/u/38918983?v=4?s=100" alt="" data-size="line"><br><strong>bharathm</strong></a><br></p><p>Contributor<br></p> | <p><a href="https://arbaranwal.github.io"><img src="https://avatars.githubusercontent.com/u/22285086?v=4?s=100" alt="" data-size="line"><br><strong>Akhil Raj Baranwal</strong></a><br></p><p>Contributor</p><p><strong></strong></p> |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |



### 1. Introduction

The ZAP is a high performance ARMV5TE compliant processor. It is intended to be used in FPGA projects that need a high performance ARMV5TE soft processor core. Most aspects of the processor can be configured through HDL parameters. The default processor specification is as follows:

| **Property**                                                                                                                                                                                                                                                                                                                                   | **Value**                                                                                                                                                           |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <p>Fmax@FPGA when synthesized with default configuration and synthesis options as:<br><code>-flatten_hierarchy full</code> <br><code>-directive PerformanceOptimized -retiming</code> <br><code>-fsm_extraction one_hot -keep_equivalent_registers -resource_sharing off</code> <br><code>-no_lc</code> <br><code>-shreg_min_size 5</code></p> | <p>Artix7   ->  140MHz@xc7a75tcsg324-3 <br></p>                                                                                                                     |
| Pipeline Depth                                                                                                                                                                                                                                                                                                                                 | 17                                                                                                                                                                  |
| Issue and Execution Width                                                                                                                                                                                                                                                                                                                      | Single issue, in order core, with out-of-order completion for some loads/stores that miss in cache.                                                                 |
| Data Width                                                                                                                                                                                                                                                                                                                                     | 32                                                                                                                                                                  |
| Address Width                                                                                                                                                                                                                                                                                                                                  | 32                                                                                                                                                                  |
| Virtual Address Width                                                                                                                                                                                                                                                                                                                          | 32                                                                                                                                                                  |
| Instruction Set                                                                                                                                                                                                                                                                                                                                | ARMV5TE                                                                                                                                                             |
| L1 I-Cache                                                                                                                                                                                                                                                                                                                                     | <p>16KB Direct Mapped Cache.<br>64 Byte Cache Line</p>                                                                                                              |
| L1 D-Cache                                                                                                                                                                                                                                                                                                                                     | <p>16KB Direct Mapped Cache<br>64 Byte Cache Line</p>                                                                                                               |
| I-TLB Structure                                                                                                                                                                                                                                                                                                                                | <p>Direct mapped. 512 entries divided into <br>- 128 entry section TLB<br>- 128 entry large page TLB<br>- 128 entry small page TLB<br>- 128 entry tiny page TLB</p> |
| D-TLB Structure                                                                                                                                                                                                                                                                                                                                | <p>Direct mapped. 512 entries divided into <br>- 128 entry section TLB<br>- 128 entry large page TLB<br>- 128 entry small page TLB<br>- 128 entry tiny page TLB</p> |
| Branch Prediction                                                                                                                                                                                                                                                                                                                              | <p>Bimodal Predictor + BTB. Direct Mapped.<br>1K entries in Thumb state. <br>512 entries in ARM state. </p>                                                         |
| RAS Depth                                                                                                                                                                                                                                                                                                                                      | 4 deep return address stack.                                                                                                                                        |
| Branch latency                                                                                                                                                                                                                                                                                                                                 | <p>12 or 18 cycles (wrong prediction)<br>3 cycles (taken, correctly predicted)<br>1 cycle    (not-taken, correctly predicted)</p>                                   |
| Store Buffer                                                                                                                                                                                                                                                                                                                                   | FIFO, 16 x 32-bit.                                                                                                                                                  |
| Fetch Buffer                                                                                                                                                                                                                                                                                                                                   | FIFO, 16 x 32-bit.                                                                                                                                                  |
| DMIPS@MHz Rating                                                                                                                                                                                                                                                                                                                               | 182DMIPS@140MHz                                                                                                                                                     |
| Bus Interface                                                                                                                                                                                                                                                                                                                                  | Unified 32-Bit Wishbone B3 bus with CTI and BTE signals.                                                                                                            |
| <p>FPGA Resource Utilization with default configuration when synthesized to 140MHz. This includes caches, TLBs and MMUs as well.<br>(Artix-7 FPGA  xc7a75tcsg324-3)</p>                                                                                                                                                                        | <p>23K LUTs<br>116 LUTRAMs<br>15.3K FFs<br>29 BRAMs<br>4 DSP Blocks</p>                                                                                             |

A simplified block diagram of the ZAP pipeline is shown below:

![Pipeline](Pipeline.drawio.svg)

ZAP includes several microarchitectural enhancements to improve instruction throughput, hide external bus and memory latency and boost performance:

* The ability to continue instruction execution even when the data cache is being filled. The data cache features hit under miss capability. The processor stalls when an instruction that depends on the cache access is decoded.
* Direct mapped instruction and data caches. These caches are virtually indexed and virtually tagged. Individual caches allow code and data to be accessed at the same time. The sizes of these caches can be set during synthesis. Cache size is parameterizable. Cache line width may be set as well.
* Direct mapped instruction and data memory TLBs. Having separate translation buffers allows data and code translation to happen in parallel. The sizes of these TLBs can be set during synthesis. Six different TLB memories are provides, each providing direct mapped buffering for sections, large page and small page, each for instruction and data (3 x 2 = 6). The sizes of these 6 memories is parameterizable.
* A parameterizable store buffer that helps buffer stores when the cache is disabled or if the data access is uncacheable. When the cache is enabled and data is cacheable, the store buffer helps buffer cache clean operations. This is slightly different from a write buffer.
* A 4-state bimodal branch predictor that predicts the outcome of immediate branches and branch-and-link instructions. ZAP employs a BTB (Branch Target Buffer) to predict branch outcomes early.&#x20;
* A 4 deep return address stack that stores the predicted return address of branch and link instructions function return. When a `BX LR`, `MOV PC,LR` or a block load with PC in register list, the processor pops off the return address. Note that switching between ARM and Thumb state has a penalty of 12 cycles.
* The ability to execute most ARM instructions in a single clock cycle. The only instructions that take multiple cycles include branch-and-link, 64-bit loads and stores, block loads and stores, swap instructions and `BLX2`.
* A highly efficient superpipeline with dual feedback networks to minimize pipeline stalls as much as possible while allowing for high clock frequencies. A deep 17 stage superpipelined architecture that allows the CPU to run at relatively high FPGA speeds.
* Support for single cycle saturating additions and subtractions for better signal processing performance. Result is available for immediate use in the next instruction itself. Do note that multiplication/MAC operations take 4 to 5 cycles per operation. Note that the multiplier inside the ZAP processor is not pipelined.
* The abort model is base restored. This allows for the implementation of a demand based paging system if supporting software is available.

### 1.1. Superpipelined Microarchitecture

ZAP uses a 17 stage execution pipeline to increase the speed of the flow of instructions to the processor. The 17 stage pipeline consists of Address Generator, TLB Check, Cache Access, Memory, Fetch, Instruction Buffer, Thumb Decoder, Pre-Decoder, Decoder, Issue, Shift, Execute, TLB Check, Cache Access, Memory and Writeback.

> To maintain compatibility with the ARMv5TE standard, reading the program counter (PC) will return PC + 8 when read.

During normal operation:

* One instruction is writing out one or two results to the register bank.
  * In case of LDR/STR with writeback, two results are being written to the register bank in a single cycle.
  * All other instructions write out one result to the register bank per cycle.
  * A pending load might write another value. The RF has 3 write ports.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is performing arithmetic, logic or memory address generation operations. This stage also confirms or rejects the branch predictor's decisions. The ALU performs saturation in the same cycle.
* The instruction before that is performing a correction, shift or multiply/MAC operation.
* The instruction before that is performing a register or pipeline read.
* The instruction before that is being decoded.
* The instruction before that is being sequenced to micro-ops (possibly).
  * Most of the time, 1 ARM instruction = 1 micro-op.
  * The only ARM instructions requiring more than 1 micro-op generation are BLX, LDM, STM, SWAP and LONG MULTIPLY (They generate a 32-bit result per micro-op).
  * All other ARM instruction decode to just a single micro-op.
  * This stage also causes branches predicted as taken to be actually executed. The latency for a successfully predicted taken branch is 6 cycles.
* The instruction before that is being being decompressed. This is only required in the Thumb state, else the stage simply passes the instructions on.
* The instruction before that is popped off the instruction buffer.
* The instruction before that is pushed onto the instruction buffer. Branches\
  are predicted using a bimodal predictor (if applicable).
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.
* The instruction before that is accessing the cache/TLB RAM.

The deep pipeline, although uses more resources, allows the ZAP to run at high clock speeds.

#### 1.1.1. Automatic Dual Forwarding Network

The ZAP pipeline has an efficient automatic dual forwarding network with interlock detection hardware. This is done automatically and no software intervention is required. This complex feedback logic guarantees that almost all micro-ops/instructions execute at a rate of 1 every cycle.

The only times a pipeline stalls is when (assume 100% cache hit rate):

* An instruction uses a register that is a data (not pointer) destination for a load instruction within 6 cycles (assuming a load hit).
* The pipeline is executing any multiply/MAC instruction (4 to 5 cycle latency).
  * An instruction that uses a register that is a destination for multiply/MAC adds +1 to the multiply/MAC operation's latency.
* Two back to back instructions require non-zero shift and the second instruction's operand overlaps with the first instruction's destination.

This snippet of ARM code takes 6 cycles to execute:

```
    ADD  R1, R2, R2 LSL #10 (1 cycle)
    ADD  R1, R1, R1 LSL #20 (2 cycles)
    ADD  R3, R4, R5, LSR #3 (1 cycle)
    QADD R3, R3, R3         (1 cycle)
    MOV  R4, R3             (1 cycle)
```

This snippet of ARM code takes only 5 cycles (Possible because of dual feedback network):

```
    ADD  R1, R2, R2, R2     (1 cycle)
    ADD  R1, R1, R1 LSL #2  (1 cycle)
    ADD  R3, R4, R5 LSR #3  (1 cycle)
    QADD R3, R3, R3         (1 cycle)
    MOV  R4, R3             (1 cycle)
```

#### 1.1.2. Single Cycle Load with Writeback

The ZAP can execute `LDR`/`STR` with writeback in a single cycle. It will perform a parallel write to the register file with the pointer register and the data register in the same cycle.

#### 1.1.3. Hit Under Miss/Execute Under Miss

Data cache accesses that are performing line fills will not block subsequent instructions from executing. In addition, the data cache supports hit under miss functionality i.e., the cache can service the next memory access (hit) while handing the current line fill (miss). Thus, the ZAP can change the order of completion of memory accesses with respect to other instructions, when possible, in a relatively simple way.

If a store misses and is in the process of a line fill, a subsequent load at the same address will report as a hit during the line fill.

#### 1.1.4. Multi Port Register File

ZAP implements the register file in flip-flops. The register file provides 4 read ports and 3 write ports (A, B and C). The operation is as follows:

| Operation           | Port A | Port B | Port C                               |
| ------------------- | ------ | ------ | ------------------------------------ |
| Load with Writeback | Used   | Used   | _Free to be used by background load_ |
| Other               | Used   | Unused | _Free to be used by background load_ |

#### 1.1.5. Branch Predictor and Return Address Stack

To improve performance, the ZAP processor uses a bimodal branch predictor. A branch memory is maintained which stores the state of each branch and the target address and branch tag. Note that the predictor can only predict `Bcc[L]`, `BX LR`, `LDM` with PC in register list and `MOV PC, LR` instructions. Some of these utilize the RAS.

* Correctly predicted instructions take 2 cycles (taken)/1 cycle (not taken) of latency. Misprediction latency is 12 cycles.
* Prediction unsupported methods for PC changes takes 12 cycles.
* Loading to PC from memory takes 18 cycles. The bimodal predictor is organized as a direct mapped unit so aliasing is possible. The predictor cannot be disabled.

The processor implements a 4 deep return address stack.&#x20;

Upon calls to

* `BL offset`

the potential return address is pushed to a stack in the processor.

On encountering these instructions:

* `BX LR`,
* `MOV PC, LR`
* `LDM` with PC in register list.

the CPU treats them as function returns and will pop return address of the stack much earlier. This results in some performance improvement and reduced branch latency. Correctly predicted return takes 2 cycles, while incorrectly or unpredicted returns take 12 cycles.

### 1.2. External Bus Interface

ZAP features a common 32-bit Wishbone B3 bus to access external resources (like DRAM/SRAM/IO etc). The processor can generate byte, halfword or word accesses. The processor uses CTI and BTE signals to allow the bus to function more efficiently. Registered feedback mode is supported for higher performance. Note that multiprocessing is not readily supported and hence, SWAP instructions do not actually perform locked transfers.

**The bus interface is efficient for burst transfers and hence, cache must be enabled as soon as possible for good performance.**

### 1.3. System Control

Please refer to ref \[1] for CP15 CSR architectural requirements. The ZAP implements the following software accessible registers within its CP15 coprocessor.

NOTE: Cleaning and flushing cache and TLB is only supported for the entire memory.&#x20;

Selective flushing of TLB will result in the entire TLB being flushed.&#x20;

Selective cleaning of TLB will result in the entire TLB being cleaned.&#x20;

The above rules are permitted as per the arch spec.

* Register 1: Cache and MMU control.
* Register 2: Translation Base.
* Register 3: Domain Access Control.
* Register 5: FSR.
* Register 6: FAR.
* Register 8: TLB functions.
* Register 7: Cache functions.
  * The arch spec allows for a subset of the functions to be implemented for register 7.
  *   These below are valid value supported in ZAP for register 7. Using other operations will result in UNDEFINED operation.

      | Cache Operation                                      | Opcode2 | CRM    |
      | ---------------------------------------------------- | ------- | ------ |
      | Flush instruction and data cache                     | 0b000   | 0b0111 |
      | Flush instruction cache                              | 0b000   | 0b0101 |
      | Flush data cache                                     | 0b000   | 0b0110 |
      | Clean data cache                                     | 0b000   | 0b101x |
      | Clean and flush data cache. Flush instruction cache. | 0b000   | 0b1111 |
      | Clean and flush data cache                           | 0b000   | 0b1110 |
* Register 13: FCSE Register.

### 1.4. CPU Ports and Parameters

#### 1.4.1. Parameters

Note that all parameters should be 2^n. Cache size should be multiple of line size and at least 16 x line width. Caches/TLBs consume majority of the resources so should be tuned as required. The default parameters give you quite large caches.

| Parameter                   | Default | Description                                                                |
| --------------------------- | ------- | -------------------------------------------------------------------------- |
| BP\_ENTRIES                 | 1024    | Predictor RAM depth. Each RAM row also contains the branch target address. |
| FIFO\_DEPTH                 | 4       | Command FIFO depth.                                                        |
| STORE\_BUFFER\_DEPTH        | 16      | Depth of the store buffer. Keep multiple of cache line size in bytes / 4.  |
| DATA\_SECTION\_TLB\_ENTRIES | 128     | Section TLB entries (Data).                                                |
| DATA\_LPAGE\_TLB\_ENTRIES   | 128     | Large page TLB entries (Data).                                             |
| DATA\_SPAGE\_TLB\_ENTRIES   | 128     | Small page TLB entries (Data).                                             |
| DATA\_FPAGE\_TLB\_ENTRIES   | 128     | Tiny page TLB entries (Data).                                              |
| DATA\_CACHE\_SIZE           | 16384   | Cache size in bytes. Should be at least 16 x line size.                    |
| CODE\_SECTION\_TLB\_ENTRIES | 128     | Section TLB entries.                                                       |
| CODE\_LPAGE\_TLB\_ENTRIES   | 128     | Large page TLB entries.                                                    |
| CODE\_SPAGE\_TLB\_ENTRIES   | 128     | Small page TLB entries.                                                    |
| CODE\_FPAGE\_TLB\_ENTRIES   | 128     | Tiny page TLB entries.                                                     |
| CODE\_CACHE\_SIZE           | 16384   | Cache size in bytes. Should be at least 16 x line size.                    |
| DATA\_CACHE\_LINE           | 64      | Cache Line for Data (Byte). Keep > 8                                       |
| CODE\_CACHE\_LINE           | 64      | Cache Line for Code (Byte). Keep > 8                                       |
| RAS\_DEPTH                  | 4       | Depth of Return Address Stack                                              |

#### 1.4.2. IO

| Port       | Description                                                                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| i\_clk     | Clock. All logic is clocked on the rising edge of this signal.                                                                                      |
| i\_reset   | Active high global reset signal. Assert for a duration >= 1 clock cycle (not necessarily synchronously to clock edge). Signal is internally synced. |
| i\_irq     | Interrupt. Level Sensitive. Signal is internally synced.                                                                                            |
| i\_fiq     | Fast Interrupt. Level Sensitive. Signal is internally synced.                                                                                       |
| o\_wb\_cyc | Wishbone CYC signal.                                                                                                                                |
| o\_wb\_stb | Wishbone STB signal.                                                                                                                                |
| o\_wb\_adr | Wishbone address signal. (32)                                                                                                                       |
| o\_wb\_we  | Wishbone write enable signal.                                                                                                                       |
| o\_wb\_dat | Wishbone data output signal. (32)                                                                                                                   |
| o\_wb\_sel | Wishbone byte select signal. (4)                                                                                                                    |
| o\_wb\_cti | Wishbone CTI (Classic, Incrementing Burst, EOB) (3)                                                                                                 |
| o\_wb\_bte | Wishbone BTE (Linear) (2)                                                                                                                           |
| i\_wb\_ack | Wishbone acknowledge signal. Wishbone registered cycles recommended.                                                                                |
| i\_wb\_dat | Wishbone data input signal. (32)                                                                                                                    |

#### 1.4.3. Integration

* To use the ZAP processor in your project:
  *   Get the project files:

      > git clone https://github.com/krevanth/ZAP.git
  * Add all the files in `src/rtl/*.sv` to your project.
  * Add `src/rtl/` to your tool's search path to allow it to pick up SV headers.
  * Instantiate the ZAP processor in your project using this template:

```
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
```

* The processor provides a Wishbone B3 bus. It is recommended that you use it in registered feedback cycle mode.
* Interrupts are level sensitive and are internally synced to clock.

### 1.5. ARM Implementation Options

#### 1.5.1. Big and Little Endian

ZAP only supports little endian byte ordering.

#### 1.5.2. 26-Bit Architecture

ZAP does not support the legacy 26-bit mode.

#### 1.5.3. Thumb

ZAP has support for the thumb (ARMV5T) instruction set.

#### 1.5.4. ARM DSP Enhanced Instruction Set

The ZAP implements the ARM DSP-enhanced instruction set (ARMV5E). There are new multiply instructions that operate on 16-bit data values and new saturation instructions. Some of the new instructions are:&#x20;

* SMLAxy 32<=16x16+32&#x20;
* SMLAWy 32<=32x16+32
* SMLALxy 64<=16x16+64
* SMULxy 32<=16x16&#x20;
* SMULWy 32<=32x16&#x20;
* QADD adds two registers and saturates the result if an overflow occurred.
* QDADD doubles and saturates one of the input registers then add and saturate.
* QSUB subtracts two registers and saturates the result if an overflow occurred.
* QDSUB doubles and saturates one of the input registers then subtract and saturate.

The ZAP also implements LDRD, STRD and PLD instructions with the following implementation notes:&#x20;

* PLD is interpreted as a NOP.
* MCRR and MRRC are not intended to be used on coprocessor 15 (see \[1]). Since ZAP does not have an external coprocessor bus, these instructions should not be used.

#### 1.5.5. Base Register Update

If a data abort is signaled on a memory instruction that specifies writeback, the contents of the base register will not be updated. This holds for all load and store instructions. This behavior  is referred to in the ARM V5TE architecture as the Base Restored Abort Model.

#### 1.5.6. Cache and TLB Lockdown

ZAP does not support lockdown of cache and TLB entries.

#### 1.5.7. TLB Flush

ZAP implements global TLB flushing. If software tries to invalidate selective TLB entries, the entire TLB will be invalidated. This behavior is acceptable as per the arch specification.

#### 1.5.8. Cache Clean and Flush

ZAP implements global cache cleaning and flushing. Cleaning and/or flushing specific cache lines/VA is not supported.

#### 1.5.9. Cache and TLB Structure

ZAP implements a direct mapped cache and TLB. Separate caches and TLBs exist for instruction and data paths. Each MMU (I and D) has 4 TLBs, one each for sections, large pages, small pages and tiny pages. Each one is direct mapped.

#### 1.5.10. FCSE

ZAP implements the FCSE.

## 2. Project Environment (Docker)

The project environment requires Docker to be installed at your site. Click [here](https://docs.docker.com/engine/install/) for instructions on how to install Docker. The steps here assume that the user is a part of the `docker` group.

I (Revanth Kamaraj) would like to thank Erez Binyamin for adding Docker support to allow the core to be used more widely.

### 2.1. Running TCs

To run all/a specific TC, do:

> make \[TC=test\_name]

See `src/ts` for a list of test names. Not providing a testname will run all tests.

To remove existing object/simulation/synthesis files, do:

> make clean

### 2.2. Adding TCs

* Create a folder `src/ts/<test_name>`
* Please note that these will be run on the sample TB SOC platform.
  * See `src/testbench/testbench.v` for more information.
* Tests will produce wave files in the `obj/src/ts/<test_name>/zap.vcd`.
* Add a C file (.c), an assembly file (.s) and a linker script (.ld).
*   Create a `Config.cfg`. This is a Perl hash that must be edited to meet requirements. Note that the registers in the `REG_CHECK` are indexed registers. To find those, please do:

    > cat src/rtl/zap\_localparams.svh | grep PHY

    For example, if a check requires a certain value of R13 in IRQ mode, the hash will mention the register number as r25.
* Here is a sample `Config.cfg`:

```
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
        );
```

### 2.3. Running RTL Lint

To run RTL lint, simply do:

> make lint

### 2.4. Running Vivado Synthesis

Synthesis scripts can be found here: `src/syn/`

Assuming you have Vivado installed, please do:

> make syn

Timing report will be available in `obj/syn/syn_timing.rpt`

If you had used Docker previously to run a test, or had run synth before, do a

> make clean

first.

#### 2.4.1. XDC Setup (Vivado FPGA Synthesis)

* The XDC assumes a 200MHz clock for an Artix 7 FPGA part.
* Input assume they receive data from a flop with Tcq = 50% of clock period.
* Outputs assume they are driving a flop with Tsu = 2ns Th=1ns.
* Setting FPGA synthesis clock to an unreasonably high frequency may result in better timing closure (but will result in a larger design).&#x20;
* The tool should be able to meet 140MHz on the Artix 7 FPGA.

### 3. References

\[1] ARM Architecture Specification (ARM DDI 0100E)

### 4. Mentions

The ZAP project was mentioned [here](https://researchgate.net/publication/347558929\_Free\_ARM\_Compatible\_Softcores\_on\_FPGA)

### 5. License

Copyright (C) 2016-2022 Revanth Kamaraj

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.&#x20;

###
