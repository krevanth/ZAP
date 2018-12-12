#!/usr/bin/perl -w

# -----------------------------------------------------------------------------
# --                                                                         --
# --                   (C) 2016-2018 Revanth Kamaraj.                        --
# --                                                                         -- 
# -- --------------------------------------------------------------------------
# --                                                                         --
# -- This program is free software; you can redistribute it and/or           --
# -- modify it under the terms of the GNU General Public License             --
# -- as published by the Free Software Foundation; either version 2          --
# -- of the License, or (at your option) any later version.                  --
# --                                                                         --
# -- This program is distributed in the hope that it will be useful,         --
# -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
# -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
# -- GNU General Public License for more details.                            --
# --                                                                         --
# -- You should have received a copy of the GNU General Public License       --
# -- along with this program; if not, write to the Free Software             --
# -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
# -- 02110-1301, USA.                                                        --
# --                                                                         --
# -----------------------------------------------------------------------------


use strict;
use warnings;

my %Config = do "./Config.cfg";

# Extract from config
my $RAM_SIZE                    = $Config{'EXT_RAM_SIZE'}; 
my $SEED                        = $Config{'SEED'};      
my $SYNTHESIS                   = $Config{'SYNTHESIS'};
my $DUMP_START                  = $Config{'DUMP_START'};
my $DUMP_SIZE                   = $Config{'DUMP_SIZE'};
my $MAX_CLOCK_CYCLES            = $Config{'MAX_CLOCK_CYCLES'};
my $TLB_DEBUG                   = $Config{'DEFINE_TLB_DEBUG'};
my $STALL                       = $Config{'ALLOW_STALLS'};
my $TX_TERM0                    = $Config{'UART0_TX_TERMINAL'};
my $TX_TERM1                    = $Config{'UART1_TX_TERMINAL'};
my $RX_TERM0                    = $Config{'UART0_RX_TERMINAL'};
my $RX_TERM1                    = $Config{'UART1_RX_TERMINAL'};
my $IRQ_EN                      = $Config{'IRQ_EN'};
my $FIQ_EN                      = $Config{'FIQ_EN'}; 
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

# Generate a random seed if needed
if ( $SEED == -1 ) {
                $SEED = int rand (0xffffffff);
}

# Parse arguments.
foreach(@ARGV) {
        if (/^\+test\+(.*)/) { 
                $SCRATCH = "$ZAP_HOME/obj/ts/$1"; $TEST = $1; 
        } else {
                die "Unrecognized option to run_sim.pl\n";
        }
}

# Log file - the final file is compressed.
my $LOG_FILE_PATH               = "$SCRATCH/zap.log";
my $COMPRESSED_LOG_FILE_PATH    = "$SCRATCH/zap.log.gz";

# VCD file - the final file is compressed.
my $VCD_PATH                    = "$SCRATCH/zap.vcd";
my $COMPRESSED_VCD_PATH         = "$SCRATCH/zap.vcd.gz";

# Paths
my $VVP_PATH                    = "$SCRATCH/zap.vvp";
my $PROG_PATH                   = "$SCRATCH/zap_mem.v";
my $TARGET_BIN_PATH             = "$SCRATCH/zap.bin";
my $UART0_PATH_TX               = "$SCRATCH/zapuart0.tx";
my $UART1_PATH_TX               = "$SCRATCH/zapuart1.tx";
my $UART0_PATH_RX               = "$SCRATCH/zapuart0.rx";
my $UART1_PATH_RX               = "$SCRATCH/zapuart1.rx";

# Generate IVL options including VCD generation path.
my $IVL_OPTIONS  = " -I$ZAP_HOME/src/rtl/cpu -I$ZAP_HOME/obj/ts/$TEST -I$ZAP_HOME/src/rtl/External_IP/uart16550/rtl            ";
   $IVL_OPTIONS .= "  $ZAP_HOME/src/rtl/External_IP/uart16550/rtl/*.v $ZAP_HOME/src/rtl/timer/timer.v  $ZAP_HOME/src/rtl/vic/vic.v $ZAP_HOME/src/rtl/ram/ram.v ";
   $IVL_OPTIONS .= "  $ZAP_HOME/src/rtl/cpu/*.v   ";
   $IVL_OPTIONS .= "  $ZAP_HOME/src/rtl/TOP/chip_top.v ";
   $IVL_OPTIONS .= "  $ZAP_HOME/src/testbench/*.v "; 
   $IVL_OPTIONS .= " -o $VVP_PATH -gstrict-ca-eval -Wall -g2001 -Winfloop -DSEED=$SEED -DMEMORY_IMAGE=\\\"$PROG_PATH\\\" ";
   $IVL_OPTIONS .= " -DVCD_FILE_PATH=\\\"$VCD_PATH\\\" "; 

