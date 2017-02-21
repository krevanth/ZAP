#!/usr/bin/perl -w

use strict;
use warnings;

###############################################################################
# Perl script to simulate the ZAP processor. This script itself calls other
# scripts and programts.
# 1. The script compiles asm and C files into an BIN image.
# 2. The BIN file is converter into a set of Verilog assignments (Memory Image).
# 3. The simulation is run using the generated memory image.
# 4. The post processing script is applied on the generated log file.
#
# Usage :
# perl run_sim.pl <optional seed value>
###############################################################################

my $rand;
my $force_seed;

        if ( @ARGV == 1 )        {
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
my $EXPECTED_OUTPUT = "/tmp/expected_factorial_output.txt";

check_ivl_version();

# Compilation.
print "PROG_PATH = $PROG_PATH\n";
system("rm -fv $LOG_FILE_PATH $VVP_PATH $VCD_PATH $PROG_PATH $TARGET_BIN_PATH $PROG_PATH");
system("date | tee $LOG_FILE_PATH");
system("ls -l | tee -a $LOG_FILE_PATH");
die "*E: Translation Failed!" if system("perl $ZAP_HOME/scripts/do_it.pl $ASM_PATH $C_PATH $LINKER_PATH $TARGET_BIN_PATH $PROG_PATH");
die "*E: Bin2Mem Failed!" if system("perl $ZAP_HOME/scripts/bin2mem.pl $TARGET_BIN_PATH $PROG_PATH");


unless ( defined($force_seed) ) {
       $rand           = int rand(0xffffffff); }
else {
        $rand = $force_seed }

print "Rand is $rand...\n";

die "*E: Verilog Compilation Failed!\n" if system("iverilog -v -f $RTL_FILE_LIST -f $BENCH_FILE_LIST -o $VVP_PATH -g2001 -Winfloop -Wall -DSEED=$rand");
die "*E: VVP execution error!\n" if system("vvp $VVP_PATH >> $LOG_FILE_PATH");

# Check for success or failure.
die "*E: Bad config.vh for synthesis! Please check!\n" unless system("grep \\*E $LOG_FILE_PATH");

# A custom perl script to analyze the output log.

if ( @ARGV == 2 )
{
        print "Writing to $EXPECTED_OUTPUT...\n";
        die "*E: Could not post-process the log file!\n" if system("$POST_PROCESS | tee $EXPECTED_OUTPUT");
}
else
{
        print "Writing to curr_ZAP.txt\n";
        die "*E: Could not post-process the log file!\n" if system("$POST_PROCESS | tee /tmp/curr_ZAP.txt");
}

# If you provide an argument. The script looks for $EXPECTED_OUTPUT
if ( @ARGV == 2 )
{
        print "Second argument provided. Performing check...\n";
        die "*E: Diff returned some differences between current and expected ouptut" if system("diff /tmp/curr_ZAP.txt $EXPECTED_OUTPUT");
}

# Run GTKWAVE.
if ( @ARGV == 0 )
{
        die "*E: GTKWave file open Error!\n" if system("gtkwave $VCD_PATH &");
}

# Exit
print "*** Exited with return value 0 ***\n";
exit 0;

###############################################################################

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






