#pragma once
#include <stdint.h>
#include <type_traits>

#ifdef KRAYTE_ALLOW_STD
// If std is allowed Ostream will fallback to std::cout hence we need to include
// iostream.
#include <iostream>
#endif

// Print out a NUL-terminated string to the serial console.
// @param msg: The NUL-terminated string to print out.
extern "C" void logSerial(char const * const msg);

namespace kr8 {
// Wrapper for serial console output.
class Ostream {
    public:
        // Generic printing operator.
        // @param value: The value to be printed.
        // @return: A reference on the current Ostream. This is used to chain
        // multiple operator<<s together.
        template<typename T>
        Ostream& operator<<(T const value) {
#ifdef KRAYTE_ALLOW_STD
            std::cout << value;
#else
            if constexpr (std::is_integral<T>::value) {
                outputInteger(value);
            } else if constexpr (std::is_floating_point<T>::value) {
                outputFloatingPoint(value);
            }
#endif
            return *this;
        }

    private:
        // Print an integer in serial output.
        // @param integer: The value of the integer.
        template<typename T>
        void outputInteger(T const& integer) {
            T value = integer;
            if (std::is_signed<T>() && value < 0) {
                value = -value;
            }

            // 64-bit {u}ints produce 20 digits max in base 10.
            char buf[22] = {'0'};
            buf[21] = '\0';

            uint8_t i = 0;
            for (; value; ++i, value /= 10) {
                char const digit = '0' + (value % 10);
                buf[20 - i] = digit;
            }

            char const * const strValue = buf + 20 - i + 1;
            *this << strValue;
        }

        // Print a floating point in the serial output.
        // @param fp: The value of the floating point.
        template<typename T>
        void outputFloatingPoint(T const& fp) {
            // TODO
        }
};

#ifndef KRAYTE_ALLOW_STD
// Specialization for NUL-terminated char strings.
template<>
Ostream& Ostream::operator<<<char const*>(char const * const str) {
    logSerial(str);
    return *this;
}

// Specialization for single characters.
template<>
Ostream& Ostream::operator<<<char>(char const c) {
    char buf[2] = {c, '\0'};
    return (*this << buf);
}
#endif

// Singleton instance to print in serial console.
Ostream sout;
char const * const endl = "\n";
}
