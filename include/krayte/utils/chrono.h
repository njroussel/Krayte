// Time measuring functions.
#pragma once
#include <stdint.h>

#ifdef KRAYTE_ALLOW_STD
#include <chrono>
#endif

// Read the current value of the Time-Stamp counter.
// @return: Current value of TSC on this cpu.
extern "C" uint64_t readTsc(void);

// Get the frequency of the Time-Stamp counter.
// @return: Frequency of this cpu's TSC in Hz.
extern "C" uint64_t getTscFreq(void);

namespace kr8 {
class Chrono {
    public:
#ifdef KRAYTE_ALLOW_STD
    // Opaque type used to represent a point in time.
    using TimePoint = decltype(std::chrono::high_resolution_clock::now());

    // Get a TimePoint for the current instant.
    // @return: An opaque time point.
    static TimePoint now() {
        return std::chrono::high_resolution_clock::now();
    }

    // Compute the duration in nanoseconds between two time points.
    // @param start: The start of the interval.
    // @param end: The start of the interval.
    // @return: The number of nanoseconds between start and end.
    static uint64_t duration(TimePoint const& start, TimePoint const& end) {
        auto const d = end - start;
        return std::chrono::duration_cast<std::chrono::nanoseconds>(d).count();
    }
#else
    // Opaque type used to represent a point in time. On baremetal setup this is
    // simply the value of the TSC at that point.
    using TimePoint = uint64_t;

    // Get a TimePoint for the current instant.
    // @return: An opaque time point.
    static TimePoint now() {
        return readTsc();
    }

    // Compute the duration in nanoseconds between two time points.
    // @param start: The start of the interval.
    // @param end: The start of the interval.
    // @return: The number of nanoseconds between start and end.
    static uint64_t duration(TimePoint const& start, TimePoint const& end) {
        uint64_t const diff = end - start;
        uint64_t const tscFreq = getTscFreq();
        return 1000000000 * diff / tscFreq;
    }
#endif
};
}
