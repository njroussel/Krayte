// This file contains macro(s) that are used in assembly file(s).

// Create a GDT entry for a 16-bit segment with the given base, limit and type.
// The DPL will be set to ring 0 and granularity to 4KiB pages.
#define GDT_ENTRY16(base, limit, type)   \
    (limit & 0xFFFF) | ((base & 0xFFFFFF) << 16) | (type << 40) | (1 << 44) | \
    (0x0 << 45) | (1 << 47) | (((limit & 0xF0000) >> 16) << 48) | \
    (0 << 53) | (0 << 54) | (1 << 55) | (((base & 0xFF) >> 24) << 56)

// Create a GDT entry for a 32-bit segment with the given base, limit and type.
// The DPL will be set to ring 0 and granularity to 4KiB pages.
#define GDT_ENTRY32(base, limit, type)   \
    GDT_ENTRY16(base, limit, type) | (1 << 54)

#define ARG(idx) (0x4 + idx << 1)

// Define a 16-bit/real-mode function.
// @param name: The name of the function.
#define ASM_FUNC_DEF16(name)    ;\
    .code16                     ;\
    .global name                ;\
    .type name, @function       ;\
    name

// Define a 16-bit/real-mode function.
// @param name: The name of the function.
#define ASM_FUNC_DEF32(name)    ;\
    .code32                     ;\
    .global name                ;\
    .type name, @function       ;\
    name
