#include <stdint.h>
#include <iostream>
#include <krayte/kr8md.h>

int main(void)
{
    using pfloat4 = kr8md::Pak<float, 4>;

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

    std::cout << "c1" << std::endl;
    for (size_t i = 0; i < 4; i++)
    {
        std::cout << vec_c1.data[i] << std::endl;
    }
    std::cout << std::endl;

    std::cout << "c2" << std::endl;
    for (size_t i = 0; i < 4; i++)
    {
        std::cout << vec_c2.data[i] << std::endl;
    }

    return 0;
}