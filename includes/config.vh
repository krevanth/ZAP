/*
You can defines these macros...
FPGA/ASIC - Determines RAM type.
TB_CACHE/FPGA_CACHE - Determines cache type.
IRQ_EN - Bench only. Gives periodic IRQs.
SIM - Bench only. Be more verbose
 */


`ifndef FPGA
        `define FPGA
`endif

`ifndef TB_CACHE
        `define TB_CACHE
`endif

`ifndef IRQ_EN
        `define IRQ_EN
`endif


