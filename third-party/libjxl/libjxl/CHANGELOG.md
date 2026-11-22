# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
 - encoder API: add `JxlEncoderSetExtraChannelDistance` to adjust the quality
   of extra channels (like alpha) separately.
 - encoder API: new api functions for streaming encoding:
  - `JxlEncoderSetOutputCallback`,
  - `JxlEncoderChunkedImageFrameStart`,
  - `JxlEncoderChunkedImageFrameAddPart` and new
  - `JXL_ENC_FRAME_SETTING_BUFFERING` enum value.
 - encoder API: new options for more fine-grained control over metadata
   preservation when using `JxlEncoderAddJPEGFrame`:
  - `JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF`
  - `JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP`
  - `JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF`
 - encoder API: new function `JxlEncoderSetUpsamplingMode` to change the upsampling
   method, e.g. to use nearest-neighbor upsampling for pixel art
 - cjxl can now be used to explicitly add/update/strip Exif/XMP/JUMBF metadata using
   the decoder-hints syntax, e.g. `cjxl input.ppm -x exif=input.exif output.jxl`
 - djxl can now be used to extract Exif/XMP/JUMBF metadata

### Removed
 - API: the Butteraugli API (`jxl/butteraugli.h`) was removed.
 - encoder and decoder API: all deprecated functions were removed:
   `JxlDecoderDefaultPixelFormat`, `JxlEncoderOptionsSetLossless`,
   `JxlEncoderOptionsSetEffort`, `JxlEncoderOptionsSetDecodingSpeed`,
   `JxlEncoderOptionsSetDistance`, `JxlEncoderOptionsCreate`, as well as
   the deprecated enumerator values `JXL_DEC_EXTENSIONS`, `JXL_ENC_NOT_SUPPORTED`,
   `JXL_TYPE_BOOLEAN`, `JXL_TYPE_UINT32`, and deprecated type `JxlEncoderOptions`.
 - decoder API: the signature of `JxlDecoderGetColorAsEncodedProfile`,
   `JxlDecoderGetICCProfileSize`, and `JxlDecoderGetColorAsICCProfile`
   changed: a deprecated unused argument was removed.

### Changed
 - changed the name of the cjxl flag `photon_noise` to `photon_noise_iso`

## [0.8.0] - 2023-01-18

### Added
 - decoder API: new function `JxlDecoderSetImageBitDepth` to set the bit depth
   of the output buffer.
 - decoder API proposal: add `JxlDecoderSetOutputColorProfile` and
   `JxlDecoderSetCms` to enable decoding to desired colorspace; NB: not
   implemented yet.
 - encoder API: new function `JxlEncoderSetFrameBitDepth` to set the bit depth
   of the input buffer.
 - encoder API: add an effort 10 option for lossless compression; using this
   setting requires calling `JxlEncoderAllowExpertOptions`.
 - encoder API: new `JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES` enum value to
   allow explicit control of metadata compression

### Removed
 - common API: removed `JxlIntrinsicSizeHeader`
 - decoder API: removed deprecated `JXL_DEC_NEED_DC_OUT_BUFFER` and
   `JXL_DEC_DC_IMAGE` events, `JxlDecoderDCOutBufferSize` and
   `JxlDecoderSetDCOutBuffer` functions

### Changed / clarified
 - encoder API: `JxlEncoderProcessOutput` requires at least 32 bytes of output
   space to proceed and guarantees that at least one byte will be written

## [0.7] - 2022-07-21

