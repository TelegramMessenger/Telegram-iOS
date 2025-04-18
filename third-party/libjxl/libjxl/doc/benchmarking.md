# Benchmarking

For speed benchmarks on single images in single or multi-threaded decoding
`djxl` can print decoding speed information. See `djxl --help` for details
on the decoding options and note that the output image is optional for
benchmarking purposes.

For a more comprehensive comparison of compression density between multiple
options, the tool `benchmark_xl` can be used (see below).

## Benchmarking with benchmark_xl

We recommend `build/tools/benchmark_xl` as a convenient method for reading
images or image sequences, encoding them using various codecs (jpeg jxl png
webp), decoding the result, and computing objective quality metrics. An example
invocation is:

```bash
build/tools/benchmark_xl --input "/path/*.png" --codec jxl:wombat:d1,jxl:cheetah:d2
```

Multiple comma-separated codecs are allowed. The characters after : are
parameters for the codec, separated by colons, in this case specifying maximum
target psychovisual distances of 1 and 2 (higher implies lower quality) and
the encoder effort (see below). Other common parameters are `r0.5` (target
bitrate 0.5 bits per pixel) and `q92` (quality 92, on a scale of 0-100, where
higher is better). The `jxl` codec supports the following additional parameters:

Speed: `lightning`, `thunder`, `falcon`, `cheetah`, `hare`, `wombat`, `squirrel`,
`kitten`, `tortoise` control the encoder effort in ascending order. This also
affects memory usage: using lower effort will typically reduce memory consumption
during encoding.

*   `lightning` and `thunder` are fast modes useful for lossless mode (modular).
*   `falcon` disables all of the following tools.
*   `cheetah` enables coefficient reordering, context clustering, and heuristics
    for selecting DCT sizes and quantization steps.
*   `hare` enables Gaborish filtering, chroma from luma, and an initial estimate
    of quantization steps.
*   `wombat` enables error diffusion quantization and full DCT size selection
    heuristics.
*   `squirrel` (default) enables dots, patches, and spline detection, and full
    context clustering.
*   `kitten` optimizes the adaptive quantization for a psychovisual metric.
*   `tortoise` enables a more thorough adaptive quantization search.

Mode: JPEG XL has two modes. The default is Var-DCT mode, which is suitable for
lossy compression. The other mode is Modular mode, which is suitable for lossless
compression. Modular mode can also do lossy compression (e.g. `jxl:m:q50`).

*   `m` activates modular mode.

Other arguments to benchmark_xl include:

*   `--save_compressed`: save codestreams to `output_dir`.
*   `--save_decompressed`: save decompressed outputs to `output_dir`.
*   `--output_extension`: selects the format used to output decoded images.
*   `--num_threads`: number of codec instances that will independently
    encode/decode images, or 0.
*   `--inner_threads`: how many threads each instance should use for parallel
    encoding/decoding, or 0.
*   `--encode_reps`/`--decode_reps`: how many times to repeat encoding/decoding
    each image, for more consistent measurements (we recommend 10).

The benchmark output begins with a header:

```
Compr              Input    Compr            Compr       Compr  Decomp  Butteraugli
Method            Pixels     Size              BPP   #    MP/s    MP/s     Distance    Error p norm           BPP*pnorm   Errors
```

`ComprMethod` lists each each comma-separated codec. `InputPixels` is the number
of pixels in the input image. `ComprSize` is the codestream size in bytes and
`ComprBPP` the bitrate. `Compr MP/s` and `Decomp MP/s` are the
compress/decompress throughput, in units of Megapixels/second.
`Butteraugli Distance` indicates the maximum psychovisual error in the decoded
image (larger is worse). `Error p norm` is a similar summary of the psychovisual
error, but closer to an average, giving less weight to small low-quality
regions. `BPP*pnorm` is the product of `ComprBPP` and `Error p norm`, which is a
figure of merit for the codec (lower is better). `Errors` is nonzero if errors
occurred while loading or encoding/decoding the image.

