## Disclaimer

Haiku builds are not officially supported, i.e. the build might not work at all,
some tests may fail and some sub-projects are excluded from build.

This manual outlines Haiku-specific setup. For general building and testing
instructions see "[BUILDING](BUILDING.md)" and
"[Building and Testing changes](doc/building_and_testing.md)".

## Dependencies

```shell
pkgman install llvm9_clang ninja cmake doxygen libjpeg_turbo_devel giflib_devel
```

## Building

```shell
TEST_STACK_LIMIT=none CMAKE_FLAGS="-I/boot/system/develop/tools/lib/gcc/x86_64-unknown-haiku/8.3.0/include/c++ -I/boot/system/develop/tools/lib/gcc/x86_64-unknown-haiku/8.3.0/include/c++/x86_64-unknown-haiku" CMAKE_SHARED_LINKER_FLAGS="-shared -Xlinker -soname=libjpegxl.so -lpthread" ./ci.sh opt
```
