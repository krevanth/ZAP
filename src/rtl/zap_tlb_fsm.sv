//
// (C) 2016-2022 Revanth Kamaraj (krevanth)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//
// An automatic page fetching system.
//

`include "zap_defines.svh"

module zap_tlb_fsm #(

parameter bit [31:0] LPAGE_TLB_ENTRIES   = 32'd8,
parameter bit [31:0] SPAGE_TLB_ENTRIES   = 32'd8,
parameter bit [31:0] SECTION_TLB_ENTRIES = 32'd8,
parameter bit [31:0] FPAGE_TLB_ENTRIES   = 32'd8

)(

// ----------------------------------------------------------------------------
// Clock and Reset
// ----------------------------------------------------------------------------

input   logic                    i_clk,
input   logic                    i_reset,

// ----------------------------------------------------------------------------
// MMU configuration
// ----------------------------------------------------------------------------

input   logic                    i_mmu_en,
input   logic   [31:0]           i_baddr,

// ----------------------------------------------------------------------------
// From cache FSM.
// ----------------------------------------------------------------------------

input   logic   [31:0]           i_address,
input   logic                    i_idle,

// ----------------------------------------------------------------------------
// From TLB check unit.
// ----------------------------------------------------------------------------

input   logic                    i_walk,
input   logic    [7:0]           i_fsr,
input   logic    [31:0]          i_far,
input   logic                    i_cacheable,
input   logic    [31:0]          i_phy_addr,

// ----------------------------------------------------------------------------
// To cache FSM
// ----------------------------------------------------------------------------

output logic    [7:0]             o_fsr,
output  logic   [31:0]            o_far,
output  logic                     o_fault,
output  logic   [31:0]            o_phy_addr,
output  logic                     o_cacheable,
output  logic                     o_busy,

// ----------------------------------------------------------------------------
// To TLBs
// ----------------------------------------------------------------------------

output logic      [`ZAP_SECTION_TLB_WDT-1:0]  o_setlb_wdata,
output logic                                  o_setlb_wen,
output logic      [`ZAP_SPAGE_TLB_WDT-1:0]    o_sptlb_wdata,
output logic                                  o_sptlb_wen,
output  logic     [`ZAP_LPAGE_TLB_WDT-1:0]    o_lptlb_wdata,
output  logic                                 o_lptlb_wen,
output  logic     [`ZAP_FPAGE_TLB_WDT-1:0]    o_fptlb_wdata,
output  logic                                 o_fptlb_wen,
output logic      [31:0]                      o_address,

// ----------------------------------------------------------------------------
// Wishbone B3 Interface
// ----------------------------------------------------------------------------

output  logic                    o_wb_cyc_nxt,
output  logic                    o_wb_stb_nxt,
output  logic    [31:0]          o_wb_adr_nxt,
output  logic    [3:0]           o_wb_sel_nxt,
output logic                     o_wb_cyc,
output logic                     o_wb_stb,
output logic                     o_wb_wen,
output logic [3:0]               o_wb_sel,
output logic [31:0]              o_wb_adr,
input  logic [31:0]              i_wb_dat,
input  logic                     i_wb_ack

);

`include "zap_localparams.svh"
`include "zap_defines.svh"

// ----------------------------------------------------------------------------

localparam IDLE                 = 0; // Idle State
localparam PRE_FETCH_L1_DESC_0  = 1; // Trigger fetch
localparam FETCH_L1_DESC        = 2; // Fetch L1 descriptor
localparam FETCH_L2_DESC        = 3; // Fetch L2 descriptor
localparam FETCH_L1_DESC_0      = 4;
localparam FETCH_L2_DESC_0      = 5;
localparam NUMBER_OF_STATES     = 6;

// ----------------------------------------------------------------------------

logic [3:0]  dac_ff, dac_nxt;                              // Scratchpad register
logic [$clog2(NUMBER_OF_STATES)-1:0] state_ff, state_nxt; // State register
logic        wb_stb_nxt, wb_stb_ff;
logic        wb_cyc_nxt, wb_cyc_ff;
logic [31:0] wb_adr_nxt, wb_adr_ff;
logic [31:0] address;
logic [3:0]  wb_sel_nxt, wb_sel_ff;
logic [31:0] dff, dnxt; // Wishbone memory buffer.
logic unused;

// ----------------------------------------------------------------------------

assign o_wb_cyc         = wb_cyc_ff;
assign o_wb_stb         = wb_stb_ff;
assign o_wb_adr         = wb_adr_ff;
assign o_wb_cyc_nxt     = wb_cyc_nxt;
assign o_wb_stb_nxt     = wb_stb_nxt;
assign o_wb_adr_nxt     = wb_adr_nxt;
assign o_wb_wen         = 1'd0;
assign o_wb_sel         = wb_sel_ff;
assign o_wb_sel_nxt     = wb_sel_nxt;
assign o_address        = address;
assign unused           = |{i_baddr[13:0]};

always_ff @ ( posedge i_clk )
begin
        if ( state_ff == IDLE )
                address <= i_address;
end

always_comb
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
        o_setlb_wdata   = 0;
        o_sptlb_wdata   = 0;
        o_lptlb_wdata   = 0;
        o_fptlb_wdata   = 0;
        o_fptlb_wen     = 0;
        wb_stb_nxt      = 0;
        wb_cyc_nxt      = 0;
        wb_adr_nxt      = 0;
        wb_sel_nxt      = 0;
        dac_nxt         = dac_ff;
        state_nxt       = state_ff;
        dnxt            = dff;

        case ( state_ff )
        IDLE:
        begin
                if ( i_mmu_en && i_idle )
                begin
                        if ( i_walk ) /* Prepare to access the PTEs. */
                        begin
                                o_busy    = 1'd1;
                                state_nxt = PRE_FETCH_L1_DESC_0;
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

        PRE_FETCH_L1_DESC_0:
        begin
                /* Connect this to the next state. */
                o_busy    = 1'd1;
                state_nxt = FETCH_L1_DESC_0;

                /*
                 * We need to page walk to get the page table.
                 * Call for access to L1 level page table.
                 */
                tsk_prpr_wb_rd({i_baddr[`ZAP_VA__TRANSLATION_BASE],
                                address[`ZAP_VA__TABLE_INDEX], 2'd0});
        end

        FETCH_L1_DESC_0:
        begin
                o_busy = 1;

                if ( i_wb_ack )
                begin
                        dnxt = i_wb_dat;
                        state_nxt = FETCH_L1_DESC;
                end
                else
                begin
                        tsk_hold_wb_access ();
                end
        end

        FETCH_L1_DESC:
        begin
                /*
                 * What we would have fetched is the L1 descriptor.
                 * Examine it. dff holds the L1 descriptor.
                 */

                o_busy = 1'd1;

                case ( dff[`ZAP_DESC_ID] )

                SECTION_ID, 2'b00:
                begin
                        /*
                         * It is a section itself so there is no need
                         * for another fetch. Simply reload the TLB
                         * and we are good.
                         */
                        o_setlb_wen       = 1'd1;
                        o_setlb_wdata     = {address[`ZAP_VA__SECTION_TAG],
                                             dff};
                        state_nxt         = IDLE;

                end

                PAGE_ID:
                begin
                        /*
                         * Page ID requires that DAC from current
                         * descriptor is remembered because when we
                         * reload the TLB, it would be useful. Anyway,
                         * we need to initiate another access.
                         */

                        // dac register holds the dac sel for future use.
                        dac_nxt         = dff[`ZAP_L1_PAGE__DAC_SEL];
                        state_nxt       = FETCH_L2_DESC_0;

                        tsk_prpr_wb_rd({dff[`ZAP_L1_PAGE__PTBR],
                                          address[`ZAP_VA__L2_TABLE_INDEX], 2'd0});
                end

                FINE_ID:
                begin
                        //  Page ID requires DAC from current descriptor.
                        dac_nxt         = dff[`ZAP_L1_PAGE__DAC_SEL];
                        state_nxt       = FETCH_L2_DESC_0;

                        tsk_prpr_wb_rd({dff[`ZAP_L1_FINE__PTBR],
                                         address[`ZAP_VA__L2_TABLE_INDEX], 2'd0});
                end

                endcase
        end

        FETCH_L2_DESC_0:
        begin
                        o_busy = 1;

                        if ( i_wb_ack )
                        begin
                                dnxt            = i_wb_dat;
                                state_nxt       = FETCH_L2_DESC;
                        end
                        else
                        begin
                                tsk_hold_wb_access ();
                        end
        end

        FETCH_L2_DESC:
        begin
                o_busy = 1'd1;

                case ( dff[`ZAP_DESC_ID] )
                // dff holds L2 descriptor. dac_ff holds L1 descriptor DAC.

                SPAGE_ID, 2'b00:
                begin
                        // Update TLB.
                        o_sptlb_wen   = 1'd1;

                        // Define TLB fields to write.

                        o_sptlb_wdata[`ZAP_SPAGE_TLB__TAG]     = address[`ZAP_VA__SPAGE_TAG];

                        // DAC selector for L1.
                        o_sptlb_wdata[`ZAP_SPAGE_TLB__DAC_SEL] = dac_ff;
                        o_sptlb_wdata[1:0]                     = dff[1:0];
                        o_sptlb_wdata[`ZAP_SPAGE_TLB__AP]      = dff[`ZAP_L2_SPAGE__AP];
                        o_sptlb_wdata[`ZAP_SPAGE_TLB__CB]      = dff[`ZAP_L2_SPAGE__CB];
                        o_sptlb_wdata[`ZAP_SPAGE_TLB__BASE]    = dff[`ZAP_L2_SPAGE__BASE];

                        state_nxt   = IDLE;
                end

                LPAGE_ID:
                begin
                        // Update TLB.
                        o_lptlb_wen   = 1'd1;

                        // Define TLB fields to write.

                        o_lptlb_wdata[`ZAP_LPAGE_TLB__TAG]     = address[`ZAP_VA__LPAGE_TAG];

                        // DAC selector from L1.
                        o_lptlb_wdata[`ZAP_LPAGE_TLB__DAC_SEL] = dac_ff;

                        o_lptlb_wdata[`ZAP_LPAGE_TLB__AP]      = dff[`ZAP_L2_LPAGE__AP];
                        o_lptlb_wdata[`ZAP_LPAGE_TLB__CB]      = dff[`ZAP_L2_LPAGE__CB];
                        o_lptlb_wdata[`ZAP_LPAGE_TLB__BASE]    = dff[`ZAP_L2_LPAGE__BASE];

                        state_nxt   = IDLE;
                end

                FPAGE_ID:
                begin
                        // Update TLB.
                        o_fptlb_wen = 1'd1;

                        // Define TLB fields to write.

                        o_fptlb_wdata[`ZAP_FPAGE_TLB__TAG]     = address[`ZAP_VA__FPAGE_TAG];

                        // DAC selector from L1.
                        o_fptlb_wdata[`ZAP_FPAGE_TLB__DAC_SEL] = dac_ff;

                        o_fptlb_wdata[`ZAP_FPAGE_TLB__AP]      = dff[`ZAP_L2_FPAGE__AP];
                        o_fptlb_wdata[`ZAP_FPAGE_TLB__CB]      = dff[`ZAP_L2_FPAGE__CB];
                        o_fptlb_wdata[`ZAP_FPAGE_TLB__BASE]    = dff[`ZAP_L2_FPAGE__BASE];

                        state_nxt   = IDLE;
                end

                endcase
        end

        endcase
end

// Clocked Logic.
always_ff @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                 state_ff        <=      IDLE;
                 wb_stb_ff       <=      0;
                 wb_cyc_ff       <=      0;
                 wb_adr_ff       <=      0;
                 dac_ff          <=      0;
                 wb_sel_ff       <=      0;
                 dff             <=      0;
        end
        else
        begin
                state_ff        <=      state_nxt;
                wb_stb_ff       <=      wb_stb_nxt;
                wb_cyc_ff       <=      wb_cyc_nxt;
                wb_adr_ff       <=      wb_adr_nxt;
                dac_ff          <=      dac_nxt;
                wb_sel_ff       <=      wb_sel_nxt;
                dff             <=      dnxt;
        end
end

function automatic void tsk_hold_wb_access ();
begin
        wb_stb_nxt = wb_stb_ff;
        wb_cyc_nxt = wb_cyc_ff;
        wb_adr_nxt = wb_adr_ff;
        wb_sel_nxt = wb_sel_ff;
end
endfunction

function automatic void tsk_prpr_wb_rd ( input [31:0] adr );
begin
        wb_stb_nxt      = 1'd1;
        wb_cyc_nxt      = 1'd1;
        wb_adr_nxt      = adr;
        wb_sel_nxt[3:0] = 4'b1111;
end
endfunction

endmodule

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
