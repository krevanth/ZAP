`default_nettype none

//
// This accepts virtual addresses and 
// provides physical addresses and an FSR.
//

module zap_mmu_main
#(
        parameter SECTION_TLB_DEPTH = 64,
        parameter SPAGE_TLB_DEPTH   = 64,
        parameter LPAGE_TLB_DEPTH   = 64
)
(
        input wire              i_clk,
        input wire              i_reset,

        input wire  [31:0]      i_va,
        input wire              i_va_dav,
        input wire              i_rd_req,
        input wire              i_wr_req,
        input wire              i_user,

        input wire [31:0]       i_cfg_tr_base,
        input wire              i_cfg_tlb_flush,
        input wire              i_cfg_tlb_en,
        input wire [15:0]       i_cfg_dac,
        input wire              i_cfg_s_bit,

        output reg [31:0]       o_pa,          
        output reg              o_pa_dav,       
        output reg [3:0]        o_fsr,         
        output reg [3:0]        o_domain, 
        output reg              o_fault,        
        output reg [1:0]        o_ucb,

        output wire             o_flush_in_progress,
        output wire [31:0]      o_mem_addr,     
        output wire             o_mem_rd_en,    
        input  wire             i_mem_dav,
        input  wire [31:0]      i_mem_data
);

localparam L1_DESC_WDT = 32'd32;
localparam L2_DESC_WDT = 32'd32;

localparam [1:0] SECTION_ID = 2'd2;
localparam [1:0] PAGE_ID    = 2'd1;

localparam [1:0] SPAGE_ID   = 2'd2;
localparam [1:0] LPAGE_ID   = 2'd1;

wire [L1_DESC_WDT-1:0] l1_desc;
wire [L2_DESC_WDT-1:0] l2_desc;
wire                   dav;

// Domain access control bits.
localparam [1:0] NO_ACCESS = 2'd0;
localparam [1:0] CLIENT    = 2'd1;
localparam [1:0] RESERVED  = 2'd2;
localparam [1:0] MANAGER   = 2'd3;

// Access permissions + S bit
localparam [2:0] NA_NA     = 3'b000;
localparam [2:0] RO_NA     = 3'b001;
localparam [2:0] RW_NA     = 3'b01?;
localparam [2:0] RW_RO     = 3'b10?;
localparam [2:0] RW_RW     = 3'b11?;

`define DOMAIN 8:5

