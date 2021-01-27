#include <stdint.h>
#include <random>
#include <chrono>
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
    using pfloat8 = kr8md::Pak<float, 8>;

    std::cout << "max kr8md width: " << KR8MD_MAX_VEC_REGISTER_SIZE << std::endl;
    std::cout << "sizeof(pfloat): " << sizeof(pfloat) << std::endl;
    std::cout << std::endl;

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> distrib(1, 100);

    size_t n = 80000;
    float vec_a[n];
    float vec_b[n];
    float vec_c[n];

    for (int i = 0; i < n; ++i)
    {
        vec_a[i] = distrib(gen);
    }
    for (int i = 0; i < n; ++i)
    {
        vec_b[i] = distrib(gen);
    }

    auto begin_normal = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < n; ++i)
    {
        vec_c[i] = vec_a[i] * vec_b[i];
    }
    auto end_normal = std::chrono::high_resolution_clock::now();
    auto duration_normal = std::chrono::duration_cast<std::chrono::nanoseconds>(end_normal - begin_normal).count();

    float out_pvec_c[n];
    auto begin_pak = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < n; i += pfloat::width)
    {
        pfloat pvec_a = kr8md::load(&vec_a[i]);
        pfloat pvec_b = kr8md::load(&vec_b[i]);

        pfloat pvec_c = pvec_a * pvec_b;

        kr8md::store(&out_pvec_c[i], pvec_c.intrinsic);
    }
    auto end_pak = std::chrono::high_resolution_clock::now();
    auto duration_pak = std::chrono::duration_cast<std::chrono::nanoseconds>(end_pak - begin_pak).count();

    // -------
    std::cout << "Multiplication of two vectors (size " << n << "): " << duration_normal << std::endl;
    std::cout << "Duration normal: " << duration_normal << std::endl;
    std::cout << "Duration pak: " << duration_pak << std::endl;
    std::cout << std::endl;

    std::cout << "Visual inspection of correctness: " << std::endl;
    for (int i = 0; i < 20; ++i)
    {
        std::cout << vec_c[i] << " ";
    }
    std::cout << std::endl;
    for (int i = 0; i < 20; ++i)
    {
        std::cout << out_pvec_c[i] << " ";
    }
    std::cout << std::endl;

    return 0;
}