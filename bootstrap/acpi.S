// This file contains all the routines related to ACPI table parsing. One simply
// needs to call the init_acpi routine to parse all ACPI tables and initialize
// state that depend on ACPI tables (such as LAPIC and IOAPIC addresses, NCPUS,
// IRQ redirections, ...).

#include <asm_macros.h>
#include <consts.h>
.intel_syntax   noprefix

.section .data
// Signature of the Root System Descriptor Pointer (RSDP). This is what we need
// to look for to find the location of the table.
rsdp_signature:
.ascii "RSD PTR "

// Jump table for the _acpi_parse_sdt routine. Each entry of this table is a
// pair <signature>:<function> where <signature> is a 4 byte string and
// <function> is a pointer (8 bytes) to the function handling SDTs of the given
// signature. The table ends with a 0:0 entry.
acpi_sdt_parsers_table:
REGISTER_SDT_PARSER("APIC", _acpi_sdt_parser_apic)
// 0:0 entru indicating the end of the table.
.skip   12, 0

// The physical address of the LAPIC. This is for any cpu in the system.
.global LAPIC_ADDR
LAPIC_ADDR:
.quad   0x0

// The physical address of the IOAPIC. This _should_ (AFAIK) be valid for any
// cpu. AFAIK there is only one IOAPIC.
.global IOAPIC_ADDR
IOAPIC_ADDR:
.quad   0x0

// The total number of cpus on the processor.
.global NCPUS
NCPUS:
.byte   0x0

// Array containing the redirected legacy IRQs. This array is indexed by the
// legacy IRQ vector (0 through 15 included) and maps to the system interrupt.
// By default the mapping is idempotent, the ACPI tables (more precisely the
// MADT) will tell us what the actual mapping is.
.global IRQ_REDIR
IRQ_REDIR:
.byte 0x0,0x1,0x2,0x3,0x4,0x5,0x6,0x7,0x8,0x9,0xA,0xB,0xC,0xD,0xE,0xF

// Jump table used by _acpi_sdt_parser_apic to parse the entries of the MADT.
// This table is indexed by the entry type (which is between 0 and 5 included).
acpi_sdt_parser_apic_jump_table:
.quad ._acpi_sdt_parser_apic_target_0
.quad ._acpi_sdt_parser_apic_target_1
.quad ._acpi_sdt_parser_apic_target_2
.quad ._acpi_sdt_parser_apic_target_3
.quad ._acpi_sdt_parser_apic_target_4
.quad ._acpi_sdt_parser_apic_target_5

// =============================================================================
// Try to find the RSDP in a memory region.
// @param (RDI): Start address of the memory region to scan.
// @param (RSI): End address of the memory region to scan.
// @return (RAX): If found, the linear address of the RSDP, otherwise 0x0.
// =============================================================================
ASM_FUNC_DEF64(_acpi_find_rsdp_helper):
    push    rbp
    mov     rbp, rsp

    // The RSDP is on a 16-bytes aligned address. Hence we might need to fix up
    // the start or end addresses.
    and     rdi, ~(16 - 1)
    and     rsi, ~(16 - 1)

    // RCX = Number of addresses to test, that is the number of 16-bytes aligned
    // addresses between start and end.
    mov     rcx, rsi
    sub     rcx, rdi
    jns     0f
    PANIC64("_acpi_find_rsdp_helper: Start address > End address")
0:
    shr     rcx, 4

    // To find the RSDP we need to find its signature, a 8 char string.
    // RAX = Signature.
    mov     rax, [rsdp_signature]
._acpi_find_rsdp_helper_loop:
    scasq
    je      ._acpi_find_rsdp_helper_found
    // Since the RSDP is on a 16-byte aligned address, RDI needs to be increased
    // by 16. It was already inc by 8 by the SCASQ instruction.
    add     rdi, 8
    loop     ._acpi_find_rsdp_helper_loop

    // Could not find the RSDP here.
    xor     rax, rax
    jmp     ._acpi_find_rsdp_helper_end
._acpi_find_rsdp_helper_found:
    // RSDP found at address RDI - 8. The -8 comes from the fact that scasq
    // increased RDI by 8 on the last iteration.
    mov     rax, rdi
    sub     rax, 8
._acpi_find_rsdp_helper_end:
    leave
    ret

