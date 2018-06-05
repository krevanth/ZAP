#!/usr/bin/perl -w

#// -----------------------------------------------------------------------------
#// --                                                                         --
#// --                   (C) 2016-2018 Revanth Kamaraj.                        --
#// --                                                                         -- 
#// -- --------------------------------------------------------------------------
#// --                                                                         --
#// -- This program is free software; you can redistribute it and/or           --
#// -- modify it under the terms of the GNU General Public License             --
#// -- as published by the Free Software Foundation; either version 2          --
#// -- of the License, or (at your option) any later version.                  --
#// --                                                                         --
#// -- This program is distributed in the hope that it will be useful,         --
#// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
#// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
#// -- GNU General Public License for more details.                            --
#// --                                                                         --
#// -- You should have received a copy of the GNU General Public License       --
#// -- along with this program; if not, write to the Free Software             --
#// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
#// -- 02110-1301, USA.                                                        --
#// --                                                                         --
#// -----------------------------------------------------------------------------


my $HELP = "
###############################################################################

Perl script to simulate the ZAP processor. This script itself calls other
scripts and programs.

Usage :
perl run_sim.pl
+test+<test_case>           -- Run a specific test case.
+irq_en                     -- Configure TB to use IRQ.

###############################################################################
";

use strict;
use warnings;

my $FH;

my %Config = do "./Config.cfg";

# Env setup.
my $RAM_SIZE                    = $Config{'EXT_RAM_SIZE'}; 
my $SEED                        = $Config{'SEED'};      
my $SYNTHESIS                   = $Config{'SYNTHESIS'};
my $DUMP_START                  = $Config{'DUMP_START'};
my $DUMP_SIZE                   = $Config{'DUMP_SIZE'};
my $MAX_CLOCK_CYCLES            = $Config{'MAX_CLOCK_CYCLES'};
my $TLB_DEBUG                   = $Config{'DEFINE_TLB_DEBUG'};
my $STALL                       = $Config{'ALLOW_STALLS'};
my $TX_TERM                     = $Config{'UART_TX_TERMINAL'};
my $IRQ_EN                      = $Config{'IRQ_EN'};

# System configuration.
my $DATA_CACHE_SIZE             = $Config{'DATA_CACHE_SIZE'};
my $CODE_CACHE_SIZE             = $Config{'CODE_CACHE_SIZE'};
my $CODE_SECTION_TLB_ENTRIES    = $Config{'CODE_SECTION_TLB_ENTRIES'};
my $CODE_SPAGE_TLB_ENTRIES      = $Config{'CODE_SPAGE_TLB_ENTRIES'};
my $CODE_LPAGE_TLB_ENTRIES      = $Config{'CODE_LPAGE_TLB_ENTRIES'};
my $DATA_SECTION_TLB_ENTRIES    = $Config{'DATA_SECTION_TLB_ENTRIES'};
my $DATA_SPAGE_TLB_ENTRIES      = $Config{'DATA_SPAGE_TLB_ENTRIES'};
my $DATA_LPAGE_TLB_ENTRIES      = $Config{'DATA_LPAGE_TLB_ENTRIES'};
my $BP                          = $Config{'BP_DEPTH'};
my $FIFO                        = $Config{'INSTR_FIFO_DEPTH'};
my $SBUF_DEPTH                  = $Config{'STORE_BUFFER_DEPTH'};

# Leave this as is.
my $ZAP_HOME                    = "../../../";
my $TEST                        = "null";
my $SCRATCH                     = "/dev/null";
my $FIQ_EN                      = 0; 

if ( $SEED == -1 ) {
                $SEED = randSeed();
}

sub randSeed {
        return int rand (0xffffffff);
}

foreach(@ARGV) {
        if (/^\+test\+(.*)/)                 
        { 
                $SCRATCH = "$ZAP_HOME/obj/ts/$1"; $TEST = $1; 
        }
        elsif (/help/)                          
        { 
                print "$HELP"; exit 0  
        }
        else                                    
        { 
                die "Unrecognized $_  $HELP"; 
        }
}

if ( $TEST eq "null" ) {
        print "$HELP";
        die "ERROR: +test+<testname> not specified!";
}

my $LOG_FILE_PATH   = "$SCRATCH/zap.log";
my $VVP_PATH        = "$SCRATCH/zap.vvp";
my $VCD_PATH        = "$SCRATCH/zap.vcd";
my $PROG_PATH       = "$SCRATCH/zap_mem.v";
my $TARGET_BIN_PATH = "$SCRATCH/zap.bin";
my $UART_PATH       = "$SCRATCH/zapuart.fifo";

# Generate IVL options.
my $IVL_OPTIONS .= 
" -I$ZAP_HOME/src/rtl/cpu -I$ZAP_HOME/obj/ts/$TEST -I$ZAP_HOME/src/testbench/cpu/uart16550/rtl $ZAP_HOME/src/testbench/cpu/uart16550/rtl/*.v $ZAP_HOME/src/testbench/cpu/timer/timer.v  $ZAP_HOME/src/testbench/cpu/vic/vic.v";

   $IVL_OPTIONS .= " $ZAP_HOME/src/rtl/*/*.v $ZAP_HOME/src/testbench/cpu/*.v -o $VVP_PATH -gstrict-ca-eval -Wall -g2001 -Winfloop -DSEED=$SEED -DMEMORY_IMAGE=\\\"$PROG_PATH\\\" ";

$IVL_OPTIONS .= " -DVCD_FILE_PATH=\\\"$VCD_PATH\\\" "; 

