// Bootstrap code loaded by the BIOS. This is in lieu of a bootloader. This
// routine will setup the processor from Real-Mode to 32-bit protected mode and
// jump to the main function of the rust code.

#include <asm_macros.h>

// This is an Intel syntax Minecraft server, so no $,%,(,) thanks.
.intel_syntax noprefix

.code16
.global entry
entry:
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

    // Setup a small temporary stack below the image. The x86 memory map
    // indicate the region 0x0500 - 0x7BFF free to use.
    // See https://wiki.osdev.org/Memory_Map_(x86)
    mov     sp, 0x7C00
    
    // Setup GDTR and jump into protected 32-bit mode.
    // EAX = linear address of GDT.
    lea     eax, [gdt] 
    lea     bx, [gdt_end]
    // EBX = limit = sizeof(GDT) - 1
    sub     bx, ax
    dec     bx
    // Push table descriptor on stack and load it into GDTR.
    push    eax
    push    bx
    lgdt    [esp]
    add     esp, 6

    // Enable protected mode bit (PE) in cr0.
    mov     eax, cr0
    or      eax, 1
    mov     cr0, eax
    
    // Warning: Nothing should be executed between the mov to cr0 and the jump.

    // Jump to protected mode
    jmp     0x10:protected_mode_entry

.code32
protected_mode_entry:
    // We are now in 32 bits Protected mode, only the code segment register is
    // valid. Reset the others to use the data segment:
    mov     ax, 0x8
    mov     ds, ax
    mov     es, ax
    mov     gs, ax
    mov     fs, ax
    mov     ss, ax

    // This is where we would put a jump/call to the main function of the rust
    // code.
    jmp     0f

0:
    // In case we return from the main function, simply halt forever.
    cli
    hlt
    jmp     0b

// Under this line is the data used by the bootstrap routine.
// The one and only GDT.
gdt:
// Entry 0: NULL entry (required).
.quad 0x0
// Entry 1: Flat data segment, page granularity, read/write, non-conforming.
.quad GDT_ENTRY(0x0, 0xFFFFF, 2)
// Entry 2: Flat code segment, page granularity, read only, non-conforming.
.quad GDT_ENTRY(0x0, 0xFFFFF, 10)
gdt_end:

// Magic number at the end of the sector to make it bootable.
. = 0x1FE
.short  0xAA55
