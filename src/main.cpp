#include <stdint.h>
#include <type_traits>

#include <krayte/utils/framebuffer.h>
#include <krayte/utils/ostream.h>

// Read the current value of the Time-Stamp counter.
// @return: Current value of TSC on this cpu.
extern "C" uint64_t readTsc(void);

// Get the frequency of the Time-Stamp counter.
// @return: Frequency of this cpu's TSC in Hz.
extern "C" uint64_t getTscFreq(void);

// Main entry point of Krayte.
// @param fbInfo: FrameBufferInfo struct passed by the bootstrap in order to
// understand how to interact with the VESA framebuffer. This argument is only
// available for RELEASE builds.
extern "C" int main(kr8::FrameBufferInfo const * const fbInfo) {
    kr8::sout << "Hello world in the serial console using syscall" << kr8::endl;
    return 0;
}