if ( $TX_TERM) { 
        $IVL_OPTIONS .= " -DUART_FILE_PATH=\\\"$UART_PATH\\\" "; 
} else {
        $IVL_OPTIONS .= " -DUART_FILE_PATH=\\\"/dev/null\\\" ";
}

$IVL_OPTIONS .= " -Pzap_test.RAM_SIZE=$RAM_SIZE -Pzap_test.START=$DUMP_START -Pzap_test.COUNT=$DUMP_SIZE -DLINUX -Pzap_test.STORE_BUFFER_DEPTH=$SBUF_DEPTH ";
$IVL_OPTIONS .= " -Pzap_test.BP_ENTRIES=$BP -Pzap_test.FIFO_DEPTH=$FIFO ";
$IVL_OPTIONS .= " -Pzap_test.DATA_SECTION_TLB_ENTRIES=$DATA_SECTION_TLB_ENTRIES ";
$IVL_OPTIONS .= " -Pzap_test.DATA_LPAGE_TLB_ENTRIES=$DATA_LPAGE_TLB_ENTRIES -Pzap_test.DATA_SPAGE_TLB_ENTRIES=$DATA_SPAGE_TLB_ENTRIES -Pzap_test.DATA_CACHE_SIZE=$DATA_CACHE_SIZE ";
$IVL_OPTIONS .= " -Pzap_test.CODE_SECTION_TLB_ENTRIES=$CODE_SECTION_TLB_ENTRIES -Pzap_test.CODE_LPAGE_TLB_ENTRIES=$CODE_LPAGE_TLB_ENTRIES -Pzap_test.CODE_SPAGE_TLB_ENTRIES=$CODE_SPAGE_TLB_ENTRIES ";
$IVL_OPTIONS .= " -Pzap_test.CODE_CACHE_SIZE=$CODE_CACHE_SIZE ";
$IVL_OPTIONS .= "-DMAX_CLOCK_CYCLES=$MAX_CLOCK_CYCLES ";

if ( $IRQ_EN )          {        print "Script: IRQ defined.\n" ; $IVL_OPTIONS .= "-DIRQ_EN ";   }
if ( $FIQ_EN )          {        $IVL_OPTIONS .= "-DFIQ_EN ";   }
if ( $STALL )           {        print "Script: Stall defined.\n" ; $IVL_OPTIONS .= "-DSTALL ";    }
if ( $SYNTHESIS )       {        $IVL_OPTIONS .= "-DSYNTHESIS ";}

if ( $MAX_CLOCK_CYCLES == 0 )   {  die "*E: MAX_CLOCK_CYCLES set to 0. Ending script...";  }
if ( $TLB_DEBUG )               {  print "Warning: TLB_DEBUG defined. Do not use for unattended systems!"; $IVL_OPTIONS .= "-DTLB_DEBUG ";}

open(HH, ">$ZAP_HOME/obj/ts/$TEST/zap_check.vh") or die "Could not write to ../../../obj/ts/$TEST/zap_check.vh";

my $X = $Config{'FINAL_CHECK'}; 

foreach(keys (%$X)) {
        my $string = "$_, $$X{$_}, U_MODEL_RAM_DATA.ram[$_]";
        print    "if ( U_MODEL_RAM_DATA.ram[$_/4] != ", $$X{"$_"}, ') begin $display("Error: Memory values not matched. PTR = %d EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("RAM check passed!");',"\n";
        print HH "if ( U_MODEL_RAM_DATA.ram[$_/4] != ", $$X{"$_"}, ') begin $display("Error: Memory values not matched. PTR = %d EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("RAM check passed!");',"\n";
}

$X = $Config{'REG_CHECK'};

my $REG_HIER = "u_zap_top.u_zap_core.u_zap_writeback.u_zap_register_file";

foreach(keys (%$X)) {
        my $string = "\"$_\", $$X{$_}, $REG_HIER.$_";
        print    "if ( $REG_HIER.$_ != ", $$X{"$_"}, ') begin $display("Error: Register values not matched. PTR = %s EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("Reg check passed!");',"\n";
        print HH "if ( $REG_HIER.$_ != ", $$X{"$_"}, ') begin $display("Error: Register values not matched. PTR = %s EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("Reg check passed!");',"\n";
}

print HH '$display("Simulation Complete. All checks (if any) passed.");$finish;';

print "*I: Rand is $SEED...\n";
print "iverilog $IVL_OPTIONS\n";

if ( $TX_TERM ) {
        system("rm -f $UART_PATH");    # Remove UART file.
        system("mknod $UART_PATH p");  # Create a UART output FIFO file.
}

# UART output monitor.
die "Error: XTerm could not be found!" if system("which xterm");
die "Error: Icarus Verilog could not be found!" if system("which iverilog");

if ( $TX_TERM == 1 ) {
        print "Setting up UART output monitor\n";
        system("xterm -T 'TB UART Output' -hold -e 'cat $UART_PATH ; echo ; echo ------------------ ; echo UART_Output_Complete ; echo ------------------' &");
}

die "*E: Verilog Compilation Failed!\n" if system("iverilog $IVL_OPTIONS");
die "*E: VVP execution error!\n" if system("vvp $VVP_PATH | tee $LOG_FILE_PATH");

die "*E: Errors occurred! Please grep for Errors in $LOG_FILE_PATH\n"       unless system("grep Error   $LOG_FILE_PATH");
die "*E: There were Warnings! Please grep for Warnings in $LOG_FILE_PATH\n" unless system("grep Warning $LOG_FILE_PATH");

exit 0;


