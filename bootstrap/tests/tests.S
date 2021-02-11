// Main file for testing. This will run all the tests of the project.

#include <asm_macros.h>
#include <consts.h>
#include <test_macros.h>

.intel_syntax   noprefix

// Testing Architecture
// ====================
//   Tests are no more than routines not taking any argument and returning a
// boolean in EAX indicating success or failure (EAX == 1 => success).
// To add a new test one simply needs to define the test routine and then call
// the REGISTER_TEST(<test_name>) macro.
// Registered tests are put in the "Test table" which is simply an array of
// tuples (<test mode>, <test name address>,<test routine address>). The <test
// mode> is a byte value equal to 32 or 64 indicating the mode required to run
// the test.
// The run_tests32 and run_tests64 routines will iterate through the table and
// execute all tests it finds there while reporting successes and errors.
// Note: The test table is put in a special data section called .data.test_table

// Offset of the mode in a test table entry.
.set TEST_TABLE_MODE_OFF, 0x0
// Offset of the pointer to test routine in a test table entry.
.set TEST_TABLE_FUNC_NAME_OFF, 0x1
// Offset of the pointer to test name in a test table entry.
.set TEST_TABLE_FUNC_PTR_OFF, 0x5
.set TEST_TABLE_ENTRY_SIZE, 0x9

// ============================================================================= 
// Check that no callee saved register has been clobbered during a test. This
// can catch a lot of accidental clobbering (from implementation or even tests
// themselves) but not all unfortunately.
// No arguments and no return, however ESP is expected to point on saved
// registers (from pusha) before calling this function.
// This routine will panic if any clobbering is detected.
// ============================================================================= 
ASM_FUNC_DEF32(_check_callee_save_registers):
    // EAX = pointer to saved registers.
    lea     eax, [esp + 4]

    // We can reuse the consts BCP_<reg>_OFF here. All we need to do is sub 2
    // from them since the first saved register in the BCP is at offset 0x2.
    cmp     edi, [eax + BCP_EDI_OFF - 0x2]
    jne     0f
    cmp     esi, [eax + BCP_ESI_OFF - 0x2]
    jne     0f
    cmp     ebp, [eax + BCP_EBP_OFF - 0x2]
    jne     0f
    cmp     ebx, [eax + BCP_EBX_OFF - 0x2]
    jne     0f

    jmp     1f
0:
    PANIC32("Register clobbering detected!\n")
    // Unreachable
    int3
1:
    ret

// ============================================================================= 
// Execute all 32-bit tests registered in the test table and print a summary.
// ============================================================================= 
ASM_FUNC_DEF32(run_tests32):
    push    ebp
    mov     ebp, esp

    INFO32("Running 32-bit tests\n")
    
    // Local variables:
    // EBP - 0x4: Number of tests ran so far.
    // EBP - 0x8: Number of successful test so far.
    // EBP - 0xC: Return value of last test.
    push    0x0
    push    0x0
    push    0x0

    push    ebx

    // EBX = Address in test table.
    lea     ebx, [TEST_TABLE_START]

    jmp     cond
loop:
    // AL = Mode of the test.
    mov     al, [ebx + TEST_TABLE_MODE_OFF]
    cmp     al, 32
    // If the mode is not 32-bits skip the test.
    jne     next

    // EAX = Address of test routine.
    mov     eax, [ebx + TEST_TABLE_FUNC_PTR_OFF] 

    // Push the GP registers onto the stack right before calling the test. We
    // will use these saved values to detect any register clobbering.
    pusha
    // Run the test
    call    eax
    // Save return value during call to _check_callee_save_registers.
    mov     [ebp - 0xC], eax

    // Check that no callee-saved register has been clobbered.
    call    _check_callee_save_registers
    // Remove saved registers.
    add     esp, 4 * 8

    // Increment the number of tests ran.
    inc     DWORD PTR [ebp - 0x4]

    // Print correct prefix depending on the outcome of the test.
    mov     eax, [ebp - 0xC]
    test    eax, eax
    jnz     0f
    
    // Test was a failure. Print failure prefix.
    _PRINTF32("[TEST ] [FAIL] :", "")
    jmp     1f

0:
    // Test was a success. Print success prefix.
    _PRINTF32("[TEST ] [ OK ] :", "")
    // And increase successes count.
    inc     DWORD PTR [ebp - 0x8]

1:
    // Print test name.
    push    [ebx + TEST_TABLE_FUNC_NAME_OFF]
    call    printf32
    add     esp, 4

    push    '\n'
    call    _putc32
    add     esp, 4

next:
    // Move to next entry in test table.
    add     ebx, TEST_TABLE_ENTRY_SIZE
