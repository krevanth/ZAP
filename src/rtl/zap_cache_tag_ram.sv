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
// This is the tag RAM and data RAM unit. The tag RAM holds both the
// virtual tag and the physical address. The physical address is used to
// avoid translation during clean operations. The cache data RAM is also
// present in this unit. This unit has a dedicated memory interface
// because it can perform global clean and flush by itself without
// depending on the cache controller.
//

`include "zap_defines.svh"

module zap_cache_tag_ram #(

parameter logic [31:0] CACHE_SIZE = 32'd1024, // Bytes.
parameter logic [31:0] CACHE_LINE = 32'd8

)(

input   logic                            i_clk,
input   logic                            i_reset,
input   logic    [31:0]                  i_address_nxt,
input   logic    [31:0]                  i_address,
input   logic                            i_hold,
input   logic                            i_cache_en,
input   logic    [CACHE_LINE*8-1:0]      i_cache_line,
input   logic    [CACHE_LINE-1:0]        i_cache_line_ben,
output  logic    [CACHE_LINE*8-1:0]      o_cache_line,
input   logic                            i_cache_tag_wr_en,
input   logic    [`ZAP_CACHE_TAG_WDT-1:0]i_cache_tag,
input   logic                            i_cache_tag_dirty,

output  logic    [`ZAP_CACHE_TAG_WDT-1:0] o_cache_tag,
output  logic                             o_cache_tag_valid,
output  logic                             o_cache_tag_dirty,
input   logic                             i_cache_clean_req,

/* verilator lint_off UNOPTFLAT */
output  logic                             o_cache_clean_done,
/* verilator lint_on UNOPTFLAT */

input   logic                             i_cache_inv_req,

/* verilator lint_off UNOPTFLAT */
output  logic                             o_cache_inv_done,
/* verilator lint_on UNOPTFLAT */

//
// Cache clean operations occur through these ports.
// Bus access ports.
//
output  logic                             o_wb_cyc_ff, o_wb_cyc_nxt,
output  logic                             o_wb_stb_ff, o_wb_stb_nxt,
output  logic     [31:0]                  o_wb_adr_ff, o_wb_adr_nxt,
output  logic     [31:0]                  o_wb_dat_ff, o_wb_dat_nxt,
output  logic     [3:0]                   o_wb_sel_ff, o_wb_sel_nxt,
output  logic                             o_wb_wen_ff, o_wb_wen_nxt,
output  logic     [2:0]                   o_wb_cti_ff, o_wb_cti_nxt,
input logic      [31:0]                   i_wb_dat,
input logic                               i_wb_ack

);

// ----------------------------------------------------------------------------

`include "zap_localparams.svh"

localparam [31:0] NUMBER_OF_DIRTY_BLOCKS = ((CACHE_SIZE/CACHE_LINE)/16); // Keep cache size > 16 bytes.

// States.
typedef enum logic [6:0] {
        IDLE                           = 7'b000_0001,
        CACHE_CLEAN_GET_ADDRESS        = 7'b000_0010,
        CACHE_CLEAN_WRITE_PRE_PRE_WAIT = 7'b000_0100,
        CACHE_CLEAN_WRITE_PRE_WAIT     = 7'b000_1000,
        CACHE_CLEAN_WRITE_PRE          = 7'b001_0000,
        CACHE_CLEAN_WRITE              = 7'b010_0000,
        CACHE_INV                      = 7'b100_0000,
        `ZAP_DEFAULT_XX
} t_state;

// Padding widths.
localparam [31:0] BLK_CTR_PAD = 32 - $clog2(NUMBER_OF_DIRTY_BLOCKS) - 1;
localparam [31:0] ADR_CTR_PAD = 32 - $clog2(CACHE_LINE/4) - 1;
localparam [31:0] ZERO_WDT    = $clog2(CACHE_LINE/4) + 1;

// ----------------------------------------------------------------------------

logic [(CACHE_SIZE/CACHE_LINE)-1:0]        dirty;
logic [(CACHE_SIZE/CACHE_LINE)-1:0]        valid;
logic [`ZAP_CACHE_TAG_WDT-1:0]             tag_ram_wr_data;
logic                                      tag_ram_wr_en;
logic [$clog2(CACHE_SIZE/CACHE_LINE)-1:0]  tag_ram_wr_addr;
logic [$clog2(CACHE_SIZE/CACHE_LINE)-1:0]  tag_ram_rd_addr, tag_ram_rd_addr_del,
                                           tag_ram_rd_addr_del2, tag_ram_rd_addr_ff,
                                           tag_ram_rd_addr_nxt;
logic                                      tag_ram_clear;
logic                                      tag_ram_clean;
t_state                                    state_ff, state_nxt;
logic [$clog2(NUMBER_OF_DIRTY_BLOCKS):0]   blk_ctr_ff, blk_ctr_nxt;
logic [$clog2(CACHE_LINE/4):0]             adr_ctr_ff, adr_ctr_nxt;
logic                                      cache_tag_dirty, cache_tag_dirty_del;
logic                                      cache_tag_valid, cache_tag_valid_del;
logic                                      cache_clean_done_nxt, cache_clean_done_ff;

logic                                      unused;
logic [BLK_CTR_PAD-1:0]                    dummy;
logic [CACHE_LINE*8-32-1:0]                line_dummy;
logic                                      cache_unused0;
logic                                      cache_unused1;
logic [CACHE_LINE*8-1:0]                   w_dummy;
logic [`ZAP_CACHE_TAG_WDT-1:0]             w_dummy_1;

assign cache_unused0 = |{i_address[31: $clog2(CACHE_LINE)+$clog2(CACHE_SIZE/CACHE_LINE)], i_address[$clog2(CACHE_LINE)-1:0]};
assign cache_unused1 = |{i_address_nxt[31: $clog2(CACHE_LINE)+$clog2(CACHE_SIZE/CACHE_LINE)], i_address_nxt[$clog2(CACHE_LINE)-1:0]};
assign        unused = |{dummy, line_dummy, i_wb_dat, cache_unused0, cache_unused1, w_dummy, w_dummy_1};

zap_ram_simple_ben #(.WIDTH(CACHE_LINE*8), .DEPTH(CACHE_SIZE/CACHE_LINE)) u_zap_ram_simple_data_ram (
        .i_clk(i_clk),
        .i_clken(!i_hold),

        .i_wr_en(i_cache_line_ben),
        .i_wr_data(i_cache_line),

        .o_rd_data_pre(w_dummy),
        .o_rd_data(o_cache_line),

        .i_wr_addr(tag_ram_wr_addr),
        .i_rd_addr(tag_ram_rd_addr)
);

zap_ram_simple #(.WIDTH(`ZAP_CACHE_TAG_WDT), .DEPTH(CACHE_SIZE/CACHE_LINE)) u_zap_ram_simple_tag (
        .i_clk(i_clk),
        .i_clken(!i_hold),

        .i_wr_en(tag_ram_wr_en),
        .i_wr_data(tag_ram_wr_data),

        .o_rd_data_pre(w_dummy_1),
        .o_rd_data(o_cache_tag),

        .i_wr_addr(tag_ram_wr_addr),
        .i_rd_addr(tag_ram_rd_addr)
);

