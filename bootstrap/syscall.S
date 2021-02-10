// Syscall related routines.
// Syscalls in Krayte are done through software interrupts for now. In the
// future we might add support for the SYSCALL/SYSENTER instructions, but for
// now we try to keep things simple (interrupts are well tested) and portable
// (at least for syscalls).
//
// Syscalls through software interrupts use the following conventions:
//  - Vector is INTERRUPT_SYSCALL_VEC.
//  - RAX contains the syscall number.
//  - Parameters of the syscall are passed through registers in the following
//  order:
//      1. RDI
//      2. RSI
//      3. RDX
//      4. RCX
//      5. R8
//      6. R9
//  - For now a syscall can only take up to 6 parameters. Passing extra
//  parameters through the stack can be added later. There is no use cases for
//  more than 6 parameters for now.
//  - RAX will contains the return value of the syscall.
// Syscall numbers are defined in consts.h

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

.section .data
// The SYSCALL_TABLE is a simple array mapping a syscall number to its handler.
// Each entry in the table is a 64-bit pointer to a handler. Entries are indexed
// by syscall number, that is entry i correspond to syscall number i and
// SYSCALL_TABLE + i * 8 contains the pointer to the handler for syscall number
// i.
// 0x0 entries indicate non-implemented syscalls.
// Note: Handlers should be written like regular routines, that is using the
// custom 64-bit SYSV ABI, without expecting arguments on the stack (limit of 6
// arguments).
// Note2: The first 2 entries of the syscall table are reserved for testing.
.global SYSCALL_TABLE
SYSCALL_TABLE:
.quad   0x0
.quad   0x0
SYSCALL_TABLE_END:

// =============================================================================
// Initialize syscall handling.
// =============================================================================
ASM_FUNC_DEF64(init_syscall):
    push    rbp
    mov     rbp, rsp
    
    // The only thing needed at initialization time is to register the callback
    // for INTERRUPT_SYSCALL_VEC.
    mov     rdi, INTERRUPT_SYSCALL_VEC
    lea     rsi, [syscall_callback]
    call    set_interrupt_callback

    leave
    ret

// =============================================================================
// Revert a call to init_syscall. This routine must only be used in tests. The
// rationale is that syscall tests might expect the syscall subsystem to be
// initialized to work properly, but init_syscall cannot be called before
// running the tests as it would conflict with interrupt tests registering
// callbacks for every vectors.
// =============================================================================
ASM_FUNC_DEF64(reset_syscall):
    // For now we simply need to remove the interrupt callback used for
    // syscalls.
    mov     rdi, INTERRUPT_SYSCALL_VEC
    call    del_interrupt_callback
    ret

// =============================================================================
// Callback for a syscall through a software interrupt INTERRUPT_SYSCALL_VEC.
// @param (RDI): Pointer to the interrupt frame.
// =============================================================================
ASM_FUNC_DEF64(syscall_callback):
    push    rbp
    mov     rbp, rsp

    // Check that the syscall number is not out of bounds.
    // RAX = Requested syscall number.
    mov     rax, [rdi + INT_FRAME_SAVED_RAX_OFF]
    // RCX = Number of entries in SYSCALL_TABLE.
    lea     rcx, [SYSCALL_TABLE_END - SYSCALL_TABLE]
    shr     rcx, 3

    cmp     rax, rcx
    jb      0f
    // Syscall number is out of bounds. This usually indicates something went
    // terribly wrong in the application. PANIC.
    PANIC64("syscall_callback: Syscall number out of bounds")
0:

    // Get the handler's address.
    lea     rcx, [SYSCALL_TABLE]
    // RAX = handler's address.
    mov     rax, [rcx + rax * 8]

    // The handler's address may be 0x0, indicating that the syscall is not
    // (yet) implemented. In this case we should panic.
    test    rax, rax
    jnz     0f
    PANIC64("syscall_callback: Syscall number not implemented")
0:

    // Unpack the arguments for the handler.
    mov     rsi, [rdi + INT_FRAME_SAVED_RSI_OFF]
    mov     rdx, [rdi + INT_FRAME_SAVED_RDX_OFF]
    mov     rcx, [rdi + INT_FRAME_SAVED_RCX_OFF]
    mov     r8,  [rdi + INT_FRAME_SAVED_R8_OFF]
    mov     r9,  [rdi + INT_FRAME_SAVED_R9_OFF]
    push    rdi
    mov     rdi, [rdi + INT_FRAME_SAVED_RDI_OFF]

    // Call the handler.
    call    rax

    pop     rdi
    // Set the saved RAX to the return value of the handler.
    mov     [rdi + INT_FRAME_SAVED_RAX_OFF], rax

    // Return to interrupted context.
    leave
    ret