### Added
 - Export version information in headers.
 - decoder API: Ability to decode the content of metadata boxes:
   `JXL_DEC_BOX`, `JXL_DEC_BOX_NEED_MORE_OUTPUT`, `JxlDecoderSetBoxBuffer`,
   `JxlDecoderGetBoxType`, `JxlDecoderGetBoxSizeRaw` and
   `JxlDecoderSetDecompressBoxes`.
 - decoder API: ability to mark the input is finished: `JxlDecoderCloseInput`.
 - decoder API: ability to request updates on different progressive events using
   `JxlDecoderSetProgressiveDetail`; currently supported events are
   `kDC`, `kLastPasses` and `kPasses`.
 - decoder API: ability to specify desired intensity target using
   `JxlDecoderSetDesiredIntensityTarget`
 - decoder API: new function `JxlDecoderSetCoalesced` to allow decoding
   non-coalesced (unblended) frames, e.g. layers of a composite still image
   or the cropped frames of a recompressed GIF/APNG.
 - decoder API: new function `JxlDecoderSetUnpremultiplyAlpha` to set
   preference for getting an associated alpha channel with premultiplied or
   unpremultiplied colors.
 - decoder API: field added to `JxlFrameHeader`: a `JxlLayerInfo` struct
   that contains crop dimensions and offsets and blending information for
   the non-coalesced case.
 - decoder API: new function `JxlDecoderGetExtraChannelBlendInfo` to get
   the blending information for extra channels in the non-coalesced case.
 - decoder API: new function `JxlDecoderSetMultithreadedImageOutCallback`,
   allowing output callbacks to receive more information about the number of
   threads on which they are running.
 - decoder API: new function `JxlDecoderSkipCurrentFrame` to skip processing
   the current frame after a progressive detail is reached.
 - decoder API: new function `JxlDecoderGetIntendedDownsamplingRatio` to get
   the intended downsampling ratio of progressive steps, based on the
   information in the frame header.
 - decoder API: new function `JxlDecoderSetRenderSpotcolors` to allow disabling
   rendering of spot colors.
 - decoder/encoder API: add two fields to `JXLBasicInfo`: `intrinsic_xsize`
   and `intrinsic_ysize` to signal the intrinsic size.
 - encoder API: ability to add metadata boxes, added new functions
   `JxlEncoderAddBox`, `JxlEncoderUseBoxes`, `JxlEncoderCloseBoxes` and
   `JxlEncoderCloseFrames`.
 - encoder API: added ability to set several encoder options / extra fields to
   frames using `JxlEncoderSetFrameName`, `JxlEncoderFrameSettingsSetOption`,
   `JxlEncoderFrameSettingsSetFloatOption`.
 - encoder API: added ability to check required codestream compatibility level
   and force specified using `JxlEncoderGetRequiredCodestreamLevel` and
   `JxlEncoderSetCodestreamLevel`.
 - encoder API: added ability to force emitting box-based container format
   using `JxlEncoderUseContainer`.
 - encoder API: added ability to store JPEG metadata for lossless reconstruction
   using `JxlEncoderStoreJPEGMetadata`
 - encoder API: new functions `JxlEncoderSetFrameHeader` and
   `JxlEncoderSetExtraChannelBlendInfo` to set animation
   and blending parameters of the frame, and `JxlEncoderInitFrameHeader` and
   `JxlEncoderInitBlendInfo` to initialize the structs to set.
 - encoder API: ability to encode arbitrary extra channels:
  `JxlEncoderInitExtraChannelInfo`, `JxlEncoderSetExtraChannelInfo`,
  `JxlEncoderSetExtraChannelName` and `JxlEncoderSetExtraChannelBuffer`.
 - encoder API: ability to plug custom CMS implementation using
   `JxlEncoderSetCms(JxlEncoder* enc, JxlCmsInterface cms)`
 - encoder API: added `JxlEncoderGetError` to retrieve last encoder error.

### Changed
- decoder API: using `JxlDecoderCloseInput` at the end of all input is required
  when using JXL_DEC_BOX, and is now also encouraged in other cases, but not
  required in those other cases for backwards compatibility.
- encoder API: `JxlEncoderCloseInput` now closes both frames and boxes input.
- CLI: `cjxl` and `djxl` have been reimplemented on the base of public decoder
  and encoder API; dropped dependency on `gflags` for argument parsing.

### Deprecated
- decoder API: `JXL_DEC_EXTENSIONS` event: use `JXL_DEC_BASIC_INFO`
- decoder / encoder API: pixel types `JXL_TYPE_BOOLEAN` and `JXL_TYPE_UINT32`:
  consider using `JXL_TYPE_UINT8` and `JXL_TYPE_FLOAT` correspondingly.
