module zap_test;

parameter PHY_REGS  = 46;
parameter ALU_OPS   = 32;
parameter SHIFT_OPS = 5;
parameter ARCH_REGS = 32;

// Clock and reset.
reg              i_clk;                  // ZAP clock.        
reg              i_reset;                // Active high synchronous reset.
                
// From I-cache.
wire [31:0]       i_instruction;          // A 32-bit ZAP instruction.
wire             i_valid;                // Instruction valid.
wire             i_instr_abort;          // Instruction abort fault.


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
 wire              o_fiq_ack;              // FIQ acknowledge.
 wire              o_irq_ack;              // IRQ acknowledge.

// Program counter.
wire[31:0]       o_pc;                   // Program counter.

wire o_mem_reset;

// CPSR.
wire [31:0]      o_cpsr;                 // CPSR

`include "cc.vh"

wire [31:0] r0; assign r0 = u_zap_top.u_zap_regf.r_ff[0]; 
wire [31:0] r1; assign r1 = u_zap_top.u_zap_regf.r_ff[1];
wire [31:0] r2; assign r2 = u_zap_top.u_zap_regf.r_ff[2];
wire [31:0] r3; assign r3 = u_zap_top.u_zap_regf.r_ff[3];
wire [31:0] r4; assign r4 = u_zap_top.u_zap_regf.r_ff[4];
wire [31:0] r5; assign r5 = u_zap_top.u_zap_regf.r_ff[5];
wire [31:0] r6; assign r6 = u_zap_top.u_zap_regf.r_ff[6];
wire [31:0] r7; assign r7 = u_zap_top.u_zap_regf.r_ff[7];
wire [31:0] r8; assign r8 = u_zap_top.u_zap_regf.r_ff[8];
wire [31:0] r9; assign r9 = u_zap_top.u_zap_regf.r_ff[9];
wire [31:0] r10; assign r10 = u_zap_top.u_zap_regf.r_ff[10];
wire [31:0] r11; assign r11 = u_zap_top.u_zap_regf.r_ff[11];
wire [31:0] r12; assign r12 = u_zap_top.u_zap_regf.r_ff[12];
wire [31:0] r13; assign r13 = u_zap_top.u_zap_regf.r_ff[13];
wire [31:0] r14; assign r14 = u_zap_top.u_zap_regf.r_ff[14];
wire [31:0] r15; assign r15 = u_zap_top.u_zap_regf.r_ff[15];
wire [31:0] r16; assign r16 = u_zap_top.u_zap_regf.r_ff[16];
wire [31:0] r17; assign r17 = u_zap_top.u_zap_regf.r_ff[17];
wire [31:0] r18; assign r18 = u_zap_top.u_zap_regf.r_ff[18];
wire [31:0] r19; assign r19 = u_zap_top.u_zap_regf.r_ff[19];
wire [31:0] r20; assign r20 = u_zap_top.u_zap_regf.r_ff[20];
wire [31:0] r21; assign r21 = u_zap_top.u_zap_regf.r_ff[21];
wire [31:0] r22; assign r22 = u_zap_top.u_zap_regf.r_ff[22];
wire [31:0] r23; assign r23 = u_zap_top.u_zap_regf.r_ff[23];
wire [31:0] r24; assign r24 = u_zap_top.u_zap_regf.r_ff[24];
wire [31:0] r25; assign r25 = u_zap_top.u_zap_regf.r_ff[25];
wire [31:0] r26; assign r26 = u_zap_top.u_zap_regf.r_ff[26];
wire [31:0] r27; assign r27 = u_zap_top.u_zap_regf.r_ff[27];
wire [31:0] r28; assign r28 = u_zap_top.u_zap_regf.r_ff[28];
wire [31:0] r29; assign r29 = u_zap_top.u_zap_regf.r_ff[29];
wire [31:0] r30; assign r30 = u_zap_top.u_zap_regf.r_ff[30];
wire [31:0] r31; assign r31 = u_zap_top.u_zap_regf.r_ff[31];
wire [31:0] r32; assign r32 = u_zap_top.u_zap_regf.r_ff[32];
wire [31:0] r33; assign r33 = u_zap_top.u_zap_regf.r_ff[33];
wire [31:0] r34; assign r34 = u_zap_top.u_zap_regf.r_ff[34];
wire [31:0] r35; assign r35 = u_zap_top.u_zap_regf.r_ff[35];
wire [31:0] r36; assign r36 = u_zap_top.u_zap_regf.r_ff[36];
wire [31:0] r37; assign r37 = u_zap_top.u_zap_regf.r_ff[37];
wire [31:0] r38; assign r38 = u_zap_top.u_zap_regf.r_ff[38];
wire [31:0] r39; assign r39 = u_zap_top.u_zap_regf.r_ff[39];
wire [31:0] r40; assign r40 = u_zap_top.u_zap_regf.r_ff[40];
wire [31:0] r41; assign r41 = u_zap_top.u_zap_regf.r_ff[41];
wire [31:0] r42; assign r42 = u_zap_top.u_zap_regf.r_ff[42];
wire [31:0] r43; assign r43 = u_zap_top.u_zap_regf.r_ff[43];
wire [31:0] r44; assign r44 = u_zap_top.u_zap_regf.r_ff[44];
wire [31:0] r45; assign r45 = u_zap_top.u_zap_regf.r_ff[45];

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

initial #200
begin
        i_irq = 1;
end

initial
begin
        i_irq = 0;
        i_fiq = 0;

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
