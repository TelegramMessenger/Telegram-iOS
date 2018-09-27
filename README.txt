BUILD INSTRUCTIONS
==================
1. install meson build system. ( follow instruction in this link http://mesonbuild.com/Getting-meson.html )
2. install ninja build tool    (https://ninja-build.org/)
3. invoke meson build/  or meson -Dexample=true build/
4. invoke ninja inside the build folder.

NOTE: run meson configure to see all the build options

BUILD EXAMPLES
==============
1. meson configure -Dexample=true
2. ninja
3. to run examples invoke ./build/example/demo, etc.
