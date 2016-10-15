/*
You can defines these macros...
FPGA/ASIC - Determines RAM type.
TB_CACHE/FPGA_CACHE - Determines cache type.
IRQ_EN - Bench only. Gives periodic IRQs.
SIM - Bench only. Be more verbose
 */


`ifndef FPGA
        `define FPGA
        `undef ASIC
`endif

`ifndef TB_CACHE
        `define TB_CACHE
        `undef FPGA_CACHE
`endif

`ifndef IRQ_EN
        `define IRQ_EN
`endif

`ifndef VCD_FILE_PATH
        `define VCD_FILE_PATH "/tmp/zap.vcd"
`endif

`ifndef MEMORY_IMAGE
        `define MEMORY_IMAGE "/tmp/prog.v"
`endif
