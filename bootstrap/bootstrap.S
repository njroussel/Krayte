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

// Lock up the CPU. Indicate that something went wrong during early
// initialization.
die:
    //mov     ax, 0xdead
    mov     bx, 0xbeef
    cli
    hlt
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
// ============================================================================= 
// END OF FIRST SECTOR.
// ============================================================================= 



// Width of the VGA text buffer in number of characters.
.set VGA_WIDTH, 80
// Height of the VGA text buffer in number of characters.
.set VGA_HEIGHT, 25
// Segment to use to write into the VGA text buffer.
.set VGA_SEGMENT, 0xB800

// Clear the VGA text buffer. This result in a black screen.
b_16_clear_vga_buffer:
    push    bp
    mov     bp, sp
    push    di

    mov     ax, VGA_SEGMENT
    mov     es, ax
    xor     di, di
    mov     ecx, VGA_WIDTH * VGA_HEIGHT
    // Zero out the entire buffer.
    xor     ax, ax
    cld
    rep     stosw

    // On a clear the cursor is reset to 0 == top left corner.
    mov     WORD PTR [b_16_putc_vga_buffer_cursor], 0x0

    mov     es, ax
    pop     di
    pop     bp
    ret

// Scroll the VGA text buffer up, and clear the bottom line.
b_16_scroll_vga_buffer:
    push    bp
    mov     bp, sp
    push    si
    push    di
    
    mov     ax, VGA_SEGMENT
    mov     es, ax
    mov     ds, ax

    // Copy the content from line i+1 to line i for all lines except the bottom
    // one.
    xor     di, di
    mov     si, VGA_WIDTH * 2
    mov     ecx, VGA_WIDTH * VGA_HEIGHT - VGA_WIDTH
    cld
    rep     movsw

    // DI now points to the first char of the botton line. Zero it out.
    mov     ecx, VGA_WIDTH
    xor     ax, ax
    cld
    rep     stosw

    mov     es, ax
    mov     ds, ax

    pop     di
    pop     si
    pop     bp
    ret

// Print a char in the VGA text buffer. This function will scroll the buffer if
// needed.
// @param char: The ASCII char to be printed.
b_16_putc_vga_buffer:
    push    bp
    mov     bp, sp
    push    bx

    mov     ax, VGA_SEGMENT
    mov     es, ax

    // AL = char to write.
    mov     al, [bp + ARG(0)] 

    // 0x0A == '\n'.
    cmp     al, 0x0A
    je      1f

    // Attribute = 0x7 == light grey char on black background.
    mov     ah, 0x7
    mov     bx, [b_16_putc_vga_buffer_cursor]
    // Convert cursor index to offset in the buffer (that is * sizeof(u16)).
    shl     bx, 1

    // Write char.
    mov     es:[bx], ax
    shr     bx, 1

    xor     ax, ax
    mov     es, ax
    jmp     0f

1:
    // This is a new-line char. Advance the cursor to the start of the next
    // line.
    mov     ax, [b_16_putc_vga_buffer_cursor]
    mov     bx, VGA_WIDTH
    // AL = cursor / VGA_WIDTH, AH = cursor % VGA_WIDTH.
    div     bl
    
    sub     bl, ah
    add     bx, [b_16_putc_vga_buffer_cursor]
    // The cursor will be updated underneath. Fix up so the update puts the
    // cursor at the beginning of the line.
    sub     bx, 2

0:
    // Advance cursor and check if it is now out of bounds. If it is then scroll
    // up the buffer.
    inc     bx
    mov     [b_16_putc_vga_buffer_cursor], bx
    cmp     bx, VGA_WIDTH * VGA_HEIGHT
    jb      0f
    
    // We reached the end of the VGA buffer, time to scroll up.
    call    b_16_scroll_vga_buffer
    // The cursor goes to the beginning of the last line.
    mov     WORD PTR [b_16_putc_vga_buffer_cursor], VGA_WIDTH * (VGA_HEIGHT - 1)
    
0:
    pop     bx
    pop     bp
    ret
// Cursor of the VGA text buffer. Indicate the index of the next char to be
// printed.
b_16_putc_vga_buffer_cursor:
.word   0x0

// Output an hexadecimal value into the VGA buffer.
// @param size: The number of bytes of the value.
// @param addr: Address where the value is stored.
_b_16_printf_output_hex:
    push    bp
    mov     bp, sp

    push    bx
    
    // Put '0'.
    push    0x30
    call    b_16_putc_vga_buffer
    add     sp, 2

    // Put 'x'.
    push    0x78
    call    b_16_putc_vga_buffer
    add     sp, 2

    // Since x86 is little-endian, the byte following the "0x" will be the byte
    // at ths address `addr + size - 1`. Hence we will iterates over the bytes
    // of the value in reverse, that is MSB first and finish with LSB.

    // BX = address of the MSByte of the value.
    mov     bx, [bp + ARG(1)]
    add     bx, [bp + ARG(0)]
    dec     bx

    jmp     1f
