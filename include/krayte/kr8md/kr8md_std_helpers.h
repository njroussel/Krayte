#pragma once

#include <krayte/kr8md/kr8md.h>
#include <krayte/utils/ostream.h>

namespace kr8md
{
    template <typename T, size_t W>
    kr8::Ostream &operator<<(kr8::Ostream &os, const Pak<T, W> &pak)
    {
        os << "{";
        for (size_t i = 0; i < W; ++i)
        {
            os << pak.data[i];
            if (i != W - 1)
            {
                os << ", ";
            }
        }
        os << "}";

        return os;
    }

} // namespace kr8md
