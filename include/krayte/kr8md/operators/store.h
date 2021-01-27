#pragma once

#include <krayte/kr8md/pak.h>

namespace kr8md
{
#if defined(__AVX__)
    KR8MD_INLINE const void store(float *const addr, const __m256 a)
    {
        return _mm256_store_ps(addr, a);
    }
#elif defined(__SSE4_2__)
    KR8MD_INLINE const void store(float *const addr, const __m128 a)
    {
        return _mm_store_ps(addr, a);
    }
#endif
} // namespace kr8md