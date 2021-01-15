// Some tests for the routines defined in arith64.S.

#include <asm_macros.h>
#include <test_macros.h>

.intel_syntax   noprefix

// ============================================================================= 
// Test the add64 routine.
// ============================================================================= 
ASM_FUNC_DEF32(add64_test):
    push    ebp
    mov     ebp, esp
    push    ebx

    // A = 0x0000DEADBABEBABE.
    push    0xDEAD
    push    0xBABEBABE
    mov     eax, esp

    // B = 0x0000BEEFCAFECAFE.
    push    0xBEEF
    push    0xCAFECAFE
    mov     ebx, esp

    // Allocate space for result.
    sub     esp, 8
    mov     ecx, esp
    
    // Do A + B.
    push    ebx
    push    eax
    push    ecx
    call    add64
    add     esp, 12

    // Check result.
    cmp     DWORD PTR [esp], 0x85BD85BC
    jne     0f
    cmp     DWORD PTR [esp + 0x4], 0x19D9D
    jne     0f

    // Test success.
    mov     eax, 1
    jmp     1f

0:
    // Test failure.
    xor     eax, eax

1:
    // Get rid of result and operands.
    add     esp, 24

    pop     ebx
    leave
    ret
REGISTER_TEST(add64_test)
