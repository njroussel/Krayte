#pragma once

#include <krayte/kr8md/pak.h>
#include <krayte/kr8md/defaults.h>

namespace kr8md
{
#ifdef __SSE4_2__
    KR8MD_INLINE pfloat4 select(const pfloat4 &mask, const pfloat4 &a, const pfloat4 &b)
    {
        return _mm_blendv_ps(a, b, mask);
    }
#endif

#ifdef __AVX2__
    KR8MD_INLINE pfloat8 select(const pfloat8 &mask, const pfloat8 &a, const pfloat8 &b)
    {
        return _mm256_blendv_ps(a, b, mask);
    }
#endif
} // namespace kr8md
