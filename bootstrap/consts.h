// This file contains #defines of many constants used throughout the project.
// The reason we are using #defines instead of global `.set`s is because the
// latter will generate relocation when used in different file from where it has
// been declared/.set.

// ============================================================================= 
// BIOS Call Packet (BCP)
// This data structure is described in bios.S.
// The following constants define the offset of each field.

// (BYTE) Interrupt number of the function.
#define BCP_INT_OFF 0x00
// (BYTE) Value of CF after the function call.
#define BCP_CF_OFF  0x01
// (DWORD) * 8, Value of the GP registers.
#define BCP_EDI_OFF 0x02
#define BCP_ESI_OFF 0x06
#define BCP_EBP_OFF 0x0A
#define BCP_ESP_OFF 0x0E
#define BCP_EBX_OFF 0x12
#define BCP_EDX_OFF 0x16
#define BCP_ECX_OFF 0x1A
#define BCP_EAX_OFF 0x1E

// Size of the BCP structure.
#define BCP_SIZE 0x22
// ============================================================================= 

// ============================================================================= 
// 64-bit Arithmetic comparison return values.

#define ARITH64_BELOW   -1
#define ARITH64_EQUAL   0
#define ARITH64_ABOVE   1
// ============================================================================= 

// ============================================================================= 
// Memory Map Entry (MME)
// (QWORD) The base address of the memory region described by this entry.
#define MME_BASE_OFF    0x00
// (QWORD) The length of the memory region described by this entry.
#define MME_LENGTH_OFF  0x08
// (DWORD) The type of the memory region described by this entry.
#define MME_TYPE_OFF    0x10

#define MME_SIZE        0x14

// Here are the possible values for the type field of a MME:
// The memory region is available for use.
#define MME_TYPE_AVAIL  0x1
// The memory region is reserved (mmem-map devices, ...).
#define MME_TYPE_RESRV  0x1
// Other values are possible but considered reserved as well for this project.
// ============================================================================= 

// ============================================================================= 
// Frame allocator consts.
#define PAGE_SIZE 4096
// Indicate failure during the frame allocation. Any value that is not page
// aligned works.
#define NO_FRAME  0xFFFFFFFF

// The following are the offsets used for the nodes of the allocator's linked
// list.
// Offset of the `next` pointer in a node.
#define NODE_NEXT_OFF 0x0
// Offset of the start address in a node.
#define NODE_ADDR_OFF 0x8
// Offset of the block size in a node.
#define NODE_SIZE_OFF 0x10
// Total size of a node structure in bytes.
#define NODE_SIZE 0x18
// ============================================================================= 

// ============================================================================= 
// Paging consts.
// Mapping flags: These flags control how a physical frame is mapped to virtual
// memory.
// Define the page as read only.
#define MAP_READ_ONLY       (0)
// Enable write on the page.
#define MAP_WRITE           (1 << 1)
// Allow user access to the page.
#define MAP_USER            (1 << 2)
// All writes are write through.
#define MAP_WRITE_THROUGH   (1 << 3)
// Disable cache for the memory addresses pointing to this page.
#define MAP_CACHE_DISABLE   (1 << 4)
// Set the global bit.
#define MAP_GLOBAL          (1 << 8)
// Indicate that the page is non-executable.
#define MAP_NO_EXEC         (1 << 63)
// ============================================================================= 

// ============================================================================= 
// Disk Address Packet (DAP). This data structure is used by the BIOS function
// int 0x13/AH 0x42 to load sectors/blocks from a disk into memory.

// (BYTE) The size of the DAP. Must be DAP_SIZE.
#define DAP_SIZE_OFF        0x0
// (BYTE) Reserved, must be 0.
#define DAP_RESV_OFF        0x1
// (WORD) The number of blocks to read from disk.
#define DAP_NUM_BLOCKS_OFF  0x2
// (DWORD) Where to copy the blocks.
#define DAP_DEST_OFF        0x4
// (QWORD) Start index of the blocks to copy.
#define DAP_START_BLOCK_OFF 0x8

// Size of the DAP structure.
#define DAP_SIZE    0x10
// ============================================================================= 

