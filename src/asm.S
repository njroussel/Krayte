.intel_syntax   noprefix
.section .text
.code64
.global readTsc
.type   readTsc, @function
readTsc:
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    ret

// Interrupt vector used for syscalls through software interrupts.
.set SYSCALL_INTERRUPT_VECTOR, 0x21
// Syscall number for GET_TSC_FREQ.
.set SYSNR_GET_TSC_FREQ, 0x2

.section .text
.code64
.global getTscFreq
.type   getTscFreq, @function
getTscFreq:
    mov     rax, SYSNR_GET_TSC_FREQ
    int     SYSCALL_INTERRUPT_VECTOR
    ret
