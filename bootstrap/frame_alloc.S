// This file contains all the code related to phusical frame allocation.
// The main data structure used by the allocator is a linked list where each
// node describes a block of contiguous free frames. Each node has the following
// layout:
//  - (QWORD) Address of the next entry/node in the linked list.
//  - (QWORD) Start address of the block. That is the address of the first frame
//  of the block.
//  - (QWORD) Size of the block in number of frames.
// A global variable (FRAME_ALLOC_HEAD) maintains a pointer to the head of the
// linked-list.
// Allocating a frame is straight-forward, one simply needs to look at the first
// entry of the linked list, the allocated frame is the first frame of the block
// described by the entry. The allocating procedure then update the start
// address and size fields of the entry. If this entry is empty then it is
// removed from the list.
// Free-ing frames is not yet implemented as there are no use case for that yet.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

.section .data
// The pointer to the first node in the list.
.global FRAME_ALLOC_HEAD
FRAME_ALLOC_HEAD:
.quad   0x0

// =============================================================================
// Shift a 64-bit value 12 bits to the right. Returns wether or not the result
// is 0.
// @param (DWORD): Pointer on a 64-bit value. The value will be updated
// in-place.
// @return (EAX): result value != 0.
// =============================================================================
ASM_FUNC_DEF32(_shr12_64):
    push    ebp
    mov     ebp, esp

    // EAX = Pointer on value.
    mov     eax, [ebp + 0x8]

    // ECX = lower 12 bits of high DWORD.
    mov     ecx, [eax + 4]
    and     ecx, 0xFFF
    
    // Shift both DWORDs independently.
    shr     DWORD PTR [eax], 12
    shr     DWORD PTR [eax + 4], 12

    // Fix the low DWORD's high 12 bits.
    shl     ecx, 20
    or      [eax], ecx
    
    cmp     DWORD PTR [eax], 0x0
    jne     0f
    cmp     DWORD PTR [eax + 4], 0x0
    jne     0f

    // Result is 0 => EAX = 0.
    xor     eax, eax
    jmp     1f
0:
    // Result is > 0 => EAX = 1.
    mov     eax, 1
1:
    leave
    ret


// =============================================================================
// Initialize the physical frame allocator. This will initialize the free frames
// linked-list.
// =============================================================================
ASM_FUNC_DEF32(init_frame_allocator):
    push    ebp
    mov     ebp, esp
    push    ebx
    push    edi
    push    esi

    INFO32("Init physical frame allocator\n")

    // EDI = entry index.
    xor     edi, edi
    // EBX = Address of the last entry in the linked list.
    lea     ebx, [FRAME_ALLOC_HEAD]
.loop:
    // ESI = Address of current mem map entry.
    imul    esi, edi, MME_SIZE
    add     esi, [MEM_MAP_START]

    // Check that this is available memory.
    cmp     DWORD PTR [esi + MME_TYPE_OFF], MME_TYPE_AVAIL
    jne     .next

    // If this entry refers to memory that is below 1MiB then don't touch it. We
    // don't want to clobber low memory.
    push    0x0
    push    0x100000
    push    esp
    lea     eax, [esi + MME_BASE_OFF]
    push    eax
    call    cmp64
    add     esp, 0x10
    cmp     eax, ARITH64_BELOW
    je      .next 
    
    // Memory is available. Compute the size in number of frames. Result is
    // stored onto the stack.
    push    DWORD PTR [esi + MME_LENGTH_OFF + 4]
    push    DWORD PTR [esi + MME_LENGTH_OFF]
    push    esp
    call    _shr12_64
    add     esp, 4

    // Some memory regions described in the mem map may be smaller than a page.
    // In this case we can skip them.
    test    eax, eax
    jz      .next_fixup

    // The size is >= 1 frame. Allocate a new entry in the linked-list.
    // EAX = Pointer on new linked-list node.
    push    NODE_SIZE
    call    allocate_low_mem
    add     esp, 4

    // Fill up the node.
    // Fill in size in frame.
    pop     [eax + NODE_SIZE_OFF]
    pop     [eax + NODE_SIZE_OFF + 4]
    // Fill in start address.
    mov     ecx, [esi + MME_BASE_OFF]
    mov     [eax + NODE_ADDR_OFF], ecx
    mov     ecx, [esi + MME_BASE_OFF + 4]
    mov     [eax + NODE_ADDR_OFF + 4], ecx
    // Fill in pointer to next node (NULL for now).
    xor     ecx, ecx
    mov     [eax + NODE_NEXT_OFF], ecx
    mov     [eax + NODE_NEXT_OFF + 4], ecx

    push    eax

    // Print new entry.
    push    [eax + NODE_SIZE_OFF + 4]
    push    [eax + NODE_SIZE_OFF]
    push    [eax + NODE_ADDR_OFF + 4]
    push    [eax + NODE_ADDR_OFF]
    INFO32("Available memory @ %q with %q frames\n")
    add     esp, 0x10
    pop     eax

    // Add the node to the linked list.
    mov     [ebx + NODE_NEXT_OFF], eax
    // Upper 32-bit of the address must be 0 since we skip entries above 4GiB.
    mov     DWORD PTR [ebx + NODE_NEXT_OFF + 4], 0x0

    // Update pointer of last entry in the list.
    mov     ebx, eax
    jmp     .next