// ----------------------------------------------------------------------------

always_ff @ ( posedge i_clk )
begin
        if ( !i_hold )
        begin
                tag_ram_rd_addr_del  <= tag_ram_rd_addr;
                tag_ram_rd_addr_del2 <= tag_ram_rd_addr_del;
        end
end

always_ff @ ( posedge i_clk )
begin
        if ( i_reset )
        begin
                o_cache_tag_dirty     <= '0;
                cache_tag_dirty_del   <= '0;
                cache_tag_dirty       <= '0;
                dirty                 <= '0;
        end
        else if ( !i_hold || tag_ram_clean )
        begin
                o_cache_tag_dirty  <= tag_ram_rd_addr_del2 == tag_ram_wr_addr && tag_ram_wr_en ? i_cache_tag_dirty : cache_tag_dirty_del;
                cache_tag_dirty_del<= tag_ram_rd_addr_del  == tag_ram_wr_addr && tag_ram_wr_en ? i_cache_tag_dirty : cache_tag_dirty;
                cache_tag_dirty    <= tag_ram_rd_addr      == tag_ram_wr_addr && tag_ram_wr_en ? i_cache_tag_dirty : dirty [ tag_ram_rd_addr ];

                if ( tag_ram_wr_en )
                begin
                        dirty [ tag_ram_wr_addr ]   <= i_cache_tag_dirty;
                end
                else if ( tag_ram_clean )
                begin
                        dirty[tag_ram_rd_addr] <= 1'd0;
                end
        end