# Generate UART related defines for both the UARTs.
if ( $TX_TERM0 ) { $IVL_OPTIONS .= " -DUART0_FILE_PATH_TX=\\\"$UART0_PATH_TX\\\" "; } else { $IVL_OPTIONS .= " -DUART0_FILE_PATH_TX=\\\"/dev/null\\\" "; }
if ( $TX_TERM1 ) { $IVL_OPTIONS .= " -DUART1_FILE_PATH_TX=\\\"$UART1_PATH_TX\\\" "; } else { $IVL_OPTIONS .= " -DUART1_FILE_PATH_TX=\\\"/dev/null\\\" "; }
if ( $RX_TERM0 ) { $IVL_OPTIONS .= " -DUART0_FILE_PATH_RX=\\\"$UART0_PATH_RX\\\" "; } else { $IVL_OPTIONS .= " -DUART0_FILE_PATH_RX=\\\"/dev/null\\\" "; }
if ( $RX_TERM1 ) { $IVL_OPTIONS .= " -DUART1_FILE_PATH_RX=\\\"$UART1_PATH_RX\\\" "; } else { $IVL_OPTIONS .= " -DUART1_FILE_PATH_RX=\\\"/dev/null\\\" "; }

# CPU / TB configuration related parameters.
$IVL_OPTIONS .= " -Pzap_test.RAM_SIZE=$RAM_SIZE -Pzap_test.START=$DUMP_START -Pzap_test.COUNT=$DUMP_SIZE -DLINUX -Pzap_test.STORE_BUFFER_DEPTH=$SBUF_DEPTH ";
$IVL_OPTIONS .= " -Pzap_test.BP_ENTRIES=$BP -Pzap_test.FIFO_DEPTH=$FIFO ";
$IVL_OPTIONS .= " -Pzap_test.DATA_SECTION_TLB_ENTRIES=$DATA_SECTION_TLB_ENTRIES ";
$IVL_OPTIONS .= " -Pzap_test.DATA_LPAGE_TLB_ENTRIES=$DATA_LPAGE_TLB_ENTRIES -Pzap_test.DATA_SPAGE_TLB_ENTRIES=$DATA_SPAGE_TLB_ENTRIES -Pzap_test.DATA_CACHE_SIZE=$DATA_CACHE_SIZE ";
$IVL_OPTIONS .= " -Pzap_test.CODE_SECTION_TLB_ENTRIES=$CODE_SECTION_TLB_ENTRIES -Pzap_test.CODE_LPAGE_TLB_ENTRIES=$CODE_LPAGE_TLB_ENTRIES -Pzap_test.CODE_SPAGE_TLB_ENTRIES=$CODE_SPAGE_TLB_ENTRIES ";
$IVL_OPTIONS .= " -Pzap_test.CODE_CACHE_SIZE=$CODE_CACHE_SIZE ";

# Defines
if ( 1       )          {        $IVL_OPTIONS .= " -DMAX_CLOCK_CYCLES=$MAX_CLOCK_CYCLES " };
if ( $IRQ_EN )          {        $IVL_OPTIONS .= "-DIRQ_EN ";                             }
if ( $FIQ_EN )          {        $IVL_OPTIONS .= "-DFIQ_EN ";                             }
if ( $STALL )           {        $IVL_OPTIONS .= "-DSTALL ";                              }
if ( $SYNTHESIS )       {        $IVL_OPTIONS .= "-DSYNTHESIS ";                          }
if ( $TLB_DEBUG )       {        $IVL_OPTIONS .= "-DTLB_DEBUG ";                          }

###########################################################################################################################################
# Create checker assertion verilog include file.
###########################################################################################################################################

open(HH, ">$ZAP_HOME/obj/ts/$TEST/zap_check.vh") or die "Could not write to ../../../obj/ts/$TEST/zap_check.vh";

my $REG_HIER = "u_chip_top.u_zap_top.u_zap_core.u_zap_writeback.u_zap_register_file";
my $RAM_HIER = "u_chip_top.u_ram.ram";
my $X = $Config{'FINAL_CHECK'}; 