// =============================================================================
// Validate the checksum of an ACPI table. This routine works with the RSDP,
// RSDT and any SDTs.
// @param (RDI): Pointer to the table to validate the checksum for.
// @param (RSI): Length of the table in bytes.
// @return (RAX): 1 if the checksum is valid, else 0.
// =============================================================================
ASM_FUNC_DEF64(_acpi_validate_checksum):
    push    rbp
    mov     rbp, rsp

    // Checksums of ACPI tables is done by adding up every bytes of the table
    // and making sure that the result has its lower byte to 0.
    // RAX = Sum.
    xor     rax, rax
    mov     rcx, rsi
._acpi_validate_checksum_loop:
    movzx   rdx, BYTE PTR [rdi + rcx - 1]
    add     rax, rdx
    loop    ._acpi_validate_checksum_loop

    // Check lower byte of the sum.
    test    al, al
    jz      ._acpi_validate_checksum_ok

    // Checksum is not valid.
    xor     rax, rax
    jmp     ._acpi_validate_checksum_end
._acpi_validate_checksum_ok:
    mov     rax, 1
._acpi_validate_checksum_end:
    leave
    ret

// =============================================================================
// Check that the RSDP is supported, that is its revision is ACPI v1 and its
// checksum is valid.
// @param (RDI): Pointer to the RSDP.
// @return (RAX): 1 if the RSDP is valid, 0 otherwise.
// =============================================================================
ASM_FUNC_DEF64(_acpi_check_rsdp):
    push    rbp
    mov     rbp, rsp

    // First check that the revision of the RSDP is 0, that is ACPI v1. For now
    // we only support ACPI v1, which is what qemu implements. Support to ACPI
    // v2 can easily be added later (and will most likely be required for read
    // hardware).
    cmp     BYTE PTR [rdi + ACPI_RSDP_REVISION_OFF], 0x0
    je      0f
    INFO64("_acpi_check_rsdp: Unsupported ACPI version!\n")
    xor     rax, rax
    leave
    ret
0:
    mov     rsi, ACPI_RSDP_SIZE
    // RAX == Checksum is valid.
    call    _acpi_validate_checksum
    leave
    ret

// =============================================================================
// Find the RSDP.
// @return (RAX): The linear address of the RSDP. If no RSDP is found this
// routine will panic. The address returned is guaranteed to be ID mapped in
// virtual address space (since the lower 1MiB is ID mapped).
// =============================================================================
ASM_FUNC_DEF64(_acpi_find_rsdp):
    push    rbp
    mov     rbp, rsp

    // RSDP is either located:
    //  - In the first 1KiB of the Extended BIOS Data Area (EBDA).
    //  - Between 0x000E0000 and 0x000FFFFF.

    // First location.
    mov     rdi, 0x80000
    // The -16 because RSDP is always on a 16-byte aligned address.
    mov     rsi, 0x80000 + 1024 - 16
    call    _acpi_find_rsdp_helper
    test    rax, rax
    jnz     ._acpi_find_rsdp_found

    // Second location.
    mov     rdi, 0x000E0000
    mov     rsi, 0x000FFFFF - 16
    call    _acpi_find_rsdp_helper
    test    rax, rax
    jnz     ._acpi_find_rsdp_found

    // Could not find the RSDP.
    PANIC64("_acpi_find_rsdp: No RSDP found in standard locations.")

._acpi_find_rsdp_found:
    // RAX = Address of RSDP.
    push    rax
    INFO64("RSDP found @ %q\n")
    pop     rax
    // Check that the RSDP is valid (correct revision and checksum is valid).
    // This will panic if it isn't.
    push    rax
    mov     rdi, rax
    call    _acpi_check_rsdp

    test    rax, rax
    jnz     0f
    PANIC64("_acpi_find_rsdp: RSDP is not valid or supported")

0:
    pop     rax

    leave
    ret

// =============================================================================
// Check that an SDT is valid, that is its checksum is valid.
// @param (RDI): pointer to SDT. This must point to the header of the SDT.
// @return (RAX): 1 if the checksum is valid, 0 otherwise.
// =============================================================================
ASM_FUNC_DEF64(_acpi_check_sdt):
    push    rbp
    mov     rbp, rsp

    // RSI = Length of SDT.
    mov     esi, DWORD PTR [rdi + ACPI_SDT_HDR_LENGTH_OFF]
    // RAX = checksum is valid.
    call    _acpi_validate_checksum
    leave
    ret

