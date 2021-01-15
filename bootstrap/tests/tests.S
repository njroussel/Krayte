// Main file for testing. This will run all the tests of the project.

#include <asm_macros.h>
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
// Execute all tests registered in the test table and print a summary.
// ============================================================================= 
ASM_FUNC_DEF32(run_tests):
    push    ebp
    mov     ebp, esp
    
    // Local variables:
    // EBP - 0x4: Number of tests ran so far.
    // EBP - 0x8: Number of successful test so far.
    push    0x0
    push    0x0

    push    ebx

    // EBX = Address in test table.
    lea     ebx, [TEST_TABLE_START]

    jmp     cond
loop:
    // EAX = Address of test routine.
    mov     eax, [ebx + TEST_TABLE_FUNC_PTR_OFF] 
    // Run the test
    call    eax

    // Increment the number of tests ran.
    inc     DWORD PTR [ebp - 0x4]

    // Print correct prefix depending on the outcome of the test.
    test    eax, eax
    jnz     0f
    
    // Test was a failure. Print failure prefix.
    _PRINTF("[TEST ] [FAIL] :", "")
    jmp     1f

0:
    // Test was a success. Print success prefix.
    _PRINTF("[TEST ] [ OK ] :", "")
    // And increase successes count.
    inc     DWORD PTR [ebp - 0x8]

1:
    // Print test name.
    push    [ebx + TEST_TABLE_FUNC_NAME_OFF]
    call    printf
    add     esp, 4

    push    '\n'
    call    putc_vga_buffer
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
    _PRINTF("[TEST ] [SUMM] :", "%d / %d tests failed!\n")
    add     esp, 8
    jmp     1f

0:
    // All tests Successful.
    push    [ebp - 0x4]
    _PRINTF("[TEST ] [SUMM] :", "All %d tests passed!\n")
    add     esp, 4

1:
    pop     ebx
    leave
    ret
