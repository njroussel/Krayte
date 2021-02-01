
#pragma once

#include <stddef.h>
#include <krayte/kr8md/defaults.h>
#include <krayte/kr8md/intrinsic_types.h>
#include <krayte/kr8md/operators/store.h>

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

        Pak(const intrinsic_t intrinsinc_) : intrinsic(intrinsinc_) {}

        Pak(T const *const arr)
        {
            for (size_t i = 0; i < W; ++i)
            {
                data[i] = arr[i];
            }
        }

        Pak(const T val)
        {
            for (size_t i = 0; i < W; ++i)
            {
                data[i] = val;
            }
        }

        KR8MD_INLINE operator const intrinsic_t &() const
        {
            return intrinsic;
        }

        KR8MD_INLINE operator intrinsic_t &()
        {
            return intrinsic;
        }
    };

    template <typename TPak>
    struct MaskedPak
    {
        using intrinsic_t = typename TPak::intrinsic_t;

        TPak &pak;
        const TPak &mask;

        MaskedPak() {}

        MaskedPak(TPak &pak_, const TPak &mask_) : pak(pak_), mask(mask_) {}

        KR8MD_INLINE void operator=(const TPak &rhs)
        {
            pak = select(mask, pak, rhs);
        }
    };

    template <typename TPak>
    KR8MD_INLINE MaskedPak<TPak> masked(TPak &pak, const TPak &mask)
    {
        return MaskedPak<TPak>(pak, mask);
    }

    using pfloat = Pak<float>;
    using pdouble = Pak<double>;
    using pint32 = Pak<int32_t>;

    template <size_t W>
    using pdoublen = Pak<double, W>;
    template <size_t W>
    using pfloatn = Pak<float, W>;
    template <size_t W>
    using pint32n = Pak<int32_t, W>;
    template <size_t W>
    using pbooln = Pak<bool, W>;

    using pfloat_4 = pfloatn<4>;
    using pint32_4 = pint32n<4>;
    using pdouble_4 = pdoublen<4>;

    using pfloat_8 = pfloatn<8>;
    using pint32_8 = pint32n<8>;
} // namespace kr8md