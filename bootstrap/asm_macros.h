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
    .section .text              ;\
    .code16                     ;\
    .global name                ;\
    .type name, @function       ;\
    name

// Define a 16-bit/real-mode function. This is the same as ASM_FUNC_DEF16 except
// that this macro will not set the current to section to .text and will keep
// the section of the call-site.
// @param name: The name of the function.
#define ASM_FUNC_DEF16_NO_SECTION(name)     ;\
    .code16                                 ;\
    .global name                            ;\
    .type name, @function                   ;\
    name

// Define a 16-bit/real-mode function.
// @param name: The name of the function.
#define ASM_FUNC_DEF32(name)    ;\
    .section .text              ;\
    .code32                     ;\
    .global name                ;\
    .type name, @function       ;\
    name

// Helper macros to panic the current code. This macros will define the message
// in the .data section and call panic.
// @param msg: A string indicating the nature of the panic.
// Note: Since we need a new label for the message string, and it is not
// possible to generate unique labels with AS, we use a numeric label with a
// high number. This _almost_ guarantee that this will not conflict with any
// label in the current code.
#define PANIC32(msg)        ;\
    .section .data          ;\
    999999:                 ;\
    .asciz msg              ;\
    .section .text          ;\
    lea     eax, [999999b]  ;\
    push    eax             ;\
    call    panic

// Helper macro to printf with a prefix. The prefix and the format string will
// be defined by the macro in the .data section of the current file. This macros
// will push the concatenation of prefix and fmt and will pop them from the
// stack.
// @param prefix: Prefix to the line to be printed.
// @param fmt: Format string.
#define _PRINTF(prefix, fmt)    ;\
    .section .data              ;\
    999999:                     ;\
    .ascii prefix               ;\
    .ascii " "                  ;\
    .asciz fmt                  ;\
    .section .text              ;\
    lea     eax, [999999b]      ;\
    push    eax                 ;\
    call    printf              ;\
    add     esp, 4

// Print an info message (prefixed by [INFO ]).
// @param fmt: The format string.
#define INFO(fmt)   ;\
    _PRINTF("[INFO ] :", fmt)

// Print a debug message (prefixed by [DEBUG]).
// @param fmt: The format string.
#define DEBUG(fmt)  ;\
    _PRINTF("[DEBUG] :", fmt)

// Print a warning message (prefixed by [WARN ]).
// @param fmt: The format string.
#define WARN(fmt)   ;\
    _PRINTF("[WARN ] :", fmt)
