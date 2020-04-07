#!/bin/bash
set -e
set -x

uname -a

cmake -H. -B_build_${TOOLCHAIN} -DCMAKE_TOOLCHAIN_FILE="${PWD}/toolchains/${TOOLCHAIN}.cmake"
cmake --build _build_${TOOLCHAIN} -- -j4

if [ "$RUN_TESTS" = true ]; then
	case "$TOOLCHAIN" in linux-mingw*)
		echo "copy runtime libraries needed for tests into build directory"
		cp /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll /usr/lib/gcc/x86_64-w64-mingw32/7.3-win32/{libstdc++-6.dll,libgcc_s_seh-1.dll} _build_${TOOLCHAIN}
	esac
	CTEST_OUTPUT_ON_FAILURE=1 cmake --build _build_${TOOLCHAIN} --target test
fi


