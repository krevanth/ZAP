# A sample command to run test without cache.
xterm -e 'perl run_sim.pl +zap_root+../../ +sim +test+factorial +ram_size+65536 +dump_start+1990+100 +scratch+/tmp +irq_en +max_clock_cycles+100000 +bp+1024 +fifo+4 +rtl_file_list+../rtl/rtl_files.list +tb_file_list+../tb/bench_files.list +cmmu_en +cache_size+1024+1024 +dtlb+8+8+8 +itlb+8+8+8 +post_process+post_process.pl;cat' 