end

always_ff @ ( posedge i_clk )
begin
        if ( i_reset )
        begin
                o_cache_tag_valid   <= '0;
                cache_tag_valid_del <= '0;
                cache_tag_valid     <= '0;
                valid               <= '0;
        end
        else if ( !i_hold || tag_ram_clear )
        begin
                o_cache_tag_valid   <= tag_ram_rd_addr_del2 == tag_ram_wr_addr && tag_ram_wr_en ? 1'd1 : cache_tag_valid_del;
                cache_tag_valid_del <= tag_ram_rd_addr_del  == tag_ram_wr_addr && tag_ram_wr_en ? 1'd1 : cache_tag_valid;
                cache_tag_valid     <= tag_ram_rd_addr      == tag_ram_wr_addr && tag_ram_wr_en ? 1'd1 : valid [ tag_ram_rd_addr ];

                if ( tag_ram_clear || !i_cache_en )
                begin
                        valid <= '0;
                end
                else if ( tag_ram_wr_en )
                begin
                        valid [ tag_ram_wr_addr ]   <= 1'd1;
                end
        end
end

// ----------------------------------------------------------------------------

always_ff @ ( posedge i_clk )
begin
        if ( i_reset )
        begin
                o_wb_cyc_ff             <= 0;
                o_wb_stb_ff             <= 0;
                o_wb_wen_ff             <= 'x;
                o_wb_sel_ff             <= 'x;
                o_wb_dat_ff             <= 'x;
                o_wb_cti_ff             <= CTI_EOB;
                o_wb_adr_ff             <= 'x;
                adr_ctr_ff              <= 0;
                blk_ctr_ff              <= 0;
                cache_clean_done_ff     <= 0;
                tag_ram_rd_addr_ff      <= 0;

                // STATE
                state_ff                <= IDLE;
        end
        else
        begin
                o_wb_cyc_ff             <= o_wb_cyc_nxt;
                o_wb_stb_ff             <= o_wb_stb_nxt;
                o_wb_wen_ff             <= o_wb_wen_nxt;
                o_wb_sel_ff             <= o_wb_sel_nxt;
                o_wb_dat_ff             <= o_wb_dat_nxt;
                o_wb_cti_ff             <= o_wb_cti_nxt;
                o_wb_adr_ff             <= o_wb_adr_nxt;
                adr_ctr_ff              <= adr_ctr_nxt;
                blk_ctr_ff              <= blk_ctr_nxt;
                cache_clean_done_ff     <= cache_clean_done_nxt;
                tag_ram_rd_addr_ff      <= tag_ram_rd_addr_nxt;

                // STATE
                state_ff                <= state_nxt;
        end
end

// ----------------------------------------------------------------------------

