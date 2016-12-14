`default_nettype none
`include "config.vh"

module zap_top
(
        // Clock and reset.
        input   wire            i_clk,
        input   wire            i_clk_2x,
        input   wire            i_reset,

        // Interrupts.
        input   wire            i_irq,
        input   wire            i_fiq,

        // Simple D-Memory Interface.
        output  wire            o_dram_wr_en,
        output  wire            o_dram_rd_en,
        output  wire   [31:0]   o_dram_data,
        output  wire   [31:0]   o_dram_addr,
        output  wire   [3:0]    o_dram_ben,
        input   wire   [31:0]   i_dram_data, 
        input   wire            i_dram_stall,

        // Simple I-Memory Interface.
        output  wire            o_iram_rd_en,
        input   wire   [31:0]   i_iram_data,
        output  wire   [31:0]   o_iram_addr,
        input   wire            i_iram_stall
);

wire sync_reset;

`include "regs.vh"
`include "modes.vh"

localparam PHY_REGS = TOTAL_PHY_REGS;

wire [31:0] DRAM_WDATA;
wire [31:0] DRAM_RDATA;
wire [31:0] DRAM_ADDR ;
wire        DRAM_REN  ;
wire        DRAM_WEN  ;
wire [3:0]  DRAM_BEN  ;
wire        DRAM_STALL;

wire [31:0] IRAM_DATA;
wire [31:0] IRAM_ADDR;
wire        IRAM_REN;
wire        IRAM_STALL;

reg  clear;
reg  stall;
wire [31:0] instr;
wire instr_valid_n;
wire instr_abort;
wire clear_from_alu;
wire stall_from_shifter;
wire stall_from_issue;
wire stall_from_decode;
wire clear_from_writeback;
wire clear_from_decode;
wire [31:0] cpsr;
wire [31:0] pc, pc_nxt;
wire [31:0] addr, addr_nxt;
wire ren, wen;
wire [3:0] ben;
wire [31:0] wdata, rdata;
wire data_stall;
wire data_abort;
wire force_user;
wire cp_done;
wire cp_dav;
wire [31:0] cp_word, cp_wdata, cp_rdata;
wire cp_reg_en;
wire [$clog2(PHY_REGS)-1:0] cp_rindex, cp_windex;

// ======================
// Processor core.
// ======================
zap_core 
u_zap_core 
(
.i_clk                  (i_clk),
.i_clk_2x               (i_clk_2x),
.i_reset                (i_reset),
.i_instruction          (instr),
.i_valid                (!instr_valid_n),
.i_instr_abort          (instr_abort),
.o_read_en              (ren),
.o_write_en             (wen),
.o_address              (addr),
.o_mem_translate        (force_user),
.o_ben                  (ben),
.i_data_stall           (data_stall),
.i_data_abort           (data_abort),
.i_rd_data              (rdata),
.o_wr_data              (wdata),
.i_fiq                  (i_fiq),
.i_irq                  (i_irq),
.o_pc                   (pc),
.i_copro_done           (cp_done),           
.o_copro_dav            (cp_dav),
.o_copro_word           (cp_word),
.i_copro_reg_en         (cp_reg_en),
.i_copro_reg_wr_index   (cp_windex),
.i_copro_reg_rd_index   (cp_rindex),
.i_copro_reg_wr_data    (cp_wdata),
.o_copro_reg_rd_data    (cp_rdata),
.o_cpsr                 (cpsr),

// Combo Outputs.
.o_pc_nxt               (pc_nxt),
.o_address_nxt          (addr_nxt),
.o_clear_from_alu       (clear_from_alu),
.o_stall_from_shifter   (stall_from_shifter),
.o_stall_from_issue     (stall_from_issue),
.o_stall_from_decode    (stall_from_decode),
.o_clear_from_decode    (clear_from_decode),
.o_clear_from_writeback (clear_from_writeback)
);

