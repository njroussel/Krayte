#include <asm_macros.h>
#include <test_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// Data used by the call_real_mode_test test.
.section .data
// Indicate that the 16-bit routine was successfully executed and the stack
// pointer was correct.
_call_real_mode_test_exp_target_executed:
.byte   0x0
// The expected stack pointer in the called 16-bit routine.
_call_real_mode_test_exp_sp:
.word   0x0

// ============================================================================= 
// Helper to the call_real_mode_test routine. This is what will be executed in
// real mode by the test.
// This routine compares its SP with the expected one stored in
// _call_real_mode_test_exp_sp and, if it is the same, will write 0x1 into
// _call_real_mode_test_exp_target_executed and put 0xABABBABA in EAX.
// ============================================================================= 
ASM_FUNC_DEF16(_call_real_mode_test_target):
    // Check the SP.
    cmp     sp, WORD PTR [_call_real_mode_test_exp_sp]
    jne     0f

    // SP ok.
    mov     BYTE PTR [_call_real_mode_test_exp_target_executed], 0x1 
    mov     eax, 0xABABBABA
    jmp     1f
0:
    // Test failure.
    mov     BYTE PTR [_call_real_mode_test_exp_target_executed], 0x0 
    xor     eax, eax
1:
    ret

// ============================================================================= 
// Test the call_real_mode routine.
// ============================================================================= 
ASM_FUNC_DEF32(call_real_mode_test):
    push    ebp
    mov     ebp, esp

    // call_real_mode will clobber the EBX and EDI registers.
    push    ebx
    push    edi

    // The stack on the target should look like the stack right before the call
    // to call_real_mode + a 16-bit return address pushed.
    lea     eax, [esp - 2]
    mov     [_call_real_mode_test_exp_sp], ax

    // Call the real mode routine.
    lea     eax, [_call_real_mode_test_target]
    push    eax
    call    call_real_mode
    add     esp, 4

    // Check that the target was executed.
    cmp     BYTE PTR [_call_real_mode_test_exp_target_executed], 0x1
    jne     0f

    // Check the value of EAX.
    cmp     eax, 0xABABBABA
    jne     0f

    // Success.
    mov     eax, 0x1
    jmp     1f

0:
    // Failure.
    xor     eax, eax

1:
    pop     edi
    pop     ebx

    leave
    ret
REGISTER_TEST(call_real_mode_test)

// call_bios_func_32 testing:
//  1 - Overwrite an entry in the real-mode IVT to point to the test handler.
//  2 - Prepare a BCP with arbitratry values for all registers.
//  3 - Call call_bios_func_32 with the BCP.
//  4 - In the test handler: Check that the values of the registers are as
//  expected, set _call_bios_func_32_handler_success if this is the case. Then
//  write all the registers to some other value and set the CF flag. Finally
//  return from the interrupt.
//  5 - Back in protected mode test, check that the output values stored in the
//  BCP are as expected (same as written in the test handler), and that the CF
//  value is reported as 0x1.
//  6 - Restore the IVT entry back.
.section .data
// The value of the IVT entry used by the test, before the test.
ivt_entry_bak:
.long   0x0
// Used by the test handler to indicate that it was successfully ran. That is
// all registers had expected values.
_call_bios_func_32_handler_success:
.byte   0x0

// The interrupt vector used by the test.
interrupt_vector:
// Fall-through to first byte of _call_bios_func_32_test_bcp.
// The BCP used in the test. Each register has a distinct non-zero value.
_call_bios_func_32_test_bcp:
.byte   0x3         // This is the vector of the interrupt.
.byte   0x0         // CF
.long   0xEEEEEEEE  // EDI
.long   0x55555555  // ESI
.long   0x88888888  // EBP
.long   0x00000000  // ESP: Ignored.
.long   0xBBBBBBBB  // EBX
.long   0xDDDDDDDD  // EDX
.long   0xCCCCCCCC  // ECX
.long   0xAAAAAAAA  // EAX


