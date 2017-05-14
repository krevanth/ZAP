// Merges two Wishbone busses onto a single bus. Released under GPL V2.
// (C)2017 Revanth Kamaraj.

`default_nettype none

module zap_wb_merger (

input wire i_clk,   
input wire i_reset,

input wire i_c_wb_stb,
input wire i_c_wb_cyc,
input wire i_c_wb_wen,
input wire [3:0] i_c_wb_sel,
input wire [31:0] i_c_wb_dat,
input wire [31:0] i_c_wb_adr,
input wire [2:0] i_c_wb_cti,
output reg o_c_wb_ack,

input wire i_d_wb_stb,
input wire i_d_wb_cyc,
input wire i_d_wb_wen,
input wire [3:0] i_d_wb_sel,
input wire [31:0] i_d_wb_dat,
input wire [31:0] i_d_wb_adr,
input wire [2:0] i_d_wb_cti,
output reg o_d_wb_ack,

output reg o_wb_cyc,
output reg o_wb_stb,
output reg o_wb_wen,
output reg [3:0] o_wb_sel,
output reg [31:0] o_wb_dat,
output reg [31:0] o_wb_adr,
output reg [2:0] o_wb_cti,
input wire i_wb_ack

);

`include "zap_defines.vh"
`include "zap_localparams.vh"

localparam CODE = 1'd0;
localparam DATA = 1'd1;

reg sel_ff, sel_nxt;

always @ (posedge i_clk)
begin
        if ( i_reset )
                sel_ff <= CODE;
        else
                sel_ff <= sel_nxt;
end

always @*
begin
        if ( sel_ff == CODE )
        begin
                o_c_wb_ack = i_wb_ack;
                o_d_wb_ack = 1'd0;
        end
        else
        begin
                o_d_wb_ack = i_wb_ack;
                o_c_wb_ack = 1'd0;
        end
end

always @*
begin
        case(sel_ff)
        CODE:
        begin
                if ( i_wb_ack && (o_wb_cti == CTI_CLASSIC || o_wb_cti == CTI_EOB) && i_d_wb_stb )
                        sel_nxt = DATA;
                else if ( !i_c_wb_stb && i_d_wb_stb )
                        sel_nxt = DATA;
                else
                        sel_nxt = sel_ff;
        end

        DATA:
        begin
                if ( i_wb_ack && (o_wb_cti == CTI_CLASSIC || o_wb_cti == CTI_EOB) && i_c_wb_stb )
                        sel_nxt = CODE;
                else if ( i_c_wb_stb && !i_d_wb_stb )
                        sel_nxt = CODE;
                else
                        sel_nxt = sel_ff;
        end
        endcase
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                o_wb_cyc <= 0;
                o_wb_stb <= 0;
                o_wb_wen <= 0;
                o_wb_sel <= 0;
                o_wb_dat <= 0;                                
                o_wb_adr <= 0;
                o_wb_cti <= 0;
        end
        else if ( sel_nxt == CODE )
        begin
                o_wb_cyc <= i_c_wb_cyc;
                o_wb_stb <= i_c_wb_stb;
                o_wb_wen <= i_c_wb_wen;
                o_wb_sel <= i_c_wb_sel;
                o_wb_dat <= i_c_wb_dat;                                
                o_wb_adr <= i_c_wb_adr;
                o_wb_cti <= i_c_wb_cti;               
        end
        else
        begin
                o_wb_cyc <= i_d_wb_cyc;
                o_wb_stb <= i_d_wb_stb;
                o_wb_wen <= i_d_wb_wen;
                o_wb_sel <= i_d_wb_sel;
                o_wb_dat <= i_d_wb_dat;                                
                o_wb_adr <= i_d_wb_adr;
                o_wb_cti <= i_d_wb_cti; 
        end
end

endmodule
