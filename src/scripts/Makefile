#// -----------------------------------------------------------------------------
#// --                                                                         --
#// --                   (C) 2016-2022 Revanth Kamaraj (krevanth)              --
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

##################################################
#                                                #
# This is a common makefile to be used for all   #   
# testcases. Note that all paths are relative    #
# to the testcase directory. Do a make c2asm     #
# if you need the assembly version of C files.   #
#                                                #
##################################################

.DEFAULT_GOAL = all

.PHONY: clean
.PHONY: c2asm
.PHONY: dirs

SHELL        := /bin/bash -o pipefail
ARCH         := armv5t
TC           := $(shell basename `pwd`)
SCRIPT_PATH  := ../../scripts/
C_FILES      := $(wildcard *.c)
S_FILES      := $(wildcard *.s)
H_FILES      := $(wildcard *.h)
LD_FILE      := $(wildcard *.ld)
COBJFILES    := $(patsubst %.c,../../../obj/ts/$(TC)/%_c.o,$(C_FILES))
AOBJFILES    := $(patsubst %.s,../../../obj/ts/$(TC)/%_s.o,$(S_FILES))
CFLAGS       := -c -msoft-float -mfloat-abi=soft -march=$(ARCH) -g 
SFLAGS       := -march=$(ARCH) -g
LFLAGS       := -T
OFLAGS       := -O binary
CC           := arm-none-eabi-gcc
AS           := arm-none-eabi-as
LD           := arm-none-eabi-ld
OB           := arm-none-eabi-objcopy
CPU_FILES    := $(wildcard ../../../src/rtl/*)
TB_FILES     := $(wildcard ../../../src/testbench/*)
SCRIPT_FILES := $(wildcard ../../scripts/*)

# This rule will convert every ASM to file its corresponding object file.
../../../obj/ts/$(TC)/%_s.o: %.s
	$(AS) $(SFLAGS) $^ -o $@

# This rule will convert every C file to its corresponding object file.
../../../obj/ts/$(TC)/%_c.o: %.c $(H_FILES)
	$(CC) $(CFLAGS) $< -o $@

# Rule to convert the object files to an ELF file.
../../../obj/ts/$(TC)/$(TC).elf: $(LD_FILE) $(AOBJFILES) $(COBJFILES)
	$(LD) $(LFLAGS) $^ -o $@

# Rule to generate a BIN file.
../../../obj/ts/$(TC)/$(TC).bin: ../../../obj/ts/$(TC)/$(TC).elf
	$(OB) $(OFLAGS) $^ $@

# Rule to convert the bin file to a Verilog image.
../../../obj/ts/$(TC)/zap_mem.v: ../../../obj/ts/$(TC)/$(TC).bin 
	$(SCRIPT_PATH)/bin2vlog $< $@

# Rule to lint and verilate.
../../../obj/ts/$(TC)/Vzap_test: ../../../obj/ts/$(TC)/zap_mem.v $(CPU_FILES) $(TB_FILES) $(SCRIPT_FILES)
	cd ../../../lint && make lint && cd ../src/ts/$(TC) && $(SCRIPT_PATH)/verilate $(TC) 

# Final rule.
all: dirs ../../../obj/ts/$(TC)/Vzap_test
	cd ../../../obj/ts/$(TC) && ./Vzap_test +verilator+seed+$$RANDOM | tee ../../../obj/ts/$(TC)/zap.log

$(CC):
$(AS): 
$(LD):
$(OB):

dirs:
	mkdir -p ../../../obj/ts/$(TC)/
	touch ../../../obj/ts/$(TC)/

clean: 
	mkdir -p ../../../obj/ts/$(TC)/
	rm -fv  ../../../obj/ts/$(TC)/*

c2asm:
	$(CC) -S $(CFLAGS) $(X) -o ../../../obj/ts/$(TC)/$(X).asm

waves:
	gtkwave ../../../obj/ts/$(TC)/zap.vcd &
	gvim    ../../../obj/ts/$(TC)/zap.log & 

print-%  : ; @echo $* = $($*)

