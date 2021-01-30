#include <stdint.h>
#include <random>
#include <algorithm>
#include <chrono>
#include <iostream>

#include <krayte/kr8md/kr8md.h>
#include <krayte/kr8md/kr8md_std_helpers.h>

using namespace kr8md;

template <class T>
auto measure_runtime(T func)
{
    auto begin = std::chrono::high_resolution_clock::now();
    func();
    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - begin).count();
}

void loop_normal(size_t n, float const *const a, float const *const b, float *const dst)
{
    for (int i = 0; i < n; ++i)
    {
        dst[i] = a[i] * b[i];
        if (a[i] > b[i])
        {
            dst[i] = a[i] * a[i];
        }
    }
}

void loop_paked(size_t n, float const *const a, float const *const b, float *const dst)
{
    for (int i = 0; i < n; i += pfloat::width)
    {
        pfloat pa = load(&a[i]);
        pfloat pb = load(&b[i]);

        pfloat pc = pa * pb;

        pfloat condition = pa > pb;
        if (any(condition))
        {
            masked(pc, condition) = pa * pa;
        }

        store(&dst[i], pc);
    }
}

int main(void)
{

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> distribution(1, 100);

    size_t n = 80000000;
    assert(n % 8 == 0);

    float *vec_a = new float[n];
    float *vec_b = new float[n];

    std::transform(&vec_a[0], &vec_a[n], &vec_a[0], [&](auto _) { return distribution(gen); });
    std::transform(&vec_b[0], &vec_b[n], &vec_b[0], [&](auto _) { return distribution(gen); });

    float *vec_c = new float[n];
    float *pvec_c = new float[n];

    auto duration_normal = measure_runtime([&] { loop_normal(n, vec_a, vec_b, vec_c); });
    auto duration_pak = measure_runtime([&] { loop_paked(n, vec_a, vec_b, pvec_c); });

    bool correct = std::equal(&vec_c[0], &vec_c[n], &pvec_c[0]);

    // -------
    std::cout << "max kr8md width: " << KR8MD_MAX_VEC_REGISTER_SIZE << std::endl;
    std::cout << "sizeof(pfloat): " << sizeof(pfloat) << std::endl;
    std::cout << std::endl;

    std::cout << "Multiplication of two vectors (size " << n << "):" << std::endl;
    std::cout << "Duration normal: " << duration_normal << std::endl;
    std::cout << "Duration pak: " << duration_pak << std::endl;
    std::cout << "Correctness: " << correct << std::endl;

    return 0;
}