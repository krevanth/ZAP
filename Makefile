# // -----------------------------------------------------------------------------
# // --                                                                         --
# // --             (C) 2016-2022 Revanth Kamaraj (krevanth)                    --
# // --                                                                         -- 
# // -- --------------------------------------------------------------------------
# // --                                                                         --
# // -- This program is free software; you can redistribute it and/or           --
# // -- modify it under the terms of the GNU General Public License             --
# // -- as published by the Free Software Foundation; either version 2          --
# // -- of the License, or (at your option) any later version.                  --
# // --                                                                         --
# // -- This program is distributed in the hope that it will be useful,         --
# // -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
# // -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
# // -- GNU General Public License for more details.                            --
# // --                                                                         --
# // -- You should have received a copy of the GNU General Public License       --
# // -- along with this program; if not, write to the Free Software             --
# // -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
# // -- 02110-1301, USA.                                                        --
# // --                                                                         --
# // -----------------------------------------------------------------------------

.PHONY: all
.PHONY: clean
.PHONY: reset
.PHONY: c2asm
.PHONY: dirs

PWD          := $(shell pwd)
TAG          := archlinux/zap
SHELL        := /bin/bash -o pipefail
ARCH         := armv5te
C_FILES      := $(wildcard src/ts/$(TC)/*.c)
S_FILES      := $(wildcard src/ts/$(TC)/*.s)
H_FILES      := $(wildcard src/ts/$(TC)/*.h)
LD_FILE      := $(wildcard src/ts/$(TC)/*.ld)
CFLAGS       := -c -msoft-float -mfloat-abi=soft -march=$(ARCH) -g 
SFLAGS       := -march=$(ARCH) -g
LFLAGS       := -T
OFLAGS       := -O binary
CC           := arm-none-eabi-gcc
AS           := arm-none-eabi-as
LD           := arm-none-eabi-ld
OB           := arm-none-eabi-objcopy
CPU_FILES    := $(wildcard src/rtl/*)
TB_FILES     := $(wildcard src/testbench/*)
SCRIPT_FILES := $(wildcard scripts/*)
TEST         := $(shell find src/ts/* -type d -exec basename {} \; | xargs echo)
DLOAD        := 'FROM archlinux:latest\nRUN  pacman -Syyu --noconfirm arm-none-eabi-gcc arm-none-eabi-binutils gcc make perl verilator'

########################################## User Accessible Targets ####################################################

.DEFAULT_GOAL = all

# Run all tests. Default goal.
all:
	docker image ls | grep $(TAG) || echo -e $(DLOAD) | docker build --no-cache --rm --tag $(TAG) -
	for var in $(TEST); do docker run --tty --volume `pwd`:`pwd` --workdir `pwd` $(TAG) $(MAKE) runsim TC=$$var; done;

# Remove runsim objects
clean: 
	docker image ls | grep $(TAG) && docker run --interactive --tty --volume `pwd`:`pwd` --workdir `pwd` $(TAG) rm -rfv obj/

# Remove docker image.
reset: clean 
	docker image ls | grep $(TAG) && docker image rmi --force $(TAG)

############################################ Internal Targets #########################################################

# Compile S files to OBJ.
obj/ts/$(TC)/a.o: $(S_FILES)
	$(AS) $(SFLAGS) $(S_FILES) -o obj/ts/$(TC)/a.o

# Compile C files to OBJ.
obj/ts/$(TC)/c.o: $(C_FILES) $(H_FILES)
	$(CC) $(CFLAGS) $(C_FILES) -o obj/ts/$(TC)/c.o

# Rule to convert the object files to an ELF file.
obj/ts/$(TC)/$(TC).elf: $(LD_FILE) obj/ts/$(TC)/a.o obj/ts/$(TC)/c.o
	$(LD) $(LFLAGS) $(LD_FILE) obj/ts/$(TC)/a.o obj/ts/$(TC)/c.o -o obj/ts/$(TC)/$(TC).elf

# Rule to generate a BIN file.
obj/ts/$(TC)/$(TC).bin: obj/ts/$(TC)/$(TC).elf
	$(OB) $(OFLAGS) obj/ts/$(TC)/$(TC).elf obj/ts/$(TC)/$(TC).bin

# Lint
lint:
	cd lint && $(MAKE)

# Rule to lint and verilate.
obj/ts/$(TC)/Vzap_test: $(CPU_FILES) $(TB_FILES) $(SCRIPT_FILES) src/ts/$(TC)/Config.cfg obj/ts/$(TC)/$(TC).bin lint 
	./src/scripts/verilate $(TC) 

# Rule to execute command.
runsim: dirs obj/ts/$(TC)/Vzap_test
ifdef TC
	cd obj/ts/$(TC) && ./Vzap_test $(TC).bin $(TC)
	echo "Generated waveform file 'obj/ts/$(TC)/zap.vcd'"
else
	echo "TC value not passed in make command."
	exit 1
endif

# Create test directory.
dirs:
	mkdir -p obj/ts/$(TC)/
	touch obj/ts/$(TC)/

# Make C to ASM.
c2asm:
	$(CC) -S $(CFLAGS) $(X) -o obj/ts/$(TC)/$(X).asm

# Print internal variables.
print-%  : ; @echo $* = $($*)

#######################################################################################################################
