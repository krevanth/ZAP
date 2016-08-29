#!/usr/bin/perl -w

die "Usage: perl binasm.pl asm_file linker_script target_bin" if ( @ARGV != 3 );
system("arm-none-eabi-as -mcpu=arm7tdmi -g $ARGV[0] -o startup.o"); # ASM file
system("arm-none-eabi-ld -T $ARGV[1] startup.o -o startup.elf"); # Linker script.
system("arm-none-eabi-objcopy -O binary startup.elf $ARGV[2]"); # Target bin
system("rm -rf startup.o startup.elf");
