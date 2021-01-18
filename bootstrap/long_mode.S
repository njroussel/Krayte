// This file contains code related to initializing and jumping to long mode.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

.section .data
// The address of the PML4 to be used in CR3.
PML4_ADDR:
.long   0x0

// Number of the IA32_EFER MSR.
.set IA32_EFER, 0xC0000080
// Index of the Long Mode Enable bit in IA32_EFER.
.set LME_SHIFT, 8
// Index of the Long Mode Active bit in IA32_EFER.
.set LMA_SHIFT, 10
// Index of the Paging big in CR0.
.set PG_SHIFT, 31
// Index of the Physical Address Extension bit in CR4.
.set PAE_SHIFT, 5
// Index of the Present bit in the PML4, PDP, Page Dir and Page Table entries.
.set PRESENT_SHIFT,    0
// Index of the Write bit in the PML4, PDP, Page Dir and Page Table entries.
.set WRITE_SHIFT,      1
// Index of the Address in the PML4, PDP, Page Dir and Page Table entries.
.set PDP_SHIFT,        12

// =============================================================================
// Initialize Long Mode. This will prepare the paging structures only, not
// jumping to long mode.
// After calling this function it is possible to call jump_to_long_mode to jump
// into 64-bit mode.
// =============================================================================
ASM_FUNC_DEF32(init_long_mode):
    push    ebp
    mov     ebp, esp

    // ID map the first 1MiB of RAM. We need:
    //  - 1 PML4 table      (EBP - 0x04)
    //  - 1 PDP table       (EBP - 0x08)
    //  - 1 Page Directory  (EBP - 0x0C)
    //  - 1 Page Table.     (EBP - 0x10)
    // Since we are mapping the first 1MiB we simply need to initialize the
    // first entry in the PML4, PDP, and Page Dir. For the page table we will
    // initialize the first 256 entries (256 * PAGE_SIZE == 1MiB).

    mov     ecx, 4
    // Allocate the tables.
0:
    push    ecx

    call    allocate_frame32
    // EDX = Address of frame.
    mov     edx, eax

    // Zero out the new frame.
    mov     edi, eax
    xor     eax, eax
    mov     ecx, PAGE_SIZE / 4
    cld
    rep     stosd

    pop     ecx
    
    // Push the frame address into the local vars.
    push    edx
    loop    0b

    // Store the address of the PML4.
    mov     eax, [ebp - 0x4]
    mov     [PML4_ADDR], eax

    // Note: For all tables from any level, the present and write bits are at
    // the same shift offset. These are the only bits (other than the address of
    // the next-level table or page) that are required. Hence compute the mask
    // once and re-use.
    mov     edx, ((1 << PRESENT_SHIFT) | (1 << WRITE_SHIFT))

    // Note 2: Because all tables are under the 4GiB limit their address will
    // fit in 20 bits and therefore we simply need to or the lower 32-bits of
    // each entry to set the addresses.
    // Callee-saved.
    push    ebx

    // Iterate over the tables allocated above and set the present bit, write
    // bit and address to the next level for the first entry.
    // EAX = Pointer on local vars, starting on address of PML4.
    lea     eax, [ebp - 0x04]
    // Fill up the first 3 tables. The page table is handled differently.
    mov     ecx, 3
0:
    push    ecx

    // ECX = Address of table = Address of first entry.
    mov     ecx, [eax]
    // Advance local var pointer.
    sub     eax, 0x4

    // Set present and write bits.
    or      [ecx], edx
    // Set address of next table.
    mov     ebx, [eax]
    or      [ecx], ebx

    // Loop on next table.
    pop     ecx
    loop    0b

    pop     ebx

    // Now populate the Page Table. Since we want to ID map the first 1MiB, we
    // need to initialize entries 0 through 255 included. Once again we simply
    // need the present and write bits as well as the address of the page it
    // maps to.
    // ECX = Iteration counter.
    mov     ecx, 256
    // EAX = bit mask for present and writable.
    mov     eax, ((1 << PRESENT_SHIFT) | (1 << WRITE_SHIFT))
    // EDI = Pointer on first entry of the page table.
    push    edi
    mov     edi, [ebp - 0x10] 
    cld
0:
    // Store EAX in the first 32-bit of the current entry.
    stosd
    // The top 32-bits of the entry should be zero. This is because the
    // addresses of the physical frames are < 4GiB and we are not using the
    // NoExec bit.
    mov     DWORD PTR [edi], 0x0
    // Advance EDI to next entry.
    add     edi, 4

    // Update EAX to contain the value of the next entry.
    add     eax, 0x1000
    loop    0b

    pop     edi
    // Get rid of temp vars.
    add     esp, 0x10
    leave
    ret

// =============================================================================
// Jump to 64-bit mode. This routine assumes that init_long_mode has been called
// in the past. This routine DOES NOT RETURN.
// @param (QWORD) target: Target of the jump to 64-bit.
// =============================================================================
ASM_FUNC_DEF32(jump_to_long_mode):
    // Intel's Manual Volume 3 chapter 9.8.5 explains the steps to follow to
    // enable IA-32e mode.

    // Step 1: Disable paging. Paging was never enabled in the first place
    // but we still do this for completness.
    mov     eax, cr0
    and     eax, ~(1 << PG_SHIFT) 
    mov     cr0, eax

    // Step 2: Enable physical address extensions (PAE).
    mov     eax, cr4
    or      eax, (1 << PAE_SHIFT)
    mov     cr4, eax

    // Step 3: Load CR3 with level 4 Page Map table (PML4).
    mov     eax, [PML4_ADDR]
    mov     cr3, eax

    // Step 4: Enable long mode by setting IA32_EFER.LME = 1.
    mov     ecx, IA32_EFER
    rdmsr
    or      eax, (1 << LME_SHIFT)
    wrmsr

    // Step 5: Enable paging.
    mov     eax, cr0
    or      eax, (1 << PG_SHIFT)
    mov     cr0, eax

    // Check the IA32_EFER.LMA bit to verify that long mode has successfully
    // been enabled.
    mov     ecx, IA32_EFER
    rdmsr
    test    eax, (1 << LMA_SHIFT)
    jnz     0f
    // Failure to enabled long mode.
    PANIC32("Failed to enable long mode.\n")
0:

    // We are now in long mode, compatibility mode. Jump to 64-bit mode.
    // 0x30 is the 64-bit code segment selector in the GDT.
    jmp     0x30:0f

.code64
0:
    // Set the rest of the segment registers to use 64-bit segments.
    mov     ax, 0x28
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax

    // Get the target address from the stack.
    mov     rax, [esp + 0x4]
    // Jump to target.
    jmp     rax