// ============================================================================= 
// Metadata sector. The metadata sector is a special sector located on disk
// right after the last sector used by the bootstrap. Its goal is to provide
// information to locate the ELF file to be loaded and executed.
// (DWORD) The size of the file in bytes.
#define METADATA_SIZE_OFF       0x0
// (DWORD) The index of the first sector containing the file. The file is stored
// in contiguous sectors on the disk.
#define METADATA_START_SEC_OFF  0x4
// (NUL-terminated string) The name of the file.
#define METADATA_NAME_OFF       0x8
// ============================================================================= 

// ============================================================================= 
// ACPI offsets and constants.
// Root System Descriptor Pointer (RSDP) offsets:
// (QWORD) Signature of the table, must contain "RSD PTR ".
#define ACPI_RSDP_SIGNATURE_OFF 0x00
// (BYTE) Checksum of the RSDP.
#define ACPI_RSDP_CHECKSUM_OFF  0x08
// (6 BYTES) OEM identifier.
#define ACPI_RSDP_OEMID_OFF     0x09
// (BYTE) Revision. 0 -> ACPI v1, 1 -> ACPI v2 to v6.1.
#define ACPI_RSDP_REVISION_OFF  0x0F
// (DWORD) Linear Address of the RSDT.
#define ACPI_RSDP_RSDT_ADDR_OFF 0x10
// Size of a RSDP for ACPI v1.
#define ACPI_RSDP_SIZE  0x14

// System Descriptor Table (SDT) header offsets:
// (4 BYTES) Signature of the SDT.
#define ACPI_SDT_HDR_SIGNATURE_OFF          0x0
// (DWORD) Length of the SDT in bytes, including the header.
#define ACPI_SDT_HDR_LENGTH_OFF             0x4
// (BYTE) Revision of the SDT.
#define ACPI_SDT_HDR_REVISION_OFF           0x8
// (BYTE) Checksum so that the sum of all bytes has its lower byte to 0x0.
#define ACPI_SDT_HDR_CHECKSUM_OFF           0x9
// (6 BYTES) OEM ID String.
#define ACPI_SDT_HDR_OEMID_OFF              0xA
// (8 BYTES) OEM ID String bis.
#define ACPI_SDT_HDR_OEMTABLEID_OFF         0x10
// (DWORD) OEM Revision.
#define ACPI_SDT_HDR_OEMREVISION_OFF        0x18
// (DWORD) Creator ID.
#define ACPI_SDT_HDR_CREATORID_OFF          0x1C
// (DWORD) Creator Revision.
#define ACPI_SDT_HDR_CREATORREVISION_OFF    0x20
// Size of a SDT header.
#define ACPI_SDT_HDR_SIZE ACPI_SDT_HDR_CREATORREVISION_OFF + 4

// Offsets for SDT with signature == "APIC", those tables are also known as
// Multiple APIC Description Table (MADT). An MADT starts with an SDT header
// followed by the fields:
// (DWORD) Physical address of the LAPIC.
#define ACPI_MADT_LAPIC_ADDR_OFF    0x24
#define ACPI_MADT_ENTRIES_OFF       0x2C
// The MADT then contains an arbitrary number of variable sized entries. Each
// entry starts with a header:
// (BYTE) Type of the entry. See acpi.S for more info about the different types.
#define ACPI_MADT_ENTRY_TYPE_OFF    0x0
// (BYTE) Length of the entry in byte, including the header.
#define ACPI_MADT_ENTRY_LENGTH_OFF  0x1
// ============================================================================= 

// ============================================================================= 
// Interrupt related constants.
// The size of the IDT in number of entries, if this value is X then the IDT
// will handle interrupts vectors 0, 1, ..., X - 1.
#define INTERRUPT_IDT_SIZE  0x30

// Vectors used in this project:
// Vector used for the redirected PIT IRQs.
#define INTERRUPT_PIT_VEC       0x20
// Vector used for syscalls through software interrupts.
#define INTERRUPT_SYSCALL_VEC   0x21

