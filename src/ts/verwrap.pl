#
# (C) 2016-2022 Revanth Kamaraj (krevanth)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.
#


use strict;
use warnings;

my $TEST                        = $ARGV[0];
my $HT                          = $ARGV[1];
my %Config                      = do "./src/ts/$TEST/Config.cfg";
my $ONLY_CORE                   = $Config{'ONLY_CORE'};
my $DUMP_SIZE                   = $Config{'DUMP_SIZE'};
my $MAX_CLOCK_CYCLES            = $Config{'MAX_CLOCK_CYCLES'};
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
my $REG_HIER                    = "u_chip_top.u_zap_top.u_zap_core.u_zap_writeback.u_zap_register_file";

my $IVL_OPTIONS  = " -Isrc/rtl ";
   $IVL_OPTIONS .= "   src/rtl/*.sv ";
   $IVL_OPTIONS .= " -Iobj/ts/$TEST ";
   $IVL_OPTIONS .= "   src/testbench/*.v ";
   $IVL_OPTIONS .= " -GBP_ENTRIES=$BP ";
   $IVL_OPTIONS .= " -GFIFO_DEPTH=$FIFO ";
   $IVL_OPTIONS .= " -GDATA_SECTION_TLB_ENTRIES=$DATA_SECTION_TLB_ENTRIES ";
   $IVL_OPTIONS .= " -GDATA_LPAGE_TLB_ENTRIES=$DATA_LPAGE_TLB_ENTRIES ";
   $IVL_OPTIONS .= " -GDATA_SPAGE_TLB_ENTRIES=$DATA_SPAGE_TLB_ENTRIES ";
   $IVL_OPTIONS .= " -GDATA_CACHE_SIZE=$DATA_CACHE_SIZE ";
   $IVL_OPTIONS .= " -GCODE_SECTION_TLB_ENTRIES=$CODE_SECTION_TLB_ENTRIES ";
   $IVL_OPTIONS .= " -GCODE_LPAGE_TLB_ENTRIES=$CODE_LPAGE_TLB_ENTRIES ";
   $IVL_OPTIONS .= " -GCODE_SPAGE_TLB_ENTRIES=$CODE_SPAGE_TLB_ENTRIES ";
   $IVL_OPTIONS .= " -GCODE_CACHE_SIZE=$CODE_CACHE_SIZE ";
   $IVL_OPTIONS .= " -GONLY_CORE=$ONLY_CORE ";
   $IVL_OPTIONS .= " +define+MAX_CLOCK_CYCLES=$MAX_CLOCK_CYCLES ";
   $IVL_OPTIONS .= " +define+IRQ_EN "      if ( $IRQ_EN    );
   $IVL_OPTIONS .= " +define+FIQ_EN "      if ( $FIQ_EN    );
   $IVL_OPTIONS .= " +define+DEBUG_EN "    if ( @ARGV == 3  );
   $IVL_OPTIONS .= " +define+REG_HIER=$REG_HIER ";
   $IVL_OPTIONS .= " --trace "    if ( @ARGV == 3  );

open(HH, ">obj/ts/$TEST/zap_check.vh") or die "Could not write to obj/ts/$TEST/zap_check.vh";

my $RAM_HIER = "zap_test.mem";
my $X = $Config{'FINAL_CHECK'};

foreach(keys (%$X)) {
        my $string = "$_, $$X{$_}, ${RAM_HIER}[$_/4]";
        print HH
        "if ( ${RAM_HIER}[$_/4] !== ", $$X{"$_"}, ')
         begin
                $display("Error: Memory values not matched. PTR = %d EXP = %x REC = %x", ', $string , ' );
                o_sim_err <= 1;
                o_sim_ok  <= 0;
         end
         else
         begin
         end'
        ,
        "\n";
}

$X = $Config{'REG_CHECK'};

foreach(keys (%$X)) {
        my $string = "\"$_\", $$X{$_}, $_";
        print HH
        "if ( $_ !== ", $$X{"$_"}, ')
         begin
                $display("Error: Register values not matched. PTR = %s EXP = %x REC = %x", ', $string , ' );
                o_sim_err <= 1;
                o_sim_ok  <= 0;
         end
         else
         begin
         end'
         ,
         "\n";
}

my $THREADS = `getconf _NPROCESSORS_ONLN`;
chomp $THREADS;

my $MAKE_THREADS = $THREADS + 1;

if ( $HT == 1 )
{
        $HT = "-j $MAKE_THREADS --threads $THREADS";
} else
{
        $HT = "-j 1 --threads $THREADS";
}

my $cmd =
"verilator -O3 $HT -Wno-lint --cc --exe --assert  --build ../../../src/testbench/zap_test.cpp --Mdir obj/ts/$TEST --top zap_test $IVL_OPTIONS --x-assign unique --x-initial unique --error-limit 1 ";

print "$cmd\n";
die "Error: Failed to build executable." if system("$cmd");

exit 0;

