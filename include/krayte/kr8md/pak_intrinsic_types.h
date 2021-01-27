
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

#if defined(__AVX2__) || defined(__AVX__)
    template <>
    struct pak_intrinsic_type<float, 8>
    {
        using type = __m256;
    };

    template <>
    struct pak_intrinsic_type<int, 8>
    {
        using type = __m256i;
    };
#endif
} // namespace kr8md
