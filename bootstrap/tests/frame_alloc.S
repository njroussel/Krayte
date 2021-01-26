#include <asm_macros.h>
#include <test_macros.h>
#include <consts.h>

.intel_syntax   noprefix

.section .data
// Create a fake linked-list for the test.
node0:
.quad   node1
.quad   0xC000
.quad   2
node1:
.quad   0x0
.quad   0xDEAD000
.quad   1

// =============================================================================
// Test for allocate_frame32.
// =============================================================================
ASM_FUNC_DEF32(allocate_frame32_test):
    push    ebp
    mov     ebp, esp

    // Save the actual value of FRAME_ALLOC_HEAD.
    push    [FRAME_ALLOC_HEAD + 4]
    push    [FRAME_ALLOC_HEAD]

    // Set the FRAME_ALLOC_HEAD to the fake linked-list.
    lea     eax, [node0]
    mov     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    mov     [FRAME_ALLOC_HEAD], eax

    // First allocation: Expected ret = 0xC000. Node0 should have its size to 1
    // and start addr to 0xD000.
    call    allocate_frame32
    cmp     eax, 0xC000
    jne     .fail
    
    lea     eax, [node0]
    cmp     DWORD PTR [eax + NODE_ADDR_OFF + 4], 0x0
    jne     .fail
    cmp     DWORD PTR [eax + NODE_ADDR_OFF], 0xD000
    jne     .fail

    cmp     DWORD PTR [eax + NODE_SIZE_OFF + 4], 0x0
    jne     .fail
    cmp     DWORD PTR [eax + NODE_SIZE_OFF], 0x1
    jne     .fail

    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    jne     .fail
    cmp     [FRAME_ALLOC_HEAD], eax
    jne     .fail

    // Second allocation: Expected ret = 0xD000. Node0 should have been removed.
    call    allocate_frame32
    cmp     eax, 0xD000
    jne     .fail
    
    lea     eax, [node0]
    cmp     DWORD PTR [eax + NODE_ADDR_OFF + 4], 0x0
    jne     .fail
    cmp     DWORD PTR [eax + NODE_ADDR_OFF], 0xE000
    jne     .fail

    cmp     DWORD PTR [eax + NODE_SIZE_OFF + 4], 0x0
    jne     .fail
    cmp     DWORD PTR [eax + NODE_SIZE_OFF], 0x0
    jne     .fail

    lea     eax, [node1]
    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    jne     .fail
    cmp     [FRAME_ALLOC_HEAD], eax
    jne     .fail
    
    // Third allocation: Expected ret = 0xDEAD000. Node1 should have been
    // removed.
    call    allocate_frame32
    cmp     eax, 0xDEAD000
    jne     .fail
    
    lea     eax, [node1]
    cmp     DWORD PTR [eax + NODE_ADDR_OFF + 4], 0x0
    jne     .fail
    cmp     DWORD PTR [eax + NODE_ADDR_OFF], 0xDEAE000
    jne     .fail

    cmp     DWORD PTR [eax + NODE_SIZE_OFF + 4], 0x0
    jne     .fail
    cmp     DWORD PTR [eax + NODE_SIZE_OFF], 0x0
    jne     .fail

    xor     eax, eax
    cmp     [FRAME_ALLOC_HEAD + 4], eax
    jne     .fail
    cmp     [FRAME_ALLOC_HEAD], eax
    jne     .fail

    // Success.
    mov     eax, 1
    jmp     .out

.fail:
    xor     eax, eax
.out:

    // Restore FRAME_ALLOC_HEAD.
    pop     [FRAME_ALLOC_HEAD]
    pop     [FRAME_ALLOC_HEAD + 4]
    leave
    ret
REGISTER_TEST(allocate_frame32_test)

.section .data
n_node0:
.quad   n_node1
.quad   0xC000
.quad   1
n_node1:
.quad   n_node2
.quad   0xDEAD000
.quad   2
n_node2:
.quad   0x0
.quad   0xFFFFF000
.quad   64


