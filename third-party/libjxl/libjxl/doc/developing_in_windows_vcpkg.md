# Developing on Windows with Visual Studio 2019

These instructions assume an up-to-date Windows 10 (e.g. build 19041.928) with
**Microsoft Visual Studio 2019** (e.g. Version 16.9.0 Preview 4.0) installed. If
unavailable, please use another build environment:

* [MSYS2 on Windows](developing_in_windows_msys.md)
* [Crossroad on Linux](developing_with_crossroad.md) (cross compilation for Windows)

## Minimum build dependencies

Apart from the dependencies in third_party, some of the tools use external
dependencies that need to be installed in your system first.

Please install [vcpkg](https://vcpkg.readthedocs.io/en/latest/examples/installing-and-using-packages/)
(tested with version 2019.07.18), and use it to install the following libraries:

```
vcpkg install gtest:x64-windows
vcpkg install giflib:x64-windows
vcpkg install libjpeg-turbo:x64-windows
vcpkg install libpng:x64-windows
vcpkg install zlib:x64-windows
```

## Building

From Visual Studio, open the CMakeLists.txt in the JPEG XL root directory.
Right-click the CMakeLists.txt entry in the Folder View of the Solution
Explorer. In the context menu, select CMake Settings. Click on the green plus
to add an x64-Clang configuration and the red minus to remove any non-Clang
configuration (the MSVC compiler is currently not supported). Click on the blue
hyperlink marked "CMakeSettings.json" and an editor will open. Insert the
following text after replacing $VCPKG with the directory where you installed
vcpkg above.

```
{
  "configurations": [
    {
      "name": "x64-Clang-Release",
      "generator": "Ninja",
      "configurationType": "MinSizeRel",
      "buildRoot": "${projectDir}\\out\\build\\${name}",
      "installRoot": "${projectDir}\\out\\install\\${name}",
      "cmakeCommandArgs": "-DCMAKE_TOOLCHAIN_FILE=$VCPKG/scripts/buildsystems/vcpkg.cmake",
      "buildCommandArgs": "-v",
      "ctestCommandArgs": "",
      "inheritEnvironments": [ "clang_cl_x64" ],
      "variables": [
        {
          "name": "VCPKG_TARGET_TRIPLET",
          "value": "x64-windows",
          "type": "STRING"
        },
        {
          "name": "JPEGXL_ENABLE_TCMALLOC",
          "value": "False",
          "type": "BOOL"
        },
        {
          "name": "BUILD_GMOCK",
          "value": "True",
          "type": "BOOL"
        },
        {
          "name": "gtest_force_shared_crt",
          "value": "True",
          "type": "BOOL"
        },
        {
          "name": "JPEGXL_ENABLE_FUZZERS",
          "value": "False",
          "type": "BOOL"
        },
        {
          "name": "JPEGXL_ENABLE_VIEWERS",
          "value": "False",
          "type": "BOOL"
        }
      ]
    }
  ]
}
```

The project is now ready for use. To build, simply press F7 (or choose
Build All from the Build menu). This writes binaries to
`out/build/x64-Clang-Release/tools`. The main [README.md](../README.md) explains
how to use the encoder/decoder and benchmark binaries.
