#pragma once

extern "C" int memcmp(void const * const  str1,
                      void const * const str2,
                      size_t size) {
    uint8_t const *s1 = (uint8_t const*)str1;
    uint8_t const *s2 = (uint8_t const*)str2;

    while (size > 0) {
        if (*s1 != *s2) {
            return *s1 < *s2 ? -1 : 1;
        }
        ++s1;
        ++s2;
        --size;
    }
    return 0;
}
