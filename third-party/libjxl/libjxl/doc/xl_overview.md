# XL Overview

## Requirements

JPEG XL was designed for two main requirements:

*   high quality: visually lossless at reasonable bitrates;
*   decoding speed: multithreaded decoding should be able to reach around
    400 Megapixel/s on large images.

These goals apply to various types of images, including HDR content, whose
support is made possible by full-precision (float32) computations and extensive
support of color spaces and transfer functions.

High performance is achieved by designing the format with careful consideration
of memory bandwidth usage and ease of SIMD/GPU implementation.

The full requirements for JPEG XL are listed in document wg1m82079.

## General architecture

The architecture follows the traditional block transform model with improvements
in the individual components. For a quick overview, we sketch a "block diagram"
of the lossy format decoder in the form of module names in **bold** followed by
a brief description. Note that post-processing modules in [brackets] are
optional - they are unnecessary or even counterproductive at very high quality
settings.

**Header**: decode metadata (e.g. image dimensions) from compressed fields
(smaller than Exp-Golomb thanks to per-field encodings). The compression and
small number of required fields enables very compact headers - much smaller than
JFIF and HEVC. The container supports multiple images (e.g. animations/bursts)
and passes (progressive).

**Bitstream**: decode transform coefficient residuals using rANS-encoded
<#bits,bits> symbols

**Dequantize**: from adaptive quant map side information, plus chroma from luma

**DC prediction**: expand DC residuals using adaptive (history-based) predictors

**Chroma from luma**: restore predicted X from B and Y from B

**IDCT:** 2x2..32x32, floating-point

**[Gaborish]**: additional deblocking convolution with 3x3 kernel

**[Edge preserving filter]**: nonlinear adaptive smoothing controlled by side
information

**[Noise injection]**: add perceptually pleasing noise according to a per-image
noise model

**Color space conversion**: from perceptual opsin XYB to linear RGB

**[Converting to other color spaces via ICC]**

The encoder is basically the reverse:

**Color space conversion**: from linear RGB to perceptual opsin XYB

**[Noise estimation]**: compute a noise model for the image

**[Gaborish]**: sharpening to counteract the blurring on the decoder side

**DCT**: transform sizes communicated via per-block side information

**Chroma from luma**: find the best multipliers of Y for X and B channels of
entire image

**Adaptive quantization**: iterative search for quant map that yields the best
perceived restoration

**Quantize**: store 16-bit prediction residuals

**DC prediction**: store residuals (prediction happens in quantized space)

**Entropy coding**: rANS and context modeling with clustering


# File Structure

A codestream begins with a `FileHeader` followed by one or more "passes"
(= scans: e.g. DC or AC_LF) which are then added together (summing the
respective color components in Opsin space) to form the final image. There is no
limit to the number of passes, so an encoder could choose to send salient parts
first, followed by arbitrary decompositions of the final image (in terms of
resolution, bit depth, quality or spatial location).

Each pass contains groups of AC and DC data. A group is a subset of pixels that
can be decoded in parallel. DC groups contain 256x256 DCs (from 2048x2048 input
pixels), AC groups cover 256x256 input pixels.

Each pass starts with a table of contents (sizes of each of their DC+AC
groups), which enables parallel decoding and/or the decoding of a subset.
However, there is no higher-level TOC of passes, as that would prevent
appending additional images and could be too constraining for the encoder.


## Lossless

JPEG XL supports tools for lossless coding designed by Alexander Rhatushnyak and
Jon Sneyers. They are about 60-75% of size of PNG, and smaller than WebP
lossless for photos.

An adaptive predictor computes 4 from the NW, N, NE and W pixels and combines
them with weights based on previous errors. The error value is encoded in a
bucket chosen based on a heuristic max error. The result is entropy-coded using
the ANS encoder.

## Current Reference Implementation

### Conventions

The software is written in C++ and built using CMake 3.6 or later.

Error handling is done by having functions return values of type `jxl::Status`
(a thin wrapper around bool which checks that it is not ignored). A convenience
macro named `JXL_RETURN_IF_ERROR` makes this more convenient by automatically
forwarding errors, and another macro named `JXL_FAILURE` exits with an error
message if reached, with no effect in optimized builds.

To diagnose the cause of encoder/decoder failures (which often only result in a
generic "decode failed" message), build using the following command:

```bash
CMAKE_FLAGS="-DJXL_CRASH_ON_ERROR" ./ci.sh opt
```

In such builds, the first JXL_FAILURE will print a message identifying where the
problem is and the program will exit immediately afterwards.

### Architecture

Getting back to the earlier block diagram:

**Header** handling is implemented in `headers.h` and `field*`.

**Bitstream**: `entropy_coder.h`, `dec_ans_*`.

**(De)quantize**: `quantizer.h`.

**DC prediction**: `predictor.h`.

**Chroma from luma**: `chroma_from_luma.h`

**(I)DCT**: `dct*.h`. Instead of operating directly on blocks of memory, the
functions operate on thin wrappers which can handle blocks spread across
multiple image lines.

**DCT size selection**: `ac_strategy.cc`

**[Gaborish]**: `enc_gaborish.h`.

**[Edge preserving filter]**: `epf.h`

**[Noise injection]**: `noise*` (currently disabled)

**Color space conversion**: `color_*`, `dec_xyb.h`.

## Decoder overview

After decoding headers, the decoder begins processing frames (`dec_frame.cc`).

For each pass, it will read the DC group table of contents (TOC) and start
decoding, dequantizing and restoring color correlation of each DC group
(covering 2048x2048 pixels in the input image) in parallel
(`compressed_dc.cc`). The DC is split into parts corresponding to each AC group
(with 1px of extra border); the AC group TOC is read and each AC group (256x256
pixels) is processed in parallel (`dec_group.cc`).

In each AC group, the decoder reads per-block side information indicating the
kind of DCT transform; this is followed by the quantization field. Then, AC
coefficients are read, dequantized and have color correlation restored on a
tile per tile basis for better locality.

After all the groups are read, postprocessing is applied: Gaborish smoothing
and edge preserving filter, to reduce blocking and other artifacts.

Finally, the image is converted back from the XYB color space
(`dec_xyb.cc`) and saved to the output image (`codec_*.cc`).
