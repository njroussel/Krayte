// This file contains code related to video framebuffer initialization and
// configuration.
// The webpage https://wiki.osdev.org/Getting_VBE_Mode_Info is a great source of
// information on how to interact with the BIOS to get info about VESA video
// mode.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// The next few consts define the video mode that we want to use. The init_video
// routine will try to find this video mode. If it succeed then the video mode
// is set, otherwise it panics.
// Width in pixel.
.set PREFERRED_WIDTH, 1920
// Height in pixel.
.set PREFERRED_HEIGHT, 1080
// Number of bytes per pixel.
.set PREFERRED_BPP, 32
// The type of framebuffer. See http://www.ctyme.com/intr/rb-0274.htm
// 0x6 indicate direct color.
.set PREFERRED_MEM_MODEL, 6

// Data used in this file.
.section .data
// Pointer on a copy of the VBE info block. This points to allocated memory that
// contains the returned info from the BIOS when executing the "Get Controller
// Info" function (int 0x10 AX = 0x4F00).
vbe_info_block:
.quad   0x0
// Pointer on a copy of the video mode info block. This points to allocated
// memory as well. This is the information reported by the "Get Mode Info"
// function. This will contain info on the current video mode after the call to
// init_video.
.global mode_info_block
mode_info_block:
.quad   0x0

// The size of the VBE info block in bytes.
.set VBE_INFO_BLOCK_SIZE, 512
// Some offsets of fields in the VBE info block. Note: In the definition below,
// a "real mode far pointer" is defined as a 32-bit dword of the form <real mode
// segment>:<offset>.
// (DWORD) real mode far pointer to the OEM string.
.set VBE_INFO_BLOCK_OEM_OFF, 0x6
// (DWORD) real mode far pointer to the array of available video modes.
.set VBE_INFO_BLOCK_MODE_PTR_OFF, 0xE

// ============================================================================= 
// Read the VBE info block from the BIOS and store it in accessible RAM
// (dynamically allocated).
// @return (EAX): Pointer to the copy of the VBE info block.
// Note: This routine will also set the `vbe_info_block` pointer.
// ============================================================================= 
ASM_FUNC_DEF32(_read_vbe_info_block):
    push    ebp
    mov     ebp, esp

    // Allocate enough space to contain the VBE info block.
    push    VBE_INFO_BLOCK_SIZE
    call    allocate_low_mem
    mov     [vbe_info_block], eax 

    // Call the "Get Controller Info" BIOS function. Int 0x10/AX = 0x4F00.
    sub     esp, BCP_SIZE
    mov     BYTE PTR [esp + BCP_INT_OFF], 0x10
    mov     DWORD PTR [esp + BCP_EAX_OFF], 0x4F00
    // EDI points to the destination where to write the information.
    mov     DWORD PTR [esp + BCP_EDI_OFF], eax
    push    esp
    call    call_bios_func_32
    add     esp, 4

    // VBE functions will return 0x004F in AX on success.
    cmp     WORD PTR [esp + BCP_EAX_OFF], 0x004F
    je      0f
    PANIC32("_read_vbe_info_block: Error when getting controller info\n")
0:
    add     esp, BCP_SIZE

    // Check the signature of the block. It should be "VESA".
    mov     eax, [vbe_info_block]
    cmp     DWORD PTR [eax], 0x41534556
    je      0f
    PANIC32("_read_vbe_info_block: Invalid signature\n")
0:

    // Print OEM string in logs.
    INFO32("Found VBE info OEM = ")
    // ECX = Addr of string.
    mov     eax, [vbe_info_block]
    movzx   ecx, WORD PTR [eax + VBE_INFO_BLOCK_OEM_OFF + 2]
    shl     ecx, 4
    movzx   edx, WORD PTR [eax + VBE_INFO_BLOCK_OEM_OFF]
    add     ecx, edx
    push    ecx
    call    printf32
    push    '\n'
    call    putc_vga_buffer32
    add     esp, 8

    // Return the address of the copy.
    mov     eax, [vbe_info_block]
    leave
    ret

// The size of the mode info block in bytes.
.set MODE_INFO_BLOCK_SIZE, 256
// Some offsets of the mode info block's fields used during init:
// (WORD) Width in pixels.
.set MODE_INFO_BLOCK_WIDTH_OFF, 0x12
// (WORD) Height in pixels.
.set MODE_INFO_BLOCK_HEIGHT_OFF, 0x14
// (WORD) Mode's attributes.
.set MODE_INFO_BLOCK_ATTR_OFF, 0x0
// (BYTE) Memory model type. See http://www.ctyme.com/intr/rb-0274.htm#Table82.
.set MODE_INFO_BLOCK_MEM_MODEL, 0x1B
// (DWORD) Physical address of the mode's framebuffer. If applicable.
.set MODE_INFO_BLOCK_FB_ADDR_OFF, 0x28
// (BYTE) Number of bits per pixels.
.set MODE_INFO_BLOCK_BPP, 0x19
// (WORD) Number of bytes per line. This is used to compute the offset of the
// start of a line as follows: offset = line_num * bytes_per_line.
.set MODE_INFO_BLOCK_BYTE_PER_LINE, 0x10

