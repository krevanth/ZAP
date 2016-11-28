`include "config.vh"

module zap_test;

parameter RAM_SIZE = 8192;
parameter START = 4992;
parameter COUNT = 120;

reg             i_clk;
reg             i_clk_2x;
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
zap_top 
u_zap_top 
(
        .i_clk(i_clk),
        .i_clk_2x(i_clk_2x),
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
        .SIZE_IN_BYTES(RAM_SIZE),
        .INIT(0)
)
model_ram_data
(
        .i_clk(i_clk),
        .i_wen(o_dram_wr_en),
        .i_ren(o_dram_rd_en),
        .i_data(o_dram_data),
        .i_ben(o_dram_ben),
        .o_data(i_dram_data),
        .i_addr(o_dram_addr),
        .o_stall(i_dram_stall)        
);

model_ram
#(
        .SIZE_IN_BYTES(RAM_SIZE),
        .INIT(1)
)
model_ram_instr
(
        .i_clk(i_clk),
        .i_wen(1'd0),
        .i_ren(o_iram_rd_en),
        .i_data(32'd0),
        .i_ben(4'd0),
        .o_data(i_iram_data),
        .i_addr(o_iram_addr),
        .o_stall(i_iram_stall)  
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
        i_clk_2x = 0;

        #5;
        forever #5 i_clk_2x = !i_clk_2x;        
end

`ifdef IRQ_EN
always @ (negedge i_clk)
        i_irq = $random;
`endif

initial
begin
        i_irq = 0;
        i_fiq = 0;

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("DATA INITIAL :: mem[%d] = %x", i, {model_ram_data.ram[(i/4)]});
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
                $display("DATA mem[%d] = %x", i, {model_ram_data.ram[(i/4)]});
        end

        $finish;
end

endmodule
