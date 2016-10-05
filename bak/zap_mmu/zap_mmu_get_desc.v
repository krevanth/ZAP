`default_nettype none

//
// This is a negedge MEALY state machine that retrieves descriptors
// from memory and updates the TLB accordingly.
//

module zap_mmu_get_desc #(
        parameter       SECTION_TLB_DEPTH = 64,
        parameter       SPAGE_TLB_DEPTH   = 64,
        parameter       LPAGE_TLB_DEPTH   = 64 
)
(
        // Clock and reset.
        input   wire            i_clk,
        input   wire            i_reset,

        // Configuration.
        input   wire    [31:0]  i_cfg_tr_base,
        input   wire            i_cfg_tlb_flush,
        input   wire            i_cfg_tlb_en,

        // Interface.
        input   wire    [31:0]  i_virt_addr,
        input   wire            i_virt_addr_dav,
        output  reg     [31:0]  o_l1_desc,
        output  reg     [31:0]  o_l2_desc,
        output  reg             o_dav,
        output  reg             o_flush_progress,

        // Memory interface.
        output  reg     [31:0]  o_mem_addr,
        output  reg             o_mem_rd_en,
        input   wire    [31:0]  i_mem_data,     // Must come from a registered source.
        input   wire            i_mem_dav       // Must come from a registered source.
);

// Set up L1 and L2 descriptor widths.
localparam L1_DESC_WDT  = 32;
localparam L2_DESC_WDT  = 32;

// Set up sizes.
localparam SECTION_SIZE = 1 << 20;
localparam LPAGE_SIZE   = 1 << 16;
localparam SPAGE_SIZE   = 1 << 12;

// Compute index widths.
localparam SECTION_INDEX_WDT = $clog2(SECTION_TLB_DEPTH);
localparam SPAGE_INDEX_WDT   = $clog2(SPAGE_TLB_DEPTH);
localparam LPAGE_INDEX_WDT   = $clog2(LPAGE_TLB_DEPTH);

// We can now compute tag width.
localparam SECTION_TAG_WDT   =  (32'd32 - $clog2(SECTION_SIZE)) - SECTION_INDEX_WDT;
localparam SPAGE_TAG_WDT     =  (32'd32 - $clog2(SPAGE_SIZE))   - SPAGE_INDEX_WDT;
localparam LPAGE_TAG_WDT     =  (32'd32 - $clog2(LPAGE_SIZE))   - LPAGE_INDEX_WDT;   

// Width of valid.
localparam VALID_WDT         = 32'd1;

// We can compute TLB widths.
localparam SECTION_TLB_WDT      = L1_DESC_WDT + SECTION_TAG_WDT + VALID_WDT;
localparam SPAGE_TLB_WDT        = L1_DESC_WDT + L2_DESC_WDT + SPAGE_TAG_WDT + VALID_WDT;
localparam LPAGE_TLB_WDT        = L1_DESC_WDT + L2_DESC_WDT + LPAGE_TAG_WDT + VALID_WDT;

// Aliases.
wire    [11:0]  virt_addr_1m_aligned            =  i_virt_addr[31:20];
wire    [15:0]  virt_addr_64k_aligned           =  i_virt_addr[31:16];
wire    [19:0]  virt_addr_4k_aligned            =  i_virt_addr[31:12];
wire    [31:0]  translation_table_base_addr     =  {i_cfg_tr_base[31:14], 14'd0};
wire    [11:0]  table_index                     =  i_virt_addr[31:20];
wire    [7:0]   l2_table_index                  =  i_virt_addr[19:12];

// IDs.
localparam  [1:0]    SECTION_ID      =       2'd2;
localparam  [1:0]    PAGE_ID         =       2'd1;
localparam  [1:0]    SPAGE_ID        =       2'd2;
localparam  [1:0]    LPAGE_ID        =       2'd1;

// TLBs for each one.
reg     [SECTION_TLB_WDT-1:0] section_tlb   [SECTION_TLB_DEPTH-1:0];
reg     [LPAGE_TLB_WDT-1:0]   lpage_tlb     [SECTION_TLB_DEPTH-1:0];
reg     [SPAGE_TLB_WDT-1:0]   spage_tlb     [SECTION_TLB_DEPTH-1:0];

// Defines for positions within TLBs.
`define SECTION_TLB_L1          L1_DESC_WDT - 1 : 0
`define SECTION_TLB_TAG         SECTION_TLB_WDT - 2 : L1_DESC_WDT
`define SECTION_TLB_DAV         SECTION_TLB_WDT - 1

`define LPAGE_TLB_L2            L2_DESC_WDT-1 : 0
`define LPAGE_TLB_L1            L2_DESC_WDT + L1_DESC_WDT - 1 : L2_DESC_WDT
`define LPAGE_TLB_TAG           LPAGE_TLB_WDT - 2 : L2_DESC_WDT + L1_DESC_WDT
`define LPAGE_TLB_DAV           LPAGE_TLB_WDT - 1

