// This file contains the required runtime support for C++ in "baremetal".

#include <stddef.h>

// From OSDev: This function is called in case a pure virtual function call
// cannot be made (e.g. if you have overridden the virtual function table of an
// object).
// The linker can sometimes generate calls to this function and therefore it
// needs to be defined somewhere.
// In practice it should never be called because it is not possible to
// instantiate a class that doesn't define all virtual functions (at least
// without hacks or undefined behavior. Hence do nothing.
extern "C" void __cxa_pure_virtual() { }

// Since we do not have the standard library, we need to define our new, new[],
// delete and delete[] operators ourselves since the compiler expects them to
// exist. For now these functions are stubs only.
void *operator new(size_t size) {
    // TODO
    return NULL;
}
 
void *operator new[](size_t size) {
    // TODO
    return NULL;
}
 
void operator delete(void *p) {
    // TODO
}
 
void operator delete[](void *p) {
    // TODO
}