// Loop head, iterate over all bytes.
0:
    // AL = current byte.
    mov     al, [bx]

    // In order to output the correct representation of the byte, we need to do
    // some ASCII math on each half/4bits composing the byte.
    // The goal here is to make two calls to b_16_putc_vga_buffer with the
    // correct digit or letter.
    // The math is the same for each half, hence we have a small loop that will
    // execute twice, computing the digit/letter and pushing it onto the stack.
    mov     cl, 2
2:
    mov     dl, al
    and     dl, 0x0F

    cmp     dl, 0xA
    jb      3f

    // The byte is above or equal to 10, we need a letter.
    add     dl, 0x41 - 0xA
    push    dx
    jmp     4f

3:
    // The byte is < 10, we need a digit.
    add     dl, 0x30
    push    dx

4:
    shr     al, 4
    loop    2b

    // At this point the stack contains:
    //  SP + 2 -> digit/letter of lower 4 bits of AL.
    //  SP     -> digit/letter of higher 4 bits of AL.
    call    b_16_putc_vga_buffer
    add     sp, 2
    call    b_16_putc_vga_buffer
    add     sp, 2
    
    // Move to previous byte.
    dec     bx

// Loop condition, iterate over all bytes.
1:
    cmp     bx, WORD PTR [bp + ARG(1)]
    jae     0b

    pop     bx
    pop     bp
    ret

// Print a formatted string and values.
// @param format_string: A string that can contain substitution characters "%".
// @param values...: A variadic list of values for the substitutions.
// The following substitutions are available:
//  - %b: Print an hexadecimal byte.
//  - %w: Print an hexadecimal word (16 bits).
//  - %d: Print an hexadecimal dword (32 bits).
//  - %q: Print an hexadecimal qword (64 bits).
// For values that are bigger than 16 bits, the MSBs of the value should be
// pushed onto the stack first, followed by the LSBs.
b_16_printf:
    push    bp
    mov     bp, sp

    // Local var:
    //  BP - 2: Number of arguments from the variadic list used so far.
    push    0x0

    push    bx

    // BX = pointer on format string.
    mov     bx, [bp + ARG(0)]
    jmp     1f

0:
    // Loop on format string. AL = curr char.

    // 0x25 == '%'
    cmp     al, 0x25
    je      2f

    // Regular character, simply output it.
    push    ax
    call    b_16_putc_vga_buffer
    add     sp, 2
    jmp     3f

2:
    // % char. Peek next char to know the type.
    inc     bx
    mov     cl, [bx]
    test    cl, cl
    // If NUL char break out of the loop.
    jz      1f 

    xor     dx, dx

    // 'b' outputs a byte.
    mov     ax, 1
    cmp     cl, 0x62
    cmove   dx, ax

    // 'w' outputs a word.
    mov     ax, 2
    cmp     cl, 0x77
    cmove   dx, ax

    // 'd' outputs a dword.
    mov     ax, 4
    cmp     cl, 0x64
    cmove   dx, ax

    // 'q' outputs a qword.
    mov     ax, 8
    cmp     cl, 0x71
    cmove   dx, ax

    test    dx, dx
    // In case of invalid subst, ignore. TODO: Panic ?
    jz      3f
   
    // AX = address of the value.
    lea     ax, [bp + ARG(1)]
    mov     cx, [bp - 0x2]
    shl     cx, 1
    add     ax, cx

    // Push the arguments for the call to _b_16_printf_output_hex.
    push    ax
    push    dx

    // DX = ceil(DX / 2) = the number of arguments from the variadic list used
    // for this substitution.
    dec     dx
    shr     dx, 1
    inc     dx

    // Update the arg counter.
    add     WORD PTR [bp - 0x2], dx
    
    // Output the value.
    call    _b_16_printf_output_hex
    add     sp, 4

// Update loop iteration and go to next ite.
3:
    inc     bx
1:
    movzx   ax, BYTE PTR [bx]
    test    al, al
    jnz     0b

    pop     bx
    // Clean up local var(s).
    add     sp, 2
    pop     bp
    ret

// This routine will be jumped into as soon as the remaining sectors composing
// the bootstrap procedure as been loaded into RAM.
second_sector_entry:
    call    b_16_clear_vga_buffer

    movzx   dx, BYTE PTR [drive_number]
    push    dx
    push    OFFSET FLAT : [str_boot_message]
    call    b_16_printf
    add     sp, 4

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

// The one and only GDT.
gdt:
// Entry 0: NULL entry (required).
.quad 0x0
// Entry 1: Flat data segment, page granularity, read/write, non-conforming.
.quad GDT_ENTRY(0x0, 0xFFFFF, 2)
// Entry 2: Flat code segment, page granularity, read only, non-conforming.
.quad GDT_ENTRY(0x0, 0xFFFFF, 10)
gdt_end:

str_boot_message:
.asciz  "Bootstrap code successfully loaded from drive %b\n"

bootstrap_end:
