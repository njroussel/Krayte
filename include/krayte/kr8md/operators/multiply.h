#pragma once

#include <krayte/kr8md/pak.h>
#include <krayte/kr8md/defaults.h>

namespace kr8md
{
#ifdef __SSE4_2__
    KR8MD_INLINE pfloat4 operator*(const pfloat4 &a, const pfloat4 &b)
    {
        return _mm_mul_ps(a, b);
    }
#endif

#ifdef __AVX2__
    KR8MD_INLINE pfloat8 operator*(const pfloat8 &a, const pfloat8 &b)
    {
        return _mm256_mul_ps(a, b);
    }
#endif
} // namespace kr8md