`define SECTION_BASE_ADDRESS 31:20
`define SECTION_INDEX        19:0
`define SECTION_AP           11:10

localparam [3:0] SEC_DOM_FAULT  = 4'b1001;
localparam [3:0] PAGE_DOM_FAULT = 4'b1011;
localparam [3:0] SEC_TRA_FAULT  = 4'b0101;
localparam [3:0] PAGE_TRA_FAULT = 4'b0111;
localparam [3:0] SEC_PERM_FAULT = 4'b1101;
localparam [3:0] PAGE_PERM_FAULT= 4'b1111;

always @*
begin
        o_fsr    = 4'd0;
        o_ucb    = 3'd0;
        o_fault  = 1'd0;
        o_domain = 4'd0;
        o_pa     = 32'd0;
        o_pa_dav = 1'd0;

        if ( dav )
        begin
                if ( !i_cfg_tlb_en )
                begin
                        o_pa     = i_va;
                        o_pa_dav = i_va_dav;
                end
                // Work out faults and what not.
                else if ( l1_desc[1:0] == SECTION_ID )
                begin
                                o_domain = l1_desc[`DOMAIN];
                                o_pa     = {l1_desc[`SECTION_BASE_ADDRESS], i_va[`SECTION_INDEX]};
                                o_ucb    = l1_desc[4:2];

                                // Look only in domain access control.
                                case ( i_cfg_dac [ o_domain ] )
                                        NO_ACCESS, RESERVED:
                                        begin
                                                o_fault  = 1'd1;
                                                o_fsr    = SEC_DOM_FAULT;                
                                        end
                                        CLIENT:
                                        begin
                                                // Look at access permissions = You can only generate SECTION TRANSLATION FAULTS.
                                                interpret_ap ( l1_desc[`SECTION_AP], i_cfg_s_bit, SEC_PERM_FAULT );
                                        end
                                        MANAGER:
                                        begin
                                                o_pa_dav = 1'd1;
                                        end
                                endcase
                end 
                else if ( l1_desc[1:0] == PAGE_ID )
                begin: blk199

                        reg [3:0] ap;

                        o_domain = l1_desc[`DOMAIN];
                        o_ucb    = {l1_desc[4], l2_desc[3:2]};
                        
                        if ( o_domain == MANAGER )
                        begin
                               // Do not check with AP. 
                               o_pa_dav = 1'd1;
                        end
                        else if ( o_domain == CLIENT )
                        begin
                                // Can generate only page permission fault.
                                // Check with AP. Each AP deals with 16KB of memory.
                                case ( i_va[15:14] ) 
                                        2'b00: ap = l2_desc [ 5:4 ] ;
                                        2'b01: ap = l2_desc [ 7:6 ] ;
                                        2'b10: ap = l2_desc [ 9:8 ] ;
                                        2'b11: ap = l2_desc [ 11:10 ] ;
                                endcase

                                // Based on that logic, use AP and S bit.
                                interpret_ap ( ap, i_cfg_s_bit, PAGE_PERM_FAULT );
                        end
                        else
                        begin
                                // Page domain fault.
                                o_fsr = PAGE_DOM_FAULT;
                        end

                        if ( l1_desc[1:0] == LPAGE_ID )
                                o_pa = {l2_desc[31:16], i_va[15:0]};
                        else if ( l1_desc[1:0] == SPAGE_ID )
                                o_pa = {l2_desc[31:12], i_va[11:0]}; 
                        else
                                o_fsr = PAGE_TRA_FAULT;
                end 
                else
                        o_fsr = SEC_TRA_FAULT;               
        end
end

task interpret_ap ( input [3:0] ap, input s, input [3:0] fault );
begin
      casez ( {ap, s} )
              NA_NA:
              begin
                      o_fault = 1'd1;
                      o_fsr   = fault; 
              end

              RO_NA:
              begin
                      if ( (i_wr_req) || (i_rd_req && i_user) ) // FAIL.
                      begin
                              o_fault = 1'd1;
                              o_fsr   = fault;
                      end
                      else
                      begin
                              o_pa_dav = 1'd1;
                      end
              end

              RW_NA:
              begin
                      if ( i_user ) // FAIL.
                      begin
                              o_fault = 1'd1;
                              o_fsr   = fault;
                      end
                      else
                      begin
                              o_pa_dav = 1'd1;
                      end
              end  

              RW_RO:
              begin
                      if ( (i_wr_req && i_user) ) // FAIL.
                      begin
                              o_fault = 1'd1;
                              o_fsr   = fault;
                      end
                      else
                      begin
                              o_pa_dav = 1'd1;
                      end
              end   

              RW_RW:
              begin
                      o_pa_dav = 1'd1;
              end                                                   
      endcase                                            
end
endtask

zap_mmu_get_desc #(
        .SECTION_TLB_DEPTH(SECTION_TLB_DEPTH), 
        .SPAGE_TLB_DEPTH(SPAGE_TLB_DEPTH), 
        .LPAGE_TLB_DEPTH(LPAGE_TLB_DEPTH)
) u_zap_mmu_get_desc (
        .i_clk                  (i_clk),
        .i_reset                (i_reset),

        .i_cfg_tr_base          (i_cfg_tr_base),
        .i_cfg_tlb_flush        (i_cfg_tlb_flush),
        .i_cfg_tlb_en           (i_cfg_tlb_en),

        .i_virt_addr            (i_va),
        .i_virt_addr_dav        (i_va_dav),

        .o_l1_desc              (l1_desc),
        .o_l2_desc              (l2_desc),
        .o_dav                  (dav),
        .o_flush_progress       (o_flush_in_progress),
        
        .o_mem_addr             (o_mem_addr),
        .o_mem_rd_en            (o_mem_rd_en),
        .i_mem_dav              (i_mem_dav),
        .i_mem_data             (i_mem_data)
);

endmodule
