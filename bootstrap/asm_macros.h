// This file contains macro(s) that are used in assembly file(s).

// Placeholder for the 64-bit bit in the GDT entry. For now, only 32-bit is
// supported.
#define bits64 0

// Create a GDT entry with the given base, limit and type.
// The DPL will be set to ring 0 and granularity to 4KiB pages.
#define GDT_ENTRY(base, limit, type)   \
    (limit & 0xFFFF) | ((base & 0xFFFFFF) << 16) | (type << 40) | (1 << 44) | \
    (0x0 << 45) | (1 << 47) | (((limit & 0xF0000) >> 16) << 48) | \
    (bits64 << 53) | (1 << 54) | (1 << 55) | (((base & 0xFF) >> 24) << 56)

#define ARG(idx) (0x4 + idx << 1)
