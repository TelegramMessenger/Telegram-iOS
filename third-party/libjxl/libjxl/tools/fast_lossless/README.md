# Fast-lossless
This is a script to compile a standalone version of a JXL encoder that supports
lossless compression, up to 16 bits, of 1- to 4-channel images and animations; it is
very fast and compression is slightly worse than PNG for 8-bit nonphoto content
and better or much better than PNG for all other situations.

The main encoder is made out of two files, `lib/jxl/enc_fast_lossless.{cc,h}`;
it automatically selects and runs a SIMD implementation supported by your CPU.

This folder contains an example build script and `main` file.
