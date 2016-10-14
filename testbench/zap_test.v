`include "config.vh"

module zap_test;

parameter FPGA_CACHE_SIZE = 1023;
parameter PHY_REGS  = 64;
parameter ALU_OPS   = 32;
parameter SHIFT_OPS = 5;
parameter ARCH_REGS = 32;

// Clock and reset.
reg              i_clk;                  // ZAP clock.        
reg              i_clk_2x;
reg              i_reset;                // Active high synchronous reset.
                
// From I-cache.
wire [31:0]       i_instruction;          // A 32-bit ZAP instruction.
wire             i_valid;                // Instruction valid.
wire             i_instr_abort;          // Instruction abort fault.


// Memory access.
wire             o_read_en;              // Memory load
wire             o_write_en;             // Memory store.
wire[31:0]       o_address;              // Memory address.

//Coproc wires.
wire                             o_copro_dav;
wire  [31:0]                     o_copro_word;
wire  [$clog2(PHY_REGS)-1:0]     o_copro_reg;

// User view.
wire             o_mem_translate;

// Memory stall.
wire             i_data_stall;

// Memory abort.
wire             i_data_abort;

// Memory read data.
wire [31:0]      i_rd_data;

// Memory write data.
wire [31:0]      o_wr_data;

// Interrupts.
reg              i_fiq;                  // FIQ signal.
reg              i_irq;                  // IRQ signal.

// Interrupt acknowledge.
 wire             o_fiq_ack;              // FIQ acknowledge.
 wire             o_irq_ack;              // IRQ acknowledge.

// Program counter.
wire[31:0]      o_pc;                   // Program counter.

wire [31:0]      o_cpsr;                 // CPSR

reg             i_copro_reg_en;
reg [5:0]       i_copro_reg_wr_index;
reg [5:0]       i_copro_reg_rd_index;
reg [31:0]      i_copro_reg_wr_data;
wire [31:0]     o_copro_reg_rd_data;

wire [3:0] o_ben;

initial
begin
        i_copro_reg_en          = 0;
        i_copro_reg_wr_index    = 16;
        i_copro_reg_rd_index    = 16;
        i_copro_reg_wr_data     = 0;
end

`include "cc.vh"

// Testing interrupts.
`ifdef IRQ_EN
always @ (negedge i_clk)
        i_irq = $random;
`endif

// Processor core.
zap_top 
#(
        .PHY_REGS(PHY_REGS),
        .ALU_OPS(ALU_OPS),
        .SHIFT_OPS(SHIFT_OPS),
        .ARCH_REGS(ARCH_REGS)
)
u_zap_top 
(
        .i_clk(i_clk),
        .i_clk_2x(i_clk_2x),
        .i_reset(i_reset),
        .i_instruction(i_instruction),
        .i_valid(i_valid),
        .i_instr_abort(i_instr_abort),
        .o_read_en(o_read_en),
        .o_write_en(o_write_en),
        .o_address(o_address),
        .o_mem_translate(o_mem_translate),
        .o_ben(o_ben),
        .i_data_stall(i_data_stall),
        .i_data_abort(i_data_abort),
        .i_rd_data(i_rd_data),
        .o_wr_data(o_wr_data),
        .i_fiq(i_fiq),
        .i_irq(i_irq),
        .o_fiq_ack(o_fiq_ack),
        .o_irq_ack(o_irq_ack),
        .o_pc(o_pc),
        .o_cpsr(o_cpsr),

        .i_copro_done (1'd1),           // Assume coprocessor completes its task.
//        .o_copro_flags (o_copro_flags),
        .o_copro_dav  (o_copro_dav),
        .o_copro_word (o_copro_word),
        .o_copro_reg  (o_copro_reg),

        .i_copro_reg_en(i_copro_reg_en),
        .i_copro_reg_wr_index(i_copro_reg_wr_index),
        .i_copro_reg_rd_index(i_copro_reg_rd_index),
        .i_copro_reg_wr_data(i_copro_reg_wr_data),
        .o_copro_reg_rd_data(o_copro_reg_rd_data)
);

`ifdef TB_CACHE

// Memory - Dual ported unified cache.
cache u_cache
(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_address(o_address & 32'hfffffffc),
        .i_address1(o_pc),
        .i_data(o_wr_data),
        .o_data(i_rd_data),
        .o_data1(i_instruction),
        .o_hit1(i_valid),
        .o_miss(i_data_stall),
        .i_ben(o_ben),
        .o_abort(i_data_abort),  
        .i_rd_en(o_read_en),
        .i_wr_en(o_write_en),
        .o_abort1(i_instr_abort),
        .i_cpsr(o_cpsr)
);

`elsif FPGA_CACHE

zap_cache_main
#(
        .SIZE_IN_BYTES(FPGA_CACHE_SIZE)
)
u_cache
(
        .i_clk(i_clk),
        .i_daddress(o_address),
        .i_iaddress(o_pc),
        .o_ddata(i_rd_data),
        .o_idata(i_instruction),
        .i_ben(o_ben),
        .i_ddata(o_wr_data),
        .i_wr_en(o_write_en)
);

assign i_valid       = 1'd1;
assign i_data_stall  = 1'd0;
assign i_data_abort  = 1'd0;
assign i_instr_abort = 1'd0;

`else
initial
begin
        $display("Please define TB_CACHE or FPGA_CACHE...");
        $finish;
end
`endif

initial i_clk = 0;
always #10 i_clk = !i_clk;

initial
begin
        i_clk_2x = 0;
        #5;
        forever #5 i_clk_2x = !i_clk_2x;        
end

integer i;

initial
begin
        i_irq = 0;
        i_fiq = 0;

        `ifdef TB_CACHE
        for(i=596;i<=644;i=i+4)
        begin
                $display("INITIAL(TB CACHE) :: mem[%d] = %x", i, {u_cache.mem[i+3],u_cache.mem[i+2],u_cache.mem[i+1],u_cache.mem[i]});
        end
        `elsif FPGA_CACHE
        for(i=596;i<=644;i=i+4)
        begin
                $display("INITIAL(FPGA CACHE) :: mem[%d] = %x", i, {u_cache.mem3[(i/4)+3], u_cache.mem2[(i/4)+2], u_cache.mem1[(i/4)+1], u_cache.mem0[(i/4)]});
        end
        `endif

        $dumpfile("zap.vcd");
        $dumpvars;

        $display("Started!");

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        repeat(50000) @(negedge i_clk);

        `ifdef TB_CACHE
        for(i=596;i<=644;i=i+4)
        begin
                $display("(TB)mem[%d] = %x", i, {u_cache.mem[i+3],u_cache.mem[i+2],u_cache.mem[i+1],u_cache.mem[i]});
        end
        `elsif FPGA_CACHE
        for(i=596;i<644;i=i+4)
        begin
                $display("(FPGA) mem[%d] = %x", i, {u_cache.mem3[(i/4)+3], u_cache.mem2[(i/4)+2], u_cache.mem1[(i/4)+1], u_cache.mem0[(i/4)]});
        end
        `endif

        $finish;
end

endmodule
