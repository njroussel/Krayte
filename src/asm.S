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
.set SYSNR_LOG_SERIAL, 0x3
.set SYSNR_SBRK, 0x4

.section .text
.code64
.global getTscFreq
.type   getTscFreq, @function
getTscFreq:
    mov     rax, SYSNR_GET_TSC_FREQ
    int     SYSCALL_INTERRUPT_VECTOR
    ret

.section .text
.code64
.global logSerial
.type   logSerial, @function
logSerial:
    mov     rax, SYSNR_LOG_SERIAL
    int     SYSCALL_INTERRUPT_VECTOR
    ret

.section .text
.code64
.global sbrk
.type   sbrk, @function
sbrk:
    mov     rax, SYSNR_SBRK
    int     SYSCALL_INTERRUPT_VECTOR
    ret
