// This file contains routines and state related to the Time-Stamp Counter
// (TSC).
// In this project, we use the TSC as a time-keeping counter, this means that we
// need the TSC to have a _constant_ frequency no matter the state of the CPU
// (running, idle, freq scaling, ...). Fortunately all recent Intel processors
// have this feature, this is called "Invariant TSC" and support can be asserted
// using CPUID.
// Unfortunately getting the TSC's frequency is an adventure on itself. Intel
// provides multiple ways to achieve this, but none seem to be portable and in
// reality it depends on the processor's model. Additionally Qemu gets in our
// way by hiding some CPUID information and MSRs from the guest (even though we
// are using the host cpu model, ...). If all fails we can use the PIT to
// calibrate the TSC's frequency. This is the least precise method but it yields
// decent results, and it works in Qemu VMs.
//
// Here are the three methods to get the TSC's frequency:
//  1. Using CPUID.15H. This execution to CPUID will give enough information to
//  compute the frequency. Unfortunately, not all cpus implement CPUID.15H. The
//  precision using this method is high.
//  2. Using the MSR_PLATFORM_INFO (0xCE). This MSR gives the "Maximum Non-Turbo
//  Ratio". This ration can be used to compute the TSC's frequency. Using this
//  method precision is high.
//  3. Using the PIT. Precision is medium to poor but is usually sufficient.
// Upon calling init_tsc, each method will be tried (in the order above) to find
// the TSC's frequency.

#include <asm_macros.h>
#include <consts.h>

.intel_syntax   noprefix

.section .data
// The frequency of the TSC in Hz.
.global TSC_FREQ
TSC_FREQ:
.quad   0x0

// =============================================================================
// Read the current value of the TSC.
// @return (RAX): The value of TSC.
// =============================================================================
ASM_FUNC_DEF64(read_tsc):
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    ret

// =============================================================================
// Calibrate the TSC.
// =============================================================================
ASM_FUNC_DEF64(init_tsc):
    push    rbp
    mov     rbp, rsp

    // First detect for the invariant TSC extension, this is indicated by
    // CPUID.80000007H:EDX[8]. This feature is required for this project.
    mov     eax, 0x80000007
    cpuid
    test    edx, (1 << 8)
    jnz     0f
    PANIC64("init_tsc: Processor does not support Invariant TSC extension")
0:

    // Try each method to get the TSC's frequency.
    // Using CPUID:
    call    _calibrate_tsc_cpuid
    test    rax, rax
    jnz     ._init_tsc_freq_found
    WARN64("init_tsc: _calibrate_tsc_cpuid failed\n")

    // Using the MSR:
    call    _calibrate_tsc_msr
    test    rax, rax
    jnz     ._init_tsc_freq_found
    WARN64("init_tsc: _calibrate_tsc_msr failed\n")

    // If nothing works, then we use PIT.
    INFO64("init_tsc: Fallback to PIT calibration\n")
    call    _calibrate_tsc_pit

._init_tsc_freq_found:
    mov     [TSC_FREQ], rax

    push    rax
    INFO64("TSC_FREQ = %q Hz\n")
    pop     rax

    leave
    ret

// =============================================================================
// Calibrate the TSC's frequency using the "CPUID method":
// According to the CPUID documentation, the TSC's frequency can be computed
// using the following information from the Time Stamp Counter and Nominal Core
// Crystal Clock Information Leaf (15H):
//  - EAX Bits 31 - 00: An unsigned integer which is the denominator of the
//  TSC/”core crystal clock” ratio.
//  - EBX Bits 31 - 00: An unsigned integer which is the numerator of the
//  TSC/”core crystal clock” ratio.
//  - ECX Bits 31 - 00: An unsigned integer which is the nominal frequency of
//  the core crystal clock in Hz.
// The TSC's frequency is therefore:
//  Ftsc = ECX * EBX / EAX
//
// Unfortunately, this is not implemented by every CPU. If EBX or ECX is 0 then
// this is not supported.
// Another issue is if the max EAX value accepted by CPUID is < 0x15.
//
// @return (RAX): On success the computed frequency of the TSC in hz, 0
// otherwise.
// =============================================================================
ASM_FUNC_DEF64(_calibrate_tsc_cpuid):
    push    rbp
    mov     rbp, rsp

    // Check that the max input value of CPUID is >= 0x15.
    xor     eax, eax
    cpuid
    cmp     eax, 0x15
    jae     0f

    // The processor does not support EAX >= 0x15 with cpuid. Give up.
    WARN64("_calibrate_tsc_cpuid: CPU does not support 0x15 CPUID leaf\n")
    xor     rax, rax
    leave
    ret

0:
    // We can give EAX = 0x15 as input to CPUID. Do this and look if the output
    // is complete to compute the frequency.
    mov     eax, 0x15
    cpuid

    push    rcx
    push    rbx
    push    rax
    DEBUG64("CPUID.15H: RAX = %q RBX = %q RCX = %q\n")
    pop     rax
    pop     rbx
    pop     rcx

    test    rbx, rbx
    jnz     0f
    WARN64("_calibrate_tsc_cpuid: CPUID.15H does not enumerate numerator\n")
    xor     rax, rax
    leave
    ret

0:
    test    rcx, rcx
    jnz     0f
    WARN64("_calibrate_tsc_cpuid: CPUID.15H does not enumerate clock freq\n")
    xor     rax, rax
    leave
    ret

0:
    // We have all the necessary information to compute the frequency equation.
    // Swap EAX and EBX so that we can do the MUL before the DIV.
    // Note: The equation becomes: Ftsc = ECX * EAX / EBX
    xchg    rax, rbx
    mul     rcx
    // RAX = Freq.
    div     rbx

    leave
    ret


// =============================================================================
// Compute the TSC's frequency using the MSR_PLATFORM_INFO.
// =============================================================================
ASM_FUNC_DEF64(_calibrate_tsc_msr):
    push    rbp
    mov     rbp, rsp
    
    // Using the MSR, computing the TSC's frequency is easy, we simply need to
    // read MSR_PLATFORM_INFO. Bits[15:8] gives the ratio, multiplying this
    // ratio by 100MHz (or 133.33MHz) gives the TSC's frequency.
.set MSR_PLATFORM_INFO, 0xCE
    mov     ecx, MSR_PLATFORM_INFO
    rdmsr
    shr     eax, 8
    movsx   rax, al

    // On micro-architecture different than Nephalem, we need to multiply the
    // ratio by 100MHz to obtain the TSC's frequency. With Nephalem this should
    // be 133.33MHz, however those are ancient micro-architecture and therefore
    // we won't care about them.
    imul    rax, rax, 100000000

    leave
    ret

// =============================================================================
// Compute the TSC's frequency using PIT calibration. This method is sure to be
// successful, albeit with potentially reduced precision.
// @return (RAX): On success the computed frequency of the TSC in hz, 0
// otherwise.
// =============================================================================
ASM_FUNC_DEF64(_calibrate_tsc_pit):
    push    rbp
    mov     rbp, rsp
    lea     rdi, [read_tsc]
    call    calibrate_counter_with_pit
    leave
    ret
