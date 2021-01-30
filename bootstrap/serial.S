// This file contains routines related to outputing to the serial console.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// The port number of COM0. This should be somewhat reliable. As long as it
// works under Qemu it is enough.
.set COM_PORT, 0x3F8
// The maximum baud rate.
.set MAX_BAUD_RATE, 115200
// The requested baud rate.
.set BAUD_RATE, 38400
// The divisor to be used for the rate.
.set BAUD_DIV, MAX_BAUD_RATE / BAUD_RATE

// The following are the offset of the "registers".
// Data registers. This is when DLAB is 0.
.set SERIAL_REG_DATA, 0x0
// When DLAB is 1 this becomes the register holding the lower 8 bits of the
// divisor.
.set SERIAL_REG_BAUD_LSB, 0x0
// When DLAB = 1 this is the register holding the upper byte of the divisor.
.set SERIAL_REG_BAUD_MSB, 0x1
// Line control register.
.set SERIAL_REG_LINE_CTRL, 0x3
// Line status register.
.set SERIAL_REG_LINE_STAT, 0x5

// ============================================================================= 
// Initialize COM0 for serial output.
// ============================================================================= 
ASM_FUNC_DEF32(init_serial):
    push    ebp
    mov     ebp, esp

    // First set the baud rate divisor.
    // Set DLAB bit.
    mov     dx, COM_PORT + SERIAL_REG_LINE_CTRL
    in      al, dx
    or      al, (1 << 7)
    out     dx, al

    // Set divisor.
    mov     dx, COM_PORT + SERIAL_REG_BAUD_LSB
    mov     al, BAUD_DIV & 0xFF
    out     dx, al
    mov     al, BAUD_DIV >> 8
    mov     dx, COM_PORT + SERIAL_REG_BAUD_MSB
    out     dx, al

    // Unset DLAB bit.
    mov     dx, COM_PORT + SERIAL_REG_LINE_CTRL
    in      al, dx
    and     al, ~(1 << 7)
    out     dx, al

    // Set 8bits per characters, 1 stop bit and no parity.
    //  - Char width is in the 2 LSbits of the line control register. Should
    //  both be 1.
    //  - Stop bit is bit 2, should be 0.
    //  - Parity is disabled by setting the bit 3 to 0.
    mov     dx, COM_PORT + SERIAL_REG_LINE_CTRL
    in      al, dx
    or      al, 3
    and     al, ~((1 << 2) | (1 << 3))
    out     dx, al
    
    leave
    ret

// ============================================================================= 
// Output a character through COM0, 32-bit mode version.
// @param (DWORD) The character to be printed.
// ============================================================================= 
ASM_FUNC_DEF32(putc_serial32):
    push    ebp
    mov     ebp, esp

    // Wait for the transmission buffer to be empty. This is indicated by the
    // bit 6 of the line status register.
    mov     dx, COM_PORT + SERIAL_REG_LINE_STAT
0:
    in      al, dx
    test    al, (1 << 6)
    jz      0b

    // Transmission buffer free. Send the char. 
    mov     dx, COM_PORT + SERIAL_REG_DATA
    mov     al, [ebp + 0x8]
    out     dx, al

    cmp     BYTE PTR [ebp + 0x8], '\n'
    jne     0f
    // New lines in serial output should be followed by a carriage return. Do
    // this here, hidden from the caller.
    push    '\r'
    call    putc_serial32
    add     esp, 4
0:

    leave
    ret

// ============================================================================= 
// Output a character through COM0, 64-bit mode version.
// @param (DWORD) The character to be printed.
// ============================================================================= 
ASM_FUNC_DEF64(putc_serial64):
    push    rbp
    mov     rbp, rsp

    // Wait for the transmission buffer to be empty. This is indicated by the
    // bit 6 of the line status register.
    mov     dx, COM_PORT + SERIAL_REG_LINE_STAT
0:
    in      al, dx
    test    al, (1 << 6)
    jz      0b

    // Transmission buffer free. Send the char. 
    mov     dx, COM_PORT + SERIAL_REG_DATA
    mov     al, dil
    out     dx, al

    cmp     dil, '\n'
    jne     0f
    // New lines in serial output should be followed by a carriage return. Do
    // this here, hidden from the caller.
    mov     dil, '\r'
    call    putc_serial64
0:

    leave
    ret
