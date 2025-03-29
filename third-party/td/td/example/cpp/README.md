# TDLib C++ basic usage examples

TDLib should be prebuilt and installed to local subdirectory `td/`:
```
cd <path to TDLib sources>
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=../example/cpp/td ..
cmake --build . --target install
```
Also, see [building](https://github.com/tdlib/td#building) for additional details on TDLib building.

After this you can build the examples:
```
cd <path to TDLib sources>/example/cpp
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DTd_DIR=<full path to TDLib sources>/example/cpp/td/lib/cmake/Td ..
cmake --build .
```

Documentation for all available classes and methods can be found at https://core.telegram.org/tdlib/docs.

To run the examples you may need to manually copy needed shared libraries from `td/bin` to a directory containing built binaries.
