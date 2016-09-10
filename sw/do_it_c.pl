die "Usage: perl do_it_c.pl asm_file c_file" if (@ARGV != 2);
system("perl \$ZAP_HOME/sw/binc.pl $ARGV[0] $ARGV[1] \$ZAP_HOME/sw/linker/linker.ld prog.bin"); # ARGV[0] -> Assembler ARGV[1] -> C function.
system("perl \$ZAP_HOME/sw/bin2verilog.pl prog.bin > prog.v");
system("rm -f prog.bin");

