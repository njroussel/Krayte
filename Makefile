# Top level Makefile.
# The following rules are available:
# 	- test: This rule is for testing Krayte on the dev machine (not baremetal).
# 	- run: Build Krayte for baremetal and run it in Qemu.
# 	- runs: Same as `run` but pass the -S option to Qemu.

# Directory used for the CMake build.
CMAKE_BUILD_DIR=build

# Path to the application to bake into the disk.
APP_PATH=$(CMAKE_BUILD_DIR)/Krayte

# Path to the binary image containing the entire bootstrap code and data.
BOOTSTRAP_IMG_PATH=bootstrap/bootstrap.img

# Set of flags used by Qemu.
# Note: The +invtsc indicates to Qemu to add the constant TSC freq extension. It
# turns out that even if the host support this extension, Qemu does not show it
# to the VM hence why we need to add it here.
QEMU_FLAGS=-s -m 1024 -no-reboot -no-shutdown -enable-kvm -cpu host,+invtsc

# Test the application on the dev machine.
# This will create the $(APP_PATH) in DEBUG mode.
.PHONY: test
test: BUILD_TYPE=DEBUG
test: $(APP_PATH)

# Run the application in a VM. This will compile both the application (in
# RELEASE mode) and the bootstrap and create a disk image. This recipe will
# start Qemu with the disk image.
.PHONY: run
run: BUILD_TYPE=RELEASE
run: disk.img
	qemu-system-x86_64 -drive file=$<,format=raw $(QEMU_FLAGS)

# Same as above except that Qemu waits for a connection on the GDB server before
# starting.
.PHONY: runs
runs: QEMU_FLAGS += -S
runs: run

# Recipe to create the executable of the application.
.PHONY: $(APP_PATH)
$(APP_PATH):
	rm -rf $(CMAKE_BUILD_DIR)
	mkdir $(CMAKE_BUILD_DIR)
	cmake -S . -B $(CMAKE_BUILD_DIR) -DCMAKE_BUILD_TYPE=$(BUILD_TYPE)
	CXX=clang++ make -C $(CMAKE_BUILD_DIR)

# Recursive rule for the bootstrap image.
.PHONY: $(BOOTSTRAP_IMG_PATH)
$(BOOTSTRAP_IMG_PATH):
	make -C bootstrap/

# Create the final disk image from the bootstrap image and the ELF file of the
# application. Those will be concatenated by create_img.py.
disk.img: $(BOOTSTRAP_IMG_PATH) $(APP_PATH)
	./create_img.py $@ $^

# Clean recursively.
.PHONY: clean
clean:
	make -C bootstrap/ clean
	rm -rf disk.img $(CMAKE_BUILD_DIR)
