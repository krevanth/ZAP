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
(
        input wire           i_clk,
        input wire           i_reset,

        input wire           i_clear,
        input wire           i_start,

        input wire [31:0]    i_rm,
        input wire [31:0]    i_rn,
        input wire [31:0]    i_rs, // rm.rs + rn

        output [31:0]   o_rd,
        output reg      o_busy
);

// Machine state.
reg [2:0] state_ff, state_nxt;

// Partial products.
reg [15:0] prodlolo_ff, prodlohi_ff, prodhilo_ff;
reg [15:0] prodlolo_nxt, prodlohi_nxt, prodhilo_nxt;
reg [31:0] out_ff, out_nxt;

assign o_rd = out_nxt; // Output.

// Parameter
parameter IDLE = 0;
parameter SX   = 1;
parameter S0   = 2;
parameter S1   = 3;
parameter S2   = 4;
parameter S3   = 5;

always @*
begin
        prodlolo_nxt = prodlolo_ff;
        prodlohi_nxt = prodlohi_ff;
        prodhilo_nxt = prodhilo_ff;
        state_nxt    = state_ff;

        case ( state_ff )
                IDLE:
                begin
                        if ( i_start )
                        begin
                                state_nxt = SX;
                                o_busy = 1'd1;
                        end
                        else
                        begin
                                state_nxt = IDLE;
                                o_busy = 1'd0;
                        end
                end
                SX:
                begin
                        o_busy          = 1'd1;
                        state_nxt       = S0;
                        prodlolo_nxt    = i_rm[15:0] * i_rs[15:0];
                        out_nxt         = 32'd0;
                end
                S0:
                begin
                        o_busy          = 1'd1;
                        state_nxt       = S1;
                        prodlohi_nxt    = i_rm[15:0] * i_rs[31:16];
                end 
                S1:
                begin
                        o_busy          = 1'd1;
                        state_nxt       = S2;
                        prodhilo_nxt    = i_rm[31:16] * i_rs[15:0];
                        out_nxt         = prodlolo_ff + (prodlohi_ff << 16);
                end
                S2:
                begin
                       state_nxt = S3;
                       o_busy    = 1'd1;
                       out_nxt   = out_ff + (prodlohi_ff << 16); 
                end
                S3:
                begin
                        state_nxt = IDLE; 
                        out_nxt   = out_ff + i_rn;
                        o_busy    = 1'd0;
                end
        endcase
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                out_ff   <= 0;
                state_ff <= IDLE;
        end
        else
        begin
                state_ff <= state_nxt;
                out_ff   <= out_nxt;
        end
end

endmodule
