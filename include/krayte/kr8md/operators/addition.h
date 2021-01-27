#pragma once

#include <krayte/kr8md/pak.h>
#include <krayte/kr8md/defaults.h>

namespace kr8md
{
    KR8MD_INLINE const pfloat4 operator+(const pfloat4 &a, const pfloat4 &b)
    {
#ifdef __SSE4_2__
        return _mm_add_ps(a.intrinsic, b.intrinsic);
#else
        pfloat8 out;
        for (size_t i = 0; i < 4; i++)
        {
            out.data[i] = a.data[i] + b.data[i];
        }

        return out;
#endif
    }

    KR8MD_INLINE const pfloat8 operator+(const pfloat8 &a, const pfloat8 &b)
    {
#ifdef __AVX2__
        return _mm256_add_ps(a.intrinsic, b.intrinsic);
#else
        pfloat8 out;
        for (size_t i = 0; i < 8; i++)
        {
            out.data[i] = a.data[i] + b.data[i];
        }

        return out;
#endif
    }
} // namespace kr8md