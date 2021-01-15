// This file contains various logging functions used by bootstrap code.

#include <asm_macros.h>
.intel_syntax   noprefix

// Width of the VGA text buffer in number of characters.
.set VGA_WIDTH, 80
// Height of the VGA text buffer in number of characters.
.set VGA_HEIGHT, 25
// Address of the VGA buffer.
.set VGA_BUFFER, 0xB8000

// ============================================================================= 
// Clear the VGA text buffer. This result in a black screen.
// ============================================================================= 
ASM_FUNC_DEF32(clear_vga_buffer):
    push    ebp
    mov     ebp, esp
    push    edi

    mov     edi, VGA_BUFFER
    mov     ecx, VGA_WIDTH * VGA_HEIGHT
    // Zero out the entire buffer.
    xor     ax, ax
    cld
    rep     stosw

    // On a clear the cursor is reset to 0 == top left corner.
    mov     WORD PTR [putc_vga_buffer_cursor], 0x0

    pop     edi
    leave
    ret

// ============================================================================= 
// Scroll the VGA text buffer up, and clear the bottom line.
// ============================================================================= 
ASM_FUNC_DEF32(scroll_vga_buffer):
    push    ebp
    mov     ebp, esp
    push    esi
    push    edi
    
    // Copy the content from line i+1 to line i for all lines except the bottom
    // one.
    mov     edi, VGA_BUFFER
    mov     esi, VGA_WIDTH * 2
    mov     ecx, VGA_WIDTH * VGA_HEIGHT - VGA_WIDTH
    cld
    rep     movsw

    // DI now points to the first char of the botton line. Zero it out.
    mov     ecx, VGA_WIDTH
    xor     ax, ax
    cld
    rep     stosw

    pop     edi
    pop     esi
    leave
    ret

// ============================================================================= 
// Print a char in the VGA text buffer at the current cursor position. This
// function will scroll the buffer if needed.
// @param (DWORD) char: The ASCII char to be printed. Only the bottom byte is
// used.
// ============================================================================= 
ASM_FUNC_DEF32(putc_vga_buffer):
    push    ebp
    mov     ebp, esp
    push    ebx

    // AL = char to write.
    mov     al, [ebp + 0x8] 

    // 0x0A == '\n'.
    cmp     al, 0x0A
    je      1f

    // Attribute = 0x7 == light grey char on black background.
    mov     ah, 0x7
    mov     ebx, [putc_vga_buffer_cursor]
    // Convert cursor index to offset in the buffer (that is * sizeof(u16)).
    shl     ebx, 1

    // Write char.
    mov     [ebx + VGA_BUFFER], ax
    shr     ebx, 1

    jmp     0f

1:
    // This is a new-line char. Advance the cursor to the start of the next
    // line.
    mov     ax, [putc_vga_buffer_cursor]
    mov     bx, VGA_WIDTH
    // AL = cursor / VGA_WIDTH, AH = cursor % VGA_WIDTH.
    div     bl
    
    sub     bl, ah
    add     bx, [putc_vga_buffer_cursor]
    // The cursor will be updated underneath. Fix up so the update puts the
    // cursor at the beginning of the line.
    dec     bx

0:
    // Advance cursor and check if it is now out of bounds. If it is then scroll
    // up the buffer.
    inc     bx
    mov     [putc_vga_buffer_cursor], bx
    cmp     bx, VGA_WIDTH * VGA_HEIGHT
    jb      0f
    
    // We reached the end of the VGA buffer, time to scroll up.
    call    scroll_vga_buffer
    // The cursor goes to the beginning of the last line.
    mov     WORD PTR [putc_vga_buffer_cursor], VGA_WIDTH * (VGA_HEIGHT - 1)
    
0:

    pop     ebx
    leave
    ret

// Cursor of the VGA text buffer. Indicate the index of the next char to be
// printed.
putc_vga_buffer_cursor:
.long   0x0

// ============================================================================= 
// Output an hexadecimal value into the VGA buffer at the current cursor
// position.
// @param (DWORD) size: The number of bytes of the value.
// @param (DWORD) addr: Address where the value is stored.
// ============================================================================= 
ASM_FUNC_DEF32(_printf_output_hex):
    push    ebp
    mov     ebp, esp

    push    ebx
    
    // Put '0'.
    push    0x30
    call    putc_vga_buffer
    add     esp, 4

    // Put 'x'.
    push    0x78
    call    putc_vga_buffer
    add     esp, 4

    // Since x86 is little-endian, the byte following the "0x" will be the byte
    // at ths address `addr + size - 1`. Hence we will iterates over the bytes
    // of the value in reverse, that is MSB first and finish with LSB.

    // EBX = address of the MSByte of the value.
    mov     ebx, [ebp + 0xC]
    add     ebx, [ebp + 0x8]
    dec     ebx

    jmp     1f
