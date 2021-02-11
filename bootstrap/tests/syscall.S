// Tests for syscall handling.

#include <asm_macros.h>
#include <consts.h>
#include <test_macros.h>

.intel_syntax   noprefix

// ============================================================================= 
// Register a handler for one of the test syscall numbers.
// @param (RDI): Syscall number (0 or 1).
// @param (RSI): Handler's address.
// ============================================================================= 
ASM_FUNC_DEF64(_set_test_handler):
    push    rbp
    mov     rbp, rsp

    cmp     rdi, 1
    jbe     0f
    PANIC64("_set_test_handler: Syscall number too high, expected 0 or 1")
0:

    lea     rax, [SYSCALL_TABLE]
    mov     [rax + rdi * 8], rsi
    leave
    ret 

// ============================================================================= 
// Test that syscalls are correctly dispatched to the correct handler given the
// syscall number.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_dispatch_test):
    push    rbp
    mov     rbp, rsp

    call    init_syscall

    xor     rdi, rdi
    lea     rsi, [syscall_dispatch_test_handler0]
    call    _set_test_handler

    mov     rdi, 1
    lea     rsi, [syscall_dispatch_test_handler1]
    call    _set_test_handler

    mov     BYTE PTR [syscall_dispatch_test_flag], 0xFF
    mov     rax, SYSNR_TEST0
    int     INTERRUPT_SYSCALL_VEC

    cmp     BYTE PTR [syscall_dispatch_test_flag], 0x0
    jne     ._syscall_dispatch_test_fail

    mov     BYTE PTR [syscall_dispatch_test_flag], 0xFF
    mov     rax, SYSNR_TEST1
    int     INTERRUPT_SYSCALL_VEC

    cmp     BYTE PTR [syscall_dispatch_test_flag], 0x1
    jne     ._syscall_dispatch_test_fail

    // Success.
    mov     rax, 1
    jmp     ._syscall_dispatch_test_end

._syscall_dispatch_test_fail:
    xor     rax, rax
._syscall_dispatch_test_end:
    push    rax
    call    reset_syscall
    pop     rax
    leave
    ret
REGISTER_TEST64(syscall_dispatch_test)

// ============================================================================= 
// Test handler for SYSNR_TEST0. This routine will simply set
// syscall_dispatch_test_flag to 0.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_dispatch_test_handler0):
    mov     BYTE PTR [syscall_dispatch_test_flag], 0x0
    ret

// ============================================================================= 
// Test handler for SYSNR_TEST1. This routine will simply set
// syscall_dispatch_test_flag to 1.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_dispatch_test_handler1):
    mov     BYTE PTR [syscall_dispatch_test_flag], 0x1
    ret

.section .data
// Flag for the syscall_dispatch_test. This byte indicate which handler was
// called last.
syscall_dispatch_test_flag:
.byte   0xFF


// ============================================================================= 
// Test that parameters are correctly passed to a syscall handler.
// This test works as follows:
//  1. The test routine set its parameter registers to some specific values.
//  2. Call SYSNR_TEST0.
//  3. The handler for SYSNR_TEST0 checks the value of the param registers
//  against the expected ones.
//  4. If the values are correct, it sets the flag to 1.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_param_unpack_test):
    push    rbp
    mov     rbp, rsp

    call    init_syscall
    
    // Set handler for SYSNR_TEST0.
    mov     rdi, SYSNR_TEST0
    lea     rsi, [syscall_param_unpack_test_handler]
    call    _set_test_handler

    // Reset flag.
    mov     BYTE PTR [syscall_param_unpack_test_flag], 0x0

    // Set the param registers.
    mov     rdi, 0xD1D1D1D1D1D1D1D1
    mov     rsi, 0x5151515151515151
    mov     rdx, 0xDDDDDDDDDDDDDDDD
    mov     rcx, 0xCCCCCCCCCCCCCCCC
    mov     r8,  0x8888888888888888
    mov     r9,  0x9999999999999999

    // Call syscall.
    mov     rax, SYSNR_TEST0
    int     INTERRUPT_SYSCALL_VEC

    call    reset_syscall

    // Check flag.
    cmp     BYTE PTR [syscall_param_unpack_test_flag], 0x1
    sete    al
    movzx   rax, al
    leave
    ret
