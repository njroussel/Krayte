// This file contains routines and state related to I/O APIC.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

.section .data
// The max index in the redirection table.
ioapic_max_redir_entry:
.byte   0x0

// Offset of the two registers of the IO APIC.
.set IOREGSEL, 0x0
.set IOWIN, 0x10

// The offsets of the IOAPIC registers.
.set IOAPICID, 0x0
.set IOAPICVER, 0x1
.set IOAPICARB, 0x2
.set IOREDTBL0, 0x10

// =============================================================================
// Initialize the I/O APIC.
// =============================================================================
ASM_FUNC_DEF64(init_ioapic):
    push    rbp
    mov     rbp, rsp
    push    rbx

    // Check that the address of the IOAPIC was found while parsing ACPI tables.
    // RBX = Physical address of IO APIC.
    mov     rbx, [IOAPIC_ADDR]
    test    rbx, rbx
    jnz     0f
    PANIC64("init_ioapic: IOAPIC_ADDR is 0x0. Did you parse ACPI tables ?")
0:
    push    rbx
    INFO64("Initializing I/O APIC @ %q\n")
    pop     rbx

    // We need to map the I/O APIC to virtual address space. Use an ID mapping
    // to avoid confusions.
    mov     rdi, rbx
    mov     rsi, rbx
    // We only need to map the two memory map registers.
    mov     rdx, 0x14
    mov     rcx, (MAP_WRITE | MAP_CACHE_DISABLE | MAP_WRITE_THROUGH)
    call    map

    // We can now use the IOAPIC.
    // Read the version and the maximum number of redirection entries.
    mov     BYTE PTR [rbx + IOREGSEL], IOAPICVER
    mov     eax, [rbx + IOWIN]

    // Save max redirection entry.
    mov     ecx, eax
    shr     ecx, 16
    mov     [ioapic_max_redir_entry], cl 

    push    rcx
    push    rax
    INFO64("I/O APIC is version %b, max redirection entry = %b\n")
    pop     rax
    pop     rcx

    pop     rbx
    leave
    ret

// =============================================================================
// Map a legacy IRQ number to a vector. Subsequent interrupts on this IRQ will
// raise an interrupt with the given vector on the current cpu.
// @param (RDI): Legacy IRQ number.
// @param (RSI): Vector to redirect to.
// =============================================================================
ASM_FUNC_DEF64(ioapic_redir_legacy_irq):
    push    rbp
    mov     rbp, rsp
    push    rbx

    // Check that the IRQ number is within the range of the redirection table.
    cmp     dil, [ioapic_max_redir_entry]
    jbe     0f
    PANIC64("ioapic_redir_legacy_irq: IRQ number is outside bounds of table")
0:

    push    rsi
    push    rdi
    INFO64("ioapic_redir_legacy_irq: Redirecting IRQ %b => vector %b\n")
    pop     rdi
    pop     rsi

    // The IRQ may not be identity-mapped to the I/O APIC. Look up the IRQ_REDIR
    // table from ACPI to use the correct source.
    lea     rbx, [IRQ_REDIR]
    mov     al, dil
    xlatb 
    mov     dil, al

    // RBX = IOAPIC.
    mov     rbx, [IOAPIC_ADDR]

    // Compute the value to write into the redirection table.
    // RAX = entry.
    // FIXME: For now we leave everything to 0, except the vector, this means:
    //  - Delivery mode = Fixed
    //  - Destination mode = Physical
    //  - Polarity = High active
    //  - Trigger mode = edge sensitive
    //  - Interrupt unmasked
    //  - Destination = APIC ID 0.
    // FIXME: The destination is always cpu 0.
    // In practice this is working just fine.
    xor     rax, rax
    mov     al, sil

    // Write the new entry. The low DWORD should be written to IOREDTBLx and the
    // high DWORD to IOREDTBLx+1. Although the specification is not clear about
    // how to write those, we should probably write the high DWORD first, as the
    // low DWORD will unmask the interrupt.
    // CL = IOREDTBLx+1
    mov     cl, dil
    shl     cl, 1
    add     cl, IOREDTBL0 + 1

    // Write high DWORD.
    mov     rdx, rax
    shr     rdx, 32
    mov     BYTE PTR [rbx + IOREGSEL], cl
    mov     [rbx + IOWIN], edx

    // Write low DWORD.
    dec     cl
    shr     rdx, 32
    mov     BYTE PTR [rbx + IOREGSEL], cl
    mov     [rbx + IOWIN], eax

    pop     rbx
    leave
    ret