- decoder API: pixel format parameter for `JxlDecoderGetColorAsEncodedProfile`
  and `JxlDecoderGetICCProfileSize`: pass `NULL`.
- decoder API: `JxlDecoderDefaultPixelFormat`
- encoder API: `JxlEncoderOptions`: use `JxlEncoderFrameSettings` instead.
- encoder API: `JxlEncoderOptionsCreate`: use `JxlEncoderFrameSettingsCreate`
  instead.
- encoder API: `JxlEncoderOptionsSetDistance`: use `JxlEncoderSetFrameDistance`
  instead.
- encoder API: `JxlEncoderOptionsSetLossless`: use `JxlEncoderSetFrameLossless`
  instead.
- encoder API: `JxlEncoderOptionsSetEffort`: use
  `JxlEncoderFrameSettingsSetOption(frame_settings, JXL_ENC_FRAME_SETTING_EFFORT, effort)`
  instead.
- encoder API: `JxlEncoderOptionsSetDecodingSpeed`: use
  `JxlEncoderFrameSettingsSetOption(frame_settings, JXL_ENC_FRAME_SETTING_DECODING_SPEED, tier)`
  instead.
- encoder API: deprecated `JXL_ENC_NOT_SUPPORTED`, the encoder returns
  `JXL_ENC_ERROR` instead and there is no need to handle
  `JXL_ENC_NOT_SUPPORTED`.

