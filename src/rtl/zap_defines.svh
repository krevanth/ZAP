//
// (C)2016-2024 Revanth Kamaraj (krevanth)
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

`ifndef _ZAP_DEFINES_VH_
`define _ZAP_DEFINES_VH_

`define ZAP_BASE                    19:16   // Base address extend.
`define ZAP_DP_RA                   19:16   // ALU source. DDI0100E rn.
`define ZAP_SRCDEST                 15:12   // Data src/dest register MEMOPS.
`define ZAP_DP_RD                   15:12   // Destination source.
`define ZAP_DP_RB                   3:0     // Shift source. DDI0100E refers to this as rm.

// Generic defines.
`define ZAP_DESC_ID               1:0  // Determine type of descriptor.

// Virtual Address Breakup
`define ZAP_VA__TABLE_INDEX       31:20
`define ZAP_VA__L2_TABLE_INDEX    19:12
`define ZAP_VA__4K_PAGE_INDEX     11:0
`define ZAP_VA__64K_PAGE_INDEX    15:0
`define ZAP_VA__1K_PAGE_INDEX     9:0
`define ZAP_VA__1M_SECTION_INDEX  19:0

`define ZAP_VA__TRANSLATION_BASE  31:14

`define ZAP_VA__SECTION_INDEX   20+$clog2(SECTION_TLB_ENTRIES)-1:20
`define ZAP_VA__LPAGE_INDEX     16+$clog2(LPAGE_TLB_ENTRIES)-1:16
`define ZAP_VA__SPAGE_INDEX     12+$clog2(SPAGE_TLB_ENTRIES)-1:12
`define ZAP_VA__FPAGE_INDEX     10+$clog2(FPAGE_TLB_ENTRIES)-1:10

`define ZAP_VA__SPAGE_TAG       31:12+$clog2(SPAGE_TLB_ENTRIES)
`define ZAP_VA__LPAGE_TAG       31:16+$clog2(LPAGE_TLB_ENTRIES)
`define ZAP_VA__SECTION_TAG     31:20+$clog2(SECTION_TLB_ENTRIES)
`define ZAP_VA__FPAGE_TAG       31:10+$clog2(FPAGE_TLB_ENTRIES)

`define ZAP_VA__SPAGE_AP_SEL    11:10
`define ZAP_VA__LPAGE_AP_SEL    15:14

// L1 Section Descriptior Breakup
`define ZAP_L1_SECTION__BASE      31:20
`define ZAP_L1_SECTION__DAC_SEL   8:5
`define ZAP_L1_SECTION__AP        11:10
`define ZAP_L1_SECTION__CB        3:2

// L1 Page Descriptor Breakup
`define ZAP_L1_PAGE__PTBR    31:10
`define ZAP_L1_PAGE__DAC_SEL 8:5

// L1 fine page descriptor breakup
`define ZAP_L1_FINE__PTBR    31:10
`define ZAP_L1_FINE__DAC_SEL 8:5

// L2 Page Small Descriptor Breakup
`define ZAP_L2_SPAGE__BASE   31:12
`define ZAP_L2_SPAGE__AP     11:4
`define ZAP_L2_SPAGE__CB     3:2

// L2 Large Page Descriptor Breakup
`define ZAP_L2_LPAGE__BASE   31:16
`define ZAP_L2_LPAGE__AP     11:4
`define ZAP_L2_LPAGE__CB     3:2

// L2 Fine Page Descriptor Breakup
`define ZAP_L2_FPAGE__BASE   31:10
`define ZAP_L2_FPAGE__AP     5:4
`define ZAP_L2_FPAGE__CB     3:2

// Section TLB Structure - 1:0 is undefined.
`define ZAP_SECTION_TLB__TAG     32+(32-$clog2(SECTION_TLB_ENTRIES)-20)-1:32
`define ZAP_SECTION_TLB__BASE    31:20
`define ZAP_SECTION_TLB__AP      11:10
`define ZAP_SECTION_TLB__DAC_SEL 8:5
`define ZAP_SECTION_TLB__CB      3:2

// Large page TLB Structure - 1:0 is undefined
`define ZAP_LPAGE_TLB__TAG       32+(32-$clog2(LPAGE_TLB_ENTRIES)-16)-1:32
`define ZAP_LPAGE_TLB__BASE      31:16
`define ZAP_LPAGE_TLB__DAC_SEL   15:12
`define ZAP_LPAGE_TLB__AP        11:4
`define ZAP_LPAGE_TLB__CB        3:2

