##################################################
#                                                #
#              THE ZAP PROJECT                   #
#          Released under the GNU GPL v2         #
#                                                #
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
.PHONY: compiler
.PHONY: dirs
.PHONY: cleanall

ARCH         := armv4t
TC           := $(shell basename `pwd`)
GCC_PATH     := ../../../obj/gcc-arm-none-eabi-*/bin/
SCRIPT_PATH  := ../../scripts/
C_FILES      := $(wildcard *.c)
S_FILES      := $(wildcard *.s)
H_FILES      := $(wildcard *.h)
LD_FILE      := $(wildcard *.ld)
COBJFILES    := $(patsubst %.c,../../../obj/ts/$(TC)/%_c.o,$(C_FILES))
AOBJFILES    := $(patsubst %.s,../../../obj/ts/$(TC)/%_s.o,$(S_FILES))
GCC_SRC      := ../../../sw/gcc-arm-none-eabi-*-linux.tar.*
CFLAGS       := -c -msoft-float -mfloat-abi=soft -march=$(ARCH) -g 
SFLAGS       := -march=$(ARCH) -g
LFLAGS       := -T
OFLAGS       := -O binary
CC           := $(GCC_PATH)/arm-none-eabi-gcc
AS           := $(GCC_PATH)/arm-none-eabi-as
LD           := $(GCC_PATH)/arm-none-eabi-ld
OB           := $(GCC_PATH)/arm-none-eabi-objcopy

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
	perl $(SCRIPT_PATH)/bin2vlog.pl $< $@

# Rule to run the simulation.
all: dirs $(CC) ../../../obj/ts/$(TC)/zap_mem.v
	perl $(SCRIPT_PATH)/run_sim.pl +test+$(TC) 

$(AS): 
$(LD):
$(OB):

$(CC): $(GCC_SRC)
	mkdir -p ../../../obj/ts/$(TC)/
	tar -xvf $(GCC_SRC) -C ../../../obj/ 
	touch $@

dirs:
	bash ../../scripts/check_arc.sh
	mkdir -p ../../../obj/ts/$(TC)/
	touch ../../../obj/ts/$(TC)/

clean: 
	mkdir -p ../../../obj/ts/$(TC)/
	rm -fv  ../../../obj/ts/$(TC)/*

cleanall:
	rm -fv  ../../../obj/ts/$(TC)/*
	rm -rfv ../../../obj/ts/$(TC)/../../gcc-arm-none-*

c2asm:
	$(CC) -S $(CFLAGS) $(X) -o ../../../obj/ts/$(TC)/$(X).asm

print-%  : ; @echo $* = $($*)

