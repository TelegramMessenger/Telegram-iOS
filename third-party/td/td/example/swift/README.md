# TDLib swift macOS example

TDLib should be prebuilt and installed to local subdirectory `td/`:
```
cd <path to TDLib sources>
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=../example/swift/td ..
cmake --build . --target install
```

After this you can open and build the example with the latest Xcode.

Description of all available classes and methods can be found at [td_json_client](https://core.telegram.org/tdlib/docs/td__json__client_8h.html)
and [td_api](https://core.telegram.org/tdlib/docs/td__api_8h.html) documentation.
