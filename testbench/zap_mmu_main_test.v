module zap_mmu_main_test;

        bit              i_clk;
        bit              i_reset;

        bit  [31:0]      i_va;
        bit              i_va_dav;
        bit              i_rd_req;
        bit              i_wr_req;
        bit              i_user;

        bit [31:0]       i_cfg_tr_base;
        bit              i_cfg_tlb_flush;
        bit              i_cfg_tlb_en;
        bit [15:0]       i_cfg_dac;
        bit              i_cfg_s_bit;

        wire [31:0]       o_pa;          
        wire              o_pa_dav;       
        wire [3:0]        o_fsr;         
        wire [3:0]        o_domain; 
        wire              o_fault;        
        wire [1:0]        o_ucb;
        wire             o_flush_in_progress;
        wire [31:0]      o_mem_addr;     
        wire             o_mem_rd_en;    

        bit             i_mem_dav;
        bit [31:0]      i_mem_data;

zap_mmu_main UUT (.*);

initial i_clk = 0;
always #1 i_clk++;

initial
begin
        $dumpfile("mmu.vcd");
        $dumpvars;
end

initial 
begin
        i_cfg_tr_base = 32'hffffffff;

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        repeat (2) 
                @(negedge i_clk);

        i_cfg_tlb_en = 1;

        while(o_flush_in_progress)
        @(negedge i_clk);
       

        i_va     <= 0;
        i_va_dav <= 1;

        @(negedge i_clk);
 
        i_va     <= 0;
        i_va_dav <= 0;

        while(o_mem_rd_en != 1)
                @(negedge i_clk);

        i_mem_dav  <= 1;
        i_mem_data <= 0;
end

initial #1000 $finish;

endmodule
