// This file contains the ELF parser that will parse and prepare execution
// environment for the application.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

// Offsets of different fields (those that we use) of a 64-bit ELF header.
.set ELF_HEADER_SIZE, 0x40
// Magic number.
.set E_MAG, 0x0
// Class (e.g. 32 or 64bits).
.set E_CLASS, 0x4
// Endianess
.set E_DATA, 0x5
// Version.
.set E_VERSION, 0x6
// Type (executable, shared obj, ...)
.set E_TYPE, 0x10
// Architecture.
.set E_MACHINE, 0x12
// Version (second one, ELF is weird).
.set E_VERSION2, 0x14
// Entry point of program.
.set E_ENTRY, 0x18
// Offset of the Program Header Table in the file.
.set E_PHOFF, 0x20
// Size of a Program Header Table entry.
.set E_PHENTSIZE, 0x36
// The number of entries in the Program Header Table.
.set E_PHNUM, 0x38

// =============================================================================
// Check that an ELF file is compatible with the boostrap, that is:
//  - Correct magic number at beginning of file.
//  - 64bit ELF for AMD64 architecture (and hence little endian).
//  - Executable type (this implies having a Program Header Table).
//  - Correct version numbers.
// @param (RDI) Address of the file.
// @return (RAX): 1 if the file is valid and compatible, 0 otherwise.
// =============================================================================
ASM_FUNC_DEF64(check_elf):
    push    rbp
    mov     rbp, rsp

    // Check magic number at beginning of file.
    mov     eax, [rdi + E_MAG]
    cmp     eax, 0x464C457F
    jne     .check_elf_fail

    // Check that the class is set to 2 (e.g. 64-bits).
    mov     al, [rdi + E_CLASS]
    cmp     al, 2
    jne     .check_elf_fail

    // Check that this is little endian.
    mov     al, [rdi + E_DATA]
    cmp     al, 1
    jne     .check_elf_fail

    // Check version.
    mov     al, [rdi + E_VERSION]
    cmp     al, 1
    jne     .check_elf_fail

    // Check type.
    mov     ax, [rdi + E_TYPE]
    // 0x02 == Executable.
    cmp     ax, 0x02
    jne     .check_elf_fail

    // Check arch.
    mov     ax, [rdi + E_MACHINE]
    // 0x3E == AMD64.
    cmp     ax, 0x3E
    jne     .check_elf_fail

    // Check 2nd version number.
    mov     eax, [rdi + E_VERSION2]
    cmp     eax, 0x1
    jne     .check_elf_fail

    // Check the offset of the program header table, this should be right after
    // the ELF header and therefore 0x40.
    mov     rax, [rdi + E_PHOFF]
    cmp     rax, 0x40
    jne     .check_elf_fail

    // All criteria are met.
    mov     rax, 1
    leave
    ret
.check_elf_fail:
    xor     rax, rax
    leave
    ret

// Offsets for a Program Header Table entry (the one that we use).
// The type of the entry (e.g. LOAD, DYNAMIC, ...).
.set P_TYPE, 0x0
// Offset of the segment's data in the file.
.set P_OFFSET, 0x8
// Virtual address of the segment.
.set P_VADDR, 0x10
// Size of the data of the segment in the file. This is <= P_MEMSZ.
.set P_FILESZ, 0x20
// Size of the segment in virtual memory. If this is bigger than P_FILESZ then
// any additional bytes after the initialized content should be 0.
.set P_MEMSZ, 0x20
// Size of a Program Header Table entry in bytes.
.set PHENTSIZE, 0x38

// =============================================================================
// Process a LOAD entry from the Program Header Table. This routine will
// allocate the requested memory and copy data from the file to the memory (if
// applicable).
// @param (RDI) The address of the file.
// @param (RSI) The address of the entry.
// @param (RDX) The size of the file.
// =============================================================================
ASM_FUNC_DEF64(_pht_process_load_segment):
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    // RBX = Address of the entry.
    mov     rbx, rsi
    // R12 = Size of file.
    mov     r12, rdx
    // R13 = Address of the file.
    mov     r13, rdi

    push    rbx
    INFO64("Processing PHT entry @ %q\n")
    add     esp, 8

    // Check if p_memsz is 0. This is allowed in the ELF spec. If this is the
    // case skip this entry. FIXME: Is that really what we need to do ?
    // RCX = memsize
    mov     rcx, [rbx + P_MEMSZ]
    test    rcx, rcx
    jz      .memsz_zero

    // Compute the number of pages required for this segment.
    // RAX = Page index of the beginning of the segment.
    mov     rax, [rbx + P_VADDR]
    and     rax, ~(PAGE_SIZE - 1)
    // RCX = Page index of the end of the segment.
    mov     rcx, [rbx + P_VADDR]
    add     rcx, [rbx + P_MEMSZ]
    and     rcx, ~(PAGE_SIZE - 1)
    // RCX = Number of pages for the segment.
    sub     rcx, rax
    // Ceil.
    inc     rcx

    // Allocate virtual memory for the segment. The P_VADDR given in the file is
    // not necessarily page aligned, hence use RAX which is the rounded down
    // address.
    mov     rdi, rax
    // FIXME: Even though the entry would indicate the access bits of the
    // segment, we still need to write data into it. Hence set it to writable.
    mov     rsi, MAP_WRITE
    mov     rdx, rcx
    call    alloc_virt

    // Virtual memory has been allocated. Now copy the content from the file to
    // the memory. We know from the spec that P_FILESZ <= P_MEMSZ. Hence copy
    // the first P_FILESZ bytes. If P_FILESZ < P_MEMSZ then the remaining bytes
    // are 0.
