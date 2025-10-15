# Improved JPEG encoder and decoder implementation

This subdirectory contains a JPEG encoder and decoder implementation that is
API and ABI compatible with libjpeg62.

## Building

When building the parent libjxl project, two binaries, `tools/cjpegli` and
`tools/djpegli` will be built, as well as a
`lib/jpegli/libjpeg.so.62.3.0` shared library that can be used as a drop-in
replacement for the system library with the same name.

## Encoder improvements

Improvements and new features used by the encoder include:

* Support for 16-bit unsigned and 32-bit floating point input buffers.

* Color space conversions, chroma subsampling and DCT are all done in floating
  point precision, the conversion to integers happens first when producing
  the final quantized DCT coefficients.

* The desired quality can be indicated by a distance parameter that is
  analogous to the distance parameter of JPEG XL. The quantization tables
  are chosen based on the distance and the chroma subsampling mode, with
  different positions in the quantization matrix scaling differently, and the
  red and blue chrominance channels have separate quantization tables.

* Adaptive dead-zone quantization. On noisy parts of the image, quantization
  thresholds for zero coefficients are higher than on smoother parts of the
  image.

* Support for more efficient compression of JPEGs with an ICC profile
  representing the XYB colorspace. These JPEGs will not be converted to the
  YCbCr colorspace, but specialized quantization tables will be chosen for
  the original X, Y, B channels.

## Decoder improvements

* Support for 16-bit unsigned and 32-bit floating point output buffers.

* Non-zero DCT coefficients are dequantized to the expectation value of their
  respective quantization intervals assuming a Laplacian distribution of the
  original unquantized DCT coefficients.

* After dequantization, inverse DCT, chroma upsampling and color space
  conversions are all done in floating point precision, the conversion to
  integer samples happens only in the final output phase (unless output to
  floating point was requested).
