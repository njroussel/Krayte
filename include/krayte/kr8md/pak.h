
#pragma once

#include <stddef.h>
#include <krayte/kr8md/defaults.h>
#include <krayte/kr8md/intrinsic_types.h>

namespace kr8md
{
    template <typename T, size_t W = max_supported_width_for_type<T>()>
    struct Pak
    {

        enum
        {
            width = W,
        };

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
            for (size_t i = 0; i < W; ++i)
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
} // namespace kr8md