`define SPAGE_TLB_L2            L2_DESC_WDT-1 : 0
`define SPAGE_TLB_L1            L2_DESC_WDT + L1_DESC_WDT - 1 : L2_DESC_WDT
`define SPAGE_TLB_TAG           SPAGE_TLB_WDT - 2 : L2_DESC_WDT + L1_DESC_WDT
`define SPAGE_TLB_DAV           SPAGE_TLB_WDT - 1

// TLB read buffers.
reg     [SECTION_TLB_WDT-1:0]   section_tlb_buf;
reg     [LPAGE_TLB_WDT-1:0]     lpage_tlb_buf;
reg     [SPAGE_TLB_WDT-1:0]     spage_tlb_buf;

// Aliases.
wire    [SECTION_INDEX_WDT-1:0]   virt_addr_section_index = i_cfg_tlb_flush ? ctr_ff : virt_addr_1m_aligned    [ SECTION_INDEX_WDT - 1 : 0 ];
wire    [LPAGE_INDEX_WDT-1:0]     virt_addr_lpage_index   = i_cfg_tlb_flush ? ctr_ff : virt_addr_64k_aligned   [ LPAGE_INDEX_WDT   - 1 : 0 ];
wire    [SPAGE_INDEX_WDT-1:0]     virt_addr_spage_index   = i_cfg_tlb_flush ? ctr_ff : virt_addr_4k_aligned    [ SPAGE_INDEX_WDT   - 1 : 0 ];

wire    [SECTION_TAG_WDT-1:0]     virt_addr_section_tag   = virt_addr_1m_aligned  [ SECTION_INDEX_WDT + SECTION_TAG_WDT - 1 : SECTION_INDEX_WDT];
wire    [SPAGE_TAG_WDT-1:0]       virt_addr_spage_tag     = virt_addr_4k_aligned  [ LPAGE_INDEX_WDT   + SPAGE_TAG_WDT   - 1 : LPAGE_INDEX_WDT  ];
wire    [LPAGE_TAG_WDT-1:0]       virt_addr_lpage_tag     = virt_addr_64k_aligned [ SPAGE_INDEX_WDT   + LPAGE_TAG_WDT   - 1 : SPAGE_INDEX_WDT  ];

// These regs control TLB updates.
reg section_tlb_wr_en;
reg lpage_tlb_wr_en;
reg spage_tlb_wr_en;

// All TLBs are continually being read.
always @ (negedge i_clk)
        section_tlb_buf <=      section_tlb     [ virt_addr_section_index ];

always @ (negedge i_clk)
        lpage_tlb_buf   <=      lpage_tlb       [ virt_addr_lpage_index   ];

always @ (negedge i_clk)
        spage_tlb_buf   <=      spage_tlb       [ virt_addr_spage_index   ];

// | TAG | L1 | L2 | <== Structure.

// TLB writes.
always @ (negedge i_clk)
        if ( section_tlb_wr_en )
                section_tlb [ virt_addr_section_index ]  <=     {!i_cfg_tlb_flush, virt_addr_section_tag ,i_mem_data};  

always @ (negedge i_clk)
        if ( lpage_tlb_wr_en )
                lpage_tlb   [ virt_addr_lpage_index ]    <=     {!i_cfg_tlb_flush, virt_addr_lpage_tag, l1_buf_ff, i_mem_data};

always @ (negedge i_clk)
        if ( spage_tlb_wr_en )
                spage_tlb   [ virt_addr_spage_index ]    <=     {!i_cfg_tlb_flush, virt_addr_spage_tag, l1_buf_ff, i_mem_data};

// Counter. Uses SPAGE_TLB_DEPTH since most people like to keep more entries for small page TLBs.
reg     [$clog2(SPAGE_TLB_DEPTH)-1:0]   ctr_ff, ctr_nxt;

// States.
localparam  [2:0]    IDLE            =       3'd0;
localparam  [2:0]    READ_TLB        =       3'd1;
localparam  [2:0]    FETCH_L1        =       3'd2;
localparam  [2:0]    FETCH_L2        =       3'd3;
localparam  [2:0]    CLEAR_TLB       =       3'd4;  
localparam  [2:0]    FLUSH_TLB       =       3'd5; 
localparam  [31:0]   NO_OF_STATES    =      32'd6;

// State variable.
reg     [NO_OF_STATES-1:0]  state_ff, state_nxt;

// L1 descriptor buffer.
reg     [L1_DESC_WDT-1:0]   l1_buf_ff, l1_buf_nxt;    

always @ (negedge i_clk)
        state_ff <= state_nxt;

