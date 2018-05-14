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

TC           := $(shell basename `pwd`)
OBJ_DIR      := ../../../obj/ts/$(TC)/
GCC_PATH     := ../../../obj/gcc-arm-none-eabi-*/bin/
SCRIPT_PATH  := ../../scripts/
C_FILES      := $(wildcard *.c)
S_FILES      := $(wildcard *.s)
LD_FILE      := $(wildcard *.ld)
GCC_SRC      := ../../../sw/gcc-arm-none-eabi-*-linux.tar.*
CFLAGS       := -c -msoft-float -mfloat-abi=soft -mcpu=arm7tdmi -g
SFLAGS       := -mcpu=arm7tdmi -g
LFLAGS       := -T
OFLAGS       := -O binary
CC           := $(GCC_PATH)/arm-none-eabi-gcc
AS           := $(GCC_PATH)/arm-none-eabi-as
LD           := $(GCC_PATH)/arm-none-eabi-ld
OB           := $(GCC_PATH)/arm-none-eabi-objcopy

$(OBJ_DIR)/asm_file.o: $(S_FILES)
	$(AS) $(SFLAGS) $^ -o $@

$(OBJ_DIR)/c_file.o: $(C_FILES)
	$(CC) $(CFLAGS) $^ -o $@

$(OBJ_DIR)/$(TC).elf: $(LD_FILE) $(OBJ_DIR)/asm_file.o $(OBJ_DIR)/c_file.o $(TC).ld
	$(LD) $(LFLAGS) $< $^ -o $@

$(OBJ_DIR)/$(TC).bin: $(OBJ_DIR)/$(TC).elf
	$(OB) $(OFLAGS) $^ $@

$(OBJ_DIR)/zap_mem.v: $(OBJ_DIR)/$(TC).bin 
	perl $(SCRIPT_PATH)/bin2vlog.pl $< $@

all: dirs $(CC) $(AS) $(LD) $(OB) $(OBJ_DIR)/zap_mem.v 
	perl $(SCRIPT_PATH)/run_sim.pl +test+$(TC) 

$(AS): 
$(LD):
$(OB):

$(CC): $(GCC_SRC)
	mkdir -p $(OBJ_DIR)
	tar -xvf $(GCC_SRC) -C ../../../obj/ 
	touch $@

dirs:
	bash ../../scripts/check_arc.sh
	mkdir -p $(OBJ_DIR)
	touch $(OBJ_DIR)

clean: 
	rm -fv  $(OBJ_DIR)/* 
	rm -rfv $(OBJ_DIR)/../../gcc-arm-none-*

c2asm: $(C_FILES)
	$(CC) -S $(CFLGAS) $(C_FILES) -o $(OBJ_DIR)/c_file.asm

print-%  : ; @echo $* = $($*)