// Small page TLB Structure - 1:0 is undefined
`define ZAP_SPAGE_TLB__TAG       36+(32-$clog2(SPAGE_TLB_ENTRIES)-12)-1:36
`define ZAP_SPAGE_TLB__BASE      35:16
`define ZAP_SPAGE_TLB__DAC_SEL   15:12
`define ZAP_SPAGE_TLB__AP        11:4
`define ZAP_SPAGE_TLB__CB        3:2

// Fine page TLB Structure - 1:0 is undefined
`define ZAP_FPAGE_TLB__TAG        32+(32-$clog2(FPAGE_TLB_ENTRIES)-10)-1:32
`define ZAP_FPAGE_TLB__BASE       31:10
`define ZAP_FPAGE_TLB__DAC_SEL    9:6
`define ZAP_FPAGE_TLB__AP         5:4
`define ZAP_FPAGE_TLB__CB         3:2

// Cache tag width. Tag consists of the tag and the physical address. valid and dirty are stored as flops.
`define ZAP_VA__CACHE_INDEX        $clog2(CACHE_LINE)+$clog2(CACHE_SIZE/CACHE_LINE)-1:$clog2(CACHE_LINE)
`define ZAP_VA__CACHE_TAG          31 : $clog2(CACHE_LINE)+$clog2(CACHE_SIZE/CACHE_LINE)
`define ZAP_CACHE_TAG__TAG         (31 - $clog2(CACHE_LINE) - $clog2(CACHE_SIZE/CACHE_LINE) + 1) -1   : 0
`define ZAP_CACHE_TAG__PA          31 - $clog2(CACHE_LINE) + (31 - $clog2(CACHE_LINE) - $clog2(CACHE_SIZE/CACHE_LINE) + 1) : 31 - $clog2(CACHE_LINE) - $clog2(CACHE_SIZE/CACHE_LINE) + 1
`define ZAP_CACHE_TAG_WDT          31 - $clog2(CACHE_LINE) + (31 - $clog2(CACHE_LINE) - $clog2(CACHE_SIZE/CACHE_LINE) + 1) + 1

// TLB widths.
`define ZAP_SECTION_TLB_WDT       (32 + (32-$clog2(SECTION_TLB_ENTRIES)-20))
`define ZAP_LPAGE_TLB_WDT         (32 + (32-$clog2(LPAGE_TLB_ENTRIES)-16))
`define ZAP_SPAGE_TLB_WDT         (36 + (32-$clog2(SPAGE_TLB_ENTRIES)-12))
`define ZAP_FPAGE_TLB_WDT         (32 + (32-$clog2(FPAGE_TLB_ENTRIES)-10))

// Misc.
`define ZAP_DEFAULT_XX            XX = 'X

// Common decoding macros.

// Process Immediate Decoding