always @ (negedge i_clk)
        l1_buf_ff <= l1_buf_nxt;

// Next state and output logic.
always @*
begin
        section_tlb_wr_en = 1'd0;
        lpage_tlb_wr_en   = 1'd0;
        spage_tlb_wr_en   = 1'd0;
        state_nxt         = state_ff;
        ctr_nxt           = 0;
        o_l1_desc         = {L1_DESC_WDT{1'd0}};
        o_l2_desc         = {L2_DESC_WDT{1'd0}};
        o_dav             = 1'd0;
        l1_buf_nxt        = l1_buf_ff;
        o_mem_rd_en       = 1'd0;
        o_flush_progress  = 1'd0;

        if ( i_reset )
        begin
                state_nxt  = 1 << IDLE;
                l1_buf_nxt = {L2_DESC_WDT{1'd0}};
        end
        else if ( i_cfg_tlb_flush || !i_cfg_tlb_en || state_nxt == 1 << FLUSH_TLB )
        begin
                ctr_nxt                 = ctr_ff + 1;
                o_flush_progress        = 1'd1;
                state_nxt               = 1 << FLUSH_TLB;

                /* verilator lint_off width */
                if ( (ctr_ff == SPAGE_TLB_DEPTH - 1) ) 
                /* verilator lint_on width */
                begin
                        ctr_nxt      = ctr_ff;
                        state_nxt    = i_cfg_tlb_en ? 1 << IDLE : state_ff;
                end
        end
        else case ( 1'b1 )
                state_ff[IDLE]:
                begin
                        // If a request is given, wait for TLBs to read...
                        if ( i_virt_addr_dav )
                        begin
                                state_nxt       =       1 << READ_TLB;
                        end 
                end

                state_ff[READ_TLB]:
                begin
                        // If section TLB  hits.
                        if (      section_tlb_buf [`SECTION_TLB_DAV] && 
                                ( section_tlb_buf [`SECTION_TLB_TAG] == virt_addr_section_tag ) )
                        begin
                                o_l1_desc = section_tlb_buf [ `SECTION_TLB_L1 ];
                                o_dav     = 1'd1;
                        end
                        // If small page TLB hits.
                        else if (   spage_tlb_buf [ `SPAGE_TLB_DAV ] &&
                                  ( spage_tlb_buf [ `SPAGE_TLB_TAG ] == virt_addr_spage_tag ) )       
                        begin
                                o_l1_desc = spage_tlb_buf [ `SPAGE_TLB_L1 ];
                                o_l2_desc = spage_tlb_buf [ `SPAGE_TLB_L2 ];
                                o_dav     = 1'd1;
                        end
                        // If large page TLB hits.
                        else if (   lpage_tlb_buf [ `LPAGE_TLB_DAV ] &&
                                  ( lpage_tlb_buf [ `LPAGE_TLB_TAG ] == virt_addr_lpage_tag ) )
                        begin
                                o_l1_desc = lpage_tlb_buf [ `LPAGE_TLB_L1 ];
                                o_l2_desc = lpage_tlb_buf [ `LPAGE_TLB_L2 ];
                                o_dav     = 1'd1;
                        end
                        else /* All miss. */
                        begin
                                state_nxt       =       1 << FETCH_L1;
                        end
                end

                state_ff[FETCH_L1]:
                begin
                        // Fetch L1 descriptor.
                        memory_read ( translation_table_base_addr );

                        if ( i_mem_dav ) // Memory read successful!.
                        begin
                                stop_memory_read;

                                case ( i_mem_data[1:0] )
                                PAGE_ID:
                                begin
                                        // Initiate next level fetch.
                                        state_nxt = 1 << FETCH_L2;

                                        // Store L1.
                                        l1_buf_nxt = i_mem_data;
                                end

                                default:
                                begin
                                        // Update the section TLB.
                                        section_tlb_wr_en = 1'd1;
                                end
                                endcase 
                        end
                end

                state_ff[FETCH_L2]:
                begin
                        memory_read ( {l1_buf_ff[31:10], l2_table_index, 2'b00} );
                        
                        if ( i_mem_dav )
                        begin
                                stop_memory_read;
                                state_nxt = 1 << IDLE;                                       
 
                                case ( i_mem_data[1:0] )
                                SPAGE_ID: spage_tlb_wr_en = 1'd1;
                                default : lpage_tlb_wr_en = 1'd1;
                                endcase
                        end
                end                     

        endcase
end

// ========================
// Tasks.
// ========================

task memory_read ( input [31:0] addr );
begin
        o_mem_addr = addr;
        o_mem_rd_en = 1'd1; 
end
endtask

task stop_memory_read;
begin
        o_mem_addr = 32'd0;
        o_mem_rd_en = 1'd0;
end
endtask

endmodule
