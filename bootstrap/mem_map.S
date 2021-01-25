// This file contains routines related to the physical memory map given by the
// BIOS.
// Accessing BIOS' memory maps involve calling BIOS functions (and hence
// switching to real-mode). This file defines the init_mem_map routine which
// will read the entire memory map from the BIOS and put it in RAM.
// The memory map contains one or more entries of the form:
//      (QWORD) Base address
//      (QWORD) Length in bytes
//      (DWORD) Type
// Each entry corresponds to the memory region [<base addr>; <base addr>+<len>[
// and the type field indicates if this region is available for the OS or
// reserved.

.intel_syntax   noprefix

#include <asm_macros.h>
#include <consts.h>

.section .data
// The start address of the memory map array containing all entries.
.global MEM_MAP_START
MEM_MAP_START:
.long   0x0
// The number of entries in the memory map array.
.global MEM_MAP_NUM_ENTRIES
MEM_MAP_NUM_ENTRIES:
.long   0x0

// ============================================================================= 
// Read an entry of the memory map given by the BIOS.
// @param (DWORD) dest: Pointer where to write the entry into. This must be
// UNDER 1MiB.
// @param (DWORD) entry_index: The index of the entry to get.
// @return (EAX): Index of the next entry. 0 if this was the last entry.
// ============================================================================= 
ASM_FUNC_DEF32(_get_bios_mem_map_entry):
    push    ebp
    mov     ebp, esp

    // Allocate a BCP onto the stack.
    sub     esp, BCP_SIZE
    // EAX = Pointer on BCP.
    mov     eax, esp

    // ECX = dest
    mov     ecx, [ebp + 0x8]
    // EDX = index of entry
    mov     edx, [ebp + 0xC]

    // Set up values in BCP.
    mov     BYTE PTR [eax + BCP_INT_OFF], 0x15
    mov     BYTE PTR [eax + BCP_CF_OFF], 0x0
    mov     DWORD PTR [eax + BCP_EAX_OFF], 0x0000E820
    mov     DWORD PTR [eax + BCP_EDX_OFF], 0x534D4150
    mov     DWORD PTR [eax + BCP_EBX_OFF], edx
    mov     DWORD PTR [eax + BCP_ECX_OFF], MME_SIZE
    mov     DWORD PTR [eax + BCP_EDI_OFF], ecx
   
    // Call the BIOS function "GET SYSTEM MEMORY MAP" (int 0x15 AX 0xE820).
    push    eax
    call    call_bios_func_32
    add     esp, 4

    mov     al, [esp + BCP_CF_OFF]
    test    al, al
    jz      0f

    PANIC32("Memory map BIOS call failed\n")

0:
    // EAX = Index of next entry = EBX in the BCP.
    mov     eax, [esp + BCP_EBX_OFF]

    // Dealloc the BCP.
    add     esp, BCP_SIZE
    leave
    ret

// ============================================================================= 
// Copy the BIOS memory map into RAM and set the MEM_MAP_START and
// MEM_MAP_NUM_ENTRIES variables.
// ============================================================================= 
ASM_FUNC_DEF32(init_mem_map):
    push    ebp
    mov     ebp, esp
    push    ebx
    push    edi

    // Read each entry from the BIOS one by one and allocate them.
    // Note: Instead of counting the number of entries and then allocating
    // enough contiguous space for all of them, we simply allocate as we go.
    // This is OK because at this point there is no possibility of race
    // conditions (no interrupts and other cpus are not awake).

    // EBX = Index of next entry.
    xor     ebx, ebx
loop:
    // EDI = Destination for memory map entry.
    push    MME_SIZE
    call    allocate_low_mem
    add     esp, 4
    mov     edi, eax

    test    ebx, ebx
    jnz     0f
    // This is the first entry. Save the address.
    mov     [MEM_MAP_START], edi
    push    edi
    INFO32("Memory map starting @ %d:\n")
    add     esp, 4
0:

    // Fill memory map.
    push    ebx
    push    edi
    call    _get_bios_mem_map_entry
    add     esp, 8

    // Save next index.
    mov     ebx, eax

    inc     DWORD PTR [MEM_MAP_NUM_ENTRIES]

    push    DWORD PTR [edi + MME_TYPE_OFF]
    push    DWORD PTR [edi + MME_LENGTH_OFF + 4]
    push    DWORD PTR [edi + MME_LENGTH_OFF]
    push    DWORD PTR [edi + MME_BASE_OFF + 4]
    push    DWORD PTR [edi + MME_BASE_OFF]
    INFO32("Base = %q Len = %q Type = %d\n")
    add     esp, 20

    // Loop until the BIOS reports next index of 0 indicating the end of the
    // map.
    test    ebx, ebx
    jnz     loop

    push    [MEM_MAP_NUM_ENTRIES]
    INFO32("%d entries in memory map\n")
    add     esp, 4

    pop     edi
    pop     ebx
    leave
    ret
