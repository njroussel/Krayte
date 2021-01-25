# Top level Makefile generating the final disk image.

# Path to the application to bake into the disk.
APP_PATH=src/Krayte
# Path to the binary image containing the entire bootstrap code and data.
BOOTSTRAP_IMG_PATH=bootstrap/bootstrap.img

all: disk.img

# Recursive rule for the ELF.
.PHONY: $(APP_PATH)
$(APP_PATH):
	make -C src/

# Recursive rule for the bootstrap image.
.PHONY: $(BOOTSTRAP_IMG_PATH)
$(BOOTSTRAP_IMG_PATH):
	make -C bootstrap/

# Create the final disk image from the bootstrap image and the ELF file of the
# application. Those will be concatenated by create_img.py.
disk.img: $(BOOTSTRAP_IMG_PATH) $(APP_PATH)
	./create_img.py $@ $^

# Set of flags used by Qemu.
QEMU_FLAGS=-s -m 1024 -no-reboot -no-shutdown

# Run Qemu with the disk image. The GDB server is started as well but Qemu does
# not wait to start the execution.
run: disk.img
	qemu-system-x86_64 -drive file=$<,format=raw $(QEMU_FLAGS)

# Run Qemu with the disk image. The GDB server is started as well and Qemu WAITs
# for a continue command from a GDB session before starting execution.
runs: disk.img
	qemu-system-x86_64 -drive file=$<,format=raw -S $(QEMU_FLAGS)

# Clean recursively.
.PHONY: clean
clean:
	make -C src/ clean
	make -C bootstrap/ clean
	rm -rf disk.img