cond:
    lea     eax, [TEST_TABLE_END]
    cmp     ebx, eax
    jb      loop

    // All tests executed print summary.
    mov     eax, [ebp - 0x4]
    cmp     eax, [ebp - 0x8]
    je      0f

    // Not all tests were successful.
    sub     eax, [ebp - 0x8]
    push    [ebp - 0x4]
    push    eax
    _PRINTF32("[TEST ] [SUMM] :", "%d / %d tests failed!\n")
    add     esp, 8
    jmp     1f

0:
    // All tests Successful.
    push    [ebp - 0x4]
    _PRINTF32("[TEST ] [SUMM] :", "All %d tests passed!\n")
    add     esp, 4

1:
    pop     ebx
    leave
    ret

// ============================================================================= 
// Check that no callee saved register has been clobbered during a 64-bit test.
// This can catch a lot of accidental clobbering (from implementation or even
// tests themselves) but not all unfortunately.
// No arguments and no return, however RSP is expected to point on saved
// registers before calling this function.
// This routine will panic if any clobbering is detected.
// ============================================================================= 
ASM_FUNC_DEF64(_check_callee_save_registers64):
    // RAX = pointer to saved registers.
    lea     rax, [rsp + 8]

    cmp     r15, [rax + 0 * 0x8]
    jne     0f
    cmp     r14, [rax + 1 * 0x8]
    jne     0f
    cmp     r13, [rax + 2 * 0x8]
    jne     0f
    cmp     r12, [rax + 3 * 0x8]
    jne     0f
    cmp     rbp, [rax + 4 * 0x8]
    jne     0f
    cmp     rbx, [rax + 5 * 0x8]
    jne     0f

    jmp     1f
0:
    PANIC64("Register clobbering detected!\n")
    // Unreachable
    int3
1:
    ret

// ============================================================================= 
// Execute all 64-bit tests registered in the test table and print a summary.
// ============================================================================= 
ASM_FUNC_DEF64(run_tests64):
    push    rbp
    mov     rbp, rsp

    INFO64("Running 64-bit tests\n")

    // Local variables:
    // RBP - 0x8: Number of tests ran so far.
    // RBP - 0x10: Number of successful test so far.
    // RBP - 0x18: Return value of last test.
    push    0x0
    push    0x0
    push    0x0

    push    rbx

    // RBX = Address in test table.
    lea     rbx, [TEST_TABLE_START]

    jmp     ._run_tests64_loop_cond
._run_tests64_loop:
    // AL = Mode of the test.
    mov     al, [ebx + TEST_TABLE_MODE_OFF]
    cmp     al, 64
    // If the mode is not 64-bits skip the test.
    jne     ._run_tests64_loop_next

    // RAX = Address of test routine.
    // Note: The adddresses in the test table are 32-bit.
    mov     eax, [rbx + TEST_TABLE_FUNC_PTR_OFF]

    // Push the callee-saved registers onto the stack right before calling the
    // test. We will use these saved values to detect any register clobbering.
    // 64-bit callee-saved registers: RBX, RBP, R12 -> R15
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    // Run the test
    call    rax
    // Save return value during call to _check_callee_save_registers.
    mov     [rbp - 0x18], rax

    // Check that no callee-saved register has been clobbered.
    call    _check_callee_save_registers64
    // Remove saved registers.
    add     rsp, 6 * 8

    // Increment the number of tests ran.
    inc     QWORD PTR [rbp - 0x8]

    // Print correct prefix depending on the outcome of the test.
    mov     rax, [rbp - 0x18]
    test    rax, rax
    jnz     0f

    // Test was a failure. Print failure prefix.
    _PRINTF64("[TEST ] [FAIL] :", "")
    jmp     1f

0:
    // Test was a success. Print success prefix.
    _PRINTF64("[TEST ] [ OK ] :", "")
    // And increase successes count.
    inc     QWORD PTR [rbp - 0x10]

1:
    // Print test name.
    // Note: Addresses are 32-bit in a table entry.
    mov     edi, [rbx + TEST_TABLE_FUNC_NAME_OFF]
    call    printf64

    mov     rdi, '\n'
    call    _putc64

._run_tests64_loop_next:
    // Move to next entry in test table.
    add     rbx, TEST_TABLE_ENTRY_SIZE
._run_tests64_loop_cond:
    lea     rax, [TEST_TABLE_END]
    cmp     rbx, rax
    jb      ._run_tests64_loop

    // All tests executed print summary.
    mov     rax, [rbp - 0x8]
    cmp     rax, [rbp - 0x10]
    je      0f

    // Not all tests were successful.
    sub     rax, [rbp - 0x10]
    push    [rbp - 0x8]
    push    rax
    _PRINTF64("[TEST ] [SUMM] :", "%q / %q tests failed!\n")
    add     rsp, 16
    jmp     1f

0:
    // All tests Successful.
    push    [rbp - 0x8]
    _PRINTF64("[TEST ] [SUMM] :", "All %q tests passed!\n")
    add     rsp, 8

1:
    pop     rbx
    leave
    ret
