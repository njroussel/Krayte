// Tests for interrupts.

#include <asm_macros.h>
#include <consts.h>
#include <test_macros.h>

.intel_syntax   noprefix

.section .data
// Those values are used by the _set_registers_value helper to set the value of
// all general purpose 64-bit registers.
specific_val_rax: .quad 0xAAAAAAAAAAAAAAAA
specific_val_rbx: .quad 0xBBBBBBBBBBBBBBBB
specific_val_rcx: .quad 0xCCCCCCCCCCCCCCCC
specific_val_rdx: .quad 0xDDDDDDDDDDDDDDDD
specific_val_rbp: .quad 0xB0B0B0B0B0B0B0B0
specific_val_rdi: .quad 0xD1D1D1D1D1D1D1D1
specific_val_rsi: .quad 0x5151515151515151
specific_val_r8:  .quad 0x8888888888888888
specific_val_r9:  .quad 0x9999999999999999
specific_val_r10: .quad 0x1010101010101010
specific_val_r11: .quad 0x1111111111111111
specific_val_r12: .quad 0x1212121212121212
specific_val_r13: .quad 0x1313131313131313
specific_val_r14: .quad 0x1414141414141414
specific_val_r15: .quad 0x1515151515151515

// ============================================================================= 
// Set all general purpose registers values to some specific values.
// Note: RSP is left untouched.
// ============================================================================= 
ASM_FUNC_DEF64(_set_registers_value):
    mov     rax, QWORD PTR [specific_val_rax]
    mov     rbx, QWORD PTR [specific_val_rbx]
    mov     rcx, QWORD PTR [specific_val_rcx]
    mov     rdx, QWORD PTR [specific_val_rdx]
    mov     rbp, QWORD PTR [specific_val_rbp]
    mov     rdi, QWORD PTR [specific_val_rdi]
    mov     rsi, QWORD PTR [specific_val_rsi]
    mov     r8,  QWORD PTR [specific_val_r8]
    mov     r9,  QWORD PTR [specific_val_r9]
    mov     r10, QWORD PTR [specific_val_r10]
    mov     r11, QWORD PTR [specific_val_r11]
    mov     r12, QWORD PTR [specific_val_r12]
    mov     r13, QWORD PTR [specific_val_r13]
    mov     r14, QWORD PTR [specific_val_r14]
    mov     r15, QWORD PTR [specific_val_r15]
    ret

// ============================================================================= 
// Check that all general purpose registers (except RSP) have the same values as
// set by _set_registers_value.
// @return (RAX): 1 if values match, 0 otherwise.
// ============================================================================= 
ASM_FUNC_DEF64(_check_registers_value):
    cmp     rax, QWORD PTR [specific_val_rax]
    jne     ._check_registers_value_fail
    cmp     rbx, QWORD PTR [specific_val_rbx]
    jne     ._check_registers_value_fail
    cmp     rcx, QWORD PTR [specific_val_rcx]
    jne     ._check_registers_value_fail
    cmp     rdx, QWORD PTR [specific_val_rdx]
    jne     ._check_registers_value_fail
    cmp     rbp, QWORD PTR [specific_val_rbp]
    jne     ._check_registers_value_fail
    cmp     rdi, QWORD PTR [specific_val_rdi]
    jne     ._check_registers_value_fail
    cmp     rsi, QWORD PTR [specific_val_rsi]
    jne     ._check_registers_value_fail
    cmp     r8,  QWORD PTR [specific_val_r8]
    jne     ._check_registers_value_fail
    cmp     r9,  QWORD PTR [specific_val_r9]
    jne     ._check_registers_value_fail
    cmp     r10, QWORD PTR [specific_val_r10]
    jne     ._check_registers_value_fail
    cmp     r11, QWORD PTR [specific_val_r11]
    jne     ._check_registers_value_fail
    cmp     r12, QWORD PTR [specific_val_r12]
    jne     ._check_registers_value_fail
    cmp     r13, QWORD PTR [specific_val_r13]
    jne     ._check_registers_value_fail
    cmp     r14, QWORD PTR [specific_val_r14]
    jne     ._check_registers_value_fail
    cmp     r15, QWORD PTR [specific_val_r15]
    jne     ._check_registers_value_fail
    // All values match.
    mov     rax, 1
    ret
