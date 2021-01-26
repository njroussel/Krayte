#include <stdint.h>
#include <iostream>
#include <krayte/kr8md.h>

int main(void)
{
    using pfloat4 = kr8md::pak<float, 4>;

    pfloat4 vec_a = {1.f,
                     2.f,
                     3.f,
                     4.f};

    pfloat4 vec_b = {1.f,
                     2.f,
                     3.f,
                     4.f};

    pfloat4 vec_c = kr8md::add(vec_a, vec_b);

    for (size_t i = 0; i < 4; i++)
    {
        std::cout << vec_c.data[i] << std::endl;
    }

    return 0;
}