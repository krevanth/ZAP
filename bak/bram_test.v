module bram_test;

bit i_clk;
bit i_clk_2x;
bit i_reset;
bit i_wen;
bit [5:0] i_wr_addr_a, i_wr_addr_b;
bit [31:0] i_wr_data_a, i_wr_data_b;
bit [5:0] i_rd_addr_a, i_rd_addr_b, i_rd_addr_c, i_rd_addr_d;
logic [31:0] o_rd_data_a, o_rd_data_b, o_rd_data_c, o_rd_data_d;

bram_wrapper UUT (.*);

always #10 i_clk++;

initial
begin
        #5;
        forever #5 i_clk_2x++;
end

initial
begin
        $dumpfile("bram.vcd");
        $dumpvars;

        i_reset = 1'd1;
        @(negedge i_clk);
        i_reset = 1'd0;

        @(posedge i_clk);
        i_wr_addr_a <= 0;
        i_wr_addr_b <= 1;
        i_wr_data_a <= 5;
        i_wr_data_b <= 6;
        i_wen       <= 1'd1;

        @(posedge i_clk);
        i_wr_addr_a <= 2;
        i_wr_addr_b <= 3;
        i_wr_data_a <= 1;
        i_wr_data_b <= 2;
        i_wen       <= 1'd1;
        i_rd_addr_a <= 0;
        i_rd_addr_b <= 1;
        i_rd_addr_c <= 2;
        i_rd_addr_d <= 3;

        @(posedge i_clk);
        i_wen       <= 0;

        #100;

        $finish;
end

endmodule