._check_registers_value_fail:
    // No match.
    xor     rax, rax
    ret

// #############################################################################
// ============================================================================= 
// Test that a registered callback is called upon a given interrupt.
// This is tested for _all_ interrupt vectors of the IDT.
// The test works as follows: For each vector V:
//  1. Register callback for V to use interrupt_callback_test_callback.
//  2. Reset interrupt_callback_test_callback_called to 0x0.
//  3. Raise a software interrupt with vector V.
//  4. Delete the callback for V.
//  5. Check that interrupt_callback_test_callback_called  is 0x1. This was set
//  by interrupt_callback_test_callback.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_callback_test):
    push    rbp
    mov     rbp, rsp
    push    rbx

    // BL = Vector of next interrupt.
    mov     bl, 0x0
    jmp     interrupt_callback_test_loop_cond
interrupt_callback_test_loop:
    // Register the callback.
    movzx   rdi, bl
    lea     rsi, [interrupt_callback_test_callback]
    call    set_interrupt_callback

    // Reset interrupt_callback_test_callback_called.
    mov     BYTE PTR [interrupt_callback_test_callback_called], 0x0

    // Raise the interrupt. We use some self-modifying code in order to have a
    // "generic" INT instruction. This is ok because bootstrap code is mapped as
    // writable (for now).
    mov     BYTE PTR [interrupt_callback_test_int_vec], bl

    // 0xCD is the opcode for the INT imm8 instruction.
    .byte   0xCD
interrupt_callback_test_int_vec:
    .byte   0x0

    // Delete the callback.
    movzx   rdi, bl
    call    del_interrupt_callback

    // Check that the callback was called.
    movzx   rax, BYTE PTR [interrupt_callback_test_callback_called]
    test    rax, rax
    jz      interrupt_callback_test_failed

    // Next iteration.
    inc     bl
interrupt_callback_test_loop_cond:
    cmp     bl, INTERRUPT_IDT_SIZE
    jb      interrupt_callback_test_loop

    // Success.
    mov     rax, 1
    jmp     interrupt_callback_test_end
interrupt_callback_test_failed:
    // Failure.
    xor     rax, rax

interrupt_callback_test_end:
    pop     rbx
    leave
    ret
REGISTER_TEST64(interrupt_callback_test)

.section .data
// Indicate if the interrupt_callback_test_callback was called.
interrupt_callback_test_callback_called:
.byte   0x0

// ============================================================================= 
// The callback used for each vector in the interrupt_callback_test routine.
// This routine will set interrupt_callback_test_callback_called to 1.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_callback_test_callback):
    mov     BYTE PTR [interrupt_callback_test_callback_called], 1
    ret

// #############################################################################
// ============================================================================= 
// Test checking that the interrupt frame pointer passed to an interrupt
// callback points to correct information, that is:
//  - Saved register values are correct.
//  - Vector is correct.
//  - Hardware interrupt frame is correct.
// The test works as follows, for all vector V.
//  1. Register interrupt callback for V and reset success flag.
//  2. Set registers to some values.
//  3. Raise software interrupt vector V.
//  4. In callback:
//      4.1. Check the values of the saved registers of the interrupt frame.
//      4.2. Check the value of the vector in the interrupt frame.
//      4.3. Check the hardware interrupt frame.
//      4.4. If all the above successful, set the success flag.
//  5. (After returning from INT) Check the success flag.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_callback_int_frame_test):
    push    rbp
    mov     rbp, rsp
    // Save all callee-saved registers, we will clobber them as part of the
    // test.
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    // BL = Next vector to raise.
    xor     rbx, rbx