assign tag_ram_rd_addr = state_ff == IDLE ?
                         i_address_nxt [`ZAP_VA__CACHE_INDEX] :
                         tag_ram_rd_addr_ff;

always_comb
begin:blk1

        // --------------------------------------------------
        // Local Vars Section
        // --------------------------------------------------

        logic [31:0] shamt, data, pa;

        // --------------------------------------------------
        // Defaults Value Section
        // (Done to avoid combo loops/incomplete assignments).
        // --------------------------------------------------

        line_dummy              = {(CACHE_LINE*8-32){1'd0}};
        shamt                   = '0;
        data                    = '0;
        pa                      = '0;
        dummy                   = '0;
        state_nxt               = state_ff;
        tag_ram_rd_addr_nxt     = get_tag_ram_rd_addr (blk_ctr_ff, dirty);
        tag_ram_wr_addr         = i_address[`ZAP_VA__CACHE_INDEX];
        tag_ram_wr_en           = 0;
        tag_ram_clear           = 0;
        tag_ram_clean           = 0;
        adr_ctr_nxt             = adr_ctr_ff;
        blk_ctr_nxt             = blk_ctr_ff;
        cache_clean_done_nxt    = cache_clean_done_ff;
        o_cache_inv_done        = 0;
        o_wb_cyc_nxt            = o_wb_cyc_ff;
        o_wb_stb_nxt            = o_wb_stb_ff;
        o_wb_adr_nxt            = o_wb_adr_ff;
        o_wb_dat_nxt            = o_wb_dat_ff;
        o_wb_sel_nxt            = o_wb_sel_ff;
        o_wb_wen_nxt            = o_wb_wen_ff;
        o_wb_cti_nxt            = o_wb_cti_ff;
        tag_ram_wr_data         = 0;
        o_cache_clean_done      = cache_clean_done_ff;

        // --------------------------------------------------
        // FSM Code Section
        // --------------------------------------------------

        case ( state_ff )

        IDLE:
        begin
                `zap_kill_access;

                tag_ram_wr_addr = i_address     [`ZAP_VA__CACHE_INDEX];
                tag_ram_wr_en   = i_cache_tag_wr_en;
                tag_ram_wr_data = i_cache_tag;

                cache_clean_done_nxt = 1'd0;

                if ( i_cache_clean_req && !cache_clean_done_ff )
                begin
                        tag_ram_wr_en = 0;
                        blk_ctr_nxt   = 0;

                        state_nxt     = CACHE_CLEAN_GET_ADDRESS;
                end
                else if ( i_cache_inv_req && !cache_clean_done_ff )
                begin
                        tag_ram_wr_en = 0;
                        state_nxt     = CACHE_INV;
                end
        end

        CACHE_CLEAN_GET_ADDRESS:
        begin
                if ( &baggage(dirty, blk_ctr_ff) )
                begin
                        // Move to next block.
                        {dummy, blk_ctr_nxt} = {dummy, blk_ctr_ff} + 32'd1;

                        if ( {{BLK_CTR_PAD{1'd0}}, blk_ctr_ff} == NUMBER_OF_DIRTY_BLOCKS - 1 )
                        begin
                                state_nxt            = IDLE;
                                cache_clean_done_nxt = 1'd1;
                        end
                end
                else
                begin
                        // Go to state.
                        state_nxt = CACHE_CLEAN_WRITE_PRE_PRE_WAIT;
                end

                adr_ctr_nxt     = 0; // Initialize address counter.
        end

        CACHE_CLEAN_WRITE_PRE_PRE_WAIT:
        begin
                state_nxt = CACHE_CLEAN_WRITE_PRE_WAIT;
        end

        CACHE_CLEAN_WRITE_PRE_WAIT: // Since RAM is pipelined.
        begin
                state_nxt       = CACHE_CLEAN_WRITE_PRE;
        end

        CACHE_CLEAN_WRITE_PRE: // Since RAM is pipelined.
        begin
                state_nxt       = CACHE_CLEAN_WRITE;
        end

        CACHE_CLEAN_WRITE:
        begin

                adr_ctr_nxt = adr_ctr_ff + ((i_wb_ack && o_wb_stb_ff) ?
                              {{(ZERO_WDT-1){1'd0}}, 1'd1} :
                              {ZERO_WDT{1'd0}});

                if ( {{ADR_CTR_PAD{1'd0}}, adr_ctr_nxt} > ((CACHE_LINE/4) - 1) )
                begin
                        // Remove dirty marking. BUG FIX.
                        tag_ram_clean = 1;

                        // Kill access.
                        `zap_kill_access;

                        // Go to new state.
                        state_nxt = CACHE_CLEAN_GET_ADDRESS;
                end
                else
                begin
                        shamt = {{(ADR_CTR_PAD-5){1'd0}}, adr_ctr_nxt, 5'd0};
                        {line_dummy, data}  = o_cache_line >> shamt;

                        pa    = {o_cache_tag[`ZAP_CACHE_TAG__PA],
                                {$clog2(CACHE_LINE){1'd0}}};

                        o_wb_cyc_nxt = 1'd1;
                        o_wb_stb_nxt = 1'd1;
                        o_wb_wen_nxt = 1'd1;

                        // Perform a Wishbone write using Physical Address.
                        // Uses WB burst protocol for higher efficency.
                        o_wb_dat_nxt = data;
                        o_wb_adr_nxt = pa + ({{(ADR_CTR_PAD-2){1'd0}}, adr_ctr_nxt, 2'd0});
                        o_wb_cti_nxt = ({{ADR_CTR_PAD{1'd0}},adr_ctr_nxt} != (CACHE_LINE/4)-1) ?
                        CTI_BURST : CTI_EOB;
                        o_wb_sel_nxt = 4'b1111;
                end
        end

        CACHE_INV:
        begin
                tag_ram_clear    = 1'd1;
                state_nxt        = IDLE;
                o_cache_inv_done = 1'd1;
        end

        // ------------------------------------------------------
        // Default Section (To simplify synthesis)
        // ------------------------------------------------------

        default: // Cannot happen.
        begin
                // Assigning X here can simplify synthesis.

                line_dummy              = 'x;
                shamt                   = 'x;
                data                    = 'x;
                pa                      = 'x;
                dummy                   = 'x;
                state_nxt               = XX;
                tag_ram_rd_addr_nxt     = 'x;
                tag_ram_wr_addr         = 'x;
                tag_ram_wr_en           = 'x;
                tag_ram_clear           = 'x;
                tag_ram_clean           = 'x;
                adr_ctr_nxt             = 'x;
                blk_ctr_nxt             = 'x;
                cache_clean_done_nxt    = 'x;
                o_cache_inv_done        = 'x;
                o_wb_cyc_nxt            = 'x;
                o_wb_stb_nxt            = 'x;
                o_wb_adr_nxt            = 'x;
                o_wb_dat_nxt            = 'x;
                o_wb_sel_nxt            = 'x;
                o_wb_wen_nxt            = 'x;
                o_wb_cti_nxt            = 'x;
                tag_ram_wr_data         = 'x;
                o_cache_clean_done      = 'x;
        end
        endcase
end:blk1

// -----------------------------------------------------------------------------

// Priority encoder. Bit 0 is prioritized.
function automatic  [4:0] pri_enc ( input [15:0] in );
                casez ( in )
                16'b???????????????1: return 5'd0;
                16'b??????????????10: return 5'd1;
                16'b?????????????100: return 5'd2;
                16'b????????????1000: return 5'd3;
                16'b???????????10000: return 5'd4;
                16'b??????????100000: return 5'd5;
                16'b?????????1000000: return 5'd6;
                16'b????????10000000: return 5'd7;
                16'b???????100000000: return 5'd8;
                16'b??????1000000000: return 5'd9;
                16'b?????10000000000: return 5'd10;
                16'b????100000000000: return 5'd11;
                16'b???1000000000000: return 5'd12;
                16'b??10000000000000: return 5'd13;
                16'b?100000000000000: return 5'd14;
                16'b1000000000000000: return 5'd15;
                default             : return 5'b11111;
                endcase
endfunction : pri_enc

// -----------------------------------------------------------------------------

function automatic [$clog2(CACHE_SIZE/CACHE_LINE)-1:0] get_tag_ram_rd_addr (
input [$clog2(NUMBER_OF_DIRTY_BLOCKS):0]   blk_ctr,
input [CACHE_SIZE/CACHE_LINE-1:0]          Dirty
);

        localparam [31:0] W = $clog2(NUMBER_OF_DIRTY_BLOCKS) + 5;

        logic [15:0]                               dirty_new;
        logic [4:0]                                enc;
        logic [W-1:0]                              shamt;
        logic [31:0]                               sum;
        logic [(CACHE_SIZE/CACHE_LINE) - 16 - 1:0] unused1;
        logic                                      unused0;

        sum                 = 32'd0;
        shamt               = {blk_ctr, 4'd0};
        {unused1,dirty_new} = Dirty >> shamt;
        enc                 = pri_enc(dirty_new[15:0]);
        sum[W:0]            = {1'd0, shamt[W-1:0]} + {1'd0, {{(W-5){1'd0}}, enc}};
        unused0             = |{sum[31:$clog2(CACHE_SIZE/CACHE_LINE)]};
        get_tag_ram_rd_addr = sum[$clog2(CACHE_SIZE/CACHE_LINE)-1:0];

endfunction : get_tag_ram_rd_addr

// ----------------------------------------------------------------------------

function automatic [4:0] baggage (
        input [CACHE_SIZE/CACHE_LINE-1:0]               Dirty,
        input [$clog2(NUMBER_OF_DIRTY_BLOCKS):0]        blk_ctr
);
        logic [CACHE_SIZE/CACHE_LINE-1:0] w_dirty;
        logic [15:0] val;
        logic [(CACHE_SIZE/CACHE_LINE) - 16 - 1:0] unused1;

        w_dirty        = Dirty >> {blk_ctr, 4'd0};
        {unused1, val} = w_dirty;

        return pri_enc(val);

endfunction : baggage

endmodule : zap_cache_tag_ram

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------

