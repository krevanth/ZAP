`default_nettype none

module zap_cache_tag_ram (

i_clk,
i_reset,

i_address_nxt,
i_address,

i_cache_en,

i_cache_line,
o_cache_line,

i_cache_line_ben,

i_cache_tag_wr_en,
i_cache_tag,
i_cache_tag_dirty,

o_cache_tag,
o_cache_tag_valid,
o_cache_tag_dirty,

i_cache_inv_req,
o_cache_inv_done,

i_cache_clean_req,
o_cache_clean_done,

// Cache clean operations occur through these ports.
o_wb_stb_nxt, o_wb_stb_ff,
o_wb_cyc_nxt, o_wb_cyc_ff,
o_wb_adr_nxt, o_wb_adr_ff,
o_wb_wen_nxt, o_wb_wen_ff,
o_wb_sel_nxt, o_wb_sel_ff,
o_wb_dat_nxt, o_wb_dat_ff,
o_wb_cti_nxt, o_wb_cti_ff,
i_wb_ack, i_wb_dat

);

// ----------------------------------------------------------------------------

`include "zap_localparams.vh"
`include "zap_defines.vh"
`include "zap_functions.vh"
`include "zap_mmu_functions.vh"

parameter CACHE_SIZE = 1024; // Bytes.

input   wire                            i_clk;
input   wire                            i_reset;

input   wire    [31:0]                  i_address_nxt;
input   wire    [31:0]                  i_address;

input   wire                            i_cache_en;

input   wire    [127:0]                 i_cache_line;
input   wire    [15:0]                  i_cache_line_ben;
output  reg     [127:0]                 o_cache_line;

input   wire                            i_cache_tag_wr_en;
input   wire    [`CACHE_TAG_WDT-1:0]    i_cache_tag;
input   wire                            i_cache_tag_dirty;

output  reg     [`CACHE_TAG_WDT-1:0]    o_cache_tag;
output  reg                             o_cache_tag_valid;
output  reg                             o_cache_tag_dirty;

input   wire                            i_cache_clean_req;
output  reg                             o_cache_clean_done;

input   wire                            i_cache_inv_req;
output  reg                             o_cache_inv_done;

/* Memory access ports, both NXT and FF. Usually you'll be connecting NXT ports */
output  reg                             o_wb_cyc_ff, o_wb_cyc_nxt;
output  reg                             o_wb_stb_ff, o_wb_stb_nxt;
output  reg     [31:0]                  o_wb_adr_ff, o_wb_adr_nxt;
output  reg     [31:0]                  o_wb_dat_ff, o_wb_dat_nxt;
output  reg     [3:0]                   o_wb_sel_ff, o_wb_sel_nxt;
output  reg                             o_wb_wen_ff, o_wb_wen_nxt;
output  reg     [2:0]                   o_wb_cti_ff, o_wb_cti_nxt; /* Cycle Type Indicator - 010, 111 */
input wire      [31:0]                  i_wb_dat;
input wire                              i_wb_ack;

// ----------------------------------------------------------------------------

localparam NUMBER_OF_DIRTY_BLOCKS = ((CACHE_SIZE/16)/16); // Keep cache size > 16 bytes.

// ----------------------------------------------------------------------------

reg [(CACHE_SIZE/16)-1:0]       dirty;
reg [(CACHE_SIZE/16)-1:0]       valid; 
reg [`CACHE_TAG_WDT-1:0]        tag_ram [(CACHE_SIZE/16)-1:0];
reg [127:0]                     dat_ram [(CACHE_SIZE/16)-1:0];

// ----------------------------------------------------------------------------