copy:
    mov     rdi, [rbx + P_VADDR]
    mov     rsi, r13
    add     rsi, [rbx + P_OFFSET]
    mov     rcx, [rbx + P_FILESZ]
    cld
    rep     movsb
    // Check if P_FILESZ < P_MEMSZ.
    mov     rax, [rbx + P_FILESZ]
    cmp     rax, [rbx + P_MEMSZ]
    je      .process_done
    // Write 0 for the remaining bytes.
    xor     al, al
    mov     rcx, [rbx + P_MEMSZ]
    sub     rcx, [rbx + P_FILESZ]
    rep     movsb
    jmp     .process_done

.memsz_zero:
    WARN64("Empty segment in ELF file\n")
.process_done:
    pop     r13
    pop     r12
    pop     rbx
    leave
    ret

// Some values for the Program Header Table entry type field.
// PT_LOAD indicate a loadable segment, this is what we are looking for.
.set PT_LOAD, 0x1
// The following values are not allowed, and are check against the type of all
// processed entries to detect errors. If one of these type is discovered then
// something was wrong with the way the application was compiled and the ELF is
// therefore not supported by the bootstrap.
// Dynamic linking information.
.set PT_DYNAMIC, 0x2
// Interpreted information.
.set PT_INTERP, 0x3
// Thread-Local Storage Template.
.set PT_TLS, 0x7

// =============================================================================
// Parse the Program Header Table from the ELF file. This will process each
// entry in the order they appear in the file.
// @param (RDI) The address of the beginning of the file.
// @param (RSI) The address of the program header table.
// @param (RDX) The number of entries in the program header table.
// @param (RCX) The size of the file in bytes.
// =============================================================================
ASM_FUNC_DEF64(parse_prog_header_table):
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    // Process each entry.
    // RCX = Number of entries left to parse.
    mov     rcx, rdx
    // RBX = Address of current entry.
    mov     rbx, rsi 
    // R12 = Size of file.
    mov     r12, rcx
    // R13 = Pointer on the file.
    mov     r13, rdi
.parse_prog_header_table_loop:
    push    rcx

    // EAX = type of entry. For now we only support LOAD entries. Some other
    // types can be ignored (e.g. NOTES or GNU stack, ...), but the type should
    // never be DYNAMIC or INTERP unless something went wrong with the
    // compilation of the application (e.g. not freestanding or dependency on
    // the std lib).
    mov     eax, [rbx + P_TYPE]
    cmp     eax, PT_LOAD
    je      0f
    cmp     eax, PT_DYNAMIC
    je      1f
    cmp     eax, PT_INTERP
    je      1f
    cmp     eax, PT_TLS
    je      1f
    jmp     .parse_prog_header_table_loop_next
1:
    PANIC64("parse_prog_header_table: Unexpected segment type\n")
0:
    // This is a loadable segment. Process it.
    mov     rdi, r13
    mov     rsi, rbx
    mov     rdx, r12
    call    _pht_process_load_segment

    // Next iteration.
.parse_prog_header_table_loop_next:
    // Advance pointer to the next entry.
    add     rbx, PHENTSIZE
    pop     rcx
    loop    .parse_prog_header_table_loop

    pop     r13
    pop     r12
    pop     rbx
    leave
    ret

// =============================================================================
// Parse an ELF file loaded in RAM. This will create all segments of the Program
// Header Table in virtual memory and initialize their content. The file must be
// a 64-bit ELF and its type must be `Executable`.
// @param (RDI) Address of the file in RAM to be parsed.
// @param (RSI) Size of the file in bytes.
// @return (RAX): The entry point of the executable.
// =============================================================================
ASM_FUNC_DEF64(parse_elf_from_ram):
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    // RBX = Address of the file.
    mov     rbx, rdi
    // R12 = Size of the file.
    mov     r12, rsi

    // First off check that the file is big enough to contain an ELF header and
    // that this is an actual ELF file that we can process and run.
    cmp     r12, ELF_HEADER_SIZE
    jae     0f
    PANIC64("parse_elf_from_ram: File too small\n")
0:
    call    check_elf
    test    rax, rax
    jnz     0f
    PANIC64("parse_elf_from_ram: Not a compatible ELF file.\n")
0:
    INFO64("ELF file is compatible!\n")

    // Check that the file contains the entire program header table.
    // RAX = Limit of page header table that is the offset of the last valid
    // byte in the table.
    mov     ax, WORD PTR [rbx + E_PHENTSIZE]
    movzx   rax, ax
    cqo
    mov     cx, [rbx + E_PHNUM]
    movzx   rcx, cx
    mul     rcx
    add     rax, [rbx + E_PHOFF]
    dec     rax
    cmp     rax, r12
    jb      0f
    PANIC64("parse_prog_header_table: File too small for prog header table\n")
0:
    
    // The program header table is not out of bounds. Parse it.
    mov     rdi, rbx
    mov     rsi, rbx
    add     rsi, [rbx + E_PHOFF]
    mov     dx, [rbx + E_PHNUM]
    movzx   rdx, dx
    mov     rcx, r12
    call    parse_prog_header_table

    INFO64("Program Header Table parsed\n")

    mov     rax, [rbx + E_ENTRY]

    pop     r12
    pop     rbx
    leave
    ret
