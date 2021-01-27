#pragma once

#include <krayte/kr8md/pak.h>
#include <krayte/kr8md/defaults.h>

namespace kr8md
{
    template <typename PAK>
    KR8MD_INLINE PAK load(void const *const addr)
    {
        //using pak_t = pak::value_t;
        size_t pak_width = PAK::width;

        PAK pak;

        std::cout << "pak_width: " << pak_width << std::endl;

        /*
        for (size_t i = 0; i < 4; ++i)
        {
            pak.data[i] = *addr[i];
        }
        */

        return pak;
    }

#ifdef __SSE4_2__
    template <>
    KR8MD_INLINE const pfloat4 load(void const *const addr)
    {
        return _mm_load_ps(static_cast<const float *>(addr));
    }
#endif

#ifdef __AVX__
    template <>
    KR8MD_INLINE const pfloat8 load(void const *const addr)
    {
        return _mm256_load_ps(static_cast<const float *>(addr));
    }
#endif
} // namespace kr8md