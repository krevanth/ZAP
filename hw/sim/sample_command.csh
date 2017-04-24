# A sample command to run test without cache.
perl run_sim.pl +zap_root+../../ +sim +test+factorial +ram_size+32768 +dump_start+1992+10 +scratch+/tmp +irq_en +max_clock_cycles+100000 +bp+1024 +fifo+4 +rtl_file_list+../rtl/rtl_files.list +tb_file_list+../tb/bench_files.list +post_process+post_process.pl 