// =============================================================================
// Map a SDT to virtual memory and check its checksum. If the checksum is
// invalid this routine will PANIC! This routine works with both the RSDT or a
// regular SDT.
// @param (RDI): PHYSICAL address of the SDT.
// @return (RAX): The virtual address where the SDT has been mapped to.
// Note: The caller of this routine should unmap the SDT once it is not using it
// anymore.
// =============================================================================
ASM_FUNC_DEF64(_acpi_map_and_check_sdt):
    push    rbp
    mov     rbp, rsp

    // FIXME: For now we are using an ID map.
    // Step 1: Map the header of the table so that we can read its length.
    push    rdi
    mov     rsi, rdi
    mov     rdx, ACPI_SDT_HDR_SIZE
    mov     rcx, MAP_READ_ONLY
    call    map
    pop     rdi

    // RDX = Total length of table (including the header).
    mov     edx, DWORD PTR [rdi + ACPI_SDT_HDR_LENGTH_OFF] 

    // Step 2: Map the entire table.
    push    rdi
    mov     rsi, rdi
    mov     rcx, MAP_READ_ONLY
    call    map
    pop     rdi

    // Step 3: Validate the checksum.
    push    rdi
    call    _acpi_check_sdt
    test    rax, rax
    jnz     0f
    PANIC64("init_acpi: SDT checksum is invalid")
0:
    // RAX = Virtual address of the SDT (= RDI).
    pop     rax
    leave
    ret

// =============================================================================
// Unmap a SDT that has been mapped to virtual address space.
// @param (RDI): Virtual address of the SDT to unmap.
// =============================================================================
ASM_FUNC_DEF64(_acpi_unmap_sdt):
    // TODO: Once we have a routine to unmap virtual addresses, we should call
    // it here.
    ret


// =============================================================================
// Parser for SDT with signature = "APIC". This routine must be called by
// _acpi_parse_sdt only.
// @param (RDI): Pointer on the SDT to parse.
// =============================================================================
ASM_FUNC_DEF64(_acpi_sdt_parser_apic):
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    // We don't bother checking the signature again. Trust the _acpi_parse_sdt
    // routine for that. If you are calling this function yourself you are
    // asking for troubles anyway.
    
    // The MADT gives us the LAPIC address. Save this address for later when we
    // initialize the LAPIC.
    mov     eax, [rdi + ACPI_MADT_LAPIC_ADDR_OFF]
    mov     [LAPIC_ADDR], rax

    // Now parse each entry of the MADT. Entries have variable length, but all
    // start with a common header:
    //  (BYTE) Entry type.
    //  (BYTE) Entry length (including the entry header).
    // RBX = Entry iterator.
    lea     rbx, [rdi + ACPI_MADT_ENTRIES_OFF]
    // R12 = Stop addr.
    mov     r12d, [rdi + ACPI_SDT_HDR_LENGTH_OFF]
    add     r12, rdi
    jmp     ._acpi_sdt_parser_apic_cond
._acpi_sdt_parser_apic_loop:
    // AL = Entry type.
    movzx   rax, BYTE PTR [rbx]
    cmp     rax, 5
    jbe     0f
    PANIC64("_acpi_sdt_parser_apic: Invalid entry type")
0:
    // Use the jump table to jump to the correct label.
    jmp     [acpi_sdt_parser_apic_jump_table + rax * 8]

    // Each label below handles a given entry type. The following invariants
    // hold true when the execution flow reaches any label:
    //  - RBX points to the entry (to the header of the entry).

    // Type 0 => Processor Local APIC. There is one such entry for each core on
    // the cpu. This entry has the following content.
    //  Offset  | Len   | Desc
    //  --------+-------+-------------------------------------------------------
    //  0x2     | 0x1   | ACPI Processor ID
    //  0x3     | 0x1   | APIC ID
    //  0x4     | 0x4   | Flags (bit 0 = cpu enabled, bit 1 = online capable)
._acpi_sdt_parser_apic_target_0:
    DEBUG64("Entry type = 0 (LAPIC)\n")
    // If this cpu is online capable OR enabled, increment the NCPUS.
    mov     eax, [rbx + 0x4]
    test    eax, eax
    setnz   al
    add     BYTE PTR [NCPUS], al
    jmp     ._acpi_sdt_parser_apic_next

    // Type 1 => I/O APIC. There is one entry for each I/O APIC.
    //  Offset  | Len   | Desc
    //  --------+-------+-------------------------------------------------------
    //  0x2     | 0x1   | I/O APIC's ID
    //  0x3     | 0x1   | Reserved (0)
    //  0x4     | 0x4   | I/O APIC Address
    //  0x8     | 0x4   | Global System Interrupt Base 
    // The global system interrupt base is the first interrupt number that this
    // I/O APIC handles
