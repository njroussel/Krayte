#include <stdint.h>
#include <iostream>
#include <krayte/kr8md.h>

namespace kr8md
{
    template <typename T, size_t W>
    std::ostream &operator<<(std::ostream &os, const Pak<T, W> &pak)
    {
        os << "{";
        for (size_t i = 0; i < W; i++)
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

int main(void)
{
    using pfloat4 = kr8md::Pak<float, 4>;

    std::cout << "sizeof pfloat4: " << sizeof(pfloat4) << std::endl;
    std::cout << "sizeof __m256: " << sizeof(__m256) << std::endl;

    float arr_a[4] = {1.f,
                      2.f,
                      3.f,
                      4.f};

    float arr_b[4] = {2.f,
                      3.f,
                      4.f,
                      5.f};

    pfloat4 vec_a(arr_a);
    pfloat4 vec_b(arr_b);

    std::cout << std::endl;
    pfloat4 vec_c1 = kr8md::add(vec_a, vec_b);
    pfloat4 vec_c2 = vec_a + vec_b;

    std::cout << "c1: " << vec_c1 << std::endl;
    std::cout << "c2: " << vec_c2 << std::endl;

    return 0;
}