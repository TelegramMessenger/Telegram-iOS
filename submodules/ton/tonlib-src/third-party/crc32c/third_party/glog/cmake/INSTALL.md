# Glog - CMake Support

Glog comes with a CMake build script ([CMakeLists.txt](../CMakeLists.txt)) that can be used on a wide range of platforms.  
If you don't have CMake installed already, you can download it for free from <http://www.cmake.org/>.

CMake works by generating native makefiles or build projects that can be used in the compiler environment of your choice.  
You can either build Glog with CMake as a standalone project or it can be incorporated into an existing CMake build for another project.

## Table of Contents

- [Building Glog with CMake](#building-glog-with-cmake)
- [Consuming Glog in a CMake Project](#consuming-glog-in-a-cmake-project)
- [Incorporating Glog into a CMake Project](#incorporating-glog-into-a-cmake-project)

## Building Glog with CMake

When building Glog as a standalone project, on Unix-like systems with GNU Make as build tool, the typical workflow is:  

1. Get the source code and change to it.
e.g. cloning with git:
```bash
git clone git@github.com:google/glog.git
cd glog
```

2. Run CMake to configure the build tree.
```bash
cmake -H. -Bbuild -G "Unix Makefiles"
```
note: To get the list of available generators (e.g. Visual Studio), use `-G ""`

3. Afterwards, generated files can be used to compile the project.
```bash
cmake --build build
```

4. Test the build software (optional).
```bash
cmake --build build --target test
```

5. Install the built files (optional).
```bash
cmake --build build --target install
```

## Consuming Glog in a CMake Project

If you have Glog installed in your system, you can use the CMake command
`find_package()` to include it in your CMake Project.

```cmake
cmake_minimum_required(VERSION 3.0.2)
project(myproj VERSION 1.0)

find_package(glog 0.4.0 REQUIRED)

add_executable(myapp main.cpp)
target_link_libraries(myapp glog::glog)
```

Compile definitions and options will be added automatically to your target as
needed.

## Incorporating Glog into a CMake Project

You can also use the CMake command `add_subdirectory()` to include Glog directly from a subdirectory of your project.  
The **glog::glog** target is in this case an ALIAS library target for the **glog** library target. 

```cmake
cmake_minimum_required(VERSION 3.0.2)
project(myproj VERSION 1.0)

add_subdirectory(glog)

add_executable(myapp main.cpp)
target_link_libraries(myapp glog::glog)
```

Again, compile definitions and options will be added automatically to your target as
needed.
