`default_nettype none

// DO NOT CHANGE LINE_SIZE

module zap_cache_fsm
#(
        parameter CACHE_LINE_SIZE = 16,  /* Bytes */
        parameter CACHE_TAG_SIZE  = 22   /* Bits  */
)
(
        // Clock and reset.
        input  wire                             i_clk,
        input  wire                             i_reset,

        // From processor. Come directly from posedge flops.
        input  wire [31:0]                      i_addr,
        input  wire [31:0]                      i_pc,
        input  wire                             i_wen,
        input  wire                             i_ren,
        input  wire [31:0]                      i_data,
        input  wire [3:0]                       i_ben,

        // To processor. Go to posedge flops.
        output reg                              o_miss,     /* Data and I-cache miss use the same signal. */
        output reg [31:0]                       o_rd_data,
        output reg [31:0]                       o_instr,
        output reg                              o_data_abort,
        output reg                              o_instr_abort,
        output reg [3:0]                        o_fsr,  //From FSR reg.
        output reg [31:0]                       o_far,  //From FAR reg.
        output reg [3:0]                        o_dom,  // From DOM reg.

        // From cache - These come from negedge registers absorbed into BLOCK RAM.
        input wire [CACHE_LINE_SIZE*8-1:0]      i_icache_line,
        input wire [CACHE_TAG_SIZE-1:0]         i_icache_tag,
        input wire                              i_icache_dav,
        input wire [CACHE_LINE_SIZE*8-1:0]      i_dcache_line,
        input wire [CACHE_TAG_SIZE-1:0]         i_dcache_tag,
        input wire                              i_dcache_dav,

        // Cache update controls.
        output reg [CACHE_LINE_SIZE*8-1:0]      o_cache_line,
        output reg [CACHE_TAG_SIZE-1:0]         o_cache_tag,
        output reg                              o_cache_sel,

        // Memory access interface.
        output reg [31:0]                       o_mem_addr,     // Unregd.
        output reg                              o_mem_rd_en,    // Unregd.
        input wire                              i_mem_dav,      // Regd.
        input wire [CACHE_LINE_SIZE*8-1:0]      i_mem_data,     // Regd.

        // Interface to MMU. Outputs from this unit are REGD since other is MEALY. 
        output reg [31:0]                       o_virt_addr,            // REGD
        output reg                              o_virt_addr_dav,        // REGD
        output reg                              o_wen,                  // REGD
        output reg                              o_ren,                  // REGD
        input wire [31:0]                       i_phy_addr,
        input wire                              i_phy_addr_dav,
        input wire                              i_fault,
        input wire [3:0]                        i_fsr,
        input wire [31:0]                       i_far,
        input wire [3:0]                        i_dom,
        input wire [2:0]                        i_ucb,

        // Write FIFO interface.
        output reg [31:0]                       o_fifo_data,
        output reg [31:0]                       o_fifo_phy_addr,
        output reg                              o_fifo_wr_en,
        input wire                              i_fifo_empty,
        input wire                              i_fifo_full
);

// Aliases.
wire [CACHE_TAG_SIZE-1:0] itag = i_pc   [ $clog2(CACHE_LINE_SIZE) + CACHE_TAG_SIZE - 1 : $clog2(CACHE_LINE_SIZE) ];
wire [CACHE_TAG_SIZE-1:0] dtag = i_addr [ $clog2(CACHE_LINE_SIZE) + CACHE_TAG_SIZE - 1 : $clog2(CACHE_LINE_SIZE) ];

wire                      ihit = i_icache_dav && (i_icache_tag == itag);
wire                      dhit = (i_dcache_dav && (i_dcache_tag == dtag) && i_ren) | (!i_ren && !i_wen);

// D pin of flops to talk to MMU.
reg [31:0]      virt_addr_nxt;
reg             virt_addr_dav_nxt;
reg             ren_nxt;
reg             wen_nxt;
reg [3:0]       fsr_nxt;
reg [31:0]      far_nxt;
reg [3:0]       dom_nxt;

// Register MMU outputs.
reg [3:0]  x_fsr, x_fsr_nxt;
reg [31:0] x_far, x_far_nxt;
reg [31:0] x_phy_addr, x_phy_addr_nxt;
reg        x_phy_addr_dav, x_phy_addr_dav_nxt;
reg [2:0]  x_ucb, x_ucb_nxt;
reg        x_fault, x_fault_nxt;
reg [3:0]  x_dom, x_dom_nxt;

localparam IDLE                 = 0;
localparam BUSY                 = 2;
localparam GET_PA               = 1;
localparam DRAIN_WRITE_BUFFER   = 3;

reg [1:0] state_ff, state_nxt;

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                o_virt_addr       <=  0;
                o_virt_addr_dav   <=  0;
                o_ren             <=  0;
                o_wen             <=  0;
                o_fsr             <=  0;
                o_far             <=  0;
                o_dom             <=  0;
                x_fsr             <=  0;
                x_far             <=  0;
                x_phy_addr        <=  0;
                x_phy_addr_dav    <=  0;
                x_ucb             <=  0;
                state_nxt         <= IDLE;
                x_fault           <= 0;
                x_dom             <= 0;
        end
        else
        begin
                o_virt_addr <= virt_addr_nxt;
                o_virt_addr_dav <= virt_addr_dav_nxt;
                o_ren <= ren_nxt;
                o_wen <= wen_nxt;
                o_fsr <= fsr_nxt;
                o_far <= far_nxt;
                o_dom <= dom_nxt;
                x_fsr <= x_fsr_nxt;
                x_far <= x_far_nxt;
                x_phy_addr <= x_phy_addr_nxt;
                x_phy_addr_dav <= x_phy_addr_dav_nxt;
                x_ucb <= x_ucb_nxt;
                state_nxt <= state_ff;
                x_fault <= x_fault_nxt;
                x_dom <= x_dom_nxt;
        end
end

initial
begin
        if ( CACHE_LINE_SIZE != 16 )
        begin
                $display("*E: Cache line size must only be 16 bytes...");
                $finish;
        end
end

always @*
begin
        state_nxt         = state_ff;
        virt_addr_nxt     = o_virt_addr;
        virt_addr_dav_nxt = o_virt_addr_dav;
        ren_nxt           = o_ren;
        wen_nxt           = o_wen;
        fsr_nxt           = o_fsr;
        far_nxt           = o_far;
        dom_nxt           = o_dom;
        o_miss            = 1'd1;
        o_rd_data         = 0;
        o_instr           = 0;
        o_data_abort      = 0;
        o_instr_abort     = 0;
        o_cache_line      = 0;
        o_cache_tag       = 0;
        o_cache_sel       = 0;
        o_mem_addr        = 0;
        o_mem_rd_en       = 0;

        case(state_ff)
        IDLE:
        begin
                casez({ihit, dhit})
                2'b11:
                begin
                        // This is the only case where we can continue.
                        // Deliver output. 
                        o_miss          = 1'd0;
                        o_rd_data       = i_icache_line >> (i_addr[3:0] << 3); // Shift to position data correctly.
                        o_instr         = i_dcache_line >> (i_addr[3:0] << 3);
                end
                2'b01, 2'b00:
                begin
                        virt_addr_nxt     = i_addr;
                        virt_addr_dav_nxt = 1'd1;
                        ren_nxt           = 1'd1; 
                        state_nxt         = GET_PA;
                        o_miss            = 1'd1;
                end
                2'b10:
                begin
                        virt_addr_nxt     = i_pc;
                        virt_addr_dav_nxt = 1'd1;
                        wen_nxt           = 1'd1;
                        state_nxt         = GET_PA;
                        o_miss            = 1'd1;
                end
                endcase
        end

        GET_PA:
        begin
                if ( i_phy_addr_dav )
                begin
                        // Record all details from the TLB and be done with it.
                        x_fault_nxt         = i_fault;              
                        x_dom_nxt           = i_dom;
                        x_fsr_nxt           = i_fsr;
                        x_far_nxt           = i_far;
                        x_phy_addr_nxt      = i_phy_addr;
                        x_phy_addr_dav_nxt  = i_phy_addr_dav;
                        state_nxt           = BUSY;
                end
        end

        BUSY:
        begin
                if ( x_fault == 1'd1 )
                begin
                        if ( !dhit ) // If  this is a data miss.
                        begin
                                o_miss       = 1'd0;
                                o_data_abort = 1'd1;
                                fsr_nxt      = x_fsr;
                                far_nxt      = x_far;
                                dom_nxt      = x_dom;
                        end
                        else
                        begin
                                o_miss        = 1'd0;
                                o_instr_abort = 1'd1;
                        end
                end
                else if ( x_phy_addr_dav == 1'd1 )
                begin
                        // If a read caused the miss, we will perform a memory access to fetch the entire cache line.
                        // We will do cache line updated only after we do the memory access.
                        if ( i_ren && !dhit )
                        begin
                                o_mem_addr  = (x_phy_addr >> $clog2(CACHE_LINE_SIZE)) << $clog2(CACHE_LINE_SIZE); 
                                o_mem_rd_en = 1'd1;

                                // Look for the flopped dav = 1 to ensure a memory read.
                                if ( i_mem_dav )
                                begin
                                        // Get to IDLE.
                                        state_nxt = IDLE;

                                        // Kill memory access.
                                        o_mem_rd_en = 1'd0;

                                        if ( x_ucb[1] == 1'd1 ) // Cacheable
                                        begin
                                                // Update cache line.
                                                o_cache_tag  = i_addr[$clog2(CACHE_LINE_SIZE) + CACHE_TAG_SIZE - 1 :$clog2(CACHE_LINE_SIZE)];
                                                o_cache_line = i_mem_data;
                                                o_cache_sel  = 1'd1;
                                        end
                                        else
                                        begin
                                                o_miss     = 1'd0;
                                                o_rd_data  = i_mem_data >> (i_addr[3:0] << 3); // Shift to position data correctly.
                                        end
                                end
                        end 
                        else if ( i_wen && !dhit ) 
                        // If write caused a miss, then invalidate the cache line and
                        // push the entry to the write buffer.
                        begin
                                // If write buffer is full, stall the pipeline hrere. 
                                if ( !i_fifo_full )
                                begin
                                        if ( x_ucb[0] == 1 ) // Bufferable
                                                state_nxt = IDLE;
                                        else
                                                state_nxt = DRAIN_WRITE_BUFFER;              
                                end
       
                                // Write to write buffer. 
                                o_fifo_wr_en    = !i_fifo_full;
                                o_fifo_data     = i_data;
                                o_fifo_phy_addr = x_phy_addr;

                                // Update cache.                
                                o_cache_tag    =       i_dcache_tag;   // No change to tag.
                                o_cache_line   =       i_dcache_line;

                                // A line consists of 4 words (16 bytes), to determine which line to change, we can
                                // use [5:4] to determine that.
                                case ( i_addr[3:2] )
                                        2'b00: 
                                        begin
                                                if ( i_ben[0] )   o_cache_line[7:0]   = i_data[7:0];
                                                if ( i_ben[1] )   o_cache_line[15:8]  = i_data[15:8];
                                                if ( i_ben[2] )   o_cache_line[23:16] = i_data[23:16];
                                                if ( i_ben[3] )   o_cache_line[31:24] = i_data[31:24];
                                        end
                                        2'b01:
                                        begin
                                                if ( i_ben[0] )   o_cache_line[39:32] = i_data[7:0];
                                                if ( i_ben[1] )   o_cache_line[47:40] = i_data[15:8];
                                                if ( i_ben[2] )   o_cache_line[55:48] = i_data[23:16];
                                                if ( i_ben[3] )   o_cache_line[63:56] = i_data[31:24];
                                        end
                                        2'b10:
                                        begin
                                                if ( i_ben[0] )   o_cache_line[71:64] = i_data[7:0];
                                                if ( i_ben[1] )   o_cache_line[79:72] = i_data[15:8];
                                                if ( i_ben[2] )   o_cache_line[87:80] = i_data[23:16];
                                                if ( i_ben[3] )   o_cache_line[95:88] = i_data[31:24];
                                        end
                                        2'b11:
                                        begin
                                                if ( i_ben[0] )   o_cache_line[103:96]  = i_data[7:0];
                                                if ( i_ben[1] )   o_cache_line[111:104] = i_data[15:8];
                                                if ( i_ben[2] )   o_cache_line[119:112] = i_data[23:16];
                                                if ( i_ben[3] )   o_cache_line[127:120] = i_data[31:24];
                                        end
                                endcase

                                o_cache_sel     =       x_ucb[0] && !i_fifo_full;   // Update the D-cache at the same time FIFO writes.
                        end
                        else
                        begin
                                // We are here because of an I-Cache miss.
                                o_mem_addr  = (x_phy_addr >> $clog2(CACHE_LINE_SIZE)) << $clog2(CACHE_LINE_SIZE); 
                                o_mem_rd_en = 1'd1;

                                // Look for the flopped dav = 1 to ensure a memory read.
                                if ( i_mem_dav )
                                begin
                                        // Get to IDLE.
                                        state_nxt = IDLE;

                                        // Kill memory access.
                                        o_mem_rd_en = 1'd0;

                                        // Update cache line.
                                        o_cache_tag  = i_addr[$clog2(CACHE_LINE_SIZE) + CACHE_TAG_SIZE - 1 :$clog2(CACHE_LINE_SIZE)];
                                        o_cache_line = i_mem_data;
                                        o_cache_sel  = 1'd1;
                                end
                        end
                end
        end

        DRAIN_WRITE_BUFFER:
        begin
                // A non bufferable write will drain the entire write buffer.
                if ( !i_fifo_empty )
                        state_nxt = state_ff;
                else
                        state_nxt = IDLE; 
        end
        endcase
end

endmodule
