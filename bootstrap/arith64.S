// This file contains routines to perform 64-bit arithmetic in 32-bit mode.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// ============================================================================= 
// Add two 64-bit values (A and B) and store the result in the destination.
// @param (DWORD) dest: Address where to store the result.
// @param (DWORD) A: Address of first operand.
// @param (DWORD) B: Address of second operand.
// ============================================================================= 
ASM_FUNC_DEF32(add64):
    push    ebp
    mov     ebp, esp
    push    ebx

    // EAX = A.
    mov     eax, [ebp + 0xC]
    // EBX = B.
    mov     ebx, [ebp + 0x10]
    // ECX = Dest.
    mov     ecx, [ebp + 0x8]

    // Add lower 32-bits first into EDX.
    mov     edx, [eax]
    add     edx, [ebx]
    // Store lower 32 bits.
    mov     [ecx], edx

    // Add upper 32-bits.
    mov     edx, [eax + 0x4]
    // The ADC instruction will add the two operand + the carry flag.
    adc     edx, [ebx + 0x4]
    // Store upper 32 bits.
    mov     [ecx + 0x4], edx

    pop     ebx
    leave
    ret

// ============================================================================= 
// Subtract a 64-bit value from another and store the result in the destination.
// This function will perform: dest = A - B.
// @param (DWORD) dest: Address where to store the result.
// @param (DWORD) A: Address of first operand.
// @param (DWORD) B: Address of second operand.
// ============================================================================= 
ASM_FUNC_DEF32(sub64):
    push    ebp
    mov     ebp, esp
    push    ebx

    // EAX = A.
    mov     eax, [ebp + 0xC]
    // EBX = B.
    mov     ebx, [ebp + 0x10]
    // ECX = Dest.
    mov     ecx, [ebp + 0x8]

    // Sub lower 32-bits first into EDX.
    mov     edx, [eax]
    sub     edx, [ebx]
    // Store lower 32 bits.
    mov     [ecx], edx

    // Sub upper 32-bits.
    mov     edx, [eax + 0x4]
    // The SBB instruction will sub the two operand + the carry flag.
    sbb     edx, [ebx + 0x4]
    // Store upper 32 bits.
    mov     [ecx + 0x4], edx

    pop     ebx
    leave
    ret

// ============================================================================= 
// Compare two 64-bit values and return the result of the comparison.
// @param (DWORD) A : first operand.
// @param (DWORD) B : second operand.
// @return (EAX) :
//          * ARITH64_BELOW if A < B
//          * ARITH64_EQUAL if A == B
//          * ARITH64_ABOVE if A > B
// ============================================================================= 
ASM_FUNC_DEF32(cmp64):
    push    ebp
    mov     ebp, esp
    push    ebx

    // EAX = A.
    mov     eax, [ebp + 0x8]
    // EBX = B.
    mov     ebx, [ebp + 0xC]

    // Compare upper DWORDs.
    mov     ecx, [eax + 0x4]
    cmp     ecx, [ebx + 0x4]
    // If the upper DWORDs are the same we need to compare the lower DWORDs to
    // make a decision.
    je      _lower_dwords
    ja      0f
    // If the upper DWORD of A is < than the upper DWORD of B then A < B.
    mov     eax, ARITH64_BELOW
    jmp     _out
0:
    // If the upper DWORD of A is > than the upper DWORD of B then A > B.
    mov     eax, ARITH64_ABOVE
    jmp     _out

_lower_dwords:
    // Compare the lower DWORDs.
    mov     ecx, [eax]
    cmp     ecx, [ebx]
    je      0f
    ja      1f

    // A < B.
    mov     eax, ARITH64_BELOW
    jmp     _out
0:
    // A == B.
    mov     eax, ARITH64_EQUAL
    jmp     _out
1:
    // A > B.
    mov     eax, ARITH64_ABOVE
    jmp     _out

_out:
    pop     ebx
    leave
    ret
