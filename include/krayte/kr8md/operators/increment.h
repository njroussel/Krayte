#pragma once

#include <krayte/kr8md/pak.h>
#include <krayte/kr8md/defaults.h>

namespace kr8md
{
#ifdef __SSE4_2__
    template <>
    KR8MD_INLINE pfloat_4 &pfloat_4::operator++()
    {
        this->intrinsic = _mm_add_ps(*this, _mm_set1_ps(1));
        return *this;
    }

    template <>
    KR8MD_INLINE pfloat_4 pfloat_4::operator++(int)
    {
        pfloat_4 tmp = *this;
        ++*this;
        return tmp;
    }
#endif

#ifdef __AVX2__
    template <>
    KR8MD_INLINE pfloat_8 &pfloat_8::operator++()
    {
        this->intrinsic = _mm256_add_ps(*this, _mm256_set1_ps(1));
        return *this;
    }

    template <>
    KR8MD_INLINE pfloat_8 pfloat_8::operator++(int)
    {
        pfloat_8 tmp = *this;
        ++*this;
        return tmp;
    }
#endif
} // namespace kr8md