## [0.6.1] - 2021-10-29
### Changed
 - Security: Fix OOB read in splines rendering (#735 -
   [CVE-2021-22563](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22563))
 - Security: Fix OOB copy (read/write) in out-of-order/multi-threaded decoding
   (#708 - [CVE-2021-22564](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22564))
 - Fix segfault in `djxl` tool with `--allow_partial_files` flag (#781).
 - Fix border in extra channels when using upsampling (#796)

## [0.6] - 2021-10-04
### Added
 - API: New functions to decode extra channels:
   `JxlDecoderExtraChannelBufferSize` and `JxlDecoderSetExtraChannelBuffer`.
 - API: New function `JxlEncoderInitBasicInfo` to initialize `JxlBasicInfo`
   (only needed when encoding). NOTE: it is now required to call this function
   when using the encoder. Padding was added to the struct for forward
   compatibility.
 - API: Support for encoding oriented images.
 - API: FLOAT16 support in the encoder API.
 - Rewrite of the GDK pixbuf loader plugin. Added proper color management and
   animation support.
 - Rewrite of GIMP plugin. Added compression parameters dialog and switched to
   using the public C API.
 - Debian packages for GDK pixbuf loader (`libjxl-gdk-pixbuf`) and GIMP
   (`libjxl-gimp-plugin`) plugins.
 - `cjxl`/`djxl` support for `stdin` and `stdout`.

### Changed
 - API: Renamed the field `alpha_associated` in `JxlExtraChannelInfo` to
   `alpha_premultiplied`, to match the corresponding name in `JxlBasicInfo`.
 - Improved the 2x2 downscaling method in the encoder for the optional color
   channel resampling for low bit rates.
 - Fixed: the combination of floating point original data, XYB color encoding,
   and Modular mode was broken (in both encoder and decoder). It now works.
   NOTE: this can cause the current encoder to write jxl bitstreams that do
   not decode with the old decoder. In particular this will happen when using
   cjxl with PFM, EXR, or floating point PSD input, and a combination of XYB
   and modular mode is used (which caused an encoder error before), e.g.
   using options like `-m -q 80` (lossy modular), `-d 4.5` or `--progressive_dc=1`
   (modular DC frame), or default lossy encoding on an image where patches
   end up being used. There is no problem when using cjxl with PNG, JPEG, GIF,
   APNG, PPM, PGM, PGX, or integer (8-bit or 16-bit) PSD input.
 - `libjxl` static library now bundles skcms, fixing static linking in
   downstream projects when skcms is used.
 - Spline rendering performance improvements.
 - Butteraugli changes for less visual masking.

## [0.5] - 2021-08-02
### Added
 - API: New function to decode the image using a callback outputting a part of a
   row per call.
 - API: 16-bit float output support.
 - API: `JxlDecoderRewind` and `JxlDecoderSkipFrames` functions to skip more
   efficiently to earlier animation frames.
 - API: `JxlDecoderSetPreferredColorProfile` function to choose color profile in
   certain circumstances.
 - encoder: Adding `center_x` and `center_y` flags for more control of the tile
   order.
 - New encoder speeds `lightning` (1) and `thunder` (2).

### Changed
 - Re-licensed the project under a BSD 3-Clause license. See the
   [LICENSE](LICENSE) and [PATENTS](PATENTS) files for details.
 - Full JPEG XL part 1 specification support: Implemented all the spec required
   to decode files to pixels, including cases that are not used by the encoder
   yet. Part 2 of the spec (container format) is final but not fully implemented
   here.
 - Butteraugli metric improvements. Exact numbers are different from previous
   versions.
 - Memory reductions during decoding.
 - Reduce the size of the jxl_dec library by removing dependencies.
 - A few encoding speedups.
 - Clarify the security policy.
 - Significant encoding improvements (~5 %) and less ringing.
 - Butteraugli metric to have some less masking.
 - `cjxl` flag `--speed` is deprecated and replaced by the `--effort` synonym.

### Removed
- API for returning a downsampled DC was deprecated
  (`JxlDecoderDCOutBufferSize` and `JxlDecoderSetDCOutBuffer`) and will be
  removed in the next release.

## [0.3.7] - 2021-03-29
### Changed
 - Fix a rounding issue in 8-bit decoding.

## [0.3.6] - 2021-03-25
### Changed
 - Fix a bug that could result in the generation of invalid codestreams as
   well as failure to decode valid streams.

## [0.3.5] - 2021-03-23
### Added
 - New encode-time options for faster decoding at the cost of quality.
 - Man pages for cjxl and djxl.

### Changed
 - Memory usage improvements.
 - Faster decoding to 8-bit output with the C API.
 - GIMP plugin: avoid the sRGB conversion dialog for sRGB images, do not show
   a console window on Windows.
 - Various bug fixes.

## [0.3.4] - 2021-03-16
### Changed
 - Improved box parsing.
 - Improved metadata handling.
 - Performance and memory usage improvements.

## [0.3.3] - 2021-03-05
### Changed
 - Performance improvements for small images.
 - Add a (flag-protected) non-high-precision mode with better speed.
 - Significantly speed up the PQ EOTF.
 - Allow optional HDR tone mapping in djxl (--tone_map, --display_nits).
 - Change the behavior of djxl -j to make it consistent with cjxl (#153).
 - Improve image quality.
 - Improve EXIF handling.

## [0.3.2] - 2021-02-12
### Changed
 - Fix embedded ICC encoding regression
   [#149](https://gitlab.com/wg1/jpeg-xl/-/issues/149).

## [0.3.1] - 2021-02-10
### Changed
 - New experimental Butteraugli API (`jxl/butteraugli.h`).
 - Encoder improvements to low quality settings.
 - Bug fixes, including fuzzer-found potential security bug fixes.
 - Fixed `-q 100` and `-d 0` not triggering lossless modes.

## [0.3] - 2021-01-29
### Changed
 - Minor change to the Decoder C API to accommodate future work for other ways
   to provide input.
 - Future decoder C API changes will be backwards compatible.
 - Lots of bug fixes since the previous version.

## [0.2] - 2020-12-24
### Added
 - JPEG XL bitstream format is frozen. Files encoded with 0.2 will be supported
   by future versions.

### Changed
 - Files encoded with previous versions are not supported.

## [0.1.1] - 2020-12-01

## [0.1] - 2020-11-14
### Added
 - Initial release of an encoder (`cjxl`) and decoder (`djxl`) that work
   together as well as a benchmark tool for comparison with other codecs
   (`benchmark_xl`).
 - Note: JPEG XL format is in the final stages of standardization, minor changes
   to the codestream format are still possible but we are not expecting any
   changes beyond what is required by bug fixing.
 - API: new decoder API in C, check the `examples/` directory for its example
   usage. The C API is a work in progress and likely to change both in API and
   ABI in future releases.