._interrupt_callback_int_frame_test_loop:
    // Register callback.
    movzx   rdi, bl
    lea     rsi, [interrupt_callback_int_frame_test_callback]
    call    set_interrupt_callback

    // Reset flag.
    mov     BYTE PTR [interrupt_callback_int_frame_test_success_flag], 0x0

    // Set the vector for the interrupt. We need to do this before overwritting
    // RBX.
    mov     BYTE PTR [._interrupt_callback_int_frame_test_vec], bl

    // We need to save RBP and RBX since they will be overwritten by
    // _set_registers_value.
    push    rbp
    push    rbx

    // Set all registers to some values.
    call    _set_registers_value

    // Set the expected RFLAGS and RSP for the callback.
    pushfq
    pop     [interrupt_callback_int_frame_test_expected_rflags]
    mov     [interrupt_callback_int_frame_test_expected_rsp], rsp
    // Raise the interrupt.
    .byte   0xCD
._interrupt_callback_int_frame_test_vec:
    .byte   0x0
    // Software interrupts generate "traps" hence the expected RIP is the
    // instruction following the INT. This is what the callback expects for the
    // saved value of RIP in the interrupt frame.
interrupt_callback_int_frame_test_expected_rip:

    pop     rbx
    pop     rbp

    // Remove the callback.
    movzx   rdi, bl
    call    del_interrupt_callback

    // Check the success flag.
    movzx   rax, BYTE PTR [interrupt_callback_int_frame_test_success_flag]
    test    rax, rax
    jz      ._interrupt_callback_int_frame_test_fail

    // Try with next vector.
    inc     bl
._interrupt_callback_int_frame_test_loop_cond:
    cmp     bl, INTERRUPT_IDT_SIZE
    jb      ._interrupt_callback_int_frame_test_loop

    // Success.
    mov     rax, 1
    jmp     ._interrupt_callback_int_frame_test_end
._interrupt_callback_int_frame_test_fail:
    xor     rax, rax
._interrupt_callback_int_frame_test_end:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    leave
    ret
REGISTER_TEST64(interrupt_callback_int_frame_test)

.section .data
// The success flags. This is used by the callback to indicate success.
interrupt_callback_int_frame_test_success_flag:
.byte   0x0
// The expected value for RFLAGS in the interrupt frame.
interrupt_callback_int_frame_test_expected_rflags:
.quad   0x0
// The expected value for RSP in the interrupt frame.
interrupt_callback_int_frame_test_expected_rsp:
.quad   0x0


