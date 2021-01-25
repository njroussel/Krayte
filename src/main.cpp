// Simple stub file to test the project. For now this simply outputs Hello World
// in the VGA buffer.
#include <stdint.h>

namespace Kr8 {
// Abstraction for the VGA buffer residing in memory at address 0xB8000.
class VGABuffer {
    public:
        // Create an instance of VGABuffer.
        // @param startCursor: The starting position of the cursor.
        VGABuffer(uint16_t const startCursor) : cursor(startCursor) {}

        // Print out a character in the VGA buffer.
        // @param c: The char to be printed.
        void putc(char const c) {
            if (c == '\n') {
                newLine();
            } else {
                bufAddr[cursor] = (7 << 8) | c;
                cursor++;
            }
        } 

        // Print out a string in the VGA buffer.
        // @param str: The string to be printed.
        void operator<<(char const * cstr) {
            while (*cstr) {
                putc(*(cstr++));
            }
        }

    private:
        // Address of the memory-mapped VGA buffer.
        uint16_t * const bufAddr = reinterpret_cast<uint16_t*>(0xB8000);
        // Width of the VGA buffer in number of characters.
        uint8_t const bufWidth = 80;
        // Height of the VGA buffer in number of characters.
        uint8_t const bufHeight = 25;
        // Current position of the cursor.
        uint16_t cursor;

        // Handle a new line character.
        void newLine(void) {
            if (cursor / bufWidth == bufHeight - 1) {
                // We are at the bottom of the buffer, scroll up once and put
                // the cursor back to the beginning of the last line.
                scrollUp();
                cursor = bufWidth * (bufHeight - 1);
            } else {
                cursor += bufWidth;
            }
        }

        // Scroll up the lines of the buffer once.
        void scrollUp(void) {
            uint16_t const * src = bufAddr + bufWidth;
            uint16_t * dst = bufAddr;
            for (uint16_t i = 0; i < bufWidth * bufHeight; ++i) {
                *dst = *src;
                dst++;
                src++;
            }
        }
};
}

// The entry point name is expected to be _start. The extern "C" is here to
// avoid the compiler mangling the name and ld complaining.
// @param startCursor: The current position of the cursor. This is passed by the
// boostrap so that the application does not overwrite previous log messages.
extern "C" void _start(uint16_t const startCursor) {
    Kr8::VGABuffer buf(startCursor);
    buf << "Hello world from a 64-bit C++ process!\n";
}
