
#pragma once

#include <krayte/kr8md/pak.h>

namespace kr8md
{
#ifdef __SSE4_2__
    template <>
    KR8MD_INLINE pfloat_8::Pak(const float &value) : intrinsic(_mm256_set1_ps(value)){};
#endif

#ifdef __AVX2__
    template <>
    KR8MD_INLINE pfloat_8::Pak(const float &value) : intrinsic(_mm256_set1_ps(value)){};
#endif
} // namespace kr8md