// This file defines the routine allowing calling BIOS functions from 32-bit
// protected mode. The goal is to make the transitions 32-bit PM -> Real mode ->
// 32-bit PM transparent to the caller.
// The caller simply specifies the values of the registers and the interrupt to
// be called and this routine takes care of the rest.

.intel_syntax   noprefix

#include <asm_macros.h>
#include <consts.h>

// A BIOS Call Packet (BCP) is a structure that contains the values of the
// registers to be used for the BIOS call. Additionally it contains the value of
// the interrupt to be used and the value of the Carry Flag (only used for
// output).
// A 32-bit PM routine willing to execute a 16-bit BIOS function would allocate
// such a structure, fill in the values of the registers and the interrupt and
// pass the address of this structure/packet to the call_bios_func_32 routine.
// This routine will execute the BIOS function and fill the output values of the
// registers (and the CF of FLAGS) into the same structure.
// See consts.h for offset and size.

// ============================================================================= 
// Helper real-mode routine that, given an address to a BCP, set the registers
// to the requested values, raise the requested interrupts and writeback the
// register values (output) in the BCP structure.
// @param (WORD) bcp: Pointer on the BCP structure to be used for the bios call.
//
// Note: This routine cannot be executed on multiple cores at once.
// ============================================================================= 
ASM_FUNC_DEF16(_do_call_bios):
    push    bp
    mov     bp, sp

    // Never trust BIOS functions. Some might clobber registers.
    pushad

    // BX = Pointer on the BCP.
    mov     bx, [bp + 4]

    // Set the value of the interrupt number in this code. See comment below
    // describing the self-modifying code.
    // AL = Interrupt number of the BCP.
    mov     al, [bx]
    mov     [int_number], al

    // To set all the registers at once we will use a popad instruction. However
    // this requires the values to be onto the stack. Hence copy them from the
    // BCP onto the stack and then execute popad.

    // CX = number of bytes to copy = 8 * 4 
    mov     cx, 8 * 4

    // Make space on stack.
    sub     sp, cx

    // SI = Pointer to registers values.
    mov     si, bx
    add     si, BCP_EDI_OFF 
   
    // SI = top of stack.
    mov     di, sp

    // Do the copy.
    cld
    rep     movsb

    // Set all registers at once.
    popad

    // Execute the BIOS function by raising the interrupt:
    // i8086 (and later archs) do not support software interrupt with the vector
    // specified in a register, only immediate. Hence we use some self-modifying
    // code in order to be able to raise the interrupt with the requested vector
    // without doing a long "switch" statement to execute the correct
    // instruction.
    // The idea is simple: Put a 0xCD byte, which is the op-code of the `INT`
    // instruction, and follow it by a place holder byte, which is the immediate
    // holding the value of the vector. When this routine executes, it will
    // replace the immediate by the requested value.
    // The only down-side of doing things like this is that it is not safe to
    // execute this function concurrently on multiple cores. However this is not
    // expected to be the case.
    .byte   0xcd
int_number:
    .byte   0x00

    // Save the value of the registers as they appear right after the BIOS
    // function.
    pushad

    // CX = CF.
    pushf
    pop     cx
    and     cx, (1 << 0)

    // DI = Pointer on BCP. Note: Not sure we can trust the value of BP here.
    // Hence we only use SP. Offset = 8 * 4 (saved EGP) * 2 + 4
    mov     di, sp
    mov     di, [di + 8 * 4 * 2 + 4]

    // Write the CF value.
    mov     [di + BCP_CF_OFF], cl

    // Copy the registers. The process is pretty much the same as before but
    // with DI and SI reversed.
    add     di, BCP_EDI_OFF
    mov     si, sp
    mov     cx, 8 * 4
    cld
    rep     movsb

    // We can now get rid of the values on the stack.
    mov     sp, si 

    // Restore the registers as they were before all of this.
    popad

    pop     bp
    ret

// ============================================================================= 
// Call a BIOS function from 32-bit protected mode.
// @param (DWORD) bcp: The address of the BCP structure containing information
// about the BIOS call to make. This address MUST BE UNDER 1MiB. Once the
// function is executed this structure will contain the values of the registers
// as they were after returning from the interrupt.
// ============================================================================= 
ASM_FUNC_DEF32(call_bios_func_32):
    push    ebp
    mov     ebp, esp

    // The call_real_mode routine will clobber the EBX and EDI registers. Make
    // sure to save them.
    push    ebx
    push    edi

    // The BCP must be accessible from real-mode, hence it must be under
    // 0x100000 - sizeof(BCP).
    // EAX = Address of BCP.
    mov     eax, [ebp + 0x8]
    // ECX = 0xFFFFF - sizeof(BCP)
    mov     ecx, (1 << 20)
    sub     ecx, BCP_SIZE

    cmp     eax, ecx
    jbe     0f
    // Address is too big for 16-bits.
    call    panic
0:

    movzx   eax, ax    

    // Call the helper routine in real mode.
    // It is ok to push 32-bit here. The function will only use the first 16-bit
    // and we know the top 16-bits are 0 anyway.
    push    eax
    lea     eax, [_do_call_bios]
    push    eax
    call    call_real_mode
    add     esp, 8
    
    pop     edi
    pop     ebx
    leave
    ret
