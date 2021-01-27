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
// pair (<test routine address>,<address to string containing test name>).
// The run_tests routine will iterate through the table and execute all tests it
// finds there while reporting successes and errors.
// Note: The test table is put in a special data section called .data.test_table

// Offset of the pointer to test routine in a test table entry.
.set TEST_TABLE_FUNC_NAME_OFF, 0x0
// Offset of the pointer to test name in a test table entry.
.set TEST_TABLE_FUNC_PTR_OFF, 0x4

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
// Execute all tests registered in the test table and print a summary.
// ============================================================================= 
ASM_FUNC_DEF32(run_tests):
    push    ebp
    mov     ebp, esp
    
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

    // Move to next entry in test table.
    add     ebx, 8
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
