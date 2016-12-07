#!/usr/bin/perl -w

use strict;
use warnings;

my $rand;
my $force_seed;

        if ( @ARGV )        {
                $force_seed = $ARGV[0];
        }
        else        {
                undef $force_seed;
        }

my $ZAP_HOME        = "/proj/ZAP";  # Modify this according to your system configuration. Do not add trailing slash!
my $LOG_FILE_PATH   = "/tmp/zap.log";
my $VVP_PATH        = "/tmp/zap.vvp";
my $VCD_PATH        = "/tmp/zap.vcd";
my $MEMORY_IMAGE    = "/tmp/prog.v";
my $PROG_PATH       = $MEMORY_IMAGE;
my $ASM_PATH        = "$ZAP_HOME/sw/asm/prog.s";
my $C_PATH          = "$ZAP_HOME/sw/c/fact.c";
my $LINKER_PATH     = "$ZAP_HOME/scripts/linker.ld";
my $TARGET_BIN_PATH = "/tmp/prog.bin";
my $POST_PROCESS    = "perl $ZAP_HOME/scripts/post_process.pl $LOG_FILE_PATH";
my $RTL_FILE_LIST   = "$ZAP_HOME/run/rtl_files.list";
my $BENCH_FILE_LIST = "$ZAP_HOME/run/bench_files.list";

check_ivl_version();

# Compilation.
print "PROG_PATH = $PROG_PATH\n";
system("rm -fv $LOG_FILE_PATH $VVP_PATH $VCD_PATH $PROG_PATH $TARGET_BIN_PATH $PROG_PATH");
system("date | tee $LOG_FILE_PATH");
system("ls -l | tee -a $LOG_FILE_PATH");
die "*E: Translation Failed!" if system("perl $ZAP_HOME/scripts/do_it.pl $ASM_PATH $C_PATH $LINKER_PATH $TARGET_BIN_PATH $PROG_PATH");
die "*E: Bin2Mem Failed!" if system("perl $ZAP_HOME/scripts/bin2mem.pl $TARGET_BIN_PATH $PROG_PATH");

while (1)
{

        unless ( defined($force_seed) ) {
               $rand           = int rand(0xffffffff); }
        else {
                $rand = $force_seed }

        print "Rand is $rand...\n";

        die "*E: Verilog Compilation Failed!\n" if system("iverilog -v -f $RTL_FILE_LIST -f $BENCH_FILE_LIST -o $VVP_PATH -g2001 -Winfloop -Wall -DSEED=$rand");
        die "*E: VVP execution error!\n" if system("vvp $VVP_PATH >> $LOG_FILE_PATH");

        # A custom perl script to analyze the output log.
        die "*E: Could not post-process the log file!\n" if system("$POST_PROCESS > current_output");

        # Run GTKWAVE.
        #die "*E: GTKWave file open Error!\n" if system("gtkwave $VCD_PATH &");

        # Check fail status.
        die "Simulation failed. Random was $rand for this run...\n" if system("diff current_output expected_output");

        # Successful.
        print "**************** SUCCESS! RUNNING AGAIN... ************************\n";

        if ( defined($force_seed) )
        {
                print "Seed was forced. Exiting without looping...\n";
                exit;
        }
}
# Guard.
sub check_ivl_version {
        my $x = `iverilog -V`;
        
        if ( $x !~ m/^Icarus Verilog version 10.0 \(stable\) \(v10_0\)\n/ )
        {
                print "*W: ZAP has been tested with Icarus Verilog 10.0 set to Verilog-2001 mode. Running on other versions of the compiler in other modes MAY result in differing behavior.\n"        ;
                print "*W: Press a key to continue running the simulation.";
                my $NULL = <STDIN>;
        }
        else
        {
                print "*I: Compiler version check passed!\n";
        }
}






