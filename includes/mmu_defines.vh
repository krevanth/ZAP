/* Defines work on specific items, the syntax is ITEM_NAME__PORTION
   Parameters tend to define values. */

`ifndef __MMU__VH__
`define __MMU__VH__

///////////////////////////////
// Generic defines.
///////////////////////////////
`define ID 1:0

///////////////////////////////
// Virtual Address Breakup
///////////////////////////////

`define VA__TABLE_INDEX       31:20
`define VA__L2_TABLE_INDEX    19:12
`define VA__4K_PAGE_INDEX     11:0
`define VA__64K_PAGE_INDEX    15:0
`define VA__1M_SECTION_INDEX  19:0

`define VA__TRANSLATION_BASE  31:14

`define VA__CACHE_INDEX      4+$clog2(CACHE_SIZE/16)-1:4
`define VA__SECTION_INDEX   20+$clog2(SECTION_TLB_ENTRIES)-1:20
`define VA__LPAGE_INDEX     16+$clog2(LPAGE_TLB_ENTRIES)-1:16
`define VA__SPAGE_INDEX     12+$clog2(SPAGE_TLB_ENTRIES)-1:12

`define VA__CACHE_TAG       31:4+$clog2(CACHE_SIZE/16)

`define VA__SPAGE_TAG       31:12+$clog2(SPAGE_TLB_ENTRIES)
`define VA__LPAGE_TAG       31:16+$clog2(LPAGE_TLB_ENTRIES)
`define VA__SECTION_TAG     31:20+$clog2(SECTION_TLB_ENTRIES)

`define VA__SPAGE_AP_SEL    11:10    
`define VA__LPAGE_AP_SEL    17:16


///////////////////////////////////
// L1 Section Descriptior Breakup
///////////////////////////////////
`define L1_SECTION__BASE      31:20
`define L1_SECTION__DAC_SEL   8:5
`define L1_SECTION__AP        11:10
`define L1_SECTION__CB        3:2

////////////////////////////////////
// L1 Page Descriptor Breakup
///////////////////////////////////
`define L1_PAGE__PTBR    31:10
`define L1_PAGE__DAC_SEL 8:5



//////////////////////////////////
// L2 Page Descriptor Breakup
//////////////////////////////////
`define L2_SPAGE__BASE   31:12
`define L2_SPAGE__AP     11:4
`define L2_SPAGE__CB     3:2
`define L2_LPAGE__BASE   31:16
`define L2_LPAGE__AP     11:4
`define L2_SPAGE__CB     3:2



///////////////////////////////////
// Section TLB Structure - 1:0 is undefined.
///////////////////////////////////
`define SECTION_TLB__BASE    31:20
`define SECTION_TLB__DAC_SEL 8:5
`define SECTION_TLB__AP     11:10
`define SECTION_TLB__CB     3:2
`define SECTION_TLB__TAG 32+(32-$clog2(SECTION_TLB_ENTRIES)-20)-1:32



///////////////////////////////////
// Lpage TLB Structure - 1:0 is undefined
//////////////////////////////////
`define LPAGE_TLB__BASE      31:16
`define LPAGE_TLB__DAC_SEL   15:12 // Squeezed in blank space.
`define LPAGE_TLB__AP        11:4
`define LPAGE_TLB__CB        3:2
`define LPAGE_TLB__TAG 32+(32-$clog2(LPAGE_TLB_ENTRIES)-16)-1:32


//////////////////////////////////
// Spage TLB Structure - 1:0 is undefined
//////////////////////////////////
`define SPAGE_TLB__BASE      31:12
`define SPAGE_TLB__AP        11:4
`define SPAGE_TLB__CB        3:2
`define SPAGE_TLB__DAC_SEL   35:32
`define SPAGE_TLB__TAG 36+(32-$clog2(SPAGE_TLB_ENTRIES)-12)-1:36


`endif