// ============================================================================= 
// Callback for an interrupt generated during
// interrupt_callback_int_frame_test_callback. This routine will check the
// interrupt frame passed as argument and expects the following:
//  - Saved values of registers correspond to values set by
//  _set_registers_value.
//  - Vector matches ._interrupt_callback_int_frame_test_vec.
//  - Info pushed by the hardware is consistent with what we expects.
// If everything is in order, this routine will set
// interrupt_callback_int_frame_test_success_flag to 0x1. Otherwise it sets it
// to 0x0.
// @param (RDI): The interrupt frame.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_callback_int_frame_test_callback):
    push    rbp
    mov     rbp, rsp

    // Check the saved values of the registers.
    // TODO: Once again we are not supporting segment registers here.
    mov     rax, [specific_val_rax]
    cmp     [rdi + INT_FRAME_SAVED_RAX_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_rbx]
    cmp     [rdi + INT_FRAME_SAVED_RBX_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_rcx]
    cmp     [rdi + INT_FRAME_SAVED_RCX_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_rdx]
    cmp     [rdi + INT_FRAME_SAVED_RDX_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_rbp]
    cmp     [rdi + INT_FRAME_SAVED_RBP_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_rsi]
    cmp     [rdi + INT_FRAME_SAVED_RSI_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_rdi]
    cmp     [rdi + INT_FRAME_SAVED_RDI_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r8]
    cmp     [rdi + INT_FRAME_SAVED_R8_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r9]
    cmp     [rdi + INT_FRAME_SAVED_R9_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r10]
    cmp     [rdi + INT_FRAME_SAVED_R10_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r11]
    cmp     [rdi + INT_FRAME_SAVED_R11_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r12]
    cmp     [rdi + INT_FRAME_SAVED_R12_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r13]
    cmp     [rdi + INT_FRAME_SAVED_R13_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r14]
    cmp     [rdi + INT_FRAME_SAVED_R14_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [specific_val_r15]
    cmp     [rdi + INT_FRAME_SAVED_R15_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail

    // Check the vector.
    movzx   rax, BYTE PTR [._interrupt_callback_int_frame_test_vec]
    cmp     rax, [rdi + INT_FRAME_VECTOR_OFF]
    jne     ._interrupt_callback_int_frame_test_callback_fail

    // Check the hardware interrupt frame. 
    // FIXME: Hardcoded 64-bit data segment.
    cmp     QWORD PTR [rdi + INT_FRAME_SS_OFF], 0x28
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [interrupt_callback_int_frame_test_expected_rsp]
    cmp     [rdi + INT_FRAME_RSP_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    mov     rax, [interrupt_callback_int_frame_test_expected_rflags]
    cmp     [rdi + INT_FRAME_RFLAGS_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    // FIXME: Hardcoded 64-bit code segment.
    cmp     QWORD PTR [rdi + INT_FRAME_CS_OFF], 0x30
    jne     ._interrupt_callback_int_frame_test_callback_fail
    // Software interrupts do not add error messages, hence we expect the dummy
    // one added by generic_handler.
    mov     rax, 0xC0DEC0DEC0DEC0DE
    cmp     QWORD PTR [rdi + INT_FRAME_ERROR_CODE_OFF], rax
    jne     ._interrupt_callback_int_frame_test_callback_fail
    cmp     QWORD PTR [rdi + INT_FRAME_RIP_OFF], OFFSET FLAT : \
            interrupt_callback_int_frame_test_expected_rip
    jne     ._interrupt_callback_int_frame_test_callback_fail

    // Success, set the flags to true.
    mov     BYTE PTR [interrupt_callback_int_frame_test_success_flag], 0x1
    leave
    ret
._interrupt_callback_int_frame_test_callback_fail:
    // Failure, make sure the success flag is false.
    mov     BYTE PTR [interrupt_callback_int_frame_test_success_flag], 0x0
    leave
    ret

// #############################################################################
// ============================================================================= 
// Tests that general purpose registers are correctly restored by the generic
// interrupt handler before returning to the interrupted context.
// This is tested in the following scenario:
//  1. All registers are set to specific values.
//  2. A software interrupt is raised. The callback clobbers all caller-saved
//  registers.
//  3. After returning from the interrupt the values of each register is checked
//  against its respective expected value.
// Unfortunately this test has a big limitation: The callback can only clobber
// caller-saved registers, otherwise it could lead to errors in the generic
// interrupt handler.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_registers_save_test):
    push    rbp
    mov     rbp, rsp
    // Save all callee-saved registers.
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    // 1. Register callback. For this test we use interrupt vector = 0x0.
    xor     rdi, rdi
    lea     rsi, [interrupt_registers_save_test_callback]
    call    set_interrupt_callback

    // 2. Set all registers to distincts values. We cannot set the stack pointer
    // to an arbitrary value. This would produce a page fault.
    call    _set_registers_value
    // TODO: We should probably try to set the segment registers to different
    // values. However for now saving and restoring of seg registers is not
    // supported. This is because the application code won't touch them. In the
    // future we should add this feature, for completness ...

    // 3. Raise the interrupt.
    int     0x0

    // 4. Check the values of the registers.
    // RAX = Result of comparison = result of the test.
    call    _check_registers_value

    // Remove interrupt callback.
    push    rax
    xor     rdi, rdi
    call    del_interrupt_callback
    pop     rax

    // Restore callee-saved regs.
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    leave
    ret
REGISTER_TEST64(interrupt_registers_save_test)

// ============================================================================= 
// Callback for the interrupt raised in interrupt_register_save_test. This
// callback will clobber all caller-saved registers.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_registers_save_test_callback):
    // Make sure that all caller-saved registers get a different value from what
    // they had before. This is easily done by NOTing them.
    not     rax
    not     rcx
    not     rdx
    not     rdi
    not     rsi
    not     r8
    not     r9
    not     r10
    not     r11
    ret


// #############################################################################
// ============================================================================= 
// Test that an interrupt callback can overwrite saved registers and that the
// writes will be reflected in the interrupted context once it resumes
// execution. This test works as follows:
//  1. Set registers to some value.
//  2. Raise an interrupt vector = V.
//  3. In the callback for V:
//      3.1. NOT all saved general purpose registers values.
//      3.2. Change saved RIP.
//      3.3. Change saved RFLAGS (Set the carry flag).
//  4. When returning from the INT, NOT all registers.
//  5. Check all register values using _check_registers_value. This should be
//  successful since the NOT in step 4 cancelled the NOT from the callback.
// Any vector will do, we choose V = 0x0.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_register_overwrite_test):
    push    rbp
    mov     rbp, rsp
    // Save all callee-saved registers.
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    // 1. Register callback. For this test we use interrupt vector = 0x0.
    xor     rdi, rdi
    lea     rsi, [interrupt_register_overwrite_test_callback]
    call    set_interrupt_callback

    // 2. Set all registers to distincts values. We cannot set the stack pointer
    // to an arbitrary value. This would produce a page fault.
    call    _set_registers_value
    // TODO: Segment registers unchanged.

    mov     [interrupt_register_overwrite_test_expected_rsp], rsp
    not     QWORD PTR [interrupt_register_overwrite_test_expected_rsp]

    // Unset the Carry Flag so we are sure that if it set after the interrupt
    // this would have come from the handler.
    clc

    // 3. Raise the interrupt.
    int     0x0
    PANIC64("interrupt_register_overwrite_test: RIP was not changed")

interrupt_register_overwrite_test_exp_rip:
    // This is what the interrupt callback will change the RIP to.

    // Check the CF in RFLAGS, it should be set.
    jnc     ._interrupt_register_overwrite_test_fail_fixup_rsp

    // Check RSP against interrupt_register_overwrite_test_expected_rsp.
    cmp     rsp, [interrupt_register_overwrite_test_expected_rsp]
    jne     ._interrupt_register_overwrite_test_fail_fixup_rsp

    // Restore all GPs by NOTing them, including the RSP.
    not     rsp
    not     rax
    not     rbx
    not     rcx
    not     rdx
    not     rbp
    not     rdi
    not     rsi
    not     r8
    not     r9
    not     r10
    not     r11
    not     r12
    not     r13
    not     r14
    not     r15

    // Check the values of the registers. They should match the
    // _set_registers_value.
    // RAX = Result of comparison = result of the test.
    call    _check_registers_value

    jmp     ._interrupt_register_overwrite_test_end
._interrupt_register_overwrite_test_fail_fixup_rsp:
    // If we end up here then the RSP is not valid. However we can recover the
    // previous RSP and exit the test.
    mov     rsp, [interrupt_register_overwrite_test_expected_rsp]
    not     rsp
    // The test is a failure.
    xor     rax, rax

._interrupt_register_overwrite_test_end:

    // Remove interrupt callback.
    push    rax
    xor     rdi, rdi
    call    del_interrupt_callback
    pop     rax

    // Restore callee-saved regs.
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    leave
    ret
REGISTER_TEST64(interrupt_register_overwrite_test)

.section .data
// The expected value of the RSP after returning from the interrupt.
interrupt_register_overwrite_test_expected_rsp:
.quad   0x0

// ============================================================================= 
// Callback for the interrupt raised in interrupt_register_overwrite_test. This
// callback will NOT all the saved registers, set the CF in RFLAGS and set the
// saved RIP to interrupt_register_overwrite_test_exp_rip.
// @param (RDI): Pointer to the interrupt frame.
// ============================================================================= 
ASM_FUNC_DEF64(interrupt_register_overwrite_test_callback):
    // NOT all GPs, including RSP.
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RAX_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RBX_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RCX_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RDX_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RBP_OFF]
    not     QWORD PTR [rdi + INT_FRAME_RSP_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RSI_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_RDI_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R8_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R9_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R10_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R11_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R12_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R13_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R14_OFF]
    not     QWORD PTR [rdi + INT_FRAME_SAVED_R15_OFF]

    // Set the carry flag (bit 1) in RFLAGS.
    or      QWORD PTR [rdi + INT_FRAME_RFLAGS_OFF], 1 

    // Change the RIP to point after the PANIC.
    lea     rax, [interrupt_register_overwrite_test_exp_rip]
    mov     [rdi + INT_FRAME_RIP_OFF], rax
    ret
