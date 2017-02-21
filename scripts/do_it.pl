#!/usr/bin/perl -w

###############################################################################
# A Perl script to automate compilation of code. It accepts an assembly file
# and a C file along with a linker script.
###############################################################################

use strict;
use warnings;

die "Usage: perl do_it.pl <asm_file> <c_file> <linker_script> <target_bin> <target_verilog_file>" if (@ARGV != 5);

my $asm_file            =            $ARGV[0];
my $c_file              =            $ARGV[1];
my $linker              =            $ARGV[2];
my $target              =            $ARGV[3];
my $bin_file            =            $target;
my $target_verilog_file =            $ARGV[4];

# Remove files.
system("rm -fv /tmp/asm_file.o /tmp/c_file.asm /tmp/c_file.o /tmp/elf_file.elf $target_verilog_file $target $bin_file");

# Assembly to object file.
print "Converting $asm_file to asm_file.o...\n";
die "*E: Failed to convert $asm_file to asm_file.o" if system("arm-none-eabi-as -mcpu=arm7tdmi -g $asm_file  -o /tmp/asm_file.o"); 

# C file to assembly.
print "Converting C file to /tmp/c_file.asm...\n";
die "*E: Failed to convert $c_file to c_file.asm" if system("arm-none-eabi-gcc -S -c -msoft-float -mfloat-abi=soft -mcpu=arm7tdmi -g $c_file -o /tmp/c_file.asm"); 

# C file to object file.
print "Converting C file $c_file to object file c_file.o...\n";
die "*E: Failed to convert $c_file to c_file.o" if system("arm-none-eabi-gcc -c -msoft-float -mfloat-abi=soft -mcpu=arm7tdmi -g $c_file -o /tmp/c_file.o");     

# This is the linker script to combine input files to a single ELF output file.
print "Assembling all .o files usig the linker script $linker...\n";
die "*E: Linking failed!" if system("arm-none-eabi-ld -T $linker /tmp/asm_file.o /tmp/c_file.o -o /tmp/elf_file.elf");  

# Generate target bin file from the ELF file.
print "Generating bin $target...\n";
die "*E: Failed to generate bin $target..." if system("arm-none-eabi-objcopy -O binary /tmp/elf_file.elf $target");   


