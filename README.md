## *ZAP* : An ARM compatible core with cache and MMU (ARMv4T ISA compatible)

#### Author        : Revanth Kamaraj (revanth91kamaraj@gmail.com)
#### License       : GPL v2

### Description 

ZAP is a pipelined ARM processor core that can execute the ARMv4T instruction
set. It is equipped with ARMv4 compatible split writeback caches and memory 
management capabilities. The processor core uses a 10 stage pipeline.

Note that ARM GCC is included in the repository in the *sw* directory. The
makefile will extract the GCC compiler into the object folder.

### Current Status 

Experimental.

### Bugs and Known Issues

 - Issues with the Thumb ISA.  
 - SWAP does not bypass cache.

### Bus Interface 
 
Wishbone B3 compatible 32-bit bus.

### Documentation

Please see the PDF file at *doc/ZAP_PROCESSOR_CORE_DATASHEET.pdf*

### Features 

 - Fully synthesizable Verilog-2001 core.    
 - Store buffer for improved performance.    
 - Can execute ARMv4T code. Note that compressed instruction support is EXPERIMENTAL.
 - Wishbone B3 compatible interface. Cache unit supports burst access.
 - 10-stage pipeline design. Pipeline has bypass network to resolve dependencies.
 - 2 write ports for the register file to allow LDR/STR with writeback to execute as a single instruction.
 - Branch prediction supported.
 - Split I and D writeback cache (Size can be configured using parameters).
 - Split I and D MMUs (TLB size can be configured using parameters).
 - Base restored abort model to simplify data abort handling.

