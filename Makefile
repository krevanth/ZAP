#                                                                         
#  (C) 2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
#                                                                         
# This program is free software; you can redistribute it and/or           
# modify it under the terms of the GNU General Public License             
# as published by the Free Software Foundation; either version 3          
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

.PHONY: test clean reset lint runlint runsvlint c2asm dirs runsim syn

PWD          := $(shell pwd)
TAG          := archlinux/zap
SHELL        := /bin/bash -o pipefail
ARCH         := armv5te
C_FILES      := $(wildcard src/ts/$(TC)/*.c)
S_FILES      := $(wildcard src/ts/$(TC)/*.s)
H_FILES      := $(wildcard src/ts/$(TC)/*.h)
LD_FILE      := $(wildcard src/ts/*.ld)
CFLAGS       := -c -msoft-float -mfloat-abi=soft -march=$(ARCH) -g 
SFLAGS       := -march=$(ARCH) -g
LFLAGS       := -T
OFLAGS       := -O binary
CC           := arm-none-eabi-gcc
AS           := arm-none-eabi-as
LD           := arm-none-eabi-ld
OB           := arm-none-eabi-objcopy
DP           := arm-none-eabi-objdump
CPU_FILES    := $(wildcard src/rtl/*)
SYN_SCRIPTS  := $(wildcard src/syn/*)
TB_FILES     := $(wildcard src/testbench/*)
SCRIPT_FILES := $(wildcard scripts/*)
TEST         := $(shell find src/ts/* -type d -exec basename {} \; | xargs echo)

DLOAD        := "FROM archlinux:latest\n\
				 RUN pacman -Syyu --noconfirm cargo perl make\n\
				 RUN pacman -Syyu --noconfirm arm-none-eabi-gcc arm-none-eabi-binutils gcc verilator\n\
				 RUN cargo install svlint"

DOCKER		 := docker run --interactive --tty --volume $(PWD):$(PWD) --workdir $(PWD) $(TAG)
LOAD_DOCKER  := docker image ls | grep $(TAG) || echo -e $(DLOAD) | docker build --no-cache --rm --tag $(TAG) -

##########################################
# User Accessible Targets
##########################################

# Thanks to Erez Binyamin for Docker support patches.

.DEFAULT_GOAL = test

# Run all tests. Default goal.
test:
	$(LOAD_DOCKER)
ifndef TC
	for var in $(TEST); do $(MAKE) test TC=$$var HT=1 || exit 10 ; done; 
else
ifndef SEED
	$(DOCKER) $(MAKE) runsim TC=$(TC) HT=1 || exit 10
else
	$(DOCKER) $(MAKE) runsim TC=$(TC) SEED=$(SEED) HT=1 || exit 10
endif
endif

# Remove runsim objects.
clean: 
	$(LOAD_DOCKER)
	$(DOCKER) rm -rfv obj_dir/ obj/ || exit 10

# Lint
lint:
	$(LOAD_DOCKER)
	$(DOCKER) $(MAKE) runlint || exit 10

# Remove docker image.
reset: clean
	docker image ls | grep $(TAG) && docker image rmi --force $(TAG)

# Synthesis (Vivado, no Docker Support)
syn: obj/syn/syn_timing.rpt
	vi obj/syn/syn_timing.rpt

############################################
# Internal Targets
############################################

obj/syn/syn_timing.rpt: $(CPU_FILES) $(SYN_SCRIPTS)
	mkdir -p obj/syn
	rm -rf obj/syn/syn_timing.rpt
	cd obj/syn ; vivado -mode batch -source ../../src/syn/syn.tcl

# Compile S files to OBJ.
obj/ts/$(TC)/a.o: $(S_FILES)
	$(AS) $(SFLAGS) $(S_FILES) -o obj/ts/$(TC)/a.o

# Compile C files to OBJ.
obj/ts/$(TC)/c.o: $(C_FILES) $(H_FILES)
	$(CC) $(CFLAGS) $(C_FILES) -o obj/ts/$(TC)/c.o

# Rule to convert the object files to an ELF file.
obj/ts/$(TC)/$(TC).elf: $(LD_FILE) obj/ts/$(TC)/a.o obj/ts/$(TC)/c.o
	$(LD) $(LFLAGS) $(LD_FILE) obj/ts/$(TC)/a.o obj/ts/$(TC)/c.o -o obj/ts/$(TC)/$(TC).elf
	$(DP) -d obj/ts/$(TC)/$(TC).elf > obj/ts/$(TC)/$(TC).dump

# Rule to generate a BIN file.
obj/ts/$(TC)/$(TC).bin: obj/ts/$(TC)/$(TC).elf
	$(OB) $(OFLAGS) obj/ts/$(TC)/$(TC).elf obj/ts/$(TC)/$(TC).bin

# Rule to verilate.
obj/ts/$(TC)/Vzap_test: $(CPU_FILES) $(TB_FILES) $(SCRIPT_FILES) src/ts/$(TC)/Config.cfg obj/ts/$(TC)/$(TC).bin
ifdef SEED
	perl src/ts/verwrap.pl $(TC) $(HT) $(SEED)
else
	perl src/ts/verwrap.pl $(TC) $(HT)
endif

# Rule to lint.
runlint:
	/root/.cargo/bin/svlint --include src/rtl/ src/rtl/*.sv --define SYNTHESIS 
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GONLY_CORE=1\'d1 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_FPAGE_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_FPAGE_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_FPAGE_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_FPAGE_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_FPAGE_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_FPAGE_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_FPAGE_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_FPAGE_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_FPAGE_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_FPAGE_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SPAGE_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SPAGE_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SPAGE_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SPAGE_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SPAGE_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SPAGE_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SPAGE_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SPAGE_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SPAGE_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SPAGE_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_LPAGE_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_LPAGE_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_LPAGE_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_LPAGE_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_LPAGE_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_LPAGE_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_LPAGE_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_LPAGE_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_LPAGE_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_LPAGE_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SECTION_TLB_ENTRIES=2 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SECTION_TLB_ENTRIES=4 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SECTION_TLB_ENTRIES=8 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SECTION_TLB_ENTRIES=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GCODE_SECTION_TLB_ENTRIES=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SECTION_TLB_ENTRIES=2 -GDATA_CACHE_SIZE=16384 -GDATA_CACHE_LINE=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SECTION_TLB_ENTRIES=4 -GCODE_CACHE_SIZE=16384 -GCODE_CACHE_LINE=16 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SECTION_TLB_ENTRIES=8 -GDATA_CACHE_SIZE=4096 -GCODE_CACHE_LINE=32 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SECTION_TLB_ENTRIES=16 -GCODE_CACHE_SIZE=4096 -GDATA_CACHE_LINE=64 && echo "Lint OK"
	verilator --assert --lint-only +define+SYNTHESIS -sv -error-limit 1 -Wall -Wpedantic -Wwarn-lint -Wwarn-style -Wwarn-MULTIDRIVEN     \
        -Wwarn-IMPERFECTSCH --report-unoptflat --clk i_clk --top-module zap_top src/rtl/*.sv -Isrc/rtl/           \
        -GDATA_SECTION_TLB_ENTRIES=32 && echo "Lint OK"

# Rule to execute command.
runsim: dirs obj/ts/$(TC)/Vzap_test
ifdef TC
ifdef SEED 
	cd obj/ts/$(TC) && ./Vzap_test $(TC).bin $(TC) $(SEED) 
else
	cd obj/ts/$(TC) && ./Vzap_test $(TC).bin $(TC)
endif
	echo "Generated waveform file 'obj/ts/$(TC)/zap.vcd'"
else
	echo "TC value not provided in make command."
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


