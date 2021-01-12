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

# Extract the .text from the .o file and store it in an img file.
bootstrap.img: $(OBJ_FILES)
	ld -T $(LINKER_SCRIPT) --oformat binary -o $@ $^

%.o: %.S asm_macros.h
	$(CC) -c $< -o $@ -I./

run: bootstrap.img
	qemu-system-x86_64 -drive file=$<,format=raw -s -m 512 -no-reboot -no-shutdown

.PHONY: clean
clean:
	rm -rf bootstrap.img $(OBJ_FILES)
