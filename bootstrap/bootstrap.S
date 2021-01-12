// Bootstrap code loaded by the BIOS. This is in lieu of a bootloader. This
// routine will setup the processor from Real-Mode to 32-bit protected mode and
// jump to the main function of the rust code.

#include <asm_macros.h>

// This is an Intel syntax Minecraft server, so no $,%,(,) thanks.
.intel_syntax noprefix

// ============================================================================= 
// Entry point of the bootstrap code. This is what will be loaded into RAM by
// the BIOS.
// This routine will load the remaining sectors from the boot drive and jump to
// `second_sector_entry` present on the second sector.
// ============================================================================= 
ASM_FUNC_DEF16(entry):
    // Safety first, disable interrupts and set segment registers to safe
    // values (i.e. 0x0).
    cli

    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     gs, ax
    mov     fs, ax
    mov     ss, ax

    // Setting CS requires a far jump.
    jmp     0x0:0f
0:

    // Save the drive number passed by the BIOS
    mov     [drive_number], dl

    // Setup a small temporary stack below the image. The x86 memory map
    // indicate the region 0x0500 - 0x7BFF free to use.
    // See https://wiki.osdev.org/Memory_Map_(x86)
    mov     sp, 0x7C00

    // Load the rest of the bootstrap code from the boot drive.
    // EAX = number of blocks to load.
    lea     eax, [bootstrap_end]
    lea     ebx, [entry]
    sub     eax, ebx
    mov     ecx, eax

    shr     eax, 9

    and     ecx, 0xFF
    jz      0f
    // Size is not a multiple of 512, add 1 for the partial sector.
    inc     eax
0:
    // We will load the sectors from 1 to N.
    dec     eax

    // Save the number of sectors to load onto the stack. We will use it later
    // to compare with the output of the BIOS function.
    push    eax

    mov     WORD PTR [disk_access_packet_num_blocks], ax 
    mov     DWORD PTR [disk_access_packet_addr], 0x7E00
    mov     DWORD PTR [disk_access_packet_start_block], 1
    mov     DWORD PTR [disk_access_packet_start_block + 4], 0

    mov     ah, 0x42
    mov     dl, [drive_number]
    lea     si, [disk_access_packet]
    int     0x13

    // If carry flag is set then an error occured.
    jc      die

    // Check that all sectors have been loaded.
    pop     eax
    cmp     ax, [disk_access_packet_num_blocks]
    jne     die

    // All blocks have been successfully loaded, we can jump to the code on the
    // second sector.
    jmp     second_sector_entry

// ============================================================================= 
// Lock up the CPU. Indicate that something went wrong during early
// initialization.
// ============================================================================= 
ASM_FUNC_DEF16(die):
    //mov     ax, 0xdead
    mov     bx, 0xbeef
    cli
    int3
    jmp     die

// Data used by the code in the first sector:
    
// The number of the boot drive, passed by the BIOS.
drive_number:
.byte   0x0

// The disk access "packet", passed as argument when using the sector loading
// BIOS function.
disk_access_packet:
.byte   0x10
.byte   0x0
// Number of blocks to transfert.
disk_access_packet_num_blocks:
.word   0x0
disk_access_packet_addr:
.long   0x0
disk_access_packet_start_block:
.quad   0x0


. = 0x1FE
// Magic number at the end of the sector to make it bootable.
.short  0xAA55
// ############################################################################# 
// #########################  END OF FIRST SECTOR ##############################
// ############################################################################# 

#include <logging.S>

// ============================================================================= 
// Entry point of the bootstrap code on the second sector. This routine assumes
// that the entire bootstrap code has been loaded in RAM at address 0x7C00
// (first sector).
// This routine will enable 32-bit Protected Mode and jump to the main routine.
// ============================================================================= 
ASM_FUNC_DEF16(second_sector_entry):
    // Clear the buffer from logging from the BIOS.
    call    b_16_clear_vga_buffer

    // Print boot message with drive number.
    movzx   dx, BYTE PTR [drive_number]
    push    dx
    push    OFFSET FLAT : [str_boot_message]
    call    b_16_printf
    add     sp, 4

    // Save the Real-Mode IDT in case we ever want to go back to real-mode.
    sidt    [real_mode_idtr]

    // Jump to main routine in 32-bit PM.
    lea     eax, [bootstrap_main]
    push    eax
    call    jump_to_32_bit_protected_mode

    // Unreachable.
    int3

jmp_str:
.asciz  "Jump to 32-bit PM @ %d\n"

