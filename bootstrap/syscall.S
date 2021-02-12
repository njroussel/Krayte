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
.quad   do_get_tsc_freq
.quad   do_log_serial
.quad   do_sbrk
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

// =============================================================================
// Get the TSC's frequency in Hz. This is the implementaion of the
// SYSNR_GET_TSC_FREQ syscall.
// @return (RAX): The TSC's frequency.
// =============================================================================
ASM_FUNC_DEF64(do_get_tsc_freq):
    mov     rax, [TSC_FREQ]
    ret

// =============================================================================
// Log a message to the serial console. This is the implementation of the
// SYSNR_LOG_SERIAL syscall.
// @param (RDI): The NUL-terminated string to be printed.
// =============================================================================
ASM_FUNC_DEF64(do_log_serial):
    push    rbp
    mov     rbp, rsp
    push    rbx

    // RBX = Pointer to next char to print.
    mov     rbx, rdi

    // Iterate over each char of the string and use putc_serial64 to print it
    // out.
    jmp     ._do_log_serial_loop_cond
._do_log_serial_loop:
    movzx   rdi, al
    call    putc_serial64
    
    inc     rbx
._do_log_serial_loop_cond:
    // AL = next char to print.
    mov     al, [rbx]
    test    al, al
    jnz     ._do_log_serial_loop

    pop     rbx
    leave
    ret

// =============================================================================
// Increment or decrement the program break of the current process.
// @param (RDI): Increment in bytes. This can be negative to de-allocate heap
// memory. A value of 0 will return the current program break.
// @return (RAX): The new value of the program break.
// Note: The actual size being added or removed to/from the program break might
// be different than the argument passed for alignment purposes.
// =============================================================================
ASM_FUNC_DEF64(do_sbrk):
    push    rbp
    mov     rbp, rsp
    push    rbx

    cmp     rdi, 0x0
    jle     ._do_sbrk_dealloc
._do_sbrk_alloc:
    // Allocation is the hard case since we need to allocate physical RAM and
    // map it to virtual address space.
    // To make things easier, we are allocating by multiple of PAGE_SIZE.
    // RDX = Number of pages to allocate.
    mov     rdx, rdi
    shr     rdx, 12
    test    rdi, (PAGE_SIZE - 1)
    setnz   al
    movzx   rax, al
    add     rdx, rax

    push    rdx
    // Allocate virtual memory starting at the current program break.
    mov     rdi, [PROGRAM_BREAK]
    mov     rsi, (MAP_USER | MAP_WRITE)
    // RDX already contains the number of pages to allocate.
    call    alloc_virt
    pop     rdx

    // Compute the new program break.
    shl     rdx, 12
    add     [PROGRAM_BREAK], rdx
    mov     rax, [PROGRAM_BREAK]
    jmp     ._do_sbrk_end
._do_sbrk_dealloc:
    // Heap de-allocation is not yet implemented. For now we simply do nothing.
    mov     rax, [PROGRAM_BREAK]
._do_sbrk_end:
    // RAX must be set to return value before jumping to here.
    // Make sure the new PROGRAM_BREAK is page aligned.
    test    QWORD PTR [PROGRAM_BREAK], (PAGE_SIZE - 1)
    jz      0f
    PANIC64("do_sbrk: New program break is not page aligned")
0:
    push    rax
    DEBUG64("do_sbrk: New program break @ %q\n")
    pop     rax
    pop     rbx
    leave
    ret
