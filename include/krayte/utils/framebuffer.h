#include <stdint.h>

namespace kr8 {
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
