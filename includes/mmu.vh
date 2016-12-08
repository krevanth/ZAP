
// Basic configuration parameters.
`include "mmu_config.vh"
`include "mmu_defines.vh"

/////////////////////////////////
// State definitions.            
/////////////////////////////////       
localparam IDLE                 = 0;
localparam FETCH_L1_DESC        = 1;
localparam FETCH_L2_DESC        = 2;
localparam CACHE_FILL_0         = 5;
localparam CACHE_FILL_1         = 6;
localparam CACHE_FILL_2         = 7;
localparam CACHE_FILL_3         = 8;
localparam REFRESH_CYCLE        = 9;
localparam RD_DLY               = 10;
localparam REFRESH_CYCLE_CACHE  = 11;
localparam NUMBER_OF_STATES     = 12;

parameter CACHE_TAG_WDT = 31 - 4 - $clog2(CACHE_SIZE/16) + 1;

///////////////////////////////////
// Identifier for L1
///////////////////////////////////
parameter SECTION_ID = 2'b10;
parameter PAGE_ID    = 2'b01;

///////////////////////////////////
// Identifier for L2
///////////////////////////////////
parameter SPAGE_ID = 2'b10;
parameter LPAGE_ID = 2'b01;

parameter SECTION_TLB_WDT=32+(32-$clog2(SECTION_TLB_ENTRIES)-20);

parameter LPAGE_TLB_WDT=32+(32-$clog2(LPAGE_TLB_ENTRIES)-16);

parameter SPAGE_TLB_WDT=36+(32-$clog2(SPAGE_TLB_ENTRIES)-12);

///////////////////////////////////
// APSR bits.
///////////////////////////////////
             //K  U
parameter APSR_NA_NA = 4'b00_00;
parameter APSR_RO_RO = 4'b00_01;
parameter APSR_RO_NA = 4'b00_10;
parameter APSR_RW_NA = 4'b01_??;
parameter APSR_RW_RO = 4'b10_??;
parameter APSR_RW_RW = 4'b11_??;

////////////////////////////////////
// DAC bits.
////////////////////////////////////
parameter DAC_MANAGER = 2'b11;
parameter DAC_CLIENT  = 2'b01;

////////////////////////////////////
// FSR
////////////////////////////////////

//Section.
parameter [3:0] FSR_SECTION_DOMAIN_FAULT      = 4'b1001; 
parameter [3:0] FSR_SECTION_TRANSLATION_FAULT = 4'b0101;
parameter [3:0] FSR_SECTION_PERMISSION_FAULT  = 4'b1101;

//Page.
parameter [3:0] FSR_PAGE_TRANSLATION_FAULT    = 4'b0111;
parameter [3:0] FSR_PAGE_DOMAIN_FAULT         = 4'b1011;
parameter [3:0] FSR_PAGE_PERMISSION_FAULT     = 4'b1111;


