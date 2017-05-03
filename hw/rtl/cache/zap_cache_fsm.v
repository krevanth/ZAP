// ----------------------------------------------------------------------------
//                            The ZAP Project
//                     (C)2016-2017, Revanth Kamaraj.     
// ----------------------------------------------------------------------------
// Filename     : zap_cache_fsm.v
// HDL          : Verilog-2001
// Module       : zap_cache_fsm
// Author       : Revanth Kamaraj
// License      : GPL v2
// ----------------------------------------------------------------------------
//                               ABSTRACT
//                               --------
// This is the core state machine for the memory subsystem. Talks to both the
// processor and the TLB controller. Cache uploads and downloads are done
// using an incrementing burst on the Wishbone bus for maximum efficiency.
// ----------------------------------------------------------------------------
//                              INFORMATION                                  
//                              ------------
// Reset method : Synchronous active high.
// Clock        : Core clock.
// Depends      : --
// ----------------------------------------------------------------------------

`default_nettype none

`include "zap_defines.vh"

module zap_cache_fsm   #(
parameter CACHE_SIZE    = 1024  // Bytes.
) /* Port List */       (

/* Clock and reset */
input   wire                      i_clk,
input   wire                      i_reset,

/* From/to processor */
input   wire    [31:0]            i_address,      
input   wire    [31:0]            i_address_nxt,
input   wire                      i_rd,
input   wire                      i_wr,
input   wire    [31:0]            i_din,
input   wire    [3:0]             i_ben, /* Valid only for writes. */
output  reg     [31:0]            o_dat,
output  reg                       o_ack,
output  reg                       o_err,
output  reg     [7:0]             o_fsr,
output  reg     [31:0]            o_far,

/* From/To CP15 unit */
input   wire                      i_cache_en,
input   wire                      i_cache_inv,
input   wire                      i_cache_clean,
output  reg                       o_cache_inv_done,
output  reg                       o_cache_clean_done,

/* From/to cache. */
input   wire    [127:0]           i_cache_line,

input   wire                      i_cache_tag_dirty,
input   wire  [`CACHE_TAG_WDT-1:0] i_cache_tag, // Tag 
input   wire                      i_cache_tag_valid,

output  reg   [`CACHE_TAG_WDT-1:0] o_cache_tag,
output  reg                       o_cache_tag_dirty,
output  reg                       o_cache_tag_wr_en,

output  reg     [127:0]           o_cache_line,
output  reg     [15:0]            o_cache_line_ben,    /* Write + Byte enable */

output  reg                       o_cache_clean_req,
input   wire                      i_cache_clean_done,

output  reg                       o_cache_inv_req,
input   wire                      i_cache_inv_done,

/* From/to TLB unit */
input   wire    [31:0]            i_phy_addr,
input   wire    [7:0]             i_fsr,
input   wire    [31:0]            i_far,
input   wire                      i_fault,
input   wire                      i_cacheable,
input   wire                      i_busy,

/* Memory access ports, both NXT and FF. Usually you'll be connecting NXT ports */
output  reg             o_wb_cyc_ff, o_wb_cyc_nxt,
output  reg             o_wb_stb_ff, o_wb_stb_nxt,
output  reg     [31:0]  o_wb_adr_ff, o_wb_adr_nxt,
output  reg     [31:0]  o_wb_dat_ff, o_wb_dat_nxt,
output  reg     [3:0]   o_wb_sel_ff, o_wb_sel_nxt,
output  reg             o_wb_wen_ff, o_wb_wen_nxt,
output  reg     [2:0]   o_wb_cti_ff, o_wb_cti_nxt,/* Cycle Type Indicator - 010, 111 */
input   wire            i_wb_ack,
input   wire    [31:0]  i_wb_dat

);

`include "zap_localparams.vh"
`include "zap_defines.vh"
`include "zap_functions.vh"
`include "zap_mmu_functions.vh"

/* Signal aliases */
wire cache_cmp   = (i_cache_tag[`CACHE_TAG__TAG] == i_address[`VA__CACHE_TAG]);
wire cache_dirty = i_cache_tag_dirty;

/* States */
localparam IDLE                 = 0; /* Resting state. */
localparam UNCACHEABLE          = 1; /* Uncacheable access. */
localparam REFRESH_1            = 2; /* Cache write hit state. Unused. */
localparam CLEAN_SINGLE         = 3; /* Ultimately cleans up cache line. Parent state */
localparam FETCH_SINGLE         = 4; /* Ultimately validates cache line. Parent state */
localparam REFRESH              = 5; /* Cache refresh parent state */
localparam INVALIDATE           = 6; /* Cache invalidate parent state */
localparam CLEAN                = 7; /* Cache clean parent state */

