// Some tests for the routines defined in arith64.S.

#include <asm_macros.h>
#include <consts.h>
#include <test_macros.h>

.intel_syntax   noprefix

// ============================================================================= 
// Test the cmp64 routine, all cases (e.g. A > B, A < B and A == B.
// ============================================================================= 
ASM_FUNC_DEF32(cmp64_test):
    push    ebp
    mov     ebp, esp
    push    edi
    push    esi

    // A = 0xC0DEDEADBABEBABE.
    push    0xC0DEDEAD
    push    0xBABEBABE
    mov     edi, esp

    // B = 0xABCDBEEFCAFECAFE.
    push    0xABCDBEEF
    push    0xCAFECAFE
    mov     esi, esp

    // cmp64(A, B) == ARITH64_ABOVE
    push    esi
    push    edi
    call    cmp64
    add     esp, 8
    cmp     eax, ARITH64_ABOVE
    jne     1

    // cmp64(B, A) == ARITH64_BELOW
    push    edi
    push    esi
    call    cmp64
    add     esp, 8
    cmp     eax, ARITH64_BELOW
    jne     1

    // cmp64(A, A) == ARITH64_EQUAL
    push    edi
    push    edi
    call    cmp64
    add     esp, 8
    cmp     eax, ARITH64_EQUAL
    jne     1
    
0:
    // Test success.
    mov     eax, 1
    jmp     2f

1:
    // Test failure.
    xor     eax, eax

2:
    // Get rid of result and operands.
    add     esp, 0x10

    pop     esi
    pop     edi
    leave
    ret
REGISTER_TEST(cmp64_test)

// ============================================================================= 
// Test the add64 routine.
// ============================================================================= 
ASM_FUNC_DEF32(add64_test):
    push    ebp
    mov     ebp, esp
    push    edi
    push    esi

    // A = 0x0000DEADBABEBABE.
    push    0xDEAD
    push    0xBABEBABE
    mov     edi, esp

    // B = 0x0000BEEFCAFECAFE.
    push    0xBEEF
    push    0xCAFECAFE
    mov     esi, esp

    // Allocate res.
    sub     esp, 8
    mov     ecx, esp
    
    // Do A + B.
    push    esi
    push    edi
    push    ecx
    call    add64
    add     esp, 12

    // Expected.
    push    0x19D9D
    push    0x85BD85BC
    mov     ecx, esp

    // Compare result.
    lea     eax, [esp + 8]
    push    eax
    push    ecx
    call    cmp64
    add     esp, 8
    test    eax, eax
    jnz     0f

    // Test success.
    mov     eax, 1
    jmp     1f

0:
    // Test failure.
    xor     eax, eax

1:
    // Get rid of result and operands + expected result.
    add     esp, 0x20

    pop     esi
    pop     edi
    leave
    ret
REGISTER_TEST(add64_test)

// ============================================================================= 
// Test the sub64 routine.
// ============================================================================= 
ASM_FUNC_DEF32(sub64_test):
    push    ebp
    mov     ebp, esp
    push    edi
    push    esi

    // A = 0xC0DEDEADBABEBABE.
    push    0xC0DEDEAD
    push    0xBABEBABE
    mov     edi, esp

    // B = 0xABCDBEEFCAFECAFE.
    push    0xABCDBEEF
    push    0xCAFECAFE
    mov     esi, esp

    // Allocate space for result.
    sub     esp, 8
    mov     ecx, esp
    
    // Do A - B.
    push    esi
    push    edi
    push    ecx
    call    sub64
    add     esp, 12

    // Expected result.
    push    0x15111FBD
    push    0xEFBFEFC0
    mov     ecx, esp

    // Compare result. 
    lea     eax, [esp + 8]
    push    eax
    push    ecx
    call    cmp64
    add     esp, 8
    test    eax, eax
    jnz     0f

    add     esp, 8

    // Do B - A.
    mov     ecx, esp
    push    edi
    push    esi
    push    ecx
    call    sub64
    add     esp, 12

    // Expected result.
    push    0xEAEEE042
    push    0x10401040
    mov     ecx, esp

    // Compare result. 
    lea     eax, [esp + 8]
    push    eax
    push    ecx
    call    cmp64
    add     esp, 8
    test    eax, eax
    jnz     0f

    // Test success.
    mov     eax, 1
    jmp     1f

0:
    // Test failure.
    xor     eax, eax

1:
    // Get rid of result and operands + expected result.
    add     esp, 0x20

    pop     esi
    pop     edi
    leave
    ret
REGISTER_TEST(sub64_test)
