`default_nettype none

/*
Filename --
zap_multiply.v

Description --
A 32x32 multiplier using 16x16 multipliers. Takes 4 cycles to perform
a multiply-accumulate operation. Long multiplication (M) is not supported. 

Author --
Revanth Kamaraj
*/

module zap_multiply
#(
        parameter PHY_REGS = 46,
        parameter ALU_OPS   = 32
)
(
        input wire                              i_clk,
        input wire                              i_reset,

        input wire                              i_clear_from_writeback,
        input wire                              i_data_stall,
        input wire                              i_clear_from_alu,

        input wire   [$clog2(ALU_OPS)-1:0]      i_alu_operation_ff,
        input wire                              i_cc_satisfied,

        input wire [31:0]                       i_rm,
        input wire [31:0]                       i_rn,
        input wire [31:0]                       i_rh,
        input wire [31:0]                       i_rs,        // rm.rs + {rh,rn}. For non ACC versions, rn = 0x0 and rh = 0x0.

        output reg  [31:0]                      o_rd,
        output reg                              o_busy
);

`include "opcodes.vh"

wire higher = i_alu_operation_ff[0];
wire sign   = (i_alu_operation_ff == SMLALL || i_alu_operation_ff == SMLALH);

wire signed [16:0] a;
wire signed [16:0] b;
wire signed [16:0] c;
wire signed [16:0] d;
reg signed [63:0] x_ff, x_nxt;
wire signed [63:0] ab, ad, bc, cd;

assign a = sign ? {i_rm[31], i_rm[31:16]} : {1'd0, i_rm[31:16]};
assign b = sign ? {i_rs[31], i_rs[31:16]} : {1'd0, i_rs[31:16]};
assign c = {1'd0, i_rm[15:0]}; 
assign d = {1'd0, i_rs[15:0]};

// Aliases.
assign ab = a * b;
assign ad = a * d;
assign bc = b * c;
assign cd = c * d;

// States
localparam IDLE = 0;
localparam S1   = 1;
localparam S2   = 2;
localparam S3   = 3;
localparam S4   = 4;
localparam S5   = 5;
localparam S6   = 6;
localparam NUMBER_OF_STATES = 7;

reg [$clog2(NUMBER_OF_STATES)-1:0] state_ff, state_nxt;

always @*
begin
        o_busy = 1'd1;
        o_rd   = 32'd0;
        state_nxt = state_ff;
        x_nxt = x_ff;        

        case ( state_ff )
                IDLE:
                begin
                        o_busy = 1'd0;
                        x_nxt  = 32'd0;

                        // If we have the go signal.
                        if ( i_cc_satisfied && (i_alu_operation_ff == UMLALL || i_alu_operation_ff == UMLALH || i_alu_operation_ff == SMLALL || i_alu_operation_ff == SMLALH) )
                        begin
                                o_busy = 1'd1;
                                state_nxt = S1;
                        end
                end
                S1:
                begin
                        x_nxt     = x_ff + (cd << 0);                        
                        state_nxt = S2;
                end
                S2:
                begin
                        state_nxt = S3;
                        x_nxt     = x_ff + (ab << 32);
                end
                S3:
                begin
                        state_nxt = S4;
                        x_nxt     = x_ff + (ad << 16);
                end
                S4:
                begin
                        state_nxt = S5;
                        x_nxt    = x_ff + (bc << 16);
                end
                S5:
                begin
                        state_nxt = S6;
                        x_nxt     = x_ff + {i_rh, i_rn};
                end
                S6:
                begin
                        state_nxt = IDLE;
                        o_busy    = 1'd0;
                        o_rd      = higher ? x_ff[63:32] : x_ff[31:0];
                end
        endcase
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                x_ff     <= 63'd0;
                state_ff <= IDLE;
        end
        else if ( i_clear_from_writeback )
        begin
                x_ff     <= 63'd0;
                state_ff <= IDLE; 
        end
        else if ( i_data_stall )
        begin
                // Hold values
        end
        else if ( i_clear_from_alu )
        begin
                x_ff     <= 63'd0;
                state_ff <= IDLE;
        end
        else
        begin
                x_ff <= x_nxt;
                state_ff <= state_nxt;
        end
end

endmodule