REGISTER_TEST64(syscall_param_unpack_test)

// ============================================================================= 
// Handler for SYSNR_TEST0 in syscall_param_unpack_test. This routine will
// compare the value of RDI, RSI, RDX, RCX, R8 and R9 with their respective
// value before the syscall. If they match then it sets the
// syscall_param_unpack_test_flag to 0x1, else it sets it to 0x0.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_param_unpack_test_handler):
    mov     rax, 0xD1D1D1D1D1D1D1D1
    cmp     rdi, rax
    jne     ._syscall_param_unpack_test_handler_fail
    mov     rax, 0x5151515151515151
    cmp     rsi, rax
    jne     ._syscall_param_unpack_test_handler_fail
    mov     rax, 0xDDDDDDDDDDDDDDDD
    cmp     rdx, rax
    jne     ._syscall_param_unpack_test_handler_fail
    mov     rax, 0xCCCCCCCCCCCCCCCC
    cmp     rcx, rax
    jne     ._syscall_param_unpack_test_handler_fail
    mov     rax,  0x8888888888888888
    cmp     r8,  rax
    jne     ._syscall_param_unpack_test_handler_fail
    mov     rax,  0x9999999999999999
    cmp     r9,  rax
    jne     ._syscall_param_unpack_test_handler_fail
    // Success.
    mov     BYTE PTR [syscall_param_unpack_test_flag], 0x1
    ret
._syscall_param_unpack_test_handler_fail:
    // Failure.
    mov     BYTE PTR [syscall_param_unpack_test_flag], 0x0
    ret

.section .data
// Success flag for syscall_param_unpack_test.
syscall_param_unpack_test_flag:
.byte   0x0


// ============================================================================= 
// This test checks that the return value of a syscall handler is correctly
// reported into the RAX register in the interrupted context after the IRET.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_return_value_test):
    push    rbp
    mov     rbp, rsp

    call    init_syscall

    // Register the temp handler.
    mov     rdi, SYSNR_TEST0
    lea     rsi, [syscall_return_value_test_handler]
    call    _set_test_handler

    // Choose a "random" value for the return value. Use the TSC for that. Make
    // sure RAX has its upper DWORD non-zero.
    rdtsc
    mov     rdx, rax
    not     rdx
    shl     rdx, 32
    or      rax, rdx
    mov     [syscall_return_value_test_expected_rax], rax

    // Exec the syscall.
    mov     rax, SYSNR_TEST0
    int     INTERRUPT_SYSCALL_VEC

    // Check RAX, it should be equal to the expected value.
    cmp     rax, [syscall_return_value_test_expected_rax]
    jne     ._syscall_return_value_test_fail

    // Success
    mov     rax, 1
    jmp     ._syscall_return_value_test_end
._syscall_return_value_test_fail:
    xor     rax, rax
._syscall_return_value_test_end:
    push    rax
    call    reset_syscall
    pop     rax
    leave
    ret
REGISTER_TEST64(syscall_return_value_test)

// ============================================================================= 
// Write syscall_return_value_test_expected_rax into RAX.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_return_value_test_handler):
    mov     rax, [syscall_return_value_test_expected_rax]
    ret

.section .data
// The value of RAX to be returned by the syscall_return_value_test_handler.
syscall_return_value_test_expected_rax:
.quad   0x0

// ============================================================================= 
// Test the SYSNR_GET_TSC_FREQ syscall.
// ============================================================================= 
ASM_FUNC_DEF64(syscall_get_tsc_freq_test):
    push    rbp
    mov     rbp, rsp

    call    init_syscall

    mov     rax, SYSNR_GET_TSC_FREQ
    int     INTERRUPT_SYSCALL_VEC

    cmp     rax, [TSC_FREQ]
    sete    al
    movzx   rax, al

    push    rax
    call    reset_syscall
    pop     rax
    leave
    ret
REGISTER_TEST64(syscall_get_tsc_freq_test)
