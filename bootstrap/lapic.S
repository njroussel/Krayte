// This file contains routines and state related to the Local APIC.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// LAPIC Registers offsets.
// End-Of-Interrupt register.
.set LAPIC_REG_EOI, 0xB0

// =============================================================================
// Initialize the Local APIC of the current cpu.
// =============================================================================
ASM_FUNC_DEF64(init_lapic):
    push    rbp
    mov     rbp, rsp

    // Map the LAPIC to virtual memory, use ID mapping to avoid confusion.
    mov     rdi, [LAPIC_ADDR]
    mov     rsi, rdi
    mov     rdx, (MAP_WRITE | MAP_CACHE_DISABLE | MAP_WRITE_THROUGH)
    call    map_frame

    leave
    ret

// =============================================================================
// Indicate the End-Of-Interrupt to the Local APIC.
// =============================================================================
ASM_FUNC_DEF64(lapic_eoi):
    mov     rax, [LAPIC_ADDR]
    // Any value works.
    mov     DWORD PTR [rax + LAPIC_REG_EOI], 0x0
    ret
