CC=g++

# Flags required in order for the application to be ran by the bootstrap.
# 	-ffreestanding: Give a hint to the compiler that std and builtin won't be
# 	available.
# 	-static: There is no dynamic linking done by the bootstrap hence everything
# 	must be static.
# 	-nostdlib: Same as -static.
# 	-fno-exceptions: Exceptions are not supported since they required a library.
# 	-fno-rtti: No runtime support (at least yet).
CPPFLAGS=-ffreestanding -static -nostdlib -fno-exceptions -fno-rtti

SRC_DIR=./
SOURCE_FILES:=$(shell find $(SRC_DIR) -type f -name "*.cpp")
OBJ_FILES:=$(SOURCE_FILES:.cpp=.o)

# Final executable name.
FILENAME=Krayte

all: $(FILENAME)

$(FILENAME): $(OBJ_FILES)
	$(CC) -o $@ $(CPPFLAGS) $^

%.o: %.cpp
	$(CC) -c -o $@ $(CPPFLAGS) $<

.PHONY: clean
clean:
	rm -rf $(OBJ_FILES) $(FILENAME)
