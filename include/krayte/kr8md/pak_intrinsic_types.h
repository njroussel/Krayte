
#if defined(__AVX2__) || defined(__AVX__) || defined(__SSE4_2__)
#include <immintrin.h>
#endif

namespace kr8md
{

    template <typename T, int W>
    struct pak_udef_intrinsic_type
    {
        using type = T *;
    };

    template <typename T, size_t W>
    struct pak_intrinsic_type
    {
        using type = pak_udef_intrinsic_type<T, W>;
    };

#if defined(__SSE4_2__)
    template <>
    struct pak_intrinsic_type<float, 4>
    {
        using type = __m128;
    };

    template <>
    struct pak_intrinsic_type<int32_t, 4>
    {
        using type = __m128i;
    };

    template <>
    struct pak_intrinsic_type<int64_t, 2>
    {
        using type = __m128i;
    };
#endif

#if defined(__AVX2__) || defined(__AVX__)
    template <>
    struct pak_intrinsic_type<float, 8>
    {
        using type = __m256;
    };

    template <>
    struct pak_intrinsic_type<int32_t, 8>
    {
        using type = __m256i;
    };
#endif
} // namespace kr8md
