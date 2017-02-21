module zap_test;

parameter RAM_SIZE = 32768;
parameter START = 1992;
parameter COUNT = 120;

`define STALL
`define IRQ_EN
`define VCD_FILE_PATH   "/tmp/zap.vcd"
`define MEMORY_IMAGE    "/tmp/prog.v"
`define MAX_CLOCK_CYCLES 100000

reg             i_clk;
reg             i_clk_multipump;
reg             i_reset;

reg             i_irq;
reg             i_fiq;

wire             o_dram_wr_en;
wire             o_dram_rd_en;
wire [31:0]      o_dram_data;
wire [31:0]      i_dram_data;
wire             i_dram_stall;
wire [3:0]       o_dram_ben;
wire [31:0]      o_dram_addr;

wire             o_iram_rd_en;
wire [31:0]      i_iram_data;
wire             i_iram_stall;
wire [31:0]      o_iram_addr;


// =========================
// Processor core.
// =========================
zap_top #(

        // enable cache and mmu.
        .CACHE_MMU_ENABLE(1),

        // enable 16-bit support.
        .COMPRESSED_EN(1),

        // data config.
        .DATA_SECTION_TLB_ENTRIES(4),
        .DATA_LPAGE_TLB_ENTRIES(8),
        .DATA_SPAGE_TLB_ENTRIES(16),
        .DATA_CACHE_SIZE(1024),

        // code config.
        .CODE_SECTION_TLB_ENTRIES(4),
        .CODE_LPAGE_TLB_ENTRIES(8),
        .CODE_SPAGE_TLB_ENTRIES(16),
        .CODE_CACHE_SIZE(1024)
) 
u_zap_top 
(
        .i_clk(i_clk),
        .i_clk_multipump(i_clk_multipump),
        .i_reset(i_reset),
        .i_irq(i_irq),
        .i_fiq(i_fiq),

        .o_dram_wr_en(o_dram_wr_en),
        .o_dram_rd_en(o_dram_rd_en),
        .o_dram_data (o_dram_data),
        .o_dram_ben  (o_dram_ben),
        .o_dram_addr (o_dram_addr),
        .i_dram_data (i_dram_data),
        .i_dram_stall(i_dram_stall),

        .o_iram_rd_en(o_iram_rd_en),
        .o_iram_addr (o_iram_addr),
        .i_iram_stall(i_iram_stall),
        .i_iram_data(i_iram_data)
);

// ===========================
// RAM
// ===========================
model_ram
#(
        .SIZE_IN_BYTES(RAM_SIZE)
)
U_MODEL_RAM
(
        .i_clk(i_clk),

        // RW port.
        .i_wen_rw   (o_dram_wr_en),
        .i_ren_rw   (o_dram_rd_en),
        .i_data_rw  (o_dram_data),
        .i_ben_rw   (o_dram_ben),
        .o_data_rw  (i_dram_data),
        .i_addr_rw  (o_dram_addr),
        .o_stall_rw (i_dram_stall),

        // RO port.
        .i_ren_ro   (o_iram_rd_en),
        .o_data_ro  (i_iram_data),
        .i_addr_ro  (o_iram_addr),
        .o_stall_ro (i_iram_stall)  
);


// ===========================
// Variables.
// ===========================
integer i;

// ===========================
// Clocks.
// ===========================
initial i_clk    = 0;
always #10 i_clk = !i_clk;

initial
begin
        i_clk_multipump = 0;

        #5;
        forever #5 i_clk_multipump = !i_clk_multipump;        
end

integer seed = `SEED;

`ifdef IRQ_EN

always @ (negedge i_clk)
begin
        i_irq = $random;
end

`endif

initial
begin
        i_irq = 0;
        i_fiq = 0;

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("DATA INITIAL :: mem[%d] = %x", i, {U_MODEL_RAM.ram[(i/4)]});
        end

        $dumpfile(`VCD_FILE_PATH);
        $dumpvars;

        $display("Started!");

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        repeat(`MAX_CLOCK_CYCLES) @(negedge i_clk);

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("DATA mem[%d] = %x", i, {U_MODEL_RAM.ram[(i/4)]});
        end

        $finish;
end

endmodule