`ifndef CMMU_EN

always @*
begin
        // Pipeline external stall sequence.
        if      ( clear_from_writeback )       stall = 1'd0;
        else if ( data_stall )                 stall = 1'd1;
        else if ( clear_from_alu )             stall = 1'd0;       
        else if ( stall_from_shifter )         stall = 1'd1;
        else if ( stall_from_issue )           stall = 1'd1;
        else if ( stall_from_decode)           stall = 1'd1;
        else                                   stall = 1'd0;
end

// Connect core directly to output.

assign o_dram_wr_en = wen;
assign o_dram_rd_en = ren;
assign o_dram_data  = wdata;
assign o_dram_addr  = addr;
assign o_dram_ben   = ben;
assign rdata        = i_dram_data;
assign data_stall   = i_dram_stall;
assign o_iram_rd_en  = !stall;
assign o_iram_addr   = pc;
assign instr         = i_iram_data;
assign instr_valid_n = i_iram_stall;
assign cp_done       = 1'd1;
assign cp_reg_en     = 1'd0;
assign cp_windex     = 0;
assign cp_rindex     = 0;
assign cp_wdata      = 0;

`else

// Reset synchronizer for MMU.
reset_sync u_reset_sync (.i_clk(i_clk), .i_reset(i_reset), .o_reset(sync_reset)); 

// ===========================
// MMU - DATA.
// ===========================
zap_d_mmu_cache #(.PHY_REGS(PHY_REGS))
u_zap_mmu_dcache (
.i_clk                   (i_clk), // Clock.
.i_reset                 (sync_reset), // Reset.
.i_address_nxt           (addr_nxt), // To be flopped address.
.i_clear_from_writeback  (clear_from_writeback),    // Clear from writeback.
.i_read_en               (ren), // Read request from CPU.
.i_write_en              (wen), // Write request from CPU.
.i_ben                   (ben), // Byte enable from CPU.
.i_wr_data               (wdata), // Data from CPU.
.i_address               (addr), // Address from CPU.
.i_cpsr                  ({cpsr[31:5], force_user ? USR : cpsr[4:0]}), // CPSR from CPU.
.o_rd_data               (rdata), // Data read. Pipeline register.

/* CAN CAUSE COMBO LOOP */
.o_stall                 (data_stall), // Not registered.
.o_fault                 (data_abort), // Not registered.

.i_cp_word               (cp_word),
.i_cp_dav                (cp_dav),
.o_cp_done               (cp_done),
.o_reg_en                (cp_reg_en),
.o_reg_wr_data           (cp_wdata),
.i_reg_rd_data           (cp_rdata),
.o_reg_wr_index          (cp_windex),
.o_reg_rd_index          (cp_rindex),

.o_ram_wr_data           ( DRAM_WDATA), // RAM write data.
.i_ram_rd_data           ( DRAM_RDATA), // RAM read data.
.o_ram_address           ( DRAM_ADDR ), // RAM address.
.o_ram_rd_en             ( DRAM_REN  ), // RAM read command.
.o_ram_wr_en             ( DRAM_WEN  ), // RAM write command.
.o_ram_ben               ( DRAM_BEN  ), // RAM byte enable.
.i_ram_done              (!DRAM_STALL)  // RAM done indicator.
);