// ============================================================================= 
// Enable 32-bit Protection Mode and jump to a 32-bit routine. This routine
// DOES NOT RETURN.
// Note: This routine will NOT change the value of EAX. This is needed to
// implement real-mode function calls from protected mode.
// @param (DWORD) target: The address to jump to after the transition to 32-bit
// PM is complete.
// ============================================================================= 
ASM_FUNC_DEF16(jump_to_32_bit_protected_mode):
    // EAX = linear address of GDT.
    lea     edx, [gdt] 
    lea     cx, [gdt_end]
    // ECX = limit = sizeof(GDT) - 1
    sub     cx, dx
    dec     cx
    // Push table descriptor on stack and load it into GDTR.
    push    edx
    push    cx
    lgdt    [esp]
    add     esp, 6

    mov     edx, [esp + 0x2]
    push    edx
    lea     dx, [jmp_str]
    push    dx
    call    b_16_printf
    add     sp, 6

    // Enable protected mode bit (PE) in cr0.
    mov     edx, cr0
    or      edx, 1
    mov     cr0, edx
    
    // Warning: Nothing should be executed between the mov to cr0 and the jump.

    // Jump to protected mode
    jmp     0x20:0f
.code32
0:
    // We are now in 32 bits Protected mode, only the code segment register is
    // valid. Reset the others to use the data segment:
    mov     dx, 0x18
    mov     ds, dx
    mov     es, dx
    mov     gs, dx
    mov     fs, dx
    mov     ss, dx

    // EDX = address of the target.
    mov     edx, [esp + 0x2]

    // Clean up the stack. Need to remove:
    //  - Ret address (WORD)
    //  - Argument (DWORD)
    add     esp, 6

    // Jump to target.
    jmp     edx

// ============================================================================= 
// Call a real-mode routine from 32-bit protected mode. This routine will take
// the necessary step to come back in real-mode, execute the requested
// routine/target, come back to 32-bit protected mode and return.

// ==> WARNING: THIS ROUTINE WILL OVERWRITE EBX AND EDI. THOSE MUST BE SAVED BY
// THE CALLER BEFORE CALLING THIS ROUTINE. <==

// @param (DWORD) target: The address of the routine in real-mode.
// @return (EAX): The value returned by the real-mode routine. If applicable.
// ============================================================================= 
ASM_FUNC_DEF32(call_real_mode):
    // Disable paging. WARNING: This assumes the current code is 1:1 mapped. 
    mov     eax, cr0
    and     eax, ~(1 << 31)
    mov     cr0, eax
    xor     eax, eax
    mov     cr3, eax

    // Far jump to 16-bit protected mode.
    jmp     0x10:0f
.code16
0:
    // We are now in 16-bits protected mode. Reset other segment registers to
    // use the 16-bit entries of the GDT.
    mov     ax, 0x8
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax

    // Load the Real-Mode IDT.
    lidt    [real_mode_idtr]

    // Disable protected mode.
    mov     eax, cr0
    and     eax, ~1
    mov     cr0, eax

    // Far jump into Real-Mode.
    jmp     0x0:0f
0:
    // Set up segment registers for real mode.
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax

    // We need to remove the address of the caller and the argument here so that
    // the function will see the arguments that it needs. Save those values into
    // callee saved registers:
    // Save the address of the caller.
    pop     ebx
    // DI = address of target.
    pop     edi

    // Call the real mode function.
    call    di
    // (E)AX contains the return value from the function. It will not be changed
    // during jump_to_32_bit_protected_mode and will be returned to the caller
    // as-is.

    // The caller of this function expects the target address to be on top of
    // the stack after returning from this call. Since we poped this address, we
    // need to add it back.
    push    edi

    // Real-mode function is done executing. Return to the caller in protected
    // mode.
    push    ebx
    call    jump_to_32_bit_protected_mode

    // Unreachable.
    int3

// ============================================================================= 
// Main routine of the bootstrap code.
// Does not return.
// ============================================================================= 
ASM_FUNC_DEF32(bootstrap_main):
    // Example of calling a real-mode function from 32-bit PM.
    lea     ax, [str_main_message]
    sub     esp, 2
    mov     WORD PTR [esp], ax
    lea     eax, [b_16_printf]
    push    eax
    call    call_real_mode
    add     esp, 6

    // This is where we would typically jump to the rust main function.
    jmp     0f
0:
    cli
    hlt
    jmp     0b


// Data used by the bootstrap code:

// The one and only GDT.
gdt:
// Entry 0: NULL entry (required).
.quad 0x0
// Flat 16-bit data segment, ring 0, read/write.
.quad GDT_ENTRY16(0x0, 0xFFFFF, 2)
// Flat 16-bit code segment, ring 0, read, non-conforming.
.quad GDT_ENTRY16(0x0, 0xFFFFF, 10)
// Flat 32-bit data segment, ring 0, read/write.
.quad GDT_ENTRY32(0x0, 0xFFFFF, 2)
// Flat 32-bit code segment, ring 0, read, non-conforming.
.quad GDT_ENTRY32(0x0, 0xFFFFF, 10)
gdt_end:

// Saved value of the ITDR when the BIOS just loaded the first sector. This is
// used when switching back to real-mode from protected mode.
real_mode_idtr:
.skip   6

// Boot message displayed when the bootstrap code has been fully loaded.
str_boot_message:
.asciz  "Bootstrap code successfully loaded from drive %b\n"

str_main_message:
.asciz  "Bootstrap code main executed\n"

bootstrap_end:
