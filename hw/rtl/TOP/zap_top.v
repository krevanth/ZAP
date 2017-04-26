// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_top.v
// HDL          : Verilog-2001
// Module       : zap_top
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// This is the top module of the ZAP processor. It contains instances of the
// processor core and the memory management units. I and D Wishbone interfaces
// are provided. 
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Asynchronous active low reset
// Clock        : Core clock
// Depends      : --
// ----------------------------------------------------------------------------

`default_nettype none

module zap_top #(

// Enable cache and MMU.
parameter [0:0]         CACHE_MMU_ENABLE        = 1'd1,
parameter               BP_ENTRIES              = 1024, // Predictor depth.
parameter               FIFO_DEPTH              = 4,    // FIFO depth.

// ----------------------------------
// Data MMU/Cache configuration.
// ----------------------------------
parameter [31:0] DATA_SECTION_TLB_ENTRIES =  32'd4,    // Section TLB entries.
parameter [31:0] DATA_LPAGE_TLB_ENTRIES   =  32'd8,    // Large page TLB entries.
parameter [31:0] DATA_SPAGE_TLB_ENTRIES   =  32'd16,   // Small page TLB entries.
parameter [31:0] DATA_CACHE_SIZE          =  32'd1024, // Cache size in bytes.

// ----------------------------------
// Code MMU/Cache configuration.
// ----------------------------------
parameter [31:0] CODE_SECTION_TLB_ENTRIES =  32'd4,    // Section TLB entries.
parameter [31:0] CODE_LPAGE_TLB_ENTRIES   =  32'd8,    // Large page TLB entries.
parameter [31:0] CODE_SPAGE_TLB_ENTRIES   =  32'd16,   // Small page TLB entries.
parameter [31:0] CODE_CACHE_SIZE          =  32'd1024  // Cache size in bytes.

)(
        // Clock.
        input   wire            i_clk,

        // Multipump clock for the multi-ported register file.
        input   wire            i_clk_multipump,

        // Reset. 
        // This reset is passed through a reset
        // synchronizer so it need not be clean.
        // Active high and synchronous.
        input   wire            i_reset,

        // Interrupts. 
        // Both of them are active high and level trigerred.
        input   wire            i_irq,
        input   wire            i_fiq,

        // ---------------------
        // Code interface.
        // ---------------------
        output  wire            o_instr_wb_cyc,
        output  wire            o_instr_wb_stb,
        output  wire [31:0]     o_instr_wb_adr,
        output  wire            o_instr_wb_we,
        input   wire            i_instr_wb_err,
        input   wire [31:0]     i_instr_wb_dat, // Wishbone data port.
        input   wire            i_instr_wb_ack,
        output  wire [3:0]      o_instr_wb_sel,
        output  wire [2:0]      o_instr_wb_cti,

        // ---------------------
        // Data interface.
        // ---------------------
        output  wire            o_data_wb_cyc,
        output  wire            o_data_wb_stb,
        output  wire [31:0]     o_data_wb_adr,
        output  wire            o_data_wb_we,
        input   wire            i_data_wb_err,
        input   wire [31:0]     i_data_wb_dat, // Wishbone instr port.
        output wire  [31:0]     o_data_wb_dat,
        input   wire            i_data_wb_ack,
        output  wire [3:0]      o_data_wb_sel,
        output wire [2:0]       o_data_wb_cti

);

localparam COMPRESSED_EN = 1'd1;

`include "zap_defines.vh"
`include "zap_localparams.vh"
`include "zap_functions.vh"

