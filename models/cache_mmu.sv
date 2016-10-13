/*
 * Non synthesizeable model of cache+MMU for ZAP. Synthesizeable model coming soon!
 * Use -g2012 with icarus to run this.
 */

module zap_cache_mmu_nonsynth;

// Ports
bit             i_clk;
bit             i_reset;
bit     [31:0]  i_pc;



logic   [31:0]  o_data;
logic           o_fault;

endmodule