._acpi_sdt_parser_apic_target_1:
    DEBUG64("Entry type = 1 (IOAPIC)\n")
    // Save the address of the IOAPIC.
    mov     eax, [rbx + 0x4]
    mov     [IOAPIC_ADDR], rax

    // Make sure that the base is 0. This is because we only support one IOAPIC
    // max.
    cmp     DWORD PTR [rbx + 0x8], 0x0
    je      ._acpi_sdt_parser_apic_next
    PANIC64("_acpi_sdt_parser_apic: IOAPIC does not have base = 0")

    // Type 2 => Interrupt Source Override. This explains how IRQ sources are
    // mapped to global system interrupts.
    //  Offset  | Len   | Desc
    //  --------+-------+-------------------------------------------------------
    //  0x2     | 0x1   | Bus Source
    //  0x3     | 0x1   | IRQ Source e.g the legacy interrupt
    //  0x4     | 0x4   | Global System Interrupt e.g where IRQ is redirected
    //  0x8     | 0x2   | Flags (unused here)
._acpi_sdt_parser_apic_target_2:
    DEBUG64("Entry type = 2 (Interrupt Source Override)\n")
    // RAX = Legacy IRQ vector.
    movzx   eax, BYTE PTR [rbx + 0x3]
    // CL = New vector.
    mov     cl, [rbx + 0x4]
    // Save the redirection.
    mov     BYTE PTR [IRQ_REDIR + rax], cl
    
    movzx   rcx, cl
    push    rcx
    push    rax
    DEBUG64("IRQ %b redirected to vector %b\n")
    add     esp, 0x10

    jmp     ._acpi_sdt_parser_apic_next

    // Type 3 => Invalid type.
._acpi_sdt_parser_apic_target_3:
    PANIC64("_acpi_sdt_parser_apic: Invalid entry type 3")

    // Type 4 => Non-maskable interrupts. Unused in this project.
._acpi_sdt_parser_apic_target_4:
    DEBUG64("Entry type = 4 (Non-maskable interrupts)\n")
    jmp     ._acpi_sdt_parser_apic_next

    // Type 5 => Local APIC Address Override. Provides 64 bit systems with an
    // override of the physical address of the Local APIC. There can only be one
    // of these defined in the MADT. If this structure is defined, the 64-bit
    // Local APIC address stored within it should be used instead of the 32-bit
    // Local APIC address stored in the MADT header.
    //  Offset  | Len   | Desc
    //  --------+-------+-------------------------------------------------------
    //  0x2     | 0x2   | Reserved
    //  0x4     | 0x8   | 64-bit physical address of Local APIC
._acpi_sdt_parser_apic_target_5:
    DEBUG64("Entry type = 5 (Local APIC Address Override)\n")
    // Since we already parsed the address of the LAPIC from the MADT, if we
    // find this type of entry then we simply need to overwrite the saved
    // LAPIC_ADDR.
    mov     rax, [rbx + 0x4]
    mov     [LAPIC_ADDR], rax
    jmp     ._acpi_sdt_parser_apic_next

._acpi_sdt_parser_apic_next:
    // Advance to next entry by adding the entry's length to the iterator.
    // RAX = Entry's length.
    movzx   rax, BYTE PTR [rbx + 1]
    add     rbx, rax
._acpi_sdt_parser_apic_cond:
    // Loop until we reach the end of the MADT (R12).
    cmp     rbx, r12
    jb      ._acpi_sdt_parser_apic_loop

    pop     r12
    pop     rbx
    leave
    ret

