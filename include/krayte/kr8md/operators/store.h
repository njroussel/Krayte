#pragma once

#include <krayte/kr8md/pak.h>

namespace kr8md
{
#if defined(__AVX2__)
    KR8MD_INLINE void store(float *const addr, const __m256 &a)
    {
        return _mm256_storeu_ps(addr, a);
    }
#elif defined(__SSE4_2__)
    KR8MD_INLINE void store(float *const addr, const __m128 &a)
    {
        return _mm_storeu_ps(addr, a);
    }
#endif

#if defined(__AVX2__)
    KR8MD_INLINE void store(float *const addr, const __m256 &a, const __m256i &mask)
    {
        return _mm256_maskstore_ps(addr, mask, a);
    }
#endif

#if defined(__AVX2__)
    KR8MD_INLINE void store_aligned(float *const addr, const __m256 &a)
    {
        return _mm256_store_ps(addr, a);
    }
#elif defined(__SSE4_2__)
    KR8MD_INLINE void store_aligned(float *const addr, const __m128 &a)
    {
        return _mm_store_ps(addr, a);
    }
#endif

#if defined(__AVX2__)
    KR8MD_INLINE void store_unaligned(float *const addr, const __m256 &a)
    {
        return _mm256_storeu_ps(addr, a);
    }
#elif defined(__SSE4_2__)
    KR8MD_INLINE void store_unaligned(float *const addr, const __m128 &a)
    {
        return _mm_storeu_ps(addr, a);
    }
#endif
} // namespace kr8md