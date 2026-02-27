# JPEG XL reference implementation

[![Build/Test](https://github.com/libjxl/libjxl/actions/workflows/build_test.yml/badge.svg)](
https://github.com/libjxl/libjxl/actions/workflows/build_test.yml)
[![Build/Test Cross](https://github.com/libjxl/libjxl/actions/workflows/build_test_cross.yml/badge.svg)](
https://github.com/libjxl/libjxl/actions/workflows/build_test_cross.yml)
[![Conformance](https://github.com/libjxl/libjxl/actions/workflows/conformance.yml/badge.svg)](
https://github.com/libjxl/libjxl/actions/workflows/conformance.yml)
[![CIFuzz](https://github.com/libjxl/libjxl/actions/workflows/fuzz.yml/badge.svg)](
https://github.com/libjxl/libjxl/actions/workflows/fuzz.yml)
[![Releases](https://github.com/libjxl/libjxl/actions/workflows/release.yaml/badge.svg)](
https://github.com/libjxl/libjxl/actions/workflows/release.yaml)
[![Doc](https://readthedocs.org/projects/libjxl/badge/?version=latest)](
https://libjxl.readthedocs.io/en/latest/?badge=latest)
[![codecov](https://codecov.io/gh/libjxl/libjxl/branch/main/graph/badge.svg)](
https://codecov.io/gh/libjxl/libjxl)

<img src="doc/jxl.svg" width="100" align="right" alt="JXL logo">

This repository contains a reference implementation of JPEG XL (encoder and
decoder), called `libjxl`. This software library is
[used by many applications that support JPEG XL](doc/software_support.md).

JPEG XL was standardized in 2022 as [ISO/IEC 18181](https://jpeg.org/jpegxl/workplan.html).
The [core codestream](doc/format_overview.md#codestream-features) is specified in 18181-1,
the [file format](doc/format_overview.md#file-format-features) in 18181-2.
[Decoder conformance](https://github.com/libjxl/conformance) is defined in 18181-3,
and 18181-4 is the [reference software](https://github.com/libjxl/libjxl).

The library API, command line options, and tools in this repository are subject
to change, however files encoded with `cjxl` conform to the JPEG XL specification
and can be decoded with current and future `djxl` decoders or the `libjxl` decoding library.

## Installation

In most Linux distributions, installing `libjxl` is just a matter of using the package management system.
For example in Debian-based distributions: `apt install libjxl-tools` will install `cjxl` and `djxl`
and other tools like `benchmark_xl` are available in the package `libjxl-devtools`.
On MacOS, you can use [Homebrew](https://brew.sh/): `brew install jpeg-xl`.

[![libjxl packaging status](https://repology.org/badge/vertical-allrepos/libjxl.svg?exclude_unsupported=1&columns=3&exclude_sources=modules,site&header=libjxl%20packaging%20status)](https://repology.org/project/libjxl/versions)

From the [releases page](https://github.com/libjxl/libjxl/releases/) the following can be downloaded:
 - Windows binaries 
 - Debian and Ubuntu .deb packages 

Of course you can also [build libjxl from sources](BUILDING.md).


## Usage

To encode a source image to JPEG XL with default settings:

```bash
cjxl input.png output.jxl
```

The desired visual fidelity can be selected using the `--distance` parameter
(in units of just-noticeable difference, where 0 is lossless and the most useful lossy range is 0.5 .. 3.0),
or using `--quality` (on a scale from 0 to 100, roughly matching libjpeg).
The [encode effort](doc/encode_effort.md) can be selected using the `--effort` parameter.

For more settings run `cjxl --help` or for a full list of options
run `cjxl -v -v --help`.

To decode a JPEG XL file run:

```bash
djxl input.jxl output.png
```

When possible `cjxl`/`djxl` are able to read/write the following
image formats: .exr, .gif, .jpeg/.jpg, .pfm, .pgm/.ppm, .pgx, .png.
Specifically for JPEG files, the default `cjxl` behavior is to apply lossless
recompression and the default `djxl` behavior is to reconstruct the original
JPEG file (when the extension of the output file is .jpg).

### Benchmarking

For speed benchmarks on single images in single or multi-threaded decoding
`djxl` can print decoding speed information. See `djxl --help` for details
on the decoding options and note that the output image is optional for
benchmarking purposes.

For more comprehensive benchmarking options, see the
[benchmarking guide](doc/benchmarking.md).

### Library API

Besides the `libjxl` library [API documentation](https://libjxl.readthedocs.io/en/latest/),
there are [example applications](examples/) and [plugins](plugins/) that can be used as a reference or
starting point for developers who wish to integrate `libjxl` in their project.


## License

This software is available under a 3-clause BSD license which can be found in
the [LICENSE](LICENSE) file, with an "Additional IP Rights Grant" as outlined in
the [PATENTS](PATENTS) file.

Please note that the PATENTS file only mentions Google since Google is the legal
entity receiving the Contributor License Agreements (CLA) from all contributors
to the JPEG XL Project, including the initial main contributors to the JPEG XL
format: Cloudinary and Google.

## Additional documentation

### Codec description

*   [JPEG XL Format Overview](doc/format_overview.md)
*   [Introductory paper](https://www.spiedigitallibrary.org/proceedings/Download?fullDOI=10.1117%2F12.2529237) (open-access)
*   [XL Overview](doc/xl_overview.md) - a brief introduction to the source code modules
*   [JPEG XL white paper](https://ds.jpeg.org/whitepapers/jpeg-xl-whitepaper.pdf)
*   [JPEG XL official website](https://jpeg.org/jpegxl)
*   [JPEG XL community website](https://jpegxl.info)

### Development process

*   [More information on testing/build options](doc/building_and_testing.md)
*   [Git guide for JPEG XL](doc/developing_in_github.md) - for developers
*   [Fuzzing](doc/fuzzing.md) - for developers
*   [Building Web Assembly artifacts](doc/building_wasm.md)
*   [Test coverage on Codecov.io](https://app.codecov.io/gh/libjxl/libjxl) - for
    developers
*   [libjxl documentation on readthedocs.io](https://libjxl.readthedocs.io/)

### Contact

If you encounter a bug or other issue with the software, please open an Issue here.

There is a [subreddit about JPEG XL](https://www.reddit.com/r/jpegxl/), and
informal chatting with developers and early adopters of `libjxl` can be done on the
[JPEG XL Discord server](https://discord.gg/DqkQgDRTFu).