localparam NUMBER_OF_STATES     = 8; 

/* Flops */
reg [$clog2(NUMBER_OF_STATES)-1:0] state_ff, state_nxt;
reg [31:0] buf_ff [3:0];
reg [31:0] buf_nxt[3:0];
reg cache_clean_req_nxt, cache_clean_req_ff;
reg cache_inv_req_nxt, cache_inv_req_ff;

/* Address Counter */
reg [2:0] adr_ctr_ff, adr_ctr_nxt; // Needs to take on 0,1,2,3 AND 4(nxt).

reg hit; // debug.

always @* o_cache_clean_req = cache_clean_req_ff; // Tie req flop to output.
always @* o_cache_inv_req = cache_inv_req_ff;

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                o_wb_cyc_ff <= 0;
                o_wb_stb_ff <= 0;
                o_wb_wen_ff <= 0;
                o_wb_sel_ff <= 0;
                o_wb_dat_ff <= 0;
                o_wb_cti_ff <= CTI_CLASSIC;
                o_wb_adr_ff <= 0;
                cache_clean_req_ff <= 0;
                cache_inv_req_ff <= 0;
                adr_ctr_ff <= 0;
                state_ff   <= IDLE;
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
                cache_clean_req_ff      <= cache_clean_req_nxt;
                cache_inv_req_ff        <= cache_inv_req_nxt;
                adr_ctr_ff              <= adr_ctr_nxt;
                state_ff                <= state_nxt;
                buf_ff[0]               <= buf_nxt[0];
                buf_ff[1]               <= buf_nxt[1];
                buf_ff[2]               <= buf_nxt[2];
	        buf_ff[3]		<= buf_nxt[3];
        end
end

always @*
begin
        /* Default values */
        state_nxt               = state_ff;
        adr_ctr_nxt             = adr_ctr_ff;
        o_wb_cyc_nxt            = o_wb_cyc_ff;
        o_wb_stb_nxt            = o_wb_stb_ff;
        o_wb_adr_nxt            = o_wb_adr_ff;
        o_wb_dat_nxt            = o_wb_dat_ff;
        o_wb_cti_nxt            = o_wb_cti_ff;
        o_wb_wen_nxt            = o_wb_wen_ff;
        o_wb_sel_nxt            = o_wb_sel_ff;
        cache_clean_req_nxt     = cache_clean_req_ff;
        cache_inv_req_nxt       = cache_clean_req_ff;
        o_fsr = 0;
	o_far = 0;
        o_cache_tag = 0;
        o_cache_inv_done = 0;
        o_cache_clean_done = 0;
        o_cache_tag_dirty = 0;
        o_cache_tag_wr_en = 0;
        o_cache_line = 0;
        o_cache_line_ben = 0;
        o_dat = 0;
        o_ack = 0;
        o_err = 0;
        buf_nxt[0] = buf_ff[0];
        buf_nxt[1] = buf_ff[1];
        buf_nxt[2] = buf_ff[2];       
        buf_nxt[3] = buf_ff[3];
        hit = 0;
 
        case(state_ff)

        IDLE:
        begin
                kill_access;

                if ( i_cache_inv )
                begin
                        o_ack     = 1'd0;
                        state_nxt = INVALIDATE;
                end
                else if ( i_cache_clean )
                begin
                        o_ack     = 1'd0;
                        state_nxt = CLEAN;
                end
                else if ( i_fault )
                begin
                        /* MMU access fault. */
                        o_err = 1'd1;
                        o_ack = 1'd1;
			o_fsr = i_fsr;
			o_far = i_far;
                end
                else if ( i_busy )
                begin
                        /* Wait it out */
                end
                else if ( i_rd || i_wr )
                begin
                        if ( i_cacheable && i_cache_en )
                        begin
                                case ({cache_cmp,i_cache_tag_valid})

                                2'b11: /* Cache hit */
                                begin
                                        if ( i_rd ) /* Read request. */
                                        begin  
                                                /* Accelerate performance */
                                                o_dat   = adapt_cache_data_debug(i_address[3:2], i_cache_line); 

                                                hit = 1'd1;

                                                //adapt_cache_data
                                                //( 
                                                //        i_address[3:2] , 
                                                //        i_cache_line 
                                                //);

                                                o_ack   = 1'd1;
                                        end
                                        else if ( i_wr ) /* Write request */
                                        begin
                                                state_nxt    = REFRESH_1;
                                                o_ack        = 1'd0;

                                                /* Accelerate performance */
                                                o_cache_line = 
                                                {i_din,i_din,i_din,i_din};
  
                                                o_cache_line_ben  = ben_comp ( i_address[3:2], i_ben ); 