foreach(keys (%$X)) {
        my $string = "$_, $$X{$_}, ${RAM_HIER}[$_/4]";
        print    "if ( ${RAM_HIER}[$_/4] != ", $$X{"$_"}, ') begin $display("Error: Memory values not matched. PTR = %d EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("RAM check passed!");',"\n";
        print HH "if ( ${RAM_HIER}[$_/4] != ", $$X{"$_"}, ') begin $display("Error: Memory values not matched. PTR = %d EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("RAM check passed!");',"\n";
}

$X = $Config{'REG_CHECK'};

foreach(keys (%$X)) {
        my $string = "\"$_\", $$X{$_}, $REG_HIER.$_";
        print    "if ( $REG_HIER.$_ != ", $$X{"$_"}, ') begin $display("Error: Register values not matched. PTR = %s EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("Reg check passed!");',"\n";
        print HH "if ( $REG_HIER.$_ != ", $$X{"$_"}, ') begin $display("Error: Register values not matched. PTR = %s EXP = %x REC = %x", ', $string , ' ); $finish; end else $display("Reg check passed!");',"\n";
}

print HH '$display("Simulation Complete. All checks (if any) passed.");$finish;';

############################################################################################################################################
# Set up UART terminals
############################################################################################################################################

if ( $TX_TERM0 ) {
        system1("rm -f $UART0_PATH_TX");    # Remove UART file.
        system1("mknod $UART0_PATH_TX p");  # Create a UART output FIFO file.
}

if ( $TX_TERM1 ) {
        system1("rm -f $UART1_PATH_TX");    # Remove UART file.
        system1("mknod $UART1_PATH_TX p");  # Create a UART output FIFO file.
}

if ( $RX_TERM0 ) {
        system1("rm -f $UART0_PATH_RX");    # Remove UART file.
        system1("touch $UART0_PATH_RX");    # Create file.
}

if ( $RX_TERM1 ) {
        system1("rm -f $UART1_PATH_RX");    # Remove UART file.
        system1("touch $UART1_PATH_RX");    # Create file.
}

die "Error: XTerm could not be found!" if system("which xterm");

if ( $TX_TERM0 ) {        die "Failed to open UART TX terminal 0." if system1("xterm -T 'TB UART Output' -hold -e 'cat $UART0_PATH_TX' &");                                                }
if ( $TX_TERM1 ) {        die "Failed to open UART TX terminal 1." if system1("xterm -T 'TB UART Output' -hold -e 'cat $UART1_PATH_TX' &");                                                }
if ( $RX_TERM0 ) {        die "Failed to open UART RX terminal 0." if system1("xterm -T 'TB UART Input'  -hold -e 'bash $ZAP_HOME/src/scripts/uart_input.bash $UART0_PATH_RX' &");         }
if ( $RX_TERM1 ) {        die "Failed to open UART RX terminal 1." if system1("xterm -T 'TB UART Input'  -hold -e 'bash $ZAP_HOME/src/scripts/uart_input.bash $UART1_PATH_RX' &");         }

#############################################################################################################################################
# Compile using VVP
#############################################################################################################################################

die "*E: Verilog Compilation Failed!\n"  if system1("iverilog $IVL_OPTIONS");
die "*E: Failed to read out Log FIFO!\n" if system1("rm -f $LOG_FILE_PATH ; mkfifo $LOG_FILE_PATH ; cat $LOG_FILE_PATH | gzip  > $COMPRESSED_LOG_FILE_PATH &");
die "*E: Failed to read out VCD FIFO!\n" if system1("rm -f $VCD_PATH      ; mkfifo $VCD_PATH      ; cat $VCD_PATH      | gzip  > $COMPRESSED_VCD_PATH &");
die "*E: VVP execution error!\n"         if system1("vvp $VVP_PATH | tee $LOG_FILE_PATH");

###############################################################################################################################################
# Scan for errors and warnings.
###############################################################################################################################################

die "*E: Errors occurred! Please grep for Errors in $COMPRESSED_LOG_FILE_PATH\n"       unless system("zcat $COMPRESSED_LOG_FILE_PATH | grep Error");
die "*E: There were Warnings! Please grep for Warnings in $COMPRESSED_LOG_FILE_PATH\n" unless system("zcat $COMPRESSED_LOG_FILE_PATH | grep Warning");

###############################################################################################################################################
# Functions
###############################################################################################################################################

sub system1 {
        my $x = $_[0];
        print "#SystemCommand: $x\n";
        system("$x");
}

exit 0;


