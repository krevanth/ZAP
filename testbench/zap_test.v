module zap_test;

parameter PHY_REGS  = 46;
parameter ALU_OPS   = 32;
parameter SHIFT_OPS = 5;
parameter ARCH_REGS = 32;

// Clock and reset.
bit              i_clk;                  // ZAP clock.        
bit              i_reset;                // Active high synchronous reset.
                
// From I-cache.
bit [31:0]       i_instruction;          // A 32-bit ZAP instruction.
bit              i_valid;                // Instruction valid.
bit              i_instr_abort;          // Instruction abort fault.


// Memory access.
wire             o_read_en;              // Memory load
wire             o_write_en;             // Memory store.
wire[31:0]       o_address;              // Memory address.
wire             o_unsigned_byte_en;      // Unsigned byte enable.
wire             o_signed_byte_en;       // Signed byte enable.
wire             o_unsigned_halfword_en; // Unsiged halfword enable.
wire             o_signed_halfword_en;   // Signed halfword enable.

// From cache.
wire [31:0]     i_instruction_address;

// User view.
wire             o_mem_translate;

// Memory stall.
bit              i_data_stall;

// Memory abort.
bit              i_data_abort;

// Memory read data.
bit  [31:0]      i_rd_data;

// Memory write data.
wire [31:0]      o_wr_data;

// Interrupts.
bit              i_fiq;                  // FIQ signal.
bit              i_irq;                  // IRQ signal.

// Interrupt acknowledge.
 wire              o_fiq_ack;              // FIQ acknowledge.
 wire              o_irq_ack;              // IRQ acknowledge.

// Program counter.
wire[31:0]       o_pc;                   // Program counter.

wire o_mem_reset;

// CPSR.
wire [31:0]      o_cpsr;                 // CPSR

`include "cc.vh"

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
        .i_reset(i_reset),
        .i_instruction_address(i_instruction_address),
        .i_instruction(i_instruction),
        .i_valid(i_valid),
        .i_instr_abort(i_instr_abort),
        .o_read_en(o_read_en),
        .o_write_en(o_write_en),
        .o_address(o_address),
        .o_unsigned_byte_en(o_unsigned_byte_en),
        .o_signed_byte_en(o_signed_byte_en),
        .o_unsigned_halfword_en(o_unsigned_halfword_en),
        .o_signed_halfword_en(o_signed_halfword_en),
        .o_mem_translate(o_mem_translate),
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
        .o_mem_reset(o_mem_reset)
);

// Code memory.
cache u_i_cache
(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_address(o_pc),
        .o_data(i_instruction),
        .i_data('d0),
        .o_hit(i_valid),
        .o_miss(),
        .o_abort(i_instr_abort),
        .i_rd_en(1'd1),
        .i_wr_en(1'd0),
        .i_recover(1'd1)
);

// Data memory.
cache u_d_cache
(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_address(o_address),
        .i_data(o_wr_data),
        .o_data(i_rd_data),
        .o_hit(),
        .o_miss(i_data_stall),
        .o_abort(i_data_abort),  
        .i_rd_en(o_read_en),
        .i_wr_en(o_write_en),
        .i_recover(o_mem_reset)
);

initial i_clk = 0;
always #10 i_clk = !i_clk;

initial
begin
        $dumpfile("zap.vcd");
        $dumpvars;

        $display("Started!");

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        repeat(100) @(negedge i_clk);

        $finish;
end

endmodule
