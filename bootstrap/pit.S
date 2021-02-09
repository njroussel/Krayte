// This file contains helper routines to interact with the legacy Programmable
// Interval Timer (PIT).
// The main usage for the PIT is to calibrate frequencies of counters for which
// frequency is not well defined, this can include: Time-Stamp Counter, LAPIC
// timer, ... The `calibrate_counter_with_pit` routine provides a generic way to
// estimate the frequency of a counter.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// The port for the data channel 0.
.set CHAN0_DATA_PORT, 0x40
// The command port of the PIT.
.set MODE_CMD_PORT, 0x43

// =============================================================================
// Start the PIT with frequency PIT_FREQ. This routine will take care of
// re-routing the legacy PIT IRQ to INTERRUPT_PIT_VEC and will ENABLE
// interrupts.
// Note: It is the responsibility of the caller to register the callback for
// INTERRUPT_PIT_VEC.
// =============================================================================
ASM_FUNC_DEF64(start_pit):
    push    rbp
    mov     rbp, rsp

    // Redirect PIT IRQ (0) to vector INTERRUPT_PIT_VEC.
    xor     rdi, rdi
    mov     rsi, INTERRUPT_PIT_VEC
    call    ioapic_redir_legacy_irq

    // Setup the PIT to fire an interrupt with frequency PIT_FREQ Hz.
    mov     al, (0b11 << 4) | (0b010 << 1)
    out     MODE_CMD_PORT, al
    mov     ax, PIT_RELOAD_VAL
    out     CHAN0_DATA_PORT, al
    rol     ax, 8
    // The second write to the data port will start the pit.
    out     CHAN0_DATA_PORT, al

    // Enable interrupts.
    sti

    leave
    ret

// =============================================================================
// Stop the PIT. This routine masks the PIT IRQ on the I/O APIC. This routine
// does _NOT_ disable interrupts.
// =============================================================================
ASM_FUNC_DEF64(stop_pit):
    // TODO: Once we can mask IRQs on the I/O APIC we should call that here.
    ret

// Calibration related data. See below.
.section .data
// The number of iterations/interrupts received so far.
_calibrate_counter_with_pit_iterations:
.short  0x0
// The maximum number of iterations/interrupts used to calibrate.
.set CALIBRATE_WITH_PIT_MAX_ITE, 100

// =============================================================================
// Interrupt callback used during calibration. This routine simply increments
// the _calibrate_counter_with_pit_iterations unless it is already equals to
// CALIBRATE_WITH_PIT_MAX_ITE.
// =============================================================================
ASM_FUNC_DEF64(_calibrate_counter_with_pit_callback):
    lea     rax, [_calibrate_counter_with_pit_iterations]
    cmp     WORD PTR [rax], CALIBRATE_WITH_PIT_MAX_ITE
    jae     0f
    inc     WORD PTR [rax]
0:
    ret

// =============================================================================
// Calibrate an arbitrary counter using the PIT. The counter must be started
// _PRIOR_ to calling this routine. This routine starts the PIT, waits for
// CALIBRATE_WITH_PIT_MAX_ITE PIT interrupts to come in and finally computes the
// counter's frequency by using the start and end value and the PIT frequence.
// @param (RDI): Pointer on routine reading the current value of the counter
// into RAX.
// @return (RAX): The frequency of the counter in Hz.
// =============================================================================
ASM_FUNC_DEF64(calibrate_counter_with_pit):
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    // RBX = read routine.
    mov     rbx, rdi

    mov     eax, (1000 * CALIBRATE_WITH_PIT_MAX_ITE / PIT_FREQ)
    push    rax
    INFO64("Performing calibration with PIT, expected time = %d ms\n")
    add     esp, 8

    // Register callback for interrupt INTERRUPT_PIT_VEC.
    mov     rdi, INTERRUPT_PIT_VEC
    lea     rsi, [_calibrate_counter_with_pit_callback]
    call    set_interrupt_callback

    // Reset _calibrate_counter_with_pit_iterations.
    mov     WORD PTR [_calibrate_counter_with_pit_iterations], 0x0

    // Start PIT.
    call    start_pit

    // Read the start value. We do this _after_ starting the PIT because it is
    // likely that starting the PIT has a bigger overhead than reading the
    // current value.
    // R12 = Start value.
    call    rbx
    mov     r12, rax

    // Wait for CALIBRATE_WITH_PIT_MAX_ITE iterrupts ...
._calibrate_counter_with_pit_wait:
    hlt
    cmp     WORD PTR [_calibrate_counter_with_pit_iterations], \
            CALIBRATE_WITH_PIT_MAX_ITE
    jb      ._calibrate_counter_with_pit_wait

    // Wait is over. Disable interrupts and read the end value.
    cli
    // R13 = End value.
    call    rbx
    mov     r13, rax

    // Stop the PIT.
    call    stop_pit

    // Compute the frequency of the counter using the following equation:
    //  F = (end - start) / (N / PIT_FREQ) = PIT_FREQ * (end - start) / NUM_ITE
    //    = PIT_FREQ * (r13 - r12) / N
    mov     rax, r13
    sub     rax, r12
    mov     rcx, PIT_FREQ
    imul    rcx
    mov     rcx, CALIBRATE_WITH_PIT_MAX_ITE
    // RAX = Freq.
    idiv    rcx

    push    rax
    // Delete the interrupt callback used for the calibration.
    mov     rdi, INTERRUPT_PIT_VEC
    call    del_interrupt_callback
    pop     rax

    pop     r13
    pop     r12
    pop     rbx
    leave
    ret