// Loop head, iterate over all bytes.
0:
    // AL = current byte.
    mov     al, [ebx]

    // In order to output the correct representation of the byte, we need to do
    // some ASCII math on each half/4bits composing the byte.
    // The goal here is to make two calls to putc_vga_buffer with the correct
    // digit or letter.
    // The math is the same for each half, hence we have a small loop that will
    // execute twice, computing the digit/letter and pushing it onto the stack.
    xor     edx, edx
    mov     cl, 2
2:
    mov     dl, al
    and     dl, 0x0F

    cmp     dl, 0xA
    jb      3f

    // The byte is above or equal to 10, we need a letter.
    add     dl, 0x41 - 0xA
    push    edx
    jmp     4f

3:
    // The byte is < 10, we need a digit.
    add     dl, 0x30
    push    edx

4:
    shr     al, 4
    loop    2b

    // At this point the stack contains:
    //  SP + 4 -> digit/letter of lower 4 bits of AL.
    //  SP     -> digit/letter of higher 4 bits of AL.
    call    putc_vga_buffer
    add     esp, 4
    call    putc_vga_buffer
    add     esp, 4
    
    // Move to previous byte.
    dec     ebx

// Loop condition, iterate over all bytes.
1:
    cmp     ebx, [ebp + 0xC]
    jae     0b

    pop     ebx
    leave
    ret

// ============================================================================= 
// Print a formatted string and values.
// @param (DWORD) format_string: Address of a string that can contain
// substitution characters "%".
// @param (MIX) values...: A variadic list of values for the substitutions.
// The following substitutions are available:
//  - %b: Print an hexadecimal byte.
//  - %w: Print an hexadecimal word (16 bits).
//  - %d: Print an hexadecimal dword (32 bits).
//  - %q: Print an hexadecimal qword (64 bits).
// For values that are bigger than 16 bits, the MSBs of the value should be
// pushed onto the stack first, followed by the LSBs.
// The size of each value is at least a DWORD (hence for %b and %w one should
// push an entire DWORD) or a QWORD for %q.
// ============================================================================= 
ASM_FUNC_DEF32(printf):
    push    ebp
    mov     ebp, esp

    // Local var:
    //  EBP - 4: Number of arguments from the variadic list used so far.
    push    0x0

    push    ebx

    // EBX = pointer on format string.
    mov     ebx, [ebp + 0x8]
    jmp     1f

0:
    // Loop on format string. AL = curr char.

    // 0x25 == '%'
    cmp     al, 0x25
    je      2f

    // Regular character, simply output it.
    push    eax
    call    putc_vga_buffer
    add     esp, 4
    jmp     3f

2:
    // % char. Peek next char to know the type.
    inc     ebx
    mov     cl, [ebx]
    test    cl, cl
    // If NUL char break out of the loop.
    jz      1f 

    xor     edx, edx

    // 'b' outputs a byte.
    mov     eax, 1
    cmp     cl, 0x62
    cmove   edx, eax

    // 'w' outputs a word.
    mov     eax, 2
    cmp     cl, 0x77
    cmove   edx, eax

    // 'd' outputs a dword.
    mov     eax, 4
    cmp     cl, 0x64
    cmove   edx, eax

    // 'q' outputs a qword.
    mov     eax, 8
    cmp     cl, 0x71
    cmove   edx, eax

    test    edx, edx
    // In case of invalid subst, panic.
    jnz      4f
    PANIC32("Invalid substitution character in printf")
4:
   
    // EAX = address of the value = Address of first arg + <num args used> * 4.
    lea     eax, [ebp + 0xC]
    mov     ecx, [ebp - 0x4]
    shl     ecx, 2
    add     eax, ecx

    // Push the arguments for the call to _printf_output_hex.
    push    eax
    push    edx

    // EDX = ceil(EDX / 8) = the number of arguments from the variadic list used
    // for this substitution. This is because for any value under 32-bit we
    // still push a DWORD onto the stack.
    dec     edx
    shr     edx, 3
    inc     edx

    // Update the arg counter.
    add     [ebp - 0x4], edx
    
    // Output the value.
    call    _printf_output_hex
    add     esp, 8

// Update loop iteration and go to next ite.
3:
    inc     ebx
1:
    mov     al, [ebx]
    test    al, al
    jnz     0b

    pop     ebx
    // Clean up local var(s).
    add     esp, 4
    leave
    ret
