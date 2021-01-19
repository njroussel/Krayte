CC=gcc

# Directory containing the sources.
SRC_DIR=./
# All the assembly files composing the bootstrap code.
SOURCE_FILES:=$(shell find $(SRC_DIR) -type f -name "*.S")
OBJ_FILES:=$(SOURCE_FILES:.S=.o)

# The name of the entry point of the bootstrap. This is what will be put at
# address 0x7C00.
ENTRY_FUNC=entry
LINKER_SCRIPT=linker.ld

# Get rid of builtin rules. For some reasons, when compiling for baremetal, make
# tries to outsmart us with its builtin rules and tries to compile a .S file
# only to fail spectacularly.
.SUFFIXES:

all: bootstrap.img

# Link all object files into the final disk image.
# NOTE: In order to have debug information, GDB loads symbols from an ELF file.
# Since the bootstrap.img is a binary file this cannot work. Hence we create an
# ELF file "debuginfo" containing all debug info that will be loaded by GDB.
bootstrap.img: $(OBJ_FILES)
	ld -T $(LINKER_SCRIPT) --oformat binary -o $@ $^ --orphan-handling="discard"
	ld -T $(LINKER_SCRIPT) -o debuginfo $^

%.o: %.S asm_macros.h
	$(CC) -g -O0 -c $< -o $@ -I./ -I$(dir $<)

run: bootstrap.img
	qemu-system-x86_64 -drive file=$<,format=raw -s -m 16000 -no-reboot -no-shutdown -d int 2>out
runs: bootstrap.img
	qemu-system-x86_64 -drive file=$<,format=raw -s -m 16000 -no-reboot -no-shutdown -S

.PHONY: clean
clean:
	rm -rf bootstrap.img $(OBJ_FILES)