`define zap_process_immediate(X) \
begin \
        logic [11:0] xinstruction; \
\
        xinstruction = X; \
\
        o_shift_length[31:0]    = {27'd0, xinstruction[11:8], 1'd0}; \
        o_shift_length[32]      = IMMED_EN; \
\
        o_shift_source[31:0]    = {24'd0, xinstruction[7:0]}; \
        o_shift_source[32]      = IMMED_EN; \
\
        o_shift_operation       = RORI; \
\
        if ( o_shift_length[31:0] == 0 && o_shift_length[32] == IMMED_EN ) \
        begin \
                o_shift_operation    = {1'd0, LSL}; \
\
                o_shift_length[31:0] = '0; \
                o_shift_length[32]   = IMMED_EN; \
\
                o_shift_source[31:0] = {24'd0, xinstruction[7:0]}; \
                o_shift_source[32]   = IMMED_EN; \
        end \
end

//
// The shifter source is a register but the
// amount to shift is in the instruction itself.
//
// ROR #0 = RRC, ASR #0 = ASR #32, LSL #0 = LSL #0, LSR #0 = LSR #32
// ROR #n = ROR_1 #n ( n > 0 )
//

`define zap_process_instruction_specified_shift(X) \
begin \
        logic [32:0] xinstruction; \
        xinstruction = X; \
        o_shift_length          = {28'd0, xinstruction[11:7]}; \
        o_shift_length[32]      = IMMED_EN; \
        o_shift_source          = {28'd0, xinstruction[ZAP_DP_RB_EXTEND],xinstruction[`ZAP_DP_RB]}; \
        o_shift_source[32]      = INDEX_EN; \
        o_shift_operation       = {1'd0, xinstruction[6:5]}; \
\
        case ( o_shift_operation[1:0] ) \
                LSR: if ( o_shift_length[31:0] == 32'd0 ) o_shift_length[31:0] = 32; \
                ASR: if ( o_shift_length[31:0] == 32'd0 ) o_shift_length[31:0] = 32; \
                ROR: \
                begin \
                        if ( o_shift_length[31:0] == 32'd0 ) \
                        begin \
                                o_shift_operation    = RRC; \
                        end \
                        else \
                        begin \
                                o_shift_operation    = ROR_1; \
                        end \
                end \
                default:; \
        endcase \
\
        o_shift_length[32] = IMMED_EN; \
end

// First branch is jump instruction basically.
`define zap_pc_shelve(X) \
begin \
        new_pc = X; \
\
        if (!i_code_stall ) \
        begin \
                pc_nxt_tmp    = {1'd1, new_pc}; \
                pc_del_nxt    = {1'd0, pc_ff[31:0]}; \
                pc_del2_nxt   = {1'd0, pc_del_ff[31:0]}; \
                pc_del3_nxt   = {1'd0, pc_del2_ff[31:0]}; \
                shelve_nxt    = 1'd0; \
        end \
        else \
        begin \
                shelve_nxt    = 1'd1; \
                pc_shelve_nxt = new_pc; \
                pc_nxt_tmp    = pc_ff; \
                pc_del_nxt    = pc_del_ff; \
                pc_del2_nxt   = pc_del2_ff; \
                pc_del3_nxt   = pc_del3_ff; \
        end \
end

// Mask IRQ and go to mode 32.
`define zap_chmod \
begin \
        o_clear_from_writeback  = 1'd1; \
        cpsr_nxt[I]             = 1'd1; \
        cpsr_nxt[T]             = 1'd0; \
end

// Allow hit under miss. At end, write to tag and also write out physical
// address. In i_rd, i_wr, we check read or write coherent conditions.
`define zap_hit_under_miss \
begin \
        rhit = 1'd0; \
        whit = 1'd0; \
\
        if (!i_busy && !i_fault && (i_rd || i_wr) && !i_cache_en && i_cacheable \
           && cache_cmp && i_cache_tag_valid) \
        begin \
                if ( i_rd ) \
                begin \
                        rhit    = 1'd1; \
                        o_ack   = 1'd1; \
\
                        if ( i_address == address && wr ) \
                        begin \
                                if(i_ben[0])   o_dat[7:0] = din[7:0]; \
                                if(i_ben[1])  o_dat[15:8] = din[15:8]; \
                                if(i_ben[2]) o_dat[23:16] = din[23:16]; \
                                if(i_ben[3]) o_dat[31:24] = din[31:24]; \
                        end \
                end \
                else if ( i_wr ) \
                begin \
                        o_ack        = 1'd1; \
                        whit         = 1'd1; \
\
                        o_cache_line = {(CACHE_LINE/4){i_din}}; \
\
                        o_cache_line_ben  = ben_comp ( \
                                i_address[$clog2(CACHE_LINE)-1:2], \
                                i_ben ); \
\
                        o_cache_tag_wr_en                = 1'd1; \
                        o_cache_tag[`ZAP_CACHE_TAG__TAG] = i_address[`ZAP_VA__CACHE_TAG]; \
                        o_cache_tag_dirty                = 1'd1; \
                        o_cache_tag[`ZAP_CACHE_TAG__PA]  = i_phy_addr[31 : \
                                                           $clog2(CACHE_LINE)]; \
                        o_address                        = i_address; \
                end \
        end \
end

// Task to generate Wishbone read signals.
`define zap_wb_prpr_read(Address,cti) \
begin \
        o_wb_cyc_nxt = 1'd1; \
        o_wb_stb_nxt = 1'd1; \
        o_wb_wen_nxt = 1'd0; \
        o_wb_sel_nxt = 4'b1111; \
        o_wb_adr_nxt = Address; \
        o_wb_cti_nxt = cti; \
        o_wb_dat_nxt = 0; \
end

// Disables Wishbone
`define zap_kill_access \
begin \
        o_wb_cyc_nxt = 0; \
        o_wb_stb_nxt = 0; \
        o_wb_wen_nxt = 0; \
        o_wb_adr_nxt = 0; \
        o_wb_dat_nxt = 0; \
        o_wb_sel_nxt = 0; \
        o_wb_cti_nxt = CTI_EOB; \
end

`endif

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
