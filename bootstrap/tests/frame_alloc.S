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
