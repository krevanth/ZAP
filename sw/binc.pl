#!/usr/bin/perl -w

die "Usage: perl binc.pl asm_file c_file linker_script target_bin" if (@ARGV != 4);

system("arm-none-eabi-as -mcpu=arm7tdmi     -g $ARGV[0] -o startup.o"); # Assembly file.
system("arm-none-eabi-gcc -S -c -mcpu=arm7tdmi -g $ARGV[1] -o test.asm"); # Assembly file.
system("arm-none-eabi-gcc -c -mcpu=arm7tdmi -g $ARGV[1] -o test.o");    # C file.
system("arm-none-eabi-ld -T $ARGV[2] test.o startup.o -o test.elf");    # Linker script
system("arm-none-eabi-objcopy -O binary test.elf $ARGV[3]");            # Target bin file
system("rm -rf startup.o test.o test.elf");
