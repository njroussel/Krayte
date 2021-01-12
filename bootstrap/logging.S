// This file contains various logging functions used by bootstrap code. For now
// those functions are available for 16-bit mode only.

#include <asm_macros.h>
.intel_syntax   noprefix

// Width of the VGA text buffer in number of characters.
.set VGA_WIDTH, 80
// Height of the VGA text buffer in number of characters.
.set VGA_HEIGHT, 25
// Segment to use to write into the VGA text buffer.
.set VGA_SEGMENT, 0xB800

// Clear the VGA text buffer. This result in a black screen.
ASM_FUNC_DEF16(b_16_clear_vga_buffer):
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
ASM_FUNC_DEF16(b_16_scroll_vga_buffer):
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
ASM_FUNC_DEF16(b_16_putc_vga_buffer):
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
    dec     bx

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
    xor     ax, ax
    mov     es, ax

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
ASM_FUNC_DEF16(_b_16_printf_output_hex):
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
ASM_FUNC_DEF16(b_16_printf):
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
