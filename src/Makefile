CC=g++

# Flags required in order for the application to be ran by the bootstrap.
# 	-ffreestanding: Give a hint to the compiler that std and builtin won't be
# 	available.
# 	-static: There is no dynamic linking done by the bootstrap hence everything
# 	must be static.
# 	-nostdlib: Same as -static.
# 	-fno-exceptions: Exceptions are not supported since they required a library.
# 	-fno-rtti: No runtime support (at least yet).
# 	-mno-red-zone: Disable red zone on the stack (128 bytes under current RSP).
# 	This is because the kernel does not switch stacks on interrupts.
CPPFLAGS=-ffreestanding -static -nostdlib -fno-exceptions -fno-rtti -mno-red-zone

SRC_DIR=./
SOURCE_FILES:=$(shell find $(SRC_DIR) -type f -name "*.cpp")
ASM_FILES:=$(shell find $(SRC_DIR) -type f -name "*.S")
OBJ_FILES:=$(SOURCE_FILES:.cpp=.o) $(ASM_FILES:.S=.o)

# Final executable name.
FILENAME=Krayte

all: $(FILENAME)

$(FILENAME): $(OBJ_FILES)
	$(CC) -o $@ $(CPPFLAGS) $^

%.o: %.cpp
	$(CC) -c -o $@ $(CPPFLAGS) $<
%.o: %.S
	$(CC) -c -o $@ $(CPPFLAGS) $<

.PHONY: clean
clean:
	rm -rf $(OBJ_FILES) $(FILENAME)