zap_mem_shm U_ZAP_MEM_SHM
(
        .i_clk          (i_clk),
        .i_reset        (i_reset),
        .i_cpu_address  (DRAM_ADDR),
        .i_cpu_data     (DRAM_WDATA),
        .i_cpu_ren      (DRAM_REN),
        .i_cpu_wen      (DRAM_WEN),
        .o_cpu_data     (DRAM_RDATA),
        .o_cpu_stall    (DRAM_STALL),
        .i_cpu_flush    (1'd0), //(clear_from_writeback),
        .i_cpu_ben      (DRAM_BEN),

        .o_ram_addr     (o_dram_addr),
        .o_ram_rd_en    (o_dram_rd_en),     
        .o_ram_wr_en    (o_dram_wr_en),
        .o_ram_ben      (o_dram_ben),
        .o_ram_data     (o_dram_data),
        .i_ram_data     (i_dram_data),
        .i_ram_stall    (i_dram_stall)
);

always @*
begin
        // Pipeline external stall sequence.
        if      ( clear_from_writeback )       clear = 1'd1;
        else if ( data_stall )                 clear = 1'd0;
        else if ( clear_from_alu )             clear = 1'd1;       
        else if ( stall_from_shifter )         clear = 1'd0;
        else if ( stall_from_issue )           clear = 1'd0;
        else if ( stall_from_decode)           clear = 1'd0;
        else if ( clear_from_decode)           clear = 1'd1;
        else                                   clear = 1'd0;
end

// =============================
// MMU - INSTRUCTION.
// =============================
zap_i_mmu_cache #(.PHY_REGS(PHY_REGS))
u_zap_icache_mmu (
.i_clk                   (i_clk), // Clock.
.i_reset                 (sync_reset), // Reset.
.i_address_nxt           (pc_nxt), // To be flopped address.
.i_dcache_stall          (data_stall),
.i_clear_from_writeback  (clear_from_writeback), // | High Priority.
.i_clear_from_alu        (clear_from_alu),       // |
.i_stall_from_shifter    (stall_from_shifter),   // |
.i_stall_from_issue      (stall_from_issue),     // |
.i_stall_from_decode     (stall_from_decode),    // V Low Priority.
.i_clear_from_decode     (clear_from_decode),    // V
.i_address               (pc),     // Address from CPU.
.i_cpsr                  (cpsr), // CPSR from CPU.
.o_rd_data               (instr), // Data read. Pipeline register.

/* CAN CAUSE COMBO LOOP */
.o_stall                 (instr_valid_n), // Not registered.
.o_fault                 (instr_abort), // Not registered.

.i_cp_word               (cp_word),
.i_cp_dav                (cp_dav),
.i_reg_rd_data           (cp_rdata), 
 
.i_ram_rd_data           (IRAM_DATA), //(i_iram_data),  // RAM read data.
.o_ram_address           (IRAM_ADDR), //(o_iram_addr),  // RAM address.
.o_ram_rd_en             (IRAM_REN),  // (o_iram_rd_en), // RAM read command.
.i_ram_done              (!IRAM_STALL) // (!i_iram_stall)     // RAM done indicator.
);

/*
assign IRAM_DATA    = i_iram_data;
assign o_iram_addr  = IRAM_ADDR;
assign o_iram_rd_en = IRAM_REN;
assign IRAM_STALL   = i_iram_stall;
*/

zap_mem_shm U_ZAP_MEM_SHM_CODE
(
        .i_clk          (i_clk),
        .i_reset        (i_reset),
        .i_cpu_address  (IRAM_ADDR),
        .i_cpu_data     (32'd0),
        .i_cpu_ren      (IRAM_REN),
        .i_cpu_wen      (1'd0),
        .o_cpu_data     (IRAM_DATA),
        .o_cpu_stall    (IRAM_STALL),
        .i_cpu_flush    (clear),
        .i_cpu_ben      (4'd0),

        .o_ram_addr     (o_iram_addr),
        .o_ram_rd_en    (o_iram_rd_en),     
        .o_ram_wr_en    (),
        .o_ram_ben      (),
        .o_ram_data     (),
        .i_ram_data     (i_iram_data),
        .i_ram_stall    (i_iram_stall)
);



`endif


// Ignored by synthesis.
initial
begin
        `ifndef SIM
                `ifdef FORCE_I_RAND_CACHEABLE
                        $display("*E: Bad config.vh setting for synthesis...");
                        $finish;
                `endif

                `ifdef FORCE_D_RAND_CACHEABLE
                        $display("*E: Bad config.vh setting for synthesis...");
                        $finish;
                `endif
        `endif
end

endmodule
