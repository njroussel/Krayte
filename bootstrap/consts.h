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