// ============================================================================= 
// Test interrupt handler for the call_bios_func_32_test. This handler will
// compare the current value of the registers with the ones in the BCP. If they
// are the same then it will set the _call_bios_func_32_handler_success to 0x1
// and change the values of all registers to their 1-complement and set the CF
// flag in FLAGS. Otherwise it writes 0x0 in _call_bios_func_32_handler_success.
// ============================================================================= 
ASM_FUNC_DEF16(_call_bios_func_32_handler):
    pushad
    
    // Compare the saved values of the GP registers with the ones from the BCP.
    // Note: We first need to fixup the ESP value in the BCP. This is because it
    // is not controllable.
    // ECX = Saved value of ESP onto the stack.
    mov     bx, sp
    mov     ecx, [bx + 0xC]
    // Fixup.
    lea     bx, [_call_bios_func_32_test_bcp + 0x2]
    mov     [bx + 0xC], ecx

    // Compare the values.
    mov     si, sp
    mov     di, bx
    mov     cx, 8
    cld
    repe    cmpsd
    jne     0f

    // Values are the same, success.
    mov     BYTE PTR [_call_bios_func_32_handler_success], 0x1

    // Now do two things:
    //  - Change the value of all the registers (except ESP).
    //  - Set the Carry Flag to 1.
    // Both of these operations are done on the saved values so that they will
    // be restored.

    // Change values of GPs. We simply NOT them all.
    mov     cx, 8
    mov     si, sp
change_loop:
    not     DWORD PTR [si] 
    add     si, 4
    loop    change_loop

    // Set carry flag.
    mov     bx, sp
    add     bx, 4 * 8 + 4
    mov     cx, [bx]
    or      cx, (1 << 0)
    mov     [bx], cx

    // Test over, return to 32-bit PM.
    jmp     1f
0:
    // Failure.
    mov     BYTE PTR [_call_bios_func_32_handler_success], 0x0
1:
    // Restore registers and return from interrupt context.
    popad
    iret

// ============================================================================= 
// Test the call_bios_func_32 routine, see comment above explaining how this
// test works.
// ============================================================================= 
ASM_FUNC_DEF32(call_bios_func_32_test):
    push    ebp
    mov     ebp, esp
    push    edi
    push    esi

    // Change the real-mode IVT interrupt handler for interrupt
    // `interrupt_vector` to use our custom handler.
    // IVT is _typically_ at address 0x0. TODO: We should really make sure.
    // EAX = Ptr to IVT entry.
    movzx   ecx, BYTE PTR [interrupt_vector]
    lea     eax, [0x0 + ecx * 4]

    // Save current entry.
    mov     edx, [eax]
    mov     [ivt_entry_bak], edx
    
    // Write new entry.
    // ECX = new entry.
    lea     cx, [_call_bios_func_32_handler]
    movzx   ecx, cx
    mov     [eax], ecx

    // Make a copy of the BCP reg values onto the stack. This will be used later
    // to compare the output with the expected one.
    sub     esp, BCP_SIZE - 2
    lea     esi, [_call_bios_func_32_test_bcp + 0x2]
    mov     edi, esp
    mov     ecx, 8
    cld
    rep     movsd

    // Call the dummy BIOS function.
    lea     eax, [_call_bios_func_32_test_bcp]
    push    eax
    call    call_bios_func_32
    add     esp, 4

    // Check that the dummy handler was executed.
    cmp     BYTE PTR [_call_bios_func_32_handler_success], 0x1
    jne     0f

    // Check the output values of the registers (stored in the original BCP).
    // First generate expected values.
    mov     ecx, 8
    mov     esi, esp
expected_gen_loop:
    not     DWORD PTR [esi]
    add     esi, 4
    loop    expected_gen_loop
    // Fixup the value of the ESP.
    mov     eax, [_call_bios_func_32_test_bcp + 0x2 + 0xC]
    mov     [esp + 0xC], eax
    // Do the comparison
    mov     ecx, 8
    mov     esi, esp
    lea     edi, [_call_bios_func_32_test_bcp + 0x2]
    repe    cmpsd
    jne     0f 

    // Values are the same as expected ones. Check that the Carry Flag was set.
    cmp     BYTE PTR [_call_bios_func_32_test_bcp + 0x1], 0x1
    jne     0f

    // Success.
    mov     eax, 1
    jmp     1f
0:
    // Failure.
    xor     eax, eax
1:
    // Remove copy of BCP.
    add     esp, BCP_SIZE - 2

    // Restore the IVT entry.
    movzx   ecx, BYTE PTR [interrupt_vector]
    lea     eax, [0x0 + ecx * 4]
    mov     edx, [ivt_entry_bak]
    mov     [eax], edx

    pop     esi
    pop     edi
    leave
    ret
REGISTER_TEST(call_bios_func_32_test)
