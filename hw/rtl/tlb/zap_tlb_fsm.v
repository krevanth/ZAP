// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_tlb_fsm.v
// HDL          : Verilog-2001
// Module       : zap_tlb_fsm
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// An automatic page fetching system.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high.
// Clock        : Core clock.
// Depends      : --
// ----------------------------------------------------------------------------

`default_nettype none

`include "zap_defines.vh"

module zap_tlb_fsm #(

// Pass from top.
parameter LPAGE_TLB_ENTRIES   = 8,
parameter SPAGE_TLB_ENTRIES   = 8,
parameter SECTION_TLB_ENTRIES = 8

)(

/* Clock and Reset */
input   wire                    i_clk,
input   wire                    i_reset,

/* From CP15 */
input   wire                    i_mmu_en,
input   wire   [31:0]           i_baddr,

/* From cache FSM */
input   wire   [31:0]           i_address,

/* From TLB check unit */
input   wire                    i_walk,
input   wire    [7:0]           i_fsr,
input   wire    [31:0]          i_far,
input   wire                    i_cacheable,
input   wire    [31:0]          i_phy_addr,

/* To main cache FSM */
output reg    [7:0]             o_fsr,
output  reg   [31:0]            o_far,
output  reg                     o_fault,
output  reg   [31:0]            o_phy_addr,
output  reg                     o_cacheable,
output  reg                     o_busy,

/* To TLBs */
output reg      [`SECTION_TLB_WDT-1:0] o_setlb_wdata,
output reg                      o_setlb_wen,
output reg      [`SPAGE_TLB_WDT-1:0] o_sptlb_wdata,
output reg                      o_sptlb_wen,
output  reg     [`LPAGE_TLB_WDT-1:0] o_lptlb_wdata,
output  reg                     o_lptlb_wen,

/* Wishbone signals NXT */
output  wire                    o_wb_cyc_nxt,
output  wire                    o_wb_stb_nxt,
output  wire    [31:0]          o_wb_adr_nxt,

/* Wishbone Signals */
output wire                     o_wb_cyc,
output wire                     o_wb_stb,
output wire                     o_wb_wen,
output wire [3:0]               o_wb_sel, o_wb_sel_nxt,
output wire [31:0]              o_wb_adr,
input  wire [31:0]              i_wb_dat,
input  wire                     i_wb_ack,

// Unused.
output wire o_unused_ok

);

`include "zap_localparams.vh"
`include "zap_defines.vh"
`include "zap_functions.vh"

// ----------------------------------------------------------------------------

/* States */
localparam IDLE                 = 0; /* Idle State */
localparam FETCH_L1_DESC        = 1; /* Fetch L1 descriptor */
localparam FETCH_L2_DESC        = 2; /* Fetch L2 descriptor */
localparam REFRESH_CYCLE        = 3; /* Refresh TLBs and cache */

localparam NUMBER_OF_STATES     = 4; 

// ----------------------------------------------------------------------------

reg [3:0] dff_ff, dff_nxt;                              /* Scratchpad register */
reg [$clog2(NUMBER_OF_STATES)-1:0] state_ff, state_nxt; /* State register */

/* Wishbone related */
reg        wb_stb_nxt, wb_stb_ff;
reg        wb_cyc_nxt, wb_cyc_ff;
reg [31:0] wb_adr_nxt, wb_adr_ff;

// ----------------------------------------------------------------------------

/* Tie output flops to ports. */
assign o_wb_cyc         = wb_cyc_ff;
assign o_wb_stb         = wb_stb_ff;
assign o_wb_adr         = wb_adr_ff;

assign o_wb_cyc_nxt     = wb_cyc_nxt;
assign o_wb_stb_nxt     = wb_stb_nxt;
assign o_wb_adr_nxt     = wb_adr_nxt;

reg [3:0] wb_sel_nxt, wb_sel_ff;

/* Tied PORTS */
assign o_wb_wen = 1'd0;
assign o_wb_sel = wb_sel_ff;
assign o_wb_sel_nxt = wb_sel_nxt;

assign o_unused_ok = 0 || i_baddr[13:0];

/* Combinational logic */
always @*
begin: blk1

        o_fsr           = 0;
        o_far           = 0;
        o_fault         = 0;
        o_busy          = 0;
        o_phy_addr      = i_phy_addr;
        o_cacheable     = i_cacheable;
        o_setlb_wen     = 0;
        o_lptlb_wen     = 0;
        o_sptlb_wen     = 0;
        o_setlb_wdata  = 0;
        o_sptlb_wdata   = 0;
        o_lptlb_wdata   = 0;

        /* Kill wishbone access unless overridden */
        wb_stb_nxt      = 0;
        wb_cyc_nxt      = 0;
        wb_adr_nxt      = 0;
	     wb_sel_nxt	   = 0;

        dff_nxt         = dff_ff;
        state_nxt       = state_ff;

        case ( state_ff )
        IDLE:
        begin
                if ( i_mmu_en )
                begin
                        if ( i_walk )
                        begin
                                o_busy = 1'd1;

                                /*
                                 * We need to page walk to get the page table.
                                 * Call for access to L1 level page table.
                                 */
                                tsk_prpr_wb_rd({i_baddr[`VA__TRANSLATION_BASE], 
                                           i_address[`VA__TABLE_INDEX], 2'd0});

                                state_nxt = FETCH_L1_DESC;
                        end
                        else if ( i_fsr[3:0] != 4'b0000 ) /* Access Violation. */
                        begin
                                o_fault = 1'd1;
                                o_busy  = 1'd0;
                                o_fsr   = i_fsr;
                                o_far   = i_far;
                        end
                end
        end

        FETCH_L1_DESC:
        begin
                /*
                 * What we would have fetched is the L1 descriptor.
                 * Examine it.
                 */

                o_busy = 1'd1;

                if ( i_wb_ack ) /* Wait for ACK. */
                begin
                        case ( i_wb_dat[`ID] )

                        SECTION_ID:
                        begin
                                /*
                                 * It is a section itself so there is no need
                                 * for another fetch. Simply reload the TLB
                                 * and we are good.
                                 */  

                                o_setlb_wen       = 1'd1;
                                o_setlb_wdata     = {i_address[`VA__SECTION_TAG], 
                                                     i_wb_dat};
                                state_nxt       = REFRESH_CYCLE; 
                        end

                        PAGE_ID:
                        begin
                                /*
                                 * Page ID requires that DAC from current
                                 * descriptor is remembered because when we
                                 * reload the TLB, it would be useful. Anyway,
                                 * we need to initiate another access.
                                 */      
                                dff_nxt         = i_wb_dat[`L1_PAGE__DAC_SEL];       
                                state_nxt       = FETCH_L2_DESC;

                                tsk_prpr_wb_rd({i_wb_dat[`L1_PAGE__PTBR], 
                                                  i_address[`VA__L2_TABLE_INDEX], 2'd0});
                        end               

                        default: /* Generate section translation fault. Fault Class II */
                        begin
                                o_fsr        = FSR_SECTION_TRANSLATION_FAULT;
                                o_fsr        = {i_wb_dat[`L1_SECTION__DAC_SEL], o_fsr[3:0]};
                                o_far        = i_address;
                                o_fault      = 1'd1;
                                o_busy       = 1'd0;
                                state_nxt    = IDLE;
                        end
 
                        endcase
                end
                else tsk_hold_wb_access;
        end

        FETCH_L2_DESC:
        begin
                o_busy = 1'd1;

                if ( i_wb_ack )
                begin
                        case ( i_wb_dat[`ID] )
                        SPAGE_ID:
                        begin
                                /* Update TLB */
                                o_sptlb_wen   = 1'd1;

                                o_sptlb_wdata = { i_wb_dat[`VA__SPAGE_TAG],
                                                  dff_ff[3:0],  /* DAC Selector from L1 */
                                                  i_wb_dat };    

                                state_nxt   = REFRESH_CYCLE;
                        end

                        LPAGE_ID:
                        begin
                                /* Update TLB */
                                o_lptlb_wen   = 1'd1;

                                /* DAC is inserted in between to save bits */
                                o_lptlb_wdata = {i_wb_dat[`VA__LPAGE_TAG],
                                               i_wb_dat};
                                o_lptlb_wdata[`LPAGE_TLB__DAC_SEL] = dff_ff[3:0];

                                state_nxt   = REFRESH_CYCLE;
                        end

                        default: /* Fault Class II */
                        begin
                                o_busy    = 1'd0;
                                o_fault   = 1'd1;
                                o_fsr     = FSR_PAGE_TRANSLATION_FAULT;
                                o_fsr     = {i_wb_dat[`L1_PAGE__DAC_SEL], o_fsr[3:0]};
                                o_far     = i_address;
                                state_nxt = IDLE;
                        end
                        endcase
                end
                else tsk_hold_wb_access;
        end

        REFRESH_CYCLE:
        begin
                o_busy    = 1'd1;
                state_nxt = IDLE;
        end

        endcase
end

// ----------------------------------------------------------------------------

// Clocked Logic.
always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                 state_ff        <=      IDLE;
                 wb_stb_ff       <=      0;
                 wb_cyc_ff       <=      0;
		 wb_adr_ff	 <=      0;	
		 wb_sel_ff	 <=	 0;
        end
        else
        begin
                state_ff        <=      state_nxt;
                wb_stb_ff       <=      wb_stb_nxt;
                wb_cyc_ff       <=      wb_cyc_nxt;
	        wb_adr_ff	<=	wb_adr_nxt;
                dff_ff          <=      dff_nxt;
	        wb_sel_ff	<=	wb_sel_nxt;
        end
end

// ----------------------------------------------------------------------------

task tsk_hold_wb_access;
begin
        wb_stb_nxt = wb_stb_ff;
        wb_cyc_nxt = wb_cyc_ff;
        wb_adr_nxt = wb_adr_ff;
        wb_sel_nxt = wb_sel_ff;
end
endtask

task tsk_prpr_wb_rd ( input [31:0] adr );
begin
        wb_stb_nxt = 1'd1;
        wb_cyc_nxt = 1'd1;
        wb_adr_nxt = adr;
	wb_sel_nxt[3:0] = 4'b1111;
end
endtask

endmodule // zap_tlb_fsm.v