// Offsets for the interrupt frame constructed by the generic interrupt handler.
// (QWORD) R15 value at the time of the interrupt.
#define INT_FRAME_SAVED_R15_OFF     (0 * 0x8)
// (QWORD) R14 value at the time of the interrupt.
#define INT_FRAME_SAVED_R14_OFF     (1 * 0x8)
// (QWORD) R13 value at the time of the interrupt.
#define INT_FRAME_SAVED_R13_OFF     (2 * 0x8)
// (QWORD) R12 value at the time of the interrupt.
#define INT_FRAME_SAVED_R12_OFF     (3 * 0x8)
// (QWORD) R11 value at the time of the interrupt.
#define INT_FRAME_SAVED_R11_OFF     (4 * 0x8)
// (QWORD) R10 value at the time of the interrupt.
#define INT_FRAME_SAVED_R10_OFF     (5 * 0x8)
// (QWORD) R9 value at the time of the interrupt.
#define INT_FRAME_SAVED_R9_OFF      (6 * 0x8)
// (QWORD) R8 value at the time of the interrupt.
#define INT_FRAME_SAVED_R8_OFF      (7 * 0x8)
// (QWORD) RDI value at the time of the interrupt.
#define INT_FRAME_SAVED_RDI_OFF     (8 * 0x8)
// (QWORD) RSI value at the time of the interrupt.
#define INT_FRAME_SAVED_RSI_OFF     (9 * 0x8)
// (QWORD) RBP value at the time of the interrupt.
#define INT_FRAME_SAVED_RBP_OFF     (10 * 0x8)
// (QWORD) RBX value at the time of the interrupt.
#define INT_FRAME_SAVED_RBX_OFF     (11 * 0x8)
// (QWORD) RDX value at the time of the interrupt.
#define INT_FRAME_SAVED_RDX_OFF     (12 * 0x8)
// (QWORD) RCX value at the time of the interrupt.
#define INT_FRAME_SAVED_RCX_OFF     (13 * 0x8)
// (QWORD) RAX value at the time of the interrupt.
#define INT_FRAME_SAVED_RAX_OFF     (14 * 0x8)
// (QWORD) Vector of the interrupt.
#define INT_FRAME_VECTOR_OFF        (15 * 0x8)
// (QWORD) Error code of the interrupt. For vector that do not push error code
// or software interrupts this value is a placeholder.
#define INT_FRAME_ERROR_CODE_OFF    (16 * 0x8)
// (QWORD) RIP at the time of the interrupt.
#define INT_FRAME_RIP_OFF           (17 * 0x8)
// (QWORD) CS at the time of the interrupt.
#define INT_FRAME_CS_OFF            (18 * 0x8)
// (QWORD) RFLAGS at the time of the interrupt.
#define INT_FRAME_RFLAGS_OFF        (19 * 0x8)
// (QWORD) RSP at the time of the interrupt.
#define INT_FRAME_RSP_OFF           (20 * 0x8)
// (QWORD) SS at the time of the interrupt.
#define INT_FRAME_SS_OFF            (21 * 0x8)
// ============================================================================= 

// ============================================================================= 
// Programmable Interval Timer (PIT) constants.
// This is the base frequency of the crystal oscillator of the PIT.
#define PIT_BASE_FREQ   1193182
// Choose a reload value so that PIT_FREQ % RELOAD_VAL == 0 as to avoid rounding
// errors! 29102 is the biggest divisor of the PIT frequency.
#define PIT_RELOAD_VAL  29102
// This is the divided frequency. THIS IS THE DROID YOU ARE LOOKING FOR!!
// Throughout this project, the PIT is ALWAYS running at this frequency. DO NOT
// use PIT_BASE_FREQ in computations!
#define PIT_FREQ        (PIT_BASE_FREQ / PIT_RELOAD_VAL)
// ============================================================================= 

// ============================================================================= 
// Syscall constants.
//
// Syscall numbers:
// Test syscall 0. Reserved for testing purposes.
#define SYSNR_TEST0         0x0
// Test syscall 1. Reserved for testing purposes.
#define SYSNR_TEST1         0x1
// Syscall to get the TSC's frequency in Hz.
#define SYSNR_GET_TSC_FREQ  0x2
// Syscall to print a NUL-terminated string in the serial console.
#define SYSNR_LOG_SERIAL    0x3
// Syscall to alloc/dealloc heap memory.
#define SYSNR_SBRK          0x4
// ============================================================================= 
