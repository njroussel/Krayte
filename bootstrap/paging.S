// This file contains routine to interact with paging data structure such as
// mapping physical frames to virtual memory.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// Index of the Present bit in the PML4, PDP, Page Dir and Page Table entries.
.set PRESENT_SHIFT,    0

// The set of flags used for "intermediate" entries, that is entries from the
// PML4, PDP, PG. The idea is to give as many permission has possible all the
// way to the Page Table. The entries of the page table will have the final
// permission/restriction.
.set INTERMEDIATE_FLAGS, MAP_WRITE | MAP_USER

// =============================================================================
// Check if RCX contains a valid OR of MAP_* flags, that is no bits other than
// the ones set by MAP_* are set in RCX. This routine will NOT CLOBBER ANY
// REGISTER except RAX of course.
// @param (RCX): The value to check.
// @return (RAX): 1 if the value is valid, 0 otherwise.
// =============================================================================
ASM_FUNC_DEF64(_check_map_flags_rcx):
    push    rbp
    mov     rbp, rsp
    push    rcx

    // If the AND RCX with the ~(OR all MAP_* flags) is 0 then the RCX is valid,
    // because no bits other than the ones coming from MAP_* are set. Otherwise
    // RCX is invalid.
    mov     rax, (MAP_WRITE | MAP_USER | MAP_WRITE_THROUGH | MAP_NO_EXEC)
    or      rax, (MAP_CACHE_DISABLE | MAP_GLOBAL)
    not     rax
    and     rcx, rax
    setz    al
    movzx   rax, al

    pop     rcx
    leave
    ret

// =============================================================================
// Set an entry in a table. The table can be any of PML4, PDP, PG or PT.
// @param (RDI) Virtual (recursive) address of the table to modify. Must be page
// aligned.
// @param (RSI) Index to modify. Must be page aligned.
// @param (RDX) Address to insert. Must be page aligned.
// @param (RCX) Flags of mapping.
// =============================================================================
ASM_FUNC_DEF64(_set_table_entry):
    push    rbp
    mov     rbp, rsp
    
    // Check that the addresses are page aligned.
    test    rdi, (PAGE_SIZE - 1)
    jnz     .not_aligned
    test    rdx, (PAGE_SIZE - 1)
    jnz     .not_aligned

    // Addresses are aligned.
    jmp     .aligned
.not_aligned:
    PANIC64("_set_table_entry: Address not aligned\n")
.aligned:

    // Check that the index is < 512.
    cmp     rsi, 512
    jb      .index_ok
    PANIC64("_set_table_entry: Index >= 512\n")
.index_ok:

    // Check the mapping flags.
    call    _check_map_flags_rcx
    test    rax, rax
    jnz     .flags_ok
    PANIC64("_set_table_entry: Invalid flags\n")
.flags_ok:

    // RDI = Pointer to entry to be modified.
    lea     rdi, [rdi + rsi * 8]

    // Check that this entry is not currently used.
    test    QWORD PTR [rdi], (1 << PRESENT_SHIFT)
    jz      .not_used
    // This entry is marked as present, this means it is still in use.
    PANIC64("_set_table_entry: Tried to overwrite an existing mapping\n")
.not_used:

    // Set address of next level table.
    or      [rdi], rdx
    // Set present and write bits.
    or      QWORD PTR [rdi], (1 << PRESENT_SHIFT)
    // Set other flags.
    or      QWORD PTR [rdi], rcx
    leave
    ret

// =============================================================================
// Compute an index from a virtual address.
// @param (RDI) Virtual address.
// @param (RSI) Level between 0-4. 4 indicates the index in the PML4, 0 indicate
// the offset in the page.
// @return (EAX): The index.
// =============================================================================
ASM_FUNC_DEF64(_get_index):
    push    rbp
    mov     rbp, rsp

    test    rsi, rsi
    jnz     0f
    // The level is zero, easy case, return the lower 12 bits.
    mov     rax, rdi
    and     rax, 0xFFF
    jmp     1f

0:
    // To get the index, we need to shift the virtual addr by:
    //      (level - 1) * 9 + 12 bits to the right.
    // and then AND with 0x1FF.
    mov     rcx, rsi
    dec     rcx
    imul    rcx, rcx, 9
    add     rcx, 12
    mov     rax, rdi
    shr     rax, cl
    and     rax, 0x1FF
1:
    leave
    ret

// =============================================================================
// Flush the TLB.
// =============================================================================
ASM_FUNC_DEF64(_flush_tlb):
    // The old CR3 switcharoo!
    mov     rax, cr3
    mov     cr3, rax
    ret

// =============================================================================
// Map a physical frame to virtual memory.
// @param (RDI) Virtual address to map to. Must be page aligned
// @param (RSI) Physical address of the frame to be mapped. Must be page
// aligned.
// @param (RDX) Flags of mapping.
// =============================================================================
ASM_FUNC_DEF64(map_frame):
    push    rbp
    mov     rbp, rsp

    // Local var:
    //  RBP - 0x8: Flags.
    push    rdx

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    // Addresses should be page aligned.
    test    rdi, (PAGE_SIZE - 1)
    jnz     .map_not_aligned
    test    rsi, (PAGE_SIZE - 1)
    jnz     .map_not_aligned
    jmp     .map_aligned 
.map_not_aligned:
    PANIC64("map_frame: Address not aligned\n")
.map_aligned:
    // R12 = Virtual address of current table. We start at the PML4.
    mov     r12, ~(0xFFF)
    // R13 = Current table level.
    mov     r13, 4 
    // R14 = Virt addr to map to.
    mov     r14, rdi
    // R15 = Phy addr to map.
    mov     r15, rsi

    // Walk the page table structure starting from the PML4. The idea is to make
    // sure that, at each level, the entry that contains the virtual address is
    // present. If this is not the case then allocate a table and update the
    // entry.
    // The next iteration will be on the table pointed by the entry.
.map_loop:
    // RBX = Index at current table.
    mov     rdi, r14
    mov     rsi, r13
    call    _get_index
    mov     rbx, rax

    // If this is the Page Table level (level = 1) then skip the allocate and
    // directly set the entry to point to the physical frame.
    cmp     r13, 1
    je      .last_level

    // Level > 1. Check if the entry is present. If not allocate it.
    // Check if entry is present.
    test    QWORD PTR [r12 + rbx * 8], (1 << PRESENT_SHIFT)
    jnz     .map_loop_continue

    // The entry is not present, we need to allocate a new table and insert it.
    // RAX = Addr of new table.
    call    allocate_frame64
    
    // Write the new entry.
    mov     rdi, r12
    mov     rsi, rbx
    mov     rdx, rax
    mov     rcx, INTERMEDIATE_FLAGS
    call    _set_table_entry
    jmp     .map_loop_continue

.last_level:
    // This is the last level/Page Table. We are done potentially adding table,
    // we can now write the final entry mapping the physical frame.
    mov     rdi, r12
    mov     rsi, rbx
    mov     rdx, r15
    mov     rcx, [rbp - 0x8]
    call    _set_table_entry
    
.map_loop_continue:
    // Update the virtual address of the current table now that we know the
    // index and that the table is present.
    shr     r12, 12
    shl     r12, 9
    or      r12, rbx
    shl     r12, 12
    // Make sure the address is canonical.
    shl     r12, 16
    sar     r12, 16

    // Dec and check the current level. If it is >0 then loop.
    dec     r13
    test    r13, r13
    jnz     .map_loop

    pop    r15
    pop    r14
    pop    r13
    pop    r12
    pop    rbx

    // Get rid of local var.
    add     rsp, 8

    leave
    ret
