#pragma once
#include <immintrin.h>

namespace kr8md
{

    template <typename T, size_t N>
    struct pak
    {
        T data[N];
    };

    template <typename T, size_t N>
    pak<T, N> add(pak<T, N> a, pak<T, N> b)
    {
        pak<T, N> out;
        for (size_t i = 0; i < N; i++)
        {
            out.data[i] = a.data[i] + b.data[i];
        }

        return out;
    }

} // namespace kr8md