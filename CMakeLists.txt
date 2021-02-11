cmake_minimum_required(VERSION 3.0)
project(Krayte)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Required by CMake in order to compile assembly files.
enable_language(ASM)

# Build type is either:
# - DEBUG: This is meant to be used when we want to test Krayte on the dev
# machine (not in baremetal or VM). We can use the std library in debug.
# - RELEASE: This is meant to be used when we want to run Krayte directly on
# baremetal or a VM. Std library is disabled at compile time.
message("Build type: ${CMAKE_BUILD_TYPE}")

# Flags required in order for the application to be ran by the bootstrap.
# 	-ffreestanding: Give a hint to the compiler that std and builtin won't be
# 	available.
# 	-static: There is no dynamic linking done by the bootstrap hence everything
# 	must be static.
# 	-nostdlib: Same as -static.
# 	-fno-exceptions: Exceptions are not supported since they required a library.
# 	-fno-rtti: No runtime support (at least yet).
# 	-mno-red-zone: Disable red zone on the stack (128 bytes under current RSP).
# 	This is because the kernel does not switch stacks on interrupts.
#   -Wl,-emain: Tell the linker that the entry point is named "main". This is
#   required in freestanding.
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -ffreestanding")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -static")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -nostdlib")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fno-exceptions")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fno-rtti")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -mno-red-zone")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Wl,-emain")

# Good practices
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wshadow=compatible-local")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=address")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wconversion")

# In DEBUG add the KRAYTE_ALLOW_STD macro so that the cpp code can check if it
# is allowed to use std.
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -DKRAYTE_ALLOW_STD")

# Enable all instruction subsets supported by the local machine
# TODO: Create  flags for specific instructions sets
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")

include_directories(
    # Include files
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

if(CMAKE_BUILD_TYPE MATCHES RELEASE)
    add_executable(Krayte
        # Source files
        src/main.cpp
        src/asm.S
    )
elseif(CMAKE_BUILD_TYPE MATCHES DEBUG)

    add_executable(Krayte
        # Header files
        # Source files
        src/kr8md_test.cpp
    )
endif()
