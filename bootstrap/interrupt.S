// This file contains all the state and routines related to interrupt
// initialization and handling.
// 
// In x86_64, the processor uses the Interrupt Descriptor Table (IDT) to know
// what handler to call for a given vector. Each IDT entry contains an `offset`
// field which is the address of the handler.
// Upon an interrupt, the processor pushes an interrupt frame onto the stack
// containing info about the interrupted context (RIP, RSP, CS, SS, RFLAGS,
// ...), looks up the handler for the vector into the IDT and jumps to it.
// Unfortunately, the interrupt frame does _not_ contain the vector number. We
// could define one handler per vector, and each handler would assume the vector
// number, but this means a lot of code duplication. Instead, we use the
// following architecture to reduce duplication:
//  1. We still define one handler per vector, but all handlers are the same and
// simply consist of a near CALL instruction to a `generic_handler`.
//  2. Each handler is therefore 5 bytes long (1 byte opcode and 32-bit rel
//  offset). All handlers are contiguous in memory, this means handlerN is at
//  address handlers<N-1> + 5.
//  3. When execution flow reaches the generic_handler, we can compute the
//  vector number by using the return address pushed by the CALL instruction of
//  the interrupt handler as follows:
//      vector = ((ret_addr - &handler0) / 5) - 1.
//  The rationale is that the return address will point to the instruction
//  _after_ the CALL instruction of the handler that called the generic_handler.
//  Each handler is 5-bytes long and they are contiguous/packed. The -1 is
//  because the return address is the next instruction, and not the CALL
//  instruction itself.
//
// In summary the interrupt handlers are arranged as follows:
//        handler0:
//            call    generic_handler
//        handler1:
//            call    generic_handler
//        handler2:
//            call    generic_handler
//        ...
//        handlerN:
//            call    generic_handler
//        ...
//        generic_handler:
//            ...
// IDT entry i points to handleri.
//
// The goal of the generic_handler is to compute the vector number, save the
// registers onto the stack, start the processing of the interrupt and later
// return to the interrupted context.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// Data used throughout this file.
.section .data
// The IDT descriptor to use with the LIDT instruction. This descriptor contains
// a 16-bit limit followed with the 8-byte linear address.
IDT_DESC:
.short  0x0
// Linear address of the IDT.
IDT_ADDR:
.quad   0x0
// Memory region containing all the interrupt handlers referenced by the IDT.
HANDLERS_ARRAY:
.quad   0x0

// =============================================================================
// Set an IDT entry. This routine will define an interrupt-gate with DPL = 0 and
// the given handler address as offset.
// @param (RDI): Index/vector of entry to set.
// @param (RSI): Offset of interrupt handler to use for the entry.
// =============================================================================
ASM_FUNC_DEF64(_set_idt_entry):
    push    rbp
    mov     rbp, rsp

    // RAX = Pointer on entry.
    mov     rcx, rdi
    shl     rcx, 4
    mov     rax, [IDT_ADDR]
    add     rax, rcx

    // First DWORD: Set lower 16-bits of offset and segment selector.
    // FIXME: The segment selector (64-bit code segment: 0x30) is hard-coded
    // here. We should at least have a #define in consts.h.
    mov     [rax], si
    or      DWORD PTR [rax], (0x30 << 16)
    add     rax, 4

    // Second DWORD: Set Type, DPL and present bit. Leave IST to 0, we are not
    // using this feature. Type 14 indicate a 64-bit interrupt gate. Upper
    // 16-bit of the DWORD contain offset bits 16 though 31.
    mov     [rax], esi
    and     DWORD PTR [rax], 0xFFFF << 16
    or      DWORD PTR [rax], (1 << 15) | (14 << 8)
    add     rax, 4

    // Third DWORD: Offset bit 32 through 63.
    shr     rsi, 32
    mov     DWORD PTR [rax], esi
    add     rax, 4

    // Fourth DWORD is reserved, put zero.
    mov     DWORD PTR [rax], 0x0
    
    leave
    ret

// =============================================================================
// Allocate and initialize the interrupt handlers for vectors 0 through
// INTERRUPT_IDT_SIZE - 1 included. Each handler is a near call to the
// generic_handler routine. Handlers are contiguous.
// =============================================================================
ASM_FUNC_DEF64(_generate_handlers):
    push    rbp
    mov     rbp, rsp

    // Allocate the array of interrup handlers. Each handler is 5-bytes long (a
    // near call with 32-bit relative offset).
    // RAX = Pointer on array of handlers.
    mov     rdi, INTERRUPT_IDT_SIZE
    imul    rdi, rdi, 5
    call    allocate_low_mem64
    // Save the array of handlers.
    mov     [HANDLERS_ARRAY], rax

    // Now populate the array. Each handler is a near call of the form:
    //  0xE8 <rel32>
    // where rel32 is a 32-bit relative offset (relative to instruction after
    // the call) in little-endian.
    // RAX = Iterator.
    // RCX = Number of handlers written.
    xor     rcx, rcx
    jmp     ._generate_handler_cond
