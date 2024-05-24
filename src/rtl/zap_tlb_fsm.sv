//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
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

parameter logic [31:0] LPAGE_TLB_ENTRIES   = 32'd8,
parameter logic [31:0] SPAGE_TLB_ENTRIES   = 32'd8,
parameter logic [31:0] SECTION_TLB_ENTRIES = 32'd8,
parameter logic [31:0] FPAGE_TLB_ENTRIES   = 32'd8

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
input  logic                     i_wb_ack,
input  logic                     i_wb_err

);

`include "zap_localparams.svh"
`include "zap_defines.svh"

// ----------------------------------------------------------------------------

localparam [2:0]  IDLE                 = 0; // Idle State
localparam [2:0]  PRE_FETCH_L1_DESC_0  = 1; // Trigger fetch
localparam [2:0]  FETCH_L1_DESC        = 2; // Fetch L1 descriptor
localparam [2:0]  FETCH_L2_DESC        = 3; // Fetch L2 descriptor
localparam [2:0]  FETCH_L1_DESC_0      = 4;
localparam [2:0]  FETCH_L2_DESC_0      = 5;
localparam [31:0] NUMBER_OF_STATES     = 6;

// ----------------------------------------------------------------------------

logic [3:0]                          dac_ff, dac_nxt;
logic [NUMBER_OF_STATES-1:0]         state_ff, state_nxt;
logic                                wb_stb_nxt, wb_stb_ff;
logic                                wb_cyc_nxt, wb_cyc_ff;
logic [31:0]                         wb_adr_nxt, wb_adr_ff;
logic [31:0]                         address;
logic [3:0]                          wb_sel_nxt, wb_sel_ff;
logic [31:0]                         dff, dnxt;
logic                                unused;
logic [31:0]                         addr0, addr1, addr2;
logic                                walk, examine_fsr;

// ----------------------------------------------------------------------------

