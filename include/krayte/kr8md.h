#pragma once
#include <immintrin.h>

namespace kr8md
{

    template <typename T, size_t W>
    struct Pak
    {
        union
        {
            T data[W];
            __m256 m256;
        };

        Pak() {}

        Pak(__m256 m256_) : m256(m256_) {}

        Pak(T *arr)
        {
            for (size_t i = 0; i < W; i++)
            {
                data[i] = arr[i];
            }
        }
    };

    template <typename T, size_t W>
    Pak<T, W> add(Pak<T, W> a, Pak<T, W> b)
    {
        Pak<T, W> out;
        for (size_t i = 0; i < W; i++)
        {
            out.data[i] = a.data[i] + b.data[i];
        }

        return out;
    }

    template <int W>
    using pfloatn = Pak<float, W>;
    using pfloat4 = pfloatn<4>;

    inline pfloat4 operator+(const pfloat4 &a, const pfloat4 &b)
    {
#ifdef __AVX2__
        __m256 c_ = _mm256_add_ps(a.m256, b.m256);
        return c_;
#else
        pfloat4 out;
        for (size_t i = 0; i < 4; i++)
        {
            out.data[i] = a.data[i] + b.data[i];
        }

        return out;
#endif
    }

} // namespace kr8md