generate
begin
if ( CACHE_MMU_ENABLE == 1'd0 ) begin:cmmu_dis // Raw processor core without cache+MMU.

assign o_data_wb_cti = 0;
assign o_instr_wb_cti = 0;

// -------------------
// Processor core.
// -------------------
zap_core #(
        .BP_ENTRIES(BP_ENTRIES),
        .FIFO_DEPTH(FIFO_DEPTH)
) u_zap_core
(
.i_clk                  (i_clk),
.i_clk_multipump        (i_clk_multipump),
.i_reset                (i_reset),


// Code related.
.o_instr_wb_adr         (o_instr_wb_adr),
.o_instr_wb_cyc         (o_instr_wb_cyc),
.o_instr_wb_stb         (o_instr_wb_stb),
.o_instr_wb_we          (o_instr_wb_we),
.o_instr_wb_sel         (o_instr_wb_sel),

// Code related.
.i_instr_wb_dat_cache   (128'd0),
.i_instr_wb_dat_nocache (i_instr_wb_dat),
.i_instr_src            (1'd0),

.i_instr_wb_ack         (i_instr_wb_ack),
.i_instr_wb_err         (i_instr_wb_err),

// Data related.
.o_data_wb_we           (o_data_wb_we),
.o_data_wb_adr          (o_data_wb_adr),
.o_data_wb_sel          (o_data_wb_sel),
.o_data_wb_dat          (o_data_wb_dat),
.o_data_wb_cyc          (o_data_wb_cyc),
.o_data_wb_stb          (o_data_wb_stb),

// Data related.
.i_data_wb_ack          (i_data_wb_ack),
.i_data_wb_err          (i_data_wb_err),
.i_data_wb_dat_cache    (128'd0),
.i_data_wb_dat_uncache  (i_data_wb_dat),
.i_data_src             (1'd0),

// Interrupts.
.i_fiq                  (i_fiq),
.i_irq                  (i_irq),

// These ports are irrelevant as no MMU, cache is present.
.o_mem_translate        (),
.i_fsr                  (32'd0),
.i_far                  (32'd0),
.o_dac                  (),
.o_baddr                (),
.o_mmu_en               (),
.o_sr                   (),
.o_dcache_inv           (),
.o_icache_inv           (),
.o_dcache_clean         (),
.o_icache_clean         (),
.o_dtlb_inv             (),
.o_itlb_inv             (),
.i_dcache_inv_done      (1'd1),
.i_icache_inv_done      (1'd1),
.i_dcache_clean_done    (1'd1),
.i_icache_clean_done    (1'd1),
.o_dcache_en            (),
.o_icache_en            (),

// Cache read enables.
.o_instr_cache_rd_en    (),
.o_data_cache_rd_en     (),

// Combo Outputs - UNUSED.
.o_clear_from_alu       (),
.o_stall_from_shifter   (),
.o_stall_from_issue     (),
.o_stall_from_decode    (),
.o_clear_from_decode    (),
.o_clear_from_writeback (),

// Data IF nxt.
.o_address_nxt          (), // Data addr nxt. Used to drive address of data tag RAM.
.o_data_wb_we_nxt       (),
.o_data_wb_cyc_nxt      (),
.o_data_wb_stb_nxt      (), 
.o_data_wb_dat_nxt      (),
.o_data_wb_sel_nxt      (),

// Code access prpr.
.o_pc_nxt               (), // PC addr nxt. Drives read address of code tag RAM.
.o_instr_wb_stb_nxt     (),

.o_cpsr                 ()  

);

end
else // Cache and MMU enabled.
begin: cmmu_en

wire cpu_mmu_en;
wire [31:0] cpu_cpsr;
wire cpu_mem_translate;

wire [31:0] cpu_daddr, cpu_daddr_nxt;
wire [31:0] cpu_iaddr, cpu_iaddr_nxt;

wire [7:0] dc_fsr;
wire [31:0] dc_far;

wire cpu_dc_en, cpu_ic_en;

wire [1:0] cpu_sr;
wire [31:0] cpu_baddr, cpu_dac_reg;

wire cpu_dc_inv, cpu_ic_inv;
wire cpu_dc_clean, cpu_ic_clean;

wire dc_inv_done, ic_inv_done, dc_clean_done, ic_clean_done;

wire cpu_dtlb_inv, cpu_itlb_inv;

wire data_ack, data_err, instr_ack, instr_err;

wire [31:0] ic_data, dc_data, cpu_dc_dat;
wire cpu_instr_stb;
wire cpu_dc_we, cpu_dc_stb;
wire [3:0] cpu_dc_sel;

zap_core #(
        .BP_ENTRIES(BP_ENTRIES),
        .FIFO_DEPTH(FIFO_DEPTH)
) u_zap_core
(
.i_clk                  (i_clk),
.i_clk_multipump        (i_clk_multipump),
.i_reset                (i_reset),


// Code related.
.o_instr_wb_adr         (cpu_iaddr),
.o_instr_wb_cyc         (),
.o_instr_wb_stb         (cpu_instr_stb),
.o_instr_wb_we          (),
.o_instr_wb_sel         (),

// Code related.
.i_instr_wb_dat_cache   (128'd0),
.i_instr_wb_dat_nocache (ic_data),
.i_instr_src            (1'd0),

.i_instr_wb_ack         (instr_ack),
.i_instr_wb_err         (instr_err),

// Data related.
.o_data_wb_we           (cpu_dc_we),
.o_data_wb_adr          (cpu_daddr),
.o_data_wb_sel          (cpu_dc_sel),
.o_data_wb_dat          (cpu_dc_dat),
.o_data_wb_cyc          (),
.o_data_wb_stb          (cpu_dc_stb),

// Data related.
.i_data_wb_ack          (data_ack),
.i_data_wb_err          (data_err),

.i_data_wb_dat_cache    (128'd0),
.i_data_wb_dat_uncache  (dc_data),
.i_data_src             (1'd0),

// Interrupts.
.i_fiq                  (i_fiq),
.i_irq                  (i_irq),

// MMU/cache is present.
.o_mem_translate        (cpu_mem_translate),
.i_fsr                  ({24'd0,dc_fsr}),
.i_far                  (dc_far),
.o_dac                  (cpu_dac_reg),
.o_baddr                (cpu_baddr),
.o_mmu_en               (cpu_mmu_en),
.o_sr                   (cpu_sr),
.o_dcache_inv           (cpu_dc_inv),
.o_icache_inv           (cpu_ic_inv),
.o_dcache_clean         (cpu_dc_clean),
.o_icache_clean         (cpu_ic_clean),
.o_dtlb_inv             (cpu_dtlb_inv),
.o_itlb_inv             (cpu_itlb_inv),
.i_dcache_inv_done      (dc_inv_done),
.i_icache_inv_done      (ic_inv_done),
.i_dcache_clean_done    (dc_clean_done),
.i_icache_clean_done    (ic_clean_done),
.o_dcache_en            (cpu_dc_en),
.o_icache_en            (cpu_ic_en),

// Cache read enables.
.o_instr_cache_rd_en    (),
.o_data_cache_rd_en     (),

// Combo Outputs - UNUSED.
.o_clear_from_alu       (),
.o_stall_from_shifter   (),
.o_stall_from_issue     (),
.o_stall_from_decode    (),
.o_clear_from_decode    (),
.o_clear_from_writeback (),

// Data IF nxt.
.o_address_nxt          (cpu_daddr_nxt), // Data addr nxt. Used to drive address of data tag RAM.
.o_data_wb_we_nxt       (),
.o_data_wb_cyc_nxt      (),
.o_data_wb_stb_nxt      (), 
.o_data_wb_dat_nxt      (),
.o_data_wb_sel_nxt      (),

// Code access prpr.
.o_pc_nxt               (cpu_iaddr_nxt), // PC addr nxt. Drives read address of code tag RAM.
.o_instr_wb_stb_nxt     (),

.o_cpsr                 (cpu_cpsr)  

);

zap_cache #(.CACHE_SIZE(DATA_CACHE_SIZE), 
.SPAGE_TLB_ENTRIES(DATA_SPAGE_TLB_ENTRIES), 
.LPAGE_TLB_ENTRIES(DATA_LPAGE_TLB_ENTRIES), 
.SECTION_TLB_ENTRIES(DATA_SECTION_TLB_ENTRIES)) 
u_data_cache (
.i_clk          (i_clk),
.i_reset        (i_reset),
.i_address      (cpu_daddr),
.i_address_nxt  (cpu_daddr_nxt),

.i_rd           (!cpu_dc_we && cpu_dc_stb),
.i_wr           (cpu_dc_we),
.i_ben          (cpu_dc_sel),
.i_dat          (cpu_dc_dat),
.o_dat          (dc_data),
.o_ack          (data_ack),
.o_err          (data_err),

.o_fsr          (dc_fsr),
.o_far          (dc_far),
.i_mmu_en       (cpu_mmu_en),
.i_cache_en     (cpu_dc_en),
.i_cache_inv_req        (cpu_dc_inv),
.i_cache_clean_req      (cpu_dc_clean),
.o_cache_inv_done       (dc_inv_done),
.o_cache_clean_done     (dc_clean_done),
.i_cpsr         (cpu_mem_translate ? USR : cpu_cpsr),
.i_sr           (cpu_sr),
.i_baddr        (cpu_baddr),
.i_dac_reg      (cpu_dac_reg),
.i_tlb_inv      (cpu_dtlb_inv),
.o_wb_stb       (o_data_wb_stb),
.o_wb_cyc       (o_data_wb_cyc),
.o_wb_wen       (o_data_wb_we),
.o_wb_sel       (o_data_wb_sel),
.o_wb_dat       (o_data_wb_dat),
.o_wb_adr       (o_data_wb_adr),
.o_wb_cti       (o_data_wb_cti),
.i_wb_dat       (i_data_wb_dat),
.i_wb_ack       (i_data_wb_ack)
);

zap_cache #(
.CACHE_SIZE(CODE_CACHE_SIZE), 
.SPAGE_TLB_ENTRIES(CODE_SPAGE_TLB_ENTRIES), 
.LPAGE_TLB_ENTRIES(CODE_LPAGE_TLB_ENTRIES), 
.SECTION_TLB_ENTRIES(CODE_SECTION_TLB_ENTRIES)) 
u_code_cache (
.i_clk              (i_clk),
.i_reset            (i_reset),
.i_address          (cpu_iaddr),
.i_address_nxt      (cpu_iaddr_nxt),

.i_rd              (cpu_instr_stb),
.i_wr              (1'd0),
.i_ben             (4'b1111),
.i_dat             (32'd0),
.o_dat             (ic_data),
.o_ack             (instr_ack),
.o_err             (instr_err),

.o_fsr(), // UNCONNO.
.o_far(), // UNCONNO.
.i_mmu_en          (cpu_mmu_en),
.i_cache_en        (cpu_ic_en),
.i_cache_inv_req   (cpu_ic_inv),
.i_cache_clean_req (cpu_ic_clean),
.o_cache_inv_done  (ic_inv_done),
.o_cache_clean_done(ic_clean_done),
.i_cpsr         (cpu_mem_translate ? USR : cpu_cpsr),
.i_sr           (cpu_sr),
.i_baddr        (cpu_baddr),
.i_dac_reg      (cpu_dac_reg),
.i_tlb_inv      (cpu_itlb_inv),
.o_wb_stb       (o_instr_wb_stb),
.o_wb_cyc       (o_instr_wb_cyc),
.o_wb_wen       (o_instr_wb_we),
.o_wb_sel       (o_instr_wb_sel),
.o_wb_dat       (),
.o_wb_adr       (o_instr_wb_adr),
.o_wb_cti       (o_instr_wb_cti),
.i_wb_dat       (i_instr_wb_dat),
.i_wb_ack       (i_instr_wb_ack)
);

end
end
endgenerate

endmodule // zap_top.v
