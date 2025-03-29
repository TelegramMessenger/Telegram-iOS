# Original issue:
# * https://gitlab.kitware.com/cmake/cmake/-/issues/23021#note_1098733
#
# For reference:
# * https://gcc.gnu.org/wiki/Atomic/GCCMM
#
# riscv64 specific:
# * https://lists.debian.org/debian-riscv/2022/01/msg00009.html
#
# ATOMICS_FOUND         - system has C++ atomics
# ATOMICS_LIBRARIES     - libraries needed to use C++ atomics

if (ATOMICS_FOUND)
  return()
endif()

include(CheckCXXSourceCompiles)

# RISC-V only has 32-bit and 64-bit atomic instructions. GCC is supposed
# to convert smaller atomics to those larger ones via masking and
# shifting like LLVM, but it's a known bug that it does not. This means
# anything that wants to use atomics on 1-byte or 2-byte types needs
# to link atomic library, but not 4-byte or 8-byte (though it does no harm).
set(ATOMIC_CODE
    "
    #include <atomic>
    #include <cstdint>
    std::atomic<std::uint8_t> n8{0}; // riscv64
    std::atomic<std::uint64_t> n64{0}; // armel, mipsel, powerpc
    int main() {
      ++n8;
      ++n64;
    }")

set(ATOMICS_LIBS " " "-latomic")
if (CMAKE_SYSTEM_NAME MATCHES "NetBSD")
  set(ATOMICS_LIBS "${ATOMICS_LIBS}" /usr/pkg/gcc12/x86_64--netbsd/lib/libatomic.so /usr/pkg/gcc12/i486--netbsdelf/lib/libatomic.so)
endif()

foreach (ATOMICS_LIBRARY ${ATOMICS_LIBS})
  unset(ATOMICS_FOUND CACHE)
  set(CMAKE_REQUIRED_LIBRARIES "${ATOMICS_LIBRARY}")
  check_cxx_source_compiles("${ATOMIC_CODE}" ATOMICS_FOUND)
  unset(CMAKE_REQUIRED_LIBRARIES)
  if (ATOMICS_FOUND)
    if (NOT ATOMICS_LIBRARY STREQUAL " ")
      include(FindPackageHandleStandardArgs)
      find_package_handle_standard_args(Atomics DEFAULT_MSG ATOMICS_LIBRARY)
      set(ATOMICS_LIBRARIES "${ATOMICS_LIBRARY}" CACHE STRING "Atomic library" FORCE)
    else()
      set(ATOMICS_LIBRARIES "" CACHE STRING "Atomic operations library" FORCE)
    endif()
    break()
  endif()
endforeach()
if (Atomics_FIND_REQUIRED AND NOT ATOMICS_FOUND)
  message(FATAL_ERROR "Atomic operations library isn't found.")
endif()

unset(ATOMICS_LIBRARY)
unset(ATOMICS_LIBS)
unset(ATOMIC_CODE)
