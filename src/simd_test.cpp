#include <stdint.h>
#include <iostream>
#include <krayte/kr8md/kr8md.h>
#include <krayte/kr8md/kr8md_std_helpers.h>

int main(void)
{
    float arr_a[8] = {1.f,
                      2.f,
                      3.f,
                      4.f,
                      1.f,
                      2.f,
                      3.f,
                      4.f};

    float arr_b[8] = {1.f,
                      2.f,
                      3.f,
                      4.f,
                      1.f,
                      2.f,
                      3.f,
                      4.f};

    using pfloat = kr8md::Pak<float>;

    pfloat vec_tmp;
    std::cout << "max kr8md width: " << MAX_KR8MD_WIDTH << std::endl;
    std::cout << "sizeof(vec_tmp): " << sizeof(vec_tmp) << std::endl;

    pfloat vec_a(arr_a);
    pfloat vec_b(arr_b);

    pfloat vec_c = vec_a + vec_b;

    std::cout << std::endl;
    std::cout << "c: " << vec_c << std::endl;

    return 0;
}