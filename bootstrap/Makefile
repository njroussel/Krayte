CC=gcc
ENTRY_FUNC=entry

# Get rid of builtin rules. For some reasons, when compiling for baremetal, make
# tries to outsmart us with its builtin rules and tries to compile a .S file
# only to fail spectacularly.
.SUFFIXES:

all: bootstrap.img

# Extract the .text from the .o file and store it in an img file.
%.img: %.o
	ld -Ttext 0x7c00 -e $(ENTRY_FUNC) --oformat binary -o $@ $<

%.o: %.S asm_macros.h
	$(CC) -c $< -o $@ -I./

run: bootstrap.img
	qemu-system-x86_64 -fda $< -no-shutdown -no-reboot -s

.PHONY: clean
clean:
	rm -rf bootstrap.img