assign addr0 = {i_baddr[`ZAP_VA__TRANSLATION_BASE],address[`ZAP_VA__TABLE_INDEX], 2'd0};
assign addr1 = {dff[`ZAP_L1_PAGE__PTBR],address[`ZAP_VA__L2_TABLE_INDEX], 2'd0};
assign addr2 = {dff[`ZAP_L1_FINE__PTBR],address[`ZAP_VA__L2_TABLE_INDEX], 2'd0};

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
begin : addr_del
        if ( state_ff[IDLE] )
        begin
                address <= i_address;
        end
end : addr_del

assign o_phy_addr = i_phy_addr;
assign o_cacheable = i_cacheable;

// Key conditions.
assign walk        = state_ff[IDLE] & i_mmu_en & i_idle &  i_walk;
assign examine_fsr = state_ff[IDLE] & i_mmu_en & i_idle & ~i_walk;

// Busy when going to walk or walking.
assign o_busy  = walk | (~state_ff[IDLE]);

// Access violation detection condition.
assign o_fault = examine_fsr & |i_fsr[3:0];

// Generate FSR and FAR on fault - else drive 0.
assign o_fsr   = o_fault ? i_fsr : 'd0;
assign o_far   = o_fault ? i_far : 'd0;

// Domain access control. Holds DAC_SEL for future use. Useful when reloading
// the TLB.
assign dac_nxt = state_ff[FETCH_L1_DESC] ? (
                    dff[`ZAP_DESC_ID] == PAGE_ID ? dff[`ZAP_L1_PAGE__DAC_SEL] :
                    dff[`ZAP_DESC_ID] == FINE_ID ? dff[`ZAP_L1_PAGE__DAC_SEL] :
                    dac_ff
                ) : dac_ff;

/////////////////////////////////
// Logic to drive ERR and DFF
// registers. The DFF register
// is a generic data register
// to hold i_wb_dat.
/////////////////////////////////

assign dnxt = (state_ff[FETCH_L2_DESC_0] | state_ff[FETCH_L1_DESC_0])
              ? ((i_wb_ack | i_wb_err)
                ? {i_wb_dat[31:2], i_wb_err ? 2'd0 : i_wb_dat[1:0]}
                : dff) : dff;

////////////////////////////
// TLB write enables.
////////////////////////////

// L1
assign o_setlb_wen = state_ff[FETCH_L1_DESC] && (dff[`ZAP_DESC_ID] inside {SECTION_ID, 2'b00});

// L2
assign o_sptlb_wen = state_ff[FETCH_L2_DESC] && (dff[`ZAP_DESC_ID] inside {SPAGE_ID, 2'b00});
assign o_lptlb_wen = state_ff[FETCH_L2_DESC] && (dff[`ZAP_DESC_ID] == LPAGE_ID);
assign o_fptlb_wen = state_ff[FETCH_L2_DESC] && (dff[`ZAP_DESC_ID] == FPAGE_ID);

//////////////////////////
// TLB WRITE DATA
//////////////////////////

// NOTE: Assigning errors to LPTLB and FPTLB is no use since those are written
// as sections/small pages.

// SETLB

assign o_setlb_wdata[31:0]                  = dff[31:0];
assign o_setlb_wdata[`ZAP_SECTION_TLB__TAG] = address[`ZAP_VA__SECTION_TAG];

// SPTLB

assign o_sptlb_wdata[`ZAP_SPAGE_TLB__TAG]     = address[`ZAP_VA__SPAGE_TAG];
assign o_sptlb_wdata[`ZAP_SPAGE_TLB__DAC_SEL] = dac_ff;
assign o_sptlb_wdata[1:0]                     = dff[1:0];
assign o_sptlb_wdata[`ZAP_SPAGE_TLB__AP]      = dff[`ZAP_L2_SPAGE__AP];
assign o_sptlb_wdata[`ZAP_SPAGE_TLB__CB]      = dff[`ZAP_L2_SPAGE__CB];
assign o_sptlb_wdata[`ZAP_SPAGE_TLB__BASE]    = dff[`ZAP_L2_SPAGE__BASE];

// LPTLB

assign o_lptlb_wdata[`ZAP_LPAGE_TLB__TAG]     = address[`ZAP_VA__LPAGE_TAG];
assign o_lptlb_wdata[`ZAP_LPAGE_TLB__DAC_SEL] = dac_ff;
assign o_lptlb_wdata[1:0]                     = dff[1:0];
assign o_lptlb_wdata[`ZAP_LPAGE_TLB__AP]      = dff[`ZAP_L2_LPAGE__AP];
assign o_lptlb_wdata[`ZAP_LPAGE_TLB__CB]      = dff[`ZAP_L2_LPAGE__CB];
assign o_lptlb_wdata[`ZAP_LPAGE_TLB__BASE]    = dff[`ZAP_L2_LPAGE__BASE];

// FPTLB

assign o_fptlb_wdata[`ZAP_FPAGE_TLB__TAG]     = address[`ZAP_VA__FPAGE_TAG];
assign o_fptlb_wdata[`ZAP_FPAGE_TLB__DAC_SEL] = dac_ff;
assign o_fptlb_wdata[1:0]                     = dff[1:0];
assign o_fptlb_wdata[`ZAP_FPAGE_TLB__AP]      = dff[`ZAP_L2_FPAGE__AP];
assign o_fptlb_wdata[`ZAP_FPAGE_TLB__CB]      = dff[`ZAP_L2_FPAGE__CB];
assign o_fptlb_wdata[`ZAP_FPAGE_TLB__BASE]    = dff[`ZAP_L2_FPAGE__BASE];

// STATE MACHINE (Next State Logic).
always_comb
begin
        case ( 1'd1 )

        state_ff[IDLE]:
        begin
                wb_stb_nxt      = 0;
                wb_cyc_nxt      = 0;
                wb_adr_nxt      = 0;
                wb_sel_nxt      = 0;

                state_nxt =
                ( i_mmu_en && i_idle && i_walk ) ? // Prepare to access PTEs.
                'd1 << PRE_FETCH_L1_DESC_0       :
                state_ff;
        end

        state_ff[PRE_FETCH_L1_DESC_0]:
        begin
                //
                // We need to page walk to get the page table.
                // Call for access to L1 level page table.
                //
                wb_stb_nxt      = 1'd1;
                wb_cyc_nxt      = 1'd1;
                wb_adr_nxt      = addr0;
                wb_sel_nxt[3:0] = 4'b1111;
                state_nxt       = 'd1 << FETCH_L1_DESC_0;
        end

        state_ff[FETCH_L1_DESC_0]:
        begin
                wb_stb_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_stb_ff;
                wb_cyc_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_cyc_ff;
                wb_adr_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_adr_ff;
                wb_sel_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_sel_ff;
                state_nxt  = (i_wb_ack|i_wb_err) ? 'd1 << FETCH_L1_DESC : state_ff;
        end

        state_ff[FETCH_L1_DESC]:
        begin
                //
                // What we would have fetched is the L1 descriptor.
                // Examine it. dff holds the L1 descriptor.
                //

                case ( dff[`ZAP_DESC_ID] )

                SECTION_ID, 2'b00:
                begin
                        //
                        // It is a section itself so there is no need
                        // for another fetch. Simply reload the TLB
                        // and we are good.
                        //
                        // Write to TLB here.
                        //

                        // No need to fetch.
                        wb_stb_nxt      = 'd0;
                        wb_cyc_nxt      = 'd0;
                        wb_adr_nxt      = 'd0;
                        wb_sel_nxt      = 'd0;
                        state_nxt       = 'd1 << IDLE;
                end

                PAGE_ID:
                begin
                        //
                        // Page ID requires that DAC from current
                        // descriptor is remembered because when we
                        // reload the TLB, it would be useful. Anyway,
                        // we need to initiate another access.
                        //

                        state_nxt       = 'd1 << FETCH_L2_DESC_0;
                        wb_stb_nxt      = 1'd1;
                        wb_cyc_nxt      = 1'd1;
                        wb_adr_nxt      = addr1;
                        wb_sel_nxt[3:0] = 4'b1111;
                end

                FINE_ID:
                begin
                        state_nxt       = 'd1 << FETCH_L2_DESC_0;
                        wb_stb_nxt      = 1'd1;
                        wb_cyc_nxt      = 1'd1;
                        wb_adr_nxt      = addr2;
                        wb_sel_nxt[3:0] = 4'b1111;
                end

                endcase
        end

        state_ff[FETCH_L2_DESC_0]:
        begin
                wb_stb_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_stb_ff;
                wb_cyc_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_cyc_ff;
                wb_adr_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_adr_ff;
                wb_sel_nxt = (i_wb_ack|i_wb_err) ? 'd0 : wb_sel_ff;
                state_nxt  = (i_wb_ack|i_wb_err) ? 'd1 << FETCH_L2_DESC : state_ff;
        end

        state_ff[FETCH_L2_DESC]:
        begin
                wb_stb_nxt = 0;
                wb_cyc_nxt = 0;
                wb_adr_nxt = 0;
                wb_sel_nxt = 0;
                state_nxt = 'd1 << IDLE;

                // Write to TLB here. See assigns.
        end

        // ---------------------------------------
        // Default Section
        // (For Better Synthesis)
        // ---------------------------------------

        default:
        begin
                wb_stb_nxt      = 'x;
                wb_cyc_nxt      = 'x;
                wb_adr_nxt      = 'x;
                wb_sel_nxt      = 'x;
                state_nxt       = 'x;
        end

        endcase
end

// Clocked Logic.
always_ff @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                 state_ff        <=      'd1 << IDLE;
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

always @ (posedge i_clk) // Assertion
begin
    if ( state_ff[FETCH_L1_DESC] )
    begin
        assert(o_setlb_wdata[19:12] == '0 || i_reset)
        else $info("Error: Section page table format incorrect. Ignoring bits 15:12.");

        assert(o_setlb_wdata[9] == '0 || i_reset)
        else $info("Error: Section page table format incorrect. Ignoring bit 9.");

        assert(o_setlb_wdata[4] == '0 || i_reset)
        else $info("Error: Section page table format incorrect. Ignoring bit 4.");
    end

    if(o_lptlb_wen)
    begin
        assert(o_lptlb_wdata[1:0] == LPAGE_ID) else $fatal(2, "Error injected to LPTLB.");
    end

    if(o_fptlb_wen)
    begin
        assert(o_fptlb_wdata[1:0] == FPAGE_ID) else $fatal(2, "Error injected to FPTLB.");
    end

    if(o_setlb_wen)
    begin
        assert(o_sptlb_wdata[1:0] inside {SPAGE_ID, 2'b00}) else
        $fatal(2, "SE TLB ID incorrect.");
    end

    if(o_sptlb_wen)
    begin
        assert(o_sptlb_wdata[1:0] inside {SECTION_ID, 2'b00}) else
        $fatal(2, "SP TLB ID incorrect.");
    end
end

endmodule

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
