// This file contains routines and state related to the Local APIC.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// LAPIC Registers offsets.
// End-Of-Interrupt register.
.set LAPIC_REG_EOI, 0xB0
.set LAPIC_REG_INIT_COUNT, 0x380
.set LAPIC_REG_CURR_COUNT, 0x390
// Divide Configuration Register (for timer).
.set LAPIC_REG_DIV_CONF, 0x3E0

.section .data
// The frequency of the LAPIC Timer in Hz.
LAPIC_FREQ:
.quad   0x0

// =============================================================================
// Initialize the Local APIC of the current cpu. This routine will calibrate the
// frequency of the timer as well.
// =============================================================================
ASM_FUNC_DEF64(init_lapic):
    push    rbp
    mov     rbp, rsp

    // Disable the legacy Programmable Interrupt Controller (PIC). Having PIC
    // and APIC at the same time is just asking for trouble.
    mov     al, 0xff
    out     0xa1, al
    out     0x21, al

    // Map the LAPIC to virtual memory, use ID mapping to avoid confusion.
    mov     rdi, [LAPIC_ADDR]
    mov     rsi, rdi
    mov     rdx, (MAP_WRITE | MAP_CACHE_DISABLE | MAP_WRITE_THROUGH)
    call    map_frame

    // Initialize the divide configuration register to use 1 as divisor. This
    // MUST NEVER CHANGE, since this is the value that we will calibrate.
    mov     eax, DWORD PTR [rbx + LAPIC_REG_DIV_CONF]
    or      eax, (1 << 3) | 3
    mov     DWORD PTR [rbx + LAPIC_REG_DIV_CONF], eax

    // Calibrate the LAPIC timer.
    call    _calibrate_lapic_timer

    leave
    ret

// =============================================================================
// Calibrate the LAPIC timer's frequency using the PIT. This routine will write
// the frequency to LAPIC_FREQ.
// =============================================================================
ASM_FUNC_DEF64(_calibrate_lapic_timer):
    push    rbp
    mov     rbp, rsp

    INFO64("Calibrating LAPIC timer frequency\n")

    // RAX = Pointer to LAPIC.
    mov     rax, [LAPIC_ADDR]

    // Start LAPIC timer countdown. Set to maximum value.
    mov     DWORD PTR [rax + LAPIC_REG_INIT_COUNT], ~0

    lea     rdi, [_calibrate_lapic_timer_read_curr_count]
    // RAX = LAPIC timer frequency.
    call    calibrate_counter_with_pit
    // Since the timer counts down, the result will be a negative frequency,
    // negate it to get the real frequency.
    neg     rax

    mov     [LAPIC_FREQ], rax
    push    rax
    INFO64("LAPIC Timer freq = %q Hz\n")
    add     esp, 8

    leave
    ret

// =============================================================================
// Helper routine used during calibration to read the current value of the LAPIC
// timer.
// =============================================================================
ASM_FUNC_DEF64(_calibrate_lapic_timer_read_curr_count):
    mov     rax, [LAPIC_ADDR]
    mov     eax, [rax + LAPIC_REG_CURR_COUNT]
    ret

// =============================================================================
// Indicate the End-Of-Interrupt to the Local APIC.
// =============================================================================
ASM_FUNC_DEF64(lapic_eoi):
    mov     rax, [LAPIC_ADDR]
    // Any value works.
    mov     DWORD PTR [rax + LAPIC_REG_EOI], 0x0
    ret