//                                                i_ben << (i_address[3:2] << 2);

                                                /* Write to tag and also write out physical address. */
                                                o_cache_tag_wr_en               = 1'd1;
                                                o_cache_tag[`CACHE_TAG__TAG]    = i_address[`VA__CACHE_TAG]; 
                                                o_cache_tag_dirty               = 1'd1;
                                                o_cache_tag[`CACHE_TAG__PA]     = i_phy_addr >> 4;
                                                

                                        end
                                end

                                2'b01: /* Unrelated tag, possibly dirty. */
                                begin
                                        /* CPU should wait */
                                        o_ack = 1'd0;

                                        if ( cache_dirty )
                                        begin
                                                /* Set up counter */
                                                adr_ctr_nxt = 0;

                                                /* Clean a single cache line */
                                                state_nxt = CLEAN_SINGLE;
                                        end
                                        else if ( i_rd | i_wr )
                                        begin
                                                /* Set up counter */
                                                adr_ctr_nxt = 0;

                                                /* Fetch a single cache line */
                                                state_nxt = FETCH_SINGLE;
                                        end
                                end 

                                default: /* Need to generate a new tag. */
                                begin
                                                /* CPU should wait. */
                                                o_ack = 1'd0;

                                                /* Set up counter */
                                                adr_ctr_nxt = 0;

                                                /* Fetch a single cache line */
                                                state_nxt = FETCH_SINGLE;
                                end
                                endcase
                        end
                        else /* Decidedly non cacheable. */
                        begin
                                state_nxt       = UNCACHEABLE;
                                o_ack           = 1'd0; /* Wait...*/
                                o_wb_stb_nxt    = 1'd1;
                                o_wb_cyc_nxt    = 1'd1;
                                o_wb_adr_nxt    = i_phy_addr;
                                o_wb_dat_nxt    = i_din;
                                o_wb_wen_nxt    = i_wr;
                                o_wb_sel_nxt    = i_wr ? i_ben : 4'b1111;
                                o_wb_cti_nxt    = CTI_CLASSIC;
                        end                        
                end
        end

        UNCACHEABLE: /* Uncacheable reads and writes definitely go through this. */
        begin
                if ( i_wb_ack )
                begin
                        o_dat           = i_wb_dat;
                        o_ack           = 1'd1;
                        state_nxt       = IDLE;
                        kill_access;
                end
        end

        REFRESH_1: /* A single wait state is needed to handle B2B write-read */
        begin
                kill_access;
                state_nxt = REFRESH;
                o_ack     = 1'd0;
        end

        CLEAN_SINGLE: /* Clean single cache line */
        begin
                o_ack = 1'd0;

                /* Generate address */
                adr_ctr_nxt = adr_ctr_ff + (o_wb_stb_ff && i_wb_ack);

                if ( adr_ctr_nxt <= 3 )
                begin
                        /* Sync up with memory. Use PA in cache tag itself. */
                        wb_prpr_write( clean_single_d (i_cache_line, adr_ctr_nxt), 
                                      {i_cache_tag[`CACHE_TAG__PA], 4'd0} + (adr_ctr_nxt << 2), 
                                      adr_ctr_nxt != 3 ? CTI_BURST : CTI_EOB, 4'b1111);
                end
                else
                begin
                        /* Move to wait state */
                        kill_access;
                        state_nxt = REFRESH_1;                        
                        
                        /* Update tag. Remove dirty bit. */
                        o_cache_tag_wr_en                      = 1'd1; // Implicitly sets valid (redundant).
                        o_cache_tag[`CACHE_TAG__TAG]           = i_cache_tag[`VA__CACHE_TAG]; // Preserve.
                        o_cache_tag_dirty                      = 1'd0;
                        o_cache_tag[`CACHE_TAG__PA]            = i_cache_tag[`CACHE_TAG__PA]; // Preserve.
                end 
        end

        FETCH_SINGLE: /* Fetch a single cache line */
        begin
                //$display($time, "%m :: Cache in FETCH_SINGLE state...");

                o_ack = 1'd0;

                /* Generate address */
                adr_ctr_nxt = adr_ctr_ff + (o_wb_stb_ff && i_wb_ack);

                /* Write to buffer */
                buf_nxt[adr_ctr_ff] = i_wb_ack ? i_wb_dat : buf_ff[adr_ctr_ff];

                /* Manipulate buffer as needed */
                if ( i_wr )
                begin
                        buf_nxt[i_address[3:2]][7:0]   = i_ben[0] ? i_din[7:0]   : buf_nxt[i_address[3:2]][7:0];
                        buf_nxt[i_address[3:2]][15:8]  = i_ben[1] ? i_din[15:8]  : buf_nxt[i_address[3:2]][15:8];
                        buf_nxt[i_address[3:2]][23:16] = i_ben[2] ? i_din[23:16] : buf_nxt[i_address[3:2]][23:16];
                        buf_nxt[i_address[3:2]][31:24] = i_ben[3] ? i_din[31:24] : buf_nxt[i_address[3:2]][31:24];
                end

                if ( adr_ctr_nxt <= 3 )
                begin
                        //$display($time, "%m :: Address generated = %x PHY_ADDR = %x, ADDR_CTR_NXT = %x", {i_phy_addr[31:4], 4'd0} + (adr_ctr_nxt << 2), i_phy_addr, adr_ctr_nxt);

                        /* Fetch line from memory */
                        wb_prpr_read({i_phy_addr[31:4], 4'd0} + (adr_ctr_nxt << 2), 
                                     adr_ctr_nxt != 3 ? CTI_BURST : CTI_EOB);
                end
                else
                begin
                        //$display($time, "%m :: Updating cache...");

                        /* Update cache */
                        o_cache_line = {buf_nxt[3], buf_ff[2], buf_ff[1], buf_ff[0]};
                        o_cache_line_ben  = 16'b1111111111111111;

                        /* Update tag. Remove dirty and set valid */
                        o_cache_tag_wr_en                       = 1'd1; // Implicitly sets valid.
                        o_cache_tag[`CACHE_TAG__TAG]            = i_address[`VA__CACHE_TAG];
                        o_cache_tag[`CACHE_TAG__PA]             = i_phy_addr >> 4;
                        o_cache_tag_dirty                       = !i_wr ? 1'd0 : 1'd1; // BUG FIX.

                        /* Move to wait state */
                        kill_access;
                        state_nxt = REFRESH_1;
                end
        end

        REFRESH: /* One extra cycle for cache and tag to update. */
        begin
                kill_access;
                o_ack     = i_wr && cache_cmp;
                state_nxt = IDLE;
        end

        INVALIDATE: /* Invalidate the cache - Almost Single Cycle */
        begin
                cache_inv_req_nxt = 1'd1;
                cache_clean_req_nxt = 1'd0;

                if ( i_cache_inv_done )
                begin
                        cache_inv_req_nxt    = 1'd0;
                        state_nxt            = IDLE;
                        o_cache_inv_done = 1'd1;
                end
        end

        CLEAN:  /* Force cache to clean itself */
        begin
                cache_clean_req_nxt = 1'd1;
                cache_inv_req_nxt   = 1'd0;

                if ( i_cache_clean_done )
                begin
                        cache_clean_req_nxt  = 1'd0;
                        state_nxt            = IDLE;
                        o_cache_clean_done   = 1'd1;
                end
        end

        endcase
end

function [31:0] adapt_cache_data_debug 
(input [1:0] shift, input [127:0] cd);
begin: blk1
        reg [31:0] shamt;
        shamt = shift << 5;
        adapt_cache_data_debug = cd >> shamt;
end
endfunction

function [15:0] ben_comp ( input [1:0] shift, input [3:0] bv );
begin:fblk2
        reg [31:0] shamt;
        shamt = shift << 2;
        ben_comp = bv << shamt;
end
endfunction

function [31:0] clean_single_d ( input [127:0] cl, input [31:0] sh );
reg [31:0] shamt;
begin
        shamt = sh << 5;
        clean_single_d = cl >> shamt; // Select specific 32-bit.
end
endfunction

// synopsys translate_off
wire [31:0] buf0_ff, buf1_ff, buf2_ff;
assign buf0_ff = buf_ff[0];
assign buf1_ff = buf_ff[1];
assign buf2_ff = buf_ff[2];
wire [31:0] buf3_ff = buf_ff[3];
wire [31:0] buf0_nxt = buf_nxt[0];
wire [31:0] buf1_nxt = buf_nxt[1];
wire [31:0] buf2_nxt = buf_nxt[2];
wire [31:0] buf3_nxt = buf_nxt[3];

wire [31:0] dbg_addr_tag = i_address[`VA__CACHE_TAG];
wire [31:0] dbg_addr_pa  = i_phy_addr >> 4;
wire [31:0] dbg_ct_tag   = o_cache_tag[`CACHE_TAG__TAG];
wire [31:0] dbg_ct_pa    = o_cache_tag[`CACHE_TAG__PA];

// synopsys translate_on

endmodule
