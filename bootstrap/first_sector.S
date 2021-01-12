// This is the first sector of the bootstrap code. This is in lieu of a
// bootloader and will be loaded by the BIOS at physical address 0x7C00.
// The goal of this file is to bring the entirety of the bootstrap code (and
// data) into RAM and execute it.

#include <asm_macros.h>

// This is an Intel syntax Minecraft server, so no $,%,(,) thanks.
.intel_syntax noprefix

// Use special .text section for the first sector so that the linker script
// knows which .text to put first in the final image.
.section    .text.first_sector

. = 0x0

// ============================================================================= 
// Entry point of the bootstrap code. This is what will be loaded into RAM by
// the BIOS.
// This routine will load the remaining sectors from the boot drive and jump to
// `second_sector_entry` present on the second sector.
// ============================================================================= 
ASM_FUNC_DEF16_NO_SECTION(entry):
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
    lea     eax, [BOOTSTRAP_END]
    lea     ebx, [BOOTSTRAP_START]
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
ASM_FUNC_DEF16_NO_SECTION(die):
    mov     ax, 0xdead
    mov     bx, 0xc0de
    cli
    int3
    jmp     die

// Put the data in the .text section for the first sector. This makes the linker
// script easier.
    
// The number of the boot drive, passed by the BIOS. Declared global so that the
// rest of the code outside the first sector can refer to it.
.global drive_number
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
