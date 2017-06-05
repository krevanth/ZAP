## *ZAP* : ARM compatible core with cache and MMU (ARMv4T ISA compatible)

#### Author        : Revanth Kamaraj (revanth91kamaraj@gmail.com)
#### License       : GPL v2

### Description 

ZAP is a pipelined ARM processor core that can execute the ARMv4T instruction
set. It is equipped with ARMv4 compatible split writeback caches and memory 
management capabilities. The processor core uses a 10 stage pipeline.

### Current Status 

Alpha. 16-bit instruction support is experimental.

### Bus Interface 
 
Wishbone B3 compatible 32-bit bus.

### Features 

    Fully synthesizable Verilog-2001 core.    
    Store buffer for improved performance.    
    Can execute ARMv4T code. Note that compressed instruction support is EXPERIMENTAL.
    Wishbone B3 compatible interface. Cache unit supports burst access.
    10-stage pipeline design. Pipeline has bypass network to resolve dependencies.
    2 write ports for the register file to allow LDR/STR with writeback to execute as a single instruction.
    Branch prediction supported.
    Split I and D writeback cache (Size can be configured using parameters).
    Split I and D MMUs (TLB size can be configured using parameters).
    Base restored abort model to simplify data abort handling.

### Pipeline Overview :

FETCH => FIFO => DECOMPRESS => PRE-DECODE => DECODE => ISSUE => SHIFTER => ALU => MEMORY => WRITEBACK

The pipeline is fully bypassed to allow most dependent instructions to execute 
without stalls. The pipeline stalls for 3 cycles if there is an attempt to 
use a value loaded from memory immediately following it. 32x32+32=32 
operations take 6 clock cycles while 32x32+64=64 takes 12 clock cycles. 
Multiplication and non trivial shifts require registers a cycle early else 
the pipeline stalls for 1 cycle.

### Project Documentation 

Please see the docs folder.

### Feedback 

Please provide your feedback on the google forum : https://groups.google.com/d/forum/zap-devel

### To simulate using Icarus Verilog 

Enter *hw/sim* and run *run_sim_gui.pl*

### License 

Copyright (C) 2016, 2017 Revanth Kamaraj.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