// ============================================================================= 
// Initialize the video mode. This routine will use the BIOS' VESA functions to
// find the mode corresponding to the requested resolution (PREFERRED_*) and set
// it. If no such mode is found it will panic.
// WARN: After calling this function, the VGA text buffer will not be available
// anymore.
// ============================================================================= 
ASM_FUNC_DEF32(init_video):
    push    ebp
    mov     ebp, esp

    push    ebx
    push    edi

    // EAX = Pointer on VBE info block.
    call    _read_vbe_info_block

    // EBX = Pointer on mode array. The pointer is a <real mode segment>:offset
    // pair.
    movzx   ebx, WORD PTR [eax + VBE_INFO_BLOCK_MODE_PTR_OFF + 2]
    shl     ebx, 4
    movzx   edx, WORD PTR [eax + VBE_INFO_BLOCK_MODE_PTR_OFF]
    add     ebx, edx

    // Allocate space for the mode info block.
    push    MODE_INFO_BLOCK_SIZE
    call    allocate_low_mem
    add     esp, 4
    mov     [mode_info_block], eax
    // EDI = mode info block addr.
    mov     edi, eax
    
    jmp     video_loop_cond
    // Loop over all modes in the mode ptr and find a graphical mode with linear
    // framebuffer that corresponds to our preferred resolution.
video_loop:
    // Call the "Get Mode Info" BIOS function. Int 0x10/AX = 0x4F01.
    sub     esp, BCP_SIZE
    mov     BYTE PTR [esp + BCP_INT_OFF], 0x10
    mov     DWORD PTR [esp + BCP_EAX_OFF], 0x4F01
    mov     ax, [ebx]
    mov     WORD PTR [esp + BCP_ECX_OFF], ax
    mov     DWORD PTR [esp + BCP_EDI_OFF], edi
    push    esp
    call    call_bios_func_32
    add     esp, 4
    cmp     WORD PTR [esp + BCP_EAX_OFF], 0x004F
    je      0f
    PANIC32("init_video: Couldn't read mode info\n")
0:
    add     esp, BCP_SIZE

    // Check if this is a graphic mode with a linear frame buffer. This is done
    // by checking the OR 0x90 (bit 7 indicate support for framebuffer and bit 4
    // graphic mode).
    mov     ax, [edi + MODE_INFO_BLOCK_ATTR_OFF] 
    and     ax, 0x90
    cmp     ax, 0x90
    jne     video_loop_next

    // Check memory model.
    mov     al, [edi + MODE_INFO_BLOCK_MEM_MODEL]
    cmp     al, PREFERRED_MEM_MODEL
    jne     video_loop_next

    // Check bits per pixel.
    mov     al, [edi + MODE_INFO_BLOCK_BPP]
    cmp     al, PREFERRED_BPP
    jne     video_loop_next

    // Compare with preferred resolution.
    cmp     WORD PTR [edi + MODE_INFO_BLOCK_WIDTH_OFF], PREFERRED_WIDTH
    jne     video_loop_next
    cmp     WORD PTR [edi + MODE_INFO_BLOCK_HEIGHT_OFF], PREFERRED_HEIGHT
    jne     video_loop_next

    // This is the mode we want.
    jmp     video_loop_found

video_loop_next:
    add     ebx, 2
video_loop_cond:
    cmp     DWORD PTR [ebx], 0xFFFF
    jne     video_loop

    // We reached the end of the list and we haven't found the requested mode.
    // Give up.
    PANIC32("init_video: Could not find requested video mode\n")

video_loop_found:
    // Requested video mode is available and it stored under mode_info_block
    // (pointed by EDI).
    push    [ebx]
    push    PREFERRED_HEIGHT
    push    PREFERRED_WIDTH
    INFO32("Video mode %w x %w found: %w\n")
    add     esp, 0xC

    // Set the video mode.
    push    [ebx]
    call    _set_video_mode
    add     esp, 4

    pop     edi
    pop     ebx

    leave
    ret

// ============================================================================= 
// Set the current video mode.
// @param (DWORD) mode number as reported in the VBE info block.
// ============================================================================= 
ASM_FUNC_DEF32(_set_video_mode):
    push    ebp
    mov     ebp, esp

    // Call the Set Video Mode BIOS function int 0x10, ax = 0x4f02.
    sub     esp, BCP_SIZE
    mov     BYTE PTR [esp + BCP_INT_OFF], 0x10
    mov     DWORD PTR [esp + BCP_EAX_OFF], 0x4F02
    // BX should hold the mode number. Additionally we should OR it by 0x4000 to
    // indicate that we want to use the linear framebuffer. See
    // https://wiki.osdev.org/Getting_VBE_Mode_Info.
    mov     ax, [ebx]
    or      ax, 0x4000
    mov     WORD PTR [esp + BCP_EBX_OFF], ax
    push    esp
    call    call_bios_func_32
    add     esp, 4

    cmp     WORD PTR [esp + BCP_EAX_OFF], 0x004F
    je      0f
    PANIC32("init_video: Couldn't set video mode\n")
0:
    add     esp, BCP_SIZE
    leave
    ret
