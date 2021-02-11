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
// Allocate multiple contiguous physical frames at once.
// @param N: The number of physical frames to allocate. This must be under 2^20.
// @return (EAX): The address of the first frame allocated. If no frame can be
// allocated, this routine will return NO_FRAME.
// =============================================================================
ASM_FUNC_DEF32(allocate_n_frames32):
    push    ebp
    mov     ebp, esp

    // Local var:
    //  EBP - 0x8: (QWORD) requested size in a QWORD.
    push    0x0
    push    [ebp + 0x8]

    // Check N against the maximum possible.
    cmp     DWORD PTR [ebp + 0x8], (1 << 20)
    jb      0f
    PANIC32("allocate_n_frames32: N is too big!\n")
0:

    // Check that the head of the linked list is not above 4GiB.
    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    je      0f
    PANIC32("allocate_n_frames32: First node in linked list is above 4GiB\n")
0:

    push    ebx
    push    edi
    push    esi

    // Traverse the linked list to find a group containing enough frames.
    // EBX = Pointer on current group.
    mov     ebx, [FRAME_ALLOC_HEAD]
    // EDI = Pointer on the next pointer of the previous node.
    lea     edi, [FRAME_ALLOC_HEAD]
.alloc_n_loop:
    // Check if the base addres of the current group is above 4GiB.
    cmp     DWORD PTR [ebx + NODE_ADDR_OFF + 4], 0x0
    jne     .alloc_n_next

    // Node starts under 4GiB and thus is available for 32-bit frame allocation.
    // Check the size of the current group against the requested size.
    lea     eax, [ebx + NODE_SIZE_OFF]
    push    eax
    lea     eax, [ebp - 0x8]
    push    eax
    call    cmp64
    add     esp, 0x8
    // If EAX == ARITH64_ABOVE then the requested size is bigger than the
    // current group. This will not work, try the next group.
    cmp     eax, ARITH64_ABOVE
    je      .alloc_n_next

    // The current group is big enough to perform the allocation. Now make sure
    // that the base address + the size does not go over the 4GiB limit. Since
    // we know that the top 32-bit of the base address are 0 we can simply add
    // the size to the lower 32-bit and check the Carry Flag. If CF is set then
    // the region goes over 4GiB and therefore cannot be used for this
    // allocation.
    // EAX = Address of the last byte of the allocation.
    mov     eax, [ebx + NODE_ADDR_OFF]
    mov     ecx, [ebp + 0x8]
    shl     ecx, 12
    // Dec here because we want the address of the last valid byte.
    dec     ecx
    add     eax, ecx
    jc      .alloc_n_next

    // This group passed all the checks, we can proceed with the allocation.
    // ESI = Start address of the allocated frames = base address of the group.
    // Once again this address is below 4GiB hence we only load the first
    // 32-bits.
    mov     esi, [ebx + NODE_ADDR_OFF]

    // Update the base address of the group by advancing it by N * PAGE_SIZE.
    lea     eax, [ebp - 0x8]
    shl     DWORD PTR [eax], 12
    push    eax
    lea     eax, [ebx + NODE_ADDR_OFF]
    push    eax
    // In-place update.
    push    eax
    call    add64
    add     esp, 0xC
    shr     DWORD PTR [ebp - 0x8], 12

    // Update the size of the group.
    lea     eax, [ebp - 0x8]
    push    eax
    lea     eax, [ebx + NODE_SIZE_OFF]
    push    eax
    // Update in place.
    push    eax
    call    sub64
    add     esp, 0xC

    // Check if size of group is now zero.
    cmp     DWORD PTR [ebx + NODE_SIZE_OFF + 4], 0x0
    jne     .alloc_n_done
    cmp     DWORD PTR [ebx + NODE_SIZE_OFF], 0x0
    jne     .alloc_n_done

    // Size is zero, we need to remove the group. Update the next pointer of the
    // previous node to point to the next node of the current one.
    mov     eax, [ebx + NODE_NEXT_OFF]
    mov     [edi], eax
    jmp     .alloc_n_done

.alloc_n_next:
    // Traverse the linked list.
    cmp     DWORD PTR [ebx + NODE_NEXT_OFF + 4], 0x0
    je      0f
    PANIC32("allocate_n_frames32: Node of linked list above 4GiB\n")
0:

    lea     edi, [ebx + NODE_NEXT_OFF]
    mov     ebx, [ebx + NODE_NEXT_OFF]

    test    ebx, ebx
    jnz     .alloc_n_loop
    // Reached the end of the linked list and couldn't find a suitable group.
    // The allocation failed.
    mov     esi, NO_FRAME

.alloc_n_done:
    // Allocation is done, ESI points to the start of the allocated physical
    // RAM.
    mov     eax, esi
    pop     esi
    pop     edi
    pop     ebx

    // Cleanup local var(s).
    add     esp, 8

    leave
    ret

// =============================================================================
// Get a free physical frame. Since this routine is for 32-bit mode it will
// return a frame under 4GiB. This is equivalent to call allocate_n_frames32
// with N = 1.
// @return (EAX): The address of frame allocated. If no frame can be allocated,
// this routine will return NO_FRAME.
// =============================================================================
ASM_FUNC_DEF32(allocate_frame32):
    push    0x1
    call    allocate_n_frames32
    add     esp, 4
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
