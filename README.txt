BUILD INSTRUCTION
=================
1. install meson build system. ( follow instruction in this link http://mesonbuild.com/Getting-meson.html )
2. install ninja build tool    (https://ninja-build.org/)
4. invoke meson build/  or meson -Dexample=true build/
5. invoke ninja inside the build folder.

NOTE: run meson configure to see all the build options

BUILD EXAMPLE
===============
1. meson configure -Dexample=true
2. ninja
3. to run example invoke ./build/example/demo
