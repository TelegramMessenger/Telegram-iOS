This directory contains encoding and decoding scripts for HEVC, for use with
the benchmark custom codec. They use the HEVC reference encoder at https://hevc.hhi.fraunhofer.de/svn/svn_HEVCSoftware/
and require the `TAppEncoderHighBitDepthStatic` and
`TAppDecoderHighBitDepthStatic` binaries to be placed in this directory.

Example usage, for encoding at QP = 30:

```
tools/benchmark_xl --input=image.png --codec='custom:bin:.../tools/benchmark/hm/encode.sh:.../tools/benchmark/hm/decode.sh:-q:30'
```

The paths to the encode and decode scripts should be adjusted as necessary.
