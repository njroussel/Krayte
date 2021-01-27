#pragma once

#include <krayte/kr8md/intrinsic_types.h>

#if defined(__AVX2__)
#define MAX_KR8MD_WIDTH 8
#elif defined(__SSE4_2__)
#define MAX_KR8MD_WIDTH 4
#else
#define MAX_KR8MD_WIDTH 1
#endif

template <typename T>
constexpr size_t max_supported_width_for_type()
{
#if defined(__AVX2__)
    if (std::is_same<int32_t, T>::value)
    {
        return 4;
    }
#endif

    return MAX_KR8MD_WIDTH;
}

namespace kr8md
{

    template <typename T, size_t W = max_supported_width_for_type<T>()>
    struct Pak
    {

        using intrinsic_t = typename intrinsic_t<T, W>::type;

        union
        {
            T data[W];
            intrinsic_t intrinsic;
        };

        Pak() {}

        Pak(intrinsic_t intrinsinc_) : intrinsic(intrinsinc_) {}

        Pak(T *arr)
        {
            for (size_t i = 0; i < W; i++)
            {
                data[i] = arr[i];
            }
        }
    };

    template <size_t W>
    using pdoublen = Pak<double, W>;
    template <size_t W>
    using pfloatn = Pak<float, W>;
    template <size_t W>
    using pintn = Pak<int, W>;

    using pfloat4 = pfloatn<4>;
    using pint4 = pintn<4>;
    using pdouble4 = pdoublen<4>;

    using pfloat8 = pfloatn<8>;

    inline __attribute__((always_inline)) const pfloat8 operator+(const pfloat8 &a, const pfloat8 &b)
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