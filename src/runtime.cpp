// This file contains the required runtime support for C++ in "baremetal".
#ifndef KRAYTE_ALLOW_STD
#include <stddef.h>
#include <stdint.h>

// From OSDev: This function is called in case a pure virtual function call
// cannot be made (e.g. if you have overridden the virtual function table of an
// object).
// The linker can sometimes generate calls to this function and therefore it
// needs to be defined somewhere.
// In practice it should never be called because it is not possible to
// instantiate a class that doesn't define all virtual functions (at least
// without hacks or undefined behavior. Hence do nothing.
extern "C" void __cxa_pure_virtual() { }

// Increase or decrease the size of the heap by `increment`.
// @return: The new program break, that is the top of the heap.
extern "C" void *sbrk(int64_t const increment);

// Get the current program break.
// @return: The address of the current program break.
static void *getProgramBreak(void) {
    return sbrk(0);
}

// The start address of the heap.
static uint8_t *HEAP_START = 0x0;
// The end address of the heap.
static uint8_t *HEAP_END = 0x0;
// The address to be used for the next allocation.
static uint8_t *nextAlloc = 0x0;

// Allocate memory on the heap.
// @param size: The number of bytes to allocate.
// @return: The address of the first byte allocated on the heap.
static void *doAlloc(size_t const size) {
    if (!HEAP_START) {
        // Setup state of the allocator on the first call.
        HEAP_START = (uint8_t*)getProgramBreak();
        HEAP_END = HEAP_START;
        nextAlloc = HEAP_START;
    }
    uint64_t const avail = HEAP_END - nextAlloc;
    if (avail < size) {
        // Need to increase the heap size.
        HEAP_END = (uint8_t*)sbrk(size - avail + 1);
    }
    void * const alloc = nextAlloc;
    nextAlloc = nextAlloc + size;
    return alloc;
}

// Since we do not have the standard library, we need to define our new, new[],
// delete and delete[] operators ourselves since the compiler expects them to
// exist. For now these functions are stubs only.
void *operator new(size_t size) {
    return doAlloc(size);
}
 
void *operator new[](size_t size) {
    return doAlloc(size);
}
 
void operator delete(void *p) {
    // TODO
}
 
void operator delete[](void *p) {
    // TODO
}

#endif // KRAYTE_ALLOW_STD
