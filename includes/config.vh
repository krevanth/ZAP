//
// Please use only these kinds of comments. DO NOT USE /* */ STYLE.
//

`ifndef __CONFIG_VH__
`define __CONFIG_VH__

//      `timescale 1ns/1ps

        `define CMMU_EN
        `define SIM
        `define STALL
        `define IRQ_EN
        `define VCD_FILE_PATH "/tmp/zap.vcd"
        `define MEMORY_IMAGE "/tmp/prog.v"
        `define MAX_CLOCK_CYCLES 100000
        `define SEED 32'h12345678
        `define THUMB_EN

/* DO NOT DEFINE ANY OF THIS IF YOU ARE SYNTHESIZING! */

//        `define FORCE_ICACHE_EN
//        `define FORCE_DCACHE_EN
//        `define FORCE_I_CACHEABLE
//        `define FORCE_D_CACHEABLE
          `define FORCE_I_RAND_CACHEABLE
          `define FORCE_D_RAND_CACHEABLE

`endif
