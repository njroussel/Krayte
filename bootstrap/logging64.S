// This file contains various logging functions used by bootstrap code in 64-bit
// mode.

#include <asm_macros.h>
.intel_syntax   noprefix

// Width of the VGA text buffer in number of characters.
.set VGA_WIDTH, 80
// Height of the VGA text buffer in number of characters.
.set VGA_HEIGHT, 25
// Address of the VGA buffer.
.set VGA_BUFFER, 0xB8000

// ============================================================================= 
// Scroll the VGA text buffer up, and clear the bottom line.
// ============================================================================= 
ASM_FUNC_DEF64(scroll_vga_buffer64):
    push    rbp
    mov     rbp, rsp
    
    // Copy the content from line i+1 to line i for all lines except the bottom
    // one.
    mov     rdi, VGA_BUFFER
    mov     rsi, VGA_BUFFER + VGA_WIDTH * 2
    mov     rcx, VGA_WIDTH * VGA_HEIGHT - VGA_WIDTH
    cld
    rep     movsw

    // DI now points to the first char of the botton line. Zero it out.
    mov     rcx, VGA_WIDTH
    xor     ax, ax
    cld
    rep     stosw

    leave
    ret

// ============================================================================= 
// Print a char in the VGA text buffer at the current cursor position. This
// function will scroll the buffer if needed.
// @param (RDI) char: The ASCII char to be printed. Only the bottom byte is
// used.
// ============================================================================= 
ASM_FUNC_DEF64(putc_vga_buffer64):
    push    rbp
    mov     rbp, rsp
    push    rbx

    // AL = char to write.
    mov     rax, rdi

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
    call    scroll_vga_buffer64
    // The cursor goes to the beginning of the last line.
    mov     WORD PTR [putc_vga_buffer_cursor], VGA_WIDTH * (VGA_HEIGHT - 1)
    
0:

    pop     rbx
    leave
    ret

// ============================================================================= 
// Output an hexadecimal value into the VGA buffer at the current cursor
// position.
// @param (RDI) size: The number of bytes of the value.
// @param (RSI) value: The value.
// ============================================================================= 
ASM_FUNC_DEF64(_printf_output_hex64):
    push    rbp
    mov     rbp, rsp

    push    rbx
    
    push    rdi
    push    rsi
    // Put '0'.
    mov     rdi, 0x30
    call    putc_vga_buffer64

    // Put 'x'.
    mov     rdi, 0x78
    call    putc_vga_buffer64
    pop     rsi
    pop     rdi

    // RBX = Value.
    mov     rbx, rsi
    // Rotate the value to the right so that the LSBytes is the first byte to
    // print (i.e. the MSB of the original value). Everytime we print a byte we
    // rotate the value to the left so that the LSByte is the next one to be
    // printed.
    // The initial rotation needs to be of (size - 1) * 8.
    mov     rcx, rdi
    dec     rcx
    shl     rcx, 3
    ror     rbx, cl     

    // RCX = Num of bytes left to print.
    shr     rcx, 3
    inc     rcx
.loop:
    // Save the RCX. It will be used for the inner loop.
    push    rcx

    // In order to output the correct representation of the byte, we need to do
    // some ASCII math on each half/4bits composing the byte.
    // The goal here is to make two calls to putc_vga_buffer64 with the correct
    // digit or letter.
    // The math is the same for each half, hence we have a small loop that will
    // execute twice, computing the digit/letter and pushing it onto the stack.
    xor     rdx, rdx
    mov     rcx, 2
.inner_loop:
    mov     dl, bl
    and     dl, 0x0F

    cmp     dl, 0xA
    jb      .digit

    // The byte is above or equal to 10, we need a letter.
    add     dl, 0x41 - 0xA
    push    rdx
    jmp     .letter

.digit:
    // The byte is < 10, we need a digit.
    add     dl, 0x30
    push    rdx

.letter:
    shr     bl, 4
    loop    .inner_loop

    // At this point the stack contains:
    //  RSP + 8 -> digit/letter of lower 4 bits of AL.
    //  RSP     -> digit/letter of higher 4 bits of AL.
    pop     rdi
    call    putc_vga_buffer64
    pop     rdi
    call    putc_vga_buffer64
    
    // Move to previous byte.
    rol     rbx, 8

    // End of iteration.
    pop     rcx
    loop    .loop

    pop     rbx
    leave
    ret

// ============================================================================= 
// Print a formatted string and values.
// @param (RDI) format_string: Address of a string that can contain
// substitution characters "%".
// @param (MIX) values...: A variadic list of values for the substitutions.
// The following substitutions are available:
//  - %b: Print an hexadecimal byte.
//  - %w: Print an hexadecimal word (16 bits).
//  - %d: Print an hexadecimal dword (32 bits).
//  - %q: Print an hexadecimal qword (64 bits).
// The list is passed onto the STACK. Each element is a QWORD.
// ============================================================================= 
ASM_FUNC_DEF64(printf64):
    push    rbp
    mov     rbp, rsp

    // Local var:
    //  EBP - 8: Number of arguments from the variadic list used so far.
    push    0x0

    push    rbx

    // RBX = pointer on format string.
    mov     rbx, rdi
    jmp     .printf64_loop_cond

.printf64_loop:
    // Loop on format string. AL = curr char.
    // 0x25 == '%'
    cmp     al, 0x25
    je      .printf64_loop_subst

    // Regular character, simply output it.
    xor     rdi, rdi
    mov     dil, al
    call    putc_vga_buffer64
    jmp     .printf64_loop_continue

.printf64_loop_subst:
    // % char. Peek next char to know the type.
    inc     rbx
    mov     cl, [rbx]
    test    cl, cl
    // If NUL char break out of the loop.
    jz      .printf64_loop_cond 

    // RDI = Size in bytes of the value.
    xor     rdi, rdi

    // 'b' outputs a byte.
    mov     rax, 1
    cmp     cl, 0x62
    cmove   rdi, rax

    // 'w' outputs a word.
    mov     rax, 2
    cmp     cl, 0x77
    cmove   rdi, rax

    // 'd' outputs a dword.
    mov     rax, 4
    cmp     cl, 0x64
    cmove   rdi, rax

    // 'q' outputs a qword.
    mov     rax, 8
    cmp     cl, 0x71
    cmove   rdi, rax

    test    rdi, rdi
    // In case of invalid subst, panic.
    jnz      0f
    //PANIC64("Invalid substitution character in printf")
0:
   
    // RSI = address of the value = Address of first arg + <num args used> * 8.
    lea     rsi, [rbp + 0x10]
    mov     rcx, [rbp - 0x8]
    shl     rcx, 3
    add     rsi, rcx
    // RSI = value
    mov     rsi, [rsi]
    
    // Output the value. RDI and RSI already have the correct values.
    call    _printf_output_hex64

    // Update the arg counter.
    inc     QWORD PTR [rbp - 0x8]

// Update loop iteration and go to next ite.
.printf64_loop_continue:
    inc     rbx

.printf64_loop_cond:
    mov     al, [rbx]
    test    al, al
    jnz     .printf64_loop

    pop     rbx
    // Clean up local var(s).
    add     rsp, 8
    leave
    ret