// =============================================================================
// Parse an SDT. This routine will look for a parser for the given signature in
// the acpi_sdt_parsers_table and, if any, calls it with the SDT as argument.
// @param (RDI): Pointer on the SDT to parse.
// =============================================================================
ASM_FUNC_DEF64(_acpi_parse_sdt):
    push    rbp
    mov     rbp, rsp

    push    rbx
    
    // Map the SDT to virtual memory and validate its checksum.
    // RBX = Virtual address of SDT.
    call    _acpi_map_and_check_sdt
    mov     rbx, rax

    push    rax
    DEBUG64("_acpi_parse_sdt: SDT @ %q has signature: ")
    pop     rax
    
    // Some shenanigans to print the signature. FIXME: It would _really_ help to
    // have the %s substitution for the logging functions.
    push    rbx
    mov     ecx, DWORD PTR [rbx]
    mov     rdx, '\n' << 32
    or      rcx, rdx
    push    rcx
    mov     rdi, rsp
    call    printf64 
    add     esp, 8
    pop     rbx

    // Find a parser (if any) for this SDT in the parser table.
    // RCX = Iterator on the table.
    lea     rcx, [acpi_sdt_parsers_table]
    // EDX = Signature of current SDT.
    mov     edx, DWORD PTR [rbx + ACPI_SDT_HDR_SIGNATURE_OFF]
    jmp     ._acpi_parse_sdt_find_loop_cond
._acpi_parse_sdt_find_loop:
    // Compare the signature with the entry.
    cmp     edx, DWORD PTR [rcx]
    jne     ._acpi_parse_sdt_find_loop_next
    
    // This is the same signature, call the parser.
    mov     rdi, rbx
    mov     rax, [rcx + 4]
    call    rax
    // Break out of the loop.
    jmp     ._acpi_parse_sdt_end

._acpi_parse_sdt_find_loop_next:
    // Advance iterator. Each entry in the table is 12 bytes.
    add     rcx, 12
._acpi_parse_sdt_find_loop_cond:
    cmp     DWORD PTR [rcx], 0x0
    jne     ._acpi_parse_sdt_find_loop

    // If we reach this point then no parser was found for this signature, then
    // we simply ignore this table. 
    DEBUG64("No parser for current SDT\n")
._acpi_parse_sdt_end:

    // Unmap the table from virtual memory.
    mov     rdi, rbx
    call    _acpi_unmap_sdt

    pop     rbx
    leave
    ret

// =============================================================================
// Parse the RSDT and all SDTs that it refers to.
// @param (RDI): Pointer to RSDT.
// =============================================================================
ASM_FUNC_DEF64(_acpi_parse_rsdt):
    push    rbp
    mov     rbp, rsp
    push    rbx
    // The RSDT (as of ACPI v1) is composed of the SDT header followed by an
    // array of 32-bit pointer (physical addresses) of the other SDTs. This
    // array contains N = (rsdt.length - sizeof(sdt header)) / 4 entries.

    // RCX = N = number of entries in array.
    mov     ecx, DWORD PTR [rdi + ACPI_SDT_HDR_LENGTH_OFF]
    sub     rcx, ACPI_SDT_HDR_SIZE
    shr     rcx, 2

    push    rdi
    push    rcx
    DEBUG64("_acpi_parse_rsdt: RSDT contains %d entries\n")
    pop     rcx
    pop     rdi

    // Iterate over the array of pointer to parse all SDTs.
    // RBX = Iterator on array.
    mov     rbx, rdi
    add     rbx, ACPI_SDT_HDR_SIZE
._acpi_parse_rsdt_loop:
    // Save iteration count.
    push    rcx

    // Parse SDT.
    mov     edi, [rbx]
    call    _acpi_parse_sdt 

    // Advance iterator and go to next iteration.
    add     rbx, 4
    pop     rcx
    loop    ._acpi_parse_rsdt_loop

    pop     rbx
    leave
    ret

// =============================================================================
// Parse all ACPI tables and initialize any state depending on them (LAPIC and
// IOAPIC addresses, NCPUS, IRQ redirection, ...), basically any global symbol
// from the .data section of this file.
// =============================================================================
ASM_FUNC_DEF64(init_acpi):
    push    rbp
    mov     rbp, rsp

    push    rbx

    // Step 1: Find the Root System Descriptor Pointer (RSDP).
    // RAX = Address of RSDP.
    call    _acpi_find_rsdp

    // RBX = Address of RSDT.
    mov     ebx, DWORD PTR [rax + ACPI_RSDP_RSDT_ADDR_OFF]

    // Map the RSDT to virtual memory.
    mov     rdi, rbx
    call    _acpi_map_and_check_sdt

    push    rbx
    DEBUG64("RSDT @ %q\n")
    add     esp, 8

    // Parse the RSDT and all SDTs pointed by it.
    mov     rdi, rbx
    call    _acpi_parse_rsdt

    // Unmap the RSDT.
    mov     rdi, rbx
    call    _acpi_unmap_sdt

    INFO64("ACPI tables successfully parsed\n")

    pop     rbx
    leave
    ret
