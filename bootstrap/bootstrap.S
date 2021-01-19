// This is the "main" code of the bootstrap code. After the code in the first
// sector has loaded everything in RAM, it will jump to second_sector_entry to
// start the bootstrapping.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// ============================================================================= 
// Entry point of the bootstrap code on the second sector. This routine assumes
// that the entire bootstrap code has been loaded in RAM at address 0x7C00
// (first sector).
// This routine will enable 32-bit Protected Mode and jump to the main routine.
// ============================================================================= 
ASM_FUNC_DEF16(second_sector_entry):
    // Save the Real-Mode IDT in case we ever want to go back to real-mode.
    sidt    [real_mode_idtr]

    // Jump to main routine in 32-bit PM.
    lea     eax, [bootstrap_main]
    push    eax
    call    jump_to_32_bit_protected_mode

    // Unreachable.
    int3

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
    call    clear_vga_buffer32

    push    [drive_number]
    INFO32("Bootstrap coded loaded from drive %b\n")
    add     esp, 4

    INFO32("Bootstrap main started\n")

    INFO32("Running tests\n")
    call    run_tests

    call    init_mem_map
    call    init_frame_allocator
    call    init_long_mode

    lea     eax, [.long_mode_target]
    push    0x0
    push    eax
    call    jump_to_long_mode
    // Unreachable.
    int3
.code64
.long_mode_target:
    mov     r8, 0xdeadbeefbabecafe
    // This is where we would typically jump to the rust main function.
    PANIC64("Not implemented\n")
0:
    cli
    hlt
    jmp     0b

// ============================================================================= 
// Read a sector from the boot disk.
// @param dest: Where to read the sector to. This address must be under 64KiB.
// @param start_idx: The index of the first sector to be read.
// @param num_sectors: The number of sectors to read starting from the index
// above.
// ============================================================================= 
ASM_FUNC_DEF32(read_sector):
    push    ebp
    mov     ebp, esp
    push    edi

    // Allocate Disk Access Packet onto the stack and zero it.
    sub     esp, DAP_SIZE
    xor     eax, eax
    mov     edi, esp
    mov     ecx, DAP_SIZE
    cld
    rep     stosb

    // Fill in the Disk Access Packet.
    mov     BYTE PTR [esp + DAP_SIZE_OFF], DAP_SIZE
    mov     BYTE PTR [esp + DAP_RESV_OFF], 0x0
    mov     eax, [ebp + 0x8]
    mov     DWORD PTR [esp + DAP_DEST_OFF], eax
    mov     eax, [ebp + 0xC]
    mov     DWORD PTR [esp + DAP_START_BLOCK_OFF + 4], 0x0
    mov     DWORD PTR [esp + DAP_START_BLOCK_OFF], eax
    mov     eax, [ebp + 0x10]
    mov     WORD PTR [esp + DAP_NUM_BLOCKS_OFF], ax

    // Allocate BIOS Call packet onto the stack and zero it.
    sub     esp, BCP_SIZE
    xor     eax, eax
    mov     edi, esp
    mov     ecx, BCP_SIZE
    cld
    rep     stosb

    // Int 0x13 AH 0x42 read from disk.
    mov     BYTE PTR [esp + BCP_INT_OFF], 0x13
    mov     DWORD PTR [esp + BCP_EAX_OFF], 0x4200
    // DL = Drive number.
    mov     al, [drive_number]
    mov     BYTE PTR [esp + BCP_EDX_OFF], al
    // SI points to the Disk Access Packet.
    lea     eax, [esp + BCP_SIZE]
    mov     WORD PTR [esp + BCP_ESI_OFF], ax

    // Call the BIOS function.
    push    esp
    call    call_bios_func_32
    add     esp, 4

    // Make sure no error occured.
    mov     al, [esp + BCP_CF_OFF]
    test    al, al
    jz      0f
    hlt
    PANIC32("read_sector: Error while reading sector\n")
0:
    // Get rid of BCP.
    add     esp, BCP_SIZE

    // Make sure all sectors were read. This is stored in the NUM_BLOCKS.
    movzx   eax, WORD PTR [esp + DAP_NUM_BLOCKS_OFF]
    cmp     eax, [ebp + 0x10]
    je      0f
    PANIC32("read_sector: Could not read all requested sectors\n")
0:
    // Get rid of DAP.
    add     esp, DAP_SIZE

    pop     edi
    leave
    ret

// ============================================================================= 
// Rudimentary dynamic memory allocation. This is only meant for memory that
// will never be freed. The allocations are placed after the bootstrap code and
// data segment and under 0xFFFF so that they will always be accessible from
// real-mode code.
// @param (DWORD) size: The number of bytes to allocated.
// ============================================================================= 
ASM_FUNC_DEF32(allocate_low_mem):
    push    ebp
    mov     ebp, esp

    // EAX = Address of next allocation (this allocation).
    mov     eax, [alloc_addr]

    // ECX = New address of alloc_addr.
    mov     ecx, eax
    add     ecx, [ebp + 0x8]
    cmp     eax, 0xFFFF
    jb      0f

    // The address will not fit in a 16-bit registers.
    PANIC32("No space left\n")
0:

    // Allocation OK. Move the alloc_addr.
    mov     [alloc_addr], ecx
    // EAX is already pointing to the beginning of the allocated memory.
    leave
    ret

.section .data
// Pointer to the next address available for allocation.
alloc_addr:
.long   ALLOC_BEGIN

// ============================================================================= 
// Panic the bootstrap code, this will print a message indicating where the
// PANIC occured (EIP) and lock up the cpu.
// This function DOES NOT RETURN.
// @param (DWORD) message: Pointer on a string describing the error.
// ============================================================================= 
ASM_FUNC_DEF32(panic32):
    push    ebp
    mov     ebp, esp

    push    [ebp + 0x4]
    _PRINTF32("[PANIC] :", "IP = %d : ")
    add     esp, 4 

    // Print message
    push    [ebp + 0x8]
    call    printf32
    add     esp, 4

    // Lock up the cpu.
0:
    mov     eax, 0xDEADC0DE
    cli
    hlt
    jmp     0b

// ============================================================================= 
// 64-bit version of the panic32 routine.
// This function DOES NOT RETURN.
// @param (RDI) message: Pointer on a string describing the error.
// ============================================================================= 
ASM_FUNC_DEF64(panic64):
    push    rbp
    mov     rbp, rsp

    push    rdi

    push    [rbp + 0x8]
    _PRINTF64("[PANIC] :", "IP = %q : ")
    add     esp, 8 

    // Print message
    pop     rdi
    call    printf64
    // Lock up the cpu.
0:
    mov     rax, 0xDEADC0DEDEADC0DE
    cli
    hlt
    jmp     0b


// Data used by the bootstrap code:
.section    .data

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
// Flat 64-bit data segment, ring 0, read/write.
.quad GDT_ENTRY64(0x0, 0xFFFFF, 2)
// Flat 64-bit code segment, ring 0, read, non-conforming.
.quad GDT_ENTRY64(0x0, 0xFFFFF, 10)
gdt_end:

// Saved value of the ITDR when the BIOS just loaded the first sector. This is
// used when switching back to real-mode from protected mode.
real_mode_idtr:
.skip   6
