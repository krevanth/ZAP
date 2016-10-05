module cdc_dual_flop
#(
        parameter WIDTH = 1
)
(
        input   i_clk,
        input   i_rst_n,
        input [WIDTH-1:0] i_sig,
        output [WIDTH-1:0] o_sig
);

reg [WIDTH-1:0] meta, sync;

assign o_sig = sync;

always @ (posedge i_clk or negedge i_rst_n)
begin
        if (!i_rst_n)
        begin
                sync <= 0;
                meta <= 0;
        end
        else
        begin
                sync <= meta;
                meta <= i_sig;
        end
end

endmodule
