cmake_minimum_required(VERSION 3.0)
project(Krayte)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

message("Build type: ${CMAKE_BUILD_TYPE}")

option(WithStd "WitStd" OFF)

# Flags required in order for the application to be ran by the bootstrap.
# 	-ffreestanding: Give a hint to the compiler that std and builtin won't be
# 	available.
# 	-static: There is no dynamic linking done by the bootstrap hence everything
# 	must be static.
# 	-nostdlib: Same as -static.
# 	-fno-exceptions: Exceptions are not supported since they required a library.
# 	-fno-rtti: No runtime support (at least yet).
if(NOT WithStd)
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -ffreestanding")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -static")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -nostdlib")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fno-exceptions")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fno-rtti")
endif()

# Good practices
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wshadow=compatible-local")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=address")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wconversion")

# Enable all instruction subsets supported by the local machine
# TODO: Create  flags for specific instructions sets
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")

include_directories(
    # Include files
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    )

#add_executable(Krayte
#    # Source files
#    src/main.cpp
#    )

add_executable(kr8md_test
    # Header files
    # Source files
    src/kr8md_test.cpp
    )