._generate_handler_loop:
    // Set the near call rel32 opcode.
    mov     BYTE PTR [rax], 0xE8 

    // Compute the 32-bit displacement.
    // EDX = Displacement = &generic_handler - (EAX + 5).
    lea     edx, [generic_handler - 5]
    sub     edx, eax
    
    // Store displacement.
    mov     [rax + 1], edx
._generate_handler_next:
    // Advance iterator to next handler (5 bytes from the current one).
    add     rax, 5
    inc     rcx
._generate_handler_cond:
    // Check that RAX < 4GiB. This is because we use 32-bit arithmetic to
    // compute the relative offsets in the loop.
    mov     edx, eax
    cmp     rax, rdx
    je      0f
    PANIC64("_generate_handlers: RAX is above 4GiB")
0:
    cmp     rcx, INTERRUPT_IDT_SIZE
    jb      ._generate_handler_loop

    leave
    ret

// =============================================================================
// Allocate and fill up the IDT for entries 0 through INTERRUPT_IDT_SIZE - 1
// included. This routine will allocate and initialize handlers as well.
// =============================================================================
ASM_FUNC_DEF64(_create_idt):
    push    rbp
    mov     rbp, rsp
    push    rbx

    // Allocate the IDT, each entry is 16-bytes.
    // RAX = Address of IDT.
    mov     rdi, INTERRUPT_IDT_SIZE
    shl     rdi, 4
    call    allocate_low_mem64
    // Save the IDT address.
    mov     [IDT_ADDR], rax
    
    // Allocate and initialize interrupt handlers. This will allocate the
    // HANDLERS_ARRAY.
    call    _generate_handlers

    // Initialize each entry in the IDT to point to its corresponding handler in
    // the HANDLERS_ARRAY.
    // BL = Entry index.
    xor     rbx, rbx
    jmp     ._create_idt_cond
._create_idt_loop:
    // Call _set_idt_entry with index = BL and handler = Base + 5 * BL where
    // base is the address of the HANDLERS_ARRAY.
    movzx   rdi, bl
    imul    rsi, rbx, 5
    add     rsi, [HANDLERS_ARRAY]
    call    _set_idt_entry
._create_idt_next:
    // Next iteration, inc the vector.
    inc     bl
._create_idt_cond:
    cmp     bl, INTERRUPT_IDT_SIZE
    jb      ._create_idt_loop

    pop     rbx
    leave
    ret

// =============================================================================
// Initialize state related to interrupts, that is:
//  - IDT
//  - Interrupt handlers
//  - IDTR
// This routine will _NOT_ enable interrupts.
// =============================================================================
ASM_FUNC_DEF64(init_interrupt):
    push    rbp
    mov     rbp, rsp

    // Allocate IDT and interrupt handlers.
    call    _create_idt

    // Initialize the IDT_DESC's limit.
    mov     WORD PTR [IDT_DESC], (INTERRUPT_IDT_SIZE * 16) - 1

    // Load the IDTR.
    lidt    [IDT_DESC] 
    INFO64("IDTR set\n")

    leave
    ret

