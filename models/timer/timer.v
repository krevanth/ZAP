`default_nettype none

module timer
(
        input wire          i_clk,
        input wire          i_reset,

        input wire  [31:0]  i_arm_val,
        input wire          i_arm_en,

        input wire          i_start,
        input wire          i_ack,

        output  reg [31:0]  o_count,
        output  reg         o_done    
);

parameter IDLE   =      0;
parameter READY  =      1;
parameter COUNT  =      2;
parameter WFA    =      3;

reg [1:0] state_ff, state_nxt;
reg [31:0] count_ff, count_nxt;
reg done_ff, done_nxt;

assign o_count = count_ff;
assign o_done  = done_ff;

always @*
begin
        done_nxt = done_ff;
        count_nxt = count_ff;

        case ( state_ff )
        IDLE:
        begin
                done_nxt = 1'd0;

                if ( i_arm_en )
                begin
                        state_nxt = READY;
                        count_nxt = i_arm_val;
                end
                else
                        state_nxt = IDLE:
        end

        READY:
        begin
                done_nxt = 1'd0;

                if ( i_start )
                        state_nxt = COUNT;
                else
                        state_nxt = READY;
        end

        COUNT:
        begin
                count_nxt = count_ff - 32'd1;

                if ( !count_nxt )
                begin
                        state_nxt = WFA;
                        done_nxt  = 1'd1;
                end
                else
                begin
                        state_nxt = COUNT;
                        done_nxt  = 1'd0;
                end
        end

        WFA:
        begin
                if ( i_ack )
                        state_nxt = IDLE;
                else
                        state_nxt = WFA;
        end
        endcase
end

always @ (posedge i_clk)
        state_ff <= i_reset ? IDLE : state_nxt;

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                done_ff  <= 1'd0;
                count_ff <= 32'd0;
        end
        else
        begin
                done_ff  <= done_nxt;
                count_ff <= count_nxt;
        end
end

endmodule