// =============================================================================
// Simple test for the allocate_n_frames32 routine and its edge cases.
// =============================================================================
ASM_FUNC_DEF32(allocate_n_frames32_test):
    push    ebp
    mov     ebp, esp

    // Save the actual value of FRAME_ALLOC_HEAD.
    push    [FRAME_ALLOC_HEAD + 4]
    push    [FRAME_ALLOC_HEAD]

    // Set the FRAME_ALLOC_HEAD to the fake linked-list.
    lea     eax, [n_node0]
    mov     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    mov     [FRAME_ALLOC_HEAD], eax

    // Test case 1: Allocate 2 frames. Expected ret = 0xDEAD000. n_node0 still
    // has size = 1 and its next is n_node2.
    push    2
    call    allocate_n_frames32
    add     esp, 4
    cmp     eax, 0xDEAD000
    jne     .n_fail

    lea     eax, [n_node0]
    cmp     DWORD PTR [eax + NODE_ADDR_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_ADDR_OFF], 0xC000
    jne     .n_fail

    cmp     DWORD PTR [eax + NODE_SIZE_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_SIZE_OFF], 0x1
    jne     .n_fail

    cmp     DWORD PTR [eax + NODE_NEXT_OFF + 4], 0x0
    jne     .n_fail
    lea     ecx, [n_node2]
    cmp     DWORD PTR [eax + NODE_NEXT_OFF], ecx
    jne     .n_fail

    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    jne     .n_fail
    cmp     [FRAME_ALLOC_HEAD], eax
    jne     .n_fail

    // Test case 2: Allocate 1 frame. Expected ret = 0xC000, n_node2 is the only
    // remaining node.
    push    1
    call    allocate_n_frames32
    add     esp, 4
    cmp     eax, 0xC000
    jne     .n_fail

    lea     eax, [n_node2]
    cmp     DWORD PTR [eax + NODE_ADDR_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_ADDR_OFF], 0xFFFFF000
    jne     .n_fail

    cmp     DWORD PTR [eax + NODE_SIZE_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_SIZE_OFF], 64
    jne     .n_fail

    cmp     DWORD PTR [eax + NODE_NEXT_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_NEXT_OFF], 0x0
    jne     .n_fail

    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    jne     .n_fail
    cmp     [FRAME_ALLOC_HEAD], eax
    jne     .n_fail

    // Test case 3: Allocate 2 frames. This is not possible with n_node2 because
    // it would go over 4GiB.
    push    2
    call    allocate_n_frames32
    add     esp, 4
    cmp     eax, NO_FRAME
    jne     .n_fail

    // Test case 4: Allocate 1 frame. This is possible in n_node2. Expected ret
    // = 0xFFFFF000. n_node2 should have its base address above 4GiB.
    push    1
    call    allocate_n_frames32
    add     esp, 4
    cmp     eax, 0xFFFFF000
    jne     .n_fail

    lea     eax, [n_node2]
    cmp     DWORD PTR [eax + NODE_ADDR_OFF + 4], 0x1
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_ADDR_OFF], 0x0
    jne     .n_fail

    cmp     DWORD PTR [eax + NODE_SIZE_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_SIZE_OFF], 63
    jne     .n_fail

    cmp     DWORD PTR [eax + NODE_NEXT_OFF + 4], 0x0
    jne     .n_fail
    cmp     DWORD PTR [eax + NODE_NEXT_OFF], 0x0
    jne     .n_fail

    cmp     DWORD PTR [FRAME_ALLOC_HEAD + 4], 0x0
    jne     .n_fail
    cmp     [FRAME_ALLOC_HEAD], eax
    jne     .n_fail

    // Test case 5: Allocate 1 frame. Since n_node2 is the only group left and
    // starts above 4GiB the allocation should fail.
    push    1
    call    allocate_n_frames32
    add     esp, 4
    cmp     eax, NO_FRAME
    jne     .n_fail

    // Success.
    mov     eax, 1
    jmp     .n_out

.n_fail:
    xor     eax, eax
.n_out:

    // Restore FRAME_ALLOC_HEAD.
    pop     [FRAME_ALLOC_HEAD]
    pop     [FRAME_ALLOC_HEAD + 4]
    leave
    ret
REGISTER_TEST(allocate_n_frames32_test)
