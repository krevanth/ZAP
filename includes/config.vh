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

`ifndef __CONFIG_VH__
`define __CONFIG_VH__

//      `timescale 1ns/1ps
        `define CMMU_EN         
        `define COMPRESS_EN      
        `define SIM
        `define STALL
        `define IRQ_EN
        `define VCD_FILE_PATH "/tmp/zap.vcd"
        `define MEMORY_IMAGE "/tmp/prog.v"
        `define MAX_CLOCK_CYCLES 100000

/* DO NOT DEFINE ANY OF THIS IF YOU ARE SYNTHESIZING! */

//        `define FORCE_ICACHE_EN
//        `define FORCE_DCACHE_EN
//        `define FORCE_I_CACHEABLE
//        `define FORCE_D_CACHEABLE
          `define FORCE_I_RAND_CACHEABLE
          `define FORCE_D_RAND_CACHEABLE

`endif
