#pragma once

#include <krayte/kr8md/pak.h>
#include <krayte/kr8md/defaults.h>

namespace kr8md
{
#ifdef __SSE4_2__
    KR8MD_INLINE const pfloat4 operator==(const pfloat4 &a, const pfloat4 &b)
    {
        return _mm_cmpeq_ps(a.intrinsic, b.intrinsic);
    }
#endif

#ifdef __AVX2__
    KR8MD_INLINE const pfloat8 operator==(const pfloat8 &a, const pfloat8 &b)
    {
        return _mm256_cmp_ps(a.intrinsic, b.intrinsic, 0);
    }
#endif
} // namespace kr8md
