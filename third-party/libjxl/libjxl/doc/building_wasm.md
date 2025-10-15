# Building WASM artifacts

This file describes the building and testing of JPEG XL
[Web Assembly](https://webassembly.org/) bundles and wrappers.

These instructions assume an up-to-date Debian/Ubuntu system.

For the sake of simplicity, it is considered, that the following environment
variables are set:

 * `OPT` - path to the directory containing additional software;
   the `emsdk` directory with the Emscripten SDK should reside there.

## Requirements

[CMake](https://cmake.org/) is used as a build system. To install it, follow
[Debian build instructions](developing_in_debian.md).

[Emscripten SDK](https://emscripten.org/) is required for building
WebAssembly artifacts. To install it, follow the
[Download and Install](https://emscripten.org/docs/getting_started/downloads.html)
guide:

```bash
cd $OPT

# Get the emsdk repo.
git clone https://github.com/emscripten-core/emsdk.git

# Enter that directory.
cd emsdk

# Download and install the latest SDK tools.
./emsdk install latest

# Make the "latest" SDK "active" for the current user. (writes ~/.emscripten file)
./emsdk activate latest
```

## Building and testing the project

```bash
# Setup EMSDK and other environment variables. In practice EMSDK is set to be
# $OPT/emsdk.
source $OPT/emsdk/emsdk_env.sh

# This should set the $EMSDK variable.
# If your node version is <16.4.0, you might need to update to a newer version or override
# the node binary with a version which supports SIMD:
echo "NODE_JS='/path/to/node_binary'" >> $EMSDK/.emscripten

# Assuming you are in the root level of the cloned libjxl repo,
# either build with regular WASM:
BUILD_TARGET=wasm32 emconfigure ./ci.sh release
# or with SIMD WASM:
BUILD_TARGET=wasm32 ENABLE_WASM_SIMD=1 emconfigure ./ci.sh release
```

## Example site

Once you have build the wasm binary, you can give it a try by building a site
that decodes jxl images, see [wasm_demo](../tools/wasm_demo/README.md).
