#include <stdint.h>
#include <algorithm>

#include <kr8md/kr8md.h>
#include <kr8md/kr8md_std_helpers.h>
#include <krayte/utils/ostream.h>
#include <krayte/utils/chrono.h>
#include <krayte/utils/string.h>

using namespace kr8md;

template <class T>
auto measure_runtime(T func)
{
    auto start = kr8::Chrono::now();
    func();
    auto end = kr8::Chrono::now();
    return kr8::Chrono::duration(start, end);
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

        pbool32 condition = pa > pb;
        if (any(condition)) // Early exit
        {
            masked(pc, condition) = pa * pa;
        }

        store(&dst[i], pc);
    }
}

uint mandelbrot_normal(float c_re, float c_im, unsigned int max_iterations)
{
    float z_re = c_re, z_im = c_im;
    uint i = 0;

    for (i = 0; i < max_iterations; ++i)
    {
        if (z_re * z_re + z_im * z_im > 4.)
            break;
        float new_re = z_re * z_re - z_im * z_im;
        float new_im = 2.f * z_re * z_im;
        z_re = c_re + new_re;
        z_im = c_im + new_im;
    }

    return i;
}

void mandelbrot_loop_normal(uint *dst, int width = 1080, int height = 720,
                            float cxmin = -2, float cxmax = 1, float cymin = -1, float cymax = 1,
                            unsigned int max_iterations = 256)
{
    float dx = (cxmax - cxmin) / width;
    float dy = (cymax - cymin) / height;

    for (size_t i = 0; i < height; ++i)
    {
        for (size_t j = 0; j < width; ++j)
        {
            float y = cymin + i * dy;
            float x = cxmin + j * dx;

            size_t index = i * width + j;
            dst[index] = mandelbrot_normal(x, y, max_iterations);
        }
    }
}

puint32 mandelbrot_pak(pfloat &c_re, pfloat &c_im, unsigned int max_iterations)
{
    pfloat z_re = c_re, z_im = c_im;
    puint32 i{0u};
    puint32 pmax_iterations{max_iterations};
    pbool32 active{i < pmax_iterations};

    while (any(active))
    {
        masked(active, active) = z_re * z_re + z_im * z_im <= 4.f;

        if (!any(active))
        {
            break;
        }

        pfloat new_re = z_re * z_re - z_im * z_im;
        pfloat new_im = 2.f * z_re * z_im;

        z_re = c_re + new_re;
        z_im = c_im + new_im;

        masked(i, active) = i + puint32{1u};
        masked(active, active) = i < pmax_iterations;
    }

    return i;
}

void mandelbrot_loop_pak(uint *dst, int width = 1080, int height = 720,
                         float cxmin = -2, float cxmax = 1, float cymin = -1, float cymax = 1,
                         unsigned int max_iterations = 256)
{
    float dx = (cxmax - cxmin) / width;
    float dy = (cymax - cymin) / height;

    for (size_t i = 0; i < height; i++)
    {
        pfloat y = cymin + i * dy;

        for (size_t j = 0; j < width; j += pfloat::width)
        {
            pfloat pj{(float)j};
            for (size_t p = 1; p < pfloat::width; p++)
            {
                pj.data[p] = pj.data[0] + p;
            }

            pfloat x = cxmin + pj * dx;

            puint32 result = mandelbrot_pak(x, y, max_iterations);

            size_t index = i * width + j;
            store(&dst[index], result);
        }
    }
}

int main(void)
{
    auto const startMain = kr8::Chrono::now();

    // The poor man's random generator.
    auto sample_one = [&](auto _) {
        auto const now = kr8::Chrono::now();
        uint64_t const duration = kr8::Chrono::duration(startMain, now);
        return (float)duration;
    };

    size_t const n = 800000;
    float *const vec_a = new float[n];
    float *const vec_b = new float[n];
    float *const vec_c = new float[n];
    float *const pvec_c = new float[n];

    std::transform(&vec_a[0], &vec_a[n], &vec_a[0], sample_one);
    std::transform(&vec_b[0], &vec_b[n], &vec_b[0], sample_one);

    auto loop_duration_normal = measure_runtime([&] { loop_normal(n, vec_a, vec_b, vec_c); });
    auto loop_duration_pak = measure_runtime([&] { loop_paked(n, vec_a, vec_b, pvec_c); });
    bool loop_correct = std::equal(&vec_c[0], &vec_c[n], &pvec_c[0]);

    size_t const width = 1920;
    size_t const height = 1080;
    size_t const size = width * height;
    uint *const out_mandel = new uint[size];
    uint *const pout_mandel = new uint[size];

    auto mandelbrot_duration_normal = measure_runtime([&] { mandelbrot_loop_normal(out_mandel, width, height); });
    auto mandelbrot_duration_pak = measure_runtime([&] { mandelbrot_loop_pak(pout_mandel, width, height); });
    bool mandelbrot_correct = std::equal(&out_mandel[0], &out_mandel[size], &pout_mandel[0]);

    // -------
    kr8::sout << "max kr8md width: " << KR8MD_MAX_VEC_REGISTER_SIZE << kr8::endl;
    kr8::sout << "sizeof(pfloat): " << sizeof(pfloat) << kr8::endl;
    kr8::sout << kr8::endl;

    kr8::sout << "Basic arithmetic on two vectors (size " << n << "):" << kr8::endl;
    kr8::sout << "Duration normal: " << loop_duration_normal << kr8::endl;
    kr8::sout << "Duration pak: " << loop_duration_pak << kr8::endl;
    kr8::sout << "Correctness: " << loop_correct << kr8::endl;
    kr8::sout << kr8::endl;

    kr8::sout << "Mabdelbrot fracal (size " << width << "x" << height << "):" << kr8::endl;
    kr8::sout << "Duration normal: " << mandelbrot_duration_normal << kr8::endl;
    kr8::sout << "Duration pak: " << mandelbrot_duration_pak << kr8::endl;
    kr8::sout << "Correctness: " << mandelbrot_correct << kr8::endl;
    kr8::sout << kr8::endl;

    delete[] vec_a;
    delete[] vec_b;
    delete[] vec_c;
    delete[] pvec_c;
    delete[] out_mandel;
    delete[] pout_mandel;

    return 0;
}
