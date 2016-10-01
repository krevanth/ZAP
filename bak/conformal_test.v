/*
 * Ensures RAM and BRAM have the same functionality.
 */

module conf_test;

bit           i_clk;
bit           i_clk_2x;

bit             i_reset;

bit   [5:0]   i_wr_addr_a;
bit   [5:0]   i_wr_addr_b;

bit   [5:0]   i_rd_addr_a;
bit   [5:0]   i_rd_addr_b;
bit   [5:0]   i_rd_addr_c;
bit   [5:0]   i_rd_addr_d;

bit   [31:0]  i_wr_data_a; 
bit   [31:0]  i_wr_data_b;

bit           i_wen;

logic [31:0]  o_rd_data_a, o_rd_data_b, o_rd_data_c, o_rd_data_d;
logic [31:0]  O_RD_DATA_A, O_RD_DATA_B, O_RD_DATA_C, O_RD_DATA_D;

bram_wrapper bram_wrapper
(
.*
);

ram ram
(
.*,
.o_rd_data_a(O_RD_DATA_A),
.o_rd_data_b(O_RD_DATA_B),
.o_rd_data_c(O_RD_DATA_C),
.o_rd_data_d(O_RD_DATA_D)
);

always #10 i_clk++;

initial
begin
        #5;
        forever #5 i_clk_2x++;
end

initial
begin
        $dumpfile("conf.vcd");
        $dumpvars;

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        forever
        begin
                @(posedge i_clk);
                i_wen       <= $random;
                i_wr_addr_a <= $random;
                i_wr_addr_b <= $random;
                i_rd_addr_a <= $random;
                i_rd_addr_b <= $random;
                i_rd_addr_c <= $random;
                i_rd_addr_d <= $random;
                i_wr_data_a <= $random;
                i_wr_data_b <= $random;
        end
end

always @ (negedge i_clk)
begin
        #1;
        $display("o_rd_data_a = %d O_RD_DATA_A = %d", o_rd_data_a, O_RD_DATA_A);
        $display("o_rd_data_b = %d O_RD_DATA_B = %d", o_rd_data_b, O_RD_DATA_B);
        $display("o_rd_data_c = %d O_RD_DATA_C = %d", o_rd_data_c, O_RD_DATA_C);
        $display("o_rd_data_d = %d O_RD_DATA_D = %d", o_rd_data_d, O_RD_DATA_D);
        $display("<===========================================================>");

        if ( o_rd_data_a == O_RD_DATA_A ) $display("OK!"); else $display("FAIL A!");
        if ( o_rd_data_b == O_RD_DATA_B ) $display("OK!"); else $display("FAIL B!");
        if ( o_rd_data_c == O_RD_DATA_C ) $display("OK!"); else $display("FAIL C!");
        if ( o_rd_data_d == O_RD_DATA_D ) $display("OK!"); else $display("FAIL D!");
end

initial #20000 $finish;

endmodule
