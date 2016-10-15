/*
You can defines these macros...
FPGA/ASIC - Determines RAM type.
TB_CACHE/FPGA_CACHE - Determines cache type.
IRQ_EN - Bench only. Gives periodic IRQs.
SIM - Bench only. Be more verbose
 */

`timescale 1ns/1ps

`ifndef FPGA
        `define FPGA
        `undef ASIC
`endif

`ifndef IRQ_EN
        `define IRQ_EN
`endif

`ifndef SIM
        `define SIM
`endif

`ifndef VCD_FILE_PATH
        `define VCD_FILE_PATH "/tmp/zap.vcd"
`endif

`ifndef MEMORY_IMAGE
        `define MEMORY_IMAGE "/tmp/prog.v"
`endif

`ifndef MAX_CLOCK_CYCLES
        `define MAX_CLOCK_CYCLES 100000
`endif
