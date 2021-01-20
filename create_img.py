#!/bin/env python3

# This script creates the final disk image by concatenating the bootstrap image
# and the ELF file to be loaded by the bootstrap.
# Usage:
#   ./create_img.py <output file> <bootstrap filename> <ELF filename>

import sys

# Read the entire content of a file.
# @param filename: The name of the file to read.
# @return: A bytes object containing the entire file.
def read_bytes(filename):
    fd = open(filename, "rb")
    content = fd.read()
    fd.close()
    return content

# Add padding to a bytes object so that its size is a multiple of 512.
# @param image: The original bytes object.
# @return: The padded bytes object.
def align_sector(image):
    l = len(image)
    if l % 512 == 0:
        return image
    else:
        res = image + 0x0.to_bytes(1, "little") * (512 - (l % 512))
        assert len(res) % 512 == 0
        return res

# Main function of the script.
# @param out_filename: The name of the image file to create.
# @param bootstrap_filename: Path to the boostrap image file.
# @param elf_filename: Path to the ELF file.
def main(out_filename, bootstrap_filename, elf_filename):
    elf_content = read_bytes(elf_filename)

    image = read_bytes(bootstrap_filename)
    image = align_sector(image)

    # Add a special "metadata" sector in the final image that contains
    # information on the ELF file such as:
    #   - Size in bytes (DWORD)
    #   - Start sector  (DWORD)
    #   - Name          (NUL terminated char*)
    # The metadata sector appears right after the bootstrap sectors.
    metadata = len(elf_content).to_bytes(4, "little")
    metadata += ((len(image) // 512) + 1).to_bytes(4, "little")
    metadata += elf_filename.encode("ascii")
    # NUL char for the string.
    metadata += 0x0.to_bytes(1, "little")
    # Metadata must fit in a single sector.
    assert len(metadata) < 512
    image += metadata

    image = align_sector(image)

    # Add elf file after metadata sector.
    image += elf_content
    image = align_sector(image)

    # Write final image.
    fd = open(out_filename, "wb")
    fd.write(image)
    fd.close()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise Exception("Not enough args, expected <out> <bootstrap img> <elf>")
    else:
        main(sys.argv[1], sys.argv[2], sys.argv[3])
