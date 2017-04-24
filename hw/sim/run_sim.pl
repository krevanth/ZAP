#!/usr/bin/perl -w

my $HELP = "
###############################################################################
Perl script to simulate the ZAP processor. This script itself calls other
scripts and programs.
1. The script compiles asm and C files into an BIN image.
2. The BIN file is converter into a set of Verilog assignments (Memory Image).
3. The simulation is run using the generated memory image.
4. The post processing script is applied on the generated log file.

NOTE: Please see sample_command.csh for a command sample.

Usage :
perl run_sim.pl
+zap_root+<root_directory>                                              -- Root directory of the ZAP project.
[+seed+<seed_value>]                                                    -- Force a specific seed for simulation.
[+sim]                                                                  -- Force register file debug and some extra error messages.
+test+<test_case>                                                       -- Run a specific test case. only +test+factorial is available, you may add new tests (see sw folder).
[+cmmu_en]                                                              -- Enable cache and MMU (highly unstable)
+ram_size+<ram_size>                                                    -- Set size of RAM in bench.
+dump_start+<start_addr_of_dump>+<number_of_words_in_dump>              -- Starting memory address to start logging and number of words to log.
[+cache_size+<data_cache_size>+<code_cache_size>]                       -- Specify data and I-cache size in bytes.
[+dtlb+<section_dtlb_entries>+<small_page_entries>+<large_page_entries> -- Specify data TLB entries for section, small and large page TLBs.
[+itlb+<section_itlb_entries>+<small_page_entries>+<large_page_entries> -- Specify I-TLB entries similarly as above.
[+irq_en]                                                               -- Trigger IRQ interrupts from bench.                                        
[+fiq_en]                                                               -- Trigger FIQ interrupts from bench.
+scratch+<scratch_dir>                                                  -- Set scratch directory. Usually set this to /tmp. VCD and logs go there.
+max_clock_cycles+<max_clock_cycles>                                    -- Set maximum clock cycles for which the simulation should run. 
+rtl_file_list+<rtl_file_list>                                          -- Specify RTL file list. See hw/rtl folder.
+tb_file_list+<tb_file_list>                                            -- Specify testbench file list. See hw/tb folder.
+bp+<branch_predictor_entries>                                          -- Number of entries in branch predictor memory.
+fifo+<fifo_depth>                                                      -- Depth of pre-fetch buffer in CPU.
+post_process+<post_process_perl_script_path>                           -- Point this to post_process.pl or any other Perl script. Script runs after sim.
+nodump                                                                 -- Do not write VCD. 
###############################################################################
";

use strict;
use warnings;

my $FH;

my $ZAP_HOME                    = "";
my $SEED                        = int rand (0xffffffff);
my $SIM                         = 0;
my $CACHE_MMU_ENABLE            = 0;
my $RAM_SIZE                    = 32768;
my $DUMP_START                  = 2000;
my $DUMP_SIZE                   = 200;
my $DATA_CACHE_SIZE             = 1024;
my $CODE_CACHE_SIZE             = 1024;
my $CODE_SECTION_TLB_ENTRIES    = 0;
my $CODE_SPAGE_TLB_ENTRIES      = 0;
my $CODE_LPAGE_TLB_ENTRIES      = 0;
my $DATA_SECTION_TLB_ENTRIES    = 0;
my $DATA_SPAGE_TLB_ENTRIES      = 0;
my $DATA_LPAGE_TLB_ENTRIES      = 0;
my $BP                          = 1024;
my $FIFO                        = 4;
my $IRQ_EN                      = 0;
my $FIQ_EN                      = 0;
my $MAX_CLOCK_CYCLES            = 0;
my $TEST                        = "null";
my $STALL                       = 0;
my $SCRATCH                     = "$ZAP_HOME/scratch";
my $RTL_FILE_LIST               = "$ZAP_HOME/hw/vlog/rtl/rtl_files.list";
my $BENCH_FILE_LIST             = "$ZAP_HOME/hw/vlog/tb/bench_files.list";
my $NODUMP                      = 0;
my $PPF                         = "null";
my $STAX                        = 0;

sub rand {
        return int rand (0xffffffff);
}

foreach(@ARGV) {
        if      (/^\+zap_root\+(.*)/)           { $ZAP_HOME = $1; }   
        elsif   (/^\+rtl_file_list\+(.*)/)      { $RTL_FILE_LIST = $1; }
        elsif   (/^\+tb_file_list\+(.*)/)       { $BENCH_FILE_LIST = $1; }
        elsif   (/^\+scratch\+(.*)/)            { $SCRATCH  = $1; }
        elsif   (/^\+seed\+(.*)/)               { $SEED     = $1; } 
        elsif   (/^\+sim/)                      { $SIM      = 1;  }
        elsif   (/^\+test\+(.*)/)               { $TEST     = $1; }
        elsif   (/^\+cmmu_en/)                  { $CACHE_MMU_ENABLE = 1; }
        elsif   (/^\+ram_size\+(.*)/)           { $RAM_SIZE = $1; }
        elsif   (/^\+dump_start\+(.*)\+(.*)/)   { $DUMP_START = $1; $DUMP_SIZE = $2; }
        elsif (/^\+cache_size\+(.*)\+(.*)/)      {
                        print "Cache size given as DATA_CACHE = $1 CODE_CACHE = $2 bytes...\n";
                        $DATA_CACHE_SIZE = $1; $CODE_CACHE_SIZE = $2; 
        }
        elsif (/^\+itlb\+(.*)\+(.*)\+(.*)/)     { $CODE_SECTION_TLB_ENTRIES = $1 ; $CODE_SPAGE_TLB_ENTRIES = $2 ; $CODE_LPAGE_TLB_ENTRIES = $3; } 
        elsif (/^\+dtlb\+(.*)\+(.*)\+(.*)/)     { $DATA_SECTION_TLB_ENTRIES = $1 ; $DATA_SPAGE_TLB_ENTRIES = $2 ; $DATA_LPAGE_TLB_ENTRIES = $3; } 
        elsif (/^\+irq_en/)                     { $IRQ_EN = 1; }
        elsif (/^\+fiq_en/)                     { $FIQ_EN = 1; }
        elsif (/^\+max_clock_cycles\+(.*)/)     { $MAX_CLOCK_CYCLES = $1; }  
        elsif (/help/)                          { print "$HELP"; exit 0  }
        elsif (/^\+bp\+(.*)/)                   { $BP = $1; }
        elsif (/^\+fifo\+(.*)/)                 { $FIFO = $1; }
        elsif (/^\+nodump/)                     { $NODUMP = 1; } 
        elsif (/^\+post_process\+(.*)/)         { $PPF = $1; }
        elsif (/^\+stax/)                       { $STAX = 1; }
        else                                    { die "Unrecognized $_  $HELP"; }
}

if ( $TEST eq "null" ) {
        print "$HELP";
        die "ERROR: +test+<testname> not specified!";
}

$ENV{'ZAP_HOME'} = $ZAP_HOME;

my $LOG_FILE_PATH   = "$SCRATCH/zap.log";
my $VVP_PATH        = "$SCRATCH/zap.vvp";
my $VCD_PATH        = "$SCRATCH/zap.vcd";
my $PROG_PATH       = "$SCRATCH/zap_mem.v";
my $TARGET_BIN_PATH = "$SCRATCH/zap.bin";
my $POST_PROCESS    = "perl $PPF $LOG_FILE_PATH"; 
my $ASM_PATH        = "$ZAP_HOME/sw/$TEST/$TEST.s"; 
my $C_PATH          = "$ZAP_HOME/sw/$TEST/$TEST.c"; 
my $LINKER_PATH     = "$ZAP_HOME/sw/$TEST/$TEST.ld";

# Generate IVL options.
my $IVL_OPTIONS .= "-v -f $RTL_FILE_LIST -f $BENCH_FILE_LIST -o $VVP_PATH -gstrict-ca-eval -Wall -g2001 -Winfloop -DSEED=$SEED -DMEMORY_IMAGE=\\\"$PROG_PATH\\\" ";

if ( !$NODUMP ) {
        $IVL_OPTIONS .= "-DVCD_FILE_PATH=\\\"$VCD_PATH\\\" "; 
} else {
        $IVL_OPTIONS .= "-DVCD_FILE_PATH=\\\"/dev/null\\\" ";
}

$IVL_OPTIONS .= "-PCACHE_MMU_ENABLE=$CACHE_MMU_ENABLE -PRAM_SIZE=$RAM_SIZE -PSTART=$DUMP_START -PCOUNT=$DUMP_SIZE -DLINUX ";
$IVL_OPTIONS .= "-PBP_ENTRIES=$BP -PFIFO_DEPTH=$FIFO ";
$IVL_OPTIONS .= "-PDATA_SECTION_TLB_ENTRIES=$DATA_SECTION_TLB_ENTRIES -PDATA_LPAGE_TLB_ENTRIES=$DATA_LPAGE_TLB_ENTRIES -PDATA_SPAGE_TLB_ENTRIES=$DATA_SPAGE_TLB_ENTRIES -PDATA_CACHE_SIZE=$DATA_CACHE_SIZE ";
$IVL_OPTIONS .= "-PCODE_SECTION_TLB_ENTRIES=$CODE_SECTION_TLB_ENTRIES -PCODE_LPAGE_TLB_ENTRIES=$CODE_LPAGE_TLB_ENTRIES -PCODE_SPAGE_TLB_ENTRIES=$CODE_SPAGE_TLB_ENTRIES -PCODE_CACHE_SIZE=$CODE_CACHE_SIZE ";

if ( $IRQ_EN ) {
        $IVL_OPTIONS .= "-DIRQ_EN ";
}

if ( $FIQ_EN ) {
        $IVL_OPTIONS .= "=DFIQ_EN ";
}

if ( $STALL ) {
        $IVL_OPTIONS .= "-DSTALL ";
}

if ( $SIM ) {
        $IVL_OPTIONS .= "-DSIM ";
}

if ( $MAX_CLOCK_CYCLES == 0 ) {
        die "*E: MAX_CLOCK_CYCLES set to 0. Ending script...";
}

$IVL_OPTIONS .= "-DMAX_CLOCK_CYCLES=$MAX_CLOCK_CYCLES ";

# Compilation.
die "*E: Translation from C/ASM to binary failed!" if system("perl $ZAP_HOME/sw/tools/casm2bin.pl $ASM_PATH $C_PATH $LINKER_PATH $TARGET_BIN_PATH");

# Binary to mem translation.
die "*E: Binary to Verilog conversion failed!" if system("perl $ZAP_HOME/sw/tools/bin2vlog.pl $TARGET_BIN_PATH $PROG_PATH");

# Print SEED.
print "*I: Rand is $SEED...\n";

# Generate VVP.
print "iverilog $IVL_OPTIONS\n";

if ( !$STAX ) {
        die "*E: Verilog Compilation Failed!\n" if system("iverilog $IVL_OPTIONS");
} else {
        die "*E: Failed syntax check!\n" if system("iverilog $IVL_OPTIONS");
        exit;
}

# Run VVP.
die "*E: VVP execution error!\n" if system("vvp $VVP_PATH | tee $LOG_FILE_PATH");

# Check for success or failure.
die "*E: Bad config.vh for synthesis or some other fatal error! Please check!\n" unless system("grep \\*E $LOG_FILE_PATH");

# A custom perl script to analyze the output log.
die "*E: Could not post-process the log file!\n" if system("$POST_PROCESS");

# Run GTKWAVE.
die "*E: GTKWave file open Error!\n" if system("gtkwave $VCD_PATH &");

# Exit
exit 0;


