// Simple stub file to test the project. For now this simply outputs Hello World
// in the VGA buffer.
#include <stdint.h>

// Read the current value of the Time-Stamp counter.
// @return: Current value of TSC on this cpu.
extern "C" uint64_t readTsc(void);

// Get the frequency of the Time-Stamp counter.
// @return: Frequency of this cpu's TSC in Hz.
extern "C" uint64_t getTscFreq(void);

// Print out a NUL-terminated string to the serial console.
// @param msg: The NUL-terminated string to print out.
extern "C" void logSerial(char const * const msg);

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

// Information on the VESA frame buffer.
struct FrameBufferInfo {
    // Number of bytes per-line. Note that this is not necessarily "width *
    // bitsPerPixel / 8" since there might be padding between lines.
    uint16_t const bytesPerLine;
    // The width in pixels.
    uint16_t const width;
    // The height in pixels.
    uint16_t const height;
    // Reserved, do not touch.
    uint8_t reserved[3];
    // The number of bits per pixels.
    uint8_t const bitsPerPixel;
    // Reserved, do not touch.
    uint8_t reserved2[5];
    // The size of the red mask in number of bits.
    uint8_t const redMaskSize;
    // The position of the red mask in number of bits from bit 0.
    uint8_t const redMaskPos;
    // The size of the green mask in number of bits.
    uint8_t const greenMaskSize;
    // The position of the green mask in number of bits from bit 0.
    uint8_t const greenMaskPos;
    // The size of the blue mask in number of bits.
    uint8_t const blueMaskSize;
    // The position of the green mask in number of bits from bit 0.
    uint8_t const blueMaskPos;
    // Reserved, do not touch.
    uint8_t reserved3[3];
    // The address of the framebuffer. This is under 4GiB hence the uint32_t.
    uint32_t const framebufferAddr;
} __attribute__((packed));

// Abstraction of the VESA framebuffer.
class FrameBuffer {
    public:
    // Create an instance of FrameBuffer from a FrameBufferInfo.
    // @param fbInfo: The FrameBufferInfo.
    FrameBuffer(struct FrameBufferInfo const * const fbInfo) : fbInfo(fbInfo) {}

    // Color class used by the frame buffer.
    class Color {
        public:
        // Create a color instance.
        // @param r: 8-bit Red component.
        // @param g: 8-bit Green component.
        // @param b: 8-bit Blue component.
        Color(uint8_t const r, uint8_t const g, uint8_t const b) : r(r), g(g), b(b) {}

        // Convert a Color to a uint32_t.
        // @param fbInfo: Information on the framebuffer. This is used to know
        // the position and size of the R, G and B masks.
        // @return: A uint32_t describing this color as understood by the
        // framebuffer.
        uint32_t toUint32(struct FrameBufferInfo const * const fbInfo) const {
            return ((r & ((1<<fbInfo->redMaskSize)-1)) << fbInfo->redMaskPos) |
            ((g & ((1<<fbInfo->greenMaskSize)-1)) << fbInfo->greenMaskPos) |
            ((b & ((1<<fbInfo->blueMaskSize)-1)) << fbInfo->blueMaskPos);
        }

        private:
        uint8_t const r;
        uint8_t const g;
        uint8_t const b;
    };

    // Position class used to describe a pixel position on the framebuffer.
    template<typename T>
    class Pos {
        public:
        // Create a positon from two coordinates of type T.
        Pos(T const x, T const y) : x(x), y(y) {}

        // Get the line index of the position. This version is specialized for
        // types that can be casted to uint16_t.
        // @param fbInfo: The information on the framebuffer where the position
        // will be used.
        // @return: The index of the line of the position.
        uint16_t line(struct FrameBufferInfo const * const fbInfo) const {
            return (uint16_t)y;
        }

        // Get the column index of the position. This version is specialized for
        // types that can be casted to uint16_t.
        // @param fbInfo: The information on the framebuffer where the position
        // will be used.
        // @return: The index of the column of the position.
        uint16_t col(struct FrameBufferInfo const * const fbInfo) const {
            return (uint16_t)x;
        }

        private:
        T const x;
        T const y;
    };

    // Draw a pixel on the framebuffer.
    // @param pos: The position of the pixel.
    // @param color: The color of the pixel.
    template<typename T>
    void putPixel(Pos<T> const& pos, Color const& color) {
        uint16_t const x = pos.col(fbInfo);
        uint16_t const y = pos.line(fbInfo);
        uint8_t * const fb = ((uint8_t*)(uint64_t)fbInfo->framebufferAddr) +
            (y * fbInfo->bytesPerLine) + x * (fbInfo->bitsPerPixel / 8);
        *(uint32_t*)fb = color.toUint32(fbInfo);
    }

    private:
    struct FrameBufferInfo const * const fbInfo;
};

// Specialization for the line method for Pos<float>. The y is between 0 and 1.
template<>
uint16_t FrameBuffer::Pos<float>::line(struct FrameBufferInfo const * const fbInfo) const {
    return (uint16_t)(y * fbInfo->height);
}

// Specialization for the col method for Pos<float>. The x is between 0 and 1.
template<>
uint16_t FrameBuffer::Pos<float>::col(struct FrameBufferInfo const * const fbInfo) const {
    return (uint16_t)(x * fbInfo->width);
}

}

// The entry point name is expected to be _start. The extern "C" is here to
// avoid the compiler mangling the name and ld complaining.
// @param fbInfo: FrameBufferInfo struct passed by the bootstrap in order to
// understand how to interact with the VESA framebuffer.
extern "C" void _start(Kr8::FrameBufferInfo const * const fbInfo) {
    Kr8::FrameBuffer fb(fbInfo);
    fb.putPixel(Kr8::FrameBuffer::Pos<float>(.33f, .33f), Kr8::FrameBuffer::Color(0, 255, 0));
    fb.putPixel(Kr8::FrameBuffer::Pos<float>(.66f, .33f), Kr8::FrameBuffer::Color(0, 255, 0));
    fb.putPixel(Kr8::FrameBuffer::Pos<float>(.33f, .66f), Kr8::FrameBuffer::Color(0, 255, 0));
    fb.putPixel(Kr8::FrameBuffer::Pos<float>(.66f, .66f), Kr8::FrameBuffer::Color(0, 255, 0));
    for (uint16_t i = 0; i < fbInfo->height; ++i) {
        uint16_t const x = fbInfo->width / 2;
        fb.putPixel(Kr8::FrameBuffer::Pos<uint16_t>(x, i), Kr8::FrameBuffer::Color(255, 255, 255));
    }
    logSerial("Hello world in the serial console from the application\n");
}
