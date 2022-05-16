.DEFAULT_GOAL = all

.PHONY: all
.PHONY: clean
.PHONY: c2asm
.PHONY: dirs

PWD          := $(shell pwd)
TAG           = latest
CMD           = $(MAKE) MAKE_TC=1 TC=$(TC)
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

ifndef TC

all:
	echo "No TC value passed. TC is not defined. Exiting..."
	exit 1

clean:
	rm -rf obj

else

ifdef MAKE_TC

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
all: dirs obj/ts/$(TC)/Vzap_test
	cd obj/ts/$(TC) && ./Vzap_test $(TC).bin $(TC)
	echo "Generated waveform file 'obj/ts/$(TC)/zap.vcd'"

# Create test directory.
dirs:
	mkdir -p obj/ts/$(TC)/
	touch obj/ts/$(TC)/

# Clean OBJ directory.
clean: 
	mkdir -p obj/ts/$(TC)/
	rm -fv  obj/ts/$(TC)/*

# Make C to ASM.
c2asm:
	$(CC) -S $(CFLAGS) $(X) -o obj/ts/$(TC)/$(X).asm

print-%  : ; @echo $* = $($*)

else

ifndef DOCKER

all:
	$(CMD)

clean:
	rm -rf obj/$(TC)

else

all: .image_build test

test:
	docker run -it -v `pwd`:`pwd` -w `pwd` $(TAG) $(CMD)

.image_build: Dockerfile
	docker build -f Dockerfile --no-cache --rm --tag $(TAG) .
	touch .image_build

clean:
	rm -rf .image_build
	docker image rmi -f $(TAG)
	rm -rf obj/$(TC)

endif # DOCKER

endif # MAKE_TC

endif # TC