.next_fixup:
    // This case is used when the code above is computing the size in number of
    // frames and the result is 0. Since the size was pushed onto the stack we
    // need to remove it.
    add     esp, 8
.next:
    inc     edi
.cond:    
    cmp     edi, [MEM_MAP_NUM_ENTRIES]
    jb      .loop

    pop     esi
    pop     edi
    pop     ebx
    leave
    ret

// =============================================================================
// Get a free physical frame. Since this routine is for 32-bit mode it will
// return a frame under 4GiB.
// @return (EAX) Physical address of the allocated frame.
// =============================================================================
ASM_FUNC_DEF32(allocate_frame32):
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi

    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    je      0f
    PANIC32("First node is above 4GiB\n")
0:

    // EBX = Pointer on the head node.
    mov     ebx, [FRAME_ALLOC_HEAD]

    // Assert that the start address is < 4GiB. We could instead look at the
    // next node, but then it would make things more complicated if we need to
    // remove it. By doing this way we can only remove the head of the list
    // which is simpler.
    cmp     DWORD PTR [ebx + NODE_ADDR_OFF + 4], 0x0
    je      0f
    PANIC32("First node has start address above 4GiB\n")
0:

    // Assert that the size is > 0.
    cmp     DWORD PTR [ebx + NODE_SIZE_OFF + 4], 0x0
    jne     0f
    cmp     DWORD PTR [ebx + NODE_SIZE_OFF], 0x0
    jne     0f
    // Size is zero. This should never happen.
    PANIC32("Element of allocator's linked list has a size of 0\n")
0:

    // ESI = Address of the allocated frame.
    mov     esi, [ebx + NODE_ADDR_OFF]

    // Increase start address by PAGE_SIZE.
    push    0x0
    push    PAGE_SIZE
    push    esp
    lea     eax, [ebx + NODE_ADDR_OFF]
    push    eax
    push    eax
    call    add64
    add     esp, 0x14

    // Decrease size by 1. 
    push    0x0
    push    0x1
    push    esp
    lea     eax, [ebx + NODE_SIZE_OFF]
    push    eax
    push    eax
    call    sub64
    add     esp, 4
    // Keep the same arg and compare the current size with 0x1
    call    cmp64
    add     esp, 0x10

    cmp     eax, ARITH64_BELOW
    jne     .alloc_done

    // Group is empty, remove it from the linked-list.
    mov     eax, [ebx + NODE_NEXT_OFF + 4]
    mov     [FRAME_ALLOC_HEAD + 4], eax
    mov     eax, [ebx + NODE_NEXT_OFF]
    mov     [FRAME_ALLOC_HEAD], eax
    
.alloc_done:
    // EBX = Address of the freshly allocated frame.
    mov     eax, esi

    pop     esi
    pop     ebx
    leave
    ret

// =============================================================================
// Get a free physical frame.
// @return (RAX) Physical address of the allocated frame.
// =============================================================================
ASM_FUNC_DEF64(allocate_frame64):
    push    rbp
    mov     rbp, rsp

    // RDI = Pointer on the head node.
    mov     rdi, [FRAME_ALLOC_HEAD]

    // Assert that the size is > 0.
    cmp     QWORD PTR [rdi + NODE_SIZE_OFF], 0x0
    jne     0f
    // Size is zero. This should never happen.
    PANIC64("Element of allocator's linked list has a size of 0\n")
0:

    // RAX = Address of the allocated frame.
    mov     rax, [rdi + NODE_ADDR_OFF]

    // Increase start address by PAGE_SIZE.
    add     QWORD PTR [rdi + NODE_ADDR_OFF], PAGE_SIZE

    // Decrease size by 1. 
    dec     QWORD PTR [rdi + NODE_SIZE_OFF]
    jne     .alloc_done64

    // Group is empty, remove it from the linked-list.
    mov     rcx, [rdi + NODE_NEXT_OFF]
    mov     [FRAME_ALLOC_HEAD], rcx
    
.alloc_done64:
    leave
    ret
