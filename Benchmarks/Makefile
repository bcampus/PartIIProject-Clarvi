# the name of the program we're going to build
PROJECT = program
# build directory
BUILD = build

# name of the Quartus program
FPGA_PROJECT_PATH = ../quartus
FPGA_PROJECT = clarvi

# source files
C_FILES := $(wildcard src/*.c)
AS_FILES := $(wildcard src/*.s)
ASP_FILES := $(wildcard src/*.S)
BENCH_FILES := $(wildcard src/bench/*.c)

# object files
C_OBJ_FILES := $(patsubst src/%.c,build/%.o,$(C_FILES))
AS_OBJ_FILES := $(patsubst src/%.s,build/%.o,$(AS_FILES))
ASP_OBJ_FILES := $(patsubst src/%.S,build/%.o,$(ASP_FILES))

BENCH_HEX32_FILES := $(patsubst src/bench/%.c,build/%32.hex,$(BENCH_FILES))
BENCH_HEX64_FILES := $(patsubst src/bench/%.c,build/%64.hex,$(BENCH_FILES))
BENCH_HEX16_FILES := $(patsubst src/bench/%.c,build/%16.hex,$(BENCH_FILES))
BENCH_HEX8_FILES := $(patsubst src/bench/%.c,build/%8.hex,$(BENCH_FILES))
BENCH_HEX_FILES := $(BENCH_HEX32_FILES) $(BENCH_HEX64_FILES) $(BENCH_HEX16_FILES) $(BENCH_HEX8_FILES)

BENCH_TXT32_FILES := $(patsubst src/bench/%.c,build/%32.txt,$(BENCH_FILES))
BENCH_TXT64_FILES := $(patsubst src/bench/%.c,build/%64.txt,$(BENCH_FILES))
BENCH_TXT16_FILES := $(patsubst src/bench/%.c,build/%16.txt,$(BENCH_FILES))
BENCH_TXT8_FILES := $(patsubst src/bench/%.c,build/%8.txt,$(BENCH_FILES))
BENCH_TXT_FILES := $(BENCH_TXT32_FILES) $(BENCH_TXT64_FILES) $(BENCH_TXT16_FILES) $(BENCH_TXT8_FILES)

BENCH_DUMP_FILES := $(patsubst src/bench/%.c,build/%.dump,$(BENCH_FILES))
BENCH_ELF_FILES := $(patsubst src/bench/%.c,build/%.elf,$(BENCH_FILES))


# settings for the compilers
RISCV_PREFIX = riscv64-unknown-elf-
CC = $(RISCV_PREFIX)gcc
LD = $(RISCV_PREFIX)ld
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

TARGET_ARCH = -mabi=lp64 -march=rv64i_zicsr
CCFLAGS = -O1 $(TARGET_ARCH)

# Lists of rules: the name of a file, followed by the files it depends on.
# When typing 'make' not followed by a rule name, the first rule is followed.  This rule depends on
# everything, causing all the parts to be built

all: dirs $(BENCH_TXT_FILES) $(BENCH_HEX_FILES) $(BENCH_ELF_FILES) $(BENCH_DUMP_FILES)

# how to build a .o file from a .c file
$(BUILD)/%.o: src/%.c
	$(CC) -c -o $@ $< $(CCFLAGS)
	#
# how to build a .o file from a .c file
$(BUILD)/bench/%.o: src/bench/%.o
	$(CC) -c -o $@ $< $(CCFLAGS)

# how to build a .o file from a .s file
$(BUILD)/%.o: src/%.s
	$(CC) -c -o $@ $< $(CCFLAGS)

# how to build a .o file from a .S file
$(BUILD)/%.o: src/%.S
	$(CC) -c -o $@ $< $(CCFLAGS)

# link with gcc
$(BUILD)/%.elf: $(BUILD)/bench/%.o ${AS_OBJ_FILES} ${C_OBJ_FILES} ${ASP_OBJ_FILES}
	$(CC) -o $@ $^ -T link.ld -lgcc -nostdlib #-Xlinker "-melf32lriscv"

# build an elf executable
$(BUILD)/%.dump: $(BUILD)/%.elf
	$(OBJDUMP) -S -s $< > $@

# extract the binary data from data and text sections to get a binary image of memory
$(BUILD)/%.bin: $(BUILD)/%.elf
	$(OBJCOPY) -O binary --only-section=.rodata* --only-section=.data* --only-section=.text* $< $@

# convert to an ASCII hex file for simulation
$(BUILD)/%32.txt: $(BUILD)/%.bin
	hexdump -v -e '"%08x\n"' $< > $@

# create 64 bit version for rv64i
$(BUILD)/%64.txt: $(BUILD)/%32.txt
	python txt32to64.py $< $@

# create 16 bit version for rv64i
$(BUILD)/%16.txt: $(BUILD)/%32.txt
	python txt32to16.py $< $@

# create 8 bit version for rv64i
$(BUILD)/%8.txt: $(BUILD)/%32.txt
	python txt32to8.py $< $@


# convert to an Intel HEX file for downloading to the FPGA
$(BUILD)/%64.hex: $(BUILD)/%64.txt
	python txt2hex.py $< $@ 8

$(BUILD)/%32.hex: $(BUILD)/%32.txt
	python txt2hex.py $< $@ 4

$(BUILD)/%16.hex: $(BUILD)/%16.txt
	python txt2hex.py $< $@ 2

$(BUILD)/%8.hex: $(BUILD)/%8.txt
	python txt2hex.py $< $@ 1

# make software project folder
dirs:
	mkdir -p $(BUILD)
	mkdir -p $(BUILD)/bench

# update the memory files inside the FPGA bitfile
update-mem:	all
	cd ${FPGA_PROJECT_PATH} && quartus_cdb ${FPGA_PROJECT} -c ${FPGA_PROJECT} --update_mif
	cd ${FPGA_PROJECT_PATH} && quartus_asm --read_settings_files=on --write_settings_files=off ${FPGA_PROJECT} -c ${FPGA_PROJECT}

# download the bitfile to your board
download:
	cd ${FPGA_PROJECT_PATH} && quartus_pgm -m jtag -o P\;output_files/${FPGA_PROJECT}.sof@2

# build the whole FPGA from the command line
# not that it's harder to spot warnings in this output compared with the GUI
build_fpga:
	cd ${FPGA_PROJECT_PATH} && quartus_sh --flow compile ${FPGA_PROJECT}

# 'clean' rule: delete all the files so we can start afresh
clean:
	rm -rf $(BUILD)
