#!/usr/bin/perl

use strict;
use warnings;

die "*E: Icarus Verilog does not exist! Please install iverilog" if system("which iverilog");
die "*E: GTKWave does not exist! Please install gtkwave" if system("which gtkwave");
die "*E: Dialog does not exist! Please install dialog" if system("which dialog");
die "*E: XTerm does not exist! Please install xterm" if system("which xterm");

my $ivl_version = `iverilog -v`;

$ivl_version =~ m/([0-9]+)\.([0-9]+)/;
$ivl_version = $1;
my $ivl_subversion = $2;

if ( $1 >= 10 ) {
        print "*I: Icarus Verilog version check passed! Detected version $ivl_version.$ivl_subversion";
} else {
        die "*E: Older version of Icarus Verilog is being used. Please upgrade to 10.0 or higher...";
} 

my $system = 'dialog --backtitle "ZAP Simulation Options" --title "ZAP Simulation Options" --form "ZAP simulation options" 25 100 16\
        "ZAP Root (ZAP_HOME)"                                                                   1  1 "../.." 1  25 25 30\
        "Seed"                                                                                  2  1 "0 " 2  25 25 30\
        "Define SIM(Y/N)?"                                                                      3  1 "Y " 3  25 25 30\
        "Testcase"                                                                              4  1 "factorial " 4  25 25 30\
        "<UNUSED>"                                                                              5  1 "Y " 5  25 25 30\
        "External RAM size(bytes)"                                                              6  1 "32768 " 6  25 25 30\
        "dump start addr+words"                                                                 7  1 "1992+100 " 7  25 25 30\
        "DTLB(sect+small+large)"                                                                8  1 "8+8+8 " 8  25 25 30\
        "ITLB(sect+small+large)"                                                                9  1 "8+8+8 " 9  25 25 30\
        "Cache size(code+data)"                                                                 10 1 "1024+1024" 10 25 25 30\
        "IRQ from bench(Y/N)?"                                                                  11 1 "Y" 11 25 25 30\
        "FIQ from bench(Y/N)?"                                                                  12 1 "N" 12 25 25 30\
        "Scratch path"                                                                          13 1 "/tmp" 13 25 25 30\
        "Max clock cycles"                                                                      14 1 "100000" 14 25 25 30\
        "RTL file list"                                                                         15 1 "../rtl/rtl_files.list" 15 25 25 30\
        "Bench file list"                                                                       16 1 "../tb/bench_files.list" 16 25 25 30\
        "Branch predictor entries"                                                              17 1 "1024" 17 25 25 30\
        "FIFO depth"                                                                            18 1 "4" 18 25 25 30\
        "Post processing script"                                                                19 1 "post_process.pl" 19 25 25 30\
        "TLB dbg msg enable(Y/N)?"                                                              20 1 "N" 20 25 25 30\
        "Generate VCD(Y/N)?"                                                                    21 1 "Y" 21 25 25 30 --stdout';

$system = `$system`;

print "Parsing options...\n";
print $system;
$system =~ s/\n/!/g;
print $system;

my $zap_home    ;
my $seed        ;
my $sim         ;
my $testcase    ;
my $ram_size    ;
my $memdumpstart;
my $dtlb        ;
my $itlb        ;
my $csize       ;
my $irq         ;
my $fiq         ;
my $scratch_path;
my $maxclockcycles;
my $rtlfilelist ;
my $tbfilelist  ;
my $bp          ;
my $fifo        ;
my $pps         ;
my $tlbdebug    ;
my $genvcd      ;

my $command;

if ( $system =~ m#^(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!(.*?)!$# ) {

        $zap_home     = $1;
        $seed         = $2;
        $sim          = $3;
        $testcase     = $4;
        $ram_size     = $6;
        $memdumpstart = $7;        
        $dtlb         = $8;
        $itlb         = $9;
        $csize        = $10;
        $irq          = $11;
        $fiq         = $12;
        $scratch_path= $13;
        $maxclockcycles = $14;
        $rtlfilelist = $15;
        $tbfilelist  = $16;
        $bp          = $17;
        $fifo        = $18;
        $pps         = $19;
        $tlbdebug    = $20;
        $genvcd      = $21;

print "
        zap_home     = $zap_home   
        seed         = $seed       
        sim          = $sim        
        testcase     = $testcase   
        ram_size     = $ram_size   
        memdumpstart = $memdumpstart
        dtlb         = $dtlb       
        itlb         = $itlb       
        csize        = $csize      
        irq          = $irq        
        fiq          = $fiq        
        scratch_path  = $scratch_path
        maxclockcycles = $maxclockcycles
        rtlfilelist =  $rtlfilelist
        tbfilelist  =  $tbfilelist 
        bp          =  $bp         
        fifo        =  $fifo       
        pps         =  $pps        
        tlbdebug    =  $tlbdebug   
        genvcd      =  $genvcd     
";

        $command = " perl run_sim.pl +zap_root+$zap_home +test+$testcase +ram_size+$ram_size +dump_start+$memdumpstart +scratch+$scratch_path +max_clock_cycles+$maxclockcycles +rtl_file_list+$rtlfilelist +tb_file_list+$tbfilelist +bp+$bp +fifo+$fifo +post_process+$pps "; 
} else {
        print "Zenity ERROR. Form not entered correctly!";
}

if ( $seed =~ m/^\s*[0-9]+\s*$/ )       { $command .= " +seed+$seed"; }
if ( $sim  =~ m/Y/ )                    { $command .= " +sim "; }

if ( 1 )  { 
        $command .= " +cache_size+$csize ";
        $command .= " +dtlb+$dtlb ";
        $command .= " +itlb+$itlb ";
}

if ( $irq =~ m/Y/ )      { $command .= " +irq_en "; }
if ( $fiq =~ m/Y/ )      { $command .= " +fiq_en "; }
if ( $tlbdebug =~ m/Y/ ) { $command .= " +tlbdebug "; }
if ( $genvcd   !~ m/Y/ ) { $command .= " +nodump "; }

$command .= ";echo Press Ctrl+C/D to exit;cat";
print "$command\n";
exec "xterm -e '$command'";
