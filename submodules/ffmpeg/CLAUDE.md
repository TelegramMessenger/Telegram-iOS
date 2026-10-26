# Upgrading the vendored FFmpeg

FFmpeg (currently 8.1.2: lavc/lavf 62, lavu 60, swr 6) is built from source by the `libffmpeg_build` genrule in
`submodules/ffmpeg/BUILD`. Dropping in a new `Sources/FFMpeg/ffmpeg-<ver>/` tree needs exactly two edits, both in that
file:

1. **`FFMPEG_VERSION`** — the only place the version is pinned. `build-ffmpeg-bazel.sh` takes it as `$5` and derives
   `$SOURCE_DIR/ffmpeg-$FF_VERSION`.
2. **Prune `ffmpeg_header_paths`** of headers the new release removed (as FFmpeg 8 removed `libavcodec/avfft.h`).
   That list doubles as the genrule's declared `outs`, each `cp`'d twice (to `Public/` and
   `Public/third_party/ffmpeg/`), so a header that no longer exists **hard-fails the build**.

When surveying for breakage:

- **App consumers are guarded lower-bound only** (`#if LIBAVFORMAT_VERSION_MAJOR >= 59`, and its `< 59` complement),
  so removed APIs sit in dead branches and majors can climb freely. That is why `avcodec_close`, `swr_alloc_set_opts`
  and `av_get_default_channel_layout` still appear in `FFMpegBinding/Sources/*.m` and
  `tgcalls/group/{AudioStreamingPart*,VideoStreamingPart}.*` although FFmpeg 8 removed them.
- **Don't validate configure component names by grepping `configure`** — it derives them at runtime from
  `libavformat/allformats.c` and `libavcodec/{allcodecs,parsers,bitstream_filters}.c` / `hwaccels.h`
  (`extern const FFOutputFormat ff_<name>_muxer;`). Always control-diff the result against the outgoing version,
  because several names in the flags (`libopus` demuxer/parser, `mp3` parser, `libvpx_vp9` encoder) have always been
  inert and otherwise read as a fresh regression.

The `pkg-config` shim in `Sources/FFMpeg/` strips version qualifiers and always answers `--exists`, so
`require_pkg_config "dav1d >= 1.0.0"` cannot fail on version — only the wrapper's compile against the vendored headers
can. Verification is the full `Make.py build` (there is no isolated smoke build); afterwards confirm
`bazel-bin/submodules/ffmpeg/Public/libavutil/ffversion.h` reports the new version rather than trusting a cache hit. A
header dropped from the list lingers under `bazel-bin/.../Public/` (bazel does not delete undeclared outputs), so check
its mtime before believing it is live.