// =============================================================================
// This is the generic interrupt handler. Every handler for any vector will call
// this handler. This routine will figure out the vector of the interrupt, save
// all GP registers, create an interrupt frame, and start the processing of the
// interrupt.
// =============================================================================
ASM_FUNC_DEF64(generic_handler):
    // In x86_64, interrupts will push information onto the stack, this
    // information is also known as the interrupt frame (to avoid confusion we
    // will refer to this as _hardware_ interrupt frame). This interrupt frame
    // has the following layout:
    //  RSP + 0x28  |   SS      | <- SS at the time of the interrupt.
    //  RSP + 0x20  |   RSP     | <- RSP at the time of the interrupt.
    //  RSP + 0x18  | RFLAGS    | <- RFLAGS at the time of the interrupt.
    //  RSP + 0x10  |   CS      | <- CS at the time of the interrupt.
    //  RSP + 0x08  |   RIP     | <- RIP at the time of the interrupt.
    //  RSP + 0x00  | ERR CODE  | <- OPTIONAL depending on the interrupt vector.
    //
    // When the handler for a given vector called the generic_handler, it pushed
    // a return address onto the stack. Therefore the stack would look as
    // follows:
    // Vector with error code:     Vector without error code:
    //  RSP + 0x30  |   SS      |
    //  RSP + 0x28  |   RSP     |   RSP + 0x28  |   SS      |
    //  RSP + 0x20  | RFLAGS    |   RSP + 0x20  |   RSP     |
    //  RSP + 0x18  |   CS      |   RSP + 0x18  | RFLAGS    |
    //  RSP + 0x10  |   RIP     |   RSP + 0x10  |   CS      |
    //  RSP + 0x08  | ERR CODE  |   RSP + 0x08  |   RIP     |
    //  RSP + 0x00  | RET ADDR  |   RSP + 0x00  | RET ADDR  |
    // The distinction between vectors with and without error code induce
    // complexity since offsets will change. Additionally, it is the handler's
    // responsibility to pop the error code from the stack before executing
    // IRET.
    //
    // To keep things simple, the generic handler will modify the interrupt
    // frame by adding a dummy error code to vectors that do not push one, so
    // that every interrupt frame looks the same therefore offsets never change
    // and there is no shenanigans required to check if we need to remove the
    // error code before the IRET or not. Here we will always need to, since we
    // add the dummy error code.  Therefore interrupt frames will _always_ have
    // the layout described above with the error code.
    //
    // There is one problem to solve: we need to detect if the error code was
    // pushed onto the stack or not, and if not push a dummy one. We could do
    // that by computing the vector number and look up if this vector produces
    // an error code, but we can be smarter:
    // In x86_64, upon an interrupt the RSP is aligned to a 16-byte boundary
    // _before_ pushing the hardware interrupt frame. Therefore, if an error
    // code was pushed, the RET ADDR is _not_ 16-byte aligned, whereas if an
    // error code was _not_ pushed, RET ADDR is 16-byte aligned. Therefore we
    // can simply look at the current value of RSP, if it is 16-bytes aligned,
    // then the error code is missing and we need to fixup the interrupt frame,
    // otherwise the error code is present and nothing more needs to be done.
    // This "smarter" way adds the benefit that it works with software
    // interrupts raising vectors that would normally push an error code (SW
    // interrupt never push error codes).

    // Step 1: Fixup interrupt frames missing error code.
    test    rsp, 0xF
    jnz     0f
    // The Stack Pointer is 16-bytes aligned, this means the error code is
    // MISSING, we need to put a dummy one.
    // Push the RET ADDR 8 bytes down the stack.
    push    [rsp]
    // Write the dummy error code in the QWORD above the return address. Now the
    // stack is consistent with what we expect.
    // Note: We use the magic number 0xC0DEC0DEC0DEC0DE to indicate that the
    // interrupt did not push an error code.
    mov     DWORD PTR [rsp + 0x8], 0xC0DEC0DE
    mov     DWORD PTR [rsp + 0xC], 0xC0DEC0DE
0:

    // Step 2: Save all GP registers.
    push    rax
    push    rcx
    push    rdx
    push    rbx
    push    rbp
    push    rsi
    push    rdi

    // RBP = Interrupt frame.
    mov     rbp, rsp

    // Step 3: Compute the vector number. This is explained in the file-level
    // comment.
    // RAX = Interrupt vector = ((ret_addr - handler_base) / 5) - 1.
    mov     rax, [rsp + 7 * 8]
    sub     rax, [HANDLERS_ARRAY]
    cqo
    mov     rcx, 5
    div     rcx
    dec     rax
    // Replace the return address with the vector number computed.
    mov     [rbp + INT_FRAME_VECTOR_OFF], rax

    // Step 4: Here we would typically handle the interrupt. For now simply log
    // the interrupt.
    push    [rbp + INT_FRAME_RIP_OFF]
    push    [rbp + INT_FRAME_ERROR_CODE_OFF]
    push    [rbp + INT_FRAME_VECTOR_OFF]
    DEBUG64("INTERRUPT, vector = %b, error code = %q, RIP = %q\n")
    mov     rsp, rbp

    // Interrupt has been handled, we are about to return to the interrputed
    // context. First restore GP registers.
    pop     rdi
    pop     rsi
    pop     rbp
    pop     rbx
    pop     rdx
    pop     rcx
    pop     rax
    // Get rid of the vector number and the error code.
    add     rsp, 16
    // Return to interrupted context.
    iretq