reg [`CACHE_TAG_WDT-1:0]        tag_ram_wr_data;
reg                             tag_ram_wr_en;
reg [$clog2(CACHE_SIZE/16)-1:0] tag_ram_wr_addr, tag_ram_rd_addr;
reg                             tag_ram_clear;
reg                             tag_ram_clean;

// ----------------------------------------------------------------------------

reg [$clog2(NUMBER_OF_DIRTY_BLOCKS)-1:0] blk_ctr_ff, blk_ctr_nxt;
reg [2:0] adr_ctr_ff, adr_ctr_nxt;

// ----------------------------------------------------------------------------

always @ (posedge i_clk)
begin
        o_cache_line    <=      dat_ram [ tag_ram_rd_addr ];
end

always @ (posedge i_clk)
begin
        if ( i_cache_line_ben[0]  )   dat_ram [tag_ram_wr_addr][7:0]       <=      i_cache_line[7:0];
        if ( i_cache_line_ben[1]  )   dat_ram [tag_ram_wr_addr][15:8]      <=      i_cache_line[15:8];
        if ( i_cache_line_ben[2]  )   dat_ram [tag_ram_wr_addr][23:16]     <=      i_cache_line[23:16];
        if ( i_cache_line_ben[3]  )   dat_ram [tag_ram_wr_addr][31:24]     <=      i_cache_line[31:24];
        if ( i_cache_line_ben[4]  )   dat_ram [tag_ram_wr_addr][39:32]     <=      i_cache_line[39:32];
        if ( i_cache_line_ben[5]  )   dat_ram [tag_ram_wr_addr][47:40]     <=      i_cache_line[47:40];
        if ( i_cache_line_ben[6]  )   dat_ram [tag_ram_wr_addr][55:48]     <=      i_cache_line[55:48];
        if ( i_cache_line_ben[7]  )   dat_ram [tag_ram_wr_addr][63:56]     <=      i_cache_line[63:56];
        if ( i_cache_line_ben[8]  )   dat_ram [tag_ram_wr_addr][71:64]     <=      i_cache_line[71:64];
        if ( i_cache_line_ben[9]  )   dat_ram [tag_ram_wr_addr][79:72]     <=      i_cache_line[79:72];
        if ( i_cache_line_ben[10] )   dat_ram [tag_ram_wr_addr][87:80]     <=      i_cache_line[87:80];
        if ( i_cache_line_ben[11] )   dat_ram [tag_ram_wr_addr][95:88]     <=      i_cache_line[95:88];
        if ( i_cache_line_ben[12] )   dat_ram [tag_ram_wr_addr][103:96]    <=      i_cache_line[103:96];
        if ( i_cache_line_ben[13] )   dat_ram [tag_ram_wr_addr][111:104]   <=      i_cache_line[111:104];
        if ( i_cache_line_ben[14] )   dat_ram [tag_ram_wr_addr][119:112]   <=      i_cache_line[119:112];
        if ( i_cache_line_ben[15] )   dat_ram [tag_ram_wr_addr][127:120]   <=      i_cache_line[127:120];
end

// ----------------------------------------------------------------------------

always @ (posedge i_clk)
begin
        if ( tag_ram_wr_en )
                tag_ram [ tag_ram_wr_addr ] <= tag_ram_wr_data;
end

always @ (posedge i_clk)
begin
                o_cache_tag                 <= tag_ram [ tag_ram_rd_addr ];
end

// ----------------------------------------------------------------------------

always @ (posedge i_clk)
begin
        o_cache_tag_dirty                   <= dirty [ tag_ram_rd_addr ];

        if ( tag_ram_clean )
                dirty [ tag_ram_wr_addr ]   <= 1'd0;
        else if ( tag_ram_wr_en )
                dirty [ tag_ram_wr_addr ]   <= i_cache_tag_dirty;
end

always @ (posedge i_clk)
begin
        o_cache_tag_valid                   <= valid [ tag_ram_rd_addr ];

        if ( tag_ram_clear | !i_cache_en )
                valid <= 0;
        else if ( tag_ram_wr_en )
                valid [ tag_ram_wr_addr ]   <= 1'd1;
end

// ----------------------------------------------------------------------------

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
                adr_ctr_ff <= 0;
                blk_ctr_ff <= 0;
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
                adr_ctr_ff              <= adr_ctr_nxt;
                blk_ctr_ff              <= blk_ctr_nxt;
		state_ff		<= state_nxt;
        end
end

// ----------------------------------------------------------------------------

localparam IDLE                         = 0;
localparam CACHE_CLEAN_GET_ADDRESS      = 1;
localparam CACHE_CLEAN_WRITE            = 2;
localparam CACHE_INV                    = 3;

reg [1:0] state_ff, state_nxt;

always @*
begin

        // Defaults.
        state_nxt = state_ff;
        tag_ram_rd_addr         = i_address_nxt [`VA__CACHE_INDEX];
        tag_ram_wr_addr         = i_address     [`VA__CACHE_INDEX];
        tag_ram_wr_en           = i_cache_tag_wr_en;
        tag_ram_clear           = 0;
        tag_ram_clean           = 0;
        adr_ctr_nxt             = adr_ctr_ff;
        blk_ctr_nxt             = blk_ctr_ff;
        o_cache_clean_done      = 0;
        o_cache_inv_done        = 0;

        o_wb_cyc_nxt = o_wb_cyc_ff;
        o_wb_stb_nxt = o_wb_stb_ff;
        o_wb_adr_nxt = o_wb_adr_ff;
        o_wb_dat_nxt = o_wb_dat_ff;
        o_wb_sel_nxt = o_wb_sel_ff;
        o_wb_wen_nxt = o_wb_wen_ff;
        o_wb_cti_nxt = o_wb_cti_ff;

        tag_ram_wr_data = 0;

        case ( state_ff )

        IDLE:
        begin
                kill_access;

                tag_ram_rd_addr = i_address_nxt [`VA__CACHE_INDEX];
                tag_ram_wr_addr = i_address     [`VA__CACHE_INDEX];
                tag_ram_wr_en   = i_cache_tag_wr_en;
                tag_ram_wr_data = i_cache_tag;

                if ( i_cache_clean_req )
                begin
                        state_nxt = CACHE_CLEAN_GET_ADDRESS;
                end
                else if ( i_cache_inv_req )
                begin
                        state_nxt = CACHE_INV;
                end
        end        

        CACHE_CLEAN_GET_ADDRESS:
        begin
                tag_ram_rd_addr = (blk_ctr_ff << 4) + pri_enc(dirty << (blk_ctr_ff << 4));

                if ( dirty >> (blk_ctr_ff << 4) == 0)
                begin
                        // Move to next block.
                        blk_ctr_nxt = blk_ctr_ff + 1;

                        if ( blk_ctr_ff == NUMBER_OF_DIRTY_BLOCKS - 1 )
                        begin
                                state_nxt = IDLE;
                                o_cache_clean_done = 1'd1;
                        end
                end
                else
                begin
                        // Go to state.
                        state_nxt = CACHE_CLEAN_WRITE;
                end

                adr_ctr_nxt     = 0; // Initialize address counter.
        end

        CACHE_CLEAN_WRITE:
        begin
                adr_ctr_nxt = adr_ctr_ff + (i_wb_ack && o_wb_stb_ff);

                if ( adr_ctr_nxt > 3 )
                begin
                        // Remove dirty marking.
                        tag_ram_rd_addr = (blk_ctr_ff << 4) + pri_enc(dirty << (blk_ctr_ff << 4));
                        tag_ram_clean   = 1'd1;

                        // Kill access.
                        kill_access;

                        // Go to new state.
                        state_nxt = CACHE_CLEAN_GET_ADDRESS;
                end
                else
                begin
                        // Perform a Wishbone write using Physical Address.
                        wb_prpr_write(  i_cache_line >> ( adr_ctr_nxt << 5), 
                                        o_cache_tag[`CACHE_TAG__PA] + (adr_ctr_nxt << 2),
                                        adr_ctr_nxt != 3 ? CTI_BURST : CTI_EOB, 4'b1111 );
                end
        end

        CACHE_INV:
        begin
                tag_ram_clear = 1'd1;
                state_nxt     = IDLE;
                o_cache_inv_done = 1'd1;
        end
        
        endcase                
end

endmodule // zap_cache_tag_ram.v
